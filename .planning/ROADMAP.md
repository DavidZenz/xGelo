# xGelo Roadmap

---
*Project: xGelo - Free Elo + xG Forecasting for UEFA World Cup Qualifiers*
*Current Version: 1.0*
*Next Version: 2.0 (Planning)
*Status: v1.0 Complete | v2.0 Pending
*Last Updated: 2026-06-05
---

## Completed Milestones

### v1.0 - MVP (Open Mode) ✅
**Status**: Complete | **Shipped**: 2026-06-05

Production-ready forecasting system using only open data (martj42 + StatsBomb). Forecasts generated for any WCQ-UEFA fixture with accurate probabilities.

> [View v1.0 Details](.planning/milestones/v1.0-ROADMAP.md) | [Requirements](.planning/milestones/v1.0-REQUIREMENTS.md) | [Audit](.planning/v1.0-MILESTONE-AUDIT.md)

**Summary**: 7 phases, 31 requirements, 100% complete
- Phase 1: Data Ingestion & Infrastructure
- Phase 2: xG Model Development (AUC: 0.7905)
- Phase 3: Elo Rating System (49,368 matches, 336 teams, AUC: 0.7916)
- Phase 4: Integration Layer
- Phase 5: Forecasting Layer (Monte Carlo, Brier: 0.214)
- Phase 6: Pipeline & Quality (27 unit tests, 4 integration tests)
- Phase 7: Visualization & Documentation

---

## v2 Requirements (Deferred)

See [v2 Roadmap](.planning/milestones/v2-REQUIREMENTS.md) for enhancements including:
- Mixed-effects xG model
- Sequence-aware models
- Hybrid WCQ data layer
- Group stage simulation
- CI/CD pipeline

---

## Quick Links

- [PROJECT.md](.planning/PROJECT.md) - Project overview and goals
- [STATE.md](.planning/STATE.md) - Current project state
- [Milestones Archive](.planning/milestones/) - All completed milestones

---

## Backlog

### Phase 999.1: Socio-economic structural benchmark (BACKLOG)

**Goal:** Evaluate Hoffmann, Ging & Ramasamy (2002) as a future benchmark or structural prior for national-team strength.
**Requirements:** TBD
**Plans:** 0 plans

Context:
- Source paper: Robert Hoffmann, Lee Chew Ging, and Bala Ramasamy (2002), "The Socio-Economic Determinants of International Soccer Performance."
- The paper models January 2001 FIFA ranking points, not match-level World Cup outcomes; treat it as a macro-strength benchmark, not a direct outcome model.
- Candidate variables: GNP/GDP per capita, squared GNP/GDP per capita, squared deviation from 14 C average capital-city temperature, prior World Cup host status, and Latin cultural-origin x population-share interaction.
- Joachim Klement's 2026 World Cup model explicitly cites Hoffmann/Ging/Ramasamy as its root, adds current FIFA ranking points, simulates tournament progression, and reports explaining roughly 55% of cross-country World Cup success variation.
- Reported fit in the original paper is R-squared = 0.3180; reserve any "55%" claim for Klement's extended World Cup model, not the 2002 paper alone.
- Potential xGelo use: compare Elo-only, xG/Elo, and structural-only baselines; optionally use structural strength as shrinkage for sparse-match countries.

Plans:
- [ ] TBD (promote with $gsd-review-backlog when ready)

---
*Last Updated: 2026-06-05 | v1.0 Archived | v2.0 Ready for Planning*
