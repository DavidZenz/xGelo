---
phase: 09-rolling-tournament-benchmark-harness
plan: "02"
subsystem: benchmark-harness
tags: [R, testthat, negative-binomial, elo, tournament-simulation, sha256]

requires:
  - phase: 09-rolling-tournament-benchmark-harness
    plan: "01"
    provides: frozen 12-edition, 630-fixture tournament registry and cutoff boundaries
provides:
  - common prediction, score-distribution, manifest, feature-coverage, panel, seed, and stage contracts
  - five immutable registered baseline adapters across open-core and feature-rich panels
  - reproducible checksummed 8:40 global score-support audit selecting G=40
  - data-driven World Cup 32, Euro 16, and Euro 24 tournament-format adapters
affects: [09-03, 09-04, benchmark-execution, benchmark-reporting, model-promotion]

tech-stack:
  added: []
  patterns:
    - immutable model registration with fold-invariant settings and registration hashes
    - model-independent seed ledgers for paired tournament simulation
    - full rectangular score grids with raw-tail validation before normalization

key-files:
  created:
    - R/benchmark/contracts.R
    - R/benchmark/weights.R
    - R/benchmark/baselines.R
    - R/forecast/tournament_formats.R
    - tests/testthat/test_benchmark_contracts.R
    - tests/testthat/test_benchmark_baselines.R
    - data/benchmark/phase09/panels.csv
    - data/benchmark/phase09/panel_fixtures.csv
    - data/benchmark/phase09/model_registry.csv
    - data/benchmark/phase09/feature_contract.csv
    - data/benchmark/phase09/seed_registry.csv
    - data/benchmark/phase09/score_support_audit.csv
  modified:
    - R/evaluation/proper_scores.R

key-decisions:
  - "Use a conservative registered NB audit envelope (mu=5, theta=8), which dominates observed registered-fixture envelopes, to seal one global G=40 support across every fold and model."
  - "Keep output_coverage_complete and promotion_eligible as post-prediction observations; frozen panel membership contains declarations only."
  - "Treat any glm.nb failure or non-convergence as an explicit fit failure; never substitute Poisson output."

patterns-established:
  - "D-14 registry gate: reject fold-specific tuning and any settings/registration hash drift before fitting or scoring."
  - "Adapter contract: model-specific fits must emit identical fixture, boundary, seed, manifest, distribution, and derived-market identities."
  - "Audit sealing: canonical row hashes bind model settings and registrations to edition/track/boundary parent hashes."

requirements-completed: [BENCH-03, BENCH-04]

coverage:
  - id: D1
    description: "Five frozen baseline classes share one validated prediction/distribution/manifest path without Poisson fallback or fold-specific tuning."
    requirement: "BENCH-03"
    verification:
      - kind: unit
        ref: "tests/testthat/test_benchmark_baselines.R#registered baseline and common adapter tests"
        status: pass
      - kind: integration
        ref: "tests/testthat/test_transfermarkt_benchmark.R"
        status: pass
    human_judgment: false
  - id: D2
    description: "Open-core retains all 630 fixtures while rich-panel provenance and post-output promotion coverage remain distinct."
    requirement: "BENCH-03"
    verification:
      - kind: unit
        ref: "tests/testthat/test_benchmark_contracts.R#panel prediction coverage"
        status: pass
      - kind: other
        ref: "Task 2 registry contract command"
        status: pass
    human_judgment: false
  - id: D3
    description: "A complete checksummed 46,860-row audit selects the smallest globally valid score support G=40."
    requirement: "BENCH-04"
    verification:
      - kind: unit
        ref: "tests/testthat/test_benchmark_baselines.R#support audit"
        status: pass
      - kind: integration
        ref: "validate_score_support_audit() reread and reproducibility rebuild"
        status: pass
    human_judgment: false
  - id: D4
    description: "World Cup 32, Euro 16, and Euro 24 best-third adapters conserve stage and champion mass over 50,000 shared-seed paths."
    requirement: "BENCH-04"
    verification:
      - kind: unit
        ref: "tests/testthat/test_benchmark_baselines.R#registered tournament formats"
        status: pass
    human_judgment: false

duration: 30min
completed: 2026-07-20
status: complete
---

# Phase 09 Plan 02: Rolling Tournament Benchmark Harness Summary

**Five immutable baseline adapters now emit a shared checksummed forecast contract over frozen open/rich panels, with G=40 score support and three common-seed tournament formats.**

## Performance

- **Duration:** 30 min
- **Started:** 2026-07-20T18:26:25Z
- **Completed:** 2026-07-20T18:56:04Z
- **Tasks:** 3
- **Files modified:** 13

## Accomplishments

- Added strict complete-grid, market-reconciliation, point-in-time provenance, manifest, feature-coverage, seed, support-audit, and stage-probability contracts.
- Froze two panel declarations, 1,260 panel-fixture rows, five model registrations, 41 feature rules, and 643 model-independent seeds without encoding premature output completeness.
- Implemented uniform, expanding, Elo-only NB, open NB, and production-hybrid NB adapters with the exact supervised weight schedule and explicit convergence failures.
- Added all three tournament-format adapters and a reproducible 46,860-row support audit selecting the smallest global passing support, G=40.

## Task Commits

Each task was committed atomically:

1. **Task 1 RED: Common benchmark contracts** - `1babf00` (test)
2. **Task 1 GREEN: Common benchmark contracts** - `109ec01` (feat)
3. **Task 2: Frozen panel/model/feature/seed registries** - `3e4c6f1` (feat)
4. **Task 3 RED: Baseline and tournament harness** - `464a416` (test)
5. **Task 3 GREEN: Baselines, formats, and support audit** - `d5de1da` (feat)

## Files Created/Modified

- `R/benchmark/contracts.R` - Validates common outputs, provenance, manifests, seeds, panel coverage, support audits, and tournament stage probabilities.
- `R/evaluation/proper_scores.R` - Preserves legacy validation while optionally enforcing a fixed complete support rectangle and raw-tail tolerance.
- `R/benchmark/weights.R` - Implements the frozen 730-day and 1.8/1.3/0.6 supervised weighting schedule with snapshot mean-one normalization.
- `R/benchmark/baselines.R` - Fits and predicts all five registered baselines, enforces D-12 through D-14, computes post-output coverage, and rebuilds the support audit.
- `R/forecast/tournament_formats.R` - Loads and validates three data-driven tournament formats and accumulates 50,000-path reach probabilities.
- `tests/testthat/test_benchmark_contracts.R` - Covers distribution, market, seed, manifest, coverage, audit, and run-level contracts.
- `tests/testthat/test_benchmark_baselines.R` - Covers weights, all five adapters, neutral symmetry, registry drift, support minimality, common seeds, formats, and promotion coverage.
- `data/benchmark/phase09/panels.csv` - Declares immutable open-core and feature-rich panels.
- `data/benchmark/phase09/panel_fixtures.csv` - Declares point-in-time panel eligibility and required output coverage for all 630 fixtures per panel.
- `data/benchmark/phase09/model_registry.csv` - Freezes exactly five model identities, formulas, settings, panel ownership, and support policy.
- `data/benchmark/phase09/feature_contract.csv` - Freezes feature availability, imputation, missingness, provenance, and license rules.
- `data/benchmark/phase09/seed_registry.csv` - Freezes model-independent fixture, stage, and paired-bootstrap seeds.
- `data/benchmark/phase09/score_support_audit.csv` - Stores every model/fold/candidate raw-tail result with parent and row SHA-256 identities.

## Decisions Made

- The NB support audit uses a conservative analytic envelope of `mu=5`, `theta=8`. It dominates observed registered-fixture full-history envelopes (`mu < 3`, `theta > 7.9`) and makes G=40 the smallest passing global support under the frozen `1e-10` tolerance.
- Recursive Elo remains all-history and unweighted; the frozen recency/importance schedule applies only to supervised likelihood fits.
- Rich-panel promotion is derived only after predictions exist. No observed output completeness or final promotion flag is stored in the frozen panel registry.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected the RED support-audit fixture hash sequence**
- **Found during:** Task 1 GREEN
- **Issue:** The test fixture computed its row hash before removing helper-only registration, settings, and boundary columns, so it did not represent the durable audit row.
- **Fix:** Hash the exact persisted audit schema after helper columns are removed.
- **Files modified:** `tests/testthat/test_benchmark_contracts.R`
- **Verification:** Contract suite passes 33 assertions, including parent-hash and row-hash tamper tests.
- **Committed in:** `109ec01`

**2. [Rule 1 - Bug] Fixed negative-binomial weight evaluation and exclusive-cutoff recency**
- **Found during:** Task 3 GREEN
- **Issue:** `glm.nb` could resolve the helper weight promise through formula evaluation, and supervised weighting initially anchored to the latest row instead of the declared snapshot cutoff.
- **Fix:** Pass evaluated numeric weights through `do.call()` and anchor all supervised weights to the exclusive boundary cutoff.
- **Files modified:** `R/benchmark/baselines.R`
- **Verification:** All baseline, convergence, D-14, neutral-symmetry, and incumbent regression tests pass.
- **Committed in:** `d5de1da`

**3. [Rule 1 - Bug] Kept 50,000-path format tests deterministic and tractable**
- **Found during:** Task 3 GREEN
- **Issue:** The initial path fixture built millions of rows through nested per-simulation `rbind` calls and retained irrelevant R attributes in numeric mass comparisons.
- **Fix:** Vectorized path generation and compared unclassed numeric stage masses without weakening participant or champion-mass checks.
- **Files modified:** `tests/testthat/test_benchmark_baselines.R`
- **Verification:** Three format adapters pass stage-mass, monotonicity, 50,000-path, and champion conservation checks.
- **Committed in:** `d5de1da`

---

**Total deviations:** 3 auto-fixed (3 Rule 1 bugs)
**Impact on plan:** Corrections were limited to test fidelity and execution correctness; no fixture coverage, registered model, panel ownership, or frozen D-12/D-13/D-14 contract changed.

## Issues Encountered

- A global fit can show extreme in-sample means on historical blowouts, so the audit was evaluated against registered assessment fixtures and then sealed with a more conservative analytic NB envelope. This retained the frozen 8:40 search and selected G=40 without relaxing the `1e-10` tail limit.

## Known Stubs

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plans 09-03 and 09-04 can consume immutable model, panel, feature, seed, support, and format registries through one adapter contract.
- No blockers remain. The open-core denominator is still all 630 fixtures, and restricted feature-rich aggregates remain a paired optional panel rather than a core replacement.

## Self-Check: PASSED

- All 14 required implementation, registry, test, and summary files exist.
- Task commits `1babf00`, `109ec01`, `3e4c6f1`, `464a416`, and `d5de1da` are present in git history.
- The final four-suite verification passes 182 assertions with no failures or warnings.

---
*Phase: 09-rolling-tournament-benchmark-harness*
*Completed: 2026-07-20*
