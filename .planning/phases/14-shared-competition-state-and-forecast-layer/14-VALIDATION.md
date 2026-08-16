---
phase: 14
slug: shared-competition-state-and-forecast-layer
# status lifecycle: draft (seeded by plan-phase) -> validated (set by validate-phase section 6)
# audit-milestone section 5.5 distinguishes NOT-VALIDATED from PARTIAL.
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-16
---

# Phase 14 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.3.2 |
| **Config file** | `tests/testthat.R` |
| **Quick run command** | `Rscript --vanilla -e 'testthat::test_dir("tests/testthat", filter = "phase14")'` |
| **Full suite command** | `Rscript --vanilla -e 'testthat::test_dir("tests/testthat")'` |
| **Estimated runtime** | Quick suite target: under 90 seconds; full suite measured during execution |

---

## Sampling Rate

- **After every task commit:** Run the focused Phase 14 test file(s) named by the task.
- **After every plan wave:** Run `Rscript --vanilla -e 'testthat::test_dir("tests/testthat", filter = "phase14")'`.
- **Before `/gsd:verify-work`:** The full suite must be green, or unrelated pre-existing failures must be documented with unchanged evidence.
- **Max feedback latency:** 90 seconds for the focused Phase 14 suite.

---

## Per-Task Verification Map

The planner must replace `TBD` plan/task identifiers after final decomposition. No requirement may lose its named automated command.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD | TBD | 0 | STATE-01 | T-14-STATE-INTEGRITY | Aggregate mismatches block promotion; rank-only mismatches warn | unit/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_standings.R")'` | No - W0 | pending |
| TBD | TBD | 0 | STATE-02 | T-14-STATE-SPOOF | Lifecycle, completion method, and score axes reject invalid combinations | unit/property matrix | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_match_state.R")'` | No - W0 | pending |
| TBD | TBD | 0 | STATE-03 | T-14-CUTOFF | Exclusive cutoffs and separate form windows prevent future-result leakage | unit/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_form.R")'` | No - W0 | pending |
| TBD | TBD | 0 | STATE-04 | T-14-CROSS-EDITION | Undeclared cross-edition joins fail and edition-local failures remain isolated | integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_state_bundle.R")'` | No - W0 | pending |
| TBD | TBD | 0 | FORECAST-01 | T-14-RELEASE-SPOOF | Raw fallback suppresses forecasts; fitted release and dual pins pass exact hash checks | integration/security | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_calibration_release.R")'` | No - W0 | pending |
| TBD | TBD | 0 | FORECAST-02 | T-14-RESOURCE-BOUND | Fixed G=40 grid, independent simplices, top-10 mass, and uncertainty remain bounded | unit/integration/performance | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_forecast_layer.R")'` | No - W0 | pending |
| TBD | TBD | 0 | FORECAST-03 | T-14-CUTOFF | Equal/after-kickoff and same-day date-only evidence are rejected with replayable lineage | adversarial/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_cutoffs.R")'` | No - W0 | pending |

*Status values: pending, green, red, flaky.*

---

## Wave 0 Requirements

- [ ] `tests/fixtures/phase14/` - compact lifecycle, reconciliation, cutoff, cross-edition, raw-release, calibrated-release, and G=40 fixtures.
- [ ] `tests/testthat/test_phase14_match_state.R` - STATE-02 lifecycle and score matrix.
- [ ] `tests/testthat/test_phase14_standings.R` - STATE-01 replay/reconciliation contract.
- [ ] `tests/testthat/test_phase14_form.R` - STATE-03 display and model form windows.
- [ ] `tests/testthat/test_phase14_cutoffs.R` - FORECAST-03 adversarial point-in-time boundaries.
- [ ] `tests/testthat/test_phase14_calibration_release.R` - FORECAST-01 release suppression, approval, and dual-pin transaction.
- [ ] `tests/testthat/test_phase14_forecast_layer.R` - FORECAST-02 G=40, calibrated 1X2, uncertainty, and performance.
- [ ] `tests/testthat/test_phase14_state_bundle.R` - STATE-04 shared-input allowlist, edition isolation, and replay.

---

## Manual-Only Verifications

All Phase 14 backend behaviors have automated verification. Empirical calibrator promotion remains an explicit execution checkpoint: a failed promotion gate must retain `release_not_calibrated` suppression and must not be overridden by weakening thresholds.

---

## Validation Sign-Off

- [ ] All tasks have automated verification or Wave 0 dependencies.
- [ ] Sampling continuity: no three consecutive tasks without automated verification.
- [ ] Wave 0 covers every missing test reference.
- [ ] No watch-mode flags.
- [ ] Focused feedback latency is below 90 seconds.
- [ ] Plan/task identifiers replace all `TBD` entries.
- [ ] `nyquist_compliant: true` is set in frontmatter after validation.

**Approval:** pending
