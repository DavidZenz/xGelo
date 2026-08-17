---
phase: 14-shared-competition-state-and-forecast-layer
plan: "07"
subsystem: release
tags: [r, calibration, immutable-release, sha256, atomic-install]
dependency_graph:
  requires:
    - phase: 14-06
      provides: selector-aware preflight and calibrated staging contract
    - phase: 14-22
      provides: independently accepted development-only calibration revision
    - phase: 12
      provides: frozen incumbent model and final-evaluation provenance
  provides:
    - exact immutable thirteen-file calibrated release bundle
    - selector-independent fresh-process manifest preflight
    - no-overwrite candidate and atomic sibling-install proof
  affects: [14-08, 14-09, forecast-runtime, FORECAST-01]
tech_stack:
  added: []
  patterns:
    - complete sibling candidate validation before one atomic directory rename
    - exact byte-preserving incumbent provenance with development-only calibration lineage
    - explicit manifest pinning while release authority remains unpromoted
key_files:
  created:
    - outputs/releases/phase14-open-nb-incumbent-calibrated-v1/release_manifest.csv
    - outputs/releases/phase14-open-nb-incumbent-calibrated-v1/model_contract.json
    - outputs/releases/phase14-open-nb-incumbent-calibrated-v1/model/calibrator.rds
    - outputs/releases/phase14-open-nb-incumbent-calibrated-v1/manifests/provenance.json
    - outputs/releases/phase14-open-nb-incumbent-calibrated-v1/reproducibility.json
  modified:
    - R/release/release_bundle.R
    - R/release/release_contract.R
    - R/release/release_install.R
    - tests/testthat/test_phase12_release.R
    - tests/testthat/test_phase14_calibration_release.R
decisions:
  - Build and completely validate the release under a sibling staging parent, then install only by one guarded atomic directory rename.
  - Preserve the incumbent model, freeze manifest, and final-evaluation manifest byte-for-byte; calibration lineage remains development-only and leaves the score distribution unchanged.
  - Keep approved_release.csv absent and competition-edition registry bytes unchanged; authority promotion belongs to later plans.
requirements-addressed: [FORECAST-01]
requirements-completed: []
coverage:
  dimensions:
    D1: exact inventory, hashes, identities, and no-overwrite candidate contract
    D2: fresh-process explicit-manifest preflight and loaded-object validation
status: complete
metrics:
  duration: 43m
  completed: 2026-08-17
---

# Phase 14 Plan 07: Immutable Calibrated Release Summary

**A hash-bound thirteen-file calibrated incumbent release was proven in sibling staging and installed by one guarded atomic directory rename without promoting runtime authority.**

## Performance

- **Duration:** 43m
- **Started:** 2026-08-17T10:39:07Z
- **Completed:** 2026-08-17T11:22:19Z
- **Tasks:** 2
- **Files changed:** 18 implementation/release files

## Accomplishments

- Added TDD coverage that reconstructs a complete candidate, verifies the exact thirteen-file inventory before and after RDS loading, checks all provenance identities, and proves an existing target cannot be overwritten.
- Extended calibrated bundle completion so contract, manifest, reports, provenance, limitations, and reproducibility metadata form one internally authenticated release envelope.
- Rebuilt the candidate under a fresh sibling staging parent and installed `phase14-open-nb-incumbent-calibrated-v1` using one `file.rename()` only after full validation and a second target-absence check.
- Preserved incumbent model bytes at SHA-256 `c65a4f90477e5b799e234d1a313ff333f6cce12cfc08de93e342d7718c252ff8`, retained the incumbent score distribution, and kept `outputs/releases/approved_release.csv` absent.
- Verified the competition-edition registry remained byte-identical at SHA-256 `97797b30b580374e753dc39e9e5af82a15fcf16a1bdd535e27c69f64fbc007c4`.

## Task Commits

Each task was committed atomically:

1. **Task 14-07-01 RED: exact immutable candidate contract** - `5b424b9` (test)
2. **Task 14-07-01 GREEN: complete calibrated candidate support** - `cf6736a` (feat)
3. **Task 14-07-02: immutable release installation** - `11c6f31` (feat)

## Files Created/Modified

- `outputs/releases/phase14-open-nb-incumbent-calibrated-v1/` - Exact thirteen-file immutable calibrated release.
- `R/release/release_bundle.R` - Calibrated lineage, exact incumbent copies, report schema, and release contract fields.
- `R/release/release_install.R` - Calibrated completion inventory, limitations, reproducibility, and manifest refresh validation.
- `R/release/release_contract.R` - Trusted explicit relative-manifest handling and fresh-process release identity exposure.
- `tests/testthat/test_phase14_calibration_release.R` - Candidate inventory, identity, no-overwrite, authority-neutrality, and relative preflight coverage.
- `tests/testthat/test_phase12_release.R` - Incumbent-pinned legacy regressions for a multi-release unpromoted parent.

## Decisions Made

- The durable release ID is immutable: construction fails closed if it exists, and installation is permitted only after complete candidate validation in a distinct non-symlinked sibling root.
- The model, freeze manifest, and final-evaluation manifest are exact incumbent copies. The fitted calibrator is linked only to accepted development evidence; holdout labels are not embedded or used.
- Release creation does not confer authority. No selector was created or moved, and no competition-edition registry row changed.

## Verification

- TDD RED failed as expected because complete candidate construction was absent; the pre-existing suite remained green.
- Task 1 GREEN: Phase 14 calibration release suite passed 183 assertions with zero failures/warnings and one pre-existing Plan 14-09 skip.
- Exact Task 2 fresh-process command passed 185 assertions with zero failures/warnings and one pre-existing Plan 14-09 skip.
- Phase 12 release regression passed 44 assertions with zero failures/warnings/skips after explicitly pinning the incumbent release.
- Complete candidate and installed bundle validation both passed with 13 manifest rows, exact inventory, no symlinks, loaded model/calibrator identity checks, and `distribution_unchanged=TRUE`.
- Incumbent model, freeze, final-evaluation, calibration revision, and calibration gate hashes matched their source artifacts exactly.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical Functionality] Completed calibrated thirteen-file bundle semantics**
- **Found during:** Task 14-07-01 GREEN
- **Issue:** Existing completion and validation paths recognized only the eleven-file raw release and lacked required calibrated lineage, report schema, and reproducibility cross-links.
- **Fix:** Added calibrated inventory selection, exact source artifact copying, required contract/provenance fields, honest reports/limitations, and manifest refresh validation.
- **Files modified:** `R/release/release_bundle.R`, `R/release/release_install.R`, `tests/testthat/test_phase14_calibration_release.R`
- **Commit:** `cf6736a`

**2. [Rule 1 - Bug] Fixed exact fresh-process explicit-manifest preflight**
- **Found during:** Task 14-07-02 fresh-process verification
- **Issue:** A project-relative manifest already under the trusted root was incorrectly joined to that root a second time, and the required top-level `release_id` was absent.
- **Fix:** Normalize existing project-relative paths, enforce trusted-root containment, and expose the validated release ID without loading RDS objects.
- **Files modified:** `R/release/release_contract.R`, `tests/testthat/test_phase14_calibration_release.R`
- **Commit:** `11c6f31`

**3. [Rule 3 - Blocking Regression] Removed legacy single-release discovery assumption**
- **Found during:** Task 14-07-02 Phase 12 regression verification
- **Issue:** Three legacy tests scanned the release parent and became ambiguous once the new unpromoted release was installed.
- **Fix:** Pin those checks explicitly to the incumbent manifest, preserving the absence of selector authority.
- **Files modified:** `tests/testthat/test_phase12_release.R`
- **Commit:** `11c6f31`

**4. [Rule 3 - Blocking Metadata] Reconciled stale SDK state prose**
- **Found during:** Plan closeout
- **Issue:** The SDK advanced the plan count but retained Plan 14-07 as next and labeled the new decisions `Phase ?`.
- **Fix:** Updated only the Phase 14 position, status, next action, and three new decision labels to reflect completed Plan 14-07 and next Plan 14-08.
- **Files modified:** `.planning/STATE.md`
- **Commit:** Final metadata commit

## Known Stubs

- `tests/testthat/test_phase14_calibration_release.R:1195` - Pre-existing Wave 0 guard skips Plan 14-09 dual-repin rollback assertions until `phase14_repin_both_competition_releases()` and `phase14_promote_calibrated_release()` are implemented. This does not block the immutable release goal and is already recorded in `.planning/WINDOWS.md`.

## Authentication Gates

None.

## Next Phase Readiness

- The immutable release is ready for later selector staging and dual-registry promotion.
- Runtime authority still points nowhere new: `approved_release.csv` remains absent and competition-edition rows are unchanged by design.

## Self-Check: PASSED

- All 18 implementation/release files and this summary exist.
- Task commits `5b424b9`, `cf6736a`, and `11c6f31` are present in git history.
