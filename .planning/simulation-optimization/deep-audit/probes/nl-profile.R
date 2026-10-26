# Audit-only probe; no production publication or performance certificate.
# Run from the worktree root. See ../../DEEP-AUDIT.md for input requirements.
audit_dir <- Sys.getenv("XGELO_AUDIT_DIR", "/private/tmp/xgelo-deep-audit")
probe_dir <- Sys.getenv("XGELO_AUDIT_PROBE_DIR", ".planning/simulation-optimization/deep-audit/probes")
dir.create(audit_dir, recursive = TRUE, showWarnings = FALSE)
entry <- new.env(parent = .GlobalEnv)
entry$commandArgs <- function(trailingOnly = FALSE) character()
sys.source("scripts/build_nations_league_outcomes.R", envir = entry)
loaded <- entry$phase15_nl_default_inputs(project_root = getwd())
handoff_path <- Sys.getenv("XGELO_AUDIT_NL_HANDOFF", "/private/tmp/xgelo-wc-style-certification/nl/handoff-752109108d6cf7ee53c6df9bfc863419faf829d273b9b029e51c0879c167e30a.rds")
handoff <- if (file.exists(handoff_path)) readRDS(handoff_path) else entry$phase15_nl_knockout_forecast_handoff(loaded)
captured <- new.env(parent = emptyenv())
entry$simulation_execute <- function(count, iteration, ...) {
  captured$kernel <- iteration
  stop(structure(list(message = "audit_capture"), class = c("audit_capture", "error", "condition")))
}
state <- loaded$state_bundle
setup <- system.time(tryCatch(entry$uefa_nl_run_simulation(
  canonical_matches = state$canonical_matches, completed_results = loaded$source$results,
  forecast_status = handoff$forecast_status, forecasts = handoff$forecasts,
  score_distributions = handoff$score_distributions,
  groups = list(groups = loaded$topology$groups, group_rows = loaded$topology$teams),
  rules = loaded$rules, simulation_count = 32L, seed = 15017L, workers = 1L,
  source_bundle_id = state$source_bundle_id, source_bundle_sha256 = state$source_bundle_sha256,
  model_release_id = state$model_release_id, model_lineage = state$model_lineage,
  state_manifest_sha256 = state$state_manifest_sha256,
  official_stage_slots = loaded$stage_capture$stage_capture,
  cutoff_utc = max(as.character(loaded$source$manifest$accepted_at_utc)),
  execution_mode = "memory"), audit_capture = function(e) NULL))
kernel <- captured$kernel
stopifnot(is.function(kernel))
runtime <- get("runtime", envir = environment(kernel), inherits = TRUE)
counts <- new.env(parent = emptyenv())
wrap_count <- function(name, env) {
  original <- get(name, env)
  counts[[name]] <- 0L
  assign(name, function(...) {
    counts[[name]] <- counts[[name]] + 1L
    original(...)
  }, env)
}
for (name in c("uefa_nl_rank_prepare_matches", "uefa_nl_rank_preflight", "uefa_nl_rank_parse_utc",
  "uefa_nl_sim_build_league_state", "uefa_nl_sim_resolve_stage_pair")) wrap_count(name, runtime)
wrap_count("uefa_nl_sim_normalize_score_distributions", entry)
if (Sys.getenv("XGELO_AUDIT_SETUP_ONLY") != "1") {
timings <- list(); outputs <- list()
Rprof(file.path(audit_dir, "nl-kernel.prof"), interval = 0.005)
for (i in 1:16) {
  before <- as.list(counts)
  elapsed <- system.time(outputs[[i]] <- kernel(i))[["elapsed"]]
  delta <- vapply(names(before), function(name) counts[[name]] - before[[name]], integer(1))
  timings[[i]] <- cbind(data.frame(iteration = i, elapsed_seconds = elapsed), as.data.frame(as.list(delta)))
}
Rprof(NULL)
profile <- summaryRprof(file.path(audit_dir, "nl-kernel.prof"))
write.csv(profile$by.self, file.path(audit_dir, "nl-kernel-self.csv"))
write.csv(profile$by.total, file.path(audit_dir, "nl-kernel-total.csv"))
write.csv(do.call(rbind, timings), file.path(audit_dir, "nl-kernel-times.csv"), row.names = FALSE)
print(setup)
print(do.call(rbind, timings))
print(head(profile$by.total, 18L))
}
