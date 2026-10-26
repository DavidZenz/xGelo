# Audit-only probe; no production publication or performance certificate.
# Run from the worktree root. See ../../DEEP-AUDIT.md for input requirements.
audit_dir <- Sys.getenv("XGELO_AUDIT_DIR", "/private/tmp/xgelo-deep-audit")
probe_dir <- Sys.getenv("XGELO_AUDIT_PROBE_DIR", ".planning/simulation-optimization/deep-audit/probes")
dir.create(audit_dir, recursive = TRUE, showWarnings = FALSE)
Sys.setenv(XGELO_AUDIT_SETUP_ONLY = "1")
source(file.path(probe_dir, "cl-prototype.R"))
# Broader support is a synthetic sensitivity probe, not an accepted forecast.
wide_grid <- expand.grid(home_goals = 0:7, away_goals = 0:7)
wide_grid$probability <- dnbinom(wide_grid$home_goals, size = 2, mu = 1.5) *
  dnbinom(wide_grid$away_goals, size = 2, mu = 1.2)
wide_grid$probability <- wide_grid$probability / sum(wide_grid$probability)
ledger_wide <- inputs$ledger$ledger
ledger_wide$score_grid <- rep(list(wide_grid), nrow(ledger_wide))
samplers <- list(two_row_reference = original_sampler, two_row_prepared = fast_sampler,
  wider_reference = .ucl_sim_prepare_sampler(graph, ledger_wide, cutoff),
  wider_prepared = scope$.ucl_sim_prepare_sampler(graph, ledger_wide, cutoff))
results <- list()
for (variant in names(samplers)) {
  sampler <- samplers[[variant]]
  ranker <- if (grepl("prepared$", variant)) fast_ranker else original_ranker
  trace_count <- 0L; unresolved <- 0L; criterion_counts <- integer(nrow(rules$article18$criteria))
  elapsed <- system.time(for (i in 1:64) {
    sample <- sampler(i, 7L); rank <- ranker(sample); trace <- attr(rank, "trace")
    trace_count <- trace_count + nrow(trace)
    unresolved <- unresolved + sum(is.na(rank$rank))
    criterion_counts <- criterion_counts + tabulate(trace$criterion_order, nbins = length(criterion_counts))
  })[["elapsed"]]
  results[[variant]] <- data.frame(variant = variant, count = 64L, elapsed_seconds = elapsed,
    mean_trace_rows = trace_count / 64, unresolved_rank_fraction = unresolved / (36 * 64),
    early_criterion_trace_rows = sum(criterion_counts[1:2]), late_criterion_trace_rows = sum(criterion_counts[-(1:2)]))
}
result <- do.call(rbind, results)
write.csv(result, file.path(audit_dir, "cl-workload-times.csv"), row.names = FALSE)
print(result)
Rprof(file.path(audit_dir, "cl-prepared-kernel.prof"), interval = 0.005)
for (i in 1:64) invisible(fast_ranker(fast_sampler(i, 7L)))
Rprof(NULL)
profile <- summaryRprof(file.path(audit_dir, "cl-prepared-kernel.prof"))
write.csv(profile$by.self, file.path(audit_dir, "cl-prepared-self.csv"))
write.csv(profile$by.total, file.path(audit_dir, "cl-prepared-total.csv"))
print(head(profile$by.total, 15L))
