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
