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

test_that("HYBRID-03 / D-12 persists the gate and keeps a failed candidate out of scoring", {
  protocol <- load_and_validate_hybrid_protocol()
  gate <- protocol$xg_gate_manifest
  expect_silent(validate_phase11_xg_gate_manifest(gate))
  xg_registration <- protocol$model_registry[
    protocol$model_registry$candidate_id == "phase11_rf_dynamic_elo_context_xg_gated_open",
    , drop = FALSE
  ]
  expect_equal(nrow(xg_registration), 1L)
  expect_equal(as.character(xg_registration$panel_rule), "open_core_when_gate_active")
  expect_equal(as.character(xg_registration$feature_rule), "open_context_plus_xg_only_after_gate")
  expect_identical(as.character(gate$active_status), "inactive")
  expect_identical(as.character(gate$score_status), "no_score_gate_failed")
  expect_identical(as.character(xg_registration$gate_parent_sha256), digest::digest(
    file.path(hybrid_project_root, "data/benchmark/phase11/xg_gate_manifest.csv"),
    algo = "sha256", file = TRUE
  ))

  history <- hybrid_rf_history()
  fixtures <- hybrid_rf_fixtures()
  fixtures$track_id <- "frozen"
  fixtures$forecast_sequence <- seq_len(nrow(fixtures))
  fixtures$result_cutoff_exclusive <- fixtures$evidence_cutoff_exclusive
  fixtures$regulation_home_goals <- c(1L, 0L)
  fixtures$regulation_away_goals <- c(0L, 1L)
  fixtures$score_eligible <- TRUE
  result <- run_hybrid_challenger_benchmark(
    history = history,
    fixtures = fixtures,
    candidate_order = "phase11_rf_dynamic_elo_context_xg_gated_open",
    run_id = "phase11_xg_gate_runner_test"
  )
  expect_equal(nrow(result$predictions), 0L)
  expect_equal(nrow(result$distributions), 0L)
  expect_equal(nrow(result$scores), 0L)
  expect_identical(as.character(result$candidate_evidence$active_status), "inactive")
  expect_identical(as.character(result$candidate_evidence$score_status), "no_score_gate_failed")
  expect_equal(as.integer(result$candidate_evidence$score_row_count), 0L)
})
