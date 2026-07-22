library(testthat)

project_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))
source(file.path(project_root, "R/evaluation/proper_scores.R"))
source(file.path(project_root, "R/benchmark/contracts.R"))
dependence_module <- file.path(project_root, "R/forecast/score_dependence.R")
if (file.exists(dependence_module)) source(dependence_module)

require_dependence_pmf_api <- function() {
  required <- c(
    "statistical_mean_prediction_hash",
    "independent_poisson_grid",
    "dixon_coles_grid",
    "bivariate_poisson_grid"
  )
  missing <- required[!vapply(required, exists, logical(1), mode = "function")]
  if (length(missing)) {
    stop(paste("Wave 0 RED contract awaits:", paste(missing, collapse = ", ")), call. = FALSE)
  }
}

dependence_mean_row <- function(dependence_id = "independent") {
  data.frame(
    outer_edition_id = "wc2010", track_id = "frozen", boundary_id = "b1",
    fixture_id = "f1", mu_home = 1.4, mu_away = 0.9,
    dependence_id = dependence_id, stringsAsFactors = FALSE
  )
}

assert_g40_distribution <- function(grid, id) {
  expect_true(all(is.finite(grid$probability)))
  expect_true(all(grid$probability >= 0))
  expect_equal(sum(grid$probability), 1, tolerance = 1e-12)
  expect_identical(sort(unique(grid$home_goals)), 0:40)
  expect_identical(sort(unique(grid$away_goals)), 0:40)
  expect_equal(nrow(grid), 41L * 41L)
  validate_benchmark_score_distributions(grid, id, support_max = 40L, tolerance = 1e-10)
  expect_silent(derive_benchmark_markets(grid))
}

bivariate_oracle_cell <- function(x, y, mu_home, mu_away, q) {
  kappa <- q * min(mu_home, mu_away)
  lambda1 <- mu_home - kappa
  lambda2 <- mu_away - kappa
  z <- 0:min(x, y)
  sum(
    exp(-(lambda1 + lambda2 + kappa)) *
      lambda1^(x - z) * lambda2^(y - z) * kappa^z /
      (factorial(x - z) * factorial(y - z) * factorial(z))
  )
}

test_that("mean hashes exclude dependence identity and bind the exact shared means", {
  require_dependence_pmf_api()
  siblings <- lapply(c("independent", "dixon_coles", "bivariate_poisson"), dependence_mean_row)
  hashes <- vapply(siblings, statistical_mean_prediction_hash, character(1))
  expect_length(unique(hashes), 1L)

  changed <- dependence_mean_row()
  changed$mu_home <- changed$mu_home + 1e-12
  expect_false(identical(statistical_mean_prediction_hash(changed), hashes[[1]]))
  expect_match(hashes[[1]], "^[0-9a-f]{64}$")
})

test_that("Dixon-Coles changes exactly four analytical low-score cells", {
  require_dependence_pmf_api()
  mu_home <- 1.4
  mu_away <- 0.9
  rho <- -0.08
  dc <- dixon_coles_grid(mu_home, mu_away, rho, support_max = 40L, score_distribution_id = "dc")
  cells <- expand.grid(home_goals = 0:40, away_goals = 0:40)
  tau <- rep(1, nrow(cells))
  tau[cells$home_goals == 0 & cells$away_goals == 0] <- 1 - mu_home * mu_away * rho
  tau[cells$home_goals == 0 & cells$away_goals == 1] <- 1 + mu_home * rho
  tau[cells$home_goals == 1 & cells$away_goals == 0] <- 1 + mu_away * rho
  tau[cells$home_goals == 1 & cells$away_goals == 1] <- 1 - rho
  expected <- dpois(cells$home_goals, mu_home) * dpois(cells$away_goals, mu_away) * tau
  expected <- expected / sum(expected)

  dc <- dc[order(dc$away_goals, dc$home_goals), , drop = FALSE]
  expect_equal(dc$probability, expected, tolerance = 1e-12)
  assert_g40_distribution(dc, "dc")
})

test_that("zero dependence recovers the independent Poisson grid exactly", {
  require_dependence_pmf_api()
  independent <- independent_poisson_grid(1.4, 0.9, support_max = 40L, score_distribution_id = "ind")
  dc <- dixon_coles_grid(1.4, 0.9, rho = 0, support_max = 40L, score_distribution_id = "dc")
  bp <- bivariate_poisson_grid(1.4, 0.9, q = 0, support_max = 40L, score_distribution_id = "bp")
  key <- function(x) x[order(x$home_goals, x$away_goals), "probability"]

  expect_equal(key(dc), key(independent), tolerance = 1e-15)
  expect_equal(key(bp), key(independent), tolerance = 1e-15)
  assert_g40_distribution(independent, "ind")
  assert_g40_distribution(dc, "dc")
  assert_g40_distribution(bp, "bp")
})

test_that("bivariate Poisson matches hand oracles and preserves supplied marginal means", {
  require_dependence_pmf_api()
  mu_home <- 1.4
  mu_away <- 0.9
  q <- 0.25
  bp <- bivariate_poisson_grid(mu_home, mu_away, q, support_max = 40L, score_distribution_id = "bp")
  normalizer <- sum(vapply(seq_len(nrow(bp)), function(i) {
    bivariate_oracle_cell(bp$home_goals[i], bp$away_goals[i], mu_home, mu_away, q)
  }, numeric(1)))
  for (cell in list(c(0L, 0L), c(1L, 0L), c(0L, 1L), c(1L, 1L), c(2L, 2L))) {
    actual <- bp$probability[bp$home_goals == cell[1] & bp$away_goals == cell[2]]
    expected <- bivariate_oracle_cell(cell[1], cell[2], mu_home, mu_away, q) / normalizer
    expect_equal(actual, expected, tolerance = 1e-12)
  }
  expect_equal(sum(bp$home_goals * bp$probability), mu_home, tolerance = 1e-10)
  expect_equal(sum(bp$away_goals * bp$probability), mu_away, tolerance = 1e-10)
  assert_g40_distribution(bp, "bp")
})

test_that("all siblings derive markets only through the inherited common validator", {
  require_dependence_pmf_api()
  grids <- list(
    independent = independent_poisson_grid(1.4, 0.9, 40L, "independent"),
    dixon_coles = dixon_coles_grid(1.4, 0.9, -0.08, 40L, "dixon_coles"),
    bivariate = bivariate_poisson_grid(1.4, 0.9, 0.25, 40L, "bivariate")
  )
  markets <- lapply(grids, derive_benchmark_markets)
  expect_true(all(vapply(markets, function(x) {
    isTRUE(all.equal(x$p_home + x$p_draw + x$p_away, 1, tolerance = 1e-10)) &&
      isTRUE(all.equal(x$p_over_2_5 + x$p_under_2_5, 1, tolerance = 1e-10))
  }, logical(1))))
  invisible(Map(assert_g40_distribution, grids, names(grids)))
})

test_that("invalid means and dependence values fail before emitting a grid", {
  require_dependence_pmf_api()
  expect_error(independent_poisson_grid(NA_real_, 1, 40L, "bad"), "mean|finite")
  expect_error(dixon_coles_grid(1.4, 0.9, rho = 1, 40L, "bad"), "rho|feasible|positive")
  expect_error(bivariate_poisson_grid(1.4, 0.9, q = 1, 40L, "bad"), "q|\\[0, 1\\)")
  expect_error(independent_poisson_grid(1.4, 0.9, 39L, "bad"), "40|support")
})
