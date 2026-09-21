---
phase: 20-ucl-rules-state-and-tournament-outcomes
plan: "03"
subsystem: competition-simulation
tags: [ucl, conditional-simulation, article-19, annex-b, draw-lineage, tdd]

# Dependency graph
requires:
  - phase: 20-ucl-rules-state-and-tournament-outcomes
    provides: "Validated UCL schedule, Article 18 rank intervals, immutable forecast ledger, and fixed Phase 19 authority resolver"
provides:
  - "Conditional league-phase simulation with immutable settled fixtures and eligible score-grid sampling"
  - "Conserved full-rank, qualification-band, and rank-8/rank-24 cut-line distributions"
  - "Article 19/Annex B legal pre-draw paths and exact same-edition accepted-draw conditioning"
affects: [ucl-outcomes, phase20-verification, forecast-projections]

# Tech tracking
tech-stack:
  added: []
  patterns: ["fixture-scoped deterministic RNG with caller-state restoration", "typed unresolved draw/rank states", "lineage-bound draw artifact validation"]

key-files:
  created: [.planning/phases/20-ucl-rules-state-and-tournament-outcomes/20-03-RED.md, .planning/phases/20-ucl-rules-state-and-tournament-outcomes/20-03-SUMMARY.md]
  modified: [R/competition/uefa_champions_league_rules.R, R/competition/uefa_champions_league_simulation.R, tests/testthat/helper_uefa_champions_league.R, tests/testthat/test_uefa_champions_league.R]

key-decisions:
  - "Keep the edition-specific 2026/27 organiser draw procedure unresolved; pre-draw outputs expose only legal rank families and never fabricate exact draw paths."
  - "Require complete same-edition/source-lineage draw artifacts with rank inputs and legal path metadata before exact conditioning; stale, partial, foreign, and contradictory artifacts stay unresolved."
  - "Use deterministic bounded enumeration for the 24 legal play-off/R16 path families and record policy, count, seed, and legality checks in simulation metadata."

patterns-established:
  - "Settled completed, extra-time, penalty, awarded, and postponed lifecycle rows are partitioned before sampling and remain byte-preserved."
  - "Every resolved club receives all 36 rank rows, three mutually exclusive band probabilities, and exact occupant distributions for rank 8 and rank 24."

requirements-completed: [UCLOUT-02, UCLOUT-03]

coverage:
  - id: D1
    description: "Conditional league simulation fixes settled lifecycle rows and samples only eligible open fixtures from validated score grids."
    requirement: UCLOUT-02
    verification:
      - kind: unit
        ref: tests/testthat/test_uefa_champions_league.R#UCLOUT-02 fixes every settled lifecycle and samples only eligible open rows
        status: pass
    human_judgment: false
  - id: D2
    description: "Full-rank, qualification-band, and rank-8/rank-24 distributions conserve probability while unresolved intervals remain typed unavailable."
    requirement: UCLOUT-02
    verification:
      - kind: unit
        ref: tests/testthat/test_uefa_champions_league.R#UCLOUT-02 emits conserved full-rank, band, and cut-line distributions
        status: pass
    human_judgment: false
  - id: D3
    description: "Pre-draw and accepted-draw knockout paths obey Article 19/Annex B rank families, bracket positions, leg order, and draw lineage."
    requirement: UCLOUT-03
    verification:
      - kind: unit
        ref: tests/testthat/test_uefa_champions_league.R#UCLOUT-03 enumerates only Article 19/Annex B legal paths
        status: pass
      - kind: unit
        ref: tests/testthat/test_uefa_champions_league.R#UCLOUT-03 suppresses rank-boundary paths and conditions exactly on accepted draw lineage
        status: pass
    human_judgment: false
  - id: D4
    description: "RNG replay, parent-reason retention, fixture authority, and unresolved draw procedure remain fail-closed."
    requirement: UCLOUT-02
    verification:
      - kind: unit
        ref: tests/testthat/test_uefa_champions_league.R#UCLOUT-02/03 preserve replay identity and parent authority diagnostics
        status: pass
    human_judgment: false

# Metrics
duration: 2h 10m
completed: 2026-09-21
status: complete
---

# Phase 20 Plan 03: Conditional UCL simulation and legal draw paths Summary

**Conditional UCL league distributions with fixed settled evidence, conserved rank outputs, and lineage-gated Article 19/Annex B knockout paths**

## Performance

- **Duration:** 2h 10m
- **Started:** 2026-09-21T16:53:00Z
- **Completed:** 2026-09-21T19:03:00Z
- **Tasks:** 2
- **Files modified:** 6 (plus this summary)

## Accomplishments

- Added score-grid conditional sampling with stable fixture/iteration seeds, caller RNG restoration, strict pre-kickoff evidence checks, and immutable settled/postponed lifecycle handling.
- Added full 1–36 rank distributions, mutually exclusive direct/play-off/eliminated bands, and rank-8/rank-24 occupant distributions with typed suppression for incomplete iterations or rank intervals.
- Added editioned Article 19/Annex B pair-family policy, 24 bounded legal pre-draw paths, legal-path validation, and metadata for policy/count/seed/legality checks.
- Added strict accepted-draw validation requiring edition/source lineage, complete rank inputs, content hash, path metadata, and legal participants; exact accepted pairings are consumed without bracket replacement.
- Preserved the exact eight-record official evidence sidecar and its unresolved `draw_procedure_2026_27` row; fixture mechanics remain permanently `production_eligible=false` behind the Phase 19 resolver.

## Task Commits

Each task was committed atomically:

1. **Task 1: Write RED contracts for conditioned league distributions and legal draw paths** - `e976a63` (test)
2. **Task 1 RED evidence transcript** - `5404e64` (docs)
3. **Task 2: Implement conditional league simulation and legal accepted-draw paths** - `43e0741` (feat)

## Files Created/Modified

- `R/competition/uefa_champions_league_rules.R` - editioned Article 19/Annex B pair families, bracket positions, and legal leg-order policy.
- `R/competition/uefa_champions_league_simulation.R` - conditional iteration preparation/sampling, conserved distributions, legal paths, and strict draw artifact validation.
- `tests/testthat/helper_uefa_champions_league.R` - settled/open lifecycle, score-grid, rank, and accepted-draw fixtures.
- `tests/testthat/test_uefa_champions_league.R` - RED/GREEN contracts for sampling, conservation, legality, lineage, replay, and parent diagnostics.
- `.planning/phases/20-ucl-rules-state-and-tournament-outcomes/20-03-RED.md` - fresh-process RED transcript and commit evidence.
- `data/competition/rules/ucl_2026_27_rules_and_draw_evidence.json` - validated unchanged; seven accepted regulation records plus unresolved edition draw row.

## Decisions Made

- Exact draw-conditioned paths stay suppressed until a genuine reviewed same-edition organiser artifact is supplied; Article 19/Annex B mechanics do not stand in for missing draw evidence.
- Rank uncertainty is propagated conservatively: dependent paths and bands are unresolved rather than lexically or randomly assigned.
- The bounded legal state space is deterministically enumerated (16 play-off rank pairs plus 8 seeded R16 slots), while metadata still records the seed and policy boundary for replay.

## Deviations from Plan

None - plan executed exactly as written. The legacy minimal accepted-draw test fixture was replaced with the plan's complete lineage fixture so the strict artifact contract is tested rather than bypassed.

## Issues Encountered

- The focused UCL suite passed in a fresh process after GREEN implementation.
- The Phase 14 state-bundle regression emitted only passing dots but exceeded the bounded runtime cap and was stopped cleanly; Phase 16 was not run after that cap. No failure was observed in the capped Phase 14 output, and no out-of-scope files were changed. The focused UCL suite is the completed verification gate for this plan.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Downstream UCL outcome work can consume deterministic rank/band/cut-line tables and legal pre-draw paths. Exact draw-conditioned outcomes remain intentionally unavailable until the unresolved `draw_procedure_2026_27` evidence row is replaced by a reviewed same-edition artifact; production forecast authority remains blocked by Phase 19 as intended.

---
*Phase: 20-ucl-rules-state-and-tournament-outcomes*
*Completed: 2026-09-21*

## Self-Check: PASSED

- All declared implementation, evidence, test, RED transcript, and summary files exist.
- Task commits `e976a63`, `5404e64`, and `43e0741` resolve in git history.
