library(testthat)

phase19_evaluation_test_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/", mustWork = TRUE
)

phase19_evaluation_test_load <- function(require_module = TRUE) {
  paths <- c(
    "R/common/phase18_canonical_hash.R",
    "R/club/history_contract.R",
    "R/club/model_contract.R",
    "R/evaluation/proper_scores.R",
    "R/evaluation/benchmark_scores.R",
    "R/club/evaluation_protocol.R",
    "R/club/rating.R",
    "R/club/goal_model.R",
    "R/club/calibration.R"
  )
  for (path in file.path(phase19_evaluation_test_root, paths)) {
    if (!file.exists(path)) stop("Missing Phase 19 evaluation dependency: ", path, call. = FALSE)
    source(path, local = .GlobalEnv)
  }
  module <- file.path(phase19_evaluation_test_root, "R/club/evaluation.R")
  if (!file.exists(module)) {
    if (isTRUE(require_module)) stop("RED: missing Phase 19 club evaluation module", call. = FALSE)
    return(invisible(FALSE))
  }
  source(module, local = .GlobalEnv)
  invisible(TRUE)
}

phase19_evaluation_test_fold <- function(protocol,
                                         family = "rolling_origin_league_season",
                                         ordinal = 1L) {
  ids <- sprintf("eval_%02d_%s", ordinal, c("a", "b"))
  heldout <- if (identical(family, "heldout_league_transport")) "league-z" else ""
  row <- data.frame(
    schema_version = "phase19-club-fold-v1",
    hash_encoding_version = phase18_canonical_encoding_v2(),
    forecast_domain = "club", authority_mode = "fixture", fixture_authority = TRUE,
    fold_id = sprintf("club__%s__league-z__2025-%02d", family, ordinal),
    fold_family = family, assessment_competition_id = "league-z",
    assessment_season_id = sprintf("2025-%02d", ordinal),
    assessment_start_utc = "2025-04-01T00:00:00Z",
    assessment_end_utc = "2025-04-30T23:59:59Z",
    training_cutoff_exclusive = "2025-02-01T00:00:00Z",
    calibration_cutoff_exclusive = "2025-04-01T00:00:00Z",
    declared_fixture_ids = paste(ids, collapse = "|"),
    declared_fixture_count = as.integer(length(ids)),
    declared_fixture_sha256 = phase19_fold_id_sha256(ids, "declared"),
    training_fixture_ids = "fit_a|fit_b",
    training_fixture_count = 2L,
    training_fixture_sha256 = phase19_fold_id_sha256(c("fit_a", "fit_b"), "training"),
    calibration_fixture_ids = "cal_a|cal_b",
    calibration_fixture_count = 2L,
    calibration_fixture_sha256 = phase19_fold_id_sha256(c("cal_a", "cal_b"), "calibration"),
    held_out_competition_id = heldout,
    fit_excluded_competition_id = heldout,
    tuning_excluded_competition_id = heldout,
    calibration_excluded_competition_id = heldout,
    eligibility_status = "eligible", support_reason_code = "",
    accepted_generation_id = "phase19-evaluation-fixture",
    corpus_manifest_sha256 = paste(rep("a", 64L), collapse = ""),
    snapshot_sha256 = paste(rep("b", 64L), collapse = ""),
    protocol_sha256 = protocol$protocol_sha256,
    policy_review_sha256 = protocol$policy_review$review_sha256,
    calibration_recipe_sha256 = phase19_expected_calibration_recipe()$recipe_sha256,
    row_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE
  )
  row$row_sha256 <- phase19_fold_row_sha256(row)
  row
}

phase19_evaluation_test_grid <- function(fixture_id, model_id, home_mean, away_mean) {
  goals <- 0:40
  home <- dpois(goals, home_mean)
  away <- dpois(goals, away_mean)
  probability <- as.vector(outer(home, away))
  probability <- probability / sum(probability)
  grid <- expand.grid(
    home_goals = goals, away_goals = goals,
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  grid <- data.frame(
    fixture_id = fixture_id,
    score_distribution_id = paste0(fixture_id, "__", model_id, "__score"),
    model_id = model_id, home_goals = grid$home_goals,
    away_goals = grid$away_goals, probability = probability,
    support_max_home = 40L, support_max_away = 40L,
    raw_tail_mass = 0, normalized = TRUE,
    tail_policy = "truncate_0_40_then_joint_renormalize_once",
    fit_sha256 = digest::digest(paste0("fit-", model_id), algo = "sha256", serialize = FALSE),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  grid[order(grid$home_goals, grid$away_goals, method = "radix"), , drop = FALSE]
}

phase19_evaluation_test_predictions <- function(fold, model_id, strong = FALSE) {
  ids <- strsplit(fold$declared_fixture_ids, "|", fixed = TRUE)[[1L]]
  grids <- if (isTRUE(strong)) {
    list(
      phase19_evaluation_test_grid(ids[[1L]], model_id, 2.4, 0.45),
      phase19_evaluation_test_grid(ids[[2L]], model_id, 0.45, 2.4)
    )
  } else {
    lapply(ids, phase19_evaluation_test_grid, model_id = model_id,
           home_mean = 1.15, away_mean = 1.15)
  }
  distributions <- do.call(rbind, grids)
  rownames(distributions) <- NULL
  rows <- lapply(seq_along(ids), function(index) {
    grid <- grids[[index]]
    market <- phase19_club_goal_grid_markets(grid)
    data.frame(
      fixture_id = ids[[index]], forecast_domain = "club", authority_mode = "fixture",
      fixture_authority = TRUE, promotion_eligible = FALSE,
      promotion_comparable = TRUE, model_id = model_id,
      model_family = "negative_binomial",
      output_capability = "complete_score_distribution_and_derived_markets",
      goal_distribution_declared = TRUE,
      prediction_status = "ready_goal_distribution",
      boundary_id = paste0("boundary-", ids[[index]]),
      evidence_cutoff_exclusive = fold$calibration_cutoff_exclusive,
      home_club_id = if (index == 1L) "club_alpha" else "club_gamma",
      away_club_id = if (index == 1L) "club_beta" else "club_delta",
      score_distribution_id = unique(grid$score_distribution_id),
      p_home = market$p_home, p_draw = market$p_draw, p_away = market$p_away,
      p_over_2_5 = market$p_over_2_5, p_btts = market$p_btts,
      expected_home_goals = market$expected_home_goals,
      expected_away_goals = market$expected_away_goals,
      likely_home_goals = market$likely_home_goals,
      likely_away_goals = market$likely_away_goals,
      raw_tail_mass = 0, support_max = 40L,
      fit_sha256 = unique(grid$fit_sha256),
      rating_evidence_sha256 = paste(rep("c", 64L), collapse = ""),
      training_snapshot_sha256 = fold$snapshot_sha256,
      current_snapshot_sha256 = paste(rep("d", 64L), collapse = ""),
      protocol_sha256 = fold$protocol_sha256,
      fallback_status = "none",
      distribution_sha256 = phase18_hash_table_v2(
        grid, key = c("fixture_id", "home_goals", "away_goals"),
        schema_tag = "phase19-club-goal-distribution-v1"
      ), prediction_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE
    )
  })
  predictions <- do.call(rbind, rows)
  predictions$prediction_sha256 <- phase19_club_goal_prediction_row_hash(predictions)
  structure(list(
    schema_version = "phase19-club-goal-prediction-set-v1",
    hash_encoding_version = phase18_canonical_encoding_v2(),
    forecast_domain = "club", authority_mode = "fixture",
    fixture_authority = TRUE, promotion_eligible = FALSE,
    promotion_comparable = TRUE, model_id = model_id,
    output_capability = "complete_score_distribution_and_derived_markets",
    goal_distribution_declared = TRUE, declared_fixture_ids = ids,
    fit_sha256 = unique(predictions$fit_sha256), predictions = predictions,
    distributions = distributions,
    prediction_table_sha256 = phase18_hash_table_v2(
      predictions, key = "fixture_id", schema_tag = "phase19-club-goal-predictions-v1"
    ),
    distribution_table_sha256 = phase18_hash_table_v2(
      distributions, key = c("fixture_id", "home_goals", "away_goals"),
      schema_tag = "phase19-club-goal-distributions-v1"
    )
  ), class = c("phase19_club_goal_predictions", "list"))
}

phase19_evaluation_test_outcomes <- function(fold) {
  ids <- strsplit(fold$declared_fixture_ids, "|", fixed = TRUE)[[1L]]
  data.frame(
    fixture_id = ids, forecast_domain = "club",
    competition_id = fold$assessment_competition_id,
    season_id = fold$assessment_season_id,
    kickoff_utc = c("2025-04-10T18:00:00Z", "2025-04-20T18:00:00Z"),
    completion_not_before_utc = c("2025-04-10T20:00:00Z", "2025-04-20T20:00:00Z"),
    evidence_available_at_utc = c("2025-04-10T20:05:00Z", "2025-04-20T20:05:00Z"),
    home_club_id = c("club_alpha", "club_gamma"),
    away_club_id = c("club_beta", "club_delta"),
    regulation_home_goals = c(2L, 0L), regulation_away_goals = c(0L, 2L),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

phase19_evaluation_test_support <- function(fold) {
  data.frame(
    model_id = c("club_venue_nb", "club_elo_nb"),
    fit_status = "converged", fallback_status = "none",
    fit_sha256 = vapply(c("club_venue_nb", "club_elo_nb"), function(id) {
      digest::digest(paste0("fit-", id), algo = "sha256", serialize = FALSE)
    }, character(1)),
    calibrator_status = "fitted", primary_probability_view = "raw_1x2",
    calibrator_sha256 = vapply(c("club_venue_nb", "club_elo_nb"), function(id) {
      digest::digest(paste0("calibrator-", id), algo = "sha256", serialize = FALSE)
    }, character(1)),
    calibration_evidence_sha256 = vapply(c("club_venue_nb", "club_elo_nb"), function(id) {
      digest::digest(paste0("cal-evidence-", id), algo = "sha256", serialize = FALSE)
    }, character(1)),
    calibration_decision_sha256 = vapply(c("club_venue_nb", "club_elo_nb"), function(id) {
      digest::digest(paste0("cal-decision-", id), algo = "sha256", serialize = FALSE)
    }, character(1)), stringsAsFactors = FALSE, check.names = FALSE
  )
}

phase19_evaluation_test_provenance <- function(fold) {
  data.frame(
    role = c("fit", "tuning", "calibration"),
    cutoff_exclusive = c(
      fold$training_cutoff_exclusive, fold$training_cutoff_exclusive,
      fold$calibration_cutoff_exclusive
    ),
    excluded_competition_id = c(
      fold$fit_excluded_competition_id, fold$tuning_excluded_competition_id,
      fold$calibration_excluded_competition_id
    ),
    declared_fixture_sha256 = c(
      fold$training_fixture_sha256, fold$training_fixture_sha256,
      fold$calibration_fixture_sha256
    ), stringsAsFactors = FALSE, check.names = FALSE
  )
}

phase19_evaluation_test_context <- function(family = "rolling_origin_league_season",
                                            ordinal = 1L) {
  phase19_evaluation_test_load()
  protocol <- phase19_load_fixture_club_evaluation_protocol()
  fold <- phase19_evaluation_test_fold(protocol, family, ordinal)
  list(
    protocol = protocol, fold = fold,
    candidate = phase19_evaluation_test_predictions(fold, "club_elo_nb", TRUE),
    incumbent = phase19_evaluation_test_predictions(fold, "club_venue_nb", FALSE),
    outcomes = phase19_evaluation_test_outcomes(fold),
    support = phase19_evaluation_test_support(fold),
    provenance = phase19_evaluation_test_provenance(fold)
  )
}

phase19_evaluation_test_score <- function(context) {
  phase19_score_club_fold(
    candidate_predictions = context$candidate,
    incumbent_predictions = context$incumbent,
    outcomes = context$outcomes, fold = context$fold,
    protocol = context$protocol, model_support = context$support,
    role_provenance = context$provenance
  )
}

test_that("one frozen rolling fold yields complete paired club evidence", {
  context <- phase19_evaluation_test_context()
  evidence <- phase19_evaluation_test_score(context)

  expect_s3_class(evidence, "phase19_club_fold_evaluation")
  expect_identical(evidence$status, "scored")
  expect_identical(evidence$forecast_domain, "club")
  expect_identical(evidence$candidate_id, "club_elo_nb")
  expect_identical(evidence$incumbent_id, "club_venue_nb")
  expect_identical(nrow(evidence$predictions), 4L)
  expect_identical(nrow(evidence$distributions), 4L * 1681L)
  expect_identical(nrow(evidence$fixture_scores), 4L * 14L)
  expect_identical(nrow(evidence$calibration_bins), 2L * 3L * 10L)
  expect_true(all(evidence$coverage$fixture_coverage == 1))
  expect_true(all(evidence$coverage$score_grid_coverage == 1))
  expect_true(all(evidence$convergence$converged))
  expect_true(all(evidence$cutoff_evidence$cutoff_passed))
  expect_match(evidence$evaluation_sha256, "^[0-9a-f]{64}$")
  expect_silent(phase19_validate_club_fold_evaluation(
    evidence, context$candidate, context$incumbent, context$outcomes,
    context$fold, context$protocol, context$support, context$provenance
  ))
})

test_that("source folds are bound to the exact accepted row and protocol", {
  context <- phase19_evaluation_test_context()
  evidence <- phase19_evaluation_test_score(context)
  source <- list(
    candidate_predictions = context$candidate,
    incumbent_predictions = context$incumbent,
    outcomes = context$outcomes,
    fold = context$fold,
    protocol = context$protocol,
    model_support = context$support,
    role_provenance = context$provenance
  )
  expect_silent(phase19_validate_club_fold_source_evidence(
    evidence, source, accepted_fold = context$fold,
    accepted_protocol = context$protocol
  ))

  forged_fold <- source
  forged_fold$fold$declared_fixture_count <-
    forged_fold$fold$declared_fixture_count + 1L
  forged_fold$fold$row_sha256 <- phase19_fold_row_sha256(forged_fold$fold)
  expect_error(
    phase19_validate_club_fold_source_evidence(
      evidence, forged_fold, accepted_fold = context$fold,
      accepted_protocol = context$protocol
    ), class = "phase19_club_evaluation_error"
  )

  forged_protocol <- source
  forged_protocol$protocol$protocol_sha256 <- strrep("f", 64L)
  expect_error(
    phase19_validate_club_fold_source_evidence(
      evidence, forged_protocol, accepted_fold = context$fold,
      accepted_protocol = context$protocol
    ), class = "phase19_club_evaluation_error"
  )
})

test_that("held-out provenance is excluded from fit tune and calibration", {
  context <- phase19_evaluation_test_context("heldout_league_transport")
  evidence <- phase19_evaluation_test_score(context)
  expect_true(all(
    evidence$role_provenance$excluded_competition_id ==
      context$fold$held_out_competition_id
  ))

  leaked <- context$provenance
  leaked$excluded_competition_id[[2L]] <- ""
  expect_error(
    phase19_score_club_fold(
      context$candidate, context$incumbent, context$outcomes, context$fold,
      context$protocol, context$support, leaked
    ), class = "phase19_club_evaluation_error"
  )
})

test_that("coverage grid cutoff domain and parent attacks fail without filtering", {
  context <- phase19_evaluation_test_context()
  attacks <- list()
  attacks$missing <- context$candidate
  attacks$missing$predictions <- attacks$missing$predictions[-1L, , drop = FALSE]
  attacks$duplicate <- context$candidate
  attacks$duplicate$predictions <- rbind(
    attacks$duplicate$predictions, attacks$duplicate$predictions[1L, , drop = FALSE]
  )
  attacks$grid <- context$candidate
  attacks$grid$distributions <- attacks$grid$distributions[-1L, , drop = FALSE]
  attacks$simplex <- context$candidate
  attacks$simplex$distributions$probability[[1L]] <- 2
  attacks$cutoff <- context$candidate
  attacks$cutoff$predictions$evidence_cutoff_exclusive <- "2025-04-02T00:00:00Z"
  attacks$domain <- context$candidate
  attacks$domain$predictions$forecast_domain <- "national_team"
  attacks$parent <- context$candidate
  attacks$parent$predictions$protocol_sha256 <- paste(rep("f", 64L), collapse = "")

  for (name in names(attacks)) {
    expect_error(
      phase19_score_club_fold(
        attacks[[name]], context$incumbent, context$outcomes, context$fold,
        context$protocol, context$support, context$provenance
      ), class = "phase19_club_evaluation_error", info = name
    )
  }
})

test_that("fold evaluation replay is canonical under source row permutation", {
  context <- phase19_evaluation_test_context()
  first <- phase19_evaluation_test_score(context)
  context$outcomes <- context$outcomes[2:1, , drop = FALSE]
  context$candidate$predictions <- context$candidate$predictions[2:1, , drop = FALSE]
  context$candidate$distributions <- context$candidate$distributions[
    rev(seq_len(nrow(context$candidate$distributions))), , drop = FALSE
  ]
  context$incumbent$predictions <- context$incumbent$predictions[2:1, , drop = FALSE]
  context$incumbent$distributions <- context$incumbent$distributions[
    rev(seq_len(nrow(context$incumbent$distributions))), , drop = FALSE
  ]
  second <- phase19_evaluation_test_score(context)
  expect_identical(first$evaluation_sha256, second$evaluation_sha256)
  expect_identical(first$fixture_scores_sha256, second$fixture_scores_sha256)
})

phase19_evaluation_test_clone_fold <- function(evidence, family, ordinal) {
  clone <- evidence
  clone$fold_id <- sprintf("club__%s__league-%02d__2025-%02d", family, ordinal, ordinal)
  clone$fold_family <- family
  clone$assessment_competition_id <- sprintf("league-%02d", ordinal)
  clone$assessment_season_id <- sprintf("2025-%02d", ordinal)
  clone$fold_row_sha256 <- digest::digest(
    paste("fold", family, ordinal), algo = "sha256", serialize = FALSE
  )
  clone$fixture_scores$fold_id <- clone$fold_id
  clone$fixture_scores$fold_family <- clone$fold_family
  clone$fixture_scores$competition_id <- clone$assessment_competition_id
  clone$fixture_scores$season_id <- clone$assessment_season_id
  clone$fold_summary$fold_id <- clone$fold_id
  clone$fold_summary$fold_family <- clone$fold_family
  clone$fold_summary$competition_id <- clone$assessment_competition_id
  clone$fold_summary$season_id <- clone$assessment_season_id
  clone$fixture_scores_sha256 <- phase18_hash_table_v2(
    clone$fixture_scores, key = c("model_id", "fixture_id", "metric"),
    schema_tag = "phase19-club-evaluation-fixture-scores-v1"
  )
  clone$fold_summary_sha256 <- phase18_hash_table_v2(
    clone$fold_summary, key = "fold_id",
    schema_tag = "phase19-club-evaluation-fold-summary-v1"
  )
  clone$evaluation_sha256 <- phase19_club_fold_evaluation_sha256(clone)
  clone
}

phase19_evaluation_test_evaluations <- local({
  cache <- NULL
  function() {
    if (is.null(cache)) {
      context <- phase19_evaluation_test_context()
      base <- phase19_evaluation_test_score(context)
      families <- rep(
        c("rolling_origin_league_season", "heldout_league_transport"), each = 3L
      )
      cache <<- lapply(seq_along(families), function(index) {
        phase19_evaluation_test_clone_fold(base, families[[index]], index)
      })
    }
    unserialize(serialize(cache, NULL))
  }
})

phase19_evaluation_test_promotion <- function(evaluations = phase19_evaluation_test_evaluations()) {
  if (!exists("phase19_load_fixture_club_evaluation_protocol", mode = "function")) {
    phase19_evaluation_test_load()
  }
  protocol <- phase19_load_fixture_club_evaluation_protocol()
  aggregate <- phase19_aggregate_club_evaluations(evaluations, protocol)
  replay <- phase19_club_reproducibility_evidence(
    evaluations, rev(evaluations), protocol
  )
  authority <- phase19_fixture_evaluation_authority(aggregate, protocol)
  integrity <- phase19_derive_club_integrity_evidence(
    aggregate, protocol, replay, authority
  )
  list(
    protocol = protocol, evaluations = evaluations, aggregate = aggregate,
    replay = replay, authority = authority, integrity = integrity,
    decision = phase19_evaluate_club_promotion(
      aggregate, protocol, replay, integrity, authority
    )
  )
}

test_that("fixture diagnostics pass while promotion remains fixture-ineligible", {
  result <- phase19_evaluation_test_promotion()
  decision <- result$decision

  expect_s3_class(result$aggregate, "phase19_club_evaluation_set")
  expect_identical(nrow(result$aggregate$fold_summaries), 6L)
  expect_identical(nrow(result$aggregate$family_summaries), 2L)
  expect_identical(nrow(result$aggregate$league_season_summaries), 6L)
  expect_identical(result$aggregate$paired_bootstrap$replicates, 10000L)
  expect_true(result$replay$reproducible)
  expect_identical(decision$diagnostic_gate_outcome, "pass")
  expect_identical(decision$authority_eligibility, "fixture_ineligible")
  expect_identical(decision$promotion_status, "ineligible_fixture")
  expect_identical(decision$selected_model_id, "club_elo_nb")
  expect_identical(decision$incumbent_id, "club_venue_nb")
  expect_identical(decision$gate_results$gate_id,
                   result$protocol$gate_registry$gate_id)
  expect_true(all(decision$gate_results$passed))
  expect_false(any(decision$gate_results$required[
    decision$gate_results$gate_id %in%
      c("current_ucl_club_coverage", "common_rating_component_coverage")
  ]))
  expect_match(decision$decision_sha256, "^[0-9a-f]{64}$")
  expect_silent(phase19_validate_club_promotion_decision(
    decision, result$aggregate, result$protocol, result$replay,
    result$integrity, result$authority
  ))
})

test_that("frozen threshold boundaries and breadth gates are exact", {
  result <- phase19_evaluation_test_promotion()
  metrics <- result$aggregate$metrics
  metrics$equal_fold_rps_delta <- -0.003
  metrics$paired_rps_ci_upper <- -1e-12
  metrics$rolling_origin_fold_breadth <- 2 / 3
  metrics$heldout_league_fold_breadth <- 2 / 3
  metrics$worst_fold_rps_regression <- 0.015
  metrics$equal_fold_brier_relative_regression <- 0.01
  metrics$equal_fold_log_loss_relative_regression <- 0.01
  metrics$fixed_bin_calibration_delta <- 0.01
  metrics$byte_reproducibility <- 1
  for (name in phase19_club_integrity_names()) metrics[[name]] <- 1
  passing <- phase19_apply_club_promotion_gates(
    metrics, result$protocol, "fixture"
  )
  expect_true(all(passing$passed))

  attacks <- list(
    equal_fold_rps_delta = -0.003 + 1e-12,
    paired_rps_ci_upper = 0,
    rolling_origin_fold_breadth = 2 / 3 - 1e-12,
    heldout_league_fold_breadth = 2 / 3 - 1e-12,
    worst_fold_rps_regression = 0.015 + 1e-12,
    equal_fold_brier_relative_regression = 0.01 + 1e-12,
    equal_fold_log_loss_relative_regression = 0.01 + 1e-12,
    fixed_bin_calibration_delta = 0.01 + 1e-12
  )
  for (field in names(attacks)) {
    changed <- metrics
    changed[[field]] <- attacks[[field]]
    gates <- phase19_apply_club_promotion_gates(changed, result$protocol, "fixture")
    expect_false(all(gates$passed), info = field)
  }
})

test_that("ties failures and every production prerequisite retain or block", {
  result <- phase19_evaluation_test_promotion()
  tied_folds <- lapply(result$evaluations, function(fold) {
    incumbent <- fold$fixture_scores[
      fold$fixture_scores$model_id == "club_venue_nb" &
        fold$fixture_scores$metric == "rps", c("fixture_id", "value"), drop = FALSE
    ]
    candidate_index <- which(
      fold$fixture_scores$model_id == "club_elo_nb" &
        fold$fixture_scores$metric == "rps"
    )
    fold$fixture_scores$value[candidate_index] <- incumbent$value[
      match(fold$fixture_scores$fixture_id[candidate_index], incumbent$fixture_id)
    ]
    fold$fold_summary$candidate_rps <- fold$fold_summary$incumbent_rps
    fold$fold_summary$rps_delta <- 0
    fold$fixture_scores_sha256 <- phase18_hash_table_v2(
      fold$fixture_scores, key = c("model_id", "fixture_id", "metric"),
      schema_tag = "phase19-club-evaluation-fixture-scores-v1"
    )
    fold$fold_summary_sha256 <- phase18_hash_table_v2(
      fold$fold_summary, key = "fold_id",
      schema_tag = "phase19-club-evaluation-fold-summary-v1"
    )
    fold$evaluation_sha256 <- phase19_club_fold_evaluation_sha256(fold)
    fold
  })
  tied <- phase19_aggregate_club_evaluations(tied_folds, result$protocol)
  tied_replay <- phase19_club_reproducibility_evidence(tied, tied, result$protocol)
  tied_authority <- phase19_fixture_evaluation_authority(tied, result$protocol)
  decision <- phase19_evaluate_club_promotion(
    tied, result$protocol, tied_replay,
    phase19_derive_club_integrity_evidence(tied, result$protocol, tied_replay,
                                           tied_authority),
    tied_authority
  )
  expect_identical(decision$diagnostic_gate_outcome, "fail")
  expect_identical(decision$promotion_status, "retained")
  expect_identical(decision$selected_model_id, "club_venue_nb")

  expect_identical(
    phase19_club_production_block_reason("blocked", "blocked", "blocked", "blocked"),
    "no_accepted_club_history"
  )
  expect_identical(
    phase19_club_production_block_reason("ready", "blocked", "blocked", "blocked"),
    "no_accepted_current_ucl"
  )
  expect_identical(
    phase19_club_production_block_reason("ready", "ready", "blocked", "blocked"),
    "protocol_policy_not_approved"
  )
  expect_identical(
    phase19_club_production_block_reason("ready", "ready", "ready", "blocked"),
    "fold_inventory_not_approved"
  )
})

test_that("replay drift and decision relabeling cannot become promotion authority", {
  result <- phase19_evaluation_test_promotion()
  shell <- structure(
    list(evaluation_set_sha256 = strrep("a", 64L)),
    class = c("phase19_club_evaluation_set", "list")
  )
  expect_error(
    phase19_club_reproducibility_evidence(shell, shell, result$protocol),
    class = "phase19_club_evaluation_error"
  )
  drift <- result$evaluations
  drift[[1L]] <- phase19_evaluation_test_clone_fold(
    drift[[1L]], drift[[1L]]$fold_family, 99L
  )
  replay <- phase19_club_reproducibility_evidence(
    result$evaluations, drift, result$protocol
  )
  expect_false(replay$reproducible)
  decision <- phase19_evaluate_club_promotion(
    result$aggregate, result$protocol, replay,
    phase19_derive_club_integrity_evidence(
      result$aggregate, result$protocol, replay, result$authority
    ), result$authority
  )
  expect_identical(decision$diagnostic_gate_outcome, "fail")
  expect_true("byte_reproducibility_failed" %in% decision$reason_codes)

  forged <- result$decision
  forged$authority_eligibility <- "production"
  forged$promotion_status <- "promoted"
  forged$decision_sha256 <- phase19_club_promotion_decision_sha256(forged)
  expect_error(
    phase19_validate_club_promotion_decision(
      forged, result$aggregate, result$protocol, result$replay,
      result$integrity, result$authority
    ), class = "phase19_club_evaluation_error"
  )

  forged_authority <- result$authority
  forged_authority$authority_mode <- "production"
  forged_authority$fixture_authority <- FALSE
  forged_authority$status <- "ready"
  forged_authority$reason_code <- ""
  forged_authority$production_eligible <- TRUE
  forged_authority$history_snapshot_sha256 <- strrep("a", 64L)
  forged_authority$current_snapshot_sha256 <- strrep("b", 64L)
  forged_authority$fold_registry_sha256 <- strrep("c", 64L)
  forged_authority$fold_review_sha256 <- strrep("d", 64L)
  forged_authority$current_ucl_club_coverage <- 1
  forged_authority$common_component_coverage <- 1
  forged_authority$authority_sha256 <- phase19_club_authority_sha256(forged_authority)
  class(forged_authority) <- class(result$authority)
  expect_error(
    phase19_evaluate_club_promotion(
      result$aggregate, result$protocol, result$replay,
      result$integrity, forged_authority
    ), class = "phase19_club_evaluation_error"
  )
})

test_that("production promotion ignores a self-hashed replay copied from accepted output", {
  result <- phase19_evaluation_test_promotion()
  production <- result$protocol
  production$authority_mode <- "production"
  production$fixture_authority <- FALSE
  production$production_eligible <- TRUE
  accepted_output_sha256 <- phase19_club_evaluation_complete_output_sha256(
    result$aggregate
  )
  seed <- phase19_club_evaluation_seed(production, "club_isolated_replay_v1")
  shell <- list(
    schema_version = "phase19-club-evaluation-reproducibility-v1",
    hash_encoding_version = phase18_canonical_encoding_v2(),
    forecast_domain = "club", seed_id = as.character(seed$seed_id[[1L]]),
    seed = as.integer(seed$seed[[1L]]),
    first_evaluation_sha256 = accepted_output_sha256,
    second_evaluation_sha256 = accepted_output_sha256,
    reproducible = TRUE, evidence_sha256 = ""
  )
  shell$evidence_sha256 <- phase19_club_reproducibility_sha256(shell)
  shell <- structure(
    shell, class = c(
      "phase19_club_production_reproducibility_evidence",
      "phase19_club_reproducibility_evidence", "list"
    )
  )
  direct_validator <- tryCatch(
    phase19_club_validate_reproducibility(shell, production),
    error = function(error) error
  )
  expect_s3_class(direct_validator, "phase19_club_evaluation_error")
  expect_identical(as.character(direct_validator$reason_code),
                   "reproducibility_source_invalid")
  expect_error(
    phase19_club_reproducibility_evidence_build(
      result$aggregate, result$aggregate, production,
      accepted_evaluation = result$aggregate, source_evidence = list(),
      accepted_fold_protocol = list(), allow_production = TRUE
    ),
    class = "phase19_club_evaluation_error",
    regexp = "fixed-source production wrapper"
  )
  rejected <- tryCatch(
    phase19_evaluate_club_promotion(
      result$aggregate, production, shell, result$integrity, result$authority
    ),
    error = function(error) error
  )
  expect_s3_class(rejected, "phase19_club_evaluation_error")
  expect_true(as.character(rejected$reason_code) %in% c(
    "evaluation_source_invalid", "evaluation_authority_invalid",
    "reproducibility_source_invalid"
  ))
})

test_that("production source graphs reject a deterministic alternate rating replay", {
  phase19_evaluation_test_load()
  phase19_test_load()
  root <- phase19_test_fixture_root("rating-replay-identity")
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  training <- phase19_load_fixture_club_training_snapshot(root)
  current <- phase19_load_fixture_current_ucl_club_snapshot(root)
  ids <- c("club_alpha", "club_beta", "club_gamma", "club_delta")
  clubs <- current$clubs[seq_along(ids), , drop = FALSE]
  clubs$provider_club_id <- as.character(9000L + seq_along(ids))
  clubs$club_id <- ids
  clubs$display_name <- paste("Identity", ids)
  clubs$canonical_name <- clubs$display_name
  clubs$row_sha256 <- phase18_ucl_projected_row_hash(clubs)
  clubs <- clubs[order(clubs$club_id, method = "radix"), , drop = FALSE]
  rownames(clubs) <- NULL
  current$clubs <- clubs
  current$source_clubs <- clubs
  current$club_count <- as.integer(nrow(clubs))
  current$roster_sha256 <- phase18_hash_table_v2(
    clubs, key = "club_id", schema_tag = "phase19-current-ucl-club-roster-v1"
  )
  current$source_club_table_sha256 <- phase19_current_ucl_source_clubs_sha256(clubs)
  current$snapshot_sha256 <- phase19_current_snapshot_sha256(current)
  phase19_validate_current_ucl_club_snapshot(current, "fixture")
  canonical_parameters <- phase19_club_rating_parameters(
    base_rating = 1500, home_advantage = 60, k_factor = 20,
    inactivity_factor = 0.995
  )
  alternate_parameters <- phase19_club_rating_parameters(
    base_rating = 1500, home_advantage = 60, k_factor = 30,
    inactivity_factor = 0.995
  )
  canonical <- phase19_replay_club_ratings(
    training, current, canonical_parameters, cutoff_utc = training$cutoff_utc
  )
  alternate <- phase19_replay_club_ratings(
    training, current, alternate_parameters, cutoff_utc = training$cutoff_utc
  )
  source_evidence <- list(
    history_snapshot = training, current_snapshot = current,
    fold_protocol = list(), rating_replay = canonical
  )
  graph <- list(
    rating_replay = canonical,
    authority = list(source_evidence = source_evidence)
  )
  expect_silent(phase19_club_assert_production_rating_replay_identity(graph))
  graph$rating_replay <- alternate
  expect_error(
    phase19_club_assert_production_rating_replay_identity(graph),
    class = "phase19_club_evaluation_error",
    regexp = "accepted authority replay"
  )
})

test_that("production promotion obtains replay from its fixed-source boundary", {
  result <- phase19_evaluation_test_promotion()
  production <- result$protocol
  production$authority_mode <- "production"
  production$fixture_authority <- FALSE
  production$production_eligible <- TRUE
  caller_shell <- result$replay
  caller_shell$reproducible <- FALSE
  caller_shell$evidence_sha256 <- phase19_club_reproducibility_sha256(caller_shell)
  class(caller_shell) <- c(
    "phase19_club_production_reproducibility_evidence",
    "phase19_club_reproducibility_evidence", "list"
  )
  wrapper_replay <- result$replay
  accepted_output_sha256 <- phase19_club_evaluation_complete_output_sha256(
    result$aggregate
  )
  wrapper_replay$first_evaluation_sha256 <- accepted_output_sha256
  wrapper_replay$second_evaluation_sha256 <- accepted_output_sha256
  wrapper_replay$reproducible <- TRUE
  wrapper_replay$evidence_sha256 <- phase19_club_reproducibility_sha256(wrapper_replay)
  class(wrapper_replay) <- c(
    "phase19_club_reproducibility_evidence", "list"
  )
  source_authority <- result$authority
  source_authority$source_evidence <- list(
    history_snapshot = list(), current_snapshot = list(),
    fold_protocol = list(), rating_replay = list()
  )
  source_graph <- list(
    history_snapshot = list(), current_snapshot = list(), protocol = production,
    evaluation = result$aggregate, authority = source_authority,
    fold_protocol = list(), rating_replay = list(), integrity = result$integrity,
    decision = NULL, fold_source_evidence = NULL
  )
  originals <- mget(c(
    "phase19_validate_club_evaluation_set",
    "phase19_club_validate_authority",
    "phase19_validate_club_integrity_evidence",
    "phase19_production_club_reproducibility_evidence",
    "phase19_club_evaluation_metrics_sha256"
  ), envir = .GlobalEnv)
  on.exit(lapply(names(originals), function(name) {
    assign(name, originals[[name]], envir = .GlobalEnv)
  }), add = TRUE)
  wrapper_calls <- 0L
  source_seen <- NULL
  integrity_replay <- NULL
  metrics_seen <- NULL
  assign("phase19_validate_club_evaluation_set", function(...) invisible(NULL), envir = .GlobalEnv)
  assign("phase19_club_validate_authority", function(...) invisible(NULL), envir = .GlobalEnv)
  assign("phase19_validate_club_integrity_evidence", function(
      evidence, evaluation, protocol, replay, authority, source_evidence = NULL,
      production_source_authority = NULL
  ) {
    integrity_replay <<- replay
    invisible(evidence)
  }, envir = .GlobalEnv)
  assign("phase19_production_club_reproducibility_evidence", function(
      evaluation, source_authority
  ) {
    wrapper_calls <<- wrapper_calls + 1L
    source_seen <<- source_authority
    wrapper_replay
  }, envir = .GlobalEnv)
  original_metrics_hash <- originals[["phase19_club_evaluation_metrics_sha256"]]
  assign("phase19_club_evaluation_metrics_sha256", function(metrics) {
    metrics_seen <<- metrics
    original_metrics_hash(metrics)
  }, envir = .GlobalEnv)
  decision <- phase19_evaluate_club_promotion(
    result$aggregate, production, caller_shell, result$integrity, source_authority,
    production_source_authority = source_graph
  )
  expect_identical(wrapper_calls, 1L)
  expect_identical(source_seen$evaluation, result$aggregate)
  expect_identical(source_seen$integrity, result$integrity)
  expect_identical(integrity_replay, wrapper_replay)
  expect_identical(metrics_seen$byte_reproducibility, 1)
  expect_identical(decision$reproducibility_evidence_sha256,
                   wrapper_replay$evidence_sha256)
  expect_false(identical(decision$reproducibility_evidence_sha256,
                         caller_shell$evidence_sha256))
})

test_that("production evaluation validation requires exact fold source evidence", {
  result <- phase19_evaluation_test_promotion()
  production <- result$protocol
  production$authority_mode <- "production"
  production$fixture_authority <- FALSE
  production$production_eligible <- TRUE
  expect_error(
    phase19_validate_club_evaluation_set(result$aggregate, production),
    class = "phase19_club_evaluation_error"
  )
  named_but_opaque <- setNames(
    replicate(length(result$aggregate$fold_evaluations), list(), simplify = FALSE),
    vapply(result$aggregate$fold_evaluations, `[[`, character(1), "fold_id")
  )
  expect_error(
    phase19_validate_club_evaluation_set(result$aggregate, production, named_but_opaque),
    class = "phase19_club_evaluation_error"
  )
})

test_that("promotion integrity rejects caller-asserted logical lists", {
  bare <- stats::setNames(as.list(rep(TRUE, 11L)), phase19_club_integrity_names())
  expect_error(
    phase19_club_integrity_sha256(bare),
    class = "phase19_club_evaluation_error"
  )
})
