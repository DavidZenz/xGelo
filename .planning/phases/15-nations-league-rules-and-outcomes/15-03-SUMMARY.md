---
phase: 15-nations-league-rules-and-outcomes
plan: "03"
subsystem: competition-simulation
tags: [R, UEFA, Nations-League, simulation, replay, transitions]

# Dependency graph
requires:
  - phase: 15-02
    provides: Article 15/19 rankings, transitions, and explicit C/D eligibility states
  - phase: 14-shared-competition-state-and-forecast-layer
    provides: immutable calibrated forecast, score-grid, cutoff, and lineage handoff
provides:
  - Deterministic calibrated Nations League state-machine simulation
  - Replay-safe standings, ranking, stage-path, transition, and C/D outputs
  - Explicit final-ranking and C/D cancellation/unresolved lineage
affects: [15-04 outcomes, 15-05 writer, 15-06 production entrypoint]

# Tech tracking
tech-stack:
  added: [seeded R state-machine simulation]
  patterns: [immutable Phase 14 handoff, canonical input hashes, calibrated-simplex sampling, explicit suppressed/unresolved rows]

key-files:
  created: []
  modified:
    - R/competition/uefa_nations_league_simulation.R
    - tests/testthat/test_phase15_nations_league.R

key-decisions:
  - "Use calibrated 1X2 probabilities as the outcome authority and the Phase 14 score grid only for conditional scoreline shape."
  - "Derive stable iteration and stage seeds while restoring the caller RNG state on every public simulation call."
  - "Keep unavailable, blocked, unresolved, and suppressed states explicit; never invent probabilities for missing external evidence."
  - "Persist final-only ranking stages and a canonical hash alongside the broader ranking-stage lineage."

patterns-established:
  - "Canonicalize and hash every Phase 14 input before the first draw; output hashes are returned with simulation metadata."
  - "Projected stage slots carry projection and draw-policy lineage, while official source fixture IDs remain distinct."
  - "C/D cancellation retains exact next-edition mappings and NA_real_ play-off probabilities; absent eligibility remains unresolved."

requirements-completed: [SIM-01]

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
    description: "Complete seeded Nations League state-machine simulation with probability aggregation, replay, and no-leakage hashes"
    requirement: "SIM-01"
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase15_nations_league.R :: simulation replay preserves RNG, hashes, and probability mass"
        status: pass
    human_judgment: false
  - id: D3
    description: "Final-ranking stages and explicit C/D contested, cancelled-retained, and unresolved simulation outputs"
    requirement: "SIM-01"
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase15_nations_league.R :: official stage capture replay is stable and C/D branches stay explicit"
        status: pass
    human_judgment: false

# Metrics
duration: resumed bounded execution; wall-clock start not captured
completed: 2026-08-22
status: complete
---

# Phase 15 Plan 03: Nations League Simulation Summary

**Deterministic calibrated Nations League simulation with immutable Phase 14 replay, legal stage paths, final-ranking lineage, and explicit C/D outcomes.**

## Performance

- **Duration:** resumed bounded execution; wall-clock start not captured
- **Started:** 2026-08-22
- **Completed:** 2026-08-22
- **Tasks:** 3 of 3 completed
- **Files modified:** 2 implementation/test files

## Accomplishments

- Implemented `uefa_nl_run_simulation()` with explicit Phase 14 handoff inputs, canonical input hashes, cutoff-qualified completed-result admission, available-open-fixture sampling, stable seeded replay, caller-RNG restoration, and output lineage.
- Aggregated projected standings, individual/interim/final rankings, League A stage paths, direct transitions, play-off outcomes, stage slots, stage matches, and unresolved/suppressed fixture rows without fabricated probabilities.
- Wired Article 19 final ranking through every iteration and preserved `final_overall_rank`, `ranking_stage`, final-stage metadata hashes, and exact C46/C47/D50/D51 C/D cancellation retention semantics.
- Added focused synthetic coverage for deterministic and reversed replay equality, mass conservation, stage-capture replay, no-leakage hashes, final-ranking stages, and all C/D branches.

## Verification

Bounded command:

`perl -e 'alarm 120; exec @ARGV' -- Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase15_nations_league.R", stop_on_failure=TRUE)'`

Result: **359 assertions, 0 failures, 0 warnings, 0 skips**.

## Task Commits

Each task was committed atomically:

1. **Task 15-03-01: Implement calibrated outcome sampling and Article 16-18 resolution** - `eeaceb9` (feat)
2. **Task 15-03-02: Run the complete Nations League state-machine simulation** - `99492e8` (feat)
3. **Task 15-03-03: Carry final rankings and C/D cancellation through simulation outputs** - `f3d7b9e` (fix)

**Plan metadata:** committed separately after self-check and state/roadmap updates.

## Files Created/Modified

- `R/competition/uefa_nations_league_simulation.R` - calibrated sampler integration, deterministic iteration runner, stage transitions, final-ranking capture, C/D branches, aggregation, and metadata hashes.
- `tests/testthat/test_phase15_nations_league.R` - synthetic replay, probability-mass, stage-capture, no-leakage, final-ranking, and C/D branch assertions.

## Decisions Made

- Calibrated 1X2 probabilities remain authoritative; the Phase 14 score grid supplies only within-category scoreline shape.
- Simulation inputs are canonicalized before sampling and never mutated; input and output hashes plus source/model/state lineage are returned in metadata.
- Explicit eligibility is required to contest or cancel C/D. Missing eligibility stays unresolved, cancellation emits retained mappings with `NA_real_` play-off probabilities, and contesting alone produces simulated play-off outcomes.
- Final ranking stages are carried both per projected-ranking row and in final-only metadata lineage, distinguishing pre-finals from completed-finals captures.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Vectorized open-fixture status admission**
- **Found during:** Task 15-03-02 implementation
- **Issue:** The status predicate used scalar `&&` semantics, so a vector of fixture statuses could admit or reject rows based on only its first element.
- **Fix:** Switched the predicate to vectorized `&` semantics and kept the available/open filter at the normalized fixture boundary.
- **Files modified:** `R/competition/uefa_nations_league_simulation.R`
- **Verification:** Focused Phase 15 suite passed with 359 assertions.
- **Committed in:** `99492e8`

**2. [Rule 1 - Bug] Restore group league before Article 19 ranking**
- **Found during:** Task 15-03-02 implementation
- **Issue:** The Phase 14 universal standings snapshot is intentionally league-neutral, but Article 19 ranking requires the admitted league on every group row.
- **Fix:** Reattached the normalized group league at the state-machine boundary before individual and interim ranking adapters run.
- **Files modified:** `R/competition/uefa_nations_league_simulation.R`
- **Verification:** Synthetic standings/ranking mass conservation and final-ranking stage assertions passed.
- **Committed in:** `99492e8`

**3. [Rule 1 - Test correction] Align ranking-stage metadata assertion with serialized lineage format**
- **Found during:** Task 15-03-03 verification
- **Issue:** The new test treated the semicolon-delimited metadata stage list as a vector and failed to find the expected stage token.
- **Fix:** Asserted token membership against the serialized field and added a dedicated final-ranking-stage hash assertion.
- **Files modified:** `tests/testthat/test_phase15_nations_league.R`
- **Verification:** Bounded focused suite passed with 359 assertions.
- **Committed in:** `f3d7b9e`

**Total deviations:** 3 auto-fixed issues; all were correctness/test alignment fixes within the planned files.

## Issues Encountered

None. The focused Phase 15 verification completed within the requested 120-second bound. Unrelated dirty and untracked worktree artifacts were preserved and excluded from all task commits.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

SIM-01 is complete for Plan 15-03. The simulation contract is ready for the sibling outcomes bundle and production writer/entrypoint plans; no implementation blocker remains.

---
*Phase: 15-nations-league-rules-and-outcomes*
*Plan: 03 (complete)*

## Self-Check: PASSED

- Summary file exists at the expected phase path.
- Task commits `eeaceb9`, `99492e8`, and `f3d7b9e` are present in repository history.
- Focused Phase 15 verification passed with 359 assertions, 0 failures, 0 warnings, and 0 skips.
- Summary records Tasks 3/3, SIM-01 coverage, final-ranking lineage, and all C/D branches as complete.
