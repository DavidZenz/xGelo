#!/usr/bin/env Rscript
# Mechanics-only CL benchmark. Synthetic fixtures never certify production.
# Usage: Rscript scripts/benchmark_champions_league_scale.R COUNT WORKERS OUTPUT_DIR
benchmark_started <- proc.time()[["elapsed"]]
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3L) stop("Expected COUNT WORKERS OUTPUT_DIR")
count <- as.integer(args[[1L]]); workers <- as.integer(args[[2L]])
if (is.na(count) || count < 1L || count > 100000L || is.na(workers) || workers < 1L) stop("Invalid count/workers")
destination <- args[[3L]]
dir.create(destination, recursive = TRUE, showWarnings = FALSE)
source("tests/testthat/helper_uefa_champions_league.R")
for (name in c("rules", "state", "simulation", "outcomes")) source(paste0("R/competition/uefa_champions_league_", name, ".R"))
# Reuse the declared hash-valid mechanics ledger without running test cases.
for (expression in parse("tests/testthat/test_phase20_simulation_review.R")) {
  if (is.call(expression) && identical(expression[[1L]], as.name("<-")) &&
      identical(expression[[2L]], as.name("phase20_sim_review_ledger"))) eval(expression)
}
cutoff <- "2026-09-01T00:00:00Z"
graph <- phase20_fixture_graph_36x144()
ledger <- phase20_sim_review_ledger(graph, cutoff)
state <- ucl_build_state(graph, state_cutoff_utc = cutoff)
message("simulation_phase phase=preparation_complete")
frozen_implementation <- digest::digest(.ucl_sim_canonical_env$simulation_repository_identity("."), algo = "sha256")
gc(reset = TRUE)
preparation_seconds <- proc.time()[["elapsed"]] - benchmark_started
execution_started <- simulation_seconds <- NA_real_
phase_progress <- function(event) {
  if (is.na(execution_started)) execution_started <<- proc.time()[["elapsed"]]
  if (event$phase == "aggregation") simulation_seconds <<- event$elapsed_seconds
  message(sprintf("simulation_progress phase=%s completed=%d committed=%d total=%d elapsed_seconds=%.3f remaining_seconds=%.3f workers=%d",
    event$phase, event$completed, event$committed, event$total, event$elapsed_seconds, event$estimated_remaining_seconds, event$workers))
}
simulation_started <- proc.time()[["elapsed"]]
elapsed <- system.time(result <- ucl_run_simulation(state, ledger = ledger,
  simulations = count, seed = 7L, information_cutoff_utc = cutoff, workers = workers,
  batch_size = 16L, progress = phase_progress, execution_mode = "stream",
  run_dir = file.path(destination, paste0("run-", count)), resume = identical(Sys.getenv("XGELO_SIM_RESUME"), "1"), chunk_size = 256L), gcFirst = FALSE)
simulation_setup_seconds <- execution_started - simulation_started
aggregation_seconds <- elapsed[["elapsed"]] - simulation_setup_seconds - simulation_seconds
stopifnot(result$status %in% c("ready", "unresolved_draw_procedure"),
          result$trace_store$statistics$count == count, !isTRUE(result$production_eligible))
message("simulation_phase phase=validation")
candidate_time <- system.time(candidate <- ucl_validate_outcome_candidate(
  list(state = state, ledger = ledger, simulation = result), information_cutoff_utc = cutoff), gcFirst = FALSE)
stopifnot(isTRUE(candidate$valid), !isTRUE(candidate$production_eligible))
measurement <- data.frame(competition = "cl", authority = "synthetic_fixture_only",
  simulations = count, workers = workers, seed = 7L,
  source_bundle_id = result$metadata$source_bundle_id, graph_sha256 = result$graph_sha256,
  ledger_sha256 = result$metadata$ledger_sha256, ruleset_sha256 = result$metadata$ruleset_sha256,
  algorithm_version = result$metadata$algorithm_version, information_cutoff_utc = cutoff,
  elapsed_seconds = elapsed[["elapsed"]],
  candidate_seconds = candidate_time[["elapsed"]], validated = TRUE,
  preparation_seconds = preparation_seconds + simulation_setup_seconds,
  simulation_seconds = simulation_seconds, aggregation_seconds = aggregation_seconds,
  implementation_sha256 = frozen_implementation,
  output_bytes = as.numeric(object.size(result)), status = result$status,
  trace_bytes = sum(file.info(list.files(result$trace_store$run_dir, recursive = TRUE, full.names = TRUE))$size),
  production_eligible = FALSE,
  simulation_sha256 = digest::digest(file = "R/competition/uefa_champions_league_simulation.R", algo = "sha256"),
  execution_sha256 = digest::digest(file = "R/common/simulation_execution.R", algo = "sha256"))
write.csv(measurement, file.path(destination, paste0("cl-", count, "-", workers, ".csv")), row.names = FALSE)
stopifnot(identical(frozen_implementation, digest::digest(.ucl_sim_canonical_env$simulation_repository_identity("."), algo = "sha256")))
print(measurement)
