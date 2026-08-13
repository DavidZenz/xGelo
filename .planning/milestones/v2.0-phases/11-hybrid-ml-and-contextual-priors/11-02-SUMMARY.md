---
phase: 11-hybrid-ml-and-contextual-priors
plan: 02
subsystem: benchmark
tags: [R, ranger, random-forest, negative-binomial, feature-provenance, scoring]

# Dependency graph
requires:
  - phase: 11-01
    provides: Wave 0 hybrid contracts, sealed panel constants, and RED test fixtures
  - phase: 11-07
    provides: verified project-local ranger 0.18.0 runtime and offline provenance record
provides:
  - research-only open RF candidate with independent home/away goal forests
  - registry, feature-contract, tuning-grid, settings-hash, and ranger-provenance validation
  - common NB G=40 score distributions, market reconciliation, feature coverage, and scoring runner
affects: [11-03-context-ablation, 11-04-xg-gate, 11-05-structural-prior, 11-06-manual-market, hybrid-benchmark]

# Tech tracking
tech-stack:
  added: [ranger 0.18.0 project-local replay usage]
  patterns: [two-goal RF means, registered one-row tuning grid, fixed-support NB adapter, fail-closed evidence]

key-files:
  created:
    - R/benchmark/hybrid_protocol.R
    - R/forecast/hybrid_rf.R
    - R/benchmark/hybrid_adapters.R
    - R/benchmark/hybrid_runner.R
    - data/benchmark/phase11/model_registry.csv
    - data/benchmark/phase11/feature_contract.csv
  modified:
    - tests/testthat/test_hybrid_random_forest.R

key-decisions:
  - "Keep one open_core RF candidate research-only, WC2026 sealed, and fixed at 630/609 fixtures with G=40."
  - "Fit separate home- and away-goal ranger forests; derive all 1X2 and auxiliary markets from independent NB marginals."
  - "Freeze one deterministic 64-tree, mtry-3, min-node-size-1 grid and reject runtime settings outside its registration."
  - "Require the verified local ranger 0.18.0 environment before fit, prediction, or benchmark execution; never fall back to randomForest."

patterns-established:
  - "Every RF feature carries source/value/imputation companions and must pass a strict pre-cutoff chronology check."
  - "Registry, settings, tuning-grid, manifest, and feature-coverage hashes form the execution identity across folds/tracks."
  - "Optional or missing scoring data fails closed with an explicit error; no silent imputation or activation occurs."

requirements-completed: [HYBRID-01]

coverage:
  - id: D1
    description: "Open RF tracer traverses registry, fold-local evidence, ranger fit/predict, NB G=40 distributions, market reconciliation, feature coverage, and the common score service."
    requirement: HYBRID-01
    verification:
      - kind: integration
        ref: "tests/testthat/test_hybrid_random_forest.R#HYBRID-01 / D-04 runs the RF through the common score service"
        status: pass
      - kind: unit
        ref: "Rscript -e 'testthat::test_file(\"tests/testthat/test_hybrid_random_forest.R\", stop_on_failure = TRUE, stop_on_warning = TRUE)'"
        status: pass
    human_judgment: false
  - id: D2
    description: "Registered RF tuning and ranger provenance are deterministic, hashed, persisted, and fail closed on unregistered settings or runtime drift."
    requirement: HYBRID-01
    verification:
      - kind: unit
        ref: "tests/testthat/test_hybrid_random_forest.R#HYBRID-01 / D-04 freezes the registered RF tuning grid and provenance"
        status: pass
      - kind: other
        ref: "Rscript -e 'source(\"R/benchmark/hybrid_protocol.R\"); validate_phase11_rf_tuning_grid(canonical_phase11_rf_tuning_grid())'"
        status: pass
    human_judgment: false

# Metrics
duration: 25min
completed: 2026-08-08
status: complete
---

# Phase 11 Plan 02 Summary

**Research-only open RF challenger using verified ranger 0.18.0, fold-local dynamic/Elo features, and sealed G=40 NB score distributions**

## Performance

- **Duration:** 24m 57s
- **Started:** 2026-08-08T18:21:54Z
- **Completed:** 2026-08-08T18:46:51Z
- **Tasks:** 2/2
- **Files modified:** 7 plan-owned implementation, contract, registry, and test files

## Accomplishments

- Added the first production-quality Phase 11 RF slice: one registered `open_core` candidate with independent home/away goal forests, strict dynamic ability plus Elo evidence, and no direct 1X2 classifier.
- Routed predictions through the shared negative-binomial adapter at exactly `G=40`, reconciled all markets from the 1681-cell grids, generated model manifests and feature coverage, and scored the deterministic fixture slice through `score_benchmark_fixtures()`.
- Added a canonical one-row tuning grid (`num.trees=64`, `mtry=3`, `min.node.size=1`), stable settings/grid/registration hashes, shared fold identity, and ranger 0.18.0 package/provenance fields.
- Preserved the fixed `630/609/G=40`, research-only, WC2026-sealed, network-free, and optional-data fail-closed contracts.

## Task Commits

Each task was committed atomically with TDD RED/GREEN gates:

1. **Task 1: RF tracer, registry, adapters, and runner**
   - `fd026f0` - `test(11-02): add RF tracer registry and runner contracts`
   - `6f77698` - `feat(11-02): implement open RF challenger tracer`
2. **Task 2: RF fold tuning and deterministic package provenance**
   - `0a8abc9` - `test(11-02): add RF tuning grid provenance contract`
   - `d0956b6` - `feat(11-02): freeze RF tuning and ranger provenance`

The final documentation commit for this summary is recorded after the self-check below.

## Verification

- RF plan verification: 65 passing assertions, 0 failures, 0 warnings, 0 skips.
- Tracer feedback gate after the Task 1 commit: 51 passing assertions, 0 failures, 0 warnings, 0 skips.
- Shared benchmark regression checks: `test_benchmark_contracts.R` (62 pass), `test_benchmark_scoring.R` (47 pass), and `test_benchmark_registry.R` (28 pass).
- Canonical Phase 11 model registry and feature contract were written and immediately reloaded through their validators.
- The ranger preflight verified the exact project-local 0.18.0 installation and offline provenance before RF execution.

## Files Created/Modified

- `R/benchmark/hybrid_protocol.R` - Canonical RF registration, feature contract, tuning grid, hashes, sealed-boundary validators, and CSV writer.
- `R/forecast/hybrid_rf.R` - Evidence-validated independent ranger fits, predictions, registered settings, and NB score distributions.
- `R/benchmark/hybrid_adapters.R` - Strict candidate allowlist, fixture/seed normalization, manifests, feature coverage, and common prediction validation.
- `R/benchmark/hybrid_runner.R` - Research-only end-to-end execution and common proper-score integration with explicit run protection flags.
- `data/benchmark/phase11/model_registry.csv` - Sealed open RF candidate and immutable runtime/settings identities.
- `data/benchmark/phase11/feature_contract.csv` - Dynamic attack/defence plus Elo feature provenance contract.
- `tests/testthat/test_hybrid_random_forest.R` - RF tracer, score-service, and deterministic tuning/provenance contracts.

## Decisions Made

- The RF remains a challenger only: no promotion, publication, or access to sealed WC2026 outcomes is exposed by this runner.
- Both forests use the same registered tuning identity; deterministic seed offsets distinguish home and away fits while preserving the shared fold contract.
- NB dispersion is a registered fixed setting (`theta=8` for both margins), and all score support remains exactly 0:40.
- Missing or imputed producer evidence is rejected rather than converted into an apparently active RF feature.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Accepted the empty default settings list used by the runner**
- **Found during:** Task 1 tracer verification
- **Issue:** The settings validator treated the valid default `list()` as an unnamed settings error before the registered defaults could be resolved.
- **Fix:** Permit an empty settings list while continuing to require names for every explicit override; all explicit unregistered overrides remain rejected.
- **Files modified:** `R/forecast/hybrid_rf.R`
- **Verification:** The RF suite passed before and after the committed tracer feedback gate.
- **Committed in:** `6f77698`

**Total deviations:** 1 auto-fixed Rule 1 bug.

**Impact on plan:** The fix was local to the requested RF settings path and did not change the registered tuning or sealed-boundary contracts.

## Issues Encountered

None blocking. The verified ranger runtime was available locally and all requested automated checks completed successfully.

## Auth Gates

None.

## User Setup Required

None - no external service configuration required.

## Known Stubs

None found in plan-created or plan-modified files. No skipped tests, placeholder implementations, or unrun verification commands remain.

## Next Phase Readiness

The RF adapter, protocol hashes, feature evidence, manifests, and runner are ready for sibling Phase 11 candidate extensions. Future candidates should append to the registry/contracts and reuse the existing G=40 NB adapter, ranger preflight, and research-only/sealed run-manifest guards.

Shared `.planning/STATE.md` and `.planning/ROADMAP.md` were intentionally not modified; the orchestrator owns those files.

---
*Phase: 11-hybrid-ml-and-contextual-priors*
*Plan: 02*
*Completed: 2026-08-08*

## Self-Check: PASSED

- All seven plan-owned implementation, contract, registry, and test files exist.
- `fd026f0`, `6f77698`, `0a8abc9`, and `d0956b6` are present in git history.
- The summary file exists and shared `.planning/STATE.md` and `.planning/ROADMAP.md` remain unmodified.
