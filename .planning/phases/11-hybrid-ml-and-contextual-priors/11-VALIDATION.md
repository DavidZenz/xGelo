---
phase: 11
slug: hybrid-ml-and-contextual-priors
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-08
---

# Phase 11 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `testthat 3.3.2` |
| **Config file** | none dedicated; suite is driven from `tests/testthat/` |
| **Quick run command** | `Rscript -e 'testthat::test_file("tests/testthat/test_hybrid_random_forest.R", stop_on_failure = TRUE, stop_on_warning = TRUE)'` |
| **Full suite command** | `Rscript -e 'testthat::test_dir("tests/testthat", stop_on_failure = TRUE, stop_on_warning = TRUE)'` |
| **Estimated runtime** | quick checks under 60 seconds; full suite depends on benchmark fixtures and targets |

## Sampling Rate

- **After every task commit:** Run the most local new Phase 11 test file plus any touched benchmark regression file.
- **After every plan wave:** Run all Phase 11 tests plus `test_benchmark_pipeline.R` and `test_benchmark_contracts.R`.
- **Before `/gsd:verify-work`:** The complete `tests/testthat` suite must be green with warnings treated as failures.
- **Max feedback latency:** 120 seconds for focused tests; full benchmark execution is an explicit wave or final-gate operation.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 11-01-01 | 01 | 0 | HYBRID-01, HYBRID-02 | T11-01, T11-02 | RF/context RED contracts lock G=40 distribution, dynamic ability/Elo evidence, strict context provenance, and no silent context imputation | RED unit + contract | `Rscript -e 'testthat::test_file("tests/testthat/test_hybrid_random_forest.R", stop_on_failure = TRUE, stop_on_warning = TRUE)'`<br>`Rscript -e 'testthat::test_file("tests/testthat/test_hybrid_context_features.R", stop_on_failure = TRUE, stop_on_warning = TRUE)'` | no - W0 creates tests/helper | pending |
| 11-01-02 | 01 | 0 | HYBRID-03, HYBRID-04 | T11-03 | xG and structural RED contracts lock fail-closed xG activation and vintage-safe continuous shrinkage | RED unit + contract | `Rscript -e 'testthat::test_file("tests/testthat/test_hybrid_xg_gate.R", stop_on_failure = TRUE, stop_on_warning = TRUE)'`<br>`Rscript -e 'testthat::test_file("tests/testthat/test_hybrid_structural_prior.R", stop_on_failure = TRUE, stop_on_warning = TRUE)'` | no - W0 creates tests/helper | pending |
| 11-01-03 | 01 | 0 | HYBRID-05, HYBRID-01..05 | T11-04, T11-05 | Mode and target RED contracts lock mode separation, no restricted raw publication, no live collection, exact panels, checksums, and research-only sealed bundle flags | RED integration + contract | `Rscript -e 'testthat::test_file("tests/testthat/test_hybrid_modes.R", stop_on_failure = TRUE, stop_on_warning = TRUE)'`<br>`Rscript -e 'testthat::test_file("tests/testthat/test_hybrid_targets.R", stop_on_failure = TRUE, stop_on_warning = TRUE)'` | no - W0 creates tests/helper | pending |
| 11-07-01 | 07 | 0 | HYBRID-01 | T11-26, T11-27, T11-28 | Verified project-local `ranger` 0.18.0 runtime exists before RF implementation and offline replay is provable | dependency + provenance | `rtk Rscript --vanilla -e 'source("R/benchmark/challenger_preflight.R"); p <- capture_ranger_package_provenance(package = "ranger", version = "0.18.0", install = TRUE, output_path = "data/benchmark/phase11/ranger_provenance.csv", archive_path = "data/cache/phase11-cran/ranger_0.18.0.tar.gz", library_path = "data/cache/phase11-library"); stopifnot(isTRUE(p$valid)); .libPaths(c(normalizePath("data/cache/phase11-library", mustWork = TRUE), .libPaths())); stopifnot(identical(as.character(utils::packageVersion("ranger")), "0.18.0"), isTRUE(verify_ranger_package_archive(p)), length(inventory_cran_dependencies(p)$unexpected) == 0L, grepl("^[0-9a-f]{64}$", hash_installed_package_contents("ranger", lib.loc = "data/cache/phase11-library"))); x <- require_hybrid_environment(); stopifnot(isTRUE(x$valid)); targets::tar_manifest()'`<br>`rtk Rscript --vanilla -e 'source("R/benchmark/challenger_preflight.R"); .libPaths(c(normalizePath("data/cache/phase11-library", mustWork = TRUE), .libPaths())); x <- require_hybrid_environment(offline = TRUE); stopifnot(isTRUE(x$valid), identical(as.character(utils::packageVersion("ranger")), "0.18.0"))'` | no - W0 creates dependency artifacts | pending |
| 11-02-01 | 02 | 1 | HYBRID-01 | T11-06, T11-07, T11-08 | RF tracer consumes verified `ranger`, Phase 10 ability/Elo evidence, and common G=40 adapter without direct 1X2-primary output | unit + integration | `Rscript -e 'testthat::test_file("tests/testthat/test_hybrid_random_forest.R", stop_on_failure = TRUE, stop_on_warning = TRUE)'` | no - depends on W0 | pending |
| 11-02-02 | 02 | 1 | HYBRID-01 | T11-09, T11-SC | RF settings, NB dispersion, seeds, and package provenance are registered and fail closed on unregistered runtime drift | unit + registry | `Rscript -e 'testthat::test_file("tests/testthat/test_hybrid_random_forest.R", stop_on_failure = TRUE, stop_on_warning = TRUE)'` | no - depends on W0 | pending |
| 11-03-01 | 03 | 2 | HYBRID-02 | T11-10, T11-12, T11-13 | Context values are point-in-time, provenance-tracked, centroid-parented, and common-panel eligible | unit | `Rscript -e 'testthat::test_file("tests/testthat/test_hybrid_context_features.R", stop_on_failure = TRUE, stop_on_warning = TRUE)'` | no - depends on W0 | pending |
| 11-03-02 | 03 | 2 | HYBRID-02 | T11-11, T11-12 | Context bundle and individual ablations are registered without changing the 630 open denominator | unit + registry | `Rscript -e 'testthat::test_file("tests/testthat/test_hybrid_context_features.R", stop_on_failure = TRUE, stop_on_warning = TRUE)'` | no - depends on W0 | pending |
| 11-04-01 | 04 | 3 | HYBRID-03 | T11-14 | xG remains inactive when coverage, variance, or provenance gates fail; common benchmark contracts remain valid | unit + regression | `Rscript -e 'testthat::test_file("tests/testthat/test_hybrid_xg_gate.R", stop_on_failure = TRUE, stop_on_warning = TRUE)'`<br>`Rscript -e 'testthat::test_file("tests/testthat/test_benchmark_contracts.R", stop_on_failure = TRUE, stop_on_warning = TRUE)'` | no - depends on W0 | pending |
| 11-04-02 | 04 | 3 | HYBRID-04 | T11-15, T11-17, T11-SC | Structural source snapshots are committed, checksum-backed, licensed, and vintage-safe before prior use | unit + snapshot | `Rscript -e 'testthat::test_file("tests/testthat/test_hybrid_structural_prior.R", stop_on_failure = TRUE, stop_on_warning = TRUE)'` | no - depends on W0 | pending |
| 11-04-03 | 04 | 3 | HYBRID-04 | T11-16, T11-17 | Structural information affects only sparse evidence through continuous registered shrinkage, not raw RF predictors | unit | `Rscript -e 'testthat::test_file("tests/testthat/test_hybrid_structural_prior.R", stop_on_failure = TRUE, stop_on_warning = TRUE)'` | no - depends on W0 | pending |
| 11-05-01 | 05 | 4 | HYBRID-05 | T11-18, T11-20 | Enriched squad mode stays derived-only, feature-rich labelled, locally snapshotted, and non-promotional | integration + regression | `Rscript -e 'testthat::test_file("tests/testthat/test_hybrid_modes.R", stop_on_failure = TRUE, stop_on_warning = TRUE)'`<br>`Rscript -e 'testthat::test_file("tests/testthat/test_transfermarkt_benchmark.R", stop_on_failure = TRUE, stop_on_warning = TRUE)'` | no - depends on W0 | pending |
| 11-05-02 | 05 | 4 | HYBRID-05 | T11-19, T11-21, T11-SC | Manual external market snapshots require timestamp, license, checksum, no redistribution breach, and no live collection path | integration | `Rscript -e 'testthat::test_file("tests/testthat/test_hybrid_modes.R", stop_on_failure = TRUE, stop_on_warning = TRUE)'` | no - depends on W0 | pending |
| 11-06-01 | 06 | 5 | HYBRID-01, HYBRID-02, HYBRID-03, HYBRID-04, HYBRID-05 | T11-22, T11-24, T11-25 | Runner, comparisons, and shortlist preserve mode separation, exact panels, evidence hashes, sealed-2026, and Phase 12-only authority | integration | `Rscript -e 'testthat::test_file("tests/testthat/test_hybrid_targets.R", stop_on_failure = TRUE, stop_on_warning = TRUE)'` | no - depends on W0 | pending |
| 11-06-02 | 06 | 5 | HYBRID-01, HYBRID-02, HYBRID-03, HYBRID-04, HYBRID-05 | T11-23, T11-SC | Target ancestry and canonical bundle publication preserve exact panels, runtime/source parents, checksums, and research-only sealed boundaries | integration + targets | `Rscript -e 'testthat::test_file("tests/testthat/test_hybrid_targets.R", stop_on_failure = TRUE, stop_on_warning = TRUE)'`<br>`Rscript -e 'targets::tar_make(benchmark_phase11_bundle_files)'`<br>`Rscript -e 'source("R/benchmark/hybrid_runner.R"); validate_hybrid_challenger_bundle("outputs/benchmarks/rolling_tournaments/phase11-hybrid-challengers")'` | no - depends on W0 | pending |

*Status: pending; green; failed; flaky. Task IDs mirror the current XML task graph from every Phase 11 PLAN.md.*

## Wave 0 Requirements

- [ ] `tests/testthat/test_hybrid_random_forest.R` - HYBRID-01 contract and fixture tests
- [ ] `tests/testthat/test_hybrid_context_features.R` - HYBRID-02 context and leakage tests
- [ ] `tests/testthat/test_hybrid_xg_gate.R` - HYBRID-03 fail-closed activation tests
- [ ] `tests/testthat/test_hybrid_structural_prior.R` - HYBRID-04 vintage and shrinkage tests
- [ ] `tests/testthat/test_hybrid_modes.R` - HYBRID-05 mode and provenance tests
- [ ] `tests/testthat/test_hybrid_targets.R` - target DAG, bundle-chain, and sealed-panel regression
- [ ] `data/benchmark/phase11/ranger_provenance.csv`, `data/cache/phase11-cran/ranger_0.18.0.tar.gz`, and `data/cache/phase11-library/ranger/` - install or vendor the registered `ranger` dependency before RF implementation; preserve the project-local dependency pattern and offline replay proof
- [ ] `data/benchmark/phase11/country_centroids.csv` and `data/benchmark/phase11/country_centroids_metadata.csv` - committed open geography registry for deterministic `travel_km`
- [ ] `data/benchmark/phase11/structural_sources.csv`, `data/benchmark/phase11/structural_sources_metadata.csv`, and `data/benchmark/phase11/structural_sources_checksums.csv` - committed structural source snapshots for HYBRID-04

Wave 0 task coverage:

- `11-01-01` creates RF/context RED tests and helper fixtures.
- `11-01-02` creates xG/structural RED tests and helper fixtures.
- `11-01-03` creates mode/target RED tests and helper fixtures.
- `11-07-01` creates the `ranger` provenance/archive/local-library dependency artifacts consumed by `11-02`.

Sampling continuity:

- Every executable task has at least one `<automated>` verification command.
- No consecutive executable task lacks automated verification; the maximum gap is 0 tasks.
- Wave 0 covers all missing Phase 11 test references before production implementation and covers the required RF runtime dependency before Wave 1.
- Later waves reuse the Wave 0 contract files with focused task-local commands plus added benchmark regressions where the plan text promises them.

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| External bookmaker snapshot is legally usable and correctly labelled | HYBRID-05 | Licensing and source permission cannot be inferred solely from numeric schema checks | Review the frozen snapshot's source, timestamp, license, checksum, and redistribution status; reject the external mode if any field is missing. |
| Structural source mapping is substantively faithful to the selected HGR-inspired variables | HYBRID-04 | Historical source interpretation and literature mapping require human review | Review the committed source registry, vintages, indicator definitions, and transformation notes before benchmark execution. |

## Validation Sign-Off

- [ ] All tasks have an automated verification command or an explicit Wave 0 dependency.
- [ ] Sampling continuity: no three consecutive tasks without automated verification.
- [ ] Wave 0 covers all missing Phase 11 test references.
- [ ] No watch-mode flags.
- [ ] Focused feedback latency remains below 120 seconds.
- [ ] `nyquist_compliant: true` set after Wave 0 tests and plan mapping are verified.

**Approval:** pending
