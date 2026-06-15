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
    "ggplot2",
    "DBI",
    "duckdb"
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
source("R/transfermarkt/squad_strength.R")
source("R/forecast/features.R")
source("R/forecast/xg_usage_audit.R")
source("R/forecast/goal_ability.R")
source("R/forecast/poisson.R")
source("R/forecast/monte_carlo.R")
source("R/forecast/output.R")
source("R/forecast/tournament.R")
source("R/forecast/calibration.R")
source("R/benchmark/euro2024.R")
source("R/benchmark/euro2024_tournament.R")
source("R/pipeline/validation.R")
source("R/visualization/auc.R")
source("R/visualization/calibration.R")
source("R/visualization/worldcup_dashboard.R")

xgelo_feature_cutoff_date <- function(default = Sys.Date() - 1L) {
  value <- Sys.getenv("XGELO_FEATURE_CUTOFF_DATE", unset = "")
  if (!nzchar(value)) return(as.Date(default))
  parsed <- as.Date(value)
  if (is.na(parsed)) {
    stop("XGELO_FEATURE_CUTOFF_DATE must parse as an ISO date, for example 2026-06-10", call. = FALSE)
  }
  parsed
}

xgelo_model_training_cutoff_date <- function(default = Sys.Date()) {
  value <- Sys.getenv("XGELO_MODEL_TRAINING_CUTOFF_DATE", unset = "")
  if (!nzchar(value)) return(as.Date(default))
  parsed <- as.Date(value)
  if (is.na(parsed)) {
    stop("XGELO_MODEL_TRAINING_CUTOFF_DATE must parse as an ISO date, for example 2026-06-12", call. = FALSE)
  }
  parsed
}

list(
  tar_target(
    team_map,
    read.csv("data/raw/team_name_map.csv", stringsAsFactors = FALSE)
  ),
  tar_target(
    eloratings_fallback_files,
    download_eloratings_fallback_files()
  ),
  tar_target(
    elo_matches,
    {
      eloratings_fallback_files
      preprocess_martj42()
    }
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
    transfermarkt_squad_strength_file,
    {
      snapshot_path <- "data/raw/transfermarkt/transfermarkt-datasets.duckdb"
      use_transfermarkt <- isTRUE(getOption("xgelo.use_transfermarkt", file.exists(snapshot_path)))
      if (!use_transfermarkt || !file.exists(snapshot_path)) {
        NA_character_
      } else {
        compute_transfermarkt_squad_strength_snapshots(
          snapshot_path = snapshot_path,
          as_of_dates = sort(unique(c(
            seq(as.Date("2000-01-01"), Sys.Date(), by = "6 months"),
            as.Date("2024-06-14"),
            xgelo_feature_cutoff_date(),
            xgelo_model_training_cutoff_date(),
            Sys.Date()
          ))),
          output_path = "data/processed/transfermarkt_squad_strength.csv"
        )
        write_transfermarkt_snapshot_metadata()
        "data/processed/transfermarkt_squad_strength.csv"
      }
    }
  ),
  tar_target(
    transfermarkt_value_audit_file,
    {
      snapshot_path <- "data/raw/transfermarkt/transfermarkt-datasets.duckdb"
      if (
        is.na(transfermarkt_squad_strength_file) ||
          !file.exists(transfermarkt_squad_strength_file) ||
          !file.exists(snapshot_path)
      ) {
        NA_character_
      } else {
        groups <- read.csv("data/raw/worldcup_2026_groups.csv", stringsAsFactors = FALSE)
        audit_transfermarkt_value_divergence(
          squad_strength = transfermarkt_squad_strength_file,
          snapshot_path = snapshot_path,
          teams = groups$team,
          cutoff_date = xgelo_feature_cutoff_date(),
          output_path = "data/processed/transfermarkt_value_audit.csv"
        )
        "data/processed/transfermarkt_value_audit.csv"
      }
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
    hybrid_goal_training_features_file,
    {
      if (is.na(transfermarkt_squad_strength_file) || !file.exists(transfermarkt_squad_strength_file)) {
        NA_character_
      } else {
        matches <- read.csv("data/processed/elo_matches.csv", stringsAsFactors = FALSE)
        matches$date <- as.Date(matches$date)
        training <- matches[
          matches$date < xgelo_model_training_cutoff_date() &
            !is.na(matches$home_score) &
            !is.na(matches$away_score) &
            !is.na(matches$home_team_canonical) &
            !is.na(matches$away_team_canonical),
          ,
          drop = FALSE
        ]
        elo <- read.csv("data/processed/elo_ratings.csv", stringsAsFactors = FALSE)
        rolling <- if (file.exists("data/processed/rolling_form.csv")) read.csv("data/processed/rolling_form.csv", stringsAsFactors = FALSE) else NULL
        squad <- read.csv(transfermarkt_squad_strength_file, stringsAsFactors = FALSE)
        ability <- suppressWarnings(compute_goal_ability_features(training, matches))
        features <- build_forecast_feature_table(
          matches = training,
          elo_ratings = elo,
          rolling_form = rolling,
          squad_strength = squad,
          goal_ability = ability
        )
        assert_no_feature_leakage(features)
        output_path <- "data/processed/goal_training_features_hybrid.csv"
        write.csv(features, output_path, row.names = FALSE)
        output_path
      }
    },
    format = "file"
  ),
  tar_target(
    home_goal_model_hybrid,
    {
      if (is.na(hybrid_goal_training_features_file) || !file.exists(hybrid_goal_training_features_file)) {
        NA_character_
      } else {
        train_home_goal_model(
          feature_table_path = hybrid_goal_training_features_file,
          model_path = "models/home_goal_model_hybrid.rds",
          predictors = hybrid_goal_predictors(),
          model_version = "hybrid"
        )
      }
    }
  ),
  tar_target(
    away_goal_model_hybrid,
    {
      if (is.na(hybrid_goal_training_features_file) || !file.exists(hybrid_goal_training_features_file)) {
        NA_character_
      } else {
        train_away_goal_model(
          feature_table_path = hybrid_goal_training_features_file,
          model_path = "models/away_goal_model_hybrid.rds",
          predictors = hybrid_goal_predictors(),
          model_version = "hybrid"
        )
      }
    }
  ),
  tar_target(
    xg_feature_usage_audit_file,
    {
      if (
        is.na(hybrid_goal_training_features_file) ||
          !file.exists(hybrid_goal_training_features_file) ||
          !file.exists("models/home_goal_model_hybrid.rds") ||
          !file.exists("models/away_goal_model_hybrid.rds")
      ) {
        NA_character_
      } else {
        audit_xg_feature_usage(
          feature_table = hybrid_goal_training_features_file,
          home_model = "models/home_goal_model_hybrid.rds",
          away_model = "models/away_goal_model_hybrid.rds",
          rolling_form = "data/processed/rolling_form.csv",
          forecast_features = if (file.exists("data/processed/worldcup_2026_forecast_features_hybrid.csv")) {
            "data/processed/worldcup_2026_forecast_features_hybrid.csv"
          } else {
            NULL
          },
          output_path = "data/processed/xg_feature_usage_audit.csv"
        )
        "data/processed/xg_feature_usage_audit.csv"
      }
    },
    format = "file"
  ),
  tar_target(
    worldcup_forecast_features_file,
    {
      if (is.na(transfermarkt_squad_strength_file) || !file.exists(transfermarkt_squad_strength_file)) {
        NA_character_
      } else {
        groups <- load_worldcup_2026_groups()
        fixtures <- make_worldcup_group_fixtures(groups)
        matches <- read.csv("data/processed/elo_matches.csv", stringsAsFactors = FALSE)
        elo <- read.csv("data/processed/elo_ratings.csv", stringsAsFactors = FALSE)
        rolling <- if (file.exists("data/processed/rolling_form.csv")) read.csv("data/processed/rolling_form.csv", stringsAsFactors = FALSE) else NULL
        squad <- read.csv(transfermarkt_squad_strength_file, stringsAsFactors = FALSE)
        features <- build_worldcup_forecast_feature_table(
          groups = groups,
          fixtures = fixtures,
          history_matches = matches,
          elo_ratings = elo,
          rolling_form = rolling,
          squad_strength = squad,
          feature_cutoff_date = xgelo_feature_cutoff_date(),
          output_path = "data/processed/worldcup_2026_forecast_features_hybrid.csv"
        )
        assert_worldcup_forecast_features(
          features,
          fixtures = fixtures,
          teams = groups$team,
          predictors = hybrid_goal_predictors(),
          cutoff_date = xgelo_feature_cutoff_date()
        )
        "data/processed/worldcup_2026_forecast_features_hybrid.csv"
      }
    },
    format = "file"
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
    euro2024_benchmark,
    {
      elo_ratings_file
      rolling_form_file
      transfermarkt_squad_strength_file
      run_euro2024_benchmark(output_dir = "outputs/benchmarks/euro2024_transfermarkt_regularized")
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
      home_goal_model_hybrid
      away_goal_model_hybrid
      transfermarkt_value_audit_file
      xg_feature_usage_audit_file
      elo_ratings_file
      worldcup_forecast_features_file
      hybrid_available <- !is.na(worldcup_forecast_features_file) &&
        file.exists(worldcup_forecast_features_file) &&
        file.exists("models/home_goal_model_hybrid.rds") &&
        file.exists("models/away_goal_model_hybrid.rds")
      dashboard <- build_worldcup_dashboard(
        n_match_sim = 5000,
        n_tournaments = 5000,
        model_version = if (hybrid_available) "hybrid" else "baseline",
        feature_cutoff_date = xgelo_feature_cutoff_date(),
        require_forecast_features = hybrid_available,
        baseline_comparison = hybrid_available,
        home_model_path = if (hybrid_available) "models/home_goal_model_hybrid.rds" else "models/home_goal_model.rds",
        away_model_path = if (hybrid_available) "models/away_goal_model_hybrid.rds" else "models/away_goal_model.rds",
        forecast_features_path = if (hybrid_available) worldcup_forecast_features_file else NULL,
        baseline_home_model_path = "models/home_goal_model.rds",
        baseline_away_model_path = "models/away_goal_model.rds"
      )
      dashboard$paths$html
    },
    format = "file"
  ),
  tar_target(
    worldcup_pages_file,
    {
      worldcup_dashboard_file
      publish_worldcup_dashboard_pages()
    },
    format = "file"
  )
)
