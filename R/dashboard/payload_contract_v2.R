# Phase 21 neutral dashboard payload contract.

`%||%` <- function(left, right) if (is.null(left) || !length(left)) right else left

phase21_dashboard_schema_version <- "phase21-dashboard-v2"

phase21_section_ids <- function() {
  c("overview", "structure", "standings", "fixtures", "results", "form",
    "match_forecasts", "rank_distributions", "qualification_bands",
    "knockout_paths", "progression_probabilities", "projected_outcomes")
}

phase21_section_states <- function() {
  c("available", "pre_draw", "loading", "blocked", "unavailable",
    "unresolved", "suppressed", "partial", "stale")
}

phase21_status_labels <- function() {
  c(available = "Available", pre_draw = "Pre-draw", loading = "Refresh pending",
    blocked = "Refresh blocked", unavailable = "Unavailable", unresolved = "Unresolved",
    suppressed = "Suppressed", partial = "Partial", stale = "Stale")
}

phase21_safe_scalar <- function(value, default = "") {
  if (is.null(value) || !length(value) || length(value) != 1L || is.na(value[[1L]])) return(default)
  as.character(value[[1L]])
}

phase21_rows <- function(value) {
  if (is.null(value)) return(list())
  if (is.data.frame(value)) {
    if (!nrow(value)) return(list())
    return(unname(lapply(seq_len(nrow(value)), function(index) as.list(value[index, , drop = FALSE]))))
  }
  if (is.list(value)) return(unname(value))
  stop("Phase 21 section rows must be a data frame or list", call. = FALSE)
}

phase21_section <- function(id, label, rows = list(), status = NULL, reason = "", filter_dimensions = character()) {
  id <- as.character(id)[[1L]]
  rows <- phase21_rows(rows)
  if (is.null(status)) status <- if (length(rows)) "available" else "unavailable"
  if (!status %in% phase21_section_states()) stop("Phase 21 section state is unsupported: ", status, call. = FALSE)
  list(id = id, label = as.character(label)[[1L]], status = status,
       reason = as.character(reason %||% "")[[1L]], rows = rows,
       filter_dimensions = as.character(filter_dimensions))
}

phase21_default_metadata <- function(edition_id, batch_id = "phase21-fixture-batch-v1", display_name = edition_id) {
  list(
    batch_id = batch_id, edition_id = edition_id,
    competition_display_name = display_name,
    lifecycle_state = "unavailable", forecast_status = "unavailable",
    last_refresh_at_utc = NA_character_, generated_at_utc = NA_character_,
    source_confidence = "unknown", source_status = "unavailable",
    source_bundle_id = NA_character_, source_bundle_sha256 = NA_character_,
    model_release_id = NA_character_, model_sha256 = NA_character_,
    calibrator_sha256 = NA_character_, release_manifest_sha256 = NA_character_,
    ruleset_version = NA_character_, ruleset_sha256 = NA_character_,
    projection_run_id = NA_character_, simulation_seed = NA_integer_,
    simulation_count = NA_integer_, information_cutoff_utc = NA_character_,
    feature_cutoff_utc = NA_character_, draw_artifact_sha256 = NA_character_,
    authority_mode = NA_character_, production_eligible = FALSE,
    freshness_status = "unknown", delay_seconds = NA_real_,
    showing_last_accepted_snapshot = FALSE, warnings = character()
  )
}

phase21_validate_payload <- function(payload, registry = NULL) {
  if (!is.list(payload)) stop("Phase 21 payload must be a list", call. = FALSE)
  required <- c("schema_version", "edition_id", "metadata", "sections", "credits")
  missing <- setdiff(required, names(payload))
  if (length(missing)) stop("Phase 21 payload is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  if (!identical(as.character(payload$schema_version[[1L]]), phase21_dashboard_schema_version)) stop("Phase 21 payload schema version is unsupported", call. = FALSE)
  edition_id <- phase21_safe_scalar(payload$edition_id)
  if (!nzchar(edition_id)) stop("Phase 21 payload edition_id must be non-empty", call. = FALSE)
  if (!is.null(registry)) {
    registry <- phase21_validate_registry(registry)
    if (!edition_id %in% registry$edition_id) stop("Phase 21 payload edition_id is not registered", call. = FALSE)
  }
  if (!is.list(payload$metadata) || !is.list(payload$sections) || !is.list(payload$credits)) stop("Phase 21 payload metadata, sections, and credits must be lists", call. = FALSE)
  if (!identical(names(payload$sections), phase21_section_ids())) stop("Phase 21 payload sections must use the stable twelve-section order", call. = FALSE)
  for (index in seq_along(payload$sections)) {
    section <- payload$sections[[index]]
    if (!is.list(section) || !all(c("id", "label", "status", "reason", "rows") %in% names(section))) stop("Phase 21 section is missing typed status fields", call. = FALSE)
    if (length(section$id) != 1L || !identical(as.character(section$id[[1L]]), names(payload$sections)[[index]])) stop("Phase 21 section id/order is invalid", call. = FALSE)
    if (!phase21_safe_scalar(section$status) %in% phase21_section_states()) stop("Phase 21 section status is unsupported", call. = FALSE)
    if (!is.list(section$rows)) stop("Phase 21 section rows must be a list", call. = FALSE)
  }
  metadata_required <- c("batch_id", "edition_id", "lifecycle_state", "forecast_status",
                         "last_refresh_at_utc", "source_bundle_id", "model_release_id",
                         "ruleset_version", "projection_run_id", "simulation_seed",
                         "simulation_count", "freshness_status", "showing_last_accepted_snapshot")
  missing_metadata <- setdiff(metadata_required, names(payload$metadata))
  if (length(missing_metadata)) stop("Phase 21 payload metadata is missing: ", paste(missing_metadata, collapse = ", "), call. = FALSE)
  if (!identical(phase21_safe_scalar(payload$metadata$edition_id), edition_id)) stop("Phase 21 metadata edition_id does not match payload", call. = FALSE)
  invisible(TRUE)
}

phase21_payload_bytes <- function(payload) {
  phase21_validate_payload(payload)
  if (exists("phase17_canonical_bytes", mode = "function", inherits = TRUE)) return(phase17_canonical_bytes(payload))
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("Phase 21 payload serialization requires jsonlite", call. = FALSE)
  charToRaw(enc2utf8(as.character(jsonlite::toJSON(payload, auto_unbox = TRUE, null = "null", na = "null", dataframe = "rows", digits = 16, pretty = FALSE))))
}

phase21_hash_raw <- function(bytes) {
  if (exists("phase17_sha256_raw", mode = "function", inherits = TRUE)) return(phase17_sha256_raw(bytes))
  if (!requireNamespace("digest", quietly = TRUE)) stop("Phase 21 hashing requires digest", call. = FALSE)
  digest::digest(bytes, algo = "sha256", serialize = FALSE)
}

phase21_metadata_from_bundle <- function(bundle, batch_id, display_name = NULL) {
  edition_id <- phase21_safe_scalar(bundle$edition_id, "unknown")
  metadata <- phase21_default_metadata(edition_id, batch_id, display_name %||% edition_id)
  fields <- names(metadata)
  for (field in intersect(fields, names(bundle))) metadata[[field]] <- bundle[[field]]
  metadata$batch_id <- batch_id
  metadata$edition_id <- edition_id
  metadata$source_status <- phase21_safe_scalar(bundle$source_status, phase21_safe_scalar(bundle$candidate_status, "accepted_bundle"))
  metadata$freshness_status <- phase21_safe_scalar(bundle$freshness_status, metadata$freshness_status)
  metadata$warnings <- as.character(bundle$warnings %||% character())
  metadata$showing_last_accepted_snapshot <- isTRUE(bundle$showing_last_accepted_snapshot %||% FALSE)
  metadata$production_eligible <- isTRUE(bundle$production_eligible %||% FALSE)
  metadata
}

phase21_status_for_rows <- function(rows, lifecycle = "unavailable", reason = NULL) {
  if (length(rows)) return(list(status = "available", reason = ""))
  if (identical(lifecycle, "pre_draw")) return(list(status = "pre_draw", reason = reason %||% "Awaiting the official draw and schedule."))
  if (lifecycle %in% c("blocked", "revision_blocked")) return(list(status = "blocked", reason = reason %||% "Refresh blocked; no new rows were accepted."))
  list(status = "unavailable", reason = reason %||% "No accepted data for this section.")
}

phase21_payload_from_bundle <- function(bundle, registry_row = NULL, batch_id = NULL) {
  if (!is.list(bundle)) stop("Phase 21 adapter requires a bundle list", call. = FALSE)
  edition_id <- phase21_safe_scalar(bundle$edition_id)
  if (!nzchar(edition_id)) stop("Phase 21 bundle edition_id is required", call. = FALSE)
  if (is.null(batch_id)) batch_id <- phase21_safe_scalar(bundle$batch_id, "phase21-fixture-batch-v1")
  display_name <- if (is.null(registry_row)) edition_id else as.character(registry_row$display_name[[1L]])
  metadata <- phase21_metadata_from_bundle(bundle, batch_id, display_name)
  names_map <- c(structure = "Structure", standings = "Standings", fixtures = "Fixtures", results = "Results",
                 form = "Form", match_forecasts = "Match forecasts", forecasts = "Match forecasts", rank_distributions = "Rank distributions",
                 qualification_bands = "Qualification bands", knockout_paths = "Knockout paths",
                 progression_probabilities = "Progression probabilities", projected_outcomes = "Projected outcomes")
  artifacts <- bundle$artifacts %||% list()
  sections <- list(overview = phase21_section("overview", "Overview", list(), "available", "Metadata and lineage are shown below.", "section"))
  for (id in phase21_section_ids()[-1L]) {
    artifact_name <- switch(id, match_forecasts = "forecasts", id)
    rows <- phase21_rows(artifacts[[artifact_name]])
    state <- phase21_status_for_rows(rows, metadata$lifecycle_state, if (length(metadata$warnings)) metadata$warnings[[1L]] else NULL)
    sections[[id]] <- phase21_section(id, names_map[[id]], rows, state$status, state$reason,
                                      c("section", "team", "matchday", "status"))
  }
  # Legacy bundles do not carry UCL-specific artifacts.  Keep the four views
  # typed and empty rather than guessing values or zero-filling probabilities.
  for (id in c("rank_distributions", "qualification_bands", "knockout_paths", "progression_probabilities")) {
    if (!length(sections[[id]]$rows)) sections[[id]] <- phase21_section(id, names_map[[id]], list(), "unavailable", "This edition does not publish this enrichment.", c("section", "team", "status"))
  }
  payload <- list(schema_version = phase21_dashboard_schema_version, edition_id = edition_id,
                  metadata = metadata, sections = sections,
                  credits = bundle$credits %||% list(source_name = "UEFA", source_url = "https://www.uefa.com/", license = "Official competition source"))
  phase21_validate_payload(payload)
  payload
}

phase21_normalize_phase17_payload <- function(payload, registry_row = NULL, batch_id = NULL) {
  if (!is.list(payload)) stop("Phase 17 payload must be a list", call. = FALSE)
  edition_id <- phase21_safe_scalar(payload$edition_id)
  if (!nzchar(edition_id)) stop("Legacy payload edition_id is required", call. = FALSE)
  if (is.null(batch_id)) batch_id <- phase21_safe_scalar(payload$metadata$batch_id, "phase21-compat-batch-v1")
  display_name <- if (is.null(registry_row)) edition_id else as.character(registry_row$display_name[[1L]])
  metadata <- phase21_default_metadata(edition_id, batch_id, display_name)
  metadata <- modifyList(metadata, payload$metadata %||% list())
  metadata$batch_id <- batch_id
  metadata$edition_id <- edition_id
  labels <- c(overview = "Overview", structure = "Structure", standings = "Standings", fixtures = "Fixtures", results = "Results", form = "Form", match_forecasts = "Match forecasts", rank_distributions = "Rank distributions", qualification_bands = "Qualification bands", knockout_paths = "Knockout paths", progression_probabilities = "Progression probabilities", projected_outcomes = "Projected outcomes")
  sections <- lapply(phase21_section_ids(), function(id) {
    legacy <- payload$sections[[id]]
    if (is.null(legacy)) return(phase21_section(id, labels[[id]], list(), "unavailable", "This section is not available for this edition."))
    phase21_section(id, labels[[id]], legacy$rows %||% list(), phase21_safe_scalar(legacy$status, "unavailable"), phase21_safe_scalar(legacy$reason), legacy$filter_dimensions %||% character())
  })
  names(sections) <- phase21_section_ids()
  result <- list(schema_version = phase21_dashboard_schema_version, edition_id = edition_id,
                 metadata = metadata, sections = sections, credits = payload$credits %||% list())
  phase21_validate_payload(result)
  result
}

phase21_blocked_payload <- function(edition_id, reason = "No accepted source/model authority is available.", registry_row = NULL, batch_id = "phase21-blocked-batch-v1", status = "blocked") {
  display_name <- if (is.null(registry_row)) edition_id else as.character(registry_row$display_name[[1L]])
  metadata <- phase21_default_metadata(edition_id, batch_id, display_name)
  metadata$lifecycle_state <- "unavailable"
  metadata$forecast_status <- "unavailable"
  metadata$source_status <- "blocked"
  metadata$freshness_status <- "unknown"
  metadata$warnings <- reason
  labels <- c(overview = "Overview", structure = "Structure", standings = "Standings", fixtures = "Fixtures", results = "Results", form = "Form", match_forecasts = "Match forecasts", rank_distributions = "Rank distributions", qualification_bands = "Qualification bands", knockout_paths = "Knockout paths", progression_probabilities = "Progression probabilities", projected_outcomes = "Projected outcomes")
  sections <- lapply(phase21_section_ids(), function(id) phase21_section(id, labels[[id]], list(), status, reason))
  names(sections) <- phase21_section_ids()
  payload <- list(schema_version = phase21_dashboard_schema_version, edition_id = edition_id,
                  metadata = metadata, sections = sections,
                  credits = list(source_name = "UEFA", source_url = "https://www.uefa.com/", license = "Official competition source"))
  phase21_validate_payload(payload)
  payload
}
