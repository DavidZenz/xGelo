# Phase 14 Calibration Remediation Contract

**Recorded:** 2026-08-17
**Status:** Approved design direction; requires nested rolling implementation and unchanged release gates

## Why A Revision Is Needed

Plan 14-04 produced valid immutable evidence with disposition
`CALIBRATION_RELEASE_BLOCKED`. The frozen scalar temperature candidate worsened
equal-tournament RPS by `0.0008328552` and fixed-bin calibration error by
`0.0030713304`. About 98 percent of the RPS loss came from the WC 2006 outer
fold, where only 95 prior fixtures yielded an unstable temperature of
`1.327133`.

The scalar transform also cannot address the incumbent's class-specific bias:
home-win probability is too high while draw and away probabilities are too
low. Home calibration error worsened even though draw and away calibration
improved.

## Locked Remediation Direction

1. Preserve every Plan 14-04 artifact and its blocked disposition unchanged.
2. Keep the Phase 12 release selector, registry pins, score distributions,
   thresholds, and WC 2026 holdout boundary unchanged until a new candidate
   independently passes.
3. Forecast availability remains earliest-possible through explicit
   `raw_fallback`; calibration activates only when its predeclared history and
   class-support requirements are met.
4. Evaluate three predeclared candidate families:
   - raw identity fallback;
   - scalar temperature with a history warm-up and shrinkage toward `T = 1`;
   - regularized multiclass vector scaling with class-specific slopes and two
     identifiable class offsets, shrunk toward the identity transform.
5. Freeze the exploratory grids before authoritative evaluation:
   - warm-up rows: `60, 128, 256, 400`;
   - scalar shrinkage: `0.25, 0.50, 0.75, 1.00`;
   - vector-scaling penalty: `0.001, 0.01, 0.05, 0.10, 0.50, 1.00, 5.00`.
6. Select family and hyperparameters inside each outer tournament using only
   nested, strictly earlier tournament folds. If nested evidence is
   insufficient or no candidate beats raw under the frozen inner criteria,
   use raw fallback for that outer tournament.
7. Evaluate the resulting outer predictions on the same 630 fixtures with the
   unchanged Plan 14-04/Phase 12 support, coverage, identity, RPS, Brier,
   log-loss, fold-stability, and strict calibration-improvement vetoes.
8. Fit a final calibrator on all 630 development fixtures only after outer
   evaluation passes. WC 2026 labels remain forbidden throughout tuning,
   selection, and fitting.
9. A failed revision remains auditable candidate evidence and cannot mutate
   release authority. Only a fully passing, hash-bound revision may resume the
   existing release and dual-registry promotion plans.

## Exploratory Feasibility Evidence

These numbers are design evidence only, not promotion evidence. They were
computed after observing the failed Plan 14-04 run and therefore must be
reproduced through the nested protocol above.

| Candidate | Warm-up | Regularization | RPS delta | Brier relative | Log-loss relative | Calibration delta |
|---|---:|---:|---:|---:|---:|---:|
| Scalar temperature shrinkage | 400 | shrink `0.25` | `-0.0000032` | `-0.0000044` | `-0.0000058` | `-0.0003770` |
| Vector scaling | 128 | lambda `0.01` | `-0.0018849` | `-0.0052294` | `-0.0029507` | `-0.0212537` |

The scalar result is too close to identity to motivate promotion by itself.
Regularized vector scaling is the primary candidate because it addresses the
observed class-specific bias and showed materially better exploratory scores,
but it receives no authority unless nested outer evidence passes unchanged
gates.

## Orchestration Consequence

Plan 14-05 remains the honest record that the first candidate could not resume
release work. Add remediation plans after 14-05, then redirect Plan 14-06 and
all release-dependent work to the new immutable passing checkpoint. Do not
delete, overwrite, or relabel the original blocked evidence.
