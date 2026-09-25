# Phase 21 registry-driven dashboard edition inventory.
#
# The registry is deliberately small and data-driven.  It is the only source
# of truth for which editions are enabled, which adapter builds them, and which
# route/credit/size policy applies to a published edition.

`%||%` <- function(left, right) if (is.null(left) || !length(left)) right else left

phase21_registry_schema_version <- "phase21-edition-registry-v1"
phase21_default_max_file_bytes <- 5L * 1024L * 1024L
phase21_default_max_batch_bytes <- 20L * 1024L * 1024L

phase21_registry_columns <- function() {
  c("edition_id", "adapter_id", "route_slug", "display_name", "enabled",
    "publish_enabled", "credits", "max_file_bytes", "max_batch_bytes", "lifecycle")
}

phase21_default_edition_registry <- function() {
  data.frame(
    edition_id = c("uefa_nations_league_2026_27", "uefa_euro_2028_qualifying", "ucl_2026_27"),
    adapter_id = c("phase17_nations_league", "phase17_euro", "phase21_ucl"),
    route_slug = c("nations-league", "euro-qualifying", "champions-league"),
    display_name = c("UEFA Nations League 2026/27", "UEFA EURO 2028 qualifying", "UEFA Champions League 2026/27"),
    enabled = TRUE,
    publish_enabled = TRUE,
    credits = c("UEFA; xGelo", "UEFA; xGelo", "UEFA; xGelo"),
    max_file_bytes = rep(phase21_default_max_file_bytes, 3L),
    max_batch_bytes = rep(phase21_default_max_batch_bytes, 3L),
    lifecycle = c("active", "pre_draw", "unavailable"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

phase21_validate_registry <- function(registry = phase21_default_edition_registry(), allow_empty = TRUE) {
  if (is.null(registry)) registry <- phase21_default_edition_registry()[FALSE, , drop = FALSE]
  if (is.list(registry) && !is.data.frame(registry)) {
    registry <- tryCatch(as.data.frame(registry, stringsAsFactors = FALSE, check.names = FALSE),
                         error = function(error) stop("Phase 21 registry must be rectangular: ", conditionMessage(error), call. = FALSE))
  }
  if (!is.data.frame(registry)) stop("Phase 21 registry must be a data frame", call. = FALSE)
  required <- phase21_registry_columns()
  missing <- setdiff(required, names(registry))
  if (length(missing)) stop("Phase 21 registry is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  registry <- registry[, required, drop = FALSE]
  if (!allow_empty && !nrow(registry)) stop("Phase 21 registry cannot be empty", call. = FALSE)
  scalar_columns <- c("edition_id", "adapter_id", "route_slug", "display_name", "credits", "lifecycle")
  for (column in scalar_columns) {
    registry[[column]] <- as.character(registry[[column]])
    if (any(is.na(registry[[column]]) | !nzchar(trimws(registry[[column]])))) {
      stop("Phase 21 registry column ", column, " must contain non-empty values", call. = FALSE)
    }
  }
  for (column in c("enabled", "publish_enabled")) {
    values <- registry[[column]]
    if (is.factor(values)) values <- as.character(values)
    if (is.character(values)) {
      lowered <- tolower(trimws(values))
      if (any(!lowered %in% c("true", "false", "1", "0"))) {
        stop("Phase 21 registry column ", column, " must be logical", call. = FALSE)
      }
      values <- lowered %in% c("true", "1")
    }
    if (!is.logical(values) || any(is.na(values))) stop("Phase 21 registry column ", column, " must be logical", call. = FALSE)
    registry[[column]] <- values
  }
  for (column in c("max_file_bytes", "max_batch_bytes")) {
    values <- suppressWarnings(as.numeric(registry[[column]]))
    if (any(!is.finite(values) | values <= 0 | values != floor(values))) {
      stop("Phase 21 registry column ", column, " must contain positive byte limits", call. = FALSE)
    }
    registry[[column]] <- as.numeric(values)
  }
  if (anyDuplicated(registry$edition_id)) stop("Phase 21 registry edition_id values must be unique", call. = FALSE)
  if (anyDuplicated(registry$route_slug)) stop("Phase 21 registry route_slug values must be unique", call. = FALSE)
  if (anyDuplicated(registry$adapter_id)) stop("Phase 21 registry adapter_id values must be unique", call. = FALSE)
  if (any(!grepl("^[a-z0-9][a-z0-9_-]*$", registry$edition_id))) stop("Phase 21 registry edition_id contains an unsafe identifier", call. = FALSE)
  if (any(!grepl("^[a-z0-9][a-z0-9-]*$", registry$route_slug))) stop("Phase 21 registry route_slug contains an unsafe route", call. = FALSE)
  if (any(grepl("(^|/)\\.\\.?(/|$)|(^|/)(raw|logs|refresh_batches)(/|$)", registry$route_slug))) stop("Phase 21 registry route_slug contains a prohibited path", call. = FALSE)
  registry
}

phase21_enabled_registry <- function(registry = phase21_default_edition_registry(), publish_only = TRUE) {
  registry <- phase21_validate_registry(registry)
  keep <- registry$enabled
  if (isTRUE(publish_only)) keep <- keep & registry$publish_enabled
  registry[keep, , drop = FALSE]
}

phase21_registry_row <- function(registry, edition_id) {
  registry <- phase21_validate_registry(registry)
  edition_id <- as.character(edition_id)[[1L]]
  rows <- registry[registry$edition_id == edition_id, , drop = FALSE]
  if (nrow(rows) != 1L) stop("Phase 21 registry edition is not registered exactly once: ", edition_id, call. = FALSE)
  rows[1L, , drop = FALSE]
}

phase21_enabled_edition_ids <- function(registry = phase21_default_edition_registry()) {
  phase21_enabled_registry(registry)$edition_id
}

phase21_registry_routes <- function(registry = phase21_default_edition_registry()) {
  rows <- phase21_enabled_registry(registry)
  routes <- rows$route_slug
  names(routes) <- rows$edition_id
  routes
}

phase21_registry_adapters <- function(registry = phase21_default_edition_registry()) {
  rows <- phase21_enabled_registry(registry)
  adapters <- rows$adapter_id
  names(adapters) <- rows$edition_id
  adapters
}

phase21_batch_relative_inventory <- function(registry = phase21_default_edition_registry()) {
  rows <- phase21_enabled_registry(registry)
  route_files <- unlist(lapply(rows$route_slug, function(route) file.path(
    route, c("index.html", "payload.json", "route-manifest.json", "current.json")
  )), use.names = FALSE)
  c(route_files, "phase21-batch-manifest.json", "current.json")
}

phase21_expected_public_inventory <- function(registry = phase21_default_edition_registry(), prefix = "docs/competitions") {
  prefix <- as.character(prefix)[[1L]]
  if (is.na(prefix) || grepl("(^|/)\\.\\.?(/|$)", prefix)) stop("Phase 21 inventory prefix is unsafe", call. = FALSE)
  file.path(prefix, phase21_batch_relative_inventory(registry))
}

phase21_registry_manifest <- function(registry = phase21_default_edition_registry()) {
  rows <- phase21_enabled_registry(registry)
  list(
    schema_version = phase21_registry_schema_version,
    editions = unname(rows$edition_id),
    routes = unname(rows$route_slug),
    adapters = unname(rows$adapter_id),
    limits = lapply(seq_len(nrow(rows)), function(index) {
      list(edition_id = rows$edition_id[[index]], max_file_bytes = rows$max_file_bytes[[index]],
           max_batch_bytes = rows$max_batch_bytes[[index]])
    })
  )
}

phase21_validate_edition_registry <- phase21_validate_registry
phase21_registry <- phase21_default_edition_registry
phase21_expected_batch_inventory <- phase21_batch_relative_inventory
