---
phase: 10-statistical-goal-model-challengers
plan: "07"
subsystem: statistical-forecasting
tags: [r, targets, challenger-selection, reproducibility, checksums, atomic-publication]

requires:
  - phase: 09-rolling-tournament-benchmark-harness
    provides: Immutable five-baseline scores, exact 630/609 comparison panels, common scoring contracts, parent hashes, and atomic staged installation
  - phase: 10-statistical-goal-model-challengers
    provides: Canonical Phase 10 protocol, seven registered candidate adapters, environment provenance, storage preflight, tuning evidence, and ablation services from Plans 10-02 through 10-06 and 10-09 through 10-11
provides:
  - Exact seven-candidate by five-baseline by two-track research comparison evidence over all 12 editions
  - Deterministic three-slot non-exclusive research shortlist with dependence, simplicity, and proper-score representatives
  - Order-reconciled checksummed bundle writer with pre/post validation and atomic rollback
  - Six downstream-only targets with explicit local Phase 9 and Phase 10 file parents
affects: [10-08, STAT-01, STAT-02, STAT-03, STAT-04, phase12-model-release]

tech-stack:
  added: []
  patterns: [explicit-panel-pairing, research-only-selection, normal-reversed-reconciliation, self-checksummed-bundle, validated-atomic-install, file-oriented-target-parents]

key-files:
  created:
    - R/evaluation/challenger_selection.R
    - R/benchmark/challenger_runner.R
    - .planning/phases/10-statistical-goal-model-challengers/10-07-SUMMARY.md
  modified:
    - _targets.R
    - tests/testthat/test_statistical_selection.R
    - tests/testthat/test_statistical_bundle.R
    - tests/testthat/test_statistical_targets.R

key-decisions:
  - "Pair every candidate with all five immutable Phase 9 baselines only after exact eligible fixture-ID projection; use 630 open-core fixtures and 609 feature-rich fixtures on both tracks."
  - "Keep the three shortlist slots non-exclusive and research-only; no release authority or final-holdout evaluator enters Phase 10 artifacts or targets."
  - "Require normal/reversed execution hash reconciliation before writing a unique staged bundle, then use the inherited validated install-and-rollback boundary."
  - "Track durable Phase 9 outputs and Phase 10 protocol/provenance files directly so the six-target chain has no upstream collection or product-output ancestor."

patterns-established:
  - "Every persisted Phase 10 artifact is canonically written, byte/row counted, SHA-256 checked, linked to the accepted Phase 9 parent, and covered by a checksum self-hash."
  - "Smoke validation checks control-plane trust facts and one G=40 grid per candidate; deep validation adds complete comparison and score-grid reconstruction."

requirements-completed: [STAT-01, STAT-02, STAT-03, STAT-04]

coverage:
  - id: D1
    description: Every registered candidate is paired with all five frozen baselines on both tracks and the exact 630/609 eligible fixture sets across 12 editions.
    requirement: STAT-01
    verification:
      - kind: integration
        ref: tests/testthat/test_statistical_selection.R (29 expectations) and tests/testthat/test_benchmark_scoring.R (47 expectations)
        status: pass
    human_judgment: false
  - id: D2
    description: Dependence selection and the three frozen shortlist slots are deterministic, evidence-linked, non-exclusive, and research-only.
    requirement: STAT-03
    verification:
      - kind: unit
        ref: tests/testthat/test_statistical_selection.R dependence and shortlist boundaries
        status: pass
    human_judgment: false
  - id: D3
    description: Normal/reversed synthetic execution round-trips through checksums and atomic publication while rejecting tampering and preserving the accepted bundle after failed replacement.
    requirement: STAT-04
    verification:
      - kind: integration
        ref: tests/testthat/test_statistical_bundle.R (34 expectations)
        status: pass
    human_judgment: false
  - id: D4
    description: Six explicit Phase 10 targets form a downstream-only local dependency chain without protected product, collection, sealed-outcome, or release-decision ancestors.
    requirement: STAT-02
    verification:
      - kind: integration
        ref: tests/testthat/test_statistical_targets.R (37 expectations) and targets::tar_manifest() (6/6 nodes)
        status: pass
    human_judgment: false

duration: 26 min
completed: 2026-07-22
status: complete
---

# Phase 10 Plan 07: Statistical Challenger Evidence Graph and Runner Summary

**Exact all-baseline evidence, a frozen research shortlist, order-reconciled atomic bundles, and six isolated targets now connect all seven statistical challengers to the immutable Phase 9 benchmark without crossing the Phase 12 decision boundary.**

## Performance

- **Duration:** 26 min
- **Started:** 2026-07-22T19:22:51Z
- **Completed:** 2026-07-22T19:48:48Z
- **Tasks:** 3
- **Product/test files modified:** 6

## Accomplishments

- Built all 70 candidate/baseline/track identities (7 × 5 × 2), requiring exact 630-fixture open-core and 609-fixture feature-rich sets and retaining 12-fold, headline, pooled, bootstrap, breadth, maximum-regression, and leave-one-tournament-out diagnostics.
- Implemented the frozen dependence rule and three non-exclusive shortlist slots: best updating equal-tournament proper score, simplest practically non-inferior active set, and registered dependence representative.
- Added immutable Phase 9 reconstruction, strict sealed-label rejection, normal/reversed execution reconciliation, canonical artifact writing, checksum self-validation, and inherited atomic install/rollback.
- Added fast smoke and deep validators with exact parent, candidate, edition, G=40, comparison, shortlist, boundary, byte-count, and row-count acceptance facts.
- Registered six file-oriented Phase 10 targets whose ancestry is explicit, local, downstream-only, and inspectable without executing the historical benchmark.

## Task Commits

Each implementation task was committed atomically after its warning-fatal gate passed:

1. **Task 1: Build exact candidate-by-five-baseline evidence and research shortlist** — `7036b7d` (feat)
2. **Task 2: Implement cache-only orchestration and atomic bundle validation** — `a409fb6` (feat)
3. **Task 3: Register isolated Phase 10 targets and expensive phase gates** — `40667db` (feat)
4. **Plan-boundary contract hardening** — `c088856` (fix)

The Wave 0 RED contracts were previously committed by Plan 10-11 in `7b1d32e`.

## Files Created/Modified

- `R/evaluation/challenger_selection.R` — Exact all-baseline pairing, dependence representative, and deterministic three-slot research shortlist.
- `R/benchmark/challenger_runner.R` — Parent loading, purpose guarding, candidate orchestration, order reconciliation, canonical paths, checksums, staged publication, smoke validation, and deep validation.
- `_targets.R` — Phase 10 module loading and six explicit downstream-only targets.
- `tests/testthat/test_statistical_selection.R` — 7 × 5 × 2 exact-panel, dependence threshold/veto, and shortlist contracts.
- `tests/testthat/test_statistical_bundle.R` — Parent identity, sealed-label callback, source boundary, reproducibility, round-trip, corruption, and rollback contracts.
- `tests/testthat/test_statistical_targets.R` — Manifest names, ordering, ancestry, invalidation-parent, and module-source-order contracts.

## Decisions Made

- Phase 9 durable outputs are opened only through checksum-validated read paths. They are not copied, regenerated, or mutated.
- The richer baseline denominator is the 609 eligible `feature_rich` fixtures, not all 630 registry rows; every comparison verifies candidate/baseline fixture-ID equality before pairing.
- Dixon-Coles wins a practical tie between valid dependence corrections, but the independent mean remains preferred when the selected correction misses the frozen -0.001 meaningful-gain threshold.
- Synthetic runs use the same checksum and inherited atomic installation boundary as canonical runs so task-level tests exercise publication behavior without starting the expensive benchmark.
- Historical execution remains behind `benchmark_phase10_bundle_files`; manifest inspection constructs the graph but performs no model fitting.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Counted eligible feature-rich fixtures rather than registry rows**

- **Found during:** Task 2 immutable parent reconstruction.
- **Issue:** The feature-rich registry has 630 rows but exactly 609 eligible comparison fixtures.
- **Fix:** Applied the frozen `eligible` projection before reconstructing the 609 denominator.
- **Files modified:** `R/benchmark/challenger_runner.R`
- **Verification:** Parent reconstruction returns exactly 630 open and 609 rich fixtures.
- **Committed in:** `a409fb6`

**2. [Rule 2 - Missing Critical] Rejected outcome-like sealed labels before environment loading or callback execution**

- **Found during:** Task 2 sealed-input callback test.
- **Issue:** The inherited purpose guard did not classify generic `home_goals`/`away_goals` names, allowing environment validation to begin before rejection.
- **Fix:** Added a fail-closed holdout outcome-column check immediately after the shared guard and before preflight, parent loading, or engine invocation.
- **Files modified:** `R/benchmark/challenger_runner.R`
- **Verification:** The callback count remains zero and the sealed-label error is raised first.
- **Committed in:** `a409fb6`

**3. [Rule 1 - Bug] Made checksum self-hashes stable across CSV type reconstruction and preserved shortlist order**

- **Found during:** Task 2 synthetic bundle round-trip.
- **Issue:** Serialization-sensitive column types changed after CSV read-back, and generic row sorting changed the frozen shortlist slot order.
- **Fix:** Canonicalized checksum tables through textual values and preserved the declared three-slot order when writing the shortlist.
- **Files modified:** `R/benchmark/challenger_runner.R`
- **Verification:** Synthetic bundles prevalidate, install, postvalidate, and deep-validate successfully.
- **Committed in:** `a409fb6`

**4. [Rule 2 - Missing Critical] Completed durable acceptance facts required by the approved phase validator**

- **Found during:** Final validation-contract audit.
- **Issue:** The validator proved but did not return 12-edition, decision-boundary, and target-isolation acceptance facts; persisted row/byte declarations were not independently compared.
- **Fix:** Added the three acceptance outputs and fail-closed row/byte, parent, and research-schema checks.
- **Files modified:** `R/benchmark/challenger_runner.R`, `tests/testthat/test_statistical_bundle.R`
- **Verification:** Bundle suite passes 34 expectations with warnings fatal.
- **Committed in:** `c088856`

---

**Total deviations:** 4 auto-fixed (2 Rule 1 bugs, 2 Rule 2 missing critical checks).
**Impact on plan:** The fixes enforce the frozen denominator, sealed-data, deterministic persistence, and downstream acceptance contracts without adding model, data, or governance scope.

## Issues Encountered

None beyond the auto-fixed correctness issues above.

## Verification Results

- `test_statistical_selection.R`: 4 tests, 29 expectations passed.
- `test_statistical_bundle.R`: 7 tests, 34 expectations passed.
- `test_statistical_targets.R`: 5 tests, 37 expectations passed.
- `test_benchmark_contracts.R`: 13 tests, 62 expectations passed.
- `test_benchmark_cutoffs.R`: 4 tests, 11 expectations passed.
- `test_benchmark_scoring.R`: 8 tests, 47 expectations passed.
- `test_benchmark_pipeline.R`: 20 tests, 83 expectations passed.
- `test_benchmark_seal.R`: 3 tests, 18 expectations passed.
- **Combined:** 64 tests and 321 expectations; zero failures, warnings, or errors with warnings fatal.
- `targets::tar_manifest()`: all 6/6 exact Phase 10 nodes present; no historical benchmark executed.
- Static boundary scan: no forbidden evaluator call, decision artifact, protected product mutation, network collection, or raw 2026 outcome path in either new Phase 10 source file.
- `git diff --check`: passed.

## TDD Gate Compliance

- Wave 0 RED contract: `7b1d32e`.
- Task 1 RED failed only on the four missing selection APIs; GREEN commit: `7036b7d`.
- Task 2 RED failed only on the six missing runner/publication APIs; GREEN commit: `a409fb6`.
- Task 3 RED failed only on the six missing target names; GREEN commit: `40667db`.
- Plan-boundary RED exposed three missing validator return facts; GREEN fix: `c088856`.
- Every final owning and inherited suite passed with `stop_on_failure = TRUE` and `stop_on_warning = TRUE`.

## Known Stubs

None. Nullable arguments and empty-string CSV encodings are control/default values, not unwired UI or placeholder data. The expensive canonical 12-tournament execution is intentionally reserved for Plan 10-08.

## Threat Flags

None. The new file-read and staged-publication surfaces are the planned T-10-20 through T-10-23 trust boundaries and are covered by exact parent, panel, checksum, rollback, sealed-input, and ancestry tests.

## User Setup Required

None - no external service configuration, package installation, or network access was added.

## Next Phase Readiness

- Plan 10-08 can execute and independently accept the canonical 12-tournament normal/reversed bundle through the six-target chain.
- Phase 12 can consume the three research slots and linked evidence without any Phase 10 release decision.
- No canonical historical benchmark was started by this plan.

## Self-Check: PASSED

- Verified all six plan-owned product/test files and this summary exist on disk.
- Verified task/fix commits `7036b7d`, `a409fb6`, `40667db`, and `c088856` resolve in Git history and contain no deletions.
- Re-ran all eight required warning-fatal suites for 64 tests / 321 expectations with zero failures, warnings, or errors.
- Confirmed all six exact target nodes load without executing the historical benchmark.
- Confirmed `STATE.md`, `ROADMAP.md`, Phase 9 durable outputs, protected outputs, and every unrelated user-owned working-tree change remain untouched and unstaged.

---
*Phase: 10-statistical-goal-model-challengers*
*Completed: 2026-07-22*
