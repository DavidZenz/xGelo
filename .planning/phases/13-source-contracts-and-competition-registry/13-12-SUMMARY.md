---
phase: 13-source-contracts-and-competition-registry
plan: 12
subsystem: competition-publication
tags: [R, atomic-publication, rollback, sha256, provenance, UEFA]

# Dependency graph
requires:
  - phase: 13-11
    provides: staged canonical table/hash and accepted-manifest/derived-hash refresh helpers
  - phase: 13-09/13-10
    provides: validated source-shaped Nations League and EURO pre_draw handoff trees
provides:
  - exact fourteen-target normalized publication transaction with lock, snapshots, promotion, and rollback
  - production acquisition integration for both edition handoffs and the complete hash graph
  - focused success, identity-stability, stale-link, and every-promotion-failure regressions
affects: [13-05 post-normalization loaders, 13-06 durable blocked-refresh state]

# Tech tracking
tech-stack:
  added: []
  patterns: [trusted sibling roots, byte/hash snapshots, sibling staging and backup roots, ordered all-target promotion]

key-files:
  created:
    - R/competition/publication_transaction.R
    - tests/testthat/test_phase13_publication_transaction.R
    - tests/testthat/test_phase13_publication_integration.R
  modified:
    - scripts/acquire_uefa_snapshot.R

key-decisions:
  - "The durable publication envelope owns exactly fourteen files: two shared registries, two edition manifests, and ten edition resource tables; refresh_batches is never a target or cleanup path."
  - "Canonical table/hash and accepted-manifest/derived-hash regeneration remains delegated to the Plan 13-11 helpers inside the transaction staging root."
  - "The acquisition entrypoint uses the normalized transaction when both trusted edition handoffs and registry context are present, while retaining the existing one-edition temporary fixture replay path for isolated capture tests."

patterns-established:
  - "Every normalized publication attempt acquires one sibling-root lock, seeds a project-shaped staging root, validates the complete graph, promotes in deterministic target order, and restores exact pre-transaction bytes on any error."
  - "Source-shaped handoff provenance may be newer than the shared registry seed only when its retrieval timestamp is newer and its canonical bytes remain internally consistent; equal-or-older conflicts fail closed."

requirements-completed: [DATA-01, DATA-02, DATA-03, DATA-04]

coverage:
  - id: D1
    description: "Locked fourteen-target normalized publication with complete hash/provenance validation and byte-for-byte rollback."
    requirement: DATA-03
    verification:
      - kind: integration
        ref: tests/testthat/test_phase13_publication_transaction.R
        status: pass
      - kind: integration
        ref: tests/testthat/test_phase13_publication_integration.R
        status: pass
    human_judgment: false
  - id: D2
    description: "Both source-shaped editions normalize to stable identity-bearing fixtures/results while EURO remains truthful pre_draw."
    requirement: DATA-03
    verification:
      - kind: integration
        ref: tests/testthat/test_phase13_publication_integration.R#normalized identity and edition assignments remain stable under source row changes
        status: pass
      - kind: other
        ref: Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_publication_hashes.R"); testthat::test_file("tests/testthat/test_phase13_publication_manifests.R")'
        status: pass
    human_judgment: false

# Metrics
duration: 29min
completed: 2026-08-14
status: complete
---

# Phase 13 Plan 12: Normalized Publication Transaction Summary

**Locked all-or-nothing promotion of both normalized UEFA editions and their complete fourteen-file canonical/manifest hash graph**

## Performance

- **Duration:** 29 minutes
- **Started:** 2026-08-14T13:47:48Z
- **Completed:** 2026-08-14T14:12:05Z
- **Tasks:** 2/2
- **Files modified:** 4

## Accomplishments

- Added an exclusive-lock publication envelope with trusted-root guards, exact existence/bytes/SHA-256 snapshots, project-shaped sibling staging, deterministic promotion, and complete rollback after any injected failure.
- Integrated both source-shaped handoffs into acquisition: fixtures/results are normalized through the stable identity resolver, groups/standings/status are carried through staging, and Plan 13-11 canonical and manifest helpers run before promotion.
- Added regressions covering the fourteen-target boundary, refresh-batch isolation, complete graph validation, stale/forged source links, identity stability, and injected failure after every target promotion.

## Task Commits

Each task was committed atomically with TDD RED/GREEN gates:

1. **Task 13-12-01: Build the publication lock, target snapshot, and rollback envelope**
   - `71ceee8` — test(13-12): add publication transaction rollback tests
   - `58cee7a` — feat(13-12): add locked normalized publication transaction
2. **Task 13-12-02: Integrate normalized hash-graph publication into acquisition**
   - `65354b3` — test(13-12): add normalized publication integration regressions
   - `1b1363a` — feat(13-12): integrate normalized dual-edition publication

## Files Created/Modified

- `R/competition/publication_transaction.R` — exact fourteen-target lock, snapshot, staging, promotion, and rollback APIs.
- `scripts/acquire_uefa_snapshot.R` — normalized dual-edition publication, complete graph validator, candidate integration, and production acquisition routing.
- `tests/testthat/test_phase13_publication_transaction.R` — lock, snapshot, cleanup, and every-index rollback tests.
- `tests/testthat/test_phase13_publication_integration.R` — temporary-root publication, provenance, identity, pre_draw, and failure-injection tests.

## Verification

- `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_publication_transaction.R"); testthat::test_file("tests/testthat/test_phase13_publication_integration.R")'` — passed, 206 expectations.
- `Rscript --vanilla -e 'source("R/competition/publication_transaction.R"); stopifnot(length(phase13_normalized_publication_targets("data/competition/accepted", "data/competition/registries")) == 14L)'` — passed.
- Plan 13-11 focused suites — passed, 107 hash expectations and 69 manifest expectations.
- Existing source-contract suite — passed, 178 expectations.
- Temporary-root candidate publication and `phase13_acquire_main(... --publish-accepted)` production routing checks — passed.

## Decisions Made

- `refresh_batches` remains a separate registry-side durability boundary owned by Plan 13-06; it is excluded from targets, backups, deletions, renames, and cleanup.
- Hash ownership stays layered: the transaction coordinates and validates, while the Plan 13-11 helpers calculate row, canonical, artifact, bundle, and manifest hashes.
- Existing isolated one-edition fixture replay remains available only when a complete two-edition production handoff context is absent; production roots route through the normalized transaction.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected transaction path validation and platform-stable test expectations**
- **Found during:** Task 13-12-01 GREEN
- **Issue:** An under-escaped R path-boundary regex caused parsing/runtime failure, and macOS canonicalized temporary roots through `/private` while the test expected `/var`.
- **Fix:** Corrected the regex and compared canonicalized roots in the test.
- **Files modified:** `R/competition/publication_transaction.R`, `tests/testthat/test_phase13_publication_transaction.R`
- **Verification:** Transaction suite passed 117 expectations.
- **Committed in:** `58cee7a`

**2. [Rule 3 - Blocking] Shaped the staging root for the Plan 13-11 helper contract**
- **Found during:** Task 13-12-02 GREEN
- **Issue:** The transaction initially staged relative targets directly below the temporary root, but the independently proven helpers require `data/competition/accepted` and `data/competition/registries` below their staging root.
- **Fix:** Staging targets now use the project-shaped `data/competition` prefix while durable targets remain the exact fourteen sibling-root files.
- **Files modified:** `R/competition/publication_transaction.R`
- **Verification:** Hash, manifest, transaction, and integration suites passed.
- **Committed in:** `1b1363a`

**3. [Rule 1 - Test correctness] Stabilized integration harness loading and identity comparisons**
- **Found during:** Task 13-12-02 RED/GREEN
- **Issue:** `sys.source()` needed the project working directory for the script path resolver, and reordered data frames carried different row-name attributes despite identical identity fields.
- **Fix:** Scoped the test working directory and normalized row names before identity comparison; the forged-link test snapshots after its intentional registry mutation.
- **Files modified:** `tests/testthat/test_phase13_publication_integration.R`
- **Verification:** Integration suite passed 89 expectations and the existing source suite remained green.
- **Committed in:** `65354b3` and `1b1363a`

**Total deviations:** 3 auto-fixed issues (2 correctness, 1 blocking contract alignment)

**Impact on plan:** All fixes were directly required to execute the declared transaction and its tests; no downstream competition logic or Plan 13-05/13-06 functionality was added.

## Issues Encountered

None remain. Existing unrelated dirty and untracked user work was preserved and excluded from all commits.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

The accepted path now exposes normalized stable IDs and a validated, loader-ready hash graph for Plan 13-05. Registry-side blocked-refresh durability remains intentionally separate for Plan 13-06.

## Self-Check: PASSED

- Summary file exists at the declared phase path.
- All four per-task TDD commits are present in git history.

---
*Phase: 13-source-contracts-and-competition-registry*
*Plan: 12*
*Completed: 2026-08-14*
