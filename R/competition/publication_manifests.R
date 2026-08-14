#' Deterministic accepted-manifest and source-bundle hash regeneration.
#'
#' This module consumes the validated output of publication_hashes.R and writes
#' only to an already-created staging root. Locks, snapshots, promotion, and
#' rollback remain responsibilities of Plan 13-12.

phase13_publication_manifest_bundle_columns <- function() {
  c(
    "schema_version", "bundle_id", "edition_id", "bundle_status", "acceptance_state",
    "fallback_status", "parser_commit_sha", "artifact_count", "required_resource_count",
    "source_bundle_sha256", "artifact_manifest_sha256", "canonical_content_sha256",
    "manifest_self_sha256", "accepted_at_utc", "last_accepted_bundle_id",
    "fallback_source", "fallback_retrieval_date", "fallback_reason", "operator_note",
    "fallback_checksum"
  )
}

phase13_publication_manifest_artifact_columns <- function() {
  c(
    "artifact_id", "artifact_type", "source_artifact_id", "source_url",
    "source_url_lineage", "retrieved_at_utc", "bytes", "raw_sha256",
    "canonical_content_sha256", "parser_commit_sha", "fallback_status", "review_state",
    "relative_local_raw_path", "status_provenance"
  )
}

phase13_publication_manifest_schema <- function() {
  c(
    phase13_publication_manifest_bundle_columns(),
    phase13_publication_manifest_artifact_columns(),
    "row_sha256"
  )
}

phase13_publication_manifest_paths <- function(staged_root) {
  staged_root <- phase13_publication_project_root(staged_root)
  accepted_root <- normalizePath(
    file.path(staged_root, "data/competition/accepted"),
    winslash = "/",
    mustWork = FALSE
  )
  paths <- file.path(
    accepted_root,
    phase13_publication_editions(),
    "source_bundle_manifest.csv"
  )
  if (any(!vapply(paths, phase13_publication_path_within, logical(1), root = accepted_root))) {
    stop("Phase 13 accepted-manifest path escaped the trusted accepted root", call. = FALSE)
  }
  stats <- setNames(paths, phase13_publication_editions())
  stats
}

phase13_publication_manifest_require_canonical <- function(canonical_refresh, staged_root) {
  if (!is.list(canonical_refresh)) {
    stop("Phase 13 accepted-manifest refresh requires canonical table/hash output", call. = FALSE)
  }
  required <- c("table_targets", "tables", "table_hashes", "source_artifacts")
  missing <- setdiff(required, names(canonical_refresh))
  if (length(missing)) {
    stop("Phase 13 canonical hash output is incomplete: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  targets <- phase13_publication_validate_resource_targets(
    staged_root,
    canonical_refresh$table_targets,
    require_files = TRUE
  )
  keys <- names(targets)
  if (!is.list(canonical_refresh$tables) ||
      !setequal(names(canonical_refresh$tables), keys) ||
      !is.character(canonical_refresh$table_hashes) ||
      !setequal(names(canonical_refresh$table_hashes), keys)) {
    stop("Phase 13 canonical hash output does not cover the complete ten-resource graph", call. = FALSE)
  }
  canonical_refresh$table_hashes <- as.character(canonical_refresh$table_hashes[keys])
  names(canonical_refresh$table_hashes) <- keys
  if (any(is.na(canonical_refresh$table_hashes) |
          !grepl("^[0-9a-fA-F]{64}$", canonical_refresh$table_hashes))) {
    stop("Phase 13 canonical hash output contains malformed table hashes", call. = FALSE)
  }
  for (key in keys) {
    path <- targets[[key]]
    actual_hash <- phase13_publication_file_sha256(path)
    if (!identical(tolower(actual_hash), tolower(canonical_refresh$table_hashes[[key]]))) {
      stop("Phase 13 accepted-manifest refresh found a stale canonical table hash: ", key, call. = FALSE)
    }
    table <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
    parts <- strsplit(key, "::", fixed = TRUE)[[1L]]
    phase13_publication_validate_table_shape(table, parts[[1L]], parts[[2L]], path)
    if (nrow(table) && any(as.character(table$row_sha256) != phase13_row_sha256(table))) {
      stop("Phase 13 accepted-manifest refresh found stale row hashes: ", key, call. = FALSE)
    }
  }
  canonical_refresh$table_targets <- targets
  canonical_refresh
}

phase13_publication_manifest_read_bundles <- function(staged_root, source_bundles = NULL) {
  path <- file.path(staged_root, "data/competition/registries/source_bundles.csv")
  bundles <- if (is.null(source_bundles)) {
    if (!file.exists(path)) stop("Phase 13 source bundle registry is missing: ", path, call. = FALSE)
    utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  } else {
    if (!is.data.frame(source_bundles)) stop("Phase 13 source bundles must be a data frame or staged CSV", call. = FALSE)
    source_bundles
  }
  required <- c(
    "schema_version", "bundle_id", "edition_id", "bundle_status", "acceptance_state",
    "fallback_status", "parser_commit_sha", "artifact_count", "required_resource_count",
    "source_bundle_sha256", "artifact_manifest_sha256", "accepted_at_utc",
    "last_accepted_bundle_id", "fallback_source", "fallback_retrieval_date",
    "fallback_reason", "operator_note", "fallback_checksum", "manifest_self_sha256", "row_sha256"
  )
  phase13_source_require_columns(bundles, required, "Phase 13 source bundle registry")
  bundles <- as.data.frame(bundles, stringsAsFactors = FALSE, check.names = FALSE)
  if (nrow(bundles) != length(phase13_publication_editions())) {
    stop("Phase 13 source bundle registry must contain exactly two edition rows", call. = FALSE)
  }
  if (anyDuplicated(as.character(bundles$bundle_id)) || anyDuplicated(as.character(bundles$edition_id))) {
    stop("Phase 13 source bundle registry contains duplicate bundle or edition rows", call. = FALSE)
  }
  if (!setequal(as.character(bundles$edition_id), phase13_publication_editions())) {
    stop("Phase 13 source bundle registry contains an unknown or missing edition", call. = FALSE)
  }
  if (any(is.na(bundles$bundle_id) | !nzchar(as.character(bundles$bundle_id))) ||
      any(is.na(bundles$parser_commit_sha) | !grepl("^[0-9a-fA-F]{7,64}$", as.character(bundles$parser_commit_sha))) ||
      any(is.na(bundles$accepted_at_utc) | !nzchar(as.character(bundles$accepted_at_utc))) ||
      any(is.na(bundles$last_accepted_bundle_id) | !nzchar(as.character(bundles$last_accepted_bundle_id)))) {
    stop("Phase 13 source bundle registry contains incomplete identity or provenance", call. = FALSE)
  }
  if (any(as.character(bundles$bundle_status) != "accepted")) {
    stop("Phase 13 source bundle registry contains a non-accepted bundle", call. = FALSE)
  }
  if (any(!as.character(bundles$fallback_status) %in% c("official", "reviewed_fallback"))) {
    stop("Phase 13 source bundle registry contains an unsupported fallback status", call. = FALSE)
  }
  bundles
}

phase13_publication_manifest_read_artifacts <- function(staged_root, artifacts) {
  artifacts <- phase13_publication_read_source_artifacts(staged_root, artifacts)
  expected_editions <- phase13_publication_editions()
  expected_types <- phase13_publication_resource_types()
  if (nrow(artifacts) != length(expected_editions) * length(expected_types) ||
      !setequal(unique(as.character(artifacts$edition_id)), expected_editions)) {
    stop("Phase 13 source-artifact projection must contain exactly ten registered resources", call. = FALSE)
  }
  if (anyDuplicated(as.character(artifacts$source_artifact_id))) {
    stop("Phase 13 source-artifact projection contains duplicate source-artifact links", call. = FALSE)
  }
  if (any(is.na(artifacts$canonical_content_sha256) |
          !grepl("^[0-9a-fA-F]{64}$", as.character(artifacts$canonical_content_sha256)))) {
    stop("Phase 13 source-artifact projection contains malformed canonical table hashes", call. = FALSE)
  }
  for (edition_id in expected_editions) {
    rows <- artifacts[as.character(artifacts$edition_id) == edition_id, , drop = FALSE]
    if (nrow(rows) != length(expected_types) ||
        !setequal(as.character(rows$artifact_type), expected_types) ||
        anyDuplicated(as.character(rows$artifact_type))) {
      stop("Phase 13 source-artifact projection is incomplete for edition: ", edition_id, call. = FALSE)
    }
    if (length(unique(as.character(rows$bundle_id))) != 1L ||
        length(unique(tolower(as.character(rows$parser_commit_sha)))) != 1L ||
        length(unique(as.character(rows$fallback_status))) != 1L) {
      stop("Phase 13 source-artifact projection cannot mix bundle, parser, or fallback lineage for edition: ", edition_id, call. = FALSE)
    }
    if (any(is.na(rows$source_url_lineage) | !nzchar(as.character(rows$source_url_lineage))) ||
        any(is.na(rows$status_provenance) | !nzchar(as.character(rows$status_provenance)))) {
      stop("Phase 13 source-artifact projection contains incomplete lineage metadata for edition: ", edition_id, call. = FALSE)
    }
  }
  artifacts
}

phase13_publication_manifest_validate_artifact_hashes <- function(artifacts, canonical_refresh) {
  for (key in names(canonical_refresh$table_targets)) {
    parts <- strsplit(key, "::", fixed = TRUE)[[1L]]
    rows <- artifacts[
      as.character(artifacts$edition_id) == parts[[1L]] &
        as.character(artifacts$artifact_type) == parts[[2L]],
      ,
      drop = FALSE
    ]
    if (nrow(rows) != 1L || !identical(
      tolower(as.character(rows$canonical_content_sha256[[1L]])),
      tolower(as.character(canonical_refresh$table_hashes[[key]]))
    )) {
      stop("Phase 13 accepted-manifest source-artifact canonical hash is stale or forged for ", key, call. = FALSE)
    }
    table <- canonical_refresh$tables[[key]]
    path <- canonical_refresh$table_targets[[key]]
    if (nrow(table)) {
      links <- unique(as.character(table$source_artifact_id))
      if (length(links) != 1L || !identical(links[[1L]], as.character(rows$source_artifact_id[[1L]]))) {
        stop("Phase 13 accepted-manifest source-artifact link is forged for ", key, call. = FALSE)
      }
    }
    if (!identical(
      tolower(phase13_publication_file_sha256(path)),
      tolower(as.character(rows$canonical_content_sha256[[1L]]))
    )) {
      stop("Phase 13 accepted-manifest source-artifact canonical bytes are stale for ", key, call. = FALSE)
    }
  }
  invisible(TRUE)
}

phase13_publication_manifest_artifact_hash <- function(artifacts) {
  phase13_canonical_sha256(artifacts, key = "artifact_id")
}

phase13_publication_manifest_content_table <- function(bundle, artifacts) {
  bundle_fields <- setdiff(
    names(bundle),
    c("canonical_content_sha256", "manifest_self_sha256", "row_sha256")
  )
  artifact_fields <- setdiff(names(artifacts), c("canonical_content_sha256", "row_sha256"))
  cbind(
    bundle[rep(1L, nrow(artifacts)), bundle_fields, drop = FALSE],
    artifacts[, artifact_fields, drop = FALSE]
  )
}

phase13_publication_manifest_content_hash <- function(bundle, artifacts) {
  phase13_source_sha256(
    phase13_publication_csv_bytes(phase13_publication_manifest_content_table(bundle, artifacts))
  )
}

phase13_publication_manifest_build_bundle <- function(bundle_input, artifacts) {
  if (nrow(bundle_input) != 1L) stop("Phase 13 accepted-manifest bundle input must contain one row", call. = FALSE)
  bundle <- bundle_input[1L, , drop = FALSE]
  if (!"canonical_content_sha256" %in% names(bundle)) {
    bundle$canonical_content_sha256 <- ""
  }
  artifact_hash <- phase13_publication_manifest_artifact_hash(artifacts)
  content_hash <- phase13_publication_manifest_content_hash(bundle, artifacts)
  bundle$source_bundle_sha256[[1L]] <- artifact_hash
  bundle$artifact_manifest_sha256[[1L]] <- artifact_hash
  bundle$canonical_content_sha256[[1L]] <- content_hash
  bundle$manifest_self_sha256[[1L]] <- ""
  bundle$manifest_self_sha256[[1L]] <- phase13_source_manifest_self_sha256(bundle, artifacts)
  bundle$row_sha256[[1L]] <- phase13_row_sha256(bundle)[[1L]]
  phase13_validate_source_bundle(bundle, artifacts)
  bundle
}

phase13_publication_manifest_build_rows <- function(bundle, artifacts) {
  artifact_order <- order(as.character(artifacts$artifact_id), method = "radix")
  artifacts <- artifacts[artifact_order, , drop = FALSE]
  bundle_fields <- phase13_publication_manifest_bundle_columns()
  artifact_fields <- phase13_publication_manifest_artifact_columns()
  missing_bundle <- setdiff(bundle_fields, names(bundle))
  missing_artifact <- setdiff(artifact_fields, names(artifacts))
  if (length(missing_bundle) || length(missing_artifact)) {
    stop("Phase 13 accepted manifest cannot be projected from incomplete hash graph", call. = FALSE)
  }
  output <- cbind(
    bundle[rep(1L, nrow(artifacts)), bundle_fields, drop = FALSE],
    artifacts[, artifact_fields, drop = FALSE]
  )
  output$row_sha256 <- phase13_row_sha256(output)
  names(output) <- phase13_publication_manifest_schema()
  output
}

phase13_publication_manifest_validate_rows <- function(manifest, bundle, artifacts) {
  if (!identical(names(manifest), phase13_publication_manifest_schema()) ||
      nrow(manifest) != length(phase13_publication_resource_types())) {
    stop("Phase 13 accepted manifest does not contain the exact five-resource schema", call. = FALSE)
  }
  edition_matches <- all(as.character(manifest$edition_id) == as.character(bundle$edition_id[[1L]]))
  bundle_matches <- all(as.character(manifest$bundle_id) == as.character(bundle$bundle_id[[1L]]))
  if (!edition_matches || !bundle_matches) {
    stop("Phase 13 accepted manifest foreign keys do not match its source bundle", call. = FALSE)
  }
  if (!setequal(as.character(manifest$artifact_type), phase13_publication_resource_types()) ||
      anyDuplicated(as.character(manifest$artifact_type))) {
    stop("Phase 13 accepted manifest is missing or duplicating a required resource class", call. = FALSE)
  }
  canonical_columns <- which(names(manifest) == "canonical_content_sha256")
  if (length(canonical_columns) != 2L) {
    stop("Phase 13 accepted manifest must expose bundle and artifact canonical hashes", call. = FALSE)
  }
  artifact_index <- match(as.character(manifest$artifact_id), as.character(artifacts$artifact_id))
  if (any(is.na(artifact_index)) ||
      !identical(
        as.character(manifest[[canonical_columns[[2L]]]]),
        as.character(artifacts$canonical_content_sha256[artifact_index])
      )) {
    stop("Phase 13 accepted manifest artifact canonical hashes do not match source artifacts", call. = FALSE)
  }
  phase13_source_validate_hash_column(manifest, "row_sha256", "Phase 13 accepted manifest")
  expected_self <- phase13_source_manifest_self_sha256(bundle, artifacts)
  if (any(as.character(manifest$manifest_self_sha256) != expected_self)) {
    stop("Phase 13 accepted manifest self-hash mismatch", call. = FALSE)
  }
  if (any(as.character(manifest$source_bundle_sha256) != as.character(bundle$source_bundle_sha256[[1L]])) ||
      any(as.character(manifest$artifact_manifest_sha256) != as.character(bundle$artifact_manifest_sha256[[1L]])) ||
      any(as.character(manifest$canonical_content_sha256) != as.character(bundle$canonical_content_sha256[[1L]]))) {
    stop("Phase 13 accepted manifest derived hash mismatch", call. = FALSE)
  }
  invisible(TRUE)
}

#' Refresh both accepted manifests and the edition-scoped derived source bundles.
phase13_refresh_accepted_manifest_hashes <- function(
    staged_root,
    canonical_refresh,
    source_artifacts = NULL,
    source_bundles = NULL,
    write_manifests = TRUE,
    write_source_bundles = TRUE) {
  staged_root <- phase13_publication_project_root(staged_root)
  canonical_refresh <- phase13_publication_manifest_require_canonical(canonical_refresh, staged_root)

  canonical_artifacts <- phase13_publication_manifest_read_artifacts(
    staged_root,
    canonical_refresh$source_artifacts
  )
  input_artifacts <- if (is.null(source_artifacts)) {
    canonical_artifacts
  } else {
    phase13_publication_manifest_read_artifacts(staged_root, source_artifacts)
  }
  phase13_publication_manifest_validate_artifact_hashes(canonical_artifacts, canonical_refresh)
  phase13_publication_manifest_validate_artifact_hashes(input_artifacts, canonical_refresh)
  if (!identical(
    phase13_canonical_sha256(input_artifacts, key = "artifact_id"),
    phase13_canonical_sha256(canonical_artifacts, key = "artifact_id")
  )) {
    stop("Phase 13 accepted-manifest source-artifact projection is stale or forged", call. = FALSE)
  }

  bundles <- phase13_publication_manifest_read_bundles(staged_root, source_bundles)
  manifest_paths <- phase13_publication_manifest_paths(staged_root)
  output_artifacts <- input_artifacts[order(
    match(as.character(input_artifacts$edition_id), phase13_publication_editions()),
    match(as.character(input_artifacts$artifact_type), phase13_publication_resource_types()),
    method = "radix"
  ), , drop = FALSE]
  output_bundles <- vector("list", length(phase13_publication_editions()))
  output_manifests <- vector("list", length(phase13_publication_editions()))
  bundle_hashes <- character(length(output_bundles))
  artifact_manifest_hashes <- character(length(output_bundles))
  manifest_self_hashes <- character(length(output_bundles))
  names(output_bundles) <- phase13_publication_editions()
  names(output_manifests) <- phase13_publication_editions()
  names(bundle_hashes) <- phase13_publication_editions()
  names(artifact_manifest_hashes) <- phase13_publication_editions()
  names(manifest_self_hashes) <- phase13_publication_editions()

  for (edition_id in phase13_publication_editions()) {
    artifacts <- output_artifacts[as.character(output_artifacts$edition_id) == edition_id, , drop = FALSE]
    bundle_input <- bundles[as.character(bundles$edition_id) == edition_id, , drop = FALSE]
    if (nrow(bundle_input) != 1L) stop("Phase 13 source bundle registry link is missing for ", edition_id, call. = FALSE)
    bundle_matches <- all(as.character(artifacts$bundle_id) == as.character(bundle_input$bundle_id[[1L]]))
    edition_matches <- all(as.character(artifacts$edition_id) == as.character(bundle_input$edition_id[[1L]]))
    if (!bundle_matches || !edition_matches) {
      stop("Phase 13 accepted-manifest source-bundle foreign key is forged for ", edition_id, call. = FALSE)
    }
    if (as.integer(bundle_input$artifact_count[[1L]]) != nrow(artifacts) ||
        as.integer(bundle_input$required_resource_count[[1L]]) != length(phase13_publication_resource_types())) {
      stop("Phase 13 source bundle registry has incomplete artifact counts for ", edition_id, call. = FALSE)
    }
    if (length(unique(as.character(artifacts$fallback_status))) != 1L ||
        !identical(as.character(bundle_input$fallback_status[[1L]]), as.character(artifacts$fallback_status[[1L]]))) {
      stop("Phase 13 source bundle cannot mix official and fallback artifacts for ", edition_id, call. = FALSE)
    }
    if (length(unique(tolower(as.character(artifacts$parser_commit_sha)))) != 1L ||
        !identical(
          tolower(as.character(bundle_input$parser_commit_sha[[1L]])),
          tolower(as.character(artifacts$parser_commit_sha[[1L]]))
        )) {
      stop("Phase 13 source bundle parser identity drifted for ", edition_id, call. = FALSE)
    }
    bundle <- phase13_publication_manifest_build_bundle(bundle_input, artifacts)
    manifest <- phase13_publication_manifest_build_rows(bundle, artifacts)
    phase13_publication_manifest_validate_rows(manifest, bundle, artifacts)
    output_bundles[[edition_id]] <- bundle
    output_manifests[[edition_id]] <- manifest
    bundle_hashes[[edition_id]] <- as.character(bundle$source_bundle_sha256[[1L]])
    artifact_manifest_hashes[[edition_id]] <- as.character(bundle$artifact_manifest_sha256[[1L]])
    manifest_self_hashes[[edition_id]] <- as.character(bundle$manifest_self_sha256[[1L]])
    if (isTRUE(write_manifests)) phase13_publication_write_csv(manifest, manifest_paths[[edition_id]])
  }

  output_bundle_table <- do.call(rbind, output_bundles[phase13_publication_editions()])
  row.names(output_bundle_table) <- NULL
  if (isTRUE(write_source_bundles)) {
    phase13_publication_write_csv(
      output_bundle_table,
      file.path(staged_root, "data/competition/registries/source_bundles.csv")
    )
  }
  list(
    staged_root = staged_root,
    manifests = output_manifests,
    manifest_paths = manifest_paths,
    source_bundles = output_bundle_table,
    source_bundles_path = file.path(staged_root, "data/competition/registries/source_bundles.csv"),
    source_artifacts = output_artifacts,
    bundle_hashes = bundle_hashes,
    artifact_manifest_hashes = artifact_manifest_hashes,
    manifest_self_hashes = manifest_self_hashes,
    canonical_refresh = canonical_refresh
  )
}

# Explicit aliases for transaction callers that use plural terminology.
phase13_refresh_accepted_manifests <- phase13_refresh_accepted_manifest_hashes
phase13_refresh_manifest_hashes <- phase13_refresh_accepted_manifest_hashes
