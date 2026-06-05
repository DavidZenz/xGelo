# xGelo Integration Tests - Pipeline and Forecast Contracts

context("Pipeline Integration")

project_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))

predict.constant_goal_model <- function(object, newdata, type = "response", ...) {
  rep(object$lambda, nrow(newdata))
}

predict.two_bin_xg_model <- function(object, new_data, type = "prob", ...) {
  data.frame(
    ".pred_No Goal" = 1 - object$probabilities,
    ".pred_Goal" = object$probabilities,
    check.names = FALSE
  )
}
assign("predict.constant_goal_model", predict.constant_goal_model, envir = .GlobalEnv)
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
  expect_false(grepl("A/B", result$path, fixed = TRUE))
  expect_equal(result$forecast$fixture_id, "A/B_vs_C D_2026-01-01")
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
