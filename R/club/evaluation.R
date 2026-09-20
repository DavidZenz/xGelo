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
    "phase19_validate_club_goal_predictions", "score_benchmark_fixtures",
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
    sum(selected$n * selected$absolute_gap) / sum(selected$n)
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
