# Phase 7: Visualization & Documentation — PLAN

---
*Phase*: 7
*Name*: Visualization & Documentation
*Project*: xGelo — Free Elo + xG Forecasting for UEFA World Cup Qualifiers
*Status*: Ready for Execution
*Last Updated*: 2026-06-04
*Dependencies*: All previous phases (Phases 1-6)
---

## Phase Goal

Create visual proofs of model performance (AUC comparison, calibration plots) and comprehensive documentation (research notebook, setup guide, runbook, model card) to enable users to understand, validate, and use the forecasting system.

## Task Breakdown

### Task 7.1: Create AUC comparison chart (VIS-01)
**Description**: Generate chart comparing AUC across 4 feature configurations

**Sub-tasks**:
- Load performance metrics from Phase 2 (xG model AUC: 0.7905) and Phase 5 (forecast models)
- Define 4 feature configurations:
  - Config 1: Elo only (baseline)
  - Config 2: Elo + xG form metrics
  - Config 3: Elo + xG form + rest days
  - Config 4: Full model (all features from Phase 5)
- Create bar chart with error bars (if bootstrap CI available)
- Add reference line at AUC = 0.75 (minimum acceptable)
- Save to `outputs/visualizations/auc_comparison.png`
- Create R script `R/visualization/auc.R`

**Dependencies**: Phase 2 (xG model AUC), Phase 5 (forecast model performance)

**File Outputs**:
- `R/visualization/auc.R`
- `outputs/visualizations/auc_comparison.png`

**Success Criteria**:
- [ ] Chart shows 4 configurations with clear labels
- [ ] Reference values match Phase 2 and 5 results
- [ ] Chart is publication-quality (high resolution, readable)
- [ ] AUC > 0.75 for all configurations

**Time Estimate**: 30 minutes

---

### Task 7.2: Generate calibration plots (VIS-02)
**Description**: Create reliability diagrams for xG and forecast models

**Sub-tasks**:
- Load xG model from `models/xg_model.rds`
- Load forecast models from `models/home_goal_model.rds`, `models/away_goal_model.rds`
- Generate calibration data:
  - For xG: Group shots by predicted xG bins (0-0.1, 0.1-0.2, ..., 0.9-1.0), compute actual goal rate
  - For forecast: Group fixtures by predicted win/draw/loss probabilities, compute actual rate
- Create reliability diagrams with:
  - X-axis: Predicted probability
  - Y-axis: Actual frequency
  - Diagonal line (y=x) for perfect calibration
  - Points for each bin with error bars
- Save to:
  - `outputs/visualizations/xg_calibration.png` (xG model calibration - already exists)
  - `outputs/visualizations/forecast_calibration.png` (forecast model - already exists)
- Update/create `R/visualization/calibration.R`

**Dependencies**: Phase 2 (xG model), Phase 5 (forecast models)

**File Outputs**:
- `R/visualization/calibration.R`
- `outputs/visualizations/xg_calibration.png` (verify/update)
- `outputs/visualizations/forecast_calibration.png` (verify/update)

**Success Criteria**:
- [ ] Both calibration plots generated
- [ ] Ideal line (y=x) included for reference
- [ ] Points are close to diagonal (good calibration)
- [ ] Bins have sufficient data points

**Time Estimate**: 40 minutes

---

### Task 7.3: Create reproducible research notebook (DOC-01)
**Description**: Build end-to-end R Markdown notebook demonstrating the system

**Sub-tasks**:
- Create `notebooks/model_performance.Rmd`
- Structure notebook with sections:
  1. **Setup**: Load libraries, set paths
  2. **Data**: Load raw data from Phase 1
  3. **xG Model**: Train and evaluate xG model (Phase 2)
  4. **Elo System**: Compute and validate Elo ratings (Phase 3)
  5. **Integration**: Generate team-match xG and rolling form (Phase 4)
  6. **Forecasting**: Train models and generate predictions (Phase 5)
  7. **Pipeline**: Run validation and tests (Phase 6)
  8. **Visualization**: Generate all plots (Phase 7)
- Each section should:
  - Explain what it does
  - Show code
  - Display results/visualizations
  - Include key metrics
- Add YAML header with title, author, date, output format
- Render notebook to HTML: `outputs/notebooks/model_performance.html`

**Dependencies**: All previous phases

**File Outputs**:
- `notebooks/model_performance.Rmd`
- `outputs/notebooks/model_performance.html`

**Success Criteria**:
- [ ] All code chunks execute without errors
- [ ] All visualizations render correctly
- [ ] Notebook runs end-to-end in <5 minutes
- [ ] All key metrics displayed

**Time Estimate**: 60 minutes

---

### Task 7.4: Create technical documentation (DOC-02)
**Description**: Write SETUP.md, RUNBOOK.md, and MODEL-CARD.md

**Sub-tasks**:

#### SETUP.md
- **Purpose**: Guide for setting up the development environment
- **Content**:
  - Project structure overview
  - R version requirements (>= 4.3.0)
  - Package dependencies with `renv` or `packrat` lockfile
  - Data setup instructions (where to place raw data)
  - Installation commands
  - Environment configuration

#### RUNBOOK.md
- **Purpose**: Guide for running the pipeline and generating forecasts
- **Content**:
  - How to run individual phases
  - How to run full pipeline
  - How to generate forecasts for new fixtures
  - How to update data
  - Expected outputs and where to find them
  - Troubleshooting common issues

#### MODEL-CARD.md
- **Purpose**: Document model specifications and performance
- **Content**:
  - Model type: Logistic regression for xG, NB regression for goals
  - Features: distance, angle, header, open_play, competition (xG); elo_diff, xgf_ewma, xga_ewma, non_neutral_home, rest_diff (forecast)
  - Training data: StatsBomb events (xG), martj42 results (forecast)
  - Performance metrics: AUC = 0.7905 (xG), Brier score < 0.25 (forecast)
  - Limitations: Domestic leagues only for xG, historical data coverage
  - License: Open data sources only
  - Intended use: UEFA World Cup Qualifier forecasting

**Dependencies**: All previous phases for accurate model documentation

**File Outputs**:
- `SETUP.md`
- `RUNBOOK.md`
- `MODEL-CARD.md`

**Success Criteria**:
- [ ] All 3 documents created with complete content
- [ ] Information is accurate and up-to-date
- [ ] Examples are clear and actionable
- [ ] Formatting is consistent

**Time Estimate**: 45 minutes

---

## Dependency Graph

```
Task 7.1: AUC Comparison Chart
    │
    ├─── Task 7.2: Calibration Plots
    │
    └─── Task 7.3: Research Notebook
            │
            └─── Task 7.4: Technical Documentation
```

**Parallelizable**: Tasks 7.1 and 7.2 can run in parallel
**Critical Path**: 7.3 → 7.4 (105 min) OR 7.1 → 7.4 OR 7.2 → 7.4

**Total Time**: ~75 minutes (parallel) or ~175 minutes (sequential)

---

## File Output Summary

| Task | Primary Output | Secondary Outputs |
|------|---------------|-------------------|
| 7.1 | `R/visualization/auc.R` | `outputs/visualizations/auc_comparison.png` |
| 7.2 | `R/visualization/calibration.R` | xg_calibration.png, forecast_calibration.png |
| 7.3 | `notebooks/model_performance.Rmd` | `outputs/notebooks/model_performance.html` |
| 7.4 | `SETUP.md`, `RUNBOOK.md`, `MODEL-CARD.md` | - |

---

## Success Criteria Alignment

| Requirement | Task | Success Criteria |
|-------------|------|------------------|
| VIS-01 | 7.1 | AUC chart with 4 configurations, publication-quality |
| VIS-02 | 7.2 | Calibration plots with ideal line, good calibration |
| DOC-01 | 7.3 | Executable notebook with all phases, renders correctly |
| DOC-02 | 7.4 | 3 documentation files with accurate content |

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| AUC values not available for all configs | Medium | Medium | Use Phase 2 and 5 results, estimate others |
| Calibration data insufficient | Medium | Medium | Use broader bins, combine sparse bins |
| Notebook takes too long | Medium | Medium | Cache intermediate results, use smaller samples for demo |
| Documentation becomes outdated | High | Medium | Review and update before finalizing |
| Visualizations not publication-quality | Low | Medium | Use consistent theme, high DPI, manual review |

---

## Execution Notes

### AUC Chart Implementation
```r
library(ggplot2)

# Example data
configs <- data.frame(
  configuration = c("Elo only", "Elo + xG form", "Elo + xG + rest", "Full model"),
  auc = c(0.75, 0.78, 0.79, 0.82),  # Example values
  lower = c(0.73, 0.76, 0.77, 0.80),
  upper = c(0.77, 0.80, 0.81, 0.84)
)

p <- ggplot(configs, aes(x = configuration, y = auc, fill = configuration)) +
  geom_bar(stat = "identity") +
  geom_errorbar(aes(ymin = lower, ymax = upper), width = 0.2) +
  geom_hline(yintercept = 0.75, linetype = "dashed", color = "red") +
  labs(title = "Model Performance by Feature Configuration",
       x = "Feature Configuration", y = "AUC") +
  theme_minimal()

ggsave("outputs/visualizations/auc_comparison.png", p, width = 10, height = 6, dpi = 300)
```

### Calibration Plot Implementation
```r
library(ggplot2)

# Example calibration data
calib_data <- data.frame(
  predicted = seq(0.1, 0.9, by = 0.1),
  actual = seq(0.1, 0.9, by = 0.1) + rnorm(9, 0, 0.02)  # Slight deviation
)

p <- ggplot(calib_data, aes(x = predicted, y = actual)) +
  geom_point(size = 3) +
  geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "red") +
  geom_errorbar(aes(ymin = actual - 0.05, ymax = actual + 0.05), width = 0.05) +
  labs(title = "Forecast Model Calibration",
       x = "Predicted Probability", y = "Actual Frequency") +
  theme_minimal()

ggsave("outputs/visualizations/forecast_calibration.png", p, width = 8, height = 8, dpi = 300)
```

### Notebook Template
```markdown
---
title: "xGelo Model Performance"
author: "xGelo Project"
date: "`r Sys.Date()`"
output: html_document
---

```{r setup, include=FALSE}
knitr::opts_chunk$set(echo = TRUE, message = FALSE, warning = FALSE)
library(tidyverse)
library(tidymodels)
```

## 1. Setup
Project structure and configuration.

## 2. Data Loading
Load raw data from Phase 1.

## 3. xG Model (Phase 2)
Train and evaluate xG model.

## 4. Elo System (Phase 3)
Compute and validate Elo ratings.

## 5. Integration (Phase 4)
Generate team-match xG and rolling form.

## 6. Forecasting (Phase 5)
Train models and generate predictions.

## 7. Pipeline (Phase 6)
Run validation and tests.

## 8. Visualization (Phase 7)
Generate all plots.
```

### Model Card Template
```markdown
# xGelo Model Card

## Model Details
- **Model Type**: Logistic Regression (xG), Negative Binomial (goals)
- **Version**: 1.0
- **License**: MIT

## Intended Use
- **Primary**: UEFA World Cup Qualifier match forecasting
- **Secondary**: Domestic league match forecasting (xG only)

## Performance Metrics
- **xG Model AUC**: 0.7905
- **Forecast Brier Score**: < 0.25
- **Draw Probability**: ~28% (calibrated)

## Training Data
- **xG Model**: StatsBomb Open Data events
- **Forecast Models**: martj42 international results
- **Date Range**: 1872-present
- **Matches**: 49,368 (Elo), domestic league shots (xG)

## Features
### xG Model
- distance: Shot distance from goal (yards)
- angle: Shot angle to goal (radians)
- header: Is header shot (logical)
- open_play: Is open play (logical)
- competition: Competition name (factor)

### Forecast Models
- elo_diff: Elo rating difference (home - away)
- xgf_ewma: Home team xG For EWMA
- xga_ewma: Home team xG Against EWMA
- non_neutral_home: Non-neutral venue (logical)
- rest_diff: Rest days difference (home - away)

## Limitations
- xG model trained on domestic leagues only
- Forecast models use historical international data
- No live data support (pre-match only)
- Assumes standard pitch dimensions (StatsBomb: 120x80 yards)
```

---

## Nyquist Validation

```bash
# Verify visualization files
Rscript -e "stopifnot(file.exists('outputs/visualizations/auc_comparison.png'))"
Rscript -e "stopifnot(file.exists('outputs/visualizations/xg_calibration.png'))"
Rscript -e "stopifnot(file.exists('outputs/visualizations/forecast_calibration.png'))"

# Verify documentation files
Rscript -e "stopifnot(file.exists('SETUP.md'))"
Rscript -e "stopifnot(file.exists('RUNBOOK.md'))"
Rscript -e "stopifnot(file.exists('MODEL-CARD.md'))"

# Verify notebook
Rscript -e "stopifnot(file.exists('notebooks/model_performance.Rmd'))"
Rscript -e "stopifnot(file.exists('outputs/notebooks/model_performance.html'))"

# Verify notebook runs
Rscript -e "rmarkdown::render('notebooks/model_performance.Rmd', output_dir = 'outputs/notebooks')"
```

---

## Phase Acceptance Criteria

Phase 7 is complete when:
- [ ] All 4 tasks completed
- [ ] All success criteria met
- [ ] All visualizations generated and reviewed
- [ ] Notebook runs end-to-end without errors
- [ ] All documentation files created and reviewed

---

## Rollback Strategy

- **AUC values missing**: Use estimated values, document as "estimated"
- **Calibration data sparse**: Combine bins, use larger intervals
- **Notebook errors**: Debug and fix individual chunks, cache intermediate results
- **Documentation outdated**: Update with current phase outputs before finalizing

---
*Plan locked: 2026-06-04 | Next: /gsd-execute-phase 7 or /gsd-plan-checker 7*
