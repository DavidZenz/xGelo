---
phase: 09
slug: rolling-tournament-benchmark-harness
status: active
nyquist_compliant: true
wave_0_complete: true
created: 2026-07-20
---

# Phase 09 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `testthat` 3.3.2 |
| **Config file** | None; repository tests source modules directly from `tests/testthat/` |
| **Quick run command** | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_transfermarkt_benchmark.R", stop_on_failure = TRUE, stop_on_warning = TRUE); testthat::test_file("tests/testthat/test_benchmark_baselines.R", stop_on_failure = TRUE, stop_on_warning = TRUE); testthat::test_file("tests/testthat/test_benchmark_contracts.R", stop_on_failure = TRUE, stop_on_warning = TRUE); testthat::test_file("tests/testthat/test_benchmark_scoring.R", stop_on_failure = TRUE, stop_on_warning = TRUE); testthat::test_file("tests/testthat/test_benchmark_promotion.R", stop_on_failure = TRUE, stop_on_warning = TRUE); testthat::test_file("tests/testthat/test_benchmark_pipeline.R", stop_on_failure = TRUE, stop_on_warning = TRUE)'` |
| **Full suite command** | `rtk Rscript --vanilla -e 'testthat::test_dir("tests/testthat", reporter = "summary", stop_on_failure = TRUE, stop_on_warning = TRUE)'` |
| **Estimated runtime** | Quick suite under 60 seconds; full historical benchmark excluded from per-task sampling |

---

## Sampling Rate

- **After every task commit:** Run the task's focused `test_benchmark_*.R` file and any directly affected incumbent test.
- **After every plan wave:** Run all `test_benchmark_*.R` files plus `test_transfermarkt_benchmark.R`, `test_worldcup_scoring.R`, and `test_worldcup_retrospective.R`.
- **Before `$gsd-verify-work`:** Run the full `tests/testthat` suite, load `targets::tar_manifest()`, and compare hashes from two deterministic benchmark runs.
- **Max feedback latency:** 60 seconds for task-level synthetic tests.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 09-01-01 | 01 | 0 | BENCH-01, BENCH-02, BENCH-03 | T-09-01, T-09-02, T-09-03 | Wave 0 fixtures encode exact denominators, same-date cutoffs, stable identities, and WC2026 adapter non-invocation | contract scaffold | `rtk Rscript --vanilla -e 'files <- c("tests/testthat/helper_benchmark.R", "tests/testthat/test_benchmark_registry.R", "tests/testthat/test_benchmark_cutoffs.R", "tests/testthat/test_benchmark_seal.R"); invisible(lapply(files, parse))'` | ✅ existing | ✅ green |
| 09-01-02 | 01 | 0 | BENCH-01, BENCH-03 | T-09-01, T-09-02, T-09-04 | The 12/630 local registry, identities, formats, regulation outcomes, corrections, and 12+272 boundaries have authoritative provenance and stable hashes | artifact contract | `rtk Rscript --vanilla -e 'stopifnot(nrow(read.csv("data/benchmark/phase09/tournaments.csv")) == 12L, nrow(read.csv("data/benchmark/phase09/fixtures.csv")) == 630L, file.exists("data/benchmark/phase09/corrections.csv"))'` | ✅ existing | ✅ green |
| 09-01-03 | 01 | 0 | BENCH-01, BENCH-02, BENCH-03 | T-09-01, T-09-03, T-09-05 | Registry/correction validation, date-complete boundaries, path guards, hashes, and WC2026 purpose gates fail closed before downstream use | adversarial unit | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_benchmark_registry.R"); testthat::test_file("tests/testthat/test_benchmark_cutoffs.R"); testthat::test_file("tests/testthat/test_benchmark_seal.R")'` | ✅ existing | ✅ green |
| 09-02-01 | 02 | 1 | BENCH-03 | T-09-06, T-09-07, T-09-10 | Common schemas reject incomplete support audits, incoherent markets, missing fixtures, invalid provenance, and unregistered seeds while preserving Phase 8 scores | contract + regression | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_benchmark_contracts.R"); testthat::test_file("tests/testthat/test_worldcup_scoring.R")'` | ✅ existing | ✅ green |
| 09-02-02 | 02 | 1 | BENCH-03, BENCH-04 | T-09-07, T-09-09, T-09-11 | Registries freeze D-14 formulas/settings/policies and hashes before folds; panel rows declare provenance, the per-edition floor, and `output_coverage_required` without observed completeness or final eligibility | artifact contract | `rtk Rscript --vanilla -e 'p <- read.csv("data/benchmark/phase09/panels.csv"); pf <- read.csv("data/benchmark/phase09/panel_fixtures.csv"); m <- read.csv("data/benchmark/phase09/model_registry.csv"); stopifnot(sum(pf$panel_id == "open_core" & pf$eligible) == 630L, all(pf$output_coverage_required), !"output_coverage_complete" %in% names(pf), !"promotion_eligible" %in% names(p), all(grepl("^[0-9a-f]{64}$", m$registration_sha256)), all(grepl("^[0-9a-f]{64}$", m$settings_sha256)))'` | ✅ existing | ✅ green |
| 09-02-03 | 02 | 1 | BENCH-03, BENCH-04 | T-09-06, T-09-08, T-09-10, T-09-11 | Five adapters obey D-12/D-13, reject D-14 fold-specific tuning/settings drift, produce identical registration/settings hashes across folds, write the normalized support audit, measure post-output coverage, and conserve format probability mass | integration + property | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_benchmark_baselines.R"); a <- read.csv("data/benchmark/phase09/score_support_audit.csv"); stopifnot(all(c("model_id", "edition_id", "track_id", "boundary_id", "candidate_g", "raw_omitted_tail", "tolerance", "pass", "selected_g", "parent_hashes", "row_hash") %in% names(a)), length(unique(a$selected_g)) == 1L); testthat::test_file("tests/testthat/test_transfermarkt_benchmark.R")'` | ✅ existing | ✅ green |
| 09-03-01 | 03 | 2 | BENCH-05 | T-09-12, T-09-13 | Proper scores, fixed bins, tournament-first weighting, exact pairing, tournament bootstrap, breadth, regression, and leave-one-out diagnostics are deterministic | unit + property | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_benchmark_scoring.R"); testthat::test_file("tests/testthat/test_worldcup_scoring.R")'` | ✅ existing | ✅ green |
| 09-03-02 | 03 | 2 | BENCH-05 | T-09-14, T-09-15, T-09-16 | D-16–D-20 are boundary-exact; protocol validates the normalized support-audit parent hash and derives rich eligibility from observed output completeness plus frozen provenance/thresholds | adversarial unit | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_benchmark_promotion.R")'` | ✅ existing | ✅ green |
| 09-04-01 | 04 | 3 | BENCH-01, BENCH-02, BENCH-03, BENCH-04, BENCH-05 | Focused runner tests validate normalized support-audit lineage, D-14 hash stability, post-adapter output coverage/final eligibility, WC2026 rejection, no-network guard, parent corruption, and deterministic reconciliation | integration | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_benchmark_pipeline.R", reporter = "summary", stop_on_failure = TRUE, stop_on_warning = TRUE)'` | ✅ existing | ✅ green |
| 09-04-02 | 04 | 3 | BENCH-01, BENCH-02, BENCH-03, BENCH-04, BENCH-05 | The targets DAG tracks `score_support_audit.csv` through predictions/protocol/bundle and observed coverage through decisions, with exact local-only invalidation and no dashboard coupling | pipeline + regression | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_benchmark_pipeline.R"); targets::tar_manifest()'` | ✅ existing | ✅ green |
| 09-04-03 | 04 | 3 | BENCH-01, BENCH-02, BENCH-03, BENCH-04, BENCH-05 | The canonical bundle reconciles registered panels/models/tracks, normalized support audit/selected G/parent hashes, identical fold settings, observed output coverage/final eligibility, reproducibility, sealing, and legacy behavior | acceptance + regression | `rtk Rscript --vanilla -e 'source("R/benchmark/runner.R"); x <- validate_rolling_benchmark_bundle("outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen"); stopifnot(isTRUE(x$valid), isTRUE(x$score_support_audit_valid), isTRUE(x$registration_settings_stable), isTRUE(x$output_coverage_reconciled), isTRUE(x$reproducible), isTRUE(x$wc2026_sealed), isTRUE(x$network_free))'` | ✅ existing | ✅ green |

### Gap Closure Task Verification Map

The original 09-01 through 09-04 rows above are retained as execution history. The rows below map every new gap task one-to-one and use explicit failure/warning propagation.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 09-05-01 | 05 | 4 | BENCH-03 | T-09-G05-01, T-09-G05-03 | The real hybrid-feature producer captures source presence/date before imputation and distinguishes observed zero from missing-then-zero before runner defaults | producer regression | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_transfermarkt_benchmark.R", reporter = "summary", stop_on_failure = TRUE, stop_on_warning = TRUE)'` | ✅ existing | ⬜ pending |
| 09-05-02 | 05 | 4 | BENCH-03 | T-09-G05-01, T-09-G05-02 | Every adapter emits exact registered feature groups; malformed evidence or dangling prediction links fail before adapter return | adapter contract | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_benchmark_baselines.R", reporter = "summary", stop_on_failure = TRUE, stop_on_warning = TRUE)'` | ✅ existing | ⬜ pending |
| 09-06-01 | 06 | 5 | BENCH-03, BENCH-04, BENCH-05 | Exact-set panel selectors reject missing/duplicate/extra rows and retain equal-tournament/paired uncertainty semantics | contract + scoring | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_benchmark_contracts.R", reporter = "summary", stop_on_failure = TRUE, stop_on_warning = TRUE); testthat::test_file("tests/testthat/test_benchmark_scoring.R", reporter = "summary", stop_on_failure = TRUE, stop_on_warning = TRUE)'` | ✅ existing | ⬜ pending |
| 09-06-02 | 06 | 5 | BENCH-03, BENCH-04, BENCH-05 | Bundle construction/read-back preserve exact adapter evidence and derived validity while runner evaluation enforces 630 open and 609 rich fixtures | contract + pipeline integration | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_benchmark_contracts.R", reporter = "summary", stop_on_failure = TRUE, stop_on_warning = TRUE); testthat::test_file("tests/testthat/test_benchmark_pipeline.R", reporter = "summary", stop_on_failure = TRUE, stop_on_warning = TRUE)'` | ✅ existing | ⬜ pending |
| 09-07-01 | 07 | 6 | BENCH-05 | Pure evaluator emits every D-16 through D-20 value/boolean and ordered failure reason while preserving empty all-pass semantics | adversarial unit | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_benchmark_promotion.R", reporter = "summary", stop_on_failure = TRUE, stop_on_warning = TRUE)'` | ✅ existing | ⬜ pending |
| 09-07-02 | 07 | 6 | BENCH-03, BENCH-05 | Canonical runner calls evaluate_promotion for every model, derives every evidence flag, and cannot finalize reproducibility before two-pass identity | integration + bypass | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_benchmark_pipeline.R", reporter = "summary", stop_on_failure = TRUE, stop_on_warning = TRUE); testthat::test_file("tests/testthat/test_benchmark_promotion.R", reporter = "summary", stop_on_failure = TRUE, stop_on_warning = TRUE)'` | ✅ existing | ⬜ pending |
| 09-08-01 | 08 | 7 | BENCH-01, BENCH-02, BENCH-03, BENCH-04, BENCH-05 | Complete local-only normal/reversed replay preserves strict cutoffs, G=40, direct feature linkage, 630/609 panels, evaluator decisions/reasons, and WC2026 seal | end-to-end acceptance | Exact automated block below | ✅ existing bundle | ⬜ pending |
| 09-08-02 | 08 | 7 | BENCH-01, BENCH-02, BENCH-03, BENCH-04, BENCH-05 | Fail-fast acceptance independently checks output SHA/bytes, streaming output/self rows, exact sorted parents, score-support lineage, full/focused suites, direct/complete target edges, transitive isolation, and protected outputs | independent acceptance + regression | Exact automated block below | ✅ existing | ⬜ pending |

#### 09-08-01 exact automated block

```sh
rtk Rscript --vanilla -e 'source("R/benchmark/registry.R"); source("R/evaluation/proper_scores.R"); source("R/benchmark/contracts.R"); source("R/evaluation/promotion.R"); source("R/benchmark/runner.R"); root <- "outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen"; x <- validate_rolling_benchmark_bundle(root); p <- read.csv(file.path(root, "predictions/fixture_predictions.csv"), stringsAsFactors = FALSE); fc <- read.csv(file.path(root, "manifests/feature_coverage.csv"), stringsAsFactors = FALSE); pf <- read.csv("data/benchmark/phase09/panel_fixtures.csv", stringsAsFactors = FALSE); s <- read.csv(file.path(root, "scores/fixture_scores.csv"), stringsAsFactors = FALSE); d <- read.csv(file.path(root, "comparisons/promotion_decisions.csv"), stringsAsFactors = FALSE, na.strings = NULL); rich <- pf$fixture_id[pf$panel_id == "feature_rich" & pf$eligible & pf$output_coverage_required]; stopifnot(isTRUE(x$valid), nrow(p) == 6300L, all(p$feature_coverage_id %in% fc$feature_coverage_id), length(unique(p$feature_coverage_id)) == length(unique(fc$feature_coverage_id)), length(rich) == 609L, !any(s$model_id == "production_hybrid_nb" & !s$fixture_id %in% rich), all(nzchar(d$reason_codes[d$decision != "eligible_for_final_holdout"])), isTRUE(x$reproducible), isTRUE(x$wc2026_sealed), isTRUE(x$network_free))'
```

#### 09-08-02 exact automated block

```sh
set -e
rtk git diff --quiet -- outputs/dashboard outputs/evaluation/wc2026
rtk Rscript --vanilla -e 'source("R/benchmark/registry.R"); source("R/evaluation/proper_scores.R"); source("R/benchmark/contracts.R"); source("R/benchmark/runner.R"); root <- "outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen"; manifest_path <- file.path(root, "manifests/checksum_manifest.csv"); m <- read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE); output <- m[m$artifact_role == "output", , drop = FALSE]; for (i in seq_len(nrow(output))) { path <- file.path(root, output$relative_path[i]); got <- strsplit(system2("/usr/bin/shasum", c("-a", "256", path), stdout = TRUE), "[[:space:]]+")[[1]][1]; stopifnot(identical(tolower(got), tolower(output$sha256[i])), identical(as.numeric(file.info(path)$size), as.numeric(output$bytes[i]))) }; stream_rows <- function(path) { con <- file(path, open = "r"); on.exit(close(con)); n <- 0L; repeat { chunk <- readLines(con, n = 100000L, warn = FALSE); if (!length(chunk)) break; n <- n + length(chunk) }; n - 1L }; counted <- m[m$artifact_role %in% c("output", "self"), , drop = FALSE]; for (i in seq_len(nrow(counted))) stopifnot(stream_rows(file.path(root, counted$relative_path[i])) == as.integer(counted$rows[i])); body <- benchmark_runner_sort(m[m$artifact != "checksum_manifest", , drop = FALSE], "checksum_manifest"); expected_self <- canonical_benchmark_sha256(body, c("artifact", "relative_path")); self <- m[m$artifact == "checksum_manifest", , drop = FALSE]; stopifnot(nrow(self) == 1L, identical(tolower(self$sha256), expected_self), identical(tolower(self$canonical_content_sha256), expected_self), identical(tolower(self$parent_hashes), expected_self)); expected_inputs <- c("boundaries", "corrections", "feature_contract", "fixtures", "formats", "goal_training_features_hybrid", "model_registry", "panel_fixtures", "panels", "promotion_protocol", "route_rules", "score_support_audit", "seed_registry", "teams", "tournaments"); input <- m[m$artifact_role == "input", , drop = FALSE]; stopifnot(setequal(input$artifact, expected_inputs)); input <- input[order(input$artifact, method = "radix"), , drop = FALSE]; graph_hash <- benchmark_runner_hash(paste(input$canonical_content_sha256, collapse = "|")); stopifnot(all(tolower(output$parent_hashes) == graph_hash)); audit <- read.csv("data/benchmark/phase09/score_support_audit.csv", stringsAsFactors = FALSE, check.names = FALSE); audit_hash <- benchmark_runner_hash(paste(sort(unique(audit$parent_hashes), method = "radix"), collapse = "|")); stopifnot(identical(tolower(input$parent_hashes[input$artifact == "score_support_audit"]), audit_hash)); testthat::test_dir("tests/testthat", reporter = "summary", stop_on_failure = TRUE, stop_on_warning = TRUE); net <- targets::tar_network(targets_only = TRUE, outdated = FALSE); phase <- c("benchmark_phase09_registry_files", "benchmark_phase09_registries", "benchmark_phase09_boundaries", "benchmark_phase09_predictions", "benchmark_phase09_stage_probabilities", "benchmark_phase09_scores", "benchmark_phase09_comparisons", "benchmark_phase09_bundle_files"); stopifnot(all(phase %in% net$vertices$name)); edge_key <- paste(net$edges$from, net$edges$to, sep = "->"); required_edges <- c("benchmark_phase09_registry_files->benchmark_phase09_registries", "benchmark_phase09_registries->benchmark_phase09_boundaries", "benchmark_phase09_boundaries->benchmark_phase09_predictions", "hybrid_goal_training_features_file->benchmark_phase09_predictions", "benchmark_phase09_predictions->benchmark_phase09_stage_probabilities", "benchmark_phase09_predictions->benchmark_phase09_scores", "benchmark_phase09_predictions->benchmark_phase09_comparisons", "benchmark_phase09_scores->benchmark_phase09_comparisons", "benchmark_phase09_stage_probabilities->benchmark_phase09_bundle_files", "benchmark_phase09_scores->benchmark_phase09_bundle_files", "benchmark_phase09_comparisons->benchmark_phase09_bundle_files"); stopifnot(all(required_edges %in% edge_key)); ancestors <- function(nodes) { seen <- character(); frontier <- nodes; while (length(frontier)) { parents <- unique(net$edges$from[net$edges$to %in% frontier]); parents <- setdiff(parents, seen); if (!length(parents)) break; seen <- union(seen, parents); frontier <- parents }; seen }; ancestry <- unique(unlist(lapply(phase, ancestors), use.names = FALSE)); forbidden <- "dashboard|publish.*page|download|refresh|worldcup_retrospective|worldcup_.*ledger"; stopifnot(!any(grepl(forbidden, ancestry, ignore.case = TRUE)))'
rtk Rscript --vanilla -e 'files <- c("tests/testthat/test_benchmark_baselines.R", "tests/testthat/test_benchmark_contracts.R", "tests/testthat/test_benchmark_scoring.R", "tests/testthat/test_benchmark_promotion.R", "tests/testthat/test_benchmark_pipeline.R", "tests/testthat/test_transfermarkt_benchmark.R", "tests/testthat/test_worldcup_dashboard.R", "tests/testthat/test_worldcup_ledger.R", "tests/testthat/test_worldcup_scoring.R", "tests/testthat/test_worldcup_retrospective.R"); for (file in files) testthat::test_file(file, reporter = "summary", stop_on_failure = TRUE, stop_on_warning = TRUE)'
rtk git diff --quiet -- outputs/dashboard outputs/evaluation/wc2026
```

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `data/benchmark/phase09/{tournaments,fixtures,teams,formats,route_rules,corrections,boundaries}.csv` and `SOURCES.md` — canonical Wave 0 editions, fixtures, statuses, regulation scores, identities, formats, routes, correction provenance, and boundaries.
- [x] `tests/testthat/helper_benchmark.R` — synthetic histories, format fixtures, adapter stubs, and fixed distributions.
- [x] `tests/testthat/test_benchmark_registry.R`
- [x] `tests/testthat/test_benchmark_cutoffs.R`
- [x] `tests/testthat/test_benchmark_seal.R`

The remaining focused test files are created test-first in their owning waves: contracts/baselines in Wave 1, scoring/promotion in Wave 2, and pipeline integration in Wave 3.

Wave 1 also creates `data/benchmark/phase09/score_support_audit.csv` as the normalized durable support audit. `model_registry.csv` remains frozen registration metadata; panel registries declare required output, while observed `output_coverage_complete` appears only after adapter generation in run/bundle coverage artifacts.

No framework installation is needed.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Source-attribution review for historical stage, status, and regulation-time corrections | BENCH-01, BENCH-03 | Provenance quality cannot be fully inferred from row shape | Review every curated correction against its cited source before freezing registry checksums. |
| Pre-WC2026 seal sign-off | BENCH-02, BENCH-05 | The freeze is a governance event as well as a software assertion | Confirm the committed protocol, candidate/model/panel registries, D-14 registration/settings hashes, normalized score-support audit and selected G, seeds, thresholds, and checksum-manifest parent links before any WC2026 result is opened. |

---

## Validation Sign-Off

- [x] All planned tasks have an automated verify command or Wave 0 dependency.
- [x] Sampling continuity: no three consecutive tasks lack automated verification.
- [x] Wave 0 covers all missing test references.
- [x] No watch-mode flags.
- [x] Task-level feedback latency target is under 60 seconds.
- [x] `nyquist_compliant: true` is set in frontmatter.

**Approval:** Wave 0 and Waves 1–3 complete; gap-closure Waves 4–7 remain pending execution and the separate post-execution verifier gate.
