#' Phase 18 pinned historical club corpus contracts.
#'
#' This module deliberately separates auditable input rows from model-eligible
#' rows.  A source or match may be retained with a typed blocked reason, but no
#' unresolved evidence is silently admitted to Phase 19.

phase18_history_source_schema <- function() {
  c(
    "schema_version", "source_id", "repository_url", "commit_sha", "commit_utc",
    "relative_path", "competition_id", "season_id", "license_id", "license_url",
    "license_sha256", "license_review_state", "license_reviewed_by",
    "license_reviewed_at_utc", "retrieval_utc", "bytes", "raw_sha256",
    "expected_completed_matches", "coverage_reviewed_by", "coverage_reviewed_at_utc",
    "source_status", "blocked_reason", "row_sha256"
  )
}

phase18_normalized_club_match_schema <- function() {
  c(
    "schema_version", "match_id", "source_id", "source_match_id", "repository_url",
    "commit_sha", "relative_path", "competition_id", "season_id", "stage", "status",
    "event_date", "kickoff_utc", "kickoff_precision", "evidence_available_at_utc",
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
  data <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = NULL)
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
  data <- phase18_history_canonical_table(data, key)
  rows <- vapply(seq_len(nrow(data)), function(index) {
    paste(vapply(data[index, , drop = FALSE], phase18_club_canonical_scalar, character(1)), collapse = "\x1f")
  }, character(1))
  digest::digest(paste(c(paste(names(data), collapse = "\x1f"), rows), collapse = "\x1e"), algo = "sha256", serialize = FALSE)
}

phase18_validate_history_sources <- function(source_manifest, allow_pending = TRUE) {
  schema <- phase18_history_source_schema()
  if (!is.data.frame(source_manifest) || !identical(names(source_manifest), schema)) {
    phase18_history_abort("invalid_history_source_schema", "Historical source inventory must use the exact schema")
  }
  if (!nrow(source_manifest)) return(invisible(TRUE))
  source_manifest[] <- lapply(source_manifest, as.character)
  if (any(source_manifest$schema_version != "phase18-club-history-source-1")) {
    phase18_history_abort("invalid_history_source_schema", "Unsupported history source schema_version")
  }
  if (anyDuplicated(source_manifest$source_id) || any(!nzchar(source_manifest$source_id))) {
    phase18_history_abort("duplicate_history_source", "Historical source_id values must be non-empty and unique")
  }
  if (any(source_manifest$row_sha256 != phase18_club_row_sha256(source_manifest))) {
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
    evidence <- if (nzchar(row$evidence_updated_at_utc[[1L]])) {
      phase18_history_parse_utc(row$evidence_updated_at_utc[[1L]], "evidence_updated_at_utc")[[1L]]
    } else if (!kickoff_known) {
      as.POSIXct(date + 1, tz = "UTC")
    } else {
      as.POSIXct(NA, tz = "UTC")
    }
    score <- phase18_history_parse_score(row$score_text[[1L]], row$score_semantics[[1L]])
    home <- phase18_history_identity(club_registries, row$home_name[[1L]], phase18_history_format_utc(event_at))
    away <- phase18_history_identity(club_registries, row$away_name[[1L]], phase18_history_format_utc(event_at))
    identity_ok <- !inherits(home, "phase18_unresolved_history_identity") && !inherits(away, "phase18_unresolved_history_identity")
    temporal_ok <- !is.na(evidence) && evidence < cutoff
    completed <- identical(as.character(row$status[[1L]]), "completed")
    reason <- if (!completed) "not_completed" else if (!identity_ok) "unresolved_club_identity" else if (!score$valid) "unresolved_score_semantics" else if (is.na(evidence)) "missing_evidence_time" else if (!temporal_ok) "evidence_not_prior_to_cutoff" else ""
    match_id <- paste0("clubmatch_", substr(digest::digest(
      paste(source_row$source_id[[1L]], row$source_match_id[[1L]], sep = "|"),
      algo = "sha256", serialize = FALSE
    ), 1L, 24L))
    normalized <- data.frame(
      schema_version = "phase18-club-history-match-1", match_id = match_id,
      source_id = source_row$source_id[[1L]], source_match_id = as.character(row$source_match_id[[1L]]),
      repository_url = source_row$repository_url[[1L]], commit_sha = source_row$commit_sha[[1L]],
      relative_path = source_row$relative_path[[1L]], competition_id = source_row$competition_id[[1L]],
      season_id = source_row$season_id[[1L]], stage = as.character(row$stage[[1L]]), status = as.character(row$status[[1L]]),
      event_date = as.character(row$event_date[[1L]]), kickoff_utc = if (kickoff_known) phase18_history_format_utc(event_at) else "",
      kickoff_precision = if (kickoff_known) "instant" else "date",
      evidence_available_at_utc = if (is.na(evidence)) "" else phase18_history_format_utc(evidence),
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
    normalized$row_sha256 <- phase18_club_row_sha256(normalized)
    normalized
  })
  result <- if (length(output)) do.call(rbind, output) else phase18_history_empty(phase18_normalized_club_match_schema())
  phase18_history_canonical_table(result, c("source_id", "source_match_id", "match_id"))
}

phase18_history_corpus_manifest_schema <- function() {
  c(
    "schema_version", "corpus_id", "cutoff_utc", "created_at_utc", "parser_commit",
    "source_manifest_sha256", "matches_sha256", "coverage_audit_sha256",
    "identity_audit_sha256", "duplicate_audit_sha256", "score_semantics_audit_sha256",
    "temporal_audit_sha256", "club_registry_sha256", "identity_review_sha256",
    "unresolved_identity_sha256", "source_pin_fraction", "license_fraction",
    "lineage_fraction", "identity_fraction", "coverage_gate_passed",
    "duplicate_gate_passed", "score_semantics_gate_passed", "temporal_gate_passed",
    "accepted_for_training", "blocked_reasons", "manifest_sha256"
  )
}

phase18_validate_normalized_club_matches <- function(matches) {
  schema <- phase18_normalized_club_match_schema()
  if (!is.data.frame(matches) || !identical(names(matches), schema)) {
    phase18_history_abort("invalid_history_match_schema", "Normalized matches must use the exact Phase 18 schema")
  }
  if (!nrow(matches)) return(invisible(TRUE))
  if (any(matches$schema_version != "phase18-club-history-match-1")) {
    phase18_history_abort("invalid_history_match_schema", "Unsupported normalized match schema_version")
  }
  if (anyDuplicated(matches$match_id) || any(!nzchar(matches$match_id))) {
    phase18_history_abort("duplicate_history_match_id", "Normalized match_id values must be non-empty and unique")
  }
  if (any(matches$row_sha256 != phase18_club_row_sha256(matches))) {
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

phase18_audit_club_history <- function(matches, source_manifest, club_registries, cutoff_utc,
                                       corpus_id = "club-history-candidate",
                                       created_at_utc = cutoff_utc,
                                       parser_commit = "working-tree",
                                       identity_review_sha256 = "",
                                       unresolved_identity_sha256 = "") {
  phase18_validate_history_sources(source_manifest)
  phase18_validate_normalized_club_matches(matches)
  phase18_validate_club_registries(club_registries)
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
  coverage_audit$row_sha256 <- phase18_club_row_sha256(coverage_audit)
  coverage_audit <- phase18_history_canonical_table(coverage_audit, c("source_id"))

  completed <- matches$status == "completed"
  active_count <- sum(completed)
  identity_resolved <- completed & nzchar(matches$home_club_id) & nzchar(matches$away_club_id) &
    !matches$exclusion_reason %in% "unresolved_club_identity"
  identity_fraction <- phase18_history_fraction(sum(identity_resolved), active_count)
  identity_gate <- active_count > 0L && identical(identity_fraction, 1)
  identity_audit <- data.frame(
    schema_version = "phase18-club-history-identity-audit-1", active_rows = as.character(active_count),
    resolved_rows = as.character(sum(identity_resolved)), unresolved_rows = as.character(active_count - sum(identity_resolved)),
    identity_fraction = sprintf("%.12f", identity_fraction), gate_passed = identity_gate,
    blocked_reason = if (identity_gate) "" else "active_identity_fraction_below_one", row_sha256 = "",
    stringsAsFactors = FALSE, check.names = FALSE
  )
  identity_audit$row_sha256 <- phase18_club_row_sha256(identity_audit)

  duplicate_count <- 0L
  if (active_count) {
    semantic_fields <- c("competition_id", "season_id", "event_date", "home_club_id", "away_club_id", "final_home_goals", "final_away_goals", "shootout_home_goals", "shootout_away_goals")
    keys <- do.call(paste, c(lapply(matches[completed, semantic_fields, drop = FALSE], as.character), sep = "\x1f"))
    duplicate_count <- sum(duplicated(keys) | duplicated(keys, fromLast = TRUE))
  }
  duplicate_gate <- duplicate_count == 0L
  duplicate_audit <- data.frame(
    schema_version = "phase18-club-history-duplicate-audit-1", active_rows = as.character(active_count),
    unresolved_duplicate_rows = as.character(duplicate_count), gate_passed = duplicate_gate,
    blocked_reason = if (duplicate_gate) "" else "unresolved_semantic_duplicates", row_sha256 = "",
    stringsAsFactors = FALSE, check.names = FALSE
  )
  duplicate_audit$row_sha256 <- phase18_club_row_sha256(duplicate_audit)

  score_valid <- completed & matches$completion_method %in% c("regulation", "extra_time", "penalties") &
    nzchar(matches$final_home_goals) & nzchar(matches$final_away_goals) &
    !matches$exclusion_reason %in% "unresolved_score_semantics"
  unresolved_scores <- active_count - sum(score_valid)
  score_gate <- unresolved_scores == 0L && active_count > 0L
  score_semantics_audit <- data.frame(
    schema_version = "phase18-club-history-score-audit-1", active_rows = as.character(active_count),
    resolved_score_rows = as.character(sum(score_valid)), unresolved_score_rows = as.character(unresolved_scores),
    gate_passed = score_gate, blocked_reason = if (score_gate) "" else "unresolved_score_semantics",
    row_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE
  )
  score_semantics_audit$row_sha256 <- phase18_club_row_sha256(score_semantics_audit)

  temporal_valid <- rep(FALSE, nrow(matches))
  if (nrow(matches)) {
    available <- nzchar(matches$evidence_available_at_utc)
    if (any(available)) temporal_valid[available] <- phase18_history_parse_utc(matches$evidence_available_at_utc[available], "evidence_available_at_utc") < cutoff
    temporal_valid <- completed & temporal_valid
  }
  temporal_violations <- active_count - sum(temporal_valid)
  temporal_gate <- temporal_violations == 0L && active_count > 0L
  temporal_audit <- data.frame(
    schema_version = "phase18-club-history-temporal-audit-1", cutoff_utc = phase18_history_format_utc(cutoff),
    active_rows = as.character(active_count), prior_evidence_rows = as.character(sum(temporal_valid)),
    temporal_violation_rows = as.character(temporal_violations), gate_passed = temporal_gate,
    blocked_reason = if (temporal_gate) "" else "missing_or_nonprior_evidence", row_sha256 = "",
    stringsAsFactors = FALSE, check.names = FALSE
  )
  temporal_audit$row_sha256 <- phase18_club_row_sha256(temporal_audit)

  lineage_ok <- logical(nrow(matches))
  if (nrow(matches)) {
    for (index in seq_len(nrow(matches))) {
      source <- source_manifest[source_manifest$source_id == matches$source_id[[index]], , drop = FALSE]
      lineage_ok[[index]] <- nrow(source) == 1L && source$source_status[[1L]] == "active" &&
        identical(matches$source_row_sha256[[index]], source$row_sha256[[1L]]) &&
        identical(matches$commit_sha[[index]], source$commit_sha[[1L]]) &&
        identical(matches$relative_path[[index]], source$relative_path[[1L]])
    }
  }
  lineage_fraction <- phase18_history_fraction(sum(lineage_ok & completed), active_count)
  coverage_gate <- nrow(coverage_audit) > 0L && all(phase18_history_logical(coverage_audit$gate_passed))
  gates <- c(
    source_pin_fraction = identical(source_pin_fraction, 1),
    license_fraction = identical(license_fraction, 1),
    coverage = coverage_gate,
    lineage_fraction = identical(lineage_fraction, 1),
    identity_fraction = identical(identity_fraction, 1),
    duplicate = duplicate_gate,
    score_semantics = score_gate,
    temporal = temporal_gate
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
    temporal_audit_sha256 = phase18_history_table_sha256(temporal_audit, "schema_version")
  )
  manifest <- data.frame(
    schema_version = "phase18-club-history-corpus-1", corpus_id = as.character(corpus_id),
    cutoff_utc = phase18_history_format_utc(cutoff), created_at_utc = as.character(created_at_utc),
    parser_commit = as.character(parser_commit), source_manifest_sha256 = hashes[["source_manifest_sha256"]],
    matches_sha256 = hashes[["matches_sha256"]], coverage_audit_sha256 = hashes[["coverage_audit_sha256"]],
    identity_audit_sha256 = hashes[["identity_audit_sha256"]], duplicate_audit_sha256 = hashes[["duplicate_audit_sha256"]],
    score_semantics_audit_sha256 = hashes[["score_semantics_audit_sha256"]], temporal_audit_sha256 = hashes[["temporal_audit_sha256"]],
    club_registry_sha256 = phase18_club_registry_hash(club_registries), identity_review_sha256 = as.character(identity_review_sha256),
    unresolved_identity_sha256 = as.character(unresolved_identity_sha256), source_pin_fraction = sprintf("%.12f", source_pin_fraction),
    license_fraction = sprintf("%.12f", license_fraction), lineage_fraction = sprintf("%.12f", lineage_fraction),
    identity_fraction = sprintf("%.12f", identity_fraction), coverage_gate_passed = coverage_gate,
    duplicate_gate_passed = duplicate_gate, score_semantics_gate_passed = score_gate,
    temporal_gate_passed = temporal_gate, accepted_for_training = accepted,
    blocked_reasons = blocked_reasons, manifest_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE
  )
  manifest$manifest_sha256 <- phase18_club_row_sha256(manifest, "manifest_sha256")
  list(
    source_manifest = phase18_history_canonical_table(source_manifest, "source_id"),
    matches = phase18_history_canonical_table(matches, c("source_id", "source_match_id", "match_id")),
    coverage_audit = coverage_audit, identity_audit = identity_audit,
    duplicate_audit = duplicate_audit, score_semantics_audit = score_semantics_audit,
    temporal_audit = temporal_audit, corpus_manifest = manifest
  )
}
