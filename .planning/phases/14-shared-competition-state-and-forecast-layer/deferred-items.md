# Deferred Items

## Pre-existing full-suite fixture-seed failures

- **Command:** `Rscript --vanilla -e 'testthat::test_dir("tests/testthat")'`
- **Contexts:** `test_phase13_publication_hashes.R`, `test_phase13_publication_manifests.R`
- **Result:** 10 failures before the default testthat maximum stopped the run.
- **Error:** Phase 13 fixture seed construction received 156 `uefa_source_fixture_id` values but zero-length normalized home/away/source columns, producing `arguments imply differing number of rows: 156, 0`.
- **Scope:** Pre-existing Phase 13 fixture/data-shape issue. The failure occurs before Phase 14 state code is loaded and is outside Plan 14-20; the Phase 14 focused gate, Phase 13 refresh-failure regression, and publication rollback regression pass.
