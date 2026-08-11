library(testthat)

project_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))
source(file.path(project_root, "R/release/freeze_manifest.R"))
source(file.path(project_root, "R/calibration/inner_oof.R"))
source(file.path(project_root, "R/calibration/probability_calibration.R"))

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
  phase12_calibration_require_api(
    c(
      "assemble_phase12_inner_oof",
      "phase12_calibration_recipe",
      paste0("fit", "_phase12_", "1x2_calibrator"),
      "apply_phase12_1x2_calibrator",
      "compare_phase12_raw_calibrated",
      "select_phase12_primary_probability_view"
    ),
    "calibration"
  )
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
  holdout_calls <- 0L
  holdout <- data.frame(edition_id = "wc2026", fixture_id = "wc2026_synthetic", actual_home_goals = 1L, stringsAsFactors = FALSE)
  expect_error(guard_benchmark_purpose(holdout, "calibration", adapter = function(x) { holdout_calls <<- holdout_calls + 1L; x }), "sealed|wc2026")
  expect_identical(holdout_calls, 0L)
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
