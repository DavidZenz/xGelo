---
phase: 19-independent-club-forecast-authority
plan: "05"
subsystem: club-goal-model
tags: [r, negative-binomial, canonical-v2, score-grid, strict-cutoff, fail-closed]

requires:
  - phase: 19-independent-club-forecast-authority
    plan: "02"
    provides: Immutable pre-boundary club rating evidence and canonical rating parents
  - phase: 19-independent-club-forecast-authority
    plan: "03"
    provides: Frozen four-role club candidate registry, feature contract, and protocol identity
provides:
  - Club-owned strict-cutoff negative-binomial incumbent and Elo candidate fits
  - Truthful uniform and expanding report-only controls
  - Complete deterministic G=40 score grids with grid-derived 1X2 and market projections
  - Exact fixture/cell coverage, unavailable-feature rejection, and fail-closed fit validation
affects: [19-06, 19-07, 19-08, 19-09, 19-10, phase-20, phase-21]

tech-stack:
  added: []
  patterns: [club-owned long-format NB, truncate-and-renormalize-once, canonical prediction manifests, exact declared coverage]

key-files:
  created:
    - R/club/goal_model.R
    - tests/testthat/test_phase19_club_goal_model.R
  modified: []

key-decisions:
  - "Both club_venue_nb and club_elo_nb use one long-format MASS::glm.nb fit over home/away team-goal rows; a failed or invalid fit has no alternate family or control fallback."
  - "Goal distributions use the frozen 0:40 support, retain omitted tail mass, and normalize the stored joint grid exactly once before every market is derived."
  - "Only club_venue_nb and club_elo_nb are promotion-comparable; expanding_1x2 keeps its empirical G=40 report while both empirical controls remain non-selectable."
  - "Typed-unavailable enrichment columns are rejected on training, rating, and fixture surfaces even when their supplied value is zero or missing."

patterns-established:
  - "Club goal fit identity binds candidate/protocol/feature/rating/snapshot/cutoff/training/coefficient/package parents through canonical-v2."
  - "Prediction validation recomputes exact fixture coverage, every 1,681-cell rectangle, simplex mass, grid-derived markets, and table hashes."

requirements-completed: [CLUBMOD-01, CLUBMOD-02, CLUBMOD-05]

coverage:
  - id: D1
    description: "Club venue and Elo negative-binomial models fit only completed club rows whose completion and evidence times are strictly before the exclusive cutoff."
    requirement: CLUBMOD-01
    verification:
      - kind: unit
        ref: "tests/testthat/test_phase19_club_goal_model.R#strict cutoff, domain, rating, convergence, theta, and fallback tests"
        status: pass
      - kind: other
        ref: "rtk Rscript --vanilla scripts/run_phase19_focused_test.R tests/testthat/test_phase19_club_goal_model.R"
        status: pass
    human_judgment: false
  - id: D2
    description: "Every goal-capable prediction exactly covers declared fixtures with 1,681 normalized cells and grid-derived 1X2, totals, BTTS, expected-goal, and likely-score values."
    requirement: CLUBMOD-02
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase19_club_goal_model.R#G=40 grid, exact inventory, reorder, and market recomputation tests"
        status: pass
      - kind: other
        ref: "combined Phase 19 authority/rating/protocol/goal regression: 33 tests, 360 assertions"
        status: pass
    human_judgment: false
  - id: D3
    description: "Unavailable current xG, injury, lineup, suspension, and player fields cannot enter a fit or prediction and are never imputed."
    requirement: CLUBMOD-05
    verification:
      - kind: adversarial
        ref: "tests/testthat/test_phase19_club_goal_model.R#unavailable enrichment value and formula-drift tests"
        status: pass
      - kind: other
        ref: "rtk git diff --check"
        status: pass
    human_judgment: false

duration: 25min
completed: 2026-09-20
status: complete
---

# Phase 19 Plan 05: Club Goal Model Authority Summary

**Strict prior-only club NB fits now produce canonical complete G=40 forecasts, while registered controls, unavailable features, failed fits, and fixture authority remain explicitly non-promotable.**

## Performance

- **Duration:** 25 min
- **Started:** 2026-09-20T18:13:01Z
- **Completed:** 2026-09-20T18:38:22Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Implemented club-owned `club_venue_nb` and `club_elo_nb` fits over canonical, completed, dual-time-strict history rows with immutable pre-result rating evidence and no Poisson/model/control fallback.
- Added deterministic `0:40 x 0:40` joint distributions, one documented tail normalization, and 1X2, over-2.5, BTTS, expected-goal, and likely-score values derived only from each stored grid.
- Dispatched all four frozen roles with truthful capabilities: exact-third report-only control, expanding empirical grid report, venue incumbent, and Elo candidate.
- Bound fits and prediction sets to canonical-v2 snapshot, rating, protocol, feature, cutoff, training-row, coefficient, fixture, distribution, and package identities.
- Enforced exact declared fixture coverage, 1,681 cells per goal-capable fixture, byte-stable ordering, fit-object integrity, and total rejection of unavailable enrichment columns.

## Task Commits

Each TDD gate was committed atomically:

1. **Task 19-05-01 RED: expose club goal authority boundary** - `f85e8cc` (test)
2. **Task 19-05-01 GREEN: implement strict club goal tracer** - `add5585` (feat)
3. **Task 19-05-02 RED: expose control and feature attacks** - `5965094` (test)
4. **Task 19-05-02 GREEN: enforce registered capabilities** - `7b08dc0` (feat)

## Files Created/Modified

- `R/club/goal_model.R` - Strict-cutoff fitting, four-role dispatch, fail-closed NB adapter, G=40 prediction, provenance hashing, and exact validation.
- `tests/testthat/test_phase19_club_goal_model.R` - Cutoff, same-batch, convergence, theta, feature, domain, capability, coverage, mass, market, reorder, and fallback tests.

## Decisions Made

- Home and away observations are represented as signed team-goal rows in one club-owned NB model, matching the frozen candidate formulas without importing national model metadata.
- Raw support outside `0:40` is retained as `raw_tail_mass`; stored cells are normalized once and become the sole source for all downstream probabilities.
- The expanding control truthfully supplies an empirical full score grid but remains report-only; release selection admits only the venue incumbent and Elo candidate.
- Unavailable enrichment names are forbidden columns at every model boundary. Absence is not converted to zero, and zero is not accepted as absence.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Tolerated harmless NB floating-point mass overshoot before normalization**
- **Found during:** Task 19-05-02 RED for `club_venue_nb`
- **Issue:** Very large finite theta can make the independently computed truncated marginal product exceed one by machine-rounding noise, causing a valid venue fit to be rejected before the documented normalization step.
- **Fix:** Retained fail-closed checks for non-finite/non-positive/materially-over-one mass, allowed only a `1e-8` numerical envelope, clamped reported omitted mass at zero, and still normalized the grid exactly once.
- **Files modified:** `R/club/goal_model.R`
- **Verification:** All four roles dispatch; 8 focused tests / 89 assertions pass without warnings.
- **Commit:** `7b08dc0`

**Total deviations:** 1 auto-fixed bug. **Impact:** Numerical robustness only; model family, fit identity, support, and probability authority are unchanged.

## Issues Encountered

- Plan 19-04 committed fold/protocol files concurrently in the shared checkout. This plan staged only its owned goal-model source, test, summary, and state files; all Plan 19-04 and unrelated user artifacts were preserved.

## TDD Gate Compliance

- Task 19-05-01: RED `f85e8cc` precedes GREEN `add5585`; post-commit tracer gate passed 4 tests / 46 assertions.
- Task 19-05-02: RED `5965094` precedes GREEN `7b08dc0`; final focused gate passed 8 tests / 89 assertions.
- Combined authority/rating/protocol/goal regression passed 33 tests / 360 assertions with zero failures, errors, warnings, or skips.
- `rtk git diff --check` passed.

## Known Stubs

None. Empty pre-hash fields are populated before return, empty dropped-feature evidence truthfully records that frozen required predictors cannot be dropped, and report-only controls use explicit non-goal capability/status rather than placeholder grids.

## User Setup Required

None for fixture mechanics. Production remains fail-closed under the existing Phase 18 source/identity and Phase 19 owner-review requirements; this plan did not invent credentials, accepted evidence, or promotion authority.

## Next Phase Readiness

- Plan 19-06 can calibrate the raw grid-derived 1X2 view while preserving `distribution_sha256` and all non-1X2 markets.
- Plan 19-07 can pair the two promotion-comparable models on exact fixture IDs, support, and canonical prediction/distribution identities.
- Fixture fits remain visibly non-promotable. A production fit still requires genuine accepted history/current-UCL evidence and accepted protocol/fold reviews.

## Self-Check: PASSED

- Both implementation/test artifacts and this summary exist.
- TDD commits `f85e8cc`, `add5585`, `5965094`, and `7b08dc0` exist in repository history.
- Focused, combined, adversarial, canonical reorder, and diff-hygiene verification all pass.

---
*Phase: 19-independent-club-forecast-authority*
*Completed: 2026-09-20*
