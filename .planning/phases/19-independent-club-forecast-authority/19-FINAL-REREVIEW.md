---
phase: 19-independent-club-forecast-authority
reviewed: 2026-09-21T12:20:56Z
depth: deep
files_reviewed: 17
files_reviewed_list:
  - R/club/model_contract.R
  - R/club/rating.R
  - R/club/goal_model.R
  - R/club/calibration.R
  - R/club/evaluation.R
  - R/club/evaluation_protocol.R
  - R/club/release.R
  - R/release/domain_contract.R
  - scripts/run_phase19_club_evaluation.R
  - _targets.R
  - tests/testthat/helper_phase19_club_fixture.R
  - tests/testthat/test_phase19_adversarial_regression.R
  - tests/testthat/test_phase19_club_domain_contract.R
  - tests/testthat/test_phase19_club_evaluation.R
  - tests/testthat/test_phase19_club_goal_model.R
  - tests/testthat/test_phase19_club_protocol.R
  - tests/testthat/test_phase19_club_rating.R
findings:
  critical: 3
  warning: 0
  info: 0
  total: 3
status: issues_found
---

# Phase 19: Final Independent Code Review

**Reviewed:** 2026-09-21T12:20:56Z
**Depth:** deep
**Files Reviewed:** 17
**Status:** issues_found

## Summary

This was an independent rereview of integrated master at `b482b754a7eecab24d56176e6d45a6f749bbf92c`. I read `AGENTS.md`, `19-REVIEW.md`, `19-REVIEW-FIX.md`, `19-REREVIEW.md`, and `19-REREVIEW-FIX-2.md`, then traced the current production authority, evaluation, rating, calibration, model, and release call chains directly. The current-UCL roster/source byte binding, complete training manifest checks, deterministic rating replay digest and re-execution, prediction and fold-level calibration regeneration, club/national domain separation, fixture escalation guards, and explicit production preflight are present and materially stronger than the earlier revisions.

The review is not clean. Three production trust-boundary gaps remain. The production authority builder accepts caller-supplied self-hashed protocol/fold graphs without resolving them against the committed owner-reviewed runtime root; the release parent graph validates self-consistent top-level model/calibrator objects without binding them to the exact evaluated source artifacts; and the byte-reproducibility gate compares caller-provided identities rather than independently re-executing and binding them to the evaluated set. These can make a production-looking authority or release describe artifacts that were never the accepted/evaluated source.

The repository's current production state is still honestly blocked by the absent accepted history/policy/fold root (`no_accepted_club_history`/`protocol_policy_not_approved`/related blocked states). That expected state is not counted as a finding. No source files were modified. Existing unrelated dirty files were preserved.

## Verification Evidence

Bounded suites run against the reviewed commit:

- `Rscript --vanilla scripts/run_phase19_focused_test.R tests/testthat/test_phase19_club_domain_contract.R` — PASS, 10 tests / 105 assertions.
- `Rscript --vanilla scripts/run_phase19_focused_test.R tests/testthat/test_phase19_club_protocol.R` — PASS, 6 tests / 110 assertions.
- `Rscript --vanilla scripts/run_phase19_focused_test.R tests/testthat/test_phase19_club_rating.R` — PASS, 11 tests / 65 assertions.
- The release, adversarial regression, and goal-model focused invocations were not allowed to run beyond the bounded review window; they were stopped before a result rather than treated as passes. No aggregate or known multi-hour targets run was started.

Targeted probes also gave exact evidence for the remaining gaps:

- A fixture protocol copied in memory, relabeled `production`, given an accepted caller review, and rehashed was accepted by `phase19_evaluate_policy_review()` as `ACCEPTED ready production caller`, while the fixed loader correctly remained `blocked protocol_policy_not_approved`.
- A self-hashed typed goal fit with `model_family = "bogus"` and a self-hashed production calibrator with arbitrary parent identities were each accepted by their generic validators. This is expected to be rejected when source-bound, but the release graph does not perform that source binding.
- A typed shell containing only `evaluation_set_sha256 = "aaaa..."` was supplied as both replay executions. `phase19_club_reproducibility_evidence()` returned `reproducible=TRUE`, and `phase19_club_validate_reproducibility()` returned `ACCEPTED` without evaluating any fold.

## Critical Issues

### CR-01: Production protocol and fold authority is not anchored to the committed runtime root — BLOCKER

**File:** `R/club/evaluation.R:1440-1472,1561-1582`; `R/club/evaluation_protocol.R:1859-1873,1921-1931`; `R/club/release.R:360-387`

**Issue:** `phase19_club_validate_production_sources()` validates the caller's `protocol$policy_review`, regenerates a fold registry from the caller's `history` and `protocol`, and checks that `folds$protocol` is identical to that same caller object. `phase19_production_evaluation_authority()` and the release parent graph pass those objects through. Neither path calls `phase19_load_club_evaluation_protocol()` or `phase19_load_club_fold_protocol()` and compares the supplied protocol, policy review, fold registry, generation, and fold review to the fixed persisted runtime root. `phase19_assert_production_fold_protocol()` checks only class/status/mode/eligibility. Consequently, a caller can construct an internally coherent, self-hashed production protocol/fold graph from a fixture or alternate registry and bypass the owner-reviewed root. The probe above demonstrated the protocol half of this bypass even while the committed loader is blocked.

**Fix:** Make production authority and installation resolve protocol and fold authority from the fixed loaders (or from opaque immutable generation IDs), then require exact persisted pointer, generation, protocol, policy-review, fold-registry, and fold-review identities. Reject caller-supplied protocol/fold/review objects for production; retain caller objects only for permanently ineligible fixture mode. Repeat the fixed-root check immediately before any release write.

### CR-02: Production release accepts self-consistent but unevaluated model and calibrator objects — BLOCKER

**File:** `R/club/release.R:389-418`; `R/club/goal_model.R:627-665`; `R/club/calibration.R:455-565`; `R/club/evaluation.R:874-923`

**Issue:** The release parent graph validates evaluated fold source artifacts, but validates the release `model` only with `phase19_validate_club_goal_fit()` and the release `calibrator` only with `phase19_validate_club_calibrator()`. Those generic validators prove nested self-hashes, domain flags, and some structural constraints; they do not regenerate the fit from the fixed training snapshot/rating replay/protocol or regenerate the calibrator from the exact evaluated source rows. The release checks only model/calibrator IDs and broad history/current/protocol parent hashes. It never compares `model$fit_sha256` and `calibrator$calibrator_sha256` (plus calibration evidence/decision identities) to the exact `model_support` rows produced by `phase19_validate_club_fold_source_artifacts()`. A caller can therefore alter coefficients/model-family metadata or calibration temperature, recompute the self-hash, retain the expected IDs and parent snapshot/protocol hashes, and present a release model different from the model that produced the evaluated predictions. The targeted probes showed that a bogus self-hashed goal fit and arbitrary self-hashed production calibrator each pass their generic validator.

**Fix:** Derive the installable model and calibrator exclusively from the canonical accepted evaluation artifact, or rerun both from fixed history/current, deterministic rating replay, fixed fold registry, and typed source rows during release validation. Require exact equality of the complete fit/calibrator identities with the selected `model_support`, including calibration evidence and decision hashes; do not treat a caller-supplied top-level RDS plus self-hashes as source authority.

### CR-03: Byte-reproducibility is self-attested rather than independently replayed — BLOCKER

**File:** `R/club/evaluation.R:1388-1410,1877-1889,1948-1967`; `scripts/run_phase19_club_evaluation.R:520-522`

**Issue:** `phase19_club_reproducibility_evidence()` accepts arbitrary values. For an object inheriting `phase19_club_evaluation_set`, `phase19_club_evaluation_identity()` returns the object's caller-supplied `evaluation_set_sha256` without validating the set or recomputing it. `phase19_club_validate_reproducibility()` checks only the evidence schema, self-hash, and registered seed; it does not require the first and second identities to equal the current `evaluation$evaluation_set_sha256`, nor does it execute the evaluation twice. The fixture runner literally passes the same aggregate object as both executions. The targeted probe used a two-field typed shell with an arbitrary 64-character hash and received `reproducible=TRUE` and `ACCEPTED`. Promotion then turns that flag directly into the required `byte_reproducibility` metric at line 1967.

**Fix:** In production, perform two independent deterministic evaluations from the fixed source graph inside a controlled replay function, canonicalize the complete outputs, and compare their derived hashes to each other and to `evaluation$evaluation_set_sha256`. Validate the full typed evaluation set before identity extraction. Do not accept caller-supplied hash-only shells as replay evidence; keep fixture replay permanently ineligible.

## Warnings

None.

---

_Reviewed: 2026-09-21T12:20:56Z_  
_Reviewer: the agent (independent Phase 19 rereview)_  
_Depth: deep_
