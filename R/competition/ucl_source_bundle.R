#' Canonical, tamper-evident UCL current-state source bundles.
#'
#' Candidate bundles are deliberately separate from accepted-state promotion.
#' A provider, manual review, or fixture contract can authorize construction,
#' but only a freshly recomputed authority record determines eligibility.

phase18_ucl_bundle_abort <- function(reason_code, message) {
  condition <- structure(
    list(message = as.character(message), call = NULL, reason_code = reason_code),
    class = c(reason_code, "phase18_ucl_bundle_error", "error", "condition")
  )
  stop(condition)
}

phase18_ucl_scalar <- function(value, field, allow_empty = FALSE) {
  if (is.null(value) || length(value) != 1L || is.na(value[[1L]])) {
    phase18_ucl_bundle_abort("blocked_schema", paste0(field, " must be one non-missing value"))
  }
  value <- as.character(value[[1L]])
  if (!allow_empty && !nzchar(value)) {
    phase18_ucl_bundle_abort("blocked_schema", paste0(field, " must not be empty"))
  }
  value
}

phase18_ucl_bool <- function(value, field) {
  if (is.logical(value) && length(value) == 1L && !is.na(value)) return(value)
  token <- tolower(phase18_ucl_scalar(value, field))
  if (!token %in% c("true", "false")) {
    phase18_ucl_bundle_abort("blocked_schema", paste0(field, " must be TRUE or FALSE"))
  }
  identical(token, "true")
}

phase18_ucl_hash <- function(value) {
  if (!is.raw(value)) {
    phase18_ucl_bundle_abort(
      "blocked_runtime",
      "Bundle byte hashes require raw input; structured integrity uses canonical v2"
    )
  }
  phase18_v2_hash(value)
}

phase18_ucl_require_hash <- function(value, field) {
  value <- tolower(phase18_ucl_scalar(value, field))
  if (!grepl("^[0-9a-f]{64}$", value)) {
    phase18_ucl_bundle_abort("blocked_schema", paste0(field, " must be a canonical SHA-256"))
  }
  value
}

phase18_ucl_canonical_hash <- function(data, key = NULL, exclude = character()) {
  if (!exists("phase18_hash_table_v2", mode = "function")) {
    phase18_ucl_bundle_abort("blocked_runtime", "Canonical v2 table hash helper is unavailable")
  }
  if (!is.data.frame(data) || !nrow(data) || !"schema_version" %in% names(data) ||
      length(unique(as.character(data$schema_version))) != 1L) {
    phase18_ucl_bundle_abort("blocked_schema", "Canonical bundle tables require one explicit schema")
  }
  schema <- as.character(data$schema_version[[1L]])
  if (!grepl("-v2$", schema) || !"hash_encoding_version" %in% names(data) ||
      any(as.character(data$hash_encoding_version) != phase18_canonical_encoding_v2())) {
    phase18_ucl_bundle_abort("blocked_migration_required", "Legacy or mixed bundle table encoding is forbidden")
  }
  if (is.null(key)) key <- names(data)[[1L]]
  phase18_hash_table_v2(
    data, key = key, exclude = intersect(exclude, names(data)),
    schema_tag = paste0(schema, ":table")
  )
}

phase18_ucl_row_hash <- function(data, exclude = "row_sha256") {
  if (!exists("phase18_hash_row_v2", mode = "function")) {
    phase18_ucl_bundle_abort("blocked_runtime", "Canonical v2 row hash helper is unavailable")
  }
  if (!is.data.frame(data) || !nrow(data) || !"schema_version" %in% names(data) ||
      length(unique(as.character(data$schema_version))) != 1L) {
    phase18_ucl_bundle_abort("blocked_schema", "Canonical bundle rows require one explicit schema")
  }
  schema <- as.character(data$schema_version[[1L]])
  if (!grepl("-v2$", schema) || !"hash_encoding_version" %in% names(data) ||
      any(as.character(data$hash_encoding_version) != phase18_canonical_encoding_v2())) {
    phase18_ucl_bundle_abort("blocked_migration_required", "Legacy or mixed bundle row encoding is forbidden")
  }
  phase18_hash_row_v2(
    data, exclude = intersect(exclude, names(data)),
    schema_tag = paste0(schema, ":row")
  )
}

phase18_ucl_hash_sequence <- function(values, domain, names, types = rep("character", length(values))) {
  phase18_hash_sequence_v2(
    as.list(values), domain = domain, names = names, types = types
  )
}

phase18_ucl_raw_aggregate_sha256 <- function(fetched) {
  resources <- phase18_ucl_required_resources()
  if (!is.list(fetched) || !identical(names(fetched), resources)) {
    phase18_ucl_bundle_abort(
      "blocked_incomplete_graph",
      "Raw aggregate requires the ordered fixed four-resource set"
    )
  }
  hashes <- vapply(resources, function(resource) {
    item <- fetched[[resource]]
    body <- item$body
    if (!is.raw(body) || !length(body)) {
      phase18_ucl_bundle_abort("blocked_empty_resource", paste0(resource, " raw bytes are empty"))
    }
    observed <- phase18_ucl_hash(body)
    declared <- phase18_ucl_require_hash(item$raw_sha256, paste0(resource, " raw_sha256"))
    if (!identical(observed, declared)) {
      phase18_ucl_bundle_abort("blocked_raw_hash", paste0(resource, " raw bytes disagree with their hash"))
    }
    observed
  }, character(1))
  values <- as.vector(rbind(resources, unname(hashes)))
  phase18_ucl_hash_sequence(
    values,
    domain = "phase18-ucl-ordered-raw-aggregate-v2",
    names = as.vector(rbind(
      paste0("resource_", seq_along(resources)),
      paste0("raw_sha256_", seq_along(resources))
    ))
  )
}

phase18_ucl_safe_relative_path <- function(path) {
  path <- gsub("\\\\", "/", phase18_ucl_scalar(path, "relative_path"))
  if (grepl("^/", path) || grepl("^[A-Za-z]:", path) || grepl("(^|/)\\.\\.?(/|$)", path) || grepl("//", path)) {
    phase18_ucl_bundle_abort("blocked_unsafe_path", paste0("Unsafe candidate path: ", path))
  }
  path
}

phase18_ucl_path_within <- function(path, root) {
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  root <- normalizePath(root, winslash = "/", mustWork = FALSE)
  identical(path, root) || startsWith(path, paste0(root, "/"))
}

phase18_ucl_is_symlink <- function(path) {
  target <- tryCatch(Sys.readlink(path), error = function(error) "")
  length(target) == 1L && !is.na(target) && nzchar(target)
}

phase18_ucl_assert_no_symlink <- function(path, root) {
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  lexical <- gsub("\\\\", "/", as.character(path))
  if (!grepl("^/", lexical)) lexical <- file.path(root, lexical)
  resolved <- normalizePath(lexical, winslash = "/", mustWork = FALSE)
  if (!phase18_ucl_path_within(resolved, root)) {
    phase18_ucl_bundle_abort("blocked_unsafe_path", "Candidate path escapes its trusted root")
  }
  relative <- if (identical(resolved, root)) "" else substring(resolved, nchar(root) + 2L)
  current <- root
  if (phase18_ucl_is_symlink(current)) phase18_ucl_bundle_abort("blocked_symlink", "Trusted root is symlinked")
  if (nzchar(relative)) {
    for (part in strsplit(relative, "/", fixed = TRUE)[[1L]]) {
      current <- file.path(current, part)
      if (file.exists(current) && phase18_ucl_is_symlink(current)) {
        phase18_ucl_bundle_abort("blocked_symlink", paste0("Candidate path contains a symlink: ", relative))
      }
    }
  }
  invisible(TRUE)
}

phase18_ucl_required_resources <- function() c("competition_metadata", "teams", "matches", "standings")
phase18_ucl_required_tables <- function() c("competition", "clubs", "matches", "standings", "lifecycle")
phase18_ucl_resource_table <- function() c(
  competition_metadata = "competition", teams = "clubs", matches = "matches", standings = "standings"
)
phase18_ucl_table_keys <- function() list(
  competition = "edition_id", clubs = "club_id", matches = "provider_match_id",
  standings = "club_id", lifecycle = "edition_id"
)

phase18_ucl_authority_schema <- function() c(
  "schema_version", "hash_encoding_version", "source_mode", "authority_type", "authority_id", "authority_sha256",
  "provider_decision_id", "provider_decision_sha256", "manual_review_id", "manual_review_sha256",
  "fixture_id", "fixture_sha256", "source_url", "license_id", "reviewer",
  "reviewed_at_utc", "aggregate_raw_sha256", "provider_automation_enabled",
  "promotion_eligible", "reason_code", "row_sha256"
)

phase18_ucl_authority_row <- function(
    source_mode, authority_type, authority_id, authority_sha256,
    provider_decision_id = "", provider_decision_sha256 = "",
    manual_review_id = "", manual_review_sha256 = "",
    fixture_id = "", fixture_sha256 = "", source_url = "", license_id = "",
    reviewer = "", reviewed_at_utc = "", aggregate_raw_sha256 = "",
    provider_automation_enabled = FALSE, promotion_eligible = FALSE,
    reason_code = "accepted") {
  row <- data.frame(
    schema_version = "phase18-ucl-source-authority-v2",
    hash_encoding_version = phase18_canonical_encoding_v2(), source_mode = source_mode,
    authority_type = authority_type, authority_id = authority_id,
    authority_sha256 = authority_sha256,
    provider_decision_id = provider_decision_id,
    provider_decision_sha256 = provider_decision_sha256,
    manual_review_id = manual_review_id, manual_review_sha256 = manual_review_sha256,
    fixture_id = fixture_id, fixture_sha256 = fixture_sha256,
    source_url = source_url, license_id = license_id, reviewer = reviewer,
    reviewed_at_utc = reviewed_at_utc, aggregate_raw_sha256 = aggregate_raw_sha256,
    provider_automation_enabled = isTRUE(provider_automation_enabled),
    promotion_eligible = isTRUE(promotion_eligible), reason_code = reason_code,
    row_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE
  )
  row$row_sha256 <- phase18_ucl_row_hash(row)
  row
}

phase18_ucl_manual_review_hash <- function(review) {
  phase18_ucl_canonical_hash(review, key = "manual_review_id", exclude = c("row_sha256", "manual_review_sha256"))
}

phase18_ucl_fixture_hash <- function(contract) {
  phase18_ucl_canonical_hash(contract, key = "fixture_id", exclude = c("row_sha256", "fixture_sha256"))
}

#' Validate and recompute one member of the closed source-authority union.
phase18_validate_source_authority <- function(
    source_mode = NULL,
    authority,
    candidate_edition_id,
    aggregate_raw_sha256) {
  if (!is.list(authority)) phase18_ucl_bundle_abort("blocked_authority", "Source authority must be a list")
  candidate_edition_id <- phase18_ucl_scalar(candidate_edition_id, "candidate_edition_id")
  aggregate_raw_sha256 <- phase18_ucl_require_hash(aggregate_raw_sha256, "aggregate_raw_sha256")
  authority_type <- phase18_ucl_scalar(authority$authority_type, "authority_type")
  inferred_mode <- switch(
    authority_type,
    provider_acceptance = "provider_live",
    manual_source_review = "manual_reviewed",
    fixture_contract = "fixture_contract",
    phase18_ucl_bundle_abort("blocked_authority", "Unknown source authority discriminator")
  )
  source_mode <- if (is.null(source_mode)) inferred_mode else phase18_ucl_scalar(source_mode, "source_mode")
  if (!identical(source_mode, inferred_mode)) {
    phase18_ucl_bundle_abort("blocked_authority", "Source mode and authority discriminator disagree")
  }
  members <- c("provider_acceptance", "manual_source_review", "fixture_contract")
  populated <- members[vapply(members, function(name) !is.null(authority[[name]]), logical(1))]
  if (!identical(populated, authority_type)) {
    phase18_ucl_bundle_abort("blocked_authority", "Authority must contain exactly one union member")
  }

  if (identical(authority_type, "provider_acceptance")) {
    evidence <- authority$provider_acceptance
    required <- c(
      "manifest", "machine_checks", "owner_review", "edition_expectations",
      "schema_fingerprint", "pointer", "current_generation"
    )
    if (!is.list(evidence) || length(setdiff(required, names(evidence)))) {
      phase18_ucl_bundle_abort("blocked_authority", "Provider authority evidence is incomplete")
    }
    tryCatch({
      phase18_validate_acceptance_pointer(evidence$pointer)
      phase18_validate_acceptance_manifest(
        evidence$manifest, evidence$machine_checks, evidence$owner_review,
        evidence$edition_expectations, evidence$schema_fingerprint
      )
      if (!identical(as.character(evidence$pointer$generation[[1L]]), as.character(evidence$current_generation)) ||
          !identical(as.character(evidence$pointer$decision_id[[1L]]), as.character(evidence$manifest$decision_id[[1L]])) ||
          !identical(tolower(as.character(evidence$pointer$manifest_sha256[[1L]])), tolower(as.character(evidence$manifest$row_sha256[[1L]])))) {
        phase18_ucl_bundle_abort("blocked_authority", "Provider authority is not the selected immutable generation")
      }
    }, error = function(error) {
      if (inherits(error, "phase18_ucl_bundle_error")) stop(error)
      phase18_ucl_bundle_abort("blocked_authority", conditionMessage(error))
    })
    manifest <- evidence$manifest
    expectation_edition <- unique(as.character(evidence$edition_expectations$edition_id))
    if (length(expectation_edition) != 1L ||
        !identical(candidate_edition_id, expectation_edition) ||
        !identical(candidate_edition_id, as.character(manifest$edition_id[[1L]]))) {
      phase18_ucl_bundle_abort("blocked_authority", "Provider authority edition differs from the candidate")
    }
    accepted <- identical(as.character(manifest$decision[[1L]]), "accepted") &&
      identical(as.character(manifest$execution_mode[[1L]]), "live_acceptance_probe") &&
      isTRUE(phase18_ucl_bool(manifest$automation_enabled[[1L]], "automation_enabled")) &&
      identical(as.character(manifest$live_provider_decision[[1L]]), "accepted")
    if (!accepted) phase18_ucl_bundle_abort("blocked_authority", "Provider decision is not freshly accepted")
    id <- phase18_ucl_scalar(manifest$decision_id, "provider decision_id")
    hash <- phase18_ucl_require_hash(manifest$row_sha256, "provider decision hash")
    record <- phase18_ucl_authority_row(
      source_mode, authority_type, id, hash,
      provider_decision_id = id, provider_decision_sha256 = hash,
      aggregate_raw_sha256 = aggregate_raw_sha256,
      provider_automation_enabled = TRUE, promotion_eligible = TRUE
    )
    return(list(record = record, evidence = evidence))
  }

  if (identical(authority_type, "manual_source_review")) {
    review <- authority$manual_source_review
    required <- c(
      "schema_version", "hash_encoding_version", "manual_review_id", "edition_id", "decision", "source_url",
      "license_id", "reviewer", "reviewed_at_utc", "aggregate_raw_sha256",
      "manual_review_sha256", "row_sha256"
    )
    if (!is.data.frame(review) || nrow(review) != 1L || length(setdiff(required, names(review)))) {
      phase18_ucl_bundle_abort("blocked_authority", "Manual source review is incomplete")
    }
    if (!identical(names(review), required) ||
        !identical(as.character(review$schema_version[[1L]]), "phase18-ucl-manual-source-review-v2") ||
        !identical(as.character(review$hash_encoding_version[[1L]]), phase18_canonical_encoding_v2())) {
      phase18_ucl_bundle_abort("blocked_migration_required", "Manual source review is not canonical v2")
    }
    expected <- phase18_ucl_manual_review_hash(review)
    if (!identical(expected, phase18_ucl_require_hash(review$manual_review_sha256, "manual review hash")) ||
        !identical(as.character(review$row_sha256[[1L]]), phase18_ucl_row_hash(review)[[1L]])) {
      phase18_ucl_bundle_abort("blocked_authority", "Manual source review hash mismatch")
    }
    if (!identical(as.character(review$decision[[1L]]), "accepted")) {
      phase18_ucl_bundle_abort("blocked_authority", "Manual source review is not accepted")
    }
    raw_hash <- phase18_ucl_require_hash(review$aggregate_raw_sha256, "manual aggregate raw hash")
    if (!identical(as.character(review$edition_id[[1L]]), candidate_edition_id) ||
        !identical(raw_hash, aggregate_raw_sha256)) {
      phase18_ucl_bundle_abort("blocked_authority", "Manual review edition or raw aggregate differs from the candidate")
    }
    id <- phase18_ucl_scalar(review$manual_review_id, "manual_review_id")
    record <- phase18_ucl_authority_row(
      source_mode, authority_type, id, expected,
      manual_review_id = id, manual_review_sha256 = expected,
      source_url = phase18_ucl_scalar(review$source_url, "manual source_url"),
      license_id = phase18_ucl_scalar(review$license_id, "manual license_id"),
      reviewer = phase18_ucl_scalar(review$reviewer, "manual reviewer"),
      reviewed_at_utc = phase18_ucl_scalar(review$reviewed_at_utc, "manual reviewed_at_utc"),
      aggregate_raw_sha256 = raw_hash, provider_automation_enabled = FALSE,
      promotion_eligible = TRUE
    )
    return(list(record = record, evidence = list(manual_source_review = review)))
  }

  contract <- authority$fixture_contract
  required <- c(
    "schema_version", "hash_encoding_version", "fixture_id", "edition_id",
    "fixture_purpose", "aggregate_raw_sha256", "fixture_sha256", "row_sha256"
  )
  if (!is.data.frame(contract) || nrow(contract) != 1L || length(setdiff(required, names(contract)))) {
    phase18_ucl_bundle_abort("blocked_authority", "Fixture contract is incomplete")
  }
  if (!identical(names(contract), required) ||
      !identical(as.character(contract$schema_version[[1L]]), "phase18-ucl-fixture-contract-v2") ||
      !identical(as.character(contract$hash_encoding_version[[1L]]), phase18_canonical_encoding_v2())) {
    phase18_ucl_bundle_abort("blocked_migration_required", "Fixture contract is not canonical v2")
  }
  expected <- phase18_ucl_fixture_hash(contract)
  if (!identical(expected, phase18_ucl_require_hash(contract$fixture_sha256, "fixture hash")) ||
      !identical(as.character(contract$row_sha256[[1L]]), phase18_ucl_row_hash(contract)[[1L]])) {
    phase18_ucl_bundle_abort("blocked_authority", "Fixture contract hash mismatch")
  }
  id <- phase18_ucl_scalar(contract$fixture_id, "fixture_id")
  fixture_raw <- phase18_ucl_require_hash(contract$aggregate_raw_sha256, "fixture aggregate raw hash")
  if (!identical(as.character(contract$edition_id[[1L]]), candidate_edition_id) ||
      !identical(fixture_raw, aggregate_raw_sha256)) {
    phase18_ucl_bundle_abort("blocked_authority", "Fixture edition or raw aggregate differs from the candidate")
  }
  record <- phase18_ucl_authority_row(
    source_mode, authority_type, id, expected,
    fixture_id = id, fixture_sha256 = expected,
    aggregate_raw_sha256 = aggregate_raw_sha256,
    provider_automation_enabled = FALSE, promotion_eligible = FALSE,
    reason_code = "fixture_permanently_non_promotable"
  )
  list(record = record, evidence = list(fixture_contract = contract))
}

phase18_ucl_table_schema_hash <- function(data) {
  # Provider JSON-path/type/cardinality drift is bound separately through the
  # adapter fingerprint.  The durable CSV contract binds exact ordered names;
  # R's CSV reader may legitimately infer a numeric-looking identifier.
  phase18_ucl_hash_sequence(
    vapply(data, phase18_v2_type_tag, character(1)),
    domain = "phase18-ucl-table-schema-v2",
    names = names(data)
  )
}

phase18_ucl_row_set_hash <- function(data) {
  hashes <- sort(tolower(as.character(data$row_sha256)), method = "radix")
  phase18_ucl_hash_sequence(
    hashes, domain = "phase18-ucl-row-set-v2",
    names = paste0("row_sha256_", seq_along(hashes))
  )
}

phase18_ucl_projected_row_hash <- function(data) {
  fields <- setdiff(names(data), c("row_sha256", "source_raw_sha256"))
  phase18_hash_row_v2(
    data,
    exclude = intersect(c("row_sha256", "source_raw_sha256"), names(data)),
    schema_tag = paste0("fd-projection:", paste(fields, collapse = ","))
  )
}

phase18_ucl_column_types_json <- function(data) {
  as.character(jsonlite::toJSON(
    as.list(vapply(data, phase18_v2_type_tag, character(1))),
    auto_unbox = TRUE, null = "null"
  ))
}

phase18_ucl_read_typed_csv <- function(path, types_json) {
  data <- utils::read.csv(
    path, stringsAsFactors = FALSE, check.names = FALSE,
    na.strings = NULL, colClasses = "character"
  )
  types <- unlist(jsonlite::fromJSON(types_json, simplifyVector = TRUE), use.names = TRUE)
  if (!identical(names(data), names(types))) {
    phase18_ucl_bundle_abort("blocked_schema", "Typed candidate table columns differ from the manifest")
  }
  for (name in names(types)) {
    value <- data[[name]]
    type <- as.character(types[[name]])
    if (identical(type, "integer")) {
      value[!nzchar(value)] <- NA_character_
      data[[name]] <- as.integer(value)
    } else if (identical(type, "double")) {
      value[!nzchar(value)] <- NA_character_
      data[[name]] <- as.double(value)
    } else if (identical(type, "logical")) {
      value[!nzchar(value)] <- NA_character_
      if (any(!is.na(value) & !value %in% c("TRUE", "FALSE"))) {
        phase18_ucl_bundle_abort("blocked_schema", paste0("Invalid logical value in ", name))
      }
      data[[name]] <- ifelse(is.na(value), NA, value == "TRUE")
    } else if (!identical(type, "character")) {
      phase18_ucl_bundle_abort("blocked_schema", paste0("Unsupported durable table type: ", type))
    }
  }
  data
}

phase18_ucl_table_source_as_of <- function(table, fallback) {
  candidates <- intersect(c("source_as_of_utc", "last_updated_utc", "retrieved_at_utc"), names(table))
  values <- unlist(lapply(candidates, function(field) as.character(table[[field]])), use.names = FALSE)
  values <- values[!is.na(values) & nzchar(values)]
  if (length(values)) max(values) else fallback
}

phase18_ucl_parser_commit <- function() {
  if (exists("phase13_parser_commit_sha", mode = "function")) return(phase13_parser_commit_sha("."))
  output <- system2("git", c("rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE)
  tolower(trimws(output[[1L]]))
}

phase18_ucl_validate_projected_graph <- function(projected, expectations) {
  required <- phase18_ucl_required_tables()
  if (!is.list(projected) || !setequal(intersect(names(projected), required), required)) {
    phase18_ucl_bundle_abort("blocked_incomplete_graph", "Projected resources require all five canonical tables")
  }
  if (any(!vapply(projected[required], is.data.frame, logical(1)))) {
    phase18_ucl_bundle_abort("blocked_schema", "Every projected resource must be a data frame")
  }
  if (any(vapply(projected[required], nrow, integer(1)) == 0L)) {
    phase18_ucl_bundle_abort("blocked_empty_resource", "Required projected resources cannot be empty")
  }
  edition_ids <- unique(unlist(lapply(projected[required], function(table) as.character(table$edition_id)), use.names = FALSE))
  edition_ids <- edition_ids[!is.na(edition_ids) & nzchar(edition_ids)]
  if (length(edition_ids) != 1L || !identical(edition_ids, as.character(expectations$edition_id[[1L]]))) {
    phase18_ucl_bundle_abort("blocked_foreign_key", "Projected edition identities disagree")
  }
  for (name in required) {
    table <- projected[[name]]
    if (!"hash_encoding_version" %in% names(table) ||
        any(as.character(table$hash_encoding_version) != phase18_canonical_encoding_v2()) ||
        any(!grepl("-v2$", as.character(table$schema_version)))) {
      phase18_ucl_bundle_abort("blocked_migration_required", paste0("Projected table is not canonical v2: ", name))
    }
    if (!"row_sha256" %in% names(table) || any(tolower(as.character(table$row_sha256)) != phase18_ucl_projected_row_hash(table))) {
      phase18_ucl_bundle_abort("blocked_row_hash", paste0("Projected table row hash mismatch: ", name))
    }
  }
  if (anyDuplicated(as.character(projected$clubs$club_id)) ||
      anyDuplicated(as.character(projected$matches$provider_match_id)) ||
      anyDuplicated(as.character(projected$standings$club_id))) {
    phase18_ucl_bundle_abort("blocked_duplicate_key", "Projected graph contains duplicate semantic keys")
  }
  club_ids <- as.character(projected$clubs$club_id)
  if (any(!as.character(projected$matches$home_club_id) %in% club_ids) ||
      any(!as.character(projected$matches$away_club_id) %in% club_ids) ||
      any(!as.character(projected$standings$club_id) %in% club_ids)) {
    phase18_ucl_bundle_abort("blocked_foreign_key", "Projected graph contains an unknown club foreign key")
  }
  lifecycle <- projected$lifecycle[1L, , drop = FALSE]
  expected_hash <- phase18_ucl_require_hash(expectations$expectation_sha256, "expectation hash")
  if (!identical(as.character(lifecycle$expectation_sha256[[1L]]), expected_hash) ||
      as.integer(lifecycle$observed_club_count[[1L]]) != nrow(projected$clubs) ||
      as.integer(lifecycle$observed_match_count[[1L]]) != nrow(projected$matches) ||
      as.integer(lifecycle$observed_standings_rows[[1L]]) != nrow(projected$standings) ||
      nrow(projected$clubs) != as.integer(expectations$expected_club_count[[1L]]) ||
      sum(as.character(projected$matches$stage) == "LEAGUE_STAGE") != as.integer(expectations$expected_league_phase_match_count[[1L]]) ||
      nrow(projected$standings) != as.integer(expectations$expected_standings_rows[[1L]])) {
    phase18_ucl_bundle_abort("blocked_expectation", "Projected graph does not satisfy reviewed expectations")
  }
  invisible(TRUE)
}

#' Build one deterministic UCL candidate bundle from exact bytes and tables.
phase18_build_ucl_source_bundle <- function(projected, fetched, authority, edition_expectations, bundle_id) {
  bundle_id <- phase18_ucl_scalar(bundle_id, "bundle_id")
  required_resources <- phase18_ucl_required_resources()
  if (!is.list(fetched) || !identical(names(fetched), required_resources)) {
    phase18_ucl_bundle_abort("blocked_incomplete_graph", "Fetched resources must be the ordered fixed four-resource set")
  }
  edition_id <- as.character(edition_expectations$edition_id[[1L]])
  aggregate_raw_sha <- phase18_ucl_raw_aggregate_sha256(fetched)
  authority_result <- phase18_validate_source_authority(
    NULL, authority, candidate_edition_id = edition_id,
    aggregate_raw_sha256 = aggregate_raw_sha
  )
  record <- authority_result$record
  phase18_ucl_validate_projected_graph(projected, edition_expectations)
  expectation_sha <- phase18_ucl_require_hash(edition_expectations$expectation_sha256, "expectation hash")
  parser_commit <- phase18_ucl_parser_commit()
  mapping <- phase18_ucl_resource_table()
  fingerprints <- projected$schema_fingerprint
  if (!is.data.frame(fingerprints) || !all(c("resource", "fingerprint_sha256") %in% names(fingerprints)) ||
      !setequal(as.character(fingerprints$resource), required_resources)) {
    phase18_ucl_bundle_abort("blocked_schema", "Projected schema fingerprints are incomplete")
  }
  fingerprint_result <- tryCatch(
    phase18_validate_schema_fingerprint(fingerprints),
    error = function(error) phase18_ucl_bundle_abort("blocked_schema", conditionMessage(error))
  )
  if (identical(as.character(record$authority_type[[1L]]), "provider_acceptance") &&
      !identical(
        fingerprint_result$schema_fingerprint_sha256,
        as.character(authority_result$evidence$manifest$schema_fingerprint_sha256[[1L]])
      )) {
    phase18_ucl_bundle_abort("blocked_authority", "Candidate fingerprint table differs from provider authority")
  }
  artifact_rows <- lapply(required_resources, function(resource) {
    item <- fetched[[resource]]
    body <- item$body
    if (!is.raw(body) || !length(body)) phase18_ucl_bundle_abort("blocked_empty_resource", paste0(resource, " raw bytes are empty"))
    raw_hash <- phase18_ucl_hash(body)
    if (!identical(raw_hash, tolower(phase18_ucl_scalar(item$raw_sha256, paste0(resource, " raw_sha256"))))) {
      phase18_ucl_bundle_abort("blocked_raw_hash", paste0(resource, " raw bytes disagree with their hash"))
    }
    table_name <- unname(mapping[[resource]])
    table <- projected[[table_name]]
    fingerprint <- fingerprints[fingerprints$resource == resource, , drop = FALSE]
    row <- data.frame(
      schema_version = "phase18-ucl-source-artifact-v2",
      hash_encoding_version = phase18_canonical_encoding_v2(),
      artifact_id = paste(bundle_id, resource, sep = "--"), bundle_id = bundle_id,
      edition_id = edition_id, resource_type = resource,
      provider_id = "football_data_org_v4",
      source_url = phase18_ucl_scalar(item$final_url, paste0(resource, " source_url")),
      retrieved_at_utc = phase18_ucl_scalar(item$retrieved_at_utc, paste0(resource, " retrieved_at_utc")),
      source_as_of_utc = phase18_ucl_table_source_as_of(table, as.character(item$retrieved_at_utc[[1L]])),
      expectation_sha256 = expectation_sha,
      schema_fingerprint_sha256 = phase18_ucl_require_hash(fingerprint$fingerprint_sha256, "schema fingerprint"),
      bytes = as.integer(length(body)), raw_sha256 = raw_hash,
      aggregate_raw_sha256 = aggregate_raw_sha,
      canonical_content_sha256 = phase18_ucl_canonical_hash(table, key = phase18_ucl_table_keys()[[table_name]]),
      parser_commit_sha = parser_commit, row_count = as.integer(nrow(table)),
      relative_raw_path = phase18_ucl_safe_relative_path(file.path("raw", paste0(resource, ".json"))),
      relative_table_path = phase18_ucl_safe_relative_path(file.path("tables", paste0(table_name, ".csv"))),
      authority_type = as.character(record$authority_type[[1L]]),
      authority_id = as.character(record$authority_id[[1L]]),
      authority_sha256 = as.character(record$authority_sha256[[1L]]),
      row_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE
    )
    row$row_sha256 <- phase18_ucl_row_hash(row)
    row
  })
  artifacts <- do.call(rbind, artifact_rows)
  row.names(artifacts) <- NULL

  table_rows <- lapply(phase18_ucl_required_tables(), function(table_name) {
    table <- projected[[table_name]]
    linked <- names(mapping)[mapping %in% table_name]
    if (identical(table_name, "lifecycle")) linked <- required_resources
    row <- data.frame(
      schema_version = "phase18-ucl-table-manifest-v2",
      hash_encoding_version = phase18_canonical_encoding_v2(), bundle_id = bundle_id,
      edition_id = edition_id, table_name = table_name,
      semantic_key = phase18_ucl_table_keys()[[table_name]],
      linked_resources_sha256 = phase18_ucl_hash_sequence(
        sort(linked), "phase18-ucl-linked-resources-v2",
        paste0("resource_", seq_along(linked))
      ),
      relative_path = phase18_ucl_safe_relative_path(file.path("tables", paste0(table_name, ".csv"))),
      row_count = as.integer(nrow(table)), column_count = as.integer(ncol(table)),
      schema_sha256 = phase18_ucl_table_schema_hash(table),
      column_types_json = phase18_ucl_column_types_json(table),
      canonical_content_sha256 = phase18_ucl_canonical_hash(table, key = phase18_ucl_table_keys()[[table_name]]),
      row_set_sha256 = phase18_ucl_row_set_hash(table),
      row_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE
    )
    row$row_sha256 <- phase18_ucl_row_hash(row)
    row
  })
  table_manifest <- do.call(rbind, table_rows)
  row.names(table_manifest) <- NULL
  artifact_manifest_sha <- phase18_ucl_canonical_hash(artifacts, key = "artifact_id")
  table_manifest_sha <- phase18_ucl_canonical_hash(table_manifest, key = "table_name")
  bundle_graph_sha <- phase18_ucl_hash_sequence(
    c(
      edition_id, aggregate_raw_sha, expectation_sha,
      record$authority_sha256[[1L]], artifact_manifest_sha, table_manifest_sha
    ),
    domain = "phase18-ucl-bundle-graph-v2",
    names = c(
      "edition_id", "aggregate_raw_sha256", "expectation_sha256",
      "authority_sha256", "artifact_manifest_sha256", "table_manifest_sha256"
    )
  )
  bundle <- data.frame(
    schema_version = "phase18-ucl-source-bundle-v2",
    hash_encoding_version = phase18_canonical_encoding_v2(), bundle_id = bundle_id,
    edition_id = edition_id, source_mode = as.character(record$source_mode[[1L]]),
    authority_type = as.character(record$authority_type[[1L]]),
    authority_id = as.character(record$authority_id[[1L]]),
    authority_sha256 = as.character(record$authority_sha256[[1L]]),
    provider_automation_enabled = isTRUE(record$provider_automation_enabled[[1L]]),
    promotion_eligible = isTRUE(record$promotion_eligible[[1L]]),
    expectation_sha256 = expectation_sha, aggregate_raw_sha256 = aggregate_raw_sha,
    parser_commit_sha = parser_commit,
    artifact_count = as.integer(nrow(artifacts)), table_count = as.integer(nrow(table_manifest)),
    artifact_manifest_sha256 = artifact_manifest_sha,
    table_manifest_sha256 = table_manifest_sha,
    bundle_sha256 = bundle_graph_sha, manifest_self_sha256 = "",
    created_at_utc = max(vapply(fetched, function(item) as.character(item$retrieved_at_utc[[1L]]), character(1))),
    row_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE
  )
  body <- bundle[, setdiff(names(bundle), c("manifest_self_sha256", "row_sha256")), drop = FALSE]
  bundle$manifest_self_sha256 <- phase18_ucl_hash_sequence(
    c(
      phase18_ucl_canonical_hash(body, key = "bundle_id"), artifact_manifest_sha,
      table_manifest_sha, phase18_ucl_canonical_hash(record, key = "authority_id")
    ),
    domain = "phase18-ucl-bundle-self-v2",
    names = c("bundle_body_sha256", "artifact_manifest_sha256", "table_manifest_sha256", "authority_table_sha256")
  )
  bundle$row_sha256 <- phase18_ucl_row_hash(bundle)
  candidate <- list(
    bundle = bundle, artifacts = artifacts, table_manifest = table_manifest,
    authority = record, authority_evidence = authority_result$evidence,
    tables = projected[phase18_ucl_required_tables()], raw_bytes = lapply(fetched, `[[`, "body")
  )
  names(candidate$raw_bytes) <- required_resources
  phase18_validate_ucl_source_bundle(candidate)
  candidate
}

phase18_ucl_authority_from_candidate <- function(candidate) {
  record <- candidate$authority
  if (!is.data.frame(record) || nrow(record) != 1L || !identical(names(record), phase18_ucl_authority_schema())) {
    phase18_ucl_bundle_abort("blocked_authority", "Candidate authority schema is invalid")
  }
  type <- as.character(record$authority_type[[1L]])
  evidence <- candidate$authority_evidence
  input <- list(authority_type = type)
  if (identical(type, "provider_acceptance")) input$provider_acceptance <- evidence
  if (identical(type, "manual_source_review")) input$manual_source_review <- evidence$manual_source_review
  if (identical(type, "fixture_contract")) input$fixture_contract <- evidence$fixture_contract
  rebuilt <- phase18_validate_source_authority(
    as.character(record$source_mode[[1L]]), input,
    candidate_edition_id = as.character(candidate$bundle$edition_id[[1L]]),
    aggregate_raw_sha256 = as.character(candidate$bundle$aggregate_raw_sha256[[1L]])
  )$record
  same <- identical(names(record), names(rebuilt)) && all(vapply(names(rebuilt), function(field) {
    identical(phase18_canonical_scalar(record[[field]][[1L]]), phase18_canonical_scalar(rebuilt[[field]][[1L]]))
  }, logical(1)))
  if (!same) phase18_ucl_bundle_abort("blocked_authority", "Stored authority differs from recomputed evidence")
  rebuilt
}

#' Recompute the full candidate graph and every source authority link.
phase18_validate_ucl_source_bundle <- function(bundle, artifacts = NULL, tables = NULL) {
  candidate <- if (is.list(bundle) && !is.data.frame(bundle) && !is.null(bundle$bundle)) bundle else {
    list(bundle = bundle, artifacts = artifacts, tables = tables)
  }
  required_parts <- c("bundle", "artifacts", "table_manifest", "authority", "authority_evidence", "tables", "raw_bytes")
  if (length(setdiff(required_parts, names(candidate)))) {
    phase18_ucl_bundle_abort("blocked_incomplete_graph", "Candidate bundle graph is incomplete")
  }
  authority <- phase18_ucl_authority_from_candidate(candidate)
  bundle_row <- candidate$bundle
  artifacts <- candidate$artifacts
  table_manifest <- candidate$table_manifest
  tables <- candidate$tables
  if (!is.data.frame(bundle_row) || nrow(bundle_row) != 1L ||
      !is.data.frame(artifacts) || !is.data.frame(table_manifest)) {
    phase18_ucl_bundle_abort("blocked_schema", "Candidate manifests must be data frames")
  }
  if (!setequal(as.character(artifacts$resource_type), phase18_ucl_required_resources()) ||
      nrow(artifacts) != length(phase18_ucl_required_resources()) || anyDuplicated(artifacts$resource_type) ||
      !setequal(as.character(table_manifest$table_name), phase18_ucl_required_tables()) ||
      nrow(table_manifest) != length(phase18_ucl_required_tables()) || anyDuplicated(table_manifest$table_name)) {
    phase18_ucl_bundle_abort("blocked_incomplete_graph", "Candidate resource inventory is incomplete")
  }
  if (!setequal(names(tables), phase18_ucl_required_tables()) ||
      !setequal(names(candidate$raw_bytes), phase18_ucl_required_resources())) {
    phase18_ucl_bundle_abort("blocked_incomplete_graph", "Candidate bytes or tables are incomplete")
  }
  edition_id <- as.character(bundle_row$edition_id[[1L]])
  aggregate_raw_sha <- phase18_ucl_raw_aggregate_sha256(
    setNames(lapply(phase18_ucl_required_resources(), function(resource) list(
      body = candidate$raw_bytes[[resource]],
      raw_sha256 = phase18_ucl_hash(candidate$raw_bytes[[resource]])
    )), phase18_ucl_required_resources())
  )
  if (!identical(
    aggregate_raw_sha,
    phase18_ucl_require_hash(bundle_row$aggregate_raw_sha256, "bundle aggregate raw hash")
  ) || !identical(
    aggregate_raw_sha,
    phase18_ucl_require_hash(authority$aggregate_raw_sha256, "authority aggregate raw hash")
  )) {
    phase18_ucl_bundle_abort("blocked_raw_hash", "Candidate raw aggregate links disagree")
  }
  if (any(as.character(artifacts$bundle_id) != as.character(bundle_row$bundle_id[[1L]])) ||
      any(as.character(table_manifest$bundle_id) != as.character(bundle_row$bundle_id[[1L]])) ||
      any(as.character(artifacts$edition_id) != edition_id) ||
      any(as.character(table_manifest$edition_id) != edition_id)) {
    phase18_ucl_bundle_abort("blocked_foreign_key", "Candidate manifest foreign keys disagree")
  }
  if (!identical(as.character(bundle_row$authority_sha256[[1L]]), as.character(authority$authority_sha256[[1L]])) ||
      !identical(as.character(bundle_row$authority_id[[1L]]), as.character(authority$authority_id[[1L]])) ||
      !identical(as.character(bundle_row$authority_type[[1L]]), as.character(authority$authority_type[[1L]])) ||
      !identical(phase18_ucl_bool(bundle_row$promotion_eligible[[1L]], "promotion_eligible"), authority$promotion_eligible[[1L]]) ||
      !identical(phase18_ucl_bool(bundle_row$provider_automation_enabled[[1L]], "provider_automation_enabled"), authority$provider_automation_enabled[[1L]])) {
    phase18_ucl_bundle_abort("blocked_authority", "Bundle authority links are stale or forged")
  }
  if (identical(as.character(authority$authority_type[[1L]]), "fixture_contract") &&
      (isTRUE(phase18_ucl_bool(bundle_row$promotion_eligible[[1L]], "promotion_eligible")) ||
       isTRUE(phase18_ucl_bool(bundle_row$provider_automation_enabled[[1L]], "provider_automation_enabled")))) {
    phase18_ucl_bundle_abort("blocked_authority", "Fixture candidates are permanently non-promotable")
  }
  for (resource in phase18_ucl_required_resources()) {
    row <- artifacts[artifacts$resource_type == resource, , drop = FALSE]
    if (nrow(row) != 1L || !identical(as.character(row$row_sha256[[1L]]), phase18_ucl_row_hash(row)[[1L]])) {
      phase18_ucl_bundle_abort("blocked_row_hash", paste0("Artifact hash mismatch: ", resource))
    }
    bytes <- candidate$raw_bytes[[resource]]
    if (!is.raw(bytes) || length(bytes) != as.integer(row$bytes[[1L]]) ||
        !identical(phase18_ucl_hash(bytes), tolower(as.character(row$raw_sha256[[1L]])))) {
      phase18_ucl_bundle_abort("blocked_raw_hash", paste0("Raw artifact mismatch: ", resource))
    }
    if (!identical(as.character(row$aggregate_raw_sha256[[1L]]), aggregate_raw_sha)) {
      phase18_ucl_bundle_abort("blocked_raw_hash", paste0("Artifact aggregate mismatch: ", resource))
    }
    phase18_ucl_safe_relative_path(row$relative_raw_path[[1L]])
    phase18_ucl_safe_relative_path(row$relative_table_path[[1L]])
  }
  keys <- phase18_ucl_table_keys()
  for (table_name in phase18_ucl_required_tables()) {
    manifest <- table_manifest[table_manifest$table_name == table_name, , drop = FALSE]
    table <- tables[[table_name]]
    if (!is.data.frame(table) || !nrow(table) || nrow(manifest) != 1L ||
        !identical(as.character(manifest$row_sha256[[1L]]), phase18_ucl_row_hash(manifest)[[1L]])) {
      phase18_ucl_bundle_abort("blocked_table_manifest", paste0("Table manifest invalid: ", table_name))
    }
    if (!"row_sha256" %in% names(table) || any(tolower(as.character(table$row_sha256)) != phase18_ucl_projected_row_hash(table))) {
      phase18_ucl_bundle_abort("blocked_canonical_hash", paste0("Canonical row mismatch: ", table_name))
    }
    if (as.integer(manifest$row_count[[1L]]) != nrow(table) ||
        as.integer(manifest$column_count[[1L]]) != ncol(table)) {
      phase18_ucl_bundle_abort("blocked_canonical_hash", paste0("Canonical table dimensions mismatch: ", table_name))
    }
    if (!identical(as.character(manifest$schema_sha256[[1L]]), phase18_ucl_table_schema_hash(table)) ||
        !identical(as.character(manifest$column_types_json[[1L]]), phase18_ucl_column_types_json(table))) {
      phase18_ucl_bundle_abort("blocked_canonical_hash", paste0("Canonical table schema mismatch: ", table_name))
    }
    if (!identical(as.character(manifest$canonical_content_sha256[[1L]]), phase18_ucl_canonical_hash(table, key = keys[[table_name]])) ||
        !identical(as.character(manifest$row_set_sha256[[1L]]), phase18_ucl_row_set_hash(table))) {
      phase18_ucl_bundle_abort("blocked_canonical_hash", paste0("Canonical table content mismatch: ", table_name))
    }
    phase18_ucl_safe_relative_path(manifest$relative_path[[1L]])
  }
  clubs <- as.character(tables$clubs$club_id)
  if (anyDuplicated(clubs) || anyDuplicated(as.character(tables$matches$provider_match_id)) ||
      anyDuplicated(as.character(tables$standings$club_id)) ||
      any(!as.character(tables$matches$home_club_id) %in% clubs) ||
      any(!as.character(tables$matches$away_club_id) %in% clubs) ||
      any(!as.character(tables$standings$club_id) %in% clubs)) {
    phase18_ucl_bundle_abort("blocked_foreign_key", "Candidate canonical graph has duplicate or unknown identities")
  }
  artifact_hash <- phase18_ucl_canonical_hash(artifacts, key = "artifact_id")
  table_hash <- phase18_ucl_canonical_hash(table_manifest, key = "table_name")
  expected_graph <- phase18_ucl_hash_sequence(
    c(
      edition_id, aggregate_raw_sha, bundle_row$expectation_sha256[[1L]],
      authority$authority_sha256[[1L]], artifact_hash, table_hash
    ),
    domain = "phase18-ucl-bundle-graph-v2",
    names = c(
      "edition_id", "aggregate_raw_sha256", "expectation_sha256",
      "authority_sha256", "artifact_manifest_sha256", "table_manifest_sha256"
    )
  )
  if (!identical(as.character(bundle_row$artifact_manifest_sha256[[1L]]), artifact_hash) ||
      !identical(as.character(bundle_row$table_manifest_sha256[[1L]]), table_hash) ||
      !identical(as.character(bundle_row$bundle_sha256[[1L]]), expected_graph) ||
      as.integer(bundle_row$artifact_count[[1L]]) != nrow(artifacts) ||
      as.integer(bundle_row$table_count[[1L]]) != nrow(table_manifest)) {
    phase18_ucl_bundle_abort("blocked_bundle_hash", "Bundle graph hash mismatch")
  }
  body <- bundle_row[, setdiff(names(bundle_row), c("manifest_self_sha256", "row_sha256")), drop = FALSE]
  expected_self <- phase18_ucl_hash_sequence(
    c(
      phase18_ucl_canonical_hash(body, key = "bundle_id"), artifact_hash, table_hash,
      phase18_ucl_canonical_hash(authority, key = "authority_id")
    ),
    domain = "phase18-ucl-bundle-self-v2",
    names = c("bundle_body_sha256", "artifact_manifest_sha256", "table_manifest_sha256", "authority_table_sha256")
  )
  if (!identical(as.character(bundle_row$manifest_self_sha256[[1L]]), expected_self) ||
      !identical(as.character(bundle_row$row_sha256[[1L]]), phase18_ucl_row_hash(bundle_row)[[1L]])) {
    phase18_ucl_bundle_abort("blocked_manifest_hash", "Bundle manifest self-hash mismatch")
  }
  if (!is.null(candidate$root)) {
    root <- normalizePath(candidate$root, winslash = "/", mustWork = TRUE)
    phase18_ucl_assert_no_symlink(root, root)
    for (path in c(artifacts$relative_raw_path, table_manifest$relative_path)) {
      phase18_ucl_assert_no_symlink(file.path(root, phase18_ucl_safe_relative_path(path)), root)
    }
  }
  invisible(candidate)
}

phase18_ucl_write_csv <- function(data, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(data, path, row.names = FALSE, na = "", quote = TRUE)
  invisible(path)
}

phase18_ucl_candidate_inventory <- function() c(
  "artifacts.csv", "authority.csv", "bundle.csv", "table_manifest.csv",
  file.path("raw", paste0(phase18_ucl_required_resources(), ".json")),
  file.path("tables", paste0(phase18_ucl_required_tables(), ".csv"))
)

phase18_ucl_write_authority_evidence <- function(candidate, root) {
  type <- as.character(candidate$authority$authority_type[[1L]])
  dir.create(file.path(root, "authority_evidence"), recursive = TRUE, showWarnings = FALSE)
  if (identical(type, "provider_acceptance")) {
    evidence <- candidate$authority_evidence
    phase18_ucl_write_csv(evidence$manifest, file.path(root, "authority_evidence", "acceptance_manifest.csv"))
    phase18_ucl_write_csv(evidence$machine_checks, file.path(root, "authority_evidence", "coverage_matrix.csv"))
    phase18_ucl_write_csv(evidence$owner_review, file.path(root, "authority_evidence", "provider_terms_review.csv"))
    phase18_ucl_write_csv(evidence$edition_expectations, file.path(root, "authority_evidence", "edition_expectations.csv"))
    phase18_ucl_write_csv(evidence$schema_fingerprint, file.path(root, "authority_evidence", "schema_fingerprint.csv"))
    phase18_ucl_write_csv(evidence$pointer, file.path(root, "authority_evidence", "acceptance_pointer.csv"))
  } else if (identical(type, "manual_source_review")) {
    phase18_ucl_write_csv(candidate$authority_evidence$manual_source_review, file.path(root, "authority_evidence", "manual_source_review.csv"))
  } else {
    phase18_ucl_write_csv(candidate$authority_evidence$fixture_contract, file.path(root, "authority_evidence", "fixture_contract.csv"))
  }
  invisible(TRUE)
}

phase18_ucl_read_csv <- function(path) {
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = NULL)
}

#' Read one candidate tree without granting it authority.
phase18_read_ucl_candidate <- function(candidate_root) {
  candidate_root <- normalizePath(candidate_root, winslash = "/", mustWork = TRUE)
  if (phase18_ucl_is_symlink(candidate_root)) phase18_ucl_bundle_abort("blocked_symlink", "Candidate root is symlinked")
  phase18_ucl_assert_no_symlink(candidate_root, candidate_root)
  top <- sort(list.files(candidate_root, all.files = FALSE, full.names = FALSE, no.. = TRUE))
  expected_top <- sort(c("artifacts.csv", "authority.csv", "authority_evidence", "bundle.csv", "raw", "table_manifest.csv", "tables"))
  if (!identical(top, expected_top)) phase18_ucl_bundle_abort("blocked_inventory", "Candidate top-level inventory is not exact")
  expected_raw <- paste0(phase18_ucl_required_resources(), ".json")
  expected_tables <- paste0(phase18_ucl_required_tables(), ".csv")
  if (!setequal(list.files(file.path(candidate_root, "raw")), expected_raw) ||
      !setequal(list.files(file.path(candidate_root, "tables")), expected_tables)) {
    phase18_ucl_bundle_abort("blocked_inventory", "Candidate resource inventory is not exact")
  }
  authority <- phase18_ucl_read_csv(file.path(candidate_root, "authority.csv"))
  type <- as.character(authority$authority_type[[1L]])
  evidence_root <- file.path(candidate_root, "authority_evidence")
  evidence <- if (identical(type, "provider_acceptance")) {
    provider <- list(
      manifest = phase18_ucl_read_csv(file.path(evidence_root, "acceptance_manifest.csv")),
      machine_checks = phase18_ucl_read_csv(file.path(evidence_root, "coverage_matrix.csv")),
      owner_review = phase18_ucl_read_csv(file.path(evidence_root, "provider_terms_review.csv")),
      edition_expectations = phase18_ucl_read_csv(file.path(evidence_root, "edition_expectations.csv")),
      schema_fingerprint = phase18_ucl_read_csv(file.path(evidence_root, "schema_fingerprint.csv")),
      pointer = phase18_ucl_read_csv(file.path(evidence_root, "acceptance_pointer.csv"))
    )
    provider$current_generation <- as.character(provider$pointer$generation[[1L]])
    provider$generation_root <- evidence_root
    provider
  } else if (identical(type, "manual_source_review")) {
    list(manual_source_review = phase18_ucl_read_csv(file.path(evidence_root, "manual_source_review.csv")))
  } else if (identical(type, "fixture_contract")) {
    list(fixture_contract = phase18_ucl_read_csv(file.path(evidence_root, "fixture_contract.csv")))
  } else phase18_ucl_bundle_abort("blocked_authority", "Candidate authority discriminator is unknown")
  raw_bytes <- setNames(lapply(phase18_ucl_required_resources(), function(resource) {
    path <- file.path(candidate_root, "raw", paste0(resource, ".json"))
    phase18_ucl_assert_no_symlink(path, candidate_root)
    readBin(path, what = "raw", n = file.info(path)$size)
  }), phase18_ucl_required_resources())
  table_manifest <- phase18_ucl_read_csv(file.path(candidate_root, "table_manifest.csv"))
  tables <- setNames(lapply(phase18_ucl_required_tables(), function(table) {
    path <- file.path(candidate_root, "tables", paste0(table, ".csv"))
    phase18_ucl_assert_no_symlink(path, candidate_root)
    manifest <- table_manifest[as.character(table_manifest$table_name) == table, , drop = FALSE]
    if (nrow(manifest) != 1L || !"column_types_json" %in% names(manifest)) {
      phase18_ucl_bundle_abort("blocked_table_manifest", paste0("Missing typed table manifest: ", table))
    }
    phase18_ucl_read_typed_csv(path, as.character(manifest$column_types_json[[1L]]))
  }), phase18_ucl_required_tables())
  list(
    root = candidate_root,
    bundle = phase18_ucl_read_csv(file.path(candidate_root, "bundle.csv")),
    artifacts = phase18_ucl_read_csv(file.path(candidate_root, "artifacts.csv")),
    table_manifest = table_manifest,
    authority = authority, authority_evidence = evidence, tables = tables,
    raw_bytes = raw_bytes
  )
}

#' Atomically write and read-back validate one candidate tree.
phase18_write_ucl_candidate <- function(candidate_root, bundle, artifacts = NULL, tables = NULL) {
  candidate <- if (is.list(bundle) && !is.data.frame(bundle) && !is.null(bundle$bundle)) bundle else {
    list(bundle = bundle, artifacts = artifacts, tables = tables)
  }
  phase18_validate_ucl_source_bundle(candidate)
  candidate_root <- gsub("\\\\", "/", phase18_ucl_scalar(candidate_root, "candidate_root"))
  supplied_parent <- dirname(candidate_root)
  dir.create(supplied_parent, recursive = TRUE, showWarnings = FALSE)
  parent <- normalizePath(supplied_parent, winslash = "/", mustWork = TRUE)
  leaf <- basename(candidate_root)
  if (leaf %in% c("", ".", "..") || grepl("/", leaf, fixed = TRUE)) {
    phase18_ucl_bundle_abort("blocked_unsafe_path", "Candidate root must be a direct trusted child")
  }
  target <- file.path(parent, leaf)
  phase18_ucl_assert_no_symlink(parent, parent)
  if (file.exists(target) || dir.exists(target)) {
    existing <- phase18_read_ucl_candidate(target)
    phase18_validate_ucl_source_bundle(existing)
    same_identity <- identical(as.character(existing$bundle$bundle_id[[1L]]), as.character(candidate$bundle$bundle_id[[1L]])) &&
      identical(as.character(existing$bundle$edition_id[[1L]]), as.character(candidate$bundle$edition_id[[1L]]))
    if (same_identity && identical(as.character(existing$bundle$manifest_self_sha256[[1L]]), as.character(candidate$bundle$manifest_self_sha256[[1L]]))) {
      return(invisible(existing))
    }
    if (same_identity) phase18_ucl_bundle_abort("blocked_provenance_collision", "Logical bundle identity already has different content")
    phase18_ucl_bundle_abort("blocked_candidate_exists", "Candidate root already contains another bundle")
  }
  stage <- tempfile(paste0(".", basename(target), "-stage-"), tmpdir = parent)
  if (!dir.create(stage, recursive = FALSE, showWarnings = FALSE)) phase18_ucl_bundle_abort("blocked_writer", "Could not create candidate stage")
  on.exit(if (dir.exists(stage)) unlink(stage, recursive = TRUE, force = TRUE), add = TRUE)
  dir.create(file.path(stage, "raw"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(stage, "tables"), recursive = TRUE, showWarnings = FALSE)
  phase18_ucl_write_csv(candidate$bundle, file.path(stage, "bundle.csv"))
  phase18_ucl_write_csv(candidate$artifacts, file.path(stage, "artifacts.csv"))
  phase18_ucl_write_csv(candidate$table_manifest, file.path(stage, "table_manifest.csv"))
  phase18_ucl_write_csv(candidate$authority, file.path(stage, "authority.csv"))
  for (resource in phase18_ucl_required_resources()) {
    writeBin(candidate$raw_bytes[[resource]], file.path(stage, "raw", paste0(resource, ".json")))
  }
  for (table in phase18_ucl_required_tables()) {
    phase18_ucl_write_csv(candidate$tables[[table]], file.path(stage, "tables", paste0(table, ".csv")))
  }
  phase18_ucl_write_authority_evidence(candidate, stage)
  staged <- phase18_read_ucl_candidate(stage)
  phase18_validate_ucl_source_bundle(staged)
  if (!file.rename(stage, target)) phase18_ucl_bundle_abort("blocked_writer", "Could not atomically install candidate")
  installed <- phase18_read_ucl_candidate(target)
  phase18_validate_ucl_source_bundle(installed)
  invisible(installed)
}
