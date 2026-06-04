# Phase 6: Pipeline & Quality — PLAN

---
*Phase*: 6
*Name*: Pipeline & Quality
*Project*: xGelo — Free Elo + xG Forecasting for UEFA World Cup Qualifiers
*Status*: Ready for Execution
*Last Updated*: 2026-06-03
*Dependencies*: All previous phases (Phases 1-5)
---

## Phase Goal

Create a reproducible pipeline that orchestrates all xGelo components, implements data quality validation, and establishes a comprehensive test suite to ensure reliability and correctness.

## Task Breakdown

### Task 6.1: Implement targets pipeline with DAG (PIPELINE-01)
**Description**: Define all pipeline targets with explicit dependencies

**Sub-tasks**:
- Install and configure targets package
- Define target for each major output:
  - `tar_data_raw()`: Raw data files exist and are valid
  - `tar_data_clean()`: Cleaned/normalized data (Phase 1 outputs)
  - `tar_elo_ratings()`: Elo ratings (Phase 3)
  - `tar_xg_model()`: xG model (Phase 2)
  - `tar_team_match_xg()`: Team-match xG metrics (Phase 4)
  - `tar_rolling_form()`: Rolling form metrics (Phase 4)
  - `tar_forecast_models()`: Goal models (Phase 5)
  - `tar_forecasts()`: Generated forecasts (Phase 5)
  - `tar_reports()`: Visualizations and calibration (Phase 5)
- Set up dependency chain:
  ```r
  tar_elo_ratings depends on tar_data_clean
  tar_xg_model depends on tar_data_clean
  tar_team_match_xg depends on tar_data_raw, tar_xg_model
  tar_rolling_form depends on tar_team_match_xg, tar_elo_ratings
  tar_forecast_models depends on tar_rolling_form, tar_elo_ratings
  tar_forecasts depends on tar_forecast_models, tar_rolling_form
  tar_reports depends on tar_forecasts
  ```
- Generate DAG visualization with `targets::tar_visnetwork()`
- Save to `outputs/pipeline_dag.png`
- Save pipeline definition to `_targets.R`
- Add configuration: parallel workers, retry logic, error handling

**Dependencies**: All Phase 1-5 outputs must exist

**File Outputs**:
- `_targets.R`
- `outputs/pipeline_dag.png`
- `.Rprofile` (optional: pipeline configuration)

**Success Criteria**:
- [ ] All targets defined with correct dependencies
- [ ] DAG visualization generated and saved
- [ ] Pipeline runs without errors on first execution
- [ ] All target outputs match expected files

**Time Estimate**: 60 minutes

---

### Task 6.2: Unit tests for xG feature calculations (TEST-01)
**Description**: Create comprehensive unit tests for xG feature functions

**Sub-tasks**:
- Review `R/xg/features.R` for testable functions:
  - `calculate_distance()`
  - `calculate_angle()`
  - `extract_shot_features()`
- Write tests using testthat:
  ```r
  test_that("calculate_distance returns correct values", {
    expect_equal(calculate_distance(0, 0), 0)
    expect_equal(calculate_distance(10, 0), 10)
    expect_equal(calculate_distance(0, 10), 10)
    expect_equal(calculate_distance(10, 10), sqrt(200))
  })
  ```
- Test edge cases:
  - Zero distance
  - Maximum field dimensions (length ~105, width ~68)
  - Invalid inputs (NA, NULL)
- Test angle calculations:
  - Directly in front of goal (0 degrees)
  - From side of field (~45 degrees)
  - From corner (~90 degrees)
- Save to `tests/testthat/test_xg_features.R`

**Dependencies**: Phase 2 outputs, xG feature functions

**File Outputs**:
- `tests/testthat/test_xg_features.R`

**Success Criteria**:
- [ ] All xG feature functions have unit tests
- [ ] Tests cover normal cases and edge cases
- [ ] All tests pass
- [ ] >=80% code coverage for xG features

**Time Estimate**: 45 minutes

---

### Task 6.3: Unit tests for Elo calculation logic (TEST-02)
**Description**: Create comprehensive unit tests for Elo rating functions

**Sub-tasks**:
- Review `R/elo/runner.R` for testable functions:
  - `compute_elo()`
  - `update_ratings()`
  - Home advantage adjustment
- Write tests using testthat:
  ```r
  test_that("compute_elo handles basic win/loss", {
    # Team A beats Team B
    initial_ratings <- data.frame(team = c("A", "B"), rating = c(1500, 1500))
    result <- compute_elo(home = "A", away = "B", home_score = 1, away_score = 0, 
                          ratings = initial_ratings, k_factor = 20)
    expect_gt(result[result$team == "A", "rating"], 1500)
    expect_lt(result[result$team == "B", "rating"], 1500)
  })
  ```
- Test scenarios:
  - Win/draw/loss
  - Home advantage
  - Different k-factors
  - Rating decay
  - Multiple consecutive matches
- Save to `tests/testthat/test_elo.R`

**Dependencies**: Phase 3 outputs, Elo functions

**File Outputs**:
- `tests/testthat/test_elo.R`

**Success Criteria**:
- [ ] All Elo calculation functions have unit tests
- [ ] Tests cover normal cases and edge cases
- [ ] All tests pass
- [ ] >=80% code coverage for Elo functions

**Time Estimate**: 45 minutes

---

### Task 6.4: Integration test for full pipeline (TEST-03)
**Description**: Test the complete pipeline execution end-to-end

**Sub-tasks**:
- Create test script `tests/testthat/test_pipeline.R`
- Test 1: Pipeline completion
  ```r
  test_that("pipeline completes successfully", {
    tar_destroy()  # Clean slate
    expect_silent(tar_make())
    expect_true(all(tar_progress()$completed))
  })
  ```
- Test 2: Reproducibility
  ```r
  test_that("pipeline is reproducible", {
    # First run
    tar_destroy()
    tar_make()
    first_outputs <- file.mtime(tar_progress()$path[tar_progress()$completed])
    
    # Second run (should be cached, but verify outputs unchanged)
    tar_make()
    second_outputs <- file.mtime(tar_progress()$path[tar_progress()$completed])
    
    expect_identical(first_outputs, second_outputs)
  })
  ```
- Test 3: Data quality validation
  ```r
  test_that("data quality checks pass", {
    expect_true(validate_schema("data/processed/elo_ratings.csv"))
    expect_true(validate_xg_values("data/processed/team_match_xg.csv"))
    expect_true(validate_probabilities("outputs/forecasts/"))
  })
  ```
- Add validation helper functions to `R/pipeline/validation.R`
- Run all integration tests

**Dependencies**: Task 6.1 (pipeline), Tasks 6.2-6.3 (unit tests)

**File Outputs**:
- `tests/testthat/test_pipeline.R`
- `R/pipeline/validation.R`

**Success Criteria**:
- [ ] Pipeline completes without errors
- [ ] Reproducibility verified (outputs match between runs)
- [ ] All data quality checks pass
- [ ] All integration tests pass

**Time Estimate**: 60 minutes

---

## Dependency Graph

```
Task 6.1: Targets Pipeline
    │
    ├─── Task 6.2: xG Feature Tests
    │
    ├─── Task 6.3: Elo Tests
    │
    └─── Task 6.4: Integration Tests
```

**Parallelizable**: Tasks 6.2 and 6.3 can run in parallel (after 6.1)
**Critical Path**: 6.1 → 6.4 (180 min) OR 6.1 → 6.2 → 6.4 OR 6.1 → 6.3 → 6.4

**Total Time**: ~210 minutes (if parallel) or ~240 minutes (sequential)

---

## File Output Summary

| Task | Primary Output | Secondary Outputs |
|------|---------------|-------------------|
| 6.1 | `_targets.R` | `outputs/pipeline_dag.png` |
| 6.2 | `test_xg_features.R` | - |
| 6.3 | `test_elo.R` | - |
| 6.4 | `test_pipeline.R` | `R/pipeline/validation.R` |

---

## Success Criteria Alignment

| Requirement | Task | Success Criteria |
|-------------|------|------------------|
| PIPELINE-01 | 6.1 | DAG defined, visualization saved, pipeline runs |
| TEST-01 | 6.2 | xG feature tests, >=80% coverage, all pass |
| TEST-02 | 6.3 | Elo tests, >=80% coverage, all pass |
| TEST-03 | 6.4 | Integration tests, reproducibility verified |

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| targets package incompatible with existing code | Low | High | Test pipeline with small subset first, document all package versions |
| Test coverage below 80% | Medium | Medium | Focus tests on core functions, add helper functions as needed |
| Pipeline takes too long to run | Medium | Medium | Use caching, parallelize where possible, start with small dataset |
| Data quality issues in existing outputs | Medium | High | Add validation at each stage before proceeding, fix data issues in previous phases |
| Dependency conflicts between phases | Medium | High | Document all dependencies, test phase-by-phase integration first |

---

## Execution Notes

### Targets Pipeline Example
```r
# _targets.R
library(targets)
library(dplyr)

# Target: Raw data
list(
  tar_target(
    name = tar_data_raw,
    command = check_data_files(),
    pattern = map(data_raw)
  ),
  
  tar_target(
    name = tar_data_clean,
    command = process_data("data/raw", "data/processed"),
    pattern = map(data_clean),
    packages = "dplyr"
  ),
  
  tar_target(
    name = tar_elo_ratings,
    command = compute_elo_ratings("data/processed/results.csv"),
    pattern = "data/processed/elo_ratings.csv",
    packages = c("dplyr", "lubridate"),
    depends = tar_data_clean
  ),
  
  tar_target(
    name = tar_xg_model,
    command = train_xg_model(),
    pattern = "models/xg_model.rds",
    packages = c("MASS", "dplyr"),
    depends = tar_data_clean
  ),
  
  tar_target(
    name = tar_team_match_xg,
    command = compute_team_match_xg(),
    pattern = "data/processed/team_match_xg.csv",
    packages = c("dplyr", "jsonlite"),
    depends = c(tar_data_raw, tar_xg_model)
  ),
  
  tar_target(
    name = tar_rolling_form,
    command = compute_rolling_form(),
    pattern = "data/processed/rolling_form.csv",
    packages = "dplyr",
    depends = c(tar_team_match_xg, tar_elo_ratings)
  ),
  
  tar_target(
    name = tar_forecast_models,
    command = train_forecast_models(),
    pattern = map(models_forecast),
    packages = c("MASS", "dplyr"),
    depends = c(tar_rolling_form, tar_elo_ratings)
  ),
  
  tar_target(
    name = tar_forecasts,
    command = generate_forecasts(),
    pattern = "outputs/forecasts",
    packages = "dplyr",
    depends = tar_forecast_models
  )
)
```

### Testthat Example
```r
# test_xg_features.R
library(testthat)
library(xgelo)  # assuming package

context("xG Feature Calculations")

test_that("distance calculation works", {
  expect_equal(calculate_distance(0, 0), 0, tolerance = 0.001)
  expect_equal(calculate_distance(10, 0), 10, tolerance = 0.001)
  expect_equal(calculate_distance(0, 10), 10, tolerance = 0.001)
  expect_equal(calculate_distance(10, 10), sqrt(200), tolerance = 0.001)
})

test_that("angle calculation works", {
  expect_equal(calculate_angle(0, 0), 0, tolerance = 0.01)
  expect_equal(calculate_angle(10, 10), pi/4, tolerance = 0.01)
  expect_gt(calculate_angle(1, 10), 0)
  expect_lt(calculate_angle(1, 10), pi/2)
})
```

### Validation Functions
```r
# R/pipeline/validation.R
validate_schema <- function(path) {
  # Check file exists
  if (!file.exists(path)) return(FALSE)
  
  # Check required columns
  data <- read.csv(path)
  required_cols <- c("team", "date", "rating")  # example
  all(required_cols %in% names(data))
}

validate_xg_values <- function(path) {
  if (!file.exists(path)) return(FALSE)
  data <- read.csv(path)
  all(data$xGF >= 0 & data$xGF <= 10, na.rm = TRUE)
}

validate_probabilities <- function(dir) {
  files <- list.files(dir, pattern = "\\.csv$")
  all(sapply(files, function(f) {
    data <- read.csv(file.path(dir, f))
    abs(data$win_prob + data$draw_prob + data$loss_prob - 1) < 0.001
  }))
}
```

### DAG Visualization
```r
# Generate DAG visualization
library(targets)
library(visNetwork)

# After defining targets, generate visualization
tar_visnetwork(
  filename = "outputs/pipeline_dag.png",
  labels = TRUE,
  main = "xGelo Pipeline DAG"
)
```

---

## Nyquist Validation

```bash
# Check _targets.R exists
Rscript -e "stopifnot(file.exists('_targets.R')); print('_targets.R OK')"

# Check DAG visualization exists
Rscript -e "stopifnot(file.exists('outputs/pipeline_dag.png')); print('DAG visualization OK')"

# Check all test files exist
Rscript -e "stopifnot(all(file.exists(c('tests/testthat/test_xg_features.R', 'tests/testthat/test_elo.R', 'tests/testthat/test_pipeline.R')))); print('Test files OK')"

# Run all tests
Rscript -e "testthat::test_dir('tests/testthat'); print('All tests passed')"

# Check reproducibility
Rscript -e "
  tar_destroy()
  tar_make()
  first <- tar_progress()
  tar_make()
  second <- tar_progress()
  stopifnot(all(first$completed == second$completed))
  print('Reproducibility OK')
"
```

---

## Phase Acceptance Criteria

Phase 6 is complete when:
- [ ] All 4 tasks completed
- [ ] All success criteria met
- [ ] All unit tests pass (if created)
- [ ] All integration tests pass
- [ ] Pipeline runs end-to-end without errors
- [ ] Pipeline is reproducible (outputs match between runs)
- [ ] All data quality checks pass

---

## Rollback Strategy

- **targets package issues**: Fall back to make-based pipeline or custom script, document limitations
- **Test failures**: Debug and fix tests, ensure they test the right behavior
- **Reproducibility issues**: Check random seeds, data versioning, package versions
- **Data quality failures**: Fix validation logic or underlying data issues

---
*Plan locked: 2026-06-03 | Next: /gsd-execute-phase 6 or /gsd-plan-checker 6*
