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

phase17_render_route <- function(payload, root, batch_id = NULL) {
  phase17_validate_payload(payload)
  root <- phase17_project_root(root, create = TRUE)
  route <- unname(phase17_routes()[[payload$edition_id]])
  if (is.null(route) || is.na(route)) stop("Phase 17 payload route is unknown", call. = FALSE)
  route_root <- file.path(root, "docs/competitions", route)
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
