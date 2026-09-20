---
phase: 19-independent-club-forecast-authority
plan: "06"
subsystem: club-calibration
tags: [temperature-calibration, nested-oof, canonical-v2, fixed-bins, proper-scores, fail-closed]

requires:
  - phase: 19-04
    provides: Frozen rolling-origin and held-out transport folds with exact calibration inventories
  - phase: 19-05
    provides: Club-only raw 1X2 forecasts and immutable G=40 distribution identities
provides:
  - Deterministic prior-only club temperature calibrators for all four frozen candidate roles
  - Distribution-preserving raw and calibrated 1X2 views
  - Exact paired score and fixed-bin calibration evidence
  - Frozen-veto primary-view decisions with canonical replay identity
affects: [19-07, 19-08, 19-09, 19-10, phase-20]

tech-stack:
  added: []
  patterns: [nested prior-only calibration, explicit non-authoritative failure evidence, immutable source-grid carry-through, deterministic gate decisions]

key-files:
  created:
    - R/club/calibration.R
    - tests/testthat/test_phase19_club_calibration.R
  modified: []

key-decisions:
  - "A failed fit is an audit-only `failed` calibrator with a canonical hash of the rejected input; it never silently falls back to promotable raw authority."
  - "Temperature calibration transforms only derived 1X2 probabilities; every source distribution hash and non-1X2 market is carried through byte-identically."
  - "Primary calibrated view selection evaluates the frozen RPS, Brier, log-loss, calibration, coverage, probability, distribution, and cutoff gates in registry order."
  - "Fixture calibrators and decisions may prove mechanics but remain permanently production-ineligible."

patterns-established:
  - "Calibrator identity binds candidate, recipe, seed, fold, cutoffs, support, optimizer result, source predictions, source grids, and protocol-review parents."
  - "Calibration evidence is regenerated from exact paired fixtures before a decision; forged summary improvement cannot become authority by reusing an old manifest hash."

requirements-completed: [CLUBMOD-02, CLUBMOD-03]

coverage:
  - id: D1
    description: "Strictly prior inner OOF evidence fits a deterministic bounded club calibrator while assessment, held-out, cutoff, source-hash, support, and optimizer attacks remain non-authoritative."
    requirement: CLUBMOD-02
    verification:
      - kind: unit
        ref: "tests/testthat/test_phase19_club_calibration.R#nested fit, four-role, leakage, source, support, optimizer, and identity tests"
        status: pass
      - kind: other
        ref: "rtk Rscript --vanilla scripts/run_phase19_focused_test.R tests/testthat/test_phase19_club_calibration.R"
        status: pass
    human_judgment: false
  - id: D2
    description: "Raw and calibrated evidence remains paired and immutable, and calibrated becomes primary only when every frozen score, calibration, coverage, and integrity veto passes."
    requirement: CLUBMOD-03
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase19_club_calibration.R#fixed-bin evidence, veto, forgery, and replay tests"
        status: pass
      - kind: other
        ref: "combined protocol/folds/goal-model/calibration regression: 31 tests, 398 assertions"
        status: pass
    human_judgment: false

duration: 22min
completed: 2026-09-20
status: complete
---

# Phase 19 Plan 06: Nested Club Calibration Authority Summary

**Prior-only club temperature calibration now preserves every goal-distribution byte while frozen proper-score and coverage vetoes control which 1X2 view may become primary.**

## Performance

- **Duration:** 22 min
- **Started:** 2026-09-20T18:40:10Z
- **Completed:** 2026-09-20T19:02:17Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Implemented a club-namespaced bounded temperature optimizer over exact nested inner OOF rows, with strict fold-role, dual-time cutoff, held-out competition, class-support, recipe, seed, source-prediction, and source-grid validation.
- Added closed `fitted|failed` calibrator evidence. Failed or insufficient fits retain canonical audit identity but cannot be applied or treated as promotion authority.
- Applied calibration only to the exact later assessment inventory while retaining raw probabilities, source distribution hashes, totals, BTTS, expected goals, likely scores, and all other non-1X2 values unchanged.
- Added exact paired RPS, multiclass Brier, log loss, and complete ten-bin one-vs-rest calibration evidence by fold, family, competition, and season.
- Implemented ordered primary-view decisions from the immutable gate registry; apparent calibration improvement cannot bypass proper-score, coverage, probability, distribution, or cutoff vetoes.
- Proved canonical calibrator/evidence/decision replay under row reorder and identity changes under outcome or parent drift.

## Task Commits

Each TDD gate was committed atomically:

1. **Task 19-06-01 RED: expose nested calibration authority attacks** - `f1d604e` (test)
2. **Task 19-06-01 GREEN: fit nested prior-only club calibrators** - `5029817` (feat)
3. **Task 19-06-02 RED: expose calibrated view gate bypasses** - `42f18ee` (test)
4. **Task 19-06-02 GREEN: gate calibrated club probability views** - `37b04a3` (feat)

## Files Created/Modified

- `R/club/calibration.R` - Source-row contracts, deterministic temperature fit, failure evidence, distribution-preserving application, paired scoring, fixed bins, gate evaluation, and decision identity.
- `tests/testthat/test_phase19_club_calibration.R` - Nested cutoff, held-out, support, optimizer, four-role, distribution integrity, exact pairing, gate-veto, forgery, reorder, and drift tests.

## Decisions Made

- Failed calibration does not produce a raw-fallback calibrator. Raw remains an independently retained view, while the failed object is explicit audit evidence only.
- The same calibration mechanism supports all four registered roles, but report-only candidates and every fixture artifact remain ineligible for production promotion.
- A goal-capable candidate must carry one valid source-grid hash per row; the non-goal uniform control must carry none. Calibration cannot manufacture distribution authority.
- Empty fixed bins remain explicit rows in the predeclared ten-bin inventory, preventing data-dependent bin creation or omission.
- Gate failures use the immutable registry's reason codes and order, making the primary-view decision a pure replayable function of exact paired evidence.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Loaded the fold validator's history-logical dependency in the focused test harness**
- **Found during:** Task 19-06-01 GREEN
- **Issue:** `phase19_validate_fold_role_evidence()` correctly delegates `counts_for_model` parsing to `phase18_history_logical()`, but the new focused test loader initially omitted that transitive module.
- **Fix:** Added `R/club/history_contract.R` to the focused loader and made the calibration module fail closed when that dependency is absent.
- **Files modified:** `tests/testthat/test_phase19_club_calibration.R`, `R/club/calibration.R`
- **Verification:** Task 1 focused gate passed 4 tests / 65 assertions; final combined gate passed.
- **Commit:** `5029817`

**Total deviations:** 1 auto-fixed blocking dependency. **Impact:** Loader completeness only; calibration semantics and scope are unchanged.

## Issues Encountered

- The combined fold-authority regression is intentionally slower because it materializes and validates immutable fixture generations. The same live process completed successfully; it was not restarted or bypassed.
- Unrelated modified raw martj42 data and existing untracked debug/output artifacts were preserved and never staged.

## TDD Gate Compliance

- Task 19-06-01: RED `f1d604e` failed on the missing club calibration module, then GREEN `5029817` passed 4 tests / 65 assertions. The tracer feedback rerun passed before Task 2 began.
- Task 19-06-02: RED `42f18ee` failed on the absent comparison/gate APIs, then GREEN `37b04a3` passed the complete 8 tests / 97 assertions.
- Combined strict regression passed protocol 6/110, folds 9/102, goal model 8/89, and calibration 8/97: 31 tests / 398 assertions with zero failures, errors, warnings, or skips.
- `rtk git diff --check` passed.

## Known Stubs

None. Empty pre-hash fields exist only transiently before canonical hashes are assigned, and blank failure reasons are allowed only on fitted authority. Production eligibility remains truthfully false for fixture mechanics.

## User Setup Required

None for fixture-backed mechanics. Production calibration remains fail-closed until genuine accepted club history, current-UCL source/identity authority, and accepted policy/fold reviews exist; this plan created no credentials or owner approval.

## Next Phase Readiness

- Plan 19-07 can consume fitted calibrators, raw/calibrated assessment views, fixed-bin evidence, and canonical primary-view decisions in complete fold evaluation.
- Plan 19-08 can bind the chosen primary view and calibrator bytes into an immutable club release contract.
- Production remains intentionally blocked under the existing source and review gates; fixture evidence cannot be promoted.

## Self-Check: PASSED

- Both implementation/test artifacts and this summary exist.
- TDD commits `f1d604e`, `5029817`, `42f18ee`, and `37b04a3` exist in repository history.
- Focused, combined upstream, adversarial, replay, distribution-integrity, and diff-hygiene checks pass.

---
*Phase: 19-independent-club-forecast-authority*
*Completed: 2026-09-20*
