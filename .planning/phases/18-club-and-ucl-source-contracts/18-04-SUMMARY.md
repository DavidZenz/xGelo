---
phase: 18-club-and-ucl-source-contracts
plan: "04"
subsystem: source-refresh
tags: [ucl, atomic-promotion, rollback, provenance, provider-exit, testthat]
dependency-graph:
  requires:
    - phase: 18-06
      provides: canonical UCL source bundles and closed source-authority union
    - phase: 18-01
      provides: hash-bound provider acceptance decisions and edition expectations
  provides:
    - locked all-or-nothing UCL candidate promotion with exact-byte rollback
    - append-only typed refresh history and hash-linked blocked sidecar
    - reviewed provider-exit retain and withdraw compliance transactions
  affects: [phase-21-publication, phase-22-operations, ucl-current-state]
tech-stack:
  added: []
  patterns:
    - trusted sibling-root transaction with exact candidate inventory
    - technical rollback separated from reviewed compliance exit
    - cyclic evidence links hashed from stable base payloads
key-files:
  created:
    - R/competition/ucl_source_refresh.R
    - scripts/refresh_ucl_source.R
    - tests/testthat/test_phase18_refresh_failure.R
    - data/competition/registries/ucl_source_refreshes.csv
    - data/competition/registries/ucl_source_blocked_refresh.json
  modified: []
key-decisions:
  - "Technical refresh failures always restore the incumbent bytes; provider exit is a separate reviewed retain/withdraw compliance transaction."
  - "A failed evidence writer is rolled back and then recorded as its own typed metadata-publication failure through the normal writer path."
  - "Production remains missing-credential, automation-disabled, and no-incumbent until real provider and owner authority exists."
patterns-established:
  - "Refresh evidence: one unique batch row plus one hash-linked current blocked sidecar for every blocked attempt."
  - "Provider withdrawal: retain only hash-reviewed lawful paths, replace provider state with a self-hashed unavailable tombstone, and rollback on any error."
requirements-completed: [UCLSRC-04]
coverage:
  - id: D1
    description: "Locked candidate promotion preserves the incumbent path-to-bytes map across every ordered promotion index and technical failure class."
    requirement: UCLSRC-04
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase18_refresh_failure.R#locked refresh and ordered promotion matrix"
        status: pass
    human_judgment: false
  - id: D2
    description: "Reviewed provider exit deterministically retains permitted bytes or atomically withdraws provider state while preserving lawful manual/open bytes."
    requirement: UCLSRC-04
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase18_refresh_failure.R#provider retain/withdraw matrix"
        status: pass
    human_judgment: false
  - id: D3
    description: "The committed production state truthfully records missing credentials, disabled automation, and no incumbent rather than fabricated acceptance."
    requirement: UCLSRC-04
    verification:
      - kind: unit
        ref: "phase18_validate_ucl_refresh_state on committed registry evidence"
        status: pass
    human_judgment: false
duration: 18min
completed: 2026-09-20
status: complete
---

# Phase 18 Plan 04: Last-Known-Good UCL Refresh Summary

**Locked UCL candidate promotion now restores accepted bytes after every technical failure, while reviewed provider exit uses distinct retain or atomic-withdraw transactions.**

## Performance

- **Duration:** 18 min
- **Started:** 2026-09-20T10:00:01Z
- **Completed:** 2026-09-20T10:18:00Z
- **Tasks:** 3
- **Files modified:** 5

## Accomplishments

- Promotes only complete, read-back-validating provider or manual candidates under one exclusive lock and rejects fixture, stale, mixed, missing, or forged authority.
- Proves exact incumbent preservation at every ordered file promotion index, on read-back, interruption, concurrency, history, sidecar, and first-refresh failures.
- Records stable machine reasons in append-only history and a hash-linked blocked sidecar without serializing raw errors or secrets.
- Executes reviewed provider exit separately: retain requires explicit retention/display permission; withdraw removes provider-derived files, preserves hash-reviewed lawful inventory, and installs a self-hashed unavailable tombstone.
- Leaves production truthfully blocked as `missing_credential` with `automation_disabled` and `no_incumbent`; no accepted provider bundle or reviewed exit disposition was fabricated.

## Task Commits

1. **Task 18-04-01 RED: locked refresh failure matrix** - `5f09bcb` (test)
2. **Task 18-04-01 GREEN: locked UCL source promotion** - `17de821` (feat)
3. **Task 18-04-02 RED: provider-exit and evidence matrix** - `0d86d5b` (test)
4. **Task 18-04-02 GREEN: reviewed provider-exit transactions** - `bc236f7` (feat)
5. **Task 18-04-02 correctness hardening: durable metadata-writer failure evidence** - `ed756e5` (fix)

## Files Created/Modified

- `R/competition/ucl_source_refresh.R` - reason classifier, lock, promotion, rollback, evidence validation, and provider-exit transactions.
- `scripts/refresh_ucl_source.R` - fixed-root operator entrypoint with explicit refresh/provider-exit modes and dry-run validation.
- `tests/testthat/test_phase18_refresh_failure.R` - 110-assertion technical and compliance failure-injection matrix.
- `data/competition/registries/ucl_source_refreshes.csv` - append-only production refresh evidence seeded with the truthful disabled attempt.
- `data/competition/registries/ucl_source_blocked_refresh.json` - current hash-linked production blocked status.

## Decisions Made

- Technical last-known-good policy is never treated as compliance permission. Provider exit requires a current, hash-bound review with exactly one `retain` or `withdraw` disposition.
- Cross-linked row/sidecar hashes exclude only their cyclic link fields, while validation compares every shared semantic field and the retained incumbent identity.
- A metadata-writer failure is first rolled back, then the writer failure itself is durably recorded through the default atomic writer so one attempt still yields one event.
- The operator CLI exposes no force/bypass option and accepts only fixed project trust roots.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Made blocked metadata publication failures durably self-reporting**
- **Found during:** Task 18-04-02 acceptance audit
- **Issue:** A sidecar writer failure preserved accepted bytes but could leave the attempt without the required durable typed event.
- **Fix:** Roll back partial history/sidecar metadata, classify the writer failure, and publish one replacement blocked event and linked sidecar through the normal atomic writer.
- **Files modified:** `R/competition/ucl_source_refresh.R`, `tests/testthat/test_phase18_refresh_failure.R`
- **Verification:** Focused suite passes 110 assertions, including history and sidecar writer failure injection.
- **Committed in:** `ed756e5`

---

**Total deviations:** 1 auto-fixed (1 missing critical functionality).
**Impact on plan:** The fix closes a stated UCLSRC-04 durability invariant without expanding scope.

## Issues Encountered

- CSV readers inferred all-empty identifier columns as missing logical values. The history reader now normalizes non-boolean fields back to canonical strings before hash and incumbent-link validation.
- The evidence-review checkpoint was auto-approved under the project’s configured `workflow.auto_advance: true` after the focused and full Phase 18 suites passed. This approval does not imply provider terms acceptance, retention permission, or live provider authority.

## Authentication Gates

None. No provider credential was available or required for the offline failure proof; production remains explicitly disabled.

## Known Stubs

None. The missing-credential production record is an intentional fail-closed state, not placeholder data.

## User Setup Required

No setup is required to use the offline refresh contract. A real live provider refresh still requires the separately documented Phase 18 provider credential and owner-review gate.

## Verification

- Focused refresh-failure suite: 110 assertions passed.
- Full Phase 18 suite: 403 assertions passed across six Phase 18 test files.
- Fresh-process source/CLI load and R parse checks passed.
- Committed disabled history/sidecar pair passed hash, linkage, and no-incumbent validation.
- `git diff --check` passed.

## Next Phase Readiness

- Phase 18 source contracts now expose a complete fail-closed promotion boundary for Phase 21 publication and Phase 22 scheduled operations.
- Automated provider acquisition remains blocked until a real credential, current owner review, and accepted live probe exist.
- No `data/competition/accepted/ucl_2026_27/` directory was created because no real accepted production authority exists.

## Self-Check: PASSED

- All five declared key files exist.
- All five Task 18-04 commits exist in Git history.
- UCLSRC-04 focused and full-phase verification commands exit zero.
- Unrelated martj42 CSV and untracked debug/benchmark/release artifacts remain untouched.

---
*Phase: 18-club-and-ucl-source-contracts*
*Completed: 2026-09-20*
