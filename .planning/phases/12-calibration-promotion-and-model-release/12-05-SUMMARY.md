---
phase: 12-calibration-promotion-and-model-release
plan: 05
subsystem: final-evaluation
tags: [R, FIFA, WC2026, one-shot, promotion, incumbent-retained]
requires:
  - Phase 12 freeze, calibration gate, and final-fit preflight
  - reviewed FIFA WC2026 label artifact and explicit approval
provides:
  - immutable WC2026 final labels, predictions, and scores
  - nine-row final-evaluation manifest and evaluator-backed promotion report
  - reproducible production runner for the frozen RF candidate
affects: [phase12-release-bundle, phase12-release-install, phase12-dashboard]
---

# Phase 12 Plan 05: One-Shot WC2026 Final Evaluation Summary

## Outcome

- The reviewed FIFA label source was opened exactly once after a passed label-free preflight and explicit approval.
- The active frozen candidate `phase11_rf_dynamic_elo_open` was rehydrated through the registered Phase 11 RF adapter using the exclusive pre-tournament cutoff `2026-06-11`.
- Dynamic goal ability and point-in-time Elo evidence were prepared without using WC2026 outcomes for fitting, calibration, or selection.
- The frozen Phase 12 calibrator supplied the primary `calibrated_1x2` probabilities; the fitted G=40 score distributions remained unchanged.
- All 104 official WC2026 fixtures were scored. The eight inactive candidates remain explicit no-score rows.

## Durable Artifacts

- `outputs/benchmarks/rolling_tournaments/phase12-calibration-release/final_evaluation/labels.csv`
- `outputs/benchmarks/rolling_tournaments/phase12-calibration-release/final_evaluation/predictions.csv`
- `outputs/benchmarks/rolling_tournaments/phase12-calibration-release/final_evaluation/scores.csv`
- `outputs/benchmarks/rolling_tournaments/phase12-calibration-release/manifests/final_evaluation_manifest.csv`
- `outputs/benchmarks/rolling_tournaments/phase12-calibration-release/manifests/promotion_report.csv`
- `scripts/run_phase12_final_evaluation.R`

The reviewed source SHA-256 is `7dd366f457460c435ca3b8bdf9a456cc85903ee639d31f29bbd9c62ff604e1dc`. The copied reporting artifact has its own immutable serialization hash and is linked to the source hash in the final manifest.

## Decision

- Final evaluation: 104/104 active fixtures covered.
- Active candidate WC2026 metrics: RPS `0.2072`, Brier `0.6799`, log loss `1.3931`, winner-pick accuracy `54.8%`.
- Promotion decision: exact `incumbent retained`.
- Selected identity: `open_nb_incumbent`.
- Active challenger vetoes: maximum fold regression exceeded the frozen limit; Brier, log-loss, and calibration-change evidence were not persisted for the Phase 11 challenger and therefore failed closed.

## Verification

- Fresh-process final-fit and final-evaluation manifest validation passed.
- `tests/testthat/test_phase12_final_evaluation.R`: 58 passing assertions.
- `tests/testthat/test_phase12_promotion.R`: 15 passing assertions, 1 intentional skip.
- `tests/testthat/test_benchmark_promotion.R`: 169 passing assertions.
- No second opener or artifact mutation was attempted.

## Next Step

Stage the complete versioned release bundle for the incumbent-retained decision, then complete metadata/installation and approved-release consumer resolution.

status: complete
---
