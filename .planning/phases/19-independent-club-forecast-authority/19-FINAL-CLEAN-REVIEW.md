---
phase: 19-independent-club-forecast-authority
reviewed: 2026-09-21T14:43:24Z
reviewed_commit: 4c42cfd5a64eff5af4677283c51b02292536866c
depth: deep
files_reviewed: 20
files_reviewed_list:
  - R/club/model_contract.R
  - R/club/evaluation_protocol.R
  - R/club/evaluation.R
  - R/club/goal_model.R
  - R/club/calibration.R
  - R/club/release.R
  - scripts/run_phase19_club_evaluation.R
  - tests/testthat/test_phase19_adversarial_regression.R
  - tests/testthat/test_phase19_club_evaluation.R
  - tests/testthat/test_phase19_club_protocol.R
  - tests/testthat/test_phase19_club_goal_model.R
  - tests/testthat/test_phase19_club_calibration.R
  - tests/testthat/test_phase19_club_release.R
  - .planning/phases/19-independent-club-forecast-authority/19-07-PLAN.md
  - .planning/phases/19-independent-club-forecast-authority/19-08-PLAN.md
  - .planning/phases/19-independent-club-forecast-authority/19-10-PLAN.md
  - .planning/phases/19-independent-club-forecast-authority/19-RESEARCH.md
  - .planning/phases/19-independent-club-forecast-authority/PATTERNS.md
  - .planning/phases/19-independent-club-forecast-authority/19-FINAL-REREVIEW.md
  - .planning/phases/19-independent-club-forecast-authority/19-FINAL-REREVIEW-FIX.md
repair_commits:
  - a28491d
  - 66b7b02
  - 86c8a8d
  - ef8b04e
  - b7faea7
  - a55ba02
blockers: 1
warnings: 0
test_evidence:
  external_orchestrator: "All six bounded Phase 19 suites passed after merge: protocol, evaluation, release, goal-model, calibration, and adversarial regression; no aggregate or targets suites were run."
  local_spot_checks: "Protocol 6 tests/112 assertions, goal-model 11 tests/95 assertions, and calibration 10 tests/103 assertions passed; no additional long suites were rerun for this bounded audit."
verdict: issues_found
---

# Phase 19: Final Clean Authority Review

**Reviewed:** 2026-09-21T14:43:24Z  
**Commit:** `4c42cfd5a64eff5af4677283c51b02292536866c`  
**Verdict:** Issues found — 1 blocker, 0 warnings

## Summary

This independent bounded review traced the six repair commits through the production authority loaders, evaluation/release call chains, publication boundary, and adversarial tests. The fixed protocol/policy/fold roots and persisted pointer/generation/review graph are now enforced; release model/calibrator identities are regenerated from and compared with the canonical evaluated `model_support`; and the fixed replay wrapper itself performs two deep-copied complete scoring/aggregation passes with typed source validation and complete-output hashing. Fixture authority remains explicitly ineligible.

The review is not clean because the production promotion boundary still accepts a caller-supplied reproducibility object without requiring that the fixed production wrapper produced it. A caller can construct a correctly typed, self-hashed replay whose two hashes equal the accepted complete evaluation hash, and promotion accepts it without two controlled executions.

## Mandatory Authority Answers

1. **Protocol/policy/fold authority:** Pass. `phase19_load_fixed_club_production_authority()` reloads committed history/current/policy/fold roots; production validators require exact object identity, and `phase19_assert_production_fold_protocol()` checks pointer, generation, state, accepted review, and fold-registry links. `phase19_install_club_release()` repeats the complete parent-graph validation immediately before selector publication.
2. **Release artifact binding:** Pass. `phase19_club_release_validate_evaluated_model_support()` regenerates canonical fold source artifacts and requires exact model, calibrator, fit, calibrator, calibration-evidence, and calibration-decision identities from the accepted support row. The parent graph then validates authority, integrity, decision, and production parent hashes before both installation and selector write.
3. **Production reproducibility enforcement:** Fail. The wrapper performs the required fixed-source two-run replay, but no production caller invokes it. The promotion API receives `replay` as an argument and only validates its shape, self-hash, seed, `reproducible` flag, and two caller-supplied hashes against the accepted complete-output hash.

## Test Evidence

The orchestrator independently reported zero failures for the six bounded suites listed in the frontmatter. The local spot checks above also passed. The committed production root remains blocked in the expected no-accepted-authority state; no credentials or fabricated authority were used.

## Blockers

### CR-01: Promotion accepts self-attested replay without requiring the fixed production wrapper

**File:** `R/club/evaluation.R:2128-2162,2223-2237`; `scripts/run_phase19_club_evaluation.R:521-526`

**Issue:** `phase19_production_club_reproducibility_evidence()` correctly reloads the fixed source graph, deep-copies fold source evidence twice, executes `phase19_score_club_fold()` and aggregation twice, and builds evidence from complete typed output hashes (`R/club/evaluation.R:1542-1585`). However, `rtk rg` finds no production call site for that wrapper. The public `phase19_evaluate_club_promotion()` instead accepts `replay` from its caller and calls `phase19_club_validate_reproducibility()`. In production that validator revalidates the accepted evaluation, computes its complete hash, and compares it to `replay$first_evaluation_sha256` and `replay$second_evaluation_sha256`, but never invokes or binds the replay to the fixed wrapper. Since `phase19_club_evaluation_complete_output_sha256()` and `phase19_club_reproducibility_sha256()` are callable, a caller with the accepted evaluation can construct a typed replay with the expected hash in both fields, set `reproducible = TRUE`, self-hash it, and pass this gate without two independent controlled evaluations. The byte-reproducibility metric is then derived directly from that caller-controlled flag at promotion.

**Fix:** Make the production promotion path accept the complete fixed source graph and invoke `phase19_production_club_reproducibility_evidence()` internally, or require a private execution result that the promotion boundary itself obtains and compares. Do not accept a caller-created replay object as production authority. Keep the fixture path on its separate non-promotable replay API.

## Warnings

None.

---

_Reviewed: 2026-09-21T14:43:24Z_  
_Reviewer: the agent (independent Phase 19 final clean reviewer)_  
_Depth: deep_
