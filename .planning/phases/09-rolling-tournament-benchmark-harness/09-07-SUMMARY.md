---
phase: 09-rolling-tournament-benchmark-harness
plan: "07"
subsystem: benchmark-governance
tags: [r, promotion, reproducibility, checksums, tdd]

requires:
  - phase: 09-06
    provides: Panel-exact score summaries, paired comparisons, and durable evidence reconciliation
provides:
  - Complete source-precision D-16 through D-20 gate values and booleans
  - Canonical candidate assembly with evaluate_promotion as the sole decision authority
  - Two-pass reproducibility finalization and evaluator-backed bundle read-back validation
affects: [09-08, benchmark-publication, promotion-decisions]

tech-stack:
  added: []
  patterns: [pure-policy-evaluator, source-table-reconstruction, post-two-pass-finalization]

key-files:
  created: []
  modified:
    - R/evaluation/promotion.R
    - R/benchmark/runner.R
    - tests/testthat/test_benchmark_promotion.R
    - tests/testthat/test_benchmark_pipeline.R

key-decisions:
  - "Canonical decisions have no injectable or hard-coded policy path: benchmark_runner_decisions calls evaluate_promotion exactly once per registered model."
  - "Reproducibility remains false during both provisional runs and becomes a promotion input only after all non-decision hashes reconcile."
  - "Optional production_hybrid_nb decisions use the rich self-comparison plus the complete open-incumbent companion evidence required by D-19."

patterns-established:
  - "Decision reconstruction: derive candidates from persisted summaries, comparisons, coverage, and manifest facts, then compare the serialized evaluator result during validation."
  - "Gate serialization: persist every gate value as value__*, every boolean as pass__*, and ordered failures in reason_codes."

requirements-completed: [BENCH-03, BENCH-05]

coverage:
  - id: D1
    description: Complete D-16 through D-20 values, booleans, and ordered empty/non-empty reason semantics
    requirement: BENCH-05
    verification:
      - kind: unit
        ref: tests/testthat/test_benchmark_promotion.R
        status: pass
    human_judgment: false
  - id: D2
    description: Canonical candidate construction and mandatory evaluator-backed decisions with tamper detection
    requirement: BENCH-05
    verification:
      - kind: integration
        ref: tests/testthat/test_benchmark_pipeline.R
        status: pass
      - kind: other
        ref: canonical production decision reconstruction against the existing Phase 09 artifacts
        status: pass
    human_judgment: false
  - id: D3
    description: Reproducibility finalization only after normal and reversed-order non-decision artifacts match
    requirement: BENCH-03
    verification:
      - kind: integration
        ref: tests/testthat/test_benchmark_pipeline.R#promotion decisions are finalized only after matching independent passes
        status: pass
    human_judgment: false

duration: 36min
completed: 2026-07-21
status: complete
---

# Phase 09 Plan 07: Canonical Promotion Decision Path Summary

**Checksum-backed candidate reconstruction now feeds the frozen D-16 through D-20 evaluator, persists 159 gate evidence/pass columns, and finalizes decisions only after two independent runs reconcile.**

## Performance

- **Duration:** 36 min
- **Started:** 2026-07-21T10:35:19Z
- **Completed:** 2026-07-21T11:11:17Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Expanded the pure promotion evaluator to return complete full-precision values and one boolean per frozen core, supporting, rich, open-companion, contract, freeze, reproducibility, and seal gate.
- Replaced the runner's hard-coded retain path with source-table candidate assembly and exactly one `evaluate_promotion()` call per registered model.
- Added post-two-pass finalization plus bundle reconstruction that rejects tampered decisions, reasons, values, booleans, ordering, or premature reproducibility.
- Confirmed the existing 630-fixture production artifacts reconstruct five decisions with complete nonblank failure reasons and 159 serialized value/pass columns.

## Task Commits

Each task was committed atomically using TDD:

1. **Task 1 RED: Complete promotion gate evidence tests** - `9f99f25`
2. **Task 1 GREEN: Complete frozen promotion gate evidence** - `deacb09`
3. **Task 2 RED: Canonical runner promotion regressions** - `14ea646`
4. **Task 2 GREEN: Evaluator-backed runner and two-pass finalization** - `7bbfc9d`

**Plan metadata:** committed separately after state and roadmap updates.

## Files Created/Modified

- `R/evaluation/promotion.R` - Pure complete gate-value, gate-pass, and reason mapping for D-16 through D-20.
- `R/benchmark/runner.R` - Candidate assembly, sole evaluator invocation, stable decision flattening, two-pass finalization, and read-back reconstruction.
- `tests/testthat/test_benchmark_promotion.R` - Complete names, source precision, boundary, one-to-one reason, and empty-reason regressions.
- `tests/testthat/test_benchmark_pipeline.R` - Bypass, evidence completeness, reproducibility ordering, and decision-tampering regressions.

## Decisions Made

- The evaluator remains non-injectable in production. Tests prove one literal evaluator call site and one unique result row per model, avoiding a test hook that would itself create a governance bypass.
- The optional production model's core/open companion evidence comes from the registered open incumbent self-comparison, while its rich evidence comes from the production-hybrid self-comparison.
- Bundle reconstruction is enabled whenever the checksum-validated protocol is supplied; legacy synthetic writer fixtures remain compatible when no protocol is requested.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Security] Removed the proposed injectable evaluator test hook**
- **Found during:** Task 2 GREEN
- **Issue:** An evaluator function parameter would permit canonical callers to bypass `evaluate_promotion()`, contradicting the critical threat mitigation.
- **Fix:** Kept a literal, non-injectable evaluator call and proved one call site plus one unique decision per registered model.
- **Files modified:** `R/benchmark/runner.R`, `tests/testthat/test_benchmark_pipeline.R`
- **Verification:** Static bypass assertion and 72 passing pipeline assertions.
- **Committed in:** `7bbfc9d`

**2. [Rule 3 - Blocking] Reduced redundant protocol-test setup work**
- **Found during:** Overall promotion regression verification
- **Issue:** Revalidating the same 3,960-row score-support audit and rehashing every row in a tamper fixture exceeded the command execution window.
- **Fix:** Reused the already validated frozen protocol and rehashed only the intentionally changed audit row; all validation assertions remain unchanged.
- **Files modified:** `tests/testthat/test_benchmark_promotion.R`
- **Verification:** Protocol validation (8 assertions), protocol tampering (3 assertions), and all lightweight promotion gates pass in isolated runs.
- **Committed in:** `7bbfc9d`

**3. [Rule 1 - Bug] Corrected stale progress fields after SDK state update**
- **Found during:** Plan tracking finalization
- **Issue:** The state progress handler reported 91% but left the frontmatter at 20% and the prose progress, activity, and next action at Plan 06 values.
- **Fix:** Reconciled STATE.md to 10/11 plans, 91%, Plan 07 complete, and Plan 08 next.
- **Files modified:** `.planning/STATE.md`
- **Verification:** STATE.md and ROADMAP.md both report seven of eight Phase 09 plans complete.
- **Committed in:** Final documentation commit

---

**Total deviations:** 3 auto-fixed (1 security, 1 blocking, 1 tracking bug)
**Impact on plan:** Both changes strengthen the mandatory evaluator boundary and preserve the frozen protocol without scope expansion.

## Issues Encountered

- The full promotion file contains multiple checksum validations of the 3,960-row score-support audit. Verification was split into canonical validation, tamper validation, and lightweight gate runs to stay within the command execution window; every assertion group passed.

## User Setup Required

None - no external service configuration required.

## Known Stubs

None.

## Next Phase Readiness

- Plan 09-08 can regenerate and audit the canonical benchmark bundle with evaluator-derived promotion decisions.
- No implementation blockers remain. The existing published bundle still contains its pre-09-07 decision schema until the planned regeneration step.

## Self-Check: PASSED

All four modified files, this summary, and task commits `9f99f25`, `deacb09`, `14ea646`, and `7bbfc9d` were verified on disk.

---
*Phase: 09-rolling-tournament-benchmark-harness*
*Completed: 2026-07-21*
