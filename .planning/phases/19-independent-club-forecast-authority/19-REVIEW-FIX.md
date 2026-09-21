---
phase: 19-independent-club-forecast-authority
fixed_at: 2026-09-21T08:47:28Z
review_path: .planning/phases/19-independent-club-forecast-authority/19-REVIEW.md
iteration: 1
findings_in_scope: 11
fixed: 11
skipped: 0
status: all_fixed
---

# Phase 19: Code Review Fix Report

**Fixed at:** 2026-09-21T08:47:28Z  
**Source review:** `.planning/phases/19-independent-club-forecast-authority/19-REVIEW.md`  
**Iteration:** 1

**Summary:**

- Findings in scope: 11 (7 blockers, 4 warnings)
- Fixed: 11
- Skipped: 0
- Production state: `human_needed / no_accepted_club_history / blocked`; no production selector or release generation was created.
- Aggregate limitation: the focused pipeline suite reached 45 passing assertions but the existing target environment lacks `glmnet` and `ranger`; no network or package installation was used.

## Fixed Issues

### CR-01: A fixture release can be installed into the production root and selected as approved authority

**Files modified:** `R/club/release.R`, `tests/testthat/test_phase19_club_release.R`, `tests/testthat/test_phase19_adversarial_regression.R`

**Commit:** `ec509bd`, with adversarial harness coverage in `2b3ba42`

**Applied fix:** Split fixture and production publication/resolution boundaries, require fixed production roots and source-backed production eligibility, and exercise install/domain/selector attacks against a real typed fixture release.

### CR-02: Release publication accepts arbitrary untyped model/calibrator objects and optional parent evidence

**Files modified:** `R/club/release.R`, `tests/testthat/test_phase19_club_release.R`, `tests/testthat/test_phase19_club_pipeline.R`, `tests/testthat/test_phase19_adversarial_regression.R`

**Commit:** `ec509bd`, `e219b18`, `6aea9c9`, `2b3ba42`

**Applied fix:** Require typed parent evidence, run all typed model/calibrator/evaluation/authority/integrity/decision validators before publication, remove caller validator injection, and explicitly load validator dependencies.

### CR-03: Production snapshot validators accept self-rehashed fixture provenance

**Files modified:** `R/club/model_contract.R`, `tests/testthat/test_phase19_club_domain_contract.R`

**Commit:** `67e9168`

**Applied fix:** Production validation re-reads fixed Phase 18 roots and rejects fixture markers, relabeled provenance, and non-provider source authority.

Status: fixed, requires human verification of source-backed production behavior when genuine Phase 18 evidence exists.

### CR-04: Goal-fit identity omits the nested fitted model and coefficient/grid contents

**Files modified:** `R/club/goal_model.R`, `tests/testthat/test_phase19_club_goal_model.R`

**Commit:** `9b0ba84`

**Applied fix:** Bind nested fitted model, coefficients, empirical grid, registration, and complete fit identity; recompute and reject mutated nested content.

Status: fixed, requires human verification of model semantics.

### CR-05: Evaluation-set validation is self-consistency only and accepts forged metrics

**Files modified:** `R/club/evaluation.R`, `tests/testthat/test_phase19_club_evaluation.R`

**Commit:** `26e72ae`

**Applied fix:** Re-derive fold evidence from exact source rows and replayed metrics, bind calibrated source evidence, and reject opaque self-consistency-only support hashes.

Status: fixed, requires human verification of production source replay with accepted provider artifacts.

### CR-06: Promotion integrity gates are caller-asserted booleans, not evidence-derived checks

**Files modified:** `R/club/evaluation.R`, `tests/testthat/test_phase19_club_evaluation.R`

**Commit:** `26e72ae`

**Applied fix:** Replace bare logical integrity claims with typed evidence derived from evaluation, replay, authority, and artifact identities; reject caller-supplied booleans.

Status: fixed, requires human verification of production artifact evidence.

### CR-07: The fixture “full evaluation” gate uses hard-coded distributions and a fake calibrator

**Files modified:** `scripts/run_phase19_club_evaluation.R`, `tests/testthat/test_phase19_club_pipeline.R`

**Commit:** `0f842c7`

**Applied fix:** Use the real goal prediction and calibrator APIs for both registered models, bind support hashes to fitted/calibrated evidence, and mark output `evaluation_mode=fixture_smoke`, `full_evaluation_gate=false`, and `production_eligible=false`.

Status: fixed, requires human verification of model/calibration semantics.

### WR-01: Rating batches silently accept unknown statuses and weak boundary metadata

**Files modified:** `R/club/rating.R`, `tests/testthat/test_phase19_club_rating.R`

**Commit:** `53f2211`

**Applied fix:** Close the status vocabulary, require scalar logical model inclusion, validate completed goals, and bind boundary identity to kickoff/date semantics.

### WR-02: Calibration error returns `NaN` for classes with no support

**Files modified:** `R/club/calibration.R`, `tests/testthat/test_phase19_club_calibration.R`

**Commit:** `6a3bb56`

**Applied fix:** Fail closed with typed `insufficient_class_support` before non-finite metrics can be serialized or promoted.

### WR-03: Model-card validation checks only a partial identity projection

**Files modified:** `R/club/release.R`, `tests/testthat/test_phase19_club_release.R`, `tests/testthat/test_phase19_club_pipeline.R`

**Commit:** `e219b18`

**Applied fix:** Validate the exact generated model-card field schema and every contract-bound value, with tamper regressions.

### WR-04: Later reason-code coverage is a source-text grep, not runtime verification

**Files modified:** `scripts/verify_phase19_contracts.R`

**Commit:** `f514b7c`

**Applied fix:** Replace source-text grep with 11 isolated runtime probes that assert reason codes and protected production-byte stability.

## Verification Evidence

Focused fresh-process suites passed:

- Adversarial: 13 tests / 71 assertions
- Calibration: 9 / 98
- Domain: 9 / 104
- Evaluation: 10 / 66
- Folds: 9 / 102
- Goal model: 9 / 90
- Protocol: 6 / 110
- Rating: 11 / 62
- Release: 9 / 36

The pipeline suite completed 45 passing assertions in the controller/fixture cases, then failed its existing `targets` dependency check because `glmnet` and `ranger` are unavailable; it also emitted the pre-existing empty-`max` warning. This is an environment limitation, not a review-fix regression. The standalone runtime verifier passed all 11 later-reason probes and reported protected production bytes unchanged.

## Skipped Issues

None — all in-scope findings were fixed.

---

_Fixed: 2026-09-21T08:47:28Z_  
_Fixer: the agent (gsd-code-fixer)_  
_Iteration: 1_
