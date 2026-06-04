# Phase 2: xG Model Development — CONTEXT

---
*Phase*: 2
*Name*: xG Model Development
*Project*: xGelo — Free Elo + xG Forecasting for UEFA World Cup Qualifiers
*Last Updated*: 2026-06-03
*Status*: Decisions locked, ready for planning

---

## Phase Goal

Train a production-ready xG model on StatsBomb Open Data using minimal, interpretable features (distance, angle, header, open_play, competition) achieving **AUC ≥ 0.75** on held-out domestic league test set. Model will be calibrated, backtested, and saved for integration into forecasting pipeline.

---

## Decisions

### Coordinate System
- **Decision**: Use **StatsBomb standard coordinate system**
- **Specification**: Pitch dimensions 120x80 yards, goal centered at x=120, goalposts at y=36.34 and y=43.66 (goal width = 7.32 yards)
- **Rationale**: Matches StatsBomb Open Data format, industry standard
- **Implication**: All distance/angle calculations use this coordinate system
- **Reference**: open_data_elo_xg_wcq_research_memo.md, StatsBomb documentation

### Feature Contract
- **Decision**: Minimal xG feature contract = **distance, angle, header, open_play, competition**
- **Specification**:
  - `distance`: Euclidean distance from shot location to goal center (yards)
  - `angle`: Angle between shot location and goalposts (radians, range [0, π])
  - `header`: Binary flag for headed shots (body_part == "Head")
  - `open_play`: Binary flag for regular play (play_pattern == "Regular Play")
  - `competition`: Categorical variable for league/competition
- **Rationale**: Achieves AUC ≥ 0.75 per research memo, keeps model interpretable and source-robust
- **Implication**: XG-03 requirement satisfied; model can be extended later with additional features
- **Reference**: ROADMAP.md XG-03, open_data_elo_xg_wcq_research_memo.md

### Penalty Handling
- **Decision**: **Exclude penalty shots** from training data
- **Rationale**: Penalties have ~80% conversion rate, fundamentally different from open play shots
- **Implication**: Penalty shots will return NA in predictions; can be handled separately if needed
- **Reference**: Code example in research memo: `filter(!shot_type %in% c("Penalty"))`

### Model Architecture
- **Decision**: Use **logistic regression with natural splines**
- **Specification**:
  - Model: `tidymodels::logistic_reg()`
  - Splines: `step_ns(distance, deg_free = 4)` + `step_ns(angle, deg_free = 4)`
  - Features: distance, angle, header, open_play, competition
  - Engine: Default (glm)
- **Rationale**: Baseline interpretable model, achieves target AUC, extensible to mixed effects
- **Implication**: XG-04 requirement satisfied
- **Reference**: ROADMAP.md XG-04, research memo (AUC 0.75-0.79 with these features)

### Train/Test Split Strategy
- **Decision**: **Season-based temporal split** on domestic leagues
- **Specification**:
  - Training: All StatsBomb domestic league matches from older seasons
  - Test: All StatsBomb domestic league matches from most recent complete season
  - No data leakage: Same match never appears in both train and test
- **Rationale**: Temporal validation simulates real-world deployment, ensures no future information leaks
- **Implication**: Model validated on unseen data, backtest represents production performance
- **Reference**: ROADMAP.md XG-04, XG-06

### Calibration Method
- **Decision**: Use **isotonic regression calibration**
- **Specification**:
  - Method: `calibrate::calibrate(method = "isotonic")`
  - Target: Predicted vs observed probabilities within ±5% per bin
  - Bins: 10 equal-width bins from 0 to 1 (0-0.1, 0.1-0.2, ..., 0.9-1.0)
  - Output: Calibration plot saved to `outputs/visualizations/xg_calibration.png`
- **Rationale**: Non-parametric, works well for xG probability calibration
- **Implication**: XG-05 requirement satisfied
- **Reference**: ROADMAP.md XG-05

### Backtest Methodology
- **Decision**: **Comprehensive performance evaluation**
- **Specification**:
  - Metrics: AUC, accuracy, Brier score
  - Grouping: Performance reported by competition and season
  - Visualization: ROC curve
  - Output: `outputs/model_performance/xg_backtest.csv` with columns: competition, season, n_shots, n_goals, auc, accuracy, brier_score
  - Target: **AUC ≥ 0.75** on domestic league test set
- **Rationale**: Validates model meets minimum performance threshold
- **Implication**: XG-06 requirement satisfied; provides baseline for future improvements
- **Reference**: ROADMAP.md XG-06

### Spline Degrees of Freedom
- **Decision**: Use **deg_free = 4** for natural splines
- **Specification**: Both distance and angle use deg_free = 4
- **Rationale**: Balances flexibility and overfitting, matches research memo example
- **Implication**: Affects model smoothness; can be tuned later if needed
- **Reference**: Code example in research memo

---

## Locked Decisions from Prior Phases

### From Phase 1 (Data Ingestion)
- **StatsBomb Data Source**: GitHub raw URLs, domestic leagues only (exclude World Cup, Euros, etc.)
- **Data Directory**: `data/raw/statsbomb/` with `events/` and `lineups/` subdirectories
- **Cache Structure**: Organized by source, with `.gitignore` exclusions
- **Validation**: Schema validation implemented in `R/pipeline/validation.R`

### From PROJECT.md
- **Language**: R (non-negotiable)
- **Orchestration**: targets framework for reproducible pipelines
- **Modelling**: tidymodels ecosystem for consistency
- **License Constraint**: Open data only for training (StatsBomb Open Data)

---

## Implementation Constraints

1. **Data Source**: Use only StatsBomb Open Data (domestic leagues) for training
2. **Output Format**: Save model as `models/xg_model.rds`
3. **Performance**: Must achieve AUC ≥ 0.75 on held-out test set
4. **Calibration**: Predicted vs observed within ±5% per bin
5. **Reproducibility**: All code in `R/xg/` directory with tests in `tests/testthat/`

---

## Success Criteria Alignment

| Requirement | Decision | Success Metric |
|-------------|----------|----------------|
| XG-01 | Coordinate system: StatsBomb 120x80 | `calculate_distance()` returns correct Euclidean distance |
| XG-02 | Coordinate system: StatsBomb goal at (120, 36.34-43.66) | `calculate_angle()` returns correct angle in radians |
| XG-03 | Feature contract: distance, angle, header, open_play, competition | All features computed for each shot |
| XG-04 | Model: logistic_reg with splines (deg_free=4) | Model trained and saved to `models/xg_model.rds` |
| XG-05 | Calibration: isotonic, bins [0-1] in 0.1 increments | Calibration within ±5% per bin, plot saved |
| XG-06 | Backtest: AUC, ROC, by competition/season | AUC ≥ 0.75 on test set, CSV saved |

---

## Open Questions / Deferred

1. **Additional Features**: Adding shooter random effects, defender pressure, shot technique could improve AUC to 0.78-0.826 (research memo). **Deferred** to Phase 2+ iterations.
2. **Sequence Features**: Using preceding events (1-3 actions before shot) can improve to AUC 0.826. **Deferred** due to complexity.
3. **Full StatsBomb Download**: Currently only sample data ingested. **Deferred** to batch processing script.

---
*Decisions locked: 2026-06-03 | Next: /gsd-plan-phase 2*
