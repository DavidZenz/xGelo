library(testthat)

# Validation 12-00-01: release ownership covers staged bundle and consumers.
# Validation 12-00-02: synthetic release fixtures remain outside the holdout boundary.

phase12_release_contract_files <- function() {
  c(
    "tests/testthat/test_phase12_calibration.R",
    "tests/testthat/test_phase12_freeze.R",
    "tests/testthat/test_phase12_final_evaluation.R",
    "tests/testthat/test_phase12_promotion.R",
    "tests/testthat/test_phase12_release.R"
  )
}

phase12_release_synthetic_manifest <- function() {
  data.frame(
    release_id = "synthetic_release_v0",
    status = "incumbent retained",
    candidate_id = "phase11_rf_dynamic_elo_open",
    track_id = "updating",
    score_support = 40L,
    primary_probability_view = "raw_1x2",
    labels_embedded = FALSE,
    stringsAsFactors = FALSE
  )
}

phase12_release_require_api <- function(required, owner) {
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

test_that("12-00-01 release fixture is explicit, versioned, and hash-ready", {
  manifest <- phase12_release_synthetic_manifest()
  expect_identical(manifest$status, "incumbent retained")
  expect_equal(manifest$score_support, 40L)
  expect_identical(manifest$primary_probability_view, "raw_1x2")
  expect_false(manifest$labels_embedded)
})

test_that("12-00-01 release gate names bundle, install, and resolver seams", {
  phase12_release_require_api(
    c(
      "stage_phase12_release_bundle",
      "validate_phase12_release_bundle",
      "complete_phase12_release_bundle",
      "install_phase12_release_bundle",
      "resolve_phase12_approved_release",
      "validate_phase12_release_contract",
      "phase12_release_metadata"
    ),
    "release"
  )
})
