# Audit-only probe; no production publication or performance certificate.
# Run from the worktree root. See ../../DEEP-AUDIT.md for input requirements.
audit_dir <- Sys.getenv("XGELO_AUDIT_DIR", "/private/tmp/xgelo-deep-audit")
probe_dir <- Sys.getenv("XGELO_AUDIT_PROBE_DIR", ".planning/simulation-optimization/deep-audit/probes")
dir.create(audit_dir, recursive = TRUE, showWarnings = FALSE)
source("tests/testthat/helper_uefa_champions_league.R")
for (name in c("rules", "state", "simulation")) source(paste0("R/competition/uefa_champions_league_", name, ".R"))
for (expression in parse("tests/testthat/test_phase20_simulation_review.R")) {
  if (is.call(expression) && identical(expression[[1L]], as.name("<-")) &&
      identical(expression[[2L]], as.name("phase20_sim_review_ledger"))) eval(expression)
}
destination <- audit_dir
graph <- phase20_fixture_graph_36x144(); cutoff <- "2026-09-01T00:00:00Z"
ledger <- phase20_sim_review_ledger(graph, cutoff); rules <- .ucl_rule_contract()
sampler <- .ucl_sim_prepare_sampler(graph, ledger$ledger, cutoff)
ranker <- .ucl_sim_prepare_ranker(graph, rules, cutoff)
run_id <- "audit-private-no-certificate"
audit_cl_iteration <- function(i) {
  graph_i <- sampler(i, 7L)
  ranking <- ranker(graph_i)
  list(sampling = attr(graph_i, "ucl_sampling"), rows = .ucl_sim_rank_rows(ranking, i, run_id))
}
invisible(audit_cl_iteration(1L))
gc()
Rprof(file.path(destination, "cl-kernel.prof"), interval = 0.005)
kernel_time <- system.time(for (i in 1:64) invisible(audit_cl_iteration(i)))
Rprof(NULL)
profile <- summaryRprof(file.path(destination, "cl-kernel.prof"))
write.csv(profile$by.self, file.path(destination, "cl-profile-self.csv"))
write.csv(profile$by.total, file.path(destination, "cl-profile-total.csv"))
sample_time <- system.time(samples <- lapply(1:64, sampler, seed = 7L))
rank_time <- system.time(rankings <- lapply(samples, ranker))
row_time <- system.time(records <- lapply(1:64, function(i) list(
  sampling = attr(samples[[i]], "ucl_sampling"), rows = .ucl_sim_rank_rows(rankings[[i]], i, run_id))))
reducer <- .ucl_stream_reducer(graph$clubs$club_id)
reduce_time <- system.time({statistics <- reducer$init(); for (i in 1:64) statistics <- reducer$update(statistics, records[[i]], i)})
trace_time <- system.time({
  con <- gzfile(file.path(destination, "cl-trace.bin.gz"), "wb", compression = 1)
  for (i in 1:64) serialize(list(iteration = i, value = records[[i]]), con, version = 3L)
  close(con)
})
result <- data.frame(component = c("kernel_profiled", "sampling", "ranking", "rank_row_materialization", "reduce", "serialize_gzip1"),
  count = 64L, elapsed_seconds = c(kernel_time[["elapsed"]], sample_time[["elapsed"]], rank_time[["elapsed"]], row_time[["elapsed"]], reduce_time[["elapsed"]], trace_time[["elapsed"]]))
write.csv(result, file.path(destination, "cl-component-times.csv"), row.names = FALSE)
print(result)
print(head(profile$by.self, 12L)); print(head(profile$by.total, 18L))
saveRDS(list(graph = graph, ledger = ledger, rules = rules, samples = samples,
  rankings = rankings, records = records), file.path(destination, "cl-probe-inputs.rds"))
