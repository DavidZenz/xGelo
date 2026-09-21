---
phase: 19-independent-club-forecast-authority
reviewed: 2026-09-21T15:42:52Z
reviewed_commit: ddcd2a5ddfccab976e13655ffb786808ef67b1af
focus_commit: 5a253806e30896c781e2e59c74f968ee4db394ed
repair_commits:
  - a28491d
  - 66b7b02
  - 86c8a8d
  - ef8b04e
  - b7faea7
  - a55ba02
blockers: 2
warnings: 0
test_evidence:
  external_orchestrator: "Protocol, evaluation, release, goal-model, calibration, and adversarial Phase 19 suites independently passed with zero failures after merge 4c42cfd; no aggregate or targets suites were rerun."
  local_spot_checks: "Parsed all five files changed by 5a25380 and ran git diff --check; both passed."
verdict: issues_found
---

# Phase 19: Final Clean Re-Review

**Reviewed:** `ddcd2a5ddfccab976e13655ffb786808ef67b1af`  
**Focus:** final replay-boundary fix `5a253806e30896c781e2e59c74f968ee4db394ed`  
**Verdict:** Issues found — 2 blockers, 0 warnings

## Scope and evidence

This bounded independent review traced the six integrated repair commits and the final replay-boundary fix through the production evaluation, promotion, release-parent, and adversarial-test call chains. The production promotion function now ignores its caller-supplied replay and invokes the fixed wrapper internally. The wrapper reloads committed history/current/policy/fold roots, validates typed evaluation and authority, deep-copies source folds for two complete scoring/aggregation runs, and compares both complete-output hashes with the accepted evaluation. Release model/calibrator support is regenerated from canonical evaluated fold artifacts and compared by exact identity. Fixture replay remains on a separate API and fixture authority remains ineligible.

The orchestrator's six bounded suites passed with zero failures after `4c42cfd`; production roots remain unavailable/blocked, so no credentials or fabricated production authority were used.

## Blockers

### CR-01: Explicit production source graphs can carry an alternate rating replay identity

**Files:** `R/club/evaluation.R:1621-1634,1562-1578`; `R/club/release.R:446-481`

**Issue:** When `production_source_authority` is supplied, `phase19_club_production_promotion_source_authority()` checks the graph's protocol, evaluation, authority, integrity, and fold-source identities, but never checks `rating_replay` against `authority$source_evidence$rating_replay` (or another accepted canonical rating identity). The production wrapper then validates the top-level replay by rerunning it with the caller-selected `parameters` and `cutoff_utc` (`R/club/rating.R:984-1039`), which proves only that it is a valid replay over fixed snapshots—not that it is the exact replay in the accepted authority graph. The release parent path repeats the same generic validation at lines 468-470 and also never performs this equality check.

A caller with a valid production graph can therefore replace only the top-level replay with another self-consistent registered-parameter/cutoff replay. The wrapper still publishes production reproducibility evidence, and the release parent validation proceeds, while the graph's advertised rating identity no longer matches the accepted authority source. This violates the required exact evaluation/authority/integrity/fold/rating binding and leaves a caller-supplied alternate at the publication boundary.

**Fix:** Require exact identity equality between `source_authority$rating_replay` and the accepted authority/source replay (including the complete replay digest, parameters, cutoff, state, predictions, and component audit) in the promotion graph helper and again in the release parent validator immediately before publication. Add an adversarial test that mutates only the top-level rating replay and recomputes its valid deterministic identity; it must fail.

### CR-02: The production replay validator has no unforgeable wrapper provenance

**Files:** `R/club/evaluation.R:1451-1503,2202-2244`

**Issue:** Production direct validation is gated only by the mutable R class string `phase19_club_production_reproducibility_evidence`. The evidence hash covers the scalar evidence fields, not the wrapper execution or source graph. Because the controller sources `R/club/evaluation.R` into `.GlobalEnv` (`scripts/run_phase19_club_evaluation.R:24-54`), a caller can either relabel a correctly self-hashed replay shell with that class or call the nominally non-exported `phase19_club_reproducibility_evidence_build(..., allow_production = TRUE)` directly with the accepted evaluation as both inputs. The builder validates the copied evaluation identities and emits the production class without executing two independent controlled evaluations; `phase19_club_validate_reproducibility()` then accepts that object after only schema, self-hash, seed, and accepted-output-hash checks. The new shell test covers only the ordinary class and therefore fails before the wrapper-provenance question; the wrapper-invocation test stubs the wrapper and does not exercise this direct validator path.

The promotion boundary is now protected because it regenerates `effective_replay` internally, but the mandatory direct-validator boundary still accepts a self-attested non-wrapper object. Any production code or future caller that relies on the validator rather than the promotion function can treat fabricated reproducibility as authoritative.

**Fix:** Do not make a mutable class tag the proof of wrapper execution. Keep production replay evidence in a private execution context with an unforgeable/opaque provenance token, or make the production validator itself invoke the fixed wrapper from the complete source graph and compare the returned complete evidence. Add a regression for a production-class relabeled shell and for direct use of the builder; both must be rejected.

## Warnings

None.

---

_Reviewed: 2026-09-21T15:42:52Z_  
_Reviewer: independent Phase 19 final rereviewer_  
_Reviewed commit: `ddcd2a5ddfccab976e13655ffb786808ef67b1af`_
