# Coding Conventions

**Analysis Date:** 2026-06-05

## Naming Patterns

**Files:**
- Use lowercase, domain-specific `.R` filenames inside layer directories: `R/xg/features.R`, `R/xg/model.R`, `R/elo/runner.R`, `R/integration/rolling_form.R`, `R/forecast/monte_carlo.R`.
- Use root-level orchestration for the targets pipeline only: `_targets.R`.
- Use `test_*.R` test filenames under `tests/testthat/`: `tests/testthat/test_xg_features.R`, `tests/testthat/test_elo.R`, `tests/testthat/test_pipeline.R`.
- Keep generated outputs outside `R/` and `tests/`: examples include `data/processed/elo_ratings.csv`, `models/xg_model.rds`, `outputs/forecasts/Spain_vs_Italy_2026-06-10.csv`.
- `test_len1.R` is a root-level scratch-style script for `compute_ewma_simple()` behavior; new durable tests belong in `tests/testthat/`.

**Functions:**
- Use snake_case for public functions: `calculate_distance()`, `extract_features_from_events()`, `train_xg_model()`, `compute_elo()`, `simulate_fixture()`.
- Use `run_*()` wrapper names for command-style functions that execute a full step with default paths: `run_goal_models()` in `R/forecast/poisson.R`, `run_monte_carlo()` in `R/forecast/monte_carlo.R`, `run_validation_checks()` in `R/pipeline/validation.R`.
- Use action-oriented prefixes that describe the analytical operation:
  - `calculate_*` for pure feature math in `R/xg/features.R`.
  - `compute_*` for derived metrics in `R/elo/runner.R`, `R/integration/rolling_form.R`, and `R/forecast/calibration.R`.
  - `train_*` for model fitting in `R/xg/model.R` and `R/forecast/poisson.R`.
  - `validate_*` for checks that return booleans in `R/pipeline/validation.R`.
  - `generate_*` for output artifact creation in `R/forecast/output.R` and `R/visualization/auc.R`.

**Variables:**
- Use snake_case for local variables and data frame columns: `required_cols`, `missing_cols`, `training_data`, `home_model_path`, `elo_diff`.
- Use domain abbreviations consistently where established: `xg`, `xGF`, `xGA`, `xGD`, `elo`, `auc`, `ewma`.
- Use `*_path` for file paths and `*_dir` for directories: `events_dir`, `competitions_file`, `output_path`, `model_path`.
- Use `n_*` for counts and sizes: `n_sim`, `n_sample`, `n_shots`, `n_use`.
- Use uppercase constants for fixed pitch geometry in `R/xg/features.R`: `PITCH_LENGTH`, `GOAL_CENTER_X`, `GOAL_POST_Y1`, `GOAL_WIDTH`.

**Types:**
- The codebase is script-oriented R, not an R package; no S3/R6 type system or package `DESCRIPTION`/`NAMESPACE` is detected.
- Model objects use package classes directly: tidymodels workflow objects in `R/xg/model.R`, `glm.nb` or `glm` objects in `R/forecast/poisson.R`.
- Data contracts are represented as required column vectors inside functions, for example `required_cols <- c("distance", "angle", "header", "open_play", "competition", "goal")` in `R/xg/model.R`.

## Code Style

**Formatting:**
- No `.lintr`, `.Rprofile`, `DESCRIPTION`, or styler configuration is detected.
- Use two-space indentation, spaces around assignment/operators, and braces on the same line as `if`, `else`, `for`, and function declarations, matching `R/xg/features.R` and `R/elo/runner.R`.
- Prefer `<-` for assignment. Use `=` for function arguments and data frame column initializers, as in `data.frame(..., stringsAsFactors = FALSE)`.
- Keep one exported function plus its roxygen block as the primary unit of organization. Multi-function files group related public helpers and a `run_*()` wrapper.
- Use explicit `return()` when a function has multiple branches or returns a structured object, matching `R/pipeline/validation.R`, `R/forecast/monte_carlo.R`, and `R/xg/model.R`.

**Linting:**
- Tool used: Not detected.
- Key rules: Not detected.
- Apply the local style manually: snake_case names, two-space indentation, roxygen blocks for exported functions, explicit path arguments with defaults, and clear `stop()` messages for invalid inputs.

## Import Organization

**Order:**
1. Root orchestration imports `targets` at the top of `_targets.R`.
2. Root orchestration sources implementation files immediately after package loading in `_targets.R`.
3. Implementation modules load package dependencies inside the function that needs them, for example `library(tidymodels)` in `R/xg/model.R`, `library(jsonlite)` and `library(dplyr)` in `R/xg/data_prep.R`, and `library(MASS)` plus `library(dplyr)` in `R/forecast/monte_carlo.R`.

**Path Aliases:**
- Not detected. Use project-root relative paths such as `R/xg/features.R`, `data/processed/elo_matches.csv`, `models/home_goal_model.rds`, and `outputs/forecasts`.

**Dependency Loading Pattern:**
- Use plain `library()` in analytical functions when startup messages are acceptable, as in `R/xg/model.R` and `R/xg/data_prep.R`.
- Use `suppressPackageStartupMessages({ library(...) })` in user-facing forecast functions that should print only model progress, as in `R/forecast/poisson.R` and `R/forecast/monte_carlo.R`.
- Keep source loading explicit. `_targets.R` lists each script path with `source("R/...")`.

## Error Handling

**Patterns:**
- Use `stop()` for invalid inputs, missing required columns, empty required data, missing model files, and unsupported arguments. Examples: `R/xg/model.R`, `R/elo/runner.R`, `R/xg/data_prep.R`, `R/forecast/monte_carlo.R`.
- Include the specific missing column names in schema errors with `setdiff()` and `paste(..., collapse = ", ")`, matching `R/xg/model.R` and `R/elo/runner.R`.
- Use `warning()` for recoverable data quality issues or fallback conditions, such as unmapped teams in `R/elo/preprocess.R`, missing optional Elo ratings in `R/integration/rolling_form.R`, and non-normalized probabilities in `R/forecast/monte_carlo.R`.
- Use `tryCatch()` around file parsing or fallback model fitting where processing can continue. Examples: JSON event processing in `R/xg/data_prep.R`, CSV schema reads in `R/pipeline/validation.R`, and negative-binomial to Poisson fallback in `R/forecast/poisson.R`.
- Validation helpers in `R/pipeline/validation.R` return `TRUE`/`FALSE` and emit `message()` diagnostics instead of stopping.

## Logging

**Framework:** console

**Patterns:**
- Use `message()` for progress that should be visible during pipeline runs: `R/elo/tuning.R`, `R/integration/team_match_xg.R`, `R/integration/rolling_form.R`, `R/forecast/output.R`.
- Use `cat()` for report-style console output and script summaries: `R/xg/model.R`, `R/xg/backtest.R`, `R/xg/calibration.R`, `R/pipeline/validation.R`.
- Do not introduce a new logging framework unless a future phase adds centralized logging across `_targets.R` and the `R/` modules.

## Comments

**When to Comment:**
- Use roxygen comments for exported functions, parameters, return values, and domain intent. Most implementation files under `R/` follow this pattern, including `R/xg/features.R`, `R/elo/runner.R`, and `R/forecast/monte_carlo.R`.
- Use short inline comments for domain formulas, non-obvious fallbacks, and data contracts. Examples include the law-of-cosines explanation in `R/xg/features.R`, home advantage adjustment in `R/elo/runner.R`, and placeholder Elo values in `R/forecast/monte_carlo.R`.
- Avoid comments that only restate assignment; comments should clarify football, modeling, pipeline, or data-shape intent.

**JSDoc/TSDoc:**
- Not applicable. Use roxygen2-style R comments with `#'`, `@param`, `@return`, `@description`, `@details`, `@examples`, and `@export`.

## Function Design

**Size:** Keep pure helpers short, like `calculate_distance()` and `calculate_angle()` in `R/xg/features.R`. Pipeline/data/model functions are longer and should be grouped by internal sections: validate input, load data, transform, fit/compute, save, return.

**Parameters:** Prefer explicit parameters with project-root relative defaults for paths and reproducibility controls:
- `model_path = "models/xg_model.rds"` in `R/xg/model.R`.
- `home_model_path = "models/home_goal_model.rds"` and `n_sim = 50000` in `R/forecast/monte_carlo.R`.
- `random_seed = 42` in `R/xg/data_prep.R`.

**Return Values:** Return structured objects that match the stage contract:
- Numeric vectors for feature helpers: `R/xg/features.R`.
- Data frames for prepared data, validation summaries, and metrics: `R/xg/data_prep.R`, `R/xg/backtest.R`, `R/pipeline/validation.R`.
- Lists for multi-artifact outputs and simulations: `R/elo/runner.R`, `R/forecast/monte_carlo.R`, `R/forecast/output.R`.
- File-writing wrappers should save artifacts and return the model, result list, plot object, or output path rather than only printing.

## Module Design

**Exports:** Use `@export` on public functions even though package metadata is not detected. This keeps files package-ready and documents the intended API surface.

**Barrel Files:** Not detected. Do not add barrel files; `_targets.R` is the explicit composition point through `source()`.

**Layer Boundaries:**
- Put xG feature extraction, model training, calibration, and backtesting in `R/xg/`.
- Put Elo computation, preprocessing, tuning, and validation in `R/elo/`.
- Put team-match and rolling-form combination logic in `R/integration/`.
- Put goal models, Monte Carlo simulation, forecast output, and forecast calibration in `R/forecast/`.
- Put pipeline validation and DAG visualization helpers in `R/pipeline/`.
- Put chart/report visualizations in `R/visualization/`.

---

*Convention analysis: 2026-06-05*
