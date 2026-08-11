---
phase: 12-calibration-promotion-and-model-release
plan: 01
subsystem: testing
tags: [R, freeze-manifest, calibration-recipe, sha256, sealed-holdout]

# Dependency graph
requires:
  - phase: 11-hybrid-ml-and-contextual-priors
    provides: "The nine-candidate Phase 11 registry and durable hybrid benchmark parent"
provides:
  - "Authoritative self-hashed Phase 12 freeze manifest"
  - "Canonical base-R temperature-scaling recipe with frozen support and seed"
  - "Fail-closed candidate, parent, code, threshold, and unopened-holdout validation"
affects: [phase12-calibration, phase12-final-evaluation, phase12-promotion, phase12-release]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Canonical CSV/JSON identity hashing with durable relative parent paths"
    - "Ordered machine-readable freeze reason codes and fresh-process read-back"

key-files:
  created:
    - R/release/freeze_manifest.R
    - data/benchmark/phase12/calibration_recipe.json
    - data/benchmark/phase12/freeze_manifest.csv
  modified:
    - tests/testthat/test_phase12_freeze.R

key-decisions:
  - "Use the durable Phase 11 hybrid run manifest path as the sole Phase 11 parent identity."
  - "Keep calibration recipe serialization and its SHA-256 binding entirely before any downstream fit API."
  - "Treat unrelated dirty benchmark/output paths as outside the code-cleanliness surface while rejecting dirty R production code."

patterns-established:
  - "All nine candidates are retained in canonical candidate-id order, including explicit inactive/no-score rows."
  - "Freeze validation recomputes recipe, registry component, parent graph, protocol-threshold, and self hashes."

requirements-completed: [PROMO-01]

coverage:
  - id: D1
    description: "A canonical recipe and nine-row self-hashed freeze bind candidates, G=40, protocol thresholds, component identities, and durable parents before fitting."
    requirement: PROMO-01
    verification:
      - kind: unit
        ref: "tests/testthat/test_phase12_freeze.R#12-01-01 builds and independently validates a synthetic nine-row freeze"
        status: pass
      - kind: integration
        ref: "Rscript --vanilla -e 'source(\"R/release/freeze_manifest.R\"); validate_phase12_freeze_manifest()'"
        status: pass
    human_judgment: false
  - id: D2
    description: "Freeze drift, unsafe parent paths, dirty-code flags, threshold/support changes, and consumed-holdout markers fail closed with ordered reason codes."
    requirement: PROMO-01
    verification:
      - kind: unit
        ref: "tests/testthat/test_phase12_freeze.R#12-01-02 freeze rejects empty, partial, single, and drifted registries"
        status: pass
      - kind: integration
        ref: "test_benchmark_promotion.R (169 assertions passed)"
        status: pass
    human_judgment: false

# Metrics
duration: 19 min
completed: 2026-08-11
status: complete
---

# Phase 12 Plan 01: Freeze Manifest and Calibration Recipe Summary

**Authoritative nine-candidate Phase 12 freeze with pre-fit temperature recipe, durable parent graph, and fail-closed drift validation**

## Performance

- **Duration:** 19 min
- **Started:** 2026-08-11T08:22:34Z
- **Completed:** 2026-08-11T08:41:32Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Added `R/release/freeze_manifest.R` with canonical recipe writing, candidate normalization, parent graph hashing, self-hash construction, unopened-holdout guard, and independent validation.
- Materialized `calibration_recipe.json` with the locked base-R one-parameter temperature recipe, optimizer/bounds, epsilon, support floors, seed `920012`, and `G=40`.
- Materialized a nine-row Phase 11 freeze bound to candidate registration/status, code cleanliness, features/settings/panels/seeds, protocol thresholds, durable Phase 9/10/11 parents, and the exact Phase 11 run-manifest bytes.
- Extended only the owned freeze test with synthetic nine-row, empty/partial/single, identity-order, drift, path-safety, and consumed-marker contracts.

## Task Commits

Each task was committed atomically:

1. **Task 1: Trace registry, frozen recipe, parent graph, and checksum into one validated freeze** - `dc2b725` (`feat`)
2. **Task 2: Complete freeze drift, parent, and unopened-holdout validation** - `8cb9fe4` (`feat`)

## Files Created/Modified

- `R/release/freeze_manifest.R` - Phase 12 freeze construction, canonical parent graph, recipe binding, and validation APIs.
- `data/benchmark/phase12/calibration_recipe.json` - Frozen calibration recipe contract.
- `data/benchmark/phase12/freeze_manifest.csv` - Authoritative self-hashed nine-candidate freeze.
- `tests/testthat/test_phase12_freeze.R` - Owned synthetic freeze and fail-closed drift tests.

## Decisions Made

- The Phase 11 parent is resolved only from `outputs/benchmarks/rolling_tournaments/phase11-hybrid-challengers/run_manifest.csv`; its actual file hash is persisted and recomputed.
- The freeze stays label-free and exposes only a pre-fit control-plane contract; no calibrator was sourced, instantiated, or fit.
- Unrelated dirty Phase 10/11 benchmark and output paths remain untouched and unstaged; code cleanliness is checked on the production R surface.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The sandbox initially blocked Git index-lock creation. The required normal staged commits were completed with repository-write escalation, including hooks; no additional files were staged.

## Known Stubs

None in the files created or modified by this plan.

## User Setup Required

None - no external service configuration required.

## Verification Results

- Focused freeze suite after Task 1: passed.
- Tracer fresh-process freeze validation after Task 1: passed.
- Exact Task 2 command (`test_phase12_freeze.R` plus `test_benchmark_promotion.R`): passed; 169 inherited promotion assertions passed.
- Final fresh-process `validate_phase12_freeze_manifest()` read-back: passed.
- Artifact acceptance checks: nine unique candidates, `G=40`, sealed-before-label, network-free, and clean code flags all passed.
- No label-bearing source was accessed, inspected, created, or written; no final model or holdout evaluation was run.

## Next Phase Readiness

Plan 02 can proceed only by validating this exact freeze and recipe identity before any calibration fit. The sealed holdout remains unopened.

---
*Phase: 12-calibration-promotion-and-model-release*
*Plan: 01*
*Completed: 2026-08-11*

## Self-Check: PASSED

- All four owned implementation/artifact/test files and this SUMMARY.md exist.
- Task commits `dc2b725` and `8cb9fe4` are present in Git history.
- Focused, inherited promotion, fresh-process, and artifact acceptance checks passed.
