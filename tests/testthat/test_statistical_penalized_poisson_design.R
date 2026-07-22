library(testthat)

project_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))
source(file.path(project_root, "tests/testthat/helper_statistical_challengers.R"))
penalized_module <- file.path(project_root, "R/forecast/penalized_poisson.R")
if (file.exists(penalized_module)) source(penalized_module)

require_penalized_design_api <- function() {
  required <- c(
    "build_penalized_poisson_design",
    "fit_penalized_team_means",
    "predict_penalized_poisson_means"
  )
  missing <- required[!vapply(required, exists, logical(1), mode = "function")]
  if (length(missing)) {
    fail(paste("Wave 0 RED contract awaits:", paste(missing, collapse = ", ")))
  }
}

fit_synthetic_team_model <- function(levels = synthetic_sparse_teams()$registered_team_ids) {
  sparse <- synthetic_sparse_teams()
  design <- build_penalized_poisson_design(
    sparse$history,
    registered_team_ids = levels
  )
  fit <- fit_penalized_team_means(
    design,
    lambda = 1,
    observation_weights = rep(1, nrow(sparse$history))
  )
  list(sparse = sparse, design = design, fit = fit)
}

test_that("two-row sparse design retains complete ridge-protected team blocks", {
  require_penalized_design_api()
  sparse <- synthetic_sparse_teams()
  design <- build_penalized_poisson_design(
    sparse$history,
    registered_team_ids = sparse$registered_team_ids
  )
  n_teams <- length(sparse$registered_team_ids)

  expect_true(inherits(design$x, "sparseMatrix"))
  expect_equal(dim(design$x), c(2L * nrow(sparse$history), 2L + 2L * n_teams))
  expect_identical(
    colnames(design$x),
    c(
      "intercept", "venue_home_non_neutral",
      paste0("attack__", sparse$registered_team_ids),
      paste0("defence__", sparse$registered_team_ids)
    )
  )
  expect_identical(as.numeric(design$penalty_factor), c(0, 0, rep(1, 2L * n_teams)))
  expect_identical(design$team_levels, sparse$registered_team_ids)
  expect_equal(design$response, c(sparse$history$home_goals, sparse$history$away_goals))
  expect_equal(design$row_data$signed_elo_diff, c(sparse$history$elo_diff, -sparse$history$elo_diff))
  expect_equal(
    design$row_data$venue_home_non_neutral,
    c(as.integer(sparse$history$venue_role == "home"), rep(0L, nrow(sparse$history)))
  )

  unseen_columns <- c(
    paste0("attack__", sparse$unseen_team_ids),
    paste0("defence__", sparse$unseen_team_ids)
  )
  expect_true(all(unseen_columns %in% colnames(design$x)))
  expect_equal(as.numeric(Matrix::colSums(design$x[, unseen_columns, drop = FALSE])), rep(0, 4L))
})

test_that("fitted attack and defence blocks center without changing linear predictors", {
  require_penalized_design_api()
  fitted <- fit_synthetic_team_model()
  fit <- fitted$fit
  rows <- fitted$design$row_data

  expect_equal(mean(unname(fit$coefficients_centered$attack)), 0, tolerance = 1e-12)
  expect_equal(mean(unname(fit$coefficients_centered$defence)), 0, tolerance = 1e-12)
  expect_equal(sum(unname(fit$coefficients_centered$attack)), 0, tolerance = 1e-12)
  expect_equal(sum(unname(fit$coefficients_centered$defence)), 0, tolerance = 1e-12)
  expect_equal(
    fit$coefficients_centered$intercept,
    fit$coefficients_raw$intercept +
      mean(unname(fit$coefficients_raw$attack)) +
      mean(unname(fit$coefficients_raw$defence)),
    tolerance = 1e-12
  )

  raw_eta <- fit$coefficients_raw$intercept +
    unname(fit$coefficients_raw$attack[rows$scoring_team_id]) +
    unname(fit$coefficients_raw$defence[rows$defending_team_id]) +
    fit$coefficients_raw$venue * rows$venue_home_non_neutral
  centered_eta <- fit$coefficients_centered$intercept +
    unname(fit$coefficients_centered$attack[rows$scoring_team_id]) +
    unname(fit$coefficients_centered$defence[rows$defending_team_id]) +
    fit$coefficients_centered$venue * rows$venue_home_non_neutral
  expect_equal(centered_eta, raw_eta, tolerance = 1e-12)
  expect_identical(fit$team_levels, fitted$sparse$registered_team_ids)
  expect_true(all(fitted$sparse$registered_team_ids %in% names(fit$prior_counts)))
})

test_that("registered level ordering cannot change fitted fixture means", {
  require_penalized_design_api()
  sparse <- synthetic_sparse_teams()
  first <- fit_synthetic_team_model(sparse$registered_team_ids)
  second <- fit_synthetic_team_model(rev(sparse$registered_team_ids))

  first_predictions <- predict_penalized_poisson_means(first$fit, sparse$fixtures)
  second_predictions <- predict_penalized_poisson_means(second$fit, sparse$fixtures)
  first_predictions <- first_predictions[order(first_predictions$fixture_id), c("fixture_id", "mu_home", "mu_away")]
  second_predictions <- second_predictions[order(second_predictions$fixture_id), c("fixture_id", "mu_home", "mu_away")]
  rownames(first_predictions) <- rownames(second_predictions) <- NULL

  expect_identical(first_predictions$fixture_id, second_predictions$fixture_id)
  expect_equal(first_predictions$mu_home, second_predictions$mu_home, tolerance = 1e-10)
  expect_equal(first_predictions$mu_away, second_predictions$mu_away, tolerance = 1e-10)
})

test_that("one- and two-unseen fixtures remain complete with auditable global fallback", {
  require_penalized_design_api()
  fitted <- fit_synthetic_team_model()
  predictions <- predict_penalized_poisson_means(fitted$fit, fitted$sparse$fixtures)
  required_evidence <- c(
    "home_prior_count", "away_prior_count",
    "home_shrinkage_weight", "away_shrinkage_weight",
    "home_cold_start_status", "away_cold_start_status",
    "home_attack_effect", "home_defence_effect",
    "away_attack_effect", "away_defence_effect"
  )

  expect_equal(nrow(predictions), nrow(fitted$sparse$fixtures))
  expect_setequal(predictions$fixture_id, fitted$sparse$fixtures$fixture_id)
  expect_true(all(is.finite(predictions$mu_home) & predictions$mu_home > 0))
  expect_true(all(is.finite(predictions$mu_away) & predictions$mu_away > 0))
  expect_true(all(required_evidence %in% names(predictions)))

  one_home <- predictions[predictions$fixture_id == "one_unseen_home", , drop = FALSE]
  expect_equal(one_home$home_prior_count, 0L)
  expect_equal(one_home$home_shrinkage_weight, 0)
  expect_identical(one_home$home_cold_start_status, "cold_start_global")
  expect_equal(one_home$home_attack_effect, 0, tolerance = 0)
  expect_equal(one_home$away_defence_effect, fitted$fit$coefficients_centered$defence[["team_beta"]])

  one_away <- predictions[predictions$fixture_id == "one_unseen_away", , drop = FALSE]
  expect_equal(one_away$away_prior_count, 0L)
  expect_identical(one_away$away_cold_start_status, "cold_start_global")
  expect_equal(one_away$away_attack_effect, 0, tolerance = 0)
  expect_equal(one_away$home_defence_effect, 0, tolerance = 0)

  two <- predictions[predictions$fixture_id == "two_unseen", , drop = FALSE]
  expect_equal(two$home_prior_count, 0L)
  expect_equal(two$away_prior_count, 0L)
  expect_equal(two$home_attack_effect, 0, tolerance = 0)
  expect_equal(two$home_defence_effect, 0, tolerance = 0)
  expect_equal(two$away_attack_effect, 0, tolerance = 0)
  expect_equal(two$away_defence_effect, 0, tolerance = 0)
  expect_equal(two$mu_home, exp(fitted$fit$coefficients_centered$intercept), tolerance = 1e-12)
  expect_equal(two$mu_away, exp(fitted$fit$coefficients_centered$intercept), tolerance = 1e-12)

  sparse_known <- predictions[predictions$fixture_id == "sparse_known", , drop = FALSE]
  expect_gt(sparse_known$home_prior_count, 0L)
  expect_gt(sparse_known$home_shrinkage_weight, 0)
  expect_lt(sparse_known$home_shrinkage_weight, 1)
  expect_identical(sparse_known$home_cold_start_status, "ridge_shrunk")
})

test_that("neutral team reversal swaps the two fitted means", {
  require_penalized_design_api()
  fitted <- fit_synthetic_team_model()
  predictions <- predict_penalized_poisson_means(fitted$fit, fitted$sparse$fixtures)
  ab <- predictions[predictions$fixture_id == "known_neutral", , drop = FALSE]
  ba <- predictions[predictions$fixture_id == "known_neutral_reversed", , drop = FALSE]

  expect_equal(ab$mu_home, ba$mu_away, tolerance = 1e-12)
  expect_equal(ab$mu_away, ba$mu_home, tolerance = 1e-12)
  expect_equal(sort(c(ab$mu_home, ab$mu_away)), sort(c(ba$mu_home, ba$mu_away)), tolerance = 1e-12)
})
