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
    lifecycle_states = c("pre_draw", "scheduled", "in_progress", "complete"),
    forecast_statuses = c("pre_draw", "available", "unavailable"),
    source_confidence_active = "official",
    registered_ruleset_versions = phase16_euro_registered_ruleset_versions(config),
    message_heading = "EURO qualifying is awaiting the official draw",
    message_body = paste(
      "Official groups and the schedule are not available yet.",
      "The draw is expected on 6 December 2026.",
      "Forecasts will appear after a complete official draw-and-schedule bundle is accepted."
    ),
    registered_source_bundle_ids = phase16_euro_registered_bundle_ids(config),
    group_tiebreak = c(
      "head_to_head_points", "head_to_head_goal_difference", "head_to_head_goals",
      "recursive_tied_subset", "overall_goal_difference", "overall_goals",
      "overall_away_goals", "wins", "away_wins", "discipline_points",
      "interim_overall_rank"
    ),
    overall_tiebreak = c(
      "group_position", "points", "goal_difference", "goals_for",
      "away_goals", "wins", "away_wins", "discipline_points",
      "interim_overall_rank"
    ),
    host_reserved_capacity = 2L,
    best_runner_up_places = 8L,
    qualifying_group_count = 12L,
    playoff_places = 4L,
    host_selection_rule = "highest_ranked_two_covered_hosts",
    registered_draw_conditions_versions = c("uefa-euro-2028-playoff-draw-conditions-v1")
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
  for (column in c("source_url", "retrieved_at_utc")) {
    if (!column %in% names(artifacts) || any(vapply(artifacts[[column]], phase16_euro_blank, logical(1)))) {
      return(paste("source artifact provenance is incomplete:", column))
    }
  }
  if (!any(c("parser_version", "parser_commit_sha") %in% names(artifacts))) {
    return("source artifact provenance is missing parser identity")
  }
  parser_column <- if ("parser_version" %in% names(artifacts)) "parser_version" else "parser_commit_sha"
  if (any(vapply(artifacts[[parser_column]], phase16_euro_blank, logical(1)))) {
    return("source artifact provenance is incomplete: parser identity")
  }
  for (column in c("raw_sha256", "canonical_content_sha256")) {
    if (!column %in% names(artifacts) || any(!vapply(artifacts[[column]], phase16_euro_hash_is_valid, logical(1)))) {
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
  raw_bundle_id <- phase16_euro_metadata_value(raw_snapshot, c("source_bundle_id", "bundle_id"))
  raw_edition_id <- phase16_euro_metadata_value(raw_snapshot, c("edition_id", "source_edition_id"))
  if (is.null(failure) && nzchar(raw_bundle_id) && !identical(raw_bundle_id, bundle_id)) {
    failure <- "raw snapshot bundle ID does not match the accepted bundle"
  }
  if (is.null(failure) && nzchar(raw_edition_id) && !identical(raw_edition_id, edition_id)) {
    failure <- "raw snapshot edition ID does not match EURO qualifying"
  }
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

# EURO qualification rules stay pure and return lineage-bearing tables. These
# helpers deliberately mirror the Phase 15 rules adapter without taking over
# Phase 14's universal standings arithmetic.
phase16_euro_rules_text <- function(value, default = "") {
  if (is.null(value) || !length(value) || is.na(value[[1L]])) return(default)
  value <- trimws(as.character(value[[1L]]))
  if (!nzchar(value)) default else value
}

phase16_euro_rules_hash <- function(value) {
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("digest is required for EURO qualification hashes", call. = FALSE)
  }
  digest::digest(enc2utf8(as.character(value)), algo = "sha256", serialize = FALSE)
}

phase16_euro_rules_canonical <- function(value) {
  if (is.data.frame(value)) {
    data <- value[, sort(names(value)), drop = FALSE]
    if (nrow(data)) {
      ordering <- lapply(data, function(column) {
        text <- as.character(column)
        text[is.na(text)] <- ""
        text
      })
      data <- data[do.call(order, c(ordering, list(na.last = TRUE, method = "radix"))), , drop = FALSE]
    }
    rows <- if (!nrow(data)) character() else vapply(seq_len(nrow(data)), function(index) {
      values <- vapply(data[index, , drop = FALSE], function(column) {
        if (is.na(column[[1L]])) "" else as.character(column[[1L]])
      }, character(1))
      paste(values, collapse = "\x1f")
    }, character(1))
    return(paste(c(paste(names(data), collapse = "\x1f"), rows), collapse = "\x1e"))
  }
  if (is.list(value)) {
    values <- value
    if (!is.null(names(values))) values <- values[sort(names(values))]
    return(paste(vapply(values, phase16_euro_rules_canonical, character(1)), collapse = "\x1c"))
  }
  values <- as.character(value)
  values[is.na(values)] <- ""
  paste(values, collapse = "\x1f")
}

uefa_euro_ruleset_sha256 <- function(rules = uefa_euro_2026_28_rules()) {
  phase16_euro_rules_hash(phase16_euro_rules_canonical(rules))
}

phase16_euro_default_draw_conditions <- function() {
  conditions <- c("host_association_separation", "northern_ireland_separation")
  payload <- paste(
    "uefa-euro-2028-playoff-draw-conditions-v1",
    "artifact-euro-draw-conditions-v1",
    paste(conditions, collapse = "|"),
    sep = "\x1f"
  )
  list(
    draw_conditions_version = "uefa-euro-2028-playoff-draw-conditions-v1",
    draw_conditions_sha256 = phase16_euro_rules_hash(payload),
    source_artifact_id = "artifact-euro-draw-conditions-v1",
    source_bundle_id = uefa_euro_source_bundle_id(),
    accepted = TRUE,
    complete = TRUE,
    conditions = conditions
  )
}

phase16_euro_draw_conditions_record <- function(draw_conditions) {
  if (is.data.frame(draw_conditions)) {
    if (!nrow(draw_conditions)) return(NULL)
    return(as.list(draw_conditions[1L, , drop = FALSE]))
  }
  if (is.list(draw_conditions) && !is.null(draw_conditions$draw_conditions)) {
    draw_conditions <- draw_conditions$draw_conditions
  }
  if (is.list(draw_conditions)) return(draw_conditions)
  NULL
}

validate_euro_draw_conditions <- function(draw_conditions = NULL, rules = uefa_euro_2026_28_rules()) {
  if (missing(draw_conditions)) draw_conditions <- phase16_euro_default_draw_conditions()
  record <- phase16_euro_draw_conditions_record(draw_conditions)
  if (is.null(record)) {
    return(list(
      valid = FALSE,
      status = "unresolved_draw_conditions",
      topology_status = "unsupported_topology",
      reasons = c("unresolved_draw_conditions", "unsupported_topology"),
      reason = "draw_conditions_missing",
      draw_conditions = NULL
    ))
  }
  version <- phase16_euro_rules_text(record$draw_conditions_version %||% record$version)
  hash <- phase16_euro_rules_text(record$draw_conditions_sha256 %||% record$canonical_hash %||% record$sha256)
  artifact <- phase16_euro_rules_text(record$source_artifact_id %||% record$draw_conditions_source_artifact_id %||% record$artifact_id)
  source_bundle <- phase16_euro_rules_text(record$source_bundle_id %||% record$bundle_id, uefa_euro_source_bundle_id())
  accepted <- if (is.null(record$accepted)) TRUE else phase16_euro_bool(record$accepted)
  complete <- if (is.null(record$complete)) NA else phase16_euro_bool(record$complete)
  conditions <- record$conditions %||% record$draw_constraints %||% record$additional_conditions %||% record$constraints
  reasons <- character()
  if (!nzchar(version)) reasons <- c(reasons, "draw_conditions_version_missing")
  if (!phase16_euro_hash_is_valid(hash)) reasons <- c(reasons, "draw_conditions_sha256_missing_or_invalid")
  if (!nzchar(artifact)) reasons <- c(reasons, "draw_conditions_source_artifact_missing")
  if (!accepted) reasons <- c(reasons, "draw_conditions_not_accepted")
  if (identical(complete, FALSE) || is.null(conditions) || !length(conditions)) {
    reasons <- c(reasons, "draw_conditions_incomplete")
  }
  registered <- unique(c(
    "uefa-euro-2028-playoff-draw-conditions-v1",
    as.character(rules$registered_draw_conditions_versions %||% character())
  ))
  if (nzchar(version) && !version %in% registered) reasons <- c(reasons, "draw_conditions_version_unrecognised")
  reasons <- unique(reasons)
  list(
    valid = !length(reasons),
    status = if (length(reasons)) "unresolved_draw_conditions" else "accepted",
    topology_status = if (length(reasons)) "unsupported_topology" else "available",
    reasons = if (length(reasons)) c("unresolved_draw_conditions", reasons, "unsupported_topology") else character(),
    reason = if (length(reasons)) paste(reasons, collapse = ";") else "",
    draw_conditions = record,
    draw_conditions_version = version,
    draw_conditions_sha256 = hash,
    draw_conditions_source_artifact_id = artifact,
    source_bundle_id = source_bundle
  )
}

phase16_euro_topology_rows <- function(rules = uefa_euro_2026_28_rules()) {
  data.frame(
    topology_id = c("euro-playoff-host-0", "euro-playoff-host-1", "euro-playoff-host-2"),
    reserved_slots_used = c(0L, 1L, 2L),
    entrant_count = c(8L, 12L, 8L),
    structure = c(
      "4 seeded-versus-unseeded home-and-away ties",
      "3 single-leg paths of 4",
      "2 single-leg paths of 4"
    ),
    places = c(4L, 3L, 2L),
    stage_format = c("home_and_away_tie", "single_leg_path", "single_leg_path"),
    seed_policy = c("seeded_home_second_leg", "pot_1_pot_2_paths", "pot_1_pot_2_paths"),
    match_resolution = c("aggregate_goals_then_article_22", "extra_time_then_penalties", "extra_time_then_penalties"),
    source = "uefa-official-playoff-rules",
    source_artifact_id = "artifact-euro-topology-v1",
    source_bundle_id = uefa_euro_source_bundle_id(),
    ruleset_version = rules$ruleset_version,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

uefa_euro_playoff_topologies <- function(rules = uefa_euro_2026_28_rules(), draw_conditions = NULL) {
  if (is.list(rules) && !is.null(rules$draw_conditions_version) && is.null(rules$ruleset_version) && missing(draw_conditions)) {
    draw_conditions <- rules
    rules <- uefa_euro_2026_28_rules()
  }
  validation <- if (missing(draw_conditions)) {
    validate_euro_draw_conditions(rules = rules)
  } else {
    validate_euro_draw_conditions(draw_conditions, rules = rules)
  }
  output <- phase16_euro_topology_rows(rules)
  output$ruleset_sha256 <- uefa_euro_ruleset_sha256(rules)
  output$draw_conditions_version <- phase16_euro_rules_text(validation$draw_conditions_version)
  output$draw_conditions_sha256 <- phase16_euro_rules_text(validation$draw_conditions_sha256)
  output$draw_conditions_source_artifact_id <- phase16_euro_rules_text(validation$draw_conditions_source_artifact_id)
  output$draw_conditions_status <- validation$status
  output$status <- if (isTRUE(validation$valid)) "available" else "unsupported_topology"
  output$reason <- if (isTRUE(validation$valid)) "" else paste(validation$reasons, collapse = ";")
  output$current_topology <- FALSE
  output$scenario_status <- "unresolved"
  output <- output[order(output$reserved_slots_used, method = "radix"), , drop = FALSE]
  row.names(output) <- NULL
  output
}

phase16_euro_coalesce <- function(left, right) {
  if (is.null(left) || !length(left)) return(right)
  if (length(left) == 1L && (is.na(left) || !nzchar(trimws(as.character(left))))) return(right)
  left
}

`%||%` <- function(left, right) phase16_euro_coalesce(left, right)

phase16_euro_bind_data_frames <- function(values) {
  values <- Filter(function(value) is.data.frame(value), values)
  if (!length(values)) return(data.frame(stringsAsFactors = FALSE, check.names = FALSE))
  columns <- unique(unlist(lapply(values, names), use.names = FALSE))
  values <- lapply(values, function(value) {
    missing <- setdiff(columns, names(value))
    for (field in missing) value[[field]] <- rep(NA, nrow(value))
    value[, columns, drop = FALSE]
  })
  output <- do.call(rbind, values)
  row.names(output) <- NULL
  output
}

phase16_euro_rank_input <- function(value) {
  if (is.data.frame(value)) return(value)
  if (is.list(value)) {
    for (field in c("rankings", "group_rankings", "rows", "standings")) {
      if (!is.null(value[[field]])) {
        nested <- phase16_euro_rank_input(value[[field]])
        if (nrow(nested) || length(value[[field]]) == 0L) return(nested)
      }
    }
    return(phase16_euro_bind_data_frames(value))
  }
  data.frame(stringsAsFactors = FALSE, check.names = FALSE)
}

phase16_euro_field <- function(data, fields, default = "") {
  candidates <- intersect(fields, names(data))
  if (!length(candidates)) return(rep(default, nrow(data)))
  field <- candidates[[1L]]
  data[[field]]
}

phase16_euro_first_field <- function(data, fields, default = "") {
  values <- phase16_euro_field(data, fields, default)
  present <- !is.na(values) & nzchar(trimws(as.character(values)))
  if (any(present)) as.character(values[[which(present)[[1L]]]]) else default
}

phase16_euro_numeric <- function(values, default = NA_real_) {
  output <- suppressWarnings(as.numeric(as.character(values)))
  output[is.na(output) & !is.na(default)] <- default
  output
}

phase16_euro_integer <- function(values, default = NA_integer_) {
  output <- suppressWarnings(as.integer(as.character(values)))
  output[is.na(output) & !is.na(default)] <- default
  output
}

phase16_euro_attach_lineage <- function(data, rules, source_bundle_id = NULL, source_artifact_id = NULL) {
  data <- as.data.frame(data, stringsAsFactors = FALSE, check.names = FALSE)
  defaults <- list(
    source_bundle_id = phase16_euro_first_field(data, "source_bundle_id", phase16_euro_rules_text(source_bundle_id, uefa_euro_source_bundle_id())),
    source_artifact_id = phase16_euro_first_field(data, c("source_artifact_id", "artifact_id"), phase16_euro_rules_text(source_artifact_id)),
    ruleset_version = phase16_euro_first_field(data, "ruleset_version", phase16_euro_rules_text(rules$ruleset_version, uefa_euro_ruleset_version())),
    ruleset_sha256 = phase16_euro_first_field(data, "ruleset_sha256", uefa_euro_ruleset_sha256(rules)),
    source_bundle_sha256 = phase16_euro_first_field(data, "source_bundle_sha256", "")
  )
  for (field in names(defaults)) {
    if (!field %in% names(data)) data[[field]] <- rep(defaults[[field]], nrow(data))
    values <- as.character(data[[field]])
    missing <- is.na(values) | !nzchar(trimws(values))
    values[missing] <- defaults[[field]]
    data[[field]] <- values
  }
  data$source_lineage <- paste(data$source_bundle_id, data$source_artifact_id, sep = "::")
  data$rules_lineage <- paste(data$ruleset_version, data$ruleset_sha256, sep = "::")
  data
}

phase16_euro_match_id <- function(data) {
  fields <- intersect(c("fixture_id", "match_id", "source_fixture_id", "source_match_id"), names(data))
  if (!length(fields)) return(rep("", nrow(data)))
  as.character(data[[fields[[1L]]]])
}

phase16_euro_completion_status <- function(values) {
  tolower(trimws(as.character(values))) %in% c(
    "completed", "complete", "finished", "full_time", "full-time",
    "after_extra_time", "after-extra-time", "after_penalties", "after-penalties", "awarded"
  )
}

phase16_euro_prepare_matches <- function(fixtures, team_ids, group_id = NULL) {
  if (is.null(fixtures)) fixtures <- data.frame(stringsAsFactors = FALSE, check.names = FALSE)
  if (!is.data.frame(fixtures)) stop("EURO ranking fixtures must be a data frame", call. = FALSE)
  if (!nrow(fixtures)) return(list(rows = fixtures, eligible = logical(), missing = character()))
  required <- c("home_team_id", "away_team_id")
  missing_columns <- setdiff(required, names(fixtures))
  if (length(missing_columns)) stop("EURO ranking fixtures are missing columns: ", paste(missing_columns, collapse = ", "), call. = FALSE)
  rows <- as.data.frame(fixtures, stringsAsFactors = FALSE, check.names = FALSE)
  rows$home_team_id <- trimws(as.character(rows$home_team_id))
  rows$away_team_id <- trimws(as.character(rows$away_team_id))
  rows$match_id <- phase16_euro_match_id(rows)
  missing <- character()
  if (any(is.na(rows$match_id) | !nzchar(rows$match_id))) missing <- c(missing, "fixture_id")
  if (anyDuplicated(rows$match_id[nzchar(rows$match_id)])) stop("EURO ranking fixtures require unique stable IDs", call. = FALSE)
  home_fields <- intersect(c("final_home_goals", "home_goals", "regulation_home_goals"), names(rows))
  away_fields <- intersect(c("final_away_goals", "away_goals", "regulation_away_goals"), names(rows))
  home_field <- if (length(home_fields)) home_fields[[1L]] else NULL
  away_field <- if (length(away_fields)) away_fields[[1L]] else NULL
  home_goals <- if (is.null(home_field) || is.na(home_field)) rep(NA_real_, nrow(rows)) else phase16_euro_numeric(rows[[home_field]])
  away_goals <- if (is.null(away_field) || is.na(away_field)) rep(NA_real_, nrow(rows)) else phase16_euro_numeric(rows[[away_field]])
  rows$final_home_goals <- home_goals
  rows$final_away_goals <- away_goals
  score_present <- !is.na(home_goals) & !is.na(away_goals) & home_goals >= 0 & away_goals >= 0
  status_fields <- intersect(c("match_status", "source_status", "fixture_status", "status"), names(rows))
  status_field <- if (length(status_fields)) status_fields[[1L]] else NULL
  status_present <- if (is.null(status_field)) rep(TRUE, nrow(rows)) else phase16_euro_completion_status(rows[[status_field]])
  count_present <- if ("counts_for_standings" %in% names(rows)) phase16_euro_bool(rows$counts_for_standings) else rep(TRUE, nrow(rows))
  if (any(status_present & count_present & !score_present)) missing <- c(missing, "completed_scores")
  foreign_team <- !rows$home_team_id %in% team_ids | !rows$away_team_id %in% team_ids
  if (any(foreign_team)) missing <- c(missing, "stable_team_id")
  if (!is.null(group_id) && "group_id" %in% names(rows)) {
    foreign_group <- !is.na(rows$group_id) & nzchar(as.character(rows$group_id)) & as.character(rows$group_id) != group_id
    if (any(foreign_group)) missing <- c(missing, "group_id")
  }
  eligible <- score_present & status_present & count_present & !foreign_team & nzchar(rows$match_id)
  evidence_fields <- intersect(c("evidence_completed_at_utc", "completed_at_utc"), names(rows))
  evidence_field <- if (length(evidence_fields)) evidence_fields[[1L]] else NULL
  if (is.null(evidence_field) && any(eligible)) {
    missing <- c(missing, "evidence_completed_at_utc")
  } else if (!is.null(evidence_field) && any(eligible & !nzchar(as.character(rows[[evidence_field]])))) {
    missing <- c(missing, "evidence_completed_at_utc")
  }
  list(rows = rows, eligible = eligible, missing = unique(missing))
}

phase16_euro_match_metrics <- function(rows, eligible, team_ids) {
  if (!is.data.frame(rows) || !nrow(rows) || !any(eligible)) {
    return(data.frame(
      team_id = as.character(team_ids), points = 0, goal_difference = 0,
      goals_for = 0, away_goals = 0, wins = 0, away_wins = 0,
      stringsAsFactors = FALSE, check.names = FALSE
    ))
  }
  rows <- rows[eligible, , drop = FALSE]
  output <- lapply(as.character(team_ids), function(team_id) {
    home <- rows$home_team_id == team_id
    away <- rows$away_team_id == team_id
    gf <- c(rows$final_home_goals[home], rows$final_away_goals[away])
    ga <- c(rows$final_away_goals[home], rows$final_home_goals[away])
    data.frame(
      team_id = team_id,
      points = as.integer(3L * sum(gf > ga) + sum(gf == ga)),
      goal_difference = as.integer(sum(gf) - sum(ga)),
      goals_for = as.integer(sum(gf)),
      away_goals = as.integer(sum(rows$final_away_goals[away])),
      wins = as.integer(sum(gf > ga)),
      away_wins = as.integer(sum(rows$final_away_goals[away] > rows$final_home_goals[away])),
      stringsAsFactors = FALSE, check.names = FALSE
    )
  })
  do.call(rbind, output)
}

phase16_euro_prepare_standings <- function(standings, rules, group_id = NULL) {
  if (!is.data.frame(standings)) stop("EURO group standings must be a data frame", call. = FALSE)
  output <- as.data.frame(standings, stringsAsFactors = FALSE, check.names = FALSE)
  if (!nrow(output)) return(output)
  if (!"team_id" %in% names(output)) stop("EURO group standings require stable team_id", call. = FALSE)
  output$team_id <- trimws(as.character(output$team_id))
  if (any(is.na(output$team_id) | !nzchar(output$team_id)) || anyDuplicated(output$team_id)) {
    stop("EURO group standings require unique stable team_id values", call. = FALSE)
  }
  if (!"group_id" %in% names(output)) output$group_id <- phase16_euro_rules_text(group_id)
  if (is.null(group_id)) group_id <- phase16_euro_first_field(output, "group_id")
  output$group_id <- phase16_euro_rules_text(group_id)
  if (!nzchar(output$group_id[[1L]])) stop("EURO group ranking requires group_id", call. = FALSE)
  if (!"edition_id" %in% names(output)) output$edition_id <- uefa_euro_edition_id()
  output$edition_id <- as.character(output$edition_id)
  aliases <- list(
    points = c("points"),
    goal_difference = c("goal_difference", "goal_diff"),
    goals_for = c("goals_for", "goals_scored", "goals"),
    away_goals = c("away_goals", "goals_for_away"),
    wins = c("wins"),
    away_wins = c("away_wins"),
    discipline_points = c("discipline_points", "disciplinary_points"),
    interim_overall_rank = c("interim_overall_rank", "interim_rank", "nations_league_rank")
  )
  for (field in names(aliases)) {
    candidates <- intersect(aliases[[field]], names(output))
    source <- if (length(candidates)) candidates[[1L]] else NULL
    if (is.null(source)) output[[field]] <- NA_integer_ else output[[field]] <- phase16_euro_integer(output[[source]])
  }
  if (!"group_position" %in% names(output)) {
    output$group_position <- if ("rank" %in% names(output)) phase16_euro_integer(output$rank) else NA_integer_
  } else {
    output$group_position <- phase16_euro_integer(output$group_position)
  }
  if (!"group_size" %in% names(output)) output$group_size <- as.integer(nrow(output))
  output$group_size <- phase16_euro_integer(output$group_size, nrow(output))
  output
}

phase16_euro_rank_metric_groups <- function(ids, values, decreasing = TRUE) {
  values <- suppressWarnings(as.numeric(values))
  if (anyNA(values)) {
    finite <- sort(unique(values[!is.na(values)]), decreasing = decreasing, method = "radix")
    groups <- lapply(finite, function(value) ids[values == value])
    if (anyNA(values)) groups[[length(groups) + 1L]] <- ids[is.na(values)]
    return(groups)
  }
  unique_values <- sort(unique(values), decreasing = decreasing, method = "radix")
  lapply(unique_values, function(value) ids[values == value])
}

phase16_euro_tiebreak_trace <- function(
    group_id, criterion, tied_subset, counted_match_ids, decision,
    recursion_depth, remaining_tied_subset, rules, source_bundle_id, source_artifact_id,
    ranking_scope = "group") {
  evidence_id <- paste(
    if (identical(as.character(ranking_scope), "overall")) "article23" else "article15",
    group_id, criterion, as.integer(recursion_depth),
    phase16_euro_rules_hash(paste(sort(tied_subset), collapse = "|")), sep = "::"
  )
  data.frame(
    evidence_id = evidence_id,
    ranking_scope = as.character(ranking_scope),
    group_id = as.character(group_id),
    criterion = as.character(criterion),
    tied_subset = paste(sort(unique(as.character(tied_subset))), collapse = ";"),
    counted_match_ids = paste(sort(unique(as.character(counted_match_ids))), collapse = ";"),
    decision = as.character(decision),
    recursion_depth = as.integer(recursion_depth),
    remaining_tied_subset = paste(sort(unique(as.character(remaining_tied_subset))), collapse = ";"),
    source_bundle_id = as.character(source_bundle_id),
    source_artifact_id = as.character(source_artifact_id),
    ruleset_version = as.character(rules$ruleset_version),
    ruleset_sha256 = uefa_euro_ruleset_sha256(rules),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

phase16_euro_apply_rank_hashes <- function(data) {
  data <- as.data.frame(data, stringsAsFactors = FALSE, check.names = FALSE)
  data$row_sha256 <- vapply(seq_len(nrow(data)), function(index) {
    phase16_euro_rules_hash(phase16_euro_rules_canonical(data[index, setdiff(names(data), "row_sha256"), drop = FALSE]))
  }, character(1))
  table_hash <- phase16_euro_rules_hash(phase16_euro_rules_canonical(data[, setdiff(names(data), "table_sha256"), drop = FALSE]))
  data$table_sha256 <- rep(table_hash, nrow(data))
  data
}

phase16_euro_blocked_ranking <- function(data, missing_rule_input, rules, ranking_scope = "group", trace = NULL) {
  data <- as.data.frame(data, stringsAsFactors = FALSE, check.names = FALSE)
  if (!"team_id" %in% names(data)) data$team_id <- character(nrow(data))
  if (!"group_id" %in% names(data)) data$group_id <- NA_character_
  if (!"edition_id" %in% names(data)) data$edition_id <- uefa_euro_edition_id()
  data$ranking_scope <- ranking_scope
  data$ranking_stage <- if (ranking_scope == "group") "article15_group" else "article23_overall"
  data$rank <- NA_integer_
  data$group_position <- if ("group_position" %in% names(data)) phase16_euro_integer(data$group_position) else NA_integer_
  data$overall_rank <- NA_integer_
  data$article23_rank <- NA_integer_
  data$counted_match_ids <- if ("counted_match_ids" %in% names(data)) as.character(data$counted_match_ids) else ""
  data$excluded_match_ids <- if ("excluded_match_ids" %in% names(data)) as.character(data$excluded_match_ids) else ""
  data$ordering_status <- "blocked"
  data$missing_rule_input <- paste(unique(as.character(missing_rule_input)), collapse = ";")
  data$suppression_reason <- "missing_rule_input"
  data$qualification_eligibility_status <- "suppressed"
  data$probability <- NA_real_
  data <- phase16_euro_attach_lineage(data, rules)
  data <- phase16_euro_apply_rank_hashes(data)
  if (is.null(trace)) {
    missing_text <- if (nrow(data)) data$missing_rule_input[[1L]] else "missing_rule_input"
    trace <- phase16_euro_tiebreak_trace(
      if (nrow(data)) data$group_id[[1L]] else "",
      "blocked", if (nrow(data)) data$team_id else character(), character(),
      missing_text, 0L,
      if (nrow(data)) data$team_id else character(), rules,
      phase16_euro_first_field(data, "source_bundle_id"),
      phase16_euro_first_field(data, "source_artifact_id")
    )
  }
  attr(data, "tiebreak_trace") <- trace
  data
}

rank_euro_group <- function(standings, fixtures = NULL, rules = uefa_euro_2026_28_rules(), group_id = NULL) {
  rules <- if (is.null(rules)) uefa_euro_2026_28_rules() else rules
  prepared <- phase16_euro_prepare_standings(standings, rules, group_id)
  if (!nrow(prepared)) {
    return(phase16_euro_blocked_ranking(prepared, "completed_standings", rules, "group"))
  }
  group_id <- prepared$group_id[[1L]]
  team_ids <- as.character(prepared$team_id)
  matches <- phase16_euro_prepare_matches(fixtures, team_ids, group_id)
  match_metrics <- phase16_euro_match_metrics(matches$rows, matches$eligible, team_ids)
  missing <- unique(matches$missing)
  required <- c("points", "goal_difference", "goals_for", "away_goals", "wins", "away_wins", "discipline_points", "interim_overall_rank")
  for (field in required) {
    values <- phase16_euro_numeric(prepared[[field]])
    derived <- match_metrics[[field]]
    fill <- is.na(values) & !is.na(derived)
    values[fill] <- derived[fill]
    if (anyNA(values)) missing <- c(missing, field)
    prepared[[field]] <- as.integer(values)
  }
  source_artifact <- phase16_euro_first_field(prepared, c("source_artifact_id", "artifact_id"))
  if (!nzchar(source_artifact)) missing <- c(missing, "source_artifact_id")
  if (any(is.na(prepared$group_id) | !nzchar(prepared$group_id))) missing <- c(missing, "group_id")
  if (length(missing)) return(phase16_euro_blocked_ranking(prepared, unique(missing), rules, "group"))

  overall <- prepared
  trace_parts <- list()
  trace_index <- 0L
  add_trace <- function(criterion, subset, counted_ids, decision, depth, remaining) {
    trace_index <<- trace_index + 1L
    trace_parts[[trace_index]] <<- phase16_euro_tiebreak_trace(
      group_id, criterion, subset, counted_ids, decision, depth, remaining,
      rules, phase16_euro_first_field(prepared, "source_bundle_id"), source_artifact
    )
  }
  h2h_values <- function(ids, criterion) {
    subset_rows <- matches$rows[
      matches$eligible & matches$rows$home_team_id %in% ids & matches$rows$away_team_id %in% ids,
      , drop = FALSE
    ]
    metrics <- phase16_euro_match_metrics(subset_rows, rep(TRUE, nrow(subset_rows)), ids)
    field <- switch(
      criterion,
      head_to_head_points = "points",
      head_to_head_goal_difference = "goal_difference",
      head_to_head_goals = "goals_for"
    )
    list(values = metrics[[field]], counted_ids = phase16_euro_match_id(subset_rows), rows = subset_rows)
  }
  overall_values <- function(ids, criterion) {
    rows <- overall[match(ids, overall$team_id), , drop = FALSE]
    field <- switch(
      criterion,
      overall_goal_difference = "goal_difference",
      overall_goals = "goals_for",
      overall_away_goals = "away_goals",
      wins = "wins",
      away_wins = "away_wins",
      discipline_points = "discipline_points",
      interim_overall_rank = "interim_overall_rank"
    )
    list(values = rows[[field]], counted_ids = phase16_euro_match_id(matches$rows[matches$eligible, , drop = FALSE]))
  }
  h2h_criteria <- c("head_to_head_points", "head_to_head_goal_difference", "head_to_head_goals")
  overall_criteria <- c("overall_goal_difference", "overall_goals", "overall_away_goals", "wins", "away_wins", "discipline_points", "interim_overall_rank")
  order_overall <- function(ids, criterion_index, depth) {
    if (length(ids) <= 1L) return(ids)
    for (index in seq.int(criterion_index, length(overall_criteria))) {
      criterion <- overall_criteria[[index]]
      evaluated <- overall_values(ids, criterion)
      groups <- phase16_euro_rank_metric_groups(ids, evaluated$values, criterion != "discipline_points" && criterion != "interim_overall_rank")
      decision <- paste(vapply(groups, function(group) paste(sort(group), collapse = "+"), character(1)), collapse = " > ")
      add_trace(criterion, ids, evaluated$counted_ids, decision, depth, ids)
      if (length(groups) > 1L) {
        return(unlist(lapply(groups, function(group) if (length(group) <= 1L) group else order_overall(group, index + 1L, depth)), use.names = FALSE))
      }
    }
    sort(ids, method = "radix")
  }
  order_tied <- function(ids, depth = 0L) {
    if (length(ids) <= 1L) return(ids)
    for (criterion in h2h_criteria) {
      evaluated <- h2h_values(ids, criterion)
      if (!nrow(evaluated$rows)) missing <<- unique(c(missing, "head_to_head_evidence"))
      groups <- phase16_euro_rank_metric_groups(ids, evaluated$values, TRUE)
      decision <- paste(vapply(groups, function(group) paste(sort(group), collapse = "+"), character(1)), collapse = " > ")
      add_trace(criterion, ids, evaluated$counted_ids, decision, depth, ids)
      if (length(groups) > 1L) {
        return(unlist(lapply(groups, function(group) {
          if (length(group) <= 1L) return(group)
          add_trace("recursive_tied_subset", group, evaluated$counted_ids, "reapply_head_to_head", depth + 1L, group)
          order_tied(group, depth + 1L)
        }), use.names = FALSE))
      }
    }
    order_overall(ids, 1L, depth)
  }
  points <- prepared$points
  initial_groups <- phase16_euro_rank_metric_groups(team_ids, points, TRUE)
  add_trace("points", team_ids, phase16_euro_match_id(matches$rows[matches$eligible, , drop = FALSE]), paste(vapply(initial_groups, function(group) paste(sort(group), collapse = "+"), character(1)), collapse = " > "), 0L, team_ids)
  ordered_ids <- unlist(lapply(initial_groups, function(group) if (length(group) <= 1L) group else order_tied(group, 0L)), use.names = FALSE)
  if (length(missing)) return(phase16_euro_blocked_ranking(prepared, unique(missing), rules, "group", do.call(rbind, trace_parts)))
  if (length(ordered_ids) != length(team_ids) || anyDuplicated(ordered_ids) || !setequal(ordered_ids, team_ids)) {
    return(phase16_euro_blocked_ranking(prepared, "team_id", rules, "group", do.call(rbind, trace_parts)))
  }
  output <- prepared[match(ordered_ids, prepared$team_id), , drop = FALSE]
  output$ranking_scope <- "group"
  output$ranking_stage <- "article15_group"
  output$rank <- as.integer(seq_len(nrow(output)))
  output$group_position <- output$rank
  output$overall_rank <- NA_integer_
  output$article23_rank <- NA_integer_
  output$counted_match_ids <- vapply(ordered_ids, function(team_id) {
    paste(sort(unique(phase16_euro_match_id(matches$rows[matches$eligible & (matches$rows$home_team_id == team_id | matches$rows$away_team_id == team_id), , drop = FALSE]))), collapse = ";")
  }, character(1))
  output$excluded_match_ids <- ""
  output$ordering_status <- "ready"
  output$missing_rule_input <- ""
  output$suppression_reason <- "none"
  output$qualification_eligibility_status <- "available"
  output$probability <- NA_real_
  output <- phase16_euro_attach_lineage(output, rules)
  trace <- if (length(trace_parts)) do.call(rbind, trace_parts) else data.frame(stringsAsFactors = FALSE, check.names = FALSE)
  trace$evidence_id <- as.character(trace$evidence_id)
  evidence_ids <- paste(unique(trace$evidence_id), collapse = ";")
  output$tiebreak_evidence_ids <- evidence_ids
  output$tie_break_evidence_id <- paste0("article15::", output$group_id, "::", output$team_id, "::", output$rank)
  output <- phase16_euro_apply_rank_hashes(output)
  row.names(trace) <- NULL
  attr(output, "tiebreak_trace") <- trace
  attr(output, "trace") <- trace
  output
}

phase16_euro_article23_metrics <- function(group_rows, group_matches, candidate_id) {
  team_ids <- as.character(group_rows$team_id)
  prepared <- phase16_euro_prepare_matches(group_matches, team_ids, group_rows$group_id[[1L]])
  if (length(prepared$missing)) {
    return(list(
      missing = prepared$missing,
      counted_match_ids = character(),
      excluded_match_ids = character(),
      metrics = NULL
    ))
  }
  group_size <- phase16_euro_integer(group_rows$group_size, nrow(group_rows))[[1L]]
  fifth_ids <- if (identical(as.integer(group_size), 5L)) {
    as.character(group_rows$team_id[group_rows$group_position == 5L])
  } else {
    character()
  }
  if (identical(as.integer(group_size), 5L) && length(fifth_ids) != 1L) {
    return(list(
      missing = "fifth_place_identification",
      counted_match_ids = character(),
      excluded_match_ids = character(),
      metrics = NULL
    ))
  }
  fifth_match <- if (length(fifth_ids)) {
    prepared$rows$home_team_id %in% fifth_ids | prepared$rows$away_team_id %in% fifth_ids
  } else {
    rep(FALSE, nrow(prepared$rows))
  }
  excluded_match_ids <- phase16_euro_match_id(prepared$rows[fifth_match, , drop = FALSE])
  eligible <- prepared$eligible & !fifth_match
  counted_match_ids <- phase16_euro_match_id(prepared$rows[eligible, , drop = FALSE])
  if (!length(counted_match_ids)) {
    return(list(
      missing = "article23_comparison_match_evidence",
      counted_match_ids = counted_match_ids,
      excluded_match_ids = excluded_match_ids,
      metrics = NULL
    ))
  }
  metrics <- phase16_euro_match_metrics(prepared$rows, eligible, team_ids)
  candidate <- metrics[match(candidate_id, metrics$team_id), , drop = FALSE]
  if (!nrow(candidate) || anyNA(candidate[1L, c("points", "goal_difference", "goals_for", "away_goals", "wins", "away_wins"), drop = FALSE])) {
    return(list(
      missing = "article23_comparison_metrics",
      counted_match_ids = counted_match_ids,
      excluded_match_ids = excluded_match_ids,
      metrics = NULL
    ))
  }
  list(
    missing = character(),
    counted_match_ids = counted_match_ids,
    excluded_match_ids = excluded_match_ids,
    metrics = candidate
  )
}

rank_euro_overall <- function(group_rankings, fixtures = NULL, rules = uefa_euro_2026_28_rules()) {
  rules <- if (is.null(rules)) uefa_euro_2026_28_rules() else rules
  data <- phase16_euro_rank_input(group_rankings)
  if (!nrow(data)) return(phase16_euro_blocked_ranking(data, "completed_group_rankings", rules, "overall"))
  if (!"team_id" %in% names(data)) return(phase16_euro_blocked_ranking(data, "team_id", rules, "overall"))
  data$team_id <- trimws(as.character(data$team_id))
  if (any(is.na(data$team_id) | !nzchar(data$team_id)) || anyDuplicated(data$team_id)) {
    stop("EURO overall ranking requires unique stable team_id values", call. = FALSE)
  }
  if (!"group_id" %in% names(data)) data$group_id <- ""
  data$group_id <- trimws(as.character(data$group_id))
  if (any(is.na(data$group_id) | !nzchar(data$group_id))) {
    return(phase16_euro_blocked_ranking(data, "group_id", rules, "overall"))
  }
  if (!"group_position" %in% names(data)) {
    data$group_position <- if ("rank" %in% names(data)) phase16_euro_integer(data$rank) else NA_integer_
  }
  data$group_position <- phase16_euro_integer(data$group_position)
  if (!"group_size" %in% names(data)) {
    data$group_size <- as.integer(table(data$group_id)[data$group_id])
  }
  data$group_size <- phase16_euro_integer(data$group_size)
  candidates <- data[data$group_position == 2L, , drop = FALSE]
  if (!nrow(candidates)) {
    return(phase16_euro_blocked_ranking(data, "runner_up_group_position", rules, "overall"))
  }
  missing <- character()
  trace_parts <- list()
  trace_index <- 0L
  add_trace <- function(criterion, subset, counted_ids, decision, depth = 0L, remaining = subset) {
    trace_index <<- trace_index + 1L
    trace_parts[[trace_index]] <<- phase16_euro_tiebreak_trace(
      "overall", criterion, subset, counted_ids, decision, depth, remaining,
      rules, phase16_euro_first_field(candidates, "source_bundle_id"),
      phase16_euro_first_field(candidates, "source_artifact_id"), "overall"
    )
  }
  comparison_rows <- vector("list", nrow(candidates))
  for (index in seq_len(nrow(candidates))) {
    candidate <- candidates[index, , drop = FALSE]
    group_id <- as.character(candidate$group_id[[1L]])
    group_rows <- data[data$group_id == group_id, , drop = FALSE]
    group_status <- if ("ordering_status" %in% names(group_rows)) as.character(group_rows$ordering_status) else rep("ready", nrow(group_rows))
    if (any(is.na(group_rows$group_position)) || any(is.na(group_status) | group_status != "ready")) {
      missing <- c(missing, "group_ordering")
    }
    group_matches <- if (is.data.frame(fixtures) && nrow(fixtures) && "group_id" %in% names(fixtures)) {
      fixtures[as.character(fixtures$group_id) == group_id, , drop = FALSE]
    } else if (is.data.frame(fixtures)) {
      fixtures
    } else {
      data.frame(stringsAsFactors = FALSE, check.names = FALSE)
    }
    comparison <- phase16_euro_article23_metrics(group_rows, group_matches, candidate$team_id[[1L]])
    missing <- c(missing, comparison$missing)
    if (is.null(comparison$metrics)) {
      comparison_rows[[index]] <- candidate
      next
    }
    for (field in c("points", "goal_difference", "goals_for", "away_goals", "wins", "away_wins")) {
      candidate[[field]] <- as.integer(comparison$metrics[[field]][[1L]])
    }
    candidate$comparison_counted_match_ids <- paste(sort(unique(comparison$counted_match_ids)), collapse = ";")
    candidate$counted_match_ids <- candidate$comparison_counted_match_ids
    candidate$excluded_match_ids <- paste(sort(unique(comparison$excluded_match_ids)), collapse = ";")
    candidate$comparison_scope <- "article23_comparable_runner_up"
    candidate$comparison_status <- "ready"
    comparison_rows[[index]] <- candidate
  }
  candidates <- do.call(rbind, comparison_rows)
  row.names(candidates) <- NULL
  required <- c("discipline_points", "interim_overall_rank", "source_artifact_id")
  for (field in required) {
    if (!field %in% names(candidates)) {
      missing <- c(missing, field)
    } else if (any(is.na(candidates[[field]]) | !nzchar(as.character(candidates[[field]])))) {
      missing <- c(missing, field)
    }
  }
  if (any(is.na(candidates$group_position)) || any(is.na(candidates$group_size))) missing <- c(missing, "group_position")
  missing <- unique(missing[nzchar(missing)])
  initial_ids <- as.character(candidates$team_id)
  if (length(missing)) {
    trace <- phase16_euro_tiebreak_trace(
      "overall", "blocked", initial_ids, character(), paste(missing, collapse = ";"), 0L,
      initial_ids, rules, phase16_euro_first_field(candidates, "source_bundle_id"),
      phase16_euro_first_field(candidates, "source_artifact_id"), "overall"
    )
    blocked <- phase16_euro_blocked_ranking(candidates, missing, rules, "overall", trace)
    blocked$ranking_stage <- "article23_best_runners_up"
    blocked$comparison_scope <- "article23_comparable_runner_up"
    blocked$comparison_status <- "blocked"
    return(blocked)
  }
  criteria <- c(
    "group_position", "points", "goal_difference", "goals_for", "away_goals",
    "wins", "away_wins", "discipline_points", "interim_overall_rank"
  )
  criterion_decreasing <- function(criterion) !criterion %in% c("group_position", "discipline_points", "interim_overall_rank")
  candidate_values <- function(ids, criterion) {
    rows <- candidates[match(ids, candidates$team_id), , drop = FALSE]
    values <- rows[[criterion]]
    list(values = values, counted_ids = unique(unlist(strsplit(paste(rows$counted_match_ids, collapse = ";"), ";", fixed = TRUE))))
  }
  order_tied <- function(ids, criterion_index = 1L, depth = 0L) {
    if (length(ids) <= 1L) return(ids)
    for (index in seq.int(criterion_index, length(criteria))) {
      criterion <- criteria[[index]]
      evaluated <- candidate_values(ids, criterion)
      groups <- phase16_euro_rank_metric_groups(ids, evaluated$values, criterion_decreasing(criterion))
      decision <- paste(vapply(groups, function(group) paste(sort(group), collapse = "+"), character(1)), collapse = " > ")
      add_trace(criterion, ids, evaluated$counted_ids, decision, depth, ids)
      if (length(groups) > 1L) {
        return(unlist(lapply(groups, function(group) {
          if (length(group) <= 1L) group else order_tied(group, index + 1L, depth)
        }), use.names = FALSE))
      }
    }
    missing <<- unique(c(missing, "article23_final_tie_break"))
    sort(ids, method = "radix")
  }
  add_trace(
    "group_position", initial_ids, unique(candidates$counted_match_ids),
    paste(vapply(phase16_euro_rank_metric_groups(initial_ids, candidates$group_position, FALSE), function(group) paste(sort(group), collapse = "+"), character(1)), collapse = " > "),
    0L, initial_ids
  )
  ordered_ids <- order_tied(initial_ids)
  if ("article23_final_tie_break" %in% missing) {
    trace <- if (length(trace_parts)) do.call(rbind, trace_parts) else NULL
    blocked <- phase16_euro_blocked_ranking(candidates, unique(missing), rules, "overall", trace)
    blocked$ranking_stage <- "article23_best_runners_up"
    blocked$comparison_scope <- "article23_comparable_runner_up"
    blocked$comparison_status <- "blocked"
    return(blocked)
  }
  output <- candidates[match(ordered_ids, candidates$team_id), , drop = FALSE]
  output$ranking_scope <- "overall"
  output$ranking_stage <- "article23_best_runners_up"
  output$rank <- as.integer(seq_len(nrow(output)))
  output$overall_rank <- output$rank
  output$article23_rank <- output$rank
  output$ordering_status <- "ready"
  output$missing_rule_input <- ""
  output$suppression_reason <- "none"
  output$qualification_eligibility_status <- "available"
  output$probability <- NA_real_
  output$comparison_scope <- "article23_comparable_runner_up"
  output$comparison_status <- "ready"
  output <- phase16_euro_attach_lineage(output, rules)
  trace <- if (length(trace_parts)) do.call(rbind, trace_parts) else data.frame(stringsAsFactors = FALSE, check.names = FALSE)
  row.names(trace) <- NULL
  output$tiebreak_evidence_ids <- paste(unique(trace$evidence_id), collapse = ";")
  output$tie_break_evidence_id <- paste0("article23::", output$group_id, "::", output$team_id, "::", output$article23_rank)
  output <- phase16_euro_apply_rank_hashes(output)
  attr(output, "tiebreak_trace") <- trace
  attr(output, "trace") <- trace
  output
}

phase16_euro_host_input <- function(hosts, rules) {
  if (is.null(hosts)) {
    return(data.frame(
      host_slot_id = character(), slot_number = integer(), association_id = character(),
      host_association_id = character(), team_id = character(), covered = logical(),
      host_rank_evidence = numeric(), host_guarantee_status = character(),
      slot_status = character(), consumes_capacity = logical(),
      source_bundle_id = character(), source_artifact_id = character(),
      ruleset_version = character(), ruleset_sha256 = character(),
      stringsAsFactors = FALSE, check.names = FALSE
    ))
  }
  if (is.list(hosts) && !is.data.frame(hosts)) {
    for (field in c("host_slots", "covered_hosts", "hosts", "rows")) {
      if (!is.null(hosts[[field]])) return(phase16_euro_host_input(hosts[[field]], rules))
    }
  }
  if (is.atomic(hosts) && !is.data.frame(hosts)) {
    hosts <- data.frame(team_id = as.character(hosts), stringsAsFactors = FALSE, check.names = FALSE)
  }
  if (!is.data.frame(hosts)) stop("EURO host associations must be a data frame or keyed list", call. = FALSE)
  if (!nrow(hosts)) return(phase16_euro_host_input(NULL, rules))
  rows <- as.data.frame(hosts, stringsAsFactors = FALSE, check.names = FALSE)
  n <- nrow(rows)
  host_slot <- phase16_euro_field(rows, c("host_slot_id", "slot_id", "slot"), "")
  host_slot <- trimws(as.character(host_slot))
  blank_slot <- is.na(host_slot) | !nzchar(host_slot)
  host_slot[blank_slot] <- sprintf("euro-host-slot-%02d", which(blank_slot))
  if (anyDuplicated(host_slot)) stop("EURO host associations require unique host_slot_id values", call. = FALSE)
  slot_number <- phase16_euro_integer(phase16_euro_field(rows, c("slot_number", "host_slot_number"), seq_len(n)), seq_len(n))
  association <- trimws(as.character(phase16_euro_field(rows, c("association_id", "host_association_id", "association", "host_id"), "")))
  team_id <- trimws(as.character(phase16_euro_field(rows, c("team_id", "host_team_id"), "")))
  covered_field <- intersect(c("covered", "host_covered", "is_host"), names(rows))
  covered <- if (length(covered_field)) phase16_euro_bool(rows[[covered_field[[1L]]]]) else rep(TRUE, n)
  guarantee_field <- intersect(c("host_guarantee_status", "guarantee_status", "host_place_status"), names(rows))
  guarantee_raw <- if (length(guarantee_field)) tolower(trimws(as.character(rows[[guarantee_field[[1L]]]]))) else rep("", n)
  guarantee <- rep("unresolved", n)
  guarantee[!covered] <- "not_covered"
  guarantee[covered & guarantee_raw %in% c("resolved", "confirmed", "guaranteed", "accepted", "true", "yes")] <- "resolved"
  rank_field <- intersect(c("rank_evidence", "host_rank_evidence", "host_rank", "rank", "overall_rank"), names(rows))
  host_rank <- if (length(rank_field)) suppressWarnings(as.numeric(as.character(rows[[rank_field[[1L]]]]))) else rep(NA_real_, n)
  source_bundle <- as.character(phase16_euro_field(rows, "source_bundle_id", uefa_euro_source_bundle_id()))
  source_bundle[is.na(source_bundle) | !nzchar(trimws(source_bundle))] <- uefa_euro_source_bundle_id()
  source_artifact <- as.character(phase16_euro_field(rows, c("source_artifact_id", "artifact_id"), ""))
  ruleset_version <- as.character(phase16_euro_field(rows, "ruleset_version", rules$ruleset_version))
  ruleset_sha256 <- as.character(phase16_euro_field(rows, "ruleset_sha256", uefa_euro_ruleset_sha256(rules)))
  status <- ifelse(covered, "conditional", "not_covered")
  output <- data.frame(
    host_slot_id = host_slot,
    slot_number = as.integer(slot_number),
    association_id = association,
    host_association_id = association,
    team_id = team_id,
    covered = as.logical(covered),
    host_rank_evidence = host_rank,
    host_guarantee_status = guarantee,
    slot_status = status,
    consumes_capacity = rep(NA, n),
    source_bundle_id = source_bundle,
    source_artifact_id = source_artifact,
    ruleset_version = ruleset_version,
    ruleset_sha256 = ruleset_sha256,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  output$host_selection_status <- ifelse(output$covered, "pending", "not_covered")
  output$host_selection_reason <- ifelse(output$covered, "host_place_conditional", "association_not_covered")
  output
}

phase16_euro_host_placeholder <- function(slot_number, rules, source_bundle_id = uefa_euro_source_bundle_id(), source_artifact_id = "") {
  data.frame(
    host_slot_id = sprintf("euro-host-reserved-slot-%02d", as.integer(slot_number)),
    slot_number = as.integer(slot_number),
    association_id = "",
    host_association_id = "",
    team_id = "",
    covered = FALSE,
    host_rank_evidence = NA_real_,
    host_guarantee_status = "not_covered",
    slot_status = "host_reserved_unused",
    consumes_capacity = FALSE,
    source_bundle_id = source_bundle_id,
    source_artifact_id = source_artifact_id,
    ruleset_version = rules$ruleset_version,
    ruleset_sha256 = uefa_euro_ruleset_sha256(rules),
    host_selection_status = "unassigned",
    host_selection_reason = "reserved_capacity_remaining",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

phase16_euro_select_host_slots <- function(hosts, direct_team_ids, results_ready, rules) {
  rows <- phase16_euro_host_input(hosts, rules)
  covered <- rows$covered %in% TRUE
  covered_rows <- rows[covered, , drop = FALSE]
  source_bundle_id <- phase16_euro_first_field(rows, "source_bundle_id", uefa_euro_source_bundle_id())
  source_artifact_id <- phase16_euro_first_field(rows, "source_artifact_id")
  deterministic <- isTRUE(results_ready)
  unresolved_reasons <- character()
  if (!deterministic && nrow(covered_rows)) unresolved_reasons <- c(unresolved_reasons, "completed_standings_required")
  if (nrow(covered_rows) && any(covered_rows$host_guarantee_status != "resolved")) {
    unresolved_reasons <- c(unresolved_reasons, "host_guarantee_unresolved")
  }
  if (nrow(covered_rows) && any(is.na(covered_rows$association_id) | !nzchar(covered_rows$association_id))) {
    unresolved_reasons <- c(unresolved_reasons, "host_association_id")
  }
  if (nrow(covered_rows) && any(is.na(covered_rows$source_artifact_id) | !nzchar(covered_rows$source_artifact_id))) {
    unresolved_reasons <- c(unresolved_reasons, "host_source_artifact")
  }
  if (nrow(covered_rows) && any(is.na(covered_rows$host_rank_evidence))) {
    unresolved_reasons <- c(unresolved_reasons, "host_rank_evidence")
  }
  if (length(unresolved_reasons)) {
    rows$slot_status[covered] <- "host_place_unresolved"
    rows$consumes_capacity[covered] <- NA
    rows$host_selection_status[covered] <- "unresolved"
    rows$host_selection_reason[covered] <- paste(unique(unresolved_reasons), collapse = ";")
    if (nrow(covered_rows)) {
      placeholders <- lapply(seq_len(max(0L, 2L - nrow(covered_rows))), phase16_euro_host_placeholder,
        rules = rules, source_bundle_id = source_bundle_id, source_artifact_id = source_artifact_id)
      if (length(placeholders)) rows <- phase16_euro_bind_data_frames(c(list(rows), placeholders))
    }
    return(list(rows = rows, deterministic = FALSE, reserved_slots_used = NA_integer_, reasons = unique(unresolved_reasons)))
  }
  if (!nrow(covered_rows)) {
    placeholders <- lapply(seq_len(2L), phase16_euro_host_placeholder,
      rules = rules, source_bundle_id = source_bundle_id, source_artifact_id = source_artifact_id)
    if (length(placeholders)) rows <- phase16_euro_bind_data_frames(c(list(rows), placeholders))
    rows$slot_status[rows$slot_status == "host_reserved_unused"] <- "host_reserved_unused"
    rows$consumes_capacity[rows$slot_status == "host_reserved_unused"] <- FALSE
    rows$host_selection_status[rows$slot_status == "host_reserved_unused"] <- "unused"
    return(list(rows = rows, deterministic = deterministic, reserved_slots_used = 0L, reasons = character()))
  }
  ordering <- order(covered_rows$host_rank_evidence, covered_rows$association_id, method = "radix")
  covered_rows <- covered_rows[ordering, , drop = FALSE]
  if (nrow(covered_rows) > rules$host_reserved_capacity && anyDuplicated(covered_rows$host_rank_evidence[seq_len(rules$host_reserved_capacity + 1L)])) {
    rows$slot_status[covered] <- "host_place_unresolved"
    rows$consumes_capacity[covered] <- NA
    rows$host_selection_status[covered] <- "unresolved"
    rows$host_selection_reason[covered] <- "host_rank_tie_at_capacity_boundary"
    return(list(rows = rows, deterministic = FALSE, reserved_slots_used = NA_integer_, reasons = "host_rank_tie_at_capacity_boundary"))
  }
  selected_associations <- covered_rows$association_id[seq_len(min(nrow(covered_rows), rules$host_reserved_capacity))]
  selected <- covered & rows$association_id %in% selected_associations
  rows$slot_status[covered & selected] <- "occupied"
  rows$consumes_capacity[covered & selected] <- TRUE
  rows$host_selection_status[covered & selected] <- "selected"
  rows$host_selection_reason[covered & selected] <- ifelse(rows$team_id[covered & selected] %in% direct_team_ids, "direct_host_precedence", "host_reserved_place")
  rows$slot_status[covered & !selected] <- "host_reserved_unused"
  rows$consumes_capacity[covered & !selected] <- FALSE
  rows$host_selection_status[covered & !selected] <- "unselected"
  rows$host_selection_reason[covered & !selected] <- "host_rank_outside_reserved_capacity"
  if (nrow(covered_rows) < rules$host_reserved_capacity) {
    placeholders <- lapply(seq_len(rules$host_reserved_capacity - nrow(covered_rows)), function(index) {
      phase16_euro_host_placeholder(
        max(rows$slot_number, 0L) + index, rules, source_bundle_id, source_artifact_id
      )
    })
    rows <- phase16_euro_bind_data_frames(c(list(rows), placeholders))
  }
  list(
    rows = rows,
    deterministic = deterministic,
    reserved_slots_used = as.integer(sum(rows$consumes_capacity %in% TRUE)),
    reasons = character()
  )
}

phase16_euro_ledger_row <- function(
    allocation_id, scenario_id, ranked_row = NULL, team_id = "", group_id = "", association_id = "",
    host_slot_id = "", stage = "qualifying", qualification_status = "unavailable",
    place_type = "", consumes_capacity = FALSE, eligibility = "available", reason = "",
    counted_match_ids = "", excluded_match_ids = "", evidence_ids = "", source_bundle_id = "",
    source_artifact_id = "", rules = uefa_euro_2026_28_rules()) {
  if (!is.null(ranked_row) && is.data.frame(ranked_row) && nrow(ranked_row)) {
    team_id <- phase16_euro_rules_text(ranked_row$team_id, team_id)
    group_id <- phase16_euro_rules_text(ranked_row$group_id, group_id)
    association_id <- phase16_euro_rules_text(phase16_euro_field(ranked_row, "association_id", association_id), association_id)
    counted_match_ids <- phase16_euro_rules_text(phase16_euro_field(ranked_row, "counted_match_ids", counted_match_ids), counted_match_ids)
    excluded_match_ids <- phase16_euro_rules_text(phase16_euro_field(ranked_row, "excluded_match_ids", excluded_match_ids), excluded_match_ids)
    evidence_ids <- phase16_euro_rules_text(phase16_euro_field(ranked_row, "tiebreak_evidence_ids", evidence_ids), evidence_ids)
    source_bundle_id <- phase16_euro_rules_text(phase16_euro_field(ranked_row, "source_bundle_id", source_bundle_id), source_bundle_id)
    source_artifact_id <- phase16_euro_rules_text(phase16_euro_field(ranked_row, "source_artifact_id", source_artifact_id), source_artifact_id)
  }
  data.frame(
    allocation_id = allocation_id,
    scenario_id = scenario_id,
    edition_id = rules$edition_id,
    team_id = team_id,
    group_id = group_id,
    association_id = association_id,
    host_slot_id = host_slot_id,
    stage = stage,
    place_type = place_type,
    qualification_status = qualification_status,
    consumes_capacity = as.logical(consumes_capacity),
    qualification_eligibility_status = eligibility,
    probability = NA_real_,
    reason = reason,
    counted_match_ids = counted_match_ids,
    excluded_match_ids = excluded_match_ids,
    tiebreak_evidence_ids = evidence_ids,
    source_bundle_id = source_bundle_id,
    source_artifact_id = source_artifact_id,
    ruleset_version = rules$ruleset_version,
    ruleset_sha256 = uefa_euro_ruleset_sha256(rules),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

phase16_euro_empty_ledger <- function() {
  data.frame(
    allocation_id = character(), scenario_id = character(), edition_id = character(), team_id = character(),
    group_id = character(), association_id = character(), host_slot_id = character(), stage = character(),
    place_type = character(), qualification_status = character(), consumes_capacity = logical(),
    qualification_eligibility_status = character(), probability = numeric(), reason = character(),
    counted_match_ids = character(), excluded_match_ids = character(), tiebreak_evidence_ids = character(),
    source_bundle_id = character(), source_artifact_id = character(), ruleset_version = character(),
    ruleset_sha256 = character(), stringsAsFactors = FALSE, check.names = FALSE
  )
}

select_euro_best_runners_up <- function(
    overall_rankings, direct_team_ids = NULL, host_slots = NULL, rules = uefa_euro_2026_28_rules(),
    direct_qualifiers = NULL, host_reservations = NULL, required_group_count = NULL) {
  rules <- if (is.null(rules)) uefa_euro_2026_28_rules() else rules
  if (is.null(direct_team_ids) && is.data.frame(direct_qualifiers) && "team_id" %in% names(direct_qualifiers)) {
    direct_team_ids <- direct_qualifiers$team_id
  }
  if (is.null(host_slots)) host_slots <- host_reservations
  data <- phase16_euro_rank_input(overall_rankings)
  empty <- data[FALSE, , drop = FALSE]
  required_group_count <- as.integer(required_group_count %||% rules$qualifying_group_count %||% 12L)
  if (!nrow(data)) {
    return(list(
      status = "unavailable", reason = "comparison_groups_missing", missing_rule_input = "completed_group_rankings",
      selected = empty, remaining = empty, excluded = empty, ruleset_version = rules$ruleset_version,
      ruleset_sha256 = uefa_euro_ruleset_sha256(rules)
    ))
  }
  if (!"team_id" %in% names(data)) stop("EURO best-runner-up selection requires stable team_id", call. = FALSE)
  if (!"group_id" %in% names(data)) data$group_id <- ""
  if (!"group_position" %in% names(data)) data$group_position <- if ("rank" %in% names(data)) data$rank else NA_integer_
  if (!"ranking_scope" %in% names(data)) data$ranking_scope <- "overall"
  if (!"ordering_status" %in% names(data)) data$ordering_status <- "ready"
  candidate <- data[data$group_position == 2L | data$ranking_scope == "overall", , drop = FALSE]
  direct_team_ids <- unique(trimws(as.character(direct_team_ids %||% character())))
  occupied_host_ids <- character()
  if (is.data.frame(host_slots) && nrow(host_slots) && "consumes_capacity" %in% names(host_slots) && "team_id" %in% names(host_slots)) {
    occupied_host_ids <- as.character(host_slots$team_id[host_slots$consumes_capacity %in% TRUE])
  }
  excluded_ids <- unique(c(direct_team_ids, occupied_host_ids))
  excluded <- candidate[candidate$team_id %in% excluded_ids, , drop = FALSE]
  if (nrow(excluded)) {
    excluded$selection_exclusion_reason <- ifelse(excluded$team_id %in% direct_team_ids, "direct_qualifier_precedence", "host_reserved_precedence")
  }
  candidate <- candidate[!candidate$team_id %in% excluded_ids, , drop = FALSE]
  if (!nrow(candidate)) {
    return(list(
      status = "unavailable", reason = "all_runner_ups_consumed_by_prior_allocation", missing_rule_input = "",
      selected = empty, remaining = empty, excluded = excluded, ruleset_version = rules$ruleset_version,
      ruleset_sha256 = uefa_euro_ruleset_sha256(rules)
    ))
  }
  group_count <- length(unique(as.character(candidate$group_id)))
  ready <- all(as.character(candidate$ordering_status) == "ready") &&
    "article23_rank" %in% names(candidate) && all(!is.na(phase16_euro_integer(candidate$article23_rank)))
  if (!ready || group_count < required_group_count) {
    return(list(
      status = "unavailable", reason = "comparison_groups_incomplete", missing_rule_input = "article23_comparison_groups",
      selected = empty, remaining = candidate, excluded = excluded, ruleset_version = rules$ruleset_version,
      ruleset_sha256 = uefa_euro_ruleset_sha256(rules)
    ))
  }
  ordering <- order(candidate$article23_rank, candidate$team_id, method = "radix")
  candidate <- candidate[ordering, , drop = FALSE]
  limit <- min(nrow(candidate), as.integer(rules$best_runner_up_places))
  selected <- candidate[seq_len(limit), , drop = FALSE]
  remaining <- if (nrow(candidate) > limit) candidate[seq.int(limit + 1L, nrow(candidate)), , drop = FALSE] else candidate[FALSE, , drop = FALSE]
  selected$selection_status <- "selected_best_runner_up"
  remaining$selection_status <- "remaining_runner_up_playoff"
  list(
    status = "ready", reason = "", missing_rule_input = "", selected = selected, remaining = remaining,
    excluded = excluded, ruleset_version = rules$ruleset_version, ruleset_sha256 = uefa_euro_ruleset_sha256(rules)
  )
}

allocate_euro_places <- function(
    ranked = NULL, host_ids = NULL, draw_conditions = NULL, rules = uefa_euro_2026_28_rules(),
    runner_ups = NULL, fixtures = NULL, group_rankings = NULL, rankings = NULL, ranked_groups = NULL,
    hosts = NULL, host_associations = NULL, scenario_id = NULL) {
  rules <- if (is.null(rules)) uefa_euro_2026_28_rules() else rules
  if (!is.null(group_rankings)) ranked <- group_rankings
  if (!is.null(rankings)) ranked <- rankings
  if (!is.null(ranked_groups)) ranked <- ranked_groups
  ranked <- phase16_euro_rank_input(ranked)
  if (is.null(host_ids)) host_ids <- hosts
  if (is.null(host_ids)) host_ids <- host_associations
  results_ready <- nrow(ranked) > 0L &&
    "team_id" %in% names(ranked) &&
    (!"ordering_status" %in% names(ranked) || all(as.character(ranked$ordering_status) == "ready")) &&
    ((!"rank" %in% names(ranked) && "group_position" %in% names(ranked)) ||
      ("rank" %in% names(ranked) && all(!is.na(phase16_euro_integer(ranked$rank)))))
  direct_rank <- if ("rank" %in% names(ranked)) phase16_euro_integer(ranked$rank) else phase16_euro_integer(ranked$group_position)
  direct_rows <- if (results_ready) ranked[direct_rank == 1L, , drop = FALSE] else ranked[FALSE, , drop = FALSE]
  direct_team_ids <- if (nrow(direct_rows)) as.character(direct_rows$team_id) else character()
  host_selection <- phase16_euro_select_host_slots(host_ids, direct_team_ids, results_ready, rules)
  host_slots <- host_selection$rows
  host_slots <- phase16_euro_attach_lineage(host_slots, rules)
  host_slots <- phase16_euro_apply_rank_hashes(host_slots)
  status_input <- if (results_ready) "completed_results" else "active_scenario"
  scenario_status <- if (results_ready && host_selection$deterministic) "resolved" else "preserved"
  source_bundle_id <- phase16_euro_first_field(ranked, "source_bundle_id", phase16_euro_first_field(host_slots, "source_bundle_id", uefa_euro_source_bundle_id()))
  source_artifact_id <- phase16_euro_first_field(ranked, "source_artifact_id", phase16_euro_first_field(host_slots, "source_artifact_id"))
  if (is.null(scenario_id) || !nzchar(as.character(scenario_id))) {
    scenario_id <- paste0(
      "euro-allocation-scenario-",
      phase16_euro_rules_hash(paste(
        rules$edition_id, status_input, paste(sort(unique(as.character(ranked$team_id))), collapse = ";"),
        paste(sort(unique(as.character(host_slots$host_slot_id))), collapse = ";"), sep = "::"
      ))
    )
  }
  allocation_id <- paste0("euro-allocation-", phase16_euro_rules_hash(paste(scenario_id, rules$ruleset_version, sep = "::")))
  ledger_parts <- list()
  if (nrow(direct_rows)) {
    ledger_parts[[length(ledger_parts) + 1L]] <- do.call(rbind, lapply(seq_len(nrow(direct_rows)), function(index) {
      phase16_euro_ledger_row(
        allocation_id, scenario_id, direct_rows[index, , drop = FALSE],
        stage = "group_winner", qualification_status = "direct", place_type = "group_winner",
        eligibility = if (results_ready) "available" else "unresolved",
        reason = "article15_group_winner", rules = rules
      )
    }))
  }
  if (nrow(host_slots)) {
    ledger_parts[[length(ledger_parts) + 1L]] <- do.call(rbind, lapply(seq_len(nrow(host_slots)), function(index) {
      row <- host_slots[index, , drop = FALSE]
      slot_status <- as.character(row$slot_status[[1L]])
      if (identical(slot_status, "occupied")) {
        status <- "host_reserved_occupied"
        eligibility <- if (results_ready) "available" else "unresolved"
        reason <- as.character(row$host_selection_reason[[1L]])
      } else if (identical(slot_status, "host_place_unresolved")) {
        status <- "host_place_unresolved"
        eligibility <- "suppressed"
        reason <- paste("host place unresolved:", as.character(row$host_selection_reason[[1L]]))
      } else if (identical(slot_status, "host_reserved_unused")) {
        status <- "host_reserved_unused"
        eligibility <- "available"
        reason <- as.character(row$host_selection_reason[[1L]])
      } else {
        status <- "unavailable"
        eligibility <- "unresolved"
        reason <- "host_slot_not_covered"
      }
      phase16_euro_ledger_row(
        allocation_id, scenario_id,
        team_id = as.character(row$team_id[[1L]]), association_id = as.character(row$association_id[[1L]]),
        host_slot_id = as.character(row$host_slot_id[[1L]]), stage = "host_reservation",
        qualification_status = status, place_type = "host_reserved",
        consumes_capacity = row$consumes_capacity[[1L]], eligibility = eligibility, reason = reason,
        source_bundle_id = as.character(row$source_bundle_id[[1L]]), source_artifact_id = as.character(row$source_artifact_id[[1L]]),
        rules = rules
      )
    }))
  }
  overall <- NULL
  best_runner_up_status <- "unavailable"
  selected_runner_ups <- data.frame(stringsAsFactors = FALSE, check.names = FALSE)
  remaining_runner_ups <- data.frame(stringsAsFactors = FALSE, check.names = FALSE)
  if (results_ready && (is.null(runner_ups) || is.data.frame(runner_ups) || is.list(runner_ups))) {
    overall <- if (is.null(runner_ups)) rank_euro_overall(ranked, fixtures, rules) else {
      candidate <- phase16_euro_rank_input(runner_ups)
      if ("ranking_scope" %in% names(candidate) && any(as.character(candidate$ranking_scope) == "overall")) candidate else rank_euro_overall(candidate, fixtures, rules)
    }
    selection <- select_euro_best_runners_up(
      overall, direct_team_ids = direct_team_ids, host_slots = host_slots, rules = rules
    )
    best_runner_up_status <- selection$status
    if (identical(selection$status, "ready")) {
      selected_runner_ups <- selection$selected
      remaining_runner_ups <- selection$remaining
      if (nrow(selected_runner_ups)) {
        ledger_parts[[length(ledger_parts) + 1L]] <- do.call(rbind, lapply(seq_len(nrow(selected_runner_ups)), function(index) {
          phase16_euro_ledger_row(
            allocation_id, scenario_id, selected_runner_ups[index, , drop = FALSE],
            stage = "best_runner_up", qualification_status = "direct", place_type = "best_runner_up",
            eligibility = "available", reason = "article23_best_runner_up", rules = rules
          )
        }))
      }
      if (nrow(remaining_runner_ups)) {
        ledger_parts[[length(ledger_parts) + 1L]] <- do.call(rbind, lapply(seq_len(nrow(remaining_runner_ups)), function(index) {
          phase16_euro_ledger_row(
            allocation_id, scenario_id, remaining_runner_ups[index, , drop = FALSE],
            stage = "playoff_entry", qualification_status = "playoff_eligible", place_type = "runner_up_playoff",
            eligibility = "available", reason = "remaining_runner_up_after_article23", rules = rules
          )
        }))
      }
    }
  }
  ledger <- if (length(ledger_parts)) do.call(rbind, ledger_parts) else phase16_euro_empty_ledger()
  ledger$scenario_status <- scenario_status
  ledger$allocation_status <- if (scenario_status == "resolved") "resolved" else "scenario_preserved"
  ledger <- phase16_euro_attach_lineage(ledger, rules, source_bundle_id, source_artifact_id)
  draw_validation <- if (missing(draw_conditions)) validate_euro_draw_conditions(rules = rules) else validate_euro_draw_conditions(draw_conditions, rules = rules)
  topology <- if (missing(draw_conditions)) uefa_euro_playoff_topologies(rules = rules) else uefa_euro_playoff_topologies(rules = rules, draw_conditions = draw_conditions)
  topology$scenario_id <- scenario_id
  topology$allocation_id <- allocation_id
  topology$scenario_status <- scenario_status
  topology$current_topology <- FALSE
  host_count_known <- isTRUE(host_selection$deterministic) && !is.na(host_selection$reserved_slots_used)
  topology_reason <- character()
  if (!host_count_known) topology_reason <- c(topology_reason, "host_place_unresolved")
  if (!isTRUE(draw_validation$valid)) topology_reason <- c(topology_reason, draw_validation$reasons)
  if (host_count_known && isTRUE(draw_validation$valid)) {
    topology$current_topology <- topology$reserved_slots_used == as.integer(host_selection$reserved_slots_used)
    topology$scenario_status <- "resolved"
    topology$status <- "available"
    topology$reason <- ""
  } else {
    topology$status <- "unsupported_topology"
    topology$scenario_status <- if (scenario_status == "preserved") "preserved" else "unresolved"
    topology$reason <- paste(unique(c(topology$reason, topology_reason)), collapse = ";")
    ledger$probability <- NA_real_
    if (nrow(ledger)) {
      ledger$qualification_eligibility_status[ledger$qualification_status %in% c("direct", "playoff_eligible")] <- "unresolved"
      if (!isTRUE(draw_validation$valid)) {
        ledger$qualification_eligibility_status <- "suppressed"
        ledger$reason <- paste(ledger$reason, "unresolved_draw_conditions", sep = ";")
      }
    }
  }
  if (nrow(ledger)) ledger <- phase16_euro_apply_rank_hashes(ledger)
  topology <- phase16_euro_apply_rank_hashes(topology)
  host_slots <- phase16_euro_apply_rank_hashes(host_slots)
  reserved_used <- if (host_count_known) as.integer(host_selection$reserved_slots_used) else NA_integer_
  capacity <- list(
    reserved_slots_total = as.integer(rules$host_reserved_capacity),
    reserved_slots_used = reserved_used,
    reserved_slots_remaining = if (is.na(reserved_used)) NA_integer_ else as.integer(rules$host_reserved_capacity) - reserved_used,
    playoff_places_total = as.integer(rules$playoff_places),
    remaining_playoff_places = if (is.na(reserved_used)) NA_integer_ else as.integer(rules$playoff_places) - reserved_used,
    direct_group_winners = as.integer(nrow(direct_rows)),
    best_runner_ups = as.integer(nrow(selected_runner_ups)),
    remaining_runner_ups = as.integer(nrow(remaining_runner_ups)),
    best_runner_up_status = best_runner_up_status,
    conservation_status = if (host_count_known && reserved_used <= rules$host_reserved_capacity) "conserved" else "unresolved",
    double_counting_status = if (host_count_known && sum(host_slots$consumes_capacity %in% TRUE) == reserved_used) "none" else "unresolved"
  )
  list(
    allocation_id = allocation_id,
    scenario_id = scenario_id,
    scenario_status = scenario_status,
    status = if (scenario_status == "resolved" && isTRUE(draw_validation$valid)) "resolved" else "scenario_preserved",
    source_bundle_id = source_bundle_id,
    source_artifact_id = source_artifact_id,
    ruleset_version = rules$ruleset_version,
    ruleset_sha256 = uefa_euro_ruleset_sha256(rules),
    qualification_ledger = ledger,
    host_slots = host_slots,
    topology = topology,
    capacity = capacity,
    direct_qualifiers = direct_rows,
    best_runner_ups = selected_runner_ups,
    remaining_playoff_entries = remaining_runner_ups,
    draw_conditions = draw_validation,
    host_selection = host_selection
  )
}
