# xGelo: Free Elo + xG Forecasting for UEFA World Cup Qualifiers

---
*Project Code: XGELO* | *Language: R* | *Domain: Sports Analytics / Football Forecasting*

## What This Is

A **free, open-data** forecasting system that combines **Elo ratings** with **expected goals (xG)** to predict UEFA World Cup Qualifiers match outcomes. The system is designed as a **hybrid solution**: using open-licensed data for model training (StatsBomb Open Data) and carefully cached public data for WCQ-specific target predictions (FotMob), while maintaining legal compliance and reproducibility.

## Core Value

**Accurate football match forecasting without paid data feeds** — Provide reliable win/draw/loss probabilities and goal expectations for UEFA World Cup Qualifiers by combining team strength (Elo) with attacking efficiency (xG), using only freely available data sources.

## Context

### The Problem
Building a competitive football forecasting model typically requires expensive data feeds (Opta, StatsBomb paid tier, etc.). For international football, particularly World Cup Qualifiers, open alternatives are fragmented. The challenge is: **Can we build a production-grade forecasting system using only free, publicly available data?**

### The Opportunity
Recent research demonstrates that:
- **Elo ratings** from historical international results (martj42 dataset: 1872-present) provide robust team strength estimates
- **xG models** trained on StatsBomb Open Data achieve AUC 0.75-0.826 using minimal, interpretable features (distance, angle, body part, play pattern)
- **Hybrid architectures** separating training sources from target sources can deliver practical value while respecting licensing constraints

### The Gap
While training data is abundant (StatsBomb Open Data covers World Cups, Euros, and select leagues), **WCQ-UEFA shot data is not openly licensed**. The most practical free source, FotMob, prohibits systematic/automated use. This requires a **modular, cache-first architecture** that cleanly separates model training from prediction-time data collection.

## Constraints

### Technical Constraints
- **Language**: R (non-negotiable — aligns with existing ecosystem and researcher expertise)
- **Orchestration**: targets framework for reproducible, incremental pipelines
- **Modelling**: tidymodels ecosystem for consistency and maintainability
- **HTTP**: httr2 for robust web requests with retry logic and rate limiting

### Data Constraints
| Source | Status | Use Case | Constraint |
|--------|--------|----------|------------|
| martj42 | ✅ Open | Elo backbone | Team name harmonization needed |
| StatsBomb Open Data | ✅ Open | xG model training | WCQ-UEFA not included |
| FotMob | ⚠️ Restricted | WCQ shot data | ToS prohibits automated use; manual cache only |
| FBref | ❌ Limited | Historical data | Advanced metrics removed Jan 2026; rate-limited |
| UEFA/FIFA pages | ✅ Public | Fixtures, line-ups | No API; careful parsing required |
| Transfermarkt | ⚠️ Restricted | Injury data | No clean national-team feed |
| Understat | ⚠️ Restricted | League shot data | No international coverage |

### Legal Constraints
- **No redistribution** of raw data from restricted sources (FotMob, FBref, Transfermarkt)
- **Local caching only** for public web data with ToS restrictions
- **Minimal, manual requests** to stay within fair use
- **Open data preference**: StatsBomb and martj42 are the foundation; others are supplements

### Performance Constraints
- **Baseline target**: AUC ≥ 0.75 for xG model (achievable with minimal features)
- **Stretch target**: AUC ≥ 0.79 with mixed-effects extensions
- **Calibration**: Predicted probabilities must match observed frequencies
- **Speed**: Simulation of 50,000 scenarios per fixture in < 10 seconds

### Operational Constraints
- **Reproducibility**: Every output traceable to source data and code version
- **Incrementality**: targets pipeline ensures only changed data is reprocessed
- **Modularity**: Components (data, xG model, Elo, forecasting) can be developed and tested independently
- **Maintainability**: Clear separation between open training data and cached target data

## What This Is NOT

- A real-time live scoring system
- A commercial betting product
- A full-featured sports data API
- A system dependent on paid data feeds
- A black-box model — interpretability is a core requirement

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| **R as primary language** | Existing expertise, strong data science ecosystem (tidymodels, targets), researcher preference | Confirmed |
| **Hybrid data architecture** | Open training data + cached target data balances legal compliance with practical utility | Confirmed |
| **Minimalist xG feature contract** | Distance, angle, body part, play pattern are robustly derivable and achieve AUC ≥ 0.75; avoids fragile features | Confirmed |
| **Targets for orchestration** | Designed for reproducible, incremental analytical projects; ideal for this use case | Confirmed |
| **Elo from all international matches** | National teams play few games; qualifiers-only sample too sparse for reliable ratings | Confirmed |
| **Logistic regression baseline** | Interpretable, fast, good performance; can extend to mixed-effects later | Confirmed |
| **Poisson goal model** | Standard for football forecasting; supports Monte Carlo simulation | Confirmed |
| **FotMob as optional layer** | Most practical WCQ shot source but ToS-restricted; manual cache only | Pending validation |
| **Three operating modes** | Open (no WCQ shots), Hybrid (cached FotMob), Experimental (full archive) — allows progressive enhancement | Pending |

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] **DATA-01**: Ingest martj42 international results dataset
- [ ] **DATA-02**: Normalize team names across sources (Turkey/Türkiye, Macedonia/North Macedonia, etc.)
- [ ] **DATA-03**: Download and cache StatsBomb Open Data events and line-ups
- [ ] **DATA-04**: Create data inventory documenting source, license, coverage for each dataset
- [ ] **XG-01**: Implement shot distance calculation from coordinates
- [ ] **XG-02**: Implement shot angle calculation from coordinates
- [ ] **XG-03**: Build minimal xG feature contract (distance, angle, header, open_play, competition)
- [ ] **XG-04**: Train logistic regression xG model with splines for distance and angle
- [ ] **XG-05**: Calibrate xG model on held-out test set
- [ ] **XG-06**: Backtest xG model performance (AUC, calibration plots)
- [ ] **ELO-01**: Implement Elo rating calculation using R elo package
- [ ] **ELO-02**: Compute Elo ratings across all men's international matches from martj42
- [ ] **ELO-03**: Add home advantage adjustment (60 points for non-neutral home matches)
- [ ] **ELO-04**: Tune Elo k-factor and home advantage via rolling-origin validation
- [ ] **INTEGR-01**: Create aggregated team-match xG metrics (xGF, xGA, xGD, shots per 90)
- [ ] **INTEGR-02**: Compute rolling form metrics with EWMA over 6-12 matches
- [ ] **FORECAST-01**: Build Poisson regression model for home goals
- [ ] **FORECAST-02**: Build Poisson regression model for away goals
- [ ] **FORECAST-03**: Implement Monte Carlo simulation engine (50,000 scenarios per fixture)
- [ ] **FORECAST-04**: Generate win/draw/loss probabilities and expected goals
- [ ] **FORECAST-05**: Calibrate forecast model (ensure predicted draw frequency matches reality)
- [ ] **PIPELINE-01**: Implement targets pipeline with clear dependency graph
- [ ] **PIPELINE-02**: Set up local cache directory structure with versioning
- [ ] **PIPELINE-03**: Create schema validation for all ingested data
- [ ] **VIS-01**: Create AUC comparison chart showing performance by feature set
- [ ] **VIS-02**: Generate calibration plots for both xG and forecast models
- [ ] **TEST-01**: Unit tests for xG feature calculations
- [ ] **TEST-02**: Unit tests for Elo calculation logic
- [ ] **TEST-03**: Integration test for full pipeline execution
- [ ] **DOC-01**: Reproducible research notebook showing model performance
- [ ] **DOC-02**: Technical documentation for pipeline setup and execution

### Out of Scope

- **Real-time data collection** — Manual cache updates only; no continuous scraping
- **FBref integration** — Advanced data removed; not reliable as primary source
- **Tracking data (360)** — Not available in free datasets for WCQ
- **Injury/suspension modelling** — No clean free data source for national teams
- **Live betting integration** — Not a commercial product
- **Mobile app or web dashboard** — Focus on model and pipeline, not UI
- **Women's football** — Scope limited to men's WCQ-UEFA (can extend later)
- **Youth tournaments** — Focus on senior national teams only

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         xGelo Forecasting System                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐         │
│  │  Data Layer  │    │ xG Model     │    │ Elo Layer    │         │
│  │              │    │              │    │              │         │
│  │ • martj42    │───▶│ • Features    │    │ • All intl   │         │
│  │ • StatsBomb  │    │ • Training    │    │   matches    │         │
│  │ • WCQ Cache  │    │ • Calibration │    │ • Ratings    │         │
│  │ • UEFA/FIFA  │    │ • Backtests   │    │ • Tuning     │         │
│  └──────────────┘    └──────────────┘    └──────────────┘         │
│           │                 │                    │                  │
│           └─────────────────┼────────────────────┘                  │
│                             ▼                                          │
│                  ┌─────────────────────────┐                          │
│                  │   Integration Layer     │                          │
│                  │                         │                          │
│                  │ • Team-match xG metrics │                          │
│                  │ • Rolling form factors  │                          │
│                  │ • Feature table         │                          │
│                  └─────────────────────────┘                          │
│                                    │                                   │
│                                    ▼                                   │
│                  ┌─────────────────────────┐                          │
│                  │    Forecasting Layer    │                          │
│                  │                         │                          │
│                  │ • Poisson goal models  │                          │
│                  │ • Monte Carlo sim       │                          │
│                  │ • Probability outputs   │                          │
│                  └─────────────────────────┘                          │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐│
│  │                    targets Pipeline Orchestration                  ││
│  └─────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────┘
```

## Success Criteria

### MVP (v0.1)
- [ ] xG model trained on StatsBomb Open Data with AUC ≥ 0.75
- [ ] Elo ratings computed from martj42 dataset
- [ ] Basic forecast model producing win/draw/loss probabilities
- [ ] targets pipeline running end-to-end
- [ ] Documentation for setup and execution

### v0.2
- [ ] xG model AUC ≥ 0.79 with extended features
- [ ] Forecast calibration within 5% of observed draw frequency
- [ ] Team-match xG metrics integrated
- [ ] Monte Carlo simulation producing goal expectations

### v0.3 (Stretch)
- [ ] Mixed-effects xG model with team random effects
- [ ] Sequence-aware xG model using preceding events
- [ ] Hybrid WCQ shot data layer (cached FotMob)
- [ ] Full backtesting framework with rolling-origin evaluation

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-06-03 after initialization*
