library(testthat)
source("../../R/common/simulation_execution.R")
stream_test_reducer <- function() list(
  init = function() list(total = 0, ids = integer()),
  update = function(a, x, id) list(total = a$total + x, ids = c(a$ids, id)),
  merge = function(a, b) list(total = a$total + b$total, ids = c(a$ids, b$ids)))

test_that("stream chunks preserve coverage, seeds and resume across worker counts", {
  path <- tempfile(); on.exit(unlink(path, recursive = TRUE))
  set.seed(4); rng <- .Random.seed
  run <- simulation_execute_stream(11L, function(i) i * 2, stream_test_reducer(), list(version = 1), path,
    workers = 2, chunk_size = 3)
  expect_equal(run$statistics$total, 132)
  expect_identical(run$statistics$ids, 1:11)
  expect_identical(.Random.seed, rng)
  resumed <- simulation_execute_stream(11L, function(i) stop("must not replay"), stream_test_reducer(), list(version = 1), path,
    workers = 1, chunk_size = 3, resume = TRUE)
  expect_identical(run, resumed)
  expect_equal(unlist(simulation_trace_materialize(run)), (1:11) * 2)
  expect_error(simulation_execute_stream(11L, identity, stream_test_reducer(), list(version = 2), path, resume = TRUE, chunk_size = 3), "fingerprint")
  writeLines("bad", file.path(path, "chunk-000001", "statistics.rds"))
  expect_error(simulation_trace_materialize(run), "Corrupt")
})

test_that("failed chunks can resume without duplicating committed iterations", {
  path <- tempfile(); on.exit(unlink(path, recursive = TRUE))
  expect_error(simulation_execute_stream(7L, function(i) { if (i == 5) stop("injected"); i }, stream_test_reducer(), "recovery", path,
    workers = 1, chunk_size = 2), "injected")
  run <- simulation_execute_stream(7L, function(i) { if (i < 5) stop("duplicated"); i }, stream_test_reducer(), "recovery", path,
    workers = 2, chunk_size = 2, resume = TRUE)
  expect_equal(run$statistics$total, 28)
  expect_identical(run$statistics$ids, 1:7)
  expect_identical(unlist(simulation_trace_materialize(run)), 1:7)
})


test_that("NL disk traces and counters reproduce legacy complete outputs", {
  source("../../R/competition/uefa_nations_league_rules.R")
  source("../../R/competition/uefa_nations_league_simulation.R")
  env <- new.env(parent = .GlobalEnv)
  for (expression in parse("test_phase15_nations_league.R")) {
    if (is.call(expression) && identical(expression[[1L]], as.name("<-"))) eval(expression, envir = env)
  }
  inputs <- env$phase15_test_simulation_inputs(simulation_count = 5L)
  path <- tempfile(); on.exit(unlink(path, recursive = TRUE))
  reference <- do.call(uefa_nl_run_simulation, inputs)
  streamed <- do.call(uefa_nl_run_simulation, c(inputs, list(execution_mode = "stream", run_dir = path, chunk_size = 2L, workers = 2L)))
  materialized <- uefa_nl_materialize_simulation(streamed)
  for (field in names(reference)) expect_identical(materialized[[field]], reference[[field]], info = field)
})

test_that("CL stream summaries and complete traces equal the corrected reference", {
  source("helper_uefa_champions_league.R", local = TRUE)
  for (name in c("rules", "state", "simulation")) source(paste0("../../R/competition/uefa_champions_league_", name, ".R"), local = TRUE)
  for (expression in parse("test_phase20_simulation_review.R")) {
    if (is.call(expression) && identical(expression[[1L]], as.name("<-")) && identical(expression[[2L]], as.name("phase20_sim_review_ledger"))) eval(expression)
  }
  graph <- phase20_fixture_graph_36x144(); cutoff <- "2026-09-01T00:00:00Z"
  state <- ucl_build_state(graph, state_cutoff_utc = cutoff)
  args <- list(state = state, ledger = phase20_sim_review_ledger(graph), simulations = 5L, seed = 7L, information_cutoff_utc = cutoff)
  path <- tempfile(); on.exit(unlink(path, recursive = TRUE))
  reference <- do.call(ucl_run_simulation, c(args, list(workers = 1L)))
  streamed <- do.call(ucl_run_simulation, c(args, list(workers = 2L, execution_mode = "stream", run_dir = path, chunk_size = 2L)))
  expect_identical(ucl_materialize_simulation(streamed), reference)
  expect_identical(ucl_aggregate_rank_distributions(streamed), ucl_aggregate_rank_distributions(reference))
})

test_that("parallel failure, missing sinks, altered manifests and extra chunks fail closed", {
  path <- tempfile(); on.exit(unlink(path, recursive = TRUE))
  expect_error(simulation_execute_stream(8L, function(i) { if (i == 3) stop("parallel injected"); i }, stream_test_reducer(), "parallel-recovery", path,
    workers = 2, chunk_size = 2), "worker failed.*parallel injected")
  recovered <- simulation_execute_stream(8L, identity, stream_test_reducer(), "parallel-recovery", path,
    workers = 1, chunk_size = 2, resume = TRUE)
  expect_identical(unlist(simulation_trace_materialize(recovered)), 1:8)
  extra <- file.path(path, "chunk-999999"); dir.create(extra)
  expect_error(simulation_trace_validate(recovered), "inventory")
  unlink(extra, recursive = TRUE)
  manifest <- readRDS(file.path(path, "manifest.rds")); manifest$count <- 9L
  saveRDS(manifest, file.path(path, "manifest.rds"))
  expect_error(simulation_trace_validate(recovered), "manifest")
  other <- tempfile(); on.exit(unlink(other, recursive = TRUE), add = TRUE)
  expect_error(simulation_execute_stream(2L, identity, stream_test_reducer(), "sink", other,
    workers = 1, trace = function(x) stop("disk sink unavailable")), "disk sink unavailable")
  expect_false(dir.exists(file.path(other, "chunk-000001")))
  expect_true(dir.exists(other))
})

test_that("external canonical hashing preserves field order, UTF-8 and separators", {
  path <- tempfile(); on.exit(unlink(path, recursive = TRUE))
  rows <- data.frame(z = c("a", "a\x1fz", "é", NA), a = c("x\ny", "x", "a", "<NA>"), stringsAsFactors = FALSE)
  run <- simulation_execute_stream(4L, function(i) list(table = rows[i, , drop = FALSE]), list(
    init = function() 0L, update = function(a, x, i) a + 1L, merge = function(a, b) a + b), "hash", path, workers = 2, chunk_size = 2)
  actual <- simulation_trace_nl_hashes(run, "table", identity, uefa_nl_sim_hash_column)
  expect_identical(unname(actual[[1L]]), uefa_nl_sim_hash_data(rows))
})

test_that("NL streaming preserves alternate seeds and unavailable forecast semantics", {
  env <- new.env(parent = .GlobalEnv)
  for (expression in parse("test_phase15_nations_league.R")) {
    if (is.call(expression) && identical(expression[[1L]], as.name("<-"))) eval(expression, envir = env)
  }
  for (seed in c(7L, 31L)) {
    inputs <- env$phase15_test_simulation_inputs(simulation_count = 7L); inputs$seed <- seed
    if (seed == 31L) {
      inputs$forecast_status$forecast_status <- "unavailable"
      inputs$forecast_status$suppression_reason <- "streaming-unavailable"
    }
    path <- tempfile(); on.exit(unlink(path, recursive = TRUE), add = TRUE)
    reference <- do.call(uefa_nl_run_simulation, inputs)
    result <- do.call(uefa_nl_run_simulation, c(inputs, list(execution_mode = "stream", run_dir = path, workers = 2L, chunk_size = 3L)))
    expect_identical(uefa_nl_materialize_simulation(result), reference)
  }
})


test_that("CL cannot resolve qualification probabilities with an unknown required fixture", {
  source("helper_uefa_champions_league.R", local = TRUE)
  for (name in c("rules", "state", "simulation")) source(paste0("../../R/competition/uefa_champions_league_", name, ".R"), local = TRUE)
  for (expression in parse("test_phase20_simulation_review.R")) {
    if (is.call(expression) && identical(expression[[1L]], as.name("<-")) && identical(expression[[2L]], as.name("phase20_sim_review_ledger"))) eval(expression)
  }
  graph <- phase20_fixture_graph_36x144(); cutoff <- "2026-09-01T00:00:00Z"
  ledger <- phase20_sim_review_ledger(graph)
  ledger$ledger$forecast_status[[1L]] <- "suppressed"
  ledger$ledger$suppression_reason[[1L]] <- "forecast_unavailable"
  ledger$ledger$row_sha256[[1L]] <- .ucl_sim_canonical_row_hash(ledger$ledger[1L,,drop=FALSE], schema_tag = "ucl20-forecast-ledger-row-v1")
  ledger$table_sha256 <- .ucl_sim_canonical_table_hash(ledger$ledger, key = "fixture_id", schema_tag = "ucl20-forecast-ledger-v1")
  state <- ucl_build_state(graph, state_cutoff_utc = cutoff)
  args <- list(state = state, ledger = ledger, simulations = 3L, seed = 7L, information_cutoff_utc = cutoff)
  reference <- do.call(ucl_run_simulation, c(args, list(workers = 1L)))
  bands <- reference$progression_probabilities[reference$progression_probabilities$stage_id %in% c("direct_round_of_16", "knockout_play_off", "eliminated"), ]
  expect_true(all(bands$status == "unresolved"))
  expect_true(all(is.na(bands$probability)))
  expect_true(all(is.na(reference$rank_rows$rank)))
  expect_true(all(vapply(reference$fixture_sampling, function(x) length(x$suppressed_fixture_ids) == 1L, logical(1))))
  path <- tempfile(); on.exit(unlink(path, recursive = TRUE))
  streamed <- do.call(ucl_run_simulation, c(args, list(workers = 2L, execution_mode = "stream", run_dir = path, chunk_size = 2L)))
  expect_identical(ucl_materialize_simulation(streamed), reference)
  expect_identical(ucl_aggregate_rank_distributions(streamed), ucl_aggregate_rank_distributions(reference))
})
