---
phase: 18-club-and-ucl-source-contracts
plan: "12"
subsystem: club-history-authority
tags: [r, canonical-v2, temporal-safety, immutable-generations, atomic-pointer]

requires:
  - phase: 18-07
    provides: canonical-v2 framed hash primitives
  - phase: 18-09
    provides: active club identity and validity contracts
  - phase: 18-14
    provides: canonical-first loader order
provides:
  - Pre-completion-safe historical match normalization with exact precision and cutoff rules
  - Independently recomputed corpus gates bound to registry, review, and unresolved snapshots
  - Immutable history generations selected by one atomic self-hashed descriptor
affects: [phase-19-club-model, club-history, source-governance, release-authority]

tech-stack:
  added: []
  patterns: [pure audit recomputation, exact recursive inventory, immutable generation pointer]

key-files:
  created:
    - data/club/history_current.json
    - data/club/history_generations/club-history-2026-01-bfeaf7666c8b2bc657d3/generation_manifest.csv
  modified:
    - R/club/history_contract.R
    - scripts/build_club_history_corpus.R
    - tests/testthat/test_phase18_club_history_contract.R
    - data/club/history_sources.csv
    - data/club/history_audits/club-history-2026-01/

key-decisions:
  - "Completed regulation results use kickoff plus 120 minutes; extra-time and penalty results use kickoff plus 180 minutes; date-only results use next-day 00:00 UTC."
  - "A blocked generation may advance audit evidence only by retaining an explicit prior accepted-generation reference or an explicit no-accepted state."
  - "History readers obtain authority only through a validated canonical-v2 current descriptor and never by scanning mutable audit or accepted roots."

patterns-established:
  - "Recompute-before-trust: construction and validation call the same deterministic history audit builder."
  - "One visibility boundary: immutable generation installation precedes one atomic descriptor replacement."

requirements-completed: [CLUBHIST-01]

coverage:
  - id: D1
    description: "Historical result evidence is excluded before conservative completion and at or after the training cutoff."
    requirement: CLUBHIST-01
    verification:
      - kind: unit
        ref: "tests/testthat/test_phase18_club_history_contract.R#completion and cutoff boundaries"
        status: pass
    human_judgment: false
  - id: D2
    description: "Corpus eligibility is recomputed from exact durable source, match, registry, review, and unresolved evidence."
    requirement: CLUBHIST-01
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase18_club_history_contract.R#rehashed stored claims and exact inventory"
        status: pass
    human_judgment: false
  - id: D3
    description: "Audit and accepted authority publish through one crash-safe immutable generation descriptor."
    requirement: CLUBHIST-01
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase18_club_history_contract.R#generation pointer, lock, writer failure, and subprocess termination"
        status: pass
    human_judgment: false

duration: 19min
completed: 2026-09-20
status: complete
---

# Phase 18 Plan 12: Historical Corpus Safety Summary

**Conservative completion floors, independently recomputed corpus authority, and one atomic immutable-generation pointer close historical leakage and split-publication gaps.**

## Performance

- **Duration:** 19 min
- **Started:** 2026-09-20T13:22:07Z
- **Completed:** 2026-09-20T13:41:25Z
- **Tasks:** 3
- **Files modified:** 24

## Accomplishments

- Added exact regulation, extra-time/penalty, date-only, source-availability, and strict-cutoff temporal rules with typed `evidence_before_completion` exclusions.
- Bound each corpus to exact registry, owner-review, and unresolved snapshots and rebuilt every eligibility table and manifest scalar during validation.
- Replaced separate audit/accepted swaps with immutable history generations and one self-hashed `history_current.json` visibility boundary.
- Regenerated production evidence as truthfully blocked with no accepted-generation claim.

## Task Commits

1. **Task 18-12-01: Exclude pre-completion evidence with exact precision and tie rules** — `06d5d2b` (RED), `eb1def6` (GREEN)
2. **Task 18-12-02: Recompute every corpus gate from bound source and identity snapshots** — `d3d4631` (RED), `58a2c82` (GREEN)
3. **Task 18-12-03: Commit audit and accepted corpus through one immutable generation pointer** — `fc44df2` (RED), `959f50c` (GREEN)

## Files Created/Modified

- `R/club/history_contract.R` — canonical-v2 temporal policy, pure audit recomputation, snapshot validation, and immutable generation publication.
- `scripts/build_club_history_corpus.R` — builds and reports only descriptor-selected history generations.
- `tests/testthat/test_phase18_club_history_contract.R` — 87 assertions covering temporal boundaries, forged audits, hidden files, locks, failures, and subprocess termination.
- `data/club/history_sources.csv` — canonical-v2 source inventory migration.
- `data/club/history_audits/club-history-2026-01/` — regenerated complete blocked audit with bound identity snapshots.
- `data/club/history_generations/` — immutable blocked production generation.
- `data/club/history_current.json` — atomic production descriptor with explicit no-accepted state.

## Decisions Made

- Explicit evidence before completion is rejected rather than clamped forward, preserving the fact that the supplied timestamp is impossible.
- Source commit availability participates in effective evidence time as the latest safe instant.
- Generation identity binds audit hash, acceptance state, accepted reference, and prior pointer so the same audit cannot collide across different authority histories.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Migrated history identity test fixtures to the Plan 18-09 canonical-v2 registry schema**
- **Found during:** Task 18-12-01 baseline
- **Issue:** The focused history suite could not reach temporal behavior because its local registries lacked `hash_encoding_version` and the v2 schema identifier.
- **Fix:** Updated only the overlapping history fixtures to the current identity contract.
- **Files modified:** `tests/testthat/test_phase18_club_history_contract.R`
- **Verification:** Focused history suite passes 87/87 assertions.
- **Committed in:** `06d5d2b`, `eb1def6`

**2. [Rule 1 - Bug] Made history row hashes stable across durable CSV round trips**
- **Found during:** Task 18-12-01 GREEN
- **Issue:** Type-sensitive v2 hashing of in-memory logical columns did not match the same fields reloaded as durable character CSV values.
- **Fix:** Added history-specific canonical-v2 row/table hashing over exact durable text representations.
- **Files modified:** `R/club/history_contract.R`, history CSV artifacts
- **Verification:** Candidate write/read validation and fresh-process production descriptor validation pass.
- **Committed in:** `eb1def6`, `58a2c82`

---

**Total deviations:** 2 auto-fixed (1 blocking dependency migration, 1 round-trip integrity bug).
**Impact on plan:** Both fixes were required for the planned canonical-v2 trust boundary; no feature scope was added.

## Issues Encountered

- The independent Phase 18 regression run found pre-existing Plan 18-10 fixture errors in `test_phase18_refresh_failure.R`: older fixtures pass character strings to the now raw-only `phase18_ucl_hash()`. This is recorded in `deferred-items.md` for Plan 18-13. Canonical, identity, adapter, bundle, and all Plan 18-12 history tests pass.

## Known Stubs

None. Production history is intentionally and explicitly blocked pending verified pins, license review, expected counts, and owner mappings; this is durable state, not a placeholder path.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 19 has a single validated descriptor API for discovering historical corpus authority.
- Production correctly exposes no accepted training corpus until the declared source and identity evidence is supplied and passes full recomputation.

## Self-Check: PASSED

- All key files exist.
- All six task commits exist.
- Focused history suite: 87 passed, 0 failed, 0 warnings.
- Production descriptor validates in a fresh process as `blocked` with an empty accepted-generation reference.
- `git diff --check` passed.

---
*Phase: 18-club-and-ucl-source-contracts*
*Completed: 2026-09-20*
