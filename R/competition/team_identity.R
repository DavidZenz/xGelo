#' Phase 13 stable team identity and visible normalized-name fallback.

phase13_team_identity_required_columns <- function() {
  c(
    "team_id", "fifa_code", "canonical_name", "aliases",
    "uefa_source_team_id", "uefa_display_name_current"
  )
}

phase13_normalize_team_name <- function(value) {
  value <- as.character(value)
  output <- rep(NA_character_, length(value))
  present <- !is.na(value)
  if (any(present)) {
    transliterated <- iconv(trimws(value[present]), from = "UTF-8", to = "ASCII//TRANSLIT", sub = "")
    transliterated <- tolower(transliterated)
    transliterated <- gsub("[^a-z0-9]+", " ", transliterated)
    output[present] <- trimws(gsub("[[:space:]]+", " ", transliterated))
  }
  output
}

phase13_identity_scalar <- function(value, name, allow_empty = FALSE) {
  if (length(value) != 1L || is.null(value) || is.na(value)) {
    stop("Phase 13 ", name, " must be one non-missing value", call. = FALSE)
  }
  value <- as.character(value[[1L]])
  if (!allow_empty && !nzchar(value)) stop("Phase 13 ", name, " must not be empty", call. = FALSE)
  value
}

phase13_prepare_team_identity_map <- function(identity_map) {
  required <- phase13_team_identity_required_columns()
  if (!is.data.frame(identity_map)) stop("Phase 13 team identity map must be a data frame", call. = FALSE)
  missing <- setdiff(required, names(identity_map))
  if (length(missing)) stop("Phase 13 team identity map missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  if (!nrow(identity_map)) {
    identity_map$normalized_alias <- character(0)
    return(identity_map)
  }
  if (any(is.na(identity_map$team_id) | !nzchar(as.character(identity_map$team_id))) ||
      any(is.na(identity_map$canonical_name) | !nzchar(as.character(identity_map$canonical_name))) ||
      any(is.na(identity_map$uefa_source_team_id) | !nzchar(as.character(identity_map$uefa_source_team_id)))) {
    stop("Phase 13 team identity map contains incomplete stable identity", call. = FALSE)
  }
  if (anyDuplicated(as.character(identity_map$team_id))) stop("Phase 13 team identity map has duplicate team IDs", call. = FALSE)
  if (anyDuplicated(as.character(identity_map$uefa_source_team_id))) stop("Phase 13 team identity map has duplicate UEFA source IDs", call. = FALSE)

  normalized_aliases <- vapply(seq_len(nrow(identity_map)), function(index) {
    aliases <- c(
      as.character(identity_map$canonical_name[[index]]),
      as.character(identity_map$uefa_display_name_current[[index]]),
      unlist(strsplit(as.character(identity_map$aliases[[index]]), "\\|", fixed = FALSE), use.names = FALSE)
    )
    aliases <- unique(phase13_normalize_team_name(aliases))
    aliases <- aliases[!is.na(aliases) & nzchar(aliases)]
    paste(aliases, collapse = "|")
  }, character(1))
  identity_map$normalized_alias <- normalized_aliases
  identity_map
}

phase13_identity_alias_rows <- function(identity_map) {
  rows <- lapply(seq_len(nrow(identity_map)), function(index) {
    aliases <- unlist(strsplit(as.character(identity_map$normalized_alias[[index]]), "\\|", fixed = FALSE), use.names = FALSE)
    aliases <- unique(aliases[!is.na(aliases) & nzchar(aliases)])
    data.frame(
      team_id = as.character(identity_map$team_id[[index]]),
      normalized_alias = aliases,
      stringsAsFactors = FALSE
    )
  })
  if (!length(rows)) return(data.frame(team_id = character(0), normalized_alias = character(0), stringsAsFactors = FALSE))
  do.call(rbind, rows)
}

phase13_identity_result <- function(candidate, source_team_id, source_display_name, method, warning, review_state, normalized_alias) {
  data.frame(
    team_id = as.character(candidate$team_id[[1L]]),
    fifa_code = as.character(candidate$fifa_code[[1L]]),
    canonical_name = as.character(candidate$canonical_name[[1L]]),
    uefa_source_team_id = as.character(candidate$uefa_source_team_id[[1L]]),
    uefa_display_name_current = as.character(candidate$uefa_display_name_current[[1L]]),
    source_team_id = if (is.null(source_team_id) || is.na(source_team_id)) NA_character_ else as.character(source_team_id),
    source_display_name = as.character(source_display_name),
    normalized_alias = as.character(normalized_alias),
    mapping_method = method,
    mapping_warning = warning,
    alias_review_state = review_state,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

#' Resolve direct UEFA IDs first, then deterministic normalized aliases.
phase13_resolve_team_identity <- function(identity_map, source_team_id = NA_character_, display_name) {
  identity_map <- phase13_prepare_team_identity_map(identity_map)
  display_name <- phase13_identity_scalar(display_name, "source display name")
  source_team_id <- if (length(source_team_id) == 0L || is.na(source_team_id) || !nzchar(as.character(source_team_id))) NA_character_ else as.character(source_team_id)

  if (!is.na(source_team_id)) {
    direct <- identity_map[as.character(identity_map$uefa_source_team_id) == source_team_id, , drop = FALSE]
    if (nrow(direct) > 1L) stop("Phase 13 team identity is ambiguous for UEFA source ID: ", source_team_id, call. = FALSE)
    if (nrow(direct) == 1L) {
      return(phase13_identity_result(
        direct, source_team_id, display_name, "source_id", "none", "not_required",
        phase13_normalize_team_name(display_name)
      ))
    }
  }

  normalized <- phase13_normalize_team_name(display_name)
  aliases <- phase13_identity_alias_rows(identity_map)
  matches <- aliases[aliases$normalized_alias == normalized, , drop = FALSE]
  if (nrow(matches) != 1L) {
    if (nrow(matches) > 1L) stop("Phase 13 team identity is ambiguous for normalized display name: ", display_name, call. = FALSE)
    stop("Phase 13 team identity is unresolved for display name: ", display_name, call. = FALSE)
  }
  candidate <- identity_map[as.character(identity_map$team_id) == as.character(matches$team_id[[1L]]), , drop = FALSE]
  warning(
    paste0("Phase 13 team identity used normalized display-name fallback for ", display_name, "; review mapping metadata"),
    call. = FALSE
  )
  phase13_identity_result(
    candidate, source_team_id, display_name, "normalized_display_name",
    "normalized_display_name_requires_review", "pending_review", normalized
  )
}

phase13_normalized_fixture_schema <- function() {
  c(
    "schema_version", "edition_id", "fixture_id", "uefa_source_fixture_id",
    "home_team_id", "away_team_id", "home_uefa_source_team_id", "away_uefa_source_team_id",
    "home_display_name", "away_display_name", "scheduled_at_utc", "status",
    "source_artifact_id", "home_mapping_method", "away_mapping_method",
    "home_mapping_warning", "away_mapping_warning", "row_sha256"
  )
}

phase13_empty_normalized_fixture_rows <- function() {
  output <- as.data.frame(setNames(replicate(length(phase13_normalized_fixture_schema()), character(0), simplify = FALSE), phase13_normalized_fixture_schema()), stringsAsFactors = FALSE)
  output$schema_version <- character(0)
  output
}

phase13_identity_row_hash <- function(data) {
  if (exists("phase13_row_sha256", mode = "function")) return(phase13_row_sha256(data))
  if (!requireNamespace("digest", quietly = TRUE)) stop("digest is required for Phase 13 identity hashes", call. = FALSE)
  fields <- setdiff(names(data), "row_sha256")
  vapply(seq_len(nrow(data)), function(index) {
    values <- as.character(data[index, fields, drop = FALSE])
    values[is.na(values)] <- ""
    digest::digest(paste(values, collapse = "|"), algo = "sha256", serialize = FALSE)
  }, character(1))
}

#' Normalize source-shaped fixture rows without changing source display values.
phase13_normalize_fixture_rows <- function(
    fixtures,
    identity_map,
    edition_id,
    source_artifact_id = "") {
  if (!is.data.frame(fixtures)) stop("Phase 13 fixture source table must be a data frame", call. = FALSE)
  required <- c(
    "source_fixture_id", "home_uefa_source_team_id", "away_uefa_source_team_id",
    "home_display_name", "away_display_name", "scheduled_at_utc", "status"
  )
  missing <- setdiff(required, names(fixtures))
  if (length(missing)) stop("Phase 13 fixture source table missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  edition_id <- phase13_identity_scalar(edition_id, "edition_id")
  source_artifact_id <- phase13_identity_scalar(source_artifact_id, "source_artifact_id", allow_empty = TRUE)
  identity_map <- phase13_prepare_team_identity_map(identity_map)
  if (!nrow(fixtures)) return(phase13_empty_normalized_fixture_rows())

  rows <- lapply(seq_len(nrow(fixtures)), function(index) {
    home <- phase13_resolve_team_identity(
      identity_map,
      fixtures$home_uefa_source_team_id[[index]],
      fixtures$home_display_name[[index]]
    )
    away <- phase13_resolve_team_identity(
      identity_map,
      fixtures$away_uefa_source_team_id[[index]],
      fixtures$away_display_name[[index]]
    )
    if (identical(home$team_id, away$team_id)) stop("Phase 13 fixture cannot contain the same home and away team", call. = FALSE)
    data.frame(
      schema_version = "phase13-normalized-fixture-v1",
      edition_id = edition_id,
      fixture_id = paste(edition_id, fixtures$source_fixture_id[[index]], sep = "-"),
      uefa_source_fixture_id = as.character(fixtures$source_fixture_id[[index]]),
      home_team_id = home$team_id,
      away_team_id = away$team_id,
      home_uefa_source_team_id = home$uefa_source_team_id,
      away_uefa_source_team_id = away$uefa_source_team_id,
      home_display_name = as.character(fixtures$home_display_name[[index]]),
      away_display_name = as.character(fixtures$away_display_name[[index]]),
      scheduled_at_utc = as.character(fixtures$scheduled_at_utc[[index]]),
      status = as.character(fixtures$status[[index]]),
      source_artifact_id = source_artifact_id,
      home_mapping_method = home$mapping_method,
      away_mapping_method = away$mapping_method,
      home_mapping_warning = home$mapping_warning,
      away_mapping_warning = away$mapping_warning,
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  })
  output <- do.call(rbind, rows)
  output$row_sha256 <- phase13_identity_row_hash(output)
  output
}
