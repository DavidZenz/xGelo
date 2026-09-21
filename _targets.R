# xGelo Pipeline Definition
# This file defines an executable targets pipeline for the xGelo forecasting system.

phase10_library <- file.path("data", "cache", "phase10-library")
phase11_library <- file.path("data", "cache", "phase11-library")
local_phase_libraries <- c(phase11_library, phase10_library)
local_phase_libraries <- local_phase_libraries[dir.exists(local_phase_libraries)]
target_library_paths <- unique(c(
  if (length(local_phase_libraries)) normalizePath(local_phase_libraries) else character(),
  .libPaths()
))
.libPaths(target_library_paths)

library(targets)

# Keep target import hashing in a clean child environment.  The legacy release
# helpers remain available through the global parent, while their historical
# mutual references cannot contaminate the independent club graph's import
# validation.
phase19_target_runtime_envir <- new.env(parent = globalenv())

# Phase 19 club authority is intentionally sourced before the legacy national
# pipeline.  Its targets below form a closed club-domain graph and never
# consume national benchmark or release targets.
source("R/common/phase18_canonical_hash.R")
source("R/release/domain_contract.R")
source("R/competition/source_contracts.R")
source("R/competition/ucl_source_acceptance.R")
source("R/competition/edition_registry.R")
source("R/club/identity.R")
source("R/club/identity_bootstrap.R")
source("R/competition/football_data_org_adapter.R")
source("R/competition/ucl_source_bundle.R")
source("R/competition/ucl_source_refresh.R")
source("R/club/history_contract.R")
source("R/club/model_contract.R")
source("R/club/evaluation_protocol.R")
source("R/club/rating.R")
source("R/club/goal_model.R")
source("R/club/calibration.R")
source("R/club/evaluation.R")
source("R/club/release.R")

tar_option_set(
  envir = phase19_target_runtime_envir,
  library = target_library_paths,
  packages = c(
    "dplyr",
    "jsonlite",
    "lubridate",
    "MASS",
    "Matrix",
    "glmnet",
    "ranger",
    "pROC",
    "tidymodels",
    "ggplot2",
    "DBI",
    "duckdb"
  )
)

source("R/elo/preprocess.R")
source("R/competition/source_contracts.R")
source("R/competition/team_identity.R")
source("R/elo/runner_optimized.R")
source("R/elo/validation.R")
source("R/xg/features.R")
source("R/xg/model.R")
source("R/xg/data_prep.R")
source("R/xg/backtest.R")
source("R/xg/calibration.R")
source("R/integration/team_match_xg.R")
source("R/integration/rolling_form.R")
source("R/transfermarkt/squad_strength.R")
source("R/forecast/features.R")
source("R/forecast/xg_usage_audit.R")
source("R/forecast/goal_ability.R")
source("R/forecast/poisson.R")
source("R/forecast/monte_carlo.R")
source("R/forecast/output.R")
source("R/forecast/tournament.R")
source("R/forecast/calibration.R")
source("R/benchmark/euro2024.R")
source("R/benchmark/euro2024_tournament.R")
source("R/pipeline/validation.R")
source("R/visualization/auc.R")
source("R/visualization/calibration.R")
source("R/visualization/worldcup_dashboard.R")
source("R/evaluation/proper_scores.R")
source("R/evaluation/worldcup_ledger.R")
source("R/evaluation/worldcup_retrospective.R")
source("R/visualization/worldcup_retrospective.R")
source("R/benchmark/registry.R")
source("R/benchmark/challenger_preflight.R")
source("R/benchmark/cutoffs.R")
source("R/benchmark/weights.R")
source("R/benchmark/contracts.R")
source("R/benchmark/baselines.R")
source("R/forecast/tournament_formats.R")
source("R/evaluation/benchmark_scores.R")
source("R/evaluation/promotion.R")
source("R/benchmark/runner.R")
source("R/benchmark/challenger_protocol.R")
source("R/forecast/penalized_poisson.R")
source("R/forecast/dynamic_goal_ability.R")
source("R/forecast/score_dependence.R")
source("R/benchmark/challengers.R")
source("R/evaluation/challenger_selection.R")
source("R/benchmark/challenger_runner.R")
source("R/forecast/hybrid_rf.R")
source("R/forecast/context_features.R")
source("R/forecast/structural_prior.R")
source("R/forecast/external_market.R")
source("R/benchmark/hybrid_protocol.R")
source("R/benchmark/hybrid_adapters.R")
source("R/benchmark/hybrid_runner.R")
source("R/calibration/inner_oof.R")
source("R/calibration/probability_calibration.R")
source("R/release/freeze_manifest.R")
source("R/release/final_fit.R")
source("R/release/final_evaluation.R")
source("R/release/promotion_report.R")
source("R/release/release_bundle.R")
source("R/release/release_install.R")
source("R/release/release_contract.R")

# Keep the legacy validator's lazy dependency loader intact while avoiding a
# targets import cycle between the loader and the validator it services.
benchmark_runner_require_validation_dependencies <- function() {
  runner_env <- environment(get("validate_rolling_benchmark_bundle", envir = .GlobalEnv))
  if (!exists("benchmark_output_coverage", envir = runner_env, mode = "function", inherits = TRUE)) {
    sys.source("R/benchmark/baselines.R", envir = runner_env)
  }
  if (!exists("benchmark_output_coverage", envir = runner_env, mode = "function", inherits = TRUE)) {
    stop("benchmark_output_coverage is required for standalone bundle validation", call. = FALSE)
  }
  invisible(TRUE)
}

xgelo_feature_cutoff_date <- function(default = Sys.Date() - 1L) {
  value <- Sys.getenv("XGELO_FEATURE_CUTOFF_DATE", unset = "")
  if (!nzchar(value)) return(as.Date(default))
  parsed <- as.Date(value)
  if (is.na(parsed)) {
    stop("XGELO_FEATURE_CUTOFF_DATE must parse as an ISO date, for example 2026-06-10", call. = FALSE)
  }
  parsed
}

xgelo_model_training_cutoff_date <- function(default = Sys.Date()) {
  value <- Sys.getenv("XGELO_MODEL_TRAINING_CUTOFF_DATE", unset = "")
  if (!nzchar(value)) return(as.Date(default))
  parsed <- as.Date(value)
  if (is.na(parsed)) {
    stop("XGELO_MODEL_TRAINING_CUTOFF_DATE must parse as an ISO date, for example 2026-06-12", call. = FALSE)
  }
  parsed
}

# Phase 19 targets carry typed status objects through every edge.  A blocked
# prerequisite is data, not an exception: downstream targets preserve its
# stable reason and must not fit, publish, or advance a selector.
phase19_targets_blocked <- function(reason_code, upstream = NULL) {
  list(
    schema_version = "phase19-club-target-state-v1",
    forecast_domain = "club", authority_mode = "production",
    fixture_authority = FALSE, production_eligible = FALSE,
    status = "blocked", reason_code = as.character(reason_code),
    upstream_reason = if (is.null(upstream)) "" else {
      value <- upstream$reason_code
      if (is.null(value) || !length(value)) "" else as.character(value[[1L]])
    }
  )
}

phase19_targets_state <- function(loader, fallback_reason) {
  result <- tryCatch(loader(), error = function(error) NULL)
  if (is.null(result) || !is.list(result)) {
    return(phase19_targets_blocked(fallback_reason))
  }
  status <- if (!is.null(result$status) && length(result$status)) {
    as.character(result$status[[1L]])
  } else "blocked"
  if (!identical(status, "ready")) {
    reason <- result$reason_code
    if (is.null(reason) || !length(reason) || !nzchar(as.character(reason[[1L]]))) {
      reason <- fallback_reason
    }
    return(phase19_targets_blocked(reason, result))
  }
  list(
    schema_version = "phase19-club-target-state-v1",
    forecast_domain = "club", authority_mode = "production",
    fixture_authority = FALSE, production_eligible = TRUE,
    status = "ready", reason_code = "", authority = result
  )
}

phase19_targets_first_blocked <- function(...) {
  states <- list(...)
  for (state in states) {
    if (is.list(state) && identical(as.character(state$status[[1L]]), "blocked")) {
      reason <- state$reason_code
      if (!is.null(reason) && length(reason) && nzchar(as.character(reason[[1L]]))) {
        return(as.character(reason[[1L]]))
      }
    }
  }
  ""
}

phase19_targets_file_inventory <- function(root, filenames = character()) {
  paths <- file.path(root, filenames)
  if (!length(paths) || any(!file.exists(paths)) || any(dir.exists(paths))) {
    stop("Phase 19 immutable authority file inventory is incomplete", call. = FALSE)
  }
  unname(paths)
}

phase19_targets_identity_state <- function(current) {
  reason <- phase19_targets_first_blocked(current)
  if (nzchar(reason)) return(phase19_targets_blocked(reason, current))
  list(
    schema_version = "phase19-club-target-state-v1",
    forecast_domain = "club", authority_mode = "production",
    fixture_authority = FALSE, production_eligible = TRUE,
    status = "ready", reason_code = "", authority = current$authority
  )
}

phase19_targets_protocol_state <- function(history, current, identity, files) {
  reason <- phase19_targets_first_blocked(history, current, identity)
  if (nzchar(reason)) return(phase19_targets_blocked(reason))
  phase19_targets_state(phase19_load_club_evaluation_protocol,
                        "protocol_policy_not_approved")
}

phase19_targets_fold_state <- function(history, current, identity, protocol,
                                       registry_file, review_file) {
  reason <- phase19_targets_first_blocked(history, current, identity, protocol)
  if (nzchar(reason)) return(phase19_targets_blocked(reason))
  registry <- tryCatch(
    utils::read.csv(registry_file, stringsAsFactors = FALSE, check.names = FALSE),
    error = function(error) NULL
  )
  review <- tryCatch(
    phase19_protocol_read_review(review_file), error = function(error) NULL
  )
  if (is.null(registry) || is.null(review)) {
    return(phase19_targets_blocked("fold_inventory_not_approved"))
  }
  valid <- tryCatch({
    phase19_validate_fold_registry(
      registry, history$authority, protocol$authority, "production"
    )
    phase19_validate_fold_review(review, protocol$authority, registry,
                                 history$authority, "production")
    TRUE
  }, error = function(error) FALSE)
  if (!isTRUE(valid)) return(phase19_targets_blocked("fold_inventory_not_approved"))
  list(
    schema_version = "phase19-club-target-state-v1",
    forecast_domain = "club", authority_mode = "production",
    fixture_authority = FALSE, production_eligible = TRUE,
    status = "ready", reason_code = "", registry = registry, review = review
  )
}

phase19_targets_passthrough_block <- function(...) {
  reason <- phase19_targets_first_blocked(...)
  if (nzchar(reason)) phase19_targets_blocked(reason) else {
    phase19_targets_blocked("fold_inventory_not_approved")
  }
}

# Phase 20 UCL target namespace.  This child environment deliberately has only
# base R plus the UCL/Phase 18 readers as parents; national target helpers are
# never imported into it.  The target bodies below carry typed blocked and
# unresolved values instead of manufacturing a schedule, release, or output.
ucl20_target_runtime_envir <- new.env(parent = baseenv())
for (ucl20_target_dependency in c(
  "R/common/phase18_canonical_hash.R",
  "R/competition/source_contracts.R",
  "R/competition/ucl_source_acceptance.R",
  "R/competition/ucl_source_bundle.R",
  "R/competition/ucl_source_refresh.R",
  "R/competition/match_state.R",
  "R/competition/standings.R",
  "R/competition/uefa_champions_league_rules.R",
  "R/competition/uefa_champions_league_state.R",
  "R/competition/uefa_champions_league_simulation.R",
  "R/competition/uefa_champions_league_outcomes.R"
)) {
  sys.source(ucl20_target_dependency, envir = ucl20_target_runtime_envir)
}

phase20_ucl_target_get <- function(name) {
  get(name, envir = ucl20_target_runtime_envir, inherits = TRUE)
}

phase20_ucl_target_blocked <- function(reason_code, message = "") {
  list(
    schema_version = "phase20-ucl-target-state-v1",
    edition_id = "ucl_2026_27", status = "blocked",
    reason_code = as.character(reason_code), message = as.character(message),
    authority_mode = "production", fixture_authority = FALSE,
    production_eligible = FALSE
  )
}

phase20_ucl_target_unresolved <- function(reason_code, message = "") {
  list(
    schema_version = "phase20-ucl-target-state-v1",
    edition_id = "ucl_2026_27", status = "unresolved",
    reason_code = as.character(reason_code), message = as.character(message),
    authority_mode = "production", fixture_authority = FALSE,
    production_eligible = FALSE
  )
}

phase20_ucl_target_first_issue <- function(...) {
  values <- list(...)
  for (value in values) {
    if (is.list(value) && identical(as.character(value$status), "blocked")) return(value)
    if (is.list(value) && identical(as.character(value$status), "unresolved")) return(value)
    if (is.list(value) && identical(as.character(value$status), "production_human_needed")) return(value)
  }
  NULL
}

phase20_ucl_target_source <- function() {
  accepted_root <- file.path(getwd(), "data/competition/accepted")
  registry_root <- file.path(getwd(), "data/competition/registries")
  reader <- phase20_ucl_target_get("phase18_read_ucl_refresh_current")
  current <- tryCatch(
    reader(accepted_root = accepted_root, registry_root = registry_root),
    error = function(error) list(error = if (!is.null(error$reason_code)) as.character(error$reason_code) else "no_accepted_current_ucl")
  )
  if (is.null(current)) return(phase20_ucl_target_blocked("no_accepted_current_ucl"))
  if (!is.null(current$error)) return(phase20_ucl_target_blocked(current$error))
  if (!identical(as.character(current$pointer$accepted_status), "accepted") ||
      is.null(current$accepted) || is.null(current$accepted$bundle)) {
    return(phase20_ucl_target_blocked("no_accepted_current_ucl"))
  }
  list(
    schema_version = "phase20-ucl-target-source-v1", edition_id = "ucl_2026_27",
    status = "ready", authority_mode = "production", fixture_authority = FALSE,
    production_eligible = TRUE, accepted = current$accepted, pointer = current$pointer
  )
}

phase20_ucl_target_rules <- function() {
  contract <- tryCatch(phase20_ucl_target_get(".ucl_rule_contract")(), error = function(error) error)
  if (inherits(contract, "error")) return(phase20_ucl_target_blocked("rules_evidence_invalid", conditionMessage(contract)))
  evidence <- contract$evidence
  draw <- evidence[as.character(evidence$document_id) == "draw_procedure_2026_27", , drop = FALSE]
  if (nrow(draw) == 1L && !isTRUE(draw$accepted[[1L]])) {
    return(list(
      schema_version = "phase20-ucl-target-rules-v1", edition_id = "ucl_2026_27",
      status = "unresolved", reason_code = "missing_edition_draw_procedure",
      message = "Edition draw procedure is not accepted; draw-conditioned paths remain suppressed.",
      evidence = evidence, rules = contract, authority_mode = "production",
      fixture_authority = FALSE, production_eligible = FALSE
    ))
  }
  list(
    schema_version = "phase20-ucl-target-rules-v1", edition_id = "ucl_2026_27",
    status = "ready", evidence = evidence, rules = contract,
    authority_mode = "production", fixture_authority = FALSE,
    production_eligible = TRUE
  )
}

phase20_ucl_target_parent_reason <- function(error) {
  reason <- if (is.list(error) && !is.null(error$reason_code)) as.character(error$reason_code[[1L]]) else "phase19_selector_not_accepted"
  if (reason %in% c("release_root_invalid", "release_artifact_missing", "release_dependency_missing", "release_preflight_stale")) {
    reason <- "no_accepted_club_history"
  }
  reason
}

phase20_ucl_target_state <- function(source, rules_evidence) {
  issue <- phase20_ucl_target_first_issue(source, rules_evidence)
  if (!is.null(issue)) return(issue)
  accepted <- source$accepted
  tables <- accepted$tables %||% accepted$artifacts
  if (!is.list(tables)) return(phase20_ucl_target_blocked("accepted_source_schema_invalid"))
  clubs <- tables$clubs %||% tables$teams
  fixtures <- tables$matches %||% tables$fixtures
  if (!is.data.frame(clubs) || !is.data.frame(fixtures)) return(phase20_ucl_target_blocked("accepted_source_schema_invalid"))
  resolver <- if (exists("phase19_resolve_production_club_release", mode = "function", inherits = TRUE)) phase19_resolve_production_club_release else NULL
  if (is.null(resolver)) return(phase20_ucl_target_blocked("no_accepted_club_history"))
  release <- tryCatch(resolver(), error = function(error) list(error = phase20_ucl_target_parent_reason(error)))
  if (!is.null(release$error)) return(phase20_ucl_target_blocked(release$error))
  graph <- list(
    edition_id = "ucl_2026_27", source_bundle_id = as.character(accepted$bundle$bundle_id[[1L]]),
    authority_mode = "production", fixture_authority = FALSE, production_eligible = TRUE,
    selector_path = NULL, production_root = NULL, clubs = clubs, fixtures = fixtures
  )
  state <- tryCatch(
    phase20_ucl_target_get("ucl_build_state")(graph, rules = rules_evidence$rules, evidence = rules_evidence$evidence),
    error = function(error) phase20_ucl_target_blocked("state_build_failed", conditionMessage(error))
  )
  if (is.list(state) && identical(as.character(state$status), "blocked")) return(state)
  state
}

phase20_ucl_target_passthrough <- function(value) {
  issue <- phase20_ucl_target_first_issue(value)
  if (!is.null(issue)) return(issue)
  value
}

list(
  tar_target(
    team_map,
    read.csv("data/raw/team_name_map.csv", stringsAsFactors = FALSE)
  ),
  tar_target(
    eloratings_fallback_files,
    download_eloratings_fallback_files()
  ),
  tar_target(
    espn_scoreboard_files,
    download_espn_scoreboard_files()
  ),
  tar_target(
    elo_matches,
    {
      eloratings_fallback_files
      espn_scoreboard_files
      preprocess_martj42()
    }
  ),
  tar_target(
    martj42_historical_normalized_file,
    {
      elo_matches
      phase13_load_martj42_historical_results(
        results_path = "data/processed/elo_matches.csv",
        identity_registry_path = "data/competition/registries/team_identity.csv",
        identity_map_path = "data/competition/registries/martj42_identity_map.csv",
        edition_lookup_path = "data/competition/registries/martj42_edition_lookup.csv",
        source_dataset = "martj42",
        source_artifact_id = "martj42-results",
        output_path = "data/processed/martj42_historical_normalized.csv"
      )
    },
    format = "file"
  ),
  tar_target(
    elo_result,
    compute_elo_optimized(elo_matches, team_map, home_advantage = 60)
  ),
  tar_target(
    elo_ratings_file,
    {
      write.csv(elo_result$ratings_history, "data/processed/elo_ratings.csv", row.names = FALSE)
      write.csv(elo_result$current_ratings, "data/processed/elo_current.csv", row.names = FALSE)
      "data/processed/elo_ratings.csv"
    },
    format = "file"
  ),
  tar_target(
    xg_split,
    prepare_and_split_data(
      events_dir = "data/raw/statsbomb/events",
      competitions_file = "data/raw/statsbomb/competitions.json",
      domestic_only = TRUE,
      competition_name = "La Liga",
      allow_unmapped_sample = TRUE
    )
  ),
  tar_target(
    xg_model,
    train_and_save_xg_model(xg_split$train_data)
  ),
  tar_target(
    xg_backtest,
    backtest_xg_model(xg_model, xg_split$test_data)
  ),
  tar_target(
    xg_calibration,
    calibrate_xg_model(xg_model, xg_split$test_data)
  ),
  tar_target(
    team_match_xg_file,
    {
      xg_model
      compute_team_match_xg(use_own_model = TRUE)
      "data/processed/team_match_xg.csv"
    },
    format = "file"
  ),
  tar_target(
    rolling_form_file,
    {
      team_match_xg_file
      elo_ratings_file
      compute_rolling_form()
      "data/processed/rolling_form.csv"
    },
    format = "file"
  ),
  tar_target(
    transfermarkt_squad_strength_file,
    {
      snapshot_path <- "data/raw/transfermarkt/transfermarkt-datasets.duckdb"
      use_transfermarkt <- isTRUE(getOption("xgelo.use_transfermarkt", file.exists(snapshot_path)))
      if (!use_transfermarkt || !file.exists(snapshot_path)) {
        NA_character_
      } else {
        compute_transfermarkt_squad_strength_snapshots(
          snapshot_path = snapshot_path,
          as_of_dates = sort(unique(c(
            seq(as.Date("2000-01-01"), Sys.Date(), by = "6 months"),
            as.Date("2024-06-14"),
            xgelo_feature_cutoff_date(),
            xgelo_model_training_cutoff_date(),
            Sys.Date()
          ))),
          output_path = "data/processed/transfermarkt_squad_strength.csv"
        )
        write_transfermarkt_snapshot_metadata()
        "data/processed/transfermarkt_squad_strength.csv"
      }
    }
  ),
  tar_target(
    transfermarkt_value_audit_file,
    {
      snapshot_path <- "data/raw/transfermarkt/transfermarkt-datasets.duckdb"
      if (
        is.na(transfermarkt_squad_strength_file) ||
          !file.exists(transfermarkt_squad_strength_file) ||
          !file.exists(snapshot_path)
      ) {
        NA_character_
      } else {
        groups <- read.csv("data/raw/worldcup_2026_groups.csv", stringsAsFactors = FALSE)
        audit_transfermarkt_value_divergence(
          squad_strength = transfermarkt_squad_strength_file,
          snapshot_path = snapshot_path,
          teams = groups$team,
          cutoff_date = xgelo_feature_cutoff_date(),
          output_path = "data/processed/transfermarkt_value_audit.csv"
        )
        "data/processed/transfermarkt_value_audit.csv"
      }
    },
    format = "file"
  ),
  tar_target(
    home_goal_model,
    {
      elo_ratings_file
      train_home_goal_model()
    }
  ),
  tar_target(
    away_goal_model,
    {
      elo_ratings_file
      train_away_goal_model()
    }
  ),
  tar_target(
    hybrid_goal_training_features_file,
    {
      if (is.na(transfermarkt_squad_strength_file) || !file.exists(transfermarkt_squad_strength_file)) {
        NA_character_
      } else {
        matches <- read.csv("data/processed/elo_matches.csv", stringsAsFactors = FALSE)
        matches$date <- as.Date(matches$date)
        training <- matches[
          matches$date < xgelo_model_training_cutoff_date() &
            !is.na(matches$home_score) &
            !is.na(matches$away_score) &
            !is.na(matches$home_team_canonical) &
            !is.na(matches$away_team_canonical),
          ,
          drop = FALSE
        ]
        training$match_id <- make.unique(as.character(training$match_id), sep = "__")
        elo <- read.csv("data/processed/elo_ratings.csv", stringsAsFactors = FALSE)
        rolling <- if (file.exists("data/processed/rolling_form.csv")) read.csv("data/processed/rolling_form.csv", stringsAsFactors = FALSE) else NULL
        squad <- read.csv(transfermarkt_squad_strength_file, stringsAsFactors = FALSE)
        ability <- suppressWarnings(compute_goal_ability_features(training, matches))
        features <- build_forecast_feature_table(
          matches = training,
          elo_ratings = elo,
          rolling_form = rolling,
          squad_strength = squad,
          goal_ability = ability
        )
        assert_no_feature_leakage(features)
        validate_forecast_feature_evidence(
          features,
          read.csv("data/benchmark/phase09/feature_contract.csv", stringsAsFactors = FALSE),
          derived_mappings = c(
            elo_difference_for_team = "elo_diff",
            venue_advantage_for_team = "elo_diff"
          )
        )
        output_path <- "data/processed/goal_training_features_hybrid.csv"
        write.csv(features, output_path, row.names = FALSE)
        output_path
      }
    },
    format = "file"
  ),
  tar_target(
    home_goal_model_hybrid,
    {
      if (is.na(hybrid_goal_training_features_file) || !file.exists(hybrid_goal_training_features_file)) {
        NA_character_
      } else {
        train_home_goal_model(
          feature_table_path = hybrid_goal_training_features_file,
          model_path = "models/home_goal_model_hybrid.rds",
          predictors = hybrid_goal_predictors(),
          model_version = "hybrid"
        )
      }
    }
  ),
  tar_target(
    away_goal_model_hybrid,
    {
      if (is.na(hybrid_goal_training_features_file) || !file.exists(hybrid_goal_training_features_file)) {
        NA_character_
      } else {
        train_away_goal_model(
          feature_table_path = hybrid_goal_training_features_file,
          model_path = "models/away_goal_model_hybrid.rds",
          predictors = hybrid_goal_predictors(),
          model_version = "hybrid"
        )
      }
    }
  ),
  tar_target(
    xg_feature_usage_audit_file,
    {
      if (
        is.na(hybrid_goal_training_features_file) ||
          !file.exists(hybrid_goal_training_features_file) ||
          !file.exists("models/home_goal_model_hybrid.rds") ||
          !file.exists("models/away_goal_model_hybrid.rds")
      ) {
        NA_character_
      } else {
        audit_xg_feature_usage(
          feature_table = hybrid_goal_training_features_file,
          home_model = "models/home_goal_model_hybrid.rds",
          away_model = "models/away_goal_model_hybrid.rds",
          rolling_form = "data/processed/rolling_form.csv",
          forecast_features = if (file.exists("data/processed/worldcup_2026_forecast_features_hybrid.csv")) {
            "data/processed/worldcup_2026_forecast_features_hybrid.csv"
          } else {
            NULL
          },
          output_path = "data/processed/xg_feature_usage_audit.csv"
        )
        "data/processed/xg_feature_usage_audit.csv"
      }
    },
    format = "file"
  ),
  tar_target(
    worldcup_forecast_features_file,
    {
      if (is.na(transfermarkt_squad_strength_file) || !file.exists(transfermarkt_squad_strength_file)) {
        NA_character_
      } else {
        groups <- load_worldcup_2026_groups()
        fixtures <- make_worldcup_group_fixtures(groups)
        matches <- read.csv("data/processed/elo_matches.csv", stringsAsFactors = FALSE)
        elo <- read.csv("data/processed/elo_ratings.csv", stringsAsFactors = FALSE)
        rolling <- if (file.exists("data/processed/rolling_form.csv")) read.csv("data/processed/rolling_form.csv", stringsAsFactors = FALSE) else NULL
        squad <- read.csv(transfermarkt_squad_strength_file, stringsAsFactors = FALSE)
        features <- build_worldcup_forecast_feature_table(
          groups = groups,
          fixtures = fixtures,
          history_matches = matches,
          elo_ratings = elo,
          rolling_form = rolling,
          squad_strength = squad,
          feature_cutoff_date = xgelo_feature_cutoff_date(),
          output_path = "data/processed/worldcup_2026_forecast_features_hybrid.csv"
        )
        assert_worldcup_forecast_features(
          features,
          fixtures = fixtures,
          teams = groups$team,
          predictors = hybrid_goal_predictors(),
          cutoff_date = xgelo_feature_cutoff_date()
        )
        "data/processed/worldcup_2026_forecast_features_hybrid.csv"
      }
    },
    format = "file"
  ),
  tar_target(
    forecasts,
    {
      home_goal_model
      away_goal_model
      fixtures <- data.frame(
        home_team = c("Spain", "Germany", "France"),
        away_team = c("Italy", "Netherlands", "England"),
        date = as.Date(c("2026-06-10", "2026-06-11", "2026-06-12")),
        venue = c("home", "home", "neutral"),
        stringsAsFactors = FALSE
      )
      generate_batch_forecasts(fixtures)
    }
  ),
  tar_target(
    forecast_calibration,
    {
      forecasts
      calibrate_model(n_sample = 100, n_sim = 1000)
    }
  ),
  tar_target(
    euro2024_benchmark,
    {
      elo_ratings_file
      rolling_form_file
      transfermarkt_squad_strength_file
      run_euro2024_benchmark(output_dir = "outputs/benchmarks/euro2024_transfermarkt_regularized")
    }
  ),
  tar_target(
    validation,
    {
      forecast_calibration
      run_validation_checks()
    }
  ),
  tar_target(
    auc_chart,
    {
      xg_backtest
      generate_auc_chart()
    }
  ),
  tar_target(
    calibration_plots,
    {
      forecast_calibration
      xg_calibration
      run_calibration_plots()
    }
  ),
  tar_target(
    worldcup_dashboard_file,
    {
      phase12_approved_release
      elo_ratings_file
      dashboard <- build_worldcup_dashboard(
        n_match_sim = 5000,
        n_tournaments = 5000,
        feature_cutoff_date = xgelo_feature_cutoff_date(),
        release_root = "outputs/releases",
        approved_release = phase12_approved_release
      )
      dashboard$paths$html
    },
    format = "file"
  ),
  tar_target(
    worldcup_pages_file,
    {
      worldcup_dashboard_file
      publish_worldcup_dashboard_pages()
    },
    format = "file"
  ),
  tar_target(
    benchmark_phase09_registry_files,
    file.path("data/benchmark/phase09", c(
      "tournaments.csv", "fixtures.csv", "teams.csv", "formats.csv",
      "route_rules.csv", "corrections.csv", "boundaries.csv", "panels.csv",
      "panel_fixtures.csv", "model_registry.csv", "score_support_audit.csv",
      "feature_contract.csv", "seed_registry.csv", "promotion_protocol.json"
    )),
    format = "file"
  ),
  tar_target(
    benchmark_phase09_registries,
    {
      benchmark_phase09_registry_files
      registry_dir <- "data/benchmark/phase09"
      registries <- load_benchmark_registries(registry_dir)
      inputs <- benchmark_runner_load_inputs(registry_dir)
      protocol <- load_promotion_protocol(file.path(registry_dir, "promotion_protocol.json"))
      validate_promotion_protocol(protocol, registry_dir = registry_dir)
      list(registries = registries, inputs = inputs, protocol = protocol)
    }
  ),
  tar_target(
    benchmark_phase09_boundaries,
    {
      context <- benchmark_phase09_registries
      inventory <- benchmark_runner_boundary_inventory(context$registries$boundaries)
      validate_score_support_audit(
        context$inputs$score_support_audit,
        context$inputs$model_registry,
        inventory
      )
      list(context = context, boundary_inventory = inventory)
    }
  ),
  tar_target(
    benchmark_phase09_predictions,
    {
      execution <- benchmark_phase09_boundaries
      score_support_audit <- execution$context$inputs$score_support_audit
      selected_g <- unique(as.integer(score_support_audit$selected_g))
      feature_input <- hybrid_goal_training_features_file
      if (length(feature_input) != 1L || is.na(feature_input) || !file.exists(feature_input)) {
        stop("Phase 9 benchmark requires the canonical hybrid goal training feature file")
      }
      history <- read.csv(feature_input, stringsAsFactors = FALSE)
      validate_forecast_feature_evidence(
        history,
        execution$context$inputs$feature_contract,
        derived_mappings = c(
          elo_difference_for_team = "elo_diff",
          venue_advantage_for_team = "elo_diff"
        )
      )
      date_column <- if ("date" %in% names(history)) "date" else "actual_completion_date"
      history <- history[
        as.Date(history[[date_column]]) <= max(as.Date(execution$context$registries$fixtures$actual_completion_date)),
        , drop = FALSE
      ]
      guard_benchmark_purpose(history, "baseline_reproduction")
      bundle <- benchmark_default_execution_engine(
        history = history,
        registries = execution$context$registries,
        inputs = execution$context$inputs,
        boundary_inventory = execution$boundary_inventory,
        protocol = execution$context$protocol,
        run_id = "phase09-baselines-frozen",
        purpose = "baseline_reproduction",
        branch_order = execution$context$inputs$model_registry$model_id,
        selected_g = selected_g
      )
      additional_inputs <- benchmark_runner_additional_input_specs(
        "data/benchmark/phase09", feature_input
      )
      list(
        bundle = bundle, execution = execution,
        score_support_audit = score_support_audit,
        additional_inputs = additional_inputs
      )
    }
  ),
  tar_target(
    benchmark_phase09_stage_probabilities,
    {
      benchmark_phase09_predictions$bundle$feature_coverage
      benchmark_phase09_predictions$bundle$stage_probabilities
    }
  ),
  tar_target(
    benchmark_phase09_scores,
    {
      benchmark_phase09_predictions$bundle$fixture_predictions
      benchmark_phase09_predictions$bundle$score_distributions
      list(
        fixture_scores = benchmark_phase09_predictions$bundle$fixture_scores,
        benchmark_summaries = benchmark_phase09_predictions$bundle$benchmark_summaries
      )
    }
  ),
  tar_target(
    benchmark_phase09_comparisons,
    {
      benchmark_phase09_scores
      feature_coverage <- benchmark_phase09_predictions$bundle$feature_coverage
      list(
        paired_comparisons = benchmark_phase09_predictions$bundle$paired_comparisons,
        promotion_decisions = benchmark_phase09_predictions$bundle$promotion_decisions,
        feature_coverage = feature_coverage
      )
    }
  ),
  tar_target(
    benchmark_phase09_bundle_files,
    {
      benchmark_phase09_stage_probabilities
      benchmark_phase09_scores
      benchmark_phase09_comparisons
      execution <- benchmark_phase09_predictions$execution
      result <- write_rolling_benchmark_bundle(
        benchmark_phase09_predictions$bundle,
        "outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen",
        execution$context$inputs$score_support_audit,
        execution$context$inputs$model_registry,
        execution$boundary_inventory,
        additional_inputs = benchmark_phase09_predictions$additional_inputs,
        panel_fixtures = execution$context$inputs$panel_fixtures,
        feature_contract = execution$context$inputs$feature_contract
      )
      unname(result$paths)
    },
    format = "file"
  ),
  tar_target(
    benchmark_phase10_registry_files,
    c(
      file.path("data/benchmark/phase10", c(
        "model_registry.csv", "feature_contract.csv", "tuning_editions.csv",
        "tuning_grid.csv", "ablation_registry.csv", "selection_protocol.json",
        "storage_preflight.csv", "glmnet_provenance.csv"
      )),
      file.path("data/benchmark/phase09", c(
        "tournaments.csv", "fixtures.csv", "teams.csv", "formats.csv",
        "route_rules.csv", "corrections.csv", "boundaries.csv", "panels.csv",
        "panel_fixtures.csv", "model_registry.csv", "score_support_audit.csv",
        "feature_contract.csv", "seed_registry.csv"
      )),
      file.path(
        "outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen",
        c(
          "run_manifest.csv", "manifests/checksum_manifest.csv",
          "scores/fixture_scores.csv"
        )
      ),
      "data/processed/goal_training_features_hybrid.csv"
    ),
    format = "file"
  ),
  tar_target(
    benchmark_phase10_registries,
    {
      benchmark_phase10_registry_files
      phase09_dir <- "data/benchmark/phase09"
      phase10_dir <- "data/benchmark/phase10"
      environment <- require_challenger_environment(
        file.path(phase10_dir, "glmnet_provenance.csv")
      )
      protocol <- load_and_validate_challenger_protocol(phase10_dir)
      phase09_registries <- load_benchmark_registries(phase09_dir)
      phase09_inputs <- benchmark_runner_load_inputs(phase09_dir)
      parent <- load_phase09_parent_bundle(
        "outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen"
      )
      feature_input <- "data/processed/goal_training_features_hybrid.csv"
      feature_input_sha256 <- benchmark_runner_file_sha256(feature_input)
      list(
        environment = environment, protocol = protocol,
        phase09_registries = phase09_registries, phase09_inputs = phase09_inputs,
        parent = parent, feature_input = feature_input,
        feature_input_sha256 = feature_input_sha256
      )
    }
  ),
  tar_target(
    benchmark_phase10_predictions,
    {
      context <- benchmark_phase10_registries
      history <- read.csv(context$feature_input, stringsAsFactors = FALSE)
      validate_forecast_feature_evidence(
        history, context$phase09_inputs$feature_contract,
        derived_mappings = c(
          elo_difference_for_team = "elo_diff",
          venue_advantage_for_team = "elo_diff"
        )
      )
      history <- .phase10_runner_prepare_history(history, context$protocol)
      date_column <- if ("date" %in% names(history)) "date" else "actual_completion_date"
      history <- history[
        as.Date(history[[date_column]]) <= max(as.Date(
          context$phase09_registries$fixtures$actual_completion_date
        )),
        , drop = FALSE
      ]
      guard_benchmark_purpose(history, "candidate_selection")
      tracks <- lapply(c("frozen", "updating"), function(track_id) {
        benchmark_runner_track_fixtures(
          context$phase09_registries$fixtures,
          context$phase09_registries$tournaments,
          context$phase09_registries$boundaries,
          context$phase09_registries$teams,
          history, track_id, context$phase09_inputs$feature_contract
        )
      })
      fixtures <- do.call(rbind, tracks)
      run_statistical_challenger_benchmark(
        history = history, fixtures = fixtures,
        seed_registry = context$phase09_inputs$seed_registry,
        synthetic = FALSE, publish = FALSE
      )
    }
  ),
  tar_target(
    benchmark_phase10_scores,
    {
      benchmark_phase10_predictions$fixture_predictions
      benchmark_phase10_predictions$score_distributions
      list(
        fixture_scores = benchmark_phase10_predictions$fixture_scores,
        benchmark_summaries = benchmark_phase10_predictions$benchmark_summaries
      )
    }
  ),
  tar_target(
    benchmark_phase10_comparisons,
    {
      benchmark_phase10_scores
      list(
        all_baseline_paired_comparisons =
          benchmark_phase10_predictions$all_baseline_paired_comparisons,
        shortlist = benchmark_phase10_predictions$shortlist
      )
    }
  ),
  tar_target(
    benchmark_phase10_bundle_files,
    {
      benchmark_phase10_comparisons
      write_statistical_challenger_bundle(
        benchmark_phase10_predictions,
        "outputs/benchmarks/rolling_tournaments/phase10-statistical-challengers"
      )
      unname(phase10_output_paths(
        "outputs/benchmarks/rolling_tournaments/phase10-statistical-challengers"
      ))
    },
    format = "file"
  ),
  tar_target(
    benchmark_phase11_registry_files,
    {
      phase11_dir <- "data/benchmark/phase11"
      phase09_dir <- "data/benchmark/phase09"
      phase10_dir <- "data/benchmark/phase10"
      phase09_output <- "outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen"
      phase10_output <- "outputs/benchmarks/rolling_tournaments/phase10-statistical-challengers"
      phase11_protocol_files <- file.path(phase11_dir, c(
        "model_registry.csv", "feature_contract.csv", "context_ablation_registry.csv",
        "ranger_provenance.csv", "country_centroids.csv", "country_centroids_metadata.csv",
        "structural_sources.csv", "structural_sources_metadata.csv",
        "structural_sources_checksums.csv", "xg_gate_manifest.csv",
        "structural_prior_manifest.csv", "mode_registry.csv", "manual_market_manifest.csv"
      ))
      phase09_registry_files <- file.path(phase09_dir, c(
        "tournaments.csv", "fixtures.csv", "teams.csv", "formats.csv",
        "route_rules.csv", "corrections.csv", "boundaries.csv", "panels.csv",
        "panel_fixtures.csv", "model_registry.csv", "score_support_audit.csv",
        "feature_contract.csv", "seed_registry.csv"
      ))
      phase10_protocol_files <- file.path(phase10_dir, c(
        "model_registry.csv", "feature_contract.csv", "tuning_editions.csv",
        "tuning_grid.csv", "ablation_registry.csv", "selection_protocol.json",
        "storage_preflight.csv", "glmnet_provenance.csv"
      ))
      phase09_bundle_files <- file.path(phase09_output, c(
        "run_manifest.csv", "manifests/checksum_manifest.csv", "scores/fixture_scores.csv"
      ))
      phase10_bundle_files <- file.path(phase10_output, c(
        "run_manifest.csv", "manifests/checksum_manifest.csv", "manifests/model_manifests.csv",
        "manifests/feature_coverage.csv", "manifests/fold_tuning.csv",
        "predictions/fixture_predictions.csv", "predictions/score_distributions.csv",
        "scores/fixture_scores.csv", "scores/benchmark_summaries.csv",
        "comparisons/all_baseline_paired_comparisons.csv", "selection/shortlist.csv",
        "selection/statistical_challenger_report.md"
      ))
      optional_local <- c("data/processed/transfermarkt_squad_strength.csv")
      c(
        phase11_protocol_files, phase09_registry_files, phase10_protocol_files,
        phase09_bundle_files, phase10_bundle_files,
        "data/processed/elo_ratings.csv",
        "data/processed/goal_training_features_hybrid.csv",
        optional_local[file.exists(optional_local)]
      )
    },
    format = "file"
  ),
  tar_target(
    benchmark_phase11_registries,
    {
      phase11_library <- normalizePath("data/cache/phase11-library", mustWork = TRUE)
      .libPaths(unique(c(phase11_library, .libPaths())))
      benchmark_phase11_registry_files
      phase09_dir <- "data/benchmark/phase09"
      phase10_dir <- "data/benchmark/phase10"
      phase11_dir <- "data/benchmark/phase11"
      phase09_output <- "outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen"
      phase10_output <- "outputs/benchmarks/rolling_tournaments/phase10-statistical-challengers"
      environment <- require_hybrid_environment(
        file.path(phase11_dir, "ranger_provenance.csv"), offline = TRUE
      )
      protocol <- load_and_validate_hybrid_protocol(phase11_dir)
      phase09_registries <- load_benchmark_registries(phase09_dir)
      phase09_inputs <- benchmark_runner_load_inputs(phase09_dir)
      phase09_parent <- load_phase09_parent_bundle(phase09_output)
      phase10_protocol <- load_and_validate_challenger_protocol(phase10_dir)
      phase10_validation <- validate_statistical_challenger_bundle(phase10_output)
      phase10_fixture_scores <- read.csv(
        file.path(phase10_output, "scores/fixture_scores.csv"),
        stringsAsFactors = FALSE, check.names = FALSE
      )
      phase10_comparisons <- read.csv(
        file.path(phase10_output, "comparisons/all_baseline_paired_comparisons.csv"),
        stringsAsFactors = FALSE, check.names = FALSE
      )
      phase10_shortlist <- read.csv(
        file.path(phase10_output, "selection/shortlist.csv"),
        stringsAsFactors = FALSE, check.names = FALSE
      )
      phase09_fixture_scores <- challenger_selection_scores(
        phase09_parent$fixture_scores_path,
        phase09_parent$fixture_scores_sha256
      )
      parent_paths <- hybrid_phase11_parent_paths()
      parent_hashes <- hybrid_phase11_parent_hashes(parent_paths)
      feature_input <- "data/processed/goal_training_features_hybrid.csv"
      list(
        environment = environment,
        protocol = protocol,
        phase09_registries = phase09_registries,
        phase09_inputs = phase09_inputs,
        phase09_parent = phase09_parent,
        phase09_fixture_scores = phase09_fixture_scores,
        phase10_protocol = phase10_protocol,
        phase10_validation = phase10_validation,
        phase10_fixture_scores = phase10_fixture_scores,
        phase10_comparisons = phase10_comparisons,
        phase10_shortlist = phase10_shortlist,
        feature_input = feature_input,
        feature_input_sha256 = benchmark_runner_file_sha256(feature_input),
        phase11_dir = phase11_dir,
        mode_registry = protocol$mode_registry,
        parent_paths = parent_paths,
        parent_hashes = parent_hashes,
        parent_graph_sha256 = challenger_selection_parent_graph_sha256(parent_hashes)
      )
    }
  ),
  tar_target(
    benchmark_phase11_predictions,
    {
      context <- benchmark_phase11_registries
      history <- read.csv(context$feature_input, stringsAsFactors = FALSE, check.names = FALSE)
      validate_forecast_feature_evidence(
        history, context$phase09_inputs$feature_contract,
        derived_mappings = c(
          elo_difference_for_team = "elo_diff",
          venue_advantage_for_team = "elo_diff"
        )
      )
      history <- .phase10_runner_prepare_history(history, context$phase10_protocol)
      history <- history[
        as.Date(history$date) <= max(as.Date(context$phase09_registries$fixtures$actual_completion_date)),
        , drop = FALSE
      ]
      guard_benchmark_purpose(history, "candidate_selection")
      tracks <- lapply(c("frozen", "updating"), function(track_id) {
        benchmark_runner_track_fixtures(
          context$phase09_registries$fixtures,
          context$phase09_registries$tournaments,
          context$phase09_registries$boundaries,
          context$phase09_registries$teams,
          history, track_id, context$phase09_inputs$feature_contract
        )
      })
      fixtures <- do.call(rbind, tracks)
      dynamic <- hybrid_prepare_dynamic_history_and_fixtures(history, fixtures)
      history <- dynamic$history
      dynamic_features <- setdiff(
        names(dynamic$fixtures),
        c("fixture_id", "actual_completion_date", "evidence_cutoff_exclusive", "home_team_id", "away_team_id")
      )
      for (column in dynamic_features) fixtures[[column]] <- dynamic$fixtures[[column]]
      baseline_ids <- c(
        context$phase09_parent$baseline_ids,
        as.character(context$phase10_shortlist$challenger_id)
      )
      run_hybrid_challenger_benchmark(
        history = history,
        fixtures = fixtures,
        seed_registry = context$phase09_inputs$seed_registry,
        candidate_order = hybrid_phase11_candidate_ids(context$protocol),
        run_id = "phase11-hybrid-challenger-benchmark",
        publish = FALSE,
        output_dir = "outputs/benchmarks/rolling_tournaments/phase11-hybrid-challengers",
        protocol = context$protocol,
        comparison_scores = rbind(context$phase09_fixture_scores, context$phase10_fixture_scores),
        comparison_tournaments = context$phase09_registries$tournaments,
        comparison_panel_fixtures = context$phase09_inputs$panel_fixtures,
        comparison_baseline_ids = baseline_ids,
        parent_hashes = context$parent_hashes,
        mode_registry = context$mode_registry,
        synthetic = FALSE
      )
    }
  ),
  tar_target(
    benchmark_phase11_scores,
    {
      benchmark_phase11_predictions$predictions
      benchmark_phase11_predictions$distributions
      list(
        fixture_scores = benchmark_phase11_predictions$scores,
        benchmark_summaries = benchmark_phase11_predictions$benchmark_summaries
      )
    }
  ),
  tar_target(
    benchmark_phase11_comparisons,
    {
      benchmark_phase11_scores
      list(
        all_baseline_paired_comparisons = benchmark_phase11_predictions$comparisons,
        hybrid_shortlist = benchmark_phase11_predictions$shortlist,
        candidate_evidence = benchmark_phase11_predictions$candidate_evidence,
        mode_companion_evidence = benchmark_phase11_predictions$mode_companion_evidence
      )
    }
  ),
  tar_target(
    benchmark_phase11_bundle_files,
    {
      benchmark_phase11_comparisons
      write_hybrid_challenger_bundle(
        benchmark_phase11_predictions,
        "outputs/benchmarks/rolling_tournaments/phase11-hybrid-challengers"
      )
      unname(hybrid_output_paths(
        "outputs/benchmarks/rolling_tournaments/phase11-hybrid-challengers"
      ))
    },
    format = "file"
  ),
  tar_target(
    phase12_calibration_recipe_file,
    "data/benchmark/phase12/calibration_recipe.json",
    format = "file"
  ),
  tar_target(
    phase12_freeze_manifest_file,
    {
      phase12_calibration_recipe_file
      benchmark_phase11_bundle_files
      path <- "data/benchmark/phase12/freeze_manifest.csv"
      validate_phase12_freeze_manifest(path)
      path
    },
    format = "file"
  ),
  tar_target(
    phase12_calibration_gate_files,
    {
      phase12_calibration_recipe_file
      phase12_freeze_manifest_file
      paths <- file.path(
        "outputs/benchmarks/rolling_tournaments/phase12-calibration-release/calibration",
        c("calibration_gate.csv", "calibrators.rds", "inner_oof_predictions.csv")
      )
      if (any(!file.exists(paths))) stop("Phase 12 calibration gate artifacts are incomplete", call. = FALSE)
      paths
    },
    format = "file"
  ),
  tar_target(
    phase12_final_fit_manifest_file,
    {
      phase12_calibration_gate_files
      phase12_freeze_manifest_file
      path <- "outputs/benchmarks/rolling_tournaments/phase12-calibration-release/final_evaluation/final_fit/final_fit_manifest.csv"
      if (!file.exists(path)) stop("Phase 12 final-fit manifest is missing", call. = FALSE)
      validate_phase12_final_fit_manifest(path)
      path
    },
    format = "file"
  ),
  tar_target(
    phase12_final_evaluation_approval,
    {
      phase12_final_fit_manifest_file
      phase12_calibration_gate_files
      phase12_freeze_manifest_file
      approval_state <- Sys.getenv("XGELO_PHASE12_APPROVAL_STATE", unset = "pending")
      preflight <- phase12_preflight_final_evaluation(
        freeze_manifest = phase12_freeze_manifest_file,
        calibration_gate = phase12_calibration_gate_files[[1L]],
        final_state = list(
          approval_state = approval_state,
          holdout_state = "unopened",
          label_path = phase12_final_evaluation_allowlisted_label_path()
        ),
        protocol = "data/benchmark/phase09/promotion_protocol.json"
      )
      if (!isTRUE(preflight$can_open)) stop("Phase 12 final-label approval is pending", call. = FALSE)
      list(approval_state = approval_state, preflight = preflight)
    }
  ),
  tar_target(
    phase12_final_labels,
    {
      phase12_final_evaluation_approval
      label_path <- phase12_final_evaluation_allowlisted_label_path()
      output_path <- "outputs/benchmarks/rolling_tournaments/phase12-calibration-release/final_evaluation/labels.csv"
      if (!file.exists(output_path)) {
        opened <- phase12_open_final_labels(
          label_path = label_path,
          expected_source_sha256 = "7dd366f457460c435ca3b8bdf9a456cc85903ee639d31f29bbd9c62ff604e1dc",
          approval_state = "approved"
        )
        phase12_final_evaluation_write_once(opened$data, output_path, "Phase 12 copied labels")
      }
      output_path
    },
    format = "file"
  ),
  tar_target(
    phase12_final_evaluation_manifest_file,
    {
      phase12_final_labels
      path <- "outputs/benchmarks/rolling_tournaments/phase12-calibration-release/manifests/final_evaluation_manifest.csv"
      validate_phase12_final_evaluation_manifest(path)
      path
    },
    format = "file"
  ),
  tar_target(
    phase12_promotion_report_file,
    {
      phase12_final_evaluation_manifest_file
      path <- "outputs/benchmarks/rolling_tournaments/phase12-calibration-release/manifests/promotion_report.csv"
      if (!file.exists(path)) stop("Phase 12 promotion report is missing", call. = FALSE)
      path
    },
    format = "file"
  ),
  tar_target(
    phase12_release_bundle_files,
    {
      phase12_final_evaluation_manifest_file
      phase12_promotion_report_file
      phase12_freeze_manifest_file
      phase12_calibration_gate_files
      benchmark_phase11_bundle_files
      root <- "outputs/releases"
      files <- list.files(root, recursive = TRUE, full.names = TRUE, all.files = FALSE)
      files <- files[!dir.exists(files)]
      if (!length(files)) stop("Phase 12 approved release bundle is missing", call. = FALSE)
      release_manifests <- files[basename(files) == "release_manifest.csv"]
      if (length(release_manifests) != 1L) stop("Phase 12 release bundle resolution is ambiguous", call. = FALSE)
      validate_phase12_complete_release_bundle(dirname(release_manifests[[1L]]))
      files
    },
    format = "file"
  ),
  tar_target(
    phase12_approved_release,
    {
      phase12_release_bundle_files
      resolve_phase12_approved_release("outputs/releases")
    }
  ),
  tar_target(
    worldcup_retrospective_ledger_bundle,
    write_forecast_ledger_bundle(
      source_ref = "HEAD",
      output_dir = "outputs/evaluation/wc2026"
    )
  ),
  tar_target(
    worldcup_retrospective_score_files,
    {
      bundle <- worldcup_retrospective_ledger_bundle
      output_dir <- "outputs/evaluation/wc2026"
      distributions <- readRDS(file.path(output_dir, "selected_distributions.rds"))
      scores <- score_worldcup_matches(bundle$selected, distributions$scorelines)
      aggregates <- aggregate_worldcup_scores(scores)
      calibration <- make_calibration_bins(bundle$selected)
      advancement <- score_knockout_advancement(bundle$selected)
      anchors <- select_stage_reach_anchors(bundle$selected, distributions$stage, bundle$fixtures)
      stages <- score_stage_reach(anchors, distributions$stage, bundle$fixtures)
      write_worldcup_score_bundle(scores, aggregates, calibration, advancement, stages, output_dir)
      file.path(output_dir, c(
        "match_scores.csv", "aggregate_scores.csv", "calibration_bins.csv",
        "advancement_scores.csv", "stage_reach_scores.csv", "score_manifest.csv"
      ))
    },
    format = "file"
  ),
  tar_target(
    worldcup_retrospective_figure_files,
    {
      worldcup_retrospective_score_files
      generate_worldcup_retrospective_figures("outputs/evaluation/wc2026")
    },
    format = "file"
  ),
  tar_target(
    worldcup_retrospective_report_file,
    {
      worldcup_retrospective_figure_files
      output_dir <- normalizePath("outputs/evaluation/wc2026")
      output_path <- file.path(output_dir, "worldcup_2026_retrospective.html")
      rmarkdown::render(
        "notebooks/worldcup_2026_retrospective.Rmd",
        output_file = basename(output_path), output_dir = dirname(output_path),
        params = list(output_dir = output_dir),
        envir = new.env(parent = globalenv()), quiet = TRUE
      )
      output_path
    },
    format = "file"
  ),
  tar_target(
    club_history_pointer_file,
    "data/club/history_current.json",
    format = "file"
  ),
  tar_target(
    club_history_generation_files,
    phase19_targets_file_inventory(
      "data/club/history_generations",
      list.files("data/club/history_generations", recursive = TRUE,
                 full.names = FALSE)
    ),
    format = "file"
  ),
  tar_target(
    club_history_authority,
    {
      club_history_pointer_file
      club_history_generation_files
      phase19_targets_state(
        phase19_load_club_training_snapshot,
        "no_accepted_club_history"
      )
    }
  ),
  tar_target(
    club_current_ucl_source_file,
    "data/competition/registries/ucl_source_current.json",
    format = "file"
  ),
  tar_target(
    club_identity_registry_files,
    phase19_targets_file_inventory(
      "data/club/registries",
      list.files("data/club/registries", full.names = FALSE)
    ),
    format = "file"
  ),
  tar_target(
    club_current_ucl_authority,
    {
      club_current_ucl_source_file
      club_identity_registry_files
      phase19_targets_state(
        phase19_load_current_ucl_club_snapshot,
        "no_accepted_current_ucl"
      )
    }
  ),
  tar_target(
    club_identity_authority,
    {
      club_current_ucl_authority
      phase19_targets_identity_state(club_current_ucl_authority)
    }
  ),
  tar_target(
    club_policy_review_files,
    phase19_targets_file_inventory(
      "data/club/model_protocol",
      c("policy_review.json", "calibration_recipe.json", "candidate_registry.csv",
        "feature_contract.csv", "gate_registry.csv", "seed_registry.csv")
    ),
    format = "file"
  ),
  tar_target(
    club_fold_registry_file,
    "data/club/model_protocol/fold_registry.csv",
    format = "file"
  ),
  tar_target(
    club_fold_review_file,
    "data/club/model_protocol/fold_review.json",
    format = "file"
  ),
  tar_target(
    club_protocol_authority,
    {
      club_history_authority
      club_current_ucl_authority
      club_identity_authority
      club_policy_review_files
      club_fold_registry_file
      club_fold_review_file
      phase19_targets_protocol_state(
        club_history_authority, club_current_ucl_authority,
        club_identity_authority, club_policy_review_files
      )
    }
  ),
  tar_target(
    club_fold_authority,
    {
      club_history_authority
      club_current_ucl_authority
      club_identity_authority
      club_protocol_authority
      club_fold_registry_file
      club_fold_review_file
      phase19_targets_fold_state(
        club_history_authority, club_current_ucl_authority,
        club_identity_authority, club_protocol_authority,
        club_fold_registry_file, club_fold_review_file
      )
    }
  ),
  tar_target(
    club_rating_replay,
    {
      club_history_authority
      club_current_ucl_authority
      club_protocol_authority
      club_fold_authority
      reason <- phase19_targets_first_blocked(
        club_history_authority, club_current_ucl_authority,
        club_protocol_authority, club_fold_authority
      )
      if (nzchar(reason)) phase19_targets_blocked(reason) else {
        phase19_targets_state(
          function() phase19_replay_club_ratings(
            club_history_authority$authority,
            club_current_ucl_authority$authority,
            phase19_club_rating_parameters(),
            cutoff_utc = club_history_authority$authority$cutoff_utc
          ),
          "fold_inventory_not_approved"
        )
      }
    }
  ),
  tar_target(
    club_model_candidates,
    {
      club_history_authority
      club_current_ucl_authority
      club_protocol_authority
      club_rating_replay
      reason <- phase19_targets_first_blocked(
        club_history_authority, club_current_ucl_authority,
        club_protocol_authority, club_rating_replay
      )
      if (nzchar(reason)) phase19_targets_blocked(reason) else {
        registrations <- club_protocol_authority$authority$candidate_registry[
          club_protocol_authority$authority$candidate_registry$model_id %in%
            c("club_venue_nb", "club_elo_nb"), , drop = FALSE
        ]
        fits <- lapply(seq_len(nrow(registrations)), function(index) {
          phase19_fit_club_goal_model(
            registrations[index, , drop = FALSE],
            club_history_authority$authority,
            club_rating_replay$authority,
            club_protocol_authority$authority,
            club_history_authority$authority$cutoff_utc
          )
        })
        names(fits) <- as.character(registrations$model_id)
        list(status = "ready", forecast_domain = "club", models = fits)
      }
    }
  ),
  tar_target(
    club_fold_predictions,
    {
      club_model_candidates
      club_fold_authority
      club_protocol_authority
      phase19_targets_passthrough_block(
        club_model_candidates, club_fold_authority, club_protocol_authority
      )
    }
  ),
  tar_target(
    club_fold_scores,
    {
      club_fold_predictions
      club_fold_authority
      phase19_targets_passthrough_block(club_fold_predictions, club_fold_authority)
    }
  ),
  tar_target(
    club_evaluation_set,
    {
      club_fold_scores
      phase19_targets_passthrough_block(club_fold_scores)
    }
  ),
  tar_target(
    club_promotion_decision,
    {
      club_evaluation_set
      club_protocol_authority
      club_current_ucl_authority
      reason <- phase19_targets_first_blocked(
        club_evaluation_set, club_protocol_authority,
        club_current_ucl_authority
      )
      if (nzchar(reason)) phase19_targets_blocked(reason) else {
        phase19_targets_blocked("fold_inventory_not_approved")
      }
    }
  ),
  tar_target(
    club_release_state,
    {
      club_promotion_decision
      club_model_candidates
      club_evaluation_set
      club_protocol_authority
      reason <- phase19_targets_first_blocked(
        club_promotion_decision, club_model_candidates,
        club_evaluation_set, club_protocol_authority
      )
      if (nzchar(reason)) phase19_targets_blocked(reason) else {
        phase19_targets_blocked("fold_inventory_not_approved")
      }
    }
  ),
  tar_target(
    club_selector_state,
    {
      club_release_state
      if (identical(club_release_state$status, "blocked")) {
        phase19_targets_blocked(club_release_state$reason_code, club_release_state)
      } else {
        phase19_targets_blocked("fold_inventory_not_approved")
      }
    }
  ),
  tar_target(
    club_protocol_artifact_file,
    {
      club_protocol_authority
      club_protocol_state_path <- "data/club/model_protocol/protocol_state.json"
      if (!file.exists(club_protocol_state_path)) {
        stop("Phase 19 protocol artifact is missing", call. = FALSE)
      }
      club_protocol_state_path
    },
    format = "file"
  ),
  tar_target(
    club_evaluation_artifact_files,
    {
      club_evaluation_set
      if (identical(club_evaluation_set$status, "blocked")) character() else {
        unname(club_evaluation_set$artifact_files)
      }
    },
    format = "file"
  ),
  tar_target(
    club_release_artifact_files,
    {
      club_release_state
      if (identical(club_release_state$status, "blocked")) character() else {
        unname(club_release_state$artifact_files)
      }
    },
    format = "file"
  ),
  tar_target(
    club_selector_file,
    {
      club_selector_state
      if (identical(club_selector_state$status, "blocked")) character() else {
        club_selector_state$selector_path
      }
    },
    format = "file"
  ),

  # Phase 20 UCL target namespace (exact ten targets / fifteen directed edges).
  # Every downstream expression names its immediate parents explicitly so the
  # targets graph cannot silently bypass an authority or evidence boundary.
  tar_target(
    ucl20_accepted_source,
    phase20_ucl_target_source()
  ),
  tar_target(
    ucl20_rules_evidence,
    phase20_ucl_target_rules()
  ),
  tar_target(
    ucl20_state,
    {
      ucl20_accepted_source
      ucl20_rules_evidence
      phase20_ucl_target_state(ucl20_accepted_source, ucl20_rules_evidence)
    }
  ),
  tar_target(
    ucl20_forecast_ledger,
    {
      ucl20_state
      phase20_ucl_target_passthrough(ucl20_state)
    }
  ),
  tar_target(
    ucl20_league_simulation,
    {
      ucl20_state
      ucl20_forecast_ledger
      ucl20_rules_evidence
      issue <- phase20_ucl_target_first_issue(
        ucl20_state, ucl20_forecast_ledger, ucl20_rules_evidence
      )
      if (!is.null(issue)) issue else phase20_ucl_target_passthrough(ucl20_state)
    }
  ),
  tar_target(
    ucl20_knockout_paths,
    {
      ucl20_league_simulation
      ucl20_rules_evidence
      issue <- phase20_ucl_target_first_issue(
        ucl20_league_simulation, ucl20_rules_evidence
      )
      if (!is.null(issue)) issue else phase20_ucl_target_passthrough(ucl20_league_simulation)
    }
  ),
  tar_target(
    ucl20_stage_events,
    {
      ucl20_knockout_paths
      ucl20_rules_evidence
      issue <- phase20_ucl_target_first_issue(
        ucl20_knockout_paths, ucl20_rules_evidence
      )
      if (!is.null(issue)) issue else phase20_ucl_target_passthrough(ucl20_knockout_paths)
    }
  ),
  tar_target(
    ucl20_outcome_candidate,
    {
      ucl20_stage_events
      ucl20_forecast_ledger
      ucl20_league_simulation
      issue <- phase20_ucl_target_first_issue(
        ucl20_stage_events, ucl20_forecast_ledger, ucl20_league_simulation
      )
      if (!is.null(issue)) issue else phase20_ucl_target_passthrough(ucl20_stage_events)
    }
  ),
  tar_target(
    ucl20_outcome_manifest,
    {
      ucl20_outcome_candidate
      phase20_ucl_target_passthrough(ucl20_outcome_candidate)
    }
  ),
  tar_target(
    ucl20_build_status,
    {
      ucl20_outcome_manifest
      issue <- phase20_ucl_target_first_issue(ucl20_outcome_manifest)
      if (!is.null(issue)) issue else phase20_ucl_target_passthrough(ucl20_outcome_manifest)
    }
  )
)
