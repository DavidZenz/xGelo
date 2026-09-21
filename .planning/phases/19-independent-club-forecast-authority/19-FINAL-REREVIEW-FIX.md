---
phase: 19
fixed_at: 2026-09-21T13:11:33Z
verified_at: 2026-09-21T13:55:00Z
review_path: .planning/phases/19-independent-club-forecast-authority/19-FINAL-REREVIEW.md
iteration: 1
findings_in_scope: 3
fixed: 3
skipped: 0
status: all_fixed
---

# Phase 19: Final Rereview Fix Report

**Fixed at:** 2026-09-21T13:11:33Z
**Source review:** `.planning/phases/19-independent-club-forecast-authority/19-FINAL-REREVIEW.md`
**Iteration:** 1

**Summary:**
- Findings in scope: 3
- Fixed: 3
- Skipped: 0

## Fixed Issues

### CR-01: Production protocol and fold authority is not anchored to the committed runtime root

**Files modified:** `R/club/evaluation_protocol.R`, `tests/testthat/test_phase19_club_protocol.R`
**Commits:** `a28491d`, `ef8b04e`
**Applied fix:** Production policy/fold authority now resolves through fixed loaders, rejects caller policy/fold/review objects, retains and validates the persisted protocol pointer/generation/state/review graph, and reruns the fixed-root parent validation immediately before selector publication. Fixture authority remains caller-backed and nonpromotable.

### CR-02: Production release accepts self-consistent but unevaluated model and calibrator objects

**Files modified:** `R/club/goal_model.R`, `R/club/release.R`, `tests/testthat/test_phase19_club_goal_model.R`, `tests/testthat/test_phase19_club_calibration.R`
**Commits:** `66b7b02`, `b7faea7`
**Applied fix:** Release-selectable fits are checked against the committed negative-binomial candidate contract. Production release validation deterministically regenerates the canonical selected fold artifacts and requires exact top-level model/calibrator equality plus fit, calibrator, calibration-evidence, and calibration-decision identities from evaluated `model_support`.

### CR-03: Byte reproducibility is self-attested rather than independently replayed

**Files modified:** `R/club/evaluation.R`, `tests/testthat/test_phase19_club_evaluation.R`, `tests/testthat/test_phase19_adversarial_regression.R`
**Commits:** `86c8a8d`, `a55ba02`
**Applied fix:** Hash-only evaluation shells are rejected. Complete typed evaluation output hashes are derived after full validation; production replay requires two independent deep-copied controlled evaluations from the fixed source graph and compares both hashes with the accepted evaluation identity. Fixture replay remains explicitly ineligible.

## Verification

All bounded focused suites passed after the complete six-commit repair series: protocol (6), evaluation (11), release (9), goal model (11), calibration (10), and adversarial regression (14) — 61 test cases total. No aggregate or targets runs were started. The production controller continues to report `status=human_needed` and `reason_code=fixture_ineligible` when accepted authority is unavailable, and protected selector/incumbent bytes were not changed.

---

_Fixed: 2026-09-21T13:11:33Z_
_Fixer: the agent (gsd-code-fixer)_
_Iteration: 1_
