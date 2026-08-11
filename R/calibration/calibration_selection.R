#' Phase 12 development gate for raw versus calibrated derived 1X2 views.
#'
#' This module deliberately scores only the derived 1X2 view. The fitted
#' scoreline distribution and every auxiliary market remain shared inputs.

phase12_selection_project_root <- function() {
  candidates <- c(getwd(), file.path(getwd(), "../.."), file.path(getwd(), "../../.."))
  for (candidate in candidates) {
    if (file.exists(file.path(candidate, "data/benchmark/phase12/freeze_manifest.csv"))) {
      return(normalizePath(candidate, mustWork = TRUE))
    }
  }
  stop("Phase 12 calibration selection could not locate the project root", call. = FALSE)
}

phase12_selection_resolve_path <- function(path) {
  if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path)) {
    stop("Phase 12 calibration selection path must be one non-empty value", call. = FALSE)
  }
  if (grepl("^/", path)) path else file.path(phase12_selection_project_root(), path)
}

phase12_selection_source_if_missing <- function(relative_path, symbols) {
  missing <- symbols[!vapply(symbols, exists, logical(1), mode = "function")]
  if (!length(missing)) return(invisible(TRUE))
  path <- phase12_selection_resolve_path(relative_path)
  if (!file.exists(path)) stop("Phase 12 calibration selection dependency is missing: ", relative_path, call. = FALSE)
  source(path, local = .GlobalEnv)
  missing <- symbols[!vapply(symbols, exists, logical(1), mode = "function")]
  if (length(missing)) stop("Phase 12 calibration selection dependency did not define: ", paste(missing, collapse = ", "), call. = FALSE)
  invisible(TRUE)
}

phase12_selection_source_if_missing("R/evaluation/proper_scores.R", c("validate_probability_vector", "score_scoreline_distribution"))
phase12_selection_source_if_missing("R/benchmark/contracts.R", c("validate_score_support_audit"))
phase12_selection_source_if_missing("R/benchmark/registry.R", c("canonical_benchmark_sha256"))
phase12_selection_source_if_missing(
  "R/evaluation/benchmark_scores.R",
  c("score_benchmark_fixtures", "aggregate_benchmark_scores", "fixed_benchmark_calibration", "make_paired_fold_comparisons")
)
phase12_selection_source_if_missing("R/evaluation/promotion.R", c("load_promotion_protocol", "validate_promotion_protocol"))
phase12_selection_source_if_missing("R/release/freeze_manifest.R", c("phase12_freeze_self_hash"))

phase12_selection_expected_identity <- function() {
  c(
    "run_id", "model_id", "panel_id", "edition_id", "track_id", "fixture_id",
    "score_distribution_id", "p_over_2_5", "p_under_2_5", "p_btts", "prediction_status"
  )
}

phase12_selection_probability_columns <- function() c("p_home", "p_draw", "p_away")

phase12_selection_protocol <- function(protocol = NULL) {
  if (is.null(protocol)) {
    return(load_promotion_protocol(phase12_selection_resolve_path("data/benchmark/phase09/promotion_protocol.json")))
  }
  if (is.character(protocol) && length(protocol) == 1L) return(load_promotion_protocol(phase12_selection_resolve_path(protocol)))
  if (!is.list(protocol)) stop("Phase 12 calibration selection protocol must be a path or validated list", call. = FALSE)
  validate_promotion_protocol(protocol, registry_dir = phase12_selection_resolve_path("data/benchmark/phase09"))
  protocol
}

# Validate the durable freeze bytes without requiring the working tree to be
# clean. The freeze validator's clean-code check belongs to the pre-label gate;
# this development comparison must remain runnable while its own artifacts are
# being staged.
phase12_selection_freeze <- function(freeze_manifest = "data/benchmark/phase12/freeze_manifest.csv") {
  if (is.data.frame(freeze_manifest)) {
    if (!isTRUE(attr(freeze_manifest, "phase12_validated"))) {
      stop("Phase 12 calibration selection requires a validated freeze data frame", call. = FALSE)
    }
    return(freeze_manifest)
  }
  path <- phase12_selection_resolve_path(freeze_manifest)
  if (!file.exists(path)) stop("Phase 12 freeze manifest is missing", call. = FALSE)
  freeze <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  required <- c("freeze_id", "candidate_id", "candidate_count", "selected_g", "freeze_self_sha256", "freeze_status", "sealed_before_final_labels", "wc2026_sealed", "phase12_decision_authority")
  missing <- setdiff(required, names(freeze))
  if (length(missing)) stop("Phase 12 freeze manifest is incomplete: ", paste(missing, collapse = ", "), call. = FALSE)
  if (nrow(freeze) != 9L || anyDuplicated(freeze$candidate_id) || any(!nzchar(freeze$candidate_id))) stop("Phase 12 freeze candidate identity is invalid", call. = FALSE)
  if (any(as.integer(freeze$candidate_count) != 9L) || any(as.integer(freeze$selected_g) != 40L)) stop("Phase 12 freeze support is invalid", call. = FALSE)
  if (any(as.character(freeze$freeze_status) != "sealed_before_final_labels") || any(!as.logical(freeze$sealed_before_final_labels)) || any(!as.logical(freeze$wc2026_sealed)) || any(as.logical(freeze$phase12_decision_authority))) stop("Phase 12 freeze is not a sealed development freeze", call. = FALSE)
  self_hash <- phase12_freeze_self_hash(freeze)
  if (length(unique(tolower(as.character(freeze$freeze_self_sha256)))) != 1L || !identical(tolower(as.character(freeze$freeze_self_sha256[[1L]])), tolower(self_hash))) stop("Phase 12 freeze self-hash mismatch", call. = FALSE)
  attr(freeze, "phase12_validated") <- TRUE
  freeze
}

phase12_selection_require_prediction_contract <- function(predictions, name) {
  if (!is.data.frame(predictions)) stop(name, " must be a data frame", call. = FALSE)
  required <- c(phase12_selection_expected_identity(), phase12_selection_probability_columns())
  missing <- setdiff(required, names(predictions))
  if (length(missing)) stop(name, " missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  if (anyDuplicated(predictions$fixture_id) || any(!nzchar(as.character(predictions$fixture_id)))) stop(name, " must have unique non-empty fixture IDs", call. = FALSE)
  if (anyNA(predictions[, c("p_home", "p_draw", "p_away")])) stop(name, " contains missing 1X2 probabilities", call. = FALSE)
  invisible(TRUE)
}

phase12_selection_prediction_view <- function(predictions, name) {
  if (!is.data.frame(predictions)) stop(name, " must be a data frame", call. = FALSE)
  result <- predictions
  calibrated <- c("p_home_calibrated", "p_draw_calibrated", "p_away_calibrated")
  if (all(calibrated %in% names(result))) {
    result[, phase12_selection_probability_columns()] <- result[, calibrated]
  }
  phase12_selection_require_prediction_contract(result, name)
  result
}

phase12_selection_identity <- function(raw, calibrated, expected_fixture_ids) {
  expected_fixture_ids <- as.character(expected_fixture_ids)
  if (!length(expected_fixture_ids) || anyDuplicated(expected_fixture_ids)) stop("Phase 12 calibration selection requires unique expected fixture IDs", call. = FALSE)
  if (!identical(sort(as.character(raw$fixture_id), method = "radix"), sort(expected_fixture_ids, method = "radix")) ||
      !identical(sort(as.character(calibrated$fixture_id), method = "radix"), sort(expected_fixture_ids, method = "radix"))) {
    stop("Phase 12 raw and calibrated views require the exact expected fixture IDs", call. = FALSE)
  }
  identity <- phase12_selection_expected_identity()
  allowed <- c(identity, phase12_selection_probability_columns(), "p_home_calibrated", "p_draw_calibrated", "p_away_calibrated", "primary_probability_view")
  if (!identical(sort(setdiff(names(raw), allowed), method = "radix"), sort(setdiff(names(calibrated), allowed), method = "radix"))) {
    stop("Phase 12 raw and calibrated views differ outside derived 1X2 probabilities: column identity", call. = FALSE)
  }
  raw_order <- order(raw$fixture_id, method = "radix")
  calibrated_order <- order(calibrated$fixture_id, method = "radix")
  for (column in identity) {
    if (!identical(as.character(raw[[column]][raw_order]), as.character(calibrated[[column]][calibrated_order]))) {
      stop("Phase 12 raw and calibrated views differ outside derived 1X2 probabilities: ", column, call. = FALSE)
    }
  }
  shared_extra <- setdiff(intersect(names(raw), names(calibrated)), phase12_selection_probability_columns())
  for (column in setdiff(shared_extra, c("p_home_calibrated", "p_draw_calibrated", "p_away_calibrated", "primary_probability_view"))) {
    if (!identical(as.character(raw[[column]][raw_order]), as.character(calibrated[[column]][calibrated_order]))) {
      stop("Phase 12 raw and calibrated views differ outside derived 1X2 probabilities: ", column, call. = FALSE)
    }
  }
  list(
    fixture_identity_match = TRUE, edition_identity_match = TRUE, track_identity_match = TRUE,
    score_distribution_identity_match = TRUE, auxiliary_market_identity_match = TRUE,
    prediction_status_identity_match = TRUE, expected_fixture_ids = expected_fixture_ids
  )
}

phase12_selection_tournaments <- function(expected_editions) {
  data.frame(
    edition_id = as.character(expected_editions),
    competition_id = ifelse(grepl("^wc", as.character(expected_editions)), "world_cup", "euro"),
    stringsAsFactors = FALSE
  )
}

phase12_selection_metric_headline <- function(summaries, metric) {
  rows <- summaries[summaries$target == "regulation_1x2" & summaries$metric == metric & summaries$grain == "headline" & summaries$aggregation == "equal_tournament", , drop = FALSE]
  if (nrow(rows) != 1L || !is.finite(rows$estimate[[1L]])) stop("Phase 12 calibration selection requires one finite headline metric: ", metric, call. = FALSE)
  as.numeric(rows$estimate[[1L]])
}

phase12_selection_tournament_metric <- function(summaries, metric) {
  rows <- summaries[summaries$target == "regulation_1x2" & summaries$metric == metric & summaries$grain == "tournament", , drop = FALSE]
  rows <- rows[order(rows$edition_id, method = "radix"), c("edition_id", "estimate"), drop = FALSE]
  if (!nrow(rows) || any(!is.finite(rows$estimate))) stop("Phase 12 calibration selection requires finite tournament metrics: ", metric, call. = FALSE)
  paste(paste(rows$edition_id, formatC(rows$estimate, digits = 17, format = "fg"), sep = "="), collapse = "|")
}

phase12_selection_calibration_values <- function(calibration) {
  row <- calibration$summary[1L, , drop = FALSE]
  required <- c("calibration_error", "home_calibration_error", "draw_calibration_error", "away_calibration_error", "n_fixtures", "n_tournaments")
  missing <- setdiff(required, names(row))
  if (length(missing) || any(!is.finite(as.numeric(row[required[1:4]])))) stop("Phase 12 calibration selection requires complete fixed-bin calibration evidence", call. = FALSE)
  as.list(row)
}

phase12_selection_relative_change <- function(raw, calibrated) {
  if (!is.finite(raw) || !is.finite(calibrated)) return(NA_real_)
  if (raw == 0) return(if (calibrated == 0) 0 else sign(calibrated))
  (calibrated - raw) / abs(raw)
}

phase12_selection_calibrator_valid <- function(calibrator) {
  if (is.null(calibrator)) return(TRUE)
  if (!is.list(calibrator)) stop("Phase 12 calibration selection calibrator must be a list", call. = FALSE)
  required <- c("fit_status", "distribution_unchanged", "probability_view", "score_support")
  missing <- setdiff(required, names(calibrator))
  if (length(missing)) stop("Phase 12 calibrator artifact is incomplete: ", paste(missing, collapse = ", "), call. = FALSE)
  if (!as.character(calibrator$fit_status) %in% c("fitted", "raw_fallback") || !isTRUE(calibrator$distribution_unchanged) || !identical(as.character(calibrator$probability_view), "derived_1x2") || !identical(as.integer(calibrator$score_support), 40L)) stop("Phase 12 calibrator artifact is not a completed derived-1X2 artifact", call. = FALSE)
  invisible(TRUE)
}

#' Compare raw and calibrated 1X2 probabilities through the shared scorer.
#' @export
compare_phase12_raw_calibrated <- function(
    raw_predictions, calibrated_predictions, fixtures, distributions,
    expected_fixture_ids, expected_editions, protocol = NULL, freeze_manifest = "data/benchmark/phase12/freeze_manifest.csv",
    calibrator = NULL, calibration_support_valid = TRUE
) {
  phase12_selection_freeze(freeze_manifest)
  phase12_selection_protocol(protocol)
  phase12_selection_calibrator_valid(calibrator)
  raw <- phase12_selection_prediction_view(raw_predictions, "Raw predictions")
  calibrated <- phase12_selection_prediction_view(calibrated_predictions, "Calibrated predictions")
  identity <- phase12_selection_identity(raw, calibrated, expected_fixture_ids)
  if (!is.data.frame(fixtures) || !all(c("edition_id", "fixture_id", "regulation_home_goals", "regulation_away_goals", "score_eligible") %in% names(fixtures))) stop("Phase 12 calibration selection fixtures are incomplete", call. = FALSE)
  expected_editions <- as.character(expected_editions)
  if (length(expected_editions) != 12L || anyDuplicated(expected_editions)) stop("Phase 12 calibration selection requires the 12 registered editions", call. = FALSE)
  fixture_rows <- fixtures[match(identity$expected_fixture_ids, as.character(fixtures$fixture_id)), , drop = FALSE]
  if (anyNA(fixture_rows$fixture_id) || any(as.character(fixture_rows$edition_id) != as.character(raw$edition_id[match(identity$expected_fixture_ids, raw$fixture_id)])) || !identical(sort(unique(as.character(fixture_rows$edition_id)), method = "radix"), sort(expected_editions, method = "radix"))) stop("Phase 12 calibration selection fixture edition identity is incomplete", call. = FALSE)
  raw_scores <- score_benchmark_fixtures(raw, fixtures, distributions, identity$expected_fixture_ids)
  calibrated_scores <- score_benchmark_fixtures(calibrated, fixtures, distributions, identity$expected_fixture_ids)
  raw_summaries <- aggregate_benchmark_scores(raw_scores, expected_editions)
  calibrated_summaries <- aggregate_benchmark_scores(calibrated_scores, expected_editions)
  raw_calibration <- fixed_benchmark_calibration(raw, fixtures, identity$expected_fixture_ids)
  calibrated_calibration <- fixed_benchmark_calibration(calibrated, fixtures, identity$expected_fixture_ids)
  tournaments <- phase12_selection_tournaments(expected_editions)
  raw_pair <- raw_scores; raw_pair$model_id <- "raw_1x2"
  calibrated_pair <- calibrated_scores; calibrated_pair$model_id <- "calibrated_1x2"
  paired <- make_paired_fold_comparisons(
    rbind(raw_pair, calibrated_pair), "calibrated_1x2", "raw_1x2", tournaments,
    identity$expected_fixture_ids, metric = "rps", target = "regulation_1x2"
  )
  scoreline_metrics <- c("joint_scoreline_log_loss", "home_goal_rps", "away_goal_rps", "exact_score_hit")
  scoreline_raw <- raw_scores[raw_scores$metric %in% scoreline_metrics, c("fixture_id", "metric", "value"), drop = FALSE]
  scoreline_calibrated <- calibrated_scores[calibrated_scores$metric %in% scoreline_metrics, c("fixture_id", "metric", "value"), drop = FALSE]
  scoreline_raw <- scoreline_raw[order(scoreline_raw$fixture_id, scoreline_raw$metric, method = "radix"), ]
  scoreline_calibrated <- scoreline_calibrated[order(scoreline_calibrated$fixture_id, scoreline_calibrated$metric, method = "radix"), ]
  distribution_unchanged <- identical(scoreline_raw[, c("fixture_id", "metric", "value")], scoreline_calibrated[, c("fixture_id", "metric", "value")])
  if (!distribution_unchanged) stop("Phase 12 calibrated view changed the fitted scoreline distribution or auxiliary scoreline metrics", call. = FALSE)
  raw_headline <- stats::setNames(vapply(c("rps", "brier", "log_loss"), function(metric) phase12_selection_metric_headline(raw_summaries, metric), numeric(1)), c("rps", "brier", "log_loss"))
  calibrated_headline <- stats::setNames(vapply(c("rps", "brier", "log_loss"), function(metric) phase12_selection_metric_headline(calibrated_summaries, metric), numeric(1)), c("rps", "brier", "log_loss"))
  raw_calibration_values <- phase12_selection_calibration_values(raw_calibration)
  calibrated_calibration_values <- phase12_selection_calibration_values(calibrated_calibration)
  coverage_numerator <- length(unique(identity$expected_fixture_ids))
  coverage_denominator <- length(identity$expected_fixture_ids)
  list(
    candidate_id = as.character(raw$model_id[[1L]]), track_id = as.character(raw$track_id[[1L]]),
    run_id = as.character(raw$run_id[[1L]]), panel_id = as.character(raw$panel_id[[1L]]),
    raw_predictions = raw, calibrated_predictions = calibrated,
    raw_scores = raw_scores, calibrated_scores = calibrated,
    raw_summaries = raw_summaries, calibrated_summaries = calibrated_summaries,
    raw_calibration = raw_calibration, calibrated_calibration = calibrated_calibration,
    raw_headline = raw_headline, calibrated_headline = calibrated_headline,
    raw_tournament_metrics = stats::setNames(lapply(c("rps", "brier", "log_loss"), function(metric) phase12_selection_tournament_metric(raw_summaries, metric)), c("rps", "brier", "log_loss")),
    calibrated_tournament_metrics = stats::setNames(lapply(c("rps", "brier", "log_loss"), function(metric) phase12_selection_tournament_metric(calibrated_summaries, metric)), c("rps", "brier", "log_loss")),
    raw_calibration_values = raw_calibration_values, calibrated_calibration_values = calibrated_calibration_values,
    paired_rps = paired, expected_fixture_ids = identity$expected_fixture_ids,
    expected_editions = expected_editions, coverage_numerator = coverage_numerator,
    coverage_denominator = coverage_denominator, coverage_valid = coverage_numerator == coverage_denominator,
    calibration_support_valid = isTRUE(calibration_support_valid) && (is.null(calibrator) || !identical(as.character(calibrator$fit_status), "raw_fallback")), distribution_unchanged = distribution_unchanged,
    identity = identity
  )
}

phase12_selection_reason_order <- function() c(
  "calibration_support_insufficient", "fixture_coverage_veto", "score_identity_veto",
  "rps_veto", "brier_veto", "log_loss_veto", "fold_stability_veto", "calibration_not_improved"
)

phase12_selection_decision <- function(comparison, protocol = NULL, calibration_support_valid = NULL) {
  protocol <- phase12_selection_protocol(protocol)
  support_valid <- if (is.null(calibration_support_valid)) isTRUE(comparison$calibration_support_valid) else isTRUE(calibration_support_valid)
  rps_delta <- comparison$calibrated_headline[["rps"]] - comparison$raw_headline[["rps"]]
  brier_delta <- comparison$calibrated_headline[["brier"]] - comparison$raw_headline[["brier"]]
  log_loss_delta <- comparison$calibrated_headline[["log_loss"]] - comparison$raw_headline[["log_loss"]]
  calibration_delta <- as.numeric(comparison$calibrated_calibration_values$calibration_error) - as.numeric(comparison$raw_calibration_values$calibration_error)
  brier_relative <- phase12_selection_relative_change(comparison$raw_headline[["brier"]], comparison$calibrated_headline[["brier"]])
  log_loss_relative <- phase12_selection_relative_change(comparison$raw_headline[["log_loss"]], comparison$calibrated_headline[["log_loss"]])
  max_fold_regression <- as.numeric(comparison$paired_rps$breadth$maximum_fold_regression[[1L]])
  reasons <- character()
  if (!support_valid) reasons <- c(reasons, "calibration_support_insufficient")
  if (!isTRUE(comparison$coverage_valid) || comparison$coverage_numerator != comparison$coverage_denominator) reasons <- c(reasons, "fixture_coverage_veto")
  if (!isTRUE(comparison$distribution_unchanged) || !isTRUE(comparison$identity$score_distribution_identity_match)) reasons <- c(reasons, "score_identity_veto")
  rps_relative <- phase12_selection_relative_change(comparison$raw_headline[["rps"]], comparison$calibrated_headline[["rps"]])
  if (!is.finite(rps_relative) || !isTRUE(rps_relative <= 0)) reasons <- c(reasons, "rps_veto")
  if (!is.finite(brier_relative) || !isTRUE(brier_relative <= as.numeric(protocol$supporting_vetoes$brier_relative_change$value))) reasons <- c(reasons, "brier_veto")
  if (!is.finite(log_loss_relative) || !isTRUE(log_loss_relative <= as.numeric(protocol$supporting_vetoes$log_loss_relative_change$value))) reasons <- c(reasons, "log_loss_veto")
  if (!is.finite(max_fold_regression) || !isTRUE(max_fold_regression <= as.numeric(protocol$core_gate$maximum_fold_regression$value))) reasons <- c(reasons, "fold_stability_veto")
  if (!is.finite(calibration_delta) || !isTRUE(calibration_delta < 0)) reasons <- c(reasons, "calibration_not_improved")
  reasons <- phase12_selection_reason_order()[phase12_selection_reason_order() %in% reasons]
  list(
    candidate_id = comparison$candidate_id, track_id = comparison$track_id,
    raw_headline = comparison$raw_headline, calibrated_headline = comparison$calibrated_headline,
    rps_delta = rps_delta, brier_delta = brier_delta, log_loss_delta = log_loss_delta,
    brier_relative_change = brier_relative, log_loss_relative_change = log_loss_relative,
    calibration_delta = calibration_delta, max_fold_regression = max_fold_regression,
    fold_rps_delta = as.numeric(comparison$paired_rps$bootstrap$estimate[[1L]]),
    fold_rps_ci_lower = as.numeric(comparison$paired_rps$bootstrap$lower[[1L]]),
    fold_rps_ci_upper = as.numeric(comparison$paired_rps$bootstrap$upper[[1L]]),
    calibration_support_valid = support_valid, coverage_valid = isTRUE(comparison$coverage_valid),
    distribution_unchanged = isTRUE(comparison$distribution_unchanged), reason_codes = reasons,
    calibration_promoted = !length(reasons), primary_probability_view = if (!length(reasons)) "calibrated_1x2" else "raw_1x2"
  )
}

phase12_selection_or_null <- function(x, y) if (is.null(x)) y else x

#' Select exactly one explicit primary probability view.
#' @export
select_phase12_primary_probability_view <- function(calibration_improves = FALSE, vetoes = character(), comparison = NULL, protocol = NULL, calibration_support_valid = NULL) {
  if (is.list(calibration_improves) && is.null(comparison)) comparison <- calibration_improves
  if (!is.null(comparison)) return(phase12_selection_decision(comparison, protocol, calibration_support_valid)$primary_probability_view)
  if (isTRUE(calibration_improves) && !length(vetoes)) "calibrated_1x2" else "raw_1x2"
}

phase12_selection_serialise_values <- function(values) {
  if (is.null(values)) return("")
  if (length(values) == 1L && is.na(values)) return("")
  paste(as.character(values), collapse = "|")
}

phase12_selection_one_gate_row <- function(comparison, candidate_id, track_id, protocol = NULL, calibration_support_valid = NULL) {
  decision <- phase12_selection_decision(comparison, protocol, calibration_support_valid)
  freeze <- phase12_selection_freeze()
  freeze_row <- freeze[freeze$candidate_id == candidate_id, , drop = FALSE]
  if (nrow(freeze_row) != 1L) stop("Phase 12 calibration gate candidate is not in the freeze", call. = FALSE)
  raw_cal <- comparison$raw_calibration_values
  calibrated_cal <- comparison$calibrated_calibration_values
  data.frame(
    schema_version = "phase12-calibration-gate-v1", candidate_id = as.character(candidate_id), track_id = as.character(track_id),
    score_status = "scored", run_id = comparison$run_id, panel_id = comparison$panel_id,
    expected_fixture_count = comparison$coverage_denominator, observed_fixture_count = comparison$coverage_numerator,
    coverage_numerator = comparison$coverage_numerator, coverage_denominator = comparison$coverage_denominator,
    raw_headline_rps = comparison$raw_headline[["rps"]], calibrated_headline_rps = comparison$calibrated_headline[["rps"]], rps_delta = decision$rps_delta,
    raw_headline_brier = comparison$raw_headline[["brier"]], calibrated_headline_brier = comparison$calibrated_headline[["brier"]], brier_relative_change = decision$brier_relative_change,
    raw_headline_log_loss = comparison$raw_headline[["log_loss"]], calibrated_headline_log_loss = comparison$calibrated_headline[["log_loss"]], log_loss_relative_change = decision$log_loss_relative_change,
    raw_tournament_rps = phase12_selection_serialise_values(comparison$raw_tournament_metrics$rps), calibrated_tournament_rps = phase12_selection_serialise_values(comparison$calibrated_tournament_metrics$rps),
    raw_tournament_brier = phase12_selection_serialise_values(comparison$raw_tournament_metrics$brier), calibrated_tournament_brier = phase12_selection_serialise_values(comparison$calibrated_tournament_metrics$brier),
    raw_tournament_log_loss = phase12_selection_serialise_values(comparison$raw_tournament_metrics$log_loss), calibrated_tournament_log_loss = phase12_selection_serialise_values(comparison$calibrated_tournament_metrics$log_loss),
    raw_calibration_error = as.numeric(raw_cal$calibration_error), calibrated_calibration_error = as.numeric(calibrated_cal$calibration_error), calibration_error_delta = decision$calibration_delta,
    raw_home_calibration_error = as.numeric(raw_cal$home_calibration_error), calibrated_home_calibration_error = as.numeric(calibrated_cal$home_calibration_error),
    raw_draw_calibration_error = as.numeric(raw_cal$draw_calibration_error), calibrated_draw_calibration_error = as.numeric(calibrated_cal$draw_calibration_error),
    raw_away_calibration_error = as.numeric(raw_cal$away_calibration_error), calibrated_away_calibration_error = as.numeric(calibrated_cal$away_calibration_error),
    fold_rps_delta = decision$fold_rps_delta, fold_rps_ci_lower = decision$fold_rps_ci_lower, fold_rps_ci_upper = decision$fold_rps_ci_upper,
    fold_stability_max_regression = decision$max_fold_regression, calibration_support_valid = decision$calibration_support_valid,
    fixture_identity_match = isTRUE(comparison$identity$fixture_identity_match), edition_identity_match = isTRUE(comparison$identity$edition_identity_match),
    track_identity_match = isTRUE(comparison$identity$track_identity_match), score_distribution_identity_match = isTRUE(comparison$identity$score_distribution_identity_match),
    auxiliary_market_identity_match = isTRUE(comparison$identity$auxiliary_market_identity_match), prediction_status_identity_match = isTRUE(comparison$identity$prediction_status_identity_match),
    score_distribution_unchanged = decision$distribution_unchanged, primary_probability_view = decision$primary_probability_view,
    calibration_promoted = decision$calibration_promoted, reason_codes = phase12_selection_serialise_values(decision$reason_codes), reason_count = length(decision$reason_codes),
    expected_editions = phase12_selection_serialise_values(comparison$expected_editions), expected_fixture_ids_sha256 = digest::digest(paste(sort(comparison$expected_fixture_ids, method = "radix"), collapse = "|"), algo = "sha256", serialize = FALSE),
    freeze_id = as.character(freeze_row$freeze_id[[1L]]), freeze_self_sha256 = as.character(freeze_row$freeze_self_sha256[[1L]]), recipe_sha256 = as.character(freeze_row$recipe_sha256[[1L]]), score_support_g = 40L,
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

phase12_selection_no_score_row <- function(candidate_id, track_id, reason = "calibration_artifact_unavailable") {
  data.frame(
    schema_version = "phase12-calibration-gate-v1", candidate_id = as.character(candidate_id), track_id = as.character(track_id), score_status = "no_score",
    primary_probability_view = "raw_1x2", calibration_promoted = FALSE, reason_codes = as.character(reason), reason_count = 1L,
    calibration_support_valid = FALSE, fixture_identity_match = FALSE, edition_identity_match = FALSE, track_identity_match = FALSE,
    score_distribution_identity_match = FALSE, auxiliary_market_identity_match = FALSE, prediction_status_identity_match = FALSE,
    score_distribution_unchanged = FALSE, coverage_numerator = 0L, coverage_denominator = 0L, expected_fixture_count = 0L, observed_fixture_count = 0L,
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

#' Build durable comparison rows, retaining no-score candidate/track states.
#' @export
phase12_calibration_gate_rows <- function(comparison, candidate_id = NULL, track_id = NULL, protocol = NULL, freeze_manifest = "data/benchmark/phase12/freeze_manifest.csv", candidate_registry = NULL) {
  if (is.null(candidate_registry)) {
    freeze <- phase12_selection_freeze(freeze_manifest)
    candidate_registry <- data.frame(candidate_id = as.character(freeze$candidate_id), track_id = "updating", stringsAsFactors = FALSE)
  }
  if (!all(c("candidate_id", "track_id") %in% names(candidate_registry))) stop("Phase 12 calibration gate registry requires candidate_id and track_id", call. = FALSE)
  if (is.null(candidate_id)) candidate_id <- comparison$candidate_id
  if (is.null(track_id)) track_id <- comparison$track_id
  scored <- phase12_selection_one_gate_row(comparison, candidate_id, track_id, protocol)
  rows <- lapply(seq_len(nrow(candidate_registry)), function(i) {
    id <- as.character(candidate_registry$candidate_id[[i]]); track <- as.character(candidate_registry$track_id[[i]])
    if (identical(id, as.character(candidate_id)) && identical(track, as.character(track_id))) scored else phase12_selection_no_score_row(id, track)
  })
  columns <- unique(unlist(lapply(rows, names), use.names = FALSE))
  rows <- lapply(rows, function(row) {
    for (column in setdiff(columns, names(row))) row[[column]] <- NA
    row[, columns, drop = FALSE]
  })
  result <- do.call(rbind, rows)
  result[order(result$candidate_id, result$track_id, method = "radix"), , drop = FALSE]
}

#' Write and read back the canonical Phase 12 calibration gate CSV.
#' @export
write_phase12_calibration_gate <- function(rows, path = "outputs/benchmarks/rolling_tournaments/phase12-calibration-release/calibration/calibration_gate.csv") {
  if (!is.data.frame(rows) || !nrow(rows)) stop("Phase 12 calibration gate rows must be non-empty", call. = FALSE)
  required <- c("candidate_id", "track_id", "score_status", "primary_probability_view", "calibration_promoted", "reason_codes", "coverage_numerator", "coverage_denominator")
  missing <- setdiff(required, names(rows))
  if (length(missing)) stop("Phase 12 calibration gate rows missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  if (anyDuplicated(paste(rows$candidate_id, rows$track_id, sep = "\r"))) stop("Phase 12 calibration gate rows contain duplicate candidate/track identities", call. = FALSE)
  if (any(!as.character(rows$primary_probability_view) %in% c("calibrated_1x2", "raw_1x2"))) stop("Phase 12 calibration gate primary view is invalid", call. = FALSE)
  rows <- rows[order(rows$candidate_id, rows$track_id, method = "radix"), , drop = FALSE]
  path <- phase12_selection_resolve_path(path)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(rows, path, row.names = FALSE, na = "", quote = TRUE)
  persisted <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  if (!identical(names(persisted), names(rows)) || nrow(persisted) != nrow(rows) || !identical(as.character(persisted$candidate_id), as.character(rows$candidate_id))) stop("Phase 12 calibration gate read-back identity drifted", call. = FALSE)
  invisible(path)
}
