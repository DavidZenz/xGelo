---
phase: 19-independent-club-forecast-authority
reviewed: 2026-09-21T09:27:41Z
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
  critical: 5
  warning: 2
  info: 0
  total: 7
status: resolved
fix_iteration: 2
fix_report: .planning/phases/19-independent-club-forecast-authority/19-REREVIEW-FIX-2.md
---

# Phase 19: Independent Code Re-Review

**Reviewed:** 2026-09-21T09:27:41Z  
**Depth:** deep  
**Files Reviewed:** 34  
**Status:** resolved after review-fix iteration 2

## Summary

The 11 prior findings are fixed in their original fixture, test, and fail-closed controller paths. Fresh focused suites pass (85 tests, 739 assertions), and production still reports `human_needed / no_accepted_club_history / blocked`. That blocked state is correct and is not counted as a defect.

The re-review found five production-authority blockers and two warnings. All seven findings are addressed in the seven atomic review-fix commits listed in `19-REREVIEW-FIX-2.md`. The production path remains fail-closed without genuine accepted Phase 18/19 evidence. The aggregate verifier reached the six changed Phase 19 contract suites successfully, then stopped at the pre-existing/slow pipeline target regression; it did not establish a full aggregate-gate pass.

## Review-Fix Iteration 2

| Finding | Status | Fix commit | Evidence |
|---|---|---|---|
| CR-01 | Fixed | `203d80d` | Canonical accepted Phase 18 UCL roster is byte-compared and hashed into current-snapshot identity; domain suite 10/105 and roster mutation probe pass. |
| CR-02 | Fixed | `c05e2d0` | Rating replay digest binds parameters, cutoff, predictions, batches, state, and audit; accepted snapshots are replayed before fit/evaluation; rating suite 11/65 and forged-prediction probe pass. |
| CR-03 | Fixed | `56c6ff1` | Every production source fold is exact-matched to the accepted registry row and protocol object; evaluation suite 11/69 and forged-row/protocol probes pass. |
| CR-04 | Fixed | `190f8b8` | Goal predictions, calibration inputs, calibrators, views, evidence, and decisions are regenerated from typed parents; goal suite 10/94 and calibration suite 10/102 pass. |
| CR-05 | Fixed | `f4c0a1f` | Production install requires the complete typed source-backed parent graph, production eligibility, and accepted authority; release installer missing-graph attack passes. |
| WR-01 | Fixed | `81b08ba` | Production training snapshots now compare every accepted manifest identity field, including corpus, source-manifest, match hash, and row count; domain suite 10/105 passes. |
| WR-02 | Fixed | `f4c0a1f`, `e5aef5a` | Generic preflight requires explicit authority mode and has explicit fixture/production wrappers; missing-mode and production-mode attacks pass. |

See `19-REREVIEW-FIX-2.md` for the complete commit and verification record.

## Prior Finding Verification

| Prior finding | Re-review result |
|---|---|
| CR-01 | Resolved for fixture/production roots and selector separation; the generic production installer still has the new publication gap below. |
| CR-02 | Resolved for typed fixture publication and validator injection; production publication remains independently unsafe below. |
| CR-03 | Partially resolved: fixed Phase 18 pointers are re-read, but the accepted source roster is not compared with the snapshot rows (CR-01 below). |
| CR-04 | Resolved: nested model, coefficient, grid, and registration identities are recomputed. |
| CR-05 | Partially resolved: production folds are replayed from supplied source bundles, but those bundles are not tied to canonical folds, fits, or calibrators (CR-03/CR-04 below). |
| CR-06 | Resolved as a caller-asserted-boolean issue; the derived object is now typed and hashed. |
| CR-07 | Resolved: fixture evaluation uses the real goal/calibration APIs and is explicitly smoke-only/non-promotable. |
| WR-01..WR-04 | Resolved; the new boundary checks, zero-support failure, exact model-card projection, and runtime probes are present. |

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Production current-UCL validation accepts a caller-forged roster

**Classification:** BLOCKER  
**File:** `R/club/model_contract.R:743-819`

The production branch re-reads the fixed Phase 18 pointer, bundle, authority, and identity hashes, but never compares `snapshot$clubs` with `source_bundle$tables$clubs` (or with the source bundle's edition/table identity). Lines 808-818 only sort and hash the caller-supplied `snapshot$clubs`. The component audit consequently trusts that replacement roster.

I reproduced the defect in fixture mode using the same validator logic: a valid 36-club snapshot reduced to one row, with recomputed `roster_sha256` and `snapshot_sha256`, was accepted. The production branch has the same missing content comparison after its fixed-parent checks. This permits a reduced or altered roster to claim the accepted UCL bundle and changes coverage/component results.

**Fix:** Canonicalize and compare the snapshot roster byte-for-byte with the accepted Phase 18 `clubs` table, validate the source row hashes/schema and `edition_id`, and bind the source table hash into the snapshot identity. Apply the equivalent candidate-table comparison in fixture mode.

### CR-02: Rating replay evidence is metadata-checked, not replay-checked

**Classification:** BLOCKER  
**Files:** `R/club/goal_model.R:148-181`; `R/club/rating.R:744-760,837-876`; `R/club/evaluation.R:1162-1199`

`phase19_club_goal_validate_rating_evidence()` checks the replay class, status, authority strings, parent snapshot hash, and required prediction columns, but does not recompute the predictions or validate a replay-output identity. `phase19_club_validate_production_sources()` repeats the same metadata/component checks. `phase19_club_rating_replay_result()` does not carry a digest that binds the prediction table and final state to the deterministic replay.

In a focused probe, adding `1` to one replay `rating_difference` left the replay accepted and produced a different valid `club_elo_nb` fit. An attacker can therefore choose rating features while preserving all advertised parent hashes.

**Fix:** Store a canonical replay digest over parameters, cutoff, prediction rows, batch/state hashes, and component audit; re-run `phase19_replay_club_ratings()` from the accepted snapshots and compare the complete output before fitting or accepting production evidence.

### CR-03: Production source evidence can use a forged fold with the right ID

**Classification:** BLOCKER  
**Files:** `R/club/evaluation.R:740-774,1162-1212`

`phase19_validate_club_fold_source_evidence()` checks only that the supplied fold has the same `fold_id` as the evaluation and that its protocol is a protocol-class object. `phase19_club_evaluation_source_by_fold()` checks set equality of list names. Neither compares the supplied fold row to the accepted `fold_protocol$fold_registry` row or requires the supplied protocol object to be the exact accepted protocol. The production source validator only checks that evaluated IDs equal registered IDs.

Thus a caller can submit a new self-hashed fold with the same ID but different declared fixtures, cutoff, held-out competition, or protocol details, then recompute the fold evaluation and pass source replay. That changes the assessment denominator and temporal boundary while retaining the registered fold name.

**Fix:** Resolve every source fold from the accepted registry and require exact row/hash equality, exact protocol identity, unique one-to-one source names, and equality of the source protocol object to the validated production protocol before scoring.

### CR-04: Fold scoring accepts probability/calibrator objects unrelated to the fitted artifacts

**Classification:** BLOCKER  
**Files:** `R/club/evaluation.R:196-230,379-430,740-757`; `R/club/goal_model.R:943-1049`; `R/club/calibration.R:455-530`

The source-replay fix re-scores the prediction objects supplied in `source_evidence`, but it never regenerates those objects from the referenced fit and calibrator. `phase19_club_evaluation_support()` treats calibrator, calibration-evidence, and decision hashes as opaque strings and only matches the advertised fit hash. `phase19_validate_club_goal_predictions()` checks internal grid/market arithmetic, not that the grid is the output of the fit. `phase19_validate_club_calibrator()` checks a self-hash and optimizer fields, not the source rows that produced the temperature; those rows are not retained in the durable calibrator.

A producer can therefore construct valid-looking probability grids and a fitted-temperature record, rehash them, and have exact-source fold scoring compute promotion metrics from those forged values. This is the remaining source-binding gap behind the partial CR-05 result.

**Fix:** Persist typed source rows/views and deterministically regenerate predictions with the exact fit, then regenerate the calibrated view with the exact calibrator and compare all rows, grids, and parent identities. Do not accept opaque support hashes as substitutes for those artifacts.

### CR-05: The production installer publishes self-described bundles without source-backed authority

**Classification:** BLOCKER  
**Files:** `R/club/release.R:814-937,971-1021,1158-1210`; `R/club/goal_model.R:608-645`; `R/club/calibration.R:455-530`

`phase19_install_production_club_release()` accepts any staged directory under the fixed production root. Its preflight validates inventory, file hashes, and contract strings, then its full readback validates only the model/calibrator self-identities plus model IDs and authority-mode strings. It never calls `phase19_stage_production_club_release()`, requires no typed history/current/protocol/evaluation/authority/replay parents, and does not require `model$production_eligible` or `calibrator$production_eligible`. The goal/calibrator validators allow their source-parent fields to be changed and rehashed.

Consequently, a caller able to construct a self-consistent production contract/RDS bundle can create a production generation and selector without source-backed Phase 18 evidence or an accepted promotion decision. The current controller's missing-history block prevents the normal path today, but it does not secure this public publication API for the expected future production state.

**Fix:** Make production installation accept only a source-backed staged-release object, or have it require and validate the complete typed parent graph (fixed snapshots, replay, accepted protocol/folds, evaluation source evidence, integrity, and decision) before any rename. Require production eligibility on both model and calibrator and reject fixture-derived or relabeled objects.

## Warnings

### WR-01: Production training snapshot leaves manifest identity fields unbound

**Classification:** WARNING  
**File:** `R/club/model_contract.R:445-466,474-500`

The fixed-root production check compares pointer/generation, corpus-manifest hash, club registry, cutoff, and recomputed match content, but does not compare the snapshot's `corpus_id`, `matches_sha256`, or `source_manifest_sha256` with the accepted Phase 18 manifest. The generic validator only checks that those fields look like SHA-256 values. A stale or forged source-manifest label can therefore travel into downstream model/release metadata while the match table remains unchanged.

**Fix:** Compare every manifest-derived identity field, including corpus ID, source-manifest hash, matches hash, and row count, against the fixed accepted generation before accepting the snapshot.

### WR-02: Generic release preflight always defaults to fixture authority

**Classification:** WARNING  
**File:** `R/club/release.R:1140-1147`

`preflight_phase19_club_release()` calls `phase19_validate_club_release()` without `expected_authority_mode`; `match.arg(c("fixture", "production"))` therefore selects `fixture`. A valid production release fails this public preflight with a fixture-authority error, encouraging callers to skip the preflight or call a lower-level validator.

**Fix:** Require an explicit `authority_mode` argument, or provide separate fixture and production preflight wrappers with unambiguous defaults.

## Verification

Fresh focused suites passed in new R processes: adversarial 13/71, release 9/36, goal model 9/90, rating 11/62, evaluation 10/66, calibration 9/98, domain 9/104, folds 9/102, and protocol 6/110. No product source files were modified. The only working-tree changes remain unrelated pre-existing user files; this re-review document is intentionally uncommitted.

---

_Reviewed: 2026-09-21T09:27:41Z_  
_Reviewer: the agent (gsd-code-reviewer)_  
_Depth: deep_
