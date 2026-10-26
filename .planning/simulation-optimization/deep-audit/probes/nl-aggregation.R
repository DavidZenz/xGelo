# Audit-only probe; no production publication or performance certificate.
# Run from the worktree root. See ../../DEEP-AUDIT.md for input requirements.
audit_dir <- Sys.getenv("XGELO_AUDIT_DIR", "/private/tmp/xgelo-deep-audit")
probe_dir <- Sys.getenv("XGELO_AUDIT_PROBE_DIR", ".planning/simulation-optimization/deep-audit/probes")
dir.create(audit_dir, recursive = TRUE, showWarnings = FALSE)
source("R/competition/uefa_nations_league_simulation.R")
directory <- file.path(audit_dir, "nl-read-probe")
dir.create(directory, showWarnings = FALSE)
original <- Sys.getenv("XGELO_AUDIT_NL_TRACE", "/private/tmp/xgelo-stream-profile/run-30")
file.copy(file.path(original, "manifest.rds"), directory, overwrite = TRUE)
dir.create(file.path(directory, "chunk-000001"), showWarnings = FALSE)
file.copy(list.files(file.path(original, "chunk-000001"), full.names = TRUE),
  file.path(directory, "chunk-000001"), overwrite = TRUE)
manifest <- readRDS(file.path(directory, "manifest.rds"))
store <- structure(list(run_dir = directory, manifest = manifest, complete = TRUE), class = "simulation_trace_store")
metadata <- manifest$identity$metadata
stopifnot(is.list(metadata), manifest$count > 0L)
fields <- c("stage_slots", "stage_matches", "stage_resolutions")
transform <- function(frame) uefa_nl_sim_add_metadata(frame, metadata$edition_id, metadata$projection_run_id,
  manifest$count, metadata$simulation_seed, metadata$rules, metadata$source_bundle_id,
  metadata$source_bundle_sha256, metadata$model_release_id)
scope <- new.env(parent = environment(uefa_nl_sim_add_metadata))
fixed_hash <- uefa_nl_ruleset_sha256(metadata$rules)
scope$uefa_nl_ruleset_sha256 <- function(rules) {
  stopifnot(identical(rules, metadata$rules)); fixed_hash
}
prepared <- uefa_nl_sim_add_metadata; environment(prepared) <- scope
transform_fast <- function(frame) prepared(frame, metadata$edition_id, metadata$projection_run_id,
  manifest$count, metadata$simulation_seed, metadata$rules, metadata$source_bundle_id,
  metadata$source_bundle_sha256, metadata$model_release_id)
results <- list(); hashes <- list()
for (variant in c("reference", "fixed_metadata")) {
  callback <- if (variant == "reference") transform else transform_fast
  elapsed <- system.time(hashes[[variant]] <- simulation_trace_nl_hashes(store, fields, callback,
    uefa_nl_sim_hash_column))[["elapsed"]]
  results[[variant]] <- data.frame(variant = variant, count = manifest$count, elapsed_seconds = elapsed)
}
stopifnot(identical(hashes$reference, hashes$fixed_metadata))
result <- do.call(rbind, results)
write.csv(result, file.path(audit_dir, "nl-canonical-times.csv"), row.names = FALSE)
jsonlite::write_json(list(exact_three_trace_hashes = TRUE, hashes = as.list(hashes$reference),
  count = manifest$count, production_code_changed = FALSE, checkpoint_copy_only = TRUE),
  file.path(audit_dir, "nl-canonical-parity.json"), auto_unbox = TRUE, pretty = TRUE)
print(result)
