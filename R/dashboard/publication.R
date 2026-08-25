# Publication-facing pure helpers. Batch staging and promotion belong to Plan 03.

phase17_public_route_targets <- function(root = ".") {
  root <- phase17_project_root(root)
  routes <- phase17_routes()
  targets <- unlist(lapply(unname(routes), function(route) file.path(
    root, "docs/competitions", route, c("index.html", "payload.json", "route-manifest.json", "current.json")
  )), use.names = FALSE)
  names(targets) <- phase17_expected_public_inventory()[1:8]
  targets
}

phase17_render_route <- function(payload, root, batch_id = NULL, route_root = NULL) {
  phase17_validate_payload(payload)
  root <- phase17_project_root(root, create = TRUE)
  route <- unname(phase17_routes()[[payload$edition_id]])
  if (is.null(route) || is.na(route)) stop("Phase 17 payload route is unknown", call. = FALSE)
  route_base <- route_root %||% file.path(root, "docs/competitions")
  route_base <- normalizePath(route_base, winslash = "/", mustWork = FALSE)
  if (!phase17_path_within(route_base, root)) stop("Phase 17 route root escaped root", call. = FALSE)
  route_root <- file.path(route_base, route)
  dir.create(route_root, recursive = TRUE, showWarnings = FALSE)
  html <- render_phase17_dashboard(payload, route = route)
  payload_bytes <- phase17_payload_bytes(payload)
  batch_id <- batch_id %||% payload$metadata$batch_id
  route_manifest <- list(schema_version = phase17_dashboard_schema_version,
                         route = paste0("/competitions/", route, "/"),
                         edition_id = payload$edition_id, batch_id = batch_id,
                         payload_sha256 = phase17_sha256_raw(payload_bytes),
                         html_sha256 = phase17_sha256_raw(charToRaw(enc2utf8(html))))
  current <- list(schema_version = phase17_dashboard_schema_version,
                  edition_id = payload$edition_id, batch_id = batch_id,
                  status = payload$metadata$lifecycle_state,
                  payload_sha256 = route_manifest$payload_sha256)
  writeBin(charToRaw(enc2utf8(html)), file.path(route_root, "index.html"))
  writeBin(payload_bytes, file.path(route_root, "payload.json"))
  phase17_write_json_bytes(route_manifest, file.path(route_root, "route-manifest.json"))
  phase17_write_json_bytes(current, file.path(route_root, "current.json"))
  files <- file.path(route_root, c("index.html", "payload.json", "route-manifest.json", "current.json"))
  phase17_validate_byte_limits(files)
  list(route = route, files = files, route_manifest = route_manifest, current = current)
}

phase17_validate_published_route <- function(payload, route_root) {
  phase17_validate_payload(payload)
  route_root <- phase17_project_root(route_root)
  files <- file.path(route_root, c("index.html", "payload.json", "route-manifest.json", "current.json"))
  if (any(!file.exists(files))) stop("Phase 17 published route is incomplete", call. = FALSE)
  manifest <- phase17_json_read(files[[3L]])
  actual <- phase17_sha256_raw(phase17_file_bytes(files[[2L]]))
  if (!identical(tolower(actual), tolower(as.character(manifest$payload_sha256)))) stop("Phase 17 payload read-back hash mismatch", call. = FALSE)
  invisible(TRUE)
}

phase17_batch_relative_inventory <- function() {
  sub("^docs/competitions/", "", phase17_expected_public_inventory())
}

phase17_batch_identity <- function(payloads = NULL, bundles = NULL, batch_id = NULL) {
  if (!is.null(batch_id)) return(phase17_scalar(batch_id, "batch_id"))
  values <- c(payloads, bundles)
  if (!length(values)) stop("Phase 17 batch identity requires payloads or bundles", call. = FALSE)
  metadata <- lapply(values, function(value) {
    if (!is.list(value)) stop("Phase 17 batch identity inputs must be lists", call. = FALSE)
    if (!is.null(value$metadata)) value <- value$metadata
    value[c("edition_id", "source_bundle_id", "source_bundle_sha256", "model_release_id",
            "release_manifest_sha256", "ruleset_version", "ruleset_sha256", "simulation_seed",
            "simulation_count", "projection_run_id")]
  })
  paste0("phase17-", substr(phase17_sha256_raw(phase17_canonical_bytes(metadata)), 1L, 24L))
}

phase17_batch_files <- function(root) {
  root <- phase17_project_root(root)
  inventory <- phase17_batch_relative_inventory()
  paths <- file.path(root, inventory)
  names(paths) <- phase17_expected_public_inventory()
  paths
}

phase17_assert_exact_batch_paths <- function(root) {
  root <- phase17_project_root(root)
  expected <- phase17_batch_relative_inventory()
  if (!dir.exists(root)) stop("Phase 17 batch root is missing", call. = FALSE)
  actual <- list.files(root, recursive = TRUE, all.files = FALSE, full.names = FALSE, include.dirs = FALSE)
  actual <- gsub("\\\\", "/", actual)
  if (any(grepl("(^|/)\\.\\.?(/|$)|(^|/)refresh_batches(/|$)|(^|/)(raw|logs)(/|$)|score_distributions", actual))) {
    stop("Phase 17 batch contains a prohibited path", call. = FALSE)
  }
  if (!identical(sort(actual), sort(expected))) {
    stop("Phase 17 batch inventory is not exact", call. = FALSE)
  }
  paths <- file.path(root, expected)
  is_symlink <- function(path) {
    link <- tryCatch(Sys.readlink(path), error = function(error) "")
    length(link) == 1L && nzchar(link)
  }
  if (any(vapply(paths, is_symlink, logical(1)))) {
    stop("Phase 17 batch contains a symlink", call. = FALSE)
  }
  if (any(!vapply(paths, function(path) phase17_path_within(path, root), logical(1)))) {
    stop("Phase 17 batch path escaped root", call. = FALSE)
  }
  paths
}

phase17_validate_batch_envelope <- function(root, batch_manifest = NULL, expected_batch_id = NULL) {
  root <- phase17_project_root(root)
  paths <- phase17_assert_exact_batch_paths(root)
  names(paths) <- phase17_batch_relative_inventory()
  json_paths <- paths[grepl("\\.json$", names(paths))]
  json <- lapply(json_paths, phase17_json_read)
  names(json) <- names(json_paths)
  json_batch_id <- function(value) {
    value$batch_id %||% value$metadata$batch_id %||% ""
  }
  ids <- unique(vapply(json, function(value) as.character(json_batch_id(value)), character(1)))
  if (length(ids) != 1L || !nzchar(ids[[1L]])) stop("Phase 17 batch identity is mixed or missing", call. = FALSE)
  if (!is.null(expected_batch_id) && !identical(ids[[1L]], phase17_scalar(expected_batch_id, "expected_batch_id"))) {
    stop("Phase 17 batch identity does not match expected identity", call. = FALSE)
  }
  manifest <- batch_manifest %||% json[["phase17-batch-manifest.json"]]
  if (!is.list(manifest) || !identical(as.character(manifest$batch_id), ids[[1L]])) {
    stop("Phase 17 batch manifest is invalid", call. = FALSE)
  }
  route_manifests <- json[c("nations-league/route-manifest.json", "euro-qualifying/route-manifest.json")]
  route_ids <- vapply(route_manifests, function(value) as.character(value$batch_id), character(1))
  if (any(route_ids != ids[[1L]])) stop("Phase 17 route manifest identity mismatch", call. = FALSE)
  for (route in c("nations-league", "euro-qualifying")) {
    prefix <- paste0(route, "/")
    manifest_path <- paths[[paste0(prefix, "route-manifest.json")]]
    route_manifest <- json[[paste0(prefix, "route-manifest.json")]]
    payload_path <- paths[[paste0(prefix, "payload.json")]]
    html_path <- paths[[paste0(prefix, "index.html")]]
    if (!identical(tolower(as.character(route_manifest$payload_sha256)),
                   tolower(phase17_sha256_raw(phase17_file_bytes(payload_path))))) {
      stop("Phase 17 route payload hash mismatch", call. = FALSE)
    }
    if (!identical(tolower(as.character(route_manifest$html_sha256)),
                   tolower(phase17_sha256_raw(phase17_file_bytes(html_path))))) {
      stop("Phase 17 route HTML hash mismatch", call. = FALSE)
    }
    if (!identical(as.character(json[[paste0(prefix, "current.json")]]$payload_sha256),
                   as.character(route_manifest$payload_sha256))) {
      stop("Phase 17 current pointer hash mismatch", call. = FALSE)
    }
  }
  expected_routes <- c("nations-league", "euro-qualifying")
  if (!identical(as.character(manifest$routes), expected_routes)) {
    stop("Phase 17 batch manifest route order is invalid", call. = FALSE)
  }
  if (!identical(sort(as.character(manifest$inventory)), sort(phase17_expected_public_inventory()))) {
    stop("Phase 17 batch manifest inventory is invalid", call. = FALSE)
  }
  limits <- phase17_validate_byte_limits(paths, phase17_max_public_file_bytes, phase17_max_batch_bytes)
  list(valid = TRUE, batch_id = ids[[1L]], inventory = phase17_expected_public_inventory(),
       files = paths, manifest = manifest, limits = limits)
}

phase17_with_batch_lock <- function(root, code, lock_name = ".phase17-batch.lock") {
  root <- phase17_project_root(root, create = TRUE)
  lock <- phase17_resolve_path(root, lock_name)
  if (file.exists(lock) || dir.exists(lock)) stop("Phase 17 batch lock collision", call. = FALSE)
  if (!dir.create(lock)) stop("Phase 17 could not acquire batch lock", call. = FALSE)
  on.exit(unlink(lock, recursive = TRUE, force = TRUE), add = TRUE)
  force(code)
}

phase17_rollback_batch <- function(public_root, incumbent_root = NULL, incumbent_snapshot = NULL) {
  public_root <- phase17_project_root(public_root)
  if (!is.null(incumbent_root) && dir.exists(incumbent_root)) {
    if (dir.exists(public_root)) unlink(public_root, recursive = TRUE, force = TRUE)
    if (!file.rename(incumbent_root, public_root)) stop("Phase 17 rollback rename failed", call. = FALSE)
    return(invisible(TRUE))
  }
  if (!is.null(incumbent_snapshot)) {
    dir.create(public_root, recursive = TRUE, showWarnings = FALSE)
    for (item in incumbent_snapshot) {
      target <- file.path(public_root, item$path)
      dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
      writeBin(item$bytes, target)
    }
    return(invisible(TRUE))
  }
  invisible(FALSE)
}

phase17_promote_batch <- function(candidate_root, public_root, injectors = list(), read_back = TRUE) {
  candidate_root <- phase17_project_root(candidate_root)
  public_root <- phase17_project_root(public_root, create = FALSE)
  phase17_validate_batch_envelope(candidate_root)
  parent <- dirname(public_root)
  if (!identical(normalizePath(dirname(candidate_root), winslash = "/", mustWork = TRUE),
                 normalizePath(parent, winslash = "/", mustWork = TRUE))) {
    stop("Phase 17 candidate and public roots must share a filesystem parent", call. = FALSE)
  }
  backup <- tempfile("phase17-incumbent-", tmpdir = parent)
  had_incumbent <- dir.exists(public_root) && length(list.files(public_root, all.files = TRUE, no.. = TRUE)) > 0L
  if (dir.exists(public_root) && !had_incumbent) unlink(public_root, recursive = TRUE, force = TRUE)
  if (had_incumbent && !file.rename(public_root, backup)) stop("Phase 17 incumbent move failed", call. = FALSE)
  committed <- FALSE
  on.exit(if (!committed) {
    if (dir.exists(public_root)) unlink(public_root, recursive = TRUE, force = TRUE)
    if (had_incumbent && dir.exists(backup)) {
      if (!file.rename(backup, public_root)) stop("Phase 17 incumbent rollback failed", call. = FALSE)
    }
  }, add = TRUE)
  injector <- function(name) {
    fn <- injectors[[name]]
    if (is.function(fn)) fn()
    invisible(TRUE)
  }
  injector("promotion")
  if (!file.rename(candidate_root, public_root)) stop("Phase 17 candidate promotion failed", call. = FALSE)
  if (isTRUE(read_back)) {
    injector("read_back")
    phase17_validate_batch_envelope(public_root)
  }
  if (had_incumbent && dir.exists(backup)) unlink(backup, recursive = TRUE, force = TRUE)
  committed <- TRUE
  invisible(list(public_root = public_root, validated = TRUE))
}
