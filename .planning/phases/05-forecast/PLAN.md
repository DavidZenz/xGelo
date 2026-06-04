# Phase 5: Forecasting Layer — PLAN

---
*Phase*: 5
*Name*: Forecasting Layer
*Project*: xGelo — Free Elo + xG Forecasting for UEFA World Cup Qualifiers
*Status*: Ready for Execution
*Last Updated*: 2026-06-03
*Dependencies*: Phase 4 (INTEGR-01, INTEGR-02 for rolling form metrics), Phase 3 (ELO-02 for Elo ratings)
---

## Phase Goal

Build goal models using Negative Binomial regression, implement Monte Carlo simulation, and generate win/draw/loss probabilities for UEFA World Cup Qualifier fixtures. This phase transforms integrated features into actionable predictions.

## Task Breakdown

### Task 5.1: Build Negative Binomial model for home goals (FORECAST-01)
**Description**: Train NB regression model to predict home team goals using integrated features

**Sub-tasks**:
- Load training data: historical fixtures with known results
- Compute features for each fixture:
  - `elo_diff`: Home Elo - Away Elo (with home advantage)
  - `xgf_ewma`: Home team's rolling xGF from Phase 4
  - `xga_ewma`: Home team's rolling xGA from Phase 4
  - `non_neutral_home`: TRUE if not at neutral venue
  - `rest_diff`: Days since last match (home - away)
- Handle missing feature values:
  - If xgf_ewma/xga_ewma missing (team has <6 matches), use Elo-only fallback
  - If rest_diff missing, use 0 (assume equal rest)
- Train NB model using `MASS::glm.nb`
- Validate model quality:
  - Check dispersion parameter theta > 0
  - AUC > 0.5 on validation set
  - Residual analysis: no patterns in residuals vs predicted
- Save model to `models/home_goal_model.rds`
- Save training script to `R/forecast/poisson.R`

**Dependencies**: Phase 4 (rolling_form.csv), Phase 3 (elo_ratings.csv)

**File Outputs**:
- `R/forecast/poisson.R`
- `models/home_goal_model.rds`

**Success Criteria**:
- [ ] Model achieves AUC > 0.5 on validation set
- [ ] Theta parameter > 0 (proper NB dispersion)
- [ ] All features have expected impact directions (elo_diff positive, xga_ewma negative)
- [ ] Model file saved and loadable

**Time Estimate**: 40 minutes

---

### Task 5.2: Build Negative Binomial model for away goals (FORECAST-02)
**Description**: Train NB regression model to predict away team goals using integrated features

**Sub-tasks**:
- Use same training data and features as Task 5.1
- Invert elo_diff for away perspective: `elo_diff_away = -elo_diff`
- Use away team's xgf_ewma and xga_ewma (from rolling_form.csv)
- Train NB model using `MASS::glm.nb`
- Validate model quality (same criteria as home model)
- Save model to `models/away_goal_model.rds`
- Update `R/forecast/poisson.R` with both models

**Dependencies**: Task 5.1 (feature computation logic), Phase 4, Phase 3

**File Outputs**:
- `R/forecast/poisson.R` (updated)
- `models/away_goal_model.rds`

**Success Criteria**:
- [ ] Model achieves AUC > 0.5 on validation set
- [ ] Theta parameter > 0
- [ ] Feature impacts: elo_diff negative (higher elo_diff means fewer away goals)
- [ ] Model file saved and loadable

**Time Estimate**: 30 minutes

---

### Task 5.3: Implement Monte Carlo simulation engine (FORECAST-03)
**Description**: Simulate 50,000 scenarios per fixture to compute outcome probabilities

**Sub-tasks**:
- Load home and away goal models from Tasks 5.1 and 5.2
- For each fixture:
  - Compute features (elo_diff, xgf_ewma, xga_ewma, non_neutral_home, rest_diff)
  - Predict lambda (mean) for home goals from home model
  - Predict lambda (mean) for away goals from away model
  - Set size parameter from model theta
- Implement simulation:
  - Use `rnbinom(n=50000, size=theta, prob=lambda/(lambda+theta))`
  - Vectorized implementation for speed
  - Set seed for reproducibility (e.g., `set.seed(fixture_id)`)
- Count outcomes:
  - win: home_goals > away_goals
  - draw: home_goals == away_goals
  - loss: home_goals < away_goals
- Compute probabilities:
  - P(win) = count(win) / 50000
  - P(draw) = count(draw) / 50000
  - P(loss) = count(loss) / 50000
- Verify P(win) + P(draw) + P(loss) = 1.0 ± 0.001
- Compute expected goals: mean(home_goals), mean(away_goals)
- Save to `R/forecast/monte_carlo.R`

**Dependencies**: Task 5.1, Task 5.2

**File Outputs**:
- `R/forecast/monte_carlo.R`

**Success Criteria**:
- [ ] Simulation completes in <10 seconds per fixture on M1/M2 Mac
- [ ] Probabilities sum to 1.0 ± 0.001
- [ ] Output is deterministic (same input → same output with same seed)
- [ ] Expected goals match model predictions (within 5%)

**Time Estimate**: 35 minutes

---

### Task 5.4: Generate win/draw/loss probabilities and expected goals (FORECAST-04)
**Description**: Production pipeline to generate forecasts for fixtures

**Sub-tasks**:
- Create forecast pipeline function:
  ```r
  forecast_fixture(home_team, away_team, date, venue = "home")
  ```
- Load required data:
  - Elo ratings for both teams (most recent before date)
  - Rolling form metrics for both teams (most recent before date)
  - Rest days for both teams
- Compute venue flag (home/away/neutral)
- Run Monte Carlo simulation (Task 5.3)
- Format output:
  - fixture_id, home_team, away_team, date, venue
  - home_goals_exp, away_goals_exp
  - win_prob, draw_prob, loss_prob
  - home_goals_median, home_goals_90th, away_goals_median, away_goals_90th
  - model_version, timestamp
- Save forecasts to `outputs/forecasts/{date}/{fixture_id}.csv`
- Create batch forecasting function for multiple fixtures
- Save to `R/forecast/output.R`

**Dependencies**: Task 5.3

**File Outputs**:
- `R/forecast/output.R`
- `outputs/forecasts/` (directory with forecast CSV files)

**Success Criteria**:
- [ ] Forecast output contains all required fields
- [ ] Batch forecasting processes 10 fixtures in <60 seconds
- [ ] Output files are properly named and organized
- [ ] Timestamp recorded for each forecast

**Time Estimate**: 25 minutes

---

### Task 5.5: Calibrate forecast model (FORECAST-05)
**Description**: Validate and calibrate forecast model performance

**Sub-tasks**:
- Collect historical fixtures with known results
- Run forecasts for all historical fixtures using models from Tasks 5.1-5.2
- Compare predictions to actuals:
  - Home goals predicted vs actual
  - Away goals predicted vs actual
- Compute metrics:
  - Brier score for win/draw/loss probabilities
  - Brier score decomposition (reliability, resolution, uncertainty)
  - AUC for goal prediction (home and away separately)
  - Mean absolute error for expected goals
- Calibrate draw probability:
  - If historical draw rate ≠ 28%, adjust model intercepts
  - Use Platt scaling: P'(draw) = a * P(draw) + b
  - Optimize a, b to minimize Brier score on validation set
- Generate calibration plot:
  - Actual frequency vs predicted probability (reliability diagram)
  - Ideal line (y=x) for reference
  - Save to `outputs/visualizations/forecast_calibration.png`
- Save calibration logic to `R/forecast/calibration.R`

**Dependencies**: Task 5.4

**File Outputs**:
- `R/forecast/calibration.R`
- `outputs/visualizations/forecast_calibration.png`

**Success Criteria**:
- [ ] Draw probability calibrated to ~28% (25-31% acceptable)
- [ ] Brier score < 0.25 on validation set
- [ ] Calibration plot shows good reliability (points close to diagonal)
- [ ] AUC > 0.60 for both home and away goal models

**Time Estimate**: 45 minutes

---

## Dependency Graph

```
Task 5.1: Home Goal Model
    │
    └─── Task 5.2: Away Goal Model
            │
            └─── Task 5.3: Monte Carlo Engine
                    │
                    └─── Task 5.4: Forecast Generation
                            │
                            └─── Task 5.5: Model Calibration
```

**Critical Path**: 5.1 → 5.2 → 5.3 → 5.4 → 5.5

**Total Sequential Time**: ~175 minutes (~3 hours)

---

## File Output Summary

| Task | Primary Output | Secondary Outputs |
|------|---------------|-------------------|
| 5.1 | `R/forecast/poisson.R` | `models/home_goal_model.rds` |
| 5.2 | `R/forecast/poisson.R` (updated) | `models/away_goal_model.rds` |
| 5.3 | `R/forecast/monte_carlo.R` | - |
| 5.4 | `R/forecast/output.R` | `outputs/forecasts/` |
| 5.5 | `R/forecast/calibration.R` | `outputs/visualizations/forecast_calibration.png` |

---

## Success Criteria Alignment

| Requirement | Task | Success Criteria |
|-------------|------|------------------|
| FORECAST-01 | 5.1 | Home goal NB model, AUC > 0.5, theta > 0 |
| FORECAST-02 | 5.2 | Away goal NB model, AUC > 0.5, theta > 0 |
| FORECAST-03 | 5.3 | Monte Carlo <10s/fixture, probabilities sum to 1.0 |
| FORECAST-04 | 5.4 | Forecast output with all fields, batch <60s for 10 fixtures |
| FORECAST-05 | 5.5 | Draw prob ~28%, Brier < 0.25, calibration plot |

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| NB model fails to converge | Medium | High | Use Poisson fallback, check for perfect separation, add regularization |
| Feature computation errors | Medium | High | Unit tests for each feature, validation checks, logging |
| Monte Carlo too slow | Low | High | Vectorize operations, use matrix operations, profile and optimize |
| Probabilities don't sum to 1.0 | Low | Medium | Add normalization step, verify with tests |
| Poor calibration (draw prob far from 28%) | Medium | Medium | Use Platt scaling, validate on multiple seasons, check data quality |
| Missing data for historical fixtures | High | Medium | Graceful degradation: use Elo-only if form metrics missing, impute rest_diff |
| Overfitting to training data | Medium | High | Use proper train/validation split, check performance on held-out data |

---

## Execution Notes

### Negative Binomial Model Training
```r
library(MASS)

# Home goal model
formula_home <- home_goals ~ elo_diff + xgf_ewma + xga_ewma + non_neutral_home + rest_diff
home_model <- glm.nb(formula_home, data = training_data, control = glm.control(maxit = 100))
summary(home_model)

# Check convergence
if (home_model$converged == FALSE) {
  # Fallback to Poisson
  home_model <- glm(formula_home, data = training_data, family = poisson)
  warning("NB failed to converge, using Poisson")
}

# Validate
predicted <- predict(home_model, type = "response")
# Check AUC using pROC or AUROC package
```

### Monte Carlo Implementation
```r
# Vectorized simulation
set.seed(fixture_id)
n_sim <- 50000

# Predict lambdas
home_lambda <- predict(home_model, newdata = fixture_features, type = "response")
away_lambda <- predict(away_model, newdata = fixture_features, type = "response")
home_theta <- home_model$theta
away_theta <- away_model$theta

# Vectorized simulation
home_goals <- rnbinom(n_sim, size = home_theta, prob = home_lambda / (home_lambda + home_theta))
away_goals <- rnbinom(n_sim, size = away_theta, prob = away_lambda / (away_lambda + away_theta))

# Compute outcomes
results <- data.frame(home = home_goals, away = away_goals)
results$outcome <- ifelse(results$home > results$away, "win", 
                         ifelse(results$home == results$away, "draw", "loss"))

# Compute probabilities
prob <- as.data.frame(table(results$outcome) / n_sim)
win_prob <- prob["win", "Freq"]
draw_prob <- prob["draw", "Freq"]
loss_prob <- prob["loss", "Freq"]

# Expected goals
expected_home <- mean(home_goals)
expected_away <- mean(away_goals)
```

### Feature Computation
```r
compute_fixture_features <- function(home_team, away_team, date, venue) {
  # Get Elo ratings (most recent before date)
  home_elo <- get_most_recent_elo(home_team, date)
  away_elo <- get_most_recent_elo(away_team, date)
  elo_diff <- home_elo - away_elo
  
  # Add home advantage (60 points for non-neutral)
  if (venue != "neutral") {
    home_elo <- home_elo + 60
  }
  elo_diff <- home_elo - away_elo
  
  # Get rolling form metrics (most recent before date)
  home_form <- get_most_recent_form(home_team, date)
  away_form <- get_most_recent_form(away_team, date)
  
  # Get rest days
  home_rest <- get_days_since_last(home_team, date)
  away_rest <- get_days_since_last(away_team, date)
  rest_diff <- home_rest - away_rest
  
  # Handle missing values
  if (is.na(home_form$xgf_ewma)) home_form$xgf_ewma <- 0
  if (is.na(away_form$xgf_ewma)) away_form$xgf_ewma <- 0
  
  # Venue flag
  non_neutral_home <- (venue != "neutral")
  
  return(data.frame(
    home_team = home_team,
    away_team = away_team,
    date = date,
    elo_diff = elo_diff,
    home_xgf_ewma = home_form$xgf_ewma,
    home_xga_ewma = home_form$xga_ewma,
    away_xgf_ewma = away_form$xgf_ewma,
    away_xga_ewma = away_form$xga_ewma,
    non_neutral_home = non_neutral_home,
    rest_diff = rest_diff
  ))
}
```

---

## Nyquist Validation

```bash
# Verify home goal model
Rscript -e "model <- readRDS('models/home_goal_model.rds'); stopifnot(!is.null(model)); stopifnot(model\$converged); print('home_goal_model.rds OK')"

# Verify away goal model
Rscript -e "model <- readRDS('models/away_goal_model.rds'); stopifnot(!is.null(model)); stopifnot(model\$converged); print('away_goal_model.rds OK')"

# Verify Monte Carlo speed
Rscript -e "source('R/forecast/monte_carlo.R'); start <- Sys.time(); simulate_fixture('test'); elapsed <- Sys.time() - start; stopifnot(elapsed < 10); print(paste('Monte Carlo speed OK:', elapsed, 'seconds'))"

# Verify probability sum
Rscript -e "source('R/forecast/monte_carlo.R'); probs <- simulate_fixture('test'); stopifnot(abs(probs\$win + probs\$draw + probs\$loss - 1) < 0.001); print('Probability sum OK')"

# Verify calibration
Rscript -e "source('R/forecast/calibration.R'); calibrate_model(); print('Calibration OK')"

# Run unit tests (if created)
Rscript -e "testthat::test_dir('tests/testthat/test_forecast.R')"
```

---

## Phase Acceptance Criteria

Phase 5 is complete when:
- [ ] All 5 tasks completed
- [ ] All success criteria met
- [ ] All unit tests pass (if created)
- [ ] All output files exist with expected content
- [ ] Monte Carlo simulation completes in <10 seconds
- [ ] Probabilities sum to 1.0 ± 0.001
- [ ] Draw probability calibrated to ~28%
- [ ] Brier score < 0.25 on validation set

---

## Rollback Strategy

- **NB model convergence failure**: Check for perfect separation, add L2 regularization, or fall back to Poisson
- **Monte Carlo too slow**: Profile code, vectorize operations, reduce scenarios or use approximation
- **Poor calibration**: Collect more training data, add/remove features, adjust calibration parameters
- **Feature computation errors**: Add validation checks, improve data quality, add error handling

---
*Plan locked: 2026-06-03 | Next: /gsd-execute-phase 5 or /gsd-plan-checker 5*
