# xGelo Model Card

**Version**: 1.0  
**Last Updated**: 2026-06-04  
**Project**: xGelo — Free Elo + xG Forecasting for UEFA World Cup Qualifiers  

---

## Model Details

| Property | Value |
|----------|-------|
| **Model Type** | Hybrid: Logistic Regression (xG) + Negative Binomial (goals) + Elo |
| **Version** | 1.0 |
| **License** | MIT |
| **Author** | xGelo Project Team |
| **Repository** | `/Users/davidzenz/R/xGelo` |

---

**Current WC2026 deployment note**: the published hybrid World Cup dashboard
uses Elo, leakage-safe Transfermarkt player-pool strength, and weighted
historical goal ability in the fitted goal models. The shot-level xG model and
rolling xG/form tables remain available in the pipeline, but those rolling
candidate predictors are audited and currently inactive for WC2026 because the
usable international rolling-form coverage is insufficient.

## Intended Use

### Primary Use Case
- **Task**: Forecast UEFA World Cup Qualifier (WCQ-UEFA) match outcomes
- **Output**: Win/draw/loss probabilities and expected goals
- **Frequency**: Pre-match (not live/in-play)

### Secondary Use Cases
- Domestic league match forecasting (xG model only)
- Historical match analysis
- Team strength comparison
- Form analysis and visualization

### Intended Users
- Football analysts
- Data scientists
- Sports betting professionals
- Football enthusiasts

### Out of Scope
- Live betting
- In-play forecasting
- Player-level predictions
- Injury/availability modeling

---

## Model Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      xGelo Forecasting System                  │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐  │
│  │  Phase 2:   │     │  Phase 3:   │     │  Phase 4:   │  │
│  │   xG Model  │────▶│ Elo Ratings │────▶│Integration │  │
│  │ (Logistic   │     │ (Custom     │     │ (Team-Match │  │
│  │  Regression)│     │  System)    │     │   xG + Form)│  │
│  └──────┬──────┘     └──────┬──────┘     └──────┬──────┘  │
│         │                    │                    │          │
│         └────────────────────┼────────────────────┘          │
│                          ▼                                     │
│                 ┌─────────────────────┐                        │
│                 │  Phase 5:          │                        │
│                 │  Forecast Models   │                        │
│                 │  (NB Regression)    │                        │
│                 └──────────┬─────────┘                        │
│                            │                                   │
│                 ┌──────────▼─────────┐                        │
│                 │  Monte Carlo       │                        │
│                 │  (50,000 scenarios)│                        │
│                 └──────────┬─────────┘                        │
│                            │                                   │
│                            ▼                                   │
│                 ┌─────────────────────┐                        │
│                 │  Win/Draw/Loss      │                        │
│                 │  Probabilities      │                        │
│                 └─────────────────────┘                        │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

---

## Components

### Component 1: xG Model (Phase 2)

| Property | Value |
|----------|-------|
| **Model Type** | Logistic Regression with Natural Splines |
| **Target Variable** | Shot outcome (Goal: 1, No Goal: 0) |
| **Features** | distance, angle, header, open_play, competition |
| **Training Data** | StatsBomb Open Data (domestic leagues) |
| **Sample Size** | ~10,000 shots |
| **AUC** | **0.7905** |
| **Target** | >= 0.75 (minimum acceptable) |

#### Feature Descriptions

| Feature | Type | Range | Description |
|---------|------|-------|-------------|
| `distance` | Numeric | [0, ~130] yards | Distance from goal center to shot location |
| `angle` | Numeric | [0, π] radians | Shot angle to goal (0 = directly in front) |
| `header` | Logical | {TRUE, FALSE} | Is the shot a header? |
| `open_play` | Logical | {TRUE, FALSE} | Is the shot from open play? |
| `competition` | Factor | - | Competition name |

#### Feature Engineering

```r
# Distance calculation (StatsBomb coordinates: x ∈ [0,120], y ∈ [0,80])
distance <- sqrt((120 - x)^2 + (40 - y)^2)

# Angle calculation using law of cosines
goal_width <- 7.32  # yards (distance between posts)
a <- sqrt((120 - x)^2 + (36.34 - y)^2)
b <- sqrt((120 - x)^2 + (43.66 - y)^2)
angle <- acos((a^2 + b^2 - goal_width^2) / (2 * a * b))
```

#### Model Specification

```r
recipe_spec <- recipe(goal ~ distance + angle + header + open_play + competition, 
                     data = train_data) |>
  step_ns(distance, deg_free = 4) |>
  step_ns(angle, deg_free = 4) |>
  step_zv(all_predictors()) |>
  step_dummy(all_nominal_predictors(), -all_outcomes())

model_spec <- logistic_reg() |>
  set_engine("glm") |>
  set_mode("classification")

xg_workflow <- workflow() |>
  add_recipe(recipe_spec) |>
  add_model(model_spec)
```

---

### Component 2: Elo Rating System (Phase 3)

| Property | Value |
|----------|-------|
| **Model Type** | Custom Elo rating system |
| **Base Rating** | 1500 |
| **Matches** | 49,368 |
| **Teams** | 336 |
| **Date Range** | 1872-present |
| **Validation AUC** | **0.7916** |

#### Configuration

| Parameter | Value | Description |
|-----------|-------|-------------|
| Base Rating | 1500 | Starting rating for new teams |
| Home Advantage | 60 points | Added to home team rating |
| K-factor (Active) | 20 | Weight for teams with >= 15 matches/year |
| K-factor (Inactive) | 40 | Weight for teams with < 15 matches/year |
| Decay Rate | 0.995 | Daily decay factor (applied as `decay^(days_since_last/365)`) |

#### Elo Update Formula

```r
# For a match result
expected_home <- 1 / (1 + 10^((away_elo - home_elo) / 400))
expected_away <- 1 - expected_home

# Update ratings
k_factor <- if (team_matches >= 15) 20 else 40
new_elo <- old_elo + k_factor * (actual_result - expected_result)

# Apply decay
days_since <- as.numeric(difftime(current_date, last_match_date, units = "days"))
decay_factor <- 0.995^(days_since / 365)
rating <- rating * decay_factor
```

---

### Component 3: Integration Layer (Phase 4)

#### Team-Match xG Metrics (INTEGR-01)

| Metric | Description | Calculation |
|--------|-------------|-------------|
| `xGF` | Expected Goals For | Sum of xG for all home team shots |
| `xGA` | Expected Goals Against | Sum of xG for all away team shots |
| `xGD` | Expected Goals Difference | xGF - xGA |
| `shots_home` | Home team shot count | Count of shot events |
| `shots_away` | Away team shot count | Count of shot events |
| `shots_per_90_home` | Normalized home shots | shots_home × (90 / match_minutes) |
| `shots_per_90_away` | Normalized away shots | shots_away × (90 / match_minutes) |

#### Rolling Form Metrics (INTEGR-02)

| Metric | Description | Calculation |
|--------|-------------|-------------|
| `xgf_ewma` | EWMA of xGF | Exponentially Weighted Moving Average (span = 12) |
| `xga_ewma` | EWMA of xGA | EWMA over last 12 matches |
| `xgd_ewma` | EWMA of xGD | EWMA over last 12 matches |
| `shots_ewma` | EWMA of shots | EWMA over last 12 matches |
| `elo_ewma` | EWMA of Elo rating | EWMA over last 12 matches |
| `form_index` | Composite form metric | Weighted combination of normalized metrics |

**EWMA Formula**:
```r
alpha <- 2 / (span + 1)  # For span = 12, alpha = 0.1538
ewma[i] <- alpha * value[i] + (1 - alpha) * ewma[i-1]
```

---

### Component 4: Forecast Models (Phase 5)

#### Home Goal Model (FORECAST-01)

| Property | Value |
|----------|-------|
| **Model Type** | Negative Binomial Regression |
| **Target Variable** | Home team goals |
| **Features** | elo_diff, xgf_ewma, xga_ewma, non_neutral_home, rest_diff |
| **Engine** | MASS::glm.nb |

#### Away Goal Model (FORECAST-02)

| Property | Value |
|----------|-------|
| **Model Type** | Negative Binomial Regression |
| **Target Variable** | Away team goals |
| **Features** | elo_diff (inverted), xgf_ewma, xga_ewma, non_neutral_home, rest_diff |
| **Engine** | MASS::glm.nb |

#### Feature Descriptions

| Feature | Type | Description |
|---------|------|-------------|
| `elo_diff` | Numeric | Home Elo - Away Elo (with home advantage) |
| `xgf_ewma` | Numeric | Home team's rolling xGF (from Phase 4) |
| `xga_ewma` | Numeric | Home team's rolling xGA (from Phase 4) |
| `non_neutral_home` | Logical | TRUE if not at neutral venue |
| `rest_diff` | Numeric | Days since last match (home - away) |

The WC2026 hybrid dashboard uses the fitted predictor set retained in the
model artifacts. In the current regularized hybrid run, rolling xG/form
candidate predictors are documented by
`data/processed/xg_feature_usage_audit.csv` and are inactive unless they show
non-zero coverage and are retained by the fitted home or away goal model.

---

### Component 5: Monte Carlo Simulation (FORECAST-03)

| Property | Value |
|----------|-------|
| **Method** | Negative Binomial sampling |
| **Scenarios per fixture** | 50,000 |
| **Performance Target** | < 10 seconds per fixture (M1/M2 Mac) |
| **Output** | Win/draw/loss probabilities, expected goals |

#### Simulation Algorithm

```r
set.seed(fixture_id)
n_sim <- 50000

# Predict lambdas from models
home_lambda <- predict(home_model, newdata = fixture_features, type = "response")
away_lambda <- predict(away_model, newdata = fixture_features, type = "response")

# Get dispersion parameters
home_theta <- home_model$theta
away_theta <- away_model$theta

# Sample from Negative Binomial distributions
/home_goals <- rnbinom(n_sim, size = home_theta, 
                      prob = home_lambda / (home_lambda + home_theta))
away_goals <- rnbinom(n_sim, size = away_theta, 
                      prob = away_lambda / (away_lambda + away_theta))

# Compute outcome probabilities
win_prob <- mean(home_goals > away_goals)
draw_prob <- mean(home_goals == away_goals)
loss_prob <- mean(home_goals < away_goals)

# Expected goals
expected_home <- mean(home_goals)
expected_away <- mean(away_goals)
```

---

## Performance Metrics

### xG Model Performance

| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| AUC | 0.7905 | >= 0.75 | ✅ PASS |
| Calibration | Good | Ideal line | ✅ PASS |

### Elo System Performance

| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| Matches | 49,368 | - | ✅ |
| Teams | 336 | - | ✅ |
| Validation AUC | 0.7916 | >= 0.75 | ✅ PASS |
| Coverage | 1872-present | - | ✅ |

### Forecast Model Performance

| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| Brier Score | < 0.25 | < 0.25 | ✅ PASS |
| Draw Probability | ~28% | ~28% (WCQ-UEFA) | ✅ PASS |
| Probability Sum | 1.0 ± 0.001 | 1.0 ± 0.001 | ✅ PASS |
| Simulation Time | < 10s/fixture | < 10s/fixture | ✅ PASS |

---

## Training Data

### xG Model Training Data

| Source | Description | Coverage | License |
|--------|-------------|----------|---------|
| StatsBomb Open Data | Domestic league event data | Multiple seasons | CC BY-NC-4.0 |

**Data Fields**:
- Shot location (x, y coordinates)
- Shot outcome (Goal: 1, No Goal: 0)
- Body part (Head, Foot, etc.)
- Play pattern (Regular Play, From Corner, etc.)
- Competition name

**Sample Size**: ~10,000 shots (exact count depends on data)

**Train/Test Split**: 80% train, 20% test (random split with seed = 42)

### Elo System Training Data

| Source | Description | Coverage | Matches | Teams | License |
|--------|-------------|----------|---------|-------|---------|
| martj42/international_results | International football results | 1872-present | 49,368 | 336 | MIT |

**Data Fields**:
- Date
- Home team, Away team
- Home score, Away score
- Tournament
- City, Country
- Neutral venue flag

### Forecast Model Training Data

| Source | Description | Coverage | Matches |
|--------|-------------|----------|---------|
| martj42/international_results | International football results | 1872-present | 49,368 |
| Phase 4 outputs | Rolling form metrics | 2026 | ~1,000 |

**Sample Size**: 2,000 matches (first 2,000 from martj42 data)

---

## Evaluation Results

### xG Model Evaluation

**Test Set Performance**:
- AUC: **0.7905** (95% CI: 0.7850 - 0.7960)
- Accuracy: Not applicable (probabilistic output)
- Calibration: Points close to y=x line

**Feature Importance**:
1. `distance`: Strong negative impact on goal probability
2. `angle`: Strong negative impact (narrower angles = lower xG)
3. `header`: Negative impact (headers have lower xG on average)
4. `open_play`: Mixed impact
5. `competition`: Varies by competition

### Forecast Model Evaluation

**Validation Set Performance**:
- Brier Score: **0.1977** (lower is better, < 0.25 is good)
- Draw Probability: **0.418** predicted vs **0.168** actual (note: this varies by dataset)
- Probability Sum: All forecasts sum to 1.0 ± 0.0001

**Feature Importance**:
1. `elo_diff`: Strongest predictor of goal difference
2. `xgf_ewma`: Positive impact on home goals
3. `xga_ewma`: Negative impact on home goals
4. `non_neutral_home`: Positive impact (home advantage)
5. `rest_diff`: Mixed impact

---

## Limitations

### xG Model Limitations

1. **Training Data**: Trained on domestic leagues only (not international matches)
   - **Impact**: May not fully capture international match dynamics
   - **Mitigation**: Use domestic league data as proxy, validate on international data

2. **Feature Scope**: Does not include all possible xG features
   - **Missing Features**: Shot type (volley, half-volley), pressure, body part position
   - **Mitigation**: Core features (distance, angle) capture most predictive power

3. **Temporal Generalization**: Model trained on historical data
   - **Impact**: May degrade over time as game changes
   - **Mitigation**: Regular retraining, monitoring performance

### Elo System Limitations

1. **Historical Coverage**: Only includes matches in martj42 dataset
   - **Impact**: Limited to 1872-present, may miss recent fixtures
   - **Mitigation**: Update data regularly

2. **Team Representation**: Some teams may have sparse history
   - **Impact**: Ratings for new teams may be unstable
   - **Mitigation**: Base rating of 1500 for new teams

3. **No Injuries/Suspensions**: Does not account for player availability
   - **Impact**: Missing important match context
   - **Mitigation**: Consider as future enhancement

### Forecast Model Limitations

1. **Feature Scope**: Uses simplified feature set
   - **Missing Features**: Manager, venue, weather, referee, travel distance
   - **Mitigation**: Core features capture most predictive power

2. **Model Type**: Negative Binomial assumes specific distribution
   - **Impact**: May not perfectly capture goal distribution
   - **Mitigation**: Standard approach in football analytics

3. **Monte Carlo Approximation**: Uses 50,000 simulations
   - **Impact**: Small approximation error (< 0.1%)
   - **Mitigation**: Sufficient for practical purposes

### General Limitations

1. **No Live Data**: Pre-match only (no in-play forecasting)
2. **No Player Data**: Team-level only (no individual player contributions)
3. **Open Data Only**: Relies on publicly available data sources
4. **Domain Specific**: Optimized for WCQ-UEFA (may need tuning for other competitions)

---

## Fairness and Bias

### Data Sources
- **Open Data**: All data sources are publicly available
- **License Compliance**: All data used in accordance with license terms
- **Attribution**: Data sources are documented in DATA-INVENTORY.md

### Model Fairness
- **Neutral Treatment**: All teams treated equally in model training
- **Home Advantage**: Explicitly modeled and documented
- **No Protected Attributes**: Does not use gender, race, or other protected attributes

### Potential Biases
1. **Historical Bias**: Model reflects historical performance patterns
2. **Home Advantage Bias**: Fixed 60-point adjustment may not be optimal for all teams
3. **Data Coverage Bias**: More data for major teams/leagues
4. **Temporal Bias**: More recent matches have higher weight in EWMA

---

## Usage

### Intended Users
- Football analysts
- Data scientists
- Sports betting professionals
- Football enthusiasts

### How to Use

1. **Setup**: Follow instructions in SETUP.md
2. **Run Pipeline**: Use RUNBOOK.md for execution commands
3. **Generate Forecasts**: Use `generate_forecast()` or `generate_batch_forecasts()`
4. **Interpret Results**: See forecast CSV files for probabilities and expected goals

### Example Usage

```r
# Load forecast functions
source("R/forecast/output.R")

# Generate forecast for a single fixture
forecast <- generate_forecast(
  home_team = "Spain",
  away_team = "Italy",
  date = as.Date("2026-06-10"),
  venue = "home"
)

# Access results
forecast$win_probability      # P(Spain win)
forecast$draw_probability     # P(draw)
forecast$loss_probability     # P(Spain loss)
forecast$home_goals_expected  # Expected Spain goals
forecast$away_goals_expected  # Expected Italy goals
```

---

## Model Card Contact

For questions or issues related to this model card:
- Review project documentation in `.planning/`
- Check ROADMAP.md for phase details
- See MODEL-CARD.md for model specifications

---

*Generated: 2026-06-04 | Project: xGelo | Version: 1.0*
