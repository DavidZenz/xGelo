#' Point-in-time descriptive form contracts for Phase 14.
#'
#' Display form is deliberately kept separate from the optional national-team
#' xG model form.  This file contains the shared row normalization and
#' deterministic lineage helpers used by both products.

phase14_form_clean_text <- function(values) {
  values <- as.character(values)
  values[is.na(values) | !nzchar(trimws(values))] <- NA_character_
  trimws(values)
}

phase14_form_pick <- function(data, index, columns, default = NA_character_) {
  for (column in as.character(columns)) {
    if (!column %in% names(data)) next
    value <- data[[column]][[index]]
    if (length(value) == 0L || is.null(value) || is.na(value)) next
    value <- as.character(value[[1L]])
    if (nzchar(trimws(value)) && !identical(toupper(value), "NA")) return(value)
  }
  default
}

phase14_form_first_column <- function(data, columns, default = NA_character_) {
  output <- rep(default, nrow(data))
  for (column in as.character(columns)) {
    if (!column %in% names(data)) next
    values <- as.character(data[[column]])
    present <- !is.na(values) & nzchar(trimws(values)) & toupper(values) != "NA"
    replace <- present & (is.na(output) | !nzchar(trimws(as.character(output))))
    output[replace] <- values[replace]
  }
  output
}

phase14_form_bool <- function(value, default = NA) {
  if (length(value) == 0L || is.null(value) || is.na(value)) return(default)
  if (is.logical(value)) return(isTRUE(value[[1L]]))
  value <- tolower(trimws(as.character(value[[1L]])))
  if (!nzchar(value) || value == "na") return(default)
  if (value %in% c("true", "t", "1", "yes", "y")) return(TRUE)
  if (value %in% c("false", "f", "0", "no", "n")) return(FALSE)
  stop("Phase 14 form logical field has unsupported value: ", value, call. = FALSE)
}

phase14_form_number <- function(value) {
  if (length(value) == 0L || is.null(value) || is.na(value)) return(NA_real_)
  parsed <- suppressWarnings(as.numeric(as.character(value[[1L]])))
  if (!length(parsed) || !is.finite(parsed)) return(NA_real_)
  parsed
}

phase14_form_timestamp <- function(value, field = "timestamp") {
  if (length(value) == 0L || is.null(value) || is.na(value)) return(NA_character_)
  value <- trimws(as.character(value[[1L]]))
  if (!nzchar(value) || identical(toupper(value), "NA")) return(NA_character_)
  parsed <- suppressWarnings(as.POSIXct(value, format = "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC"))
  if (is.na(parsed)) parsed <- suppressWarnings(as.POSIXct(value, tz = "UTC"))
  if (is.na(parsed)) stop("Phase 14 form ", field, " is not a valid UTC timestamp", call. = FALSE)
  format(parsed, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

phase14_form_date <- function(value, field = "date") {
  if (length(value) == 0L || is.null(value) || is.na(value)) return(NA_character_)
  value <- trimws(as.character(value[[1L]]))
  if (!nzchar(value) || identical(toupper(value), "NA")) return(NA_character_)
  parsed <- suppressWarnings(as.Date(substr(value, 1L, 10L)))
  if (is.na(parsed)) stop("Phase 14 form ", field, " is not a valid ISO date", call. = FALSE)
  format(parsed, "%Y-%m-%d")
}

phase14_form_cutoff <- function(value) {
  text <- phase14_form_timestamp(value, "feature_cutoff_utc")
  parsed <- as.POSIXct(text, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  list(
    text = text,
    instant = parsed,
    date = as.Date(parsed, tz = "UTC")
  )
}

phase14_form_digest <- function(value) {
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("digest is required for Phase 14 form hashes", call. = FALSE)
  }
  digest::digest(enc2utf8(paste(as.character(value), collapse = "\x1f")), algo = "sha256", serialize = FALSE)
}

phase14_form_canonical_scalar <- function(value) {
  if (inherits(value, "POSIXt")) return(format(value, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  if (inherits(value, "Date")) return(format(value, "%Y-%m-%d"))
  if (is.logical(value)) return(ifelse(is.na(value), "<NA>", ifelse(value, "TRUE", "FALSE")))
  if (length(value) == 0L || is.null(value) || is.na(value[[1L]])) return("<NA>")
  trimws(as.character(value[[1L]]))
}

phase14_form_hash_payload <- function(data) {
  fields <- setdiff(names(data), c("row_sha256", "table_sha256", "canonical_row_sha256", "canonical_table_sha256"))
  if (!length(fields)) return("")
  rows <- vapply(seq_len(nrow(data)), function(index) {
    paste(vapply(data[index, fields, drop = FALSE], phase14_form_canonical_scalar, character(1)), collapse = "\x1f")
  }, character(1))
  paste(c(paste(fields, collapse = "\x1f"), rows), collapse = "\x1e")
}

phase14_form_add_hashes <- function(data) {
  if (!nrow(data)) {
    data$row_sha256 <- character(0)
    data$canonical_row_sha256 <- character(0)
    data$table_sha256 <- character(0)
    data$canonical_table_sha256 <- character(0)
    return(data)
  }
  data$row_sha256 <- vapply(seq_len(nrow(data)), function(index) {
    phase14_form_digest(phase14_form_hash_payload(data[index, , drop = FALSE]))
  }, character(1))
  data$canonical_row_sha256 <- data$row_sha256
  table_hash <- phase14_form_digest(phase14_form_hash_payload(data))
  data$table_sha256 <- rep(table_hash, nrow(data))
  data$canonical_table_sha256 <- data$table_sha256
  data
}

phase14_form_scope <- function(value) {
  value <- tolower(trimws(as.character(value[[1L]])))
  if (value %in% c("competition", "competition_specific", "competition_last_five")) {
    return("competition")
  }
  if (value %in% c("all_senior", "all_senior_international", "all_senior_last_five")) {
    return("all_senior_international")
  }
  stop("Phase 14 form scope must be competition or all_senior_international", call. = FALSE)
}

phase14_form_infer_senior_mens_a <- function(data, index) {
  explicit <- phase14_form_pick(data, index, c("is_senior_mens_a", "senior_mens_a"))
  if (!is.na(explicit)) return(phase14_form_bool(explicit, default = FALSE))
  tournament <- tolower(phase14_form_pick(data, index, c("tournament", "competition_name", "competition"), ""))
  if (grepl("women|female|girls|youth|under[ _-]?[0-9]|(^|[^a-z])u[0-9]{2}([^0-9]|$)|futsal|beach|reserve|club", tournament)) {
    return(FALSE)
  }
  # Olympic football and youth games are not senior men's A internationals.
  if (grepl("olympic|asian games|south pacific games|southeast asian games", tournament)) return(FALSE)
  TRUE
}

phase14_form_competition_type <- function(data, index) {
  explicit <- phase14_form_pick(data, index, c("competition_type"))
  if (is.na(explicit)) {
    explicit <- phase14_form_pick(data, index, c("tournament", "competition_name", "competition"), "competition")
  }
  normalized <- tolower(trimws(explicit))
  if (grepl("friendly", normalized)) "friendly" else "competition"
}

phase14_form_source_family <- function(data, index) {
  explicit <- tolower(phase14_form_pick(data, index, c("source_family"), ""))
  namespace <- tolower(phase14_form_pick(data, index, c("source_namespace", "source_dataset", "source"), ""))
  if (explicit %in% c("competition", "historical")) return(explicit)
  if (grepl("competition|uefa|accepted", namespace)) return("competition")
  if (grepl("historical|martj42", namespace)) return("historical")
  "unknown"
}

phase14_form_source_id <- function(data, index) {
  phase14_form_pick(
    data,
    index,
    c("source_id", "source_artifact_id", "source_result_id", "source_match_id", "source_fixture_id", "source_namespace", "source_dataset"),
    NA_character_
  )
}

phase14_form_source_lineage <- function(data, index, source_id) {
  value <- phase14_form_pick(
    data,
    index,
    c("source_lineage_id", "source_artifact_id", "source_result_id", "source_match_id", "source_fixture_id"),
    source_id
  )
  if (is.na(value)) source_id else value
}

phase14_form_match_id <- function(data, index) {
  value <- phase14_form_pick(
    data,
    index,
    c("canonical_match_id", "match_id", "source_match_id", "source_result_id", "source_fixture_id", "fixture_id", "source_id"),
    NA_character_
  )
  if (is.na(value)) stop("Phase 14 form requires a stable match_id", call. = FALSE)
  value
}

phase14_form_source_hash <- function(data, index) {
  value <- phase14_form_pick(
    data,
    index,
    c("row_sha256", "source_row_sha256", "canonical_row_sha256", "source_hash", "match_hash"),
    NA_character_
  )
  if (is.na(value)) {
    values <- vapply(data[index, , drop = FALSE], phase14_form_canonical_scalar, character(1))
    value <- phase14_form_digest(c(names(data[index, , drop = FALSE]), values))
  }
  value
}

phase14_form_evidence <- function(data, index) {
  timestamp <- phase14_form_pick(
    data,
    index,
    c("evidence_completed_at_utc", "completed_at_utc", "evidence_time_utc", "evidence_timestamp_utc", "evidence_at_utc", "updated_at_utc"),
    NA_character_
  )
  timestamp <- if (is.na(timestamp)) NA_character_ else phase14_form_timestamp(timestamp, "evidence_completed_at_utc")
  evidence_date <- phase14_form_pick(
    data,
    index,
    c("evidence_date", "match_date", "date"),
    NA_character_
  )
  evidence_date <- if (is.na(evidence_date) && !is.na(timestamp)) substr(timestamp, 1L, 10L) else
    if (is.na(evidence_date)) NA_character_ else phase14_form_date(evidence_date, "evidence_date")
  precision <- tolower(phase14_form_pick(data, index, c("evidence_precision"), ""))
  if (!precision %in% c("timestamp", "date", "missing")) {
    precision <- if (!is.na(timestamp)) "timestamp" else if (!is.na(evidence_date)) "date" else "missing"
  }
  list(timestamp = timestamp, date = evidence_date, precision = precision)
}

phase14_form_timestamp_vector <- function(values, field = "timestamp") {
  values <- phase14_form_clean_text(values)
  output <- rep(NA_character_, length(values))
  present <- !is.na(values)
  if (!any(present)) return(output)
  parsed <- suppressWarnings(as.POSIXct(values[present], format = "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC"))
  fallback <- is.na(parsed)
  if (any(fallback)) parsed[fallback] <- suppressWarnings(as.POSIXct(values[present][fallback], tz = "UTC"))
  if (any(is.na(parsed))) stop("Phase 14 form ", field, " contains an invalid UTC timestamp", call. = FALSE)
  output[present] <- format(parsed, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  output
}

phase14_form_date_vector <- function(values, field = "date") {
  values <- phase14_form_clean_text(values)
  output <- rep(NA_character_, length(values))
  present <- !is.na(values)
  if (!any(present)) return(output)
  parsed <- suppressWarnings(as.Date(substr(values[present], 1L, 10L)))
  if (any(is.na(parsed))) stop("Phase 14 form ", field, " contains an invalid ISO date", call. = FALSE)
  output[present] <- format(parsed, "%Y-%m-%d")
  output
}

phase14_form_number_vector <- function(data, columns, default = NA_real_) {
  values <- phase14_form_first_column(data, columns, default = NA_character_)
  parsed <- suppressWarnings(as.numeric(values))
  parsed[!is.finite(parsed)] <- NA_real_
  parsed
}

phase14_form_bool_vector <- function(values, default = NA) {
  text <- tolower(phase14_form_clean_text(values))
  output <- rep(default, length(text))
  output[text %in% c("true", "t", "1", "yes", "y")] <- TRUE
  output[text %in% c("false", "f", "0", "no", "n")] <- FALSE
  invalid <- !is.na(text) & !(text %in% c("true", "t", "1", "yes", "y", "false", "f", "0", "no", "n"))
  if (any(invalid)) stop("Phase 14 form logical field has unsupported value: ", text[which(invalid)[[1L]]], call. = FALSE)
  output
}

phase14_form_normalize_wide_fast <- function(matches) {
  n <- nrow(matches)
  home <- phase14_form_first_column(matches, c("home_team_id", "home_source_team_id", "home_fifa_code", "home_team"))
  away <- phase14_form_first_column(matches, c("away_team_id", "away_source_team_id", "away_fifa_code", "away_team"))
  if (any(is.na(home) | is.na(away))) stop("Phase 14 form wide rows require home and away team IDs", call. = FALSE)
  match_id <- phase14_form_first_column(matches, c("canonical_match_id", "match_id", "source_match_id", "source_result_id", "source_fixture_id", "fixture_id", "source_id"))
  if (any(is.na(match_id))) stop("Phase 14 form requires a stable match_id", call. = FALSE)

  home_goals <- phase14_form_number_vector(matches, c("final_home_goals", "football_home_goals", "home_goals", "home_score"))
  away_goals <- phase14_form_number_vector(matches, c("final_away_goals", "football_away_goals", "away_goals", "away_score"))
  score_present <- is.finite(home_goals) & is.finite(away_goals)
  completion <- tolower(phase14_form_first_column(matches, c("completion_method", "completion_status")))
  status <- tolower(phase14_form_first_column(matches, c("match_status", "status")))
  explicit_counts <- phase14_form_bool_vector(phase14_form_first_column(matches, c("counts_for_form")))
  derived_counts <- score_present &
    !(completion %in% c("awarded", "purely_awarded", "not_applicable", "postponed", "abandoned")) &
    !(status %in% c("scheduled", "postponed", "abandoned", "cancelled", "canceled", "unplayed"))
  counts <- explicit_counts
  counts[is.na(counts)] <- derived_counts[is.na(counts)]
  counts[completion %in% c("awarded", "purely_awarded")] <- FALSE
  counts[status %in% c("scheduled", "postponed", "abandoned", "cancelled", "canceled", "unplayed")] <- FALSE

  senior_text <- phase14_form_first_column(matches, c("is_senior_mens_a", "senior_mens_a"))
  senior <- phase14_form_bool_vector(senior_text)
  missing_senior <- is.na(senior)
  tournament <- tolower(phase14_form_first_column(matches, c("tournament", "competition_name", "competition"), ""))
  inferred_senior <- !grepl("women|female|girls|youth|under[ _-]?[0-9]|(^|[^a-z])u[0-9]{2}([^0-9]|$)|futsal|beach|reserve|club|olympic|asian games|south pacific games|southeast asian games", tournament)
  senior[missing_senior] <- inferred_senior[missing_senior]

  competition_text <- phase14_form_first_column(matches, c("competition_type"), NA_character_)
  missing_competition <- is.na(competition_text)
  competition_text[missing_competition] <- tournament[missing_competition]
  competition_type <- ifelse(grepl("friendly", tolower(competition_text)), "friendly", "competition")

  evidence_timestamp <- phase14_form_timestamp_vector(
    phase14_form_first_column(matches, c("evidence_completed_at_utc", "completed_at_utc", "evidence_time_utc", "evidence_timestamp_utc", "evidence_at_utc", "updated_at_utc")),
    "evidence_completed_at_utc"
  )
  evidence_date <- phase14_form_date_vector(
    phase14_form_first_column(matches, c("evidence_date", "match_date", "date")),
    "evidence_date"
  )
  missing_date <- is.na(evidence_date) & !is.na(evidence_timestamp)
  evidence_date[missing_date] <- substr(evidence_timestamp[missing_date], 1L, 10L)
  precision <- tolower(phase14_form_first_column(matches, c("evidence_precision"), NA_character_))
  precision[is.na(precision)] <- ifelse(!is.na(evidence_timestamp[is.na(precision)]), "timestamp", ifelse(!is.na(evidence_date[is.na(precision)]), "date", "missing"))
  invalid_precision <- !precision %in% c("timestamp", "date", "missing")
  if (any(invalid_precision)) stop("Phase 14 form evidence_precision contains an unsupported value", call. = FALSE)

  source_id <- phase14_form_first_column(matches, c("source_id", "source_artifact_id", "source_result_id", "source_match_id", "source_fixture_id", "source_namespace", "source_dataset"))
  source_hash <- phase14_form_first_column(matches, c("row_sha256", "source_row_sha256", "canonical_row_sha256", "source_hash", "match_hash"))
  missing_hash <- is.na(source_hash)
  if (any(missing_hash)) {
    source_hash[missing_hash] <- vapply(which(missing_hash), function(index) phase14_form_source_hash(matches, index), character(1))
  }
  source_lineage <- phase14_form_first_column(matches, c("source_lineage_id", "source_artifact_id", "source_result_id", "source_match_id", "source_fixture_id"))
  source_lineage[is.na(source_lineage)] <- source_id[is.na(source_lineage)]
  explicit_family <- tolower(phase14_form_first_column(matches, c("source_family"), NA_character_))
  namespace <- tolower(phase14_form_first_column(matches, c("source_namespace", "source_dataset", "source"), ""))
  source_family <- explicit_family
  source_family[is.na(source_family) & grepl("competition|uefa|accepted", namespace)] <- "competition"
  source_family[is.na(source_family) & grepl("historical|martj42", namespace)] <- "historical"
  source_family[is.na(source_family)] <- "unknown"
  edition <- phase14_form_first_column(matches, c("edition_id"))
  source_scope <- phase14_form_first_column(matches, c("source_scope"))
  evidence_basis <- phase14_form_first_column(matches, c("evidence_basis"))
  result_home <- ifelse(!score_present, NA_character_, ifelse(home_goals > away_goals, "W", ifelse(home_goals < away_goals, "L", "D")))
  result_away <- ifelse(!score_present, NA_character_, ifelse(away_goals > home_goals, "W", ifelse(away_goals < home_goals, "L", "D")))

  make_side <- function(team, opponent, goals_for, goals_against, result) {
    data.frame(
      match_id = c(match_id),
      team_id = c(team),
      opponent_team_id = c(opponent),
      edition_id = c(edition),
      competition_type = c(competition_type),
      is_senior_mens_a = c(senior),
      match_status = c(status),
      completion_method = c(completion),
      football_goals_for = c(goals_for),
      football_goals_against = c(goals_against),
      counts_for_form = c(counts),
      result = c(result),
      evidence_completed_at_utc = c(evidence_timestamp),
      evidence_date = c(evidence_date),
      evidence_precision = c(precision),
      source_scope = c(source_scope),
      evidence_basis = c(evidence_basis),
      xgf = NA_real_,
      xga = NA_real_,
      source_id = c(source_id),
      source_hash = c(source_hash),
      source_lineage = c(source_lineage),
      source_family = c(source_family),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  }
  output <- rbind(
    make_side(home, away, home_goals, away_goals, result_home),
    make_side(away, home, away_goals, home_goals, result_away)
  )
  rownames(output) <- NULL
  output
}

phase14_form_scores <- function(data, index, home = FALSE) {
  if (isTRUE(home)) {
    for_goals <- c("final_home_goals", "football_home_goals", "home_goals", "home_score")
    against_goals <- c("final_away_goals", "football_away_goals", "away_goals", "away_score")
  } else {
    for_goals <- c("final_away_goals", "football_away_goals", "away_goals", "away_score")
    against_goals <- c("final_home_goals", "football_home_goals", "home_goals", "home_score")
  }
  c(
    for_goals = phase14_form_number(phase14_form_pick(data, index, for_goals)),
    against_goals = phase14_form_number(phase14_form_pick(data, index, against_goals))
  )
}

phase14_form_make_record <- function(data, index, team_id, opponent_team_id, goals_for, goals_against) {
  match_id <- phase14_form_match_id(data, index)
  source_id <- phase14_form_source_id(data, index)
  evidence <- phase14_form_evidence(data, index)
  completion_method <- tolower(phase14_form_pick(data, index, c("completion_method", "completion_status"), ""))
  match_status <- tolower(phase14_form_pick(data, index, c("match_status", "status"), ""))
  score_present <- is.finite(goals_for) && is.finite(goals_against)
  explicit_counts <- phase14_form_pick(data, index, c("counts_for_form"), NA_character_)
  if (is.na(explicit_counts)) {
    counts_for_form <- score_present &&
      !completion_method %in% c("awarded", "purely_awarded", "not_applicable", "postponed", "abandoned") &&
      !match_status %in% c("scheduled", "postponed", "abandoned", "cancelled", "canceled", "unplayed")
  } else {
    counts_for_form <- phase14_form_bool(explicit_counts, default = FALSE)
  }
  if (completion_method %in% c("awarded", "purely_awarded")) counts_for_form <- FALSE
  if (!is.na(match_status) && match_status %in% c("scheduled", "postponed", "abandoned", "cancelled", "canceled", "unplayed")) {
    counts_for_form <- FALSE
  }
  is_senior <- phase14_form_infer_senior_mens_a(data, index)
  result <- if (!score_present) NA_character_ else if (goals_for > goals_against) "W" else if (goals_for < goals_against) "L" else "D"
  source_hash <- phase14_form_source_hash(data, index)
  data.frame(
    match_id = match_id,
    team_id = as.character(team_id),
    opponent_team_id = as.character(opponent_team_id),
    edition_id = phase14_form_pick(data, index, c("edition_id"), NA_character_),
    competition_type = phase14_form_competition_type(data, index),
    is_senior_mens_a = isTRUE(is_senior),
    match_status = match_status,
    completion_method = completion_method,
    football_goals_for = as.numeric(goals_for),
    football_goals_against = as.numeric(goals_against),
    counts_for_form = isTRUE(counts_for_form),
    result = result,
    evidence_completed_at_utc = evidence$timestamp,
    evidence_date = evidence$date,
    evidence_precision = evidence$precision,
    source_scope = phase14_form_pick(data, index, c("source_scope"), NA_character_),
    evidence_basis = phase14_form_pick(data, index, c("evidence_basis"), NA_character_),
    xgf = phase14_form_number(phase14_form_pick(data, index, c("xgf", "xgf_team", "xGF"))),
    xga = phase14_form_number(phase14_form_pick(data, index, c("xga", "xga_team", "xGA"))),
    source_id = source_id,
    source_hash = source_hash,
    source_lineage = phase14_form_source_lineage(data, index, source_id),
    source_family = phase14_form_source_family(data, index),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

phase14_form_normalize_matches <- function(matches) {
  if (!is.data.frame(matches)) stop("Phase 14 form matches must be a data frame", call. = FALSE)
  if (!nrow(matches)) return(data.frame(stringsAsFactors = FALSE))
  is_long <- "team_id" %in% names(matches) && "opponent_team_id" %in% names(matches)
  if (!is_long) return(phase14_form_normalize_wide_fast(matches))
  records <- vector("list", if (is_long) nrow(matches) else nrow(matches) * 2L)
  cursor <- 0L
  for (index in seq_len(nrow(matches))) {
    if (is_long) {
      team_id <- phase14_form_pick(matches, index, c("team_id"), NA_character_)
      opponent <- phase14_form_pick(matches, index, c("opponent_team_id"), NA_character_)
      if (is.na(team_id) || is.na(opponent)) stop("Phase 14 form long rows require team_id and opponent_team_id", call. = FALSE)
      goals <- c(
        for_goals = phase14_form_number(phase14_form_pick(matches, index, c("football_goals_for", "goals_for", "team_goals_for"))),
        against_goals = phase14_form_number(phase14_form_pick(matches, index, c("football_goals_against", "goals_against", "team_goals_against")))
      )
      if (is.na(goals[[1L]]) || is.na(goals[[2L]])) {
        wide <- phase14_form_scores(matches, index, home = TRUE)
        if (!is.na(wide[[1L]]) && !is.na(wide[[2L]])) goals <- wide
      }
      cursor <- cursor + 1L
      records[[cursor]] <- phase14_form_make_record(matches, index, team_id, opponent, goals[[1L]], goals[[2L]])
    } else {
      home <- phase14_form_pick(matches, index, c("home_team_id", "home_source_team_id", "home_fifa_code", "home_team"), NA_character_)
      away <- phase14_form_pick(matches, index, c("away_team_id", "away_source_team_id", "away_fifa_code", "away_team"), NA_character_)
      if (is.na(home) || is.na(away)) stop("Phase 14 form wide rows require home and away team IDs", call. = FALSE)
      home_scores <- phase14_form_scores(matches, index, home = TRUE)
      away_scores <- phase14_form_scores(matches, index, home = FALSE)
      cursor <- cursor + 1L
      records[[cursor]] <- phase14_form_make_record(matches, index, home, away, home_scores[[1L]], home_scores[[2L]])
      cursor <- cursor + 1L
      records[[cursor]] <- phase14_form_make_record(matches, index, away, home, away_scores[[1L]], away_scores[[2L]])
    }
  }
  output <- do.call(rbind, records[seq_len(cursor)])
  rownames(output) <- NULL
  output
}

phase14_form_unique_text <- function(values) {
  values <- as.character(values)
  values <- values[!is.na(values) & nzchar(trimws(values))]
  unique(values)
}

phase14_form_prefer_lineage <- function(rows) {
  if (!nrow(rows)) return(rows)
  group_key <- paste(rows$match_id, rows$team_id, sep = "\x1f")
  groups <- split(seq_len(nrow(rows)), group_key, drop = TRUE)
  selected <- lapply(groups, function(indices) {
    priority <- ifelse(rows$source_family[indices] == "competition", 0L, 1L)
    accepted <- ifelse(tolower(rows$match_status[indices]) %in% c("accepted", "official", "reviewed"), 0L, 1L)
    order_indices <- indices[order(priority, accepted, rows$source_lineage[indices], na.last = TRUE)]
    row <- rows[order_indices[[1L]], , drop = FALSE]
    row$source_hash <- paste(phase14_form_unique_text(rows$source_hash[order_indices]), collapse = "|")
    row$source_lineage <- paste(phase14_form_unique_text(rows$source_lineage[order_indices]), collapse = "|")
    row
  })
  output <- do.call(rbind, selected)
  rownames(output) <- NULL
  output
}

phase14_form_before_cutoff <- function(row, cutoff) {
  precision <- tolower(as.character(row$evidence_precision[[1L]]))
  if (identical(precision, "timestamp")) {
    evidence <- as.POSIXct(row$evidence_completed_at_utc[[1L]], format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    return(!is.na(evidence) && evidence < cutoff$instant)
  }
  if (identical(precision, "date")) {
    evidence_date <- suppressWarnings(as.Date(row$evidence_date[[1L]]))
    return(!is.na(evidence_date) && evidence_date < cutoff$date)
  }
  FALSE
}

phase14_form_order <- function(rows) {
  if (!nrow(rows)) return(integer())
  timestamp <- suppressWarnings(as.POSIXct(rows$evidence_completed_at_utc, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  date_fallback <- suppressWarnings(as.POSIXct(rows$evidence_date, format = "%Y-%m-%d", tz = "UTC"))
  sort_time <- as.numeric(timestamp)
  missing_time <- is.na(timestamp)
  sort_time[missing_time] <- as.numeric(date_fallback[missing_time])
  order(sort_time, rows$match_id, rows$source_lineage, na.last = TRUE, method = "radix")
}

phase14_form_output_row <- function(team_id, rows, form_scope, edition_id, cutoff) {
  if (nrow(rows)) {
    ordered <- rows[phase14_form_order(rows), , drop = FALSE]
    selected <- tail(ordered, min(5L, nrow(ordered)))
    selected <- selected[phase14_form_order(selected), , drop = FALSE]
    sample_count <- nrow(selected)
    available <- TRUE
    reason <- if (sample_count < 5L) "partial_last_five" else "complete_last_five"
    result_sequence <- paste(selected$result, collapse = "")
    competition_type <- paste(phase14_form_unique_text(selected$competition_type), collapse = "|")
    match_ids <- paste(selected$match_id, collapse = "|")
    match_hashes <- paste(selected$source_hash, collapse = "|")
    lineages <- paste(selected$source_lineage, collapse = "|")
    timestamp_values <- selected$evidence_completed_at_utc[!is.na(selected$evidence_completed_at_utc)]
    date_values <- selected$evidence_date[!is.na(selected$evidence_date)]
    latest_timestamp <- if (length(timestamp_values)) tail(timestamp_values, 1L)[[1L]] else NA_character_
    latest_date <- if (length(date_values)) tail(date_values, 1L)[[1L]] else NA_character_
    latest_precision <- if (length(latest_timestamp)) "timestamp" else if (length(latest_date)) "date" else "missing"
    source_id <- paste(phase14_form_unique_text(selected$source_id), collapse = "|")
    if (!nzchar(source_id)) source_id <- NA_character_
    evidence_basis <- paste(phase14_form_unique_text(selected$evidence_basis), collapse = "|")
    if (!nzchar(evidence_basis)) evidence_basis <- NA_character_
    eligible_count <- nrow(rows)
  } else {
    sample_count <- 0L
    eligible_count <- 0L
    available <- FALSE
    reason <- "no_eligible_form_history"
    result_sequence <- NA_character_
    competition_type <- NA_character_
    match_ids <- NA_character_
    match_hashes <- NA_character_
    lineages <- NA_character_
    latest_timestamp <- NA_character_
    latest_date <- NA_character_
    latest_precision <- "missing"
    source_id <- NA_character_
    evidence_basis <- NA_character_
  }
  data.frame(
    edition_id = as.character(edition_id),
    team_id = as.character(team_id),
    form_scope = form_scope,
    window_type = "last_five",
    window_size = 5L,
    window_span = NA_integer_,
    sample_count = as.integer(sample_count),
    eligible_sample_count = as.integer(eligible_count),
    result_sequence = result_sequence,
    competition_type = competition_type,
    feature_cutoff_utc = cutoff$text,
    latest_evidence_completed_at_utc = latest_timestamp,
    latest_evidence_date = latest_date,
    latest_evidence_precision = latest_precision,
    contributing_match_ids = match_ids,
    contributing_match_hashes = match_hashes,
    contributing_source_lineages = lineages,
    xgf = NA_real_,
    xga = NA_real_,
    xgd = NA_real_,
    availability_status = if (available) "available" else "unavailable",
    availability_reason = reason,
    source_id = source_id,
    evidence_basis = evidence_basis,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

#' Build a five-match descriptive form view for a competition or all senior
#' men's international history.
phase14_build_display_form <- function(
    matches,
    teams = NULL,
    edition_id = NULL,
    feature_cutoff_utc,
    form_scope = "competition") {
  scope <- phase14_form_scope(form_scope)
  cutoff <- phase14_form_cutoff(feature_cutoff_utc)
  if (identical(scope, "competition") && (is.null(edition_id) || length(edition_id) != 1L || is.na(edition_id) || !nzchar(as.character(edition_id)))) {
    stop("Phase 14 competition display form requires one edition_id", call. = FALSE)
  }
  edition_id <- if (is.null(edition_id)) NA_character_ else as.character(edition_id[[1L]])
  normalized <- phase14_form_prefer_lineage(phase14_form_normalize_matches(matches))
  if (is.null(teams)) teams <- sort(unique(as.character(normalized$team_id)))
  teams <- unique(as.character(teams))
  teams <- teams[!is.na(teams) & nzchar(teams)]
  if (!length(teams)) return(phase14_form_add_hashes(data.frame(stringsAsFactors = FALSE)))

  if (nrow(normalized)) {
    cutoff_eligible <- vapply(seq_len(nrow(normalized)), function(index) {
      phase14_form_before_cutoff(normalized[index, , drop = FALSE], cutoff)
    }, logical(1))
    eligible <- normalized[cutoff_eligible & normalized$is_senior_mens_a & normalized$counts_for_form, , drop = FALSE]
    if (identical(scope, "competition")) {
      eligible <- eligible[!is.na(eligible$edition_id) & eligible$edition_id == edition_id, , drop = FALSE]
    }
  } else {
    eligible <- normalized
  }

  output <- lapply(teams, function(team_id) {
    rows <- eligible[eligible$team_id == team_id, , drop = FALSE]
    phase14_form_output_row(team_id, rows, scope, edition_id, cutoff)
  })
  phase14_form_add_hashes(do.call(rbind, output))
}

#' Durable boundary for optional shot-derived national-team xG.
phase14_national_team_xg_source_schema <- function() {
  c(
    "schema_version", "source_id", "source_scope", "evidence_basis",
    "acceptance_status", "accepted_artifact_path", "accepted_artifact_sha256",
    "stable_match_id_contract", "stable_team_id_contract",
    "point_in_time_evidence_contract", "review_state", "reviewed_at_utc",
    "reviewed_by", "review_note", "row_sha256"
  )
}

phase14_national_team_xg_registry_row_hash <- function(registry) {
  if (!is.data.frame(registry)) stop("Phase 14 national-team xG registry must be a data frame", call. = FALSE)
  fields <- setdiff(phase14_national_team_xg_source_schema(), "row_sha256")
  missing <- setdiff(fields, names(registry))
  if (length(missing)) stop("Phase 14 national-team xG registry hash is missing fields: ", paste(missing, collapse = ", "), call. = FALSE)
  vapply(seq_len(nrow(registry)), function(index) {
    values <- vapply(registry[index, fields, drop = FALSE], phase14_form_canonical_scalar, character(1))
    phase14_form_digest(paste(values, collapse = "|"))
  }, character(1))
}

phase14_form_find_project_root <- function(path = ".") {
  candidate <- normalizePath(path, winslash = "/", mustWork = FALSE)
  if (file.exists(candidate) && !dir.exists(candidate)) candidate <- dirname(candidate)
  repeat {
    if (dir.exists(file.path(candidate, ".git")) || file.exists(file.path(candidate, ".git"))) return(candidate)
    parent <- dirname(candidate)
    if (identical(parent, candidate)) break
    candidate <- parent
  }
  normalizePath(path, winslash = "/", mustWork = FALSE)
}

phase14_national_team_xg_registry_read <- function(registry, project_root = ".") {
  root <- if (identical(project_root, ".")) phase14_form_find_project_root() else project_root
  if (is.null(registry)) registry <- file.path(root, "data/competition/registries/national_team_xg_sources.csv")
  if (is.character(registry) && length(registry) == 1L) {
    path <- as.character(registry[[1L]])
    if (!grepl("^/", path) && !file.exists(path)) path <- file.path(root, path)
    if (!file.exists(path)) stop("Phase 14 national-team xG registry is missing: ", path, call. = FALSE)
    return(utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = c("", "NA")))
  }
  if (!is.data.frame(registry)) stop("Phase 14 national-team xG registry must be a data frame or CSV path", call. = FALSE)
  registry
}

phase14_national_team_xg_registry_path <- function(path, project_root = ".") {
  if (is.na(path) || !nzchar(path)) return(NA_character_)
  if (grepl("^/", path)) return(path)
  root <- if (identical(project_root, ".")) phase14_form_find_project_root() else project_root
  file.path(root, path)
}

#' Validate the declared national-team xG source boundary.
phase14_validate_national_team_xg_registry <- function(
    registry = NULL,
    project_root = ".",
    verify_artifacts = TRUE) {
  registry <- phase14_national_team_xg_registry_read(registry, project_root = project_root)
  schema <- phase14_national_team_xg_source_schema()
  missing <- setdiff(schema, names(registry))
  if (length(missing)) {
    stop("Phase 14 national-team xG registry is missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  registry <- registry[, schema, drop = FALSE]
  if (!nrow(registry)) return(invisible(registry))
  for (field in c("schema_version", "source_id", "source_scope", "evidence_basis", "acceptance_status", "stable_match_id_contract", "stable_team_id_contract", "point_in_time_evidence_contract", "review_state")) {
    values <- phase14_form_clean_text(registry[[field]])
    if (any(is.na(values))) stop("Phase 14 national-team xG registry has missing ", field, call. = FALSE)
  }
  if (anyDuplicated(as.character(registry$source_id))) stop("Phase 14 national-team xG registry has duplicate source_id values", call. = FALSE)
  if (any(as.character(registry$source_scope) != "senior_mens_national_team")) {
    stop("Phase 14 national-team xG registry source_scope must be senior_mens_national_team", call. = FALSE)
  }
  if (any(as.character(registry$evidence_basis) != "shot_derived")) {
    stop("Phase 14 national-team xG registry evidence_basis must be shot_derived", call. = FALSE)
  }
  allowed_status <- c("not_accepted", "accepted", "rejected", "blocked")
  if (any(!as.character(registry$acceptance_status) %in% allowed_status)) {
    stop("Phase 14 national-team xG registry has an unsupported acceptance_status", call. = FALSE)
  }
  allowed_review <- c("reviewed", "not_reviewed", "pending_review", "not_required")
  if (any(!as.character(registry$review_state) %in% allowed_review)) {
    stop("Phase 14 national-team xG registry has an unsupported review_state", call. = FALSE)
  }
  accepted <- as.character(registry$acceptance_status) == "accepted"
  if (any(accepted & as.character(registry$review_state) != "reviewed")) {
    stop("Phase 14 accepted national-team xG source must have review_state=reviewed", call. = FALSE)
  }
  accepted_paths <- phase14_form_clean_text(registry$accepted_artifact_path)
  accepted_hashes <- tolower(phase14_form_clean_text(registry$accepted_artifact_sha256))
  if (any(accepted & (is.na(accepted_paths) | !grepl("^[0-9a-f]{64}$", accepted_hashes)))) {
    stop("Phase 14 accepted national-team xG source requires an artifact path and SHA-256", call. = FALSE)
  }
  if (any(accepted & !grepl("strictly|before|exclusive", tolower(registry$point_in_time_evidence_contract)))) {
    stop("Phase 14 accepted national-team xG source requires an exclusive point-in-time evidence contract", call. = FALSE)
  }
  if (isTRUE(verify_artifacts) && any(accepted)) {
    for (index in which(accepted)) {
      path <- phase14_national_team_xg_registry_path(accepted_paths[[index]], project_root = project_root)
      if (!file.exists(path)) stop("Phase 14 accepted national-team xG artifact is missing: ", accepted_paths[[index]], call. = FALSE)
      actual_hash <- tolower(digest::digest(file = path, algo = "sha256"))
      if (!identical(actual_hash, accepted_hashes[[index]])) {
        stop("Phase 14 accepted national-team xG artifact hash mismatch for source_id: ", registry$source_id[[index]], call. = FALSE)
      }
    }
  }
  actual_rows <- phase14_form_clean_text(registry$row_sha256)
  if (any(is.na(actual_rows) | !grepl("^[0-9a-f]{64}$", tolower(actual_rows)))) {
    stop("Phase 14 national-team xG registry requires SHA-256 row hashes", call. = FALSE)
  }
  expected_rows <- phase14_national_team_xg_registry_row_hash(registry)
  if (any(tolower(actual_rows) != tolower(expected_rows))) {
    stop("Phase 14 national-team xG registry row SHA-256 mismatch", call. = FALSE)
  }
  invisible(registry)
}

phase14_form_cutoff_value <- function(data, index, feature_cutoff_utc = NULL) {
  if (!is.null(feature_cutoff_utc)) return(feature_cutoff_utc)
  value <- phase14_form_pick(
    data,
    index,
    c("feature_cutoff_utc", "fixture_cutoff_utc", "forecast_cutoff_utc", "cutoff_utc"),
    NA_character_
  )
  if (is.na(value)) stop("Phase 14 form cutoff is required", call. = FALSE)
  value
}

#' Assert that every evidence row is strictly before its feature cutoff.
phase14_assert_form_cutoffs <- function(data, feature_cutoff_utc = NULL) {
  if (!is.data.frame(data)) stop("Phase 14 form cutoff validation requires a data frame", call. = FALSE)
  if (!nrow(data)) return(invisible(TRUE))
  for (index in seq_len(nrow(data))) {
    cutoff_value <- phase14_form_cutoff_value(data, index, feature_cutoff_utc)
    cutoff <- phase14_form_cutoff(cutoff_value)
    precision <- tolower(phase14_form_pick(data, index, c("evidence_precision"), ""))
    timestamp <- phase14_form_pick(data, index, c("evidence_completed_at_utc", "completed_at_utc", "evidence_timestamp_utc", "evidence_at_utc"), NA_character_)
    evidence_date <- phase14_form_pick(data, index, c("evidence_date", "match_date", "date"), NA_character_)
    if (!precision %in% c("timestamp", "date", "missing")) {
      precision <- if (!is.na(timestamp)) "timestamp" else if (!is.na(evidence_date)) "date" else "missing"
    }
    if (identical(precision, "timestamp")) {
      if (is.na(timestamp)) stop("Phase 14 form evidence timestamp is missing at cutoff", call. = FALSE)
      evidence <- as.POSIXct(phase14_form_timestamp(timestamp, "evidence_completed_at_utc"), format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
      if (is.na(evidence) || evidence >= cutoff$instant) {
        stop("Phase 14 form evidence is equal to or after the feature cutoff", call. = FALSE)
      }
    } else if (identical(precision, "date")) {
      if (is.na(evidence_date)) stop("Phase 14 date-only form evidence is missing its evidence date", call. = FALSE)
      evidence_date <- as.Date(phase14_form_date(evidence_date, "evidence_date"))
      if (is.na(evidence_date) || evidence_date >= cutoff$date) {
        stop("Phase 14 date-only evidence is same-day or after the feature cutoff", call. = FALSE)
      }
    } else {
      stop("Phase 14 form evidence has missing or ambiguous time precision", call. = FALSE)
    }
  }
  invisible(TRUE)
}

phase14_national_team_xg_empty <- function() {
  data.frame(
    match_id = character(0),
    team_id = character(0),
    opponent_team_id = character(0),
    source_id = character(0),
    source_scope = character(0),
    evidence_basis = character(0),
    source_row_sha256 = character(0),
    source_lineage_id = character(0),
    edition_id = character(0),
    evidence_completed_at_utc = character(0),
    evidence_date = character(0),
    evidence_precision = character(0),
    feature_cutoff_utc = character(0),
    xgf = numeric(0),
    xga = numeric(0),
    xgd = numeric(0),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

phase14_form_is_goal_relabelled_xg <- function(rows) {
  if (!nrow(rows)) return(FALSE)
  xgf <- suppressWarnings(as.numeric(rows$xgf))
  xga <- suppressWarnings(as.numeric(rows$xga))
  goals_for <- suppressWarnings(as.numeric(rows$football_goals_for))
  goals_against <- suppressWarnings(as.numeric(rows$football_goals_against))
  complete <- is.finite(xgf) & is.finite(xga) & is.finite(goals_for) & is.finite(goals_against)
  isTRUE(any(complete)) && isTRUE(all(complete)) &&
    isTRUE(all(xgf == goals_for)) && isTRUE(all(xga == goals_against))
}

#' Adapt only a reviewed registry-approved shot-derived national-team xG table.
phase14_adapt_national_team_xg <- function(
    xg_history,
    registry = NULL,
    feature_cutoff_utc,
    strict_cutoff = TRUE,
    project_root = ".") {
  if (!is.data.frame(xg_history)) stop("Phase 14 national-team xG history must be a data frame", call. = FALSE)
  if ("team" %in% names(xg_history) && "match_date" %in% names(xg_history) &&
      !any(c("match_id", "canonical_match_id", "source_match_id") %in% names(xg_history))) {
    stop("Phase 14 national-team xG adapter rejects club rolling_form.csv: stable national match_id is missing", call. = FALSE)
  }
  cutoff <- phase14_form_cutoff(feature_cutoff_utc)
  registry <- phase14_national_team_xg_registry_read(registry, project_root = project_root)
  phase14_validate_national_team_xg_registry(registry, project_root = project_root, verify_artifacts = TRUE)
  accepted_registry <- registry[registry$acceptance_status == "accepted", , drop = FALSE]
  if (!nrow(accepted_registry)) {
    output <- phase14_national_team_xg_empty()
    attr(output, "availability_reason") <- "no_accepted_national_team_xg_source"
    attr(output, "registry") <- registry
    return(output)
  }
  normalized <- phase14_form_prefer_lineage(phase14_form_normalize_matches(xg_history))
  if (!nrow(normalized)) return(phase14_national_team_xg_empty())
  if (phase14_form_is_goal_relabelled_xg(normalized)) {
    stop("Phase 14 national-team xG evidence rejects football goals relabelled as xG", call. = FALSE)
  }
  normalized$source_row_sha256 <- as.character(normalized$source_hash)
  required_text <- c("match_id", "team_id", "source_id", "source_row_sha256", "source_scope", "evidence_basis")
  for (field in required_text) {
    values <- phase14_form_clean_text(normalized[[field]])
    if (any(is.na(values))) stop("Phase 14 national-team xG evidence requires stable ", field, call. = FALSE)
  }
  if (any(!grepl("^[0-9a-f]{64}$", tolower(normalized$source_row_sha256)))) {
    stop("Phase 14 national-team xG evidence requires a stable source row SHA-256", call. = FALSE)
  }
  accepted_ids <- as.character(accepted_registry$source_id)
  if (any(!normalized$source_id %in% accepted_ids)) {
    stop("Phase 14 national-team xG evidence references a source that is not registry-accepted", call. = FALSE)
  }
  if (any(normalized$source_scope != "senior_mens_national_team")) {
    stop("Phase 14 national-team xG evidence has a non-national source scope", call. = FALSE)
  }
  if (any(normalized$evidence_basis != "shot_derived")) {
    stop("Phase 14 national-team xG evidence must be shot_derived, not scoreline or goals", call. = FALSE)
  }
  if (any(!is.finite(normalized$xgf) | !is.finite(normalized$xga) | normalized$xgf < 0 | normalized$xga < 0)) {
    stop("Phase 14 national-team xG evidence requires finite non-negative xGF and xGA", call. = FALSE)
  }
  if (isTRUE(strict_cutoff)) {
    phase14_assert_form_cutoffs(normalized, feature_cutoff_utc = cutoff$text)
    cutoff_eligible <- rep(TRUE, nrow(normalized))
  } else {
    cutoff_eligible <- vapply(seq_len(nrow(normalized)), function(index) {
      phase14_form_before_cutoff(normalized[index, , drop = FALSE], cutoff)
    }, logical(1))
  }
  normalized <- normalized[cutoff_eligible, , drop = FALSE]
  if (!nrow(normalized)) return(phase14_national_team_xg_empty())
  normalized$feature_cutoff_utc <- cutoff$text
  normalized$xgd <- normalized$xgf - normalized$xga
  normalized <- normalized[, c(
    "match_id", "team_id", "opponent_team_id", "source_id", "source_scope",
    "evidence_basis", "source_row_sha256", "source_lineage", "edition_id",
    "evidence_completed_at_utc", "evidence_date", "evidence_precision",
    "feature_cutoff_utc", "xgf", "xga", "xgd"
  ), drop = FALSE]
  names(normalized)[names(normalized) == "source_lineage"] <- "source_lineage_id"
  normalized[phase14_form_order(normalized), , drop = FALSE]
}

phase14_form_ewma <- function(values, span) {
  values <- suppressWarnings(as.numeric(values))
  if (!length(values) || any(!is.finite(values))) return(NA_real_)
  alpha <- 2 / (as.numeric(span) + 1)
  output <- values[[1L]]
  if (length(values) > 1L) {
    for (index in 2:length(values)) output <- alpha * values[[index]] + (1 - alpha) * output
  }
  as.numeric(output)
}

phase14_model_form_output_row <- function(team_id, rows, form_scope, edition_id, cutoff, span, unavailable_reason) {
  edition_value <- if (!is.null(edition_id) && length(edition_id) && !is.na(edition_id[[1L]])) {
    as.character(edition_id[[1L]])
  } else {
    NA_character_
  }
  if (!nrow(rows)) {
    return(data.frame(
      edition_id = edition_value,
      team_id = as.character(team_id),
      form_scope = form_scope,
      window_type = "ewma",
      window_size = as.integer(span),
      window_span = as.integer(span),
      sample_count = 0L,
      eligible_sample_count = 0L,
      result_sequence = NA_character_,
      competition_type = NA_character_,
      feature_cutoff_utc = cutoff$text,
      latest_evidence_completed_at_utc = NA_character_,
      latest_evidence_date = NA_character_,
      latest_evidence_precision = "missing",
      contributing_match_ids = NA_character_,
      contributing_match_hashes = NA_character_,
      contributing_source_lineages = NA_character_,
      xgf = NA_real_,
      xga = NA_real_,
      xgd = NA_real_,
      xgf_ewma = NA_real_,
      xga_ewma = NA_real_,
      xgd_ewma = NA_real_,
      availability_status = "unavailable",
      availability_reason = unavailable_reason,
      source_id = NA_character_,
      source_scope = "senior_mens_national_team",
      evidence_basis = "shot_derived",
      stringsAsFactors = FALSE,
      check.names = FALSE
    ))
  }
  ordered <- rows[phase14_form_order(rows), , drop = FALSE]
  xgf_ewma <- phase14_form_ewma(ordered$xgf, span)
  xga_ewma <- phase14_form_ewma(ordered$xga, span)
  xgd_ewma <- xgf_ewma - xga_ewma
  timestamp_values <- ordered$evidence_completed_at_utc[!is.na(ordered$evidence_completed_at_utc)]
  date_values <- ordered$evidence_date[!is.na(ordered$evidence_date)]
  latest_timestamp <- if (length(timestamp_values)) tail(timestamp_values, 1L)[[1L]] else NA_character_
  latest_date <- if (length(date_values)) tail(date_values, 1L)[[1L]] else NA_character_
  data.frame(
    edition_id = edition_value,
    team_id = as.character(team_id),
    form_scope = form_scope,
    window_type = "ewma",
    window_size = as.integer(span),
    window_span = as.integer(span),
    sample_count = as.integer(nrow(ordered)),
    eligible_sample_count = as.integer(nrow(ordered)),
    result_sequence = NA_character_,
    competition_type = NA_character_,
    feature_cutoff_utc = cutoff$text,
    latest_evidence_completed_at_utc = latest_timestamp,
    latest_evidence_date = latest_date,
    latest_evidence_precision = if (length(timestamp_values)) "timestamp" else if (length(date_values)) "date" else "missing",
    contributing_match_ids = paste(ordered$match_id, collapse = "|"),
    contributing_match_hashes = paste(ordered$source_row_sha256, collapse = "|"),
    contributing_source_lineages = paste(ordered$source_lineage_id, collapse = "|"),
    xgf = xgf_ewma,
    xga = xga_ewma,
    xgd = xgd_ewma,
    xgf_ewma = xgf_ewma,
    xga_ewma = xga_ewma,
    xgd_ewma = xgd_ewma,
    availability_status = "available",
    availability_reason = "accepted_shot_derived_national_team_xg",
    source_id = paste(unique(ordered$source_id), collapse = "|"),
    source_scope = "senior_mens_national_team",
    evidence_basis = "shot_derived",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

#' Build the optional span-12 national-team xG model-form product.
phase14_build_model_form <- function(
    xg_history,
    teams = NULL,
    feature_cutoff_utc,
    span = 12L,
    registry = NULL,
    edition_id = NULL,
    project_root = ".") {
  if (length(span) != 1L || is.na(span) || span < 1 || span != floor(span)) {
    stop("Phase 14 national-team xG span must be one positive integer", call. = FALSE)
  }
  cutoff <- phase14_form_cutoff(feature_cutoff_utc)
  registry <- phase14_national_team_xg_registry_read(registry, project_root = project_root)
  phase14_validate_national_team_xg_registry(registry, project_root = project_root, verify_artifacts = TRUE)
  if (is.null(teams)) {
    if (is.data.frame(xg_history) && "team_id" %in% names(xg_history)) teams <- unique(as.character(xg_history$team_id)) else teams <- character()
  }
  teams <- unique(as.character(teams))
  teams <- teams[!is.na(teams) & nzchar(teams)]
  if (!length(teams)) return(phase14_form_add_hashes(data.frame(stringsAsFactors = FALSE)))
  accepted_exists <- any(registry$acceptance_status == "accepted")
  adapted <- phase14_adapt_national_team_xg(
    xg_history = xg_history,
    registry = registry,
    feature_cutoff_utc = cutoff$text,
    strict_cutoff = FALSE,
    project_root = project_root
  )
  reason <- if (accepted_exists) "no_point_in_time_national_team_xg_evidence" else "no_accepted_national_team_xg_source"
  output <- lapply(teams, function(team_id) {
    rows <- adapted[adapted$team_id == team_id, , drop = FALSE]
    phase14_model_form_output_row(team_id, rows, "national_team_xg", edition_id, cutoff, as.integer(span), reason)
  })
  phase14_form_add_hashes(do.call(rbind, output))
}
