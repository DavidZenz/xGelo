---
phase: 14-shared-competition-state-and-forecast-layer
plan: "15"
subsystem: competition-state
tags: [form, national-team-xg, cutoff, provenance, tdd]

# Dependency graph
requires:
  - phase: 14-14
    provides: cutoff-safe universal standings and same-bundle official reconciliation
provides:
  - competition and all-senior international descriptive last-five form
  - registry-gated national-team xG adaptation and span-12 EWMA model form
  - strict exclusive cutoff validation with evidence lineage hashes
affects: [phase-14-forecast-consumers, phase-15-rules, shared-dashboard-consumers]

# Tech tracking
tech-stack:
  added: []
  patterns: [separate display/model form products, registry-approved evidence boundary, strict exclusive cutoff]

key-files:
  created:
    - data/competition/registries/national_team_xg_sources.csv
  modified:
    - R/competition/form.R
    - tests/testthat/test_phase14_form.R
    - tests/testthat/test_phase14_cutoffs.R

key-decisions:
  - "Keep competition last-five, all-senior last-five, and national-team xG EWMA as separate products."
  - "Do not fabricate current national-team xG: the no-accepted-source registry emits explicit unavailable/NA rows for Austria and Germany."
  - "Reject club rolling_form.csv, football-goal relabels, non-shot evidence, and non-exclusive point-in-time evidence at the adapter boundary."

patterns-established:
  - "Display form is descriptive football-result history with deterministic canonical lineage and no xG substitution."
  - "Model form is populated only from reviewed shot-derived senior-national-team rows with stable IDs, hashes, and strict cutoff evidence."

requirements-completed: [STATE-03, FORECAST-03]

# Coverage metadata
coverage:
  - id: D1
    description: "Competition and all-senior last-five display form with friendlies, lifecycle exclusions, canonical deduplication, and cutoff metadata"
    requirement: STATE-03
    verification:
      - kind: unit
        ref: "Rscript --vanilla -e 'testthat::test_file(\"tests/testthat/test_phase14_form.R\", stop_on_failure=TRUE)'"
        status: pass
    human_judgment: false
  - id: D2
    description: "Registry-gated optional national-team xG adapter and span-12 EWMA with explicit current unavailability"
    requirement: FORECAST-03
    verification:
      - kind: unit
        ref: "tests/testthat/test_phase14_form.R — accepted, unavailable, club-rejection, and goal-relabel boundary cases"
        status: pass
    human_judgment: false
  - id: D3
    description: "Strict exclusive timestamp/date-only cutoff validator and deterministic evidence lineage"
    requirement: FORECAST-03
    verification:
      - kind: unit
        ref: "Rscript --vanilla -e 'testthat::test_file(\"tests/testthat/test_phase14_cutoffs.R\", stop_on_failure=TRUE)'"
        status: pass
    human_judgment: false

# Metrics
duration: 39 min
completed: 2026-08-17
status: complete
---

# Phase 14 Plan 15: Shared competition state and honest forecast form summary

**Cutoff-safe competition/all-senior form plus registry-gated national-team xG EWMA with explicit unavailable evidence for current inputs**

## Performance

- **Duration:** 39 min
- **Started:** 2026-08-17T17:19:34Z
- **Completed:** 2026-08-17T17:58:16Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Implemented independent competition-edition and all-senior international last-five views with canonical match deduplication, accepted-lineage preference, friendlies retained, awarded/unplayed results excluded, football shootouts kept out of the result, deterministic ordering, cutoff metadata, and hashes.
- Added the durable national-team xG source registry and adapter. Only reviewed, registry-accepted, shot-derived senior-national-team rows with stable match/team/source lineage and point-in-time evidence can enter the model-form product.
- Implemented span-12 EWMA model form while preserving the explicit no-source path: current Austria and Germany rows are unavailable with `sample_count=0`, `source_id=NA`, retained cutoff, and `NA` xGF/xGA/xGD/EWMA values. Club `rolling_form.csv` and football-goal relabels are rejected.
- Locked 80 form assertions and 19 cutoff assertions green with zero failures, warnings, or skips.

## Task Commits

Each task was committed atomically:

1. **Task 14-15-01: Build separate competition and all-senior last-five views** — `f04e5d7` (test/RED), `69b567a` (feat/GREEN)
2. **Task 14-15-02: Declare optional national-team xG and build honest span-12 availability** — `d8dfbf0` (test/RED), `6f0d7c8` (feat/GREEN)

**Plan metadata:** final docs reconciliation commit created after this summary.

## Files Created/Modified

- `R/competition/form.R` — display form, registry validation, strict cutoff assertion, national-team xG adapter, unavailable rows, and span-12 EWMA builder.
- `data/competition/registries/national_team_xg_sources.csv` — self-hashed current inventory with no accepted production national-team xG artifact.
- `tests/testthat/test_phase14_form.R` — display, availability, accepted-source, provenance, club-rejection, goal-relabel, and reorder tests.
- `tests/testthat/test_phase14_cutoffs.R` — exclusive timestamp, date-only, missing-precision, tie, and production validator tests.

## Decisions Made

- Keep display last-five form independent from model-form EWMA; display result history never becomes xG evidence.
- Require a reviewed registry row, shot-derived basis, stable IDs/hashes, and strictly-before evidence for any future national-team xG source.
- Preserve unavailable/NA rather than zero-imputing Austria/Germany national-team xG while no accepted artifact exists.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed empty-history display metadata construction**
- **Found during:** Task 14-15-01 verification
- **Issue:** Empty team histories could produce invalid scalar latest-evidence metadata instead of a clean unavailable row.
- **Fix:** Normalized empty timestamp/date values to scalar `NA` fields and preserved the explicit unavailable contract.
- **Files modified:** `R/competition/form.R`
- **Verification:** Form suite passes zero-history, singleton, bounded, and full-history cases.
- **Committed in:** `69b567a`

**2. [Rule 3 - Blocking] Added a vectorized wide-history normalization path**
- **Found during:** Task 14-15-01 full-history verification
- **Issue:** Applying the long-row normalization loop to the 49,000-row production history made the required full-history verification impractically slow.
- **Fix:** Added a vectorized wide-row path while retaining the long team-match path used by accepted xG evidence.
- **Files modified:** `R/competition/form.R`
- **Verification:** Production Austria/Germany display-form test passes within the focused suite.
- **Committed in:** `69b567a`

**3. [Rule 3 - Blocking] Made the default registry lookup repository-root aware**
- **Found during:** Task 14-15-02 verification from `tests/testthat`
- **Issue:** Relative registry lookup resolved against the test directory and failed despite the durable registry existing at the repository root.
- **Fix:** Added project-root discovery for default and relative registry paths.
- **Files modified:** `R/competition/form.R`
- **Verification:** Both direct test-file invocations pass from the repository root and registry validation is silent.
- **Committed in:** `6f0d7c8`

**4. [Rule 2 - Missing Critical] Added fail-closed protection against football goals relabelled as xG**
- **Found during:** Task 14-15-02 evidence-boundary review
- **Issue:** A source could declare `shot_derived` while copying football goal columns into xGF/xGA.
- **Fix:** Reject fully goal-identical xG rows before adaptation and add a regression test.
- **Files modified:** `R/competition/form.R`, `tests/testthat/test_phase14_form.R`
- **Verification:** Goal-relabel boundary assertion passes; accepted shot-derived fixture evidence still produces finite EWMA values.
- **Committed in:** `6f0d7c8`

**Total deviations:** 4 auto-fixed (1 Rule 1, 2 Rule 3, 1 Rule 2)
**Impact on plan:** All fixes reinforce correctness, performance, or the required evidence boundary; no unrelated files were changed.

## Issues Encountered

None remaining. No stubs, skipped tests, or unrun plan verifications were left behind.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

The downstream forecast and dashboard consumers can use the separate display/model form contracts and must preserve the current unavailable/NA state until a reviewed national-team xG artifact is added to the registry. No blocker remains for the plan.

---
*Phase: 14-shared-competition-state-and-forecast-layer*
*Completed: 2026-08-17*

## Self-Check: PASSED

- Summary file exists at the expected phase path.
- Task commits `f04e5d7`, `69b567a`, `d8dfbf0`, and `6f0d7c8` exist in git history.
