# Phase 16 EURO qualifying outcomes contract.
#
# This module owns the pure nine-file candidate, validation, lineage, and
# registered reader/writer boundary.  Phase 14 remains the state authority.

if (!exists("%||%", mode = "function", inherits = TRUE)) {
  `%||%` <- function(left, right) {
    if (is.null(left) || !length(left)) return(right)
    if (length(left) == 1L && is.na(left[[1L]])) return(right)
    left
  }
}

phase16_euro_edition_id <- function() {
  if (exists("uefa_euro_edition_id", mode = "function", inherits = TRUE)) {
    return(uefa_euro_edition_id())
  }
  "uefa_euro_2028_qualifying"
}

phase16_euro_outcomes_expected_inventory <- function() {
  file.path("outcomes", c(
    "competition_topology.csv", "stage_slots.csv", "projected_standings.csv",
    "projected_rankings.csv", "qualification_ledger.csv", "team_path_probabilities.csv",
    "fixture_forecast_form.csv", "simulation_metadata.csv", "outcomes_manifest.csv"
  ))
}

phase16_euro_outcomes_schema <- function() {
  list(
    competition_topology = c(
      "edition_id", "record_type", "league", "group_id", "display_name",
      "team_count", "fixture_count", "stage_id", "stage_type", "legs",
      "seed_policy", "different_group", "first_leg_home_policy",
      "tie_break_policy", "cancellation_condition", "topology_status",
      "source_bundle_id", "source_artifact_ids", "ruleset_version",
      "ruleset_sha256", "row_sha256"
    ),
    stage_slots = c(
      "edition_id", "stage_id", "stage_type", "stage_status", "leg_number",
      "participant_slot_home", "participant_slot_away", "home_team_id",
      "away_team_id", "source_fixture_id", "source_artifact_id",
      "projection_run_id", "draw_policy_id", "scheduled_at_utc",
      "regulation_home_goals", "regulation_away_goals", "extra_time_home_goals",
      "extra_time_away_goals", "penalty_shootout_home_goals",
      "penalty_shootout_away_goals", "final_home_goals", "final_away_goals",
      "completed_at_utc", "resolution_status", "unresolved_reason",
      "suppression_reason", "ruleset_version", "ruleset_sha256", "row_sha256"
    ),
    projected_standings = c(
      "edition_id", "projection_run_id", "simulation_count", "league", "group_id",
      "team_id", "rank", "probability", "expected_points", "expected_goal_difference",
      "ranking_status", "source_bundle_id", "source_bundle_sha256", "ruleset_version",
      "ruleset_sha256", "simulation_seed", "row_sha256"
    ),
    projected_rankings = c(
      "edition_id", "projection_run_id", "ranking_scope", "league", "group_id",
      "team_id", "group_position", "interim_overall_rank", "final_overall_rank",
      "ranking_stage", "rank", "probability", "counted_match_ids", "excluded_match_ids",
      "ranking_status", "missing_rule_input", "suppression_reason", "ruleset_version",
      "ruleset_sha256", "simulation_seed", "row_sha256"
    ),
    qualification_ledger = c(
      "edition_id", "projection_run_id", "allocation_id", "scenario_id", "team_id",
      "group_id", "association_id", "host_slot_id", "stage", "place_type",
      "qualification_status", "consumes_capacity", "qualification_eligibility_status",
      "probability", "reason", "counted_match_ids", "excluded_match_ids",
      "tiebreak_evidence_ids", "source_bundle_id", "source_bundle_sha256",
      "source_artifact_id", "model_release_id", "model_data_cutoff", "ruleset_version",
      "ruleset_sha256", "simulation_seed", "simulation_count", "row_sha256"
    ),
    team_path_probabilities = c(
      "edition_id", "projection_run_id", "scenario_id", "path_id", "team_id",
      "probability", "qualification_status", "status", "reason", "source_bundle_id",
      "source_bundle_sha256", "ruleset_version", "ruleset_sha256", "model_release_id",
      "model_data_cutoff", "state_manifest_sha256", "simulation_seed", "simulation_count",
      "row_sha256"
    ),
    fixture_forecast_form = c(
      "edition_id", "fixture_id", "forecast_status", "suppression_reason",
      "primary_probability_view", "p_home", "p_draw", "p_away",
      "expected_home_goals", "expected_away_goals", "model_id", "model_sha256",
      "model_release_id", "release_manifest_sha256", "release_selector_sha256",
      "model_data_cutoff", "model_data_cutoff_sha256", "feature_cutoff_utc",
      "feature_cutoff_sha256", "competition_form_status", "competition_form_window_type",
      "competition_form_window_size", "competition_form_cutoff_utc",
      "competition_form_sha256", "all_international_form_status",
      "all_international_form_window_type", "all_international_form_window_size",
      "all_international_form_cutoff_utc", "all_international_form_sha256",
      "source_bundle_id", "source_bundle_sha256", "parent_state_manifest_sha256",
      "parent_canonical_matches_sha256", "parent_forecast_status_sha256",
      "parent_forecasts_sha256", "parent_score_distributions_sha256", "row_sha256"
    ),
    simulation_metadata = c(
      "edition_id", "projection_run_id", "status", "reason", "scenario_id",
      "scenario_status", "simulation_seed", "simulation_count",
      "probability_sampling_policy", "scoreline_conditioning_policy",
      "penalty_resolution_policy", "draw_policy_id", "draw_policy_sha256",
      "ruleset_version", "ruleset_sha256", "source_bundle_id", "source_bundle_sha256",
      "state_manifest_sha256", "forecast_status_sha256", "forecasts_sha256",
      "score_distributions_sha256", "model_release_id", "release_manifest_sha256",
      "release_selector_sha256", "model_data_cutoff", "feature_cutoff_sha256",
      "generated_at_utc", "output_sha256", "row_sha256"
    ),
    outcomes_manifest = c(
      "edition_id", "artifact_path", "artifact_type", "row_count", "content_sha256",
      "row_sha256", "parent_paths", "parent_sha256", "source_bundle_id",
      "source_bundle_sha256", "source_artifact_ids", "model_release_id",
      "release_manifest_sha256", "release_selector_sha256", "model_id", "model_sha256",
      "calibrator_id", "calibrator_sha256", "model_data_cutoff", "feature_cutoff_sha256",
      "ruleset_version", "ruleset_sha256", "draw_policy_id", "draw_policy_sha256",
      "simulation_seed", "simulation_count", "projection_run_id", "warnings",
      "failure_reason", "validation_status", "generated_at_utc", "manifest_sha256"
    )
  )
}

phase16_euro_empty_table <- function(schema) {
  output <- as.data.frame(setNames(lapply(schema, function(field) character()), schema), stringsAsFactors = FALSE, check.names = FALSE)
  row.names(output) <- integer()
  output
}

# This signature is deliberately compatible with the scalar helper in the
# rules module, which accepts an atomic vector and an optional fallback.
phase16_euro_scalar <- function(data, field = NULL, default = "", aliases = character()) {
  if (!is.data.frame(data) && !is.list(data)) {
    value <- data
    fallback <- if (!is.null(field) && length(field)) as.character(field[[1L]]) else default
    if (!length(value) || is.na(value[[1L]]) || !nzchar(trimws(as.character(value[[1L]])))) return(fallback)
    return(as.character(value[[1L]]))
  }
  if (is.null(field)) {
    value <- data
    if (is.list(value) && !is.null(value[[1L]])) value <- value[[1L]]
    if (!length(value) || is.na(value[[1L]]) || !nzchar(trimws(as.character(value[[1L]])))) return(default)
    return(as.character(value[[1L]]))
  }
  fields <- unique(c(field, aliases))
  if (is.data.frame(data)) {
    found <- fields[fields %in% names(data)]
    value <- if (length(found)) data[[found[[1L]]]] else default
  } else {
    found <- fields[fields %in% names(data)]
    value <- if (length(found)) data[[found[[1L]]]] else default
  }
  if (!length(value) || is.na(value[[1L]]) || !nzchar(trimws(as.character(value[[1L]])))) return(default)
  as.character(value[[1L]])
}

phase16_euro_field <- function(data, field, n = if (is.data.frame(data)) nrow(data) else 0L, default = "", aliases = character()) {
  if (is.null(data)) return(rep(default, n))
  fields <- unique(c(field, aliases))
  found <- fields[fields %in% names(data)]
  value <- if (length(found)) data[[found[[1L]]]] else rep(default, n)
  if (!length(value)) return(rep(default, n))
  if (length(value) == 1L && n > 1L) value <- rep(value, n)
  value
}

phase16_euro_text <- function(value, default = "") {
  if (is.null(value) || !length(value) || is.na(value[[1L]])) return(default)
  value <- trimws(as.character(value[[1L]]))
  if (nzchar(value)) value else default
}

phase16_euro_sha256 <- function(value, serialize = FALSE) {
  if (!requireNamespace("digest", quietly = TRUE)) stop("digest is required for EURO outcome hashes", call. = FALSE)
  if (is.raw(value)) return(tolower(digest::digest(value, algo = "sha256", serialize = FALSE)))
  tolower(digest::digest(value, algo = "sha256", serialize = serialize))
}

phase16_euro_canonical_scalar <- function(value) {
  if (!length(value) || is.na(value[[1L]])) return("")
  if (is.logical(value)) return(ifelse(value[[1L]], "true", "false"))
  value <- as.character(value[[1L]])
  if (value %in% c("TRUE", "FALSE", "True", "False", "true", "false")) return(tolower(value))
  value
}

phase16_euro_row_hashes <- function(data) {
  if (!is.data.frame(data) || !nrow(data)) return(character())
  fields <- setdiff(names(data), "row_sha256")
  vapply(seq_len(nrow(data)), function(index) {
    phase16_euro_sha256(paste(vapply(data[index, fields, drop = FALSE], phase16_euro_canonical_scalar, character(1)), collapse = "|"))
  }, character(1))
}

phase16_euro_add_row_hashes <- function(data) {
  if (!is.data.frame(data)) stop("EURO outcome must be a data frame", call. = FALSE)
  if (!"row_sha256" %in% names(data)) stop("EURO outcome requires row_sha256", call. = FALSE)
  data$row_sha256 <- ""
  data$row_sha256 <- phase16_euro_row_hashes(data)
  row.names(data) <- NULL
  data
}

phase16_euro_csv_bytes <- function(data) {
  canonical <- as.data.frame(lapply(data, function(column) {
    values <- vapply(column, phase16_euro_canonical_scalar, character(1))
    values[!nzchar(values)] <- NA_character_
    values
  }), stringsAsFactors = FALSE, check.names = FALSE)
  path <- tempfile("phase16-euro-outcomes-", fileext = ".csv")
  on.exit(if (file.exists(path)) unlink(path), add = TRUE)
  utils::write.csv(canonical, path, row.names = FALSE, na = "", quote = TRUE)
  readBin(path, what = "raw", n = file.info(path)$size)
}

phase16_euro_table_content_hash <- function(data) phase16_euro_sha256(phase16_euro_csv_bytes(data))

phase16_euro_require_schema <- function(data, schema, name) {
  if (!is.data.frame(data) || !identical(names(data), schema)) {
    stop("EURO ", name, " schema mismatch; expected exact columns", call. = FALSE)
  }
  invisible(data)
}

phase16_euro_assert_hash <- function(value, name, allow_empty = FALSE) {
  value <- as.character(value)
  if (allow_empty && all(is.na(value) | !nzchar(trimws(value)))) return(invisible(TRUE))
  if (any(is.na(value) | !grepl("^[0-9a-fA-F]{64}$", value))) {
    stop("EURO ", name, " must contain SHA-256 hashes", call. = FALSE)
  }
  invisible(TRUE)
}

phase16_euro_artifact_key <- function(path) sub("^outcomes/", "", gsub("\\\\", "/", as.character(path)))

phase16_euro_lineage_value <- function(primary, fallback, field, default = "") {
  value <- phase16_euro_text(primary[[field]] %||% NULL, "")
  if (nzchar(value)) return(value)
  value <- phase16_euro_text(fallback[[field]] %||% NULL, "")
  if (nzchar(value)) value else default
}

phase16_euro_hash_or_derive <- function(value, label) {
  value <- phase16_euro_text(value, "")
  if (grepl("^[0-9a-fA-F]{64}$", value)) return(tolower(value))
  phase16_euro_sha256(label)
}

phase16_euro_activation_view <- function(activation) {
  if (!is.list(activation)) return(list(status = "unavailable", reason = "activation_missing", resources = list()))
  resources <- activation$resources %||% activation$accepted_tables %||% list()
  if (!is.list(resources)) resources <- list()
  for (field in c("teams", "groups", "fixtures", "standings", "results", "status")) {
    if (is.null(resources[[field]]) && !is.null(activation[[field]])) resources[[field]] <- activation[[field]]
  }
  status <- tolower(phase16_euro_text(activation$activation_status, ""))
  if (!nzchar(status)) status <- tolower(phase16_euro_text(activation$status, ""))
  if (status %in% c("active-after-draw", "scheduled", "in_progress", "in-progress", "active")) status <- "active"
  if (status %in% c("pre-draw", "pre_draw")) status <- "pre_draw"
  if (!status %in% c("active", "pre_draw", "unavailable", "unresolved", "unsupported_topology", "revision_blocked")) {
    lifecycle <- tolower(phase16_euro_text(activation$lifecycle_state, ""))
    status <- if (lifecycle == "pre_draw" || tolower(phase16_euro_text(activation$forecast_status, "")) == "pre_draw") "pre_draw" else if (lifecycle %in% c("scheduled", "in_progress")) "active" else "unavailable"
  }
  list(
    status = status,
    reason = phase16_euro_text(activation$reason %||% activation$forecast_reason, if (status == "pre_draw") "awaiting_official_draw_and_schedule" else ""),
    edition_id = phase16_euro_text(activation$edition_id, phase16_euro_edition_id()),
    source_bundle_id = phase16_euro_text(activation$source_bundle_id %||% activation$manifest$source_bundle_id, ""),
    ruleset_version = phase16_euro_text(activation$ruleset_version %||% activation$manifest$ruleset_version, ""),
    lifecycle_state = if (status == "active") "scheduled" else status,
    forecast_status = if (status == "active") "available" else status,
    resources = resources,
    raw = activation,
    validation = activation$validation %||% activation
  )
}

phase16_euro_rules_lineage <- function(rules = NULL) {
  rules <- rules %||% if (exists("uefa_euro_2026_28_rules", mode = "function", inherits = TRUE)) uefa_euro_2026_28_rules() else list()
  version <- if (exists("uefa_euro_ruleset_version", mode = "function", inherits = TRUE)) uefa_euro_ruleset_version() else phase16_euro_text(rules$ruleset_version, "uefa-euro-2028-qualifying-v1")
  hash <- if (exists("uefa_euro_ruleset_sha256", mode = "function", inherits = TRUE)) uefa_euro_ruleset_sha256(rules) else phase16_euro_sha256(rules, serialize = TRUE)
  list(rules = rules, ruleset_version = version, ruleset_sha256 = tolower(hash))
}

phase16_validate_euro_activation <- function(...) {
  if (!exists("validate_euro_activation", mode = "function", inherits = TRUE)) {
    return(list(valid = FALSE, activation_status = "unavailable", reason = "EURO activation validator is not loaded", failure_reason = "EURO activation validator is not loaded"))
  }
  validate_euro_activation(...)
}

phase16_euro_normalize_inputs <- function(activation, source_lineage, model_lineage) {
  view <- phase16_euro_activation_view(activation)
  source_lineage <- source_lineage %||% list()
  model_lineage <- model_lineage %||% list()
  source <- if (is.list(activation)) activation[["source_bundle"]] %||% list() else list()
  source$edition_id <- view$edition_id
  source$source_bundle_id <- phase16_euro_lineage_value(source_lineage, view, "source_bundle_id", view$source_bundle_id)
  source$bundle_id <- source$source_bundle_id
  source$source_bundle_sha256 <- phase16_euro_lineage_value(source_lineage, view$raw$manifest %||% list(), "source_bundle_sha256", phase16_euro_hash_or_derive(source$source_bundle_id, "source bundle"))
  source$source_artifact_ids <- phase16_euro_lineage_value(source_lineage, view$raw$manifest %||% list(), "source_artifact_ids", "")
  source$source_artifact_paths <- phase16_euro_lineage_value(source_lineage, view$raw$manifest %||% list(), "source_artifact_paths", "")
  source$source_manifest_path <- phase16_euro_lineage_value(source_lineage, view$raw$manifest %||% list(), "source_manifest_path", "data/competition/accepted/uefa_euro_2028_qualifying/source_bundle_manifest.csv")
  source$groups <- view$resources$groups %||% data.frame(stringsAsFactors = FALSE)
  source$teams <- view$resources$teams %||% data.frame(stringsAsFactors = FALSE)
  source$fixtures <- view$resources$fixtures %||% data.frame(stringsAsFactors = FALSE)
  source$standings <- view$resources$standings %||% data.frame(stringsAsFactors = FALSE)
  source$results <- view$resources$results %||% data.frame(stringsAsFactors = FALSE)
  source$manifest <- view$raw$manifest %||% source$manifest
  list(view = view, source = source, source_lineage = source_lineage, model_lineage = model_lineage)
}

phase16_euro_empty_state <- function(activation, lineage) {
  view <- phase16_euro_activation_view(activation)
  fixtures <- view$resources$fixtures %||% data.frame(stringsAsFactors = FALSE)
  list(
    edition_id = view$edition_id,
    state_manifest = data.frame(stringsAsFactors = FALSE),
    state_manifest_sha256 = phase16_euro_hash_or_derive(lineage$state_manifest_sha256, "phase14 state manifest"),
    model_release_id = lineage$model_release_id %||% "",
    canonical_matches = fixtures,
    forecast_status = data.frame(stringsAsFactors = FALSE),
    forecasts = data.frame(stringsAsFactors = FALSE),
    competition_form = data.frame(stringsAsFactors = FALSE),
    all_international_form = data.frame(stringsAsFactors = FALSE),
    score_distributions = data.frame(stringsAsFactors = FALSE),
    parent_graph = list()
  )
}

phase16_euro_map_table <- function(input, schema, common = list(), aliases = list()) {
  if (!is.data.frame(input) || !nrow(input)) return(phase16_euro_empty_table(schema))
  output <- phase16_euro_empty_table(schema)
  output <- output[rep(1L, nrow(input)), , drop = FALSE]
  for (field in setdiff(schema, "row_sha256")) {
    candidates <- c(field, aliases[[field]] %||% character())
    candidates <- candidates[candidates %in% names(input)]
    if (length(candidates)) output[[field]] <- input[[candidates[[1L]]]]
  }
  for (field in intersect(names(common), names(output))) {
    value <- common[[field]]
    if (length(value)) output[[field]] <- rep(value, length.out = nrow(output))
  }
  output
}

phase16_euro_build_topology <- function(view, simulation, source, rules_lineage, status) {
  schema <- phase16_euro_outcomes_schema()$competition_topology
  if (!identical(status, "active")) return(phase16_euro_empty_table(schema))
  topology <- simulation$topology %||% simulation$allocation$topology %||% NULL
  if (is.list(topology)) topology <- topology$stage_topology %||% topology$topology %||% topology$groups
  groups <- source$groups
  if (!is.data.frame(groups) || !nrow(groups)) return(phase16_euro_empty_table(schema))
  teams <- source$teams
  fixtures <- source$fixtures
  group_field <- if ("group_id" %in% names(groups)) "group_id" else if ("source_group_id" %in% names(groups)) "source_group_id" else NULL
  if (is.null(group_field)) return(phase16_euro_empty_table(schema))
  team_group_field <- if (is.data.frame(teams) && "group_id" %in% names(teams)) "group_id" else NULL
  fixture_group_field <- if (is.data.frame(fixtures) && "group_id" %in% names(fixtures)) "group_id" else NULL
  group_ids <- unique(as.character(groups[[group_field]]))
  rows <- lapply(group_ids, function(group_id) {
    group <- groups[as.character(groups[[group_field]]) == group_id, , drop = FALSE]
    row <- phase16_euro_empty_table(schema)
    team_count <- if (!is.null(team_group_field)) sum(as.character(teams[[team_group_field]]) == group_id, na.rm = TRUE) else as.integer(phase16_euro_scalar(group, "team_count", ""))
    fixture_count <- if (!is.null(fixture_group_field)) sum(as.character(fixtures[[fixture_group_field]]) == group_id, na.rm = TRUE) else 0L
    row[1L, ] <- list(
      phase16_euro_edition_id(), "group", phase16_euro_scalar(group, "league"), group_id,
      phase16_euro_scalar(group, "display_name", aliases = c("group_label", "name")),
      team_count, fixture_count, "group-stage", "group", 2L,
      "official_draw", "", "official_schedule", phase16_euro_scalar(group, "tie_break_policy", "uefa_rules"),
      "none", "official", source$source_bundle_id, phase16_euro_scalar(group, "source_artifact_id"),
      rules_lineage$ruleset_version, rules_lineage$ruleset_sha256, ""
    )
    row
  })
  output <- do.call(rbind, rows)
  if (is.data.frame(topology) && nrow(topology) && "stage_id" %in% names(topology)) {
    stage_rows <- lapply(seq_len(nrow(topology)), function(index) {
      item <- topology[index, , drop = FALSE]
      row <- phase16_euro_empty_table(schema)
      row[1L, ] <- list(
        phase16_euro_edition_id(), "stage", phase16_euro_scalar(item, "league"), phase16_euro_scalar(item, "group_id"),
        phase16_euro_scalar(item, "display_name"), phase16_euro_scalar(item, "team_count", 0L), phase16_euro_scalar(item, "fixture_count", 0L),
        phase16_euro_scalar(item, "stage_id"), phase16_euro_scalar(item, "stage_type"), phase16_euro_scalar(item, "legs", 1L),
        phase16_euro_scalar(item, "seed_policy"), phase16_euro_scalar(item, "different_group"), phase16_euro_scalar(item, "first_leg_home_policy"),
        phase16_euro_scalar(item, "tie_break_policy", "uefa_rules"), phase16_euro_scalar(item, "cancellation_condition", "none"),
        phase16_euro_scalar(item, "topology_status", "resolved"), source$source_bundle_id,
        phase16_euro_scalar(item, "source_artifact_ids", phase16_euro_scalar(item, "source_artifact_id")),
        rules_lineage$ruleset_version, rules_lineage$ruleset_sha256, ""
      )
      row
    })
    output <- rbind(output, do.call(rbind, stage_rows))
  }
  phase16_euro_add_row_hashes(output)
}

phase16_euro_build_stage_slots <- function(view, simulation, source, rules_lineage, common, status) {
  schema <- phase16_euro_outcomes_schema()$stage_slots
  if (!identical(status, "active")) return(phase16_euro_empty_table(schema))
  fixtures <- source$fixtures
  rows <- if (is.data.frame(fixtures) && nrow(fixtures)) lapply(seq_len(nrow(fixtures)), function(index) {
    item <- fixtures[index, , drop = FALSE]
    row <- phase16_euro_empty_table(schema)
    row[1L, ] <- list(
      phase16_euro_edition_id(), phase16_euro_scalar(item, "stage_id", "group-stage"), "group", "official", 1L,
      phase16_euro_scalar(item, "home_slot", phase16_euro_scalar(item, "slot")),
      phase16_euro_scalar(item, "away_slot"), phase16_euro_scalar(item, "home_team_id"),
      phase16_euro_scalar(item, "away_team_id"), phase16_euro_scalar(item, "fixture_id"),
      phase16_euro_scalar(item, "source_artifact_id"), common$projection_run_id, common$draw_policy_id,
      phase16_euro_scalar(item, "confirmed_kickoff_at_utc", phase16_euro_scalar(item, "scheduled_at_utc")),
      NA_integer_, NA_integer_, NA_integer_, NA_integer_, NA_integer_, NA_integer_, NA_integer_, NA_integer_, "",
      "official", "", "", rules_lineage$ruleset_version, rules_lineage$ruleset_sha256, ""
    )
    row
  }) else list()
  if (!length(rows) && is.data.frame(simulation$stage_slots) && nrow(simulation$stage_slots)) {
    rows <- lapply(seq_len(nrow(simulation$stage_slots)), function(index) {
      item <- simulation$stage_slots[index, , drop = FALSE]
      row <- phase16_euro_empty_table(schema)
      row[1L, ] <- list(
        phase16_euro_edition_id(), phase16_euro_scalar(item, "stage_id"), phase16_euro_scalar(item, "stage_type", "group"),
        "projected", phase16_euro_scalar(item, "leg_number", 1L), phase16_euro_scalar(item, "participant_slot_home", phase16_euro_scalar(item, "slot_id")),
        phase16_euro_scalar(item, "participant_slot_away"), phase16_euro_scalar(item, "home_team_id"), phase16_euro_scalar(item, "away_team_id"),
        "", "", common$projection_run_id, common$draw_policy_id, phase16_euro_scalar(item, "scheduled_at_utc"),
        NA_integer_, NA_integer_, NA_integer_, NA_integer_, NA_integer_, NA_integer_, NA_integer_, NA_integer_, "",
        "projected", phase16_euro_scalar(item, "unresolved_reason"), phase16_euro_scalar(item, "suppression_reason"),
        rules_lineage$ruleset_version, rules_lineage$ruleset_sha256, ""
      )
      row
    })
  }
  if (!length(rows)) return(phase16_euro_empty_table(schema))
  phase16_euro_add_row_hashes(do.call(rbind, rows))
}

phase16_euro_build_fixture_form <- function(view, state, source, model_lineage, status) {
  schema <- phase16_euro_outcomes_schema()$fixture_forecast_form
  if (identical(status, "pre_draw") || !is.data.frame(source$fixtures) || !nrow(source$fixtures)) return(phase16_euro_empty_table(schema))
  forecasts <- state$forecasts %||% data.frame(stringsAsFactors = FALSE)
  forecast_status <- state$forecast_status %||% data.frame(stringsAsFactors = FALSE)
  state_manifest <- state$state_manifest %||% data.frame(stringsAsFactors = FALSE)
  rows <- lapply(seq_len(nrow(source$fixtures)), function(index) {
    fixture <- source$fixtures[index, , drop = FALSE]
    fixture_id <- phase16_euro_scalar(fixture, "fixture_id", phase16_euro_scalar(fixture, "match_id"))
    f <- if (is.data.frame(forecasts) && "fixture_id" %in% names(forecasts)) forecasts[as.character(forecasts$fixture_id) == fixture_id, , drop = FALSE] else data.frame(stringsAsFactors = FALSE)
    s <- if (is.data.frame(forecast_status) && "fixture_id" %in% names(forecast_status)) forecast_status[as.character(forecast_status$fixture_id) == fixture_id, , drop = FALSE] else data.frame(stringsAsFactors = FALSE)
    available <- identical(tolower(phase16_euro_scalar(s, "forecast_status", phase16_euro_scalar(f, "forecast_status", "unavailable"))), "available")
    row <- phase16_euro_empty_table(schema)
    row[1L, ] <- list(
      phase16_euro_edition_id(), fixture_id, if (available) "available" else "unavailable",
      if (available) "none" else phase16_euro_scalar(s, "suppression_reason", "forecast_input_unavailable"),
      phase16_euro_scalar(f, "primary_probability_view"), if (available) phase16_euro_field(f, "p_home", 1L, NA_real_) else NA_real_,
      if (available) phase16_euro_field(f, "p_draw", 1L, NA_real_) else NA_real_, if (available) phase16_euro_field(f, "p_away", 1L, NA_real_) else NA_real_,
      if (available) phase16_euro_field(f, "expected_home_goals", 1L, NA_real_) else NA_real_, if (available) phase16_euro_field(f, "expected_away_goals", 1L, NA_real_) else NA_real_,
      phase16_euro_scalar(f, "model_id", model_lineage$model_id %||% ""), phase16_euro_scalar(f, "model_sha256", model_lineage$model_sha256 %||% ""),
      phase16_euro_scalar(f, "model_release_id", model_lineage$model_release_id %||% ""), phase16_euro_scalar(f, "release_manifest_sha256", model_lineage$release_manifest_sha256 %||% ""),
      phase16_euro_scalar(f, "release_selector_sha256", model_lineage$release_selector_sha256 %||% ""), phase16_euro_scalar(f, "model_data_cutoff", model_lineage$model_data_cutoff %||% ""),
      phase16_euro_hash_or_derive(phase16_euro_scalar(f, "model_data_cutoff", model_lineage$model_data_cutoff %||% ""), "model cutoff"),
      phase16_euro_scalar(f, "feature_cutoff_utc"), phase16_euro_hash_or_derive(phase16_euro_scalar(f, "feature_cutoff_utc"), "feature cutoff"),
      "unavailable", "", "", "", "", "unavailable", "", "", "", "", source$source_bundle_id,
      phase16_euro_hash_or_derive(source$source_bundle_sha256, "source bundle"),
      phase16_euro_hash_or_derive(phase16_euro_scalar(state, "state_manifest_sha256"), "state manifest"),
      phase16_euro_hash_or_derive(phase16_euro_scalar(state_manifest, "canonical_matches_sha256"), "canonical matches"),
      phase16_euro_hash_or_derive(phase16_euro_scalar(state_manifest, "forecast_status_sha256"), "forecast status"),
      phase16_euro_hash_or_derive(phase16_euro_scalar(state_manifest, "forecasts_sha256"), "forecasts"),
      phase16_euro_hash_or_derive(phase16_euro_scalar(state_manifest, "score_distributions_sha256"), "score distributions"), ""
    )
    row
  })
  phase16_euro_add_row_hashes(do.call(rbind, rows))
}

phase16_euro_build_metadata <- function(simulation, view, source, state, rules_lineage, model_lineage, status, reason, generated_at_utc, common) {
  schema <- phase16_euro_outcomes_schema()$simulation_metadata
  input <- if (is.list(simulation)) simulation$simulation_metadata %||% simulation$metadata else NULL
  if (is.list(input) && !is.data.frame(input)) input <- as.data.frame(input, stringsAsFactors = FALSE, check.names = FALSE)
  output <- phase16_euro_empty_table(schema)
  output <- output[rep(1L, 1L), , drop = FALSE]
  if (is.data.frame(input) && nrow(input)) {
    for (field in setdiff(schema, "row_sha256")) if (field %in% names(input)) output[[field]] <- input[[field]][[1L]]
  }
  output$edition_id <- phase16_euro_edition_id()
  output$projection_run_id <- common$projection_run_id
  output$status <- status
  output$reason <- reason
  output$scenario_id <- phase16_euro_scalar(output, "scenario_id", phase16_euro_scalar(simulation$scenario_id, ""))
  output$scenario_status <- phase16_euro_scalar(output, "scenario_status", phase16_euro_scalar(simulation$scenario_status, status))
  output$simulation_seed <- common$simulation_seed
  output$simulation_count <- common$simulation_count
  output$ruleset_version <- rules_lineage$ruleset_version
  output$ruleset_sha256 <- rules_lineage$ruleset_sha256
  output$source_bundle_id <- source$source_bundle_id
  output$source_bundle_sha256 <- phase16_euro_hash_or_derive(source$source_bundle_sha256, "source bundle")
  output$state_manifest_sha256 <- state$state_manifest_sha256
  output$model_release_id <- model_lineage$model_release_id %||% state$model_release_id %||% ""
  for (field in c("release_manifest_sha256", "release_selector_sha256", "model_data_cutoff", "feature_cutoff_sha256", "draw_policy_id", "draw_policy_sha256", "probability_sampling_policy", "scoreline_conditioning_policy", "penalty_resolution_policy")) {
    if (field %in% names(model_lineage) && !nzchar(phase16_euro_scalar(output, field))) output[[field]] <- model_lineage[[field]]
  }
  output$generated_at_utc <- generated_at_utc %||% ""
  output$output_sha256 <- phase16_euro_hash_or_derive(simulation$output_hashes %||% NULL, "simulation output")
  phase16_euro_add_row_hashes(output)
}

phase16_euro_parent_graph <- function(source, state, rules_lineage, model_lineage, metadata) {
  hash <- function(value, label) phase16_euro_hash_or_derive(value, label)
  list(
    phase14_state_manifest = list(path = "audit/state_manifest.csv", sha256 = hash(state$state_manifest_sha256, "phase14 state manifest")),
    phase14_forecast_status = list(path = "state/forecast_status.csv", sha256 = hash(model_lineage$forecast_status_sha256, "forecast status")),
    phase14_forecasts = list(path = "state/forecasts.csv", sha256 = hash(model_lineage$forecasts_sha256, "forecasts")),
    phase14_score_distributions = list(path = "local/score_distributions.rds", sha256 = hash(model_lineage$score_distributions_sha256, "score distributions")),
    phase14_canonical_matches = list(path = "state/canonical_matches.csv", sha256 = hash(model_lineage$canonical_matches_sha256, "canonical matches")),
    source_bundle_manifest = list(path = source$source_manifest_path %||% "data/competition/accepted/uefa_euro_2028_qualifying/source_bundle_manifest.csv", sha256 = hash(model_lineage$artifact_manifest_sha256, "source bundle manifest")),
    source_bundle = list(path = "data/competition/registries/source_bundles.csv", sha256 = hash(source$source_bundle_sha256, "source bundle")),
    ruleset = list(path = "rules/uefa_euro_2026_28_rules", sha256 = hash(rules_lineage$ruleset_sha256, "ruleset")),
    model_release = list(path = "outputs/releases/approved_release.csv", sha256 = hash(model_lineage$release_manifest_sha256, "model release")),
    model = list(path = "outputs/releases/model_manifest.csv", sha256 = hash(model_lineage$model_sha256, "model")),
    calibrator = list(path = "outputs/releases/model_manifest.csv", sha256 = hash(model_lineage$calibrator_sha256, "calibrator")),
    simulation_metadata = list(path = "outcomes/simulation_metadata.csv", sha256 = hash(phase16_euro_table_content_hash(metadata), "simulation metadata"))
  )
}

phase16_euro_manifest_lineage <- function(candidate) {
  lineage <- candidate$lineage %||% list()
  first <- if (is.data.frame(candidate$state_manifest) && nrow(candidate$state_manifest)) candidate$state_manifest[1L, , drop = FALSE] else list()
  get <- function(field, default = "") phase16_euro_lineage_value(lineage, first, field, default)
  list(
    source_bundle_id = get("source_bundle_id", candidate$source$source_bundle_id %||% ""),
    source_bundle_sha256 = phase16_euro_hash_or_derive(get("source_bundle_sha256", candidate$source$source_bundle_sha256), "source bundle"),
    source_artifact_ids = get("source_artifact_ids"), model_release_id = get("model_release_id"),
    release_manifest_sha256 = phase16_euro_hash_or_derive(get("release_manifest_sha256"), "release manifest"),
    release_selector_sha256 = phase16_euro_hash_or_derive(get("release_selector_sha256"), "release selector"),
    model_id = get("model_id"), model_sha256 = phase16_euro_hash_or_derive(get("model_sha256"), "model"),
    calibrator_id = get("calibrator_id"), calibrator_sha256 = phase16_euro_hash_or_derive(get("calibrator_sha256"), "calibrator"),
    model_data_cutoff = get("model_data_cutoff"), feature_cutoff_sha256 = phase16_euro_hash_or_derive(get("feature_cutoff_sha256"), "feature cutoff"),
    ruleset_version = candidate$ruleset_version, ruleset_sha256 = candidate$ruleset_sha256,
    draw_policy_id = candidate$draw_policy_id %||% "", draw_policy_sha256 = phase16_euro_hash_or_derive(candidate$draw_policy_sha256, "draw policy"),
    simulation_seed = candidate$simulation_seed %||% "", simulation_count = candidate$simulation_count %||% "",
    projection_run_id = candidate$projection_run_id %||% "", generated_at_utc = candidate$generated_at_utc %||% ""
  )
}

phase16_euro_manifest_parent_keys <- function(key) {
  switch(key,
    competition_topology = c("source_bundle_manifest", "ruleset"),
    stage_slots = c("source_bundle_manifest", "ruleset", "simulation_metadata"),
    projected_standings = c("phase14_state_manifest", "source_bundle_manifest", "ruleset", "simulation_metadata"),
    projected_rankings = c("phase14_state_manifest", "source_bundle_manifest", "ruleset", "simulation_metadata"),
    qualification_ledger = c("phase14_state_manifest", "source_bundle_manifest", "ruleset", "model_release", "simulation_metadata"),
    team_path_probabilities = c("phase14_state_manifest", "source_bundle_manifest", "ruleset", "model_release", "simulation_metadata"),
    fixture_forecast_form = c("phase14_state_manifest", "phase14_forecast_status", "phase14_forecasts", "source_bundle_manifest"),
    simulation_metadata = c("phase14_state_manifest", "source_bundle_manifest", "ruleset", "model_release"),
    character()
  )
}

phase16_euro_manifest_rows <- function(candidate, artifacts) {
  schema <- phase16_euro_outcomes_schema()$outcomes_manifest
  lineage <- phase16_euro_manifest_lineage(candidate)
  graph <- candidate$parent_graph
  table_paths <- setdiff(phase16_euro_outcomes_expected_inventory(), "outcomes/outcomes_manifest.csv")
  rows <- lapply(table_paths, function(path) {
    key <- sub("\\.csv$", "", phase16_euro_artifact_key(path))
    keys <- phase16_euro_manifest_parent_keys(key)
    parents <- graph[keys]
    parent_paths <- vapply(parents, function(value) value$path, character(1))
    parent_hashes <- vapply(parents, function(value) value$sha256, character(1))
    as.data.frame(as.list(c(
      edition_id = phase16_euro_edition_id(), artifact_path = path, artifact_type = "csv",
      row_count = nrow(artifacts[[path]]), content_sha256 = phase16_euro_table_content_hash(artifacts[[path]]), row_sha256 = "",
      parent_paths = paste(parent_paths, collapse = "|"), parent_sha256 = paste(parent_hashes, collapse = "|"),
      source_bundle_id = lineage$source_bundle_id, source_bundle_sha256 = lineage$source_bundle_sha256,
      source_artifact_ids = lineage$source_artifact_ids, model_release_id = lineage$model_release_id,
      release_manifest_sha256 = lineage$release_manifest_sha256, release_selector_sha256 = lineage$release_selector_sha256,
      model_id = lineage$model_id, model_sha256 = lineage$model_sha256, calibrator_id = lineage$calibrator_id,
      calibrator_sha256 = lineage$calibrator_sha256, model_data_cutoff = lineage$model_data_cutoff,
      feature_cutoff_sha256 = lineage$feature_cutoff_sha256, ruleset_version = lineage$ruleset_version,
      ruleset_sha256 = lineage$ruleset_sha256, draw_policy_id = lineage$draw_policy_id,
      draw_policy_sha256 = lineage$draw_policy_sha256, simulation_seed = lineage$simulation_seed,
      simulation_count = lineage$simulation_count, projection_run_id = lineage$projection_run_id,
      warnings = if (candidate$candidate_status %in% c("active", "pre_draw")) "none" else candidate$reason,
      failure_reason = if (candidate$candidate_status %in% c("active", "pre_draw")) "" else candidate$reason,
      validation_status = "valid", generated_at_utc = lineage$generated_at_utc, manifest_sha256 = ""
    )), stringsAsFactors = FALSE, check.names = FALSE)
  })
  manifest <- do.call(rbind, rows)
  self <- as.data.frame(as.list(setNames(rep("", length(schema)), schema)), stringsAsFactors = FALSE, check.names = FALSE)
  self$edition_id <- phase16_euro_edition_id(); self$artifact_path <- "outcomes/outcomes_manifest.csv"; self$artifact_type <- "csv"; self$validation_status <- "valid"; self$generated_at_utc <- lineage$generated_at_utc
  for (field in c("source_bundle_id", "source_bundle_sha256", "source_artifact_ids", "model_release_id", "release_manifest_sha256", "release_selector_sha256", "model_id", "model_sha256", "calibrator_id", "calibrator_sha256", "model_data_cutoff", "feature_cutoff_sha256", "ruleset_version", "ruleset_sha256", "draw_policy_id", "draw_policy_sha256", "simulation_seed", "simulation_count", "projection_run_id")) self[[field]] <- lineage[[field]]
  output <- rbind(manifest, self)
  output <- output[, schema, drop = FALSE]
  row.names(output) <- NULL
  output
}

phase16_euro_attach_manifest <- function(candidate) {
  artifacts <- candidate$artifacts
  base <- phase16_euro_manifest_rows(candidate, artifacts)
  self_index <- which(base$artifact_path == "outcomes/outcomes_manifest.csv")
  base$manifest_sha256 <- ""
  base$row_sha256 <- ""
  base$row_count[[self_index]] <- 0L
  base$content_sha256[[self_index]] <- ""
  manifest_hash <- phase16_euro_table_content_hash(base)
  base$manifest_sha256 <- manifest_hash
  base$row_count[[self_index]] <- nrow(base)
  base$content_sha256[[self_index]] <- manifest_hash
  base$row_sha256 <- phase16_euro_row_hashes(base)
  base <- base[, phase16_euro_outcomes_schema()$outcomes_manifest, drop = FALSE]
  candidate$artifacts[["outcomes/outcomes_manifest.csv"]] <- base
  candidate$outcomes_artifacts <- candidate$artifacts
  candidate$manifest <- base
  candidate$manifest_sha256 <- manifest_hash
  candidate
}

phase16_build_euro_outcomes_candidate <- function(
    simulation = NULL, rules = NULL, topology = NULL, source = NULL, stage_capture = NULL,
    state_bundle = NULL, project_root = ".", generated_at_utc = NULL,
    activation = NULL, source_lineage = NULL, model_lineage = NULL, incumbent = NULL) {
  normalized <- phase16_euro_normalize_inputs(activation %||% source, source_lineage, model_lineage)
  view <- normalized$view
  source <- if (is.list(source) && !is.null(source$source_bundle_id)) source else normalized$source
  source$source_bundle_id <- source$source_bundle_id %||% normalized$source$source_bundle_id
  source$source_bundle_sha256 <- source$source_bundle_sha256 %||% normalized$source$source_bundle_sha256
  lineage <- c(normalized$source_lineage, normalized$model_lineage)
  rules_lineage <- phase16_euro_rules_lineage(rules)
  if (is.null(state_bundle)) state_bundle <- phase16_euro_empty_state(activation %||% source, lineage)
  state <- state_bundle
  if (!is.list(state)) state <- phase16_euro_empty_state(activation %||% source, lineage)
  sim_status <- tolower(phase16_euro_text(simulation$status %||% simulation$scenario_status, ""))
  sim_reason <- phase16_euro_text(simulation$reason %||% simulation$suppression_reason, "")
  status <- view$status
  reason <- view$reason
  if (status == "active") {
    if (sim_status %in% c("unsupported_topology", "unsupported")) { status <- "unsupported_topology"; reason <- sim_reason %||% "unsupported_topology" }
    else if (sim_status %in% c("unresolved", "suppressed", "blocked")) { status <- "unresolved"; reason <- sim_reason %||% "external_eligibility_unresolved" }
    else if (is.null(simulation)) { status <- "unresolved"; reason <- "simulation_missing" }
  }
  if (view$status %in% c("unavailable", "unresolved", "unsupported_topology", "revision_blocked")) status <- view$status
  if (!nzchar(reason)) reason <- if (status == "active") "available" else status
  common <- list(
    edition_id = phase16_euro_edition_id(), projection_run_id = phase16_euro_scalar(simulation$projection_run_id, ""),
    simulation_seed = phase16_euro_scalar(simulation$simulation_seed, phase16_euro_scalar(simulation$seed, "")),
    simulation_count = phase16_euro_scalar(simulation$simulation_count, ""), draw_policy_id = phase16_euro_scalar(simulation$draw_policy_id, "")
  )
  competition_topology <- phase16_euro_build_topology(view, simulation %||% list(), source, rules_lineage, status)
  stage_slots <- phase16_euro_build_stage_slots(view, simulation %||% list(), source, rules_lineage, common, status)
  projected_standings <- phase16_euro_map_table(simulation$projected_standings, phase16_euro_outcomes_schema()$projected_standings, common)
  projected_rankings <- phase16_euro_map_table(simulation$projected_rankings, phase16_euro_outcomes_schema()$projected_rankings, common)
  if (nrow(projected_standings)) { projected_standings$edition_id <- phase16_euro_edition_id(); projected_standings <- phase16_euro_add_row_hashes(projected_standings) } else projected_standings <- phase16_euro_empty_table(phase16_euro_outcomes_schema()$projected_standings)
  if (nrow(projected_rankings)) { projected_rankings$edition_id <- phase16_euro_edition_id(); projected_rankings <- phase16_euro_add_row_hashes(projected_rankings) } else projected_rankings <- phase16_euro_empty_table(phase16_euro_outcomes_schema()$projected_rankings)
  ledger_input <- simulation$qualification_ledger %||% simulation$allocation$qualification_ledger %||% simulation$allocation$ledger
  paths_input <- simulation$team_path_probabilities %||% simulation$probabilities %||% simulation$qualification_probabilities
  qualification_ledger <- if (identical(status, "active")) phase16_euro_map_table(ledger_input, phase16_euro_outcomes_schema()$qualification_ledger, common, aliases = list(stage = "stage_id", qualification_eligibility_status = "eligibility_status", qualification_status = "status", reason = "suppression_reason")) else phase16_euro_empty_table(phase16_euro_outcomes_schema()$qualification_ledger)
  team_paths <- if (identical(status, "active")) phase16_euro_map_table(paths_input, phase16_euro_outcomes_schema()$team_path_probabilities, common, aliases = list(status = "path_status", reason = "suppression_reason")) else phase16_euro_empty_table(phase16_euro_outcomes_schema()$team_path_probabilities)
  if (nrow(qualification_ledger)) { qualification_ledger$edition_id <- phase16_euro_edition_id(); qualification_ledger$source_bundle_sha256 <- phase16_euro_hash_or_derive(source$source_bundle_sha256, "source bundle"); qualification_ledger$model_release_id <- normalized$model_lineage$model_release_id %||% ""; qualification_ledger$model_data_cutoff <- normalized$model_lineage$model_data_cutoff %||% ""; qualification_ledger$simulation_count <- common$simulation_count; qualification_ledger <- phase16_euro_add_row_hashes(qualification_ledger) }
  if (nrow(team_paths)) { team_paths$edition_id <- phase16_euro_edition_id(); team_paths$source_bundle_sha256 <- phase16_euro_hash_or_derive(source$source_bundle_sha256, "source bundle"); team_paths$model_release_id <- normalized$model_lineage$model_release_id %||% ""; team_paths$model_data_cutoff <- normalized$model_lineage$model_data_cutoff %||% ""; team_paths$state_manifest_sha256 <- phase16_euro_hash_or_derive(lineage$state_manifest_sha256, "phase14 state manifest"); team_paths$simulation_count <- common$simulation_count; team_paths <- phase16_euro_add_row_hashes(team_paths) }
  metadata <- phase16_euro_build_metadata(simulation %||% list(), view, source, state, rules_lineage, normalized$model_lineage, status, reason, generated_at_utc, common)
  graph <- phase16_euro_parent_graph(source, state, rules_lineage, normalized$model_lineage, metadata)
  artifacts <- list(
    "outcomes/competition_topology.csv" = competition_topology,
    "outcomes/stage_slots.csv" = stage_slots,
    "outcomes/projected_standings.csv" = projected_standings,
    "outcomes/projected_rankings.csv" = projected_rankings,
    "outcomes/qualification_ledger.csv" = qualification_ledger,
    "outcomes/team_path_probabilities.csv" = team_paths,
    "outcomes/fixture_forecast_form.csv" = phase16_euro_build_fixture_form(view, state, source, normalized$model_lineage, status),
    "outcomes/simulation_metadata.csv" = metadata
  )
  candidate <- list(
    edition_id = phase16_euro_edition_id(), candidate_status = status, activation_status = view$status,
    lifecycle_state = view$lifecycle_state, forecast_status = view$forecast_status, forecast_reason = reason,
    reason = reason, rules = rules_lineage$rules, ruleset_version = rules_lineage$ruleset_version,
    ruleset_sha256 = rules_lineage$ruleset_sha256, topology = topology %||% simulation$topology,
    source = source, activation = activation, activation_validation = view$validation,
    state_bundle = state, state_manifest = state$state_manifest, state_manifest_sha256 = state$state_manifest_sha256,
    source_lineage = normalized$source_lineage, model_lineage = normalized$model_lineage, lineage = lineage,
    simulation = simulation %||% list(), simulation_metadata = metadata, projection_run_id = common$projection_run_id,
    simulation_seed = common$simulation_seed, simulation_count = common$simulation_count,
    draw_policy_id = common$draw_policy_id, draw_policy_sha256 = phase16_euro_scalar(simulation$draw_policy_sha256, ""),
    parent_graph = graph, artifacts = artifacts, outcomes_artifacts = artifacts,
    generated_at_utc = generated_at_utc %||% ""
  )
  candidate$competition_topology <- artifacts[["outcomes/competition_topology.csv"]]
  candidate$stage_slots <- artifacts[["outcomes/stage_slots.csv"]]
  candidate$projected_standings <- artifacts[["outcomes/projected_standings.csv"]]
  candidate$projected_rankings <- artifacts[["outcomes/projected_rankings.csv"]]
  candidate$qualification_ledger <- artifacts[["outcomes/qualification_ledger.csv"]]
  candidate$team_path_probabilities <- artifacts[["outcomes/team_path_probabilities.csv"]]
  candidate$fixture_forecast_form <- artifacts[["outcomes/fixture_forecast_form.csv"]]
  candidate <- phase16_euro_attach_manifest(candidate)
  candidate
}

phase16_euro_validate_outcomes_manifest <- function(manifest, artifacts) {
  schema <- phase16_euro_outcomes_schema()$outcomes_manifest
  phase16_euro_require_schema(manifest, schema, "outcomes manifest")
  expected <- phase16_euro_outcomes_expected_inventory()
  if (!identical(as.character(manifest$artifact_path), expected)) stop("EURO outcomes manifest has an unexpected inventory", call. = FALSE)
  if (any(as.character(manifest$edition_id) != phase16_euro_edition_id())) stop("EURO outcomes manifest has a foreign edition", call. = FALSE)
  for (field in c("source_bundle_sha256", "ruleset_sha256", "content_sha256")) {
    values <- as.character(manifest[[field]])
    values <- values[!is.na(values) & nzchar(values)]
    if (length(values)) phase16_euro_assert_hash(values, paste0("EURO outcomes ", field))
  }
  for (field in c("release_manifest_sha256", "release_selector_sha256", "model_sha256", "calibrator_sha256", "draw_policy_sha256", "feature_cutoff_sha256")) {
    values <- as.character(manifest[[field]]); values <- values[!is.na(values) & nzchar(values)]
    if (length(values)) phase16_euro_assert_hash(values, paste0("EURO outcomes ", field))
  }
  if (any(is.na(suppressWarnings(as.integer(manifest$row_count))) | as.integer(manifest$row_count) < 0L)) stop("EURO outcomes manifest row counts are invalid", call. = FALSE)
  for (path in setdiff(expected, "outcomes/outcomes_manifest.csv")) {
    row <- manifest[manifest$artifact_path == path, , drop = FALSE]
    if (nrow(row) != 1L || !is.data.frame(artifacts[[path]])) stop("EURO outcomes manifest/artifact link is incomplete: ", path, call. = FALSE)
    if (as.integer(row$row_count[[1L]]) != nrow(artifacts[[path]])) stop("EURO outcomes row count mismatch: ", path, call. = FALSE)
    if (!identical(tolower(as.character(row$content_sha256[[1L]])), phase16_euro_table_content_hash(artifacts[[path]]))) stop("EURO outcomes content hash mismatch: ", path, call. = FALSE)
    parents <- strsplit(phase16_euro_text(row$parent_sha256[[1L]], ""), "|", fixed = TRUE)[[1L]]
    if (!length(parents) || any(!grepl("^[0-9a-fA-F]{64}$", parents))) stop("EURO outcomes artifact is missing parent hashes: ", path, call. = FALSE)
  }
  self <- which(manifest$artifact_path == "outcomes/outcomes_manifest.csv")
  if (length(self) != 1L) stop("EURO outcomes manifest is missing its self row", call. = FALSE)
  hashes <- unique(as.character(manifest$manifest_sha256)); hashes <- hashes[!is.na(hashes) & nzchar(hashes)]
  if (length(hashes) != 1L || !grepl("^[0-9a-fA-F]{64}$", hashes[[1L]])) stop("EURO outcomes manifest self hash is invalid", call. = FALSE)
  if (!identical(as.character(manifest$content_sha256[[self]]), hashes[[1L]]) || as.integer(manifest$row_count[[self]]) != nrow(manifest)) stop("EURO outcomes manifest self row is inconsistent", call. = FALSE)
  seed <- manifest; seed$manifest_sha256 <- ""; seed$row_sha256 <- ""; seed$row_count[[self]] <- 0L; seed$content_sha256[[self]] <- ""
  if (!identical(tolower(phase16_euro_table_content_hash(seed)), tolower(hashes[[1L]]))) stop("EURO outcomes manifest self hash mismatch", call. = FALSE)
  expected_rows <- phase16_euro_row_hashes(manifest)
  if (nrow(manifest) && any(as.character(manifest$row_sha256) != expected_rows)) stop("EURO outcomes manifest row hash mismatch", call. = FALSE)
  invisible(TRUE)
}

phase16_euro_validate_bundle_or_stop <- function(bundle) {
  artifacts <- bundle$artifacts %||% bundle$outcomes_artifacts
  expected <- phase16_euro_outcomes_expected_inventory()
  if (!is.list(artifacts) || !identical(names(artifacts), expected)) stop("EURO outcomes candidate must contain exactly the nine-file inventory", call. = FALSE)
  schemas <- phase16_euro_outcomes_schema()
  for (path in setdiff(expected, "outcomes/outcomes_manifest.csv")) {
    key <- sub("\\.csv$", "", phase16_euro_artifact_key(path)); table <- artifacts[[path]]
    phase16_euro_require_schema(table, schemas[[key]], path)
    if (nrow(table) && any(as.character(table$edition_id) != phase16_euro_edition_id())) stop("EURO outcomes artifact has a foreign edition: ", path, call. = FALSE)
    if (nrow(table) && any(as.character(table$row_sha256) != phase16_euro_row_hashes(table))) stop("EURO outcomes artifact row hash mismatch: ", path, call. = FALSE)
  }
  status <- tolower(phase16_euro_text(bundle$candidate_status, phase16_euro_text(bundle$activation_status, "candidate")))
  allowed <- c("candidate", "active", "pre_draw", "unavailable", "unresolved", "unsupported_topology", "revision_blocked", "valid")
  if (!status %in% allowed) stop("EURO outcomes candidate has an unsupported status", call. = FALSE)
  manifest <- bundle$manifest %||% artifacts[["outcomes/outcomes_manifest.csv"]]
  phase16_euro_validate_outcomes_manifest(manifest, artifacts)
  if (!nzchar(phase16_euro_text(bundle$source$source_bundle_id, ""))) stop("EURO outcomes source lineage is missing", call. = FALSE)
  if (!grepl("^[0-9a-fA-F]{64}$", phase16_euro_text(bundle$source$source_bundle_sha256, ""))) stop("EURO outcomes source bundle hash is missing", call. = FALSE)
  if (!grepl("^[0-9a-fA-F]{64}$", phase16_euro_text(bundle$ruleset_sha256, ""))) stop("EURO outcomes ruleset hash is missing", call. = FALSE)
  probabilities <- artifacts[["outcomes/team_path_probabilities.csv"]]
  ledger <- artifacts[["outcomes/qualification_ledger.csv"]]
  for (table in list(probabilities, ledger)) if (nrow(table) && any(is.na(suppressWarnings(as.numeric(as.character(table$probability)))) | suppressWarnings(as.numeric(as.character(table$probability))) < 0 | suppressWarnings(as.numeric(as.character(table$probability))) > 1)) stop("EURO outcomes probability is outside [0,1]", call. = FALSE)
  if (status == "pre_draw") {
    for (path in setdiff(expected, c("outcomes/simulation_metadata.csv", "outcomes/outcomes_manifest.csv"))) if (nrow(artifacts[[path]])) stop("pre_draw EURO outcomes must not fabricate rows", call. = FALSE)
  }
  if (status %in% c("unavailable", "unresolved", "unsupported_topology", "revision_blocked") && (nrow(probabilities) || nrow(ledger))) stop("Blocked EURO outcomes must not emit probabilities", call. = FALSE)
  if (status == "active") {
    has_activation <- "activation" %in% names(bundle)
    has_source_fixtures <- is.list(bundle[["source"]]) && "fixtures" %in% names(bundle[["source"]])
    if (has_activation || has_source_fixtures) {
      activation_input <- if (has_activation) bundle[["activation"]] else bundle[["source"]]
      activation <- phase16_euro_activation_view(activation_input)
      fixtures <- activation$resources$fixtures
      if (!is.data.frame(fixtures) || !nrow(fixtures)) stop("Active EURO outcomes require an official fixture schedule", call. = FALSE)
      if ("kickoff_confirmed" %in% names(fixtures) && any(!as.logical(fixtures$kickoff_confirmed))) stop("Active EURO outcomes require confirmed kickoff inputs", call. = FALSE)
      if ("confirmed_kickoff_at_utc" %in% names(fixtures) && any(!nzchar(as.character(fixtures$confirmed_kickoff_at_utc)))) stop("Active EURO outcomes require confirmed kickoff inputs", call. = FALSE)
      if (anyDuplicated(as.character(fixtures$fixture_id))) stop("Active EURO fixtures require unique stable IDs", call. = FALSE)
      if (nrow(probabilities) && !identical(activation$status, "active")) stop("EURO probabilities require active activation", call. = FALSE)
    } else if (!nrow(artifacts[["outcomes/competition_topology.csv"]]) || !nrow(artifacts[["outcomes/stage_slots.csv"]])) {
      stop("Active EURO outcomes require official topology and stage slots", call. = FALSE)
    }
  }
  TRUE
}

phase16_validate_euro_outcomes_bundle <- function(bundle) {
  tryCatch(
    list(valid = isTRUE(phase16_euro_validate_bundle_or_stop(bundle)), failure_reason = "", status = bundle$candidate_status %||% "candidate"),
    error = function(error) list(valid = FALSE, failure_reason = conditionMessage(error), status = bundle$candidate_status %||% "candidate")
  )
}

phase16_euro_registered_outcomes_root <- function(project_root = ".") {
  root <- normalizePath(project_root, winslash = "/", mustWork = FALSE)
  if (basename(root) == "outcomes") return(root)
  file.path(root, "outputs", "competition", phase16_euro_edition_id(), "outcomes")
}

phase16_euro_validate_output_root <- function(output_root, project_root = ".") {
  root <- gsub("/+", "/", normalizePath(output_root, winslash = "/", mustWork = FALSE))
  temp_roots <- unique(c(
    gsub("/+", "/", tempdir()),
    gsub("/+", "/", normalizePath(tempdir(), winslash = "/", mustWork = TRUE))
  ))
  registered <- gsub("/+", "/", normalizePath(phase16_euro_registered_outcomes_root(project_root), winslash = "/", mustWork = FALSE))
  if (identical(root, registered) || any(vapply(temp_roots, function(temp_root) identical(root, temp_root) || startsWith(root, paste0(temp_root, "/")), logical(1)))) return(root)
  stop("EURO outcomes writer accepts only the registered outcomes root", call. = FALSE)
}

phase16_write_euro_outcomes_bundle <- function(candidate, output_root = NULL, project_root = ".") {
  validation <- phase16_validate_euro_outcomes_bundle(candidate)
  if (!isTRUE(validation$valid)) stop("EURO outcomes candidate is not validated: ", validation$failure_reason, call. = FALSE)
  output_root <- output_root %||% phase16_euro_registered_outcomes_root(project_root)
  root <- phase16_euro_validate_output_root(output_root, project_root)
  dir.create(dirname(root), recursive = TRUE, showWarnings = FALSE)
  staging <- tempfile(".euro-outcomes-staging-", tmpdir = dirname(root)); dir.create(staging, recursive = TRUE, showWarnings = FALSE)
  on.exit(if (dir.exists(staging)) unlink(staging, recursive = TRUE), add = TRUE)
  for (path in phase16_euro_outcomes_expected_inventory()) {
    relative <- sub("^outcomes/", "", path); utils::write.csv(candidate$artifacts[[path]], file.path(staging, relative), row.names = FALSE, na = "", quote = TRUE)
  }
  backup <- tempfile(".euro-outcomes-backup-", tmpdir = dirname(root)); had_existing <- dir.exists(root)
  if (had_existing && !file.rename(root, backup)) stop("Could not stage the existing EURO outcomes root", call. = FALSE)
  if (!file.rename(staging, root)) { if (had_existing) file.rename(backup, root); stop("Could not promote the EURO outcomes root", call. = FALSE) }
  if (had_existing && dir.exists(backup)) unlink(backup, recursive = TRUE)
  output <- phase16_read_euro_outcomes_bundle(output_root = root, validate = TRUE); output$written_root <- root; output$registered <- TRUE; output
}

phase16_read_euro_outcomes_bundle <- function(root = NULL, project_root = ".", validate = TRUE, output_root = NULL) {
  root <- output_root %||% root %||% phase16_euro_registered_outcomes_root(project_root)
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  if (basename(root) != "outcomes" && file.exists(file.path(root, "competition_topology.csv"))) root <- root else if (basename(root) != "outcomes") root <- file.path(root, "outcomes")
  expected <- phase16_euro_outcomes_expected_inventory(); relative <- sub("^outcomes/", "", expected)
  present <- gsub("\\\\", "/", list.files(root, recursive = TRUE, all.files = FALSE, include.dirs = FALSE))
  if (!setequal(present, relative)) stop("EURO outcomes durable bundle must contain exactly nine files", call. = FALSE)
  artifacts <- lapply(relative, function(path) utils::read.csv(file.path(root, path), stringsAsFactors = FALSE, check.names = FALSE, na.strings = "", colClasses = "character")); names(artifacts) <- expected
  manifest <- artifacts[["outcomes/outcomes_manifest.csv"]]
  bundle <- list(edition_id = phase16_euro_edition_id(), root = root, artifacts = artifacts, outcomes_artifacts = artifacts, manifest = manifest, source = list(source_bundle_id = phase16_euro_scalar(manifest, "source_bundle_id"), source_bundle_sha256 = phase16_euro_scalar(manifest, "source_bundle_sha256")), ruleset_version = phase16_euro_scalar(manifest, "ruleset_version"), ruleset_sha256 = phase16_euro_scalar(manifest, "ruleset_sha256"), manifest_sha256 = phase16_euro_scalar(manifest, "manifest_sha256"), candidate_status = if (nrow(artifacts[["outcomes/simulation_metadata.csv"]])) phase16_euro_scalar(artifacts[["outcomes/simulation_metadata.csv"]], "status", "candidate") else "candidate", activation_status = if (nrow(artifacts[["outcomes/simulation_metadata.csv"]])) phase16_euro_scalar(artifacts[["outcomes/simulation_metadata.csv"]], "status", "candidate") else "candidate")
  if (isTRUE(validate)) {
    checked <- phase16_validate_euro_outcomes_bundle(bundle); if (!isTRUE(checked$valid)) stop(checked$failure_reason, call. = FALSE)
  }
  bundle
}

phase16_compare_euro_outcomes_replays <- function(first, second) {
  left <- first$artifacts %||% first$outcomes_artifacts; right <- second$artifacts %||% second$outcomes_artifacts
  expected <- phase16_euro_outcomes_expected_inventory(); differences <- expected[vapply(expected, function(path) {
    !is.data.frame(left[[path]]) || !is.data.frame(right[[path]]) || !identical(phase16_euro_table_content_hash(left[[path]]), phase16_euro_table_content_hash(right[[path]]))
  }, logical(1))]
  list(identical = !length(differences), differences = differences, valid = !length(differences))
}

phase16_euro_compare_replays <- phase16_compare_euro_outcomes_replays
