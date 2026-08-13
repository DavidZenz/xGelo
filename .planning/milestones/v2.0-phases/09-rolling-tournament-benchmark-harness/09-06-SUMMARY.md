---
phase: 09-rolling-tournament-benchmark-harness
plan: "06"
subsystem: benchmark-evaluation
tags: [r, tdd, feature-evidence, frozen-panels, provenance, targets]
requires:
  - phase: 09-05
    provides: adapter-emitted pre-imputation feature evidence and deterministic prediction coverage keys
provides:
  - exact 630-fixture open-core and 609-fixture feature-rich evaluation projections
  - durable feature-level evidence validation for all 6,300 audit-visible predictions
  - independently reconciled bundle panels, denominators, comparisons, and canonical input parents
affects: [09-07, 09-08, phase-10, phase-11, benchmark-promotion]
tech-stack:
  added: []
  patterns:
    - retain complete audit artifacts while projecting exact registered fixture sets before evaluation
    - validate adapter evidence both before persistence and after bundle read-back
    - track canonical analytical inputs as content-hashed target dependencies
key-files:
  created: []
  modified:
    - R/benchmark/contracts.R
    - R/evaluation/benchmark_scores.R
    - R/benchmark/runner.R
    - _targets.R
    - tests/testthat/test_benchmark_contracts.R
    - tests/testthat/test_benchmark_scoring.R
    - tests/testthat/test_benchmark_pipeline.R
key-decisions:
  - Keep all 6,300 prediction rows audit-visible while routing every evaluation consumer through the model's registered frozen panel.
  - Treat adapter-emitted feature coverage and post-output panel coverage as separate artifacts with separate validation responsibilities.
  - Hash the canonical hybrid goal-training feature file into the checked benchmark parent graph.
patterns-established:
  - "Audit then project: preserve complete predictions and evidence, then select an exact frozen fixture set before scoring."
  - "Validate twice: reject evidence or denominator drift during construction and independently after durable read-back."
requirements-completed: [BENCH-03, BENCH-04, BENCH-05]
coverage:
  - id: D1
    description: Frozen panel selection and every scoring primitive enforce exact 630-row open-core and 609-row feature-rich fixture sets.
    requirement: BENCH-04
    verification:
      - kind: unit
        ref: tests/testthat/test_benchmark_contracts.R#frozen panel selectors enforce exact declared fixture sets
        status: pass
      - kind: integration
        ref: tests/testthat/test_benchmark_scoring.R#open and rich scoring and calibration retain exact frozen denominators
        status: pass
    human_judgment: false
  - id: D2
    description: Durable bundles preserve exact adapter feature evidence and validate every prediction foreign key and canonical input parent.
    requirement: BENCH-03
    verification:
      - kind: integration
        ref: tests/testthat/test_benchmark_pipeline.R#runner binds feature-level adapter evidence and rejects aggregate substitutes
        status: pass
      - kind: integration
        ref: tests/testthat/test_benchmark_pipeline.R#canonical feature input is a checked parent and parent drift fails
        status: pass
    human_judgment: false
  - id: D3
    description: Bundle read-back rejects rich-panel contamination and denominator drift across scores, summaries, and paired diagnostics.
    requirement: BENCH-05
    verification:
      - kind: integration
        ref: tests/testthat/test_benchmark_pipeline.R#bundle validation rejects rich contamination and denominator drift
        status: pass
      - kind: integration
        ref: tests/testthat/test_benchmark_scoring.R#paired open and rich fold counts preserve all 12 tournaments
        status: pass
    human_judgment: false
metrics:
  duration: 56min
  completed: 2026-07-21
status: complete
---

# Phase 09 Plan 06: Durable Evidence and Frozen Panel Routing Summary

**Adapter-level feature evidence now survives durable publication while exact 630/609 frozen panels govern every score, calibration, comparison, diagnostic, and promotion denominator.**

## Performance

- **Duration:** 56 min, including recovery audit
- **Started:** 2026-07-21T09:33:44Z
- **Completed:** 2026-07-21T10:29:07Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments

- Enforced exact-set prediction selection, scoring, calibration, and paired comparison semantics for 630 open-core and 609 feature-rich fixtures across all 12 editions.
- Preserved feature-level adapter evidence for all 6,300 audit-visible prediction references instead of replacing it with aggregate output coverage.
- Derived run-manifest evidence validity from construction and read-back validators, including canonical hybrid feature-input parent hashes.
- Excluded the 21 rich-ineligible production-hybrid fixtures from every evaluation and promotion input while retaining them in the full prediction audit.

## Task Commits

Each TDD task was committed atomically:

1. **Task 1 RED: Exact frozen-panel regressions** - `cc4647c` (test)
2. **Task 1 GREEN: Exact panel selection and evaluation contracts** - `89a46c3` (feat)
3. **Task 2 RED: Durable evidence routing regressions** - `e13c276` (test)
4. **Task 2 GREEN: Durable evidence and frozen-panel bundle routing** - `0e79951` (feat)

## Files Created/Modified

- `R/benchmark/contracts.R` - Reconstructs expected feature keys, validates durable evidence, and selects exact registered panels.
- `R/evaluation/benchmark_scores.R` - Requires explicit fixture IDs for scoring and fixed-bin calibration.
- `R/benchmark/runner.R` - Binds adapter evidence, separates output coverage, routes panel-exact evaluation, and independently reconciles bundle denominators.
- `_targets.R` - Adds the canonical hybrid feature file as an explicit checked target dependency and bundle parent.
- `tests/testthat/test_benchmark_contracts.R` - Covers missing, duplicate, extra, wrong-panel, incomplete, and feature-link drift.
- `tests/testthat/test_benchmark_scoring.R` - Proves exact 630/609 score, calibration, and 12-fold paired denominators.
- `tests/testthat/test_benchmark_pipeline.R` - Covers durable evidence binding, read-back contamination, denominator tampering, cutoff leakage, and parent drift.

## Decisions Made

- The complete prediction and feature-evidence graph remains the audit artifact; registered panel projection is a separate, explicit evaluation operation.
- Feature evidence validity is derived only from strict feature-key and foreign-key validation. Observed output coverage remains separately named and feeds promotion eligibility.
- The canonical `goal_training_features_hybrid` content hash is part of the benchmark parent graph, so changing the analytical input invalidates bundle read-back.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Prevented evidence at the exclusive cutoff from entering runtime fixtures**
- **Found during:** Task 2 (durable evidence routing)
- **Issue:** Runtime fixture assembly could retain a source row dated exactly at the registered exclusive evidence cutoff.
- **Fix:** Added a contract-driven cutoff pass that converts at-or-after-cutoff evidence to explicit missing/imputed companions before adapter execution.
- **Files modified:** `R/benchmark/runner.R`, `tests/testthat/test_benchmark_pipeline.R`
- **Verification:** `runtime fixture evidence at the exclusive cutoff is imputed` passes in the focused pipeline suite.
- **Committed in:** `0e79951`

---

**Total deviations:** 1 auto-fixed bug.
**Impact on plan:** The fix closes a leakage edge case at the existing trust boundary without changing registered models, G=40, seeds, folds, or panel membership.

## Issues Encountered

- The previous executor stopped with Task 2 implementation uncommitted. Recovery preserved the coherent four-file continuation of `e13c276`, audited it before staging, and reran each focused suite under a 120-second watchdog.
- The prior silent stall was not reproducible. Contracts completed in 0.80s, scoring in 7.28s, and the pipeline suite—the slow segment—completed in 29.36s. Every watchdog exited normally.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plans 09-07 and 09-08 can consume bundle scores, calibration, uncertainty, and promotion inputs with frozen denominators independently verifiable from durable artifacts.
- Phase 10 and 11 challengers inherit exact model-panel routing and cannot redefine the estimand through output availability.
- No blockers remain.

## Self-Check: PASSED

- Verified all seven plan-modified files and `09-06-SUMMARY.md` exist.
- Verified Task commits `cc4647c`, `89a46c3`, `e13c276`, and `0e79951` exist in git history.
- Verified contract, scoring, and pipeline suites pass under explicit 120-second watchdogs.
- Verified coverage metadata classifies all three deliverables as fully automated and passing.
- Verified no tracked files were deleted and no stubs or unregistered threat surface were introduced.

---
*Phase: 09-rolling-tournament-benchmark-harness*
*Completed: 2026-07-21*
