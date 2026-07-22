---
phase: 10
slug: statistical-goal-model-challengers
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-07-22
---

# Phase 10 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `testthat` 3.3.2 |
| **Config file** | `tests/testthat.R`, `tests/testthat/helper_benchmark.R`; Wave 0 adds `tests/testthat/helper_statistical_challengers.R` |
| **Quick run command** | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_benchmark_baselines.R", reporter="summary", stop_on_failure=TRUE, stop_on_warning=TRUE)'` |
| **Full suite command** | `Rscript --vanilla -e 'testthat::test_dir("tests/testthat", reporter="summary", stop_on_failure=TRUE, stop_on_warning=TRUE)'` |
| **Estimated runtime** | Quick regression about 8 seconds; full benchmark gate is intentionally deferred to wave and phase boundaries |

---

## Sampling Rate

- **After every task commit:** Run the owning Phase 10 test file plus `test_benchmark_baselines.R`.
- **After every plan wave:** Run all Phase 10 tests plus existing benchmark contract, cutoff, scoring, pipeline, and seal tests.
- **Before `$gsd-verify-work`:** Run the full suite, fresh-process deterministic bundle validation, exact panel/count reconciliation, and Phase 9 parent-hash verification.
- **Max feedback latency:** About 30 seconds for task-level synthetic and contract tests; expensive 12-tournament fits run only at explicit wave or phase gates.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 10-W0-01 | Wave 0 | 0 | STAT-01 | T-10-01 | Prior-only penalty tuning and complete cold-start fixture retention | unit + integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_statistical_penalized_poisson.R", reporter="summary", stop_on_failure=TRUE, stop_on_warning=TRUE)'` | ❌ W0 | ⬜ pending |
| 10-W0-02 | Wave 0 | 0 | STAT-02 | T-10-02 | Same-date outcomes cannot affect one another; row-order invariant updates | unit + replay | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_statistical_dynamic_ability.R", reporter="summary", stop_on_failure=TRUE, stop_on_warning=TRUE)'` | ❌ W0 | ⬜ pending |
| 10-W0-03 | Wave 0 | 0 | STAT-03 | T-10-03 | Dependence parameters use prior data only and grids remain valid at `G=40` | unit + integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_statistical_dependence.R", reporter="summary", stop_on_failure=TRUE, stop_on_warning=TRUE)'` | ❌ W0 | ⬜ pending |
| 10-W0-04 | Wave 0 | 0 | STAT-04 | T-10-04 | Ablations use identical panels/fits and identify unavailable predictors explicitly | unit + integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_statistical_ablations.R", reporter="summary", stop_on_failure=TRUE, stop_on_warning=TRUE)'` | ❌ W0 | ⬜ pending |
| 10-W0-05 | Wave 0 | 0 | STAT-01..04 | T-10-01..04 | Locked Phase 9 parent, no WC2026 access, no Phase 10 promotion | end-to-end contract | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_statistical_challenger_pipeline.R", reporter="summary", stop_on_failure=TRUE, stop_on_warning=TRUE)'` | ❌ W0 | ⬜ pending |

The planner replaces Wave 0 placeholder IDs with concrete plan/task IDs without weakening the mapped assertions.

---

## Required Assertions

- Shuffle same-day rows and require byte-identical dynamic states and predictions.
- Poison each assessment tournament's outcomes and require frozen predictions, selected hyperparameters, and dependence parameters to remain unchanged.
- Require identical mean-prediction hashes across independent, Dixon-Coles, and bivariate-Poisson variants.
- Require candidate/baseline fixture-ID equality: 630 fixtures for each open baseline and 609 for `production_hybrid_nb`.
- Run twice in fresh R sessions and compare registry, manifest, prediction, score, evidence, comparison, and shortlist hashes.
- Assert statically and dynamically that Phase 10 does not call `evaluate_promotion()` or read 2026 World Cup outcomes.
- Validate finite nonnegative cells, unit mass, complete `0:40` support, and common market derivation for every score distribution.
- Preserve zero-coded xG/form formula columns while marking them inactive because point-in-time coverage is zero, not because observed values are zero.

---

## Wave 0 Requirements

- [ ] `tests/testthat/helper_statistical_challengers.R` - synthetic matches, fixed sparse levels, PMF oracle fixtures, and fold helpers.
- [ ] `tests/testthat/test_statistical_penalized_poisson.R` - STAT-01 tests.
- [ ] `tests/testthat/test_statistical_dynamic_ability.R` - STAT-02 tests.
- [ ] `tests/testthat/test_statistical_dependence.R` - STAT-03 tests.
- [ ] `tests/testthat/test_statistical_ablations.R` - STAT-04 tests.
- [ ] `tests/testthat/test_statistical_challenger_pipeline.R` - cross-requirement bundle and chronology contract.
- [ ] Install and verify `glmnet` 5.0, then record it in targets package declarations and manifests.
- [ ] Measure one candidate score partition and lock the disk preflight threshold before the full benchmark run.

---

## Manual-Only Verifications

All phase behaviors have automated verification. Human review is limited to interpreting the resulting research shortlist; it is not a substitute for a test gate.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verification or Wave 0 dependencies.
- [ ] Sampling continuity: no three consecutive tasks without automated verification.
- [ ] Wave 0 covers all missing references.
- [ ] No watch-mode flags.
- [ ] Task-level feedback latency remains below 30 seconds.
- [x] `nyquist_compliant: true` set in frontmatter.

**Approval:** pending plan-checker verification
