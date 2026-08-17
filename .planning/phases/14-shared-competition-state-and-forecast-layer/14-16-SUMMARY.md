---
phase: 14-shared-competition-state-and-forecast-layer
plan: "16"
subsystem: competition-forecasting
tags: [R, testthat, release-selector, elo, negative-binomial, xg, lineage]

# Dependency graph
requires:
  - phase: 14-shared-competition-state-and-forecast-layer
    provides: canonical match identity, edition lifecycle, cutoff-safe form, and approved calibrated release authority from Plans 14-13 through 14-15
provides:
  - permanent canonical-match-to-forecast vertical tracer
  - edition-scoped state candidate orchestration with required-input fan-out
  - honest inactive national-team xG suppression and EURO pre_draw emptiness
affects: [phase-14-17, phase-14-18, phase-15, phase-16, shared-dashboard-forecast-consumers]

# Tech tracking
tech-stack:
  added: []
  patterns: [release-active-predictor evidence gating, strict pre-kickoff lineage, in-memory edition-scoped candidate state]

key-files:
  created:
    - R/competition/forecast_layer.R
    - R/competition/state_bundle.R
  modified:
    - tests/testthat/test_phase14_forecast_layer.R
    - tests/testthat/test_phase14_state_bundle.R

key-decisions:
  - "Runtime forecast authority remains phase14_resolve_approved_release(selector_path, trusted_release_root); raw manifests and model discovery never become fallback authority."
  - "The immutable manifest controls evidence sufficiency: the current incumbent activates elo_diff, while dropped xG/form predictors remain NA and audited unavailable rather than becoming forecast requirements."
  - "A required active predictor failure fans out across shared edition candidates, while fixtures, results, form, standings, and forecasts remain edition-scoped."
  - "EURO pre_draw is a truthful zero-row state, and the forecast contract uses bounded G=40 score support with calibrated 1X2 and retained lineage."

patterns-established:
  - "Canonical adapter: stable team IDs resolve only through the accepted registry; confirmed kickoff supplies date and strict cutoff evidence."
  - "Fresh-process-safe production boundaries: state orchestration uses a private null-coalescing helper instead of ambient project-wide operators."

requirements-completed: [STATE-01, STATE-02, STATE-03, STATE-04, FORECAST-01, FORECAST-02, FORECAST-03]

coverage:
  - id: D1
    description: "Austria/Germany scheduled fixture reaches the approved Elo-only release, calibrated 1X2, G=40 distribution, uncertainty, and D-20 lineage."
    requirement: FORECAST-01
    verification:
      - kind: e2e
        ref: "tests/testthat/test_phase14_forecast_layer.R#permanent Austria/Germany tracer adapts the canonical fixture and preserves strict lineage"
        status: pass
      - kind: other
        ref: "Rscript --vanilla -e 'testthat::test_file(\"tests/testthat/test_phase14_forecast_layer.R\", stop_on_failure=TRUE); testthat::test_file(\"tests/testthat/test_phase14_state_bundle.R\", stop_on_failure=TRUE)'"
        status: pass
    human_judgment: false
  - id: D2
    description: "Edition-scoped state candidates preserve NL forecastability, EURO pre_draw emptiness, cross-edition rejection, and required-input fan-out."
    requirement: STATE-04
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase14_state_bundle.R#state candidate keeps NL forecastable and EURO pre_draw structurally empty"
        status: pass
      - kind: integration
        ref: "tests/testthat/test_phase14_state_bundle.R#active required shared input failure fans out while inactive xG remains audited"
        status: pass
    human_judgment: false

# Metrics
duration: 36min
completed: 2026-08-17
status: complete
---

# Phase 14 Plan 16: Shared competition state and forecast layer Summary

**Permanent release-active Austria/Germany forecast tracer with strict pre-kickoff Elo, calibrated G=40 score distributions, honest xG availability, and edition-isolated state candidates.**

## Performance

- **Duration:** 36 min
- **Started:** 2026-08-17T20:01:31+02:00
- **Completed:** 2026-08-17T20:37:22+02:00
- **Tasks:** 1 completed
- **Files modified:** 4

## Accomplishments

- Added the production canonical adapter and release-active feature boundary. It maps accepted stable team IDs, derives date from confirmed kickoff, enforces strict pre-kickoff evidence, retains model/release/calibrator/registry lineage, and routes the approved selector into the existing registered baseline.
- Added the permanent one-fixture forecast path with calibrated 1X2, analytic negative-binomial uncertainty, exact 0..40 score support, top-scoreline/omitted mass, and row hashes.
- Added edition-scoped candidate orchestration. Required active-input failures fan out across candidates; inactive national-team xG remains audited unavailable/NA; EURO `pre_draw` emits no fabricated fixtures, groups, standings, form, forecasts, or grids.
- Completed the TDD vertical slice: RED test commit followed by GREEN production commit, then a post-commit tracer gate in one fresh R process.

## Task Commits

Each task was committed atomically:

1. **Task 14-16-01: Carry one scheduled match and one pre_draw edition end to end** - `a5200b2` (test: RED failing tracer assertions)
2. **Task 14-16-01: Carry one scheduled match and one pre_draw edition end to end** - `75a0af5` (feat: GREEN permanent production tracer)

Plan metadata is reconciled in the final documentation commit after STATE/ROADMAP updates.

## Files Created/Modified

- `R/competition/forecast_layer.R` - Canonical-match adaptation, immutable manifest evidence gating, strict Elo, calibrated baseline forecast, bounded score grid, uncertainty, and lineage.
- `R/competition/state_bundle.R` - Edition-parameterized in-memory candidate orchestration, pre_draw suppression, cross-edition rejection, and shared failure fan-out.
- `tests/testthat/test_phase14_forecast_layer.R` - RED/GREEN contract coverage for the permanent Austria/Germany path, active xG suppression, and club-form rejection.
- `tests/testthat/test_phase14_state_bundle.R` - RED/GREEN contract coverage for candidate state, EURO pre_draw, inactive xG audit, fan-out, and cross-edition rejection.

## Decisions Made

- Kept the approved selector as the sole runtime release authority and used the immutable model manifest to decide which evidence is required.
- Kept national-team xG explicitly unavailable/NA under the current Elo-only incumbent; synthetic xG-active manifests suppress instead of silently substituting club form or football goals.
- Kept all derived state in edition-scoped candidate objects; only explicitly shared identity, release, strength, and declared senior-history inputs can fan out.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Made active-predictor and evidence checks vector-safe**
- **Found during:** Task 14-16-01 GREEN verification
- **Issue:** The active-xG alias helper assumed a scalar predictor, and the companion presence check used scalar `isTRUE()` semantics for batches.
- **Fix:** Applied scalar mapping through `vapply()` and validated all row-aligned companion flags.
- **Files modified:** `R/competition/forecast_layer.R`
- **Verification:** Forecast tracer passed with the current and synthetic xG-active manifests.
- **Committed in:** `75a0af5`

**2. [Rule 3 - Blocking] Fixed state bootstrap root discovery**
- **Found during:** Standalone state-bundle verification
- **Issue:** Loading the production state API from `tests/testthat` attempted to source dependencies relative to the test directory.
- **Fix:** Added upward project-root discovery before bootstrapping the forecast layer.
- **Files modified:** `R/competition/state_bundle.R`
- **Verification:** Standalone state test and the combined fresh-process tracer both passed.
- **Committed in:** `75a0af5`

**3. [Rule 1 - Bug] Isolated state null-coalescing from ambient global redefinitions**
- **Found during:** Exact combined fresh-process tracer gate
- **Issue:** A previously sourced project module redefined `%||%`; applying that operator to the canonical match data frame caused state construction to fail only when both tracer files ran in one R process.
- **Fix:** Added and used a private `phase14_state_bundle_or()` helper for state orchestration.
- **Files modified:** `R/competition/state_bundle.R`
- **Verification:** Exact plan command passed after the fix, including both files in one fresh process.
- **Committed in:** `75a0af5`

**Total deviations:** 3 auto-fixed (2 Rule 1, 1 Rule 3)
**Impact on plan:** All fixes were directly required for the permanent tracer’s correctness and fresh-process isolation; no architecture or scope expansion was introduced.

## Issues Encountered

- The shared master worktree contained unrelated dirty benchmark and scratch artifacts. They were left untouched and excluded from every task staging operation.
- The sandbox required an approved escalation for the Git index lock during commit; no code or repository-content blocker remained.

## User Setup Required

None - no external service configuration required.

## Verification

- RED gate: focused forecast verification failed as expected before production functions existed; committed as `a5200b2`.
- GREEN/post-commit tracer gate: exact command from the plan passed in one fresh R process with `108` forecast assertions and `86` state assertions, zero failures, warnings, or skips.
- Syntax checks: `R/competition/forecast_layer.R` and `R/competition/state_bundle.R` parsed successfully.

## Known Stubs

None. The empty EURO `pre_draw` structures and inactive national-team xG `NA` values are intentional contract outputs, not placeholders.

## Next Phase Readiness

The permanent vertical slice is ready for the planned batch expansion. Downstream plans can consume `phase14_build_competition_state_candidate()` and `phase14_build_fixture_forecasts()` while preserving selector authority, strict cutoffs, G=40, inactive-xG honesty, synthetic xG-active suppression, and EURO pre_draw semantics.

---
*Phase: 14-shared-competition-state-and-forecast-layer*
*Plan: 16*
*Completed: 2026-08-17*

## Self-Check: PASSED

- Summary file exists at the required phase path.
- RED commit `a5200b2` and GREEN commit `75a0af5` are present in Git history.
- All four plan-owned source/test files are present or committed as scoped changes.
- Exact combined fresh-process verification passed with zero failures, warnings, or skips.
