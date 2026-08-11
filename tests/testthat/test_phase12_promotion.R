library(testthat)

project_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))
source(file.path(project_root, "R/release/promotion_report.R"))

# Validation 12-00-01: promotion owns evaluator delegation and fallback contracts.
# Validation 12-00-02: promotion fixtures contain synthetic score evidence only.

phase12_promotion_synthetic_candidates <- function() {
  data.frame(
    candidate_id = c(
      "phase11_rf_dynamic_elo_open", "phase11_rf_dynamic_elo_rich",
      "phase11_nb_dynamic_elo_open", "phase11_nb_dynamic_elo_rich",
      "phase11_penalized_poisson", "phase11_dynamic_goal_ability",
      "phase11_score_dependence", "phase11_context_prior", "phase11_structural_prior"
    ),
    incumbent_id = "phase11_rf_dynamic_elo_open",
    eligible = c(TRUE, rep(FALSE, 8L)),
    rps_delta = c(0, rep(NA_real_, 8L)),
    decision = "incumbent retained",
    stringsAsFactors = FALSE
  )
}

phase12_promotion_require_api <- function(required, owner) {
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

test_that("12-00-01 promotion fixture retains exact incumbent fallback", {
  candidates <- phase12_promotion_synthetic_candidates()
  expect_equal(nrow(candidates), 9L)
  expect_equal(sum(candidates$eligible), 1L)
  expect_identical(unique(candidates$decision), "incumbent retained")
  expect_true(all(is.na(candidates$rps_delta[-1L])))
})

test_that("12-00-01 promotion gate names evaluator and report seams", {
  phase12_promotion_require_api(
    c(
      "evaluate_phase12_candidates",
      "write_phase12_promotion_report",
      "evaluate_promotion",
      "select_promoted_candidate"
    ),
    "promotion"
  )
})

phase12_promotion_all_contracts <- function() {
  fields <- c("probability_valid", "distribution_valid", "fixture_valid", "coverage_valid",
    "provenance_valid", "license_valid", "seed_valid", "checksum_valid", "reproducible",
    "code_frozen", "features_frozen", "settings_frozen", "panels_frozen", "seeds_frozen", "wc2026_sealed")
  stats::setNames(as.list(rep(TRUE, length(fields))), fields)
}

phase12_promotion_candidate_inputs <- function() {
  ids <- phase12_promotion_synthetic_candidates()$candidate_id
  stats::setNames(lapply(ids, function(id) {
    list(candidate_id = id, incumbent_id = "open_nb_incumbent", uses_optional_data = FALSE,
      contracts = phase12_promotion_all_contracts(),
      core = list(rps_delta = if (id == ids[[1L]]) 0 else -0.004, ci_upper = if (id == ids[[1L]]) 0.001 else -0.001,
        fold_wins = if (id == ids[[1L]]) 7L else 8L, world_cup_wins = 1L, euro_wins = 4L,
        maximum_fold_regression = 0.01, brier_relative_change = 0, log_loss_relative_change = 0, calibration_change = 0),
      core_headline_rps = 0.2, core_log_loss = 0.7, core_brier = 0.5, core_calibration_error = 0.05,
      complexity_rank = 1L)
  }), ids)
}

test_that("12-05-02 promotion delegates every registry row and retains incumbent", {
  candidates <- phase12_promotion_candidate_inputs()
  result <- evaluate_phase12_candidates(candidates)
  expect_identical(result$evaluator_calls, 9L)
  expect_equal(nrow(result$candidate_evaluations), 9L)
  expect_identical(sort(as.character(result$candidate_evaluations$candidate_id)), sort(names(candidates)))
  expect_true(all(grepl("^value__", names(result$candidate_evaluations)[grepl("^value__", names(result$candidate_evaluations))])))
  expect_true(all(grepl("^pass__", names(result$candidate_evaluations)[grepl("^pass__", names(result$candidate_evaluations))])))
  expect_identical(result$release_decision, "incumbent retained")
  expect_identical(result$selected_id, "open_nb_incumbent")
  path <- tempfile("phase12-promotion-report-", fileext = ".csv")
  report <- write_phase12_promotion_report(result, path)
  persisted <- read.csv(report, stringsAsFactors = FALSE, check.names = FALSE)
  expect_equal(nrow(persisted), 9L)
  expect_true(all(persisted$release_decision == "incumbent retained"))
  expect_true(all(nzchar(persisted$decision_sha256)))
  expect_error(write_phase12_promotion_report(result, path), "immutable")
})
