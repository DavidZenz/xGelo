# xGelo Unit Tests - Elo Calculation Logic

context("Elo Rating Calculations")

project_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))
source(file.path(project_root, "R/elo/runner.R"))
source(file.path(project_root, "R/elo/runner_optimized.R"))

test_that("expected_result is symmetric for equal teams", {
  expect_equal(expected_result(1500, 1500), 0.5, tolerance = 0.001)
  expect_gt(expected_result(1600, 1500), 0.5)
  expect_lt(expected_result(1400, 1500), 0.5)
})

test_that("elo_update handles wins and draws", {
  win <- elo_update(1500, 1500, actual_result = 1, k_factor_a = 20, k_factor_b = 20, home_advantage = 0)
  expect_gt(win$rating_a, 1500)
  expect_lt(win$rating_b, 1500)
  
  draw <- elo_update(1500, 1500, actual_result = 0.5, k_factor_a = 20, k_factor_b = 20, home_advantage = 0)
  expect_equal(draw$rating_a, 1500, tolerance = 0.001)
  expect_equal(draw$rating_b, 1500, tolerance = 0.001)
})

test_that("home advantage changes expected update", {
  home <- elo_update(1500, 1500, actual_result = 1, k_factor_a = 20, k_factor_b = 20, home_advantage = 60)
  neutral <- elo_update(1500, 1500, actual_result = 1, k_factor_a = 20, k_factor_b = 20, home_advantage = 0)
  expect_lt(home$rating_a - 1500, neutral$rating_a - 1500)
})

test_that("compute_elo processes small chronological fixture data", {
  matches <- data.frame(
    date = as.Date(c("2020-01-01", "2020-02-01")),
    home_team = c("A", "B"),
    away_team = c("B", "A"),
    home_score = c(2, 1),
    away_score = c(1, 1),
    neutral = c(FALSE, TRUE),
    stringsAsFactors = FALSE
  )
  team_map <- data.frame(
    source_name = c("A", "B"),
    canonical_name = c("A", "B"),
    fifa_code = c("AAA", "BBB"),
    stringsAsFactors = FALSE
  )
  
  result <- compute_elo(matches, team_map, home_advantage = 60)
  expect_equal(nrow(result$matches_processed), 2)
  expect_equal(nrow(result$ratings_history), 8)
  expect_true(all(c("A", "B") %in% result$current_ratings$team))
})

test_that("Elo yearly match counters reset across calendar years", {
  matches <- data.frame(
    date = as.Date(c("2020-01-01", "2021-01-01")),
    home_team = c("A", "A"),
    away_team = c("B", "B"),
    home_score = c(1, 1),
    away_score = c(0, 0),
    neutral = c(TRUE, TRUE),
    stringsAsFactors = FALSE
  )
  team_map <- data.frame(
    source_name = c("A", "B"),
    canonical_name = c("A", "B"),
    fifa_code = c("AAA", "BBB"),
    stringsAsFactors = FALSE
  )
  
  regular <- compute_elo(matches, team_map, home_advantage = 0)$current_ratings
  expect_equal(regular$matches_last_year[regular$team == "A"], 1)
  expect_equal(regular$matches_this_year[regular$team == "A"], 1)
  expect_equal(regular$matches_last_year[regular$team == "B"], 1)
  expect_equal(regular$matches_this_year[regular$team == "B"], 1)
  
  optimized_matches <- transform(
    matches,
    home_team_canonical = home_team,
    away_team_canonical = away_team,
    result = ifelse(home_score > away_score, 1, ifelse(home_score == away_score, 0.5, 0)),
    is_home = !neutral
  )
  optimized <- compute_elo_optimized(optimized_matches, team_map, home_advantage = 0)$current_ratings
  expect_equal(optimized$matches_last_year[optimized$team == "A"], 1)
  expect_equal(optimized$matches_this_year[optimized$team == "A"], 1)
  expect_equal(optimized$matches_last_year[optimized$team == "B"], 1)
  expect_equal(optimized$matches_this_year[optimized$team == "B"], 1)
})

test_that("optimized Elo skips unscored future fixtures", {
  matches <- data.frame(
    date = as.Date(c("2026-06-01", "2026-06-12")),
    home_team_canonical = c("A", "A"),
    away_team_canonical = c("B", "B"),
    home_score = c(2, NA),
    away_score = c(1, NA),
    neutral = c(TRUE, TRUE),
    result = c(1, NA),
    is_home = c(FALSE, FALSE),
    stringsAsFactors = FALSE
  )
  team_map <- data.frame(
    source_name = c("A", "B"),
    canonical_name = c("A", "B"),
    fifa_code = c("AAA", "BBB"),
    stringsAsFactors = FALSE
  )

  result <- compute_elo_optimized(matches, team_map, home_advantage = 0)

  expect_equal(nrow(result$matches_processed), 1)
  expect_true(all(is.finite(result$current_ratings$rating)))
  expect_equal(max(result$current_ratings$last_match_date), as.Date("2026-06-01"))
})
