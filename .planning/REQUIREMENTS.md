# Requirements: xGelo v3.0

**Defined:** 2026-08-13
**Core Value:** Accurate, calibrated international-football forecasting without dependence on paid data feeds.

## v3.0 Requirements

### Competition Data

- [ ] **DATA-01**: The analyst can capture official UEFA snapshots for competition fixtures, groups, standings, results, and status.
- [ ] **DATA-02**: Every captured snapshot records its source URL, retrieval time, raw-byte hash, parser version, and fallback status.
- [ ] **DATA-03**: UEFA and open historical results are normalized to stable team IDs and competition-edition IDs while preserving source display names.
- [ ] **DATA-04**: The pipeline supports audited manual fallback snapshots with source, retrieval date, reason, operator note, and checksum visible in the published metadata.

### Competition Registry and Rules

- [ ] **COMP-01**: Each competition edition is registered with lifecycle state, ruleset version, source bundle, model release, and output bundle.
- [ ] **COMP-02**: The 2026/27 Nations League registry represents Leagues A-D, published groups, league-phase fixtures, and downstream knockout or play-off stages.
- [ ] **COMP-03**: The EURO 2028 qualifying registry represents the pre-draw state and activates groups, fixtures, and simulations only after an official draw snapshot exists.
- [ ] **COMP-04**: Competition state applies the official tie-breakers, cross-group rankings, host-place rules, play-off topology, and regulation-version checks for the selected edition.

### Competition State and Form

- [ ] **STATE-01**: The analyst can compute competition-specific standings from completed results with played, wins, draws, losses, goals, goal difference, points, and official rank.
- [ ] **STATE-02**: The data model keeps scheduled, completed, postponed, abandoned, extra-time, and penalty-shootout states distinct, including regulation and final scores where applicable.
- [ ] **STATE-03**: The dashboard reports competition-specific recent form and a separate all-international form view with explicit windows and point-in-time cutoffs.
- [ ] **STATE-04**: Nations League and EURO state remain independent while sharing canonical team identity, Elo/xG strength, and international match history.

### Match Forecasts

- [ ] **FORECAST-01**: Both dashboards use the approved calibrated model release and expose its model identity, data cutoff, and feature cutoff.
- [ ] **FORECAST-02**: Each open fixture has calibrated home/draw/away probabilities, expected goals, a most likely score, a bounded scoreline distribution, and uncertainty metadata.
- [ ] **FORECAST-03**: Forecast generation proves point-in-time feature safety and never uses future competition standings or outcomes as pre-match model inputs.

### Competition Simulation

- [ ] **SIM-01**: The Nations League simulator reports projected standings, League A quarter-final and title paths, direct promotion/relegation, and applicable promotion/relegation play-offs.
- [ ] **SIM-02**: The EURO simulator reports direct qualification, host-reserved places, Nations League-linked play-off eligibility, and every valid play-off topology.
- [ ] **SIM-03**: Every simulation records deterministic seeds, ruleset hashes, source bundle identity, model release identity, and replayable run metadata.
- [ ] **SIM-04**: Pre-draw, unresolved, and insufficient-source states are shown explicitly without fabricated groups, fixtures, standings, or probabilities.

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
| DATA-01 | TBD | Pending roadmap |
| DATA-02 | TBD | Pending roadmap |
| DATA-03 | TBD | Pending roadmap |
| DATA-04 | TBD | Pending roadmap |
| COMP-01 | TBD | Pending roadmap |
| COMP-02 | TBD | Pending roadmap |
| COMP-03 | TBD | Pending roadmap |
| COMP-04 | TBD | Pending roadmap |
| STATE-01 | TBD | Pending roadmap |
| STATE-02 | TBD | Pending roadmap |
| STATE-03 | TBD | Pending roadmap |
| STATE-04 | TBD | Pending roadmap |
| FORECAST-01 | TBD | Pending roadmap |
| FORECAST-02 | TBD | Pending roadmap |
| FORECAST-03 | TBD | Pending roadmap |
| SIM-01 | TBD | Pending roadmap |
| SIM-02 | TBD | Pending roadmap |
| SIM-03 | TBD | Pending roadmap |
| SIM-04 | TBD | Pending roadmap |
| DASH-01 | TBD | Pending roadmap |
| DASH-02 | TBD | Pending roadmap |
| DASH-03 | TBD | Pending roadmap |
| DASH-04 | TBD | Pending roadmap |
| OPS-01 | TBD | Pending roadmap |
| OPS-02 | TBD | Pending roadmap |
| OPS-03 | TBD | Pending roadmap |
| OPS-04 | TBD | Pending roadmap |
| OPS-05 | TBD | Pending roadmap |

**Coverage:**

- v3.0 requirements: 28 total
- Mapped to phases: 0
- Unmapped: 28

---
*Requirements defined: 2026-08-13*
