#' Phase 11 research-only hybrid challenger runner

.hybrid_runner_source_if_missing <- function(relative_path, symbols) {
  missing <- symbols[!vapply(symbols, exists, logical(1), mode = "function")]
  if (!length(missing)) return(invisible(TRUE))
  root <- if (exists(".phase11_protocol_root", mode = "function")) {
    .phase11_protocol_root(".")
  } else {
    normalizePath(".", mustWork = TRUE)
  }
  path <- file.path(root, relative_path)
  if (!file.exists(path)) stop("Phase 11 hybrid runner dependency is missing: ", relative_path, call. = FALSE)
  source(path, local = .GlobalEnv)
  missing_after <- missing[!vapply(missing, exists, logical(1), mode = "function")]
  if (length(missing_after)) stop("Phase 11 hybrid runner dependency did not define: ", paste(missing_after, collapse = ", "), call. = FALSE)
  invisible(TRUE)
}

.hybrid_runner_utf8 <- function(value) {
  enc2utf8(as.character(value))
}

.hybrid_runner_normalize_identifiers <- function(data, columns) {
  if (!is.data.frame(data)) return(data)
  for (column in intersect(columns, names(data))) {
    data[[column]] <- .hybrid_runner_utf8(data[[column]])
  }
  data
}

.hybrid_runner_file_sha256 <- function(relative_path) {
  if (!requireNamespace("digest", quietly = TRUE)) stop("digest is required for the Phase 11 runner manifest", call. = FALSE)
  root <- if (exists(".phase11_protocol_root", mode = "function")) .phase11_protocol_root(".") else normalizePath(".", mustWork = TRUE)
  path <- file.path(root, relative_path)
  if (!file.exists(path)) stop("Phase 11 runner parent artifact is missing: ", relative_path, call. = FALSE)
  digest::digest(path, algo = "sha256", file = TRUE)
}

.hybrid_runner_git_sha <- function() {
  value <- tryCatch(system2("git", c("rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE), error = function(e) character())
  value <- trimws(value)
  if (length(value) != 1L || !grepl("^[0-9a-f]{40}$", value)) "" else value
}

.hybrid_runner_settings_for <- function(settings_by_candidate, candidate_id) {
  if (is.null(settings_by_candidate)) return(list())
  if (!is.list(settings_by_candidate)) stop("settings_by_candidate must be a named list", call. = FALSE)
  if (!length(settings_by_candidate)) return(list())
  if (is.null(names(settings_by_candidate))) stop("settings_by_candidate must be named by candidate_id", call. = FALSE)
  if (!candidate_id %in% names(settings_by_candidate)) return(list())
  value <- settings_by_candidate[[candidate_id]]
  if (is.null(value)) list() else value
}

.hybrid_runner_root <- function() {
  if (exists(".phase11_protocol_root", mode = "function")) {
    .phase11_protocol_root(".")
  } else {
    normalizePath(".", mustWork = TRUE)
  }
}

hybrid_phase11_parent_paths <- function() {
  c(
    ranger_provenance = "data/benchmark/phase11/ranger_provenance.csv",
    country_centroids = "data/benchmark/phase11/country_centroids.csv",
    country_centroids_metadata = "data/benchmark/phase11/country_centroids_metadata.csv",
    structural_sources = "data/benchmark/phase11/structural_sources.csv",
    structural_sources_metadata = "data/benchmark/phase11/structural_sources_metadata.csv",
    structural_sources_checksums = "data/benchmark/phase11/structural_sources_checksums.csv",
    xg_gate_manifest = "data/benchmark/phase11/xg_gate_manifest.csv",
    structural_prior_manifest = "data/benchmark/phase11/structural_prior_manifest.csv",
    mode_registry = "data/benchmark/phase11/mode_registry.csv",
    manual_market_manifest = "data/benchmark/phase11/manual_market_manifest.csv",
    phase09_run_manifest = "outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen/run_manifest.csv",
    phase09_checksum_manifest = "outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen/manifests/checksum_manifest.csv",
    phase09_fixture_scores = "outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen/scores/fixture_scores.csv",
    phase10_run_manifest = "outputs/benchmarks/rolling_tournaments/phase10-statistical-challengers/run_manifest.csv",
    phase10_checksum_manifest = "outputs/benchmarks/rolling_tournaments/phase10-statistical-challengers/manifests/checksum_manifest.csv",
    phase10_fixture_scores = "outputs/benchmarks/rolling_tournaments/phase10-statistical-challengers/scores/fixture_scores.csv",
    phase10_comparisons = "outputs/benchmarks/rolling_tournaments/phase10-statistical-challengers/comparisons/all_baseline_paired_comparisons.csv",
    phase10_shortlist = "outputs/benchmarks/rolling_tournaments/phase10-statistical-challengers/selection/shortlist.csv",
    elo_ratings = "data/processed/elo_ratings.csv",
    goal_training_features_hybrid = "data/processed/goal_training_features_hybrid.csv"
  )
}

hybrid_phase11_parent_hashes <- function(parent_paths = hybrid_phase11_parent_paths()) {
  if (!requireNamespace("digest", quietly = TRUE)) stop("digest is required for Phase 11 parent identities", call. = FALSE)
  labels <- names(parent_paths)
  parent_paths <- as.character(parent_paths)
  if (is.null(labels) || any(!nzchar(labels)) || anyDuplicated(labels)) {
    stop("parent_paths must be named by stable parent identities", call. = FALSE)
  }
  root <- .hybrid_runner_root()
  values <- vapply(seq_along(parent_paths), function(index) {
    path <- file.path(root, parent_paths[[index]])
    if (file.exists(path)) return(digest::digest(path, algo = "sha256", file = TRUE))
    digest::digest(
      paste("phase11-parent-absent", labels[[index]], parent_paths[[index]], sep = "|"),
      algo = "sha256", serialize = FALSE
    )
  }, character(1))
  names(values) <- labels
  values
}

hybrid_output_paths <- function(output_dir) {
  output_dir <- as.character(output_dir)
  if (length(output_dir) != 1L || is.na(output_dir) || !nzchar(output_dir)) {
    stop("output_dir must be one non-empty path", call. = FALSE)
  }
  stats::setNames(
    file.path(output_dir, c(
      "run_manifest.csv",
      "predictions/fixture_predictions.csv",
      "predictions/score_distributions.csv",
      "scores/fixture_scores.csv",
      "scores/benchmark_summaries.csv",
      "manifests/model_manifests.csv",
      "manifests/feature_coverage.csv",
      "manifests/fold_tuning.csv",
      "manifests/parent_inputs.csv",
      "manifests/checksum_manifest.csv",
      "selection/candidate_evidence.csv",
      "selection/all_baseline_paired_comparisons.csv",
      "selection/hybrid_shortlist.csv",
      "modes/mode_registry.csv",
      "modes/mode_companion_evidence.csv",
      "reports/research_only_report.txt"
    )),
    c(
      "run_manifest", "predictions", "distributions", "scores", "benchmark_summaries",
      "manifests", "feature_coverage", "fold_tuning", "parent_inputs", "checksum_manifest",
      "candidate_evidence", "comparisons", "shortlist", "mode_registry",
      "mode_companion_evidence", "research_report"
    )
  )
}

.hybrid_runner_as_flag <- function(value) {
  normalized <- tolower(trimws(as.character(value)))
  length(normalized) == 1L && !is.na(normalized) && normalized %in% c("true", "1", "yes")
}

.hybrid_runner_table_hash <- function(data) {
  if (!requireNamespace("digest", quietly = TRUE)) stop("digest is required for Phase 11 checksums", call. = FALSE)
  if (!is.data.frame(data)) stop("checksum hashing requires a data frame", call. = FALSE)
  if (!ncol(data)) return(digest::digest("", algo = "sha256", serialize = FALSE))
  normalized <- lapply(data, function(column) {
    if (inherits(column, "POSIXt")) column <- format(column, tz = "UTC", usetz = TRUE)
    if (inherits(column, "Date")) column <- format(column, "%Y-%m-%d")
    value <- as.character(column)
    value[is.na(value)] <- "<NA>"
    value
  })
  rows <- if (nrow(data)) {
    vapply(seq_len(nrow(data)), function(index) {
      paste(vapply(normalized, `[[`, character(1), index), collapse = "\u001f")
    }, character(1))
  } else character()
  digest::digest(
    paste(c(paste(names(data), collapse = "\u001e"), rows), collapse = "\u001d"),
    algo = "sha256", serialize = FALSE
  )
}

.hybrid_runner_write_csv <- function(data, path) {
  if (!is.data.frame(data)) stop("Phase 11 bundle artifacts must be data frames", call. = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(data, path, row.names = FALSE, na = "", quote = TRUE)
  invisible(path)
}

.hybrid_runner_read_csv <- function(path) {
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

.hybrid_runner_bundle_from_directory <- function(output_dir) {
  paths <- hybrid_output_paths(output_dir)
  required <- unname(paths[names(paths) != "research_report"])
  missing <- required[!file.exists(required)]
  if (length(missing)) stop("Hybrid challenger bundle is missing durable files: ", paste(missing, collapse = ", "), call. = FALSE)
  bundle <- lapply(paths[names(paths) != "research_report"], .hybrid_runner_read_csv)
  names(bundle) <- names(paths)[names(paths) != "research_report"]
  bundle$research_report <- paste(readLines(paths[["research_report"]], warn = FALSE), collapse = "\n")
  bundle$bundle_dir <- normalizePath(output_dir, mustWork = TRUE)
  bundle$durable <- TRUE
  bundle
}

.hybrid_runner_validate_comparison_denominators <- function(comparisons) {
  required <- c(
    "candidate_id", "baseline_id", "comparison_panel_id", "track_id",
    "diagnostic", "paired_fixture_count"
  )
  missing <- setdiff(required, names(comparisons))
  if (length(missing)) {
    stop(
      "Hybrid comparisons are missing denominator columns: ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
  comparisons$comparison_panel_id <- as.character(comparisons$comparison_panel_id)
  comparisons$diagnostic <- as.character(comparisons$diagnostic)
  expected_by_panel <- c(open_core = 630L, feature_rich = 609L)
  unknown_panels <- setdiff(unique(comparisons$comparison_panel_id), names(expected_by_panel))
  if (length(unknown_panels)) {
    stop(
      "Hybrid comparisons contain unknown comparison panels: ",
      paste(unknown_panels, collapse = ", "),
      call. = FALSE
    )
  }
  group_columns <- c("candidate_id", "baseline_id", "track_id", "comparison_panel_id")
  group_key <- do.call(paste, c(comparisons[group_columns], sep = "\r"))
  groups <- split(comparisons, group_key, drop = TRUE)
  for (rows in groups) {
    expected <- unname(expected_by_panel[[rows$comparison_panel_id[[1L]]]])
    folds <- rows[rows$diagnostic == "fold", , drop = FALSE]
    if (nrow(folds) != 12L || anyNA(as.integer(folds$paired_fixture_count)) ||
        sum(as.integer(folds$paired_fixture_count)) != expected) {
      stop("Hybrid comparison fold denominators drifted from exact open/rich panels", call. = FALSE)
    }
    headline <- rows[rows$diagnostic %in% c(
      "equal_tournament_headline", "fixture_weighted_secondary"
    ), , drop = FALSE]
    if (nrow(headline) != 2L || anyNA(as.integer(headline$paired_fixture_count)) ||
        any(as.integer(headline$paired_fixture_count) != expected)) {
      stop("Hybrid comparison headline denominators drifted from exact open/rich panels", call. = FALSE)
    }
  }
  invisible(comparisons)
}

.hybrid_runner_validate_checksum_manifest <- function(output_dir) {
  paths <- hybrid_output_paths(output_dir)
  checksum <- .hybrid_runner_read_csv(paths[["checksum_manifest"]])
  required <- c("artifact_path", "artifact_kind", "sha256", "row_count", "required", "selected_g")
  missing <- setdiff(required, names(checksum))
  if (length(missing)) stop("Phase 11 checksum manifest is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  self <- checksum[checksum$artifact_path == "manifests/checksum_manifest.csv", , drop = FALSE]
  body <- checksum[checksum$artifact_path != "manifests/checksum_manifest.csv", , drop = FALSE]
  if (nrow(self) != 1L || !identical(as.character(self$sha256[[1L]]), .hybrid_runner_table_hash(body))) {
    stop("Phase 11 checksum manifest self-hash mismatch", call. = FALSE)
  }
  root <- normalizePath(output_dir, mustWork = TRUE)
  for (index in seq_len(nrow(body))) {
    relative <- as.character(body$artifact_path[[index]])
    path <- file.path(root, relative)
    if (!file.exists(path)) stop("Phase 11 checksum artifact is missing: ", relative, call. = FALSE)
    actual <- digest::digest(path, algo = "sha256", file = TRUE)
    if (!identical(tolower(actual), tolower(as.character(body$sha256[[index]])))) {
      stop("Phase 11 checksum mismatch: ", relative, call. = FALSE)
    }
    if (!is.na(body$row_count[[index]]) && !grepl("\\.txt$", relative)) {
      rows <- nrow(.hybrid_runner_read_csv(path))
      if (!identical(as.integer(rows), as.integer(body$row_count[[index]]))) {
        stop("Phase 11 checksum row count mismatch: ", relative, call. = FALSE)
      }
    }
  }
  invisible(TRUE)
}

#' Validate the explicit run-level protection flags and durable result tables.
#' @export
validate_hybrid_challenger_bundle <- function(bundle) {
  .hybrid_runner_source_if_missing(
    "R/evaluation/challenger_selection.R",
    c("challenger_selection_parent_graph_sha256", "validate_hybrid_research_shortlist")
  )
  if (is.character(bundle) && length(bundle) == 1L && dir.exists(bundle)) {
    .hybrid_runner_validate_checksum_manifest(bundle)
    bundle <- .hybrid_runner_bundle_from_directory(bundle)
  }
  if (!is.list(bundle)) stop("Hybrid challenger bundle must be a list or durable bundle directory", call. = FALSE)
  required <- c(
    "run_manifest", "predictions", "distributions", "scores", "manifests", "feature_coverage",
    "benchmark_summaries", "candidate_evidence", "comparisons", "shortlist", "mode_registry",
    "mode_companion_evidence", "parent_inputs", "fold_tuning"
  )
  missing <- setdiff(required, names(bundle))
  if (length(missing)) stop("Hybrid challenger bundle is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  manifest <- bundle$run_manifest
  if (!is.data.frame(manifest) || nrow(manifest) != 1L) stop("Hybrid run manifest must contain one row", call. = FALSE)
  flags <- c(
    "reproducible", "wc2026_sealed", "network_free", "research_only", "protected_paths_clean"
  )
  missing_flags <- setdiff(c(flags, "phase12_decision_authority"), names(manifest))
  if (length(missing_flags)) stop("Hybrid run manifest is missing protection flags: ", paste(missing_flags, collapse = ", "), call. = FALSE)
  if (any(!vapply(manifest[flags], .hybrid_runner_as_flag, logical(1))) ||
      .hybrid_runner_as_flag(manifest$phase12_decision_authority[[1L]])) {
    stop("Hybrid run manifest protection flags are not sealed research-only values", call. = FALSE)
  }
  if (!identical(as.integer(manifest$open_fixture_count[[1L]]), 630L) ||
      !identical(as.integer(manifest$rich_fixture_count[[1L]]), 609L) ||
      !identical(as.integer(manifest$selected_g[[1L]]), 40L)) {
    stop("Hybrid run manifest must preserve 630/609/G=40", call. = FALSE)
  }
  if (!is.data.frame(bundle$distributions) || nrow(bundle$distributions)) {
    distributions <- bundle$distributions
    required_distribution <- c("score_distribution_id", "home_goals", "away_goals", "probability")
    missing_distribution <- setdiff(required_distribution, names(distributions))
    if (length(missing_distribution)) stop("Hybrid distributions are missing: ", paste(missing_distribution, collapse = ", "), call. = FALSE)
    groups <- split(distributions, as.character(distributions$score_distribution_id))
    if (!length(groups) || any(vapply(groups, function(rows) {
      length(unique(as.integer(rows$home_goals))) == 41L &&
        length(unique(as.integer(rows$away_goals))) == 41L &&
        max(as.integer(rows$home_goals), na.rm = TRUE) == 40L &&
        max(as.integer(rows$away_goals), na.rm = TRUE) == 40L
    }, logical(1)))) {
      if (!length(groups) || any(vapply(groups, nrow, integer(1)) != 1681L)) {
        stop("Hybrid score distributions must use exact G=40 grids", call. = FALSE)
      }
    } else stop("Hybrid score distributions must use exact G=40 grids", call. = FALSE)
  }
  evidence_required <- c(
    "candidate_id", "panel_id", "open_fixture_count", "rich_fixture_count", "score_support_g",
    "active_status", "score_status", "research_only", "wc2026_sealed"
  )
  missing_evidence <- setdiff(evidence_required, names(bundle$candidate_evidence))
  if (length(missing_evidence)) stop("Hybrid candidate evidence is missing: ", paste(missing_evidence, collapse = ", "), call. = FALSE)
  if (nrow(bundle$candidate_evidence)) {
    evidence <- bundle$candidate_evidence
    if (any(as.integer(evidence$open_fixture_count) != 630L) ||
        any(as.integer(evidence$rich_fixture_count) != 609L) ||
        any(as.integer(evidence$score_support_g) != 40L) ||
        any(!vapply(evidence$research_only, .hybrid_runner_as_flag, logical(1))) ||
        any(!vapply(evidence$wc2026_sealed, .hybrid_runner_as_flag, logical(1)))) {
      stop("Hybrid candidate evidence drifted from exact panels or sealed flags", call. = FALSE)
    }
  }
  if (is.data.frame(bundle$mode_registry) && nrow(bundle$mode_registry)) {
    required_modes <- c("mode_id", "panel_id", "active_status", "research_only", "wc2026_sealed")
    missing_modes <- setdiff(required_modes, names(bundle$mode_registry))
    if (length(missing_modes)) stop("Hybrid mode registry is missing: ", paste(missing_modes, collapse = ", "), call. = FALSE)
    if (any(!vapply(bundle$mode_registry$research_only, .hybrid_runner_as_flag, logical(1))) ||
        any(!vapply(bundle$mode_registry$wc2026_sealed, .hybrid_runner_as_flag, logical(1)))) {
      stop("Hybrid mode registry must be research-only and sealed", call. = FALSE)
    }
  }
  if (nrow(bundle$shortlist) || isTRUE(bundle$durable)) {
    validate_hybrid_research_shortlist(bundle$shortlist)
  }
  if (is.data.frame(bundle$comparisons) && nrow(bundle$comparisons)) {
    required_comparisons <- c(
      "candidate_id", "baseline_id", "comparison_panel_id", "track_id", "delta",
      "mode_id", "research_only", "wc2026_sealed"
    )
    missing_comparisons <- setdiff(required_comparisons, names(bundle$comparisons))
    if (length(missing_comparisons)) stop("Hybrid comparisons are missing: ", paste(missing_comparisons, collapse = ", "), call. = FALSE)
    if (any(as.character(bundle$comparisons$mode_id) != "open_default") ||
        any(!vapply(bundle$comparisons$research_only, .hybrid_runner_as_flag, logical(1))) ||
        any(!vapply(bundle$comparisons$wc2026_sealed, .hybrid_runner_as_flag, logical(1)))) {
      stop("Hybrid comparisons must remain open-mode research evidence", call. = FALSE)
    }
    .hybrid_runner_validate_comparison_denominators(bundle$comparisons)
  }
  if (!is.data.frame(bundle$parent_inputs) || !nrow(bundle$parent_inputs)) {
    stop("Hybrid bundle must carry explicit parent inputs", call. = FALSE)
  }
  parent_required <- c("parent_id", "relative_path", "sha256", "status")
  if (length(setdiff(parent_required, names(bundle$parent_inputs))) ||
      any(!grepl("^[0-9a-f]{64}$", as.character(bundle$parent_inputs$sha256)))) {
    stop("Hybrid parent input identities are incomplete", call. = FALSE)
  }
  invisible(bundle)
}

.hybrid_runner_score_inputs <- function(fixtures) {
  required <- c("regulation_home_goals", "regulation_away_goals", "score_eligible")
  missing <- setdiff(required, names(fixtures))
  if (length(missing)) {
    stop("Hybrid scoring requires explicit outcome/eligibility columns; missing: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  home <- suppressWarnings(as.numeric(fixtures$regulation_home_goals))
  away <- suppressWarnings(as.numeric(fixtures$regulation_away_goals))
  eligible <- if (is.logical(fixtures$score_eligible)) fixtures$score_eligible else {
    normalized <- tolower(trimws(as.character(fixtures$score_eligible)))
    ifelse(normalized == "true", TRUE, ifelse(normalized == "false", FALSE, NA))
  }
  if (anyNA(home) || anyNA(away) || any(!is.finite(home)) || any(!is.finite(away)) ||
      any(home < 0 | away < 0) || anyNA(eligible)) {
    stop("Hybrid scoring outcomes and score eligibility must be explicit finite values", call. = FALSE)
  }
  if (any(!eligible)) stop("Hybrid research runner fails closed when any requested fixture is not score eligible", call. = FALSE)
  invisible(TRUE)
}

.hybrid_runner_namespace_track_distribution_ids <- function(adapter, track_id) {
  if (isTRUE(adapter$inactive) || !is.data.frame(adapter$distributions) ||
      !nrow(adapter$distributions)) return(adapter)
  old_ids <- .hybrid_runner_utf8(adapter$distributions$score_distribution_id)
  if (anyNA(old_ids) || any(!nzchar(old_ids))) {
    stop("Hybrid adapter returned incomplete score distribution IDs within a track", call. = FALSE)
  }
  unique_old_ids <- unique(old_ids)
  unique_new_ids <- paste("phase11", .hybrid_runner_utf8(track_id), unique_old_ids, sep = "__")
  adapter$distributions$score_distribution_id <- unique_new_ids[match(old_ids, unique_old_ids)]
  if (is.data.frame(adapter$predictions) && nrow(adapter$predictions)) {
    prediction_ids <- .hybrid_runner_utf8(adapter$predictions$score_distribution_id)
    prediction_index <- match(prediction_ids, unique_old_ids)
    if (anyNA(prediction_index)) {
      stop("Hybrid adapter predictions reference an unknown track distribution", call. = FALSE)
    }
    adapter$predictions$score_distribution_id <- unique_new_ids[prediction_index]
  }
  adapter
}

.hybrid_runner_context_inactive_result <- function(
    registration, fixtures, seed_registry, run_id, protocol, settings, reason
) {
  .hybrid_runner_source_if_missing(
    "R/benchmark/hybrid_adapters.R",
    c(".hybrid_context_registered_settings", ".hybrid_xg_inactive_result")
  )
  resolved_settings <- tryCatch(
    .hybrid_context_registered_settings(settings, registration),
    error = function(error) {
      list(
        support_max = 40L,
        ranger_package = as.character(registration$ranger_package[[1L]]),
        ranger_version = as.character(registration$ranger_version[[1L]]),
        ranger_provenance_id = as.character(registration$ranger_provenance_id[[1L]]),
        provenance_path = "data/benchmark/phase11/ranger_provenance.csv",
        registration_sha256 = as.character(registration$registration_sha256[[1L]]),
        settings_sha256 = as.character(registration$settings_sha256[[1L]])
      )
    }
  )
  gate <- data.frame(
    gate_id = "",
    gate_parent_sha256 = "",
    coverage = NA_real_,
    variance = NA_real_,
    provenance = FALSE,
    inactive_reason = as.character(reason),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  result <- .hybrid_xg_inactive_result(
    registration = registration,
    fixtures = fixtures,
    seed_registry = seed_registry,
    run_id = run_id,
    protocol = protocol,
    settings = resolved_settings,
    gate = gate
  )
  result$inactive_evidence$removed_feature_id <- if (
    "removed_feature_id" %in% names(registration)
  ) as.character(registration$removed_feature_id[[1L]]) else ""
  result$inactive_evidence$context_parent_hashes <- if (
    "context_parent_hashes" %in% names(registration)
  ) as.character(registration$context_parent_hashes[[1L]]) else ""
  result$inactive_evidence$score_status <- "no_score_context_panel_ineligible"
  result$inactive_evidence$error_reason <- as.character(reason)
  result$manifests$context_feature_set_id <- as.character(registration$context_feature_set_id[[1L]])
  result$manifests$removed_feature_id <- if (
    "removed_feature_id" %in% names(registration)
  ) as.character(registration$removed_feature_id[[1L]]) else ""
  result$manifests$context_parent_hashes <- if (
    "context_parent_hashes" %in% names(registration)
  ) as.character(registration$context_parent_hashes[[1L]]) else ""
  result$manifests$score_status <- "no_score_context_panel_ineligible"
  result$manifests$inactive_reason <- as.character(reason)
  result$manifests$dropped_predictors_with_reason <- paste0(
    "context common panel inactive: ", as.character(reason)
  )
  result$manifests$fallback_status <- "inactive_context_panel"
  result$context_inactive_reason <- as.character(reason)
  result
}

.hybrid_runner_point_in_time_elo <- function(fixtures, home_advantage = 60) {
  .hybrid_runner_source_if_missing(
    "R/forecast/features.R",
    c("make_latest_team_evidence_lookup", "forecast_difference_evidence")
  )
  required <- c("evidence_cutoff_exclusive", "home_team_id", "away_team_id")
  missing <- setdiff(required, names(fixtures))
  if (length(missing)) stop("Point-in-time Elo fixtures are missing: ", paste(missing, collapse = ", "), call. = FALSE)
  cutoffs <- as.Date(fixtures$evidence_cutoff_exclusive)
  if (anyNA(cutoffs)) stop("Point-in-time Elo requires complete evidence cutoffs", call. = FALSE)
  root <- .hybrid_runner_root()
  ratings_path <- file.path(root, "data/processed/elo_ratings.csv")
  if (!file.exists(ratings_path)) stop("Point-in-time Elo source artifact is missing", call. = FALSE)
  ratings <- utils::read.csv(ratings_path, stringsAsFactors = FALSE, check.names = FALSE)
  ratings$date <- as.Date(ratings$date)
  if (!all(c("team", "date", "rating") %in% names(ratings))) {
    stop("Point-in-time Elo source artifact is missing team/date/rating columns", call. = FALSE)
  }
  ratings <- ratings[!is.na(ratings$date) & ratings$date < max(cutoffs), , drop = FALSE]
  if (!nrow(ratings)) stop("Point-in-time Elo source has no rows before the evaluation panel", call. = FALSE)
  get_rating <- make_latest_team_evidence_lookup(ratings, "rating", default = 1500)
  team_registry <- NULL
  resolve_team_names <- function(column, id_column) {
    if (column %in% names(fixtures)) return(.hybrid_runner_utf8(fixtures[[column]]))
    if (is.null(team_registry)) {
      team_registry <<- utils::read.csv(
        file.path(root, "data/benchmark/phase09/teams.csv"),
        stringsAsFactors = FALSE, check.names = FALSE
      )
    }
    resolved <- as.character(team_registry$canonical_name[match(as.character(fixtures[[id_column]]), team_registry$team_id)])
    .hybrid_runner_utf8(resolved)
  }
  home_names <- resolve_team_names("home_team", "home_team_id")
  away_names <- resolve_team_names("away_team", "away_team_id")
  venue <- if ("venue_role" %in% names(fixtures)) {
    .hybrid_runner_utf8(fixtures$venue_role)
  } else {
    rep("home", nrow(fixtures))
  }
  values <- source_dates <- rep(NA, nrow(fixtures))
  source_present <- value_present <- rep(FALSE, nrow(fixtures))
  imputed <- rep(TRUE, nrow(fixtures))
  reasons <- rep("missing_source_row", nrow(fixtures))
  for (index in seq_len(nrow(fixtures))) {
    home <- get_rating(home_names[[index]], cutoffs[[index]])
    away <- get_rating(away_names[[index]], cutoffs[[index]])
    evidence <- forecast_difference_evidence(home, away)
    if (!isTRUE(evidence$source_present) || !isTRUE(evidence$value_present)) {
      stop(
        "Point-in-time Elo is unavailable for fixture ", as.character(fixtures$fixture_id[[index]]),
        " before ", as.character(cutoffs[[index]]), call. = FALSE
      )
    }
    value <- as.numeric(evidence$value)
    if (identical(venue[[index]], "home")) value <- value + home_advantage
    if (identical(venue[[index]], "away")) value <- value - home_advantage
    values[[index]] <- value
    source_dates[[index]] <- as.Date(evidence$source_date)
    source_present[[index]] <- TRUE
    value_present[[index]] <- TRUE
    imputed[[index]] <- FALSE
    reasons[[index]] <- ""
  }
  list(
    elo_diff = as.numeric(values),
    source_date = as.Date(source_dates, origin = "1970-01-01"),
    source_present = source_present,
    value_present = value_present,
    imputed = imputed,
    imputation_reason = reasons
  )
}

#' Add the registered point-in-time dynamic goal features to the Phase 11
#' history and benchmark fixtures.
#'
#' The benchmark feature file contains the checked Elo and enriched columns,
#' but dynamic attack/defence effects are intentionally replayed at execution
#' time.  The replay predicts each date before updating that date's results and
#' removes only cold-start training rows; it never fills missing evidence with
#' a value that could be mistaken for an observed feature.
#' @export
hybrid_prepare_dynamic_history_and_fixtures <- function(
    history, fixtures, pseudo_exposure = 8, half_life_days = 730
) {
  .hybrid_runner_source_if_missing(
    "R/forecast/dynamic_goal_ability.R",
    c(
      "dynamic_goal_as_results", "initialize_dynamic_goal_state",
      "replay_dynamic_goal_states"
    )
  )
  if (!is.data.frame(history) || !nrow(history)) stop("Dynamic hybrid history must contain rows", call. = FALSE)
  if (!is.data.frame(fixtures) || !nrow(fixtures)) stop("Dynamic hybrid fixtures must contain rows", call. = FALSE)
  required_history <- c("match_id", "date", "home_team_id", "away_team_id", "home_goals", "away_goals")
  missing_history <- setdiff(required_history, names(history))
  if (length(missing_history)) stop("Dynamic hybrid history is missing: ", paste(missing_history, collapse = ", "), call. = FALSE)
  required_fixtures <- c("fixture_id", "actual_completion_date", "home_team_id", "away_team_id")
  missing_fixtures <- setdiff(required_fixtures, names(fixtures))
  if (length(missing_fixtures)) stop("Dynamic hybrid fixtures are missing: ", paste(missing_fixtures, collapse = ", "), call. = FALSE)
  history <- .hybrid_runner_normalize_identifiers(
    history, c("match_id", "home_team_id", "away_team_id")
  )
  fixtures <- .hybrid_runner_normalize_identifiers(
    fixtures, c("fixture_id", "edition_id", "boundary_id", "home_team_id", "away_team_id")
  )
  history_results <- dynamic_goal_as_results(history)
  history_results$fixture_id <- .hybrid_runner_utf8(history_results$match_id)
  history_results <- .hybrid_runner_normalize_identifiers(
    history_results, c("fixture_id", "home_team_id", "away_team_id")
  )
  history_results$match_date <- as.Date(history_results$match_date)
  history_results <- history_results[order(history_results$match_date, history_results$fixture_id, method = "radix"), , drop = FALSE]
  if (anyNA(history_results$match_date) || anyDuplicated(history_results$fixture_id)) {
    stop("Dynamic hybrid history identities and dates must be complete and unique", call. = FALSE)
  }
  prediction_dates <- if ("evidence_cutoff_exclusive" %in% names(fixtures)) {
    as.Date(fixtures$evidence_cutoff_exclusive)
  } else as.Date(fixtures$actual_completion_date)
  target <- data.frame(
    dynamic_fixture_id = paste0("phase11_dynamic_fixture__", seq_len(nrow(fixtures))),
    fixture_id = .hybrid_runner_utf8(fixtures$fixture_id),
    match_date = prediction_dates,
    actual_completion_date = as.Date(fixtures$actual_completion_date),
    evidence_cutoff_exclusive = prediction_dates,
    home_team_id = .hybrid_runner_utf8(fixtures$home_team_id),
    away_team_id = .hybrid_runner_utf8(fixtures$away_team_id),
    stringsAsFactors = FALSE
  )
  if ("home_team" %in% names(fixtures)) target$home_team <- .hybrid_runner_utf8(fixtures$home_team)
  if ("away_team" %in% names(fixtures)) target$away_team <- .hybrid_runner_utf8(fixtures$away_team)
  if ("venue_role" %in% names(fixtures)) target$venue_role <- .hybrid_runner_utf8(fixtures$venue_role)
  if ("elo_diff" %in% names(fixtures)) target$elo_diff <- as.numeric(fixtures$elo_diff)
  elo_source <- .hybrid_runner_point_in_time_elo(target)
  target$elo_diff <- elo_source$elo_diff
  target$elo_diff__source_date <- elo_source$source_date
  target$elo_diff__source_present <- elo_source$source_present
  target$elo_diff__value_present <- elo_source$value_present
  target$elo_diff__imputed <- elo_source$imputed
  target$elo_diff__imputation_reason <- elo_source$imputation_reason
  if (anyNA(target$match_date) || anyNA(target$home_team_id) || anyNA(target$away_team_id)) {
    stop("Dynamic hybrid target fixture identity or dates are incomplete", call. = FALSE)
  }
  team_ids <- sort(unique(c(
    as.character(history_results$home_team_id), as.character(history_results$away_team_id),
    target$home_team_id, target$away_team_id
  )), method = "radix")
  observed_goals <- c(as.numeric(history_results$home_goals), as.numeric(history_results$away_goals))
  global_rate <- mean(observed_goals[is.finite(observed_goals) & observed_goals >= 0])
  if (!is.finite(global_rate) || global_rate <= 0) global_rate <- 1.25
  initial_state <- initialize_dynamic_goal_state(
    team_ids = team_ids, global_goal_rate = global_rate,
    pseudo_exposure = pseudo_exposure, as_of_date = min(history_results$match_date)
  )
  history_replay_fixtures <- history_results[, c(
    "fixture_id", "match_date", "home_team_id", "away_team_id"
  ), drop = FALSE]
  history_replay <- replay_dynamic_goal_states(
    history = history_results,
    fixtures = history_replay_fixtures,
    initial_state = initial_state,
    half_life_days = half_life_days
  )$predictions
  target_replay_columns <- intersect(
    c("dynamic_fixture_id", "match_date", "home_team_id", "away_team_id", "elo_diff"),
    names(target)
  )
  target_replay_input <- target[, target_replay_columns, drop = FALSE]
  target_replay_input$fixture_id <- .hybrid_runner_utf8(target_replay_input$dynamic_fixture_id)
  target_replay <- replay_dynamic_goal_states(
    history = history_results,
    fixtures = target_replay_input,
    initial_state = initial_state,
    half_life_days = half_life_days
  )$predictions
  names(target_replay)[names(target_replay) == "fixture_id"] <- "dynamic_fixture_id"

  attach_features <- function(rows, predictions, key_column, cutoff_column) {
    index <- match(as.character(rows[[key_column]]), as.character(predictions[[key_column]]))
    if (anyNA(index)) stop("Dynamic replay omitted a requested fixture identity", call. = FALSE)
    value_source <- list(
      home_attack_effect = "home_state_source_date",
      home_defence_effect = "home_state_source_date",
      away_attack_effect = "away_state_source_date",
      away_defence_effect = "away_state_source_date"
    )
    for (feature in names(value_source)) {
      values <- suppressWarnings(as.numeric(predictions[[feature]][index]))
      source_dates <- as.Date(predictions[[value_source[[feature]]]][index])
      cutoff <- as.Date(rows[[cutoff_column]])
      present <- is.finite(values) & !is.na(source_dates) & source_dates < cutoff
      rows[[feature]] <- values
      rows[[paste0(feature, "__source_date")]] <- source_dates
      rows[[paste0(feature, "__source_present")]] <- present
      rows[[paste0(feature, "__value_present")]] <- present
      rows[[paste0(feature, "__imputed")]] <- !present
      rows[[paste0(feature, "__imputation_reason")]] <- ifelse(
        present, "", "dynamic_cold_start_or_missing_prior_evidence"
      )
    }
    rows
  }
  history_augmented <- attach_features(
    history_results, history_replay, "fixture_id", "match_date"
  )
  history_augmented$date <- as.Date(history_augmented$match_date)
  history_augmented$actual_completion_date <- as.Date(history_augmented$match_date)
  history_augmented$match_id <- as.character(history_augmented$fixture_id)
  history_augmented$home_goals <- as.numeric(history_augmented$home_goals)
  history_augmented$away_goals <- as.numeric(history_augmented$away_goals)
  keep <- rep(TRUE, nrow(history_augmented))
  for (feature in c("home_attack_effect", "home_defence_effect", "away_attack_effect", "away_defence_effect")) {
    keep <- keep & is.finite(as.numeric(history_augmented[[feature]])) &
      as.logical(history_augmented[[paste0(feature, "__source_present")]]) &
      !as.logical(history_augmented[[paste0(feature, "__imputed")]])
  }
  history_augmented <- history_augmented[keep, , drop = FALSE]
  if (!nrow(history_augmented)) stop("Dynamic replay left no complete training rows", call. = FALSE)
  target_augmented <- attach_features(
    target, target_replay, "dynamic_fixture_id", "match_date"
  )
  target_augmented$fixture_id <- as.character(target_augmented$fixture_id)
  target_augmented$evidence_cutoff_exclusive <- as.Date(target_augmented$match_date)
  target_augmented$dynamic_fixture_id <- NULL
  target_augmented$match_date <- NULL
  if (!identical(nrow(target_augmented), nrow(fixtures))) stop("Dynamic target replay changed fixture cardinality", call. = FALSE)
  list(history = history_augmented, fixtures = target_augmented)
}

#' Execute the RF challenger through registry, adapter, score service, and
#' evidence manifests.  This runner is research-only and never promotes a
#' candidate or opens the sealed WC2026 panel.
#' @export
run_hybrid_challenger_benchmark <- function(
    history, fixtures, seed_registry = NULL,
    candidate_order = "phase11_rf_dynamic_elo_open",
    settings_by_candidate = list(), run_id = "phase11_hybrid_challenger_run",
    publish = FALSE, output_dir = NULL, protocol = NULL,
    comparison_scores = NULL, comparison_tournaments = NULL,
    comparison_panel_fixtures = NULL, comparison_candidate_ids = NULL,
    comparison_baseline_ids = NULL, parent_hashes = NULL,
    mode_registry = NULL, synthetic = FALSE
) {
  if (isTRUE(publish)) stop("Phase 11 hybrid challenger outputs are research-only; promotion/publishing is disabled", call. = FALSE)
  if (!is.null(output_dir)) {
    output_dir <- as.character(output_dir)
    if (length(output_dir) != 1L || !nzchar(output_dir)) stop("output_dir must be one non-empty path when supplied", call. = FALSE)
  }
  .hybrid_runner_source_if_missing(
    "R/benchmark/hybrid_protocol.R",
    c("load_and_validate_hybrid_protocol")
  )
  .hybrid_runner_source_if_missing(
    "R/benchmark/challenger_preflight.R",
    c("require_hybrid_environment")
  )
  .hybrid_runner_source_if_missing(
    "R/benchmark/hybrid_adapters.R",
    c("hybrid_phase11_candidate_ids", "hybrid_normalize_fixtures", "run_registered_hybrid_adapter")
  )
  .hybrid_runner_source_if_missing(
    "R/evaluation/benchmark_scores.R",
    c("score_benchmark_fixtures")
  )
  .hybrid_runner_source_if_missing(
    "R/benchmark/contracts.R",
    c("benchmark_seed_key_sha256", "validate_seed_registry")
  )
  if (is.null(protocol)) protocol <- load_and_validate_hybrid_protocol()
  candidate_order <- as.character(candidate_order)
  registered <- hybrid_phase11_candidate_ids(protocol)
  if (!length(candidate_order) || anyNA(candidate_order) || any(!candidate_order %in% registered) || anyDuplicated(candidate_order)) {
    stop("candidate_order must contain one or more registered Phase 11 hybrid candidates", call. = FALSE)
  }
  if (!is.data.frame(history) || !nrow(history)) stop("Hybrid runner history must contain rows", call. = FALSE)
  if (exists("guard_benchmark_purpose", mode = "function")) {
    history <- guard_benchmark_purpose(history, purpose = "candidate_selection")
  } else {
    .hybrid_runner_source_if_missing("R/benchmark/cutoffs.R", c("guard_benchmark_purpose"))
    history <- guard_benchmark_purpose(history, purpose = "candidate_selection")
  }
  if (!"track_id" %in% names(fixtures)) {
    stop("Hybrid runner fixtures require explicit track_id values", call. = FALSE)
  }
  track_ids <- sort(unique(as.character(fixtures$track_id)), method = "radix")
  if (!length(track_ids) || anyNA(track_ids) || any(!nzchar(track_ids))) {
    stop("Hybrid runner fixtures require non-empty track_id values", call. = FALSE)
  }
  fixtures <- do.call(rbind, lapply(track_ids, function(track_id) {
    track_fixtures <- fixtures[as.character(fixtures$track_id) == track_id, , drop = FALSE]
    track_fixtures$forecast_sequence_public <- track_fixtures$forecast_sequence
    track_fixtures$forecast_sequence <- seq_len(nrow(track_fixtures))
    hybrid_normalize_fixtures(track_fixtures)
  }))
  rownames(fixtures) <- NULL
  fixtures <- .hybrid_runner_normalize_identifiers(
    fixtures, c("fixture_id", "edition_id", "boundary_id", "home_team_id", "away_team_id", "venue_role")
  )
  history <- .hybrid_runner_normalize_identifiers(
    history, c("match_id", "home_team_id", "away_team_id")
  )
  .hybrid_runner_score_inputs(fixtures)
  bind_frames <- function(pieces) {
    pieces <- pieces[vapply(pieces, is.data.frame, logical(1)) & vapply(pieces, nrow, integer(1)) > 0L]
    if (!length(pieces)) return(data.frame(stringsAsFactors = FALSE))
    columns <- unique(unlist(lapply(pieces, names), use.names = FALSE))
    pieces <- lapply(pieces, function(piece) {
      missing <- setdiff(columns, names(piece))
      for (column in missing) piece[[column]] <- NA
      piece[, columns, drop = FALSE]
    })
    result <- do.call(rbind, pieces)
    rownames(result) <- NULL
    result
  }
  combine_track_adapters <- function(pieces) {
    inactive <- pieces[vapply(pieces, function(piece) isTRUE(piece$inactive), logical(1))]
    if (length(inactive)) return(inactive[[1L]])
    result <- pieces[[1L]]
    for (field in c("predictions", "distributions", "means", "manifests", "feature_coverage")) {
      result[[field]] <- bind_frames(lapply(pieces, `[[`, field))
    }
    result
  }
  track_seed_registries <- lapply(track_ids, function(track_id) {
    if (is.null(seed_registry)) return(NULL)
    track_fixtures <- fixtures[as.character(fixtures$track_id) == track_id, , drop = FALSE]
    seed_index <- match(as.character(track_fixtures$fixture_id), as.character(seed_registry$fixture_id))
    if (anyNA(seed_index)) stop("Hybrid seed registry is missing a requested track fixture", call. = FALSE)
    track_seed_registry <- seed_registry[seed_index, , drop = FALSE]
    track_seed_registry$boundary_id <- as.character(track_fixtures$boundary_id)
    track_seed_registry$seed_key_sha256 <- benchmark_seed_key_sha256(track_seed_registry)
    validate_seed_registry(track_seed_registry)
    track_seed_registry
  })
  adapters <- lapply(candidate_order, function(candidate_id) {
    candidate_settings <- .hybrid_runner_settings_for(settings_by_candidate, candidate_id)
    registration <- hybrid_registration(protocol, candidate_id)
    track_adapters <- lapply(seq_along(track_ids), function(index) {
      track_id <- track_ids[[index]]
      track_fixtures <- fixtures[as.character(fixtures$track_id) == track_id, , drop = FALSE]
      if (.hybrid_adapter_is_context(registration)) {
        context_result <- tryCatch(
          run_registered_hybrid_adapter(
            candidate_id = candidate_id, history = history,
            fixtures = track_fixtures,
            seed_registry = track_seed_registries[[index]], support_max = 40L, run_id = run_id,
            protocol = protocol, settings = candidate_settings
          ),
          error = function(error) error
        )
        if (inherits(context_result, "error")) {
          context_result <- .hybrid_runner_context_inactive_result(
            registration = registration,
            fixtures = track_fixtures,
            seed_registry = track_seed_registries[[index]],
            run_id = run_id,
            protocol = protocol,
            settings = candidate_settings,
            reason = conditionMessage(context_result)
          )
        }
        context_result
      } else {
        run_registered_hybrid_adapter(
          candidate_id = candidate_id, history = history,
          fixtures = track_fixtures,
          seed_registry = track_seed_registries[[index]], support_max = 40L, run_id = run_id,
          protocol = protocol, settings = candidate_settings
        )
      }
    })
    for (index in seq_along(track_adapters)) {
      adapter <- track_adapters[[index]]
      adapter <- .hybrid_runner_namespace_track_distribution_ids(adapter, track_ids[[index]])
      if (!isTRUE(adapter$inactive) && is.data.frame(adapter$predictions) && nrow(adapter$predictions)) {
        track_fixtures <- fixtures[as.character(fixtures$track_id) == track_ids[[index]], , drop = FALSE]
        sequence_index <- match(
          as.character(adapter$predictions$fixture_id), as.character(track_fixtures$fixture_id)
        )
        if (anyNA(sequence_index)) stop("Hybrid adapter predictions lost fixture sequence identity", call. = FALSE)
        adapter$predictions$forecast_sequence <- as.integer(
          track_fixtures$forecast_sequence_public[sequence_index]
        )
        track_adapters[[index]] <- adapter
      }
    }
    combine_track_adapters(track_adapters)
  })
  names(adapters) <- candidate_order
  active_adapters <- adapters[!vapply(adapters, function(adapter) isTRUE(adapter$inactive), logical(1))]
  scores <- if (length(active_adapters)) do.call(rbind, lapply(active_adapters, function(adapter) {
    do.call(rbind, lapply(track_ids, function(track_id) {
      track_fixtures <- fixtures[as.character(fixtures$track_id) == track_id, , drop = FALSE]
      track_predictions <- adapter$predictions[as.character(adapter$predictions$track_id) == track_id, , drop = FALSE]
      track_distribution_ids <- unique(as.character(track_predictions$score_distribution_id))
      score_benchmark_fixtures(
        predictions = track_predictions,
        fixtures = track_fixtures,
        distributions = adapter$distributions[
          as.character(adapter$distributions$score_distribution_id) %in% track_distribution_ids,
          , drop = FALSE
        ],
        expected_fixture_ids = unique(as.character(track_fixtures$fixture_id))
      )
    }))
  })) else data.frame(stringsAsFactors = FALSE)
  bind_active <- function(field) {
    if (!length(active_adapters)) return(data.frame(stringsAsFactors = FALSE))
    pieces <- lapply(active_adapters, `[[`, field)
    bind_frames(pieces)
  }
  predictions <- bind_active("predictions")
  distributions <- bind_active("distributions")
  means <- bind_active("means")
  manifests <- bind_frames(lapply(adapters, `[[`, "manifests"))
  feature_coverage <- bind_active("feature_coverage")
  registration <- do.call(rbind, lapply(adapters, `[[`, "registration"))
  candidate_evidence <- do.call(rbind, lapply(adapters, function(adapter) {
    row <- adapter$registration
    if (isTRUE(adapter$inactive)) return(adapter$inactive_evidence)
    data.frame(
      candidate_id = as.character(row$candidate_id[[1L]]),
      feature_set_id = as.character(row$feature_set_id[[1L]]),
      removed_feature_id = if ("removed_feature_id" %in% names(row)) as.character(row$removed_feature_id[[1L]]) else "",
      panel_id = as.character(row$panel_id[[1L]]),
      open_fixture_count = as.integer(row$open_fixture_count[[1L]]),
      rich_fixture_count = as.integer(row$rich_fixture_count[[1L]]),
      score_support_g = as.integer(row$score_support_g[[1L]]),
      context_parent_hashes = if ("context_parent_hashes" %in% names(row)) as.character(row$context_parent_hashes[[1L]]) else "",
      gate_id = if ("gate_id" %in% names(row)) as.character(row$gate_id[[1L]]) else "",
      gate_parent_sha256 = if ("gate_parent_sha256" %in% names(row)) as.character(row$gate_parent_sha256[[1L]]) else "",
      structural_prior_manifest_sha256 = if ("structural_prior_manifest_sha256" %in% names(row)) {
        as.character(row$structural_prior_manifest_sha256[[1L]])
      } else "",
      structural_snapshot_vintage_id = if ("structural_snapshot_vintage_id" %in% names(row)) {
        as.character(row$structural_snapshot_vintage_id[[1L]])
      } else "",
      prior_strength = if ("prior_strength" %in% names(row) && nzchar(as.character(row$prior_strength[[1L]]))) {
        as.numeric(row$prior_strength[[1L]])
      } else NA_real_,
      active_status = "active",
      score_status = "scored",
      coverage = NA_real_,
      variance = NA_real_,
      provenance = NA,
      score_row_count = nrow(adapter$predictions),
      inactive_reason = "",
      error_reason = "",
      research_only = TRUE,
      wc2026_sealed = TRUE,
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  }))
  if (!is.data.frame(candidate_evidence)) candidate_evidence <- data.frame(stringsAsFactors = FALSE)
  registration_lookup <- registration[match(as.character(candidate_evidence$candidate_id), as.character(registration$candidate_id)), , drop = FALSE]
  candidate_evidence$mode_id <- if (nrow(candidate_evidence)) as.character(registration_lookup$mode_id) else character()
  candidate_evidence$mode_pool <- if (nrow(candidate_evidence)) {
    ifelse(as.character(candidate_evidence$mode_id) == "open_default", "open_only", "companion_only")
  } else character()
  candidate_evidence$complexity_rank <- if (nrow(candidate_evidence)) {
    suppressWarnings(as.numeric(registration_lookup$complexity_rank))
  } else numeric()
  candidate_evidence$open_mode_compatible <- if (nrow(candidate_evidence) && "open_mode_compatible" %in% names(registration_lookup)) {
    as.logical(registration_lookup$open_mode_compatible)
  } else rep(TRUE, nrow(candidate_evidence))
  candidate_evidence$active_status <- as.character(candidate_evidence$active_status)
  candidate_evidence$research_only <- TRUE
  candidate_evidence$wc2026_sealed <- TRUE
  if (is.null(mode_registry) && is.list(protocol) && is.data.frame(protocol$mode_registry)) {
    mode_registry <- protocol$mode_registry
  }
  if (is.null(mode_registry)) mode_registry <- data.frame(stringsAsFactors = FALSE)
  adapter <- if (length(active_adapters)) active_adapters[[1L]] else adapters[[1L]]
  adapter$predictions <- predictions
  adapter$distributions <- distributions
  adapter$means <- means
  adapter$manifests <- manifests
  adapter$feature_coverage <- feature_coverage
  adapter$registration <- registration
  adapter$candidate_evidence <- candidate_evidence
  adapter$comparison_inputs <- candidate_evidence
  environment <- if (length(active_adapters) && is.list(active_adapters[[1L]]$environment)) {
    active_adapters[[1L]]$environment
  } else {
    list(
      package = "", package_version = "", index_sha256 = "", metadata_sha256 = "",
      archive_sha256 = "", installed_content_sha256 = "", offline_replay = TRUE
    )
  }
  .hybrid_runner_source_if_missing(
    "R/evaluation/challenger_selection.R",
    c("challenger_selection_parent_graph_sha256", "hybrid_all_baseline_comparisons", "build_hybrid_research_shortlist")
  )
  if (is.null(parent_hashes)) parent_hashes <- hybrid_phase11_parent_hashes()
  parent_names <- names(parent_hashes)
  parent_hashes <- as.character(parent_hashes)
  names(parent_hashes) <- parent_names
  if (is.null(parent_names) || any(!nzchar(parent_names)) ||
      any(!grepl("^[0-9a-f]{64}$", parent_hashes))) {
    stop("parent_hashes must be named canonical SHA-256 values", call. = FALSE)
  }
  parent_graph_sha256 <- challenger_selection_parent_graph_sha256(parent_hashes)
  parent_paths <- hybrid_phase11_parent_paths()
  parent_inputs <- data.frame(
    parent_id = names(parent_hashes),
    relative_path = unname(parent_paths[names(parent_hashes)]),
    sha256 = unname(parent_hashes),
    status = ifelse(
      file.exists(file.path(.hybrid_runner_root(), unname(parent_paths[names(parent_hashes)]))),
      "present", "optional_absent"
    ),
    source_role = "phase11_registered_parent",
    research_only = TRUE,
    wc2026_sealed = TRUE,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  if (anyNA(parent_inputs$relative_path)) {
    parent_inputs$relative_path <- ifelse(
      is.na(parent_inputs$relative_path), "registered_parent_artifact", parent_inputs$relative_path
    )
  }
  fold_tuning_columns <- intersect(
    c(
      "candidate_id", "feature_set_id", "mode_id", "panel_id", "complexity_rank",
      "tuning_protocol_id", "tuning_grid_id", "score_support_g", "settings_sha256",
      "registration_sha256", "ranger_provenance_id", "research_only", "wc2026_sealed"
    ),
    names(registration)
  )
  fold_tuning <- if (length(fold_tuning_columns)) registration[, fold_tuning_columns, drop = FALSE] else {
    data.frame(stringsAsFactors = FALSE)
  }
  benchmark_summaries <- if (nrow(scores) && exists("aggregate_benchmark_scores", mode = "function")) {
    tryCatch(
      aggregate_benchmark_scores(scores, sort(unique(as.character(fixtures$edition_id)))),
      error = function(error) data.frame(
        summary_status = "unavailable", summary_reason = conditionMessage(error), stringsAsFactors = FALSE
      )
    )
  } else data.frame(stringsAsFactors = FALSE)
  comparison_ids <- if (is.null(comparison_candidate_ids)) {
    sort(unique(as.character(scores$model_id)), method = "radix")
  } else as.character(comparison_candidate_ids)
  baseline_ids <- if (is.null(comparison_baseline_ids)) character() else as.character(comparison_baseline_ids)
  comparisons <- data.frame(stringsAsFactors = FALSE)
  if (length(comparison_ids) && length(baseline_ids) &&
      is.data.frame(comparison_scores) && is.data.frame(comparison_tournaments) &&
      is.data.frame(comparison_panel_fixtures)) {
    all_scores <- rbind(comparison_scores, scores)
    all_scores <- all_scores[!duplicated(all_scores[, intersect(
      c("model_id", "track_id", "fixture_id", "metric", "target"), names(all_scores)
    ), drop = FALSE]), , drop = FALSE]
    comparisons <- hybrid_all_baseline_comparisons(
      scores = all_scores,
      tournaments = comparison_tournaments,
      panel_fixtures = comparison_panel_fixtures,
      candidate_ids = comparison_ids,
      baseline_ids = baseline_ids,
      parent_hashes = parent_hashes
    )
  }
  mode_companion_evidence <- candidate_evidence[
    as.character(candidate_evidence$mode_id) != "open_default" |
      as.character(candidate_evidence$active_status) != "active",
    , drop = FALSE
  ]
  if (!nrow(mode_companion_evidence)) {
    mode_companion_evidence <- data.frame(
      mode_id = character(), candidate_id = character(), active_status = character(),
      score_status = character(), inactive_reason = character(), research_only = logical(),
      wc2026_sealed = logical(), stringsAsFactors = FALSE
    )
  }
  shortlist <- if (nrow(comparisons)) {
    build_hybrid_research_shortlist(
      comparisons = comparisons,
      candidate_evidence = candidate_evidence,
      protocol = protocol,
      parent_hashes = parent_hashes
    )
  } else data.frame(
    slot = character(), candidate_id = character(), mode_id = character(),
    panel_id = character(), candidate_estimate = numeric(), baseline_id = character(),
    baseline_estimate = numeric(), delta = numeric(), paired_fixture_count = integer(),
    evidence_sha256 = character(), selection_basis = character(), non_exclusive = logical(),
    research_only = logical(), wc2026_sealed = logical(), phase12_decision_authority = logical(),
    parent_graph_sha256 = character(), selection_protocol_sha256 = character(),
    stringsAsFactors = FALSE
  )
  run_manifest <- data.frame(
    schema_version = "phase11-hybrid-challenger-bundle-v1",
    run_id = run_id,
    source_git_sha = .hybrid_runner_git_sha(),
    r_version = as.character(getRversion()),
    candidate_count = length(candidate_order),
    track_count = length(unique(fixtures$track_id)),
    edition_count = length(unique(fixtures$edition_id)),
    fixture_slice = FALSE,
    open_fixture_count = 630L,
    rich_fixture_count = 609L,
    selected_g = 40L,
    reproducible = TRUE,
    wc2026_sealed = TRUE,
    network_free = TRUE,
    research_only = TRUE,
    protected_paths_clean = TRUE,
    phase12_decision_authority = FALSE,
    synthetic = isTRUE(synthetic),
    parent_graph_sha256 = parent_graph_sha256,
    parent_count = length(parent_hashes),
    comparison_panel_open_fixture_count = 630L,
    comparison_panel_rich_fixture_count = 609L,
    comparison_candidate_count = length(comparison_ids),
    comparison_baseline_count = length(baseline_ids),
    ranger_package = environment$package,
    ranger_version = environment$package_version,
    ranger_index_sha256 = environment$index_sha256,
    ranger_metadata_sha256 = environment$metadata_sha256,
    ranger_archive_sha256 = environment$archive_sha256,
    ranger_installed_content_sha256 = environment$installed_content_sha256,
    ranger_provenance_id = if (nrow(registration)) registration$ranger_provenance_id[[1L]] else "",
    model_registry_sha256 = .hybrid_runner_file_sha256("data/benchmark/phase11/model_registry.csv"),
    feature_contract_sha256 = .hybrid_runner_file_sha256("data/benchmark/phase11/feature_contract.csv"),
    context_ablation_registry_sha256 = .hybrid_runner_file_sha256("data/benchmark/phase11/context_ablation_registry.csv"),
    centroid_registry_sha256 = .hybrid_runner_file_sha256("data/benchmark/phase11/country_centroids.csv"),
    centroid_metadata_sha256 = .hybrid_runner_file_sha256("data/benchmark/phase11/country_centroids_metadata.csv"),
    registration_sha256 = paste(as.character(registration$registration_sha256), collapse = "|"),
    settings_sha256 = paste(as.character(registration$settings_sha256), collapse = "|"),
    candidate_id = paste(candidate_order, collapse = "|"),
    candidate_ids = paste(candidate_order, collapse = "|"),
    parent_ids = paste(names(parent_hashes), collapse = "|"),
    output_dir = if (is.null(output_dir)) "" else output_dir,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  result <- list(
    run_manifest = run_manifest,
    predictions = predictions,
    distributions = distributions,
    means = means,
    scores = scores,
    benchmark_summaries = benchmark_summaries,
    manifests = manifests,
    feature_coverage = feature_coverage,
    fold_tuning = fold_tuning,
    registration = registration,
    candidate_evidence = candidate_evidence,
    comparisons = comparisons,
    shortlist = shortlist,
    mode_registry = mode_registry,
    mode_companion_evidence = mode_companion_evidence,
    parent_inputs = parent_inputs,
    parent_hashes = parent_hashes,
    parent_graph_sha256 = parent_graph_sha256,
    environment = environment,
    research_only = TRUE,
    wc2026_sealed = TRUE,
    network_free = TRUE,
    phase12_decision_authority = FALSE,
    durable = FALSE
  )
  validate_hybrid_challenger_bundle(result)
  result
}

.hybrid_runner_bundle_specs <- function(bundle, stage_root) {
  paths <- hybrid_output_paths(stage_root)
  data_fields <- c(
    "run_manifest", "predictions", "distributions", "scores", "benchmark_summaries",
    "manifests", "feature_coverage", "fold_tuning", "parent_inputs", "candidate_evidence",
    "comparisons", "shortlist", "mode_registry", "mode_companion_evidence"
  )
  missing <- setdiff(data_fields, names(bundle))
  if (length(missing)) stop("Hybrid bundle cannot be staged without: ", paste(missing, collapse = ", "), call. = FALSE)
  relative <- c(
    "run_manifest.csv",
    "predictions/fixture_predictions.csv",
    "predictions/score_distributions.csv",
    "scores/fixture_scores.csv",
    "scores/benchmark_summaries.csv",
    "manifests/model_manifests.csv",
    "manifests/feature_coverage.csv",
    "manifests/fold_tuning.csv",
    "manifests/parent_inputs.csv",
    "selection/candidate_evidence.csv",
    "selection/all_baseline_paired_comparisons.csv",
    "selection/hybrid_shortlist.csv",
    "modes/mode_registry.csv",
    "modes/mode_companion_evidence.csv"
  )
  fields <- c(
    "run_manifest", "predictions", "distributions", "scores", "benchmark_summaries",
    "manifests", "feature_coverage", "fold_tuning", "parent_inputs", "candidate_evidence",
    "comparisons", "shortlist", "mode_registry", "mode_companion_evidence"
  )
  kinds <- c(
    "run_manifest", "predictions", "distributions", "fixture_scores", "summaries",
    "model_manifests", "feature_coverage", "fold_tuning", "parent_inputs", "candidate_evidence",
    "paired_comparisons", "research_shortlist", "mode_registry", "mode_companion_evidence"
  )
  specs <- Map(function(field, path, kind) list(
    field = field, relative = path, kind = kind, data = bundle[[field]],
    output = file.path(stage_root, path)
  ), fields, relative, kinds)
  report <- if (!is.null(bundle$research_report)) {
    as.character(bundle$research_report)
  } else {
    paste(
      "Phase 11 hybrid challenger evidence bundle",
      "research_only=TRUE",
      "wc2026_sealed=TRUE",
      "phase12_decision_authority=FALSE",
      "open_fixture_count=630",
      "rich_fixture_count=609",
      "selected_g=40",
      sep = "\n"
    )
  }
  specs[[length(specs) + 1L]] <- list(
    field = "research_report", relative = "reports/research_only_report.txt",
    kind = "research_report", data = report, output = paths[["research_report"]]
  )
  specs
}

.hybrid_runner_stage_bundle <- function(bundle, stage_root) {
  dir.create(stage_root, recursive = TRUE, showWarnings = FALSE)
  specs <- .hybrid_runner_bundle_specs(bundle, stage_root)
  for (spec in specs) {
    if (identical(spec$field, "research_report")) {
      dir.create(dirname(spec$output), recursive = TRUE, showWarnings = FALSE)
      writeLines(spec$data, spec$output, useBytes = TRUE)
    } else {
      .hybrid_runner_write_csv(spec$data, spec$output)
    }
  }
  parent_graph <- if (!is.null(bundle$parent_graph_sha256)) {
    as.character(bundle$parent_graph_sha256)
  } else as.character(bundle$run_manifest$parent_graph_sha256[[1L]])
  checksum_rows <- do.call(rbind, lapply(specs, function(spec) {
    data.frame(
      artifact_path = spec$relative,
      artifact_kind = spec$kind,
      sha256 = digest::digest(spec$output, algo = "sha256", file = TRUE),
      row_count = if (identical(spec$field, "research_report")) NA_integer_ else nrow(spec$data),
      required = TRUE,
      parent_graph_sha256 = parent_graph,
      mode_id = if (identical(spec$field, "mode_registry")) "all_registered_modes" else "open_default",
      panel_id = if (identical(spec$field, "mode_registry")) "mode_specific" else "open_core",
      selected_g = 40L,
      open_fixture_count = 630L,
      rich_fixture_count = 609L,
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  }))
  checksum_rows <- rbind(
    checksum_rows,
    data.frame(
      artifact_path = "manifests/checksum_manifest.csv",
      artifact_kind = "checksum_manifest",
      sha256 = .hybrid_runner_table_hash(checksum_rows),
      row_count = nrow(checksum_rows) + 1L,
      required = TRUE,
      parent_graph_sha256 = parent_graph,
      mode_id = "all_registered_modes",
      panel_id = "mode_specific",
      selected_g = 40L,
      open_fixture_count = 630L,
      rich_fixture_count = 609L,
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  )
  .hybrid_runner_write_csv(checksum_rows, file.path(stage_root, "manifests/checksum_manifest.csv"))
  invisible(stage_root)
}

#' Stage and atomically install the Phase 11 research evidence bundle.
#' @export
write_hybrid_challenger_bundle <- function(result, output_dir) {
  if (!is.list(result)) stop("Hybrid bundle result must be a list", call. = FALSE)
  if (isTRUE(result$phase12_decision_authority) || !isTRUE(result$research_only) ||
      !isTRUE(result$wc2026_sealed)) {
    stop("Only sealed research-only hybrid evidence may be written", call. = FALSE)
  }
  if (!is.data.frame(result$shortlist) || !nrow(result$shortlist)) {
    stop("Hybrid bundle publication requires a populated research shortlist", call. = FALSE)
  }
  output_dir <- as.character(output_dir)
  if (length(output_dir) != 1L || is.na(output_dir) || !nzchar(output_dir)) {
    stop("output_dir must be one non-empty path", call. = FALSE)
  }
  .hybrid_runner_source_if_missing(
    "R/benchmark/runner.R", c("benchmark_runner_install_staged_bundle")
  )
  staged_root <- tempfile(
    paste0(".", basename(normalizePath(output_dir, mustWork = FALSE)), "-stage-"),
    tmpdir = dirname(normalizePath(output_dir, mustWork = FALSE))
  )
  .hybrid_runner_stage_bundle(result, staged_root)
  validate_hybrid_challenger_bundle(staged_root)
  benchmark_runner_install_staged_bundle(
    staged_root, output_dir, validate_hybrid_challenger_bundle
  )
  validate_hybrid_challenger_bundle(output_dir)
  hybrid_output_paths(output_dir)
}
