---
phase: 13-source-contracts-and-competition-registry
plan: "05"
subsystem: competition-registry
tags: [R, accepted-snapshots, provenance, sha256, UEFA]

# Dependency graph
requires:
  - phase: 13-12
    provides: transactional normalized fourteen-target publication graph and refreshed accepted handoffs
provides:
  - fail-closed accepted snapshot validation on the production edition loader
  - normalized result identity and artifact-lineage checks for both competition editions
  - mandatory default team-identity source-bundle foreign-key validation
  - temporary-copy regressions for missing, tampered, stale-hash, forged-link, and pre_draw cases
affects: [13-06, phase-14, competition-registry-consumers]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - fail-closed accepted-directory and manifest validation before registry return
    - canonical whole-table SHA-256 checks independent of row-hash recomputation
    - adjacent source-bundle provenance loading for default identity consumers
    - fixture-backed production replay followed by atomic fourteen-target promotion

key-files:
  created:
    - .planning/phases/13-source-contracts-and-competition-registry/deferred-items.md
  modified:
    - R/competition/edition_registry.R
    - R/competition/publication_manifests.R
    - R/competition/team_identity.R
    - tests/testthat/test_phase13_competition_registry.R
    - data/competition/registries/source_artifacts.csv
    - data/competition/registries/source_bundles.csv
    - data/competition/accepted/{uefa_nations_league_2026_27,uefa_euro_2028_qualifying}/*.csv

key-decisions:
  - "Use Plan 13-12's production normalized publication transaction to regenerate the complete fourteen-target graph from committed compact fixtures; do not repair hashes manually."
  - "Keep accepted snapshots and refresh-batch history as separate trust boundaries; this loader validates only the replaceable accepted tree."
  - "Set bundle source_bundle_sha256 and artifact_manifest_sha256 before computing bundle canonical content so the canonical hash covers its complete non-circular projection."

patterns-established:
  - "Validate accepted table schemas, row hashes, canonical content hashes, manifest links, raw provenance, and edition identity as one chain before returning production state."
  - "Derive the default team identity source-bundle registry from the identity file's adjacent registry directory and fail closed when it is absent."

requirements-completed: [DATA-02, DATA-03, COMP-01]

coverage:
  - id: D1
    description: "Production edition loading validates both accepted edition directories, their five resource tables, manifests, registries, hashes, and normalized result lineage."
    requirement: COMP-01
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase13_competition_registry.R"
        status: pass
      - kind: other
        ref: "Rscript --vanilla -e production load_competition_edition_registries() check"
        status: pass
    human_judgment: false
  - id: D2
    description: "Default team identity loading validates adjacent source-bundle provenance and EURO remains an explicit, schema-valid empty pre_draw snapshot."
    requirement: DATA-03
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase13_competition_registry.R"
        status: pass
      - kind: other
        ref: "Rscript --vanilla -e load_phase13_team_identity_registry() check"
        status: pass
    human_judgment: false
  - id: D3
    description: "Temporary-copy regressions prove missing directories, recomputed-row tampering, stale canonical hashes, forged manifest links, and forged identity foreign keys fail closed."
    requirement: DATA-02
    verification:
      - kind: unit
        ref: "tests/testthat/test_phase13_competition_registry.R (103 passing assertions)"
        status: pass
    human_judgment: false

# Metrics
duration: 1h 10m
completed: 2026-08-14
status: complete
---

# Phase 13 Plan 05: Accepted Snapshot Loader Summary

**Fail-closed accepted-snapshot and identity-provenance loading over a regenerated, fixture-backed normalized fourteen-target publication graph**

## Performance

- **Duration:** approximately 1h 10m
- **Started:** 2026-08-14T14:14:18Z
- **Completed:** 2026-08-14T15:24:00Z
- **Tasks:** 2/2
- **Files modified:** 13 implementation, test, and accepted/registry graph files

## Accomplishments

- Wired `load_competition_edition_registries()` through accepted-directory, exact-schema, normalized identity, table-row-hash, canonical-content-hash, raw-provenance, manifest, bundle, and artifact-lineage validation.
- Replayed the committed compact fixtures through the existing acquisition/publication helpers and atomically regenerated the complete fourteen-target graph, including both accepted manifests, all ten accepted resource hash rows, derived bundle/manifest/self hashes, and row hashes.
- Made the default identity loader require the adjacent `source_bundles.csv`, and added temporary-copy regressions for missing provenance and forged non-accepted bundle IDs even after row-hash recomputation.
- Preserved EURO `pre_draw` truthfulness: normalized fixtures/results and source-shaped groups/standings are empty but schema-valid, with explicit status metadata.
- Preserved macOS `/var` versus `/private/var` path alias handling in trusted-root validation.

## Task Commits

Each task was committed atomically:

1. **Task 13-05-01: Validate accepted snapshot directories through the edition loader** - `8fc3164` (`feat`)
2. **Task 13-05-02: Enforce source-bundle provenance in the default identity loader** - `aa32b0e` (`feat`)

**Plan metadata:** captured in the final GSD metadata commit.

## Files Created/Modified

- `R/competition/edition_registry.R` - accepted snapshot root, table, manifest, provenance, hash, normalized lineage, and pre_draw validators on the production loader path.
- `R/competition/publication_manifests.R` - canonical bundle content hashing now includes derived artifact-manifest/source-bundle hash fields before the content hash is calculated.
- `R/competition/team_identity.R` - default adjacent source-bundle registry loading and validation.
- `tests/testthat/test_phase13_competition_registry.R` - production and temporary-copy regressions covering all requested fail-closed cases.
- `data/competition/accepted/{uefa_nations_league_2026_27,uefa_euro_2028_qualifying}/*.csv` - fixture-backed normalized accepted graph and refreshed manifest/table hashes.
- `data/competition/registries/source_artifacts.csv` and `source_bundles.csv` - regenerated canonical, derived, raw, and row-hash provenance graph.

## Decisions Made

- The accepted loader owns the replaceable accepted-directory boundary; Plan 13-06 remains responsible for registry-side `refresh_batches` blocked records and append-only history.
- Production graph repair uses the Plan 13-12 normalizer and atomic promotion over committed compact fixtures. Hashes were not edited ad hoc.
- Bundle canonical content is computed only after derived bundle hash fields are populated, keeping the hash contract complete and non-circular.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Integrity bug] Regenerated stale accepted graph through the production normalizer**
- **Found during:** Task 13-05-01 (production loader replay)
- **Issue:** The accepted manifests contained stale row hashes and the fixture-backed EURO raw status bytes disagreed with the old registry metadata.
- **Fix:** Rebuilt source-shaped handoffs from the committed fixtures, invoked the existing Plan 13-12 normalized publication helpers, refreshed the complete graph, and promoted all fourteen targets transactionally under the existing publication lock.
- **Files modified:** `data/competition/accepted/`, `data/competition/registries/source_artifacts.csv`, `data/competition/registries/source_bundles.csv`
- **Verification:** Focused registry suite and production loader both pass; no live source access was used.
- **Committed in:** `8fc3164`

**2. [Rule 1 - Integrity bug] Corrected publication-helper hash ordering**
- **Found during:** Task 13-05-01 canonical-hash regression
- **Issue:** The bundle canonical content hash was computed before `source_bundle_sha256` and `artifact_manifest_sha256` were assigned, so it did not cover the complete bundle projection.
- **Fix:** Assign both derived hash fields before computing `canonical_content_sha256` and add a direct helper regression.
- **Files modified:** `R/competition/publication_manifests.R`, `tests/testthat/test_phase13_competition_registry.R`
- **Verification:** The focused suite passes all 103 assertions, including recomputation of the rebuilt canonical bundle hash.
- **Committed in:** `8fc3164`

---

**Total deviations:** 2 auto-fixed (Rule 1 integrity corrections)
**Impact on plan:** Both changes were required to make the requested production graph and hash contract truthful; no unrelated implementation was changed.

## Issues Encountered

- An unrelated Plan 13-11 publication-manifest test harness currently fails five cases because its temporary seed passes normalized accepted tables to a source-shaped normalizer. This is recorded in [`deferred-items.md`](./deferred-items.md) and was not changed in this plan.

## Verification

- `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_competition_registry.R", reporter = "progress")'` — **103 passed, 0 failed, 0 skipped**.
- Production `load_competition_edition_registries()` — both editions load with two accepted snapshots and normalized Nations League identity/provenance.
- Default `load_phase13_team_identity_registry()` — committed identity registry loads with adjacent accepted source-bundle provenance.
- Fixture-backed normalized publication replay — complete fourteen-target transaction and post-normalization graph validation succeeded.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 13-05 is complete and ready for Phase 13 verification. Plan 13-06 can consume the accepted loader contract while retaining ownership of registry-side blocked refresh metadata and append-only status history. The unrelated Plan 13-11 test-seeding mismatch remains deferred to its owner.

---
*Phase: 13-source-contracts-and-competition-registry*
*Completed: 2026-08-14*

## Self-Check: PASSED

- Summary and deferred-items files exist.
- Task commits `8fc3164` and `aa32b0e` exist in git history.
- Focused verification passed with 103 assertions and no failures.
