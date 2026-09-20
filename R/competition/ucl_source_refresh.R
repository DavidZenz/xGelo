#' Fail-closed UCL refresh transactions selected by one atomic pointer.

phase18_ucl_refresh_reason_codes <- function() c(
  "accepted", "missing_credential", "owner_review_required", "terms_changed", "authority_invalid",
  "fixture_non_promotable", "http_failure", "rate_limited", "null_response", "empty_response",
  "stale_response", "incomplete_pagination", "schema_invalid", "expectation_mismatch",
  "coverage_invalid", "identity_invalid", "provenance_collision", "secret_exposure",
  "concurrent_refresh", "interrupted", "provider_exit_required", "promotion_failure",
  "read_back_failure", "history_write_failure", "sidecar_write_failure", "unknown_failure"
)

phase18_ucl_refresh_abort <- function(reason_code, message, failure_phase = "preflight") {
  if (!reason_code %in% phase18_ucl_refresh_reason_codes()) reason_code <- "unknown_failure"
  stop(structure(list(message = as.character(message), call = NULL, reason_code = reason_code,
    failure_phase = failure_phase), class = c(paste0("phase18_refresh_", reason_code),
    "phase18_ucl_refresh_error", "error", "condition")))
}

phase18_classify_ucl_refresh_failure <- function(error) {
  if (inherits(error, "phase18_ucl_refresh_error")) return(list(
    reason_code = as.character(error$reason_code), failure_phase = as.character(error$failure_phase)))
  mapped <- c(blocked_empty_resource = "empty_response", blocked_incomplete_graph = "incomplete_pagination",
    blocked_schema = "schema_invalid", blocked_expectation = "expectation_mismatch",
    blocked_foreign_key = "identity_invalid", blocked_duplicate_key = "identity_invalid",
    blocked_authority = "authority_invalid", blocked_provenance_collision = "provenance_collision",
    blocked_candidate_exists = "provenance_collision", blocked_raw_hash = "schema_invalid",
    blocked_row_hash = "schema_invalid", blocked_canonical_hash = "schema_invalid",
    blocked_bundle_hash = "schema_invalid", blocked_manifest_hash = "schema_invalid",
    blocked_inventory = "incomplete_pagination", blocked_symlink = "schema_invalid",
    blocked_unsafe_path = "schema_invalid", blocked_migration_required = "schema_invalid")
  hit <- intersect(names(mapped), class(error))
  if (length(hit)) return(list(reason_code = unname(mapped[[hit[[1L]]]]), failure_phase = "candidate_validation"))
  message <- tolower(conditionMessage(error))
  patterns <- list(missing_credential = "credential|token.*missing", rate_limited = "rate.?limit|http 429",
    http_failure = "http|server error|network", null_response = "null response|null payload",
    stale_response = "stale|freshness", incomplete_pagination = "pagination|incomplete",
    secret_exposure = "secret|credential exposure", interrupted = "interrupt|terminated|killed",
    concurrent_refresh = "lock collision|concurrent", read_back_failure = "read.?back",
    promotion_failure = "promotion|promote", history_write_failure = "history[_ ]writer|history write",
    sidecar_write_failure = "sidecar[_ ]writer|sidecar write")
  for (reason in names(patterns)) if (grepl(patterns[[reason]], message, perl = TRUE))
    return(list(reason_code = reason, failure_phase = "technical"))
  list(reason_code = "unknown_failure", failure_phase = "technical")
}

phase18_ucl_refresh_scalar <- function(value, field, allow_empty = FALSE) {
  if (is.null(value) || length(value) != 1L || is.na(value[[1L]]))
    phase18_ucl_refresh_abort("schema_invalid", paste0(field, " must be one value"))
  value <- enc2utf8(as.character(value[[1L]]))
  if (!allow_empty && !nzchar(value)) phase18_ucl_refresh_abort("schema_invalid", paste0(field, " must not be empty"))
  value
}

phase18_ucl_refresh_bool <- function(value, field) {
  if (is.logical(value) && length(value) == 1L && !is.na(value)) return(value)
  token <- tolower(phase18_ucl_refresh_scalar(value, field))
  if (!token %in% c("true", "false")) phase18_ucl_refresh_abort("schema_invalid", paste0(field, " must be TRUE or FALSE"))
  identical(token, "true")
}

phase18_ucl_refresh_safe_id <- function(value, field) {
  value <- phase18_ucl_refresh_scalar(value, field)
  if (!grepl("^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$", value))
    phase18_ucl_refresh_abort("schema_invalid", paste0(field, " is not a safe identifier"))
  value
}

phase18_ucl_refresh_safe_relative_path <- function(path) {
  path <- gsub("\\\\", "/", phase18_ucl_refresh_scalar(path, "relative_path"))
  if (grepl("^/|^[A-Za-z]:|(^|/)\\.\\.?(/|$)|//", path))
    phase18_ucl_refresh_abort("schema_invalid", "Refresh inventory contains an unsafe path")
  path
}

phase18_ucl_refresh_roots <- function(accepted_root, registry_root) {
  accepted_root <- normalizePath(accepted_root, winslash = "/", mustWork = TRUE)
  registry_root <- normalizePath(registry_root, winslash = "/", mustWork = TRUE)
  if (!identical(dirname(accepted_root), dirname(registry_root)) || identical(accepted_root, registry_root) ||
      phase18_ucl_is_symlink(accepted_root) || phase18_ucl_is_symlink(registry_root))
    phase18_ucl_refresh_abort("schema_invalid", "Refresh accepted and registry roots must be non-symlinked siblings")
  common <- dirname(accepted_root)
  list(accepted_root = accepted_root, registry_root = registry_root, common_root = common,
    generations_root = file.path(common, "ucl_source_generations"),
    accepted_generations_root = file.path(common, "ucl_source_generations", "accepted"),
    transaction_generations_root = file.path(common, "ucl_source_generations", "transactions"),
    pointer_path = file.path(registry_root, "ucl_source_current.json"),
    legacy_history_path = file.path(registry_root, "ucl_source_refreshes.csv"),
    legacy_sidecar_path = file.path(registry_root, "ucl_source_blocked_refresh.json"),
    lock_path = file.path(common, ".phase18-ucl-refresh.lock"))
}

phase18_ucl_refresh_hash_list <- function(value, domain, exclude = character()) {
  value <- value[setdiff(sort(names(value)), exclude)]
  if (!length(value) || any(vapply(value, length, integer(1)) != 1L))
    phase18_ucl_refresh_abort("schema_invalid", paste0(domain, " requires scalar named fields"))
  phase18_hash_sequence_v2(value, domain, names(value), vapply(value, phase18_v2_type_tag, character(1)))
}

phase18_ucl_refresh_file_bytes <- function(path) {
  if (!file.exists(path) || dir.exists(path) || phase18_ucl_is_symlink(path))
    phase18_ucl_refresh_abort("schema_invalid", "Generation contains a missing or unsafe file", "read_back")
  readBin(path, "raw", n = file.info(path)$size)
}

phase18_ucl_refresh_inventory <- function(root) {
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  phase18_ucl_assert_no_symlink(root, root)
  files <- sort(list.files(root, recursive = TRUE, full.names = TRUE, all.files = TRUE, no.. = TRUE))
  files <- files[!file.info(files)$isdir]
  if (!length(files)) phase18_ucl_refresh_abort("schema_invalid", "Generation inventory is empty", "read_back")
  paths <- substring(files, nchar(root) + 2L)
  hashes <- vapply(files, function(path) phase18_ucl_hash(phase18_ucl_refresh_file_bytes(path)), character(1))
  values <- as.vector(rbind(paths, hashes))
  list(paths = paths, hashes = hashes, sha256 = phase18_hash_sequence_v2(as.list(values),
    "phase18-ucl-refresh-generation-inventory-v2",
    as.vector(rbind(paste0("path_", seq_along(paths)), paste0("sha256_", seq_along(paths)))),
    rep("character", length(values))))
}

phase18_ucl_refresh_atomic_json <- function(value, path, reason = "sidecar_write_failure") {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  stage <- tempfile(paste0(".", basename(path), "-"), tmpdir = dirname(path))
  on.exit(if (file.exists(stage)) unlink(stage, force = TRUE), add = TRUE)
  jsonlite::write_json(value, stage, auto_unbox = TRUE, pretty = TRUE, null = "null", digits = 17)
  if (!file.rename(stage, path)) phase18_ucl_refresh_abort(reason, "Atomic JSON replacement failed", "commit")
  invisible(path)
}

phase18_ucl_refresh_run_hook <- function(hooks, name, reason_code, failure_phase, ...) {
  hook <- hooks[[name]]
  if (is.null(hook)) return(invisible(NULL))
  if (!is.function(hook)) phase18_ucl_refresh_abort("schema_invalid", paste0("writer_hooks$", name, " must be a function"))
  tryCatch(hook(...), error = function(error) phase18_ucl_refresh_abort(reason_code, paste0("Injected ", name, " failure"), failure_phase))
  invisible(NULL)
}

phase18_ucl_refresh_copy_tree <- function(source, target, hooks = list()) {
  source <- normalizePath(source, winslash = "/", mustWork = TRUE); phase18_ucl_assert_no_symlink(source, source)
  files <- sort(list.files(source, recursive = TRUE, full.names = TRUE, all.files = TRUE, no.. = TRUE)); files <- files[!file.info(files)$isdir]
  paths <- substring(files, nchar(source) + 2L); dir.create(target, recursive = TRUE, showWarnings = FALSE)
  for (index in seq_along(files)) {
    destination <- file.path(target, phase18_ucl_refresh_safe_relative_path(paths[[index]])); dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
    if (!file.copy(files[[index]], destination, overwrite = FALSE, copy.mode = FALSE))
      phase18_ucl_refresh_abort("promotion_failure", "Could not stage exact candidate inventory", "staging")
    phase18_ucl_refresh_run_hook(hooks, "after_promotion", "promotion_failure", "staging", index, paths[[index]])
  }
  paths
}

phase18_ucl_refresh_history_schema <- function() c("schema_version", "hash_encoding_version", "refresh_batch_id",
  "event_at_utc", "edition_id", "status", "candidate_bundle_id", "candidate_bundle_sha256",
  "incumbent_status", "incumbent_bundle_id", "incumbent_bundle_sha256", "authority_type",
  "authority_id", "authority_sha256", "acceptance_decision_id", "acceptance_decision_sha256",
  "failure_phase", "reason_code", "disposition", "automation_enabled", "blocked_record_sha256", "row_sha256")

phase18_ucl_refresh_empty_history <- function() {
  out <- as.data.frame(setNames(replicate(length(phase18_ucl_refresh_history_schema()), character(), simplify = FALSE),
    phase18_ucl_refresh_history_schema()), stringsAsFactors = FALSE, check.names = FALSE); out$automation_enabled <- logical(); out
}

phase18_ucl_refresh_read_history <- function(path) {
  if (!file.exists(path)) return(phase18_ucl_refresh_empty_history())
  out <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = NULL)
  for (field in setdiff(names(out), "automation_enabled")) { out[[field]] <- as.character(out[[field]]); out[[field]][is.na(out[[field]])] <- "" }
  out
}

phase18_ucl_refresh_row_hash <- function(row) {
  if (!is.data.frame(row) || nrow(row) != 1L || !identical(names(row), phase18_ucl_refresh_history_schema()))
    phase18_ucl_refresh_abort("schema_invalid", "Refresh event schema is invalid", "history")
  phase18_hash_row_v2(row, exclude = c("blocked_record_sha256", "row_sha256"), schema_tag = "phase18-ucl-source-refresh-row-v2")[[1L]]
}

phase18_ucl_refresh_sidecar_hash <- function(sidecar)
  phase18_ucl_refresh_hash_list(sidecar, "phase18-ucl-blocked-refresh-sidecar-v2", "blocked_record_sha256")

phase18_ucl_refresh_bundle_identity <- function(candidate) {
  if (is.null(candidate)) return(list(status = "no_incumbent", id = "", sha256 = ""))
  if (!is.null(candidate$tombstone)) return(list(status = "unavailable_tombstone",
    id = as.character(candidate$tombstone$exit_review_id), sha256 = as.character(candidate$tombstone$tombstone_sha256)))
  list(status = "last_known_good", id = as.character(candidate$bundle$bundle_id[[1L]]),
    sha256 = as.character(candidate$bundle$bundle_sha256[[1L]]))
}

phase18_ucl_refresh_batch_id <- function(now_utc, candidate_root, history) {
  token <- substr(phase18_hash_sequence_v2(list(as.character(now_utc), as.character(candidate_root),
    as.integer(nrow(history) + 1L), as.integer(Sys.getpid())), "phase18-ucl-refresh-batch-id-v2",
    c("event_at_utc", "candidate", "ordinal", "pid"), c("character", "character", "integer", "integer")), 1L, 20L)
  phase18_ucl_refresh_safe_id(paste0("ucl-refresh-", gsub("[^0-9]", "", now_utc), "-", token), "refresh_batch_id")
}

phase18_ucl_refresh_event_row <- function(refresh_batch_id, now_utc, edition_id, status, candidate, incumbent,
    failure_phase, reason_code, disposition = "", automation_enabled = FALSE) {
  authority <- if (is.null(candidate) || is.null(candidate$authority)) NULL else candidate$authority
  bundle <- if (is.null(candidate) || is.null(candidate$bundle)) NULL else candidate$bundle
  type <- if (is.null(authority)) "" else as.character(authority$authority_type[[1L]])
  row <- data.frame(schema_version = "phase18-ucl-source-refresh-v2", hash_encoding_version = phase18_canonical_encoding_v2(),
    refresh_batch_id = refresh_batch_id, event_at_utc = as.character(now_utc), edition_id = edition_id, status = status,
    candidate_bundle_id = if (is.null(bundle)) "" else as.character(bundle$bundle_id[[1L]]),
    candidate_bundle_sha256 = if (is.null(bundle)) "" else as.character(bundle$bundle_sha256[[1L]]),
    incumbent_status = incumbent$status, incumbent_bundle_id = incumbent$id, incumbent_bundle_sha256 = incumbent$sha256,
    authority_type = type, authority_id = if (is.null(authority)) "" else as.character(authority$authority_id[[1L]]),
    authority_sha256 = if (is.null(authority)) "" else as.character(authority$authority_sha256[[1L]]),
    acceptance_decision_id = if (identical(type, "provider_acceptance")) as.character(authority$provider_decision_id[[1L]]) else "",
    acceptance_decision_sha256 = if (identical(type, "provider_acceptance")) as.character(authority$provider_decision_sha256[[1L]]) else "",
    failure_phase = failure_phase, reason_code = reason_code, disposition = disposition,
    automation_enabled = isTRUE(automation_enabled), blocked_record_sha256 = "", row_sha256 = "",
    stringsAsFactors = FALSE, check.names = FALSE)
  row$row_sha256 <- phase18_ucl_refresh_row_hash(row); row
}

phase18_ucl_refresh_make_sidecar <- function(row) {
  out <- as.list(row[1L, setdiff(names(row), "blocked_record_sha256"), drop = FALSE]); out$schema_version <- "phase18-ucl-blocked-refresh-v2"
  out$history_row_sha256 <- row$row_sha256[[1L]]; out$blocked_record_sha256 <- ""
  out$blocked_record_sha256 <- phase18_ucl_refresh_sidecar_hash(out); out
}

phase18_validate_ucl_refresh_state <- function(history, blocked_sidecar = NULL, accepted_root = NULL) {
  if (!is.data.frame(history) || !identical(names(history), phase18_ucl_refresh_history_schema()))
    phase18_ucl_refresh_abort("schema_invalid", "Refresh history schema is invalid", "history")
  if (!nrow(history)) return(invisible(history))
  if (any(as.character(history$schema_version) != "phase18-ucl-source-refresh-v2") ||
      any(as.character(history$hash_encoding_version) != phase18_canonical_encoding_v2()) || anyDuplicated(as.character(history$refresh_batch_id)))
    phase18_ucl_refresh_abort("provenance_collision", "Refresh history is not canonical-v2 append-only", "history")
  expected <- vapply(seq_len(nrow(history)), function(i) phase18_ucl_refresh_row_hash(history[i, , drop = FALSE]), character(1))
  if (!identical(tolower(as.character(history$row_sha256)), expected)) phase18_ucl_refresh_abort("schema_invalid", "Refresh history row hash mismatch", "history")
  last <- history[nrow(history), , drop = FALSE]
  if (identical(as.character(last$status[[1L]]), "blocked")) {
    if (is.null(blocked_sidecar) || !is.list(blocked_sidecar) ||
        !identical(as.character(blocked_sidecar$history_row_sha256), as.character(last$row_sha256[[1L]])) ||
        !identical(as.character(blocked_sidecar$blocked_record_sha256), as.character(last$blocked_record_sha256[[1L]])) ||
        !identical(phase18_ucl_refresh_sidecar_hash(blocked_sidecar), as.character(blocked_sidecar$blocked_record_sha256)))
      phase18_ucl_refresh_abort("schema_invalid", "Blocked sidecar and history row disagree", "sidecar")
  } else if (!is.null(blocked_sidecar)) phase18_ucl_refresh_abort("schema_invalid", "Non-blocked state cannot carry a blocked sidecar", "sidecar")
  invisible(history)
}

phase18_ucl_refresh_state_hash <- function(state)
  phase18_ucl_refresh_hash_list(state, "phase18-ucl-refresh-transaction-state-v2", "state_sha256")
phase18_ucl_refresh_pointer_hash <- function(pointer)
  phase18_ucl_refresh_hash_list(pointer, "phase18-ucl-refresh-current-pointer-v2", "pointer_sha256")

phase18_ucl_refresh_finalize_dir <- function(stage, target) {
  if (file.exists(target) || dir.exists(target)) phase18_ucl_refresh_abort("provenance_collision", "Generation ID already exists", "staging")
  if (!file.rename(stage, target)) phase18_ucl_refresh_abort("promotion_failure", "Could not finalize immutable generation", "staging")
  invisible(target)
}

phase18_ucl_refresh_stage_accepted <- function(candidate_root, candidate, roots, generation_id, hooks = list()) {
  dir.create(roots$accepted_generations_root, recursive = TRUE, showWarnings = FALSE)
  stage <- tempfile(".accepted-stage-", tmpdir = roots$accepted_generations_root); dir.create(stage)
  on.exit(if (dir.exists(stage)) unlink(stage, recursive = TRUE, force = TRUE), add = TRUE)
  phase18_ucl_refresh_copy_tree(candidate_root, stage, hooks)
  staged <- phase18_read_ucl_candidate(stage); phase18_validate_ucl_source_bundle(staged)
  if (!identical(as.character(staged$bundle$manifest_self_sha256[[1L]]), as.character(candidate$bundle$manifest_self_sha256[[1L]])))
    phase18_ucl_refresh_abort("read_back_failure", "Staged candidate differs from validated snapshot", "staging")
  inventory <- phase18_ucl_refresh_inventory(stage)
  target <- file.path(roots$accepted_generations_root, phase18_ucl_refresh_safe_id(generation_id, "accepted_generation_id"))
  phase18_ucl_refresh_finalize_dir(stage, target)
  list(id = generation_id, root = target, sha256 = inventory$sha256, status = "accepted", candidate = staged)
}

phase18_ucl_refresh_stage_transaction <- function(roots, generation_id, history, sidecar, accepted_ref, hooks = list()) {
  dir.create(roots$transaction_generations_root, recursive = TRUE, showWarnings = FALSE)
  stage <- tempfile(".transaction-stage-", tmpdir = roots$transaction_generations_root); dir.create(stage)
  on.exit(if (dir.exists(stage)) unlink(stage, recursive = TRUE, force = TRUE), add = TRUE)
  history_path <- file.path(stage, "ucl_source_refreshes.csv")
  phase18_ucl_refresh_run_hook(hooks, "history_writer", "history_write_failure", "history", history, history_path)
  utils::write.csv(history, history_path, row.names = FALSE, na = "", quote = TRUE)
  sidecar_sha <- ""
  if (!is.null(sidecar)) {
    sidecar_path <- file.path(stage, "ucl_source_blocked_refresh.json")
    phase18_ucl_refresh_run_hook(hooks, "sidecar_writer", "sidecar_write_failure", "sidecar", sidecar, sidecar_path)
    phase18_ucl_refresh_atomic_json(sidecar, sidecar_path)
    sidecar_sha <- phase18_ucl_hash(phase18_ucl_refresh_file_bytes(sidecar_path))
  }
  state <- list(schema_version = "phase18-ucl-refresh-transaction-state-v2",
    hash_encoding_version = phase18_canonical_encoding_v2(), transaction_generation_id = generation_id,
    history_sha256 = phase18_ucl_hash(phase18_ucl_refresh_file_bytes(history_path)), sidecar_sha256 = sidecar_sha,
    accepted_status = accepted_ref$status, accepted_generation_id = accepted_ref$id,
    accepted_generation_sha256 = accepted_ref$sha256, state_sha256 = "")
  state$state_sha256 <- phase18_ucl_refresh_state_hash(state)
  phase18_ucl_refresh_atomic_json(state, file.path(stage, "state.json"))
  phase18_validate_ucl_refresh_state(history, sidecar)
  inventory <- phase18_ucl_refresh_inventory(stage); target <- file.path(roots$transaction_generations_root, generation_id)
  phase18_ucl_refresh_finalize_dir(stage, target)
  list(id = generation_id, root = target, sha256 = inventory$sha256, state = state, history = history, sidecar = sidecar)
}

phase18_ucl_refresh_commit_pointer <- function(roots, transaction, accepted_ref, now_utc) {
  pointer <- list(schema_version = "phase18-ucl-source-current-v2", hash_encoding_version = phase18_canonical_encoding_v2(),
    committed_at_utc = as.character(now_utc), transaction_generation_id = transaction$id,
    transaction_generation_path = file.path("transactions", transaction$id), transaction_generation_sha256 = transaction$sha256,
    accepted_status = accepted_ref$status, accepted_generation_id = accepted_ref$id,
    accepted_generation_path = if (nzchar(accepted_ref$id)) file.path("accepted", accepted_ref$id) else "",
    accepted_generation_sha256 = accepted_ref$sha256, pointer_sha256 = "")
  pointer$pointer_sha256 <- phase18_ucl_refresh_pointer_hash(pointer)
  phase18_ucl_refresh_atomic_json(pointer, roots$pointer_path, "promotion_failure")
  pointer
}

phase18_validate_ucl_refresh_current <- function(current) {
  if (!is.list(current) || is.null(current$pointer) || is.null(current$state) || is.null(current$history))
    phase18_ucl_refresh_abort("schema_invalid", "Current refresh state is incomplete", "read_back")
  if (!identical(as.character(current$pointer$accepted_status), as.character(current$state$accepted_status)) ||
      !identical(as.character(current$pointer$accepted_generation_id), as.character(current$state$accepted_generation_id)) ||
      !identical(as.character(current$pointer$accepted_generation_sha256), as.character(current$state$accepted_generation_sha256)))
    phase18_ucl_refresh_abort("schema_invalid", "Pointer and transaction accepted references disagree", "read_back")
  invisible(current)
}

phase18_read_ucl_refresh_current <- function(accepted_root = "data/competition/accepted", registry_root = "data/competition/registries") {
  roots <- phase18_ucl_refresh_roots(accepted_root, registry_root)
  if (!file.exists(roots$pointer_path)) return(NULL)
  pointer <- jsonlite::fromJSON(roots$pointer_path, simplifyVector = TRUE)
  required <- c("schema_version", "hash_encoding_version", "committed_at_utc", "transaction_generation_id",
    "transaction_generation_path", "transaction_generation_sha256", "accepted_status", "accepted_generation_id",
    "accepted_generation_path", "accepted_generation_sha256", "pointer_sha256")
  if (length(setdiff(required, names(pointer))) || !identical(as.character(pointer$schema_version), "phase18-ucl-source-current-v2") ||
      !identical(as.character(pointer$hash_encoding_version), phase18_canonical_encoding_v2()) ||
      !identical(as.character(pointer$pointer_sha256), phase18_ucl_refresh_pointer_hash(pointer)))
    phase18_ucl_refresh_abort("schema_invalid", "Current refresh pointer is invalid", "pointer")
  tx_rel <- phase18_ucl_refresh_safe_relative_path(pointer$transaction_generation_path)
  if (!startsWith(tx_rel, "transactions/") || dirname(tx_rel) != "transactions")
    phase18_ucl_refresh_abort("schema_invalid", "Current transaction reference is unsafe", "pointer")
  tx_root <- file.path(roots$generations_root, tx_rel); tx_inventory <- phase18_ucl_refresh_inventory(tx_root)
  if (!identical(tx_inventory$sha256, as.character(pointer$transaction_generation_sha256)))
    phase18_ucl_refresh_abort("schema_invalid", "Current transaction generation hash mismatch", "pointer")
  state <- jsonlite::fromJSON(file.path(tx_root, "state.json"), simplifyVector = TRUE)
  if (!identical(as.character(state$state_sha256), phase18_ucl_refresh_state_hash(state)) ||
      !identical(as.character(state$transaction_generation_id), as.character(pointer$transaction_generation_id)))
    phase18_ucl_refresh_abort("schema_invalid", "Transaction state manifest is invalid", "read_back")
  history_path <- file.path(tx_root, "ucl_source_refreshes.csv")
  if (!identical(phase18_ucl_hash(phase18_ucl_refresh_file_bytes(history_path)), as.character(state$history_sha256)))
    phase18_ucl_refresh_abort("schema_invalid", "Transaction ledger bytes are invalid", "history")
  history <- phase18_ucl_refresh_read_history(history_path)
  sidecar_path <- file.path(tx_root, "ucl_source_blocked_refresh.json")
  sidecar <- if (file.exists(sidecar_path)) jsonlite::fromJSON(sidecar_path, simplifyVector = TRUE) else NULL
  observed_sidecar <- if (is.null(sidecar)) "" else phase18_ucl_hash(phase18_ucl_refresh_file_bytes(sidecar_path))
  if (!identical(observed_sidecar, as.character(state$sidecar_sha256)))
    phase18_ucl_refresh_abort("schema_invalid", "Transaction sidecar bytes are invalid", "sidecar")
  phase18_validate_ucl_refresh_state(history, sidecar)
  accepted <- NULL; accepted_root_path <- ""
  if (!identical(as.character(pointer$accepted_status), "no_incumbent")) {
    accepted_rel <- phase18_ucl_refresh_safe_relative_path(pointer$accepted_generation_path)
    if (!startsWith(accepted_rel, "accepted/") || dirname(accepted_rel) != "accepted")
      phase18_ucl_refresh_abort("schema_invalid", "Current accepted reference is unsafe", "pointer")
    accepted_root_path <- file.path(roots$generations_root, accepted_rel); inventory <- phase18_ucl_refresh_inventory(accepted_root_path)
    if (!identical(inventory$sha256, as.character(pointer$accepted_generation_sha256)) ||
        !identical(inventory$sha256, as.character(state$accepted_generation_sha256)))
      phase18_ucl_refresh_abort("schema_invalid", "Current accepted generation hash mismatch", "read_back")
    if (identical(as.character(pointer$accepted_status), "accepted")) {
      accepted <- phase18_read_ucl_candidate(accepted_root_path); phase18_validate_ucl_source_bundle(accepted)
    } else if (identical(as.character(pointer$accepted_status), "unavailable_tombstone")) {
      accepted <- list(tombstone = phase18_validate_ucl_unavailable_tombstone(file.path(accepted_root_path, "source_unavailable.json")))
    } else phase18_ucl_refresh_abort("schema_invalid", "Current accepted status is invalid", "pointer")
  } else if (nzchar(as.character(pointer$accepted_generation_id)) || nzchar(as.character(pointer$accepted_generation_sha256)))
    phase18_ucl_refresh_abort("schema_invalid", "No-incumbent pointer contains an accepted reference", "pointer")
  out <- list(pointer = pointer, state = state, history = history, sidecar = sidecar, accepted = accepted,
    accepted_generation_root = accepted_root_path, transaction_generation_root = tx_root, roots = roots)
  phase18_validate_ucl_refresh_current(out); out
}

phase18_ucl_refresh_current_ref <- function(current) {
  if (is.null(current)) return(list(status = "no_incumbent", id = "", sha256 = "", root = "", candidate = NULL))
  list(status = as.character(current$pointer$accepted_status), id = as.character(current$pointer$accepted_generation_id),
    sha256 = as.character(current$pointer$accepted_generation_sha256), root = current$accepted_generation_root, candidate = current$accepted)
}

phase18_ucl_refresh_append <- function(current, row, sidecar, accepted_ref, roots, hooks = list()) {
  history <- if (is.null(current)) phase18_ucl_refresh_empty_history() else current$history
  if (row$refresh_batch_id[[1L]] %in% as.character(history$refresh_batch_id))
    phase18_ucl_refresh_abort("provenance_collision", "Refresh batch ID already exists", "history")
  if (!is.null(sidecar)) row$blocked_record_sha256 <- sidecar$blocked_record_sha256
  next_history <- rbind(history, row); phase18_validate_ucl_refresh_state(next_history, sidecar)
  phase18_ucl_refresh_stage_transaction(roots, as.character(row$refresh_batch_id[[1L]]), next_history, sidecar, accepted_ref, hooks)
}

phase18_ucl_refresh_validate_provider_authority <- function(candidate, acceptance_root) {
  authority <- candidate$authority; type <- as.character(authority$authority_type[[1L]])
  if (identical(type, "fixture_contract")) phase18_ucl_refresh_abort("fixture_non_promotable", "Fixture authority is never promotable", "authority")
  if (!phase18_ucl_bool(authority$promotion_eligible[[1L]], "promotion_eligible"))
    phase18_ucl_refresh_abort("authority_invalid", "Candidate authority is not promotion eligible", "authority")
  if (!identical(type, "provider_acceptance")) return(invisible(TRUE))
  evidence <- tryCatch(phase18_read_acceptance_set(file.path(acceptance_root, "football_data_org_v4",
    as.character(candidate$bundle$edition_id[[1L]]))), error = function(error) NULL)
  if (is.null(evidence) || !identical(as.character(evidence$manifest$decision_id[[1L]]), as.character(authority$provider_decision_id[[1L]])) ||
      !identical(as.character(evidence$manifest$row_sha256[[1L]]), as.character(authority$provider_decision_sha256[[1L]])))
    phase18_ucl_refresh_abort("authority_invalid", "Provider authority is stale", "authority")
  invisible(TRUE)
}

phase18_refresh_ucl_source <- function(candidate_root, accepted_root = "data/competition/accepted",
    registry_root = "data/competition/registries", acceptance_root = "data/competition/provider_acceptance",
    writer_hooks = list(), now_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")) {
  if (!is.list(writer_hooks)) phase18_ucl_refresh_abort("schema_invalid", "writer_hooks must be a list")
  roots <- phase18_ucl_refresh_roots(accepted_root, registry_root)
  if (file.exists(roots$lock_path) || dir.exists(roots$lock_path) || !dir.create(roots$lock_path, recursive = FALSE, showWarnings = FALSE))
    return(invisible(list(status = "blocked", reason_code = "concurrent_refresh", failure_phase = "lock", recorded = FALSE)))
  on.exit(if (dir.exists(roots$lock_path)) unlink(roots$lock_path, recursive = TRUE, force = TRUE), add = TRUE)
  current <- tryCatch(phase18_read_ucl_refresh_current(accepted_root, registry_root), error = function(error) error)
  if (inherits(current, "error")) { classified <- phase18_classify_ucl_refresh_failure(current); return(invisible(list(
    status = "blocked", reason_code = classified$reason_code, failure_phase = classified$failure_phase, recorded = FALSE))) }
  history <- if (is.null(current)) phase18_ucl_refresh_empty_history() else current$history
  incumbent_ref <- phase18_ucl_refresh_current_ref(current); incumbent <- phase18_ucl_refresh_bundle_identity(incumbent_ref$candidate)
  edition_id <- if (is.null(current) || is.null(current$accepted) || is.null(current$accepted$bundle)) "ucl_2026_27" else as.character(current$accepted$bundle$edition_id[[1L]])
  batch_id <- phase18_ucl_refresh_batch_id(now_utc, candidate_root, history); candidate <- NULL
  result <- tryCatch({
    candidate <- phase18_read_ucl_candidate(candidate_root); phase18_validate_ucl_source_bundle(candidate)
    edition_id <- as.character(candidate$bundle$edition_id[[1L]])
    phase18_ucl_refresh_validate_provider_authority(candidate, normalizePath(acceptance_root, winslash = "/", mustWork = FALSE))
    phase18_ucl_refresh_run_hook(writer_hooks, "before_promotion", "promotion_failure", "staging")
    accepted_ref <- phase18_ucl_refresh_stage_accepted(candidate_root, candidate, roots, paste0(batch_id, "-accepted"), writer_hooks)
    row <- phase18_ucl_refresh_event_row(batch_id, now_utc, edition_id, "accepted", candidate, incumbent, "", "accepted",
      "promoted", phase18_ucl_refresh_bool(candidate$authority$provider_automation_enabled[[1L]], "provider_automation_enabled"))
    transaction <- phase18_ucl_refresh_append(current, row, NULL, accepted_ref, roots, writer_hooks)
    phase18_ucl_refresh_run_hook(writer_hooks, "interrupt", "interrupted", "commit")
    phase18_ucl_refresh_run_hook(writer_hooks, "before_readback", "read_back_failure", "read_back")
    pointer <- phase18_ucl_refresh_commit_pointer(roots, transaction, accepted_ref, now_utc)
    phase18_ucl_refresh_run_hook(writer_hooks, "after_pointer_commit", "promotion_failure", "commit")
    list(status = "accepted", reason_code = "accepted", refresh_batch_id = batch_id,
      candidate_bundle_id = as.character(candidate$bundle$bundle_id[[1L]]), incumbent_status = incumbent$status,
      pointer_sha256 = pointer$pointer_sha256, recorded = TRUE)
  }, error = function(error) error)
  if (!inherits(result, "error")) return(invisible(result))
  classified <- phase18_classify_ucl_refresh_failure(result)
  if (classified$reason_code %in% c("promotion_failure", "interrupted", "read_back_failure"))
    return(invisible(list(status = "blocked", reason_code = classified$reason_code,
      failure_phase = classified$failure_phase, refresh_batch_id = batch_id,
      incumbent_status = incumbent$status, recorded = FALSE)))
  row <- phase18_ucl_refresh_event_row(batch_id, now_utc, edition_id, "blocked", candidate, incumbent,
    classified$failure_phase, classified$reason_code)
  sidecar <- phase18_ucl_refresh_make_sidecar(row); row$blocked_record_sha256 <- sidecar$blocked_record_sha256
  transaction <- tryCatch(phase18_ucl_refresh_append(current, row, sidecar, incumbent_ref, roots, writer_hooks), error = function(error) error)
  recorded <- !inherits(transaction, "error")
  if (recorded) phase18_ucl_refresh_commit_pointer(roots, transaction, incumbent_ref, now_utc)
  invisible(list(status = "blocked", reason_code = classified$reason_code, failure_phase = classified$failure_phase,
    refresh_batch_id = batch_id, incumbent_status = incumbent$status, recorded = recorded))
}

phase18_ucl_exit_review_hash <- function(review)
  phase18_hash_row_v2(review, exclude = c("exit_review_sha256", "row_sha256"), schema_tag = "phase18-ucl-provider-exit-review-v2")[[1L]]

phase18_hash_ucl_provider_exit_review <- function(review) {
  if (!is.data.frame(review) || nrow(review) != 1L)
    phase18_ucl_refresh_abort("owner_review_required", "Provider exit requires one reviewed row", "compliance")
  review$exit_review_sha256 <- phase18_ucl_exit_review_hash(review)
  review$row_sha256 <- phase18_hash_row_v2(review, exclude = "row_sha256", schema_tag = "phase18-ucl-provider-exit-review-row-v2")
  review
}

phase18_validate_ucl_provider_exit_review <- function(review) {
  required <- c("schema_version", "hash_encoding_version", "exit_review_id", "provider_id", "edition_id", "decision",
    "exit_disposition", "retention_permitted", "display_permitted", "terms_sha256", "provider_decision_id",
    "provider_decision_sha256", "incumbent_bundle_id", "incumbent_bundle_sha256", "reviewed_inventory_paths",
    "reviewed_inventory_sha256s", "reviewer", "reviewed_at_utc", "reason", "retained_relative_paths",
    "retained_inventory_sha256s", "exit_review_sha256", "row_sha256")
  if (!is.data.frame(review) || nrow(review) != 1L || length(setdiff(required, names(review))) ||
      !identical(as.character(review$schema_version[[1L]]), "phase18-ucl-provider-exit-review-v2") ||
      !identical(as.character(review$hash_encoding_version[[1L]]), phase18_canonical_encoding_v2()) ||
      !identical(as.character(review$decision[[1L]]), "reviewed") || !as.character(review$exit_disposition[[1L]]) %in% c("retain", "withdraw") ||
      !identical(as.character(review$exit_review_sha256[[1L]]), phase18_ucl_exit_review_hash(review)) ||
      !identical(as.character(review$row_sha256[[1L]]), phase18_hash_row_v2(review, exclude = "row_sha256", schema_tag = "phase18-ucl-provider-exit-review-row-v2")[[1L]]))
    phase18_ucl_refresh_abort("owner_review_required", "Provider exit review is incomplete or stale", "compliance")
  invisible(review)
}

phase18_ucl_refresh_token_inventory <- function(paths_token, hashes_token, root, label) {
  if (!nzchar(paths_token) && !nzchar(hashes_token)) return(setNames(character(), character()))
  paths <- strsplit(paths_token, "|", fixed = TRUE)[[1L]]; hashes <- strsplit(hashes_token, "|", fixed = TRUE)[[1L]]
  if (length(paths) != length(hashes) || anyDuplicated(paths))
    phase18_ucl_refresh_abort("owner_review_required", paste0(label, " inventory is invalid"), "compliance")
  paths <- vapply(paths, phase18_ucl_refresh_safe_relative_path, character(1)); hashes <- tolower(hashes)
  for (i in seq_along(paths)) {
    path <- file.path(root, paths[[i]])
    if (!file.exists(path) || dir.exists(path) || !identical(phase18_ucl_hash(phase18_ucl_refresh_file_bytes(path)), hashes[[i]]))
      phase18_ucl_refresh_abort("owner_review_required", paste0(label, " inventory is missing or changed"), "compliance")
  }
  setNames(hashes, paths)
}

phase18_ucl_unavailable_tombstone_hash <- function(value)
  phase18_ucl_refresh_hash_list(value, "phase18-ucl-source-unavailable-tombstone-v2", "tombstone_sha256")

phase18_validate_ucl_unavailable_tombstone <- function(path) {
  if (!file.exists(path) || dir.exists(path)) phase18_ucl_refresh_abort("schema_invalid", "UCL unavailable tombstone is missing", "compliance")
  value <- jsonlite::fromJSON(path, simplifyVector = TRUE)
  if (!identical(as.character(value$schema_version), "phase18-ucl-source-unavailable-v2") ||
      !identical(as.character(value$hash_encoding_version), phase18_canonical_encoding_v2()) ||
      !identical(as.character(value$tombstone_sha256), phase18_ucl_unavailable_tombstone_hash(value)))
    phase18_ucl_refresh_abort("schema_invalid", "UCL unavailable tombstone is invalid", "compliance")
  value
}

phase18_ucl_refresh_stage_tombstone <- function(source_root, retained, tombstone, roots, generation_id) {
  dir.create(roots$accepted_generations_root, recursive = TRUE, showWarnings = FALSE)
  stage <- tempfile(".tombstone-stage-", tmpdir = roots$accepted_generations_root); dir.create(stage)
  on.exit(if (dir.exists(stage)) unlink(stage, recursive = TRUE, force = TRUE), add = TRUE)
  for (relative in names(retained)) {
    destination <- file.path(stage, phase18_ucl_refresh_safe_relative_path(relative)); dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
    if (!file.copy(file.path(source_root, relative), destination, overwrite = FALSE, copy.mode = FALSE))
      phase18_ucl_refresh_abort("promotion_failure", "Could not stage retained lawful inventory", "compliance")
  }
  phase18_ucl_refresh_atomic_json(tombstone, file.path(stage, "source_unavailable.json"))
  phase18_validate_ucl_unavailable_tombstone(file.path(stage, "source_unavailable.json"))
  inventory <- phase18_ucl_refresh_inventory(stage); target <- file.path(roots$accepted_generations_root, generation_id)
  phase18_ucl_refresh_finalize_dir(stage, target)
  list(id = generation_id, root = target, sha256 = inventory$sha256, status = "unavailable_tombstone", tombstone = tombstone)
}

phase18_apply_provider_exit <- function(exit_review, accepted_root = "data/competition/accepted",
    registry_root = "data/competition/registries", writer_hooks = list(),
    now_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")) {
  phase18_validate_ucl_provider_exit_review(exit_review)
  roots <- phase18_ucl_refresh_roots(accepted_root, registry_root)
  if (file.exists(roots$lock_path) || dir.exists(roots$lock_path) || !dir.create(roots$lock_path, recursive = FALSE, showWarnings = FALSE))
    phase18_ucl_refresh_abort("concurrent_refresh", "Provider-exit lock collision", "compliance")
  on.exit(if (dir.exists(roots$lock_path)) unlink(roots$lock_path, recursive = TRUE, force = TRUE), add = TRUE)
  current <- phase18_read_ucl_refresh_current(accepted_root, registry_root)
  if (is.null(current) || is.null(current$accepted) || is.null(current$accepted$bundle))
    phase18_ucl_refresh_abort("provider_exit_required", "Provider exit requires a readable accepted provider bundle", "compliance")
  candidate <- current$accepted; phase18_validate_ucl_source_bundle(candidate); authority <- candidate$authority; bundle <- candidate$bundle
  if (!identical(as.character(authority$authority_type[[1L]]), "provider_acceptance"))
    phase18_ucl_refresh_abort("provider_exit_required", "Provider exit cannot affect non-provider authority", "compliance")
  exact <- c(as.character(exit_review$provider_id[[1L]]) == "football_data_org_v4",
    as.character(exit_review$edition_id[[1L]]) == as.character(bundle$edition_id[[1L]]),
    as.character(exit_review$provider_decision_id[[1L]]) == as.character(authority$provider_decision_id[[1L]]),
    as.character(exit_review$provider_decision_sha256[[1L]]) == as.character(authority$provider_decision_sha256[[1L]]),
    as.character(exit_review$incumbent_bundle_id[[1L]]) == as.character(bundle$bundle_id[[1L]]),
    as.character(exit_review$incumbent_bundle_sha256[[1L]]) == as.character(bundle$bundle_sha256[[1L]]))
  if (!all(exact)) phase18_ucl_refresh_abort("provider_exit_required", "Provider exit review targets a different incumbent", "compliance")
  actual <- phase18_ucl_refresh_inventory(current$accepted_generation_root)
  reviewed <- phase18_ucl_refresh_token_inventory(as.character(exit_review$reviewed_inventory_paths[[1L]]),
    as.character(exit_review$reviewed_inventory_sha256s[[1L]]), current$accepted_generation_root, "Reviewed")
  if (!identical(names(reviewed), actual$paths) || !identical(unname(reviewed), unname(actual$hashes)))
    phase18_ucl_refresh_abort("provider_exit_required", "Provider exit review inventory is not exact", "compliance")
  incumbent <- phase18_ucl_refresh_bundle_identity(candidate)
  batch_id <- phase18_ucl_refresh_batch_id(now_utc, paste0("provider-exit:", exit_review$exit_review_id[[1L]]), current$history)
  disposition <- as.character(exit_review$exit_disposition[[1L]]); accepted_ref <- phase18_ucl_refresh_current_ref(current)
  if (identical(disposition, "retain")) {
    if (!phase18_ucl_refresh_bool(exit_review$retention_permitted[[1L]], "retention_permitted") ||
        !phase18_ucl_refresh_bool(exit_review$display_permitted[[1L]], "display_permitted"))
      phase18_ucl_refresh_abort("provider_exit_required", "Retain requires explicit retention and display permission", "compliance")
    row <- phase18_ucl_refresh_event_row(batch_id, now_utc, as.character(bundle$edition_id[[1L]]),
      "retained_last_known_good", NULL, incumbent, "compliance", "provider_exit_required", "retain", FALSE)
    tx <- phase18_ucl_refresh_append(current, row, NULL, accepted_ref, roots, writer_hooks)
    phase18_ucl_refresh_commit_pointer(roots, tx, accepted_ref, now_utc)
    return(invisible(list(status = "retained_last_known_good", disposition = "retain", automation_enabled = FALSE,
      refresh_batch_id = batch_id, recorded = TRUE)))
  }
  retained <- phase18_ucl_refresh_token_inventory(as.character(exit_review$retained_relative_paths[[1L]]),
    as.character(exit_review$retained_inventory_sha256s[[1L]]), current$accepted_generation_root, "Retained")
  withdrawn <- setNames(actual$hashes[!actual$paths %in% names(retained)], actual$paths[!actual$paths %in% names(retained)])
  inventory_hash <- function(items, domain) {
    if (!length(items)) return(phase18_hash_sequence_v2(list(), domain, character(), character()))
    values <- as.vector(rbind(names(items), unname(items)))
    phase18_hash_sequence_v2(as.list(values), domain, paste0("item_", seq_along(values)), rep("character", length(values)))
  }
  tombstone <- list(schema_version = "phase18-ucl-source-unavailable-v2", hash_encoding_version = phase18_canonical_encoding_v2(),
    edition_id = as.character(bundle$edition_id[[1L]]), provider_id = "football_data_org_v4",
    provider_decision_id = as.character(authority$provider_decision_id[[1L]]),
    provider_decision_sha256 = as.character(authority$provider_decision_sha256[[1L]]),
    incumbent_bundle_id = as.character(bundle$bundle_id[[1L]]), incumbent_bundle_sha256 = as.character(bundle$bundle_sha256[[1L]]),
    exit_review_id = as.character(exit_review$exit_review_id[[1L]]), exit_review_sha256 = as.character(exit_review$exit_review_sha256[[1L]]),
    reason = as.character(exit_review$reason[[1L]]), effective_at_utc = as.character(now_utc),
    withdrawn_inventory_sha256 = inventory_hash(withdrawn, "phase18-ucl-withdrawn-inventory-v2"),
    retained_inventory_sha256 = inventory_hash(retained, "phase18-ucl-retained-inventory-v2"), tombstone_sha256 = "")
  tombstone$tombstone_sha256 <- phase18_ucl_unavailable_tombstone_hash(tombstone)
  new_ref <- phase18_ucl_refresh_stage_tombstone(current$accepted_generation_root, retained, tombstone, roots, paste0(batch_id, "-tombstone"))
  row <- phase18_ucl_refresh_event_row(batch_id, now_utc, as.character(bundle$edition_id[[1L]]), "source_unavailable",
    NULL, incumbent, "compliance", "provider_exit_required", "withdraw", FALSE)
  tx <- phase18_ucl_refresh_append(current, row, NULL, new_ref, roots, writer_hooks)
  phase18_ucl_refresh_run_hook(writer_hooks, "before_provider_exit_swap", "promotion_failure", "compliance")
  phase18_ucl_refresh_commit_pointer(roots, tx, new_ref, now_utc)
  phase18_ucl_refresh_run_hook(writer_hooks, "after_provider_exit_swap", "promotion_failure", "compliance")
  invisible(list(status = "source_unavailable", disposition = "withdraw", automation_enabled = FALSE,
    refresh_batch_id = batch_id, tombstone_path = file.path(new_ref$root, "source_unavailable.json"), recorded = TRUE))
}
