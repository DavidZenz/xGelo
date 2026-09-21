---
phase: 20-ucl-rules-state-and-tournament-outcomes
plan: "02"
subsystem: competition-state
tags: [ucl, article-18, schedule-validation, forecast-ledger, phase14, phase19]

# Dependency graph
requires:
  - phase: 20-ucl-rules-state-and-tournament-outcomes
    provides: Wave 1 UCL fixture graph, evidence sidecar, and Phase 19 authority seam
provides:
  - Exact 36-club/144-fixture UCL league-phase schedule validation
  - Article 18 interim/final trace, unresolved intervals, and qualification bands
  - Strict pre-kickoff, one-row-per-fixture forecast ledger with completed-row immutability
affects: [ucl-simulation, ucl-outcomes, phase20-verification]

# Tech tracking
tech-stack:
  added: []
  patterns: [typed blocked states, criterion-level Article 18 traces, strict exclusive cutoff, immutable completed evidence]

key-files:
  created: [.planning/phases/20-ucl-rules-state-and-tournament-outcomes/20-02-RED.md, .planning/phases/20-ucl-rules-state-and-tournament-outcomes/20-02-SUMMARY.md]
  modified: [R/competition/uefa_champions_league_rules.R, R/competition/uefa_champions_league_state.R, tests/testthat/helper_uefa_champions_league.R, tests/testthat/test_uefa_champions_league.R, data/competition/rules/ucl_2026_27_rules_and_draw_evidence.json]

key-decisions:
  - "Treat provider standings as reconciliation-only evidence and never use provider or lexical order to close Article 18 intervals."
  - "Require source-row hashes, stable source identity, exact kickoff confirmation, and canonical lifecycle/score semantics before state arithmetic."
  - "Use the fixed Phase 19 production resolver; fixture releases remain mechanics-only and permanently non-promotable."

patterns-established:
  - "Article 18 traces carry ordered criteria, before/after subsets, counted evidence IDs, decisive markers, rank intervals, and row hashes."
  - "Forecast rows validate identity, source bundle, model evidence, finite probabilities/xG, and feature_cutoff_utc < kickoff_utc before becoming available."

requirements-completed: [UCLRULE-01, UCLRULE-02, UCLRULE-03, UCLOUT-01]

coverage:
  - id: D1
    description: "Accepted UCL league graph is exactly 36 clubs and 144 source-bound fixtures with eight opponents and 4/4 home-away split."
    requirement: UCLRULE-01
    verification:
      - kind: unit
        ref: tests/testthat/test_uefa_champions_league.R#UCLRULE-01/UCLRULE-03 validate the complete accepted schedule
        status: pass
    human_judgment: false
  - id: D2
    description: "Article 18 final ten-criterion and interim first-five traces preserve unresolved intervals and derive boundary-safe qualification bands."
    requirement: UCLRULE-02
    verification:
      - kind: unit
        ref: tests/testthat/test_uefa_champions_league.R#UCLRULE-02 exposes the complete Article 18 trace and separate presentation order
        status: pass
      - kind: unit
        ref: tests/testthat/test_uefa_champions_league.R#Rank intervals touching 8 or 24 suppress the affected qualification band
        status: pass
    human_judgment: false
  - id: D3
    description: "Forecast ledger has exact fixture coverage, strict pre-kickoff evidence gates, typed suppression reasons, and byte-preserving completed rows."
    requirement: UCLOUT-01
    verification:
      - kind: unit
        ref: tests/testthat/test_uefa_champions_league.R#Forecast ledger enforces strict cutoff equality and release lineage
        status: pass
      - kind: unit
        ref: tests/testthat/test_uefa_champions_league.R#Completed forecast rows remain byte-identical when state is rebuilt
        status: pass
    human_judgment: false
  - id: D4
    description: "The eight-row official evidence sidecar is identity-validated and CR-01 through CR-05 parent failures remain rejected and normalized."
    requirement: UCLRULE-03
    verification:
      - kind: unit
        ref: tests/testthat/test_uefa_champions_league.R#Wave 0 pins the exact seven regulation records and unresolved draw row
        status: pass
      - kind: unit
        ref: tests/testthat/test_uefa_champions_league.R#CR-01 through CR-05 probes reject forged or unbacked parent evidence
        status: pass
    human_judgment: false

# Metrics
duration: 25min
completed: 2026-09-21
status: complete
---

# Phase 20 Plan 02 Summary

**Exact UCL league-phase rules/state boundary with Article 18 traces, unresolved qualification bands, and an immutable pre-kickoff forecast ledger**

## Performance

- **Duration:** 25 min
- **Started:** 2026-09-21T20:08:00+02:00
- **Completed:** 2026-09-21T20:27:39Z
- **Tasks:** 2
- **Files modified:** 6 (plus this summary)

## Accomplishments

- Validated only the complete 36-club/144-fixture graph, including stable source-row hashes, unique opponent pairs, 4/4 home-away degrees, kickoff confirmation, lifecycle, score, and lineage semantics.
- Implemented the exact ten-criterion Article 18 resolver with interim first-five behavior, durable criterion/subset evidence trace, decisive trace IDs, presentation ordering, unresolved rank intervals, and rank-8/rank-24 band suppression.
- Hardened the one-row-per-fixture forecast ledger with strict identity/source-bundle/model/cutoff/probability checks, typed suppression reasons, fixed Phase 19 production authority, and byte-preserving completed rows.
- Verified the exact eight-row UEFA evidence sidecar and converted CR-01 through CR-05 helper probes into explicit rejected parent-reason contracts.

## Task Commits

Each task was committed atomically:

1. **Task 1: Write RED contracts for schedule completeness, Article 18 traces, and ledger immutability** - `d16e8ef` (test)
2. **Task 1 RED evidence transcript** - `1ea628b` (docs)
3. **Task 2: Implement the complete UCL rules/state and immutable forecast ledger** - `d466c5e` (feat)

## Files Created/Modified

- `R/competition/uefa_champions_league_rules.R` - canonical evidence identity checks, Article 18 traces, decisive IDs, presentation order, and qualification-band derivation.
- `R/competition/uefa_champions_league_state.R` - exact schedule/lifecycle/score/source validation, Phase 14 state projection, provider reconciliation, and immutable ledger validation/merge.
- `data/competition/rules/ucl_2026_27_rules_and_draw_evidence.json` - exact seven accepted regulation rows plus unresolved draw-procedure row (verified unchanged from Wave 0).
- `tests/testthat/helper_uefa_champions_league.R` - typed CR-01..CR-05 rejection probes.
- `tests/testthat/test_uefa_champions_league.R` - RED boundary contracts for schedule, Article 18, ledger, evidence, and parent gates.
- `.planning/phases/20-ucl-rules-state-and-tournament-outcomes/20-02-RED.md` - fresh-process non-zero RED transcript.

## Decisions Made

- Project-owned Phase 14 arithmetic remains the sole standings arithmetic source; UCL logic only orders it through the editioned Article 18 contract.
- A missing late criterion leaves a shared rank interval and an explicitly unresolved qualification band wherever rank 8 or 24 can be crossed.
- Fixture releases can satisfy mechanics tests only; they cannot satisfy the fixed Phase 19 production resolver or promote selector/incumbent bytes.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected the Article 18 decisive-trace key expression and presentation mapping.**
- **Found during:** Task 2 verification
- **Issue:** The first implementation had an unbalanced trace-key subscript and initially conflated qualification rank with input presentation order.
- **Fix:** Closed the expression and map presentation order/rank from deterministic input order while keeping project rank independent.
- **Files modified:** `R/competition/uefa_champions_league_rules.R`
- **Verification:** Focused UCL suite passes, including the exact trace/presentation contract.
- **Committed in:** `d466c5e`

**2. [Rule 2 - Missing critical validation] Added canonical lifecycle/score semantics and source-lineage checks required to fail closed.**
- **Found during:** Task 2 implementation
- **Issue:** The tracer accepted unmapped lifecycle values, contradictory score axes, duplicate source rows, and kickoff confirmation mismatches.
- **Fix:** Added status/completion mapping, integer/pair/winner validation, duplicate source-key rejection, exact kickoff confirmation, and explicit provider same-lineage reconciliation statuses.
- **Files modified:** `R/competition/uefa_champions_league_state.R`
- **Verification:** Focused UCL suite passes; adversarial schedule mutations remain typed blocked states.
- **Committed in:** `d466c5e`

**Total deviations:** 2 auto-fixed (1 Rule 1, 1 Rule 2)
**Impact on plan:** All fixes reinforce the planned fail-closed schedule, trace, and ledger boundary; no scope expansion or production authority was introduced.

## Issues Encountered

- Focused UCL verification passes in a fresh process.
- Phase 14 forecast-layer verification passes in a fresh process.
- Phase 14 standings verification was run but has one pre-existing out-of-scope failure at `tests/testthat/test_phase14_standings.R:686` involving temporary-schema row-name attributes; no Phase 14 files were changed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

The UCL state and forecast boundary is ready for downstream simulation/outcome plans. Production forecasts remain correctly blocked by the existing Phase 19 `no_accepted_club_history` authority state, while fixture evidence remains mechanics-only.

---
*Phase: 20-ucl-rules-state-and-tournament-outcomes*
*Completed: 2026-09-21*

## Self-Check: PASSED

- All declared implementation, evidence, test, RED transcript, and summary files exist.
- Task commits `d16e8ef`, `1ea628b`, and `d466c5e` resolve in git history.
