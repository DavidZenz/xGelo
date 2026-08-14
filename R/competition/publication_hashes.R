#' Deterministic canonical table and source-artifact hash regeneration.
#'
#' This module owns the pure hash/projection slice of Phase 13 publication. It
#' may rewrite files below an already-created staging root, but it never takes
#' locks, snapshots, promotes targets, or performs rollback. Those concerns
#' belong to R/competition/publication_transaction.R.

phase13_publication_editions <- function() {
  c("uefa_nations_league_2026_27", "uefa_euro_2028_qualifying")
}

phase13_publication_resource_types <- function() {
  c("fixtures", "groups", "standings", "results", "status")
}

phase13_publication_key <- function(edition_id, artifact_type) {
  paste(as.character(edition_id), as.character(artifact_type), sep = "::")
}

phase13_publication_scalar <- function(value, name, allow_empty = FALSE) {
  if (length(value) != 1L || is.null(value) || is.na(value)) {
    stop("Phase 13 publication ", name, " must be one non-missing value", call. = FALSE)
  }
  value <- as.character(value[[1L]])
  if (!allow_empty && !nzchar(value)) {
    stop("Phase 13 publication ", name, " must not be empty", call. = FALSE)
  }
  value
}

phase13_publication_project_root <- function(staged_root) {
  if (!is.character(staged_root) || length(staged_root) != 1L || is.na(staged_root) || !nzchar(staged_root)) {
    stop("Phase 13 publication staged root must be one non-empty path", call. = FALSE)
  }
  normalizePath(staged_root, winslash = "/", mustWork = TRUE)
}

phase13_publication_path_within <- function(path, root) {
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  root <- normalizePath(root, winslash = "/", mustWork = FALSE)
  identical(path, root) || startsWith(path, paste0(root, "/"))
}

phase13_publication_resolve_path <- function(staged_root, path) {
  staged_root <- phase13_publication_project_root(staged_root)
  path <- gsub("\\\\", "/", as.character(path))
  if (length(path) != 1L || is.na(path) || !nzchar(path) ||
      grepl("(^|/)\\.\\.?(/|$)", path) || grepl("^[A-Za-z]:", path)) {
    stop("Phase 13 publication target path is unsafe: ", path, call. = FALSE)
  }
  candidate <- if (grepl("^/", path)) path else file.path(staged_root, path)
  accepted_root <- normalizePath(
    file.path(staged_root, "data/competition/accepted"),
    winslash = "/",
    mustWork = FALSE
  )
  candidate <- normalizePath(candidate, winslash = "/", mustWork = FALSE)
  if (!phase13_publication_path_within(candidate, accepted_root)) {
    stop("Phase 13 publication target must remain inside data/competition/accepted", call. = FALSE)
  }
  candidate
}

phase13_normalized_resource_targets <- function(
    staged_root,
    editions = phase13_publication_editions(),
    resource_types = phase13_publication_resource_types()) {
  staged_root <- phase13_publication_project_root(staged_root)
  editions <- as.character(editions)
  resource_types <- as.character(resource_types)
  expected_editions <- phase13_publication_editions()
  expected_types <- phase13_publication_resource_types()
  if (!length(editions) || anyDuplicated(editions) || !setequal(editions, expected_editions)) {
    stop("Phase 13 normalized publication target editions must be the two unique registered editions", call. = FALSE)
  }
  if (!length(resource_types) || anyDuplicated(resource_types) || !setequal(resource_types, expected_types)) {
    stop("Phase 13 normalized publication target resource classes must be the five unique required classes", call. = FALSE)
  }
  paths <- unlist(lapply(editions, function(edition_id) {
    file.path(
      staged_root,
      "data/competition/accepted",
      edition_id,
      paste0(resource_types, ".csv")
    )
  }), use.names = FALSE)
  keys <- unlist(lapply(editions, function(edition_id) {
    phase13_publication_key(edition_id, resource_types)
  }), use.names = FALSE)
  stats <- setNames(paths, keys)
  phase13_publication_validate_resource_targets(staged_root, stats, require_files = FALSE)
}

# Explicit alias for callers that use the transaction terminology.
phase13_normalized_publication_resource_targets <- phase13_normalized_resource_targets

phase13_publication_validate_resource_targets <- function(
    staged_root,
    table_targets,
    require_files = TRUE) {
  staged_root <- phase13_publication_project_root(staged_root)
  if (!is.character(table_targets) || !length(table_targets)) {
    stop("Phase 13 normalized publication requires a declared resource target vector", call. = FALSE)
  }
  if (anyDuplicated(as.character(table_targets))) {
    stop("Phase 13 normalized publication resource targets contain duplicate paths", call. = FALSE)
  }

  expected_keys <- unlist(lapply(phase13_publication_editions(), function(edition_id) {
    phase13_publication_key(edition_id, phase13_publication_resource_types())
  }), use.names = FALSE)
  resolved <- vapply(table_targets, function(path) phase13_publication_resolve_path(staged_root, path), character(1))
  if (anyDuplicated(resolved)) {
    stop("Phase 13 normalized publication resource targets contain duplicate paths", call. = FALSE)
  }

  accepted_root <- normalizePath(file.path(staged_root, "data/competition/accepted"), winslash = "/", mustWork = FALSE)
  path_keys <- vapply(resolved, function(path) {
    relative <- substring(path, nchar(accepted_root) + 2L)
    pieces <- strsplit(relative, "/", fixed = TRUE)[[1L]]
    if (length(pieces) != 2L) {
      stop("Phase 13 normalized publication resource target path is malformed: ", path, call. = FALSE)
    }
    edition_id <- pieces[[1L]]
    filename <- pieces[[2L]]
    if (!grepl("^[A-Za-z0-9][A-Za-z0-9_-]*\\.csv$", filename)) {
      stop("Phase 13 normalized publication resource target must be a trusted CSV path: ", path, call. = FALSE)
    }
    artifact_type <- sub("\\.csv$", "", filename)
    key <- phase13_publication_key(edition_id, artifact_type)
    if (!key %in% expected_keys) {
      stop("Phase 13 normalized publication target crosses an edition or resource boundary: ", path, call. = FALSE)
    }
    key
  }, character(1))
  if (!is.null(names(table_targets)) && any(nzchar(names(table_targets)))) {
    supplied_names <- as.character(names(table_targets))
    if (anyDuplicated(supplied_names) || !setequal(supplied_names, expected_keys) ||
        any(supplied_names != path_keys)) {
      stop("Phase 13 normalized publication target names do not match their trusted edition/resource paths", call. = FALSE)
    }
  } else {
    names(resolved) <- path_keys
  }
  if (!setequal(path_keys, expected_keys) || length(path_keys) != length(expected_keys)) {
    stop("Phase 13 normalized publication target graph must contain exactly ten resource tables", call. = FALSE)
  }
  if (isTRUE(require_files) && any(!file.exists(resolved))) {
    missing <- resolved[!file.exists(resolved)]
    stop("Phase 13 normalized publication resource table is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  resolved <- resolved[expected_keys]
  names(resolved) <- expected_keys
  resolved
}

phase13_publication_table_schema <- function(artifact_type) {
  artifact_type <- phase13_publication_scalar(artifact_type, "artifact_type")
  if (artifact_type == "fixtures") {
    return(phase13_normalized_fixture_schema())
  }
  if (artifact_type == "results") {
    return(phase13_normalized_result_schema())
  }
  compact <- phase13_source_compact_resource_schema()[[artifact_type]]
  if (is.null(compact)) stop("Phase 13 publication resource class is unsupported: ", artifact_type, call. = FALSE)
  c("schema_version", compact, "edition_id", "source_artifact_id", "row_sha256")
}

phase13_publication_validate_table_shape <- function(table, edition_id, artifact_type, path) {
  if (!is.data.frame(table)) stop("Phase 13 publication resource is not a data frame: ", path, call. = FALSE)
  expected <- phase13_publication_table_schema(artifact_type)
  if (!identical(names(table), expected)) {
    stop(
      "Phase 13 publication resource schema mismatch for ", edition_id, "/", artifact_type,
      "; expected exact normalized or source-shaped columns",
      call. = FALSE
    )
  }
  if (anyDuplicated(names(table))) stop("Phase 13 publication resource schema contains duplicate columns: ", path, call. = FALSE)
  if (nrow(table)) {
    edition_values <- as.character(table$edition_id)
    if (any(is.na(edition_values) | edition_values != edition_id)) {
      stop("Phase 13 publication resource has a cross-edition row: ", path, call. = FALSE)
    }
    artifact_values <- as.character(table$source_artifact_id)
    if (any(is.na(artifact_values) | !nzchar(trimws(artifact_values)))) {
      stop("Phase 13 publication resource has missing source-artifact lineage: ", path, call. = FALSE)
    }
  }
  invisible(table)
}

phase13_publication_sort_table <- function(table) {
  hash_col <- if ("row_sha256" %in% names(table)) "row_sha256" else NULL
  fields <- setdiff(names(table), hash_col)
  if (nrow(table) > 1L && length(fields)) {
    values <- lapply(table[fields], function(column) {
      vapply(column, phase13_source_canonical_scalar, character(1))
    })
    table <- table[do.call(order, c(values, list(na.last = TRUE, method = "radix"))), , drop = FALSE]
  }
  row.names(table) <- NULL
  table
}

phase13_publication_csv_bytes <- function(table) {
  path <- tempfile("phase13-publication-table-", fileext = ".csv")
  on.exit(if (file.exists(path)) unlink(path), add = TRUE)
  utils::write.csv(table, path, row.names = FALSE, na = "", quote = TRUE)
  readBin(path, what = "raw", n = file.info(path)$size)
}

phase13_publication_file_sha256 <- function(path) {
  if (!file.exists(path)) stop("Phase 13 publication file is missing: ", path, call. = FALSE)
  phase13_source_sha256(readBin(path, what = "raw", n = file.info(path)$size))
}

phase13_publication_write_csv <- function(table, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  staged <- tempfile(paste0(".", basename(path), "-"), tmpdir = dirname(path))
  on.exit(if (file.exists(staged)) unlink(staged), add = TRUE)
  utils::write.csv(table, staged, row.names = FALSE, na = "", quote = TRUE)
  if (!file.rename(staged, path)) stop("Could not write staged Phase 13 publication CSV: ", path, call. = FALSE)
  invisible(path)
}

phase13_publication_read_source_artifacts <- function(staged_root, source_artifacts = NULL) {
  path <- file.path(staged_root, "data/competition/registries/source_artifacts.csv")
  output <- if (is.null(source_artifacts)) {
    if (!file.exists(path)) stop("Phase 13 source artifact registry is missing: ", path, call. = FALSE)
    utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  } else {
    if (!is.data.frame(source_artifacts)) stop("Phase 13 source artifacts must be a data frame or staged CSV", call. = FALSE)
    source_artifacts
  }
  required <- c(
    "schema_version", "artifact_id", "bundle_id", "edition_id", "artifact_type",
    "source_url", "retrieved_at_utc", "bytes", "raw_sha256", "parser_commit_sha",
    "fallback_status", "review_state", "relative_local_raw_path", "row_sha256",
    "source_artifact_id", "source_url_lineage", "status_provenance", "canonical_content_sha256"
  )
  missing <- setdiff(required, names(output))
  if (length(missing)) stop("Phase 13 source artifact registry is missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  output <- as.data.frame(output, stringsAsFactors = FALSE, check.names = FALSE)
  if (!nrow(output)) stop("Phase 13 source artifact registry must not be empty", call. = FALSE)
  if (anyDuplicated(as.character(output$artifact_id))) stop("Phase 13 source artifact registry contains duplicate artifact IDs", call. = FALSE)
  if (anyDuplicated(paste(output$edition_id, output$artifact_type, sep = "::"))) {
    stop("Phase 13 source artifact registry contains duplicate edition/resource links", call. = FALSE)
  }
  if (any(!as.character(output$artifact_type) %in% phase13_publication_resource_types())) {
    stop("Phase 13 source artifact registry contains an unknown resource class", call. = FALSE)
  }
  if (any(!as.character(output$fallback_status) %in% c("official", "reviewed_fallback"))) {
    stop("Phase 13 source artifact registry contains an unsupported fallback status", call. = FALSE)
  }
  if (any(is.na(output$raw_sha256) | !grepl("^[0-9a-fA-F]{64}$", as.character(output$raw_sha256)))) {
    stop("Phase 13 source artifact registry contains invalid raw SHA-256 values", call. = FALSE)
  }
  if (any(is.na(output$source_url) | !nzchar(as.character(output$source_url))) ||
      any(is.na(output$retrieved_at_utc) | !nzchar(as.character(output$retrieved_at_utc))) ||
      any(is.na(output$parser_commit_sha) | !grepl("^[0-9a-fA-F]{7,64}$", as.character(output$parser_commit_sha)))) {
    stop("Phase 13 source artifact registry contains incomplete provenance", call. = FALSE)
  }
  source_artifact_missing <- is.na(output$source_artifact_id) | !nzchar(as.character(output$source_artifact_id))
  bundle_missing <- is.na(output$bundle_id) | !nzchar(as.character(output$bundle_id))
  edition_missing <- is.na(output$edition_id) | !nzchar(as.character(output$edition_id))
  if (any(source_artifact_missing) || any(bundle_missing | edition_missing)) {
    stop("Phase 13 source artifact registry contains malformed source-artifact links", call. = FALSE)
  }
  expected_editions <- phase13_publication_editions()
  for (edition_id in expected_editions) {
    rows <- output[as.character(output$edition_id) == edition_id, , drop = FALSE]
    if (nrow(rows) != length(phase13_publication_resource_types()) ||
        !setequal(as.character(rows$artifact_type), phase13_publication_resource_types())) {
      stop("Phase 13 source artifact registry is incomplete for edition: ", edition_id, call. = FALSE)
    }
  }
  phase13_source_validate_hash_column(output, "row_sha256", "Phase 13 source artifact registry")
  output
}

phase13_publication_validate_pre_draw <- function(tables) {
  euro <- "uefa_euro_2028_qualifying"
  status <- tables[[phase13_publication_key(euro, "status")]]
  if (!nrow(status)) stop("Phase 13 EURO pre_draw status table must contain one status row", call. = FALSE)
  status_fields <- intersect(c("competition_status", "lifecycle_state"), names(status))
  values <- unique(tolower(unlist(lapply(status[status_fields], as.character), use.names = FALSE)))
  values <- values[!is.na(values) & nzchar(values)]
  if ("pre_draw" %in% values) {
    structure_types <- setdiff(phase13_publication_resource_types(), "status")
    if (any(vapply(structure_types, function(type) nrow(tables[[phase13_publication_key(euro, type)]]) != 0L, logical(1)))) {
      stop("Phase 13 EURO pre_draw publication must not fabricate structure rows", call. = FALSE)
    }
  }
  invisible(TRUE)
}

phase13_refresh_canonical_table_hashes <- function(
    staged_root,
    table_targets = NULL,
    source_artifacts = NULL,
    write_source_artifacts = TRUE) {
  staged_root <- phase13_publication_project_root(staged_root)
  if (is.null(table_targets)) table_targets <- phase13_normalized_resource_targets(staged_root)
  table_targets <- phase13_publication_validate_resource_targets(staged_root, table_targets, require_files = TRUE)
  artifacts <- phase13_publication_read_source_artifacts(staged_root, source_artifacts)

  tables <- vector("list", length(table_targets))
  table_hashes <- character(length(table_targets))
  names(tables) <- names(table_targets)
  names(table_hashes) <- names(table_targets)
  for (key in names(table_targets)) {
    path <- table_targets[[key]]
    parts <- strsplit(key, "::", fixed = TRUE)[[1L]]
    edition_id <- parts[[1L]]
    artifact_type <- parts[[2L]]
    table <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
    phase13_publication_validate_table_shape(table, edition_id, artifact_type, path)
    table$row_sha256 <- phase13_row_sha256(table)
    table <- phase13_publication_sort_table(table)
    phase13_publication_write_csv(table, path)
    tables[[key]] <- table
    table_hashes[[key]] <- phase13_publication_file_sha256(path)

    artifact_rows <- artifacts[
      as.character(artifacts$edition_id) == edition_id &
        as.character(artifacts$artifact_type) == artifact_type,
      , drop = FALSE
    ]
    if (nrow(artifact_rows) != 1L) {
      stop("Phase 13 source artifact registry link is missing or duplicated for ", key, call. = FALSE)
    }
    if (nrow(table)) {
      table_links <- unique(as.character(table$source_artifact_id))
      if (length(table_links) != 1L || !identical(table_links[[1L]], as.character(artifact_rows$source_artifact_id[[1L]]))) {
        stop("Phase 13 source artifact registry link does not match staged table: ", key, call. = FALSE)
      }
    }
    artifacts$canonical_content_sha256[
      as.character(artifacts$artifact_id) == as.character(artifact_rows$artifact_id[[1L]])
    ] <- table_hashes[[key]]
  }

  artifacts$row_sha256 <- phase13_row_sha256(artifacts)
  if (isTRUE(write_source_artifacts)) {
    phase13_publication_write_csv(
      artifacts,
      file.path(staged_root, "data/competition/registries/source_artifacts.csv")
    )
  }
  phase13_publication_validate_pre_draw(tables)
  list(
    staged_root = staged_root,
    table_targets = table_targets,
    tables = tables,
    table_hashes = table_hashes,
    source_artifacts = artifacts,
    source_artifacts_path = file.path(staged_root, "data/competition/registries/source_artifacts.csv")
  )
}
