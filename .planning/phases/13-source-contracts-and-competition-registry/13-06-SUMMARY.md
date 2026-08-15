---
phase: 13-source-contracts-and-competition-registry
plan: "06"
subsystem: refresh-failure-and-provenance
tags: [R, UEFA, refresh-batches, rollback, fallback, provenance]

# Dependency graph
requires:
  - phase: 13-05
    provides: fail-closed accepted-snapshot loader and normalized identity/provenance validation
  - phase: 13-08
    provides: stable historical source-contract identity coverage
  - phase: 13-12
    provides: transactional normalized publication envelope
provides:
  - durable blocked edition and registry-side refresh-batch records
  - append-only refresh status history with explicit recovery linkage
  - isolated official-fixture, reviewed-fallback, and invalid-refresh evidence
affects: [phase-13-verification, phase-14, competition-refresh-operators]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - paired edition-row, blocked-sidecar, and status-history publication with rollback
    - accepted/source byte-hash retention on failed refresh
    - explicit operator action and validation for blocked recovery

key-files:
  created:
    - tests/testthat/test_phase13_refresh_failure.R
  modified:
    - scripts/acquire_uefa_snapshot.R
    - data/competition/registries/competition_editions.csv
    - R/competition/edition_registry.R
    - R/competition/team_identity.R
    - tests/testthat/test_phase13_competition_registry.R
    - tests/testthat/test_phase13_publication_hashes.R
    - tests/testthat/test_phase13_publication_integration.R
    - tests/testthat/test_phase13_publication_manifests.R

requirements-completed: [DATA-02, DATA-04, COMP-01]

coverage:
  - id: D1
    description: "A failed candidate durably blocks one edition and links the edition row, blocked sidecar, and first status-history event by one refresh_batch_id."
    requirement: COMP-01
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase13_refresh_failure.R"
        status: pass
      - kind: human-check
        ref: "isolated invalid replacement evidence"
        status: approved
    human_judgment: true
  - id: D2
    description: "Failed refresh publication leaves accepted output and immutable source registries byte/hash stable, with exact sidecar-write rollback coverage."
    requirement: DATA-02
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase13_refresh_failure.R"
        status: pass
      - kind: human-check
        ref: "accepted_unchanged=TRUE; source_registries_unchanged=TRUE"
        status: approved
    human_judgment: true
  - id: D3
    description: "Reviewed fallback remains edition-wide, approved, and fully represented in source provenance."
    requirement: DATA-04
    verification:
      - kind: integration
        ref: "reviewed fallback fixture replay and edition loader"
        status: pass
      - kind: human-check
        ref: "fallback_status=reviewed_fallback; review_state=approved"
        status: approved
    human_judgment: true

# Metrics
completed: 2026-08-15
status: complete
---

# Phase 13 Plan 06: Durable Refresh Failure and Recovery Summary

**Refresh failures now remain auditable, fail closed, and retain the last accepted competition output.**

## Accomplishments

- Added one refresh-batch identity per acquisition attempt and durable blocked state across `competition_editions.csv`, registry-side `blocked_refresh.json`, and append-only `status_history.csv`.
- Added staged cross-validation and rollback for edition, sidecar, and history publication, including an injected sidecar-writer failure regression.
- Required explicit operator action and `validation_passed=TRUE` before a blocked edition can recover; later accepted refreshes use a distinct batch identity and preserve the original blocked record.
- Reconciled normalized publication contracts across the acquisition, accepted snapshot, source registry, manifest, and loader test harnesses.

## Verification

- Seven focused Phase 13 test files completed with exit code `0`:
  `phase13_competition_registry`, `phase13_publication_hashes`,
  `phase13_publication_integration`, `phase13_publication_manifests`,
  `phase13_publication_transaction`, `phase13_refresh_failure`, and
  `phase13_source_contracts`.
- Official-fixture replay: accepted normalized tables and the edition loader returned `OK` with one row in each of fixtures, groups, standings, results, and status.
- Reviewed-fallback replay: all five artifacts carried `reviewed_fallback` and `approved` provenance; the edition loader returned `OK`.
- Invalid replacement replay: capture exited nonzero; accepted output and immutable source registries remained SHA-256 identical; the blocked-state loader returned `OK`; unapproved recovery was rejected.
- The repository-wide suite was also run. Its remaining failures are unrelated Phase 10 statistical challenger feature-contract drift at rows 42-47 (`source_artifact_sha256`); no Phase 13 tests failed.

## Human Gate Evidence

Local isolated evidence was retained at:

- `phase13-human-check-ffVUIa/official/`
- `phase13-human-check-1xS5hT/fallback/`
- `phase13-human-check-n8RzQz/invalid/`

The user reviewed the evidence and explicitly approved the blocking human gate on 2026-08-15.

## Caveats Accepted at the Gate

- The official UEFA pages were reachable, but this environment did not expose the undocumented structured JSON endpoint URLs required for a live replay. The approved official evidence therefore uses the committed official-source fixture replay and records the official UEFA page URLs in provenance.
- The CLI capture emits normalized accepted tables directly, while the standalone normalized-publication helper expects a source-shaped handoff. The direct accepted-edition loader passes, and the focused publication integration suite covers the source-handoff-to-normalized transaction boundary.

## Task Commits

1. **Implement durable Phase 13 refresh failure state** - `5be4054`
2. **Reconcile normalized publication contracts** - `0599b7c`

## Next Phase Readiness

Phase 13 implementation and the approved Plan 13-06 gate are complete. The next workflow step is Phase 13 verification before planning Phase 14.

---
*Phase: 13-source-contracts-and-competition-registry*
*Plan: 06*
*Completed: 2026-08-15*
