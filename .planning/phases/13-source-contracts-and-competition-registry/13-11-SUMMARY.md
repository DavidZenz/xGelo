---
phase: 13-source-contracts-and-competition-registry
plan: "11"
subsystem: publication-integrity
tags: [R, sha256, canonical-csv, source-contracts, provenance, manifests]

# Dependency graph
requires:
  - phase: 13-04
    provides: normalized fixture/result projections and stable identity-bearing schemas
  - phase: 13-09
    provides: Nations League source-shaped five-resource handoff and registry lineage
  - phase: 13-10
    provides: EURO pre_draw source-shaped handoff and explicit status lineage
provides:
  - deterministic ten-resource canonical table and row-hash regeneration
  - staged source_artifacts.csv canonical projections preserving raw provenance
  - deterministic accepted manifests, source-bundle derived hashes, artifact-manifest hashes, and self-hashes
affects: [13-12, 13-05]

# Tech tracking
tech-stack:
  added: []
  patterns: [staged-root-only hash regeneration, canonical CSV bytes, fail-closed hash-graph validation]

key-files:
  created:
    - R/competition/publication_hashes.R
    - R/competition/publication_manifests.R
    - tests/testthat/test_phase13_publication_hashes.R
    - tests/testthat/test_phase13_publication_manifests.R
  modified: []

key-decisions:
  - "Canonical and derived hash helpers write only to a supplied staging root; locks, snapshots, promotion, and rollback remain Plan 13-12 responsibilities."
  - "Raw SHA-256 and source/provenance fields remain unchanged while row, canonical-content, derived bundle, artifact-manifest, and self-hashes are regenerated."
  - "Bundle canonical_content_sha256 follows the established complete non-circular bundle-content CSV projection, while manifest self-hashes use the existing source-contract self-hash convention."

patterns-established:
  - "The complete two-edition resource graph is declared explicitly as ten trusted normalized table targets."
  - "Every derived projection is rebuilt from validated staged bytes and exact edition/bundle/resource foreign keys before it is written."

requirements-completed: [DATA-02, DATA-03, DATA-04]

coverage:
  - id: D1
    description: "Ten normalized accepted resource tables receive deterministic row hashes and complete CSV-content hashes, with matching source-artifact canonical projections."
    requirement: DATA-02
    verification:
      - kind: unit
        ref: "tests/testthat/test_phase13_publication_hashes.R"
        status: pass
    human_judgment: false
  - id: D2
    description: "Both five-artifact accepted manifests and source-bundle derived hash rows are regenerated deterministically, including manifest self-hashes."
    requirement: DATA-03
    verification:
      - kind: unit
        ref: "tests/testthat/test_phase13_publication_manifests.R"
        status: pass
    human_judgment: false
  - id: D3
    description: "Stale, forged, duplicate, cross-edition, incomplete, and mixed-fallback graphs fail closed while EURO pre_draw empties and provenance remain truthful."
    requirement: DATA-04
    verification:
      - kind: unit
        ref: "combined focused Phase 13 publication hash and manifest test command"
        status: pass
    human_judgment: false

# Metrics
duration: 26m
completed: 2026-08-14
status: complete
---

# Phase 13 Plan 11: Deterministic canonical and accepted-manifest hash graph Summary

**Normalized ten-resource tables now regenerate canonical bytes, source-artifact projections, accepted manifests, bundle/artifact-manifest hashes, and self-hashes in a staging root without durable promotion.**

## Performance

- **Duration:** 26 minutes
- **Started:** 2026-08-14T13:10:50Z
- **Completed:** 2026-08-14T13:36:59Z
- **Tasks:** 2 completed
- **Files modified:** 4 plan-owned files

## Accomplishments

- Added an explicit two-edition/five-resource target graph and staged canonical refresh API that recomputes row hashes before complete CSV-byte hashes, preserves raw/provenance metadata, and enforces EURO pre_draw empty schemas.
- Added accepted-manifest regeneration for exactly five sorted artifact links per edition, with source-bundle derived hashes, bundle-content hashes, artifact-manifest hashes, manifest self-hashes, and stable row hashes.
- Added focused TDD coverage for ordering stability, durable-target non-mutation, provenance preservation, malformed links, stale/forged/duplicate/cross-edition graphs, mixed fallback status, on-disk round trips, and EURO status lineage.

## Task Commits

Each task was committed atomically:

1. **Task 13-11-01 RED: canonical hash tests** - `1e93400` (test)
2. **Task 13-11-01 GREEN: canonical table and source-artifact hash refresh** - `b74bcb5` (feat)
3. **Task 13-11-02 RED: accepted-manifest hash tests** - `6a29725` (test)
4. **Task 13-11-02 GREEN: accepted manifest and derived hash graph** - `dacdbc3` (feat)
5. **Task 13-11-02 correctness fix: established bundle canonical-content projection** - `b79cf4c` (fix)

**Plan metadata:** captured in the final GSD metadata commit with this summary, STATE.md, and ROADMAP.md.

## Files Created/Modified

- `R/competition/publication_hashes.R` - trusted ten-resource target declaration, staged normalized table validation/writes, row/canonical hash refresh, source-artifact projection, provenance checks, and pre_draw validation.
- `R/competition/publication_manifests.R` - canonical-output revalidation, exact source-artifact/bundle lineage checks, five-row accepted-manifest projection, derived source-bundle hashes, and self-hash regeneration.
- `tests/testthat/test_phase13_publication_hashes.R` - Task 1 RED/GREEN focused tests for canonical hash and source-artifact behavior.
- `tests/testthat/test_phase13_publication_manifests.R` - Task 2 RED/GREEN focused tests for manifest and derived hash behavior.

## Decisions Made

- Helpers are staging-only and perform no locking, snapshotting, promotion, rollback, or refresh-batch writes.
- Canonical table hashes are computed from the complete serialized CSV bytes after deterministic row-hash refresh; raw SHA-256 values continue to describe exact source response bytes.
- Accepted manifest output retains the established duplicate `canonical_content_sha256` positions: the bundle projection carries the aggregate bundle-content hash and the artifact projection carries each table’s canonical hash.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected vectorized provenance validation**
- **Found during:** Task 13-11-01 (GREEN implementation)
- **Issue:** A source-artifact guard used scalar `||` with vector conditions, which could reject or mishandle multi-row registry validation.
- **Fix:** Replaced it with explicit vector masks and aggregate checks.
- **Files modified:** `R/competition/publication_hashes.R`
- **Verification:** Canonical focused suite and combined focused gate pass.
- **Committed in:** `b74bcb5`

**2. [Rule 3 - Blocking] Allowed read-only target declaration before staging directories exist**
- **Found during:** Task 13-11-01 (acceptance smoke check)
- **Issue:** The explicit target-vector API required the accepted directory to exist even when a transaction had only created the empty staging root.
- **Fix:** Trusted path normalization now permits declaration against an existing staging root while refresh still requires every table file.
- **Files modified:** `R/competition/publication_hashes.R`
- **Verification:** Empty-root target-vector smoke check passes; refresh tests still require complete files.
- **Committed in:** `b74bcb5`

**3. [Rule 1 - Bug] Matched the established accepted-manifest schema and bundle-content hash convention**
- **Found during:** Task 13-11-02 (GREEN implementation and legacy registry comparison)
- **Issue:** Initial manifest projection introduced an extra self-row column and initially derived bundle canonical content from only artifact canonical hashes rather than the established complete non-circular bundle-content CSV body.
- **Fix:** Restored the existing 35-column manifest shape with its manifest `row_sha256`, and aligned bundle `canonical_content_sha256` with the existing Phase 13 bundle-content projection.
- **Files modified:** `R/competition/publication_manifests.R`, `tests/testthat/test_phase13_publication_manifests.R`
- **Verification:** On-disk manifest round trips and combined focused gate pass.
- **Committed in:** `dacdbc3`, `b79cf4c`

**Total deviations:** 3 auto-fixed (2 Rule 1, 1 Rule 3)
**Impact on plan:** All fixes were directly required for correct staged hash-graph behavior; no scope expansion occurred.

## Issues Encountered

No unresolved issues. Pre-existing unrelated dirty and untracked user work was preserved and never staged.

## Self-Check: PASSED

- Summary file exists at the declared phase path.
- All five Task 1/Task 2 commits are present in git history.
- Scoped diff check passes with no whitespace errors.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 13-12 can source `publication_hashes.R` and `publication_manifests.R`, normalize both handoff editions in its sibling staging root, invoke the helpers in order, and then own the 14-target transaction, lock, promotion, and rollback. Plan 13-05 loaders were not implemented here.

---
*Phase: 13-source-contracts-and-competition-registry*
*Completed: 2026-08-14*
