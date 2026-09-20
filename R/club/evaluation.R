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

phase19_club_evaluation_list_identity <- function(evaluations) {
  if (!is.list(evaluations) || length(evaluations) < 2L) {
    phase19_club_evaluation_abort(
      "evaluation_set_invalid", "Evaluation set requires multiple canonical folds"
    )
  }
  invisible(lapply(evaluations, phase19_club_evaluation_fold_self_check))
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
phase19_aggregate_club_evaluations <- function(evaluations, protocol) {
  phase19_club_evaluation_require_dependencies()
  if (!inherits(protocol, "phase19_club_evaluation_protocol") ||
      !identical(protocol$status, "ready") || !identical(protocol$forecast_domain, "club")) {
    phase19_club_evaluation_abort(
      "evaluation_protocol_invalid", "Aggregation requires one ready club protocol"
    )
  }
  phase19_validate_gate_registry(protocol$gate_registry)
  member_hash <- phase19_club_evaluation_list_identity(evaluations)
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

phase19_validate_club_evaluation_set <- function(evidence, protocol) {
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
  expected <- phase19_aggregate_club_evaluations(evidence$fold_evaluations, protocol)
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

phase19_club_evaluation_identity <- function(value) {
  if (inherits(value, "phase19_club_evaluation_set")) {
    return(as.character(value$evaluation_set_sha256))
  }
  phase19_club_evaluation_list_identity(value)
}

#' Compare two isolated club evaluation executions canonically.
#'
#' @export
phase19_club_reproducibility_evidence <- function(first, second, protocol) {
  seed <- phase19_club_evaluation_seed(protocol, "club_isolated_replay_v1")
  first_hash <- phase19_club_evaluation_identity(first)
  second_hash <- phase19_club_evaluation_identity(second)
  result <- list(
    schema_version = "phase19-club-evaluation-reproducibility-v1",
    hash_encoding_version = phase18_canonical_encoding_v2(), forecast_domain = "club",
    seed_id = as.character(seed$seed_id[[1L]]), seed = as.integer(seed$seed[[1L]]),
    first_evaluation_sha256 = first_hash, second_evaluation_sha256 = second_hash,
    reproducible = identical(first_hash, second_hash), evidence_sha256 = ""
  )
  result$evidence_sha256 <- phase19_club_reproducibility_sha256(result)
  structure(result, class = c("phase19_club_reproducibility_evidence", "list"))
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

phase19_club_validate_production_sources <- function(source_evidence, evaluation,
                                                     protocol) {
  if (!is.list(source_evidence) ||
      !identical(names(source_evidence), phase19_club_production_source_schema())) {
    phase19_club_evaluation_abort(
      "evaluation_authority_invalid",
      "Production authority requires exact accepted source evidence"
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
  phase19_validate_fold_review(folds$fold_review, folds, require_accepted = TRUE)
  expected_audit <- phase19_club_rating_component_audit(history, current, history$matches)
  if (!inherits(replay, "phase19_club_rating_replay") ||
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
    fold_protocol, rating_replay
) {
  phase19_validate_club_evaluation_set(evaluation, protocol)
  if (!inherits(protocol, "phase19_club_evaluation_protocol") ||
      !identical(protocol$status, "ready") ||
      !identical(protocol$authority_mode, "production") ||
      isTRUE(protocol$fixture_authority) || !isTRUE(protocol$production_eligible)) {
    phase19_club_evaluation_abort(
      "evaluation_authority_invalid",
      "Production authority requires the ready owner-reviewed protocol"
    )
  }
  sources <- list(
    history_snapshot = history_snapshot, current_snapshot = current_snapshot,
    fold_protocol = fold_protocol, rating_replay = rating_replay
  )
  resolved <- phase19_club_validate_production_sources(sources, evaluation, protocol)
  result <- list(
    schema_version = "phase19-club-evaluation-authority-v1",
    hash_encoding_version = phase18_canonical_encoding_v2(), forecast_domain = "club",
    authority_mode = "production", fixture_authority = FALSE,
    status = "ready", reason_code = "", production_eligible = TRUE,
    history_snapshot_sha256 = resolved$history_snapshot_sha256,
    current_snapshot_sha256 = resolved$current_snapshot_sha256,
    protocol_sha256 = protocol$protocol_sha256,
    policy_review_sha256 = protocol$policy_review$review_sha256,
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

phase19_club_integrity_sha256 <- function(integrity) {
  expected <- phase19_club_integrity_names()
  if (!is.list(integrity) || !identical(names(integrity), expected) ||
      any(!vapply(integrity, is.logical, logical(1))) || any(lengths(integrity) != 1L)) {
    phase19_club_evaluation_abort(
      "promotion_integrity_invalid", "Promotion integrity evidence is incomplete"
    )
  }
  phase19_club_evaluation_hash_values(
    integrity, "phase19-club-promotion-integrity-v1"
  )
}

phase19_club_validate_reproducibility <- function(replay, protocol) {
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
  invisible(replay)
}

phase19_club_validate_authority <- function(authority, evaluation, protocol) {
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
      authority$source_evidence, evaluation, protocol
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
                                            integrity, authority) {
  phase19_validate_club_evaluation_set(evaluation, protocol)
  phase19_club_validate_reproducibility(replay, protocol)
  phase19_club_validate_authority(authority, evaluation, protocol)
  integrity_hash <- phase19_club_integrity_sha256(integrity)
  metrics <- evaluation$metrics
  metrics$current_ucl_club_coverage <- authority$current_ucl_club_coverage
  metrics$common_rating_component_coverage <- authority$common_component_coverage
  metrics$byte_reproducibility <- as.numeric(isTRUE(replay$reproducible))
  for (name in phase19_club_integrity_names()) {
    metrics[[name]] <- as.numeric(isTRUE(integrity[[name]]))
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
    reproducibility_evidence_sha256 = replay$evidence_sha256,
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
    decision, evaluation, protocol, replay, integrity, authority
) {
  if (!inherits(decision, "phase19_club_promotion_decision") ||
      !identical(names(decision), phase19_club_promotion_decision_schema()) ||
      !identical(decision$decision_sha256,
                 phase19_club_promotion_decision_sha256(decision))) {
    phase19_club_evaluation_abort(
      "promotion_decision_hash_mismatch", "Promotion decision schema or identity drifted"
    )
  }
  expected <- phase19_evaluate_club_promotion(
    evaluation, protocol, replay, integrity, authority
  )
  if (!identical(decision$decision_sha256, expected$decision_sha256)) {
    phase19_club_evaluation_abort(
      "promotion_decision_source_mismatch",
      "Promotion decision does not derive from the exact ordered evidence"
    )
  }
  invisible(decision)
}
