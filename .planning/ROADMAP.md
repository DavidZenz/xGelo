# xGelo Roadmap

**Active milestone:** v3.0 - UEFA Competition Forecast Dashboards
**Status:** Planned
**Created:** 2026-08-13

## Milestone Objective

Build two public static forecast dashboards for the 2026/27 UEFA Nations League
and UEFA EURO 2028 qualifying cycle from one shared engine, with official UEFA
competition data, truthful pre-draw handling, calibrated forecasts, replayable
simulations, and fail-closed hourly publication.

## Phases

- [x] **Phase 13: Source Contracts and Competition Registry** - Freeze official snapshot, fallback, normalization, and edition-registry contracts for both competitions. (completed 2026-08-16)
- [x] **Phase 14: Shared Competition State and Forecast Layer** - Build the shared standings, status, form, and point-in-time forecast layer that both competitions consume. (completed 2026-08-21)
- [ ] **Phase 15: Nations League Rules and Outcomes** - Deliver the full 2026/27 Nations League state, forecasts, and projection logic.
- [ ] **Phase 16: EURO Qualifying Activation and Play-off Rules** - Deliver truthful EURO 2028 qualifying pre-draw behavior and official post-draw qualification logic.
- [ ] **Phase 17: Shared Dashboards and Atomic Refresh Operations** - Publish both dashboards from one renderer and harden the hourly batch refresh, validation, and release flow.

## Phase Details

### Phase 13: Source Contracts and Competition Registry

**Goal**: Analysts can capture authoritative UEFA competition snapshots and register both competition editions under one auditable contract.
**Depends on**: Nothing (first v3.0 phase)
**Requirements**: DATA-01, DATA-02, DATA-03, DATA-04, COMP-01
**Success Criteria** (what must be TRUE):

1. An analyst can capture official UEFA snapshots for Nations League and EURO qualifying fixtures, groups, standings, results, and competition status.
2. Every accepted snapshot exposes its source URL, retrieval time, raw-byte hash, parser version, and fallback flag in audit metadata.
3. Manual fallback snapshots can be loaded with visible source, retrieval date, reason, operator note, and checksum instead of silently replacing official data.
4. Normalized records retain UEFA display names while resolving to stable team IDs and competition-edition IDs for both competition editions.
5. Registry entries exist for the 2026/27 Nations League and EURO 2028 qualifying editions with lifecycle state, source bundle, model release slot, and output bundle target.

**Plans**: 13/13 plans executed

- [x] 13-13-PLAN.md

- [x] 13-04-PLAN.md
- [x] 13-05-PLAN.md
- [x] 13-06-PLAN.md
- [x] 13-07-PLAN.md
- [x] 13-08-PLAN.md
- [x] 13-09-PLAN.md
- [x] 13-10-PLAN.md
- [x] 13-11-PLAN.md
- [x] 13-12-PLAN.md

**Wave 1**

- [x] 13-01-PLAN.md

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 13-02-PLAN.md
- [x] 13-03-PLAN.md

### Phase 14: Shared Competition State and Forecast Layer

**Goal**: Both competitions can reuse one edition-aware state, form, and pre-match forecast engine without leaking future information.
**Depends on**: Phase 13
**Requirements**: STATE-01, STATE-02, STATE-03, STATE-04, FORECAST-01, FORECAST-02, FORECAST-03
**Success Criteria** (what must be TRUE):

1. Standings can be computed from completed results with played, wins, draws, losses, goals, goal difference, points, and official rank visible for the selected competition state.
2. Scheduled, completed, postponed, abandoned, extra-time, and penalty-shootout states remain distinct, including regulation and final scores where applicable.
3. Both competitions expose separate competition-specific form and all-international form views with explicit windows and point-in-time cutoffs.
4. Open fixtures show calibrated home, draw, and away probabilities, expected goals, a most likely score, a bounded score distribution, and uncertainty metadata from the approved release.
5. Forecast audits prove point-in-time feature safety, and Nations League and EURO competition states remain independent while sharing canonical team identity and strength inputs.

**Plans**: 22/22 plans executed
**Wave 1**

- [x] 14-01-PLAN.md
- [x] 14-02-PLAN.md
- [x] 14-03-PLAN.md
- [x] 14-04-PLAN.md

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 14-05-PLAN.md

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 14-21-PLAN.md

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 14-22-PLAN.md

**Wave 5** *(blocked on Wave 4 completion)*

- [x] 14-06-PLAN.md

**Wave 6** *(blocked on Wave 5 completion)*

- [x] 14-07-PLAN.md

**Wave 7** *(blocked on Wave 6 completion)*

- [x] 14-08-PLAN.md

**Wave 8** *(blocked on Wave 7 completion)*

- [x] 14-09-PLAN.md

**Wave 9** *(blocked on Wave 8 completion)*

- [x] 14-10-PLAN.md

**Wave 10** *(blocked on Wave 9 completion)*

- [x] 14-11-PLAN.md

**Wave 11** *(blocked on Wave 10 completion)*

- [x] 14-12-PLAN.md

**Wave 12** *(blocked on Wave 11 completion)*

- [x] 14-13-PLAN.md

**Wave 13** *(blocked on Wave 12 completion)*

- [x] 14-14-PLAN.md

**Wave 14** *(blocked on Wave 13 completion)*

- [x] 14-15-PLAN.md

**Wave 15** *(blocked on Wave 14 completion)*

- [x] 14-16-PLAN.md

**Wave 16** *(blocked on Wave 15 completion)*

- [x] 14-17-PLAN.md

**Wave 17** *(blocked on Wave 16 completion)*

- [x] 14-18-PLAN.md

**Wave 18** *(blocked on Wave 17 completion)*

- [x] 14-19-PLAN.md

**Wave 19** *(blocked on Wave 18 completion)*

- [x] 14-20-PLAN.md

### Phase 15: Nations League Rules and Outcomes

**Goal**: Users can inspect the full 2026/27 Nations League competition state and projections under the official edition rules.
**Depends on**: Phase 14
**Requirements**: COMP-02, SIM-01
**Success Criteria** (what must be TRUE):

1. The Nations League output shows Leagues A through D, published groups, league-phase fixtures, completed results, and downstream knockout or play-off stages for the 2026/27 edition.
2. Nations League tables and overall rankings follow the official edition rules, including cross-group comparisons and League D group-size handling where required.
3. Open Nations League fixtures show calibrated forecasts together with competition-specific form and all-international form from the shared engine.
4. Projected outcomes report League A quarter-final and title paths, direct promotion and relegation, and applicable promotion or relegation play-off probabilities for every team.

**Plans**: 1/7 plans executed
Plans:
**Wave 1**

- [x] 15-00-PLAN.md — Create the Wave 0 Phase 15 test harness and synthetic fixtures
- [ ] 15-01-PLAN.md — Freeze topology, Article 13 access-list/group formation, and separately registered stage capture

**Wave 2** *(blocked on Wave 1 completion)*

- [ ] 15-02-PLAN.md — Implement Article 15/19 rankings, final overall rank, blocked inputs, transitions, and C/D retention

**Wave 3** *(blocked on Wave 2 completion)*

- [ ] 15-03-PLAN.md — Implement calibrated simulation and Article 14-18 stage resolution

**Wave 4** *(blocked on Wave 3 completion)*

- [ ] 15-04-PLAN.md — Define and validate the nine-file sibling outcomes bundle with fixture forecast/form pass-through

**Wave 5** *(blocked on Wave 4 completion)*

- [ ] 15-05-PLAN.md — Build the Nations League CLI, registered output root, and durable nine-file outcome artifacts

**Wave 6** *(blocked on Wave 5 completion)*

- [ ] 15-06-PLAN.md — Run production acceptance, replay, and no-leakage checks

**UI hint**: yes

### Phase 16: EURO Qualifying Activation and Play-off Rules

**Goal**: Users can see a truthful EURO 2028 qualifying dashboard before the draw and the full official qualification logic once UEFA publishes the draw and schedule.
**Depends on**: Phase 15
**Requirements**: COMP-03, COMP-04, SIM-02, SIM-04
**Success Criteria** (what must be TRUE):

1. Before an official draw snapshot exists, the EURO 2028 qualifying output remains in an explicit `pre_draw` state through the official 6 December 2026 draw date without invented groups, fixtures, standings, or probabilities.
2. Once an official draw snapshot exists, the competition activates real groups, fixtures, standings, and simulations from the registered UEFA source bundle rather than guessed structures.
3. Qualification outputs apply the official edition rules for direct qualification, host-reserved places, best runners-up, Nations League-linked play-off eligibility, and every valid play-off topology.
4. Unresolved, blocked, or insufficient-source states stay explicit and suppress fabricated groups, fixtures, standings, and probabilities.

**Plans**: TBD
**UI hint**: yes

### Phase 17: Shared Dashboards and Atomic Refresh Operations

**Goal**: The public site publishes both competition dashboards from one shared renderer and refreshes them safely as one validated hourly batch.
**Depends on**: Phase 16
**Requirements**: SIM-03, DASH-01, DASH-02, DASH-03, DASH-04, OPS-01, OPS-02, OPS-03, OPS-04, OPS-05
**Success Criteria** (what must be TRUE):

1. Users can open dedicated Nations League and EURO qualifying entry points powered by one shared rendering and payload engine, and each dashboard shows structure, standings, fixtures, results, form, match forecasts, and projected outcomes.
2. Users can filter by competition section, league or group, team, matchday, and fixture status in responsive desktop and mobile layouts.
3. Every published dashboard shows refresh status, source confidence, model release, warnings, collapsed data credits, and replayable simulation metadata.
4. An hourly macOS `launchd` refresh stages both competitions together, runs source, rules, probability, freshness, deterministic replay, browser smoke, and regression checks, and atomically promotes only a fully valid batch.
5. Auto-commit and push happen only from a clean, upstream-aligned repository and include only compact code, manifests, and dashboard outputs; dirty, diverged, partial, oversized, or failed batches stay unpublished.

**Plans**: TBD
**UI hint**: yes

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 13. Source Contracts and Competition Registry | 13/13 | Complete    | 2026-08-16 |
| 14. Shared Competition State and Forecast Layer | 22/22 | Complete    | 2026-08-21 |
| 15. Nations League Rules and Outcomes | 1/7 | In Progress|  |
| 16. EURO Qualifying Activation and Play-off Rules | 0/TBD | Not started | - |
| 17. Shared Dashboards and Atomic Refresh Operations | 0/TBD | Not started | - |

## Requirement Coverage

| Phase | Requirements | Count |
|-------|--------------|-------|
| 13 | DATA-01..04, COMP-01 | 5 |
| 14 | STATE-01..04, FORECAST-01..03 | 7 |
| 15 | COMP-02, SIM-01 | 2 |
| 16 | COMP-03, COMP-04, SIM-02, SIM-04 | 4 |
| 17 | SIM-03, DASH-01..04, OPS-01..05 | 10 |
| **Total** | **All v3.0 requirements** | **28** |

## Completed Milestones

### v1.0 - Open-Data Forecasting MVP

**Status:** Complete (2026-06-05)

See [v1.0 roadmap](milestones/v1.0-ROADMAP.md) and
[v1.0 requirements](milestones/v1.0-REQUIREMENTS.md).

### v2.0 - Model Retrospective and Forecast Evolution

**Status:** Complete (2026-08-13)

Phases 8 through 12 completed the benchmark, challenger, calibration, promotion,
and release work that v3.0 reuses as its approved forecast engine.

---
*Last updated: 2026-08-13 for milestone v3.0 roadmap creation*
