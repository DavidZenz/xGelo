---
phase: 18-club-and-ucl-source-contracts
plan: "03"
subsystem: data-contracts
tags: [r, httr2, football-data.org, ucl, secret-safety, club-identity, testthat]

requires:
  - phase: 18-club-and-ucl-source-contracts
    provides: provider acceptance state machine, reviewed edition expectations, and club identity authority from Plans 18-01 and 18-02
provides:
  - Fixed four-endpoint football-data.org UCL request and transport boundary
  - Canonical competition, club, match, standings, and lifecycle projection through reviewed club identity
  - Offline contract and explicit first-live-acceptance CLI modes with exact token scanning
  - Typed rejection matrix for transport, schema, pagination, freshness, enum, cardinality, and identity failures
affects: [18-04-last-known-good, 18-06-canonical-source-bundle, phase-20-ucl-state]

tech-stack:
  added: []
  patterns:
    - "Fixed-host request plans carry no credential state; the live performer reads the redacted token only at request time."
    - "Provider responses retain exact raw bytes while only whitelisted non-secret metadata crosses the transport boundary."
    - "Nonaccepted operator decisions are observational and preserve an incumbent acceptance set byte-for-byte."

key-files:
  created:
    - R/competition/football_data_org_adapter.R
    - tests/testthat/test_phase18_football_data_adapter.R
    - tests/fixtures/phase18/football_data_org/null_resource.json
    - tests/fixtures/phase18/football_data_org/empty_teams.json
    - tests/fixtures/phase18/football_data_org/incomplete_page.json
    - tests/fixtures/phase18/football_data_org/unknown_match_enum.json
  modified:
    - scripts/accept_ucl_provider.R
    - tests/testthat/test_phase18_source_acceptance.R

key-decisions:
  - "The public adapter accepts only the exact CL/2026 four-resource request plan; no host, URL, path, or per-ID traversal parameter exists."
  - "Synthetic adapter evidence is always offline_contract_test with automation disabled; only explicit live_acceptance_probe can invoke the atomic accepted-manifest writer."
  - "Every projected club and match participant must resolve through the Plan 18-02 reviewed registry before probe evidence can reach the writer."
  - "An existing acceptance set is immutable for missing-key, pending-review, rejected, offline, or otherwise nonaccepted operator outcomes."

patterns-established:
  - "Transport validation order: fixed final URL, status, JSON content type, byte limit, exact raw hash, parse, then semantic projection."
  - "Lifecycle acceptance independently compares observed clubs, league-phase matches, stages, and standings with the reviewed expectation hash."

requirements-completed: [UCLSRC-02]

coverage:
  - id: D1
    description: "Fixed, secret-safe four-resource provider adapter with deterministic canonical UCL projection"
    requirement: UCLSRC-02
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase18_football_data_adapter.R#fixed-window transport and canonical projection"
        status: pass
      - kind: other
        ref: "Rscript --vanilla -e 'testthat::test_file(\"tests/testthat/test_phase18_football_data_adapter.R\")'"
        status: pass
    human_judgment: false
  - id: D2
    description: "Explicit offline and first-live-acceptance CLI modes bound to reviewed club identity and atomic provider evidence"
    requirement: UCLSRC-02
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase18_source_acceptance.R#operator CLI adapter seams and incumbent immutability"
        status: pass
      - kind: other
        ref: "fresh-process production authority validation remains disabled with missing_credential"
        status: pass
    human_judgment: true
    rationale: "Synthetic seams prove the bounded transaction, but real provider rights, terms, key behavior, schema, completeness, and freshness still require owner review and a real credential."

duration: 9 min
completed: 2026-09-20
status: complete
---

# Phase 18 Plan 03: Current UCL Provider Adapter Summary

**A fixed-host football-data.org adapter now projects the complete UCL 2026/27 resource window through reviewed club identities while keeping credentials process-local and production automation fail-closed.**

## Performance

- **Duration:** 9 min
- **Started:** 2026-09-20T09:13:32Z
- **Completed:** 2026-09-20T09:22:44Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments

- Added the exact four competition-scoped CL requests, nine-per-minute throttling, bounded three-attempt retry policy, fixed-host redirect checks, JSON/byte validation, and exact raw SHA-256 capture.
- Added canonical edition-scoped competition, club, match, standings, and lifecycle tables with reviewed club resolution and nullable score preservation.
- Added typed rejection of null, empty, partial, duplicate, stale, enum-unknown, wrong-edition, cardinality-drifted, and identity-unresolved provider resources.
- Extended the operator CLI with explicit offline and live-acceptance modes, deterministic current-club token evidence, exact secret scanning, and byte-preserving nonaccepted outcomes.

## Task Commits

1. **Task 18-03-01: Fictional fixed-window tracer** — `16839f5` (RED), `ef3a9db` (GREEN)
2. **Task 18-03-02: Live-acceptance CLI wiring** — `136bf41` (RED), `e644d0f` (GREEN)
3. **Rejection-matrix hardening** — `58885aa` (test)

## Files Created/Modified

- `R/competition/football_data_org_adapter.R` - Fixed request plan, live performer, bounded fetcher, response validation, secret scan, and canonical projection.
- `scripts/accept_ucl_provider.R` - Explicit offline/live modes, reviewed registry integration, deterministic token evidence, and incumbent-preserving transaction routing.
- `tests/testthat/test_phase18_football_data_adapter.R` - Sixty-five assertions across the positive lifecycle and negative transport/semantic matrix.
- `tests/testthat/test_phase18_source_acceptance.R` - Eighty-nine assertions including CLI adapter integration and nonaccepted-state immutability.
- `tests/fixtures/phase18/football_data_org/*.json` - Provider-shaped null, empty, incomplete-page, and unknown-enum boundary fixtures.

## Decisions Made

- Kept the request plan closed: the only live URLs are the four reviewed `api.football-data.org/v4/competitions/CL` resources, with season 2026 fixed where applicable.
- Kept credentials below the transport boundary using `httr2::req_headers_redacted()`; no request object, token, or authentication header enters returned or durable evidence.
- Treated provider standings strictly as source evidence. The adapter projects rows but does not implement or authorize UCL ranking rules.
- Left the committed production decision at `not_run_missing_credential`; synthetic successful probes run only in temporary test roots.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The original no-key CLI rewrote an existing nonaccepted decision on every invocation. The Task 2 RED test exposed this before completion; the CLI now returns candidate decision evidence in memory and preserves the incumbent files exactly.
- Git index writes used the repository's existing sandbox approval path; all task commits completed successfully.

## Authentication Gates

- No live authentication or network request was attempted. The real `FOOTBALL_DATA_API_TOKEN` remains absent, and the production authority correctly validates as disabled with `missing_credential`.

## User Setup Required

No new setup artifact was created. The existing [18-USER-SETUP.md](./18-USER-SETUP.md) remains the authoritative account-key and owner-review checklist before a real live probe may run.

## Known Stubs

None. Synthetic provider payloads are test-only contract evidence; production acceptance remains explicitly disabled rather than represented by placeholder data.

## Threat Flags

None. The new credential, remote-response, redirect, provider-identity, and first-acceptance surfaces are covered by T18-01 through T18-06 and T18-16 in the plan threat model.

## Verification

- Adapter suite: **65 assertions passed; 0 failures, warnings, or skips**.
- Source-acceptance suite: **89 assertions passed; 0 failures, warnings, or skips**.
- Production provider authority fresh-process validation: disabled with `reason_code = missing_credential`.
- Exact sentinel scan found no credential occurrence in provider acceptance data or fixture outputs.
- `git diff --check`: passed.

## Next Phase Readiness

- Plan 18-06 can consume deterministic canonical current-state tables and recompute provider authority from the accepted manifest.
- Plan 18-04 can wrap adapter failures in blocked-refresh evidence while preserving last-known-good accepted bytes.
- Real provider automation remains intentionally unavailable until the owner completes the Phase 18 setup and runs the no-cache live acceptance probe.

## Self-Check: PASSED

- All eight declared implementation, test, and fixture paths exist.
- All five Plan 18-03 task/test commits exist in Git history.
- Both plan verification commands and the production fail-closed validation passed.
- Unrelated martj42 changes and untracked debug, benchmark, and release artifacts were not staged or modified.

---
*Phase: 18-club-and-ucl-source-contracts*
*Plan: 03*
*Completed: 2026-09-20*
