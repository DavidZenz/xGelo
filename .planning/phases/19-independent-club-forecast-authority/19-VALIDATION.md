---
phase: 19
slug: independent-club-forecast-authority
status: planned
nyquist_compliant: false
wave_0_complete: false
created: 2026-09-20
updated: 2026-09-20
production_completion: human_needed
---

# Phase 19 — Validation Strategy

> Pre-execution Nyquist contract. Fixture-backed execution proves mechanics; it cannot satisfy CLUBMOD-04 or phase completion. Completion requires real accepted Phase 18 history and current-UCL/identity generations, accepted owner policy/fold reviews, a production-promoted candidate, an atomic club selector, and successful production resolver readback.

## Test Infrastructure

| Property | Value |
|---|---|
| Framework | `testthat` 3.3.2 |
| Strict focused command | `rtk Rscript --vanilla scripts/run_phase19_focused_test.R <test-file>...` |
| Full phase command | `rtk Rscript --vanilla scripts/verify_phase19_contracts.R` |
| Focused policy | Fail on failure, error, warning, skip, empty file, or missing file |
| Current production expectation | `human_needed`; no production club selector until every external authority/review gate passes |
| Maximum focused feedback | 60 seconds per task command; split tests when exceeded |

## Per-Task Verification Map

| Task | Wave | Requirements | Test file | Strict automated command | Pre-execution status |
|---|---:|---|---|---|---|
| 19-01-01 | 1 | CLUBMOD-01,05 | `test_phase19_club_domain_contract.R` | `rtk Rscript --vanilla scripts/run_phase19_focused_test.R tests/testthat/test_phase19_club_domain_contract.R` | MISSING — Wave 0 creates runner/test |
| 19-01-02 | 1 | CLUBMOD-05 | `test_phase19_club_domain_contract.R` | same focused command + `rtk git diff --check` | MISSING — Wave 0 |
| 19-02-01 | 2 | CLUBMOD-01,02 | `test_phase19_club_rating.R` | `rtk Rscript --vanilla scripts/run_phase19_focused_test.R tests/testthat/test_phase19_club_rating.R` | MISSING — Wave 0 |
| 19-02-02 | 2 | CLUBMOD-02 | `test_phase19_club_rating.R` | same focused command + `rtk git diff --check` | MISSING — Wave 0 |
| 19-03-01 | 2 | CLUBMOD-01,03 | `test_phase19_club_protocol.R` | `rtk Rscript --vanilla scripts/run_phase19_focused_test.R tests/testthat/test_phase19_club_protocol.R` | MISSING — Wave 0 |
| 19-03-02 | 2 | CLUBMOD-03 | `test_phase19_club_protocol.R` | same focused command + `rtk git diff --check` | MISSING — Wave 0 |
| 19-04-01 | 3 | CLUBMOD-02,03 | `test_phase19_club_folds.R` | `rtk Rscript --vanilla scripts/run_phase19_focused_test.R tests/testthat/test_phase19_club_folds.R` | MISSING — Wave 0 |
| 19-04-02 | 3 | CLUBMOD-02,03 | `test_phase19_club_folds.R` | same focused command + `rtk git diff --check` | MISSING — Wave 0 |
| 19-05-01 | 3 | CLUBMOD-01,02,05 | `test_phase19_club_goal_model.R` | `rtk Rscript --vanilla scripts/run_phase19_focused_test.R tests/testthat/test_phase19_club_goal_model.R` | MISSING — Wave 0 |
| 19-05-02 | 3 | CLUBMOD-01,05 | `test_phase19_club_goal_model.R` | same focused command + `rtk git diff --check` | MISSING — Wave 0 |
| 19-06-01 | 4 | CLUBMOD-02,03 | `test_phase19_club_calibration.R` | `rtk Rscript --vanilla scripts/run_phase19_focused_test.R tests/testthat/test_phase19_club_calibration.R` | MISSING — Wave 0 |
| 19-06-02 | 4 | CLUBMOD-03 | `test_phase19_club_calibration.R` | same focused command + `rtk git diff --check` | MISSING — Wave 0 |
| 19-07-01 | 5 | CLUBMOD-02,03 | `test_phase19_club_evaluation.R` | `rtk Rscript --vanilla scripts/run_phase19_focused_test.R tests/testthat/test_phase19_club_evaluation.R` | MISSING — Wave 0 |
| 19-07-02 | 5 | CLUBMOD-03 | `test_phase19_club_evaluation.R` | same focused command + `rtk git diff --check` | MISSING — Wave 0 |
| 19-08-01 | 6 | CLUBMOD-04 | `test_phase19_club_release.R` | `rtk Rscript --vanilla scripts/run_phase19_focused_test.R tests/testthat/test_phase19_club_release.R` | MISSING — Wave 0 |
| 19-08-02 | 6 | CLUBMOD-01,04,05 | club + national compatibility set | strict runner over club release, Phase 12/14 release, Phase 14 forecast/state, Phase 15 Nations League | MISSING club test; legacy tests exist |
| 19-09-01 | 7 | CLUBMOD-01..05 | `test_phase19_club_pipeline.R` | `rtk Rscript --vanilla scripts/run_phase19_focused_test.R tests/testthat/test_phase19_club_pipeline.R` | MISSING — Wave 0 |
| 19-09-02 | 7 | CLUBMOD-01..05 | `test_phase19_club_pipeline.R` | focused command + `rtk Rscript --vanilla -e 'targets::tar_manifest(fields=c(name, command))'` | MISSING — Wave 0 |
| 19-10-01 | 8 | CLUBMOD-01..05 | `test_phase19_adversarial_regression.R` | `rtk Rscript --vanilla scripts/run_phase19_focused_test.R tests/testthat/test_phase19_adversarial_regression.R` | MISSING — Wave 0 |
| 19-10-02 | 8 | CLUBMOD-01..05 | exact full inventory | `rtk Rscript --vanilla scripts/verify_phase19_contracts.R` | MISSING — Wave 0 |

## Wave 0 Required Artifacts

- [ ] `scripts/run_phase19_focused_test.R` — strict failures/errors/warnings/skips wrapper.
- [ ] `tests/testthat/helper_phase19_club_fixture.R` — paired history/current-UCL fixture authority.
- [ ] Ten exact `test_phase19_*.R` files named in Plans 19-01..19-10.
- [ ] `scripts/verify_phase19_contracts.R` — exact test/probe/30-prohibition inventory, protected byte maps, fixture reproducibility, regression set.
- [ ] Pending self-hashed `policy_review.json` and `fold_review.json` schemas; no invented approval.

## Production Completion Gate (Manual/External)

The verifier must return `human_needed` until all are true:

1. Phase 18 exposes accepted immutable historical and current-UCL non-tombstone generations plus an exact accepted current identity-registry generation.
2. An owner accepts the exact candidate/baseline/numeric gate policy review.
3. The real fold inventory, final cutoff, calibration recipe, and parent hashes receive a separate accepted owner fold review before scoring.
4. Production evaluation passes all gates with `authority_eligibility=production` and `promotion_status=promoted`.
5. The atomic production club selector exists and the production resolver reads back the immutable model-card-backed release.

Fixture evidence may yield `diagnostic_gate_outcome=pass`, but must remain `authority_eligibility=fixture_ineligible` and `promotion_status=ineligible_fixture`.

## Sign-Off State

- [ ] Wave 0 artifacts exist.
- [ ] Every focused check is strict and green.
- [ ] Full aggregate gate is green without production mutation.
- [ ] Fixture-only release/replay is deterministic.
- [ ] Production completion gate is satisfied by real evidence/review/release.

**Approval:** pending. Nyquist architecture is declared before execution; compliance and phase completion are not yet claimed.
