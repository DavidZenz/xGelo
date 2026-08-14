#!/usr/bin/env Rscript

# Bounded Phase 13 source capture.  This entrypoint accepts either committed
# compact fixtures or one operator-supplied URL per structured resource class.
# It never parses rendered page text and never publishes a candidate before the
# complete edition-wide bundle has passed the source contract.

phase13_acquire_command_args <- commandArgs(trailingOnly = FALSE)
phase13_acquire_script_args <- phase13_acquire_command_args[grepl("^--file=", phase13_acquire_command_args)]
phase13_acquire_source_file <- tryCatch(sys.frame(1L)$ofile, error = function(error) NULL)
phase13_acquire_script_candidates <- c(
  if (length(phase13_acquire_script_args)) sub("^--file=", "", phase13_acquire_script_args[[1L]]) else character(),
  if (!is.null(phase13_acquire_source_file)) as.character(phase13_acquire_source_file) else character(),
  file.path(getwd(), "scripts/acquire_uefa_snapshot.R")
)
phase13_acquire_script_candidates <- phase13_acquire_script_candidates[
  !is.na(phase13_acquire_script_candidates) & nzchar(phase13_acquire_script_candidates)
]
phase13_acquire_script_file <- phase13_acquire_script_candidates[
  vapply(phase13_acquire_script_candidates, file.exists, logical(1))
][1L]
if (is.na(phase13_acquire_script_file) || !nzchar(phase13_acquire_script_file)) {
  stop("Phase 13 capture entrypoint could not resolve its script path", call. = FALSE)
}
phase13_acquire_script_file <- normalizePath(
  phase13_acquire_script_file,
  winslash = "/",
  mustWork = TRUE
)
phase13_acquire_project_root <- normalizePath(
  file.path(dirname(phase13_acquire_script_file), ".."),
  winslash = "/",
  mustWork = TRUE
)
source(file.path(phase13_acquire_project_root, "R/competition/source_contracts.R"))
source(file.path(phase13_acquire_project_root, "R/competition/team_identity.R"))
source(file.path(phase13_acquire_project_root, "R/competition/edition_registry.R"))
source(file.path(phase13_acquire_project_root, "R/competition/publication_hashes.R"))
source(file.path(phase13_acquire_project_root, "R/competition/publication_manifests.R"))
source(file.path(phase13_acquire_project_root, "R/competition/publication_transaction.R"))

# `source()` intentionally keeps the shared contract helpers in the process
# environment for the command-line entrypoint.  Rebind the transaction and
# hash helpers into a sys.source() caller's environment as well, so tests and
# embedded acquisition callers receive the same executable API.
phase13_normalized_publication_targets <- get("phase13_normalized_publication_targets", envir = .GlobalEnv)
phase13_with_publication_lock <- get("phase13_with_publication_lock", envir = .GlobalEnv)
phase13_seed_publication_staging <- get("phase13_seed_publication_staging", envir = .GlobalEnv)
phase13_promote_publication_targets <- get("phase13_promote_publication_targets", envir = .GlobalEnv)
phase13_refresh_canonical_table_hashes <- get("phase13_refresh_canonical_table_hashes", envir = .GlobalEnv)
phase13_refresh_accepted_manifest_hashes <- get("phase13_refresh_accepted_manifest_hashes", envir = .GlobalEnv)

phase13_acquire_now_utc <- function() {
  format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

phase13_acquire_resolve_path <- function(path, project_root = phase13_acquire_project_root) {
  path <- phase13_source_scalar(path, "path")
  value <- if (grepl("^/", path)) path else file.path(project_root, path)
  normalizePath(value, winslash = "/", mustWork = FALSE)
}

phase13_acquire_load_edition_context <- function(
    edition_id,
    registry_root = file.path(phase13_acquire_project_root, "data/competition/registries"),
    project_root = phase13_acquire_project_root) {
  edition_id <- phase13_source_safe_relative_path(edition_id)
  registry_root <- phase13_acquire_resolve_path(registry_root, project_root)
  if (!dir.exists(registry_root)) {
    stop("Phase 13 edition registry root is missing: ", registry_root, call. = FALSE)
  }

  identity_path <- file.path(registry_root, "team_identity.csv")
  edition_path <- file.path(registry_root, "competition_editions.csv")
  if (!file.exists(identity_path) || !file.exists(edition_path)) {
    stop(
      "Phase 13 accepted publication requires team identity and competition edition registries",
      call. = FALSE
    )
  }

  identity_registry <- load_phase13_team_identity_registry(identity_path)
  editions <- utils::read.csv(
    edition_path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = ""
  )
  required <- c("edition_id", "lifecycle_state", "source_bundle_id", "row_sha256")
  missing <- setdiff(required, names(editions))
  if (length(missing)) {
    stop(
      "Phase 13 competition edition registry is missing columns: ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
  selected <- editions[as.character(editions$edition_id) == edition_id, , drop = FALSE]
  if (nrow(selected) != 1L) {
    stop("Phase 13 competition edition registry must contain exactly one selected edition: ", edition_id, call. = FALSE)
  }
  lifecycle_state <- as.character(selected$lifecycle_state[[1L]])
  if (!lifecycle_state %in% c("pre_draw", "scheduled", "in_progress", "complete")) {
    stop("Phase 13 selected edition has an unsupported lifecycle state: ", lifecycle_state, call. = FALSE)
  }
  if (is.na(selected$source_bundle_id[[1L]]) || !nzchar(as.character(selected$source_bundle_id[[1L]]))) {
    stop("Phase 13 selected edition requires a source bundle ID", call. = FALSE)
  }
  actual_hash <- tolower(as.character(selected$row_sha256[[1L]]))
  expected_hash <- phase13_row_sha256(selected)
  if (!grepl("^[0-9a-f]{64}$", actual_hash) || !identical(actual_hash, expected_hash[[1L]])) {
    stop("Phase 13 selected edition registry row SHA-256 mismatch", call. = FALSE)
  }

  list(
    edition_id = edition_id,
    lifecycle_state = lifecycle_state,
    source_bundle_id = as.character(selected$source_bundle_id[[1L]]),
    identity_registry = identity_registry,
    edition_registry = selected,
    registry_root = registry_root,
    identity_path = normalizePath(identity_path, winslash = "/", mustWork = TRUE),
    edition_path = normalizePath(edition_path, winslash = "/", mustWork = TRUE)
  )
}

phase13_acquire_load_registry_context <- phase13_acquire_load_edition_context

phase13_acquire_value <- function(value, name, default = "") {
  if (is.null(value) || !length(value)) return(default)
  if (is.list(value)) value <- unlist(value, use.names = FALSE)
  if (!length(value) || is.na(value[[1L]])) return(default)
  as.character(value[[1L]])
}

phase13_acquire_parse_args <- function(args) {
  value_keys <- c(
    "fixture-dir", "fixture-file", "edition-id", "output-root", "registry-root",
    "raw-root", "fallback-file", "bundle-id", "fixtures-url", "groups-url",
    "standings-url", "results-url", "status-url", "url-fixtures", "url-groups",
    "url-standings", "url-results", "url-status", "source-url-fixtures",
    "source-url-groups", "source-url-standings", "source-url-results", "source-url-status",
    "refresh-batch-id", "operator", "operator-action", "validation-passed"
  )
  output <- list(dry_run = FALSE, help = FALSE, publish_accepted = FALSE)
  index <- 1L
  while (index <= length(args)) {
    token <- args[[index]]
    if (!startsWith(token, "--")) stop("Phase 13 capture argument must start with --: ", token, call. = FALSE)
    key <- sub("^--", "", token)
    key <- gsub("_", "-", key, fixed = TRUE)
    if (identical(key, "dry-run")) {
      output$dry_run <- TRUE
      index <- index + 1L
      next
    }
    if (identical(key, "help")) {
      output$help <- TRUE
      index <- index + 1L
      next
    }
    if (identical(key, "publish-accepted")) {
      output$publish_accepted <- TRUE
      index <- index + 1L
      next
    }
    if (!key %in% value_keys) stop("Unsupported Phase 13 capture option: --", key, call. = FALSE)
    if (index == length(args)) stop("Phase 13 capture option requires a value: --", key, call. = FALSE)
    output[[key]] <- args[[index + 1L]]
    index <- index + 2L
  }
  output
}

phase13_acquire_option_logical <- function(options, key, default = FALSE) {
  value <- options[[key]]
  if (is.null(value) || !length(value)) return(default)
  token <- tolower(trimws(as.character(value[[1L]])))
  if (token %in% c("true", "1", "yes")) return(TRUE)
  if (token %in% c("false", "0", "no")) return(FALSE)
  stop("Phase 13 option --", key, " must be true or false", call. = FALSE)
}

phase13_acquire_resolve_refresh_batch_id <- function(
    value = NULL,
    edition_id,
    at_utc = phase13_acquire_now_utc()) {
  if (!is.null(value) && length(value) && !is.na(value[[1L]]) && nzchar(as.character(value[[1L]]))) {
    batch_id <- as.character(value[[1L]])
  } else {
    entropy <- substr(
      phase13_source_sha256(paste(edition_id, at_utc, Sys.time(), Sys.getpid(), tempfile(), sep = "|")),
      1L,
      12L
    )
    batch_id <- paste0("refresh-", gsub("[^0-9]", "", at_utc), "-", entropy)
  }
  if (length(batch_id) != 1L || is.na(batch_id) ||
      !grepl("^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$", batch_id)) {
    stop("Phase 13 refresh_batch_id must be one safe identifier", call. = FALSE)
  }
  batch_id
}

phase13_refresh_history_schema <- function() {
  c(
    "schema_version", "edition_id", "refresh_batch_id", "event_index", "status",
    "event_at_utc", "candidate_bundle_id", "last_accepted_bundle_id",
    "last_accepted_output_bundle_id", "registry_revision", "operator",
    "operator_action", "validation_passed", "record_relative_path", "row_sha256"
  )
}

phase13_refresh_history_empty <- function() {
  data.frame(
    schema_version = character(),
    edition_id = character(),
    refresh_batch_id = character(),
    event_index = integer(),
    status = character(),
    event_at_utc = character(),
    candidate_bundle_id = character(),
    last_accepted_bundle_id = character(),
    last_accepted_output_bundle_id = character(),
    registry_revision = integer(),
    operator = character(),
    operator_action = character(),
    validation_passed = logical(),
    record_relative_path = character(),
    row_sha256 = character(),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

phase13_acquire_refresh_history_paths <- function(
    registry_root,
    edition_id,
    refresh_batch_id = NULL,
    refresh_batch_root = file.path(registry_root, "refresh_batches")) {
  registry_root <- phase13_acquire_resolve_path(registry_root)
  refresh_batch_root <- phase13_acquire_resolve_path(refresh_batch_root)
  edition_id <- phase13_source_safe_relative_path(edition_id)
  edition_root <- file.path(refresh_batch_root, edition_id)
  batch_root <- if (is.null(refresh_batch_id)) NULL else {
    refresh_batch_id <- phase13_acquire_resolve_refresh_batch_id(refresh_batch_id, edition_id)
    file.path(edition_root, refresh_batch_id)
  }
  list(
    registry_root = registry_root,
    refresh_batch_root = refresh_batch_root,
    edition_root = edition_root,
    batch_root = batch_root,
    history_path = file.path(edition_root, "status_history.csv"),
    blocked_path = if (is.null(batch_root)) NULL else file.path(batch_root, "blocked_refresh.json")
  )
}

phase13_acquire_read_refresh_history <- function(path) {
  if (!file.exists(path)) return(phase13_refresh_history_empty())
  history <- utils::read.csv(
    path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = ""
  )
  history
}

phase13_acquire_validate_refresh_history_table <- function(
    history,
    edition_id,
    refresh_batch_root) {
  phase13_source_require_columns(
    history,
    phase13_refresh_history_schema(),
    "Phase 13 refresh status history"
  )
  if (!nrow(history)) return(invisible(history))
  if (any(as.character(history$schema_version) != "phase13-refresh-status-history-v1")) {
    stop("Phase 13 refresh status history has an unsupported schema version", call. = FALSE)
  }
  if (any(as.character(history$edition_id) != edition_id)) {
    stop("Phase 13 refresh status history has a foreign edition ID", call. = FALSE)
  }
  batch_ids <- as.character(history$refresh_batch_id)
  if (any(is.na(batch_ids) | !nzchar(batch_ids))) stop("Phase 13 refresh status history has an empty batch ID", call. = FALSE)
  invisible(lapply(batch_ids, phase13_acquire_resolve_refresh_batch_id, edition_id = edition_id))
  event_index <- suppressWarnings(as.integer(history$event_index))
  if (any(is.na(event_index) | event_index < 1L) || !identical(event_index, seq_len(nrow(history)))) {
    stop("Phase 13 refresh status history event_index must be contiguous and append-only", call. = FALSE)
  }
  statuses <- as.character(history$status)
  if (any(!statuses %in% c("blocked", "recovery", "accepted"))) {
    stop("Phase 13 refresh status history contains an unsupported status", call. = FALSE)
  }
  if (any(vapply(history$event_at_utc, phase13_registry_blank, logical(1))) ||
      any(vapply(history$operator, phase13_registry_blank, logical(1))) ||
      any(vapply(history$candidate_bundle_id, phase13_registry_blank, logical(1))) ||
      any(vapply(history$last_accepted_bundle_id, phase13_registry_blank, logical(1))) ||
      any(vapply(history$last_accepted_output_bundle_id, phase13_registry_blank, logical(1)))) {
    stop("Phase 13 refresh status history is missing audit or accepted-lineage metadata", call. = FALSE)
  }
  revisions <- suppressWarnings(as.integer(history$registry_revision))
  if (any(is.na(revisions) | revisions < 1L)) stop("Phase 13 refresh status history has invalid registry revisions", call. = FALSE)
  validation <- vapply(history$validation_passed, phase13_registry_logical, logical(1), name = "validation_passed")
  relative_paths <- as.character(history$record_relative_path)
  for (index in seq_len(nrow(history))) {
    record <- relative_paths[[index]]
    if (is.na(record)) record <- ""
    if (nzchar(record)) {
      record <- phase13_source_safe_relative_path(record)
      expected <- file.path(
        "refresh_batches", edition_id, batch_ids[[index]], "blocked_refresh.json"
      )
      if (statuses[[index]] %in% c("blocked", "recovery") && !identical(record, expected)) {
        stop("Phase 13 refresh status history record path is inconsistent with its batch", call. = FALSE)
      }
      if (!phase13_source_path_within(file.path(refresh_batch_root, record), refresh_batch_root)) {
        stop("Phase 13 refresh status history record path escapes refresh_batches", call. = FALSE)
      }
    } else if (statuses[[index]] %in% c("blocked", "recovery")) {
      stop("Phase 13 blocked or recovery history events require a record path", call. = FALSE)
    }
    if (identical(statuses[[index]], "recovery") &&
        (!isTRUE(validation[[index]]) || phase13_registry_blank(history$operator_action[[index]]))) {
      stop("Phase 13 recovery history events require explicit validation and operator action", call. = FALSE)
    }
  }
  for (batch_id in unique(batch_ids)) {
    rows <- history[batch_ids == batch_id, , drop = FALSE]
    batch_statuses <- as.character(rows$status)
    if (!batch_statuses[[1L]] %in% c("blocked", "accepted") || sum(batch_statuses == "blocked") > 1L ||
        sum(batch_statuses == "recovery") > 1L || sum(batch_statuses == "accepted") > 1L) {
      stop("Phase 13 refresh status history has an invalid batch lifecycle", call. = FALSE)
    }
    if (any(batch_statuses == "blocked") && which(batch_statuses == "blocked")[[1L]] != 1L) {
      stop("Phase 13 blocked history event must be the first event for its batch", call. = FALSE)
    }
    if (any(batch_statuses == "recovery") && !any(batch_statuses == "blocked")) {
      stop("Phase 13 recovery history event has no blocked predecessor", call. = FALSE)
    }
    if (any(batch_statuses == "accepted") && any(batch_statuses == "blocked") &&
        !any(batch_statuses == "recovery")) {
      stop("Phase 13 accepted recovery batch requires a recovery event", call. = FALSE)
    }
  }
  phase13_source_validate_hash_column(history, "row_sha256", "Phase 13 refresh status history")
  invisible(history)
}

phase13_acquire_build_refresh_history_row <- function(
    edition_id,
    refresh_batch_id,
    event_index,
    status,
    event_at_utc,
    candidate_bundle_id,
    last_accepted_bundle_id,
    last_accepted_output_bundle_id,
    registry_revision,
    operator,
    operator_action = "",
    validation_passed = FALSE,
    record_relative_path = "") {
  row <- data.frame(
    schema_version = "phase13-refresh-status-history-v1",
    edition_id = edition_id,
    refresh_batch_id = refresh_batch_id,
    event_index = as.integer(event_index),
    status = status,
    event_at_utc = event_at_utc,
    candidate_bundle_id = candidate_bundle_id,
    last_accepted_bundle_id = last_accepted_bundle_id,
    last_accepted_output_bundle_id = last_accepted_output_bundle_id,
    registry_revision = as.integer(registry_revision),
    operator = operator,
    operator_action = operator_action,
    validation_passed = isTRUE(validation_passed),
    record_relative_path = record_relative_path,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  row$row_sha256 <- phase13_row_sha256(row)
  row
}

phase13_acquire_read_blocked_refresh <- function(path) {
  if (!file.exists(path) || dir.exists(path)) stop("Phase 13 blocked refresh record is missing: ", path, call. = FALSE)
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("jsonlite is required for Phase 13 refresh records", call. = FALSE)
  jsonlite::fromJSON(path, simplifyVector = TRUE)
}

phase13_acquire_copy_registry_overlay <- function(registry_root, edition_path, overlay_root) {
  dir.create(overlay_root, recursive = TRUE, showWarnings = FALSE)
  required <- c("source_bundles.csv", "source_artifacts.csv", "team_identity.csv")
  paths <- file.path(registry_root, required)
  if (any(!file.exists(paths))) {
    stop("Phase 13 refresh validation cannot build a registry overlay", call. = FALSE)
  }
  if (!all(file.copy(paths, overlay_root, overwrite = TRUE)) ||
      !file.copy(edition_path, file.path(overlay_root, "competition_editions.csv"), overwrite = TRUE)) {
    stop("Phase 13 refresh validation could not copy its registry overlay", call. = FALSE)
  }
  overlay_root
}

phase13_validate_refresh_history <- function(
    edition_id,
    registry_root = file.path(phase13_acquire_project_root, "data/competition/registries"),
    accepted_root = file.path(phase13_acquire_project_root, "data/competition/accepted"),
    refresh_batch_root,
    refresh_batch_id = NULL,
    project_root = phase13_acquire_project_root,
    edition_path = NULL,
    raw_root = NULL) {
  edition_id <- phase13_source_safe_relative_path(edition_id)
  registry_root <- phase13_acquire_resolve_path(registry_root, project_root)
  accepted_root <- phase13_acquire_resolve_path(accepted_root, project_root)
  refresh_batch_root <- phase13_acquire_resolve_path(refresh_batch_root, project_root)
  if (!dir.exists(registry_root) || !dir.exists(accepted_root)) {
    stop("Phase 13 refresh validation requires trusted registry and accepted roots", call. = FALSE)
  }
  if (!dir.exists(refresh_batch_root) && !is.null(refresh_batch_id)) {
    stop("Phase 13 refresh validation requires a refresh-batch root for a requested batch", call. = FALSE)
  }

  overlay_root <- NULL
  validation_registry_root <- registry_root
  if (!is.null(edition_path)) {
    edition_path <- phase13_acquire_resolve_path(edition_path, project_root)
    overlay_root <- tempfile(".phase13-refresh-validation-", tmpdir = registry_root)
    validation_registry_root <- phase13_acquire_copy_registry_overlay(
      registry_root,
      edition_path,
      overlay_root
    )
    on.exit(if (!is.null(overlay_root) && dir.exists(overlay_root)) unlink(overlay_root, recursive = TRUE, force = TRUE), add = TRUE)
  }

  registries <- load_competition_edition_registries(
    registry_dir = validation_registry_root,
    project_root = project_root,
    accepted_root = accepted_root,
    raw_root = raw_root
  )
  edition_rows <- registries[as.character(registries$edition_id) == edition_id, , drop = FALSE]
  if (nrow(edition_rows) != 1L) stop("Phase 13 refresh validation requires one edition row: ", edition_id, call. = FALSE)
  history_paths <- phase13_acquire_refresh_history_paths(
    registry_root,
    edition_id,
    refresh_batch_id = refresh_batch_id,
    refresh_batch_root = refresh_batch_root
  )
  history <- if (dir.exists(refresh_batch_root)) {
    phase13_acquire_read_refresh_history(file.path(refresh_batch_root, edition_id, "status_history.csv"))
  } else {
    phase13_refresh_history_empty()
  }
  phase13_acquire_validate_refresh_history_table(history, edition_id, refresh_batch_root)
  result <- list(
    registries = registries,
    edition = edition_rows,
    history = history,
    history_path = file.path(refresh_batch_root, edition_id, "status_history.csv"),
    refresh_batch_root = refresh_batch_root,
    accepted_snapshot = registries$accepted_snapshots[[edition_id]]
  )
  if (is.null(refresh_batch_id)) return(result)

  refresh_batch_id <- phase13_acquire_resolve_refresh_batch_id(refresh_batch_id, edition_id)
  blocked_path <- file.path(
    refresh_batch_root,
    edition_id,
    refresh_batch_id,
    "blocked_refresh.json"
  )
  metadata <- phase13_acquire_read_blocked_refresh(blocked_path)
  required <- c(
    "schema_version", "refresh_batch_id", "status", "edition_id", "candidate_bundle_id",
    "last_accepted_bundle_id", "last_accepted_output_bundle_id", "blocked_at_utc",
    "failure_reason", "registry_revision", "parser_commit_sha", "edition_blocked"
  )
  missing <- setdiff(required, names(metadata))
  if (length(missing)) stop("Phase 13 blocked refresh record is missing fields: ", paste(missing, collapse = ", "), call. = FALSE)
  if (!identical(as.character(metadata$schema_version), "phase13-refresh-batch-v1") ||
      !identical(as.character(metadata$status), "blocked") ||
      !identical(as.character(metadata$refresh_batch_id), refresh_batch_id) ||
      !identical(as.character(metadata$edition_id), edition_id) ||
      !isTRUE(metadata$edition_blocked)) {
    stop("Phase 13 blocked refresh record identity or status does not match", call. = FALSE)
  }
  if (phase13_registry_blank(metadata$candidate_bundle_id) ||
      phase13_registry_blank(metadata$last_accepted_bundle_id) ||
      phase13_registry_blank(metadata$last_accepted_output_bundle_id) ||
      phase13_registry_blank(metadata$blocked_at_utc) ||
      phase13_registry_blank(metadata$failure_reason) ||
      !grepl("^[0-9a-fA-F]{7,64}$", as.character(metadata$parser_commit_sha))) {
    stop("Phase 13 blocked refresh record has incomplete audit metadata", call. = FALSE)
  }
  revision <- suppressWarnings(as.integer(metadata$registry_revision))
  if (is.na(revision) || revision < 1L) stop("Phase 13 blocked refresh record has an invalid registry revision", call. = FALSE)
  matching <- history[as.character(history$refresh_batch_id) == refresh_batch_id, , drop = FALSE]
  blocked_events <- matching[as.character(matching$status) == "blocked", , drop = FALSE]
  if (nrow(blocked_events) != 1L) stop("Phase 13 refresh history must contain one blocked event for the batch", call. = FALSE)
  blocked_event <- blocked_events[1L, , drop = FALSE]
  compare <- c(
    refresh_batch_id = "refresh_batch_id",
    edition_id = "edition_id",
    candidate_bundle_id = "candidate_bundle_id",
    last_accepted_bundle_id = "last_accepted_bundle_id",
    last_accepted_output_bundle_id = "last_accepted_output_bundle_id",
    blocked_at_utc = "event_at_utc",
    registry_revision = "registry_revision"
  )
  for (field in names(compare)) {
    expected <- phase13_source_canonical_scalar(metadata[[field]])
    actual <- phase13_source_canonical_scalar(blocked_event[[compare[[field]]]][[1L]])
    if (!identical(expected, actual)) {
      stop("Phase 13 blocked refresh record disagrees with status history: ", field, call. = FALSE)
    }
  }
  expected_record_path <- file.path(
    "refresh_batches", edition_id, refresh_batch_id, "blocked_refresh.json"
  )
  if (!identical(as.character(blocked_event$record_relative_path[[1L]]), expected_record_path)) {
    stop("Phase 13 blocked refresh record path is not linked from status history", call. = FALSE)
  }

  current <- edition_rows[1L, , drop = FALSE]
  current_blocked <- phase13_registry_logical(current$blocked[[1L]], "blocked")
  current_pointer <- if ("blocked_refresh_batch_id" %in% names(current)) {
    as.character(current$blocked_refresh_batch_id[[1L]])
  } else {
    ""
  }
  if (current_blocked && !identical(current_pointer, refresh_batch_id)) {
    stop("Phase 13 blocked edition does not point to its blocked refresh batch", call. = FALSE)
  }
  if (current_blocked &&
      (!identical(as.character(current$active_output_bundle_id[[1L]]), as.character(metadata$last_accepted_output_bundle_id)) ||
       !identical(as.character(current$last_accepted_output_bundle_id[[1L]]), as.character(metadata$last_accepted_output_bundle_id)))) {
    stop("Phase 13 blocked edition does not retain the blocked batch's active output", call. = FALSE)
  }
  if (current_blocked && !identical(as.character(current$source_bundle_id[[1L]]), as.character(metadata$last_accepted_bundle_id))) {
    stop("Phase 13 blocked edition does not retain the blocked batch's accepted bundle", call. = FALSE)
  }
  if (current_blocked && !identical(as.character(current$registry_revision[[1L]]), as.character(metadata$registry_revision))) {
    stop("Phase 13 blocked edition registry revision does not match its refresh batch", call. = FALSE)
  }

  current_bundle <- attr(registries, "source_bundles")
  current_bundle <- current_bundle[as.character(current_bundle$bundle_id) == as.character(metadata$last_accepted_bundle_id), , drop = FALSE]
  if (current_blocked && nrow(current_bundle) != 1L) {
    stop("Phase 13 blocked refresh record does not link to an accepted source bundle", call. = FALSE)
  }
  if (current_blocked &&
      !identical(as.character(result$accepted_snapshot$bundle_id), as.character(metadata$last_accepted_bundle_id))) {
    stop("Phase 13 blocked refresh record does not link to the active accepted snapshot", call. = FALSE)
  }
  result$refresh_batch_id <- refresh_batch_id
  result$blocked_record <- metadata
  result$blocked_event <- blocked_event
  result
}

phase13_acquire_help <- function() {
  c(
    "Usage: Rscript --vanilla scripts/acquire_uefa_snapshot.R [options]",
    "",
    "Fixture replay:",
    "  --fixture-dir DIR --edition-id EDITION [--output-root DIR] [--registry-root DIR]",
    "  [--raw-root DIR] [--fallback-file FILE] [--bundle-id ID] [--publish-accepted] [--dry-run]",
    "",
    "Bounded live capture:",
    "  --edition-id EDITION --fixtures-url URL --groups-url URL --standings-url URL",
    "  --results-url URL [--status-url URL] [--publish-accepted] [the same output options as above]",
    "  [--refresh-batch-id ID] [--operator NAME] [--operator-action TEXT] [--validation-passed true|false]",
    "",
    "Only structured JSON resources are accepted.  Rendered HTML and PDF inputs are rejected."
  )
}

phase13_acquire_default_bundle_id <- function(edition_id, fallback = FALSE) {
  if (identical(edition_id, "uefa_nations_league_2026_27")) {
    return(if (fallback) "nl-2026-27-reviewed-fallback-sample-v1" else "nl-2026-27-official-sample-v1")
  }
  paste(edition_id, if (fallback) "reviewed-fallback" else "official", "v1", sep = "-")
}

phase13_acquire_fixture_path <- function(fixture_dir, edition_id, fixture_file = NULL) {
  root <- phase13_acquire_resolve_path(fixture_dir)
  candidates <- if (!is.null(fixture_file)) {
    phase13_acquire_resolve_path(fixture_file)
  } else if (identical(edition_id, "uefa_nations_league_2026_27")) {
    file.path(root, "uefa_nations_league_sample.json")
  } else if (identical(edition_id, "uefa_euro_2028_qualifying")) {
    file.path(root, "euro2028_predraw_sample.json")
  } else {
    c(file.path(root, paste0(edition_id, ".json")), file.path(root, "uefa_nations_league_sample.json"))
  }
  candidates <- candidates[file.exists(candidates)]
  if (!length(candidates)) stop("No Phase 13 compact fixture found for edition: ", edition_id, call. = FALSE)
  candidates[[1L]]
}

phase13_acquire_empty_resource <- function(artifact_type) {
  fields <- phase13_source_compact_resource_schema()[[artifact_type]]
  types <- lapply(fields, function(field) {
    if (field %in% c("position", "points", "home_goals", "away_goals")) integer() else character()
  })
  names(types) <- fields
  as.data.frame(types, stringsAsFactors = FALSE, check.names = FALSE)
}

phase13_acquire_fixture_input <- function(fixture_dir, edition_id, fixture_file = NULL) {
  path <- phase13_acquire_fixture_path(fixture_dir, edition_id, fixture_file)
  fixture <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  if (identical(edition_id, "uefa_euro_2028_qualifying") && is.null(fixture$resources)) {
    lifecycle_state <- phase13_acquire_value(
      fixture$lifecycle_state,
      "lifecycle_state",
      phase13_acquire_value(fixture$source_snapshot_state, "source_snapshot_state")
    )
    resource_types <- phase13_source_required_resource_types()
    resources <- setNames(lapply(resource_types, phase13_acquire_empty_resource), resource_types)
    resources$status <- list(list(
      source_edition_id = fixture$edition_id,
      competition_status = lifecycle_state
    ))
    urls <- setNames(rep(fixture$source_reference, length(resource_types)), resource_types)
    return(list(
      edition_id = fixture$edition_id,
      resources = resources,
      source_urls = urls,
      raw_bytes_by_resource = lapply(resources, function(value) jsonlite::toJSON(value, auto_unbox = TRUE, pretty = FALSE, null = "null")),
      retrieved_at_utc = phase13_acquire_now_utc()
    ))
  }
  if (is.null(fixture$resources) || is.null(fixture$source_urls)) {
    stop("Phase 13 fixture must include resources and source_urls", call. = FALSE)
  }
  resources <- fixture$resources
  mandatory_types <- c("fixtures", "groups", "standings", "results")
  missing <- setdiff(mandatory_types, names(resources))
  if (length(missing)) {
    stop("Phase 13 fixture is missing mandatory resource classes: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  resource_types <- mandatory_types
  if ("status" %in% names(resources) && "status" %in% names(fixture$source_urls) &&
      nzchar(phase13_acquire_value(fixture$source_urls$status, "status URL"))) {
    resource_types <- c(resource_types, "status")
  }
  raw_bytes <- lapply(resources[resource_types], function(value) {
    jsonlite::toJSON(value, auto_unbox = TRUE, pretty = FALSE, null = "null", digits = 17)
  })
  list(
    edition_id = phase13_source_scalar(fixture$edition_id, "edition_id"),
    resources = resources[resource_types],
    source_urls = unlist(fixture$source_urls[resource_types], use.names = TRUE),
    raw_bytes_by_resource = raw_bytes,
    retrieved_at_utc = phase13_acquire_value(fixture$retrieved_at_utc, "retrieved_at_utc", phase13_acquire_now_utc())
  )
}

phase13_acquire_clock_seconds <- function(clock_fn) {
  value <- clock_fn()
  if (inherits(value, "POSIXt")) value <- as.numeric(value)
  value <- suppressWarnings(as.numeric(value[[1L]]))
  if (length(value) != 1L || is.na(value) || !is.finite(value)) {
    stop("Phase 13 capture clock callback must return one finite number", call. = FALSE)
  }
  value
}

phase13_acquire_response_status <- function(response) {
  if (inherits(response, "httr2_response")) return(as.integer(httr2::resp_status(response)))
  if (is.list(response)) {
    value <- response$status_code %||% response$status
    if (length(value)) return(as.integer(value[[1L]]))
  }
  stop("Phase 13 structured response did not expose an HTTP status", call. = FALSE)
}

phase13_acquire_response_header <- function(response, header, default = "") {
  if (inherits(response, "httr2_response")) {
    return(as.character(httr2::resp_header(response, header, default = default) %||% default))
  }
  headers <- if (is.list(response)) response$headers else NULL
  if (is.null(headers) || !length(headers)) return(default)
  names_lower <- tolower(names(headers))
  match_index <- match(tolower(header), names_lower)
  if (is.na(match_index)) default else as.character(headers[[match_index]])
}

phase13_acquire_response_raw <- function(response, artifact_type) {
  raw_bytes <- if (inherits(response, "httr2_response")) {
    tryCatch(
      httr2::resp_body_raw(response),
      error = function(error) stop("Phase 13 structured response has no body for ", artifact_type, call. = FALSE)
    )
  } else if (is.list(response)) {
    response$raw_bytes %||% response$body
  } else {
    NULL
  }
  if (is.null(raw_bytes)) stop("Phase 13 structured response has no body for ", artifact_type, call. = FALSE)
  phase13_source_raw_bytes(raw_bytes)
}

phase13_acquire_retryable_statuses <- function() {
  c(408L, 425L, 429L, 500L, 502L, 503L, 504L)
}

phase13_acquire_rate_limit_wait <- function(
    rate_limit_state,
    clock_fn,
    sleep_fn,
    min_interval_seconds) {
  now <- phase13_acquire_clock_seconds(clock_fn)
  previous <- if (exists("next_allowed_at", envir = rate_limit_state, inherits = FALSE)) {
    get("next_allowed_at", envir = rate_limit_state, inherits = FALSE)
  } else {
    NULL
  }
  wait <- if (is.null(previous)) 0 else max(0, as.numeric(previous) - now)
  if (wait > 0) sleep_fn(wait)
  assign(
    "next_allowed_at",
    max(now, if (is.null(previous)) now else as.numeric(previous)) + min_interval_seconds,
    envir = rate_limit_state
  )
  invisible(wait)
}

phase13_acquire_fetch_structured_url <- function(
    url,
    artifact_type,
    max_bytes = 5e6,
    max_attempts = 3L,
    timeout_seconds = 30,
    min_interval_seconds = 1,
    backoff_base_seconds = 1,
    request_fn = NULL,
    perform_fn = NULL,
    clock_fn = function() as.numeric(Sys.time()),
    sleep_fn = Sys.sleep,
    rate_limit_state = NULL) {
  url <- phase13_source_scalar(url, paste0(artifact_type, " URL"))
  artifact_type <- phase13_source_scalar(artifact_type, "artifact_type")
  if (!grepl("^https://", tolower(url))) {
    stop("Phase 13 live capture requires an HTTPS URL for ", artifact_type, call. = FALSE)
  }
  if (!requireNamespace("httr2", quietly = TRUE)) {
    stop("httr2 is required for Phase 13 live structured capture", call. = FALSE)
  }
  max_bytes <- suppressWarnings(as.numeric(max_bytes))
  max_attempts <- suppressWarnings(as.integer(max_attempts))
  timeout_seconds <- suppressWarnings(as.numeric(timeout_seconds))
  min_interval_seconds <- suppressWarnings(as.numeric(min_interval_seconds))
  backoff_base_seconds <- suppressWarnings(as.numeric(backoff_base_seconds))
  if (is.na(max_bytes) || max_bytes <= 0 || is.na(max_attempts) || max_attempts < 1L ||
      is.na(timeout_seconds) || timeout_seconds <= 0 || is.na(min_interval_seconds) || min_interval_seconds < 0 ||
      is.na(backoff_base_seconds) || backoff_base_seconds <= 0) {
    stop("Phase 13 structured capture bounds must be positive", call. = FALSE)
  }
  max_attempts <- min(max_attempts, 3L)
  if (is.null(rate_limit_state)) rate_limit_state <- new.env(parent = emptyenv())
  if (is.null(request_fn)) request_fn <- function(value) httr2::request(value)
  if (is.null(perform_fn)) perform_fn <- function(request) httr2::req_perform(request)

  last_message <- ""
  for (attempt in seq_len(max_attempts)) {
    phase13_acquire_rate_limit_wait(
      rate_limit_state, clock_fn, sleep_fn, min_interval_seconds
    )
    request <- tryCatch(
      request_fn(url),
      error = function(error) stop(
        "Phase 13 structured URL request construction failed for ", artifact_type,
        ": ", conditionMessage(error), call. = FALSE
      )
    )
    if (inherits(request, "httr2_request")) {
      request <- httr2::req_headers(request, Accept = "application/json")
      request <- httr2::req_timeout(request, seconds = timeout_seconds)
    } else if (is.list(request)) {
      request$headers <- c(request$headers %||% list(), list(Accept = "application/json"))
      request$timeout_seconds <- timeout_seconds
    }

    response_error <- NULL
    response <- tryCatch(
      perform_fn(request),
      error = function(error) {
        response_error <<- error
        NULL
      }
    )
    status <- if (is.null(response)) NA_integer_ else {
      tryCatch(phase13_acquire_response_status(response), error = function(error) NA_integer_)
    }
    transient <- is.na(status) || status %in% phase13_acquire_retryable_statuses()
    if (!is.null(response) && status >= 200L && status < 300L) {
      content_type <- tolower(trimws(phase13_acquire_response_header(response, "content-type", "")))
      if (!grepl("^application/(json|[a-z0-9.+-]+\\+json)(;|$)", content_type)) {
        stop("Phase 13 structured response for ", artifact_type, " is not JSON (content-type: ", content_type, ")", call. = FALSE)
      }
      raw_bytes <- phase13_acquire_response_raw(response, artifact_type)
      if (!length(raw_bytes) || length(raw_bytes) > max_bytes) {
        stop("Phase 13 structured URL response exceeds the bounded byte limit: ", artifact_type, call. = FALSE)
      }
      phase13_source_validate_structured_bytes(raw_bytes, artifact_type)
      payload <- tryCatch(
        jsonlite::fromJSON(rawToChar(raw_bytes), simplifyVector = FALSE),
        error = function(error) stop(
          "Phase 13 structured response JSON parsing failed for ", artifact_type,
          ": ", conditionMessage(error), call. = FALSE
        )
      )
      tryCatch(
        phase13_source_validate_resource_payload(payload, artifact_type),
        error = function(error) stop(
          "Phase 13 structured response schema validation failed for ", artifact_type,
          ": ", conditionMessage(error), call. = FALSE
        )
      )
      return(list(payload = payload, raw_bytes = raw_bytes, source_url = url))
    }

    last_message <- if (!is.null(response_error)) {
      conditionMessage(response_error)
    } else if (is.na(status)) {
      "response did not expose an HTTP status"
    } else {
      paste0("HTTP status ", status)
    }
    if (!transient || attempt >= max_attempts) break
    sleep_fn(min(8, backoff_base_seconds * (2 ^ (attempt - 1L))))
  }
  stop(
    "Phase 13 structured URL capture failed for ", artifact_type,
    " after ", max_attempts, " attempt(s): ", last_message,
    call. = FALSE
  )
}

phase13_acquire_option_url <- function(options, artifact_type) {
  candidates <- c(
    options[[paste0(artifact_type, "-url")]],
    options[[paste0("url-", artifact_type)]],
    options[[paste0("source-url-", artifact_type)]]
  )
  candidates <- candidates[!vapply(candidates, is.null, logical(1))]
  candidates <- candidates[vapply(candidates, function(value) length(value) && !is.na(value[[1L]]) && nzchar(as.character(value[[1L]])), logical(1))]
  if (!length(candidates)) return(NULL)
  as.character(candidates[[1L]])
}

phase13_acquire_status_evidence <- function(resource_payloads) {
  status_fields <- c(
    "competition_status", "competition_state", "edition_status", "edition_state",
    "lifecycle_state", "source_snapshot_state"
  )
  edition_fields <- c(
    "source_edition_id", "source_edition", "source_competition_id",
    "competition_edition_id", "edition_id"
  )
  evidence <- list()
  visit <- function(value, resource_type) {
    if (is.data.frame(value)) {
      for (index in seq_len(nrow(value))) visit(as.list(value[index, , drop = FALSE]), resource_type)
      return(invisible(NULL))
    }
    if (!is.list(value)) return(invisible(NULL))
    fields <- names(value)
    if (length(fields)) {
      for (field in intersect(fields, c(status_fields, edition_fields))) {
        candidate <- value[[field]]
        if (is.atomic(candidate) && length(candidate)) {
          candidate <- as.character(candidate)
          candidate <- candidate[!is.na(candidate) & nzchar(trimws(candidate))]
          if (length(candidate)) evidence[[length(evidence) + 1L]] <<- list(
            resource_type = resource_type,
            field = field,
            values = candidate
          )
        }
      }
      for (field in setdiff(fields, c(status_fields, edition_fields))) visit(value[[field]], resource_type)
    } else {
      for (child in value) visit(child, resource_type)
    }
    invisible(NULL)
  }
  for (resource_type in intersect(names(resource_payloads), c("fixtures", "groups", "standings", "results"))) {
    visit(resource_payloads[[resource_type]], resource_type)
  }
  evidence
}

phase13_acquire_derive_status <- function(input, edition_id) {
  evidence <- phase13_acquire_status_evidence(input$resources)
  status_evidence <- evidence[vapply(evidence, function(item) item$field %in% c(
    "competition_status", "competition_state", "edition_status", "edition_state",
    "lifecycle_state", "source_snapshot_state"
  ), logical(1))]
  statuses <- sort(unique(unlist(lapply(status_evidence, function(item) item$values), use.names = FALSE)))
  if (!length(statuses)) {
    stop(
      "Phase 13 status source unavailable: optional status URL was not supplied and no status-bearing fields were found",
      call. = FALSE
    )
  }
  if (length(statuses) != 1L) {
    stop("Phase 13 derived status has conflicting status-bearing fields", call. = FALSE)
  }
  edition_evidence <- evidence[vapply(evidence, function(item) item$field %in% c(
    "source_edition_id", "source_edition", "source_competition_id", "competition_edition_id", "edition_id"
  ), logical(1))]
  source_edition <- sort(unique(unlist(lapply(edition_evidence, function(item) item$values), use.names = FALSE)))
  if (length(source_edition) > 1L) {
    stop("Phase 13 derived status has conflicting source edition identifiers", call. = FALSE)
  }
  source_edition <- if (length(source_edition)) source_edition[[1L]] else edition_id
  contributors <- sort(unique(vapply(status_evidence, function(item) item$resource_type, character(1))))
  if (!length(contributors)) stop("Phase 13 derived status has no contributing resources", call. = FALSE)
  status_payload <- list(list(
    source_edition_id = source_edition,
    competition_status = statuses[[1L]]
  ))
  source_urls <- as.character(input$source_urls[contributors])
  source_urls <- source_urls[!is.na(source_urls) & nzchar(source_urls)]
  if (!length(source_urls)) stop("Phase 13 derived status has no contributing source URLs", call. = FALSE)
  status_url <- paste(sort(unique(source_urls)), collapse = " | ")
  raw_bytes <- jsonlite::toJSON(status_payload, auto_unbox = TRUE, pretty = FALSE, null = "null", digits = 17)
  input$resources$status <- status_payload
  input$source_urls[["status"]] <- status_url
  input$raw_bytes_by_resource$status <- raw_bytes
  input$status_provenance <- "derived"
  input$status_contributors <- contributors
  input
}

phase13_acquire_finalize_input <- function(input, edition_id) {
  mandatory <- c("fixtures", "groups", "standings", "results")
  missing <- setdiff(mandatory, names(input$resources))
  if (length(missing)) stop("Phase 13 capture is missing mandatory resource classes: ", paste(missing, collapse = ", "), call. = FALSE)
  invisible(lapply(mandatory, function(type) phase13_source_validate_resource_payload(input$resources[[type]], type)))
  has_explicit_status <- "status" %in% names(input$resources) && "status" %in% names(input$source_urls) &&
    !is.null(input$source_urls[["status"]]) && nzchar(as.character(input$source_urls[["status"]]))
  if (has_explicit_status) {
    phase13_source_validate_resource_payload(input$resources$status, "status")
    input$status_provenance <- "explicit"
    input$status_contributors <- "status"
    return(input)
  }
  phase13_acquire_derive_status(input, edition_id)
}

phase13_acquire_live_input <- function(
    options,
    edition_id,
    fetch_fn = phase13_acquire_fetch_structured_url,
    clock_fn = function() as.numeric(Sys.time()),
    sleep_fn = Sys.sleep,
    rate_limit_state = NULL) {
  mandatory <- c("fixtures", "groups", "standings", "results")
  url_values <- setNames(vapply(mandatory, function(type) {
    value <- phase13_acquire_option_url(options, type)
    if (is.null(value)) return(NA_character_)
    value
  }, character(1)), mandatory)
  if (any(is.na(url_values) | !nzchar(url_values))) {
    stop("Live Phase 13 capture requires explicit HTTPS URLs for fixtures, groups, standings, and results", call. = FALSE)
  }
  if (is.null(rate_limit_state)) rate_limit_state <- new.env(parent = emptyenv())
  payloads <- list()
  raw_bytes <- list()
  for (artifact_type in mandatory) {
    captured <- fetch_fn(
      url_values[[artifact_type]], artifact_type,
      rate_limit_state = rate_limit_state, clock_fn = clock_fn, sleep_fn = sleep_fn
    )
    payloads[[artifact_type]] <- captured$payload
    raw_bytes[[artifact_type]] <- captured$raw_bytes
  }
  input <- list(
    edition_id = edition_id,
    resources = payloads,
    source_urls = url_values,
    raw_bytes_by_resource = raw_bytes,
    retrieved_at_utc = phase13_acquire_now_utc()
  )
  status_url <- phase13_acquire_option_url(options, "status")
  if (!is.null(status_url)) {
    captured <- fetch_fn(
      status_url, "status",
      rate_limit_state = rate_limit_state, clock_fn = clock_fn, sleep_fn = sleep_fn
    )
    input$resources$status <- captured$payload
    input$source_urls[["status"]] <- captured$source_url %||% status_url
    input$raw_bytes_by_resource$status <- captured$raw_bytes
    input$status_provenance <- "explicit"
    input$status_contributors <- "status"
  }
  phase13_acquire_finalize_input(input, edition_id)
}


phase13_acquire_read_fallback <- function(path) {
  metadata <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  if (!identical(phase13_acquire_value(metadata$fallback_status, "fallback_status"), "reviewed_fallback")) {
    stop("Phase 13 fallback metadata must declare reviewed_fallback", call. = FALSE)
  }
  if (!identical(phase13_acquire_value(metadata$review_state, "review_state"), "approved")) {
    stop("Phase 13 fallback metadata must be approved before publication", call. = FALSE)
  }
  metadata
}

phase13_acquire_candidate <- function(options, edition_id, project_root = phase13_acquire_project_root) {
  fallback <- !is.null(options[["fallback-file"]])
  input <- if (!is.null(options[["fixture-dir"]])) {
    phase13_acquire_fixture_input(options[["fixture-dir"]], edition_id, options[["fixture-file"]])
  } else {
    phase13_acquire_live_input(options, edition_id)
  }
  input <- phase13_acquire_finalize_input(input, edition_id)
  if (!identical(as.character(input$edition_id), edition_id)) {
    stop("Phase 13 input edition does not match --edition-id", call. = FALSE)
  }
  bundle_id <- if (!is.null(options[["bundle-id"]])) {
    phase13_source_scalar(options[["bundle-id"]], "bundle_id")
  } else {
    phase13_acquire_default_bundle_id(edition_id, fallback)
  }
  capture_args <- list(
    resource_payloads = input$resources,
    edition_id = edition_id,
    bundle_id = bundle_id,
    source_urls = input$source_urls,
    retrieved_at_utc = input$retrieved_at_utc,
    fallback_status = if (fallback) "reviewed_fallback" else "official",
    parser_commit_sha = phase13_parser_commit_sha(project_root),
    project_root = project_root,
    raw_bytes_by_resource = input$raw_bytes_by_resource
  )
  if (fallback) {
    metadata <- phase13_acquire_read_fallback(phase13_acquire_resolve_path(options[["fallback-file"]], project_root))
    checksum <- phase13_acquire_value(metadata$fallback_checksum, "fallback_checksum")
    if (!nzchar(checksum)) checksum <- phase13_source_sha256(phase13_acquire_value(metadata$operator_note, "operator_note"))
    capture_args <- c(capture_args, list(
      acceptance_state = "reviewed",
      fallback_source = phase13_acquire_value(metadata$fallback_source, "fallback_source"),
      fallback_retrieval_date = phase13_acquire_value(metadata$fallback_retrieval_date, "fallback_retrieval_date"),
      fallback_reason = phase13_acquire_value(metadata$fallback_reason, "fallback_reason"),
      operator_note = phase13_acquire_value(metadata$operator_note, "operator_note"),
      fallback_checksum = checksum
    ))
  }
  candidate <- do.call(phase13_capture_structured_bundle, capture_args)
  phase13_acquire_enrich_candidate(
    candidate,
    source_urls = input$source_urls,
    status_provenance = input$status_provenance %||% "explicit",
    status_contributors = input$status_contributors %||% "status"
  )
}

phase13_acquire_csv_bytes <- function(data) {
  if (!is.data.frame(data)) stop("Phase 13 canonical CSV hashing requires a data frame", call. = FALSE)
  path <- tempfile("phase13-canonical-content-", fileext = ".csv")
  on.exit(if (file.exists(path)) unlink(path), add = TRUE)
  utils::write.csv(data, path, row.names = FALSE, na = "", quote = TRUE)
  readBin(path, what = "raw", n = file.info(path)$size)
}

phase13_acquire_canonical_content_sha256 <- function(data) {
  phase13_source_sha256(phase13_acquire_csv_bytes(data))
}

phase13_acquire_csv_roundtrip <- function(data) {
  if (!is.data.frame(data)) stop("Phase 13 CSV round-trip requires a data frame", call. = FALSE)
  path <- tempfile("phase13-csv-roundtrip-", fileext = ".csv")
  on.exit(if (file.exists(path)) unlink(path), add = TRUE)
  utils::write.csv(data, path, row.names = FALSE, na = "", quote = TRUE)
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
}

phase13_acquire_file_sha256 <- function(path) {
  if (!file.exists(path)) return("")
  phase13_source_sha256(readBin(path, what = "raw", n = file.info(path)$size))
}

phase13_acquire_source_manifest_table <- function(bundle, artifacts) {
  phase13_validate_source_bundle(bundle, artifacts)
  bundle_fields <- c(
    "schema_version", "bundle_id", "edition_id", "bundle_status", "acceptance_state",
    "fallback_status", "parser_commit_sha", "artifact_count", "required_resource_count",
    "source_bundle_sha256", "artifact_manifest_sha256", "canonical_content_sha256",
    "manifest_self_sha256", "accepted_at_utc", "last_accepted_bundle_id",
    "fallback_source", "fallback_retrieval_date", "fallback_reason", "operator_note",
    "fallback_checksum"
  )
  artifact_fields <- c(
    "artifact_id", "artifact_type", "source_artifact_id", "source_url", "source_url_lineage",
    "retrieved_at_utc", "bytes", "raw_sha256", "canonical_content_sha256",
    "parser_commit_sha", "fallback_status", "review_state", "relative_local_raw_path",
    "status_provenance", "row_sha256"
  )
  phase13_source_require_columns(bundle, bundle_fields, "Phase 13 accepted source manifest bundle")
  phase13_source_require_columns(artifacts, artifact_fields, "Phase 13 accepted source manifest artifacts")
  manifest <- cbind(
    bundle[rep(1L, nrow(artifacts)), bundle_fields, drop = FALSE],
    artifacts[, artifact_fields, drop = FALSE]
  )
  manifest$row_sha256 <- phase13_row_sha256(manifest)
  manifest
}

phase13_acquire_validate_candidate_raw_bytes <- function(candidate) {
  required <- phase13_source_required_resource_types()
  phase13_source_require_columns(
    candidate$artifacts,
    c("artifact_id", "artifact_type", "canonical_content_sha256", "source_artifact_id"),
    "Phase 13 accepted source artifacts"
  )
  if (!is.list(candidate$raw_bytes_by_resource) || is.null(names(candidate$raw_bytes_by_resource)) ||
      !setequal(names(candidate$raw_bytes_by_resource), required)) {
    stop("Phase 13 accepted publication requires raw bytes for every resource class", call. = FALSE)
  }
  artifact_indexes <- match(required, as.character(candidate$artifacts$artifact_type))
  raw_bytes_by_artifact <- setNames(
    lapply(required, function(artifact_type) candidate$raw_bytes_by_resource[[artifact_type]]),
    as.character(candidate$artifacts$artifact_id[artifact_indexes])
  )
  if (any(is.na(names(raw_bytes_by_artifact))) || any(!nzchar(names(raw_bytes_by_artifact)))) {
    stop("Phase 13 accepted publication raw bytes are not linked to every artifact", call. = FALSE)
  }
  phase13_validate_source_artifacts(candidate$artifacts, raw_bytes_by_artifact)
  if (any(is.na(candidate$artifacts$source_artifact_id) |
          !nzchar(as.character(candidate$artifacts$source_artifact_id)))) {
    stop("Phase 13 accepted source artifacts require source_artifact_id lineage", call. = FALSE)
  }
  if (any(is.na(candidate$artifacts$canonical_content_sha256) |
          !grepl("^[0-9a-fA-F]{64}$", as.character(candidate$artifacts$canonical_content_sha256)))) {
    stop("Phase 13 accepted source artifacts require canonical content hashes", call. = FALSE)
  }
  invisible(raw_bytes_by_artifact)
}

phase13_acquire_validate_raw_store <- function(candidate, raw_root, edition_id) {
  if (is.null(raw_root)) return(invisible(TRUE))
  raw_edition_dir <- file.path(raw_root, edition_id)
  if (!dir.exists(raw_edition_dir)) return(invisible(TRUE))
  raw_dir <- file.path(raw_edition_dir, as.character(candidate$bundle$bundle_id[[1L]]))
  if (!dir.exists(raw_dir)) {
    stop("Phase 13 accepted publication raw-byte bundle is missing: ", raw_dir, call. = FALSE)
  }
  required <- phase13_source_required_resource_types()
  actual_files <- list.files(raw_dir, all.files = FALSE, full.names = FALSE)
  expected_files <- paste0(required, ".json")
  if (!setequal(actual_files, expected_files)) {
    stop("Phase 13 accepted publication raw-byte bundle has an incomplete resource set", call. = FALSE)
  }
  for (artifact_type in required) {
    artifact <- candidate$artifacts[candidate$artifacts$artifact_type == artifact_type, , drop = FALSE]
    path <- file.path(raw_dir, paste0(artifact_type, ".json"))
    bytes <- readBin(path, what = "raw", n = file.info(path)$size)
    if (nrow(artifact) != 1L || length(bytes) != as.integer(artifact$bytes[[1L]]) ||
        !identical(tolower(phase13_source_sha256(bytes)), tolower(as.character(artifact$raw_sha256[[1L]])))) {
      stop("Phase 13 accepted publication raw-byte bundle failed exact verification: ", artifact_type, call. = FALSE)
    }
  }
  invisible(TRUE)
}

phase13_acquire_validate_manifest <- function(actual, expected) {
  if (!is.data.frame(actual) || !identical(names(actual), names(expected)) || nrow(actual) != nrow(expected)) {
    stop("Phase 13 accepted source manifest schema or row count does not match the candidate", call. = FALSE)
  }
  for (column in names(expected)) {
    actual_values <- unname(vapply(actual[[column]], phase13_source_canonical_scalar, character(1)))
    expected_values <- unname(vapply(expected[[column]], phase13_source_canonical_scalar, character(1)))
    if (!identical(actual_values, expected_values)) {
      stop("Phase 13 accepted source manifest provenance or hash mismatch: ", column, call. = FALSE)
    }
  }
  invisible(TRUE)
}

phase13_acquire_validate_accepted_directory <- function(path, candidate, edition_id) {
  if (!dir.exists(path)) stop("Phase 13 accepted publication directory is missing", call. = FALSE)
  required <- phase13_source_required_resource_types()
  expected_files <- paste0(c("source_bundle_manifest", required), ".csv")
  actual_files <- list.files(path, all.files = FALSE, full.names = FALSE)
  if (!setequal(actual_files, expected_files)) {
    stop("Phase 13 accepted publication must contain exactly one manifest and five resource tables", call. = FALSE)
  }
  manifest_path <- file.path(path, "source_bundle_manifest.csv")
  manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  expected_manifest <- phase13_acquire_source_manifest_table(candidate$bundle, candidate$artifacts)
  phase13_acquire_validate_manifest(manifest, expected_manifest)
  for (artifact_type in required) {
    artifact <- candidate$artifacts[candidate$artifacts$artifact_type == artifact_type, , drop = FALSE]
    if (nrow(artifact) != 1L) stop("Phase 13 accepted publication has an incomplete artifact manifest", call. = FALSE)
    table_path <- file.path(path, paste0(artifact_type, ".csv"))
    table <- utils::read.csv(table_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
    expected_table <- if (!is.null(candidate$accepted_tables)) {
      candidate$accepted_tables[[artifact_type]]
    } else {
      phase13_acquire_resource_table(
        candidate$resources[[artifact_type]],
        artifact_type,
        edition_id,
        as.character(artifact$source_artifact_id[[1L]])
      )
    }
    expected_columns <- names(expected_table)
    if (!identical(names(table), expected_columns)) {
      stop("Phase 13 accepted resource schema mismatch: ", artifact_type, call. = FALSE)
    }
    phase13_source_validate_hash_column(table, "row_sha256", paste("Phase 13 accepted", artifact_type))
    if (any(as.character(table$edition_id) != edition_id) ||
        any(as.character(table$source_artifact_id) != as.character(artifact$source_artifact_id[[1L]]))) {
      stop("Phase 13 accepted resource foreign-key mismatch: ", artifact_type, call. = FALSE)
    }
    actual_hash <- phase13_acquire_file_sha256(table_path)
    if (!identical(tolower(actual_hash), tolower(as.character(artifact$canonical_content_sha256[[1L]])))) {
      stop("Phase 13 accepted resource canonical content hash mismatch: ", artifact_type, call. = FALSE)
    }
  }
  invisible(path)
}

phase13_acquire_resource_table <- function(payload, artifact_type, edition_id, artifact_id) {
  table <- phase13_source_resource_table(payload, artifact_type, edition_id, artifact_id)
  table <- cbind(
    schema_version = rep(paste0("phase13-", artifact_type, "-v1"), nrow(table)),
    table
  )
  table$row_sha256 <- phase13_row_sha256(table)
  table
}

phase13_acquire_accepted_tables <- function(candidate, edition_context) {
  required <- phase13_source_required_resource_types()
  artifact_ids <- setNames(
    as.character(candidate$artifacts$source_artifact_id),
    as.character(candidate$artifacts$artifact_type)
  )
  accepted <- setNames(vector("list", length(required)), required)
  for (artifact_type in required) {
    if (is.null(artifact_ids[[artifact_type]]) || !nzchar(artifact_ids[[artifact_type]])) {
      stop("Phase 13 accepted publication is missing source artifact lineage: ", artifact_type, call. = FALSE)
    }
    accepted[[artifact_type]] <- phase13_acquire_resource_table(
      candidate$resources[[artifact_type]],
      artifact_type,
      edition_context$edition_id,
      artifact_ids[[artifact_type]]
    )
  }

  source_fixture_table <- phase13_source_resource_table(
    candidate$resources$fixtures,
    "fixtures",
    edition_context$edition_id,
    artifact_ids[["fixtures"]]
  )
  accepted$fixtures <- phase13_normalize_fixture_rows(
    source_fixture_table,
    identity_map = edition_context$identity_registry,
    edition_id = edition_context$edition_id,
    source_artifact_id = artifact_ids[["fixtures"]],
    lifecycle_state = edition_context$lifecycle_state
  )
  source_result_table <- phase13_source_resource_table(
    candidate$resources$results,
    "results",
    edition_context$edition_id,
    artifact_ids[["results"]]
  )
  accepted$results <- phase13_normalize_accepted_result_rows(
    source_result_table,
    normalized_fixtures = accepted$fixtures,
    edition_id = edition_context$edition_id,
    source_artifact_id = artifact_ids[["results"]],
    lifecycle_state = edition_context$lifecycle_state
  )
  accepted
}

phase13_acquire_rebuild_accepted_candidate <- function(candidate, accepted_tables) {
  required <- phase13_source_required_resource_types()
  if (!is.list(accepted_tables) || !setequal(names(accepted_tables), required)) {
    stop("Phase 13 accepted publication requires all five normalized resource tables", call. = FALSE)
  }
  artifacts <- candidate$artifacts
  canonical_hashes <- character(nrow(artifacts))
  for (index in seq_len(nrow(artifacts))) {
    artifact_type <- as.character(artifacts$artifact_type[[index]])
    table <- accepted_tables[[artifact_type]]
    if (!is.data.frame(table)) stop("Phase 13 accepted resource table is not a data frame: ", artifact_type, call. = FALSE)
    phase13_source_validate_hash_column(table, "row_sha256", paste("Phase 13 accepted", artifact_type))
    canonical_hashes[[index]] <- phase13_acquire_canonical_content_sha256(table)
  }
  artifacts$canonical_content_sha256 <- canonical_hashes
  artifacts$row_sha256 <- phase13_row_sha256(artifacts)

  bundle <- phase13_acquire_rebuild_bundle_row(candidate$bundle, artifacts)
  bundle$canonical_content_sha256 <- phase13_acquire_canonical_content_sha256(
    phase13_acquire_csv_roundtrip(phase13_acquire_bundle_content_table(bundle, artifacts))
  )
  bundle <- phase13_acquire_rebuild_bundle_row(bundle, artifacts)
  phase13_validate_source_bundle(bundle, artifacts)
  candidate$bundle <- bundle
  candidate$artifacts <- artifacts
  candidate$accepted_tables <- accepted_tables
  candidate$manifest <- phase13_acquire_source_manifest_table(bundle, artifacts)
  candidate
}

phase13_acquire_bundle_content_table <- function(bundle, artifacts) {
  bundle_fields <- setdiff(names(bundle), c("canonical_content_sha256", "manifest_self_sha256", "row_sha256"))
  artifact_fields <- setdiff(names(artifacts), c("canonical_content_sha256", "row_sha256"))
  cbind(
    bundle[rep(1L, nrow(artifacts)), bundle_fields, drop = FALSE],
    artifacts[, artifact_fields, drop = FALSE]
  )
}

phase13_acquire_rebuild_bundle_row <- function(bundle, artifacts) {
  bundle <- bundle[1L, , drop = FALSE]
  artifact_hash <- phase13_canonical_sha256(artifacts, key = "artifact_id")
  bundle$source_bundle_sha256 <- artifact_hash
  bundle$artifact_manifest_sha256 <- artifact_hash
  bundle$artifact_count <- as.integer(nrow(artifacts))
  bundle$required_resource_count <- as.integer(length(phase13_source_required_resource_types()))
  if (!"canonical_content_sha256" %in% names(bundle)) bundle$canonical_content_sha256 <- ""
  bundle$manifest_self_sha256 <- ""
  bundle$manifest_self_sha256 <- phase13_source_manifest_self_sha256(bundle, artifacts)
  bundle$row_sha256 <- phase13_row_sha256(bundle)
  bundle
}

phase13_acquire_enrich_candidate <- function(
    candidate,
    source_urls,
    status_provenance,
    status_contributors) {
  artifacts <- candidate$artifacts
  source_artifact_links <- character(nrow(artifacts))
  source_url_lineage <- character(nrow(artifacts))
  artifact_status_provenance <- rep("not_applicable", nrow(artifacts))
  canonical_hashes <- character(nrow(artifacts))
  for (index in seq_len(nrow(artifacts))) {
    artifact_type <- as.character(artifacts$artifact_type[[index]])
    artifact_id <- as.character(artifacts$artifact_id[[index]])
    source_artifact_links[[index]] <- artifact_id
    source_url_lineage[[index]] <- as.character(source_urls[[artifact_type]])
    if (identical(artifact_type, "status")) {
      if (identical(status_provenance, "derived")) {
        contributors <- sort(unique(as.character(status_contributors)))
        source_artifact_links[[index]] <- paste(
          sort(paste0(candidate$bundle$bundle_id[[1L]], "-", contributors)),
          collapse = "|"
        )
        artifact_status_provenance[[index]] <- "derived"
      } else {
        artifact_status_provenance[[index]] <- "explicit"
      }
      source_url_lineage[[index]] <- as.character(source_urls[["status"]])
    }
    table_source_artifact_id <- source_artifact_links[[index]]
    canonical_hashes[[index]] <- phase13_acquire_canonical_content_sha256(
      phase13_acquire_resource_table(
        candidate$resources[[artifact_type]],
        artifact_type,
        candidate$bundle$edition_id[[1L]],
        table_source_artifact_id
      )
    )
  }
  artifacts$source_artifact_id <- source_artifact_links
  artifacts$source_url_lineage <- source_url_lineage
  artifacts$status_provenance <- artifact_status_provenance
  artifacts$canonical_content_sha256 <- canonical_hashes
  artifacts$row_sha256 <- phase13_row_sha256(artifacts)

  bundle <- phase13_acquire_rebuild_bundle_row(candidate$bundle, artifacts)
  bundle$canonical_content_sha256 <- phase13_acquire_canonical_content_sha256(
    phase13_acquire_bundle_content_table(bundle, artifacts)
  )
  bundle <- phase13_acquire_rebuild_bundle_row(bundle, artifacts)
  phase13_validate_source_bundle(bundle, artifacts)
  candidate$bundle <- bundle
  candidate$artifacts <- artifacts
  candidate$manifest <- phase13_acquire_source_manifest_table(bundle, artifacts)
  candidate
}

phase13_acquire_write_raw_store <- function(candidate, raw_root, edition_id, bundle_id) {
  edition_dir <- file.path(raw_root, edition_id)
  dir.create(edition_dir, recursive = TRUE, showWarnings = FALSE)
  staged_dir <- tempfile(paste0(".", bundle_id, "-raw-"), tmpdir = edition_dir)
  dir.create(staged_dir, recursive = TRUE, showWarnings = FALSE)
  target_dir <- file.path(edition_dir, bundle_id)
  backup_dir <- NULL
  promoted <- FALSE
  rollback <- function() {
    if (promoted && dir.exists(target_dir)) unlink(target_dir, recursive = TRUE)
    if (!is.null(backup_dir) && dir.exists(backup_dir) && !dir.exists(target_dir)) {
      file.rename(backup_dir, target_dir)
    }
  }
  on.exit({
    if (!promoted) rollback()
    if (dir.exists(staged_dir)) unlink(staged_dir, recursive = TRUE)
    if (!is.null(backup_dir) && dir.exists(backup_dir)) unlink(backup_dir, recursive = TRUE)
  }, add = TRUE)

  for (artifact_type in phase13_source_required_resource_types()) {
    raw_bytes <- candidate$raw_bytes_by_resource[[artifact_type]]
    target <- file.path(staged_dir, paste0(artifact_type, ".json"))
    writeBin(phase13_source_raw_bytes(raw_bytes), target)
    artifact <- candidate$artifacts[candidate$artifacts$artifact_type == artifact_type, , drop = FALSE]
    actual_bytes <- readBin(target, what = "raw", n = file.info(target)$size)
    if (nrow(artifact) != 1L || file.info(target)$size != artifact$bytes[[1L]] || phase13_source_sha256(actual_bytes) != artifact$raw_sha256[[1L]]) {
      stop("Phase 13 retained raw response failed exact-byte verification: ", artifact_type, call. = FALSE)
    }
  }
  if (dir.exists(target_dir)) {
    backup_dir <- tempfile(paste0(".", bundle_id, "-previous-"), tmpdir = edition_dir)
    if (!file.rename(target_dir, backup_dir)) stop("Could not stage the previous Phase 13 raw response", call. = FALSE)
  }
  if (!file.rename(staged_dir, target_dir)) stop("Could not retain Phase 13 raw response bundle", call. = FALSE)
  promoted <- TRUE
  if (!is.null(backup_dir) && dir.exists(backup_dir)) unlink(backup_dir, recursive = TRUE)
  on.exit(NULL, add = TRUE)
  normalizePath(target_dir, winslash = "/", mustWork = TRUE)
}

phase13_acquire_write_resource_table <- function(
    payload, artifact_type, edition_id, artifact_id, path, source_artifact_id = artifact_id,
    table_override = NULL) {
  table <- if (is.null(table_override)) {
    phase13_acquire_resource_table(payload, artifact_type, edition_id, source_artifact_id)
  } else {
    if (!is.data.frame(table_override)) stop("Phase 13 accepted resource override must be a data frame", call. = FALSE)
    table_override
  }
  phase13_source_write_csv(table, path)
  table
}

phase13_acquire_publish_accepted <- function(
    candidate,
    output_root,
    edition_id,
    raw_root,
    registry_root = NULL,
    registry_context_root = NULL) {
  edition_id <- phase13_source_safe_relative_path(edition_id)
  if (!is.data.frame(candidate$bundle) || !is.data.frame(candidate$artifacts) ||
      !is.data.frame(candidate$manifest) || !is.list(candidate$resources)) {
    stop("Phase 13 accepted publication requires a complete candidate contract", call. = FALSE)
  }
  if (nrow(candidate$bundle) != 1L || !identical(as.character(candidate$bundle$edition_id[[1L]]), edition_id)) {
    stop("Phase 13 accepted publication candidate edition does not match the target", call. = FALSE)
  }
  phase13_validate_source_bundle(candidate$bundle, candidate$artifacts)
  phase13_acquire_validate_candidate_raw_bytes(candidate)
  original_manifest <- phase13_acquire_source_manifest_table(candidate$bundle, candidate$artifacts)
  phase13_acquire_validate_manifest(candidate$manifest, original_manifest)
  if (is.null(registry_context_root)) {
    candidate_registry_root <- if (!is.null(registry_root)) {
      phase13_acquire_resolve_path(registry_root)
    } else {
      ""
    }
    has_candidate_context <- nzchar(candidate_registry_root) &&
      file.exists(file.path(candidate_registry_root, "team_identity.csv")) &&
      file.exists(file.path(candidate_registry_root, "competition_editions.csv"))
    registry_context_root <- if (has_candidate_context) {
      candidate_registry_root
    } else {
      file.path(phase13_acquire_project_root, "data/competition/registries")
    }
  }
  edition_context <- phase13_acquire_load_edition_context(
    edition_id,
    registry_root = registry_context_root,
    project_root = phase13_acquire_project_root
  )
  candidate <- phase13_acquire_rebuild_accepted_candidate(
    candidate,
    phase13_acquire_accepted_tables(candidate, edition_context)
  )
  phase13_validate_source_bundle(candidate$bundle, candidate$artifacts)
  phase13_acquire_validate_candidate_raw_bytes(candidate)
  phase13_acquire_validate_raw_store(candidate, raw_root, edition_id)
  expected_manifest <- phase13_acquire_source_manifest_table(candidate$bundle, candidate$artifacts)
  phase13_acquire_validate_manifest(candidate$manifest, expected_manifest)

  dir.create(output_root, recursive = TRUE, showWarnings = FALSE)
  output_root <- normalizePath(output_root, winslash = "/", mustWork = TRUE)
  target <- file.path(output_root, edition_id)
  if (!phase13_source_path_within(target, output_root)) {
    stop("Phase 13 accepted publication target escapes the accepted output root", call. = FALSE)
  }
  if (!is.null(registry_root)) {
    registry_root <- normalizePath(registry_root, winslash = "/", mustWork = FALSE)
    refresh_root <- file.path(registry_root, "refresh_batches")
    if (phase13_source_path_within(target, refresh_root) || phase13_source_path_within(refresh_root, target)) {
      stop("Phase 13 accepted publication target must remain separate from registry refresh batches", call. = FALSE)
    }
  }

  staged <- tempfile(paste0(".", edition_id, "-candidate-"), tmpdir = output_root)
  dir.create(staged, recursive = TRUE, showWarnings = FALSE)
  backup <- NULL
  promoted <- FALSE
  success <- FALSE
  rollback <- function() {
    if (promoted && (dir.exists(target) || file.exists(target))) unlink(target, recursive = TRUE, force = TRUE)
    if (!is.null(backup) && dir.exists(backup) && !dir.exists(target) && !file.exists(target)) {
      if (!file.rename(backup, target)) stop("Could not restore the previous Phase 13 accepted output", call. = FALSE)
    }
  }
  on.exit({
    if (!success) rollback()
    if (dir.exists(staged)) unlink(staged, recursive = TRUE, force = TRUE)
    if (!is.null(backup) && dir.exists(backup)) unlink(backup, recursive = TRUE, force = TRUE)
  }, add = TRUE)

  phase13_source_write_csv(expected_manifest, file.path(staged, "source_bundle_manifest.csv"))
  for (artifact_type in phase13_source_required_resource_types()) {
    artifact <- candidate$artifacts[candidate$artifacts$artifact_type == artifact_type, , drop = FALSE]
    if (nrow(artifact) != 1L) stop("Phase 13 accepted publication requires one artifact per resource class", call. = FALSE)
    phase13_acquire_write_resource_table(
      candidate$resources[[artifact_type]], artifact_type, edition_id,
      as.character(artifact$artifact_id[[1L]]),
      file.path(staged, paste0(artifact_type, ".csv")),
      source_artifact_id = as.character(artifact$source_artifact_id[[1L]]),
      table_override = candidate$accepted_tables[[artifact_type]]
    )
  }
  phase13_acquire_validate_accepted_directory(staged, candidate, edition_id)

  if (file.exists(target) && !dir.exists(target)) {
    stop("Could not replace a non-directory Phase 13 accepted output", call. = FALSE)
  }
  if (dir.exists(target)) {
    backup <- tempfile(paste0(".", edition_id, "-previous-"), tmpdir = output_root)
    if (!file.rename(target, backup)) stop("Could not stage the last accepted Phase 13 output", call. = FALSE)
  }
  if (!file.rename(staged, target)) stop("Could not publish Phase 13 accepted output", call. = FALSE)
  promoted <- TRUE
  phase13_acquire_validate_accepted_directory(target, candidate, edition_id)
  success <- TRUE
  candidate$accepted_path <- normalizePath(target, winslash = "/", mustWork = TRUE)
  candidate
}

phase13_acquire_publication_read_csv <- function(path, label) {
  if (!file.exists(path) || dir.exists(path)) {
    stop("Phase 13 normalized publication ", label, " is missing: ", path, call. = FALSE)
  }
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
}

phase13_acquire_publication_validate_source_manifest <- function(
    manifest,
    bundle,
    artifacts,
    edition_id,
    accepted_dir) {
  expected_schema <- phase13_publication_manifest_schema()
  if (!is.data.frame(manifest) || !identical(names(manifest), expected_schema) || nrow(manifest) != 5L) {
    stop("Phase 13 normalized publication source handoff manifest is incomplete for ", edition_id, call. = FALSE)
  }
  if (any(as.character(manifest$edition_id) != edition_id) ||
      length(unique(as.character(manifest$bundle_id))) != 1L ||
      !identical(as.character(manifest$bundle_id[[1L]]), as.character(bundle$bundle_id[[1L]]))) {
    stop("Phase 13 normalized publication source handoff manifest has forged edition or bundle links: ", edition_id, call. = FALSE)
  }
  if (!setequal(as.character(manifest$artifact_type), phase13_source_required_resource_types()) ||
      anyDuplicated(as.character(manifest$artifact_type))) {
    stop("Phase 13 normalized publication source handoff manifest has an incomplete resource graph: ", edition_id, call. = FALSE)
  }
  canonical_columns <- which(names(manifest) == "canonical_content_sha256")
  if (length(canonical_columns) != 2L) {
    stop("Phase 13 normalized publication source handoff manifest has an ambiguous canonical hash projection: ", edition_id, call. = FALSE)
  }
  compare_columns <- c(
    "artifact_id", "artifact_type", "source_artifact_id", "source_url",
    "source_url_lineage", "fallback_status", "review_state",
    "relative_local_raw_path", "status_provenance"
  )
  for (artifact_type in phase13_source_required_resource_types()) {
    manifest_row <- manifest[as.character(manifest$artifact_type) == artifact_type, , drop = FALSE]
    artifact_row <- artifacts[as.character(artifacts$artifact_type) == artifact_type, , drop = FALSE]
    if (nrow(manifest_row) != 1L || nrow(artifact_row) != 1L) {
      stop("Phase 13 normalized publication source handoff manifest link is missing: ", edition_id, "/", artifact_type, call. = FALSE)
    }
    for (column in compare_columns) {
      manifest_value <- phase13_source_canonical_scalar(manifest_row[[column]][[1L]])
      artifact_value <- phase13_source_canonical_scalar(artifact_row[[column]][[1L]])
      if (!identical(manifest_value, artifact_value)) {
        stop("Phase 13 normalized publication source handoff manifest has stale source link: ", edition_id, "/", artifact_type, call. = FALSE)
      }
    }
    manifest_canonical <- phase13_source_canonical_scalar(manifest_row[[canonical_columns[[2L]]]][[1L]])
    artifact_canonical <- phase13_source_canonical_scalar(artifact_row$canonical_content_sha256[[1L]])
    if (!identical(manifest_canonical, artifact_canonical)) {
      manifest_retrieved <- phase13_source_canonical_scalar(manifest_row$retrieved_at_utc[[1L]])
      artifact_retrieved <- phase13_source_canonical_scalar(artifact_row$retrieved_at_utc[[1L]])
      if (!nzchar(manifest_retrieved) || !nzchar(artifact_retrieved) || manifest_retrieved <= artifact_retrieved) {
        stop("Phase 13 normalized publication source handoff manifest has stale canonical hash: ", edition_id, "/", artifact_type, call. = FALSE)
      }
    }
    for (column in c("bytes", "raw_sha256")) {
      manifest_value <- phase13_source_canonical_scalar(manifest_row[[column]][[1L]])
      artifact_value <- phase13_source_canonical_scalar(artifact_row[[column]][[1L]])
      if (!identical(manifest_value, artifact_value)) {
        manifest_retrieved <- phase13_source_canonical_scalar(manifest_row$retrieved_at_utc[[1L]])
        artifact_retrieved <- phase13_source_canonical_scalar(artifact_row$retrieved_at_utc[[1L]])
        if (!nzchar(manifest_retrieved) || !nzchar(artifact_retrieved) || manifest_retrieved <= artifact_retrieved) {
          stop("Phase 13 normalized publication source handoff manifest has stale raw provenance: ", edition_id, "/", artifact_type, call. = FALSE)
        }
      }
    }
    source_table_path <- file.path(
      accepted_dir,
      paste0(artifact_type, ".csv")
    )
    if (!identical(
      tolower(manifest_canonical),
      tolower(phase13_acquire_file_sha256(source_table_path))
    )) {
      stop("Phase 13 normalized publication source handoff manifest canonical bytes are stale: ", edition_id, "/", artifact_type, call. = FALSE)
    }
  }
  invisible(manifest)
}

phase13_acquire_publication_validate_source_table <- function(
    table,
    edition_id,
    artifact_type,
    artifact) {
  compact_schema <- phase13_source_compact_resource_schema()[[artifact_type]]
  expected_schema <- c(
    "schema_version", compact_schema, "edition_id", "source_artifact_id", "row_sha256"
  )
  if (!is.data.frame(table) || !identical(names(table), expected_schema)) {
    stop("Phase 13 normalized publication source handoff schema mismatch: ", edition_id, "/", artifact_type, call. = FALSE)
  }
  phase13_source_validate_hash_column(
    table,
    "row_sha256",
    paste("Phase 13 normalized publication source handoff", edition_id, artifact_type)
  )
  if (nrow(table)) {
    if (any(as.character(table$edition_id) != edition_id) ||
        any(as.character(table$source_artifact_id) != as.character(artifact$source_artifact_id[[1L]]))) {
      stop("Phase 13 normalized publication source handoff has a forged source-artifact link: ", edition_id, "/", artifact_type, call. = FALSE)
    }
  }
  invisible(table)
}

phase13_acquire_publication_validate_source_handoff <- function(
    accepted_root,
    registry_root,
    edition_id) {
  artifacts <- phase13_acquire_publication_read_csv(
    file.path(registry_root, "source_artifacts.csv"),
    "source artifact registry"
  )
  bundles <- phase13_acquire_publication_read_csv(
    file.path(registry_root, "source_bundles.csv"),
    "source bundle registry"
  )
  phase13_validate_source_artifacts(artifacts)
  artifact_rows <- artifacts[as.character(artifacts$edition_id) == edition_id, , drop = FALSE]
  bundle_rows <- bundles[as.character(bundles$edition_id) == edition_id, , drop = FALSE]
  if (nrow(artifact_rows) != length(phase13_source_required_resource_types()) ||
      nrow(bundle_rows) != 1L) {
    stop("Phase 13 normalized publication source handoff registry is incomplete for ", edition_id, call. = FALSE)
  }
  bundle <- bundle_rows[1L, , drop = FALSE]
  phase13_validate_source_bundle(bundle, artifact_rows)

  accepted_dir <- file.path(accepted_root, edition_id)
  expected_files <- paste0(c("source_bundle_manifest", phase13_source_required_resource_types()), ".csv")
  actual_files <- list.files(accepted_dir, all.files = FALSE, full.names = FALSE)
  if (!dir.exists(accepted_dir) || !setequal(actual_files, expected_files)) {
    stop("Phase 13 normalized publication source handoff must contain exactly one manifest and five tables: ", edition_id, call. = FALSE)
  }
  manifest <- phase13_acquire_publication_read_csv(
    file.path(accepted_dir, "source_bundle_manifest.csv"),
    paste("source handoff manifest for", edition_id)
  )
  phase13_acquire_publication_validate_source_manifest(
    manifest,
    bundle,
    artifact_rows,
    edition_id,
    accepted_dir
  )

  tables <- setNames(vector("list", length(phase13_source_required_resource_types())), phase13_source_required_resource_types())
  for (artifact_type in phase13_source_required_resource_types()) {
    artifact <- artifact_rows[as.character(artifact_rows$artifact_type) == artifact_type, , drop = FALSE]
    if (nrow(artifact) != 1L) {
      stop("Phase 13 normalized publication source handoff has an incomplete artifact link: ", edition_id, "/", artifact_type, call. = FALSE)
    }
    table <- phase13_acquire_publication_read_csv(
      file.path(accepted_dir, paste0(artifact_type, ".csv")),
      paste("source handoff table for", edition_id, artifact_type)
    )
    phase13_acquire_publication_validate_source_table(table, edition_id, artifact_type, artifact)
    tables[[artifact_type]] <- table
  }
  list(
    edition_id = edition_id,
    bundle = bundle,
    artifacts = artifact_rows,
    manifest = manifest,
    tables = tables
  )
}

phase13_acquire_publication_validate_handoffs <- function(accepted_root, registry_root) {
  all_artifacts <- phase13_acquire_publication_read_csv(
    file.path(registry_root, "source_artifacts.csv"),
    "source artifact registry"
  )
  all_bundles <- phase13_acquire_publication_read_csv(
    file.path(registry_root, "source_bundles.csv"),
    "source bundle registry"
  )
  phase13_validate_source_artifacts(all_artifacts)
  if (nrow(all_artifacts) != 10L || nrow(all_bundles) != 2L) {
    stop("Phase 13 normalized publication requires exactly ten source artifacts and two source bundles", call. = FALSE)
  }
  handoffs <- lapply(
    phase13_publication_editions(),
    function(edition_id) phase13_acquire_publication_validate_source_handoff(accepted_root, registry_root, edition_id)
  )
  names(handoffs) <- phase13_publication_editions()
  list(artifacts = all_artifacts, bundles = all_bundles, handoffs = handoffs)
}

phase13_acquire_publication_assert_immutable_provenance <- function(before, after) {
  if (!is.data.frame(before) || !is.data.frame(after)) {
    stop("Phase 13 normalized publication provenance comparison requires registry tables", call. = FALSE)
  }
  key <- if ("artifact_id" %in% names(before)) "artifact_id" else "bundle_id"
  derived <- if (identical(key, "artifact_id")) {
    c("row_sha256", "canonical_content_sha256")
  } else {
    c(
      "source_bundle_sha256", "artifact_manifest_sha256", "canonical_content_sha256",
      "manifest_self_sha256", "row_sha256"
    )
  }
  compare <- setdiff(intersect(names(before), names(after)), derived)
  if (!length(compare) || !key %in% names(after)) {
    stop("Phase 13 normalized publication provenance comparison has an incomplete registry", call. = FALSE)
  }
  for (identifier in unique(as.character(before[[key]]))) {
    before_row <- before[as.character(before[[key]]) == identifier, , drop = FALSE]
    after_row <- after[as.character(after[[key]]) == identifier, , drop = FALSE]
    if (nrow(before_row) != 1L || nrow(after_row) != 1L) {
      stop("Phase 13 normalized publication changed registry identity cardinality: ", identifier, call. = FALSE)
    }
    for (column in compare) {
      before_value <- phase13_source_canonical_scalar(before_row[[column]][[1L]])
      after_value <- phase13_source_canonical_scalar(after_row[[column]][[1L]])
      if (!identical(before_value, after_value)) {
        stop("Phase 13 normalized publication changed immutable provenance: ", identifier, "/", column, call. = FALSE)
      }
    }
  }
  invisible(TRUE)
}

phase13_acquire_publication_stage_normalized_edition <- function(
    transaction,
    edition_id,
    registry_context_root,
    handoff) {
  staged_dir <- file.path(transaction$staging_root, "data/competition/accepted", edition_id)
  context <- phase13_acquire_load_edition_context(
    edition_id,
    registry_root = registry_context_root,
    project_root = phase13_acquire_project_root
  )
  fixture_artifact <- handoff$artifacts[
    as.character(handoff$artifacts$artifact_type) == "fixtures", , drop = FALSE
  ]
  result_artifact <- handoff$artifacts[
    as.character(handoff$artifacts$artifact_type) == "results", , drop = FALSE
  ]
  if (nrow(fixture_artifact) != 1L || nrow(result_artifact) != 1L) {
    stop("Phase 13 normalized publication requires fixture and result source artifacts: ", edition_id, call. = FALSE)
  }
  normalized_fixtures <- phase13_normalize_fixture_rows(
    handoff$tables$fixtures,
    identity_map = context$identity_registry,
    edition_id = edition_id,
    source_artifact_id = as.character(fixture_artifact$source_artifact_id[[1L]]),
    lifecycle_state = context$lifecycle_state
  )
  normalized_results <- phase13_normalize_accepted_result_rows(
    handoff$tables$results,
    normalized_fixtures = normalized_fixtures,
    edition_id = edition_id,
    source_artifact_id = as.character(result_artifact$source_artifact_id[[1L]]),
    lifecycle_state = context$lifecycle_state
  )
  phase13_publication_write_csv(normalized_fixtures, file.path(staged_dir, "fixtures.csv"))
  phase13_publication_write_csv(normalized_results, file.path(staged_dir, "results.csv"))
  invisible(list(
    edition_id = edition_id,
    lifecycle_state = context$lifecycle_state,
    fixtures = normalized_fixtures,
    results = normalized_results
  ))
}

phase13_acquire_publication_validate_normalized_graph <- function(
    staged_root,
    canonical_refresh,
    manifest_refresh,
    provenance_before) {
  table_targets <- phase13_normalized_resource_targets(staged_root)
  canonical_refresh <- phase13_publication_manifest_require_canonical(canonical_refresh, staged_root)
  if (!is.list(manifest_refresh) || !all(c("manifests", "source_bundles", "source_artifacts") %in% names(manifest_refresh))) {
    stop("Phase 13 normalized publication manifest refresh is incomplete", call. = FALSE)
  }
  artifacts <- phase13_publication_manifest_read_artifacts(staged_root, manifest_refresh$source_artifacts)
  bundles <- phase13_publication_manifest_read_bundles(staged_root, manifest_refresh$source_bundles)
  if (nrow(artifacts) != 10L || nrow(bundles) != 2L) {
    stop("Phase 13 normalized publication hash graph must contain ten artifacts and two bundles", call. = FALSE)
  }
  tables <- vector("list", length(table_targets))
  names(tables) <- names(table_targets)
  for (key in names(table_targets)) {
    parts <- strsplit(key, "::", fixed = TRUE)[[1L]]
    path <- table_targets[[key]]
    table <- phase13_acquire_publication_read_csv(path, paste("normalized table", key))
    phase13_publication_validate_table_shape(table, parts[[1L]], parts[[2L]], path)
    phase13_source_validate_hash_column(table, "row_sha256", paste("Phase 13 normalized table", key))
    artifact <- artifacts[
      as.character(artifacts$edition_id) == parts[[1L]] &
        as.character(artifacts$artifact_type) == parts[[2L]],
      , drop = FALSE
    ]
    if (nrow(artifact) != 1L || (!nrow(table) && !nzchar(as.character(artifact$source_artifact_id[[1L]])))) {
      stop("Phase 13 normalized publication table has an incomplete artifact graph: ", key, call. = FALSE)
    }
    if (nrow(table)) {
      links <- unique(as.character(table$source_artifact_id))
      if (length(links) != 1L || !identical(links[[1L]], as.character(artifact$source_artifact_id[[1L]]))) {
        stop("Phase 13 normalized publication table has a forged source-artifact link: ", key, call. = FALSE)
      }
    }
    actual_hash <- phase13_publication_file_sha256(path)
    if (!identical(tolower(actual_hash), tolower(as.character(artifact$canonical_content_sha256[[1L]])))) {
      stop("Phase 13 normalized publication table has a stale canonical hash: ", key, call. = FALSE)
    }
    tables[[key]] <- table
  }
  phase13_publication_validate_pre_draw(tables)
  for (edition_id in phase13_publication_editions()) {
    bundle <- bundles[as.character(bundles$edition_id) == edition_id, , drop = FALSE]
    edition_artifacts <- artifacts[as.character(artifacts$edition_id) == edition_id, , drop = FALSE]
    if (nrow(bundle) != 1L || nrow(edition_artifacts) != 5L) {
      stop("Phase 13 normalized publication bundle graph is incomplete: ", edition_id, call. = FALSE)
    }
    phase13_validate_source_bundle(bundle, edition_artifacts)
    manifest_path <- phase13_publication_manifest_paths(staged_root)[[edition_id]]
    manifest <- phase13_acquire_publication_read_csv(manifest_path, paste("normalized manifest", edition_id))
    phase13_publication_manifest_validate_rows(manifest, bundle, edition_artifacts)
  }
  phase13_acquire_publication_assert_immutable_provenance(
    provenance_before$artifacts,
    artifacts
  )
  phase13_acquire_publication_assert_immutable_provenance(
    provenance_before$bundles,
    bundles
  )
  list(
    table_targets = table_targets,
    tables = tables,
    source_artifacts = artifacts,
    source_bundles = bundles,
    manifests = manifest_refresh$manifests
  )
}

phase13_acquire_publication_candidate_handoff <- function(candidate, edition_id) {
  if (!is.list(candidate) || !is.data.frame(candidate$bundle) ||
      !is.data.frame(candidate$artifacts) || !is.list(candidate$resources)) {
    stop("Phase 13 normalized publication candidate is incomplete", call. = FALSE)
  }
  if (nrow(candidate$bundle) != 1L ||
      !identical(as.character(candidate$bundle$edition_id[[1L]]), edition_id)) {
    stop("Phase 13 normalized publication candidate edition does not match the target", call. = FALSE)
  }
  phase13_validate_source_bundle(candidate$bundle, candidate$artifacts)
  artifact_ids <- setNames(
    as.character(candidate$artifacts$source_artifact_id),
    as.character(candidate$artifacts$artifact_type)
  )
  required <- phase13_source_required_resource_types()
  if (!setequal(names(artifact_ids), required) || any(is.na(artifact_ids) | !nzchar(artifact_ids))) {
    stop("Phase 13 normalized publication candidate is missing source-artifact lineage", call. = FALSE)
  }
  tables <- setNames(vector("list", length(required)), required)
  for (artifact_type in required) {
    tables[[artifact_type]] <- phase13_acquire_resource_table(
      candidate$resources[[artifact_type]],
      artifact_type,
      edition_id,
      artifact_ids[[artifact_type]]
    )
  }
  manifest <- phase13_acquire_source_manifest_table(candidate$bundle, candidate$artifacts)
  list(
    edition_id = edition_id,
    bundle = candidate$bundle,
    artifacts = candidate$artifacts,
    manifest = manifest,
    tables = tables
  )
}

phase13_acquire_publication_merge_candidate_registry <- function(
    source_registries,
    candidate_handoff) {
  edition_id <- candidate_handoff$edition_id
  old_bundles <- source_registries$bundles[
    as.character(source_registries$bundles$edition_id) != edition_id,
    , drop = FALSE
  ]
  old_artifacts <- source_registries$artifacts[
    as.character(source_registries$artifacts$edition_id) != edition_id,
    , drop = FALSE
  ]
  bundle_columns <- unique(c(names(source_registries$bundles), names(candidate_handoff$bundle)))
  artifact_columns <- unique(c(names(source_registries$artifacts), names(candidate_handoff$artifacts)))
  old_bundles <- phase13_acquire_align_registry_columns(old_bundles, bundle_columns)
  candidate_bundle <- phase13_acquire_align_registry_columns(candidate_handoff$bundle, bundle_columns)
  old_artifacts <- phase13_acquire_align_registry_columns(old_artifacts, artifact_columns)
  candidate_artifacts <- phase13_acquire_align_registry_columns(candidate_handoff$artifacts, artifact_columns)
  bundles <- rbind(old_bundles, candidate_bundle)
  artifacts <- rbind(old_artifacts, candidate_artifacts)
  phase13_validate_source_artifacts(artifacts)
  for (edition in phase13_publication_editions()) {
    bundle <- bundles[as.character(bundles$edition_id) == edition, , drop = FALSE]
    edition_artifacts <- artifacts[as.character(artifacts$edition_id) == edition, , drop = FALSE]
    if (nrow(bundle) != 1L) stop("Phase 13 normalized publication candidate registry has a duplicate edition", call. = FALSE)
    phase13_validate_source_bundle(bundle, edition_artifacts)
  }
  list(bundles = bundles, artifacts = artifacts)
}

phase13_acquire_publication_stage_candidate_handoff <- function(transaction, candidate_handoff, registry_tables) {
  staged_registry <- file.path(transaction$staging_root, "data/competition/registries")
  staged_accepted <- file.path(
    transaction$staging_root,
    "data/competition/accepted",
    candidate_handoff$edition_id
  )
  phase13_publication_write_csv(
    registry_tables$artifacts,
    file.path(staged_registry, "source_artifacts.csv")
  )
  phase13_publication_write_csv(
    registry_tables$bundles,
    file.path(staged_registry, "source_bundles.csv")
  )
  phase13_publication_write_csv(
    candidate_handoff$manifest,
    file.path(staged_accepted, "source_bundle_manifest.csv")
  )
  for (artifact_type in phase13_source_required_resource_types()) {
    phase13_publication_write_csv(
      candidate_handoff$tables[[artifact_type]],
      file.path(staged_accepted, paste0(artifact_type, ".csv"))
    )
  }
  invisible(candidate_handoff)
}

phase13_acquire_normalized_publication_ready <- function(output_root, registry_root) {
  tryCatch({
    accepted_root <- normalizePath(output_root, winslash = "/", mustWork = TRUE)
    registry_root <- normalizePath(registry_root, winslash = "/", mustWork = TRUE)
    required_context <- file.path(registry_root, c("team_identity.csv", "competition_editions.csv"))
    all(file.exists(required_context)) &&
      all(file.exists(unname(phase13_normalized_publication_targets(accepted_root, registry_root))))
  }, error = function(error) FALSE)
}

#' Normalize and atomically publish both accepted edition handoffs.
phase13_publish_normalized_editions <- function(
    output_root = file.path(phase13_acquire_project_root, "data/competition/accepted"),
    registry_root = file.path(phase13_acquire_project_root, "data/competition/registries"),
    registry_context_root = registry_root,
    failure_injector = NULL,
    handoff_root = output_root,
    candidate = NULL) {
  accepted_root <- phase13_acquire_resolve_path(output_root)
  registry_root <- phase13_acquire_resolve_path(registry_root)
  registry_context_root <- phase13_acquire_resolve_path(registry_context_root)
  handoff_root <- phase13_acquire_resolve_path(handoff_root)
  if (!dir.exists(accepted_root) || !dir.exists(registry_root) || !dir.exists(handoff_root)) {
    stop("Phase 13 normalized publication requires accepted, registry, and handoff roots", call. = FALSE)
  }
  accepted_root <- normalizePath(accepted_root, winslash = "/", mustWork = TRUE)
  registry_root <- normalizePath(registry_root, winslash = "/", mustWork = TRUE)
  registry_context_root <- normalizePath(registry_context_root, winslash = "/", mustWork = TRUE)
  handoff_root <- normalizePath(handoff_root, winslash = "/", mustWork = TRUE)
  if (!identical(handoff_root, accepted_root)) {
    stop("Phase 13 normalized publication handoff root must be the accepted root", call. = FALSE)
  }
  targets <- phase13_normalized_publication_targets(accepted_root, registry_root)
  if (any(!file.exists(unname(targets)))) {
    missing <- unname(targets)[!file.exists(unname(targets))]
    stop("Phase 13 normalized publication target graph is incomplete: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  handoffs <- phase13_acquire_publication_validate_handoffs(accepted_root, registry_root)
  provenance_before <- list(
    artifacts = handoffs$artifacts,
    bundles = handoffs$bundles
  )
  publication_root <- phase13_transaction_common_root(accepted_root, registry_root)
  phase13_with_publication_lock(
    publication_root = publication_root,
    targets = targets,
    failure_injector = failure_injector,
    require_complete_promotion = TRUE,
    callback = function(transaction) {
      phase13_seed_publication_staging(transaction)
      graph_provenance <- provenance_before
      if (!is.null(candidate)) {
        candidate_edition <- phase13_source_scalar(candidate$bundle$edition_id[[1L]], "candidate edition_id")
        candidate_handoff <- phase13_acquire_publication_candidate_handoff(candidate, candidate_edition)
        merged_registries <- phase13_acquire_publication_merge_candidate_registry(
          handoffs,
          candidate_handoff
        )
        phase13_acquire_publication_stage_candidate_handoff(
          transaction,
          candidate_handoff,
          merged_registries
        )
        handoffs$handoffs[[candidate_edition]] <- candidate_handoff
        graph_provenance <- merged_registries
      }
      normalized <- lapply(
        phase13_publication_editions(),
        function(edition_id) phase13_acquire_publication_stage_normalized_edition(
          transaction,
          edition_id,
          registry_context_root,
          handoffs$handoffs[[edition_id]]
        )
      )
      names(normalized) <- phase13_publication_editions()
      canonical_refresh <- phase13_refresh_canonical_table_hashes(transaction$staging_root)
      manifest_refresh <- phase13_refresh_accepted_manifest_hashes(
        transaction$staging_root,
        canonical_refresh = canonical_refresh
      )
      graph <- phase13_acquire_publication_validate_normalized_graph(
        transaction$staging_root,
        canonical_refresh,
        manifest_refresh,
        graph_provenance
      )
      phase13_promote_publication_targets(transaction)
      transaction$result <- list(
        targets = targets,
        normalized_editions = normalized,
        canonical_refresh = canonical_refresh,
        manifest_refresh = manifest_refresh,
        graph = graph,
        loader_ready = TRUE,
        candidate = candidate
      )
      transaction$result
    }
  )
}

phase13_acquire_read_registry <- function(path) {
  if (!file.exists(path)) return(NULL)
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
}

phase13_acquire_align_registry_columns <- function(data, columns) {
  missing <- setdiff(columns, names(data))
  for (column in missing) data[[column]] <- ""
  data[, columns, drop = FALSE]
}

phase13_acquire_normalize_registry_artifacts <- function(artifacts, project_root) {
  artifacts <- as.data.frame(artifacts, stringsAsFactors = FALSE, check.names = FALSE)
  artifacts$source_artifact_id <- if ("source_artifact_id" %in% names(artifacts)) {
    as.character(artifacts$source_artifact_id)
  } else {
    as.character(artifacts$artifact_id)
  }
  artifacts$source_url_lineage <- if ("source_url_lineage" %in% names(artifacts)) {
    as.character(artifacts$source_url_lineage)
  } else {
    as.character(artifacts$source_url)
  }
  artifacts$status_provenance <- if ("status_provenance" %in% names(artifacts)) {
    as.character(artifacts$status_provenance)
  } else {
    ifelse(as.character(artifacts$artifact_type) == "status", "explicit", "not_applicable")
  }
  canonical <- character(nrow(artifacts))
  for (index in seq_len(nrow(artifacts))) {
    accepted_path <- file.path(
      project_root,
      "data/competition/accepted",
      as.character(artifacts$edition_id[[index]]),
      paste0(as.character(artifacts$artifact_type[[index]]), ".csv")
    )
    existing <- if ("canonical_content_sha256" %in% names(artifacts)) {
      as.character(artifacts$canonical_content_sha256[[index]])
    } else {
      ""
    }
    canonical[[index]] <- if (file.exists(accepted_path)) {
      phase13_acquire_file_sha256(accepted_path)
    } else if (grepl("^[0-9a-f]{64}$", existing)) {
      existing
    } else {
      stop(
        "Phase 13 existing source artifact has no canonical content bytes: ",
        as.character(artifacts$artifact_id[[index]]),
        call. = FALSE
      )
    }
  }
  artifacts$canonical_content_sha256 <- canonical
  artifacts$row_sha256 <- phase13_row_sha256(artifacts)
  artifacts
}

phase13_acquire_normalize_registry_bundle <- function(bundle, artifacts) {
  bundle <- as.data.frame(bundle, stringsAsFactors = FALSE, check.names = FALSE)[1L, , drop = FALSE]
  bundle <- phase13_acquire_rebuild_bundle_row(bundle, artifacts)
  bundle$canonical_content_sha256 <- phase13_acquire_canonical_content_sha256(
    phase13_acquire_bundle_content_table(bundle, artifacts)
  )
  phase13_acquire_rebuild_bundle_row(bundle, artifacts)
}

phase13_acquire_validate_registry_tables <- function(bundles, artifacts) {
  if (!nrow(bundles) || !nrow(artifacts)) stop("Phase 13 source registries must not be empty", call. = FALSE)
  for (bundle_id in unique(as.character(bundles$bundle_id))) {
    bundle <- bundles[as.character(bundles$bundle_id) == bundle_id, , drop = FALSE]
    bundle_artifacts <- artifacts[as.character(artifacts$bundle_id) == bundle_id, , drop = FALSE]
    if (nrow(bundle) != 1L || !nrow(bundle_artifacts)) {
      stop("Phase 13 source registry bundle/artifact linkage is incomplete: ", bundle_id, call. = FALSE)
    }
    phase13_validate_source_bundle(bundle, bundle_artifacts)
  }
  invisible(TRUE)
}

phase13_acquire_update_registries <- function(candidate, registry_root, project_root = phase13_acquire_project_root) {
  dir.create(registry_root, recursive = TRUE, showWarnings = FALSE)
  bundle_path <- file.path(registry_root, "source_bundles.csv")
  artifact_path <- file.path(registry_root, "source_artifacts.csv")
  old_bundles <- phase13_acquire_read_registry(bundle_path)
  old_artifacts <- phase13_acquire_read_registry(artifact_path)
  if (xor(is.null(old_bundles), is.null(old_artifacts))) {
    stop("Phase 13 source registries must be present as a pair", call. = FALSE)
  }
  if (is.null(old_bundles)) {
    bundles <- candidate$bundle
    artifacts <- candidate$artifacts
  } else {
    old_artifacts <- phase13_acquire_normalize_registry_artifacts(old_artifacts, project_root)
    old_bundle_rows <- lapply(unique(as.character(old_bundles$bundle_id)), function(bundle_id) {
      bundle <- old_bundles[as.character(old_bundles$bundle_id) == bundle_id, , drop = FALSE]
      bundle_artifacts <- old_artifacts[as.character(old_artifacts$bundle_id) == bundle_id, , drop = FALSE]
      if (nrow(bundle) != 1L || !nrow(bundle_artifacts)) {
        stop("Phase 13 existing source registry bundle is incomplete: ", bundle_id, call. = FALSE)
      }
      phase13_acquire_normalize_registry_bundle(bundle, bundle_artifacts)
    })
    old_bundles <- do.call(rbind, old_bundle_rows)
    old_bundles <- old_bundles[as.character(old_bundles$bundle_id) != as.character(candidate$bundle$bundle_id), , drop = FALSE]
    old_artifacts <- old_artifacts[as.character(old_artifacts$bundle_id) != as.character(candidate$bundle$bundle_id), , drop = FALSE]
    old_bundles <- phase13_acquire_align_registry_columns(old_bundles, names(candidate$bundle))
    old_artifacts <- phase13_acquire_align_registry_columns(old_artifacts, names(candidate$artifacts))
    bundles <- rbind(old_bundles, candidate$bundle)
    artifacts <- rbind(old_artifacts, candidate$artifacts)
  }
  phase13_acquire_validate_registry_tables(bundles, artifacts)

  staged_root <- tempfile(".phase13-registry-stage-", tmpdir = registry_root)
  dir.create(staged_root, recursive = TRUE, showWarnings = FALSE)
  staged_bundle_path <- file.path(staged_root, basename(bundle_path))
  staged_artifact_path <- file.path(staged_root, basename(artifact_path))
  backup_root <- tempfile(".phase13-registry-backup-", tmpdir = registry_root)
  dir.create(backup_root, recursive = TRUE, showWarnings = FALSE)
  bundle_backup <- NULL
  artifact_backup <- NULL
  promoted_bundle <- FALSE
  promoted_artifact <- FALSE
  success <- FALSE
  rollback <- function() {
    if (promoted_artifact && file.exists(artifact_path)) unlink(artifact_path)
    if (promoted_bundle && file.exists(bundle_path)) unlink(bundle_path)
    if (!is.null(artifact_backup) && file.exists(artifact_backup)) file.rename(artifact_backup, artifact_path)
    if (!is.null(bundle_backup) && file.exists(bundle_backup)) file.rename(bundle_backup, bundle_path)
  }
  on.exit({
    if (!success) rollback()
    if (dir.exists(staged_root)) unlink(staged_root, recursive = TRUE)
    if (dir.exists(backup_root)) unlink(backup_root, recursive = TRUE)
  }, add = TRUE)
  phase13_source_write_csv(bundles, staged_bundle_path)
  phase13_source_write_csv(artifacts, staged_artifact_path)
  staged_bundles <- phase13_acquire_read_registry(staged_bundle_path)
  staged_artifacts <- phase13_acquire_read_registry(staged_artifact_path)
  phase13_acquire_validate_registry_tables(staged_bundles, staged_artifacts)

  if (file.exists(bundle_path)) {
    bundle_backup <- file.path(backup_root, basename(bundle_path))
    if (!file.rename(bundle_path, bundle_backup)) stop("Could not stage the previous source bundle registry", call. = FALSE)
  }
  if (file.exists(artifact_path)) {
    artifact_backup <- file.path(backup_root, basename(artifact_path))
    if (!file.rename(artifact_path, artifact_backup)) stop("Could not stage the previous source artifact registry", call. = FALSE)
  }
  if (!file.rename(staged_bundle_path, bundle_path)) stop("Could not publish the source bundle registry", call. = FALSE)
  promoted_bundle <- TRUE
  if (!file.rename(staged_artifact_path, artifact_path)) stop("Could not publish the source artifact registry", call. = FALSE)
  promoted_artifact <- TRUE
  success <- TRUE
  invisible(list(source_bundles = bundles, source_artifacts = artifacts))
}

phase13_acquire_last_accepted_bundle_id <- function(edition_id, registry_root, output_root) {
  registry_path <- file.path(registry_root, "source_bundles.csv")
  if (file.exists(registry_path)) {
    bundles <- phase13_acquire_read_registry(registry_path)
    matches <- bundles[as.character(bundles$edition_id) == edition_id & as.character(bundles$bundle_status) == "accepted", , drop = FALSE]
    if (nrow(matches)) return(as.character(matches$bundle_id[[nrow(matches)]]))
  }
  manifest_path <- file.path(output_root, edition_id, "source_bundle_manifest.csv")
  if (file.exists(manifest_path)) {
    manifest <- phase13_acquire_read_registry(manifest_path)
    if (nrow(manifest) && "bundle_id" %in% names(manifest)) return(as.character(manifest$bundle_id[[1L]]))
  }
  ""
}

phase13_acquire_publish_blocked_refresh <- function(
    edition_id,
    bundle_id,
    output_root,
    registry_root,
    reason,
    project_root = phase13_acquire_project_root,
    refresh_batch_id = NULL,
    operator = "system",
    blocked_at_utc = phase13_acquire_now_utc(),
    raw_root = NULL,
    sidecar_writer = phase13_source_write_json) {
  edition_id <- phase13_source_safe_relative_path(edition_id)
  output_root <- phase13_acquire_resolve_path(output_root, project_root)
  registry_root <- phase13_acquire_resolve_path(registry_root, project_root)
  if (!dir.exists(output_root) || !dir.exists(registry_root)) {
    stop("Phase 13 refresh-batch publication requires existing accepted and registry roots", call. = FALSE)
  }
  refresh_batch_id <- phase13_acquire_resolve_refresh_batch_id(refresh_batch_id, edition_id, blocked_at_utc)
  bundle_id <- phase13_source_scalar(bundle_id, "candidate_bundle_id")
  reason <- phase13_source_scalar(reason, "failure_reason")
  operator <- phase13_source_scalar(operator, "operator")
  current <- load_competition_edition_registries(
    registry_dir = registry_root,
    project_root = project_root,
    accepted_root = output_root,
    raw_root = raw_root
  )
  edition_index <- match(edition_id, as.character(current$edition_id))
  if (is.na(edition_index)) stop("Phase 13 refresh-batch publication edition is not registered: ", edition_id, call. = FALSE)
  edition_row <- current[edition_index, , drop = FALSE]
  paths <- phase13_acquire_refresh_history_paths(
    registry_root,
    edition_id,
    refresh_batch_id = refresh_batch_id
  )
  existing_history <- phase13_acquire_read_refresh_history(
    file.path(paths$refresh_batch_root, edition_id, "status_history.csv")
  )
  phase13_acquire_validate_refresh_history_table(
    existing_history,
    edition_id,
    paths$refresh_batch_root
  )
  if (any(as.character(existing_history$refresh_batch_id) == refresh_batch_id) || file.exists(paths$blocked_path)) {
    stop("Phase 13 refresh batch ID already exists: ", refresh_batch_id, call. = FALSE)
  }
  accepted_bundle_id <- as.character(edition_row$source_bundle_id[[1L]])
  accepted_output_bundle_id <- as.character(edition_row$active_output_bundle_id[[1L]])
  blocked_row <- phase13_block_competition_edition(
    edition_row,
    failure_reason = reason,
    failure_at_utc = blocked_at_utc,
    operator = operator,
    refresh_batch_id = refresh_batch_id
  )
  editions <- current
  editions[edition_index, names(blocked_row)] <- blocked_row
  editions <- as.data.frame(editions, stringsAsFactors = FALSE, check.names = FALSE)
  editions$row_sha256 <- phase13_row_sha256(editions)
  event_index <- if (nrow(existing_history)) max(as.integer(existing_history$event_index)) + 1L else 1L
  record_relative_path <- file.path(
    "refresh_batches", edition_id, refresh_batch_id, "blocked_refresh.json"
  )
  event <- phase13_acquire_build_refresh_history_row(
    edition_id = edition_id,
    refresh_batch_id = refresh_batch_id,
    event_index = event_index,
    status = "blocked",
    event_at_utc = blocked_at_utc,
    candidate_bundle_id = bundle_id,
    last_accepted_bundle_id = accepted_bundle_id,
    last_accepted_output_bundle_id = accepted_output_bundle_id,
    registry_revision = blocked_row$registry_revision[[1L]],
    operator = operator,
    validation_passed = FALSE,
    record_relative_path = record_relative_path
  )
  history <- rbind(existing_history, event)
  phase13_acquire_validate_refresh_history_table(history, edition_id, paths$refresh_batch_root)
  metadata <- list(
    schema_version = "phase13-refresh-batch-v1",
    refresh_batch_id = refresh_batch_id,
    status = "blocked",
    edition_id = edition_id,
    candidate_bundle_id = bundle_id,
    last_accepted_bundle_id = accepted_bundle_id,
    last_accepted_output_bundle_id = accepted_output_bundle_id,
    blocked_at_utc = blocked_at_utc,
    failure_reason = reason,
    registry_revision = as.integer(blocked_row$registry_revision[[1L]]),
    parser_commit_sha = phase13_parser_commit_sha(project_root),
    edition_blocked = TRUE
  )

  stage_root <- tempfile(".phase13-refresh-stage-", tmpdir = registry_root)
  backup_root <- tempfile(".phase13-refresh-backup-", tmpdir = registry_root)
  dir.create(stage_root, recursive = TRUE, showWarnings = FALSE)
  dir.create(backup_root, recursive = TRUE, showWarnings = FALSE)
  staged_edition_path <- file.path(stage_root, "competition_editions.csv")
  staged_history_path <- file.path(stage_root, "refresh_batches", edition_id, "status_history.csv")
  staged_sidecar_path <- file.path(stage_root, record_relative_path)
  phase13_source_write_csv(editions, staged_edition_path)
  phase13_source_write_csv(history, staged_history_path)
  tryCatch(
    sidecar_writer(metadata, staged_sidecar_path),
    error = function(error) stop("Phase 13 refresh-batch publication failed: blocked_refresh.json", call. = FALSE)
  )
  staged_sidecar <- phase13_acquire_read_blocked_refresh(staged_sidecar_path)
  if (!identical(as.character(staged_sidecar$refresh_batch_id), refresh_batch_id)) {
    stop("Phase 13 refresh-batch publication failed: blocked_refresh.json", call. = FALSE)
  }
  phase13_validate_refresh_history(
    edition_id = edition_id,
    registry_root = registry_root,
    accepted_root = output_root,
    refresh_batch_root = file.path(stage_root, "refresh_batches"),
    refresh_batch_id = refresh_batch_id,
    project_root = project_root,
    edition_path = staged_edition_path,
    raw_root = raw_root
  )

  target_paths <- c(
    edition = file.path(registry_root, "competition_editions.csv"),
    history = file.path(registry_root, "refresh_batches", edition_id, "status_history.csv"),
    sidecar = file.path(registry_root, record_relative_path)
  )
  staged_paths <- c(
    edition = staged_edition_path,
    history = staged_history_path,
    sidecar = staged_sidecar_path
  )
  backup_paths <- c(
    edition = file.path(backup_root, "competition_editions.csv"),
    history = file.path(backup_root, "status_history.csv"),
    sidecar = ""
  )
  promoted <- setNames(logical(length(target_paths)), names(target_paths))
  backed_up <- setNames(logical(length(target_paths)), names(target_paths))
  success <- FALSE
  rollback <- function() {
    for (name in rev(names(target_paths))) {
      target <- target_paths[[name]]
      if (isTRUE(promoted[[name]]) && (file.exists(target) || dir.exists(target))) {
        unlink(target, recursive = TRUE, force = TRUE)
      }
    }
    for (name in names(target_paths)) {
      if (isTRUE(backed_up[[name]]) && file.exists(backup_paths[[name]]) && !file.exists(target_paths[[name]])) {
        file.rename(backup_paths[[name]], target_paths[[name]])
      }
    }
    batch_dir <- dirname(target_paths[["sidecar"]])
    if (!success && dir.exists(batch_dir) && !file.exists(target_paths[["sidecar"]])) {
      unlink(batch_dir, recursive = TRUE, force = TRUE)
    }
  }
  on.exit({
    if (!success) rollback()
    if (dir.exists(stage_root)) unlink(stage_root, recursive = TRUE, force = TRUE)
    if (dir.exists(backup_root)) unlink(backup_root, recursive = TRUE, force = TRUE)
  }, add = TRUE)
  for (name in c("edition", "history")) {
    target <- target_paths[[name]]
    if (file.exists(target)) {
      if (!file.rename(target, backup_paths[[name]])) {
        stop("Phase 13 refresh-batch publication failed: ", name, call. = FALSE)
      }
      backed_up[[name]] <- TRUE
    }
  }
  for (name in names(target_paths)) {
    dir.create(dirname(target_paths[[name]]), recursive = TRUE, showWarnings = FALSE)
    if (!file.rename(staged_paths[[name]], target_paths[[name]])) {
      stop("Phase 13 refresh-batch publication failed: ", basename(target_paths[[name]]), call. = FALSE)
    }
    promoted[[name]] <- TRUE
  }
  phase13_validate_refresh_history(
    edition_id = edition_id,
    registry_root = registry_root,
    accepted_root = output_root,
    refresh_batch_root = file.path(registry_root, "refresh_batches"),
    refresh_batch_id = refresh_batch_id,
    project_root = project_root,
    raw_root = raw_root
  )
  success <- TRUE
  invisible(list(
    metadata = metadata,
    edition = blocked_row,
    history = history,
    paths = target_paths
  ))
}

phase13_acquire_write_blocked_metadata <- function(
    edition_id,
    bundle_id,
    output_root,
    registry_root,
    reason,
    project_root = phase13_acquire_project_root,
    refresh_batch_id = NULL,
    operator = "system",
    blocked_at_utc = phase13_acquire_now_utc(),
    raw_root = NULL,
    sidecar_writer = phase13_source_write_json) {
  phase13_acquire_publish_blocked_refresh(
    edition_id = edition_id,
    bundle_id = bundle_id,
    output_root = output_root,
    registry_root = registry_root,
    reason = reason,
    project_root = project_root,
    refresh_batch_id = refresh_batch_id,
    operator = operator,
    blocked_at_utc = blocked_at_utc,
    raw_root = raw_root,
    sidecar_writer = sidecar_writer
  )$metadata
}

phase13_acquire_prepare_refresh_acceptance <- function(
    edition_id,
    output_root,
    registry_root,
    project_root = phase13_acquire_project_root,
    operator = "system",
    operator_action = "",
    validation_passed = FALSE,
    raw_root = NULL) {
  edition_path <- file.path(registry_root, "competition_editions.csv")
  if (!file.exists(edition_path)) return(NULL)
  state <- phase13_validate_refresh_history(
    edition_id = edition_id,
    registry_root = registry_root,
    accepted_root = output_root,
    refresh_batch_root = file.path(registry_root, "refresh_batches"),
    project_root = project_root,
    raw_root = raw_root
  )
  row <- state$edition[1L, , drop = FALSE]
  if (!phase13_registry_logical(row$blocked[[1L]], "blocked")) {
    return(list(state = state, edition = row, was_blocked = FALSE, blocked_batch_id = ""))
  }
  blocked_batch_id <- as.character(row$blocked_refresh_batch_id[[1L]])
  if (phase13_registry_blank(blocked_batch_id)) {
    stop("Phase 13 blocked lifecycle recovery requires a linked refresh batch", call. = FALSE)
  }
  phase13_validate_refresh_history(
    edition_id = edition_id,
    registry_root = registry_root,
    accepted_root = output_root,
    refresh_batch_root = file.path(registry_root, "refresh_batches"),
    refresh_batch_id = blocked_batch_id,
    project_root = project_root,
    raw_root = raw_root
  )
  transitioned <- phase13_transition_competition_edition(
    row,
    next_lifecycle_state = row$lifecycle_state[[1L]],
    operator_action = operator_action,
    validation_passed = validation_passed,
    operator = operator,
    audit_at_utc = phase13_acquire_now_utc()
  )
  list(
    state = state,
    edition = row,
    transitioned = transitioned,
    was_blocked = TRUE,
    blocked_batch_id = blocked_batch_id,
    operator_action = operator_action
  )
}

phase13_acquire_update_edition_after_acceptance <- function(
    candidate,
    edition_id,
    output_root,
    registry_root,
    refresh_batch_id,
    project_root = phase13_acquire_project_root,
    operator = "system",
    operator_action = "",
    validation_passed = FALSE,
    recovery_context = NULL,
    accepted_at_utc = phase13_acquire_now_utc(),
    raw_root = NULL) {
  edition_id <- phase13_source_safe_relative_path(edition_id)
  candidate_bundle_id <- phase13_source_scalar(candidate$bundle$bundle_id[[1L]], "candidate bundle_id")
  refresh_batch_id <- phase13_acquire_resolve_refresh_batch_id(refresh_batch_id, edition_id)
  registry_root <- phase13_acquire_resolve_path(registry_root, project_root)
  output_root <- phase13_acquire_resolve_path(output_root, project_root)
  edition_path <- file.path(registry_root, "competition_editions.csv")
  if (!file.exists(edition_path)) stop("Phase 13 accepted refresh requires competition_editions.csv", call. = FALSE)
  current_editions <- utils::read.csv(
    edition_path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = ""
  )
  edition_index <- match(edition_id, as.character(current_editions$edition_id))
  if (is.na(edition_index)) stop("Phase 13 accepted refresh edition is not registered: ", edition_id, call. = FALSE)
  base_row <- if (!is.null(recovery_context)) recovery_context$edition else current_editions[edition_index, , drop = FALSE]
  if (!"blocked_refresh_batch_id" %in% names(base_row)) base_row$blocked_refresh_batch_id <- ""
  was_blocked <- !is.null(recovery_context) && isTRUE(recovery_context$was_blocked)
  recovered_row <- if (was_blocked) recovery_context$transitioned else base_row
  if (was_blocked && !isTRUE(validation_passed)) {
    stop("Phase 13 blocked lifecycle recovery requires explicit operator action and validation", call. = FALSE)
  }
  if (was_blocked && phase13_registry_blank(operator_action)) {
    stop("Phase 13 blocked lifecycle recovery requires explicit operator action and validation", call. = FALSE)
  }
  existing_history_path <- file.path(registry_root, "refresh_batches", edition_id, "status_history.csv")
  existing_history <- phase13_acquire_read_refresh_history(existing_history_path)
  phase13_acquire_validate_refresh_history_table(
    existing_history,
    edition_id,
    file.path(registry_root, "refresh_batches")
  )
  if (any(as.character(existing_history$refresh_batch_id) == refresh_batch_id)) {
    stop("Phase 13 refresh batch ID already exists: ", refresh_batch_id, call. = FALSE)
  }
  accepted_row <- recovered_row
  accepted_row$source_bundle_id <- candidate_bundle_id
  accepted_row$active_output_bundle_id <- candidate_bundle_id
  accepted_row$last_accepted_output_bundle_id <- candidate_bundle_id
  accepted_row$blocked <- FALSE
  accepted_row$audit_event <- "refresh_accepted"
  accepted_row$audit_at_utc <- accepted_at_utc
  accepted_row$operator <- operator
  accepted_row$registry_revision <- as.integer(accepted_row$registry_revision[[1L]]) + 1L
  accepted_row$row_sha256 <- phase13_registry_row_hash(accepted_row)
  current_editions[edition_index, names(accepted_row)] <- accepted_row
  current_editions$row_sha256 <- phase13_row_sha256(current_editions)

  next_event_index <- if (nrow(existing_history)) max(as.integer(existing_history$event_index)) + 1L else 1L
  appended <- existing_history
  if (was_blocked) {
    recovery_event <- phase13_acquire_build_refresh_history_row(
      edition_id = edition_id,
      refresh_batch_id = recovery_context$blocked_batch_id,
      event_index = next_event_index,
      status = "recovery",
      event_at_utc = accepted_at_utc,
      candidate_bundle_id = candidate_bundle_id,
      last_accepted_bundle_id = as.character(recovery_context$edition$source_bundle_id[[1L]]),
      last_accepted_output_bundle_id = as.character(recovery_context$edition$active_output_bundle_id[[1L]]),
      registry_revision = recovered_row$registry_revision[[1L]],
      operator = operator,
      operator_action = operator_action,
      validation_passed = TRUE,
      record_relative_path = file.path(
        "refresh_batches", edition_id, recovery_context$blocked_batch_id, "blocked_refresh.json"
      )
    )
    appended <- rbind(appended, recovery_event)
    next_event_index <- next_event_index + 1L
  }
  accepted_event <- phase13_acquire_build_refresh_history_row(
    edition_id = edition_id,
    refresh_batch_id = refresh_batch_id,
    event_index = next_event_index,
    status = "accepted",
    event_at_utc = accepted_at_utc,
    candidate_bundle_id = candidate_bundle_id,
    last_accepted_bundle_id = candidate_bundle_id,
    last_accepted_output_bundle_id = candidate_bundle_id,
    registry_revision = accepted_row$registry_revision[[1L]],
    operator = operator,
    operator_action = operator_action,
    validation_passed = TRUE,
    record_relative_path = ""
  )
  appended <- rbind(appended, accepted_event)
  phase13_acquire_validate_refresh_history_table(
    appended,
    edition_id,
    file.path(registry_root, "refresh_batches")
  )

  stage_root <- tempfile(".phase13-accepted-refresh-stage-", tmpdir = registry_root)
  backup_root <- tempfile(".phase13-accepted-refresh-backup-", tmpdir = registry_root)
  dir.create(stage_root, recursive = TRUE, showWarnings = FALSE)
  dir.create(backup_root, recursive = TRUE, showWarnings = FALSE)
  staged_edition_path <- file.path(stage_root, "competition_editions.csv")
  staged_history_path <- file.path(stage_root, "refresh_batches", edition_id, "status_history.csv")
  phase13_source_write_csv(current_editions, staged_edition_path)
  phase13_source_write_csv(appended, staged_history_path)
  phase13_validate_refresh_history(
    edition_id = edition_id,
    registry_root = registry_root,
    accepted_root = output_root,
    refresh_batch_root = file.path(stage_root, "refresh_batches"),
    project_root = project_root,
    edition_path = staged_edition_path,
    raw_root = raw_root
  )

  target_paths <- c(
    edition = edition_path,
    history = existing_history_path
  )
  staged_paths <- c(
    edition = staged_edition_path,
    history = staged_history_path
  )
  backup_paths <- c(
    edition = file.path(backup_root, "competition_editions.csv"),
    history = file.path(backup_root, "status_history.csv")
  )
  promoted <- setNames(logical(length(target_paths)), names(target_paths))
  backed_up <- setNames(logical(length(target_paths)), names(target_paths))
  success <- FALSE
  rollback <- function() {
    for (name in rev(names(target_paths))) {
      target <- target_paths[[name]]
      if (isTRUE(promoted[[name]]) && (file.exists(target) || dir.exists(target))) unlink(target, recursive = TRUE, force = TRUE)
    }
    for (name in names(target_paths)) {
      if (isTRUE(backed_up[[name]]) && file.exists(backup_paths[[name]]) && !file.exists(target_paths[[name]])) {
        file.rename(backup_paths[[name]], target_paths[[name]])
      }
    }
  }
  on.exit({
    if (!success) rollback()
    if (dir.exists(stage_root)) unlink(stage_root, recursive = TRUE, force = TRUE)
    if (dir.exists(backup_root)) unlink(backup_root, recursive = TRUE, force = TRUE)
  }, add = TRUE)
  for (name in names(target_paths)) {
    target <- target_paths[[name]]
    if (file.exists(target)) {
      if (!file.rename(target, backup_paths[[name]])) stop("Phase 13 accepted refresh publication failed: ", name, call. = FALSE)
      backed_up[[name]] <- TRUE
    }
  }
  for (name in names(target_paths)) {
    dir.create(dirname(target_paths[[name]]), recursive = TRUE, showWarnings = FALSE)
    if (!file.rename(staged_paths[[name]], target_paths[[name]])) stop("Phase 13 accepted refresh publication failed: ", name, call. = FALSE)
    promoted[[name]] <- TRUE
  }
  phase13_validate_refresh_history(
    edition_id = edition_id,
    registry_root = registry_root,
    accepted_root = output_root,
    refresh_batch_root = file.path(registry_root, "refresh_batches"),
    project_root = project_root,
    raw_root = raw_root
  )
  success <- TRUE
  invisible(list(edition = accepted_row, history = appended, refresh_batch_id = refresh_batch_id))
}

phase13_acquire_publish_refresh <- function(
    candidate,
    output_root,
    edition_id,
    raw_root,
    registry_root,
    project_root = phase13_acquire_project_root,
    registry_context_root = registry_root,
    refresh_batch_id,
    operator = "system",
    operator_action = "",
    validation_passed = FALSE) {
  edition_id <- phase13_source_safe_relative_path(edition_id)
  refresh_batch_id <- phase13_acquire_resolve_refresh_batch_id(refresh_batch_id, edition_id)
  registry_context_root <- if (is.null(registry_context_root)) {
    NULL
  } else {
    candidate_context_root <- phase13_acquire_resolve_path(registry_context_root, project_root)
    context_files <- file.path(candidate_context_root, c("team_identity.csv", "competition_editions.csv"))
    if (all(file.exists(context_files))) candidate_context_root else NULL
  }
  recovery_context <- phase13_acquire_prepare_refresh_acceptance(
    edition_id = edition_id,
    output_root = output_root,
    registry_root = registry_root,
    project_root = project_root,
    operator = operator,
    operator_action = operator_action,
    validation_passed = validation_passed,
    raw_root = raw_root
  )
  phase13_acquire_write_raw_store(
    candidate,
    phase13_acquire_resolve_path(raw_root, project_root),
    edition_id,
    candidate$bundle$bundle_id[[1L]]
  )
  candidate <- phase13_acquire_publish_accepted(
    candidate,
    output_root = phase13_acquire_resolve_path(output_root, project_root),
    edition_id = edition_id,
    raw_root = phase13_acquire_resolve_path(raw_root, project_root),
    registry_root = phase13_acquire_resolve_path(registry_root, project_root),
    registry_context_root = registry_context_root
  )
  phase13_acquire_update_registries(
    candidate,
    phase13_acquire_resolve_path(registry_root, project_root),
    project_root = project_root
  )
  if (!is.null(recovery_context)) {
    candidate$edition_registry <- phase13_acquire_update_edition_after_acceptance(
      candidate = candidate,
      edition_id = edition_id,
      output_root = output_root,
      registry_root = registry_root,
      refresh_batch_id = refresh_batch_id,
      project_root = project_root,
      operator = operator,
      operator_action = operator_action,
      validation_passed = validation_passed,
      recovery_context = recovery_context,
      raw_root = raw_root
    )
  }
  candidate
}

phase13_acquire_main <- function(args = commandArgs(trailingOnly = TRUE)) {
  options <- phase13_acquire_parse_args(args)
  if (isTRUE(options$help)) {
    cat(paste(phase13_acquire_help(), collapse = "\n"), "\n", sep = "")
    return(invisible(NULL))
  }
  edition_id <- phase13_source_scalar(options[["edition-id"]], "edition_id")
  output_root <- phase13_acquire_resolve_path(options[["output-root"]] %||% "data/competition/accepted")
  registry_root <- phase13_acquire_resolve_path(options[["registry-root"]] %||% "data/competition/registries")
  raw_root <- phase13_acquire_resolve_path(options[["raw-root"]] %||% "data/competition/local_raw")
  fallback <- !is.null(options[["fallback-file"]])
  bundle_id <- if (!is.null(options[["bundle-id"]])) options[["bundle-id"]] else phase13_acquire_default_bundle_id(edition_id, fallback)
  refresh_batch_id <- phase13_acquire_resolve_refresh_batch_id(options[["refresh-batch-id"]], edition_id)
  operator <- if (!is.null(options[["operator"]])) phase13_source_scalar(options[["operator"]], "operator") else "system"
  operator_action <- if (!is.null(options[["operator-action"]])) as.character(options[["operator-action"]]) else ""
  validation_passed <- phase13_acquire_option_logical(options, "validation-passed", default = FALSE)
  tryCatch({
    candidate <- phase13_acquire_candidate(options, edition_id)
    candidate$manifest <- phase13_acquire_source_manifest_table(candidate$bundle, candidate$artifacts)
    if (isTRUE(options$dry_run)) {
      message(sprintf("Phase 13 dry-run candidate valid: %s (%s)", candidate$bundle$bundle_id[[1L]], edition_id))
      return(invisible(candidate))
    }
    if (isTRUE(options$publish_accepted)) {
      candidate <- phase13_acquire_publish_refresh(
        candidate = candidate,
        output_root = output_root,
        edition_id = edition_id,
        raw_root = raw_root,
        registry_root = registry_root,
        registry_context_root = registry_root,
        refresh_batch_id = refresh_batch_id,
        operator = operator,
        operator_action = operator_action,
        validation_passed = validation_passed
      )
    } else {
      phase13_acquire_write_raw_store(candidate, raw_root, edition_id, candidate$bundle$bundle_id[[1L]])
      phase13_acquire_update_registries(candidate, registry_root)
    }
    message(sprintf(
      "Phase 13 %s %s source bundle: %s",
      if (isTRUE(options$publish_accepted)) "accepted" else "captured",
      edition_id,
      candidate$bundle$bundle_id[[1L]]
    ))
    invisible(candidate)
  }, error = function(error) {
    if (!isTRUE(options$dry_run) && file.exists(file.path(registry_root, "competition_editions.csv")) && dir.exists(output_root)) {
      block_error <- tryCatch(
        phase13_acquire_write_blocked_metadata(
          edition_id = edition_id,
          bundle_id = bundle_id,
          output_root = output_root,
          registry_root = registry_root,
          reason = conditionMessage(error),
          project_root = phase13_acquire_project_root,
          refresh_batch_id = refresh_batch_id,
          operator = operator,
          raw_root = raw_root
        ),
        error = function(block_error) block_error
      )
      if (inherits(block_error, "error")) {
        stop(
          sprintf(
            "Phase 13 source capture blocked: %s; %s",
            conditionMessage(error),
            conditionMessage(block_error)
          ),
          call. = FALSE
        )
      }
    }
    stop(sprintf("Phase 13 source capture blocked: %s", conditionMessage(error)), call. = FALSE)
  })
}

`%||%` <- function(value, fallback) if (is.null(value)) fallback else value

if (identical(environment(), globalenv())) {
  phase13_acquire_main()
}
