---
phase: 19-independent-club-forecast-authority
plan: "09"
subsystem: orchestration
tags: [r, targets, club-authority, fail-closed, canonical-v2, tdd]

# Dependency graph
requires:
  - phase: 19-08
    provides: Immutable fixture/production club release authority and bidirectional domain guards
provides:
  - Closed production/fixture club evaluation controller with durable blocked-run evidence
  - Separate validate-before-consume club target namespace and blocked target state
  - Automated CLI, DAG, dependency-isolation, idempotency, and fixture-release verification
affects: [19-10, phase-20, phase-21, club-forecast-consumers]

# Tech tracking
tech-stack:
  added: []
  patterns: [explicit trusted-root CLI modes, isolated targets runtime environment, typed blocked target states, validate-before-consume file edges]

key-files:
  created:
    - scripts/run_phase19_club_evaluation.R
  modified:
    - _targets.R
    - tests/testthat/test_phase19_club_pipeline.R

key-decisions:
  - "Production has no caller-selectable evidence roots: it resolves only fixed Phase 18 and reviewed club authority paths and writes a deterministic blocked record before model work when authority is absent."
  - "Fixture mode is explicit, process-temporary, disjoint from the project, and permanently fixture-ineligible even when the complete evaluation/release mechanics pass."
  - "The club target graph runs in a child environment whose parent is globalenv() so canonical lookup remains available without importing the pre-existing legacy Phase 12 mutual cycle into targets' import graph."
  - "Independent fixture subprocesses remain separate for idempotency and credential/path-leakage evidence; no cache was introduced that could weaken deterministic replay coverage."

patterns-established:
  - "Controller authority order: accepted history -> current UCL/identity -> owner policy -> owner folds -> evaluation -> promotion -> release/selector."
  - "Every club target consumer receives a typed validated predecessor, while file-backed protocol, fold, evaluation, release, and selector artifacts remain explicit targets."
  - "A missing production authority is represented as human_needed/blocked with a stable reason code and cannot create model, release, or selector authority."

requirements-completed: [CLUBMOD-01, CLUBMOD-02, CLUBMOD-03, CLUBMOD-05]

coverage:
  - id: D1
    description: "Closed club controller executes the full isolated fixture mechanics and fails closed in production before model work when accepted authority is missing."
    requirement: CLUBMOD-01
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase19_club_pipeline.R#production controller and explicit fixture release tests"
        status: pass
      - kind: other
        ref: "rtk proxy Rscript --vanilla scripts/run_phase19_focused_test.R tests/testthat/test_phase19_club_pipeline.R (7 tests, 47 assertions)"
        status: pass
    human_judgment: false
  - id: D2
    description: "A separate club_* targets namespace exposes validated history/current/identity/policy/fold/evaluation/release/selector edges without named national or legacy Phase 12 authority dependencies."
    requirement: CLUBMOD-02
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase19_club_pipeline.R#validated club-only authority chain"
        status: pass
      - kind: other
        ref: "targets::tar_manifest(fields=c(name, command), callr_function=NULL, script=\"_targets.R\") (88 targets)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Production and target execution preserve a truthful blocked state without a production club release or selector; genuine Phase 18 and owner-review evidence is still required."
    requirement: CLUBMOD-04
    verification:
      - kind: integration
        ref: "blocked controller/target assertions: reason no_accepted_club_history, status human_needed/blocked, no selector"
        status: pass
    human_judgment: true
    rationale: "Automation proves the fail-closed behavior, but production acceptance cannot be judged complete until real accepted Phase 18 history/current-UCL generations and owner-approved policy/fold reviews exist."

# Metrics
duration: 2h 10m
completed: 2026-09-20
status: complete
---

# Phase 19 Plan 09: Club Orchestration and Blocked Production Summary

**Fail-closed club controller and isolated `club_*` targets chain with fixture-only release mechanics and truthful blocked production state**

## Performance

- **Duration:** 2h 10m
- **Started:** 2026-09-20T21:10:40Z
- **Completed:** 2026-09-20T23:20:59Z
- **Tasks:** 2 completed (strict RED -> GREEN)
- **Files modified:** 3 implementation/test files

## Accomplishments

- Added one closed Phase 19 controller. Default production execution resolves only fixed trusted authority locations, emits an atomic typed `human_needed` record for the first missing authority, and leaves model, release, and selector authority untouched. Explicit fixture execution runs the actual club history/current snapshot, rating, model, fold, score, evaluation, promotion, and fixture-release path under disjoint temporary roots, while preserving `pass` + `fixture_ineligible` + `ineligible_fixture` semantics.
- Added a separate `club_*` targets subgraph with explicit file targets and validation-before-consume edges from Phase 18 history/current UCL/identity through policy/fold review, rating, candidate models, fold scoring, promotion, release, and selector state. Blocked production is a typed target result and cannot fabricate release or selector files.
- Added subprocess, target-manifest, blocked-runtime, dependency-isolation, root/domain attack, deterministic replay, and fixture-release assertions. The focused runner passed 7 tests and 47 assertions; the manifest loaded 88 targets; the blocked target runtime completed with `no_accepted_club_history`.

## Task Commits

Each task was committed atomically:

1. **Task 19-09-01 RED: controller tests** - `30ca9db` (`test`)
2. **Task 19-09-01 GREEN: club authority controller** - `7f4ec23` (`feat`)
3. **Task 19-09-02 RED: target graph tests** - `40d984d` (`test`)
4. **Task 19-09-02 GREEN: club target chain** - `a284648` (`feat`)

**Plan metadata:** recorded in the final docs commit after state and roadmap updates.

## Files Created/Modified

- `scripts/run_phase19_club_evaluation.R` - Closed production/fixture controller, root and mode guards, atomic blocked record, full fixture evaluation/release path, and stable result vocabulary.
- `_targets.R` - Isolated Phase 19 source registrations, runtime environment, file targets, validated club authority chain, and typed blocked/release/selector state targets.
- `tests/testthat/test_phase19_club_pipeline.R` - CLI behavior, attack rejection, deterministic fixture replay, target manifest/dependency, blocked runtime, and file-target tests.

## Decisions Made

- Production remains fail-closed and `human_needed` until genuine accepted Phase 18 history plus current-UCL/identity generations and owner-approved protocol/fold reviews are available.
- Fixture evidence is sufficient to prove mechanics only; its release and selector remain permanently non-production and cannot satisfy CLUBMOD-04.
- Independent full fixture subprocesses are retained for replay/idempotency evidence. Profiling showed approximately 150 seconds per isolated fixture run, with about 97% in canonical Phase 18 hashing/join work; caching or collapsing those runs would weaken the independent determinism and leakage checks.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking issue] Isolated the targets import environment**
- **Found during:** Task 19-09-02 GREEN
- **Issue:** The initial full `_targets.R` graph import failed `igraph::is_dag(graph) is not TRUE` because targets scanned a pre-existing Phase 12 mutual import cycle through `globalenv()`.
- **Fix:** Added `phase19_target_runtime_envir <- new.env(parent = globalenv())` and configured `tar_option_set(envir=...)`, preserving source lookup while excluding unrelated legacy imports from the Phase 19 graph.
- **Files modified:** `_targets.R`
- **Verification:** Manifest loads with 88 targets; blocked `tar_make` completes and returns `no_accepted_club_history`; focused pipeline tests pass.
- **Committed in:** `a284648`

**2. [Rule 3 - Blocking issue] Anchored target tests to the project root**
- **Found during:** Task 19-09-02 GREEN
- **Issue:** `testthat::test_file()` changes the working directory to `tests/testthat`, so project-relative `_targets.R` source registrations failed during manifest/runtime checks.
- **Fix:** Wrapped manifest and blocked-runtime target calls in `withr::local_dir(phase19_pipeline_root)`.
- **Files modified:** `tests/testthat/test_phase19_club_pipeline.R`
- **Verification:** Focused runner passes 7 tests and 47 assertions; manifest and blocked runtime checks pass.
- **Committed in:** `a284648`

---

**Total deviations:** 2 auto-fixed Rule 3 blocking issues.
**Impact on plan:** Both fixes were required to execute the declared target graph without importing unrelated legacy authority or depending on testthat's transient working directory. No national authority edge or fail-closed assertion was weakened.

## Issues Encountered

- A transient `.git/index.lock` permission error occurred during staging; no lock was removed, and the retry staged only the intended task files.
- The pre-existing missing `outputs/releases/phase12-wc2026-incumbent-retained-v1/model/approved_model.rds` remains untouched. Any dependent national regression remains truthfully blocked; no artifact was fabricated.
- No network, credentials, package installation, or external service configuration was used.

## Known Stubs

None. The fixture calibration point-mass grid and blocked fold/review states are explicit, marker-bound diagnostic/authority gates; they do not flow into production authority and are covered by the fixture-ineligible/fail-closed assertions.

## User Setup Required

None for the implementation mechanics. Production still requires operator-provided lawful Phase 18 source acceptance, club identity mappings, historical coverage, policy review, and fold review before a real selector can resolve.

## Next Phase Readiness

The executable orchestration and target graph are ready for Plan 19-10 adversarial/regression coverage. Phase 19 remains `human_needed`, and CLUBMOD-04 remains pending until genuine accepted Phase 18 history/current-UCL evidence and owner-approved protocol/fold reviews produce an immutable production club selector. National regression is also blocked by the pre-existing missing Phase 12 approved model artifact.

---
*Phase: 19-independent-club-forecast-authority*
*Plan: 09*
*Completed: 2026-09-20*

## Self-Check: PASSED

- Summary file exists at the required path.
- Commits `30ca9db`, `7f4ec23`, `40d984d`, and `a284648` exist in git history.
- Final focused tests, target manifest, blocked target runtime, and `git diff --check` passed before documentation updates.
