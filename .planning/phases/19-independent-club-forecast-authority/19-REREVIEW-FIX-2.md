---
phase: 19-independent-club-forecast-authority
fixed_at: 2026-09-21T11:58:00Z
review_path: .planning/phases/19-independent-club-forecast-authority/19-REREVIEW.md
iteration: 2
findings_in_scope: 7
fixed: 7
skipped: 0
status: all_fixed
---

# Phase 19: Independent Re-Review Fix Report

**Fixed at:** 2026-09-21T11:58:00Z  
**Source review:** `.planning/phases/19-independent-club-forecast-authority/19-REREVIEW.md`  
**Iteration:** 2

## Summary

All five blockers and both warnings from the independent Phase 19 re-review were fixed in atomic commits on `gsd-reviewfix/19-39543`. No finding was skipped. Production remains fail-closed unless the complete accepted Phase 18/19 authority graph is present; fixture artifacts cannot be promoted by relabeling or self-rehashing.

## Fixed findings

### CR-01: Production current-UCL validation accepts a caller-forged roster

**Status:** fixed  
**Commit:** `203d80d`  
**Files:** `R/club/model_contract.R`, `scripts/run_phase19_club_evaluation.R`, `tests/testthat/test_phase19_adversarial_regression.R`, `tests/testthat/test_phase19_club_domain_contract.R`, fixture test updates

The current snapshot now carries the accepted source-club-table hash. Production and fixture validators validate source schema/edition/hash and require byte equality of the current-UCL roster with the accepted Phase 18 clubs table before accepting component or snapshot identity. The adversarial roster mutation is rejected.

### CR-02: Rating replay evidence is metadata-checked, not replay-checked

**Status:** fixed  
**Commit:** `c05e2d0`  
**Files:** `R/club/rating.R`, `R/club/goal_model.R`, `R/club/evaluation.R`, rating and goal-model tests

Rating evidence now stores a deterministic replay digest over typed parameters, cutoff, accepted training/current snapshots, canonical prediction rows, batch/state hashes, final state, and component audit. Validation replays from accepted snapshots and compares the complete result before fitting or accepting production evidence; a forged rating prediction is rejected.

### CR-03: Production source evidence can use a forged fold with the right ID

**Status:** fixed  
**Commit:** `56c6ff1`  
**Files:** `R/club/evaluation.R`, `tests/testthat/test_phase19_club_evaluation.R`

Production fold source evidence now requires exact row/hash identity with the accepted fold registry and exact protocol-object identity, with unique one-to-one source names and complete registry coverage. Same-ID forged fold rows and protocols are rejected before scoring.

### CR-04: Fold scoring accepts probability/calibrator objects unrelated to fitted artifacts

**Status:** fixed  
**Commit:** `190f8b8`  
**Files:** `R/club/goal_model.R`, `R/club/calibration.R`, `R/club/evaluation.R`, goal-model and calibration tests

Typed fit fixtures, source rows, calibration inputs, calibrators, calibrated views, evidence, and decisions are retained and deterministically regenerated. Validators compare regenerated rows, grids, parent identities, hashes, and decisions rather than trusting opaque support hashes. Forged prediction/calibration source artifacts are rejected.

### CR-05: Production installer publishes self-described bundles without source-backed authority

**Status:** fixed  
**Commit:** `f4c0a1f`  
**Files:** `R/club/release.R`, `tests/testthat/test_phase19_club_release.R`

Production installation now requires the complete typed source-backed parent graph: accepted history/current snapshots, protocol/folds, deterministic rating replay, rich fold source evidence, authority, integrity, decision, typed model/calibrator, and production eligibility. The graph is validated before any production root, generation, lock, selector, or rename mutation; missing-graph installation is rejected.

### WR-01: Production training snapshot leaves manifest identity fields unbound

**Status:** fixed  
**Commit:** `81b08ba`  
**Files:** `R/club/model_contract.R`

Production training snapshot validation now compares the accepted manifest's corpus ID, matches hash, source-manifest hash, row count, and existing pointer/generation identities, in addition to exact match-table content.

### WR-02: Generic release preflight always defaults to fixture authority

**Status:** fixed  
**Commits:** `f4c0a1f`, `e5aef5a`  
**Files:** `R/club/release.R`, `tests/testthat/test_phase19_club_release.R`

The generic preflight requires an explicit `authority_mode`; dedicated fixture and production wrappers make the authority boundary explicit. Missing mode, fixture-as-production, and explicit production preflight attacks are covered.

## Verification evidence

Fresh focused suites already recorded on this branch:

- adversarial: 13 tests / 71 assertions
- calibration: 10 tests / 102 assertions
- domain contract: 10 tests / 105 assertions
- evaluation: 11 tests / 69 assertions
- folds: 9 tests / 102 assertions
- goal model: 10 tests / 94 assertions
- rating: 11 tests / 65 assertions
- release: passed after CR-05 and WR-02 changes

The aggregate command `Rscript --vanilla scripts/verify_phase19_contracts.R` passed the six suites through goal model, then failed at `test_phase19_club_pipeline.R`; it did not reach the later Phase 18/national/protected-byte stages. A bounded direct pipeline diagnostic reached three controller/fixture test groups with 4, 16, and 10 passing assertions before the long repeated fixture/target execution was intentionally stopped. No source or protected production bytes were changed, and `git status --short` is clean on the fix branch.

## Commits

`203d80d` (CR-01), `c05e2d0` (CR-02), `56c6ff1` (CR-03), `190f8b8` (CR-04), `f4c0a1f` (CR-05 and WR-02 implementation), `81b08ba` (WR-01), and `e5aef5a` (WR-02 adversarial test).

---

_Fixed: 2026-09-21T11:58:00Z_  
_Fixer: the agent (gsd-code-fixer)_  
_Iteration: 2_
