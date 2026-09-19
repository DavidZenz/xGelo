---
phase: 13-source-contracts-and-competition-registry
plan: "02"
subsystem: source-contracts
tags: [R, UEFA, provenance, SHA-256, JSON, fallback, source-bundle]

# Dependency graph
requires:
  - phase: 13-source-contracts-and-competition-registry/01
    provides: Wave 1 source-contract and registry tracer, fixture shapes, and edge-case conventions
provides:
  - Required five-class structured source validation with schema and provenance enforcement
  - Bounded UEFA fixture/live capture with exact ignored raw bytes and compact accepted snapshots
  - Reviewed-fallback and blocked-refresh metadata with last-accepted retention
  - Committed source bundle and artifact registries for the two Phase 13 editions
affects: [13-03, competition-registry, source-refresh, data-ingestion]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Explicit source-shaped schemas are validated before acceptance, including truthful zero-row pre-draw tables
    - Raw source bytes are retained locally for replay and hashing while only compact provenance outputs are committed
    - Candidate publication is staged atomically and blocked refreshes retain the prior accepted output

key-files:
  created:
    - scripts/acquire_uefa_snapshot.R
    - data/competition/accepted/uefa_nations_league_2026_27/*.csv
    - data/competition/accepted/uefa_euro_2028_qualifying/*.csv
    - data/competition/registries/source_bundles.csv
    - data/competition/registries/source_artifacts.csv
  modified:
    - R/competition/source_contracts.R
    - tests/testthat/test_phase13_source_contracts.R
    - .gitignore

key-decisions:
  - "Acceptance requires all five structured resource classes and their provenance fields; rendered HTML/PDF documents are never accepted as substitutes."
  - "Capture is bounded and explicit: fixture replay is deterministic, live mode requires HTTPS URLs, and exact raw bytes remain in an ignored local store."
  - "Reviewed fallback is an edition-wide source bundle with approved metadata; blocked candidates write failure metadata while preserving the last accepted output."
  - "Euro pre-draw resource classes use schema-correct empty tables so unavailable upstream data is represented truthfully rather than fabricated."

patterns-established:
  - "Every accepted resource carries schema_version, edition_id, source_artifact_id, row_sha256, and raw-byte provenance."
  - "Committed registries contain compact metadata only; local_raw is explicitly ignored and verified absent from Git tracking."

requirements-completed: [DATA-01, DATA-02, DATA-04]

# Coverage metadata
coverage:
  - id: D1
    description: "Validated all five required structured resource classes, schema drift, stable row hashes, and manifest self-hashes."
    requirement: DATA-01
    verification:
      - kind: unit
        ref: "tests/testthat/test_phase13_source_contracts.R#required resource and provenance contract tests"
        status: pass
      - kind: integration
        ref: "Rscript --vanilla -e 'testthat::test_file(\"tests/testthat/test_phase13_source_contracts.R\")'"
        status: pass
    human_judgment: false
  - id: D2
    description: "Added bounded fixture/live acquisition and published compact accepted snapshots plus source registries for both Phase 13 editions."
    requirement: DATA-02
    verification:
      - kind: integration
        ref: "Rscript --vanilla scripts/acquire_uefa_snapshot.R --fixture-dir tests/fixtures/phase13 --edition-id uefa_nations_league_2026_27 --output-root data/competition/accepted --registry-root data/competition/registries --dry-run"
        status: pass
      - kind: unit
        ref: "tests/testthat/test_phase13_source_contracts.R#bounded acquisition replays compact structured fixtures into an accepted edition"
        status: pass
    human_judgment: false
  - id: D3
    description: "Implemented reviewed fallback acceptance and blocked-refresh metadata that retains the previous accepted bundle."
    requirement: DATA-04
    verification:
      - kind: unit
        ref: "tests/testthat/test_phase13_source_contracts.R#reviewed fallback is accepted as a complete bundle"
        status: pass
      - kind: unit
        ref: "tests/testthat/test_phase13_source_contracts.R#blocked candidate writes failure metadata and retains the prior accepted bundle"
        status: pass
    human_judgment: false
  - id: D4
    description: "Protected provenance boundaries by rejecting HTML/PDF masquerades and keeping exact local raw bytes out of Git tracking."
    verification:
      - kind: unit
        ref: "tests/testthat/test_phase13_source_contracts.R#structured bytes reject rendered HTML and PDF inputs"
        status: pass
      - kind: other
        ref: "git ls-files data/competition/local_raw (empty output)"
        status: pass
    human_judgment: false

# Metrics
duration: 26min
completed: 2026-08-13
status: complete
---

# Phase 13 Plan 02: Source Acquisition and Provenance Summary

**Required UEFA source contracts, bounded acquisition, accepted snapshots, and reviewed fallback retention are now enforced with SHA-256 provenance.**

## Performance

- **Duration:** 26 min
- **Started:** 2026-08-13T20:17:14Z
- **Completed:** 2026-08-13
- **Tasks:** 2
- **Files modified:** 18

## Accomplishments

- Completed the Wave 1 tracer into production-grade validators for the five required resource classes, explicit schemas, raw-byte checks, stable row hashes, manifest self-hashes, and source registries.
- Added `scripts/acquire_uefa_snapshot.R` with deterministic fixture replay, bounded explicit HTTPS capture, atomic raw-byte storage, compact accepted publication, and dry-run validation.
- Added reviewed fallback acceptance and blocked-refresh metadata that preserves the prior accepted edition output on validation failure.
- Published schema-validated compact snapshots for `uefa_nations_league_2026_27` and the truthful pre-draw `uefa_euro_2028_qualifying` edition.

## Verification

- Focused Phase 13 source-contract tests: **63 assertions, 0 failures, 0 warnings, 0 skips**.
- Full repository test suite: **2,689 assertions, 0 failures, 0 warnings, 0 skips** in 351.6 seconds.
- Exact plan dry-run command passed with candidate `nl-2026-27-official-sample-v1`.
- Both committed source registries and accepted-edition CSV snapshots validate; raw bytes are present only in the ignored local store and `git ls-files data/competition/local_raw` is empty.

## Task Commits

Each task was committed atomically; TDD tasks include their RED and GREEN commits:

1. **Task 13-02-01: Complete required-resource and provenance validation**
   - `c54ca19` — test: add required resource and provenance contract tests
   - `8af1d6f` — feat: complete required source and provenance validators
   - `4656c5d` — feat: publish compact source bundle registries
   - `537f596` — fix: preserve trusted relative raw paths
2. **Task 13-02-02: Add bounded capture, fallback, and blocked retention**
   - `52feb02` — test: add bounded capture and fallback tests
   - `4e283d2` — feat: add bounded UEFA snapshot acquisition
   - `539bc52` — feat: publish accepted competition snapshots

## Files Created/Modified

- `R/competition/source_contracts.R` - Required resource schemas, structured payload validation, provenance/hash enforcement, compact registry tables, and staged writers.
- `scripts/acquire_uefa_snapshot.R` - Bounded fixture/live acquisition, dry-run, fallback, blocked metadata, and accepted-output publication.
- `tests/testthat/test_phase13_source_contracts.R` - TDD coverage for schema drift, provenance, content safety, capture, fallback, and retention.
- `data/competition/registries/source_bundles.csv` and `source_artifacts.csv` - Compact committed bundle/artifact registries.
- `data/competition/accepted/{uefa_nations_league_2026_27,uefa_euro_2028_qualifying}/*.csv` - Accepted compact resource snapshots and manifests.
- `.gitignore` - Explicitly ignores `data/competition/local_raw/`.

## Decisions Made

- Required five-class structured source contracts are the acceptance boundary; HTML/PDF renderings cannot satisfy a resource requirement.
- Capture preserves exact raw bytes locally for reproducibility and hashing, while committed outputs remain compact and provenance-rich.
- Fallback is reviewed and edition-wide, and blocked candidates never overwrite the last accepted bundle.
- Pre-draw Euro resources remain empty but schema-valid to avoid inventing unavailable competition data.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected the malformed-hash RED test input**
- **Found during:** Task 13-02-01 (TDD RED verification)
- **Issue:** A string of 64 zeroes is a syntactically valid SHA-256 value, so it did not exercise malformed-hash rejection.
- **Fix:** Changed the test fixture value to `not-a-sha256` and amended the RED commit.
- **Files modified:** `tests/testthat/test_phase13_source_contracts.R`
- **Verification:** Focused tests pass with the malformed-hash rejection assertion exercised.
- **Committed in:** `c54ca19`

**2. [Rule 1 - Bug] Preserved valid relative raw paths after local raw-store creation**
- **Found during:** Task 13-02-01 (registry validation)
- **Issue:** `normalizePath()` converted a valid relative provenance path to an absolute path once the ignored raw directory existed, causing committed registries to reject themselves.
- **Fix:** Made relative-path validation syntactic and kept root containment in the separate path-under-root validator; added a regression test.
- **Files modified:** `R/competition/source_contracts.R`, `tests/testthat/test_phase13_source_contracts.R`
- **Verification:** Both committed source registries reload and validate after raw-store creation; focused and full suites pass.
- **Committed in:** `537f596`

**Total deviations:** 2 auto-fixed (Rule 1: 2)
**Impact on plan:** Both fixes were directly required for correct validation; no architectural scope changed.

## Issues Encountered

None unresolved. Live capture remains intentionally operator-supplied and bounded; deterministic fixture replay provides the automated verification path.

## Known Stubs

None. The zero-row Euro pre-draw resource tables are intentional schema-valid representations of source classes that do not exist before the draw.

## User Setup Required

None - no external service configuration is required for the committed fixture-backed workflow. Live capture accepts only explicit HTTPS URLs supplied at invocation.

## Next Phase Readiness

Plan 13-03 can consume the accepted compact snapshots, source registries, required resource contract, and blocked/fallback metadata without replacing the Wave 1 tracer. No blockers remain for the next plan.

## Self-Check: PASSED

- Summary file exists at the required phase path.
- All seven production/task commit hashes listed above exist in Git history.
- Focused and full verification commands passed.
- Required accepted snapshot files exist and `data/competition/local_raw` has no tracked files.

---
*Phase: 13-source-contracts-and-competition-registry*
*Plan: 02*
*Completed: 2026-08-13*
