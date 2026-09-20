#' Fixed, secret-safe football-data.org adapter for the UCL 2026/27 window.

phase18_fd_abort <- function(reason_code, message, data = list()) {
  condition <- structure(
    c(list(message = as.character(message), call = NULL, reason_code = reason_code), data),
    class = c(reason_code, "phase18_fd_error", "error", "condition")
  )
  stop(condition)
}

phase18_fd_closed_reasons <- function() c(
  "blocked_transport", "blocked_http_status", "blocked_content_type",
  "blocked_redirect_host", "blocked_empty_resource", "blocked_byte_limit",
  "blocked_invalid_json", "blocked_null_resource", "blocked_schema",
  "blocked_retry_policy", "blocked_request_scope", "blocked_retry_exhausted",
  "blocked_missing_credential", "blocked_resource_window", "blocked_edition_identity",
  "blocked_incomplete_pagination", "blocked_duplicate_id", "blocked_unknown_status",
  "blocked_unknown_stage", "blocked_cardinality", "blocked_standings",
  "blocked_coverage", "blocked_missing_team", "blocked_unresolved_club",
  "blocked_stale_resource", "blocked_future_resource", "blocked_malformed_freshness",
  "blocked_freshness_unavailable", "blocked_secret_exposure",
  "blocked_unclassified_acquisition"
)

phase18_fd_classify_acquisition_error <- function(error) {
  if (inherits(error, "phase18_fd_error") &&
      length(error$reason_code) == 1L && error$reason_code %in% phase18_fd_closed_reasons()) {
    return(error)
  }
  if (inherits(error, c("httr2_error", "curl_error", "timeout_error", "connection_error"))) {
    return(structure(
      list(message = "Provider transport failed", call = NULL, reason_code = "blocked_transport"),
      class = c("blocked_transport", "phase18_fd_error", "error", "condition")
    ))
  }
  structure(
    list(message = "Acquisition failed without a classified reason", call = NULL,
      reason_code = "blocked_unclassified_acquisition"),
    class = c("blocked_unclassified_acquisition", "phase18_fd_error", "error", "condition")
  )
}

phase18_fd_with_closed_errors <- function(expression) {
  tryCatch(expression, error = function(error) stop(phase18_fd_classify_acquisition_error(error)))
}

phase18_fd_scalar <- function(value, field, allow_missing = FALSE) {
  if (is.null(value) || !length(value) || is.na(value[[1L]])) {
    if (allow_missing) return(NA_character_)
    phase18_fd_abort("blocked_schema", paste0("Missing provider field: ", field))
  }
  value <- as.character(value[[1L]])
  if (!allow_missing && !nzchar(value)) {
    phase18_fd_abort("blocked_schema", paste0("Empty provider field: ", field))
  }
  value
}

phase18_fd_or <- function(value, fallback) if (is.null(value) || !length(value)) fallback else value

#' Return the only request window accepted by the Phase 18 provider contract.
phase18_fd_request_plan <- function(season = 2026L) {
  season <- suppressWarnings(as.integer(season))
  if (length(season) != 1L || is.na(season) || season != 2026L) {
    phase18_fd_abort("blocked_edition_identity", "The fixed provider season is 2026")
  }
  data.frame(
    resource = c("competition_metadata", "teams", "matches", "standings"),
    url = c(
      "https://api.football-data.org/v4/competitions/CL",
      "https://api.football-data.org/v4/competitions/CL/teams?season=2026",
      "https://api.football-data.org/v4/competitions/CL/matches?season=2026",
      "https://api.football-data.org/v4/competitions/CL/standings?season=2026"
    ),
    logical_call = seq_len(4L),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

phase18_fd_validate_request_plan <- function(request_plan) {
  expected <- phase18_fd_request_plan()
  if (!is.data.frame(request_plan) || !identical(names(request_plan), names(expected)) ||
      nrow(request_plan) != 4L || !identical(as.character(request_plan$resource), expected$resource) ||
      !identical(as.character(request_plan$url), expected$url) ||
      !identical(as.integer(request_plan$logical_call), expected$logical_call)) {
    phase18_fd_abort("blocked_request_scope", "Request plan must be the fixed four-resource UCL window")
  }
  invisible(TRUE)
}

phase18_fd_parse_time <- function(value, field) {
  value <- phase18_fd_scalar(value, field)
  parsed <- as.POSIXct(value, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  if (is.na(parsed)) phase18_fd_abort("blocked_schema", paste0("Invalid UTC timestamp: ", field))
  parsed
}

phase18_fd_response_header <- function(headers, name) {
  if (is.null(headers) || !length(headers)) return(NA_character_)
  names_lower <- tolower(names(headers))
  index <- match(tolower(name), names_lower)
  if (is.na(index)) NA_character_ else as.character(headers[[index]][[1L]])
}

phase18_fd_validate_response <- function(response, request, retrieved_at_utc, max_bytes) {
  if (!is.list(response)) phase18_fd_abort("blocked_transport", "Provider performer must return a response list")
  status <- suppressWarnings(as.integer(phase18_fd_or(response$status, NA_integer_)))
  if (length(status) != 1L || is.na(status) || status != 200L) {
    phase18_fd_abort("blocked_http_status", paste0("Provider returned HTTP ", phase18_fd_or(status, "unknown")))
  }
  content_type <- tolower(phase18_fd_scalar(response$content_type, "content_type"))
  if (!grepl("^application/(json|[^;]+\\+json)(;|$)", content_type)) {
    phase18_fd_abort("blocked_content_type", "Provider response is not JSON")
  }
  final_url <- phase18_fd_scalar(response$final_url, "final_url")
  if (!identical(final_url, as.character(request$url[[1L]])) ||
      !startsWith(final_url, "https://api.football-data.org/v4/competitions/CL")) {
    phase18_fd_abort("blocked_redirect_host", "Provider response left the fixed HTTPS endpoint")
  }
  body <- response$body
  if (!is.raw(body)) phase18_fd_abort("blocked_transport", "Provider body must be exact raw bytes")
  if (!length(body)) phase18_fd_abort("blocked_empty_resource", "Provider body is empty")
  if (length(body) > max_bytes) phase18_fd_abort("blocked_byte_limit", "Provider body exceeds the fixed byte limit")
  parsed <- tryCatch(
    jsonlite::fromJSON(rawToChar(body), simplifyVector = FALSE),
    error = function(error) phase18_fd_abort("blocked_invalid_json", conditionMessage(error))
  )
  if (is.null(parsed)) phase18_fd_abort("blocked_null_resource", "Provider returned JSON null")
  if (!is.list(parsed)) phase18_fd_abort("blocked_schema", "Provider top-level JSON must be an object")
  headers <- phase18_fd_or(response$headers, list())
  list(
    resource = as.character(request$resource[[1L]]),
    status = status,
    content_type = content_type,
    final_url = final_url,
    retrieved_at_utc = retrieved_at_utc,
    bytes = as.integer(length(body)),
    raw_sha256 = digest::digest(body, algo = "sha256", serialize = FALSE),
    rate_limit_remaining = phase18_fd_response_header(headers, "x-requests-available-minute"),
    body = body,
    parsed = parsed
  )
}

#' Fetch the fixed provider window using an injected single-request performer.
phase18_fd_fetch_window <- function(
    request_plan,
    perform_request,
    clock_fn = Sys.time,
    sleep_fn = Sys.sleep,
    max_attempts = 3L,
    max_bytes = 10L * 1024L * 1024L) {
  phase18_fd_validate_request_plan(request_plan)
  if (!is.function(perform_request) || !is.function(clock_fn) || !is.function(sleep_fn)) {
    phase18_fd_abort("blocked_transport", "Performer, clock, and sleep seams must be functions")
  }
  max_attempts <- suppressWarnings(as.integer(max_attempts))
  if (length(max_attempts) != 1L || is.na(max_attempts) || max_attempts < 1L || max_attempts > 3L) {
    phase18_fd_abort("blocked_retry_policy", "Provider calls allow one to three attempts")
  }
  output <- vector("list", nrow(request_plan))
  names(output) <- request_plan$resource
  last_started <- NULL
  min_interval <- 60 / 9
  retryable_status <- c(429L, 500L, 502L, 503L, 504L)
  for (index in seq_len(nrow(request_plan))) {
    request <- request_plan[index, , drop = FALSE]
    now <- as.POSIXct(clock_fn(), tz = "UTC")
    if (!is.null(last_started)) {
      wait <- min_interval - as.numeric(difftime(now, last_started, units = "secs"))
      if (is.finite(wait) && wait > 0) sleep_fn(wait)
    }
    last_started <- as.POSIXct(clock_fn(), tz = "UTC")
    accepted <- NULL
    last_error <- NULL
    for (attempt in seq_len(max_attempts)) {
      response <- tryCatch(
        phase18_fd_with_closed_errors(perform_request(request, attempt)),
        error = function(error) {
          if (!isTRUE(attr(error, "retryable")) || attempt == max_attempts) stop(error)
          last_error <<- error
          NULL
        }
      )
      if (is.null(response)) next
      status <- suppressWarnings(as.integer(phase18_fd_or(response$status, NA_integer_)))
      retryable <- isTRUE(response$retryable) || (!is.na(status) && status %in% retryable_status)
      if (retryable && attempt < max_attempts) {
        retry_after <- suppressWarnings(as.numeric(phase18_fd_response_header(response$headers, "retry-after")))
        sleep_fn(if (is.finite(retry_after) && retry_after >= 0) retry_after else min(2^(attempt - 1L), 4))
        next
      }
      retrieved <- format(as.POSIXct(clock_fn(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
      accepted <- phase18_fd_validate_response(response, request, retrieved, max_bytes)
      accepted$attempt_count <- attempt
      break
    }
    if (is.null(accepted)) {
      phase18_fd_abort("blocked_retry_exhausted", if (is.null(last_error)) "Provider retry budget exhausted" else conditionMessage(last_error))
    }
    output[[index]] <- accepted
  }
  output
}

#' Create the real performer. The token is read only when a request executes.
phase18_fd_live_performer <- function() {
  function(request, attempt) {
    token <- Sys.getenv("FOOTBALL_DATA_API_TOKEN", unset = "")
    if (!nzchar(token)) phase18_fd_abort("blocked_missing_credential", "FOOTBALL_DATA_API_TOKEN is not set")
    url <- phase18_fd_scalar(request$url, "request_url")
    if (!identical(url, phase18_fd_request_plan()$url[match(request$resource[[1L]], phase18_fd_request_plan()$resource)])) {
      phase18_fd_abort("blocked_request_scope", "Live performer received a non-fixed URL")
    }
    req <- httr2::request(url)
    req <- httr2::req_headers_redacted(req, `X-Auth-Token` = token)
    req <- httr2::req_throttle(req, rate = 9, capacity = 9, fill_time_s = 60, realm = "football-data.org-v4-ucl")
    req <- httr2::req_error(req, is_error = function(response) FALSE)
    response <- httr2::req_perform(req)
    list(
      status = httr2::resp_status(response),
      content_type = phase18_fd_or(httr2::resp_header(response, "content-type"), ""),
      final_url = httr2::resp_url(response),
      body = httr2::resp_body_raw(response),
      headers = list(
        `retry-after` = phase18_fd_or(httr2::resp_header(response, "retry-after"), NA_character_),
        `x-requests-available-minute` = phase18_fd_or(httr2::resp_header(response, "x-requests-available-minute"), NA_character_)
      ),
      retryable = httr2::resp_status(response) %in% c(429L, 500L, 502L, 503L, 504L)
    )
  }
}

phase18_fd_pagination_complete <- function(payload, observed_count = NULL) {
  pagination <- payload$pagination
  if (!is.null(pagination)) {
    current <- suppressWarnings(as.integer(phase18_fd_or(pagination$currentPage, 1L)))
    total <- suppressWarnings(as.integer(phase18_fd_or(pagination$totalPages, 1L)))
    if (is.na(current) || is.na(total) || current < total) return(FALSE)
  }
  if (!is.null(observed_count)) {
    declared <- NULL
    if (!is.null(payload$count)) declared <- payload$count
    if (!is.null(payload$resultSet$count)) declared <- payload$resultSet$count
    if (!is.null(declared) && as.integer(declared[[1L]]) != as.integer(observed_count)) return(FALSE)
  }
  TRUE
}

phase18_fd_list_rows <- function(value, resource) {
  if (is.null(value)) phase18_fd_abort("blocked_null_resource", paste0(resource, " is null"))
  if (!is.list(value) || !length(value)) phase18_fd_abort("blocked_empty_resource", paste0(resource, " is empty"))
  value
}

phase18_fd_nested <- function(object, path, allow_missing = FALSE) {
  value <- object
  for (field in path) {
    if (is.null(value) || !is.list(value) || is.null(value[[field]])) {
      if (allow_missing) return(NULL)
      phase18_fd_abort("blocked_schema", paste0("Missing provider path: ", paste(path, collapse = ".")))
    }
    value <- value[[field]]
  }
  value
}

phase18_fd_nullable_integer <- function(value) {
  if (is.null(value) || !length(value) || is.na(value[[1L]])) return(NA_integer_)
  suppressWarnings(as.integer(value[[1L]]))
}

phase18_fd_fingerprint <- function(payload) {
  walk <- function(value, prefix = "") {
    if (!is.list(value) || is.data.frame(value)) return(prefix)
    fields <- sort(names(value))
    unique(c(prefix, unlist(lapply(fields, function(field) {
      child <- if (nzchar(prefix)) paste(prefix, field, sep = ".") else field
      item <- value[[field]]
      if (is.list(item) && length(item)) walk(item[[1L]], child) else child
    }), use.names = FALSE)))
  }
  digest::digest(paste(sort(unique(walk(payload))), collapse = "|"), algo = "sha256", serialize = FALSE)
}

phase18_fd_freshness_schema <- function() c(
  "schema_version", "hash_encoding_version", "resource", "evidence_kind",
  "evidence_path", "source_timestamp_utc", "retrieved_at_utc", "checked_at_utc",
  "age_hours", "policy_threshold_hours", "verdict", "reason", "row_sha256"
)

phase18_fd_freshness_evidence <- function(resource, values, evidence_kind, evidence_path,
                                           retrieved_at_utc, now_utc, max_age_hours = 48,
                                           future_tolerance_hours = 1) {
  if (is.null(values) || !length(values) || any(vapply(values, function(value) {
    is.null(value) || !length(value) || is.na(value[[1L]]) || !nzchar(as.character(value[[1L]]))
  }, logical(1)))) {
    phase18_fd_abort("blocked_freshness_unavailable", paste0(resource, " has no independent source freshness"))
  }
  source_text <- vapply(values, function(value) as.character(value[[1L]]), character(1))
  source_times <- suppressWarnings(as.POSIXct(source_text, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  if (any(is.na(source_times))) {
    phase18_fd_abort("blocked_malformed_freshness", paste0(resource, " has malformed source freshness"))
  }
  now <- suppressWarnings(as.POSIXct(as.character(now_utc), format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  retrieved <- suppressWarnings(as.POSIXct(as.character(retrieved_at_utc), format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  if (length(now) != 1L || is.na(now) || length(retrieved) != 1L || is.na(retrieved)) {
    phase18_fd_abort("blocked_malformed_freshness", "Freshness check or retrieval time is malformed")
  }
  ages <- as.numeric(difftime(now, source_times, units = "hours"))
  if (any(!is.finite(ages))) {
    phase18_fd_abort("blocked_malformed_freshness", paste0(resource, " freshness age is not finite"))
  }
  if (any(ages < -future_tolerance_hours)) {
    phase18_fd_abort("blocked_future_resource", paste0(resource, " source freshness is implausibly future-dated"))
  }
  if (any(ages > max_age_hours)) {
    phase18_fd_abort("blocked_stale_resource", paste0(resource, " is outside the accepted freshness window"))
  }
  oldest <- which.max(ages)[[1L]]
  row <- data.frame(
    schema_version = "phase18-fd-freshness-v2",
    hash_encoding_version = phase18_canonical_encoding_v2(),
    resource = as.character(resource), evidence_kind = as.character(evidence_kind),
    evidence_path = as.character(evidence_path), source_timestamp_utc = source_text[[oldest]],
    retrieved_at_utc = as.character(retrieved_at_utc), checked_at_utc = as.character(now_utc),
    age_hours = as.double(ages[[oldest]]), policy_threshold_hours = as.double(max_age_hours),
    verdict = "pass", reason = "fresh", row_sha256 = "",
    stringsAsFactors = FALSE, check.names = FALSE
  )
  row$row_sha256 <- phase18_hash_row_v2(
    row, exclude = "row_sha256", schema_tag = "phase18-fd-freshness-v2"
  )
  row
}

phase18_fd_row_hash <- function(data) {
  phase18_hash_row_v2(
    data, exclude = "row_sha256",
    schema_tag = paste0("fd-projection:", paste(setdiff(names(data), "row_sha256"), collapse = ","))
  )
}

#' Project the four provider resources into edition-scoped canonical tables.
phase18_fd_project_resources_impl <- function(
    fetched,
    edition_id,
    club_registries,
    edition_expectations = phase18_default_edition_expectations(edition_id),
    now_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")) {
  expected_names <- phase18_fd_request_plan()$resource
  if (!is.list(fetched) || !identical(names(fetched), expected_names)) {
    phase18_fd_abort("blocked_resource_window", "Projection requires the complete fixed four-resource window")
  }
  edition_id <- phase18_fd_scalar(edition_id, "edition_id")
  if (!identical(edition_id, "ucl_2026_27")) phase18_fd_abort("blocked_edition_identity", "Only ucl_2026_27 is accepted")
  phase18_validate_club_registries(club_registries)
  payload <- lapply(fetched, `[[`, "parsed")
  competition <- payload$competition_metadata
  if (!identical(phase18_fd_scalar(competition$code, "competition.code"), "CL")) {
    phase18_fd_abort("blocked_edition_identity", "Provider competition code is not CL")
  }
  season <- phase18_fd_nested(competition, c("currentSeason"))
  start_date <- phase18_fd_scalar(season$startDate, "currentSeason.startDate")
  if (!startsWith(start_date, "2026-")) phase18_fd_abort("blocked_edition_identity", "Provider season does not start in 2026")
  team_objects <- phase18_fd_list_rows(payload$teams$teams, "teams")
  match_objects <- phase18_fd_list_rows(payload$matches$matches, "matches")
  standing_groups <- phase18_fd_list_rows(payload$standings$standings, "standings")
  standing_objects <- unlist(lapply(standing_groups, function(group) phase18_fd_or(group$table, list())), recursive = FALSE)
  if (!length(standing_objects)) phase18_fd_abort("blocked_empty_resource", "standings table is empty")
  freshness_evidence <- do.call(rbind, list(
    phase18_fd_freshness_evidence(
      "competition_metadata", list(competition$lastUpdated), "resource", "competition_metadata.lastUpdated",
      fetched$competition_metadata$retrieved_at_utc, now_utc
    ),
    phase18_fd_freshness_evidence(
      "teams", lapply(team_objects, `[[`, "lastUpdated"), "rows", "teams.teams[*].lastUpdated",
      fetched$teams$retrieved_at_utc, now_utc
    ),
    phase18_fd_freshness_evidence(
      "matches", lapply(match_objects, `[[`, "lastUpdated"), "rows", "matches.matches[*].lastUpdated",
      fetched$matches$retrieved_at_utc, now_utc
    ),
    phase18_fd_freshness_evidence(
      "standings", list(payload$standings$lastUpdated), "resource", "standings.lastUpdated",
      fetched$standings$retrieved_at_utc, now_utc
    )
  ))
  if (!phase18_fd_pagination_complete(payload$teams, length(team_objects)) ||
      !phase18_fd_pagination_complete(payload$matches, length(match_objects)) ||
      !phase18_fd_pagination_complete(payload$standings, length(standing_objects))) {
    phase18_fd_abort("blocked_incomplete_pagination", "Provider indicates an incomplete resource page")
  }

  team_provider_ids <- vapply(team_objects, function(team) phase18_fd_scalar(team$id, "team.id"), character(1))
  if (anyDuplicated(team_provider_ids)) phase18_fd_abort("blocked_duplicate_id", "Provider team IDs are duplicated")
  match_provider_ids <- vapply(match_objects, function(match) phase18_fd_scalar(match$id, "match.id"), character(1))
  if (anyDuplicated(match_provider_ids)) phase18_fd_abort("blocked_duplicate_id", "Provider match IDs are duplicated")
  stages <- vapply(match_objects, function(match) phase18_fd_scalar(match$stage, "match.stage"), character(1))
  statuses <- vapply(match_objects, function(match) phase18_fd_scalar(match$status, "match.status"), character(1))
  allowed_statuses <- c("SCHEDULED", "TIMED", "IN_PLAY", "PAUSED", "FINISHED", "POSTPONED", "SUSPENDED", "CANCELLED", "AWARDED")
  if (length(setdiff(unique(statuses), allowed_statuses))) {
    phase18_fd_abort("blocked_unknown_status", "Provider match status is outside the closed enum")
  }
  allowed_stages <- unique(trimws(unlist(strsplit(as.character(edition_expectations$allowed_stages[[1L]]), "\\|"))))
  if (length(setdiff(unique(stages), allowed_stages))) {
    phase18_fd_abort("blocked_unknown_stage", "Provider match stage is outside the reviewed allowlist")
  }
  observed <- list(
    club_count = length(team_objects), league_phase_match_count = sum(stages == "LEAGUE_STAGE"),
    stages = paste(sort(unique(stages)), collapse = "|"), standings_rows = length(standing_objects)
  )
  expectation <- phase18_validate_edition_expectations(edition_expectations, observed, "league_phase")
  if (!isTRUE(expectation$valid)) {
    reason <- switch(expectation$reason_code, cardinality = "blocked_cardinality", stage = "blocked_unknown_stage", standings = "blocked_standings", "blocked_coverage")
    phase18_fd_abort(reason, expectation$message)
  }

  event_at <- phase18_fd_scalar(competition$lastUpdated, "competition.lastUpdated")
  club_rows <- lapply(seq_along(team_objects), function(index) {
    team <- team_objects[[index]]
    provider_id <- phase18_fd_scalar(team$id, "team.id")
    display_name <- phase18_fd_scalar(team$name, "team.name")
    resolution <- tryCatch(
      phase18_resolve_club_identity(
        club_registries, "football_data_org_v4", provider_id, display_name, event_at
      ),
      error = function(error) phase18_fd_abort("blocked_unresolved_club", conditionMessage(error))
    )
    data.frame(
      schema_version = "phase18-fd-club-v2", hash_encoding_version = phase18_canonical_encoding_v2(), edition_id = edition_id,
      provider_id = "football_data_org_v4", provider_club_id = provider_id,
      club_id = resolution$club_id[[1L]], display_name = display_name,
      canonical_name = resolution$canonical_name[[1L]],
      short_name = phase18_fd_scalar(team$shortName, "team.shortName", TRUE),
      tla = phase18_fd_scalar(team$tla, "team.tla", TRUE),
      crest_url = phase18_fd_scalar(team$crest, "team.crest", TRUE),
      last_updated_utc = phase18_fd_scalar(team$lastUpdated, "team.lastUpdated"),
      source_raw_sha256 = fetched$teams$raw_sha256, row_sha256 = "",
      stringsAsFactors = FALSE, check.names = FALSE
    )
  })
  clubs <- do.call(rbind, club_rows)
  clubs$row_sha256 <- phase18_fd_row_hash(clubs)
  provider_to_club <- setNames(clubs$club_id, clubs$provider_club_id)

  match_rows <- lapply(seq_along(match_objects), function(index) {
    match <- match_objects[[index]]
    if (is.null(match$homeTeam) || is.null(match$awayTeam)) {
      phase18_fd_abort("blocked_missing_team", "Match is missing a nested team")
    }
    home_id <- phase18_fd_scalar(match$homeTeam$id, "match.homeTeam.id")
    away_id <- phase18_fd_scalar(match$awayTeam$id, "match.awayTeam.id")
    if (!home_id %in% names(provider_to_club) || !away_id %in% names(provider_to_club)) {
      phase18_fd_abort("blocked_unresolved_club", "Match participant is not in the reviewed club set")
    }
    kickoff <- phase18_fd_scalar(match$utcDate, "match.utcDate")
    for (side in c("homeTeam", "awayTeam")) {
      team <- match[[side]]
      tryCatch(
        phase18_resolve_club_identity(
          club_registries, "football_data_org_v4", phase18_fd_scalar(team$id, paste0("match.", side, ".id")),
          phase18_fd_scalar(team$name, paste0("match.", side, ".name")), kickoff
        ),
        error = function(error) phase18_fd_abort("blocked_unresolved_club", conditionMessage(error))
      )
    }
    score <- phase18_fd_or(match$score, list())
    full_time <- phase18_fd_or(score$fullTime, list())
    data.frame(
      schema_version = "phase18-fd-match-v2", hash_encoding_version = phase18_canonical_encoding_v2(), edition_id = edition_id,
      provider_match_id = phase18_fd_scalar(match$id, "match.id"),
      kickoff_utc = kickoff, status = phase18_fd_scalar(match$status, "match.status"),
      stage = phase18_fd_scalar(match$stage, "match.stage"),
      matchday = phase18_fd_nullable_integer(match$matchday),
      home_club_id = unname(provider_to_club[[home_id]]), away_club_id = unname(provider_to_club[[away_id]]),
      home_score = phase18_fd_nullable_integer(full_time$home),
      away_score = phase18_fd_nullable_integer(full_time$away),
      winner = phase18_fd_scalar(score$winner, "score.winner", TRUE),
      last_updated_utc = phase18_fd_scalar(match$lastUpdated, "match.lastUpdated"),
      source_raw_sha256 = fetched$matches$raw_sha256, row_sha256 = "",
      stringsAsFactors = FALSE, check.names = FALSE
    )
  })
  matches <- do.call(rbind, match_rows)
  matches$row_sha256 <- phase18_fd_row_hash(matches)

  standing_rows <- lapply(seq_along(standing_objects), function(index) {
    row <- standing_objects[[index]]
    team <- phase18_fd_nested(row, c("team"))
    provider_id <- phase18_fd_scalar(team$id, "standing.team.id")
    if (!provider_id %in% names(provider_to_club)) phase18_fd_abort("blocked_unresolved_club", "Standing club is unresolved")
    data.frame(
      schema_version = "phase18-fd-standing-v2", hash_encoding_version = phase18_canonical_encoding_v2(), edition_id = edition_id,
      stage = phase18_fd_scalar(standing_groups[[1L]]$stage, "standings.stage"),
      table_type = phase18_fd_scalar(standing_groups[[1L]]$type, "standings.type"),
      position = phase18_fd_nullable_integer(row$position), club_id = unname(provider_to_club[[provider_id]]),
      played = phase18_fd_nullable_integer(row$playedGames), won = phase18_fd_nullable_integer(row$won),
      drawn = phase18_fd_nullable_integer(row$draw), lost = phase18_fd_nullable_integer(row$lost),
      points = phase18_fd_nullable_integer(row$points), goals_for = phase18_fd_nullable_integer(row$goalsFor),
      goals_against = phase18_fd_nullable_integer(row$goalsAgainst),
      goal_difference = phase18_fd_nullable_integer(row$goalDifference),
      source_raw_sha256 = fetched$standings$raw_sha256, row_sha256 = "",
      stringsAsFactors = FALSE, check.names = FALSE
    )
  })
  standings <- do.call(rbind, standing_rows)
  if (anyDuplicated(standings$club_id)) phase18_fd_abort("blocked_duplicate_id", "Standings contain duplicate clubs")
  standings$row_sha256 <- phase18_fd_row_hash(standings)

  competition_table <- data.frame(
    schema_version = "phase18-fd-competition-v2", hash_encoding_version = phase18_canonical_encoding_v2(), edition_id = edition_id,
    provider_id = "football_data_org_v4",
    provider_competition_id = phase18_fd_scalar(competition$id, "competition.id"),
    provider_season_id = phase18_fd_scalar(season$id, "currentSeason.id"),
    code = "CL", name = phase18_fd_scalar(competition$name, "competition.name"),
    type = phase18_fd_scalar(competition$type, "competition.type"),
    start_date = start_date, end_date = phase18_fd_scalar(season$endDate, "currentSeason.endDate"),
    current_matchday = phase18_fd_nullable_integer(season$currentMatchday),
    last_updated_utc = event_at, source_raw_sha256 = fetched$competition_metadata$raw_sha256,
    row_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE
  )
  competition_table$row_sha256 <- phase18_fd_row_hash(competition_table)
  lifecycle <- data.frame(
    schema_version = "phase18-fd-lifecycle-v2", hash_encoding_version = phase18_canonical_encoding_v2(), edition_id = edition_id,
    lifecycle = "league_phase", observed_club_count = nrow(clubs),
    observed_match_count = nrow(matches), observed_standings_rows = nrow(standings),
    observed_stages = paste(sort(unique(matches$stage)), collapse = "|"),
    expectation_sha256 = expectation$expectation_sha256,
    source_as_of_utc = max(c(competition_table$last_updated_utc, matches$last_updated_utc)),
    retrieved_at_utc = max(vapply(fetched, `[[`, character(1), "retrieved_at_utc")),
    row_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE
  )
  lifecycle$row_sha256 <- phase18_fd_row_hash(lifecycle)
  schema_fingerprint <- data.frame(
    resource = expected_names,
    fingerprint_sha256 = vapply(payload, phase18_fd_fingerprint, character(1)),
    raw_sha256 = vapply(fetched, `[[`, character(1), "raw_sha256"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  coverage <- list(
    club_count = as.integer(nrow(clubs)),
    league_phase_match_count = as.integer(sum(matches$stage == "LEAGUE_STAGE")),
    standings_rows = as.integer(nrow(standings)), stages = sort(unique(matches$stage)),
    identity_passed = TRUE, pagination_complete = TRUE,
    freshness_passed = all(freshness_evidence$verdict == "pass"), expectation_sha256 = expectation$expectation_sha256
  )
  list(
    competition = competition_table, clubs = clubs, matches = matches,
    standings = standings, lifecycle = lifecycle, coverage = coverage,
    schema_fingerprint = schema_fingerprint, freshness_evidence = freshness_evidence
  )
}

phase18_fd_project_resources <- function(...) {
  phase18_fd_with_closed_errors(phase18_fd_project_resources_impl(...))
}

phase18_fd_assert_secret_absent <- function(value, secret) {
  if (is.null(secret) || length(secret) != 1L || is.na(secret) || !nzchar(secret)) return(invisible(TRUE))
  haystack <- serialize(value, NULL, version = 2)
  needle <- charToRaw(enc2utf8(secret))
  exposed <- FALSE
  if (length(needle) <= length(haystack)) {
    exposed <- any(vapply(seq_len(length(haystack) - length(needle) + 1L), function(index) {
      identical(haystack[index:(index + length(needle) - 1L)], needle)
    }, logical(1)))
  }
  if (exposed) {
    phase18_fd_abort("blocked_secret_exposure", "Credential bytes escaped the transport boundary")
  }
  invisible(TRUE)
}
