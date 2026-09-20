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
