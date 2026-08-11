library(testthat)

# Validation 12-00-01: release ownership covers staged bundle and consumers.
# Validation 12-00-02: synthetic release fixtures remain outside the holdout boundary.

phase12_release_contract_files <- function() {
  file.path(
    phase12_test_project_root,
    c(
      "tests/testthat/test_phase12_calibration.R",
      "tests/testthat/test_phase12_freeze.R",
      "tests/testthat/test_phase12_final_evaluation.R",
      "tests/testthat/test_phase12_promotion.R",
      "tests/testthat/test_phase12_release.R"
    )
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

phase12_release_static_scan <- function(files = phase12_release_contract_files()) {
  expected <- phase12_release_contract_files()
  stopifnot(identical(files, expected), all(file.exists(files)))

  forbidden_source_patterns <- c(
    paste0("data/benchmark/phase12/", "wc2026_labels", "\\.", "csv")
  )
  forbidden_calls <- character()

  for (path in files) {
    text <- paste(readLines(path, warn = FALSE), collapse = "\n")
    bad_patterns <- forbidden_source_patterns[vapply(
      forbidden_source_patterns, function(pattern) grepl(pattern, text, perl = TRUE),
      logical(1)
    )]
    if (length(bad_patterns)) {
      stop(
        "forbidden label-boundary construct in Phase 12 validation file: ",
        path, " :: ", paste(bad_patterns, collapse = ", ")
      )
    }
    parsed <- parse(file = path, keep.source = TRUE)
    stopifnot(length(parsed) > 0L)
    parse_data <- getParseData(parsed)
    calls <- unique(parse_data$text[parse_data$token == "SYMBOL_FUNCTION_CALL"])
    bad_calls <- intersect(calls, forbidden_calls)
    if (length(bad_calls)) {
      stop(
        "forbidden production or write call in Wave 0 scaffold: ", path,
        " :: ", paste(bad_calls, collapse = ", ")
      )
    }
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

test_that("12-00-02 static scan covers exactly the five Wave 0 files", {
  expect_invisible(phase12_release_static_scan())
})

test_that("12-00-01 release gate names bundle, install, and resolver seams", {
  expect_invisible(phase12_release_require_api(
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
  ))
})
