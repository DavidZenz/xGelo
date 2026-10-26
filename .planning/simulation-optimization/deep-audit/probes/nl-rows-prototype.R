# Audit-only probe; no production publication or performance certificate.
# Run from the worktree root. See ../../DEEP-AUDIT.md for input requirements.
audit_dir <- Sys.getenv("XGELO_AUDIT_DIR", "/private/tmp/xgelo-deep-audit")
probe_dir <- Sys.getenv("XGELO_AUDIT_PROBE_DIR", ".planning/simulation-optimization/deep-audit/probes")
dir.create(audit_dir, recursive = TRUE, showWarnings = FALSE)
Sys.setenv(XGELO_AUDIT_SETUP_ONLY = "1")
source(file.path(probe_dir, "nl-profile.R"))
reference_outputs <- lapply(1:8, kernel)
audit_scalar_frame <- function(..., row.names = NULL, check.rows = FALSE,
    check.names = TRUE, fix.empty.names = TRUE, stringsAsFactors = FALSE) {
  columns <- list(...)
  named <- length(columns) > 0L && length(names(columns)) == length(columns) && all(nzchar(names(columns)))
  scalar_atomic <- named && all(vapply(columns, function(x) is.atomic(x) && length(x) == 1L && !is.object(x), logical(1)))
  if (scalar_atomic && is.null(row.names) && !stringsAsFactors && !check.rows) {
    if (check.names) names(columns) <- make.names(names(columns), unique = TRUE)
    return(structure(columns, class = "data.frame", row.names = c(NA_integer_, -1L)))
  }
  base::data.frame(..., row.names = row.names, check.rows = check.rows,
    check.names = check.names, fix.empty.names = fix.empty.names, stringsAsFactors = stringsAsFactors)
}
runtime$data.frame <- audit_scalar_frame
for (i in 1:8) stopifnot(identical(kernel(i), reference_outputs[[i]]))
results <- list()
for (repeat_id in 1:2) {
  for (variant in if (repeat_id %% 2L) c("reference", "scalar_row_templates") else c("scalar_row_templates", "reference")) {
    if (variant == "reference") rm("data.frame", envir = runtime) else runtime$data.frame <- audit_scalar_frame
    gc()
    elapsed <- system.time(for (i in 1:8) invisible(kernel(i)))[["elapsed"]]
    results[[length(results) + 1L]] <- data.frame(variant = variant, repeat_id = repeat_id, count = 8L, elapsed_seconds = elapsed)
  }
}
result <- do.call(rbind, results)
write.csv(result, file.path(audit_dir, "nl-rows-prototype-times.csv"), row.names = FALSE)
jsonlite::write_json(list(full_iteration_cases = 8L, full_iteration_objects_identical = TRUE,
  experiment_only = TRUE, public_data_frame_unchanged = TRUE,
  production_recommendation = "explicit typed row constructors at profiled call sites; retain public validators",
  production_code_changed = FALSE), file.path(audit_dir, "nl-rows-prototype-parity.json"), auto_unbox = TRUE, pretty = TRUE)
print(result)
