#' Phase 18 reviewed club identity bootstrap shared by current and history data.

phase18_club_token_schema <- function() {
  c(
    "schema_version", "corpus", "source_system", "source_row",
    "source_club_id", "display_value", "normalized_display", "event_at_utc",
    "evidence_sha256", "row_sha256"
  )
}

phase18_club_review_schema <- function() {
  c(
    "corpus", "source_system", "source_row", "source_club_id", "display_value",
    "evidence_sha256", "club_id", "entity_kind", "canonical_name",
    "association_code", "valid_from_utc", "valid_to_utc", "reviewer",
    "reviewed_at_utc", "review_state", "source_bundle_id"
  )
}

phase18_unresolved_club_token_schema <- function() {
  c(
    "schema_version", "corpus", "source_system", "source_row",
    "source_club_id", "display_value", "evidence_sha256", "blocked_reason",
    "row_sha256"
  )
}

phase18_empty_table <- function(columns) {
  as.data.frame(
    setNames(replicate(length(columns), character(0), simplify = FALSE), columns),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

phase18_token_rows <- function(corpus, source_system, source_row, source_club_id,
                               display_value, event_at_utc) {
  rows <- data.frame(
    schema_version = "phase18-club-token-1",
    corpus = as.character(corpus),
    source_system = as.character(source_system),
    source_row = as.character(source_row),
    source_club_id = as.character(source_club_id),
    display_value = as.character(display_value),
    normalized_display = phase18_normalize_club_name(display_value),
    event_at_utc = as.character(event_at_utc),
    evidence_sha256 = "", row_sha256 = "",
    stringsAsFactors = FALSE, check.names = FALSE
  )
  evidence_fields <- c(
    "corpus", "source_system", "source_row", "source_club_id",
    "display_value", "event_at_utc"
  )
  rows$evidence_sha256 <- vapply(seq_len(nrow(rows)), function(index) {
    values <- vapply(rows[index, evidence_fields, drop = FALSE], phase18_club_canonical_scalar, character(1))
    digest::digest(paste(values, collapse = "|"), algo = "sha256", serialize = FALSE)
  }, character(1))
  rows$row_sha256 <- phase18_club_row_sha256(rows)
  rows
}

phase18_extract_current_tokens <- function(current_resources) {
  if (is.null(current_resources)) return(phase18_empty_table(phase18_club_token_schema()))
  if (is.list(current_resources) && !is.data.frame(current_resources)) {
    parts <- lapply(names(current_resources), function(name) {
      data <- current_resources[[name]]
      if (!is.data.frame(data) || !nrow(data)) return(NULL)
      if (all(c("source_system", "source_club_id", "display_name", "event_at_utc") %in% names(data))) {
        if (!"source_row" %in% names(data)) data$source_row <- paste0(name, ":", seq_len(nrow(data)))
        return(phase18_token_rows(
          "current_ucl", data$source_system, data$source_row,
          data$source_club_id, data$display_name, data$event_at_utc
        ))
      }
      required <- c(
        "source_system", "home_source_club_id", "home_display_name",
        "away_source_club_id", "away_display_name", "event_at_utc"
      )
      if (all(required %in% names(data))) {
        source_row <- if ("source_row" %in% names(data)) data$source_row else paste0(name, ":", seq_len(nrow(data)))
        home <- phase18_token_rows(
          "current_ucl", data$source_system, paste0(source_row, ":home"),
          data$home_source_club_id, data$home_display_name, data$event_at_utc
        )
        away <- phase18_token_rows(
          "current_ucl", data$source_system, paste0(source_row, ":away"),
          data$away_source_club_id, data$away_display_name, data$event_at_utc
        )
        return(rbind(home, away))
      }
      phase18_club_abort("invalid_club_token_source", paste0("Unsupported current resource schema: ", name))
    })
    parts <- Filter(Negate(is.null), parts)
    if (!length(parts)) return(phase18_empty_table(phase18_club_token_schema()))
    return(do.call(rbind, parts))
  }
  if (!is.data.frame(current_resources)) {
    phase18_club_abort("invalid_club_token_source", "current_resources must be a data frame or named list")
  }
  required <- c("source_system", "source_club_id", "display_name", "event_at_utc")
  missing <- setdiff(required, names(current_resources))
  if (length(missing)) phase18_club_abort("invalid_club_token_source", paste0("Current resources missing: ", paste(missing, collapse = ", ")))
  if (!nrow(current_resources)) return(phase18_empty_table(phase18_club_token_schema()))
  source_row <- if ("source_row" %in% names(current_resources)) current_resources$source_row else paste0("current:", seq_len(nrow(current_resources)))
  phase18_token_rows(
    "current_ucl", current_resources$source_system, source_row,
    current_resources$source_club_id, current_resources$display_name,
    current_resources$event_at_utc
  )
}

phase18_extract_history_tokens <- function(history_inventory) {
  if (is.null(history_inventory) || (is.data.frame(history_inventory) && !nrow(history_inventory))) {
    return(phase18_empty_table(phase18_club_token_schema()))
  }
  if (!is.data.frame(history_inventory)) {
    phase18_club_abort("invalid_club_token_source", "history_inventory must be a data frame")
  }
  required <- c("source_system", "source_row", "event_at_utc", "home_name", "away_name")
  missing <- setdiff(required, names(history_inventory))
  if (length(missing)) phase18_club_abort("invalid_club_token_source", paste0("Historical inventory missing: ", paste(missing, collapse = ", ")))
  home_id <- if ("home_source_club_id" %in% names(history_inventory)) {
    history_inventory$home_source_club_id
  } else {
    paste0("name:", gsub(" ", "_", phase18_normalize_club_name(history_inventory$home_name), fixed = TRUE))
  }
  away_id <- if ("away_source_club_id" %in% names(history_inventory)) {
    history_inventory$away_source_club_id
  } else {
    paste0("name:", gsub(" ", "_", phase18_normalize_club_name(history_inventory$away_name), fixed = TRUE))
  }
  home <- phase18_token_rows(
    "historical_inventory", history_inventory$source_system,
    paste0(history_inventory$source_row, ":home"), home_id,
    history_inventory$home_name, history_inventory$event_at_utc
  )
  away <- phase18_token_rows(
    "historical_inventory", history_inventory$source_system,
    paste0(history_inventory$source_row, ":away"), away_id,
    history_inventory$away_name, history_inventory$event_at_utc
  )
  rbind(home, away)
}

phase18_extract_club_tokens <- function(current_resources = NULL, history_inventory = NULL) {
  rows <- rbind(
    phase18_extract_current_tokens(current_resources),
    phase18_extract_history_tokens(history_inventory)
  )
  if (!nrow(rows)) return(rows)
  required_nonempty <- c("corpus", "source_system", "source_row", "source_club_id", "display_value", "event_at_utc")
  if (any(vapply(rows[required_nonempty], function(value) any(is.na(value) | !nzchar(value)), logical(1)))) {
    phase18_club_abort("invalid_club_token_source", "Extracted club tokens contain empty identity evidence")
  }
  phase18_club_parse_time(rows$event_at_utc, "event_at_utc")
  key <- c("corpus", "source_system", "source_club_id", "display_value", "event_at_utc", "source_row")
  rows <- rows[!duplicated(rows[key]), , drop = FALSE]
  rows <- phase18_club_canonical_table(rows, c("corpus", "source_system", "source_club_id", "normalized_display", "source_row", "row_sha256"))
  rows$row_sha256 <- phase18_club_row_sha256(rows)
  rows
}

phase18_validate_club_identity_review <- function(tokens, review) {
  if (!is.data.frame(tokens) || !identical(names(tokens), phase18_club_token_schema())) {
    phase18_club_abort("invalid_club_review", "tokens must use the Phase 18 club token schema")
  }
  if (!is.data.frame(review) || !identical(names(review), phase18_club_review_schema())) {
    phase18_club_abort("invalid_club_review", "review must use the exact owner review schema")
  }
  if (!nrow(review)) return(invisible(TRUE))
  text_fields <- setdiff(names(review), "valid_to_utc")
  if (any(vapply(review[text_fields], function(value) any(is.na(value) | !nzchar(as.character(value))), logical(1)))) {
    phase18_club_abort("invalid_club_review", "Owner review contains empty required fields")
  }
  if (any(review$entity_kind != "club") || any(!grepl("^club_[a-z0-9][a-z0-9_]*$", review$club_id))) {
    phase18_club_abort("cross_domain_club_identity", "Owner review must map only project-owned club_ identities")
  }
  if (any(!review$review_state %in% c("approved", "pending", "rejected"))) {
    phase18_club_abort("invalid_club_review", "Owner review_state must be approved, pending, or rejected")
  }
  phase18_club_parse_time(review$valid_from_utc, "valid_from_utc")
  ends <- phase18_club_parse_time(review$valid_to_utc, "valid_to_utc", allow_blank = TRUE)
  starts <- phase18_club_parse_time(review$valid_from_utc, "valid_from_utc")
  if (any(!is.na(ends) & starts >= ends)) phase18_club_abort("invalid_club_validity", "Owner review has invalid half-open interval")
  phase18_club_parse_time(review$reviewed_at_utc, "reviewed_at_utc")
  missing_evidence <- setdiff(review$evidence_sha256, tokens$evidence_sha256)
  if (length(missing_evidence)) phase18_club_abort("invalid_club_review", "Owner review references unknown or stale token evidence")
  for (index in seq_len(nrow(review))) {
    token <- tokens[tokens$evidence_sha256 == review$evidence_sha256[[index]], , drop = FALSE]
    fields <- c("corpus", "source_system", "source_row", "source_club_id", "display_value")
    if (nrow(token) != 1L || !identical(as.character(token[1L, fields]), as.character(review[index, fields]))) {
      phase18_club_abort("invalid_club_review", "Owner review fields do not match their evidence-bound token")
    }
  }
  invisible(TRUE)
}

phase18_unresolved_row <- function(token, reason) {
  row <- data.frame(
    schema_version = "phase18-unresolved-club-token-1",
    corpus = token$corpus[[1L]], source_system = token$source_system[[1L]],
    source_row = token$source_row[[1L]], source_club_id = token$source_club_id[[1L]],
    display_value = token$display_value[[1L]], evidence_sha256 = token$evidence_sha256[[1L]],
    blocked_reason = reason, row_sha256 = "",
    stringsAsFactors = FALSE, check.names = FALSE
  )
  row$row_sha256 <- phase18_club_row_sha256(row)
  row
}

phase18_assignment_overlap <- function(existing, row, identity_fields) {
  if (!nrow(existing)) return(existing)
  match <- rep(TRUE, nrow(existing))
  for (field in identity_fields) match <- match & existing[[field]] == row[[field]][[1L]]
  candidates <- existing[match, , drop = FALSE]
  if (!nrow(candidates)) return(candidates)
  start <- phase18_club_parse_time(row$valid_from_utc, "valid_from_utc")[[1L]]
  end <- phase18_club_parse_time(row$valid_to_utc, "valid_to_utc", allow_blank = TRUE)[[1L]]
  if (is.na(end)) end <- as.POSIXct("9999-12-31T23:59:59Z", tz = "UTC")
  candidate_start <- phase18_club_parse_time(candidates$valid_from_utc, "valid_from_utc")
  candidate_end <- phase18_club_parse_time(candidates$valid_to_utc, "valid_to_utc", allow_blank = TRUE)
  candidate_end[is.na(candidate_end)] <- as.POSIXct("9999-12-31T23:59:59Z", tz = "UTC")
  candidates[candidate_start < end & start < candidate_end, , drop = FALSE]
}

phase18_append_unique_assignment <- function(existing, row, key_fields) {
  if (nrow(existing)) {
    exact <- rep(TRUE, nrow(existing))
    for (field in key_fields) exact <- exact & as.character(existing[[field]]) == as.character(row[[field]][[1L]])
    if (any(exact)) return(existing)
  }
  rbind(existing, row)
}

phase18_apply_club_identity_review <- function(tokens, review, registries) {
  phase18_validate_club_registries(registries)
  phase18_validate_club_identity_review(tokens, review)
  candidate <- registries
  unresolved <- phase18_empty_table(phase18_unresolved_club_token_schema())
  approved_evidence <- character(0)

  for (index in seq_len(nrow(tokens))) {
    token <- tokens[index, , drop = FALSE]
    matches <- review[review$evidence_sha256 == token$evidence_sha256[[1L]], , drop = FALSE]
    if (!nrow(matches)) {
      unresolved <- rbind(unresolved, phase18_unresolved_row(token, "missing_owner_review"))
      next
    }
    approved <- matches[matches$review_state == "approved", , drop = FALSE]
    if (nrow(approved) != 1L) {
      reason <- if (nrow(approved) > 1L) "ambiguous_owner_review" else paste0(matches$review_state[[1L]], "_owner_review")
      unresolved <- rbind(unresolved, phase18_unresolved_row(token, reason))
      next
    }
    mapping <- approved[1L, , drop = FALSE]
    approved_evidence <- c(approved_evidence, token$evidence_sha256[[1L]])
    existing_club <- candidate$clubs[candidate$clubs$club_id == mapping$club_id[[1L]], , drop = FALSE]
    if (nrow(existing_club)) {
      if (nrow(existing_club) != 1L || existing_club$canonical_name[[1L]] != mapping$canonical_name[[1L]] ||
          existing_club$entity_kind[[1L]] != "club") {
        phase18_club_abort("club_identity_review_conflict", "Owner review conflicts with an existing canonical club")
      }
    } else {
      club <- data.frame(
        schema_version = phase18_club_identity_schema_version(),
        club_id = mapping$club_id[[1L]], entity_kind = "club",
        canonical_name = mapping$canonical_name[[1L]], association_code = mapping$association_code[[1L]],
        valid_from_utc = mapping$valid_from_utc[[1L]], valid_to_utc = mapping$valid_to_utc[[1L]],
        club_status = "active", row_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE
      )
      club$row_sha256 <- phase18_club_row_sha256(club)
      candidate$clubs <- rbind(candidate$clubs, club)
    }

    source_row <- data.frame(
      schema_version = phase18_club_identity_schema_version(), club_id = mapping$club_id[[1L]],
      source_system = token$source_system[[1L]], source_club_id = token$source_club_id[[1L]],
      valid_from_utc = mapping$valid_from_utc[[1L]], valid_to_utc = mapping$valid_to_utc[[1L]],
      review_state = "approved", source_bundle_id = mapping$source_bundle_id[[1L]], row_sha256 = "",
      stringsAsFactors = FALSE, check.names = FALSE
    )
    overlap <- phase18_assignment_overlap(candidate$source_ids, source_row, c("source_system", "source_club_id"))
    if (nrow(overlap) && any(overlap$club_id != mapping$club_id[[1L]])) {
      phase18_club_abort("club_identity_review_conflict", "Owner review conflicts with an existing source ID assignment")
    }
    source_row$row_sha256 <- phase18_club_row_sha256(source_row)
    candidate$source_ids <- phase18_append_unique_assignment(
      candidate$source_ids, source_row,
      c("club_id", "source_system", "source_club_id", "valid_from_utc", "valid_to_utc")
    )

    alias_row <- data.frame(
      schema_version = phase18_club_identity_schema_version(), club_id = mapping$club_id[[1L]],
      source_system = token$source_system[[1L]], alias = token$display_value[[1L]],
      normalized_alias = token$normalized_display[[1L]],
      valid_from_utc = mapping$valid_from_utc[[1L]], valid_to_utc = mapping$valid_to_utc[[1L]],
      review_state = "approved", reviewed_by = mapping$reviewer[[1L]],
      reviewed_at_utc = mapping$reviewed_at_utc[[1L]], row_sha256 = "",
      stringsAsFactors = FALSE, check.names = FALSE
    )
    overlap <- phase18_assignment_overlap(candidate$aliases, alias_row, c("source_system", "normalized_alias"))
    if (nrow(overlap) && any(overlap$club_id != mapping$club_id[[1L]])) {
      phase18_club_abort("club_identity_review_conflict", "Owner review conflicts with an existing alias assignment")
    }
    alias_row$row_sha256 <- phase18_club_row_sha256(alias_row)
    candidate$aliases <- phase18_append_unique_assignment(
      candidate$aliases, alias_row,
      c("club_id", "source_system", "normalized_alias", "valid_from_utc", "valid_to_utc")
    )
  }
  candidate <- phase18_hash_club_registry_rows(candidate)
  phase18_validate_club_registries(candidate)
  if (nrow(unresolved)) {
    unresolved <- phase18_club_canonical_table(unresolved, c("corpus", "source_system", "source_club_id", "source_row", "row_sha256"))
  }
  list(
    registries = candidate, tokens = tokens, review = review,
    unresolved = unresolved, approved_evidence_sha256 = sort(unique(approved_evidence)),
    registry_sha256 = phase18_club_registry_hash(candidate)
  )
}

phase18_expectation_value <- function(expectations, name, default) {
  if (is.null(expectations) || is.null(expectations[[name]])) return(default)
  expectations[[name]]
}

phase18_validate_identity_bootstrap <- function(result, current_expectations = list(), history_expectations = list()) {
  if (!is.list(result) || is.null(result$registries) || is.null(result$tokens) || is.null(result$unresolved)) {
    phase18_club_abort("invalid_identity_bootstrap", "Identity bootstrap result is incomplete")
  }
  phase18_validate_club_registries(result$registries)
  if (!is.data.frame(result$unresolved) ||
      !identical(names(result$unresolved), phase18_unresolved_club_token_schema())) {
    phase18_club_abort("invalid_identity_bootstrap", "Unresolved club evidence has the wrong schema")
  }
  if (nrow(result$unresolved)) {
    if (any(!grepl("^[0-9a-f]{64}$", result$unresolved$evidence_sha256)) ||
        any(result$unresolved$row_sha256 != phase18_club_row_sha256(result$unresolved))) {
      phase18_club_abort("club_identity_evidence_hash_mismatch", "Unresolved club evidence hash mismatch")
    }
    sentinel_reasons <- c("missing_history_inventory", "not_run_missing_probe")
    linked <- result$unresolved$blocked_reason %in% sentinel_reasons |
      result$unresolved$evidence_sha256 %in% result$tokens$evidence_sha256
    if (any(!linked)) {
      phase18_club_abort("club_identity_evidence_hash_mismatch", "Unresolved club evidence is not linked to a token or declared missing-input sentinel")
    }
  }
  corpora <- c(current_ucl = "current_ucl", historical_inventory = "historical_inventory")
  expectations <- list(current_ucl = current_expectations, historical_inventory = history_expectations)
  rows <- lapply(names(corpora), function(name) {
    corpus <- corpora[[name]]
    tokens <- result$tokens[result$tokens$corpus == corpus, , drop = FALSE]
    unresolved <- result$unresolved[result$unresolved$corpus == corpus, , drop = FALSE]
    expected <- as.integer(phase18_expectation_value(expectations[[name]], "expected_tokens", nrow(tokens)))
    required <- isTRUE(phase18_expectation_value(expectations[[name]], "required", FALSE))
    not_run <- isTRUE(phase18_expectation_value(expectations[[name]], "not_run", FALSE))
    resolution_failures <- 0L
    if (nrow(tokens)) {
      for (index in seq_len(nrow(tokens))) {
        resolved <- tryCatch(
          phase18_resolve_club_identity(
            result$registries, tokens$source_system[[index]], tokens$source_club_id[[index]],
            tokens$display_value[[index]], tokens$event_at_utc[[index]]
          ),
          error = function(error) NULL
        )
        if (is.null(resolved)) resolution_failures <- resolution_failures + 1L
      }
    }
    status <- if (not_run && !nrow(tokens)) {
      "not_run"
    } else if (nrow(tokens) == expected && !nrow(unresolved) && resolution_failures == 0L) {
      "complete"
    } else if (!required && !nrow(tokens)) {
      "not_run"
    } else {
      "blocked"
    }
    data.frame(
      corpus = corpus, expected_tokens = expected, observed_tokens = nrow(tokens),
      unresolved_tokens = nrow(unresolved), resolution_failures = resolution_failures,
      status = status, stringsAsFactors = FALSE, check.names = FALSE
    )
  })
  report <- do.call(rbind, rows)
  rownames(report) <- NULL
  if (any(report$status == "blocked")) {
    phase18_club_abort(
      "club_identity_bootstrap_blocked",
      paste0("Club identity bootstrap blocked: ", paste(report$corpus[report$status == "blocked"], collapse = ", ")),
      list(report = report)
    )
  }
  report
}

phase18_write_csv_atomic <- function(data, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  temporary <- tempfile(pattern = paste0(basename(path), "."), tmpdir = dirname(path))
  on.exit(unlink(temporary, force = TRUE), add = TRUE)
  utils::write.csv(data, temporary, row.names = FALSE, na = "", quote = TRUE)
  if (!file.rename(temporary, path)) phase18_club_abort("club_registry_write_failed", paste0("Could not atomically write ", path))
  invisible(path)
}

phase18_write_club_registries_atomic <- function(registries, root) {
  phase18_validate_club_registries(registries)
  dir.create(root, recursive = TRUE, showWarnings = FALSE)
  files <- c(clubs = "clubs.csv", source_ids = "club_source_ids.csv", aliases = "club_aliases.csv")
  snapshots <- lapply(files, function(file) {
    path <- file.path(root, file)
    if (file.exists(path)) readBin(path, "raw", n = file.info(path)$size) else raw(0)
  })
  written <- character(0)
  tryCatch({
    for (name in names(files)) {
      path <- file.path(root, files[[name]])
      phase18_write_csv_atomic(phase18_club_canonical_table(registries[[name]], phase18_club_sort_keys()[[name]]), path)
      written <- c(written, name)
    }
    reloaded <- phase18_load_club_registries(root)
    if (!identical(phase18_club_registry_hash(reloaded), phase18_club_registry_hash(registries))) {
      phase18_club_abort("club_registry_write_failed", "Registry read-back hash mismatch")
    }
  }, error = function(error) {
    for (name in written) {
      path <- file.path(root, files[[name]])
      if (length(snapshots[[name]])) writeBin(snapshots[[name]], path) else unlink(path, force = TRUE)
    }
    stop(error)
  })
  invisible(root)
}
