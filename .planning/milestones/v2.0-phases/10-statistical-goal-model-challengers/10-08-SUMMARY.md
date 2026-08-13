---
phase: 10-statistical-goal-model-challengers
plan: "08"
type: execute
wave: 6
status: complete
requirements: [STAT-01, STAT-02, STAT-03, STAT-04]
---

# Phase 10 Plan 08: Canonical Benchmark Acceptance Summary

## Outcome

The historical Phase 10 challenger benchmark was executed in both candidate
orders, reconciled byte-for-byte, and atomically published. The accepted bundle
is research-only and does not use WC2026 outcomes or make a promotion decision.

Published bundle:

`outputs/benchmarks/rolling_tournaments/phase10-statistical-challengers/`

The reversed-order audit stage remains available at:

`outputs/benchmarks/rolling_tournaments/.phase10-reversed-stage-1008/`

## Canonical Runs

- Normal order: `CANONICAL_STAGE_OK`, 10,943.678 seconds.
- Reversed order: `CANONICAL_STAGE_OK`, 10,665.173 seconds.
- Candidates: 7.
- Editions: 12.
- Tracks: frozen and updating.
- Predictions: 8,820.
- Score distributions: 14,826,420 on G=40 support.
- Normal and reversed checksum manifests: byte-identical.

## Acceptance

- Bounded real adapter preflight passed for all seven candidates on both tracks
  for `wc2002`.
- Fresh-process smoke acceptance passed in 11.710 seconds.
- Deep bundle validation passed before and after atomic installation.
- Phase 9 parent bundle and dependency provenance identities validated.
- WC2026 seal, research-only boundary, and protected paths validated.
- Complete `testthat` suite passed with exit status 0.
- Core coverage gate passed without instrumentation exceptions:
  `penalized_poisson` 88.73%, `dynamic_goal_ability` 89.53%,
  `score_dependence` 86.35%, `challengers` 90.84%, and
  `challenger_selection` 85.71%.

## Corrections

Deep validation exposed an R compatibility defect in the expected score-grid
construction: `rep.int()` does not accept `each`. Replaced it with `rep()` in
`R/benchmark/challenger_runner.R`, reran deep validation, and published only
after the corrected validator passed.

## Files Added

- `scripts/phase10_reconcile_publish.R` - bounded preflight, stage reconciliation,
  and atomic publication driver.

## Next Step

Review the three-slot historical shortlist and begin Phase 11 hybrid ML and
contextual-prior challenger design. No Phase 10 candidate is promoted yet.
