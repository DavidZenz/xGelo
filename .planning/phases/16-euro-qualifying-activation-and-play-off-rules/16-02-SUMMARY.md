---
phase: 16-euro-qualifying-activation-and-play-off-rules
plan: 02
subsystem: competition-rules
tags: [uefa, euro-qualifying, article-15, article-23, host-allocation, playoff-topology]

# Dependency graph
requires:
  - phase: 16-euro-qualifying-activation-and-play-off-rules
    provides: Plan 16-00 shared fixtures and Plan 16-01 activation identifiers/source bundle contract
provides:
  - Official Article 15 group ranking and Article 23 comparable best-runner-up ranking
  - Conditional host-slot allocation with deterministic highest-ranked-two selection
  - Conserved qualification ledger and all three accepted play-off topology branches
  - Versioned draw-condition validation with unresolved and unsupported fail-closed states
affects: [16-03 qualification simulation, Phase 17 dashboard payload]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Pure source-lined ranking and allocation tables keyed by stable IDs
    - Canonical rules/source hashes and explicit evidence/exclusion lineage
    - Conditional capacity ledger with scenario-preserving unresolved states

key-files:
  created:
    - .planning/phases/16-euro-qualifying-activation-and-play-off-rules/16-02-SUMMARY.md
  modified:
    - R/competition/uefa_euro_rules.R
    - tests/testthat/test_phase16_euro_qualifying.R
    - .planning/phases/16-euro-qualifying-activation-and-play-off-rules/deferred-items.md

key-decisions:
  - "Host usage is resolved only after complete ranking evidence and accepted host guarantees; unused reserved capacity remains an explicit ledger row."
  - "The two highest-ranked covered hosts consume the two reserved slots when more than two associations are covered."
  - "Missing, partial, stale, or unrecognised draw conditions never select a topology or qualification-ready result."

patterns-established:
  - "Article 15 traces each comparison criterion and counted match IDs, including recursive tied subsets."
  - "Article 23 runner-up comparisons exclude matches against fifth-place teams in groups of five and retain excluded IDs."

requirements-completed: [COMP-04]

coverage:
  - id: D1
    description: "Article 15 group ranking and Article 23 best-runner-up comparison with evidence and exclusion lineage"
    requirement: COMP-04
    verification:
      - kind: unit
        ref: "tests/testthat/test_phase16_euro_qualifying.R#article15|article23|four_host|topology|draw_conditions|conservation"
        status: pass
    human_judgment: false
  - id: D2
    description: "Host-reserved allocation ledger conserves zero, one, two, and multi-host capacity without double counting"
    requirement: COMP-04
    verification:
      - kind: unit
        ref: "tests/testthat/test_phase16_euro_qualifying.R#ranking|host|allocation|phase16_smoke"
        status: pass
    human_judgment: false
  - id: D3
    description: "Official 0/1/2-host play-off topologies and fail-closed draw-condition validation"
    requirement: COMP-04
    verification:
      - kind: unit
        ref: "tests/testthat/test_phase16_euro_qualifying.R#article15|article23|four_host|topology|draw_conditions|conservation"
        status: pass
    human_judgment: false

# Metrics
duration: 48m
completed: 2026-08-24
status: complete
---

# Phase 16 Plan 02: EURO Qualifying Ranking and Topology Summary

**Source-lined EURO qualifying ranking, host-place conservation, best-runner-up allocation, and official play-off topology validation are implemented without guessing unresolved inputs.**

## Performance

- **Duration:** Approximately 48 minutes
- **Started:** 2026-08-24T10:00:00Z (approximate from first task commit)
- **Completed:** 2026-08-24T10:46:33Z
- **Tasks:** 2/2
- **Files modified:** 3 plan-owned files plus required planning metadata

## Accomplishments

- Implemented Article 15 group ranking with head-to-head recursion, official overall tie-break order, stable IDs, counted-match evidence, tiebreak evidence IDs, source lineage, and deterministic row/table hashes.
- Implemented Article 23 comparable runner-up ranking, including group-of-five exclusion of matches against fifth place and explicit excluded-match evidence.
- Implemented direct, host-reserved, best-runner-up, and play-off ledger allocation with zero/one/two-host branches, top-two selection for four covered hosts, explicit unused slots, and no double counting.
- Implemented the three official topologies and versioned accepted draw-condition gates that return `unresolved_draw_conditions` plus `unsupported_topology` instead of inferring a bracket.

## Task Commits

Each TDD task was committed atomically with RED and GREEN gates:

1. **Task 1: Trace one completed group through ranking, host allocation, and place conservation** - `8e63785` (RED tests), `862b07f` (GREEN implementation)
2. **Task 2: Complete mixed-size ranking, four-host selection, draw conditions, and topology validation** - `8325bc1` (RED tests), `0662886` (GREEN implementation)

## Files Created/Modified

- `R/competition/uefa_euro_rules.R` - Article 15/23 ranking, host selector, allocation ledger, topology branches, hashes, and draw-condition validation.
- `tests/testthat/test_phase16_euro_qualifying.R` - completed-group tracer, mixed-size Article 23, best-runner-up, host-branch, conservation, four-host, and invalid-condition tests.
- `deferred-items.md` - preserves prior Phase 14 deferral and records unrelated Phase 14 regression findings from this wave.

## Decisions Made

- Host slots are conditional ledger entries, and a direct host qualifier consumes the host reservation exactly once through the host row.
- Host rank evidence is accepted as source-controlled input; more than two covered hosts select only the two lowest numeric ranks, with boundary ties unresolved rather than guessed.
- Topology eligibility requires a version, canonical SHA-256-shaped hash, accepted source artifact, and complete condition set; unsupported inputs suppress derived qualification eligibility.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed zero-row host placeholder binding and unresolved-slot overcounting**
- **Found during:** Task 2 GREEN verification
- **Issue:** Binding placeholder columns into a zero-row host table failed, and unresolved covered hosts incorrectly converted an unassigned capacity row into a second `host_place_unresolved` row.
- **Fix:** Bind missing columns with zero-length vectors and preserve unassigned capacity as `host_reserved_unused` while only covered associations become unresolved.
- **Files modified:** `R/competition/uefa_euro_rules.R`
- **Verification:** Focused Phase 16 suite passed.
- **Committed in:** `0662886`

**2. [Rule 1 - Bug] Fixed incomplete ranking preflight and empty blocked-trace paths**
- **Found during:** Task 1 implementation
- **Issue:** Derived standings metrics were marked missing before fixture-derived values were applied, and empty blocked results indexed a nonexistent row.
- **Fix:** Apply derivations before missing checks, guard empty traces, and safely resolve absent input columns.
- **Files modified:** `R/competition/uefa_euro_rules.R`
- **Verification:** Focused Phase 16 suite and tracer rerun passed.
- **Committed in:** `862b07f`

### Verification Adjustments

- The plan's `testthat::test_file(..., filter=...)` command is unsupported by the installed testthat version (`unused argument (filter=...)`). The equivalent full focused Phase 16 file was run with `stop_on_failure=TRUE` for every RED/GREEN/tracer gate.
- No package installation, external service, architecture change, or Plan 16-03 simulation work was introduced.

**Total deviations:** 2 auto-fixed bugs plus 1 verification-command adjustment.
**Impact on plan:** All fixes were directly required for typed, capacity-conserving behavior; scope remained within the two Plan 16-02 files and required planning records.

## Verification

- PASS: `tests/testthat/test_phase16_euro_qualifying.R` after Task 1 GREEN and after the autonomous tracer gate.
- PASS: final focused Phase 16 file after Task 2 GREEN.
- PASS: `tests/testthat/test_phase15_nations_league.R`.
- FAIL, pre-existing/out of scope: `tests/testthat/test_phase14_standings.R:686` temporary schema-v2 row-name attribute comparison.
- INCOMPLETE: `tests/testthat/test_phase14_state_bundle.R` exceeded the bounded verification window with no failure output and was stopped cleanly; recorded in `deferred-items.md`.
- NOT RERUN: full repository suite, per plan; Wave 0 baseline remains the captured known failure in `16-BASELINE.md`.

## Known Stubs

None. `phase16_euro_host_placeholder()` creates intentional, source-lined unused reserved-capacity ledger rows; it is not an unimplemented feature.

## Issues Encountered

- The best-runner-up API was missing at the first Task 2 RED gate; the public `select_euro_best_runners_up()` contract was added and wired into allocation.
- The broken-windows append command was not able to update `.planning/WINDOWS.md` because its pre-existing frontmatter counts disagree with its entries. No unrelated ledger repair was attempted.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 16-03 can consume `rank_euro_group()`, `rank_euro_overall()`, `select_euro_best_runners_up()`, `allocate_euro_places()`, and the versioned topology/draw-condition result. Simulation, outcomes, CLI, and dashboard work were intentionally left untouched.

## Self-Check: PASSED

- SUMMARY file exists at the required phase path.
- Task commits `8e63785`, `862b07f`, `8325bc1`, and `0662886` are present in git history.
- Plan-owned source/test changes pass `git diff --check`.

---
*Phase: 16-euro-qualifying-activation-and-play-off-rules*
*Plan: 02*
*Completed: 2026-08-24*
