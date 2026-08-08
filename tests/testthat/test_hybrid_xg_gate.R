library(testthat)

source(file.path(
  normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else ".")),
  "tests/testthat/helper_hybrid_phase11.R"
))
hybrid_require_xg_api()

test_that("HYBRID-03 / D-12 fails closed on current zero-coverage xG/form data", {
  files <- hybrid_xg_current_files()
  gate <- evaluate_hybrid_xg_gate(
    feature_table = files$feature_table,
    home_model = files$home_model,
    away_model = files$away_model,
    rolling_form = files$rolling_form,
    forecast_features = files$forecast_features,
    predictors = xg_form_predictors(),
    thresholds = hybrid_xg_gate_thresholds(),
    evidence_cutoff_exclusive = as.Date("2026-06-05")
  )

  expect_true(is.list(gate) || is.data.frame(gate))
  expect_true(all(c(
    "coverage", "variance", "provenance", "thresholds", "active",
    "active_status", "inactive_reason", "source_hashes"
  ) %in% names(gate)))
  expect_equal(as.numeric(hybrid_result_field(gate, "coverage")), 0)
  expect_equal(as.numeric(hybrid_result_field(gate, "variance")), 0)
  expect_false(isTRUE(hybrid_result_field(gate, "provenance")))
  expect_false(isTRUE(hybrid_result_field(gate, "active")))
  expect_identical(as.character(hybrid_result_field(gate, "active_status")), "inactive")
  expect_true(nzchar(as.character(hybrid_result_field(gate, "inactive_reason"))))
  expect_true(all(grepl("^[0-9a-f]{64}$", unlist(hybrid_result_field(gate, "source_hashes")))))
  expect_true(all(c(
    "minimum_source_coverage", "minimum_nonzero_variance",
    "require_complete_provenance"
  ) %in% names(hybrid_result_field(gate, "thresholds"))))
})

test_that("HYBRID-03 / D-12 preserves missing xG as source-absent rather than observed zero", {
  files <- hybrid_xg_current_files()
  features <- utils::read.csv(files$feature_table, stringsAsFactors = FALSE)
  predictors <- xg_form_predictors()

  for (feature in predictors) {
    source_present <- features[[paste0(feature, "__source_present")]]
    value_present <- features[[paste0(feature, "__value_present")]]
    imputed <- features[[paste0(feature, "__imputed")]]
    expect_false(any(source_present), info = paste(feature, "source presence"))
    expect_false(any(value_present), info = paste(feature, "value presence"))
    expect_true(all(imputed), info = paste(feature, "imputation"))
    expect_true(all(features[[feature]] == 0), info = paste(feature, "zero placeholder"))
  }
})
