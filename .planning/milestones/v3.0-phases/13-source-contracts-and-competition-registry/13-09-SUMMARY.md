---
phase: 13-source-contracts-and-competition-registry
plan: "09"
subsystem: data-capture
tags: [R, source-contracts, provenance, atomic-publication, nations-league]

# Dependency graph
requires:
  - phase: 13-07
    provides: bounded five-class UEFA capture, exact local raw retention, and compact source registries
provides:
  - fail-closed staged accepted-directory publication for one source-shaped edition
  - validated Nations League manifest and five-class handoff for later normalization and hash-graph sealing
  - explicit/derived status lineage and a registry refresh-batch replacement boundary
affects: [13-04, 13-05, 13-11, 13-12]

# Tech tracking
tech-stack:
  added: []
  patterns: [staged sibling promotion, backup-and-rollback, canonical CSV hashing, trusted registry boundary]

key-files:
  created: []
  modified:
    - scripts/acquire_uefa_snapshot.R
    - tests/testthat/test_phase13_source_contracts.R
    - data/competition/accepted/uefa_nations_league_2026_27/source_bundle_manifest.csv
    - data/competition/accepted/uefa_nations_league_2026_27/fixtures.csv
    - data/competition/accepted/uefa_nations_league_2026_27/groups.csv
    - data/competition/accepted/uefa_nations_league_2026_27/standings.csv
    - data/competition/accepted/uefa_nations_league_2026_27/results.csv
    - data/competition/accepted/uefa_nations_league_2026_27/status.csv

key-decisions:
  - "The accepted publisher validates the complete manifest and five compact tables before replacing only the edition directory."
  - "Derived status canonical content is hashed with its complete sorted source_artifact_id lineage, not the synthetic status artifact ID."
  - "data/competition/registries/refresh_batches remains outside the accepted replacement scope and is never created, renamed, or deleted by the publisher."
  - "The committed Nations League output remains a source-shaped seed; identity normalization and final canonical/hash-graph promotion stay with Plans 13-04, 13-11, and 13-12."

patterns-established:
  - "Candidate publication writes to a temporary edition sibling, validates read-back schemas, row hashes, foreign keys, canonical file hashes, and manifest provenance, then promotes by rename."
  - "Raw response bytes are verified from the candidate and, when already retained, from the ignored local raw bundle before accepted publication."

requirements-completed: [DATA-01, DATA-02, DATA-04]

coverage:
  - id: D1
    description: "Generic accepted-directory publication stages and validates one complete manifest plus fixtures, groups, standings, results, and status before promotion."
    requirement: DATA-01
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase13_source_contracts.R#accepted publication validates the complete staged directory and protects registry-side refresh records"
        status: pass
      - kind: integration
        ref: "Rscript --vanilla -e 'testthat::test_file(\"tests/testthat/test_phase13_source_contracts.R\")'"
        status: pass
    human_judgment: false
  - id: D2
    description: "The Nations League source-shaped handoff carries edition IDs, source artifact lineage, row hashes, canonical content hashes, and explicit status provenance without tracked raw bodies."
    requirement: DATA-02
    verification:
      - kind: integration
        ref: "Rscript --vanilla scripts/acquire_uefa_snapshot.R --fixture-dir tests/fixtures/phase13 --edition-id uefa_nations_league_2026_27 --output-root data/competition/accepted --registry-root data/competition/registries --dry-run"
        status: pass
      - kind: integration
        ref: "tests/testthat/test_phase13_source_contracts.R#capture-only registries retain exact raw bytes and canonical source hashes"
        status: pass
      - kind: other
        ref: "test -z \"$(git ls-files data/competition/local_raw)\""
        status: pass
    human_judgment: false
  - id: D3
    description: "Registry-side blocked refresh records, the blocked_refresh_batch_id pointer, and status history remain byte-stable while the accepted edition is replaced."
    requirement: DATA-04
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase13_source_contracts.R#accepted publication validates the complete staged directory and protects registry-side refresh records"
        status: pass
    human_judgment: false

# Metrics
duration: 26min
completed: 2026-08-14
status: complete
---

# Phase 13 Plan 09: Source-Shaped Nations League Handoff Summary

**Atomic, fail-closed publication of a compact Nations League five-class source handoff with derived-status lineage and refresh-batch isolation**

## Performance

- **Duration:** 26 min
- **Started:** 2026-08-14T11:44:00Z
- **Completed:** 2026-08-14T12:09:39Z
- **Tasks:** 2 completed
- **Files changed in commits:** 3 (the six-file handoff directory was replayed; five table bytes were already identical)

## Accomplishments

- Added a generic accepted-directory publisher that writes a staged manifest and all five compact source tables, validates their read-back schemas, row hashes, source links, canonical content hashes, and provenance, and promotes only after validation.
- Preserved the previous accepted edition on failed promotion and explicitly kept `data/competition/registries/refresh_batches` outside the replacement and rollback scope.
- Corrected derived-status canonical hashing to use the complete sorted lineage from the contributing fixtures/results artifacts and added regression coverage for explicit/derived provenance, dry-run non-publication, and sidecar byte stability.
- Replayed the deterministic Nations League fixture into the committed source-shaped handoff with canonical content hashes, source artifact links, and no tracked raw response bodies.

## Task Commits

Each task was committed atomically; Task 13-09-01 used the required TDD RED/GREEN sequence:

1. **Task 13-09-01 RED: accepted-directory publication regressions** - `5d2a740` (test)
2. **Task 13-09-01 GREEN: atomic accepted source handoff** - `54f7be3` (feat)
3. **Task 13-09-02: Nations League source handoff** - `4a7ec3f` (feat)

## Verification

- Focused source-contract suite: 141 passing assertions, 0 failures, 0 warnings, 0 skips.
- Deterministic `--publish-accepted` replay completed successfully using temporary raw and registry roots.
- Required dry-run replay completed successfully without accepted, registry, or raw publication.
- `git ls-files data/competition/local_raw` remains empty.
- No plan-owned files were deleted; unrelated pre-existing dirty/untracked user work remains untouched.

## Files Created/Modified

- `scripts/acquire_uefa_snapshot.R` - staged accepted-directory writer, source-shaped manifest builder, read-back validation, raw-store verification, and refresh-batch boundary.
- `tests/testthat/test_phase13_source_contracts.R` - TDD regressions for full staged publication, prior-output retention, sidecar protection, and dry-run behavior.
- `data/competition/accepted/uefa_nations_league_2026_27/source_bundle_manifest.csv` - refreshed source-shaped handoff manifest; the five resource CSVs were replay-validated and remained byte-identical.
- `data/competition/accepted/uefa_nations_league_2026_27/{fixtures,groups,standings,results,status}.csv` - validated source-shaped handoff tables retained for the later normalization plans.

## Decisions Made

- Accepted publication is edition-scoped and only replaces a fully validated temporary directory.
- The accepted publisher accepts an optional registry root solely to enforce that refresh batches remain separate; it performs no registry-side writes.
- The handoff is intentionally source-shaped and is not the final normalized canonical/hash graph.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Derived status canonical hash used the synthetic status artifact ID**
- **Found during:** Task 13-09-01 RED verification
- **Issue:** The derived status table hash was generated with the status artifact ID instead of the complete contributing-artifact lineage used in the accepted table.
- **Fix:** Hash the status resource with its sorted `source_artifact_id` lineage and preserve that same link in the table and manifest.
- **Files modified:** `scripts/acquire_uefa_snapshot.R`, `tests/testthat/test_phase13_source_contracts.R`
- **Verification:** Focused suite passes with 141 assertions.
- **Committed in:** `54f7be3`

**2. [Rule 1 - Bug] Empty fallback manifest fields failed CSV round-trip comparison**
- **Found during:** Task 13-09-01 GREEN verification
- **Issue:** Empty fallback fields were read back as `NA`, and strict vector comparison treated equivalent canonical empty values as different because of names attributes.
- **Fix:** Compare unnamed canonical scalar vectors so empty fields remain equivalent after CSV serialization.
- **Files modified:** `scripts/acquire_uefa_snapshot.R`
- **Verification:** Focused suite passes with 141 assertions and no warnings.
- **Committed in:** `54f7be3`

**Total deviations:** 2 auto-fixed bugs.
**Impact on plan:** Both fixes were directly required for fail-closed provenance and deterministic staged publication; no later-plan normalization or transaction work was added.

## Issues Encountered

Git metadata writes required an approved sandbox escalation because the repository metadata directory is protected in the default sandbox. Both task commits completed with normal repository hooks; no project blocker remains.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

The Nations League source-shaped handoff is ready for Plan 13-04 identity-bearing fixture/result projection. Plans 13-11 and 13-12 must still regenerate the complete normalized canonical/hash graph and perform the shared atomic promotion before the Plan 13-05 loader treats the handoff as final. Registry-side refresh-batch records remain intentionally outside this plan's publication scope.

---
*Phase: 13-source-contracts-and-competition-registry*
*Plan: 09*
*Completed: 2026-08-14*

## Self-Check: PASSED

- All eight plan-owned implementation/test/handoff paths exist.
- TDD RED/GREEN and Task 2 commits `5d2a740`, `54f7be3`, and `4a7ec3f` are present in Git history.
- Final focused verification, dry-run verification, and untracked-raw guard passed.
