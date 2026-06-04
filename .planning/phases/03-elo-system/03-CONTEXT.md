# Phase 3: Elo Rating System — CONTEXT

---
*Phase*: 3
*Name*: Elo Rating System
*Project*: xGelo — Free Elo + xG Forecasting for UEFA World Cup Qualifiers
*Last Updated*: 2026-06-03
*Status*: Decisions locked, ready for planning
*Dependencies*: Phase 1 (DATA-01, DATA-02 for martj42 results data)
*Parallelizable*: Yes (with Phase 2)

---

## Phase Goal

Implement a custom Elo rating system for international football using martj42 historical results data, with configurable k-factor, home advantage, and rating decay. Compute ratings for all teams from 1872-present and tune parameters via rolling-origin validation.

---

## Decisions

### Elo Formula
- **Decision**: Use **standard Elo formula with adjustments**
- **Specification**:
  - Base formula: `R_new = R_old + K * (actual_result - expected_result)`
  - Expected result: `E = 1 / (1 + 10^((R_b - R_a) / 400))`
  - Actual result: 1 for win, 0.5 for draw, 0 for loss
- **Rationale**: Standard Elo formula used in football rating systems (FIFA, Betfair)
- **Implication**: Matches common practice, interpretable, extensible
- **Reference**: Betfair Elo tutorial (https://betfair-datascientists.github.io/modelling/soccerEloTutorialR/)

### Base Rating
- **Decision**: **1500 points** as base rating for new teams
- **Rationale**: Standard Elo starting point; ensures new teams don't start at 0 or extreme values
- **Implication**: All new teams start at 1500 and adjust based on results

### K-Factor (Development Coefficient)
- **Decision**: **Variable k-factor based on match frequency**
- **Specification**:
  - `k = 20` for teams with ≥15 matches/year (active national teams)
  - `k = 40` for teams with <15 matches/year (less active teams)
- **Rationale**: More active teams have more data, so smaller k-factor provides stability; less active teams need larger k-factor to adjust faster
- **Implication**: Requires tracking match frequency per team per year
- **Reference**: ROADMAP.md ELO-04

### Home Advantage
- **Decision**: **60 points** for home team in non-neutral venues
- **Specification**:
  - Home team rating adjusted: `R_home_adjusted = R_home + 60`
  - Away team rating: `R_away` (unchanged)
  - Neutral venue: no adjustment (0 points)
- **Rationale**: Empirical value used in football Elo systems; accounts for home field advantage
- **Implication**: Consistent with common practice
- **Reference**: ROADMAP.md ELO-03

### Rating Decay
- **Decision**: **Exponential decay** based on days since last match
- **Specification**:
  - Decay factor: `0.995^(days_since_last_match / 365)`
  - Applied before each rating update
- **Rationale**: Teams lose rating over time due to inactivity; 0.995 decay means ~0.5% loss per day, ~183 points per year
- **Implication**: Encourages regular play, penalizes inactivity
- **Reference**: ROADMAP.md ELO-04

### Match Result Interpretation
- **Decision**: Use **standard football result mapping**
- **Specification**:
  - Win: 1 point
  - Draw: 0.5 points
  - Loss: 0 points
- **Rationale**: Standard mapping for Elo in football
- **Implication**: Consistent with FIFA and other rating systems

### Temporal Ordering
- **Decision**: **Process matches chronologically**
- **Rationale**: Elo ratings depend on chronological order; must process from earliest to latest
- **Implication**: Requires sorting martj42 results by date before processing

### Rolling-Origin Validation
- **Decision**: **Leave-one-out by date**
- **Specification**:
  - For each match, compute Elo ratings using only data BEFORE that match
  - Predict match outcome using pre-match ratings
  - Compare predicted vs actual to evaluate k-factor and home advantage
- **Rationale**: Temporal validation simulates real-world prediction
- **Implication**: XG-04 success criteria satisfied

### Output Format
- **Decision**: **CSV with rating history**
- **Specification**:
  - File: `data/processed/elo_ratings.csv`
  - Columns: date, home_team, away_team, home_rating_pre, away_rating_pre, home_rating_post, away_rating_post, home_advantage, k_factor_home, k_factor_away, actual_result, predicted_result
- **Rationale**: Complete audit trail for reproducibility and analysis

---

## Locked Decisions from Prior Phases

### From Phase 1 (Data Ingestion)
- **martj42 Source**: GitHub raw URLs, data loaded to `data/raw/martj42/results.csv`
- **Team Name Mapping**: `data/raw/team_name_map.csv` with FIFA codes for canonical identification
- **Data Directory**: `data/raw/martj42/` with results, goalscorers, shootouts

### From Phase 2 (xG Model)
- **StatsBomb Data**: Sample data ingested, feature extraction working
- **Model Trained**: xG model with AUC 0.7905 on test set

### From PROJECT.md
- **Language**: R (non-negotiable)
- **Orchestration**: targets framework for reproducible pipelines
- **Data**: Only free, publicly available data (martj42 for Elo)

---

## Implementation Constraints

1. **Data Source**: Use only martj42 `results.csv` for Elo calculations
2. **Team Identification**: Use FIFA codes from `team_name_map.csv` for consistent team matching
3. **Chronological Processing**: Matches MUST be processed in date order
4. **Reproducibility**: Same input data must produce same ratings (deterministic)
5. **Performance**: Must process all historical matches (1872-present, ~49k matches) in < 5 minutes

---

## Success Criteria Alignment

| Requirement | Decision | Success Metric |
|-------------|----------|----------------|
| ELO-01 | Standard Elo formula with adjustments | `compute_elo()` is pure function with configurable parameters |
| ELO-02 | Process all martj42 results chronologically | Elo ratings computed for all teams 1872-present |
| ELO-03 | Home advantage = 60 points | Home rating adjusted by 60 for non-neutral matches |
| ELO-04 | Variable k-factor (20/40) + decay | Rolling-origin validation, parameters tuned |

---

## Open Questions / Deferred

1. **Alternative Elo Variants**: Glicko, Glicko-2, TrueSkill could provide uncertainty estimates. **Deferred** to future enhancements.
2. **Team Strength Normalization**: Normalizing by average rating or to fixed scale. **Deferred** to post-MVP.
3. **Margin of Victory**: Incorporating goal difference into Elo. **Deferred** - standard Elo uses only win/draw/loss.
4. **Tournament Weighting**: Weighting matches by tournament importance. **Deferred** - could use tournament classification from Phase 1.

---
*Decisions locked: 2026-06-03 | Next: /gsd-plan-phase 3*
