---
phase: 10-statistical-goal-model-challengers
plan: "10"
subsystem: testing
tags: [r, testthat, red-contracts, chronology, score-dependence, g40]

requires:
  - phase: 09-rolling-tournament-benchmark-harness
    provides: Complete G=40 score-distribution and common-market validators
  - phase: 10-statistical-goal-model-challengers
    provides: Locked D-05 through D-10 design decisions and future production API ownership
provides:
  - Task-scoped RED contracts for deterministic dynamic matchday state and prior-only tuning
  - Task-scoped RED contracts for shared-mean dependence PMFs and fold-global prior parameters
  - Explicit RED-only verification that separates absent production APIs from scaffold failures
affects: [10-04, 10-05, STAT-02, STAT-03]

tech-stack:
  added: []
  patterns: [self-contained-wave0-contracts, aborting-missing-api-gates, sibling-task-api-separation, inherited-g40-validation]

key-files:
  created:
    - tests/testthat/test_statistical_dynamic_state.R
    - tests/testthat/test_statistical_dynamic_tuning.R
    - tests/testthat/test_statistical_dependence_pmf.R
    - tests/testthat/test_statistical_dependence_parameters.R
  modified: []

key-decisions:
  - "Make each Wave 0 API gate abort its current test with one explicit missing-production-API message so RED evidence cannot be confused with scaffold errors."
  - "Keep dynamic-state and dependence-PMF contracts independent of their sibling task's later tuning, fold-parameter, and manifest APIs."
  - "Use the inherited benchmark distribution and market validators for every complete 0:40 dependence grid rather than introducing test-local market semantics."

patterns-established:
  - "Wave 0 RED classification: parse first, then inspect silent testthat results and require every expectation message to be an explicit missing-API gate."
  - "Ownership separation: earlier production-task suites contain no calls to APIs introduced by later sibling tasks."

requirements-completed: [STAT-02, STAT-03]

coverage:
  - id: D1
    description: Dynamic-state and dynamic-tuning RED contracts fix deterministic date batching, scored/conceded updates, all-history mean reversion, inactive historical xG/form evidence, prior-only hyperparameters, and nested Elo behavior.
    requirement: STAT-02
    verification:
      - kind: unit
        ref: tests/testthat/test_statistical_dynamic_state.R and test_statistical_dynamic_tuning.R parse plus RED-only missing-API classification
        status: pass
    human_judgment: false
  - id: D2
    description: Dependence-PMF and dependence-parameter RED contracts fix analytical low cells, bivariate marginals, exact shared means, G=40 validation, fold-global prior fitting, track reuse, poisoning resistance, and manifest evidence.
    requirement: STAT-03
    verification:
      - kind: unit
        ref: tests/testthat/test_statistical_dependence_pmf.R and test_statistical_dependence_parameters.R parse plus RED-only missing-API classification
        status: pass
    human_judgment: false

duration: 7 min
completed: 2026-07-22
status: complete
---

# Phase 10 Plan 10: Dynamic and Score-Dependence RED Contracts Summary

**Four self-contained testthat suites now lock D-05 through D-10 chronology, shared-mean mathematics, fold-global tuning, and complete G=40 distributions while failing only on their owning future production APIs.**

## Performance

- **Duration:** 7 min
- **Started:** 2026-07-22T13:02:39Z
- **Completed:** 2026-07-22T13:09:31Z
- **Tasks:** 1
- **Files modified:** 4

## Accomplishments

- Added dynamic-state contracts for immutable pre-date snapshots, same-day row-order invariance, scored/conceded weighted updates, strictly later result effects, all-history decay, continuous global-mean reversion, cycle-label invariance, and inactive historical xG/form evidence.
- Added dynamic-tuning contracts for the standalone/Elo nested pair, prior-only pseudo-exposure selection, stronger-shrinkage tie-breaking, track-shared settings, outer-label poisoning resistance, canonical Elo provenance, and auditable manifests.
- Added dependence-PMF contracts for exact shared-mean hashes, analytical Dixon-Coles cells, bivariate-Poisson oracles and marginals, independence limits, finite nonnegative unit-mass 0:40 grids, and common inherited market derivation.
- Added dependence-parameter contracts for exactly one bounded prior-fit parameter per outer-fold/family, no track-specific duplication, chronology checks, shared hashes, poisoning/order invariance, and complete no-fallback manifests.

## Task Commits

Each task was committed atomically:

1. **Task 1: Scaffold dynamic-state and score-dependence contract tests** - `d58fd17` (test)

## Files Created/Modified

- `tests/testthat/test_statistical_dynamic_state.R` - Plan 10-04 Task 1 date-batch, update, decay, reversion, replay, and inactive-evidence RED contracts.
- `tests/testthat/test_statistical_dynamic_tuning.R` - Plan 10-04 Task 2 prior-only hyperparameter, nested-Elo, poisoning, provenance, and manifest RED contracts.
- `tests/testthat/test_statistical_dependence_pmf.R` - Plan 10-05 Task 1 shared-mean, independent/DC/BP oracle, marginal, market, and G=40 RED contracts.
- `tests/testthat/test_statistical_dependence_parameters.R` - Plan 10-05 Task 2 fold-global parameter, chronology, reuse, poisoning, and manifest RED contracts.

## Decisions Made

- Used self-contained synthetic fixtures and oracles instead of requiring the same-wave statistical helper, so the four files parse independently and their RED state has one cause.
- Made missing API gates abort immediately with the complete owning symbol list; silent-result verification can therefore prove there are no parse, fixture, dependency, or post-gate function-call errors.
- Kept Task 1 state/PMF files free of Task 2 tuning/parameter/manifest symbols while allowing later Task 2 suites to build on their earlier sibling APIs.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected an under-escaped R regex in the PMF contract**
- **Found during:** Task 1 parse verification
- **Issue:** The first parse gate rejected an escaped bracket in the expected-error pattern before any production API could be evaluated.
- **Fix:** Doubled the regex escapes so R parses the pattern and the intended q-domain assertion remains intact.
- **Files modified:** `tests/testthat/test_statistical_dependence_pmf.R`
- **Verification:** All four files parse successfully in one fresh `Rscript --vanilla` process.
- **Committed in:** `d58fd17`

**2. [Rule 1 - Bug] Stopped API gates from producing secondary missing-function noise**
- **Found during:** Task 1 focused RED verification
- **Issue:** `testthat::fail()` records a failure but continues the test body, so absent APIs produced additional raw function-not-found errors that obscured scaffold quality.
- **Fix:** Changed each gate to abort the current test immediately with `Wave 0 RED contract awaits: ...` and the complete owning API list.
- **Files modified:** All four task test files.
- **Verification:** Silent `testthat` result inspection confirms all 21 current expectations match the explicit missing-production-API prefix and no other error class/message occurs.
- **Committed in:** `d58fd17`

---

**Total deviations:** 2 auto-fixed bugs.
**Impact on plan:** Both fixes strengthen the required distinction between expected RED production gaps and scaffold errors; behavior scope and production ownership did not expand.

## Issues Encountered

- The sandbox initially denied creation of `.git/index.lock`; the same explicit four-file staging and normal hooked commit succeeded with repository write approval.

## Verification

- Exact plan parse command over all four files: passed in a fresh `Rscript --vanilla` process.
- Focused RED suites: intentionally non-green; silent-result classification passed with 5 dynamic-state, 5 dynamic-tuning, 6 dependence-PMF, and 5 dependence-parameter expectations, all failing only with `Wave 0 RED contract awaits:` and the owning absent symbols.
- Ownership checks: dynamic-state contains no Task 2 tuning/Elo/manifest API calls; dependence-PMF contains no Task 2 fold-parameter/shared-hash-validator/manifest API calls.
- Distribution checks: PMF contracts require support `0:40`, 1,681 cells, finite nonnegative unit mass, `validate_benchmark_score_distributions()`, and `derive_benchmark_markets()`.
- `git diff --check`: passed before commit.
- No model implementation, model fit, target execution, or benchmark run occurred.

## User Setup Required

None - no external service configuration required.

## Known Stubs

None. The absent dynamic/dependence production APIs are the intentional RED boundary owned by Plans 10-04 and 10-05, not unfinished work in this scaffold plan. Empty synthetic `elo_diff__imputation_reason` values represent canonically observed, non-imputed evidence.

## Next Phase Readiness

- Plan 10-04 can implement Task 1 state APIs against `test_statistical_dynamic_state.R`, then add Task 2 tuning/Elo/manifest APIs against the separate tuning suite.
- Plan 10-05 can implement pure PMF/hash APIs against `test_statistical_dependence_pmf.R`, then add prior-fold parameter and manifest APIs against the separate parameter suite.
- No production model behavior or historical benchmark output was generated ahead of those owning plans.

## Self-Check: PASSED

- Verified all four task files and this summary exist on disk.
- Verified task commit `d58fd17` exists and contains exactly the four planned RED test files.
- Verified summary coverage metadata classifies both deliverables as fully automated with no schema errors.
- Verified there were no task-commit deletions and all unrelated working-tree changes remain unstaged.

---
*Phase: 10-statistical-goal-model-challengers*
*Completed: 2026-07-22*
