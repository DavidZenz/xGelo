library(testthat)
joint_root <- normalizePath(if (basename(getwd()) == "testthat") "../.." else ".", mustWork = TRUE)
source(file.path(joint_root, "R/common/phase18_canonical_hash.R"), local = .GlobalEnv)
source(file.path(joint_root, "R/competition/ucl_joint_score_view.R"), local = .GlobalEnv)

test_that("outcome-first view preserves raw conditional scores and approved class masses", {
  raw <- data.frame(home_goals = c(0L, 0L, 1L, 1L), away_goals = c(0L, 1L, 0L, 1L), probability = c(.4, .3, .2, .1))
  before <- serialize(raw, NULL)
  view <- ucl_tournament_score_view(raw, c(.55, .25, .20), "fixture-unit", "release-unit",
    "calibrated_1x2", strrep("a", 64L), support_max = 1L)
  expect_equal(view$grid$probability, c(.20, .20, .55, .05), tolerance = 1e-14)
  g <- view$grid
  expect_equal(sum(g$probability[g$home_goals > g$away_goals]), .55, tolerance = 1e-14)
  expect_equal(sum(g$probability[g$home_goals == g$away_goals]), .25, tolerance = 1e-14)
  expect_equal(sum(g$probability[g$home_goals < g$away_goals]), .20, tolerance = 1e-14)
  # Independent outcome-first factorization for every cell, including both draws.
  expected <- c(.25 * .4/.5, .20 * .3/.3, .55 * .2/.2, .25 * .1/.5)
  expect_equal(g$probability, expected, tolerance = 1e-14)
  expect_identical(serialize(raw, NULL), before)
  expect_lte(view$provenance$max_1x2_error, 1e-12)
  expect_lte(view$provenance$max_conditional_error, 1e-12)
  expect_match(view$provenance$view_sha256, "^[0-9a-f]{64}$")
  expect_identical(view$scope, "tournament_sampling_only")
})

test_that("raw primary view is unchanged and invalid conditional support fails closed", {
  raw <- data.frame(home_goals = c(0L, 0L, 1L, 1L), away_goals = c(0L, 1L, 0L, 1L), probability = c(.4, .3, .2, .1))
  build <- function(grid = raw, p = c(.2, .5, .3)) ucl_tournament_score_view(grid, p, "f", "r", "raw_1x2", strrep("b", 64L), 1L)
  expect_equal(build()$grid, raw, tolerance = 1e-14)
  impossible <- raw; impossible$probability <- c(.7, .3, 0, 0)
  expect_error(build(impossible), "no raw conditional score support")
  expect_error(build(raw[-1L, ]), "complete normalized score rectangle")
  expect_error(build(p = c(.2, .5, .4)), "normalized 1X2")
  duplicate <- raw; duplicate$home_goals[[4L]] <- 0L
  expect_error(build(duplicate), "complete normalized score rectangle")
  changed <- build(p = c(.3, .4, .3))
  expect_false(identical(changed$provenance$view_sha256, build()$provenance$view_sha256))
})
