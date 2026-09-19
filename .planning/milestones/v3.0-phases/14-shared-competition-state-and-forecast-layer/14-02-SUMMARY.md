---
phase: 14-shared-competition-state-and-forecast-layer
plan: "02"
subsystem: testing
tags: [r, testthat, release-contract, calibration, sha256, selector]
requires:
  - phase: 12-release-artifacts-and-installation
    provides: approved incumbent release contract and release-bundle validators
provides:
  - descriptor-only raw and fitted release fixtures materialized into complete temporary release roots
  - hash-bound selector, manifest, calibrator, and gate validation helpers
  - adversarial release-contract tests plus guarded assertions for later Phase 14 APIs
affects: [14-04, 14-06, 14-07, 14-08, 14-09, phase-17]
tech-stack:
  added: []
  patterns:
    - descriptor-only binary-free fixtures reconstructed from a trusted incumbent release
    - explicit self-hashed selectors bind tests to one exact release instead of directory recency
key-files:
  created:
    - tests/fixtures/phase14/raw_release/model_contract.json
    - tests/fixtures/phase14/raw_release/release_manifest.csv
    - tests/fixtures/phase14/calibrated_release/model_contract.json
    - tests/fixtures/phase14/calibrated_release/release_manifest.csv
    - tests/testthat/helper_phase14_release.R
    - tests/testthat/test_phase14_calibration_release.R
  modified: []
key-decisions:
  - "Keep committed release fixtures descriptor-only and reconstruct complete trusted roots from the incumbent model during tests."
  - "Bind fixture authority to a one-row self-hashed selector and exact manifest/object hashes while preserving distinct raw and fitted probability views."
patterns-established:
  - "Release fixture materialization: copy trusted immutable artifacts into a temporary root, replace calibration state, then regenerate all dependent hashes."
  - "Adversarial contract tests: rebind outer hashes when needed so each mutation reaches and exercises its intended invariant."
requirements-addressed: [FORECAST-01]
requirements-completed: []
duration: 21m
completed: 2026-08-16
status: complete
---

# Phase 14 Plan 02: Calibration Release Contract Surface Summary

Descriptor-only raw and fitted release fixtures now materialize hash-complete temporary release roots, with adversarial tests freezing selector, calibrator, gate, manifest, and final-label integrity before later Phase 14 APIs arrive.

## Performance

- **Duration:** 21 minutes
- **Started:** 2026-08-16T17:50:09Z
- **Completed:** 2026-08-16T18:10:41Z
- **Tasks:** 2
- **Files created:** 6

## Accomplishments

- Added compact raw and fitted calibration descriptors whose committed hashes cover the generated calibrator, manifest, selector, and gate state without storing binary model artifacts.
- Added a reusable helper that reconstructs complete release roots from the approved incumbent model, regenerates dependent hashes, and validates the exact selected release.
- Added direct `testthat` coverage for raw/fitted distinctions, complete materialization, tamper rejection, ambiguous-directory resistance, and immutable bundle validation.
- Seeded guarded contract tests for empirical calibration, selector-aware preflight, and dual-release rollback APIs scheduled for later Phase 14 plans.

## Task Commits

Each task was committed atomically:

1. **Task 1: Build descriptor-only raw and fitted release fixtures** — `e3983f4` (`test`)
2. **Task 2: Seed the calibration and release contract test surface** — `44bd470` (`test`)

## Files Created/Modified

- `tests/fixtures/phase14/raw_release/model_contract.json` — Raw-calibration fixture descriptor with expected object and selector hashes.
- `tests/fixtures/phase14/raw_release/release_manifest.csv` — Raw release manifest descriptor and expected self-hash.
- `tests/fixtures/phase14/calibrated_release/model_contract.json` — Fitted-calibration fixture descriptor with calibrated probability metadata.
- `tests/fixtures/phase14/calibrated_release/release_manifest.csv` — Fitted release manifest descriptor and expected self-hash.
- `tests/testthat/helper_phase14_release.R` — Temporary-root materialization, hash regeneration, selector creation, and fixture validation helpers.
- `tests/testthat/test_phase14_calibration_release.R` — Active adversarial release tests and guarded future API contracts.

## Decisions Made

- Committed only text descriptors; tests reconstruct full release roots from the trusted incumbent model so binary release artifacts are not duplicated in the repository.
- Made the selector authoritative through its own SHA-256 value and the selected manifest hash, preventing a newer sibling directory from changing the tested release.
- Preserved separate raw and fitted fixture semantics: raw releases expose the raw fallback and no calibration cutoff, while fitted releases require a calibrated primary view and a passing calibration gate.

## Deviations from Plan

None — the plan was executed exactly as written.

## Issues Encountered

- The fitted-gate mutation initially failed at the earlier calibrator-hash boundary. The test setup now deliberately rebinds the temporary contract, manifest, and selector hashes so the mutation reaches the intended fitted-gate invariant.

## Known Stubs

These guards are intentional contract seeds for APIs assigned to later Phase 14 plans; they do not prevent this fixture-and-test plan from meeting its objective.

| File | Line | Stub | Planned closure |
|------|------|------|-----------------|
| `tests/testthat/test_phase14_calibration_release.R` | 231 | Empirical calibration assertions skip until `phase14_evaluate_incumbent_calibration()` exists. | Plan 14-04 |
| `tests/testthat/test_phase14_calibration_release.R` | 252 | Selector-aware preflight assertions skip until `phase14_resolve_approved_release()` exists. | Plan 14-06 |
| `tests/testthat/test_phase14_calibration_release.R` | 325 | Dual-repin rollback assertions skip until the repin and promotion APIs exist. | Plan 14-09 |

All three guards are also recorded as open `skipped-test` entries in `.planning/WINDOWS.md`.

## Verification

- `Rscript --vanilla -e 'source("tests/testthat/helper_phase14_release.R"); ...'` — passed Task 1 acceptance checks for both fixture roots, exact selectors, valid hashes, distinct calibration states, and absence of committed binary fixtures.
- `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_calibration_release.R", stop_on_failure=TRUE)'` — passed with 31 active assertions and only the three intentional future-API guards skipped.
- `git diff --check 7c40ece0162a80d1d2954dc8b7c6d220bc1146e8..HEAD` — passed.

## Next Phase Readiness

- Plans 14-04, 14-06, and 14-09 can implement against the guarded API contracts and activate their assertions without changing fixture authority.
- `FORECAST-01` remains open because other Phase 14 plans also contribute to the requirement.
- No external setup or credentials are required.

## Self-Check: PASSED

- All six declared Plan 14-02 artifacts exist.
- Task commits `e3983f4` and `44bd470` exist in repository history.
- Both task-local verification commands and the plan-level direct test passed.
