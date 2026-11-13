# Integrate the recent dashboard repairs into master

## Scope

Integrate only the repairs from `7598061`, `8e15ec1`, and `a2ed84d` onto
`522e32fdc085586fb70120585605ce7e5d8cb7d0`. The originating branch contains
older CL development and model/data artifacts outside this merge request;
those changes remain excluded. Cherry-pick provenance is retained in the
integration commits.

The six dependency readers now stop at the nearest complete code root, and
source-registry migration follows the explicitly supplied accepted-data root.
The Phase 13 test setup uses the committed synthetic source captures, actual
approved selector, current CLI schemas, and the active R installation.

## Conflict resolution

- Preserve master's existing milestone state and add only the scoped recovery
  and regression observations to `.planning/STATE.md`.
- Retain master's absence of `docs/NON_WC_OPERATIONS.md`. That branch-only
  runbook depends on older operations work outside the selected commits; the
  self-contained repair plans under `.planning/operations/` remain included.
- Make the nested-workspace regression fixture load its form/rules dependencies
  explicitly and put the real rules module in each synthetic code root. This
  preserves both test cases on master's older refresh bootstrap.

## Verification

- Earlier full Phase 13 run: seven suites, 82 cases, 852 assertions; zero
  failures, errors, warnings or skips. All 35 compared repair/import/fixture
  files match that validated version byte for byte. Comparison evidence:
  `/private/tmp/xgelo-master-merge-phase13-code-equality.json`.
- Fresh master integration run: nested-workspace, publication-hash and
  publication-manifest suites; 14 cases, 207 assertions; zero failures, errors,
  warnings or skips. Evidence: `/private/tmp/xgelo-master-merge-tests.log` and
  `/private/tmp/xgelo-master-merge-tests.rds`.
- Focused accepted-root migration and missing-edition-authority tests passed
  seven assertions. Evidence: `/private/tmp/xgelo-master-merge-focused.log`.
- The complete `docs`, `data`, and `outputs` Git trees match the current public
  master commit. No dashboard/data/model artifacts are introduced by this merge.
- The original checkout's 46 pre-existing tracked changes retain the exact same
  bytes/deletion state and Git status. All merge operations use an owned clean
  worktree under `/private/tmp`.
- No production refresh, model fitting, or forecast simulation was run for
  integration. A master push invokes the normal Pages workflow with unchanged
  public artifact bytes.
