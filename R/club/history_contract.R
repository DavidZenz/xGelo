#' Phase 18 pinned historical club corpus contracts.
#'
#' This module deliberately separates auditable input rows from model-eligible
#' rows.  A source or match may be retained with a typed blocked reason, but no
#' unresolved evidence is silently admitted to Phase 19.

phase18_history_source_schema <- function() {
  c(
    "schema_version", "hash_encoding_version", "source_id", "repository_url", "commit_sha", "commit_utc",
    "relative_path", "competition_id", "season_id", "license_id", "license_url",
    "license_sha256", "license_review_state", "license_reviewed_by",
    "license_reviewed_at_utc", "retrieval_utc", "bytes", "raw_sha256",
    "expected_completed_matches", "coverage_reviewed_by", "coverage_reviewed_at_utc",
    "source_status", "blocked_reason", "row_sha256"
  )
}

phase18_normalized_club_match_schema <- function() {
  c(
    "schema_version", "hash_encoding_version", "match_id", "source_id", "source_match_id", "repository_url",
    "commit_sha", "relative_path", "competition_id", "season_id", "stage", "status",
    "event_date", "kickoff_utc", "kickoff_precision", "evidence_observed_at_utc",
    "completion_not_before_utc", "source_available_at_utc", "evidence_available_at_utc",
    "evidence_precision_policy",
    "home_club_id", "away_club_id", "home_display_name", "away_display_name",
    "home_resolution_method", "away_resolution_method", "regulation_home_goals",
    "regulation_away_goals", "extra_time_home_goals", "extra_time_away_goals",
    "final_home_goals", "final_away_goals", "shootout_home_goals",
    "shootout_away_goals", "completion_method", "score_semantics",
    "identity_registry_sha256", "source_row_sha256", "counts_for_model",
    "exclusion_reason", "row_sha256"
  )
}

phase18_history_abort <- function(reason, message, data = list()) {
  condition <- structure(
    c(list(message = as.character(message), call = NULL, reason = reason), data),
    class = c(reason, "phase18_club_history_error", "error", "condition")
  )
  stop(condition)
}

phase18_history_empty <- function(columns) {
  as.data.frame(
    setNames(replicate(length(columns), character(0), simplify = FALSE), columns),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

phase18_history_read_csv <- function(path, schema = NULL) {
  if (!file.exists(path)) {
    if (is.null(schema)) phase18_history_abort("missing_history_artifact", paste0("Missing file: ", path))
    return(phase18_history_empty(schema))
  }
  data <- utils::read.csv(
    path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = NULL,
    colClasses = "character"
  )
  data[] <- lapply(data, function(value) {
    value <- as.character(value)
    value[is.na(value)] <- ""
    value
  })
  data
}

phase18_history_safe_relative_path <- function(value) {
  value <- as.character(value)
  present <- !is.na(value) & nzchar(value)
  if (!all(present)) return(FALSE)
  normalized <- gsub("\\\\", "/", value)
  !grepl("^/|^[A-Za-z]:/", normalized) &
    !vapply(strsplit(normalized, "/", fixed = TRUE), function(parts) any(parts %in% c("", ".", "..")), logical(1))
}

phase18_history_parse_utc <- function(value, field, allow_blank = FALSE) {
  value <- as.character(value)
  blank <- is.na(value) | !nzchar(value)
  if (any(blank) && !allow_blank) phase18_history_abort("invalid_history_time", paste0(field, " contains a missing timestamp"))
  parsed <- rep(as.POSIXct(NA, tz = "UTC"), length(value))
  if (any(!blank)) {
    parsed[!blank] <- as.POSIXct(value[!blank], format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    if (any(is.na(parsed[!blank]))) phase18_history_abort("invalid_history_time", paste0(field, " must contain UTC ISO-8601 timestamps"))
  }
  parsed
}

phase18_history_format_utc <- function(value) format(value, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

phase18_history_canonical_table <- function(data, key) {
  if (nrow(data)) {
    args <- lapply(data[key], function(column) vapply(column, phase18_club_canonical_scalar, character(1)))
    data <- data[do.call(order, c(args, list(na.last = TRUE, method = "radix"))), , drop = FALSE]
    rownames(data) <- NULL
  }
  data
}

phase18_history_table_sha256 <- function(data, key) {
  text <- data
  text[] <- lapply(text, function(column) {
    value <- as.character(column)
    value[is.na(value)] <- ""
    value
  })
  phase18_hash_table_v2(
    text, key = key,
    schema_tag = paste0("club-history-table:", paste(names(text), collapse = ","))
  )
}

phase18_history_row_sha256 <- function(data, hash_col = "row_sha256") {
  text <- data
  text[] <- lapply(text, function(column) {
    value <- as.character(column)
    value[is.na(value)] <- ""
    value
  })
  phase18_hash_row_v2(
    text, exclude = hash_col,
    schema_tag = paste0("club-history-row:", paste(setdiff(names(text), hash_col), collapse = ","))
  )
}

phase18_validate_history_sources <- function(source_manifest, allow_pending = TRUE) {
  schema <- phase18_history_source_schema()
  if (!is.data.frame(source_manifest) || !identical(names(source_manifest), schema)) {
    phase18_history_abort("invalid_history_source_schema", "Historical source inventory must use the exact schema")
  }
  if (!nrow(source_manifest)) return(invisible(TRUE))
  source_manifest[] <- lapply(source_manifest, as.character)
  if (any(source_manifest$schema_version != "phase18-club-history-source-v2") ||
      any(source_manifest$hash_encoding_version != phase18_canonical_encoding_v2())) {
    phase18_history_abort("invalid_history_source_schema", "Unsupported history source schema_version")
  }
  if (anyDuplicated(source_manifest$source_id) || any(!nzchar(source_manifest$source_id))) {
    phase18_history_abort("duplicate_history_source", "Historical source_id values must be non-empty and unique")
  }
  if (any(source_manifest$row_sha256 != phase18_history_row_sha256(source_manifest))) {
    phase18_history_abort("history_source_hash_mismatch", "Historical source row SHA-256 mismatch")
  }
  statuses <- c("active", "blocked_pending_review", "inactive")
  if (any(!source_manifest$source_status %in% statuses)) {
    phase18_history_abort("invalid_history_source_status", "source_status must be active, blocked_pending_review, or inactive")
  }
  active <- source_manifest$source_status == "active"
  if (any(active)) {
    rows <- source_manifest[active, , drop = FALSE]
    if (any(!grepl("^https://github\\.com/openfootball/[a-z0-9-]+$", rows$repository_url))) {
      phase18_history_abort("invalid_history_source_repository", "Active repository URLs must be fixed OpenFootball repositories")
    }
    if (any(!grepl("^[0-9a-f]{40}$", rows$commit_sha))) {
      phase18_history_abort("invalid_history_source_pin", "Active sources require a full lowercase 40-hex commit SHA")
    }
    if (any(!phase18_history_safe_relative_path(rows$relative_path))) {
      phase18_history_abort("unsafe_history_source_path", "Active source paths must be safe relative paths")
    }
    phase18_history_parse_utc(rows$commit_utc, "commit_utc")
    phase18_history_parse_utc(rows$retrieval_utc, "retrieval_utc")
    phase18_history_parse_utc(rows$license_reviewed_at_utc, "license_reviewed_at_utc")
    phase18_history_parse_utc(rows$coverage_reviewed_at_utc, "coverage_reviewed_at_utc")
    if (any(rows$license_review_state != "approved") ||
        any(!nzchar(rows$license_id) | !nzchar(rows$license_url) | !nzchar(rows$license_reviewed_by)) ||
        any(!grepl("^[0-9a-f]{64}$", rows$license_sha256))) {
      phase18_history_abort("unapproved_history_license", "Active sources require reviewed license evidence")
    }
    numeric_bytes <- suppressWarnings(as.numeric(rows$bytes))
    expected <- suppressWarnings(as.integer(rows$expected_completed_matches))
    if (any(is.na(numeric_bytes) | numeric_bytes <= 0) || any(!grepl("^[0-9a-f]{64}$", rows$raw_sha256))) {
      phase18_history_abort("invalid_history_source_hash", "Active sources require positive bytes and a raw SHA-256")
    }
    if (any(is.na(expected) | expected <= 0) || any(!nzchar(rows$coverage_reviewed_by))) {
      phase18_history_abort("unreviewed_history_coverage", "Active sources require a positive owner-reviewed expected match count")
    }
    if (any(nzchar(rows$blocked_reason))) {
      phase18_history_abort("invalid_history_source_status", "Active source rows cannot carry blocked_reason")
    }
  }
  pending <- source_manifest$source_status == "blocked_pending_review"
  if (any(pending) && (!allow_pending || any(!nzchar(source_manifest$blocked_reason[pending])))) {
    phase18_history_abort("unreviewed_history_source", "Pending source rows require an explicit blocked reason")
  }
  invisible(TRUE)
}

phase18_history_parse_score <- function(score_text, semantics) {
  blank <- function() c(home = "", away = "")
  result <- list(regulation = blank(), extra_time = blank(), final = blank(), shootout = blank(), completion_method = "unresolved", valid = FALSE)
  score_text <- trimws(as.character(score_text))
  semantics <- as.character(semantics)
  pair <- function(text) {
    match <- regexec("^([0-9]+)-([0-9]+)$", trimws(text))
    values <- regmatches(trimws(text), match)[[1L]]
    if (length(values) != 3L) return(NULL)
    c(home = values[[2L]], away = values[[3L]])
  }
  if (identical(semantics, "regulation")) {
    value <- pair(score_text)
    if (is.null(value)) return(result)
    result$regulation <- value; result$final <- value; result$completion_method <- "regulation"; result$valid <- TRUE
    return(result)
  }
  if (identical(semantics, "extra_time")) {
    pieces <- strsplit(score_text, ";", fixed = TRUE)[[1L]]
    if (length(pieces) != 2L) return(result)
    regulation <- pair(pieces[[1L]])
    final <- pair(sub("^\\s*aet\\s+", "", pieces[[2L]], ignore.case = TRUE))
    if (is.null(regulation) || is.null(final)) return(result)
    result$regulation <- regulation; result$extra_time <- final; result$final <- final
    result$completion_method <- "extra_time"; result$valid <- TRUE
    return(result)
  }
  if (identical(semantics, "penalties")) {
    pieces <- strsplit(score_text, ";", fixed = TRUE)[[1L]]
    if (length(pieces) != 3L) return(result)
    regulation <- pair(pieces[[1L]])
    final <- pair(sub("^\\s*aet\\s+", "", pieces[[2L]], ignore.case = TRUE))
    shootout <- pair(sub("^\\s*pens\\s+", "", pieces[[3L]], ignore.case = TRUE))
    if (is.null(regulation) || is.null(final) || is.null(shootout)) return(result)
    result$regulation <- regulation; result$extra_time <- final; result$final <- final; result$shootout <- shootout
    result$completion_method <- "penalties"; result$valid <- TRUE
  }
  result
}

phase18_history_identity <- function(registries, display_name, event_at_utc) {
  normalized <- phase18_normalize_club_name(display_name)
  source_id <- paste0("name:", gsub(" ", "_", normalized, fixed = TRUE))
  tryCatch(
    phase18_resolve_club_identity(registries, "openfootball", source_id, display_name, event_at_utc),
    error = function(error) structure(
      list(reason = if (is.null(error$reason)) class(error)[[1L]] else error$reason),
      class = "phase18_unresolved_history_identity"
    )
  )
}

phase18_normalize_club_history <- function(rows, source_row, club_registries, cutoff_utc) {
  required <- c("source_match_id", "event_date", "kickoff_utc", "stage", "status", "home_name", "away_name", "score_text", "score_semantics", "evidence_updated_at_utc")
  if (!is.data.frame(rows) || length(setdiff(required, names(rows)))) {
    phase18_history_abort("invalid_history_match_schema", paste0("Historical matches missing columns: ", paste(setdiff(required, names(rows)), collapse = ", ")))
  }
  phase18_validate_history_sources(source_row)
  if (nrow(source_row) != 1L || source_row$source_status[[1L]] != "active") {
    phase18_history_abort("inactive_history_source", "Normalization requires exactly one active source row")
  }
  phase18_validate_club_registries(club_registries)
  cutoff <- phase18_history_parse_utc(cutoff_utc, "cutoff_utc")[[1L]]
  output <- lapply(seq_len(nrow(rows)), function(index) {
    row <- rows[index, , drop = FALSE]
    date <- as.Date(row$event_date[[1L]], format = "%Y-%m-%d")
    if (is.na(date)) phase18_history_abort("invalid_history_event_date", "event_date must use YYYY-MM-DD")
    kickoff_known <- nzchar(row$kickoff_utc[[1L]])
    event_at <- if (kickoff_known) {
      phase18_history_parse_utc(row$kickoff_utc[[1L]], "kickoff_utc")[[1L]]
    } else {
      as.POSIXct(paste0(row$event_date[[1L]], "T00:00:00Z"), format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    }
    observed_evidence <- if (nzchar(row$evidence_updated_at_utc[[1L]])) {
      phase18_history_parse_utc(row$evidence_updated_at_utc[[1L]], "evidence_updated_at_utc")[[1L]]
    } else if (!kickoff_known) {
      as.POSIXct(date + 1, tz = "UTC")
    } else {
      as.POSIXct(NA, tz = "UTC")
    }
    score <- phase18_history_parse_score(row$score_text[[1L]], row$score_semantics[[1L]])
    completion_floor <- if (!identical(as.character(row$status[[1L]]), "completed")) {
      as.POSIXct(NA, tz = "UTC")
    } else if (!kickoff_known) {
      as.POSIXct(date + 1, tz = "UTC")
    } else {
      event_at + if (score$completion_method %in% c("extra_time", "penalties")) 180 * 60 else 120 * 60
    }
    source_available <- phase18_history_parse_utc(source_row$commit_utc[[1L]], "commit_utc")[[1L]]
    evidence_before_completion <- !is.na(observed_evidence) && !is.na(completion_floor) && observed_evidence < completion_floor
    evidence <- if (is.na(observed_evidence) || evidence_before_completion) {
      as.POSIXct(NA, tz = "UTC")
    } else {
      max(observed_evidence, source_available)
    }
    home <- phase18_history_identity(club_registries, row$home_name[[1L]], phase18_history_format_utc(event_at))
    away <- phase18_history_identity(club_registries, row$away_name[[1L]], phase18_history_format_utc(event_at))
    identity_ok <- !inherits(home, "phase18_unresolved_history_identity") && !inherits(away, "phase18_unresolved_history_identity")
    temporal_ok <- !is.na(evidence) && !is.na(completion_floor) && evidence >= completion_floor && evidence < cutoff
    completed <- identical(as.character(row$status[[1L]]), "completed")
    reason <- if (!completed) "not_completed" else if (!identity_ok) "unresolved_club_identity" else if (!score$valid) "unresolved_score_semantics" else if (evidence_before_completion) "evidence_before_completion" else if (is.na(observed_evidence)) "missing_evidence_time" else if (!temporal_ok) "evidence_not_prior_to_cutoff" else ""
    match_id <- paste0("clubmatch_", substr(phase18_hash_sequence_v2(
      list(source_row$source_id[[1L]], as.character(row$source_match_id[[1L]])),
      domain = "club-history-match-id-v2", names = c("source_id", "source_match_id"),
      types = c("character", "character")
    ), 1L, 24L))
    normalized <- data.frame(
      schema_version = "phase18-club-history-match-v2", hash_encoding_version = phase18_canonical_encoding_v2(), match_id = match_id,
      source_id = source_row$source_id[[1L]], source_match_id = as.character(row$source_match_id[[1L]]),
      repository_url = source_row$repository_url[[1L]], commit_sha = source_row$commit_sha[[1L]],
      relative_path = source_row$relative_path[[1L]], competition_id = source_row$competition_id[[1L]],
      season_id = source_row$season_id[[1L]], stage = as.character(row$stage[[1L]]), status = as.character(row$status[[1L]]),
      event_date = as.character(row$event_date[[1L]]), kickoff_utc = if (kickoff_known) phase18_history_format_utc(event_at) else "",
      kickoff_precision = if (kickoff_known) "instant" else "date",
      evidence_observed_at_utc = if (is.na(observed_evidence)) "" else phase18_history_format_utc(observed_evidence),
      completion_not_before_utc = if (is.na(completion_floor)) "" else phase18_history_format_utc(completion_floor),
      source_available_at_utc = phase18_history_format_utc(source_available),
      evidence_available_at_utc = if (is.na(evidence)) "" else phase18_history_format_utc(evidence),
      evidence_precision_policy = if (kickoff_known) "instant_method_floor" else "date_next_day_utc",
      home_club_id = if (identity_ok) home$club_id[[1L]] else "", away_club_id = if (identity_ok) away$club_id[[1L]] else "",
      home_display_name = as.character(row$home_name[[1L]]), away_display_name = as.character(row$away_name[[1L]]),
      home_resolution_method = if (identity_ok) home$resolution_method[[1L]] else "unresolved",
      away_resolution_method = if (identity_ok) away$resolution_method[[1L]] else "unresolved",
      regulation_home_goals = score$regulation[["home"]], regulation_away_goals = score$regulation[["away"]],
      extra_time_home_goals = score$extra_time[["home"]], extra_time_away_goals = score$extra_time[["away"]],
      final_home_goals = score$final[["home"]], final_away_goals = score$final[["away"]],
      shootout_home_goals = score$shootout[["home"]], shootout_away_goals = score$shootout[["away"]],
      completion_method = score$completion_method, score_semantics = as.character(row$score_semantics[[1L]]),
      identity_registry_sha256 = phase18_club_registry_hash(club_registries), source_row_sha256 = source_row$row_sha256[[1L]],
      counts_for_model = identical(reason, ""), exclusion_reason = reason, row_sha256 = "",
      stringsAsFactors = FALSE, check.names = FALSE
    )
    normalized$row_sha256 <- phase18_history_row_sha256(normalized)
    normalized
  })
  result <- if (length(output)) do.call(rbind, output) else phase18_history_empty(phase18_normalized_club_match_schema())
  phase18_history_canonical_table(result, c("source_id", "source_match_id", "match_id"))
}

phase18_history_corpus_manifest_schema <- function() {
  c(
    "schema_version", "hash_encoding_version", "corpus_id", "cutoff_utc", "created_at_utc", "parser_commit",
    "source_manifest_sha256", "matches_sha256", "coverage_audit_sha256",
    "identity_audit_sha256", "duplicate_audit_sha256", "score_semantics_audit_sha256",
    "temporal_audit_sha256", "registry_clubs_sha256", "registry_source_ids_sha256",
    "registry_aliases_sha256", "club_registry_sha256", "identity_review_sha256",
    "unresolved_identity_sha256", "source_pin_fraction", "license_fraction",
    "lineage_fraction", "identity_fraction", "coverage_gate_passed",
    "duplicate_gate_passed", "score_semantics_gate_passed", "temporal_gate_passed",
    "row_claims_gate_passed", "accepted_for_training", "blocked_reasons", "manifest_sha256"
  )
}

phase18_validate_normalized_club_matches <- function(matches) {
  schema <- phase18_normalized_club_match_schema()
  if (!is.data.frame(matches) || !identical(names(matches), schema)) {
    phase18_history_abort("invalid_history_match_schema", "Normalized matches must use the exact Phase 18 schema")
  }
  if (!nrow(matches)) return(invisible(TRUE))
  if (any(matches$schema_version != "phase18-club-history-match-v2") ||
      any(matches$hash_encoding_version != phase18_canonical_encoding_v2())) {
    phase18_history_abort("invalid_history_match_schema", "Unsupported normalized match schema_version")
  }
  if (anyDuplicated(matches$match_id) || any(!nzchar(matches$match_id))) {
    phase18_history_abort("duplicate_history_match_id", "Normalized match_id values must be non-empty and unique")
  }
  if (any(matches$row_sha256 != phase18_history_row_sha256(matches))) {
    phase18_history_abort("history_match_hash_mismatch", "Normalized match row SHA-256 mismatch")
  }
  invisible(TRUE)
}

phase18_history_logical <- function(value) {
  if (is.logical(value)) return(!is.na(value) & value)
  tolower(as.character(value)) %in% c("true", "t", "1")
}

phase18_history_fraction <- function(numerator, denominator) {
  if (!denominator) 0 else as.numeric(numerator) / as.numeric(denominator)
}

phase18_history_summary_row <- function(schema, values) {
  row <- as.list(setNames(rep("", length(schema)), schema))
  for (name in intersect(names(values), schema)) row[[name]] <- values[[name]]
  as.data.frame(row, stringsAsFactors = FALSE, check.names = FALSE)
}

phase18_history_text_table <- function(data) {
  output <- data
  output[] <- lapply(output, function(value) {
    value <- as.character(value)
    value[is.na(value)] <- ""
    value
  })
  rownames(output) <- NULL
  output
}

phase18_history_validate_identity_snapshots <- function(registries, identity_review, unresolved_identity) {
  phase18_validate_club_registries(registries)
  if (!is.data.frame(identity_review) || !identical(names(identity_review), phase18_club_review_schema())) {
    phase18_history_abort("invalid_history_identity_review", "History owner review snapshot must use the exact canonical-v2 schema")
  }
  if (nrow(identity_review)) {
    if (any(identity_review$schema_version != "phase18-club-review-v2") ||
        any(identity_review$hash_encoding_version != phase18_canonical_encoding_v2()) ||
        any(identity_review$row_sha256 != phase18_club_row_sha256(identity_review)) ||
        any(identity_review$corpus != "historical_inventory") ||
        any(identity_review$review_state != "approved")) {
      phase18_history_abort("invalid_history_identity_review", "History owner review snapshot is not exact approved canonical-v2 evidence")
    }
  }
  if (!is.data.frame(unresolved_identity) || !identical(names(unresolved_identity), phase18_unresolved_club_token_schema())) {
    phase18_history_abort("invalid_history_unresolved_identity", "History unresolved snapshot must use the exact canonical-v2 schema")
  }
  if (nrow(unresolved_identity)) {
    if (any(unresolved_identity$schema_version != "phase18-unresolved-club-token-v2") ||
        any(unresolved_identity$hash_encoding_version != phase18_canonical_encoding_v2()) ||
        any(unresolved_identity$row_sha256 != phase18_club_row_sha256(unresolved_identity)) ||
        any(unresolved_identity$corpus != "historical_inventory")) {
      phase18_history_abort("invalid_history_unresolved_identity", "History unresolved snapshot hash or corpus mismatch")
    }
  }
  invisible(TRUE)
}

phase18_history_recompute_match_state <- function(matches, source_manifest, club_registries, cutoff) {
  count <- nrow(matches)
  result <- list(
    identity_ok = rep(FALSE, count), score_ok = rep(FALSE, count),
    temporal_ok = rep(FALSE, count), lineage_ok = rep(FALSE, count),
    expected_reason = rep("not_completed", count), claim_ok = rep(FALSE, count)
  )
  if (!count) return(result)
  registry_hash <- phase18_club_registry_hash(club_registries)
  for (index in seq_len(count)) {
    match <- matches[index, , drop = FALSE]
    completed <- identical(match$status[[1L]], "completed")
    source <- source_manifest[source_manifest$source_id == match$source_id[[1L]], , drop = FALSE]
    result$lineage_ok[[index]] <- nrow(source) == 1L && source$source_status[[1L]] == "active" &&
      identical(match$source_row_sha256[[1L]], source$row_sha256[[1L]]) &&
      identical(match$repository_url[[1L]], source$repository_url[[1L]]) &&
      identical(match$commit_sha[[1L]], source$commit_sha[[1L]]) &&
      identical(match$relative_path[[1L]], source$relative_path[[1L]]) &&
      identical(match$competition_id[[1L]], source$competition_id[[1L]]) &&
      identical(match$season_id[[1L]], source$season_id[[1L]]) &&
      identical(match$identity_registry_sha256[[1L]], registry_hash)

    event_at <- if (nzchar(match$kickoff_utc[[1L]])) match$kickoff_utc[[1L]] else paste0(match$event_date[[1L]], "T00:00:00Z")
    home <- phase18_history_identity(club_registries, match$home_display_name[[1L]], event_at)
    away <- phase18_history_identity(club_registries, match$away_display_name[[1L]], event_at)
    result$identity_ok[[index]] <- completed &&
      !inherits(home, "phase18_unresolved_history_identity") &&
      !inherits(away, "phase18_unresolved_history_identity") &&
      identical(match$home_club_id[[1L]], home$club_id[[1L]]) &&
      identical(match$away_club_id[[1L]], away$club_id[[1L]])

    method <- match$completion_method[[1L]]
    goals <- suppressWarnings(as.integer(c(match$final_home_goals[[1L]], match$final_away_goals[[1L]])))
    result$score_ok[[index]] <- completed && method %in% c("regulation", "extra_time", "penalties") &&
      all(!is.na(goals) & goals >= 0L) &&
      (method != "penalties" || all(nzchar(c(match$shootout_home_goals[[1L]], match$shootout_away_goals[[1L]]))))

    observed <- phase18_history_parse_utc(match$evidence_observed_at_utc[[1L]], "evidence_observed_at_utc", allow_blank = TRUE)[[1L]]
    stored_floor <- phase18_history_parse_utc(match$completion_not_before_utc[[1L]], "completion_not_before_utc", allow_blank = TRUE)[[1L]]
    stored_source <- phase18_history_parse_utc(match$source_available_at_utc[[1L]], "source_available_at_utc", allow_blank = TRUE)[[1L]]
    stored_effective <- phase18_history_parse_utc(match$evidence_available_at_utc[[1L]], "evidence_available_at_utc", allow_blank = TRUE)[[1L]]
    expected_floor <- as.POSIXct(NA, tz = "UTC")
    if (completed) {
      if (identical(match$kickoff_precision[[1L]], "date") && !nzchar(match$kickoff_utc[[1L]])) {
        expected_floor <- as.POSIXct(as.Date(match$event_date[[1L]]) + 1, tz = "UTC")
      } else if (identical(match$kickoff_precision[[1L]], "instant") && nzchar(match$kickoff_utc[[1L]])) {
        kickoff <- phase18_history_parse_utc(match$kickoff_utc[[1L]], "kickoff_utc")[[1L]]
        expected_floor <- kickoff + if (method %in% c("extra_time", "penalties")) 180 * 60 else 120 * 60
      }
    }
    precompletion <- !is.na(observed) && !is.na(expected_floor) && observed < expected_floor
    expected_effective <- if (is.na(observed) || is.na(stored_source) || precompletion) as.POSIXct(NA, tz = "UTC") else max(observed, stored_source)
    floor_equal <- (is.na(stored_floor) && is.na(expected_floor)) || (!is.na(stored_floor) && !is.na(expected_floor) && identical(as.numeric(stored_floor), as.numeric(expected_floor)))
    effective_equal <- (is.na(stored_effective) && is.na(expected_effective)) || (!is.na(stored_effective) && !is.na(expected_effective) && identical(as.numeric(stored_effective), as.numeric(expected_effective)))
    source_equal <- nrow(source) == 1L && !is.na(stored_source) && identical(match$source_available_at_utc[[1L]], source$commit_utc[[1L]])
    result$temporal_ok[[index]] <- completed && floor_equal && source_equal && effective_equal &&
      !precompletion && !is.na(expected_effective) && expected_effective >= expected_floor && expected_effective < cutoff

    reason <- if (!completed) "not_completed" else if (!result$identity_ok[[index]]) "unresolved_club_identity" else if (!result$score_ok[[index]]) "unresolved_score_semantics" else if (precompletion) "evidence_before_completion" else if (is.na(observed)) "missing_evidence_time" else if (!result$temporal_ok[[index]]) "evidence_not_prior_to_cutoff" else ""
    result$expected_reason[[index]] <- reason
    result$claim_ok[[index]] <- identical(match$exclusion_reason[[1L]], reason) &&
      identical(phase18_history_logical(match$counts_for_model[[1L]]), identical(reason, ""))
  }
  result
}

phase18_audit_club_history <- function(matches, source_manifest, club_registries, cutoff_utc,
                                       corpus_id = "club-history-candidate",
                                       created_at_utc = cutoff_utc,
                                       parser_commit = "working-tree",
                                       identity_review = NULL,
                                       unresolved_identity = NULL,
                                       identity_review_sha256 = NULL,
                                       unresolved_identity_sha256 = NULL) {
  phase18_validate_history_sources(source_manifest)
  phase18_validate_normalized_club_matches(matches)
  phase18_validate_club_registries(club_registries)
  if (is.null(identity_review)) identity_review <- phase18_empty_table(phase18_club_review_schema())
  if (is.null(unresolved_identity)) unresolved_identity <- phase18_empty_table(phase18_unresolved_club_token_schema())
  phase18_history_validate_identity_snapshots(club_registries, identity_review, unresolved_identity)
  cutoff <- phase18_history_parse_utc(cutoff_utc, "cutoff_utc")[[1L]]
  phase18_history_parse_utc(created_at_utc, "created_at_utc")

  active_sources <- source_manifest$source_status == "active"
  pin_ok <- active_sources & grepl("^[0-9a-f]{40}$", source_manifest$commit_sha) &
    grepl("^[0-9a-f]{64}$", source_manifest$raw_sha256) &
    phase18_history_safe_relative_path(source_manifest$relative_path)
  license_ok <- active_sources & source_manifest$license_review_state == "approved" &
    grepl("^[0-9a-f]{64}$", source_manifest$license_sha256)
  source_pin_fraction <- phase18_history_fraction(sum(pin_ok), nrow(source_manifest))
  license_fraction <- phase18_history_fraction(sum(license_ok), nrow(source_manifest))

  coverage_rows <- lapply(seq_len(nrow(source_manifest)), function(index) {
    source <- source_manifest[index, , drop = FALSE]
    observed <- sum(matches$source_id == source$source_id[[1L]] & matches$status == "completed")
    expected <- suppressWarnings(as.integer(source$expected_completed_matches[[1L]]))
    passed <- source$source_status[[1L]] == "active" && !is.na(expected) && expected > 0L && observed == expected
    data.frame(
      schema_version = "phase18-club-history-coverage-audit-1", source_id = source$source_id[[1L]],
      competition_id = source$competition_id[[1L]], season_id = source$season_id[[1L]],
      expected_completed_matches = if (is.na(expected)) "" else as.character(expected),
      observed_completed_matches = as.character(observed), delta = if (is.na(expected)) "" else as.character(observed - expected),
      gate_passed = passed, blocked_reason = if (passed) "" else if (source$source_status[[1L]] != "active") source$blocked_reason[[1L]] else "completed_match_count_mismatch",
      row_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE
    )
  })
  coverage_audit <- if (length(coverage_rows)) do.call(rbind, coverage_rows) else phase18_history_empty(c(
    "schema_version", "source_id", "competition_id", "season_id", "expected_completed_matches",
    "observed_completed_matches", "delta", "gate_passed", "blocked_reason", "row_sha256"
  ))
  coverage_audit$row_sha256 <- phase18_history_row_sha256(coverage_audit)
  coverage_audit <- phase18_history_canonical_table(coverage_audit, c("source_id"))

  completed <- matches$status == "completed"
  active_count <- sum(completed)
  state <- phase18_history_recompute_match_state(matches, source_manifest, club_registries, cutoff)
  identity_resolved <- completed & state$identity_ok
  identity_fraction <- phase18_history_fraction(sum(identity_resolved), active_count)
  identity_gate <- active_count > 0L && identical(identity_fraction, 1) && !nrow(unresolved_identity)
  identity_audit <- data.frame(
    schema_version = "phase18-club-history-identity-audit-1", active_rows = as.character(active_count),
    resolved_rows = as.character(sum(identity_resolved)), unresolved_rows = as.character(active_count - sum(identity_resolved)),
    identity_fraction = sprintf("%.12f", identity_fraction), gate_passed = identity_gate,
    blocked_reason = if (identity_gate) "" else "active_identity_fraction_below_one", row_sha256 = "",
    stringsAsFactors = FALSE, check.names = FALSE
  )
  identity_audit$row_sha256 <- phase18_history_row_sha256(identity_audit)

  duplicate_count <- 0L
  if (active_count) {
    semantic_fields <- c("competition_id", "season_id", "event_date", "home_club_id", "away_club_id", "final_home_goals", "final_away_goals", "shootout_home_goals", "shootout_away_goals")
    active_matches <- phase18_history_text_table(matches[completed, semantic_fields, drop = FALSE])
    keys <- vapply(seq_len(nrow(active_matches)), function(index) phase18_hash_sequence_v2(
      as.list(active_matches[index, , drop = FALSE]), domain = "club-history-semantic-match-v2",
      names = semantic_fields, types = rep("character", length(semantic_fields))
    ), character(1))
    duplicate_count <- sum(duplicated(keys) | duplicated(keys, fromLast = TRUE))
  }
  duplicate_gate <- duplicate_count == 0L
  duplicate_audit <- data.frame(
    schema_version = "phase18-club-history-duplicate-audit-1", active_rows = as.character(active_count),
    unresolved_duplicate_rows = as.character(duplicate_count), gate_passed = duplicate_gate,
    blocked_reason = if (duplicate_gate) "" else "unresolved_semantic_duplicates", row_sha256 = "",
    stringsAsFactors = FALSE, check.names = FALSE
  )
  duplicate_audit$row_sha256 <- phase18_history_row_sha256(duplicate_audit)

  score_valid <- completed & state$score_ok
  unresolved_scores <- active_count - sum(score_valid)
  score_gate <- unresolved_scores == 0L && active_count > 0L
  score_semantics_audit <- data.frame(
    schema_version = "phase18-club-history-score-audit-1", active_rows = as.character(active_count),
    resolved_score_rows = as.character(sum(score_valid)), unresolved_score_rows = as.character(unresolved_scores),
    gate_passed = score_gate, blocked_reason = if (score_gate) "" else "unresolved_score_semantics",
    row_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE
  )
  score_semantics_audit$row_sha256 <- phase18_history_row_sha256(score_semantics_audit)

  temporal_valid <- completed & state$temporal_ok
  temporal_violations <- active_count - sum(temporal_valid)
  temporal_gate <- temporal_violations == 0L && active_count > 0L
  temporal_audit <- data.frame(
    schema_version = "phase18-club-history-temporal-audit-1", cutoff_utc = phase18_history_format_utc(cutoff),
    active_rows = as.character(active_count), prior_evidence_rows = as.character(sum(temporal_valid)),
    temporal_violation_rows = as.character(temporal_violations), gate_passed = temporal_gate,
    blocked_reason = if (temporal_gate) "" else "missing_or_nonprior_evidence", row_sha256 = "",
    stringsAsFactors = FALSE, check.names = FALSE
  )
  temporal_audit$row_sha256 <- phase18_history_row_sha256(temporal_audit)

  lineage_ok <- state$lineage_ok
  lineage_fraction <- phase18_history_fraction(sum(lineage_ok & completed), active_count)
  row_claims_gate <- all(state$claim_ok[completed])
  coverage_gate <- nrow(coverage_audit) > 0L && all(phase18_history_logical(coverage_audit$gate_passed))
  gates <- c(
    source_pin_fraction = identical(source_pin_fraction, 1),
    license_fraction = identical(license_fraction, 1),
    coverage = coverage_gate,
    lineage_fraction = identical(lineage_fraction, 1),
    identity_fraction = identical(identity_fraction, 1),
    duplicate = duplicate_gate,
    score_semantics = score_gate,
    temporal = temporal_gate,
    row_claims = row_claims_gate
  )
  accepted <- length(gates) > 0L && all(gates)
  blocked_reasons <- paste(names(gates)[!gates], collapse = ";")

  hashes <- c(
    source_manifest_sha256 = phase18_history_table_sha256(source_manifest, "source_id"),
    matches_sha256 = phase18_history_table_sha256(matches, c("source_id", "source_match_id", "match_id")),
    coverage_audit_sha256 = phase18_history_table_sha256(coverage_audit, "source_id"),
    identity_audit_sha256 = phase18_history_table_sha256(identity_audit, "schema_version"),
    duplicate_audit_sha256 = phase18_history_table_sha256(duplicate_audit, "schema_version"),
    score_semantics_audit_sha256 = phase18_history_table_sha256(score_semantics_audit, "schema_version"),
    temporal_audit_sha256 = phase18_history_table_sha256(temporal_audit, "schema_version"),
    registry_clubs_sha256 = phase18_history_table_sha256(club_registries$clubs, phase18_club_sort_keys()$clubs),
    registry_source_ids_sha256 = phase18_history_table_sha256(club_registries$source_ids, phase18_club_sort_keys()$source_ids),
    registry_aliases_sha256 = phase18_history_table_sha256(club_registries$aliases, phase18_club_sort_keys()$aliases),
    identity_review_sha256 = phase18_history_table_sha256(identity_review, c("corpus", "source_system", "source_row", "evidence_sha256", "row_sha256")),
    unresolved_identity_sha256 = phase18_history_table_sha256(unresolved_identity, c("corpus", "source_system", "source_row", "evidence_sha256", "row_sha256"))
  )
  if (!is.null(identity_review_sha256) && nzchar(as.character(identity_review_sha256)) && !identical(as.character(identity_review_sha256), hashes[["identity_review_sha256"]])) {
    phase18_history_abort("history_identity_snapshot_mismatch", "Supplied owner-review hash does not match the durable snapshot")
  }
  if (!is.null(unresolved_identity_sha256) && nzchar(as.character(unresolved_identity_sha256)) && !identical(as.character(unresolved_identity_sha256), hashes[["unresolved_identity_sha256"]])) {
    phase18_history_abort("history_identity_snapshot_mismatch", "Supplied unresolved hash does not match the durable snapshot")
  }
  manifest <- data.frame(
    schema_version = "phase18-club-history-corpus-v2", hash_encoding_version = phase18_canonical_encoding_v2(), corpus_id = as.character(corpus_id),
    cutoff_utc = phase18_history_format_utc(cutoff), created_at_utc = as.character(created_at_utc),
    parser_commit = as.character(parser_commit), source_manifest_sha256 = hashes[["source_manifest_sha256"]],
    matches_sha256 = hashes[["matches_sha256"]], coverage_audit_sha256 = hashes[["coverage_audit_sha256"]],
    identity_audit_sha256 = hashes[["identity_audit_sha256"]], duplicate_audit_sha256 = hashes[["duplicate_audit_sha256"]],
    score_semantics_audit_sha256 = hashes[["score_semantics_audit_sha256"]], temporal_audit_sha256 = hashes[["temporal_audit_sha256"]],
    registry_clubs_sha256 = hashes[["registry_clubs_sha256"]], registry_source_ids_sha256 = hashes[["registry_source_ids_sha256"]],
    registry_aliases_sha256 = hashes[["registry_aliases_sha256"]], club_registry_sha256 = phase18_club_registry_hash(club_registries),
    identity_review_sha256 = hashes[["identity_review_sha256"]], unresolved_identity_sha256 = hashes[["unresolved_identity_sha256"]], source_pin_fraction = sprintf("%.12f", source_pin_fraction),
    license_fraction = sprintf("%.12f", license_fraction), lineage_fraction = sprintf("%.12f", lineage_fraction),
    identity_fraction = sprintf("%.12f", identity_fraction), coverage_gate_passed = coverage_gate,
    duplicate_gate_passed = duplicate_gate, score_semantics_gate_passed = score_gate,
    temporal_gate_passed = temporal_gate, row_claims_gate_passed = row_claims_gate, accepted_for_training = accepted,
    blocked_reasons = blocked_reasons, manifest_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE
  )
  manifest$manifest_sha256 <- phase18_history_row_sha256(manifest, "manifest_sha256")
  list(
    source_manifest = phase18_history_canonical_table(source_manifest, "source_id"),
    matches = phase18_history_canonical_table(matches, c("source_id", "source_match_id", "match_id")),
    coverage_audit = coverage_audit, identity_audit = identity_audit,
    duplicate_audit = duplicate_audit, score_semantics_audit = score_semantics_audit,
    temporal_audit = temporal_audit,
    registry_clubs = phase18_history_canonical_table(club_registries$clubs, phase18_club_sort_keys()$clubs),
    registry_source_ids = phase18_history_canonical_table(club_registries$source_ids, phase18_club_sort_keys()$source_ids),
    registry_aliases = phase18_history_canonical_table(club_registries$aliases, phase18_club_sort_keys()$aliases),
    identity_review = phase18_history_canonical_table(identity_review, c("corpus", "source_system", "source_row", "evidence_sha256", "row_sha256")),
    unresolved_identity = phase18_history_canonical_table(unresolved_identity, c("corpus", "source_system", "source_row", "evidence_sha256", "row_sha256")),
    corpus_manifest = manifest
  )
}

phase18_verify_history_source_file <- function(source_row, raw_root) {
  phase18_validate_history_sources(source_row, allow_pending = FALSE)
  if (nrow(source_row) != 1L || source_row$source_status[[1L]] != "active") {
    phase18_history_abort("inactive_history_source", "Source-byte verification requires one active source row")
  }
  root <- normalizePath(raw_root, winslash = "/", mustWork = TRUE)
  relative <- source_row$relative_path[[1L]]
  if (!phase18_history_safe_relative_path(relative)) {
    phase18_history_abort("unsafe_history_source_path", "Historical source path is unsafe")
  }
  candidate <- file.path(root, relative)
  if (!file.exists(candidate) || dir.exists(candidate)) {
    phase18_history_abort("missing_history_source_file", paste0("Declared historical source file is missing: ", relative))
  }
  current <- root
  for (part in strsplit(gsub("\\\\", "/", relative), "/", fixed = TRUE)[[1L]]) {
    current <- file.path(current, part)
    if (nzchar(Sys.readlink(current))) {
      phase18_history_abort("unsafe_history_source_symlink", paste0("Historical source path contains a symlink: ", relative))
    }
  }
  resolved <- normalizePath(candidate, winslash = "/", mustWork = TRUE)
  if (!(identical(resolved, root) || startsWith(resolved, paste0(root, "/")))) {
    phase18_history_abort("unsafe_history_source_path", "Historical source path escapes raw_root")
  }
  observed_bytes <- file.info(resolved)$size
  observed_hash <- digest::digest(file = resolved, algo = "sha256", serialize = FALSE)
  if (!identical(as.character(observed_bytes), as.character(source_row$bytes[[1L]])) ||
      !identical(observed_hash, source_row$raw_sha256[[1L]])) {
    phase18_history_abort("history_source_hash_mismatch", "Historical source bytes or SHA-256 do not match the inventory")
  }
  resolved
}

phase18_history_bundle_files <- function() {
  c(
    source_manifest = "source_manifest.csv", matches = "matches.csv",
    coverage_audit = "coverage_audit.csv", identity_audit = "identity_audit.csv",
    duplicate_audit = "duplicate_audit.csv", score_semantics_audit = "score_semantics_audit.csv",
    temporal_audit = "temporal_audit.csv",
    registry_clubs = "registry_clubs.csv", registry_source_ids = "registry_source_ids.csv",
    registry_aliases = "registry_aliases.csv", identity_review = "identity_review.csv",
    unresolved_identity = "unresolved_identity.csv", corpus_manifest = "corpus_manifest.csv"
  )
}

phase18_history_write_csv <- function(data, path) {
  utils::write.csv(data, path, row.names = FALSE, na = "", quote = TRUE)
  invisible(path)
}

phase18_history_write_bundle_candidate <- function(audit, candidate_root) {
  files <- phase18_history_bundle_files()
  if (!is.list(audit) || !all(names(files) %in% names(audit))) {
    phase18_history_abort("invalid_history_audit", "History audit is missing one or more required tables")
  }
  dir.create(candidate_root, recursive = TRUE, showWarnings = FALSE)
  for (name in names(files)) phase18_history_write_csv(audit[[name]], file.path(candidate_root, files[[name]]))
  invisible(candidate_root)
}

phase18_history_replace_directory <- function(candidate_root, destination_root) {
  parent <- dirname(destination_root)
  dir.create(parent, recursive = TRUE, showWarnings = FALSE)
  backup <- tempfile(paste0(".", basename(destination_root), ".backup-"), tmpdir = parent)
  had_destination <- dir.exists(destination_root)
  if (file.exists(destination_root) && !had_destination) {
    phase18_history_abort("history_publish_failed", "Destination exists and is not a directory")
  }
  if (had_destination && !file.rename(destination_root, backup)) {
    phase18_history_abort("history_publish_failed", "Could not move incumbent history bundle aside")
  }
  committed <- FALSE
  tryCatch({
    if (!file.rename(candidate_root, destination_root)) {
      phase18_history_abort("history_publish_failed", "Could not atomically promote history bundle")
    }
    committed <- TRUE
    if (dir.exists(backup)) unlink(backup, recursive = TRUE, force = TRUE)
  }, error = function(error) {
    if (!committed && had_destination && dir.exists(backup)) file.rename(backup, destination_root)
    stop(error)
  })
  invisible(destination_root)
}

phase18_validate_club_history_corpus <- function(root) {
  if (!dir.exists(root) || nzchar(Sys.readlink(root))) {
    phase18_history_abort("invalid_history_corpus_root", "History corpus root must be a real directory")
  }
  files <- phase18_history_bundle_files()
  actual <- sort(list.files(root, all.files = TRUE, no.. = TRUE, recursive = TRUE, include.dirs = FALSE))
  if (!identical(actual, sort(unname(files)))) {
    phase18_history_abort("invalid_history_corpus_inventory", "History corpus must contain exactly the declared recursive artifacts")
  }
  tables <- lapply(files, function(file) phase18_history_read_csv(file.path(root, file)))
  source_manifest <- tables$source_manifest
  matches <- tables$matches
  manifest <- tables$corpus_manifest
  phase18_validate_history_sources(source_manifest)
  phase18_validate_normalized_club_matches(matches)
  if (!identical(names(manifest), phase18_history_corpus_manifest_schema()) || nrow(manifest) != 1L) {
    phase18_history_abort("invalid_history_corpus_manifest", "Corpus manifest must contain one exact-schema row")
  }
  expected_self_hash <- phase18_history_row_sha256(manifest, "manifest_sha256")
  if (!identical(manifest$manifest_sha256[[1L]], expected_self_hash[[1L]])) {
    phase18_history_abort("history_manifest_hash_mismatch", "Corpus manifest self-hash mismatch")
  }
  if (!identical(manifest$schema_version[[1L]], "phase18-club-history-corpus-v2") ||
      !identical(manifest$hash_encoding_version[[1L]], phase18_canonical_encoding_v2())) {
    phase18_history_abort("invalid_history_corpus_manifest", "Corpus manifest must declare canonical-v2")
  }
  for (name in c("coverage_audit", "identity_audit", "duplicate_audit", "score_semantics_audit", "temporal_audit")) {
    table <- tables[[name]]
    if (!"row_sha256" %in% names(table) || any(table$row_sha256 != phase18_history_row_sha256(table))) {
      phase18_history_abort("history_audit_hash_mismatch", paste0(name, " row SHA-256 mismatch"))
    }
  }
  registries <- list(
    clubs = tables$registry_clubs,
    source_ids = tables$registry_source_ids,
    aliases = tables$registry_aliases
  )
  tryCatch(
    phase18_history_validate_identity_snapshots(registries, tables$identity_review, tables$unresolved_identity),
    error = function(error) phase18_history_abort("history_identity_snapshot_mismatch", conditionMessage(error))
  )
  registry_keys <- phase18_club_sort_keys()
  registry_hashes <- c(
    registry_clubs_sha256 = phase18_history_table_sha256(registries$clubs, registry_keys$clubs),
    registry_source_ids_sha256 = phase18_history_table_sha256(registries$source_ids, registry_keys$source_ids),
    registry_aliases_sha256 = phase18_history_table_sha256(registries$aliases, registry_keys$aliases)
  )
  if (any(vapply(names(registry_hashes), function(field) !identical(registry_hashes[[field]], manifest[[field]][[1L]]), logical(1))) ||
      !identical(phase18_club_registry_hash(registries), manifest$club_registry_sha256[[1L]]) ||
      (nrow(matches) && any(matches$identity_registry_sha256 != manifest$club_registry_sha256[[1L]]))) {
    phase18_history_abort("history_identity_snapshot_mismatch", "Registry snapshots do not match the manifest and normalized match lineage")
  }

  recomputed <- tryCatch(
    phase18_audit_club_history(
      matches, source_manifest, registries, manifest$cutoff_utc[[1L]],
      corpus_id = manifest$corpus_id[[1L]], created_at_utc = manifest$created_at_utc[[1L]],
      parser_commit = manifest$parser_commit[[1L]], identity_review = tables$identity_review,
      unresolved_identity = tables$unresolved_identity
    ),
    error = function(error) phase18_history_abort("history_recomputed_audit_mismatch", conditionMessage(error))
  )
  for (name in names(files)) {
    observed <- phase18_history_text_table(tables[[name]])
    expected <- phase18_history_text_table(recomputed[[name]])
    if (!identical(observed, expected)) {
      phase18_history_abort("history_recomputed_audit_mismatch", paste0(name, " does not equal the independently recomputed table"))
    }
  }
  gates <- c(
    source_pin_fraction = identical(manifest$source_pin_fraction[[1L]], "1.000000000000"),
    license_fraction = identical(manifest$license_fraction[[1L]], "1.000000000000"),
    coverage = phase18_history_logical(manifest$coverage_gate_passed[[1L]]),
    lineage_fraction = identical(manifest$lineage_fraction[[1L]], "1.000000000000"),
    identity_fraction = identical(manifest$identity_fraction[[1L]], "1.000000000000"),
    duplicate = phase18_history_logical(manifest$duplicate_gate_passed[[1L]]),
    score_semantics = phase18_history_logical(manifest$score_semantics_gate_passed[[1L]]),
    temporal = phase18_history_logical(manifest$temporal_gate_passed[[1L]]),
    row_claims = phase18_history_logical(manifest$row_claims_gate_passed[[1L]])
  )
  invisible(list(accepted_for_training = phase18_history_logical(manifest$accepted_for_training[[1L]]), tables = tables, gates = gates))
}

phase18_history_generation_manifest_schema <- function() {
  c(
    "schema_version", "hash_encoding_version", "generation_id", "acceptance_state",
    "audit_manifest_sha256", "accepted_generation_id", "accepted_manifest_sha256",
    "prior_pointer_sha256", "generation_manifest_sha256"
  )
}

phase18_history_pointer_schema <- function() {
  c(
    "schema_version", "hash_encoding_version", "audit_generation_id",
    "accepted_generation_id", "audit_manifest_sha256", "accepted_manifest_sha256",
    "acceptance_state", "blocked_reasons", "generation_manifest_sha256", "pointer_sha256"
  )
}

phase18_history_pointer_sha256 <- function(pointer) {
  fields <- setdiff(phase18_history_pointer_schema(), "pointer_sha256")
  if (!is.list(pointer) || !identical(names(pointer), phase18_history_pointer_schema())) {
    phase18_history_abort("invalid_history_pointer", "History pointer must use the exact ordered schema")
  }
  phase18_hash_sequence_v2(
    unname(pointer[fields]), domain = "club-history-current-pointer-v2",
    names = fields, types = rep("character", length(fields))
  )
}

phase18_history_safe_generation_id <- function(value) {
  length(value) == 1L && !is.na(value) && grepl("^[a-z0-9][a-z0-9-]{0,95}$", as.character(value))
}

phase18_history_read_pointer_file <- function(path) {
  if (!file.exists(path) || dir.exists(path) || nzchar(Sys.readlink(path))) {
    phase18_history_abort("missing_history_pointer", "History current descriptor is missing or unsafe")
  }
  pointer <- jsonlite::read_json(path, simplifyVector = TRUE)
  pointer <- as.list(pointer)
  if (!identical(names(pointer), phase18_history_pointer_schema()) ||
      any(!vapply(pointer, function(value) length(value) == 1L && !is.na(value), logical(1)))) {
    phase18_history_abort("invalid_history_pointer", "History current descriptor has the wrong schema")
  }
  pointer[] <- lapply(pointer, as.character)
  if (!identical(pointer$schema_version, "phase18-club-history-pointer-v2") ||
      !identical(pointer$hash_encoding_version, phase18_canonical_encoding_v2()) ||
      !identical(pointer$pointer_sha256, phase18_history_pointer_sha256(pointer)) ||
      !phase18_history_safe_generation_id(pointer$audit_generation_id) ||
      (!identical(pointer$accepted_generation_id, "") && !phase18_history_safe_generation_id(pointer$accepted_generation_id)) ||
      !pointer$acceptance_state %in% c("accepted", "blocked")) {
    phase18_history_abort("invalid_history_pointer", "History current descriptor failed canonical-v2 validation")
  }
  pointer
}

phase18_history_validate_generation <- function(generation_root) {
  if (!dir.exists(generation_root) || nzchar(Sys.readlink(generation_root))) {
    phase18_history_abort("invalid_history_generation", "History generation root is missing or unsafe")
  }
  manifest_path <- file.path(generation_root, "generation_manifest.csv")
  manifest <- phase18_history_read_csv(manifest_path)
  if (!identical(names(manifest), phase18_history_generation_manifest_schema()) || nrow(manifest) != 1L ||
      !identical(manifest$schema_version[[1L]], "phase18-club-history-generation-v2") ||
      !identical(manifest$hash_encoding_version[[1L]], phase18_canonical_encoding_v2()) ||
      !phase18_history_safe_generation_id(manifest$generation_id[[1L]]) ||
      !identical(manifest$generation_manifest_sha256[[1L]], phase18_history_row_sha256(manifest, "generation_manifest_sha256")[[1L]])) {
    phase18_history_abort("invalid_history_generation", "History generation manifest failed canonical-v2 validation")
  }
  state <- manifest$acceptance_state[[1L]]
  if (!state %in% c("accepted", "blocked")) {
    phase18_history_abort("invalid_history_generation", "History generation has an invalid acceptance state")
  }
  expected <- c(
    "generation_manifest.csv",
    file.path("audit", unname(phase18_history_bundle_files()))
  )
  if (identical(state, "accepted")) {
    expected <- c(expected, file.path("accepted", unname(phase18_history_bundle_files())))
  }
  actual <- sort(list.files(generation_root, all.files = TRUE, no.. = TRUE, recursive = TRUE, include.dirs = FALSE))
  if (!identical(actual, sort(expected))) {
    phase18_history_abort("invalid_history_generation_inventory", "History generation recursive inventory is not exact")
  }
  audit <- phase18_validate_club_history_corpus(file.path(generation_root, "audit"))
  audit_manifest <- audit$tables$corpus_manifest$manifest_sha256[[1L]]
  if (!identical(audit_manifest, manifest$audit_manifest_sha256[[1L]])) {
    phase18_history_abort("invalid_history_generation", "Audit manifest hash is not bound to the generation")
  }
  if (identical(state, "accepted")) {
    accepted <- phase18_validate_club_history_corpus(file.path(generation_root, "accepted"))
    accepted_manifest <- accepted$tables$corpus_manifest$manifest_sha256[[1L]]
    if (!isTRUE(accepted$accepted_for_training) ||
        !identical(manifest$accepted_generation_id[[1L]], manifest$generation_id[[1L]]) ||
        !identical(accepted_manifest, manifest$accepted_manifest_sha256[[1L]])) {
      phase18_history_abort("invalid_history_generation", "Accepted corpus is not bound to its generation")
    }
  }
  invisible(list(manifest = manifest, audit = audit))
}

phase18_read_club_history_current <- function(current_path, generations_root = dirname(current_path)) {
  pointer <- phase18_history_read_pointer_file(current_path)
  audit_root <- file.path(generations_root, pointer$audit_generation_id)
  audit_generation <- phase18_history_validate_generation(audit_root)
  manifest <- audit_generation$manifest
  if (!identical(manifest$generation_manifest_sha256[[1L]], pointer$generation_manifest_sha256) ||
      !identical(manifest$audit_manifest_sha256[[1L]], pointer$audit_manifest_sha256) ||
      !identical(manifest$acceptance_state[[1L]], pointer$acceptance_state)) {
    phase18_history_abort("invalid_history_pointer", "History pointer does not bind its audit generation")
  }
  if (identical(pointer$acceptance_state, "accepted")) {
    if (!identical(pointer$accepted_generation_id, pointer$audit_generation_id) ||
        !identical(pointer$accepted_manifest_sha256, pointer$audit_manifest_sha256)) {
      phase18_history_abort("invalid_history_pointer", "Accepted pointer must advance audit and accepted state together")
    }
  }
  if (nzchar(pointer$accepted_generation_id)) {
    accepted_root <- file.path(generations_root, pointer$accepted_generation_id)
    accepted_generation <- phase18_history_validate_generation(accepted_root)
    accepted_corpus <- phase18_validate_club_history_corpus(file.path(accepted_root, "accepted"))
    if (!isTRUE(accepted_corpus$accepted_for_training) ||
        !identical(accepted_corpus$tables$corpus_manifest$manifest_sha256[[1L]], pointer$accepted_manifest_sha256)) {
      phase18_history_abort("invalid_history_pointer", "History pointer accepted reference is invalid")
    }
  } else if (nzchar(pointer$accepted_manifest_sha256)) {
    phase18_history_abort("invalid_history_pointer", "No-accepted state cannot contain an accepted manifest hash")
  }
  invisible(pointer)
}

phase18_history_call_writer_hook <- function(writer_hook, boundary, ...) {
  if (is.null(writer_hook)) return(invisible(TRUE))
  if (!is.function(writer_hook)) phase18_history_abort("invalid_history_writer_hook", "writer_hook must be a function")
  writer_hook(boundary, ...)
  invisible(TRUE)
}

phase18_publish_club_history_generation <- function(audit, generations_root, current_path, writer_hook = NULL) {
  if (!is.list(audit) || is.null(audit$corpus_manifest) || nrow(audit$corpus_manifest) != 1L) {
    phase18_history_abort("invalid_history_audit", "History publication requires one complete audit")
  }
  dir.create(generations_root, recursive = TRUE, showWarnings = FALSE)
  dir.create(dirname(current_path), recursive = TRUE, showWarnings = FALSE)
  generations_root <- normalizePath(generations_root, winslash = "/", mustWork = TRUE)
  current_parent <- normalizePath(dirname(current_path), winslash = "/", mustWork = TRUE)
  current_path <- file.path(current_parent, basename(current_path))
  lock_path <- paste0(current_path, ".lock")
  if (!dir.create(lock_path, showWarnings = FALSE)) {
    phase18_history_abort("history_publish_locked", "Another history publication owns the current descriptor lock")
  }
  on.exit(if (dir.exists(lock_path)) unlink(lock_path, recursive = TRUE, force = TRUE), add = TRUE)

  prior <- if (file.exists(current_path)) phase18_read_club_history_current(current_path, generations_root) else NULL
  accepted <- phase18_history_logical(audit$corpus_manifest$accepted_for_training[[1L]])
  audit_hash <- as.character(audit$corpus_manifest$manifest_sha256[[1L]])
  accepted_generation_id <- if (accepted) "" else if (is.null(prior)) "" else prior$accepted_generation_id
  accepted_manifest_sha256 <- if (accepted) audit_hash else if (is.null(prior)) "" else prior$accepted_manifest_sha256
  prior_pointer_sha256 <- if (is.null(prior)) "" else prior$pointer_sha256
  generation_seed <- phase18_hash_sequence_v2(
    list(audit_hash, if (accepted) "accepted" else "blocked", accepted_generation_id, accepted_manifest_sha256, prior_pointer_sha256),
    domain = "club-history-generation-id-v2",
    names = c("audit_manifest_sha256", "acceptance_state", "accepted_generation_id", "accepted_manifest_sha256", "prior_pointer_sha256"),
    types = rep("character", 5L)
  )
  generation_id <- paste0(
    gsub("[^a-z0-9-]+", "-", tolower(audit$corpus_manifest$corpus_id[[1L]])), "-",
    substr(generation_seed, 1L, 20L)
  )
  if (!phase18_history_safe_generation_id(generation_id)) {
    phase18_history_abort("invalid_history_generation", "Derived history generation_id is unsafe")
  }
  if (accepted) accepted_generation_id <- generation_id

  candidate <- tempfile(paste0(".", generation_id, ".candidate-"), tmpdir = generations_root)
  dir.create(candidate, recursive = TRUE, showWarnings = FALSE)
  on.exit(if (dir.exists(candidate)) unlink(candidate, recursive = TRUE, force = TRUE), add = TRUE)
  phase18_history_write_bundle_candidate(audit, file.path(candidate, "audit"))
  phase18_validate_club_history_corpus(file.path(candidate, "audit"))
  if (accepted) {
    phase18_history_write_bundle_candidate(audit, file.path(candidate, "accepted"))
    validated <- phase18_validate_club_history_corpus(file.path(candidate, "accepted"))
    if (!isTRUE(validated$accepted_for_training)) {
      phase18_history_abort("history_publish_failed", "Accepted generation failed independent validation")
    }
  }
  generation_manifest <- data.frame(
    schema_version = "phase18-club-history-generation-v2",
    hash_encoding_version = phase18_canonical_encoding_v2(),
    generation_id = generation_id, acceptance_state = if (accepted) "accepted" else "blocked",
    audit_manifest_sha256 = audit_hash, accepted_generation_id = accepted_generation_id,
    accepted_manifest_sha256 = accepted_manifest_sha256,
    prior_pointer_sha256 = prior_pointer_sha256, generation_manifest_sha256 = "",
    stringsAsFactors = FALSE, check.names = FALSE
  )
  generation_manifest$generation_manifest_sha256 <- phase18_history_row_sha256(generation_manifest, "generation_manifest_sha256")
  phase18_history_write_csv(generation_manifest, file.path(candidate, "generation_manifest.csv"))
  phase18_history_call_writer_hook(writer_hook, "after_stage", candidate = candidate)

  destination <- file.path(generations_root, generation_id)
  if (!dir.exists(destination)) {
    if (!file.rename(candidate, destination)) {
      phase18_history_abort("history_publish_failed", "Could not atomically install immutable history generation")
    }
  } else {
    phase18_history_validate_generation(destination)
  }
  phase18_history_validate_generation(destination)
  phase18_history_call_writer_hook(writer_hook, "after_generation_rename", generation_root = destination)

  pointer <- list(
    schema_version = "phase18-club-history-pointer-v2",
    hash_encoding_version = phase18_canonical_encoding_v2(),
    audit_generation_id = generation_id,
    accepted_generation_id = accepted_generation_id,
    audit_manifest_sha256 = audit_hash,
    accepted_manifest_sha256 = accepted_manifest_sha256,
    acceptance_state = if (accepted) "accepted" else "blocked",
    blocked_reasons = as.character(audit$corpus_manifest$blocked_reasons[[1L]]),
    generation_manifest_sha256 = generation_manifest$generation_manifest_sha256[[1L]],
    pointer_sha256 = ""
  )
  pointer$pointer_sha256 <- phase18_history_pointer_sha256(pointer)
  pointer_candidate <- tempfile(paste0(".", basename(current_path), ".candidate-"), tmpdir = current_parent)
  on.exit(if (file.exists(pointer_candidate)) unlink(pointer_candidate, force = TRUE), add = TRUE)
  jsonlite::write_json(pointer, pointer_candidate, auto_unbox = TRUE, pretty = TRUE, null = "null")
  observed_pointer <- phase18_history_read_pointer_file(pointer_candidate)
  if (!identical(observed_pointer, pointer)) {
    phase18_history_abort("history_publish_failed", "History descriptor read-back differs before commit")
  }
  phase18_history_call_writer_hook(writer_hook, "before_pointer_replace", pointer_candidate = pointer_candidate)
  if (!file.rename(pointer_candidate, current_path)) {
    phase18_history_abort("history_publish_failed", "Could not atomically replace history current descriptor")
  }
  phase18_read_club_history_current(current_path, generations_root)
  pointer
}

phase18_publish_club_history_corpus <- function(...) {
  phase18_history_abort(
    "deprecated_history_publication",
    "Separate audit/accepted publication is disabled; use phase18_publish_club_history_generation"
  )
}
