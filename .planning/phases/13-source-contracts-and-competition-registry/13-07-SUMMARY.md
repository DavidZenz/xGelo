---
phase: 13-source-contracts-and-competition-registry
plan: "07"
subsystem: data-capture
tags: [R, httr2, json, provenance, sha256, source-contracts]

# Dependency graph
requires:
  - phase: 13-source-contracts-and-competition-registry
    provides: Phase 13 structured source-contract APIs and validators from Plan 13-02
provides:
  - bounded HTTPS structured capture with retry, rate-limit, byte, content, and schema guards
  - capture-only exact raw retention and compact source bundle/artifact registries
  - explicit and derived status provenance plus reviewed-fallback metadata
affects: [13-09, 13-10, 13-11, 13-12, source-capture, competition-publication]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - injectable httr2 request/perform/clock/sleep seams for deterministic bounded capture tests
    - staged pairwise CSV promotion with rollback and exact-byte raw-store verification
    - canonical CSV-with-header SHA-256 values alongside exact raw-response hashes

key-files:
  created: []
  modified:
    - scripts/acquire_uefa_snapshot.R
    - tests/testthat/test_phase13_source_contracts.R
    - data/competition/registries/source_bundles.csv
    - data/competition/registries/source_artifacts.csv

key-decisions:
  - "Capture-only is the default; accepted-directory publication remains an explicit opt-in for legacy replay checks and later plans own normal publication."
  - "A missing status URL is valid only when one unambiguous status and edition identity can be derived from validated mandatory structured resources."
  - "Derived status lineage is recorded as sorted contributing source artifact IDs and URL lineage, while canonical content hashes cover complete CSV bytes including headers."

patterns-established:
  - "Live capture uses one bounded httr2 seam with at most three attempts, transient-status retries, capped exponential backoff, and a shared minimum request interval."
  - "Registry updates validate every edition bundle from staged CSVs before promoting the bundle/artifact pair."

requirements-completed: [DATA-01, DATA-02, DATA-04]

coverage:
  - id: D1
    description: "Bounded HTTPS structured capture assembles five resource classes and supports explicit or derived status provenance."
    requirement: DATA-01
    verification:
      - kind: unit
        ref: "tests/testthat/test_phase13_source_contracts.R#bounded live fetch retries transient responses through injectable httr2 callbacks"
        status: pass
      - kind: integration
        ref: "Rscript --vanilla -e 'testthat::test_file(\"tests/testthat/test_phase13_source_contracts.R\")'"
        status: pass
    human_judgment: false
  - id: D2
    description: "Exact local raw bytes and compact source registries retain URL lineage, raw and canonical hashes, parser identity, and stable row hashes."
    requirement: DATA-02
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase13_source_contracts.R#capture-only registries retain exact raw bytes and canonical source hashes"
        status: pass
      - kind: other
        ref: "tracked source_bundles.csv/source_artifacts.csv validation via phase13_validate_source_bundle"
        status: pass
    human_judgment: false
  - id: D3
    description: "Reviewed fallback provenance remains complete and edition-wide without mixing official and fallback artifacts."
    requirement: DATA-04
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase13_source_contracts.R#reviewed fallback acceptance is complete and never mixes provenance"
        status: pass
    human_judgment: false

# Metrics
duration: 20min
completed: 2026-08-14
status: complete
---

# Phase 13 Plan 07: Bounded Capture and Compact Source Registries Summary

**Bounded five-class UEFA structured capture with optional derived status, exact ignored raw retention, and hash-backed source registries**

## Performance

- **Duration:** 20 min
- **Started:** 2026-08-14T11:22:19Z
- **Completed:** 2026-08-14T11:42:09Z
- **Tasks:** 2 completed
- **Files modified:** 4

## Accomplishments

- Added the injectable httr2 capture seam with HTTPS enforcement, JSON/content/schema validation, bounded retries, capped backoff, request spacing, and deterministic callback tests.
- Added status derivation from validated mandatory resources when no separate status URL exists, preserving contributing artifact IDs and URL lineage.
- Added capture-only exact-byte local retention, canonical CSV content hashes, staged pairwise registry promotion, rollback protection, and refreshed official registries for both Phase 13 editions.
- Preserved complete reviewed-fallback metadata and made accepted-directory publication explicit rather than coupling it to source capture.

## Task Commits

Each task was committed atomically; TDD tasks include their RED and GREEN commits:

1. **Task 13-07-01: Trace bounded structured capture with optional status derivation**
   - RED: `9a77750` (test)
   - GREEN: `53011f3` (feat)
2. **Task 13-07-02: Persist compact source registries and reviewed fallback provenance**
   - RED: `362d35c` (test)
   - GREEN: `02078e0` (feat)

**Plan metadata:** final execution metadata commit is recorded in the completion report.

## Files Created/Modified

- `scripts/acquire_uefa_snapshot.R` - bounded live/fixture capture, status provenance, exact raw staging, canonical hashes, and atomic registries.
- `tests/testthat/test_phase13_source_contracts.R` - retry, derivation, raw/hash, fallback, capture-only, and atomic-write regressions.
- `data/competition/registries/source_bundles.csv` - refreshed two-edition bundle registry with canonical content hashes.
- `data/competition/registries/source_artifacts.csv` - refreshed ten-artifact registry with lineage, provenance, raw hashes, canonical hashes, and row hashes.
- `.gitignore` - required `data/competition/local_raw/` rule was already present and needed no diff.

## Decisions Made

- Capture-only is the default so source acquisition does not publish accepted competition tables; `--publish-accepted` remains an explicit compatibility path.
- Status derivation requires unambiguous status-bearing and edition-bearing fields in the four validated mandatory resources; missing or conflicting evidence fails closed.
- Exact raw response hashes and canonical CSV-with-header hashes are stored separately to distinguish byte replay from source-shaped table content.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Normalized script resolution for sourced test environments**
- **Found during:** Task 13-07-01
- **Issue:** `sys.source()` from `tests/testthat` resolved the entrypoint relative to the test directory, preventing the script from locating the project source-contract file.
- **Fix:** Normalize the resolved script path and make the test loader temporarily source from the project root.
- **Files modified:** `scripts/acquire_uefa_snapshot.R`, `tests/testthat/test_phase13_source_contracts.R`
- **Verification:** Focused suite passes with 122 assertions.
- **Committed in:** `53011f3`

**2. [Rule 1 - Bug] Fixed named-vector status URL access**
- **Found during:** Task 13-07-01
- **Issue:** The live input stores source URLs as a named atomic vector, so `$status` access failed during candidate finalization and derived-status assertions.
- **Fix:** Use named indexing with `[["status"]]` for status URL reads and writes, and align the regression assertions.
- **Files modified:** `scripts/acquire_uefa_snapshot.R`, `tests/testthat/test_phase13_source_contracts.R`
- **Verification:** Focused suite passes with 122 assertions and no warnings.
- **Committed in:** `53011f3`

**Total deviations:** 2 auto-fixed (1 Rule 3 blocking, 1 Rule 1 bug)
**Impact on plan:** Both fixes were directly required for the planned capture and test paths; no unrelated scope was added.

## Issues Encountered

- Context7 was unavailable and `ctx7` was not installed; the existing local httr2 1.2.2 API was inspected and used without adding dependencies.
- No authentication gate, human checkpoint, skipped test, unrun verification, or unresolved blocker occurred.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plans 13-09 and 13-10 can consume the five-class source-shaped seed registries and exact local raw paths. Plans 13-11 and 13-12 remain responsible for normalized canonical publication and final promotion; no blocker remains for those handoffs.

## Self-Check: PASSED

- SUMMARY.md exists at the required plan path.
- RED and GREEN task commits `9a77750`, `53011f3`, `362d35c`, and `02078e0` are present in Git history.
- Focused source-contract tests and tracked-registry validation pass.

---
*Phase: 13-source-contracts-and-competition-registry*
*Completed: 2026-08-14*
