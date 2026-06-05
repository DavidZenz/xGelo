# Architecture

**Analysis Date:** 2026-06-05

## Pattern Overview

**Overall:** File-based analytical pipeline with layered R scripts, `targets` orchestration, and persisted CSV/RDS artifacts as contracts between stages.

**Key Characteristics:**
- Top-level orchestration lives in `_targets.R`; manual execution paths are documented in `RUNBOOK.md`.
- Domain modules are grouped by pipeline layer under `R/xg/`, `R/elo/`, `R/integration/`, `R/forecast/`, `R/pipeline/`, and `R/visualization/`.
- Data contracts are materialized on disk under `data/raw/`, `data/processed/`, `models/`, and `outputs/`.
- Modules use direct `source()` loading and exported functions in scripts rather than an R package namespace.
- Layer handoffs are explicit files such as `models/xg_model.rds`, `data/processed/elo_ratings.csv`, `data/processed/team_match_xg.csv`, `data/processed/rolling_form.csv`, and `outputs/forecasts/*.csv`.

## Layers

**Pipeline Orchestration:**
- Purpose: Defines the end-to-end DAG and target dependencies for raw data, cleaned data, models, integration metrics, forecasts, reports, and DAG visualization.
- Location: `_targets.R`
- Contains: `targets::tar_target()` declarations and `source()` statements for layer scripts.
- Depends on: `targets`, script files under `R/`, raw data under `data/raw/`, generated artifacts under `data/processed/` and `models/`.
- Used by: `targets::tar_make()` runs from R sessions and the runbook workflow in `RUNBOOK.md`.
- Important constraint: `_targets.R` references `R/data_ingest/martj42.R`, `R/data_ingest/statsbomb.R`, and `R/data_ingest/team_names.R`; no `R/data_ingest/` directory is present in the repository. Implemented data preparation is in `R/elo/preprocess.R` and `R/xg/data_prep.R`.

**Raw Data Layer:**
- Purpose: Stores downloaded or curated source data before model-specific processing.
- Location: `data/raw/`
- Contains: `data/raw/martj42/results.csv`, `data/raw/martj42/goalscorers.csv`, `data/raw/martj42/shootouts.csv`, `data/raw/statsbomb/competitions.json`, `data/raw/statsbomb/events/*.json`, `data/raw/statsbomb/lineups/*.json`, and `data/raw/team_name_map.csv`.
- Depends on: External open data sources documented in `DATA-INVENTORY.md`.
- Used by: `R/elo/preprocess.R`, `R/elo/runner.R`, `R/xg/data_prep.R`, `R/integration/team_match_xg.R`, `notebooks/model_performance.Rmd`, and validation checks in `R/pipeline/validation.R`.

**Data Preparation Layer:**
- Purpose: Converts raw data into model-ready tables and validates source schemas.
- Location: `R/elo/preprocess.R`, `R/xg/data_prep.R`
- Contains: `preprocess_martj42()`, `preprocess_and_save_elo_matches()`, `prepare_training_data()`, `split_training_data()`, and `prepare_and_split_data()`.
- Depends on: `data/raw/martj42/results.csv`, `data/raw/team_name_map.csv`, `data/raw/statsbomb/events/`, and `data/raw/statsbomb/competitions.json`.
- Used by: Elo rating computation, xG model training, tests in `tests/testthat/test_pipeline.R`, and notebook sections in `notebooks/model_performance.Rmd`.
- Output contracts: `data/processed/elo_matches.csv`, `data/processed/xg_training_data.rds`, `data/processed/xg_train_data.rds`, and `data/processed/xg_test_data.rds`.

**xG Modeling Layer:**
- Purpose: Extracts shot features, trains the expected-goals model, predicts shot scoring probabilities, calibrates, and backtests model performance.
- Location: `R/xg/`
- Contains: `R/xg/features.R`, `R/xg/data_prep.R`, `R/xg/model.R`, `R/xg/calibration.R`, and `R/xg/backtest.R`.
- Depends on: StatsBomb event data in `data/raw/statsbomb/events/`, competition metadata in `data/raw/statsbomb/competitions.json`, and `tidymodels`.
- Used by: Integration xG aggregation in `R/integration/team_match_xg.R`, visual reports in `R/visualization/calibration.R`, and notebook reporting in `notebooks/model_performance.Rmd`.
- Output contracts: `models/xg_model.rds`, `models/xg_calibration.rds`, `outputs/model_performance/xg_backtest.csv`, `outputs/model_performance/xg_roc_curve.png`, and `outputs/visualizations/xg_calibration.png`.

**Elo Rating Layer:**
- Purpose: Computes custom international football Elo ratings with home advantage, match-frequency k-factors, and rating decay.
- Location: `R/elo/`
- Contains: `R/elo/runner.R`, `R/elo/runner_optimized.R`, `R/elo/preprocess.R`, `R/elo/tuning.R`, and `R/elo/validation.R`.
- Depends on: `data/raw/martj42/results.csv`, `data/raw/team_name_map.csv`, `dplyr`, `lubridate`, and `stringr`.
- Used by: Form integration in `R/integration/rolling_form.R`, forecast goal models in `R/forecast/poisson.R`, model reporting in `MODEL-CARD.md`, and tests in `tests/testthat/test_elo.R`.
- Output contracts: `data/processed/elo_matches.csv`, `data/processed/elo_ratings.csv`, `data/processed/elo_current.csv`, and `outputs/model_performance/elo_validation.csv`.

**Integration Layer:**
- Purpose: Combines xG outputs and Elo ratings into team-match and rolling form features.
- Location: `R/integration/`
- Contains: `R/integration/team_match_xg.R` and `R/integration/rolling_form.R`.
- Depends on: `models/xg_model.rds`, `data/raw/statsbomb/events/`, `data/raw/statsbomb/competitions.json`, and `data/processed/elo_ratings.csv`.
- Used by: Forecast model training in `R/forecast/poisson.R`, validation in `R/pipeline/validation.R`, and reporting in `notebooks/model_performance.Rmd`.
- Output contracts: `data/processed/team_match_xg.csv` and `data/processed/rolling_form.csv`.

**Forecasting Layer:**
- Purpose: Trains goal count models, simulates fixtures, and writes user-facing forecast probabilities.
- Location: `R/forecast/`
- Contains: `R/forecast/poisson.R`, `R/forecast/monte_carlo.R`, `R/forecast/output.R`, and `R/forecast/calibration.R`.
- Depends on: `data/processed/elo_matches.csv`, `data/processed/elo_ratings.csv`, `models/home_goal_model.rds`, `models/away_goal_model.rds`, `MASS`, and `dplyr`.
- Used by: Forecast output generation in `R/forecast/output.R`, validation in `R/pipeline/validation.R`, calibration visuals in `R/visualization/calibration.R`, and notebook reporting in `notebooks/model_performance.Rmd`.
- Output contracts: `models/home_goal_model.rds`, `models/away_goal_model.rds`, and `outputs/forecasts/*.csv`.

**Validation and Visualization Layer:**
- Purpose: Validates artifact existence/schemas, produces DAG and model performance visualizations, and supports notebook rendering.
- Location: `R/pipeline/`, `R/visualization/`, `notebooks/`
- Contains: `R/pipeline/validation.R`, `R/pipeline/dag_visualization.R`, `R/visualization/auc.R`, `R/visualization/calibration.R`, and `notebooks/model_performance.Rmd`.
- Depends on: Generated data/model/forecast artifacts and visualization packages such as `ggplot2`.
- Used by: `RUNBOOK.md`, `_targets.R`, `tests/testthat/test_pipeline.R`, and output documentation.
- Output contracts: `outputs/pipeline_dag.png`, `outputs/visualizations/auc_comparison.png`, `outputs/visualizations/xg_calibration.png`, `outputs/visualizations/forecast_calibration.png`, and `outputs/notebooks/model_performance.html`.

## Data Flow

**End-to-End Forecast Flow:**

1. Raw international results are stored in `data/raw/martj42/results.csv`, with team normalization in `data/raw/team_name_map.csv`.
2. Raw StatsBomb event data is stored in `data/raw/statsbomb/events/*.json`, with metadata in `data/raw/statsbomb/competitions.json`.
3. Elo preprocessing in `R/elo/preprocess.R` produces `data/processed/elo_matches.csv`.
4. Elo computation in `R/elo/runner.R` produces rating history/current ratings in `data/processed/elo_ratings.csv` and `data/processed/elo_current.csv`.
5. xG preparation in `R/xg/data_prep.R` and feature extraction in `R/xg/features.R` produce model-ready RDS files under `data/processed/`.
6. xG model training in `R/xg/model.R` writes `models/xg_model.rds`.
7. Team-match xG aggregation in `R/integration/team_match_xg.R` reads StatsBomb events and `models/xg_model.rds`, then writes `data/processed/team_match_xg.csv`.
8. Rolling form computation in `R/integration/rolling_form.R` reads `data/processed/team_match_xg.csv` and `data/processed/elo_ratings.csv`, then writes `data/processed/rolling_form.csv`.
9. Goal model training in `R/forecast/poisson.R` reads `data/processed/elo_matches.csv` and `data/processed/elo_ratings.csv`, then writes `models/home_goal_model.rds` and `models/away_goal_model.rds`.
10. Monte Carlo simulation in `R/forecast/monte_carlo.R` reads goal model RDS files and returns win/draw/loss probabilities.
11. Forecast output generation in `R/forecast/output.R` writes fixture-level CSVs under `outputs/forecasts/`.
12. Validation and reporting in `R/pipeline/validation.R`, `R/visualization/`, and `notebooks/model_performance.Rmd` read generated artifacts and write reports/plots under `outputs/`.

**State Management:**
- Persistent state is file-based: CSV artifacts live in `data/processed/`, RDS model artifacts live in `models/`, and report artifacts live in `outputs/`.
- Runtime state is local to functions; modules do not define shared mutable service objects.
- Randomness is controlled inside specific functions, such as `split_training_data(..., random_seed = 42)` in `R/xg/data_prep.R` and `simulate_fixture(..., seed = NULL)` in `R/forecast/monte_carlo.R`.
- `targets` state is expected under `_targets/`, which is excluded from the mapped source tree and not present in the file listing.

## Key Abstractions

**Targets DAG:**
- Purpose: Represents pipeline execution order and rebuild dependencies.
- Examples: `_targets.R`
- Pattern: `tar_target()` declarations with file-producing commands and explicit `depends` fields.

**Raw Data Contracts:**
- Purpose: Stable local copies of external source data.
- Examples: `data/raw/martj42/results.csv`, `data/raw/statsbomb/events/15946.json`, `data/raw/statsbomb/competitions.json`, `data/raw/team_name_map.csv`
- Pattern: Source data files are read directly by layer functions using default path arguments.

**Processed Data Contracts:**
- Purpose: Handoff tables between model layers.
- Examples: `data/processed/elo_matches.csv`, `data/processed/elo_ratings.csv`, `data/processed/team_match_xg.csv`, `data/processed/rolling_form.csv`
- Pattern: Functions write CSV outputs and downstream layers read those exact default paths.

**Model Artifacts:**
- Purpose: Persist trained models for integration and forecasting.
- Examples: `models/xg_model.rds`, `models/home_goal_model.rds`, `models/away_goal_model.rds`
- Pattern: Training functions save RDS artifacts; prediction/simulation functions load them by default path.

**xG Feature Contract:**
- Purpose: Defines model-ready shot features.
- Examples: `R/xg/features.R`, `R/xg/data_prep.R`, `R/xg/model.R`
- Pattern: Use `distance`, `angle`, `header`, `open_play`, `competition`, and `goal` columns for training; use all except `goal` for prediction.

**Elo Rating Contract:**
- Purpose: Defines team strength history for downstream models.
- Examples: `R/elo/runner.R`, `R/elo/preprocess.R`, `data/processed/elo_ratings.csv`
- Pattern: Ratings are keyed by `date`, `team`, `fifa_code`, `rating`, `match_id`, and `is_post_match`.

**Forecast Contract:**
- Purpose: User-facing match prediction output.
- Examples: `R/forecast/output.R`, `outputs/forecasts/Spain_vs_Italy_2026-06-10.csv`
- Pattern: Each forecast CSV includes teams, fixture date, expected goals, win/draw/loss probabilities, model version, and timestamp.

**Manual Runner Functions:**
- Purpose: Give each layer a script-friendly entry point outside `targets`.
- Examples: `run_team_match_xg()` in `R/integration/team_match_xg.R`, `run_rolling_form()` in `R/integration/rolling_form.R`, `run_goal_models()` in `R/forecast/poisson.R`, `run_output_generation()` in `R/forecast/output.R`, `run_validation_checks()` in `R/pipeline/validation.R`
- Pattern: `run_*()` wrappers call the main computation function with default paths and return results invisibly or directly.

## Entry Points

**Targets Pipeline:**
- Location: `_targets.R`
- Triggers: `targets::tar_make()` from an R session.
- Responsibilities: Loads layer scripts, declares pipeline targets, coordinates dependencies, writes data/model/output artifacts.

**Manual Runbook:**
- Location: `RUNBOOK.md`
- Triggers: Developer runs sourced R functions interactively or via `Rscript`.
- Responsibilities: Documents manual phase execution, forecast generation, validation, visualization, and notebook rendering commands.

**Model Performance Notebook:**
- Location: `notebooks/model_performance.Rmd`
- Triggers: `rmarkdown::render("notebooks/model_performance.Rmd", output_dir = "outputs/notebooks")`.
- Responsibilities: Loads existing artifacts, summarizes pipeline behavior, reports model metrics, and renders `outputs/notebooks/model_performance.html`.

**Tests:**
- Location: `tests/testthat/`
- Triggers: `testthat::test_dir("tests/testthat")`.
- Responsibilities: Checks existence of critical files/directories, validates forecast probability columns, and exercises selected xG/Elo functions.

**Validation Checks:**
- Location: `R/pipeline/validation.R`
- Triggers: `run_validation_checks()` or `_targets.R` report target.
- Responsibilities: Verifies raw data, processed data, model files, forecast probability sums, and visualization outputs.

**Visualization Runners:**
- Location: `R/visualization/auc.R`, `R/visualization/calibration.R`, `R/pipeline/dag_visualization.R`
- Triggers: `run_auc_chart()`, `run_calibration_plots()`, and `run_dag_visualization()`.
- Responsibilities: Generate model performance, calibration, and pipeline graph artifacts under `outputs/`.

## Error Handling

**Strategy:** Fail fast for missing required inputs, return `FALSE` for validation failures, and warn/continue for recoverable per-file data issues.

**Patterns:**
- Use `stop()` when required paths or columns are missing, as in `R/xg/model.R`, `R/xg/data_prep.R`, `R/elo/runner.R`, `R/integration/team_match_xg.R`, and `R/forecast/monte_carlo.R`.
- Use `warning()` and continue when individual event files or optional data are invalid, as in `R/xg/data_prep.R` and `R/integration/rolling_form.R`.
- Use `tryCatch()` around per-file JSON processing and model fallback paths, as in `R/xg/data_prep.R` and `R/forecast/poisson.R`.
- Use boolean validation returns and printed diagnostics in `R/pipeline/validation.R`.

## Cross-Cutting Concerns

**Logging:** `message()` and `cat()` are used directly in scripts such as `R/elo/preprocess.R`, `R/xg/data_prep.R`, `R/integration/team_match_xg.R`, `R/forecast/output.R`, and `R/pipeline/validation.R`.

**Validation:** Input validation is implemented inside computation functions; artifact-level validation is centralized in `R/pipeline/validation.R`; test-level validation lives in `tests/testthat/test_pipeline.R`.

**Authentication:** Not applicable. The mapped code reads local open-data files and generated artifacts. No credential or auth integration is present in the source tree.

**Configuration:** Function defaults encode file paths and model parameters. Pipeline configuration is split between `_targets.R`, function arguments in `R/*/*.R`, and workflow metadata in `.planning/config.json`.

**Reproducibility:** File-based artifacts, `targets` orchestration, explicit output paths, and deterministic seeds in selected functions support reproducible reruns. Add new randomness behind explicit `seed` or `random_seed` arguments.

---

*Architecture analysis: 2026-06-05*
