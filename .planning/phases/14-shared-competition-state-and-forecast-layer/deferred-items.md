# Phase 14 Plan 14-13 Deferred Items

## Pre-existing Phase 13 regression mismatch

- **Command:** `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_competition_registry.R", stop_on_failure=TRUE)'`
- **Result:** 4 failures, 151 passes, 0 warnings, 0 skips.
- **Failure:** The production-loading assertions at lines 757, 758, 770, and 771 compare the loader output with the legacy `phase13_normalized_fixture_schema()` / `phase13_normalized_result_schema()`, while the accepted snapshots currently expose the Phase 14 v2 schema (`source_group_id`, `group_id`, `kickoff_confirmed`, `confirmed_kickoff_at_utc`, `source_status`, and related lifecycle fields).
- **Scope:** This predates Plan 14-13 and is outside the allowed implementation files. No Phase 13 source, loader, fixture, or regression test was changed. Reconcile the v1/v2 contract in the owning Phase 13 work before marking that regression green.
