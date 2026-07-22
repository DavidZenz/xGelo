library(testthat)

project_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))
challenger_module <- file.path(project_root, "R/benchmark/challengers.R")
if (file.exists(challenger_module)) source(challenger_module)

require_ablation_selection_api <- function() {
  required <- "challenger_ablation_evidence"
  missing <- required[!vapply(required, exists, logical(1), mode = "function")]
  if (length(missing)) {
    stop(paste("Wave 0 RED contract awaits:", paste(missing, collapse = ", ")), call. = FALSE)
  }
}

ablation_selection_fixture <- function(rps_delta = 0.001, brier = 0, log_loss = 0,
                                       calibration = 0, worst_fold = 0.01) {
  list(
    candidate_id = "open_nb_elo_only_ablation",
    parent_id = "open_nb_incumbent",
    updating_equal_tournament_rps_delta = rps_delta,
    brier_relative_change = brier,
    log_loss_relative_change = log_loss,
    calibration_change = calibration,
    maximum_fold_regression = worst_fold,
    fold_wins = 8L,
    world_cup_wins = 4L,
    euro_wins = 4L,
    active_features = "elo_diff",
    inactive_features = c("xgf_ewma_diff", "xga_ewma_diff", "xgd_ewma_diff", "form_index_diff")
  )
}

test_that("practical non-inferiority includes the +0.001 boundary", {
  require_ablation_selection_api()
  at_boundary <- challenger_ablation_evidence(ablation_selection_fixture(0.001))
  above_boundary <- challenger_ablation_evidence(ablation_selection_fixture(0.0010001))
  expect_true(at_boundary$practically_non_inferior)
  expect_false(above_boundary$practically_non_inferior)
  expect_identical(at_boundary$active_features, "elo_diff")
  expect_setequal(at_boundary$inactive_features, ablation_selection_fixture()$inactive_features)
})

test_that("each supporting regression veto blocks simplification", {
  require_ablation_selection_api()
  cases <- list(
    brier = ablation_selection_fixture(brier = 0.010001),
    log_loss = ablation_selection_fixture(log_loss = 0.010001),
    calibration = ablation_selection_fixture(calibration = 0.010001),
    worst_fold = ablation_selection_fixture(worst_fold = 0.015001)
  )
  decisions <- lapply(cases, challenger_ablation_evidence)
  expect_false(any(vapply(decisions, `[[`, logical(1), "practically_non_inferior")))
  expect_true(all(vapply(decisions, function(x) nzchar(x$reason_codes), logical(1))))
})

test_that("coefficient significance cannot enter ablation selection", {
  require_ablation_selection_api()
  forbidden <- c("p_value", "pvalue", "significance", "coefficient_significant")
  expect_false(any(forbidden %in% names(formals(challenger_ablation_evidence))))
  code <- paste(deparse(body(challenger_ablation_evidence)), collapse = "\n")
  expect_false(any(vapply(forbidden, grepl, logical(1), x = code, ignore.case = TRUE)))
  result <- challenger_ablation_evidence(ablation_selection_fixture())
  expect_false(any(forbidden %in% names(result)))
})
