# Phase 3: Elo Rating System — PLAN

---
*Phase*: 3
*Name*: Elo Rating System
*Project*: xGelo — Free Elo + xG Forecasting for UEFA World Cup Qualifiers
*Status*: Ready for Execution
*Last Updated*: 2026-06-03
*Dependencies*: Phase 1 (DATA-01, DATA-02 for martj42 results data)
*Parallelizable*: Yes (with Phase 2)

---

## Phase Goal

Implement a custom Elo rating system for international football using martj42 historical results, with configurable k-factor, home advantage, and rating decay. Compute ratings for all teams from 1872-present and tune via rolling-origin validation.

---

## Task Breakdown

### Task 3.1: Implement Elo calculation function (ELO-01)
**Description**: Create `compute_elo()` pure function with standard Elo formula and adjustments

**Sub-tasks**:
- In `R/elo/runner.R`, implement:
  - `expected_result(rating_a, rating_b)` - Compute expected score for team A
  - `elo_update(rating_a, rating_b, actual_result, k_factor_a, k_factor_b, home_advantage)` - Compute new ratings
  - `compute_elo()` - Main function that orchestrates rating updates
- Handle edge cases: new teams (base rating = 1500), missing ratings
- Add input validation: ratings must be numeric, actual_result must be in {0, 0.5, 1}
- Add unit tests in `tests/testthat/test_elo.R`:
  - Expected result for equal ratings (0.5)
  - Expected result for 100-point difference
  - Rating update for win/draw/loss
  - Home advantage adjustment

**Dependencies**: None (within Phase 3)

**File Outputs**:
- `R/elo/runner.R`
- `tests/testthat/test_elo.R`

**Success Criteria**:
- [ ] `compute_elo()` is pure function with configurable k-factor and home advantage
- [ ] All unit tests pass
- [ ] Expected result formula: `1 / (1 + 10^((R_b - R_a) / 400))` implemented correctly
- [ ] Rating update formula: `R_new = R_old + K * (actual - expected)` implemented correctly

**Time Estimate**: 20 minutes

---

### Task 3.2: Preprocess martj42 results (ELO-02)
**Description**: Load and prepare martj42 results for Elo computation

**Sub-tasks**:
- Load `data/raw/martj42/results.csv`
- Map team names to canonical names using `data/raw/team_name_map.csv`
- Map team names to FIFA codes for consistent identification
- Add result column: `result` = 1 (home win), 0.5 (draw), 0 (away win)
- Sort by date chronologically (oldest first)
- Add match identifier column for tracking: `match_id` = paste(home_team, away_team, date)
- Add days_since_last_match for each team (for decay calculation)
- Save preprocessed data to `data/processed/elo_matches.csv`

**Dependencies**: Task 3.1

**File Outputs**:
- `R/elo/preprocess.R`
- `data/processed/elo_matches.csv`

**Success Criteria**:
- [ ] All martj42 results loaded and preprocessed
- [ ] Team names mapped to canonical names and FIFA codes
- [ ] Results encoded as 1, 0.5, 0
- [ ] Matches sorted chronologically
- [ ] Data saved with proper column types

**Time Estimate**: 25 minutes

---

### Task 3.3: Compute Elo ratings (ELO-02)
**Description**: Process all matches chronologically and compute Elo ratings for all teams

**Sub-tasks**:
- Initialize rating history: all teams start at 1500
- For each match in chronological order:
  - Look up current ratings for home and away teams
  - Apply home advantage (60 points) if not neutral venue
  - Compute expected results using `expected_result()`
  - Update ratings using `elo_update()` with appropriate k-factors
  - Apply rating decay based on days since last match
  - Store pre-match and post-match ratings
- Track match frequency per team per year for k-factor calculation
- Save complete rating history to `data/processed/elo_ratings.csv`
- Save current (most recent) ratings to `data/processed/elo_current.csv`

**Dependencies**: Task 3.1, Task 3.2

**File Outputs**:
- `R/elo/runner.R` (updated)
- `data/processed/elo_ratings.csv`
- `data/processed/elo_current.csv`

**Success Criteria**:
- [ ] Elo ratings computed for all teams from 1872-present
- [ ] Ratings updated chronologically for all ~49,000 matches
- [ ] Home advantage applied for non-neutral matches
- [ ] Rating decay applied based on days since last match
- [ ] Rating history and current ratings saved

**Time Estimate**: 30 minutes

---

### Task 3.4: Implement k-factor logic (ELO-04)
**Description**: Implement variable k-factor based on match frequency and decay

**Sub-tasks**:
- In `R/elo/runner.R`, add:
  - `get_k_factor(team, date)` - Returns k-factor based on match frequency
  - Track matches per team per calendar year
  - k = 20 for teams with ≥15 matches in current/previous year
  - k = 40 for teams with <15 matches
- Implement rating decay function:
  - `apply_decay(rating, days_since_last)` - Returns decayed rating
  - Formula: `rating * 0.995^(days_since_last / 365)`
- Update Task 3.3 to use variable k-factors and decay

**Dependencies**: Task 3.3

**File Outputs**:
- `R/elo/runner.R` (updated)

**Success Criteria**:
- [ ] k-factor = 20 for teams ≥15 matches/year, 40 for <15 matches/year
- [ ] Rating decay implemented: 0.995^(days_since_last/365)
- [ ] Decay applied before each rating update

**Time Estimate**: 20 minutes

---

### Task 3.5: Rolling-origin validation (ELO-04)
**Description**: Tune Elo parameters via rolling-origin (leave-one-out by date) validation

**Sub-tasks**:
- Create `R/elo/tuning.R`
- For each match in test period (most recent 1-2 years):
  - Compute Elo ratings using only data BEFORE that match
  - Predict match outcome using pre-match ratings
  - Store: predicted_result, actual_result, date, home_team, away_team
- Calculate validation metrics:
  - AUC for predicting win/draw/loss
  - Accuracy
  - Brier score
- Compare performance with different parameter combinations:
  - k-factor: 20 vs 30 vs 40
  - Home advantage: 40 vs 60 vs 80
  - Decay: 0.99 vs 0.995 vs 0.999
- Select best parameters based on validation performance
- Save validation results to `outputs/model_performance/elo_validation.csv`

**Dependencies**: Task 3.4

**File Outputs**:
- `R/elo/tuning.R`
- `outputs/model_performance/elo_validation.csv`

**Success Criteria**:
- [ ] Rolling-origin validation implemented
- [ ] Performance metrics (AUC, accuracy, Brier) calculated
- [ ] Parameter combinations tested and compared
- [ ] Best parameters identified

**Time Estimate**: 30 minutes

---

## Dependency Graph

```
Task 3.1: Elo Calculation Function
    │
    └─── Task 3.2: Preprocess martj42 Results
            │
            └─── Task 3.3: Compute Elo Ratings
                    │
                    └─── Task 3.4: K-Factor & Decay Implementation
                            │
                            └─── Task 3.5: Rolling-Origin Validation
```

**Critical Path**: 3.1 → 3.2 → 3.3 → 3.4 → 3.5

**Total Sequential Time**: ~125 minutes (~2.1 hours)

---

## File Output Summary

| Task | Primary Output | Secondary Outputs |
|------|---------------|-------------------|
| 3.1 | `R/elo/runner.R` | `tests/testthat/test_elo.R` |
| 3.2 | `R/elo/preprocess.R` | `data/processed/elo_matches.csv` |
| 3.3 | `R/elo/runner.R` (updated) | `data/processed/elo_ratings.csv`, `data/processed/elo_current.csv` |
| 3.4 | `R/elo/runner.R` (updated) | - |
| 3.5 | `R/elo/tuning.R` | `outputs/model_performance/elo_validation.csv` |

---

## Success Criteria Alignment

| Requirement | Task | Success Criteria |
|-------------|------|------------------|
| ELO-01 | 3.1 | `compute_elo()` is pure function with configurable k-factor and home advantage |
| ELO-02 | 3.2, 3.3 | Elo ratings computed for all teams from 1872-present |
| ELO-03 | 3.3, 3.4 | Home advantage = 60 points for non-neutral matches, 0 for neutral |
| ELO-04 | 3.4, 3.5 | k-factor tuned: 20 for ≥15 matches/year, 40 for <15; decay = 0.995^(days/365) |

---

## Execution Notes

### Elo Formula Implementation
```r
# Expected result for team A against team B
expected_result <- function(rating_a, rating_b) {
  1 / (1 + 10^((rating_b - rating_a) / 400))
}

# Rating update
elo_update <- function(rating_a, rating_b, actual_result, k_a, k_b, home_advantage = 0) {
  # Adjust home rating for home advantage
  rating_a_adj <- rating_a + if (is_home) home_advantage else 0
  
  # Expected results
  exp_a <- expected_result(rating_a_adj, rating_b)
  exp_b <- 1 - exp_a
  
  # New ratings
  rating_a_new <- rating_a + k_a * (actual_result - exp_a)
  rating_b_new <- rating_b + k_b * ((1 - actual_result) - exp_b)
  
  list(rating_a = rating_a_new, rating_b = rating_b_new)
}

# Rating decay
apply_decay <- function(rating, days_since_last) {
  rating * (0.995 ^ (days_since_last / 365))
}
```

### Match Preprocessing
```r
library(dplyr)
library(lubridate)

# Load results
results <- read.csv("data/raw/martj42/results.csv")

# Map team names
team_map <- read.csv("data/raw/team_name_map.csv")

# Preprocess
elo_matches <- results |
  # Convert date to Date object
  mutate(date = as.Date(date)) |
  # Determine result
  mutate(result = case_when(
    home_score > away_score ~ 1.0,
    home_score == away_score ~ 0.5,
    home_score < away_score ~ 0.0
  )) |
  # Sort chronologically
  arrange(date)

# Save
write.csv(elo_matches, "data/processed/elo_matches.csv", row.names = FALSE)
```

### Elo Computation
```r
# Initialize ratings
ratings <- data.frame(
  team = unique(c(elo_matches$home_team, elo_matches$away_team)),
  fifa_code = NA_character_,
  rating = 1500,
  last_match_date = as.Date(NA),
  matches_this_year = 0,
  matches_last_year = 0
)

# Process each match
for (i in seq_nrow(elo_matches)) {
  match <- elo_matches[i, ]
  
  # Get current ratings
  home_rating <- ratings$rating[ratings$team == match$home_team]
  away_rating <- ratings$rating[ratings$team == match$away_team]
  
  # Apply decay
  days_since_home <- as.numeric(difftime(match$date, 
                                         ratings$last_match_date[ratings$team == match$home_team],
                                         units = "days"))
  days_since_away <- as.numeric(difftime(match$date,
                                         ratings$last_match_date[ratings$team == match$away_team],
                                         units = "days"))
  
  home_rating <- home_rating * (0.995 ^ (days_since_home / 365))
  away_rating <- away_rating * (0.995 ^ (days_since_away / 365))
  
  # Determine k-factors
  k_home <- if (ratings$matches_last_year[ratings$team == match$home_team] >= 15) 20 else 40
  k_away <- if (ratings$matches_last_year[ratings$team == match$away_team] >= 15) 20 else 40
  
  # Apply home advantage
  home_advantage <- if (!match$neutral) 60 else 0
  
  # Update ratings
  update <- elo_update(home_rating, away_rating, match$result, k_home, k_away, home_advantage)
  
  # Save post-match ratings
  # ... (update ratings data frame)
}
```

### Rolling-Origin Validation
```r
# Use most recent year as test period
test_start <- max(elo_matches$date) - 365

test_matches <- elo_matches[elo_matches$date >= test_start, ]

# For each test match, compute ratings using only data before match date
validation_results <- list()
for (i in seq_nrow(test_matches)) {
  test_match <- test_matches[i, ]
  
  # Get all matches before this one
  train_matches <- elo_matches[elo_matches$date < test_match$date, ]
  
  # Compute ratings using only train data
  train_ratings <- compute_ratings(train_matches)  # This uses Task 3.3 logic
  
  # Get pre-match ratings
  home_rating <- train_ratings$rating[train_ratings$team == test_match$home_team]
  away_rating <- train_ratings$rating[train_ratings$team == test_match$away_team]
  
  # Apply home advantage
  home_rating_adj <- home_rating + if (!test_match$neutral) 60 else 0
  
  # Predict
  pred_exp <- expected_result(home_rating_adj, away_rating)
  
  validation_results[[i]] <- list(
    date = test_match$date,
    home_team = test_match$home_team,
    away_team = test_match$away_team,
    actual_result = test_match$result,
    predicted_prob = pred_exp,
    home_rating_pre = home_rating,
    away_rating_pre = away_rating
  )
}

# Calculate metrics
actuals <- sapply(validation_results, function(x) x$actual_result)
predictions <- sapply(validation_results, function(x) x$predicted_prob)

auc_val <- pROC::auc(pROC::roc(actuals, predictions))
accuracy_val <- mean(as.integer(predictions >= 0.5) == as.integer(actuals >= 0.5))
```

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Chronological sorting error | Medium | High | Verify date parsing, sort explicitly |
| Team name mapping errors | Medium | High | Use FIFA codes from Phase 1, validate all teams have mappings |
| Performance issues with 49k matches | Low | Medium | Vectorize where possible, test with subset first |
| Rating explosion/instability | Low | Medium | Clamp ratings to reasonable range (e.g., 1000-2000) |
| Missing neutral venue flag | Low | Medium | Default to non-neutral, flag in data quality check |

---

## Parallel Execution Notes

This phase can run **in parallel with Phase 2 (xG Model Development)** as they have no dependencies on each other. Both depend only on Phase 1 (Data Ingestion).

---

## Rollback Strategy

- Failed unit tests: Fix calculation logic, re-run tests
- Preprocessing errors: Check date parsing, team name mapping
- Rating computation errors: Validate input data, check for NA values
- Validation errors: Verify temporal split, check metric calculations

---

## Nyquist Validation

```bash
# Run Elo unit tests
Rscript -e "testthat::test_dir('tests/testthat/test_elo.R')"

# Verify Elo ratings file exists
Rscript -e "elo_ratings <- read.csv('data/processed/elo_ratings.csv'); stopifnot(nrow(elo_ratings) > 40000)"

# Check current ratings
Rscript -e "elo_current <- read.csv('data/processed/elo_current.csv'); print(head(elo_current))"

# Verify validation results
Rscript -e "validation <- read.csv('outputs/model_performance/elo_validation.csv'); print(summary(validation))"
```

---

## Phase Acceptance Criteria

Phase 3 is complete when:
- [ ] All 5 tasks completed
- [ ] All success criteria met
- [ ] All unit tests pass
- [ ] Elo ratings computed for all teams 1872-present
- [ ] Home advantage and k-factor implemented correctly
- [ ] Rating decay applied
- [ ] Rolling-origin validation completed
- [ ] All output files exist in specified locations

---
*Plan locked: 2026-06-03 | Next: /gsd-verify-work 3 or /gsd-execute-phase 3*

---

## PLAN SUMMARY

**PLAN CREATED** ✓

- **5 tasks** defined
- **1 dependency chain** (sequential)
- **10 file outputs** specified
- **All Phase 3 requirements covered** (ELO-01, ELO-02, ELO-03, ELO-04)
- **Total Time Estimate**: ~125 minutes (~2.1 hours)
- **Parallelizable**: Yes (with Phase 2)
