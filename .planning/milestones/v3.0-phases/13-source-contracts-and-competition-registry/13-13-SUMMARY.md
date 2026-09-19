---
phase: 13-source-contracts-and-competition-registry
plan: "13"
subsystem: competition-publication
tags: [R, source-contracts, raw-json, atomic-publication, rollback, testthat]
requires:
  - phase: 13-source-contracts-and-competition-registry
    provides: source registries, normalized fourteen-target transaction, hash/manifest helpers, and blocked-refresh boundary
provides:
  - public dual-edition raw-source handoff adapter
  - single-transaction acquisition refresh wiring
  - public success, loader, hash, EURO pre_draw, rollback, and blocked-refresh regressions
affects: [phase-14-shared-competition-state, publication, acquisition]
tech-stack:
  added: []
  patterns: [raw JSON rehydration into source-shaped transient handoffs, callback-injected transaction verification]
key-files:
  created: []
  modified:
    - scripts/acquire_uefa_snapshot.R
    - tests/testthat/test_phase13_publication_integration.R
key-decisions:
  - "The public refresh constructs both source-shaped handoffs from the candidate and trusted raw JSON, then invokes the existing fourteen-target transaction exactly once."
  - "Isolated one-edition fixture replay and explicit blocked recovery retain their established publisher boundary for compatibility; complete source registries take the dual-edition public route."
patterns-established:
  - "Raw handoff adapter: resolve trusted paths, verify exact bytes and SHA-256, parse JSON, then build typed source-shaped tables."
  - "Public transaction tests snapshot all target and registry-side bytes and inject every ordered promotion failure."
requirements-completed: [DATA-01, DATA-02, DATA-03, DATA-04, COMP-01]
coverage:
  - id: D1
    description: "Public acquisition refresh rehydrates both editions from raw JSON/source registries and publishes one normalized fourteen-target graph."
    requirement: DATA-01
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase13_publication_integration.R#public refresh rehydrates raw source handoffs and atomically publishes both editions"
        status: pass
    human_judgment: false
  - id: D2
    description: "Successful output has loader-valid hashes, stable identity, and truthful EURO pre_draw empty structures."
    requirement: COMP-01
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase13_publication_integration.R#public refresh rehydrates raw source handoffs and atomically publishes both editions"
        status: pass
    human_judgment: false
  - id: D3
    description: "Every promotion failure rolls back all fourteen targets and registry-side state, while offline main failures create durable blocked-refresh evidence."
    requirement: DATA-04
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase13_publication_integration.R#public refresh restores every target and registry-side file after each promotion failure"
        status: pass
      - kind: integration
        ref: "tests/testthat/test_phase13_publication_integration.R#offline main routes transaction failure to the durable blocked-refresh boundary"
        status: pass
    human_judgment: false
duration: 43m
completed: 2026-08-16
status: complete
---

# Phase 13 Plan 13: Source Contracts and Competition Registry Summary

**Public acquisition now rehydrates dual-edition source handoffs from raw JSON and publishes the normalized fourteen-target graph atomically with complete rollback evidence.**

## Performance

- **Duration:** 43m
- **Started:** 2026-08-16T11:05:00Z
- **Completed:** 2026-08-16T11:48:51Z
- **Tasks:** 2
- **Files modified:** 2 implementation/test files

## Accomplishments

- Added trusted raw-store source handoff rehydration for the companion edition, including exact path, byte-count, raw SHA-256, provenance, typed schema, and EURO `pre_draw` handling.
- Routed complete public refreshes through one callback-testable fourteen-target normalized publication transaction, while retaining isolated one-edition replay and blocked recovery boundaries.
- Replaced reverse-adaptation integration fixtures with raw JSON/source-registry replay and added success, loader/hash, identity, EURO pre_draw, all-index rollback, and offline `phase13_acquire_main()` blocked-refresh coverage.

## Task Commits

Each task was committed atomically:

1. **Task 1: Wire public dual-edition source handoffs and transaction orchestration** - `0109be5` (feat), `14b67fd` (fix), `931cc06` (fix)
2. **Task 2: Prove public-path normalization, loader success, and complete rollback** - `2360058` (test)

## Files Created/Modified

- `scripts/acquire_uefa_snapshot.R` - Builds trusted raw source handoffs, stages both editions into the normalized transaction, exposes the publication callback seam, and preserves legacy/recovery compatibility.
- `tests/testthat/test_phase13_publication_integration.R` - Uses isolated raw/source-registry fixtures and verifies public success, hashes, loader validity, rollback at all fourteen promotion points, and blocked main handling.

## Decisions Made

- Keep normalized accepted CSVs as transaction output only; never reverse-adapt them into source handoffs.
- Require the companion source registry before selecting the dual-edition route, preserving established isolated one-edition fixture replay behavior.
- Preserve the established Plan 13-06 blocked-recovery publisher path for explicit replacement bundle IDs, while normal unblocked production refreshes use the dual-edition transaction.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Compatibility regression] Preserved isolated one-edition fixture replay**
- **Found during:** Task 1 focused compatibility suites
- **Issue:** Existing bounded source-contract tests intentionally use a temporary registry containing only one edition, so the new companion adapter could not build a dual-edition handoff.
- **Fix:** Select the established one-edition publisher only when the companion source registry is absent; complete source registries still require the public dual-edition route.
- **Files modified:** `scripts/acquire_uefa_snapshot.R`
- **Verification:** `test_phase13_source_contracts.R` passed.
- **Committed in:** `14b67fd`

**2. [Rule 1 - Compatibility regression] Preserved blocked recovery with replacement bundle IDs**
- **Found during:** Task 1 focused compatibility suites
- **Issue:** The existing Plan 13-06 recovery test uses a distinct replacement bundle ID and validates the explicit operator/validation recovery boundary.
- **Fix:** Keep that established recovery publisher/update sequence for already-blocked editions, including explicit operator validation, without weakening the normal public transaction route.
- **Files modified:** `scripts/acquire_uefa_snapshot.R`
- **Verification:** `test_phase13_refresh_failure.R` passed.
- **Committed in:** `14b67fd`, `931cc06`

**3. [Rule 1 - Metadata regression] Retained rebuilt candidate provenance**
- **Found during:** Task 1 focused compatibility suites
- **Issue:** The legacy publisher returns a rebuilt candidate containing normalized manifest provenance; discarding that return caused refresh-history validation to compare stale hashes.
- **Fix:** Preserve the rebuilt candidate returned by the compatibility publisher before updating registries.
- **Files modified:** `scripts/acquire_uefa_snapshot.R`
- **Verification:** `test_phase13_refresh_failure.R` passed.
- **Committed in:** `931cc06`

**Total deviations:** 3 auto-fixed issues (Rule 1 compatibility/metadata corrections)
**Impact on plan:** Narrow compatibility fixes only; the complete public path remains the planned raw-source to fourteen-target transaction.

## Issues Encountered

The repository had unrelated dirty benchmark outputs, debug notes, raw artifacts, and temporary directories. They were left untouched and uncommitted as requested.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 13 Plan 13 is complete and ready for Phase 13 verification. The public acquisition path is fixture-backed and offline-testable; no downstream dashboard, forecast, competition-rule, or live-network code was changed.

## Verification

- `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_publication_integration.R", reporter="summary")'`
- `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_source_contracts.R", reporter="summary")'`
- `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_publication_hashes.R", reporter="summary")'`
- `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_publication_manifests.R", reporter="summary")'`
- `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_publication_transaction.R", reporter="summary")'`
- `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_refresh_failure.R", reporter="summary")'`
- Isolated source load check confirmed `phase13_acquire_publish_refresh()` and `phase13_publish_normalized_editions()` are functions.

## Self-Check: PASSED

- Summary file exists.
- Task commits `0109be5`, `14b67fd`, `931cc06`, and `2360058` exist in Git history.
- Stub scan found no placeholder or empty UI-flow patterns in the modified implementation/test files.

---
*Phase: 13-source-contracts-and-competition-registry*
*Plan: 13*
*Completed: 2026-08-16*
