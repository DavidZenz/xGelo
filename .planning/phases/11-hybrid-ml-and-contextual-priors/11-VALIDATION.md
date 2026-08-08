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
| 11-01-01 | 01 | 0 | HYBRID-01 | T11-01 | RF outputs complete score distributions and cannot bypass the common adapter | unit + contract | `Rscript -e 'testthat::test_file("tests/testthat/test_hybrid_random_forest.R", stop_on_failure = TRUE, stop_on_warning = TRUE)'` | no - W0 | pending |
| 11-07-01 | 07 | 0 | HYBRID-01 | T11-26 | Verified project-local `ranger` 0.18.0 runtime exists before RF implementation | dependency + provenance | `rtk Rscript --vanilla -e 'source("R/benchmark/challenger_preflight.R"); x <- require_hybrid_environment(offline = TRUE); stopifnot(isTRUE(x$valid))'` | no - W0 | pending |
| 11-02-01 | 02 | 1 | HYBRID-01 | T11-06 | RF tracer consumes verified `ranger`, Phase 10 ability/Elo evidence, and common G=40 adapter | unit + integration | `Rscript -e 'testthat::test_file("tests/testthat/test_hybrid_random_forest.R", stop_on_failure = TRUE, stop_on_warning = TRUE)'` | no - W0 | pending |
| 11-03-01 | 03 | 2 | HYBRID-02 | T11-10 | Context values are point-in-time, provenance-tracked, centroid-parented, and common-panel eligible | unit | `Rscript -e 'testthat::test_file("tests/testthat/test_hybrid_context_features.R", stop_on_failure = TRUE, stop_on_warning = TRUE)'` | no - W0 | pending |
| 11-04-01 | 04 | 3 | HYBRID-03, HYBRID-04 | T11-14 | xG remains inactive when gates fail; structural snapshots are committed, vintage-safe, and only shrink sparse evidence | unit + integration | `Rscript -e 'testthat::test_file("tests/testthat/test_hybrid_xg_gate.R", stop_on_failure = TRUE, stop_on_warning = TRUE)'` and `Rscript -e 'testthat::test_file("tests/testthat/test_hybrid_structural_prior.R", stop_on_failure = TRUE, stop_on_warning = TRUE)'` | no - W0 | pending |
| 11-05-01 | 05 | 4 | HYBRID-05 | T11-18 | Squad and market modes remain separate, licensed, optional, and panel-correct | integration | `Rscript -e 'testthat::test_file("tests/testthat/test_hybrid_modes.R", stop_on_failure = TRUE, stop_on_warning = TRUE)'` | no - W0 | pending |
| 11-06-01 | 06 | 5 | HYBRID-01, HYBRID-02, HYBRID-03, HYBRID-04, HYBRID-05 | T11-22 | Target ancestry and bundle hashes preserve exact panels, runtime/source parents, and sealed-2026 boundaries | integration | `Rscript -e 'testthat::test_file("tests/testthat/test_hybrid_targets.R", stop_on_failure = TRUE, stop_on_warning = TRUE)'` | no - W0 | pending |

*Status: pending; green; failed; flaky. Plan IDs are the expected decomposition
for planner alignment and may be refined while preserving requirement coverage.*

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
