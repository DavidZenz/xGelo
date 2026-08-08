#' Phase 11 registered adapters for hybrid challenger candidates

.hybrid_adapter_source_if_missing <- function(relative_path, symbols) {
  missing <- symbols[!vapply(symbols, exists, logical(1), mode = "function")]
  if (!length(missing)) return(invisible(TRUE))
  root <- if (exists(".phase11_protocol_root", mode = "function")) {
    .phase11_protocol_root(".")
  } else {
    normalizePath(".", mustWork = TRUE)
  }
  path <- file.path(root, relative_path)
  if (!file.exists(path)) stop("Phase 11 hybrid adapter dependency is missing: ", relative_path, call. = FALSE)
  source(path, local = .GlobalEnv)
  missing_after <- missing[!vapply(missing, exists, logical(1), mode = "function")]
  if (length(missing_after)) stop("Phase 11 hybrid adapter dependency did not define: ", paste(missing_after, collapse = ", "), call. = FALSE)
  invisible(TRUE)
}

hybrid_phase11_candidate_ids <- function(protocol = NULL) {
  if (is.null(protocol)) {
    .hybrid_adapter_source_if_missing("R/benchmark/hybrid_protocol.R", c("load_and_validate_hybrid_protocol"))
    protocol <- load_and_validate_hybrid_protocol()
  }
  ids <- as.character(protocol$model_registry$candidate_id)
  ids[ids == "phase11_rf_dynamic_elo_open"]
}

.hybrid_adapter_registration <- function(protocol, candidate_id) {
  .hybrid_adapter_source_if_missing(
    "R/benchmark/hybrid_protocol.R",
    c("hybrid_registration", "validate_hybrid_model_registry")
  )
  if (!inherits(protocol, "validated_hybrid_protocol") || !isTRUE(protocol$valid)) {
    stop("hybrid adapter requires a validated Phase 11 protocol", call. = FALSE)
  }
  allowed <- hybrid_phase11_candidate_ids(protocol)
  if (!identical(as.character(candidate_id), allowed)) {
    stop("unknown or inactive Phase 11 hybrid candidate_id", call. = FALSE)
  }
  hybrid_registration(protocol, candidate_id)
}

#' Normalize only benchmark identity and chronology fields; source features are
#' never imputed by the adapter.
#' @export
hybrid_normalize_fixtures <- function(fixtures) {
  .hybrid_adapter_source_if_missing(
    "R/benchmark/contracts.R",
    c("benchmark_contract_require_columns")
  )
  required <- c(
    "edition_id", "fixture_id", "boundary_id", "home_team_id", "away_team_id",
    "venue_role", "actual_completion_date", "evidence_cutoff_exclusive"
  )
  benchmark_contract_require_columns(fixtures, required, "Hybrid adapter fixtures")
  result <- fixtures
  result$edition_id <- as.character(result$edition_id)
  result$fixture_id <- as.character(result$fixture_id)
  result$boundary_id <- as.character(result$boundary_id)
  result$home_team_id <- as.character(result$home_team_id)
  result$away_team_id <- as.character(result$away_team_id)
  result$venue_role <- as.character(result$venue_role)
  if (any(is.na(result$fixture_id) | !nzchar(result$fixture_id)) || anyDuplicated(result$fixture_id)) {
    stop("Hybrid adapter fixture IDs must be unique and non-empty", call. = FALSE)
  }
  if (any(is.na(result$edition_id) | !nzchar(result$edition_id)) ||
      any(is.na(result$boundary_id) | !nzchar(result$boundary_id)) ||
      any(is.na(result$home_team_id) | !nzchar(result$home_team_id)) ||
      any(is.na(result$away_team_id) | !nzchar(result$away_team_id)) ||
      any(is.na(result$venue_role) | !nzchar(result$venue_role))) {
    stop("Hybrid adapter fixture identity is incomplete", call. = FALSE)
  }
  result$actual_completion_date <- as.Date(result$actual_completion_date)
  result$evidence_cutoff_exclusive <- as.Date(result$evidence_cutoff_exclusive)
  if (anyNA(result$actual_completion_date) || anyNA(result$evidence_cutoff_exclusive) ||
      any(result$evidence_cutoff_exclusive > result$actual_completion_date)) {
    stop("Hybrid adapter fixture chronology is invalid", call. = FALSE)
  }
  if (!"track_id" %in% names(result)) result$track_id <- "frozen"
  result$track_id <- as.character(result$track_id)
  if (any(is.na(result$track_id) | !nzchar(result$track_id))) stop("Hybrid adapter track_id values must be explicit", call. = FALSE)
  if (!"forecast_sequence" %in% names(result)) result$forecast_sequence <- seq_len(nrow(result))
  result$forecast_sequence <- as.integer(result$forecast_sequence)
  if (anyNA(result$forecast_sequence) || anyDuplicated(result[c("track_id", "forecast_sequence")])) {
    stop("Hybrid adapter forecast_sequence values must be unique within each track", call. = FALSE)
  }
  if (!"result_cutoff_exclusive" %in% names(result)) {
    result$result_cutoff_exclusive <- result$evidence_cutoff_exclusive
  } else {
    result$result_cutoff_exclusive <- as.Date(result$result_cutoff_exclusive)
  }
  if (anyNA(result$result_cutoff_exclusive) || any(result$result_cutoff_exclusive > result$evidence_cutoff_exclusive)) {
    stop("Hybrid adapter result cutoffs must not exceed evidence cutoffs", call. = FALSE)
  }
  if (any(result$home_team_id == result$away_team_id)) stop("Hybrid adapter fixtures cannot have identical teams", call. = FALSE)
  rownames(result) <- NULL
  result
}

hybrid_default_seed_registry <- function(fixtures, seed = 920001L) {
  .hybrid_adapter_source_if_missing(
    "R/benchmark/contracts.R",
    c("benchmark_seed_key_sha256", "validate_seed_registry", "benchmark_contract_row_hash")
  )
  fixtures <- hybrid_normalize_fixtures(fixtures)
  seed <- as.integer(seed)
  if (length(seed) != 1L || is.na(seed) || seed < 0L) stop("Hybrid seed base must be one non-negative integer", call. = FALSE)
  registry <- data.frame(
    schema_version = "1.0",
    seed_id = paste0("phase11_seed__", fixtures$edition_id, "__", fixtures$fixture_id),
    purpose = "phase11_hybrid_challenger_common_random_number",
    edition_id = fixtures$edition_id,
    boundary_id = fixtures$boundary_id,
    fixture_id = fixtures$fixture_id,
    seed = seed + seq_len(nrow(fixtures)) - 1L,
    model_independent = TRUE,
    seed_key_sha256 = "",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  registry$seed_key_sha256 <- benchmark_seed_key_sha256(registry)
  validate_seed_registry(registry)
  registry
}

.hybrid_adapter_seed_registry <- function(fixtures, seed_registry = NULL) {
  if (is.null(seed_registry)) return(hybrid_default_seed_registry(fixtures))
  .hybrid_adapter_source_if_missing("R/benchmark/contracts.R", c("validate_seed_registry"))
  validate_seed_registry(seed_registry)
  required <- c("edition_id", "boundary_id", "fixture_id")
  if (any(!fixtures$fixture_id %in% seed_registry$fixture_id)) stop("Hybrid seed registry is missing fixture seeds", call. = FALSE)
  seed_index <- match(fixtures$fixture_id, seed_registry$fixture_id)
  if (any(as.character(seed_registry$edition_id[seed_index]) != fixtures$edition_id) ||
      any(as.character(seed_registry$boundary_id[seed_index]) != fixtures$boundary_id)) {
    stop("Hybrid seed registry fixture identity does not match the adapter fixtures", call. = FALSE)
  }
  seed_registry
}

.hybrid_manifest_rows <- function(fit, registration, fixtures, history, run_id, mean_predictions) {
  .hybrid_adapter_source_if_missing(
    "R/benchmark/contracts.R",
    c("benchmark_contract_sha256", "validate_model_manifests")
  )
  date_candidates <- c("actual_completion_date", "date", "match_date", "result_date")
  date_col <- intersect(date_candidates, names(history))[[1L]]
  history_dates <- as.Date(history[[date_col]])
  boundaries <- unique(fixtures[c("edition_id", "track_id", "boundary_id", "evidence_cutoff_exclusive")])
  rows <- lapply(seq_len(nrow(boundaries)), function(index) {
    boundary <- boundaries[index, , drop = FALSE]
    cutoff <- as.Date(boundary$evidence_cutoff_exclusive[[1L]])
    eligible <- history_dates[!is.na(history_dates) & history_dates < cutoff]
    if (!length(eligible)) stop("Hybrid manifest cannot be created without pre-cutoff history", call. = FALSE)
    boundary_means <- mean_predictions[mean_predictions$boundary_id == boundary$boundary_id[[1L]], , drop = FALSE]
    mean_hash <- if (nrow(boundary_means)) {
      benchmark_contract_sha256(sort(as.character(boundary_means$mean_prediction_hash)))
    } else {
      benchmark_contract_sha256(character())
    }
    model_manifest_id <- paste(run_id, registration$candidate_id[[1L]], boundary$boundary_id[[1L]], sep = "__")
    data.frame(
      model_manifest_id = model_manifest_id,
      run_id = run_id,
      model_id = registration$candidate_id[[1L]],
      edition_id = boundary$edition_id[[1L]],
      track_id = boundary$track_id[[1L]],
      boundary_id = boundary$boundary_id[[1L]],
      fit_status = "ok",
      fit_row_count = fit$fit_row_count,
      fit_min_date = min(eligible),
      fit_max_date = max(eligible),
      max_result_date = max(eligible),
      max_feature_source_date = fit$max_feature_source_date,
      evidence_cutoff_exclusive = cutoff,
      active_predictors = paste(fit$active_predictors, collapse = "|"),
      dropped_predictors_with_reason = "",
      model_family = fit$model_family,
      convergence_status = fit$convergence_status,
      fallback_status = fit$fallback_status,
      adapter_version = registration$adapter_version[[1L]],
      code_version = "phase11-v1",
      r_version = as.character(getRversion()),
      package_versions = paste0("ranger=", fit$ranger_version, ";digest=", as.character(utils::packageVersion("digest"))),
      registration_sha256 = fit$registration_sha256,
      settings_sha256 = fit$settings_sha256,
      parent_hashes = benchmark_contract_sha256(c(
        fit$registration_sha256, fit$settings_sha256, fit$fit_data_sha256, boundary$boundary_id[[1L]]
      )),
      mean_parent_candidate_id = registration$candidate_id[[1L]],
      mean_prediction_hash = mean_hash,
      ranger_package = fit$ranger_package,
      ranger_version = fit$ranger_version,
      ranger_provenance_id = fit$ranger_provenance_id,
      research_only = TRUE,
      wc2026_sealed = TRUE,
      mode_id = registration$mode_id[[1L]],
      open_fixture_count = as.integer(registration$open_fixture_count[[1L]]),
      rich_fixture_count = as.integer(registration$rich_fixture_count[[1L]]),
      score_support_g = as.integer(registration$score_support_g[[1L]]),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  })
  do.call(rbind, rows)
}

.hybrid_adapter_markets <- function(distributions, fixture_ids) {
  .hybrid_adapter_source_if_missing(
    "R/benchmark/contracts.R",
    c("derive_benchmark_markets")
  )
  rows <- lapply(fixture_ids, function(fixture_id) {
    grid <- distributions[distributions$mean_parent_id == fixture_id, , drop = FALSE]
    if (!nrow(grid)) stop("Hybrid distributions are missing fixture ", fixture_id, call. = FALSE)
    market <- derive_benchmark_markets(grid)
    data.frame(
      fixture_id = fixture_id,
      score_distribution_id = as.character(grid$score_distribution_id[[1L]]),
      as.data.frame(market, stringsAsFactors = FALSE),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  })
  result <- do.call(rbind, rows)
  rownames(result) <- NULL
  result
}

#' Run one registered Phase 11 RF candidate through fit, prediction, evidence,
#' and common-contract validation.
#' @export
run_registered_hybrid_adapter <- function(
    candidate_id, history, fixtures, seed_registry = NULL, support_max = 40L,
    run_id = "benchmark_run", protocol = NULL, settings = list()
) {
  .hybrid_adapter_source_if_missing(
    "R/benchmark/hybrid_protocol.R",
    c("load_and_validate_hybrid_protocol", "hybrid_registration")
  )
  .hybrid_adapter_source_if_missing(
    "R/forecast/hybrid_rf.R",
    c("hybrid_rf_registered_settings", "fit_hybrid_two_goal_rf", "predict_hybrid_rf_means", "hybrid_rf_nb_score_distributions")
  )
  .hybrid_adapter_source_if_missing(
    "R/benchmark/contracts.R",
    c(
      "benchmark_contract_require_columns", "validate_benchmark_predictions",
      "validate_model_manifests", "build_registered_feature_coverage",
      "validate_benchmark_feature_evidence", "benchmark_feature_coverage_id"
    )
  )
  if (is.null(protocol)) protocol <- load_and_validate_hybrid_protocol()
  registration <- .hybrid_adapter_registration(protocol, candidate_id)
  fixtures <- hybrid_normalize_fixtures(fixtures)
  if (!is.data.frame(history) || !nrow(history)) stop("Hybrid adapter history must contain rows", call. = FALSE)
  seed_registry <- .hybrid_adapter_seed_registry(fixtures, seed_registry)
  settings <- hybrid_rf_registered_settings(settings, registration)
  if (as.integer(support_max) != settings$support_max) stop("Hybrid adapter support differs from registered G=40", call. = FALSE)

  boundary_groups <- split(seq_len(nrow(fixtures)), as.character(fixtures$boundary_id))
  pieces <- lapply(boundary_groups, function(index) {
    boundary_fixtures <- fixtures[index, , drop = FALSE]
    cutoffs <- unique(as.Date(boundary_fixtures$evidence_cutoff_exclusive))
    if (length(cutoffs) != 1L || is.na(cutoffs[[1L]])) stop("Hybrid boundary requires one exclusive evidence cutoff", call. = FALSE)
    fit <- fit_hybrid_two_goal_rf(history, cutoffs[[1L]], settings, registration)
    means <- predict_hybrid_rf_means(fit, boundary_fixtures, settings)
    distributions <- hybrid_rf_nb_score_distributions(means, settings$support_max, settings)
    markets <- .hybrid_adapter_markets(distributions, as.character(boundary_fixtures$fixture_id))
    list(fit = fit, fixtures = boundary_fixtures, means = means, distributions = distributions, markets = markets)
  })
  distributions <- do.call(rbind, lapply(pieces, `[[`, "distributions"))
  means <- do.call(rbind, lapply(pieces, `[[`, "means"))
  markets <- do.call(rbind, lapply(pieces, `[[`, "markets"))
  manifests <- do.call(rbind, lapply(pieces, function(piece) {
    .hybrid_manifest_rows(piece$fit, registration, piece$fixtures, history, run_id, piece$means)
  }))
  manifests <- manifests[!duplicated(manifests$model_manifest_id), , drop = FALSE]
  fixture_index <- match(as.character(fixtures$fixture_id), as.character(markets$fixture_id))
  market <- markets[fixture_index, , drop = FALSE]
  seeds <- seed_registry[match(fixtures$fixture_id, seed_registry$fixture_id), , drop = FALSE]
  model_manifest_ids <- paste(run_id, registration$candidate_id, fixtures$boundary_id, sep = "__")
  predictions <- data.frame(
    schema_version = "1.0",
    run_id = run_id,
    model_id = registration$candidate_id,
    panel_id = registration$panel_id,
    edition_id = fixtures$edition_id,
    track_id = fixtures$track_id,
    fixture_id = fixtures$fixture_id,
    boundary_id = fixtures$boundary_id,
    forecast_sequence = fixtures$forecast_sequence,
    home_team_id = fixtures$home_team_id,
    away_team_id = fixtures$away_team_id,
    venue_role = fixtures$venue_role,
    evidence_cutoff_exclusive = fixtures$evidence_cutoff_exclusive,
    result_cutoff_exclusive = fixtures$result_cutoff_exclusive,
    model_manifest_id = model_manifest_ids,
    feature_coverage_id = vapply(seq_len(nrow(fixtures)), function(index) {
      benchmark_feature_coverage_id(
        run_id, registration$candidate_id, fixtures$track_id[index], fixtures$boundary_id[index], fixtures$fixture_id[index]
      )
    }, character(1)),
    seed_id = seeds$seed_id,
    score_distribution_id = market$score_distribution_id,
    p_home = market$p_home,
    p_draw = market$p_draw,
    p_away = market$p_away,
    expected_home_goals = market$expected_home_goals,
    expected_away_goals = market$expected_away_goals,
    p_over_2_5 = market$p_over_2_5,
    p_under_2_5 = market$p_under_2_5,
    p_btts = market$p_btts,
    modal_home_goals = market$modal_home_goals,
    modal_away_goals = market$modal_away_goals,
    modal_score_probability = market$modal_score_probability,
    prediction_status = "ok",
    failure_reason = "",
    mean_prediction_hash = means$mean_prediction_hash[match(fixtures$fixture_id, means$fixture_id)],
    registration_sha256 = settings$registration_sha256,
    settings_sha256 = settings$settings_sha256,
    ranger_package = settings$ranger_package,
    ranger_version = settings$ranger_version,
    ranger_provenance_id = settings$ranger_provenance_id,
    research_only = TRUE,
    wc2026_sealed = TRUE,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  validate_model_manifests(manifests)
  validate_benchmark_predictions(predictions, fixtures, distributions, seed_registry, settings$support_max)
  feature_contract <- protocol$feature_contract
  feature_coverage <- build_registered_feature_coverage(
    registration, predictions, fixtures, feature_contract, manifests
  )
  model_registry <- data.frame(
    model_id = registration$candidate_id,
    panel_id = registration$panel_id,
    stringsAsFactors = FALSE
  )
  validate_benchmark_feature_evidence(predictions, feature_coverage, model_registry, feature_contract)
  list(
    candidate_id = candidate_id,
    registration = registration,
    settings = settings,
    protocol = protocol,
    predictions = predictions,
    distributions = distributions,
    means = means,
    manifests = manifests,
    feature_coverage = feature_coverage,
    seed_registry = seed_registry,
    environment = pieces[[1L]]$fit$environment,
    research_only = TRUE,
    wc2026_sealed = TRUE
  )
}
