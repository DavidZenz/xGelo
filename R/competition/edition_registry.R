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
    "last_accepted_output_bundle_id", "blocked", "blocked_reason", "blocked_at_utc",
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
  # This is a compatibility projection.  Acceptance still preflights the
  # trusted Phase 12 release root and compares every row with its metadata.
  "phase12-wc2026-incumbent-retained-v1"
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
  if (exists("phase13_source_find_project_root", mode = "function")) {
    return(phase13_source_find_project_root(path))
  }
  candidate <- normalizePath(path, winslash = "/", mustWork = FALSE)
  if (file.exists(candidate) && !dir.exists(candidate)) candidate <- dirname(candidate)
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
    project_root = ".") {
  root <- phase13_edition_project_root(project_root)
  phase13_edition_source_contracts(root)
  trusted_root <- as.character(trusted_root)
  if (length(trusted_root) != 1L || is.na(trusted_root) || !nzchar(trusted_root)) {
    stop("Phase 13 approved release root is invalid", call. = FALSE)
  }
  if (!grepl("^/", trusted_root)) trusted_root <- file.path(root, trusted_root)
  preflight_phase12_approved_release(trusted_root, release_manifest_path)
}

phase13_validate_approved_model_release_pin <- function(
    model_release_ids,
    trusted_root = "outputs/releases",
    approved_model_release_ids = phase13_approved_model_release_ids(),
    project_root = ".") {
  preflight <- phase13_preflight_approved_model_release(trusted_root, project_root = project_root)
  expected <- as.character(preflight$metadata$release_id)
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
  row$row_sha256 <- phase13_registry_row_hash(row)
  row
}

phase13_validate_competition_edition_registries <- function(
    registries,
    source_bundles = NULL,
    approved_model_release_ids = phase13_approved_model_release_ids(),
    trusted_release_root = NULL,
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
    vapply(registries$last_refresh_failure_at_utc, phase13_registry_blank, logical(1))
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
    project_root = ".") {
  phase13_validate_competition_edition_registries(
    row,
    source_bundles = source_bundles,
    approved_model_release_ids = approved_model_release_ids,
    trusted_release_root = trusted_release_root,
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
    audit_at_utc = NULL) {
  if (!is.data.frame(row) || nrow(row) != 1L) stop("Phase 13 block operation requires one registry row", call. = FALSE)
  failure_reason <- phase13_registry_scalar(failure_reason, "failure_reason")
  failure_at_utc <- phase13_registry_scalar(failure_at_utc, "failure_at_utc")
  if (phase13_registry_blank(row$active_output_bundle_id[[1L]])) stop("Phase 13 blocked edition must retain an active output bundle", call. = FALSE)
  row$blocked <- TRUE
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

load_competition_edition_registries <- function(
    registry_dir = "data/competition/registries",
    project_root = ".",
    validate = TRUE,
    trusted_release_root = NULL) {
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
  for (bundle_id in unique(as.character(source_bundles$bundle_id))) {
    bundle <- source_bundles[source_bundles$bundle_id == bundle_id, , drop = FALSE]
    artifacts <- source_artifacts[source_artifacts$bundle_id == bundle_id, , drop = FALSE]
    validate_phase13_source_bundle(bundle, artifacts)
  }
  attr(registries, "source_bundles") <- source_bundles
  attr(registries, "source_artifacts") <- source_artifacts
  attr(registries, "path") <- edition_path
  attr(registries, "trusted_root") <- root
  if (is.null(trusted_release_root)) trusted_release_root <- file.path(root, "outputs/releases")
  attr(registries, "trusted_release_root") <- trusted_release_root
  attr(registries, "phase13_complete_registry") <- TRUE
  if (isTRUE(validate)) {
    phase13_validate_competition_edition_registries(
      registries,
      source_bundles = source_bundles,
      trusted_release_root = trusted_release_root,
      require_complete = TRUE,
      project_root = root
    )
  }
  registries
}

load_phase13_competition_edition_registries <- load_competition_edition_registries
phase13_load_competition_edition_registries <- load_competition_edition_registries

validate_competition_edition_registries <- phase13_validate_competition_edition_registries
validate_phase13_competition_edition_registries <- phase13_validate_competition_edition_registries
