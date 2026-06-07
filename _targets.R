# xGelo Pipeline Definition
# This file defines an executable targets pipeline for the xGelo forecasting system.

library(targets)

tar_option_set(
  packages = c(
    "dplyr",
    "jsonlite",
    "lubridate",
    "MASS",
    "pROC",
    "tidymodels",
    "ggplot2"
  )
)

source("R/elo/preprocess.R")
source("R/elo/runner_optimized.R")
source("R/elo/validation.R")
source("R/xg/features.R")
source("R/xg/model.R")
source("R/xg/data_prep.R")
source("R/xg/backtest.R")
source("R/xg/calibration.R")
source("R/integration/team_match_xg.R")
source("R/integration/rolling_form.R")
source("R/forecast/poisson.R")
source("R/forecast/monte_carlo.R")
source("R/forecast/output.R")
source("R/forecast/tournament.R")
source("R/forecast/calibration.R")
source("R/pipeline/validation.R")
source("R/visualization/auc.R")
source("R/visualization/calibration.R")
source("R/visualization/worldcup_dashboard.R")

list(
  tar_target(
    team_map,
    read.csv("data/raw/team_name_map.csv", stringsAsFactors = FALSE)
  ),
  tar_target(
    elo_matches,
    preprocess_martj42()
  ),
  tar_target(
    elo_result,
    compute_elo_optimized(elo_matches, team_map, home_advantage = 60)
  ),
  tar_target(
    elo_ratings_file,
    {
      write.csv(elo_result$ratings_history, "data/processed/elo_ratings.csv", row.names = FALSE)
      write.csv(elo_result$current_ratings, "data/processed/elo_current.csv", row.names = FALSE)
      "data/processed/elo_ratings.csv"
    },
    format = "file"
  ),
  tar_target(
    xg_split,
    prepare_and_split_data(
      events_dir = "data/raw/statsbomb/events",
      competitions_file = "data/raw/statsbomb/competitions.json",
      domestic_only = TRUE,
      competition_name = "La Liga",
      allow_unmapped_sample = TRUE
    )
  ),
  tar_target(
    xg_model,
    train_and_save_xg_model(xg_split$train_data)
  ),
  tar_target(
    xg_backtest,
    backtest_xg_model(xg_model, xg_split$test_data)
  ),
  tar_target(
    xg_calibration,
    calibrate_xg_model(xg_model, xg_split$test_data)
  ),
  tar_target(
    team_match_xg_file,
    {
      xg_model
      compute_team_match_xg(use_own_model = TRUE)
      "data/processed/team_match_xg.csv"
    },
    format = "file"
  ),
  tar_target(
    rolling_form_file,
    {
      team_match_xg_file
      elo_ratings_file
      compute_rolling_form()
      "data/processed/rolling_form.csv"
    },
    format = "file"
  ),
  tar_target(
    home_goal_model,
    {
      elo_ratings_file
      train_home_goal_model()
    }
  ),
  tar_target(
    away_goal_model,
    {
      elo_ratings_file
      train_away_goal_model()
    }
  ),
  tar_target(
    forecasts,
    {
      home_goal_model
      away_goal_model
      fixtures <- data.frame(
        home_team = c("Spain", "Germany", "France"),
        away_team = c("Italy", "Netherlands", "England"),
        date = as.Date(c("2026-06-10", "2026-06-11", "2026-06-12")),
        venue = c("home", "home", "neutral"),
        stringsAsFactors = FALSE
      )
      generate_batch_forecasts(fixtures)
    }
  ),
  tar_target(
    forecast_calibration,
    {
      forecasts
      calibrate_model(n_sample = 100, n_sim = 1000)
    }
  ),
  tar_target(
    validation,
    {
      forecast_calibration
      run_validation_checks()
    }
  ),
  tar_target(
    auc_chart,
    {
      xg_backtest
      generate_auc_chart()
    }
  ),
  tar_target(
    calibration_plots,
    {
      forecast_calibration
      xg_calibration
      run_calibration_plots()
    }
  ),
  tar_target(
    worldcup_dashboard_file,
    {
      home_goal_model
      away_goal_model
      elo_ratings_file
      dashboard <- build_worldcup_dashboard(n_match_sim = 5000, n_tournaments = 5000)
      dashboard$paths$html
    },
    format = "file"
  )
)
