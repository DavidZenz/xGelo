# Requirements: xGelo v3.0

**Defined:** 2026-08-13
**Core Value:** Accurate, calibrated international-football forecasting without dependence on paid data feeds.

## v3.0 Requirements

### Competition Data

- [x] **DATA-01**: The analyst can capture official UEFA snapshots for competition fixtures, groups, standings, results, and status.
- [x] **DATA-02**: Every captured snapshot records its source URL, retrieval time, raw-byte hash, parser version, and fallback status.
- [x] **DATA-03**: UEFA and open historical results are normalized to stable team IDs and competition-edition IDs while preserving source display names.
- [x] **DATA-04**: The pipeline supports audited manual fallback snapshots with source, retrieval date, reason, operator note, and checksum visible in the published metadata.

### Competition Registry and Rules

- [x] **COMP-01**: Each competition edition is registered with lifecycle state, ruleset version, source bundle, model release, and output bundle.
- [x] **COMP-02**: The 2026/27 Nations League registry represents Leagues A-D, published groups, league-phase fixtures, and downstream knockout or play-off stages.
- [x] **COMP-03**: The EURO 2028 qualifying registry represents the pre-draw state and activates groups, fixtures, and simulations only after an official draw snapshot exists.
- [ ] **COMP-04**: Competition state applies the official tie-breakers, cross-group rankings, host-place rules, play-off topology, and regulation-version checks for the selected edition.

### Competition State and Form

- [x] **STATE-01**: The analyst can compute competition-specific standings from completed results with played, wins, draws, losses, goals, goal difference, points, and official rank.
- [x] **STATE-02**: The data model keeps scheduled, completed, postponed, abandoned, extra-time, and penalty-shootout states distinct, including regulation and final scores where applicable.
- [x] **STATE-03**: The dashboard reports competition-specific recent form and a separate all-international form view with explicit windows and point-in-time cutoffs.
- [x] **STATE-04**: Nations League and EURO state remain independent while sharing canonical team identity, Elo/xG strength, and international match history.

### Match Forecasts

- [x] **FORECAST-01**: Both dashboards use the approved calibrated model release and expose its model identity, data cutoff, and feature cutoff.
- [x] **FORECAST-02**: Each open fixture has calibrated home/draw/away probabilities, expected goals, a most likely score, a bounded scoreline distribution, and uncertainty metadata.
- [x] **FORECAST-03**: Forecast generation proves point-in-time feature safety and never uses future competition standings or outcomes as pre-match model inputs.

### Competition Simulation

- [x] **SIM-01**: The Nations League simulator reports projected standings, League A quarter-final and title paths, direct promotion/relegation, and applicable promotion/relegation play-offs.
- [ ] **SIM-02**: The EURO simulator reports direct qualification, host-reserved places, Nations League-linked play-off eligibility, and every valid play-off topology.
- [ ] **SIM-03**: Every simulation records deterministic seeds, ruleset hashes, source bundle identity, model release identity, and replayable run metadata.
- [x] **SIM-04**: Pre-draw, unresolved, and insufficient-source states are shown explicitly without fabricated groups, fixtures, standings, or probabilities.

### Dashboard Experience

- [ ] **DASH-01**: The project publishes dedicated Nations League and EURO qualifying dashboard entry points powered by one shared rendering and payload engine.
- [ ] **DASH-02**: Each dashboard provides competition structure, groups or leagues, standings, fixtures, results, match forecasts, form, and projected outcomes.
- [ ] **DASH-03**: Users can filter by competition section, league/group, team, matchday, and fixture status in responsive desktop and mobile views.
- [ ] **DASH-04**: Each dashboard shows refresh status, source confidence, model release, warnings, and collapsed data credits without presenting operational detail as the primary content.

### Automated Operations

- [ ] **OPS-01**: A macOS launchd job refreshes both competition bundles hourly using the existing reproducible update pattern.
- [ ] **OPS-02**: Candidate source snapshots and derived outputs are staged and validated before both dashboards are atomically published as one coherent refresh batch.
- [ ] **OPS-03**: The refresh runs source, rules, probability, freshness, deterministic replay, browser smoke, and regression tests before publication.
- [ ] **OPS-04**: Changed compact code, manifests, and dashboard outputs are committed and pushed only when the worktree is clean and the branch is upstream-aligned.
- [ ] **OPS-05**: The refresh fails closed on incomplete sources, dirty or diverged repositories, failed tests, invalid hashes, partial bundles, or oversized generated artifacts.

## Future Requirements

### Additional Editions and Data

- **FUTURE-01**: Add a historical 2026 FIFA World Cup European qualifiers edition to the shared competition selector.
- **FUTURE-02**: Activate full EURO 2028 qualifying groups and simulations after the official 6 December 2026 draw and schedule publication.
- **FUTURE-03**: Add richer lineup, injury, or squad-availability signals when a legal, reproducible historical source exists.
- **FUTURE-04**: Add continuous live-event or post-match evaluation after the batch refresh and immutable snapshot contracts are proven.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Automatic bookmaker, FotMob, or Transfermarkt scraping | Conflicts with licensing, terms, or the open-data-first operating mode |
| Paid data as a required dependency | Violates the project's core value |
| Live event tracker or betting recommendations | These dashboards are scheduled analytical forecasts, not a live-score or betting product |
| Mobile app or server-backed public API | The milestone uses the existing static dashboard and launchd publication surface |
| Invented EURO qualifying groups before the official draw | Unknown competition state must remain explicitly pre-draw |
| Large raw response bodies or score-distribution artifacts in Git | Avoids repository bloat and preserves the code/manifests-only publication boundary |

## Traceability

Each active v3.0 requirement maps to exactly one roadmap phase.

| Requirement | Phase | Status |
|-------------|-------|--------|
| DATA-01 | Phase 13 | Complete |
| DATA-02 | Phase 13 | Complete |
| DATA-03 | Phase 13 | Complete |
| DATA-04 | Phase 13 | Complete |
| COMP-01 | Phase 13 | Complete |
| COMP-02 | Phase 15 | Complete |
| COMP-03 | Phase 16 | Complete |
| COMP-04 | Phase 16 | Pending |
| STATE-01 | Phase 14 | Complete |
| STATE-02 | Phase 14 | Complete |
| STATE-03 | Phase 14 | Complete |
| STATE-04 | Phase 14 | Complete |
| FORECAST-01 | Phase 14 | Complete |
| FORECAST-02 | Phase 14 | Complete |
| FORECAST-03 | Phase 14 | Complete |
| SIM-01 | Phase 15 | Complete |
| SIM-02 | Phase 16 | Pending |
| SIM-03 | Phase 17 | Pending |
| SIM-04 | Phase 16 | Complete |
| DASH-01 | Phase 17 | Pending |
| DASH-02 | Phase 17 | Pending |
| DASH-03 | Phase 17 | Pending |
| DASH-04 | Phase 17 | Pending |
| OPS-01 | Phase 17 | Pending |
| OPS-02 | Phase 17 | Pending |
| OPS-03 | Phase 17 | Pending |
| OPS-04 | Phase 17 | Pending |
| OPS-05 | Phase 17 | Pending |

**Coverage:**

- v3.0 requirements: 28 total
- Mapped to phases: 28
- Unmapped: 0

---
*Requirements defined: 2026-08-13*
