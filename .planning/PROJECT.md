# xGelo: Free Elo + xG Forecasting for UEFA World Cup Qualifiers

---
*Project Code: XGELO* | *Language: R* | *Domain: Sports Analytics / Football Forecasting*

## What This Is

A **free, open-data-first** forecasting system for men's international football that combines team-strength ratings, goal models, expected goals (xG), and tournament simulation. It produces leakage-safe match probabilities and tournament forecasts while keeping restricted data optional, local, and auditable.

## Core Value

**Accurate, calibrated international-football forecasting without dependence on paid data feeds.**

## Current Milestone: v3.0 UEFA Competition Forecast Dashboards

**Goal:** Build two public, automatically refreshed dashboards for the 2026/27 UEFA Nations League and UEFA EURO 2028 qualifying cycle.

**Target features:**
- Publish dedicated Nations League and EURO qualifying entry points through one shared dashboard engine.
- Show competition-specific groups, standings, fixtures, results, form, calibrated match forecasts, and simulated outcomes.
- Use official UEFA competition data with auditable fallbacks and preserve the shared open-data model and release contracts.
- Refresh both dashboards hourly through the existing fail-closed launchd workflow.

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
| **UEFA source contract** | Structured, edition-scoped source bundles with ignored raw bytes, explicit provenance, and reviewed fallback keep public capture auditable | Confirmed in Phase 13 |
| **Dual-edition publication boundary** | Both competition editions share one locked fourteen-target normalized publication transaction while blocked refresh history remains separate | Confirmed in Phase 13 |
| **EURO activation gate** | EURO qualifying remains explicitly `pre_draw` until a complete accepted official draw-and-schedule bundle proves activation; date-only or candidate-level lifecycle text cannot activate it | Confirmed in Phase 16 |
| **EURO qualification topology** | Host capacity, best runners-up, Nations League eligibility, and play-off topology are derived from validated lineage and fail closed on unresolved rules or inputs | Confirmed in Phase 16 |
| **Outcome publication rollback** | Retain the incumbent EURO outcomes backup through promoted read-back validation and restore it byte-for-byte after a promotion or read-back failure | Confirmed in Phase 16 |
| **FotMob as optional layer** | Most practical WCQ shot source but ToS-restricted; manual cache only | Pending validation |
| **Three operating modes** | Open (no WCQ shots), Hybrid (cached FotMob), Experimental (full archive) — allows progressive enhancement | Pending |

## Requirements

### Validated

- ✓ Open international-results ingestion, canonical team identities, and reproducible caches — v1.0
- ✓ Calibrated open-data xG model and historical Elo rating system — v1.0
- ✓ Negative-binomial match forecasts, scoreline distributions, and Monte Carlo simulation — v1.0
- ✓ 2026 World Cup group and knockout simulation with result conditioning and dashboard publication — post-v1.0
- ✓ Automated tests, targets orchestration, model documentation, and forecast artifacts — v1.0
- ✓ Trustworthy pre-kickoff 2026 forecast ledger and retrospective scorecard — validated in Phase 8
- ✓ Leakage-safe rolling multi-tournament benchmark infrastructure and frozen promotion gates — validated in Phase 9
- ✓ UEFA source, identity, and competition-registry contracts for Nations League and EURO qualifying — validated in Phase 13
- ✓ Shared competition state and calibrated forecast authority for Nations League and EURO qualifying — validated in Phase 14
- ✓ Nations League rules, outcomes, and durable forecast bundle — validated in Phase 15
- ✓ EURO qualifying activation, official play-off rules, truthful pre-draw outcomes, and revision-safe publication — validated in Phase 16

### Active

- [ ] Implement and compare literature-backed goal and machine-learning challengers.
- [ ] Improve strength, context, xG, squad, and calibration features only when they generalize out of sample.

### Out of Scope

- **Real-time data collection** — Manual cache updates only; no continuous scraping
- **FBref integration** — Advanced data removed; not reliable as primary source
- **Tracking data (360)** — Not available in free datasets for WCQ
- **Injury/suspension modelling** — No clean free data source for national teams
- **Live betting integration** — Not a commercial product
- **Mobile app or general-purpose web application** — This milestone includes static public dashboards, not a separate mobile app or server-backed product.
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

## Current State

**v3.0:** Phases 13 through 16 are complete; Phase 17 is ready to plan the shared dashboards and atomic refresh operations.

**v1.0 MVP (Open Mode)**: ✅ **SHIPPED** - 2026-06-05

Production-ready forecasting system using only open data (martj42 + StatsBomb).

### Delivered
- **7 phases** completed with 31 requirements at 100% coverage
- **xG Model**: Logistic regression with splines, AUC = 0.7905 on held-out test set
- **Elo System**: 49,368 matches processed, 336 teams, validation AUC = 0.7916
- **Forecasting**: Negative Binomial models, Monte Carlo simulation (50,000 scenarios/fixture in <10s)
- **Pipeline**: targets orchestration with 9 targets, DAG visualization, 27 unit tests, 4 integration tests
- **Documentation**: SETUP.md, RUNBOOK.md, MODEL-CARD.md, research notebook

### Architecture Proven
```
Data (Phase 1) → xG Model (Phase 2, AUC: 0.7905)
Data (Phase 1) → Elo (Phase 3, AUC: 0.7916)
xG + Elo → Integration (Phase 4)
Integration + Elo → Forecasting (Phase 5, Brier: 0.214)
All → Pipeline & Quality (Phase 6)
Pipeline → Visualization & Docs (Phase 7)
```

### Quality Metrics
- **Code Coverage**: >80% for xG and Elo functions
- **Test Results**: 27/27 unit tests passing, 4/4 integration tests passing
- **Model Calibration**: All bins within ±5% of ideal line
- **Reproducibility**: Pipeline outputs match across runs

## v2.0 Evaluation Principles

Phase 9 is complete. The accepted benchmark now provides deterministic rolling
World Cup and European Championship folds, common baseline contracts, durable
point-in-time evidence, proper-score comparisons, and a checksum-backed promotion
protocol. Phase 10 will evaluate statistical goal-model challengers against this
frozen contract.

- The 2026 World Cup is an untouched final holdout for model comparison, not a tuning set.
- Candidate models must improve proper scoring and calibration across multiple rolling tournament folds.
- Added complexity must beat simpler Elo and count-model baselines by a predeclared promotion rule.
- Structural and market models are benchmarks or priors unless their data and licensing fit the open-data operating mode.
- Dashboard behavior remains stable while model evaluation and replacement happen behind explicit versioned contracts.

---
*Last updated: 2026-08-24 after Phase 16 completion*
