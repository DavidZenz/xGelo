---
phase: 20-ucl-rules-state-and-tournament-outcomes
plan: "04"
subsystem: competition-outcomes
tags: [ucl, knockout-resolution, stage-reconciliation, canonical-hashing, replay]

# Dependency graph
requires:
  - phase: 20-ucl-rules-state-and-tournament-outcomes
    provides: "Validated UCL league state, conditional simulation, legal pre-draw paths, and typed draw evidence"
provides:
  - "Editioned two-leg and neutral-final UCL knockout resolution"
  - "Stage-event and progression reconciliation through champion"
  - "Canonical, replay-safe ten-file UCL outcome candidate and writer"
affects: [phase21-ucl-dashboard, ucl-verification, competition-outcomes]

# Tech tracking
tech-stack:
  added: []
  patterns: ["typed suppressed/unresolved stage events", "manifest self-hash with canonical-v2 table identity", "atomic temporary staging with read-back validation"]

key-files:
  created: [.planning/phases/20-ucl-rules-state-and-tournament-outcomes/20-04-RED.md, .planning/phases/20-ucl-rules-state-and-tournament-outcomes/20-04-SUMMARY.md]
  modified: [R/competition/uefa_champions_league_simulation.R, R/competition/uefa_champions_league_outcomes.R, tests/testthat/helper_uefa_champions_league.R, tests/testthat/test_uefa_champions_league.R]

key-decisions:
  - "Resolve non-final ties from aggregate regulation goals only; apply second-leg extra time only at a tied aggregate, then penalties, with no away-goals criterion."
  - "Represent the final as one neutral-venue match with no home advantage and preserve unresolved/suppressed later stages when draw evidence is incomplete."
  - "Make the exact ten-file inventory, row hashes, table hashes, parent lineage, and manifest self-hash prerequisites for any candidate write; production eligibility remains false."

patterns-established:
  - "Stage-event detail remains in knockout_paths.csv, including participant, leg/venue, aggregate, ET, penalty, draw, and source lineage fields."
  - "Canonical artifact ordering is semantic-key sorted and excludes timestamps/filesystem order, enabling byte-identical repeat and reverse-input replay."

requirements-completed: [UCLOUT-04, UCLOUT-05, UCLOUT-06]

coverage:
  - id: D1
    description: "Two-leg aggregate/no-away-goals/ET/penalty semantics and neutral-final resolution are editioned and topology-gated."
    requirement: UCLOUT-04
    verification:
      - kind: unit
        ref: tests/testthat/test_uefa_champions_league.R#20-04 RED: two-leg resolution is editioned, aggregate-only, and stage-event complete
        status: pass
      - kind: unit
        ref: tests/testthat/test_uefa_champions_league.R#20-04 RED: neutral final resolves regulation, extra time, and penalties without home advantage
        status: pass
    human_judgment: false
  - id: D2
    description: "Stage input/output counts, league bands, exact probability bounds/sums, and monotone progression remain reconciled with typed unresolved states."
    requirement: UCLOUT-05
    verification:
      - kind: integration
        ref: tests/testthat/test_uefa_champions_league.R#20-04 RED: stage input/output conservation and progression are exact and monotone
        status: pass
    human_judgment: false
  - id: D3
    description: "The closed ten-file outcome inventory validates exact schemas, lineage, row/table hashes, manifest self-hash, replay identity, and tamper rejection before writing."
    requirement: UCLOUT-06
    verification:
      - kind: integration
        ref: tests/testthat/test_uefa_champions_league.R#20-04 RED: knockout paths and outcome inventory persist complete lineage
        status: pass
      - kind: integration
        ref: rtk Rscript --vanilla -e byte replay/read-back probe for normal and reverse candidates
        status: pass
    human_judgment: false

# Metrics
duration: 46m
completed: 2026-09-21
status: complete
---

# Phase 20 Plan 04: UCL knockout resolution and canonical outcomes Summary

**Edition-correct UCL knockout mechanics with reconciled stage probabilities and a byte-replayable ten-file outcome bundle**

## Performance

- **Duration:** 46m
- **Started:** 2026-09-21T19:02:00Z
- **Completed:** 2026-09-21T19:47:51Z
- **Tasks:** 2
- **Files modified:** 6 (including this summary)

## Accomplishments

- Implemented strict UCL two-leg resolution with rank-derived seeded return-leg order, venue/topology validation, aggregate regulation/final totals, no away-goals logic, second-leg extra time, and post-extra-time penalties.
- Implemented neutral-final resolution with explicit venue semantics and no home advantage; persisted all stage-event fields in `knockout_paths.csv` and retained typed suppressed/unresolved play-off-through-champion rows when the edition draw procedure is missing.
- Reconciled stage counts and progression probabilities to stage inputs and 36-club league bands, enforcing probability bounds, sums, and per-club monotonicity.
- Replaced the former one-row outcome record with an exact ten-file registry, exact schemas, canonical-v2 row/table hashes, parent/source/rules/model/draw/cutoff/seed lineage, manifest self-hash, and pre-write read-back validation.
- Confirmed repeated/reversed candidates write byte-identical CSV artifacts and that row/manifest tampering or production promotion is rejected.

## Task Commits

Each task was committed atomically:

1. **Task 1: Write RED contracts for UCL stage resolution and outcome reconciliation** - `0e144d7` (test)
2. **Task 1 RED evidence transcript** - `f1b79d5` (docs)
3. **Task 2: Implement UCL knockout resolution, progression reconciliation, and canonical outcomes** - `28e8b64` (feat)

The summary is committed separately after self-check.

## Files Created/Modified

- `R/competition/uefa_champions_league_simulation.R` - strict two-leg/final resolvers, stage-event capture, event conservation, and progression validation.
- `R/competition/uefa_champions_league_outcomes.R` - exact ten-file schemas/inventory, canonical identity, manifest self-hash, tamper validation, and atomic read-back writer.
- `tests/testthat/helper_uefa_champions_league.R` - UCL two-leg, final, stage-event, and progression fixtures.
- `tests/testthat/test_uefa_champions_league.R` - RED/GREEN contracts for mechanics, reconciliation, inventory, lineage, tamper rejection, and replay.
- `.planning/phases/20-ucl-rules-state-and-tournament-outcomes/20-04-RED.md` - fresh-process non-zero RED transcript and commit evidence.
- `.planning/phases/20-ucl-rules-state-and-tournament-outcomes/20-04-SUMMARY.md` - this execution summary.

## Decisions Made

- The unresolved `draw_procedure_2026_27` evidence remains explicit; exact draw-conditioned outcomes are suppressed rather than inferred.
- Later knockout/champion stage events use typed `suppressed`/`unresolved` rows with lineage and no fabricated participants, venues, scores, or draw IDs.
- A candidate must have the complete ten-file set and valid hashes before the writer stages or publishes anything; fixture authority is never promoted.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected scalar logical conditions in the new resolver and reconciliation code**
- **Found during:** Task 2 (focused GREEN verification)
- **Issue:** Vectorized `vapply()` results were passed directly to scalar `if` expressions, causing runtime errors; the progression missing-value guard had the same scalar/vector coercion issue.
- **Fix:** Reduced vector checks with `any()` and made the progression guard elementwise.
- **Files modified:** `R/competition/uefa_champions_league_simulation.R`
- **Verification:** Focused UCL suite, Phase 15 analog suite, and Phase 16 analog suite passed.
- **Committed in:** `28e8b64`

**Total deviations:** 1 auto-fixed (Rule 1)
**Impact on plan:** The fixes were local correctness repairs; no architecture, authority, or scope expansion was introduced.

## Issues Encountered

- The existing one-row manifest expectation was updated to assert the new exact ten-row manifest contract.
- The intentionally malformed progression test now uses an out-of-bounds value so the contract tests a deterministic conservation failure rather than a still-monotone sequence.
- No authentication gates occurred. No package installation or external service configuration was required.

## Known Stubs

None. The suppressed/unresolved stage rows are intentional typed evidence states required while the edition-specific draw artifact remains unavailable, not placeholder data.

## Threat Flags

None. The implementation stays within the plan's declared resolver, stage-reconciliation, and candidate-to-output-root trust boundaries.

## Verification

- `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_uefa_champions_league.R", reporter="summary", stop_on_failure=TRUE)'` — passed.
- `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase15_nations_league.R", reporter="summary", stop_on_failure=TRUE)'` — passed.
- `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase16_euro_qualifying.R", reporter="summary", stop_on_failure=TRUE)'` — passed.
- Fresh custom probe — normal/reverse candidates produced identical hashes and all ten CSV bytes; manifest and production-promotion tampering were rejected.

## Next Phase Readiness

Phase 21 can consume the read-only sibling outcome inventory and stage-event fields. Exact draw-conditioned outcomes remain intentionally unavailable until reviewed same-edition draw evidence is accepted, and the fixed Phase 19 resolver continues to keep production fail-closed.

STATE.md, ROADMAP.md, REQUIREMENTS.md, and PROJECT.md were intentionally not modified because Phase 19 remains human-needed and Phase 20 is deliberately staged.

---
*Phase: 20-ucl-rules-state-and-tournament-outcomes*
*Completed: 2026-09-21*

## Self-Check: PASSED

- Summary file exists at the declared phase path.
- Task commits `0e144d7`, `f1b79d5`, and `28e8b64` resolve in git history.
- Focused and mandated analog verification commands passed.
- No out-of-scope user-owned or generated files were staged.
