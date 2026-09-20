---
phase: 19-independent-club-forecast-authority
plan: "01"
subsystem: model-authority
tags: [r, canonical-v2, club-domain, fail-closed, typed-unavailable]

requires:
  - phase: 18-club-and-ucl-source-contracts
    provides: Canonical-v2 club history, current-UCL refresh, and club identity authority readers
provides:
  - Club-only production training and current-UCL snapshot authority boundaries
  - Explicit fixture-only non-promotable club authority for deterministic tests
  - Five-row typed unavailable enrichment registry with accepted-source activation guard
affects: [19-02, 19-03, 19-04, 19-05, 19-06, 19-07, 19-08, 19-09, 19-10, phase-20, phase-21]

tech-stack:
  added: []
  patterns: [fixed production authority roots, marker-bound fixture authority, canonical-v2 parent graphs, typed unavailable evidence]

key-files:
  created:
    - R/club/model_contract.R
    - data/club/model_protocol/feature_contract.csv
    - scripts/run_phase19_focused_test.R
    - tests/testthat/helper_phase19_club_fixture.R
    - tests/testthat/test_phase19_club_domain_contract.R
  modified: []

key-decisions:
  - "Production club loaders expose no caller-selectable evidence paths; synthetic authority exists only below marker-bound process-temporary fixture roots."
  - "Current xG, injury, lineup, suspension, and player evidence stays value-less, inactive, optional, and non-imputable until one matching hash-valid accepted source contract is supplied."
  - "The committed enrichment inventory has one canonical order and rejects reordering even though its deterministic table hash is key-canonical."

patterns-established:
  - "Club authority discriminator: production snapshots are promotable only from fixed accepted Phase 18 descriptors; fixture snapshots are explicit and permanently non-promotable."
  - "Unavailable evidence is data: every fixture carries all five typed unavailable rows rather than zeros or omitted columns."

requirements-completed: [CLUBMOD-01, CLUBMOD-05]

coverage:
  - id: D1
    description: "Club-only training and current-UCL snapshot loaders fail closed on absent production authority while fixture authority remains explicit and non-promotable."
    requirement: CLUBMOD-01
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase19_club_domain_contract.R#production and fixture authority contract tests"
        status: pass
      - kind: other
        ref: "rtk Rscript --vanilla scripts/run_phase19_focused_test.R tests/testthat/test_phase19_club_domain_contract.R"
        status: pass
    human_judgment: false
  - id: D2
    description: "Five enrichment families are canonical typed unavailable evidence and cannot activate or enter formulas without accepted source authority."
    requirement: CLUBMOD-05
    verification:
      - kind: unit
        ref: "tests/testthat/test_phase19_club_domain_contract.R#enrichment registry, activation, attack, and projection tests"
        status: pass
      - kind: other
        ref: "rtk git diff --check"
        status: pass
    human_judgment: false

duration: 31min
completed: 2026-09-20
status: complete
---

# Phase 19 Plan 01: Independent Club Forecast Authority Summary

**Club-only fixed-root authority snapshots and a canonical five-feature unavailable-evidence registry now fail closed without accepted production sources.**

## Performance

- **Duration:** 31 min
- **Started:** 2026-09-20T17:13:58Z
- **Completed:** 2026-09-20T17:45:14Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Bound production training to the fixed Phase 18 accepted club-history descriptor and production current coverage to the fixed accepted UCL refresh plus complete club identity generation.
- Created marker-bound fixture authority that validates real multi-league club data while remaining explicit, isolated below the process temporary root, and non-promotable.
- Frozen exactly `current_xg`, `injury`, `lineup`, `suspension`, and `player` as value-less typed unavailable evidence with canonical row/table hashes and accepted-source activation validation.
- Added a focused fresh-process runner that rejects failures, errors, warnings, skips, missing files, and empty suites; final verification passed 9 tests and 103 assertions.

## Task Commits

Each TDD gate was committed atomically:

1. **Task 19-01-01 RED: expose club authority boundary** - `d13cf8d` (test)
2. **Task 19-01-01 GREEN: enforce club-only authority snapshots** - `26b4998` (feat)
3. **Task 19-01-02 RED: add failing enrichment contract tests** - `61922b4` (test)
4. **Task 19-01-02 GREEN: enforce typed unavailable enrichment** - `5b5afc5` (feat)

## Files Created/Modified

- `R/club/model_contract.R` - Club history/current snapshot authority, fixture isolation, typed feature validation, formula guard, and fixture evidence projection.
- `data/club/model_protocol/feature_contract.csv` - Exact ordered five-row canonical-v2 unavailable-enrichment registry.
- `scripts/run_phase19_focused_test.R` - Strict fresh-process focused test runner.
- `tests/testthat/helper_phase19_club_fixture.R` - Deterministic accepted, blocked, tampered, and incomplete multi-league fixture authority.
- `tests/testthat/test_phase19_club_domain_contract.R` - Production/fixture/domain/enrichment contracts plus runner negative-path tests.

## Decisions Made

- Production functions accept no evidence paths or authority-mode overrides, preventing test fixtures or arbitrary roots from becoming production authority.
- Fixture roots require a canonical marker bound to their normalized temporary path and fixture ID; their snapshots always carry `fixture_authority = TRUE` and `promotion_eligible = FALSE`.
- Feature rows remain optional and inactive when unavailable. Any active row must match exactly one separately supplied, canonical-hash-valid accepted source contract, and unavailable feature IDs are rejected from candidate formulas.
- The feature registry rejects non-canonical row order to make omission, collision, and reorder attacks immediately visible to consumers.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Made project-root discovery stable under testthat fresh processes**
- **Found during:** Task 19-01-01 GREEN
- **Issue:** Source-frame-based path discovery resolved the test harness location instead of the repository root.
- **Fix:** Walk upward from the process working directory until both `.planning/` and the club contract module exist.
- **Files modified:** `R/club/model_contract.R`
- **Verification:** Focused fresh-process suite passes from the repository root.
- **Committed in:** `26b4998`

**2. [Rule 1 - Bug] Preserved blank CSV evidence as typed empty character values**
- **Found during:** Task 19-01-02 GREEN
- **Issue:** Base CSV inference converted all-empty source/value/timestamp columns to logical `NA`, violating the value-less typed contract and changing canonical hashes.
- **Fix:** Declared exact CSV column classes and regenerated canonical row hashes over empty character values.
- **Files modified:** `R/club/model_contract.R`, `data/club/model_protocol/feature_contract.csv`
- **Verification:** Registry validator and focused suite pass all 103 assertions.
- **Committed in:** `5b5afc5`

---

**Total deviations:** 2 auto-fixed (2 Rule 1 bugs)
**Impact on plan:** Both fixes were required for deterministic authority behavior; neither expanded scope.

## Issues Encountered

- One shared-checkout Git index lock appeared during the Task 2 RED commit. It cleared without deletion or mutation, and the commit succeeded on retry with only the plan-owned test file staged.

## TDD Gate Compliance

- Task 19-01-01: RED `d13cf8d` precedes GREEN `26b4998`.
- Task 19-01-02: RED `61922b4` precedes GREEN `5b5afc5`.
- Final focused verification: 9 tests, 103 assertions, zero failures/errors/warnings/skips.

## Known Stubs

None. Blank production enrichment fields are the intentional, validated representation of unavailable evidence required by CLUBMOD-05; they are not model inputs or UI placeholders.

## User Setup Required

None - no credentials, network access, package installation, or external service configuration was used.

## Next Phase Readiness

- Later Phase 19 plans can consume one validated club snapshot boundary and one deterministic feature-contract hash without importing national-team authority.
- Production remains intentionally blocked with `no_accepted_club_history` and `no_accepted_current_ucl` until real Phase 18 accepted generations exist.

## Self-Check: PASSED

- All five implementation/test artifacts and this summary exist.
- RED/GREEN commits `d13cf8d`, `26b4998`, `61922b4`, and `5b5afc5` are present in repository history.

---
*Phase: 19-independent-club-forecast-authority*
*Completed: 2026-09-20*
