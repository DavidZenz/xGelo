#!/usr/bin/env Rscript

message("xGelo WC2026 dashboard update")

read_env_int <- function(name, default) {
  value <- Sys.getenv(name, unset = NA_character_)
  if (is.na(value) || !nzchar(value)) return(as.integer(default))
  parsed <- suppressWarnings(as.integer(value))
  if (is.na(parsed) || parsed <= 0L) {
    stop(sprintf("%s must be a positive integer; got %s", name, value), call. = FALSE)
  }
  parsed
}

read_env_flag <- function(name, default = FALSE) {
  value <- Sys.getenv(name, unset = NA_character_)
  if (is.na(value) || !nzchar(value)) return(isTRUE(default))
  normalized <- tolower(trimws(value))
  if (normalized %in% c("1", "true", "t", "yes", "y")) return(TRUE)
  if (normalized %in% c("0", "false", "f", "no", "n")) return(FALSE)
  stop(sprintf("%s must be true/false; got %s", name, value), call. = FALSE)
}

read_env_path <- function(name, default) {
  value <- Sys.getenv(name, unset = NA_character_)
  if (is.na(value) || !nzchar(value)) default else value
}

require_paths <- function(paths, label) {
  missing_paths <- paths[!file.exists(paths)]
  if (length(missing_paths) > 0) {
    stop(
      sprintf(
        "Missing %s:\n%s\nRun the targets pipeline before publishing the dashboard.",
        label,
        paste(sprintf("- %s", missing_paths), collapse = "\n")
      ),
      call. = FALSE
    )
  }
}

source_dashboard_code <- function() {
  sources <- c(
    "R/forecast/features.R",
    "R/transfermarkt/squad_strength.R",
    "R/forecast/goal_ability.R",
    "R/forecast/xg_usage_audit.R",
    "R/forecast/poisson.R",
    "R/forecast/monte_carlo.R",
    "R/forecast/tournament.R",
    "R/visualization/worldcup_dashboard.R"
  )
  require_paths(sources, "dashboard source files")
  invisible(lapply(sources, source))
}

report_local_data_freshness <- function(matches_path, transfermarkt_metadata_path) {
  if (file.exists(matches_path)) {
    matches <- read.csv(matches_path, stringsAsFactors = FALSE)
    if ("date" %in% names(matches)) {
      scored <- matches[!is.na(matches$home_score) & !is.na(matches$away_score), , drop = FALSE]
      latest_scored <- suppressWarnings(max(as.Date(scored$date), na.rm = TRUE))
      if (is.finite(latest_scored)) {
        message(sprintf("Latest scored match in %s: %s", matches_path, latest_scored))
        if (latest_scored < Sys.Date() - 7L) {
          warning(
            sprintf(
              "Local scored match data is older than seven days (%s). Refresh processed inputs before publishing if newer friendlies/tests matter.",
              latest_scored
            ),
            call. = FALSE
          )
        }
      }
    }
  }

  if (file.exists(transfermarkt_metadata_path)) {
    metadata <- read.csv(transfermarkt_metadata_path, stringsAsFactors = FALSE)
    if (nrow(metadata) > 0) {
      useful_cols <- intersect(c("generated_at", "snapshot_path", "snapshot_checksum"), names(metadata))
      if (length(useful_cols) > 0) {
        compact <- paste(sprintf("%s=%s", useful_cols, as.character(metadata[1, useful_cols])), collapse = ", ")
        message(sprintf("Transfermarkt snapshot metadata: %s", compact))
      }
    }
  }

  message("This script uses local processed data only; it does not download or refresh upstream datasets.")
}

collect_dashboard_team_sources <- function(forecast_features_path, output_dir = NULL, include_dashboard = FALSE) {
  sources <- list()
  if (file.exists("data/processed/elo_current.csv")) {
    elo_current <- read.csv("data/processed/elo_current.csv", stringsAsFactors = FALSE)
    sources$elo_current <- elo_current$team
  }
  if (file.exists("data/processed/elo_ratings.csv")) {
    elo_ratings <- read.csv("data/processed/elo_ratings.csv", stringsAsFactors = FALSE)
    sources$elo_ratings <- elo_ratings$team
  }
  if (file.exists("data/processed/transfermarkt_squad_strength.csv")) {
    squad <- read.csv("data/processed/transfermarkt_squad_strength.csv", stringsAsFactors = FALSE)
    sources$transfermarkt_squad_strength <- squad$team
  }
  if (file.exists(forecast_features_path)) {
    forecast_features <- read.csv(forecast_features_path, stringsAsFactors = FALSE)
    sources$forecast_features <- c(forecast_features$home_team, forecast_features$away_team)
  }
  dashboard_stage_path <- if (!is.null(output_dir)) file.path(output_dir, "worldcup_stage_probabilities.csv") else NA_character_
  if (include_dashboard && file.exists(dashboard_stage_path)) {
    dashboard_stage <- read.csv(dashboard_stage_path, stringsAsFactors = FALSE)
    sources$dashboard_stage <- dashboard_stage$team
  }
  if (
    file.exists("data/raw/transfermarkt/transfermarkt-datasets.duckdb") &&
      requireNamespace("duckdb", quietly = TRUE) &&
      requireNamespace("DBI", quietly = TRUE)
  ) {
    con <- DBI::dbConnect(
      duckdb::duckdb(),
      dbdir = "data/raw/transfermarkt/transfermarkt-datasets.duckdb",
      read_only = TRUE
    )
    on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
    if ("national_teams" %in% DBI::dbListTables(con)) {
      national_teams <- DBI::dbReadTable(con, "national_teams")
      sources$transfermarkt_national_teams_raw <- c(national_teams$name, national_teams$country_name)
    }
  }
  sources
}

audit_dashboard_team_coverage <- function(forecast_features_path, output_dir = NULL, include_dashboard = FALSE) {
  groups <- read.csv("data/raw/worldcup_2026_groups.csv", stringsAsFactors = FALSE)
  sources <- collect_dashboard_team_sources(
    forecast_features_path = forecast_features_path,
    output_dir = output_dir,
    include_dashboard = include_dashboard
  )
  coverage <- audit_team_source_coverage(groups$team, sources)
  required_sources <- c("elo_current", "elo_ratings", "transfermarkt_squad_strength", "forecast_features")
  if (include_dashboard) required_sources <- c(required_sources, "dashboard_stage")
  assert_team_source_coverage(coverage, intersect(required_sources, names(coverage)))

  message("WC2026 team coverage audit:")
  for (source_name in setdiff(names(coverage), "team")) {
    missing_teams <- coverage$team[!coverage[[source_name]]]
    status <- if (length(missing_teams) == 0) "OK" else paste(missing_teams, collapse = ", ")
    message(sprintf("- %s: %s", source_name, status))
  }
  coverage
}

report_transfermarkt_value_divergence <- function(
    forecast_features_path,
    transfermarkt_snapshot_path,
    cutoff_date,
    n = 8L
) {
  if (
    !file.exists("data/processed/transfermarkt_squad_strength.csv") ||
      !file.exists(transfermarkt_snapshot_path)
  ) {
    message("Transfermarkt value divergence audit: skipped; required local files are missing.")
    return(invisible(NULL))
  }
  groups <- read.csv("data/raw/worldcup_2026_groups.csv", stringsAsFactors = FALSE)
  audit <- audit_transfermarkt_value_divergence(
    squad_strength = "data/processed/transfermarkt_squad_strength.csv",
    snapshot_path = transfermarkt_snapshot_path,
    teams = groups$team,
    cutoff_date = cutoff_date
  )
  missing_raw <- audit$team[audit$status == "missing_raw_national_team"]
  flagged <- audit[audit$status %in% c("review", "warn"), , drop = FALSE]
  message("Transfermarkt player-pool vs national-team value audit:")
  if (length(missing_raw) > 0) {
    message(sprintf("- missing raw national_teams rows: %s", paste(missing_raw, collapse = ", ")))
  } else {
    message("- missing raw national_teams rows: none")
  }
  if (nrow(flagged) == 0) {
    message("- flagged divergences: none")
  } else {
    flagged <- flagged[order(match(flagged$status, c("review", "warn")), -flagged$abs_log_divergence), , drop = FALSE]
    message("- top flagged divergences:")
    for (idx in seq_len(min(n, nrow(flagged)))) {
      row <- flagged[idx, ]
      message(sprintf(
        "  %s: %s, pool/national %.2fx, pool EUR %.1fm vs national EUR %.1fm",
        row$team,
        row$status,
        row$pool_to_national_ratio,
        row$player_pool_value / 1e6,
        row$national_team_value / 1e6
      ))
    }
  }
  invisible(audit)
}

report_xg_feature_usage <- function(
    feature_table_path,
    home_model_path,
    away_model_path,
    forecast_features_path,
    audit_output_path = "data/processed/xg_feature_usage_audit.csv"
) {
  if (!file.exists(feature_table_path)) {
    message("xG/form feature usage audit: skipped; training feature table is missing.")
    return(invisible(NULL))
  }
  audit <- audit_xg_feature_usage(
    feature_table = feature_table_path,
    home_model = home_model_path,
    away_model = away_model_path,
    rolling_form = "data/processed/rolling_form.csv",
    forecast_features = forecast_features_path,
    output_path = audit_output_path
  )
  active_flag <- as.logical(audit$active_in_model)
  active_flag[is.na(active_flag)] <- FALSE
  active <- audit$predictor[active_flag]
  nonzero <- suppressWarnings(as.numeric(audit$nonzero_count))
  sd_values <- suppressWarnings(as.numeric(audit$sd))
  message("xG/form feature usage audit:")
  if (length(active) > 0) {
    message(sprintf("- active predictors: %s", paste(active, collapse = ", ")))
  } else {
    message("- active predictors: none")
  }
  message(sprintf(
    "- candidate predictors: %s",
    paste(audit$predictor, collapse = ", ")
  ))
  message(sprintf(
    "- max nonzero count: %s; max sd: %.6f",
    if (all(is.na(nonzero))) NA_real_ else max(nonzero, na.rm = TRUE),
    if (all(is.na(sd_values))) NA_real_ else max(sd_values, na.rm = TRUE)
  ))
  message(sprintf(
    "- rolling-form team coverage: training %.1f%% (%s/%s), forecast %.1f%% (%s/%s)",
    100 * audit$training_team_coverage[1],
    audit$training_teams_with_rolling_form[1],
    audit$training_teams[1],
    100 * audit$forecast_team_coverage[1],
    audit$forecast_teams_with_rolling_form[1],
    audit$forecast_teams[1]
  ))
  message(sprintf("- wrote audit: %s", audit_output_path))
  invisible(audit)
}

extract_top_champions <- function(stage_path, n = 10L) {
  if (!file.exists(stage_path)) return(NULL)
  stage <- read.csv(stage_path, stringsAsFactors = FALSE)
  if (!"team" %in% names(stage)) return(NULL)
  probability_col <- if ("champion_probability" %in% names(stage)) {
    "champion_probability"
  } else if ("champion" %in% names(stage)) {
    "champion"
  } else {
    return(NULL)
  }
  stage <- stage[order(stage[[probability_col]], decreasing = TRUE), c("team", probability_col), drop = FALSE]
  names(stage) <- c("team", "champion")
  utils::head(stage, n)
}

main <- function() {
  source_dashboard_code()

  n_match_sim <- read_env_int("XGELO_MATCH_SIMS", 100000L)
  n_tournaments <- read_env_int("XGELO_TOURNAMENT_SIMS", 100000L)
  n_workers <- read_env_int("XGELO_DASHBOARD_WORKERS", 4L)
  output_dir <- read_env_path("XGELO_OUTPUT_DIR", "outputs/dashboard_100k")
  pages_dir <- read_env_path("XGELO_PAGES_DIR", "docs/wc2026")
  publish_pages <- read_env_flag("XGELO_PUBLISH", TRUE)
  baseline_comparison <- read_env_flag("XGELO_BASELINE_COMPARISON", FALSE)
  route_method <- read_env_path("XGELO_ROUTE_METHOD", "analytic")
  feature_cutoff_date <- as.Date(read_env_path("XGELO_FEATURE_CUTOFF_DATE", as.character(Sys.Date() - 1L)))
  if (is.na(feature_cutoff_date)) {
    stop("XGELO_FEATURE_CUTOFF_DATE must parse as an ISO date, for example 2026-06-10", call. = FALSE)
  }
  actual_results_cutoff_date <- as.Date(read_env_path("XGELO_ACTUAL_RESULTS_CUTOFF_DATE", as.character(Sys.Date())))
  if (is.na(actual_results_cutoff_date)) {
    stop("XGELO_ACTUAL_RESULTS_CUTOFF_DATE must parse as an ISO date, for example 2026-06-12", call. = FALSE)
  }
  if (!route_method %in% c("analytic", "simulation")) {
    stop("XGELO_ROUTE_METHOD must be either analytic or simulation", call. = FALSE)
  }

  home_model_path <- read_env_path("XGELO_HOME_MODEL", "models/home_goal_model_hybrid.rds")
  away_model_path <- read_env_path("XGELO_AWAY_MODEL", "models/away_goal_model_hybrid.rds")
  forecast_features_path <- read_env_path(
    "XGELO_FORECAST_FEATURES",
    "data/processed/worldcup_2026_forecast_features_hybrid.csv"
  )
  matches_path <- read_env_path("XGELO_MATCHES", "data/processed/elo_matches.csv")
  transfermarkt_metadata_path <- read_env_path(
    "XGELO_TRANSFERMARKT_METADATA",
    "data/raw/transfermarkt/SNAPSHOT-METADATA.csv"
  )
  transfermarkt_snapshot_path <- read_env_path(
    "XGELO_TRANSFERMARKT_SNAPSHOT",
    "data/raw/transfermarkt/transfermarkt-datasets.duckdb"
  )

  require_paths(
    c(home_model_path, away_model_path, forecast_features_path, matches_path),
    "hybrid dashboard artifacts"
  )
  if (baseline_comparison) {
    require_paths(c("models/home_goal_model.rds", "models/away_goal_model.rds"), "baseline comparison artifacts")
  }

  report_local_data_freshness(matches_path, transfermarkt_metadata_path)
  audit_dashboard_team_coverage(
    forecast_features_path = forecast_features_path,
    output_dir = output_dir,
    include_dashboard = FALSE
  )
  report_transfermarkt_value_divergence(
    forecast_features_path = forecast_features_path,
    transfermarkt_snapshot_path = transfermarkt_snapshot_path,
    cutoff_date = feature_cutoff_date
  )
  report_xg_feature_usage(
    feature_table_path = "data/processed/goal_training_features_hybrid.csv",
    home_model_path = home_model_path,
    away_model_path = away_model_path,
    forecast_features_path = forecast_features_path
  )

  message(sprintf(
    "Building hybrid dashboard: match_sims=%s, tournaments=%s, workers=%s, feature_cutoff=%s, actual_results_cutoff=%s, route_method=%s",
    n_match_sim,
    n_tournaments,
    n_workers,
    feature_cutoff_date,
    actual_results_cutoff_date,
    route_method
  ))

  started <- Sys.time()
  dashboard <- build_worldcup_dashboard(
    output_dir = output_dir,
    n_match_sim = n_match_sim,
    n_tournaments = n_tournaments,
    n_workers = n_workers,
    model_version = "hybrid",
    feature_cutoff_date = feature_cutoff_date,
    actual_results_cutoff_date = actual_results_cutoff_date,
    actual_results_path = matches_path,
    require_forecast_features = TRUE,
    baseline_comparison = baseline_comparison,
    home_model_path = home_model_path,
    away_model_path = away_model_path,
    forecast_features_path = forecast_features_path,
    baseline_home_model_path = "models/home_goal_model.rds",
    baseline_away_model_path = "models/away_goal_model.rds",
    transfermarkt_metadata_path = transfermarkt_metadata_path,
    route_method = route_method
  )
  elapsed <- as.numeric(difftime(Sys.time(), started, units = "secs"))

  published_path <- NA_character_
  if (publish_pages) {
    published_path <- publish_worldcup_dashboard_pages(
      data_json_path = dashboard$paths$data_json,
      pages_dir = pages_dir
    )
  }
  audit_dashboard_team_coverage(
    forecast_features_path = forecast_features_path,
    output_dir = output_dir,
    include_dashboard = TRUE
  )

  message(sprintf("Dashboard HTML: %s", dashboard$paths$html))
  message(sprintf("Dashboard data: %s", dashboard$paths$data_json))
  if (publish_pages) message(sprintf("Published Pages copy: %s", published_path))
  message(sprintf("Elapsed: %.1f seconds", elapsed))

  top_champions <- extract_top_champions(file.path(output_dir, "worldcup_stage_probabilities.csv"))
  if (!is.null(top_champions)) {
    message("Top champion probabilities:")
    for (idx in seq_len(nrow(top_champions))) {
      message(sprintf(
        "%2d. %-20s %5.2f%%",
        idx,
        top_champions$team[idx],
        100 * top_champions$champion[idx]
      ))
    }
  }

  invisible(list(
    dashboard = dashboard,
    published_path = published_path,
    elapsed_seconds = elapsed
  ))
}

main()
