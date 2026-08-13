---
phase: 09-rolling-tournament-benchmark-harness
plan: "05"
subsystem: benchmark-evidence
tags: [r, provenance, point-in-time, feature-coverage, tdd]
requires:
  - phase: 09-04
    provides: sealed baseline adapters, frozen registries, and benchmark bundle contracts
provides:
  - producer-captured pre-imputation evidence for every registered source-backed feature
  - deterministic prediction-to-feature-coverage foreign keys
  - strict cutoff, imputation, provenance, license, and contract-hash validation
affects: [09-06, benchmark-runner, forecast-feature-producer]
tech-stack:
  added: []
  patterns:
    - strict latest-before lookups return value and evidence together
    - adapter coverage expands predictions over exact registered panel features
    - derived fixture evidence is explicit and never receives a fabricated source date
key-files:
  created: []
  modified:
    - R/forecast/features.R
    - R/forecast/goal_ability.R
    - R/benchmark/contracts.R
    - R/benchmark/baselines.R
    - R/benchmark/runner.R
    - _targets.R
    - data/processed/goal_training_features_hybrid.csv
    - tests/testthat/test_transfermarkt_benchmark.R
    - tests/testthat/test_benchmark_baselines.R
    - tests/testthat/test_benchmark_contracts.R
key-decisions:
  - Preserve source-row presence separately from numeric value presence so observed zero cannot collapse into missing-then-zero.
  - Hash feature coverage IDs from run, model, track, boundary, and fixture identity.
  - Represent venue advantage as checked fixture-derived evidence without fabricating a historical source date.
requirements-completed: [BENCH-03]
coverage:
  - id: D1
    description: Canonical forecast features retain actual latest source dates and pre-imputation evidence companions.
    requirement: BENCH-03
    verification:
      - kind: integration
        ref: tests/testthat/test_transfermarkt_benchmark.R#forecast producer retains match keys and per-feature evidence companions
        status: pass
      - kind: integration
        ref: canonical 49520-row goal_training_features_hybrid.csv chunk validation
        status: pass
    human_judgment: false
  - id: D2
    description: Every adapter prediction links to an exact registered runtime feature group.
    requirement: BENCH-03
    verification:
      - kind: integration
        ref: tests/testthat/test_benchmark_baselines.R#adapter emits exact deterministic feature coverage groups
        status: pass
      - kind: unit
        ref: tests/testthat/test_benchmark_baselines.R#feature coverage rejects key, cutoff, imputation, provenance, and link drift
        status: pass
    human_judgment: false
  - id: D3
    description: Runner preparation preserves producer evidence before applying registered numeric defaults.
    requirement: BENCH-03
    verification:
      - kind: unit
        ref: tests/testthat/test_benchmark_baselines.R#runner preserves producer evidence before applying numeric defaults
        status: pass
      - kind: integration
        ref: tests/testthat/test_benchmark_pipeline.R
        status: pass
    human_judgment: false
metrics:
  duration: 35min
  completed: 2026-07-21
status: complete
---

# Phase 09 Plan 05: Runtime Feature Evidence Summary

**Producer-captured pre-imputation provenance with deterministic, validated prediction-to-feature coverage links for every registered baseline adapter.**

## Performance

- **Duration:** 35 min
- **Started:** 2026-07-21T08:48:25Z
- **Completed:** 2026-07-21T09:23:41Z
- **Tasks:** 2
- **Files modified:** 10

## Accomplishments

- Rebuilt the 49,520-row canonical hybrid training feature artifact with 260 columns, including actual source dates and five evidence companions per source-backed feature.
- Added deterministic feature coverage IDs and exact model-panel feature expansion at adapter return.
- Enforced fail-fast prediction links, strict cutoffs, imputation semantics, active-fit visibility, registered source hashes, feature-contract hashes, and license classes.
- Preserved producer companions through runner matching before numeric defaults are applied.

## Task Commits

Each task was committed atomically:

1. **Task 1 RED: Producer evidence regressions** - `b988c0b` (test)
2. **Task 1 GREEN: Pre-imputation producer evidence** - `1eaf7ed` (feat)
3. **Task 2 RED: Adapter coverage regressions** - `2f7ec82` (test)
4. **Task 2 GREEN: Validated adapter feature groups** - `44e7ff6` (feat)
5. **Task 2 regression compatibility: Full contract fixture** - `e432d0c` (test)

## Files Created/Modified

- `R/forecast/features.R` - Evidence-returning strict lookups, wide companions, unique match keys, and producer validation.
- `R/forecast/goal_ability.R` - Actual latest prior-result dates and observed-versus-fallback ability evidence.
- `_targets.R` - Canonical producer validation before persistence.
- `data/processed/goal_training_features_hybrid.csv` - Match-keyed values with pre-imputation evidence companions.
- `R/benchmark/baselines.R` - Deterministic group IDs, registered feature expansion, and adapter handoff.
- `R/benchmark/contracts.R` - Exact feature evidence and prediction-link validators.
- `R/benchmark/runner.R` - Companion-preserving history and fixture preparation.
- `tests/testthat/test_transfermarkt_benchmark.R` - Producer and genuine-zero regressions.
- `tests/testthat/test_benchmark_baselines.R` - Adapter evidence, drift, and foreign-key regressions.
- `tests/testthat/test_benchmark_contracts.R` - Expanded runtime coverage schema regression.

## Decisions Made

- Source-row presence and finite value presence are independent facts; a present row with a missing value retains its real date and explicit imputation reason.
- Home-away evidence is source-present only when both selected source rows exist, and its source date is their actual maximum.
- Venue advantage is marked `derived_fixture` with no invented source date; all historical source-backed features require strict prior dates.
- Coverage IDs use a SHA-256 identity over run, model, track, boundary, and fixture to prevent frozen/updating collisions.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed quadratic fixture-date scanning from goal-ability evidence**
- **Found during:** Task 1 canonical regeneration
- **Issue:** Expanding the evidence traversal to all historical dates exposed repeated full fixture scans and made regeneration impractically slow.
- **Fix:** Pre-split fixture rows by date and retained the same strict update order.
- **Files modified:** `R/forecast/goal_ability.R`
- **Verification:** Producer suite passed; all 49,520 canonical rows regenerated and validated.
- **Committed in:** `1eaf7ed`

**2. [Rule 2 - Missing Critical] Enforced deterministic unique canonical match IDs**
- **Found during:** Task 1 canonical validation
- **Issue:** Historical source IDs can repeat for same-team same-date matches, violating the required evidence primary key.
- **Fix:** Applied stable `make.unique()` suffixes before producer persistence while leaving already-unique IDs unchanged.
- **Files modified:** `R/forecast/features.R`, `_targets.R`
- **Verification:** Chunk validation rejected duplicate IDs and the final producer completed with 49,520 unique rows.
- **Committed in:** `1eaf7ed`

**3. [Rule 1 - Bug] Updated adjacent contract regression to the expanded schema**
- **Found during:** Final benchmark contract regression
- **Issue:** The existing synthetic fixture lacked the newly mandatory identity, provenance, and contract-hash columns.
- **Fix:** Extended the fixture without weakening its cutoff assertions.
- **Files modified:** `tests/testthat/test_benchmark_contracts.R`
- **Verification:** Benchmark contract and pipeline suites pass with warning propagation enabled.
- **Committed in:** `e432d0c`

---

**Total deviations:** 3 auto-fixed (2 bugs, 1 missing critical functionality).
**Impact on plan:** All changes were necessary for correctness, bounded regeneration, and the declared evidence-key contract; no Phase 10/11 models or network paths were introduced.

## Issues Encountered

- A one-object canonical rebuild exceeded practical memory/runtime limits after the evidence table widened from 54 to 260 columns. The same producer was run in validated 5,000-row chunks and atomically installed only after all ten chunks passed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 09-06 can bind `feature_coverage` directly from every adapter result without reconstructing evidence.
- Exact 630/609 panel enforcement can now use deterministic prediction foreign keys and complete runtime feature groups.
- No blockers remain.

## Self-Check: PASSED

- Verified all ten modified plan files exist.
- Verified Task commits `b988c0b`, `1eaf7ed`, `2f7ec82`, `44e7ff6`, and `e432d0c` exist in git history.
- Verified producer, adapter, contract, and pipeline suites pass with failures and warnings propagated.
- Verified benchmark modules contain no HTTP, download, or refresh calls and introduced no unregistered threat surface.

---
*Phase: 09-rolling-tournament-benchmark-harness*
*Completed: 2026-07-21*
