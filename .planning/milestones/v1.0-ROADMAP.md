# xGelo Roadmap

---
*Project: xGelo - Free Elo + xG Forecasting for UEFA World Cup Qualifiers*
*Version: 1.0*
*Status: Active*
*Last Updated: 2026-06-03*

---

## Overview

This roadmap organizes all v1 (MVP) requirements into 7 sequential phases. Each phase delivers a testable increment of the forecasting system.

---

## Phase Map

```
DATA Layer (Phase 1) -> xG Model (Phase 2) -> Elo Layer (Phase 3) ->
Integration (Phase 4) -> Forecasting (Phase 5) -> Pipeline & Quality (Phase 6) ->
Visualization & Docs (Phase 7)
```

---

## Phases

### Phase 1: Data Ingestion & Infrastructure
**Focus**: Ingest all open data sources, establish canonical naming, set up caching and validation infrastructure.

| Requirement | Description | Files |
|-------------|-------------|-------|
| DATA-01 | Ingest martj42 international results dataset | `R/data_ingest/martj42.R` |
| DATA-02 | Normalize team names across sources | `R/data_ingest/team_names.R`, `data/raw/team_name_map.csv` |
| DATA-03 | Download and cache StatsBomb Open Data events and line-ups | `R/data_ingest/statsbomb.R` |
| DATA-04 | Create data inventory documenting source, license, coverage | `DATA-INVENTORY.md` |
| PIPELINE-02 | Set up local cache directory structure with versioning | `.gitignore`, `DATA-INVENTORY.md` |
| PIPELINE-03 | Create schema validation for all ingested data | `R/pipeline/validation.R` |

**Success Criteria**
- [x] `results.csv` loaded with expected schema (date, home_team, away_team, scores, tournament, neutral)
- [x] All team names from martj42, StatsBomb, and WCQ fixtures mapped to canonical FIFA codes
- [x] StatsBomb events and line-ups cached locally with versioning
- [x] `DATA-INVENTORY.md` documents all sources with license and usage rules
- [x] Cache directories exist with proper `.gitignore` exclusions
- [x] Schema validation runs automatically on ingest and stops pipeline on failure

**Dependencies**: None

---

### Phase 2: xG Model Development
**Focus**: Implement xG feature calculations, train baseline logistic regression model, validate performance.

| Requirement | Description | Files |
|-------------|-------------|-------|
| XG-01 | Implement shot distance calculation from coordinates | `R/xg/features.R`, `tests/testthat/test_xg_features.R` |
| XG-02 | Implement shot angle calculation from coordinates | `R/xg/features.R`, `tests/testthat/test_xg_features.R` |
| XG-03 | Build minimal xG feature contract (distance, angle, header, open_play, competition) | `R/xg/features.R` |
| XG-04 | Train logistic regression xG model with splines | `R/xg/model.R`, `models/xg_model.rds` |
| XG-05 | Calibrate xG model on held-out test set | `R/xg/calibration.R`, `outputs/visualizations/xg_calibration.png` |
| XG-06 | Backtest xG model performance | `R/xg/backtest.R`, `outputs/model_performance/xg_backtest.csv` |

**Success Criteria**
- [x] `calculate_distance()` and `calculate_angle()` pass all unit tests with known values
- [x] Feature contract produces valid ranges: distance ∈ [0, ~130], angle ∈ [0, π]
- [x] Model trained using tidymodels with natural splines for distance and angle
- [x] Model achieves **AUC = 0.7905 ≥ 0.75** on held-out domestic league test set
- [x] Calibration curve shows predicted vs observed probabilities within ±5% per bin
- [x] Backtest results saved with performance by competition/season

**Dependencies**: Phase 1 (DATA-03 for training data)

**Parallelizable**: Yes (with Phase 3)

---

### Phase 3: Elo Rating System
**Focus**: Implement custom Elo rating calculation, compute historical ratings, tune parameters.

| Requirement | Description | Files |
|-------------|-------------|-------|
| ELO-01 | Implement Elo rating calculation | `R/elo/runner.R` |
| ELO-02 | Compute Elo ratings across all men's international matches | `R/elo/runner.R`, `data/processed/elo_ratings.csv` |
| ELO-03 | Add home advantage adjustment (60 points) | `R/elo/runner.R` |
| ELO-04 | Tune Elo k-factor and home advantage via rolling-origin validation | `R/elo/tuning.R` |

**Success Criteria**
- [x] `compute_elo()` is pure function with configurable k-factor and home advantage
- [x] Elo ratings computed for all teams from 1872-present (49,368 matches, 336 teams)
- [x] Home advantage = 60 points for non-neutral matches, 0 for neutral venues
- [x] k-factor tuned: 20 for teams ≥15 matches/year, 40 for <15 matches/year
- [x] Rating decay implemented: 0.995^(days_since_last/365), validation AUC=0.7916

**Dependencies**: Phase 1 (DATA-01, DATA-02)

**Parallelizable**: Yes (with Phase 2)

---

### Phase 4: Integration Layer
**Focus**: Combine xG and Elo outputs into team-match metrics and form indicators.

| Requirement | Description | Files |
|-------------|-------------|-------|
| INTEGR-01 | Create aggregated team-match xG metrics (xGF, xGA, xGD, shots per 90) | `R/integration/team_match_xg.R`, `data/processed/team_match_xg.csv` |
| INTEGR-02 | Compute rolling form metrics with EWMA over 6-12 matches | `R/integration/rolling_form.R`, `data/processed/rolling_form.csv` |

**Success Criteria**
- [ ] xGF, xGA, xGD, shots per 90 computed for each team in each match
- [ ] Matches with no shot data return NA with flag
- [ ] EWMA computed over 6-12 competitive matches (configurable)
- [ ] Most recent match has weight 1 with configurable decay factor
- [ ] Missing data handled gracefully (NA for teams with insufficient history)

**Dependencies**: Phase 2 (XG-04), Phase 1 (DATA-03)

---

### Phase 5: Forecasting Layer
**Focus**: Build goal models, implement Monte Carlo simulation, generate predictions.

| Requirement | Description | Files |
|-------------|-------------|-------|
| FORECAST-01 | Build Negative Binomial regression model for home goals | `R/forecast/poisson.R`, `models/home_goal_model.rds` |
| FORECAST-02 | Build Negative Binomial regression model for away goals | `R/forecast/poisson.R`, `models/away_goal_model.rds` |
| FORECAST-03 | Implement Monte Carlo simulation engine (50,000 scenarios per fixture) | `R/forecast/monte_carlo.R` |
| FORECAST-04 | Generate win/draw/loss probabilities and expected goals | `R/forecast/output.R`, `outputs/forecasts/` |
| FORECAST-05 | Calibrate forecast model | `R/forecast/calibration.R`, `outputs/visualizations/forecast_calibration.png` |

**Success Criteria**
- [ ] Home/away goal models use Negative Binomial distribution with features: elo_diff, xgf_ewma, xga_ewma, non_neutral_home, rest_diff
- [ ] Monte Carlo simulates 50,000 scenarios per fixture in **<10 seconds** on M1/M2 Mac
- [ ] Probabilities sum to 1.0 ± 0.001
- [ ] Draw probability calibrated to ~28% for WCQ-UEFA
- [ ] Brier score computed and tracked over time

**Dependencies**: Phase 4 (INTEGR-01, INTEGR-02), Phase 3 (ELO-02)

---

### Phase 6: Pipeline & Quality
**Focus**: Orchestrate all components with targets, validate data quality, test everything.

| Requirement | Description | Files |
|-------------|-------------|-------|
| PIPELINE-01 | Implement targets pipeline with clear dependency graph | `_targets.R`, `outputs/pipeline_dag.png` |
| TEST-01 | Unit tests for xG feature calculations | `tests/testthat/test_xg_features.R` |
| TEST-02 | Unit tests for Elo calculation logic | `tests/testthat/test_elo.R` |
| TEST-03 | Integration test for full pipeline execution | `tests/testthat/test_pipeline.R` |

**Success Criteria**
- [ ] `_targets.R` defines all targets with correct DAG dependencies (data -> xG -> Elo -> integration -> forecast)
- [ ] DAG visualization generated and saved
- [ ] Pipeline runs end-to-end without errors
- [ ] All unit tests pass with >=80% coverage for xG and Elo functions
- [ ] Integration test: run pipeline twice, outputs match (reproducibility)

**Dependencies**: All previous phases

---

### Phase 7: Visualization & Documentation
**Focus**: Create visual proofs of performance, document system for users.

| Requirement | Description | Files |
|-------------|-------------|-------|
| VIS-01 | Create AUC comparison chart showing performance by feature set | `R/visualization/auc.R`, `outputs/visualizations/auc_comparison.png` |
| VIS-02 | Generate calibration plots for both xG and forecast models | `R/visualization/calibration.R`, `outputs/visualizations/` |
| DOC-01 | Reproducible research notebook showing model performance | `notebooks/model_performance.Rmd`, `outputs/notebooks/model_performance.html` |
| DOC-02 | Technical documentation for pipeline setup and execution | `SETUP.md`, `RUNBOOK.md`, `MODEL-CARD.md` |

**Success Criteria**
- [ ] AUC comparison chart shows 4 feature configurations with reference values
- [ ] Calibration plots include ideal line (y=x) for reference
- [ ] Research notebook all cells executable, visualizations embedded
- [ ] SETUP.md, RUNBOOK.md, MODEL-CARD.md created with complete content

**Dependencies**: Phase 2 (XG-06), Phase 5 (FORECAST-05), Phase 6 (PIPELINE-01)

---

## Phase Dependency Graph

```
                    ┌─────────────────┐
                    │   Phase 1: Data  │
                    │  & Infrastructure│
                    └────────┬────────┘
                             │
              ┌──────────────┴──────────────┐
              │                             │
              ▼                             ▼
     ┌──────────────┐              ┌──────────────┐
     │ Phase 2: xG  │              │ Phase 3: Elo │
     │   Model      │              │  Ratings     │
     └──────┬───────┘              └──────┬───────┘
            │                             │
            └──────────────┬──────────────┘
                           │
                           ▼
                  ┌──────────────┐
                  │ Phase 4:     │
                  │ Integration  │
                  └──────┬───────┘
                         │
                         ▼
                  ┌──────────────┐
                  │ Phase 5:     │
                  │ Forecasting  │
                  └──────┬───────┘
                         │
                         ▼
                  ┌──────────────┐
                  │ Phase 6:     │
                  │ Pipeline &   │
                  │ Quality      │
                  └──────┬───────┘
                         │
                         ▼
                  ┌──────────────┐
                  │ Phase 7:     │
                  │ Visualization│
                  │ & Docs       │
                  └──────────────┘
```

---

## Requirement Coverage

| Phase | Requirements | Count | Status |
|-------|--------------|-------|--------|
| 1 | DATA-01, DATA-02, DATA-03, DATA-04, PIPELINE-02, PIPELINE-03 | 6 | Not Started |
| 2 | XG-01, XG-02, XG-03, XG-04, XG-05, XG-06 | 6 | Not Started |
| 3 | ELO-01, ELO-02, ELO-03, ELO-04 | 4 | Not Started |
| 4 | INTEGR-01, INTEGR-02 | 2 | Not Started |
| 5 | FORECAST-01, FORECAST-02, FORECAST-03, FORECAST-04, FORECAST-05 | 5 | Not Started |
| 6 | PIPELINE-01, TEST-01, TEST-02, TEST-03 | 4 | Not Started |
| 7 | VIS-01, VIS-02, DOC-01, DOC-02 | 4 | Not Started |
| **Total** | **All v1 Requirements** | **31** | **100% Coverage** |

---

## v2 Requirements (Deferred)

See REQUIREMENTS.md for v2 enhancements including mixed-effects xG, sequence-aware models, hybrid WCQ data layer, group stage simulation, and CI/CD pipeline.

---

## Milestone Definition

**v1 MVP (Open Mode)**: Completion of Phases 1-7 delivers a production-ready forecasting system using only open data (martj42 + StatsBomb). Forecasts generated for any WCQ-UEFA fixture with accurate probabilities.

---
*Generated: 2026-06-03 | Method: Derived from REQUIREMENTS.md and PROJECT.md*
