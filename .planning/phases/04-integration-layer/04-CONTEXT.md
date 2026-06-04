# Phase 4: Integration Layer — CONTEXT

---
*Phase*: 4
*Name*: Integration Layer
*Project*: xGelo — Free Elo + xG Forecasting for UEFA World Cup Qualifiers
*Last Updated*: 2026-06-03
*Status*: Decisions locked, ready for planning
---

## Phase Goal

Combine xG and Elo outputs into team-match metrics and form indicators to enable predictive modeling in Phase 5.

## Decisions

### Integration Scope
- **Decision**: Create two core integration outputs: team-match xG metrics and rolling form metrics
- **Rationale**: These provide the features needed for the forecasting models in Phase 5
- **Implication**: Focus on computing aggregated metrics, not building prediction models yet

### Team-Match xG Metrics (INTEGR-01)
- **Decision**: Compute xG For (xGF), xG Against (xGA), xG Difference (xGD), and shots per 90 for each team in each match
- **Rationale**: These are standard football analytics metrics that capture attacking and defensive performance
- **Data Sources**: StatsBomb event data (from Phase 1) + xG model (from Phase 2)
- **Handling Missing Data**: Matches with no shot data return NA with a flag column
- **Feature**: `shots_per_90` = total shots / (match minutes / 90)

### Rolling Form Metrics (INTEGR-02)
- **Decision**: Use Exponentially Weighted Moving Average (EWMA) over 6-12 competitive matches
- **Rationale**: EWMA gives more weight to recent matches while still considering historical performance
- **Configuration**: Most recent match has weight 1, with configurable decay factor
- **Span**: Default to 12 matches, but make configurable
- **Inputs**: Elo ratings (from Phase 3) + team-match xG metrics (from INTEGR-01)
- **Outputs**: Rolling form metrics per team

### Data Flow
```
Phase 1 (Data) → StatsBomb events
                     ↓
Phase 2 (xG) → xG model
      ↓
Phase 4 (Integration) → team-match xG metrics ← StatsBomb + xG
                        ↓
                        rolling form metrics ← xG metrics + Elo
                      ↓
Phase 5 (Forecasting) → goal models ← integrated metrics
```

### Technical Approach
- **xG Metrics**: For each match, aggregate shot xG values by team using the xG model from Phase 2
- **EWMA Implementation**: Use stats::filter or manual calculation with configurable alpha (decay factor)
- **Missing Data**: Graceful handling with NA values and flags
- **Configurability**: All parameters (EWMA span, decay, etc.) should be configurable via function arguments

### File Outputs
- `R/integration/team_match_xg.R`: Computes xGF, xGA, xGD, shots_per_90
- `R/integration/rolling_form.R`: Computes EWMA-based form metrics
- `data/processed/team_match_xg.csv`: Team-match level xG metrics
- `data/processed/rolling_form.csv`: Rolling form metrics per team

### Dependencies
- **Phase 2 (xG Model)**: xG model at `models/xg_model.rds` and feature extraction code at `R/xg/features.R`
- **Phase 1 (Data Ingestion)**: StatsBomb events at `data/raw/statsbomb/events/*.json`
- **Phase 3 (Elo)**: Elo ratings at `data/processed/elo_ratings.csv` for form metric enrichment

### Constraints
- StatsBomb data is domestic leagues only (excludes international tournaments per Phase 1 decisions)
- xG model uses distance, angle, header, open_play, competition features (per Phase 2 decisions)
- All outputs must be reproducible and deterministic

### Validation Strategy
- Unit tests for metric calculations
- Spot-checks: verify xGF + xGA ≈ total xG for match
- NA handling: ensure missing data doesn't break pipeline

---
*Context locked: 2026-06-03 | Next: /gsd-plan-phase 4*
