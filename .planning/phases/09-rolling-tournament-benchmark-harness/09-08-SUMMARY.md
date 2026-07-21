---
phase: 09-rolling-tournament-benchmark-harness
plan: "08"
subsystem: benchmark-publication
tags: [r, reproducibility, sha256, promotion, targets, acceptance]

requires:
  - phase: 09-07
    provides: Evaluator-backed promotion decisions and post-reconciliation reproducibility finalization
provides:
  - Independently reconciled normal/reversed canonical Phase 09 benchmark bundle
  - External checksum, byte, streamed-row, self-hash, and complete parent-graph acceptance
  - Full/focused regression and isolated targets-DAG evidence for the immutable bundle
affects: [phase-10, phase-11, benchmark-challengers, model-promotion]

tech-stack:
  added: []
  patterns: [staged-prevalidation, atomic-install-with-rollback, durable-numeric-evaluation, fresh-process-acceptance]

key-files:
  created: []
  modified:
    - outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen/manifests/feature_coverage.csv
    - outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen/manifests/checksum_manifest.csv
    - outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen/predictions/fixture_predictions.csv
    - outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen/predictions/score_distributions.csv
    - outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen/scores/fixture_scores.csv
    - outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen/scores/benchmark_summaries.csv
    - outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen/comparisons/paired_comparisons.csv
    - outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen/comparisons/promotion_decisions.csv
    - outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen/run_manifest.csv

key-decisions:
  - "Canonical publication validates a unique staged bundle before install and retains a rollback backup through post-install validation."
  - "Promotion decisions are evaluated from CSV-persisted numeric views so durable reconstruction and evaluator hashes cannot drift."
  - "Bundle acceptance runs in fresh Rscript processes with explicit dependency sourcing; ambient producer-session state is not evidence."

patterns-established:
  - "Seal-preserving publication: normal and reversed passes reconcile before a validated staged candidate can replace the accepted bundle."
  - "Independent acceptance: external file hashes and streamed counts verify the durable graph without trusting loaded bundle metadata."

requirements-completed: [BENCH-01, BENCH-02, BENCH-03, BENCH-04, BENCH-05]

coverage:
  - id: D1
    description: Complete normal/reversed replay publishes a content-identical, validated G=40 bundle with 6,300 linked predictions and exact 630/609 panels.
    requirement: BENCH-01
    verification:
      - kind: e2e
        ref: run_rolling_tournament_benchmark(... verify_reproducibility = TRUE, parallel_workers = 2L)
        status: pass
      - kind: integration
        ref: 09-08 Task 1 exact fresh-process acceptance command
        status: pass
    human_judgment: false
  - id: D2
    description: Every durable artifact passes external SHA-256/byte/streamed-row checks, checksum self-hash, complete parent graph, and evaluator reconstruction.
    requirement: BENCH-03
    verification:
      - kind: e2e
        ref: 09-08 Task 2 exact fail-fast external-integrity block
        status: pass
    human_judgment: false
  - id: D3
    description: Full and focused regressions pass while all eight Phase 09 targets retain required edges and exclude dashboard/WC2026 ancestry.
    requirement: BENCH-05
    verification:
      - kind: integration
        ref: testthat::test_dir("tests/testthat", stop_on_failure = TRUE, stop_on_warning = TRUE)
        status: pass
      - kind: integration
        ref: targets::tar_network(targets_only = TRUE, outdated = FALSE) edge and ancestry assertions
        status: pass
      - kind: integration
        ref: 09-08 ten-file focused regression loop
        status: pass
    human_judgment: false

duration: 1h 22m
completed: 2026-07-21
status: complete
---

# Phase 09 Plan 08: Rolling Tournament Benchmark Reseal Summary

**A seal-preserving two-pass replay produced a content-identical 6,300-prediction G=40 benchmark bundle, then passed external graph integrity, full regression, and targets-isolation acceptance.**

## Performance

- **Duration:** 1h 22m
- **Started:** 2026-07-21T18:23:17Z
- **Completed:** 2026-07-21T19:45:44Z
- **Tasks:** 2
- **Product files modified:** 9 (2 additional regenerated artifacts were byte-identical)

## Accomplishments

- Replayed all 12 registered tournaments, five baseline classes, and both frozen/updating tracks in normal and reversed model order with the fixed two-worker ceiling, common seeds, strict exclusive cutoffs, and G=40 support.
- Atomically published bundle SHA-256 `977e119dd17e1212d2bfc57da2e676b6ee9d16bfba8b6c9bdbf1a97d302db069` only after staged validation, canonical identity, durable evaluator decisions, and post-install read-back succeeded.
- Preserved 6,300 audit-visible prediction groups and 78,120 feature-evidence rows while routing score/promotion consumers through exact 630-fixture open-core and 609-fixture feature-rich panels.
- Passed external SHA-256/bytes, streamed rows, checksum self-hash, exact 15-input parent graph, score-support lineage, full/focused tests, required target edges, forbidden-ancestry checks, and protected dashboard/WC2026 diffs.

## Task Commits

Recovery and execution outcomes were committed atomically:

1. **Task 1 corrective: Preserve the seal during reconciliation** - `a845df6` (fix)
2. **Task 1 corrective: Evaluate promotion from durable numeric evidence** - `58ff288` (fix)
3. **Task 1 corrective: Make bundle validation standalone** - `03b3a1e` (fix)
4. **Task 1: Publish reconciled canonical benchmark bundle** - `15ed965` (feat)
5. **Task 2: Independent acceptance** - verification-only; no files changed and no artificial empty commit was created

## Files Created/Modified

- `manifests/feature_coverage.csv` - 78,120 feature-level evidence rows resolving exactly 6,300 prediction groups.
- `manifests/checksum_manifest.csv` - 10 output, 15 checked-input, and one self row with external bytes/hashes and complete parent graph.
- `predictions/fixture_predictions.csv` - 6,300 common-schema audit-visible predictions.
- `predictions/score_distributions.csv` - Complete 41×41 score grids under sealed G=40 support.
- `scores/fixture_scores.csv` and `scores/benchmark_summaries.csv` - Exact registered panel scoring and aggregate denominators.
- `comparisons/paired_comparisons.csv` and `comparisons/promotion_decisions.csv` - Paired diagnostics plus five evaluator-backed decisions with 159 value/pass evidence columns and nonblank failed-gate reasons.
- `run_manifest.csv` - Reproducible, WC2026-sealed, network-free run facts.

`model_manifests.csv` and `stage_probabilities.csv` were regenerated but remained byte-identical, so Git correctly recorded no change for them.

## Decisions Made

- The prior accepted seal remained authoritative until staged pre-validation and both-pass reconciliation completed; installation retained rollback protection until post-install validation passed.
- All promotion source tables were canonicalized through `benchmark_runner_persisted_view()` before evaluator invocation, making durable CSV numerics the decision authority.
- Acceptance was run from fresh `Rscript --vanilla` processes with explicit source sequences, including the standalone validator dependency path.
- D-01 through D-20, G=40, temporal cutoffs, common seeds, two workers, cache-only behavior, and the WC2026 seal were preserved without weakening.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Prevented install-before-validation from displacing the accepted seal**
- **Found during:** Task 1 recovery acceptance
- **Issue:** An earlier reconciliation path could replace the prior seal before semantic read-back validation completed.
- **Fix:** Added staged pre-validation, atomic rename, retained backup, post-install validation, and rollback restoration.
- **Files modified:** `R/benchmark/runner.R`, `tests/testthat/test_benchmark_pipeline.R`
- **Verification:** Rollback regression plus successful fresh staged canonical replay.
- **Committed in:** `a845df6`

**2. [Rule 1 - Bug] Eliminated in-memory versus persisted promotion evidence drift**
- **Found during:** Task 1 recovery acceptance
- **Issue:** Full-precision in-memory values could cross gate boundaries differently after CSV read-back and change evaluator evidence hashes.
- **Fix:** Round-tripped comparisons, coverage, summaries, and run-manifest facts through `benchmark_runner_persisted_view()` before evaluation.
- **Files modified:** `R/benchmark/runner.R`, `tests/testthat/test_benchmark_pipeline.R`
- **Verification:** Durable/reconstructed decision hashes match and the final two-pass decisions reconcile.
- **Committed in:** `58ff288`

**3. [Rule 3 - Blocking] Removed ambient-session dependency from bundle validation**
- **Found during:** Task 1 fresh-process acceptance
- **Issue:** Standalone validation depended on `benchmark_output_coverage()` already existing in the producer session.
- **Fix:** Added explicit on-demand dependency loading and a fresh-environment regression.
- **Files modified:** `R/benchmark/runner.R`, `tests/testthat/test_benchmark_pipeline.R`
- **Verification:** The exact Task 1 and Task 2 fresh-process source sequences both passed.
- **Committed in:** `03b3a1e`

---

**Total deviations:** 3 auto-fixed (2 correctness bugs, 1 blocking dependency defect).
**Impact on plan:** All fixes strengthened staged publication, durable evaluator identity, and independent validation without changing scientific settings or scope.

## Issues Encountered

- The complete two-pass replay took roughly 75 minutes and remained intentionally quiet during boundary refits. Six-minute filesystem inspections confirmed the old seal remained present until the first repro pass existed and publication occurred only after reconciliation.
- Task 2 was deliberately verification-only. The exact fail-fast shell exited successfully and left no task-related working-tree changes.

## Verification

- Fresh standalone Task 1 acceptance: passed exact 6,300 prediction, coverage-link, 609-rich, reason, reproducibility, seal, and network checks.
- Exact Task 2 fail-fast block: passed external SHA-256/bytes, streamed rows, self-hash, 15-input parent set, graph hash, score-support lineage, full suite, target network, focused suites, and protected-path pre/post checks.
- Full `tests/testthat` suite: zero failures and zero warnings.
- Focused benchmark, Transfermarkt/EURO, World Cup dashboard, ledger, scoring, and retrospective suites: zero failures and zero warnings.
- Protected `outputs/dashboard/` and `outputs/evaluation/wc2026/`: no tracked diff before or after acceptance.
- `.planning/phases/09-rolling-tournament-benchmark-harness/09-VERIFICATION.md`: unchanged; fresh phase verification remains verifier-owned.

## User Setup Required

None - no external service configuration required.

## Known Stubs

None. Empty successful reason/value fields in durable CSVs are intentional contract values, not placeholders.

## Next Phase Readiness

- Phase 09 now has an accepted immutable benchmark authority for Phase 10 and Phase 11 challengers.
- The standard post-execution verifier may regenerate `09-VERIFICATION.md`; the executor did not edit verifier-owned evidence.
- No execution blocker remains.

## Self-Check: PASSED

- Verified the summary and all key canonical bundle files exist on disk.
- Verified corrective commits `a845df6`, `58ff288`, `03b3a1e`, and publication commit `15ed965` exist as commits.
- Verified all three coverage entries classify as automated and passing.
- Verified no temporary repro/staged directory remains and protected dashboard/WC2026 outputs have no tracked diff.

---
*Phase: 09-rolling-tournament-benchmark-harness*
*Completed: 2026-07-21*
