#' Phase 13 competition-edition registry contracts.

phase13_competition_edition_required_columns <- function() {
  c(
    "schema_version", "edition_id", "competition_id", "display_name", "lifecycle_state",
    "ruleset_version", "source_bundle_id", "model_release_id", "output_bundle_target",
    "active_output_bundle_id", "last_accepted_output_bundle_id", "blocked", "blocked_reason",
    "blocked_at_utc", "last_refresh_failure", "last_refresh_failure_at_utc",
    "registry_revision", "audit_event", "operator", "row_sha256"
  )
}

phase13_competition_lifecycle_states <- function() {
  c("pre_draw", "scheduled", "in_progress", "complete")
}

phase13_approved_model_release_ids <- function() {
  c("phase12-wc2026-incumbent-retained-v1")
}

phase13_registry_scalar <- function(value, name, allow_empty = FALSE) {
  if (length(value) != 1L || is.null(value) || is.na(value)) {
    stop("Phase 13 ", name, " must be one non-missing value", call. = FALSE)
  }
  value <- as.character(value[[1L]])
  if (!allow_empty && !nzchar(value)) stop("Phase 13 ", name, " must not be empty", call. = FALSE)
  value
}

phase13_registry_row_hash <- function(data) {
  if (exists("phase13_row_sha256", mode = "function")) return(phase13_row_sha256(data))
  if (!requireNamespace("digest", quietly = TRUE)) stop("digest is required for Phase 13 registry hashes", call. = FALSE)
  fields <- setdiff(names(data), "row_sha256")
  vapply(seq_len(nrow(data)), function(index) {
    values <- as.character(data[index, fields, drop = FALSE])
    values[is.na(values)] <- ""
    digest::digest(paste(values, collapse = "|"), algo = "sha256", serialize = FALSE)
  }, character(1))
}

#' Build one revisioned competition-edition row with explicit release slots.
phase13_build_competition_edition_row <- function(
    edition_id,
    competition_id,
    display_name,
    lifecycle_state,
    ruleset_version,
    source_bundle_id,
    model_release_id,
    output_bundle_target,
    active_output_bundle_id = NULL,
    last_accepted_output_bundle_id = NULL,
    blocked = FALSE,
    blocked_reason = "",
    blocked_at_utc = "",
    last_refresh_failure = "",
    last_refresh_failure_at_utc = "",
    registry_revision = 1L,
    audit_event = "initial_registration",
    operator = "system") {
  values <- list(
    edition_id = edition_id, competition_id = competition_id, display_name = display_name,
    lifecycle_state = lifecycle_state, ruleset_version = ruleset_version,
    source_bundle_id = source_bundle_id, model_release_id = model_release_id,
    output_bundle_target = output_bundle_target
  )
  values <- lapply(names(values), function(name) phase13_registry_scalar(values[[name]], name))
  names(values) <- c("edition_id", "competition_id", "display_name", "lifecycle_state", "ruleset_version", "source_bundle_id", "model_release_id", "output_bundle_target")
  if (!values$lifecycle_state %in% phase13_competition_lifecycle_states()) stop("Phase 13 lifecycle state is unsupported: ", values$lifecycle_state, call. = FALSE)
  if (!is.logical(blocked) || length(blocked) != 1L || is.na(blocked)) stop("Phase 13 blocked must be one logical value", call. = FALSE)
  active_output_bundle_id <- if (is.null(active_output_bundle_id)) values$source_bundle_id else phase13_registry_scalar(active_output_bundle_id, "active_output_bundle_id")
  last_accepted_output_bundle_id <- if (is.null(last_accepted_output_bundle_id)) active_output_bundle_id else phase13_registry_scalar(last_accepted_output_bundle_id, "last_accepted_output_bundle_id")
  row <- data.frame(
    schema_version = "phase13-competition-edition-v1",
    edition_id = values$edition_id,
    competition_id = values$competition_id,
    display_name = values$display_name,
    lifecycle_state = values$lifecycle_state,
    ruleset_version = values$ruleset_version,
    source_bundle_id = values$source_bundle_id,
    model_release_id = values$model_release_id,
    output_bundle_target = values$output_bundle_target,
    active_output_bundle_id = active_output_bundle_id,
    last_accepted_output_bundle_id = last_accepted_output_bundle_id,
    blocked = blocked,
    blocked_reason = phase13_registry_scalar(blocked_reason, "blocked_reason", allow_empty = TRUE),
    blocked_at_utc = phase13_registry_scalar(blocked_at_utc, "blocked_at_utc", allow_empty = TRUE),
    last_refresh_failure = phase13_registry_scalar(last_refresh_failure, "last_refresh_failure", allow_empty = TRUE),
    last_refresh_failure_at_utc = phase13_registry_scalar(last_refresh_failure_at_utc, "last_refresh_failure_at_utc", allow_empty = TRUE),
    registry_revision = as.integer(registry_revision),
    audit_event = phase13_registry_scalar(audit_event, "audit_event"),
    operator = phase13_registry_scalar(operator, "operator"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  if (is.na(row$registry_revision) || row$registry_revision < 1L) stop("Phase 13 registry_revision must be a positive integer", call. = FALSE)
  row$row_sha256 <- phase13_registry_row_hash(row)
  row
}

phase13_validate_competition_edition_registries <- function(
    registries,
    source_bundles = NULL,
    approved_model_release_ids = phase13_approved_model_release_ids()) {
  required <- phase13_competition_edition_required_columns()
  if (!is.data.frame(registries)) stop("Phase 13 competition edition registry must be a data frame", call. = FALSE)
  missing <- setdiff(required, names(registries))
  if (length(missing)) stop("Phase 13 competition edition registry missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  if (!nrow(registries)) return(invisible(registries))
  if (anyDuplicated(as.character(registries$edition_id))) stop("Phase 13 competition edition registry has duplicate edition IDs", call. = FALSE)
  if (any(is.na(registries$edition_id) | !nzchar(as.character(registries$edition_id))) ||
      any(is.na(registries$source_bundle_id) | !nzchar(as.character(registries$source_bundle_id))) ||
      any(is.na(registries$model_release_id) | !nzchar(as.character(registries$model_release_id))) ||
      any(is.na(registries$output_bundle_target) | !nzchar(as.character(registries$output_bundle_target))) ||
      any(is.na(registries$active_output_bundle_id) | !nzchar(as.character(registries$active_output_bundle_id))) ||
      any(is.na(registries$last_accepted_output_bundle_id) | !nzchar(as.character(registries$last_accepted_output_bundle_id)))) {
    stop("Phase 13 competition edition registry contains incomplete release slots", call. = FALSE)
  }
  if (any(!as.character(registries$lifecycle_state) %in% phase13_competition_lifecycle_states())) stop("Phase 13 competition edition registry contains invalid lifecycle state", call. = FALSE)
  if (any(is.na(registries$blocked) | !as.logical(registries$blocked))) {
    # The expression above is intentionally not used as the success condition;
    # it only normalizes logical-looking CSV values below.
    blocked <- as.character(registries$blocked)
    if (any(is.na(blocked) | !blocked %in% c("TRUE", "FALSE", "true", "false"))) stop("Phase 13 blocked overlay must be explicit", call. = FALSE)
  }
  blocked <- as.logical(registries$blocked)
  if (any(blocked & (is.na(registries$blocked_reason) | !nzchar(as.character(registries$blocked_reason)) | is.na(registries$blocked_at_utc) | !nzchar(as.character(registries$blocked_at_utc))))) {
    stop("Phase 13 blocked editions require failure reason and timestamp metadata", call. = FALSE)
  }
  if (any(!as.character(registries$model_release_id) %in% as.character(approved_model_release_ids))) {
    stop("Phase 13 competition edition registry contains an unapproved model release", call. = FALSE)
  }
  if (!is.null(source_bundles)) {
    source_required <- c("bundle_id", "edition_id", "bundle_status")
    missing_source <- setdiff(source_required, names(source_bundles))
    if (length(missing_source)) stop("Phase 13 source bundle registry missing columns: ", paste(missing_source, collapse = ", "), call. = FALSE)
    for (index in seq_len(nrow(registries))) {
      bundle <- source_bundles[as.character(source_bundles$bundle_id) == as.character(registries$source_bundle_id[[index]]), , drop = FALSE]
      if (nrow(bundle) != 1L || as.character(bundle$edition_id[[1L]]) != as.character(registries$edition_id[[index]]) || as.character(bundle$bundle_status[[1L]]) != "accepted") {
        stop("Phase 13 competition edition registry references a non-accepted source bundle", call. = FALSE)
      }
    }
  }
  predraw <- as.character(registries$lifecycle_state) == "pre_draw"
  if (any(predraw)) {
    forbidden_columns <- intersect(c("group_count", "fixture_count", "standings_hash", "fixtures_hash", "probability_hash"), names(registries))
    if (length(forbidden_columns)) {
      for (column in forbidden_columns) if (any(predraw & nzchar(as.character(registries[[column]])))) stop("Phase 13 pre-draw registry cannot fabricate competition structures", call. = FALSE)
    }
  }
  phase13_source_validate_hash_column <- if (exists("phase13_source_validate_hash_column", mode = "function")) phase13_source_validate_hash_column else NULL
  if (exists("phase13_source_validate_hash_column", mode = "function")) {
    phase13_source_validate_hash_column(registries, "row_sha256", "Phase 13 competition edition registry")
  } else {
    actual <- tolower(as.character(registries$row_sha256))
    expected <- phase13_registry_row_hash(registries)
    if (any(is.na(actual) | !grepl("^[0-9a-f]{64}$", actual)) || any(actual != expected)) stop("Phase 13 competition edition registry row SHA-256 mismatch", call. = FALSE)
  }
  invisible(registries)
}

phase13_validate_competition_edition_row <- function(row, source_bundles = NULL, approved_model_release_ids = phase13_approved_model_release_ids()) {
  phase13_validate_competition_edition_registries(row, source_bundles, approved_model_release_ids)
  invisible(row)
}

phase13_competition_registry_hash <- function(registries) {
  if (exists("phase13_canonical_sha256", mode = "function")) return(phase13_canonical_sha256(registries, key = "edition_id"))
  if (!requireNamespace("digest", quietly = TRUE)) stop("digest is required for Phase 13 registry hashes", call. = FALSE)
  rows <- registries[order(registries$edition_id), , drop = FALSE]
  digest::digest(paste(c(names(rows), capture.output(utils::write.csv(rows, stdout(), row.names = FALSE))), collapse = "\n"), algo = "sha256", serialize = FALSE)
}

phase13_validate_lifecycle_transition <- function(current_state, next_state) {
  current_state <- phase13_registry_scalar(current_state, "current lifecycle state")
  next_state <- phase13_registry_scalar(next_state, "next lifecycle state")
  states <- phase13_competition_lifecycle_states()
  if (!current_state %in% states || !next_state %in% states) stop("Phase 13 lifecycle transition contains an invalid state", call. = FALSE)
  current_index <- match(current_state, states)
  next_index <- match(next_state, states)
  if (!(identical(current_state, next_state) || identical(next_index, current_index + 1L))) {
    stop("Phase 13 lifecycle transition must move forward one state at a time", call. = FALSE)
  }
  invisible(TRUE)
}

phase13_transition_competition_edition <- function(
    row,
    next_lifecycle_state,
    operator_action = "",
    validation_passed = TRUE,
    operator = NULL) {
  if (!is.data.frame(row) || nrow(row) != 1L) stop("Phase 13 lifecycle transition requires one registry row", call. = FALSE)
  blocked <- isTRUE(as.logical(row$blocked[[1L]]))
  if (blocked && (!isTRUE(validation_passed) || !nzchar(as.character(operator_action)))) {
    stop("Phase 13 blocked lifecycle recovery requires explicit operator action and validation", call. = FALSE)
  }
  phase13_validate_lifecycle_transition(row$lifecycle_state[[1L]], next_lifecycle_state)
  row$lifecycle_state <- next_lifecycle_state
  row$blocked <- FALSE
  row$blocked_reason <- ""
  row$blocked_at_utc <- ""
  row$audit_event <- paste0("lifecycle_", next_lifecycle_state)
  if (!is.null(operator)) row$operator <- phase13_registry_scalar(operator, "operator")
  row$registry_revision <- as.integer(row$registry_revision[[1L]]) + 1L
  row$row_sha256 <- phase13_registry_row_hash(row)
  row
}

phase13_block_competition_edition <- function(
    row,
    failure_reason,
    failure_at_utc,
    operator = "system") {
  if (!is.data.frame(row) || nrow(row) != 1L) stop("Phase 13 block operation requires one registry row", call. = FALSE)
  failure_reason <- phase13_registry_scalar(failure_reason, "failure_reason")
  failure_at_utc <- phase13_registry_scalar(failure_at_utc, "failure_at_utc")
  if (is.na(row$active_output_bundle_id[[1L]]) || !nzchar(as.character(row$active_output_bundle_id[[1L]]))) {
    stop("Phase 13 blocked edition must retain an active output bundle", call. = FALSE)
  }
  row$blocked <- TRUE
  row$blocked_reason <- failure_reason
  row$blocked_at_utc <- failure_at_utc
  row$last_refresh_failure <- failure_reason
  row$last_refresh_failure_at_utc <- failure_at_utc
  row$last_accepted_output_bundle_id <- as.character(row$active_output_bundle_id[[1L]])
  row$audit_event <- "refresh_blocked"
  row$operator <- phase13_registry_scalar(operator, "operator")
  row$registry_revision <- as.integer(row$registry_revision[[1L]]) + 1L
  row$row_sha256 <- phase13_registry_row_hash(row)
  row
}

validate_competition_edition_registries <- phase13_validate_competition_edition_registries
validate_phase13_competition_edition_registries <- phase13_validate_competition_edition_registries
