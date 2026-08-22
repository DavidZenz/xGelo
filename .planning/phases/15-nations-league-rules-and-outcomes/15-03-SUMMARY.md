---
phase: 15-nations-league-rules-and-outcomes
plan: "03"
subsystem: competition-simulation
tags: [R, UEFA, Nations-League, simulation, seeded-rng]

# Dependency graph
requires:
  - phase: 15-02
    provides: Article 15/19 rankings, transitions, and explicit C/D eligibility states
  - phase: 14-shared-competition-state-and-forecast-layer
    provides: immutable calibrated forecast and score-grid handoff
provides:
  - Calibrated 1X2 outcome sampling with conditional scoreline distributions
  - Article 14-18 tie resolution and legal projected draw primitives
affects: [15-03 continuation, 15-04 outcomes, 15-05 writer]

# Tech tracking
tech-stack:
  added: []
  patterns: [calibrated-simplex sampling, conditional score-grid sampling, seeded replay, projected-slot lineage]

key-files:
  created:
    - R/competition/uefa_nations_league_simulation.R
  modified:
    - tests/testthat/test_phase15_nations_league.R

key-decisions:
  - "Use calibrated_1x2 as the outcome authority and the Phase 14 score grid only for conditional scoreline shape."
  - "Represent projected draws with projection and draw-policy lineage while leaving source fixture IDs empty."
  - "Preserve unresolved states rather than inventing outcomes when a score category or required pairing is absent."

patterns-established:
  - "Every seeded primitive restores the caller RNG state after sampling."
  - "Two-leg resolution compares the aggregate only after both legs, then applies extra time and penalties at the tie boundary."

requirements-completed: []

coverage:
  - id: D1
    description: "Calibrated sampling, Article 14 reciprocal-leg resolution, Article 18 tie-breaks, and Article 17 draw policies"
    requirement: "SIM-01"
    verification:
      - kind: unit
        ref: "tests/testthat/test_phase15_nations_league.R"
        status: pass
    human_judgment: false
  - id: D2
    description: "Complete seeded Nations League state-machine simulation and probability aggregation"
    requirement: "SIM-01"
    verification: []
    human_judgment: true
    rationale: "Task 15-03-02 remains outstanding in this paused execution."
  - id: D3
    description: "Final-ranking and C/D cancellation propagation through simulation outputs"
    requirement: "SIM-01"
    verification: []
    human_judgment: true
    rationale: "Task 15-03-03 remains outstanding in this paused execution."

# Metrics
duration: partial execution
completed: 2026-08-22
status: in_progress
---

# Phase 15 Plan 3: Nations League Simulation Summary

**Calibrated Nations League match sampling, Article 14-18 resolution, and legal projected draw primitives are implemented; the state-machine runner and output propagation remain pending.**

## Performance

- **Duration:** partial execution; plan paused after Task 15-03-01
- **Started:** 2026-08-22
- **Completed:** 2026-08-22 (partial)
- **Tasks:** 1 of 3 completed
- **Files modified:** 2 implementation/test files

## Accomplishments

- Added calibrated `p_home`/`p_draw`/`p_away` sampling and conditional score-grid reweighting with normalized support and fixture identity checks.
- Added reciprocal two-leg validation, aggregate resolution, second-leg extra time, seeded penalties, single-leg final/direct-penalty resolution, and projected QF/semi draw policies.
- Focused Phase 15 verification passed with 318 assertions, 0 failures, 0 warnings, and 0 skips.

## Task Commits

1. **Task 15-03-01: Implement calibrated outcome sampling and Article 16-18 resolution** - `eeaceb9` (feat)
2. **Task 15-03-02: Run the complete Nations League state-machine simulation** - outstanding
3. **Task 15-03-03: Carry final rankings and C/D cancellation through simulation outputs** - outstanding

## Files Created/Modified

- `R/competition/uefa_nations_league_simulation.R` - calibrated sampler, tie resolvers, projected QF draw, and host-ordered semi-final primitives.
- `tests/testthat/test_phase15_nations_league.R` - focused sampling, resolution, and draw-policy tests.

## Decisions Made

- Calibrated 1X2 probabilities are authoritative; the Phase 14 score grid supplies only within-category scoreline shape.
- Seeds are scoped to individual primitives and restore the caller RNG state, preserving deterministic replay without leaking RNG mutations.
- Projected stage slots carry `projection_run_id` and `draw_policy_id`, while official source fixture IDs remain empty until an official pairing is supplied.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Test correction] Aligned focused synthetic expectations with primitive contracts**
- **Found during:** Task 15-03-01 verification
- **Issue:** The initial focused additions compared named vectors, supplied an unnormalized filtered grid to the empty-category assertion, used score orientations that did not produce the intended higher-team aggregate tie-break outcomes, and expected a later validation error message.
- **Fix:** Removed name-only comparison noise, normalized the filtered test grid, corrected reciprocal-leg score orientations, and broadened the assertion to the explicit same-side validation error.
- **Files modified:** `tests/testthat/test_phase15_nations_league.R`
- **Verification:** Focused Phase 15 test passed with 318 assertions.
- **Committed in:** `eeaceb9`

**Total deviations:** 1 test correction; no production scope expansion.

## Issues Encountered

- The requested checkpoint arrived after Task 15-03-01. `eeaceb9` is a valid atomic task commit, but it does not contain the state-machine runner or Task 15-03-03 ranking/C-D propagation.
- The Phase 14 regression test and full `tests/testthat` suite were not run during this bounded partial execution.
- The worktree contains unrelated pre-existing dirty and untracked generated artifacts; they were preserved and excluded from task staging.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Resume at Task 15-03-02. The next implementation should consume the immutable Phase 14 forecast/status/score-grid inputs, aggregate seeded iterations, and then wire final-ranking plus C/D cancellation lineage in Task 15-03-03. This summary is intentionally marked `in_progress`; SIM-01 is not marked complete.

---
*Phase: 15-nations-league-rules-and-outcomes*
*Plan: 03 (partial)*

## Self-Check: PASSED

- Summary file exists at the expected phase path.
- Task commit `eeaceb9` is present in repository history.
- Focused Phase 15 verification passed with 318 assertions, 0 failures, 0 warnings, and 0 skips.
- Remaining Tasks 15-03-02 and 15-03-03 are explicitly recorded as outstanding.
