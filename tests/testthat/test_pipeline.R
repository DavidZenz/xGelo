# xGelo Integration Tests - Full Pipeline
# Run with: testthat::test_dir('tests/testthat')

context("Pipeline Integration")

# Test 1: All required files exist
test_that("All required pipeline files exist", {
  required_files <- c(
    "data/raw/martj42/results.csv",
    "data/processed/elo_matches.csv",
    "data/processed/elo_ratings.csv",
    "data/processed/team_match_xg.csv",
    "data/processed/rolling_form.csv",
    "models/xg_model.rds",
    "models/home_goal_model.rds",
    "models/away_goal_model.rds"
  )
  
  missing <- required_files[!file.exists(required_files)]
  expect_equal(length(missing), 0)
})

# Test 2: All required directories exist
test_that("All required directories exist", {
  required_dirs <- c(
    "data/raw/martj42",
    "data/raw/statsbomb",
    "data/processed",
    "models",
    "outputs/forecasts",
    "outputs/visualizations",
    "R/xg",
    "R/elo",
    "R/integration",
    "R/forecast",
    "R/pipeline"
  )
  
  missing_dirs <- required_dirs[!dir.exists(required_dirs)]
  expect_equal(length(missing_dirs), 0)
})

# Test 3: Models are valid RDS files
test_that("Model files are valid", {
  model_files <- c(
    "models/xg_model.rds",
    "models/home_goal_model.rds",
    "models/away_goal_model.rds"
  )
  
  for (file in model_files) {
    if (file.exists(file)) {
      model <- tryCatch(readRDS(file), error = function(e) NULL)
      expect_true(!is.null(model))
    }
  }
})

# Test 4: Forecasts are valid
test_that("Forecast files are valid", {
  forecast_dir <- "outputs/forecasts"
  if (dir.exists(forecast_dir)) {
    forecast_files <- list.files(forecast_dir, pattern = "\\.csv$", full.names = TRUE)
    expect_true(length(forecast_files) > 0)
    
    for (file in forecast_files) {
      data <- tryCatch(read.csv(file), error = function(e) NULL)
      expect_true(!is.null(data))
      
      if (!is.null(data)) {
        expect_true("win_probability" %in% names(data))
        expect_true("draw_probability" %in% names(data))
        expect_true("loss_probability" %in% names(data))
      }
    }
  }
})

# Test 5: Pipeline can be reconstructed
test_that("Pipeline structure is valid", {
  phase_dirs <- c(
    ".planning/phases/01-data-ingestion",
    ".planning/phases/02-xg-model",
    ".planning/phases/03-elo-system",
    ".planning/phases/04-integration-layer",
    ".planning/phases/05-forecast"
  )
  
  for (dir in phase_dirs) {
    expect_true(dir.exists(dir))
  }
})

# Test 6: Script files exist
test_that("All R scripts exist", {
  r_scripts <- list.files("R", recursive = TRUE, pattern = "\\.R$")
  expect_true(length(r_scripts) > 0)
  
  key_scripts <- c(
    "R/xg/features.R",
    "R/elo/runner.R",
    "R/integration/team_match_xg.R",
    "R/integration/rolling_form.R",
    "R/forecast/poisson.R",
    "R/forecast/monte_carlo.R",
    "R/forecast/output.R",
    "R/forecast/calibration.R",
    "R/pipeline/validation.R"
  )
  
  for (script in key_scripts) {
    expect_true(file.exists(script))
  }
})

# Test 7: Probabilities sum to 1
test_that("Probabilities sum to 1", {
  forecast_dir <- "outputs/forecasts"
  if (dir.exists(forecast_dir)) {
    forecast_files <- list.files(forecast_dir, pattern = "\\.csv$", full.names = TRUE)
    
    for (file in forecast_files) {
      data <- read.csv(file)
      if (all(c("win_probability", "draw_probability", "loss_probability") %in% names(data))) {
        prob_sum <- data$win_probability + data$draw_probability + data$loss_probability
        expect_true(all(abs(prob_sum - 1) < 0.001, na.rm = TRUE))
      }
    }
  }
})
