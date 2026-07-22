---
phase: 10
slug: statistical-goal-model-challengers
status: approved
nyquist_compliant: true
wave_0_complete: false
created: 2026-07-22
---

# Phase 10 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `testthat` 3.3.2 |
| **Config file** | `tests/testthat.R`, `tests/testthat/helper_benchmark.R`; Wave 0 adds `tests/testthat/helper_statistical_challengers.R` |
| **Quick run command** | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_benchmark_baselines.R", reporter = "summary", stop_on_failure = TRUE, stop_on_warning = TRUE)'` |
| **Full suite command** | `rtk Rscript --vanilla -e 'testthat::test_dir("tests/testthat", reporter = "summary", stop_on_failure = TRUE, stop_on_warning = TRUE)'` |
| **Core coverage command** | `rtk Rscript --vanilla -e 'source("tests/testthat/phase10_core_coverage.R"); x <- run_phase10_core_coverage(); stopifnot(all(x$coverage_percent >= 80 | x$instrumentation_exception_valid))'` |
| **Estimated runtime** | Quick regression about 8 seconds; full benchmark gate is intentionally deferred to wave and phase boundaries |

---

## Sampling Rate

- **After every task commit:** Run that task's exact focused command from the verification map; inherited baseline/contract/cutoff/scoring files are included only where the owning plan requires them.
- **After every plan wave:** Run only focused tests whose owning production tasks are complete; keep later task-scoped files parse-only until their owners execute. Add inherited benchmark contract/cutoff/scoring/pipeline/seal tests only where the owning plan declares them.
- **Before `$gsd-verify-work`:** Run the full suite, fresh-process deterministic bundle validation, exact panel/count reconciliation, and Phase 9 parent-hash verification.
- **Max feedback latency:** About 30 seconds for task-level synthetic, contract, and Plan 10-08 smoke tests, apart from the one-time dependency provenance/install preflight and Plan 10-09's pre-2002 numerical diagnostic. The expensive 12-tournament normal/reversed benchmark runs only in Plan 10-08 Task 1, never in a smoke command or the final complete-suite command.

---

## Per-Task Verification Map

Every row below reproduces the owning task's `<automated>` command. Task rows are focused checks; only the final phase gate runs the complete suite and coverage, and only Plan 10-08 Task 1 executes the expensive historical benchmark.

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Status | Pending Status |
|---------|------|------|-------------|-----------|-------------------|-------------|----------------|
| 10-01-T1 | 10-01 | 0 | STAT-01 | parse + task-scoped Wave 0 contracts | `rtk Rscript --vanilla -e 'files <- c("tests/testthat/helper_statistical_challengers.R", "tests/testthat/test_statistical_penalized_poisson_design.R", "tests/testthat/test_statistical_penalized_poisson_tuning.R"); invisible(lapply(files, parse)); source(files[[1]]); stopifnot(all(vapply(c("synthetic_statistical_history", "synthetic_statistical_folds", "synthetic_sparse_teams", "statistical_pmf_oracles", "synthetic_phase10_registries"), exists, logical(1), mode = "function")))'` | planned — creates helper plus separate Plan 10-03 Task 1/Task 2 files | ⬜ pending |
| 10-10-T1 | 10-10 | 0 | STAT-02, STAT-03 | parse + task-scoped Wave 0 contracts | `rtk Rscript --vanilla -e 'invisible(lapply(c("tests/testthat/test_statistical_dynamic_state.R", "tests/testthat/test_statistical_dynamic_tuning.R", "tests/testthat/test_statistical_dependence_pmf.R", "tests/testthat/test_statistical_dependence_parameters.R"), parse))'` | planned — creates separate Plan 10-04 and 10-05 task files | ⬜ pending |
| 10-11-T1 | 10-11 | 0 | STAT-01, STAT-02, STAT-03, STAT-04 | parse + task-scoped pipeline/coverage contracts | `rtk Rscript --vanilla -e 'files <- c("tests/testthat/test_statistical_ablation_hierarchy.R", "tests/testthat/test_statistical_adapter_dispatch.R", "tests/testthat/test_statistical_ablation_selection.R", "tests/testthat/test_statistical_selection.R", "tests/testthat/test_statistical_bundle.R", "tests/testthat/test_statistical_targets.R", "tests/testthat/phase10_core_coverage.R"); invisible(lapply(files, parse)); x <- read.csv("tests/testthat/phase10_coverage_exceptions.csv", stringsAsFactors = FALSE); stopifnot(identical(names(x), c("source_file", "reason_code", "instrumentation_command", "error_text", "error_sha256", "evidence_path", "reviewer_note")), nrow(x) == 0L)'` | planned — creates separate Plan 10-06/10-07 task files plus coverage artifacts | ⬜ pending |
| 10-02-T1 | 10-02 | 0 | STAT-01, STAT-02, STAT-03, STAT-04 | dependency provenance preflight | `rtk Rscript --vanilla -e 'source("R/benchmark/challenger_preflight.R"); p <- capture_cran_package_provenance(package = "glmnet", version = "5.0", install = TRUE, output_path = "data/benchmark/phase10/glmnet_provenance.csv"); stopifnot(isTRUE(p$valid), identical(as.character(utils::packageVersion("glmnet")), "5.0"), isTRUE(verify_cran_package_archive(p)), length(inventory_cran_dependencies(p)$unexpected) == 0L, grepl("^[0-9a-f]{64}$", hash_installed_package_contents("glmnet"))); x <- require_challenger_environment(); stopifnot(isTRUE(x$valid)); targets::tar_manifest()'` | mixed — creates preflight/provenance files and modifies existing `_targets.R` | ⬜ pending |
| 10-09-T1 | 10-09 | 1 | STAT-01, STAT-02, STAT-03, STAT-04 | canonical parent/hash/grid/chronology + executed pre-2002 diagnostic | `rtk Rscript --vanilla -e 'source("R/benchmark/registry.R"); source("R/benchmark/challenger_preflight.R"); source("R/benchmark/challenger_protocol.R"); testthat::test_file("tests/testthat/test_statistical_registry_protocol.R", reporter = "summary", stop_on_failure = TRUE, stop_on_warning = TRUE); d <- run_pre2002_grid_diagnostic(); stopifnot(isTRUE(d$valid), identical(d$edition_ids, c("wc1994", "euro1996", "wc1998", "euro2000")), d$max_evidence_date < as.Date("2002-01-01"), identical(d$grid_sha256_before, d$grid_sha256_after), isTRUE(d$assessment_rows_absent))'` | planned — owns canonical protocol module, five registries, and Task 1 mutation test | ⬜ pending |
| 10-09-T2 | 10-09 | 1 | STAT-03, STAT-04 | canonical ablation/selection/no-promotion/storage mutation gate | `rtk Rscript --vanilla -e 'source("R/benchmark/registry.R"); source("R/benchmark/challenger_protocol.R"); testthat::test_file("tests/testthat/test_statistical_storage_preflight.R", reporter = "summary", stop_on_failure = TRUE, stop_on_warning = TRUE); x <- load_and_validate_challenger_protocol("data/benchmark/phase10"); stopifnot(isTRUE(x$valid), identical(x$shortlist_slots, c("best_proper_score", "simplest_non_inferior", "dependence_representative")), identical(x$thresholds, c(dependence_rps_gain = -0.001, practical_tie = 0.0005, simpler_noninferiority = 0.001, brier_relative = 0.01, log_relative = 0.01, calibration = 0.01, maximum_fold_regression = 0.015, fold_wins = 8, world_cup_wins = 2, euro_wins = 2)), isTRUE(validate_challenger_storage_preflight(x$storage)))'` | planned — owns ablation/selection/storage artifacts and Task 2 mutation test | ⬜ pending |
| 10-03-T1 | 10-03 | 2 | STAT-01 | focused sparse-design/cold-start behavior | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_statistical_penalized_poisson_design.R", reporter = "summary", stop_on_failure = TRUE, stop_on_warning = TRUE)'` | planned — Task 1 owns only design test; tuning contracts remain RED/unrun | ⬜ pending |
| 10-03-T2 | 10-03 | 2 | STAT-01 | focused tuning/Elo boundary + baseline regression | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_statistical_penalized_poisson_tuning.R", reporter = "summary", stop_on_failure = TRUE, stop_on_warning = TRUE); testthat::test_file("tests/testthat/test_benchmark_baselines.R", reporter = "summary", stop_on_failure = TRUE, stop_on_warning = TRUE)'` | mixed — Task 2 owns tuning/Elo test; later Plan 10-07 files remain RED/unrun | ⬜ pending |
| 10-04-T1 | 10-04 | 2 | STAT-02 | focused state-machine unit + replay | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_statistical_dynamic_state.R", reporter = "summary", stop_on_failure = TRUE, stop_on_warning = TRUE)'` | planned — Task 1 owns state test; tuning/Elo contracts remain RED/unrun | ⬜ pending |
| 10-04-T2 | 10-04 | 2 | STAT-02 | focused tuning/Elo + inherited cutoff regression | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_statistical_dynamic_tuning.R", reporter = "summary", stop_on_failure = TRUE, stop_on_warning = TRUE); testthat::test_file("tests/testthat/test_benchmark_cutoffs.R", reporter = "summary", stop_on_failure = TRUE, stop_on_warning = TRUE)'` | mixed — Task 2 owns tuning/Elo test; inherited cutoff test exists | ⬜ pending |
| 10-05-T1 | 10-05 | 3 | STAT-03 | focused PMF unit + inherited contract regression | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_statistical_dependence_pmf.R", reporter = "summary", stop_on_failure = TRUE, stop_on_warning = TRUE); testthat::test_file("tests/testthat/test_benchmark_contracts.R", reporter = "summary", stop_on_failure = TRUE, stop_on_warning = TRUE)'` | planned — Task 1 owns PMF test; fold-parameter contracts remain RED/unrun | ⬜ pending |
| 10-05-T2 | 10-05 | 3 | STAT-03 | focused chronology + parameter fit | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_statistical_dependence_parameters.R", reporter = "summary", stop_on_failure = TRUE, stop_on_warning = TRUE)'` | planned — Task 2 owns dependence-parameter test | ⬜ pending |
| 10-06-T1 | 10-06 | 4 | STAT-04 | focused ablation hierarchy + baseline regression | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_statistical_ablation_hierarchy.R", reporter = "summary", stop_on_failure = TRUE, stop_on_warning = TRUE); testthat::test_file("tests/testthat/test_benchmark_baselines.R", reporter = "summary", stop_on_failure = TRUE, stop_on_warning = TRUE)'` | mixed — Task 1 owns hierarchy test; dispatch/NI contracts remain RED/unrun | ⬜ pending |
| 10-06-T2 | 10-06 | 4 | STAT-01, STAT-02, STAT-03, STAT-04 | all-family focused adapter matrix | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_statistical_adapter_dispatch.R", reporter = "summary", stop_on_failure = TRUE, stop_on_warning = TRUE); testthat::test_file("tests/testthat/test_benchmark_contracts.R", reporter = "summary", stop_on_failure = TRUE, stop_on_warning = TRUE)'` | planned — Task 2 owns adapter test; NI contracts remain RED/unrun | ⬜ pending |
| 10-06-T3 | 10-06 | 4 | STAT-04 | focused non-inferiority + contract regression | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_statistical_ablation_selection.R", reporter = "summary", stop_on_failure = TRUE, stop_on_warning = TRUE); testthat::test_file("tests/testthat/test_benchmark_contracts.R", reporter = "summary", stop_on_failure = TRUE, stop_on_warning = TRUE)'` | planned — Task 3 owns non-inferiority test | ⬜ pending |
| 10-07-T1 | 10-07 | 5 | STAT-01, STAT-02, STAT-03, STAT-04 | focused selection + scoring regression | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_statistical_selection.R", reporter = "summary", stop_on_failure = TRUE, stop_on_warning = TRUE); testthat::test_file("tests/testthat/test_benchmark_scoring.R", reporter = "summary", stop_on_failure = TRUE, stop_on_warning = TRUE)'` | planned — Task 1 owns selection test; runner/targets files remain RED/unrun | ⬜ pending |
| 10-07-T2 | 10-07 | 5 | STAT-01, STAT-02, STAT-03, STAT-04 | synthetic bundle integration + corruption tests | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_statistical_bundle.R", reporter = "summary", stop_on_failure = TRUE, stop_on_warning = TRUE)'` | planned — Task 2 owns bundle test; targets file remains RED/unrun | ⬜ pending |
| 10-07-T3 | 10-07 | 5 | STAT-01, STAT-02, STAT-03, STAT-04 | focused target-manifest structure | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_statistical_targets.R", reporter = "summary", stop_on_failure = TRUE, stop_on_warning = TRUE); m <- targets::tar_manifest(); stopifnot(all(c("benchmark_phase10_registry_files", "benchmark_phase10_registries", "benchmark_phase10_predictions", "benchmark_phase10_scores", "benchmark_phase10_comparisons", "benchmark_phase10_bundle_files") %in% m$name))'` | mixed — modifies `_targets.R` and owns target test | ⬜ pending |
| 10-08-T1 | 10-08 | 6 | STAT-01, STAT-02, STAT-03, STAT-04 | deep published-bundle acceptance after expensive task action | `rtk Rscript --vanilla -e 'source("R/benchmark/registry.R"); source("R/benchmark/contracts.R"); source("R/benchmark/challenger_preflight.R"); source("R/benchmark/challenger_protocol.R"); source("R/benchmark/challengers.R"); source("R/evaluation/challenger_selection.R"); source("R/benchmark/challenger_runner.R"); x <- validate_statistical_challenger_bundle("outputs/benchmarks/rolling_tournaments/phase10-statistical-challengers"); stopifnot(isTRUE(x$valid), x$n_editions == 12L, x$n_candidates == 7L, x$open_fixture_count == 630L, x$rich_fixture_count == 609L, x$score_support_max == 40L, isTRUE(x$reproducible), isTRUE(x$wc2026_sealed), isTRUE(x$promotion_free))'` | planned — task action publishes twelve durable bundle artifacts | ⬜ pending |
| 10-08-T2 | 10-08 | 6 | STAT-01, STAT-02, STAT-03, STAT-04 | sub-30-second independent smoke acceptance | `rtk Rscript --vanilla -e 'source("R/benchmark/registry.R"); source("R/benchmark/contracts.R"); source("R/benchmark/challenger_preflight.R"); source("R/benchmark/challenger_protocol.R"); source("R/benchmark/challenger_runner.R"); started <- Sys.time(); x <- smoke_statistical_challenger_bundle("outputs/benchmarks/rolling_tournaments/phase10-statistical-challengers"); elapsed <- as.numeric(difftime(Sys.time(), started, units = "secs")); stopifnot(isTRUE(x$valid), isTRUE(x$parents_valid), isTRUE(x$sampled_grids_valid), isTRUE(x$targets_isolated), isTRUE(x$protected_paths_clean), elapsed < 30)'` | verification-only — reads the installed bundle and writes no files | ⬜ pending |
| 10-FINAL | phase gate | final | STAT-01, STAT-02, STAT-03, STAT-04 | persisted normal/reversed fresh-process reconciliation + exact panels/parents + complete suite + per-file coverage | `rtk Rscript --vanilla -e 'source("R/benchmark/registry.R"); source("R/benchmark/contracts.R"); source("R/benchmark/challenger_preflight.R"); source("R/benchmark/challenger_protocol.R"); source("R/benchmark/challengers.R"); source("R/evaluation/challenger_selection.R"); source("R/benchmark/challenger_runner.R"); deep <- validate_statistical_challenger_bundle("outputs/benchmarks/rolling_tournaments/phase10-statistical-challengers"); stopifnot(isTRUE(deep$valid), isTRUE(deep$reproducible), deep$open_fixture_count == 630L, deep$rich_fixture_count == 609L, isTRUE(deep$parents_valid), identical(deep$phase09_parent_bundle_sha256, "977e119dd17e1212d2bfc57da2e676b6ee9d16bfba8b6c9bdbf1a97d302db069")); testthat::test_dir("tests/testthat", reporter = "summary", stop_on_failure = TRUE, stop_on_warning = TRUE); source("tests/testthat/phase10_core_coverage.R"); coverage <- run_phase10_core_coverage(); stopifnot(all((coverage$coverage_percent >= 80) + coverage$instrumentation_exception_valid > 0))'` | phase gate — all planned source, test, registry, and bundle files must exist | ⬜ pending |

---

## Required Assertions

- Shuffle same-day rows and require byte-identical dynamic states and predictions.
- Poison each assessment tournament's outcomes and require frozen predictions, selected hyperparameters, and dependence parameters to remain unchanged.
- Require identical mean-prediction hashes across independent, Dixon-Coles, and bivariate-Poisson variants.
- Recompute every stored Phase 10 row/settings/protocol hash from canonicalized non-hash content; reject valid-shape substitutions, missing/extra rows or columns, reordered canonical rows, and mutated values.
- Assert exact Phase 9 bundle SHA `977e119dd17e1212d2bfc57da2e676b6ee9d16bfba8b6c9bdbf1a97d302db069`, model-registry canonical SHA `a3d21b90568aec86f44cefe2964555cb5565e1ab4e205489f42009a3ec489255`, checksum self SHA `4fe638ab49014c9dbac98fe389709d7668715a9ac99840f52847d0297998c309`, and parent-graph SHA `19263239c52ceab8b9c2a345646a6475d103f38137ec5deebbc0993525701584` from durable Phase 9 evidence.
- Assert the exact ordered seven candidates, exact 33-row tuning/dependence specification, complete 114-row outer/inner relation, and an executed four-edition pre-2002 diagnostic whose before/after grid hashes match.
- Assert the complete ablation parent graph, exact ordered shortlist slots, and exact frozen thresholds: dependence gain -0.001, practical tie 0.0005, simpler non-inferiority +0.001, Brier/log/calibration 0.01, maximum fold regression 0.015, and fold/World Cup/Euro wins 8/2/2.
- In `test_statistical_penalized_poisson_tuning.R`, statically scan the parsed Phase 10 penalized-Poisson source and reject raw rating-history reads, direct `data/processed/elo_ratings.csv` access, nearest-date Elo reconstruction, or an unrestricted `elo_matches.csv` join. Dynamically reject missing/invalid canonical `elo_diff` companions, raw-rating/path/lookup inputs, stale source dates, and duplicate or unmatched tournament-map keys before fitting.
- Require candidate/baseline fixture-ID equality: 630 fixtures for each open baseline and 609 for `production_hybrid_nb`.
- Run twice in fresh R sessions and compare registry, manifest, prediction, score, evidence, comparison, and shortlist hashes.
- The final phase gate must accept that persisted normal/reversed fresh-process reconciliation, require exact 630-open/609-rich counts, validate the complete parent graph including Phase 9 bundle SHA-256 `977e119dd17e1212d2bfc57da2e676b6ee9d16bfba8b6c9bdbf1a97d302db069`, run the complete suite once, and enforce per-file core coverage at or above 80%.
- Assert statically and dynamically that Phase 10 does not call `evaluate_promotion()` or read 2026 World Cup outcomes.
- Validate finite nonnegative cells, unit mass, complete `0:40` support, and common market derivation for every score distribution.
- Preserve zero-coded xG/form formula columns while marking them inactive because point-in-time coverage is zero, not because observed values are zero.
- Measure `R/forecast/penalized_poisson.R`, `R/forecast/dynamic_goal_ability.R`, `R/forecast/score_dependence.R`, `R/benchmark/challengers.R`, and `R/evaluation/challenger_selection.R` separately with `covr`; every instrumented file must be at least 80% covered.
- Reject coverage exceptions for failed tests, uncovered branches, low percentages, or runtime. A whole-file exception is valid only when covr instrumentation itself fails reproducibly and the exact command, error/hash, evidence path, and reviewer note are registered.

---

## Wave 0 and Pre-Implementation Requirements

- [ ] Plan 10-01 Task 1: helper plus separate penalized design and tuning/Elo test files - synthetic folds, exact centering/identifiability, cold starts, tuning, and STAT-01 contracts.
- [ ] Plan 10-10 Task 1: separate dynamic-state, dynamic-tuning, dependence-PMF, and dependence-parameter files - task-scoped STAT-02/03 replay, PMF, shared-mean, chronology, and parameter contracts.
- [ ] Plan 10-11 Task 1: separate ablation-hierarchy, adapter-dispatch, non-inferiority, selection, bundle, and targets files plus `phase10_core_coverage.R` and the header-only exception registry - task-scoped STAT-04 and pipeline contracts.
- [ ] Plan 10-02 Task 1: capture official CRAN metadata/checksums/dependencies, install verified `glmnet` 5.0 locally, and persist repository/archive/content hashes for targets and run manifests.
- [ ] Plan 10-09 Task 1: canonically recompute hashes; assert exact Phase 9 parents, candidate/grid order, complete chronology; and execute/assert the pre-2002 diagnostic.
- [ ] Plan 10-09 Task 2: canonically validate exact ablation/selection/no-promotion thresholds and run the deterministic format-identical exact-cardinality G=40 storage pilot.

---

## Manual-Only Verifications

All phase behaviors have automated verification. Human review is limited to interpreting the resulting research shortlist; it is not a substitute for a test gate.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verification or Wave 0 dependencies.
- [x] Sampling continuity: no three consecutive tasks without automated verification.
- [x] Wave 0 covers all missing references.
- [x] No watch-mode flags.
- [x] Task-level feedback latency remains below 30 seconds.
- [x] Final phase-level gate runs the complete suite once and enforces per-file core modelling coverage >=80% or a valid instrumentation-only exception.
- [x] `nyquist_compliant: true` set in frontmatter.

**Approval:** approved 2026-07-22 after blocker-free plan verification and stale-reference cleanup
