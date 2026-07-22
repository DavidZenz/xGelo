library(testthat)

project_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))
runner_module <- file.path(project_root, "R/benchmark/challenger_runner.R")
if (file.exists(runner_module)) source(runner_module)

require_statistical_bundle_api <- function() {
  required <- c(
    "phase10_output_paths", "load_phase09_parent_bundle",
    "run_statistical_challenger_benchmark", "write_statistical_challenger_bundle",
    "smoke_statistical_challenger_bundle", "validate_statistical_challenger_bundle"
  )
  missing <- required[!vapply(required, exists, logical(1), mode = "function")]
  if (length(missing)) {
    stop(paste("Wave 0 RED contract awaits:", paste(missing, collapse = ", ")), call. = FALSE)
  }
}

statistical_bundle_artifacts <- function() {
  c(
    "run_manifest", "model_manifests", "feature_coverage", "fold_tuning",
    "checksum_manifest", "fixture_predictions", "score_distributions",
    "fixture_scores", "benchmark_summaries", "all_baseline_comparisons",
    "shortlist", "research_report"
  )
}

test_that("Phase 10 output paths expose the complete publication graph", {
  require_statistical_bundle_api()
  paths <- phase10_output_paths(tempfile("phase10-bundle-"))
  expect_identical(names(paths), statistical_bundle_artifacts())
  expect_true(all(grepl("phase10|manifest|prediction|score|comparison|shortlist|report", paths)))
})

test_that("accepted Phase 9 parent is reconstructed with exact panel facts", {
  require_statistical_bundle_api()
  parent <- load_phase09_parent_bundle(
    file.path(project_root, "outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen")
  )
  expect_identical(
    parent$bundle_sha256,
    "977e119dd17e1212d2bfc57da2e676b6ee9d16bfba8b6c9bdbf1a97d302db069"
  )
  expect_identical(parent$open_fixture_count, 630L)
  expect_identical(parent$rich_fixture_count, 609L)
  expect_identical(parent$edition_count, 12L)
  expect_setequal(
    parent$baseline_ids,
    c("uniform_1x2", "expanding_1x2", "elo_goal_nb", "open_nb_incumbent", "production_hybrid_nb")
  )
  expect_true(all(grepl("^[0-9a-f]{64}$", unlist(parent$parent_hashes))))
})

test_that("runner rejects sealed labels before invoking a synthetic engine", {
  require_statistical_bundle_api()
  called <- 0L
  engine <- function(...) {
    called <<- called + 1L
    stop("engine must not run")
  }
  history <- data.frame(
    edition_id = "wc2026", fixture_id = "wc2026_001",
    actual_completion_date = as.Date("2026-06-11"),
    home_goals = 2L, away_goals = 0L, stringsAsFactors = FALSE
  )
  expect_error(
    run_statistical_challenger_benchmark(history = history, execution_engine = engine),
    "wc2026|sealed|holdout"
  )
  expect_identical(called, 0L)
})

test_that("runner source forbids promotion, network, and dashboard paths", {
  require_statistical_bundle_api()
  code <- paste(readLines(runner_module, warn = FALSE), collapse = "\n")
  forbidden <- c(
    "evaluate_promotion(", "promotion_decisions", "worldcup_2026",
    "dashboard", "httr::", "httr2::", "curl::", "download.file", "refresh"
  )
  expect_false(any(vapply(forbidden, grepl, logical(1), x = code, fixed = TRUE)))
})

test_that("normal and reversed synthetic runs reconcile before atomic publication", {
  require_statistical_bundle_api()
  engine <- function(candidate_order, ...) {
    candidates <- data.frame(
      candidate_id = candidate_order,
      artifact_sha256 = vapply(candidate_order, function(id) {
        digest::digest(id, algo = "sha256", serialize = FALSE)
      }, character(1)),
      stringsAsFactors = FALSE
    )
    list(
      candidates = candidates,
      declared_open_fixture_count = 630L,
      declared_rich_fixture_count = 609L,
      declared_support_max = 40L,
      reproducible = FALSE
    )
  }
  candidates <- c(
    "poisson_team_ridge", "poisson_team_ridge_elo", "dynamic_goal_ability",
    "dynamic_goal_ability_elo", "poisson_team_ridge_elo_dc",
    "poisson_team_ridge_elo_bivpois", "open_nb_elo_only_ablation"
  )
  first <- run_statistical_challenger_benchmark(
    candidate_order = candidates, execution_engine = engine, synthetic = TRUE,
    publish = FALSE
  )
  second <- run_statistical_challenger_benchmark(
    candidate_order = rev(candidates), execution_engine = engine, synthetic = TRUE,
    publish = FALSE
  )
  expect_identical(first$canonical_hashes, second$canonical_hashes)
  expect_true(first$reproducible)
  expect_true(second$reproducible)
  expect_identical(first$declared_open_fixture_count, 630L)
  expect_identical(first$declared_rich_fixture_count, 609L)
  expect_identical(first$declared_support_max, 40L)
})
