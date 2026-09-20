---
phase: 19-independent-club-forecast-authority
plan: "03"
subsystem: model-governance
tags: [r, canonical-v2, club-domain, promotion-gates, owner-review, fail-closed]

requires:
  - phase: 18-club-and-ucl-source-contracts
    provides: Canonical-v2 hashing and accepted club source/identity authority boundaries
  - phase: 19-independent-club-forecast-authority
    plan: "01"
    provides: Fixed club production/fixture roots and canonical unavailable-feature contract
provides:
  - Exact club-only candidate, control, incumbent, parameter, and deterministic seed registries
  - Complete ordered numeric, coverage, reproducibility, current-club, and integrity gate authority
  - One canonical protocol parent plus exact-hash self-reviewed production authorization boundary
affects: [19-04, 19-05, 19-06, 19-07, 19-08, 19-09, 19-10, phase-20, phase-21]

tech-stack:
  added: []
  patterns: [canonical-v2 policy graph, predeclared numeric gates, self-hashed owner review, fixture-only mechanical policy]

key-files:
  created:
    - R/club/evaluation_protocol.R
    - data/club/model_protocol/candidate_registry.csv
    - data/club/model_protocol/gate_registry.csv
    - data/club/model_protocol/seed_registry.csv
    - data/club/model_protocol/policy_review.json
    - tests/testthat/test_phase19_club_protocol.R
  modified: []

key-decisions:
  - "Only club_venue_nb is the promotion incumbent and club_elo_nb is the promotion candidate; uniform_1x2 and expanding_1x2 remain report-only controls."
  - "Every threshold, comparator, aggregation, applicability, order, and failure reason is a predeclared canonical gate row; observed scores cannot rewrite policy."
  - "Fixture evaluation may exercise a pending policy mechanically, while production remains blocked until one accepted self-hashed owner review binds every exact parent hash."

patterns-established:
  - "Club protocol graph: exact table schemas and canonical-v2 hashes are bound with ordered filenames, domain, and G=40 support into one protocol identity."
  - "Review authority is separate from policy mechanics: pending/rejected/missing/stale reviews always return protocol_policy_not_approved in production."

requirements-completed: [CLUBMOD-01, CLUBMOD-03]

coverage:
  - id: D1
    description: "Four club-only model roles and four deterministic seed purposes are frozen before fitting, with inner-only Elo tuning and unavailable-feature rejection."
    requirement: CLUBMOD-01
    verification:
      - kind: unit
        ref: "tests/testthat/test_phase19_club_protocol.R#candidate role, parameter, formula, domain, seed, and canonical-order tests"
        status: pass
      - kind: other
        ref: "rtk Rscript --vanilla scripts/run_phase19_focused_test.R tests/testthat/test_phase19_club_protocol.R"
        status: pass
    human_judgment: false
  - id: D2
    description: "Twenty-four ordered promotion gates and exact-hash owner review authority make production policy fail closed while fixture mechanics remain evaluable."
    requirement: CLUBMOD-03
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase19_club_protocol.R#gate inventory, protocol identity, review authority, mutation, and read-only loader tests"
        status: pass
      - kind: other
        ref: "two isolated Rscript loads produced protocol 34e084ab9e88de48ac26d57477a8d9ad03ca36972eac9245a13ddf8da719f9a2"
        status: pass
      - kind: other
        ref: "rtk git diff --check"
        status: pass
    human_judgment: false

duration: 22min
completed: 2026-09-20
status: complete
---

# Phase 19 Plan 03: Frozen Club Evaluation Policy Summary

**Canonical-v2 club candidates, deterministic seeds, 24 predeclared promotion gates, and exact-hash owner review now form one immutable production policy boundary.**

## Performance

- **Duration:** 22 min
- **Started:** 2026-09-20T17:49:57Z
- **Completed:** 2026-09-20T18:12:00Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Registered exactly `uniform_1x2`, `expanding_1x2`, `club_venue_nb`, and `club_elo_nb` with closed roles, club-only formulas, G=40 support where applicable, and the predeclared base/K/home-advantage/inactivity search domain.
- Bound four unique named seeds for inner candidate tuning, calibration, paired bootstrap, and isolated replay into canonical-v2 policy identity before any fit or score exists.
- Froze 24 ordered gates spanning RPS effect and uncertainty, both fold families, supporting scores, calibration, exact fixture/grid coverage, current-UCL connectivity, byte replay, and complete integrity checks.
- Added a self-hashed policy review over every exact table/protocol parent. The committed review is truthfully `pending` with blank reviewer/time, so fixture evaluation is available while production returns `protocol_policy_not_approved`.
- Final focused verification passed 6 tests and 110 assertions; the combined Phase 19 suite passed 25 tests and 271 assertions with zero failures, errors, warnings, or skips.

## Task Commits

Each TDD gate was committed atomically:

1. **Task 19-03-01 RED: expose club protocol authority boundary** - `ddb8f56` (test)
2. **Task 19-03-01 GREEN: freeze club candidate and seed authority** - `9b0a364` (feat)
3. **Task 19-03-02 RED: expose promotion policy review attacks** - `e2c0df8` (test)
4. **Task 19-03-02 GREEN: freeze club promotion policy authority** - `6c4a22f` (feat)

## Files Created/Modified

- `R/club/evaluation_protocol.R` - Exact schemas, closed policy inventories, canonical-v2 row/table/protocol hashes, fixed-root readers, and fixture/production review authority.
- `data/club/model_protocol/candidate_registry.csv` - Four exact club roles, formulas, capabilities, support, and parameter policy candidates.
- `data/club/model_protocol/gate_registry.csv` - Twenty-four ordered numeric, coverage, replay, and integrity rules with stable failure reasons.
- `data/club/model_protocol/seed_registry.csv` - Four unique positive named seeds bound to their predeclared purposes/stages.
- `data/club/model_protocol/policy_review.json` - Truthful pending self-hashed review bound to exact candidate/gate/seed/feature/protocol hashes.
- `tests/testthat/test_phase19_club_protocol.R` - Role, formula, threshold, ordering, collision, domain, review, inventory, immutability, and fresh-process tests.

## Decisions Made

- Candidate and seed physical row order is canonicalized by stable keys, while semantic order fields and all values remain hash-bound; a semantic order/value edit changes identity and fails exact validation.
- Candidate formulas resolve only a closed active core vocabulary. All five unavailable enrichment IDs remain forbidden until the Phase 19 feature contract separately activates them.
- `club_venue_nb` is the sole incumbent and `club_elo_nb` the sole candidate. The two empirical controls are never release-selectable.
- The protocol directory accepts either the exact current five-file authority inventory or the exact complete downstream fold/calibration inventory added by Plan 19-04; partial or unknown surplus states fail closed.
- Owner review is not inferred from valid hashes. Only `decision=accepted` with a non-empty reviewer, UTC review time, valid self-hash, and exact parent agreement makes production eligible.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- Plan 19-02 executed concurrently in the shared checkout. Its commits and state update were preserved; this plan staged only its owned protocol/policy files and based its summary on the latest committed state.

## TDD Gate Compliance

- Task 19-03-01: RED `ddb8f56` precedes GREEN `9b0a364`.
- Task 19-03-02: RED `e2c0df8` precedes GREEN `6c4a22f`.
- Final focused verification: 6 tests, 110 assertions, zero failures/errors/warnings/skips.
- Combined Phase 19 regression: 25 tests, 271 assertions, zero failures/errors/warnings/skips.
- Two independent fresh R processes reproduced protocol hash `34e084ab9e88de48ac26d57477a8d9ad03ca36972eac9245a13ddf8da719f9a2` and review hash `234e11ce8f05d01e614b70957884290e378f240638bbb7a9da0aed01181c3b99`.

## Known Stubs

None. Blank reviewer and review-time values are the required canonical representation of a truthful pending owner review; they cannot authorize production and are not runtime placeholders.

## User Setup Required

The production policy remains intentionally blocked until a real owner reviews the exact committed policy and replaces the pending review with a valid accepted review. No credentials, network access, package installation, or invented approval were used.

## Next Phase Readiness

- Fold, fit, calibration, evaluation, and promotion plans can depend on one deterministic club protocol hash and closed gate/reason inventory.
- Fixture-backed mechanics can proceed safely. Production promotion remains fail-closed until genuine source authority and a genuine accepted policy review exist.

## Self-Check: PASSED

- All six implementation/test artifacts and this summary exist.
- TDD commits `ddb8f56`, `9b0a364`, `e2c0df8`, and `6c4a22f` exist in repository history.
- Focused and combined fresh-process verification plus diff hygiene pass.

---
*Phase: 19-independent-club-forecast-authority*
*Completed: 2026-09-20*
