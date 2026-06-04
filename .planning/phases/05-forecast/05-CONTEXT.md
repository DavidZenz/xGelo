# Phase 5: Forecasting Layer — CONTEXT

---
*Phase*: 5
*Name*: Forecasting Layer
*Project*: xGelo — Free Elo + xG Forecasting for UEFA World Cup Qualifiers
*Last Updated*: 2026-06-03
*Status*: Decisions locked, ready for planning
---

## Phase Goal

Build goal models, implement Monte Carlo simulation, and generate win/draw/loss probabilities for UEFA World Cup Qualifier fixtures using integrated features from Phase 4.

## Decisions

### Forecasting Architecture
- **Decision**: Use Negative Binomial regression models for home and away goals separately
- **Rationale**: Goal counts are discrete, overdispersed (variance > mean), and Negative Binomial is standard in football analytics
- **Implication**: Separate models for home and away allow for different dynamics (home advantage)

### Model Features (FORECAST-01, FORECAST-02)
- **Decision**: Use feature set: `elo_diff`, `xgf_ewma`, `xga_ewma`, `non_neutral_home`, `rest_diff`
- **Rationale**: Combines current form (xG EWMA) with historical strength (Elo) and situational factors
- **Sources**: Elo ratings from Phase 3, rolling form metrics from Phase 4
- **Feature Definitions**:
  - `elo_diff`: Home team Elo - Away team Elo (with home advantage adjustment)
  - `xgf_ewma`: Home team's rolling xGF (from INTEGR-02)
  - `xga_ewma`: Home team's rolling xGA (from INTEGR-02)
  - `non_neutral_home`: TRUE if home team is not at neutral venue
  - `rest_diff`: Days since last match for home team - days since last match for away team

### Monte Carlo Engine (FORECAST-03)
- **Decision**: Simulate 50,000 scenarios per fixture
- **Rationale**: Provides stable probability estimates while being computationally feasible
- **Performance Target**: <10 seconds per fixture on M1/M2 Mac
- **Method**: For each scenario, draw from Negative Binomial distributions for home and away goals, determine outcome
- **Output**: Win/draw/loss probabilities, expected goals

### Probability Calibration (FORECAST-04, FORECAST-05)
- **Decision**: Calibrate to achieve ~28% draw probability for WCQ-UEFA
- **Rationale**: UEFA World Cup Qualifiers have historically ~28% draw rate
- **Calibration Method**: Adjust model intercepts or use Platt scaling
- **Validation**: Use Brier score to track calibration quality over time

### Data Flow
```
Phase 4 (Integration) → team-match xG metrics + rolling form metrics
                         ↓
Phase 5 (Forecasting) → goal models ← integrated features
                         ↓
                      Monte Carlo simulation ← goal models
                         ↓
                      win/draw/loss probabilities + expected goals
```

### Technical Approach
- **Model Training**: Use `glm.nb` from MASS package for Negative Binomial regression
- **Feature Engineering**: Compute all features from Phase 3 and Phase 4 outputs
- **Monte Carlo**: Vectorized implementation for speed, parallel processing if needed
- **Calibration**: Compare predicted vs actual probabilities, adjust model parameters
- **Reproducibility**: Set random seeds for Monte Carlo, document all parameters

### File Outputs
- `R/forecast/poisson.R`: NB regression models for home and away goals
- `models/home_goal_model.rds`: Trained home goal model
- `models/away_goal_model.rds`: Trained away goal model
- `R/forecast/monte_carlo.R`: Monte Carlo simulation engine
- `R/forecast/output.R`: Probability generation and output formatting
- `R/forecast/calibration.R`: Model calibration logic
- `outputs/forecasts/`: Directory for forecast outputs (CSV/JSON)
- `outputs/visualizations/forecast_calibration.png`: Calibration plot

### Dependencies
- **Phase 2 (xG Model)**: xG model at `models/xg_model.rds` (for validation comparisons)
- **Phase 3 (Elo)**: Elo ratings at `data/processed/elo_ratings.csv` for elo_diff
- **Phase 4 (Integration)**: Rolling form metrics at `data/processed/rolling_form.csv` for xgf_ewma, xga_ewma

### Constraints
- All models must be deterministic (set random seeds)
- Monte Carlo must complete in <10 seconds per fixture
- Probabilities must sum to 1.0 ± 0.001
- Must handle missing feature values gracefully

### Validation Strategy
- **Model Quality**: Check AUC for goal prediction (home goals > 0.5, away goals > 0.5)
- **Probability Calibration**: Verify draw probability ≈ 28% over historical fixtures
- **Performance**: Time Monte Carlo simulation
- **Consistency**: Ensure home + away goal probabilities are independent
- **Brier Score**: Track and minimize Brier score over validation set

---
*Context locked: 2026-06-03 | Next: /gsd-plan-phase 5*
