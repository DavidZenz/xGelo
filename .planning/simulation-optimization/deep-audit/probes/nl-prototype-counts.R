# Audit-only probe; no production publication or performance certificate.
# Run from the worktree root. See ../../DEEP-AUDIT.md for input requirements.
audit_dir <- Sys.getenv("XGELO_AUDIT_DIR", "/private/tmp/xgelo-deep-audit")
probe_dir <- Sys.getenv("XGELO_AUDIT_PROBE_DIR", ".planning/simulation-optimization/deep-audit/probes")
dir.create(audit_dir, recursive = TRUE, showWarnings = FALSE)
Sys.setenv(XGELO_AUDIT_PROTOTYPE_SETUP_ONLY = "1")
source(file.path(probe_dir, "nl-prototype.R"))
results <- list()
for (variant in c("reference", "prepared_reuse")) {
  set_variant(variant == "prepared_reuse")
  before <- as.list(counts)
  output <- audit_iteration(1L)
  delta <- vapply(names(before), function(name) counts[[name]] - before[[name]], integer(1))
  results[[variant]] <- as.list(delta)
}
jsonlite::write_json(results, file.path(audit_dir, "nl-prototype-call-counts.json"), auto_unbox = TRUE, pretty = TRUE)
print(results)
