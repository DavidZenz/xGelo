# Phase 16 EURO qualifying activation and lifecycle contract.
# The acquisition script supplies registered source metadata; this module only
# validates the bundle and builds typed state envelopes.

phase16_euro_required_resource_types <- function() {
  c("fixtures", "groups", "standings", "results", "status")
}

uefa_euro_edition_id <- function() "uefa_euro_2028_qualifying"

uefa_euro_ruleset_version <- function() "uefa-euro-2028-qualifying-v1"

uefa_euro_source_bundle_id <- function() "uefa_euro_2028_qualifying-official-v1"

uefa_euro_official_draw_date <- function() "2026-12-06"

uefa_euro_activation_status_values <- function() {
  c("pre_draw", "active", "unavailable", "revision_blocked")
}

uefa_euro_2026_28_rules <- function(config = NULL) {
  list(
    edition_id = uefa_euro_edition_id(),
    ruleset_version = uefa_euro_ruleset_version(),
    source_bundle_id = uefa_euro_source_bundle_id(),
    official_draw_date = uefa_euro_official_draw_date(),
    required_resource_types = phase16_euro_required_resource_types(),
    lifecycle_states = c("pre_draw", "scheduled"),
    forecast_statuses = c("pre_draw", "available", "unavailable"),
    source_confidence_active = "official",
    registered_ruleset_versions = phase16_euro_registered_ruleset_versions(config),
    message_heading = "EURO qualifying is awaiting the official draw",
    message_body = paste(
      "Official groups and the schedule are not available yet.",
      "The draw is expected on 6 December 2026.",
      "Forecasts will appear after a complete official draw-and-schedule bundle is accepted."
    ),
    registered_source_bundle_ids = phase16_euro_registered_bundle_ids(config)
  )
}

phase16_euro_scalar <- function(value, default = "") {
  if (is.null(value) || length(value) == 0L || is.na(value[[1L]])) return(default)
  as.character(value[[1L]])
}

phase16_euro_or <- function(value, fallback) {
  if (is.null(value) || length(value) == 0L) fallback else value
}

phase16_euro_config_value <- function(config, names, default = NULL) {
  if (is.null(config) || !is.list(config)) return(default)
  for (name in names) {
    if (!is.null(config[[name]])) return(config[[name]])
  }
  default
}

phase16_euro_registered_bundle_ids <- function(config = NULL, manifest = NULL) {
  configured <- phase16_euro_config_value(
    config,
    c("registered_source_bundle_ids", "source_bundle_ids", "accepted_source_bundle_ids"),
    character()
  )
  manifest_id <- phase16_euro_metadata_value(
    manifest,
    c("source_bundle_id", "bundle_id", "accepted_source_bundle_id")
  )
  unique(c(
    uefa_euro_source_bundle_id(),
    as.character(configured),
    if (nzchar(manifest_id)) manifest_id else character()
  ))
}

phase16_euro_registered_ruleset_versions <- function(config = NULL) {
  configured <- phase16_euro_config_value(
    config,
    c("registered_ruleset_versions", "ruleset_versions", "accepted_ruleset_versions"),
    character()
  )
  unique(c(uefa_euro_ruleset_version(), as.character(configured)))
}

phase16_euro_metadata_value <- function(metadata, fields, default = "") {
  if (is.null(metadata)) return(default)
  if (is.data.frame(metadata)) {
    for (name in fields) {
      if (name %in% base::names(metadata) && nrow(metadata)) return(phase16_euro_scalar(metadata[[name]], default))
    }
    return(default)
  }
  if (is.list(metadata)) {
    for (name in fields) {
      if (!is.null(metadata[[name]])) return(phase16_euro_scalar(metadata[[name]], default))
    }
  }
  default
}

phase16_euro_blank <- function(value) {
  is.null(value) || length(value) == 0L || is.na(value[[1L]]) || !nzchar(trimws(as.character(value[[1L]])))
}

phase16_euro_hash_is_valid <- function(value) {
  values <- as.character(value)
  length(values) == 1L && !is.na(values) && grepl("^[0-9a-fA-F]{64}$", values)
}

phase16_euro_data_frame <- function(value) {
  if (is.data.frame(value)) return(value)
  if (is.null(value)) return(NULL)
  if (is.list(value) && length(value) == 0L) return(data.frame(stringsAsFactors = FALSE))
  NULL
}

phase16_euro_resource <- function(candidate, resource_type) {
  sources <- list(
    candidate$resources,
    candidate$accepted_tables,
    candidate$source_bundle$resources,
    candidate$raw_snapshot$resources
  )
  for (source in sources) {
    if (is.list(source) && !is.null(source[[resource_type]])) {
      value <- phase16_euro_data_frame(source[[resource_type]])
      if (!is.null(value)) return(value)
    }
  }
  value <- phase16_euro_data_frame(candidate[[resource_type]])
  if (!is.null(value)) return(value)
  NULL
}

phase16_euro_resource_list <- function(candidate) {
  resources <- setNames(
    lapply(phase16_euro_required_resource_types(), function(type) phase16_euro_resource(candidate, type)),
    phase16_euro_required_resource_types()
  )
  resources
}

phase16_euro_empty_table <- function(columns, types = NULL) {
  if (is.null(types)) types <- rep("character", length(columns))
  values <- lapply(types, function(type) {
    switch(
      type,
      character = character(),
      integer = integer(),
      numeric = numeric(),
      logical = logical(),
      stop("Unsupported EURO empty table type: ", type, call. = FALSE)
    )
  })
  as.data.frame(setNames(values, columns), stringsAsFactors = FALSE, check.names = FALSE)
}

phase16_euro_empty_like <- function(value, fallback) {
  if (is.data.frame(value)) return(value[FALSE, , drop = FALSE])
  fallback
}

phase16_euro_empty_collections <- function(resources = list()) {
  defaults <- list(
    teams = phase16_euro_empty_table(c(
      "team_id", "display_name", "association_id", "group_id", "source_bundle_id"
    )),
    groups = phase16_euro_empty_table(c(
      "group_id", "edition_id", "source_bundle_id", "ruleset_version"
    )),
    fixtures = phase16_euro_empty_table(c(
      "fixture_id", "edition_id", "group_id", "home_team_id", "away_team_id",
      "kickoff_confirmed", "confirmed_kickoff_at_utc", "source_bundle_id",
      "forecast_eligible"
    ), c("character", "character", "character", "character", "character", "logical", "character", "character", "logical")),
    standings = phase16_euro_empty_table(c(
      "edition_id", "group_id", "team_id", "rank", "source_bundle_id"
    )),
    results = phase16_euro_empty_table(c(
      "edition_id", "fixture_id", "home_team_id", "away_team_id", "home_goals",
      "away_goals", "source_bundle_id"
    )),
    qualification_ledger = phase16_euro_empty_table(c(
      "edition_id", "team_id", "stage", "qualification_status", "probability"
    )),
    host_slots = phase16_euro_empty_table(c(
      "host_slot_id", "slot_number", "association_id", "team_id", "slot_status",
      "consumes_capacity", "source_bundle_id", "ruleset_version"
    )),
    topology = phase16_euro_empty_table(c(
      "reserved_slots_used", "entrant_count", "structure", "places", "status"
    )),
    probabilities = phase16_euro_empty_table(c(
      "edition_id", "team_id", "probability", "status", "reason", "source_bundle_id"
    ))
  )
  for (name in names(defaults)) {
    defaults[[name]] <- phase16_euro_empty_like(resources[[name]], defaults[[name]])
  }
  defaults
}

phase16_euro_nonempty <- function(data, columns, label) {
  if (!is.data.frame(data) || !nrow(data)) {
    return(paste(label, "must contain at least one row"))
  }
  missing <- setdiff(columns, names(data))
  if (length(missing)) return(paste(label, "is missing", paste(missing, collapse = ", ")))
  for (column in columns) {
    values <- as.character(data[[column]])
    if (any(is.na(values) | !nzchar(trimws(values)))) {
      return(paste(label, column, "contains blank values"))
    }
  }
  NULL
}

phase16_euro_bool <- function(value) {
  if (is.logical(value)) return(!is.na(value) & value)
  tolower(trimws(as.character(value))) %in% c("true", "1", "yes", "confirmed")
}

phase16_euro_fixture_eligibility <- function(fixtures) {
  if (!is.data.frame(fixtures)) {
    return(data.frame(
      fixture_id = character(), kickoff_confirmed = logical(),
      confirmed_kickoff_at_utc = character(), forecast_eligible = logical(),
      reason = character(), stringsAsFactors = FALSE, check.names = FALSE
    ))
  }
  fixture_id <- if ("fixture_id" %in% names(fixtures)) as.character(fixtures$fixture_id) else rep("", nrow(fixtures))
  kickoff <- if ("kickoff_confirmed" %in% names(fixtures)) phase16_euro_bool(fixtures$kickoff_confirmed) else rep(FALSE, nrow(fixtures))
  confirmed_at <- if ("confirmed_kickoff_at_utc" %in% names(fixtures)) {
    as.character(fixtures$confirmed_kickoff_at_utc)
  } else {
    rep("", nrow(fixtures))
  }
  has_id <- !is.na(fixture_id) & nzchar(trimws(fixture_id))
  has_time <- !is.na(confirmed_at) & nzchar(trimws(confirmed_at))
  eligible <- has_id & kickoff & has_time
  reason <- rep("confirmed_kickoff", nrow(fixtures))
  reason[!has_id] <- "missing_fixture_id"
  reason[has_id & !kickoff] <- "kickoff_not_confirmed"
  reason[has_id & kickoff & !has_time] <- "missing_confirmed_kickoff_at_utc"
  data.frame(
    fixture_id = fixture_id,
    kickoff_confirmed = kickoff,
    confirmed_kickoff_at_utc = confirmed_at,
    forecast_eligible = eligible,
    reason = reason,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

phase16_euro_artifacts <- function(candidate) {
  artifacts <- candidate$artifacts
  if (is.null(artifacts)) artifacts <- candidate$source_artifacts
  if (is.null(artifacts) && is.data.frame(candidate$source_bundle)) {
    artifacts <- candidate$source_bundle
  }
  if (is.null(artifacts) && is.list(candidate$source_bundle)) artifacts <- candidate$source_bundle$artifacts
  if (is.data.frame(artifacts)) return(artifacts)
  NULL
}

phase16_euro_validate_artifacts <- function(candidate, edition_id, bundle_id) {
  artifacts <- phase16_euro_artifacts(candidate)
  required <- phase16_euro_required_resource_types()
  if (is.null(artifacts)) return("source bundle is missing the registered artifact manifest")
  if (!"artifact_type" %in% names(artifacts)) return("source artifact manifest is missing artifact_type")
  types <- as.character(artifacts$artifact_type)
  if (length(types) != length(required) || anyDuplicated(types) || !setequal(types, required)) {
    return("source bundle must contain exactly the five required resources")
  }
  if ("edition_id" %in% names(artifacts) && any(as.character(artifacts$edition_id) != edition_id)) {
    return("source artifact edition_id does not match EURO qualifying")
  }
  if ("bundle_id" %in% names(artifacts) && any(as.character(artifacts$bundle_id) != bundle_id)) {
    return("source artifact bundle_id does not match the accepted bundle")
  }
  if ("ruleset_version" %in% names(artifacts)) {
    ruleset_version <- phase16_euro_scalar(c(
      candidate$ruleset_version,
      phase16_euro_metadata_value(candidate$source_bundle, c("ruleset_version", "ruleset"))
    ))
    if (any(as.character(artifacts$ruleset_version) != ruleset_version)) {
      return("source artifact ruleset revision does not match the accepted bundle")
    }
  }
  for (column in c("source_url", "retrieved_at_utc", "parser_version")) {
    if (column %in% names(artifacts) && any(vapply(artifacts[[column]], phase16_euro_blank, logical(1)))) {
      return(paste("source artifact provenance is incomplete:", column))
    }
  }
  for (column in c("raw_sha256", "canonical_content_sha256")) {
    if (column %in% names(artifacts) && any(!vapply(artifacts[[column]], phase16_euro_hash_is_valid, logical(1)))) {
      return(paste("source artifact", column, "must contain SHA-256 values"))
    }
  }
  NULL
}

phase16_euro_artifact_canonical_hashes <- function(candidate) {
  artifacts <- phase16_euro_artifacts(candidate)
  if (is.null(artifacts) || !"artifact_type" %in% names(artifacts) ||
      !"canonical_content_sha256" %in% names(artifacts)) return(character())
  hashes <- as.character(artifacts$canonical_content_sha256)
  names(hashes) <- as.character(artifacts$artifact_type)
  hashes
}

phase16_euro_candidate_canonical_hashes <- function(candidate) {
  hashes <- candidate$canonical_hashes
  if (is.null(hashes)) return(phase16_euro_artifact_canonical_hashes(candidate))
  if (is.data.frame(hashes) && all(c("artifact_type", "canonical_content_sha256") %in% names(hashes))) {
    values <- as.character(hashes$canonical_content_sha256)
    names(values) <- as.character(hashes$artifact_type)
    return(values)
  }
  if (is.list(hashes) && !is.null(names(hashes))) {
    values <- vapply(hashes, phase16_euro_scalar, character(1))
    return(values)
  }
  values <- as.character(hashes)
  if (!is.null(names(hashes))) names(values) <- names(hashes)
  values
}

phase16_euro_validate_candidate <- function(candidate, config = NULL, incumbent = NULL) {
  if (!is.list(candidate)) return(list(valid = FALSE, activation_status = "unavailable", reason = "candidate must be a list"))
  if (is.null(config) && is.list(candidate$activation_config)) config <- candidate$activation_config
  rules <- uefa_euro_2026_28_rules(config)
  manifest_registered <- tolower(phase16_euro_metadata_value(
    candidate$manifest,
    c("registered", "is_registered"),
    "false"
  )) %in% c("true", "1", "yes")
  rules$registered_source_bundle_ids <- unique(c(
    phase16_euro_registered_bundle_ids(config),
    if (manifest_registered) phase16_euro_metadata_value(candidate$manifest, c("source_bundle_id", "bundle_id")) else character()
  ))
  rules$registered_ruleset_versions <- unique(c(
    phase16_euro_registered_ruleset_versions(config),
    if (manifest_registered) phase16_euro_metadata_value(candidate$manifest, c("ruleset_version", "ruleset")) else character()
  ))
  resources <- phase16_euro_resource_list(candidate)
  source_bundle <- candidate$source_bundle
  bundle_id <- phase16_euro_scalar(
    c(
      candidate$source_bundle_id,
      phase16_euro_metadata_value(source_bundle, c("source_bundle_id", "bundle_id")),
      phase16_euro_metadata_value(candidate$manifest, c("source_bundle_id", "bundle_id"))
    )
  )
  edition_id <- phase16_euro_scalar(c(
    candidate$edition_id,
    phase16_euro_metadata_value(source_bundle, c("edition_id", "source_edition_id")),
    phase16_euro_metadata_value(candidate$manifest, c("edition_id", "source_edition_id"))
  ))
  ruleset_version <- phase16_euro_scalar(c(
    candidate$ruleset_version,
    phase16_euro_metadata_value(source_bundle, c("ruleset_version", "ruleset")),
    phase16_euro_metadata_value(candidate$manifest, c("ruleset_version", "ruleset"))
  ))
  lifecycle_state <- tolower(phase16_euro_scalar(c(
    candidate$lifecycle_state,
    phase16_euro_metadata_value(resources$status, c("lifecycle_state", "competition_status")),
    phase16_euro_metadata_value(source_bundle, c("lifecycle_state", "competition_status"))
  )))
  if (identical(lifecycle_state, "active") || identical(lifecycle_state, "in_progress")) lifecycle_state <- "scheduled"
  failure <- NULL
  if (!identical(edition_id, rules$edition_id)) failure <- "unknown EURO qualifying edition"
  if (is.null(failure) && !ruleset_version %in% rules$registered_ruleset_versions) failure <- "unknown EURO qualifying ruleset revision"
  if (is.null(failure) && !nzchar(bundle_id)) failure <- "accepted source bundle ID is missing"
  if (is.null(failure) && !bundle_id %in% rules$registered_source_bundle_ids) failure <- "source bundle is not registered for EURO qualifying"
  manifest_id <- phase16_euro_metadata_value(candidate$manifest, c("source_bundle_id", "bundle_id"))
  if (is.null(failure) && nzchar(manifest_id) && !identical(manifest_id, bundle_id)) failure <- "manifest source bundle ID does not match candidate"
  manifest_edition <- phase16_euro_metadata_value(candidate$manifest, c("edition_id", "source_edition_id"))
  if (is.null(failure) && nzchar(manifest_edition) && !identical(manifest_edition, edition_id)) failure <- "manifest edition ID does not match candidate"
  manifest_rules <- phase16_euro_metadata_value(candidate$manifest, c("ruleset_version", "ruleset"))
  if (is.null(failure) && nzchar(manifest_rules) && !identical(manifest_rules, ruleset_version)) failure <- "manifest ruleset revision does not match candidate"
  bundle_status <- tolower(phase16_euro_metadata_value(source_bundle, c("bundle_status", "status", "acceptance_status"), "accepted"))
  if (is.null(failure) && !identical(bundle_status, "accepted")) failure <- "source bundle is not accepted"
  if (is.null(failure)) failure <- phase16_euro_validate_artifacts(candidate, edition_id, bundle_id)
  artifact_hashes <- phase16_euro_artifact_canonical_hashes(candidate)
  candidate_hashes <- phase16_euro_candidate_canonical_hashes(candidate)
  if (is.null(failure) && length(candidate_hashes)) {
    common_hashes <- intersect(names(candidate_hashes), names(artifact_hashes))
    if (length(common_hashes) && any(tolower(candidate_hashes[common_hashes]) != tolower(artifact_hashes[common_hashes]))) {
      failure <- "candidate canonical content hash does not match the source artifact manifest"
    }
  }

  required_missing <- names(resources)[vapply(resources, is.null, logical(1))]
  if (is.null(failure) && length(required_missing)) {
    failure <- paste("source bundle is missing resource:", paste(required_missing, collapse = ", "))
  }
  raw_snapshot <- candidate$raw_snapshot
  raw_hash <- phase16_euro_metadata_value(raw_snapshot, c("raw_sha256", "snapshot_sha256", "bundle_raw_sha256"))
  raw_time <- phase16_euro_metadata_value(raw_snapshot, c("retrieved_at_utc", "retrieved_at", "last_refresh_at_utc"))
  if (is.null(failure) && is.null(raw_snapshot)) {
    raw_hash <- phase16_euro_metadata_value(candidate$manifest, c("raw_sha256", "snapshot_sha256"))
    raw_time <- phase16_euro_metadata_value(source_bundle, c("retrieved_at_utc", "accepted_at_utc"))
  }
  if (is.null(failure) && !phase16_euro_hash_is_valid(raw_hash)) failure <- "raw snapshot provenance hash is missing or invalid"
  if (is.null(failure) && !nzchar(raw_time)) failure <- "raw snapshot refresh timestamp is missing"

  non_status <- setdiff(names(resources), "status")
  if (is.null(failure) && !lifecycle_state %in% c("pre_draw", "scheduled")) {
    failure <- "source bundle lifecycle is invalid"
  }
  if (is.null(failure) && lifecycle_state == "pre_draw") {
    if (any(vapply(resources[non_status], nrow, integer(1)) != 0L)) {
      failure <- "pre_draw source bundle contains fabricated groups, fixtures, standings, or results"
    }
  }
  fixture_gate <- "not_applicable"
  if (is.null(failure) && lifecycle_state == "scheduled") {
    group_failure <- phase16_euro_nonempty(resources$groups, c("group_id"), "groups")
    if (!is.null(group_failure)) failure <- group_failure
    fixture_failure <- phase16_euro_nonempty(
      resources$fixtures,
      c("fixture_id", "home_team_id", "away_team_id"),
      "fixtures"
    )
    if (is.null(failure) && !is.null(fixture_failure)) failure <- fixture_failure
    if (is.null(failure) && anyDuplicated(as.character(resources$groups$group_id))) {
      failure <- "groups must have unique stable group IDs"
    }
    if (is.null(failure) && anyDuplicated(as.character(resources$fixtures$fixture_id))) {
      failure <- "fixtures must have unique stable fixture IDs"
    }
    if (is.null(failure) && any(as.character(resources$fixtures$home_team_id) == as.character(resources$fixtures$away_team_id))) {
      failure <- "fixtures cannot contain identical home and away team IDs"
    }
    if (is.null(failure) && "edition_id" %in% names(resources$groups) && any(as.character(resources$groups$edition_id) != edition_id)) {
      failure <- "group edition IDs do not match EURO qualifying"
    }
    team_ids <- if (is.data.frame(candidate$teams) && "team_id" %in% names(candidate$teams)) {
      as.character(candidate$teams$team_id)
    } else if (is.data.frame(resources$groups) && "team_id" %in% names(resources$groups)) {
      as.character(resources$groups$team_id)
    } else {
      unique(c(as.character(resources$fixtures$home_team_id), as.character(resources$fixtures$away_team_id)))
    }
    if (is.null(failure) && any(is.na(team_ids) | !nzchar(trimws(team_ids)))) failure <- "stable team IDs are missing"
    fixture_team_ids <- unique(c(as.character(resources$fixtures$home_team_id), as.character(resources$fixtures$away_team_id)))
    if (is.null(failure) && !all(fixture_team_ids %in% team_ids)) failure <- "fixtures reference unregistered team IDs"
    eligibility <- phase16_euro_fixture_eligibility(resources$fixtures)
    fixture_gate <- if (all(eligibility$forecast_eligible)) "confirmed_kickoff" else "kickoff_incomplete"
    if (is.null(failure) && !all(eligibility$forecast_eligible)) failure <- "every active fixture requires a stable ID and confirmed kickoff"
    if (is.null(failure) && any(!is.na(resources$groups$team_count))) {
      expected <- tapply(resources$groups$team_count, resources$groups$group_id, function(count) as.integer(count[[1L]]) * (as.integer(count[[1L]]) - 1L))
      actual <- table(as.character(resources$fixtures$group_id))
      expected_names <- intersect(base::names(expected), base::names(actual))
      if (length(expected_names) && any(as.integer(expected[expected_names]) > as.integer(actual[expected_names]))) {
        failure <- "active fixture schedule is incomplete for a group"
      }
      if (is.null(failure) && length(setdiff(base::names(expected), base::names(actual)))) {
        failure <- "active fixture schedule is incomplete for a group"
      }
    }
  }
  if (is.null(failure) && !is.null(incumbent)) {
    incumbent_raw <- phase16_euro_scalar(incumbent$raw_sha256)
    if (nzchar(incumbent_raw) && identical(tolower(incumbent_raw), tolower(raw_hash))) {
      failure <- "revision cannot reuse the incumbent raw snapshot hash"
    }
    incumbent_hashes <- phase16_euro_candidate_canonical_hashes(incumbent)
    common_hashes <- intersect(names(candidate_hashes), names(incumbent_hashes))
    if (is.null(failure) && length(common_hashes) && any(
      tolower(candidate_hashes[common_hashes]) == tolower(incumbent_hashes[common_hashes])
    )) {
      failure <- "revision cannot reuse the incumbent canonical content hash"
    }
  }
  valid <- is.null(failure)
  activation_status <- if (!valid) "unavailable" else if (lifecycle_state == "pre_draw") "pre_draw" else "active"
  list(
    valid = valid,
    activation_status = activation_status,
    lifecycle_state = if (valid) lifecycle_state else "unavailable",
    forecast_status = if (!valid) "unavailable" else if (lifecycle_state == "pre_draw") "pre_draw" else "available",
    forecast_reason = if (valid && lifecycle_state == "pre_draw") "awaiting_official_draw_and_schedule" else if (valid) "complete_official_draw_and_schedule_bundle" else "source_bundle_validation_failed",
    forecast_unavailability_reason = if (valid && lifecycle_state == "pre_draw") "awaiting_official_draw_and_schedule" else if (!valid) failure else "",
    reason = if (valid) "accepted_complete_source_bundle" else failure,
    failure_reason = if (valid) "" else failure,
    fixture_gate = fixture_gate,
    edition_id = edition_id,
    ruleset_version = ruleset_version,
    source_bundle_id = bundle_id,
    revision_status = if (is.null(incumbent)) "accepted" else "candidate",
    raw_sha256 = raw_hash,
    canonical_hashes = candidate_hashes,
    official_draw_date = rules$official_draw_date,
    last_refresh_at_utc = raw_time,
    source_confidence = phase16_euro_scalar(c(
      candidate$source_confidence,
      phase16_euro_metadata_value(source_bundle, c("source_confidence", "confidence")),
      if (lifecycle_state == "pre_draw") "official_registry_pending" else "official"
    )),
    resources = resources,
    candidate = candidate,
    raw_snapshot = raw_snapshot,
    rules = rules
  )
}

phase16_validate_euro_source_bundle <- function(candidate = NULL, config = NULL, incumbent = NULL, ...) {
  if (is.null(candidate)) candidate <- list(...)
  phase16_euro_validate_candidate(candidate, config = config, incumbent = incumbent)
}

validate_euro_activation <- function(
    candidate = NULL,
    groups = NULL,
    fixtures = NULL,
    team_registry = NULL,
    source_bundle = NULL,
    standings = NULL,
    results = NULL,
    raw_snapshot = NULL,
    registered_manifest = NULL,
    config = NULL,
    incumbent = NULL,
    ...) {
  if (is.null(candidate)) {
    candidate <- list(
      edition_id = uefa_euro_edition_id(),
      source_bundle = source_bundle,
      resources = list(
        groups = groups,
        fixtures = fixtures,
        standings = standings,
        results = results,
        status = NULL
      ),
      teams = team_registry,
      raw_snapshot = raw_snapshot,
      manifest = registered_manifest,
      ...
    )
  } else {
    if (!is.null(registered_manifest) && is.null(candidate$manifest)) candidate$manifest <- registered_manifest
    if (!is.null(raw_snapshot) && is.null(candidate$raw_snapshot)) candidate$raw_snapshot <- raw_snapshot
    if (!is.null(source_bundle) && is.null(candidate$source_bundle)) candidate$source_bundle <- source_bundle
    if (!is.null(team_registry) && is.null(candidate$teams)) candidate$teams <- team_registry
  }
  phase16_validate_euro_source_bundle(candidate, config = config, incumbent = incumbent)
}

phase16_euro_activation_envelope <- function(validation, incumbent = NULL) {
  if (!is.list(validation)) stop("EURO activation validation must be a list", call. = FALSE)
  if (!isTRUE(validation$valid)) {
    if (!is.null(incumbent)) return(phase16_euro_revision_overlay(validation, incumbent))
    empty <- phase16_euro_empty_collections(validation$resources)
    return(c(
      list(
        valid = FALSE,
        activation_status = "unavailable",
        lifecycle_state = "unavailable",
        forecast_status = "unavailable",
        forecast_reason = "source_bundle_validation_failed",
        forecast_unavailability_reason = phase16_euro_scalar(validation$failure_reason, "source bundle validation failed"),
        reason = phase16_euro_scalar(validation$failure_reason, "source bundle validation failed"),
        official_draw_date = phase16_euro_scalar(validation$official_draw_date, uefa_euro_official_draw_date()),
        last_refresh_at_utc = phase16_euro_scalar(validation$last_refresh_at_utc),
        source_bundle_id = phase16_euro_scalar(validation$source_bundle_id),
        ruleset_version = phase16_euro_scalar(validation$ruleset_version, uefa_euro_ruleset_version()),
        source_confidence = phase16_euro_scalar(validation$source_confidence, "official_registry_pending"),
        raw_sha256 = phase16_euro_scalar(validation$raw_sha256),
        canonical_hashes = validation$canonical_hashes,
        message_heading = uefa_euro_2026_28_rules()$message_heading,
        message_body = uefa_euro_2026_28_rules()$message_body,
        candidate_isolated = TRUE,
        candidate_metadata = list(source_bundle_id = validation$source_bundle_id, reason = validation$failure_reason)
      ),
      empty
    ))
  }
  resources <- validation$resources
  empty <- phase16_euro_empty_collections(resources)
  if (identical(validation$activation_status, "pre_draw")) {
    return(c(
      list(
        valid = TRUE,
        activation_status = "pre_draw",
        lifecycle_state = "pre_draw",
        forecast_status = "pre_draw",
        forecast_reason = "awaiting_official_draw_and_schedule",
        forecast_unavailability_reason = "awaiting_official_draw_and_schedule",
        reason = "awaiting_official_draw_and_schedule",
        official_draw_date = validation$official_draw_date,
        last_refresh_at_utc = validation$last_refresh_at_utc,
        source_bundle_id = validation$source_bundle_id,
        ruleset_version = validation$ruleset_version,
        source_confidence = validation$source_confidence,
        raw_sha256 = validation$raw_sha256,
        canonical_hashes = validation$canonical_hashes,
        message_heading = uefa_euro_2026_28_rules()$message_heading,
        message_body = uefa_euro_2026_28_rules()$message_body,
        candidate_isolated = FALSE
      ),
      empty
    ))
  }
  fixtures <- resources$fixtures
  eligibility <- phase16_euro_fixture_eligibility(fixtures)
  fixtures$forecast_eligible <- eligibility$forecast_eligible
  c(
    list(
      valid = TRUE,
      activation_status = "active",
      lifecycle_state = "scheduled",
      forecast_status = "available",
      forecast_reason = "complete_official_draw_and_schedule_bundle",
      forecast_unavailability_reason = "",
      reason = "complete_official_draw_and_schedule_bundle",
      official_draw_date = validation$official_draw_date,
      last_refresh_at_utc = validation$last_refresh_at_utc,
      source_bundle_id = validation$source_bundle_id,
      ruleset_version = validation$ruleset_version,
      source_confidence = validation$source_confidence,
      raw_sha256 = validation$raw_sha256,
      canonical_hashes = validation$canonical_hashes,
      fixture_gate = validation$fixture_gate,
      candidate_isolated = FALSE,
      teams = phase16_euro_or(resources$teams, empty$teams),
      groups = phase16_euro_or(resources$groups, empty$groups),
      fixtures = fixtures,
      standings = phase16_euro_or(resources$standings, empty$standings),
      results = phase16_euro_or(resources$results, empty$results)
    ),
    empty[c("qualification_ledger", "host_slots", "topology", "probabilities")]
  )
}

phase16_euro_revision_overlay <- function(validation, incumbent) {
  if (is.null(incumbent) || !is.list(incumbent)) {
    return(phase16_euro_activation_envelope(validation))
  }
  overlay <- incumbent
  overlay$activation_status <- "revision_blocked"
  overlay$revision_status <- "revision_blocked"
  overlay$revision_warning <- "A candidate EURO source revision was isolated; the incumbent accepted bundle remains active."
  overlay$warning <- overlay$revision_warning
  overlay$candidate_isolated <- TRUE
  overlay$candidate_metadata <- list(
    source_bundle_id = validation$source_bundle_id,
    edition_id = validation$edition_id,
    ruleset_version = validation$ruleset_version,
    reason = validation$failure_reason
  )
  overlay$candidate <- NULL
  overlay$candidate_rows <- NULL
  overlay$revision_failure_reason <- validation$failure_reason
  overlay
}

phase16_euro_rules <- uefa_euro_2026_28_rules
