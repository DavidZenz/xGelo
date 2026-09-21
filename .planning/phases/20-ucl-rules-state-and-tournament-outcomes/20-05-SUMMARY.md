---
phase: 20-ucl-rules-state-and-tournament-outcomes
plan: "05"
subsystem: testing-and-orchestration
tags: [uefa-champions-league, targets, replay, fail-closed, adversarial-testing, R]

# Dependency graph
requires:
  - phase: 20-04
    provides: Canonical UCL rules, state, simulation, knockout, stage-event, and outcome contracts.
  - phase: 19-independent-club-forecast-authority
    provides: Fixed production resolver and typed CR-01..CR-05 parent-authority gate.
provides:
  - Fixed-root UCL production CLI with typed human-needed/blocked/unresolved outcomes.
  - Isolated ten-target/fifteen-edge UCL targets namespace.
  - Fresh-process aggregate Phase 20 contract, adversarial, replay, and protected-byte gate.
  - Honest validation evidence separating fixture mechanics from production authority.
affects: [phase-21, UCL dashboard consumers, pipeline verification]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Fixed internal authority roots with no caller-selectable fixture, output, selector, or release paths.
    - Typed blocked/unresolved propagation through isolated targets and stable CLI result contracts.
    - Exact inventory gates for targets, edges, public symbols, schemas, threats, requirements, and prohibitions.
    - Fresh-process fixture replay with protected production-byte snapshots and non-promotable fixture authority.

key-files:
  created:
    - scripts/build_uefa_champions_league_outcomes.R
    - scripts/verify_phase20_contracts.R
    - tests/testthat/test_phase20_adversarial_regression.R
    - .planning/phases/20-ucl-rules-state-and-tournament-outcomes/20-05-RED.md
  modified:
    - _targets.R
    - tests/testthat/test_uefa_champions_league.R
    - .planning/phases/20-ucl-rules-state-and-tournament-outcomes/20-VALIDATION.md

key-decisions:
  - "Resolve the accepted Phase 18 UCL source before invoking the fixed Phase 19 production resolver; missing authority remains typed human-needed and cannot mutate production state."
  - "Keep fixture mechanics executable only in disjoint temporary roots and permanently non-promotable; fixture runs cannot create selectors or overwrite incumbent bytes."
  - "Treat the edition draw procedure as unresolved and suppress exact draw-conditioned production outputs until authoritative evidence is accepted."
  - "Use a bounded historical regression smoke in the aggregate verifier because pre-existing Phase 14/19 blockers make a full historical suite non-diagnostic; do not claim those suites passed."
  - "Do not update STATE.md, ROADMAP.md, REQUIREMENTS.md, or PROJECT.md because the execution brief explicitly keeps Phase 19 human-needed and Phase 20 staged."

patterns-established:
  - "Production CLI result contract: every expected human-needed/blocked/unresolved result reports production_eligible=false, selector_changed=false, incumbent_changed=false, and preserves original_parent_reason."
  - "UCL target isolation: only the exact ucl20_* namespace is admitted, with no national or legacy authority edge."

requirements-completed: [UCLRULE-01, UCLRULE-02, UCLRULE-03, UCLOUT-01, UCLOUT-02, UCLOUT-03, UCLOUT-04, UCLOUT-05, UCLOUT-06]

coverage:
  - id: D1
    description: "Fixed-root UCL CLI supports help, dry-run, write, replay-check, seed, simulations, and exact edition modes while rejecting caller authority roots."
    requirement: UCLRULE-01
    verification:
      - kind: integration
        ref: "rtk Rscript --vanilla scripts/verify_phase20_contracts.R (PHASE20_PRODUCTION and PHASE20_ROOT_REJECTIONS)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Isolated UCL targets expose exactly ten named targets and fifteen directed edges and propagate typed blocked/unresolved state."
    requirement: UCLRULE-02
    verification:
      - kind: integration
        ref: "rtk Rscript --vanilla scripts/verify_phase20_contracts.R (PHASE20_TARGET_GRAPH)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Aggregate Phase 20 verifier enforces exact inventories, CR-01..CR-05 probes, focused/adversarial tests, and zero-warning/zero-skip result contracts."
    requirement: UCLRULE-03
    verification:
      - kind: integration
        ref: "rtk Rscript --vanilla scripts/verify_phase20_contracts.R (PHASE20_GATE_OK)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Fixture mechanics replay byte-identically in normal/reverse/repeat runs without production promotion or protected-byte mutation."
    requirement: UCLOUT-06
    verification:
      - kind: integration
        ref: "rtk Rscript --vanilla scripts/verify_phase20_contracts.R (PHASE20_FIXTURE_REPLAY and PHASE20_PROTECTED_BYTES)"
        status: pass
    human_judgment: false
  - id: D5
    description: "Production acceptance remains human-needed while Phase 18 authority, Phase 19 CR-01..CR-05 repair, and the edition draw procedure are unresolved."
    verification: []
    human_judgment: true
    rationale: "Automation verifies fail-closed behavior, but it cannot fabricate authoritative UEFA source, owner approval, Phase 19 repair evidence, or the unresolved edition draw procedure."

# Metrics
duration: "~55 min"
completed: 2026-09-21
status: complete
---

# Phase 20 Plan 05 Summary

**Fixed-root UCL orchestration with isolated targets, exact adversarial inventories, deterministic fixture replay, and fail-closed production handoff**

## Performance

- **Duration:** ~55 min (executor start timestamp was not captured)
- **Started:** not captured
- **Completed:** 2026-09-21T20:33:20Z
- **Tasks:** 2
- **Files modified or created:** 8 in scope, including this summary

## Accomplishments

- Implemented `scripts/build_uefa_champions_league_outcomes.R` with fixed project roots, exact `ucl_2026_27` edition handling, stable CLI modes, replay controls, closed parent-reason normalization, and fail-closed Phase 18/19 authority behavior.
- Added the exact ten-target/fifteen-edge isolated UCL target namespace to `_targets.R`; national and legacy authority dependencies are excluded and blocked/unresolved state is carried to the build status.
- Implemented a fresh-process aggregate verifier covering exact inventories, public symbols, output schemas, evidence rows, CR-01..CR-05 probes, threat/prohibition mappings, protected bytes, fixture replay, and typed production result contracts.
- Completed focused UCL tests (63 tests, 0 failures/errors/warnings/skips) and adversarial regression tests (10 tests, 0 failures/errors/warnings/skips).
- Recorded validation evidence showing the current production result is typed human-needed (`phase18_authority_missing`) with `production_eligible=false`, no selector/incumbent mutation, unresolved draw procedure, and byte-identical fixture replay.

## Task Commits

Each task was committed atomically:

1. **Task 1: Write RED contracts for fixed orchestration, target isolation, and aggregate attack coverage** - `b57f05b` (test)
2. **Task 1 RED evidence: Record orchestration RED evidence** - `8fb5295` (docs)
3. **Task 2: Implement fixed CLI/targets and the aggregate Phase 20 verification gate** - `da81d27` (feat)

The summary is the final plan documentation commit; global state/roadmap metadata was intentionally not changed per the execution brief.

## Files Created/Modified

- `scripts/build_uefa_champions_league_outcomes.R` - Fixed-root UCL CLI and typed production/fixture orchestration.
- `scripts/verify_phase20_contracts.R` - Fresh-process aggregate inventory, adversarial, replay, and protected-byte gate.
- `_targets.R` - Isolated exact UCL target graph with typed state propagation.
- `tests/testthat/test_uefa_champions_league.R` - Focused orchestration and contract coverage.
- `tests/testthat/test_phase20_adversarial_regression.R` - Public-boundary attacks and exact inventory assertions.
- `.planning/phases/20-ucl-rules-state-and-tournament-outcomes/20-VALIDATION.md` - Observed Phase 20-05 validation results and honest bounded-regression status.
- `.planning/phases/20-ucl-rules-state-and-tournament-outcomes/20-05-RED.md` - Durable RED transcript and commit evidence.
- `.planning/phases/20-ucl-rules-state-and-tournament-outcomes/20-05-SUMMARY.md` - This execution summary.

## Verification Evidence

The final aggregate verifier exited 0 and reported:

- `PHASE20_INVENTORIES edges=19 threats=21 outputs=10 requirements=9`
- `PHASE20_PUBLIC_SYMBOLS count=19 private_helpers=dot_ucl_only`
- `PHASE20_TARGET_GRAPH targets=10 edges=15 exact=true isolated=true`
- `PHASE20_EVIDENCE rows=8 regulations=7 draw_status=unresolved anchor=article_19`
- `PHASE20_CR_GATE probes=5 normalized=13 current_parent_gate=closed`
- focused tests `tests=63 failed=0 errors=0 warnings=0 skips=0`
- adversarial tests `tests=10 failed=0 errors=0 warnings=0 skips=0`
- `PHASE20_FIXTURE_REPLAY runs=3 byte_identical=true fixture_authority=true production_eligible=false`
- `PHASE20_PROTECTED_BYTES unchanged=true`
- `PHASE20_GATE_OK mechanics=true production=typed_human_needed_or_blocked replay=true warnings=0 skips=0 failures=0 unexpected_failures=0`

`rtk git diff --check` also passed. The aggregate verifier uses bounded historical regression smoke (parse/test declaration checks plus explicit Phase 19 blocker isolation); it does not claim full Phase 14/18/19 suites passed. A pre-existing Phase 14 standings assertion failure and the recorded Phase 19 repair blocker remain outside this plan’s owned files.

## Decisions Made

- Authority is resolved in fixed order: accepted Phase 18 UCL source first, then the fixed Phase 19 production resolver. Missing or under-repair authority is a typed terminal state.
- Fixture inputs are useful for mechanics and replay only; they are not authority and cannot promote outputs.
- Draw-conditioned exact paths stay suppressed while the edition draw procedure is unresolved.
- Exact inventories are treated as executable contracts, so missing/extra targets, edges, symbols, schemas, probes, or evidence rows fail the gate.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Test boundary] Scoped legacy-resolver assertions to the UCL target namespace**
- **Found during:** Task 2
- **Issue:** `_targets.R` contains pre-existing national/legacy targets outside the new UCL marker section; a global source-text prohibition would incorrectly fail unrelated Phase 14/19 wiring.
- **Fix:** The focused and adversarial tests, and aggregate graph extraction, assert the exact UCL section while separately enforcing no national/legacy edge inside that namespace.
- **Files modified:** `_targets.R`, `tests/testthat/test_uefa_champions_league.R`, `tests/testthat/test_phase20_adversarial_regression.R`, `scripts/verify_phase20_contracts.R`
- **Verification:** `PHASE20_TARGET_GRAPH targets=10 edges=15 exact=true isolated=true`; focused and adversarial suites pass.
- **Committed in:** `da81d27`

**2. [Rule 3 - Blocking] Bounded historical regression smoke around pre-existing blockers**
- **Found during:** Task 2 aggregate verification
- **Issue:** Full historical Phase 14/18/19 execution is non-diagnostic in this staged tree: Phase 14 standings has a pre-existing row-name assertion failure and Phase 19 remains gated by its recorded repair blocker.
- **Fix:** The aggregate gate validates parseability and test declarations for the Phase 14–16/18 artifacts, explicitly isolates the Phase 19 known blocker, and continues to enforce all Phase 20-owned focused/adversarial/replay/protected-byte checks.
- **Files modified:** `scripts/verify_phase20_contracts.R`, `.planning/phases/20-ucl-rules-state-and-tournament-outcomes/20-VALIDATION.md`
- **Verification:** `PHASE20_REGRESSIONS phase14_15_16=true phase18=true phase19=known_preexisting_repair_blocker bounded=true`; gate exits 0 with no unexpected failures.
- **Committed in:** `da81d27`

**Total deviations:** 2 auto-fixed (1 test-boundary adjustment, 1 bounded verification adjustment)
**Impact on plan:** Phase 20-owned contracts are fully exercised; unresolved production authority and historical blockers remain explicitly fail-closed and documented rather than hidden.

## Issues Encountered

- The initial aggregate verifier required a fixture result field that the existing outcome contract intentionally did not expose. The verifier was corrected to assert fixture graph/release markers and output non-promotion through public boundaries.
- The current fixed Phase 18 registry has no accepted UCL incumbent, so production execution correctly returns `production_human_needed` with `phase18_authority_missing`.
- The edition draw procedure remains unresolved (`accepted=false`, `complete=false`, `unresolved_reason=missing_edition_draw_procedure`) and therefore exact draw-conditioned production outputs remain suppressed.
- Pre-existing user-owned modifications and untracked data/output files were preserved untouched.

## User Setup Required

None - no external service configuration required. Production promotion still requires authoritative Phase 18/19 evidence and the unresolved edition draw procedure to be supplied through the existing human review process.

## Next Phase Readiness

Phase 21 can consume deterministic, read-only UCL mechanics and typed status artifacts. It must preserve the fixed-root CLI, exact target graph, fixture non-promotion rule, and draw suppression. Production forecasts remain human-needed until the Phase 18 authority, Phase 19 CR-01..CR-05 repair/selector evidence, and edition draw procedure are accepted.

## Self-Check: PASSED

- `FOUND: .planning/phases/20-ucl-rules-state-and-tournament-outcomes/20-05-SUMMARY.md`.
- Task commits `b57f05b`, `8fb5295`, and `da81d27` are present in git history.
- `rtk git diff --check` passed.
- No protected global planning state file was modified.

---
*Phase: 20-ucl-rules-state-and-tournament-outcomes*
*Completed: 2026-09-21*
