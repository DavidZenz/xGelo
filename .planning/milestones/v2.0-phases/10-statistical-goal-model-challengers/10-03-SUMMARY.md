---
phase: 10-statistical-goal-model-challengers
plan: "03"
subsystem: statistical-forecasting
tags: [r, glmnet, sparse-matrix, poisson, ridge, lasso, chronology]

requires:
  - phase: 10-statistical-goal-model-challengers
    provides: Wave 0 penalized-Poisson RED contracts from Plan 10-01 and the verified glmnet 5.0 environment from Plan 10-02
  - phase: 10-statistical-goal-model-challengers
    provides: Canonical challenger, feature, tuning, chronology, and storage contracts from Plan 10-09
provides:
  - Sparse full-block ridge attack/defence team means with centered-identification evidence
  - Nested canonical-Elo lasso increment that can recover the minimal parent exactly
  - Strictly prior, equal-tournament updating-RPS penalty tuning shared by frozen and updating tracks
  - Complete cold-start predictions and chronology/settings/provenance manifests
affects: [10-06, 10-07, 10-08, phase12-model-release]

tech-stack:
  added: []
  patterns: [full sparse identity blocks, centered ridge coefficients with intercept compensation, fixed-offset nested lasso, stagewise prior-edition tuning]

key-files:
  created:
    - R/forecast/penalized_poisson.R
  modified:
    - tests/testthat/test_statistical_penalized_poisson_tuning.R

key-decisions:
  - "Treat zero-prior registered teams exactly like unseen identities at prediction time: each contributes the global zero centered effect while remaining present in the fitted coefficient blocks."
  - "Fit Elo only as a no-intercept lasso increment over the immutable centered team-model predictor, preserving the minimal model hash and exact nesting when Elo is zero."
  - "Tune team ridge first and Elo lasso second with equal weight per completed inner tournament, then freeze one settings identity for both outer tracks."

patterns-established:
  - "Canonical Elo boundary: only elo_diff plus its five provenance companions may cross into the model, with source/imputation consistency and source_date < cutoff enforced before optimization."
  - "Cold-start completeness: unknown or zero-prior team blocks contribute zero but retain prior-count, shrinkage-weight, and status evidence without dropping fixtures."

requirements-completed: [STAT-01]

coverage:
  - id: D1
    description: "Sparse full attack/defence blocks are ridge fit, sum-to-zero centered, predictor invariant, level-order invariant, and complete for known, sparse, and unseen teams."
    requirement: STAT-01
    verification:
      - kind: unit
        ref: "tests/testthat/test_statistical_penalized_poisson_design.R (50 assertions)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Canonical Elo is a nested lasso increment selected after team ridge from strictly prior completed tournaments and shared unchanged across frozen/updating tracks."
    requirement: STAT-01
    verification:
      - kind: integration
        ref: "tests/testthat/test_statistical_penalized_poisson_tuning.R (68 assertions)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Every candidate fixture remains paired against all five inherited baselines at exact 630 open-core and 609 feature-rich counts."
    requirement: STAT-01
    verification:
      - kind: integration
        ref: "tests/testthat/test_benchmark_baselines.R plus penalized candidate pairing contract (75 baseline assertions)"
        status: pass
    human_judgment: false

duration: 15 min
completed: 2026-07-22
status: complete
---

# Phase 10 Plan 03: Penalized-Poisson Challenger Summary

**Sparse centered ridge team means, a canonical-Elo fixed-offset lasso increment, and chronology-sealed two-stage tuning now produce complete attributable challenger means without fixture loss.**

## Performance

- **Duration:** 15 min
- **Started:** 2026-07-22T13:56:45Z
- **Completed:** 2026-07-22T14:11:29Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Built two goal-perspective rows per match with complete registered attack/defence sparse blocks, ridge-only team penalties, unpenalized intercept/venue, full-block centering, and strict raw-versus-centered predictor invariance.
- Added a canonical-Elo-only lasso increment over fixed minimal-model predictors; a sufficiently large penalty selects Elo exactly to zero while retaining the identical parent team-fit SHA-256 and means.
- Selected ridge and Elo penalties only from completed prior tournament folds using equal-tournament updating RPS, deterministic largest-penalty ties, G=40 shared market/scorer paths, and one settings hash reused by frozen/updating tracks.
- Preserved every synthetic fixture, including three cold-start fixtures, and paired the candidate against five baselines at exact 630/609 panel counts.

## Task Commits

Wave 0 supplied both RED contracts in `0e8d5bc`; each implementation task was then committed atomically after its focused suite passed:

1. **Task 1: Build sparse identified team means and global cold starts** — `b2762b5` (feat)
2. **Task 2: Add nested Elo selection and prior-tournament tuning** — `bf78265` (feat)

## Files Created/Modified

- `R/forecast/penalized_poisson.R` — Sparse design, weighted ridge fit, centered prediction, canonical Elo validation/offset fit, stagewise chronology-safe tuning, and manifest evidence.
- `tests/testthat/test_statistical_penalized_poisson_tuning.R` — Compatibility-safe fixture-key assertions for the installed `testthat` API while preserving all frozen contract semantics.

## Tuning and Cold-Start Evidence

- Synthetic outer edition: `wc2010`; exclusive cutoff: `2010-06-11`.
- Latest eligible inner final: `2008-06-29`, strictly before the outer opener.
- Selected team ridge lambda: `1`; selected Elo lasso lambda: `1`.
- Shared tracks: `frozen`, `updating`.
- Settings SHA-256: `d8547b0a9d1c633cb5191a6d641dca97d2d2e26c6ee546beb081018c70315651`.
- Eligible-match SHA-256: `c025bb650c326d215f49020acd14d7623b6a6bcf1006c4430901040933f75901`.
- Selected synthetic Elo coefficient: `-0.0001301501`; the separate `lambda = 1e6` nesting contract selected exact zero and reproduced minimal means within `1e-12`.
- Cold-start fixtures retained: `3` of `6`; no fixture was dropped.

## Decisions Made

- Centered effects remain stored for every registered identity, but prediction applies a team effect only when that identity has positive prior evidence. This reconciles complete fixed blocks with the required global fallback.
- The Elo optimizer receives only signed canonical `elo_diff`, fixed minimal offsets, no intercept, and no rating-history/path/lookup surface.
- Tournament metadata is accepted only through a complete unique `match_id` → `tournament` map exposing exactly those two fields; raw or reconstructed ratings are rejected before fitting.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected global fallback for registered zero-prior teams**
- **Found during:** Task 1 GREEN verification.
- **Issue:** Full-block centering can give a registered but unobserved level a small nonzero centered coefficient even though it has no evidence.
- **Fix:** Prediction now applies centered team effects only to identities with positive prior counts; zero-prior registered and truly unseen identities both contribute exactly zero.
- **Files modified:** `R/forecast/penalized_poisson.R`
- **Verification:** All 50 design/centering/cold-start assertions pass.
- **Committed in:** `b2762b5`

**2. [Rule 3 - Blocking] Adapted two frozen assertions to the installed testthat API**
- **Found during:** Task 2 GREEN verification.
- **Issue:** This `testthat` version does not accept `info` in `expect_setequal()`, and strict `expect_false()` does not coerce integer zero returned by `anyDuplicated()`.
- **Fix:** Removed the unsupported diagnostic argument and asserted `anyDuplicated(...) == 0L`; expected fixture sets and duplicate semantics are unchanged.
- **Files modified:** `tests/testthat/test_statistical_penalized_poisson_tuning.R`
- **Verification:** All 68 tuning/provenance/pairing assertions pass.
- **Committed in:** `bf78265`

---

**Total deviations:** 2 auto-fixed (1 Rule 1 bug, 1 Rule 3 blocker).
**Impact on plan:** Both fixes were required for the frozen behavior to execute correctly; neither expanded model scope or benchmark work.

## Issues Encountered

- `glmnet` 5.0 is consumed from the verified Phase 10 local library prepared by Plan 10-02; no package installation or substitution was performed.

## TDD Gate Compliance

- Wave 0 RED contract: `0e8d5bc`.
- Task 1 GREEN: `b2762b5`; Task 2 GREEN: `bf78265`.
- Both initial RED runs failed only because their production APIs were absent, and the final focused suites pass with warnings treated as failures.

## Verification Results

- `test_statistical_penalized_poisson_design.R`: 50 passing assertions.
- `test_statistical_penalized_poisson_tuning.R`: 68 passing assertions, including static forbidden-source scans, dynamic canonical provenance rejection, poisoning invariance, exact nesting, manifest chronology, and 630/609 pairing.
- `test_benchmark_baselines.R`: 75 passing assertions.
- Combined focused regression: 193 passing assertions; zero failures and zero warnings.
- No full tournament benchmark, promotion run, package install, network access, or Phase 9 artifact mutation occurred.

## Known Stubs

None. Empty active/dropped predictor vectors are intentional nested-model evidence, not placeholders.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The common benchmark adapter can consume finite per-fixture `mu_home`/`mu_away` and complete fit, provenance, tuning, chronology, and cold-start evidence.
- Exact minimal/augmented nesting and shared track settings are ready for downstream challenger execution without revisiting hyperparameters.
- Release and promotion authority remain outside this plan.

## Self-Check: PASSED

- Verified `R/forecast/penalized_poisson.R` and `tests/testthat/test_statistical_penalized_poisson_tuning.R` exist.
- Verified task commits `b2762b5` and `bf78265` exist in git history.
- Re-ran all three focused suites successfully for 193 total assertions.
- Confirmed only preserved user-owned planning/report artifacts remain outside the plan commits.

---
*Phase: 10-statistical-goal-model-challengers*
*Completed: 2026-07-22*
