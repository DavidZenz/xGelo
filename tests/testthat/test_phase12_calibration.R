library(testthat)

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
