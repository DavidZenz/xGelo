#' Durable canonical match identity and lifecycle/score contracts for Phase 14.

phase14_match_identity_schema <- function() {
  c(
    "schema_version", "match_id", "source_namespace", "source_id",
    "source_match_id", "source_lineage_id", "edition_id",
    "home_team_id", "away_team_id", "scheduled_at_utc", "match_date",
    "neutral", "venue_context", "minting_projection",
    "minting_projection_sha256", "competition_lineage_id",
    "history_lineage_id", "collision_status", "review_state",
    "row_sha256", "table_sha256"
  )
}

phase14_match_state_canonical_scalar <- function(value) {
  if (!length(value) || is.null(value) || is.na(value[[1L]])) return("<NA>")
  value <- value[[1L]]
  if (inherits(value, "POSIXt")) return(format(value, "%Y-%m-%dT%H:%M:%S", tz = "UTC"))
  if (is.logical(value)) return(if (isTRUE(value)) "TRUE" else "FALSE")
  trimws(as.character(value))
}

phase14_match_state_digest <- function(value) {
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("digest is required for Phase 14 match-state hashes", call. = FALSE)
  }
  digest::digest(enc2utf8(as.character(value)), algo = "sha256", serialize = FALSE)
}

phase14_match_state_canonical_column <- function(value) {
  if (inherits(value, "POSIXt")) {
    value <- format(value, "%Y-%m-%dT%H:%M:%S", tz = "UTC")
  } else if (is.logical(value)) {
    value <- ifelse(is.na(value), NA_character_, ifelse(value, "TRUE", "FALSE"))
  } else {
    value <- as.character(value)
  }
  value <- trimws(value)
  value[is.na(value)] <- "<NA>"
  value
}

phase14_match_state_payloads <- function(data, fields, separator = "\x1f") {
  columns <- lapply(data[fields], phase14_match_state_canonical_column)
  if (!length(columns)) return(rep("", nrow(data)))
  do.call(paste, c(columns, sep = separator))
}

phase14_match_state_value <- function(data, columns, index, default = NA_character_) {
  for (column in as.character(columns)) {
    if (!column %in% names(data)) next
    value <- data[[column]][[index]]
    if (length(value) == 0L || is.null(value) || is.na(value)) next
    value <- as.character(value[[1L]])
    if (nzchar(trimws(value))) return(value)
  }
  default
}

phase14_match_state_coalesce <- function(data, columns, default = NA_character_) {
  if (length(default) == 1L) {
    output <- rep(default, nrow(data))
  } else if (length(default) == nrow(data)) {
    output <- as.character(default)
  } else {
    stop("Phase 14 match-state coalesce default must be scalar or row-aligned", call. = FALSE)
  }
  for (column in as.character(columns)) {
    if (!column %in% names(data)) next
    values <- as.character(data[[column]])
    present <- !is.na(values) & nzchar(trimws(values))
    replace <- present & (is.na(output) | !nzchar(trimws(as.character(output))))
    output[replace] <- values[replace]
  }
  output
}

phase14_match_state_bool <- function(value) {
  if (length(value) == 0L || is.null(value) || is.na(value)) return(NA)
  value <- tolower(trimws(as.character(value[[1L]])))
  if (!nzchar(value)) return(NA)
  if (value %in% c("true", "t", "1", "yes", "y")) return(TRUE)
  if (value %in% c("false", "f", "0", "no", "n")) return(FALSE)
  stop("Phase 14 neutral flag has an unsupported value: ", value, call. = FALSE)
}

phase14_match_state_bool_vector <- function(values) {
  text <- tolower(trimws(as.character(values)))
  output <- rep(NA, length(text))
  missing <- is.na(values) | !nzchar(text)
  true <- !missing & text %in% c("true", "t", "1", "yes", "y")
  false <- !missing & text %in% c("false", "f", "0", "no", "n")
  invalid <- !missing & !(true | false)
  if (any(invalid)) stop("Phase 14 neutral flag has an unsupported value: ", text[which(invalid)[[1L]]], call. = FALSE)
  output[true] <- TRUE
  output[false] <- FALSE
  output
}

phase14_match_state_date <- function(value) {
  if (length(value) == 0L || is.null(value) || is.na(value)) return(NA_character_)
  value <- trimws(as.character(value[[1L]]))
  if (!nzchar(value)) return(NA_character_)
  parsed <- suppressWarnings(as.Date(substr(value, 1L, 10L)))
  if (is.na(parsed)) stop("Phase 14 match identity has an invalid match date: ", value, call. = FALSE)
  format(parsed, "%Y-%m-%d")
}

phase14_match_state_date_vector <- function(values) {
  values <- as.character(values)
  output <- rep(NA_character_, length(values))
  present <- !is.na(values) & nzchar(trimws(values))
  if (!any(present)) return(output)
  parsed <- suppressWarnings(as.Date(substr(values[present], 1L, 10L)))
  if (any(is.na(parsed))) stop("Phase 14 match identity contains an invalid match date", call. = FALSE)
  output[present] <- format(parsed, "%Y-%m-%d")
  output
}

phase14_match_state_timestamp <- function(value) {
  if (length(value) == 0L || is.null(value) || is.na(value)) return(NA_character_)
  value <- trimws(as.character(value[[1L]]))
  if (!nzchar(value)) return(NA_character_)
  parsed <- suppressWarnings(as.POSIXct(value, tz = "UTC", format = "%Y-%m-%dT%H:%M:%OSZ"))
  if (is.na(parsed)) parsed <- suppressWarnings(as.POSIXct(value, tz = "UTC"))
  if (is.na(parsed)) stop("Phase 14 match identity has an invalid kickoff: ", value, call. = FALSE)
  format(parsed, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

phase14_match_state_timestamp_vector <- function(values) {
  values <- as.character(values)
  output <- rep(NA_character_, length(values))
  present <- !is.na(values) & nzchar(trimws(values))
  if (!any(present)) return(output)
  parsed <- suppressWarnings(as.POSIXct(values[present], tz = "UTC", format = "%Y-%m-%dT%H:%M:%OSZ"))
  fallback <- is.na(parsed)
  if (any(fallback)) parsed[fallback] <- suppressWarnings(as.POSIXct(values[present][fallback], tz = "UTC"))
  if (any(is.na(parsed))) stop("Phase 14 match identity contains an invalid kickoff timestamp", call. = FALSE)
  output[present] <- format(parsed, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  output
}

phase14_match_state_venue <- function(data, index) {
  values <- vapply(
    c("venue_context", "venue", "venue_name", "stadium", "city", "country"),
    function(column) phase14_match_state_value(data, column, index, NA_character_),
    character(1)
  )
  values <- values[!is.na(values) & nzchar(trimws(values))]
  if (!length(values)) return(NA_character_)
  paste(unique(values), collapse = "|")
}

phase14_match_state_venue_vector <- function(data) {
  primary <- phase14_match_state_coalesce(data, c("venue_context", "venue", "venue_name", "stadium"))
  city <- phase14_match_state_coalesce(data, "city")
  country <- phase14_match_state_coalesce(data, "country")
  vapply(seq_len(nrow(data)), function(index) {
    values <- c(primary[[index]], city[[index]], country[[index]])
    values <- values[!is.na(values) & nzchar(trimws(values))]
    if (!length(values)) return(NA_character_)
    paste(unique(values), collapse = "|")
  }, character(1))
}

phase14_match_state_source_lineage <- function(data, index, namespace, source_id) {
  explicit <- phase14_match_state_value(data, "source_lineage_id", index, NA_character_)
  if (!is.na(explicit) && nzchar(trimws(explicit))) return(explicit)
  artifact <- phase14_match_state_value(data, "source_artifact_id", index, NA_character_)
  if (!is.na(artifact) && nzchar(trimws(artifact))) return(paste(artifact, source_id, sep = "::"))
  paste(namespace, source_id, sep = "::")
}

phase14_match_state_source_id <- function(data, index, source_family, table_kind) {
  columns <- if (identical(source_family, "competition")) {
    if (identical(table_kind, "results")) {
      c("source_fixture_id", "uefa_source_fixture_id", "source_match_id", "fixture_id")
    } else {
      c("source_fixture_id", "uefa_source_fixture_id", "source_match_id", "fixture_id")
    }
  } else {
    c("source_match_id", "source_result_id", "match_id", "source_id")
  }
  value <- phase14_match_state_value(data, columns, index, NA_character_)
  if (is.na(value) || !nzchar(trimws(value))) {
    stop("Phase 14 match identity requires a non-empty source match ID", call. = FALSE)
  }
  value
}

phase14_match_state_normalize_source_table <- function(
    data,
    source_family,
    table_kind = "source",
    default_namespace = NULL) {
  if (!is.data.frame(data)) stop("Phase 14 match identity source must be a data frame", call. = FALSE)
  if (!nrow(data)) return(data.frame(stringsAsFactors = FALSE))
  source_family <- match.arg(source_family, c("competition", "historical"))
  default_namespace <- if (is.null(default_namespace)) {
    if (identical(source_family, "historical")) "martj42_history" else
      paste0("competition_", if (identical(table_kind, "results")) "result" else "fixture")
  } else as.character(default_namespace[[1L]])

  namespace <- phase14_match_state_coalesce(data, "source_namespace", default_namespace)
  source_columns <- if (identical(source_family, "historical")) {
    c("source_match_id", "source_result_id", "match_id", "source_id")
  } else c("source_fixture_id", "uefa_source_fixture_id", "source_match_id", "fixture_id")
  source_id <- phase14_match_state_coalesce(data, source_columns)
  if (any(is.na(source_id) | !nzchar(trimws(source_id)))) stop("Phase 14 match identity requires a non-empty source match ID", call. = FALSE)
  edition_id <- phase14_match_state_coalesce(data, "edition_id")
  home_team_id <- phase14_match_state_coalesce(data, c("home_team_id", "home_source_team_id", "home_fifa_code", "home_team"))
  away_team_id <- phase14_match_state_coalesce(data, c("away_team_id", "away_source_team_id", "away_fifa_code", "away_team"))
  if (any(is.na(home_team_id) | !nzchar(trimws(home_team_id))) || any(is.na(away_team_id) | !nzchar(trimws(away_team_id)))) {
    stop("Phase 14 match identity requires stable home and away team IDs", call. = FALSE)
  }
  scheduled_raw <- phase14_match_state_coalesce(data, c("scheduled_at_utc", "confirmed_kickoff_at_utc", "kickoff_at_utc"))
  scheduled <- phase14_match_state_timestamp_vector(scheduled_raw)
  date_raw <- phase14_match_state_coalesce(data, c("match_date", "date"))
  missing_date <- is.na(date_raw) | !nzchar(trimws(date_raw))
  date_raw[missing_date] <- scheduled[missing_date]
  match_date <- phase14_match_state_date_vector(date_raw)
  if (any(is.na(scheduled) & is.na(match_date))) stop("Phase 14 match identity requires a scheduled timestamp or match date", call. = FALSE)
  neutral <- phase14_match_state_bool_vector(phase14_match_state_coalesce(data, "neutral"))
  lineage <- phase14_match_state_coalesce(data, "source_lineage_id")
  artifact <- phase14_match_state_coalesce(data, "source_artifact_id")
  explicit_lineage <- !is.na(lineage) & nzchar(trimws(lineage))
  fallback_lineage <- paste(namespace, source_id, sep = "::")
  lineage[!explicit_lineage] <- fallback_lineage[!explicit_lineage]
  use_artifact <- !explicit_lineage & !is.na(artifact) & nzchar(trimws(artifact))
  lineage[use_artifact] <- paste(artifact[use_artifact], source_id[use_artifact], sep = "::")
  history_lineage <- phase14_match_state_coalesce(data, c("source_match_id", "source_result_id", "match_id"), lineage)
  provided_match_id <- phase14_match_state_coalesce(data, c("canonical_match_id", "canonical_id"))
  data.frame(
    source_family = rep(source_family, nrow(data)),
    source_namespace = namespace,
    source_id = source_id,
    source_match_id = source_id,
    source_lineage_id = lineage,
    edition_id = edition_id,
    home_team_id = home_team_id,
    away_team_id = away_team_id,
    scheduled_at_utc = scheduled,
    match_date = match_date,
    neutral = neutral,
    venue_context = phase14_match_state_venue_vector(data),
    competition_lineage_id = if (identical(source_family, "competition")) lineage else rep(NA_character_, nrow(data)),
    history_lineage_id = if (identical(source_family, "historical")) history_lineage else rep(NA_character_, nrow(data)),
    collision_status = phase14_match_state_coalesce(data, "collision_status", "none"),
    review_state = phase14_match_state_coalesce(data, "review_state", "not_required"),
    provided_match_id = provided_match_id,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

phase14_match_state_empty_identity_rows <- function() {
  schema <- phase14_match_identity_schema()
  output <- as.data.frame(setNames(lapply(schema, function(column) {
    if (column %in% c("neutral")) logical(0) else character(0)
  }), schema), stringsAsFactors = FALSE, check.names = FALSE)
  output
}

phase14_match_state_collect_sources <- function(
    sources = NULL,
    competition = NULL,
    historical = NULL,
    accepted_fixtures = NULL,
    accepted_results = NULL,
    historical_matches = NULL,
    dots = list()) {
  parts <- list()
  append_part <- function(data, family, kind, namespace = NULL) {
    if (is.null(data)) return(invisible(NULL))
    if (is.list(data) && !is.data.frame(data)) {
      for (name in names(data)) {
        if (is.null(data[[name]])) next
        nested_kind <- if (identical(family, "competition") && grepl("result", name, ignore.case = TRUE)) "results" else
          if (identical(family, "competition") && grepl("fixture", name, ignore.case = TRUE)) "fixtures" else kind
        append_part(data[[name]], family, nested_kind, namespace)
      }
      return(invisible(NULL))
    }
    if (!is.data.frame(data)) stop("Phase 14 match identity source collection contains a non-table value", call. = FALSE)
    normalized <- phase14_match_state_normalize_source_table(data, family, kind, namespace)
    if (nrow(normalized)) parts[[length(parts) + 1L]] <<- normalized
    invisible(NULL)
  }

  if (!is.null(sources)) {
    if (is.data.frame(sources)) {
      family <- if (any(c("source_match_id", "source_result_id", "home_score") %in% names(sources))) "historical" else "competition"
      append_part(sources, family, if (identical(family, "historical")) "history" else "source")
    } else if (is.list(sources)) {
      for (name in names(sources)) {
        family <- if (grepl("hist|martj|history", name, ignore.case = TRUE)) "historical" else "competition"
        kind <- if (grepl("result", name, ignore.case = TRUE)) "results" else if (grepl("fixture", name, ignore.case = TRUE)) "fixtures" else "source"
        append_part(sources[[name]], family, kind)
      }
    } else stop("Phase 14 match identity sources must be a data frame or list", call. = FALSE)
  }
  append_part(competition, "competition", "source")
  append_part(historical, "historical", "history")
  append_part(accepted_fixtures, "competition", "fixtures", "competition_fixture")
  append_part(accepted_results, "competition", "results", "competition_result")
  append_part(historical_matches, "historical", "history", "martj42_history")
  if (length(dots)) {
    for (name in names(dots)) {
      family <- if (grepl("hist|martj|history", name, ignore.case = TRUE)) "historical" else "competition"
      kind <- if (grepl("result", name, ignore.case = TRUE)) "results" else if (grepl("fixture", name, ignore.case = TRUE)) "fixtures" else "source"
      append_part(dots[[name]], family, kind)
    }
  }
  if (!length(parts)) return(phase14_match_state_empty_identity_rows()[0, , drop = FALSE])
  output <- do.call(rbind, parts)
  row.names(output) <- NULL
  output
}

phase14_match_state_identity_projection <- function(row) {
  values <- c(
    paste0("source_family=", phase14_match_state_canonical_scalar(row$source_family)),
    paste0("source_id=", phase14_match_state_canonical_scalar(row$source_id)),
    paste0("edition_id=", phase14_match_state_canonical_scalar(row$edition_id)),
    paste0("home_team_id=", phase14_match_state_canonical_scalar(row$home_team_id)),
    paste0("away_team_id=", phase14_match_state_canonical_scalar(row$away_team_id)),
    paste0("scheduled_at_utc=", phase14_match_state_canonical_scalar(row$scheduled_at_utc)),
    paste0("match_date=", phase14_match_state_canonical_scalar(row$match_date)),
    paste0("neutral=", phase14_match_state_canonical_scalar(row$neutral)),
    paste0("venue_context=", phase14_match_state_canonical_scalar(row$venue_context))
  )
  paste(values, collapse = "\x1f")
}

phase14_match_state_semantic_key <- function(row) {
  values <- c(
    phase14_match_state_canonical_scalar(row$home_team_id),
    phase14_match_state_canonical_scalar(row$away_team_id),
    phase14_match_state_canonical_scalar(row$scheduled_at_utc),
    phase14_match_state_canonical_scalar(row$match_date),
    phase14_match_state_canonical_scalar(row$neutral),
    phase14_match_state_canonical_scalar(row$venue_context)
  )
  paste(values, collapse = "\x1f")
}

phase14_match_state_identity_projections <- function(data) {
  paste0(
    "source_family=", phase14_match_state_canonical_column(data$source_family), "\x1f",
    "source_id=", phase14_match_state_canonical_column(data$source_id), "\x1f",
    "edition_id=", phase14_match_state_canonical_column(data$edition_id), "\x1f",
    "home_team_id=", phase14_match_state_canonical_column(data$home_team_id), "\x1f",
    "away_team_id=", phase14_match_state_canonical_column(data$away_team_id), "\x1f",
    "scheduled_at_utc=", phase14_match_state_canonical_column(data$scheduled_at_utc), "\x1f",
    "match_date=", phase14_match_state_canonical_column(data$match_date), "\x1f",
    "neutral=", phase14_match_state_canonical_column(data$neutral), "\x1f",
    "venue_context=", phase14_match_state_canonical_column(data$venue_context)
  )
}

phase14_match_state_semantic_keys <- function(data) {
  paste(
    phase14_match_state_canonical_column(data$home_team_id),
    phase14_match_state_canonical_column(data$away_team_id),
    phase14_match_state_canonical_column(data$scheduled_at_utc),
    phase14_match_state_canonical_column(data$match_date),
    phase14_match_state_canonical_column(data$neutral),
    phase14_match_state_canonical_column(data$venue_context),
    sep = "\x1f"
  )
}

phase14_match_state_row_hash <- function(data) {
  fields <- setdiff(names(data), c("row_sha256", "table_sha256"))
  if (!nrow(data)) return(character(0))
  payloads <- phase14_match_state_payloads(data, fields, separator = "|")
  vapply(payloads, phase14_match_state_digest, character(1))
}

phase14_match_state_table_hash <- function(data) {
  fields <- setdiff(names(data), c("row_sha256", "table_sha256"))
  if (!length(fields)) stop("Phase 14 match identity table has no hashable fields", call. = FALSE)
  header <- paste(fields, collapse = "\x1f")
  rows <- phase14_match_state_payloads(data, fields, separator = "\x1f")
  rows <- sort(rows, method = "radix")
  phase14_match_state_digest(paste(c(header, rows), collapse = "\x1e"))
}

phase14_match_state_order <- function(data) {
  order(
    as.character(data$match_id),
    as.character(data$source_namespace),
    as.character(data$source_match_id),
    as.character(data$source_lineage_id),
    method = "radix",
    na.last = TRUE
  )
}

phase14_match_state_rebuild_identity_hashes <- function(data) {
  schema <- phase14_match_identity_schema()
  data <- data[, intersect(c(schema, names(data)), names(data)), drop = FALSE]
  data <- data[, schema[schema %in% names(data)], drop = FALSE]
  data <- data[phase14_match_state_order(data), , drop = FALSE]
  data$row_sha256 <- phase14_match_state_row_hash(data)
  data$table_sha256 <- rep(phase14_match_state_table_hash(data), nrow(data))
  data[, schema, drop = FALSE]
}

phase14_match_state_forbidden_projection_field <- function(projection) {
  grepl(
    "(^|\\x1f)(source_status|match_status|completion_method|home_goals|away_goals|regulation_home_goals|regulation_away_goals|final_home_goals|final_away_goals|shootout_home_goals|shootout_away_goals|row_sha256|table_sha256)(=|\\x1f|$)",
    projection,
    perl = TRUE
  )
}

phase14_validate_match_identity_crosswalk <- function(
    crosswalk,
    strict_order = TRUE,
    verify_hashes = TRUE) {
  if (!is.data.frame(crosswalk)) stop("Phase 14 match identity crosswalk must be a data frame", call. = FALSE)
  schema <- phase14_match_identity_schema()
  missing <- setdiff(schema, names(crosswalk))
  if (length(missing)) stop("Phase 14 match identity crosswalk missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  if (!nrow(crosswalk)) stop("Phase 14 match identity crosswalk must contain at least one row", call. = FALSE)
  for (column in c("match_id", "source_namespace", "source_match_id", "source_lineage_id", "edition_id")) {
    values <- as.character(crosswalk[[column]])
    if (any(is.na(values) | !nzchar(trimws(values)))) stop("Phase 14 match identity crosswalk contains missing ", column, call. = FALSE)
  }
  source_key <- paste(crosswalk$source_namespace, crosswalk$source_match_id, sep = "\x1f")
  duplicate_source_keys <- unique(source_key[duplicated(source_key)])
  if (length(duplicate_source_keys)) {
    source_groups <- split(seq_len(nrow(crosswalk)), source_key, drop = TRUE)
    for (key in duplicate_source_keys) {
      indices <- source_groups[[key]]
      ids <- unique(as.character(crosswalk$match_id[indices]))
      if (length(ids) > 1L) stop("Phase 14 match identity source ID is mapped to multiple canonical IDs: ", key, call. = FALSE)
      if (anyDuplicated(as.character(crosswalk$source_lineage_id[indices]))) {
        stop("Phase 14 match identity crosswalk has duplicate source lineage rows: ", key, call. = FALSE)
      }
      projections <- unique(as.character(crosswalk$minting_projection[indices]))
      if (length(projections) > 1L && !all(tolower(as.character(crosswalk$review_state[indices])) %in% c("reviewed", "accepted", "approved"))) {
        stop("Phase 14 unreviewed source identity collision: ", key, call. = FALSE)
      }
    }
  }
  if (any(tolower(as.character(crosswalk$collision_status)) %in% c("unreviewed", "pending"))) {
    stop("Phase 14 match identity crosswalk contains an unreviewed collision", call. = FALSE)
  }
  if (any(phase14_match_state_forbidden_projection_field(as.character(crosswalk$minting_projection)))) {
    stop("Phase 14 match identity minting projection contains mutable score/status fields", call. = FALSE)
  }
  if (isTRUE(verify_hashes)) {
    projection_hash <- vapply(as.character(crosswalk$minting_projection), phase14_match_state_digest, character(1))
    if (any(tolower(as.character(crosswalk$minting_projection_sha256)) != projection_hash)) {
      stop("Phase 14 match identity minting projection hash mismatch", call. = FALSE)
    }
    row_hash <- phase14_match_state_row_hash(crosswalk)
    if (any(tolower(as.character(crosswalk$row_sha256)) != row_hash)) {
      stop("Phase 14 match identity row SHA-256 mismatch", call. = FALSE)
    }
    table_hash <- phase14_match_state_table_hash(crosswalk)
    if (any(tolower(as.character(crosswalk$table_sha256)) != table_hash)) {
      stop("Phase 14 match identity table SHA-256 mismatch", call. = FALSE)
    }
  }
  if (isTRUE(strict_order)) {
    expected_order <- phase14_match_state_order(crosswalk)
    if (!identical(as.integer(expected_order), seq_len(nrow(crosswalk)))) {
      stop("Phase 14 match identity crosswalk ordering is not deterministic", call. = FALSE)
    }
  }
  invisible(TRUE)
}

phase14_match_state_existing_mapping <- function(existing_crosswalk) {
  if (is.null(existing_crosswalk)) return(data.frame())
  phase14_validate_match_identity_crosswalk(existing_crosswalk)
  source_key <- paste(existing_crosswalk$source_namespace, existing_crosswalk$source_match_id, sep = "\x1f")
  mappings <- lapply(unique(source_key), function(key) {
    rows <- existing_crosswalk[source_key == key, , drop = FALSE]
    ids <- unique(as.character(rows$match_id))
    if (length(ids) != 1L) stop("Phase 14 existing crosswalk has an ambiguous source mapping: ", key, call. = FALSE)
    data.frame(source_key = key, match_id = ids[[1L]], stringsAsFactors = FALSE)
  })
  do.call(rbind, mappings)
}

#' Build the durable source-to-canonical match crosswalk.
phase14_build_match_identity_crosswalk <- function(
    sources = NULL,
    competition = NULL,
    historical = NULL,
    accepted_fixtures = NULL,
    accepted_results = NULL,
    historical_matches = NULL,
    existing_crosswalk = NULL,
    schema_version = "phase14-match-identity-v1",
    strict = TRUE,
    ...) {
  schema_version <- as.character(schema_version[[1L]])
  if (is.na(schema_version) || !nzchar(schema_version)) stop("Phase 14 match identity schema version is required", call. = FALSE)
  records <- phase14_match_state_collect_sources(
    sources = sources,
    competition = competition,
    historical = historical,
    accepted_fixtures = accepted_fixtures,
    accepted_results = accepted_results,
    historical_matches = historical_matches,
    dots = list(...)
  )
  if (!nrow(records)) stop("Phase 14 match identity crosswalk has no source rows", call. = FALSE)
  records$identity_projection <- phase14_match_state_identity_projections(records)
  projection_hashes <- vapply(unique(records$identity_projection), phase14_match_state_digest, character(1))
  records$identity_projection_sha256 <- unname(projection_hashes[records$identity_projection])
  records$semantic_key <- phase14_match_state_semantic_keys(records)

  source_key <- paste(records$source_family, records$source_id, sep = "\x1f")
  duplicate_source_keys <- unique(source_key[duplicated(source_key)])
  if (length(duplicate_source_keys)) {
    source_groups <- split(seq_len(nrow(records)), source_key, drop = TRUE)
    for (key in duplicate_source_keys) {
      indices <- source_groups[[key]]
      projections <- unique(records$identity_projection[indices])
      reviewed <- all(tolower(as.character(records$review_state[indices])) %in% c("reviewed", "accepted", "approved")) ||
        all(tolower(as.character(records$collision_status[indices])) %in% c("reviewed", "accepted", "approved"))
      if (length(projections) > 1L && !reviewed) {
        stop("Phase 14 unreviewed source identity collision: ", key, call. = FALSE)
      }
    }
  }

  records$group_key <- paste(records$source_family, records$source_id, sep = "\x1f")
  competition_rows <- which(records$source_family == "competition")
  historical_rows <- which(records$source_family == "historical")
  if (length(competition_rows) && length(historical_rows)) {
    for (index in historical_rows) {
      candidates <- competition_rows[records$semantic_key[competition_rows] == records$semantic_key[[index]]]
      candidate_groups <- unique(records$group_key[candidates])
      if (length(candidate_groups) == 1L) records$group_key[[index]] <- candidate_groups[[1L]]
      if (length(candidate_groups) > 1L) {
        reviewed <- all(tolower(as.character(records$review_state[candidates])) %in% c("reviewed", "accepted", "approved"))
        if (!reviewed) stop("Phase 14 ambiguous cross-source match collision for historical source ID: ", records$source_id[[index]], call. = FALSE)
      }
    }
  }

  existing <- phase14_match_state_existing_mapping(existing_crosswalk)
  existing_rows <- if (is.null(existing_crosswalk)) phase14_match_state_empty_identity_rows()[0, , drop = FALSE] else existing_crosswalk
  group_indices <- split(seq_len(nrow(records)), records$group_key, drop = TRUE)
  existing_match_by_source <- if (nrow(existing)) setNames(existing$match_id, existing$source_key) else character(0)
  group_order <- order(
    records$group_key,
    records$source_family != "competition",
    records$source_namespace != "competition_fixture",
    records$source_namespace,
    records$source_lineage_id,
    method = "radix"
  )
  preferred_indices <- group_order[!duplicated(records$group_key[group_order])]
  group_names <- records$group_key[preferred_indices]
  group_projection <- setNames(records$identity_projection[preferred_indices], group_names)
  group_projection_hash <- setNames(records$identity_projection_sha256[preferred_indices], group_names)
  group_match_id <- setNames(paste0("match-", group_projection_hash), group_names)
  group_collision <- setNames(rep("none", length(group_names)), group_names)
  group_review <- setNames(rep("not_required", length(group_names)), group_names)
  projection_count <- tapply(records$identity_projection, records$group_key, function(values) length(unique(values)))
  collision_groups <- names(projection_count)[projection_count > 1L]
  if (length(collision_groups)) {
    for (group_key in collision_groups) {
      indices <- group_indices[[group_key]]
      cross_source_merge <- any(records$source_family[indices] == "competition") && any(records$source_family[indices] == "historical")
      if (cross_source_merge) next
      reviewed <- all(tolower(as.character(records$review_state[indices])) %in% c("reviewed", "accepted", "approved")) ||
        all(tolower(as.character(records$collision_status[indices])) %in% c("reviewed", "accepted", "approved"))
      if (!reviewed) stop("Phase 14 unreviewed identity projection collision for group: ", group_key, call. = FALSE)
      group_collision[[group_key]] <- "reviewed"
      group_review[[group_key]] <- "reviewed"
    }
  }

  source_keys <- paste(records$source_family, records$source_id, sep = "\x1f")
  row_existing <- if (length(existing_match_by_source)) unname(existing_match_by_source[source_keys]) else rep(NA_character_, nrow(records))
  supplied_present <- !is.na(records$provided_match_id) & nzchar(records$provided_match_id)
  if (nrow(existing) || any(supplied_present)) {
    for (group_key in group_names) {
      indices <- group_indices[[group_key]]
      key_matches <- unique(row_existing[indices][!is.na(row_existing[indices]) & nzchar(row_existing[indices])])
      supplied <- unique(records$provided_match_id[indices][supplied_present[indices]])
      if (length(key_matches) > 1L) stop("Phase 14 existing source mapping is ambiguous for group: ", group_key, call. = FALSE)
      if (length(supplied) > 1L) stop("Phase 14 supplied canonical match IDs conflict for group: ", group_key, call. = FALSE)
      if (length(key_matches)) group_match_id[[group_key]] <- key_matches[[1L]] else
        if (length(supplied)) group_match_id[[group_key]] <- supplied[[1L]]
    }
  }

  candidate_rows <- data.frame(
    schema_version = rep(schema_version, nrow(records)),
    match_id = unname(group_match_id[records$group_key]),
    source_namespace = records$source_namespace,
    source_id = records$source_id,
    source_match_id = records$source_match_id,
    source_lineage_id = records$source_lineage_id,
    edition_id = records$edition_id,
    home_team_id = records$home_team_id,
    away_team_id = records$away_team_id,
    scheduled_at_utc = records$scheduled_at_utc,
    match_date = records$match_date,
    neutral = records$neutral,
    venue_context = records$venue_context,
    minting_projection = unname(group_projection[records$group_key]),
    minting_projection_sha256 = unname(group_projection_hash[records$group_key]),
    competition_lineage_id = records$competition_lineage_id,
    history_lineage_id = records$history_lineage_id,
    collision_status = unname(group_collision[records$group_key]),
    review_state = unname(group_review[records$group_key]),
    row_sha256 = NA_character_,
    table_sha256 = NA_character_,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  row.names(candidate_rows) <- NULL
  candidate_rows <- candidate_rows[, phase14_match_identity_schema(), drop = FALSE]

  if (nrow(existing_rows)) {
    current_lineage_key <- paste(candidate_rows$source_namespace, candidate_rows$source_match_id, candidate_rows$source_lineage_id, sep = "\x1f")
    old_lineage_key <- paste(existing_rows$source_namespace, existing_rows$source_match_id, existing_rows$source_lineage_id, sep = "\x1f")
    existing_rows <- existing_rows[!(old_lineage_key %in% current_lineage_key), , drop = FALSE]
    candidate_rows <- rbind(existing_rows[, phase14_match_identity_schema(), drop = FALSE], candidate_rows)
  }
  output <- phase14_match_state_rebuild_identity_hashes(candidate_rows)
  if (isTRUE(strict)) phase14_validate_match_identity_crosswalk(output, verify_hashes = FALSE)
  output
}

phase14_write_match_identity_crosswalk <- function(crosswalk, path, overwrite = TRUE) {
  phase14_validate_match_identity_crosswalk(crosswalk)
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  if (file.exists(path) && !isTRUE(overwrite)) stop("Phase 14 match identity output already exists", call. = FALSE)
  utils::write.csv(crosswalk, path, row.names = FALSE, na = "", quote = TRUE)
  invisible(path)
}

phase14_canonical_match_schema <- function() {
  c(
    "schema_version", "match_id", "source_namespace", "source_id",
    "source_match_id", "source_lineage_id", "edition_id", "fixture_id",
    "source_group_id", "group_id", "home_team_id", "away_team_id",
    "home_display_name", "away_display_name", "scheduled_at_utc",
    "match_date", "kickoff_confirmed", "confirmed_kickoff_at_utc",
    "neutral", "venue_context", "source_status", "match_status",
    "completion_method", "regulation_home_goals", "regulation_away_goals",
    "final_home_goals", "final_away_goals", "shootout_home_goals",
    "shootout_away_goals", "winner_team_id", "evidence_completed_at_utc",
    "counts_for_standings", "counts_for_form", "source_artifact_id",
    "fixture_source_artifact_id", "competition_lineage_id",
    "history_lineage_id", "source_row_sha256", "row_sha256", "table_sha256"
  )
}

phase14_canonical_match_integer_vector <- function(values, field) {
  text <- trimws(as.character(values))
  output <- rep(NA_integer_, length(text))
  present <- !is.na(text) & nzchar(text)
  if (!any(present)) return(output)
  numeric_values <- suppressWarnings(as.numeric(text[present]))
  invalid <- is.na(numeric_values) | !is.finite(numeric_values) | numeric_values < 0 | numeric_values != floor(numeric_values)
  if (any(invalid)) {
    stop("Phase 14 ", field, " must contain non-negative integer scores", call. = FALSE)
  }
  output[present] <- as.integer(numeric_values)
  output
}

phase14_canonical_match_optional_timestamp <- function(values, field) {
  output <- phase14_match_state_timestamp_vector(values)
  present <- !is.na(values) & nzchar(trimws(as.character(values)))
  if (length(output) && any(present & is.na(output))) {
    stop("Phase 14 ", field, " contains an invalid timestamp", call. = FALSE)
  }
  output
}

phase14_canonical_match_first_nonmissing <- function(data, indices, field, empty_is_missing = TRUE) {
  if (!length(indices) || !field %in% names(data)) return(NA)
  values <- data[[field]][indices]
  present <- !is.na(values)
  if (is.character(values) && isTRUE(empty_is_missing)) present <- present & nzchar(trimws(values))
  if (!any(present)) {
    if (is.character(values)) return(NA_character_)
    if (is.logical(values)) return(NA)
    if (is.integer(values)) return(NA_integer_)
    return(NA_real_)
  }
  values[which(present)[[1L]]]
}

phase14_canonical_match_first_character <- function(data, indices, field) {
  value <- phase14_canonical_match_first_nonmissing(data, indices, field)
  if (length(value) == 0L || is.na(value)) return(NA_character_)
  as.character(value[[1L]])
}

phase14_canonical_match_join_unique <- function(values) {
  values <- as.character(values)
  values <- values[!is.na(values) & nzchar(trimws(values))]
  if (!length(values)) return(NA_character_)
  paste(unique(values), collapse = "|")
}

phase14_canonical_match_source_status_map <- function(values) {
  values <- tolower(trimws(as.character(values)))
  output <- rep(NA_character_, length(values))
  output[values %in% c("scheduled", "not_started", "not-started", "upcoming", "fixture")] <- "scheduled"
  output[values %in% c("live", "in_progress", "in-progress", "inplay", "in_play")] <- "in_progress"
  output[values %in% c("completed", "complete", "finished", "full_time", "full-time", "after_extra_time", "after-extra-time", "after_penalties", "after-penalties", "awarded", "historical_completed")] <- "completed"
  output[values %in% c("postponed", "delayed")] <- "postponed"
  output[values %in% c("abandoned", "cancelled", "canceled", "suspended")] <- "abandoned"
  output
}

phase14_canonical_match_completion_map <- function(values) {
  values <- tolower(trimws(as.character(values)))
  output <- rep(NA_character_, length(values))
  output[values %in% c("scheduled", "not_started", "not-started", "upcoming", "fixture", "live", "in_progress", "in-progress", "inplay", "in_play", "postponed", "delayed", "abandoned", "cancelled", "canceled", "suspended")] <- "not_applicable"
  output[values %in% c("historical_completed")] <- "regulation"
  output[values %in% c("after_extra_time", "after-extra-time")] <- "extra_time"
  output[values %in% c("after_penalties", "after-penalties")] <- "penalties"
  output[values == "awarded"] <- "awarded"
  output
}

phase14_canonical_match_score_pair_complete <- function(home, away) {
  !(is.na(home) & is.na(away)) && !(is.na(home) | is.na(away))
}

phase14_canonical_match_score_pair_missing <- function(home, away) {
  is.na(home) && is.na(away)
}

phase14_canonical_match_collect_inputs <- function(
    inputs = NULL,
    competition = NULL,
    historical = NULL,
    fixtures = NULL,
    results = NULL,
    accepted_fixtures = NULL,
    accepted_results = NULL,
    historical_matches = NULL,
    dots = list()) {
  parts <- list()
  append_part <- function(data, family, kind = "source") {
    if (is.null(data)) return(invisible(NULL))
    if (is.list(data) && !is.data.frame(data)) {
      for (name in names(data)) {
        if (is.null(data[[name]])) next
        nested_kind <- if (identical(family, "historical")) "history" else if (grepl("result", name, ignore.case = TRUE)) "results" else if (grepl("fixture", name, ignore.case = TRUE)) "fixtures" else kind
        append_part(data[[name]], family, nested_kind)
      }
      return(invisible(NULL))
    }
    if (!is.data.frame(data)) stop("Phase 14 canonical match inputs must be data frames or lists of data frames", call. = FALSE)
    if (!nrow(data)) return(invisible(NULL))
    if (identical(kind, "source")) {
      kind <- if (any(c("home_goals", "away_goals", "home_score", "away_score", "final_home_goals", "match_status") %in% names(data))) "results" else "fixtures"
    }
    default_namespace <- if (identical(family, "historical")) "martj42_history" else if (identical(kind, "results")) "competition_result" else "competition_fixture"
    source_namespace <- phase14_match_state_coalesce(data, "source_namespace", default_namespace)
    source_columns <- if (identical(family, "historical")) c("source_match_id", "source_result_id", "match_id", "source_id") else c("source_fixture_id", "uefa_source_fixture_id", "source_match_id", "fixture_id", "match_id", "source_id")
    source_id <- phase14_match_state_coalesce(data, source_columns)
    if (any(is.na(source_id) | !nzchar(trimws(source_id)))) stop("Phase 14 canonical match input requires a non-empty source ID", call. = FALSE)
    source_lineage <- phase14_match_state_coalesce(data, "source_lineage_id")
    source_artifact <- phase14_match_state_coalesce(data, "source_artifact_id")
    explicit_lineage <- !is.na(source_lineage) & nzchar(trimws(source_lineage))
    fallback_lineage <- paste(source_namespace, source_id, sep = "::")
    source_lineage[!explicit_lineage] <- fallback_lineage[!explicit_lineage]
    use_artifact <- !explicit_lineage & !is.na(source_artifact) & nzchar(trimws(source_artifact))
    source_lineage[use_artifact] <- paste(source_artifact[use_artifact], source_id[use_artifact], sep = "::")
    scheduled <- phase14_canonical_match_optional_timestamp(
      phase14_match_state_coalesce(data, c("scheduled_at_utc", "confirmed_kickoff_at_utc", "kickoff_at_utc")),
      "scheduled_at_utc"
    )
    match_date <- phase14_match_state_date_vector(phase14_match_state_coalesce(data, c("match_date", "date")))
    output <- data.frame(
      .source_family = rep(family, nrow(data)),
      .source_kind = rep(kind, nrow(data)),
      .source_namespace = source_namespace,
      .source_id = source_id,
      .source_match_id = source_id,
      .source_lineage_id = source_lineage,
      .provided_match_id = if (identical(family, "historical")) {
        phase14_match_state_coalesce(data, c("canonical_match_id", "canonical_id"))
      } else {
        phase14_match_state_coalesce(data, c("match_id", "canonical_match_id", "canonical_id"))
      },
      .edition_id = phase14_match_state_coalesce(data, "edition_id"),
      .fixture_id = phase14_match_state_coalesce(data, c("fixture_id", "source_fixture_id", "uefa_source_fixture_id")),
      .source_group_id = phase14_match_state_coalesce(data, "source_group_id"),
      .group_id = phase14_match_state_coalesce(data, "group_id"),
      .home_team_id = phase14_match_state_coalesce(data, c("home_team_id", "home_source_team_id", "home_fifa_code", "home_team")),
      .away_team_id = phase14_match_state_coalesce(data, c("away_team_id", "away_source_team_id", "away_fifa_code", "away_team")),
      .home_display_name = phase14_match_state_coalesce(data, c("home_display_name", "home_team")),
      .away_display_name = phase14_match_state_coalesce(data, c("away_display_name", "away_team")),
      .scheduled_at_utc = scheduled,
      .match_date = match_date,
      .kickoff_confirmed = phase14_match_state_bool_vector(phase14_match_state_coalesce(data, "kickoff_confirmed")),
      .confirmed_kickoff_at_utc = phase14_canonical_match_optional_timestamp(phase14_match_state_coalesce(data, "confirmed_kickoff_at_utc"), "confirmed_kickoff_at_utc"),
      .neutral = phase14_match_state_bool_vector(phase14_match_state_coalesce(data, "neutral")),
      .venue_context = phase14_match_state_venue_vector(data),
      .source_status = phase14_match_state_coalesce(data, "source_status"),
      .match_status = phase14_match_state_coalesce(data, "match_status"),
      .completion_method = phase14_match_state_coalesce(data, "completion_method"),
      .regulation_home_goals = phase14_canonical_match_integer_vector(phase14_match_state_coalesce(data, c("regulation_home_goals", "regulation_home_score")), "regulation_home_goals"),
      .regulation_away_goals = phase14_canonical_match_integer_vector(phase14_match_state_coalesce(data, c("regulation_away_goals", "regulation_away_score")), "regulation_away_goals"),
      .final_home_goals = phase14_canonical_match_integer_vector(phase14_match_state_coalesce(data, c("final_home_goals", "final_home_score")), "final_home_goals"),
      .final_away_goals = phase14_canonical_match_integer_vector(phase14_match_state_coalesce(data, c("final_away_goals", "final_away_score")), "final_away_goals"),
      .shootout_home_goals = phase14_canonical_match_integer_vector(phase14_match_state_coalesce(data, c("shootout_home_goals", "shootout_home_score")), "shootout_home_goals"),
      .shootout_away_goals = phase14_canonical_match_integer_vector(phase14_match_state_coalesce(data, c("shootout_away_goals", "shootout_away_score")), "shootout_away_goals"),
      .generic_home_goals = phase14_canonical_match_integer_vector(phase14_match_state_coalesce(data, c("home_goals", "home_score")), "home_goals"),
      .generic_away_goals = phase14_canonical_match_integer_vector(phase14_match_state_coalesce(data, c("away_goals", "away_score")), "away_goals"),
      .winner_team_id = phase14_match_state_coalesce(data, c("winner_team_id", "winner")),
      .evidence_completed_at_utc = phase14_canonical_match_optional_timestamp(phase14_match_state_coalesce(data, c("evidence_completed_at_utc", "completed_at_utc")), "evidence_completed_at_utc"),
      .counts_for_standings = phase14_match_state_bool_vector(phase14_match_state_coalesce(data, "counts_for_standings")),
      .counts_for_form = phase14_match_state_bool_vector(phase14_match_state_coalesce(data, "counts_for_form")),
      .source_artifact_id = source_artifact,
      .fixture_source_artifact_id = phase14_match_state_coalesce(data, "fixture_source_artifact_id"),
      .source_row_sha256 = phase14_match_state_coalesce(data, c("source_row_sha256", "row_sha256")),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
    parts[[length(parts) + 1L]] <<- output
    invisible(NULL)
  }

  append_named <- function(value) {
    if (is.null(value)) return(invisible(NULL))
    if (is.data.frame(value)) {
      family <- if (any(c("source_match_id", "source_result_id", "home_score") %in% names(value))) "historical" else "competition"
      append_part(value, family, if (identical(family, "historical")) "history" else "source")
    } else if (is.list(value)) {
      for (name in names(value)) {
        family <- if (grepl("hist|martj|history", name, ignore.case = TRUE)) "historical" else "competition"
        kind <- if (grepl("result", name, ignore.case = TRUE)) "results" else if (grepl("fixture", name, ignore.case = TRUE)) "fixtures" else if (identical(family, "historical")) "history" else "source"
        append_part(value[[name]], family, kind)
      }
    } else stop("Phase 14 canonical match inputs must be a data frame or list", call. = FALSE)
    invisible(NULL)
  }

  append_named(inputs)
  append_part(competition, "competition", "source")
  append_part(historical, "historical", "history")
  append_part(fixtures, "competition", "fixtures")
  append_part(results, "competition", "results")
  append_part(accepted_fixtures, "competition", "fixtures")
  append_part(accepted_results, "competition", "results")
  append_part(historical_matches, "historical", "history")
  if (length(dots)) {
    for (name in names(dots)) {
      family <- if (grepl("hist|martj|history", name, ignore.case = TRUE)) "historical" else "competition"
      kind <- if (grepl("result", name, ignore.case = TRUE)) "results" else if (grepl("fixture", name, ignore.case = TRUE)) "fixtures" else if (identical(family, "historical")) "history" else "source"
      append_part(dots[[name]], family, kind)
    }
  }
  if (!length(parts)) stop("Phase 14 canonical match inputs contain no rows", call. = FALSE)
  output <- do.call(rbind, parts)
  row.names(output) <- NULL
  output
}

phase14_canonical_match_crosswalk_map <- function(crosswalk) {
  if (is.null(crosswalk)) return(NULL)
  phase14_validate_match_identity_crosswalk(crosswalk)
  source_key <- paste(crosswalk$source_namespace, crosswalk$source_match_id, sep = "\x1f")
  groups <- split(seq_len(nrow(crosswalk)), source_key, drop = TRUE)
  ids <- vapply(groups, function(indices) {
    values <- unique(as.character(crosswalk$match_id[indices]))
    if (length(values) != 1L) stop("Phase 14 crosswalk source link maps to multiple canonical IDs", call. = FALSE)
    values[[1L]]
  }, character(1))
  list(ids = ids, crosswalk = crosswalk)
}

phase14_canonical_match_validate_foreign_links <- function(records) {
  fixture_rows <- records$.source_kind == "fixtures"
  result_rows <- records$.source_kind == "results"
  if (!any(fixture_rows) || !any(result_rows)) return(invisible(TRUE))
  semantic_key <- paste(
    records$.edition_id,
    records$.home_team_id,
    records$.away_team_id,
    records$.scheduled_at_utc,
    records$.match_date,
    sep = "\x1f"
  )
  groups <- split(seq_len(nrow(records)), semantic_key, drop = TRUE)
  for (indices in groups) {
    if (!any(fixture_rows[indices]) || !any(result_rows[indices])) next
    ids <- unique(records$.source_id[indices])
    if (length(ids) > 1L) {
      stop("Phase 14 foreign fixture/result source link: competing source IDs for one match", call. = FALSE)
    }
  }
  invisible(TRUE)
}

phase14_canonical_match_resolve_ids <- function(records, crosswalk, strict = TRUE) {
  phase14_canonical_match_validate_foreign_links(records)
  provided <- as.character(records$.provided_match_id)
  provided[is.na(provided) | !nzchar(trimws(provided))] <- NA_character_
  resolved <- provided
  if (!is.null(crosswalk)) {
    lookup <- phase14_canonical_match_crosswalk_map(crosswalk)
    keys <- paste(records$.source_namespace, records$.source_id, sep = "\x1f")
    mapped <- unname(lookup$ids[keys])
    mapped[is.na(mapped) | !nzchar(trimws(mapped))] <- NA_character_
    conflict <- !is.na(provided) & !is.na(mapped) & provided != mapped
    if (any(conflict)) stop("Phase 14 foreign canonical match link: supplied match_id disagrees with crosswalk", call. = FALSE)
    resolved[is.na(resolved)] <- mapped[is.na(resolved)]
    missing <- is.na(resolved)
    if (any(missing)) {
      stop("Phase 14 foreign or unresolved source link has no canonical match_id", call. = FALSE)
    }
  }
  if (any(is.na(resolved) | !nzchar(trimws(resolved)))) {
    if (isTRUE(strict)) stop("Phase 14 canonical match requires a stable canonical match_id or crosswalk link", call. = FALSE)
    resolved[is.na(resolved) | !nzchar(trimws(resolved))] <- paste0("unresolved-", seq_len(nrow(records))[is.na(resolved) | !nzchar(trimws(resolved))])
  }
  records$.match_id <- resolved
  records
}

phase14_canonical_match_prepare_scores <- function(records, indices, completion_method) {
  regulation_home <- phase14_canonical_match_first_nonmissing(records, indices, ".regulation_home_goals")
  regulation_away <- phase14_canonical_match_first_nonmissing(records, indices, ".regulation_away_goals")
  final_home <- phase14_canonical_match_first_nonmissing(records, indices, ".final_home_goals")
  final_away <- phase14_canonical_match_first_nonmissing(records, indices, ".final_away_goals")
  shootout_home <- phase14_canonical_match_first_nonmissing(records, indices, ".shootout_home_goals")
  shootout_away <- phase14_canonical_match_first_nonmissing(records, indices, ".shootout_away_goals")
  generic_home <- phase14_canonical_match_first_nonmissing(records, indices, ".generic_home_goals")
  generic_away <- phase14_canonical_match_first_nonmissing(records, indices, ".generic_away_goals")

  if (identical(completion_method, "awarded")) {
    if (is.na(final_home) && is.na(final_away) && !is.na(generic_home) && !is.na(generic_away)) {
      final_home <- generic_home
      final_away <- generic_away
    }
  } else {
    if (is.na(final_home) && is.na(final_away) && !is.na(regulation_home) && !is.na(regulation_away)) {
      final_home <- regulation_home
      final_away <- regulation_away
    }
    if (is.na(regulation_home) && is.na(regulation_away) && !is.na(final_home) && !is.na(final_away)) {
      regulation_home <- final_home
      regulation_away <- final_away
    }
    if (is.na(regulation_home) && is.na(regulation_away) && is.na(final_home) && is.na(final_away) && !is.na(generic_home) && !is.na(generic_away)) {
      regulation_home <- generic_home
      regulation_away <- generic_away
      final_home <- generic_home
      final_away <- generic_away
    }
  }
  list(
    regulation_home_goals = as.integer(regulation_home),
    regulation_away_goals = as.integer(regulation_away),
    final_home_goals = as.integer(final_home),
    final_away_goals = as.integer(final_away),
    shootout_home_goals = as.integer(shootout_home),
    shootout_away_goals = as.integer(shootout_away)
  )
}

phase14_canonical_match_validate_semantics <- function(
    row,
    strict = TRUE,
    require_evidence = FALSE) {
  scalar_character <- function(field) {
    value <- as.character(row[[field]][[1L]])
    if (is.na(value) || !nzchar(trimws(value))) NA_character_ else trimws(value)
  }
  scalar_logical <- function(field) {
    value <- row[[field]][[1L]]
    if (length(value) == 0L || is.na(value)) NA else isTRUE(value)
  }
  score <- function(field) row[[field]][[1L]]
  fail <- function(message) stop("Phase 14 canonical match semantic validation: ", message, call. = FALSE)

  source_status <- scalar_character("source_status")
  match_status <- scalar_character("match_status")
  completion_method <- scalar_character("completion_method")
  if (is.na(source_status)) fail("source_status is required")
  if (is.na(match_status) || !match_status %in% c("scheduled", "in_progress", "completed", "postponed", "abandoned")) {
    fail("match_status is unresolved or outside the canonical lifecycle")
  }
  if (is.na(completion_method) || !completion_method %in% c("not_applicable", "regulation", "extra_time", "penalties", "awarded")) {
    fail("completion_method is unresolved or outside the canonical enum")
  }

  mapped_status <- phase14_canonical_match_source_status_map(source_status)[[1L]]
  mapped_completion <- phase14_canonical_match_completion_map(source_status)[[1L]]
  if (is.na(mapped_status)) fail("source_status is unmapped")
  if (!identical(mapped_status, match_status)) fail("source_status and match_status disagree")
  if (!is.na(mapped_completion) && !identical(mapped_completion, completion_method)) fail("source_status and completion_method disagree")

  regulation_home <- score("regulation_home_goals")
  regulation_away <- score("regulation_away_goals")
  final_home <- score("final_home_goals")
  final_away <- score("final_away_goals")
  shootout_home <- score("shootout_home_goals")
  shootout_away <- score("shootout_away_goals")
  all_scores <- c(regulation_home, regulation_away, final_home, final_away, shootout_home, shootout_away)
  if (any(!is.na(all_scores) & (all_scores < 0 | all_scores != floor(all_scores)))) fail("scores must be non-negative integers")

  counts_standings <- scalar_logical("counts_for_standings")
  counts_form <- scalar_logical("counts_for_form")
  if (is.na(counts_standings) || is.na(counts_form)) fail("count flags must be explicit TRUE/FALSE")
  evidence <- scalar_character("evidence_completed_at_utc")
  scheduled <- scalar_character("scheduled_at_utc")
  if (!is.na(evidence) && !is.na(scheduled) && evidence < scheduled) fail("evidence_completed_at_utc precedes scheduled kickoff")

  if (!identical(match_status, "completed")) {
    if (!identical(completion_method, "not_applicable")) fail("incomplete lifecycle rows require not_applicable completion")
    if (any(!is.na(all_scores))) fail("incomplete lifecycle rows cannot carry score axes")
    if (!is.na(scalar_character("winner_team_id"))) fail("incomplete lifecycle rows cannot carry a winner")
    if (isTRUE(counts_standings) || isTRUE(counts_form)) fail("incomplete lifecycle rows cannot count for standings or form")
    if (!is.na(evidence)) fail("incomplete lifecycle rows cannot carry completion evidence")
    return(invisible(TRUE))
  }

  if (identical(completion_method, "not_applicable")) fail("completed lifecycle rows require an explicit completion method")
  if (isTRUE(require_evidence) && (isTRUE(counts_standings) || isTRUE(counts_form)) && is.na(evidence)) {
    fail("completed counted rows require evidence_completed_at_utc")
  }
  home_team <- scalar_character("home_team_id")
  away_team <- scalar_character("away_team_id")
  winner <- scalar_character("winner_team_id")
  if (is.na(home_team) || is.na(away_team)) fail("resolved home and away team IDs are required for completed rows")
  if (!is.na(winner) && !winner %in% c(home_team, away_team)) fail("winner_team_id must identify the home or away team")

  check_pair <- function(home, away, label, required = FALSE) {
    if (xor(is.na(home), is.na(away))) fail(paste0(label, " score must be paired"))
    if (isTRUE(required) && (is.na(home) || is.na(away))) fail(paste0(label, " score is required"))
  }
  winner_from_score <- function(home, away) {
    if (home > away) home_team else if (away > home) away_team else NA_character_
  }

  check_pair(regulation_home, regulation_away, "regulation")
  check_pair(final_home, final_away, "final")
  check_pair(shootout_home, shootout_away, "shootout")
  if (identical(completion_method, "regulation")) {
    check_pair(regulation_home, regulation_away, "regulation", TRUE)
    check_pair(final_home, final_away, "final", TRUE)
    if (!identical(regulation_home, final_home) || !identical(regulation_away, final_away)) fail("regulation and final football scores must agree for regulation completion")
    if (!is.na(shootout_home) || !is.na(shootout_away)) fail("shootout scores require penalties completion")
    expected_winner <- winner_from_score(final_home, final_away)
  } else if (identical(completion_method, "extra_time")) {
    check_pair(regulation_home, regulation_away, "regulation", TRUE)
    check_pair(final_home, final_away, "final", TRUE)
    if (final_home < regulation_home || final_away < regulation_away) fail("final football score cannot be below regulation score after extra time")
    if (!is.na(shootout_home) || !is.na(shootout_away)) fail("shootout scores are not valid for extra-time completion")
    expected_winner <- winner_from_score(final_home, final_away)
  } else if (identical(completion_method, "penalties")) {
    check_pair(regulation_home, regulation_away, "regulation", TRUE)
    check_pair(final_home, final_away, "final", TRUE)
    check_pair(shootout_home, shootout_away, "shootout", TRUE)
    if (!identical(final_home, final_away)) fail("penalty completion requires a tied final football score")
    if (identical(shootout_home, shootout_away)) fail("penalty shootout must resolve the tie")
    expected_winner <- winner_from_score(shootout_home, shootout_away)
    if (is.na(winner) || !identical(winner, expected_winner)) fail("penalty winner must match the shootout result")
  } else if (identical(completion_method, "awarded")) {
    check_pair(final_home, final_away, "final", TRUE)
    if (!is.na(regulation_home) || !is.na(regulation_away)) fail("awarded results must not carry regulation football scores")
    if (!is.na(shootout_home) || !is.na(shootout_away)) fail("awarded results must not carry shootout scores")
    if (isTRUE(counts_form)) fail("awarded results are excluded from form")
    expected_winner <- winner_from_score(final_home, final_away)
  } else {
    fail("unsupported completion method")
  }
  if (is.na(expected_winner)) {
    if (!is.na(winner)) fail("a tied football result cannot carry a winner")
  } else if (is.na(winner) || !identical(winner, expected_winner)) {
    fail("winner_team_id does not match the final football result")
  }
  invisible(TRUE)
}

phase14_canonical_match_build_row <- function(
    records,
    indices,
    schema_version,
    strict = TRUE,
    require_evidence = FALSE) {
  competition_indices <- indices[records$.source_family[indices] == "competition"]
  history_indices <- indices[records$.source_family[indices] == "historical"]
  identity_pool <- if (length(competition_indices)) competition_indices else indices
  identity_order <- identity_pool[order(
    records$.source_kind[identity_pool] != "fixtures",
    records$.source_namespace[identity_pool],
    records$.source_lineage_id[identity_pool],
    method = "radix"
  )]
  state_pool <- if (length(competition_indices)) competition_indices else indices
  explicit_status_order <- state_pool[order(
    records$.source_kind[state_pool] != "results",
    records$.match_status[state_pool] != "completed",
    records$.source_lineage_id[state_pool],
    method = "radix"
  )]

  source_status <- phase14_canonical_match_first_character(records, explicit_status_order, ".source_status")
  explicit_match_status <- phase14_canonical_match_first_character(records, explicit_status_order, ".match_status")
  explicit_completion <- phase14_canonical_match_first_character(records, explicit_status_order, ".completion_method")
  generic_home <- phase14_canonical_match_first_nonmissing(records, explicit_status_order, ".generic_home_goals")
  generic_away <- phase14_canonical_match_first_nonmissing(records, explicit_status_order, ".generic_away_goals")
  has_historical_score <- !is.na(generic_home) && !is.na(generic_away)
  if (is.na(source_status) && !is.na(generic_home) && !is.na(generic_away) && length(history_indices)) {
    source_status <- "historical_completed"
  }
  mapped_status <- if (is.na(source_status)) NA_character_ else phase14_canonical_match_source_status_map(source_status)[[1L]]
  if (is.na(mapped_status) && isTRUE(strict)) {
    fail_message <- if (is.na(source_status)) "missing source_status" else paste0("unmapped source_status: ", source_status)
    stop("Phase 14 canonical match cannot resolve ", fail_message, call. = FALSE)
  }
  if (!is.na(explicit_match_status) && !is.na(mapped_status) && !identical(explicit_match_status, mapped_status)) {
    stop("Phase 14 canonical match source_status and match_status disagree", call. = FALSE)
  }
  match_status <- if (!is.na(explicit_match_status)) explicit_match_status else mapped_status
  mapped_completion <- if (is.na(source_status)) NA_character_ else phase14_canonical_match_completion_map(source_status)[[1L]]
  if (!is.na(explicit_completion) && !is.na(mapped_completion) && !identical(explicit_completion, mapped_completion)) {
    stop("Phase 14 canonical match source_status and completion_method disagree", call. = FALSE)
  }
  completion_method <- if (!is.na(explicit_completion)) explicit_completion else mapped_completion
  if (is.na(completion_method) && !is.na(match_status) && !identical(match_status, "completed")) completion_method <- "not_applicable"
  if (is.na(completion_method) && identical(match_status, "completed")) completion_method <- "regulation"
  if (is.na(completion_method) && isTRUE(strict)) stop("Phase 14 canonical match completion_method is unresolved", call. = FALSE)

  scores <- phase14_canonical_match_prepare_scores(records, explicit_status_order, ifelse(is.na(completion_method), "not_applicable", completion_method))
  winner <- phase14_canonical_match_first_character(records, explicit_status_order, ".winner_team_id")
  home_team <- phase14_canonical_match_first_character(records, identity_order, ".home_team_id")
  away_team <- phase14_canonical_match_first_character(records, identity_order, ".away_team_id")
  if (isTRUE(strict) && (is.na(home_team) || is.na(away_team))) stop("Phase 14 canonical match requires resolved home and away team IDs", call. = FALSE)
  if (is.na(home_team)) home_team <- "unresolved_home_team"
  if (is.na(away_team)) away_team <- "unresolved_away_team"
  if (is.na(winner) && identical(match_status, "completed")) {
    winner <- if (identical(completion_method, "penalties")) {
      if (scores$shootout_home_goals > scores$shootout_away_goals) home_team else if (scores$shootout_away_goals > scores$shootout_home_goals) away_team else NA_character_
    } else if (!is.na(scores$final_home_goals) && !is.na(scores$final_away_goals)) {
      if (scores$final_home_goals > scores$final_away_goals) home_team else if (scores$final_away_goals > scores$final_home_goals) away_team else NA_character_
    } else NA_character_
  }

  counts_standings <- phase14_canonical_match_first_nonmissing(records, explicit_status_order, ".counts_for_standings")
  counts_form <- phase14_canonical_match_first_nonmissing(records, explicit_status_order, ".counts_for_form")
  if (is.na(counts_standings)) counts_standings <- identical(match_status, "completed")
  if (is.na(counts_form)) counts_form <- identical(match_status, "completed") && !identical(completion_method, "awarded")
  if (!identical(match_status, "completed")) {
    counts_standings <- FALSE
    counts_form <- FALSE
  }
  if (identical(completion_method, "awarded")) counts_form <- FALSE

  row <- data.frame(
    schema_version = schema_version,
    match_id = as.character(unique(records$.match_id[indices])[[1L]]),
    source_namespace = phase14_canonical_match_first_character(records, explicit_status_order, ".source_namespace"),
    source_id = phase14_canonical_match_first_character(records, explicit_status_order, ".source_id"),
    source_match_id = phase14_canonical_match_first_character(records, explicit_status_order, ".source_match_id"),
    source_lineage_id = phase14_canonical_match_first_character(records, explicit_status_order, ".source_lineage_id"),
    edition_id = phase14_canonical_match_first_character(records, identity_order, ".edition_id"),
    fixture_id = phase14_canonical_match_first_character(records, identity_order, ".fixture_id"),
    source_group_id = phase14_canonical_match_first_character(records, identity_order, ".source_group_id"),
    group_id = phase14_canonical_match_first_character(records, identity_order, ".group_id"),
    home_team_id = home_team,
    away_team_id = away_team,
    home_display_name = phase14_canonical_match_first_character(records, identity_order, ".home_display_name"),
    away_display_name = phase14_canonical_match_first_character(records, identity_order, ".away_display_name"),
    scheduled_at_utc = phase14_canonical_match_first_character(records, identity_order, ".scheduled_at_utc"),
    match_date = phase14_canonical_match_first_character(records, identity_order, ".match_date"),
    kickoff_confirmed = phase14_canonical_match_first_nonmissing(records, identity_order, ".kickoff_confirmed"),
    confirmed_kickoff_at_utc = phase14_canonical_match_first_character(records, identity_order, ".confirmed_kickoff_at_utc"),
    neutral = phase14_canonical_match_first_nonmissing(records, identity_order, ".neutral"),
    venue_context = phase14_canonical_match_first_character(records, identity_order, ".venue_context"),
    source_status = source_status,
    match_status = match_status,
    completion_method = completion_method,
    regulation_home_goals = scores$regulation_home_goals,
    regulation_away_goals = scores$regulation_away_goals,
    final_home_goals = scores$final_home_goals,
    final_away_goals = scores$final_away_goals,
    shootout_home_goals = scores$shootout_home_goals,
    shootout_away_goals = scores$shootout_away_goals,
    winner_team_id = winner,
    evidence_completed_at_utc = phase14_canonical_match_first_character(records, explicit_status_order, ".evidence_completed_at_utc"),
    counts_for_standings = isTRUE(counts_standings),
    counts_for_form = isTRUE(counts_form),
    source_artifact_id = phase14_canonical_match_first_character(records, explicit_status_order, ".source_artifact_id"),
    fixture_source_artifact_id = phase14_canonical_match_first_character(records, identity_order, ".fixture_source_artifact_id"),
    competition_lineage_id = phase14_canonical_match_join_unique(records$.source_lineage_id[competition_indices]),
    history_lineage_id = phase14_canonical_match_join_unique(records$.source_lineage_id[history_indices]),
    source_row_sha256 = phase14_canonical_match_first_character(records, explicit_status_order, ".source_row_sha256"),
    row_sha256 = NA_character_,
    table_sha256 = NA_character_,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  row <- row[, phase14_canonical_match_schema(), drop = FALSE]
  if (isTRUE(strict)) phase14_canonical_match_validate_semantics(row, strict = strict, require_evidence = require_evidence)
  row
}

phase14_canonical_match_build_singletons <- function(
    records,
    indices,
    schema_version,
    strict = TRUE) {
  if (!length(indices)) return(NULL)
  get <- function(field) records[[field]][indices]
  text_present <- function(values) !is.na(values) & nzchar(trimws(as.character(values)))
  choose <- function(primary, fallback) {
    primary <- as.character(primary)
    fallback <- as.character(fallback)
    missing <- !text_present(primary)
    primary[missing] <- fallback[missing]
    primary
  }
  source_status <- get(".source_status")
  generic_home <- get(".generic_home_goals")
  generic_away <- get(".generic_away_goals")
  historical_completed <- records$.source_family[indices] == "historical" &
    !text_present(source_status) & !is.na(generic_home) & !is.na(generic_away)
  source_status[historical_completed] <- "historical_completed"
  mapped_status <- phase14_canonical_match_source_status_map(source_status)
  explicit_status <- get(".match_status")
  status <- choose(explicit_status, mapped_status)
  if (isTRUE(strict) && any(!text_present(mapped_status))) stop("Phase 14 canonical match cannot resolve an unmapped source_status", call. = FALSE)
  status_conflict <- text_present(explicit_status) & text_present(mapped_status) & explicit_status != mapped_status
  if (any(status_conflict)) stop("Phase 14 canonical match source_status and match_status disagree", call. = FALSE)

  mapped_completion <- phase14_canonical_match_completion_map(source_status)
  explicit_completion <- get(".completion_method")
  completion <- choose(explicit_completion, mapped_completion)
  completion[text_present(status) & status != "completed" & !text_present(completion)] <- "not_applicable"
  completion[text_present(status) & status == "completed" & !text_present(completion)] <- "regulation"
  completion_conflict <- text_present(explicit_completion) & text_present(mapped_completion) & explicit_completion != mapped_completion
  if (any(completion_conflict)) stop("Phase 14 canonical match source_status and completion_method disagree", call. = FALSE)
  if (isTRUE(strict) && any(!text_present(completion))) stop("Phase 14 canonical match completion_method is unresolved", call. = FALSE)

  reg_h <- get(".regulation_home_goals")
  reg_a <- get(".regulation_away_goals")
  final_h <- get(".final_home_goals")
  final_a <- get(".final_away_goals")
  shoot_h <- get(".shootout_home_goals")
  shoot_a <- get(".shootout_away_goals")
  final_missing <- is.na(final_h) & is.na(final_a)
  reg_complete <- !is.na(reg_h) & !is.na(reg_a)
  reg_missing <- is.na(reg_h) & is.na(reg_a)
  final_complete <- !is.na(final_h) & !is.na(final_a)
  copy_final <- completion != "awarded" & final_missing & reg_complete
  final_h[copy_final] <- reg_h[copy_final]
  final_a[copy_final] <- reg_a[copy_final]
  copy_reg <- completion != "awarded" & reg_missing & final_complete
  reg_h[copy_reg] <- final_h[copy_reg]
  reg_a[copy_reg] <- final_a[copy_reg]
  fill_generic <- completion != "awarded" & is.na(reg_h) & is.na(reg_a) & is.na(final_h) & is.na(final_a) & !is.na(generic_home) & !is.na(generic_away)
  reg_h[fill_generic] <- generic_home[fill_generic]
  reg_a[fill_generic] <- generic_away[fill_generic]
  final_h[fill_generic] <- generic_home[fill_generic]
  final_a[fill_generic] <- generic_away[fill_generic]
  fill_awarded <- completion == "awarded" & is.na(final_h) & is.na(final_a) & !is.na(generic_home) & !is.na(generic_away)
  final_h[fill_awarded] <- generic_home[fill_awarded]
  final_a[fill_awarded] <- generic_away[fill_awarded]

  home_team <- get(".home_team_id")
  away_team <- get(".away_team_id")
  winner <- get(".winner_team_id")
  expected_winner <- rep(NA_character_, length(indices))
  penalty_winner <- completion == "penalties" & !is.na(shoot_h) & !is.na(shoot_a) & shoot_h != shoot_a
  expected_winner[penalty_winner & shoot_h > shoot_a] <- home_team[penalty_winner & shoot_h > shoot_a]
  expected_winner[penalty_winner & shoot_a > shoot_h] <- away_team[penalty_winner & shoot_a > shoot_h]
  football_winner <- completion != "penalties" & !is.na(final_h) & !is.na(final_a) & final_h != final_a
  expected_winner[football_winner & final_h > final_a] <- home_team[football_winner & final_h > final_a]
  expected_winner[football_winner & final_a > final_h] <- away_team[football_winner & final_a > final_h]
  winner_missing <- !text_present(winner)
  winner[winner_missing & !is.na(expected_winner)] <- expected_winner[winner_missing & !is.na(expected_winner)]

  counts_standings <- get(".counts_for_standings")
  counts_form <- get(".counts_for_form")
  counts_standings[is.na(counts_standings)] <- status[is.na(counts_standings)] == "completed"
  counts_form[is.na(counts_form)] <- status[is.na(counts_form)] == "completed" & completion[is.na(counts_form)] != "awarded"
  counts_standings[status != "completed"] <- FALSE
  counts_form[status != "completed"] <- FALSE
  counts_form[completion == "awarded"] <- FALSE

  output <- data.frame(
    schema_version = rep(schema_version, length(indices)),
    match_id = get(".match_id"),
    source_namespace = get(".source_namespace"),
    source_id = get(".source_id"),
    source_match_id = get(".source_match_id"),
    source_lineage_id = get(".source_lineage_id"),
    edition_id = get(".edition_id"),
    fixture_id = get(".fixture_id"),
    source_group_id = get(".source_group_id"),
    group_id = get(".group_id"),
    home_team_id = home_team,
    away_team_id = away_team,
    home_display_name = get(".home_display_name"),
    away_display_name = get(".away_display_name"),
    scheduled_at_utc = get(".scheduled_at_utc"),
    match_date = get(".match_date"),
    kickoff_confirmed = get(".kickoff_confirmed"),
    confirmed_kickoff_at_utc = get(".confirmed_kickoff_at_utc"),
    neutral = get(".neutral"),
    venue_context = get(".venue_context"),
    source_status = source_status,
    match_status = status,
    completion_method = completion,
    regulation_home_goals = as.integer(reg_h),
    regulation_away_goals = as.integer(reg_a),
    final_home_goals = as.integer(final_h),
    final_away_goals = as.integer(final_a),
    shootout_home_goals = as.integer(shoot_h),
    shootout_away_goals = as.integer(shoot_a),
    winner_team_id = winner,
    evidence_completed_at_utc = get(".evidence_completed_at_utc"),
    counts_for_standings = as.logical(counts_standings),
    counts_for_form = as.logical(counts_form),
    source_artifact_id = get(".source_artifact_id"),
    fixture_source_artifact_id = get(".fixture_source_artifact_id"),
    competition_lineage_id = ifelse(records$.source_family[indices] == "competition", get(".source_lineage_id"), NA_character_),
    history_lineage_id = ifelse(records$.source_family[indices] == "historical", get(".source_lineage_id"), NA_character_),
    source_row_sha256 = get(".source_row_sha256"),
    row_sha256 = NA_character_,
    table_sha256 = NA_character_,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  output <- output[, phase14_canonical_match_schema(), drop = FALSE]
  if (isTRUE(strict) && any(is.na(output$edition_id) | !nzchar(trimws(output$edition_id)))) stop("Phase 14 canonical match requires edition_id", call. = FALSE)
  output
}

phase14_canonical_match_validate_semantics_vectorized <- function(
    data,
    strict = TRUE,
    require_evidence = FALSE) {
  character_values <- function(field) {
    values <- as.character(data[[field]])
    values[is.na(values) | !nzchar(trimws(values))] <- NA_character_
    values
  }
  fail <- function(message) stop("Phase 14 canonical match semantic validation: ", message, call. = FALSE)
  source_status <- character_values("source_status")
  match_status <- character_values("match_status")
  completion <- character_values("completion_method")
  if (any(is.na(source_status))) fail("source_status is required")
  if (any(is.na(match_status) | !match_status %in% c("scheduled", "in_progress", "completed", "postponed", "abandoned"))) fail("match_status is unresolved or outside the canonical lifecycle")
  if (any(is.na(completion) | !completion %in% c("not_applicable", "regulation", "extra_time", "penalties", "awarded"))) fail("completion_method is unresolved or outside the canonical enum")
  mapped_status <- phase14_canonical_match_source_status_map(source_status)
  mapped_completion <- phase14_canonical_match_completion_map(source_status)
  if (any(is.na(mapped_status))) fail("source_status is unmapped")
  if (any(mapped_status != match_status)) fail("source_status and match_status disagree")
  completion_comparable <- !is.na(mapped_completion) & mapped_completion != completion
  if (any(completion_comparable)) fail("source_status and completion_method disagree")

  numeric_fields <- c("regulation_home_goals", "regulation_away_goals", "final_home_goals", "final_away_goals", "shootout_home_goals", "shootout_away_goals")
  scores <- lapply(numeric_fields, function(field) as.numeric(data[[field]]))
  names(scores) <- numeric_fields
  all_scores <- do.call(cbind, scores)
  if (any(!is.na(all_scores) & (all_scores < 0 | all_scores != floor(all_scores)))) fail("scores must be non-negative integers")
  pair_bad <- function(home, away) xor(is.na(home), is.na(away))
  if (any(pair_bad(scores$regulation_home_goals, scores$regulation_away_goals))) fail("regulation score must be paired")
  if (any(pair_bad(scores$final_home_goals, scores$final_away_goals))) fail("final score must be paired")
  if (any(pair_bad(scores$shootout_home_goals, scores$shootout_away_goals))) fail("shootout score must be paired")

  counts_standings <- as.logical(data$counts_for_standings)
  counts_form <- as.logical(data$counts_for_form)
  if (any(is.na(counts_standings) | is.na(counts_form))) fail("count flags must be explicit TRUE/FALSE")
  evidence <- character_values("evidence_completed_at_utc")
  scheduled <- character_values("scheduled_at_utc")
  evidence_order_bad <- !is.na(evidence) & !is.na(scheduled) & evidence < scheduled
  if (any(evidence_order_bad)) fail("evidence_completed_at_utc precedes scheduled kickoff")

  incomplete <- match_status != "completed"
  if (any(incomplete & completion != "not_applicable")) fail("incomplete lifecycle rows require not_applicable completion")
  if (any(incomplete & rowSums(!is.na(all_scores)) > 0L)) fail("incomplete lifecycle rows cannot carry score axes")
  if (any(incomplete & !is.na(character_values("winner_team_id")))) fail("incomplete lifecycle rows cannot carry a winner")
  if (any(incomplete & (counts_standings | counts_form))) fail("incomplete lifecycle rows cannot count for standings or form")
  if (any(incomplete & !is.na(evidence))) fail("incomplete lifecycle rows cannot carry completion evidence")
  completed <- !incomplete
  if (any(completed & completion == "not_applicable")) fail("completed lifecycle rows require an explicit completion method")
  if (isTRUE(require_evidence) && any(completed & (counts_standings | counts_form) & is.na(evidence))) fail("completed counted rows require evidence_completed_at_utc")

  home_team <- character_values("home_team_id")
  away_team <- character_values("away_team_id")
  if (any(completed & (is.na(home_team) | is.na(away_team)))) fail("resolved home and away team IDs are required for completed rows")
  winner <- character_values("winner_team_id")
  winner_bad_team <- !is.na(winner) & !is.na(home_team) & !is.na(away_team) & !(winner %in% c(home_team, away_team))
  if (any(winner_bad_team)) fail("winner_team_id must identify the home or away team")

  reg <- completion == "regulation"
  extra <- completion == "extra_time"
  penalties <- completion == "penalties"
  awarded <- completion == "awarded"
  if (any(completed & reg & (is.na(scores$regulation_home_goals) | is.na(scores$regulation_away_goals) | is.na(scores$final_home_goals) | is.na(scores$final_away_goals)))) fail("regulation and final scores are required for regulation completion")
  if (any(completed & reg & (scores$regulation_home_goals != scores$final_home_goals | scores$regulation_away_goals != scores$final_away_goals))) fail("regulation and final football scores must agree")
  if (any(completed & reg & !is.na(scores$shootout_home_goals) | completed & reg & !is.na(scores$shootout_away_goals))) fail("shootout scores require penalties completion")
  if (any(completed & extra & (is.na(scores$regulation_home_goals) | is.na(scores$regulation_away_goals) | is.na(scores$final_home_goals) | is.na(scores$final_away_goals)))) fail("regulation and final scores are required for extra-time completion")
  if (any(completed & extra & (scores$final_home_goals < scores$regulation_home_goals | scores$final_away_goals < scores$regulation_away_goals))) fail("final football score cannot be below regulation score after extra time")
  if (any(completed & extra & (!is.na(scores$shootout_home_goals) | !is.na(scores$shootout_away_goals)))) fail("shootout scores are not valid for extra-time completion")
  if (any(completed & penalties & (is.na(scores$regulation_home_goals) | is.na(scores$regulation_away_goals) | is.na(scores$final_home_goals) | is.na(scores$final_away_goals) | is.na(scores$shootout_home_goals) | is.na(scores$shootout_away_goals)))) fail("regulation, final, and shootout scores are required for penalties completion")
  if (any(completed & penalties & scores$final_home_goals != scores$final_away_goals)) fail("penalty completion requires a tied final football score")
  if (any(completed & penalties & scores$shootout_home_goals == scores$shootout_away_goals)) fail("penalty shootout must resolve the tie")
  if (any(completed & awarded & (is.na(scores$final_home_goals) | is.na(scores$final_away_goals)))) fail("final score is required for awarded completion")
  if (any(completed & awarded & (!is.na(scores$regulation_home_goals) | !is.na(scores$regulation_away_goals) | !is.na(scores$shootout_home_goals) | !is.na(scores$shootout_away_goals)))) fail("awarded results must not carry regulation or shootout scores")
  if (any(completed & awarded & counts_form)) fail("awarded results are excluded from form")
  if (any(completed & !(reg | extra | penalties | awarded))) fail("unsupported completion method")

  expected_winner <- rep(NA_character_, nrow(data))
  penalty_decided <- completed & penalties & scores$shootout_home_goals != scores$shootout_away_goals
  expected_winner[penalty_decided & scores$shootout_home_goals > scores$shootout_away_goals] <- home_team[penalty_decided & scores$shootout_home_goals > scores$shootout_away_goals]
  expected_winner[penalty_decided & scores$shootout_away_goals > scores$shootout_home_goals] <- away_team[penalty_decided & scores$shootout_away_goals > scores$shootout_home_goals]
  football_decided <- completed & !penalties & !is.na(scores$final_home_goals) & !is.na(scores$final_away_goals) & scores$final_home_goals != scores$final_away_goals
  expected_winner[football_decided & scores$final_home_goals > scores$final_away_goals] <- home_team[football_decided & scores$final_home_goals > scores$final_away_goals]
  expected_winner[football_decided & scores$final_away_goals > scores$final_home_goals] <- away_team[football_decided & scores$final_away_goals > scores$final_home_goals]
  if (any(completed & !is.na(winner) & is.na(expected_winner))) fail("a tied football result cannot carry a winner")
  if (any(completed & !is.na(expected_winner) & (is.na(winner) | winner != expected_winner))) fail("winner_team_id does not match the football result")
  invisible(TRUE)
}

phase14_canonical_match_order <- function(data) {
  order(
    as.character(data$edition_id),
    as.character(data$scheduled_at_utc),
    as.character(data$match_date),
    as.character(data$match_id),
    as.character(data$source_namespace),
    as.character(data$source_id),
    method = "radix",
    na.last = TRUE
  )
}

phase14_canonical_match_rebuild_hashes <- function(data) {
  schema <- phase14_canonical_match_schema()
  data <- data[, schema, drop = FALSE]
  data <- data[phase14_canonical_match_order(data), , drop = FALSE]
  data$row_sha256 <- phase14_match_state_row_hash(data)
  data$table_sha256 <- rep(phase14_match_state_table_hash(data), nrow(data))
  data[, schema, drop = FALSE]
}

phase14_validate_canonical_matches <- function(
    canonical,
    crosswalk = NULL,
    identity_crosswalk = NULL,
    strict_order = TRUE,
    verify_hashes = TRUE,
    strict = TRUE,
    require_evidence = FALSE) {
  if (is.null(crosswalk)) crosswalk <- identity_crosswalk
  if (!is.data.frame(canonical)) stop("Phase 14 canonical matches must be a data frame", call. = FALSE)
  schema <- phase14_canonical_match_schema()
  missing <- setdiff(schema, names(canonical))
  if (length(missing)) stop("Phase 14 canonical matches missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  if (!nrow(canonical)) stop("Phase 14 canonical matches must contain at least one row", call. = FALSE)
  for (field in c("match_id", "source_namespace", "source_id", "source_match_id", "source_lineage_id", "edition_id", "home_team_id", "away_team_id")) {
    values <- as.character(canonical[[field]])
    if (any(is.na(values) | !nzchar(trimws(values)))) stop("Phase 14 canonical matches contain missing ", field, call. = FALSE)
  }
  if (anyDuplicated(as.character(canonical$match_id))) stop("Phase 14 canonical matches must contain one row per canonical match_id", call. = FALSE)
  if (isTRUE(strict_order)) {
    expected_order <- phase14_canonical_match_order(canonical)
    if (!identical(as.integer(expected_order), seq_len(nrow(canonical)))) stop("Phase 14 canonical match ordering is not deterministic", call. = FALSE)
  }
  phase14_canonical_match_validate_semantics_vectorized(
    canonical,
    strict = strict,
    require_evidence = require_evidence
  )
  if (!is.null(crosswalk)) {
    lookup <- phase14_canonical_match_crosswalk_map(crosswalk)
    keys <- paste(canonical$source_namespace, canonical$source_id, sep = "\x1f")
    mapped <- unname(lookup$ids[keys])
    if (any(is.na(mapped) | !nzchar(mapped))) stop("Phase 14 canonical match has a foreign or unresolved crosswalk source link", call. = FALSE)
    if (any(mapped != as.character(canonical$match_id))) stop("Phase 14 canonical match crosswalk link disagrees with match_id", call. = FALSE)
  }
  if (isTRUE(verify_hashes)) {
    expected_rows <- phase14_match_state_row_hash(canonical)
    if (any(tolower(as.character(canonical$row_sha256)) != expected_rows)) stop("Phase 14 canonical match row SHA-256 mismatch", call. = FALSE)
    expected_table <- phase14_match_state_table_hash(canonical)
    if (any(tolower(as.character(canonical$table_sha256)) != expected_table)) stop("Phase 14 canonical match table SHA-256 mismatch", call. = FALSE)
  }
  invisible(TRUE)
}

phase14_build_canonical_matches <- function(
    inputs = NULL,
    competition = NULL,
    historical = NULL,
    fixtures = NULL,
    results = NULL,
    accepted_fixtures = NULL,
    accepted_results = NULL,
    historical_matches = NULL,
    crosswalk = NULL,
    identity_crosswalk = NULL,
    schema_version = "phase14-canonical-match-v1",
    strict = TRUE,
    require_evidence = FALSE,
    ...) {
  if (is.null(crosswalk)) crosswalk <- identity_crosswalk
  records <- phase14_canonical_match_collect_inputs(
    inputs = inputs,
    competition = competition,
    historical = historical,
    fixtures = fixtures,
    results = results,
    accepted_fixtures = accepted_fixtures,
    accepted_results = accepted_results,
    historical_matches = historical_matches,
    dots = list(...)
  )
  records <- phase14_canonical_match_resolve_ids(records, crosswalk, strict = strict)
  group_indices <- split(seq_len(nrow(records)), records$.match_id, drop = TRUE)
  singleton_groups <- vapply(group_indices, length, integer(1)) == 1L
  singleton_indices <- if (any(singleton_groups)) unlist(group_indices[singleton_groups], use.names = FALSE) else integer(0)
  singleton_rows <- phase14_canonical_match_build_singletons(
    records,
    singleton_indices,
    schema_version = schema_version,
    strict = strict
  )
  duplicate_rows <- lapply(group_indices[!singleton_groups], function(indices) {
    phase14_canonical_match_build_row(
      records,
      indices,
      schema_version = schema_version,
      strict = strict,
      require_evidence = require_evidence
    )
  })
  output <- singleton_rows
  if (length(duplicate_rows)) output <- rbind(output, do.call(rbind, duplicate_rows))
  row.names(output) <- NULL
  output <- output[, phase14_canonical_match_schema(), drop = FALSE]
  output <- phase14_canonical_match_rebuild_hashes(output)
  phase14_validate_canonical_matches(
    output,
    crosswalk = crosswalk,
    strict_order = TRUE,
    verify_hashes = FALSE,
    strict = strict,
    require_evidence = require_evidence
  )
  output
}
