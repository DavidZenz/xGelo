---
phase: 19-independent-club-forecast-authority
plan: "04"
subsystem: evaluation
tags: [club-folds, rolling-origin, heldout-transport, canonical-v2, owner-review, atomic-publication]

requires:
  - phase: 19-01
    provides: accepted/fixture club training snapshots with immutable history identity
  - phase: 19-03
    provides: frozen club candidate, seed, gate, feature, and policy-review authority
provides:
  - Deterministic rolling-origin league-season and held-out-league transport fold inventories
  - Strict dual-time nested fit, tuning, calibration, and assessment boundaries
  - Canonical blocked/pending-review/ready fold protocol with self-hashed owner review
  - Fixture-only immutable generations plus atomic pointer publication
affects: [19-05, 19-06, 19-07, 19-08, 19-09, 19-10, phase-20]

tech-stack:
  added: []
  patterns: [exclusive dual-time cutoffs, frozen fixture-role inventories, immutable generation pointer, separate owner review]

key-files:
  created:
    - data/club/model_protocol/fold_registry.csv
    - data/club/model_protocol/protocol_state.json
    - data/club/model_protocol/calibration_recipe.json
    - data/club/model_protocol/fold_review.json
    - tests/testthat/test_phase19_club_folds.R
  modified:
    - R/club/evaluation_protocol.R

key-decisions:
  - "Every fold freezes disjoint exact fixture IDs for fit, calibration, and assessment; timestamps alone cannot silently redefine a role."
  - "Held-out competition exclusion is repeated explicitly for fit, tuning, and calibration and is validated against every selected row."
  - "Production remains blocked/no_accepted_club_history; automatic materialization can publish only pending_review, while a separately self-hashed accepted review is required for ready."
  - "Fixture fold generations live below marker-bound temporary roots and can become mechanically ready without ever becoming production eligible."

patterns-established:
  - "Fold identity: canonical-v2 row/table hashes bind snapshot, accepted generation, policy review, protocol, calibration recipe, and every exact fixture role."
  - "Publication boundary: complete immutable generation first, validate it, then atomically replace one self-hashed pointer."

requirements-completed: [CLUBMOD-02, CLUBMOD-03]

coverage:
  - id: D1
    description: "Two frozen club fold families enforce exact-batch exclusive cutoffs, nested prior-only roles, held-out transport isolation, and complete declared fixture coverage."
    requirement: CLUBMOD-02
    verification:
      - kind: unit
        ref: "tests/testthat/test_phase19_club_folds.R#fold families, role evidence, boundary attacks, and coverage tests"
        status: pass
      - kind: other
        ref: "rtk Rscript --vanilla scripts/run_phase19_focused_test.R tests/testthat/test_phase19_club_folds.R"
        status: pass
    human_judgment: false
  - id: D2
    description: "Canonical fold, recipe, state, and self-hashed review authority keeps production blocked until exact history, policy, and owner review exist."
    requirement: CLUBMOD-03
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase19_club_folds.R#blocked production and immutable fixture publication tests"
        status: pass
      - kind: other
        ref: "rtk Rscript --vanilla scripts/run_phase19_focused_test.R tests/testthat/test_phase19_club_protocol.R"
        status: pass
      - kind: other
        ref: "rtk git diff --check"
        status: pass
    human_judgment: false

duration: 25min
completed: 2026-09-20
status: complete
---

# Phase 19 Plan 04: Frozen Club Fold Authority Summary

**Canonical rolling-origin and held-out transport folds now freeze every prior-only role and require an exact self-hashed owner review before production evaluation can become ready.**

## Performance

- **Duration:** 25 min
- **Started:** 2026-09-20T18:12:53Z
- **Completed:** 2026-09-20T18:37:58Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Built both required fold families from one validated snapshot, with canonical declared assessment fixtures and disjoint exact fit/calibration fixture sets.
- Enforced strict `< cutoff` checks for completion time, evidence availability, and exact-kickoff/full-date batch boundaries; transport folds exclude their competition from fit, tuning, and calibration.
- Froze a club-only temperature recipe with bounds `0.25..4`, deterministic optimizer/seed identity, prior-only evidence role, support rules, and non-promotable failure behavior.
- Committed a truthful header-only production fold registry with `blocked/no_accepted_club_history` state and a pending review containing no invented reviewer, time, history, cutoff, or fold authority.
- Added immutable generation publication through one atomic self-hashed pointer. Fixture generations exercise pending and accepted review mechanics but remain permanently production-ineligible.
- Final focused verification passed 9 tests and 102 assertions; the upstream protocol regression passed 6 tests and 110 assertions.

## Task Commits

1. **Task 19-04-01 RED: expose fold boundary attacks** - `20b1064` (test)
2. **Task 19-04-01 GREEN: freeze leakage-safe club folds** - `8ab9677` (feat)
3. **Task 19-04-02 RED: expose fold review authority attacks** - `2ee4f7b` (test)
4. **Task 19-04-02 GREEN: bind owner-reviewed fold protocol** - `31b5383` (feat)

## Files Created/Modified

- `R/club/evaluation_protocol.R` - Fold schemas/builders, strict role/cutoff validators, calibration recipe, blocked/pending/ready state, self-hashed reviews, and immutable generation publication.
- `data/club/model_protocol/fold_registry.csv` - Exact header-only blocked-production fold schema.
- `data/club/model_protocol/protocol_state.json` - Canonical `blocked/no_accepted_club_history` production state.
- `data/club/model_protocol/calibration_recipe.json` - Frozen club temperature-calibration policy.
- `data/club/model_protocol/fold_review.json` - Pending no-owner review bound to the exact current protocol and recipe.
- `tests/testthat/test_phase19_club_folds.R` - Fold-family, nesting, cutoff, batch, held-out, coverage, review, atomicity, and escalation tests.

## Decisions Made

- The inner fit cutoff is the start of the latest eligible prior batch; that entire batch is calibration evidence and all earlier dual-time-eligible rows are fit/tuning evidence.
- A row is eligible only when its boundary, completion floor, and evidence-availability time are all strictly earlier than the relevant exclusive cutoff.
- Physical fold row order may change without changing table identity, but role fixture order is canonical and all semantic edits require new row/table/review identities.
- Production runtime generations use a disjoint fixed root; fixture generations use only the validated marker-bound temporary root.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- Plan 19-05 committed concurrently in the shared checkout. This plan staged only its six owned implementation/artifact files and preserved all concurrent and unrelated work.

## TDD Gate Compliance

- Task 19-04-01: RED `20b1064` precedes GREEN `8ab9677`; tracer feedback recheck passed 5 tests / 64 assertions before expansion.
- Task 19-04-02: RED `2ee4f7b` precedes GREEN `31b5383`.
- Final strict focused gate: 9 tests / 102 assertions, zero failures, errors, warnings, or skips.
- Upstream Plan 19-03 protocol regression: 6 tests / 110 assertions, zero failures, errors, warnings, or skips.
- Diff hygiene passed.

## Known Stubs

None. Blank production fold/history/reviewer fields are the required canonical representation of blocked and pending authority; validators reject them as ready evidence.

## User Setup Required

Real production folds remain intentionally unavailable until Phase 18 provides accepted club history and an owner separately accepts the exact policy and fold-review hashes. No credentials, network access, or fabricated approval were used.

## Next Phase Readiness

- Plan 19-05 and later evaluation code can consume exact fold IDs, strict evidence roles, declared fixture inventories, and the frozen recipe.
- Fixture mechanics are ready for end-to-end scoring. Production evaluation remains fail-closed until genuine accepted history, accepted policy review, and accepted fold review exist.

## Self-Check: PASSED

- All six implementation/test artifacts and this summary exist.
- TDD commits `20b1064`, `8ab9677`, `2ee4f7b`, and `31b5383` exist in repository history.
- Focused fold tests, upstream protocol regression, and diff hygiene pass.

---
*Phase: 19-independent-club-forecast-authority*
*Completed: 2026-09-20*
