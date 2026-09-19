---
phase: 16-euro-qualifying-activation-and-play-off-rules
plan: 00
subsystem: testing
tags: [R, testthat, EURO, UEFA, fixtures, baseline, regression]
requires:
  - phase: 15-nations-league-rules-and-outcomes
    provides: stable Phase 15 team identifiers and interim-ranking handoff fields
provides:
  - Repository-root-aware Phase 16 smoke and fixture harness
  - Deterministic activation, host, topology, and Phase 15 handoff fixtures
  - Runnable full-suite baseline capture/compare helper and exact captured baseline record
affects: [16-01, 16-02, 16-03, 16-04, 16-05, phase-17-dashboards]
tech-stack:
  added: []
  patterns:
    - Repository-root-aware source-style testthat harnesses
    - Stable-ID, lineage-bearing local fixture constructors
    - Full-suite regression fingerprints that preserve nonzero child status
key-files:
  created:
    - tests/testthat/test_phase16_euro_qualifying.R
    - .planning/phases/16-euro-qualifying-activation-and-play-off-rules/16-baseline-check.R
    - .planning/phases/16-euro-qualifying-activation-and-play-off-rules/16-BASELINE.md
    - .planning/phases/16-euro-qualifying-activation-and-play-off-rules/deferred-items.md
  modified:
    - .planning/phases/16-euro-qualifying-activation-and-play-off-rules/16-VALIDATION.md
key-decisions:
  - Preserve the exact existing Phase 13 full-suite capture as Wave 0 authority; a persistent known baseline remains explicitly non-green.
  - Use testthat 3.3.2 desc= selection for named smoke and fixture tests, keeping the child command exact and quoted.
  - Keep Phase 16 fixtures local, stable-ID keyed, lineage-bearing, and schema-valid when collections are intentionally empty.
requirements-completed:
  - COMP-03
  - COMP-04
  - SIM-02
  - SIM-04
coverage:
  - id: D1
    description: Repository-root-aware Phase 16 smoke harness validates the explicit pre-draw contract.
    requirement: COMP-03
    verification:
      - kind: unit
        ref: tests/testthat/test_phase16_euro_qualifying.R#phase16_smoke
        status: pass
      - kind: other
        ref: Rscript test_file desc=phase16_smoke
        status: pass
    human_judgment: false
  - id: D2
    description: Exact full-suite baseline record preserves the known Phase 13 failure as a separate non-green disposition.
    requirement: COMP-03
    verification:
      - kind: other
        ref: .planning/phases/16-euro-qualifying-activation-and-play-off-rules/16-BASELINE.md#Capture
        status: pass
      - kind: other
        ref: local helper parse/read/signature and failure-cap checks
        status: pass
    human_judgment: false
  - id: D3
    description: Shared deterministic fixtures cover active zero-results, four hosts, all topology branches, preserved scenarios, and Phase 15 interim handoffs.
    requirement: SIM-02
    verification:
      - kind: unit
        ref: tests/testthat/test_phase16_euro_qualifying.R#fixture
        status: pass
      - kind: other
        ref: Rscript test_file full Phase 16 harness
        status: pass
    human_judgment: false
  - id: D4
    description: Baseline comparison policy accepts only no failures or the exact recorded identity/signature and rejects changed identities.
    requirement: COMP-04
    verification:
      - kind: other
        ref: local synthetic phase16_baseline_compare policy check
        status: pass
    human_judgment: false
duration: 27 min
completed: 2026-08-24
status: complete
---

# Phase 16 Plan 00: Wave 0 Validation Harness Summary

**Phase 16 smoke/fixture coverage and a persistent known-baseline comparator for EURO qualifying activation**

## Performance

- **Duration:** 27 min
- **Started:** 2026-08-24T08:11:34Z
- **Completed:** 2026-08-24T08:38:42Z
- **Tasks:** 2
- **Files modified:** 5 plan artifacts

## Accomplishments

- Added a repository-root-aware `phase16_smoke` harness with schema-valid pre-draw and active-after-draw constructors.
- Added deterministic four-host, zero/one/two/over-capacity host-usage, three-topology, preserved-scenario, and Phase 15 interim-ranking handoff fixtures.
- Preserved the exact full-suite capture: child status `1`, ten normalized Phase 13 identities, SHA-256 `4f123bfc5edb83fac3b5ba6606ca6dba1971208793f7c2f11a2254b915c9a98c`, and signature `156 fixture IDs paired with zero-length normalized source columns`.
- Added capture/compare behavior that reports a persistent known baseline as non-green while gating only new or unparseable failures.

## Verification

- `phase16_smoke`: passed.
- `fixture`: passed.
- Full Phase 16 test file: passed.
- Phase 15 regression: passed.
- Baseline helper local parse/read/signature and comparator policy checks: passed.
- The existing exact full-suite capture was used as Task 1 evidence and was not rerun, per the user constraint.

## Task Commits

1. **Task 1: Trace the Wave 0 smoke harness through baseline capture** - `c7cfeca` (`test`)
2. **Task 2: Seed shared activation, host, topology, and handoff fixtures** - `24cd768` (`test`)

## Files Created/Modified

- `tests/testthat/test_phase16_euro_qualifying.R` - Smoke test, local constructors, stable IDs, lineage, and handoff assertions.
- `.planning/phases/16-euro-qualifying-activation-and-play-off-rules/16-baseline-check.R` - Exact child-process capture and no-new-failure comparator.
- `.planning/phases/16-euro-qualifying-activation-and-play-off-rules/16-BASELINE.md` - Captured full-suite evidence and known-baseline policy.
- `.planning/phases/16-euro-qualifying-activation-and-play-off-rules/16-VALIDATION.md` - Corrected test selection commands and marked Wave 0 complete.
- `.planning/phases/16-euro-qualifying-activation-and-play-off-rules/deferred-items.md` - Out-of-scope Phase 14 regression ledger.

## Decisions Made

- The known Phase 13 full-suite failure is retained as a regression fingerprint, never relabeled as a green suite.
- Empty pre-draw collections and unresolved `NA` fields are intentional contract fixtures, not fabricated active data.
- The Phase 15 handoff accepts only stable `team_id` rows at `ranking_scope = interim_overall` and `ranking_stage = interim_overall`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Made failure parsing compatible with testthat 3.3.2 output**
- **Found during:** Task 1.
- **Issue:** Numbered `Error` headers and `Maximum number of 10 failures reached` output needed explicit normalization, and the raw known shape error did not use the exact STATE wording.
- **Fix:** Parse numbered headers and capped failure counts, and map `arguments imply differing number of rows: 156, 0` to the recorded signature.
- **Files modified:** `16-baseline-check.R`.
- **Verification:** Local helper parse/read/signature checks and the preserved exact capture passed.
- **Committed in:** `c7cfeca`.

**2. [Rule 3 - Blocking] Preserved exact child-process quoting and combined-output evidence**
- **Found during:** Task 1.
- **Issue:** The baseline contract requires the exact `Rscript --vanilla -e` expression while retaining stdout/stderr and child status across a nonzero suite.
- **Fix:** Centralized the exact expression/command, quoted the child expression for `system2`, and persisted complete output hash and exit status.
- **Files modified:** `16-baseline-check.R`, `16-BASELINE.md`.
- **Verification:** Baseline command, status, hash, and local comparator policy checks passed.
- **Committed in:** `c7cfeca`.

**3. [Rule 3 - Blocking] Corrected testthat named-test selection from `filter=` to `desc=`**
- **Found during:** Task 1.
- **Issue:** The planned fast commands used `filter=` for test descriptions under testthat 3.3.2.
- **Fix:** Updated the validation commands and Wave 0 task map to use `desc="phase16_smoke"` and `desc="fixture"`.
- **Files modified:** `16-VALIDATION.md`.
- **Verification:** Both named commands passed.
- **Committed in:** `c7cfeca`.

**Total deviations:** 3 auto-fixed (1 Rule 1, 2 Rule 3). **Impact:** Compatibility and evidence-preservation fixes stayed within the validation surface; no production behavior or unrelated dirty files were changed.

## Issues Encountered

- The broad Phase 14 regression was interrupted after a prolonged dot-only run (`exit 130`); its targeted state-candidate test exposed the pre-existing missing symbol `phase14_build_competition_state_candidate`. This is recorded in `deferred-items.md` and was not fixed because it is outside Plan 16-00.
- The optional WINDOWS ledger append was rejected by an existing ledger frontmatter/entry count mismatch; the unrelated ledger was left unchanged.
- One ad hoc helper check initially used `sys.source()` with a text connection; it was corrected to `eval(parse(...))` and passed. No repository file was affected.

## Known Stubs

None. The pre-draw message text containing “not available yet” and empty/`NA` fixture fields are intentional D-14/D-16 contract values, not missing implementation.

## Authentication Gates

None.

## Next Phase Readiness

Plan 16-01 can consume the committed smoke harness, exact baseline record, and deterministic fixtures. The known full-suite Phase 13 baseline remains non-green but is isolated by the comparator; the Phase 14 missing-symbol regression remains deferred to its owning phase.

---
*Plan: 16-00*
*Completed: 2026-08-24*

## Self-Check: PASSED

- SUMMARY file exists on disk.
- Task commits `c7cfeca` and `24cd768` exist in git history.
- Required plan requirements, status, task commits, and verification claims are present.
- No unexpected file deletion was introduced by either task commit.
