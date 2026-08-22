---
phase: 15-nations-league-rules-and-outcomes
plan: "00"
subsystem: testing
tags: [r, testthat, nations-league, rules, simulation, fixtures, replay]

# Dependency graph
requires:
  - phase: 14-shared-competition-state-and-forecast-layer
    provides: Phase 14 state, standings, forecast, lineage, and replay test patterns
provides:
  - Wave 0 focused Phase 15 harness with repository-root loading and precise API guards
  - Synthetic Nations League group, two-leg, host-order, stage-capture, forecast, and hash fixtures
  - Registered temporary output-root helper for later outcomes tests
affects: [15-01, 15-02, 15-03, 15-04, 15-05, 15-06]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Self-contained base-R fixture constructors inside one focused test file
    - Canonical column/row ordering with SHA-256 replay assertions
    - Explicit API guards and tempdir-child registration for future production tests

key-files:
  created:
    - tests/testthat/test_phase15_nations_league.R
  modified: []

key-decisions:
  - "Keep all Wave 0 fixtures self-contained so later Phase 15 plans extend one stable test surface without adding fixture files."
  - "Represent admitted Article 13 metadata separately from the current unresolved source snapshot; missing positions and draw pots remain NA rather than inferred."
  - "Use a calibrated 1X2 simplex whose category masses are explicitly reproduced by a bounded score grid."
  - "Allow temporary output roots only as registered children of tempdir(); durable production output is outside this helper."

patterns-established:
  - "phase15_test_require_api() reports the exact missing function name when a later contract is activated."
  - "phase15_test_table_sha256() canonicalizes columns and row order so reversed-input replay comparisons are deterministic."
  - "Completed stage fixtures preserve regulation, extra-time, shootout, final-score, completion-time, and source-lineage fields together."

requirements-completed: [COMP-02, SIM-01]

coverage:
  - id: D1
    description: "Wave 0 fixtures cover Nations League group cardinality, Article 13 access-list states, reciprocal legs, Article 17 host ordering, and completed-stage score semantics."
    requirement: COMP-02
    verification:
      - kind: unit
        ref: tests/testthat/test_phase15_nations_league.R
        status: pass
    human_judgment: false
  - id: D2
    description: "Wave 0 fixtures cover calibrated 1X2 mass, bounded conditional score-grid mass, deterministic hashes, replay order, and registered test output roots."
    requirement: SIM-01
    verification:
      - kind: unit
        ref: tests/testthat/test_phase15_nations_league.R
        status: pass
    human_judgment: false

# Metrics
duration: 8min
completed: 2026-08-22
status: complete
---

# Phase 15 Plan 00: Nations League Wave 0 Harness Summary

**A repository-root-aware Phase 15 test harness now freezes synthetic Nations League rules, stage, forecast, provenance, and replay contracts before production APIs exist.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-08-22T08:27:09Z
- **Completed:** 2026-08-22T08:34:45Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Added deterministic three-team League D and four-team League A fixtures with tied standings, discipline points, access-list positions, Article 13 admitted metadata, and explicit `unresolved_access_list` current-source rows.
- Added reciprocal two-leg fixtures with lower-league first-leg home ordering, an invalid duplicate-home case, Article 17 host-association metadata, and completed QF, semi-final, final, A/B, B/C, and C/D captures with regulation, extra-time, shootout, final-score, and completion fields.
- Added calibrated 1X2 and bounded score-grid fixtures, canonical row/table/tree hash helpers, exact missing-API errors, source loading, and a registered `tempdir()` output-root helper for later plans.

## Task Commits

Each task was committed atomically:

1. **Task 15-00-01: Create the Phase 15 focused harness and synthetic fixtures** - `2f8c31b` (test)

**Plan metadata:** recorded in this plan's final planning-artifact commit.

## Files Created/Modified

- `tests/testthat/test_phase15_nations_league.R` - Self-contained Wave 0 fixtures, deterministic hash helpers, repository loader, API guard, temp-root registration, and eight focused contract tests.

## Decisions Made

- Kept the harness self-contained and synthetic so Plans 15-01 through 15-06 can extend the same fixture names without adding separate fixture files.
- Preserved absent Article 13 evidence as `NA_integer_` positions, `NA` draw pots, and `unresolved_access_list` status rather than deriving access-list facts from group membership.
- Used category-scaled score-grid probabilities that exactly reproduce the calibrated `p_home`, `p_draw`, and `p_away` simplex while retaining bounded support.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected the API guard success-path environment**
- **Found during:** Task 15-00-01 focused verification
- **Issue:** The test initially looked up its own helper only in `.GlobalEnv`, while testthat evaluates the file in a private environment.
- **Fix:** Tested the success path with an explicit synthetic API environment while retaining the exact missing-symbol error path.
- **Files modified:** `tests/testthat/test_phase15_nations_league.R`
- **Verification:** Focused test file passes with zero skips and zero warnings.
- **Committed in:** `2f8c31b`

**2. [Rule 1 - Bug] Corrected reciprocal-leg invariant handling**
- **Found during:** Task 15-00-01 focused verification
- **Issue:** The first invariant rejected the expected repeated unordered participant pair across reciprocal legs and used a logical assertion for an integer duplicate index.
- **Fix:** Require one unique unordered pair with each participant hosting once, and assert the documented `0L` duplicate result.
- **Files modified:** `tests/testthat/test_phase15_nations_league.R`
- **Verification:** Reciprocal-leg and duplicate-home tests pass.
- **Committed in:** `2f8c31b`

---

**Total deviations:** 2 auto-fixed (Rule 1)
**Impact on plan:** Both fixes were confined to the planned harness and were required for the stated fixture contracts; no production scope was added.

## Issues Encountered

- The sandbox initially blocked creation of Git's index lock. The normal task commit was then created with elevated permission, still using standard hooks and staging only the planned test file.

## Known Stubs

None. The six later-plan API areas are explicit extension comments, not skipped tests or placeholder production behavior.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 15-01 can source the future rules and stage-admission APIs into this file and activate the named topology/source-contract assertions.
- Plans 15-02 through 15-06 can reuse the group, capture, forecast, hash, tree-snapshot, and registered-root helpers without changing fixture names.
- No production Phase 15 APIs or durable outputs were changed by this Wave 0 plan.

## Verification

`Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase15_nations_league.R", stop_on_failure=TRUE)'` passed with 8 test blocks, 72 expectations, 0 failures, 0 warnings, and 0 skips.

## Self-Check: PASSED

- Summary and harness files exist at their declared paths.
- Task commit `2f8c31b` is present in git history.
- The focused verification command passed after the task commit.

---
*Phase: 15-nations-league-rules-and-outcomes*
*Completed: 2026-08-22*
