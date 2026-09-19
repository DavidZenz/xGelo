---
phase: 14-shared-competition-state-and-forecast-layer
plan: "08"
subsystem: release
tags: [r, release-selector, sha256, trusted-paths, calibration]
dependency_graph:
  requires:
    - phase: 14-07
      provides: immutable calibrated release installed without authority promotion
    - phase: 14-06
      provides: exact-manifest selector-aware metadata preflight
  provides:
    - exact five-field self-hashed release selector builder and validator
    - validated non-authoritative selector candidate for the calibrated incumbent release
    - fail-closed traversal, symlink, allowlist, manifest-hash, row-count, and self-hash controls
  affects: [14-09, forecast-runtime, competition-edition-registry, FORECAST-01]
tech-stack:
  added: []
  patterns:
    - explicit one-release allowlist with trusted-root-relative immediate-child manifest topology
    - canonical CSV self-hash plus exact manifest file hash before metadata preflight
key-files:
  created:
    - outputs/benchmarks/rolling_tournaments/phase14-incumbent-calibration-remediation-v2/approved_release_candidate.csv
  modified:
    - R/release/calibration_revision.R
    - tests/testthat/test_phase14_calibration_release.R
key-decisions:
  - "Allow only phase14-open-nb-incumbent-calibrated-v1 to satisfy the Plan 14-08 selector contract; no release discovery or raw fallback is permitted."
  - "Keep the persisted selector row non-authoritative: approved_release.csv stays absent and both competition registry rows stay on the raw incumbent until Plan 14-09."
  - "Keep FORECAST-01 addressed but pending until the calibrated release is consumed by both downstream dashboards."
requirements-addressed: [FORECAST-01]
requirements-completed: []
coverage:
  - id: D1
    description: "Exact self-hashed selector builder and validator with fail-closed path, identity, timestamp, and hash checks"
    requirement: FORECAST-01
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase14_calibration_release.R#14-08 selector candidate and adversarial contracts"
        status: pass
      - kind: other
        ref: "Rscript --vanilla -e 'testthat::test_file(\"tests/testthat/test_phase14_calibration_release.R\", stop_on_failure=TRUE)'"
        status: pass
    human_judgment: false
  - id: D2
    description: "One non-authoritative selector candidate bound to the exact immutable calibrated release manifest"
    requirement: FORECAST-01
    verification:
      - kind: integration
        ref: "fresh R process: phase14_validate_release_selector(candidate, trusted_root=\"outputs/releases\")"
        status: pass
    human_judgment: false
  - id: D3
    description: "Durable selector and dual competition-registry authority remain unchanged"
    requirement: FORECAST-01
    verification:
      - kind: integration
        ref: "approved_release.csv absence plus competition_editions.csv SHA-256 97797b30b580374e753dc39e9e5af82a15fcf16a1bdd535e27c69f64fbc007c4"
        status: pass
    human_judgment: false
metrics:
  duration: 21m
  completed: 2026-08-17
status: complete
---

# Phase 14 Plan 08: Non-Authoritative Release Selector Candidate Summary

**An exact five-field, self-hashed selector now proves the immutable calibrated release without creating runtime authority or repinning either competition.**

## Performance

- **Duration:** 21m
- **Started:** 2026-08-17T11:29:20Z
- **Completed:** 2026-08-17T11:50:23Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Added `phase14_build_release_selector_row()` and `phase14_validate_release_selector()` with one exact schema, strict UTC approval timestamps, an explicit one-release allowlist, trusted-root containment, immediate-child topology, canonical self-hashing, and metadata-only release preflight.
- Added adversarial coverage proving multiple rows, traversal, symlink escape, unknown releases, stale manifest hashes, malformed timestamps, and self-hash forgery fail closed before release object loading.
- Persisted one candidate row for `phase14-open-nb-incumbent-calibrated-v1` with manifest file SHA-256 `0e89c2948c77b348c5b6d3832cf6d4e7721ca7794f8f68f857d6ae82b9fe7d50` and selector self-hash `fc9a617e48969b5d524f9994bccb31de0cb028829b4c58a1999b77cf12c5a990`.
- Proved `outputs/releases/approved_release.csv` remains absent and `data/competition/registries/competition_editions.csv` remains byte-identical with both rows pinned to `phase12-wc2026-incumbent-retained-v1`.

## Task Commits

Each task was committed atomically:

1. **Task 14-08-01 RED: failing selector behavioral contract** - `3f2e10a` (test)
2. **Task 14-08-01 GREEN: release selector builder and validator** - `740e530` (feat)
3. **Task 14-08-02: persisted selector candidate** - `7cd18a9` (feat)

## Files Created/Modified

- `R/release/calibration_revision.R` - Builds and validates the exact allowlisted selector row through trusted release metadata preflight.
- `tests/testthat/test_phase14_calibration_release.R` - Proves exact selector semantics, authority neutrality, and the complete adversarial rejection matrix.
- `outputs/benchmarks/rolling_tournaments/phase14-incumbent-calibration-remediation-v2/approved_release_candidate.csv` - Stores the single validated non-authoritative candidate for Plan 14-09.

## Decisions Made

- The selector validator allowlists only `phase14-open-nb-incumbent-calibrated-v1`; neither directory discovery nor a raw fallback can satisfy the contract.
- Manifest path/hash ambiguity is rejected before metadata preflight, while release trust itself is delegated to the established exact-manifest preflight with `load_models = FALSE`.
- The candidate is evidence, not authority. Runtime selection and both registry repins remain one later atomic transaction.
- `FORECAST-01` remains pending until both dashboards consume the approved calibrated release and expose its lineage.

## TDD Gate Compliance

- **RED:** The canonical release suite reached 185 existing passing assertions, then failed only on the two missing Plan 14-08 APIs.
- **GREEN:** The implemented API passed 202 assertions with zero failures or warnings.
- **REFACTOR:** No separate refactor commit was needed; the minimal implementation followed existing release-contract helpers directly.

## Verification

- Canonical release suite: 202 assertions passed, zero failures/warnings, and one pre-existing Plan 14-09 skip.
- Fresh-process candidate validation passed with exactly one row and the exact calibrated release identity/path/hash.
- Durable selector absence was rechecked after persistence.
- Competition registry SHA-256 remained `97797b30b580374e753dc39e9e5af82a15fcf16a1bdd535e27c69f64fbc007c4`; both rows still name `phase12-wc2026-incumbent-retained-v1`.
- TDD commit order is present: `3f2e10a` precedes `740e530`.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## Known Stubs

- `tests/testthat/test_phase14_calibration_release.R:1348` - Pre-existing Plan 14-09 dual-repin guard remains skipped until `phase14_repin_both_competition_releases()` and `phase14_promote_calibrated_release()` are implemented. This is already open in `.planning/WINDOWS.md` and does not block the non-authoritative candidate goal.

## Authentication Gates

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 14-09 can consume this candidate in the selector-plus-dual-registry atomic authority transaction.
- Runtime authority remains deliberately unchanged until that transaction succeeds.
- `FORECAST-01` remains addressed/pending for downstream dashboard consumption.

## Self-Check: PASSED

- All three implementation/evidence files and this summary exist.
- Task commits `3f2e10a`, `740e530`, and `7cd18a9` are present in Git history.
- Coverage metadata classifies all three deliverables as automatically proven by passing verification.
- Durable selector absence and the byte-identical raw-incumbent registry were revalidated after both task commits.

---
*Phase: 14-shared-competition-state-and-forecast-layer*
*Completed: 2026-08-17*
