---
phase: 16-euro-qualifying-activation-and-play-off-rules
plan: 03
subsystem: competition-simulation
tags: [R, UEFA, EURO, Nations-League, seeded-simulation, deterministic-replay]

# Dependency graph
requires:
  - phase: 14-shared-competition-state-and-forecast-layer
    provides: calibrated 1X2 and bounded score-distribution forecast authority
  - phase: 15-nations-league-rules-and-outcomes
    provides: registered projected-rankings artifact, manifest lineage, and interim-ranking contract
  - phase: 16-euro-qualifying-activation-and-play-off-rules
    provides: Plan 02 ranking, host-capacity, ledger, topology, and draw-condition contracts
provides:
  - registered Phase 15 interim-overall eligibility adapter with fail-closed lineage validation
  - deterministic seeded EURO single-leg and two-leg qualification simulation
  - official host-capacity branches, fallback pot construction, suppression envelopes, and replay hashes
affects: [16-04, 16-05, SIM-02, EURO qualification outputs]

# Tech tracking
tech-stack:
  added: []
  patterns: [registered-manifest adapter, calibrated-score-grid conditioning, caller-RNG save-restore, canonical replay hashing]

key-files:
  created: [R/competition/uefa_euro_simulation.R]
  modified: [tests/testthat/test_phase16_euro_qualifying.R]

key-decisions:
  - "The registered Phase 15 artifact is the only external eligibility authority; its current blocked/final-stage rows remain a rejection fixture rather than a positive input."
  - "EURO simulation consumes Phase 14 calibrated_1x2 probabilities and its score grid without fitting or recalibrating a second model."
  - "Host capacity is resolved through the Plan 02 ledger before runner-up and Nations League fallback admission, with only the highest-ranked two covered hosts consuming reservations."
  - "Stable canonical input ordering and complete output hashes are part of the simulation contract, including fresh-process replay."

patterns-established:
  - "External handoffs are normalized to exact ranking_scope=interim_overall and ranking_stage=interim_overall before any eligibility admission."
  - "Blocked paths return typed status/reason envelopes with empty probability tables and preserve scenario/topology context."

requirements-completed: [SIM-02]

coverage:
  - id: D1
    description: "Registered Phase 15 projected rankings are validated, normalized to the canonical interim stage, and rejected when final-only, wrong-stage, duplicate, missing, blocked, or unresolved."
    requirement: SIM-02
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase16_euro_qualifying.R#simulation|handoff|interim_adapter|registered_phase15|ranking_stage|rng|suppression"
        status: pass
    human_judgment: false
  - id: D2
    description: "Seeded single-leg and home-and-away resolution consumes calibrated forecast authority and restores the caller RNG state."
    requirement: SIM-02
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase16_euro_qualifying.R#simulation|handoff|interim_adapter|registered_phase15|ranking_stage|rng|suppression"
        status: pass
      - kind: unit
        ref: "Rscript --vanilla -e parse(file='R/competition/uefa_euro_simulation.R')"
        status: pass
    human_judgment: false
  - id: D3
    description: "Official zero-, one-, and two-host topology branches, four-host selection, fallback provenance, draw-condition gating, and empty probability suppression are enforced."
    requirement: SIM-02
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase16_euro_qualifying.R#topology|four_host|fallback|draw_conditions|fresh_process|replay"
        status: pass
    human_judgment: false
  - id: D4
    description: "Normal, reversed-input, repeated, and fresh child-process replays produce identical complete artifact hashes."
    requirement: SIM-02
    verification:
      - kind: e2e
        ref: "tests/testthat/test_phase16_euro_qualifying.R#topology|four_host|fallback|draw_conditions|fresh_process|replay"
        status: pass
    human_judgment: false

# Metrics
duration: 54 min
completed: 2026-08-24
status: complete
---

# Phase 16 Plan 03: Interim Handoff and Seeded EURO Simulation Summary

**Registered Phase 15 interim eligibility with fail-closed lineage checks and deterministic calibrated EURO qualification simulation across every official play-off topology.**

## Performance

- **Duration:** 54 min
- **Started:** 2026-08-24T11:02:43Z
- **Completed:** 2026-08-24T11:56:29Z
- **Tasks:** 2 completed
- **Files modified:** 2 plan-owned files

## Accomplishments

- Added the registered Phase 15 reader and canonical interim projection adapter. Stable `team_id`, manifest/artifact content identity, source bundle lineage, rules lineage, `ranking_scope`, and exact `ranking_stage` are required before eligibility is admitted.
- Added deterministic calibrated single-leg and two-leg resolution with stable child seeds, caller RNG restoration, aggregate/extra-time/penalty handling, model release lineage, and score-grid conditioning from the Phase 14 authority.
- Added Plan 02 ledger consumption for host capacity, runner-up allocation, Nations League A-C and D fallback order, qualified/host exclusion, official pot/path construction, and zero/one/two-host topology cardinalities.
- Added typed suppression and scenario-preservation envelopes for pre-draw/invalid activation, missing kickoff, unresolved standings or hosts, incomplete handoffs, and invalid draw conditions, plus complete output replay hashes and fresh child-process coverage.

## Task Commits

Each task was committed atomically:

1. **Task 1: Trace the registered Phase 15 output through interim-projection normalization and calibrated seeded simulation** - `ed2ecb7` (test RED), `27064da` (feat GREEN)
2. **Task 2: Complete host branches, fallback eligibility, draw-condition suppression, and fresh-process replay** - `279991f` (test RED), `341af9c` (fix GREEN)

**Plan metadata:** recorded in the final docs commit after state and roadmap updates.

## Files Created/Modified

- `R/competition/uefa_euro_simulation.R` - Registered Phase 15 adapter, calibrated match sampling, single/two-leg resolution, host-capacity pool allocation, fallback pot construction, topology simulation, typed suppression, metadata, and replay hashes.
- `tests/testthat/test_phase16_euro_qualifying.R` - Task 1 handoff/RNG/suppression coverage and Task 2 topology, four-host, fallback, draw-condition, repeated/reversed/child-process replay fixtures.

## Verification

- Focused Phase 16 file: passed with `testthat::test_file("tests/testthat/test_phase16_euro_qualifying.R", stop_on_failure=TRUE, reporter="summary")`.
- Phase 14 state-bundle regression: passed.
- Phase 15 Nations League regression: passed.
- R parse checks for the simulation module and focused test file: passed.
- Fresh child-process two-leg replay hash: passed.
- The repository-wide suite was intentionally not rerun. The exact Wave 0 baseline in `16-BASELINE.md` remains the known non-green comparator: `156 fixture IDs paired with zero-length normalized source columns` in the recorded Phase 13 identities.

## Decisions Made

The implementation keeps the registered Phase 15 artifact as the trust boundary and never promotes final-stage display rows into interim eligibility. It derives a canonical interim stage only from preserved interim evidence, then carries source/artifact/manifest/rules lineage into every admitted row. Simulation uses only the accepted Phase 14 calibrated authority and makes host capacity, draw-condition version, scenario identity, and deterministic replay part of the returned contract.

## Deviations from Plan

### Verification Compatibility

The plan's filtered command uses `testthat::test_file(..., filter=...)`, but the installed testthat 3.3.2 API rejects that argument with `unused argument (filter = ...)`. The supported whole focused file was run with `stop_on_failure=TRUE`; it passed, and the focused tests were scoped to the plan-owned file. No production behavior or test coverage was removed.

**Total deviations:** 1 verification-command substitution; 0 code-scope deviations.

## Issues Encountered

- The initial RED implementation exposed and fixed calibrated probability extraction, score-grid conditional normalization, runner-up derivation from completed standings, and reversed-input canonicalization during the planned TDD loop.
- No new blocker remains. Existing unrelated dirty files and the recorded Wave 0 full-suite baseline were preserved and not modified.
- The optional WINDOWS ledger append was not applied because its pre-existing frontmatter counts disagree with its stored entries; repairing that unrelated ledger was outside this plan.

## Known Stubs

None found in the plan-created or plan-modified files.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 16-04 can consume the adapter's normalized eligibility, topology, stage-resolution, probability, suppression, lineage, and replay-hash contracts. Plans 16-04 and 16-05 remain untouched.

---
*Phase: 16-euro-qualifying-activation-and-play-off-rules*
*Plan: 03*
*Completed: 2026-08-24*

## Self-Check: PASSED

- Summary file exists on disk.
- Task commit hashes `ed2ecb7`, `27064da`, `279991f`, and `341af9c` exist in git history.
- No plan-owned file deletions were introduced.
