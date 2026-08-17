---
phase: 14-shared-competition-state-and-forecast-layer
plan: "14"
subsystem: competition-state
tags: [standings, cutoff, reconciliation, provenance, tdd]

# Dependency graph
requires:
  - phase: 14-shared-competition-state-and-forecast-layer
    provides: Plan 14-13 canonical match identity, lifecycle, score, evidence, and counts_for_standings semantics
provides:
  - Four-part keyed, cutoff-safe universal standings reducer with deterministic provisional ordering
  - Explicit competition ruleset adapter seam for official ordering
  - Same-source-bundle official reconciliation and fail-closed snapshot validation
affects: [phase-14-form, phase-14-forecast, phase-15-nations-league-rules, phase-16-euro-qualifying-rules]

# Tech tracking
tech-stack:
  added: []
  patterns: [universal football arithmetic, evidence cutoff filtering, source-bundle provenance binding, canonical SHA-256 snapshot hashes]

key-files:
  created:
    - R/competition/standings.R
  modified:
    - tests/testthat/test_phase14_standings.R

key-decisions:
  - "Standings computes only universal football arithmetic; competition-specific ordering remains behind an explicit ruleset adapter and is provisional when no adapter is supplied."
  - "Eligibility requires counts_for_standings, a completed paired final score, and evidence_completed_at_utc at or before state_cutoff_utc."
  - "Official aggregates reconcile only within the computed source bundle; aggregate, partial, and foreign mismatches retain prior state while rank-only disagreement warns."

patterns-established:
  - "Every snapshot carries edition_id, group_id, state_cutoff_utc, and source_bundle_id as an exact identity key."
  - "Computed and official fields remain side-by-side, with explicit ordering, reconciliation, warning, block, and prior-retention statuses."

requirements-completed: [STATE-01]

coverage:
  - id: D1
    description: "Universal standings reducer computes cutoff-safe played, W/D/L, goals, goal difference, points, keyed hashes, and provisional/adapter ordering."
    requirement: STATE-01
    verification:
      - kind: unit
        ref: "tests/testthat/test_phase14_standings.R — reducer, cutoff, key, hash, and adapter tests"
        status: pass
    human_judgment: false
  - id: D2
    description: "Same-bundle official standings reconciliation distinguishes exact, rank-only, blocked aggregate/partial, absent provisional, and foreign-bundle outcomes."
    requirement: STATE-01
    verification:
      - kind: unit
        ref: "tests/testthat/test_phase14_standings.R — reconciliation and fail-closed validation tests"
        status: pass
    human_judgment: false

# Metrics
duration: 12min
completed: 2026-08-17
status: complete
---

# Phase 14 Plan 14: Cutoff-safe universal standings and official reconciliation Summary

**Cutoff-safe universal standings with explicit provisional ordering, same-bundle official reconciliation, and fail-closed snapshot hashes**

## Performance

- **Duration:** 12 minutes
- **Started:** 2026-08-17T17:01:20Z
- **Completed:** 2026-08-17T17:17:06Z
- **Tasks:** 2
- **Files modified:** 2 implementation/test files

## Accomplishments

- Added `phase14_compute_standings()` with four-part snapshot identity, evidence-time cutoff filtering, universal football metrics, deterministic provisional ordering, and an explicit ruleset adapter seam.
- Added `phase14_reconcile_standings()` and `phase14_validate_standings_snapshot()` with side-by-side computed/official fields, same-bundle enforcement, canonical row/table hashes, and prior-state retention for blocked results.
- Expanded the Phase 14 standings fixture coverage across exact, rank-only, aggregate mismatch, partial official, absent official, foreign bundle, late evidence, adapter, and tampering cases.

## Task Commits

Each TDD task was committed atomically with a RED test commit followed by a GREEN implementation commit:

1. **Task 14-14-01: Compute fully keyed cutoff-safe universal standings**
   - `1297428` — `test(14-14): add failing tests for cutoff-safe standings`
   - `666429a` — `feat(14-14): implement cutoff-safe universal standings`
2. **Task 14-14-02: Reconcile same-bundle official standings and block aggregates**
   - `1c747ec` — `test(14-14): add failing reconciliation and validation tests`
   - `d1d6e8a` — `feat(14-14): complete standings reconciliation`

## Files Created/Modified

- `R/competition/standings.R` - Universal reducer, ruleset adapter seam, reconciliation state machine, and snapshot validation/hash helpers.
- `tests/testthat/test_phase14_standings.R` - TDD coverage for cutoff safety, keys, arithmetic, ordering, provenance, reconciliation, retention, and tamper detection.

## Decisions Made

- Kept competition-specific ordering out of the universal reducer; no adapter is explicitly marked `provisional` rather than being presented as official.
- Bound both computed and official standings to the same edition/group/cutoff/source bundle identity, rejecting foreign provenance before publication.
- Made aggregate and partial official disagreement fail closed with `retain_prior`, while rank-only disagreement remains publishable with a warning.

## TDD Gate Compliance

- Task 14-14-01 RED: `1297428` (expected failures before implementation).
- Task 14-14-01 GREEN: `666429a`; focused verification passed with 229 assertions.
- Task 14-14-02 RED: `1c747ec` (expected failures before reconciliation fixes).
- Task 14-14-02 GREEN: `d1d6e8a`; final focused verification passed with 237 assertions.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Allowed signed goal difference in metric validation**
- **Found during:** Task 14-14-01 GREEN verification
- **Issue:** The first validation path treated `goal_difference` like a non-negative metric and rejected valid negative values.
- **Fix:** Kept non-negative validation for goals/points while validating goal difference as a signed integer.
- **Files modified:** `R/competition/standings.R`
- **Verification:** Focused standings test passed with 229 assertions after the fix.
- **Committed in:** `666429a`

**2. [Rule 1 - Bug] Guarded nullable accepted source-bundle input**
- **Found during:** Task 14-14-02 RED/GREEN verification
- **Issue:** The reconciliation guard called `is.na()` on a `NULL` accepted bundle and errored before producing the required provisional/blocked disposition.
- **Fix:** Check for non-`NULL` and non-`NA` accepted bundle values before comparing provenance.
- **Files modified:** `R/competition/standings.R`
- **Verification:** Final focused standings test passed with 237 assertions.
- **Committed in:** `d1d6e8a`

**3. [Rule 1 - Contract handling] Permitted one-row official rank fragments**
- **Found during:** Task 14-14-02 RED/GREEN verification
- **Issue:** Validation required a complete contiguous rank sequence even for the fixture's intentionally partial one-row official fragment, preventing the required `partial_official_blocked` result.
- **Fix:** Preserve contiguous-rank validation for full snapshots while allowing a single-row fragment to reach the partial reconciliation disposition.
- **Files modified:** `R/competition/standings.R`
- **Verification:** Partial-official fixture and full snapshot validation both pass in the final focused suite.
- **Committed in:** `d1d6e8a`

**Total deviations:** 3 auto-fixed issues (Rule 1: 3)

**Impact on plan:** All fixes were directly required for the stated signed-metric, partial-official, and null-safe reconciliation contracts. No scope creep or architectural change was introduced.

## Issues Encountered

None in the plan deliverables remain. The shared standings module contains the common schema/hash helpers used by both TDD task surfaces; the reconciliation behavior still has its own RED and GREEN commits and acceptance coverage. The best-effort broken-windows append was not applied because the pre-existing ledger frontmatter counts disagree with its entries; `.planning/WINDOWS.md` was left unchanged.

## Known Stubs

None found in the files created or modified by this plan.

## Threat Flags

None. The plan's declared cutoff/provenance tampering and official/provisional spoofing controls are implemented and covered by the focused test suite.

## User Setup Required

None - no external service configuration required.

## Verification

```text
Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_standings.R", stop_on_failure=TRUE)'
PASS 237, FAIL 0, WARN 0, SKIP 0
```

## Next Phase Readiness

The shared standings layer is ready for downstream form, forecast, and competition-specific rules plans. No blocker remains; later plans must supply the appropriate competition ruleset adapter before claiming official ordering.

---
*Phase: 14-shared-competition-state-and-forecast-layer*
*Plan: 14*
*Completed: 2026-08-17*

## Self-Check: PASSED

- Summary file exists at the expected phase path.
- All four Plan 14-14 TDD commits are present in git history: `1297428`, `666429a`, `1c747ec`, and `d1d6e8a`.
- Summary content passes `git diff --check`.
