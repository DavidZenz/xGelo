---
phase: 19
slug: independent-club-forecast-authority
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-09-20
updated: 2026-09-21
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
| 19-01-01 | 1 | CLUBMOD-01,05 | `test_phase19_club_domain_contract.R` | `rtk Rscript --vanilla scripts/run_phase19_focused_test.R tests/testthat/test_phase19_club_domain_contract.R` | PASS — aggregate fresh-process run; 9 tests / 103 assertions |
| 19-01-02 | 1 | CLUBMOD-05 | `test_phase19_club_domain_contract.R` | same focused command + `rtk git diff --check` | PASS — aggregate inventory and diff hygiene |
| 19-02-01 | 2 | CLUBMOD-01,02 | `test_phase19_club_rating.R` | `rtk Rscript --vanilla scripts/run_phase19_focused_test.R tests/testthat/test_phase19_club_rating.R` | PASS — aggregate fresh-process run; 10 tests / 58 assertions |
| 19-02-02 | 2 | CLUBMOD-02 | `test_phase19_club_rating.R` | same focused command + `rtk git diff --check` | PASS — aggregate inventory and diff hygiene |
| 19-03-01 | 2 | CLUBMOD-01,03 | `test_phase19_club_protocol.R` | `rtk Rscript --vanilla scripts/run_phase19_focused_test.R tests/testthat/test_phase19_club_protocol.R` | PASS — aggregate fresh-process run; 6 tests / 110 assertions |
| 19-03-02 | 2 | CLUBMOD-03 | `test_phase19_club_protocol.R` | same focused command + `rtk git diff --check` | PASS — aggregate inventory and diff hygiene |
| 19-04-01 | 3 | CLUBMOD-02,03 | `test_phase19_club_folds.R` | `rtk Rscript --vanilla scripts/run_phase19_focused_test.R tests/testthat/test_phase19_club_folds.R` | PASS — aggregate fresh-process run; 9 tests / 102 assertions |
| 19-04-02 | 3 | CLUBMOD-02,03 | `test_phase19_club_folds.R` | same focused command + `rtk git diff --check` | PASS — aggregate inventory and diff hygiene |
| 19-05-01 | 3 | CLUBMOD-01,02,05 | `test_phase19_club_goal_model.R` | `rtk Rscript --vanilla scripts/run_phase19_focused_test.R tests/testthat/test_phase19_club_goal_model.R` | PASS — aggregate fresh-process run; 8 tests / 89 assertions |
| 19-05-02 | 3 | CLUBMOD-01,05 | `test_phase19_club_goal_model.R` | same focused command + `rtk git diff --check` | PASS — aggregate inventory and diff hygiene |
| 19-06-01 | 4 | CLUBMOD-02,03 | `test_phase19_club_calibration.R` | `rtk Rscript --vanilla scripts/run_phase19_focused_test.R tests/testthat/test_phase19_club_calibration.R` | PASS — aggregate fresh-process run; 8 tests / 97 assertions |
| 19-06-02 | 4 | CLUBMOD-03 | `test_phase19_club_calibration.R` | same focused command + `rtk git diff --check` | PASS — aggregate inventory and diff hygiene |
| 19-07-01 | 5 | CLUBMOD-02,03 | `test_phase19_club_evaluation.R` | `rtk Rscript --vanilla scripts/run_phase19_focused_test.R tests/testthat/test_phase19_club_evaluation.R` | PASS — aggregate fresh-process run; 8 tests / 63 assertions |
| 19-07-02 | 5 | CLUBMOD-03 | `test_phase19_club_evaluation.R` | same focused command + `rtk git diff --check` | PASS — aggregate inventory and diff hygiene |
| 19-08-01 | 6 | CLUBMOD-04 mechanics | `test_phase19_club_release.R` | `rtk Rscript --vanilla scripts/run_phase19_focused_test.R tests/testthat/test_phase19_club_release.R` | PASS — aggregate fresh-process run; 8 tests / 31 assertions; production pending |
| 19-08-02 | 6 | CLUBMOD-01,05 direct; CLUBMOD-04 mechanics | club + national compatibility set | strict runner over club release, Phase 12/14 release, Phase 14 forecast/state, Phase 15 Nations League | PARTIAL — club, forecast/state, and Nations League gates pass; Phase 12 release and dependent Phase 14 calibration are blocked by the pre-existing missing Phase 12 model artifact |
| 19-09-01 | 7 | CLUBMOD-01..03,05 direct; CLUBMOD-04 mechanics | `test_phase19_club_pipeline.R` | `rtk Rscript --vanilla scripts/run_phase19_focused_test.R tests/testthat/test_phase19_club_pipeline.R` | PASS — aggregate fresh-process run; 7 tests / 46 assertions; production pending |
| 19-09-02 | 7 | CLUBMOD-01..03,05 direct; CLUBMOD-04 mechanics | `test_phase19_club_pipeline.R` | focused command + `rtk Rscript --vanilla -e 'targets::tar_manifest(fields=c(name, command))'` | PASS — prior plan manifest check and aggregate pipeline run; production pending |
| 19-10-01 | 8 | CLUBMOD-01..03,05 direct; CLUBMOD-04 mechanics | `test_phase19_adversarial_regression.R` | `rtk Rscript --vanilla scripts/run_phase19_focused_test.R tests/testthat/test_phase19_adversarial_regression.R` | PASS — 13 tests / 71 assertions; exact 30 executable probes |
| 19-10-02 | 8 | CLUBMOD-01..03,05 direct; CLUBMOD-04 mechanics | exact full inventory | `rtk Rscript --vanilla scripts/verify_phase19_contracts.R` | MECHANICS PASS — exact inventories, fresh suites, Phase 18, replay, and production preservation pass; command remains blocked only by the declared pre-existing Phase 12 model artifact |

## Wave 0 Required Artifacts

- [x] `scripts/run_phase19_focused_test.R` — strict failures/errors/warnings/skips wrapper.
- [x] `tests/testthat/helper_phase19_club_fixture.R` — paired history/current-UCL fixture authority.
- [x] Ten exact `test_phase19_*.R` files named in Plans 19-01..19-10.
- [x] `scripts/verify_phase19_contracts.R` — exact test/probe/30-prohibition inventory, protected byte maps, fixture reproducibility, regression set.
- [x] Pending self-hashed `policy_review.json` and `fold_review.json` schemas exist; no invented approval.

## Production Completion Gate (Manual/External)

The verifier must return `human_needed` until all are true:

1. Phase 18 exposes accepted immutable historical and current-UCL non-tombstone generations plus an exact accepted current identity-registry generation.
2. An owner accepts the exact candidate/baseline/numeric gate policy review.
3. The real fold inventory, final cutoff, calibration recipe, and parent hashes receive a separate accepted owner fold review before scoring.
4. Production evaluation passes all gates with `authority_eligibility=production` and `promotion_status=promoted`.
5. The atomic production club selector exists and the production resolver reads back the immutable model-card-backed release.

Fixture evidence may yield `diagnostic_gate_outcome=pass`, but must remain `authority_eligibility=fixture_ineligible` and `promotion_status=ineligible_fixture`.

The fixed-root production CLI currently asserts only the truthful first reason, `no_accepted_club_history`. Later current-UCL, identity, policy-review, and fold-review reasons are validation-mechanics evidence obtained through tagged non-production temporary boundary harnesses; those harnesses cannot create accepted production prerequisites or satisfy CLUBMOD-04.

## Observed Aggregate Results (2026-09-21)

The credential-free aggregate verifier completed every Phase 19 and Phase 18
mechanics gate before reporting the known national regression blocker. It
reported the following evidence:

- Exact inventory: 30 `[FLAGGED-UNVERIFIED]` prohibitions, 30 bijective probe
  rows, and 30 executable probe hits; all ten planned Phase 19 test files were
  present and executed in fresh processes.
- Phase 19 suite: 86 tests / 770 assertions across ten files, with zero
  warnings, skips, or failures. The adversarial file contributed 13 tests / 71
  assertions.
- Phase 18 gate: 15 critical probes, four warning probes, 15 edge probes, 50
  mapped prohibitions, eight fresh-process files, 142 tests / 840 assertions,
  and `production_fail_closed=true`.
- National regressions: Phase 14 forecast (16 / 136), Phase 14 state bundle
  (18 / 162), and Phase 15 Nations League (40 / 607) passed. Phase 12 release
  and dependent Phase 14 calibration-release checks remain blocked by the
  pre-existing missing
  `outputs/releases/phase12-wc2026-incumbent-retained-v1/model/approved_model.rds`.
  No replacement artifact was created.
- Fixture replay: two isolated runs from one materialized fixture root emitted
  byte-identical canonical outputs and release trees. The selector's intentional
  approval timestamp is excluded from byte comparison; both selector rows are
  self-hash-valid and have identical stable identity fields. Both results remain
  `human_needed`, `fixture_ineligible`, and `ineligible_fixture`.
- Production controller: the fixed-root CLI returned exactly
  `human_needed / no_accepted_club_history / blocked`, did not expose a club
  selector, and did not start model work. Protected production descriptors and
  selectors were byte-identical before and after verification.
- Later authority/review reasons were checked only through tagged temporary
  non-production public-boundary harnesses; no harness can publish into a
  production root or create accepted production prerequisites.

The aggregate command therefore exits nonzero with
`PHASE19_GATE_BLOCKED reason=preexisting_national_regression_artifact_missing`
until the externally owned Phase 12 model artifact is genuinely restored. This
is a truthful blocker, not a test suppression or a production promotion.

## Sign-Off State

- [x] Wave 0 artifacts exist.
- [x] Every Phase 19 focused check is strict and green.
- [x] Aggregate mechanics are green through Phase 19/18, fixture replay, and
  production-byte preservation; the command is externally blocked by the
  declared missing Phase 12 model artifact.
- [x] Fixture-only release/replay is deterministic.
- [ ] Production completion gate is satisfied by real evidence/review/release.

**Approval:** mechanics verified 2026-09-21; production completion remains
human-needed and the national regression blocker remains open. No phase
completion or CLUBMOD-04 production authority is claimed.
