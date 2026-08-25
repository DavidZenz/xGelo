# Phase 17 dashboard contract and executable Wave 0 harness primitives.
#
# This file is deliberately independent of the competition builders.  Adapters
# may enrich the contract, but the renderer and publication gates only consume
# values validated here.

phase17_dashboard_schema_version <- "phase17-dashboard-v1"
phase17_max_public_file_bytes <- 5L * 1024L * 1024L
phase17_max_batch_bytes <- 20L * 1024L * 1024L
phase17_safari_driver_path <- "/System/Cryptexes/App/usr/bin/safaridriver"
phase17_safari_version <- "26.5.2"

if (!exists("%||%", mode = "function", inherits = TRUE)) {
  `%||%` <- function(left, right) if (is.null(left) || !length(left)) right else left
}

phase17_editions <- function() {
  c("uefa_nations_league_2026_27", "uefa_euro_2028_qualifying")
}

phase17_routes <- function() {
  c(
    uefa_nations_league_2026_27 = "nations-league",
    uefa_euro_2028_qualifying = "euro-qualifying"
  )
}

phase17_section_ids <- function() {
  c(
    "overview", "structure", "standings", "fixtures", "results",
    "form", "match_forecasts", "projected_outcomes"
  )
}

phase17_ui_state_ids <- function() {
  c(
    "empty_pre_draw", "loading_refresh_pending", "error_refresh_blocked",
    "populated", "partial", "overflow", "zero_one_many", "long_text"
  )
}

phase17_lifecycle_states <- function() {
  c("pre_draw", "scheduled", "in_progress", "complete", "active",
    "unavailable", "unresolved", "unsupported_topology", "revision_blocked")
}

phase17_section_states <- function() {
  c("available", "pre_draw", "loading", "blocked", "unavailable",
    "unresolved", "suppressed", "partial")
}

phase17_status_labels <- function() {
  c(available = "Available", pre_draw = "Pre-draw", loading = "Refresh pending",
    blocked = "Refresh blocked", unavailable = "Unavailable", unresolved = "Unresolved",
    suppressed = "Suppressed", partial = "Partial")
}

phase17_expected_public_inventory <- function() {
  c(
    "docs/competitions/nations-league/index.html",
    "docs/competitions/nations-league/payload.json",
    "docs/competitions/nations-league/route-manifest.json",
    "docs/competitions/nations-league/current.json",
    "docs/competitions/euro-qualifying/index.html",
    "docs/competitions/euro-qualifying/payload.json",
    "docs/competitions/euro-qualifying/route-manifest.json",
    "docs/competitions/euro-qualifying/current.json",
    "docs/competitions/phase17-batch-manifest.json",
    "docs/competitions/current.json"
  )
}

# One provider is the source of truth for publication, route generation and
# tests.  Keep repository code and fixtures in the same explicit allowlist so
# a later Git gate cannot accidentally publish raw inputs or operational logs.
phase17_expected_git_allowlist <- function() {
  sort(unique(c(
    phase17_expected_public_inventory(),
    file.path("R/dashboard", c(
      "payload_contract.R", "payload_nations_league.R", "payload_euro.R",
      "renderer.R", "publication.R", "production_provider.R"
    )),
    "tests/testthat/test_phase17_dashboards.R",
    "scripts/refresh_competition_dashboards.R",
    "scripts/auto_update_competition_dashboards.sh",
    "scripts/com.xgelo.competition-dashboards.plist",
    "scripts/com.xgelo.dashboard-update.plist"
  )))
}

phase17_scalar <- function(value, name, allow_empty = FALSE) {
  if (is.null(value) || length(value) != 1L || is.na(value)) {
    stop("Phase 17 ", name, " must be one non-missing scalar", call. = FALSE)
  }
  value <- as.character(value[[1L]])
  if (!allow_empty && !nzchar(value)) {
    stop("Phase 17 ", name, " must not be empty", call. = FALSE)
  }
  value
}

phase17_project_root <- function(root = ".", create = FALSE) {
  root <- phase17_scalar(root, "root")
  if (create && !dir.exists(root)) dir.create(root, recursive = TRUE, showWarnings = FALSE)
  normalizePath(root, winslash = "/", mustWork = TRUE)
}

phase17_path_within <- function(path, root) {
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  root <- normalizePath(root, winslash = "/", mustWork = FALSE)
  identical(path, root) || startsWith(path, paste0(root, "/"))
}

phase17_resolve_path <- function(root, relative, allow_absolute = FALSE) {
  root <- phase17_project_root(root)
  relative <- gsub("\\\\", "/", phase17_scalar(relative, "relative path"))
  if (grepl("(^|/)\\.\\.?(/|$)", relative) || grepl("^[A-Za-z]:", relative)) {
    stop("Phase 17 path traversal is not allowed: ", relative, call. = FALSE)
  }
  if (startsWith(relative, "/") && !allow_absolute) {
    stop("Phase 17 absolute path is not allowed: ", relative, call. = FALSE)
  }
  candidate <- if (startsWith(relative, "/")) relative else file.path(root, relative)
  candidate <- normalizePath(candidate, winslash = "/", mustWork = FALSE)
  if (!phase17_path_within(candidate, root)) stop("Phase 17 path escaped root", call. = FALSE)
  if (file.exists(candidate) && nzchar(Sys.readlink(candidate))) {
    stop("Phase 17 symlink path is not allowed: ", candidate, call. = FALSE)
  }
  candidate
}

phase17_sha256_raw <- function(bytes) {
  if (!is.raw(bytes)) stop("Phase 17 hash input must be raw bytes", call. = FALSE)
  digest::digest(bytes, algo = "sha256", serialize = FALSE)
}

phase17_file_bytes <- function(path) {
  if (!file.exists(path) || dir.exists(path)) stop("Phase 17 file is missing: ", path, call. = FALSE)
  readBin(path, what = "raw", n = as.integer(file.info(path)$size))
}

phase17_snapshot_bytes <- function(paths, root = NULL) {
  if (is.null(root)) root <- dirname(paths[[1L]])
  root <- phase17_project_root(root)
  paths <- as.character(paths)
  if (!length(paths) || anyDuplicated(paths)) stop("Phase 17 snapshot paths must be unique", call. = FALSE)
  result <- lapply(paths, function(path) {
    absolute <- if (startsWith(path, "/")) path else file.path(root, path)
    bytes <- phase17_file_bytes(absolute)
    list(path = path, bytes = bytes, size = length(bytes), sha256 = phase17_sha256_raw(bytes))
  })
  names(result) <- paths
  result
}

phase17_snapshot_equal <- function(first, second) {
  identical(first, second)
}

phase17_canonical_json <- function(value) {
  jsonlite::toJSON(value, auto_unbox = TRUE, null = "null", na = "null",
                   dataframe = "rows", digits = 16, pretty = FALSE)
}

phase17_canonical_bytes <- function(value) {
  charToRaw(enc2utf8(as.character(phase17_canonical_json(value))))
}

phase17_write_json_bytes <- function(value, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeBin(phase17_canonical_bytes(value), path)
  invisible(path)
}

phase17_json_read <- function(path) {
  if (!file.exists(path)) stop("Phase 17 JSON is missing: ", path, call. = FALSE)
  jsonlite::fromJSON(rawToChar(phase17_file_bytes(path)), simplifyVector = FALSE)
}

phase17_bytes_total <- function(paths) {
  sum(vapply(paths, function(path) as.numeric(file.info(path)$size), numeric(1)))
}

phase17_validate_byte_limits <- function(paths,
                                          max_file_bytes = phase17_max_public_file_bytes,
                                          max_batch_bytes = phase17_max_batch_bytes) {
  paths <- as.character(paths)
  if (!length(paths) || any(!file.exists(paths)) || any(dir.exists(paths))) {
    stop("Phase 17 byte validation requires existing files", call. = FALSE)
  }
  sizes <- vapply(paths, function(path) as.numeric(file.info(path)$size), numeric(1))
  if (any(sizes > max_file_bytes)) stop("Phase 17 public file exceeds byte limit", call. = FALSE)
  total <- sum(sizes)
  if (total > max_batch_bytes) stop("Phase 17 batch exceeds byte limit", call. = FALSE)
  list(valid = TRUE, files = sizes, total_bytes = total,
       max_file_bytes = max_file_bytes, max_batch_bytes = max_batch_bytes)
}

phase17_failure_injector <- function(name, fail = FALSE, reason = NULL) {
  name <- phase17_scalar(name, "injector name")
  function(...) {
    if (isTRUE(fail)) stop("Injected Phase 17 ", name, " failure",
                          if (!is.null(reason)) paste0(": ", reason) else "", call. = FALSE)
    invisible(FALSE)
  }
}

phase17_failure_injectors <- function() {
  setNames(lapply(c("source", "rules", "probability", "freshness", "replay",
                    "browser", "regression", "manifest", "hash", "promotion",
                    "read_back", "git_preflight"), phase17_failure_injector),
           c("source", "rules", "probability", "freshness", "replay", "browser",
             "regression", "manifest", "hash", "promotion", "read_back", "git_preflight"))
}

phase17_validate_payload <- function(payload) {
  if (!is.list(payload)) stop("Phase 17 payload must be a list", call. = FALSE)
  required <- c("schema_version", "edition_id", "metadata", "sections", "credits")
  missing <- setdiff(required, names(payload))
  if (length(missing)) stop("Phase 17 payload is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  if (!identical(as.character(payload$schema_version), phase17_dashboard_schema_version)) {
    stop("Phase 17 payload schema version is unsupported", call. = FALSE)
  }
  if (length(payload$edition_id) != 1L || is.na(payload$edition_id) ||
      !phase17_scalar(payload$edition_id, "payload edition_id") %in% phase17_editions()) {
    stop("Phase 17 payload edition_id must be one registered scalar edition", call. = FALSE)
  }
  if (!is.list(payload$metadata) || !is.list(payload$sections) || !is.list(payload$credits)) {
    stop("Phase 17 payload metadata, sections, and credits must be lists", call. = FALSE)
  }
  if (!identical(names(payload$sections), phase17_section_ids())) {
    stop("Phase 17 payload sections must use the stable eight-section order", call. = FALSE)
  }
  for (section in payload$sections) {
    if (!is.list(section) || !all(c("id", "label", "status", "reason", "rows") %in% names(section))) {
      stop("Phase 17 section is missing typed status fields", call. = FALSE)
    }
    if (!as.character(section$status[[1L]]) %in% phase17_section_states()) {
      stop("Phase 17 section status is unsupported", call. = FALSE)
    }
    if (!is.list(section$rows)) stop("Phase 17 section rows must be a list", call. = FALSE)
  }
  metadata_required <- c("batch_id", "lifecycle_state", "forecast_status", "last_refresh_at_utc",
                         "generated_at_utc", "source_confidence", "source_bundle_id",
                         "model_release_id", "ruleset_version", "projection_run_id",
                         "simulation_seed", "simulation_count")
  missing_metadata <- setdiff(metadata_required, names(payload$metadata))
  if (length(missing_metadata)) {
    stop("Phase 17 payload metadata is missing: ", paste(missing_metadata, collapse = ", "), call. = FALSE)
  }
  invisible(TRUE)
}

phase17_payload_bytes <- function(payload) {
  phase17_validate_payload(payload)
  phase17_canonical_bytes(payload)
}

phase17_assert_ui_states <- function(payload) {
  phase17_validate_payload(payload)
  state_text <- paste(unlist(payload, use.names = FALSE), collapse = " ")
  expected <- c("Available", "Pre-draw", "Refresh pending", "Refresh blocked",
                "Unavailable", "Unresolved", "Suppressed", "Showing last accepted snapshot")
  invisible(list(states = phase17_ui_state_ids(), labels = expected,
                 present = vapply(expected, grepl, logical(1), x = state_text, fixed = TRUE)))
}

phase17_probe_safari_capability <- function(driver = phase17_safari_driver_path,
                                            expected_version = phase17_safari_version,
                                            version_output = NULL,
                                            enabled = TRUE) {
  result <- list(runner = "safari-webdriver", driver = driver,
                 expected_version = expected_version, automated_only = TRUE,
                 enabled = isTRUE(enabled), available = FALSE, version = NA_character_,
                 status = "unavailable", failure_reason = NULL)
  if (!identical(driver, phase17_safari_driver_path)) {
    result$status <- "path_mismatch"; result$failure_reason <- "unsupported Safari driver path"; return(result)
  }
  if (!isTRUE(enabled)) { result$status <- "disabled"; result$failure_reason <- "Safari automation disabled"; return(result) }
  if (!file.exists(driver) || dir.exists(driver)) {
    result$failure_reason <- "Safari driver is unavailable"; return(result)
  }
  output <- version_output
  if (is.null(output)) output <- tryCatch(system2(driver, "--version", stdout = TRUE, stderr = TRUE), error = function(e) character())
  version <- regmatches(paste(output, collapse = " "), regexpr("[0-9]+\\.[0-9]+\\.[0-9]+", paste(output, collapse = " ")))
  if (!length(version) || identical(version, character(0))) version <- NA_character_
  result$version <- version[[1L]]
  result$available <- identical(result$version, expected_version)
  result$status <- if (result$available) "ready" else "version_mismatch"
  if (!result$available) result$failure_reason <- "Safari version does not match the pinned capability"
  result
}

phase17_validate_plist <- function(path) {
  path <- phase17_scalar(path, "plist path")
  if (!file.exists(path)) stop("Phase 17 plist is missing: ", path, call. = FALSE)
  parsed <- tryCatch(jsonlite::fromJSON(system2("plutil", c("-convert", "json", "-o", "-", path), stdout = TRUE), simplifyVector = FALSE), error = function(e) NULL)
  if (is.null(parsed)) return(list(valid = FALSE, path = path, reason = "plutil could not parse plist"))
  list(valid = TRUE, path = path, label = parsed$Label %||% NA_character_, arguments = parsed$ProgramArguments %||% list())
}

phase17_captured_launchctl <- function() {
  calls <- character()
  list(
    call = function(...) { calls <<- c(calls, paste(c(...), collapse = " ")); invisible(TRUE) },
    calls = function() calls
  )
}

phase17_bounded_dry_run <- function(args = character(), max_seconds = 60L) {
  if (length(args) && any(!nzchar(args))) stop("Phase 17 dry-run arguments must be non-empty", call. = FALSE)
  list(valid = TRUE, dry_run = TRUE, bounded = TRUE, max_seconds = as.integer(max_seconds),
       mutation = FALSE, args = as.character(args))
}

phase17_test_fixture_root <- function(root = NULL) {
  if (is.null(root)) root <- tempfile("phase17-fixture-")
  root <- phase17_project_root(root, create = TRUE)
  dir.create(file.path(root, "accepted", "uefa_nations_league_2026_27"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(root, "accepted", "uefa_euro_2028_qualifying"), recursive = TRUE, showWarnings = FALSE)
  root
}

phase17_fixture_bundle <- function(edition_id, lifecycle_state = NULL) {
  edition_id <- phase17_scalar(edition_id, "edition_id")
  if (!edition_id %in% phase17_editions()) stop("Unknown Phase 17 fixture edition", call. = FALSE)
  if (is.null(lifecycle_state)) lifecycle_state <- if (grepl("euro", edition_id)) "pre_draw" else "active"
  empty <- data.frame(stringsAsFactors = FALSE)
  rows <- if (lifecycle_state == "pre_draw") empty else data.frame(
    fixture_id = "fixture-001", group_id = "A", matchday = 1L,
    home_team = "Alpha", away_team = "Beta", status = "scheduled",
    stringsAsFactors = FALSE
  )
  list(
    edition_id = edition_id, lifecycle_state = lifecycle_state,
    candidate_status = if (lifecycle_state == "pre_draw") "pre_draw" else "accepted",
    source_bundle_id = paste0(if (grepl("euro", edition_id)) "euro" else "nl", "-fixture-v1"),
    source_bundle_sha256 = strrep("1", 64), source_confidence = "High - official UEFA bundle",
    source_retrieved_at_utc = "2026-08-25T00:00:00Z", model_release_id = "phase12-calibrated-v1",
    release_manifest_sha256 = strrep("2", 64), ruleset_version = "phase17-fixture-rules-v1",
    ruleset_sha256 = strrep("3", 64), simulation_seed = 1701L, simulation_count = 1L,
    projection_run_id = "phase17-fixture-run-v1", forecast_status = if (lifecycle_state == "pre_draw") "pre_draw" else "available",
    warnings = if (lifecycle_state == "pre_draw") "Awaiting the official draw and schedule." else character(),
    artifacts = list(structure = empty, standings = empty, fixtures = rows, results = empty,
                     forecasts = empty, form = empty, projected_outcomes = empty),
    credits = list(source_name = "UEFA", source_url = "https://www.uefa.com/", license = "Official competition source")
  )
}

phase17_load_fixture_bundle <- function(root, edition_id) {
  root <- phase17_project_root(root)
  fixture <- phase17_fixture_bundle(edition_id)
  fixture$fixture_root <- root
  fixture
}

phase17_bundle_scalar <- function(bundle, field, default = "", allow_empty = TRUE) {
  value <- bundle[[field]]
  if (is.null(value) || !length(value) || is.na(value[[1L]])) return(default)
  as.character(value[[1L]])
}

phase17_bundle_rows <- function(bundle, name) {
  value <- bundle$artifacts[[name]]
  if (is.null(value)) return(list())
  if (is.data.frame(value)) {
    if (!nrow(value)) return(list())
    return(unname(lapply(seq_len(nrow(value)), function(i) as.list(value[i, , drop = FALSE]))))
  }
  if (is.list(value)) return(value)
  stop("Phase 17 artifact rows must be a data frame or list: ", name, call. = FALSE)
}

phase17_normalize_metadata <- function(bundle, batch_id = "phase17-fixture-batch-v1") {
  required <- c("edition_id", "source_bundle_id", "source_bundle_sha256", "model_release_id",
                "ruleset_version", "ruleset_sha256", "simulation_seed", "simulation_count",
                "projection_run_id")
  missing <- required[vapply(required, function(field) is.null(bundle[[field]]) || !length(bundle[[field]]), logical(1))]
  if (length(missing)) stop("Phase 17 accepted bundle is missing lineage: ", paste(missing, collapse = ", "), call. = FALSE)
  lifecycle <- phase17_bundle_scalar(bundle, "lifecycle_state")
  forecast <- phase17_bundle_scalar(bundle, "forecast_status", lifecycle)
  if (!lifecycle %in% phase17_lifecycle_states()) stop("Phase 17 lifecycle state is unsupported", call. = FALSE)
  if (!grepl("^[0-9a-fA-F]{64}$", phase17_bundle_scalar(bundle, "source_bundle_sha256"))) stop("Phase 17 source hash is malformed", call. = FALSE)
  if (!grepl("^[0-9a-fA-F]{64}$", phase17_bundle_scalar(bundle, "ruleset_sha256"))) stop("Phase 17 ruleset hash is malformed", call. = FALSE)
  list(
    batch_id = phase17_scalar(batch_id, "batch_id"),
    edition_id = phase17_scalar(bundle$edition_id, "edition_id"),
    lifecycle_state = lifecycle,
    forecast_status = forecast,
    generated_at_utc = phase17_bundle_scalar(bundle, "generated_at_utc", "2026-08-25T00:00:00Z"),
    last_refresh_at_utc = phase17_bundle_scalar(bundle, "source_retrieved_at_utc", "2026-08-25T00:00:00Z"),
    source_confidence = phase17_bundle_scalar(bundle, "source_confidence", "unknown"),
    source_bundle_id = phase17_bundle_scalar(bundle, "source_bundle_id"),
    source_bundle_sha256 = phase17_bundle_scalar(bundle, "source_bundle_sha256"),
    model_release_id = phase17_bundle_scalar(bundle, "model_release_id"),
    release_manifest_sha256 = phase17_bundle_scalar(bundle, "release_manifest_sha256", ""),
    ruleset_version = phase17_bundle_scalar(bundle, "ruleset_version"),
    ruleset_sha256 = phase17_bundle_scalar(bundle, "ruleset_sha256"),
    simulation_seed = as.integer(bundle$simulation_seed[[1L]]),
    simulation_count = as.integer(bundle$simulation_count[[1L]]),
    projection_run_id = phase17_bundle_scalar(bundle, "projection_run_id"),
    warnings = as.character(bundle$warnings %||% character()),
    showing_last_accepted_snapshot = isTRUE(bundle$showing_last_accepted_snapshot %||% FALSE)
  )
}

phase17_status_for_section <- function(rows, lifecycle, reason = NULL) {
  if (length(rows)) return(list(status = "available", reason = ""))
  if (identical(lifecycle, "pre_draw")) return(list(status = "pre_draw", reason = reason %||% "Awaiting the official draw and schedule."))
  if (lifecycle %in% c("revision_blocked", "unavailable")) {
    return(list(status = "blocked", reason = reason %||% "Refresh blocked - showing the last accepted snapshot."))
  }
  list(status = "unavailable", reason = reason %||% "No accepted data for this section.")
}

phase17_neutral_payload <- function(bundle, section_labels, batch_id = "phase17-fixture-batch-v1") {
  if (!is.list(bundle) || !phase17_bundle_scalar(bundle, "edition_id") %in% phase17_editions()) {
    stop("Phase 17 payload adapter requires one registered accepted edition bundle", call. = FALSE)
  }
  metadata <- phase17_normalize_metadata(bundle, batch_id)
  artifact_names <- c("structure", "standings", "fixtures", "results", "form", "forecasts", "projected_outcomes")
  labels <- c("Structure", "Standings", "Fixtures", "Results", "Form", "Match forecasts", "Projected outcomes")
  sections <- list()
  sections$overview <- list(id = "overview", label = "Overview", status = "available", reason = "",
                            rows = list(), filter_dimensions = c("section"))
  for (i in seq_along(artifact_names)) {
    rows <- phase17_bundle_rows(bundle, artifact_names[[i]])
    warning_reason <- if (length(metadata$warnings)) metadata$warnings[[1L]] else NULL
    state <- phase17_status_for_section(rows, metadata$lifecycle_state, warning_reason)
    section_id <- phase17_section_ids()[[i + 1L]]
    sections[[section_id]] <- list(
      id = section_id, label = labels[[i]], status = state$status, reason = state$reason,
      rows = rows, filter_dimensions = c("section", "league_or_group", "team", "matchday", "fixture_status")
    )
  }
  credits <- bundle$credits %||% list(source_name = "UEFA", source_url = "https://www.uefa.com/",
                                      license = "Official competition source")
  payload <- list(schema_version = phase17_dashboard_schema_version,
                  edition_id = metadata$edition_id, metadata = metadata,
                  sections = sections, credits = credits)
  phase17_validate_payload(payload)
  payload
}

phase17_row_value <- function(row, fields, default = "") {
  if (!is.list(row)) return(default)
  for (field in fields) {
    value <- row[[field]]
    if (!is.null(value) && length(value) && !is.na(value[[1L]])) return(as.character(value[[1L]]))
  }
  default
}

phase17_filter_payload <- function(payload, filters = list()) {
  phase17_validate_payload(payload)
  filters <- modifyList(list(section = "", league_or_group = "", team = "",
                             matchday = "", fixture_status = ""), filters)
  result <- unserialize(serialize(payload, NULL))
  selected_section <- as.character(filters$section %||% "")[[1L]]
  selected_group <- as.character(filters$league_or_group %||% "")[[1L]]
  selected_team <- as.character(filters$team %||% "")[[1L]]
  selected_matchday <- as.character(filters$matchday %||% "")[[1L]]
  selected_status <- tolower(as.character(filters$fixture_status %||% "")[[1L]])
  if (nzchar(selected_section) && selected_section %in% names(result$sections)) {
    result$sections <- result$sections[selected_section]
  }
  row_matches <- function(row) {
    group <- phase17_row_value(row, c("league_or_group", "group_id", "league", "group"))
    team_values <- vapply(row[c("team", "home_team", "away_team")], function(value) {
      if (is.null(value) || !length(value)) "" else as.character(value[[1L]])
    }, character(1), USE.NAMES = FALSE)
    matchday <- phase17_row_value(row, c("matchday", "match_day"))
    status <- tolower(phase17_row_value(row, c("fixture_status", "status")))
    (is.null(selected_group) || !nzchar(selected_group) || identical(group, selected_group)) &&
      (is.null(selected_team) || !nzchar(selected_team) || selected_team %in% team_values) &&
      (is.null(selected_matchday) || !nzchar(selected_matchday) || identical(matchday, selected_matchday)) &&
      (is.null(selected_status) || !nzchar(selected_status) || identical(status, selected_status))
  }
  for (name in names(result$sections)) {
    rows <- result$sections[[name]]$rows
    if (length(rows)) result$sections[[name]]$rows <- rows[vapply(rows, row_matches, logical(1))]
  }
  result$filter_result_count <- sum(vapply(result$sections, function(section) length(section$rows), integer(1)))
  result
}
