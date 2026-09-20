library(testthat)

phase19_calibration_test_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/", mustWork = TRUE
)

phase19_calibration_test_load <- function() {
  paths <- c(
    "R/common/phase18_canonical_hash.R",
    "R/club/model_contract.R",
    "R/evaluation/proper_scores.R",
    "R/club/evaluation_protocol.R",
    "R/club/goal_model.R"
  )
  for (path in file.path(phase19_calibration_test_root, paths)) {
    if (!file.exists(path)) stop("Missing Phase 19 calibration dependency: ", path, call. = FALSE)
    source(path, local = .GlobalEnv)
  }
  module <- file.path(phase19_calibration_test_root, "R/club/calibration.R")
  if (!file.exists(module)) stop("RED: missing Phase 19 club calibration module", call. = FALSE)
  source(module, local = .GlobalEnv)
  invisible(TRUE)
}

phase19_calibration_test_fold <- function(protocol) {
  calibration_ids <- sprintf("cal_%03d", seq_len(60L))
  declared_ids <- c("assessment_a", "assessment_b")
  training_ids <- c("fit_a", "fit_b")
  row <- data.frame(
    schema_version = "phase19-club-fold-v1",
    hash_encoding_version = phase18_canonical_encoding_v2(),
    forecast_domain = "club", authority_mode = "fixture",
    fixture_authority = TRUE,
    fold_id = "club__heldout_league_transport__league-z__2025-26",
    fold_family = "heldout_league_transport",
    assessment_competition_id = "league-z", assessment_season_id = "2025-26",
    assessment_start_utc = "2025-03-01T00:00:00Z",
    assessment_end_utc = "2025-05-31T00:00:00Z",
    training_cutoff_exclusive = "2025-01-01T00:00:00Z",
    calibration_cutoff_exclusive = "2025-03-01T00:00:00Z",
    declared_fixture_ids = paste(sort(declared_ids), collapse = "|"),
    declared_fixture_count = as.integer(length(declared_ids)),
    declared_fixture_sha256 = phase19_fold_id_sha256(declared_ids, "declared"),
    training_fixture_ids = paste(sort(training_ids), collapse = "|"),
    training_fixture_count = as.integer(length(training_ids)),
    training_fixture_sha256 = phase19_fold_id_sha256(training_ids, "training"),
    calibration_fixture_ids = paste(sort(calibration_ids), collapse = "|"),
    calibration_fixture_count = as.integer(length(calibration_ids)),
    calibration_fixture_sha256 = phase19_fold_id_sha256(calibration_ids, "calibration"),
    held_out_competition_id = "league-z",
    fit_excluded_competition_id = "league-z",
    tuning_excluded_competition_id = "league-z",
    calibration_excluded_competition_id = "league-z",
    eligibility_status = "eligible", support_reason_code = "",
    accepted_generation_id = "phase19-calibration-fixture",
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

phase19_calibration_test_rows <- function(fold, candidate_id = "club_elo_nb") {
  fixture_ids <- strsplit(fold$calibration_fixture_ids, "|", fixed = TRUE)[[1L]]
  observed <- rep(c("home", "draw", "away"), length.out = length(fixture_ids))
  probability <- rbind(
    home = c(0.58, 0.24, 0.18),
    draw = c(0.37, 0.39, 0.24),
    away = c(0.25, 0.25, 0.50)
  )[observed, , drop = FALSE]
  rows <- data.frame(
    fixture_id = fixture_ids, candidate_id = candidate_id,
    outer_fold_id = fold$fold_id,
    inner_fold_id = rep(c("inner_01", "inner_02", "inner_03"), length.out = length(fixture_ids)),
    evidence_role = "inner_out_of_fold", competition_id = "league-a",
    event_date = "2025-02-01", kickoff_utc = "2025-02-01T18:00:00Z",
    kickoff_precision = "instant",
    completion_not_before_utc = "2025-02-01T20:00:00Z",
    evidence_available_at_utc = "2025-02-01T20:00:00Z",
    counts_for_model = TRUE,
    p_home_raw = probability[, 1L], p_draw_raw = probability[, 2L],
    p_away_raw = probability[, 3L], observed_class = observed,
    source_grid_sha256 = if (identical(candidate_id, "uniform_1x2")) "" else
      vapply(fixture_ids, function(id) digest::digest(paste0("grid-", id), algo = "sha256", serialize = FALSE), character(1)),
    source_prediction_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE
  )
  rows$source_prediction_sha256 <- phase19_club_calibration_source_row_sha256(rows)
  rows
}

phase19_calibration_test_context <- function(candidate_id = "club_elo_nb") {
  phase19_calibration_test_load()
  protocol <- phase19_load_fixture_club_evaluation_protocol()
  fold <- phase19_calibration_test_fold(protocol)
  rows <- phase19_calibration_test_rows(fold, candidate_id)
  candidate <- protocol$candidate_registry[
    protocol$candidate_registry$model_id == candidate_id, , drop = FALSE
  ]
  list(protocol = protocol, fold = fold, rows = rows, candidate = candidate)
}

test_that("nested prior-only evidence fits and applies one club calibrator", {
  context <- phase19_calibration_test_context()
  calibrator <- phase19_fit_club_calibrator(
    context$rows, context$fold, context$candidate, context$protocol
  )

  expect_s3_class(calibrator, "phase19_club_calibrator")
  expect_identical(calibrator$fit_status, "fitted")
  expect_identical(calibrator$forecast_domain, "club")
  expect_true(is.finite(as.numeric(calibrator$temperature)))
  expect_true(as.numeric(calibrator$temperature) >= 0.25)
  expect_true(as.numeric(calibrator$temperature) <= 4)
  expect_identical(calibrator$row_count, 60L)
  expect_identical(
    c(calibrator$class_count_home, calibrator$class_count_draw,
      calibrator$class_count_away), c(20L, 20L, 20L)
  )
  expect_false(calibrator$labels_embedded)
  expect_true(calibrator$distribution_unchanged)
  expect_false(calibrator$production_eligible)
  expect_match(calibrator$calibrator_sha256, "^[0-9a-f]{64}$")
  expect_silent(phase19_validate_club_calibrator(calibrator, require_fitted = TRUE))

  predictions <- data.frame(
    fixture_id = c("assessment_b", "assessment_a"),
    candidate_id = "club_elo_nb",
    evidence_cutoff_exclusive = "2025-03-01T00:00:00Z",
    p_home = c(0.31, 0.62), p_draw = c(0.29, 0.23), p_away = c(0.40, 0.15),
    p_over_2_5 = c(0.55, 0.63), p_btts = c(0.48, 0.57),
    expected_home_goals = c(1.1, 1.8), expected_away_goals = c(1.4, 0.8),
    likely_home_goals = c(1L, 2L), likely_away_goals = c(1L, 1L),
    distribution_sha256 = vapply(c("assessment_b", "assessment_a"), function(id) {
      digest::digest(paste0("assessment-grid-", id), algo = "sha256", serialize = FALSE)
    }, character(1)), stringsAsFactors = FALSE, check.names = FALSE
  )
  applied <- phase19_apply_club_calibrator(calibrator, predictions, context$fold)

  expect_identical(applied$predictions$fixture_id, c("assessment_a", "assessment_b"))
  expect_equal(
    rowSums(applied$predictions[, c("p_home_calibrated", "p_draw_calibrated", "p_away_calibrated")]),
    rep(1, 2), tolerance = 1e-12
  )
  expect_identical(applied$predictions$distribution_sha256,
                   applied$predictions$source_distribution_sha256)
  expect_identical(applied$predictions$p_over_2_5,
                   applied$predictions$p_over_2_5_raw)
  expect_identical(applied$predictions$expected_home_goals,
                   applied$predictions$expected_home_goals_raw)
  expect_true(all(applied$predictions$distribution_unchanged))
  expect_identical(applied$primary_probability_view, "not_selected")
})

test_that("all four frozen candidate roles accept the same prior-only mechanism", {
  phase19_calibration_test_load()
  protocol <- phase19_load_fixture_club_evaluation_protocol()
  fold <- phase19_calibration_test_fold(protocol)
  for (candidate_id in protocol$candidate_registry$model_id) {
    rows <- phase19_calibration_test_rows(fold, candidate_id)
    candidate <- protocol$candidate_registry[
      protocol$candidate_registry$model_id == candidate_id, , drop = FALSE
    ]
    calibrator <- phase19_fit_club_calibrator(rows, fold, candidate, protocol)
    expect_identical(calibrator$fit_status, "fitted", info = candidate_id)
    expect_identical(calibrator$candidate_id, candidate_id)
    expect_false(calibrator$production_eligible)
  }
})

test_that("temporal role source support and optimizer attacks have no fitted authority", {
  context <- phase19_calibration_test_context()
  attacks <- list()
  attacks$outer_label <- context$rows
  attacks$outer_label$fixture_id[[1L]] <- "assessment_a"
  attacks$outer_label$source_prediction_sha256 <-
    phase19_club_calibration_source_row_sha256(attacks$outer_label)
  attacks$heldout <- context$rows
  attacks$heldout$competition_id[[1L]] <- context$fold$held_out_competition_id
  attacks$heldout$source_prediction_sha256 <-
    phase19_club_calibration_source_row_sha256(attacks$heldout)
  attacks$at_cutoff <- context$rows
  attacks$at_cutoff$evidence_available_at_utc[[1L]] <-
    context$fold$calibration_cutoff_exclusive
  attacks$at_cutoff$source_prediction_sha256 <-
    phase19_club_calibration_source_row_sha256(attacks$at_cutoff)
  attacks$source_drift <- context$rows
  attacks$source_drift$p_home_raw[[1L]] <- attacks$source_drift$p_home_raw[[1L]] - 0.01
  attacks$source_drift$p_draw_raw[[1L]] <- attacks$source_drift$p_draw_raw[[1L]] + 0.01
  attacks$insufficient_support <- context$rows[seq_len(30L), , drop = FALSE]

  for (name in names(attacks)) {
    result <- phase19_fit_club_calibrator(
      attacks[[name]], context$fold, context$candidate, context$protocol
    )
    expect_identical(result$fit_status, "failed", info = name)
    expect_false(result$authoritative, info = name)
    expect_false(result$production_eligible, info = name)
    expect_true(nzchar(result$failure_reason_code), info = name)
    expect_error(
      phase19_validate_club_calibrator(result, require_fitted = TRUE),
      class = "phase19_club_calibration_error", info = name
    )
  }

  optimizer_failure <- phase19_fit_club_calibrator(
    context$rows, context$fold, context$candidate, context$protocol,
    optimizer_fn = function(...) stop("fixture optimizer failure")
  )
  expect_identical(optimizer_failure$fit_status, "failed")
  expect_identical(optimizer_failure$failure_reason_code, "optimizer_failed")
  expect_false(optimizer_failure$authoritative)
  expect_error(
    phase19_apply_club_calibrator(optimizer_failure, data.frame(), context$fold),
    class = "phase19_club_calibration_error"
  )
})

test_that("calibrator identity is canonical and binds every frozen parent", {
  context <- phase19_calibration_test_context()
  first <- phase19_fit_club_calibrator(
    context$rows, context$fold, context$candidate, context$protocol
  )
  second <- phase19_fit_club_calibrator(
    context$rows[rev(seq_len(nrow(context$rows))), , drop = FALSE],
    context$fold, context$candidate, context$protocol
  )
  expect_identical(first$calibrator_sha256, second$calibrator_sha256)
  expect_identical(first$source_predictions_sha256, second$source_predictions_sha256)

  drift <- first
  drift$recipe_sha256 <- paste(rep("f", 64L), collapse = "")
  expect_error(
    phase19_validate_club_calibrator(drift),
    class = "phase19_club_calibration_error"
  )
  drift <- first
  drift$calibration_cutoff_exclusive <- "2025-04-01T00:00:00Z"
  expect_error(
    phase19_validate_club_calibrator(drift),
    class = "phase19_club_calibration_error"
  )
})
