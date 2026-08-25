---
phase: 17-shared-dashboards-and-atomic-refresh-operations
plan: 03
subsystem: dashboard-publication
tags: [r, testthat, atomic-refresh, batch-envelope, rollback, static-dashboard]
requires:
  - phase: 17-02
    provides: Shared dashboard renderer, typed states, filters, and route contract.
provides:
  - Exact ten-file cross-edition dashboard batch envelope with bounded inventory and hashes.
  - Ordered fail-closed refresh coordinator with named Phase 13-17 callback contracts.
  - Same-parent promotion, incumbent retention, read-back validation, and rollback-safe routes.
affects: [17-04, launchd refresh, public dashboard routes]
tech-stack:
  added: []
  patterns: [exact allowlisted inventory, canonical JSON bytes, same-filesystem rename, ordered gate trace]
key-files:
  created:
    - scripts/refresh_competition_dashboards.R
    - docs/competitions/phase17-batch-manifest.json
    - docs/competitions/current.json
    - docs/competitions/nations-league/index.html
    - docs/competitions/nations-league/payload.json
    - docs/competitions/nations-league/route-manifest.json
    - docs/competitions/nations-league/current.json
    - docs/competitions/euro-qualifying/index.html
    - docs/competitions/euro-qualifying/payload.json
    - docs/competitions/euro-qualifying/route-manifest.json
    - docs/competitions/euro-qualifying/current.json
  modified:
    - R/dashboard/publication.R
    - tests/testthat/test_phase17_dashboards.R
decisions:
  - Use the Wave 0 provider and named 5 MiB/20 MiB constants for every envelope validation.
  - Stage both edition routes under one sibling candidate root and promote them with one same-parent rename.
  - Preserve incumbent bytes and exclude refresh history whenever any gate, promotion, or read-back fails.
metrics:
  duration: approximately 2 hours including regression verification
  completed: 2026-08-25
  tasks: 3
  files: 13
status: complete
requirements-completed: [OPS-02, OPS-03, OPS-05]
---

# Phase 17 Plan 03: Cross-Edition Atomic Refresh Summary

**One bounded coordinator now validates, stages, promotes, reads back, and rolls back both dashboard editions as one exact public batch.**

## Accomplishments

- Enforced the exact ten-path inventory, path containment, symlink/traversal rejection, JSON/schema checks, shared batch identity, route hashes, lineage, and 5 MiB per-file / 20 MiB batch limits.
- Added exclusive batch locking, same-parent candidate promotion, incumbent backup, exact rollback, read-back validation, and idempotent deterministic route materialization.
- Added the ordered source, rules, probability, freshness, replay, browser, regression, envelope, promotion, read-back, and Git-preflight trace with named callback aliases and exact contract descriptions.
- Generated both shared-renderer routes, route manifests, current pointers, and the cross-edition batch/current envelope; EURO remains truthful `pre_draw`.

## Task Commits

1. **Task 1: Implement exact batch inventory, limits, lock, promotion, and rollback** - `24503c7`
2. **Task 2: Wire the ordered refresh CLI to prior-phase callbacks and fail-closed gates** - `729c7b1`
3. **Task 3: Render and stage both edition routes through the shared renderer** - `d244b29`

## Verification

- Phase 17 focused suite: PASS.
- Phase 13 publication transaction: PASS.
- Phase 13 publication integration: PASS.
- Phase 15 Nations League regression: PASS.
- Phase 16 EURO qualifying regression: PASS.
- Bounded `--dry-run --skip-git`: PASS; recorded the ordered trace without public mutation.
- Public byte comparison after dry-run: PASS (`git diff --exit-code -- docs/competitions`).
- Phase 13 publication hashes: BLOCKED by the pre-existing fixture-seed shape error in `tests/testthat/test_phase13_publication_hashes.R:196` (156 fixture IDs paired with zero-length normalized columns). No Phase 17 code was involved.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected candidate-root layout for atomic same-parent promotion**
- **Found during:** Task 1 verification
- **Issue:** Renderer project-root staging placed the candidate below an extra `docs/competitions` directory, preventing a same-parent rename.
- **Fix:** Added an explicit route staging base while preserving the existing project-root default.
- **Files modified:** `R/dashboard/publication.R`, `scripts/refresh_competition_dashboards.R`
- **Commit:** `24503c7`

**2. [Rule 3 - Blocking test harness] Added route, envelope, callback, and rollback assertions**
- **Found during:** Task 1 and Task 2 verification
- **Issue:** Wave 0 tests did not exercise the new transaction boundary or named callback bindings.
- **Fix:** Added focused exact-inventory, identity, lock, rollback, gate-order, callback-alias, and route-manifest tests.
- **Files modified:** `tests/testthat/test_phase17_dashboards.R`
- **Commit:** `24503c7`, `729c7b1`, `d244b29`

## Deferred Issues

- The pre-existing Phase 13 publication-hash fixture-seed shape error remains open and is recorded in the phase deferred-items file and the cross-phase WINDOWS ledger. It predates this plan and does not affect the passing Phase 17 publication transaction or integration checks.

## Known Stubs

None in the files created or modified by this plan.

## Self-Check: PASSED

- All 13 declared implementation and generated artifact groups exist on disk.
- Task commits `24503c7`, `729c7b1`, and `d244b29` exist in Git history.
- The exact public inventory validates and dry-run leaves public bytes unchanged.

---
*Phase: 17-shared-dashboards-and-atomic-refresh-operations*
*Completed: 2026-08-25*
