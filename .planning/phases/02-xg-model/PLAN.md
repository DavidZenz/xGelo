# Phase 2: xG Model Development — PLAN

---
*Phase*: 2
*Name*: xG Model Development
*Project*: xGelo — Free Elo + xG Forecasting for UEFA World Cup Qualifiers
*Status*: Ready for Execution
*Last Updated*: 2026-06-03
*Dependencies*: Phase 1 (DATA-03 for StatsBomb training data)
*Parallelizable*: Yes (with Phase 3)

---

## Phase Goal

Train a production-ready xG model on StatsBomb Open Data using minimal, interpretable features (distance, angle, header, open_play, competition) achieving **AUC ≥ 0.75** on held-out domestic league test set.

---

## Task Breakdown

### Task 2.1: Implement coordinate system calculations (XG-01, XG-02)
**Description**: Create `calculate_distance()` and `calculate_angle()` functions using StatsBomb coordinate system

**Sub-tasks**:
- Create `R/xg/features.R` with coordinate system constants (pitch 120x80, goal at x=120, posts at y=36.34/43.66)
- Implement `calculate_distance(x, y)` using Euclidean distance to goal center (120, 40)
- Implement `calculate_angle(x, y)` using law of cosines with goalposts 7.32 yards apart
- Add unit tests in `tests/testthat/test_xg_features.R` with known values:
  - Distance from penalty spot (108, 40) should be 12 yards (to goal center at 120,40)
  - Distance from center spot (60, 40) should be 60 yards (to goal center at 120,40)
  - Angle at center spot (60, 40) should be π/2 (90 degrees)
  - Angle at penalty spot (108, 40) should be small

**Dependencies**: None (within Phase 2)

**File Outputs**:
- `R/xg/features.R`
- `tests/testthat/test_xg_features.R`

**Success Criteria**:
- [ ] `calculate_distance()` passes all unit tests with known values
- [ ] `calculate_angle()` passes all unit tests with known values
- [ ] Both functions return numeric vectors of same length as input
- [ ] Distance values ∈ [0, ~130] (max distance on 120x80 pitch)
- [ ] Angle values ∈ [0, π] radians

**Time Estimate**: 20 minutes

---

### Task 2.2: Implement full feature contract (XG-03)
**Description**: Build complete xG feature extraction from StatsBomb shot events

**Sub-tasks**:
- In `R/xg/features.R`, add:
  - `extract_shot_features(event)` to extract features from a single shot event
  - `extract_features_from_events(events_df)` to process a data frame of events
  - Feature: `header` = (event$shot$body_part == "Head")
  - Feature: `open_play` = (event$play_pattern$name == "Regular Play")
  - Feature: `competition` = extract from match context
- Add validation: return NA for missing/invalid shot events
- Exclude penalty shots: filter out events where event$type$name == "Penalty"
- Add unit tests for all feature extractions

**Dependencies**: Task 2.1

**File Outputs**:
- `R/xg/features.R` (updated)
- `tests/testthat/test_xg_features.R` (updated)

**Success Criteria**:
- [ ] All 5 features (distance, angle, header, open_play, competition) extracted correctly
- [ ] Feature ranges valid: distance ∈ [0, ~130], angle ∈ [0, π], header ∈ {TRUE, FALSE}, open_play ∈ {TRUE, FALSE}
- [ ] All unit tests pass
- [ ] Penalty shots excluded from output

**Time Estimate**: 25 minutes

---

### Task 2.3: Prepare training data (XG-03, XG-04)
**Description**: Load StatsBomb events, extract shots, apply feature contract, create model-ready dataset

**Sub-tasks**:
- Load `data/raw/statsbomb/competitions.json` to identify domestic leagues
- Filter competitions to **domestic leagues only** (exclude World Cup, Euros, Qualifiers, Nations League)
- Load all StatsBomb events files from `data/raw/statsbomb/events/`
- Extract all shot events (type$name == "Shot")
- Apply feature extraction from Task 2.2
- Filter out penalty shots (type$name == "Penalty")
- Add outcome column: `goal` = (shot$outcome$name == "Goal")
- Split into train/test by season (older seasons = train, most recent = test)
- Validate data quality: check for NA coordinates, out-of-bounds values (x ∈ [0,120], y ∈ [0,80])
- Save processed data to `data/processed/xg_training_data.rds`

**Dependencies**: Task 2.2

**File Outputs**:
- `R/xg/data_prep.R`
- `data/processed/xg_training_data.rds`

**Success Criteria**:
- [ ] Training data contains all required features (distance, angle, header, open_play, competition, goal)
- [ ] Test set is temporal (most recent season only)
- [ ] No data leakage: train and test have disjoint match IDs
- [ ] Data saved as RDS with proper column types
- [ ] Data quality validated: no NA coordinates, all x ∈ [0,120], y ∈ [0,80]

**Time Estimate**: 30 minutes

---

### Task 2.4: Train xG model (XG-04)
**Description**: Train logistic regression model with natural splines using tidymodels

**Sub-tasks**:
- Create `R/xg/model.R` with:
  - Recipe: `recipe(goal ~ distance + angle + header + open_play + competition, data = train_data)`
  - Preprocessing: `step_ns(distance, deg_free = 4)` + `step_ns(angle, deg_free = 4)` + `step_dummy(all_nominal_predictors(), -all_outcomes())` + `step_zv(all_predictors())`
  - Model: `logistic_reg()`
  - Workflow: `workflow() %>% add_recipe(recipe) %>% add_model(model)`
  - Fit on training data
  - Save fitted workflow to `models/xg_model.rds`
- Create prediction function: `predict_xg(model, new_data)` that returns predicted probabilities

**Dependencies**: Task 2.3

**File Outputs**:
- `R/xg/model.R`
- `models/xg_model.rds`

**Success Criteria**:
- [ ] Model trained using tidymodels with natural splines
- [ ] Model saved to `models/xg_model.rds`
- [ ] `predict_xg()` function works on new data

**Time Estimate**: 25 minutes

---

### Task 2.5: Calibrate model (XG-05)
**Description**: Calibrate model probabilities and generate calibration plot

**Sub-tasks**:
- Create `R/xg/calibration.R`
- Use test set predictions to assess calibration
- Apply isotonic regression: `calibrate::calibrate(predictions ~ predicted, data = test_preds, method = "isotonic")`
- Calculate observed vs predicted by 10 bins (0-0.1, 0.1-0.2, ..., 0.9-1.0)
- Check calibration: all bins within ±5% difference
- Generate calibration plot using ggplot2:
  - X-axis: predicted probability bins
  - Y-axis: observed goal rate
  - Perfect calibration line (y = x)
  - Save to `outputs/visualizations/xg_calibration.png`
- If miscalibrated >5% in any bin, apply calibration transformation and re-evaluate
- Save calibrated model to `models/xg_model_calibrated.rds`

**Dependencies**: Task 2.4

**File Outputs**:
- `R/xg/calibration.R`
- `outputs/visualizations/xg_calibration.png`

**Success Criteria**:
- [ ] Calibration curve shows predicted vs observed within ±5% per bin
- [ ] Calibration plot saved and visually confirms good calibration
- [ ] Calibration transformation applied if needed

**Time Estimate**: 20 minutes

---

### Task 2.6: Backtest model performance (XG-06)
**Description**: Evaluate model performance on held-out test set

**Sub-tasks**:
- Create `R/xg/backtest.R`
- Compute predictions on test set
- Calculate metrics:
  - AUC using `pROC::auc()` or `yardstick::roc_auc()`
  - Accuracy: (TP + TN) / (P + N)
  - Brier score: mean((predicted - goal)^2)
- Group performance by competition and season
- Also report separate metrics for international tournaments (if any in test set)
- Generate ROC curve visualization
- Save results to `outputs/model_performance/xg_backtest.csv` with columns:
  - competition, season, n_shots, n_goals, auc, accuracy, brier_score, data_type (domestic/international)
- Verify **AUC ≥ 0.75** on domestic league test set

**Dependencies**: Task 2.4, Task 2.5

**File Outputs**:
- `R/xg/backtest.R`
- `outputs/model_performance/xg_backtest.csv`
- `outputs/visualizations/xg_roc_curve.png`

**Success Criteria**:
- [ ] AUC ≥ 0.75 on held-out domestic league test set
- [ ] Performance metrics reported by competition and season
- [ ] ROC curve and backtest CSV saved
- [ ] All files created in specified locations

**Time Estimate**: 20 minutes

---

## Dependency Graph

```
Task 2.1: Coordinate System Calculations
    │
    └─── Task 2.2: Feature Contract Implementation
            │
            └─── Task 2.3: Training Data Preparation
                    │
                    └─── Task 2.4: Model Training
                            │
                            ├─── Task 2.5: Calibration
                            │        │
                            │        └─── Task 2.6: Backtest
                            │
                            └─── Task 2.6: Backtest (also depends on 2.5)
```

**Critical Path**: 2.1 → 2.2 → 2.3 → 2.4 → 2.5 → 2.6

**Total Sequential Time**: ~140 minutes (~2.3 hours)

---

## File Output Summary

| Task | Primary Output | Secondary Outputs |
|------|---------------|-------------------|
| 2.1 | `R/xg/features.R` | `tests/testthat/test_xg_features.R` |
| 2.2 | `R/xg/features.R` (updated) | `tests/testthat/test_xg_features.R` (updated) |
| 2.3 | `R/xg/data_prep.R` | `data/processed/xg_training_data.rds` |
| 2.4 | `models/xg_model.rds` | `R/xg/model.R` |
| 2.5 | `outputs/visualizations/xg_calibration.png` | `R/xg/calibration.R` |
| 2.6 | `outputs/model_performance/xg_backtest.csv` | `R/xg/backtest.R`, `outputs/visualizations/xg_roc_curve.png` |

---

## Success Criteria Alignment

| Requirement | Task | Success Criteria |
|-------------|------|------------------|
| XG-01 | 2.1 | `calculate_distance()` returns correct Euclidean distance to goal center |
| XG-02 | 2.1 | `calculate_angle()` returns correct angle in radians [0, π] |
| XG-03 | 2.2 | All 5 features (distance, angle, header, open_play, competition) extracted |
| XG-04 | 2.4 | Model trained using tidymodels with natural splines, saved to `models/xg_model.rds` |
| XG-05 | 2.5 | Calibration curve shows predicted vs observed within ±5% per bin, plot saved |
| XG-06 | 2.6 | AUC ≥ 0.75 on test set, performance by competition/season saved to CSV |

---

## Execution Notes

### StatsBomb Coordinate System
```r
# Constants for StatsBomb pitch
PITCH_LENGTH <- 120  # yards
PITCH_WIDTH <- 80   # yards
GOAL_CENTER_X <- 120
GOAL_CENTER_Y <- 40
GOAL_POST_Y1 <- 36.34
GOAL_POST_Y2 <- 43.66
GOAL_WIDTH <- 7.32  # yards (8 yards - 2 * 0.33 for post width)

# Distance calculation
calculate_distance <- function(x, y) {
  sqrt((GOAL_CENTER_X - x)^2 + (GOAL_CENTER_Y - y)^2)
}

# Angle calculation using law of cosines
calculate_angle <- function(x, y) {
  a <- sqrt((GOAL_CENTER_X - x)^2 + (GOAL_POST_Y1 - y)^2)
  b <- sqrt((GOAL_CENTER_X - x)^2 + (GOAL_POST_Y2 - y)^2)
  c <- GOAL_WIDTH
  acos(pmax(-1, pmin(1, (a^2 + b^2 - c^2) / (2 * a * b))))
}
```

### Feature Extraction from StatsBomb Events
```r
# Shot event structure:
event$type$name == "Shot"
event$shot$outcome$name == "Goal"  # or "Saved", "Wayward", etc.
event$shot$body_part$name == "Head"  # or "Right Foot", "Left Foot", etc.
event$play_pattern$name == "Regular Play"  # or "From Corner", "From Free Kick", etc.
event$location <- list(x = x_coord, y = y_coord)  # coordinates
```

### Model Specification
```r
library(tidymodels)

recipe_spec <- recipe(goal ~ distance + angle + header + open_play + competition, 
                      data = train_data) |
  step_ns(distance, deg_free = 4) |
  step_ns(angle, deg_free = 4) |
  step_dummy(all_nominal_predictors(), -all_outcomes()) |
  step_zv(all_predictors())  # remove zero-variance

model_spec <- logistic_reg() |>
  set_engine("glm") |>
  set_mode("regression")

xg_workflow <- workflow() |>
  add_recipe(recipe_spec) |>
  add_model(model_spec)

xg_fit <- fit(xg_workflow, data = train_data)
```

### Train/Test Split
```r
# Season-based split
seasons <- unique(train_data$season)
train_seasons <- head(sort(seasons), -1)  # all but most recent
test_seasons <- tail(sort(seasons), 1)    # most recent only

train_data <- train_data %>% filter(season %in% train_seasons)
test_data <- train_data %>% filter(season %in% test_seasons)
```

---

## Required Packages

The following R packages are required for this phase:
- `tidymodels` - Model specification and fitting
- `recipes` - Preprocessing recipes
- `yardstick` - Model metrics (AUC, accuracy, Brier score)
- `pROC` - ROC curve and AUC calculation (alternative to yardstick)
- `calibrate` - Isotonic regression for calibration
- `ggplot2` - Visualizations
- `dplyr` - Data manipulation
- `jsonlite` - JSON parsing
- `testthat` - Unit testing

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Insufficient training data | Medium | High | Use all available domestic league data; minimum 10,000 shots required |
| Model doesn't reach AUC 0.75 | Low | High | Add competition feature, verify data quality, check feature ranges |
| Data leakage | Medium | High | Use temporal split (season-based), verify disjoint match IDs |
| Spline overfitting | Medium | Medium | Use deg_free=4, monitor with cross-validation |
| Missing required packages | Low | Medium | Document dependencies in DESCRIPTION/renv.lock |

---

## Parallel Execution Notes

This phase can run **in parallel with Phase 3 (Elo Rating System)** as they have no dependencies on each other. Both Phase 2 and Phase 3 depend only on Phase 1 (Data Ingestion).

---

## Rollback Strategy

- Failed feature tests: Fix calculation logic, re-run tests
- Model training fails: Check data quality, verify feature ranges
- Calibration fails: Adjust calibration method (try "sigmoid" instead of "isotonic")
- Backtest fails: Verify test set is truly held-out, check metric calculations

---

## Nyquist Validation

```bash
# Run unit tests
Rscript -e "testthat::test_dir('tests/testthat')"

# Validate model exists and loads
Rscript -e "xg_model <- readRDS('models/xg_model.rds'); print(summary(xg_model))"

# Check backtest results
Rscript -e "backtest <- read.csv('outputs/model_performance/xg_backtest.csv'); print(backtest); stopifnot(backtest[1, 'auc'] >= 0.75)"
```

---

## Phase Acceptance Criteria

Phase 2 is complete when:
- [ ] All 6 tasks completed
- [ ] All success criteria met
- [ ] All unit tests pass
- [ ] Model achieves AUC ≥ 0.75 on held-out test set
- [ ] Calibration within ±5% per bin
- [ ] All output files exist in specified locations

---
*Plan locked: 2026-06-03 | Next: /gsd-verify-work 2 or /gsd-execute-phase 2*

---

## PLAN SUMMARY

**PLAN CREATED** ✓

- **6 tasks** defined
- **1 dependency chain** (sequential)
- **14 file outputs** specified
- **All Phase 2 requirements covered** (XG-01, XG-02, XG-03, XG-04, XG-05, XG-06)
- **Total Time Estimate**: ~140 minutes (~2.3 hours)
- **Parallelizable**: Yes (with Phase 3)
