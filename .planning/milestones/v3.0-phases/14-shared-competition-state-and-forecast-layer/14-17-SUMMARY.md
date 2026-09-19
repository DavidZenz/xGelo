---
phase: 14-shared-competition-state-and-forecast-layer
plan: "17"
subsystem: competition-state-forecast
tags: [R, testthat, production-batch, deterministic-replay, lineage, G40]

# Dependency graph
requires:
  - phase: 14-shared-competition-state-and-forecast-layer
    provides: canonical match identity, edition lifecycle, cutoff-safe form, and approved calibrated release authority from Plans 14-13 through 14-16
provides:
  - vectorized no-silent-drop production fixture forecast batches with G=40 local grids and compact top-10 outputs
  - validated one/both-edition in-memory state candidates with exact eleven-artifact manifests and scoped failure semantics
  - fixed-seed script-relative dry-run/build entrypoint without Phase 17 promotion
affects: [phase-14-18, phase-14-19, phase-14-20, phase-15, phase-16, shared-dashboard-forecast-consumers]

# Tech tracking
tech-stack:
  added: []
  patterns: [batch-once model prediction, immutable active-predictor evidence, exact artifact inventory, deterministic hash replay, forecastable-row shared preflight]

key-files:
  created:
    - scripts/build_competition_state.R
  modified:
    - R/competition/forecast_layer.R
    - R/competition/state_bundle.R
    - tests/testthat/test_phase14_forecast_layer.R
    - tests/testthat/test_phase14_state_bundle.R

key-decisions:
  - "The approved selector remains the sole release authority; each batch resolves the selector and immutable model manifest once and carries release/model/calibrator identities through every available row and candidate manifest."
  - "The exact eleven-artifact state inventory is represented in memory before later promotion; the validator checks fixture/status/forecast/grid/top10 equality, parent hashes, lineage, and fixed G=40 boundaries."
  - "Shared active-predictor evidence is preflighted only for forecastable fixtures; kickoff-unconfirmed and other ineligible rows remain auditable edition-local suppressions rather than causing shared fan-out."
  - "Inactive national-team xG remains explicitly unavailable/NA under the Elo-only incumbent, while xG-active releases require point-in-time evidence and suppress uncovered eligible fixtures."
  - "`set.seed(14017L)` is fixed at script startup, and the script performs no durable state publication; later plans own promotion."

patterns-established:
  - "Every supplied fixture is represented by exactly one available or suppressed status row; available forecasts, local grids, and compact rows must have identical fixture identity coverage."
  - "State batch candidates are edition-isolated, with shared identity/release/strength/history preflight and explicit shared versus edition_local failure scope."

requirements-completed: [STATE-04, FORECAST-01, FORECAST-02, FORECAST-03]

coverage:
  - id: D1
    description: "Production forecast batches preserve every fixture, enforce immutable release-active evidence, emit calibrated lineage, G=40 score grids, and deterministic compact top-10 rows."
    requirement: FORECAST-01
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase14_forecast_layer.R#production forecast batch preserves exact fixture/status/grid/top10 identity and lineage"
        status: pass
      - kind: other
        ref: "Rscript --vanilla -e 'testthat::test_file(\"tests/testthat/test_phase14_forecast_layer.R\", stop_on_failure=TRUE)'"
        status: pass
    human_judgment: false
  - id: D2
    description: "One/both-edition state candidates expose exact isolated inventory, manifests, parent hashes, validation, pre_draw emptiness, and shared/local failure scope."
    requirement: STATE-04
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase14_state_bundle.R#production state batch exposes exact isolated inventory and validates candidates"
        status: pass
      - kind: integration
        ref: "tests/testthat/test_phase14_state_bundle.R#shared identity failure fans out before edition work while local failure stays local"
        status: pass
    human_judgment: false
  - id: D3
    description: "The script-relative entrypoint accepts an explicit edition or both, fixes startup seed 14017, supports injectable dry-run replay, and performs no durable mutation."
    requirement: FORECAST-03
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase14_state_bundle.R#build script uses fixed startup seed and dry-run replay without durable mutation"
        status: pass
      - kind: other
        ref: "Rscript scripts/build_competition_state.R --edition-id both --dry-run"
        status: pass
    human_judgment: false

# Metrics
duration: 47min
completed: 2026-08-17
status: complete
---

# Phase 14 Plan 17: Production Batch State and Forecast Summary

**Deterministic production-batch forecasts and edition-isolated state candidates with exact lineage, G=40 local uncertainty, scoped failure fan-out, and fixed-seed replay.**

## Performance

- **Duration:** 47 min
- **Started:** 2026-08-17T20:52:09+02:00
- **Completed:** 2026-08-17T21:38:50+02:00
- **Tasks:** 2 completed
- **Files modified:** 5

## Accomplishments

- Expanded `phase14_build_fixture_forecasts()` into a deterministic production batch boundary: canonical adapter coverage, complete suppression reasons, one release/feature/prediction call per batch, exact input/status equality, immutable active/dropped predictor lineage, calibrated dual-simplex checks, fixed G=40 grids, and compact top-10 output.
- Added `phase14_build_competition_state_batch()` and `phase14_validate_competition_state_bundle()` with one shared preflight, edition-local construction, exact eleven-artifact inventory, row/content/parent hashes, model/release/calibrator/cutoff/xG audit fields, and truthful EURO `pre_draw` zero rows.
- Added `scripts/build_competition_state.R` with script-relative root resolution, explicit `--edition-id <id|both>`, `--dry-run`, fixed startup seed `14017L`, injectable callbacks, fail-closed validation, and no durable promotion.
- Completed both TDD cycles: RED tests precede production commits, followed by the exact combined fresh-process verification with 128 forecast assertions and 129 state assertions, zero failures, warnings, or skips.

## Task Commits

Each task was committed atomically:

1. **Task 14-17-01: Expand complete suppression, G=40 uncertainty, and D-20 lineage** - `77b034d` (test: RED contract)
2. **Task 14-17-01: Expand complete suppression, G=40 uncertainty, and D-20 lineage** - `c353364` (feat: GREEN production batch)
3. **Task 14-17-02: Build complete one/both-edition candidates with scoped failure semantics** - `9bfb3b1` (test: RED contract)
4. **Task 14-17-02: Build complete one/both-edition candidates with scoped failure semantics** - `30c2ac6` (feat: GREEN state batch, validator, and script)
5. **Task 14-17-02: Harden embedded state coalescing** - `1eadc21` (fix: combined-process compatibility)
6. **Task 14-17-02: Scope shared evidence to forecastable fixtures** - `c63bef1` (fix: edition-local kickoff suppression)

Plan metadata is reconciled in the final documentation commit after STATE/ROADMAP updates.

## Files Created/Modified

- `R/competition/forecast_layer.R` - Vectorized fixture/status/forecast/grid/top-10 production contract and deterministic D-20 lineage.
- `R/competition/state_bundle.R` - Shared preflight, production candidates, exact artifact manifests, validator, batch hash, and scoped failure handling.
- `scripts/build_competition_state.R` - Explicit one/both-edition fixed-seed dry-run/build entrypoint.
- `tests/testthat/test_phase14_forecast_layer.R` - RED/GREEN no-silent-drop, callback-once, active-evidence, G=40, and lineage assertions.
- `tests/testthat/test_phase14_state_bundle.R` - RED/GREEN inventory, validator, replay, fan-out, local-isolation, and script assertions.

## Decisions Made

- Kept release selector resolution and immutable model-manifest identity as the only forecast authority; no recency discovery or raw release fallback was introduced.
- Kept local score distributions in candidate memory and excluded Phase 17 publication; the eleven-artifact manifest is the handoff contract for Plans 14-18/19.
- Evaluated shared active evidence only after lifecycle/status/identity/cutoff eligibility, so an unconfirmed kickoff is represented by its own suppression reason and cannot silently become a shared evidence failure.
- Kept inactive xG unavailable/NA and auditable, while active xG remains a required evidence boundary.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Made zero-column empty artifacts hashable and self-manifest counts exact**
- **Found during:** Task 14-17-02 GREEN verification
- **Issue:** Valid empty schemas used by EURO `pre_draw` and shared failures caused the generic data-frame hash helper to call `order()` without a vector; the manifest’s self-artifact row also initially reported zero rows.
- **Fix:** Added stable empty-schema hashing and set the self-manifest artifact row count to the eleven manifest rows.
- **Files modified:** `R/competition/state_bundle.R`
- **Verification:** State suite passed with 129 assertions.
- **Committed in:** `30c2ac6`

**2. [Rule 1 - Bug] Allowed named test input overrides through the batch helper**
- **Found during:** Task 14-17-02 RED/GREEN verification
- **Issue:** The test helper passed a fixed `team_registry` and could not accept the bad-identity override through `...`, so the shared-failure case failed before the production API ran.
- **Fix:** Built the helper argument list and applied named overrides before `do.call()`.
- **Files modified:** `tests/testthat/test_phase14_state_bundle.R`
- **Verification:** Shared identity fan-out and local failure isolation passed.
- **Committed in:** `30c2ac6`

**3. [Rule 3 - Blocking] Made the script robust when embedded with `sys.source()`**
- **Found during:** Task 14-17-02 GREEN verification
- **Issue:** Test embedding could not infer the script path from `sys.frame(1)$ofile`, and the validator referenced an internal helper under the wrong name.
- **Fix:** Added upward script-path discovery and corrected the validator dispatch.
- **Files modified:** `scripts/build_competition_state.R`, `R/competition/state_bundle.R`
- **Verification:** Script source, injected dry-run replay, and standalone `--help` checks passed.
- **Committed in:** `30c2ac6`

**4. [Rule 1 - Bug] Preserved embedded multi-value inputs across module loading**
- **Found during:** Exact combined forecast/state verification
- **Issue:** A previously sourced scalar-only `%||%` helper overwrote the operator and rejected data-frame inputs only when both test files ran in one process.
- **Fix:** Restored a length-safe state boundary definition that preserves vectors and data frames.
- **Files modified:** `R/competition/state_bundle.R`
- **Verification:** Combined fresh-process verification passed with 128 forecast and 129 state assertions.
- **Committed in:** `1eadc21`

**5. [Rule 1 - Bug] Kept ineligible kickoff rows out of shared active-evidence fan-out**
- **Found during:** Real script `--edition-id both --dry-run` verification
- **Issue:** The accepted fixture has `kickoff_confirmed=FALSE`; preflighting all scheduled rows incorrectly treated that row as a shared Elo evidence failure instead of its own suppression.
- **Fix:** Shared Elo/xG evidence checks now inspect only forecastable rows; lifecycle, identity, and kickoff suppression remain auditable and edition-local.
- **Files modified:** `R/competition/state_bundle.R`
- **Verification:** State suite passed with 129 assertions; real script dry-run exited 0 with no durable mutation.
- **Committed in:** `c63bef1`

**Total deviations:** 5 auto-fixed (4 Rule 1, 1 Rule 3)
**Impact on plan:** All fixes were directly required for correctness, isolation, or deterministic embedding; no architectural scope or durable publication was added.

## Issues Encountered

- Shared master contained unrelated benchmark, scratch, and generated artifacts. They were preserved and excluded from every staging operation.
- The sandbox required approved Git-index escalation for scoped commits; no repository-content blocker remained.
- The real accepted snapshot currently has an unconfirmed kickoff; the production dry-run now reports that as an edition-local suppression rather than incorrectly fanning out a shared evidence failure.

## User Setup Required

None - no external service configuration required.

## Known Stubs

None. EURO `pre_draw` zero-row structures and inactive national-team xG unavailable/NA audit values are intentional contract outputs, not placeholders.

## Next Phase Readiness

Plans 14-18/19 can consume the exact candidate fields and eleven-artifact inventory without re-resolving release authority or copying state between editions. Plan 14-20 can add replay checks around the fixed-seed batch boundary. Durable output promotion remains intentionally deferred to the later atomic publication plan.

---
*Phase: 14-shared-competition-state-and-forecast-layer*
*Plan: 17*
*Completed: 2026-08-17*

## Self-Check: PASSED

- Summary, source, script, and test files exist at their plan-owned paths.
- RED/GREEN/fix commits `77b034d`, `c353364`, `9bfb3b1`, `30c2ac6`, `1eadc21`, and `c63bef1` are present in Git history.
- Exact combined fresh-process verification passed with 128 forecast and 129 state assertions, zero failures, warnings, or skips.
