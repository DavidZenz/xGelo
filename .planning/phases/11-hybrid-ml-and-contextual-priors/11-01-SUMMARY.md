---
phase: 11-hybrid-ml-and-contextual-priors
plan: 01
subsystem: testing
tags: [R, testthat, nyquist, phase11, hybrid-models, benchmark-contracts]

# Dependency graph
requires:
  - phase: 10-statistical-goal-model-challengers
    provides: "Open benchmark panels, G=40 score-grid conventions, fold-local dynamic-state/Elo contracts, and provenance/checksum patterns"
provides:
  - "A six-file Phase 11 Nyquist RED contract suite with shared deterministic fixtures"
  - "Executable contracts for RF goal distributions, open contextual features, xG activation, structural priors, optional modes, and the research-only target bundle"
affects: [11-02, 11-03, 11-04, 11-05, 11-06]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Top-level exact missing-API gates make each RED file fail once on its owned production boundary."
    - "Synthetic fixtures carry value/source/date/imputation evidence companions and deterministic provenance."
    - "All hybrid probability contracts use separate goal marginals, a complete 0:40 grid, and derived 1X2 markets."

key-files:
  created:
    - tests/testthat/helper_hybrid_phase11.R
    - tests/testthat/test_hybrid_random_forest.R
    - tests/testthat/test_hybrid_context_features.R
    - tests/testthat/test_hybrid_xg_gate.R
    - tests/testthat/test_hybrid_structural_prior.R
    - tests/testthat/test_hybrid_modes.R
    - tests/testthat/test_hybrid_targets.R
  modified: []

key-decisions:
  - "Keep Wave 0 tests limited to their owned production symbols so sibling Phase 11 plans can turn contracts green independently."
  - "Lock the common benchmark denominator at 630 open fixtures, 609 rich fixtures, G=40, sealed WC2026, network-free execution, and research-only publication."
  - "Represent current xG as source-absent and inactive, and require structural-prior vintage, license, checksum, and cutoff evidence before shrinkage."
  - "Leave STATE.md and ROADMAP.md unchanged because shared Wave 0 tracking is owned by the orchestrator."

patterns-established:
  - "Every focused file sources the shared helper and stops at one explicit missing-API RED gate."
  - "Optional context, xG, structural, enriched, and external inputs must expose explicit evidence or inactive status."

requirements-completed: [HYBRID-01, HYBRID-02, HYBRID-03, HYBRID-04, HYBRID-05]

# Coverage metadata
coverage:
  - id: D1
    description: "RED contracts for separate home/away RF goal means, fold-local dynamic/Elo evidence, complete G=40 NB grids, and derived market reconciliation."
    requirement: HYBRID-01
    verification:
      - kind: unit
        ref: "tests/testthat/test_hybrid_random_forest.R via testthat::test_file"
        status: fail
      - kind: unit
        ref: "tests/testthat/test_hybrid_context_features.R via testthat::test_file"
        status: fail
    human_judgment: true
    rationale: "Expected Wave 0 RED state: both files stop at their planned missing Phase 11 production APIs; no contract or parse errors were observed."
  - id: D2
    description: "RED contracts for fail-closed current xG coverage and vintage-safe continuous structural-prior shrinkage."
    requirement: HYBRID-03
    verification:
      - kind: unit
        ref: "tests/testthat/test_hybrid_xg_gate.R via testthat::test_file"
        status: fail
      - kind: unit
        ref: "tests/testthat/test_hybrid_structural_prior.R via testthat::test_file"
        status: fail
    human_judgment: true
    rationale: "Expected Wave 0 RED state: both files stop at their planned missing Phase 11 production APIs; later implementation plans are responsible for turning these contracts green."
  - id: D3
    description: "RED contracts for open/enriched/external mode separation and the downstream-only, sealed, research-only Phase 11 target bundle."
    requirement: HYBRID-05
    verification:
      - kind: unit
        ref: "tests/testthat/test_hybrid_modes.R via testthat::test_file"
        status: fail
      - kind: unit
        ref: "tests/testthat/test_hybrid_targets.R via testthat::test_file"
        status: fail
    human_judgment: true
    rationale: "Expected Wave 0 RED state: both files stop at their planned missing Phase 11 production APIs or absent target nodes; target-boundary assertions are ready for later plans."

# Metrics
duration: 12 min
completed: 2026-08-08
status: complete
---

# Phase 11 Plan 01: Wave 0 Hybrid ML and Contextual Priors Contract Suite Summary

**Executable testthat RED contracts for RF goal distributions, open context evidence, fail-closed xG and structural priors, optional modes, and the Phase 11 target DAG**

## Performance

- **Duration:** 12 min
- **Started:** 2026-08-08T18:02:57Z
- **Completed:** 2026-08-08T18:15:04Z
- **Tasks:** 3
- **Files modified:** 7

## Accomplishments

- Added deterministic helper fixtures and six focused test_hybrid_* files covering HYBRID-01 through HYBRID-05 and D-01 through D-16.
- Locked two-goal RF/NB contracts, strict open context evidence, fail-closed xG activation, vintage-safe structural shrinkage, and separated optional modes.
- Locked the Phase 11 target/bundle boundary to 630 open fixtures, 609 rich fixtures, G=40, sealed WC2026, network-free execution, and research-only evidence.
- Verified all seven owned files parse and all six focused tests fail only at their intended missing production API gates.

## Task Commits

Each task was committed atomically:

1. **Task 1: RF and context RED contracts** - 7d2c122 (test)
2. **Task 2: xG gate and structural-prior RED contracts** - b28c486 (test)
3. **Task 3: mode and target/bundle RED contracts** - ab04f31 (test)

**Plan metadata:** The summary docs commit is reported in the final execution handoff.

## Files Created/Modified

- tests/testthat/helper_hybrid_phase11.R - Shared API gates, deterministic fixtures, evidence assertions, and target/bundle helpers.
- tests/testthat/test_hybrid_random_forest.R - Separate RF goal-regressor, NB grid, market-reconciliation, and provenance contracts.
- tests/testthat/test_hybrid_context_features.R - Host, neutral, rest, travel, stage, cutoff, and strict common-panel contracts.
- tests/testthat/test_hybrid_xg_gate.R - Current zero-coverage xG fail-closed and source-absent contracts.
- tests/testthat/test_hybrid_structural_prior.R - Vintage/checksum-gated structural snapshot and continuous shrinkage contracts.
- tests/testthat/test_hybrid_modes.R - Open/enriched/external registry and manual-market snapshot contracts.
- tests/testthat/test_hybrid_targets.R - Phase 11 target DAG, dependency-boundary, and exact run-manifest contracts.

## Decisions Made

- Used a shared helper with top-level exact missing-symbol gates so each focused RED test has one actionable failure and does not couple to later sibling APIs.
- Kept current xG rows explicitly source-absent and imputed rather than allowing zero-valued placeholders to activate the feature path.
- Required structural and manual-market fixtures to carry vintage, source-date, license, checksum, and cutoff evidence before they can feed contracts.
- Preserved the orchestrator-owned shared tracking files and all unrelated user/generated Phase 10 and sibling Phase 11 artifacts.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Halted RED gates before undefined production calls**
- **Found during:** Task 1 (RF and context RED contracts)
- **Issue:** The initial testthat::fail() gate recorded a failure but allowed test execution to continue, producing secondary undefined-symbol errors instead of the single planned missing-API failure.
- **Fix:** Changed the shared gate to stop execution and placed each owned API gate at the top level of its focused test file.
- **Files modified:** tests/testthat/helper_hybrid_phase11.R and the six tests/testthat/test_hybrid_*.R files.
- **Verification:** Re-ran all six focused test files; each produced exactly one planned missing-API error, with no parse, helper, warning, or contract-assertion error.
- **Committed in:** 7d2c122, b28c486, and ab04f31 (the shared gate was carried into the later task files).

---

**Total deviations:** 1 auto-fixed (Rule 1)
**Impact on plan:** The fix makes the required RED evidence precise and prevents misleading secondary failures; no scope creep.

## Issues Encountered

The sandbox initially denied Git index writes for task commits. Repository commits were completed through the approved escalated Git path. No project blocker remains, and no unrelated dirty or untracked files were staged.

## User Setup Required

None - no external service configuration or package installation is required for this contract-only plan.

## Next Phase Readiness

Ready for the Phase 11 production plans: 11-02 can implement the RF tracer, 11-03 the context features, 11-04 the xG/structural gates, 11-05 the optional modes, and 11-06 the target/bundle runner. The focused tests are intentionally RED until those production APIs and target nodes exist.

## Self-Check: PASSED

- All seven owned R files parse successfully.
- All three task commits exist: 7d2c122, b28c486, ab04f31.
- The six focused verification commands fail only on the planned missing Phase 11 API gates.
- No plan-owned file remains modified, and shared .planning/STATE.md / .planning/ROADMAP.md were not changed by this executor.

---
*Phase: 11-hybrid-ml-and-contextual-priors*
*Plan: 01*
*Completed: 2026-08-08*
