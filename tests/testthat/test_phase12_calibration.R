library(testthat)

project_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))
source(file.path(project_root, "R/release/freeze_manifest.R"))
source(file.path(project_root, "R/calibration/inner_oof.R"))
source(file.path(project_root, "R/calibration/probability_calibration.R"))
source(file.path(project_root, "R/calibration/calibration_selection.R"))

# Validation 12-00-01: calibration contracts are synthetic and chronology-aware.
# Validation 12-00-02: no holdout artifact is opened by the Wave 0 scaffold.

phase12_calibration_synthetic_oof <- function() {
  data.frame(
    candidate_id = rep("candidate_alpha", 4L),
    track_id = rep("updating", 4L),
    outer_edition_id = rep("wc2010", 4L),
    inner_edition_id = rep(c("wc2002", "euro2004"), each = 2L),
    fixture_id = paste0("synthetic_fixture_", seq_len(4L)),
    evidence_cutoff_exclusive = as.Date(c(
      "2002-06-01", "2002-06-02", "2004-06-01", "2004-06-02"
    )),
    p_home_raw = c(0.50, 0.45, 0.40, 0.35),
    p_draw_raw = c(0.25, 0.30, 0.35, 0.30),
    p_away_raw = c(0.25, 0.25, 0.25, 0.35),
    observed_class = c("home", "draw", "away", "home"),
    source_prediction_sha256 = strrep("a", 64),
    stringsAsFactors = FALSE
  )
}

phase12_calibration_require_api <- function(required, owner) {
  missing <- required[!vapply(required, exists, logical(1), mode = "function")]
  if (length(missing)) {
    stop(
      paste0("Wave 0 RED contract awaits Phase 12 ", owner, " API: ",
             paste(missing, collapse = ", ")),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

test_that("12-00-01 calibration fixture preserves a strict prior-only contract", {
  fixture <- phase12_calibration_synthetic_oof()
  expect_equal(nrow(fixture), 4L)
  expect_true(all(fixture$evidence_cutoff_exclusive < as.Date("2010-01-01")))
  expect_true(all(abs(fixture$p_home_raw + fixture$p_draw_raw + fixture$p_away_raw - 1) < 1e-12))
  expect_identical(unique(fixture$candidate_id), "candidate_alpha")
  expect_identical(unique(fixture$track_id), "updating")
})

test_that("12-00-01 calibration owner gate names only downstream APIs", {
  expect_invisible(phase12_calibration_require_api(
    c(
      "assemble_phase12_inner_oof",
      "phase12_calibration_recipe",
      paste0("fit", "_phase12_", "1x2_calibrator"),
      "apply_phase12_1x2_calibrator",
      "compare_phase12_raw_calibrated",
      "select_phase12_primary_probability_view"
    ),
    "calibration"
  ))
})

phase12_calibration_synthetic_inputs <- function() {
  editions <- c("wc2002", "euro2004", "wc2006", "euro2008")
  edition_dates <- as.Date(c("2002-06-02", "2004-06-02", "2006-06-02", "2008-06-02"))
  n <- 60L
  edition_index <- rep(seq_along(editions), each = 15L)
  fixture_id <- paste0("synthetic_oof_", seq_len(n))
  classes <- rep(c("home", "draw", "away"), each = 20L)
  fixtures <- data.frame(
    edition_id = editions[edition_index], fixture_id = fixture_id,
    actual_completion_date = edition_dates[edition_index],
    boundary_id = paste0(editions[edition_index], "__update"),
    regulation_home_goals = ifelse(classes == "home", 1L, ifelse(classes == "draw", 0L, 0L)),
    regulation_away_goals = ifelse(classes == "away", 1L, 0L), score_eligible = TRUE,
    stringsAsFactors = FALSE
  )
  boundaries <- rbind(
    data.frame(
      boundary_id = paste0(editions, "__frozen"), edition_id = editions,
      sequence = 0L, track = "frozen", assessment_date = edition_dates,
      evidence_cutoff_exclusive = edition_dates, prior_boundary_id = "",
      stringsAsFactors = FALSE
    ),
    data.frame(
      boundary_id = paste0(editions, "__update"), edition_id = editions,
      sequence = 1L, track = "updating", assessment_date = edition_dates,
      evidence_cutoff_exclusive = edition_dates, prior_boundary_id = "",
      stringsAsFactors = FALSE
    )
  )
  predictions <- data.frame(
    candidate_id = "phase11_rf_dynamic_elo_open", track_id = "updating",
    edition_id = editions[edition_index], fixture_id = fixture_id,
    p_home_raw = ifelse(classes == "home", 0.60, 0.20),
    p_draw_raw = ifelse(classes == "draw", 0.60, 0.20),
    p_away_raw = ifelse(classes == "away", 0.60, 0.20),
    observed_class = classes,
    source_prediction_sha256 = vapply(seq_len(n), function(i) digest::digest(paste("source", i), algo = "sha256", serialize = FALSE), character(1)),
    max_evidence_date = edition_dates[edition_index] - 2L,
    stringsAsFactors = FALSE
  )
  list(predictions = predictions, fixtures = fixtures, boundaries = boundaries)
}

test_that("12-02-01 assembles only prior candidate/track inner OOF after the freeze", {
  inputs <- phase12_calibration_synthetic_inputs()
  oof <- assemble_phase12_inner_oof(
    inputs$predictions, inputs$fixtures, inputs$boundaries,
    candidate_id = "phase11_rf_dynamic_elo_open", track_id = "updating",
    outer_edition_id = "wc2010"
  )
  expect_equal(nrow(oof), 60L)
  expect_true(all(oof$inner_edition_id != "wc2010"))
  expect_true(all(oof$evidence_cutoff_exclusive > as.Date("2000-01-01")))
  expect_true(all(c("boundary_id", "source_prediction_sha256", "max_evidence_date") %in% names(oof)))
  expect_true(all(abs(oof$p_home_raw + oof$p_draw_raw + oof$p_away_raw - 1) < 1e-12))
  expect_equal(length(unique(oof$fixture_id)), 60L)
})

test_that("12-02-01 frozen recipe and repeated fit are deterministic", {
  inputs <- phase12_calibration_synthetic_inputs()
  oof <- assemble_phase12_inner_oof(inputs$predictions, inputs$fixtures, inputs$boundaries, "phase11_rf_dynamic_elo_open", "updating", "wc2010")
  recipe <- phase12_calibration_recipe()
  first <- fit_phase12_1x2_calibrator(oof, "phase11_rf_dynamic_elo_open", "updating", "wc2010", recipe = recipe, boundaries = inputs$boundaries)
  second <- fit_phase12_1x2_calibrator(oof, "phase11_rf_dynamic_elo_open", "updating", "wc2010", recipe = recipe, boundaries = inputs$boundaries)
  expect_identical(first$fit_status, "fitted")
  expect_identical(first$temperature, second$temperature)
  expect_identical(first$manifest_row, second$manifest_row)
  calibrated <- apply_phase12_1x2_calibrator(first, c(home = 0.5, draw = 0.3, away = 0.2))
  expect_true(abs(sum(calibrated) - 1) < 1e-12)
  expect_true(all(calibrated >= 0 & calibrated <= 1))
})

test_that("12-02-02 sparse history returns an explicit raw fallback", {
  inputs <- phase12_calibration_synthetic_inputs()
  oof <- assemble_phase12_inner_oof(inputs$predictions[1, , drop = FALSE], inputs$fixtures[1, , drop = FALSE], inputs$boundaries, "phase11_rf_dynamic_elo_open", "updating", "wc2010")
  fallback <- fit_phase12_1x2_calibrator(oof, "phase11_rf_dynamic_elo_open", "updating", "wc2010")
  expect_identical(fallback$fit_status, "raw_fallback")
  expect_true(nzchar(fallback$fallback_reason))
  expect_identical(apply_phase12_1x2_calibrator(fallback, c(home = 0.5, draw = 0.3, away = 0.2)), c(home = 0.5, draw = 0.3, away = 0.2))
  empty <- oof[FALSE, , drop = FALSE]
  empty_fallback <- fit_phase12_1x2_calibrator(empty, "phase11_rf_dynamic_elo_open", "updating", "wc2010")
  expect_identical(empty_fallback$fit_status, "raw_fallback")
})

test_that("12-02-02 chronology, identity, and holdout guards fail closed", {
  inputs <- phase12_calibration_synthetic_inputs()
  oof <- assemble_phase12_inner_oof(inputs$predictions, inputs$fixtures, inputs$boundaries, "phase11_rf_dynamic_elo_open", "updating", "wc2010")
  mixed <- oof; mixed$candidate_id[[1L]] <- "other_candidate"
  expect_error(validate_phase12_inner_oof_chronology(mixed, "phase11_rf_dynamic_elo_open", "updating", "wc2010", inputs$boundaries), "mixed|identity")
  future <- oof; future$inner_edition_id[[1L]] <- "wc2014"
  expect_error(validate_phase12_inner_oof_chronology(future, "phase11_rf_dynamic_elo_open", "updating", "wc2010", inputs$boundaries), "prior|chronology")
  same_cutoff <- oof; same_cutoff$max_evidence_date[[1L]] <- same_cutoff$evidence_cutoff_exclusive[[1L]]
  expect_error(validate_phase12_inner_oof_chronology(same_cutoff, "phase11_rf_dynamic_elo_open", "updating", "wc2010", inputs$boundaries), "precede|cutoff")
  invalid_probability <- oof; invalid_probability$p_home_raw[[1L]] <- 0.9
  expect_error(validate_phase12_inner_oof_chronology(invalid_probability, "phase11_rf_dynamic_elo_open", "updating", "wc2010", inputs$boundaries), "sum|probabil")
  calibrator <- fit_phase12_1x2_calibrator(oof, "phase11_rf_dynamic_elo_open", "updating", "wc2010")
  invalid_optimizer <- calibrator; invalid_optimizer$optimizer_convergence <- 1L
  expect_error(validate_phase12_calibrator(invalid_optimizer), "optimizer")
  holdout_calls <- 0L
  holdout <- data.frame(edition_id = "wc2026", fixture_id = "wc2026_synthetic", actual_home_goals = 1L, stringsAsFactors = FALSE)
  expect_error(guard_benchmark_purpose(holdout, "calibration", adapter = function(x) { holdout_calls <<- holdout_calls + 1L; x }), "sealed|wc2026")
  expect_identical(holdout_calls, 0L)
})

test_that("12-02-02 provenance row retains frozen identity, support, and source hash", {
  inputs <- phase12_calibration_synthetic_inputs()
  oof <- assemble_phase12_inner_oof(inputs$predictions, inputs$fixtures, inputs$boundaries, "phase11_rf_dynamic_elo_open", "updating", "wc2010")
  calibrator <- fit_phase12_1x2_calibrator(oof, "phase11_rf_dynamic_elo_open", "updating", "wc2010")
  row <- phase12_calibration_manifest_row(calibrator)
  expect_identical(row$candidate_id[[1L]], "phase11_rf_dynamic_elo_open")
  expect_identical(row$track_id[[1L]], "updating")
  expect_identical(row$outer_edition_id[[1L]], "wc2010")
  expect_identical(row$row_count[[1L]], 60L)
  expect_true(all(c(row$class_count_home[[1L]], row$class_count_draw[[1L]], row$class_count_away[[1L]]) == 20L))
  expect_match(row$recipe_sha256[[1L]], "^[0-9a-f]{64}$")
  expect_match(row$source_prediction_sha256[[1L]], "^[0-9a-f]{64}$")
  expect_identical(row$inner_edition_ids[[1L]], "euro2004|euro2008|wc2002|wc2006")
})

test_that("12-02-02 calibration adds only a derived 1X2 view and preserves G=40 scorelines", {
  inputs <- phase12_calibration_synthetic_inputs()
  oof <- assemble_phase12_inner_oof(inputs$predictions, inputs$fixtures, inputs$boundaries, "phase11_rf_dynamic_elo_open", "updating", "wc2010")
  calibrator <- fit_phase12_1x2_calibrator(oof, "phase11_rf_dynamic_elo_open", "updating", "wc2010")
  distribution <- data.frame(score_distribution_id = "dist_1", home_goals = c(0L, 1L), away_goals = c(0L, 0L), probability = c(0.7, 0.3), stringsAsFactors = FALSE)
  view <- data.frame(fixture_id = "synthetic_fixture", p_home_raw = 0.5, p_draw_raw = 0.3, p_away_raw = 0.2, distribution = I(list(distribution)), stringsAsFactors = FALSE)
  calibrated <- apply_phase12_1x2_calibrator(calibrator, view)
  expect_identical(calibrated$distribution[[1L]], distribution)
  expect_true(all(abs(calibrated$p_home_calibrated + calibrated$p_draw_calibrated + calibrated$p_away_calibrated - 1) < 1e-12))
  expect_identical(calibrated$primary_probability_view[[1L]], "calibrated")
})

test_that("12-02-02 durable CSV/RDS artifacts reconcile in a fresh read-back", {
  inputs <- phase12_calibration_synthetic_inputs()
  oof <- assemble_phase12_inner_oof(inputs$predictions, inputs$fixtures, inputs$boundaries, "phase11_rf_dynamic_elo_open", "updating", "wc2010")
  calibrator <- fit_phase12_1x2_calibrator(oof, "phase11_rf_dynamic_elo_open", "updating", "wc2010")
  output_dir <- tempfile("phase12-calibration-artifacts-")
  paths <- write_phase12_calibration_artifacts(oof, list(calibrator), output_dir)
  expect_true(all(file.exists(paths)))
  expect_invisible(validate_phase12_calibration_artifacts(paths[[1L]], paths[[2L]]))
  payload <- readRDS(paths[[2L]])
  expect_identical(payload$manifest$recipe_sha256[[1L]], calibrator$recipe_sha256)
  expect_identical(payload$inner_oof_row_count, 60L)
})

phase12_calibration_gate_test_case <- function(calibrated = TRUE) {
  editions <- c(
    "wc2002", "wc2006", "wc2010", "wc2014", "wc2018", "wc2022",
    "euro2004", "euro2008", "euro2012", "euro2016", "euro2020", "euro2024"
  )
  fixture_id <- paste0("phase12_gate_fixture_", seq_along(editions))
  observed <- rep(c("home", "draw", "away"), length.out = length(editions))
  fixtures <- data.frame(
    edition_id = editions, fixture_id = fixture_id,
    regulation_home_goals = ifelse(observed == "home", 1L, 0L),
    regulation_away_goals = ifelse(observed == "away", 1L, 0L),
    score_eligible = TRUE, stringsAsFactors = FALSE
  )
  distributions <- expand.grid(home_goals = 0:40, away_goals = 0:40)
  distributions$score_distribution_id <- "phase12_g40"
  distributions$probability <- dpois(distributions$home_goals, 2) * dpois(distributions$away_goals, 1)
  distributions$probability <- distributions$probability / sum(distributions$probability)
  raw <- data.frame(
    run_id = "phase12_synthetic_gate", model_id = "phase11_rf_dynamic_elo_open", panel_id = "open_core",
    edition_id = editions, track_id = "updating", fixture_id = fixture_id,
    score_distribution_id = "phase12_g40", p_home = .3, p_draw = .3, p_away = .4,
    p_over_2_5 = .4, p_under_2_5 = .6, p_btts = .3, prediction_status = "ok",
    stringsAsFactors = FALSE
  )
  raw$p_home <- ifelse(observed == "home", .4, .3)
  raw$p_draw <- ifelse(observed == "draw", .4, .3)
  raw$p_away <- ifelse(observed == "away", .4, .3)
  calibrated_view <- raw
  if (isTRUE(calibrated)) {
    calibrated_view$p_home <- ifelse(observed == "home", .7, .15)
    calibrated_view$p_draw <- ifelse(observed == "draw", .7, .15)
    calibrated_view$p_away <- ifelse(observed == "away", .7, .15)
  }
  list(raw = raw, calibrated = calibrated_view, fixtures = fixtures, distributions = distributions, ids = fixture_id, editions = editions)
}

test_that("12-03-01 raw and calibrated views use identical fixtures and shared scores", {
  x <- phase12_calibration_gate_test_case()
  comparison <- compare_phase12_raw_calibrated(
    x$raw, x$calibrated, x$fixtures, x$distributions, x$ids, x$editions
  )
  expect_equal(comparison$coverage_numerator, 12L)
  expect_equal(comparison$coverage_denominator, 12L)
  expect_true(comparison$coverage_valid)
  expect_true(comparison$distribution_unchanged)
  expect_true(comparison$identity$fixture_identity_match)
  expect_equal(nrow(comparison$raw_summaries[comparison$raw_summaries$grain == "tournament", ]), 12L * 14L)
  expect_equal(nrow(comparison$calibrated_summaries[comparison$calibrated_summaries$grain == "tournament", ]), 12L * 14L)
  expect_lt(comparison$calibrated_calibration_values$calibration_error, comparison$raw_calibration_values$calibration_error)
  expect_true(all(comparison$raw_scores$metric[comparison$raw_scores$target == "regulation_scoreline"] == comparison$calibrated_scores$metric[comparison$calibrated_scores$target == "regulation_scoreline"]))
})

test_that("12-03-01 rejects identity drift outside derived 1X2", {
  x <- phase12_calibration_gate_test_case()
  drifted <- x$calibrated
  drifted$score_distribution_id[[1L]] <- "other_distribution"
  expect_error(
    compare_phase12_raw_calibrated(x$raw, drifted, x$fixtures, x$distributions, x$ids, x$editions),
    "outside derived 1X2|score_distribution"
  )
  expect_identical(select_phase12_primary_probability_view(TRUE, character()), "calibrated_1x2")
  expect_identical(select_phase12_primary_probability_view(FALSE, character()), "raw_1x2")
})

test_that("12-03-02 calibration selection is strict and vetoes supporting regressions", {
  x <- phase12_calibration_gate_test_case()
  comparison <- compare_phase12_raw_calibrated(x$raw, x$calibrated, x$fixtures, x$distributions, x$ids, x$editions)
  decision <- phase12_selection_decision(comparison)
  expect_true(decision$calibration_promoted)
  expect_identical(decision$primary_probability_view, "calibrated_1x2")
  expect_length(decision$reason_codes, 0L)

  tied <- compare_phase12_raw_calibrated(x$raw, x$raw, x$fixtures, x$distributions, x$ids, x$editions)
  tied_decision <- phase12_selection_decision(tied)
  expect_false(tied_decision$calibration_promoted)
  expect_true("calibration_not_improved" %in% tied_decision$reason_codes)

  sparse <- comparison
  sparse$calibration_support_valid <- FALSE
  sparse_decision <- phase12_selection_decision(sparse)
  expect_identical(sparse_decision$primary_probability_view, "raw_1x2")
  expect_true("calibration_support_insufficient" %in% sparse_decision$reason_codes)

  unstable <- comparison
  unstable$paired_rps$breadth$maximum_fold_regression <- .015 + 1e-12
  unstable_decision <- phase12_selection_decision(unstable)
  expect_true("fold_stability_veto" %in% unstable_decision$reason_codes)

  incomplete <- comparison
  incomplete$coverage_valid <- FALSE
  incomplete$coverage_numerator <- 11L
  incomplete_decision <- phase12_selection_decision(incomplete)
  expect_true("fixture_coverage_veto" %in% incomplete_decision$reason_codes)
  expect_identical(
    incomplete_decision$reason_codes,
    phase12_selection_reason_order()[phase12_selection_reason_order() %in% incomplete_decision$reason_codes]
  )
})

test_that("12-03-02 durable gate retains all candidate/track states and reads back", {
  x <- phase12_calibration_gate_test_case()
  comparison <- compare_phase12_raw_calibrated(x$raw, x$calibrated, x$fixtures, x$distributions, x$ids, x$editions)
  rows <- phase12_calibration_gate_rows(comparison)
  expect_equal(nrow(rows), 9L)
  expect_equal(length(unique(rows$candidate_id)), 9L)
  expect_equal(sum(rows$score_status == "scored"), 1L)
  expect_equal(sum(rows$score_status == "no_score"), 8L)
  expect_true(all(rows$primary_probability_view %in% c("calibrated_1x2", "raw_1x2")))
  expect_true(all(rows$score_support_g == 40L))
  expect_identical(rows$primary_probability_view[rows$score_status == "scored"], "calibrated_1x2")
  expect_true(all(nzchar(rows$reason_codes[rows$score_status == "no_score"])))
  output_path <- file.path(tempdir(), "phase12-calibration-gate.csv")
  expect_invisible(write_phase12_calibration_gate(rows, output_path))
  persisted <- read.csv(output_path, stringsAsFactors = FALSE, check.names = FALSE)
  expect_identical(as.character(persisted$candidate_id), as.character(rows$candidate_id))
  expect_identical(as.character(persisted$track_id), as.character(rows$track_id))
})
