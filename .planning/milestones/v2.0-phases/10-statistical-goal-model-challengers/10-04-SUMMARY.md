---
phase: 10-statistical-goal-model-challengers
plan: "04"
subsystem: forecasting
tags: [r, dynamic-poisson, chronology, elo, mean-reversion, testthat]

requires:
  - phase: 09-rolling-tournament-benchmark-harness
    provides: Date-complete boundaries, frozen importance treatment, G=40 support, and shared cutoff regressions
  - phase: 10-statistical-goal-model-challengers
    provides: Canonical dynamic pair, tuning registries, feature contract, and RED behavior contracts from Plans 10-09 and 10-10
provides:
  - Deterministic predict-before-update dynamic attack and defence state replay
  - Continuous inactivity reversion around a fixed global pseudo-exposure
  - Prior-tournament pseudo-exposure selection and canonical point-in-time Elo nesting
  - Dynamic manifests with state, tuning, eligible-ID, Elo-value, and provenance hashes
affects: [10-06, 10-08, STAT-02, phase12-model-release]

tech-stack:
  added: []
  patterns: [immutable-matchday-snapshots, decayed-sufficient-statistics, fixed-global-pseudo-exposure, canonical-elo-offset]

key-files:
  created:
    - R/forecast/dynamic_goal_ability.R
  modified: []

key-decisions:
  - "Represent dynamic evidence as decayed GF, GA, and W sufficient statistics while keeping global pseudo-exposure fixed, so inactivity continuously removes team effects without deleting history."
  - "Select pseudo-exposure by equal-weight completed-prior-tournament updating RPS and break numerical ties toward the largest pseudo-exposure."
  - "Fit Elo only as one signed adapter-supplied point-in-time increment over immutable standalone dynamic log-means; no raw rating history or reconstructed lookup is accepted."

patterns-established:
  - "Date batch contract: decay once, predict every fixture from one immutable snapshot, aggregate all observed regulation outcomes, then update once."
  - "Nested dynamic pair: the Elo sibling preserves parent dynamic_log_mu_home and dynamic_log_mu_away exactly and applies symmetric signed Elo increments."

requirements-completed: [STAT-02]

coverage:
  - id: D1
    description: Deterministic dynamic state replay is row-order invariant, strictly prior-only, all-history preserving, continuously mean-reverting, and complete for unseen teams.
    requirement: STAT-02
    verification:
      - kind: unit
        ref: tests/testthat/test_statistical_dynamic_state.R (20 expectations)
        status: pass
      - kind: integration
        ref: tests/testthat/test_benchmark_cutoffs.R (11 expectations)
        status: pass
    human_judgment: false
  - id: D2
    description: Prior-only pseudo-exposure tuning and canonical Elo nesting are poisoning-resistant, track-shared, provenance-checked, and manifest-auditable.
    requirement: STAT-02
    verification:
      - kind: unit
        ref: tests/testthat/test_statistical_dynamic_tuning.R (25 expectations)
        status: pass
    human_judgment: false

duration: 9 min
completed: 2026-07-22
status: complete
---

# Phase 10 Plan 04: Dynamic Goal-Ability Challengers Summary

**Date-batched dynamic attack/defence states now decay continuously toward a fixed global prior, with prior-only pseudo-exposure tuning and a provenance-checked nested Elo sibling.**

## Performance

- **Duration:** 9 min
- **Started:** 2026-07-22T14:17:04Z
- **Completed:** 2026-07-22T14:25:55Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments

- Implemented stable team-keyed `GF`, `GA`, and `W` sufficient statistics, immutable same-date prediction snapshots, complete-date aggregation, all-history decay, fixed pseudo-exposure, and cold-start evidence.
- Implemented prior-edition equal-tournament RPS selection over pseudo-exposures, with the selected identity reused across frozen and updating tracks and stronger-shrinkage tie-breaking.
- Added one signed canonical Elo term over unchanged dynamic parent means, strict source/value/imputation/chronology validation, assessed-label poisoning resistance, and complete provenance manifests.

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement deterministic matchday-batch state and inactivity reversion** — `e2b5f7c` (feat)
2. **Task 2: Add the nested Elo variant and prior-only dynamic tuning** — `2bc739f` (feat)

The RED contracts were previously committed by Plan 10-10 in `d58fd17`; these two commits are the owning GREEN implementations.

## Files Created/Modified

- `R/forecast/dynamic_goal_ability.R` — Dynamic sufficient-state initialization, decay, batch prediction/update, replay, pseudo-exposure tuning, Elo-coefficient fitting, and manifest evidence.

## Decisions Made

- Kept the global prior goal rate and pseudo-exposure fixed while decaying only observed evidence. This makes the inactivity limit explicit: attack and defence log-effects converge to zero while historical match counts remain intact.
- Used complete prior inner tournaments as the tuning unit and averaged their updating-track RPS equally. Candidate traversal and the largest-pseudo-exposure tie-break are deterministic.
- Required all six canonical Elo columns and strict source-date chronology before fitting or prediction. The implementation contains no direct raw Elo file read, history join, reconstruction, or nearest-date lookup.

## Tuning and Invariance Evidence

- Candidate pseudo-exposure RPS values: `2 → 0.2848622091`, `4 → 0.2644544060`, `8 → 0.2543661213`, `16 → 0.2494418985`, `32 → 0.2470234235`.
- Selected setting: pseudo-exposure `32`, half-life `730` days, objective RPS `0.247023423457`.
- Signed Elo coefficient: `0.0166784863805`; convergence status `converged`; maximum eligible Elo source date `2006-06-10`.
- Assessed-outcome poisoning: settings identical, Elo fit identical, and frozen predictions identical.
- Unseen-team check: one fixture retained, both means equal the `1.25` global prior, and `cold_start = TRUE`.
- Dynamic-state tests serialize normal and reversed same-date rows byte-identically; a result changes only a later-date prediction.
- Twenty-year inactivity reduces the tested log-scale effect below `1e-2` while retaining the original history count.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Resolved the canonical feature contract from test and project working directories**
- **Found during:** Task 2 focused GREEN verification
- **Issue:** The first implementation treated the feature-contract path as relative to the process working directory, but `testthat::test_file()` executes from `tests/testthat`.
- **Fix:** Added deterministic project-root resolution while retaining an injectable explicit contract path.
- **Files modified:** `R/forecast/dynamic_goal_ability.R`
- **Verification:** `test_statistical_dynamic_tuning.R` passes from the standard project-root command.
- **Committed in:** `2bc739f`

**2. [Rule 1 - Bug] Validated the canonical `required` field instead of a nonexistent `active` field**
- **Found during:** Task 2 feature-contract validation
- **Issue:** The initial validator used an `active` column not present in the frozen Phase 10 feature-contract schema.
- **Fix:** Require the unique open-core `elo_diff` row and its canonical `required = TRUE` declaration.
- **Files modified:** `R/forecast/dynamic_goal_ability.R`
- **Verification:** All provenance acceptance and rejection tests pass.
- **Committed in:** `2bc739f`

**3. [Rule 2 - Missing Critical] Kept cold-start state-age evidence finite**
- **Found during:** Task 2 contract audit
- **Issue:** An unseen team initially emitted infinite state age, conflicting with the feature contract's finite global-prior fallback requirement.
- **Fix:** Emit age zero with missing source date, zero observed exposure, zero shrinkage weight, and explicit cold-start status.
- **Files modified:** `R/forecast/dynamic_goal_ability.R`
- **Verification:** The unseen-team fixture remains forecastable at finite global means.
- **Committed in:** `2bc739f`

---

**Total deviations:** 3 auto-fixed (2 bugs, 1 missing critical evidence requirement).
**Impact on plan:** All fixes preserve the planned model and strengthen deterministic path handling, schema fidelity, and finite cold-start evidence; no model, benchmark, or dependency scope was added.

## Issues Encountered

None beyond the auto-fixed implementation issues above.

## Verification Results

- `test_statistical_dynamic_state.R`: 20 expectations passed.
- `test_statistical_dynamic_tuning.R`: 25 expectations passed.
- `test_benchmark_cutoffs.R`: 11 expectations passed.
- Total focused and inherited checks: 56 passed, 0 failed, 0 warnings.
- Static scan found no direct `elo_ratings.csv` read, raw Elo join, nearest-date reconstruction, promotion evaluator, or WC2026 outcome path.
- Canonical registry contains both `dynamic_goal_ability` and `dynamic_goal_ability_elo` with the latter nested on the former.
- No full historical tournament benchmark, target graph, shortlist, promotion evaluation, or release action ran.

## TDD Gate Compliance

- RED contracts: `d58fd17` from Plan 10-10, failing only on the five owning Task 1/Task 2 APIs.
- Task 1 GREEN: `e2b5f7c`.
- Task 2 GREEN: `2bc739f`.
- Final state, tuning, and inherited cutoff suites all pass.

## Known Stubs

None. The `feature_contract_path = NULL` default is intentional: it triggers deterministic project-root resolution and does not disable validation.

## User Setup Required

None - no external service configuration or package installation required.

## Next Phase Readiness

- Plans 10-06 and 10-08 can dispatch the two registered dynamic candidates through the canonical adapter and historical benchmark without redefining chronology, tuning, Elo provenance, or manifest semantics.
- STAT-02 implementation is complete at the model layer; the full tournament benchmark and any shortlist decision remain intentionally deferred to their owning plans.

## Self-Check: PASSED

- Verified `R/forecast/dynamic_goal_ability.R` and this summary exist on disk.
- Verified task commits `e2b5f7c` and `2bc739f` exist in repository history.
- Re-ran both focused suites and the inherited cutoff regression with 56 passing expectations.
- Confirmed the unrelated config, research cache, design-audit output, and Elo-decision report remain unstaged and untouched.

---
*Phase: 10-statistical-goal-model-challengers*
*Completed: 2026-07-22*
