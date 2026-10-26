# Audit-only probe; no production publication or performance certificate.
# Run from the worktree root. See ../../DEEP-AUDIT.md for input requirements.
audit_dir <- Sys.getenv("XGELO_AUDIT_DIR", "/private/tmp/xgelo-deep-audit")
probe_dir <- Sys.getenv("XGELO_AUDIT_PROBE_DIR", ".planning/simulation-optimization/deep-audit/probes")
dir.create(audit_dir, recursive = TRUE, showWarnings = FALSE)
source("tests/testthat/helper_uefa_champions_league.R")
for (name in c("rules", "state", "simulation")) source(paste0("R/competition/uefa_champions_league_", name, ".R"))
inputs <- readRDS(file.path(audit_dir, "cl-probe-inputs.rds"))
graph <- inputs$graph; rules <- inputs$rules; cutoff <- "2026-09-01T00:00:00Z"
.ucl_rule_phase18_available()
# Audit-only encoders. The reference defines the bytes; prepare only invariant
# framing. No new seed family, algorithm, football rule or digest is introduced.
audit_frame <- function(bytes) c(writeBin(as.integer(length(bytes)), raw(), size = 4L, endian = "big"), bytes)
audit_text_frame <- function(text) audit_frame(charToRaw(enc2utf8(text)))
audit_scalar_prefix <- function(field, type) c(audit_text_frame("phase18-canonical-v2"),
  audit_text_frame("scalar"), audit_text_frame(field), audit_text_frame(type))
audit_present <- audit_text_frame("present"); audit_missing <- audit_text_frame("missing")
audit_scalar <- function(value, type, prefix) {
  missing <- is.na(value[[1L]])
  payload <- if (missing) raw() else phase18_v2_raw(phase18_v2_scalar_text(value, type))
  audit_frame(c(prefix, if (missing) audit_missing else audit_present, audit_frame(payload)))
}
audit_fast_seed <- local({
  header <- c(audit_text_frame("phase18-canonical-v2"), audit_text_frame("sequence"),
    audit_text_frame("ucl20-simulation-sequence-v2"), audit_text_frame("3"))
  prefixes <- lapply(paste0("value_", 1:3), audit_scalar_prefix, type = "character")
  function(seed, ...) {
    values <- c(seed, ...)
    if (length(values) != 3L) return(.ucl_sim_seed_for(seed, ...))
    bytes <- c(header, audit_scalar(as.character(values[[1L]]), "character", prefixes[[1L]]),
      audit_scalar(as.character(values[[2L]]), "character", prefixes[[2L]]),
      audit_scalar(as.character(values[[3L]]), "character", prefixes[[3L]]))
    value <- suppressWarnings(strtoi(substr(digest::digest(bytes, algo = "sha256", serialize = FALSE), 1L, 7L), 16L))
    if (is.na(value)) value <- 1L
    as.integer((as.numeric(value) %% (.Machine$integer.max - 1)) + 1)
  }
})
audit_fast_trace_hash <- local({
  layout <- NULL; header <- NULL; prefixes <- NULL
  function(data) {
    if (!nrow(data)) return(character())
    fields <- setdiff(names(data), "row_sha256")
    types <- vapply(data[fields], phase18_v2_type_tag, character(1))
    next_layout <- list(fields, types)
    if (!identical(next_layout, layout)) {
      layout <<- next_layout
      header <<- c(audit_text_frame("phase18-canonical-v2"), audit_text_frame("row"),
        audit_text_frame("ucl-rules-trace-v2"), audit_text_frame(as.character(length(fields))))
      prefixes <<- lapply(seq_along(fields), function(i) audit_scalar_prefix(fields[[i]], types[[i]]))
    }
    columns <- lapply(seq_along(fields), function(i) {
      column <- data[[fields[[i]]]]; values <- unique(column)
      encoded <- lapply(seq_along(values), function(j) audit_scalar(values[j], types[[i]], prefixes[[i]]))
      encoded[match(column, values)]
    })
    vapply(seq_len(nrow(data)), function(row) digest::digest(
      do.call(c, c(list(header), lapply(columns, `[[`, row))), algo = "sha256", serialize = FALSE), character(1))
  }
})
scope <- new.env(parent = .GlobalEnv)
scope$.ucl_sim_seed_for <- audit_fast_seed
scope$.ucl_rule_hash_rows <- audit_fast_trace_hash
for (name in c(".ucl_sim_prepare_sampler", ".ucl_sim_prepare_ranker", "ucl_apply_article18")) {
  fn <- get(name); environment(fn) <- scope; assign(name, fn, scope)
}
original_sampler <- .ucl_sim_prepare_sampler(graph, inputs$ledger$ledger, cutoff)
original_ranker <- .ucl_sim_prepare_ranker(graph, rules, cutoff)
fast_sampler <- scope$.ucl_sim_prepare_sampler(graph, inputs$ledger$ledger, cutoff)
fast_ranker <- scope$.ucl_sim_prepare_ranker(graph, rules, cutoff)
if (Sys.getenv("XGELO_AUDIT_SETUP_ONLY") != "1") {
seed_probes <- expand.grid(seed = c(-100L, 0L, 7L, 2147483646L),
  label = c("fixture", "iteration"), value = c("1", "CL-144", "é", "x\x1fy", NA_character_), stringsAsFactors = FALSE)
stopifnot(all(vapply(seq_len(nrow(seed_probes)), function(i) {
  p <- seed_probes[i, ]; identical(audit_fast_seed(p$seed, p$label, p$value), .ucl_sim_seed_for(p$seed, p$label, p$value))
}, logical(1))))
set.seed(918L); caller_seed <- .Random.seed
for (i in 1:64) {
  sampled <- fast_sampler(i, 7L)
  stopifnot(identical(sampled, inputs$samples[[i]]))
  stopifnot(identical(fast_ranker(sampled), inputs$rankings[[i]]))
}
stopifnot(identical(.Random.seed, caller_seed))
benchmark <- function(sampler, ranker) system.time(for (i in 1:64) {
  sampled <- sampler(i, 7L); ranked <- ranker(sampled)
})[["elapsed"]]
results <- list()
for (repeat_id in 1:2) {
  for (variant in if (repeat_id %% 2L) c("reference", "prepared_frames") else c("prepared_frames", "reference")) {
    gc()
    elapsed <- if (variant == "reference") benchmark(original_sampler, original_ranker) else benchmark(fast_sampler, fast_ranker)
    results[[length(results) + 1L]] <- data.frame(variant = variant, repeat_id = repeat_id, count = 64L, elapsed_seconds = elapsed)
  }
}
result <- do.call(rbind, results)
write.csv(result, file.path(audit_dir, "cl-prototype-times.csv"), row.names = FALSE)
jsonlite::write_json(list(seed_cases = nrow(seed_probes), full_sampling_and_ranking_cases = 64L,
  caller_rng_preserved = TRUE, full_rank_attributes_and_trace_hashes_identical = TRUE,
  production_code_changed = FALSE), file.path(audit_dir, "cl-prototype-parity.json"), auto_unbox = TRUE, pretty = TRUE)
print(result)
}
