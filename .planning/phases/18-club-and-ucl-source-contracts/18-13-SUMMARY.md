---
phase: 18-club-and-ucl-source-contracts
plan: "13"
subsystem: testing
tags: [testthat, adversarial-regression, canonical-hash, fail-closed, nyquist]
requires:
  - phase: 18-08..18-14
    provides: canonical-v2 provider, identity, bundle, refresh, and history contracts
provides:
  - Exact CR-01 through CR-15 and WR-01 through WR-04 production regressions
  - One fresh-process gate for all eight Phase 18 test files
  - Exact 50-prohibition and 15-edge evidence inventories
  - Complete 35-task Nyquist validation contract
affects: [phase-18-verification, phase-19, release-gates]
tech-stack:
  added: []
  patterns: [fresh-process test isolation, immutable production byte-map guard, digest-bound evidence inventory]
key-files:
  created:
    - tests/testthat/test_phase18_adversarial_regression.R
    - scripts/verify_phase18_contracts.R
  modified:
    - R/competition/ucl_source_acceptance.R
    - tests/testthat/test_phase18_source_acceptance.R
    - .planning/phases/18-club-and-ucl-source-contracts/18-VALIDATION.md
key-decisions:
  - "A Phase 18 pass requires all eight explicit test files in fresh processes with zero failures, warnings, or skips."
  - "The 50 prohibition identities are bound by plan, ordinal, canonical-v2 text digest, and one aggregate inventory digest."
  - "Live resource evidence requires positive observed counts before provider automation can become authoritative."
patterns-established:
  - "Production evidence is recursively byte-mapped before and after verification; any mutation fails the gate."
  - "Critical, warning, and edge evidence inventories are exact rather than best-effort discovery."
requirements-completed: [UCLSRC-01, UCLSRC-02, UCLSRC-03, UCLSRC-04, CLUBID-01, CLUBHIST-01]
coverage:
  - id: D1
    description: Exact critical and warning exploit suite against production interfaces
    requirement: UCLSRC-01
    verification:
      - kind: integration
        ref: tests/testthat/test_phase18_adversarial_regression.R#CR-01..CR-15 and WR-01..WR-04
        status: pass
    human_judgment: false
  - id: D2
    description: Unified Phase 18 gate with edge, prohibition, full-suite, and production-evidence checks
    requirement: UCLSRC-04
    verification:
      - kind: integration
        ref: Rscript --vanilla scripts/verify_phase18_contracts.R
        status: pass
    human_judgment: false
  - id: D3
    description: Live provider owner, credential, and source approval remains an explicit external dependency
    requirement: UCLSRC-01
    verification: []
    human_judgment: true
    rationale: Real provider rights and credential-backed live evidence require owner review outside this credential-free phase gate.
duration: 52min
completed: 2026-09-20
status: complete
---

# Phase 18 Plan 13: Adversarial Contract Gate Summary

**A digest-bound, fresh-process regression gate now proves 15 critical exploits, four warning regressions, 15 edge cases, and all 50 kept prohibitions while preserving fail-closed production evidence byte-for-byte.**

## Performance

- **Duration:** 52 min
- **Started:** 2026-09-20T14:16:00Z
- **Completed:** 2026-09-20T15:07:59Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Added exact production-level CR-01..CR-15 and WR-01..WR-04 tests, including real fork/kill concurrency and CLI subprocess checks.
- Added one canonical-first runner that executed eight test files, 131 tests, and 785 assertions with zero failures, warnings, or skips.
- Bound 50 plan prohibitions (20 original, 30 gap) and 15 named edge probes to automated evidence and completed the 35-task Nyquist map.
- Proved committed provider automation remains disabled, UCL refresh has no incumbent, club history remains blocked, and verification changes no production evidence bytes.

## Task Commits

1. **Task 1 RED: exact probe inventory** - `08d1fdd`
2. **Fixture isolation prerequisite** - `cff7982`
3. **Task 1 RED: exact production exploits** - `10e8682`
4. **Task 1 GREEN: zero-observation authority fix** - `9d30dce`
5. **Task 2 RED: unified phase gate** - `3bcdef3`
6. **Task 2 GREEN: inventories, full runner, and validation map** - `d831b75`

## Files Created/Modified

- `tests/testthat/test_phase18_adversarial_regression.R` - Exact CR, WR, and edge inventory with production-level probes.
- `scripts/verify_phase18_contracts.R` - Fresh-process eight-file gate, prohibition bijection, committed evidence readers, and byte-map isolation proof.
- `R/competition/ucl_source_acceptance.R` - Requires positive observed counts for integrated live provider resources.
- `tests/testthat/test_phase18_source_acceptance.R` - Fixes canonical-v2 fixture schema, sandboxes CLI history publication, strengthens byte-map isolation, and covers zero observations.
- `.planning/phases/18-club-and-ucl-source-contracts/18-VALIDATION.md` - Records all 35 tasks and post-gate Nyquist completion.

## Decisions Made

- Every `test_phase18_*.R` file is an explicit allowlisted gate input; adding or removing a file requires updating the evidence contract.
- Prohibition changes fail through a canonical aggregate of all plan+ordinal+text-digest identities, while each runtime identity has exactly one automated evidence row.
- Credential-free success means truthful fail-closed production state, not fabricated live provider acceptance.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Sandboxed source-acceptance history publication**
- **Found during:** Task 1 preflight
- **Issue:** Two legacy adapter fixtures lacked `hash_encoding_version`, and a CLI smoke test ignored obsolete path options and mutated tracked production history state.
- **Fix:** Migrated the three fixture tables to canonical-v2, passed the supported sandbox generation/current options, and guarded production pointer/generation bytes recursively.
- **Files modified:** `tests/testthat/test_phase18_source_acceptance.R`
- **Verification:** Source-acceptance suite passed 266 assertions and production paths remained unchanged.
- **Committed in:** `cff7982`

**2. [Rule 1 - Bug] Closed zero-observation live authority bypass**
- **Found during:** Task 1 CR-04
- **Issue:** Rehashed live resource rows with zero observations still passed machine validation and could enable automation.
- **Fix:** Required a positive observed count for every integrated provider resource and returned typed `coverage` failure otherwise.
- **Files modified:** `R/competition/ucl_source_acceptance.R`, `tests/testthat/test_phase18_source_acceptance.R`, `tests/testthat/test_phase18_adversarial_regression.R`
- **Verification:** CR-04 and focused acceptance regression pass; unified gate passes all 785 assertions.
- **Committed in:** `9d30dce`

---

**Total deviations:** 2 auto-fixed (2 Rule 1 bugs)
**Impact on plan:** Both fixes were required for isolation and fail-closed authority; no feature scope was added.

## Issues Encountered

- The initial runner treated the history reader result as nested and emitted locale-smart quotes in child expressions; both runner-only shape issues were corrected before the authoritative run.

## User Setup Required

None - the gate is intentionally credential-free. Real provider acceptance remains a separate explicit owner/key/source action.

## Next Phase Readiness

Phase 18 source contracts now have one non-bypassable regression command suitable for final verification and Phase 19 consumption. The expected external blockers remain explicit: no real provider credential/owner acceptance and no accepted historical training corpus.

## Self-Check: PASSED

- All listed files and commits exist.
- `Rscript --vanilla scripts/verify_phase18_contracts.R` passed with 8 files, 131 tests, and 785 assertions.
- `git diff --check` passed and the production byte-map was unchanged.

---
*Phase: 18-club-and-ucl-source-contracts*
*Completed: 2026-09-20*
