#' Official UEFA Nations League 2026/27 match-response adapter.
#'
#' UEFA publishes the Nations League schedule as one match collection rather
#' than as the five compact resource classes used by xGelo.  This module is a
#' deliberately small boundary adapter: it validates the official response,
#' projects it into the existing Phase 13/14 contracts, and never fabricates a
#' fixture or standings row.

phase14_uefa_nl_edition_id <- function() {
  "uefa_nations_league_2026_27"
}

phase14_uefa_nl_matches_url <- function() {
  "https://match.uefa.com/v5/matches?competitionId=2014&seasonYear=2027&offset=0&limit=200"
}

phase14_uefa_nl_source_page_url <- function() {
  "https://www.uefa.com/uefanationsleague/fixtures-results/"
}

phase14_uefa_nl_bundle_id <- function() {
  "nl-2026-27-official-uefa-v2"
}

phase14_uefa_nl_scalar <- function(value, name, allow_empty = FALSE) {
  if (is.null(value) || length(value) != 1L || is.na(value)) {
    stop("Official UEFA Nations League ", name, " must be one non-missing value", call. = FALSE)
  }
  value <- as.character(value[[1L]])
  if (!allow_empty && !nzchar(trimws(value))) {
    stop("Official UEFA Nations League ", name, " must not be empty", call. = FALSE)
  }
  value
}

phase14_uefa_nl_get <- function(value, path, default = NULL) {
  current <- value
  for (key in as.character(path)) {
    if (!is.list(current) || is.null(current[[key]])) return(default)
    current <- current[[key]]
  }
  current
}

phase14_uefa_nl_first_scalar <- function(..., default = NULL) {
  values <- list(...)
  for (value in values) {
    if (is.null(value) || !length(value) || is.na(value[[1L]])) next
    value <- as.character(value[[1L]])
    if (nzchar(trimws(value))) return(value)
  }
  default
}

phase14_uefa_nl_team_display_name <- function(team) {
  phase14_uefa_nl_first_scalar(
    phase14_uefa_nl_get(team, c("translations", "displayName", "EN")),
    team$internationalName,
    phase14_uefa_nl_get(team, c("translations", "countryName", "EN")),
    default = NA_character_
  )
}

phase14_uefa_nl_team_record <- function(team) {
  if (!is.list(team)) stop("Official UEFA Nations League team payload is not an object", call. = FALSE)
  placeholder <- phase14_uefa_nl_first_scalar(team$isPlaceHolder, default = "false")
  if (tolower(placeholder) %in% c("true", "t", "1", "yes")) {
    stop("Official UEFA Nations League response contains a placeholder team", call. = FALSE)
  }
  id <- phase14_uefa_nl_first_scalar(team$id, team$organizationId, default = NA_character_)
  code <- phase14_uefa_nl_first_scalar(team$countryCode, team$teamCode, default = NA_character_)
  name <- phase14_uefa_nl_team_display_name(team)
  if (any(is.na(c(id, code, name)) | !nzchar(trimws(c(id, code, name))))) {
    stop("Official UEFA Nations League response contains an incomplete team identity", call. = FALSE)
  }
  data.frame(
    uefa_source_team_id = id,
    uefa_team_code = toupper(code),
    display_name = name,
    international_name = phase14_uefa_nl_first_scalar(team$internationalName, name),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

phase14_uefa_nl_validate_response <- function(
    payload,
    expected_fixture_count = 156L,
    expected_group_count = 14L,
    expected_team_count = 54L) {
  if (!is.list(payload) || !length(payload) || is.data.frame(payload)) {
    stop("Official UEFA Nations League match response must be a non-empty JSON array", call. = FALSE)
  }
  required_fixture_fields <- c("id", "status", "seasonYear", "kickOffTime", "group", "homeTeam", "awayTeam")
  fixture_ids <- character(length(payload))
  group_ids <- character(length(payload))
  team_ids <- character(0)
  for (index in seq_along(payload)) {
    match <- payload[[index]]
    missing <- required_fixture_fields[vapply(required_fixture_fields, function(field) is.null(match[[field]]), logical(1))]
    if (length(missing)) {
      stop("Official UEFA Nations League match is missing fields: ", paste(missing, collapse = ", "), call. = FALSE)
    }
    fixture_ids[[index]] <- phase14_uefa_nl_scalar(match$id, "fixture ID")
    if (!identical(as.character(match$seasonYear[[1L]]), "2027")) {
      stop("Official UEFA Nations League response contains a non-2027 season", call. = FALSE)
    }
    competition_id <- phase14_uefa_nl_first_scalar(
      phase14_uefa_nl_get(match, c("competition", "id")),
      phase14_uefa_nl_get(match, c("group", "competitionId")),
      default = NA_character_
    )
    if (!identical(competition_id, "2014")) {
      stop("Official UEFA Nations League response contains a non-2014 competition", call. = FALSE)
    }
    kickoff <- phase14_uefa_nl_first_scalar(
      phase14_uefa_nl_get(match, c("kickOffTime", "dateTime")),
      default = NA_character_
    )
    if (is.na(kickoff) || is.na(suppressWarnings(as.POSIXct(kickoff, tz = "UTC")))) {
      stop("Official UEFA Nations League response contains a malformed kickoff", call. = FALSE)
    }
    group_ids[[index]] <- phase14_uefa_nl_scalar(match$group$id, "group ID")
    phase14_uefa_nl_team_record(match$homeTeam)
    phase14_uefa_nl_team_record(match$awayTeam)
    team_ids <- c(
      team_ids,
      phase14_uefa_nl_scalar(match$homeTeam$id, "home UEFA team ID"),
      phase14_uefa_nl_scalar(match$awayTeam$id, "away UEFA team ID")
    )
  }
  if (length(payload) != as.integer(expected_fixture_count)) {
    stop("Official UEFA Nations League response fixture count is not ", expected_fixture_count, call. = FALSE)
  }
  if (anyDuplicated(fixture_ids)) stop("Official UEFA Nations League response contains duplicate fixture IDs", call. = FALSE)
  if (length(unique(group_ids)) != as.integer(expected_group_count)) {
    stop("Official UEFA Nations League response group count is not ", expected_group_count, call. = FALSE)
  }
  if (length(unique(team_ids)) != as.integer(expected_team_count)) {
    stop("Official UEFA Nations League response team count is not ", expected_team_count, call. = FALSE)
  }
  if (any(tolower(vapply(payload, function(match) phase14_uefa_nl_scalar(match$status, "status"), character(1))) != "upcoming")) {
    stop("Official UEFA Nations League response contains a non-UPCOMING match", call. = FALSE)
  }
  invisible(payload)
}

phase14_uefa_nl_adapt_response <- function(
    payload,
    expected_fixture_count = 156L,
    expected_group_count = 14L,
    expected_team_count = 54L) {
  phase14_uefa_nl_validate_response(
    payload,
    expected_fixture_count = expected_fixture_count,
    expected_group_count = expected_group_count,
    expected_team_count = expected_team_count
  )
  n <- length(payload)
  fixture_rows <- lapply(payload, function(match) {
    group_id <- phase14_uefa_nl_scalar(match$group$id, "group ID")
    kickoff <- phase14_uefa_nl_scalar(
      phase14_uefa_nl_get(match, c("kickOffTime", "dateTime")),
      "kickoff"
    )
    status <- phase14_uefa_nl_scalar(match$status, "status")
    home <- phase14_uefa_nl_team_record(match$homeTeam)
    away <- phase14_uefa_nl_team_record(match$awayTeam)
    data.frame(
      source_fixture_id = phase14_uefa_nl_scalar(match$id, "fixture ID"),
      scheduled_at_utc = kickoff,
      status = status,
      home_uefa_source_team_id = home$uefa_source_team_id,
      away_uefa_source_team_id = away$uefa_source_team_id,
      home_display_name = home$display_name,
      away_display_name = away$display_name,
      source_group_id = group_id,
      group_id = group_id,
      source_status = status,
      kickoff_confirmed = TRUE,
      confirmed_kickoff_at_utc = kickoff,
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  })
  fixtures <- do.call(rbind, fixture_rows)

  group_rows <- lapply(payload, function(match) {
    group <- match$group
    league <- phase14_uefa_nl_first_scalar(
      phase14_uefa_nl_get(group, c("league", "metaData", "leagueName")),
      phase14_uefa_nl_get(group, c("league", "translations", "name", "EN")),
      default = NA_character_
    )
    league <- sub("^League[[:space:]]+", "", league)
    display_name <- phase14_uefa_nl_first_scalar(
      phase14_uefa_nl_get(group, c("metaData", "groupName")),
      phase14_uefa_nl_get(group, c("translations", "name", "EN")),
      default = NA_character_
    )
    data.frame(
      source_group_id = phase14_uefa_nl_scalar(group$id, "group ID"),
      league = phase14_uefa_nl_scalar(league, "league"),
      display_name = phase14_uefa_nl_scalar(display_name, "group display name"),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  })
  groups <- do.call(rbind, group_rows)
  groups <- groups[!duplicated(groups$source_group_id), , drop = FALSE]
  groups <- groups[order(as.character(groups$source_group_id), method = "radix"), , drop = FALSE]
  row.names(groups) <- NULL

  team_rows <- unlist(lapply(payload, function(match) {
    list(phase14_uefa_nl_team_record(match$homeTeam), phase14_uefa_nl_team_record(match$awayTeam))
  }), recursive = FALSE)
  teams <- do.call(rbind, team_rows)
  teams <- teams[!duplicated(teams$uefa_source_team_id), , drop = FALSE]
  teams <- teams[order(as.character(teams$uefa_source_team_id), method = "radix"), , drop = FALSE]
  row.names(teams) <- NULL

  standings <- data.frame(
    source_team_id = character(0),
    source_group_id = character(0),
    position = integer(0),
    points = integer(0),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  results <- data.frame(
    source_fixture_id = fixtures$source_fixture_id,
    status = fixtures$status,
    home_goals = rep(NA_integer_, n),
    away_goals = rep(NA_integer_, n),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  status <- data.frame(
    source_edition_id = phase14_uefa_nl_edition_id(),
    competition_status = "scheduled",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  list(
    resources = list(
      fixtures = fixtures,
      groups = groups,
      standings = standings,
      results = results,
      status = status
    ),
    teams = teams,
    official_counts = c(fixtures = nrow(fixtures), groups = nrow(groups), teams = nrow(teams)),
    source_url = phase14_uefa_nl_matches_url()
  )
}

phase14_uefa_nl_adapt_raw_bytes <- function(raw_bytes, artifact_type) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("jsonlite is required for the UEFA adapter", call. = FALSE)
  raw_bytes <- if (is.raw(raw_bytes)) raw_bytes else charToRaw(enc2utf8(as.character(raw_bytes)))
  payload <- jsonlite::fromJSON(rawToChar(raw_bytes), simplifyVector = FALSE)
  adapted <- phase14_uefa_nl_adapt_response(payload)
  if (!artifact_type %in% names(adapted$resources)) {
    stop("Official UEFA Nations League adapter does not expose resource: ", artifact_type, call. = FALSE)
  }
  adapted$resources[[artifact_type]]
}

phase14_uefa_nl_validate_payload <- function(payload, artifact_type = "fixtures") {
  if (!identical(as.character(artifact_type), "fixtures")) {
    stop("Official UEFA Nations League endpoint payload must enter through the fixtures adapter boundary", call. = FALSE)
  }
  phase14_uefa_nl_validate_response(payload)
  invisible(payload)
}

phase14_uefa_nl_api_key <- function(options = list()) {
  supplied <- options[["uefa-api-key"]] %||% options[["uefa_public_api_key"]]
  if (is.null(supplied) || !length(supplied) || is.na(supplied[[1L]]) || !nzchar(trimws(as.character(supplied[[1L]])))) {
    supplied <- Sys.getenv("UEFA_PUBLIC_API_KEY", unset = "")
  }
  if (length(supplied) != 1L || is.na(supplied) || !nzchar(trimws(as.character(supplied)))) return(NULL)
  as.character(supplied[[1L]])
}

phase14_uefa_nl_live_input <- function(
    options = list(),
    fetch_fn,
    clock_fn = function() as.numeric(Sys.time()),
    sleep_fn = Sys.sleep,
    rate_limit_state = NULL) {
  if (!is.function(fetch_fn)) stop("Official UEFA Nations League acquisition requires a fetch function", call. = FALSE)
  url <- options[["uefa-matches-url"]] %||% options[["uefa_matches_url"]] %||% phase14_uefa_nl_matches_url()
  url <- phase14_uefa_nl_scalar(url, "matches URL")
  headers <- phase14_uefa_nl_api_key(options)
  request_headers <- if (is.null(headers)) NULL else list(`x-api-key` = headers)
  fetch_formals <- names(formals(fetch_fn))
  fetch_args <- list(
    url = url,
    artifact_type = "fixtures",
    rate_limit_state = rate_limit_state,
    clock_fn = clock_fn,
    sleep_fn = sleep_fn
  )
  if ("validate_payload_fn" %in% fetch_formals || "..." %in% fetch_formals) {
    fetch_args$validate_payload_fn <- phase14_uefa_nl_validate_payload
  }
  if (!is.null(request_headers) && ("request_headers" %in% fetch_formals || "..." %in% fetch_formals)) {
    fetch_args$request_headers <- request_headers
  }
  captured <- do.call(fetch_fn, fetch_args)
  if (!is.list(captured) || is.null(captured$payload) || is.null(captured$raw_bytes)) {
    stop("Official UEFA Nations League fetch did not return a payload and exact raw bytes", call. = FALSE)
  }
  adapted <- phase14_uefa_nl_adapt_response(captured$payload)
  resource_types <- c("fixtures", "groups", "standings", "results", "status")
  source_url <- captured$source_url %||% url
  list(
    edition_id = phase14_uefa_nl_edition_id(),
    resources = adapted$resources,
    teams = adapted$teams,
    official_counts = adapted$official_counts,
    source_urls = setNames(rep(source_url, length(resource_types)), resource_types),
    raw_bytes_by_resource = setNames(rep(list(captured$raw_bytes), length(resource_types)), resource_types),
    retrieved_at_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    official_endpoint = source_url,
    source_page_url = phase14_uefa_nl_source_page_url()
  )
}

phase14_uefa_nl_normalize_name <- function(value) {
  if (exists("phase13_normalize_team_name", mode = "function")) return(phase13_normalize_team_name(value))
  value <- iconv(trimws(as.character(value)), from = "", to = "ASCII//TRANSLIT", sub = "")
  value <- tolower(gsub("[^a-z0-9]+", " ", value))
  trimws(gsub("[[:space:]]+", " ", value))
}

phase14_uefa_nl_missing_text <- function(value) {
  is.null(value) || !length(value) || is.na(value[[1L]]) ||
    !nzchar(trimws(as.character(value[[1L]]))) ||
    tolower(trimws(as.character(value[[1L]]))) %in% c("na", "n/a", "null")
}

phase14_uefa_nl_build_identity_registry <- function(
    official_teams,
    stable_identity_map,
    bundle_id = phase14_uefa_nl_bundle_id(),
    existing_registry = NULL) {
  required_official <- c("uefa_source_team_id", "uefa_team_code", "display_name")
  missing_official <- setdiff(required_official, names(official_teams))
  if (length(missing_official)) stop("Official UEFA team inventory is missing: ", paste(missing_official, collapse = ", "), call. = FALSE)
  required_stable <- c("team_id", "fifa_code", "canonical_name", "aliases")
  missing_stable <- setdiff(required_stable, names(stable_identity_map))
  if (length(missing_stable)) stop("Stable xGelo identity map is missing: ", paste(missing_stable, collapse = ", "), call. = FALSE)
  bundle_id <- phase14_uefa_nl_scalar(bundle_id, "bundle ID")
  stable_identity_map <- as.data.frame(stable_identity_map, stringsAsFactors = FALSE, check.names = FALSE)
  official_teams <- as.data.frame(official_teams, stringsAsFactors = FALSE, check.names = FALSE)
  if (!nrow(official_teams) || anyDuplicated(as.character(official_teams$uefa_source_team_id))) {
    stop("Official UEFA team inventory must contain unique non-empty IDs", call. = FALSE)
  }
  normalize <- phase14_uefa_nl_normalize_name
  stable_aliases <- function(row) {
    values <- c(
      row$canonical_name[[1L]],
      if ("source_display_name" %in% names(row)) row$source_display_name[[1L]] else character(0),
      if (phase14_uefa_nl_missing_text(row$aliases)) character(0) else unlist(strsplit(as.character(row$aliases[[1L]]), "\\|", fixed = FALSE), use.names = FALSE)
    )
    unique(normalize(values)[!is.na(normalize(values)) & nzchar(normalize(values))])
  }
  existing_registry <- if (is.null(existing_registry)) data.frame() else as.data.frame(existing_registry, stringsAsFactors = FALSE, check.names = FALSE)
  rows <- lapply(seq_len(nrow(official_teams)), function(index) {
    team <- official_teams[index, , drop = FALSE]
    code <- toupper(as.character(team$uefa_team_code[[1L]]))
    name <- as.character(team$display_name[[1L]])
    direct <- which(!is.na(stable_identity_map$fifa_code) & toupper(as.character(stable_identity_map$fifa_code)) == code)
    if (length(direct) > 1L) stop("Stable xGelo identity map has multiple FIFA matches for UEFA code: ", code, call. = FALSE)
    if (!length(direct)) {
      target <- normalize(c(name, if ("international_name" %in% names(team)) team$international_name[[1L]] else ""))
      matches <- unique(unlist(lapply(seq_len(nrow(stable_identity_map)), function(map_index) {
        aliases <- stable_aliases(stable_identity_map[map_index, , drop = FALSE])
        if (any(target %in% aliases)) map_index else integer(0)
      }), use.names = FALSE))
      if (length(matches) != 1L) stop("Official UEFA team could not be resolved to one stable xGelo ID: ", name, " (", code, ")", call. = FALSE)
      direct <- matches
    }
    stable <- stable_identity_map[direct[[1L]], , drop = FALSE]
    existing <- if (nrow(existing_registry) && "team_id" %in% names(existing_registry)) {
      existing_registry[as.character(existing_registry$team_id) == as.character(stable$team_id[[1L]]), , drop = FALSE]
    } else data.frame()
    old_aliases <- if (nrow(existing) && "aliases" %in% names(existing) && !is.na(existing$aliases[[1L]])) {
      unlist(strsplit(as.character(existing$aliases[[1L]]), "\\|", fixed = FALSE), use.names = FALSE)
    } else character(0)
    stable_fifa <- as.character(stable$fifa_code[[1L]])
    if (phase14_uefa_nl_missing_text(stable$fifa_code)) stable_fifa <- code
    aliases <- unique(c(
      old_aliases,
      if (phase14_uefa_nl_missing_text(stable$aliases)) character(0) else unlist(strsplit(as.character(stable$aliases[[1L]]), "\\|", fixed = FALSE), use.names = FALSE),
      name,
      if ("international_name" %in% names(team)) as.character(team$international_name[[1L]]) else character(0)
    ))
    data.frame(
      schema_version = "phase13-team-identity-v1",
      team_id = as.character(stable$team_id[[1L]]),
      fifa_code = toupper(stable_fifa),
      canonical_name = as.character(stable$canonical_name[[1L]]),
      aliases = paste(aliases[!is.na(aliases) & nzchar(trimws(aliases))], collapse = "|"),
      normalized_alias = "",
      uefa_source_team_id = as.character(team$uefa_source_team_id[[1L]]),
      uefa_display_name_current = name,
      uefa_team_code = code,
      mapping_method = "source_id",
      mapping_warning = "none",
      alias_review_state = "not_required",
      source_bundle_id = bundle_id,
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  })
  output <- do.call(rbind, rows)
  output <- output[order(as.character(output$team_id), method = "radix"), , drop = FALSE]
  row.names(output) <- NULL
  if (exists("phase13_prepare_team_identity_map", mode = "function")) {
    output <- phase13_prepare_team_identity_map(output)
  } else {
    output$normalized_alias <- vapply(seq_len(nrow(output)), function(index) {
      aliases <- unique(normalize(c(output$canonical_name[[index]], output$uefa_display_name_current[[index]], strsplit(output$aliases[[index]], "\\|", fixed = FALSE)[[1L]])))
      paste(aliases[!is.na(aliases) & nzchar(aliases)], collapse = "|")
    }, character(1))
  }
  if (anyDuplicated(output$team_id) || anyDuplicated(output$fifa_code) || anyDuplicated(output$uefa_source_team_id)) {
    stop("Official UEFA team identity registry contains duplicate stable keys", call. = FALSE)
  }
  output$row_sha256 <- if (exists("phase13_identity_row_hash", mode = "function")) {
    phase13_identity_row_hash(output)
  } else if (requireNamespace("digest", quietly = TRUE)) {
    vapply(seq_len(nrow(output)), function(index) digest::digest(paste(output[index, setdiff(names(output), "row_sha256"), drop = TRUE], collapse = "|"), algo = "sha256", serialize = FALSE), character(1))
  } else stop("digest is required for official UEFA team identity hashes", call. = FALSE)
  output
}

`%||%` <- if (exists("%||%", mode = "function")) get("%||%", mode = "function") else function(value, fallback) if (is.null(value)) fallback else value

# ---------------------------------------------------------------------------
# Phase 15 optional downstream-stage capture boundary.
# ---------------------------------------------------------------------------

phase15_uefa_nl_stage_capture_schema <- function() {
  c(
    "edition_id", "stage_id", "round_id", "leg_number", "source_fixture_id",
    "home_team_id", "away_team_id", "participant_slot_home", "participant_slot_away",
    "scheduled_at_utc", "source_status", "stage_status", "source_artifact_id",
    "source_url", "retrieved_at_utc", "raw_sha256", "regulation_home_goals",
    "regulation_away_goals", "extra_time_home_goals", "extra_time_away_goals",
    "penalty_shootout_home_goals", "penalty_shootout_away_goals", "final_home_goals",
    "final_away_goals", "completed_at_utc", "row_sha256"
  )
}

phase15_uefa_nl_stage_capture_manifest_schema <- function() {
  c(
    "capture_id", "edition_id", "capture_relative_path", "raw_relative_path",
    "capture_status", "capture_row_count", "capture_content_sha256", "raw_sha256",
    "source_bundle_id", "source_bundle_sha256", "source_url", "retrieved_at_utc",
    "parser_commit_sha", "validation_status", "manifest_sha256", "row_sha256"
  )
}

phase15_uefa_nl_stage_capture_id <- function() {
  "nl-2026-27-stage-capture-v1"
}

phase15_uefa_nl_adapter_project_root <- function(project_root = ".") {
  if (exists("phase13_source_find_project_root", mode = "function", inherits = TRUE)) {
    return(phase13_source_find_project_root(project_root))
  }
  candidate <- normalizePath(project_root, winslash = "/", mustWork = FALSE)
  if (file.exists(candidate) && !dir.exists(candidate)) candidate <- dirname(candidate)
  repeat {
    if (dir.exists(file.path(candidate, ".git")) || file.exists(file.path(candidate, ".git"))) return(candidate)
    parent <- dirname(candidate)
    if (identical(parent, candidate)) break
    candidate <- parent
  }
  normalizePath(project_root, winslash = "/", mustWork = TRUE)
}

phase15_uefa_nl_adapter_safe_relative_path <- function(path) {
  if (exists("phase13_source_safe_relative_path", mode = "function", inherits = TRUE)) return(phase13_source_safe_relative_path(path))
  path <- gsub("\\\\", "/", as.character(path))
  if (length(path) != 1L || is.na(path) || !nzchar(path) || grepl("^/", path) || grepl("^[A-Za-z]:", path) || grepl("(^|/)\\.\\.?(/|$)", path) || grepl("//", path)) {
    stop("Phase 15 stage capture path is unsafe: ", path, call. = FALSE)
  }
  path
}

phase15_uefa_nl_adapter_path_under_root <- function(root, relative_path, must_work = FALSE) {
  relative_path <- phase15_uefa_nl_adapter_safe_relative_path(relative_path)
  if (exists("phase13_source_path_under_root", mode = "function", inherits = TRUE)) {
    return(phase13_source_path_under_root(root, relative_path, must_work = must_work))
  }
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  candidate <- normalizePath(file.path(root, relative_path), winslash = "/", mustWork = FALSE)
  if (!(identical(candidate, root) || startsWith(candidate, paste0(root, "/")))) stop("Phase 15 stage capture path escapes the project root", call. = FALSE)
  if (isTRUE(must_work) && !file.exists(candidate)) stop("Phase 15 stage capture artifact is missing: ", relative_path, call. = FALSE)
  candidate
}

phase15_uefa_nl_stage_capture_paths <- function(
    project_root = ".",
    capture_id = phase15_uefa_nl_stage_capture_id()) {
  root <- phase15_uefa_nl_adapter_project_root(project_root)
  capture_id <- phase14_uefa_nl_scalar(capture_id, "stage capture ID")
  edition_id <- phase14_uefa_nl_edition_id()
  raw_relative_path <- phase15_uefa_nl_adapter_safe_relative_path(file.path(
    "data/competition/local_raw", edition_id, capture_id, "stage_capture.json"
  ))
  capture_relative_path <- phase15_uefa_nl_adapter_safe_relative_path(file.path(
    "data/competition/accepted", edition_id, "stage_capture.csv"
  ))
  manifest_relative_path <- phase15_uefa_nl_adapter_safe_relative_path(file.path(
    "data/competition/accepted", edition_id, "stage_capture_manifest.csv"
  ))
  registry_relative_path <- phase15_uefa_nl_adapter_safe_relative_path("data/competition/registries/stage_captures.csv")
  list(
    project_root = root,
    capture_id = capture_id,
    edition_id = edition_id,
    raw_relative_path = raw_relative_path,
    capture_relative_path = capture_relative_path,
    manifest_relative_path = manifest_relative_path,
    registry_relative_path = registry_relative_path,
    raw_path = phase15_uefa_nl_adapter_path_under_root(root, raw_relative_path),
    capture_path = phase15_uefa_nl_adapter_path_under_root(root, capture_relative_path),
    manifest_path = phase15_uefa_nl_adapter_path_under_root(root, manifest_relative_path),
    registry_path = phase15_uefa_nl_adapter_path_under_root(root, registry_relative_path)
  )
}

phase15_uefa_nl_capture_missing <- function(values) {
  values <- as.character(values)
  is.na(values) | !nzchar(trimws(values))
}

phase15_uefa_nl_parse_utc_timestamp <- function(values, field) {
  text <- trimws(as.character(values))
  parsed <- suppressWarnings(as.POSIXct(text, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  invalid <- is.na(text) | !nzchar(text) | is.na(parsed) | !grepl("Z$", text)
  if (any(invalid)) stop("Phase 15 stage capture has an invalid ", field, " UTC timestamp", call. = FALSE)
  parsed
}

phase15_uefa_nl_capture_hash <- function(value) {
  if (exists("phase13_source_sha256", mode = "function", inherits = TRUE)) return(phase13_source_sha256(value))
  if (!requireNamespace("digest", quietly = TRUE)) stop("digest is required for Phase 15 capture hashes", call. = FALSE)
  bytes <- if (is.raw(value)) value else charToRaw(enc2utf8(as.character(value)))
  digest::digest(bytes, algo = "sha256", serialize = FALSE)
}

phase15_uefa_nl_capture_canonical_hash <- function(data, key = NULL) {
  if (exists("phase13_canonical_sha256", mode = "function", inherits = TRUE)) return(phase13_canonical_sha256(data, key = key))
  if (!requireNamespace("digest", quietly = TRUE)) stop("digest is required for Phase 15 capture hashes", call. = FALSE)
  fields <- names(data)
  if (is.null(key)) key <- fields[[1L]]
  data <- data[, sort(fields), drop = FALSE]
  order_args <- lapply(data[key], function(column) as.character(column))
  if (nrow(data)) data <- data[do.call(order, c(order_args, list(na.last = TRUE, method = "radix"))), , drop = FALSE]
  rows <- if (!nrow(data)) character() else apply(data, 1L, function(row) paste(ifelse(is.na(row), "", as.character(row)), collapse = "\x1f"))
  digest::digest(paste(c(paste(names(data), collapse = "\x1f"), rows), collapse = "\x1e"), algo = "sha256", serialize = FALSE)
}

phase15_uefa_nl_capture_row_hash <- function(data) {
  if (exists("phase13_row_sha256", mode = "function", inherits = TRUE)) return(phase13_row_sha256(data))
  fields <- setdiff(names(data), "row_sha256")
  vapply(seq_len(nrow(data)), function(index) {
    phase15_uefa_nl_capture_hash(paste(as.character(data[index, fields, drop = FALSE]), collapse = "|"))
  }, character(1))
}

phase15_uefa_nl_capture_score <- function(values, field, allow_missing = TRUE) {
  text <- as.character(values)
  present <- !is.na(text) & nzchar(trimws(text))
  numeric_values <- suppressWarnings(as.numeric(text))
  invalid <- present & (is.na(numeric_values) | !is.finite(numeric_values) | numeric_values < 0 | numeric_values != floor(numeric_values))
  if (any(invalid)) stop("Phase 15 stage capture ", field, " must contain non-negative integers", call. = FALSE)
  if (!isTRUE(allow_missing) && any(!present)) stop("Phase 15 stage capture ", field, " is required", call. = FALSE)
  output <- rep(NA_integer_, length(text))
  output[present] <- as.integer(numeric_values[present])
  output
}

phase15_uefa_nl_expected_source_bundle_sha256 <- function(project_root = ".") {
  root <- phase15_uefa_nl_adapter_project_root(project_root)
  path <- file.path(root, "data/competition/registries/source_bundles.csv")
  if (file.exists(path)) {
    bundles <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
    row <- bundles[as.character(bundles$bundle_id) == phase14_uefa_nl_bundle_id() & as.character(bundles$edition_id) == phase14_uefa_nl_edition_id(), , drop = FALSE]
    if (nrow(row) == 1L && grepl("^[0-9a-fA-F]{64}$", as.character(row$source_bundle_sha256[[1L]]))) return(tolower(as.character(row$source_bundle_sha256[[1L]])))
  }
  "d5a807768f5f30401d022a77c6f0095052579d0a0d8e7bebe4a22e1711e01dc2"
}

phase15_uefa_nl_manifest_self_sha256 <- function(manifest_row) {
  body <- manifest_row
  body$manifest_sha256 <- ""
  body$row_sha256 <- ""
  phase15_uefa_nl_capture_canonical_hash(body, key = "capture_id")
}

phase15_uefa_nl_validate_stage_capture_manifest <- function(
    manifest,
    paths = NULL,
    capture = NULL,
    project_root = ".") {
  if (!is.data.frame(manifest)) stop("Phase 15 stage capture manifest must be a data frame", call. = FALSE)
  required <- phase15_uefa_nl_stage_capture_manifest_schema()
  missing <- setdiff(required, names(manifest))
  if (length(missing)) stop("Phase 15 stage capture manifest is missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  if (nrow(manifest) != 1L) stop("Phase 15 stage capture manifest must contain one row", call. = FALSE)
  row <- manifest[1L, required, drop = FALSE]
  if (!identical(as.character(row$edition_id[[1L]]), phase14_uefa_nl_edition_id())) stop("Phase 15 stage capture manifest has a foreign edition", call. = FALSE)
  if (!identical(as.character(row$capture_id[[1L]]), phase15_uefa_nl_stage_capture_id())) stop("Phase 15 stage capture manifest has an unknown capture ID", call. = FALSE)
  if (!as.character(row$capture_status[[1L]]) %in% c("empty", "accepted")) stop("Phase 15 stage capture manifest has an unsupported capture_status", call. = FALSE)
  count <- suppressWarnings(as.numeric(as.character(row$capture_row_count[[1L]])))
  if (is.na(count) || count < 0 || count != floor(count)) stop("Phase 15 stage capture manifest has an invalid row count", call. = FALSE)
  path_values <- c(row$capture_relative_path[[1L]], row$raw_relative_path[[1L]])
  if (any(vapply(path_values, phase15_uefa_nl_adapter_safe_relative_path, character(1)) != path_values)) stop("Phase 15 stage capture manifest has noncanonical paths", call. = FALSE)
  if (!is.null(paths)) {
    if (!identical(as.character(row$capture_relative_path[[1L]]), as.character(paths$capture_relative_path)) ||
        !identical(as.character(row$raw_relative_path[[1L]]), as.character(paths$raw_relative_path))) {
      stop("Phase 15 stage capture manifest paths do not match the registered capture", call. = FALSE)
    }
  }
  hash_fields <- c("capture_content_sha256", "raw_sha256", "source_bundle_sha256", "manifest_sha256", "row_sha256")
  if (any(vapply(row[hash_fields], function(value) !grepl("^[0-9a-fA-F]{64}$", as.character(value[[1L]])), logical(1)))) {
    stop("Phase 15 stage capture manifest contains a noncanonical SHA-256", call. = FALSE)
  }
  if (!identical(tolower(as.character(row$source_bundle_sha256[[1L]])), phase15_uefa_nl_expected_source_bundle_sha256(project_root))) {
    stop("Phase 15 stage capture manifest has an unexpected Phase 13 source bundle hash", call. = FALSE)
  }
  if (phase15_uefa_nl_capture_missing(row$source_bundle_id) || phase15_uefa_nl_capture_missing(row$source_url) || phase15_uefa_nl_capture_missing(row$retrieved_at_utc) || phase15_uefa_nl_capture_missing(row$parser_commit_sha)) {
    stop("Phase 15 stage capture manifest is missing source lineage", call. = FALSE)
  }
  phase15_uefa_nl_parse_utc_timestamp(row$retrieved_at_utc, "retrieved_at_utc")
  if (!grepl("^https://", as.character(row$source_url[[1L]]))) stop("Phase 15 stage capture source_url must be HTTPS", call. = FALSE)
  if (!grepl("^[0-9a-fA-F]{7,64}$", as.character(row$parser_commit_sha[[1L]]))) stop("Phase 15 stage capture parser identity is invalid", call. = FALSE)
  if (!identical(tolower(as.character(row$manifest_sha256[[1L]])), tolower(phase15_uefa_nl_manifest_self_sha256(row)))) stop("Phase 15 stage capture manifest self-hash mismatch", call. = FALSE)
  expected_row_hash <- phase15_uefa_nl_capture_row_hash(row)
  if (!identical(tolower(as.character(row$row_sha256[[1L]])), tolower(expected_row_hash[[1L]]))) stop("Phase 15 stage capture manifest row hash mismatch", call. = FALSE)
  if (!is.null(capture) && as.integer(count) != nrow(capture)) stop("Phase 15 stage capture manifest row count does not match capture", call. = FALSE)
  if (identical(as.character(row$capture_status[[1L]]), "empty") && as.integer(count) != 0L) stop("Empty Phase 15 stage capture must have zero rows", call. = FALSE)
  if (identical(as.character(row$capture_status[[1L]]), "accepted") && as.integer(count) == 0L) stop("Accepted Phase 15 stage capture must contain rows", call. = FALSE)
  invisible(TRUE)
}

phase15_uefa_nl_load_rules <- function(project_root = ".") {
  if (exists("uefa_nl_stage_topology", mode = "function", inherits = TRUE)) return(invisible(TRUE))
  root <- phase15_uefa_nl_adapter_project_root(project_root)
  path <- file.path(root, "R/competition/uefa_nations_league_rules.R")
  if (!file.exists(path)) stop("Phase 15 Nations League rules source is missing", call. = FALSE)
  sys.source(path, envir = .GlobalEnv)
  invisible(TRUE)
}

phase15_uefa_nl_validate_stage_capture <- function(
    capture,
    manifest = NULL,
    project_root = ".") {
  phase15_uefa_nl_load_rules(project_root)
  if (!is.data.frame(capture)) stop("Phase 15 stage capture must be a data frame", call. = FALSE)
  required <- phase15_uefa_nl_stage_capture_schema()
  missing <- setdiff(required, names(capture))
  if (length(missing)) stop("Phase 15 stage capture is missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  if (!is.null(manifest)) phase15_uefa_nl_validate_stage_capture_manifest(manifest, capture = capture, project_root = project_root)
  if (!nrow(capture)) {
    if (is.null(manifest) || !identical(as.character(manifest$capture_status[[1L]]), "empty")) stop("A schema-valid empty stage capture requires a registered empty manifest", call. = FALSE)
    return(invisible(TRUE))
  }
  values <- as.data.frame(capture, stringsAsFactors = FALSE, check.names = FALSE)
  if (any(is.na(values$edition_id) | as.character(values$edition_id) != phase14_uefa_nl_edition_id())) stop("Phase 15 stage capture has a foreign edition", call. = FALSE)
  stage_ids <- uefa_nl_stage_topology()$stage_id
  if (any(is.na(values$stage_id) | !as.character(values$stage_id) %in% stage_ids)) stop("Phase 15 stage capture contains an unknown stage ID", call. = FALSE)
  if (any(phase15_uefa_nl_capture_missing(values$round_id))) stop("Phase 15 stage capture requires round_id", call. = FALSE)
  leg <- suppressWarnings(as.numeric(as.character(values$leg_number)))
  if (any(is.na(leg) | leg < 1 | leg != floor(leg))) stop("Phase 15 stage capture leg_number must be a positive integer", call. = FALSE)
  if (anyDuplicated(as.character(values$source_fixture_id)) || any(phase15_uefa_nl_capture_missing(values$source_fixture_id))) stop("Phase 15 stage capture requires unique source fixture IDs", call. = FALSE)
  team_valid <- if (exists("uefa_nl_team_id_valid", mode = "function", inherits = TRUE)) uefa_nl_team_id_valid else function(x) grepl("^team[-_]", as.character(x))
  if (any(!team_valid(values$home_team_id)) || any(!team_valid(values$away_team_id)) || any(as.character(values$home_team_id) == as.character(values$away_team_id))) stop("Phase 15 stage capture contains non-canonical team IDs", call. = FALSE)
  for (field in c("participant_slot_home", "participant_slot_away", "scheduled_at_utc", "source_status", "source_artifact_id", "source_url", "retrieved_at_utc", "raw_sha256")) {
    if (any(phase15_uefa_nl_capture_missing(values[[field]]))) stop("Phase 15 stage capture is missing ", field, call. = FALSE)
  }
  if (any(!grepl("^https://", as.character(values$source_url)))) stop("Phase 15 stage capture source_url must be HTTPS", call. = FALSE)
  if (any(!grepl("^[0-9a-fA-F]{64}$", as.character(values$raw_sha256)))) stop("Phase 15 stage capture raw_sha256 is invalid", call. = FALSE)
  phase15_uefa_nl_parse_utc_timestamp(values$scheduled_at_utc, "scheduled_at_utc")
  phase15_uefa_nl_parse_utc_timestamp(values$retrieved_at_utc, "retrieved_at_utc")
  status <- tolower(trimws(as.character(values$stage_status)))
  if (any(is.na(status) | !status %in% c("official", "completed"))) stop("Phase 15 stage capture may contain only official or completed source rows", call. = FALSE)
  if (any(!grepl("^[0-9a-fA-F]{64}$", as.character(values$row_sha256)))) stop("Phase 15 stage capture requires canonical row hashes", call. = FALSE)
  expected_hashes <- phase15_uefa_nl_capture_row_hash(values)
  if (any(tolower(as.character(values$row_sha256)) != tolower(expected_hashes))) stop("Phase 15 stage capture row hash mismatch", call. = FALSE)
  score_fields <- c("regulation_home_goals", "regulation_away_goals", "extra_time_home_goals", "extra_time_away_goals", "final_home_goals", "final_away_goals")
  completed <- status == "completed"
  score_values <- lapply(score_fields, function(field) phase15_uefa_nl_capture_score(values[[field]], field, allow_missing = TRUE))
  names(score_values) <- score_fields
  if (any(completed)) {
    if (any(phase15_uefa_nl_capture_missing(values$completed_at_utc[completed]))) stop("Completed Phase 15 stage capture rows require completed_at_utc", call. = FALSE)
    phase15_uefa_nl_parse_utc_timestamp(values$completed_at_utc[completed], "completed_at_utc")
    for (field in score_fields) if (any(is.na(score_values[[field]][completed]))) stop("Completed Phase 15 stage capture rows require ", field, call. = FALSE)
    if (any(score_values$final_home_goals[completed] != score_values$regulation_home_goals[completed] + score_values$extra_time_home_goals[completed]) || any(score_values$final_away_goals[completed] != score_values$regulation_away_goals[completed] + score_values$extra_time_away_goals[completed])) stop("Phase 15 stage capture final goals must equal regulation plus extra-time goals", call. = FALSE)
  }
  if (any(!completed & !phase15_uefa_nl_capture_missing(values$completed_at_utc))) stop("Official Phase 15 stage capture rows must not carry completed_at_utc", call. = FALSE)
  for (field in score_fields) if (any(!completed & !phase15_uefa_nl_capture_missing(values[[field]]))) stop("Official Phase 15 stage capture rows must not carry ", field, call. = FALSE)
  shootout_home <- phase15_uefa_nl_capture_score(values$penalty_shootout_home_goals, "penalty_shootout_home_goals")
  shootout_away <- phase15_uefa_nl_capture_score(values$penalty_shootout_away_goals, "penalty_shootout_away_goals")
  if (any(xor(is.na(shootout_home), is.na(shootout_away)))) stop("Phase 15 shootout tallies must be supplied as a pair", call. = FALSE)
  shootout <- !is.na(shootout_home) | !is.na(shootout_away)
  if (any(shootout & (!completed | score_values$final_home_goals != score_values$final_away_goals))) stop("Phase 15 shootout tallies are only valid after a tied completed score", call. = FALSE)
  if (!is.null(manifest)) {
    manifest_row <- manifest[1L, , drop = FALSE]
    if (any(tolower(as.character(values$raw_sha256)) != tolower(as.character(manifest_row$raw_sha256[[1L]])))) stop("Phase 15 stage capture raw hash lineage mismatch", call. = FALSE)
    if (any(as.character(values$source_url) != as.character(manifest_row$source_url[[1L]]))) stop("Phase 15 stage capture source URL lineage mismatch", call. = FALSE)
  }
  invisible(TRUE)
}

phase15_uefa_nl_stage_capture_row_from_list <- function(row, schema) {
  if (!is.list(row)) stop("Phase 15 stage capture JSON row must be an object", call. = FALSE)
  values <- lapply(schema, function(field) {
    value <- row[[field]]
    if (is.null(value) || !length(value)) return(NA_character_)
    if (is.list(value)) value <- value[[1L]]
    if (length(value) > 1L) value <- value[[1L]]
    if (is.na(value)) NA_character_ else as.character(value)
  })
  names(values) <- schema
  as.data.frame(values, stringsAsFactors = FALSE, check.names = FALSE)
}

phase15_uefa_nl_adapt_stage_capture <- function(
    payload,
    raw_bytes = NULL,
    source_url = NULL,
    retrieved_at_utc = NULL,
    source_artifact_id = NULL,
    raw_sha256 = NULL,
    manifest = NULL,
    project_root = ".") {
  phase15_uefa_nl_load_rules(project_root)
  schema <- phase15_uefa_nl_stage_capture_schema()
  if (is.list(payload) && !is.data.frame(payload)) {
    if (!is.null(payload$stage_capture)) payload <- payload$stage_capture
    if (!is.null(payload$capture)) payload <- payload$capture
    if (is.list(payload) && (is.null(names(payload)) || !all(schema %in% names(payload)))) {
      if (!length(payload)) {
        rows <- as.data.frame(setNames(lapply(schema, function(field) character()), schema), stringsAsFactors = FALSE, check.names = FALSE)
      } else {
        rows <- do.call(rbind, lapply(payload, phase15_uefa_nl_stage_capture_row_from_list, schema = schema))
      }
    } else {
      rows <- phase15_uefa_nl_stage_capture_row_from_list(payload, schema)
    }
  } else if (is.data.frame(payload)) {
    rows <- as.data.frame(payload, stringsAsFactors = FALSE, check.names = FALSE)
  } else {
    stop("Phase 15 stage capture payload must be a data frame or JSON object list", call. = FALSE)
  }
  if (!nrow(rows)) {
    rows <- rows[, schema, drop = FALSE]
    if (!is.null(manifest)) phase15_uefa_nl_validate_stage_capture(rows, manifest = manifest, project_root = project_root)
    return(list(stage_capture = rows, capture = rows, capture_status = "empty", manifest = manifest, raw_sha256 = if (is.null(raw_bytes)) NA_character_ else phase15_uefa_nl_capture_hash(raw_bytes)))
  }
  for (field in schema) if (!field %in% names(rows)) rows[[field]] <- NA_character_
  rows <- rows[, unique(c(schema, setdiff(names(rows), schema))), drop = FALSE]
  if (!is.null(source_url)) rows$source_url[phase15_uefa_nl_capture_missing(rows$source_url)] <- as.character(source_url)
  if (!is.null(retrieved_at_utc)) rows$retrieved_at_utc[phase15_uefa_nl_capture_missing(rows$retrieved_at_utc)] <- as.character(retrieved_at_utc)
  if (!is.null(source_artifact_id)) rows$source_artifact_id[phase15_uefa_nl_capture_missing(rows$source_artifact_id)] <- as.character(source_artifact_id)
  raw_hash <- raw_sha256 %||% if (is.null(raw_bytes)) NULL else phase15_uefa_nl_capture_hash(raw_bytes)
  if (!is.null(raw_hash)) rows$raw_sha256[phase15_uefa_nl_capture_missing(rows$raw_sha256)] <- as.character(raw_hash)
  rows <- rows[order(as.character(rows$stage_id), as.numeric(as.character(rows$leg_number)), as.character(rows$source_fixture_id), method = "radix"), , drop = FALSE]
  row.names(rows) <- NULL
  if (any(phase15_uefa_nl_capture_missing(rows$row_sha256))) {
    rows$row_sha256 <- phase15_uefa_nl_capture_row_hash(rows[, setdiff(names(rows), "row_sha256"), drop = FALSE])
  }
  phase15_uefa_nl_validate_stage_capture(rows, manifest = manifest, project_root = project_root)
  list(
    stage_capture = rows,
    capture = rows,
    capture_status = "accepted",
    manifest = manifest,
    raw_sha256 = if (is.null(raw_bytes)) NA_character_ else phase15_uefa_nl_capture_hash(raw_bytes),
    capture_content_sha256 = phase15_uefa_nl_capture_canonical_hash(rows, key = "source_fixture_id")
  )
}

phase15_uefa_nl_read_stage_capture <- function(
    project_root = ".",
    capture_id = phase15_uefa_nl_stage_capture_id()) {
  paths <- phase15_uefa_nl_stage_capture_paths(project_root = project_root, capture_id = capture_id)
  required_paths <- c(paths$raw_path, paths$capture_path, paths$manifest_path, paths$registry_path)
  if (any(!file.exists(required_paths))) stop("Registered Phase 15 stage capture path is missing", call. = FALSE)
  registry <- utils::read.csv(paths$registry_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  required <- phase15_uefa_nl_stage_capture_manifest_schema()
  missing <- setdiff(required, names(registry))
  if (length(missing)) stop("Phase 15 stage capture registry is missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  registry_rows <- registry[as.character(registry$capture_id) == as.character(capture_id), , drop = FALSE]
  if (nrow(registry_rows) != 1L) stop("Phase 15 stage capture is missing a unique registry row", call. = FALSE)
  manifest <- utils::read.csv(paths$manifest_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  phase15_uefa_nl_validate_stage_capture_manifest(manifest, paths = paths, project_root = project_root)
  registry_row <- registry_rows[1L, required, drop = FALSE]
  if (!identical(as.character(registry_row$manifest_sha256), as.character(manifest$manifest_sha256)) || !identical(as.character(registry_row$row_sha256), as.character(manifest$row_sha256))) stop("Phase 15 stage capture registry does not match its companion manifest", call. = FALSE)
  raw_bytes <- readBin(paths$raw_path, what = "raw", n = file.info(paths$raw_path)$size)
  raw_hash <- phase15_uefa_nl_capture_hash(raw_bytes)
  if (!identical(tolower(raw_hash), tolower(as.character(manifest$raw_sha256[[1L]])))) stop("Phase 15 stage capture raw hash mismatch", call. = FALSE)
  capture_bytes <- readBin(paths$capture_path, what = "raw", n = file.info(paths$capture_path)$size)
  capture_hash <- phase15_uefa_nl_capture_hash(capture_bytes)
  if (!identical(tolower(capture_hash), tolower(as.character(manifest$capture_content_sha256[[1L]])))) stop("Phase 15 stage capture content hash mismatch", call. = FALSE)
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("jsonlite is required to read the Phase 15 stage capture", call. = FALSE)
  jsonlite::validate(rawToChar(raw_bytes))
  raw_payload <- jsonlite::fromJSON(rawToChar(raw_bytes), simplifyVector = FALSE)
  capture <- utils::read.csv(paths$capture_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  phase15_uefa_nl_validate_stage_capture(capture, manifest = manifest, project_root = project_root)
  if (identical(as.character(manifest$capture_status[[1L]]), "empty") && length(raw_payload)) stop("Registered empty Phase 15 stage capture raw payload is not empty", call. = FALSE)
  if (identical(as.character(manifest$capture_status[[1L]]), "accepted") && length(raw_payload) != nrow(capture)) stop("Registered Phase 15 stage capture raw row count does not match accepted rows", call. = FALSE)
  list(
    stage_capture = capture,
    capture = capture,
    capture_status = as.character(manifest$capture_status[[1L]]),
    manifest = manifest,
    registry = registry_row,
    paths = paths,
    raw_sha256 = raw_hash,
    capture_content_sha256 = capture_hash
  )
}
