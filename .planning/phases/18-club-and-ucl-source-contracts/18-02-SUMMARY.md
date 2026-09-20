---
phase: 18-club-and-ucl-source-contracts
plan: "02"
subsystem: data-contracts
tags: [r, club-identity, sha256, validity-intervals, tdd]

requires:
  - phase: 13-source-contracts-and-competition-registry
    provides: canonical SHA-256, source-ID-first resolution, and fail-closed registry patterns
provides:
  - Separate three-table club identity authority with source-ID-first and reviewed-alias resolution
  - Hash-bound current/history token extraction and explicit owner-review bootstrap
  - Strict extract, review, apply, and verify CLI with atomic registry read-back and rollback
affects: [18-03-current-ucl-adapter, 18-05-historical-club-corpus, 18-06-canonical-source-bundle, phase-19-club-model]

tech-stack:
  added: []
  patterns: [half-open validity intervals, typed fail-closed conditions, canonical row-order-independent hashing, atomic three-registry updates]

key-files:
  created:
    - R/club/identity.R
    - R/club/identity_bootstrap.R
    - scripts/bootstrap_club_identity.R
    - data/club/registries/clubs.csv
    - data/club/registries/club_source_ids.csv
    - data/club/registries/club_aliases.csv
    - data/club/identity_reviews/current_ucl_tokens.csv
    - data/club/identity_reviews/historical_inventory_tokens.csv
    - data/club/identity_reviews/unresolved_club_tokens.csv
    - tests/testthat/test_phase18_club_identity.R
  modified: []

key-decisions:
  - "Club identity uses a project-owned club_ namespace and never reuses the national team/FIFA registry as authority."
  - "Production registries remain empty until explicit owner mappings exist; missing history is retained as hash-bound blocked evidence and an absent live probe remains not-run."

patterns-established:
  - "Identity resolution: exact source-system/source-club-ID at event time, then exactly one approved validity-compatible alias, otherwise a typed failure."
  - "Bootstrap review: evidence-bound owner rows are the only path into all three registries; unresolved evidence is durable and downstream coverage is recomputed."

requirements-completed: [CLUBID-01]

coverage:
  - id: D1
    description: Separate validity-aware club registry and fail-closed resolver
    requirement: CLUBID-01
    verification:
      - kind: unit
        ref: tests/testthat/test_phase18_club_identity.R#direct-alias-boundary-and-hash-contracts
        status: pass
    human_judgment: false
  - id: D2
    description: Shared current/history token extraction and atomic owner-review bootstrap
    requirement: CLUBID-01
    verification:
      - kind: integration
        ref: tests/testthat/test_phase18_club_identity.R#bootstrap-review-replay-and-atomic-writer
        status: pass
    human_judgment: false
  - id: D3
    description: Production club mapping review state
    requirement: CLUBID-01
    verification:
      - kind: manual_procedural
        ref: data/club/identity_reviews/unresolved_club_tokens.csv
        status: pass
    human_judgment: true
    rationale: "There are no production mapping rows to approve yet; the owner must review future live and historical mappings before they can populate the registries."

duration: 10 min
completed: 2026-09-20
status: complete
---

# Phase 18 Plan 02: Club Identity Authority Summary

**A separate, validity-aware club identity authority now resolves reviewed source IDs and aliases, while an evidence-bound bootstrap keeps unreviewed current and historical tokens blocked.**

## Performance

- **Duration:** 10 min
- **Started:** 2026-09-20T08:57:19Z
- **Completed:** 2026-09-20T09:07:29Z
- **Tasks:** 3
- **Files modified:** 10

## Accomplishments

- Added exact, versioned club/source-ID/alias registries with canonical row hashes, aggregate hashes, half-open validity, duplicate/overlap rejection, and typed cross-domain failures.
- Added source-ID-first resolution with exact approved alias fallback, name-disagreement detection, expiry handling, and row-order-invariant behavior.
- Added one evidence-bound current/history workflow and strict CLI for extraction, owner review, atomic application, and independent coverage verification.
- Preserved truthful production state: no club was inferred, the absent live probe remains not-run, and missing historical inventory is a hash-bound blocked row.

## Task Commits

Each TDD task was committed as RED then GREEN:

1. **Task 18-02-01: Direct club identity authority** — `94e4700` (test), `d82fada` (feat)
2. **Task 18-02-02: Reviewed alias and deterministic validity behavior** — `810b018` (test), `6f9bcfb` (feat)
3. **Task 18-02-03: Current/history owner-review bootstrap** — `391f181` (test), `09ca9ff` (feat)

## Files Created/Modified

- `R/club/identity.R` - Club-only schemas, validation, normalization, canonical hashing, loading, and resolution.
- `R/club/identity_bootstrap.R` - Token extraction, owner-review validation, replay-safe registry merge, coverage checks, and atomic writing.
- `scripts/bootstrap_club_identity.R` - Trusted-root `extract|review|apply|verify` operator CLI.
- `data/club/registries/*.csv` - Schema-complete, currently empty production identity authority.
- `data/club/identity_reviews/*.csv` - Current/history token ledgers and durable blocked evidence.
- `tests/testthat/test_phase18_club_identity.R` - Forty-four assertions covering direct IDs, aliases, boundaries, ambiguity, hashing, review, replay, coverage, and rollback.

## Decisions Made

- Club IDs must match `club_[a-z0-9_]+`; `team_*`, FIFA-only, foreign-kind, fuzzy, and first-match resolution paths are rejected.
- All validity intervals are `[valid_from_utc, valid_to_utc)`, allowing adjacency while rejecting positive-duration overlap.
- Missing production evidence does not seed registries. The historical inventory absence is explicitly blocked, while no live probe is represented as not-run.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Normalized blank CSV fields before registry hash read-back**
- **Found during:** Task 18-02-03 atomic-writer verification
- **Issue:** Base CSV inference converted blank character validity endpoints to logical `NA`, changing the canonical row hash after a valid atomic write.
- **Fix:** Registry and CLI readers now coerce all columns to character and restore blank cells before validation.
- **Files modified:** `R/club/identity.R`, `scripts/bootstrap_club_identity.R`
- **Verification:** The atomic writer round-trip and rollback test passes; all 44 focused assertions pass.
- **Committed in:** `09ca9ff`

---

**Total deviations:** 1 auto-fixed (1 Rule 1 bug).
**Impact on plan:** The fix is required for deterministic byte/reload behavior and adds no scope.

## Issues Encountered

- `data/club/history_sources.csv` does not exist yet. This is recorded as `missing_history_inventory` in the unresolved ledger, and production `verify` exits 2 with `club_identity_bootstrap_blocked` as designed.
- No live provider probe tokens exist. Current-UCL coverage therefore remains explicitly `not_run` rather than being reported complete.

## Known Stubs

None. Empty production registries and token ledgers are intentional fail-closed artifacts backed by an explicit blocked/not-run state, not UI or data placeholders.

## User Setup Required

None for this plan. Future production mappings require an owner-authored review CSV; no external credential is consumed by the identity bootstrap itself.

## Verification

- `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_club_identity.R")'` — 44 assertions passed.
- Fresh-process registry validation produced deterministic SHA-256 `d41fe2bd91b1be5cf6ba45cbc0f4a1ce3d1eb04fe3645e38c8b561e1de1bd728` with zero inferred rows.
- Production CLI `verify` exited 2 with typed `club_identity_bootstrap_blocked` because historical inventory is absent.
- `data/competition/registries/team_identity.csv` is unchanged from the plan baseline.

## Next Phase Readiness

- Plan 18-03 can route every live current-UCL club and match participant through this resolver.
- Plan 18-05 must declare the historical inventory and provide owner-reviewed mappings before the historical identity gate can complete.

## Self-Check: PASSED

All declared files and six task commits exist; focused tests, fresh-process registry validation, CLI blocked-state verification, and diff checks passed.

---
*Phase: 18-club-and-ucl-source-contracts*
*Completed: 2026-09-20*
