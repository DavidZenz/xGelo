library(testthat)

nl_precision_root <- normalizePath(if (basename(getwd()) == "testthat") "../.." else ".", mustWork = TRUE)
source(file.path(nl_precision_root, "R/competition/nl_simulation_precision.R"))

nl_precision_cli <- function() {
  api <- new.env(parent = globalenv())
  api$interactive <- function() TRUE
  api$commandArgs <- function(trailingOnly = FALSE) if (trailingOnly) character() else
    paste0("--file=", file.path(nl_precision_root, "scripts/build_nations_league_outcomes.R"))
  sys.source(file.path(nl_precision_root, "scripts/build_nations_league_outcomes.R"), api)
  api
}

test_that("production counts have a predeclared one-point pointwise precision floor", {
  expect_identical(uefa_nl_mc_policy()$minimum_simulations, 9600L)
  expect_false(uefa_nl_mc_precision(100)$sufficient)
  expect_false(uefa_nl_mc_precision(1000)$sufficient)
  expect_false(uefa_nl_mc_precision(9599)$sufficient)
  expect_true(uefa_nl_mc_precision(9600)$sufficient)
  expect_true(uefa_nl_mc_precision(10000)$sufficient)
  expect_gt(uefa_nl_mc_precision(1000)$worst_case_half_width, .03)
  expect_lt(uefa_nl_mc_precision(10000)$worst_case_half_width, .01)
  expect_error(uefa_nl_mc_require_publication(100), "preview-only")
  expect_silent(uefa_nl_mc_require_publication(10000))
  for (n in list(NA, Inf, 0, -1, 2.5, c(1, 2))) expect_error(uefa_nl_mc_precision(n))
})

test_that("Wilson intervals match numerical reference values and retain rare-event uncertainty", {
  # Standard two-sided 95% Wilson score reference: 50 successes / 100 trials.
  interval <- uefa_nl_mc_interval(.5, 100)
  expect_equal(interval$mc_lower_95, 0.4038315303659956, tolerance = 1e-12)
  expect_equal(interval$mc_upper_95, 0.5961684696340044, tolerance = 1e-12)
  edges <- uefa_nl_mc_interval(c(0, 1, NA), 10000)
  expect_gt(edges$mc_upper_95[[1]], 0)
  expect_lt(edges$mc_upper_95[[1]], .001)
  expect_lt(edges$mc_lower_95[[2]], 1)
  expect_true(is.na(edges$mc_lower_95[[3]]))
  expect_error(uefa_nl_mc_interval(.12345, 1000), "counted simulation event")
  expect_error(uefa_nl_mc_interval(c(.5, -1), 1000))
  set.seed(20261105)
  empirical <- mean(stats::rbinom(10000, size = 1, prob = .4))
  sample_interval <- uefa_nl_mc_interval(empirical, 10000)
  expect_lte(sample_interval$mc_lower_95, .4)
  expect_gte(sample_interval$mc_upper_95, .4)
})

test_that("benchmark counts numeric events without treating reason strings as gaps", {
  api <- new.env(parent = globalenv())
  sys.source(file.path(nl_precision_root, "scripts/benchmark_nl_precision.R"), api)
  result <- list(projected_standings = data.frame(team_id = "a", rank = 1L, probability = 1),
    team_path_probabilities = data.frame(team_id = "a", p_champion = 0.2),
    euro_priority_queue = data.frame(team_id = "a", p_group_winner = NA_real_,
      p_group_winner_reason = "awaiting accepted forecasts"))
  values <- api$nl_benchmark_metrics(result)
  expect_equal(nrow(values), 3L)
  expect_equal(sum(is.na(values$probability)), 1L)
  expect_false(any(grepl("reason", values$key)))
})

test_that("independent benchmark audit catches lost probability mass and impossible paths", {
  api <- new.env(parent = globalenv())
  sys.source(file.path(nl_precision_root, "scripts/benchmark_nl_precision.R"), api)
  standings <- expand.grid(team_id = letters[1:8], rank = 1:4, stringsAsFactors = FALSE)
  standings$group_id <- ifelse(standings$team_id %in% letters[1:4], "A1", "A2")
  standings$probability <- .25
  paths <- data.frame(team_id = letters[1:8], p_quarter_final = 1, p_semi_final = .5,
    p_third_place = .25, p_final = .25, p_champion = .125)
  result <- list(projected_standings = standings, team_path_probabilities = paths,
    euro_priority_queue = data.frame(team_id = letters[1:8], p_group_winner = .25))
  expect_true(api$nl_benchmark_probability_audit(result)$each_team_rank_mass_one)
  corrupt <- result; corrupt$projected_standings$probability[[1L]] <- .5
  expect_error(api$nl_benchmark_probability_audit(corrupt), "audit failed")
  corrupt <- result; corrupt$team_path_probabilities$p_champion[[1L]] <- .6
  expect_error(api$nl_benchmark_probability_audit(corrupt), "audit failed")
})

test_that("CLI production rejects demo counts before reading or writing accepted inputs", {
  withr::local_envvar(c(XGELO_NL_SIMULATIONS = NA))
  api <- nl_precision_cli()
  expect_identical(api$phase15_nl_parse_args(c("--edition-id", "uefa_nations_league_2026_27"))$simulations, 10000L)
  api$phase15_nl_default_inputs <- function(...) stop("Accepted inputs must not be read")
  expect_error(api$phase15_build_nl_outcomes_main(c("--edition-id", "uefa_nations_league_2026_27", "--simulations", "100", "--write")), "preview-only")
  preview <- api$phase15_nl_parse_args(c("--edition-id", "uefa_nations_league_2026_27", "--simulations", "100", "--dry-run"))
  expect_identical(preview$mode, "dry-run")
  expect_identical(preview$simulations, 100L)
  withr::local_envvar(c(XGELO_NL_SIMULATIONS = "20000"))
  expect_identical(api$phase15_nl_parse_args(c("--edition-id", "uefa_nations_league_2026_27"))$simulations, 20000L)
  withr::local_envvar(c(XGELO_NL_SIMULATIONS = "1000.5"))
  expect_error(api$phase15_nl_parse_args(c("--edition-id", "uefa_nations_league_2026_27")), "positive integer")
})

test_that("production precision report uses one shared handoff and publishes only its selected run", {
  api <- nl_precision_cli()
  sys.source(file.path(nl_precision_root, "scripts/benchmark_nl_precision.R"), api)
  report_dir <- tempfile("nl-production-precision-")
  on.exit(unlink(report_dir, recursive = TRUE), add = TRUE)
  calls <- integer(); handoffs <- 0L; writes <- 0L; selected <- NULL
  standings <- expand.grid(team_id = letters[1:8], rank = 1:4, stringsAsFactors = FALSE)
  standings$group_id <- ifelse(standings$team_id %in% letters[1:4], "A1", "A2")
  standings$probability <- .25
  api$uefa_nl_run_simulation <- function(simulation_count, ...) {
    calls <<- c(calls, simulation_count)
    list(projected_standings = standings,
      team_path_probabilities = data.frame(team_id = letters[1:8], p_quarter_final = 1,
        p_semi_final = .5, p_third_place = .25, p_final = .25, p_champion = .125),
      euro_priority_queue = data.frame(team_id = letters[1:8], p_group_winner = .25),
      output_hashes = list(independent_fixture_count = simulation_count), selected_count = simulation_count)
  }
  api$phase15_nl_default_inputs <- function(...) list(state_bundle = list(source_bundle_id = "fixture", state_manifest_sha256 = "fixture-sha"))
  api$phase15_nl_simulation_inputs <- function(loaded, options, ...) {
    handoffs <<- handoffs + 1L
    list(simulation_count = options$simulations, workers = 1L, seed = options$seed,
      source_bundle_id = "fixture", source_bundle_sha256 = "fixture-source-sha",
      state_manifest_sha256 = "fixture-state-sha", model_release_id = "independent-fixture", cutoff_utc = "2026-11-05T00:00:00Z")
  }
  api$phase15_nl_build_candidate <- function(loaded, options, simulation_override = NULL) {
    selected <<- simulation_override
    list(candidate = list(stage_capture_lineage = list()), simulation = simulation_override)
  }
  api$phase15_write_nl_outcomes_bundle <- function(...) { writes <<- writes + 1L; list() }
  result <- api$phase15_build_nl_outcomes_main(c("--edition-id", "uefa_nations_league_2026_27",
    "--write", "--simulations", "10000", "--precision-report-dir", report_dir))
  expect_identical(calls, c(1000L, 10000L))
  expect_identical(handoffs, 1L)
  expect_identical(writes, 1L)
  expect_identical(selected$selected_count, 10000L)
  expect_identical(result$simulation, selected)
  expect_true(file.exists(file.path(report_dir, "event_intervals_10000.csv")))
  report <- jsonlite::read_json(file.path(report_dir, "benchmark_report.json"), simplifyVector = TRUE)
  expect_true(report$runs[["10000"]]$monte_carlo_precision$sufficient)
  expect_equal(report$runs[["10000"]]$comparison$maximum_absolute_change, 0)
  expect_error(api$phase15_nl_parse_args(c("--edition-id", "uefa_nations_league_2026_27", "--write", "--precision-report-dir", "relative")), "absolute path")
  expect_error(api$phase15_nl_parse_args(c("--edition-id", "uefa_nations_league_2026_27", "--precision-report-dir", report_dir)), "requires --write")
})

test_that("NL preview disclosure and pointwise interval metadata reach the rendered page", {
  api <- new.env(parent = globalenv())
  for (file in c("R/dashboard/payload_contract.R", "R/dashboard/payload_nations_league.R", "R/dashboard/renderer.R"))
    sys.source(file.path(nl_precision_root, file), api)
  bundle <- api$phase17_fixture_bundle("uefa_nations_league_2026_27")
  bundle$simulation_count <- 100L
  payload <- api$phase17_payload_nations_league(bundle)
  expect_identical(payload$metadata$monte_carlo_precision$status, "preview_only")
  expect_match(api$phase17_nl_mc_precision_note(payload), "Low-precision preview", fixed = TRUE)
  bundle$simulation_count <- 10000L
  payload <- api$phase17_payload_nations_league(bundle)
  expect_true(payload$metadata$monte_carlo_precision$sufficient)
  note <- api$phase17_nl_mc_precision_note(payload)
  expect_match(note, "0.98 percentage points", fixed = TRUE)
  expect_match(note, "do not provide simultaneous coverage", fixed = TRUE)
  expect_match(api$phase17_nl_mc_interval_label(payload, .1), "95% pointwise Monte Carlo interval", fixed = TRUE)
})
