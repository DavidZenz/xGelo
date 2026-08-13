#' Phase 13 source artifact and edition-scoped bundle contracts.
#'
#' This module keeps the exact bytes of a structured source response outside
#' the committed contract tables.  The tables retain the byte count, SHA-256,
#' provenance, parser commit, and acceptance metadata needed to replay and
#' audit a candidate without publishing the response body.

phase13_source_required_resource_types <- function() {
  c("fixtures", "groups", "standings", "results", "status")
}

phase13_source_resource_schema <- function() {
  list(
    fixtures = c("source_fixture_id", "scheduled_at_utc", "status", "home", "away"),
    groups = c("source_group_id", "league", "display_name"),
    standings = c("source_team_id", "source_group_id", "position", "points"),
    results = c("source_fixture_id", "status", "home_goals", "away_goals"),
    status = c("source_edition_id", "competition_status")
  )
}

phase13_source_compact_resource_schema <- function() {
  list(
    fixtures = c(
      "source_fixture_id", "scheduled_at_utc", "status",
      "home_uefa_source_team_id", "away_uefa_source_team_id",
      "home_display_name", "away_display_name"
    ),
    groups = c("source_group_id", "league", "display_name"),
    standings = c("source_team_id", "source_group_id", "position", "points"),
    results = c("source_fixture_id", "status", "home_goals", "away_goals"),
    status = c("source_edition_id", "competition_status")
  )
}

phase13_validate_structured_resource_names <- function(resource_types) {
  if (is.null(resource_types) || !length(resource_types)) {
    stop("Phase 13 structured resource set must not be empty", call. = FALSE)
  }
  resource_types <- as.character(resource_types)
  required <- phase13_source_required_resource_types()
  missing <- setdiff(required, resource_types)
  unknown <- setdiff(resource_types, required)
  if (length(missing)) stop("Phase 13 structured bundle is missing required resource classes: ", paste(missing, collapse = ", "), call. = FALSE)
  if (length(unknown)) stop("Phase 13 structured bundle contains unknown resource classes: ", paste(unknown, collapse = ", "), call. = FALSE)
  if (anyDuplicated(resource_types)) stop("Phase 13 structured bundle contains duplicate resource classes", call. = FALSE)
  invisible(resource_types)
}

phase13_source_find_project_root <- function(path = ".") {
  candidate <- normalizePath(path, winslash = "/", mustWork = FALSE)
  if (file.exists(candidate) && !dir.exists(candidate)) candidate <- dirname(candidate)
  repeat {
    if (dir.exists(file.path(candidate, ".git")) || file.exists(file.path(candidate, ".git"))) {
      return(candidate)
    }
    parent <- dirname(candidate)
    if (identical(parent, candidate)) break
    candidate <- parent
  }
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

phase13_source_scalar <- function(value, name, allow_empty = FALSE) {
  if (length(value) != 1L || is.null(value) || is.na(value)) {
    stop("Phase 13 ", name, " must be one non-missing value", call. = FALSE)
  }
  value <- as.character(value[[1L]])
  if (!allow_empty && !nzchar(value)) {
    stop("Phase 13 ", name, " must not be empty", call. = FALSE)
  }
  value
}

phase13_source_canonical_scalar <- function(value) {
  if (inherits(value, "Date")) value <- format(value, "%Y-%m-%d")
  if (inherits(value, "POSIXt")) value <- format(value, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  if (is.logical(value)) value <- ifelse(is.na(value), "", ifelse(value, "true", "false"))
  if (length(value) == 0L || is.na(value[[1L]])) return("")
  as.character(value[[1L]])
}

phase13_source_safe_relative_path <- function(path) {
  path <- gsub("\\\\", "/", as.character(path))
  if (length(path) != 1L || is.na(path) || !nzchar(path) || grepl("^/", path) ||
      grepl("(^|/)\\.\\.?(/|$)", path)) {
    stop("Phase 13 source path is unsafe: ", path, call. = FALSE)
  }
  normalized <- normalizePath(path, winslash = "/", mustWork = FALSE)
  if (identical(normalized, ".") || grepl("^/", normalized) || !identical(normalized, path)) {
    stop("Phase 13 source path is not a trusted relative path: ", path, call. = FALSE)
  }
  path
}

phase13_source_path_within <- function(path, root) {
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  root <- normalizePath(root, winslash = "/", mustWork = FALSE)
  identical(path, root) || startsWith(path, paste0(root, "/"))
}

phase13_source_path_under_root <- function(root, relative_path, must_work = FALSE) {
  relative_path <- phase13_source_safe_relative_path(relative_path)
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  candidate <- normalizePath(file.path(root, relative_path), winslash = "/", mustWork = FALSE)
  if (!phase13_source_path_within(candidate, root)) {
    stop("Phase 13 source path escapes the trusted root", call. = FALSE)
  }
  if (isTRUE(must_work) && !file.exists(candidate)) {
    stop("Phase 13 source artifact is missing: ", relative_path, call. = FALSE)
  }
  candidate
}

phase13_parser_commit_sha <- function(project_root = ".") {
  root <- phase13_source_find_project_root(project_root)
  output <- tryCatch(
    system2("git", c("-C", root, "rev-parse", "HEAD"), stdout = TRUE, stderr = TRUE),
    error = function(error) character(0)
  )
  status <- attr(output, "status")
  if (!length(output) || (!is.null(status) && status != 0L)) {
    stop("Phase 13 parser identity requires git rev-parse HEAD", call. = FALSE)
  }
  sha <- trimws(as.character(output[[1L]]))
  if (!grepl("^[0-9a-fA-F]{7,64}$", sha)) {
    stop("Phase 13 parser identity is not a Git commit SHA", call. = FALSE)
  }
  tolower(sha)
}

phase13_source_raw_bytes <- function(value) {
  if (is.raw(value)) return(value)
  if (is.character(value) && length(value) == 1L && !is.na(value)) {
    return(charToRaw(enc2utf8(value)))
  }
  stop("Phase 13 raw response must be one character value or a raw vector", call. = FALSE)
}

phase13_source_sha256 <- function(value) {
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("digest is required for Phase 13 SHA-256 contracts", call. = FALSE)
  }
  digest::digest(phase13_source_raw_bytes(value), algo = "sha256", serialize = FALSE)
}

phase13_source_validate_structured_bytes <- function(value, artifact_type = "resource") {
  raw_bytes <- phase13_source_raw_bytes(value)
  if (!length(raw_bytes)) stop("Phase 13 structured resource bytes must not be empty", call. = FALSE)
  text <- tryCatch(rawToChar(raw_bytes), error = function(error) "")
  probe <- tolower(trimws(text))
  if (grepl("^%pdf", probe) || grepl("^<!doctype\\s+html", probe) || grepl("^<html(?:[ >]|$)", probe)) {
    stop("Phase 13 official resource must be structured JSON, not rendered HTML or PDF: ", artifact_type, call. = FALSE)
  }
  if (requireNamespace("jsonlite", quietly = TRUE)) {
    tryCatch(
      jsonlite::validate(text),
      error = function(error) stop("Phase 13 structured resource is not valid JSON: ", artifact_type, call. = FALSE)
    )
  }
  invisible(raw_bytes)
}

phase13_canonical_sha256 <- function(data, key = NULL) {
  if (!is.data.frame(data)) stop("Phase 13 canonical hashing requires a data frame", call. = FALSE)
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("digest is required for Phase 13 SHA-256 contracts", call. = FALSE)
  }
  if (!ncol(data)) stop("Phase 13 canonical hashing requires named columns", call. = FALSE)
  if (is.null(key)) key <- names(data)[[1L]]
  key <- as.character(key)
  missing <- setdiff(key, names(data))
  if (length(missing)) stop("Phase 13 canonical hash key missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  if (nrow(data)) {
    order_args <- lapply(data[key], function(column) vapply(column, phase13_source_canonical_scalar, character(1)))
    data <- data[do.call(order, c(order_args, list(na.last = TRUE, method = "radix"))), , drop = FALSE]
  }
  rows <- vapply(seq_len(nrow(data)), function(index) {
    paste(vapply(data[index, , drop = FALSE], phase13_source_canonical_scalar, character(1)), collapse = "\x1f")
  }, character(1))
  payload <- paste(c(paste(names(data), collapse = "\x1f"), rows), collapse = "\x1e")
  digest::digest(payload, algo = "sha256", serialize = FALSE)
}

phase13_row_sha256 <- function(data, hash_col = "row_sha256") {
  if (!is.data.frame(data)) stop("Phase 13 row hashing requires a data frame", call. = FALSE)
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("digest is required for Phase 13 SHA-256 contracts", call. = FALSE)
  }
  fields <- setdiff(names(data), hash_col)
  vapply(seq_len(nrow(data)), function(index) {
    values <- vapply(data[index, fields, drop = FALSE], phase13_source_canonical_scalar, character(1))
    digest::digest(paste(values, collapse = "|"), algo = "sha256", serialize = FALSE)
  }, character(1))
}

phase13_source_require_columns <- function(data, required, name) {
  if (!is.data.frame(data)) stop(name, " must be a data frame", call. = FALSE)
  missing <- setdiff(required, names(data))
  if (length(missing)) stop(name, " missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  invisible(TRUE)
}

phase13_source_require_unique <- function(data, key, name) {
  if (anyDuplicated(data[key])) stop(name, " contains duplicate keys: ", paste(key, collapse = ", "), call. = FALSE)
  invisible(TRUE)
}

phase13_source_validate_resource_payload <- function(payload, artifact_type) {
  allowed <- phase13_source_required_resource_types()
  artifact_type <- phase13_source_scalar(artifact_type, "artifact_type")
  if (!artifact_type %in% allowed) {
    stop("Phase 13 structured resource class is unsupported: ", artifact_type, call. = FALSE)
  }
  nested_required <- phase13_source_resource_schema()[[artifact_type]]
  compact_required <- phase13_source_compact_resource_schema()[[artifact_type]]
  if (is.data.frame(payload)) {
    missing <- setdiff(compact_required, names(payload))
    if (length(missing)) {
      stop(
        "Phase 13 ", artifact_type, " resource schema is missing columns: ",
        paste(missing, collapse = ", "),
        call. = FALSE
      )
    }
    return(invisible(payload))
  }
  if (!is.list(payload) || !length(payload)) {
    stop("Phase 13 ", artifact_type, " resource schema is empty or null", call. = FALSE)
  }
  for (index in seq_along(payload)) {
    row <- payload[[index]]
    if (!is.list(row)) stop("Phase 13 ", artifact_type, " resource row must be structured", call. = FALSE)
    missing <- setdiff(nested_required, names(row))
    if (length(missing)) {
      stop(
        "Phase 13 ", artifact_type, " resource schema is missing fields: ",
        paste(missing, collapse = ", "),
        call. = FALSE
      )
    }
    if (identical(artifact_type, "fixtures")) {
      for (side in c("home", "away")) {
        team <- row[[side]]
        if (!is.list(team) || !all(c("uefa_source_team_id", "display_name") %in% names(team))) {
          stop("Phase 13 fixtures resource schema has incomplete ", side, " team fields", call. = FALSE)
        }
      }
    }
  }
  invisible(payload)
}

phase13_validate_structured_resource_payloads <- function(resource_payloads, edition_id = NULL) {
  if (!is.list(resource_payloads) || is.null(names(resource_payloads))) {
    stop("Phase 13 structured resource payloads must be a named list", call. = FALSE)
  }
  phase13_validate_structured_resource_names(names(resource_payloads))
  if (!is.null(edition_id)) phase13_source_scalar(edition_id, "edition_id")
  invisible(lapply(names(resource_payloads), function(artifact_type) {
    phase13_source_validate_resource_payload(resource_payloads[[artifact_type]], artifact_type)
  }))
}

phase13_source_scalar_or_na <- function(row, field) {
  value <- row[[field]]
  if (is.null(value) || !length(value) || is.na(value[[1L]])) return(NA_character_)
  as.character(value[[1L]])
}

phase13_source_flatten_resource_row <- function(row, artifact_type) {
  if (identical(artifact_type, "fixtures")) {
    return(data.frame(
      source_fixture_id = phase13_source_scalar_or_na(row, "source_fixture_id"),
      scheduled_at_utc = phase13_source_scalar_or_na(row, "scheduled_at_utc"),
      status = phase13_source_scalar_or_na(row, "status"),
      home_uefa_source_team_id = phase13_source_scalar_or_na(row$home, "uefa_source_team_id"),
      away_uefa_source_team_id = phase13_source_scalar_or_na(row$away, "uefa_source_team_id"),
      home_display_name = phase13_source_scalar_or_na(row$home, "display_name"),
      away_display_name = phase13_source_scalar_or_na(row$away, "display_name"),
      stringsAsFactors = FALSE
    ))
  }
  fields <- phase13_source_compact_resource_schema()[[artifact_type]]
  values <- lapply(fields, function(field) phase13_source_scalar_or_na(row, field))
  names(values) <- fields
  as.data.frame(values, stringsAsFactors = FALSE, check.names = FALSE)
}

phase13_source_resource_table <- function(payload, artifact_type, edition_id = NULL, source_artifact_id = NULL) {
  phase13_source_validate_resource_payload(payload, artifact_type)
  if (is.data.frame(payload)) {
    output <- payload
  } else {
    rows <- lapply(payload, phase13_source_flatten_resource_row, artifact_type = artifact_type)
    output <- do.call(rbind, rows)
  }
  if (!is.null(edition_id)) {
    edition_id <- phase13_source_scalar(edition_id, "edition_id")
    output$edition_id <- if (nrow(output)) edition_id else character(0)
  }
  if (!is.null(source_artifact_id)) {
    source_artifact_id <- phase13_source_scalar(source_artifact_id, "source_artifact_id")
    output$source_artifact_id <- if (nrow(output)) source_artifact_id else character(0)
  }
  output
}

phase13_source_validate_hash_column <- function(data, hash_col, name) {
  phase13_source_require_columns(data, hash_col, name)
  actual <- tolower(as.character(data[[hash_col]]))
  if (any(is.na(actual) | !grepl("^[0-9a-f]{64}$", actual))) {
    stop(name, " contains noncanonical SHA-256 values", call. = FALSE)
  }
  expected <- phase13_row_sha256(data, hash_col)
  if (any(actual != expected)) stop(name, " row SHA-256 mismatch", call. = FALSE)
  invisible(TRUE)
}

phase13_source_normalize_fallback_status <- function(value) {
  value <- tolower(phase13_source_scalar(value, "fallback_status"))
  aliases <- c(
    official = "official",
    fallback = "reviewed_fallback",
    manual_fallback = "reviewed_fallback",
    reviewed_fallback = "reviewed_fallback"
  )
  normalized <- unname(aliases[value])
  if (is.na(normalized)) stop("Phase 13 fallback status is unsupported: ", value, call. = FALSE)
  normalized
}

phase13_source_default_raw_path <- function(edition_id, bundle_id, artifact_type) {
  edition_id <- phase13_source_scalar(edition_id, "edition_id")
  bundle_id <- phase13_source_scalar(bundle_id, "bundle_id")
  artifact_type <- phase13_source_scalar(artifact_type, "artifact_type")
  phase13_source_safe_relative_path(
    file.path("data/competition/local_raw", edition_id, bundle_id, paste0(artifact_type, ".json"))
  )
}

phase13_source_validate_local_raw_path <- function(path) {
  path <- phase13_source_safe_relative_path(path)
  prefix <- "data/competition/local_raw/"
  if (!startsWith(path, prefix) || identical(path, prefix)) {
    stop("Phase 13 raw artifact path must remain inside data/competition/local_raw", call. = FALSE)
  }
  path
}

#' Build one compact artifact provenance row from exact response bytes.
phase13_build_source_artifact <- function(
    raw_bytes,
    artifact_id,
    bundle_id,
    edition_id,
    artifact_type,
    source_url,
    retrieved_at_utc,
    parser_commit_sha = NULL,
    fallback_status = "official",
    review_state = NULL,
    relative_local_raw_path = NULL,
    project_root = ".") {
  raw_bytes <- phase13_source_raw_bytes(raw_bytes)
  if (!length(raw_bytes)) stop("Phase 13 source artifact raw bytes must not be empty", call. = FALSE)
  artifact_id <- phase13_source_scalar(artifact_id, "artifact_id")
  bundle_id <- phase13_source_scalar(bundle_id, "bundle_id")
  edition_id <- phase13_source_scalar(edition_id, "edition_id")
  artifact_type <- phase13_source_scalar(artifact_type, "artifact_type")
  if (!artifact_type %in% phase13_source_required_resource_types()) {
    stop("Phase 13 source artifact type is unsupported: ", artifact_type, call. = FALSE)
  }
  source_url <- phase13_source_scalar(source_url, "source_url")
  retrieved_at_utc <- phase13_source_scalar(retrieved_at_utc, "retrieved_at_utc")
  fallback_status <- phase13_source_normalize_fallback_status(fallback_status)
  phase13_source_validate_structured_bytes(raw_bytes, artifact_type)
  parser_commit_sha <- if (is.null(parser_commit_sha)) phase13_parser_commit_sha(project_root) else phase13_source_scalar(parser_commit_sha, "parser_commit_sha")
  if (!grepl("^[0-9a-fA-F]{7,64}$", parser_commit_sha)) stop("Phase 13 parser_commit_sha must be a Git SHA", call. = FALSE)
  review_state <- if (is.null(review_state)) {
    if (identical(fallback_status, "reviewed_fallback")) "approved" else "not_required"
  } else phase13_source_scalar(review_state, "review_state")
  relative_local_raw_path <- if (is.null(relative_local_raw_path)) {
    phase13_source_default_raw_path(edition_id, bundle_id, artifact_type)
  } else phase13_source_validate_local_raw_path(relative_local_raw_path)

  row <- data.frame(
    schema_version = "phase13-source-artifact-v1",
    artifact_id = artifact_id,
    bundle_id = bundle_id,
    edition_id = edition_id,
    artifact_type = artifact_type,
    source_url = source_url,
    retrieved_at_utc = retrieved_at_utc,
    bytes = as.integer(length(raw_bytes)),
    raw_sha256 = phase13_source_sha256(raw_bytes),
    parser_commit_sha = tolower(parser_commit_sha),
    fallback_status = fallback_status,
    review_state = review_state,
    relative_local_raw_path = relative_local_raw_path,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  row$row_sha256 <- phase13_row_sha256(row)
  row
}

phase13_source_fallback_metadata <- function(
    fallback_status,
    fallback_source = "",
    fallback_retrieval_date = "",
    fallback_reason = "",
    operator_note = "",
    fallback_checksum = "") {
  fallback_status <- phase13_source_normalize_fallback_status(fallback_status)
  data.frame(
    fallback_source = phase13_source_scalar(fallback_source, "fallback_source", allow_empty = TRUE),
    fallback_retrieval_date = phase13_source_scalar(fallback_retrieval_date, "fallback_retrieval_date", allow_empty = TRUE),
    fallback_reason = phase13_source_scalar(fallback_reason, "fallback_reason", allow_empty = TRUE),
    operator_note = phase13_source_scalar(operator_note, "operator_note", allow_empty = TRUE),
    fallback_checksum = phase13_source_scalar(fallback_checksum, "fallback_checksum", allow_empty = TRUE),
    stringsAsFactors = FALSE
  )
}

phase13_source_manifest_self_sha256 <- function(bundle, artifacts) {
  if (!is.data.frame(bundle) || nrow(bundle) != 1L) {
    stop("Phase 13 source manifest self-hash requires one bundle row", call. = FALSE)
  }
  phase13_validate_source_artifacts(artifacts)
  bundle_body <- bundle[, setdiff(names(bundle), c("row_sha256", "manifest_self_sha256")), drop = FALSE]
  artifact_body <- artifacts[, setdiff(names(artifacts), c("row_sha256")), drop = FALSE]
  digest::digest(
    paste(
      phase13_canonical_sha256(bundle_body, key = "bundle_id"),
      phase13_canonical_sha256(artifact_body, key = "artifact_id"),
      sep = "\x1e"
    ),
    algo = "sha256",
    serialize = FALSE
  )
}

#' Build one edition-scoped bundle row from its component artifact rows.
phase13_build_source_bundle <- function(
    bundle_id,
    edition_id,
    artifacts,
    bundle_status = "accepted",
    fallback_status = NULL,
    parser_commit_sha = NULL,
    acceptance_state = NULL,
    accepted_at_utc = NULL,
    last_accepted_bundle_id = NULL,
    fallback_source = "",
    fallback_retrieval_date = "",
    fallback_reason = "",
    operator_note = "",
    fallback_checksum = "") {
  bundle_id <- phase13_source_scalar(bundle_id, "bundle_id")
  edition_id <- phase13_source_scalar(edition_id, "edition_id")
  bundle_status <- phase13_source_scalar(bundle_status, "bundle_status")
  phase13_validate_source_artifacts(artifacts)
  if (any(as.character(artifacts$bundle_id) != bundle_id) || any(as.character(artifacts$edition_id) != edition_id)) {
    stop("Phase 13 source artifacts do not belong to the requested bundle and edition", call. = FALSE)
  }
  artifact_status <- unique(as.character(artifacts$fallback_status))
  if (is.null(fallback_status)) fallback_status <- artifact_status[[1L]]
  fallback_status <- phase13_source_normalize_fallback_status(fallback_status)
  if (length(artifact_status) != 1L || !identical(artifact_status[[1L]], fallback_status)) {
    stop("Phase 13 source bundle cannot mix official and fallback artifacts", call. = FALSE)
  }
  artifact_parser <- unique(tolower(as.character(artifacts$parser_commit_sha)))
  if (is.null(parser_commit_sha)) parser_commit_sha <- artifact_parser[[1L]]
  parser_commit_sha <- tolower(phase13_source_scalar(parser_commit_sha, "parser_commit_sha"))
  if (length(artifact_parser) != 1L || !identical(artifact_parser[[1L]], parser_commit_sha)) {
    stop("Phase 13 source bundle parser identity drifted across artifacts", call. = FALSE)
  }
  if (is.null(accepted_at_utc)) accepted_at_utc <- as.character(artifacts$retrieved_at_utc[[1L]])
  accepted_at_utc <- phase13_source_scalar(accepted_at_utc, "accepted_at_utc")
  if (is.null(acceptance_state)) acceptance_state <- if (identical(fallback_status, "official")) "accepted" else "reviewed"
  acceptance_state <- phase13_source_scalar(acceptance_state, "acceptance_state")
  if (is.null(last_accepted_bundle_id)) last_accepted_bundle_id <- if (identical(bundle_status, "accepted")) bundle_id else ""
  last_accepted_bundle_id <- phase13_source_scalar(last_accepted_bundle_id, "last_accepted_bundle_id", allow_empty = TRUE)
  fallback <- phase13_source_fallback_metadata(
    fallback_status, fallback_source, fallback_retrieval_date, fallback_reason,
    operator_note, fallback_checksum
  )
  artifact_hash <- phase13_canonical_sha256(artifacts, key = "artifact_id")
  row <- data.frame(
    schema_version = "phase13-source-bundle-v1",
    bundle_id = bundle_id,
    edition_id = edition_id,
    bundle_status = bundle_status,
    acceptance_state = acceptance_state,
    fallback_status = fallback_status,
    parser_commit_sha = parser_commit_sha,
    artifact_count = as.integer(nrow(artifacts)),
    required_resource_count = as.integer(length(phase13_source_required_resource_types())),
    source_bundle_sha256 = artifact_hash,
    artifact_manifest_sha256 = artifact_hash,
    accepted_at_utc = accepted_at_utc,
    last_accepted_bundle_id = last_accepted_bundle_id,
    fallback_source = fallback$fallback_source,
    fallback_retrieval_date = fallback$fallback_retrieval_date,
    fallback_reason = fallback$fallback_reason,
    operator_note = fallback$operator_note,
    fallback_checksum = fallback$fallback_checksum,
    manifest_self_sha256 = "",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  row$manifest_self_sha256 <- phase13_source_manifest_self_sha256(row, artifacts)
  row$row_sha256 <- phase13_row_sha256(row)
  row
}

phase13_validate_source_artifacts <- function(artifacts, raw_bytes_by_artifact = NULL) {
  required <- c(
    "schema_version", "artifact_id", "bundle_id", "edition_id", "artifact_type",
    "source_url", "retrieved_at_utc", "bytes", "raw_sha256", "parser_commit_sha",
    "fallback_status", "review_state", "relative_local_raw_path", "row_sha256"
  )
  phase13_source_require_columns(artifacts, required, "Phase 13 source artifacts")
  if (!nrow(artifacts)) stop("Phase 13 source artifacts must not be empty", call. = FALSE)
  phase13_source_require_unique(artifacts, "artifact_id", "Phase 13 source artifacts")
  if (any(is.na(artifacts$source_url) | !nzchar(as.character(artifacts$source_url))) ||
      any(is.na(artifacts$retrieved_at_utc) | !nzchar(as.character(artifacts$retrieved_at_utc))) ||
      any(is.na(artifacts$parser_commit_sha) | !grepl("^[0-9a-fA-F]{7,64}$", as.character(artifacts$parser_commit_sha)))) {
    stop("Phase 13 source artifacts contain incomplete provenance", call. = FALSE)
  }
  if (any(is.na(artifacts$bytes) | !is.finite(as.numeric(artifacts$bytes)) | as.numeric(artifacts$bytes) <= 0)) {
    stop("Phase 13 source artifacts require positive raw byte counts", call. = FALSE)
  }
  if (any(is.na(artifacts$raw_sha256) | !grepl("^[0-9a-fA-F]{64}$", as.character(artifacts$raw_sha256)))) {
    stop("Phase 13 source artifacts contain invalid raw SHA-256 values", call. = FALSE)
  }
  if (any(is.na(artifacts$artifact_type) | !as.character(artifacts$artifact_type) %in% phase13_source_required_resource_types())) {
    stop("Phase 13 source artifacts contain an unknown or missing required resource type", call. = FALSE)
  }
  if (any(is.na(artifacts$fallback_status) | !as.character(artifacts$fallback_status) %in% c("official", "reviewed_fallback"))) {
    stop("Phase 13 source artifacts contain an unsupported fallback status", call. = FALSE)
  }
  if (any(is.na(artifacts$review_state) | !nzchar(as.character(artifacts$review_state)))) {
    stop("Phase 13 source artifacts require review state metadata", call. = FALSE)
  }
  invisible(lapply(as.character(artifacts$relative_local_raw_path), phase13_source_validate_local_raw_path))
  if (length(unique(as.character(artifacts$fallback_status))) != 1L) {
    stop("Phase 13 source artifacts cannot mix official and fallback statuses", call. = FALSE)
  }
  phase13_source_validate_hash_column(artifacts, "row_sha256", "Phase 13 source artifacts")
  if (!is.null(raw_bytes_by_artifact)) {
    if (!is.list(raw_bytes_by_artifact) || is.null(names(raw_bytes_by_artifact))) {
      stop("Phase 13 raw byte verification requires a named list", call. = FALSE)
    }
    if (!setequal(names(raw_bytes_by_artifact), as.character(artifacts$artifact_id))) {
      stop("Phase 13 raw byte verification must cover every source artifact", call. = FALSE)
    }
    for (artifact_id in names(raw_bytes_by_artifact)) {
      if (!artifact_id %in% artifacts$artifact_id) stop("Phase 13 raw byte verification references an unknown artifact", call. = FALSE)
      bytes <- phase13_source_raw_bytes(raw_bytes_by_artifact[[artifact_id]])
      phase13_source_validate_structured_bytes(bytes, artifacts$artifact_type[artifacts$artifact_id == artifact_id][[1L]])
      row <- artifacts[artifacts$artifact_id == artifact_id, , drop = FALSE]
      if (nrow(row) != 1L || as.integer(row$bytes) != length(bytes) || !identical(tolower(row$raw_sha256), phase13_source_sha256(bytes))) {
        stop("Phase 13 source artifact raw byte hash mismatch: ", artifact_id, call. = FALSE)
      }
    }
  }
  invisible(artifacts)
}

phase13_validate_fallback_review_metadata <- function(bundle, artifacts) {
  phase13_source_require_columns(
    bundle,
    c(
      "fallback_status", "acceptance_state", "fallback_source", "fallback_retrieval_date",
      "fallback_reason", "operator_note", "fallback_checksum"
    ),
    "Phase 13 source bundle"
  )
  phase13_source_require_columns(artifacts, c("fallback_status", "review_state"), "Phase 13 source artifacts")
  fallback_status <- as.character(bundle$fallback_status[[1L]])
  if (!fallback_status %in% c("official", "reviewed_fallback")) {
    stop("Phase 13 fallback review metadata has unsupported status", call. = FALSE)
  }
  if (length(unique(as.character(artifacts$fallback_status))) != 1L ||
      !identical(as.character(artifacts$fallback_status[[1L]]), fallback_status)) {
    stop("Phase 13 fallback review metadata is not edition-wide", call. = FALSE)
  }
  if (identical(fallback_status, "official")) {
    if (!identical(as.character(bundle$acceptance_state[[1L]]), "accepted")) {
      stop("Phase 13 official source bundle must have accepted state", call. = FALSE)
    }
    return(invisible(TRUE))
  }
  fields <- c("fallback_source", "fallback_retrieval_date", "fallback_reason", "operator_note", "fallback_checksum")
  if (any(is.na(bundle[fields][1L, ]) | !nzchar(as.character(bundle[fields][1L, ])))) {
    stop("Phase 13 reviewed fallback bundle has incomplete review metadata", call. = FALSE)
  }
  if (!grepl("^[0-9a-fA-F]{64}$", as.character(bundle$fallback_checksum[[1L]])) ||
      !identical(as.character(bundle$acceptance_state[[1L]]), "reviewed") ||
      any(as.character(artifacts$review_state) != "approved")) {
    stop("Phase 13 reviewed fallback bundle requires approved review metadata", call. = FALSE)
  }
  invisible(TRUE)
}

phase13_validate_source_bundle <- function(bundle, artifacts) {
  required <- c(
    "schema_version", "bundle_id", "edition_id", "bundle_status", "acceptance_state",
    "fallback_status", "parser_commit_sha", "artifact_count", "required_resource_count",
    "source_bundle_sha256", "artifact_manifest_sha256", "accepted_at_utc",
    "last_accepted_bundle_id", "fallback_source", "fallback_retrieval_date",
    "fallback_reason", "operator_note", "fallback_checksum", "manifest_self_sha256", "row_sha256"
  )
  phase13_source_require_columns(bundle, required, "Phase 13 source bundle")
  if (nrow(bundle) != 1L) stop("Phase 13 source bundle must contain exactly one row", call. = FALSE)
  phase13_validate_source_artifacts(artifacts)
  bundle <- bundle[1L, , drop = FALSE]
  if (any(as.character(artifacts$bundle_id) != as.character(bundle$bundle_id)) ||
      any(as.character(artifacts$edition_id) != as.character(bundle$edition_id))) {
    stop("Phase 13 source bundle foreign keys do not match artifacts", call. = FALSE)
  }
  if (as.integer(bundle$artifact_count) != nrow(artifacts) ||
      as.integer(bundle$required_resource_count) != length(phase13_source_required_resource_types())) {
    stop("Phase 13 source bundle artifact counts are incomplete", call. = FALSE)
  }
  if (!setequal(as.character(artifacts$artifact_type), phase13_source_required_resource_types()) ||
      anyDuplicated(as.character(artifacts$artifact_type))) {
    stop("Phase 13 source bundle is missing a required resource class", call. = FALSE)
  }
  fallback <- unique(as.character(artifacts$fallback_status))
  if (length(fallback) != 1L || !identical(fallback[[1L]], as.character(bundle$fallback_status))) {
    stop("Phase 13 source bundle cannot mix official and fallback artifacts", call. = FALSE)
  }
  parser <- unique(tolower(as.character(artifacts$parser_commit_sha)))
  if (length(parser) != 1L || !identical(parser[[1L]], tolower(as.character(bundle$parser_commit_sha)))) {
    stop("Phase 13 source bundle parser identity does not match artifacts", call. = FALSE)
  }
  artifact_hash <- phase13_canonical_sha256(artifacts, key = "artifact_id")
  if (!identical(tolower(as.character(bundle$source_bundle_sha256)), artifact_hash) ||
      !identical(tolower(as.character(bundle$artifact_manifest_sha256)), artifact_hash)) {
    stop("Phase 13 source bundle artifact manifest hash mismatch", call. = FALSE)
  }
  if (is.na(bundle$manifest_self_sha256[[1L]]) || !grepl("^[0-9a-fA-F]{64}$", as.character(bundle$manifest_self_sha256[[1L]])) ||
      !identical(tolower(as.character(bundle$manifest_self_sha256[[1L]])), tolower(phase13_source_manifest_self_sha256(bundle, artifacts)))) {
    stop("Phase 13 source bundle manifest self-hash mismatch", call. = FALSE)
  }
  if (!identical(as.character(bundle$bundle_status), "accepted")) {
    stop("Phase 13 source bundle is not accepted", call. = FALSE)
  }
  if (!nzchar(as.character(bundle$last_accepted_bundle_id))) {
    stop("Phase 13 accepted source bundle must retain a last accepted bundle ID", call. = FALSE)
  }
  phase13_validate_fallback_review_metadata(bundle, artifacts)
  phase13_source_validate_hash_column(bundle, "row_sha256", "Phase 13 source bundle")
  invisible(bundle)
}

phase13_accept_source_bundle <- function(..., artifacts = NULL) {
  if (is.null(artifacts)) {
    values <- list(...)
    artifacts <- values$artifacts
    values$artifacts <- NULL
    bundle <- do.call(phase13_build_source_bundle, c(values, list(artifacts = artifacts)))
  } else {
    bundle <- phase13_build_source_bundle(..., artifacts = artifacts)
  }
  phase13_validate_source_bundle(bundle, artifacts)
  list(bundle = bundle, artifacts = artifacts)
}

#' Serialize compact structured resource payloads and accept one bundle.
phase13_capture_structured_bundle <- function(
    resource_payloads,
    edition_id,
    bundle_id,
    source_urls,
    retrieved_at_utc,
    fallback_status = "official",
    parser_commit_sha = NULL,
    project_root = ".",
    raw_bytes_by_resource = NULL,
    ...) {
  if (!is.list(resource_payloads) || is.null(names(resource_payloads))) {
    stop("Phase 13 structured resource payloads must be a named list", call. = FALSE)
  }
  required <- phase13_source_required_resource_types()
  phase13_validate_structured_resource_payloads(resource_payloads, edition_id = edition_id)
  if (is.null(names(source_urls))) source_urls <- setNames(rep(source_urls, length(required)), required)
  source_url_values <- as.character(source_urls[required])
  if (!setequal(names(source_urls), required) || any(is.na(source_url_values) | !nzchar(source_url_values))) {
    stop("Phase 13 structured resources require one source URL per resource class", call. = FALSE)
  }
  if (!is.null(raw_bytes_by_resource) && (!is.list(raw_bytes_by_resource) || is.null(names(raw_bytes_by_resource)) ||
      !setequal(names(raw_bytes_by_resource), required))) {
    stop("Phase 13 raw bytes must be supplied for every named resource class", call. = FALSE)
  }
  parser_commit_sha <- if (is.null(parser_commit_sha)) phase13_parser_commit_sha(project_root) else parser_commit_sha
  artifact_rows <- lapply(required, function(artifact_type) {
    payload <- resource_payloads[[artifact_type]]
    raw_text <- if (!is.null(raw_bytes_by_resource)) {
      raw_bytes_by_resource[[artifact_type]]
    } else if (requireNamespace("jsonlite", quietly = TRUE)) {
      jsonlite::toJSON(payload, auto_unbox = TRUE, pretty = FALSE, null = "null", digits = 17)
    } else {
      stop("jsonlite is required to serialize Phase 13 structured resources", call. = FALSE)
    }
    url <- source_urls[[artifact_type]]
    if (is.null(url)) stop("Phase 13 structured resource is missing source URL: ", artifact_type, call. = FALSE)
    phase13_build_source_artifact(
      raw_bytes = raw_text,
      artifact_id = paste(bundle_id, artifact_type, sep = "-"),
      bundle_id = bundle_id,
      edition_id = edition_id,
      artifact_type = artifact_type,
      source_url = url,
      retrieved_at_utc = retrieved_at_utc,
      parser_commit_sha = parser_commit_sha,
      fallback_status = fallback_status,
      project_root = project_root
    )
  })
  artifacts <- do.call(rbind, artifact_rows)
  accepted <- phase13_accept_source_bundle(
    bundle_id = bundle_id,
    edition_id = edition_id,
    artifacts = artifacts,
    fallback_status = fallback_status,
    parser_commit_sha = parser_commit_sha,
    accepted_at_utc = retrieved_at_utc,
    ...
  )
  if (!is.null(raw_bytes_by_resource)) {
    raw_bytes_by_artifact <- raw_bytes_by_resource
    names(raw_bytes_by_artifact) <- paste(bundle_id, names(raw_bytes_by_artifact), sep = "-")
    phase13_validate_source_artifacts(artifacts, raw_bytes_by_artifact)
  }
  accepted$resources <- resource_payloads
  accepted$raw_bytes_by_resource <- raw_bytes_by_resource
  accepted
}

# Short aliases used by later Phase 13 capture code and tests.
validate_phase13_source_bundle <- phase13_validate_source_bundle
validate_phase13_source_artifacts <- phase13_validate_source_artifacts

phase13_source_registry_tables <- function(bundle, artifacts) {
  phase13_validate_source_bundle(bundle, artifacts)
  list(
    source_bundles = bundle,
    source_artifacts = artifacts
  )
}

phase13_source_write_csv <- function(data, path) {
  if (!is.data.frame(data)) stop("Phase 13 CSV writer requires a data frame", call. = FALSE)
  if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path)) {
    stop("Phase 13 CSV writer requires one non-empty path", call. = FALSE)
  }
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  staged <- tempfile(paste0(".", basename(path), "-"), tmpdir = dirname(path))
  on.exit(if (file.exists(staged)) unlink(staged), add = TRUE)
  utils::write.csv(data, staged, row.names = FALSE, na = "", quote = TRUE)
  if (!file.rename(staged, path)) stop("Could not publish Phase 13 CSV: ", path, call. = FALSE)
  invisible(path)
}

phase13_source_write_text <- function(text, path) {
  if (!is.character(text) || length(text) != 1L || is.na(text)) {
    stop("Phase 13 text writer requires one non-missing string", call. = FALSE)
  }
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  staged <- tempfile(paste0(".", basename(path), "-"), tmpdir = dirname(path))
  on.exit(if (file.exists(staged)) unlink(staged), add = TRUE)
  writeLines(enc2utf8(text), staged, useBytes = TRUE)
  if (!file.rename(staged, path)) stop("Could not publish Phase 13 text: ", path, call. = FALSE)
  invisible(path)
}

phase13_source_write_json <- function(value, path) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("jsonlite is required for Phase 13 JSON writes", call. = FALSE)
  }
  phase13_source_write_text(
    jsonlite::toJSON(value, auto_unbox = TRUE, pretty = TRUE, null = "null", na = "string", digits = 17),
    path
  )
}

phase13_source_manifest_table <- function(bundle, artifacts) {
  phase13_validate_source_bundle(bundle, artifacts)
  bundle_fields <- c(
    "schema_version", "bundle_id", "edition_id", "bundle_status", "acceptance_state",
    "fallback_status", "parser_commit_sha", "artifact_count", "required_resource_count",
    "source_bundle_sha256", "artifact_manifest_sha256", "manifest_self_sha256",
    "accepted_at_utc", "last_accepted_bundle_id", "fallback_source", "fallback_retrieval_date",
    "fallback_reason", "operator_note", "fallback_checksum"
  )
  artifact_fields <- c(
    "artifact_id", "artifact_type", "source_url", "retrieved_at_utc", "bytes", "raw_sha256",
    "parser_commit_sha", "fallback_status", "review_state", "relative_local_raw_path", "row_sha256"
  )
  output <- cbind(
    bundle[rep(1L, nrow(artifacts)), bundle_fields, drop = FALSE],
    artifacts[, artifact_fields, drop = FALSE]
  )
  output
}
