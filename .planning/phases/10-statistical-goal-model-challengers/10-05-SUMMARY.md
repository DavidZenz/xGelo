---
phase: 10-statistical-goal-model-challengers
plan: "05"
subsystem: statistical-forecasting
tags: [poisson, dixon-coles, bivariate-poisson, chronology, deterministic-evidence]
requires:
  - phase: 10-03
    provides: centered prior-tuned penalized-Poisson fixture means
  - phase: 10-09
    provides: sealed chronology and eligible-edition registries
provides:
  - shared-mean independent, Dixon-Coles, and bivariate-Poisson G=40 PMFs
  - prior-only fold-global dependence parameter fitting
  - deterministic shared-mean and dependence evidence manifests
affects: [10-06, 10-07, 10-08, phase-12]
tech-stack:
  added: []
  patterns: [log-space PMFs, bounded scalar optimization, canonical SHA-256 evidence]
key-files:
  created:
    - R/forecast/score_dependence.R
    - .planning/phases/10-statistical-goal-model-challengers/10-05-SUMMARY.md
  modified:
    - tests/testthat/test_statistical_dependence_parameters.R
key-decisions:
  - "Dependence families share one canonical hash over fold, track, boundary, fixture, and penalized-Poisson means; dependence identity is excluded."
  - "Dixon-Coles rho and bivariate-Poisson q are fitted once per outer fold from registry-approved prior editions and never vary by track or fixture."
  - "Assessed rows are filtered out before outcome validation so poisoned future labels cannot affect fitting or manifests."
requirements-completed: [STAT-03]
coverage:
  - dimension: D1
    contract: tests/testthat/test_statistical_dependence_pmf.R and tests/testthat/test_benchmark_contracts.R
    result: pass
  - dimension: D2
    contract: tests/testthat/test_statistical_dependence_parameters.R
    result: pass
  - dimension: human
    result: not-required
duration: 9m32s
completed: 2026-07-22
status: complete
---

# Phase 10 Plan 05: Score-Dependence Corrections Summary

Stable independent, Dixon-Coles, and bivariate-Poisson score grids now share one penalized-Poisson mean structure, with prior-only fold-global parameters and deterministic evidence manifests.

## Accomplishments

- Added normalized long-form score grids on sealed support 0:40, including Dixon-Coles low-score corrections and a log-sum-exp bivariate-Poisson shared component.
- Preserved supplied marginal means across all three dependence families and proved exact independence limits at rho/q zero through the inherited distribution and market contracts.
- Added bounded prior-only rho/q estimation, strict tuning-edition chronology checks, fold-global reuse validation, and poisoning/order-invariant evidence hashes.
- Added manifests containing parameter bounds, objectives, training ranges and hashes, runtime versions, convergence status, and explicit no-fallback status.

## Task Commits

1. **Task 1: Implement stable independent, Dixon-Coles, and bivariate PMFs** — `f3b559b`
2. **Task 2: Estimate one prior-only global dependence parameter per fold** — `e46deed`

## Verification

- `test_statistical_dependence_pmf.R`: PASS — 74 assertions.
- `test_statistical_dependence_parameters.R`: PASS — 26 assertions.
- `test_benchmark_contracts.R`: PASS — 62 assertions.
- `git diff --check`: PASS.
- Final combined gate used `stop_on_failure = TRUE` and `stop_on_warning = TRUE` for all three files.

## TDD Gate Compliance

The existing Wave 0 contract suites were run before implementation and failed on the missing Plan 10-05 APIs. Each task was then implemented against its scoped contract and rerun to GREEN before its atomic feature commit.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Filtered assessed rows before validating fitting outcomes**

- **Found during:** Task 2 parameter-contract verification
- **Issue:** Full-history goal validation inspected deliberately poisoned assessed outcomes before the prior-only chronology filter, violating the leakage-invariance contract.
- **Fix:** Moved support validation to the registry-approved prior training rows returned by chronology validation.
- **Files modified:** `R/forecast/score_dependence.R`
- **Commit:** `e46deed`

**2. [Rule 3 - Blocking] Corrected an impossible table-to-vector assertion**

- **Found during:** Task 2 parameter-contract verification
- **Issue:** The prewritten test compared a `table` object, including array attributes, with a plain named integer vector; identical family counts still failed solely on object attributes.
- **Fix:** Compared the table's integer counts while retaining the preceding exact family-identity assertion.
- **Files modified:** `tests/testthat/test_statistical_dependence_parameters.R`
- **Commit:** `e46deed`

## Known Stubs

None.

## Security and Protocol Review

- Mitigated T-10-14 with exact shared-mean hashing, marginal checks, and hard rejection of sibling hash drift.
- Mitigated T-10-15 with registry-backed prior filtering and assessed-label poisoning tests.
- Mitigated T-10-16 with bounded scalar optimization, log-space calculations, finite checks, and fixed G=40 support.
- No raw Elo reconstruction, Phase 9 protocol changes, World Cup 2026 outcomes, or promotion evaluation were introduced.
- No additional network, authentication, filesystem, schema, or trust-boundary surface was added.

## Self-Check: PASSED

All owned source/test files and this summary exist, and both task commits resolve in Git history.
