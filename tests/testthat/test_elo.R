# xGelo Unit Tests - Elo Calculation Logic

context("Elo Rating Calculations")

project_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))
source(file.path(project_root, "R/elo/runner.R"))
source(file.path(project_root, "R/elo/runner_optimized.R"))
source(file.path(project_root, "R/elo/preprocess.R"))

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

test_that("EloRatings fallback fills only missing matching World Cup scores", {
  results <- data.frame(
    date = as.Date(c("2026-06-13", "2026-06-13", "2026-06-13", "2026-06-13", "2026-06-14")),
    home_team = c("Brazil", "Qatar", "Australia", "Brazil", "Netherlands"),
    away_team = c("Morocco", "Switzerland", "Turkey", "Morocco", "Japan"),
    home_score = c(NA, NA, 9, NA, NA),
    away_score = c(NA, NA, 9, NA, NA),
    tournament = c("FIFA World Cup", "FIFA World Cup", "FIFA World Cup", "Friendly", "FIFA World Cup"),
    neutral = c(TRUE, TRUE, TRUE, TRUE, TRUE),
    stringsAsFactors = FALSE
  )
  eloratings <- data.frame(
    date = as.Date(c("2026-06-13", "2026-06-13", "2026-06-13", "2026-06-14")),
    home_team = c("Brazil", "Qatar", "Australia", "Japan"),
    away_team = c("Morocco", "Switzerland", "Turkey", "Netherlands"),
    home_score = c(1L, 1L, 2L, 2L),
    away_score = c(1L, 1L, 0L, 3L),
    stringsAsFactors = FALSE
  )

  updated <- apply_eloratings_score_fallback(results, eloratings)

  expect_equal(updated$home_score[1:2], c(1, 1))
  expect_equal(updated$away_score[1:2], c(1, 1))
  expect_equal(updated$score_source[1:2], rep("eloratings_fallback", 2))
  expect_equal(updated$home_score[3], 9)
  expect_equal(updated$away_score[3], 9)
  expect_equal(updated$score_source[3], "martj42")
  expect_true(is.na(updated$home_score[4]))
  expect_true(is.na(updated$away_score[4]))
  expect_equal(updated$home_score[5], 3)
  expect_equal(updated$away_score[5], 2)
  expect_equal(updated$score_source[5], "eloratings_fallback")
})

test_that("EloRatings parser maps known team code variants", {
  temp_dir <- tempfile("eloratings")
  dir.create(temp_dir)
  latest_path <- file.path(temp_dir, "latest.tsv")
  teams_path <- file.path(temp_dir, "en.teams.tsv")
  writeLines(c(
    "BR\tBrazil",
    "MA\tMorocco",
    "CH\tSwitzerland",
    "SQ\tScotland",
    "HT\tHaiti"
  ), teams_path, useBytes = TRUE)
  writeLines(c(
    "2026\t06\t13\tBR\tMA\t1\t1\tWC\tUS",
    "2026\t06\t13\tSQ\tHT\t1\t0\tWC\tUS"
  ), latest_path, useBytes = TRUE)

  parsed <- read_eloratings_latest_results(latest_path, teams_path)

  expect_equal(parsed$home_team, c("Brazil", "Scotland"))
  expect_equal(parsed$away_team, c("Morocco", "Haiti"))
  expect_equal(parsed$home_score, c(1L, 1L))
  expect_equal(parsed$away_score, c(1L, 0L))
})

test_that("World Cup ESPN fallback date window covers tournament through final", {
  dates <- worldcup_2026_scoreboard_dates(today = as.Date("2026-06-29"))

  expect_equal(min(dates), as.Date("2026-06-11"))
  expect_equal(max(dates), as.Date("2026-07-19"))
  expect_true(as.Date("2026-06-29") %in% dates)
})

test_that("ESPN scoreboard parser reads completed World Cup scores", {
  temp_dir <- tempfile("espn")
  dir.create(temp_dir)
  scoreboard_path <- file.path(temp_dir, "scoreboard_20260617.json")
  payload <- list(
    events = list(
      list(
        id = "760434",
        date = "2026-06-17T04:00Z",
        links = list(list(href = "https://www.espn.com/soccer/match/_/gameId/760434")),
        competitions = list(list(
          date = "2026-06-17T04:00Z",
          status = list(type = list(completed = TRUE, description = "Full Time")),
          competitors = list(
            list(
              homeAway = "home",
              score = "3",
              team = list(displayName = "Austria")
            ),
            list(
              homeAway = "away",
              score = "1",
              team = list(displayName = "Jordan")
            )
          )
        ))
      ),
      list(
        id = "760435",
        date = "2026-06-17T17:00Z",
        competitions = list(list(
          date = "2026-06-17T17:00Z",
          status = list(type = list(completed = FALSE, description = "Scheduled")),
          competitors = list(
            list(homeAway = "home", score = "0", team = list(displayName = "Portugal")),
            list(homeAway = "away", score = "0", team = list(displayName = "Congo DR"))
          )
        ))
      )
    )
  )
  jsonlite::write_json(payload, scoreboard_path, auto_unbox = TRUE)

  parsed <- read_espn_scoreboard_results(temp_dir)

  expect_equal(nrow(parsed), 1)
  expect_equal(parsed$date, as.Date("2026-06-17"))
  expect_equal(parsed$home_team, "Austria")
  expect_equal(parsed$away_team, "Jordan")
  expect_equal(parsed$home_score, 3L)
  expect_equal(parsed$away_score, 1L)
  expect_equal(parsed$espn_status, "Full Time")
})

test_that("ESPN fallback supports one-day event date tolerance and preserves existing sources", {
  results <- data.frame(
    date = as.Date(c("2026-06-16", "2026-06-16", "2026-06-17", "2026-06-17", "2026-06-19")),
    home_team = c("Argentina", "Austria", "France", "Portugal", "Turkey"),
    away_team = c("Algeria", "Jordan", "Senegal", "DR Congo", "Paraguay"),
    home_score = c(NA, NA, 3, NA, NA),
    away_score = c(NA, NA, 1, NA, NA),
    tournament = rep("FIFA World Cup", 5),
    neutral = rep(TRUE, 5),
    score_source = c(NA, NA, "eloratings_fallback", NA, NA),
    stringsAsFactors = FALSE
  )
  espn <- data.frame(
    date = as.Date(c("2026-06-17", "2026-06-17", "2026-06-17", "2026-06-17", "2026-06-20")),
    home_team = c("Argentina", "Austria", "France", "Congo DR", "Türkiye"),
    away_team = c("Algeria", "Jordan", "Senegal", "Portugal", "Paraguay"),
    home_score = c(3L, 3L, 9L, 2L, 0L),
    away_score = c(0L, 1L, 9L, 1L, 1L),
    stringsAsFactors = FALSE
  )

  updated <- apply_espn_score_fallback(
    results,
    espn,
    date_tolerance_days = 1L,
    team_map_path = file.path(project_root, "data/raw/team_name_map.csv")
  )

  expect_equal(updated$home_score[1:2], c(3, 3))
  expect_equal(updated$away_score[1:2], c(0, 1))
  expect_equal(updated$score_source[1:2], rep("espn_scoreboard_fallback", 2))
  expect_equal(updated$home_score[3], 3)
  expect_equal(updated$away_score[3], 1)
  expect_equal(updated$score_source[3], "eloratings_fallback")
  expect_equal(updated$home_score[4], 1)
  expect_equal(updated$away_score[4], 2)
  expect_equal(updated$score_source[4], "espn_scoreboard_fallback")
  expect_equal(updated$home_score[5], 0)
  expect_equal(updated$away_score[5], 1)
  expect_equal(updated$score_source[5], "espn_scoreboard_fallback")
})
