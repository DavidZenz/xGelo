---
phase: 19-independent-club-forecast-authority
plan: "07"
subsystem: club-evaluation-promotion
tags: [paired-evaluation, proper-scores, calibration, bootstrap, promotion-gates, fail-closed]

requires:
  - phase: 19-02
    provides: Accepted/fixture club source authority contracts
  - phase: 19-04
    provides: Frozen owner-reviewed fold protocol and exact role inventories
  - phase: 19-05
    provides: Club candidate and incumbent goal-distribution forecasts
  - phase: 19-06
    provides: Raw/calibrated probability views and fixed-bin evidence
provides:
  - Exact paired fold scoring over the common frozen G=40 support
  - Equal-fold family aggregation and deterministic 10,000-replicate paired bootstrap
  - Ordered immutable promotion gates with complete evidence and reason codes
  - Separate diagnostic, authority-eligibility, and promotion-status vocabulary
  - Source-validated production authority and permanently ineligible fixture authority
affects: [19-08, 19-09, 19-10, phase-20, phase-21]

tech-stack:
  added: []
  patterns: [exact paired scoring, equal-fold aggregation, source-object authority projection, fail-closed promotion]

key-files:
  created:
    - R/club/evaluation.R
    - tests/testthat/test_phase19_club_evaluation.R
  modified: []

key-decisions:
  - "Fixture mechanics may pass every diagnostic gate but always emit authority_eligibility=fixture_ineligible and promotion_status=ineligible_fixture."
  - "Production authority is reconstructed from validated accepted history, current-UCL, fold-review, and rating-component source objects; hashes alone cannot grant promotion authority."
  - "Candidate and incumbent remain paired on identical declared fixtures and full G=40 score support before any aggregate is computed."
  - "Gate evaluation follows immutable registry order and retains or blocks the incumbent unless every applicable required gate passes."

patterns-established:
  - "Fold evidence carries complete predictions, distributions, proper scores, fixed bins, coverage, convergence, cutoff, feature, and provenance tables with canonical identities."
  - "Production eligibility is an exact projection of validated upstream objects, never a caller-provided boolean or relabeled fixture hash."

requirements-completed: [CLUBMOD-02, CLUBMOD-03]

coverage:
  - id: D1
    description: "Both frozen fold families are scored on complete paired fixture and grid evidence with leakage, cutoff, coverage, and parent attacks rejected."
    requirement: CLUBMOD-02
    verification:
      - kind: unit
        ref: "tests/testthat/test_phase19_club_evaluation.R#paired fold scoring and aggregation attacks"
        status: pass
      - kind: other
        ref: "final evaluation gate: 8 tests, 63 assertions"
        status: pass
    human_judgment: false
  - id: D2
    description: "Promotion is a reproducible ordered decision over proper scores, calibration, breadth, coverage, reproducibility, integrity, and genuine source authority."
    requirement: CLUBMOD-03
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase19_club_evaluation.R#thresholds, replay, fixture vocabulary, production forgery"
        status: pass
      - kind: other
        ref: "combined evaluation/folds/goal-model/calibration gate: 33 tests, 351 assertions"
        status: pass
    human_judgment: false

duration: 74min
completed: 2026-09-20
status: complete
---

# Phase 19 Plan 07: Independent Club Evaluation and Promotion Authority Summary

**Complete paired club evaluation now produces reproducible proper-score evidence and an ordered promotion decision that cannot confuse diagnostic success with production authority.**

## Performance

- **Duration:** 74 min
- **Started:** 2026-09-20T19:03:38Z
- **Completed:** 2026-09-20T20:17:22Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Implemented exact candidate/incumbent fold scoring on the same declared fixture set and full G=40 score grid, including RPS, multiclass Brier, log loss, scoreline/goal/market evidence, fixed calibration bins, convergence, coverage, cutoffs, features, and provenance.
- Aggregated folds equally within the two frozen families and persisted fold, family, league-season, paired-bootstrap, integrity, and reproducibility identities.
- Applied all immutable promotion gates in registry order with exact comparator boundaries, applicability, values, thresholds, pass states, and stable failure reasons.
- Separated `diagnostic_gate_outcome`, `authority_eligibility`, and `promotion_status`; a gate-complete fixture remains explicitly `pass / fixture_ineligible / ineligible_fixture`.
- Closed a production-authority elevation path by requiring validated accepted history, current-UCL roster, owner-reviewed fold protocol, and connected rating replay source objects rather than trusting relabeled/self-hashed fixture metadata.

## Task Commits

Each TDD gate was committed atomically:

1. **Task 19-07-01 RED: expose paired club evaluation attacks** - `c8cbd64` (test)
2. **Task 19-07-01 GREEN: score exact paired club folds** - `823e6f0` (feat)
3. **Task 19-07-02 RED: expose promotion authority confusion** - `cdb2cc0` (test)
4. **Task 19-07-02 security RED: reject forged production authority** - `549674d` (test)
5. **Task 19-07-02 GREEN: enforce club promotion authority** - `5b03ce2` (feat)

## Files Created/Modified

- `R/club/evaluation.R` - Fold validation/scoring, canonical evidence, family aggregation, paired bootstrap, ordered gates, reproducibility, authority projection, decision identity, and validation.
- `tests/testthat/test_phase19_club_evaluation.R` - Exact coverage/grid/cutoff/leakage, aggregation, threshold, replay, vocabulary, parent-drift, and forged-authority tests.

## Decisions Made

- Proper-score comparison is performed only after exact fixture and grid equality is established; missing or surplus rows fail the fold and never alter denominators.
- Equal-fold family summaries are promotion evidence; fixture-weighted league/season summaries remain secondary diagnostics.
- Production-only roster/component gates are not required for fixture diagnostics, but fixture authority remains permanently non-promotable regardless of gate outcome.
- A production decision can be `promoted` only through `phase19_production_evaluation_authority()`, which reruns upstream source validators and exact parent/fold/component checks.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected the canonical table hash argument binding**
- **Found during:** Task 19-07-01 GREEN
- **Issue:** A schema tag was initially passed positionally to `phase18_hash_table_v2()`, binding it as a different argument.
- **Fix:** Passed `schema_tag` by name and reran the tracer gate.
- **Files modified:** `R/club/evaluation.R`
- **Verification:** Task 1 passed 4 tests / 26 assertions twice, including the tracer feedback gate.
- **Commit:** `823e6f0`

**2. [Rule 3 - Blocking] Memoized complete canonical validation without weakening mutation checks**
- **Found during:** Task 19-07-02 GREEN
- **Issue:** Revalidating six embedded 6,724-row fold artifacts for every assertion made the focused suite pathologically slow.
- **Fix:** Added serialization-keyed in-process validation memoization. The first observation performs every canonical/source check; any byte mutation changes the key and forces full revalidation.
- **Files modified:** `R/club/evaluation.R`
- **Verification:** Final evaluation gate completed with all mutation/forgery tests passing.
- **Commit:** `5b03ce2`

**3. [Rule 2 - Missing Critical Functionality] Bound production authority to genuine source objects**
- **Found during:** Final threat-model audit
- **Issue:** A caller could relabel and rehash fixture authority fields as production-ready because scalar parent hashes were not independently backed by accepted source objects.
- **Fix:** Added an adversarial RED test and a source-validating production constructor that reruns history, current-UCL, policy, fold-review, exact fold inventory, and connected-component checks.
- **Files modified:** `R/club/evaluation.R`, `tests/testthat/test_phase19_club_evaluation.R`
- **Verification:** The attack failed before the fix, passed after it, and the final combined gate remained green.
- **Commits:** `549674d`, `5b03ce2`

**Total deviations:** 3 auto-fixed correctness/blocking issues. **Impact:** Stronger fail-closed authority and practical validation runtime; the frozen evaluation and gate policy did not change.

## Issues Encountered

- The first complete Task 2 run was interrupted after more than twelve minutes while repeatedly rehashing identical embedded evidence. The optimized run completed successfully without reducing coverage.
- Unrelated modified raw martj42 data and existing untracked debug/output artifacts were preserved and never staged.

## TDD Gate Compliance

- Task 19-07-01: RED `c8cbd64`, GREEN `823e6f0`; tracer gate passed 4 tests / 26 assertions.
- Task 19-07-02: RED `cdb2cc0`, security RED `549674d`, GREEN `5b03ce2`.
- Final focused/upstream gate passed evaluation 8/63, folds 9/102, goal model 8/89, and calibration 8/97: 33 tests / 351 assertions, zero failures.
- `rtk git diff --check` passed.

## Known Stubs

None. Production remains non-promotable because the repository truthfully lacks genuine accepted Phase 18 history/current-UCL and owner policy/fold review authority, not because an implementation surface is stubbed.

## User Setup Required

Production promotion requires genuine accepted Phase 18 club history and current-UCL/identity snapshots plus accepted owner policy and fold reviews. Fixture mechanics require no setup and remain diagnostic-only.

## Next Phase Readiness

- Plan 19-08 can consume the exact three-field decision vocabulary and fixture-only eligibility for release writing.
- Plans 19-09/10 can verify end-to-end provenance and production fail-closed behavior against the persisted gate table and source-backed authority graph.
- Current production remains intentionally blocked; no fixture or history-only evidence can emit `promotion_status=promoted`.

## Self-Check: PASSED

- Both implementation/test artifacts and this summary exist.
- TDD commits `c8cbd64`, `823e6f0`, `cdb2cc0`, `549674d`, and `5b03ce2` exist in repository history.
- Focused evaluation, upstream folds/goal-model/calibration, forged-authority, replay, and diff-hygiene checks pass.

---
*Phase: 19-independent-club-forecast-authority*
*Completed: 2026-09-20*
