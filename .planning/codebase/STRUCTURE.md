# Codebase Structure

**Analysis Date:** 2026-06-05

## Directory Layout

```text
xGelo/
├── _targets.R                     # targets pipeline definition and main DAG entry point
├── AGENTS.md                      # Codex/GSD project instructions
├── CLAUDE.md                      # Claude/GSD project instructions mirror
├── DATA-INVENTORY.md              # Data source catalog and usage rules
├── MODEL-CARD.md                  # Model architecture, metrics, and intended use
├── RUNBOOK.md                     # Manual operation guide for pipeline phases
├── SETUP.md                       # Setup instructions
├── open_data_elo_xg_wcq_research_memo.md # Domain research memo
├── R/                             # Layered R source scripts
│   ├── elo/                       # Elo preprocessing, runners, tuning, validation
│   ├── forecast/                  # Goal models, Monte Carlo, forecast output, calibration
│   ├── integration/               # xG/Elo feature integration and rolling form
│   ├── pipeline/                  # Validation and DAG visualization helpers
│   ├── visualization/             # AUC and calibration plot generation
│   └── xg/                        # xG feature engineering, training, calibration, backtest
├── data/                          # Raw and processed data artifacts
│   ├── cache/                     # Cache directory for local pipeline intermediates
│   ├── processed/                 # Cleaned/model-ready CSV and RDS artifacts
│   └── raw/                       # Source data snapshots and team mapping
├── models/                        # Persisted model RDS artifacts
├── notebooks/                     # Source R Markdown notebooks
├── outputs/                       # Forecasts, visualizations, reports, and notebook HTML
├── tests/                         # testthat tests
│   └── testthat/                  # Unit and integration test files
└── .planning/                     # GSD planning state and generated codebase maps
```

## Directory Purposes

**Root:**
- Purpose: Holds pipeline entry points, project documentation, and top-level artifacts.
- Contains: `_targets.R`, `RUNBOOK.md`, `MODEL-CARD.md`, `DATA-INVENTORY.md`, `SETUP.md`, `AGENTS.md`, `CLAUDE.md`, and generated `Rplots.pdf`.
- Key files: `_targets.R`, `RUNBOOK.md`, `MODEL-CARD.md`, `DATA-INVENTORY.md`.

**`R/`:**
- Purpose: Contains executable R source organized by forecasting pipeline layer.
- Contains: Subdirectories `R/xg/`, `R/elo/`, `R/integration/`, `R/forecast/`, `R/pipeline/`, and `R/visualization/`.
- Key files: `R/xg/model.R`, `R/elo/runner.R`, `R/integration/team_match_xg.R`, `R/forecast/monte_carlo.R`, `R/pipeline/validation.R`.
- Placement rule: Put new production R functions under the layer directory that owns their output artifact or model responsibility.

**`R/xg/`:**
- Purpose: Owns shot feature engineering and expected-goals modeling.
- Contains: `R/xg/features.R`, `R/xg/data_prep.R`, `R/xg/model.R`, `R/xg/calibration.R`, and `R/xg/backtest.R`.
- Key files: `R/xg/features.R` for StatsBomb shot features, `R/xg/model.R` for the tidymodels workflow, `R/xg/data_prep.R` for xG training/test datasets.

**`R/elo/`:**
- Purpose: Owns international results preprocessing, Elo computation, tuning, optimized variants, and validation.
- Contains: `R/elo/preprocess.R`, `R/elo/runner.R`, `R/elo/runner_optimized.R`, `R/elo/tuning.R`, and `R/elo/validation.R`.
- Key files: `R/elo/preprocess.R` for canonical team mapping and match preprocessing, `R/elo/runner.R` for core Elo update logic.

**`R/integration/`:**
- Purpose: Owns handoff features that combine xG and Elo outputs.
- Contains: `R/integration/team_match_xg.R` and `R/integration/rolling_form.R`.
- Key files: `R/integration/team_match_xg.R` writes `data/processed/team_match_xg.csv`; `R/integration/rolling_form.R` writes `data/processed/rolling_form.csv`.

**`R/forecast/`:**
- Purpose: Owns goal model training, Monte Carlo simulation, forecast output files, and forecast calibration.
- Contains: `R/forecast/poisson.R`, `R/forecast/monte_carlo.R`, `R/forecast/output.R`, and `R/forecast/calibration.R`.
- Key files: `R/forecast/poisson.R` writes `models/home_goal_model.rds` and `models/away_goal_model.rds`; `R/forecast/output.R` writes `outputs/forecasts/*.csv`.

**`R/pipeline/`:**
- Purpose: Owns pipeline-level validation and DAG visualization helpers.
- Contains: `R/pipeline/validation.R` and `R/pipeline/dag_visualization.R`.
- Key files: `R/pipeline/validation.R` provides `run_validation_checks()`; `R/pipeline/dag_visualization.R` provides `run_dag_visualization()` and Mermaid/DAG helpers.

**`R/visualization/`:**
- Purpose: Owns report-quality plot generation.
- Contains: `R/visualization/auc.R` and `R/visualization/calibration.R`.
- Key files: `R/visualization/auc.R` writes `outputs/visualizations/auc_comparison.png`; `R/visualization/calibration.R` writes calibration plots.

**`data/raw/`:**
- Purpose: Stores source data snapshots and internal mapping files.
- Contains: `data/raw/martj42/`, `data/raw/statsbomb/`, `data/raw/wcq_cache/`, and `data/raw/team_name_map.csv`.
- Key files: `data/raw/martj42/results.csv`, `data/raw/statsbomb/competitions.json`, `data/raw/statsbomb/events/*.json`, `data/raw/statsbomb/lineups/*.json`, `data/raw/team_name_map.csv`.

**`data/processed/`:**
- Purpose: Stores model-ready intermediate artifacts.
- Contains: CSV and RDS outputs from Elo, xG preparation, and integration layers.
- Key files: `data/processed/elo_matches.csv`, `data/processed/elo_ratings.csv`, `data/processed/elo_current.csv`, `data/processed/team_match_xg.csv`, `data/processed/rolling_form.csv`, `data/processed/xg_training_data.rds`, `data/processed/xg_train_data.rds`, and `data/processed/xg_test_data.rds`.

**`data/cache/`:**
- Purpose: Cache location referenced by `_targets.R` for raw martj42 and StatsBomb RDS files.
- Contains: No mapped files from the source listing.
- Key files: `_targets.R` writes `data/cache/martj42.rds` and `data/cache/statsbomb.rds`.

**`models/`:**
- Purpose: Stores trained model artifacts.
- Contains: RDS files loaded by integration and forecast functions.
- Key files: `models/xg_model.rds`, `models/home_goal_model.rds`, and `models/away_goal_model.rds`.

**`outputs/`:**
- Purpose: Stores user-facing generated artifacts.
- Contains: `outputs/forecasts/`, `outputs/model_performance/`, `outputs/visualizations/`, `outputs/notebooks/`, and `outputs/pipeline_dag.png`.
- Key files: `outputs/forecasts/Spain_vs_Italy_2026-06-10.csv`, `outputs/model_performance/xg_backtest.csv`, `outputs/model_performance/elo_validation.csv`, `outputs/visualizations/auc_comparison.png`, `outputs/visualizations/forecast_calibration.png`, `outputs/visualizations/xg_calibration.png`, and `outputs/notebooks/model_performance.html`.

**`notebooks/`:**
- Purpose: Stores source notebooks for reproducible reporting.
- Contains: `notebooks/model_performance.Rmd`.
- Key files: `notebooks/model_performance.Rmd` renders to `outputs/notebooks/model_performance.html`.

**`tests/testthat/`:**
- Purpose: Stores `testthat` checks for core functions and generated pipeline artifacts.
- Contains: `tests/testthat/test_xg_features.R`, `tests/testthat/test_elo.R`, and `tests/testthat/test_pipeline.R`.
- Key files: `tests/testthat/test_pipeline.R` asserts required files/directories and forecast probability contracts.

**`.planning/`:**
- Purpose: Stores GSD project state, roadmap, phase artifacts, research, and codebase maps.
- Contains: `.planning/PROJECT.md`, `.planning/ROADMAP.md`, `.planning/STATE.md`, `.planning/config.json`, `.planning/research/`, `.planning/phases/`, `.planning/milestones/`, and `.planning/codebase/`.
- Key files: `.planning/codebase/ARCHITECTURE.md` and `.planning/codebase/STRUCTURE.md`.

## Key File Locations

**Entry Points:**
- `_targets.R`: Main `targets` DAG definition for end-to-end pipeline execution.
- `RUNBOOK.md`: Manual commands for phase-by-phase execution, validation, visualization, and notebook rendering.
- `notebooks/model_performance.Rmd`: Reproducible reporting notebook.
- `tests/testthat/test_pipeline.R`: Pipeline artifact and forecast contract checks.

**Configuration:**
- `_targets.R`: Pipeline source loading, target dependency declarations, example forecast fixtures, and target output paths.
- `.planning/config.json`: GSD workflow configuration.
- `R/*/*.R`: Function-level defaults for input/output paths, seeds, model parameters, and output directories.
- `DATA-INVENTORY.md`: Source data usage rules and expected raw data files.

**Core Logic:**
- `R/xg/features.R`: StatsBomb coordinate constants, shot distance/angle calculations, and event feature extraction.
- `R/xg/model.R`: xG logistic regression workflow training and prediction.
- `R/elo/runner.R`: Elo expected result, update, decay, k-factor, and full rating computation.
- `R/elo/preprocess.R`: martj42 result normalization and FIFA code/team mapping.
- `R/integration/team_match_xg.R`: Match-level xG aggregation from event files and the xG model.
- `R/integration/rolling_form.R`: EWMA form metrics and Elo/xG integration.
- `R/forecast/poisson.R`: Negative Binomial/Poisson fallback goal model training.
- `R/forecast/monte_carlo.R`: Fixture simulation and probability generation.
- `R/forecast/output.R`: Forecast CSV formatting and batch output generation.

**Testing:**
- `tests/testthat/test_xg_features.R`: xG feature calculation checks.
- `tests/testthat/test_elo.R`: Elo calculation checks.
- `tests/testthat/test_pipeline.R`: End-to-end artifact, model, directory, and forecast probability checks.

**Generated Data and Models:**
- `data/processed/elo_matches.csv`: Preprocessed match results for Elo and goal models.
- `data/processed/elo_ratings.csv`: Elo rating history.
- `data/processed/team_match_xg.csv`: Match-level xG metrics.
- `data/processed/rolling_form.csv`: Team form features.
- `models/xg_model.rds`: xG model artifact.
- `models/home_goal_model.rds`: Home goal count model.
- `models/away_goal_model.rds`: Away goal count model.

**Generated Outputs:**
- `outputs/forecasts/*.csv`: Fixture-level forecast outputs.
- `outputs/visualizations/*.png`: AUC and calibration plots.
- `outputs/model_performance/*.csv`: Model validation/backtest summaries.
- `outputs/notebooks/model_performance.html`: Rendered report.
- `outputs/pipeline_dag.png`: Pipeline graph artifact.

## Naming Conventions

**Files:**
- Use snake_case for R source files: `R/integration/team_match_xg.R`, `R/forecast/monte_carlo.R`, `R/pipeline/dag_visualization.R`.
- Use `test_*.R` for tests under `tests/testthat/`: `tests/testthat/test_xg_features.R`.
- Use descriptive artifact names matching their content: `data/processed/rolling_form.csv`, `models/xg_model.rds`, `outputs/visualizations/forecast_calibration.png`.
- Use fixture names in forecast CSVs: `outputs/forecasts/Germany_vs_Netherlands_2026-06-11.csv`.

**Directories:**
- Use layer names under `R/`: `R/xg/`, `R/elo/`, `R/integration/`, `R/forecast/`, `R/pipeline/`, `R/visualization/`.
- Use data lifecycle directories under `data/`: `data/raw/`, `data/processed/`, `data/cache/`.
- Use output-type directories under `outputs/`: `outputs/forecasts/`, `outputs/visualizations/`, `outputs/model_performance/`, `outputs/notebooks/`.

## Where to Add New Code

**New Pipeline Target:**
- Primary code: Add the implementation function to the owning layer under `R/`.
- Orchestration: Add `source("R/<layer>/<file>.R")` and a `tar_target()` in `_targets.R`.
- Tests: Add or extend `tests/testthat/test_pipeline.R` for artifact contracts and add focused tests under `tests/testthat/test_<area>.R`.

**New Data Ingestion Function:**
- Primary code: Create `R/data_ingest/<source>.R` if restoring the ingestion layer referenced by `_targets.R`, or add source-specific preprocessing to `R/elo/preprocess.R` / `R/xg/data_prep.R` when the logic belongs to an existing model layer.
- Raw files: Store source snapshots under `data/raw/<source>/`.
- Processed files: Write cleaned outputs under `data/processed/`.
- Documentation: Update `DATA-INVENTORY.md` for source coverage and usage rules.

**New xG Feature or Model Variant:**
- Primary code: Add feature extraction to `R/xg/features.R`; add training/prediction changes to `R/xg/model.R`; add data preparation changes to `R/xg/data_prep.R`.
- Output artifacts: Write model outputs to `models/` and performance outputs to `outputs/model_performance/` or `outputs/visualizations/`.
- Tests: Add feature-level checks to `tests/testthat/test_xg_features.R`.

**New Elo Logic or Rating Variant:**
- Primary code: Add core calculations to `R/elo/runner.R`; add performance variants to `R/elo/runner_optimized.R`; add parameter search to `R/elo/tuning.R`; add validation to `R/elo/validation.R`.
- Output artifacts: Write rating tables under `data/processed/`.
- Tests: Add focused checks to `tests/testthat/test_elo.R`.

**New Integration Feature:**
- Primary code: Add match-level xG/Elo features to `R/integration/team_match_xg.R` or team-history features to `R/integration/rolling_form.R`.
- Output artifacts: Extend `data/processed/team_match_xg.csv` or `data/processed/rolling_form.csv`.
- Tests: Add schema checks to `tests/testthat/test_pipeline.R` and computation checks in a new `tests/testthat/test_integration.R`.

**New Forecasting Capability:**
- Primary code: Add goal model logic to `R/forecast/poisson.R`, simulation logic to `R/forecast/monte_carlo.R`, output formatting to `R/forecast/output.R`, or calibration logic to `R/forecast/calibration.R`.
- Output artifacts: Write models under `models/` and forecast CSVs under `outputs/forecasts/`.
- Tests: Extend `tests/testthat/test_pipeline.R` with probability and schema checks; add a focused `tests/testthat/test_forecast.R` for simulation behavior.

**New Visualization or Report:**
- Primary code: Add reusable plot functions to `R/visualization/`.
- Notebook source: Add reporting notebooks under `notebooks/`.
- Output artifacts: Write PNGs to `outputs/visualizations/` and rendered HTML to `outputs/notebooks/`.

**Utilities:**
- Shared helpers: Keep helpers inside the owning layer file until two or more layers need them.
- Cross-layer helper path: Add a new `R/utils/` directory only when a helper is used across multiple layer directories and cannot belong cleanly to `R/pipeline/`.

## Special Directories

**`data/raw/`:**
- Purpose: Source data snapshots and curated mapping data.
- Generated: Partly. External source files are downloaded or manually curated; `data/raw/team_name_map.csv` is internal curated data.
- Committed: Yes, mapped files are present in the repository listing.

**`data/processed/`:**
- Purpose: Pipeline intermediate artifacts consumed by later layers.
- Generated: Yes.
- Committed: Yes, mapped CSV/RDS files are present in the repository listing.

**`data/cache/`:**
- Purpose: Cache path referenced by `_targets.R` for raw data RDS files.
- Generated: Yes.
- Committed: No mapped files detected.

**`models/`:**
- Purpose: Trained model artifacts.
- Generated: Yes.
- Committed: Yes, mapped RDS files are present in the repository listing.

**`outputs/`:**
- Purpose: Forecasts, plots, validation summaries, rendered notebooks, and DAG images.
- Generated: Yes.
- Committed: Yes, mapped output files are present in the repository listing.

**`.planning/`:**
- Purpose: GSD workflow state, research, phase plans, milestone records, and codebase maps.
- Generated: Yes.
- Committed: Yes, mapped planning files are present in the repository listing.

**`_targets/`:**
- Purpose: `targets` runtime metadata and cache.
- Generated: Yes.
- Committed: Not detected in the mapped source listing.

**`R/data_ingest/`:**
- Purpose: Referenced ingestion layer for martj42, StatsBomb, and team name loading in `_targets.R` and `RUNBOOK.md`.
- Generated: No.
- Committed: Not detected. Add this directory before relying on the ingestion `source()` calls in `_targets.R`.

---

*Structure analysis: 2026-06-05*
