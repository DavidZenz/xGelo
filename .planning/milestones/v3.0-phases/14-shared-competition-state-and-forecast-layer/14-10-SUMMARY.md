---
phase: 14-shared-competition-state-and-forecast-layer
plan: "10"
subsystem: competition-contracts
tags: [R, source-contracts, normalized-schema, standings, sha256, provenance]

# Dependency graph
requires:
  - phase: 13-source-contracts-and-competition-registry
    provides: v1 source bundles, normalized identity guards, publication hashes, manifests, and transaction replay
  - phase: 14-shared-competition-state-and-forecast-layer
    provides: explicit state-ready decisions from Plans 14-01 and 14-09
provides:
  - explicit Phase 14 v2 fixture, result, and standings schemas
  - fail-closed accepted-boundary normalization with source/artifact/bundle lineage
  - schema-aware staged handoff and publication hashing while retaining v1 replay
affects: [14-11 transaction proof, 14-12 durable promotion, 14-13 match state, 14-14 standings]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - explicit schema-version dispatch with v1 compatibility as the default
    - source wording and immutable identity retained beside canonical state-ready fields
    - typed missing/false/unresolved optional evidence at the accepted boundary

key-files:
  created: []
  modified:
    - R/competition/source_contracts.R
    - R/competition/team_identity.R
    - R/competition/publication_hashes.R
    - R/competition/edition_registry.R
    - scripts/acquire_uefa_snapshot.R
    - tests/testthat/test_phase14_match_state.R
    - tests/testthat/test_phase14_standings.R

key-decisions:
  - "Keep Phase 13 v1 source/normalized replay as the default and select v2 only through explicit schema branches."
  - "Preserve source_status verbatim; match_status and completion_method remain orthogonal, and absent evidence never creates completed state or score axes."
  - "Leave STATE-01 and STATE-02 pending until downstream canonical semantics, reconciliation, transaction proof, and durable promotion plans complete."

patterns-established:
  - "Versioned normalized schemas are exact, hashable, and preserve stable identity/provenance foreign keys."
  - "EURO pre_draw structure tables remain zero-row, schema-complete projections."

requirements-completed: [] # Deliberately pending until all downstream owning plans complete.

coverage:
  - id: D1
    description: "Accepted fixture/result v2 contracts preserve source status, independent lifecycle/completion axes, score evidence, identity, and provenance."
    requirement: STATE-01
    verification:
      - kind: unit
        ref: tests/testthat/test_phase14_match_state.R
        status: pass
      - kind: unit
        ref: tests/testthat/test_phase13_source_contracts.R
        status: pass
    human_judgment: false
  - id: D2
    description: "Accepted standings v2 preserves mapped team/group identity, independent official aggregates, source lineage, and deterministic hashes."
    requirement: STATE-02
    verification:
      - kind: unit
        ref: tests/testthat/test_phase14_standings.R
        status: pass
      - kind: unit
        ref: tests/testthat/test_phase13_publication_hashes.R
        status: pass
    human_judgment: false
  - id: D3
    description: "The source handoff stages fixture/result/standings v2 through the existing dual-edition hash, manifest, loader, and transaction envelope without durable mutation."
    verification:
      - kind: integration
        ref: tests/testthat/test_phase13_publication_integration.R
        status: pass
      - kind: integration
        ref: tests/testthat/test_phase13_publication_transaction.R
        status: pass
      - kind: integration
        ref: tests/testthat/test_phase13_publication_manifests.R
        status: pass
    human_judgment: false

# Metrics
duration: 32min
completed: 2026-08-17
status: complete
---

# Phase 14 Plan 10: Shared competition state and forecast layer Summary

**State-ready v2 source, normalized, standings, publication-hash, and staged-handoff contracts with truthful missing evidence and preserved Phase 13 replay**

## Performance

- **Duration:** 32min 26s
- **Started:** 2026-08-17T13:39:36Z
- **Completed:** 2026-08-17T14:12:02Z
- **Tasks:** 3
- **Files modified:** 7

## Accomplishments

- Added explicit Phase 14 source and normalized fixture/result v2 contracts with independent `source_status`, `match_status`, `completion_method`, score axes, evidence time, and count flags.
- Added standings v2 normalization with mapped team/group identity, nullable official metrics, source bundle/artifact lineage, warnings, and deterministic row hashes.
- Routed staged fixture/result/standings handoffs through v2 schema/hash validation while preserving raw provenance, EURO pre_draw empties, dual-edition transactions, and Phase 13 v1 replay.

## Task Commits

Each task was committed atomically:

1. **Task 1: Extend source and normalized match contracts** - `8724ca0` (test RED), `36fd807` (feat GREEN)
2. **Task 2: Add official standings normalization and hash parity** - `696c20b` (test RED), `af3447b` (feat GREEN)
3. **Task 3: Carry schema v2 through the source handoff normalizer** - `e2fbdc7` (feat)

## Files Created/Modified

- `R/competition/source_contracts.R` - Adds explicit Phase 14 source-shaped v2 projections without changing Phase 13 required capture fields.
- `R/competition/team_identity.R` - Adds v2 fixture/result/standings schemas, typed empty tables, normalization, identity guards, and fail-closed optional evidence handling.
- `R/competition/publication_hashes.R` - Adds explicit v2 publication schema dispatch and automatic v1/v2 table-shape detection.
- `R/competition/edition_registry.R` - Accepts v2 normalized snapshot columns in the existing loader while retaining v1 default validation.
- `scripts/acquire_uefa_snapshot.R` - Emits v2 fixture/result/standings targets only in the source-handoff staging path.
- `tests/testthat/test_phase14_match_state.R` - Tests v2 match schemas, independent axes, provenance, and missing evidence.
- `tests/testthat/test_phase14_standings.R` - Tests v2 standings mapping, official-field independence, lineage rejection, and hash dispatch.

## Verification

- `test_phase14_match_state.R`: 68 passed, 1 pre-existing downstream skip for `phase14_build_canonical_matches` (Plan 14-13).
- `test_phase14_standings.R`: 41 passed, 1 pre-existing downstream skip for `phase14_compute_standings` (Plan 14-14).
- `test_phase13_source_contracts.R`: 175 passed.
- `test_phase13_publication_hashes.R`: 107 passed.
- `test_phase13_publication_integration.R`: 175 passed.
- `test_phase13_publication_manifests.R`: 68 passed.
- `test_phase13_publication_transaction.R`: 117 passed.
- `data/competition/accepted` has no Git status or diff changes; durable accepted CSVs were not changed.

## Decisions Made

- v1 remains the default replay contract; v2 is selected explicitly by schema ID or exact v2 columns.
- Source wording is retained verbatim and canonical fields are not inferred from ambiguous source tokens; missing completion time, kickoff confirmation, split scores, group, aggregates, and counts remain typed unresolved/false values.
- Source bundle/artifact and stable identity links remain validated before row/content hash refresh.
- Shared requirements remain pending until their downstream owning plans finish.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed v2 fixture schema-order projection**
- **Found during:** Task 1 GREEN verification
- **Issue:** The first v2 fixture projection selected schema names as row indices, causing valid v2 rows to fail exact-column ordering.
- **Fix:** Corrected the projection to select columns explicitly before calculating `row_sha256`.
- **Files modified:** `R/competition/team_identity.R`
- **Verification:** `test_phase14_match_state.R` and `test_phase13_source_contracts.R` passed.
- **Committed in:** `36fd807`

**2. [Rule 2 - Missing critical compatibility] Added v2 accepted-snapshot loader dispatch**
- **Found during:** Task 3 integration verification
- **Issue:** The required Phase 13 integration regression reloads staged v2 accepted files through `edition_registry.R`, whose validator only recognized v1 fixture/result columns.
- **Fix:** Added exact v2 schema detection and validation for fixtures, results, and standings while preserving v1 as the default and all existing identity/provenance checks.
- **Files modified:** `R/competition/edition_registry.R`
- **Verification:** `test_phase13_publication_integration.R`, `test_phase13_publication_manifests.R`, and `test_phase13_publication_transaction.R` passed.
- **Committed in:** `e2fbdc7`

**Total deviations:** 2 auto-fixed (1 Rule 1 bug, 1 Rule 2 critical compatibility guard)
**Impact on plan:** Both fixes were necessary for the planned v2 staged graph and listed Phase 13 regressions; no durable accepted data or unrelated workspace dirt was changed.

## Issues Encountered

None unresolved. The two implementation issues above were fixed inline and verified.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

The v2 contract is ready for Plan 14-11 isolated transaction proof and later canonical match/standings consumers. STATE-01 and STATE-02 intentionally remain pending; this plan does not perform durable accepted promotion or claim canonical match/standings semantics.

---
*Phase: 14-shared-competition-state-and-forecast-layer*
*Plan: 14-10*
*Completed: 2026-08-17*

## Self-Check: PASSED

- Summary file exists.
- Task commits `8724ca0`, `36fd807`, `696c20b`, `af3447b`, and `e2fbdc7` exist in Git history.
- No required self-check items are missing.
