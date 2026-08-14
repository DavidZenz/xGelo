---
phase: 13-source-contracts-and-competition-registry
plan: "04"
subsystem: data-capture
tags: [R, source-contracts, stable-identity, accepted-publication, provenance, sha256]

# Dependency graph
requires:
  - phase: 13-03
    provides: durable team-identity and competition-edition registries with lifecycle provenance
  - phase: 13-09
    provides: staged source-shaped Nations League accepted handoff
  - phase: 13-10
    provides: truthful source-shaped EURO pre_draw accepted handoff
provides:
  - normalized accepted fixture publication through the durable identity registry
  - normalized accepted result publication joined exactly to fixture source identity
  - score, identity, edition, display-name, status, and artifact-lineage safeguards
affects: [13-05, 13-08, 13-11, 13-12, accepted-publication, competition-registry]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - exact source_fixture_id joins from accepted results to normalized fixtures
    - stable canonical IDs copied separately from preserved source display values
    - staged accepted-table projections refresh local provenance hashes before promotion

key-files:
  created: []
  modified:
    - R/competition/team_identity.R
    - scripts/acquire_uefa_snapshot.R
    - tests/testthat/test_phase13_source_contracts.R
    - tests/testthat/test_phase13_competition_registry.R

key-decisions:
  - "Accepted results inherit all identity, display, edition, schedule, mapping, and fixture-artifact fields from the exact normalized fixture match; source status and valid scores remain result-owned."
  - "Score-only changes are permitted and change the result row hash, while optional source identity or edition fields must match the normalized fixture contract."
  - "EURO pre_draw results use the explicit registry edition when the normalized fixture table is empty, preserving an exact zero-row schema without fabricated records."
  - "Canonical/hash helper extraction and all-target atomic rollback remain owned by Plans 13-11 and 13-12."

patterns-established:
  - "Result normalization rejects duplicate or unknown source fixture keys before accepted promotion."
  - "Goal values are either paired non-negative whole numbers or paired missing values for unscheduled results; completed statuses require scores."
  - "Accepted publication validates the original source bundle and manifest before rebuilding normalized projections, preserving fail-closed forged-candidate behavior."

requirements-completed: [DATA-01, DATA-02, DATA-03]

coverage:
  - id: D1
    description: "Accepted fixture rows pass through durable team identity normalization while retaining UEFA source IDs, display names, edition, mapping metadata, and row hashes."
    requirement: DATA-03
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase13_source_contracts.R#accepted fixture publication uses the durable identity registry and preserves source values"
        status: pass
      - kind: integration
        ref: "Rscript --vanilla -e 'testthat::test_file(\"tests/testthat/test_phase13_source_contracts.R\")'"
        status: pass
    human_judgment: false
  - id: D2
    description: "Accepted result rows use the exact fixture source key, preserve source status and scores, carry both artifact links, and emit the normalized result contract."
    requirement: DATA-03
    verification:
      - kind: unit
        ref: "tests/testthat/test_phase13_competition_registry.R#accepted results inherit exact fixture identity and preserve valid source scores"
        status: pass
      - kind: integration
        ref: "Rscript --vanilla -e 'testthat::test_file(\"tests/testthat/test_phase13_source_contracts.R\"); testthat::test_file(\"tests/testthat/test_phase13_competition_registry.R\")'"
        status: pass
    human_judgment: false
  - id: D3
    description: "EURO pre_draw accepted fixtures and results remain schema-complete and empty, with no fabricated competition rows."
    requirement: DATA-01
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase13_source_contracts.R#accepted publication normalizes result identity and emits empty EURO result schema"
        status: pass
      - kind: unit
        ref: "tests/testthat/test_phase13_competition_registry.R#empty EURO pre-draw results retain the exact normalized result schema"
        status: pass
    human_judgment: false
  - id: D4
    description: "Duplicate, unknown, invalid, or mismatched result inputs fail closed, while later-row append, reorder, and score-only changes preserve baseline identity and edition assignments."
    requirement: DATA-03
    verification:
      - kind: unit
        ref: "tests/testthat/test_phase13_competition_registry.R#accepted result joins reject duplicate, unknown, invalid, and mismatched identity inputs"
        status: pass
      - kind: unit
        ref: "tests/testthat/test_phase13_competition_registry.R#accepted result identity is stable under later-row append, reorder, and score changes"
        status: pass
    human_judgment: false

# Metrics
duration: 27min
completed: 2026-08-14
status: complete
---

# Phase 13 Plan 04: Accepted Fixture and Result Identity Summary

**Accepted UEFA fixtures and results now publish through stable team/edition identity joins with preserved source provenance and fail-closed score semantics.**

## Performance

- **Duration:** 27 min
- **Started:** 2026-08-14T12:33:28Z
- **Completed:** 2026-08-14T13:00:28Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Routed accepted fixture publication through the durable team identity and edition registries, retaining UEFA IDs, display names, lifecycle, artifact lineage, mapping metadata, and row hashes.
- Added the exact normalized result schema and source-fixture-key join, including paired score validation, result/fixture artifact links, optional identity/edition consistency checks, and stable score-only update behavior.
- Kept EURO 2028 qualifying in a truthful `pre_draw` state with exact zero-row normalized fixture and result schemas; duplicate, unknown, invalid, forged-identity, and forged-edition inputs fail before accepted replacement.

## Task Commits

Each task was committed atomically:

1. **Task 1: Normalize accepted fixtures from the durable identity registry** - `ef0c40f` (feat)
2. **Task 2: Normalize accepted competition results from fixture identity** - `da34ff9` (feat)

## Files Created/Modified

- `R/competition/team_identity.R` - normalized result schema, empty-table contract, exact fixture join, score validation, and identity/edition guards.
- `scripts/acquire_uefa_snapshot.R` - accepted result projection after normalized fixture publication.
- `tests/testthat/test_phase13_source_contracts.R` - production-path Nations League and EURO normalization/provenance assertions.
- `tests/testthat/test_phase13_competition_registry.R` - direct result join, score-only, append/reorder, empty pre_draw, and fail-closed identity regressions.

## Decisions Made

- Normalized results inherit identity-bearing and display-bearing fields from normalized fixtures; the source result owns status and score values.
- Empty pre_draw tables use the explicit edition context because zero-row fixture tables cannot carry a row-local edition value.
- Plan 13-11 remains responsible for shared canonical/hash helpers, and Plan 13-12 remains responsible for atomic multi-target promotion and rollback.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Preserved original candidate validation before normalized projection rebuild**
- **Found during:** Task 1 (Normalize accepted fixtures from the durable identity registry)
- **Issue:** Rebuilding normalized tables before validating the original manifest could discard a forged candidate link and allow tampered provenance to reach the staged writer.
- **Fix:** Validate the original source bundle, raw bytes, and manifest before deriving normalized accepted tables; retain the normalized rebuild only after the source-shaped candidate is proven valid.
- **Files modified:** `scripts/acquire_uefa_snapshot.R`, `tests/testthat/test_phase13_source_contracts.R`
- **Verification:** Forged-candidate rejection and the full source-contract suite passed.
- **Committed in:** `ef0c40f`

**2. [Rule 1 - Bug] Allowed explicit edition context for empty EURO result normalization**
- **Found during:** Task 2 (Normalize accepted competition results from fixture identity)
- **Issue:** An empty normalized fixture table has no row from which to derive `edition_id`, so the first implementation rejected the valid EURO `pre_draw` publication path.
- **Fix:** Require and validate the explicit registry edition when normalized fixtures are empty, while still rejecting any non-empty result row without an exact fixture match.
- **Files modified:** `R/competition/team_identity.R`, `tests/testthat/test_phase13_competition_registry.R`, `tests/testthat/test_phase13_source_contracts.R`
- **Verification:** Combined focused source/registry gate passed with 178 source assertions and 78 registry assertions.
- **Committed in:** `da34ff9`

---

**Total deviations:** 2 auto-fixed (Rule 1: 2 bugs)
**Impact on plan:** Both fixes were required for fail-closed provenance and truthful zero-row pre_draw publication; no Plan 13-11 or 13-12 scope was added.

## Issues Encountered

The managed checkout initially denied creation of `.git/index.lock`; staging and committing were completed through the approved Git escalation, with repository hooks enabled. No checkpoint, authentication gate, or unresolved blocker occurred.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

The accepted fixture/result identity graph is ready for the dependent accepted-snapshot loader and later canonical/hash sealing. Shared canonical/hash helper extraction and atomic transaction/rollback remain intentionally untouched for Plans 13-11 and 13-12.

---
*Phase: 13-source-contracts-and-competition-registry*
*Completed: 2026-08-14*

## Self-Check: PASSED

- Summary file exists at the expected phase path.
- Task commits `ef0c40f` and `da34ff9` are present in Git history.
- Focused source-contract and competition-registry verification passed.
