---
phase: 12
slug: calibration-promotion-and-model-release
status: revised
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-10
---

# Phase 12 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.x |
| **Config file** | `tests/testthat/` with project-local helpers |
| **Quick run command** | `Rscript --vanilla -e 'files <- list.files("tests/testthat", pattern = "phase12", full.names = TRUE); if (length(files)) for (path in files) testthat::test_file(path, reporter = "summary")'` |
| **Full suite command** | `Rscript --vanilla -e 'testthat::test_dir("tests/testthat", reporter = "summary")'` |
| **Estimated runtime** | Quick: under 90 seconds; full: under 5 minutes |

## Sampling Rate

- **After every task commit:** Run the Phase 12 quick command.
- **After every plan wave:** Run the full `tests/testthat` suite.
- **Before `/gsd:verify-work`:** The full suite and all Phase 12 contract tests must be green.
- **Max feedback latency:** 90 seconds for targeted tests; 5 minutes for the full suite.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 12-00-01 | 00 | 0 | CAL-01, CAL-02, PROMO-01, PROMO-02, PROMO-03 | N/A | The five exact Phase 12 test files parse and remain contract-only before production implementation | scaffold | Wave 0 parse command; `test_phase12_*` exact paths | Yes - W0 | pending |
| 12-00-02 | 00 | 0 | CAL-01, CAL-02, PROMO-01, PROMO-02, PROMO-03 | N/A | Wave 0 uses synthetic/in-memory fixtures and cannot read or create the operator-supplied label artifact | scaffold | Wave 0 ownership command; exact five files | Yes - W0 | pending |
| 12-01-01 | 01 | 1 | PROMO-01 | N/A | Aggregate freeze manifest contains all nine candidates and required parent/code/feature/settings/panel/seed/recipe/threshold hashes | contract | Phase 12 quick command; `test_phase12_freeze.R` | Yes - W0 | pending |
| 12-01-02 | 01 | 1 | PROMO-01 | N/A | Freeze validation fails closed on changed candidates, hashes, settings, panels, seeds, thresholds, or opened WC2026 labels | contract | Phase 12 quick command; `test_phase12_freeze.R` | Yes - W0 | pending |
| 12-02-01 | 02 | 2 | CAL-01 | N/A | Inner OOF rows are strictly prior to the outer assessment and WC2026 labels are rejected | unit/contract | Phase 12 quick command; `test_phase12_calibration.R` | Yes - W0 | pending |
| 12-02-02 | 02 | 2 | CAL-01 | N/A | Candidate/track calibrator records recipe, chronology, support, seed, and source hashes | unit/contract | Phase 12 quick command; `test_phase12_calibration.R` | Yes - W0 | pending |
| 12-03-01 | 03 | 3 | CAL-02 | N/A | Raw and calibrated 1X2 vectors are scored on identical fixtures with identical proper-score functions | integration | Phase 12 quick command; `test_phase12_calibration.R` | Yes - W0 | pending |
| 12-03-02 | 03 | 3 | CAL-02 | N/A | Raw fallback is selected when calibration improvement or any frozen score/stability/coverage veto fails | unit/contract | Phase 12 quick command; `test_phase12_calibration.R` | Yes - W0 | pending |
| 12-04-01 | 04 | 4 | PROMO-02 | N/A | Label-free final-fit/preflight failure prevents provider invocation and preserves the exact unopened allowlisted seam | integration | Phase 12 quick command; `test_phase12_final_evaluation.R` | Yes - W0 | pending |
| 12-05-01 | 05 | 5 | PROMO-02 | N/A | Immutable final-evaluation artifact and append-only manifest link freeze, label, prediction, score, coverage, and promotion hashes | contract | Phase 12 quick command; `test_phase12_final_evaluation.R` | Yes - W0 | pending |
| 12-05-02 | 05 | 5 | PROMO-02 | N/A | Promotion decision calls the locked Phase 9 evaluator and retains incumbent unless every gate passes | integration | Phase 12 quick command; `test_phase12_promotion.R` | Yes - W0 | pending |
| 12-06-01 | 06 | 6 | PROMO-03 | N/A | Core staged release contains model object, model contract, freeze/final manifests, report, model card, provenance, and core hashes | contract | Phase 12 quick command; core release smoke plus `test_phase12_release.R` | Yes - W0 | pending |
| 12-08-01 | 08 | 7 | PROMO-03 | N/A | Complete release installation validates metadata, hashes, paths, and fresh-process integrity before and after atomic replacement | regression | Phase 12 quick command; `test_phase12_release.R` and `test_benchmark_pipeline.R` | Yes - W0 | pending |
| 12-08-02 | 08 | 7 | PROMO-03 | N/A | Approved and exact no-promotion `incumbent retained` releases remain complete, rollback-safe, and consumer-ready | contract | Phase 12 quick command; `test_phase12_release.R` | Yes - W0 | pending |
| 12-07-01 | 07 | 8 | PROMO-03 | N/A | Dashboard/export resolution fails closed on absent, unapproved, or hash-mismatched release artifacts | regression | Phase 12 quick command; `test_phase12_release.R` and `test_worldcup_dashboard.R` | Yes - W0 | pending |
| 12-07-02 | 07 | 8 | PROMO-03 | N/A | Target ancestry remains label-safe and the approved/retained release metadata is preserved across dashboard/export consumers | integration | Phase 12 quick command; `test_phase12_promotion.R`, `test_phase12_release.R`, and `test_worldcup_dashboard.R` | Yes - W0 | pending |

*Status: pending until execution; green after the corresponding automated assertion passes.*

## Wave 0 Requirements

- [ ] `tests/testthat/test_phase12_calibration.R` - chronology, calibration recipe, raw/calibrated scoring, and veto contract stubs only.
- [ ] `tests/testthat/test_phase12_freeze.R` - nine-candidate freeze manifest and fail-closed hash/preflight contract stubs only.
- [ ] `tests/testthat/test_phase12_final_evaluation.R` - one-shot label gate, immutable artifact, and final manifest contract stubs only.
- [ ] `tests/testthat/test_phase12_promotion.R` - Phase 9 evaluator delegation and incumbent/challenger gate contract stubs only.
- [ ] `tests/testthat/test_phase12_release.R` - release bundle, contract validation, no-promotion fallback, and consumer contract stubs only.

Wave 0 creates no production code, reads no label artifact, and does not fit a calibrator.

## Manual-Only Verifications

All Phase 12 behaviors have an automated verification path. No manual-only verification is planned.

## Validation Sign-Off

- [ ] Every plan task has an automated `<verify>` command or a Wave 0 dependency.
- [ ] Sampling continuity has no three consecutive tasks without automated verification.
- [x] Wave 0 covers all five required Phase 12 test files.
- [ ] No watch-mode flags are used.
- [ ] Feedback latency remains below 90 seconds for targeted tests.
- [ ] `nyquist_compliant: true` set after execution verification.

**Approval:** pending
