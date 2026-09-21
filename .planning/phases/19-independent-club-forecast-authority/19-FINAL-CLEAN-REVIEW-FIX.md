---
phase: 19-independent-club-forecast-authority
fixed_at: 2026-09-21T15:33:54Z
review_path: .planning/phases/19-independent-club-forecast-authority/19-FINAL-CLEAN-REVIEW.md
iteration: 1
findings_in_scope: 1
fixed: 1
skipped: 0
status: all_fixed
---

# Phase 19: Final Clean Authority Review Fix Report

**Fixed at:** 2026-09-21T15:33:54Z  
**Source review:** `.planning/phases/19-independent-club-forecast-authority/19-FINAL-CLEAN-REVIEW.md`  
**Iteration:** 1

**Summary:**

- Findings in scope: 1
- Fixed: 1
- Skipped: 0

## Fixed Issues

### CR-01: Promotion accepts self-attested replay without requiring the fixed production wrapper

**Files modified:** `R/club/evaluation.R`, `R/club/release.R`, `scripts/run_phase19_club_evaluation.R`, `tests/testthat/test_phase19_club_evaluation.R`, `tests/testthat/test_phase19_adversarial_regression.R`

**Commit:** `5a25380`

**Applied fix:** Production promotion now ignores the caller-supplied replay object, binds promotion to a complete typed source graph, and invokes `phase19_production_club_reproducibility_evidence()` at the promotion boundary. The wrapper reloads the fixed production roots, validates the typed graph, performs two independent deep-copied complete fold evaluations, and checks both complete-output hashes against the accepted evaluation identity before metrics or decision hashes are derived. Direct production replay validation requires the private production-evidence class. The release boundary recomputes this controlled evidence, while fixture promotion retains the separate fixture-only replay API and remains permanently ineligible for production.

**Regression coverage:** Added a copied accepted-hash shell attack and a direct boundary test that stubs the fixed wrapper, proves it is called, and proves integrity, byte-reproducibility metrics, and the decision hash use the wrapper result rather than the caller shell.

**Checks:** All five affected R files parse and `git diff --check` passes. The targeted boundary assertion passed with 7 successes; the copied-hash class-gate assertion passed with 4 successes. The bounded evaluation, adversarial, and release suites had already passed before this resumed tightening (11 tests/70 assertions, 15 tests/76 assertions, and 9 tests/41 assertions respectively).

**Production fail-closed evidence:** A production call cannot manufacture replay authority from `replay`; it must supply the accepted typed graph or fail with `reproducibility_source_invalid`/upstream authority errors. The wrapper reloads the fixed committed roots and requires typed production authority, integrity, evaluation, fold, and rating-replay identities. With the repository's committed production roots still unavailable, production remains blocked and cannot publish; fixture evidence is still explicitly ineligible.

## Skipped Issues

None.

---

_Fixed: 2026-09-21T15:33:54Z_  
_Fixer: the agent (gsd-code-fixer)_  
_Iteration: 1_
