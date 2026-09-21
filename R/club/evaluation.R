#' Frozen paired evaluation and promotion authority for club forecasts.
#'
#' This module is deliberately club-owned. It adapts validated Phase 19 goal
#' distributions to the domain-neutral proper-score functions, but does not
#' accept national benchmark identities, filtered denominators, or summary-only
#' claims as authority.

phase19_club_evaluation_abort <- function(reason_code, message, data = list()) {
  stop(structure(
    c(list(message = as.character(message), call = NULL,
           reason_code = as.character(reason_code)), data),
    class = c("phase19_club_evaluation_error", "error", "condition")
  ))
}

phase19_club_evaluation_require_dependencies <- function() {
  required <- c(
    "phase18_canonical_encoding_v2", "phase18_hash_sequence_v2",
    "phase18_hash_table_v2", "phase19_is_sha256",
    "phase19_fold_registry_schema", "phase19_fold_row_sha256",
    "phase19_fold_parse_id_text", "phase19_fold_parse_utc",
    "phase19_validate_fold_prediction_coverage",
    "phase19_validate_gate_registry", "phase19_gate_registry_sha256",
    "phase19_validate_club_goal_predictions",
    "phase19_validate_club_goal_prediction_source",
    "phase19_club_goal_calibration_input",
    "phase19_validate_club_rating_replay",
    "phase19_validate_club_calibrator_source",
    "phase19_validate_club_calibrated_view_source",
    "phase19_validate_club_calibration_decision_source",
    "score_benchmark_fixtures",
    "ranked_probability_score", "multiclass_brier", "log_score"
  )
  missing <- required[!vapply(required, exists, logical(1), mode = "function")]
  if (length(missing)) {
    phase19_club_evaluation_abort(
      "evaluation_dependency_missing",
      paste0("Phase 19 evaluation dependencies must be sourced first: ",
             paste(missing, collapse = ", "))
    )
  }
  invisible(TRUE)
}

phase19_club_evaluation_hash_values <- function(values, domain) {
  phase18_hash_sequence_v2(
    values, domain = domain, names = names(values),
    types = vapply(values, phase18_v2_type_tag, character(1))
  )
}

.phase19_club_evaluation_validation_cache <- new.env(parent = emptyenv())

phase19_club_evaluation_cache_key <- function(value, domain) {
  if (!requireNamespace("digest", quietly = TRUE)) {
    phase19_club_evaluation_abort(
      "evaluation_dependency_missing", "digest is required for validation memoization"
    )
  }
  paste0(domain, ":", digest::digest(value, algo = "sha256", serialize = TRUE))
}

phase19_club_evaluation_capture <- function(expression, reason_code) {
  tryCatch(
    expression,
    error = function(error) {
      upstream <- if (is.null(error$reason_code)) class(error)[[1L]] else error$reason_code
      phase19_club_evaluation_abort(
        reason_code, conditionMessage(error), list(upstream_reason = upstream)
      )
    }
  )
}

phase19_club_evaluation_validate_fold <- function(fold, protocol) {
  if (!is.data.frame(fold) || nrow(fold) != 1L ||
      !identical(names(fold), phase19_fold_registry_schema()) ||
      !identical(as.character(fold$row_sha256), phase19_fold_row_sha256(fold)) ||
      !inherits(protocol, "phase19_club_evaluation_protocol") ||
      !identical(protocol$status, "ready") ||
      !identical(protocol$forecast_domain, "club") ||
      !identical(as.character(fold$forecast_domain), "club") ||
      !identical(as.character(fold$authority_mode), protocol$authority_mode) ||
      !identical(isTRUE(fold$fixture_authority), isTRUE(protocol$fixture_authority)) ||
      !identical(as.character(fold$protocol_sha256), protocol$protocol_sha256) ||
      !identical(as.character(fold$policy_review_sha256),
                 protocol$policy_review$review_sha256) ||
      !identical(as.character(fold$calibration_recipe_sha256),
                 phase19_expected_calibration_recipe()$recipe_sha256)) {
    phase19_club_evaluation_abort(
      "evaluation_fold_authority_invalid",
      "Evaluation requires one canonical fold bound to the exact ready club protocol"
    )
  }
  invisible(fold)
}

phase19_club_evaluation_canonical_predictions <- function(result,
                                                           declared_fixture_ids) {
  if (!inherits(result, "phase19_club_goal_predictions") ||
      !is.data.frame(result$predictions) || !is.data.frame(result$distributions)) {
    phase19_club_evaluation_abort(
      "evaluation_prediction_invalid", "Evaluation input is not a club goal-prediction set"
    )
  }
  canonical <- result
  canonical$predictions <- canonical$predictions[
    order(as.character(canonical$predictions$fixture_id), method = "radix"), , drop = FALSE
  ]
  rownames(canonical$predictions) <- NULL
  if (nrow(canonical$distributions)) {
    canonical$distributions <- canonical$distributions[order(
      as.character(canonical$distributions$fixture_id),
      as.integer(canonical$distributions$home_goals),
      as.integer(canonical$distributions$away_goals), method = "radix"
    ), , drop = FALSE]
    rownames(canonical$distributions) <- NULL
  }
  phase19_club_evaluation_capture(
    phase19_validate_club_goal_predictions(
      canonical, declared_fixture_ids, require_goal_grid = TRUE
    ), "evaluation_prediction_invalid"
  )
  canonical
}

phase19_club_evaluation_outcome_schema <- function() {
  c(
    "fixture_id", "forecast_domain", "competition_id", "season_id",
    "kickoff_utc", "completion_not_before_utc", "evidence_available_at_utc",
    "home_club_id", "away_club_id", "regulation_home_goals",
    "regulation_away_goals"
  )
}

phase19_club_evaluation_outcomes <- function(outcomes, fold, predictions) {
  schema <- phase19_club_evaluation_outcome_schema()
  if (!is.data.frame(outcomes) || !identical(names(outcomes), schema) ||
      !nrow(outcomes) || anyNA(outcomes) ||
      any(!vapply(outcomes[setdiff(schema, c(
        "regulation_home_goals", "regulation_away_goals"
      ))], is.character, logical(1))) ||
      !is.integer(outcomes$regulation_home_goals) ||
      !is.integer(outcomes$regulation_away_goals) ||
      any(outcomes$regulation_home_goals < 0L) ||
      any(outcomes$regulation_away_goals < 0L) ||
      anyDuplicated(outcomes$fixture_id) ||
      any(outcomes$forecast_domain != "club") ||
      any(outcomes$competition_id != fold$assessment_competition_id) ||
      any(outcomes$season_id != fold$assessment_season_id)) {
    phase19_club_evaluation_abort(
      "evaluation_outcome_invalid", "Assessment outcomes are incomplete, duplicate, or mixed-domain"
    )
  }
  expected <- phase19_fold_parse_id_text(
    fold$declared_fixture_ids[[1L]], "declared_fixture_ids"
  )
  if (!identical(sort(outcomes$fixture_id, method = "radix"), expected)) {
    phase19_club_evaluation_abort(
      "evaluation_coverage_invalid", "Assessment outcomes must preserve every declared denominator row"
    )
  }
  outcomes <- outcomes[match(expected, outcomes$fixture_id), , drop = FALSE]
  predictions <- predictions[match(expected, predictions$fixture_id), , drop = FALSE]
  rownames(outcomes) <- NULL
  if (any(outcomes$home_club_id != predictions$home_club_id) ||
      any(outcomes$away_club_id != predictions$away_club_id)) {
    phase19_club_evaluation_abort(
      "evaluation_identity_invalid", "Outcome and prediction club identities differ"
    )
  }
  kickoff <- phase19_club_evaluation_capture(
    phase19_fold_parse_utc(outcomes$kickoff_utc, "assessment kickoff"),
    "evaluation_cutoff_invalid"
  )
  completion <- phase19_club_evaluation_capture(
    phase19_fold_parse_utc(outcomes$completion_not_before_utc, "assessment completion"),
    "evaluation_cutoff_invalid"
  )
  available <- phase19_club_evaluation_capture(
    phase19_fold_parse_utc(outcomes$evidence_available_at_utc, "assessment evidence"),
    "evaluation_cutoff_invalid"
  )
  start <- phase19_fold_parse_utc(fold$assessment_start_utc, "assessment start")[[1L]]
  end <- phase19_fold_parse_utc(fold$assessment_end_utc, "assessment end")[[1L]]
  if (any(kickoff < start | kickoff > end) || any(completion < kickoff) ||
      any(available < completion)) {
    phase19_club_evaluation_abort(
      "evaluation_cutoff_invalid", "Assessment labels or evidence violate the frozen interval"
    )
  }
  outcomes
}

phase19_club_evaluation_support_schema <- function() {
  c(
    "model_id", "fit_status", "fallback_status", "fit_sha256",
    "calibrator_status", "primary_probability_view", "calibrator_sha256",
    "calibration_evidence_sha256", "calibration_decision_sha256"
  )
}

phase19_club_evaluation_support <- function(model_support, candidate, incumbent) {
  schema <- phase19_club_evaluation_support_schema()
  ids <- c("club_venue_nb", "club_elo_nb")
  if (!is.data.frame(model_support) || !identical(names(model_support), schema) ||
      nrow(model_support) != 2L || anyNA(model_support) ||
      any(!vapply(model_support, is.character, logical(1))) ||
      anyDuplicated(model_support$model_id) || !setequal(model_support$model_id, ids) ||
      any(model_support$fit_status != "converged") ||
      any(model_support$fallback_status != "none") ||
      any(model_support$calibrator_status != "fitted") ||
      any(!model_support$primary_probability_view %in% c("raw_1x2", "calibrated_1x2"))) {
    phase19_club_evaluation_abort(
      "evaluation_model_support_invalid",
      "Evaluation requires exact converged fit and fitted-calibrator evidence for both models"
    )
  }
  hash_fields <- c(
    "fit_sha256", "calibrator_sha256", "calibration_evidence_sha256",
    "calibration_decision_sha256"
  )
  if (any(!vapply(unlist(model_support[hash_fields], use.names = FALSE),
                  phase19_is_sha256, logical(1)))) {
    phase19_club_evaluation_abort(
      "evaluation_model_support_invalid", "Model support contains an invalid identity"
    )
  }
  model_support <- model_support[match(ids, model_support$model_id), , drop = FALSE]
  rownames(model_support) <- NULL
  expected_fit <- c(incumbent$fit_sha256, candidate$fit_sha256)
  if (!identical(model_support$fit_sha256, expected_fit)) {
    phase19_club_evaluation_abort(
      "evaluation_model_support_invalid", "Model support does not bind the supplied fits"
    )
  }
  model_support
}

phase19_club_evaluation_role_schema <- function() {
  c("role", "cutoff_exclusive", "excluded_competition_id", "declared_fixture_sha256")
}

phase19_club_evaluation_role_provenance <- function(role_provenance, fold) {
  schema <- phase19_club_evaluation_role_schema()
  roles <- c("fit", "tuning", "calibration")
  if (!is.data.frame(role_provenance) || !identical(names(role_provenance), schema) ||
      nrow(role_provenance) != 3L || anyNA(role_provenance) ||
      any(!vapply(role_provenance, is.character, logical(1))) ||
      anyDuplicated(role_provenance$role) || !setequal(role_provenance$role, roles)) {
    phase19_club_evaluation_abort(
      "evaluation_role_provenance_invalid", "Fit, tuning, and calibration provenance is incomplete"
    )
  }
  role_provenance <- role_provenance[match(roles, role_provenance$role), , drop = FALSE]
  rownames(role_provenance) <- NULL
  expected_cutoff <- c(
    fold$training_cutoff_exclusive, fold$training_cutoff_exclusive,
    fold$calibration_cutoff_exclusive
  )
  expected_exclusion <- c(
    fold$fit_excluded_competition_id, fold$tuning_excluded_competition_id,
    fold$calibration_excluded_competition_id
  )
  expected_inventory <- c(
    fold$training_fixture_sha256, fold$training_fixture_sha256,
    fold$calibration_fixture_sha256
  )
  if (!identical(role_provenance$cutoff_exclusive, expected_cutoff) ||
      !identical(role_provenance$excluded_competition_id, expected_exclusion) ||
      !identical(role_provenance$declared_fixture_sha256, expected_inventory) ||
      any(!vapply(role_provenance$declared_fixture_sha256,
                  phase19_is_sha256, logical(1)))) {
    phase19_club_evaluation_abort(
      "evaluation_heldout_leakage",
      "Role provenance does not preserve the frozen cutoffs, inventories, and held-out exclusions"
    )
  }
  role_provenance
}

phase19_club_evaluation_benchmark_inputs <- function(result, fold) {
  predictions <- result$predictions
  data.frame(
    run_id = as.character(fold$fold_id), model_id = predictions$model_id,
    panel_id = "club", edition_id = as.character(fold$fold_id),
    track_id = as.character(fold$fold_family), fixture_id = predictions$fixture_id,
    score_distribution_id = predictions$score_distribution_id,
    p_home = predictions$p_home, p_draw = predictions$p_draw,
    p_away = predictions$p_away, p_over_2_5 = predictions$p_over_2_5,
    p_under_2_5 = 1 - predictions$p_over_2_5, p_btts = predictions$p_btts,
    prediction_status = ifelse(
      predictions$prediction_status == "ready_goal_distribution", "ok", "failed"
    ), stringsAsFactors = FALSE, check.names = FALSE
  )
}

phase19_club_evaluation_complete_bins <- function(predictions, outcomes) {
  classes <- c("home", "draw", "away")
  probability_fields <- c("p_home", "p_draw", "p_away")
  result <- list()
  cursor <- 0L
  for (model_id in sort(unique(predictions$model_id), method = "radix")) {
    rows <- predictions[predictions$model_id == model_id, , drop = FALSE]
    labels <- outcomes[match(rows$fixture_id, outcomes$fixture_id), , drop = FALSE]
    observed_class <- ifelse(
      labels$regulation_home_goals > labels$regulation_away_goals, "home",
      ifelse(labels$regulation_home_goals < labels$regulation_away_goals, "away", "draw")
    )
    for (index in seq_along(classes)) {
      probability <- as.numeric(rows[[probability_fields[[index]]]])
      observed <- as.numeric(observed_class == classes[[index]])
      assigned <- pmin(floor(probability * 10), 9L) + 1L
      for (bin_id in seq_len(10L)) {
        keep <- assigned == bin_id
        cursor <- cursor + 1L
        result[[cursor]] <- data.frame(
          model_id = model_id, class = classes[[index]], bin_id = as.integer(bin_id),
          bin_lower = (bin_id - 1) / 10, bin_upper = bin_id / 10,
          n = as.integer(sum(keep)),
          mean_probability = if (any(keep)) mean(probability[keep]) else NA_real_,
          observed_frequency = if (any(keep)) mean(observed[keep]) else NA_real_,
          absolute_gap = if (any(keep)) {
            abs(mean(probability[keep]) - mean(observed[keep]))
          } else NA_real_, stringsAsFactors = FALSE, check.names = FALSE
        )
      }
    }
  }
  bins <- do.call(rbind, result)
  rownames(bins) <- NULL
  bins
}

phase19_club_evaluation_calibration_error <- function(bins, model_id) {
  rows <- bins[bins$model_id == model_id & bins$n > 0L, , drop = FALSE]
  mean(vapply(c("home", "draw", "away"), function(class) {
    selected <- rows[rows$class == class, , drop = FALSE]
    support <- sum(selected$n)
    if (!length(selected$n) || !is.finite(support) || support <= 0L ||
        any(!is.finite(selected$absolute_gap))) {
      phase19_club_evaluation_abort(
        "insufficient_class_support",
        paste0("Evaluation calibration error requires positive support for class ", class)
      )
    }
    sum(selected$n * selected$absolute_gap) / support
  }, numeric(1)))
}

phase19_club_fold_evaluation_schema <- function() {
  c(
    "schema_version", "hash_encoding_version", "forecast_domain", "status",
    "authority_mode", "fixture_authority", "production_eligible", "fold_id",
    "fold_family", "assessment_competition_id", "assessment_season_id",
    "candidate_id", "incumbent_id", "declared_fixture_count",
    "fold_row_sha256", "protocol_sha256", "policy_review_sha256",
    "gate_registry_sha256", "candidate_prediction_sha256",
    "candidate_distribution_sha256", "incumbent_prediction_sha256",
    "incumbent_distribution_sha256", "outcomes_sha256", "model_support_sha256",
    "role_provenance_sha256", "predictions_sha256", "distributions_sha256",
    "fixture_scores_sha256", "calibration_bins_sha256", "coverage_sha256",
    "convergence_sha256", "cutoff_evidence_sha256", "fold_summary_sha256",
    "predictions", "distributions", "fixture_scores", "calibration_bins",
    "coverage", "convergence", "cutoff_evidence", "role_provenance",
    "fold_summary", "evaluation_sha256"
  )
}

phase19_club_fold_evaluation_sha256 <- function(evidence) {
  schema <- phase19_club_fold_evaluation_schema()
  if (!is.list(evidence) || !identical(names(evidence), schema)) {
    phase19_club_evaluation_abort(
      "evaluation_schema_invalid", "Club fold evaluation schema is not exact"
    )
  }
  fields <- schema[seq_len(match("fold_summary_sha256", schema))]
  phase19_club_evaluation_hash_values(
    evidence[fields], "phase19-club-fold-evaluation-v1"
  )
}

#' Score one exact club fold for the frozen candidate and incumbent.
#'
#' @export
phase19_score_club_fold <- function(candidate_predictions, incumbent_predictions,
                                    outcomes, fold, protocol, model_support,
                                    role_provenance) {
  phase19_club_evaluation_require_dependencies()
  phase19_club_evaluation_validate_fold(fold, protocol)
  declared <- phase19_fold_parse_id_text(
    fold$declared_fixture_ids[[1L]], "declared_fixture_ids"
  )
  candidate <- phase19_club_evaluation_canonical_predictions(
    candidate_predictions, declared
  )
  incumbent <- phase19_club_evaluation_canonical_predictions(
    incumbent_predictions, declared
  )
  if (!identical(candidate$model_id, "club_elo_nb") ||
      !identical(incumbent$model_id, "club_venue_nb") ||
      !isTRUE(candidate$promotion_comparable) ||
      !isTRUE(incumbent$promotion_comparable) ||
      !identical(candidate$authority_mode, as.character(fold$authority_mode)) ||
      !identical(incumbent$authority_mode, as.character(fold$authority_mode)) ||
      !identical(isTRUE(candidate$fixture_authority), isTRUE(fold$fixture_authority)) ||
      !identical(isTRUE(incumbent$fixture_authority), isTRUE(fold$fixture_authority))) {
    phase19_club_evaluation_abort(
      "evaluation_model_pair_invalid",
      "Evaluation requires only club_elo_nb against the exact club_venue_nb incumbent"
    )
  }
  combined_predictions <- rbind(candidate$predictions, incumbent$predictions)
  if (any(combined_predictions$protocol_sha256 != protocol$protocol_sha256) ||
      any(combined_predictions$training_snapshot_sha256 != fold$snapshot_sha256) ||
      any(combined_predictions$evidence_cutoff_exclusive !=
            fold$calibration_cutoff_exclusive) ||
      length(unique(combined_predictions$current_snapshot_sha256)) != 1L ||
      any(combined_predictions$forecast_domain != "club")) {
    phase19_club_evaluation_abort(
      "evaluation_parent_mismatch",
      "Prediction protocol, snapshot, current-roster, domain, or cutoff parents drifted"
    )
  }
  phase19_validate_fold_prediction_coverage(fold, candidate$predictions$fixture_id)
  phase19_validate_fold_prediction_coverage(fold, incumbent$predictions$fixture_id)
  outcomes <- phase19_club_evaluation_outcomes(
    outcomes, fold, candidate$predictions
  )
  if (any(incumbent$predictions$home_club_id != candidate$predictions$home_club_id) ||
      any(incumbent$predictions$away_club_id != candidate$predictions$away_club_id)) {
    phase19_club_evaluation_abort(
      "evaluation_pairing_invalid", "Candidate and incumbent club identities are not paired"
    )
  }
  support <- phase19_club_evaluation_support(model_support, candidate, incumbent)
  provenance <- phase19_club_evaluation_role_provenance(role_provenance, fold)

  benchmark_predictions <- rbind(
    phase19_club_evaluation_benchmark_inputs(candidate, fold),
    phase19_club_evaluation_benchmark_inputs(incumbent, fold)
  )
  benchmark_predictions <- benchmark_predictions[order(
    benchmark_predictions$model_id, benchmark_predictions$fixture_id,
    method = "radix"
  ), , drop = FALSE]
  benchmark_distributions <- rbind(candidate$distributions, incumbent$distributions)
  benchmark_distributions <- benchmark_distributions[order(
    benchmark_distributions$model_id, benchmark_distributions$fixture_id,
    benchmark_distributions$home_goals, benchmark_distributions$away_goals,
    method = "radix"
  ), , drop = FALSE]
  benchmark_fixtures <- data.frame(
    edition_id = as.character(fold$fold_id), fixture_id = outcomes$fixture_id,
    regulation_home_goals = outcomes$regulation_home_goals,
    regulation_away_goals = outcomes$regulation_away_goals,
    score_eligible = TRUE, stringsAsFactors = FALSE, check.names = FALSE
  )
  scores <- phase19_club_evaluation_capture(
    score_benchmark_fixtures(
      benchmark_predictions, benchmark_fixtures,
      benchmark_distributions[, c(
        "score_distribution_id", "home_goals", "away_goals", "probability"
      ), drop = FALSE], declared
    ), "evaluation_scoring_failed"
  )
  scores$fold_id <- as.character(fold$fold_id)
  scores$fold_family <- as.character(fold$fold_family)
  scores$competition_id <- as.character(fold$assessment_competition_id)
  scores$season_id <- as.character(fold$assessment_season_id)
  scores <- scores[order(scores$model_id, scores$fixture_id, scores$metric,
                         method = "radix"), , drop = FALSE]
  rownames(scores) <- NULL
  bins <- phase19_club_evaluation_complete_bins(benchmark_predictions, outcomes)
  coverage <- data.frame(
    model_id = c("club_elo_nb", "club_venue_nb"),
    declared_fixture_count = as.integer(length(declared)),
    observed_fixture_count = c(nrow(candidate$predictions), nrow(incumbent$predictions)),
    fixture_coverage = c(nrow(candidate$predictions), nrow(incumbent$predictions)) /
      length(declared),
    expected_grid_cell_count = as.integer(length(declared) * 1681L),
    observed_grid_cell_count = c(nrow(candidate$distributions), nrow(incumbent$distributions)),
    score_grid_coverage = c(nrow(candidate$distributions), nrow(incumbent$distributions)) /
      (length(declared) * 1681L), stringsAsFactors = FALSE, check.names = FALSE
  )
  coverage <- coverage[order(coverage$model_id, method = "radix"), , drop = FALSE]
  convergence <- data.frame(
    model_id = support$model_id,
    converged = support$fit_status == "converged",
    fallback_status = support$fallback_status,
    fit_sha256 = support$fit_sha256,
    calibrator_status = support$calibrator_status,
    primary_probability_view = support$primary_probability_view,
    calibrator_sha256 = support$calibrator_sha256,
    calibration_evidence_sha256 = support$calibration_evidence_sha256,
    calibration_decision_sha256 = support$calibration_decision_sha256,
    stringsAsFactors = FALSE, check.names = FALSE
  )
  cutoff_evidence <- data.frame(
    model_id = c("club_elo_nb", "club_venue_nb"),
    prediction_cutoff_exclusive = fold$calibration_cutoff_exclusive,
    fit_cutoff_exclusive = fold$training_cutoff_exclusive,
    held_out_competition_id = fold$held_out_competition_id,
    cutoff_passed = TRUE, stringsAsFactors = FALSE, check.names = FALSE
  )
  metric_mean <- function(model, metric) {
    mean(scores$value[scores$model_id == model & scores$metric == metric])
  }
  candidate_rps <- metric_mean("club_elo_nb", "rps")
  incumbent_rps <- metric_mean("club_venue_nb", "rps")
  candidate_brier <- metric_mean("club_elo_nb", "brier")
  incumbent_brier <- metric_mean("club_venue_nb", "brier")
  candidate_log <- metric_mean("club_elo_nb", "log_loss")
  incumbent_log <- metric_mean("club_venue_nb", "log_loss")
  summary <- data.frame(
    fold_id = as.character(fold$fold_id),
    fold_family = as.character(fold$fold_family),
    competition_id = as.character(fold$assessment_competition_id),
    season_id = as.character(fold$assessment_season_id),
    fixture_count = as.integer(length(declared)), candidate_rps = candidate_rps,
    incumbent_rps = incumbent_rps, rps_delta = candidate_rps - incumbent_rps,
    candidate_brier = candidate_brier, incumbent_brier = incumbent_brier,
    candidate_log_loss = candidate_log, incumbent_log_loss = incumbent_log,
    candidate_calibration_error = phase19_club_evaluation_calibration_error(
      bins, "club_elo_nb"
    ),
    incumbent_calibration_error = phase19_club_evaluation_calibration_error(
      bins, "club_venue_nb"
    ), stringsAsFactors = FALSE, check.names = FALSE
  )
  table_hash <- function(data, key, tag) {
    phase18_hash_table_v2(data, key = key, schema_tag = tag)
  }
  all_predictions <- rbind(candidate$predictions, incumbent$predictions)
  all_predictions <- all_predictions[order(all_predictions$model_id,
                                           all_predictions$fixture_id,
                                           method = "radix"), , drop = FALSE]
  all_distributions <- rbind(candidate$distributions, incumbent$distributions)
  all_distributions <- all_distributions[order(
    all_distributions$model_id, all_distributions$fixture_id,
    all_distributions$home_goals, all_distributions$away_goals, method = "radix"
  ), , drop = FALSE]
  result <- list(
    schema_version = "phase19-club-fold-evaluation-v1",
    hash_encoding_version = phase18_canonical_encoding_v2(),
    forecast_domain = "club", status = "scored",
    authority_mode = as.character(fold$authority_mode),
    fixture_authority = isTRUE(fold$fixture_authority), production_eligible = FALSE,
    fold_id = as.character(fold$fold_id), fold_family = as.character(fold$fold_family),
    assessment_competition_id = as.character(fold$assessment_competition_id),
    assessment_season_id = as.character(fold$assessment_season_id),
    candidate_id = "club_elo_nb", incumbent_id = "club_venue_nb",
    declared_fixture_count = as.integer(length(declared)),
    fold_row_sha256 = as.character(fold$row_sha256),
    protocol_sha256 = protocol$protocol_sha256,
    policy_review_sha256 = protocol$policy_review$review_sha256,
    gate_registry_sha256 = phase19_gate_registry_sha256(protocol$gate_registry),
    candidate_prediction_sha256 = candidate$prediction_table_sha256,
    candidate_distribution_sha256 = candidate$distribution_table_sha256,
    incumbent_prediction_sha256 = incumbent$prediction_table_sha256,
    incumbent_distribution_sha256 = incumbent$distribution_table_sha256,
    outcomes_sha256 = table_hash(
      outcomes, "fixture_id", "phase19-club-evaluation-outcomes-v1"
    ),
    model_support_sha256 = table_hash(
      support, "model_id", "phase19-club-evaluation-model-support-v1"
    ),
    role_provenance_sha256 = table_hash(
      provenance, "role", "phase19-club-evaluation-role-provenance-v1"
    ),
    predictions_sha256 = table_hash(
      all_predictions, c("model_id", "fixture_id"),
      "phase19-club-evaluation-predictions-v1"
    ),
    distributions_sha256 = table_hash(
      all_distributions, c("model_id", "fixture_id", "home_goals", "away_goals"),
      "phase19-club-evaluation-distributions-v1"
    ),
    fixture_scores_sha256 = table_hash(
      scores, c("model_id", "fixture_id", "metric"),
      "phase19-club-evaluation-fixture-scores-v1"
    ),
    calibration_bins_sha256 = table_hash(
      bins, c("model_id", "class", "bin_id"),
      "phase19-club-evaluation-calibration-bins-v1"
    ),
    coverage_sha256 = table_hash(
      coverage, "model_id", "phase19-club-evaluation-coverage-v1"
    ),
    convergence_sha256 = table_hash(
      convergence, "model_id", "phase19-club-evaluation-convergence-v1"
    ),
    cutoff_evidence_sha256 = table_hash(
      cutoff_evidence, "model_id", "phase19-club-evaluation-cutoffs-v1"
    ),
    fold_summary_sha256 = table_hash(
      summary, "fold_id", "phase19-club-evaluation-fold-summary-v1"
    ),
    predictions = all_predictions, distributions = all_distributions,
    fixture_scores = scores, calibration_bins = bins, coverage = coverage,
    convergence = convergence, cutoff_evidence = cutoff_evidence,
    role_provenance = provenance, fold_summary = summary,
    evaluation_sha256 = ""
  )
  result$evaluation_sha256 <- phase19_club_fold_evaluation_sha256(result)
  structure(result, class = c("phase19_club_fold_evaluation", "list"))
}

#' Recompute one fold evaluation from exact source evidence.
#'
#' @export
phase19_validate_club_fold_evaluation <- function(
    evidence, candidate_predictions, incumbent_predictions, outcomes, fold,
    protocol, model_support, role_provenance
) {
  if (!inherits(evidence, "phase19_club_fold_evaluation") ||
      !identical(names(evidence), phase19_club_fold_evaluation_schema()) ||
      !identical(evidence$evaluation_sha256,
                 phase19_club_fold_evaluation_sha256(evidence))) {
    phase19_club_evaluation_abort(
      "evaluation_hash_mismatch", "Club fold evidence schema or identity drifted"
    )
  }
  expected <- phase19_score_club_fold(
    candidate_predictions, incumbent_predictions, outcomes, fold, protocol,
    model_support, role_provenance
  )
  if (!identical(evidence$evaluation_sha256, expected$evaluation_sha256)) {
    phase19_club_evaluation_abort(
      "evaluation_source_mismatch", "Club fold evidence does not derive from exact source rows"
    )
  }
  invisible(evidence)
}

phase19_club_evaluation_seed <- function(protocol, seed_id) {
  rows <- protocol$seed_registry[
    protocol$seed_registry$seed_id == seed_id, , drop = FALSE
  ]
  if (nrow(rows) != 1L || !is.integer(rows$seed) || rows$seed <= 0L) {
    phase19_club_evaluation_abort(
      "evaluation_seed_invalid", paste0("Registered evaluation seed is missing: ", seed_id)
    )
  }
  rows
}

phase19_club_evaluation_fold_self_check <- function(evidence) {
  cache_key <- phase19_club_evaluation_cache_key(evidence, "fold")
  if (exists(cache_key, envir = .phase19_club_evaluation_validation_cache,
             inherits = FALSE)) {
    return(invisible(evidence))
  }
  if (!inherits(evidence, "phase19_club_fold_evaluation") ||
      !identical(names(evidence), phase19_club_fold_evaluation_schema()) ||
      !identical(evidence$evaluation_sha256,
                 phase19_club_fold_evaluation_sha256(evidence)) ||
      !identical(evidence$forecast_domain, "club") ||
      !identical(evidence$status, "scored") ||
      !identical(evidence$candidate_id, "club_elo_nb") ||
      !identical(evidence$incumbent_id, "club_venue_nb")) {
    phase19_club_evaluation_abort(
      "evaluation_hash_mismatch", "Fold evaluation identity or model pair drifted"
    )
  }
  specifications <- list(
    predictions = list(c("model_id", "fixture_id"),
                       "phase19-club-evaluation-predictions-v1",
                       "predictions_sha256"),
    distributions = list(c("model_id", "fixture_id", "home_goals", "away_goals"),
                         "phase19-club-evaluation-distributions-v1",
                         "distributions_sha256"),
    fixture_scores = list(c("model_id", "fixture_id", "metric"),
                          "phase19-club-evaluation-fixture-scores-v1",
                          "fixture_scores_sha256"),
    calibration_bins = list(c("model_id", "class", "bin_id"),
                            "phase19-club-evaluation-calibration-bins-v1",
                            "calibration_bins_sha256"),
    coverage = list("model_id", "phase19-club-evaluation-coverage-v1",
                    "coverage_sha256"),
    convergence = list("model_id", "phase19-club-evaluation-convergence-v1",
                       "convergence_sha256"),
    cutoff_evidence = list("model_id", "phase19-club-evaluation-cutoffs-v1",
                           "cutoff_evidence_sha256"),
    role_provenance = list("role", "phase19-club-evaluation-role-provenance-v1",
                           "role_provenance_sha256"),
    fold_summary = list("fold_id", "phase19-club-evaluation-fold-summary-v1",
                        "fold_summary_sha256")
  )
  for (name in names(specifications)) {
    item <- specifications[[name]]
    observed <- phase18_hash_table_v2(
      evidence[[name]], key = item[[1L]], schema_tag = item[[2L]]
    )
    if (!identical(observed, evidence[[item[[3L]]]])) {
      phase19_club_evaluation_abort(
        "evaluation_hash_mismatch", paste0("Fold evaluation table drifted: ", name)
      )
    }
  }
  if (any(evidence$coverage$fixture_coverage != 1) ||
      any(evidence$coverage$score_grid_coverage != 1) ||
      any(!evidence$convergence$converged) ||
      any(evidence$convergence$fallback_status != "none") ||
      any(!evidence$cutoff_evidence$cutoff_passed) ||
      nrow(evidence$fold_summary) != 1L ||
      !identical(as.character(evidence$fold_summary$fold_id), evidence$fold_id)) {
    phase19_club_evaluation_abort(
      "evaluation_contract_failed", "Fold evaluation coverage, convergence, or cutoff failed"
    )
  }
  metric_mean <- function(model, metric) {
    mean(evidence$fixture_scores$value[
      evidence$fixture_scores$model_id == model &
        evidence$fixture_scores$metric == metric
    ])
  }
  summary <- evidence$fold_summary
  expected <- c(
    candidate_rps = metric_mean("club_elo_nb", "rps"),
    incumbent_rps = metric_mean("club_venue_nb", "rps"),
    candidate_brier = metric_mean("club_elo_nb", "brier"),
    incumbent_brier = metric_mean("club_venue_nb", "brier"),
    candidate_log_loss = metric_mean("club_elo_nb", "log_loss"),
    incumbent_log_loss = metric_mean("club_venue_nb", "log_loss")
  )
  observed <- unlist(summary[names(expected)], use.names = FALSE)
  if (!isTRUE(all.equal(as.numeric(observed), as.numeric(expected),
                        tolerance = 0, check.attributes = FALSE)) ||
      !identical(as.numeric(summary$rps_delta),
                 as.numeric(summary$candidate_rps - summary$incumbent_rps))) {
    phase19_club_evaluation_abort(
      "evaluation_summary_mismatch", "Fold summary does not derive from fixture scores"
    )
  }
  assign(cache_key, TRUE, envir = .phase19_club_evaluation_validation_cache)
  invisible(evidence)
}

phase19_club_fold_source_evidence_schema <- function() {
  c(
    "candidate_predictions", "incumbent_predictions", "outcomes", "fold",
    "protocol", "model_support", "role_provenance"
  )
}

phase19_club_production_fold_source_evidence_schema <- function() {
  c(
    phase19_club_fold_source_evidence_schema(),
    "candidate_fit", "candidate_fixtures", "candidate_calibration_fold",
    "candidate_calibration_source", "candidate_calibration_input",
    "candidate_calibrator", "candidate_calibrated_view",
    "candidate_calibration_evidence", "candidate_calibration_decision",
    "incumbent_fit", "incumbent_fixtures", "incumbent_calibration_fold",
    "incumbent_calibration_source", "incumbent_calibration_input",
    "incumbent_calibrator", "incumbent_calibrated_view",
    "incumbent_calibration_evidence", "incumbent_calibration_decision"
  )
}

phase19_club_evaluation_calibration_outcomes <- function(outcomes, input) {
  if (!is.data.frame(input) || !"fixture_id" %in% names(input) ||
      anyDuplicated(as.character(input$fixture_id)) ||
      !setequal(as.character(input$fixture_id), as.character(outcomes$fixture_id))) {
    phase19_club_evaluation_abort(
      "evaluation_calibration_source_invalid",
      "Calibration source input must cover the exact held-out fixture inventory"
    )
  }
  ordered <- outcomes[match(as.character(input$fixture_id), outcomes$fixture_id), , drop = FALSE]
  if (anyNA(ordered$regulation_home_goals) || anyNA(ordered$regulation_away_goals)) {
    phase19_club_evaluation_abort(
      "evaluation_calibration_source_invalid",
      "Calibration source outcomes contain incomplete labels"
    )
  }
  data.frame(
    fixture_id = as.character(input$fixture_id),
    observed_class = ifelse(
      ordered$regulation_home_goals > ordered$regulation_away_goals, "home",
      ifelse(ordered$regulation_home_goals == ordered$regulation_away_goals,
             "draw", "away")
    ), stringsAsFactors = FALSE, check.names = FALSE
  )
}

phase19_club_evaluation_source_artifacts <- function(source, label, fold,
                                                     protocol, outcomes) {
  prefix <- paste0(label, "_")
  predictions <- source[[paste0(prefix, "predictions")]]
  fit <- source[[paste0(prefix, "fit")]]
  fixtures <- source[[paste0(prefix, "fixtures")]]
  calibration_fold <- source[[paste0(prefix, "calibration_fold")]]
  calibration_source <- source[[paste0(prefix, "calibration_source")]]
  calibration_input <- source[[paste0(prefix, "calibration_input")]]
  calibrator <- source[[paste0(prefix, "calibrator")]]
  calibrated_view <- source[[paste0(prefix, "calibrated_view")]]
  calibration_evidence <- source[[paste0(prefix, "calibration_evidence")]]
  calibration_decision <- source[[paste0(prefix, "calibration_decision")]]
  if (!inherits(fit, "phase19_club_goal_fit") ||
      !inherits(calibrator, "phase19_club_calibrator") ||
      !inherits(calibrated_view, "phase19_club_calibrated_view") ||
      !inherits(calibration_evidence, "phase19_club_calibration_evidence") ||
      !inherits(calibration_decision, "phase19_club_calibration_decision")) {
    phase19_club_evaluation_abort(
      "evaluation_source_invalid",
      paste0("Production ", label, " source is missing typed fit/calibration artifacts")
    )
  }
  declared <- phase19_fold_parse_id_text(
    fold$declared_fixture_ids[[1L]], "declared_fixture_ids"
  )
  phase19_club_evaluation_capture(
    phase19_validate_club_goal_prediction_source(
      predictions, fit, fixtures, declared, require_production = TRUE
    ), "evaluation_source_invalid"
  )
  if (!identical(as.character(fit$protocol_sha256),
                 as.character(protocol$protocol_sha256)) ||
      !identical(as.character(fit$training_snapshot_sha256),
                 as.character(fold$snapshot_sha256)) ||
      any(as.character(predictions$model_id) != as.character(fit$model_id)) ||
      any(as.character(predictions$protocol_sha256) != protocol$protocol_sha256)) {
    phase19_club_evaluation_abort(
      "evaluation_source_invalid",
      paste0("Production ", label, " fit is not bound to the accepted fold/protocol")
    )
  }
  if (!is.data.frame(calibration_fold) || nrow(calibration_fold) != 1L) {
    phase19_club_evaluation_abort(
      "evaluation_source_invalid",
      paste0("Production ", label, " calibration fold is missing")
    )
  }
  phase19_club_evaluation_capture(
    phase19_club_evaluation_validate_fold(calibration_fold, protocol),
    "evaluation_source_invalid"
  )
  phase19_club_evaluation_capture(
    phase19_validate_club_calibrator_source(
      calibrator, calibration_source, calibration_fold,
      fit$registration, protocol, require_production = TRUE
    ), "evaluation_source_invalid"
  )
  expected_input <- phase19_club_goal_calibration_input(predictions)
  if (!is.data.frame(calibration_input) || !identical(calibration_input, expected_input)) {
    phase19_club_evaluation_abort(
      "evaluation_source_invalid",
      paste0("Production ", label, " calibration input is not the generated prediction view")
    )
  }
  phase19_club_evaluation_capture(
    phase19_validate_club_calibrated_view_source(
      calibrated_view, calibrator, calibration_input, calibration_fold,
      require_production = TRUE
    ), "evaluation_source_invalid"
  )
  calibration_outcomes <- phase19_club_evaluation_calibration_outcomes(
    outcomes, calibration_input
  )
  phase19_club_evaluation_capture(
    phase19_validate_club_calibration_decision_source(
      calibration_evidence, calibration_decision, calibrated_view,
      calibration_outcomes, calibration_fold, protocol
    ), "evaluation_source_invalid"
  )
  list(
    fit = fit, calibrator = calibrator, calibrated_view = calibrated_view,
    calibration_evidence = calibration_evidence,
    calibration_decision = calibration_decision
  )
}

phase19_validate_club_fold_source_artifacts <- function(source, fold, protocol,
                                                        outcomes) {
  artifacts <- lapply(c("candidate", "incumbent"), function(label) {
    phase19_club_evaluation_source_artifacts(
      source, label, fold, protocol, outcomes
    )
  })
  names(artifacts) <- c("candidate", "incumbent")
  expected <- data.frame(
    model_id = c(artifacts$incumbent$fit$model_id,
                 artifacts$candidate$fit$model_id),
    fit_status = "converged", fallback_status = c(
      artifacts$incumbent$fit$fallback_status,
      artifacts$candidate$fit$fallback_status
    ), fit_sha256 = c(
      artifacts$incumbent$fit$fit_sha256, artifacts$candidate$fit$fit_sha256
    ), calibrator_status = "fitted",
    primary_probability_view = c(
      artifacts$incumbent$calibration_decision$primary_probability_view,
      artifacts$candidate$calibration_decision$primary_probability_view
    ), calibrator_sha256 = c(
      artifacts$incumbent$calibrator$calibrator_sha256,
      artifacts$candidate$calibrator$calibrator_sha256
    ), calibration_evidence_sha256 = c(
      artifacts$incumbent$calibration_evidence$evidence_sha256,
      artifacts$candidate$calibration_evidence$evidence_sha256
    ), calibration_decision_sha256 = c(
      artifacts$incumbent$calibration_decision$decision_sha256,
      artifacts$candidate$calibration_decision$decision_sha256
    ), stringsAsFactors = FALSE, check.names = FALSE
  )
  expected <- expected[order(expected$model_id, method = "radix"), , drop = FALSE]
  observed <- source$model_support
  if (!is.data.frame(observed) || !identical(names(observed), names(expected)) ||
      nrow(observed) != nrow(expected)) {
    phase19_club_evaluation_abort(
      "evaluation_model_support_invalid",
      "Production model support must bind typed fit, calibrator, evidence, and decision artifacts"
    )
  }
  observed <- observed[match(expected$model_id, observed$model_id), , drop = FALSE]
  rownames(observed) <- NULL
  rownames(expected) <- NULL
  if (!identical(observed, expected)) {
    phase19_club_evaluation_abort(
      "evaluation_model_support_invalid",
      "Production model support contains an opaque or mismatched artifact identity"
    )
  }
  artifacts
}

phase19_validate_club_fold_source_evidence <- function(evidence, source,
                                                       accepted_fold = NULL,
                                                       accepted_protocol = NULL) {
  production_source <- (
    !is.null(accepted_protocol) &&
      identical(as.character(accepted_protocol$authority_mode), "production")
  ) || (
    is.list(source) && !is.null(source$protocol) &&
      identical(as.character(source$protocol$authority_mode), "production")
  )
  expected_schema <- if (production_source) {
    phase19_club_production_fold_source_evidence_schema()
  } else phase19_club_fold_source_evidence_schema()
  if (!is.list(source) || !identical(names(source), expected_schema)) {
    phase19_club_evaluation_abort(
      "evaluation_source_invalid",
      "Production fold source evidence must include exact predictions, labels, fold, protocol, and support objects"
    )
  }
  if (!identical(as.character(source$fold$fold_id), as.character(evidence$fold_id)) ||
      !inherits(source$protocol, "phase19_club_evaluation_protocol")) {
    phase19_club_evaluation_abort(
      "evaluation_source_invalid", "Production fold source evidence is bound to another fold or protocol"
    )
  }
  if (!is.null(accepted_fold)) {
    if (!is.data.frame(accepted_fold) || nrow(accepted_fold) != 1L ||
        !identical(names(accepted_fold), phase19_fold_registry_schema())) {
      phase19_club_evaluation_abort(
        "evaluation_source_invalid", "Accepted fold identity is not one exact registry row"
      )
    }
    observed_fold <- source$fold
    rownames(observed_fold) <- NULL
    rownames(accepted_fold) <- NULL
    if (!identical(observed_fold, accepted_fold)) {
      phase19_club_evaluation_abort(
        "evaluation_source_invalid",
        "Production fold source evidence differs from the accepted registry row"
      )
    }
  }
  if (!is.null(accepted_protocol) && !identical(source$protocol, accepted_protocol)) {
    phase19_club_evaluation_abort(
      "evaluation_source_invalid",
      "Production fold source evidence uses a protocol other than the accepted protocol"
    )
  }
  if (production_source) {
    phase19_validate_club_fold_source_artifacts(
      source, source$fold, source$protocol, source$outcomes
    )
  }
  phase19_validate_club_fold_evaluation(
    evidence, source$candidate_predictions, source$incumbent_predictions,
    source$outcomes, source$fold, source$protocol,
    source$model_support, source$role_provenance
  )
  invisible(source)
}

phase19_club_evaluation_source_by_fold <- function(source_evidence, evaluations,
                                                   protocol,
                                                   accepted_fold_registry = NULL,
                                                   accepted_protocol = NULL) {
  if (!identical(protocol$authority_mode, "production")) return(NULL)
  fold_ids <- vapply(evaluations, `[[`, character(1), "fold_id")
  if (!is.list(source_evidence) || is.null(names(source_evidence)) ||
      anyDuplicated(names(source_evidence)) || anyDuplicated(fold_ids) ||
      !setequal(names(source_evidence), fold_ids)) {
    phase19_club_evaluation_abort(
      "evaluation_source_invalid",
      "Production evaluation requires one exact source-evidence bundle per registered fold"
    )
  }
  if (!is.data.frame(accepted_fold_registry) ||
      !identical(names(accepted_fold_registry), phase19_fold_registry_schema()) ||
      anyDuplicated(as.character(accepted_fold_registry$fold_id)) ||
      is.null(accepted_protocol) ||
      !inherits(accepted_protocol, "phase19_club_evaluation_protocol")) {
    phase19_club_evaluation_abort(
      "evaluation_source_invalid",
      "Production evaluation requires the accepted fold registry and protocol identity"
    )
  }
  accepted_ids <- as.character(accepted_fold_registry$fold_id)
  if (!identical(sort(names(source_evidence), method = "radix"),
                 sort(accepted_ids, method = "radix")) ||
      !identical(sort(fold_ids, method = "radix"), sort(accepted_ids, method = "radix"))) {
    phase19_club_evaluation_abort(
      "evaluation_source_invalid",
      "Production source fold names do not cover the accepted registry exactly"
    )
  }
  resolved <- source_evidence[fold_ids]
  for (index in seq_along(evaluations)) {
    accepted_fold <- accepted_fold_registry[
      accepted_fold_registry$fold_id == fold_ids[[index]], , drop = FALSE
    ]
    phase19_validate_club_fold_source_evidence(
      evaluations[[index]], resolved[[index]], accepted_fold, accepted_protocol
    )
  }
  resolved
}

phase19_club_evaluation_list_identity <- function(evaluations, source_evidence = NULL,
                                                  protocol = NULL,
                                                  accepted_fold_registry = NULL,
                                                  accepted_protocol = NULL) {
  if (!is.list(evaluations) || length(evaluations) < 2L) {
    phase19_club_evaluation_abort(
      "evaluation_set_invalid", "Evaluation set requires multiple canonical folds"
    )
  }
  source_by_fold <- if (!is.null(protocol)) {
    phase19_club_evaluation_source_by_fold(
      source_evidence, evaluations, protocol,
      accepted_fold_registry, accepted_protocol
    )
  } else NULL
  invisible(lapply(seq_along(evaluations), function(index) {
    phase19_club_evaluation_fold_self_check(evaluations[[index]])
    if (!is.null(source_by_fold)) {
      phase19_validate_club_fold_source_evidence(
        evaluations[[index]], source_by_fold[[evaluations[[index]]$fold_id]]
      )
    }
  }))
  fold_ids <- vapply(evaluations, `[[`, character(1), "fold_id")
  if (anyDuplicated(fold_ids)) {
    phase19_club_evaluation_abort(
      "evaluation_set_invalid", "Evaluation set contains duplicate fold IDs"
    )
  }
  ordering <- order(fold_ids, method = "radix")
  evaluations <- evaluations[ordering]
  fold_ids <- fold_ids[ordering]
  phase19_club_evaluation_hash_values(
    as.list(vapply(evaluations, `[[`, character(1), "evaluation_sha256")) |>
      setNames(paste0("fold_", fold_ids)),
    "phase19-club-evaluation-set-members-v1"
  )
}

phase19_club_evaluation_bootstrap <- function(deltas, seed, reps = 10000L) {
  if (!is.numeric(deltas) || length(deltas) < 2L || any(!is.finite(deltas)) ||
      as.integer(reps) != 10000L || length(seed) != 1L || is.na(seed)) {
    phase19_club_evaluation_abort(
      "evaluation_bootstrap_invalid", "Paired fold bootstrap inputs are invalid"
    )
  }
  old_kind <- RNGkind()
  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (had_seed) old_seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  on.exit(do.call(RNGkind, as.list(old_kind)), add = TRUE)
  on.exit({
    if (had_seed) {
      assign(".Random.seed", old_seed, envir = .GlobalEnv)
    } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".Random.seed", envir = .GlobalEnv)
    }
  }, add = TRUE)
  set.seed(as.integer(seed), kind = "L'Ecuyer-CMRG")
  draws <- replicate(as.integer(reps), mean(sample(deltas, length(deltas), replace = TRUE)))
  interval <- stats::quantile(draws, c(0.025, 0.975), names = FALSE, type = 8L)
  data.frame(
    estimate = mean(deltas), lower = interval[[1L]], upper = interval[[2L]],
    replicates = as.integer(reps), seed = as.integer(seed),
    resampling_unit = "fold", quantile_type = 8L,
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

phase19_club_evaluation_metric_names <- function() {
  phase19_expected_gate_policy()$gate_id
}

phase19_club_evaluation_metrics_sha256 <- function(metrics) {
  names_expected <- phase19_club_evaluation_metric_names()
  if (!is.list(metrics) || !identical(names(metrics), names_expected) ||
      any(lengths(metrics) != 1L)) {
    phase19_club_evaluation_abort(
      "evaluation_metrics_invalid", "Evaluation metrics do not match the frozen gate inventory"
    )
  }
  phase19_club_evaluation_hash_values(
    metrics, "phase19-club-evaluation-metrics-v1"
  )
}

phase19_club_evaluation_set_schema <- function() {
  c(
    "schema_version", "hash_encoding_version", "forecast_domain",
    "authority_mode", "fixture_authority", "production_eligible",
    "candidate_id", "incumbent_id", "fold_count", "evaluation_member_sha256",
    "protocol_sha256", "policy_review_sha256", "gate_registry_sha256",
    "seed_registry_sha256", "fold_summaries_sha256", "family_summaries_sha256",
    "league_season_summaries_sha256", "paired_bootstrap_sha256",
    "metrics_sha256", "fold_evaluations", "fold_summaries", "family_summaries",
    "league_season_summaries", "paired_bootstrap", "metrics",
    "evaluation_set_sha256"
  )
}

phase19_club_evaluation_set_sha256 <- function(evidence) {
  schema <- phase19_club_evaluation_set_schema()
  if (!is.list(evidence) || !identical(names(evidence), schema)) {
    phase19_club_evaluation_abort(
      "evaluation_set_schema_invalid", "Club evaluation set schema is not exact"
    )
  }
  fields <- schema[seq_len(match("metrics_sha256", schema))]
  phase19_club_evaluation_hash_values(
    evidence[fields], "phase19-club-evaluation-set-v1"
  )
}

phase19_club_evaluation_complete_output_sha256 <- function(evidence) {
  schema <- phase19_club_evaluation_set_schema()
  if (!inherits(evidence, "phase19_club_evaluation_set") ||
      !is.list(evidence) || !identical(names(evidence), schema) ||
      !identical(evidence$evaluation_set_sha256,
                 phase19_club_evaluation_set_sha256(evidence))) {
    phase19_club_evaluation_abort(
      "evaluation_set_hash_mismatch",
      "Complete-output hashing requires one exact typed evaluation set"
    )
  }
  # Re-run every fold's complete typed self-check before deriving the
  # reproducibility identity.  Fold-level scalar hashes alone are not a
  # sufficient authority claim for a caller-provided shell object.
  fold_hashes <- vapply(evidence$fold_evaluations, function(fold) {
    phase19_club_evaluation_fold_self_check(fold)
    fields <- phase19_club_fold_evaluation_schema()[seq_len(
      match("fold_summary_sha256", phase19_club_fold_evaluation_schema())
    )]
    phase19_club_evaluation_hash_values(
      fold[fields], "phase19-club-complete-fold-output-v1"
    )
  }, character(1))
  fold_hashes <- as.list(fold_hashes) |>
    setNames(paste0("fold_", vapply(evidence$fold_evaluations, `[[`,
                                    character(1), "fold_id")))
  nested <- list(
    fold_evaluations_sha256 = phase19_club_evaluation_hash_values(
      fold_hashes, "phase19-club-complete-fold-members-v1"
    ),
    fold_summaries_sha256 = as.character(evidence$fold_summaries_sha256),
    family_summaries_sha256 = as.character(evidence$family_summaries_sha256),
    league_season_summaries_sha256 = as.character(evidence$league_season_summaries_sha256),
    paired_bootstrap_sha256 = as.character(evidence$paired_bootstrap_sha256),
    metrics_sha256 = as.character(evidence$metrics_sha256),
    evaluation_set_sha256 = as.character(evidence$evaluation_set_sha256)
  )
  phase19_club_evaluation_hash_values(
    nested, "phase19-club-complete-evaluation-output-v1"
  )
}

phase19_club_evaluation_metrics_from_summaries <- function(fold_summaries,
                                                           paired_bootstrap) {
  families <- c("rolling_origin_league_season", "heldout_league_transport")
  relative <- function(candidate, incumbent) {
    ifelse(incumbent == 0, ifelse(candidate <= incumbent, 0, Inf),
           candidate / incumbent - 1)
  }
  equal_family <- function(values) {
    mean(vapply(families, function(family) {
      mean(values[fold_summaries$fold_family == family])
    }, numeric(1)))
  }
  values <- as.list(rep(NA_real_, length(phase19_club_evaluation_metric_names())))
  names(values) <- phase19_club_evaluation_metric_names()
  values$equal_fold_rps_delta <- equal_family(fold_summaries$rps_delta)
  values$paired_rps_ci_upper <- paired_bootstrap$upper[[1L]]
  values$rolling_origin_fold_breadth <- mean(
    fold_summaries$rps_delta[
      fold_summaries$fold_family == "rolling_origin_league_season"
    ] < 0
  )
  values$heldout_league_fold_breadth <- mean(
    fold_summaries$rps_delta[
      fold_summaries$fold_family == "heldout_league_transport"
    ] < 0
  )
  values$worst_fold_rps_regression <- max(c(0, fold_summaries$rps_delta))
  values$equal_fold_brier_relative_regression <- equal_family(relative(
    fold_summaries$candidate_brier, fold_summaries$incumbent_brier
  ))
  values$equal_fold_log_loss_relative_regression <- equal_family(relative(
    fold_summaries$candidate_log_loss, fold_summaries$incumbent_log_loss
  ))
  values$fixed_bin_calibration_delta <- equal_family(
    fold_summaries$candidate_calibration_error -
      fold_summaries$incumbent_calibration_error
  )
  values$declared_fixture_coverage <- 1
  values$full_score_grid_coverage <- 1
  values
}

#' Aggregate validated club folds before applying promotion rules.
#'
#' @export
phase19_aggregate_club_evaluations <- function(evaluations, protocol,
                                               source_evidence = NULL,
                                               accepted_fold_protocol = NULL) {
  phase19_club_evaluation_require_dependencies()
  if (!inherits(protocol, "phase19_club_evaluation_protocol") ||
      !identical(protocol$status, "ready") || !identical(protocol$forecast_domain, "club")) {
    phase19_club_evaluation_abort(
      "evaluation_protocol_invalid", "Aggregation requires one ready club protocol"
    )
  }
  phase19_validate_gate_registry(protocol$gate_registry)
  member_hash <- phase19_club_evaluation_list_identity(
    evaluations, source_evidence, protocol,
    if (is.null(accepted_fold_protocol)) NULL else accepted_fold_protocol$fold_registry,
    if (is.null(accepted_fold_protocol)) NULL else accepted_fold_protocol$protocol
  )
  families <- vapply(evaluations, `[[`, character(1), "fold_family")
  required_families <- c("rolling_origin_league_season", "heldout_league_transport")
  if (!setequal(unique(families), required_families) ||
      any(vapply(evaluations, `[[`, character(1), "authority_mode") !=
            protocol$authority_mode) ||
      any(vapply(evaluations, `[[`, character(1), "protocol_sha256") !=
            protocol$protocol_sha256) ||
      any(vapply(evaluations, `[[`, character(1), "policy_review_sha256") !=
            protocol$policy_review$review_sha256)) {
    phase19_club_evaluation_abort(
      "evaluation_set_invalid", "Evaluation folds omit a family or mix authority parents"
    )
  }
  fold_summaries <- do.call(rbind, lapply(evaluations, `[[`, "fold_summary"))
  fold_summaries <- fold_summaries[order(fold_summaries$fold_id, method = "radix"), , drop = FALSE]
  rownames(fold_summaries) <- NULL
  family_summaries <- do.call(rbind, lapply(required_families, function(family) {
    rows <- fold_summaries[fold_summaries$fold_family == family, , drop = FALSE]
    data.frame(
      fold_family = family, fold_count = as.integer(nrow(rows)),
      candidate_rps = mean(rows$candidate_rps), incumbent_rps = mean(rows$incumbent_rps),
      rps_delta = mean(rows$rps_delta), improved_fold_fraction = mean(rows$rps_delta < 0),
      maximum_fold_regression = max(c(0, rows$rps_delta)),
      candidate_brier = mean(rows$candidate_brier),
      incumbent_brier = mean(rows$incumbent_brier),
      candidate_log_loss = mean(rows$candidate_log_loss),
      incumbent_log_loss = mean(rows$incumbent_log_loss),
      candidate_calibration_error = mean(rows$candidate_calibration_error),
      incumbent_calibration_error = mean(rows$incumbent_calibration_error),
      stringsAsFactors = FALSE, check.names = FALSE
    )
  }))
  league_season <- fold_summaries[, c(
    "fold_id", "fold_family", "competition_id", "season_id", "fixture_count",
    "candidate_rps", "incumbent_rps", "rps_delta", "candidate_brier",
    "incumbent_brier", "candidate_log_loss", "incumbent_log_loss",
    "candidate_calibration_error", "incumbent_calibration_error"
  ), drop = FALSE]
  seed <- phase19_club_evaluation_seed(protocol, "club_paired_bootstrap_v1")
  bootstrap <- phase19_club_evaluation_bootstrap(
    fold_summaries$rps_delta, seed$seed[[1L]]
  )
  metrics <- phase19_club_evaluation_metrics_from_summaries(
    fold_summaries, bootstrap
  )
  fold_hash <- phase18_hash_table_v2(
    fold_summaries, key = "fold_id",
    schema_tag = "phase19-club-evaluation-set-folds-v1"
  )
  family_hash <- phase18_hash_table_v2(
    family_summaries, key = "fold_family",
    schema_tag = "phase19-club-evaluation-set-families-v1"
  )
  league_hash <- phase18_hash_table_v2(
    league_season, key = "fold_id",
    schema_tag = "phase19-club-evaluation-set-league-season-v1"
  )
  bootstrap_hash <- phase18_hash_table_v2(
    bootstrap, key = "seed",
    schema_tag = "phase19-club-evaluation-set-bootstrap-v1"
  )
  result <- list(
    schema_version = "phase19-club-evaluation-set-v1",
    hash_encoding_version = phase18_canonical_encoding_v2(),
    forecast_domain = "club", authority_mode = protocol$authority_mode,
    fixture_authority = isTRUE(protocol$fixture_authority),
    production_eligible = identical(protocol$authority_mode, "production") &&
      isTRUE(protocol$production_eligible),
    candidate_id = "club_elo_nb", incumbent_id = "club_venue_nb",
    fold_count = as.integer(length(evaluations)),
    evaluation_member_sha256 = member_hash,
    protocol_sha256 = protocol$protocol_sha256,
    policy_review_sha256 = protocol$policy_review$review_sha256,
    gate_registry_sha256 = protocol$gate_registry_sha256,
    seed_registry_sha256 = protocol$seed_registry_sha256,
    fold_summaries_sha256 = fold_hash, family_summaries_sha256 = family_hash,
    league_season_summaries_sha256 = league_hash,
    paired_bootstrap_sha256 = bootstrap_hash,
    metrics_sha256 = phase19_club_evaluation_metrics_sha256(metrics),
    fold_evaluations = evaluations, fold_summaries = fold_summaries,
    family_summaries = family_summaries,
    league_season_summaries = league_season,
    paired_bootstrap = bootstrap, metrics = metrics,
    evaluation_set_sha256 = ""
  )
  result$evaluation_set_sha256 <- phase19_club_evaluation_set_sha256(result)
  result <- structure(result, class = c("phase19_club_evaluation_set", "list"))
  assign(
    phase19_club_evaluation_cache_key(result, "set"), TRUE,
    envir = .phase19_club_evaluation_validation_cache
  )
  result
}

phase19_validate_club_evaluation_set <- function(evidence, protocol,
                                                 source_evidence = NULL,
                                                 accepted_fold_protocol = NULL) {
  if (!inherits(protocol, "phase19_club_evaluation_protocol") ||
      !identical(protocol$status, "ready")) {
    phase19_club_evaluation_abort(
      "evaluation_protocol_invalid", "Evaluation-set validation requires one ready protocol"
    )
  }
  if (identical(protocol$authority_mode, "production")) {
    if (!inherits(accepted_fold_protocol, "phase19_club_fold_protocol") ||
        !identical(accepted_fold_protocol$authority_mode, "production") ||
        !isTRUE(accepted_fold_protocol$production_eligible) ||
        !inherits(accepted_fold_protocol$protocol, "phase19_club_evaluation_protocol") ||
        !identical(accepted_fold_protocol$protocol, protocol)) {
      phase19_club_evaluation_abort(
        "evaluation_source_invalid",
        "Production evaluation requires the accepted fold protocol identity"
      )
    }
    phase19_club_evaluation_source_by_fold(
      source_evidence, evidence$fold_evaluations, protocol,
      accepted_fold_protocol$fold_registry, accepted_fold_protocol$protocol
    )
  }
  cache_key <- phase19_club_evaluation_cache_key(evidence, "set")
  if (exists(cache_key, envir = .phase19_club_evaluation_validation_cache,
             inherits = FALSE)) {
    if (!identical(evidence$protocol_sha256, protocol$protocol_sha256) ||
        !identical(evidence$policy_review_sha256,
                   protocol$policy_review$review_sha256)) {
      phase19_club_evaluation_abort(
        "evaluation_set_source_mismatch", "Cached evaluation parents differ from protocol"
      )
    }
    if (identical(protocol$authority_mode, "production")) {
      # A cached aggregate is only a performance optimization. Re-run the
      # exact fold-source replay on every production validation so a caller
      # cannot satisfy the gate with a correctly named but unrelated source
      # bundle.
      phase19_club_evaluation_list_identity(
        evidence$fold_evaluations, source_evidence, protocol,
        accepted_fold_protocol$fold_registry, accepted_fold_protocol$protocol
      )
    }
    return(invisible(evidence))
  }
  if (!inherits(evidence, "phase19_club_evaluation_set") ||
      !identical(names(evidence), phase19_club_evaluation_set_schema()) ||
      !identical(evidence$evaluation_set_sha256,
                 phase19_club_evaluation_set_sha256(evidence))) {
    phase19_club_evaluation_abort(
      "evaluation_set_hash_mismatch", "Club evaluation-set identity drifted"
    )
  }
  expected <- phase19_aggregate_club_evaluations(
    evidence$fold_evaluations, protocol, source_evidence,
    accepted_fold_protocol
  )
  if (!identical(evidence$evaluation_set_sha256, expected$evaluation_set_sha256)) {
    phase19_club_evaluation_abort(
      "evaluation_set_source_mismatch", "Evaluation set does not derive from its exact folds"
    )
  }
  assign(cache_key, TRUE, envir = .phase19_club_evaluation_validation_cache)
  invisible(evidence)
}

phase19_club_reproducibility_schema <- function() {
  c(
    "schema_version", "hash_encoding_version", "forecast_domain", "seed_id",
    "seed", "first_evaluation_sha256", "second_evaluation_sha256",
    "reproducible", "evidence_sha256"
  )
}

phase19_club_reproducibility_sha256 <- function(evidence) {
  if (!is.list(evidence) || !identical(names(evidence),
                                       phase19_club_reproducibility_schema())) {
    phase19_club_evaluation_abort(
      "reproducibility_schema_invalid", "Reproducibility evidence schema is not exact"
    )
  }
  phase19_club_evaluation_hash_values(
    evidence[setdiff(names(evidence), "evidence_sha256")],
    "phase19-club-evaluation-reproducibility-v1"
  )
}

phase19_club_evaluation_identity <- function(value, protocol = NULL,
                                             source_evidence = NULL,
                                             accepted_fold_protocol = NULL) {
  if (inherits(value, "phase19_club_evaluation_set")) {
    if (is.null(protocol)) {
      phase19_club_evaluation_abort(
        "evaluation_source_invalid",
        "Typed evaluation-set identity requires its validating protocol"
      )
    }
    phase19_validate_club_evaluation_set(
      value, protocol, source_evidence, accepted_fold_protocol
    )
    return(phase19_club_evaluation_complete_output_sha256(value))
  }
  phase19_club_evaluation_list_identity(value)
}

#' Build typed reproducibility evidence after the caller has selected an
#' authority mode.  Production callers must use the fixed-source wrapper
#' below; this internal escape hatch is deliberately not exported.
phase19_club_reproducibility_evidence_build <- function(
    first, second, protocol, accepted_evaluation = NULL,
    source_evidence = NULL, accepted_fold_protocol = NULL,
    allow_production = FALSE
) {
  seed <- phase19_club_evaluation_seed(protocol, "club_isolated_replay_v1")
  accepted_hash <- NULL
  if (identical(protocol$authority_mode, "production")) {
    if (!isTRUE(allow_production)) {
      phase19_club_evaluation_abort(
        "reproducibility_source_invalid",
        "Production reproducibility requires the fixed-source production wrapper"
      )
    }
    if (is.null(accepted_evaluation) || is.null(source_evidence) ||
        is.null(accepted_fold_protocol)) {
      phase19_club_evaluation_abort(
        "reproducibility_evidence_invalid",
        "Production reproducibility requires the accepted typed evaluation and source graph"
      )
    }
    accepted_hash <- phase19_club_evaluation_identity(
      accepted_evaluation, protocol, source_evidence, accepted_fold_protocol
    )
  }
  first_hash <- phase19_club_evaluation_identity(
    first, protocol, source_evidence, accepted_fold_protocol
  )
  second_hash <- phase19_club_evaluation_identity(
    second, protocol, source_evidence, accepted_fold_protocol
  )
  if (!is.null(accepted_hash) &&
      (!identical(first_hash, accepted_hash) || !identical(second_hash, accepted_hash))) {
    phase19_club_evaluation_abort(
      "reproducibility_source_mismatch",
      "Controlled production evaluations do not match the accepted evaluation-set identity"
    )
  }
  result <- list(
    schema_version = "phase19-club-evaluation-reproducibility-v1",
    hash_encoding_version = phase18_canonical_encoding_v2(), forecast_domain = "club",
    seed_id = as.character(seed$seed_id[[1L]]), seed = as.integer(seed$seed[[1L]]),
    first_evaluation_sha256 = first_hash, second_evaluation_sha256 = second_hash,
    reproducible = identical(first_hash, second_hash) &&
      (is.null(accepted_hash) || identical(first_hash, accepted_hash)), evidence_sha256 = ""
  )
  result$evidence_sha256 <- phase19_club_reproducibility_sha256(result)
  classes <- c("phase19_club_reproducibility_evidence", "list")
  if (isTRUE(allow_production) && identical(protocol$authority_mode, "production")) {
    classes <- c("phase19_club_production_reproducibility_evidence", classes)
  }
  structure(result, class = classes)
}

#' Compare two isolated fixture club evaluation executions canonically.
#'
#' Production callers must use phase19_production_club_reproducibility_evidence,
#' which resolves the fixed source graph and performs both controlled runs.
#' @export
phase19_club_reproducibility_evidence <- function(
    first, second, protocol, accepted_evaluation = NULL,
    source_evidence = NULL, accepted_fold_protocol = NULL
) {
  if (identical(protocol$authority_mode, "production")) {
    phase19_club_evaluation_abort(
      "reproducibility_source_invalid",
      "Production reproducibility requires the fixed-source production wrapper"
    )
  }
  phase19_club_reproducibility_evidence_build(
    first, second, protocol, accepted_evaluation,
    source_evidence, accepted_fold_protocol, allow_production = FALSE
  )
}

#' Run two isolated production evaluations from the fixed accepted source graph.
#'
#' The caller may provide the typed authority graph, but production source
#' identity is resolved again from the committed loaders before either run.
#' Each run receives an independent deep copy of the typed fold source rows;
#' no caller-supplied hash shell or replay claim is used as evidence.
phase19_production_club_reproducibility_evidence <- function(
    evaluation, source_authority
) {
  required <- c(
    "history_snapshot", "current_snapshot", "protocol", "evaluation",
    "authority", "fold_protocol", "rating_replay", "integrity", "decision",
    "fold_source_evidence"
  )
  if (!is.list(source_authority) || !identical(names(source_authority), required)) {
    phase19_club_evaluation_abort(
      "reproducibility_source_invalid",
      "Production reproducibility requires the complete typed source graph"
    )
  }
  if (!inherits(source_authority$evaluation, "phase19_club_evaluation_set") ||
      !inherits(source_authority$authority, "phase19_club_evaluation_authority") ||
      !inherits(source_authority$integrity, "phase19_club_integrity_evidence") ||
      (!is.null(source_authority$decision) &&
       !inherits(source_authority$decision, "phase19_club_promotion_decision"))) {
    phase19_club_evaluation_abort(
      "reproducibility_source_invalid",
      "Production reproducibility requires one complete typed promotion graph"
    )
  }
  if (!identical(source_authority$evaluation, evaluation)) {
    phase19_club_evaluation_abort(
      "reproducibility_source_invalid",
      "Production reproducibility evaluation identity drifted"
    )
  }
  fixed <- phase19_load_fixed_club_production_authority()
  if (!identical(source_authority$history_snapshot, fixed$history_snapshot) ||
      !identical(source_authority$current_snapshot, fixed$current_snapshot) ||
      !identical(source_authority$protocol, fixed$protocol) ||
      !identical(source_authority$fold_protocol, fixed$fold_protocol) ||
      !identical(source_authority$protocol, source_authority$fold_protocol$protocol)) {
    phase19_club_evaluation_abort(
      "reproducibility_source_invalid",
      "Production reproducibility rejects caller-owned snapshot, policy, fold, or evaluation identities"
    )
  }
  phase19_validate_club_rating_replay(
    source_authority$rating_replay, fixed$history_snapshot,
    current_snapshot = fixed$current_snapshot,
    parameters = source_authority$rating_replay$parameters,
    cutoff_utc = source_authority$rating_replay$cutoff_utc
  )
  phase19_club_validate_authority(
    source_authority$authority, evaluation, fixed$protocol,
    source_authority$fold_source_evidence
  )
  phase19_validate_club_evaluation_set(
    evaluation, fixed$protocol, source_authority$fold_source_evidence,
    fixed$fold_protocol
  )
  replay_once <- function() {
    isolated <- unserialize(serialize(
      source_authority$fold_source_evidence, NULL, version = 3L
    ))
    folds <- lapply(evaluation$fold_evaluations, function(accepted) {
      source <- isolated[[as.character(accepted$fold_id)]]
      phase19_score_club_fold(
        source$candidate_predictions, source$incumbent_predictions,
        source$outcomes, source$fold, source$protocol,
        source$model_support, source$role_provenance
      )
    })
    phase19_aggregate_club_evaluations(
      folds, fixed$protocol, isolated, fixed$fold_protocol
    )
  }
  first <- replay_once()
  second <- replay_once()
  phase19_club_reproducibility_evidence_build(
    first, second, fixed$protocol, accepted_evaluation = evaluation,
    source_evidence = source_authority$fold_source_evidence,
    accepted_fold_protocol = fixed$fold_protocol, allow_production = TRUE
  )
}

phase19_club_production_promotion_source_authority <- function(
    evaluation, protocol, integrity, authority, source_evidence,
    production_source_authority = NULL
) {
  required <- c(
    "history_snapshot", "current_snapshot", "protocol", "evaluation",
    "authority", "fold_protocol", "rating_replay", "integrity", "decision",
    "fold_source_evidence"
  )
  if (!is.null(production_source_authority)) {
    if (!is.list(production_source_authority) ||
        !identical(names(production_source_authority), required) ||
        !identical(production_source_authority$protocol, protocol) ||
        !identical(production_source_authority$evaluation, evaluation) ||
        !identical(production_source_authority$authority, authority) ||
        !identical(production_source_authority$integrity, integrity) ||
        !identical(production_source_authority$fold_source_evidence, source_evidence)) {
      phase19_club_evaluation_abort(
        "reproducibility_source_invalid",
        "Production promotion source graph is not bound to the accepted promotion inputs"
      )
    }
    return(production_source_authority)
  }
  if (!inherits(authority, "phase19_club_evaluation_authority") ||
      !is.list(authority$source_evidence) ||
      !identical(
        names(authority$source_evidence),
        phase19_club_production_source_schema()
      )) {
    phase19_club_evaluation_abort(
      "reproducibility_source_invalid",
      "Production promotion requires the complete typed source graph"
    )
  }
  roots <- authority$source_evidence
  list(
    history_snapshot = roots$history_snapshot,
    current_snapshot = roots$current_snapshot,
    protocol = protocol,
    evaluation = evaluation,
    authority = authority,
    fold_protocol = roots$fold_protocol,
    rating_replay = roots$rating_replay,
    integrity = integrity,
    decision = NULL,
    fold_source_evidence = source_evidence
  )
}

phase19_club_authority_schema <- function() {
  c(
    "schema_version", "hash_encoding_version", "forecast_domain", "authority_mode",
    "fixture_authority", "status", "reason_code", "production_eligible",
    "history_snapshot_sha256", "current_snapshot_sha256", "protocol_sha256",
    "policy_review_sha256", "fold_registry_sha256", "fold_review_sha256",
    "current_ucl_club_coverage", "common_component_coverage",
    "evaluation_set_sha256", "source_evidence", "authority_sha256"
  )
}

phase19_club_authority_sha256 <- function(authority) {
  if (!is.list(authority) || !identical(names(authority), phase19_club_authority_schema())) {
    phase19_club_evaluation_abort(
      "evaluation_authority_invalid", "Evaluation authority schema is not exact"
    )
  }
  phase19_club_evaluation_hash_values(
    authority[setdiff(names(authority), c("source_evidence", "authority_sha256"))],
    "phase19-club-evaluation-authority-v1"
  )
}

phase19_club_production_source_schema <- function() {
  c("history_snapshot", "current_snapshot", "fold_protocol", "rating_replay")
}

phase19_load_fixed_club_production_authority <- function(...) {
  phase19_reject_arbitrary_arguments(list(...))
  history <- phase19_load_club_training_snapshot()
  if (!identical(history$status, "ready")) {
    phase19_club_evaluation_abort(
      "evaluation_authority_invalid",
      "Fixed production authority has no accepted Phase 18 club history"
    )
  }
  current <- phase19_load_current_ucl_club_snapshot()
  if (!identical(current$status, "ready")) {
    phase19_club_evaluation_abort(
      "evaluation_authority_invalid",
      "Fixed production authority has no accepted current-UCL club snapshot"
    )
  }
  protocol <- phase19_load_club_evaluation_protocol()
  if (!identical(protocol$status, "ready")) {
    phase19_club_evaluation_abort(
      "evaluation_authority_invalid",
      "Fixed production authority has no accepted club policy review"
    )
  }
  folds <- phase19_load_club_fold_protocol()
  phase19_assert_production_fold_protocol(folds)
  list(
    history_snapshot = history, current_snapshot = current,
    protocol = protocol, fold_protocol = folds
  )
}

phase19_validate_fixed_club_production_authority <- function(source_evidence) {
  fixed <- phase19_load_fixed_club_production_authority()
  fields <- c("history_snapshot", "current_snapshot", "protocol", "fold_protocol")
  if (!is.list(source_evidence) ||
      any(!vapply(fields, function(field) {
        identical(source_evidence[[field]], fixed[[field]])
      }, logical(1)))) {
    phase19_club_evaluation_abort(
      "evaluation_authority_invalid",
      "Production authority must use the exact fixed-root snapshot, policy, and fold identities"
    )
  }
  fixed
}

phase19_club_validate_production_sources <- function(source_evidence, evaluation,
                                                     protocol,
                                                     fold_source_evidence = NULL) {
  if (!is.list(source_evidence) ||
      !identical(names(source_evidence), phase19_club_production_source_schema())) {
    phase19_club_evaluation_abort(
      "evaluation_authority_invalid",
      "Production authority requires exact accepted source evidence"
    )
  }
  fixed <- phase19_validate_fixed_club_production_authority(source_evidence)
  if (!identical(protocol, fixed$protocol)) {
    phase19_club_evaluation_abort(
      "evaluation_authority_invalid",
      "Production evaluation protocol is not the fixed committed policy identity"
    )
  }
  history <- source_evidence$history_snapshot
  current <- source_evidence$current_snapshot
  folds <- source_evidence$fold_protocol
  replay <- source_evidence$rating_replay
  phase19_validate_club_training_snapshot(history, "production")
  phase19_validate_current_ucl_club_snapshot(current, "production")
  phase19_validate_policy_review(protocol$policy_review, protocol, require_accepted = TRUE)
  phase19_assert_production_fold_protocol(folds)
  if (!identical(history, fixed$history_snapshot) ||
      !identical(current, fixed$current_snapshot) ||
      !identical(protocol, fixed$protocol) ||
      !identical(folds, fixed$fold_protocol)) {
    phase19_club_evaluation_abort(
      "evaluation_authority_invalid",
      "Production source graph is not the fixed committed runtime graph"
    )
  }
  accepted_fold_registry <- tryCatch(
    phase19_validate_fold_registry(
      folds$fold_registry, history, protocol, authority_mode = "production"
    ),
    error = function(error) error
  )
  phase19_validate_fold_review(folds$fold_review, folds, require_accepted = TRUE)
  if (inherits(accepted_fold_registry, "error") ||
      !inherits(folds$protocol, "phase19_club_evaluation_protocol") ||
      !identical(folds$protocol, protocol)) {
    phase19_club_evaluation_abort(
      "evaluation_authority_invalid",
      "Production fold protocol is not the exact accepted registry/protocol graph"
    )
  }
  replay_valid <- tryCatch(
    phase19_validate_club_rating_replay(
      replay, history, current_snapshot = current,
      parameters = replay$parameters, cutoff_utc = replay$cutoff_utc
    ),
    error = function(error) error
  )
  expected_audit <- phase19_club_rating_component_audit(history, current, history$matches)
  if (inherits(replay_valid, "error") ||
      !inherits(replay, "phase19_club_rating_replay") ||
      !identical(replay$status, "ready") ||
      !identical(replay$authority_mode, "production") ||
      isTRUE(replay$fixture_authority) || !isTRUE(replay$promotion_eligible) ||
      !isTRUE(replay$component_audit$coverage_passed) ||
      !identical(replay$component_audit, expected_audit) ||
      !identical(replay$training_snapshot_sha256, history$snapshot_sha256) ||
      !identical(replay$current_snapshot_sha256, current$snapshot_sha256) ||
      !identical(folds$snapshot_sha256, history$snapshot_sha256) ||
      !identical(folds$protocol_sha256, protocol$protocol_sha256) ||
      !identical(folds$policy_review_sha256, protocol$policy_review$review_sha256) ||
      !identical(evaluation$authority_mode, "production") ||
      isTRUE(evaluation$fixture_authority) || !isTRUE(evaluation$production_eligible)) {
    phase19_club_evaluation_abort(
      "evaluation_authority_invalid",
      "Production source evidence is blocked, incomplete, or parent-mismatched"
    )
  }
  evaluated_folds <- sort(vapply(
    evaluation$fold_evaluations, `[[`, character(1), "fold_id"
  ), method = "radix")
  registered_folds <- sort(as.character(folds$fold_registry$fold_id), method = "radix")
  if (!identical(evaluated_folds, registered_folds)) {
    phase19_club_evaluation_abort(
      "evaluation_authority_invalid",
      "Production evaluation does not cover the accepted fold inventory"
    )
  }
  phase19_club_evaluation_source_by_fold(
    fold_source_evidence, evaluation$fold_evaluations, protocol,
    folds$fold_registry, folds$protocol
  )
  list(
    history_snapshot_sha256 = as.character(history$snapshot_sha256),
    current_snapshot_sha256 = as.character(current$snapshot_sha256),
    fold_registry_sha256 = as.character(folds$fold_registry_sha256),
    fold_review_sha256 = as.character(folds$fold_review$review_sha256),
    current_ucl_club_coverage = as.numeric(
      1 - replay$component_audit$missing_current_club_count /
        replay$component_audit$current_club_count
    ),
    common_component_coverage = as.numeric(
      replay$component_audit$current_component_count == 1L
    )
  )
}

#' Build explicit permanently ineligible fixture evaluation authority.
#'
#' @export
phase19_fixture_evaluation_authority <- function(evaluation, protocol) {
  phase19_validate_club_evaluation_set(evaluation, protocol)
  if (!identical(protocol$authority_mode, "fixture") ||
      !isTRUE(protocol$fixture_authority) || !isTRUE(evaluation$fixture_authority)) {
    phase19_club_evaluation_abort(
      "evaluation_authority_invalid", "Fixture authority cannot be projected from production inputs"
    )
  }
  result <- list(
    schema_version = "phase19-club-evaluation-authority-v1",
    hash_encoding_version = phase18_canonical_encoding_v2(), forecast_domain = "club",
    authority_mode = "fixture", fixture_authority = TRUE,
    status = "fixture_ineligible", reason_code = "fixture_ineligible",
    production_eligible = FALSE, history_snapshot_sha256 = "",
    current_snapshot_sha256 = "", protocol_sha256 = protocol$protocol_sha256,
    policy_review_sha256 = protocol$policy_review$review_sha256,
    fold_registry_sha256 = "", fold_review_sha256 = "",
    current_ucl_club_coverage = NA_real_, common_component_coverage = NA_real_,
    evaluation_set_sha256 = evaluation$evaluation_set_sha256,
    source_evidence = list(),
    authority_sha256 = ""
  )
  result$authority_sha256 <- phase19_club_authority_sha256(result)
  structure(result, class = c("phase19_club_evaluation_authority", "list"))
}

#' Build production evaluation authority from accepted source objects only.
#'
#' @export
phase19_production_evaluation_authority <- function(
    evaluation, protocol, history_snapshot, current_snapshot,
    fold_protocol, rating_replay, fold_source_evidence = NULL
) {
  fixed <- phase19_load_fixed_club_production_authority()
  if (!identical(protocol, fixed$protocol) ||
      !identical(history_snapshot, fixed$history_snapshot) ||
      !identical(current_snapshot, fixed$current_snapshot) ||
      !identical(fold_protocol, fixed$fold_protocol)) {
    phase19_club_evaluation_abort(
      "evaluation_authority_invalid",
      "Production authority rejects caller-supplied policy, snapshot, or fold objects"
    )
  }
  phase19_validate_club_evaluation_set(
    evaluation, fixed$protocol, fold_source_evidence, fixed$fold_protocol
  )
  if (!inherits(fixed$protocol, "phase19_club_evaluation_protocol") ||
      !identical(fixed$protocol$status, "ready") ||
      !identical(fixed$protocol$authority_mode, "production") ||
      isTRUE(fixed$protocol$fixture_authority) || !isTRUE(fixed$protocol$production_eligible)) {
    phase19_club_evaluation_abort(
      "evaluation_authority_invalid",
      "Production authority requires the ready owner-reviewed protocol"
    )
  }
  sources <- list(
    history_snapshot = fixed$history_snapshot, current_snapshot = fixed$current_snapshot,
    fold_protocol = fixed$fold_protocol, rating_replay = rating_replay
  )
  resolved <- phase19_club_validate_production_sources(
    sources, evaluation, fixed$protocol, fold_source_evidence
  )
  result <- list(
    schema_version = "phase19-club-evaluation-authority-v1",
    hash_encoding_version = phase18_canonical_encoding_v2(), forecast_domain = "club",
    authority_mode = "production", fixture_authority = FALSE,
    status = "ready", reason_code = "", production_eligible = TRUE,
    history_snapshot_sha256 = resolved$history_snapshot_sha256,
    current_snapshot_sha256 = resolved$current_snapshot_sha256,
    protocol_sha256 = fixed$protocol$protocol_sha256,
    policy_review_sha256 = fixed$protocol$policy_review$review_sha256,
    fold_registry_sha256 = resolved$fold_registry_sha256,
    fold_review_sha256 = resolved$fold_review_sha256,
    current_ucl_club_coverage = resolved$current_ucl_club_coverage,
    common_component_coverage = resolved$common_component_coverage,
    evaluation_set_sha256 = evaluation$evaluation_set_sha256,
    source_evidence = sources, authority_sha256 = ""
  )
  result$authority_sha256 <- phase19_club_authority_sha256(result)
  structure(result, class = c("phase19_club_evaluation_authority", "list"))
}

#' Return the first stable missing production prerequisite.
#'
#' This diagnostic helper never creates production authority.
#' @export
phase19_club_production_block_reason <- function(history_status, current_ucl_status,
                                                 policy_status, fold_status) {
  values <- c(history_status, current_ucl_status, policy_status, fold_status)
  if (length(values) != 4L || anyNA(values) || any(!values %in% c("ready", "blocked"))) {
    phase19_club_evaluation_abort(
      "evaluation_authority_invalid", "Production prerequisite states must be ready or blocked"
    )
  }
  reasons <- c(
    "no_accepted_club_history", "no_accepted_current_ucl",
    "protocol_policy_not_approved", "fold_inventory_not_approved"
  )
  failed <- which(values != "ready")
  if (length(failed)) reasons[[failed[[1L]]]] else ""
}

phase19_club_evaluation_gate_value <- function(metrics, gate_id) {
  value <- metrics[[gate_id]]
  if (is.logical(value)) as.numeric(isTRUE(value)) else as.numeric(value)
}

#' Apply the exact immutable gate registry in registry order.
#'
#' @export
phase19_apply_club_promotion_gates <- function(metrics, protocol,
                                               authority_mode = protocol$authority_mode) {
  phase19_validate_gate_registry(protocol$gate_registry)
  phase19_club_evaluation_metrics_sha256(metrics)
  if (!authority_mode %in% c("fixture", "production")) {
    phase19_club_evaluation_abort(
      "evaluation_authority_invalid", "Gate authority mode is invalid"
    )
  }
  registry <- protocol$gate_registry[order(protocol$gate_registry$gate_order), , drop = FALSE]
  result <- lapply(seq_len(nrow(registry)), function(index) {
    gate <- registry[index, , drop = FALSE]
    production_only <- identical(as.character(gate$applicability), "production_release")
    applicable <- !(production_only && identical(authority_mode, "fixture"))
    required <- applicable
    value <- phase19_club_evaluation_gate_value(metrics, gate$gate_id)
    threshold <- as.numeric(gate$threshold)
    operator <- as.character(gate$operator)
    passed <- if (!required) {
      TRUE
    } else if (length(value) != 1L || !is.finite(value)) {
      FALSE
    } else switch(
      operator,
      "<=" = value <= threshold,
      "<" = value < threshold,
      ">=" = value >= threshold,
      "==" = value == threshold,
      FALSE
    )
    data.frame(
      gate_order = as.integer(gate$gate_order), gate_id = as.character(gate$gate_id),
      gate_category = as.character(gate$gate_category),
      metric_id = as.character(gate$metric_id), value = value,
      operator = operator, threshold = threshold,
      applicable = applicable, required = required, passed = isTRUE(passed),
      failure_reason_code = as.character(gate$failure_reason_code),
      stringsAsFactors = FALSE, check.names = FALSE
    )
  })
  gates <- do.call(rbind, result)
  rownames(gates) <- NULL
  gates
}

phase19_club_promotion_decision_schema <- function() {
  c(
    "schema_version", "hash_encoding_version", "forecast_domain", "authority_mode",
    "fixture_authority", "candidate_id", "incumbent_id", "selected_model_id",
    "diagnostic_gate_outcome", "authority_eligibility", "promotion_status",
    "reason_codes", "authority_reason_code", "evaluation_set_sha256",
    "reproducibility_evidence_sha256", "authority_sha256", "protocol_sha256",
    "policy_review_sha256", "gate_registry_sha256", "seed_registry_sha256",
    "metrics_sha256", "integrity_sha256", "gate_results_sha256",
    "gate_results", "decision_sha256"
  )
}

phase19_club_promotion_decision_sha256 <- function(decision) {
  if (!is.list(decision) || !identical(names(decision),
                                       phase19_club_promotion_decision_schema())) {
    phase19_club_evaluation_abort(
      "promotion_decision_schema_invalid", "Promotion decision schema is not exact"
    )
  }
  fields <- setdiff(names(decision), c("gate_results", "decision_sha256"))
  values <- decision[fields]
  values$reason_codes <- paste(as.character(values$reason_codes), collapse = "|")
  phase19_club_evaluation_hash_values(
    values, "phase19-club-promotion-decision-v1"
  )
}

phase19_club_integrity_names <- function() {
  c(
    "probability_integrity", "distribution_integrity", "cutoff_integrity",
    "identity_integrity", "source_integrity", "license_integrity",
    "feature_integrity", "seed_integrity", "checksum_integrity",
    "domain_integrity", "model_card_integrity"
  )
}

phase19_club_integrity_artifact_names <- function() {
  c(
    "evaluation_set_sha256", "protocol_sha256", "replay_sha256",
    "authority_sha256", "fold_members_sha256", "source_evidence_sha256"
  )
}

phase19_club_integrity_evidence_schema <- function() {
  c("schema_version", "hash_encoding_version", "checks", "artifact_hashes",
    "evidence_sha256")
}

phase19_club_integrity_evidence_sha256 <- function(evidence) {
  checks <- evidence$checks
  artifacts <- evidence$artifact_hashes
  values <- c(
    list(schema_version = evidence$schema_version,
         hash_encoding_version = evidence$hash_encoding_version),
    stats::setNames(as.list(checks), paste0("check_", names(checks))),
    stats::setNames(as.list(artifacts), paste0("artifact_", names(artifacts)))
  )
  phase19_club_evaluation_hash_values(
    values, "phase19-club-promotion-integrity-evidence-v1"
  )
}

phase19_validate_club_integrity_evidence <- function(
    evidence, evaluation, protocol, replay, authority, source_evidence = NULL
) {
  if (!inherits(evidence, "phase19_club_integrity_evidence") ||
      !identical(names(evidence), phase19_club_integrity_evidence_schema()) ||
      !identical(names(evidence$checks), phase19_club_integrity_names()) ||
      !identical(names(evidence$artifact_hashes), phase19_club_integrity_artifact_names()) ||
      any(!vapply(evidence$checks, is.logical, logical(1))) ||
      any(lengths(evidence$checks) != 1L) ||
      any(!vapply(evidence$artifact_hashes, phase19_is_sha256, logical(1))) ||
      !identical(evidence$evidence_sha256,
                 phase19_club_integrity_evidence_sha256(evidence))) {
    phase19_club_evaluation_abort(
      "promotion_integrity_invalid",
      "Promotion integrity evidence must be one exact typed artifact-bound object"
    )
  }
  expected <- phase19_derive_club_integrity_evidence(
    evaluation, protocol, replay, authority, source_evidence
  )
  if (!identical(evidence$evidence_sha256, expected$evidence_sha256)) {
    phase19_club_evaluation_abort(
      "promotion_integrity_source_mismatch",
      "Promotion integrity evidence does not derive from validated artifacts"
    )
  }
  invisible(evidence)
}

phase19_derive_club_integrity_evidence <- function(
    evaluation, protocol, replay, authority, source_evidence = NULL
) {
  accepted_fold_protocol <- if (identical(protocol$authority_mode, "production") &&
                                inherits(authority$source_evidence, "list")) {
    authority$source_evidence$fold_protocol
  } else NULL
  phase19_validate_club_evaluation_set(
    evaluation, protocol, source_evidence, accepted_fold_protocol
  )
  phase19_club_validate_reproducibility(
    replay, protocol, evaluation = evaluation,
    source_evidence = source_evidence,
    accepted_fold_protocol = accepted_fold_protocol
  )
  phase19_club_validate_authority(authority, evaluation, protocol, source_evidence)
  folds <- evaluation$fold_evaluations
  probabilities <- all(vapply(folds, function(fold) {
    fields <- c("p_home", "p_draw", "p_away")
    rows <- fold$predictions[fold$predictions$model_id %in%
      c("club_elo_nb", "club_venue_nb"), fields, drop = FALSE]
    nrow(rows) > 0L && all(vapply(rows, function(column) {
      values <- as.numeric(column)
      all(is.finite(values)) && all(values >= 0) && all(values <= 1)
    }, logical(1)))
  }, logical(1)))
  distributions <- all(vapply(folds, function(fold) {
    all(fold$coverage$fixture_coverage == 1) &&
      all(fold$coverage$score_grid_coverage == 1)
  }, logical(1)))
  cutoffs <- all(vapply(folds, function(fold) all(fold$cutoff_evidence$cutoff_passed), logical(1)))
  identities <- identical(evaluation$protocol_sha256, protocol$protocol_sha256) &&
    identical(evaluation$authority_mode, authority$authority_mode) &&
    identical(authority$evaluation_set_sha256, evaluation$evaluation_set_sha256)
  sources <- if (identical(protocol$authority_mode, "production")) {
    !is.null(source_evidence)
  } else {
    identical(authority$status, "fixture_ineligible") &&
      isTRUE(authority$fixture_authority)
  }
  license <- if (identical(protocol$authority_mode, "production")) {
    length(authority$source_evidence) > 0L
  } else sources
  feature <- isTRUE(identical(protocol$feature_contract_sha256,
                              phase19_feature_contract_sha256(protocol$feature_contract)))
  seed <- isTRUE(identical(protocol$seed_registry_sha256,
                            phase19_seed_registry_sha256(protocol$seed_registry)))
  checksum <- isTRUE(identical(evaluation$evaluation_set_sha256,
                               phase19_club_evaluation_set_sha256(evaluation))) &&
    isTRUE(identical(authority$authority_sha256,
                     phase19_club_authority_sha256(authority)))
  domain <- all(vapply(folds, function(fold) identical(fold$forecast_domain, "club"), logical(1))) &&
    identical(protocol$forecast_domain, "club")
  model_card <- all(vapply(folds, function(fold) {
    all(vapply(fold$convergence$fit_sha256, phase19_is_sha256, logical(1))) &&
      all(fold$convergence$fit_status == "converged")
  }, logical(1)))
  checks <- c(
    probability_integrity = probabilities,
    distribution_integrity = distributions,
    cutoff_integrity = cutoffs,
    identity_integrity = identities,
    source_integrity = sources,
    license_integrity = license,
    feature_integrity = feature,
    seed_integrity = seed,
    checksum_integrity = checksum,
    domain_integrity = domain,
    model_card_integrity = model_card
  )
  source_hash <- if (!is.null(source_evidence)) {
    digest::digest(source_evidence, algo = "sha256", serialize = TRUE)
  } else {
    digest::digest(list(authority_mode = protocol$authority_mode,
                        fixture_authority = isTRUE(protocol$fixture_authority)),
                   algo = "sha256", serialize = TRUE)
  }
  artifacts <- c(
    evaluation_set_sha256 = evaluation$evaluation_set_sha256,
    protocol_sha256 = protocol$protocol_sha256,
    replay_sha256 = replay$evidence_sha256,
    authority_sha256 = authority$authority_sha256,
    fold_members_sha256 = evaluation$evaluation_member_sha256,
    source_evidence_sha256 = source_hash
  )
  result <- list(
    schema_version = "phase19-club-promotion-integrity-evidence-v1",
    hash_encoding_version = phase18_canonical_encoding_v2(),
    checks = as.list(checks), artifact_hashes = as.list(artifacts),
    evidence_sha256 = ""
  )
  result$evidence_sha256 <- phase19_club_integrity_evidence_sha256(result)
  structure(result, class = c("phase19_club_integrity_evidence", "list"))
}

phase19_club_integrity_sha256 <- function(integrity) {
  if (!inherits(integrity, "phase19_club_integrity_evidence") ||
      !identical(names(integrity), phase19_club_integrity_evidence_schema()) ||
      !identical(names(integrity$checks), phase19_club_integrity_names()) ||
      !identical(names(integrity$artifact_hashes), phase19_club_integrity_artifact_names()) ||
      any(!vapply(integrity$checks, is.logical, logical(1))) ||
      any(lengths(integrity$checks) != 1L) ||
      any(!vapply(integrity$artifact_hashes, phase19_is_sha256, logical(1))) ||
      !identical(integrity$evidence_sha256,
                 phase19_club_integrity_evidence_sha256(integrity))) {
    phase19_club_evaluation_abort(
      "promotion_integrity_invalid", "Promotion integrity evidence is not a typed artifact-bound object"
    )
  }
  integrity$evidence_sha256
}

phase19_club_validate_reproducibility <- function(
    replay, protocol, evaluation = NULL, source_evidence = NULL,
    accepted_fold_protocol = NULL
) {
  seed <- phase19_club_evaluation_seed(protocol, "club_isolated_replay_v1")
  if (!inherits(replay, "phase19_club_reproducibility_evidence") ||
      !identical(names(replay), phase19_club_reproducibility_schema()) ||
      !identical(replay$evidence_sha256,
                 phase19_club_reproducibility_sha256(replay)) ||
      !identical(replay$seed_id, as.character(seed$seed_id[[1L]])) ||
      !identical(as.integer(replay$seed), as.integer(seed$seed[[1L]]))) {
    phase19_club_evaluation_abort(
      "reproducibility_evidence_invalid", "Reproducibility evidence or seed drifted"
    )
  }
  if (identical(protocol$authority_mode, "production")) {
    if (!inherits(replay, "phase19_club_production_reproducibility_evidence")) {
      phase19_club_evaluation_abort(
        "reproducibility_source_invalid",
        "Production reproducibility evidence must come from the fixed-source wrapper"
      )
    }
    if (is.null(evaluation) || is.null(source_evidence) ||
        is.null(accepted_fold_protocol)) {
      phase19_club_evaluation_abort(
        "reproducibility_evidence_invalid",
        "Production reproducibility validation requires the accepted evaluation source graph"
      )
    }
    phase19_validate_club_evaluation_set(
      evaluation, protocol, source_evidence, accepted_fold_protocol
    )
    expected <- phase19_club_evaluation_complete_output_sha256(evaluation)
    if (!isTRUE(replay$reproducible) ||
        !identical(as.character(replay$first_evaluation_sha256), expected) ||
        !identical(as.character(replay$second_evaluation_sha256), expected)) {
      phase19_club_evaluation_abort(
        "reproducibility_source_mismatch",
        "Production reproducibility evidence does not match the accepted complete evaluation output"
      )
    }
  }
  invisible(replay)
}

phase19_club_validate_authority <- function(authority, evaluation, protocol,
                                            source_evidence = NULL) {
  if (!inherits(authority, "phase19_club_evaluation_authority") ||
      !identical(names(authority), phase19_club_authority_schema()) ||
      !identical(authority$authority_sha256,
                 phase19_club_authority_sha256(authority)) ||
      !identical(authority$forecast_domain, "club") ||
      !identical(authority$evaluation_set_sha256,
                 evaluation$evaluation_set_sha256) ||
      !identical(authority$protocol_sha256, protocol$protocol_sha256) ||
      !identical(authority$policy_review_sha256,
                 protocol$policy_review$review_sha256) ||
      !identical(authority$authority_mode, protocol$authority_mode) ||
      !identical(authority$authority_mode, evaluation$authority_mode)) {
    phase19_club_evaluation_abort(
      "evaluation_authority_invalid", "Evaluation authority parent graph drifted"
    )
  }
  if (identical(authority$authority_mode, "fixture")) {
    if (!isTRUE(authority$fixture_authority) ||
        !identical(authority$status, "fixture_ineligible") ||
        isTRUE(authority$production_eligible) || length(authority$source_evidence)) {
      phase19_club_evaluation_abort(
        "evaluation_authority_invalid", "Fixture authority was relabeled as production"
      )
    }
  } else {
    if (!identical(authority$authority_mode, "production") ||
        isTRUE(authority$fixture_authority) ||
        !identical(authority$status, "ready") ||
        !isTRUE(authority$production_eligible)) {
      phase19_club_evaluation_abort(
        "evaluation_authority_invalid", "Production authority state is invalid"
      )
    }
    resolved <- phase19_club_validate_production_sources(
      authority$source_evidence, evaluation, protocol,
      fold_source_evidence = source_evidence
    )
    compared <- c(
      "history_snapshot_sha256", "current_snapshot_sha256",
      "fold_registry_sha256", "fold_review_sha256",
      "current_ucl_club_coverage", "common_component_coverage"
    )
    if (!identical(authority[compared], resolved[compared])) {
      phase19_club_evaluation_abort(
        "evaluation_authority_invalid", "Production authority source projection drifted"
      )
    }
  }
  invisible(authority)
}

#' Produce the immutable ordered club promotion decision.
#'
#' @export
phase19_evaluate_club_promotion <- function(evaluation, protocol, replay,
                                            integrity, authority,
                                            source_evidence = NULL,
                                            production_source_authority = NULL) {
  accepted_fold_protocol <- if (identical(protocol$authority_mode, "production") &&
                                inherits(authority$source_evidence, "list")) {
    authority$source_evidence$fold_protocol
  } else NULL
  phase19_validate_club_evaluation_set(
    evaluation, protocol, source_evidence, accepted_fold_protocol
  )
  effective_replay <- if (identical(protocol$authority_mode, "production")) {
    source_authority <- phase19_club_production_promotion_source_authority(
      evaluation, protocol, integrity, authority, source_evidence,
      production_source_authority
    )
    phase19_production_club_reproducibility_evidence(
      evaluation, source_authority
    )
  } else replay
  phase19_club_validate_reproducibility(
    effective_replay, protocol, evaluation = evaluation,
    source_evidence = source_evidence,
    accepted_fold_protocol = accepted_fold_protocol
  )
  phase19_club_validate_authority(authority, evaluation, protocol, source_evidence)
  phase19_validate_club_integrity_evidence(
    integrity, evaluation, protocol, effective_replay, authority, source_evidence
  )
  integrity_hash <- phase19_club_integrity_sha256(integrity)
  metrics <- evaluation$metrics
  metrics$current_ucl_club_coverage <- authority$current_ucl_club_coverage
  metrics$common_rating_component_coverage <- authority$common_component_coverage
  metrics$byte_reproducibility <- as.numeric(isTRUE(effective_replay$reproducible))
  for (name in phase19_club_integrity_names()) {
    metrics[[name]] <- as.numeric(isTRUE(integrity$checks[[name]]))
  }
  metrics_hash <- phase19_club_evaluation_metrics_sha256(metrics)
  gates <- phase19_apply_club_promotion_gates(
    metrics, protocol, authority$authority_mode
  )
  gate_hash <- phase18_hash_table_v2(
    gates, key = "gate_order",
    schema_tag = "phase19-club-promotion-gate-results-v1"
  )
  failed <- as.character(gates$failure_reason_code[gates$required & !gates$passed])
  diagnostic <- if (length(failed)) "fail" else "pass"
  authority_eligibility <- if (identical(authority$authority_mode, "fixture")) {
    "fixture_ineligible"
  } else if (isTRUE(authority$production_eligible) &&
             identical(authority$status, "ready")) {
    "production"
  } else "production_blocked"
  promotion_status <- if (identical(diagnostic, "fail")) {
    "retained"
  } else if (identical(authority_eligibility, "fixture_ineligible")) {
    "ineligible_fixture"
  } else if (identical(authority_eligibility, "production")) {
    "promoted"
  } else "blocked"
  selected <- if (promotion_status %in% c("promoted", "ineligible_fixture")) {
    "club_elo_nb"
  } else "club_venue_nb"
  result <- list(
    schema_version = "phase19-club-promotion-decision-v1",
    hash_encoding_version = phase18_canonical_encoding_v2(), forecast_domain = "club",
    authority_mode = authority$authority_mode,
    fixture_authority = isTRUE(authority$fixture_authority),
    candidate_id = "club_elo_nb", incumbent_id = "club_venue_nb",
    selected_model_id = selected, diagnostic_gate_outcome = diagnostic,
    authority_eligibility = authority_eligibility,
    promotion_status = promotion_status,
    reason_codes = if (length(failed)) failed else "",
    authority_reason_code = as.character(authority$reason_code),
    evaluation_set_sha256 = evaluation$evaluation_set_sha256,
    reproducibility_evidence_sha256 = effective_replay$evidence_sha256,
    authority_sha256 = authority$authority_sha256,
    protocol_sha256 = protocol$protocol_sha256,
    policy_review_sha256 = protocol$policy_review$review_sha256,
    gate_registry_sha256 = protocol$gate_registry_sha256,
    seed_registry_sha256 = protocol$seed_registry_sha256,
    metrics_sha256 = metrics_hash, integrity_sha256 = integrity_hash,
    gate_results_sha256 = gate_hash, gate_results = gates,
    decision_sha256 = ""
  )
  result$decision_sha256 <- phase19_club_promotion_decision_sha256(result)
  structure(result, class = c("phase19_club_promotion_decision", "list"))
}

#' Recompute a promotion decision from exact evaluation authority.
#'
#' @export
phase19_validate_club_promotion_decision <- function(
    decision, evaluation, protocol, replay, integrity, authority,
    source_evidence = NULL, production_source_authority = NULL
) {
  if (!inherits(decision, "phase19_club_promotion_decision") ||
      !identical(names(decision), phase19_club_promotion_decision_schema()) ||
      !identical(decision$decision_sha256,
                 phase19_club_promotion_decision_sha256(decision))) {
    phase19_club_evaluation_abort(
      "promotion_decision_hash_mismatch", "Promotion decision schema or identity drifted"
    )
  }
  expected_replay <- if (identical(protocol$authority_mode, "production")) {
    NULL
  } else replay
  expected <- phase19_evaluate_club_promotion(
    evaluation, protocol, expected_replay, integrity, authority, source_evidence,
    production_source_authority
  )
  if (!identical(decision$decision_sha256, expected$decision_sha256)) {
    phase19_club_evaluation_abort(
      "promotion_decision_source_mismatch",
      "Promotion decision does not derive from the exact ordered evidence"
    )
  }
  invisible(decision)
}
