library(testthat)

project_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))
source(file.path(project_root, "tests/testthat/helper_statistical_challengers.R"))
source(file.path(project_root, "R/benchmark/weights.R"))
source(file.path(project_root, "R/benchmark/baselines.R"))
source(file.path(project_root, "R/forecast/poisson.R"))
challenger_module <- file.path(project_root, "R/benchmark/challengers.R")
if (file.exists(challenger_module)) source(challenger_module)

require_ablation_hierarchy_api <- function() {
  required <- c("elo_only_goal_predictors", "fit_open_nb_elo_only_ablation")
  missing <- required[!vapply(required, exists, logical(1), mode = "function")]
  if (length(missing)) {
    stop(paste("Wave 0 RED contract awaits:", paste(missing, collapse = ", ")), call. = FALSE)
  }
}

ablation_zero_coverage_features <- function() {
  c("xgf_ewma_diff", "xga_ewma_diff", "xgd_ewma_diff", "form_index_diff")
}

test_that("level-one ablation changes only the active predictor set", {
  require_ablation_hierarchy_api()
  history <- synthetic_statistical_history(include_outer = FALSE)
  for (feature in ablation_zero_coverage_features()) history[[feature]] <- 0
  cutoff <- max(history$date) + 1L
  weights <- benchmark_observation_weights(history, cutoff)

  full <- fit_open_nb_incumbent(history, cutoff, observation_weights = weights)
  simpler <- fit_open_nb_elo_only_ablation(history, cutoff, observation_weights = weights)

  expect_identical(elo_only_goal_predictors(), "elo_diff")
  expect_identical(full$model_family, simpler$model_family)
  expect_identical(full$panel_id, "open_core")
  expect_identical(simpler$panel_id, "open_core")
  expect_identical(full$fit_row_count, simpler$fit_row_count)
  expect_equal(full$home_model$prior.weights, simpler$home_model$prior.weights)
  expect_equal(full$away_model$prior.weights, simpler$away_model$prior.weights)
  expect_identical(simpler$active_predictors, "elo_diff")
  expect_identical(full$training_dates, simpler$training_dates)
})

test_that("zero-coded compatibility features remain explicitly unavailable", {
  require_ablation_hierarchy_api()
  history <- synthetic_statistical_history(include_outer = FALSE)
  for (feature in ablation_zero_coverage_features()) {
    history[[feature]] <- 0
    history[[paste0(feature, "__source_present")]] <- FALSE
    history[[paste0(feature, "__value_present")]] <- FALSE
    history[[paste0(feature, "__imputed")]] <- TRUE
    history[[paste0(feature, "__imputation_reason")]] <- "point_in_time_source_coverage_zero"
  }
  fit <- fit_open_nb_elo_only_ablation(history, max(history$date) + 1L)
  evidence <- fit$compatibility_feature_evidence

  expect_setequal(evidence$feature_id, ablation_zero_coverage_features())
  expect_true(all(evidence$value == 0))
  expect_false(any(evidence$source_present))
  expect_false(any(evidence$value_present))
  expect_true(all(evidence$imputed))
  expect_false(any(evidence$active_in_fit))
  expect_true(all(evidence$coverage_status == "point_in_time_source_coverage_zero"))
})

test_that("zero coverage leaves every deeper child auditable and unfit", {
  require_ablation_hierarchy_api()
  history <- synthetic_statistical_history(include_outer = FALSE)
  for (feature in ablation_zero_coverage_features()) history[[feature]] <- 0
  fit <- fit_open_nb_elo_only_ablation(history, max(history$date) + 1L)
  nodes <- fit$ablation_nodes

  expect_identical(nodes$node_id, c("attack_xg", "defence_xg", "xgd", "form"))
  expect_true(all(nodes$parent_id == "open_nb_incumbent"))
  expect_false(any(nodes$activated))
  expect_false(any(nodes$fit_invoked))
  expect_true(all(nodes$status == "not_activated_zero_coverage"))
})
