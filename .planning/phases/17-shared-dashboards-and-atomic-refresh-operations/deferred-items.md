# Deferred Items

- The required `tests/testthat/test_worldcup_dashboard.R` regression command remains blocked by the pre-existing Phase 12 release resolver error: `Phase 12 release resolution is ambiguous or missing` at `test_worldcup_dashboard.R:704`. This is outside Plan 17-02 scope and was not changed.
## Plan 17-03

- Pre-existing regression blocker: `tests/testthat/test_phase13_publication_hashes.R:196` cannot construct its seed because 156 fixture IDs are paired with zero-length normalized source columns. Phase 17 focused, transaction, integration, Nations League, EURO, and dry-run checks pass; no Phase 17 code was changed for this blocker.

## Plan 17-04

- Pre-existing regression blocker: `tests/testthat/test_phase13_publication_manifests.R:201` reproduces the same 156-fixture/zero-length normalized-column seed failure as the Phase 13 publication-hash suite. No Phase 17 code or fixtures were changed.
- Pre-existing regression-contract blocker: the exact planned child command `scripts/build_euro_qualifying_outcomes.R --replay-check` exits before replay because the existing CLI requires `--edition-id`. No unrelated Phase 16 CLI contract was changed.
