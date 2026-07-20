library(testthat)

project_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))
source(file.path(project_root, "tests/testthat/helper_benchmark.R"))
source(file.path(project_root, "R/benchmark/cutoffs.R"))

test_that("WC2026 outcomes are rejected before adapters run for every development role", {
  forbidden <- synthetic_benchmark_history(include_wc2026 = TRUE)
  purposes <- c(
    "development", "baseline_reproduction", "candidate_selection",
    "fit", "feature_selection", "tuning", "calibration"
  )

  for (purpose in purposes) {
    adapter <- recording_benchmark_adapter()
    recorder <- attr(adapter, "recorder")
    expect_error(
      guard_benchmark_purpose(forbidden, purpose = purpose, adapter = adapter),
      "wc2026|sealed|outcome"
    )
    expect_identical(recorder$calls, 0L)
  }
})

test_that("label-free WC2026 fixture identities remain available", {
  identities <- data.frame(
    fixture_id = "wc2026_001",
    edition_id = "wc2026",
    actual_completion_date = as.Date("2026-06-11"),
    home_team_id = "team_001",
    away_team_id = "team_002",
    stringsAsFactors = FALSE
  )
  adapter <- recording_benchmark_adapter()
  recorder <- attr(adapter, "recorder")

  result <- guard_benchmark_purpose(identities, purpose = "development", adapter = adapter)
  expect_equal(result$fixture_id, "wc2026_001")
  expect_identical(recorder$calls, 1L)
})

test_that("non-holdout outcome data may reach a registered adapter", {
  history <- synthetic_benchmark_history()
  adapter <- recording_benchmark_adapter()
  recorder <- attr(adapter, "recorder")

  result <- guard_benchmark_purpose(history, purpose = "baseline_reproduction", adapter = adapter)
  expect_equal(nrow(result), nrow(history))
  expect_identical(recorder$calls, 1L)
})
