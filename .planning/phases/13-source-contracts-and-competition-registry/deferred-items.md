# Deferred Items

## Plan 13-11 publication-manifest test harness

- **Observed:** `tests/testthat/test_phase13_publication_manifests.R` currently fails in five cases while seeding its temporary project because it passes the normalized accepted `fixtures.csv` table to `phase13_normalize_fixture_rows()`, which expects the source-shaped `source_fixture_id` column.
- **Scope:** This is an out-of-scope Plan 13-11 test-fixture seeding mismatch surfaced while checking the regenerated Plan 13-12 graph; it is not part of Plan 13-05 and was not changed here.
- **Impact:** The Plan 13-05 focused registry suite, production edition loader, identity loader, and fixture-backed normalized publication checks all pass. Plan 13-11 should update its seed helper to use source-shaped handoffs or the normalized publication path.
