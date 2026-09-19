---
phase: 15-nations-league-rules-and-outcomes
plan: 05
subsystem: competition-outcomes
tags: [nations-league, cli, simulation, replay, lineage, durable-output]

# Dependency graph
requires:
  - phase: 15-nations-league-rules-and-outcomes
    provides: "Phase 15-04 validated outcomes candidate, validator, writer, and nine-file schema"
provides:
  - "Registered Nations League production CLI with dry-run, replay-check, and write modes"
  - "Deterministic nine-file 2026/27 Nations League outcomes bundle"
  - "Fresh-process coverage for source/state boundaries, replay equality, lineage, and no mutation"
affects: [15-06-production-acceptance, dashboards, refresh-operations]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "CLI delegates only to validated Phase 13, Phase 14, and Phase 15 contracts"
    - "Atomic registered sibling publication with byte/hash replay checks"

key-files:
  created:
    - scripts/build_nations_league_outcomes.R
    - scripts/build_uefa_nations_league_outcomes.R
    - outputs/competition/uefa_nations_league_2026_27/outcomes/
  modified:
    - tests/testthat/test_phase15_nations_league.R
    - R/competition/uefa_nations_league_outcomes.R
    - R/competition/uefa_nations_league_simulation.R

key-decisions:
  - "Keep the plan-owned build_nations_league_outcomes.R implementation and expose the requested UEFA-prefixed command as a thin compatibility entrypoint."
  - "Use immutable Phase 14 forecast/status/score-grid handoff and join only missing simulator team identifiers from canonical match state in memory."
  - "Keep absent EURO eligibility explicit so C/D transitions remain unresolved rather than inferred."

patterns-established:
  - "Production output roots are resolved internally from the registered edition; callers cannot select arbitrary roots."
  - "Replay validation compares complete artifact bytes plus explicit lineage, status, probability, and completed-score fields."

requirements-completed: [COMP-02, SIM-01]

coverage:
  - id: D1
    description: "Nations League-only CLI validates registered source/state/stage-capture boundaries and exposes help, dry-run, replay, and write modes."
    requirement: COMP-02
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase15_nations_league.R: registered Nations League entrypoint covers every mode without parent mutation"
        status: pass
    human_judgment: false
  - id: D2
    description: "Validated deterministic nine-file outcomes bundle is durably published under the registered 2026/27 output root."
    requirement: SIM-01
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase15_nations_league.R: registered Nations League entrypoint covers every mode without parent mutation"
        status: pass
    human_judgment: false
  - id: D3
    description: "Normal, reversed-input, and repeated replay candidates preserve stage-capture lineage and completed-score/status fields."
    requirement: SIM-01
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase15_nations_league.R: registered Nations League entrypoint covers every mode without parent mutation"
        status: pass
    human_judgment: false

# Metrics
duration: approximately 55min
completed: 2026-08-22
status: complete
---

# Phase 15 Plan 05: Nations League Outcomes Summary

**Registered deterministic Nations League CLI with replay-safe nine-file outcomes bundle and separate stage-capture lineage**

## Performance

- **Duration:** approximately 55 min
- **Started:** 2026-08-22 (executor start timestamp was not retained across the interrupted verification loop)
- **Completed:** 2026-08-22
- **Tasks:** 1
- **Files modified:** 14, including the nine generated outcomes artifacts

## Accomplishments

- Added the Nations League-only production builder with strict edition/mode parsing, Phase 13 adapter validation, Phase 14 eleven-artifact loading, separate stage-capture loading, immutable simulation handoff, dry-run, replay-check, and registered-root write modes.
- Generated and committed exactly nine durable artifacts under `outputs/competition/uefa_nations_league_2026_27/outcomes/`, including `fixture_forecast_form.csv` and the self-hashed manifest.
- Added fresh-process focused coverage for help, invalid edition/mode, dry-run no-write, replay equality, write inventory, source/state immutability, stage-capture lineage, and completed-score/status schema fields.

## Task Commits

Each task was committed atomically:

1. **Task 15-05-01: Build the Nations League CLI and registered input loader** - `690e7e3` (feat)
2. **User-requested UEFA-prefixed entrypoint compatibility** - `5c6337c` (feat)

**Plan metadata:** committed with the final GSD STATE/ROADMAP metadata commit.

## Files Created/Modified

- `scripts/build_nations_league_outcomes.R` - Plan-owned CLI, input boundary, candidate builder, replay comparator, and writer entrypoint.
- `scripts/build_uefa_nations_league_outcomes.R` - Explicit UEFA-prefixed compatibility command delegating to the plan-owned builder.
- `tests/testthat/test_phase15_nations_league.R` - Fresh-process production mode and immutability tests.
- `R/competition/uefa_nations_league_outcomes.R` - Phase 14 parent inventory check scoped to registered state/audit/local namespaces so outcomes remain a valid sibling.
- `R/competition/uefa_nations_league_simulation.R` - NA-safe unresolved C/D transition handling.
- `outputs/competition/uefa_nations_league_2026_27/outcomes/*.csv` - Exact durable nine-file outcomes bundle.

## Decisions Made

- The durable output was produced with the deterministic seed `15017` and bounded `--simulations 1` write used by the focused production contract; the CLI default remains `1000` for future refreshes.
- Stage capture remains outside the Phase 13 five-resource list and Phase 14 eleven-artifact state inventory; its capture ID, raw/content/manifest hashes, and registry row lineage travel through the outcomes candidate parent graph.
- Unresolved C/D eligibility stays explicit (`unresolved_external_eligibility`) and is not converted into projected or official results.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Made unresolved C/D transition path aggregation NA-safe**
- **Found during:** Task 15-05-01 production dry-run
- **Issue:** Empty scheduled stage-capture rows carried NA status values into scalar transition-path checks, causing production simulation to fail before candidate construction.
- **Fix:** Treat unresolved/cancelled/playoff status checks as NA-safe while preserving unresolved probabilities and statuses.
- **Files modified:** `R/competition/uefa_nations_league_simulation.R`
- **Verification:** Focused Phase 15 suite passed 408 assertions.
- **Committed in:** `690e7e3`

**2. [Rule 1 - Bug] Scoped Phase 14 state inventory validation to its registered namespaces**
- **Found during:** Task 15-05-01 write/replay rerun after the outcomes sibling was generated
- **Issue:** The Phase 14 parent loader recursively included the legitimate `outcomes/` sibling and rejected the exact eleven-artifact state bundle on subsequent runs.
- **Fix:** Check only `state/`, `audit/`, and `local/` files when validating the Phase 14 inventory.
- **Files modified:** `R/competition/uefa_nations_league_outcomes.R`
- **Verification:** Focused Phase 15 suite passed with the durable outcomes sibling present.
- **Committed in:** `690e7e3`

**3. [User-directed compatibility] Added the requested UEFA-prefixed builder path**
- **Found during:** Final deliverable reconciliation
- **Issue:** The plan names `build_nations_league_outcomes.R`, while the latest execution request names `build_uefa_nations_league_outcomes.R`.
- **Fix:** Added a thin delegating entrypoint and moved fresh-process tests to exercise it while preserving the plan-owned implementation path.
- **Files modified:** `scripts/build_uefa_nations_league_outcomes.R`, `scripts/build_nations_league_outcomes.R`, `tests/testthat/test_phase15_nations_league.R`
- **Verification:** UEFA-prefixed `--help`, bounded focused suite, and registered-root write run passed.
- **Committed in:** `5c6337c`

**Total deviations:** 3 (2 correctness fixes, 1 user-directed compatibility addition)
**Impact on plan:** The fixes are required for repeatable sibling publication and unresolved-state correctness; the compatibility path expands invocation ergonomics without changing the contract.

## Issues Encountered

- A bounded attempt to refresh the durable bundle with the default `--simulations 1000` exceeded the requested 120-second limit and was terminated before publication. The previous validated nine-file write remains intact with `simulation_count=1`; no partial temporary output was promoted.
- The broader Phase 14/full-suite wave checks were not run because the latest user instruction explicitly limited verification to the focused Phase 15 test.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 15-06 can read the registered nine-file bundle, verify its manifest and lineage, and perform production acceptance checks. The only operational follow-up is to run a longer refresh window if a higher simulation count is required for production calibration.

## Self-Check: PASSED

- Summary path exists.
- Task commits `690e7e3` and `5c6337c` exist.
- The registered output root contains exactly nine CSV artifacts.
- The bounded focused Phase 15 test completed with 408 passes, zero failures, and zero warnings.

---
*Phase: 15-nations-league-rules-and-outcomes*
*Completed: 2026-08-22*
