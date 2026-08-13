---
phase: 12-calibration-promotion-and-model-release
plan: 04
subsystem: release
tags: [phase12, final-fit, preflight, holdout-boundary]
requires:
  - Phase 12 freeze manifest and calibration gate
  - Phase 11 registered model, adapter, and ranger provenance artifacts
provides:
  - label-free final-fit allowlist and durable manifest
  - unopened final-evaluation preflight and exact approval seam
affects:
  - 12-05 approval-gated final evaluation
tech-stack:
  added: []
  patterns:
    - frozen artifact hash reconciliation
    - fail-closed provider boundary
key-files:
  created:
    - R/release/final_fit.R
    - R/release/final_evaluation.R
    - outputs/benchmarks/rolling_tournaments/phase12-calibration-release/final_evaluation/final_fit/final_fit_manifest.csv
  modified:
    - tests/testthat/test_phase12_final_evaluation.R
decisions:
  - Only phase11_rf_dynamic_elo_open is admissible; all eight inactive candidates remain explicit no-score rows.
  - Preflight is label-free and the sole opener requires the exact allowlisted source path, approved state, and a passed unopened preflight.
  - Final-fit validation derives every persisted contract field from frozen inputs before authorization.
requirements-completed: []
metrics:
  duration: 13m46s
  completed: 2026-08-11T10:04:15Z
  tasks: 2
  files: 4
status: complete
---

# Phase 12 Plan 04: Label-Free Final-Fit and Preflight Boundary Summary

Durable label-free final-fit identity and fail-closed unopened preflight for the later approval-gated WC2026 operation.

## What Was Built

- Added `R/release/final_fit.R` to derive the exact nine-candidate updating allowlist, admit only `phase11_rf_dynamic_elo_open`, retain eight explicit no-score rows, record model/calibrator and frozen-input hashes, and validate the durable manifest from a fresh process.
- Added `R/release/final_evaluation.R` with label-free freeze/calibration/final-fit preflight and the sole exact opener signature/path contract. Preflight never invokes a provider; the opener is reserved for the dependent approval-gated plan.
- Persisted `final_fit_manifest.csv` with active/inactive identities, G=40, contract flags, provenance, hash fields, unopened state, and no label-consumption markers.
- Extended only the owned final-evaluation test file with synthetic provider call-count assertions and fail-closed drift coverage.

## Task Commits

| Task | Commit | Description |
| --- | --- | --- |
| 1 | `55baf23` | Build label-free final-fit and preflight boundary |
| 2 | `838a47c` | Harden final-fit drift validation |

## Verification

- Focused final-evaluation suite: 43 passing assertions, 0 failures, 0 warnings, 0 skips.
- Inherited benchmark seal suite: 18 passing assertions, 0 failures, 0 warnings, 0 skips.
- Fresh-process read-back: final-fit manifest validation and unopened preflight passed; rejected non-allowlisted path was blocked before provider invocation; provider calls remained 0.
- Tracer feedback gate: focused final-evaluation suite passed after Task 1 commit.
- No final evaluation, promotion, release, label read, label copy, or label-bearing fit/calibration/selection was performed.

## Deviations from Plan

None - plan executed as written.

PROMO-02 remains pending in `REQUIREMENTS.md` because Plan 12-05 also owns the shared requirement and must perform the explicit approval-gated one-shot comparison.

## Known Stubs

None. The opener body is intentionally reserved for Plan 12-05 and was not invoked; this is the planned approval boundary, not an incomplete prerequisite for this plan.

## Self-Check: PASSED

- Owned implementation, manifest, and test files exist.
- Task commits `55baf23` and `838a47c` exist and contain no file deletions.
- Unrelated dirty Phase 10/11 benchmark and output changes remain unstaged and unmodified by this plan.
