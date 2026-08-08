# xGelo Pipeline Definition
# This file defines an executable targets pipeline for the xGelo forecasting system.

phase10_library <- file.path("data", "cache", "phase10-library")
phase11_library <- file.path("data", "cache", "phase11-library")
local_phase_libraries <- c(phase11_library, phase10_library)
local_phase_libraries <- local_phase_libraries[dir.exists(local_phase_libraries)]
if (length(local_phase_libraries)) {
  .libPaths(unique(c(normalizePath(local_phase_libraries), .libPaths())))
}

library(targets)

tar_option_set(
  packages = c(
    "dplyr",
    "jsonlite",
    "lubridate",
    "MASS",
    "Matrix",
    "glmnet",
    "ranger",
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
source("R/evaluation/proper_scores.R")
source("R/evaluation/worldcup_ledger.R")
source("R/evaluation/worldcup_retrospective.R")
source("R/visualization/worldcup_retrospective.R")
source("R/benchmark/registry.R")
source("R/benchmark/challenger_preflight.R")
source("R/benchmark/cutoffs.R")
source("R/benchmark/weights.R")
source("R/benchmark/contracts.R")
source("R/benchmark/baselines.R")
source("R/forecast/tournament_formats.R")
source("R/evaluation/benchmark_scores.R")
source("R/evaluation/promotion.R")
source("R/benchmark/runner.R")
source("R/benchmark/challenger_protocol.R")
source("R/forecast/penalized_poisson.R")
source("R/forecast/dynamic_goal_ability.R")
source("R/forecast/score_dependence.R")
source("R/benchmark/challengers.R")
source("R/evaluation/challenger_selection.R")
source("R/benchmark/challenger_runner.R")

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
    espn_scoreboard_files,
    download_espn_scoreboard_files()
  ),
  tar_target(
    elo_matches,
    {
      eloratings_fallback_files
      espn_scoreboard_files
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
        training$match_id <- make.unique(as.character(training$match_id), sep = "__")
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
        validate_forecast_feature_evidence(
          features,
          read.csv("data/benchmark/phase09/feature_contract.csv", stringsAsFactors = FALSE),
          derived_mappings = c(
            elo_difference_for_team = "elo_diff",
            venue_advantage_for_team = "elo_diff"
          )
        )
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
  ),
  tar_target(
    benchmark_phase09_registry_files,
    file.path("data/benchmark/phase09", c(
      "tournaments.csv", "fixtures.csv", "teams.csv", "formats.csv",
      "route_rules.csv", "corrections.csv", "boundaries.csv", "panels.csv",
      "panel_fixtures.csv", "model_registry.csv", "score_support_audit.csv",
      "feature_contract.csv", "seed_registry.csv", "promotion_protocol.json"
    )),
    format = "file"
  ),
  tar_target(
    benchmark_phase09_registries,
    {
      benchmark_phase09_registry_files
      registry_dir <- "data/benchmark/phase09"
      registries <- load_benchmark_registries(registry_dir)
      inputs <- benchmark_runner_load_inputs(registry_dir)
      protocol <- load_promotion_protocol(file.path(registry_dir, "promotion_protocol.json"))
      validate_promotion_protocol(protocol, registry_dir = registry_dir)
      list(registries = registries, inputs = inputs, protocol = protocol)
    }
  ),
  tar_target(
    benchmark_phase09_boundaries,
    {
      context <- benchmark_phase09_registries
      inventory <- benchmark_runner_boundary_inventory(context$registries$boundaries)
      validate_score_support_audit(
        context$inputs$score_support_audit,
        context$inputs$model_registry,
        inventory
      )
      list(context = context, boundary_inventory = inventory)
    }
  ),
  tar_target(
    benchmark_phase09_predictions,
    {
      execution <- benchmark_phase09_boundaries
      score_support_audit <- execution$context$inputs$score_support_audit
      selected_g <- unique(as.integer(score_support_audit$selected_g))
      feature_input <- hybrid_goal_training_features_file
      if (length(feature_input) != 1L || is.na(feature_input) || !file.exists(feature_input)) {
        stop("Phase 9 benchmark requires the canonical hybrid goal training feature file")
      }
      history <- read.csv(feature_input, stringsAsFactors = FALSE)
      validate_forecast_feature_evidence(
        history,
        execution$context$inputs$feature_contract,
        derived_mappings = c(
          elo_difference_for_team = "elo_diff",
          venue_advantage_for_team = "elo_diff"
        )
      )
      date_column <- if ("date" %in% names(history)) "date" else "actual_completion_date"
      history <- history[
        as.Date(history[[date_column]]) <= max(as.Date(execution$context$registries$fixtures$actual_completion_date)),
        , drop = FALSE
      ]
      guard_benchmark_purpose(history, "baseline_reproduction")
      bundle <- benchmark_default_execution_engine(
        history = history,
        registries = execution$context$registries,
        inputs = execution$context$inputs,
        boundary_inventory = execution$boundary_inventory,
        protocol = execution$context$protocol,
        run_id = "phase09-baselines-frozen",
        purpose = "baseline_reproduction",
        branch_order = execution$context$inputs$model_registry$model_id,
        selected_g = selected_g
      )
      additional_inputs <- benchmark_runner_additional_input_specs(
        "data/benchmark/phase09", feature_input
      )
      list(
        bundle = bundle, execution = execution,
        score_support_audit = score_support_audit,
        additional_inputs = additional_inputs
      )
    }
  ),
  tar_target(
    benchmark_phase09_stage_probabilities,
    {
      benchmark_phase09_predictions$bundle$feature_coverage
      benchmark_phase09_predictions$bundle$stage_probabilities
    }
  ),
  tar_target(
    benchmark_phase09_scores,
    {
      benchmark_phase09_predictions$bundle$fixture_predictions
      benchmark_phase09_predictions$bundle$score_distributions
      list(
        fixture_scores = benchmark_phase09_predictions$bundle$fixture_scores,
        benchmark_summaries = benchmark_phase09_predictions$bundle$benchmark_summaries
      )
    }
  ),
  tar_target(
    benchmark_phase09_comparisons,
    {
      benchmark_phase09_scores
      feature_coverage <- benchmark_phase09_predictions$bundle$feature_coverage
      list(
        paired_comparisons = benchmark_phase09_predictions$bundle$paired_comparisons,
        promotion_decisions = benchmark_phase09_predictions$bundle$promotion_decisions,
        feature_coverage = feature_coverage
      )
    }
  ),
  tar_target(
    benchmark_phase09_bundle_files,
    {
      benchmark_phase09_stage_probabilities
      benchmark_phase09_scores
      benchmark_phase09_comparisons
      execution <- benchmark_phase09_predictions$execution
      result <- write_rolling_benchmark_bundle(
        benchmark_phase09_predictions$bundle,
        "outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen",
        execution$context$inputs$score_support_audit,
        execution$context$inputs$model_registry,
        execution$boundary_inventory,
        additional_inputs = benchmark_phase09_predictions$additional_inputs,
        panel_fixtures = execution$context$inputs$panel_fixtures,
        feature_contract = execution$context$inputs$feature_contract
      )
      unname(result$paths)
    },
    format = "file"
  ),
  tar_target(
    benchmark_phase10_registry_files,
    c(
      file.path("data/benchmark/phase10", c(
        "model_registry.csv", "feature_contract.csv", "tuning_editions.csv",
        "tuning_grid.csv", "ablation_registry.csv", "selection_protocol.json",
        "storage_preflight.csv", "glmnet_provenance.csv"
      )),
      file.path("data/benchmark/phase09", c(
        "tournaments.csv", "fixtures.csv", "teams.csv", "formats.csv",
        "route_rules.csv", "corrections.csv", "boundaries.csv", "panels.csv",
        "panel_fixtures.csv", "model_registry.csv", "score_support_audit.csv",
        "feature_contract.csv", "seed_registry.csv"
      )),
      file.path(
        "outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen",
        c(
          "run_manifest.csv", "manifests/checksum_manifest.csv",
          "scores/fixture_scores.csv"
        )
      ),
      "data/processed/goal_training_features_hybrid.csv"
    ),
    format = "file"
  ),
  tar_target(
    benchmark_phase10_registries,
    {
      benchmark_phase10_registry_files
      phase09_dir <- "data/benchmark/phase09"
      phase10_dir <- "data/benchmark/phase10"
      environment <- require_challenger_environment(
        file.path(phase10_dir, "glmnet_provenance.csv")
      )
      protocol <- load_and_validate_challenger_protocol(phase10_dir)
      phase09_registries <- load_benchmark_registries(phase09_dir)
      phase09_inputs <- benchmark_runner_load_inputs(phase09_dir)
      parent <- load_phase09_parent_bundle(
        "outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen"
      )
      feature_input <- "data/processed/goal_training_features_hybrid.csv"
      feature_input_sha256 <- benchmark_runner_file_sha256(feature_input)
      list(
        environment = environment, protocol = protocol,
        phase09_registries = phase09_registries, phase09_inputs = phase09_inputs,
        parent = parent, feature_input = feature_input,
        feature_input_sha256 = feature_input_sha256
      )
    }
  ),
  tar_target(
    benchmark_phase10_predictions,
    {
      context <- benchmark_phase10_registries
      history <- read.csv(context$feature_input, stringsAsFactors = FALSE)
      validate_forecast_feature_evidence(
        history, context$phase09_inputs$feature_contract,
        derived_mappings = c(
          elo_difference_for_team = "elo_diff",
          venue_advantage_for_team = "elo_diff"
        )
      )
      history <- .phase10_runner_prepare_history(history, context$protocol)
      date_column <- if ("date" %in% names(history)) "date" else "actual_completion_date"
      history <- history[
        as.Date(history[[date_column]]) <= max(as.Date(
          context$phase09_registries$fixtures$actual_completion_date
        )),
        , drop = FALSE
      ]
      guard_benchmark_purpose(history, "candidate_selection")
      tracks <- lapply(c("frozen", "updating"), function(track_id) {
        benchmark_runner_track_fixtures(
          context$phase09_registries$fixtures,
          context$phase09_registries$tournaments,
          context$phase09_registries$boundaries,
          context$phase09_registries$teams,
          history, track_id, context$phase09_inputs$feature_contract
        )
      })
      fixtures <- do.call(rbind, tracks)
      run_statistical_challenger_benchmark(
        history = history, fixtures = fixtures,
        seed_registry = context$phase09_inputs$seed_registry,
        synthetic = FALSE, publish = FALSE
      )
    }
  ),
  tar_target(
    benchmark_phase10_scores,
    {
      benchmark_phase10_predictions$fixture_predictions
      benchmark_phase10_predictions$score_distributions
      list(
        fixture_scores = benchmark_phase10_predictions$fixture_scores,
        benchmark_summaries = benchmark_phase10_predictions$benchmark_summaries
      )
    }
  ),
  tar_target(
    benchmark_phase10_comparisons,
    {
      benchmark_phase10_scores
      list(
        all_baseline_paired_comparisons =
          benchmark_phase10_predictions$all_baseline_paired_comparisons,
        shortlist = benchmark_phase10_predictions$shortlist
      )
    }
  ),
  tar_target(
    benchmark_phase10_bundle_files,
    {
      benchmark_phase10_comparisons
      write_statistical_challenger_bundle(
        benchmark_phase10_predictions,
        "outputs/benchmarks/rolling_tournaments/phase10-statistical-challengers"
      )
      unname(phase10_output_paths(
        "outputs/benchmarks/rolling_tournaments/phase10-statistical-challengers"
      ))
    },
    format = "file"
  ),
  tar_target(
    worldcup_retrospective_ledger_bundle,
    write_forecast_ledger_bundle(
      source_ref = "HEAD",
      output_dir = "outputs/evaluation/wc2026"
    )
  ),
  tar_target(
    worldcup_retrospective_score_files,
    {
      bundle <- worldcup_retrospective_ledger_bundle
      output_dir <- "outputs/evaluation/wc2026"
      distributions <- readRDS(file.path(output_dir, "selected_distributions.rds"))
      scores <- score_worldcup_matches(bundle$selected, distributions$scorelines)
      aggregates <- aggregate_worldcup_scores(scores)
      calibration <- make_calibration_bins(bundle$selected)
      advancement <- score_knockout_advancement(bundle$selected)
      anchors <- select_stage_reach_anchors(bundle$selected, distributions$stage, bundle$fixtures)
      stages <- score_stage_reach(anchors, distributions$stage, bundle$fixtures)
      write_worldcup_score_bundle(scores, aggregates, calibration, advancement, stages, output_dir)
      file.path(output_dir, c(
        "match_scores.csv", "aggregate_scores.csv", "calibration_bins.csv",
        "advancement_scores.csv", "stage_reach_scores.csv", "score_manifest.csv"
      ))
    },
    format = "file"
  ),
  tar_target(
    worldcup_retrospective_figure_files,
    {
      worldcup_retrospective_score_files
      generate_worldcup_retrospective_figures("outputs/evaluation/wc2026")
    },
    format = "file"
  ),
  tar_target(
    worldcup_retrospective_report_file,
    {
      worldcup_retrospective_figure_files
      output_dir <- normalizePath("outputs/evaluation/wc2026")
      output_path <- file.path(output_dir, "worldcup_2026_retrospective.html")
      rmarkdown::render(
        "notebooks/worldcup_2026_retrospective.Rmd",
        output_file = basename(output_path), output_dir = dirname(output_path),
        params = list(output_dir = output_dir),
        envir = new.env(parent = globalenv()), quiet = TRUE
      )
      output_path
    },
    format = "file"
  )
)
