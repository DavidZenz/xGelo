#!/usr/bin/env Rscript

# Bounded Phase 13 source capture.  This entrypoint accepts either committed
# compact fixtures or one operator-supplied URL per structured resource class.
# It never parses rendered page text and never publishes a candidate before the
# complete edition-wide bundle has passed the source contract.

phase13_acquire_command_args <- commandArgs(trailingOnly = FALSE)
phase13_acquire_script_args <- phase13_acquire_command_args[grepl("^--file=", phase13_acquire_command_args)]
phase13_acquire_source_file <- tryCatch(sys.frame(1L)$ofile, error = function(error) NULL)
phase13_acquire_script_candidates <- c(
  if (length(phase13_acquire_script_args)) sub("^--file=", "", phase13_acquire_script_args[[1L]]) else character(),
  if (!is.null(phase13_acquire_source_file)) as.character(phase13_acquire_source_file) else character(),
  file.path(getwd(), "scripts/acquire_uefa_snapshot.R")
)
phase13_acquire_script_candidates <- phase13_acquire_script_candidates[
  !is.na(phase13_acquire_script_candidates) & nzchar(phase13_acquire_script_candidates)
]
phase13_acquire_script_file <- phase13_acquire_script_candidates[
  vapply(phase13_acquire_script_candidates, file.exists, logical(1))
][1L]
if (is.na(phase13_acquire_script_file) || !nzchar(phase13_acquire_script_file)) {
  stop("Phase 13 capture entrypoint could not resolve its script path", call. = FALSE)
}
phase13_acquire_script_file <- normalizePath(
  phase13_acquire_script_file,
  winslash = "/",
  mustWork = TRUE
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
    "  --results-url URL [--status-url URL] [the same output options as above]",
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
  mandatory_types <- c("fixtures", "groups", "standings", "results")
  missing <- setdiff(mandatory_types, names(resources))
  if (length(missing)) {
    stop("Phase 13 fixture is missing mandatory resource classes: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  resource_types <- mandatory_types
  if ("status" %in% names(resources) && "status" %in% names(fixture$source_urls) &&
      nzchar(phase13_acquire_value(fixture$source_urls$status, "status URL"))) {
    resource_types <- c(resource_types, "status")
  }
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

phase13_acquire_clock_seconds <- function(clock_fn) {
  value <- clock_fn()
  if (inherits(value, "POSIXt")) value <- as.numeric(value)
  value <- suppressWarnings(as.numeric(value[[1L]]))
  if (length(value) != 1L || is.na(value) || !is.finite(value)) {
    stop("Phase 13 capture clock callback must return one finite number", call. = FALSE)
  }
  value
}

phase13_acquire_response_status <- function(response) {
  if (inherits(response, "httr2_response")) return(as.integer(httr2::resp_status(response)))
  if (is.list(response)) {
    value <- response$status_code %||% response$status
    if (length(value)) return(as.integer(value[[1L]]))
  }
  stop("Phase 13 structured response did not expose an HTTP status", call. = FALSE)
}

phase13_acquire_response_header <- function(response, header, default = "") {
  if (inherits(response, "httr2_response")) {
    return(as.character(httr2::resp_header(response, header, default = default) %||% default))
  }
  headers <- if (is.list(response)) response$headers else NULL
  if (is.null(headers) || !length(headers)) return(default)
  names_lower <- tolower(names(headers))
  match_index <- match(tolower(header), names_lower)
  if (is.na(match_index)) default else as.character(headers[[match_index]])
}

phase13_acquire_response_raw <- function(response, artifact_type) {
  raw_bytes <- if (inherits(response, "httr2_response")) {
    tryCatch(
      httr2::resp_body_raw(response),
      error = function(error) stop("Phase 13 structured response has no body for ", artifact_type, call. = FALSE)
    )
  } else if (is.list(response)) {
    response$raw_bytes %||% response$body
  } else {
    NULL
  }
  if (is.null(raw_bytes)) stop("Phase 13 structured response has no body for ", artifact_type, call. = FALSE)
  phase13_source_raw_bytes(raw_bytes)
}

phase13_acquire_retryable_statuses <- function() {
  c(408L, 425L, 429L, 500L, 502L, 503L, 504L)
}

phase13_acquire_rate_limit_wait <- function(
    rate_limit_state,
    clock_fn,
    sleep_fn,
    min_interval_seconds) {
  now <- phase13_acquire_clock_seconds(clock_fn)
  previous <- if (exists("next_allowed_at", envir = rate_limit_state, inherits = FALSE)) {
    get("next_allowed_at", envir = rate_limit_state, inherits = FALSE)
  } else {
    NULL
  }
  wait <- if (is.null(previous)) 0 else max(0, as.numeric(previous) - now)
  if (wait > 0) sleep_fn(wait)
  assign(
    "next_allowed_at",
    max(now, if (is.null(previous)) now else as.numeric(previous)) + min_interval_seconds,
    envir = rate_limit_state
  )
  invisible(wait)
}

phase13_acquire_fetch_structured_url <- function(
    url,
    artifact_type,
    max_bytes = 5e6,
    max_attempts = 3L,
    timeout_seconds = 30,
    min_interval_seconds = 1,
    backoff_base_seconds = 1,
    request_fn = NULL,
    perform_fn = NULL,
    clock_fn = function() as.numeric(Sys.time()),
    sleep_fn = Sys.sleep,
    rate_limit_state = NULL) {
  url <- phase13_source_scalar(url, paste0(artifact_type, " URL"))
  artifact_type <- phase13_source_scalar(artifact_type, "artifact_type")
  if (!grepl("^https://", tolower(url))) {
    stop("Phase 13 live capture requires an HTTPS URL for ", artifact_type, call. = FALSE)
  }
  if (!requireNamespace("httr2", quietly = TRUE)) {
    stop("httr2 is required for Phase 13 live structured capture", call. = FALSE)
  }
  max_bytes <- suppressWarnings(as.numeric(max_bytes))
  max_attempts <- suppressWarnings(as.integer(max_attempts))
  timeout_seconds <- suppressWarnings(as.numeric(timeout_seconds))
  min_interval_seconds <- suppressWarnings(as.numeric(min_interval_seconds))
  backoff_base_seconds <- suppressWarnings(as.numeric(backoff_base_seconds))
  if (is.na(max_bytes) || max_bytes <= 0 || is.na(max_attempts) || max_attempts < 1L ||
      is.na(timeout_seconds) || timeout_seconds <= 0 || is.na(min_interval_seconds) || min_interval_seconds < 0 ||
      is.na(backoff_base_seconds) || backoff_base_seconds <= 0) {
    stop("Phase 13 structured capture bounds must be positive", call. = FALSE)
  }
  max_attempts <- min(max_attempts, 3L)
  if (is.null(rate_limit_state)) rate_limit_state <- new.env(parent = emptyenv())
  if (is.null(request_fn)) request_fn <- function(value) httr2::request(value)
  if (is.null(perform_fn)) perform_fn <- function(request) httr2::req_perform(request)

  last_message <- ""
  for (attempt in seq_len(max_attempts)) {
    phase13_acquire_rate_limit_wait(
      rate_limit_state, clock_fn, sleep_fn, min_interval_seconds
    )
    request <- tryCatch(
      request_fn(url),
      error = function(error) stop(
        "Phase 13 structured URL request construction failed for ", artifact_type,
        ": ", conditionMessage(error), call. = FALSE
      )
    )
    if (inherits(request, "httr2_request")) {
      request <- httr2::req_headers(request, Accept = "application/json")
      request <- httr2::req_timeout(request, seconds = timeout_seconds)
    } else if (is.list(request)) {
      request$headers <- c(request$headers %||% list(), list(Accept = "application/json"))
      request$timeout_seconds <- timeout_seconds
    }

    response_error <- NULL
    response <- tryCatch(
      perform_fn(request),
      error = function(error) {
        response_error <<- error
        NULL
      }
    )
    status <- if (is.null(response)) NA_integer_ else {
      tryCatch(phase13_acquire_response_status(response), error = function(error) NA_integer_)
    }
    transient <- is.na(status) || status %in% phase13_acquire_retryable_statuses()
    if (!is.null(response) && status >= 200L && status < 300L) {
      content_type <- tolower(trimws(phase13_acquire_response_header(response, "content-type", "")))
      if (!grepl("^application/(json|[a-z0-9.+-]+\\+json)(;|$)", content_type)) {
        stop("Phase 13 structured response for ", artifact_type, " is not JSON (content-type: ", content_type, ")", call. = FALSE)
      }
      raw_bytes <- phase13_acquire_response_raw(response, artifact_type)
      if (!length(raw_bytes) || length(raw_bytes) > max_bytes) {
        stop("Phase 13 structured URL response exceeds the bounded byte limit: ", artifact_type, call. = FALSE)
      }
      phase13_source_validate_structured_bytes(raw_bytes, artifact_type)
      payload <- tryCatch(
        jsonlite::fromJSON(rawToChar(raw_bytes), simplifyVector = FALSE),
        error = function(error) stop(
          "Phase 13 structured response JSON parsing failed for ", artifact_type,
          ": ", conditionMessage(error), call. = FALSE
        )
      )
      tryCatch(
        phase13_source_validate_resource_payload(payload, artifact_type),
        error = function(error) stop(
          "Phase 13 structured response schema validation failed for ", artifact_type,
          ": ", conditionMessage(error), call. = FALSE
        )
      )
      return(list(payload = payload, raw_bytes = raw_bytes, source_url = url))
    }

    last_message <- if (!is.null(response_error)) {
      conditionMessage(response_error)
    } else if (is.na(status)) {
      "response did not expose an HTTP status"
    } else {
      paste0("HTTP status ", status)
    }
    if (!transient || attempt >= max_attempts) break
    sleep_fn(min(8, backoff_base_seconds * (2 ^ (attempt - 1L))))
  }
  stop(
    "Phase 13 structured URL capture failed for ", artifact_type,
    " after ", max_attempts, " attempt(s): ", last_message,
    call. = FALSE
  )
}

phase13_acquire_option_url <- function(options, artifact_type) {
  candidates <- c(
    options[[paste0(artifact_type, "-url")]],
    options[[paste0("url-", artifact_type)]],
    options[[paste0("source-url-", artifact_type)]]
  )
  candidates <- candidates[!vapply(candidates, is.null, logical(1))]
  candidates <- candidates[vapply(candidates, function(value) length(value) && !is.na(value[[1L]]) && nzchar(as.character(value[[1L]])), logical(1))]
  if (!length(candidates)) return(NULL)
  as.character(candidates[[1L]])
}

phase13_acquire_status_evidence <- function(resource_payloads) {
  status_fields <- c(
    "competition_status", "competition_state", "edition_status", "edition_state",
    "lifecycle_state", "source_snapshot_state"
  )
  edition_fields <- c(
    "source_edition_id", "source_edition", "source_competition_id",
    "competition_edition_id", "edition_id"
  )
  evidence <- list()
  visit <- function(value, resource_type) {
    if (is.data.frame(value)) {
      for (index in seq_len(nrow(value))) visit(as.list(value[index, , drop = FALSE]), resource_type)
      return(invisible(NULL))
    }
    if (!is.list(value)) return(invisible(NULL))
    fields <- names(value)
    if (length(fields)) {
      for (field in intersect(fields, c(status_fields, edition_fields))) {
        candidate <- value[[field]]
        if (is.atomic(candidate) && length(candidate)) {
          candidate <- as.character(candidate)
          candidate <- candidate[!is.na(candidate) & nzchar(trimws(candidate))]
          if (length(candidate)) evidence[[length(evidence) + 1L]] <<- list(
            resource_type = resource_type,
            field = field,
            values = candidate
          )
        }
      }
      for (field in setdiff(fields, c(status_fields, edition_fields))) visit(value[[field]], resource_type)
    } else {
      for (child in value) visit(child, resource_type)
    }
    invisible(NULL)
  }
  for (resource_type in intersect(names(resource_payloads), c("fixtures", "groups", "standings", "results"))) {
    visit(resource_payloads[[resource_type]], resource_type)
  }
  evidence
}

phase13_acquire_derive_status <- function(input, edition_id) {
  evidence <- phase13_acquire_status_evidence(input$resources)
  status_evidence <- evidence[vapply(evidence, function(item) item$field %in% c(
    "competition_status", "competition_state", "edition_status", "edition_state",
    "lifecycle_state", "source_snapshot_state"
  ), logical(1))]
  statuses <- sort(unique(unlist(lapply(status_evidence, function(item) item$values), use.names = FALSE)))
  if (!length(statuses)) {
    stop(
      "Phase 13 status source unavailable: optional status URL was not supplied and no status-bearing fields were found",
      call. = FALSE
    )
  }
  if (length(statuses) != 1L) {
    stop("Phase 13 derived status has conflicting status-bearing fields", call. = FALSE)
  }
  edition_evidence <- evidence[vapply(evidence, function(item) item$field %in% c(
    "source_edition_id", "source_edition", "source_competition_id", "competition_edition_id", "edition_id"
  ), logical(1))]
  source_edition <- sort(unique(unlist(lapply(edition_evidence, function(item) item$values), use.names = FALSE)))
  if (length(source_edition) > 1L) {
    stop("Phase 13 derived status has conflicting source edition identifiers", call. = FALSE)
  }
  source_edition <- if (length(source_edition)) source_edition[[1L]] else edition_id
  contributors <- sort(unique(vapply(status_evidence, function(item) item$resource_type, character(1))))
  if (!length(contributors)) stop("Phase 13 derived status has no contributing resources", call. = FALSE)
  status_payload <- list(list(
    source_edition_id = source_edition,
    competition_status = statuses[[1L]]
  ))
  source_urls <- as.character(input$source_urls[contributors])
  source_urls <- source_urls[!is.na(source_urls) & nzchar(source_urls)]
  if (!length(source_urls)) stop("Phase 13 derived status has no contributing source URLs", call. = FALSE)
  status_url <- paste(sort(unique(source_urls)), collapse = " | ")
  raw_bytes <- jsonlite::toJSON(status_payload, auto_unbox = TRUE, pretty = FALSE, null = "null", digits = 17)
  input$resources$status <- status_payload
  input$source_urls[["status"]] <- status_url
  input$raw_bytes_by_resource$status <- raw_bytes
  input$status_provenance <- "derived"
  input$status_contributors <- contributors
  input
}

phase13_acquire_finalize_input <- function(input, edition_id) {
  mandatory <- c("fixtures", "groups", "standings", "results")
  missing <- setdiff(mandatory, names(input$resources))
  if (length(missing)) stop("Phase 13 capture is missing mandatory resource classes: ", paste(missing, collapse = ", "), call. = FALSE)
  invisible(lapply(mandatory, function(type) phase13_source_validate_resource_payload(input$resources[[type]], type)))
  has_explicit_status <- "status" %in% names(input$resources) && "status" %in% names(input$source_urls) &&
    !is.null(input$source_urls[["status"]]) && nzchar(as.character(input$source_urls[["status"]]))
  if (has_explicit_status) {
    phase13_source_validate_resource_payload(input$resources$status, "status")
    input$status_provenance <- "explicit"
    input$status_contributors <- "status"
    return(input)
  }
  phase13_acquire_derive_status(input, edition_id)
}

phase13_acquire_live_input <- function(
    options,
    edition_id,
    fetch_fn = phase13_acquire_fetch_structured_url,
    clock_fn = function() as.numeric(Sys.time()),
    sleep_fn = Sys.sleep,
    rate_limit_state = NULL) {
  mandatory <- c("fixtures", "groups", "standings", "results")
  url_values <- setNames(vapply(mandatory, function(type) {
    value <- phase13_acquire_option_url(options, type)
    if (is.null(value)) return(NA_character_)
    value
  }, character(1)), mandatory)
  if (any(is.na(url_values) | !nzchar(url_values))) {
    stop("Live Phase 13 capture requires explicit HTTPS URLs for fixtures, groups, standings, and results", call. = FALSE)
  }
  if (is.null(rate_limit_state)) rate_limit_state <- new.env(parent = emptyenv())
  payloads <- list()
  raw_bytes <- list()
  for (artifact_type in mandatory) {
    captured <- fetch_fn(
      url_values[[artifact_type]], artifact_type,
      rate_limit_state = rate_limit_state, clock_fn = clock_fn, sleep_fn = sleep_fn
    )
    payloads[[artifact_type]] <- captured$payload
    raw_bytes[[artifact_type]] <- captured$raw_bytes
  }
  input <- list(
    edition_id = edition_id,
    resources = payloads,
    source_urls = url_values,
    raw_bytes_by_resource = raw_bytes,
    retrieved_at_utc = phase13_acquire_now_utc()
  )
  status_url <- phase13_acquire_option_url(options, "status")
  if (!is.null(status_url)) {
    captured <- fetch_fn(
      status_url, "status",
      rate_limit_state = rate_limit_state, clock_fn = clock_fn, sleep_fn = sleep_fn
    )
    input$resources$status <- captured$payload
    input$source_urls[["status"]] <- captured$source_url %||% status_url
    input$raw_bytes_by_resource$status <- captured$raw_bytes
    input$status_provenance <- "explicit"
    input$status_contributors <- "status"
  }
  phase13_acquire_finalize_input(input, edition_id)
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
  input <- phase13_acquire_finalize_input(input, edition_id)
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
