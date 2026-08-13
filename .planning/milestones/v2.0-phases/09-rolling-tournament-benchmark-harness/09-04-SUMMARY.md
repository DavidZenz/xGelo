---
phase: 09-rolling-tournament-benchmark-harness
plan: "04"
subsystem: benchmark-pipeline
tags: [r, targets, testthat, negative-binomial, sha256, reproducibility]

requires:
  - phase: 09-rolling-tournament-benchmark-harness
    provides: frozen registries, leakage-safe boundaries, baseline adapters, scoring, and promotion protocol
provides:
  - Cache-only Phase 9 targets DAG isolated from dashboard publication
  - Reconciled 12-edition, five-model, two-track canonical benchmark bundle
  - Deterministic two-pass content identity with complete parent checksum lineage
affects: [phase-10-challengers, phase-11-hybrid-models, phase-12-promotion]

tech-stack:
  added: []
  patterns: [two-worker model-track execution, staged atomic publication, persisted-file SHA-256 reconciliation]

key-files:
  created:
    - outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen/
  modified:
    - R/benchmark/runner.R
    - R/benchmark/baselines.R
    - R/evaluation/benchmark_scores.R
    - tests/testthat/test_benchmark_pipeline.R
    - _targets.R

key-decisions:
  - "Use two independent model-track workers after the worst-case Euro 2024 production-hybrid fit measured 4.935 seconds."
  - "Preserve every completed-matchday refit, frozen formula, hyperparameter, seed, and G=40 support while optimizing execution and hashing only."
  - "Hash sorted persisted CSVs and parent every output to the complete frozen registry/protocol graph."

patterns-established:
  - "Canonical benchmark publication is staged and installed only after reversed-order rerun hashes match."
  - "Independent acceptance checks stream external SHA-256 and row counts one artifact at a time."

requirements-completed: [BENCH-01, BENCH-02, BENCH-03, BENCH-04, BENCH-05]

coverage:
  - id: D1
    description: "Cache-only rolling tournament runner and isolated targets DAG"
    requirement: BENCH-01
    verification:
      - kind: integration
        ref: "tests/testthat/test_benchmark_pipeline.R; targets::tar_manifest()"
        status: pass
    human_judgment: false
  - id: D2
    description: "WC2026 outcomes remain sealed and Phase 8/dashboard artifacts remain unchanged"
    requirement: BENCH-02
    verification:
      - kind: integration
        ref: "tests/testthat/test_benchmark_seal.R; git diff --quiet HEAD -- outputs/dashboard outputs/evaluation/wc2026"
        status: pass
    human_judgment: false
  - id: D3
    description: "Complete predictions, distributions, manifests, coverage, seeds, and parent checksums"
    requirement: BENCH-03
    verification:
      - kind: e2e
        ref: "validate_rolling_benchmark_bundle('outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen')"
        status: pass
    human_judgment: false
  - id: D4
    description: "All five registered baseline classes execute on 630 fixtures across frozen and updating tracks"
    requirement: BENCH-04
    verification:
      - kind: e2e
        ref: "canonical artifact inventory: 6,300 predictions and 1,420 fit manifests"
        status: pass
    human_judgment: false
  - id: D5
    description: "Proper scores, paired comparisons, promotion decisions, and deterministic rerun identity reconcile"
    requirement: BENCH-05
    verification:
      - kind: e2e
        ref: "external streaming SHA-256 audit plus full testthat suite"
        status: pass
    human_judgment: false

duration: 1h 12m
completed: 2026-07-21
status: complete
---

# Phase 09 Plan 04: Sealed Baseline Benchmark Bundle Summary

**Offline 12-edition benchmark bundle with five frozen baselines, 10.59 million G=40 score cells, complete checksum lineage, and exact reversed-order reproducibility**

## Performance

- **Duration:** 1h 12m
- **Started:** 2026-07-21T04:36:04Z
- **Completed:** 2026-07-21T05:48:00Z
- **Tasks:** 3
- **Files modified:** 16
- **Canonical two-pass runtime:** 3,483.751 seconds
- **Worst-case diagnostic:** 4.935 seconds for the latest Euro 2024 production-hybrid home+away fit on 47,473 eligible rows

## Accomplishments

- Added a cache-only runner and an eight-target Phase 9 DAG that does not feed dashboard or Phase 8 publication targets.
- Published all 12 registered tournaments, five baseline classes, and both tracks as 6,300 fixture predictions, 10,590,300 normalized score cells, 1,420 fit manifests, and 7,560 stage-probability rows.
- Reconciled all 25 checksum-manifest entries, the complete frozen input-parent graph, observed rich-panel output coverage, promotion decisions, and a reversed-order deterministic rerun.
- Confirmed all 11 focused suites and the full repository suite pass with true failure exits and no warnings.

## Task Commits

Each task was committed atomically:

1. **Task 1: Cache-only benchmark runner** - `0eb0a7a` (test), `3894154` (feat)
2. **Task 2: Isolated Phase 9 targets DAG** - `8100a72` (test), `ad8b618` (feat)
3. **Task 3: Produce and reconcile the sealed bundle** - `1f5e2ee` (perf), `cd95122` (fix), `dcbe51d` (feat)

## Files Created/Modified

- `R/benchmark/runner.R` - Offline orchestration, staged publication, full parent graph, reproducibility, and default-path validation.
- `R/benchmark/baselines.R` - Per-fixture market derivation without repeated bound-grid scans.
- `R/evaluation/benchmark_scores.R` - Indexed score-distribution lookup during fixture scoring.
- `_targets.R` - Eight isolated Phase 9 registry-to-bundle targets.
- `tests/testthat/test_benchmark_pipeline.R` - Pipeline, checksum, performance-regression, sealing, and DAG contracts.
- `outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen/` - Eleven-file sealed canonical bundle.

## Decisions Made

- The 4.935-second worst-case fit made a complete replay feasible with two workers; no statistical semantics needed to change.
- Parallelism is limited to independent model-track jobs. Every matchday boundary still refits from strictly prior completed evidence with the frozen formulas and hyperparameters.
- Canonical output identity uses sorted persisted CSV hashes, while runtime-only metadata remains outside content identity.
- Bundle output parents include every registry, the score-support audit, and the promotion protocol rather than only model/boundary/audit inputs.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Bounded the compute- and scan-heavy canonical replay**
- **Found during:** Task 3 (Produce and reconcile the sealed baseline benchmark bundle)
- **Issue:** The original serial execution repeatedly scanned complete grids and performed row-wise canonical hashing, making the required double replay impractical.
- **Fix:** Added two-worker model-track execution, per-fixture market derivation, indexed scoring, persisted-file hashes, garbage collection between passes, and staged publication.
- **Files modified:** `R/benchmark/runner.R`, `R/benchmark/baselines.R`, `R/evaluation/benchmark_scores.R`, `tests/testthat/test_benchmark_pipeline.R`
- **Verification:** 28 focused expectations passed before the long run; the canonical double replay completed in 58.1 minutes with identical hashes.
- **Committed in:** `1f5e2ee`

**2. [Rule 1 - Bug] Normalized default validator parent inputs**
- **Found during:** Task 3 independent post-run validation
- **Issue:** The default validator read `model_registry.csv` directly and hashed schema version `1`, while execution normalized it to `1.0`, causing a false checksum-parent mismatch.
- **Fix:** Default validation now loads model and support registries through `benchmark_runner_load_inputs()`.
- **Files modified:** `R/benchmark/runner.R`, `tests/testthat/test_benchmark_pipeline.R`
- **Verification:** 31 focused expectations and the exact default-path bundle acceptance command passed.
- **Committed in:** `cd95122`

---

**Total deviations:** 2 auto-fixed (1 blocking issue, 1 correctness bug).
**Impact on plan:** Both changes preserve the frozen statistical contract and were required to complete and independently validate the canonical bundle.

## Issues Encountered

- The first canonical attempt before this continuation was interrupted while repeatedly fitting `MASS::glm.nb`. The approved one-fit diagnostic measured the true worst case and justified the bounded two-worker replay.
- The canonical bundle is 962 MiB because the registered contract retains every cell in 6,300 complete 41×41 score grids.

## Authentication Gates

None.

## Known Stubs

None. Empty failure/reason fields are intentional successful-output values, not unresolved implementation placeholders.

## Verification

- `targets::tar_manifest()` loaded and contained all eight isolated Phase 9 targets.
- Eleven focused benchmark, legacy EURO, World Cup scoring, and retrospective suites passed.
- Full `tests/testthat` suite passed with zero failures and zero warnings.
- Fresh default-path bundle validation passed: 12 editions, 630 core fixtures, five models, `G=40`, 11 artifacts, reproducible, sealed, and network-free.
- External `/usr/bin/shasum -a 256` and streaming line counts matched all 10 durable output rows in `checksum_manifest.csv`; the recomputed parent graph was `df0a510ceb1a2cfde2366b679eeac5018d76c5b3701ddcd5cbc0c154a49d6138`.
- Phase 8 and dashboard tracked artifacts had no git diff before or after execution.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 10 can evaluate statistical challengers against the immutable open-core and production-hybrid baseline bundle.
- The complete score grids, coverage evidence, scoring summaries, paired comparisons, and frozen decisions are available without network access.
- No blockers remain.

## Self-Check: PASSED

- All 11 canonical bundle files exist and validate.
- All seven Task 1-3 commits exist in git history.
- Summary claims match fresh acceptance, streaming checksum, focused-suite, full-suite, and protected-path checks.

---
*Phase: 09-rolling-tournament-benchmark-harness*
*Completed: 2026-07-21*
