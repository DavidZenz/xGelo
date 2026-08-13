---
phase: 12-calibration-promotion-and-model-release
plan: 03
subsystem: calibration
tags: [R, testthat, calibration-gate, proper-scores, raw-fallback, G40]

# Dependency graph
requires:
  - phase: 12-calibration-promotion-and-model-release
    provides: "Validated freeze, chronology-safe inner-OOF rows, and derived-1X2 calibrator artifacts"
provides:
  - "Shared raw-versus-calibrated 1X2 scoring and development selection gate"
  - "Durable nine-row candidate/track calibration_gate.csv with score, calibration, stability, coverage, and veto evidence"
affects: [phase12-final-evaluation, phase12-promotion, phase12-release]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Compare raw and calibrated probabilities through one shared fixture identity and proper-score contract."
    - "Persist explicit calibrated_1x2/raw_1x2 decisions with ordered fail-closed fallback reasons."
    - "Retain G=40 and fitted scoreline metrics unchanged while calibrating only derived 1X2 probabilities."

key-files:
  created:
    - R/calibration/calibration_selection.R
    - outputs/benchmarks/rolling_tournaments/phase12-calibration-release/calibration/calibration_gate.csv
  modified:
    - tests/testthat/test_phase12_calibration.R

key-decisions:
  - "Use strict calibration-error improvement plus zero raw-vs-calibrated RPS regression, inherited Brier/log-loss limits, fold-stability, exact coverage, and score/distribution identity vetoes."
  - "Represent every frozen candidate on the updating track; retain eight unavailable candidate/track states as explicit raw/no-score rows rather than dropping identities."
  - "Keep freeze-byte validation separate from the pre-label clean-code gate so development artifacts can be staged without weakening the later holdout boundary."

requirements-completed: [CAL-02]

coverage:
  - id: D1
    description: "Raw and calibrated derived 1X2 predictions are scored on identical 12-edition fixtures through the shared RPS, Brier, log-loss, fixed-bin calibration, and paired-fold services without changing G=40 scoreline evidence."
    requirement: CAL-02
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase12_calibration.R#12-03-01 raw and calibrated views use identical fixtures and shared scores"
        status: pass
      - kind: integration
        ref: "Rscript phase12 calibration gate test: 76 assertions passed"
        status: pass
    human_judgment: false
  - id: D2
    description: "The development gate selects calibrated_1x2 only on strict improvement and passing score, stability, coverage, and identity vetoes; otherwise it records raw_1x2 with ordered reasons."
    requirement: CAL-02
    verification:
      - kind: unit
        ref: "tests/testthat/test_phase12_calibration.R#12-03-02 calibration selection is strict and vetoes supporting regressions"
        status: pass
      - kind: contract
        ref: "gate CSV contract: 9 rows, 1 scored calibrated-primary row, 8 no-score raw rows, G=40 on all rows"
        status: pass
    human_judgment: false

# Metrics
duration: 32 min
completed: 2026-08-11
status: complete
---

# Phase 12 Plan 03: Calibration Gate Summary

**Raw-versus-calibrated derived-1X2 development gate with shared proper scoring, fail-closed vetoes, and durable nine-candidate evidence**

## Performance

- **Duration:** 32 min
- **Started:** 2026-08-11T09:10:00Z
- **Completed:** 2026-08-11T09:42:50Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Added `compare_phase12_raw_calibrated()` with exact fixture/edition/track/status/market/distribution identity checks, shared proper-score aggregation, fixed-bin calibration, paired fold stability, and unchanged fitted scoreline evidence.
- Added `select_phase12_primary_probability_view()` and durable gate-row builders that preserve raw fallback for insufficient support, score/stability/coverage vetoes, tied calibration, and identity drift.
- Persisted `calibration_gate.csv` with all nine frozen candidate identities on the updating track, one scored calibrated-primary synthetic row, eight explicit raw/no-score rows, and G=40 support on every row.
- Extended only the owned Phase 12 calibration test surface with identity drift, strict threshold, sparse support, tied metric, incomplete coverage, fold instability, unchanged distribution, ordering, and read-back regressions.

## Task Commits

Each task was committed atomically:

1. **Task 1: Trace one frozen candidate through raw-versus-calibrated development scoring** - `7460fff` (`feat`)
2. **Task 2: Persist all raw/calibrated comparison and regression evidence** - `e274d37` (`feat`)
3. **Task 2 corrective commit: Make no-score gate support explicit** - `f892e30` (`fix`)

## Files Created/Modified

- `R/calibration/calibration_selection.R` - Shared comparison, selection, veto, gate-row, no-score, and durable read-back APIs.
- `tests/testthat/test_phase12_calibration.R` - Owned CAL-02 integration and regression coverage; prior CAL-01 tests remain green.
- `outputs/benchmarks/rolling_tournaments/phase12-calibration-release/calibration/calibration_gate.csv` - Canonical synthetic, label-free nine-row development gate evidence.

## Decisions Made

- Calibration is promoted only when fixed-bin calibration error is strictly lower, raw-vs-calibrated RPS is non-regressing, inherited Brier/log-loss limits pass, fold stability passes, and fixture/distribution coverage remains exact.
- The fitted G=40 scoreline distribution and auxiliary markets are shared and unchanged; only derived 1X2 probabilities differ between views.
- No final evaluation, promotion decision, or release action is part of this development plan.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Correctness] Made no-score G=40 support explicit**
- **Found during:** Task 2 acceptance verification
- **Issue:** The eight explicit no-score rows carried `NA` for `score_support_g`, so the durable all-row support contract was not fail-closed.
- **Fix:** Set `score_support_g = 40` on no-score rows and added a regression assertion covering every persisted row.
- **Files modified:** `R/calibration/calibration_selection.R`, `tests/testthat/test_phase12_calibration.R`, `outputs/benchmarks/rolling_tournaments/phase12-calibration-release/calibration/calibration_gate.csv`
- **Verification:** Phase 12 calibration, inherited scoring, inherited promotion, and CSV contract checks passed.
- **Committed in:** `f892e30`

---

**Total deviations:** 1 auto-fixed (Rule 2: 1)
**Impact on plan:** The fix closes a directly related durable support invariant; no scope expansion or unrelated file changes were made.

## Issues Encountered

- The inherited freeze validator intentionally rejects tracked R changes while a downstream task is being staged. Task 2 production/output changes were committed before the inherited regression suite was rerun so the clean-code precondition could be satisfied without weakening the validator.
- The full repository suite was not run because later Phase 12 plan-owned Wave 0 contract files remain intentionally incomplete; the plan’s focused and inherited verification commands all passed.

## Authentication Gates

None.

## Known Stubs

None in files created or modified by this plan.

## Threat Flags

None. The implementation adds only the planned local raw/calibrated scoring and durable CSV surface; no new network, authentication, or external trust-boundary surface was introduced.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 12-04 can consume the validated `calibration_gate.csv`, explicit primary-view values, ordered fallback reasons, exact coverage, and G=40 unchanged-distribution contract. The sealed holdout remains unopened, and no final evaluation, promotion, or release was performed.

## Self-Check: PASSED

- All three Plan 12-03 owned implementation/test/output files exist.
- Task commits `7460fff`, `e274d37`, and `f892e30` exist in Git history.
- Focused calibration (76 assertions), inherited scoring (47 assertions), inherited promotion (169 assertions), and durable CSV contract checks passed with zero failures, warnings, or skips.
- Unrelated Phase 10/11 dirty benchmark/output files and untracked artifacts remained unstaged.

---
*Phase: 12-calibration-promotion-and-model-release*
*Completed: 2026-08-11*
