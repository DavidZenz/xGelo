#' ClubElo rating-source adapter.
#'
#' ClubElo is used as calculation-only evidence.  This module deliberately
#' keeps the provider rows separate from the Phase 19 accepted match corpus:
#' ratings are derived observations and cannot silently become historical
#' match authority or dashboard publication data.

phase19_clubelo_abort <- function(reason_code, message, data = list()) {
  stop(structure(
    c(list(message = as.character(message), call = NULL,
           reason_code = as.character(reason_code)), data),
    class = c("phase19_clubelo_error", "error", "condition")
  ))
}

phase19_clubelo_require_dependencies <- function() {
  required <- c(
    "phase18_canonical_encoding_v2", "phase18_hash_row_v2",
    "phase18_hash_table_v2"
  )
  missing <- required[!vapply(required, exists, logical(1), mode = "function")]
  if (length(missing)) {
    phase19_clubelo_abort(
      "dependency_missing",
      paste0("ClubElo adapter dependencies must be sourced first: ",
             paste(missing, collapse = ", "))
    )
  }
  if (!requireNamespace("digest", quietly = TRUE)) {
    phase19_clubelo_abort("dependency_missing", "digest is required for ClubElo provenance")
  }
  invisible(TRUE)
}

phase19_clubelo_source_columns <- function() {
  c("Rank", "Club", "Elo", "From", "To", "Country", "Level")
}

phase19_clubelo_normalized_columns <- function() {
  c(
    "schema_version", "hash_encoding_version", "source_kind", "source_url",
    "requested_as_of_date", "retrieved_at_utc", "clubelo_rank", "clubelo_club",
    "clubelo_elo", "valid_from", "valid_to", "country", "level",
    "source_raw_sha256", "row_sha256"
  )
}

phase19_clubelo_base_url <- function() "http://api.clubelo.com"

phase19_clubelo_date <- function(value, field = "date") {
  if (length(value) != 1L || is.na(value) || !nzchar(as.character(value)) ||
      !grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", as.character(value))) {
    phase19_clubelo_abort("invalid_request", paste0(field, " must be YYYY-MM-DD"))
  }
  parsed <- as.Date(as.character(value), format = "%Y-%m-%d")
  if (is.na(parsed) || format(parsed, "%Y-%m-%d") != as.character(value)) {
    phase19_clubelo_abort("invalid_request", paste0(field, " is not a valid calendar date"))
  }
  as.character(value)
}

phase19_clubelo_slug <- function(value) {
  value <- enc2utf8(as.character(value))
  if (length(value) != 1L || is.na(value) || !nzchar(value) ||
      !grepl("^[A-Za-z0-9-]+$", value)) {
    phase19_clubelo_abort(
      "invalid_request",
      "ClubElo history keys must be explicit ASCII slugs without path separators"
    )
  }
  value
}

phase19_clubelo_request_plan <- function(date = NULL, clubs = character()) {
  phase19_clubelo_require_dependencies()
  rows <- list()
  if (!is.null(date)) {
    date <- phase19_clubelo_date(date, "date")
    rows[[length(rows) + 1L]] <- data.frame(
      request_id = paste0("snapshot_", date), source_kind = "snapshot",
      requested_as_of_date = date, clubelo_key = "",
      url = paste0(phase19_clubelo_base_url(), "/", date),
      stringsAsFactors = FALSE, check.names = FALSE
    )
  }
  clubs <- as.character(clubs)
  if (length(clubs)) {
    if (anyDuplicated(clubs)) {
      phase19_clubelo_abort("invalid_request", "ClubElo history keys must be unique")
    }
    for (club in clubs) {
      slug <- phase19_clubelo_slug(club)
      rows[[length(rows) + 1L]] <- data.frame(
        request_id = paste0("history_", slug), source_kind = "history",
        requested_as_of_date = "", clubelo_key = slug,
        url = paste0(phase19_clubelo_base_url(), "/", slug),
        stringsAsFactors = FALSE, check.names = FALSE
      )
    }
  }
  if (!length(rows)) {
    phase19_clubelo_abort("invalid_request", "At least one snapshot date or history key is required")
  }
  plan <- do.call(rbind, rows)
  rownames(plan) <- NULL
  phase19_clubelo_validate_request_plan(plan)
  plan
}

phase19_clubelo_validate_request_plan <- function(plan) {
  required <- c("request_id", "source_kind", "requested_as_of_date", "clubelo_key", "url")
  if (!is.data.frame(plan) || !identical(names(plan), required) || !nrow(plan) ||
      anyDuplicated(as.character(plan$request_id))) {
    phase19_clubelo_abort("invalid_request", "ClubElo request plan schema is invalid")
  }
  if (any(!as.character(plan$source_kind) %in% c("snapshot", "history"))) {
    phase19_clubelo_abort("invalid_request", "ClubElo source_kind is outside the closed vocabulary")
  }
  for (index in seq_len(nrow(plan))) {
    kind <- as.character(plan$source_kind[[index]])
    url <- as.character(plan$url[[index]])
    if (identical(kind, "snapshot")) {
      date <- phase19_clubelo_date(plan$requested_as_of_date[[index]], "requested_as_of_date")
      expected <- paste0(phase19_clubelo_base_url(), "/", date)
      if (!identical(as.character(plan$clubelo_key[[index]]), "") || !identical(url, expected)) {
        phase19_clubelo_abort("invalid_request", "Snapshot request is outside the fixed ClubElo URL shape")
      }
    } else {
      slug <- phase19_clubelo_slug(plan$clubelo_key[[index]])
      if (!identical(as.character(plan$requested_as_of_date[[index]]), "") ||
          !identical(url, paste0(phase19_clubelo_base_url(), "/", slug))) {
        phase19_clubelo_abort("invalid_request", "History request is outside the fixed ClubElo URL shape")
      }
    }
    if (!identical(as.character(plan$request_id[[index]]),
                   if (identical(kind, "snapshot")) {
                     paste0("snapshot_", plan$requested_as_of_date[[index]])
                   } else paste0("history_", plan$clubelo_key[[index]]))) {
      phase19_clubelo_abort("invalid_request", "ClubElo request_id does not bind the request URL")
    }
  }
  invisible(TRUE)
}

phase19_clubelo_live_performer <- function() {
  function(request) {
    phase19_clubelo_validate_request_plan(request[1L, , drop = FALSE])
    response <- tryCatch({
      req <- httr2::request(as.character(request$url[[1L]]))
      req <- httr2::req_user_agent(req, "xGelo/clubelo-calculation-adapter")
      req <- httr2::req_timeout(req, 20)
      httr2::req_error(req, is_error = function(resp) FALSE) |>
        httr2::req_perform()
    }, error = function(error) {
      phase19_clubelo_abort("blocked_transport", "ClubElo request failed")
    })
    content_type <- httr2::resp_header(response, "content-type")
    if (is.null(content_type) || !length(content_type)) content_type <- ""
    list(
      status = httr2::resp_status(response),
      content_type = as.character(content_type[[1L]]),
      final_url = httr2::resp_url(response),
      body = httr2::resp_body_raw(response)
    )
  }
}

phase19_clubelo_response_header <- function(response, name) {
  value <- response[[name]]
  if (is.null(value) || !length(value)) "" else as.character(value[[1L]])
}

phase19_clubelo_validate_response <- function(response, request, max_bytes = 5L * 1024L * 1024L) {
  if (!is.list(response)) phase19_clubelo_abort("blocked_transport", "ClubElo performer must return a response list")
  status <- suppressWarnings(as.integer(response$status[[1L]]))
  if (length(status) != 1L || is.na(status) || status != 200L) {
    phase19_clubelo_abort("blocked_http_status", paste0("ClubElo returned HTTP ", ifelse(is.na(status), "unknown", status)))
  }
  content_type <- tolower(phase19_clubelo_response_header(response, "content_type"))
  if (!grepl("^(text/(csv|plain)|application/(csv|octet-stream))(;|$)", content_type)) {
    phase19_clubelo_abort("blocked_content_type", "ClubElo response is not a CSV/text resource")
  }
  final_url <- as.character(response$final_url[[1L]])
  requested_url <- as.character(request$url[[1L]])
  allowed_urls <- c(requested_url, sub("^http://", "https://", requested_url))
  if (!final_url %in% allowed_urls) {
    phase19_clubelo_abort("blocked_redirect_host", "ClubElo response left the fixed request URL")
  }
  body <- response$body
  if (!is.raw(body) || !length(body)) phase19_clubelo_abort("blocked_empty_resource", "ClubElo response body is empty")
  if (length(body) > max_bytes) phase19_clubelo_abort("blocked_byte_limit", "ClubElo response exceeds the byte limit")
  body
}

phase19_clubelo_parse_csv <- function(body, request, retrieved_at_utc,
                                      max_rows = 100000L) {
  phase19_clubelo_require_dependencies()
  if (!is.raw(body) || !length(body)) phase19_clubelo_abort("blocked_empty_resource", "ClubElo CSV bytes are empty")
  text <- tryCatch(rawToChar(body), error = function(error) {
    phase19_clubelo_abort("blocked_encoding", "ClubElo CSV is not valid text")
  })
  raw_table <- tryCatch(
    utils::read.csv(text = text, stringsAsFactors = FALSE, check.names = FALSE,
                    na.strings = c("", "None", "NA")),
    error = function(error) phase19_clubelo_abort("blocked_schema", "ClubElo CSV could not be parsed")
  )
  expected <- phase19_clubelo_source_columns()
  if (!identical(names(raw_table), expected)) {
    phase19_clubelo_abort(
      "blocked_schema",
      paste0("ClubElo CSV columns must be exactly: ", paste(expected, collapse = ", "))
    )
  }
  if (!nrow(raw_table) || nrow(raw_table) > max_rows) {
    phase19_clubelo_abort("blocked_cardinality", "ClubElo CSV row count is outside the accepted range")
  }
  blank_to_empty <- function(value) {
    value <- as.character(value)
    value[is.na(value)] <- ""
    trimws(value)
  }
  rank <- blank_to_empty(raw_table$Rank)
  club <- blank_to_empty(raw_table$Club)
  elo_text <- blank_to_empty(raw_table$Elo)
  from <- blank_to_empty(raw_table$From)
  to <- blank_to_empty(raw_table$To)
  country <- blank_to_empty(raw_table$Country)
  level <- blank_to_empty(raw_table$Level)
  if (any(!nzchar(club)) || any(!nzchar(elo_text)) || any(!nzchar(from))) {
    phase19_clubelo_abort("blocked_schema", "ClubElo rows require club, Elo, and From values")
  }
  elo <- suppressWarnings(as.numeric(elo_text))
  if (any(!is.finite(elo)) || any(elo < 500 | elo > 3000)) {
    phase19_clubelo_abort("blocked_schema", "ClubElo Elo values must be finite and plausible")
  }
  rank_numeric <- suppressWarnings(as.numeric(rank))
  if (any(nzchar(rank) & (!is.finite(rank_numeric) | rank_numeric < 1 | rank_numeric != floor(rank_numeric)))) {
    phase19_clubelo_abort("blocked_schema", "ClubElo Rank values must be positive integers when present")
  }
  parse_dates <- function(values, field, allow_blank = TRUE) {
    if (any(!allow_blank & !nzchar(values))) phase19_clubelo_abort("blocked_schema", paste0(field, " is incomplete"))
    parsed <- as.Date(values, format = "%Y-%m-%d")
    if (any(nzchar(values) & (is.na(parsed) | format(parsed, "%Y-%m-%d") != values))) {
      phase19_clubelo_abort("blocked_schema", paste0(field, " contains an invalid date"))
    }
    values
  }
  from <- parse_dates(from, "From", allow_blank = FALSE)
  to <- parse_dates(to, "To", allow_blank = TRUE)
  from_date <- as.Date(from)
  to_date <- as.Date(ifelse(nzchar(to), to, NA_character_))
  if (any(!is.na(to_date) & to_date < from_date)) {
    phase19_clubelo_abort("blocked_schema", "ClubElo validity intervals run backwards")
  }
  normalized <- data.frame(
    schema_version = "phase19-clubelo-rating-v1",
    hash_encoding_version = phase18_canonical_encoding_v2(),
    source_kind = as.character(request$source_kind[[1L]]),
    source_url = as.character(request$url[[1L]]),
    requested_as_of_date = as.character(request$requested_as_of_date[[1L]]),
    retrieved_at_utc = as.character(retrieved_at_utc),
    clubelo_rank = ifelse(nzchar(rank), as.integer(rank_numeric), NA_integer_),
    clubelo_club = club, clubelo_elo = as.numeric(elo),
    valid_from = from, valid_to = to, country = country, level = level,
    source_raw_sha256 = digest::digest(body, algo = "sha256", serialize = FALSE),
    row_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE
  )
  normalized$row_sha256 <- vapply(seq_len(nrow(normalized)), function(index) {
    phase18_hash_row_v2(
      normalized[index, , drop = FALSE],
      exclude = c("row_sha256", "source_raw_sha256"),
      schema_tag = "phase19-clubelo-rating-row-v1"
    )
  }, character(1))
  key <- c("clubelo_club", "valid_from", "valid_to")
  if (anyDuplicated(normalized[key])) {
    phase19_clubelo_abort("blocked_duplicate_id", "ClubElo contains duplicate club validity rows")
  }
  normalized <- normalized[do.call(order, lapply(normalized[key], as.character)), , drop = FALSE]
  rownames(normalized) <- NULL
  hash_table <- normalized
  hash_table$source_raw_sha256 <- NULL
  hash_table$valid_to_key <- ifelse(nzchar(hash_table$valid_to), hash_table$valid_to, "open")
  table_hash <- phase18_hash_table_v2(
    hash_table, key = c("clubelo_club", "valid_from", "valid_to_key"),
    schema_tag = "phase19-clubelo-rating-table-v1"
  )
  list(
    schema_version = "phase19-clubelo-snapshot-v1",
    hash_encoding_version = phase18_canonical_encoding_v2(),
    source_kind = as.character(request$source_kind[[1L]]),
    source_url = as.character(request$url[[1L]]),
    requested_as_of_date = as.character(request$requested_as_of_date[[1L]]),
    retrieved_at_utc = as.character(retrieved_at_utc),
    raw_sha256 = digest::digest(body, algo = "sha256", serialize = FALSE),
    table_sha256 = table_hash, row_count = as.integer(nrow(normalized)),
    ratings = normalized
  )
}

phase19_clubelo_fetch <- function(request_plan, perform_request,
                                  clock_fn = Sys.time,
                                  max_bytes = 5L * 1024L * 1024L) {
  phase19_clubelo_require_dependencies()
  phase19_clubelo_validate_request_plan(request_plan)
  if (!is.function(perform_request) || !is.function(clock_fn)) {
    phase19_clubelo_abort("blocked_transport", "ClubElo performer and clock must be functions")
  }
  output <- vector("list", nrow(request_plan))
  names(output) <- as.character(request_plan$request_id)
  for (index in seq_len(nrow(request_plan))) {
    request <- request_plan[index, , drop = FALSE]
    response <- tryCatch(perform_request(request), error = function(error) {
      if (inherits(error, "phase19_clubelo_error")) stop(error)
      phase19_clubelo_abort("blocked_transport", "ClubElo request failed")
    })
    body <- phase19_clubelo_validate_response(response, request, max_bytes)
    retrieved <- format(as.POSIXct(clock_fn(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    output[[index]] <- phase19_clubelo_parse_csv(body, request, retrieved)
  }
  output
}

phase19_clubelo_select_as_of <- function(snapshot, as_of_date) {
  phase19_clubelo_require_dependencies()
  if (!is.list(snapshot) || !is.data.frame(snapshot$ratings)) {
    phase19_clubelo_abort("invalid_snapshot", "ClubElo snapshot must contain a ratings table")
  }
  as_of_date <- as.Date(phase19_clubelo_date(as_of_date, "as_of_date"))
  ratings <- snapshot$ratings
  starts <- as.Date(ratings$valid_from)
  eligible <- !is.na(starts) & starts <= as_of_date
  if (!any(eligible)) return(ratings[FALSE, , drop = FALSE])
  ratings <- ratings[eligible, , drop = FALSE]
  ratings <- ratings[order(ratings$clubelo_club, as.Date(ratings$valid_from),
                           ratings$row_sha256, method = "radix"), , drop = FALSE]
  selected <- ratings[!duplicated(ratings$clubelo_club, fromLast = TRUE), , drop = FALSE]
  selected <- selected[order(selected$clubelo_club, method = "radix"), , drop = FALSE]
  rownames(selected) <- NULL
  selected
}

phase19_clubelo_prior <- function(snapshot, mapping, as_of_date) {
  phase19_clubelo_require_dependencies()
  if (!is.data.frame(mapping) || !identical(names(mapping), c("club_id", "clubelo_club")) ||
      !nrow(mapping) || anyDuplicated(mapping$club_id) || anyDuplicated(mapping$clubelo_club) ||
      any(!grepl("^club_[a-z0-9][a-z0-9_]*$", as.character(mapping$club_id))) ||
      any(!nzchar(as.character(mapping$clubelo_club)))) {
    phase19_clubelo_abort("invalid_mapping", "ClubElo mapping must be a one-to-one club_id/name table")
  }
  selected <- phase19_clubelo_select_as_of(snapshot, as_of_date)
  index <- match(as.character(mapping$clubelo_club), as.character(selected$clubelo_club))
  if (anyNA(index)) {
    missing <- mapping$clubelo_club[is.na(index)]
    phase19_clubelo_abort(
      "unresolved_club", paste0("ClubElo mapping has no rating for: ", paste(missing, collapse = ", "))
    )
  }
  result <- data.frame(
    club_id = as.character(mapping$club_id),
    clubelo_club = as.character(mapping$clubelo_club),
    rating = as.numeric(selected$clubelo_elo[index]),
    rating_date = as.character(selected$valid_from[index]),
    source_url = as.character(selected$source_url[index]),
    source_table_sha256 = as.character(snapshot$table_sha256),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  result <- result[order(result$club_id, method = "radix"), , drop = FALSE]
  rownames(result) <- NULL
  result$prior_sha256 <- phase18_hash_table_v2(
    result, key = "club_id", schema_tag = "phase19-clubelo-prior-v1"
  )
  result
}

phase19_clubelo_rating_features <- function(prior, fixtures, home_advantage = 60) {
  required_prior <- c("club_id", "rating", "source_table_sha256", "prior_sha256")
  required_fixtures <- c("fixture_id", "home_club_id", "away_club_id")
  if (!is.data.frame(prior) || length(setdiff(required_prior, names(prior))) ||
      !nrow(prior) || anyDuplicated(as.character(prior$club_id)) ||
      any(!grepl("^club_[a-z0-9][a-z0-9_]*$", as.character(prior$club_id)))) {
    phase19_clubelo_abort("invalid_prior", "ClubElo prior is incomplete or not club-domain")
  }
  if (!is.data.frame(fixtures) || length(setdiff(required_fixtures, names(fixtures))) ||
      !nrow(fixtures) || anyDuplicated(as.character(fixtures$fixture_id))) {
    phase19_clubelo_abort("invalid_fixture", "ClubElo feature fixtures are incomplete or duplicated")
  }
  home_advantage <- suppressWarnings(as.numeric(home_advantage))
  if (length(home_advantage) != 1L || !is.finite(home_advantage) || home_advantage < 0) {
    phase19_clubelo_abort("invalid_parameters", "ClubElo home_advantage must be one non-negative number")
  }
  home_index <- match(as.character(fixtures$home_club_id), as.character(prior$club_id))
  away_index <- match(as.character(fixtures$away_club_id), as.character(prior$club_id))
  if (anyNA(home_index) || anyNA(away_index)) {
    phase19_clubelo_abort("unresolved_club", "ClubElo fixtures contain an unmapped club")
  }
  data.frame(
    fixture_id = as.character(fixtures$fixture_id),
    home_club_id = as.character(fixtures$home_club_id),
    away_club_id = as.character(fixtures$away_club_id),
    home_clubelo_rating = as.numeric(prior$rating[home_index]),
    away_clubelo_rating = as.numeric(prior$rating[away_index]),
    clubelo_rating_difference = as.numeric(prior$rating[home_index]) + home_advantage -
      as.numeric(prior$rating[away_index]),
    clubelo_source_table_sha256 = as.character(prior$source_table_sha256[home_index]),
    clubelo_prior_sha256 = as.character(prior$prior_sha256[home_index]),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}
