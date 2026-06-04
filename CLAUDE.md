# CLAUDE.md - xGelo Project Instructions

This file provides context and instructions for working with the xGelo project using GSD workflows.

---

## Project Overview

**xGelo**: Free, open-data forecasting system combining Elo ratings with expected goals (xG) to predict UEFA World Cup Qualifiers match outcomes.

- **Core Value**: Accurate football match forecasting without paid data feeds
- **Language**: R
- **Domain**: Sports Analytics / Football Forecasting
- **Project Code**: XGELO
- **Workflow**: GSD (Get Shit Done)

---

## Quick Reference

### GSD Commands

| Command | Purpose | When to Use |
|---------|---------|-------------|
| `/gsd-progress` | Check progress, advance workflow | Always start here |
| `/gsd-discuss-phase N` | Gather context for phase N | Before planning a phase |
| `/gsd-plan-phase N` | Create detailed plan for phase N | After discussion |
| `/gsd-execute-phase N` | Execute all plans in phase N | After planning |
| `/gsd-transition` | Transition to next phase | After phase completion |
| `/gsd-complete-milestone` | Archive completed milestone | After all phases done |

---

### Project Artifacts

| Artifact | Location | Purpose |
|----------|----------|---------|
| PROJECT.md | .planning/PROJECT.md | Project context, constraints, decisions |
| config.json | .planning/config.json | Workflow preferences |
| REQUIREMENTS.md | .planning/REQUIREMENTS.md | All requirements with traceability |
| ROADMAP.md | .planning/ROADMAP.md | Phases, success criteria, dependencies |
| STATE.md | .planning/STATE.md | Current progress tracking |
| Research | .planning/research/ | Domain research (STACK, FEATURES, ARCHITECTURE, PITFALLS, SUMMARY) |

---

### Current Status

- **Milestone**: Not Started
- **Phases**: 7 (Data → xG Model → Elo → Integration → Forecast → Pipeline → Docs)
- **Requirements**: 31 v1 (MVP), 10 v2 (deferred)
- **Progress**: 0% (0/31 complete)
- **Next Phase**: Phase 1 (Data Ingestion & Infrastructure)

---

## Project Configuration

```json
{
  "mode": "yolo",
  "granularity": "standard",
  "parallelization": true,
  "commit_docs": true,
  "model_profile": "balanced",
  "workflow": {
    "research": true,
    "plan_check": true,
    "verifier": true,
    "nyquist_validation": true,
    "auto_advance": true
  }
}
```

---

## Workflow Instructions

### Before Starting Work

1. **Check current state**: `cat .planning/STATE.md`
2. **Review roadmap**: `cat .planning/ROADMAP.md`
3. **Understand requirements**: `grep -A5 "Phase N:" .planning/ROADMAP.md`

### Starting a New Phase

1. **Discuss**: `/gsd-discuss-phase N` - Gather context, clarify approach
2. **Plan**: `/gsd-plan-phase N` - Create detailed execution plan
3. **Review**: Check PLAN.md for the phase
4. **Execute**: `/gsd-execute-phase N` - Run the plan

### During Execution

- Commit early and often with descriptive messages
- Reference requirement IDs in commit messages (e.g., "Implement DATA-01")
- Update STATE.md checkboxes as requirements are completed
- Run tests frequently: `testthat::test_dir("tests/testthat")`

### After Phase Completion

1. **Verify**: All success criteria met
2. **Update**: STATE.md with completed requirements
3. **Transition**: `/gsd-transition` - Move to next phase
4. **Commit**: Push all changes

---

## Phase Details

### Phase 1: Data Ingestion & Infrastructure
- **Requirements**: DATA-01, DATA-02, DATA-03, DATA-04, PIPELINE-02, PIPELINE-03
- **Focus**: Ingest martj42, StatsBomb, normalize team names, set up caching
- **Success Criteria**: Data loaded, validated, cached with proper versioning

### Phase 2: xG Model Development
- **Requirements**: XG-01 to XG-06
- **Focus**: Feature calculations, model training, validation
- **Success Criteria**: AUC ≥ 0.75, calibrated, backtested
- **Parallelizable**: Yes (with Phase 3)

### Phase 3: Elo Rating System
- **Requirements**: ELO-01 to ELO-04
- **Focus**: Custom Elo implementation, historical ratings, parameter tuning
- **Success Criteria**: Ratings computed for all teams, tuned k-factor and home advantage
- **Parallelizable**: Yes (with Phase 2)

### Phase 4: Integration Layer
- **Requirements**: INTEGR-01, INTEGR-02
- **Focus**: Combine xG and Elo into team-match metrics
- **Success Criteria**: xGF, xGA, xGD, rolling form computed

### Phase 5: Forecasting Layer
- **Requirements**: FORECAST-01 to FORECAST-05
- **Focus**: Goal models, Monte Carlo simulation, probability generation
- **Success Criteria**: Predictions generated, calibrated to WCQ-UEFA draw rate (~28%)

### Phase 6: Pipeline & Quality
- **Requirements**: PIPELINE-01, TEST-01, TEST-02, TEST-03
- **Focus**: targets orchestration, validation, testing
- **Success Criteria**: Pipeline runs end-to-end, all tests pass, reproducible

### Phase 7: Visualization & Documentation
- **Requirements**: VIS-01, VIS-02, DOC-01, DOC-02
- **Focus**: Visual proofs, user documentation
- **Success Criteria**: AUC chart, calibration plots, notebook, setup guide created

---

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| R as primary language | Existing expertise, strong data science ecosystem |
| targets for orchestration | Designed for reproducible, incremental analytical projects |
| Custom Elo implementation | CRAN package inflexible; need home advantage customization |
| Negative Binomial distribution | Football goals overdispersed; Poisson underestimates 0 and 4+ goals |
| Manual WCQ cache | FotMob ToS prohibits automated scraping |
| Train on domestic leagues only | Avoid data contamination between training and target |

---

## Data Sources

| Source | Usage | License | Notes |
|--------|-------|---------|-------|
| martj42 | Elo backbone | CC0/Open | Historical international results (1872-present) |
| StatsBomb Open Data | xG model training | CC BY-NC-SA 4.0 | Event data for domestic leagues (exclude intl tournaments) |
| FotMob | WCQ shot data (optional) | Restricted | Manual cache only, no redistribution |
| UEFA/FIFA pages | Fixtures, line-ups | Public | Manual, rate-limited access |

---

## Architecture Overview

```
Data Layer (martj42, StatsBomb, WCQ Cache)
    ↓
    ├──→ xG Layer (features, model, training, backtesting)
    │
    └──→ Elo Layer (ratings, tuning, backtesting)
    ↓
Integration Layer (team-match xG, rolling form)
    ↓
Forecasting Layer (goal models, Monte Carlo, predictions)
    ↓
Pipeline Layer (targets orchestration, validation, tests)
```

**Layer Separation Rule**: xG and Elo data combine ONLY in Integration Layer via feature_table

---

## Critical Pitfalls to Avoid

| Pitfall | Prevention |
|---------|-------------|
| Training-prediction data contamination | Train xG only on domestic leagues, exclude all intl tournaments |
| Team name inconsistency | Use canonical mapping with FIFA codes as primary keys |
| Temporal leakage in rolling metrics | Only use matches **before** prediction date |
| Poisson distribution violations | Use Negative Binomial, not Poisson for goal models |
| Draw calibration issues | Target 28% draw frequency for WCQ-UEFA |
| ToS violation (FotMob) | Manual cache only, no automated scraping |
| Non-reproducible results | `set.seed()` at start of every script |

---

## Testing Strategy

### Unit Tests
- xG feature calculations (distance, angle)
- Elo rating logic (k-factor, home advantage, decay)
- Target: ≥80% coverage for core functions

### Integration Tests
- Full pipeline execution
- Reproducibility check (run twice, compare outputs)

### Model Validation
- xG: AUC on held-out test set
- Forecast: Brier score, calibration plots
- Backtesting: Rolling-origin validation

---

## Performance Targets

| Component | Target | Measurement |
|-----------|--------|-------------|
| xG model | AUC ≥ 0.75 | Backtest on held-out domestic league data |
| Forecast calibration | Draw freq ±5% | Compare predicted vs WCQ-UEFA historical |
| Monte Carlo | 50K sims in <10s | Benchmark on M1/M2 Mac |
| Pipeline | End-to-end success | All targets complete without errors |

---

## Directory Structure

```
xGelo/
├── .planning/                      # GSD artifacts
│   ├── PROJECT.md                  # Project context
│   ├── config.json                 # Workflow configuration
│   ├── REQUIREMENTS.md             # Requirements specification
│   ├── ROADMAP.md                 # Phase structure
│   ├── STATE.md                    # Current progress
│   └── research/                   # Domain research
│       ├── STACK.md
│       ├── FEATURES.md
│       ├── ARCHITECTURE.md
│       ├── PITFALLS.md
│       └── SUMMARY.md
├── R/                              # Source code
│   ├── data_ingest/
│   │   ├── martj42.R
│   │   ├── statsbomb.R
│   │   └── team_names.R
│   ├── xg/
│   │   ├── features.R
│   │   ├── model.R
│   │   ├── calibration.R
│   │   └── backtest.R
│   ├── elo/
│   │   ├── runner.R
│   │   └── tuning.R
│   ├── integration/
│   │   ├── team_match_xg.R
│   │   └── rolling_form.R
│   ├── forecast/
│   │   ├── poisson.R (NB models)
│   │   ├── monte_carlo.R
│   │   ├── calibration.R
│   │   └── output.R
│   ├── wcq/
│   │   ├── cache.R
│   │   └── scoring.R
│   └── pipeline/
│       ├── _targets.R
│       ├── validation.R
│       └── tests/
├── data/
│   ├── raw/
│   │   ├── martj42/
│   │   ├── statsbomb/
│   │   └── wcq_cache/
│   ├── processed/
│   ├── models/
│   └── cache/
├── outputs/
│   ├── forecasts/
│   ├── visualizations/
│   └── notebooks/
├── tests/
│   └── testthat/
│       ├── test_xg_features.R
│       ├── test_elo.R
│       └── test_pipeline.R
├── _targets.R                     # Main pipeline definition
├── CLAUDE.md                      # This file
└── README.md                      # User-facing documentation
```

---

## Getting Started

### Prerequisites

```bash
# Install R 4.4.x
# Install required packages
Rscript -e "install.packages(c('targets', 'tarchetypes', 'tidyverse', 'tidymodels', 'httr2', 'jsonlite', 'arrow', 'testthat', 'knitr', 'rmarkdown'))"
```

### First Time Setup

```bash
# Clone the repository
git clone /Users/davidzenz/R/xGelo
git checkout master

# Initialize renv (if used)
Rscript -e "renv::init()"
Rscript -e "renv::restore()"
```

### Running the Pipeline

```bash
# Check current state
cat .planning/STATE.md

# Run targets pipeline
Rscript -e "targets::tar_make()"

# Run specific target
targets::tar_make(target = "xg_model")
```

---

## GSD Workflow Reminders

✅ **DO**:
- Commit planning docs to git (config: commit_docs = true)
- Run plans in parallel (config: parallelization = true)
- Use research agents for domain investigation
- Verify plans before execution
- Verify work after execution

❌ **DON'T**:
- Skip planning - always create PLAN.md before execution
- Edit files without reading them first
- Remove code that wasn't asked to be removed
- Commit without verification

---

## Contact & Support

For questions about:
- **Project context**: See PROJECT.md and research/SUMMARY.md
- **Workflow**: See config.json and this file (CLAUDE.md)
- **Current status**: See STATE.md and ROADMAP.md
- **GSD commands**: Run `/gsd-help`

---

## Changelog

| Date | Change | Author |
|------|--------|--------|
| 2026-06-03 | Initial CLAUDE.md created | GSD Initialization |

---

*This file is auto-generated and maintained. Last updated: 2026-06-03*
