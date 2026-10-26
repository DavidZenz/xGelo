#!/usr/bin/env Rscript
# Mechanics-only CL benchmark. Synthetic fixtures never certify production.
# Usage: Rscript scripts/benchmark_champions_league_scale.R COUNT WORKERS OUTPUT_DIR
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3L) stop("Expected COUNT WORKERS OUTPUT_DIR")
count <- as.integer(args[[1L]]); workers <- as.integer(args[[2L]])
if (is.na(count) || count < 1L || count > 100000L || is.na(workers) || workers < 1L) stop("Invalid count/workers")
destination <- args[[3L]]
dir.create(destination, recursive = TRUE, showWarnings = FALSE)
source("tests/testthat/helper_uefa_champions_league.R")
for (name in c("rules", "state", "simulation")) source(paste0("R/competition/uefa_champions_league_", name, ".R"))
# Reuse the declared hash-valid mechanics ledger without running test cases.
for (expression in parse("tests/testthat/test_phase20_simulation_review.R")) {
  if (is.call(expression) && identical(expression[[1L]], as.name("<-")) &&
      identical(expression[[2L]], as.name("phase20_sim_review_ledger"))) eval(expression)
}
cutoff <- "2026-09-01T00:00:00Z"
graph <- phase20_fixture_graph_36x144()
ledger <- phase20_sim_review_ledger(graph, cutoff)
state <- ucl_build_state(graph, state_cutoff_utc = cutoff)
gc(reset = TRUE)
elapsed <- system.time(result <- ucl_run_simulation(state, ledger = ledger,
  simulations = count, seed = 7L, information_cutoff_utc = cutoff, workers = workers,
  batch_size = 16L, progress = TRUE))
stopifnot(result$status %in% c("ready", "unresolved_draw_procedure"),
          nrow(result$rank_rows) == 36L * count, !isTRUE(result$production_eligible))
measurement <- data.frame(competition = "cl", authority = "synthetic_fixture_only",
  simulations = count, workers = workers, elapsed_seconds = elapsed[["elapsed"]],
  output_bytes = as.numeric(object.size(result)), status = result$status,
  production_eligible = FALSE,
  simulation_sha256 = digest::digest(file = "R/competition/uefa_champions_league_simulation.R", algo = "sha256"),
  execution_sha256 = digest::digest(file = "R/common/simulation_execution.R", algo = "sha256"))
write.csv(measurement, file.path(destination, paste0("cl-", count, "-", workers, ".csv")), row.names = FALSE)
print(measurement)
