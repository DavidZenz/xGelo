---
phase: 18-club-and-ucl-source-contracts
plan: "14"
subsystem: data-integrity
tags: [r, canonical-hash, bootstrap-order, subprocess, tdd]

requires:
  - phase: 18-club-and-ucl-source-contracts
    provides: phase18-canonical-v2 primitive from Plan 18-07
provides:
  - canonical-first bootstrap order in all four Phase 18 production CLIs
  - canonical-first direct, dynamic, sys.source, and fresh-R test loaders
  - executable loader inventory and credential-free zero-mutation CLI smoke contract
affects: [18-08-acceptance-migration, 18-09-identity-migration, 18-10-bundle-migration, 18-11-refresh-migration, 18-12-history-migration]

tech-stack:
  added: []
  patterns: [trusted-root dependency bootstrap, executable loader inventory, child-process dependency parity]

key-files:
  created: []
  modified:
    - scripts/accept_ucl_provider.R
    - scripts/bootstrap_club_identity.R
    - scripts/refresh_ucl_source.R
    - scripts/build_club_history_corpus.R
    - tests/testthat/test_phase18_source_acceptance.R
    - tests/testthat/test_phase18_football_data_adapter.R
    - tests/testthat/test_phase18_source_bundle.R
    - tests/testthat/test_phase18_refresh_failure.R
    - tests/testthat/test_phase18_club_identity.R
    - tests/testthat/test_phase18_club_history_contract.R

key-decisions:
  - "Every production CLI loads the common hash module immediately after resolving its trusted project root and before any Phase 18 consumer."
  - "Dynamic test source loops are unconditional so a missing mandatory dependency fails closed rather than being silently skipped."
  - "This plan changes loader order only; no consumer hash, schema, durable evidence, or authority state is migrated."

patterns-established:
  - "Canonical-first imports: R/common/phase18_canonical_hash.R is the first Phase 18 module in each loader boundary."
  - "Fresh-process parity: generated and literal Rscript expressions declare the same mandatory dependency order as their parent process."

requirements-completed: [UCLSRC-01, UCLSRC-02, UCLSRC-03, UCLSRC-04, CLUBID-01, CLUBHIST-01]

coverage:
  - id: D1
    description: "All four Phase 18 production CLIs load the canonical v2 module before acceptance, identity, bundle, refresh, adapter, or history consumers."
    requirement: UCLSRC-01
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase18_source_acceptance.R#all Phase 18 production CLIs bootstrap the canonical hash module first"
        status: pass
      - kind: integration
        ref: "tests/testthat/test_phase18_source_acceptance.R#credential-free CLI smoke paths preserve durable Phase 18 evidence"
        status: pass
    human_judgment: false
  - id: D2
    description: "Six direct test loaders, both dynamic loops, and both fresh-R source expressions are canonical-first and inventory-checked."
    requirement: CLUBID-01
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase18_source_acceptance.R#Phase 18 loader inventory is canonical-first in every parent and child process"
        status: pass
    human_judgment: false
  - id: D3
    description: "The complete pre-migration Phase 18 sampling gate remains green without changing persisted authority or evidence bytes."
    requirement: UCLSRC-04
    verification:
      - kind: integration
        ref: "Rscript --vanilla full test_phase18_*.R sampling gate plus git diff --check"
        status: pass
    human_judgment: false

duration: 7min
completed: 2026-09-20
status: complete
---

# Phase 18 Plan 14: Canonical-First Loader Bootstrap Summary

**All Phase 18 production and test entrypoints now resolve the canonical v2 hash dependency before authority consumers, including fresh R subprocesses, without migrating or mutating durable evidence.**

## Performance

- **Duration:** 7 min
- **Started:** 2026-09-20T11:36:34Z
- **Completed:** 2026-09-20T11:43:49Z
- **Tasks:** 2
- **Files modified:** 10

## Accomplishments

- Installed the common canonical hash module as the first Phase 18 source in all four production CLIs after trusted-root resolution.
- Covered all six direct test bootstraps, two dynamic source loops, the acceptance literal Rscript command, and the bundle-generated fresh-process expression.
- Added an executable inventory that rejects missing, duplicated, late, or conditionally skipped common-module loads and smoke-tested all CLIs without changing durable evidence.

## Task Commits

Each TDD task was committed atomically:

1. **Task 18-14-01: Bootstrap every Phase 18 production CLI through the canonical module**
   - `091c357` — failing CLI order and zero-mutation smoke contract
   - `fc5abd6` — canonical-first bootstrap in all four production CLIs
2. **Task 18-14-02: Cover all direct, dynamic, and subprocess test loaders before migration**
   - `70133ac` — failing complete loader-inventory contract
   - `2c54a2b` — canonical-first direct, dynamic, sys.source, and child-process loaders

## Files Created/Modified

- `scripts/accept_ucl_provider.R` — loads canonical v2 before acceptance, identity, adapter, and bundle consumers.
- `scripts/bootstrap_club_identity.R` — loads canonical v2 before identity consumers.
- `scripts/refresh_ucl_source.R` — loads canonical v2 before acceptance, bundle, and refresh consumers.
- `scripts/build_club_history_corpus.R` — loads canonical v2 before source-contract, identity, and history consumers.
- `tests/testthat/test_phase18_source_acceptance.R` — canonical-first direct and literal subprocess loads plus complete inventory and CLI smoke assertions.
- `tests/testthat/test_phase18_football_data_adapter.R` — canonical-first adapter test bootstrap.
- `tests/testthat/test_phase18_source_bundle.R` — canonical-first direct, sys.source, and generated subprocess bootstrap.
- `tests/testthat/test_phase18_refresh_failure.R` — canonical-first unconditional dynamic source loop.
- `tests/testthat/test_phase18_club_identity.R` — canonical-first identity test bootstrap.
- `tests/testthat/test_phase18_club_history_contract.R` — canonical-first unconditional history source loop.

## Decisions Made

- Kept the common source adjacent to trusted-root resolution so no consumer can run in a partially initialized environment.
- Made dynamic test loops unconditional because silently ignoring a missing common dependency would violate the fail-closed import contract.
- Left every legacy consumer hash and persisted artifact byte untouched; Plans 18-08 onward own those domain migrations.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- Repository Git metadata required the approved sandbox escalation path for the four atomic TDD commits.

## User Setup Required

None - no external service configuration required.

## Known Stubs

None.

## Next Phase Readiness

- Acceptance, identity, bundle, refresh, adapter, and history migrations can now call canonical v2 helpers from every supported parent and child process.
- The pre-migration suite remains green, so downstream plans can attribute any later artifact change to the owning domain migration rather than import-order drift.
- No credential, schema, durable authority, or stored hash changed in this plan.

## Verification

- Task 1 focused gate: source acceptance (111 assertions), refresh failure (110 assertions), and club history (49 assertions) passed together.
- Task 2 complete sampling gate: every `test_phase18_*.R` file passed in a fresh R process.
- Loader inventory: four CLIs, six direct test bootstraps, two dynamic loops, and two fresh-process commands passed canonical-first order checks.
- Scope and formatting: `git diff --check` passed; `f353aad..2c54a2b` modifies exactly the ten declared loader files with no deletions.
- Durable state: credential-free CLI smoke paths produced byte-identical before/after snapshots for committed provider, identity, refresh, and history evidence roots.

## Self-Check: PASSED

- All ten declared modified files exist.
- All four TDD task commits exist in Git history in RED → GREEN order.
- Every task acceptance criterion and the plan-level verification command passed.

---
*Phase: 18-club-and-ucl-source-contracts*
*Completed: 2026-09-20*
