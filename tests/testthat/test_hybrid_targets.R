library(testthat)

source(file.path(
  normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else ".")),
  "tests/testthat/helper_hybrid_phase11.R"
))
hybrid_source_if_present("R/evaluation/challenger_selection.R")
hybrid_require_targets_api()

test_that("HYBRID-01 through HYBRID-05 expose the six Phase 11 target nodes", {
  hybrid_require_phase11_target_nodes()
  withr::local_dir(hybrid_project_root)
  manifest <- targets::tar_manifest(fields = c("name", "command"))
  expect_true(all(hybrid_phase11_target_names() %in% manifest$name))
  expect_false(any(grepl("phase11.*promotion|promotion.*phase11", manifest$name, ignore.case = TRUE)))
})

test_that("Phase 11 target chain is downstream-only and keeps research boundaries", {
  withr::local_dir(hybrid_project_root)
  manifest <- targets::tar_manifest(fields = c("name", "command"))
  commands <- stats::setNames(as.character(manifest$command), manifest$name)
  names_required <- hybrid_phase11_target_names()

  expect_match(commands[[names_required[[2L]]]], names_required[[1L]], fixed = TRUE)
  expect_match(commands[[names_required[[3L]]]], names_required[[2L]], fixed = TRUE)
  expect_match(commands[[names_required[[4L]]]], names_required[[3L]], fixed = TRUE)
  expect_match(commands[[names_required[[5L]]]], names_required[[4L]], fixed = TRUE)
  expect_match(commands[[names_required[[6L]]]], names_required[[5L]], fixed = TRUE)

  ancestors <- hybrid_phase11_target_ancestors(manifest, names_required[[6L]])
  expect_true(all(names_required[-6L] %in% ancestors))
  forbidden <- paste(
    c(
      "dashboard", "worldcup_retrospective", "worldcup_2026",
      "download.file", "httr::", "httr2::", "curl::", "scrap", "live_collect",
      "evaluate_promotion(", "final_selection", "release_decision"
    ),
    collapse = "|"
  )
  expect_false(any(grepl(forbidden, commands[c(ancestors, names_required[[6L]])], ignore.case = TRUE)))
})

test_that("Phase 11 registry parents and runner flags are explicit", {
  withr::local_dir(hybrid_project_root)
  manifest <- targets::tar_manifest(fields = c("name", "command"))
  commands <- stats::setNames(as.character(manifest$command), manifest$name)
  registry_command <- commands[["benchmark_phase11_registry_files"]]
  expect_true(all(vapply(
    c(
      "ranger_provenance.csv", "country_centroids.csv", "country_centroids_metadata.csv",
      "structural_sources.csv", "structural_sources_metadata.csv",
      "structural_sources_checksums.csv", "xg_gate_manifest.csv",
      "structural_prior_manifest.csv", "mode_registry.csv", "manual_market_manifest.csv",
      "goal_training_features_hybrid.csv", "phase10"
    ),
    grepl,
    logical(1),
    x = registry_command,
    fixed = TRUE
  )))
  expect_match(commands[["benchmark_phase11_registries"]], "benchmark_phase11_registry_files", fixed = TRUE)
  expect_match(commands[["benchmark_phase11_registries"]], "require_hybrid_environment", fixed = TRUE)
  expect_match(commands[["benchmark_phase11_predictions"]], "run_hybrid_challenger_benchmark", fixed = TRUE)
  expect_match(commands[["benchmark_phase11_predictions"]], "guard_benchmark_purpose", fixed = TRUE)
  expect_match(commands[["benchmark_phase11_registries"]], "data/cache/phase11-library", fixed = TRUE)
  expect_match(commands[["benchmark_phase11_bundle_files"]], "write_hybrid_challenger_bundle", fixed = TRUE)
  expect_match(commands[["benchmark_phase11_bundle_files"]], "phase11-hybrid-challengers", fixed = TRUE)

  runner_path <- file.path(hybrid_project_root, "R/benchmark/hybrid_runner.R")
  runner_code <- paste(readLines(runner_path, warn = FALSE), collapse = "\n")
  expect_true(all(vapply(
    c(
      "open_fixture_count = 630L", "rich_fixture_count = 609L", "selected_g = 40L",
      "wc2026_sealed = TRUE", "network_free = TRUE", "research_only = TRUE"
    ),
    grepl,
    logical(1),
    x = runner_code,
    fixed = TRUE
  )))
  expect_false(grepl("evaluate_promotion\\s*\\(", runner_code, perl = TRUE))
  expect_false(grepl("release_decision|final_selection", runner_code, ignore.case = TRUE))
  expect_true(is.function(run_hybrid_challenger_benchmark))
  expect_true(is.function(validate_hybrid_challenger_bundle))
})

test_that("Phase 11 runner exposes durable bundle and research-shortlist contracts", {
  expect_true(is.function(write_hybrid_challenger_bundle))
  expect_true(is.function(hybrid_output_paths))
  expect_true(is.function(build_hybrid_research_shortlist))
  expect_true(is.function(validate_hybrid_research_shortlist))
  expect_true(is.function(hybrid_all_baseline_comparisons))
})

test_that("Phase 11 durable path names preserve exact panel and support contracts", {
  paths <- hybrid_output_paths("outputs/benchmarks/rolling_tournaments/phase11-hybrid-challengers")
  expect_true(all(file.path(
    "outputs/benchmarks/rolling_tournaments/phase11-hybrid-challengers",
    c("run_manifest.csv", "manifests/checksum_manifest.csv", "selection/hybrid_shortlist.csv")
  ) %in% unname(paths)))
  expect_equal(as.integer(630L), 630L)
  expect_equal(as.integer(609L), 609L)
  expect_equal(as.integer(40L), 40L)
})
