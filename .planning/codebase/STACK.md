# Technology Stack

**Analysis Date:** 2026-06-05

## Languages

**Primary:**
- R 4.6.0 observed locally - all source code and orchestration in `R/`, `_targets.R`, `tests/testthat/`, and `notebooks/model_performance.Rmd`

**Secondary:**
- Markdown/R Markdown - project docs in `SETUP.md`, `RUNBOOK.md`, `MODEL-CARD.md`, `DATA-INVENTORY.md`, and executable reporting in `notebooks/model_performance.Rmd`
- CSV/JSON/RDS - data and model artifact formats under `data/`, `models/`, and `outputs/`

## Runtime

**Environment:**
- R runtime. `SETUP.md` specifies R >= 4.3.0 with R 4.4.0 or later recommended; the inspected local runtime is R 4.6.0.
- Working directory is expected to be the project root `/Users/davidzenz/R/xGelo`; paths in `_targets.R` and `R/*.R` are project-relative.

**Package Manager:**
- Base R `install.packages()` is the active dependency installation path in `SETUP.md`.
- `renv` is documented as optional in `SETUP.md`, but no `renv.lock` is present.
- Lockfile: missing.
- Package manifest: no `DESCRIPTION` file is present, so this is a script-oriented R project rather than an installable R package.

## Frameworks

**Core:**
- `targets` 1.12.0 observed locally - pipeline orchestration in `_targets.R`
- `tidymodels` 1.5.0 observed locally - xG modeling workflows in `R/xg/model.R`, `R/xg/calibration.R`, `R/xg/backtest.R`, and `R/integration/team_match_xg.R`
- `tidyverse` 2.0.0 observed locally - notebook analysis in `notebooks/model_performance.Rmd`
- `dplyr` 1.2.1 observed locally - data transformation across `R/elo/preprocess.R`, `R/integration/rolling_form.R`, `R/forecast/poisson.R`, `R/forecast/output.R`, and visualization scripts

**Testing:**
- `testthat` 3.3.2 observed locally - tests in `tests/testthat/test_xg_features.R`, `tests/testthat/test_elo.R`, and `tests/testthat/test_pipeline.R`

**Build/Dev:**
- `rmarkdown` 2.31 observed locally - report rendering for `notebooks/model_performance.Rmd` into `outputs/notebooks/`
- `knitr` 1.51 observed locally - notebook chunk execution configured in `notebooks/model_performance.Rmd`
- `ggplot2` 4.0.3 observed locally - visualization output in `R/visualization/auc.R`, `R/visualization/calibration.R`, `R/xg/calibration.R`, and `R/forecast/calibration.R`
- `igraph` 2.3.1 observed locally - DAG visualization support in `R/pipeline/dag_visualization.R`
- `visNetwork` is declared in `SETUP.md` and `_targets.R`, but is not installed in the inspected local R library.
- `devtools` 2.5.2 and `roxygen2` 8.0.0 are listed in `SETUP.md`; roxygen-style comments are used in `R/**/*.R`, but no package `DESCRIPTION`/`NAMESPACE` is present.

## Key Dependencies

**Critical:**
- `targets` - defines the analytical pipeline in `_targets.R`; the pipeline writes caches, processed data, models, forecasts, reports, and DAG artifacts.
- `jsonlite` 2.0.0 observed locally - reads StatsBomb JSON from `data/raw/statsbomb/competitions.json` and `data/raw/statsbomb/events/*.json` in `R/xg/data_prep.R` and `R/integration/team_match_xg.R`.
- `tidymodels` - trains and predicts the xG classifier in `R/xg/model.R`; predictions are reused by `R/integration/team_match_xg.R`.
- `MASS` 7.3-65 observed locally - fits Negative Binomial goal models with `glm.nb()` in `R/forecast/poisson.R` and supports simulation code in `R/forecast/monte_carlo.R`.
- `dplyr` and `lubridate` 1.9.5 observed locally - normalize match data, dates, ratings, rolling form, and forecast inputs across `R/elo/`, `R/integration/`, and `R/forecast/`.
- `pROC` 1.19.0.1 observed locally - AUC/ROC validation in `R/elo/validation.R`, `R/elo/tuning.R`, and `R/xg/backtest.R`.
- `calibrate` 1.7.7 observed locally - xG calibration transformations in `R/xg/calibration.R`.

**Infrastructure:**
- Local filesystem data storage - raw files in `data/raw/`, processed files in `data/processed/`, models in `models/`, and generated outputs in `outputs/`.
- Base R serialization - `saveRDS()`/`readRDS()` for caches and model artifacts in `_targets.R`, `R/xg/data_prep.R`, `R/xg/model.R`, `R/forecast/poisson.R`, and `R/forecast/monte_carlo.R`.
- Base R CSV IO - `read.csv()`/`write.csv()` for martj42 data, Elo outputs, team-match xG, forecasts, and validation in `R/elo/preprocess.R`, `R/pipeline/validation.R`, and `R/forecast/output.R`.
- `here` 1.0.2 observed locally - documented for project-relative paths in `SETUP.md` and used in `notebooks/model_performance.Rmd`.

## Configuration

**Environment:**
- No `.env`, `.Renviron`, or `.Rprofile` files are present at the project root or inspected depth.
- No API keys or environment variables are required by the current R source.
- `SETUP.md` recommends `options(timeout = 600)` and `options(suppressPackageStartupMessages = TRUE)` for local execution.
- `.gitignore` excludes `data/raw/wcq_cache/` and `data/cache/`, so manual WCQ caches and general pipeline caches are local-only.

**Build:**
- `_targets.R` is the main pipeline configuration and entry point.
- `SETUP.md` is the dependency and environment setup guide.
- `RUNBOOK.md` contains manual execution commands and fallback workflows.
- `notebooks/model_performance.Rmd` is the main analytical report source.
- `R/pipeline/validation.R` defines runtime validation checks for raw data, processed data, models, forecasts, and calibration artifacts.
- `_targets.R` sources `R/data_ingest/martj42.R`, `R/data_ingest/statsbomb.R`, and `R/data_ingest/team_names.R`, but the current `R/` tree does not contain `R/data_ingest/`.

## Platform Requirements

**Development:**
- R >= 4.3.0; R 4.4.0 or later recommended in `SETUP.md`.
- macOS, Linux, or Windows 10+ according to `SETUP.md`.
- 8GB RAM minimum and 16GB recommended for the full pipeline according to `SETUP.md`.
- 10GB free disk space for data and model artifacts according to `SETUP.md`.
- Required local data files include `data/raw/martj42/results.csv`, `data/raw/team_name_map.csv`, `data/raw/statsbomb/competitions.json`, and `data/raw/statsbomb/events/*.json`.

**Production:**
- Deployment target is not detected.
- CI/CD configuration is not detected.
- The current operational model is local R execution through `targets::tar_make()`, manual `source()` workflows from `RUNBOOK.md`, and rendered R Markdown reports.

---

*Stack analysis: 2026-06-05*
