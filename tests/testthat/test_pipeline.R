# xGelo Integration Tests - Pipeline and Forecast Contracts

context("Pipeline Integration")

project_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))

predict.constant_goal_model <- function(object, newdata, type = "response", ...) {
  rep(object$lambda, nrow(newdata))
}

predict.side_context_goal_model <- function(object, newdata, type = "response", ...) {
  exp(log(object$base_lambda) + object$elo_slope * newdata$elo_diff)
}

predict.two_bin_xg_model <- function(object, new_data, type = "prob", ...) {
  data.frame(
    ".pred_No Goal" = 1 - object$probabilities,
    ".pred_Goal" = object$probabilities,
    check.names = FALSE
  )
}
assign("predict.constant_goal_model", predict.constant_goal_model, envir = .GlobalEnv)
assign("predict.side_context_goal_model", predict.side_context_goal_model, envir = .GlobalEnv)
assign("predict.two_bin_xg_model", predict.two_bin_xg_model, envir = .GlobalEnv)

test_that("all source files parse and source cleanly", {
  r_files <- list.files(file.path(project_root, "R"), pattern = "[.]R$", recursive = TRUE, full.names = TRUE)
  expect_gt(length(r_files), 0)

  for (file in r_files) {
    expect_error(sys.source(file, envir = new.env(parent = globalenv())), NA)
  }
})

test_that("targets pipeline definition loads", {
  oldwd <- setwd(project_root)
  on.exit(setwd(oldwd), add = TRUE)
  expect_error(source("_targets.R", local = new.env(parent = globalenv())), NA)
})

test_that("validation checks current checked-in artifacts", {
  source(file.path(project_root, "R/pipeline/validation.R"))
  oldwd <- setwd(project_root)
  on.exit(setwd(oldwd), add = TRUE)
  result <- run_validation_checks()
  expect_true(result$all_passed)
})

test_that("forecasts use team-specific Elo inputs", {
  source(file.path(project_root, "R/forecast/monte_carlo.R"))
  oldwd <- setwd(project_root)
  on.exit(setwd(oldwd), add = TRUE)

  strong_home <- simulate_fixture("France", "San Marino", date = as.Date("2026-06-12"), venue = "neutral", n_sim = 1000, seed = 123)
  weak_home <- simulate_fixture("San Marino", "France", date = as.Date("2026-06-12"), venue = "neutral", n_sim = 1000, seed = 123)

  expect_gt(strong_home$win_prob, weak_home$win_prob)
  expect_equal(strong_home$total_prob, 1, tolerance = 0.001)
  expect_equal(weak_home$total_prob, 1, tolerance = 0.001)
})

test_that("negative-binomial simulation preserves predicted goal means", {
  source(file.path(project_root, "R/forecast/monte_carlo.R"))

  home_model_path <- tempfile(fileext = ".rds")
  away_model_path <- tempfile(fileext = ".rds")
  elo_ratings_path <- tempfile(fileext = ".csv")

  saveRDS(structure(list(lambda = 1.4), class = "constant_goal_model"), home_model_path)
  saveRDS(structure(list(lambda = 0.7), class = "constant_goal_model"), away_model_path)
  write.csv(
    data.frame(
      date = as.Date(c("2020-01-01", "2020-01-01")),
      team = c("A", "B"),
      rating = c(1500, 1500),
      is_post_match = c(TRUE, TRUE),
      stringsAsFactors = FALSE
    ),
    elo_ratings_path,
    row.names = FALSE
  )

  result <- simulate_fixture(
    "A",
    "B",
    date = as.Date("2020-02-01"),
    venue = "neutral",
    home_model_path = home_model_path,
    away_model_path = away_model_path,
    elo_ratings_path = elo_ratings_path,
    n_sim = 30000,
    seed = 321
  )

  expect_equal(result$expected_home, 1.4, tolerance = 0.08)
  expect_equal(result$expected_away, 0.7, tolerance = 0.08)
  expect_equal(result$total_prob, 1, tolerance = 0.001)
})

test_that("negative-binomial theta prevents scoreline distributions from becoming too zero-heavy", {
  source(file.path(project_root, "R/forecast/monte_carlo.R"))

  home_model_path <- tempfile(fileext = ".rds")
  away_model_path <- tempfile(fileext = ".rds")
  elo_ratings_path <- tempfile(fileext = ".csv")

  saveRDS(structure(list(lambda = 2.8, theta = 100), class = c("constant_goal_model", "negbin")), home_model_path)
  saveRDS(structure(list(lambda = 0.5, theta = 100), class = c("constant_goal_model", "negbin")), away_model_path)
  write.csv(
    data.frame(
      date = as.Date(c("2020-01-01", "2020-01-01")),
      team = c("A", "B"),
      rating = c(1500, 1500),
      is_post_match = c(TRUE, TRUE),
      stringsAsFactors = FALSE
    ),
    elo_ratings_path,
    row.names = FALSE
  )

  result <- simulate_fixture(
    "A",
    "B",
    date = as.Date("2020-02-01"),
    venue = "neutral",
    home_model_path = home_model_path,
    away_model_path = away_model_path,
    elo_ratings_path = elo_ratings_path,
    n_sim = 50000,
    seed = 777
  )

  expect_equal(result$expected_home, 2.8, tolerance = 0.08)
  expect_equal(result$expected_away, 0.5, tolerance = 0.08)
  expect_false(result$most_likely_score == "0-0")
  expect_true(result$most_likely_home_goals > result$most_likely_away_goals)
})

test_that("neutral fixtures do not depend on nominal home-team ordering", {
  source(file.path(project_root, "R/forecast/monte_carlo.R"))

  home_model_path <- tempfile(fileext = ".rds")
  away_model_path <- tempfile(fileext = ".rds")
  elo_ratings_path <- tempfile(fileext = ".csv")

  saveRDS(structure(list(base_lambda = 1.6, elo_slope = 0.001, theta = 100), class = "side_context_goal_model"), home_model_path)
  saveRDS(structure(list(base_lambda = 0.9, elo_slope = 0.001, theta = 100), class = "side_context_goal_model"), away_model_path)
  write.csv(
    data.frame(
      date = as.Date(c("2020-01-01", "2020-01-01")),
      team = c("A", "B"),
      rating = c(1600, 1500),
      is_post_match = c(TRUE, TRUE),
      stringsAsFactors = FALSE
    ),
    elo_ratings_path,
    row.names = FALSE
  )

  ab <- simulate_fixture(
    "A",
    "B",
    date = as.Date("2020-02-01"),
    venue = "neutral",
    home_model_path = home_model_path,
    away_model_path = away_model_path,
    elo_ratings_path = elo_ratings_path,
    n_sim = 80000,
    seed = 1001
  )
  ba <- simulate_fixture(
    "B",
    "A",
    date = as.Date("2020-02-01"),
    venue = "neutral",
    home_model_path = home_model_path,
    away_model_path = away_model_path,
    elo_ratings_path = elo_ratings_path,
    n_sim = 80000,
    seed = 1001
  )

  expect_equal(ab$expected_home, ba$expected_away, tolerance = 0.03)
  expect_equal(ab$expected_away, ba$expected_home, tolerance = 0.03)
  expect_equal(ab$win_prob, ba$loss_prob, tolerance = 0.02)
  expect_equal(ab$loss_prob, ba$win_prob, tolerance = 0.02)
})

test_that("scoreline distribution and derived forecast summaries are coherent", {
  source(file.path(project_root, "R/forecast/monte_carlo.R"))

  home_model_path <- tempfile(fileext = ".rds")
  away_model_path <- tempfile(fileext = ".rds")
  elo_ratings_path <- tempfile(fileext = ".csv")

  saveRDS(structure(list(lambda = 1.2), class = "constant_goal_model"), home_model_path)
  saveRDS(structure(list(lambda = 0.8), class = "constant_goal_model"), away_model_path)
  write.csv(
    data.frame(
      date = as.Date(c("2020-01-01", "2020-01-01")),
      team = c("A", "B"),
      rating = c(1500, 1500),
      is_post_match = c(TRUE, TRUE),
      stringsAsFactors = FALSE
    ),
    elo_ratings_path,
    row.names = FALSE
  )

  result <- simulate_fixture(
    "A",
    "B",
    date = as.Date("2020-02-01"),
    venue = "neutral",
    home_model_path = home_model_path,
    away_model_path = away_model_path,
    elo_ratings_path = elo_ratings_path,
    n_sim = 20000,
    seed = 99
  )

  dist <- result$scoreline_distribution
  expect_true(all(c("home_goals", "away_goals", "scoreline", "outcome", "count", "probability") %in% names(dist)))
  expect_equal(sum(dist$probability), 1, tolerance = 0.001)
  expect_equal(result$total_prob, 1, tolerance = 0.001)
  expect_equal(result$expected_home, 1.2, tolerance = 0.08)
  expect_equal(result$expected_away, 0.8, tolerance = 0.08)

  modal <- dist[order(-dist$probability, dist$home_goals + dist$away_goals, dist$home_goals, dist$away_goals), ][1, ]
  expect_equal(result$most_likely_score, modal$scoreline)
  expect_equal(result$most_likely_score_probability, modal$probability)
  expect_true(result$predicted_outcome %in% c("home_win", "draw", "away_win"))
  expect_equal(
    result$both_teams_to_score_probability,
    sum(dist$probability[dist$home_goals > 0 & dist$away_goals > 0]),
    tolerance = 0.001
  )
  expect_equal(
    result$over_2_5_probability,
    sum(dist$probability[dist$home_goals + dist$away_goals > 2.5]),
    tolerance = 0.001
  )
  expect_equal(result$over_2_5_probability + result$under_2_5_probability, 1, tolerance = 0.001)
})

test_that("forecast output sanitizes filenames", {
  source(file.path(project_root, "R/forecast/monte_carlo.R"))
  source(file.path(project_root, "R/forecast/output.R"))
  oldwd <- setwd(project_root)
  on.exit(setwd(oldwd), add = TRUE)

  out_dir <- tempfile("forecasts-")
  result <- suppressWarnings(
    generate_forecast(
      home_team = "A/B",
      away_team = "C D",
      date = as.Date("2026-01-01"),
      output_dir = out_dir,
      n_sim = 100,
      seed = 1
    )
  )

  expect_true(file.exists(result$path))
  expect_true(file.exists(result$forecast_path))
  expect_true(file.exists(result$scorelines_path))
  expect_false(grepl("A/B", result$path, fixed = TRUE))
  expect_false(grepl("A/B", result$scorelines_path, fixed = TRUE))
  expect_equal(result$forecast$fixture_id, "A/B_vs_C D_2026-01-01")
  expect_true(all(c(
    "win_probability",
    "draw_probability",
    "loss_probability",
    "predicted_outcome",
    "most_likely_score",
    "most_likely_score_probability",
    "rounded_expected_score",
    "over_2_5_probability",
    "under_2_5_probability",
    "both_teams_to_score_probability",
    "n_sim"
  ) %in% names(result$forecast)))
  expect_gt(nchar(result$forecast$predicted_outcome), 0)
  expect_gt(nchar(result$forecast$most_likely_score), 0)
  scorelines <- read.csv(result$scorelines_path, stringsAsFactors = FALSE)
  expect_true(all(c("home_goals", "away_goals", "scoreline", "outcome", "count", "probability") %in% names(scorelines)))
})

test_that("group table ranking falls back to points, goal difference, goals for, and seeded ties", {
  source(file.path(project_root, "R/forecast/tournament.R"))

  table <- data.frame(
    team = c("A", "B", "C", "D"),
    points = c(4, 4, 4, 1),
    goal_difference = c(1, 2, 2, -5),
    goals_for = c(5, 4, 6, 0),
    tie_breaker = c(0.2, 0.1, 0.9, 0.3),
    stringsAsFactors = FALSE
  )

  ranked <- rank_group_table(table)
  expect_equal(ranked$team, c("C", "B", "A", "D"))
})

test_that("group table ranking applies FIFA head-to-head tiebreakers before overall goal difference", {
  source(file.path(project_root, "R/forecast/tournament.R"))

  table <- data.frame(
    team = c("Turkey", "Paraguay", "Australia", "United States"),
    points = c(3, 3, 6, 6),
    goal_difference = c(1, -1, 2, 3),
    goals_for = c(3, 1, 4, 5),
    tie_breaker = c(0.4, 0.3, 0.2, 0.1),
    stringsAsFactors = FALSE
  )
  matches <- data.frame(
    home_team = c("Turkey", "United States", "Australia", "Turkey", "Turkey", "Paraguay"),
    away_team = c("Paraguay", "Australia", "Turkey", "United States", "Australia", "United States"),
    home_goals = c(0, 2, 2, 1, 3, 0),
    away_goals = c(1, 0, 0, 3, 0, 1),
    stringsAsFactors = FALSE
  )

  ranked <- rank_group_table(table, matches)
  expect_equal(ranked$team, c("United States", "Australia", "Paraguay", "Turkey"))
})

test_that("tournament simulation resolves group ties and knockout draws reproducibly", {
  source(file.path(project_root, "R/forecast/monte_carlo.R"))
  source(file.path(project_root, "R/forecast/tournament.R"))

  home_model_path <- tempfile(fileext = ".rds")
  away_model_path <- tempfile(fileext = ".rds")
  elo_ratings_path <- tempfile(fileext = ".csv")

  saveRDS(structure(list(lambda = 0), class = "constant_goal_model"), home_model_path)
  saveRDS(structure(list(lambda = 0), class = "constant_goal_model"), away_model_path)
  write.csv(
    data.frame(
      date = as.Date(rep("2020-01-01", 4)),
      team = c("A", "B", "C", "D"),
      rating = rep(1500, 4),
      is_post_match = rep(TRUE, 4),
      stringsAsFactors = FALSE
    ),
    elo_ratings_path,
    row.names = FALSE
  )

  fixtures <- data.frame(
    match_id = c("g1", "g2", "f1"),
    stage = c("group", "group", "final"),
    group = c("A", "A", NA),
    home_team = c("A", "C", "A"),
    away_team = c("B", "D", "B"),
    date = as.Date(c("2026-06-01", "2026-06-01", "2026-07-19")),
    venue = c("neutral", "neutral", "neutral"),
    stringsAsFactors = FALSE
  )

  first <- simulate_tournament(
    fixtures,
    n_tournaments = 20,
    n_match_sim = 50,
    seed = 123,
    home_model_path = home_model_path,
    away_model_path = away_model_path,
    elo_ratings_path = elo_ratings_path
  )
  second <- simulate_tournament(
    fixtures,
    n_tournaments = 20,
    n_match_sim = 50,
    seed = 123,
    home_model_path = home_model_path,
    away_model_path = away_model_path,
    elo_ratings_path = elo_ratings_path
  )

  expect_equal(first$stage_probabilities, second$stage_probabilities)
  expect_equal(sum(first$champion_probabilities$champion_probability), 1, tolerance = 0.001)
  expect_equal(sum(first$stage_probabilities$group_probability), 4, tolerance = 0.001)
  expect_true(all(!is.na(first$sampled_tournament$advancing_team[first$sampled_tournament$stage == "final"])))
  expect_true(all(c("team", "expected_points", "expected_goals_for", "expected_goals_against") %in% names(first$team_expectations)))
})

test_that("xG calibration plot uses per-bin actual rates", {
  source(file.path(project_root, "R/visualization/calibration.R"))

  model_path <- tempfile(fileext = ".rds")
  test_data_path <- tempfile(fileext = ".rds")
  output_path <- tempfile(fileext = ".png")

  saveRDS(
    structure(list(probabilities = c(0.1, 0.2, 0.8, 0.9)), class = "two_bin_xg_model"),
    model_path
  )
  saveRDS(
    data.frame(
      distance = c(10, 20, 30, 40),
      angle = c(0.2, 0.3, 0.4, 0.5),
      header = c(FALSE, FALSE, FALSE, FALSE),
      open_play = c(TRUE, TRUE, TRUE, TRUE),
      competition = c("Test", "Test", "Test", "Test"),
      goal = factor(c("No Goal", "No Goal", "Goal", "Goal"), levels = c("No Goal", "Goal")),
      stringsAsFactors = FALSE
    ),
    test_data_path
  )

  plot <- generate_xg_calibration(model_path, test_data_path, output_path)
  actual_rates <- sort(unique(plot$data$mean_actual))
  expect_equal(actual_rates, c(0, 1))
})

test_that("forecast calibration can run standalone", {
  source(file.path(project_root, "R/forecast/calibration.R"))
  oldwd <- setwd(project_root)
  on.exit(setwd(oldwd), add = TRUE)

  matches_path <- tempfile(fileext = ".csv")
  write.csv(
    data.frame(
      date = as.Date("2026-06-12"),
      home_team_canonical = "France",
      away_team_canonical = "England",
      home_score = 1,
      away_score = 1,
      neutral = TRUE,
      stringsAsFactors = FALSE
    ),
    matches_path,
    row.names = FALSE
  )

  expect_error(
    calibrate_model(
      matches_data_path = matches_path,
      n_sample = 1,
      n_sim = 50,
      output_path = tempfile(fileext = ".png")
    ),
    NA
  )
})
