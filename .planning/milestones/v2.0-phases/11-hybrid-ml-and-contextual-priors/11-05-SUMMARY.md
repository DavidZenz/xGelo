---
phase: 11-hybrid-ml-and-contextual-priors
plan: 05
subsystem: benchmarking
tags: [R, hybrid-benchmark, mode-registry, provenance, licensing, Transfermarkt, bookmaker]

# Dependency graph
requires:
  - phase: 11-03
    provides: Open-core hybrid adapter dispatch and the feature-rich panel boundary.
  - phase: 11-04
    provides: Fail-closed optional evidence, sealed WC2026 boundaries, and the common G=40 scoring path.
provides:
  - Separate open_default, enriched_squad, and external_market mode registry with panel, license, provenance, and promotion-boundary validation.
  - Local derived-only squad aggregate adapter for the feature_rich panel.
  - Fail-closed validator and reference adapter for manually frozen external 1X2 probabilities.
affects: [phase-11-hybrid-benchmark, phase-12-candidate-selection, open-default-promotion]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Optional modes are registered independently and remain explicitly inactive when their local evidence is absent or invalid.
    - Restricted inputs cross the benchmark boundary only as locally derived aggregates or permitted labelled probabilities with checksums and licensing metadata.
    - Enriched and external evidence is research/reference-only and cannot enter open-default promotion.

key-files:
  created:
    - R/forecast/external_market.R
    - data/benchmark/phase11/mode_registry.csv
    - data/benchmark/phase11/manual_market_manifest.csv
    - .planning/phases/11-hybrid-ml-and-contextual-priors/deferred-items.md
  modified:
    - R/benchmark/hybrid_protocol.R
    - R/benchmark/hybrid_adapters.R
    - tests/testthat/test_hybrid_modes.R

key-decisions:
  - The open_default mode remains the only open-compatible promotion path; enriched_squad and external_market are sealed research/reference modes.
  - Enriched squad evidence reads only the committed local derived aggregate `data/processed/transfermarkt_squad_strength.csv`; raw Transfermarkt rows and automated collection paths are rejected.
  - The optional manual market snapshot is absent in this checkout, so external_market is registered inactive and the persisted manifest is intentionally header-only.
  - External market output is limited to labelled 1X2 reference probabilities and provenance; no implied ability reconstruction or score distribution is inferred.
  - Phase 11 remains research-only with the inherited exact open panel, sealed WC2026 boundary, and G=40 support.

patterns-established:
  - Mode registry rows carry source and metadata SHA-256 values, row hashes, active/inactive reasons, panel identities, licensing classes, and promotion boundaries.
  - Manual external evidence requires fixture/team/date keys, capture timestamp, source, operator, license, normalized probabilities, source checksum, and row checksum.

requirements-completed: [HYBRID-05]

coverage:
  - id: D1
    description: Open, enriched squad, and external market modes are separately labelled, licensed, panel-bound, and promotion-boundary validated.
    requirement: HYBRID-05
    verification:
      - kind: unit
        ref: tests/testthat/test_hybrid_modes.R via testthat::test_file
        status: pass
      - kind: integration
        ref: tests/testthat/test_transfermarkt_benchmark.R via testthat::test_file
        status: pass
    human_judgment: false
  - id: D2
    description: The optional manual market path validates frozen licensed 1X2 probabilities and fails closed without blocking open mode.
    requirement: HYBRID-05
    verification:
      - kind: unit
        ref: tests/testthat/test_hybrid_modes.R manual snapshot and inactive-mode cases
        status: pass
      - kind: other
        ref: Manual fail-closed smoke checks for absent snapshot, post-cutoff timestamp, missing fixture key, and tampered row hash
        status: pass
    human_judgment: false

# Metrics
metrics:
  duration: 21m
  completed: 2026-08-08
status: complete
---

# Phase 11 Plan 05: Hybrid ML and Contextual Priors Summary

**Fail-closed open/enriched/external mode boundaries with derived-only squad provenance and a manually frozen external-market reference validator.**

## Performance

- **Duration:** 21 minutes
- **Started:** 2026-08-08T21:27:34Z
- **Completed:** 2026-08-08T21:47:14Z
- **Tasks:** 2/2
- **Files modified:** 7 plan/phase-owned artifacts, including the deferred-issues ledger

## Accomplishments

- Added and persisted a three-row Phase 11 mode registry for `open_default`, `enriched_squad`, and `external_market`, with exact panel identities, licensing classes, checksums, active/inactive reasons, research-only/sealed flags, and promotion boundaries.
- Added a local aggregate-only enriched squad adapter backed by `data/processed/transfermarkt_squad_strength.csv` (SHA-256 `33b32feac6ba1fe9e4434b311c7314d2ce1351ab45d9d856c2872a30027ad5d0`). Raw player, club, market-value, and live-collection paths are rejected.
- Added a manual external-market validator and reference adapter. The absent optional snapshot leaves the external mode explicitly inactive and persists a schema-valid header-only manifest; open mode remains unaffected.
- Preserved the exact open panel denominator, sealed WC2026 boundary, research-only status, and G=40 score support. External outputs contain only labelled 1X2 reference probabilities and provenance metadata.

## Test Results

- `tests/testthat/test_hybrid_modes.R`: **52 assertions passed**, 0 failures, 0 warnings, 0 skips.
- `tests/testthat/test_transfermarkt_benchmark.R`: **111 assertions passed**, 0 failures, 0 warnings, 0 skips.
- Supporting contract/RF/structural suites also passed: **62**, **65**, and **39** assertions respectively.
- Manual fail-closed smoke checks passed for absent optional snapshot, post-cutoff timestamps, missing fixture keys, tampered row hashes, and persisted empty-manifest validation.
- `tests/testthat/test_hybrid_context_features.R` remains an out-of-scope pre-existing mismatch: 48 assertions passed and 2 candidate-set assertions fail because the merged 11-04 registry now includes the xG-gated and structural candidates. No context test or prior-wave registry row was changed by this plan; the issue is recorded in `deferred-items.md`.

## Task Commits

Each task was committed atomically, including the TDD RED contracts:

1. **Task 1 RED: Mode boundary and manual market contracts** - `0c92f8d` (test)
2. **Task 1 RED: Load enriched adapter mode contract** - `c091b68` (test)
3. **Task 1 GREEN: Register enriched squad mode boundary** - `1bd2580` (feat)
4. **Task 2 GREEN: Add fail-closed manual market reference adapter** - `3f68feb` (feat)

The plan metadata commit is created after the self-check below.

## Files Created/Modified

- `R/benchmark/hybrid_protocol.R` - Mode and manual-market schemas, canonical registries, validators, protocol readback, and writers.
- `R/benchmark/hybrid_adapters.R` - Aggregate-only enriched squad metadata/dispatch and external reference dispatch boundaries.
- `R/forecast/external_market.R` - Local manual snapshot resolver, validator, manifest validator, reader, and labelled 1X2 reference adapter.
- `data/benchmark/phase11/mode_registry.csv` - Persisted open/enriched/external registry, with external inactive because the optional source is absent.
- `data/benchmark/phase11/manual_market_manifest.csv` - Required manual-market schema with zero rows while no legal snapshot is supplied.
- `tests/testthat/test_hybrid_modes.R` - TDD and regression coverage for mode separation, aggregate-only reads, external validation, and promotion exclusions.
- `.planning/phases/11-hybrid-ml-and-contextual-priors/deferred-items.md` - Out-of-scope record for the pre-existing context-registry expectation mismatch.

## Decisions Made

- `enriched_squad` is tied to the `feature_rich` panel and local derived squad aggregates only. It is not blended into `open_default` and cannot replace open-mode promotion eligibility.
- `external_market` is a manually frozen, point-in-time reference panel. It requires legal/licensing metadata and checksums, but it does not reconstruct hidden team ability or create score distributions.
- Missing optional evidence is represented as explicit inactive state with a reason, never as observed zeros or silent activation.
- No automated bookmaker, Transfermarkt, or FotMob collection was added, and no raw restricted data is committed or published.
- Shared `.planning/STATE.md` and `.planning/ROADMAP.md` remain untouched for the orchestrator.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Test contract bug] Corrected the duplicate-mode assertion for R semantics**
- **Found during:** Task 1 (RED/GREEN verification)
- **Issue:** `anyDuplicated()` returns integer `0L` for no duplicates, while the initial test compared it to logical `FALSE` under strict equality.
- **Fix:** Compare the result explicitly with `0L`.
- **Files modified:** `tests/testthat/test_hybrid_modes.R`
- **Verification:** Mode suite passed with 52 assertions.
- **Committed in:** `1bd2580`

**2. [Rule 1 - Validator bug] Made mode semantic validation run before row-hash validation**
- **Found during:** Task 1 (mode-registry mutation checks)
- **Issue:** Mutating a semantic field in a test fixture produced a stale row-hash error before the intended panel/license boundary error.
- **Fix:** Validate semantic mode boundaries before requiring persisted row hashes.
- **Files modified:** `R/benchmark/hybrid_protocol.R`
- **Verification:** Mode boundary tests passed and semantic tampering reports the relevant boundary violation.
- **Committed in:** `1bd2580`

**3. [Rule 1 - Validator bug] Prevented `p_draw` from matching the restricted/raw-column guard**
- **Found during:** Task 2 (manual snapshot validation)
- **Issue:** A broad forbidden-column regular expression matched the legitimate probability column name `p_draw` because it contains the substring `raw`.
- **Fix:** Tightened the restricted/raw-column detection to identify actual raw/restricted fields and live-collection markers.
- **Files modified:** `R/forecast/external_market.R`
- **Verification:** Valid manual probabilities and the full mode suite pass; restricted/live-path fixtures still fail closed.
- **Committed in:** `3f68feb`

**Total deviations:** 3 auto-fixed bugs (Rule 1).  
**Impact on plan:** All fixes were directly required for correct tests and fail-closed boundary behavior; no architectural scope was added.

## Issues Encountered

- The optional manual bookmaker snapshot is not present. This is the expected precondition outcome: external mode is inactive with an explicit reason and open mode is not blocked.
- The broader context suite has a pre-existing registry expectation mismatch after 11-04. It is not part of the 11-05 acceptance criteria and is recorded in `deferred-items.md` without changing unrelated files.
- Git index writes required a narrow sandbox approval; no unrelated files were staged.

## Known Stubs

None. The zero-row manual-market manifest is an intentional fail-closed inactive state, not a UI or data-source stub.

## User Setup Required

An external market snapshot is optional. If a legally usable manually frozen CSV is later supplied at `data/manual/bookmaker/phase11_manual_market_snapshot.csv`, it must contain the manifest fields, normalized 1X2 probabilities, source/capture/license/operator metadata, and source/row SHA-256 values. No live collection or automated bookmaker/Transfermarkt/FotMob retrieval is permitted.

## Next Phase Readiness

HYBRID-05 is complete. Later research workflows can dispatch the three modes explicitly, retain open-default promotion eligibility exclusively for `open_default`, and consume optional external evidence only as labelled reference output. The absent manual snapshot is the only optional-data limitation and does not block open-mode execution. The orchestrator should update shared state and roadmap tracking.

## Self-Check: PASSED

- Summary file exists at `.planning/phases/11-hybrid-ml-and-contextual-priors/11-05-SUMMARY.md`.
- Plan commits `0c92f8d`, `c091b68`, `1bd2580`, and `3f68feb` exist in git history.
- No plan commit deleted tracked files.
- Focused acceptance suites passed; shared `STATE.md` and `ROADMAP.md` were not modified.

---
*Phase: 11-hybrid-ml-and-contextual-priors*  
*Plan: 05*  
*Completed: 2026-08-08*
