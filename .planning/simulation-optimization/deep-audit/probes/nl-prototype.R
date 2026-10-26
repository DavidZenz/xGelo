# Audit-only probe; no production publication or performance certificate.
# Run from the worktree root. See ../../DEEP-AUDIT.md for input requirements.
audit_dir <- Sys.getenv("XGELO_AUDIT_DIR", "/private/tmp/xgelo-deep-audit")
probe_dir <- Sys.getenv("XGELO_AUDIT_PROBE_DIR", ".planning/simulation-optimization/deep-audit/probes")
dir.create(audit_dir, recursive = TRUE, showWarnings = FALSE)
Sys.setenv(XGELO_AUDIT_SETUP_ONLY = "1")
source(file.path(probe_dir, "nl-profile.R"))
# Warm the same bounded set in both variants; production's cold-cache cost is
# separately recorded in nl-kernel-times.csv.
reference_outputs <- if (Sys.getenv("XGELO_AUDIT_PROTOTYPE_SETUP_ONLY") == "1") list() else lapply(1:8, kernel)
original_build_wrapper <- runtime$uefa_nl_sim_build_league_state
original_build <- get("original", envir = environment(original_build_wrapper))
fast_build <- original_build
nodes <- as.list(body(fast_build))
for_index <- which(vapply(nodes, function(x) is.call(x) && identical(x[[1L]], as.name("for")), logical(1)))
stopifnot(length(for_index) == 1L)
loop <- nodes[[for_index]]; statements <- as.list(loop[[4L]])
assignment_to <- function(x, text) is.call(x) && identical(x[[1L]], as.name("<-")) && identical(paste(deparse(x[[2L]]), collapse = ""), text)
first <- which(vapply(statements, assignment_to, logical(1), text = "fields_hash"))
last <- which(vapply(statements, assignment_to, logical(1), text = "snapshot$table_sha256"))
stopifnot(length(first) == 1L, length(last) == 1L, first < last)
loop[[4L]] <- as.call(statements[-seq.int(first, last)])
nodes[[for_index]] <- loop; body(fast_build) <- as.call(nodes)
original_prepare <- runtime$uefa_nl_rank_prepare_matches
original_parse <- runtime$uefa_nl_rank_parse_utc
prepare_cache <- new.env(parent = emptyenv()); parse_cache <- new.env(parent = emptyenv())
fast_prepare <- function(match_rows, team_ids, standings) {
  # Audit-only trusted accepted roster: one fixed match slice per group in an
  # iteration. A production seam should use a prepared group integer index.
  key <- if (Sys.getenv("XGELO_AUDIT_NL_MEMO") == "hashed") digest::digest(list(match_rows, sort(team_ids), standings[, intersect(c("state_cutoff_utc", "group_id"), names(standings)), drop = FALSE]), algo = "xxhash64") else paste(sort(team_ids), collapse = "\x1f")
  if (!exists(key, prepare_cache, inherits = FALSE)) assign(key, original_prepare(match_rows, team_ids, standings), prepare_cache)
  get(key, prepare_cache, inherits = FALSE)
}
fast_parse <- function(values) {
  key <- digest::digest(values, algo = "xxhash64")
  if (!exists(key, parse_cache, inherits = FALSE)) assign(key, original_parse(values), parse_cache)
  get(key, parse_cache, inherits = FALSE)
}
# The hashes here are audit-only memo lookup keys, never football identities.
# A production seam should pass prepared objects directly, avoiding cache keys.
set_variant <- function(fast) {
  runtime$uefa_nl_sim_build_league_state <- if (fast) fast_build else original_build_wrapper
  runtime$uefa_nl_rank_prepare_matches <- if (fast) fast_prepare else original_prepare
  runtime$uefa_nl_rank_parse_utc <- if (fast) fast_parse else original_parse
}
audit_iteration <- function(i) {
  rm(list = ls(prepare_cache), envir = prepare_cache)
  kernel(i)
}
if (Sys.getenv("XGELO_AUDIT_PROTOTYPE_SETUP_ONLY") != "1") {
set_variant(TRUE)
for (i in 1:8) stopifnot(identical(audit_iteration(i), reference_outputs[[i]]))
results <- list()
for (repeat_id in 1:2) {
  for (variant in if (repeat_id %% 2L) c("reference", "prepared_reuse") else c("prepared_reuse", "reference")) {
    set_variant(variant == "prepared_reuse"); gc()
    elapsed <- system.time(for (i in 1:8) invisible(audit_iteration(i)))[["elapsed"]]
    results[[length(results) + 1L]] <- data.frame(variant = variant, repeat_id = repeat_id, count = 8L, elapsed_seconds = elapsed)
  }
}
result <- do.call(rbind, results)
write.csv(result, file.path(audit_dir, if (Sys.getenv("XGELO_AUDIT_NL_MEMO") == "hashed") "nl-prototype-times.csv" else "nl-prepared-prototype-times.csv"), row.names = FALSE)
jsonlite::write_json(list(full_iteration_cases = 8L, full_iteration_objects_identical = TRUE,
  prototype = c("omit overwritten intermediate snapshot hashes", "reuse within-iteration match preparation", "memo immutable timestamp vectors"),
  production_code_changed = FALSE, scope = "warm selected kernels only; no scale certification"),
  file.path(audit_dir, if (Sys.getenv("XGELO_AUDIT_NL_MEMO") == "hashed") "nl-prototype-parity.json" else "nl-prepared-prototype-parity.json"), auto_unbox = TRUE, pretty = TRUE)
print(result)
}
