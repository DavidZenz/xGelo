---
phase: 18-club-and-ucl-source-contracts
plan: "07"
subsystem: data-integrity
tags: [r, sha256, canonical-encoding, tamper-evidence, tdd]

requires:
  - phase: 18-club-and-ucl-source-contracts
    provides: legacy acceptance and club-identity hash consumers whose collision risk was reproduced
provides:
  - domain-separated phase18-canonical-v2 scalar, sequence, row, and table hash primitives
  - adversarial collision, type, control-character, ordering, and multiplicity regression contract
  - isolated pre-migration foundation for loader bootstrapping and later authority migrations
affects: [18-14-loader-bootstrap, 18-08-acceptance-migration, 18-09-identity-migration]

tech-stack:
  added: []
  patterns: [length-prefixed raw-byte framing, explicit schema and type domains, duplicate-preserving canonical ordering]

key-files:
  created:
    - R/common/phase18_canonical_hash.R
    - tests/testthat/test_phase18_canonical_hash.R
  modified: []

key-decisions:
  - "Canonical v2 preserves exact UTF-8 bytes without Unicode normalization, so byte-distinct normalization forms remain auditable and distinct."
  - "Numeric scalar payloads use locale-independent binary-derived text, while every scalar binds its field name, explicit type, missing marker, and byte length."
  - "Canonical tables accept duplicate stable keys but reject missing or blank key values and use v2 row bytes as deterministic tie-breakers."

patterns-established:
  - "Canonical v2 framing: every compound digest begins with phase18-canonical-v2 plus an explicit scalar, sequence, row, or table domain."
  - "Migration isolation: shared primitives may land before consumers, but no durable authority claims v2 until loader order and domain migrations are complete."

requirements-completed: [UCLSRC-01, CLUBID-01]

coverage:
  - id: D1
    description: "Unambiguous scalar and row hashing distinguishes delimiter, control-character, missing, empty, Unicode, field-name, and type variants."
    requirement: UCLSRC-01
    verification:
      - kind: unit
        ref: "tests/testthat/test_phase18_canonical_hash.R#length-prefixed row and scalar framing tests"
        status: pass
    human_judgment: false
  - id: D2
    description: "Canonical sequence and table hashing binds schema, order, stable keys, duplicate multiplicity, and one-byte mutations while permitting row reorder."
    requirement: CLUBID-01
    verification:
      - kind: unit
        ref: "tests/testthat/test_phase18_canonical_hash.R#sequence and table semantics tests"
        status: pass
    human_judgment: false
  - id: D3
    description: "The v2 primitive remains isolated from every existing Phase 18 authority consumer before migration."
    requirement: UCLSRC-01
    verification:
      - kind: integration
        ref: "Rscript --vanilla Phase 18 sampling gate over all test_phase18_*.R files"
        status: pass
    human_judgment: false

duration: 4min
completed: 2026-09-20
status: complete
---

# Phase 18 Plan 07: Canonical Hash Primitive Summary

**Domain-separated, length-prefixed SHA-256 framing now makes Phase 18 scalar, sequence, row, and table evidence unambiguous without migrating any incumbent authority consumer.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-09-20T11:30:34Z
- **Completed:** 2026-09-20T11:34:31Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Reproduced and closed the `("x|y", "z")` versus `("x", "y|z")` delimiter collision with typed length-prefixed raw-byte framing.
- Added explicit sequence, row, and canonical-table domains that bind names, types, schema tags, key layouts, missing markers, and row multiplicity.
- Proved the common module in isolation, then ran every existing Phase 18 test unchanged to confirm no premature consumer or persisted-artifact migration.

## Task Commits

Each TDD task was committed atomically:

1. **Task 18-07-01: Prove canonical encoding against delimiter and control-character collisions**
   - `893b9c3` — failing adversarial contract
   - `c48eaa1` — canonical v2 scalar, row, sequence, and table implementation
2. **Task 18-07-02: Lock deterministic sequence, row, and table semantics**
   - `200516b` — failing stable-key and extended semantics contract
   - `62cc642` — non-missing, nonblank stable-key enforcement

## Files Created/Modified

- `R/common/phase18_canonical_hash.R` — raw-byte framing, typed scalar conversion, ordered sequence and row hashing, and duplicate-preserving canonical table hashing.
- `tests/testthat/test_phase18_canonical_hash.R` — collision corpus and adversarial type, Unicode, control-character, ordering, schema, mutation, and multiplicity tests.

## Decisions Made

- Preserve exact UTF-8 bytes rather than silently normalizing Unicode; this keeps the integrity claim byte-explicit and deterministic.
- Represent integer and floating-point values with locale-independent binary-derived text rather than locale-sensitive display formatting or R serialization.
- Allow repeated stable keys because valid evidence can contain multiplicity, but require every key component to be present and nonblank; v2 row bytes provide deterministic tie-breaking.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- Repository `.git` writes were sandbox-restricted; the already-approved Git escalation path was used for the required atomic commits.

## User Setup Required

None - no external service configuration required.

## Known Stubs

None.

## Next Phase Readiness

- Plan 18-14 can source the common module before any Phase 18 consumer.
- Plans 18-08 and 18-09 can migrate acceptance and club-identity authorities onto the stable v2 interface after loader bootstrapping.
- No provider, identity, CLI, durable evidence, or persisted artifact changed in this plan.

## Verification

- Focused canonical suite: 31 assertions passed.
- Full pre-migration Phase 18 sampling gate: all seven Phase 18 test files passed unchanged, including the 31 new canonical assertions.
- Scope audit: only `R/common/phase18_canonical_hash.R` and `tests/testthat/test_phase18_canonical_hash.R` changed in production/test commits.

## Self-Check: PASSED

- Both key files exist.
- All four task commits exist in Git history.
- Every task acceptance criterion and plan-level verification command passed.

---
*Phase: 18-club-and-ucl-source-contracts*
*Completed: 2026-09-20*
