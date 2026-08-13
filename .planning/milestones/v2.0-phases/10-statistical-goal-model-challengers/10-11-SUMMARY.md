---
phase: 10-statistical-goal-model-challengers
plan: "11"
subsystem: testing
tags: [r, testthat, red-contracts, coverage, publication, targets]

requires:
  - phase: 09-rolling-tournament-benchmark-harness
    provides: Frozen five-baseline bundle, exact 630/609 panels, shared scoring, hashes, and atomic publication patterns
  - phase: 10-statistical-goal-model-challengers
    provides: Wave 0 synthetic helper plus locked D-11 through D-16 ownership and validation contracts
provides:
  - Task-scoped RED contracts for ablation hierarchy, seven-candidate adapters, practical non-inferiority, and three-slot selection
  - Synthetic publication and exact six-target DAG contracts with promotion/WC2026 boundaries
  - Fail-closed 80-percent per-file core coverage runner and header-only instrumentation exception registry
affects: [10-06, 10-07, 10-08, STAT-01, STAT-02, STAT-03, STAT-04]

tech-stack:
  added: []
  patterns: [task-owned-red-gates, synthetic-publication-contracts, exact-target-manifest, per-file-covr-gate, reproduced-whole-file-exceptions]

key-files:
  created:
    - tests/testthat/test_statistical_ablation_hierarchy.R
    - tests/testthat/test_statistical_adapter_dispatch.R
    - tests/testthat/test_statistical_ablation_selection.R
    - tests/testthat/test_statistical_selection.R
    - tests/testthat/test_statistical_bundle.R
    - tests/testthat/test_statistical_targets.R
    - tests/testthat/phase10_core_coverage.R
    - tests/testthat/phase10_coverage_exceptions.csv
  modified: []

key-decisions:
  - "Keep each RED file gated only by the production APIs owned by its downstream task, so sibling tasks can turn GREEN independently."
  - "Represent publication reproducibility with a synthetic normal/reversed execution engine and reserve historical benchmark execution for the explicit Phase 10 gate."
  - "Permit coverage exceptions only for currently reproducible whole-file covr instrumentation failures bound to the exact source, command, error hash, evidence file, and reviewer note."

patterns-established:
  - "Task-scoped RED ownership: hierarchy, dispatch, non-inferiority, selection, bundle, and targets each abort before touching later sibling APIs."
  - "Coverage is measured independently per core source file against its complete owning focused suite; aggregate coverage cannot hide a weak file."

requirements-completed: [STAT-01, STAT-02, STAT-03, STAT-04]

coverage:
  - id: D1
    description: Six independently owned RED suites preserve the exact ablation, adapter, selection, bundle, target, panel, shortlist, and sealed-holdout boundaries.
    requirement: STAT-04
    verification:
      - kind: unit
        ref: tests/testthat/test_statistical_*.R parse and 20-result missing-production-API classification
        status: pass
    human_judgment: false
  - id: D2
    description: Per-file Phase 10 covr enforcement covers all five core modelling files at a fixed 80-percent threshold with fail-closed evidence-only exceptions.
    requirement: STAT-01
    verification:
      - kind: unit
        ref: tests/testthat/phase10_core_coverage.R source/spec/schema/valid-and-invalid exception checks
        status: pass
    human_judgment: false
  - id: D3
    description: Synthetic publication and target contracts preserve exact 630/609 denominators, seven candidates, five baselines, six target names, and promotion/WC2026 isolation without running the benchmark.
    requirement: STAT-03
    verification:
      - kind: integration
        ref: static acceptance checks across test_statistical_selection.R, test_statistical_bundle.R, and test_statistical_targets.R
        status: pass
    human_judgment: false

duration: 9 min
completed: 2026-07-22
status: complete
---

# Phase 10 Plan 11: Statistical Handoff and Coverage RED Contracts Summary

**Eight Wave 0 artifacts now lock the complete D-11 through D-16 handoff, publication, targets, and per-file coverage boundary while failing only on downstream production APIs.**

## Performance

- **Duration:** 9 min
- **Started:** 2026-07-22T13:14:02Z
- **Completed:** 2026-07-22T13:23:08Z
- **Tasks:** 1
- **Files modified:** 8

## Accomplishments

- Partitioned hierarchical ablation, seven-candidate adapter dispatch, practical non-inferiority, all-five-baseline selection, bundle publication, and targets contracts by downstream owning task.
- Preserved the exact seven candidates, five Phase 9 baselines, 12-edition evidence, 630 open/609 rich panels, three ordered non-exclusive shortlist slots, complete parent hashes, G=40, and no-promotion/WC2026 boundaries.
- Added a fixed 80% per-file `covr` runner over five core modelling files and a header-only registry that rejects test-, function-, branch-, percentage-, runtime-, stale-, and unmatched exceptions.
- Confirmed all 20 focused RED results abort only with explicit missing-production-API diagnostics; no model fitting or benchmark execution occurred.

## Task Commits

Each task was committed atomically:

1. **Task 1: Scaffold ablation, adapter, selection, publication, targets, and coverage tests** - `7b1d32e` (test)

## Files Created/Modified

- `tests/testthat/test_statistical_ablation_hierarchy.R` - Plan 10-06 Task 1 common-fitter, zero-coverage provenance, and non-activated child contracts.
- `tests/testthat/test_statistical_adapter_dispatch.R` - Plan 10-06 Task 2 exact seven-ID allowlist, inherited adapter shape, validator, and shared-mean contracts.
- `tests/testthat/test_statistical_ablation_selection.R` - Plan 10-06 Task 3 +0.001 practical non-inferiority, supporting veto, and no-significance contracts.
- `tests/testthat/test_statistical_selection.R` - Plan 10-07 Task 1 all-five-baseline 630/609 pairing, dependence representative, and research shortlist contracts.
- `tests/testthat/test_statistical_bundle.R` - Plan 10-07 Task 2 exact output graph, Phase 9 parent reconstruction, synthetic reproducibility, and sealed-boundary contracts.
- `tests/testthat/test_statistical_targets.R` - Plan 10-07 Task 3 exact six-node manifest, dependency order, forbidden ancestry, and no-execution contracts.
- `tests/testthat/phase10_core_coverage.R` - Per-file instrumentation, 80% enforcement, focused ownership map, and reproducible exception validation.
- `tests/testthat/phase10_coverage_exceptions.csv` - Empty exception registry with the exact seven-column evidence schema.

## Decisions Made

- Kept every file independently runnable after its owner turns GREEN: hierarchy does not call dispatch or non-inferiority APIs, dispatch does not call selection, selection does not call publication, and bundle does not require targets.
- Used exact IDs and frozen denominators directly in the contracts rather than discovering them from mutable output coverage.
- Required coverage exceptions to reproduce the same instrumentation error during the current run; a successful rerun makes a registry row stale and fails the gate.
- Kept full historical execution out of Wave 0. Bundle behavior uses a synthetic engine, and target tests inspect the manifest without calling `tar_make()`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Made every missing-API gate abort its current test**
- **Found during:** Task 1 focused RED verification
- **Issue:** Initial `testthat::fail()` gates recorded the expected RED result but continued into downstream calls, producing secondary function-not-found errors and incidental fitter warnings.
- **Fix:** Replaced each gate with an immediate `stop(..., call. = FALSE)` using the complete owning API list.
- **Files modified:** All six RED test files.
- **Verification:** All 20 focused results now stop only at `Wave 0 RED contract awaits:` with no scaffold, fixture, parse, or post-gate errors.
- **Committed in:** `7b1d32e`

---

**Total deviations:** 1 auto-fixed bug.
**Impact on plan:** The fix enforces the required RED diagnostic boundary without adding production behavior or expanding scope.

## Issues Encountered

- The sandbox initially denied creation of `.git/index.lock`; the same explicit eight-file staging and normal hooked commit succeeded with repository write approval.

## Verification

- Exact plan parse/schema command: passed for all seven R files; the exception CSV has the exact ordered columns and zero rows.
- Coverage contract checks: passed for the five-file ownership map, fixed threshold, valid reproduced whole-file exception, and rejection of percentage/runtime/test/function/unmatched exception categories.
- Focused RED diagnostics: 3 hierarchy, 3 adapter, 3 non-inferiority, 3 selection, 5 bundle, and 3 target results; all 20 fail only on their explicit downstream API gates.
- Static acceptance checks: exact seven candidates, five baselines, six targets, 630/609 denominators, G=40, and sibling-API separation passed.
- `git diff --check`: passed before commit; normal repository hooks passed on `7b1d32e`.
- No model implementation, model fit, target execution, historical benchmark run, or Phase 9 mutation occurred.

## User Setup Required

None - no external service configuration required.

## Known Stubs

None. The missing production APIs and target nodes are the intentional RED boundary owned by Plans 10-06 and 10-07, not incomplete implementation in this scaffold plan. The exception registry is intentionally header-only and fail-closed.

## Next Phase Readiness

- Plan 10-06 can turn hierarchy, dispatch, and non-inferiority suites GREEN one task at a time without later sibling APIs.
- Plan 10-07 can independently turn selection, publication, and targets suites GREEN while preserving the Phase 12 promotion boundary.
- Plan 10-08 remains the sole owner of the expensive 12-tournament normal/reversed benchmark gate.

## Self-Check: PASSED

- Verified all eight task artifacts and this summary exist on disk.
- Verified task commit `7b1d32e` exists and contains exactly the eight planned Wave 0 files.
- Verified summary coverage metadata classifies all three deliverables as fully automated with no schema errors.
- Verified the task commit contains no deletions and all preserved unrelated working-tree changes remain unstaged.

---
*Phase: 10-statistical-goal-model-challengers*
*Completed: 2026-07-22*
