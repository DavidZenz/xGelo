# xGelo Pipeline Definition
# This file defines the targets pipeline for the xGelo forecasting system

library(targets)

# Source all necessary functions
source("R/data_ingest/martj42.R")
source("R/data_ingest/statsbomb.R")
source("R/data_ingest/team_names.R")
source("R/xg/features.R")
source("R/xg/model.R")
source("R/xg/data_prep.R")
source("R/elo/runner.R")
source("R/integration/team_match_xg.R")
source("R/integration/rolling_form.R")
source("R/forecast/poisson.R")
source("R/forecast/monte_carlo.R")
source("R/forecast/output.R")
source("R/forecast/calibration.R")
source("R/pipeline/validation.R")

# Target: Raw data ingestion
tar_target(
  name = tar_data_raw,
  command = {
    # Ingest martj42 data
    martj42_data <- ingest_martj42()
    # Ingest StatsBomb data
    statsbomb_data <- ingest_statsbomb()
    # Save to cache
    saveRDS(martj42_data, "data/cache/martj42.rds")
    saveRDS(statsbomb_data, "data/cache/statsbomb.rds")
  },
  pattern = map(data_raw)
)

# Target: Clean data
tar_target(
  name = tar_data_clean,
  command = {
    # Load raw data
    martj42 <- readRDS("data/cache/martj42.rds")
    statsbomb <- readRDS("data/cache/statsbomb.rds")
    
    # Process and clean
    clean_data <- clean_and_normalize(martj42, statsbomb)
    
    # Save processed data
    write.csv(clean_data$results, "data/processed/results.csv", row.names = FALSE)
    
    # Also save original files for reference
    file.copy("data/raw/martj42/results.csv", "data/processed/martj42_results.csv")
  },
  pattern = "data/processed/results.csv",
  depends = tar_data_raw
)

# Target: Elo ratings
tar_target(
  name = tar_elo_ratings,
  command = {
    # Compute Elo ratings
    elo_ratings <- compute_elo_all()
    write.csv(elo_ratings, "data/processed/elo_ratings.csv", row.names = FALSE)
    saveRDS(elo_ratings, "data/processed/elo_ratings.rds")
  },
  pattern = "data/processed/elo_ratings.csv",
  packages = "dplyr",
  depends = tar_data_clean
)

# Target: xG model
tar_target(
  name = tar_xg_model,
  command = {
    # Prepare training data
    training_data <- prepare_training_data()
    
    # Train model
    xg_model <- train_xg_model(training_data)
    
    # Save model
    saveRDS(xg_model, "models/xg_model.rds")
    
    # Calibrate and backtest
    calibration <- calibrate_xg(xg_model)
    saveRDS(calibration, "models/xg_calibration.rds")
  },
  pattern = "models/xg_model.rds",
  packages = c("tidymodels", "dplyr"),
  depends = tar_data_clean
)

# Target: Team-match xG metrics
tar_target(
  name = tar_team_match_xg,
  command = {
    compute_team_match_xg(use_own_model = TRUE)
  },
  pattern = "data/processed/team_match_xg.csv",
  packages = c("dplyr", "jsonlite", "tidymodels"),
  depends = c(tar_data_clean, tar_xg_model)
)

# Target: Rolling form metrics
tar_target(
  name = tar_rolling_form,
  command = {
    compute_rolling_form()
  },
  pattern = "data/processed/rolling_form.csv",
  packages = "dplyr",
  depends = c(tar_team_match_xg, tar_elo_ratings)
)

# Target: Forecast models (home and away)
tar_target(
  name = tar_forecast_models,
  command = {
    train_home_goal_model()
    train_away_goal_model()
  },
  pattern = map(models_forecast),
  packages = c("MASS", "dplyr"),
  depends = c(tar_rolling_form, tar_elo_ratings)
)

# Target: Generate forecasts
tar_target(
  name = tar_forecasts,
  command = {
    # Generate forecasts for example fixtures
    fixtures <- data.frame(
      home_team = c("Spain", "Germany", "France"),
      away_team = c("Italy", "Netherlands", "England"),
      date = as.Date(c("2026-06-10", "2026-06-11", "2026-06-12")),
      venue = c("home", "home", "neutral"),
      stringsAsFactors = FALSE
    )
    generate_batch_forecasts(fixtures)
  },
  pattern = "outputs/forecasts",
  packages = "dplyr",
  depends = tar_forecast_models
)

# Target: Validation and reports
tar_target(
  name = tar_reports,
  command = {
    # Run calibration
    calibrate_model()
    
    # Run validation
    validate_pipeline()
  },
  pattern = c("outputs/visualizations/forecast_calibration.png", "outputs/pipeline_dag.png"),
  packages = c("ggplot2", "dplyr"),
  depends = tar_forecasts
)

# Target: DAG visualization
tar_target(
  name = tar_dag,
  command = {
    tar_visnetwork(
      filename = "outputs/pipeline_dag.png",
      labels = TRUE,
      main = "xGelo Pipeline DAG"
    )
  },
  pattern = "outputs/pipeline_dag.png",
  packages = "visNetwork",
  depends = c(tar_data_raw, tar_data_clean, tar_elo_ratings, tar_xg_model, 
              tar_team_match_xg, tar_rolling_form, tar_forecast_models, tar_forecasts, tar_reports)
)
