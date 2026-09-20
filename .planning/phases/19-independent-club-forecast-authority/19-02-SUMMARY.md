---
phase: 19-independent-club-forecast-authority
plan: "02"
subsystem: club-rating
tags: [r, elo, canonical-v2, batch-safety, temporal-cutoff, graph-connectivity]

requires:
  - phase: 18-club-and-ucl-source-contracts
    provides: Accepted club history, current-UCL roster, club identity, and canonical-v2 authority
  - phase: 19-independent-club-forecast-authority
    plan: "01"
    provides: Validated club-only training/current snapshots and fixture authority discriminator
provides:
  - Club-namespaced canonical-v2 Elo parameters and state identities
  - Immutable same-kickoff/date prediction batches with simultaneous regulation-result updates
  - Strict dual-time history replay and exact current-UCL connected-component gate
affects: [19-04, 19-05, 19-06, 19-07, 19-08, 19-09, 19-10, phase-20, phase-21]

tech-stack:
  added: []
  patterns: [immutable pre-batch state, simultaneous Elo deltas, strict dual-time replay, exact-roster component audit]

key-files:
  created:
    - R/club/rating.R
    - tests/testthat/test_phase19_club_rating.R
  modified: []

key-decisions:
  - "Club Elo accepts only base 1500 and the predeclared K, home-advantage, and annual inactivity-factor domains; parameter identity is canonical-v2 hashed."
  - "Historical outcomes become eligible only when both completion and evidence timestamps are strictly before the next boundary; date-only matches share a UTC-date boundary and become eligible afterward."
  - "Every exact current-UCL roster club must occur in one accepted-history component; missing or disconnected coverage returns current_ucl_identity_incomplete."

patterns-established:
  - "Batch-safe club Elo: canonical predictions are materialized from one immutable state, then all regulation-result deltas are summed and committed together."
  - "Fixture rating evidence remains fixture-only and non-promotable even when its mechanical graph and replay checks pass."

requirements-completed: [CLUBMOD-01, CLUBMOD-02]

coverage:
  - id: D1
    description: "Club-only Elo parameters, state, and exact-kickoff batches are authority-bound, order-invariant, and free of contemporaneous result leakage."
    requirement: CLUBMOD-01
    verification:
      - kind: unit
        ref: "tests/testthat/test_phase19_club_rating.R#immutable batch, permutation, identity, parameter, and regulation-only tests"
        status: pass
      - kind: other
        ref: "rtk Rscript --vanilla scripts/run_phase19_focused_test.R tests/testthat/test_phase19_club_rating.R"
        status: pass
    human_judgment: false
  - id: D2
    description: "Club rating replay enforces strict completion/evidence cutoffs, conservative date batches, canonical provenance, and exact current-roster graph connectivity."
    requirement: CLUBMOD-02
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase19_club_rating.R#strict replay, date-only, graph, inactivity, and isolated-process tests"
        status: pass
      - kind: other
        ref: "rtk git diff --check"
        status: pass
    human_judgment: false

duration: 17min
completed: 2026-09-20
status: complete
---

# Phase 19 Plan 02: Batch-Safe Club Rating Summary

**Canonical-v2 club Elo now forecasts immutable kickoff/date batches, applies only strictly prior regulation outcomes, and blocks incomplete or disconnected current-UCL rating graphs.**

## Performance

- **Duration:** 17 min
- **Started:** 2026-09-20T17:50:36Z
- **Completed:** 2026-09-20T18:07:35Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Created a club-only rating state bound to validated training/current snapshots, exact club IDs, registered parameter domains, fixture/production authority, and canonical-v2 state identities.
- Materialized every prediction in a boundary from one unchanged pre-state, then applied canonical simultaneous deltas using regulation results only; input permutation and peer-outcome changes cannot leak across the batch.
- Replayed accepted history with exclusive completion/evidence cutoffs, conservative date-only batches, annual difference-to-base inactivity reversion, exact-roster component coverage, and isolated-process reproducibility.

## Task Commits

Each TDD gate was committed atomically:

1. **Task 19-02-01 RED: expose club rating batch invariants** - `f2997ea` (test)
2. **Task 19-02-01 GREEN: implement immutable club rating batches** - `770bae8` (feat)
3. **Task 19-02-02 RED: expose strict replay and graph coverage gaps** - `8fda92d` (test)
4. **Task 19-02-02 GREEN: enforce strict club rating replay** - `4c11022` (feat)

## Files Created/Modified

- `R/club/rating.R` - Closed club Elo parameters, authority-bound state, batch forecasting/updating, temporal replay, and component audit.
- `tests/testthat/test_phase19_club_rating.R` - Same-boundary, permutation, cutoff, date-only, regulation-only, inactivity, graph, identity, and isolated-process coverage.

## Decisions Made

- The rating contract freezes base 1500 and admits only the predeclared K factors (20/30/40), home advantages (40/60/80), and annual inactivity factors (0.99/0.995/0.999).
- Inactivity applies `base + (rating - base) * factor^(days/365)`; it never shrinks the absolute rating toward zero.
- A historical kickoff/date batch becomes rating evidence as one unit at its latest required completion/evidence time and only when that time is strictly before the consuming boundary.
- Component diagnostics bind the exact current roster, training/current snapshot identities, both identity registries, and canonical membership tables; fixture success remains explicitly non-promotable.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- Concurrent Plan 19-03 commits landed in the shared checkout while this plan ran. Only Plan 19-02 files were staged, and all Plan 19-03 work plus unrelated user artifacts remained untouched.

## TDD Gate Compliance

- Task 19-02-01: RED `f2997ea` precedes GREEN `770bae8`.
- Task 19-02-02: RED `8fda92d` precedes GREEN `4c11022`.
- Final focused verification: 10 tests, 58 assertions, zero failures/errors/warnings/skips.
- Combined Plan 19-01/19-02 regression: 19 tests, 161 assertions, zero failures/errors/warnings/skips.

## Known Stubs

None. Empty state-provenance fields are canonical initial-state values and scheduled replay rows intentionally carry missing regulation scores because they are prediction-only, non-updating evidence.

## User Setup Required

None - no credentials, network access, package installation, or external service configuration was used.

## Next Phase Readiness

- Club goal models can consume `rating_difference`, strict boundary/cutoff provenance, parameter/state hashes, and cold-start diagnostics without importing national-team state.
- Fixture mechanics are fully evaluable but non-promotable. Production remains fail-closed until the fixed Phase 18 history/current descriptors resolve real accepted evidence.

## Self-Check: PASSED

- Both implementation/test artifacts and this summary exist.
- TDD commits `f2997ea`, `770bae8`, `8fda92d`, and `4c11022` exist in repository history.
- Independent focused verification and diff hygiene pass.

---
*Phase: 19-independent-club-forecast-authority*
*Completed: 2026-09-20*
