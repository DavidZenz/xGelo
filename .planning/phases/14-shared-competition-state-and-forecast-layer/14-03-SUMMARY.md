---
phase: 14-shared-competition-state-and-forecast-layer
plan: "03"
subsystem: testing
tags: [r, testthat, forecast-contract, edition-isolation, g40, deterministic-replay]
requires:
  - phase: 12-release-artifacts-and-installation
    provides: approved release identities, model cutoffs, calibration state, and immutable predictor metadata
  - phase: 13-competition-data-foundation
    provides: edition registry, accepted source bundles, stable identities, and edition-scoped publication boundaries
provides:
  - exact G=40 fixture forecast contract with raw/calibrated views, uncertainty, suppression, and D-20 lineage
  - D-18 shared-input allowlist with D-21 local/shared failure fan-out expectations
  - deterministic normal/reversed replay fixture with explicit canonical byte count and SHA-256 identity
affects: [14-16, 14-17, 14-20, phase-17]
tech-stack:
  added: []
  patterns:
    - fixture-driven boundary contracts with active self-tests and guarded future production assertions
    - edition-local derived state with fail-closed shared-input allowlisting
key-files:
  created:
    - tests/fixtures/phase14/forecast_fixture.csv
    - tests/fixtures/phase14/edition_isolation_cases.csv
    - tests/testthat/test_phase14_forecast_layer.R
    - tests/testthat/test_phase14_state_bundle.R
  modified:
    - .planning/WINDOWS.md
key-decisions: []
patterns-established:
  - "Forecast contract: a scheduled eligible fixture owns one inclusive 0:40 grid, separate raw/calibrated simplices, deterministic top-10 ordering, and complete release/evidence lineage."
  - "Isolation contract: only identity, release, strengths, and declared senior history may be shared; every derived row remains edition-scoped."
requirements-addressed: [STATE-04, FORECAST-02]
requirements-completed: []
duration: 17m
completed: 2026-08-16
status: complete
---

# Phase 14 Plan 03: Forecast and Edition-Isolation Contract Summary

Exact G=40 forecast boundaries and a fail-closed edition-isolation matrix now freeze probability, uncertainty, lineage, shared-input fan-out, foreign-join, and deterministic replay behavior before the production tracer is implemented.

## Performance

- **Duration:** 17 minutes
- **Started:** 2026-08-16T18:16:33Z
- **Completed:** 2026-08-16T18:33:10Z
- **Tasks:** 2
- **Files created:** 4

## Accomplishments

- Added a compact forecast fixture with one eligible Austria/Germany Nations League match plus all six required suppression/lifecycle scenarios.
- Frozen the inclusive 0:40 score support, exact 1,681-cell count, distinct equal-probability cells, separate raw/calibrated simplices, deterministic top-10 ordering, mass tolerance, natural-log entropy, first-CDF intervals, analytic statuses, and complete D-20 lineage.
- Added an edition-isolation matrix proving NL-only and EURO-only invalidation, shared identity/release/history/active-evidence fan-out, inactive optional xG auditing, synthetic xG-active failure, declared history joins, and undeclared derived-state rejection.
- Bound normal and reversed state inputs to the same explicit 393-byte canonical payload and SHA-256 replay identity.

## Task Commits

Each task was committed atomically:

1. **Task 1: Freeze G=40 forecast, suppression, uncertainty, and lineage cases** — `ec6ba82` (`test`)
2. **Task 2: Freeze edition isolation, failure fan-out, and replay cases** — `56937e9` (`test`)

## Files Created/Modified

- `tests/fixtures/phase14/forecast_fixture.csv` — Eligible, empty-state, and suppression forecast rows with exact expected probabilities, uncertainty, cutoffs, and lineage.
- `tests/testthat/test_phase14_forecast_layer.R` — Active FORECAST-02 boundary tests plus the guarded future forecast-builder assertion.
- `tests/fixtures/phase14/edition_isolation_cases.csv` — D-18/D-21 sharing, invalidation, join, active-predictor, and replay case matrix.
- `tests/testthat/test_phase14_state_bundle.R` — Active STATE-04 isolation/replay tests plus the guarded future state-candidate assertion.
- `.planning/WINDOWS.md` — Open skipped-test entries for the two production APIs scheduled in Plan 14-16.

## Decisions Made

None — this plan codified the established D-13, D-14, D-16 through D-18, D-20, and D-21 decisions without introducing new domain choices.

## Deviations from Plan

None — the plan was executed exactly as written.

## Issues Encountered

- Initial fixture/test runs exposed one CSV field alignment issue and three assertion type/name mismatches. They were corrected before the task commits; no contract scope or production behavior changed.

## Known Stubs

These guards are intentional Wave 0 contract seeds for production APIs assigned to Plan 14-16; they do not prevent this fixture-and-test plan from meeting its objective.

| File | Line | Stub | Planned closure |
|------|------|------|-----------------|
| `tests/testthat/test_phase14_forecast_layer.R` | 419 | Production forecast assertion skips until `phase14_build_fixture_forecasts()` exists. | Plan 14-16 |
| `tests/testthat/test_phase14_state_bundle.R` | 247 | Production state-candidate assertion skips until `phase14_build_competition_state_candidate()` exists. | Plan 14-16 |

Both guards are recorded as open `skipped-test` entries in `.planning/WINDOWS.md`.

## Verification

- `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_forecast_layer.R", stop_on_failure=TRUE)'` — passed with 68 active assertions and only the intentional future forecast-builder guard skipped.
- `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_state_bundle.R", stop_on_failure=TRUE)'` — passed with 63 active assertions and only the intentional future state-candidate guard skipped.
- Both files run together from a fresh R process — passed with 131 active assertions, zero failures, and exactly two planned skips.
- `git diff --check bd15de5e0b8f19f109f1b134e5f68ab1bb3077e6..HEAD` — passed.

## Next Phase Readiness

- Plan 14-16 can implement the forecast and state-candidate tracer directly against these fixtures, then activate the two guarded production assertions.
- Plans 14-17 and 14-20 can expand batch validation and failure isolation without changing the frozen shared-input allowlist or replay identity.
- `STATE-04` and `FORECAST-02` remain open because other Phase 14 plans also contribute to both requirements.
- No external setup or credentials are required.

## Self-Check: PASSED

- All four declared Plan 14-03 artifacts and this summary exist.
- Task commits `ec6ba82` and `56937e9` exist in repository history.
- Both task-local verification commands and the fresh-process plan-level test passed.
