---
phase: 14-shared-competition-state-and-forecast-layer
plan: "04"
subsystem: release-calibration
tags: [r, testthat, calibration, chronology, empirical-gate, fail-closed]
requires:
  - phase: 09-rolling-tournament-benchmark
    provides: frozen 630-fixture incumbent updating/open-core benchmark evidence
  - phase: 12-release-artifacts-and-installation
    provides: immutable incumbent identity, 1X2 calibration recipe, selection protocol, and unchanged veto implementation
  - phase: 14-shared-competition-state-and-forecast-layer
    plan: "02"
    provides: calibration release contracts and downstream fail-closed guards
provides:
  - chronology-safe rolling incumbent calibration over exactly 630 historical development fixtures
  - hash-bound raw-versus-calibrated empirical gate evaluated with unchanged Phase 12 vetoes
  - durable CALIBRATION_RELEASE_BLOCKED evidence that downstream promotion validation refuses
affects: [14-05, 14-06, 14-09, 14-16, 14-17]
tech-stack:
  added: []
  patterns:
    - strict prior-edition calibration with immutable source, fixture, recipe, protocol, and code lineage
    - pass-or-block evidence with recomputed gate decisions and fail-closed promotion validation
key-files:
  created:
    - R/release/calibration_revision.R
    - outputs/benchmarks/rolling_tournaments/phase14-incumbent-calibration-revision/calibrator.rds
    - outputs/benchmarks/rolling_tournaments/phase14-incumbent-calibration-revision/calibrated_predictions.csv
    - outputs/benchmarks/rolling_tournaments/phase14-incumbent-calibration-revision/calibration_gate.csv
    - outputs/benchmarks/rolling_tournaments/phase14-incumbent-calibration-revision/calibration_revision_manifest.csv
  modified:
    - tests/testthat/test_phase14_calibration_release.R
key-decisions:
  - "D-15 empirical outcome is CALIBRATION_RELEASE_BLOCKED because unchanged RPS and strict calibration-improvement vetoes fail; release, selector, and registry authority remain untouched."
  - "Blocked calibration evidence remains auditable candidate evidence only; require_promoted validation rejects it downstream."
patterns-established:
  - "Calibration development panel: select open_nb_incumbent/updating/open_core from 1,260 source rows and fail unless exactly 630 rows map one-to-one to 630 fixtures."
  - "Gate durability: hash every input and output, recompute the unchanged Phase 12 decision, and distinguish valid blocked evidence from promotable evidence."
requirements-addressed: [FORECAST-01]
requirements-completed: []
duration: 41m
completed: 2026-08-16
status: complete
---

# Phase 14 Plan 04: Incumbent Calibration Revision Summary

Chronology-safe rolling calibration now evaluates the frozen incumbent on exactly 630 historical fixtures and persists hash-bound blocked evidence after the unchanged Phase 12 gate rejects it on RPS and strict calibration improvement.

## Performance

- **Duration:** 41 minutes
- **Started:** 2026-08-16T18:40:28Z
- **Completed:** 2026-08-16T19:21:53Z
- **Tasks:** 2
- **Files created:** 5
- **Files modified:** 1

## Accomplishments

- Selected exactly 630 `open_nb_incumbent` / `updating` / `open_core` rows and 630 unique fixtures from the frozen 1,260-row incumbent source without reading or using WC2026 labels.
- Fit rolling 1X2 calibration in strict prior-edition order, then fit the final candidate calibrator only after the rolling evaluation, preserving raw probabilities, score-distribution identities, auxiliary markets, completion dates, and immutable source hashes.
- Reused `phase12_selection_decision()` with its original support, coverage, score-identity, RPS, Brier, log-loss, fold-stability, and strict calibration-improvement vetoes unchanged.
- Persisted one empirical gate row and a manifest hashing every input and output; canonical validation recomputes the evidence and refuses downstream promotion for the blocked disposition.
- Confirmed that release-manifest, selector, and edition-registry authority files were not modified by any Plan 14-04 commit.

## Empirical Gate Disposition

**Disposition:** `CALIBRATION_RELEASE_BLOCKED`  
**Ordered reasons:** `rps_veto|calibration_not_improved`

| Metric | Observed change | Gate result |
|--------|----------------:|-------------|
| RPS delta | `+0.0008328552` | Failed veto |
| Brier relative change | `+0.002499697` | Passed unchanged tolerance |
| Log-loss relative change | `+0.002116221` | Passed unchanged tolerance |
| Maximum fold regression | `+0.009795255` | Passed unchanged tolerance |
| Calibration-error delta | `+0.00307133` | Failed strict improvement |

The blocked result is a valid completion outcome for this plan, but it is not promotable: `phase14_validate_calibration_revision(..., require_promoted = TRUE)` fails closed. The primary probability view remains raw 1X2, `calibration_promoted` is false, and `authority_mutated` is false.

## TDD Execution

1. **Task 1 RED** — `af6a34f` added exact-slice, duplicate-fixture, chronology, holdout-path, and lineage contracts. The test failed because `phase14_build_incumbent_development_panel()` and `phase14_fit_rolling_incumbent_calibration()` did not yet exist.
2. **Task 1 GREEN** — `d963af3` implemented the chronology-safe panel and rolling/final calibrator and persisted the candidate artifacts. The Phase 14 calibration suite passed 64 active assertions with three then-planned guards skipped; the unchanged Phase 12 suite passed 76 assertions.
3. **Task 2 RED** — `bc5e141` added exact veto-order, durable gate/manifest, authority-neutrality, tamper detection, and downstream-blocking contracts. The test failed because the evaluator and validator did not yet exist.
4. **Task 2 GREEN** — `0ef4849` implemented evaluation, durable blocked evidence, manifest hashing, decision recomputation, and fail-closed validation. The final Phase 14 suite passed 93 active assertions with two pre-existing future-plan guards skipped.

## Task Commits

Each RED and GREEN step was committed atomically:

1. **Task 1 RED: Calibration revision contracts** — `af6a34f` (`test`)
2. **Task 1 GREEN: Chronology-safe incumbent calibration** — `d963af3` (`feat`)
3. **Task 2 RED: Empirical gate contracts** — `bc5e141` (`test`)
4. **Task 2 GREEN: Empirical calibration gate** — `0ef4849` (`feat`)

## Files Created/Modified

- `R/release/calibration_revision.R` — Exact development-panel construction, rolling/final calibration, empirical gate evaluation, artifact persistence, and fail-closed validation.
- `tests/testthat/test_phase14_calibration_release.R` — Active TDD contracts for chronology, cardinality, lineage, unchanged veto ordering, authority neutrality, tampering, and downstream blocking.
- `outputs/benchmarks/rolling_tournaments/phase14-incumbent-calibration-revision/calibrator.rds` — Candidate 1X2 calibrator bound to the frozen incumbent and historical evidence only.
- `outputs/benchmarks/rolling_tournaments/phase14-incumbent-calibration-revision/calibrated_predictions.csv` — Rolling calibrated predictions for exactly 630 historical fixtures with preserved score/distribution identities.
- `outputs/benchmarks/rolling_tournaments/phase14-incumbent-calibration-revision/calibration_gate.csv` — One-row empirical blocked disposition and unchanged veto diagnostics.
- `outputs/benchmarks/rolling_tournaments/phase14-incumbent-calibration-revision/calibration_revision_manifest.csv` — Immutable hashes for every input and output plus manifest self-identity.

## Decisions Made

- Accepted the empirical blocked disposition exactly as produced by the frozen evidence and unchanged protocol; no threshold or operator was weakened.
- Kept the revision outside release, selector, and registry authority. The blocked candidate can be audited but cannot satisfy a promoted-release precondition.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Retained fixture score eligibility for frozen scoring**

- **Found during:** Task 2 GREEN empirical comparison
- **Issue:** The development-panel builder validated `score_eligible` but did not retain it, causing the frozen headline scorer to report that registered tournaments lacked eligible coverage.
- **Fix:** Preserved `score_eligible` in the calibrated evidence and included it in fixture-projection lineage before regenerating the candidate artifacts.
- **Files modified:** `R/release/calibration_revision.R`, `calibrator.rds`, `calibrated_predictions.csv`
- **Commit:** `0ef4849`

**2. [Rule 1 - Bug] Accounted for numeric CSV serialization in validation**

- **Found during:** Task 2 GREEN durable-artifact validation
- **Issue:** Exact in-memory equality rejected a valid gate after decimal text was written to and read from CSV, despite identical gate decisions and reason ordering.
- **Fix:** Kept disposition, booleans, reason codes, thresholds, and operators exact while comparing serialized numeric diagnostics at `1e-12`, far below any gate threshold.
- **Files modified:** `R/release/calibration_revision.R`
- **Commit:** `0ef4849`

Neither deviation changes model-selection policy, release authority, or the blocked empirical outcome.

## Issues Encountered

- The empirical candidate did not satisfy the frozen RPS and strict calibration-improvement vetoes. This is an expected, valid blocked outcome rather than an execution failure; downstream promotion remains unavailable.

## Known Stubs

No new Plan 14-04 stubs were introduced. Two pre-existing Wave 0 guards remain in the modified shared test file and were already recorded in `.planning/WINDOWS.md` by Plan 14-02:

| File | Current line | Existing guard | Planned closure |
|------|-------------:|----------------|-----------------|
| `tests/testthat/test_phase14_calibration_release.R` | 508 | Selector-aware preflight awaits `phase14_resolve_approved_release()`. | Plan 14-06 |
| `tests/testthat/test_phase14_calibration_release.R` | 581 | Atomic dual-repin assertions await `phase14_repin_both_competition_releases()` and `phase14_promote_calibrated_release()`. | Plan 14-09 |

## Test Evidence

- Task 1 plan command — Phase 14 calibration tests and unchanged Phase 12 calibration tests passed.
- Task 2 plan command — 93 Phase 14 assertions passed, canonical `phase14_validate_calibration_revision()` returned true, and only the two pre-existing future-plan guards skipped.
- Fresh-process plan regression — Phase 14: 93 passed, 0 failed, 0 warnings, 2 planned skips; Phase 12: 76 passed, 0 failed, 0 warnings, 0 skips; canonical validation passed.
- Acceptance check — `630` calibrated rows, `630` unique fixtures, one blocked gate row, exact reason order, no WC2026 identity in persisted evidence, and `require_promoted = TRUE` refused the blocked result.
- `git diff --check` passed before the Task 2 commit.
- Plan commit diff from `22bf11c` contains only the six declared implementation/test/evidence files; release, selector, and registry authority files are absent.

## Next Phase Readiness

- Plans 14-05 and 14-06 can consume the durable blocked disposition but must preserve raw 1X2 as the primary view and fail any precondition that requires promoted calibration.
- Plan 14-09 must not repin calibration authority unless a future frozen evidence revision independently satisfies every unchanged veto.
- `FORECAST-01` remains open because later Phase 14 plans also contribute to the requirement.
- No external setup or credentials are required.

## Self-Check: PASSED

- All six declared Plan 14-04 implementation, test, and evidence files plus this summary exist.
- Task commits `af6a34f`, `d963af3`, `bc5e141`, and `0ef4849` exist in repository history.
- Both task-local verification commands, the full fresh-process regression, the canonical validator, and the downstream promotion-refusal check passed.
