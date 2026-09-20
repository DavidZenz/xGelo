---
phase: 18-club-and-ucl-source-contracts
plan: "11"
subsystem: data-integrity
tags: [r, canonical-v2, immutable-generations, atomic-pointer, provider-exit]
requires:
  - phase: 18-10
    provides: exact immutable UCL candidate snapshots and authority validation
  - phase: 18-14
    provides: canonical-first production and test loaders
provides:
  - Immutable accepted and transaction generations selected by one atomic hash-bound pointer
  - Lock-silent refresh with strict pointer, ledger, sidecar, incumbent, and inventory prevalidation
  - Exact provider/edition/decision/bundle/inventory-bound retain and withdraw transactions
  - Canonical-v2 no-incumbent missing-credential production state and stable CLI exits
affects: [18-13, phase-21-publication, phase-22-refresh]
tech-stack:
  added: []
  patterns: [immutable generations, atomic selector pointer, validate-before-derive, exact compliance authority]
key-files:
  created:
    - data/competition/registries/ucl_source_current.json
    - data/competition/ucl_source_generations/transactions/ucl-refresh-20260920-disabled-missing-credential-v2/state.json
  modified:
    - R/competition/ucl_source_refresh.R
    - scripts/refresh_ucl_source.R
    - tests/testthat/test_phase18_refresh_failure.R
    - data/competition/registries/ucl_source_refreshes.csv
    - data/competition/registries/ucl_source_blocked_refresh.json
key-decisions:
  - "Refresh visibility changes only through one canonical-v2 ucl_source_current.json pointer; accepted and evidence generations are immutable."
  - "A lock loser returns concurrent_refresh in memory and creates no history, sidecar, generation, or pointer bytes."
  - "Provider exit requires an exact provider-authorized incumbent plus reviewed provider, edition, decision, bundle, and full inventory identity."
patterns-established:
  - "Generation publication: validate staged accepted and transaction trees fully, finalize them immutably, then replace one pointer."
  - "Reader snapshot: capture and validate one pointer and resolve only its hash-bound immutable references."
requirements-completed: [UCLSRC-04]
coverage:
  - id: D1
    description: "Atomic accepted/evidence generation publication under crashes and concurrent readers"
    requirement: UCLSRC-04
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase18_refresh_failure.R#successful refresh and concurrent reader cases"
        status: pass
    human_judgment: false
  - id: D2
    description: "Lock-owned evidence and strict prior-state tamper prevalidation"
    requirement: UCLSRC-04
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase18_refresh_failure.R#lock loser and ledger/sidecar/incumbent tamper cases"
        status: pass
    human_judgment: false
  - id: D3
    description: "Exact-incumbent provider retain/withdraw and stable CLI exits"
    requirement: UCLSRC-04
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase18_refresh_failure.R#provider exit and CLI cases"
        status: pass
    human_judgment: false
duration: 62min
completed: 2026-09-20
status: complete
---

# Phase 18 Plan 11: Immutable UCL Refresh Transaction Summary

**UCL accepted bundles and refresh evidence now advance together through one canonical-v2 pointer, with immutable generations, lock-silent contention, exact provider-exit authority, and an explicit no-incumbent production state.**

## Performance

- **Duration:** 62 min
- **Started:** 2026-09-20T13:29:00Z
- **Completed:** 2026-09-20T14:31:36Z
- **Tasks:** 3
- **Files modified:** 9

## Accomplishments

- Replaced unlink/backup and file-by-file accepted-tree promotion with immutable accepted and transaction generations selected by one atomic pointer replacement.
- Added strict reader and writer prevalidation for pointer self-hash, generation inventories, transaction state, every ledger row, sidecar linkage, accepted bundle bytes, and explicit no-incumbent state.
- Made lock collisions completely non-durable and proved forked readers observe only complete old or complete new bundle/evidence tuples.
- Bound retain/withdraw compliance to the exact provider-authorized incumbent and complete reviewed inventory; manual, stale, mismatched, unreadable, and no-incumbent states fail closed.
- Migrated committed missing-credential production evidence to canonical-v2 while keeping automation disabled and accepted state absent.

## Task Commits

1. **Task 18-11-01 RED: Expose generation atomicity gaps** - `d11b1fe` (test)
2. **Tasks 18-11-01 through 18-11-03 GREEN: Immutable generation refresh, provider exit, CLI, and production migration** - `80468fe` (feat)
3. **Task 18-11-02 regression expansion: Prior-state tamper prevalidation** - `8dd7c98` (test)

The generation transaction is one inseparable safety boundary, so the GREEN implementation commit contains the shared primitives consumed by all three tasks; the RED and adversarial expansion remain separate commits.

## Files Created/Modified

- `R/competition/ucl_source_refresh.R` - Immutable accepted/transaction generations, atomic pointer reader/writer, strict state validation, lock discipline, and exact provider exit.
- `scripts/refresh_ucl_source.R` - Fixed provider/edition CLI, tagged result exits, and safe sourced-script root resolution.
- `tests/testthat/test_phase18_refresh_failure.R` - Generation, kill-boundary, concurrent-reader, lock, tamper, no-incumbent, provider-exit, and CLI contracts.
- `data/competition/registries/ucl_source_current.json` - Canonical-v2 current selector for the disabled/no-incumbent production state.
- `data/competition/ucl_source_generations/transactions/ucl-refresh-20260920-disabled-missing-credential-v2/` - Immutable production transaction generation.
- `data/competition/registries/ucl_source_refreshes.csv` - Canonical-v2 mirror of the current ledger.
- `data/competition/registries/ucl_source_blocked_refresh.json` - Canonical-v2 mirror of the current blocked sidecar.

## Decisions Made

- Finalized generations may remain unreachable after a killed writer; readers ignore them because only the validated current pointer confers authority.
- Pre-commit termination and evidence-writer failure preserve the exact incumbent pointer rather than trying to mutate shared failure metadata from a compromised transaction.
- Technical no-incumbent failure is represented by a valid transaction generation whose accepted reference is explicitly empty; no synthetic accepted bytes are created.
- Retain reuses the exact immutable provider generation. Withdraw creates a new tombstone generation and commits it through the same pointer transaction.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Migrated pre-18-10 refresh fixtures to canonical-v2 inputs**
- **Found during:** Task 18-11-01 RED
- **Issue:** The inherited refresh suite called raw-only `phase18_ucl_hash()` with character values and built v1 bundle schemas.
- **Fix:** Rebuilt refresh fixtures with v2 edition, projected table, fingerprint, authority, and raw aggregate contracts.
- **Files modified:** `tests/testthat/test_phase18_refresh_failure.R`
- **Verification:** Focused refresh file passes with zero failures, errors, warnings, or skips.
- **Committed in:** `d11b1fe`, `80468fe`

**2. [Rule 1 - Bug] Removed full-suite history test leakage from this worktree**
- **Found during:** Plan-level regression
- **Issue:** The Phase 18 history suite changed tracked `data/club/history_current.json` and created two untracked history generations.
- **Fix:** Verified the exact leaked paths, restored only the tracked pointer from HEAD, and removed only the two generated directories. No unrelated files were touched.
- **Files modified:** None in the final plan diff.
- **Verification:** `git status --short` contains only the user's pre-existing martj42/debug/benchmark/release artifacts after plan commits.
- **Committed in:** Not applicable (cleanup restored the pre-run state).

---

**Total deviations:** 2 auto-fixed (1 blocking fixture migration, 1 test-isolation cleanup).
**Impact on plan:** Both were required to execute the canonical-v2 contract safely; no production scope was added.

## Legacy Failure Coverage Mapping

- Ordered file-promotion failure loops are superseded by staged immutable-directory validation plus one pointer commit; `before_promotion`, `interrupt`, and `before_readback` probes assert pointer byte preservation.
- Backup/restore assertions are superseded by immutable incumbent generations that writers never unlink or rename.
- History/sidecar writer failure is covered by transaction-stage failure with exact pointer preservation and a validating incumbent.
- Concurrent lock evidence mutation is covered by a whole-root byte snapshot proving the lock loser creates no durable path.
- Retain/withdraw tree rollback is superseded by new immutable generations; stale review and pre-commit failures leave the old pointer byte-identical.

## Issues Encountered

- The Phase 18 source-acceptance regression still has two known setup errors because `phase18_test_adapter_registries()` constructs the pre-18-09 club registry schema. This was already assigned to Plan 18-13; all acceptance assertions that reach refresh/CLI behavior pass after restoring canonical-first loader compatibility and the established missing-argument exit.
- The exact production refresh state remains intentionally blocked because no real credential or accepted provider authority was supplied.

## Authentication Gates

None. No credential or network access was used.

## Known Stubs

None. Empty accepted-generation fields in the production pointer are the explicit validated no-incumbent state, not placeholders.

## Verification

- Focused refresh failure suite: 13 named tests, zero failures/errors/warnings/skips; includes forked concurrent readers and exact provider retain/withdraw.
- Source bundle suite: 11 named tests, zero failures/errors/warnings/skips.
- Production pointer/generation fresh-process validation: PASS (`no_incumbent`, `missing_credential`).
- Full Phase 18 sampling: canonical hash, club history, club identity, football-data adapter, refresh, and source bundle files pass; source acceptance has only the two pre-existing Plan 18-13 fixture setup errors described above.
- `git diff --check`: PASS.

## Threat Flags

None. The pointer, filesystem, concurrency, ledger, and provider-exit trust boundaries are exactly T18-G11-01 through T18-G11-04 from the plan.

## User Setup Required

None. Real automated refresh remains unavailable until a genuine provider key and accepted owner review exist.

## Next Phase Readiness

- Plan 18-13 can exercise CR-08 through CR-11 against production interfaces and close the known source-acceptance fixture schema residual.
- Phase 21/22 can consume one complete pointer snapshot without observing mixed accepted/evidence state.

## Self-Check: PASSED

- All nine declared production/test/data paths exist.
- Commits `d11b1fe`, `80468fe`, and `8dd7c98` exist in Git history.
- Focused refresh, source bundle, production fresh-process, and formatting gates pass.
- No plan-unowned or generated history artifacts remain from verification.

---
*Phase: 18-club-and-ucl-source-contracts*
*Completed: 2026-09-20*
