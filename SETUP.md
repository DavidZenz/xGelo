# xGelo Setup Guide

This guide walks you through setting up the xGelo project environment on your local machine.

---

## Prerequisites

### R Version
- **Minimum**: R >= 4.3.0 (recommended: R 4.4.0 or later)
- **Check**: `R --version`

### System Requirements
- **OS**: macOS, Linux, or Windows 10+
- **Memory**: 8GB RAM minimum (16GB recommended for full pipeline)
- **Disk**: 10GB free space for data and models

---

## Installation

### 1. Install R

**macOS**:
```bash
# Using Homebrew
brew install r

# Or download from CRAN
# https://cran.r-project.org/
```

**Linux (Ubuntu/Debian)**:
```bash
sudo apt-get update
sudo apt-get install r-base
```

**Windows**:
Download installer from [CRAN](https://cran.r-project.org/bin/windows/base/)

### 2. Install RStudio (Optional but Recommended)
Download from [RStudio](https://posit.co/downloads/)

### 3. Install Required Packages

Run the following in R:

```r
# Install core packages
install.packages(c(
  "tidyverse",      # Data manipulation and visualization
  "tidymodels",     # Modeling framework
  "jsonlite",       # JSON parsing
  "lubridate",      # Date handling
  "here",          # File path management
  "targets",       # Pipeline orchestration
  "ggplot2",        # Visualization
  "MASS",          # Negative Binomial models
  "duckdb",        # Optional Transfermarkt snapshot reader
  "knitr",         # Notebook rendering
  "rmarkdown",      # Notebook support
  "visNetwork",     # DAG visualization
  "igraph"         # Graph algorithms
))

# Install additional dependencies
install.packages(c(
  "testthat",       # Testing framework
  "devtools",       # Package development
  "roxygen2"        # Documentation
))
```

### 4. Initialize renv (Optional but Recommended)

For reproducible dependency management:

```r
# Install renv
install.packages("renv")

# Initialize in project directory
renv::init()

# Restore packages from lockfile (if exists)
renv::restore()
```

---

## Project Structure

```
xGelo/
├── .planning/               # GSD planning artifacts
│   ├── PROJECT.md           # Project definition
│   ├── ROADMAP.md           # Phase roadmap
│   ├── STATE.md             # Current status
│   └── phases/              # Phase directories
│       ├── 01-data-ingestion/
│       ├── 02-xg-model/
│       ├── 03-elo-system/
│       ├── 04-integration-layer/
│       ├── 05-forecast/
│       ├── 06-pipeline-quality/
│       └── 07-visualization-documentation/
│
├── R/                      # R source code
│   ├── xg/                  # xG model code
│   │   ├── features.R       # Feature extraction
│   │   ├── model.R          # Model training
│   │   ├── data_prep.R      # Training data prep
│   │   ├── calibration.R    # Model calibration
│   │   └── backtest.R       # Model backtesting
│   │
│   ├── elo/                # Elo rating system
│   │   ├── runner.R         # Elo computation
│   │   ├── preprocess.R     # Data preprocessing
│   │   ├── tuning.R         # Parameter tuning
│   │   └── validation.R     # Validation
│   │
│   ├── integration/        # Integration layer
│   │   ├── team_match_xg.R  # Team-match xG metrics
│   │   └── rolling_form.R   # Rolling form metrics
│   │
│   ├── forecast/           # Forecasting layer
│   │   ├── poisson.R        # NB regression models
│   │   ├── monte_carlo.R    # Monte Carlo simulation
│   │   ├── output.R         # Forecast output generation
│   │   └── calibration.R    # Forecast calibration
│   │
│   └── pipeline/           # Pipeline components
│       ├── validation.R    # Pipeline validation
│       └── dag_visualization.R  # DAG visualization
│
├── data/                  # Data directory
│   ├── raw/               # Raw data
│   │   ├── martj42/        # martj42 international results
│   │   │   ├── results.csv
│   │   │   ├── goalscorers.csv
│   │   │   └── shootouts.csv
│   │   └── statsbomb/      # StatsBomb Open Data
│   │       ├── events/     # Event JSON files
│   │       ├── lineups/    # Lineup JSON files
│   │       └── competitions.json
│   │
│   └── processed/         # Processed data
│       ├── elo_matches.csv
│       ├── elo_ratings.csv
│       ├── team_match_xg.csv
│       └── rolling_form.csv
│
├── models/                # Trained models
│   ├── xg_model.rds        # xG logistic regression model
│   ├── home_goal_model.rds # Home goal NB model
│   └── away_goal_model.rds # Away goal NB model
│
├── outputs/               # Generated outputs
│   ├── forecasts/          # Forecast CSV files
│   ├── visualizations/     # Plot PNG files
│   └── notebooks/          # Rendered notebooks
│
├── tests/                 # Test files
│   └── testthat/           # testthat tests
│       ├── test_xg_features.R
│       ├── test_elo.R
│       └── test_pipeline.R
│
├── notebooks/             # R Markdown notebooks
│   └── model_performance.Rmd
│
├── _targets.R             # Targets pipeline definition
├── SETUP.md               # This file
├── RUNBOOK.md             # Execution guide
├── MODEL-CARD.md          # Model documentation
├── DATA-INVENTORY.md      # Data source documentation
└── CLAUDE.md              # Project research memo
```

---

## Data Setup

### 1. Download Open Data Sources

#### martj42 International Results
- **Source**: [https://github.com/martj42/international_results](https://github.com/martj42/international_results)
- **Files needed**: `results.csv`, `goalscorers.csv`, `shootouts.csv`
- **Location**: `data/raw/martj42/`

#### StatsBomb Open Data
- **Source**: [https://github.com/statsbomb/open-data](https://github.com/statsbomb/open-data)
- **Files needed**: Event JSON files, lineup JSON files, competitions.json
- **Location**: `data/raw/statsbomb/`
- **Sample data**: The project includes sample files in `data/raw/statsbomb/`

#### Optional Transfermarkt Snapshot
- **Source**: [https://github.com/dcaribou/transfermarkt-datasets](https://github.com/dcaribou/transfermarkt-datasets)
- **File needed**: `transfermarkt-datasets.duckdb`
- **Location**: `data/raw/transfermarkt/transfermarkt-datasets.duckdb`
- **Usage**: Optional, default-off squad-strength feature block
- **Features**: Dated valuation aggregates, top-N squad value, positional value,
  depth concentration, age profile, and 6-/12-month valuation momentum
- **Leakage rule**: valuation and squad feature source dates must be strictly
  before the match date or benchmark cutoff date. Current player profile fields
  must not be used for historical benchmarks unless rebuilt from dated records.

### 2. Verify Data Files

```r
# Check martj42 data
file.exists("data/raw/martj42/results.csv")

# Check StatsBomb data
dir.exists("data/raw/statsbomb/events")
file.exists("data/raw/statsbomb/competitions.json")

# Optional Transfermarkt snapshot
file.exists("data/raw/transfermarkt/transfermarkt-datasets.duckdb")
```

---

## Environment Configuration

### Set Working Directory

In RStudio, set the working directory to the project root:
```r
setwd("/path/to/xGelo")
```

Or use `here::here()` in your scripts:
```r
library(here)
# All paths are relative to project root
```

### Configure Options

```r
# Increase timeout for long-running operations
options(timeout = 600)

# Suppress package startup messages
options(suppressPackageStartupMessages = TRUE)
```

---

## Pipeline Configuration

### targets Package

The project uses the `targets` package for pipeline orchestration. To run the pipeline:

```r
library(targets)
tar_make()
```

### Manual Execution

Alternatively, run phases sequentially:

```r
# Phase 1: Data Ingestion
source("R/data_ingest/martj42.R")
source("R/data_ingest/statsbomb.R")

# Phase 2: xG Model
source("R/xg/data_prep.R")
source("R/xg/model.R")

# Phase 3: Elo System
source("R/elo/runner.R")

# Phase 4: Integration
source("R/integration/team_match_xg.R")
source("R/integration/rolling_form.R")

# Phase 5: Forecasting
source("R/forecast/poisson.R")
source("R/forecast/monte_carlo.R")
source("R/forecast/output.R")

# Phase 6: Pipeline & Quality
source("R/pipeline/validation.R")

# Phase 7: Visualization & Documentation
source("R/visualization/auc.R")
source("R/visualization/calibration.R")
```

---

## Running Tests

```r
library(testthat)
test_dir("tests/testthat")
```

---

## Troubleshooting

### Common Issues

#### Package Installation Errors
- **Solution**: Update R and all packages
  ```r
  update.packages(ask = FALSE, checkBuilt = TRUE)
  ```

#### File Not Found Errors
- **Solution**: Verify working directory and file paths
  ```r
  getwd()
  list.files("data/raw/martj42")
  ```

#### Memory Issues
- **Solution**: Use `gc()` to free memory, process in batches
  ```r
  gc()
  ```

#### Pipeline Caching Issues
- **Solution**: Destroy and rebuild
  ```r
  tar_destroy()
  tar_make()
  ```

### Get Help
- Check `ROADMAP.md` for phase dependencies
- Check `STATE.md` for current progress
- Review phase-specific PLAN.md files

---

## Next Steps

After setup, proceed to [RUNBOOK.md](RUNBOOK.md) to learn how to execute the pipeline and generate forecasts.

---

*Last updated: 2026-06-04*
