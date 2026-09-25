# Phase 21 dynamic, all-or-nothing dashboard publication.

`%||%` <- function(left, right) if (is.null(left) || !length(left)) right else left

phase21_public_root <- function(path, create = FALSE) {
  path <- as.character(path)[[1L]]
  if (is.na(path) || !nzchar(path)) stop("Phase 21 public root must be non-empty", call. = FALSE)
  if (create && !dir.exists(path)) dir.create(path, recursive = TRUE, showWarnings = FALSE)
  normalizePath(path, winslash = "/", mustWork = create || dir.exists(path))
}

phase21_public_file_bytes <- function(path) {
  if (!file.exists(path) || dir.exists(path)) stop("Phase 21 public file is missing: ", path, call. = FALSE)
  readBin(path, "raw", n = as.integer(file.info(path)$size))
}

phase21_public_hash <- function(bytes) {
  if (exists("phase17_sha256_raw", mode = "function", inherits = TRUE)) return(phase17_sha256_raw(bytes))
  phase21_hash_raw(bytes)
}

phase21_canonical_value_bytes <- function(value) {
  if (exists("phase17_canonical_bytes", mode = "function", inherits = TRUE)) return(phase17_canonical_bytes(value))
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("Phase 21 canonical serialization requires jsonlite", call. = FALSE)
  charToRaw(enc2utf8(as.character(jsonlite::toJSON(value, auto_unbox = TRUE, null = "null", na = "null", dataframe = "rows", digits = 16, pretty = FALSE))))
}

phase21_write_json <- function(value, path) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("Phase 21 JSON publication requires jsonlite", call. = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  bytes <- charToRaw(enc2utf8(as.character(jsonlite::toJSON(value, auto_unbox = TRUE, null = "null", na = "null", dataframe = "rows", digits = 16, pretty = FALSE))))
  writeBin(bytes, path)
  invisible(path)
}

phase21_read_json <- function(path) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("Phase 21 JSON publication requires jsonlite", call. = FALSE)
  jsonlite::fromJSON(rawToChar(phase21_public_file_bytes(path)), simplifyVector = FALSE)
}

phase21_batch_identity <- function(payloads = list(), batch_id = NULL) {
  if (!is.null(batch_id)) return(as.character(batch_id)[[1L]])
  if (!length(payloads)) return(paste0("phase21-empty-", substr(phase21_public_hash(charToRaw("phase21-empty")), 1L, 16L)))
  bytes <- do.call(c, lapply(payloads, phase21_payload_bytes))
  paste0("phase21-", substr(phase21_public_hash(bytes), 1L, 24L))
}

phase21_route_files <- function(root, route) {
  file.path(root, route, c("index.html", "payload.json", "route-manifest.json", "current.json"))
}

phase21_render_route_v2 <- function(payload, root, registry_row, batch_id) {
  phase21_validate_payload(payload)
  root <- phase21_public_root(root, create = TRUE)
  route <- as.character(registry_row$route_slug[[1L]])
  route_root <- file.path(root, route)
  dir.create(route_root, recursive = TRUE, showWarnings = FALSE)
  html <- phase21_render_dashboard(payload, route = route)
  payload_bytes <- phase21_payload_bytes(payload)
  manifest <- list(schema_version = phase21_dashboard_schema_version, edition_id = payload$edition_id,
                   route = paste0("/competitions/", route, "/"), batch_id = batch_id,
                   payload_sha256 = phase21_public_hash(payload_bytes),
                   html_sha256 = phase21_public_hash(charToRaw(enc2utf8(html))))
  current <- list(schema_version = phase21_dashboard_schema_version, edition_id = payload$edition_id,
                  route = route, batch_id = batch_id, status = payload$metadata$lifecycle_state,
                  payload_sha256 = manifest$payload_sha256)
  writeBin(charToRaw(enc2utf8(html)), file.path(route_root, "index.html"))
  writeBin(payload_bytes, file.path(route_root, "payload.json"))
  phase21_write_json(manifest, file.path(route_root, "route-manifest.json"))
  phase21_write_json(current, file.path(route_root, "current.json"))
  list(route = route, files = phase21_route_files(root, route), route_manifest = manifest, current = current)
}

phase21_assert_exact_batch_paths <- function(root, registry) {
  root <- phase21_public_root(root)
  expected <- phase21_batch_relative_inventory(registry)
  actual <- gsub("\\\\", "/", list.files(root, recursive = TRUE, all.files = FALSE, full.names = FALSE, include.dirs = FALSE))
  if (any(grepl("(^|/)\\.\\.?(/|$)|(^|/)(raw|logs|refresh_batches)(/|$)|score_distributions|\\.rds$", actual))) stop("Phase 21 batch contains a prohibited path", call. = FALSE)
  if (!identical(sort(actual), sort(expected))) stop("Phase 21 batch inventory is not exact", call. = FALSE)
  expected_paths <- file.path(root, expected)
  is_symlink <- function(path) {
    link <- tryCatch(Sys.readlink(path), error = function(error) "")
    length(link) == 1L && nzchar(link)
  }
  if (any(vapply(expected_paths, is_symlink, logical(1)))) stop("Phase 21 batch contains a symlink", call. = FALSE)
  root_norm <- normalizePath(root, winslash = "/", mustWork = TRUE)
  path_within <- function(path) {
    value <- normalizePath(path, winslash = "/", mustWork = TRUE)
    identical(value, root_norm) || startsWith(value, paste0(root_norm, "/"))
  }
  if (any(!vapply(expected_paths, path_within, logical(1)))) stop("Phase 21 batch path escaped its root", call. = FALSE)
  expected_paths
}

phase21_validate_batch <- function(root, registry = phase21_default_edition_registry(), expected_batch_id = NULL) {
  registry <- phase21_validate_registry(registry)
  rows <- phase21_enabled_registry(registry)
  root <- phase21_public_root(root)
  paths <- phase21_assert_exact_batch_paths(root, registry)
  relative <- phase21_batch_relative_inventory(registry)
  names(paths) <- relative
  manifest <- phase21_read_json(file.path(root, "phase21-batch-manifest.json"))
  current <- phase21_read_json(file.path(root, "current.json"))
  batch_id <- as.character(manifest$batch_id %||% "")
  if (!nzchar(batch_id) || !identical(batch_id, as.character(current$batch_id %||% ""))) stop("Phase 21 batch identity is missing or mixed", call. = FALSE)
  if (!is.null(expected_batch_id) && !identical(batch_id, as.character(expected_batch_id)[[1L]])) stop("Phase 21 batch identity does not match expected identity", call. = FALSE)
  expected_routes <- as.character(rows$route_slug)
  if (!identical(as.character(manifest$routes %||% character()), expected_routes)) stop("Phase 21 batch route order is invalid", call. = FALSE)
  if (!identical(sort(as.character(manifest$inventory %||% character())), sort(phase21_expected_public_inventory(registry)))) stop("Phase 21 batch manifest inventory is invalid", call. = FALSE)
  payloads <- list()
  route_manifests <- list()
  for (index in seq_len(nrow(rows))) {
    row <- rows[index, , drop = FALSE]
    route <- row$route_slug[[1L]]
    route_root <- file.path(root, route)
    payload <- phase21_read_json(file.path(route_root, "payload.json"))
    payload$sections <- lapply(payload$sections, function(section) {
      section$rows <- if (is.null(section$rows)) list() else section$rows
      section
    })
    phase21_validate_payload(payload, registry)
    if (!identical(as.character(payload$edition_id), as.character(row$edition_id))) stop("Phase 21 route payload edition mismatch", call. = FALSE)
    route_manifest <- phase21_read_json(file.path(route_root, "route-manifest.json"))
    current_route <- phase21_read_json(file.path(route_root, "current.json"))
    payload_hash <- phase21_public_hash(phase21_public_file_bytes(file.path(route_root, "payload.json")))
    html_hash <- phase21_public_hash(phase21_public_file_bytes(file.path(route_root, "index.html")))
    if (!identical(tolower(as.character(route_manifest$payload_sha256)), tolower(payload_hash)) || !identical(tolower(as.character(route_manifest$html_sha256)), tolower(html_hash))) stop("Phase 21 route hash mismatch", call. = FALSE)
    if (!identical(as.character(route_manifest$batch_id), batch_id) || !identical(as.character(current_route$batch_id), batch_id) || !identical(as.character(current_route$payload_sha256), as.character(route_manifest$payload_sha256))) stop("Phase 21 route batch identity mismatch", call. = FALSE)
    payloads[[as.character(row$edition_id)]] <- payload
    route_manifests[[route]] <- route_manifest
  }
  limits <- lapply(seq_len(nrow(rows)), function(index) {
    row <- rows[index, , drop = FALSE]
    route_files <- phase21_route_files(root, row$route_slug[[1L]])
    sizes <- vapply(route_files, function(path) as.numeric(file.info(path)$size), numeric(1))
    if (any(sizes > row$max_file_bytes[[1L]])) stop("Phase 21 public file exceeds the edition byte limit", call. = FALSE)
    list(edition_id = row$edition_id[[1L]], total_bytes = sum(sizes), max_file_bytes = row$max_file_bytes[[1L]])
  })
  all_files <- paths
  batch_limit <- if (nrow(rows)) max(rows$max_batch_bytes) else phase21_default_max_batch_bytes
  total <- sum(vapply(all_files, function(path) as.numeric(file.info(path)$size), numeric(1)))
  if (total > batch_limit) stop("Phase 21 batch exceeds byte limit", call. = FALSE)
  list(valid = TRUE, batch_id = batch_id, inventory = phase21_expected_public_inventory(registry), files = paths,
       payloads = payloads, route_manifests = route_manifests, total_bytes = total, limits = limits)
}

phase21_stage_batch <- function(payloads, registry = phase21_default_edition_registry(), stage_root, batch_id = NULL, generated_at_utc = "2026-09-25T00:00:00Z") {
  registry <- phase21_validate_registry(registry)
  rows <- phase21_enabled_registry(registry)
  stage_root <- phase21_public_root(stage_root, create = TRUE)
  expected_ids <- as.character(rows$edition_id)
  payload_names <- names(payloads %||% list())
  if (is.null(payload_names)) payload_names <- character()
  if (!identical(sort(payload_names), sort(expected_ids))) stop("Phase 21 payload inventory does not match enabled registry", call. = FALSE)
  ordered_payloads <- if (length(expected_ids)) payloads[expected_ids] else list()
  batch_id <- phase21_batch_identity(ordered_payloads, batch_id)
  rendered <- list()
  if (nrow(rows)) for (index in seq_len(nrow(rows))) {
    row <- rows[index, , drop = FALSE]
    rendered[[row$edition_id[[1L]]]] <- phase21_render_route_v2(ordered_payloads[[row$edition_id[[1L]]]], stage_root, row, batch_id)
  }
  manifest <- list(schema_version = phase21_dashboard_schema_version, batch_id = batch_id,
                   generated_at_utc = generated_at_utc, routes = as.character(rows$route_slug),
                   inventory = phase21_expected_public_inventory(registry),
                   route_manifests = lapply(rendered, `[[`, "route_manifest"),
                   statuses = if (length(ordered_payloads)) vapply(ordered_payloads, function(payload) phase21_safe_scalar(payload$metadata$lifecycle_state), character(1)) else character(),
                   lineage = if (length(ordered_payloads)) lapply(ordered_payloads, function(payload) payload$metadata[c("source_bundle_id", "source_bundle_sha256", "model_release_id", "ruleset_version", "ruleset_sha256", "projection_run_id")]) else list())
  phase21_write_json(manifest, file.path(stage_root, "phase21-batch-manifest.json"))
  phase21_write_json(list(schema_version = phase21_dashboard_schema_version, batch_id = batch_id,
                          status = "accepted", manifest_sha256 = phase21_public_hash(phase21_canonical_value_bytes(manifest)),
                          inventory = phase21_expected_public_inventory(registry)), file.path(stage_root, "current.json"))
  validation <- phase21_validate_batch(stage_root, registry, expected_batch_id = batch_id)
  list(valid = TRUE, batch_id = batch_id, stage_root = stage_root, rendered = rendered, validation = validation)
}

phase21_promote_batch <- function(candidate_root, public_root, registry = phase21_default_edition_registry(), injectors = list(), read_back = TRUE) {
  registry <- phase21_validate_registry(registry)
  candidate_root <- phase21_public_root(candidate_root)
  public_root <- as.character(public_root)[[1L]]
  if (is.na(public_root) || !nzchar(public_root)) stop("Phase 21 public root is required", call. = FALSE)
  parent <- dirname(normalizePath(public_root, winslash = "/", mustWork = FALSE))
  if (!dir.exists(parent)) dir.create(parent, recursive = TRUE, showWarnings = FALSE)
  parent <- normalizePath(parent, winslash = "/", mustWork = TRUE)
  if (!identical(normalizePath(dirname(candidate_root), winslash = "/", mustWork = TRUE), parent)) stop("Phase 21 candidate and public roots must share a filesystem parent", call. = FALSE)
  validation <- phase21_validate_batch(candidate_root, registry)
  backup <- tempfile("phase21-incumbent-", tmpdir = parent)
  had_incumbent <- dir.exists(public_root) && length(list.files(public_root, all.files = TRUE, no.. = TRUE)) > 0L
  if (dir.exists(public_root) && !had_incumbent) unlink(public_root, recursive = TRUE, force = TRUE)
  if (had_incumbent && !file.rename(public_root, backup)) stop("Phase 21 incumbent move failed", call. = FALSE)
  committed <- FALSE
  on.exit(if (!committed) {
    if (dir.exists(public_root)) unlink(public_root, recursive = TRUE, force = TRUE)
    if (had_incumbent && dir.exists(backup)) file.rename(backup, public_root)
  }, add = TRUE)
  inject <- function(name) { fn <- injectors[[name]]; if (is.function(fn)) fn(); invisible(TRUE) }
  inject("promotion")
  if (!file.rename(candidate_root, public_root)) stop("Phase 21 candidate promotion failed", call. = FALSE)
  if (isTRUE(read_back)) { inject("read_back"); validation <- phase21_validate_batch(public_root, registry, expected_batch_id = validation$batch_id) }
  if (had_incumbent && dir.exists(backup)) unlink(backup, recursive = TRUE, force = TRUE)
  committed <- TRUE
  list(valid = TRUE, public_root = public_root, batch_id = validation$batch_id, validation = validation)
}

phase21_publish_batch <- function(payloads, registry = phase21_default_edition_registry(), public_root, batch_id = NULL, generated_at_utc = "2026-09-25T00:00:00Z", injectors = list()) {
  public_root <- as.character(public_root)[[1L]]
  parent <- dirname(normalizePath(public_root, winslash = "/", mustWork = FALSE))
  if (!dir.exists(parent)) dir.create(parent, recursive = TRUE, showWarnings = FALSE)
  stage <- tempfile("phase21-candidate-", tmpdir = parent)
  dir.create(stage, recursive = TRUE, showWarnings = FALSE)
  on.exit(if (dir.exists(stage)) unlink(stage, recursive = TRUE, force = TRUE), add = TRUE)
  staged <- phase21_stage_batch(payloads, registry, stage, batch_id = batch_id, generated_at_utc = generated_at_utc)
  promoted <- phase21_promote_batch(stage, public_root, registry, injectors = injectors)
  list(valid = TRUE, batch_id = promoted$batch_id, staged = staged, promoted = promoted)
}

phase21_validate_public_batch <- phase21_validate_batch
phase21_promote_public_batch <- phase21_promote_batch
