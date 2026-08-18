---
phase: 14-shared-competition-state-and-forecast-layer
plan: 20
subsystem: testing
tags: [R, testthat, competition-state, replay, rollback, lineage]

# Dependency graph
requires:
  - phase: 14-shared-competition-state-and-forecast-layer
    provides: truthful EURO pre-draw durable state and approved release lineage from Plan 14-19
provides:
  - shared failure fan-out and edition-local state isolation
  - no-silent-drop inventory and fixture/status equality validation
  - deterministic normal/reversed/repeated replay checks with non-promoting --replay-check
  - resolver model cutoff and feature cutoff durable read-back validation
affects: [phase-14 completion, phase-15, phase-16, phase-17]

# Tech tracking
tech-stack:
  added: []
  patterns: [canonical tabular input ordering at the state boundary, suppressed full-schema lineage rows, dry-run replay comparison]

key-files:
  created: [.planning/phases/14-shared-competition-state-and-forecast-layer/deferred-items.md]
  modified: [R/competition/state_bundle.R, scripts/build_competition_state.R, tests/testthat/test_phase14_state_bundle.R]

key-decisions:
  - "Canonicalize every tabular state input before shared preflight or edition-local construction so caller ordering cannot change hashes or forecast evidence."
  - "Represent suppressed source fixtures with the same complete status schema and row hashes as available fixtures, preserving no-silent-drop equality."
  - "Keep --replay-check strictly dry-run and non-promoting; existing Phase 13 publication rollback remains the durable promotion boundary."

patterns-established:
  - "Every production candidate carries source fixture IDs and validates equality against canonical, status, and manifest inventories."
  - "Every valid state artifact carrying rows must carry the approved resolver model_data_cutoff; available status and forecast rows must agree on per-fixture feature_cutoff_utc."

requirements-completed: [STATE-04, FORECAST-03]

coverage:
  - id: D1
    description: "Shared required failures fan out while inactive optional xG and edition-local failures remain correctly scoped."
    requirement: STATE-04
    verification:
      - kind: unit
        ref: tests/testthat/test_phase14_state_bundle.R#shared failure fan-out preserves every source fixture as suppressed status
        status: pass
    human_judgment: false
  - id: D2
    description: "Normal, reversed, and repeated both-edition builds replay to identical hashes without durable mutation."
    requirement: FORECAST-03
    verification:
      - kind: integration
        ref: tests/testthat/test_phase14_state_bundle.R#reversed input order has identical canonical hashes and replay-check never promotes
        status: pass
    human_judgment: false
  - id: D3
    description: "Promotion failure restores every target byte and leaves unrelated paths unchanged."
    verification:
      - kind: integration
        ref: tests/testthat/test_phase13_publication_transaction.R#failure after every ordered target promotion restores the complete publication graph
        status: pass
    human_judgment: false
  - id: D4
    description: "Durable state read-back verifies exact inventory and approved resolver cutoff lineage."
    requirement: STATE-04
    verification:
      - kind: integration
        ref: Rscript --vanilla -e 'source("R/competition/state_bundle.R"); phase14_validate_competition_state_bundle("outputs/competition/uefa_euro_2028_qualifying")'
        status: pass
    human_judgment: false

# Metrics
duration: 1h 15m
completed: 2026-08-18
status: complete
---

# Phase 14 Plan 20: Shared State Isolation and Replay Summary

**Production competition-state batching now preserves edition isolation and source coverage, propagates approved cutoff lineage, and verifies deterministic non-promoting replay.**

## Performance

- **Duration:** 1h 15m
- **Started:** 2026-08-18T08:23:15Z
- **Completed:** 2026-08-18T09:38:11Z
- **Tasks:** 2 complete
- **Files modified:** 3 implementation/test files, plus phase execution notes

## Accomplishments

- Shared identity, release, history, and active-predictor evidence failures fan out to both edition candidates; inactive optional national-team xG remains audited without invalidation.
- Edition-local resources are partitioned before construction, suppressed source fixtures retain complete status lineage, and exact eleven-artifact inventories, row counts, hashes, and parent links are validated.
- `--replay-check` now executes normal, reversed-input, and repeated both-edition dry-runs, compares canonical hashes and fixture inventories, and guarantees no durable promotion.
- Valid status, forecast, compact top-10, manifest, and durable read-back data are checked against the approved resolver `model_data_cutoff`; available fixtures also require matching feature cutoffs.
- Existing durable EURO pre-draw state validates successfully. No missing Nations League durable output was fabricated, and Phase 15/16/17 behavior was not changed.

## Task Commits

Each task was committed atomically:

1. **Task 14-20-01: Enforce shared-failure fan-out and edition-specific isolation** - `e112aa0` (`feat`)
2. **Task 14-20-02: Prove deterministic full-batch replay and equality** - `fadc124` (`feat`)

The TDD RED contract for both tasks was committed first as `bd2c74e` (`test`).

**Plan metadata:** pending final docs commit.

## Files Created/Modified

- `R/competition/state_bundle.R` - Canonical input ordering, shared/local failure status fan-out, source/output equality checks, cutoff lineage validation, and durable resolver read-back.
- `scripts/build_competition_state.R` - `--replay-check`, fixed startup seed, normal/reversed/repeated replay comparison, and non-promoting result envelope.
- `tests/testthat/test_phase14_state_bundle.R` - Isolation, suppressed-coverage, cutoff-lineage, reversed-input, replay, and durable-mutation assertions.
- `.planning/phases/14-shared-competition-state-and-forecast-layer/deferred-items.md` - Out-of-scope pre-existing full-suite fixture-seed failure ledger.

## Verification

- Focused Phase 14 state bundle: **162 passed, 0 failed, 0 warnings, 0 skips**.
- Focused Phase 13 refresh-failure regression: **40 passed, 0 failed, 0 warnings, 0 skips**.
- Phase 13 publication transaction rollback regression: **117 passed, 0 failed, 0 warnings, 0 skips**; this includes failure injection after every ordered promotion and exact byte/unrelated-path checks.
- Durable EURO read-back validator: **TRUE**.
- Required full suite command `Rscript --vanilla -e 'testthat::test_dir("tests/testthat")'`: stopped at testthat's default maximum after **10 pre-existing failures**: five in `test_phase13_publication_hashes.R` and five in `test_phase13_publication_manifests.R`. All share the fixture-seed error `arguments imply differing number of rows: 156, 0`, before Phase 14 state code is loaded. The passed Phase 13 publication-integration context immediately before the failures reported **175** assertions. Details are recorded in `deferred-items.md`.

## Decisions Made

- Keep the shared state boundary deterministic by ordering all tabular inputs before preflight, feature construction, and manifest hashing.
- Preserve a complete, hashed status row for every suppressed source fixture so failure paths cannot silently drop inventory.
- Treat `--replay-check` as an isolated dry-run verification path; it never promotes or rewrites durable state.
- Preserve the existing Phase 13 publication transaction as the rollback implementation and verify it directly rather than changing Phase 13 behavior.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected cutoff lineage validation for repeated fixtures**
- **Found during:** Task 14-20-02
- **Issue:** The validator compared the number of unique cutoff values with the number of rows, rejecting valid batches with one resolver cutoff repeated across multiple fixtures.
- **Fix:** Validate every row for non-empty cutoff content, then compare the unique observed values with the resolver cutoff.
- **Files modified:** `R/competition/state_bundle.R`
- **Verification:** Focused state bundle suite passed with 162 assertions.
- **Committed in:** `e112aa0`

**2. [Rule 1 - Bug] Completed suppressed status lineage rows**
- **Found during:** Task 14-20-01
- **Issue:** Failure fan-out rows returned the 41-column pre-hash lineage shape and could not satisfy the exact production status inventory.
- **Fix:** Apply the shared status row hash before selecting the exact 42-column status schema and mark identity failures unresolved.
- **Files modified:** `R/competition/state_bundle.R`
- **Verification:** Shared failure fan-out and focused refresh-failure regressions passed.
- **Committed in:** `e112aa0`

**3. [Rule 1 - Bug] Made all replay inputs order-independent**
- **Found during:** Task 14-20-02
- **Issue:** Reversing team, Elo, and other tabular inputs changed feature evidence and forecast hashes even when canonical fixture rows were unchanged.
- **Fix:** Canonically order every tabular input at the state-batch boundary before shared preflight and candidate construction.
- **Files modified:** `R/competition/state_bundle.R`
- **Verification:** Normal/reversed direct replay boundary check and Phase 14 replay tests passed.
- **Committed in:** `e112aa0`

**Total deviations:** 3 auto-fixed bugs.
**Impact on plan:** All fixes were required to satisfy the specified isolation, lineage, and deterministic replay acceptance criteria; no unrelated behavior was changed.

## Issues Encountered

The required repository-wide test command remains blocked by an existing Phase 13 fixture-seed data-shape mismatch. It is outside this plan's files and occurs before Phase 14 state code is loaded, so it was not modified. The focused Phase 14, Phase 13 refresh-failure, and Phase 13 rollback gates are green.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 14's shared state and forecast boundary is ready for sequential continuation. No Phase 15/16 behavior or Phase 17 public dashboard promotion was introduced. Resolve the deferred Phase 13 fixture-seed mismatch before treating the entire repository suite as green.

---
*Phase: 14-shared-competition-state-and-forecast-layer*
*Plan: 20*
*Completed: 2026-08-18*

## Self-Check: PASSED

- Summary and deferred-items files exist on disk.
- RED and both task implementation commits are present in git history.
- Focused, rollback, and durable read-back verification claims above match the recorded command results.
