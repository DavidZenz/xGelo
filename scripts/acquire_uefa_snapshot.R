#!/usr/bin/env Rscript

# Bounded Phase 13 source capture.  This entrypoint accepts either committed
# compact fixtures or one operator-supplied URL per structured resource class.
# It never parses rendered page text and never publishes a candidate before the
# complete edition-wide bundle has passed the source contract.

phase13_acquire_script_file <- sub(
  "^--file=",
  "",
  commandArgs(trailingOnly = FALSE)[grep("^--file=", commandArgs(trailingOnly = FALSE))][1L]
)
phase13_acquire_project_root <- normalizePath(
  file.path(dirname(phase13_acquire_script_file), ".."),
  winslash = "/",
  mustWork = TRUE
)
source(file.path(phase13_acquire_project_root, "R/competition/source_contracts.R"))

phase13_acquire_now_utc <- function() {
  format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

phase13_acquire_resolve_path <- function(path, project_root = phase13_acquire_project_root) {
  path <- phase13_source_scalar(path, "path")
  value <- if (grepl("^/", path)) path else file.path(project_root, path)
  normalizePath(value, winslash = "/", mustWork = FALSE)
}

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
    "source-url-groups", "source-url-standings", "source-url-results", "source-url-status"
  )
  output <- list(dry_run = FALSE, help = FALSE)
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
    if (!key %in% value_keys) stop("Unsupported Phase 13 capture option: --", key, call. = FALSE)
    if (index == length(args)) stop("Phase 13 capture option requires a value: --", key, call. = FALSE)
    output[[key]] <- args[[index + 1L]]
    index <- index + 2L
  }
  output
}

phase13_acquire_help <- function() {
  c(
    "Usage: Rscript --vanilla scripts/acquire_uefa_snapshot.R [options]",
    "",
    "Fixture replay:",
    "  --fixture-dir DIR --edition-id EDITION [--output-root DIR] [--registry-root DIR]",
    "  [--raw-root DIR] [--fallback-file FILE] [--bundle-id ID] [--dry-run]",
    "",
    "Bounded live capture:",
    "  --edition-id EDITION --fixtures-url URL --groups-url URL --standings-url URL",
    "  --results-url URL --status-url URL [the same output options as above]",
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
    resource_types <- phase13_source_required_resource_types()
    resources <- setNames(lapply(resource_types, phase13_acquire_empty_resource), resource_types)
    resources$status <- list(list(
      source_edition_id = fixture$edition_id,
      competition_status = fixture$source_snapshot_state
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
  resource_types <- phase13_source_required_resource_types()
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

phase13_acquire_fetch_structured_url <- function(url, artifact_type, max_bytes = 5e6) {
  url <- phase13_source_scalar(url, paste0(artifact_type, " URL"))
  if (!grepl("^https://", tolower(url))) stop("Phase 13 live capture requires an HTTPS URL for ", artifact_type, call. = FALSE)
  target <- tempfile("phase13-uefa-response-", fileext = ".json")
  on.exit(if (file.exists(target)) unlink(target), add = TRUE)
  result <- tryCatch(
    utils::download.file(url, target, mode = "wb", quiet = TRUE),
    error = function(error) stop("Phase 13 structured URL capture failed for ", artifact_type, ": ", conditionMessage(error), call. = FALSE)
  )
  if (!identical(as.integer(result), 0L)) stop("Phase 13 structured URL capture failed for ", artifact_type, call. = FALSE)
  size <- file.info(target)$size
  if (is.na(size) || size <= 0 || size > max_bytes) stop("Phase 13 structured URL response exceeds the bounded byte limit: ", artifact_type, call. = FALSE)
  raw_bytes <- readBin(target, what = "raw", n = size)
  phase13_source_validate_structured_bytes(raw_bytes, artifact_type)
  list(
    payload = jsonlite::fromJSON(rawToChar(raw_bytes), simplifyVector = FALSE),
    raw_bytes = raw_bytes,
    source_url = url
  )
}

phase13_acquire_live_input <- function(options, edition_id) {
  resource_types <- phase13_source_required_resource_types()
  url_values <- vapply(resource_types, function(artifact_type) {
    candidates <- c(
      options[[paste0(artifact_type, "-url")]],
      options[[paste0("url-", artifact_type)]],
      options[[paste0("source-url-", artifact_type)]]
    )
    candidates <- candidates[!vapply(candidates, is.null, logical(1))]
    if (!length(candidates)) return(NA_character_)
    as.character(candidates[[1L]])
  }, character(1))
  if (any(is.na(url_values) | !nzchar(url_values))) {
    stop("Live Phase 13 capture requires explicit HTTPS URLs for fixtures, groups, standings, results, and status", call. = FALSE)
  }
  payloads <- list()
  raw_bytes <- list()
  for (artifact_type in resource_types) {
    captured <- phase13_acquire_fetch_structured_url(url_values[[artifact_type]], artifact_type)
    payloads[[artifact_type]] <- captured$payload
    raw_bytes[[artifact_type]] <- captured$raw_bytes
  }
  list(
    edition_id = edition_id,
    resources = payloads,
    source_urls = url_values,
    raw_bytes_by_resource = raw_bytes,
    retrieved_at_utc = phase13_acquire_now_utc()
  )
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
  do.call(phase13_capture_structured_bundle, capture_args)
}

phase13_acquire_write_raw_store <- function(candidate, raw_root, edition_id, bundle_id) {
  raw_dir <- file.path(raw_root, edition_id, bundle_id)
  dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
  resource_types <- phase13_source_required_resource_types()
  for (artifact_type in resource_types) {
    raw_bytes <- candidate$raw_bytes_by_resource[[artifact_type]]
    target <- file.path(raw_dir, paste0(artifact_type, ".json"))
    staged <- tempfile(paste0(".", basename(target), "-"), tmpdir = raw_dir)
    on.exit(if (file.exists(staged)) unlink(staged), add = TRUE)
    writeBin(phase13_source_raw_bytes(raw_bytes), staged)
    if (!file.rename(staged, target)) stop("Could not retain Phase 13 raw response: ", target, call. = FALSE)
    artifact <- candidate$artifacts[candidate$artifacts$artifact_type == artifact_type, , drop = FALSE]
    actual_bytes <- readBin(target, what = "raw", n = file.info(target)$size)
    if (nrow(artifact) != 1L || file.info(target)$size != artifact$bytes[[1L]] || phase13_source_sha256(actual_bytes) != artifact$raw_sha256[[1L]]) {
      stop("Phase 13 retained raw response failed exact-byte verification: ", artifact_type, call. = FALSE)
    }
  }
  normalizePath(raw_dir, winslash = "/", mustWork = TRUE)
}

phase13_acquire_write_resource_table <- function(payload, artifact_type, edition_id, artifact_id, path) {
  table <- phase13_source_resource_table(payload, artifact_type, edition_id, artifact_id)
  schema_version <- paste0("phase13-", artifact_type, "-v1")
  table <- cbind(schema_version = rep(schema_version, nrow(table)), table)
  table$row_sha256 <- phase13_row_sha256(table)
  phase13_source_write_csv(table, path)
  table
}

phase13_acquire_publish_accepted <- function(candidate, output_root, edition_id, raw_root) {
  target <- file.path(output_root, edition_id)
  dir.create(output_root, recursive = TRUE, showWarnings = FALSE)
  staged <- tempfile(paste0(".", edition_id, "-candidate-"), tmpdir = output_root)
  dir.create(staged, recursive = TRUE, showWarnings = FALSE)
  on.exit(if (dir.exists(staged)) unlink(staged, recursive = TRUE), add = TRUE)

  phase13_source_write_csv(candidate$manifest, file.path(staged, "source_bundle_manifest.csv"))
  for (artifact_type in phase13_source_required_resource_types()) {
    artifact_id <- candidate$artifacts$artifact_id[candidate$artifacts$artifact_type == artifact_type][[1L]]
    phase13_acquire_write_resource_table(
      candidate$resources[[artifact_type]], artifact_type, edition_id, artifact_id,
      file.path(staged, paste0(artifact_type, ".csv"))
    )
  }

  backup <- NULL
  if (dir.exists(target)) {
    backup <- tempfile(paste0(".", edition_id, "-previous-"), tmpdir = output_root)
    if (!file.rename(target, backup)) stop("Could not stage the last accepted Phase 13 output", call. = FALSE)
  }
  if (!file.rename(staged, target)) {
    if (!is.null(backup)) file.rename(backup, target)
    stop("Could not publish Phase 13 accepted output", call. = FALSE)
  }
  if (!is.null(backup) && dir.exists(backup)) unlink(backup, recursive = TRUE)
  on.exit(NULL, add = TRUE)
  normalizePath(target, winslash = "/", mustWork = TRUE)
}

phase13_acquire_read_registry <- function(path) {
  if (!file.exists(path)) return(NULL)
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
}

phase13_acquire_update_registries <- function(candidate, registry_root) {
  dir.create(registry_root, recursive = TRUE, showWarnings = FALSE)
  bundle_path <- file.path(registry_root, "source_bundles.csv")
  artifact_path <- file.path(registry_root, "source_artifacts.csv")
  old_bundles <- phase13_acquire_read_registry(bundle_path)
  old_artifacts <- phase13_acquire_read_registry(artifact_path)
  bundles <- if (is.null(old_bundles)) candidate$bundle else rbind(old_bundles[old_bundles$bundle_id != candidate$bundle$bundle_id, , drop = FALSE], candidate$bundle)
  artifacts <- if (is.null(old_artifacts)) candidate$artifacts else rbind(old_artifacts[old_artifacts$bundle_id != candidate$bundle$bundle_id, , drop = FALSE], candidate$artifacts)
  phase13_source_write_csv(bundles, bundle_path)
  phase13_source_write_csv(artifacts, artifact_path)
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

phase13_acquire_write_blocked_metadata <- function(
    edition_id, bundle_id, output_root, registry_root, reason, project_root = phase13_acquire_project_root) {
  target_dir <- file.path(output_root, edition_id)
  dir.create(target_dir, recursive = TRUE, showWarnings = FALSE)
  last_accepted <- phase13_acquire_last_accepted_bundle_id(edition_id, registry_root, output_root)
  metadata <- list(
    schema_version = "phase13-source-refresh-blocked-v1",
    status = "blocked",
    edition_id = edition_id,
    candidate_bundle_id = bundle_id,
    output_bundle_target = edition_id,
    last_accepted_bundle_id = last_accepted,
    accepted_output_preserved = TRUE,
    blocked_at_utc = phase13_acquire_now_utc(),
    failure_reason = reason,
    parser_commit_sha = tryCatch(phase13_parser_commit_sha(project_root), error = function(error) "")
  )
  phase13_source_write_json(metadata, file.path(target_dir, "blocked_refresh.json"))
  metadata
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
  tryCatch({
    candidate <- phase13_acquire_candidate(options, edition_id)
    candidate$manifest <- phase13_source_manifest_table(candidate$bundle, candidate$artifacts)
    if (isTRUE(options$dry_run)) {
      message(sprintf("Phase 13 dry-run candidate valid: %s (%s)", candidate$bundle$bundle_id[[1L]], edition_id))
      return(invisible(candidate))
    }
    phase13_acquire_write_raw_store(candidate, raw_root, edition_id, candidate$bundle$bundle_id[[1L]])
    phase13_acquire_publish_accepted(candidate, output_root, edition_id, raw_root)
    phase13_acquire_update_registries(candidate, registry_root)
    message(sprintf("Phase 13 accepted %s source bundle: %s", edition_id, candidate$bundle$bundle_id[[1L]]))
    invisible(candidate)
  }, error = function(error) {
    if (!isTRUE(options$dry_run)) {
      phase13_acquire_write_blocked_metadata(
        edition_id = edition_id,
        bundle_id = bundle_id,
        output_root = output_root,
        registry_root = registry_root,
        reason = conditionMessage(error)
      )
    }
    stop(sprintf("Phase 13 source capture blocked: %s", conditionMessage(error)), call. = FALSE)
  })
}

`%||%` <- function(value, fallback) if (is.null(value)) fallback else value

if (identical(environment(), globalenv())) {
  phase13_acquire_main()
}
