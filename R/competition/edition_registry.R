#' Phase 13 competition-edition registry contracts.
#'
#' Edition rows are durable authority for the source bundle, approved model
#' release, lifecycle, and output slot consumed by later phases.  The blocked
#' flag is an overlay: it never replaces the lifecycle state or the last
#' accepted output reference.

phase13_competition_edition_required_columns <- function() {
  c(
    "schema_version", "edition_id", "source_edition_id", "competition_id", "display_name",
    "lifecycle_state", "official_draw_date", "source_reference", "ruleset_version",
    "source_bundle_id", "model_release_id", "output_bundle_target", "active_output_bundle_id",
    "last_accepted_output_bundle_id", "blocked", "blocked_refresh_batch_id", "blocked_reason", "blocked_at_utc",
    "last_refresh_failure", "last_refresh_failure_at_utc", "registry_revision", "audit_event",
    "audit_at_utc", "operator", "pre_draw_note", "row_sha256"
  )
}

phase13_competition_lifecycle_states <- function() {
  c("pre_draw", "scheduled", "in_progress", "complete")
}

phase13_competition_edition_ids <- function() {
  c("uefa_nations_league_2026_27", "uefa_euro_2028_qualifying")
}

phase13_competition_edition_catalog <- function() {
  data.frame(
    edition_id = phase13_competition_edition_ids(),
    source_edition_id = c("uefa-nations-league-2026-27", "uefa-euro-2028-qualifying"),
    competition_id = c("uefa_nations_league", "uefa_euro_2028_qualifying"),
    display_name = c("UEFA Nations League 2026/27", "UEFA EURO 2028 qualifying"),
    official_draw_date = c("", "2026-12-06"),
    source_reference = c(
      "https://www.uefa.com/uefanationsleague/fixtures-results/",
      "https://www.uefa.com/euro2028/about/"
    ),
    pre_draw_note = c(
      "",
      "Awaiting the official 2026-12-06 qualifying draw; no competition structures are fabricated."
    ),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

phase13_approved_model_release_ids <- function() {
  # Compatibility projection only. Runtime authority is selected through
  # approved_release.csv once that selector exists.
  c(
    "phase12-wc2026-incumbent-retained-v1",
    "phase14-open-nb-incumbent-calibrated-v1"
  )
}

phase13_registry_scalar <- function(value, name, allow_empty = FALSE) {
  if (length(value) != 1L || is.null(value) || is.na(value)) {
    stop("Phase 13 ", name, " must be one non-missing value", call. = FALSE)
  }
  value <- as.character(value[[1L]])
  if (!allow_empty && !nzchar(value)) stop("Phase 13 ", name, " must not be empty", call. = FALSE)
  value
}

phase13_registry_blank <- function(value) {
  length(value) == 0L || is.null(value) || is.na(value[[1L]]) || !nzchar(as.character(value[[1L]]))
}

phase13_registry_logical <- function(value, name) {
  if (is.logical(value) && length(value) == 1L && !is.na(value)) return(value)
  token <- tolower(trimws(as.character(value)))
  if (length(token) != 1L || is.na(token) || !token %in% c("true", "false")) {
    stop("Phase 13 ", name, " must be an explicit TRUE or FALSE value", call. = FALSE)
  }
  identical(token, "true")
}

phase13_registry_hash_scalar <- function(value) {
  if (inherits(value, "Date")) value <- format(value, "%Y-%m-%d")
  if (inherits(value, "POSIXt")) value <- format(value, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  if (is.logical(value)) return(ifelse(is.na(value), "", ifelse(value, "true", "false")))
  if (length(value) == 0L || is.na(value[[1L]])) return("")
  as.character(value[[1L]])
}

phase13_registry_row_hash <- function(data) {
  if (exists("phase13_row_sha256", mode = "function")) return(phase13_row_sha256(data))
  if (!is.data.frame(data)) stop("Phase 13 registry row hashing requires a data frame", call. = FALSE)
  if (!requireNamespace("digest", quietly = TRUE)) stop("digest is required for Phase 13 registry hashes", call. = FALSE)
  fields <- setdiff(names(data), "row_sha256")
  vapply(seq_len(nrow(data)), function(index) {
    values <- vapply(data[index, fields, drop = FALSE], phase13_registry_hash_scalar, character(1))
    digest::digest(paste(values, collapse = "|"), algo = "sha256", serialize = FALSE)
  }, character(1))
}

phase13_competition_registry_hash <- function(registries) {
  if (!is.data.frame(registries)) stop("Phase 13 competition registry hash requires a data frame", call. = FALSE)
  if (exists("phase13_canonical_sha256", mode = "function")) {
    return(phase13_canonical_sha256(registries, key = "edition_id"))
  }
  if (!requireNamespace("digest", quietly = TRUE)) stop("digest is required for Phase 13 registry hashes", call. = FALSE)
  ordered <- registries[order(as.character(registries$edition_id)), , drop = FALSE]
  digest::digest(paste(c(names(ordered), capture.output(utils::write.csv(ordered, stdout(), row.names = FALSE))), collapse = "\n"), algo = "sha256", serialize = FALSE)
}

phase13_edition_project_root <- function(path = ".") {
  candidate <- normalizePath(path, winslash = "/", mustWork = FALSE)
  if (file.exists(candidate) && !dir.exists(candidate)) candidate <- dirname(candidate)
  # Temporary registry roots used by the fail-closed tests do not contain a
  # Git checkout.  Keep an explicit absolute directory as the project root so
  # its adjacent raw-byte store and accepted tree remain independently bound.
  if (grepl("^/", as.character(path)) && dir.exists(candidate) &&
      !dir.exists(file.path(candidate, ".git")) && !file.exists(file.path(candidate, ".git"))) {
    return(candidate)
  }
  if (exists("phase13_source_find_project_root", mode = "function")) {
    return(phase13_source_find_project_root(path))
  }
  repeat {
    if (dir.exists(file.path(candidate, ".git")) || file.exists(file.path(candidate, ".git"))) return(candidate)
    parent <- dirname(candidate)
    if (identical(parent, candidate)) break
    candidate <- parent
  }
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

phase13_edition_source_contracts <- function(project_root = ".") {
  root <- phase13_edition_project_root(project_root)
  if (!exists("phase13_source_validate_hash_column", mode = "function")) {
    source(file.path(root, "R/competition/source_contracts.R"), local = .GlobalEnv)
  }
  if (!exists("phase13_normalized_fixture_schema", mode = "function")) {
    source(file.path(root, "R/competition/team_identity.R"), local = .GlobalEnv)
  }
  if (!exists("preflight_phase12_approved_release", mode = "function")) {
    source(file.path(root, "R/release/release_contract.R"), local = .GlobalEnv)
  }
  if (!exists("preflight_phase12_approved_release", mode = "function")) {
    stop("Phase 13 edition registry could not load the Phase 12 release preflight", call. = FALSE)
  }
  invisible(root)
}

phase13_preflight_approved_model_release <- function(
    trusted_root = "outputs/releases",
    release_manifest_path = NULL,
    selector_path = NULL,
    project_root = ".") {
  root <- phase13_edition_project_root(project_root)
  phase13_edition_source_contracts(root)
  trusted_root <- as.character(trusted_root)
  if (length(trusted_root) != 1L || is.na(trusted_root) || !nzchar(trusted_root)) {
    stop("Phase 13 approved release root is invalid", call. = FALSE)
  }
  if (!grepl("^/", trusted_root)) trusted_root <- file.path(root, trusted_root)
  if (!is.null(selector_path)) {
    if (!is.null(release_manifest_path)) {
      stop("Phase 13 selector resolution cannot also receive a release manifest", call. = FALSE)
    }
    if (!exists("phase14_resolve_approved_release", mode = "function")) {
      stop("Phase 13 edition registry could not load the Phase 14 selector resolver", call. = FALSE)
    }
    return(phase14_resolve_approved_release(
      selector_path = selector_path,
      trusted_release_root = trusted_root
    ))
  }
  # Pre-selector compatibility is deliberately pinned to the incumbent
  # manifest. It avoids directory scanning and is never used by the loader
  # after approved_release.csv exists.
  if (is.null(release_manifest_path)) {
    release_manifest_path <- file.path(
      trusted_root,
      "phase12-wc2026-incumbent-retained-v1",
      "release_manifest.csv"
    )
  }
  preflight_phase12_approved_release(trusted_root, release_manifest_path)
}

phase13_validate_approved_model_release_pin <- function(
    model_release_ids,
    trusted_root = "outputs/releases",
    approved_model_release_ids = phase13_approved_model_release_ids(),
    selector_path = NULL,
    resolved_release = NULL,
    project_root = ".") {
  preflight <- resolved_release
  if (is.null(preflight)) {
    preflight <- phase13_preflight_approved_model_release(
      trusted_root = trusted_root,
      selector_path = selector_path,
      project_root = project_root
    )
  }
  expected <- if (!is.null(preflight$release_identity$release_id)) {
    as.character(preflight$release_identity$release_id)
  } else {
    as.character(preflight$metadata$release_id)
  }
  if (length(expected) != 1L || is.na(expected) || !nzchar(expected)) {
    stop("Phase 13 approved release resolution returned no release identity", call. = FALSE)
  }
  if (length(approved_model_release_ids) && !expected %in% as.character(approved_model_release_ids)) {
    stop("Phase 13 approved model release projection disagrees with the trusted Phase 12 release", call. = FALSE)
  }
  values <- as.character(model_release_ids)
  if (any(is.na(values) | !nzchar(values)) || any(values != expected)) {
    stop("Phase 13 competition edition registry contains a model release pin that does not match the approved Phase 12 release", call. = FALSE)
  }
  invisible(preflight)
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
    blocked_refresh_batch_id = "",
    blocked_reason = "",
    blocked_at_utc = "",
    last_refresh_failure = "",
    last_refresh_failure_at_utc = "",
    registry_revision = 1L,
    audit_event = "initial_registration",
    operator = "system",
    source_edition_id = NULL,
    official_draw_date = NULL,
    source_reference = NULL,
    audit_at_utc = "2026-08-13T00:00:00Z",
    pre_draw_note = NULL) {
  edition_id <- phase13_registry_scalar(edition_id, "edition_id")
  catalog <- phase13_competition_edition_catalog()
  catalog_row <- catalog[catalog$edition_id == edition_id, , drop = FALSE]
  if (is.null(source_edition_id)) source_edition_id <- if (nrow(catalog_row)) catalog_row$source_edition_id[[1L]] else edition_id
  if (is.null(official_draw_date)) official_draw_date <- if (nrow(catalog_row)) catalog_row$official_draw_date[[1L]] else ""
  if (is.null(source_reference)) source_reference <- if (nrow(catalog_row)) catalog_row$source_reference[[1L]] else ""
  if (is.null(pre_draw_note)) pre_draw_note <- if (nrow(catalog_row)) catalog_row$pre_draw_note[[1L]] else ""

  scalar_names <- c(
    "source_edition_id", "competition_id", "display_name", "lifecycle_state", "ruleset_version",
    "source_bundle_id", "model_release_id", "output_bundle_target", "official_draw_date",
    "source_reference", "audit_event", "audit_at_utc", "operator", "pre_draw_note"
  )
  scalar_values <- list(
    source_edition_id, competition_id, display_name, lifecycle_state, ruleset_version,
    source_bundle_id, model_release_id, output_bundle_target, official_draw_date,
    source_reference, audit_event, audit_at_utc, operator, pre_draw_note
  )
  names(scalar_values) <- scalar_names
  scalar_values <- lapply(seq_along(scalar_values), function(index) {
    phase13_registry_scalar(scalar_values[[index]], scalar_names[[index]], allow_empty = scalar_names[[index]] %in% c("official_draw_date", "source_reference", "pre_draw_note"))
  })
  names(scalar_values) <- scalar_names
  if (!scalar_values$lifecycle_state %in% phase13_competition_lifecycle_states()) stop("Phase 13 lifecycle state is unsupported: ", scalar_values$lifecycle_state, call. = FALSE)
  if (!is.logical(blocked) || length(blocked) != 1L || is.na(blocked)) stop("Phase 13 blocked must be one logical value", call. = FALSE)
  active_output_bundle_id <- if (is.null(active_output_bundle_id)) scalar_values$source_bundle_id else phase13_registry_scalar(active_output_bundle_id, "active_output_bundle_id")
  last_accepted_output_bundle_id <- if (is.null(last_accepted_output_bundle_id)) active_output_bundle_id else phase13_registry_scalar(last_accepted_output_bundle_id, "last_accepted_output_bundle_id")
  registry_revision <- as.integer(registry_revision)
  if (length(registry_revision) != 1L || is.na(registry_revision) || registry_revision < 1L) stop("Phase 13 registry_revision must be a positive integer", call. = FALSE)

  row <- data.frame(
    schema_version = "phase13-competition-edition-v2",
    edition_id = edition_id,
    source_edition_id = scalar_values$source_edition_id,
    competition_id = scalar_values$competition_id,
    display_name = scalar_values$display_name,
    lifecycle_state = scalar_values$lifecycle_state,
    official_draw_date = scalar_values$official_draw_date,
    source_reference = scalar_values$source_reference,
    ruleset_version = scalar_values$ruleset_version,
    source_bundle_id = scalar_values$source_bundle_id,
    model_release_id = scalar_values$model_release_id,
    output_bundle_target = scalar_values$output_bundle_target,
    active_output_bundle_id = active_output_bundle_id,
    last_accepted_output_bundle_id = last_accepted_output_bundle_id,
    blocked = blocked,
    blocked_refresh_batch_id = phase13_registry_scalar(blocked_refresh_batch_id, "blocked_refresh_batch_id", allow_empty = TRUE),
    blocked_reason = phase13_registry_scalar(blocked_reason, "blocked_reason", allow_empty = TRUE),
    blocked_at_utc = phase13_registry_scalar(blocked_at_utc, "blocked_at_utc", allow_empty = TRUE),
    last_refresh_failure = phase13_registry_scalar(last_refresh_failure, "last_refresh_failure", allow_empty = TRUE),
    last_refresh_failure_at_utc = phase13_registry_scalar(last_refresh_failure_at_utc, "last_refresh_failure_at_utc", allow_empty = TRUE),
    registry_revision = registry_revision,
    audit_event = scalar_values$audit_event,
    audit_at_utc = scalar_values$audit_at_utc,
    operator = scalar_values$operator,
    pre_draw_note = scalar_values$pre_draw_note,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  if (blocked && (phase13_registry_blank(row$blocked_reason) || phase13_registry_blank(row$blocked_at_utc))) {
    stop("Phase 13 blocked editions require failure reason and timestamp metadata", call. = FALSE)
  }
  if (blocked && phase13_registry_blank(row$blocked_refresh_batch_id)) {
    stop("Phase 13 blocked editions require a refresh batch ID", call. = FALSE)
  }
  row$row_sha256 <- phase13_registry_row_hash(row)
  row
}

phase13_validate_competition_edition_registries <- function(
    registries,
    source_bundles = NULL,
    approved_model_release_ids = phase13_approved_model_release_ids(),
    trusted_release_root = NULL,
    selector_path = NULL,
    resolved_release = NULL,
    require_complete = NULL,
    project_root = ".") {
  if (!is.data.frame(registries)) stop("Phase 13 competition edition registry must be a data frame", call. = FALSE)
  required <- phase13_competition_edition_required_columns()
  missing <- setdiff(required, names(registries))
  if (length(missing)) stop("Phase 13 competition edition registry missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  if (is.null(require_complete)) require_complete <- isTRUE(attr(registries, "phase13_complete_registry"))
  if (is.null(source_bundles)) source_bundles <- attr(registries, "source_bundles")
  if (is.null(trusted_release_root)) trusted_release_root <- attr(registries, "trusted_release_root")
  if (is.null(trusted_release_root)) trusted_release_root <- "outputs/releases"
  if (is.null(selector_path)) selector_path <- attr(registries, "selector_path")
  if (!nrow(registries)) {
    if (isTRUE(require_complete)) stop("Phase 13 competition edition registry must contain both required editions", call. = FALSE)
    return(invisible(registries))
  }

  if (anyDuplicated(as.character(registries$edition_id))) stop("Phase 13 competition edition registry has duplicate edition IDs", call. = FALSE)
  required_nonempty <- c(
    "edition_id", "source_edition_id", "competition_id", "display_name", "lifecycle_state", "ruleset_version",
    "source_bundle_id", "model_release_id", "output_bundle_target", "active_output_bundle_id",
    "last_accepted_output_bundle_id", "audit_event", "audit_at_utc", "operator"
  )
  for (column in required_nonempty) {
    if (any(vapply(registries[[column]], phase13_registry_blank, logical(1)))) {
      stop("Phase 13 competition edition registry contains empty required field: ", column, call. = FALSE)
    }
  }
  if (any(!as.character(registries$lifecycle_state) %in% phase13_competition_lifecycle_states())) stop("Phase 13 competition edition registry contains invalid lifecycle state", call. = FALSE)
  if (any(!grepl("^outputs/competition/[^/]+(?:/[^/]+)*$", as.character(registries$output_bundle_target)))) {
    stop("Phase 13 output bundle targets must remain under outputs/competition", call. = FALSE)
  }
  revisions <- suppressWarnings(as.integer(registries$registry_revision))
  if (any(is.na(revisions) | revisions < 1L)) stop("Phase 13 registry revisions must be positive integers", call. = FALSE)
  blocked <- vapply(registries$blocked, phase13_registry_logical, logical(1), name = "blocked")
  if (any(blocked & (
    vapply(registries$blocked_reason, phase13_registry_blank, logical(1)) |
    vapply(registries$blocked_at_utc, phase13_registry_blank, logical(1)) |
    vapply(registries$last_refresh_failure, phase13_registry_blank, logical(1)) |
    vapply(registries$last_refresh_failure_at_utc, phase13_registry_blank, logical(1)) |
    vapply(registries$blocked_refresh_batch_id, phase13_registry_blank, logical(1))
  ))) {
    stop("Phase 13 blocked editions require failure reason and timestamp metadata", call. = FALSE)
  }
  if (any(blocked & as.character(registries$last_accepted_output_bundle_id) != as.character(registries$active_output_bundle_id))) {
    stop("Phase 13 blocked editions must retain the active last accepted output bundle", call. = FALSE)
  }

  if (is.null(source_bundles)) stop("Phase 13 competition edition registry requires source bundle linkage", call. = FALSE)
  source_required <- c("bundle_id", "edition_id", "bundle_status")
  missing_source <- setdiff(source_required, names(source_bundles))
  if (length(missing_source)) stop("Phase 13 source bundle registry missing columns: ", paste(missing_source, collapse = ", "), call. = FALSE)
  if (anyDuplicated(as.character(source_bundles$bundle_id))) stop("Phase 13 source bundle registry has duplicate bundle IDs", call. = FALSE)
  for (index in seq_len(nrow(registries))) {
    bundle <- source_bundles[as.character(source_bundles$bundle_id) == as.character(registries$source_bundle_id[[index]]), , drop = FALSE]
    if (nrow(bundle) != 1L || as.character(bundle$edition_id[[1L]]) != as.character(registries$edition_id[[index]]) || as.character(bundle$bundle_status[[1L]]) != "accepted") {
      stop("Phase 13 competition edition registry references a non-accepted source bundle", call. = FALSE)
    }
  }

  phase13_validate_approved_model_release_pin(
    registries$model_release_id,
    trusted_root = trusted_release_root,
    approved_model_release_ids = approved_model_release_ids,
    selector_path = selector_path,
    resolved_release = resolved_release,
    project_root = project_root
  )

  if (isTRUE(require_complete)) {
    expected <- phase13_competition_edition_ids()
    if (nrow(registries) != length(expected) || !setequal(as.character(registries$edition_id), expected)) {
      stop("Phase 13 competition edition registry must contain exactly the Nations League and EURO qualifying editions", call. = FALSE)
    }
    euro <- registries[registries$edition_id == "uefa_euro_2028_qualifying", , drop = FALSE]
    nl <- registries[registries$edition_id == "uefa_nations_league_2026_27", , drop = FALSE]
    if (nrow(euro) != 1L || euro$lifecycle_state[[1L]] != "pre_draw" || euro$official_draw_date[[1L]] != "2026-12-06") {
      stop("Phase 13 EURO qualifying registry must remain an explicit 2026-12-06 pre-draw edition", call. = FALSE)
    }
    if (nrow(nl) != 1L) stop("Phase 13 Nations League edition is missing", call. = FALSE)
  }
  predraw <- as.character(registries$lifecycle_state) == "pre_draw"
  forbidden_columns <- intersect(c("group_count", "fixture_count", "standings_hash", "fixtures_hash", "probability_hash"), names(registries))
  if (length(forbidden_columns)) {
    for (column in forbidden_columns) {
      if (any(predraw & !vapply(registries[[column]], phase13_registry_blank, logical(1)))) stop("Phase 13 pre-draw registry cannot fabricate competition structures", call. = FALSE)
    }
  }

  actual <- tolower(as.character(registries$row_sha256))
  expected_hash <- phase13_registry_row_hash(registries)
  if (any(is.na(actual) | !grepl("^[0-9a-f]{64}$", actual)) || any(actual != expected_hash)) {
    stop("Phase 13 competition edition registry row SHA-256 mismatch", call. = FALSE)
  }
  invisible(registries)
}

phase13_validate_competition_edition_row <- function(
    row,
    source_bundles = NULL,
    approved_model_release_ids = phase13_approved_model_release_ids(),
    trusted_release_root = "outputs/releases",
    selector_path = NULL,
    resolved_release = NULL,
    project_root = ".") {
  phase13_validate_competition_edition_registries(
    row,
    source_bundles = source_bundles,
    approved_model_release_ids = approved_model_release_ids,
    trusted_release_root = trusted_release_root,
    selector_path = selector_path,
    resolved_release = resolved_release,
    require_complete = FALSE,
    project_root = project_root
  )
  invisible(row)
}

phase13_transition_competition_edition <- function(
    row,
    next_lifecycle_state,
    operator_action = "",
    validation_passed = TRUE,
    operator = NULL,
    audit_at_utc = NULL) {
  if (!is.data.frame(row) || nrow(row) != 1L) stop("Phase 13 lifecycle transition requires one registry row", call. = FALSE)
  blocked <- phase13_registry_logical(row$blocked[[1L]], "blocked")
  if (blocked && (!isTRUE(validation_passed) || phase13_registry_blank(operator_action))) {
    stop("Phase 13 blocked lifecycle recovery requires explicit operator action and validation", call. = FALSE)
  }
  phase13_validate_lifecycle_transition(row$lifecycle_state[[1L]], next_lifecycle_state)
  row$lifecycle_state <- phase13_registry_scalar(next_lifecycle_state, "next lifecycle state")
  row$blocked <- FALSE
  if (!"blocked_refresh_batch_id" %in% names(row)) row$blocked_refresh_batch_id <- ""
  row$blocked_reason <- ""
  row$blocked_at_utc <- ""
  row$audit_event <- paste0("lifecycle_", row$lifecycle_state[[1L]])
  if (!is.null(operator)) row$operator <- phase13_registry_scalar(operator, "operator")
  if (is.null(audit_at_utc)) audit_at_utc <- if (!phase13_registry_blank(row$audit_at_utc[[1L]])) row$audit_at_utc[[1L]] else "2026-08-13T00:00:00Z"
  row$audit_at_utc <- phase13_registry_scalar(audit_at_utc, "audit_at_utc")
  row$registry_revision <- as.integer(row$registry_revision[[1L]]) + 1L
  row$row_sha256 <- phase13_registry_row_hash(row)
  row
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

phase13_block_competition_edition <- function(
    row,
    failure_reason,
    failure_at_utc,
    operator = "system",
    audit_at_utc = NULL,
    refresh_batch_id = NULL) {
  if (!is.data.frame(row) || nrow(row) != 1L) stop("Phase 13 block operation requires one registry row", call. = FALSE)
  if (!"blocked_refresh_batch_id" %in% names(row)) row$blocked_refresh_batch_id <- ""
  failure_reason <- phase13_registry_scalar(failure_reason, "failure_reason")
  failure_at_utc <- phase13_registry_scalar(failure_at_utc, "failure_at_utc")
  if (phase13_registry_blank(row$active_output_bundle_id[[1L]])) stop("Phase 13 blocked edition must retain an active output bundle", call. = FALSE)
  row$blocked <- TRUE
  if (!is.null(refresh_batch_id)) {
    row$blocked_refresh_batch_id <- phase13_registry_scalar(refresh_batch_id, "refresh_batch_id")
  }
  row$blocked_reason <- failure_reason
  row$blocked_at_utc <- failure_at_utc
  row$last_refresh_failure <- failure_reason
  row$last_refresh_failure_at_utc <- failure_at_utc
  row$last_accepted_output_bundle_id <- as.character(row$active_output_bundle_id[[1L]])
  row$audit_event <- "refresh_blocked"
  row$operator <- phase13_registry_scalar(operator, "operator")
  row$audit_at_utc <- if (is.null(audit_at_utc)) failure_at_utc else phase13_registry_scalar(audit_at_utc, "audit_at_utc")
  row$registry_revision <- as.integer(row$registry_revision[[1L]]) + 1L
  row$row_sha256 <- phase13_registry_row_hash(row)
  row
}

phase13_repin_competition_model_release <- function(
    row,
    model_release_id,
    operator_action,
    audit_at_utc,
    operator = "system",
    trusted_release_root = "outputs/releases",
    project_root = ".") {
  if (!is.data.frame(row) || nrow(row) != 1L) stop("Phase 13 model release repin requires one registry row", call. = FALSE)
  if (phase13_registry_blank(operator_action)) stop("Phase 13 model release repin requires an operator audit action", call. = FALSE)
  phase13_validate_approved_model_release_pin(model_release_id, trusted_release_root, project_root = project_root)
  row$model_release_id <- phase13_registry_scalar(model_release_id, "model_release_id")
  row$registry_revision <- as.integer(row$registry_revision[[1L]]) + 1L
  row$audit_event <- "model_release_repin"
  row$audit_at_utc <- phase13_registry_scalar(audit_at_utc, "audit_at_utc")
  row$operator <- phase13_registry_scalar(operator, "operator")
  row$row_sha256 <- phase13_registry_row_hash(row)
  row
}

phase14_dual_repin_release_id <- function(resolved_release) {
  release_id <- if (is.list(resolved_release)) {
    resolved_release$release_identity$release_id
  } else NULL
  release_id <- as.character(release_id)
  if (length(release_id) != 1L || is.na(release_id) || !nzchar(release_id) ||
      !identical(release_id, "phase14-open-nb-incumbent-calibrated-v1")) {
    stop("selector-release-mismatch: calibrated release identity is invalid", call. = FALSE)
  }
  cutoff <- suppressWarnings(as.Date(as.character(resolved_release$model_data_cutoff)))
  if (length(cutoff) != 1L || is.na(cutoff)) {
    stop("selector-release-mismatch: calibrated release cutoff is missing", call. = FALSE)
  }
  release_id
}

#' Validate a complete two-edition release repin candidate.
#' @export
phase14_validate_dual_repin_candidate <- function(
    prior_registries,
    candidate_registries,
    resolved_release,
    source_bundles) {
  expected_editions <- phase13_competition_edition_ids()
  for (value in list(prior_registries, candidate_registries)) {
    if (!is.data.frame(value) || nrow(value) != length(expected_editions) ||
        !setequal(as.character(value$edition_id), expected_editions) ||
        anyDuplicated(as.character(value$edition_id))) {
      stop("missing-edition-rejected: exactly two required editions must be repinned", call. = FALSE)
    }
  }
  prior_ordered <- prior_registries[match(expected_editions, prior_registries$edition_id), , drop = FALSE]
  candidate_ordered <- candidate_registries[match(expected_editions, candidate_registries$edition_id), , drop = FALSE]
  release_id <- phase14_dual_repin_release_id(resolved_release)
  candidate_ids <- as.character(candidate_ordered$model_release_id)
  if (length(unique(candidate_ids)) != 1L || any(candidate_ids != release_id)) {
    stop("selector-release-mismatch: both edition pins must equal selector authority", call. = FALSE)
  }
  revision_delta <- as.integer(candidate_ordered$registry_revision) -
    as.integer(prior_ordered$registry_revision)
  if (anyNA(revision_delta) || any(revision_delta != 1L)) {
    stop("wrong-revision-delta: each registry revision must increment exactly once", call. = FALSE)
  }
  mutable <- c(
    "model_release_id", "registry_revision", "audit_event",
    "audit_at_utc", "operator", "row_sha256"
  )
  immutable <- setdiff(names(prior_ordered), mutable)
  if (!identical(names(prior_ordered), names(candidate_ordered)) ||
      !identical(prior_ordered[immutable], candidate_ordered[immutable])) {
    stop("changed-lineage: release repin changed edition-local authority or output lineage", call. = FALSE)
  }
  if (any(as.character(candidate_ordered$audit_event) != "model_release_repin")) {
    stop("Phase 14 release repin requires the model_release_repin audit event", call. = FALSE)
  }
  phase13_validate_competition_edition_registries(
    candidate_ordered,
    source_bundles = source_bundles,
    approved_model_release_ids = release_id,
    resolved_release = resolved_release,
    require_complete = TRUE
  )
  invisible(candidate_ordered)
}

#' Repin both allowlisted competition editions in one pure transformation.
#' @export
phase14_repin_both_competition_releases <- function(
    registries,
    resolved_release,
    source_bundles,
    audit_at_utc,
    operator,
    operator_action) {
  expected_editions <- phase13_competition_edition_ids()
  if (!is.data.frame(registries) || nrow(registries) != length(expected_editions) ||
      !setequal(as.character(registries$edition_id), expected_editions) ||
      anyDuplicated(as.character(registries$edition_id))) {
    stop("missing-edition-rejected: exactly two required editions must be repinned", call. = FALSE)
  }
  prior_ids <- as.character(registries$model_release_id)
  if (anyNA(prior_ids) || any(!nzchar(prior_ids)) || length(unique(prior_ids)) != 1L) {
    stop("split-pin-rejected: both editions must share one prior release pin", call. = FALSE)
  }
  phase13_registry_scalar(operator_action, "operator_action")
  audit_at_utc <- phase13_registry_scalar(audit_at_utc, "audit_at_utc")
  operator <- phase13_registry_scalar(operator, "operator")
  release_id <- phase14_dual_repin_release_id(resolved_release)
  prior_resolved <- list(
    release_identity = list(release_id = unique(prior_ids)),
    model_data_cutoff = resolved_release$model_data_cutoff
  )
  phase13_validate_competition_edition_registries(
    registries,
    source_bundles = source_bundles,
    approved_model_release_ids = unique(prior_ids),
    resolved_release = prior_resolved,
    require_complete = TRUE
  )
  candidate <- registries
  candidate$model_release_id <- release_id
  candidate$registry_revision <- as.integer(registries$registry_revision) + 1L
  candidate$audit_event <- "model_release_repin"
  candidate$audit_at_utc <- audit_at_utc
  candidate$operator <- operator
  candidate$row_sha256 <- phase13_registry_row_hash(candidate)
  phase14_validate_dual_repin_candidate(
    registries,
    candidate,
    resolved_release,
    source_bundles
  )
  candidate
}

phase13_accepted_snapshot_resource_types <- function() {
  c("fixtures", "groups", "standings", "results", "status")
}

phase13_accepted_snapshot_manifest_schema <- function() {
  c(
    "schema_version", "bundle_id", "edition_id", "bundle_status", "acceptance_state",
    "fallback_status", "parser_commit_sha", "artifact_count", "required_resource_count",
    "source_bundle_sha256", "artifact_manifest_sha256", "canonical_content_sha256",
    "manifest_self_sha256", "accepted_at_utc", "last_accepted_bundle_id",
    "fallback_source", "fallback_retrieval_date", "fallback_reason", "operator_note",
    "fallback_checksum", "artifact_id", "artifact_type", "source_artifact_id", "source_url",
    "source_url_lineage", "retrieved_at_utc", "bytes", "raw_sha256", "canonical_content_sha256",
    "parser_commit_sha", "fallback_status", "review_state", "relative_local_raw_path",
    "status_provenance", "row_sha256"
  )
}

phase13_accepted_snapshot_is_symlink <- function(path) {
  value <- tryCatch(Sys.readlink(path), error = function(error) "")
  length(value) == 1L && !is.na(value) && nzchar(value)
}

phase13_accepted_snapshot_has_symlink <- function(path, root) {
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  lexical <- gsub("\\\\", "/", as.character(path))
  if (!grepl("^/", lexical)) lexical <- file.path(root, lexical)
  resolved <- normalizePath(lexical, winslash = "/", mustWork = FALSE)
  if (!phase13_source_path_within(resolved, root)) return(TRUE)
  if (identical(lexical, root)) return(phase13_accepted_snapshot_is_symlink(root))
  prefix <- paste0(root, "/")
  # macOS temporary paths may be addressed through /var while normalizePath
  # returns /private/var.  The resolved containment check above is the trust
  # decision for that alias; component inspection applies when lexical roots
  # share the same canonical prefix.
  if (!startsWith(lexical, prefix)) return(FALSE)
  relative <- substring(lexical, nchar(prefix) + 1L)
  parts <- strsplit(relative, "/", fixed = TRUE)[[1L]]
  current <- root
  for (part in parts) {
    current <- file.path(current, part)
    if (phase13_accepted_snapshot_is_symlink(current)) return(TRUE)
  }
  FALSE
}

phase13_accepted_snapshot_resolve_root <- function(project_root, accepted_root) {
  root <- phase13_edition_project_root(project_root)
  if (!dir.exists(root)) stop("Phase 13 accepted snapshot project root is missing", call. = FALSE)
  supplied <- phase13_registry_scalar(accepted_root, "accepted_root")
  lexical <- if (grepl("^/", supplied)) supplied else file.path(root, supplied)
  if (!dir.exists(lexical)) stop("Phase 13 accepted snapshot root is missing: ", lexical, call. = FALSE)
  if (phase13_accepted_snapshot_is_symlink(lexical)) {
    stop("Phase 13 accepted snapshot root must not be a symlink: ", lexical, call. = FALSE)
  }
  resolved <- normalizePath(lexical, winslash = "/", mustWork = TRUE)
  if (!phase13_source_path_within(resolved, root)) {
    stop("Phase 13 accepted snapshot root must remain under the project root", call. = FALSE)
  }
  if (phase13_accepted_snapshot_has_symlink(lexical, root)) {
    stop("Phase 13 accepted snapshot root contains a symlinked path component", call. = FALSE)
  }
  resolved
}

phase13_accepted_snapshot_resolve_raw_root <- function(project_root, raw_root = NULL) {
  root <- phase13_edition_project_root(project_root)
  if (is.null(raw_root)) return(root)
  supplied <- phase13_registry_scalar(raw_root, "raw_root")
  lexical <- if (grepl("^/", supplied)) supplied else file.path(root, supplied)
  if (!dir.exists(lexical)) stop("Phase 13 raw-store root is missing: ", lexical, call. = FALSE)
  if (phase13_accepted_snapshot_is_symlink(lexical)) {
    stop("Phase 13 raw-store root must not be a symlink: ", lexical, call. = FALSE)
  }
  resolved <- normalizePath(lexical, winslash = "/", mustWork = TRUE)
  if (phase13_source_path_within(resolved, root) && phase13_accepted_snapshot_has_symlink(lexical, root)) {
    stop("Phase 13 raw-store root contains a symlinked path component", call. = FALSE)
  }
  resolved
}

phase13_accepted_snapshot_resolve_raw_path <- function(project_root, raw_root = NULL, relative_path) {
  relative_path <- phase13_source_validate_local_raw_path(relative_path)
  if (is.null(raw_root)) {
    root <- phase13_edition_project_root(project_root)
    lexical <- file.path(root, relative_path)
    resolved <- phase13_source_path_under_root(root, relative_path, must_work = TRUE)
    if (phase13_accepted_snapshot_has_symlink(lexical, root)) {
      stop("Phase 13 source raw artifact path contains a symlink: ", relative_path, call. = FALSE)
    }
    return(resolved)
  }
  prefix <- "data/competition/local_raw/"
  suffix <- substring(relative_path, nchar(prefix) + 1L)
  suffix <- phase13_source_safe_relative_path(suffix)
  trusted_root <- phase13_accepted_snapshot_resolve_raw_root(project_root, raw_root)
  lexical <- file.path(trusted_root, suffix)
  resolved <- phase13_source_path_under_root(trusted_root, suffix, must_work = TRUE)
  if (phase13_accepted_snapshot_has_symlink(lexical, trusted_root)) {
    stop("Phase 13 source raw artifact path contains a symlink: ", relative_path, call. = FALSE)
  }
  resolved
}

phase13_accepted_snapshot_csv_hash <- function(path) {
  if (!file.exists(path) || dir.exists(path)) stop("Phase 13 accepted snapshot file is missing: ", path, call. = FALSE)
  bytes <- readBin(path, what = "raw", n = file.info(path)$size)
  phase13_source_sha256(bytes)
}

phase13_accepted_snapshot_table_hash <- function(data) {
  if (!is.data.frame(data)) stop("Phase 13 accepted snapshot table hash requires a data frame", call. = FALSE)
  path <- tempfile("phase13-accepted-table-", fileext = ".csv")
  on.exit(if (file.exists(path)) unlink(path), add = TRUE)
  utils::write.csv(data, path, row.names = FALSE, na = "", quote = TRUE)
  phase13_accepted_snapshot_csv_hash(path)
}

phase13_accepted_snapshot_bundle_content_table <- function(bundle, artifacts) {
  resource_order <- phase13_source_required_resource_types()
  artifact_order <- order(
    match(as.character(artifacts$artifact_type), resource_order),
    as.character(artifacts$artifact_id),
    method = "radix"
  )
  artifacts <- artifacts[artifact_order, , drop = FALSE]
  row.names(artifacts) <- NULL
  bundle_fields <- setdiff(names(bundle), c("canonical_content_sha256", "manifest_self_sha256", "row_sha256"))
  artifact_fields <- setdiff(names(artifacts), c("canonical_content_sha256", "row_sha256"))
  cbind(
    bundle[rep(1L, nrow(artifacts)), bundle_fields, drop = FALSE],
    artifacts[, artifact_fields, drop = FALSE]
  )
}

phase13_accepted_snapshot_require_nonempty <- function(data, columns, name) {
  for (column in columns) {
    values <- as.character(data[[column]])
    if (any(is.na(values) | !nzchar(trimws(values)))) {
      stop(name, " contains an empty required field: ", column, call. = FALSE)
    }
  }
  invisible(TRUE)
}

phase13_accepted_snapshot_validate_manifest <- function(manifest, bundle, artifacts) {
  schema <- phase13_accepted_snapshot_manifest_schema()
  if (!identical(names(manifest), schema) || nrow(manifest) != length(phase13_accepted_snapshot_resource_types())) {
    stop("Phase 13 accepted snapshot manifest schema or resource count is invalid", call. = FALSE)
  }
  phase13_source_validate_hash_column(manifest, "row_sha256", "Phase 13 accepted snapshot manifest")
  phase13_accepted_snapshot_require_nonempty(
    manifest,
    c("bundle_id", "edition_id", "artifact_id", "artifact_type", "source_artifact_id", "raw_sha256", "canonical_content_sha256"),
    "Phase 13 accepted snapshot manifest"
  )
  if (anyDuplicated(as.character(manifest$artifact_id)) ||
      !setequal(as.character(manifest$artifact_type), phase13_accepted_snapshot_resource_types()) ||
      anyDuplicated(as.character(manifest$artifact_type))) {
    stop("Phase 13 accepted snapshot manifest has an incomplete resource graph", call. = FALSE)
  }

  bundle_fields <- c(
    "schema_version", "bundle_id", "edition_id", "bundle_status", "acceptance_state",
    "fallback_status", "parser_commit_sha", "artifact_count", "required_resource_count",
    "source_bundle_sha256", "artifact_manifest_sha256", "canonical_content_sha256",
    "manifest_self_sha256", "accepted_at_utc", "last_accepted_bundle_id",
    "fallback_source", "fallback_retrieval_date", "fallback_reason", "operator_note",
    "fallback_checksum"
  )
  for (index in seq_along(bundle_fields)) {
    actual <- vapply(manifest[[index]], phase13_source_canonical_scalar, character(1))
    expected <- phase13_source_canonical_scalar(bundle[[bundle_fields[[index]]]][[1L]])
    if (any(actual != expected)) {
      stop("Phase 13 accepted snapshot manifest bundle provenance mismatch: ", bundle_fields[[index]], call. = FALSE)
    }
  }

  artifact_fields <- c(
    "artifact_id", "artifact_type", "source_artifact_id", "source_url", "source_url_lineage",
    "retrieved_at_utc", "bytes", "raw_sha256", "canonical_content_sha256", "parser_commit_sha",
    "fallback_status", "review_state", "relative_local_raw_path", "status_provenance"
  )
  artifact_positions <- length(bundle_fields) + seq_along(artifact_fields)
  for (row_index in seq_len(nrow(manifest))) {
    artifact_id <- as.character(manifest[[artifact_positions[[1L]]]][[row_index]])
    artifact <- artifacts[as.character(artifacts$artifact_id) == artifact_id, , drop = FALSE]
    if (nrow(artifact) != 1L) stop("Phase 13 accepted snapshot manifest links an unknown artifact: ", artifact_id, call. = FALSE)
    for (field_index in seq_along(artifact_fields)) {
      actual <- phase13_source_canonical_scalar(manifest[[artifact_positions[[field_index]]]][[row_index]])
      expected <- phase13_source_canonical_scalar(artifact[[artifact_fields[[field_index]]]][[1L]])
      if (!identical(actual, expected)) {
        stop("Phase 13 accepted snapshot manifest artifact link mismatch: ", artifact_id, "/", artifact_fields[[field_index]], call. = FALSE)
      }
    }
  }

  expected_self <- phase13_source_manifest_self_sha256(bundle, artifacts)
  if (any(tolower(as.character(manifest$manifest_self_sha256)) != tolower(expected_self))) {
    stop("Phase 13 accepted snapshot manifest self-hash mismatch", call. = FALSE)
  }
  manifest_bundle_hashes_match <- all(
    tolower(as.character(manifest$source_bundle_sha256)) == tolower(as.character(bundle$source_bundle_sha256[[1L]])),
    tolower(as.character(manifest$artifact_manifest_sha256)) == tolower(as.character(bundle$artifact_manifest_sha256[[1L]])),
    tolower(as.character(manifest[[12L]])) == tolower(as.character(bundle$canonical_content_sha256[[1L]]))
  )
  if (!manifest_bundle_hashes_match) {
    stop("Phase 13 accepted snapshot manifest bundle hash links are stale or forged", call. = FALSE)
  }
  expected_bundle_content <- phase13_accepted_snapshot_table_hash(
    phase13_accepted_snapshot_bundle_content_table(bundle, artifacts)
  )
  if (!identical(tolower(expected_bundle_content), tolower(as.character(bundle$canonical_content_sha256[[1L]])))) {
    stop("Phase 13 source bundle canonical content hash is stale or forged", call. = FALSE)
  }
  invisible(TRUE)
}

phase13_accepted_snapshot_table_schema <- function(artifact_type, schema_version = NULL) {
  if (!is.null(schema_version)) {
    schema_version <- phase13_registry_scalar(schema_version, "schema_version")
    if (identical(schema_version, "phase14-normalized-fixture-v2") && identical(artifact_type, "fixtures")) {
      return(phase14_normalized_fixture_schema())
    }
    if (identical(schema_version, "phase14-normalized-result-v2") && identical(artifact_type, "results")) {
      return(phase14_normalized_result_schema())
    }
    if (identical(schema_version, "phase14-normalized-standings-v2") && identical(artifact_type, "standings")) {
      return(phase14_normalized_standings_schema())
    }
    stop("Phase 14 accepted snapshot schema version is unsupported for ", artifact_type, call. = FALSE)
  }
  if (identical(artifact_type, "fixtures")) return(phase13_normalized_fixture_schema())
  if (identical(artifact_type, "results")) return(phase13_normalized_result_schema())
  compact <- phase13_source_compact_resource_schema()[[artifact_type]]
  c("schema_version", compact, "edition_id", "source_artifact_id", "row_sha256")
}

phase13_accepted_snapshot_detect_schema_version <- function(table, artifact_type) {
  if (identical(artifact_type, "fixtures") &&
      identical(names(table), phase14_normalized_fixture_schema())) {
    return("phase14-normalized-fixture-v2")
  }
  if (identical(artifact_type, "results") &&
      identical(names(table), phase14_normalized_result_schema())) {
    return("phase14-normalized-result-v2")
  }
  if (identical(artifact_type, "standings") &&
      identical(names(table), phase14_normalized_standings_schema())) {
    return("phase14-normalized-standings-v2")
  }
  NULL
}

phase13_accepted_snapshot_validate_identity_links <- function(data, identity_registry, name) {
  if (is.null(identity_registry) || !nrow(data)) return(invisible(TRUE))
  required <- c("team_id", "uefa_source_team_id")
  if (!all(required %in% names(identity_registry))) {
    stop("Phase 13 accepted snapshot identity registry is incomplete", call. = FALSE)
  }
  for (index in seq_len(nrow(data))) {
    for (side in c("home", "away")) {
      team_id <- as.character(data[[paste0(side, "_team_id")]][[index]])
      source_id <- as.character(data[[paste0(side, "_uefa_source_team_id")]][[index]])
      match <- identity_registry[as.character(identity_registry$team_id) == team_id, , drop = FALSE]
      if (nrow(match) != 1L || !identical(as.character(match$uefa_source_team_id[[1L]]), source_id)) {
        stop(name, " contains a forged or unknown stable/source team identity", call. = FALSE)
      }
    }
  }
  invisible(TRUE)
}

phase13_accepted_snapshot_validate_fixture_rows <- function(fixtures, identity_registry) {
  if (!nrow(fixtures)) return(invisible(TRUE))
  status_field <- if ("status" %in% names(fixtures)) "status" else "source_status"
  phase13_accepted_snapshot_require_nonempty(
    fixtures,
    c(
      "fixture_id", "uefa_source_fixture_id", "home_team_id", "away_team_id",
      "home_uefa_source_team_id", "away_uefa_source_team_id", "home_display_name",
      "away_display_name", "scheduled_at_utc", status_field, "source_artifact_id"
    ),
    "Phase 13 normalized accepted fixtures"
  )
  if (anyDuplicated(as.character(fixtures$fixture_id)) || anyDuplicated(as.character(fixtures$uefa_source_fixture_id))) {
    stop("Phase 13 normalized accepted fixtures contain duplicate stable fixture identities", call. = FALSE)
  }
  if (any(as.character(fixtures$home_team_id) == as.character(fixtures$away_team_id))) {
    stop("Phase 13 normalized accepted fixtures contain identical home and away teams", call. = FALSE)
  }
  phase13_accepted_snapshot_validate_identity_links(fixtures, identity_registry, "Phase 13 normalized accepted fixtures")
  invisible(TRUE)
}

phase13_accepted_snapshot_validate_result_rows <- function(results, fixtures, identity_registry) {
  if (!nrow(results)) return(invisible(TRUE))
  if (!nrow(fixtures)) stop("Phase 13 normalized accepted results require normalized fixtures", call. = FALSE)
  status_field <- if ("status" %in% names(results)) "status" else "source_status"
  phase13_accepted_snapshot_require_nonempty(
    results,
    c(
      "fixture_id", "uefa_source_fixture_id", "home_team_id", "away_team_id",
      "home_uefa_source_team_id", "away_uefa_source_team_id", "home_display_name",
      "away_display_name", "scheduled_at_utc", status_field, "source_artifact_id",
      "fixture_source_artifact_id"
    ),
    "Phase 13 normalized accepted results"
  )
  if (anyDuplicated(as.character(results$fixture_id)) || anyDuplicated(as.character(results$uefa_source_fixture_id))) {
    stop("Phase 13 normalized accepted results contain duplicate fixture identities", call. = FALSE)
  }
  fixture_index <- match(as.character(results$uefa_source_fixture_id), as.character(fixtures$uefa_source_fixture_id))
  if (anyNA(fixture_index)) stop("Phase 13 normalized accepted results contain an unknown fixture join", call. = FALSE)
  fixture_rows <- fixtures[fixture_index, , drop = FALSE]
  identity_columns <- c(
    "fixture_id", "home_team_id", "away_team_id", "home_uefa_source_team_id",
    "away_uefa_source_team_id", "home_display_name", "away_display_name",
    "scheduled_at_utc"
  )
  for (column in identity_columns) {
    if (any(as.character(results[[column]]) != as.character(fixture_rows[[column]]))) {
      stop("Phase 13 normalized accepted results do not inherit fixture identity: ", column, call. = FALSE)
    }
  }
  if (any(as.character(results$fixture_source_artifact_id) != as.character(fixture_rows$source_artifact_id))) {
    stop("Phase 13 normalized accepted results have forged fixture artifact lineage", call. = FALSE)
  }
  for (column in c("home_goals", "away_goals")) {
    values <- suppressWarnings(as.numeric(as.character(results[[column]])))
    if (any(!is.na(values) & (!is.finite(values) | values < 0 | values != floor(values)))) {
      stop("Phase 13 normalized accepted results contain invalid goal values: ", column, call. = FALSE)
    }
  }
  if (any(xor(is.na(results$home_goals), is.na(results$away_goals)))) {
    stop("Phase 13 normalized accepted results must provide both goals or neither", call. = FALSE)
  }
  phase13_accepted_snapshot_validate_identity_links(results, identity_registry, "Phase 13 normalized accepted results")
  invisible(TRUE)
}

phase13_accepted_snapshot_manifest_artifact_positions <- function() {
  bundle_count <- 21L - 1L
  bundle_count + seq_along(c(
    "artifact_id", "artifact_type", "source_artifact_id", "source_url", "source_url_lineage",
    "retrieved_at_utc", "bytes", "raw_sha256", "canonical_content_sha256", "parser_commit_sha",
    "fallback_status", "review_state", "relative_local_raw_path", "status_provenance"
  ))
}

phase13_accepted_snapshot_validate_raw_provenance <- function(
    project_root,
    artifacts,
    manifest,
    raw_root = NULL) {
  positions <- phase13_accepted_snapshot_manifest_artifact_positions()
  for (index in seq_len(nrow(artifacts))) {
    artifact <- artifacts[index, , drop = FALSE]
    relative_path <- phase13_source_validate_local_raw_path(as.character(artifact$relative_local_raw_path[[1L]]))
    raw_path <- phase13_accepted_snapshot_resolve_raw_path(project_root, raw_root, relative_path)
    raw_bytes <- readBin(raw_path, what = "raw", n = file.info(raw_path)$size)
    if (length(raw_bytes) != as.integer(artifact$bytes[[1L]]) ||
        !identical(tolower(phase13_source_sha256(raw_bytes)), tolower(as.character(artifact$raw_sha256[[1L]])))) {
      stop("Phase 13 source raw artifact bytes or SHA-256 do not match: ", artifact$artifact_id[[1L]], call. = FALSE)
    }
    manifest_row <- manifest[as.character(manifest[[positions[[1L]]]]) == as.character(artifact$artifact_id[[1L]]), , drop = FALSE]
    if (nrow(manifest_row) != 1L ||
        !identical(tolower(as.character(manifest_row[[positions[[8L]]]][[1L]])), tolower(as.character(artifact$raw_sha256[[1L]])))) {
      stop("Phase 13 accepted manifest raw SHA-256 link is stale or forged: ", artifact$artifact_id[[1L]], call. = FALSE)
    }
  }
  invisible(TRUE)
}

phase13_accepted_snapshot_validate_status_lineage <- function(status, status_artifact, artifacts, manifest) {
  if (!identical(as.character(status_artifact$status_provenance[[1L]]), "derived")) return(invisible(TRUE))
  values <- unique(unlist(strsplit(as.character(status$source_artifact_id), "\\|", fixed = FALSE), use.names = FALSE))
  values <- values[!is.na(values) & nzchar(values)]
  if (!length(values) || !identical(values, sort(values))) {
    stop("Phase 13 derived status source_artifact_id lineage must be sorted and non-empty", call. = FALSE)
  }
  registry_contributors <- unique(c(as.character(artifacts$artifact_id), as.character(artifacts$source_artifact_id)))
  positions <- phase13_accepted_snapshot_manifest_artifact_positions()
  manifest_contributors <- unique(c(as.character(manifest[[positions[[1L]]]]), as.character(manifest[[positions[[3L]]]])))
  if (any(!values %in% registry_contributors) || any(!values %in% manifest_contributors)) {
    stop("Phase 13 derived status lineage references an unregistered contributor", call. = FALSE)
  }
  invisible(TRUE)
}

phase13_validate_accepted_snapshot <- function(
    accepted_dir,
    edition_row,
    source_bundles,
    source_artifacts,
    project_root = ".",
    identity_registry = NULL,
    raw_root = NULL) {
  phase13_edition_source_contracts(project_root)
  if (!is.data.frame(edition_row) || nrow(edition_row) != 1L) {
    stop("Phase 13 accepted snapshot validation requires one edition registry row", call. = FALSE)
  }
  phase13_source_require_columns(
    edition_row,
    c("edition_id", "source_edition_id", "lifecycle_state", "source_bundle_id"),
    "Phase 13 competition edition registry"
  )
  phase13_source_require_columns(source_bundles, c("bundle_id", "edition_id"), "Phase 13 source bundle registry")
  phase13_source_require_columns(source_artifacts, c("artifact_id", "bundle_id", "edition_id", "artifact_type"), "Phase 13 source artifact registry")
  edition_id <- phase13_registry_scalar(edition_row$edition_id, "edition_id")
  lifecycle_state <- phase13_registry_scalar(edition_row$lifecycle_state, "lifecycle_state")
  bundle_id <- phase13_registry_scalar(edition_row$source_bundle_id, "source_bundle_id")
  if (!lifecycle_state %in% phase13_competition_lifecycle_states()) stop("Phase 13 accepted snapshot lifecycle state is unsupported", call. = FALSE)
  if (phase13_accepted_snapshot_is_symlink(accepted_dir)) stop("Phase 13 accepted snapshot directory must not be a symlink", call. = FALSE)
  if (!dir.exists(accepted_dir)) stop("Phase 13 accepted snapshot directory is missing: ", accepted_dir, call. = FALSE)
  accepted_dir <- normalizePath(accepted_dir, winslash = "/", mustWork = TRUE)
  if (phase13_accepted_snapshot_has_symlink(accepted_dir, project_root)) stop("Phase 13 accepted snapshot directory contains a symlink", call. = FALSE)
  required <- phase13_accepted_snapshot_resource_types()
  expected_files <- paste0(c("source_bundle_manifest", required), ".csv")
  actual_files <- list.files(accepted_dir, all.files = FALSE, full.names = FALSE, no.. = TRUE)
  if (!identical(sort(actual_files), sort(expected_files))) {
    stop("Phase 13 accepted snapshot directory must contain exactly one manifest and five resource tables", call. = FALSE)
  }
  read_table <- function(name) {
    path <- file.path(accepted_dir, name)
    if (phase13_accepted_snapshot_is_symlink(path) || !file.exists(path) || dir.exists(path)) {
      stop("Phase 13 accepted snapshot file is missing or symlinked: ", path, call. = FALSE)
    }
    utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  }

  bundle <- source_bundles[as.character(source_bundles$bundle_id) == bundle_id, , drop = FALSE]
  if (nrow(bundle) != 1L || !identical(as.character(bundle$edition_id[[1L]]), edition_id)) {
    stop("Phase 13 accepted snapshot references a missing or foreign source bundle", call. = FALSE)
  }
  artifacts <- source_artifacts[
    as.character(source_artifacts$bundle_id) == bundle_id &
      as.character(source_artifacts$edition_id) == edition_id,
    , drop = FALSE
  ]
  if (nrow(artifacts) != length(required) || !setequal(as.character(artifacts$artifact_type), required) ||
      anyDuplicated(as.character(artifacts$artifact_type))) {
    stop("Phase 13 accepted snapshot source artifact registry is incomplete", call. = FALSE)
  }
  if (!"canonical_content_sha256" %in% names(bundle) || !"canonical_content_sha256" %in% names(artifacts)) {
    stop("Phase 13 accepted snapshot source registries require canonical content hashes", call. = FALSE)
  }
  phase13_validate_source_bundle(bundle, artifacts)

  manifest <- read_table("source_bundle_manifest.csv")
  phase13_accepted_snapshot_validate_manifest(manifest, bundle, artifacts)
  phase13_accepted_snapshot_validate_raw_provenance(project_root, artifacts, manifest, raw_root = raw_root)

  tables <- setNames(vector("list", length(required)), required)
  for (artifact_type in required) {
    table <- read_table(paste0(artifact_type, ".csv"))
    schema_version <- phase13_accepted_snapshot_detect_schema_version(table, artifact_type)
    expected_schema <- phase13_accepted_snapshot_table_schema(artifact_type, schema_version = schema_version)
    if (!identical(names(table), expected_schema)) {
      stop("Phase 13 accepted snapshot schema mismatch: ", artifact_type, call. = FALSE)
    }
    if (!is.null(schema_version) && nrow(table) && any(as.character(table$schema_version) != schema_version)) {
      stop("Phase 14 accepted snapshot schema-version value is inconsistent: ", artifact_type, call. = FALSE)
    }
    phase13_source_validate_hash_column(table, "row_sha256", paste("Phase 13 accepted", artifact_type))
    if (nrow(table)) {
      phase13_accepted_snapshot_require_nonempty(
        table,
        c("schema_version", "edition_id", "source_artifact_id"),
        paste("Phase 13 accepted", artifact_type)
      )
      if (any(as.character(table$edition_id) != edition_id)) {
        stop("Phase 13 accepted snapshot edition_id mismatch: ", artifact_type, call. = FALSE)
      }
    }
    artifact <- artifacts[as.character(artifacts$artifact_type) == artifact_type, , drop = FALSE]
    if (nrow(artifact) != 1L) stop("Phase 13 accepted snapshot artifact link is incomplete: ", artifact_type, call. = FALSE)
    if (nrow(table) && any(as.character(table$source_artifact_id) != as.character(artifact$source_artifact_id[[1L]]))) {
      stop("Phase 13 accepted snapshot source_artifact_id mismatch: ", artifact_type, call. = FALSE)
    }
    manifest_row <- manifest[as.character(manifest[[21L]]) == as.character(artifact$artifact_id[[1L]]), , drop = FALSE]
    if (nrow(manifest_row) != 1L) stop("Phase 13 accepted snapshot manifest artifact link is incomplete: ", artifact_type, call. = FALSE)
    actual_hash <- phase13_accepted_snapshot_csv_hash(file.path(accepted_dir, paste0(artifact_type, ".csv")))
    if (!identical(tolower(actual_hash), tolower(as.character(artifact$canonical_content_sha256[[1L]]))) ||
        !identical(tolower(actual_hash), tolower(as.character(manifest_row[[29L]][[1L]])))) {
      stop("Phase 13 accepted snapshot canonical content hash mismatch: ", artifact_type, call. = FALSE)
    }
    tables[[artifact_type]] <- table
  }

  phase13_accepted_snapshot_validate_fixture_rows(tables$fixtures, identity_registry)
  phase13_accepted_snapshot_validate_result_rows(tables$results, tables$fixtures, identity_registry)
  if (nrow(tables$status) != 1L) stop("Phase 13 accepted snapshot requires exactly one status row", call. = FALSE)
  phase13_accepted_snapshot_require_nonempty(tables$status, c("source_edition_id", "competition_status"), "Phase 13 accepted status")
  status_artifact <- artifacts[as.character(artifacts$artifact_type) == "status", , drop = FALSE]
  phase13_accepted_snapshot_validate_status_lineage(tables$status, status_artifact, artifacts, manifest)
  if (!identical(as.character(tables$status$competition_status[[1L]]), lifecycle_state)) {
    stop("Phase 13 accepted status does not match the edition lifecycle state", call. = FALSE)
  }
  if (identical(lifecycle_state, "pre_draw") && any(vapply(tables[setdiff(required, "status")], nrow, integer(1)) != 0L)) {
    stop("Phase 13 EURO pre_draw accepted snapshot must keep all structures empty", call. = FALSE)
  }

  list(
    edition_id = edition_id,
    bundle_id = bundle_id,
    source_bundle = bundle,
    source_artifacts = artifacts,
    source_bundle_manifest = manifest,
    manifest = manifest,
    fixtures = tables$fixtures,
    groups = tables$groups,
    standings = tables$standings,
    results = tables$results,
    status = tables$status
  )
}

load_competition_edition_registries <- function(
    registry_dir = "data/competition/registries",
    project_root = ".",
    validate = TRUE,
    trusted_release_root = NULL,
    accepted_root = NULL,
    raw_root = NULL) {
  root <- phase13_edition_project_root(project_root)
  phase13_edition_source_contracts(root)
  registry_dir <- as.character(registry_dir)
  if (length(registry_dir) != 1L || is.na(registry_dir) || !nzchar(registry_dir)) stop("Phase 13 competition registry directory is invalid", call. = FALSE)
  if (!grepl("^/", registry_dir)) registry_dir <- file.path(root, registry_dir)
  registry_dir <- normalizePath(registry_dir, winslash = "/", mustWork = TRUE)
  edition_path <- file.path(registry_dir, "competition_editions.csv")
  bundle_path <- file.path(registry_dir, "source_bundles.csv")
  artifact_path <- file.path(registry_dir, "source_artifacts.csv")
  paths <- c(edition_path, bundle_path, artifact_path)
  missing <- paths[!file.exists(paths)]
  if (length(missing)) stop("Phase 13 competition registry files are missing: ", paste(basename(missing), collapse = ", "), call. = FALSE)
  registries <- utils::read.csv(edition_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  source_bundles <- utils::read.csv(bundle_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  source_artifacts <- utils::read.csv(artifact_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  identity_path <- file.path(registry_dir, "team_identity.csv")
  identity_registry <- NULL
  if (file.exists(identity_path)) {
    identity_registry <- load_phase13_team_identity_registry(
      identity_path,
      validate = isTRUE(validate),
      source_bundles = source_bundles
    )
  }
  for (bundle_id in unique(as.character(source_bundles$bundle_id))) {
    bundle <- source_bundles[source_bundles$bundle_id == bundle_id, , drop = FALSE]
    artifacts <- source_artifacts[source_artifacts$bundle_id == bundle_id, , drop = FALSE]
    validate_phase13_source_bundle(bundle, artifacts)
  }
  attr(registries, "source_bundles") <- source_bundles
  attr(registries, "source_artifacts") <- source_artifacts
  if (!is.null(identity_registry)) attr(registries, "team_identity") <- identity_registry
  attr(registries, "path") <- edition_path
  attr(registries, "trusted_root") <- root
  if (is.null(trusted_release_root)) trusted_release_root <- file.path(root, "outputs/releases")
  attr(registries, "trusted_release_root") <- trusted_release_root
  selector_path <- file.path(trusted_release_root, "approved_release.csv")
  if (file.exists(selector_path)) attr(registries, "selector_path") <- selector_path
  attr(registries, "phase13_complete_registry") <- TRUE
  if (isTRUE(validate)) {
    phase13_validate_competition_edition_registries(
      registries,
      source_bundles = source_bundles,
      trusted_release_root = trusted_release_root,
      selector_path = if (file.exists(selector_path)) selector_path else NULL,
      require_complete = TRUE,
      project_root = root
    )
    if (is.null(accepted_root)) accepted_root <- file.path(root, "data/competition/accepted")
    accepted_root <- phase13_accepted_snapshot_resolve_root(root, accepted_root)
    accepted_snapshots <- lapply(seq_len(nrow(registries)), function(index) {
      edition_row <- registries[index, , drop = FALSE]
      phase13_validate_accepted_snapshot(
        accepted_dir = file.path(accepted_root, as.character(edition_row$edition_id[[1L]])),
        edition_row = edition_row,
        source_bundles = source_bundles,
        source_artifacts = source_artifacts,
        project_root = root,
        identity_registry = identity_registry,
        raw_root = raw_root
      )
    })
    names(accepted_snapshots) <- as.character(registries$edition_id)
    attr(registries, "accepted_snapshots") <- accepted_snapshots
    attr(registries, "accepted_root") <- accepted_root
  }
  class(registries) <- c("phase13_competition_registry", class(registries))
  registries
}

`$.phase13_competition_registry` <- function(x, name) {
  if (identical(name, "accepted_snapshots")) return(attr(x, "accepted_snapshots"))
  NextMethod("$")
}

load_phase13_competition_edition_registries <- load_competition_edition_registries
phase13_load_competition_edition_registries <- load_competition_edition_registries

validate_competition_edition_registries <- phase13_validate_competition_edition_registries
validate_phase13_competition_edition_registries <- phase13_validate_competition_edition_registries
