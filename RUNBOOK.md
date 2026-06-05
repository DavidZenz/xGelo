# xGelo Runbook

This guide explains how to run the xGelo forecasting pipeline and generate predictions for UEFA World Cup Qualifier fixtures.

---

## Quick Start

### Run the Full Pipeline

Using the targets package (recommended):

```r
library(targets)
tar_make()  # Runs all out-of-date targets
tar_destroy()  # Clean cache
tar_make()  # Force full rebuild
```

### Run Phases Manually

```r
# Phase 1: Data Ingestion (already complete)
# Phase 2: xG Model (already complete)
# Phase 3: Elo System (already complete)

# Phase 4: Integration Layer
source("R/integration/team_match_xg.R")
run_team_match_xg(use_own_model = TRUE)

source("R/integration/rolling_form.R")
run_rolling_form()

# Phase 5: Forecasting Layer
source("R/forecast/poisson.R")
train_home_goal_model()
train_away_goal_model()

source("R/forecast/monte_carlo.R")
# Test with sample fixture
simulate_fixture("Spain", "Italy", seed = 42)

source("R/forecast/output.R")
# Generate batch forecasts
fixtures <- data.frame(
  home_team = c("Spain", "Germany"),
  away_team = c("Italy", "France"),
  date = as.Date(c("2026-06-10", "2026-06-11")),
  venue = c("home", "home"),
  stringsAsFactors = FALSE
)
generate_batch_forecasts(fixtures)

# Phase 6: Pipeline & Quality
source("R/pipeline/validation.R")
run_validation_checks()
run_dag_visualization()

# Phase 7: Visualization & Documentation
source("R/visualization/auc.R")
run_auc_chart()

source("R/visualization/calibration.R")
run_calibration_plots()

# Render notebook
rmarkdown::render("notebooks/model_performance.Rmd", 
                  output_dir = "outputs/notebooks")
```

---

## Detailed Instructions

### Phase 1: Data Ingestion & Infrastructure

**Status**: Complete (pre-requisite for all other phases)

**Outputs**:
- `data/raw/martj42/results.csv` - International match results
- `data/raw/statsbomb/events/` - Event data
- `data/raw/statsbomb/competitions.json` - Competition metadata
- `data/raw/team_name_map.csv` - Team name normalization

**To re-run**:
```r
source("R/data_ingest/martj42.R")
source("R/data_ingest/statsbomb.R")
source("R/data_ingest/team_names.R")
```

---

### Phase 2: xG Model Development

**Status**: Complete

**Outputs**:
- `models/xg_model.rds` - Trained logistic regression model
- `models/xg_calibration.rds` - Calibration results
- `outputs/visualizations/xg_calibration.png` - Calibration plot

**Key Metrics**:
- AUC: **0.7905** (on held-out domestic league test set)
- Target: >= 0.75

**To re-run**:
```r
source("R/xg/data_prep.R")
train_and_save_xg_model(prepare_training_data("data/raw/statsbomb/events/", 
                                                "data/raw/statsbomb/competitions.json"))
```

---

### Phase 3: Elo Rating System

**Status**: Complete

**Outputs**:
- `data/processed/elo_matches.csv` - Processed match data
- `data/processed/elo_ratings.csv` - Elo ratings (197,808 entries, 336 teams)
- `data/processed/elo_current.csv` - Latest ratings

**Configuration**:
- Home advantage: 60 points
- K-factor: 20 (active teams), 40 (inactive teams)
- Decay: 0.995^(days_since_last/365)
- Validation AUC: **0.7916**

**To re-run**:
```r
source("R/elo/runner.R")
compute_elo_all()
```

---

### Phase 4: Integration Layer

**Purpose**: Combine xG and Elo outputs into team-match metrics and form indicators

**Dependencies**: Phase 2 (xG model), Phase 1 (StatsBomb data), Phase 3 (Elo ratings)

#### Task 4.1: Team-Match xG Metrics

```r
source("R/integration/team_match_xg.R")
# Use our own xG model (Phase 2)
run_team_match_xg(use_own_model = TRUE)
```

**Output**: `data/processed/team_match_xg.csv`

**Columns**:
- `match_id`: Unique match identifier
- `date`: Match date
- `competition`: Competition name
- `home_team`, `away_team`: Team names
- `xGF`, `xGA`, `xGD`: Expected goals metrics
- `shots_home`, `shots_away`: Shot counts
- `shots_per_90_home`, `shots_per_90_away`: Normalized shot rates
- `has_shot_data`: Flag for matches with shot data

#### Task 4.2: Rolling Form Metrics

```r
source("R/integration/rolling_form.R")
run_rolling_form()
```

**Output**: `data/processed/rolling_form.csv`

**Columns**:
- `team`: Team name
- `match_date`: Match date
- `opponent`: Opponent team
- `is_home`: Home/away flag
- `match_num`: Sequential match number
- `xgf_ewma`, `xga_ewma`, `xgd_ewma`: EWMA of xG metrics
- `shots_ewma`: EWMA of shots
- `elo`: Elo rating at match time
- `elo_ewma`: EWMA of Elo rating
- `form_index`: Composite form metric
- `span`, `alpha`: EWMA parameters

---

### Phase 5: Forecasting Layer

**Purpose**: Build goal models, implement Monte Carlo simulation, generate win/draw/loss probabilities

**Dependencies**: Phase 4 (integration metrics), Phase 3 (Elo ratings)

#### Task 5.1: Home Goal Model

```r
source("R/forecast/poisson.R")
train_home_goal_model()
```

**Output**: `models/home_goal_model.rds`

**Features**:
- `elo_diff`: Home Elo - Away Elo (with home advantage)
- Model type: Negative Binomial regression

#### Task 5.2: Away Goal Model

```r
source("R/forecast/poisson.R")
train_away_goal_model()
```

**Output**: `models/away_goal_model.rds`

**Features**:
- `elo_diff`: Away Elo - Home Elo
- Model type: Negative Binomial regression

#### Task 5.3: Monte Carlo Simulation

```r
source("R/forecast/monte_carlo.R")

# Single fixture
result <- simulate_fixture(
  home_team = "Spain",
  away_team = "Italy",
  venue = "home",
  seed = 42
)

# Access results
result$win_prob      # P(win)
result$draw_prob     # P(draw)
result$loss_prob     # P(loss)
result$expected_home # Expected home goals
result$expected_away # Expected away goals
```

**Performance**: <10 seconds per fixture on M1/M2 Mac

**Scenarios**: 50,000 simulations per fixture

#### Task 5.4: Generate Forecasts

```r
source("R/forecast/output.R")

# Single fixture forecast
forecast <- generate_forecast(
  home_team = "Spain",
  away_team = "Italy",
  date = as.Date("2026-06-10"),
  venue = "home"
)

# Batch forecasts
fixtures <- data.frame(
  home_team = c("Spain", "Germany", "France"),
  away_team = c("Italy", "Netherlands", "England"),
  date = as.Date(c("2026-06-10", "2026-06-11", "2026-06-12")),
  venue = c("home", "home", "neutral"),
  stringsAsFactors = FALSE
)

generate_batch_forecasts(fixtures, output_dir = "outputs/forecasts")
```

**Output**: CSV files in `outputs/forecasts/`

**Columns**:
- `fixture_id`: Unique fixture identifier
- `home_team`, `away_team`: Team names
- `date`: Match date
- `venue`: home/away/neutral
- `home_goals_expected`, `away_goals_expected`: Expected goals
- `win_probability`, `draw_probability`, `loss_probability`: Outcome probabilities
- `model_version`: Model version
- `timestamp`: When forecast was generated

#### Task 5.5: Model Calibration

```r
source("R/forecast/calibration.R")
run_calibration()
```

**Output**: `outputs/visualizations/forecast_calibration.png`

**Metrics**:
- Draw probability: ~28% (target for WCQ-UEFA)
- Brier score: < 0.25

---

### Phase 6: Pipeline & Quality

**Purpose**: Create reproducible pipeline with data quality validation and comprehensive tests

#### Task 6.1: Targets Pipeline

The `_targets.R` file defines the complete pipeline with dependencies.

```r
library(targets)

# View pipeline
tar_manifest()

# Check progress
tar_progress()

# Run all
tar_make()

# Run specific target
tar_make(tar_team_match_xg)

# Visualize DAG
tar_visnetwork(filename = "outputs/pipeline_dag.png")
```

**Note**: The targets package may have environment-specific issues. Use manual execution as fallback.

#### Task 6.2: Unit Tests for xG Features

```r
# Run all tests
library(testthat)
test_dir("tests/testthat")

# Run specific test file
test_file("tests/testthat/test_xg_features.R")
```

#### Task 6.3: Unit Tests for Elo

```r
test_file("tests/testthat/test_elo.R")
```

#### Task 6.4: Integration Tests

```r
test_file("tests/testthat/test_pipeline.R")
```

---

### Phase 7: Visualization & Documentation

**Purpose**: Create visual proofs of model performance and document the system

#### Task 7.1: AUC Comparison Chart

```r
source("R/visualization/auc.R")
run_auc_chart()
```

**Output**: `outputs/visualizations/auc_comparison.png`

**Configurations**:
1. Elo only (baseline)
2. Elo + xG form
3. Elo + xG form + rest days
4. Full model

#### Task 7.2: Calibration Plots

```r
source("R/visualization/calibration.R")
run_calibration_plots()
```

**Outputs**:
- `outputs/visualizations/xg_calibration.png`
- `outputs/visualizations/forecast_calibration.png`

#### Task 7.3: Research Notebook

```r
# Render notebook to HTML
rmarkdown::render(
  "notebooks/model_performance.Rmd",
  output_dir = "outputs/notebooks",
  output_format = "html_document"
)

# Or render to PDF
rmarkdown::render(
  "notebooks/model_performance.Rmd",
  output_dir = "outputs/notebooks",
  output_format = "pdf_document"
)
```

**Output**: `outputs/notebooks/model_performance.html`

**Execution time**: <5 minutes for full notebook

#### Task 7.4: Technical Documentation

The documentation files are static and don't require execution:
- `SETUP.md`: Installation and setup
- `RUNBOOK.md`: This file
- `MODEL-CARD.md`: Model specifications

---

## Generating Forecasts for New Fixtures

### Step 1: Prepare Fixture Data

```r
# Create a data frame with fixture information
new_fixtures <- data.frame(
  home_team = c("Spain", "Germany", "France", "Italy"),
  away_team = c("Portugal", "England", "Netherlands", "Switzerland"),
  date = as.Date(c("2026-06-15", "2026-06-16", "2026-06-17", "2026-06-18")),
  venue = c("home", "home", "away", "neutral"),
  stringsAsFactors = FALSE
)
```

### Step 2: Generate Forecasts

```r
source("R/forecast/output.R")
forecasts <- generate_batch_forecasts(new_fixtures)
```

### Step 3: View Results

```r
# List generated forecast files
list.files("outputs/forecasts", pattern = "\.csv$")

# Load and view a forecast
forecast <- read.csv("outputs/forecasts/Spain_vs_Portugal_2026-06-15.csv")
print(forecast)
```

### Step 4: Interpret Results

Each forecast CSV contains:
- **Expected goals**: Mean goals from Monte Carlo simulation
- **Win/Draw/Loss probabilities**: From 50,000 simulated scenarios
- **Timestamp**: When forecast was generated

Example interpretation:
- Win probability: 0.45 → 45% chance of win
- Draw probability: 0.28 → 28% chance of draw
- Loss probability: 0.27 → 27% chance of loss
- Expected goals: Home 1.8, Away 1.2

---

## Updating Data

### Add New StatsBomb Events

1. Download new event files from [StatsBomb Open Data](https://github.com/statsbomb/open-data)
2. Place them in `data/raw/statsbomb/events/`
3. Re-run Phase 4:

```r
source("R/integration/team_match_xg.R")
run_team_match_xg()

source("R/integration/rolling_form.R")
run_rolling_form()
```

### Add New martj42 Results

1. Download updated `results.csv` from [martj42/international_results](https://github.com/martj42/international_results)
2. Replace `data/raw/martj42/results.csv`
3. Re-run Phase 3:

```r
source("R/elo/runner.R")
compute_elo_all()
```

---

## Validation and Quality Checks

### Run All Validations

```r
source("R/pipeline/validation.R")
results <- run_all_validations()
run_validation_checks()
```

### Check Pipeline Status

```r
source("R/pipeline/validation.R")
results <- run_validation_checks()
```

### Run Tests

```r
library(testthat)
test_dir("tests/testthat")
```

---

## Performance Benchmarks

| Phase | Estimated Time | Notes |
|-------|----------------|-------|
| Phase 1 | 5-10 minutes | Data download and caching |
| Phase 2 | 10-15 minutes | Model training |
| Phase 3 | 20-30 minutes | Elo computation (49K matches) |
| Phase 4 | 5-10 minutes | Integration metrics |
| Phase 5 | 15-20 minutes | Model training + simulation |
| Phase 6 | 2-5 minutes | Validation and tests |
| Phase 7 | 5-10 minutes | Visualization and docs |
| **Total** | **60-100 minutes** | Full pipeline from scratch |

---

## Expected Outputs

After running the complete pipeline, you should have:

### Data Files
- `data/processed/elo_matches.csv`
- `data/processed/elo_ratings.csv`
- `data/processed/team_match_xg.csv`
- `data/processed/rolling_form.csv`

### Models
- `models/xg_model.rds`
- `models/home_goal_model.rds`
- `models/away_goal_model.rds`

### Forecasts
- `outputs/forecasts/*.csv` (one per fixture)

### Visualizations
- `outputs/visualizations/auc_comparison.png`
- `outputs/visualizations/xg_calibration.png`
- `outputs/visualizations/forecast_calibration.png`
- `outputs/pipeline_dag.png`

### Documentation
- `notebooks/model_performance.Rmd`
- `outputs/notebooks/model_performance.html`
- `SETUP.md`
- `RUNBOOK.md`
- `MODEL-CARD.md`

---

## Troubleshooting

### Common Issues and Solutions

#### "File not found" errors
```r
# Check your working directory
getwd()

# Set to project root
setwd("/path/to/xGelo")

# Or use here::here()
library(here)
```

#### Package not available
```r
# Install missing packages
install.packages("missing_package")
```

#### Memory errors
```r
# Free memory
gc()

# Process in batches
# Instead of processing all files at once, use lapply with smaller chunks
```

#### Model training fails to converge
```r
# Try with different control parameters
glm.nb(..., control = glm.control(maxit = 100))

# Or fall back to Poisson
glm(..., family = poisson)
```

#### Monte Carlo is too slow
```r
# Reduce number of simulations for testing
simulate_fixture("Team A", "Team B", n_sim = 1000)

# For production, use 50,000
simulate_fixture("Team A", "Team B", n_sim = 50000)
```

---

## Best Practices

1. **Set seed for reproducibility**: Always set `set.seed()` before random operations
2. **Use here::here()**: For file paths to ensure they work across different working directories
3. **Cache intermediate results**: Use `data/cache/` for expensive computations
4. **Run tests frequently**: Validate each phase as you go
5. **Check dependencies**: Ensure all required files exist before running

---

## Version History

- **v1.0** (2026-06-04): Initial release with all 7 phases complete

---

## Get Help

- Check [SETUP.md](SETUP.md) for installation issues
- Check [MODEL-CARD.md](MODEL-CARD.md) for model details
- Review phase-specific PLAN.md files in `.planning/phases/`

*Last updated: 2026-06-04*
