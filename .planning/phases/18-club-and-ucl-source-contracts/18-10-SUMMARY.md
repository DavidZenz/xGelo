---
phase: 18-club-and-ucl-source-contracts
plan: "10"
subsystem: data-contracts
tags: [r, canonical-v2, provenance, symlink-safety, immutable-snapshot]
requires:
  - phase: 18-07
    provides: canonical-v2 length-prefixed hashing primitives
  - phase: 18-08
    provides: immutable provider acceptance generations and exact evidence validation
  - phase: 18-09
    provides: deterministic provider projection and source freshness contracts
  - phase: 18-14
    provides: canonical-first Phase 18 loader bootstrapping
provides:
  - Edition/raw/fingerprint-bound provider, manual, and fixture bundle authority
  - Canonical-v2 artifact, table, authority, graph, collision, and self hashes
  - Lexical-first symlink rejection and exact recursive authority inventories
  - Single-read immutable candidate snapshots with metadata and inventory drift checks
affects: [18-11, 18-12, 18-13, phase-19-club-models]
tech-stack:
  added: []
  patterns: [canonical domain-separated graph hashes, closed authority union, lexical-before-resolution paths, snapshot-only parsing]
key-files:
  created: []
  modified:
    - R/competition/ucl_source_bundle.R
    - scripts/accept_ucl_provider.R
    - tests/testthat/test_phase18_source_bundle.R
    - data/competition/manual_source_reviews/ucl_2026_27.csv
key-decisions:
  - "Every authority decision is scoped to one exact edition and the canonical aggregate of the ordered four raw resources."
  - "Candidate paths are checked lexically for symlinks before resolution; validation parses only one in-memory snapshot per file."
  - "Provider, manual, and fixture candidates each have one exact recursive authority-specific inventory; fixture authority stays permanently non-promotable."
patterns-established:
  - "Bind raw hashes, authority evidence, canonical tables, and bundle identity through one canonical-v2 graph."
  - "Enumerate hidden paths and directories, reject lexical symlinks, then snapshot and parse without reopening candidate files."
requirements-completed: [UCLSRC-03]
coverage:
  - id: D1
    description: "Exact edition/raw/fingerprint authority and canonical-v2 bundle graph"
    requirement: UCLSRC-03
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase18_source_bundle.R (authority, tamper, replay, and collision cases)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Lexical symlink-safe exact inventory and immutable snapshot reader"
    requirement: UCLSRC-03
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase18_source_bundle.R (symlink, hidden inventory, and snapshot drift cases)"
        status: pass
    human_judgment: false
duration: 28min
completed: 2026-09-20
status: complete
---

# Phase 18 Plan 10: Exact UCL Bundle Authority and Filesystem Boundary Summary

**UCL candidates now bind exact edition, raw bytes, schema fingerprint, reviewed authority, canonical tables, and lexical filesystem inventory into one fail-closed canonical-v2 graph.**

## Performance

- **Duration:** 28 min
- **Started:** 2026-09-20T12:50:46Z
- **Completed:** 2026-09-20T13:18:06Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Bound provider, manual, and fixture authority to the exact candidate edition and ordered four-resource raw aggregate, while fully revalidating provider generation, capability matrix, expectations, pointer, and schema fingerprint.
- Migrated artifact, table-manifest, authority, bundle-graph, collision, self, and row-set integrity to domain-separated canonical-v2 encoding and retained fixture non-promotability.
- Replaced resolved-first path handling with lexical symlink checks covering file, directory, broken, trusted-root, and in-root symlinks.
- Added exact recursive hidden-entry inventories per authority type and snapshot-only parsing with post-read link, metadata, and inventory drift checks.
- Pinned deterministic empty/null, adjacent/equal-key, reorder, replay, and same-identity/different-content collision outcomes.

## Task Commits

1. **Task 18-10-01 RED: Candidate authority binding gaps** - `dfb5897` (test)
2. **Task 18-10-01 GREEN: Exact authority and canonical graph** - `28f79f1` (feat)
3. **Task 18-10-02 RED: Filesystem trust-boundary gaps** - `6972fe5` (test)
4. **Task 18-10-02 GREEN: Exact immutable candidate snapshots** - `fcbbdf3` (feat)

## Files Created/Modified

- `R/competition/ucl_source_bundle.R` - Exact authority union, canonical-v2 graph, lexical symlink guard, authority inventories, and immutable snapshot reader.
- `scripts/accept_ucl_provider.R` - Canonical-first loader and edition/raw-bound provider, manual, and fixture candidate call sites.
- `tests/testthat/test_phase18_source_bundle.R` - Authority tamper, fingerprint, symlink, inventory, snapshot drift, ordering, replay, collision, and empty/null regressions.
- `data/competition/manual_source_reviews/ucl_2026_27.csv` - Canonical-v2, hash-valid, fail-closed `not_reviewed` manual authority record.

## Decisions Made

- Raw-byte SHA-256 remains exact provenance; all structured/composite integrity uses the shared canonical-v2 length-prefixed encoder.
- Authority is a closed one-member union. A valid review for different bytes or edition cannot authorize a candidate, and stored eligibility booleans cannot elevate fixture authority.
- The original candidate-root string is checked before normalization. After exact inventory validation, each file is read once to raw memory and all parsing operates from those immutable bytes.
- Production manual authority remains truthfully `not_reviewed`; no source, license, reviewer, or approval was fabricated.

## Deviations from Plan

None - plan execution stayed within the specified source-bundle files and trust-boundary contract.

## Issues Encountered

- The source-acceptance regression suite reached 234 passing assertions but two unrelated setup cases fail before bundle code runs because `phase18_test_adapter_registries()` still constructs the pre-18-09 club-registry schema (`invalid_club_registry_schema: Club registry has wrong columns: clubs`). Plan 18-10 does not own that test fixture; this is an explicit residual compatibility gap for Plan 18-13. The bundle suite and football-data adapter suite pass completely.

## Authentication Gates

None.

## User Setup Required

None - no credentials or network access were used. Production remains fail-closed without exact reviewed authority.

## Verification

- `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_source_bundle.R")'` — PASS (69 assertions, including a fresh spawned R process).
- `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_football_data_adapter.R")'` — PASS (139 assertions).
- `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_source_acceptance.R")'` — PARTIAL (234 assertions pass; 2 pre-existing club-registry fixture setup errors outside Plan 18-10 files).
- Private delimiter-hash and legacy bundle-schema scans — PASS (no matches).
- `git diff --check` — PASS.

## Known Stubs

None. Empty fields are constructor inputs populated before hashing, closed-union inactive fields, or explicit fail-closed result values; none flow to a dashboard as placeholder data.

## Threat Flags

None. The filesystem access and authority trust boundaries changed here are the plan's registered T18-G10-01 through T18-G10-04 surfaces; no additional endpoint, credential, or schema boundary was introduced.

## Next Phase Readiness

- Plans 18-11 through 18-13 can consume a bundle whose authority, bytes, tables, inventory, and identity are inseparable.
- Plan 18-13 should migrate the acceptance-suite club-registry fixture to the Plan 18-09 schema; this residual setup gap does not affect the Plan 18-10 focused contract.

## Self-Check: PASSED

- All four declared key files exist.
- Commits `dfb5897`, `28f79f1`, `6972fe5`, and `fcbbdf3` exist in Git history.
- Bundle and adapter focused verification pass, and no Plan 18-10 commit deletes tracked files.

---
*Phase: 18-club-and-ucl-source-contracts*
*Completed: 2026-09-20*
