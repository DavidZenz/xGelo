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
      if (length(candidates) == 1L) records$group_key[[index]] <- records$group_key[[candidates[[1L]]]]
      if (length(candidates) > 1L) {
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
