---
phase: 14-shared-competition-state-and-forecast-layer
plan: "09"
subsystem: release-authority
tags: [r, release-selector, atomic-transaction, rollback, competition-registry]

dependency_graph:
  requires:
    - phase: 14-08
      provides: validated non-authoritative calibrated release selector candidate
    - phase: 13
      provides: complete competition-edition registry and source-bundle validation
  provides:
    - rollback-safe selector plus dual-edition authority transaction
    - durable calibrated release selector and revision-2 competition pins
  affects: [forecast-runtime, dashboard-consumers, competition-edition-registry]

tech-stack:
  added: []
  patterns:
    - locked snapshot/stage/validate/promote/post-validate/byte-rollback authority transaction
    - selector-path-only runtime release resolution with exact two-edition and one-release invariants

key-files:
  created:
    - outputs/releases/approved_release.csv
  modified:
    - R/competition/edition_registry.R
    - R/release/calibration_revision.R
    - tests/testthat/test_phase14_calibration_release.R
    - data/competition/registries/competition_editions.csv

key-decisions:
  - "Promote the selector and both competition-edition rows only through one locked transaction; stale expected bytes fail closed and no durable retry was attempted."
  - "Runtime and registry validation use phase14_resolve_approved_release(selector_path, trusted_release_root); direct release manifests remain internal staging inputs."
  - "Keep FORECAST-01 addressed but pending until downstream dashboard consumers expose the calibrated release lineage."

requirements-addressed: [FORECAST-01, STATE-04]
requirements-completed: []
requirements-pending: [FORECAST-01, STATE-04]

coverage:
  - id: D1
    description: "Atomic selector and exactly-two-edition transaction with failure injection and exact byte rollback"
    requirement: STATE-04
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase14_calibration_release.R#14-09 transaction restores exact present selector and registry bytes at every rename boundary"
        status: pass
      - kind: integration
        ref: "tests/testthat/test_phase14_calibration_release.R#14-09 selector-absent prior state is restored at every applicable rename boundary"
        status: pass
      - kind: integration
        ref: "tests/testthat/test_phase13_competition_registry.R"
        status: pass
    human_judgment: false
  - id: D2
    description: "Durable calibrated selector and dual competition registry authority"
    requirement: FORECAST-01
    verification:
      - kind: integration
        ref: "fresh R process selector-path resolution with release identity phase14-open-nb-incumbent-calibrated-v1 and model cutoff 2026-06-10"
        status: pass
      - kind: other
        ref: "17bffcb durable artifact commit; selector SHA-256 fe038d4348b7bd7caad03da9b76321b331fd1781dabfd7ce1ba4bfd8bf0ae3c2"
        status: pass
    human_judgment: false
  - id: D3
    description: "Fresh-process revision and immutable edition-lineage proof"
    requirement: STATE-04
    verification:
      - kind: integration
        ref: "fresh R process comparison against HEAD pre-state: revisions 1|1 -> 2|2 and all immutable registry columns preserved"
        status: pass
      - kind: integration
        ref: "tests/testthat/test_phase14_calibration_release.R (full canonical suite after durable promotion)"
        status: pass
    human_judgment: false

metrics:
  duration: 1h 10m
  completed: 2026-08-17
status: complete
---

# Phase 14 Plan 09: Atomic Calibrated Selector and Dual Registry Authority Summary

**The calibrated release selector and both UEFA competition pins now promote together under a rollback-safe, selector-only authority transaction.**

## Performance

- **Duration:** 1h 10m
- **Started:** 2026-08-17T12:17:19Z
- **Completed:** 2026-08-17T13:27:24Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Implemented pure two-edition repinning with exact edition-set, one-release, revision-plus-one, audit, and immutable-lineage validation.
- Implemented locked selector/registry snapshot, complete staging, selector-path validation, deterministic renames, post-validation, and exact byte restoration across every injected rename boundary.
- Promoted `phase14-open-nb-incumbent-calibrated-v1` exactly once from the raw incumbent pre-state: both rows advanced from revision 1 to revision 2, the resolver returned model cutoff `2026-06-10`, and source/lifecycle/ruleset/output lineage was preserved.
- Proved the durable state in a fresh R process and kept `FORECAST-01` pending for downstream dashboard consumption.

## Durable Identity

- **Pre-state:** selector absent; registry SHA-256 `97797b30b580374e753dc39e9e5af82a15fcf16a1bdd535e27c69f64fbc007c4`; both rows pinned to `phase12-wc2026-incumbent-retained-v1` at revision `1|1`.
- **Post-state:** selector SHA-256 `fe038d4348b7bd7caad03da9b76321b331fd1781dabfd7ce1ba4bfd8bf0ae3c2`; registry SHA-256 `09373a3b3ef3acc791a577e194c9c5f9378dd009da04292aa066f25a39694669`; both rows pin `phase14-open-nb-incumbent-calibrated-v1` at revision `2|2`.
- **Candidate/manifest:** selector candidate self-hash `fc9a617e48969b5d524f9994bccb31de0cb028829b4c58a1999b77cf12c5a990`; release manifest SHA-256 `0e89c2948c77b348c5b6d3832cf6d4e7721ca7794f8f68f857d6ae82b9fe7d50`.
- **Audit:** `model_release_repin` at `2026-08-17T12:56:13Z` by `codex`.

## Task Commits

1. **Task 14-09-01 RED: failing atomic authority transaction tests** - `abb78f3` (test)
2. **Task 14-09-01 GREEN: atomic selector and dual registry transaction** - `32146d1` (feat)
3. **Task 14-09-02: durable selector and dual registry promotion** - `17bffcb` (feat)
4. **Scoped Rule 1 test-fixture fix: stable raw incumbent transaction baseline** - `401a4ea` (fix)

## Files Created/Modified

- `R/competition/edition_registry.R` - Validates and constructs the complete two-edition calibrated repin while preserving immutable edition lineage.
- `R/release/calibration_revision.R` - Owns lock, snapshots, staging, promotion, post-validation, failure injection, and exact rollback.
- `tests/testthat/test_phase14_calibration_release.R` - Covers all rename boundaries, selector-absent restoration, split/missing/revision/lineage rejection, success, and stale retries.
- `outputs/releases/approved_release.csv` - Durable one-row calibrated selector authority.
- `data/competition/registries/competition_editions.csv` - Durable revision-2 dual-edition calibrated pins.

## Decisions Made

- The selector is the only public runtime authority; registry validation passes a selector path to `phase14_resolve_approved_release()` and never a manifest path.
- The durable transaction was executed once against the captured absent-selector/raw-revision-1 pre-state; its stale expected-byte guard remains the only safe retry boundary.
- `FORECAST-01` remains pending until both dashboards consume and expose the calibrated release identity and cutoff.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Test fixture bug] Stabilized temporary authority sandboxes after durable promotion**

- **Found during:** Task 14-09-02 final Phase 14 suite
- **Issue:** The sandbox copied the now-promoted durable registry, so the split-pin mutation no longer created a split and the rejection assertion failed.
- **Fix:** Reset each temporary sandbox to the raw incumbent release, revision 1, initial-registration audit fields, and recomputed row hashes before exercising the transaction.
- **Files modified:** `tests/testthat/test_phase14_calibration_release.R`
- **Verification:** Full Phase 14 calibration-release suite passed after durable promotion.
- **Committed in:** `401a4ea`

**Total deviations:** 1 auto-fixed (Rule 1: 1 test-fixture bug).
**Impact on plan:** No durable authority was reverted or retried; the fix makes rollback tests deterministic across pre- and post-promotion runs.

## Issues Encountered

- The literal Task 14-09-02 verification snippet used `r$registries`, but the established `load_competition_edition_registries()` API returns the registry data frame directly. A corrected fresh-process check used `r` directly and passed without changing that public API.
- No authentication gates occurred.

## Known Stubs

None - no task-produced stubs or skipped tests remain. The generic Wave 0 API guard in the canonical test file was not exercised because all required APIs were present.

## Verification

- Phase 14 calibration-release suite passed before promotion, after promotion, and after the scoped fixture fix.
- Phase 13 competition-registry suite passed before and after durable promotion.
- Fresh-process selector resolution proved one calibrated authority, exactly two matching pins, revision `2|2`, non-missing model cutoff, selector-aware loader resolution, and preserved immutable lineage.
- No split pin, partial selector, stale retry, failure-injection rollback, or cleanup residue remained.

## Self-Check: PASSED

- All five planned implementation/durable/test files exist.
- RED, GREEN, durable promotion, and scoped fix commits are present in Git history.
- No task-produced deletions or uncommitted changes remain in Plan 14-09 files.
- `FORECAST-01` remains pending in planning requirements for downstream dashboard consumption.
- Shared `STATE-04` remains pending because later Phase 14 plans also own that requirement.
- Rerun self-check: all planned files found, all four Plan 14-09 commits found, and `git diff --check` passed.

## Next Phase Readiness

- The shared calibrated authority is ready for downstream dashboard consumption.
- `FORECAST-01` must remain pending until both dashboards consume and expose the release lineage.
- `STATE-04` remains pending until all plans that declare the shared requirement are complete.

---
*Phase: 14-shared-competition-state-and-forecast-layer*
*Completed: 2026-08-17*
