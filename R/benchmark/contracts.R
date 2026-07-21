#' Shared benchmark adapter and artifact contracts

benchmark_contract_require_columns <- function(data, required, name) {
  if (!is.data.frame(data)) stop(name, " must be a data frame", call. = FALSE)
  missing <- setdiff(required, names(data))
  if (length(missing)) stop(name, " missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  invisible(TRUE)
}

benchmark_contract_require_unique <- function(data, keys, name) {
  if (anyDuplicated(data[keys])) {
    stop(name, " contains duplicate keys: ", paste(keys, collapse = ", "), call. = FALSE)
  }
  invisible(TRUE)
}

benchmark_contract_sha256 <- function(values) {
  if (!requireNamespace("digest", quietly = TRUE)) stop("digest is required for benchmark contracts", call. = FALSE)
  digest::digest(paste(values, collapse = "|"), algo = "sha256", serialize = FALSE)
}

benchmark_contract_scalar <- function(x) {
  if (inherits(x, "Date")) x <- format(x, "%Y-%m-%d")
  if (is.logical(x)) x <- ifelse(is.na(x), "", ifelse(x, "true", "false"))
  x <- as.character(x)
  x[is.na(x)] <- ""
  x
}

benchmark_contract_row_hash <- function(data, hash_col) {
  fields <- setdiff(names(data), hash_col)
  vapply(seq_len(nrow(data)), function(i) {
    benchmark_contract_sha256(vapply(data[i, fields, drop = FALSE], benchmark_contract_scalar, character(1)))
  }, character(1))
}

benchmark_contract_validate_hash <- function(data, hash_col, name) {
  benchmark_contract_require_columns(data, hash_col, name)
  actual <- tolower(as.character(data[[hash_col]]))
  if (any(!grepl("^[0-9a-f]{64}$", actual))) {
    stop(name, " contains noncanonical ", hash_col, " values", call. = FALSE)
  }
  expected <- benchmark_contract_row_hash(data, hash_col)
  if (any(actual != expected)) stop(name, " row SHA-256 mismatch", call. = FALSE)
  invisible(TRUE)
}

#' Columns required from every successful benchmark prediction
#' @export
benchmark_prediction_columns <- function() {
  c(
    "schema_version", "run_id", "model_id", "panel_id", "edition_id", "track_id",
    "fixture_id", "boundary_id", "forecast_sequence", "home_team_id", "away_team_id",
    "venue_role", "evidence_cutoff_exclusive", "result_cutoff_exclusive",
    "model_manifest_id", "feature_coverage_id", "seed_id", "score_distribution_id",
    "p_home", "p_draw", "p_away", "expected_home_goals", "expected_away_goals",
    "p_over_2_5", "p_under_2_5", "p_btts", "modal_home_goals",
    "modal_away_goals", "modal_score_probability", "prediction_status", "failure_reason"
  )
}

#' Derive all benchmark markets from one joint score distribution
#' @export
derive_benchmark_markets <- function(distribution, tolerance = 1e-10) {
  score <- distribution[, c("home_goals", "away_goals", "probability"), drop = FALSE]
  score <- validate_scoreline_distribution(score, tolerance = tolerance)
  modal <- score[which.max(score$probability), , drop = FALSE]
  list(
    p_home = sum(score$probability[score$home_goals > score$away_goals]),
    p_draw = sum(score$probability[score$home_goals == score$away_goals]),
    p_away = sum(score$probability[score$home_goals < score$away_goals]),
    expected_home_goals = sum(score$home_goals * score$probability),
    expected_away_goals = sum(score$away_goals * score$probability),
    p_over_2_5 = sum(score$probability[score$home_goals + score$away_goals > 2L]),
    p_under_2_5 = sum(score$probability[score$home_goals + score$away_goals <= 2L]),
    p_btts = sum(score$probability[score$home_goals > 0L & score$away_goals > 0L]),
    modal_home_goals = as.integer(modal$home_goals),
    modal_away_goals = as.integer(modal$away_goals),
    modal_score_probability = as.numeric(modal$probability)
  )
}

#' Validate complete fixed-support score distributions
#' @export
validate_benchmark_score_distributions <- function(
    distributions, expected_distribution_ids, support_max,
    tolerance = 1e-10, raw_tail_tolerance = 1e-10
) {
  required <- c(
    "score_distribution_id", "home_goals", "away_goals", "probability",
    "support_max_home", "support_max_away", "raw_tail_mass", "normalized"
  )
  benchmark_contract_require_columns(distributions, required, "Benchmark score distributions")
  if (!nrow(distributions)) stop("Benchmark score distributions must not be empty", call. = FALSE)
  expected_distribution_ids <- as.character(expected_distribution_ids)
  actual_ids <- unique(as.character(distributions$score_distribution_id))
  if (anyDuplicated(expected_distribution_ids) || !setequal(actual_ids, expected_distribution_ids)) {
    stop("Benchmark score distributions do not match the expected distribution IDs", call. = FALSE)
  }
  support_max <- as.integer(support_max)
  if (length(support_max) != 1L || is.na(support_max) || support_max < 0L) {
    stop("support_max must be one non-negative integer", call. = FALSE)
  }
  for (id in expected_distribution_ids) {
    rows <- distributions[distributions$score_distribution_id == id, , drop = FALSE]
    if (any(rows$support_max_home != support_max) || any(rows$support_max_away != support_max)) {
      stop("Benchmark score distribution support differs from the sealed global support", call. = FALSE)
    }
    tail_values <- unique(as.numeric(rows$raw_tail_mass))
    if (length(tail_values) != 1L || !is.finite(tail_values)) {
      stop("Benchmark score distribution requires one finite raw omitted tail", call. = FALSE)
    }
    if (any(is.na(rows$normalized) | !rows$normalized)) {
      stop("Benchmark score distribution must be normalized after tail audit", call. = FALSE)
    }
    validate_scoreline_distribution(
      rows[, c("home_goals", "away_goals", "probability"), drop = FALSE],
      tolerance = tolerance, support_max = support_max, require_full_rectangle = TRUE,
      raw_tail_mass = tail_values, tail_tolerance = raw_tail_tolerance
    )
  }
  invisible(distributions)
}

#' Hash model-independent seed identities
#' @export
benchmark_seed_key_sha256 <- function(seed_registry) {
  benchmark_contract_row_hash(seed_registry, "seed_key_sha256")
}

#' Validate the common-random-number seed registry
#' @export
validate_seed_registry <- function(seed_registry) {
  required <- c(
    "schema_version", "seed_id", "purpose", "edition_id", "boundary_id",
    "fixture_id", "seed", "model_independent", "seed_key_sha256"
  )
  benchmark_contract_require_columns(seed_registry, required, "Seed registry")
  if ("model_id" %in% names(seed_registry)) stop("Seed identity must not contain model_id", call. = FALSE)
  benchmark_contract_require_unique(seed_registry, "seed_id", "Seed registry")
  benchmark_contract_require_unique(seed_registry, "seed_key_sha256", "Seed registry")
  if (any(is.na(seed_registry$model_independent) | !seed_registry$model_independent)) {
    stop("Every shared seed must be model independent", call. = FALSE)
  }
  if (any(!is.finite(seed_registry$seed) | seed_registry$seed != as.integer(seed_registry$seed))) {
    stop("Seed values must be finite integers", call. = FALSE)
  }
  expected <- benchmark_seed_key_sha256(seed_registry)
  if (any(tolower(seed_registry$seed_key_sha256) != expected)) stop("Seed registry seed key SHA-256 mismatch", call. = FALSE)
  invisible(seed_registry)
}

#' Validate exact prediction rows and distribution-derived targets
#' @export
validate_benchmark_predictions <- function(
    predictions, fixtures, distributions, seed_registry, support_max,
    tolerance = 1e-10, raw_tail_tolerance = 1e-10
) {
  benchmark_contract_require_columns(predictions, benchmark_prediction_columns(), "Benchmark predictions")
  fixture_columns <- c("edition_id", "fixture_id", "boundary_id", "home_team_id", "away_team_id", "venue_role", "actual_completion_date")
  benchmark_contract_require_columns(fixtures, fixture_columns, "Expected fixtures")
  benchmark_contract_require_unique(predictions, "fixture_id", "Benchmark predictions")
  benchmark_contract_require_unique(fixtures, "fixture_id", "Expected fixtures")
  if (!setequal(predictions$fixture_id, fixtures$fixture_id)) {
    stop("Benchmark predictions must contain exactly one row for every requested fixture", call. = FALSE)
  }
  if (any(is.na(predictions$prediction_status) | predictions$prediction_status != "ok")) {
    stop("Benchmark predictions contain explicit failure rows and cannot be scored", call. = FALSE)
  }
  fixture_index <- match(predictions$fixture_id, fixtures$fixture_id)
  identity <- c("edition_id", "boundary_id", "home_team_id", "away_team_id", "venue_role")
  if (any(vapply(identity, function(column) {
    as.character(predictions[[column]]) != as.character(fixtures[[column]][fixture_index])
  }, logical(nrow(predictions))))) {
    stop("Benchmark prediction fixture, team, boundary, or venue identity is not registered", call. = FALSE)
  }
  validate_seed_registry(seed_registry)
  if (any(!predictions$seed_id %in% seed_registry$seed_id)) stop("Benchmark prediction contains an unregistered seed", call. = FALSE)
  evidence <- as.Date(predictions$evidence_cutoff_exclusive)
  result <- as.Date(predictions$result_cutoff_exclusive)
  assessment <- as.Date(fixtures$actual_completion_date[fixture_index])
  if (any(is.na(evidence) | is.na(result) | evidence > assessment | result > evidence)) {
    stop("Benchmark prediction cutoffs violate point-in-time provenance", call. = FALSE)
  }
  validate_benchmark_score_distributions(
    distributions, predictions$score_distribution_id, support_max,
    tolerance = tolerance, raw_tail_tolerance = raw_tail_tolerance
  )
  market_columns <- c(
    "p_home", "p_draw", "p_away", "expected_home_goals", "expected_away_goals",
    "p_over_2_5", "p_under_2_5", "p_btts", "modal_home_goals",
    "modal_away_goals", "modal_score_probability"
  )
  for (i in seq_len(nrow(predictions))) {
    grid <- distributions[distributions$score_distribution_id == predictions$score_distribution_id[i], , drop = FALSE]
    derived <- derive_benchmark_markets(grid, tolerance)
    supplied <- as.numeric(predictions[i, market_columns, drop = TRUE])
    expected <- as.numeric(unlist(derived[market_columns], use.names = FALSE))
    if (any(!is.finite(supplied)) || any(abs(supplied - expected) > tolerance)) {
      stop("Benchmark prediction markets do not reconcile with the joint distribution", call. = FALSE)
    }
  }
  invisible(predictions)
}

#' Validate model fit and provenance manifests
#' @export
validate_model_manifests <- function(manifests) {
  required <- c(
    "model_manifest_id", "run_id", "model_id", "edition_id", "track_id", "boundary_id",
    "fit_status", "fit_row_count", "fit_min_date", "fit_max_date", "max_result_date",
    "max_feature_source_date", "evidence_cutoff_exclusive", "active_predictors",
    "dropped_predictors_with_reason", "model_family", "convergence_status", "fallback_status",
    "adapter_version", "code_version", "r_version", "package_versions",
    "registration_sha256", "settings_sha256", "parent_hashes"
  )
  benchmark_contract_require_columns(manifests, required, "Model manifests")
  benchmark_contract_require_unique(manifests, "model_manifest_id", "Model manifests")
  if (any(!is.finite(manifests$fit_row_count) | manifests$fit_row_count < 0)) {
    stop("Model manifest fit row counts must be non-negative", call. = FALSE)
  }
  cutoff <- as.Date(manifests$evidence_cutoff_exclusive)
  date_columns <- c("fit_max_date", "max_result_date", "max_feature_source_date")
  invalid_date <- vapply(date_columns, function(column) {
    values <- as.Date(manifests[[column]])
    is.na(values) | is.na(cutoff) | values >= cutoff
  }, logical(nrow(manifests)))
  if (any(invalid_date)) stop("Manifest result, fit, and feature dates must be strictly before the evidence cutoff", call. = FALSE)
  hash_columns <- c("registration_sha256", "settings_sha256")
  if (any(vapply(manifests[hash_columns], function(x) any(!grepl("^[0-9a-f]{64}$", x)), logical(1)))) {
    stop("Model manifests require canonical registration and settings hashes", call. = FALSE)
  }
  by_model <- split(manifests, manifests$model_id)
  if (any(vapply(by_model, function(rows) {
    length(unique(rows$registration_sha256)) != 1L || length(unique(rows$settings_sha256)) != 1L
  }, logical(1)))) stop("Registration and settings hashes must be identical across folds", call. = FALSE)
  invisible(manifests)
}

#' Validate one feature-coverage row for every registered expected key
#' @export
validate_feature_coverage <- function(coverage, expected_keys) {
  key_columns <- c("model_id", "boundary_id", "fixture_id", "feature_id")
  required <- c(
    "schema_version", "feature_coverage_id", "run_id", "model_id", "panel_id",
    "edition_id", "track_id", "boundary_id", "fixture_id", "feature_id",
    "source_id", "source_artifact_sha256", "feature_contract_row_sha256",
    "value_present", "source_present", "source_date",
    "evidence_cutoff_exclusive", "cutoff_valid", "imputed", "imputation_reason",
    "active_in_fit", "coverage_status", "license_class"
  )
  benchmark_contract_require_columns(coverage, required, "Feature coverage")
  benchmark_contract_require_columns(expected_keys, key_columns, "Expected feature coverage")
  if (!nrow(coverage)) stop("Feature coverage must not be empty", call. = FALSE)
  benchmark_contract_require_unique(coverage, key_columns, "Feature coverage")
  actual <- do.call(paste, c(lapply(coverage[key_columns], as.character), sep = "|"))
  expected <- do.call(paste, c(lapply(expected_keys[key_columns], as.character), sep = "|"))
  if (!setequal(actual, expected)) stop("Feature coverage is missing or contains unknown registered keys", call. = FALSE)

  expected_index <- match(actual, expected)
  exact_columns <- intersect(
    c("source_id", "source_artifact_sha256", "feature_contract_row_sha256", "license_class"),
    names(expected_keys)
  )
  for (column in exact_columns) {
    supplied <- as.character(coverage[[column]])
    registered <- as.character(expected_keys[[column]][expected_index])
    mismatch <- is.na(supplied) != is.na(registered) | (!is.na(supplied) & supplied != registered)
    if (any(mismatch)) {
      label <- switch(
        column,
        source_artifact_sha256 = "Feature coverage provenance drift",
        feature_contract_row_sha256 = "Feature coverage contract hash drift",
        license_class = "Feature coverage license drift",
        "Feature coverage registered source drift"
      )
      stop(label, call. = FALSE)
    }
  }
  hash_columns <- c("source_artifact_sha256", "feature_contract_row_sha256")
  if (any(vapply(coverage[hash_columns], function(x) {
    any(is.na(x) | !grepl("^[0-9a-f]{64}$", tolower(as.character(x))))
  }, logical(1)))) {
    stop("Feature coverage provenance and contract hashes must be canonical SHA-256 values", call. = FALSE)
  }

  source_date <- as.Date(coverage$source_date)
  cutoff <- as.Date(coverage$evidence_cutoff_exclusive)
  value_present <- as.logical(coverage$value_present)
  source_present <- as.logical(coverage$source_present)
  imputed <- as.logical(coverage$imputed)
  active <- as.logical(coverage$active_in_fit)
  derived_fixture <- coverage$coverage_status == "derived_fixture"
  if (anyNA(value_present) || anyNA(source_present) || anyNA(imputed) || anyNA(active)) {
    stop("Feature coverage evidence and fit flags must not be missing", call. = FALSE)
  }
  invalid <- source_present & (is.na(source_date) | is.na(cutoff) | source_date >= cutoff)
  if (any(invalid) || any(is.na(cutoff))) {
    stop("Feature coverage cutoff provenance is invalid", call. = FALSE)
  }
  if (any(!source_present & !is.na(source_date))) {
    stop("Feature coverage source-absent rows cannot fabricate source dates", call. = FALSE)
  }
  computed_cutoff_valid <- (!source_present & is.na(source_date)) |
    (source_present & !is.na(source_date) & source_date < cutoff)
  if (any(is.na(coverage$cutoff_valid) | as.logical(coverage$cutoff_valid) != computed_cutoff_valid)) {
    stop("Feature coverage cutoff validity flag is inconsistent", call. = FALSE)
  }
  if (any(value_present & !source_present & !derived_fixture)) {
    stop("Feature coverage source-absent values cannot masquerade as observations", call. = FALSE)
  }
  if (any(!value_present & !imputed)) {
    stop("Missing feature values must remain explicitly imputed", call. = FALSE)
  }
  if (any(imputed & (is.na(coverage$imputation_reason) | !nzchar(coverage$imputation_reason)))) {
    stop("Imputed features require an explicit missingness reason", call. = FALSE)
  }
  if (any(!imputed & !derived_fixture & !value_present) ||
      any(!imputed & nzchar(as.character(coverage$imputation_reason)))) {
    stop("Feature coverage imputation flags and reasons are inconsistent", call. = FALSE)
  }
  invisible(coverage)
}

#' Validate prediction foreign keys into exact registered feature groups
#' @export
validate_prediction_feature_coverage_links <- function(predictions, coverage, feature_contract) {
  prediction_columns <- c(
    "feature_coverage_id", "model_id", "panel_id", "edition_id", "track_id",
    "boundary_id", "fixture_id"
  )
  coverage_columns <- c(prediction_columns, "feature_id")
  benchmark_contract_require_columns(predictions, prediction_columns, "Benchmark predictions")
  benchmark_contract_require_columns(coverage, coverage_columns, "Feature coverage")
  benchmark_contract_require_columns(feature_contract, c("panel_id", "feature_id"), "Feature contract")
  benchmark_contract_require_unique(predictions, c("model_id", "track_id", "fixture_id"), "Benchmark predictions")

  prediction_ids <- as.character(predictions$feature_coverage_id)
  coverage_ids <- as.character(coverage$feature_coverage_id)
  if (any(is.na(prediction_ids) | !nzchar(prediction_ids)) || any(!prediction_ids %in% coverage_ids)) {
    stop("Benchmark predictions contain dangling feature coverage references", call. = FALSE)
  }
  if (!setequal(unique(prediction_ids), unique(coverage_ids))) {
    stop("Feature coverage contains unreferenced or dangling prediction groups", call. = FALSE)
  }

  identity_columns <- setdiff(prediction_columns, "feature_coverage_id")
  for (i in seq_len(nrow(predictions))) {
    rows <- coverage[coverage_ids == prediction_ids[i], , drop = FALSE]
    if (!nrow(rows)) stop("Benchmark prediction feature coverage group is dangling", call. = FALSE)
    for (column in identity_columns) {
      if (any(as.character(rows[[column]]) != as.character(predictions[[column]][i]))) {
        stop("Feature coverage group identity does not match its prediction", call. = FALSE)
      }
    }
    expected_features <- unique(as.character(
      feature_contract$feature_id[feature_contract$panel_id == predictions$panel_id[i]]
    ))
    actual_features <- as.character(rows$feature_id)
    if (!length(expected_features) || anyDuplicated(actual_features) || !setequal(actual_features, expected_features)) {
      stop("Prediction feature coverage group does not contain its exact registered panel features", call. = FALSE)
    }
  }
  invisible(TRUE)
}

#' Validate exact declared fixture coverage for a model panel
#' @export
validate_panel_prediction_coverage <- function(predictions, panel_fixtures, model_id) {
  benchmark_contract_require_columns(
    panel_fixtures, c("panel_id", "fixture_id", "eligible", "output_coverage_required"),
    "Panel fixtures"
  )
  benchmark_contract_require_columns(predictions, c("model_id", "panel_id", "fixture_id", "prediction_status"), "Benchmark predictions")
  rows <- predictions[predictions$model_id == model_id, , drop = FALSE]
  panel_ids <- unique(rows$panel_id)
  if (!length(panel_ids)) panel_ids <- unique(panel_fixtures$panel_id)
  if (length(panel_ids) != 1L) stop("Model predictions must identify exactly one registered panel", call. = FALSE)
  required <- panel_fixtures$fixture_id[
    panel_fixtures$panel_id == panel_ids & panel_fixtures$eligible & panel_fixtures$output_coverage_required
  ]
  missing <- setdiff(required, rows$fixture_id)
  if (length(missing)) stop("Model predictions are missing required fixture rows", call. = FALSE)
  required_rows <- rows[match(required, rows$fixture_id), , drop = FALSE]
  if (any(required_rows$prediction_status != "ok")) stop("Required panel fixture outputs are incomplete", call. = FALSE)
  invisible(TRUE)
}

#' Canonical parent hash for score-support audit rows
#' @export
benchmark_support_parent_sha256 <- function(data) {
  required <- c(
    "model_id", "edition_id", "track_id", "boundary_id",
    "registration_sha256", "settings_sha256", "boundary_sha256"
  )
  benchmark_contract_require_columns(data, required, "Score support parent data")
  vapply(seq_len(nrow(data)), function(i) {
    benchmark_contract_sha256(vapply(data[i, required, drop = FALSE], benchmark_contract_scalar, character(1)))
  }, character(1))
}

#' Validate the normalized global score-support audit
#' @export
validate_score_support_audit <- function(audit, model_registry, boundary_inventory) {
  required <- c(
    "model_id", "edition_id", "track_id", "boundary_id", "candidate_g",
    "raw_omitted_tail", "tolerance", "pass", "selected_g", "parent_hashes", "row_hash"
  )
  benchmark_contract_require_columns(audit, required, "Score support audit")
  benchmark_contract_require_columns(
    model_registry,
    c("model_id", "candidate_min", "candidate_max", "raw_tail_tolerance", "registration_sha256", "settings_sha256"),
    "Model registry"
  )
  benchmark_contract_require_columns(
    boundary_inventory, c("edition_id", "track_id", "boundary_id", "boundary_sha256"),
    "Boundary inventory"
  )
  key_columns <- c("model_id", "edition_id", "track_id", "boundary_id", "candidate_g")
  benchmark_contract_require_unique(audit, key_columns, "Score support audit")
  registered_boundaries <- do.call(paste, c(lapply(boundary_inventory[c("edition_id", "track_id", "boundary_id")], as.character), sep = "|"))
  audit_boundaries <- do.call(paste, c(lapply(audit[c("edition_id", "track_id", "boundary_id")], as.character), sep = "|"))
  if (any(!audit$model_id %in% model_registry$model_id) || any(!audit_boundaries %in% registered_boundaries)) {
    stop("Score support audit contains an unregistered audit key", call. = FALSE)
  }
  expected <- do.call(rbind, lapply(seq_len(nrow(model_registry)), function(i) {
    base <- merge(
      data.frame(model_id = model_registry$model_id[i], stringsAsFactors = FALSE),
      boundary_inventory[, c("edition_id", "track_id", "boundary_id"), drop = FALSE], by = NULL
    )
    merge(base, data.frame(candidate_g = seq.int(model_registry$candidate_min[i], model_registry$candidate_max[i])), by = NULL)
  }))
  expected_keys <- do.call(paste, c(lapply(expected[key_columns], as.character), sep = "|"))
  actual_keys <- do.call(paste, c(lapply(audit[key_columns], as.character), sep = "|"))
  if (!setequal(actual_keys, expected_keys)) stop("Score support audit has missing candidate rows", call. = FALSE)
  benchmark_contract_validate_hash(audit, "row_hash", "Score support audit")
  enriched <- merge(
    audit,
    model_registry[, c("model_id", "raw_tail_tolerance", "registration_sha256", "settings_sha256")],
    by = "model_id", all.x = TRUE, sort = FALSE
  )
  enriched <- merge(
    enriched, boundary_inventory, by = c("edition_id", "track_id", "boundary_id"),
    all.x = TRUE, sort = FALSE
  )
  expected_parent <- benchmark_support_parent_sha256(enriched)
  if (any(tolower(enriched$parent_hashes) != expected_parent)) stop("Score support audit parent hash mismatch", call. = FALSE)
  if (any(!is.finite(enriched$raw_omitted_tail) | enriched$raw_omitted_tail < 0)) {
    stop("Score support audit tails must be finite and non-negative", call. = FALSE)
  }
  if (any(enriched$tolerance != enriched$raw_tail_tolerance)) stop("Score support audit tolerance drifted from registration", call. = FALSE)
  if (any(enriched$pass != (enriched$raw_omitted_tail <= enriched$tolerance))) stop("Score support audit pass flags are inconsistent", call. = FALSE)
  selected <- unique(as.integer(enriched$selected_g))
  if (length(selected) != 1L || is.na(selected)) stop("Score support audit requires a single global selected G", call. = FALSE)
  by_candidate <- split(enriched, enriched$candidate_g)
  passing <- as.integer(names(by_candidate)[vapply(by_candidate, function(rows) all(rows$pass), logical(1))])
  if (!length(passing)) stop("No globally valid score support candidate exists", call. = FALSE)
  if (selected != min(passing)) stop("Selected score support is not the smallest globally passing G", call. = FALSE)
  invisible(audit)
}

#' Validate tournament-stage reach probabilities
#' @export
validate_stage_probabilities <- function(stage_probabilities, tolerance = 1e-10) {
  required <- c(
    "run_id", "model_id", "edition_id", "anchor_boundary_id", "team_id",
    "stage_id", "stage_order", "probability", "n_simulations", "seed_id", "format_id"
  )
  benchmark_contract_require_columns(stage_probabilities, required, "Stage probabilities")
  keys <- c("run_id", "model_id", "edition_id", "anchor_boundary_id", "team_id", "stage_id")
  benchmark_contract_require_unique(stage_probabilities, keys, "Stage probabilities")
  if (any(!is.finite(stage_probabilities$probability) |
          stage_probabilities$probability < 0 | stage_probabilities$probability > 1)) {
    stop("Stage probabilities must lie in [0, 1]", call. = FALSE)
  }
  if (any(stage_probabilities$n_simulations != 50000L)) stop("Stage probabilities require 50,000 simulations", call. = FALSE)
  team_key <- interaction(
    stage_probabilities[c("run_id", "model_id", "edition_id", "anchor_boundary_id", "team_id")],
    drop = TRUE, lex.order = TRUE
  )
  if (any(vapply(split(stage_probabilities, team_key), function(rows) {
    rows <- rows[order(rows$stage_order), , drop = FALSE]
    any(diff(rows$probability) > tolerance)
  }, logical(1)))) stop("Stage reach probabilities must be monotone", call. = FALSE)
  champion <- stage_probabilities[stage_probabilities$stage_id == "champion", , drop = FALSE]
  mass_key <- interaction(champion[c("run_id", "model_id", "edition_id", "anchor_boundary_id")], drop = TRUE)
  if (!nrow(champion) || any(abs(vapply(split(champion$probability, mass_key), sum, numeric(1)) - 1) > tolerance)) {
    stop("Tournament champion mass must sum to one", call. = FALSE)
  }
  invisible(stage_probabilities)
}

#' Validate the benchmark run-level reconciliation manifest
#' @export
validate_benchmark_run_manifest <- function(run_manifest) {
  required <- c(
    "run_id", "protocol_version", "git_sha", "dirty_worktree", "sealed_data_policy",
    "registry_sha256", "model_registry_sha256", "score_support_audit_sha256",
    "seed_registry_sha256", "prediction_contract_valid", "distribution_contract_valid",
    "manifest_contract_valid", "feature_coverage_valid", "panel_coverage_valid",
    "seed_contract_valid", "reproducible"
  )
  benchmark_contract_require_columns(run_manifest, required, "Benchmark run manifest")
  benchmark_contract_require_unique(run_manifest, "run_id", "Benchmark run manifest")
  hash_columns <- c("registry_sha256", "model_registry_sha256", "score_support_audit_sha256", "seed_registry_sha256")
  if (any(vapply(run_manifest[hash_columns], function(x) any(!grepl("^[0-9a-f]{64}$", x)), logical(1)))) {
    stop("Benchmark run manifest contains invalid SHA-256 values", call. = FALSE)
  }
  flags <- c(
    "prediction_contract_valid", "distribution_contract_valid", "manifest_contract_valid",
    "feature_coverage_valid", "panel_coverage_valid", "seed_contract_valid", "reproducible"
  )
  if (any(vapply(run_manifest[flags], function(x) any(is.na(x) | !x), logical(1)))) {
    stop("Benchmark run manifest contract flags must all pass", call. = FALSE)
  }
  invisible(run_manifest)
}
