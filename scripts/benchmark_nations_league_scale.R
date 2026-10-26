#!/usr/bin/env Rscript
# Read accepted inputs, run one scale, validate a candidate, write only compact
# measurements. Run each count in a fresh process under /usr/bin/time -l for RSS.
# Usage: Rscript scripts/benchmark_nations_league_scale.R ROOT COUNT [CACHE_DIR] [WORKERS]
benchmark_started <- proc.time()[["elapsed"]]
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2L) stop("Usage: benchmark_nations_league_scale.R ROOT COUNT [CACHE_DIR]")
asset_root <- normalizePath(args[[1L]], mustWork = TRUE)
count <- suppressWarnings(as.integer(args[[2L]]))
if (length(count) != 1L || is.na(count) || count < 1L) stop("COUNT must be positive")
cache_dir <- if (length(args) >= 3L) args[[3L]] else tempdir()
workers <- if (length(args) >= 4L) as.integer(args[[4L]]) else 4L
dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
# The production entrypoint recognizes --file. Mask it during source so this
# diagnostic cannot accidentally invoke its CLI or durable write mode.
entry <- new.env(parent = .GlobalEnv)
entry$commandArgs <- function(trailingOnly = FALSE) character()
sys.source("scripts/build_nations_league_outcomes.R", envir = entry)
# Always revalidate accepted inputs. Cache only the expensive pairwise forecast
# handoff, bound to its complete accepted inputs and local implementation bytes.
loaded <- entry$phase15_nl_default_inputs(project_root = asset_root)
implementation <- c("scripts/build_nations_league_outcomes.R", "R/competition/forecast_layer.R",
                    "R/competition/uefa_nations_league_simulation.R", "R/competition/uefa_nations_league_streaming.R", "R/common/simulation_execution.R")
implementation_hashes <- vapply(implementation, function(path) digest::digest(file = path, algo = "sha256"), character(1))
cache_key <- digest::digest(list(loaded, implementation_hashes), algo = "sha256")
handoff_path <- file.path(cache_dir, paste0("handoff-", cache_key, ".rds"))
if (file.exists(handoff_path)) {
  handoff <- readRDS(handoff_path)
} else {
  handoff <- entry$phase15_nl_knockout_forecast_handoff(loaded)
  saveRDS(handoff, handoff_path)
}
simulation_code_sha256 <- unname(implementation_hashes[["R/competition/uefa_nations_league_simulation.R"]])
execution_code_sha256 <- unname(implementation_hashes[["R/common/simulation_execution.R"]])
state <- loaded$state_bundle
cat(sprintf("accepted_source=%s state_manifest=%s count=%d seed=15017 workers=%d\n",
  state$source_bundle_id, state$state_manifest_sha256, count, workers)); flush.console()
message("simulation_phase phase=preparation_complete")
frozen_implementation <- digest::digest(simulation_repository_identity("."), algo = "sha256")
gc(reset = TRUE)
preparation_seconds <- proc.time()[["elapsed"]] - benchmark_started
execution_started <- simulation_seconds <- NA_real_
phase_progress <- function(event) {
  if (is.na(execution_started)) execution_started <<- proc.time()[["elapsed"]]
  if (event$phase == "aggregation") simulation_seconds <<- event$elapsed_seconds
  message(sprintf("simulation_progress phase=%s completed=%d committed=%d total=%d elapsed_seconds=%.3f remaining_seconds=%.3f workers=%d",
    event$phase, event$completed, event$committed, event$total, event$elapsed_seconds, event$estimated_remaining_seconds, event$workers))
}
profile <- Sys.getenv("NL_BENCH_PROFILE")
if (nzchar(profile)) Rprof(profile)
simulation_started <- proc.time()[["elapsed"]]
elapsed <- system.time(simulation <- entry$uefa_nl_run_simulation(
  canonical_matches = state$canonical_matches, completed_results = loaded$source$results,
  forecast_status = handoff$forecast_status, forecasts = handoff$forecasts,
  score_distributions = handoff$score_distributions,
  groups = list(groups = loaded$topology$groups, group_rows = loaded$topology$teams),
  rules = loaded$rules, simulation_count = count, seed = 15017L, workers = workers,
  source_bundle_id = state$source_bundle_id, source_bundle_sha256 = state$source_bundle_sha256,
  model_release_id = state$model_release_id, model_lineage = state$model_lineage,
  state_manifest_sha256 = state$state_manifest_sha256,
  official_stage_slots = loaded$stage_capture$stage_capture,
  cutoff_utc = max(as.character(loaded$source$manifest$accepted_at_utc)),
  batch_size = 32L, progress = phase_progress, execution_mode = "stream",
  run_dir = file.path(cache_dir, paste0("run-", count)), resume = identical(Sys.getenv("XGELO_SIM_RESUME"), "1"), chunk_size = 256L
), gcFirst = FALSE)
simulation_setup_seconds <- execution_started - simulation_started
aggregation_seconds <- elapsed[["elapsed"]] - simulation_setup_seconds - simulation_seconds
if (nzchar(profile)) Rprof(NULL)
heap <- gc()
peak_parent_r_heap_bytes <- sum(heap[, "max used"] * c(56, 8))
cat(sprintf("simulation_elapsed_seconds=%.3f simulation_object_bytes=%.0f\n",
  elapsed[["elapsed"]], as.numeric(object.size(simulation)))); flush.console()
message("simulation_phase phase=validation")
candidate_time <- system.time({
  candidate <- entry$phase15_build_nl_outcomes_candidate(simulation = simulation,
    rules = loaded$rules, topology = loaded$topology, source = loaded$source,
    stage_capture = loaded$stage_capture, state_bundle = state,
    project_root = loaded$project_root, generated_at_utc = NULL, rule_inputs = loaded$rule_inputs)
  candidate <- entry$phase15_nl_attach_stage_capture_lineage(candidate, loaded$stage_capture)
  entry$phase15_validate_nl_outcomes_bundle(candidate)
}, gcFirst = FALSE)
rows <- lapply(names(candidate$artifacts), function(name) data.frame(
  artifact = name, rows = nrow(candidate$artifacts[[name]]),
  bytes = length(entry$phase15_nl_csv_bytes(candidate$artifacts[[name]]))))
sizes <- do.call(rbind, rows)
write.csv(sizes, file.path(cache_dir, paste0("artifacts-", count, ".csv")), row.names = FALSE)
measurement <- data.frame(simulations = count, seed = 15017L, workers = workers,
  source_bundle_id = state$source_bundle_id, state_manifest_sha256 = state$state_manifest_sha256,
  simulation_code_sha256 = simulation_code_sha256,
  execution_code_sha256 = execution_code_sha256,
  reducer_code_sha256 = unname(implementation_hashes[["R/competition/uefa_nations_league_streaming.R"]]),
  implementation_sha256 = frozen_implementation,
  execution_mode = "stream", trace_bytes = sum(file.info(list.files(attr(simulation, "trace_store")$run_dir, recursive = TRUE, full.names = TRUE))$size),
  elapsed_seconds = elapsed[["elapsed"]], candidate_seconds = candidate_time[["elapsed"]],
  preparation_seconds = preparation_seconds + simulation_setup_seconds,
  simulation_seconds = simulation_seconds, aggregation_seconds = aggregation_seconds,
  simulation_object_bytes = as.numeric(object.size(simulation)),
  peak_parent_r_heap_bytes = peak_parent_r_heap_bytes,
  artifact_bytes = sum(sizes$bytes), validated = TRUE)
write.csv(measurement, file.path(cache_dir, paste0("measurement-", count, ".csv")), row.names = FALSE)
print(measurement, row.names = FALSE)
