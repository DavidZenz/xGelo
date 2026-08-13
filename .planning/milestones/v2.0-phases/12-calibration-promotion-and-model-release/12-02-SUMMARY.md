---
phase: 12-calibration-promotion-and-model-release
plan: 02
subsystem: calibration
tags: [R, testthat, inner-oof, temperature-scaling, chronology, provenance]

# Dependency graph
requires:
  - phase: 12-calibration-promotion-and-model-release
    provides: "Validated nine-candidate freeze manifest and canonical base-R calibration recipe"
provides:
  - "Chronology-safe candidate/track inner-OOF assembly with cutoff and holdout guards"
  - "Deterministic derived-1X2 temperature calibrator and explicit raw fallback"
  - "Persisted inner-OOF/calibrator artifacts with provenance and byte-stable read-back"
affects: [phase12-development-calibration-gate, phase12-final-evaluation, phase12-promotion, phase12-release]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Validate the authoritative freeze and recipe checksum before any calibration fit or optimizer call."
    - "Keep raw 1X2, calibrated 1X2, and fitted G=40 scoreline views separate."
    - "Serialize persisted date fields as ISO character values for byte-stable CSV replay."

key-files:
  created:
    - R/calibration/inner_oof.R
    - R/calibration/probability_calibration.R
    - outputs/benchmarks/rolling_tournaments/phase12-calibration-release/calibration/inner_oof_predictions.csv
    - outputs/benchmarks/rolling_tournaments/phase12-calibration-release/calibration/calibrators.rds
    - .planning/phases/12-calibration-promotion-and-model-release/deferred-items.md
  modified:
    - tests/testthat/test_phase12_calibration.R

key-decisions:
  - "Use the validated Phase 12 freeze and its recipe SHA as a hard pre-fit gate."
  - "Fit one positive base-R temperature per candidate/track/outer edition from strictly prior inner-OOF rows, with explicit raw fallback below 60 rows or 10 observations per class."
  - "Persist synthetic schema-faithful calibration evidence only; no operator-supplied holdout labels or final evaluation are part of Plan 12-02."

patterns-established:
  - "Inner-OOF provenance records candidate, track, outer edition, sorted prior editions, strict cutoff, source prediction hash, and maximum evidence date."
  - "Calibrator RDS payloads include a manifest row, freeze identity, recipe identity, support, optimizer state, and fallback reason."

requirements-completed: [CAL-01]

coverage:
  - id: D1
    description: "Candidate/track inner-OOF assembly rejects mixed identities, duplicate fixtures, future editions, non-strict evidence dates, and holdout-bearing rows after validating the freeze."
    requirement: CAL-01
    verification:
      - kind: unit
        ref: "tests/testthat/test_phase12_calibration.R#12-02-01 and #12-02-02"
        status: pass
      - kind: integration
        ref: "Rscript --vanilla -e 'source(\"R/release/freeze_manifest.R\"); source(\"R/calibration/inner_oof.R\"); validate_phase12_freeze_manifest()'"
        status: pass
    human_judgment: false
  - id: D2
    description: "Deterministic frozen temperature calibration produces simplex-valid derived 1X2 probabilities, explicit raw fallback, and unchanged scoreline views."
    requirement: CAL-01
    verification:
      - kind: unit
        ref: "tests/testthat/test_phase12_calibration.R#12-02-01 frozen recipe and repeated fit"
        status: pass
      - kind: unit
        ref: "tests/testthat/test_phase12_calibration.R#12-02-02 sparse history and unchanged G=40 scoreline view"
        status: pass
    human_judgment: false
  - id: D3
    description: "Durable inner-OOF CSV and calibrator RDS artifacts reconcile to the freeze, recipe, source hashes, row counts, and byte-stable fresh-process read-back."
    requirement: CAL-01
    verification:
      - kind: integration
        ref: "validate_phase12_calibration_artifacts() fresh-process read-back"
        status: pass
      - kind: integration
        ref: "fresh-process CSV/RDS SHA-256 replay"
        status: pass
    human_judgment: false

# Metrics
duration: 26 min
completed: 2026-08-11
status: complete
---

# Phase 12 Plan 02: Calibration and Inner-OOF Summary

**Chronology-safe candidate/track 1X2 temperature calibration with freeze-gated provenance, raw fallback, and byte-stable durable artifacts**

## Performance

- **Duration:** 26 min
- **Started:** 2026-08-11T08:43:00Z
- **Completed:** 2026-08-11T09:08:11Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Added freeze- and recipe-gated inner-OOF assembly that retains strict cutoff, candidate/track identity, class, source hash, and maximum evidence-date provenance.
- Added deterministic base-R `stats::optim` L-BFGS-B temperature scaling for derived 1X2 probabilities, with simplex validation, optimizer-state validation, and explicit raw fallback for insufficient history/support.
- Persisted a synthetic schema-faithful candidate/track inner-OOF CSV and calibrator RDS with manifest/read-back validation; fitted scoreline distributions remain untouched.
- Extended only the owned calibration test surface with chronology, isolation, cutoff, holdout, support, repeatability, provenance, scoreline, and persistence checks.

## Task Commits

Each task was committed atomically:

1. **Task 1: Trace one frozen candidate/track from prior inner OOF to calibrated 1X2** - `4c351ec` (`feat`)
2. **Task 2: Complete reusable inner-OOF and calibrator provenance validation** - `2b0c2b1` (`feat`)

## Files Created/Modified

- `R/calibration/inner_oof.R` - Freeze-gated chronology-safe inner-OOF assembly and validation.
- `R/calibration/probability_calibration.R` - Frozen recipe read-back, temperature fit/apply, provenance, persistence, and artifact validation.
- `outputs/benchmarks/rolling_tournaments/phase12-calibration-release/calibration/inner_oof_predictions.csv` - Deterministic synthetic prior inner-OOF rows.
- `outputs/benchmarks/rolling_tournaments/phase12-calibration-release/calibration/calibrators.rds` - Fitted calibrator payload and provenance manifest.
- `tests/testthat/test_phase12_calibration.R` - Owned CAL-01 contract extension.
- `.planning/phases/12-calibration-promotion-and-model-release/deferred-items.md` - Out-of-scope later-plan full-suite failures.

## Decisions Made

- The authoritative freeze and recipe checksum are validated before any fitting work.
- Calibration is derived-1X2-only; the fitted joint score distribution and G=40 support are not rewritten.
- Durable Plan 12-02 evidence remains synthetic and label-free; final evaluation and promotion are deferred to later plans.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Resolved project-root lookup from testthat working directories**
- **Found during:** Task 1
- **Issue:** The focused suite could not locate cutoff/freeze dependencies or the authoritative freeze when sourced from `tests/testthat`.
- **Fix:** Added repository-root discovery and path resolution before dependency sourcing and freeze validation.
- **Files modified:** `R/calibration/inner_oof.R`, `R/calibration/probability_calibration.R`
- **Verification:** Focused calibration suite passed with 43 assertions.
- **Committed in:** `4c351ec`

**2. [Rule 1 - Bug] Made persisted calibration CSV bytes reproducible after read-back**
- **Found during:** Task 2
- **Issue:** Native R `Date` serialization was unquoted on the first write and quoted after fresh-process read/write, changing CSV bytes.
- **Fix:** Canonicalized evidence-date fields to ISO character values before CSV persistence and regenerated the RDS-linked artifact pair.
- **Files modified:** `R/calibration/probability_calibration.R`, `outputs/benchmarks/rolling_tournaments/phase12-calibration-release/calibration/inner_oof_predictions.csv`, `outputs/benchmarks/rolling_tournaments/phase12-calibration-release/calibration/calibrators.rds`
- **Verification:** Fresh-process CSV/RDS SHA-256 replay passed.
- **Committed in:** `2b0c2b1`

---

**Total deviations:** 2 auto-fixed (1 Rule 1, 1 Rule 3)
**Impact on plan:** Both fixes were directly required for the specified test execution and durable reproducibility contract; no unrelated production paths were changed.

## Issues Encountered

- The full `tests/testthat` suite remains red only in later Phase 12 Wave 0 final-evaluation, promotion, and release contract tests whose production APIs are owned by Plans 03–08. These are recorded in `deferred-items.md`; all Plan 12-02-owned and inherited calibration safety checks pass.

## Known Stubs

None in Plan 12-02-owned files.

## User Setup Required

None - no external service configuration required.

## Verification Results

- Focused calibration suite: passed, 43 assertions, 0 failures, 0 warnings, 0 skips.
- Inherited cutoff suite: passed, 11 assertions.
- Inherited shared-scoring suite: passed, 47 assertions.
- Inherited seal suite: passed, 18 assertions.
- Fresh-process freeze/calibration artifact read-back: passed.
- Fresh-process persisted CSV/RDS byte replay: passed.
- No real WC2026 label artifact was accessed, inspected, created, or written; no final evaluation or promotion was performed.

## Next Phase Readiness

Plan 03 can consume the validated candidate/track calibrator APIs, provenance manifest rows, raw/calibrated view separation, and explicit raw fallback states. The sealed holdout remains unopened.

## Self-Check: PASSED

- Plan-owned implementation, test, and calibration artifact files exist.
- Task commits `4c351ec` and `2b0c2b1` exist in Git history.
- Focused, inherited, freeze, fresh-process, and persisted-byte checks passed.
- Unrelated pre-existing dirty Phase 10/11 benchmark/output paths remained unstaged.

---
*Phase: 12-calibration-promotion-and-model-release*
*Plan: 02*
*Completed: 2026-08-11*
