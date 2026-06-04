# xGelo Architecture: Elo + xG Football Forecasting System

---

## Component Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              xGelo Forecasting System                              │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│  ┌──────────────────────┐     ┌──────────────────────┐     ┌──────────────────┐ │
│  │    DATA LAYER         │     │      xG LAYER         │     │    ELO LAYER     │ │
│  │                      │     │                      │     │                  │ │
│  │  ┌──────────────────┐ │     │  ┌──────────────────┐ │     │  ┌──────────────┐ │ │
│  │  │ martj42          │◄────►│  │ Feature Eng       │ │     │  │ Elo Calc      │ │ │
│  │  │ - results.csv    │ │     │  │ - distance       │ │     │  │ - ratings     │ │ │
│  │  │ - shootouts.csv  │ │     │  │ - angle          │ │     │  │ - history     │ │ │
│  │  │ - goalscorers.csv│ │     │  │ - body_part      │ │     │  │ - k-factor    │ │ │
│  │  └──────────────────┘ │     │  └──────────────────┘ │     │  └──────────────┘ │ │
│  │                          │     │  ┌──────────────────┐ │     │                  │ │
│  │  ┌──────────────────┐ │     │  │ Model Training    │ │     │  ┌──────────────┐ │ │
│  │  │ StatsBomb Open   │─────►│  │ - logistic reg   │ │     │  │ Backtesting   │ │ │
│  │  │ - events         │ │     │  │ - splines        │ │     │  └──────────────┘ │ │
│  │  │ - lineups        │ │     │  │ - calibration    │ │     └──────────────────┘ │
│  │  │ - competitions   │ │     │  └──────────────────┘ │                              │
│  │  └──────────────────┘ │     └──────────────────────┘                       │
│  │                          │                                              │
│  │  ┌──────────────────┐ │                                              │
│  │  │ WCQ Cache        │◄──────────────────────────────────────────────────┘ │
│  │  │ - FotMob manual  │ │                                              │
│  │  │ - UEFA/FIFA      │──────────────────────────────────────────────────►│ │
│  │  └──────────────────┘ │     ┌──────────────────────┐                       │ │
│  └──────────────────────┘     │  ┌──────────────────┐ │                       │ │
│                                │  │ Team-Match xG     │◄──────────────┐         │ │
│                                │  │ - xGF, xGA, xGD   │ │     ┌──────────────────┐ │ │
│                                │  └──────────────────┘ │     │ FORECAST LAYER   │ │ │
│                                │  ┌──────────────────┐ │     │ - Poisson models │ │ │
│                                │  │ Rolling Form      │────►│ - Monte Carlo   │ │ │
│                                │  │ - EWMA 6-12       │ │     │ - probabilities │ │ │
│                                │  └──────────────────┘ │     └──────────────────┘ │ │
│                                └──────────────────────┘                           │
│                                                                                     │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                        targets PIPELINE ORCHESTRATION                       │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Component Boundaries

### Layer 1: Data Layer

| Component | Inputs | Outputs | Boundaries | Dependencies |
|-----------|--------|---------|------------|--------------|
| `martj42_ingest` | GitHub/Kaggle raw files | `results.csv`, `shootouts.csv`, `goalscorers.csv` | Read-only source | None |
| `team_name_mapper` | Raw martj42, StatsBomb, WCQ | Normalized team names | Pure function | `martj42_ingest` |
| `statsbomb_ingest` | GitHub JSON | Events, lineups, competitions | Read-only source | None |
| `wcq_cache` | FotMob/UEFA/FIFA pages | Cached shot files, fixtures | Manual write, read-only for pipeline | None |

**Boundary Rule**: Data layer components NEVER modify sources. All writes go to `data/raw/` or `data/cache/`.

---

### Layer 2: xG Layer

| Component | Inputs | Outputs | Boundaries | Dependencies |
|-----------|--------|---------|------------|--------------|
| `xg_features` | StatsBomb events | Shot features: distance, angle, header, open_play | Pure transformation | `statsbomb_ingest` |
| `xg_model` | Shot features + outcomes | Trained logistic regression | Model artifact | `xg_features` |
| `xg_calibration` | Model predictions, test set | Calibration curves, adjustments | Stateless | `xg_model` |
| `xg_backtest` | Model, historical data | AUC, calibration metrics | Validation only | `xg_model` |

**Boundary Rule**: xG layer depends ONLY on StatsBomb Open Data (training) and WCQ cache (target). No circular dependencies.

---

### Layer 3: Elo Layer

| Component | Inputs | Outputs | Boundaries | Dependencies |
|-----------|--------|---------|------------|--------------|
| `elo_runner` | martj42 results | Elo ratings per team per date | Pure function of results | `martj42_ingest`, `team_name_mapper` |
| `elo_tuner` | Results, ratings | Optimized k-factor, home_adv | Hyperparameter search | `elo_runner` |
| `elo_backtest` | Ratings, future results | Prediction accuracy | Validation only | `elo_runner` |

**Boundary Rule**: Elo layer consumes ONLY martj42 results. No dependency on xG layer.

---

### Layer 4: Integration Layer

| Component | Inputs | Outputs | Boundaries | Dependencies |
|-----------|--------|---------|------------|--------------|
| `team_match_xg` | WCQ cache, xg_model | xGF, xGA, xGD per team-match | Aggregation only | `wcq_cache`, `xg_model` |
| `rolling_form` | team_match_xg | EWMA xGF, xGA, xGD | Stateful window | `team_match_xg` |
| `feature_table` | rolling_form, elo_ratings, fixtures | Match-level features | Join only, no logic | `rolling_form`, `elo_runner` |

**Boundary Rule**: Integration layer is the ONLY place where xG and Elo data combine. Downstream layers depend on `feature_table`, never on raw xG or Elo directly.

---

### Layer 5: Forecast Layer

| Component | Inputs | Outputs | Boundaries | Dependencies |
|-----------|--------|---------|------------|--------------|
| `poisson_models` | feature_table | Home/away goal lambdas | Statistical models | `feature_table` |
| `monte_carlo` | goal lambdas | Simulated scenarios | Pure function | `poisson_models` |
| `forecast_output` | scenarios | Win/draw/loss %, expected goals | Aggregation | `monte_carlo` |
| `forecast_calibration` | predictions, results | Calibration adjustment | Validation | `forecast_output` |

**Boundary Rule**: Forecast layer consumes ONLY `feature_table`. All randomness is seeded and reproducible.

---

### Layer 6: Pipeline Orchestration

| Component | Purpose | Boundaries |
|-----------|---------|------------|
| `_targets.R` | Pipeline definition | Defines DAG, no business logic |
| `targets` | Execution engine | Manages dependencies, caching |
| `schema_validation` | Data quality | Runs after each ingest target |

**Boundary Rule**: Pipeline layer knows about ALL components but contains NO domain logic.

---

## Data Flow

```
                    ┌─────────────────────────────────────────────────────────┐
                    │                     DATA FLOW                               │
                    ├─────────────────────────────────────────────────────────┤
                    │                                                             │
                    │  OPEN DATA SOURCES                                         │
                    │  ┌──────────────┐    ┌──────────────┐                   │
                    │  │ martj42       │    │ StatsBomb     │                   │
                    │  │ results       │    │ events        │                   │
                    │  └───────┬───────┘    └───────┬───────┘                   │
                    │          │                  │                            │
                    │          ▼                  ▼                            │
                    │  ┌──────────────────────────────────────────┐            │
                    │  │              INGEST                       │            │
                    │  │  - normalize team names                   │            │
                    │  │  - validate schemas                       │            │
                    │  │  - version raw files                      │            │
                    │  └──────────────────┬───────────────────────┘            │
                    │                     │                                        │
                    │        ┌────────────▼────────────┐                         │
                    │        │                         │                         │
                    │        ▼                         ▼                         │
                    │  ┌──────────────┐          ┌──────────────┐                │
                    │  │ Elo Layer    │          │ xG Layer     │                │
                    │  │              │          │              │                │
                    │  │ results ──►  │          │ events ──►  │                │
                    │  │ ratings      │          │ features ──►│                │
                    │  │              │          │ model       │                │
                    │  └──────┬───────┘          └──────┬───────┘                │
                    │         │                         │                         │
                    │         └─────────────────────────┼─────────────────┐     │
                    │                                   ▼                     │     │
                    │                    ┌─────────────────────────────┐      │
                    │                    │     Integration Layer         │      │
                    │                    │  feature_table = f(xG, Elo)  │      │
                    │                    └────────────┬────────────────┘      │
                    │                                     │                          │
                    │                                     ▼                          │
                    │                    ┌─────────────────────────────┐      │
                    │                    │      Forecast Layer          │      │
                    │                    │  - Poisson regression        │      │
                    │                    │  - Monte Carlo (50k sims)    │      │
                    │                    │  - Win/Draw/Loss probs       │      │
                    │                    └─────────────────────────────┘      │
                    │                                                             │
                    │  CACHED DATA SOURCES (manual)                              │
                    │  ┌──────────────┐                                         │
                    │  │ WCQ Cache     │──────────────────────────────────►│
                    │  │ FotMob/UEFA   │         (optional, manual only)     │
                    │  └──────────────┘                                         │
                    └─────────────────────────────────────────────────────────┘
```

### Flow Rules

1. **Open data flows automatically**: martj42 → Elo; StatsBomb → xG model
2. **Cached data flows manually**: FotMob/UEFA → WCQ cache (triggered by user, not pipeline)
3. **Integration is one-way**: xG and Elo data meet ONLY in `feature_table`
4. **Forecast is downstream-only**: Consumes `feature_table`, never raw sources
5. **No backward flow**: Forecast layer never writes to data layers

---

## Build Order

### Phase 0: Foundation (Prerequisites)
- 0.1 Directory structure
- 0.2 targets configuration
- 0.3 R package dependencies (tidymodels, elo, httr2)
- 0.4 Git setup + .gitignore

**Dependencies**: None

---

### Phase 1: Data Ingestion
- 1.1 martj42 ingest (DATA-01)
- 1.2 Team name normalization (DATA-02)
- 1.3 StatsBomb Open Data ingest (DATA-03)
- 1.4 Data inventory (DATA-04)
- 1.5 Schema validation for all sources

**Dependencies**: Phase 0

---

### Phase 2: xG Model
- 2.1 Distance calculation (XG-01)
- 2.2 Angle calculation (XG-02)
- 2.3 Feature contract (XG-03)
- 2.4 Logistic regression training (XG-04)
- 2.5 Model calibration (XG-05)
- 2.6 Backtesting + AUC validation (XG-06)

**Dependencies**: Phase 1 (StatsBomb data)

---

### Phase 3: Elo Layer
- 3.1 Elo calculation (ELO-01)
- 3.2 Elo ratings from all international matches (ELO-02)
- 3.3 Home advantage adjustment (ELO-03)
- 3.4 K-factor tuning (ELO-04)

**Dependencies**: Phase 1 (martj42 data)
**Parallelizable**: Yes — independent of Phase 2

---

### Phase 4: Integration Layer
- 4.1 Team-match xG metrics (INTEGR-01)
- 4.2 Rolling form with EWMA (INTEGR-02)
- 4.3 Feature table assembly

**Dependencies**: Phase 2 (xG model), Phase 3 (Elo ratings)

---

### Phase 5: Forecasting
- 5.1 Home goals Poisson model (FORECAST-01)
- 5.2 Away goals Poisson model (FORECAST-02)
- 5.3 Monte Carlo simulation (50k) (FORECAST-03)
- 5.4 Win/draw/loss probabilities (FORECAST-04)
- 5.5 Forecast calibration (FORECAST-05)

**Dependencies**: Phase 4 (feature_table)

---

### Phase 6: Optional WCQ Cache
- 6.1 Manual cache of WCQ shot data
- 6.2 Score WCQ shots with trained xG model
- 6.3 Integrate into team-match xG metrics

**Dependencies**: Phase 2 (xG model), Phase 1 (WCQ fixtures)
**Boundaries**: Manual process only — NOT automated

---

### Phase 7: Pipeline & Validation
- 7.1 targets pipeline DAG (PIPELINE-01)
- 7.2 Cache directory structure (PIPELINE-02)
- 7.3 Schema validation (PIPELINE-03)
- 7.4 Unit tests (TEST-01, TEST-02)
- 7.5 Integration tests (TEST-03)

**Dependencies**: All previous phases

---

### Phase 8: Visualization & Documentation
- 8.1 AUC comparison chart (VIS-01)
- 8.2 Calibration plots (VIS-02)
- 8.3 Research notebook (DOC-01)
- 8.4 Technical documentation (DOC-02)

**Dependencies**: Phase 5 (forecasts), Phase 2 (xG backtests)

---

## Dependency Graph

```
Phase 0 (Infra)
    │
    ▼
Phase 1 (Data) ──┬── Phase 2 (xG Model)
                 │
                 └── Phase 3 (Elo Layer) ────┐
                                              │
Phase 4 (Integration) ←──────────────────────┘
    │
    ▼
Phase 5 (Forecast)
    │
    ▼
Phase 7 (Pipeline)
    │
    ▼
Phase 8 (Docs)

Phase 6 (WCQ Cache) ──┬──► Phase 4 (enhancement)
                       │
                       └──► Phase 5 (improved forecasts)
```

### Critical Path (MVP)
```
Phase 0 → Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 7 → Phase 8
```

### Parallelizable Paths
- Phase 2 (xG) and Phase 3 (Elo) can run in parallel after Phase 1
- Phase 6 (WCQ Cache) can run anytime after Phase 2, independent of Phase 3

---

## File Structure

```
xGelo/
├── .planning/
│   └── research/
│       └── ARCHITECTURE.md          # This file
├── R/
│   ├── data_ingest/                 # Phase 1
│   │   ├── martj42.R
│   │   ├── statsbomb.R
│   │   └── team_names.R
│   ├── xg/                         # Phase 2
│   │   ├── features.R
│   │   ├── model.R
│   │   ├── calibration.R
│   │   └── backtest.R
│   ├── elo/                        # Phase 3
│   │   ├── runner.R
│   │   ├── tuning.R
│   │   └── backtest.R
│   ├── integration/                # Phase 4
│   │   ├── team_match_xg.R
│   │   ├── rolling_form.R
│   │   └── feature_table.R
│   ├── forecast/                   # Phase 5
│   │   ├── poisson.R
│   │   ├── monte_carlo.R
│   │   └── calibration.R
│   ├── wcq/                        # Phase 6
│   │   ├── cache.R
│   │   └── scoring.R
│   └── pipeline/                   # Phase 7
│       ├── _targets.R
│       ├── validation.R
│       └── tests/
├── data/
│   ├── raw/                        # Immutable source dumps
│   │   ├── martj42/
│   │   ├── statsbomb/
│   │   └── wcq_cache/
│   ├── processed/                  # Cleaned, normalized
│   ├── models/                     # Serialized model artifacts
│   └── cache/                      # targets pipeline cache
├── outputs/                        # Generated artifacts
│   ├── forecasts/
│   ├── visualizations/
│   └── notebooks/
└── _targets.R                      # Main pipeline definition
```

---

## Interface Contracts

### Data Layer → xG Layer
```r
# Output of data layer, input to xG layer
sb_events <- list(
  x = numeric,      # 0-120
  y = numeric,      # 0-80
  shot_outcome = character,  # "Goal", "Saved", etc.
  shot_body_part = character, # "Head", "Right Foot", etc.
  play_pattern = character    # "Regular Play", "From Corner", etc.
)
```

### Data Layer → Elo Layer
```r
# Output of data layer, input to Elo layer
intl_results <- tibble(
  date = Date,
  home_team = character,
  away_team = character,
  home_score = integer,
  away_score = integer,
  tournament = character,
  neutral = logical
)
```

### xG Layer → Integration Layer
```r
# Output of xG layer
xg_model <- list(
  recipe = recipe,
  fit = workflow,
  calibration = tibble,
  performance = tibble  # AUC, etc.
)

# Function contract
score_shots <- function(shots, model) {
  # Input: shots with x, y, body_part, play_pattern
  # Output: shots with xg probability added
}
```

### Elo Layer → Integration Layer
```r
# Output of Elo layer
elo_ratings <- tibble(
  date = Date,
  team = character,
  elo = numeric,
  home_adv = numeric  # Implicit in neutral flag
)

# Function contract
get_elo_diff <- function(home_team, away_team, date, ratings) {
  # Output: elo difference for match
}
```

### Integration Layer → Forecast Layer
```r
# Output of integration layer
feature_table <- tibble(
  match_id = character,
  date = Date,
  home_team = character,
  away_team = character,
  elo_diff = numeric,
  home_xgf_ewma = numeric,
  away_xgf_ewma = numeric,
  home_xga_ewma = numeric,
  away_xga_ewma = numeric,
  home_shots90_ewma = numeric,
  away_shots90_ewma = numeric,
  non_neutral_home = logical,
  rest_diff = numeric  # Optional
)

# One row per match, all features available before kickoff
```

---

## Legal Boundaries

| Component | Data Source | License | Usage Rule |
|-----------|-------------|---------|------------|
| martj42 ingest | GitHub/Kaggle | CC0/Open | Automatic, cite source |
| StatsBomb ingest | GitHub | CC BY-NC-SA 4.0 | Automatic, cite + logo |
| WCQ cache | FotMob/UEFA | Public web | Manual only, no redistribution |
| WCQ cache | FIFA | Public web | Manual only, rate-limited |

**Enforcement**: Pipeline will NOT include automated FotMob scraping. WCQ cache is populated manually via user action, not code.

---

## Performance Boundaries

| Component | Target | Measurement |
|-----------|--------|-------------|
| xG model | AUC ≥ 0.75 | Backtest on held-out StatsBomb data |
| xG model (stretch) | AUC ≥ 0.79 | With extended features |
| Forecast calibration | Draw freq ±5% | Compare predicted vs observed |
| Monte Carlo | 50k sims/fixture in <10s | Benchmark on M1/M2 Mac |

---
*Architecture version: 1.0 | Last updated: 2026-06-03*
