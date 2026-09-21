---
phase: 19-independent-club-forecast-authority
fixed_at: 2026-09-21T16:08:18Z
review_path: .planning/phases/19-independent-club-forecast-authority/19-FINAL-CLEAN-REREVIEW.md
iteration: 1
findings_in_scope: 2
fixed: 2
skipped: 0
status: all_fixed
---

# Phase 19: Final Clean Re-Review Fix Report

**Fixed at:** 2026-09-21T16:08:18Z
**Source review:** `.planning/phases/19-independent-club-forecast-authority/19-FINAL-CLEAN-REREVIEW.md`
**Iteration:** 1

**Summary:**
- Findings in scope: 2
- Fixed: 2
- Skipped: 0

## Fixed Issues

### CR-01: Explicit production source graphs can carry an alternate rating replay identity

**Files modified:** `R/club/evaluation.R`, `R/club/release.R`, `tests/testthat/test_phase19_club_evaluation.R`
**Commit:** `d1acf0a`
**Applied fix:** Added exact whole-object identity checks between the top-level production rating replay and the accepted replay embedded in the authority source graph at promotion and wrapper boundaries, repeated the check immediately in the release parent validator, and added a deterministic alternate-parameter replay regression.

### CR-02: The production replay validator has no unforgeable wrapper provenance

**Files modified:** `R/club/evaluation.R`, `tests/testthat/test_phase19_club_evaluation.R`
**Commit:** `084541d`
**Applied fix:** Split scalar/schema/hash validation from production provenance, made production validation require the complete bound source graph and invoke the fixed wrapper itself, returned the internally regenerated replay to promotion/integrity paths, removed production authority minting from the builder (including `allow_production=TRUE`), and added relabeled-shell/direct-builder regressions.

## Verification

- `Rscript --vanilla -e 'invisible(parse(file="R/club/evaluation.R")); invisible(parse(file="R/club/release.R")); invisible(parse(file="tests/testthat/test_phase19_club_evaluation.R"))'`
- `git diff --check`
- Focused deterministic CR-01 rating replay assertion passed.
- Focused CR-02 relabeled-shell and production-builder boundary assertions passed.
- Focused test: `production source graphs reject a deterministic alternate rating replay` passed (2 assertions, 0 failures).

---

_Fixed: 2026-09-21T16:08:18Z_  
_Fixer: the agent (gsd-code-fixer)_  
_Iteration: 1_
