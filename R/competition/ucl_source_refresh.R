#' Fail-closed UCL current-source refresh and provider-exit transactions.
#'
#' Candidate acquisition is deliberately outside this module. This boundary
#' accepts only a complete Phase 18 candidate tree, recomputes its authority,
#' promotes its exact inventory under one lock, and restores the incumbent
#' path-to-bytes map after every technical failure.

phase18_ucl_refresh_reason_codes <- function() c(
  "missing_credential", "owner_review_required", "terms_changed",
  "authority_invalid", "fixture_non_promotable", "http_failure",
  "rate_limited", "null_response", "empty_response", "stale_response",
  "incomplete_pagination", "schema_invalid", "expectation_mismatch",
  "coverage_invalid", "identity_invalid", "provenance_collision",
  "secret_exposure", "concurrent_refresh", "interrupted",
  "provider_exit_required", "promotion_failure", "read_back_failure",
  "history_write_failure", "sidecar_write_failure", "unknown_failure"
)

phase18_ucl_refresh_abort <- function(reason_code, message, failure_phase = "preflight") {
  if (!reason_code %in% phase18_ucl_refresh_reason_codes()) reason_code <- "unknown_failure"
  condition <- structure(
    list(
      message = as.character(message), call = NULL,
      reason_code = reason_code, failure_phase = failure_phase
    ),
    class = c(paste0("phase18_refresh_", reason_code), "phase18_ucl_refresh_error", "error", "condition")
  )
  stop(condition)
}

#' Reduce errors to stable, non-secret refresh reason codes.
phase18_classify_ucl_refresh_failure <- function(error) {
  if (inherits(error, "phase18_ucl_refresh_error")) {
    return(list(
      reason_code = as.character(error$reason_code),
      failure_phase = as.character(error$failure_phase)
    ))
  }
  classes <- class(error)
  mapped <- c(
    blocked_empty_resource = "empty_response",
    blocked_incomplete_graph = "incomplete_pagination",
    blocked_schema = "schema_invalid",
    blocked_expectation = "expectation_mismatch",
    blocked_foreign_key = "identity_invalid",
    blocked_duplicate_key = "identity_invalid",
    blocked_authority = "authority_invalid",
    blocked_provenance_collision = "provenance_collision",
    blocked_candidate_exists = "provenance_collision",
    blocked_raw_hash = "schema_invalid",
    blocked_row_hash = "schema_invalid",
    blocked_canonical_hash = "schema_invalid",
    blocked_bundle_hash = "schema_invalid",
    blocked_manifest_hash = "schema_invalid",
    blocked_inventory = "incomplete_pagination",
    blocked_symlink = "schema_invalid",
    blocked_unsafe_path = "schema_invalid"
  )
  hit <- intersect(names(mapped), classes)
  if (length(hit)) return(list(reason_code = unname(mapped[[hit[[1L]]]]), failure_phase = "candidate_validation"))
  message <- tolower(conditionMessage(error))
  patterns <- list(
    missing_credential = "credential|token.*missing",
    rate_limited = "rate.?limit|http 429",
    http_failure = "http|server error|network",
    null_response = "null response|null payload",
    stale_response = "stale|freshness",
    incomplete_pagination = "pagination|incomplete",
    secret_exposure = "secret|credential exposure",
    interrupted = "interrupt|terminated",
    concurrent_refresh = "lock collision|concurrent",
    read_back_failure = "read.?back",
    promotion_failure = "promotion|promote",
    history_write_failure = "history[_ ]writer|history write",
    sidecar_write_failure = "sidecar[_ ]writer|sidecar write"
  )
  for (reason in names(patterns)) {
    if (grepl(patterns[[reason]], message, perl = TRUE)) {
      return(list(reason_code = reason, failure_phase = "technical"))
    }
  }
  list(reason_code = "unknown_failure", failure_phase = "technical")
}

phase18_ucl_refresh_scalar <- function(value, field, allow_empty = FALSE) {
  if (is.null(value) || length(value) != 1L || is.na(value[[1L]])) {
    phase18_ucl_refresh_abort("schema_invalid", paste0(field, " must be one value"))
  }
  value <- as.character(value[[1L]])
  if (!allow_empty && !nzchar(value)) {
    phase18_ucl_refresh_abort("schema_invalid", paste0(field, " must not be empty"))
  }
  value
}

phase18_ucl_refresh_bool <- function(value, field) {
  if (is.logical(value) && length(value) == 1L && !is.na(value)) return(value)
  token <- tolower(phase18_ucl_refresh_scalar(value, field))
  if (!token %in% c("true", "false")) {
    phase18_ucl_refresh_abort("schema_invalid", paste0(field, " must be TRUE or FALSE"))
  }
  identical(token, "true")
}

phase18_ucl_refresh_safe_id <- function(value, field) {
  value <- phase18_ucl_refresh_scalar(value, field)
  if (!grepl("^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$", value)) {
    phase18_ucl_refresh_abort("schema_invalid", paste0(field, " is not a safe identifier"))
  }
  value
}

phase18_ucl_refresh_safe_relative_path <- function(path) {
  path <- gsub("\\\\", "/", phase18_ucl_refresh_scalar(path, "relative_path"))
  if (grepl("^/|^[A-Za-z]:|(^|/)\\.\\.?(/|$)|//", path)) {
    phase18_ucl_refresh_abort("schema_invalid", "Refresh inventory contains an unsafe path")
  }
  path
}

phase18_ucl_refresh_roots <- function(accepted_root, registry_root) {
  dir.create(accepted_root, recursive = TRUE, showWarnings = FALSE)
  dir.create(registry_root, recursive = TRUE, showWarnings = FALSE)
  accepted_root <- normalizePath(accepted_root, winslash = "/", mustWork = TRUE)
  registry_root <- normalizePath(registry_root, winslash = "/", mustWork = TRUE)
  if (!identical(dirname(accepted_root), dirname(registry_root)) ||
      identical(accepted_root, registry_root) || phase18_ucl_is_symlink(accepted_root) ||
      phase18_ucl_is_symlink(registry_root)) {
    phase18_ucl_refresh_abort(
      "schema_invalid",
      "Refresh accepted and registry roots must be non-symlinked siblings"
    )
  }
  list(
    accepted_root = accepted_root, registry_root = registry_root,
    common_root = dirname(accepted_root),
    history_path = file.path(registry_root, "ucl_source_refreshes.csv"),
    sidecar_path = file.path(registry_root, "ucl_source_blocked_refresh.json")
  )
}

phase18_ucl_refresh_tree_snapshot <- function(root) {
  root <- normalizePath(root, winslash = "/", mustWork = FALSE)
  if (!dir.exists(root)) return(list(exists = FALSE, files = setNames(list(), character())))
  files <- list.files(root, recursive = TRUE, full.names = TRUE, all.files = TRUE, no.. = TRUE)
  files <- files[!file.info(files)$isdir]
  if (any(vapply(c(root, files), phase18_ucl_is_symlink, logical(1)))) {
    phase18_ucl_refresh_abort("schema_invalid", "Refresh snapshots cannot contain symlinks")
  }
  relative <- if (length(files)) substring(files, nchar(root) + 2L) else character()
  bytes <- lapply(files, function(path) readBin(path, "raw", n = file.info(path)$size))
  names(bytes) <- relative
  list(exists = TRUE, files = bytes)
}

phase18_ucl_refresh_restore_tree <- function(root, snapshot) {
  if (file.exists(root) || dir.exists(root)) unlink(root, recursive = TRUE, force = TRUE)
  if (!isTRUE(snapshot$exists)) return(invisible(root))
  dir.create(root, recursive = TRUE, showWarnings = FALSE)
  for (relative in names(snapshot$files)) {
    target <- file.path(root, phase18_ucl_refresh_safe_relative_path(relative))
    dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
    writeBin(snapshot$files[[relative]], target)
  }
  invisible(root)
}

phase18_ucl_refresh_snapshot_file <- function(path) {
  if (!file.exists(path) || dir.exists(path)) return(list(exists = FALSE, bytes = raw(0)))
  list(exists = TRUE, bytes = readBin(path, "raw", n = file.info(path)$size))
}

phase18_ucl_refresh_restore_file <- function(path, snapshot) {
  if (file.exists(path) || dir.exists(path)) unlink(path, recursive = TRUE, force = TRUE)
  if (isTRUE(snapshot$exists)) {
    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
    writeBin(snapshot$bytes, path)
  }
  invisible(path)
}

phase18_ucl_refresh_copy_tree <- function(source, target) {
  source <- normalizePath(source, winslash = "/", mustWork = TRUE)
  phase18_ucl_assert_no_symlink(source, source)
  files <- sort(list.files(source, recursive = TRUE, full.names = TRUE, all.files = TRUE, no.. = TRUE))
  files <- files[!file.info(files)$isdir]
  relative <- substring(files, nchar(source) + 2L)
  dir.create(target, recursive = TRUE, showWarnings = FALSE)
  for (index in seq_along(files)) {
    phase18_ucl_assert_no_symlink(files[[index]], source)
    destination <- file.path(target, phase18_ucl_refresh_safe_relative_path(relative[[index]]))
    dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
    if (!file.copy(files[[index]], destination, overwrite = FALSE, copy.mode = FALSE)) {
      phase18_ucl_refresh_abort("promotion_failure", "Could not copy the exact candidate inventory", "staging")
    }
  }
  relative
}

phase18_ucl_refresh_run_hook <- function(hooks, name, reason_code, failure_phase, ...) {
  hook <- hooks[[name]]
  if (is.null(hook)) return(invisible(NULL))
  if (!is.function(hook)) {
    phase18_ucl_refresh_abort("schema_invalid", paste0("writer_hooks$", name, " must be a function"))
  }
  tryCatch(
    hook(...),
    error = function(error) phase18_ucl_refresh_abort(
      reason_code, paste0("Injected ", name, " failure"), failure_phase
    )
  )
  invisible(NULL)
}

phase18_ucl_refresh_history_schema <- function() c(
  "schema_version", "refresh_batch_id", "event_at_utc", "edition_id", "status",
  "candidate_bundle_id", "candidate_bundle_sha256", "incumbent_status",
  "incumbent_bundle_id", "incumbent_bundle_sha256", "authority_type",
  "authority_id", "authority_sha256", "acceptance_decision_id",
  "acceptance_decision_sha256", "failure_phase", "reason_code", "disposition",
  "automation_enabled", "blocked_record_sha256", "row_sha256"
)

phase18_ucl_refresh_empty_history <- function() {
  out <- as.data.frame(setNames(replicate(
    length(phase18_ucl_refresh_history_schema()), character(), simplify = FALSE
  ), phase18_ucl_refresh_history_schema()), stringsAsFactors = FALSE, check.names = FALSE)
  out$automation_enabled <- logical()
  out
}

phase18_ucl_refresh_read_history <- function(path) {
  if (!file.exists(path)) return(phase18_ucl_refresh_empty_history())
  history <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = NULL)
  for (field in setdiff(names(history), "automation_enabled")) {
    history[[field]] <- as.character(history[[field]])
    history[[field]][is.na(history[[field]])] <- ""
  }
  history
}

phase18_ucl_refresh_row_hash <- function(row) {
  base <- row
  base$blocked_record_sha256 <- ""
  base$row_sha256 <- ""
  phase18_ucl_row_hash(base)[[1L]]
}

phase18_ucl_refresh_sidecar_hash <- function(sidecar) {
  body <- sidecar
  body$blocked_record_sha256 <- ""
  phase18_ucl_hash(jsonlite::toJSON(body[sort(names(body))], auto_unbox = TRUE, null = "null", digits = 17))
}

phase18_ucl_refresh_bundle_identity <- function(root) {
  if (!dir.exists(root)) return(list(status = "no_incumbent", id = "", sha256 = ""))
  tombstone <- file.path(root, "source_unavailable.json")
  if (file.exists(tombstone)) {
    value <- jsonlite::fromJSON(tombstone, simplifyVector = TRUE)
    return(list(
      status = "unavailable_tombstone", id = as.character(value$exit_review_id %||% ""),
      sha256 = as.character(value$tombstone_sha256 %||% "")
    ))
  }
  value <- tryCatch(phase18_read_ucl_candidate(root), error = function(error) NULL)
  if (is.null(value)) return(list(status = "incumbent_unreadable", id = "", sha256 = ""))
  list(
    status = "last_known_good", id = as.character(value$bundle$bundle_id[[1L]]),
    sha256 = as.character(value$bundle$bundle_sha256[[1L]])
  )
}

phase18_ucl_refresh_batch_id <- function(now_utc, candidate_root, history) {
  token <- substr(phase18_ucl_hash(paste(now_utc, candidate_root, nrow(history) + 1L, Sys.getpid(), sep = "|")), 1L, 16L)
  phase18_ucl_refresh_safe_id(paste0("ucl-refresh-", gsub("[^0-9]", "", now_utc), "-", token), "refresh_batch_id")
}

phase18_ucl_refresh_event_row <- function(
    refresh_batch_id, now_utc, edition_id, status, candidate, incumbent,
    failure_phase, reason_code, disposition = "", automation_enabled = FALSE) {
  candidate_bundle <- if (is.null(candidate)) NULL else candidate$bundle
  authority <- if (is.null(candidate)) NULL else candidate$authority
  authority_type <- if (is.null(authority)) "" else as.character(authority$authority_type[[1L]])
  decision_id <- if (identical(authority_type, "provider_acceptance")) as.character(authority$provider_decision_id[[1L]]) else ""
  decision_hash <- if (identical(authority_type, "provider_acceptance")) as.character(authority$provider_decision_sha256[[1L]]) else ""
  row <- data.frame(
    schema_version = "phase18-ucl-source-refresh-v1",
    refresh_batch_id = refresh_batch_id, event_at_utc = now_utc,
    edition_id = edition_id, status = status,
    candidate_bundle_id = if (is.null(candidate_bundle)) "" else as.character(candidate_bundle$bundle_id[[1L]]),
    candidate_bundle_sha256 = if (is.null(candidate_bundle)) "" else as.character(candidate_bundle$bundle_sha256[[1L]]),
    incumbent_status = incumbent$status, incumbent_bundle_id = incumbent$id,
    incumbent_bundle_sha256 = incumbent$sha256, authority_type = authority_type,
    authority_id = if (is.null(authority)) "" else as.character(authority$authority_id[[1L]]),
    authority_sha256 = if (is.null(authority)) "" else as.character(authority$authority_sha256[[1L]]),
    acceptance_decision_id = decision_id, acceptance_decision_sha256 = decision_hash,
    failure_phase = failure_phase, reason_code = reason_code, disposition = disposition,
    automation_enabled = isTRUE(automation_enabled), blocked_record_sha256 = "",
    row_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE
  )
  row$row_sha256 <- phase18_ucl_refresh_row_hash(row)
  row
}

phase18_ucl_refresh_write_csv_atomic <- function(data, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  stage <- tempfile(paste0(".", basename(path), "-"), tmpdir = dirname(path))
  on.exit(if (file.exists(stage)) unlink(stage, force = TRUE), add = TRUE)
  utils::write.csv(data, stage, row.names = FALSE, na = "", quote = TRUE)
  if (file.exists(path)) unlink(path, force = TRUE)
  if (!file.rename(stage, path)) phase18_ucl_refresh_abort("history_write_failure", "History write failed", "history")
  invisible(path)
}

phase18_ucl_refresh_write_json_atomic <- function(value, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  stage <- tempfile(paste0(".", basename(path), "-"), tmpdir = dirname(path))
  on.exit(if (file.exists(stage)) unlink(stage, force = TRUE), add = TRUE)
  jsonlite::write_json(value, stage, auto_unbox = TRUE, pretty = TRUE, null = "null", digits = 17)
  if (file.exists(path)) unlink(path, force = TRUE)
  if (!file.rename(stage, path)) phase18_ucl_refresh_abort("sidecar_write_failure", "Sidecar write failed", "sidecar")
  invisible(path)
}

phase18_ucl_refresh_publish_event <- function(
    roots, row, hooks = list(), blocked = FALSE, preserve_existing_sidecar = FALSE) {
  history_snapshot <- phase18_ucl_refresh_snapshot_file(roots$history_path)
  sidecar_snapshot <- phase18_ucl_refresh_snapshot_file(roots$sidecar_path)
  history <- phase18_ucl_refresh_read_history(roots$history_path)
  if (row$refresh_batch_id[[1L]] %in% as.character(history$refresh_batch_id)) {
    phase18_ucl_refresh_abort("provenance_collision", "Refresh batch ID already exists", "history")
  }
  sidecar <- NULL
  if (isTRUE(blocked)) {
    sidecar <- as.list(row[1L, setdiff(names(row), "blocked_record_sha256"), drop = FALSE])
    sidecar$schema_version <- "phase18-ucl-blocked-refresh-v1"
    sidecar$history_row_sha256 <- row$row_sha256[[1L]]
    sidecar$blocked_record_sha256 <- ""
    sidecar$blocked_record_sha256 <- phase18_ucl_refresh_sidecar_hash(sidecar)
    row$blocked_record_sha256 <- sidecar$blocked_record_sha256
  }
  next_history <- rbind(history, row)
  tryCatch({
    phase18_ucl_refresh_run_hook(hooks, "history_writer", "history_write_failure", "history", next_history, roots$history_path)
    phase18_ucl_refresh_write_csv_atomic(next_history, roots$history_path)
    if (isTRUE(blocked)) {
      phase18_ucl_refresh_run_hook(hooks, "sidecar_writer", "sidecar_write_failure", "sidecar", sidecar, roots$sidecar_path)
      phase18_ucl_refresh_write_json_atomic(sidecar, roots$sidecar_path)
    } else if (!isTRUE(preserve_existing_sidecar) && file.exists(roots$sidecar_path)) {
      unlink(roots$sidecar_path, force = TRUE)
    }
  }, error = function(error) {
    phase18_ucl_refresh_restore_file(roots$history_path, history_snapshot)
    phase18_ucl_refresh_restore_file(roots$sidecar_path, sidecar_snapshot)
    stop(error)
  })
  invisible(list(row = row, sidecar = sidecar))
}

#' Validate append-only refresh history and the current blocked sidecar.
phase18_validate_ucl_refresh_state <- function(history, blocked_sidecar = NULL, accepted_root) {
  if (!is.data.frame(history) || !identical(names(history), phase18_ucl_refresh_history_schema())) {
    phase18_ucl_refresh_abort("schema_invalid", "Refresh history schema is invalid", "history")
  }
  if (!nrow(history)) return(invisible(history))
  if (any(as.character(history$schema_version) != "phase18-ucl-source-refresh-v1") ||
      anyDuplicated(as.character(history$refresh_batch_id))) {
    phase18_ucl_refresh_abort("provenance_collision", "Refresh history is not append-only", "history")
  }
  expected <- vapply(seq_len(nrow(history)), function(index) {
    phase18_ucl_refresh_row_hash(history[index, , drop = FALSE])
  }, character(1))
  if (!identical(tolower(as.character(history$row_sha256)), expected)) {
    phase18_ucl_refresh_abort("schema_invalid", "Refresh history row hash mismatch", "history")
  }
  last <- history[nrow(history), , drop = FALSE]
  if (identical(as.character(last$status[[1L]]), "blocked")) {
    if (is.null(blocked_sidecar)) {
      phase18_ucl_refresh_abort("schema_invalid", "Blocked refresh requires its sidecar", "sidecar")
    }
    if (is.character(blocked_sidecar) && length(blocked_sidecar) == 1L) {
      blocked_sidecar <- jsonlite::fromJSON(blocked_sidecar, simplifyVector = TRUE)
    }
    shared <- setdiff(
      intersect(names(blocked_sidecar), names(last)),
      c("schema_version", "blocked_record_sha256", "row_sha256")
    )
    shared_equal <- length(shared) > 0L && all(vapply(shared, function(field) {
      identical(
        phase18_canonical_scalar(blocked_sidecar[[field]]),
        phase18_canonical_scalar(last[[field]][[1L]])
      )
    }, logical(1)))
    if (!is.list(blocked_sidecar) || !shared_equal ||
        !identical(as.character(blocked_sidecar$refresh_batch_id), as.character(last$refresh_batch_id[[1L]])) ||
        !identical(as.character(blocked_sidecar$history_row_sha256), as.character(last$row_sha256[[1L]])) ||
        !identical(as.character(blocked_sidecar$blocked_record_sha256), as.character(last$blocked_record_sha256[[1L]])) ||
        !identical(phase18_ucl_refresh_sidecar_hash(blocked_sidecar), as.character(blocked_sidecar$blocked_record_sha256))) {
      phase18_ucl_refresh_abort("schema_invalid", "Blocked sidecar and history row disagree", "sidecar")
    }
    accepted_root <- normalizePath(accepted_root, winslash = "/", mustWork = FALSE)
    accepted_target <- file.path(accepted_root, as.character(last$edition_id[[1L]]))
    incumbent <- phase18_ucl_refresh_bundle_identity(accepted_target)
    expected_status <- as.character(last$incumbent_status[[1L]])
    if (!identical(incumbent$status, expected_status) ||
        !identical(incumbent$id, as.character(last$incumbent_bundle_id[[1L]])) ||
        !identical(incumbent$sha256, as.character(last$incumbent_bundle_sha256[[1L]]))) {
      phase18_ucl_refresh_abort("schema_invalid", "Blocked history does not match the retained incumbent", "read_back")
    }
  }
  invisible(history)
}

phase18_ucl_refresh_infer_edition <- function(candidate_root, accepted_root) {
  candidate <- tryCatch(phase18_read_ucl_candidate(candidate_root), error = function(error) NULL)
  if (!is.null(candidate)) return(as.character(candidate$bundle$edition_id[[1L]]))
  entries <- if (dir.exists(accepted_root)) list.dirs(accepted_root, recursive = FALSE, full.names = FALSE) else character()
  entries <- entries[grepl("^ucl_", entries)]
  if (length(entries) == 1L) entries[[1L]] else "ucl_2026_27"
}

phase18_ucl_refresh_validate_provider_authority <- function(candidate, acceptance_root) {
  authority <- candidate$authority
  type <- as.character(authority$authority_type[[1L]])
  if (identical(type, "fixture_contract")) {
    phase18_ucl_refresh_abort("fixture_non_promotable", "Fixture authority is never promotable", "authority")
  }
  if (!isTRUE(phase18_ucl_bool(authority$promotion_eligible[[1L]], "promotion_eligible"))) {
    phase18_ucl_refresh_abort("authority_invalid", "Candidate authority is not promotion eligible", "authority")
  }
  if (!identical(type, "provider_acceptance")) return(invisible(TRUE))
  manifest_path <- file.path(
    acceptance_root, "football_data_org_v4", as.character(candidate$bundle$edition_id[[1L]]),
    "acceptance_manifest.csv"
  )
  if (!file.exists(manifest_path)) {
    phase18_ucl_refresh_abort("owner_review_required", "Accepted provider decision is unavailable", "authority")
  }
  manifest <- phase18_ucl_read_csv(manifest_path)
  if (nrow(manifest) != 1L ||
      !identical(as.character(manifest$decision_id[[1L]]), as.character(authority$provider_decision_id[[1L]])) ||
      !identical(as.character(manifest$row_sha256[[1L]]), as.character(authority$provider_decision_sha256[[1L]]))) {
    phase18_ucl_refresh_abort("authority_invalid", "Provider authority is stale", "authority")
  }
  invisible(TRUE)
}

#' Promote one fully validating candidate or record one typed blocked attempt.
phase18_refresh_ucl_source <- function(
    candidate_root,
    accepted_root = "data/competition/accepted",
    registry_root = "data/competition/registries",
    acceptance_root = "data/competition/provider_acceptance",
    writer_hooks = list(),
    now_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")) {
  if (!is.list(writer_hooks)) phase18_ucl_refresh_abort("schema_invalid", "writer_hooks must be a list")
  roots <- phase18_ucl_refresh_roots(accepted_root, registry_root)
  acceptance_root <- normalizePath(acceptance_root, winslash = "/", mustWork = FALSE)
  edition_id <- phase18_ucl_refresh_infer_edition(candidate_root, roots$accepted_root)
  target <- file.path(roots$accepted_root, edition_id)
  incumbent <- phase18_ucl_refresh_bundle_identity(target)
  history <- phase18_ucl_refresh_read_history(roots$history_path)
  refresh_batch_id <- phase18_ucl_refresh_batch_id(now_utc, candidate_root, history)
  lock_path <- file.path(roots$common_root, ".phase18-ucl-refresh.lock")
  if (file.exists(lock_path) || dir.exists(lock_path) ||
      !dir.create(lock_path, recursive = FALSE, showWarnings = FALSE)) {
    row <- phase18_ucl_refresh_event_row(
      refresh_batch_id, now_utc, edition_id, "blocked", NULL, incumbent,
      "lock", "concurrent_refresh"
    )
    phase18_ucl_refresh_publish_event(roots, row, blocked = TRUE)
    return(invisible(list(
      status = "blocked", reason_code = "concurrent_refresh",
      failure_phase = "lock", refresh_batch_id = refresh_batch_id,
      incumbent_status = incumbent$status
    )))
  }
  stage_root <- tempfile(".phase18-ucl-refresh-stage-", tmpdir = roots$common_root)
  backup_root <- tempfile(".phase18-ucl-refresh-backup-", tmpdir = roots$common_root)
  accepted_snapshot <- phase18_ucl_refresh_tree_snapshot(target)
  candidate <- NULL
  promotion_started <- FALSE
  cleanup <- function() {
    for (path in c(stage_root, backup_root, lock_path)) {
      if (file.exists(path) || dir.exists(path)) unlink(path, recursive = TRUE, force = TRUE)
    }
  }
  on.exit(cleanup(), add = TRUE)

  failure <- NULL
  result <- tryCatch({
    candidate <- phase18_read_ucl_candidate(candidate_root)
    edition_id <- as.character(candidate$bundle$edition_id[[1L]])
    target <- file.path(roots$accepted_root, edition_id)
    incumbent <- phase18_ucl_refresh_bundle_identity(target)
    accepted_snapshot <- phase18_ucl_refresh_tree_snapshot(target)
    phase18_validate_ucl_source_bundle(candidate)
    phase18_ucl_refresh_validate_provider_authority(candidate, acceptance_root)
    dir.create(stage_root, recursive = FALSE, showWarnings = FALSE)
    inventory <- phase18_ucl_refresh_copy_tree(candidate_root, stage_root)
    staged <- phase18_read_ucl_candidate(stage_root)
    phase18_validate_ucl_source_bundle(staged)
    phase18_ucl_refresh_run_hook(writer_hooks, "before_promotion", "promotion_failure", "promotion")
    dir.create(backup_root, recursive = FALSE, showWarnings = FALSE)
    if (dir.exists(target) && !file.rename(target, file.path(backup_root, edition_id))) {
      phase18_ucl_refresh_abort("promotion_failure", "Could not backup incumbent", "promotion")
    }
    dir.create(target, recursive = TRUE, showWarnings = FALSE)
    promotion_started <- TRUE
    for (index in seq_along(inventory)) {
      relative <- inventory[[index]]
      source <- file.path(stage_root, relative)
      destination <- file.path(target, relative)
      dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
      if (!file.rename(source, destination)) {
        phase18_ucl_refresh_abort("promotion_failure", "Could not promote candidate inventory", "promotion")
      }
      phase18_ucl_refresh_run_hook(
        writer_hooks, "after_promotion", "promotion_failure", "promotion",
        index, relative, refresh_batch_id
      )
    }
    phase18_ucl_refresh_run_hook(writer_hooks, "interrupt", "interrupted", "promotion")
    phase18_ucl_refresh_run_hook(writer_hooks, "before_readback", "read_back_failure", "read_back")
    installed <- phase18_read_ucl_candidate(target)
    phase18_validate_ucl_source_bundle(installed)
    if (!identical(
      as.character(installed$bundle$manifest_self_sha256[[1L]]),
      as.character(candidate$bundle$manifest_self_sha256[[1L]])
    )) {
      phase18_ucl_refresh_abort("read_back_failure", "Durable read-back differs from candidate", "read_back")
    }
    row <- phase18_ucl_refresh_event_row(
      refresh_batch_id, now_utc, edition_id, "accepted", candidate, incumbent,
      "", "accepted", disposition = "promoted",
      automation_enabled = isTRUE(candidate$authority$provider_automation_enabled[[1L]])
    )
    phase18_ucl_refresh_publish_event(roots, row, hooks = writer_hooks, blocked = FALSE)
    list(
      status = "accepted", reason_code = "accepted", refresh_batch_id = refresh_batch_id,
      candidate_bundle_id = as.character(candidate$bundle$bundle_id[[1L]]),
      incumbent_status = incumbent$status
    )
  }, error = function(error) {
    failure <<- error
    NULL
  })

  if (!is.null(failure)) {
    if (isTRUE(promotion_started) || !identical(
      phase18_ucl_refresh_tree_snapshot(target), accepted_snapshot
    )) {
      phase18_ucl_refresh_restore_tree(target, accepted_snapshot)
    }
    classified <- phase18_classify_ucl_refresh_failure(failure)
    row <- phase18_ucl_refresh_event_row(
      refresh_batch_id, now_utc, edition_id, "blocked", candidate, incumbent,
      classified$failure_phase, classified$reason_code
    )
    recorded <- TRUE
    record_error <- tryCatch({
      # A failed evidence writer cannot be reused to write its own failure record.
      evidence_hooks <- writer_hooks
      if (classified$reason_code %in% c("history_write_failure", "sidecar_write_failure")) {
        evidence_hooks$history_writer <- NULL
        evidence_hooks$sidecar_writer <- NULL
      }
      phase18_ucl_refresh_publish_event(roots, row, hooks = evidence_hooks, blocked = TRUE)
      NULL
    }, error = function(error) error)
    if (!is.null(record_error)) {
      metadata_failure <- phase18_classify_ucl_refresh_failure(record_error)
      fallback_row <- phase18_ucl_refresh_event_row(
        refresh_batch_id, now_utc, edition_id, "blocked", candidate, incumbent,
        metadata_failure$failure_phase, metadata_failure$reason_code
      )
      fallback_error <- tryCatch({
        phase18_ucl_refresh_publish_event(roots, fallback_row, hooks = list(), blocked = TRUE)
        NULL
      }, error = function(error) error)
      recorded <- is.null(fallback_error)
      if (recorded) classified <- metadata_failure
    }
    cleanup()
    return(invisible(list(
      status = "blocked", reason_code = classified$reason_code,
      failure_phase = classified$failure_phase, refresh_batch_id = refresh_batch_id,
      incumbent_status = incumbent$status, recorded = recorded
    )))
  }
  cleanup()
  invisible(result)
}

phase18_ucl_exit_review_hash <- function(review) {
  body <- review
  body$exit_review_sha256 <- ""
  body$row_sha256 <- ""
  phase18_ucl_canonical_hash(body, key = "exit_review_id")
}

phase18_hash_ucl_provider_exit_review <- function(review) {
  if (!is.data.frame(review) || nrow(review) != 1L) {
    phase18_ucl_refresh_abort("owner_review_required", "Provider exit requires one reviewed row", "compliance")
  }
  review$exit_review_sha256 <- phase18_ucl_exit_review_hash(review)
  review$row_sha256 <- phase18_ucl_row_hash(review)
  review
}

phase18_validate_ucl_provider_exit_review <- function(review) {
  required <- c(
    "schema_version", "exit_review_id", "provider_id", "edition_id", "decision",
    "exit_disposition", "retention_permitted", "display_permitted", "terms_sha256",
    "provider_decision_id", "provider_decision_sha256", "reviewer", "reviewed_at_utc",
    "reason", "retained_relative_paths", "retained_inventory_sha256s",
    "exit_review_sha256", "row_sha256"
  )
  if (!is.data.frame(review) || nrow(review) != 1L || length(setdiff(required, names(review)))) {
    phase18_ucl_refresh_abort("owner_review_required", "Provider exit review is incomplete", "compliance")
  }
  if (!identical(as.character(review$schema_version[[1L]]), "phase18-ucl-provider-exit-review-v1") ||
      !identical(as.character(review$decision[[1L]]), "reviewed") ||
      !as.character(review$exit_disposition[[1L]]) %in% c("retain", "withdraw") ||
      !identical(as.character(review$exit_review_sha256[[1L]]), phase18_ucl_exit_review_hash(review)) ||
      !identical(as.character(review$row_sha256[[1L]]), phase18_ucl_row_hash(review)[[1L]])) {
    phase18_ucl_refresh_abort("owner_review_required", "Provider exit review is not current and hash-bound", "compliance")
  }
  phase18_ucl_require_hash(review$terms_sha256, "terms_sha256")
  phase18_ucl_require_hash(review$provider_decision_sha256, "provider_decision_sha256")
  invisible(review)
}

phase18_ucl_exit_retained_inventory <- function(review, accepted_target) {
  paths_token <- as.character(review$retained_relative_paths[[1L]])
  hashes_token <- as.character(review$retained_inventory_sha256s[[1L]])
  if (!nzchar(paths_token) && !nzchar(hashes_token)) return(setNames(character(), character()))
  paths <- strsplit(paths_token, "|", fixed = TRUE)[[1L]]
  hashes <- strsplit(hashes_token, "|", fixed = TRUE)[[1L]]
  if (length(paths) != length(hashes)) {
    phase18_ucl_refresh_abort("owner_review_required", "Retained inventory paths and hashes disagree", "compliance")
  }
  paths <- vapply(paths, phase18_ucl_refresh_safe_relative_path, character(1))
  hashes <- vapply(hashes, phase18_ucl_require_hash, character(1), field = "retained inventory hash")
  for (index in seq_along(paths)) {
    path <- file.path(accepted_target, paths[[index]])
    if (!file.exists(path) || dir.exists(path) || phase18_ucl_is_symlink(path) ||
        !identical(phase18_ucl_hash(readBin(path, "raw", n = file.info(path)$size)), hashes[[index]])) {
      phase18_ucl_refresh_abort("owner_review_required", "Retained lawful inventory is missing or changed", "compliance")
    }
  }
  setNames(hashes, paths)
}

phase18_ucl_unavailable_tombstone_hash <- function(value) {
  body <- value
  body$tombstone_sha256 <- ""
  phase18_ucl_hash(jsonlite::toJSON(body[sort(names(body))], auto_unbox = TRUE, null = "null", digits = 17))
}

phase18_validate_ucl_unavailable_tombstone <- function(path) {
  if (!file.exists(path) || dir.exists(path)) {
    phase18_ucl_refresh_abort("schema_invalid", "UCL unavailable tombstone is missing", "compliance")
  }
  value <- jsonlite::fromJSON(path, simplifyVector = TRUE)
  required <- c(
    "schema_version", "edition_id", "provider_id", "provider_decision_id",
    "provider_decision_sha256", "exit_review_id", "exit_review_sha256", "reason",
    "effective_at_utc", "withdrawn_inventory_sha256", "retained_inventory_sha256",
    "tombstone_sha256"
  )
  if (length(setdiff(required, names(value))) ||
      !identical(as.character(value$schema_version), "phase18-ucl-source-unavailable-v1") ||
      !identical(as.character(value$tombstone_sha256), phase18_ucl_unavailable_tombstone_hash(value))) {
    phase18_ucl_refresh_abort("schema_invalid", "UCL unavailable tombstone hash is invalid", "compliance")
  }
  invisible(value)
}

#' Apply a reviewed retain or withdraw compliance transaction before transport.
phase18_apply_provider_exit <- function(
    exit_review,
    accepted_root = "data/competition/accepted",
    registry_root = "data/competition/registries",
    writer_hooks = list(),
    now_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")) {
  phase18_validate_ucl_provider_exit_review(exit_review)
  roots <- phase18_ucl_refresh_roots(accepted_root, registry_root)
  edition_id <- phase18_ucl_refresh_safe_id(exit_review$edition_id[[1L]], "edition_id")
  target <- file.path(roots$accepted_root, edition_id)
  if (!dir.exists(target)) {
    phase18_ucl_refresh_abort("provider_exit_required", "Provider exit has no accepted tree", "compliance")
  }
  incumbent <- phase18_ucl_refresh_bundle_identity(target)
  history <- phase18_ucl_refresh_read_history(roots$history_path)
  batch_id <- phase18_ucl_refresh_batch_id(now_utc, paste0("provider-exit:", exit_review$exit_review_id[[1L]]), history)
  disposition <- as.character(exit_review$exit_disposition[[1L]])
  lock_path <- file.path(roots$common_root, ".phase18-ucl-refresh.lock")
  if (file.exists(lock_path) || dir.exists(lock_path) ||
      !dir.create(lock_path, recursive = FALSE, showWarnings = FALSE)) {
    phase18_ucl_refresh_abort("concurrent_refresh", "Provider-exit lock collision", "compliance")
  }
  on.exit(if (dir.exists(lock_path)) unlink(lock_path, recursive = TRUE, force = TRUE), add = TRUE)
  snapshot <- phase18_ucl_refresh_tree_snapshot(target)

  if (identical(disposition, "retain")) {
    if (!phase18_ucl_refresh_bool(exit_review$retention_permitted[[1L]], "retention_permitted") ||
        !phase18_ucl_refresh_bool(exit_review$display_permitted[[1L]], "display_permitted")) {
      phase18_ucl_refresh_abort("provider_exit_required", "Retain requires explicit retention and display permission", "compliance")
    }
    row <- phase18_ucl_refresh_event_row(
      batch_id, now_utc, edition_id, "retained_last_known_good", NULL, incumbent,
      "compliance", "provider_exit_required", "retain", FALSE
    )
    phase18_ucl_refresh_publish_event(roots, row, hooks = writer_hooks, blocked = FALSE, preserve_existing_sidecar = TRUE)
    return(invisible(list(
      status = "retained_last_known_good", disposition = "retain",
      automation_enabled = FALSE, refresh_batch_id = batch_id
    )))
  }

  retained <- phase18_ucl_exit_retained_inventory(exit_review, target)
  all_files <- sort(list.files(target, recursive = TRUE, full.names = TRUE, all.files = TRUE, no.. = TRUE))
  all_files <- all_files[!file.info(all_files)$isdir]
  all_relative <- substring(all_files, nchar(normalizePath(target, winslash = "/", mustWork = TRUE)) + 2L)
  all_hashes <- vapply(all_files, function(path) phase18_ucl_hash(readBin(path, "raw", n = file.info(path)$size)), character(1))
  withdrawn <- setNames(all_hashes[!all_relative %in% names(retained)], all_relative[!all_relative %in% names(retained)])
  stage <- tempfile(".phase18-ucl-exit-stage-", tmpdir = roots$common_root)
  backup <- tempfile(".phase18-ucl-exit-backup-", tmpdir = roots$common_root)
  dir.create(stage, recursive = FALSE, showWarnings = FALSE)
  on.exit({
    if (dir.exists(stage)) unlink(stage, recursive = TRUE, force = TRUE)
    if (dir.exists(backup)) unlink(backup, recursive = TRUE, force = TRUE)
  }, add = TRUE)
  for (relative in names(retained)) {
    destination <- file.path(stage, relative)
    dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
    if (!file.copy(file.path(target, relative), destination, overwrite = FALSE, copy.mode = FALSE)) {
      phase18_ucl_refresh_abort("promotion_failure", "Could not stage retained lawful inventory", "compliance")
    }
  }
  tombstone <- list(
    schema_version = "phase18-ucl-source-unavailable-v1", edition_id = edition_id,
    provider_id = as.character(exit_review$provider_id[[1L]]),
    provider_decision_id = as.character(exit_review$provider_decision_id[[1L]]),
    provider_decision_sha256 = as.character(exit_review$provider_decision_sha256[[1L]]),
    exit_review_id = as.character(exit_review$exit_review_id[[1L]]),
    exit_review_sha256 = as.character(exit_review$exit_review_sha256[[1L]]),
    reason = as.character(exit_review$reason[[1L]]), effective_at_utc = now_utc,
    withdrawn_inventory_sha256 = phase18_ucl_hash(paste(names(withdrawn), withdrawn, collapse = "|")),
    retained_inventory_sha256 = phase18_ucl_hash(paste(names(retained), retained, collapse = "|")),
    tombstone_sha256 = ""
  )
  tombstone$tombstone_sha256 <- phase18_ucl_unavailable_tombstone_hash(tombstone)
  phase18_ucl_refresh_write_json_atomic(tombstone, file.path(stage, "source_unavailable.json"))
  phase18_validate_ucl_unavailable_tombstone(file.path(stage, "source_unavailable.json"))

  failure <- tryCatch({
    phase18_ucl_refresh_run_hook(writer_hooks, "before_provider_exit_swap", "promotion_failure", "compliance")
    if (!file.rename(target, backup)) phase18_ucl_refresh_abort("promotion_failure", "Could not backup provider tree", "compliance")
    if (!file.rename(stage, target)) phase18_ucl_refresh_abort("promotion_failure", "Could not install unavailable tree", "compliance")
    phase18_ucl_refresh_run_hook(writer_hooks, "after_provider_exit_swap", "promotion_failure", "compliance")
    phase18_validate_ucl_unavailable_tombstone(file.path(target, "source_unavailable.json"))
    for (relative in names(retained)) {
      path <- file.path(target, relative)
      if (!file.exists(path) || !identical(
        phase18_ucl_hash(readBin(path, "raw", n = file.info(path)$size)), retained[[relative]]
      )) phase18_ucl_refresh_abort("read_back_failure", "Retained lawful inventory changed", "compliance")
    }
    row <- phase18_ucl_refresh_event_row(
      batch_id, now_utc, edition_id, "source_unavailable", NULL, incumbent,
      "compliance", "provider_exit_required", "withdraw", FALSE
    )
    phase18_ucl_refresh_publish_event(roots, row, hooks = writer_hooks, blocked = FALSE)
    NULL
  }, error = function(error) error)
  if (!is.null(failure)) {
    phase18_ucl_refresh_restore_tree(target, snapshot)
    stop(failure)
  }
  if (dir.exists(backup)) unlink(backup, recursive = TRUE, force = TRUE)
  invisible(list(
    status = "source_unavailable", disposition = "withdraw",
    automation_enabled = FALSE, refresh_batch_id = batch_id,
    tombstone_path = file.path(target, "source_unavailable.json")
  ))
}
