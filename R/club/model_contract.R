#' Phase 19 club-only model authority and unavailable-feature contracts.
#'
#' Production functions in this module deliberately expose no caller-selectable
#' evidence paths. They resolve the repository's fixed Phase 18 descriptors.
#' Synthetic evidence is admitted only through separately named fixture loaders
#' whose roots are marker-bound children of the current process temporary root.

.phase19_club_project_root <- local({
  candidate <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  repeat {
    marker <- file.path(candidate, ".planning")
    module <- file.path(candidate, "R/club/model_contract.R")
    if (dir.exists(marker) && file.exists(module)) break
    parent <- dirname(candidate)
    if (identical(parent, candidate)) {
      stop("Could not locate the xGelo project root for Phase 19 authority", call. = FALSE)
    }
    candidate <- parent
  }
  candidate
})

phase19_club_abort <- function(reason_code, message, data = list()) {
  class_name <- switch(
    as.character(reason_code),
    fixture_authority = "phase19_fixture_authority_error",
    arbitrary_authority = "phase19_arbitrary_authority_error",
    domain_mismatch = "phase19_domain_mismatch",
    invalid_snapshot = "phase19_invalid_snapshot",
    feature_contract = "phase19_feature_contract_error",
    "phase19_club_contract_error"
  )
  stop(structure(
    c(list(message = as.character(message), call = NULL,
           reason_code = as.character(reason_code)), data),
    class = c(class_name, "phase19_club_contract_error", "error", "condition")
  ))
}

phase19_require_canonical_v2 <- function() {
  required <- c("phase18_canonical_encoding_v2", "phase18_hash_sequence_v2",
                "phase18_hash_row_v2", "phase18_hash_table_v2")
  missing <- required[!vapply(required, exists, logical(1), mode = "function")]
  if (length(missing)) {
    phase19_club_abort(
      "invalid_snapshot",
      paste0("Canonical-v2 helpers must be sourced first: ", paste(missing, collapse = ", "))
    )
  }
  invisible(TRUE)
}

phase19_scalar <- function(value, field, allow_empty = FALSE) {
  if (length(value) != 1L || is.null(value) || is.na(value[[1L]])) {
    phase19_club_abort("invalid_snapshot", paste0(field, " must contain one value"))
  }
  value <- enc2utf8(as.character(value[[1L]]))
  if (!allow_empty && !nzchar(value)) {
    phase19_club_abort("invalid_snapshot", paste0(field, " must not be empty"))
  }
  value
}

phase19_is_sha256 <- function(value) {
  length(value) == 1L && !is.na(value[[1L]]) &&
    grepl("^[0-9a-f]{64}$", tolower(as.character(value[[1L]])))
}

phase19_hash_named_scalars <- function(values, domain) {
  phase19_require_canonical_v2()
  if (!is.list(values) || is.null(names(values)) || any(!nzchar(names(values))) ||
      any(vapply(values, length, integer(1)) != 1L)) {
    phase19_club_abort("invalid_snapshot", paste0(domain, " requires named scalar values"))
  }
  phase18_hash_sequence_v2(
    values, domain = domain, names = names(values),
    types = vapply(values, phase18_v2_type_tag, character(1))
  )
}

phase19_path_within <- function(path, root) {
  identical(path, root) || startsWith(path, paste0(root, "/"))
}

phase19_assert_regular_file <- function(path, reason = "invalid_snapshot") {
  if (!file.exists(path) || dir.exists(path) || nzchar(Sys.readlink(path))) {
    phase19_club_abort(reason, paste0("Required authority file is missing or unsafe: ", path))
  }
  invisible(path)
}

phase19_reject_arbitrary_arguments <- function(arguments) {
  if (length(arguments)) {
    phase19_club_abort(
      "arbitrary_authority",
      paste0("Production club authority accepts no caller-selected evidence: ",
             paste(names(arguments), collapse = ", "))
    )
  }
  invisible(TRUE)
}

phase19_club_fixed_history_paths <- function() {
  list(
    current = file.path(.phase19_club_project_root, "data/club/history_current.json"),
    generations = file.path(.phase19_club_project_root, "data/club/history_generations")
  )
}

phase19_club_fixed_current_paths <- function() {
  list(
    accepted = file.path(.phase19_club_project_root, "data/competition/accepted"),
    registries = file.path(.phase19_club_project_root, "data/competition/registries"),
    club_registries = file.path(.phase19_club_project_root, "data/club/registries")
  )
}

phase19_club_same_path <- function(left, right) {
  normalizePath(as.character(left), winslash = "/", mustWork = FALSE) ==
    normalizePath(as.character(right), winslash = "/", mustWork = FALSE)
}

phase19_fixture_marker_schema <- function() c(
  "schema_version", "hash_encoding_version", "authority_mode",
  "fixture_authority", "fixture_id", "fixture_root_sha256", "marker_sha256"
)

phase19_fixture_root_sha256 <- function(root, fixture_id) {
  phase19_hash_named_scalars(
    list(root = normalizePath(root, winslash = "/", mustWork = TRUE),
         fixture_id = phase19_scalar(fixture_id, "fixture_id")),
    "phase19-club-fixture-root-v1"
  )
}

phase19_fixture_marker_sha256 <- function(marker) {
  fields <- setdiff(phase19_fixture_marker_schema(), "marker_sha256")
  if (!is.list(marker) || !identical(names(marker), phase19_fixture_marker_schema())) {
    phase19_club_abort("fixture_authority", "Fixture marker schema is not exact")
  }
  phase19_hash_named_scalars(marker[fields], "phase19-club-fixture-marker-v1")
}

phase19_validate_fixture_root <- function(root) {
  phase19_require_canonical_v2()
  if (length(root) != 1L || is.na(root) || !nzchar(as.character(root)) ||
      !dir.exists(root) || nzchar(Sys.readlink(root))) {
    phase19_club_abort("fixture_authority", "Fixture root must be one real non-symlinked directory")
  }
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  temporary <- normalizePath(tempdir(), winslash = "/", mustWork = TRUE)
  if (identical(root, temporary) || !phase19_path_within(root, temporary) ||
      phase19_path_within(root, .phase19_club_project_root)) {
    phase19_club_abort("fixture_authority", "Fixture authority must be isolated below the process temporary root")
  }
  marker_path <- file.path(root, "phase19_fixture_authority.json")
  phase19_assert_regular_file(marker_path, "fixture_authority")
  marker <- as.list(jsonlite::fromJSON(marker_path, simplifyVector = TRUE))
  if (!identical(names(marker), phase19_fixture_marker_schema())) {
    phase19_club_abort("fixture_authority", "Fixture marker schema is not exact")
  }
  marker[] <- lapply(marker, function(value) if (is.logical(value)) value else as.character(value))
  expected_root <- phase19_fixture_root_sha256(root, marker$fixture_id)
  if (!identical(as.character(marker$schema_version), "phase19-club-fixture-authority-v1") ||
      !identical(as.character(marker$hash_encoding_version), phase18_canonical_encoding_v2()) ||
      !identical(as.character(marker$authority_mode), "fixture") ||
      !isTRUE(marker$fixture_authority) ||
      !identical(as.character(marker$fixture_root_sha256), expected_root) ||
      !identical(as.character(marker$marker_sha256), phase19_fixture_marker_sha256(marker))) {
    phase19_club_abort("fixture_authority", "Fixture marker is stale, forged, or promotable")
  }
  list(root = root, marker = marker)
}

phase19_write_fixture_authority_marker <- function(root, fixture_id) {
  phase19_require_canonical_v2()
  if (!dir.exists(root)) dir.create(root, recursive = TRUE, showWarnings = FALSE)
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  temporary <- normalizePath(tempdir(), winslash = "/", mustWork = TRUE)
  if (identical(root, temporary) || !phase19_path_within(root, temporary) ||
      phase19_path_within(root, .phase19_club_project_root) || nzchar(Sys.readlink(root))) {
    phase19_club_abort("fixture_authority", "Fixture markers may be written only below the process temporary root")
  }
  marker <- list(
    schema_version = "phase19-club-fixture-authority-v1",
    hash_encoding_version = phase18_canonical_encoding_v2(),
    authority_mode = "fixture", fixture_authority = TRUE,
    fixture_id = phase19_scalar(fixture_id, "fixture_id"),
    fixture_root_sha256 = phase19_fixture_root_sha256(root, fixture_id),
    marker_sha256 = ""
  )
  marker$marker_sha256 <- phase19_fixture_marker_sha256(marker)
  path <- file.path(root, "phase19_fixture_authority.json")
  stage <- tempfile(".phase19-fixture-marker-", tmpdir = root)
  on.exit(if (file.exists(stage)) unlink(stage, force = TRUE), add = TRUE)
  jsonlite::write_json(marker, stage, auto_unbox = TRUE, pretty = TRUE, null = "null")
  if (!file.rename(stage, path)) {
    phase19_club_abort("fixture_authority", "Could not atomically install fixture marker")
  }
  phase19_validate_fixture_root(root)
  invisible(path)
}

phase19_training_result <- function(status, reason_code, authority_mode,
                                    fixture_authority, details = list()) {
  structure(c(list(
    status = status, reason_code = reason_code,
    authority_mode = authority_mode, fixture_authority = isTRUE(fixture_authority),
    model_domain = "club", entity_kind = "club"
  ), details), class = c("phase19_club_authority_result", "list"))
}

phase19_training_snapshot_hash_fields <- function(snapshot) c(
  "schema_version", "hash_encoding_version", "authority_mode", "fixture_authority",
  "model_domain", "entity_kind", "accepted_generation_id", "pointer_sha256",
  "generation_manifest_sha256", "corpus_id", "corpus_manifest_sha256",
  "matches_sha256", "phase19_matches_sha256", "club_registry_sha256",
  "source_manifest_sha256", "row_count", "cutoff_utc", "fixture_root_sha256"
)

phase19_training_snapshot_sha256 <- function(snapshot) {
  fields <- phase19_training_snapshot_hash_fields(snapshot)
  missing <- setdiff(fields, names(snapshot))
  if (length(missing)) {
    phase19_club_abort("invalid_snapshot", paste0("Training snapshot fields missing: ", paste(missing, collapse = ", ")))
  }
  phase19_hash_named_scalars(unname(snapshot[fields]) |> setNames(fields),
                             "phase19-club-training-snapshot-v1")
}

phase19_validate_training_matches <- function(matches, manifest) {
  phase18_validate_normalized_club_matches(matches)
  if (!nrow(matches)) phase19_club_abort("invalid_snapshot", "Club training snapshot cannot be empty")
  ids <- c(as.character(matches$home_club_id), as.character(matches$away_club_id))
  if (any(!grepl("^club_[a-z0-9][a-z0-9_]*$", ids))) {
    phase19_club_abort("domain_mismatch", "Training evidence contains a non-club identity")
  }
  forbidden <- intersect(names(matches), c(
    "team_id", "fifa_code", "home_team", "away_team", "national_team_id",
    "national_release_id", "national_selector_id"
  ))
  if (length(forbidden)) {
    phase19_club_abort("domain_mismatch", "Training evidence contains national-team fields")
  }
  counted <- vapply(matches$counts_for_model, phase18_history_logical, logical(1))
  if (any(!counted) || any(as.character(matches$status) != "completed") ||
      any(!as.character(matches$home_resolution_method) %in% c("source_id", "reviewed_alias")) ||
      any(!as.character(matches$away_resolution_method) %in% c("source_id", "reviewed_alias"))) {
    phase19_club_abort("invalid_snapshot", "Training snapshot contains ineligible or unresolved rows")
  }
  registry_hash <- as.character(manifest$club_registry_sha256[[1L]])
  if (!phase19_is_sha256(registry_hash) ||
      any(as.character(matches$identity_registry_sha256) != registry_hash)) {
    phase19_club_abort("invalid_snapshot", "Training rows are not bound to the accepted club registry")
  }
  cutoff <- phase18_history_parse_utc(manifest$cutoff_utc[[1L]], "cutoff_utc")[[1L]]
  completion <- phase18_history_parse_utc(matches$completion_not_before_utc,
                                          "completion_not_before_utc")
  evidence <- phase18_history_parse_utc(matches$evidence_available_at_utc,
                                        "evidence_available_at_utc")
  if (any(completion >= cutoff) || any(evidence >= cutoff) || any(evidence < completion)) {
    phase19_club_abort("invalid_snapshot", "Training snapshot violates its exclusive evidence cutoff")
  }
  invisible(TRUE)
}

phase19_build_training_snapshot <- function(current_path, generations_root,
                                            authority_mode, fixture_root_sha256 = "") {
  authority_mode <- phase19_scalar(authority_mode, "authority_mode")
  if (!authority_mode %in% c("production", "fixture")) {
    phase19_club_abort("invalid_snapshot", "Training snapshot authority mode is not recognised")
  }
  fixed <- phase19_club_fixed_history_paths()
  if (identical(authority_mode, "production")) {
    if (!phase19_club_same_path(current_path, fixed$current) ||
        !phase19_club_same_path(generations_root, fixed$generations) ||
        nzchar(as.character(fixture_root_sha256))) {
      phase19_club_abort(
        "arbitrary_authority",
        "Production training authority can only use the fixed Phase 18 history roots"
      )
    }
  } else {
    fixture_root <- dirname(normalizePath(current_path, winslash = "/", mustWork = FALSE))
    if (!phase19_club_same_path(generations_root, file.path(fixture_root, "history_generations"))) {
      phase19_club_abort("fixture_authority", "Fixture history paths must share one marked fixture root")
    }
    marker <- phase19_validate_fixture_root(fixture_root)
    if (!identical(as.character(fixture_root_sha256), as.character(marker$marker$fixture_root_sha256))) {
      phase19_club_abort("fixture_authority", "Fixture history is not bound to its authority marker")
    }
  }
  pointer <- tryCatch(
    phase18_read_club_history_current(current_path, generations_root),
    error = function(error) error
  )
  if (inherits(pointer, "error")) {
    return(phase19_training_result(
      "blocked", "invalid_club_history_authority", authority_mode,
      identical(authority_mode, "fixture"),
      list(upstream_reason = if (is.null(pointer$reason)) class(pointer)[[1L]] else pointer$reason)
    ))
  }
  if (!identical(as.character(pointer$acceptance_state), "accepted") ||
      !nzchar(as.character(pointer$accepted_generation_id))) {
    return(phase19_training_result(
      "blocked", "no_accepted_club_history", authority_mode,
      identical(authority_mode, "fixture")
    ))
  }
  generation_id <- as.character(pointer$accepted_generation_id)
  if (!phase18_history_safe_generation_id(generation_id)) {
    return(phase19_training_result(
      "blocked", "invalid_club_history_authority", authority_mode,
      identical(authority_mode, "fixture"), list(upstream_reason = "unsafe_generation_id")
    ))
  }
  generation_root <- file.path(generations_root, generation_id)
  generation <- tryCatch(
    phase18_history_validate_generation(generation_root),
    error = function(error) error
  )
  accepted <- tryCatch(
    phase18_validate_club_history_corpus(file.path(generation_root, "accepted")),
    error = function(error) error
  )
  if (inherits(generation, "error") || inherits(accepted, "error") ||
      !isTRUE(accepted$accepted_for_training)) {
    error <- if (inherits(generation, "error")) generation else accepted
    return(phase19_training_result(
      "blocked", "invalid_club_history_authority", authority_mode,
      identical(authority_mode, "fixture"),
      list(upstream_reason = if (is.null(error$reason)) class(error)[[1L]] else error$reason)
    ))
  }
  manifest <- accepted$tables$corpus_manifest
  matches <- accepted$tables$matches
  valid <- tryCatch({
    phase19_validate_training_matches(matches, manifest)
    TRUE
  }, error = function(error) error)
  if (inherits(valid, "error")) {
    if (inherits(valid, "phase19_domain_mismatch")) stop(valid)
    return(phase19_training_result(
      "blocked", "invalid_club_history_authority", authority_mode,
      identical(authority_mode, "fixture"),
      list(upstream_reason = if (is.null(valid$reason_code)) class(valid)[[1L]] else valid$reason_code)
    ))
  }
  matches <- phase18_history_canonical_table(matches, c("source_id", "source_match_id", "match_id"))
  phase19_matches_sha256 <- phase18_hash_table_v2(
    matches, key = c("source_id", "source_match_id", "match_id"),
    schema_tag = "phase19-club-training-matches-v1"
  )
  details <- list(
    schema_version = "phase19-club-training-snapshot-v1",
    hash_encoding_version = phase18_canonical_encoding_v2(),
    accepted_generation_id = generation_id,
    pointer_sha256 = as.character(pointer$pointer_sha256),
    generation_manifest_sha256 = as.character(pointer$generation_manifest_sha256),
    corpus_id = as.character(manifest$corpus_id[[1L]]),
    corpus_manifest_sha256 = as.character(manifest$manifest_sha256[[1L]]),
    matches_sha256 = as.character(manifest$matches_sha256[[1L]]),
    phase19_matches_sha256 = phase19_matches_sha256,
    club_registry_sha256 = as.character(manifest$club_registry_sha256[[1L]]),
    source_manifest_sha256 = as.character(manifest$source_manifest_sha256[[1L]]),
    row_count = as.integer(nrow(matches)), cutoff_utc = as.character(manifest$cutoff_utc[[1L]]),
    fixture_root_sha256 = as.character(fixture_root_sha256), matches = matches,
    snapshot_sha256 = ""
  )
  snapshot <- phase19_training_result(
    "ready", "", authority_mode, identical(authority_mode, "fixture"), details
  )
  snapshot$snapshot_sha256 <- phase19_training_snapshot_sha256(snapshot)
  phase19_validate_club_training_snapshot(snapshot, authority_mode)
  snapshot
}

phase19_load_club_training_snapshot <- function(fit_callback = NULL, ...) {
  phase19_reject_arbitrary_arguments(list(...))
  if (!is.null(fit_callback) && !is.function(fit_callback)) {
    phase19_club_abort("invalid_snapshot", "fit_callback must be NULL or a function")
  }
  fixed <- phase19_club_fixed_history_paths()
  snapshot <- phase19_build_training_snapshot(fixed$current, fixed$generations, "production")
  if (identical(snapshot$status, "ready") && !is.null(fit_callback)) fit_callback(snapshot)
  snapshot
}

phase19_load_fixture_club_training_snapshot <- function(fixture_root,
                                                        authority_mode = "fixture") {
  if (!identical(authority_mode, "fixture")) {
    phase19_club_abort("fixture_authority", "Fixture history requires authority_mode=fixture")
  }
  fixture <- phase19_validate_fixture_root(fixture_root)
  phase19_build_training_snapshot(
    file.path(fixture$root, "history_current.json"),
    file.path(fixture$root, "history_generations"),
    "fixture", as.character(fixture$marker$fixture_root_sha256)
  )
}

phase19_validate_club_training_snapshot <- function(snapshot,
                                                    expected_authority_mode = "production") {
  if (!inherits(snapshot, "phase19_club_authority_result") ||
      !identical(snapshot$status, "ready")) {
    phase19_club_abort("invalid_snapshot", "A ready club training snapshot is required")
  }
  if (!expected_authority_mode %in% c("production", "fixture") ||
      !identical(snapshot$authority_mode, expected_authority_mode)) {
    phase19_club_abort("fixture_authority", "Training snapshot authority mode differs from the caller")
  }
  if (!identical(snapshot$model_domain, "club") || !identical(snapshot$entity_kind, "club")) {
    phase19_club_abort("domain_mismatch", "Training snapshot is not club-domain authority")
  }
  if (identical(expected_authority_mode, "production")) {
    fixed <- phase19_club_fixed_history_paths()
    pointer <- tryCatch(
      phase18_read_club_history_current(fixed$current, fixed$generations),
      error = function(error) error
    )
    if (inherits(pointer, "error") ||
        !identical(as.character(pointer$acceptance_state), "accepted") ||
        !identical(as.character(pointer$accepted_generation_id),
                   as.character(snapshot$accepted_generation_id))) {
      phase19_club_abort(
        "invalid_snapshot",
        "Production training snapshot is not bound to the fixed accepted Phase 18 pointer"
      )
    }
    generation_root <- file.path(fixed$generations, as.character(pointer$accepted_generation_id))
    generation <- tryCatch(phase18_history_validate_generation(generation_root),
                           error = function(error) error)
    accepted <- tryCatch(
      phase18_validate_club_history_corpus(file.path(generation_root, "accepted")),
      error = function(error) error
    )
    if (inherits(generation, "error") || inherits(accepted, "error") ||
        !isTRUE(accepted$accepted_for_training)) {
      phase19_club_abort(
        "invalid_snapshot",
        "Production training snapshot is not bound to an accepted Phase 18 generation"
      )
    }
    manifest <- accepted$tables$corpus_manifest
    canonical <- phase18_history_canonical_table(
      accepted$tables$matches, c("source_id", "source_match_id", "match_id")
    )
    expected_match_hash <- phase18_hash_table_v2(
      canonical, key = c("source_id", "source_match_id", "match_id"),
      schema_tag = "phase19-club-training-matches-v1"
    )
    expected_corpus <- as.character(manifest$manifest_sha256[[1L]])
    expected_registry <- as.character(manifest$club_registry_sha256[[1L]])
    if (!identical(as.character(snapshot$pointer_sha256), as.character(pointer$pointer_sha256)) ||
        !identical(as.character(snapshot$generation_manifest_sha256),
                   as.character(pointer$generation_manifest_sha256)) ||
        !identical(as.character(snapshot$corpus_manifest_sha256), expected_corpus) ||
        !identical(as.character(snapshot$club_registry_sha256), expected_registry) ||
        !identical(as.character(snapshot$cutoff_utc), as.character(manifest$cutoff_utc[[1L]])) ||
        !identical(as.character(snapshot$phase19_matches_sha256), expected_match_hash) ||
        !identical(snapshot$matches, canonical)) {
      phase19_club_abort(
        "invalid_snapshot",
        "Production training snapshot content or Phase 18 source identity drifted"
      )
    }
  }
  if (!identical(isTRUE(snapshot$fixture_authority), identical(expected_authority_mode, "fixture")) ||
      (identical(expected_authority_mode, "fixture") && !phase19_is_sha256(snapshot$fixture_root_sha256)) ||
      (identical(expected_authority_mode, "production") && nzchar(snapshot$fixture_root_sha256))) {
    phase19_club_abort("fixture_authority", "Training fixture discriminator is invalid")
  }
  hash_fields <- c(
    "pointer_sha256", "generation_manifest_sha256", "corpus_manifest_sha256",
    "matches_sha256", "phase19_matches_sha256", "club_registry_sha256",
    "source_manifest_sha256", "snapshot_sha256"
  )
  if (any(!vapply(snapshot[hash_fields], phase19_is_sha256, logical(1)))) {
    phase19_club_abort("invalid_snapshot", "Training snapshot contains an invalid canonical hash")
  }
  manifest <- data.frame(
    club_registry_sha256 = snapshot$club_registry_sha256,
    cutoff_utc = snapshot$cutoff_utc, stringsAsFactors = FALSE
  )
  phase19_validate_training_matches(snapshot$matches, manifest)
  canonical <- phase18_history_canonical_table(
    snapshot$matches, c("source_id", "source_match_id", "match_id")
  )
  expected_matches <- phase18_hash_table_v2(
    canonical, key = c("source_id", "source_match_id", "match_id"),
    schema_tag = "phase19-club-training-matches-v1"
  )
  if (!identical(snapshot$matches, canonical) ||
      !identical(as.integer(snapshot$row_count), as.integer(nrow(canonical))) ||
      !identical(as.character(snapshot$phase19_matches_sha256), expected_matches) ||
      !identical(as.character(snapshot$snapshot_sha256), phase19_training_snapshot_sha256(snapshot))) {
    phase19_club_abort("invalid_snapshot", "Training snapshot content or identity drifted")
  }
  invisible(snapshot)
}

phase19_assert_production_club_authority <- function(snapshot) {
  if (!inherits(snapshot, "phase19_club_authority_result") ||
      !identical(snapshot$status, "ready") ||
      !identical(snapshot$authority_mode, "production") ||
      isTRUE(snapshot$fixture_authority)) {
    phase19_club_abort("fixture_authority", "Fixture or blocked evidence cannot become production authority")
  }
  phase19_validate_club_training_snapshot(snapshot, "production")
}

phase19_current_ucl_acceptance_reason <- function(accepted_status) {
  accepted_status <- phase19_scalar(accepted_status, "accepted_status")
  if (identical(accepted_status, "accepted")) "" else "no_accepted_current_ucl"
}

phase19_current_result <- function(status, reason_code, authority_mode,
                                   fixture_authority, details = list()) {
  structure(c(list(
    status = status, reason_code = reason_code,
    authority_mode = authority_mode, fixture_authority = isTRUE(fixture_authority),
    model_domain = "club", entity_kind = "club"
  ), details), class = c("phase19_current_ucl_authority_result", "list"))
}

phase19_current_snapshot_hash_fields <- function(snapshot) c(
  "schema_version", "hash_encoding_version", "authority_mode", "fixture_authority",
  "model_domain", "entity_kind", "accepted_status", "accepted_generation_id",
  "accepted_generation_sha256", "source_generation_id", "bundle_id", "bundle_sha256",
  "edition_id", "source_authority_type", "source_authority_sha256",
  "promotion_eligible", "identity_generation", "identity_pointer_sha256",
  "identity_registry_sha256", "club_count", "roster_sha256", "fixture_root_sha256"
)

phase19_current_snapshot_sha256 <- function(snapshot) {
  fields <- phase19_current_snapshot_hash_fields(snapshot)
  missing <- setdiff(fields, names(snapshot))
  if (length(missing)) {
    phase19_club_abort("invalid_snapshot", paste0("Current UCL snapshot fields missing: ", paste(missing, collapse = ", ")))
  }
  phase19_hash_named_scalars(unname(snapshot[fields]) |> setNames(fields),
                             "phase19-current-ucl-club-snapshot-v1")
}

phase19_read_identity_pointer <- function(registry_root) {
  pointer_path <- file.path(registry_root, "current.json")
  phase19_assert_regular_file(pointer_path, "invalid_snapshot")
  pointer <- as.list(jsonlite::fromJSON(pointer_path, simplifyVector = TRUE))
  required <- c("schema_version", "hash_encoding_version", "generation",
                "registry_sha256", "pointer_sha256")
  if (!identical(names(pointer), required) ||
      !identical(as.character(pointer$schema_version), "phase18-club-registry-pointer-v2") ||
      !identical(as.character(pointer$hash_encoding_version), phase18_canonical_encoding_v2()) ||
      !identical(as.character(pointer$pointer_sha256), phase18_club_registry_pointer_hash(pointer))) {
    phase19_club_abort("invalid_snapshot", "Current club identity pointer is invalid")
  }
  pointer
}

phase19_build_current_snapshot <- function(candidate, registry_root, authority_mode,
                                           source_ref, fixture_root_sha256 = "") {
  authority_mode <- phase19_scalar(authority_mode, "authority_mode")
  if (!authority_mode %in% c("production", "fixture")) {
    phase19_club_abort("invalid_snapshot", "Current UCL authority mode is not recognised")
  }
  fixed <- phase19_club_fixed_current_paths()
  if (identical(authority_mode, "production")) {
    if (!phase19_club_same_path(registry_root, fixed$club_registries) ||
        nzchar(as.character(fixture_root_sha256))) {
      phase19_club_abort(
        "arbitrary_authority",
        "Production current-UCL authority can only use the fixed Phase 18 club registry root"
      )
    }
  } else {
    fixture_root <- dirname(normalizePath(registry_root, winslash = "/", mustWork = FALSE))
    if (!phase19_club_same_path(registry_root, file.path(fixture_root, "club_registries"))) {
      phase19_club_abort("fixture_authority", "Fixture current-UCL paths must share one marked fixture root")
    }
    marker <- phase19_validate_fixture_root(fixture_root)
    if (!identical(as.character(fixture_root_sha256), as.character(marker$marker$fixture_root_sha256))) {
      phase19_club_abort("fixture_authority", "Fixture current-UCL source is not bound to its authority marker")
    }
  }
  valid <- tryCatch({
    phase18_validate_ucl_source_bundle(candidate)
    TRUE
  }, error = function(error) error)
  if (inherits(valid, "error")) {
    return(phase19_current_result(
      "blocked", "invalid_current_ucl_authority", authority_mode,
      identical(authority_mode, "fixture"), list(upstream_reason = class(valid)[[1L]])
    ))
  }
  bundle <- candidate$bundle
  authority <- candidate$authority
  clubs <- candidate$tables$clubs
  is_fixture <- identical(authority_mode, "fixture")
  if (is_fixture) {
    if (!identical(as.character(authority$authority_type[[1L]]), "fixture_contract") ||
        isTRUE(phase18_ucl_bool(authority$promotion_eligible[[1L]], "promotion_eligible")) ||
        isTRUE(phase18_ucl_bool(authority$provider_automation_enabled[[1L]], "provider_automation_enabled"))) {
      return(phase19_current_result("blocked", "invalid_current_ucl_authority",
                                    authority_mode, TRUE))
    }
  } else if (identical(as.character(authority$authority_type[[1L]]), "fixture_contract") ||
             !isTRUE(phase18_ucl_bool(bundle$promotion_eligible[[1L]], "promotion_eligible"))) {
    return(phase19_current_result("blocked", "invalid_current_ucl_authority",
                                  authority_mode, FALSE))
  }
  club_ids <- as.character(clubs$club_id)
  if (!nrow(clubs) || anyDuplicated(club_ids) ||
      any(!grepl("^club_[a-z0-9][a-z0-9_]*$", club_ids))) {
    return(phase19_current_result("blocked", "current_ucl_identity_incomplete",
                                  authority_mode, is_fixture))
  }
  identity <- tryCatch({
    pointer <- phase19_read_identity_pointer(registry_root)
    registries <- phase18_load_club_registries(registry_root)
    list(pointer = pointer, registries = registries)
  }, error = function(error) error)
  if (inherits(identity, "error")) {
    return(phase19_current_result(
      "blocked", "current_ucl_identity_incomplete", authority_mode, is_fixture,
      list(upstream_reason = class(identity)[[1L]])
    ))
  }
  at <- as.character(bundle$created_at_utc[[1L]])
  complete <- vapply(club_ids, function(club_id) {
    rows <- identity$registries$clubs[identity$registries$clubs$club_id == club_id, , drop = FALSE]
    rows <- tryCatch(phase18_club_at_instant(rows, phase18_club_parse_time(at, "created_at_utc")[[1L]]),
                     error = function(error) rows[FALSE, , drop = FALSE])
    nrow(rows) == 1L && identical(as.character(rows$entity_kind[[1L]]), "club") &&
      identical(as.character(rows$club_status[[1L]]), "active")
  }, logical(1))
  if (!all(complete)) {
    return(phase19_current_result("blocked", "current_ucl_identity_incomplete",
                                  authority_mode, is_fixture))
  }
  clubs <- clubs[order(club_ids, method = "radix"), , drop = FALSE]
  rownames(clubs) <- NULL
  roster_sha256 <- phase18_hash_table_v2(
    clubs, key = "club_id", schema_tag = "phase19-current-ucl-club-roster-v1"
  )
  details <- list(
    schema_version = "phase19-current-ucl-club-snapshot-v1",
    hash_encoding_version = phase18_canonical_encoding_v2(),
    accepted_status = if (is_fixture) "fixture_only" else "accepted",
    accepted_generation_id = as.character(source_ref$accepted_generation_id),
    accepted_generation_sha256 = as.character(source_ref$accepted_generation_sha256),
    source_generation_id = as.character(source_ref$source_generation_id),
    bundle_id = as.character(bundle$bundle_id[[1L]]),
    bundle_sha256 = as.character(bundle$bundle_sha256[[1L]]),
    edition_id = as.character(bundle$edition_id[[1L]]),
    source_authority_type = as.character(authority$authority_type[[1L]]),
    source_authority_sha256 = as.character(authority$authority_sha256[[1L]]),
    promotion_eligible = if (is_fixture) FALSE else TRUE,
    identity_generation = as.character(identity$pointer$generation),
    identity_pointer_sha256 = as.character(identity$pointer$pointer_sha256),
    identity_registry_sha256 = as.character(identity$pointer$registry_sha256),
    club_count = as.integer(nrow(clubs)), roster_sha256 = roster_sha256,
    fixture_root_sha256 = as.character(fixture_root_sha256), clubs = clubs,
    snapshot_sha256 = ""
  )
  snapshot <- phase19_current_result("ready", "", authority_mode, is_fixture, details)
  snapshot$snapshot_sha256 <- phase19_current_snapshot_sha256(snapshot)
  phase19_validate_current_ucl_club_snapshot(snapshot, authority_mode)
  snapshot
}

phase19_load_current_ucl_club_snapshot <- function(...) {
  phase19_reject_arbitrary_arguments(list(...))
  current <- tryCatch(
    phase18_read_ucl_refresh_current(
      file.path(.phase19_club_project_root, "data/competition/accepted"),
      file.path(.phase19_club_project_root, "data/competition/registries")
    ), error = function(error) error
  )
  if (inherits(current, "error")) {
    return(phase19_current_result(
      "blocked", "invalid_current_ucl_authority", "production", FALSE,
      list(upstream_reason = class(current)[[1L]])
    ))
  }
  status <- if (is.null(current)) "no_incumbent" else as.character(current$pointer$accepted_status)
  reason <- phase19_current_ucl_acceptance_reason(status)
  if (nzchar(reason) || is.null(current$accepted) || is.null(current$accepted$bundle)) {
    return(phase19_current_result("blocked", "no_accepted_current_ucl",
                                  "production", FALSE))
  }
  phase19_build_current_snapshot(
    current$accepted, file.path(.phase19_club_project_root, "data/club/registries"),
    "production", list(
      accepted_generation_id = as.character(current$pointer$accepted_generation_id),
      accepted_generation_sha256 = as.character(current$pointer$accepted_generation_sha256),
      source_generation_id = as.character(current$pointer$accepted_generation_id)
    )
  )
}

phase19_load_fixture_current_ucl_club_snapshot <- function(fixture_root,
                                                           authority_mode = "fixture") {
  if (!identical(authority_mode, "fixture")) {
    phase19_club_abort("fixture_authority", "Fixture current UCL requires authority_mode=fixture")
  }
  fixture <- phase19_validate_fixture_root(fixture_root)
  candidate <- tryCatch(
    phase18_read_ucl_candidate(file.path(fixture$root, "ucl_candidate")),
    error = function(error) error
  )
  if (inherits(candidate, "error")) {
    return(phase19_current_result(
      "blocked", "invalid_current_ucl_authority", "fixture", TRUE,
      list(upstream_reason = class(candidate)[[1L]])
    ))
  }
  bundle <- candidate$bundle
  phase19_build_current_snapshot(
    candidate, file.path(fixture$root, "club_registries"), "fixture",
    list(
      accepted_generation_id = "",
      accepted_generation_sha256 = "",
      source_generation_id = as.character(bundle$bundle_id[[1L]])
    ), as.character(fixture$marker$fixture_root_sha256)
  )
}

phase19_validate_current_ucl_club_snapshot <- function(snapshot,
                                                       expected_authority_mode = "production") {
  if (!inherits(snapshot, "phase19_current_ucl_authority_result") ||
      !identical(snapshot$status, "ready")) {
    phase19_club_abort("invalid_snapshot", "A ready current UCL club snapshot is required")
  }
  if (!expected_authority_mode %in% c("production", "fixture") ||
      !identical(snapshot$authority_mode, expected_authority_mode)) {
    phase19_club_abort("fixture_authority", "Current UCL authority mode differs from the caller")
  }
  is_fixture <- identical(expected_authority_mode, "fixture")
  if (!identical(snapshot$model_domain, "club") || !identical(snapshot$entity_kind, "club")) {
    phase19_club_abort("domain_mismatch", "Current UCL snapshot is not club-domain authority")
  }
  if (!is_fixture) {
    fixed <- phase19_club_fixed_current_paths()
    accepted <- tryCatch(
      phase18_read_ucl_refresh_current(fixed$accepted, fixed$registries),
      error = function(error) error
    )
    if (inherits(accepted, "error") || is.null(accepted) ||
        is.null(accepted$accepted) || is.null(accepted$accepted$bundle)) {
      phase19_club_abort(
        "invalid_snapshot",
        "Production current-UCL snapshot is not bound to an accepted fixed Phase 18 bundle"
      )
    }
    pointer <- accepted$pointer
    source_bundle <- accepted$accepted$bundle
    source_authority <- accepted$accepted$authority
    identity <- tryCatch({
      pointer <- phase19_read_identity_pointer(fixed$club_registries)
      registries <- phase18_load_club_registries(fixed$club_registries)
      list(pointer = pointer, registries = registries)
    }, error = function(error) error)
    if (inherits(identity, "error") ||
        identical(as.character(source_authority$authority_type[[1L]]), "fixture_contract") ||
        !isTRUE(phase18_ucl_bool(source_bundle$promotion_eligible[[1L]], "promotion_eligible"))) {
      phase19_club_abort(
        "invalid_snapshot",
        "Production current-UCL source authority is not accepted or promotable"
      )
    }
    if (!identical(as.character(snapshot$accepted_generation_id),
                   as.character(pointer$accepted_generation_id)) ||
        !identical(as.character(snapshot$accepted_generation_sha256),
                   as.character(pointer$accepted_generation_sha256)) ||
        !identical(as.character(snapshot$source_generation_id),
                   as.character(pointer$accepted_generation_id)) ||
        !identical(as.character(snapshot$bundle_id), as.character(source_bundle$bundle_id[[1L]])) ||
        !identical(as.character(snapshot$bundle_sha256), as.character(source_bundle$bundle_sha256[[1L]])) ||
        !identical(as.character(snapshot$source_authority_sha256),
                   as.character(source_authority$authority_sha256[[1L]])) ||
        !identical(as.character(snapshot$identity_generation), as.character(identity$pointer$generation)) ||
        !identical(as.character(snapshot$identity_pointer_sha256),
                   as.character(identity$pointer$pointer_sha256)) ||
        !identical(as.character(snapshot$identity_registry_sha256),
                   as.character(identity$pointer$registry_sha256))) {
      phase19_club_abort(
        "invalid_snapshot",
        "Production current-UCL snapshot content or Phase 18 parent identity drifted"
      )
    }
  }
  if (!identical(isTRUE(snapshot$fixture_authority), is_fixture) ||
      !identical(isTRUE(snapshot$promotion_eligible), !is_fixture) ||
      (is_fixture && !identical(snapshot$accepted_status, "fixture_only")) ||
      (!is_fixture && !identical(snapshot$accepted_status, "accepted"))) {
    phase19_club_abort("fixture_authority", "Current UCL fixture/promotion discriminator is invalid")
  }
  if ((is_fixture && !phase19_is_sha256(snapshot$fixture_root_sha256)) ||
      (!is_fixture && nzchar(snapshot$fixture_root_sha256))) {
    phase19_club_abort("fixture_authority", "Current UCL fixture root binding is invalid")
  }
  hashes <- c("bundle_sha256", "source_authority_sha256", "identity_pointer_sha256",
              "identity_registry_sha256", "roster_sha256", "snapshot_sha256")
  if (any(!vapply(snapshot[hashes], phase19_is_sha256, logical(1)))) {
    phase19_club_abort("invalid_snapshot", "Current UCL snapshot contains an invalid hash")
  }
  ids <- as.character(snapshot$clubs$club_id)
  canonical <- snapshot$clubs[order(ids, method = "radix"), , drop = FALSE]
  rownames(canonical) <- NULL
  expected_roster <- phase18_hash_table_v2(
    canonical, key = "club_id", schema_tag = "phase19-current-ucl-club-roster-v1"
  )
  if (!identical(snapshot$clubs, canonical) || anyDuplicated(ids) ||
      any(!grepl("^club_[a-z0-9][a-z0-9_]*$", ids)) ||
      !identical(as.integer(snapshot$club_count), as.integer(nrow(canonical))) ||
      !identical(as.character(snapshot$roster_sha256), expected_roster) ||
      !identical(as.character(snapshot$snapshot_sha256), phase19_current_snapshot_sha256(snapshot))) {
    phase19_club_abort("invalid_snapshot", "Current UCL roster content or identity drifted")
  }
  invisible(snapshot)
}

phase19_feature_contract_schema <- function() {
  c(
    "schema_version", "hash_encoding_version", "forecast_domain", "feature_id",
    "availability_status", "reason_code", "source_contract_id",
    "source_contract_sha256", "value_type", "value", "observed_at_utc",
    "cutoff_status", "required_by_model", "active_in_model",
    "imputation_policy", "row_sha256"
  )
}

phase19_feature_ids <- function() {
  c("current_xg", "injury", "lineup", "suspension", "player")
}

phase19_feature_row_sha256 <- function(contract) {
  phase19_require_canonical_v2()
  if (!is.data.frame(contract) ||
      !identical(names(contract), phase19_feature_contract_schema())) {
    phase19_club_abort("feature_contract", "Feature contract schema is not exact")
  }
  phase18_hash_row_v2(
    contract,
    exclude = "row_sha256",
    schema_tag = "phase19-club-feature-contract-row-v1"
  )
}

phase19_feature_contract_sha256 <- function(contract) {
  phase19_validate_feature_contract(contract)
  phase18_hash_table_v2(
    contract,
    key = "feature_id",
    schema_tag = "phase19-club-feature-contract-table-v1"
  )
}

phase19_source_contract_schema <- function() {
  c(
    "schema_version", "hash_encoding_version", "forecast_domain", "feature_id",
    "source_contract_id", "decision", "accepted_at_utc", "contract_sha256"
  )
}

phase19_validate_accepted_feature_source_contract <- function(contract) {
  phase19_require_canonical_v2()
  if (!is.data.frame(contract) || nrow(contract) != 1L ||
      !identical(names(contract), phase19_source_contract_schema())) {
    phase19_club_abort("feature_contract", "Accepted source contract schema is not exact")
  }
  if (anyNA(contract) ||
      !identical(as.character(contract$schema_version),
                 "phase19-club-feature-source-contract-v1") ||
      !identical(as.character(contract$hash_encoding_version),
                 phase18_canonical_encoding_v2()) ||
      !identical(as.character(contract$forecast_domain), "club") ||
      !as.character(contract$feature_id) %in% phase19_feature_ids() ||
      !nzchar(as.character(contract$source_contract_id)) ||
      !identical(as.character(contract$decision), "accepted") ||
      !grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$",
             as.character(contract$accepted_at_utc)) ||
      !phase19_is_sha256(contract$contract_sha256)) {
    phase19_club_abort("feature_contract", "Accepted source contract metadata is invalid")
  }
  expected <- phase18_hash_row_v2(
    contract,
    exclude = "contract_sha256",
    schema_tag = "phase19-club-feature-source-contract-v1"
  )
  if (!identical(as.character(contract$contract_sha256), expected)) {
    phase19_club_abort("feature_contract", "Accepted source contract hash drifted")
  }
  invisible(contract)
}

phase19_feature_contract_error <- function(message) {
  phase19_club_abort("feature_contract", message)
}

phase19_validate_feature_contract <- function(contract,
                                               accepted_source_contracts = list()) {
  phase19_require_canonical_v2()
  schema <- phase19_feature_contract_schema()
  ids <- phase19_feature_ids()
  if (!is.data.frame(contract) || !identical(names(contract), schema)) {
    phase19_feature_contract_error("Feature contract schema is not exact")
  }
  if (nrow(contract) != length(ids) ||
      !identical(as.character(contract$feature_id), ids) ||
      anyDuplicated(contract$feature_id)) {
    phase19_feature_contract_error("Feature inventory is omitted, duplicated, unknown, or reordered")
  }
  character_fields <- setdiff(schema, c("required_by_model", "active_in_model"))
  if (any(!vapply(contract[character_fields], is.character, logical(1))) ||
      !is.logical(contract$required_by_model) || !is.logical(contract$active_in_model) ||
      anyNA(contract)) {
    phase19_feature_contract_error("Feature contract field types or missingness are invalid")
  }
  if (any(contract$schema_version != "phase19-club-feature-v1") ||
      any(contract$hash_encoding_version != phase18_canonical_encoding_v2()) ||
      any(contract$forecast_domain != "club") ||
      any(contract$imputation_policy != "forbidden")) {
    phase19_feature_contract_error("Feature contract metadata or domain is invalid")
  }
  if (!is.list(accepted_source_contracts)) {
    phase19_feature_contract_error("Accepted source contracts must be supplied as a list")
  }
  validated_sources <- lapply(accepted_source_contracts, function(source_contract) {
    phase19_validate_accepted_feature_source_contract(source_contract)
    source_contract
  })

  for (index in seq_len(nrow(contract))) {
    row <- contract[index, , drop = FALSE]
    unavailable <- identical(row$availability_status, "unavailable") &&
      identical(row$reason_code, "no_accepted_source_contract") &&
      identical(row$source_contract_id, "") &&
      identical(row$source_contract_sha256, "") &&
      identical(row$value_type, "unavailable") && identical(row$value, "") &&
      identical(row$observed_at_utc, "") &&
      identical(row$cutoff_status, "not_applicable") &&
      identical(row$required_by_model, FALSE) &&
      identical(row$active_in_model, FALSE)
    if (unavailable) next

    active <- identical(row$availability_status, "available") &&
      identical(row$reason_code, "accepted_source_contract") &&
      nzchar(row$source_contract_id) && phase19_is_sha256(row$source_contract_sha256) &&
      !identical(row$value_type, "unavailable") && nzchar(row$value) &&
      grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$",
            row$observed_at_utc) && identical(row$cutoff_status, "before_cutoff") &&
      identical(row$required_by_model, TRUE) && identical(row$active_in_model, TRUE)
    if (!active) {
      phase19_feature_contract_error(
        paste0("Feature evidence is neither typed unavailable nor accepted active: ", row$feature_id)
      )
    }
    matching <- Filter(function(source_contract) {
      identical(as.character(source_contract$feature_id), row$feature_id) &&
        identical(as.character(source_contract$source_contract_id), row$source_contract_id) &&
        identical(as.character(source_contract$contract_sha256), row$source_contract_sha256)
    }, validated_sources)
    if (length(matching) != 1L) {
      phase19_feature_contract_error(
        paste0("Active feature lacks one separately accepted source contract: ", row$feature_id)
      )
    }
  }
  expected_rows <- phase19_feature_row_sha256(contract)
  if (!identical(as.character(contract$row_sha256), expected_rows) ||
      anyDuplicated(contract$row_sha256) ||
      any(!vapply(contract$row_sha256, phase19_is_sha256, logical(1)))) {
    phase19_feature_contract_error("Feature contract canonical row hash drifted or collided")
  }
  invisible(contract)
}

phase19_load_feature_contract <- function() {
  path <- file.path(
    .phase19_club_project_root, "data/club/model_protocol/feature_contract.csv"
  )
  phase19_assert_regular_file(path, "feature_contract")
  contract <- utils::read.csv(
    path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = character(),
    colClasses = c(
      rep("character", 12L), "logical", "logical", "character", "character"
    )
  )
  phase19_validate_feature_contract(contract)
  contract
}

phase19_validate_feature_formula <- function(formula, contract,
                                             accepted_source_contracts = list()) {
  phase19_validate_feature_contract(contract, accepted_source_contracts)
  variables <- if (inherits(formula, "formula")) {
    all.vars(formula)
  } else if (is.character(formula) && length(formula) == 1L) {
    all.vars(stats::as.formula(formula))
  } else {
    phase19_feature_contract_error("Candidate formula must be one formula or formula string")
  }
  referenced <- intersect(variables, as.character(contract$feature_id))
  if (length(referenced)) {
    rows <- match(referenced, contract$feature_id)
    unavailable <- referenced[
      contract$availability_status[rows] != "available" |
        !contract$active_in_model[rows]
    ]
    if (length(unavailable)) {
      phase19_feature_contract_error(paste0(
        "Candidate formula references unavailable features: ",
        paste(unavailable, collapse = ", ")
      ))
    }
  }
  invisible(TRUE)
}

phase19_project_feature_evidence <- function(fixtures, contract) {
  phase19_validate_feature_contract(contract)
  if (!is.data.frame(fixtures) ||
      !all(c("fixture_id", "forecast_domain") %in% names(fixtures)) ||
      !nrow(fixtures) || anyNA(fixtures[c("fixture_id", "forecast_domain")]) ||
      any(!nzchar(as.character(fixtures$fixture_id))) ||
      anyDuplicated(fixtures$fixture_id)) {
    phase19_feature_contract_error("Fixture projection requires unique non-empty fixture IDs")
  }
  if (any(as.character(fixtures$forecast_domain) != "club")) {
    phase19_club_abort("domain_mismatch", "Feature evidence projection requires club fixtures")
  }
  projected <- contract[rep(seq_len(nrow(contract)), times = nrow(fixtures)), , drop = FALSE]
  rownames(projected) <- NULL
  data.frame(
    fixture_id = rep(as.character(fixtures$fixture_id), each = nrow(contract)),
    projected,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}
