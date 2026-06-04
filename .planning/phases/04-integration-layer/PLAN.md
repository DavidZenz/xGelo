# Phase 4: Integration Layer — PLAN

---
*Phase*: 4
*Name*: Integration Layer
*Project*: xGelo — Free Elo + xG Forecasting for UEFA World Cup Qualifiers
*Status*: Ready for Execution
*Last Updated*: 2026-06-03
*Dependencies*: Phase 2 (XG-04 for xG model), Phase 1 (DATA-03 for StatsBomb data), Phase 3 (ELO-02 for Elo ratings)
---

## Phase Goal

Combine xG and Elo outputs into team-match metrics and form indicators. This phase creates the integrated feature set that Phase 5 (Forecasting Layer) will use to build predictive models.

## Task Breakdown

### Task 4.1: Create team-match xG metrics (INTEGR-01)
**Description**: Compute xGF, xGA, xGD, and shots per 90 for each team in each match

**Sub-tasks**:
- Load xG model from `models/xg_model.rds`
- For each StatsBomb event file in `data/raw/statsbomb/events/`:
  - Identify all shot events
  - Extract features (x, y, body_part, play_pattern) from each shot
  - Compute xG for each shot using `R/xg/features.R` functions
  - Aggregate xG by team and match
- Compute per-match metrics:
  - `xGF`: Total xG For (home team)
  - `xGA`: Total xG Against (away team)
  - `xGD`: xGF - xGA
  - `shots_home`: Total shots by home team
  - `shots_away`: Total shots by away team
  - `shots_per_90_home`: shots_home / (match_minutes / 90)
  - `shots_per_90_away`: shots_away / (match_minutes / 90)
- Add match metadata: date, home_team, away_team, competition, match_id
- Handle matches with no shot data: set all metrics to NA and add `has_shot_data = FALSE` flag
- Save to `data/processed/team_match_xg.csv`

**Dependencies**: None (within Phase 4)

**File Outputs**:
- `R/integration/team_match_xg.R`
- `data/processed/team_match_xg.csv`

**Success Criteria**:
- [ ] xGF, xGA, xGD computed correctly for each team in each match
- [ ] shots_per_90 computed for each team
- [ ] Matches with no shot data return NA with flag
- [ ] All xG values sum correctly across teams in a match

**Time Estimate**: 30 minutes

---

### Task 4.2: Compute rolling form metrics (INTEGR-02)
**Description**: Compute EWMA-based rolling form metrics over 6-12 matches

**Sub-tasks**:
- Load team-match xG metrics from Task 4.1
- Load Elo ratings from Phase 3 (`data/processed/elo_ratings.csv`)
- Merge Elo ratings with xG metrics by team and date
- For each team, sort matches chronologically
- Implement EWMA calculation:
  - Use stats::filter with recursive=TRUE for EWMA
  - Or manual calculation: EWMA_t = alpha * value_t + (1-alpha) * EWMA_{t-1}
  - Default span: 12 matches
  - Default alpha: computed from span (alpha = 2 / (span + 1))
  - Most recent match weight: 1 (most recent has highest weight)
- Compute rolling metrics per team per date:
  - `xgf_ewma`: EWMA of xGF over last N matches
  - `xga_ewma`: EWMA of xGA over last N matches
  - `elo_ewma`: EWMA of Elo rating over last N matches
  - `form_index`: Composite form metric (configurable combination)
- Handle teams with insufficient history (< 6 matches): return NA
- Save to `data/processed/rolling_form.csv`

**Dependencies**: Task 4.1

**File Outputs**:
- `R/integration/rolling_form.R`
- `data/processed/rolling_form.csv`

**Success Criteria**:
- [ ] EWMA computed over configurable 6-12 matches
- [ ] Most recent match has weight 1 with configurable decay factor
- [ ] Missing data handled gracefully (NA for teams with insufficient history)
- [ ] All rolling metrics computed for all teams

**Time Estimate**: 25 minutes

---

## Dependency Graph

```
Task 4.1: Team-Match xG Metrics
    │
    └─── Task 4.2: Rolling Form Metrics
```

**Critical Path**: 4.1 → 4.2

**Total Sequential Time**: ~55 minutes

---

## File Output Summary

| Task | Primary Output | Secondary Outputs |
|------|---------------|-------------------|
| 4.1 | `R/integration/team_match_xg.R` | `data/processed/team_match_xg.csv` |
| 4.2 | `R/integration/rolling_form.R` | `data/processed/rolling_form.csv` |

---

## Success Criteria Alignment

| Requirement | Task | Success Criteria |
|-------------|------|------------------|
| INTEGR-01 | 4.1 | xGF, xGA, xGD, shots per 90 computed for each team in each match |
| INTEGR-02 | 4.2 | EWMA computed over 6-12 matches, most recent weight = 1, missing data handled |

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| StatsBomb shot event structure varies | Medium | High | Use consistent field access, validate structure, log warnings |
| xG model loading fails | Low | High | Verify model file exists before processing, catch errors |
| Missing Elo ratings for teams | Medium | Medium | Join with NA, handle gracefully in EWMA calculation |
| Performance with many matches | Low | Medium | Process in batches, use vectorized operations where possible |
| Date alignment issues | Medium | Medium | Ensure all dates are Date objects, sort explicitly |

---

## Execution Notes

### xG Calculation
```r
# For each shot event
library(jsonlite)
library(purrr)

# Load model
model <- readRDS("models/xg_model.rds")

# Extract features
shot_features <- extract_shot_features(event)

# Predict xG (assuming model is a tidymodels workflow)
predict(model, new_data = shot_features)$`.pred`
```

### EWMA Implementation
```r
# Method 1: Using stats::filter
library(stats)

# For a team's xGF over time
xgf_values <- team_matches$xGF  # Sorted chronologically
span <- 12
alpha <- 2 / (span + 1)

# First value is just the first observation
EWMA_values <- filter(xgf_values, rep(alpha, length(xgf_values)), 
                     method = "convolution", circular = TRUE, recursive = TRUE)
# Note: stats::filter may need adjustment for proper EWMA

# Method 2: Manual EWMA
EWMA_manual <- function(values, alpha) {
  ewma <- numeric(length(values))
  ewma[1] <- values[1]
  for (i in 2:length(values)) {
    ewma[i] <- alpha * values[i] + (1 - alpha) * ewma[i-1]
  }
  ewma
}
```

### Configurability
```r
# All parameters should be configurable
compute_team_match_xg <- function(
  events_dir = "data/raw/statsbomb/events/",
  model_path = "models/xg_model.rds",
  output_path = "data/processed/team_match_xg.csv"
) {
  # ...
}

compute_rolling_form <- function(
  xg_metrics_path = "data/processed/team_match_xg.csv",
  elo_ratings_path = "data/processed/elo_ratings.csv",
  span = 12,
  output_path = "data/processed/rolling_form.csv"
) {
  # ...
}
```

---

## Nyquist Validation

```bash
# Verify team-match xG metrics file
Rscript -e "data <- read.csv('data/processed/team_match_xg.csv'); stopifnot(nrow(data) > 40000); print('team_match_xg.csv OK')"

# Verify rolling form file
Rscript -e "data <- read.csv('data/processed/rolling_form.csv'); stopifnot(nrow(data) > 1000); print('rolling_form.csv OK')"

# Check for NA handling
Rscript -e "data <- read.csv('data/processed/team_match_xg.csv'); print(paste('NA count:', sum(is.na(data$xGF))))"

# Run unit tests
Rscript -e "testthat::test_dir('tests/testthat/test_integration.R')"
```

---

## Phase Acceptance Criteria

Phase 4 is complete when:
- [ ] All 2 tasks completed
- [ ] All success criteria met
- [ ] All unit tests pass (if created)
- [ ] Both output files exist with expected row counts
- [ ] Spot-checks pass (xGF + xGA ≈ total match xG)
- [ ] NA handling verified

---

## Rollback Strategy

- Failed xG computation: Verify model loading, check event structure
- Failed EWMA: Check date sorting, verify sufficient history
- Data quality issues: Add validation checks, log warnings

---
*Plan locked: 2026-06-03 | Next: /gsd-execute-phase 4 or /gsd-plan-checker 4*
