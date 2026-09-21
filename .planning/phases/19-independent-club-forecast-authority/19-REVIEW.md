---
phase: 19-independent-club-forecast-authority
reviewed: 2026-09-21T04:13:34Z
depth: deep
files_reviewed: 34
files_reviewed_list:
  - R/club/calibration.R
  - R/club/evaluation.R
  - R/club/evaluation_protocol.R
  - R/club/goal_model.R
  - R/club/model_contract.R
  - R/club/rating.R
  - R/club/release.R
  - R/competition/forecast_layer.R
  - R/release/domain_contract.R
  - R/release/release_contract.R
  - _targets.R
  - data/club/model_protocol/calibration_recipe.json
  - data/club/model_protocol/candidate_registry.csv
  - data/club/model_protocol/feature_contract.csv
  - data/club/model_protocol/fold_registry.csv
  - data/club/model_protocol/fold_review.json
  - data/club/model_protocol/gate_registry.csv
  - data/club/model_protocol/policy_review.json
  - data/club/model_protocol/protocol_state.json
  - data/club/model_protocol/seed_registry.csv
  - scripts/run_phase19_club_evaluation.R
  - scripts/run_phase19_focused_test.R
  - scripts/verify_phase19_contracts.R
  - tests/testthat/helper_phase19_club_fixture.R
  - tests/testthat/test_phase19_adversarial_regression.R
  - tests/testthat/test_phase19_club_calibration.R
  - tests/testthat/test_phase19_club_domain_contract.R
  - tests/testthat/test_phase19_club_evaluation.R
  - tests/testthat/test_phase19_club_folds.R
  - tests/testthat/test_phase19_club_goal_model.R
  - tests/testthat/test_phase19_club_pipeline.R
  - tests/testthat/test_phase19_club_protocol.R
  - tests/testthat/test_phase19_club_rating.R
  - tests/testthat/test_phase19_club_release.R
findings:
  critical: 7
  warning: 4
  info: 0
  total: 11
status: fixed
---

# Phase 19: Code Review Report

**Reviewed:** 2026-09-21T04:13:34Z  
**Depth:** deep  
**Files Reviewed:** 34  
**Status:** fixed

## Summary

The Phase 19 implementation has substantial integrity gaps at the boundaries that are supposed to prevent fixture evidence, forged provenance, and self-rehashed metrics from becoming forecast authority. Focused Phase 19 tests pass, but the tested paths do not cover the attacks below. The current production result of `human_needed / no_accepted_club_history / blocked` is honest and was not counted as a defect; it is not evidence that the publication and promotion gates are safe once inputs become available.

The automated fixture/aggregate gate is not trustworthy as production evidence. It demonstrates deterministic fixture mechanics and fail-closed behavior, but it permits synthetic probabilities, caller-asserted integrity flags, and self-hashed evaluation tables without independently binding them to fitted models, calibrators, outcomes, or fixed Phase 18 sources.

The reviewed blockers and warnings were fixed in atomic commits listed in `19-REVIEW-FIX.md`. Fixture mode now remains explicitly diagnostic and non-promotable; production remains fail-closed/human-needed until genuine Phase 18 provider evidence and owner approvals exist.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: A fixture release can be installed into the production root and selected as approved authority

**Classification:** BLOCKER  
**File:** `R/club/release.R:807-827,871-888`

`phase19_stage_fixture_club_release()` rejects the production root while staging, but `phase19_install_club_release()` accepts any preflight-valid staged root and any caller-supplied output root. It never rejects `authority_mode = "fixture"` or `production_eligible = FALSE`. The generic resolver likewise has no production-only mode and returns the fixture model/calibrator from the selector. A read-only temporary-root probe successfully staged a fixture, installed it under a production-shaped root, and resolved it as a selector-authorized club release. This defeats the stated “fixture resolver only” and “fixture never production” guarantees.

**Fix:** Split fixture installation/resolution from production publication, or require an explicit `require_production = TRUE` guard that rejects fixture contracts. The production installer must require fixed production roots, `production_eligible = TRUE`, source-backed authority, and a fully validated promoted decision; the fixture installer must be unable to write or create a production selector.

**Status:** fixed

**Evidence:** `ec509bd` separates fixture installation/resolution from production publication, enforces temporary fixture roots and fixed production roots, and rejects fixture authority in production paths. `2b3ba42` keeps adversarial P22–P24 coverage on a real typed fixture release. Production CLI and runtime verifier remain `human_needed`/blocked with no production selector.

### CR-02: Release publication accepts arbitrary untyped model/calibrator objects and optional parent evidence

**Classification:** BLOCKER  
**File:** `R/club/release.R:464-484,262-275,692-772`

The fixture staging boundary only checks that `model` and `calibrator` are lists, have the club domain, and have matching IDs. `history_snapshot`, `current_snapshot`, `protocol`, `evaluation`, and `authority` are optional and can be omitted, after which the contract uses fallback strings/blanks. The release validator verifies file hashes and a few scalar identities, but never calls `phase19_validate_club_goal_fit()` or `phase19_validate_club_calibrator()` and does not recompute the decision/evaluation from source evidence. Minimal compatible lists can therefore be staged, installed, and resolved as an “immutable” release. The injectable `validator` argument at `:809-814` also lets a caller replace the publication validator entirely.

**Fix:** Require non-null typed parent objects and call the goal-fit, calibrator, authority, evaluation, and decision validators before writing any generation. Reject fallback parent identities and remove the public custom-validator escape hatch (or permit only an internal, identity-checked validator).

**Status:** fixed

**Evidence:** `ec509bd`, `e219b18`, and `6aea9c9` require typed parents, remove caller validators, load the typed validators explicitly, and validate model/calibrator/evaluation/authority/integrity/decision objects before publication. Release and adversarial suites pass; minimal untyped parent attacks remain rejected.

### CR-03: Production snapshot validators accept self-rehashed fixture provenance

**Classification:** BLOCKER  
**File:** `R/club/model_contract.R:247-248,362-417,467-553,612-654`

`phase19_build_training_snapshot()` and `phase19_build_current_snapshot()` accept caller-selected paths and authority mode. The validators only check the requested mode/discriminator, canonical table content, and hashes supplied by the object; they do not re-read the fixed Phase 18 pointer, accepted generation, UCL source bundle, identity pointer, or source authority type. In read-only probes, building a fixture snapshot with `authority_mode = "production"` returned `ready` and passed the production validator. Relabeling a valid fixture training/current snapshot (`authority_mode`, fixture/promotion flags, and self-hash) was also accepted; the current snapshot retained `source_authority_type = "fixture_contract"` while passing production validation. This is a cross-domain/authority escalation path if a caller supplies these objects to production consumers.

**Fix:** Make production loaders the only production construction path and have production validation re-read fixed Phase 18 files, then compare accepted generation IDs, bundle/source hashes, identity generation/pointer hashes, promotion state, and source authority type. Reject any fixture provenance regardless of a caller-recomputed object hash.

**Status:** fixed (requires human verification)

**Evidence:** `67e9168` binds production snapshot validation to fixed Phase 18 roots and rejects fixture markers/provenance, relabeled provenance, and non-provider source authority; the domain contract suite passes 9 tests/104 assertions.

### CR-04: Goal-fit identity omits the nested fitted model and coefficient/grid contents

**Classification:** BLOCKER  
**File:** `R/club/goal_model.R:354-373,475-540,544-562`

`phase19_club_goal_fit_hash()` hashes scalar projections plus the *declared* `coefficient_sha256` and `empirical_grid_sha256`, but does not recompute those digests from `fit$coefficients`/`fit$empirical_grid` or hash the nested `fit$model`/`registration`. The validator only checks the stored hash and that `stats::coef(fit$model)` equals the separately mutable coefficient table. A read-only probe changed the nested NB coefficients and the coefficient table, left the stored coefficient/grid/fit hashes unchanged, and `phase19_validate_club_goal_fit()` accepted the object; predictions consequently change while the advertised fit identity does not.

**Fix:** Recompute nested coefficient/grid hashes during validation, hash a canonical representation of the fitted model and registration, and verify the registration/formula/theta/model object against the frozen protocol. Bind prediction and release identities to that complete fit digest.

**Status:** fixed (requires human verification)

**Evidence:** `9b0ba84` adds nested model, coefficient, empirical-grid, and registration identity to fit hashes and recomputes them during validation; the goal-model suite passes 9 tests/90 assertions and includes nested-fit mutation rejection.

### CR-05: Evaluation-set validation is self-consistency only and accepts forged metrics

**Classification:** BLOCKER  
**File:** `R/club/evaluation.R:196-230,633-723,725-746,863-967,970-998,1074-1119`

The exact-source `phase19_validate_club_fold_evaluation()` exists, but the production path does not call it. `phase19_club_evaluation_fold_self_check()` verifies only object/table hashes, coverage/convergence/cutoff flags, and arithmetic consistency; aggregation and evaluation-set validation then trust those self-checked folds. `model_support` treats calibrator/evidence/decision digests as opaque SHA-256 strings and only binds the fit digests. A producer can fabricate predictions, score tables, outcomes, and summary metrics, recompute the internal hashes, and pass the set/promotion validators without reproducing them from trusted rows and model/calibrator artifacts.

**Fix:** Require every fold in a production evaluation set to be re-derived with `phase19_validate_club_fold_evaluation()` from the exact fitted predictions, calibrated views, outcomes, fold rows, and protocol, or persist and verify canonical source artifacts at that boundary. Do not accept opaque support hashes as evidence.

**Status:** fixed (requires human verification)

**Evidence:** `26e72ae` binds evaluation folds to exact source rows and replayed metrics, validates cached production aggregates, and rejects opaque/self-consistent support claims. The evaluation suite passes 10 tests/66 assertions.

### CR-06: Promotion integrity gates are caller-asserted booleans, not evidence-derived checks

**Classification:** BLOCKER  
**File:** `R/club/evaluation.R:1308-1327,1399-1414,1467-1487`

`phase19_club_integrity_sha256()` proves only that eleven named logical values were supplied. `phase19_evaluate_club_promotion()` copies those values directly into the metrics, and `phase19_validate_club_promotion_decision()` recomputes the same decision from the same caller claims. Nothing binds `probability_integrity`, source/license/feature/seed/checksum integrity, or model-card integrity to the corresponding artifacts. Supplying an all-`TRUE` list therefore satisfies the integrity portion of a decision whenever the other self-consistency checks pass.

**Fix:** Replace the logical list with a typed evidence object. Derive each gate by validating the relevant source/model/calibrator/card artifact, bind the evidence hashes into the decision, and reject bare caller assertions.

**Status:** fixed (requires human verification)

**Evidence:** `26e72ae` replaces caller booleans with typed integrity evidence derived from evaluation/replay/authority artifacts and rejects bare logical integrity lists; adversarial integrity attacks pass as rejections.

### CR-07: The fixture “full evaluation” gate uses hard-coded distributions and a fake calibrator

**Classification:** BLOCKER  
**File:** `scripts/run_phase19_club_evaluation.R:306-347,417-428,457-502`

The fixture controller fits two models, but its evaluation predictions are generated by `phase19_cli_grid()`: the calibrated profile is a hard-coded 0.50/0.25/0.25 point mass and ignores the fitted means, while the other profile uses hard-coded means. It never calls `phase19_predict_club_goal_model()` or fits/applies `phase19_fit_club_calibrator()`. `phase19_cli_fixture_calibrator()` returns a minimal object that would fail the typed calibrator schema validator, and support/evidence/decision hashes are synthetic strings derived from the fit hash. The resulting diagnostic gate can pass without exercising the model or calibration path that a production release would rely on.

**Fix:** Generate both candidate and incumbent fold predictions through the production prediction API, fit and validate nested calibrators from declared inner-OOF rows, apply/validate the calibrated view and evidence, and bind support hashes to those objects. Add a regression proving that changing a fit changes the evaluated distributions/metrics. If the fixture is intentionally only a smoke test, prevent it from being reported as a full evaluation gate.

**Status:** fixed (requires human verification)

**Evidence:** `0f842c7` removes hard-coded grids/fake calibrators, calls the real goal prediction and calibration APIs, binds support hashes to fitted/calibrated evidence, and marks output `evaluation_mode=fixture_smoke`, `full_evaluation_gate=false`, and `production_eligible=false`. The pipeline fixture assertions cover these non-promotable fields; the fixture controller completed with `human_needed / fixture_ineligible / retained`.

## Warnings

### WR-01: Rating batches silently accept unknown statuses and weak boundary metadata

**Classification:** WARNING  
**File:** `R/club/rating.R:337-385,450-453`

`status` is only interpreted by equality with `"completed"`; unknown values silently become non-completed rows. `counts_for_model` is coerced with `as.logical()` instead of being required to be a logical column, and the validator checks that there is one boundary ID but does not validate its relationship to the single kickoff. Malformed inputs can therefore be silently omitted from rating updates or carry an arbitrary boundary identity.

**Fix:** Enforce the closed status vocabulary, require scalar logical `counts_for_model`, require finite integer goals for completed rows, and validate the boundary ID format/UTC against the batch kickoff (including the date-only convention).

**Status:** fixed

**Evidence:** `53f2211` closes status/boundary/goal validation and adds same-kickoff/date boundary regressions; the rating suite passes 11 tests/62 assertions.

### WR-02: Calibration error returns `NaN` for classes with no support

**Classification:** WARNING  
**File:** `R/club/calibration.R:830-836`; `R/club/evaluation.R:328-334`

Both calibration-error helpers divide by `sum(selected$n)` for each class without checking a zero denominator. A fold lacking a home/draw/away observation produces `NaN`, which can be carried into serialized summaries and only fails later, indirectly, when a required promotion comparison rejects a non-finite value.

**Fix:** Require positive support for every class before constructing the metric, or return a typed `insufficient_class_support` result that makes the fold/evaluation invalid before hashes and promotion evidence are created.

**Status:** fixed

**Evidence:** `6a3bb56` fails closed with typed insufficient-support errors before metric serialization; the calibration suite passes 9 tests/98 assertions.

### WR-03: Model-card validation checks only a partial identity projection

**Classification:** WARNING  
**File:** `R/club/release.R:424-440,665-672`

The generated card contains authority mode, fixture/production flags, parent generations, fold/feature/evaluation identities, and limitations, but validation compares only eight fields (`forecast_domain`, entity/model IDs, protocol/promotion hashes, and model/calibrator file hashes). A card can be edited and rehashed while falsely documenting authority, parents, or unavailable-feature policy.

**Fix:** Validate every generated machine-readable field against the release contract, or generate/validate one canonical contract projection and reject extra or missing identity fields.

**Status:** fixed

**Evidence:** `e219b18` enforces the exact model-card field/value projection and adds tamper regressions; the release suite passes 9 tests/36 assertions.

### WR-04: Later reason-code coverage is a source-text grep, not runtime verification

**Classification:** WARNING  
**File:** `scripts/verify_phase19_contracts.R:418-438`

`phase19_gate_later_reasons()` marks eleven blocked/error boundaries as covered merely because their strings occur in selected source files. This can pass when a reason is dead, unreachable, or only present in a comment; it does not exercise the public boundary validators or assert the expected fail-closed result.

**Fix:** Replace the grep with isolated runtime probes for each reason code, asserting the triggering malformed input, error class/reason, and that no release/selector state changes.

**Status:** fixed

**Evidence:** `f514b7c` replaces source-text grep with 11 isolated runtime probes, including selector reread mutation and protected-byte snapshots. Standalone output: `PHASE19_LATER_REASON_CODES count=11 isolated_nonproduction=true runtime_probes=11`.

## Automated Gate Assessment

Focused suites for adversarial, calibration, domain, evaluation, folds, goal model, protocol, rating, and release all passed (13/71, 9/98, 9/104, 10/66, 9/102, 9/90, 6/110, 11/62, and 9/36 tests/assertions respectively). The pipeline suite passed 45 assertions in its fixture/controller cases, then stopped at the pre-existing target-environment error for missing `glmnet` and `ranger` (with one existing `max` warning); no packages were installed and no review fix depends on them. The runtime aggregate verifier reached the same environment-only limitation after the completed focused suites. Protected production bytes and the explicitly excluded dirty paths remained unchanged. Production remains `human_needed / no_accepted_club_history / blocked`, with no production selector or release generation.

---

_Reviewed: 2026-09-21T04:13:34Z_  
_Reviewer: the agent (gsd-code-reviewer)_  
_Depth: deep_
