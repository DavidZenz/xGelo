#' Unit Tests for Elo Rating System
#'
#' Test suite for R/elo/runner.R functions
#'
#' @author xGelo project
#' @date 2026-06-03

library(testthat)
library(dplyr)

# Source the Elo functions
source("R/elo/runner.R")

# Test expected_result function

context("expected_result function")

test_that("expected_result returns 0.5 for equal ratings", {
  expect_equal(expected_result(1500, 1500), 0.5)
})

test_that("expected_result returns >0.5 when team A has higher rating", {
  expect_gt(expected_result(1600, 1500), 0.5)
})

test_that("expected_result returns <0.5 when team A has lower rating", {
  expect_lt(expected_result(1500, 1600), 0.5)
})

test_that("expected_result for extreme rating difference", {
  # 400 point difference should give ~0.91 / ~0.09
  expect_gt(expected_result(1900, 1500), 0.9)
  expect_lt(expected_result(1900, 1500), 0.92)
  
  # Reverse: lower rated team should have low probability
  expect_lt(expected_result(1500, 1900), 0.1)
  expect_gt(expected_result(1500, 1900), 0.08)
})

test_that("expected_result handles numeric inputs", {
  expect_error(expected_result("1500", 1500), "must be numeric")
  expect_error(expected_result(1500, "1500"), "must be numeric")
})

test_that("expected_result requires both arguments", {
  expect_error(expected_result(1500), "Both ratings must be provided")
})

test_that("expected_result requires scalar inputs", {
  expect_error(expected_result(c(1500, 1500), 1500), "must be scalar")
})

# Test apply_decay function

context("apply_decay function")

test_that("apply_decay with 0 days returns original rating", {
  expect_equal(apply_decay(1500, 0), 1500)
})

test_that("apply_decay with NA days returns original rating", {
  expect_equal(apply_decay(1500, NA), 1500)
})

test_that("apply_decay with missing days returns original rating", {
  expect_equal(apply_decay(1500), 1500)
})

test_that("apply_decay reduces rating over time", {
  # 365 days with decay 0.995 should multiply by 0.995
  expect_lt(apply_decay(1500, 365), 1500)
  expected <- 1500 * 0.995
  expect_true(abs(apply_decay(1500, 365) - expected) < 0.01)
})

test_that("apply_decay with 730 days applies compound decay", {
  # 730 days = 2 years, decay should be 0.995^2
  expected <- 1500 * (0.995 ^ 2)
  expect_true(abs(apply_decay(1500, 730) - expected) < 0.01)
})

test_that("apply_decay handles numeric inputs", {
  expect_error(apply_decay("1500", 365), "must be numeric")
  expect_error(apply_decay(1500, "365"), "must be numeric")
})

# Test get_k_factor function

context("get_k_factor function")

test_that("get_k_factor returns 20 for >=15 matches", {
  expect_equal(get_k_factor(15, 0), 20)
  expect_equal(get_k_factor(10, 5), 20)
  expect_equal(get_k_factor(0, 15), 20)
  expect_equal(get_k_factor(10, 10), 20)
})

test_that("get_k_factor returns 40 for <15 matches", {
  expect_equal(get_k_factor(14, 0), 40)
  expect_equal(get_k_factor(0, 14), 40)
  expect_equal(get_k_factor(7, 7), 40)
})

test_that("get_k_factor returns 20 for exactly 15 matches", {
  expect_equal(get_k_factor(15, 0), 20)
  expect_equal(get_k_factor(0, 15), 20)
})

# Test elo_update function

context("elo_update function")

test_that("elo_update requires actual_result", {
  expect_error(elo_update(1500, 1500), "actual_result must be provided")
})

test_that("elo_update validates actual_result values", {
  expect_error(elo_update(1500, 1500, 2, 20, 20), "must be in")
  expect_error(elo_update(1500, 1500, -1, 20, 20), "must be in")
})

test_that("elo_update handles home win correctly", {
  # Home team (A) wins: result = 1
  # With equal ratings and no home advantage, expected result = 0.5
  # Home rating should increase, away should decrease
  result <- elo_update(1500, 1500, 1, 20, 20, home_advantage = 0, is_home = TRUE)
  
  expect_gt(result$rating_a, 1500)
  expect_lt(result$rating_b, 1500)
})

test_that("elo_update handles away win correctly", {
  # Away team wins: result = 0
  result <- elo_update(1500, 1500, 0, 20, 20, home_advantage = 0, is_home = TRUE)
  
  expect_lt(result$rating_a, 1500)
  expect_gt(result$rating_b, 1500)
})

test_that("elo_update handles draw correctly", {
  # Draw: result = 0.5
  result <- elo_update(1500, 1500, 0.5, 20, 20, home_advantage = 0, is_home = TRUE)
  
  # With equal ratings and no home advantage, expected = 0.5, so no change
  expect_equal(result$rating_a, 1500)
  expect_equal(result$rating_b, 1500)
})

test_that("elo_update applies home advantage correctly", {
  # With home advantage of 60, home team's effective rating is higher
  # For home: rating_a_adj = 1500 + 60 = 1560
  # expected_result = 1 / (1 + 10^((1500-1560)/400)) = 1 / (1 + 10^(-0.15)) ≈ 0.585
  # With draw result = 0.5, home team underperformed (0.5 < 0.585)
  # So home rating should DECREASE, away should INCREASE
  result <- elo_update(1500, 1500, 0.5, 20, 20, home_advantage = 60, is_home = TRUE)
  
  expect_lt(result$rating_a, 1500)
  expect_gt(result$rating_b, 1500)
})

test_that("elo_update uses correct formula", {
  # Test the exact formula: R_new = R_old + K * (actual - expected)
  # For equal ratings (1500, 1500) with no home advantage:
  # expected_a = 1 / (1 + 10^((1500-1500)/400)) = 1 / (1 + 10^0) = 1/2 = 0.5
  # If actual = 1 (home win):
  # rating_a_new = 1500 + 20 * (1 - 0.5) = 1500 + 10 = 1510
  # rating_b_new = 1500 + 20 * ((1-1) - (1-0.5)) = 1500 + 20 * (0 - 0.5) = 1500 - 10 = 1490
  
  result <- elo_update(1500, 1500, 1, 20, 20, home_advantage = 0, is_home = TRUE)
  
  expect_equal(result$rating_a, 1510)
  expect_equal(result$rating_b, 1490)
})

test_that("elo_update handles different k-factors", {
  result <- elo_update(1500, 1500, 1, 40, 20, home_advantage = 0, is_home = TRUE)
  
  # Home: 1500 + 40 * (1 - 0.5) = 1520
  # Away: 1500 + 20 * (0 - 0.5) = 1490
  expect_equal(result$rating_a, 1520)
  expect_equal(result$rating_b, 1490)
})

# Test compute_elo function with small dataset

context("compute_elo function")

test_that("compute_elo requires valid input", {
  empty_df <- data.frame(date = as.Date(character()), stringsAsFactors = FALSE)
  expect_error(compute_elo(empty_df, data.frame()), "must contain at least one match")
})

test_that("compute_elo requires required columns", {
  df <- data.frame(date = as.Date("2020-01-01"), home_team = "A", stringsAsFactors = FALSE)
  team_map <- data.frame(canonical_name = "A", fifa_code = "AAA", source_name = "A", stringsAsFactors = FALSE)
  
  expect_error(compute_elo(df, team_map), "Missing required columns")
})

test_that("compute_elo processes single match correctly", {
  # Create minimal test data
  matches_df <- data.frame(
    date = as.Date("2020-01-01"),
    home_team = "TeamA",
    away_team = "TeamB",
    home_score = 2,
    away_score = 1,
    neutral = FALSE,
    stringsAsFactors = FALSE
  )
  
  team_map_df <- data.frame(
    canonical_name = c("TeamA", "TeamB"),
    fifa_code = c("AAA", "BBB"),
    source_name = c("TeamA", "TeamB"),
    stringsAsFactors = FALSE
  )
  
  result <- compute_elo(matches_df, team_map_df, home_advantage = 0)
  
  # Check that ratings were computed
  expect_equal(nrow(result$current_ratings), 2)
  expect_equal(nrow(result$ratings_history), 4)  # 2 teams * 2 (pre+post)
  
  # Check that ratings changed from base (1500)
  # TeamA won at home, so should have higher rating
  team_a_rating <- result$current_ratings$rating[result$current_ratings$team == "TeamA"]
  team_b_rating <- result$current_ratings$rating[result$current_ratings$team == "TeamB"]
  
  expect_gt(team_a_rating, 1500)
  expect_lt(team_b_rating, 1500)
})

test_that("compute_elo handles chronological order", {
  matches_df <- data.frame(
    date = as.Date(c("2020-01-01", "2020-01-02")),
    home_team = c("TeamA", "TeamA"),
    away_team = c("TeamB", "TeamB"),
    home_score = c(2, 1),
    away_score = c(1, 2),
    neutral = c(FALSE, FALSE),
    stringsAsFactors = FALSE
  )
  
  team_map_df <- data.frame(
    canonical_name = c("TeamA", "TeamB"),
    fifa_code = c("AAA", "BBB"),
    source_name = c("TeamA", "TeamB"),
    stringsAsFactors = FALSE
  )
  
  result <- compute_elo(matches_df, team_map_df, home_advantage = 0)
  
  # After 2 matches, ratings should reflect both results
  expect_equal(nrow(result$current_ratings), 2)
  
  # First match: TeamA wins -> TeamA rating increases
  # Second match: TeamB wins -> TeamB rating increases
  # Final ratings should be closer to 1500 than after first match
  team_a_rating <- result$current_ratings$rating[result$current_ratings$team == "TeamA"]
  team_b_rating <- result$current_ratings$rating[result$current_ratings$team == "TeamB"]
  
  # After win then loss, TeamA should still be above 1500 but not as high
  expect_gt(team_a_rating, 1490)
  expect_lt(team_b_rating, 1510)
})

test_that("compute_elo applies home advantage", {
  matches_df <- data.frame(
    date = as.Date("2020-01-01"),
    home_team = "TeamA",
    away_team = "TeamB",
    home_score = 2,
    away_score = 1,
    neutral = FALSE,
    stringsAsFactors = FALSE
  )
  
  team_map_df <- data.frame(
    canonical_name = c("TeamA", "TeamB"),
    fifa_code = c("AAA", "BBB"),
    source_name = c("TeamA", "TeamB"),
    stringsAsFactors = FALSE
  )
  
  result_with_ha <- compute_elo(matches_df, team_map_df, home_advantage = 60)
  result_no_ha <- compute_elo(matches_df, team_map_df, home_advantage = 0)
  
  # With home advantage, the home team's effective rating is higher
  # This should result in different rating updates
  team_a_with_ha <- result_with_ha$current_ratings$rating[result_with_ha$current_ratings$team == "TeamA"]
  team_a_no_ha <- result_no_ha$current_ratings$rating[result_no_ha$current_ratings$team == "TeamA"]
  
  # The ratings should be different
  expect_true(team_a_with_ha != team_a_no_ha)
})

# Test input validation

context("input validation")

test_that("numeric validation works", {
  expect_error(expected_result("a", 1500), "must be numeric")
  expect_error(elo_update("a", 1500, 1, 20, 20), "must be numeric")
})

test_that("actual_result validation works", {
  expect_error(elo_update(1500, 1500, 2, 20, 20), "must be in")
  expect_error(elo_update(1500, 1500, -1, 20, 20), "must be in")
  expect_error(elo_update(1500, 1500, 0.6, 20, 20), "must be in")
})

test_that("k-factor validation works", {
  expect_error(elo_update(1500, 1500, 1, "20", 20), "must be numeric")
  expect_error(elo_update(1500, 1500, 1, 20, "20"), "must be numeric")
})
