---
phase: 14-shared-competition-state-and-forecast-layer
plan: "06"
subsystem: release-runtime
tags: [r, testthat, selector-authority, metadata-preflight, calibrated-release, immutable-evidence]
requires:
  - phase: 12-calibration-promotion-and-model-release
    provides: immutable incumbent release, release manifest, model contract, and fail-closed metadata preflight
  - phase: 14-shared-competition-state-and-forecast-layer
    plan: "22"
    provides: independently accepted calibration remediation graph and calibration-v2-gate-passed signal
provides:
  - selector-only calibrated runtime resolver with metadata-first preflight before RDS loading
  - exact Plan 14-22 calibrated revision staging and validation contract
  - adversarial rejection of selector, topology, source, gate, cutoff, label, and distribution forgeries
affects: [14-07, 14-09, forecast-runtime, dashboard-release-consumers, FORECAST-01]
tech-stack:
  added: []
  patterns:
    - approved_release.csv is the sole public runtime authority; direct manifest paths remain internal
    - independently accepted evidence identities are pinned before staged object enrichment
    - all release metadata and artifact hashes validate before model or calibrator deserialization
key-files:
  created: []
  modified:
    - R/release/release_contract.R
    - R/release/release_bundle.R
    - tests/testthat/test_phase14_calibration_release.R
key-decisions:
  - "Runtime callers resolve calibrated releases only through the exact self-hashed approved_release.csv selector; directory discovery and direct-manifest authority are not public seams."
  - "Calibrated staging pins the independently accepted Plan 14-22 manifest, gate, source release, model, and calibrator identities while retaining raw_1x2 as an audit-only view."
  - "Staging enriches the accepted calibrator with release-facing identity fields while preserving and validating its original accepted artifact SHA-256; it never writes an approved selector."
patterns-established:
  - "Metadata-first release trust: containment, topology, symlinks, selector hash, manifest hash, contract identity, and artifact bytes validate before readRDS()."
  - "Dual calibrator identity: source_calibrator_sha256 binds independent acceptance while calibrator_sha256 binds the staged release object."
requirements-addressed: [FORECAST-01]
requirements-completed: []
coverage:
  - id: D1
    description: The exact approved-release selector resolves one immutable fitted calibrated release and returns stable release, model, calibrator, cutoff, support, view, and loaded-object identities after metadata preflight.
    requirement: FORECAST-01
    verification:
      - kind: integration
        ref: tests/testthat/test_phase14_calibration_release.R#14-06-selector-aware-preflight-rejects-forgery-and-ignores-unselected-roots
        status: pass
      - kind: integration
        ref: tests/testthat/test_phase14_calibration_release.R#14-06-selected-manifest-preflight-precedes-RDS-reads-and-stays-fresh
        status: pass
    human_judgment: false
  - id: D2
    description: Calibrated staging accepts only the independently approved Plan 14-22 revision and rejects raw, wrong-source, chronology, label, cutoff, and score-distribution drift without creating selector authority.
    requirement: FORECAST-01
    verification:
      - kind: integration
        ref: tests/testthat/test_phase14_calibration_release.R#14-06-stages-only-the-independently-accepted-calibrated-revision
        status: pass
      - kind: unit
        ref: tests/testthat/test_phase14_calibration_release.R#14-06-calibrated-bundle-rejects-gate-chronology-label-and-score-forgeries
        status: pass
      - kind: integration
        ref: tests/testthat/test_phase12_release.R
        status: pass
    human_judgment: false
duration: 48min
completed: 2026-08-17
status: complete
---

# Phase 14 Plan 06: Selector-Aware Calibrated Release Summary

**A selector-only metadata trust boundary now resolves fitted calibrated releases, while temporary staging binds the exact independently accepted Plan 14-22 revision without installing or promoting release authority.**

## Performance

- **Duration:** 48 minutes
- **Started:** 2026-08-17T09:44:50Z
- **Completed:** 2026-08-17T10:32:13Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Added `phase14_resolve_approved_release(selector_path, trusted_release_root)` as the sole registry/runtime API, with exact selector self-hash, manifest hash, trusted-root containment, symlink, topology, freshness, and object identity checks.
- Extended calibrated bundle validation and staging to bind the exact Plan 14-22 manifest self-hash `8adb6d0475474971596d4255a174fcc7b3c8c9847a14d6112f20848bbdec82e1` and gate row hash `0e4220775d2975aa7834eda42d41a0b6dd6aff7cdb30b6ef2f1f6595b95d1f95`.
- Enforced the canonical Phase 12 source release, `open_nb_incumbent`, updating/open-core identity, G=40 support, model cutoff `2026-06-10`, calibration cutoff `2024-07-14`, fitted status, label exclusion, unchanged score distribution, and passing calibration gate.
- Proved that temporary staging creates no `approved_release.csv` and leaves durable release/registry authority unchanged.

## Test Results

Canonical plan command:

```sh
Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_calibration_release.R", stop_on_failure=TRUE); testthat::test_file("tests/testthat/test_phase12_release.R", stop_on_failure=TRUE)'
```

Result: exit `0`; Phase 14 passed 152 assertions with zero failures or warnings, and Phase 12 passed 44 assertions with zero failures, warnings, or skips. Phase 14 reported one pre-existing Plan 14-09 Wave 0 skip for the not-yet-owned dual-repin API.

## Task Commits

Each TDD task was committed as a RED test followed by GREEN implementation:

1. **Task 14-06-01: Add exact selector-aware metadata preflight**
   - `2bda591` — `test(14-06): add failing selector-aware release tests`
   - `3d9603d` — `feat(14-06): add selector-aware release preflight`
2. **Task 14-06-02: Validate and stage calibrated revision bundles**
   - `01fcf68` — `test(14-06): add failing calibrated revision bundle tests`
   - `46cf125` — `feat(14-06): validate calibrated revision bundles`

## Files Created/Modified

- `R/release/release_contract.R` — Selector reader, exact selected topology checks, metadata-first direct-manifest internal preflight, and canonical calibrated runtime resolver.
- `R/release/release_bundle.R` — Exact Plan 14-22 identity pins, canonical source/revision validation, calibrated artifact manifest support, enriched staged calibrator contract, and no-selector temporary staging.
- `tests/testthat/test_phase14_calibration_release.R` — Selector/runtime and calibrated staging adversarial coverage.
- `.planning/phases/14-shared-competition-state-and-forecast-layer/14-06-SUMMARY.md` — Canonical Plan 14-06 execution record.

## Decisions Made

- Public release resolution accepts only the one-row `approved_release.csv` selector at the trusted root. Explicit manifest paths remain lower-level staging/install inputs.
- The independent Plan 14-22 pass identity is pinned by exact manifest, gate, source-release, model, and source-calibrator hashes; self-consistently rehashed alternatives cannot become release candidates.
- The accepted calibrator is enriched only inside the staged release object so the runtime has explicit candidate, gate, cutoff, and audit-view fields. Its original accepted artifact hash remains a separate mandatory contract field.
- `FORECAST-01` remains addressed rather than complete until both dashboards consume the approved calibrated release and expose its identities and cutoffs.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - State metadata] Reconciled stale post-advance Phase 14 prose**
- **Found during:** Post-plan state update
- **Issue:** The SDK advanced Phase 14 to 8/22 plans and marked 14-06 in ROADMAP, but retained STATE prose saying Plan 14-06 was still unexecuted and next.
- **Fix:** Updated only the stale activity, current-position, progress, todo, and next-action prose to identify Plan 14-07 as next while preserving the no-promotion boundary and pending `FORECAST-01` status.
- **Files modified:** `.planning/STATE.md`
- **Verification:** STATE and ROADMAP both report 8/22 plans complete, Plan 14-07 next, and durable release authority unchanged.
- **Committed in:** final plan metadata commit

---

**Total deviations:** 1 auto-fixed (1 state-metadata bug)
**Impact on plan:** Documentation-only reconciliation; no production release, selector, registry, or accepted calibration evidence changed.

## Issues Encountered

- The first GREEN run rejected both score-distribution and cutoff forgeries correctly but returned broader identity messages than the tests required. The messages were narrowed and the full canonical suites passed on rerun.
- The shared checkout contains unrelated Phase 10/11/13 and output changes. They were preserved and never staged.

## Authentication Gates

None.

## Known Stubs

| File | Line | Stub | Reason |
|---|---:|---|---|
| `tests/testthat/test_phase14_calibration_release.R` | 966 | Pre-existing skipped Plan 14-09 dual-repin Wave 0 guard | The atomic dual-repin API belongs to Plan 14-09 and does not block Plan 14-06 selector or calibrated staging outcomes. |

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The release trust boundary and calibrated core staging contract are ready for later completion, installation, selector promotion, and dashboard consumption plans.
- No durable release directory or selector was installed or promoted by Plan 14-06.
- `FORECAST-01` remains pending until both dashboards consume the approved calibrated release.

## Self-Check: PASSED

- All three Plan 14-06 implementation/test files and this summary exist.
- TDD commits `2bda591`, `3d9603d`, `01fcf68`, and `46cf125` exist in Git history.
- The canonical Phase 14/12 verification command exited successfully after the final implementation.
- No Plan 14-06 verification step was left unrun, and no durable release or selector output was created.

---
*Phase: 14-shared-competition-state-and-forecast-layer*
*Completed: 2026-08-17*
