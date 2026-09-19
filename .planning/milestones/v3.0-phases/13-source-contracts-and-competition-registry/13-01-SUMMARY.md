---
phase: 13-source-contracts-and-competition-registry
plan: "01"
subsystem: data-contracts
tags: [R, UEFA, provenance, SHA-256, team-identity, competition-registry, testthat]

# Dependency graph
requires:
  - phase: 12-calibration-release
    provides: approved Phase 12 model release slot for downstream competition editions
provides:
  - edition-scoped structured source artifact and bundle contracts with exact-byte provenance
  - stable xGelo team identity resolution with visible normalized-name fallback metadata
  - lifecycle-aware competition edition registry rows linked to source bundles and model releases
  - compact Nations League, EURO pre-draw, and reviewed-fallback fixtures for deterministic contract tests
affects: [13-02-source-capture, 13-03-registry-expansion, phase-14-shared-competition-state]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Compute raw-byte and canonical table SHA-256 values with digest while keeping exact response bodies outside Git."
    - "Use edition-scoped accepted bundles with uniform official or reviewed-fallback provenance."
    - "Resolve direct UEFA IDs first and expose deterministic normalized-name fallback warnings."
    - "Represent lifecycle progression and blocked overlays as validated registry metadata."

key-files:
  created:
    - R/competition/source_contracts.R
    - R/competition/team_identity.R
    - R/competition/edition_registry.R
    - tests/testthat/test_phase13_source_contracts.R
    - tests/testthat/test_phase13_competition_registry.R
    - tests/fixtures/phase13/uefa_nations_league_sample.json
    - tests/fixtures/phase13/euro2028_predraw_sample.json
    - tests/fixtures/phase13/reviewed_fallback_bundle.json
  modified: []

key-decisions:
  - "Use one edition-scoped source-bundle abstraction for official and reviewed fallback variants; reject mixed provenance."
  - "Persist the Git commit SHA as parser identity and retain only compact hashes and metadata in committed artifacts."
  - "Keep normalized display-name fallback visible and fail closed on unresolved or ambiguous team identity."
  - "Register EURO qualifying as explicit pre_draw metadata with non-null source/output slots and no fabricated structures."

requirements-completed: [DATA-01, DATA-02, DATA-03, DATA-04, COMP-01]

coverage:
  - id: D1
    description: "A compact structured UEFA resource set becomes an accepted edition-scoped source bundle with artifact provenance and stable hashes."
    requirement: DATA-01
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase13_source_contracts.R"
        status: pass
      - kind: unit
        ref: "Rscript --vanilla -e 'testthat::test_file(\"tests/testthat/test_phase13_source_contracts.R\")'"
        status: pass
    human_judgment: false
  - id: D2
    description: "Fixture rows resolve to stable xGelo team IDs while preserving UEFA display names and recording fallback warnings."
    requirement: DATA-03
    verification:
      - kind: unit
        ref: "tests/testthat/test_phase13_competition_registry.R"
        status: pass
      - kind: unit
        ref: "Rscript --vanilla -e 'testthat::test_file(\"tests/testthat/test_phase13_competition_registry.R\")'"
        status: pass
    human_judgment: false
  - id: D3
    description: "Competition editions retain lifecycle, blocked-overlay, source-bundle, model-release, and output-slot invariants."
    requirement: COMP-01
    verification:
      - kind: unit
        ref: "tests/testthat/test_phase13_competition_registry.R"
        status: pass
      - kind: integration
        ref: "Rscript --vanilla -e 'testthat::test_dir(\"tests/testthat\")'"
        status: pass
    human_judgment: false

# Metrics
duration: 25 min
completed: 2026-08-13
status: complete
---

# Phase 13 Plan 01: Source Contracts and Competition Registry Summary

**Auditable structured UEFA source bundles, stable team identity mappings, and lifecycle-aware competition edition rows are now covered by a compact TDD tracer and edge-contract suite.**

## Performance

- **Duration:** 25 min
- **Started:** 2026-08-13T19:36:56Z
- **Completed:** 2026-08-13T20:02:22Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments

- Added exact-byte artifact metadata, Git parser identity, order-stable SHA-256 helpers, required-resource validation, uniform fallback checks, and accepted source-bundle validation.
- Added stable team identity preparation and resolution with UEFA source IDs, preserved display names, normalized-name fallback warnings, and ambiguity rejection.
- Added explicit competition edition rows with pinned Phase 12 model release, source/output slots, forward lifecycle transitions, blocked refresh metadata, and last-accepted output retention.
- Added compact official Nations League, EURO pre-draw, and reviewed-fallback fixtures plus focused tests covering source, provenance, identity, registry, and publication-boundary prohibitions.

## Task Commits

Each task followed RED/GREEN TDD commits:

1. **Task 13-01-01: End-to-end structured fixture to accepted bundle and registry row**
   - RED `81e7b0d` (test)
   - GREEN `8f6095e` (feat)
2. **Task 13-01-02: Expand Wave 0 contracts for edge probes and prohibitions**
   - RED `992254e` (test)
   - GREEN `cfa0832` (feat)

## Verification

- Focused Phase 13 tests: **24 source-contract assertions and 31 registry assertions passed; 0 failures, warnings, or skips**.
- Full `tests/testthat/` suite: **2,650 assertions passed; 0 failures, warnings, or skips** in 354.0 seconds.
- `git ls-files data/competition/local_raw`: **none**.

## Files Created/Modified

- `R/competition/source_contracts.R` - Exact-byte artifact, bundle, parser identity, path, hash, fallback, and acceptance contracts.
- `R/competition/team_identity.R` - Stable team IDs, UEFA source/display attributes, aliases, and warning-bearing fallback resolution.
- `R/competition/edition_registry.R` - Edition release slots, lifecycle transitions, blocked overlays, and order-stable registry validation.
- `tests/testthat/test_phase13_source_contracts.R` - Structured bundle, provenance, fallback, schema-drift, raw-byte, and raw-store tests.
- `tests/testthat/test_phase13_competition_registry.R` - Identity, pre-draw, lifecycle, blocked-output, and registry-hash tests.
- `tests/fixtures/phase13/` - Compact structured fixtures only; no exact raw response bodies.

## Decisions Made

- Kept official and reviewed fallback snapshots inside one edition-scoped bundle contract so provenance mixing cannot pass acceptance.
- Used the Git commit SHA as parser identity, matching the locked D-08 decision.
- Made normalized display-name identity fallback warning-bearing and rejected ambiguous matches.
- Kept EURO qualifying explicitly `pre_draw` with real source/output metadata and no fabricated groups, fixtures, standings, or probabilities.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected the registry order-stability RED fixture**
- **Found during:** Task 13-01-02 RED verification
- **Issue:** The first test compared hashes of two rows with the same edition ID, which is invalid for the unique-key registry and makes input-order sorting inherently ambiguous.
- **Fix:** Changed the hash fixture to use distinct Nations League and EURO edition IDs before rerunning RED.
- **Files modified:** `tests/testthat/test_phase13_competition_registry.R`
- **Verification:** RED retained only the intended missing-API failures; GREEN and full-suite gates passed.
- **Committed in:** `992254e`

**2. [Rule 1 - Bug] Prevented the API-seam test from being treated as an empty test**
- **Found during:** Task 13-01-01 GREEN verification
- **Issue:** testthat skipped a side-effect-only API existence gate because it contained no expectation.
- **Fix:** Added an explicit truth assertion after the API check so the RED/GREEN gate remains executable and visible.
- **Files modified:** `tests/testthat/test_phase13_source_contracts.R`
- **Verification:** Focused tests pass with zero skips.
- **Committed in:** `8f6095e`

**Total deviations:** 2 auto-fixed (2 Rule 1 test-contract corrections).
**Impact on plan:** No architectural or scope change; both fixes made the planned TDD and order-stability gates executable.

## Issues Encountered

- Git index writes in the shared checkout initially required repository write approval from the sandbox; approval was granted and all atomic commits completed.
- The GSD `state.update-progress` handler reported no-op because this legacy `STATE.md` has no progress-bar field; the frontmatter counters and roadmap plan count were updated, and the human-readable state table was synchronized manually.
- No authentication gates or external service setup were required.

## TDD Gate Compliance

- Task 13-01-01: RED `81e7b0d` precedes GREEN `8f6095e`.
- Task 13-01-02: RED `992254e` precedes GREEN `cfa0832`.
- No refactor commit was necessary; focused and full suites remained green.

## Known Stubs

None. The pre-draw empty resource list is an intentional truthful fixture, not a UI or production-data stub.

## Next Phase Readiness

Plan 13-02 can build bounded UEFA capture and local raw-byte retention on the accepted bundle/artifact contracts. Plan 13-03 can expand the identity and edition registries without creating a parallel official/fallback path.

## Self-Check: PASSED

- All 8 planned code, test, and compact fixture files exist.
- All 4 RED/GREEN task commits are present in Git history.
- Focused and full verification commands passed with no failures, warnings, or skips.
- No exact raw response bodies are tracked under `data/competition/local_raw`.

---
*Phase: 13-source-contracts-and-competition-registry*
*Plan: 01*
*Completed: 2026-08-13*
