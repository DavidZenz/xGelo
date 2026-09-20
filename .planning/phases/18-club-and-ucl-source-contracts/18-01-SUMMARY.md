---
phase: 18-club-and-ucl-source-contracts
plan: "01"
subsystem: data-contracts
tags: [R, football-data.org, UCL, provider-acceptance, SHA-256, atomic-transaction, testthat]

requires:
  - phase: 13-source-contracts-and-competition-registry
    provides: canonical SHA-256, source provenance, safe-path, and atomic publication patterns
provides:
  - fail-closed football-data.org provider preflight and owner-review contracts
  - hash-bound UCL 2026/27 lifecycle and capability evidence
  - bounded four-resource live-acceptance probe with rollback, replay, and collision guarantees
  - durable disabled-by-default production provider decision
affects: [18-02-current-source-adapter, 18-03-provider-transport, 18-04-accepted-source-bundle, UCLSRC-02]

tech-stack:
  added: []
  patterns:
    - "Represent credential presence without allowing credential bytes into functions or durable evidence."
    - "Enable automation only from a recomputed owner-review plus live-machine plus expectation-hash conjunction."
    - "Promote the six-file provider decision under an exclusive lock with exact-byte rollback."

key-files:
  created:
    - R/competition/ucl_source_acceptance.R
    - scripts/accept_ucl_provider.R
    - tests/testthat/test_phase18_source_acceptance.R
    - tests/fixtures/phase18/provider_terms_review.csv
    - data/competition/provider_acceptance/football_data_org_v4/ucl_2026_27/acceptance_manifest.csv
  modified: []

key-decisions:
  - "Treat the provider token as process-local transport state; only credential presence may enter the acceptance state machine."
  - "Freeze the league-phase acceptance expectation at exactly 36 clubs, 144 matches, and 36 standings rows."
  - "Keep production automation disabled until all seven owner-review dimensions and the bounded four-resource live probe pass together."
  - "Make exact decision replay idempotent and reject same-ID evidence drift as a collision."

patterns-established:
  - "Provider decision artifacts recompute row, review, machine, expectation, schema, parser, and manifest hashes instead of trusting stored booleans."
  - "Concurrent and interrupted acceptance attempts return typed reason codes while preserving the incumbent path-to-bytes map."

requirements-completed: [UCLSRC-01]

coverage:
  - id: D1
    description: "The no-key operator path emits a validating, non-secret, disabled decision without making a transport call."
    requirement: UCLSRC-01
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase18_source_acceptance.R#no-key operator path"
        status: pass
      - kind: other
        ref: "Rscript --vanilla -e 'testthat::test_file(\"tests/testthat/test_phase18_source_acceptance.R\")'"
        status: pass
    human_judgment: false
  - id: D2
    description: "The production decision binds every owner and API capability row to reviewed UCL cardinality expectations and validates in a fresh process."
    requirement: UCLSRC-01
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase18_source_acceptance.R#production evidence and fresh-process validation"
        status: pass
    human_judgment: false
  - id: D3
    description: "The sole first-live-acceptance path is bounded, concurrency-safe, rollback-safe, collision-intolerant, and idempotent."
    requirement: UCLSRC-01
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase18_source_acceptance.R#live acceptance probe transaction cases"
        status: pass
    human_judgment: true
    rationale: "Synthetic transport proves the transaction contract, but actual API rights, attribution, retention, schema, completeness, and freshness require an account owner and a real provider key."

duration: 14 min
completed: 2026-09-20
status: complete
---

# Phase 18 Plan 01: Club and UCL Source Contracts Summary

**A fail-closed football-data.org acceptance state machine now binds owner judgment, exact UCL lifecycle expectations, and bounded live evidence before automation can be enabled.**

## Performance

- **Duration:** 14 min
- **Started:** 2026-09-20T08:36:54Z
- **Completed:** 2026-09-20T08:51:02Z
- **Tasks:** 3
- **Files modified:** 10 implementation and evidence files

## Accomplishments

- Added schema-versioned preflight, owner-review, edition-expectation, machine-evidence, and acceptance-manifest contracts with canonical SHA-256 validation.
- Added a script-relative operator command whose missing-credential path never invokes transport and durably records `not_run_missing_credential` with automation disabled.
- Added a complete 16-capability production matrix and exact 36-club, 144-match, 36-standing-row league-phase expectations.
- Added a four-endpoint, no-cache live-probe transaction with exclusive locking, staged validation, exact-byte rollback, typed contention/interruption failures, idempotent replay, and decision-collision rejection.

## Task Commits

Each TDD task was committed as RED then GREEN:

1. **Task 18-01-01: Missing-credential operator tracer**
   - RED `098e33c` (test)
   - GREEN `c035d15` (feat)
2. **Task 18-01-02: Production review and lifecycle matrices**
   - RED `92ab877` (test)
   - GREEN `c352c02` (feat)
3. **Task 18-01-03: Atomic live-probe guarantees**
   - RED `8319eeb` (test)
   - GREEN `1c06b33` (feat)

## Files Created/Modified

- `R/competition/ucl_source_acceptance.R` - Provider state machine, review and expectation schemas, hash validation, bounded probe, and atomic transaction.
- `scripts/accept_ucl_provider.R` - Strict four-option operator entrypoint with no token or host arguments.
- `tests/testthat/test_phase18_source_acceptance.R` - No-key, owner/machine conjunction, cardinality, concurrency, rollback, replay, collision, and fresh-process tests.
- `tests/fixtures/phase18/provider_terms_review.csv` - Synthetic approved, pending, and rejected owner-review states.
- `data/competition/provider_acceptance/football_data_org_v4/ucl_2026_27/` - Six mutually bound production evidence files with a disabled current decision.

## Decisions Made

- Kept credential bytes entirely below the future Plan 18-03 transport boundary; Plan 18-01 receives only a boolean presence signal and transport-produced non-secret evidence.
- Required exact lifecycle cardinalities rather than accepting internally consistent subsets or excess rows.
- Made the first accepted provider decision available only through `live_acceptance_probe`; ordinary provider-live authority independently validates the installed manifest.
- Preserved the current fail-closed production state because no credential or completed owner review was available.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- Git index writes required the repository's existing sandbox approval path; all six TDD commits completed successfully.
- The state-progress handler updated the human progress bar but left legacy frontmatter totals stale; those fields were synchronized to the same 1/6-plan result.

## Authentication Gates

- No live authentication was attempted. The absent `FOOTBALL_DATA_API_TOKEN` is a planned, valid `not_run_missing_credential` outcome rather than a failed task.

## User Setup Required

External provider acceptance remains incomplete. See [18-USER-SETUP.md](./18-USER-SETUP.md) for the account key and owner terms-review requirements. Until those steps are complete, automation correctly remains disabled.

## Known Stubs

None. Pending owner-review rows and unobserved schema fingerprints are explicit fail-closed evidence, not placeholder production data.

## Threat Flags

None. The new credential and network boundary is covered by the plan's T18-01, T18-02, T18-07, T18-08, and T18-16 mitigations.

## Verification

- Focused Phase 18 suite: **76 assertions passed; 0 failures, warnings, or skips**.
- The committed production manifest validates in a fresh R process as `not_run_missing_credential` with `automation_enabled=FALSE`.
- Cardinality checks reject 35/37 clubs, 143/145 matches, unexpected stages, and lifecycle-wrong standings counts.
- Concurrency, interruption, writer failure, replay, and collision probes preserve incumbent bytes and leave no lock, staging, or backup residue.
- `git diff --check`: passed.

## Next Phase Readiness

- Ready for Plan 18-02 and the remaining Phase 18 source/identity contracts.
- Provider automation remains intentionally disabled until the user setup and real-key live probe complete.

## Self-Check: PASSED

- All 10 planned implementation, test, fixture, and production evidence paths exist.
- All six RED/GREEN task commits are present in Git history.
- All task acceptance criteria and plan-level verification commands passed.
- Existing martj42 data changes and unrelated untracked outputs were not staged or modified.

---
*Phase: 18-club-and-ucl-source-contracts*
*Plan: 01*
*Completed: 2026-09-20*
