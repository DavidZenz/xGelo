# Phase 14 Plan 14-13 Deferred Items

## Resolved Phase 13 regression mismatch

- **Command:** `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_competition_registry.R", stop_on_failure=TRUE)'`
- **Original result:** 4 failures, 151 passes, 0 warnings, 0 skips.
- **Failure:** The production-loading assertions at lines 757, 758, 770, and 771 compare the loader output with the legacy `phase13_normalized_fixture_schema()` / `phase13_normalized_result_schema()`, while the accepted snapshots currently expose the Phase 14 v2 schema (`source_group_id`, `group_id`, `kickoff_confirmed`, `confirmed_kickoff_at_utc`, `source_status`, and related lifecycle fields).
- **Resolution:** The four production integration assertions now verify `phase14_normalized_fixture_schema()` and `phase14_normalized_result_schema()`. Existing Phase 13 v1 normalization and replay tests remain unchanged.
- **Verified result:** 226 passes, 0 failures, 0 warnings, 0 skips on 2026-08-17.
