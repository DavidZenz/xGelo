# Audit-only probe; no production publication or performance certificate.
# Run from the worktree root. See ../../DEEP-AUDIT.md for input requirements.
audit_dir <- Sys.getenv("XGELO_AUDIT_DIR", "/private/tmp/xgelo-deep-audit")
probe_dir <- Sys.getenv("XGELO_AUDIT_PROBE_DIR", ".planning/simulation-optimization/deep-audit/probes")
dir.create(audit_dir, recursive = TRUE, showWarnings = FALSE)
Sys.setenv(XGELO_AUDIT_SETUP_ONLY = "1")
source(file.path(probe_dir, "cl-prototype.R"))
audit_one_row <- function(call) {
  parts <- as.list(call)
  parts[[1L]] <- as.name("list")
  parts <- parts[!names(parts) %in% c("stringsAsFactors", "check.names") | names(parts) == ""]
  # as.list(call) may have no names until named arguments are encountered.
  parts[[1L]] <- as.name("list")
  substitute(structure(COLUMNS, class = "data.frame", row.names = c(NA_integer_, -1L)), list(COLUMNS = as.call(parts)))
}
trace_fn <- .ucl_rule_trace_row
trace_body <- as.list(body(trace_fn))
stopifnot(length(trace_body) == 2L, identical(trace_body[[2L]][[1L]], as.name("data.frame")))
trace_body[[2L]] <- audit_one_row(trace_body[[2L]])
body(trace_fn) <- as.call(trace_body); environment(trace_fn) <- scope
scope$.ucl_rule_trace_row <- trace_fn
replace_rank_rows <- function(node) {
  if (!is.call(node)) return(node)
  if (identical(node[[1L]], as.name("<-")) && is.call(node[[2L]]) &&
      identical(node[[2L]][[1L]], as.name("[[")) && identical(node[[2L]][[2L]], as.name("rank_rows")) &&
      is.call(node[[3L]]) && identical(node[[3L]][[1L]], as.name("data.frame"))) {
    node[[3L]] <- audit_one_row(node[[3L]])
    return(node)
  }
  for (i in seq_along(node)) if (is.call(node[[i]])) node[[i]] <- replace_rank_rows(node[[i]])
  node
}
scope$ucl_apply_article18 <- scope$ucl_apply_article18
body(scope$ucl_apply_article18) <- replace_rank_rows(body(scope$ucl_apply_article18))
row_ranker <- scope$.ucl_sim_prepare_ranker(graph, rules, cutoff)
for (i in 1:64) stopifnot(identical(row_ranker(inputs$samples[[i]]), inputs$rankings[[i]]))
results <- list()
for (repeat_id in 1:2) {
  for (variant in if (repeat_id %% 2L) c("reference", "prepared_frames_rows") else c("prepared_frames_rows", "reference")) {
    sampler <- if (variant == "reference") original_sampler else fast_sampler
    ranker <- if (variant == "reference") original_ranker else row_ranker
    gc()
    elapsed <- system.time(for (i in 1:64) invisible(ranker(sampler(i, 7L))))[["elapsed"]]
    results[[length(results) + 1L]] <- data.frame(variant = variant, repeat_id = repeat_id, count = 64L, elapsed_seconds = elapsed)
  }
}
result <- do.call(rbind, results)
write.csv(result, file.path(audit_dir, "cl-rows-prototype-times.csv"), row.names = FALSE)
jsonlite::write_json(list(full_ranking_attribute_cases = 64L, exact_full_rankings = TRUE,
  trace_row_and_rank_row_schema_identical = TRUE, production_code_changed = FALSE),
  file.path(audit_dir, "cl-rows-prototype-parity.json"), auto_unbox = TRUE, pretty = TRUE)
print(result)
