# xGelo Requirements Specification

---
*Project: xGelo - Free Elo + xG Forecasting for UEFA World Cup Qualifiers*
*Version: 1.0*
*Status: Draft - Auto-generated from PROJECT.md and Research*
*Last Updated: 2026-06-03*

---

## Traceability

| Requirement ID | Phase | Status | Validation | File |
|---------------|-------|--------|------------|------|
| DATA-01 | 1 | Active | Pending | `R/data_ingest/martj42.R` |
| DATA-02 | 1 | Active | Pending | `R/data_ingest/team_names.R`, `data/raw/team_name_map.csv` |
| DATA-03 | 1 | Active | Pending | `R/data_ingest/statsbomb.R` |
| DATA-04 | 1 | Active | Pending | `DATA-INVENTORY.md` |
| XG-01 | 2 | Active | Pending | `R/xg/features.R`, `tests/testthat/test_xg_features.R` |
| XG-02 | 2 | Active | Pending | `R/xg/features.R`, `tests/testthat/test_xg_features.R` |
| XG-03 | 2 | Active | Pending | `R/xg/features.R` |
| XG-04 | 2 | Active | Pending | `R/xg/model.R`, `models/xg_model.rds` |
| XG-05 | 2 | Active | Pending | `R/xg/calibration.R`, `outputs/visualizations/xg_calibration.png` |
| XG-06 | 2 | Active | Pending | `R/xg/backtest.R`, `outputs/model_performance/xg_backtest.csv` |
| ELO-01 | 3 | Active | Pending | `R/elo/runner.R` |
| ELO-02 | 3 | Active | Pending | `R/elo/runner.R`, `data/processed/elo_ratings.csv` |
| ELO-03 | 3 | Active | Pending | `R/elo/runner.R` |
| ELO-04 | 3 | Active | Pending | `R/elo/tuning.R` |
| INTEGR-01 | 4 | Active | Pending | `R/integration/team_match_xg.R`, `data/processed/team_match_xg.csv` |
| INTEGR-02 | 4 | Active | Pending | `R/integration/rolling_form.R`, `data/processed/rolling_form.csv` |
| FORECAST-01 | 5 | Active | Pending | `R/forecast/poisson.R`, `models/home_goal_model.rds` |
| FORECAST-02 | 5 | Active | Pending | `R/forecast/poisson.R`, `models/away_goal_model.rds` |
| FORECAST-03 | 5 | Active | Pending | `R/forecast/monte_carlo.R` |
| FORECAST-04 | 5 | Active | Pending | `R/forecast/output.R`, `outputs/forecasts/` |
| FORECAST-05 | 5 | Active | Pending | `R/forecast/calibration.R`, `outputs/visualizations/forecast_calibration.png` |
| PIPELINE-01 | 6 | Active | Pending | `_targets.R`, `outputs/pipeline_dag.png` |
| PIPELINE-02 | 1 | Active | Pending | `.gitignore`, `DATA-INVENTORY.md` |
| PIPELINE-03 | 1 | Active | Pending | `R/pipeline/validation.R` |
| TEST-01 | 6 | Active | Pending | `tests/testthat/test_xg_features.R` |
| TEST-02 | 6 | Active | Pending | `tests/testthat/test_elo.R` |
| TEST-03 | 6 | Active | Pending | `tests/testthat/test_pipeline.R` |
| VIS-01 | 7 | Active | Pending | `R/visualization/auc.R`, `outputs/visualizations/auc_comparison.png` |
| VIS-02 | 7 | Active | Pending | `R/visualization/calibration.R`, `outputs/visualizations/` |
| DOC-01 | 7 | Active | Pending | `notebooks/model_performance.Rmd`, `outputs/notebooks/model_performance.html` |
| DOC-02 | 7 | Active | Pending | `SETUP.md`, `RUNBOOK.md`, `MODEL-CARD.md` |

---

## v1 Requirements (MVP - Open Mode)

### DATA: Data Ingestion & Preparation

#### DATA-01: Ingest martj42 international results dataset
- **Description**: Download and load martj42/international-football-results-from-1872 dataset from GitHub or Kaggle
- **Acceptance Criteria**: 
  - `results.csv` loaded with columns: date, home_team, away_team, home_score, away_score, tournament, city, country, neutral
  - `shootouts.csv` loaded (if available)
  - `goalscorers.csv` loaded (if available)
- **Priority**: High
- **Phase**: 1
- **Dependencies**: None
- **Files**: `R/data_ingest/martj42.R`

#### DATA-02: Normalize team names across sources
- **Description**: Create canonical team name mapping to handle variations (Turkey/Türkiye, Macedonia/North Macedonia, Czech Republic/Czechia)
- **Acceptance Criteria**:
  - `team_name_map.csv` created with columns: source_name, canonical_name, fifa_code
  - All team names from martj42, StatsBomb, and WCQ fixtures mapped to canonical names
  - FIFA codes used as primary keys where available
  - Zero unmapped teams in merged datasets
- **Priority**: High
- **Phase**: 1
- **Dependencies**: DATA-01
- **Files**: `R/data_ingest/team_names.R`, `data/raw/team_name_map.csv`

#### DATA-03: Download and cache StatsBomb Open Data events and line-ups
- **Description**: Ingest StatsBomb Open Data for **domestic leagues only** (exclude international tournaments)
- **Acceptance Criteria**:
  - Events data loaded for select leagues (EPL, La Liga, Bundesliga, Serie A, Ligue 1, etc.)
  - Line-ups data loaded for same leagues
  - Competitions data loaded
  - All files stored in `data/raw/statsbomb/` with versioning
  - **Explicitly filtered**: World Cup, Euros, Qualifiers, Nations League excluded from training set
- **Priority**: High
- **Phase**: 1
- **Dependencies**: None
- **Files**: `R/data_ingest/statsbomb.R`

#### DATA-04: Create data inventory documenting source, license, coverage
- **Description**: Comprehensive documentation of all data sources
- **Acceptance Criteria**:
  - `DATA-INVENTORY.md` created
  - Each source documented with: name, type, coverage years, license, access method, key fields, pros/cons
  - Open vs restricted sources clearly marked
  - Usage rules for each source specified
- **Priority**: Medium
- **Phase**: 1
- **Dependencies**: DATA-01, DATA-03
- **Files**: `DATA-INVENTORY.md`

---

### XG: xG Model Development

#### XG-01: Implement shot distance calculation from coordinates
- **Description**: Calculate Euclidean distance from shot location to goal center
- **Acceptance Criteria**:
  - Function `calculate_distance(x, y)` implemented
  - Handles StatsBomb coordinate system (120x80 pitch, goal at x=120, y=40 center)
  - Unit tests pass: distance from center spot = 12.0 yards
  - Distance from penalty spot = ~12 yards (depending on exact coordinates)
- **Priority**: High
- **Phase**: 2
- **Dependencies**: DATA-03
- **Files**: `R/xg/features.R`, `tests/testthat/test_xg_features.R`

#### XG-02: Implement shot angle calculation from coordinates
- **Description**: Calculate angle between shot location and goalposts
- **Acceptance Criteria**:
  - Function `calculate_angle(x, y)` implemented
  - Goalposts at y=36.34 and y=43.66, width = 7.32 yards
  - Angle in radians, range [0, π]
  - Unit tests pass: center of goal angle = π/2 (90 degrees)
  - Edge cases handled (shots behind goal, very close to goal)
- **Priority**: High
- **Phase**: 2
- **Dependencies**: DATA-03
- **Files**: `R/xg/features.R`, `tests/testthat/test_xg_features.R`

#### XG-03: Build minimal xG feature contract
- **Description**: Define and implement the minimal set of features for xG prediction
- **Acceptance Criteria**:
  - Features implemented: distance, angle, header (body_part == "Head"), open_play (play_pattern == "Regular Play"), competition
  - Feature calculation functions are pure (no side effects)
  - Feature ranges validated: distance ∈ [0, ~130], angle ∈ [0, π]
  - All features computable from StatsBomb event data
- **Priority**: High
- **Phase**: 2
- **Dependencies**: XG-01, XG-02, DATA-03
- **Files**: `R/xg/features.R`

#### XG-04: Train logistic regression xG model with splines
- **Description**: Train baseline xG model using logistic regression with splines for continuous features
- **Acceptance Criteria**:
  - Model trained using tidymodels (parsnip + recipes)
  - Formula: goal ~ distance + angle + header + open_play + competition
  - Natural splines for distance and angle (deg_free = 4)
  - Trained **only on domestic league data** (no international tournaments)
  - Model artifact saved to `models/xg_model.rds`
- **Priority**: High
- **Phase**: 2
- **Dependencies**: XG-03
- **Files**: `R/xg/model.R`, `models/xg_model.rds`

#### XG-05: Calibrate xG model on held-out test set
- **Description**: Ensure predicted xG probabilities match observed frequencies
- **Acceptance Criteria**:
  - Calibration curve generated (predicted vs observed by bins)
  - Calibration adjustment applied if needed
  - Calibrated model saved separately
  - Calibration plot saved to `outputs/visualizations/xg_calibration.png`
- **Priority**: Medium
- **Phase**: 2
- **Dependencies**: XG-04
- **Files**: `R/xg/calibration.R`, `outputs/visualizations/xg_calibration.png`

#### XG-06: Backtest xG model performance
- **Description**: Validate model performance on historical data
- **Acceptance Criteria**:
  - AUC ≥ 0.75 on held-out domestic league test set
  - Performance reported by competition/season
  - Separate performance reported for international tournaments (if available)
  - Backtest results saved to `outputs/model_performance/xg_backtest.csv`
- **Priority**: High
- **Phase**: 2
- **Dependencies**: XG-04, XG-05
- **Files**: `R/xg/backtest.R`, `outputs/model_performance/xg_backtest.csv`

---

### ELO: Elo Rating System

#### ELO-01: Implement Elo rating calculation
- **Description**: Custom Elo rating implementation in R
- **Acceptance Criteria**:
  - Function `compute_elo()` implemented (~50 LOC)
  - Handles match outcomes: win, draw, loss
  - Configurable k-factor parameter
  - Configurable home advantage parameter
  - Pure function (deterministic given inputs)
- **Priority**: High
- **Phase**: 3
- **Dependencies**: DATA-01, DATA-02
- **Files**: `R/elo/runner.R`

#### ELO-02: Compute Elo ratings across all men's international matches
- **Description**: Run Elo calculation on complete martj42 dataset
- **Acceptance Criteria**:
  - Elo ratings computed for all teams, all dates (1872-present)
  - Ratings data saved as `elo_ratings.csv` with columns: date, team, elo, home_team, away_team, home_score, away_score
  - Rating changes make intuitive sense (large changes after upsets)
  - All national teams with >1 match have ratings
- **Priority**: High
- **Phase**: 3
- **Dependencies**: ELO-01
- **Files**: `R/elo/runner.R`, `data/processed/elo_ratings.csv`

#### ELO-03: Add home advantage adjustment
- **Description**: Implement and apply home advantage to Elo calculations
- **Acceptance Criteria**:
  - Home advantage = 60 points for non-neutral home matches
  - Home advantage = 0 for neutral venues
  - Neutral flag correctly identified from martj42 data
  - Home advantage can be configured per competition type
- **Priority**: High
- **Phase**: 3
- **Dependencies**: ELO-02
- **Files**: `R/elo/runner.R`

#### ELO-04: Tune Elo k-factor and home advantage
- **Description**: Optimize Elo parameters via rolling-origin validation
- **Acceptance Criteria**:
  - k-factor tuned: separate values for frequent vs infrequent teams
  - k=20 for teams playing ≥15 matches/year, k=40 for <15 matches/year
  - Rating decay implemented: 0.995^(days_since_last_match/365)
  - Backtest shows improved prediction accuracy vs default parameters
  - Optimized parameters documented
- **Priority**: Medium
- **Phase**: 3
- **Dependencies**: ELO-02, ELO-03
- **Files**: `R/elo/tuning.R`

---

### INTEGR: Integration Layer

#### INTEGR-01: Create aggregated team-match xG metrics
- **Description**: Compute team-level xG statistics from shot-level predictions
- **Acceptance Criteria**:
  - Metrics computed: xGF (expected goals for), xGA (expected goals against), xGD (xG difference), shots per 90
  - Computed for each team in each match
  - Handles matches with no shot data (returns NA with flag)
  - Saved to `data/processed/team_match_xg.csv`
- **Priority**: High
- **Phase**: 4
- **Dependencies**: XG-04, DATA-03
- **Files**: `R/integration/team_match_xg.R`, `data/processed/team_match_xg.csv`

#### INTEGR-02: Compute rolling form metrics with EWMA
- **Description**: Calculate exponentially weighted moving averages for team form
- **Acceptance Criteria**:
  - EWMA computed over 6-12 competitive matches (configurable)
  - Metrics: xGF, xGA, xGD, shots per 90
  - Weighting: most recent match has weight 1, decay factor configurable
  - Missing data handled gracefully (NA for teams with insufficient history)
  - Saved to `data/processed/rolling_form.csv`
- **Priority**: Medium
- **Phase**: 4
- **Dependencies**: INTEGR-01
- **Files**: `R/integration/rolling_form.R`, `data/processed/rolling_form.csv`

---

### FORECAST: Forecasting Layer

#### FORECAST-01: Build Poisson/NB regression model for home goals
- **Description**: Model expected home team goals using Poisson or Negative Binomial distribution
- **Acceptance Criteria**:
  - Features used: elo_diff, home_xgf_ewma, away_xga_ewma, non_neutral_home, rest_diff
  - **Negative Binomial distribution** (not Poisson) to handle overdispersion
  - Model trained on historical international matches with xG data
  - Model artifact saved to `models/home_goal_model.rds`
- **Priority**: High
- **Phase**: 5
- **Dependencies**: INTEGR-01, INTEGR-02, ELO-02
- **Files**: `R/forecast/poisson.R`, `models/home_goal_model.rds`

#### FORECAST-02: Build Poisson/NB regression model for away goals
- **Description**: Model expected away team goals
- **Acceptance Criteria**:
  - Similar to FORECAST-01 but for away goals
  - Features may differ slightly (e.g., away_xgf_ewma, home_xga_ewma)
  - Model artifact saved to `models/away_goal_model.rds`
- **Priority**: High
- **Phase**: 5
- **Dependencies**: INTEGR-01, INTEGR-02, ELO-02
- **Files**: `R/forecast/poisson.R`, `models/away_goal_model.rds`

#### FORECAST-03: Implement Monte Carlo simulation engine
- **Description**: Simulate match outcomes based on goal models
- **Acceptance Criteria**:
  - 50,000 scenarios per fixture (configurable)
  - Each scenario simulates home_goals ~ NB(λ_h), away_goals ~ NB(λ_a)
  - Performance: <10 seconds per fixture on M1/M2 Mac
  - Results include: home_win, draw, away_win counts and probabilities
  - All randomness seeded for reproducibility
- **Priority**: High
- **Phase**: 5
- **Dependencies**: FORECAST-01, FORECAST-02
- **Files**: `R/forecast/monte_carlo.R`

#### FORECAST-04: Generate win/draw/loss probabilities and expected goals
- **Description**: Aggregate Monte Carlo results into final predictions
- **Acceptance Criteria**:
  - Output columns: fixture, date, home_team, away_team, home_win_p, draw_p, away_win_p, exp_home_goals, exp_away_goals
  - Probabilities sum to 1.0 ± 0.001
  - Draw probability calibrated to ~28% for WCQ-UEFA
  - Output saved to `outputs/forecasts/{date}/predictions.csv`
- **Priority**: High
- **Phase**: 5
- **Dependencies**: FORECAST-03
- **Files**: `R/forecast/output.R`, `outputs/forecasts/`

#### FORECAST-05: Calibrate forecast model
- **Description**: Ensure predicted probabilities match observed frequencies
- **Acceptance Criteria**:
  - Draw frequency predicted vs observed: within ±5%
  - Brier score computed and tracked over time
  - Calibration plot generated (predicted vs observed probabilities)
  - Calibration adjustment applied if needed
  - Calibration results documented
- **Priority**: Medium
- **Phase**: 5
- **Dependencies**: FORECAST-04
- **Files**: `R/forecast/calibration.R`, `outputs/visualizations/forecast_calibration.png`

---

### PIPELINE: Pipeline & Quality

#### PIPELINE-01: Implement targets pipeline with clear dependency graph
- **Description**: Set up reproducible pipeline orchestration
- **Acceptance Criteria**:
  - `_targets.R` created with all targets defined
  - DAG dependencies correctly specified (data → xG → Elo → integration → forecast)
  - Pipeline runs end-to-end without errors
  - `targets::tar_manifest()` shows all targets and dependencies
  - DAG visualization generated
- **Priority**: High
- **Phase**: 7
- **Dependencies**: All previous requirements
- **Files**: `_targets.R`, `outputs/pipeline_dag.png`

#### PIPELINE-02: Set up local cache directory structure with versioning
- **Description**: Organize cached data with proper versioning
- **Acceptance Criteria**:
  - Directory structure: `data/raw/{source}/`, `data/processed/`, `data/models/`, `data/cache/`
  - Each source in its own subdirectory
  - Raw data files named with version/hash (e.g., `results_20260603_v1.csv`)
  - `.gitignore` excludes all cache directories
  - Cache directories documented in `DATA-INVENTORY.md`
- **Priority**: High
- **Phase**: 1
- **Dependencies**: None
- **Files**: `.gitignore`, `DATA-INVENTORY.md`

#### PIPELINE-03: Create schema validation for all ingested data
- **Description**: Ensure data quality with automated validation
- **Acceptance Criteria**:
  - Schema defined for each data source (column names, types, ranges, nullability)
  - Validation runs automatically after each ingest target
  - Validation uses `pointblank` package
  - Failed validation stops pipeline and reports clear error
  - Validation results logged
- **Priority**: Medium
- **Phase**: 1
- **Dependencies**: PIPELINE-01
- **Files**: `R/pipeline/validation.R`

---

### VIS: Visualization

#### VIS-01: Create AUC comparison chart showing performance by feature set
- **Description**: Visualize xG model performance across different feature configurations
- **Acceptance Criteria**:
  - Bar chart with 4 groups: location-only, location + body part + competition, interpretable mixed model, multi-event model
  - Reference AUC values: ~0.75, ~0.79, ~0.781/0.801, ~0.826
  - Chart saved to `outputs/visualizations/auc_comparison.png`
  - Code reproducible (saved as R script)
- **Priority**: Medium
- **Phase**: 8
- **Dependencies**: XG-06
- **Files**: `R/visualization/auc.R`, `outputs/visualizations/auc_comparison.png`

#### VIS-02: Generate calibration plots for both xG and forecast models
- **Description**: Create visual proofs of model calibration
- **Acceptance Criteria**:
  - xG calibration plot: predicted vs observed by probability bins
  - Forecast calibration plot: predicted vs observed win/draw/loss probabilities
  - Both plots saved as PNG files
  - Ideal line (y=x) shown for reference
- **Priority**: Medium
- **Phase**: 8
- **Dependencies**: XG-05, FORECAST-05
- **Files**: `R/visualization/calibration.R`, `outputs/visualizations/`

---

### TEST: Testing

#### TEST-01: Unit tests for xG feature calculations
- **Description**: Verify correctness of xG feature functions
- **Acceptance Criteria**:
  - Tests for `calculate_distance()`: known values at specific coordinates
  - Tests for `calculate_angle()`: known angles (e.g., center = π/2, directly in front = 0)
  - Tests for feature contract: types, ranges, NA handling
  - Coverage ≥ 80% for xG feature functions
  - All tests pass
- **Priority**: High
- **Phase**: 7
- **Dependencies**: XG-01, XG-02, XG-03
- **Files**: `tests/testthat/test_xg_features.R`

#### TEST-02: Unit tests for Elo calculation logic
- **Description**: Verify correctness of Elo rating functions
- **Acceptance Criteria**:
  - Tests for `compute_elo()`: known rating changes for given outcomes
  - Tests for home advantage application
  - Tests for k-factor configuration
  - Tests for rating decay
  - Coverage ≥ 80% for Elo functions
  - All tests pass
- **Priority**: High
- **Phase**: 7
- **Dependencies**: ELO-01, ELO-02, ELO-03, ELO-04
- **Files**: `tests/testthat/test_elo.R`

#### TEST-03: Integration test for full pipeline execution
- **Description**: Verify end-to-end pipeline works correctly
- **Acceptance Criteria**:
  - Test runs full pipeline from raw data to forecasts
  - All targets complete successfully
  - Output files generated in expected locations
  - Predictions have expected format and values
  - Performance within expected ranges
  - Pipeline reproducible: run twice, outputs match
- **Priority**: High
- **Phase**: 7
- **Dependencies**: All previous requirements
- **Files**: `tests/testthat/test_pipeline.R`

---

### DOC: Documentation

#### DOC-01: Reproducible research notebook showing model performance
- **Description**: Jupyter/R Markdown notebook demonstrating model capabilities
- **Acceptance Criteria**:
  - Notebook includes: data loading, feature engineering, model training, evaluation
  - All code cells executable
  - Performance metrics reported: AUC, calibration, Brier score
  - Visualizations embedded in notebook
  - Notebook renderable to HTML
- **Priority**: Medium
- **Phase**: 8
- **Dependencies**: XG-06, FORECAST-05
- **Files**: `notebooks/model_performance.Rmd`, `outputs/notebooks/model_performance.html`

#### DOC-02: Technical documentation for pipeline setup and execution
- **Description**: Guide for setting up and running the forecasting pipeline
- **Acceptance Criteria**:
  - `SETUP.md` created with: prerequisites, installation, configuration
  - `RUNBOOK.md` created with: how to run pipeline, expected outputs, troubleshooting
  - Data inventory with sources, licenses, update frequencies
  - Model card documenting performance, limitations, intended use
- **Priority**: Medium
- **Phase**: 8
- **Dependencies**: PIPELINE-01
- **Files**: `SETUP.md`, `RUNBOOK.md`, `MODEL-CARD.md`

---

## v2 Requirements (Deferred)

### Enhanced xG Model
- **XG-07**: Mixed-effects xG model with team random effects (glmmTMB or mgcv)
- **XG-08**: Sequence-aware xG model using 1-3 preceding events
- **XG-09**: Pre-shot context features (pass length, build-up type)

### Enhanced Forecasting
- **FORECAST-06**: Group stage simulation (full group table, not just single matches)
- **FORECAST-07**: Tournament-level predictions (qualification probabilities)
- **FORECAST-08**: Uncertainty quantification (prediction intervals, entropy scores)

### Enhanced Data
- **DATA-05**: Manual WCQ shot data cache (FotMob) - Hybrid Mode
- **DATA-06**: UEFA/FIFA fixtures and line-ups ingestion
- **DATA-07**: Weather and venue data for context adjustment

### Enhanced Pipeline
- **PIPELINE-04**: Automated data refresh workflow
- **PIPELINE-05**: Monitoring and alerting for data drift
- **PIPELINE-06**: CI/CD pipeline for automated testing

---

## Out of Scope

| Requirement | Reason | Alternative |
|-------------|--------|-------------|
| Real-time data collection | ToS restrictions on automated scraping | Pre-match batch only |
| FBref integration | Advanced data removed Jan 2026 | martj42 primary |
| Tracking data (360) | Not available free for WCQ | Focus on event data |
| Injury/suspension modelling | No clean free source | Model without it |
| Live betting integration | Not a commercial product | Educational/analytical only |
| Mobile app / web dashboard | Focus on model and pipeline | CLI/R output only |
| Women's football | Scope limited to men's WCQ | Future extension possible |
| Youth tournaments | Focus on senior national teams | Keep scope tight |

---

## Requirement Quality Checklist

- [x] **Specific and testable**: Each requirement has clear acceptance criteria
- [x] **User-centric**: Focused on what users need (predictions, accuracy, reproducibility)
- [x] **Atomic**: Each requirement is a single capability
- [x] **Independent**: Minimal dependencies between requirements within same phase
- [x] **Prioritized**: MVP vs v2 vs out of scope clearly separated
- [x] **Traceable**: Each requirement mapped to phase

---

## Phase Summary

| Phase | Requirements | Count | Focus |
|-------|-------------|-------|-------|
| 1 | DATA-01 to DATA-04, PIPELINE-02 | 5 | Data ingestion and infrastructure |
| 2 | XG-01 to XG-06 | 6 | xG model development |
| 3 | ELO-01 to ELO-04 | 4 | Elo rating system |
| 4 | INTEGR-01, INTEGR-02 | 2 | Integration layer |
| 5 | FORECAST-01 to FORECAST-05 | 5 | Forecasting layer |
| 7 | PIPELINE-01, PIPELINE-03, TEST-01 to TEST-03 | 5 | Pipeline and quality |
| 8 | VIS-01, VIS-02, DOC-01, DOC-02 | 4 | Visualization and documentation |

**Total v1 Requirements: 31**
**Total v2 Requirements: 10**

---
*Generated: 2026-06-03 | Method: Auto-extracted from PROJECT.md and research outputs*
