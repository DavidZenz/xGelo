# Deferred Items

- The required `tests/testthat/test_worldcup_dashboard.R` regression command remains blocked by the pre-existing Phase 12 release resolver error: `Phase 12 release resolution is ambiguous or missing` at `test_worldcup_dashboard.R:704`. This is outside Plan 17-02 scope and was not changed.
## Plan 17-03

- Pre-existing regression blocker: `tests/testthat/test_phase13_publication_hashes.R:196` cannot construct its seed because 156 fixture IDs are paired with zero-length normalized source columns. Phase 17 focused, transaction, integration, Nations League, EURO, and dry-run checks pass; no Phase 17 code was changed for this blocker.
