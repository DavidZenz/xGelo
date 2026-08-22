#' Phase 15 Nations League outcome publication contract.
#'
#' The outcome tables are a sibling of the immutable Phase 14 state bundle.
#' This module owns the pure candidate, validation, hashing, and publication
#' boundary.  It deliberately does not fit models or mutate Phase 14 files.

if (!exists("%||%", mode = "function", inherits = TRUE)) {
  `%||%` <- function(left, right) {
    if (is.null(left) || !length(left)) return(right)
    if (length(left) == 1L && is.na(left[[1L]])) return(right)
    left
  }
}

phase15_nl_edition_id <- function() {
  "uefa_nations_league_2026_27"
}

phase15_nl_outcomes_expected_inventory <- function() {
  file.path(
    "outcomes",
    c(
      "competition_topology.csv",
      "stage_slots.csv",
      "projected_standings.csv",
      "projected_rankings.csv",
      "transition_outcomes.csv",
      "team_path_probabilities.csv",
      "fixture_forecast_form.csv",
      "simulation_metadata.csv",
      "outcomes_manifest.csv"
    )
  )
}

phase15_nl_outcomes_schema <- function() {
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
    transition_outcomes = c(
      "edition_id", "projection_run_id", "stage_id", "transition_type",
      "higher_league_team_id", "lower_league_team_id", "team_id", "higher_league_rank",
      "lower_league_rank", "outcome_type", "probability", "stage_status",
      "eligibility_status", "cd_playoff_status", "retained_next_edition_league",
      "retained_next_edition_rank", "cancellation_reason", "unresolved_reason",
      "source_bundle_id", "model_release_id", "ruleset_version", "ruleset_sha256",
      "simulation_seed", "row_sha256"
    ),
    team_path_probabilities = c(
      "edition_id", "projection_run_id", "team_id", "league", "p_quarter_final",
      "p_semi_final", "p_third_place", "p_final", "p_champion", "p_direct_promotion",
      "p_direct_relegation", "p_playoff_eligibility", "p_playoff_win",
      "p_playoff_loss", "status", "suppression_reason", "simulation_count",
      "simulation_seed", "ruleset_version", "ruleset_sha256", "source_bundle_id",
      "model_release_id", "row_sha256"
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
      "edition_id", "projection_run_id", "simulation_seed", "simulation_count",
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

phase15_nl_empty_table <- function(schema) {
  output <- as.data.frame(setNames(lapply(schema, function(field) character()), schema), stringsAsFactors = FALSE, check.names = FALSE)
  row.names(output) <- integer()
  output
}

phase15_nl_field <- function(data, field, n = if (is.data.frame(data)) nrow(data) else 0L, default = "", aliases = character()) {
  candidates <- unique(c(field, aliases))
  found <- candidates[candidates %in% names(data)]
  if (length(found)) return(data[[found[[1L]]]])
  rep(default, n)
}

phase15_nl_scalar <- function(data, field, default = "", aliases = character()) {
  value <- phase15_nl_field(data, field, n = 1L, default = default, aliases = aliases)
  if (!length(value) || is.na(value[[1L]])) return(default)
  as.character(value[[1L]])
}

phase15_nl_text <- function(value, default = "") {
  if (is.null(value) || !length(value) || is.na(value[[1L]])) return(default)
  value <- trimws(as.character(value[[1L]]))
  if (!nzchar(value)) default else value
}

phase15_nl_sha256 <- function(value, serialize = FALSE) {
  if (!requireNamespace("digest", quietly = TRUE)) stop("digest is required for Phase 15 outcomes hashes", call. = FALSE)
  if (is.raw(value)) return(tolower(digest::digest(value, algo = "sha256", serialize = FALSE)))
  tolower(digest::digest(value, algo = "sha256", serialize = serialize))
}

phase15_nl_canonical_scalar <- function(value) {
  if (length(value) == 0L || is.na(value[[1L]])) return("")
  if (is.logical(value)) return(ifelse(value[[1L]], "true", "false"))
  value <- as.character(value[[1L]])
  if (value %in% c("TRUE", "FALSE", "True", "False", "true", "false")) return(tolower(value))
  value
}

phase15_nl_row_hashes <- function(data) {
  if (!is.data.frame(data) || !nrow(data)) return(character())
  fields <- setdiff(names(data), "row_sha256")
  vapply(seq_len(nrow(data)), function(index) {
    phase15_nl_sha256(paste(vapply(data[index, fields, drop = FALSE], phase15_nl_canonical_scalar, character(1)), collapse = "|"))
  }, character(1))
}

phase15_nl_sort_table <- function(data) {
  if (!is.data.frame(data)) stop("Phase 15 outcomes artifact must be a data frame", call. = FALSE)
  if (exists("phase13_publication_sort_table", mode = "function", inherits = TRUE)) {
    return(phase13_publication_sort_table(data))
  }
  hash_col <- if ("row_sha256" %in% names(data)) "row_sha256" else NULL
  fields <- setdiff(names(data), hash_col)
  if (nrow(data) > 1L && length(fields)) {
    values <- lapply(data[fields], function(column) vapply(column, phase15_nl_canonical_scalar, character(1)))
    data <- data[do.call(order, c(values, list(na.last = TRUE, method = "radix"))), , drop = FALSE]
  }
  row.names(data) <- NULL
  data
}

phase15_nl_add_row_hashes <- function(data) {
  if (!is.data.frame(data)) stop("Phase 15 outcomes row hashing requires a data frame", call. = FALSE)
  if (!"row_sha256" %in% names(data)) stop("Phase 15 outcomes artifact requires row_sha256", call. = FALSE)
  data$row_sha256 <- ""
  data$row_sha256 <- phase15_nl_row_hashes(data)
  phase15_nl_sort_table(data)
}

phase15_nl_csv_bytes <- function(data) {
  canonical <- as.data.frame(lapply(data, function(column) {
    values <- vapply(column, phase15_nl_canonical_scalar, character(1))
    values[!nzchar(values)] <- NA_character_
    values
  }), stringsAsFactors = FALSE, check.names = FALSE)
  path <- tempfile("phase15-outcomes-", fileext = ".csv")
  on.exit(if (file.exists(path)) unlink(path), add = TRUE)
  utils::write.csv(canonical, path, row.names = FALSE, na = "", quote = TRUE)
  readBin(path, what = "raw", n = file.info(path)$size)
}

phase15_nl_table_content_hash <- function(data) {
  phase15_nl_sha256(phase15_nl_csv_bytes(data))
}

phase15_nl_artifact_key <- function(path) {
  path <- gsub("\\\\", "/", as.character(path))
  sub("^outcomes/", "", path)
}

phase15_nl_artifact_type <- function(path) {
  key <- phase15_nl_artifact_key(path)
  if (identical(key, "outcomes_manifest.csv")) return("manifest")
  sub("\\.csv$", "", key)
}

phase15_nl_competition_root <- function(project_root = ".") {
  root <- normalizePath(project_root, winslash = "/", mustWork = FALSE)
  edition <- phase15_nl_edition_id()
  if (basename(root) == edition && dir.exists(file.path(root, "state"))) return(root)
  candidate <- file.path(root, "outputs", "competition", edition)
  if (dir.exists(file.path(root, "state")) && dir.exists(file.path(root, "audit"))) return(root)
  normalizePath(candidate, winslash = "/", mustWork = FALSE)
}

phase15_nl_registered_outcomes_root <- function(project_root = ".") {
  root <- phase15_nl_competition_root(project_root)
  outcomes <- normalizePath(file.path(root, "outcomes"), winslash = "/", mustWork = FALSE)
  if (isTRUE(attr(project_root, "phase15_registered"))) return(outcomes)
  registered <- normalizePath(file.path(phase15_nl_competition_root(project_root), "outcomes"), winslash = "/", mustWork = FALSE)
  if (!identical(outcomes, registered)) stop("Phase 15 outcomes root is not the registered Nations League sibling directory", call. = FALSE)
  outcomes
}

phase15_nl_read_csv <- function(path, name = basename(path)) {
  if (!file.exists(path)) stop("Phase 15 outcomes file is missing: ", name, call. = FALSE)
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
}

phase15_nl_require_schema <- function(data, schema, name) {
  if (!is.data.frame(data) || !identical(names(data), schema)) {
    stop("Phase 15 ", name, " schema mismatch; expected exact columns", call. = FALSE)
  }
  invisible(data)
}

phase15_nl_parent_value <- function(parent_graph, key, default = "") {
  value <- if (is.list(parent_graph)) parent_graph[[key]] else NULL
  if (is.list(value) && !is.null(value$sha256)) value <- value$sha256
  phase15_nl_text(value, default)
}

phase15_nl_parent_path <- function(parent_graph, key, default = "") {
  value <- if (is.list(parent_graph)) parent_graph[[key]] else NULL
  if (is.list(value) && !is.null(value$path)) value <- value$path
  phase15_nl_text(value, default)
}

phase15_nl_parent_pairs <- function(parent_graph, keys) {
  keys <- keys[keys %in% names(parent_graph)]
  keys <- keys[vapply(keys, function(key) nzchar(phase15_nl_parent_value(parent_graph, key)), logical(1))]
  list(
    paths = vapply(keys, function(key) phase15_nl_parent_path(parent_graph, key, key), character(1)),
    hashes = vapply(keys, function(key) phase15_nl_parent_value(parent_graph, key), character(1))
  )
}

phase15_nl_assert_hash <- function(value, name, allow_empty = FALSE) {
  value <- as.character(value)
  if (allow_empty && all(is.na(value) | !nzchar(trimws(value)))) return(invisible(TRUE))
  if (any(is.na(value) | !grepl("^[0-9a-fA-F]{64}$", value))) stop("Phase 15 ", name, " must contain SHA-256 hashes", call. = FALSE)
  invisible(TRUE)
}

phase15_nl_repo_root <- function(project_root = ".") {
  root <- normalizePath(project_root, winslash = "/", mustWork = FALSE)
  if (dir.exists(file.path(root, "data/competition"))) return(root)
  if (basename(root) == phase15_nl_edition_id()) {
    candidate <- dirname(dirname(dirname(dirname(root))))
    if (dir.exists(file.path(candidate, "data/competition"))) return(candidate)
  }
  if (exists("phase13_source_find_project_root", mode = "function", inherits = TRUE)) {
    return(phase13_source_find_project_root(root))
  }
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

phase15_nl_read_source_bundle <- function(
    project_root = ".",
    edition_id = phase15_nl_edition_id()) {
  root <- phase15_nl_repo_root(project_root)
  edition_id <- phase15_nl_text(edition_id)
  if (!identical(edition_id, phase15_nl_edition_id())) stop("Phase 15 outcomes source bundle requires the Nations League edition", call. = FALSE)
  registry_root <- file.path(root, "data/competition/registries")
  accepted_root <- file.path(root, "data/competition/accepted", edition_id)
  bundle_path <- file.path(registry_root, "source_bundles.csv")
  artifacts_path <- file.path(registry_root, "source_artifacts.csv")
  edition_path <- file.path(registry_root, "competition_editions.csv")
  manifest_path <- file.path(accepted_root, "source_bundle_manifest.csv")
  required_paths <- c(bundle_path, artifacts_path, edition_path, manifest_path)
  if (any(!file.exists(required_paths))) stop("Phase 15 accepted source lineage is incomplete", call. = FALSE)
  bundles <- phase15_nl_read_csv(bundle_path, "source bundle registry")
  artifacts <- phase15_nl_read_csv(artifacts_path, "source artifact registry")
  editions <- phase15_nl_read_csv(edition_path, "competition edition registry")
  manifest <- phase15_nl_read_csv(manifest_path, "accepted source bundle manifest")
  if (!"edition_id" %in% names(editions) || !any(as.character(editions$edition_id) == edition_id)) {
    stop("Phase 15 accepted source lineage has no registered Nations League edition", call. = FALSE)
  }
  bundle_rows <- bundles[as.character(bundles$edition_id) == edition_id, , drop = FALSE]
  if (nrow(bundle_rows) != 1L) stop("Phase 15 accepted source bundle registry requires one Nations League row", call. = FALSE)
  bundle <- bundle_rows[1L, , drop = FALSE]
  bundle_id <- phase15_nl_scalar(bundle, "bundle_id", aliases = "source_bundle_id")
  bundle_status <- tolower(phase15_nl_scalar(bundle, "bundle_status"))
  acceptance <- tolower(phase15_nl_scalar(bundle, "acceptance_state"))
  if (!identical(bundle_status, "accepted") || !identical(acceptance, "accepted")) stop("Phase 15 source bundle is not accepted", call. = FALSE)
  expected_types <- c("fixtures", "groups", "standings", "results", "status")
  artifact_rows <- artifacts[as.character(artifacts$edition_id) == edition_id, , drop = FALSE]
  if (nrow(artifact_rows) != length(expected_types) ||
      !setequal(as.character(artifact_rows$artifact_type), expected_types)) {
    stop("Phase 15 accepted source bundle must contain exactly five resource artifacts", call. = FALSE)
  }
  if (!all(as.character(artifact_rows$bundle_id) == bundle_id)) stop("Phase 15 source artifact bundle links do not match", call. = FALSE)
  manifest_required <- c(
    "bundle_id", "edition_id", "bundle_status", "acceptance_state", "artifact_count",
    "required_resource_count", "artifact_type", "source_artifact_id", "source_url",
    "source_url_lineage", "relative_local_raw_path", "raw_sha256", "source_bundle_sha256",
    "artifact_manifest_sha256", "row_sha256"
  )
  if (any(!manifest_required %in% names(manifest))) stop("Accepted source bundle manifest is missing lineage columns", call. = FALSE)
  if (nrow(manifest) != length(expected_types) || any(as.character(manifest$edition_id) != edition_id) ||
      any(as.character(manifest$bundle_id) != bundle_id) ||
      !setequal(as.character(manifest$artifact_type), expected_types)) {
    stop("Accepted source bundle manifest has the wrong edition or five-resource inventory", call. = FALSE)
  }
  source_bundle_sha256 <- unique(c(
    phase15_nl_field(bundle, "source_bundle_sha256"),
    phase15_nl_field(manifest, "source_bundle_sha256")
  ))
  source_bundle_sha256 <- source_bundle_sha256[!is.na(source_bundle_sha256) & nzchar(as.character(source_bundle_sha256))]
  if (length(source_bundle_sha256) != 1L || !grepl("^[0-9a-fA-F]{64}$", source_bundle_sha256[[1L]])) {
    stop("Accepted source bundle must expose one SHA-256 identity", call. = FALSE)
  }
  artifact_ids <- setNames(as.character(artifact_rows$source_artifact_id), as.character(artifact_rows$artifact_type))
  manifest_ids <- setNames(as.character(manifest$source_artifact_id), as.character(manifest$artifact_type))
  if (!identical(unname(artifact_ids[expected_types]), unname(manifest_ids[expected_types]))) {
    stop("Accepted source artifact and bundle-manifest identities do not match", call. = FALSE)
  }
  tables <- lapply(expected_types, function(type) {
    path <- file.path(accepted_root, paste0(type, ".csv"))
    table <- phase15_nl_read_csv(path, paste0("accepted ", type, " source"))
    edition_field <- if ("edition_id" %in% names(table)) "edition_id" else "source_edition_id"
    if (!edition_field %in% names(table) || any(as.character(table[[edition_field]]) != edition_id)) {
      stop("Accepted source table has a foreign edition: ", type, call. = FALSE)
    }
    if (!"source_artifact_id" %in% names(table) || any(as.character(table$source_artifact_id) != artifact_ids[[type]])) {
      stop("Accepted source table has the wrong source artifact identity: ", type, call. = FALSE)
    }
    table
  })
  names(tables) <- expected_types
  names(artifact_rows) <- names(artifact_rows)
  list(
    edition_id = edition_id,
    bundle_id = bundle_id,
    source_bundle_id = bundle_id,
    source_bundle_sha256 = tolower(as.character(source_bundle_sha256[[1L]])),
    bundle = bundle,
    source_bundle = bundle,
    source_artifacts = artifact_rows,
    artifacts = artifact_rows,
    manifest = manifest,
    source_bundle_manifest = manifest,
    tables = tables,
    fixtures = tables$fixtures,
    groups = tables$groups,
    standings = tables$standings,
    results = tables$results,
    status = tables$status,
    source_artifact_ids = paste(unname(artifact_ids[expected_types]), collapse = "|"),
    source_artifact_paths = paste(file.path("data/competition/accepted", edition_id, paste0(expected_types, ".csv")), collapse = "|"),
    source_manifest_path = file.path("data/competition/accepted", edition_id, "source_bundle_manifest.csv")
  )
}

phase15_nl_phase14_hash_value <- function(value) {
  if (exists("phase14_state_bundle_hash_value", mode = "function", inherits = TRUE)) {
    return(phase14_state_bundle_hash_value(value))
  }
  if (is.data.frame(value)) return(phase15_nl_table_content_hash(value))
  phase15_nl_sha256(value, serialize = TRUE)
}

phase15_nl_state_manifest_seed_hash <- function(manifest, artifacts, expected) {
  base <- manifest
  self_index <- match("audit/state_manifest.csv", as.character(base$artifact_path))
  if (is.na(self_index)) stop("Phase 14 state manifest has no self row", call. = FALSE)
  base$manifest_sha256 <- ""
  base$row_count[[self_index]] <- 0L
  base$content_sha256[[self_index]] <- ""
  base$row_sha256 <- vapply(expected, function(path) {
    if (path %in% c("audit/state_manifest.csv", "local/score_distributions.rds")) return("")
    value <- artifacts[[path]]
    if (exists("phase14_state_bundle_row_hashes", mode = "function", inherits = TRUE)) {
      return(paste(phase14_state_bundle_row_hashes(value), collapse = "|"))
    }
    paste(phase15_nl_row_hashes(value), collapse = "|")
  }, character(1))
  phase15_nl_phase14_hash_value(base)
}

phase15_nl_read_phase14_state_bundle <- function(
    project_root = ".",
    state_root = NULL,
    edition_id = phase15_nl_edition_id()) {
  root <- normalizePath(state_root %||% phase15_nl_competition_root(project_root), winslash = "/", mustWork = TRUE)
  if (basename(root) != phase15_nl_edition_id() && !dir.exists(file.path(root, "state"))) {
    stop("Phase 15 Phase 14 parent must be the registered Nations League state root", call. = FALSE)
  }
  expected <- if (exists("phase14_state_bundle_expected_inventory", mode = "function", inherits = TRUE)) {
    phase14_state_bundle_expected_inventory()
  } else {
    c(
      "state/canonical_matches.csv", "state/standings.csv", "state/competition_form.csv",
      "state/all_international_form.csv", "state/model_form.csv", "state/forecast_status.csv",
      "state/forecasts.csv", "state/forecast_top10.csv", "audit/standings_reconciliation.csv",
      "audit/state_manifest.csv", "local/score_distributions.rds"
    )
  }
  # The Phase 14 bundle is a sibling of later outputs under the edition root.
  # Scope the exact-inventory check to its registered state/audit/local
  # namespaces so a valid Phase 15 outcomes sibling is not misclassified as
  # an extra Phase 14 artifact.
  present <- unlist(lapply(unique(dirname(expected)), function(namespace) {
    namespace_root <- file.path(root, namespace)
    if (!dir.exists(namespace_root)) return(character())
    files <- list.files(namespace_root, recursive = TRUE, all.files = FALSE, include.dirs = FALSE)
    file.path(namespace, files)
  }), use.names = FALSE)
  present <- gsub("\\\\", "/", present)
  if (!setequal(present, expected)) stop("Phase 15 Phase 14 parent must contain exactly eleven state artifacts", call. = FALSE)
  artifacts <- lapply(expected, function(path) {
    full <- file.path(root, path)
    if (identical(path, "local/score_distributions.rds")) readRDS(full) else phase15_nl_read_csv(full, path)
  })
  names(artifacts) <- expected
  manifest <- artifacts[["audit/state_manifest.csv"]]
  manifest_required <- c(
    "edition_id", "artifact_path", "row_count", "content_sha256", "row_sha256",
    "parent_paths", "parent_sha256", "source_bundle_id", "source_bundle_sha256",
    "model_release_id", "release_manifest_sha256", "release_selector_sha256",
    "model_id", "model_sha256", "calibrator_id", "calibrator_sha256",
    "model_data_cutoff", "validation_status", "manifest_sha256"
  )
  if (any(!manifest_required %in% names(manifest)) || nrow(manifest) != length(expected) ||
      !identical(as.character(manifest$artifact_path), expected)) {
    stop("Phase 14 state manifest does not enumerate the exact eleven artifacts", call. = FALSE)
  }
  if (length(unique(as.character(manifest$edition_id))) != 1L ||
      !identical(as.character(manifest$edition_id[[1L]]), edition_id)) {
    stop("Phase 14 state parent has a foreign edition", call. = FALSE)
  }
  manifest_hashes <- unique(as.character(manifest$manifest_sha256))
  manifest_hashes <- manifest_hashes[!is.na(manifest_hashes) & nzchar(manifest_hashes)]
  if (length(manifest_hashes) != 1L) stop("Phase 14 state manifest self identity is not unique", call. = FALSE)
  phase15_nl_assert_hash(manifest_hashes, "Phase 14 state manifest self identity")
  self_index <- match("audit/state_manifest.csv", expected)
  if (!identical(as.character(manifest$content_sha256[[self_index]]), manifest_hashes[[1L]]) ||
      !identical(as.integer(manifest$row_count[[self_index]]), as.integer(nrow(manifest)))) {
    stop("Phase 14 state manifest self row is inconsistent", call. = FALSE)
  }
  for (index in seq_along(expected)) {
    path <- expected[[index]]
    value <- artifacts[[path]]
    if (!identical(as.integer(manifest$row_count[[index]]), if (is.data.frame(value)) as.integer(nrow(value)) else 1L)) {
      stop("Phase 14 state row count mismatch: ", path, call. = FALSE)
    }
    expected_hash <- if (identical(path, "audit/state_manifest.csv")) manifest_hashes[[1L]] else phase15_nl_phase14_hash_value(value)
    if (!identical(tolower(as.character(manifest$content_sha256[[index]])), tolower(expected_hash))) {
      stop("Phase 14 state content hash mismatch: ", path, call. = FALSE)
    }
    parent_paths <- phase15_nl_text(manifest$parent_paths[[index]], "")
    parent_hashes <- phase15_nl_text(manifest$parent_sha256[[index]], "")
    if (nzchar(parent_paths)) {
      parents <- strsplit(parent_paths, "|", fixed = TRUE)[[1L]]
      hashes <- strsplit(parent_hashes, "|", fixed = TRUE)[[1L]]
      if (length(parents) != length(hashes) || any(!parents %in% expected)) stop("Phase 14 state parent graph is invalid: ", path, call. = FALSE)
      observed <- vapply(parents, function(parent) phase15_nl_phase14_hash_value(artifacts[[parent]]), character(1))
      if (!identical(tolower(paste(observed, collapse = "|")), tolower(paste(hashes, collapse = "|")))) {
        stop("Phase 14 state parent hash mismatch: ", path, call. = FALSE)
      }
    }
  }
  source <- phase15_nl_read_source_bundle(project_root = project_root, edition_id = edition_id)
  source_bundle_id <- unique(c(
    as.character(manifest$source_bundle_id), source$source_bundle_id
  ))
  source_bundle_id <- source_bundle_id[!is.na(source_bundle_id) & nzchar(source_bundle_id)]
  if (length(source_bundle_id) != 1L || !identical(source_bundle_id[[1L]], source$source_bundle_id)) stop("Phase 14 state/source bundle identity mismatch", call. = FALSE)
  source_hash <- unique(c(as.character(manifest$source_bundle_sha256), source$source_bundle_sha256))
  source_hash <- source_hash[!is.na(source_hash) & nzchar(source_hash)]
  if (length(source_hash) != 1L || !identical(tolower(source_hash[[1L]]), tolower(source$source_bundle_sha256))) stop("Phase 14 state/source bundle hash mismatch", call. = FALSE)
  release_fields <- c("model_release_id", "release_manifest_sha256", "release_selector_sha256", "model_id", "model_sha256", "calibrator_id", "calibrator_sha256", "model_data_cutoff")
  for (field in release_fields) {
    values <- unique(as.character(manifest[[field]]))
    values <- values[!is.na(values) & nzchar(trimws(values))]
    if (length(values) != 1L) stop("Phase 14 state manifest must carry one approved ", field, call. = FALSE)
    if (grepl("sha256", field)) phase15_nl_assert_hash(values, paste0("Phase 14 ", field))
  }
  cutoff_values <- unique(as.character(manifest$model_data_cutoff))
  cutoff_values <- cutoff_values[!is.na(cutoff_values) & nzchar(cutoff_values)]
  if (length(cutoff_values) != 1L) stop("Phase 14 state manifest must carry one model data cutoff", call. = FALSE)
  list(
    edition_id = edition_id,
    root = root,
    state_artifacts = artifacts,
    artifacts = artifacts,
    state_manifest = manifest,
    manifest = manifest,
    state_manifest_sha256 = manifest_hashes[[1L]],
    forecast_status = artifacts[["state/forecast_status.csv"]],
    forecasts = artifacts[["state/forecasts.csv"]],
    canonical_matches = artifacts[["state/canonical_matches.csv"]],
    competition_form = artifacts[["state/competition_form.csv"]],
    all_international_form = artifacts[["state/all_international_form.csv"]],
    score_distributions = artifacts[["local/score_distributions.rds"]],
    source = source,
    source_bundle_id = source$source_bundle_id,
    source_bundle_sha256 = source$source_bundle_sha256,
    model_release_id = unique(as.character(manifest$model_release_id))[[1L]],
    model_lineage = as.list(manifest[1L, intersect(release_fields, names(manifest)), drop = FALSE])
  )
}

phase15_nl_rules_lineage <- function(rules = NULL) {
  rules <- rules %||% if (exists("uefa_nl_2026_27_rules", mode = "function", inherits = TRUE)) uefa_nl_2026_27_rules() else list()
  version <- if (exists("uefa_nl_ruleset_version", mode = "function", inherits = TRUE)) uefa_nl_ruleset_version() else phase15_nl_text(rules$ruleset_version, "phase15-nations-league-rules-v1")
  hash <- if (exists("uefa_nl_ruleset_sha256", mode = "function", inherits = TRUE)) {
    uefa_nl_ruleset_sha256(rules)
  } else {
    phase15_nl_sha256(rules, serialize = TRUE)
  }
  list(rules = rules, ruleset_version = version, ruleset_sha256 = tolower(hash))
}

phase15_nl_simulation_metadata_row <- function(simulation) {
  metadata <- simulation$simulation_metadata %||% simulation$metadata$simulation_metadata %||% data.frame(stringsAsFactors = FALSE)
  if (is.data.frame(metadata) && nrow(metadata)) return(metadata[1L, , drop = FALSE])
  if (is.list(metadata) && !is.data.frame(metadata)) return(as.data.frame(metadata, stringsAsFactors = FALSE, check.names = FALSE))
  data.frame(stringsAsFactors = FALSE)
}

phase15_nl_stage_type <- function(stage_id, topology = NULL, rules = NULL) {
  stage_id <- as.character(stage_id)
  if (!is.null(topology) && is.data.frame(topology) && "stage_id" %in% names(topology) && "stage_type" %in% names(topology)) {
    value <- as.character(topology$stage_type[match(stage_id, as.character(topology$stage_id))])
    if (!is.na(value) && nzchar(value)) return(value)
  }
  if (is.list(topology) && is.data.frame(topology$stage_topology)) return(phase15_nl_stage_type(stage_id, topology$stage_topology, rules))
  if (is.list(rules) && is.data.frame(rules$stage_topology)) return(phase15_nl_stage_type(stage_id, rules$stage_topology, rules))
  if (exists("uefa_nl_stage_topology", mode = "function", inherits = TRUE)) {
    table <- uefa_nl_stage_topology()
    value <- as.character(table$stage_type[match(stage_id, as.character(table$stage_id))])
    if (!is.na(value) && nzchar(value)) return(value)
  }
  ""
}

phase15_nl_topology_table <- function(topology, source, rules_lineage) {
  schema <- phase15_nl_outcomes_schema()$competition_topology
  rows <- phase15_nl_empty_table(schema)
  groups <- if (is.list(topology)) topology$groups else topology
  fixtures <- if (is.list(topology)) topology$fixtures else NULL
  if (is.null(groups) || !is.data.frame(groups)) groups <- source$groups %||% data.frame(stringsAsFactors = FALSE)
  if (is.null(fixtures) || !is.data.frame(fixtures)) fixtures <- source$fixtures %||% data.frame(stringsAsFactors = FALSE)
  if (nrow(groups)) {
    group_field <- if ("group_id" %in% names(groups)) "group_id" else if ("source_group_id" %in% names(groups)) "source_group_id" else NULL
    if (is.null(group_field)) stop("Nations League topology groups require group_id", call. = FALSE)
    group_ids <- unique(as.character(groups[[group_field]]))
    group_ids <- group_ids[!is.na(group_ids) & nzchar(group_ids)]
    group_rows <- lapply(group_ids, function(group_id) {
      group <- groups[as.character(groups[[group_field]]) == group_id, , drop = FALSE]
      league <- toupper(phase15_nl_scalar(group, "league"))
      fixture_group_field <- if ("group_id" %in% names(fixtures)) "group_id" else if ("source_group_id" %in% names(fixtures)) "source_group_id" else NULL
      fixture_count <- if (!is.null(fixture_group_field)) sum(as.character(fixtures[[fixture_group_field]]) == group_id, na.rm = TRUE) else 0L
      row <- phase15_nl_empty_table(schema)
      row[1L, ] <- list(
        phase15_nl_edition_id(), "group", league, group_id,
        phase15_nl_scalar(group, "display_name", aliases = "name"),
        nrow(group), fixture_count, "", "", "", "", "", "", "", "", "",
        source$source_bundle_id %||% "",
        paste(unique(as.character(phase15_nl_field(group, "source_artifact_id"))), collapse = "|"),
        rules_lineage$ruleset_version, rules_lineage$ruleset_sha256, ""
      )
      row
    })
    rows <- do.call(rbind, group_rows)
  }
  stage_topology <- NULL
  if (is.list(topology)) stage_topology <- topology$stage_topology
  if (is.null(stage_topology) && is.list(rules_lineage$rules)) stage_topology <- rules_lineage$rules$stage_topology
  if (is.null(stage_topology) && exists("uefa_nl_stage_topology", mode = "function", inherits = TRUE)) stage_topology <- uefa_nl_stage_topology()
  if (is.data.frame(stage_topology) && nrow(stage_topology)) {
    stage_rows <- lapply(seq_len(nrow(stage_topology)), function(index) {
      stage <- stage_topology[index, , drop = FALSE]
      row <- phase15_nl_empty_table(schema)
      row[1L, ] <- list(
        phase15_nl_edition_id(), "stage", "", "", "", 0L, 0L,
        phase15_nl_scalar(stage, "stage_id"), phase15_nl_scalar(stage, "stage_type"),
        phase15_nl_field(stage, "legs", n = 1L, default = 1L), phase15_nl_scalar(stage, "seed_policy"),
        phase15_nl_scalar(stage, "different_group"), phase15_nl_scalar(stage, "first_leg_home_policy"),
        phase15_nl_scalar(stage, "tie_break_policy"), phase15_nl_scalar(stage, "cancellation_condition"),
        "unresolved", source$source_bundle_id %||% "", "", rules_lineage$ruleset_version,
        rules_lineage$ruleset_sha256, ""
      )
      row
    })
    rows <- rbind(rows, do.call(rbind, stage_rows))
  }
  if (!nrow(rows)) return(phase15_nl_empty_table(schema))
  rows$source_artifact_ids <- vapply(seq_len(nrow(rows)), function(index) phase15_nl_text(rows$source_artifact_ids[[index]], ""), character(1))
  phase15_nl_add_row_hashes(rows)
}

phase15_nl_capture_stage_slots <- function(stage_capture, topology, rules_lineage) {
  schema <- phase15_nl_outcomes_schema()$stage_slots
  if (is.null(stage_capture)) return(phase15_nl_empty_table(schema))
  capture <- if (is.list(stage_capture)) stage_capture$stage_capture %||% stage_capture$capture else stage_capture
  if (!is.data.frame(capture) || !nrow(capture)) return(phase15_nl_empty_table(schema))
  rows <- lapply(seq_len(nrow(capture)), function(index) {
    source <- capture[index, , drop = FALSE]
    source_status <- tolower(phase15_nl_scalar(source, "stage_status", aliases = "source_status"))
    status <- if (source_status %in% c("completed", "complete", "played", "final")) "completed" else "official"
    row <- phase15_nl_empty_table(schema)
    row[1L, ] <- list(
      phase15_nl_edition_id(), phase15_nl_scalar(source, "stage_id"),
      phase15_nl_stage_type(phase15_nl_scalar(source, "stage_id"), topology, rules_lineage$rules), status,
      as.integer(suppressWarnings(as.numeric(phase15_nl_scalar(source, "leg_number", default = 1L)))),
      phase15_nl_scalar(source, "participant_slot_home"), phase15_nl_scalar(source, "participant_slot_away"),
      phase15_nl_scalar(source, "home_team_id"), phase15_nl_scalar(source, "away_team_id"),
      phase15_nl_scalar(source, "source_fixture_id"), phase15_nl_scalar(source, "source_artifact_id"),
      "", "", phase15_nl_scalar(source, "scheduled_at_utc"),
      phase15_nl_field(source, "regulation_home_goals", n = 1L), phase15_nl_field(source, "regulation_away_goals", n = 1L),
      phase15_nl_field(source, "extra_time_home_goals", n = 1L), phase15_nl_field(source, "extra_time_away_goals", n = 1L),
      phase15_nl_field(source, "penalty_shootout_home_goals", n = 1L), phase15_nl_field(source, "penalty_shootout_away_goals", n = 1L),
      phase15_nl_field(source, "final_home_goals", n = 1L), phase15_nl_field(source, "final_away_goals", n = 1L),
      phase15_nl_scalar(source, "completed_at_utc"), status, "", "",
      rules_lineage$ruleset_version, rules_lineage$ruleset_sha256, ""
    )
    row
  })
  output <- do.call(rbind, rows)
  phase15_nl_add_row_hashes(output)
}

phase15_nl_simulation_stage_slots <- function(simulation, topology, rules_lineage) {
  schema <- phase15_nl_outcomes_schema()$stage_slots
  source <- simulation$stage_slots
  if (!is.data.frame(source) || !nrow(source)) return(phase15_nl_empty_table(schema))
  rows <- lapply(seq_len(nrow(source)), function(index) {
    input <- source[index, , drop = FALSE]
    status <- tolower(phase15_nl_scalar(input, "stage_status", aliases = "status"))
    if (!status %in% c("projected", "unresolved", "suppressed", "official", "completed")) status <- "unresolved"
    if (status %in% c("official", "completed")) status <- "projected"
    is_resolved <- status == "projected"
    row <- phase15_nl_empty_table(schema)
    row[1L, ] <- list(
      phase15_nl_edition_id(), phase15_nl_scalar(input, "stage_id"),
      phase15_nl_stage_type(phase15_nl_scalar(input, "stage_id"), topology, rules_lineage$rules), status,
      as.integer(suppressWarnings(as.numeric(phase15_nl_scalar(input, "leg_number", default = 1L)))),
      if (is_resolved) phase15_nl_scalar(input, "participant_slot_home") else "",
      if (is_resolved) phase15_nl_scalar(input, "participant_slot_away") else "",
      if (is_resolved) phase15_nl_scalar(input, "home_team_id") else "",
      if (is_resolved) phase15_nl_scalar(input, "away_team_id") else "",
      "", "", if (is_resolved) phase15_nl_scalar(input, "projection_run_id") else "",
      if (is_resolved) phase15_nl_scalar(input, "draw_policy_id") else "",
      if (is_resolved) phase15_nl_scalar(input, "scheduled_at_utc") else "",
      NA_integer_, NA_integer_, NA_integer_, NA_integer_, NA_integer_, NA_integer_, NA_integer_, NA_integer_, "",
      status, if (status == "unresolved") phase15_nl_scalar(input, "unresolved_reason", default = "missing_stage_resolution") else "",
      if (status == "suppressed") phase15_nl_scalar(input, "suppression_reason", default = "stage_suppressed") else "",
      rules_lineage$ruleset_version, rules_lineage$ruleset_sha256, ""
    )
    row
  })
  output <- do.call(rbind, rows)
  if (nrow(output) > 1L) {
    key <- paste(output$stage_id, output$leg_number, output$participant_slot_home, output$participant_slot_away, output$stage_status, sep = "::")
    output <- output[!duplicated(key), , drop = FALSE]
  }
  phase15_nl_add_row_hashes(output)
}

phase15_nl_merge_stage_slots <- function(stage_capture, simulation, topology, rules_lineage) {
  official <- phase15_nl_capture_stage_slots(stage_capture, topology, rules_lineage)
  projected <- phase15_nl_simulation_stage_slots(simulation, topology, rules_lineage)
  if (!nrow(official) && !nrow(projected)) return(phase15_nl_empty_table(phase15_nl_outcomes_schema()$stage_slots))
  output <- rbind(official, projected)
  if (nrow(output) > 1L) {
    key <- paste(output$stage_id, output$leg_number, output$participant_slot_home, output$participant_slot_away, sep = "::")
    output <- output[!duplicated(key), , drop = FALSE]
  }
  phase15_nl_add_row_hashes(output)
}

phase15_nl_common_simulation_fields <- function(simulation, rules_lineage, source, state, metadata = NULL) {
  metadata <- metadata %||% phase15_nl_simulation_metadata_row(simulation)
  list(
    edition_id = phase15_nl_edition_id(),
    projection_run_id = phase15_nl_scalar(metadata, "projection_run_id", default = phase15_nl_scalar(simulation$metadata, "projection_run_id")),
    simulation_count = phase15_nl_field(metadata, "simulation_count", n = 1L, default = phase15_nl_field(simulation$metadata, "simulation_count", n = 1L, default = "")),
    simulation_seed = phase15_nl_field(metadata, "simulation_seed", n = 1L, default = phase15_nl_field(simulation$metadata, "simulation_seed", n = 1L, default = "")),
    source_bundle_id = source$source_bundle_id %||% phase15_nl_scalar(metadata, "source_bundle_id"),
    source_bundle_sha256 = source$source_bundle_sha256 %||% phase15_nl_scalar(metadata, "source_bundle_sha256"),
    model_release_id = state$model_release_id %||% phase15_nl_scalar(metadata, "model_release_id"),
    ruleset_version = rules_lineage$ruleset_version,
    ruleset_sha256 = rules_lineage$ruleset_sha256
  )
}

phase15_nl_fill_common <- function(output, common, fields = names(common)) {
  for (field in intersect(fields, names(output))) {
    if (field %in% names(common)) output[[field]] <- common[[field]]
  }
  output
}

phase15_nl_map_simulation_table <- function(input, schema, common, aliases = list()) {
  if (!is.data.frame(input) || !nrow(input)) return(phase15_nl_empty_table(schema))
  output <- phase15_nl_empty_table(schema)
  output <- output[rep(1L, nrow(input)), , drop = FALSE]
  for (field in schema) {
    if (field == "row_sha256") next
    source_field <- c(field, aliases[[field]] %||% character())
    source_field <- source_field[source_field %in% names(input)]
    if (length(source_field)) output[[field]] <- input[[source_field[[1L]]]]
  }
  phase15_nl_fill_common(output, common)
}

phase15_nl_normalize_ranking_status <- function(status) {
  status <- tolower(trimws(as.character(status)))
  status[is.na(status) | !nzchar(status)] <- "resolved"
  status[status %in% c("blocked", "unresolved", "missing", "suppressed")] <- "unresolved"
  status
}

phase15_nl_build_projected_standings <- function(simulation, common) {
  output <- phase15_nl_map_simulation_table(
    simulation$projected_standings,
    phase15_nl_outcomes_schema()$projected_standings,
    common,
    aliases = list(expected_goal_difference = "expected_goal_diff", ranking_status = "ordering_status")
  )
  if (nrow(output)) output$ranking_status <- phase15_nl_normalize_ranking_status(output$ranking_status)
  if (nrow(output)) phase15_nl_add_row_hashes(output) else output
}

phase15_nl_build_projected_rankings <- function(simulation, common) {
  output <- phase15_nl_map_simulation_table(
    simulation$projected_rankings,
    phase15_nl_outcomes_schema()$projected_rankings,
    common,
    aliases = list(
      group_position = "group_rank", rank = "overall_rank", ranking_status = "ordering_status",
      counted_match_ids = "counted_matches", excluded_match_ids = "excluded_matches"
    )
  )
  if (nrow(output)) {
    output$ranking_status <- phase15_nl_normalize_ranking_status(output$ranking_status)
    blocked <- output$ranking_status == "unresolved"
    if (any(blocked)) {
      output$rank[blocked] <- NA_integer_
      output$interim_overall_rank[blocked] <- NA_integer_
      output$final_overall_rank[blocked] <- NA_integer_
      output$missing_rule_input[blocked & is.na(output$missing_rule_input)] <- "ranking_input_unresolved"
      output$suppression_reason[blocked & is.na(output$suppression_reason)] <- "ranking_input_unresolved"
    }
  }
  if (nrow(output)) phase15_nl_add_row_hashes(output) else output
}

phase15_nl_build_transition_outcomes <- function(simulation, common) {
  output <- phase15_nl_map_simulation_table(
    simulation$transition_outcomes,
    phase15_nl_outcomes_schema()$transition_outcomes,
    common,
    aliases = list(
      eligibility_status = "playoff_eligibility_status",
      probability = "outcome_probability",
      stage_status = "status"
    )
  )
  if (nrow(output)) {
    output$stage_status <- tolower(trimws(as.character(output$stage_status)))
    output$stage_status[is.na(output$stage_status) | !nzchar(output$stage_status)] <- "projected"
    canceled <- tolower(as.character(output$outcome_type)) %in% c("canceled", "cancelled")
    if (any(canceled)) output$probability[canceled] <- NA_real_
  }
  if (nrow(output)) phase15_nl_add_row_hashes(output) else output
}

phase15_nl_build_team_paths <- function(simulation, common) {
  output <- phase15_nl_map_simulation_table(
    simulation$team_path_probabilities,
    phase15_nl_outcomes_schema()$team_path_probabilities,
    common,
    aliases = list(status = "path_status")
  )
  if (nrow(output)) {
    output$status <- tolower(trimws(as.character(output$status)))
    output$status[is.na(output$status) | !nzchar(output$status)] <- "projected"
  }
  if (nrow(output)) phase15_nl_add_row_hashes(output) else output
}

phase15_nl_build_simulation_metadata <- function(simulation, state, source, rules_lineage, common, output_hash = "") {
  schema <- phase15_nl_outcomes_schema()$simulation_metadata
  input <- phase15_nl_simulation_metadata_row(simulation)
  output <- phase15_nl_empty_table(schema)
  output <- output[rep(1L, 1L), , drop = FALSE]
  if (is.data.frame(input) && ncol(input)) {
    for (field in setdiff(schema, "row_sha256")) if (field %in% names(input)) output[[field]] <- input[[field]][[1L]]
  }
  output$edition_id <- phase15_nl_edition_id()
  output$projection_run_id <- common$projection_run_id
  output$simulation_seed <- common$simulation_seed
  output$simulation_count <- common$simulation_count
  output$draw_policy_id <- phase15_nl_scalar(input, "draw_policy_id", default = phase15_nl_scalar(simulation$metadata, "draw_policy_id"))
  output$draw_policy_sha256 <- phase15_nl_scalar(input, "draw_policy_sha256", default = phase15_nl_scalar(simulation$metadata, "draw_policy_sha256"))
  output$ruleset_version <- rules_lineage$ruleset_version
  output$ruleset_sha256 <- rules_lineage$ruleset_sha256
  output$source_bundle_id <- common$source_bundle_id
  output$source_bundle_sha256 <- common$source_bundle_sha256
  output$model_release_id <- common$model_release_id
  if (!nzchar(phase15_nl_text(output$state_manifest_sha256[[1L]], ""))) output$state_manifest_sha256 <- state$state_manifest_sha256 %||% ""
  output$forecast_status_sha256 <- phase15_nl_parent_value(state$parent_graph, "phase14_forecast_status", phase15_nl_text(output$forecast_status_sha256[[1L]], ""))
  output$forecasts_sha256 <- phase15_nl_parent_value(state$parent_graph, "phase14_forecasts", phase15_nl_text(output$forecasts_sha256[[1L]], ""))
  output$score_distributions_sha256 <- phase15_nl_parent_value(state$parent_graph, "phase14_score_distributions", phase15_nl_text(output$score_distributions_sha256[[1L]], ""))
  output$release_manifest_sha256 <- phase15_nl_scalar(input, "release_manifest_sha256", default = phase15_nl_scalar(state$state_manifest, "release_manifest_sha256"))
  output$release_selector_sha256 <- phase15_nl_scalar(input, "release_selector_sha256", default = phase15_nl_scalar(state$state_manifest, "release_selector_sha256"))
  output$model_data_cutoff <- phase15_nl_scalar(input, "model_data_cutoff", default = phase15_nl_scalar(state$state_manifest, "model_data_cutoff"))
  output$feature_cutoff_sha256 <- phase15_nl_scalar(input, "feature_cutoff_sha256", default = phase15_nl_parent_value(state$parent_graph, "phase14_feature_cutoff"))
  output$generated_at_utc <- phase15_nl_scalar(input, "generated_at_utc", default = phase15_nl_scalar(state$state_manifest, "generated_at_utc"))
  output$output_sha256 <- if (nzchar(output_hash)) output_hash else phase15_nl_scalar(input, "output_sha256", default = phase15_nl_sha256(simulation$output_hashes, serialize = TRUE))
  phase15_nl_add_row_hashes(output)
}

phase15_nl_parent_graph_from_state <- function(state, source, stage_capture, rules_lineage, simulation, simulation_metadata) {
  manifest <- state$state_manifest
  parent <- list()
  put <- function(key, path, hash) parent[[key]] <<- list(path = path, sha256 = phase15_nl_text(hash))
  put("phase14_state_manifest", "audit/state_manifest.csv", state$state_manifest_sha256)
  for (path in phase14_state_bundle_expected_inventory()) {
    if (path == "audit/state_manifest.csv") next
    row <- manifest[as.character(manifest$artifact_path) == path, , drop = FALSE]
    if (nrow(row)) put(paste0("phase14_", gsub("[^A-Za-z0-9]+", "_", sub("\\.csv$", "", path))), path, phase15_nl_scalar(row, "content_sha256"))
  }
  put("source_bundle_manifest", source$source_manifest_path %||% "data/competition/accepted/uefa_nations_league_2026_27/source_bundle_manifest.csv", source$source_bundle_sha256)
  put("source_bundle", "data/competition/registries/source_bundles.csv", source$source_bundle_sha256)
  put("ruleset", "rules/uefa_nations_league_ruleset", rules_lineage$ruleset_sha256)
  capture_manifest <- if (is.list(stage_capture)) stage_capture$manifest else NULL
  if (is.data.frame(capture_manifest) && nrow(capture_manifest)) {
    put("stage_capture_manifest", "data/competition/accepted/uefa_nations_league_2026_27/stage_capture_manifest.csv", phase15_nl_scalar(capture_manifest, "manifest_sha256"))
    put("stage_capture_raw", phase15_nl_scalar(capture_manifest, "raw_relative_path"), phase15_nl_scalar(capture_manifest, "raw_sha256"))
    put("stage_capture_content", phase15_nl_scalar(capture_manifest, "capture_relative_path"), phase15_nl_scalar(capture_manifest, "capture_content_sha256"))
  }
  put("model_release", "outputs/releases/approved_release.csv", phase15_nl_scalar(manifest, "release_manifest_sha256"))
  put("model_selector", "outputs/releases/approved_release.csv", phase15_nl_scalar(manifest, "release_selector_sha256"))
  put("model", "outputs/releases/model_manifest.csv", phase15_nl_scalar(manifest, "model_sha256"))
  put("calibrator", "outputs/releases/model_manifest.csv", phase15_nl_scalar(manifest, "calibrator_sha256"))
  put("phase14_feature_cutoff", "state/forecast_status.csv#feature_cutoff_utc", phase15_nl_sha256(unique(as.character(state$forecast_status$feature_cutoff_utc))))
  put("simulation_metadata", "outcomes/simulation_metadata.csv", phase15_nl_table_content_hash(simulation_metadata))
  parent
}

phase15_build_nl_outcomes_candidate <- function(
    simulation,
    rules = NULL,
    topology = NULL,
    source = NULL,
    stage_capture = NULL,
    state_bundle = NULL,
    project_root = ".",
    generated_at_utc = NULL) {
  if (!is.list(simulation)) stop("Phase 15 outcomes candidate requires a simulation return list", call. = FALSE)
  state <- state_bundle %||% phase15_nl_read_phase14_state_bundle(project_root = project_root)
  if (is.character(state)) state <- phase15_nl_read_phase14_state_bundle(project_root = project_root, state_root = state)
  if (!is.list(state) || is.null(state$state_manifest)) stop("Phase 15 outcomes candidate requires the validated Phase 14 state parent", call. = FALSE)
  source <- source %||% state$source %||% phase15_nl_read_source_bundle(project_root = project_root)
  rules_lineage <- phase15_nl_rules_lineage(rules)
  topology <- topology %||% simulation$topology
  if (is.null(topology) && exists("uefa_nl_build_topology", mode = "function", inherits = TRUE)) {
    topology <- uefa_nl_build_topology(groups = source$groups, fixtures = source$fixtures, project_root = project_root)
  }
  if (is.null(stage_capture)) {
    if (exists("phase15_uefa_nl_read_stage_capture", mode = "function", inherits = TRUE)) {
      stage_capture <- phase15_uefa_nl_read_stage_capture(project_root = project_root)
    }
  }
  metadata <- phase15_nl_simulation_metadata_row(simulation)
  common <- phase15_nl_common_simulation_fields(simulation, rules_lineage, source, state, metadata)
  competition_topology <- phase15_nl_topology_table(topology, source, rules_lineage)
  stage_slots <- phase15_nl_merge_stage_slots(stage_capture, simulation, topology, rules_lineage)
  projected_standings <- phase15_nl_build_projected_standings(simulation, common)
  projected_rankings <- phase15_nl_build_projected_rankings(simulation, common)
  transition_outcomes <- phase15_nl_build_transition_outcomes(simulation, common)
  team_paths <- phase15_nl_build_team_paths(simulation, common)
  fixture_form <- phase15_nl_build_fixture_forecast_form(
    canonical_matches = state$canonical_matches,
    forecast_status = state$forecast_status,
    forecasts = state$forecasts,
    competition_form = state$competition_form,
    all_international_form = state$all_international_form,
    state_manifest = state$state_manifest,
    score_distributions = state$score_distributions,
    source = source
  )
  simulation_metadata <- phase15_nl_build_simulation_metadata(simulation, state, source, rules_lineage, common)
  parent_graph <- phase15_nl_parent_graph_from_state(state, source, stage_capture, rules_lineage, simulation, simulation_metadata)
  state$parent_graph <- parent_graph
  output_hash <- phase15_nl_sha256(list(
    projected_standings, projected_rankings, transition_outcomes, team_paths,
    stage_slots, fixture_form, simulation_metadata
  ), serialize = TRUE)
  simulation_metadata$output_sha256 <- output_hash
  simulation_metadata <- phase15_nl_add_row_hashes(simulation_metadata)
  artifacts <- list(
    "outcomes/competition_topology.csv" = competition_topology,
    "outcomes/stage_slots.csv" = stage_slots,
    "outcomes/projected_standings.csv" = projected_standings,
    "outcomes/projected_rankings.csv" = projected_rankings,
    "outcomes/transition_outcomes.csv" = transition_outcomes,
    "outcomes/team_path_probabilities.csv" = team_paths,
    "outcomes/fixture_forecast_form.csv" = fixture_form,
    "outcomes/simulation_metadata.csv" = simulation_metadata
  )
  candidate <- list(
    edition_id = phase15_nl_edition_id(),
    candidate_status = "candidate",
    rules = rules_lineage$rules,
    ruleset_version = rules_lineage$ruleset_version,
    ruleset_sha256 = rules_lineage$ruleset_sha256,
    topology = topology,
    source = source,
    stage_capture = stage_capture,
    state_bundle = state,
    state_manifest = state$state_manifest,
    state_manifest_sha256 = state$state_manifest_sha256,
    simulation = simulation,
    simulation_metadata = simulation_metadata,
    projection_run_id = common$projection_run_id,
    simulation_seed = common$simulation_seed,
    simulation_count = common$simulation_count,
    draw_policy_id = phase15_nl_scalar(simulation_metadata, "draw_policy_id"),
    draw_policy_sha256 = phase15_nl_scalar(simulation_metadata, "draw_policy_sha256"),
    parent_graph = parent_graph,
    artifacts = artifacts,
    outcomes_artifacts = artifacts,
    generated_at_utc = generated_at_utc %||% phase15_nl_scalar(simulation_metadata, "generated_at_utc")
  )
  candidate$manifest <- phase15_nl_outcomes_manifest_rows(candidate, artifacts)
  candidate <- phase15_nl_attach_manifest(candidate)
  candidate
}

phase15_nl_state_manifest_content_hash <- function(state_manifest, path) {
  if (!is.data.frame(state_manifest) || !nrow(state_manifest) || !"artifact_path" %in% names(state_manifest)) return("")
  row <- state_manifest[as.character(state_manifest$artifact_path) == path, , drop = FALSE]
  if (!nrow(row) || !"content_sha256" %in% names(row)) return("")
  phase15_nl_scalar(row, "content_sha256")
}

phase15_nl_form_rows_for_team <- function(form, team_id) {
  if (!is.data.frame(form) || !nrow(form) || !"team_id" %in% names(form)) return(data.frame(stringsAsFactors = FALSE))
  rows <- form[as.character(form$team_id) == as.character(team_id), , drop = FALSE]
  if (nrow(rows) > 1L) rows <- rows[order(as.character(phase15_nl_field(rows, "feature_cutoff_utc")), method = "radix"), , drop = FALSE]
  if (nrow(rows)) rows[1L, , drop = FALSE] else rows
}

phase15_nl_form_summary <- function(form, team_ids) {
  rows <- lapply(team_ids, function(team_id) phase15_nl_form_rows_for_team(form, team_id))
  present <- vapply(rows, nrow, integer(1)) > 0L
  available <- present & vapply(rows, function(row) {
    if (!nrow(row)) return(FALSE)
    tolower(phase15_nl_scalar(row, "availability_status", default = "unavailable")) == "available"
  }, logical(1))
  status <- if (all(available)) "available" else if (any(available)) "partial" else "unavailable"
  chosen <- rows[which(available)]
  chosen <- chosen[vapply(chosen, nrow, integer(1)) > 0L]
  values <- function(field, default = "") {
    if (!length(chosen)) return(default)
    values <- vapply(chosen, function(row) phase15_nl_scalar(row, field, default = default), character(1))
    values <- unique(values[nzchar(values)])
    if (length(values)) paste(values, collapse = "|") else default
  }
  reason <- vapply(rows, function(row) phase15_nl_scalar(row, "availability_reason", default = "no_eligible_form_history"), character(1))
  reason <- unique(reason[nzchar(reason)])
  list(
    status = status,
    window_type = values("window_type", if (length(reason)) reason[[1L]] else "no_eligible_form_history"),
    window_size = values("window_size", ""),
    cutoff_utc = values("feature_cutoff_utc", ""),
    reason = if (length(reason)) paste(reason, collapse = "|") else "no_eligible_form_history",
    rows = rows,
    available = available
  )
}

phase15_nl_forecast_row <- function(data, fixture_id) {
  if (!is.data.frame(data) || !nrow(data)) return(data[FALSE, , drop = FALSE] %||% data.frame(stringsAsFactors = FALSE))
  key <- if ("fixture_id" %in% names(data)) "fixture_id" else if ("match_id" %in% names(data)) "match_id" else NULL
  if (is.null(key)) return(data[FALSE, , drop = FALSE])
  rows <- data[as.character(data[[key]]) == as.character(fixture_id), , drop = FALSE]
  if (nrow(rows) > 1L) rows <- rows[1L, , drop = FALSE]
  rows
}

phase15_nl_form_parent_hash <- function(state_manifest, path) {
  hash <- phase15_nl_state_manifest_content_hash(state_manifest, path)
  if (nzchar(hash)) return(hash)
  ""
}

phase15_nl_build_fixture_forecast_form <- function(
    canonical_matches,
    forecast_status,
    forecasts,
    competition_form,
    all_international_form,
    state_manifest,
    score_distributions = NULL,
    source = list()) {
  schema <- phase15_nl_outcomes_schema()$fixture_forecast_form
  if (!is.data.frame(canonical_matches)) stop("Phase 15 fixture pass-through requires canonical matches", call. = FALSE)
  if (!nrow(canonical_matches)) return(phase15_nl_empty_table(schema))
  if (!"fixture_id" %in% names(canonical_matches)) stop("Phase 15 fixture pass-through requires fixture_id", call. = FALSE)
  parent <- list(
    state_manifest = phase15_nl_form_parent_hash(state_manifest, "audit/state_manifest.csv"),
    canonical_matches = phase15_nl_form_parent_hash(state_manifest, "state/canonical_matches.csv"),
    forecast_status = phase15_nl_form_parent_hash(state_manifest, "state/forecast_status.csv"),
    forecasts = phase15_nl_form_parent_hash(state_manifest, "state/forecasts.csv"),
    score_distributions = phase15_nl_form_parent_hash(state_manifest, "local/score_distributions.rds")
  )
  rows <- lapply(seq_len(nrow(canonical_matches)), function(index) {
    fixture <- canonical_matches[index, , drop = FALSE]
    fixture_id <- phase15_nl_scalar(fixture, "fixture_id", aliases = "match_id")
    status_row <- phase15_nl_forecast_row(forecast_status, fixture_id)
    forecast_row <- phase15_nl_forecast_row(forecasts, fixture_id)
    status <- phase15_nl_scalar(status_row, "forecast_status", default = phase15_nl_scalar(forecast_row, "forecast_status", default = "unavailable"))
    status <- tolower(status)
    suppression <- phase15_nl_scalar(status_row, "suppression_reason", default = phase15_nl_scalar(forecast_row, "suppression_reason", default = "none"))
    available <- identical(status, "available")
    home_team <- phase15_nl_scalar(fixture, "home_team_id")
    away_team <- phase15_nl_scalar(fixture, "away_team_id")
    competition <- phase15_nl_form_summary(competition_form, c(home_team, away_team))
    international <- phase15_nl_form_summary(all_international_form, c(home_team, away_team))
    feature_cutoff <- phase15_nl_scalar(status_row, "feature_cutoff_utc", default = phase15_nl_scalar(forecast_row, "feature_cutoff_utc"))
    model_cutoff <- phase15_nl_scalar(forecast_row, "model_data_cutoff", default = phase15_nl_scalar(status_row, "model_data_cutoff"))
    output <- phase15_nl_empty_table(schema)
    output[1L, ] <- list(
      phase15_nl_edition_id(), fixture_id, status, if (available) "none" else suppression,
      phase15_nl_scalar(forecast_row, "primary_probability_view", default = phase15_nl_scalar(status_row, "primary_probability_view")),
      if (available) phase15_nl_field(forecast_row, "p_home", n = 1L, default = NA_real_) else NA_real_,
      if (available) phase15_nl_field(forecast_row, "p_draw", n = 1L, default = NA_real_) else NA_real_,
      if (available) phase15_nl_field(forecast_row, "p_away", n = 1L, default = NA_real_) else NA_real_,
      if (available) phase15_nl_field(forecast_row, "expected_home_goals", n = 1L, default = NA_real_) else NA_real_,
      if (available) phase15_nl_field(forecast_row, "expected_away_goals", n = 1L, default = NA_real_) else NA_real_,
      phase15_nl_scalar(forecast_row, "model_id", default = phase15_nl_scalar(status_row, "model_id")),
      phase15_nl_scalar(forecast_row, "model_sha256", default = phase15_nl_scalar(status_row, "model_sha256")),
      phase15_nl_scalar(forecast_row, "model_release_id", default = phase15_nl_scalar(status_row, "model_release_id")),
      phase15_nl_scalar(forecast_row, "release_manifest_sha256", default = phase15_nl_scalar(status_row, "release_manifest_sha256")),
      phase15_nl_scalar(forecast_row, "release_selector_sha256", default = phase15_nl_scalar(status_row, "release_selector_sha256")),
      model_cutoff, if (nzchar(model_cutoff)) phase15_nl_sha256(model_cutoff) else "",
      feature_cutoff, if (nzchar(feature_cutoff)) phase15_nl_sha256(feature_cutoff) else "",
      competition$status, competition$window_type, competition$window_size, competition$cutoff_utc,
      parent$competition_form %||% phase15_nl_form_parent_hash(state_manifest, "state/competition_form.csv"),
      international$status, international$window_type, international$window_size, international$cutoff_utc,
      parent$all_international_form %||% phase15_nl_form_parent_hash(state_manifest, "state/all_international_form.csv"),
      phase15_nl_scalar(forecast_row, "source_bundle_id", default = phase15_nl_scalar(status_row, "source_bundle_id", default = source$source_bundle_id %||% "")),
      source$source_bundle_sha256 %||% "", parent$state_manifest, parent$canonical_matches,
      parent$forecast_status, parent$forecasts, parent$score_distributions, ""
    )
    output
  })
  output <- do.call(rbind, rows)
  # `parent$competition_form` and `parent$all_international_form` are optional
  # aliases in the local helper; fill them explicitly from the state manifest.
  output$competition_form_sha256 <- phase15_nl_form_parent_hash(state_manifest, "state/competition_form.csv")
  output$all_international_form_sha256 <- phase15_nl_form_parent_hash(state_manifest, "state/all_international_form.csv")
  if (nrow(output)) phase15_nl_add_row_hashes(output) else output
}

phase15_nl_manifest_lineage <- function(candidate) {
  state_manifest <- candidate$state_manifest %||% data.frame(stringsAsFactors = FALSE)
  source <- candidate$source %||% list()
  first <- if (is.data.frame(state_manifest) && nrow(state_manifest)) state_manifest[1L, , drop = FALSE] else data.frame(stringsAsFactors = FALSE)
  list(
    source_bundle_id = source$source_bundle_id %||% phase15_nl_scalar(first, "source_bundle_id"),
    source_bundle_sha256 = source$source_bundle_sha256 %||% phase15_nl_scalar(first, "source_bundle_sha256"),
    source_artifact_ids = source$source_artifact_ids %||% phase15_nl_scalar(first, "source_artifact_ids"),
    model_release_id = candidate$model_release_id %||% phase15_nl_scalar(first, "model_release_id"),
    release_manifest_sha256 = phase15_nl_scalar(first, "release_manifest_sha256"),
    release_selector_sha256 = phase15_nl_scalar(first, "release_selector_sha256"),
    model_id = phase15_nl_scalar(first, "model_id"),
    model_sha256 = phase15_nl_scalar(first, "model_sha256"),
    calibrator_id = phase15_nl_scalar(first, "calibrator_id"),
    calibrator_sha256 = phase15_nl_scalar(first, "calibrator_sha256"),
    model_data_cutoff = phase15_nl_scalar(first, "model_data_cutoff"),
    feature_cutoff_sha256 = phase15_nl_scalar(candidate$simulation_metadata, "feature_cutoff_sha256", default = phase15_nl_parent_value(candidate$parent_graph, "phase14_feature_cutoff")),
    ruleset_version = candidate$ruleset_version %||% "",
    ruleset_sha256 = candidate$ruleset_sha256 %||% "",
    draw_policy_id = candidate$draw_policy_id %||% phase15_nl_scalar(candidate$simulation_metadata, "draw_policy_id"),
    draw_policy_sha256 = candidate$draw_policy_sha256 %||% phase15_nl_scalar(candidate$simulation_metadata, "draw_policy_sha256"),
    simulation_seed = candidate$simulation_seed %||% phase15_nl_scalar(candidate$simulation_metadata, "simulation_seed"),
    simulation_count = candidate$simulation_count %||% phase15_nl_scalar(candidate$simulation_metadata, "simulation_count"),
    projection_run_id = candidate$projection_run_id %||% phase15_nl_scalar(candidate$simulation_metadata, "projection_run_id"),
    generated_at_utc = candidate$generated_at_utc %||% phase15_nl_scalar(candidate$simulation_metadata, "generated_at_utc")
  )
}

phase15_nl_manifest_parent_keys <- function(artifact_key) {
  artifact_key <- sub("\\.csv$", "", artifact_key)
  switch(
    artifact_key,
    competition_topology = c("source_bundle_manifest", "ruleset"),
    stage_slots = c("source_bundle_manifest", "stage_capture_manifest", "stage_capture_raw", "stage_capture_content", "ruleset", "simulation_metadata"),
    projected_standings = c("phase14_state_manifest", "phase14_canonical_matches", "source_bundle_manifest", "ruleset", "simulation_metadata"),
    projected_rankings = c("phase14_state_manifest", "phase14_canonical_matches", "source_bundle_manifest", "ruleset", "simulation_metadata"),
    transition_outcomes = c("phase14_state_manifest", "source_bundle_manifest", "ruleset", "model_release", "simulation_metadata"),
    team_path_probabilities = c("phase14_state_manifest", "source_bundle_manifest", "ruleset", "model_release", "simulation_metadata"),
    fixture_forecast_form = c("phase14_state_manifest", "phase14_canonical_matches", "phase14_forecast_status", "phase14_forecasts", "phase14_score_distributions", "source_bundle_manifest"),
    simulation_metadata = c("phase14_state_manifest", "phase14_forecast_status", "phase14_forecasts", "phase14_score_distributions", "source_bundle_manifest", "ruleset", "model_release"),
    character()
  )
}

phase15_nl_manifest_row <- function(path, table, candidate, lineage, parent_graph) {
  key <- phase15_nl_artifact_key(path)
  pairs <- phase15_nl_parent_pairs(parent_graph, phase15_nl_manifest_parent_keys(key))
  data.frame(
    edition_id = phase15_nl_edition_id(),
    artifact_path = path,
    artifact_type = "csv",
    row_count = as.integer(nrow(table)),
    content_sha256 = phase15_nl_table_content_hash(table),
    row_sha256 = "",
    parent_paths = paste(pairs$paths, collapse = "|"),
    parent_sha256 = paste(pairs$hashes, collapse = "|"),
    source_bundle_id = lineage$source_bundle_id,
    source_bundle_sha256 = lineage$source_bundle_sha256,
    source_artifact_ids = lineage$source_artifact_ids,
    model_release_id = lineage$model_release_id,
    release_manifest_sha256 = lineage$release_manifest_sha256,
    release_selector_sha256 = lineage$release_selector_sha256,
    model_id = lineage$model_id,
    model_sha256 = lineage$model_sha256,
    calibrator_id = lineage$calibrator_id,
    calibrator_sha256 = lineage$calibrator_sha256,
    model_data_cutoff = lineage$model_data_cutoff,
    feature_cutoff_sha256 = lineage$feature_cutoff_sha256,
    ruleset_version = lineage$ruleset_version,
    ruleset_sha256 = lineage$ruleset_sha256,
    draw_policy_id = lineage$draw_policy_id,
    draw_policy_sha256 = lineage$draw_policy_sha256,
    simulation_seed = lineage$simulation_seed,
    simulation_count = lineage$simulation_count,
    projection_run_id = lineage$projection_run_id,
    warnings = "none",
    failure_reason = "",
    validation_status = "candidate",
    generated_at_utc = lineage$generated_at_utc,
    manifest_sha256 = "",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

phase15_nl_outcomes_manifest_rows <- function(candidate, artifacts = NULL, generated_at_utc = NULL) {
  schema <- phase15_nl_outcomes_schema()$outcomes_manifest
  artifacts <- artifacts %||% candidate$artifacts %||% candidate$outcomes_artifacts
  expected <- phase15_nl_outcomes_expected_inventory()
  table_paths <- setdiff(expected, "outcomes/outcomes_manifest.csv")
  if (!is.list(artifacts) || !setequal(names(artifacts), table_paths)) stop("Phase 15 outcomes candidate must contain exactly eight non-manifest artifacts", call. = FALSE)
  lineage <- phase15_nl_manifest_lineage(candidate)
  parent_graph <- candidate$parent_graph %||% list()
  rows <- lapply(table_paths, function(path) {
    phase15_nl_manifest_row(path, artifacts[[path]], candidate, lineage, parent_graph)
  })
  manifest_row <- as.data.frame(setNames(lapply(schema, function(field) {
    if (field == "edition_id") return(phase15_nl_edition_id())
    if (field == "artifact_path") return("outcomes/outcomes_manifest.csv")
    if (field == "artifact_type") return("csv")
    if (field == "validation_status") return("candidate")
    if (field == "generated_at_utc") return(generated_at_utc %||% lineage$generated_at_utc)
    if (field == "source_bundle_id") return(lineage$source_bundle_id)
    if (field == "source_bundle_sha256") return(lineage$source_bundle_sha256)
    if (field == "source_artifact_ids") return(lineage$source_artifact_ids)
    if (field == "model_release_id") return(lineage$model_release_id)
    if (field == "release_manifest_sha256") return(lineage$release_manifest_sha256)
    if (field == "release_selector_sha256") return(lineage$release_selector_sha256)
    if (field == "model_id") return(lineage$model_id)
    if (field == "model_sha256") return(lineage$model_sha256)
    if (field == "calibrator_id") return(lineage$calibrator_id)
    if (field == "calibrator_sha256") return(lineage$calibrator_sha256)
    if (field == "model_data_cutoff") return(lineage$model_data_cutoff)
    if (field == "feature_cutoff_sha256") return(lineage$feature_cutoff_sha256)
    if (field == "ruleset_version") return(lineage$ruleset_version)
    if (field == "ruleset_sha256") return(lineage$ruleset_sha256)
    if (field == "draw_policy_id") return(lineage$draw_policy_id)
    if (field == "draw_policy_sha256") return(lineage$draw_policy_sha256)
    if (field == "simulation_seed") return(lineage$simulation_seed)
    if (field == "simulation_count") return(lineage$simulation_count)
    if (field == "projection_run_id") return(lineage$projection_run_id)
    ""
  }), schema), stringsAsFactors = FALSE, check.names = FALSE)
  names(manifest_row) <- schema
  output <- do.call(rbind, c(rows, list(manifest_row)))
  output <- output[, schema, drop = FALSE]
  row.names(output) <- NULL
  output
}

phase15_nl_attach_manifest <- function(candidate) {
  artifacts <- candidate$artifacts %||% candidate$outcomes_artifacts
  base <- phase15_nl_outcomes_manifest_rows(candidate, artifacts, candidate$generated_at_utc)
  base$manifest_sha256 <- ""
  base$validation_status <- "valid"
  self_index <- which(base$artifact_path == "outcomes/outcomes_manifest.csv")
  base$row_count[[self_index]] <- 0L
  base$content_sha256[[self_index]] <- ""
  manifest_hash <- phase15_nl_table_content_hash(base)
  base$manifest_sha256 <- manifest_hash
  base$row_count[[self_index]] <- nrow(base)
  base$content_sha256[[self_index]] <- manifest_hash
  base$row_sha256 <- phase15_nl_row_hashes(base)
  base <- base[, phase15_nl_outcomes_schema()$outcomes_manifest, drop = FALSE]
  artifacts[["outcomes/outcomes_manifest.csv"]] <- base
  candidate$artifacts <- artifacts
  candidate$outcomes_artifacts <- artifacts
  candidate$manifest <- base
  candidate$manifest_sha256 <- manifest_hash
  candidate$candidate_status <- "valid"
  candidate
}

phase15_nl_manifest_parent_lookup <- function(manifest, path) {
  row <- manifest[as.character(manifest$artifact_path) == path, , drop = FALSE]
  if (!nrow(row)) return(list())
  paths <- phase15_nl_text(row$parent_paths[[1L]], "")
  hashes <- phase15_nl_text(row$parent_sha256[[1L]], "")
  if (!nzchar(paths)) return(list())
  list(
    paths = strsplit(paths, "|", fixed = TRUE)[[1L]],
    hashes = strsplit(hashes, "|", fixed = TRUE)[[1L]]
  )
}

phase15_nl_validate_stage_slot_output <- function(table, rules_lineage) {
  if (!nrow(table)) return(invisible(TRUE))
  allowed <- c("official", "projected", "unresolved", "completed", "suppressed")
  status <- tolower(as.character(table$stage_status))
  if (any(is.na(status) | !status %in% allowed)) stop("Phase 15 stage slots contain an unsupported status", call. = FALSE)
  missing <- function(field) is.na(table[[field]]) | !nzchar(trimws(as.character(table[[field]])))
  if (any(status %in% c("official", "completed") & (missing("source_fixture_id") | missing("source_artifact_id")))) stop("Official/completed stage slots require source fixture and artifact lineage", call. = FALSE)
  if (any(status == "projected" & (missing("projection_run_id") | missing("draw_policy_id")))) stop("Projected stage slots require projection and draw-policy identity", call. = FALSE)
  if (any(status == "projected" & (!missing("source_fixture_id") | !missing("source_artifact_id")))) stop("Projected stage slots must not carry official fixture lineage", call. = FALSE)
  if (any(status == "unresolved" & missing("unresolved_reason"))) stop("Unresolved stage slots require unresolved_reason", call. = FALSE)
  if (any(status == "suppressed" & missing("suppression_reason"))) stop("Suppressed stage slots require suppression_reason", call. = FALSE)
  score_fields <- c("regulation_home_goals", "regulation_away_goals", "extra_time_home_goals", "extra_time_away_goals", "final_home_goals", "final_away_goals")
  for (field in score_fields) {
    numeric <- suppressWarnings(as.numeric(as.character(table[[field]])))
    present <- !missing(field)
    if (any(present & (is.na(numeric) | !is.finite(numeric) | numeric < 0 | numeric != floor(numeric)))) stop("Stage slot score fields must be non-negative integers", call. = FALSE)
    if (any(status != "completed" & present)) stop("Non-completed stage slots must not carry score fields", call. = FALSE)
  }
  completed <- status == "completed"
  if (any(completed & missing("completed_at_utc"))) stop("Completed stage slots require completed_at_utc", call. = FALSE)
  if (any(completed & as.numeric(table$final_home_goals) != as.numeric(table$regulation_home_goals) + as.numeric(table$extra_time_home_goals))) stop("Completed home final score must equal regulation plus extra time", call. = FALSE)
  if (any(completed & as.numeric(table$final_away_goals) != as.numeric(table$regulation_away_goals) + as.numeric(table$extra_time_away_goals))) stop("Completed away final score must equal regulation plus extra time", call. = FALSE)
  shootout_home <- suppressWarnings(as.numeric(as.character(table$penalty_shootout_home_goals)))
  shootout_away <- suppressWarnings(as.numeric(as.character(table$penalty_shootout_away_goals)))
  present_home <- !missing("penalty_shootout_home_goals")
  present_away <- !missing("penalty_shootout_away_goals")
  if (any(xor(present_home, present_away))) stop("Stage shootout scores must be supplied as a pair", call. = FALSE)
  if (any((present_home | present_away) & (!completed | table$final_home_goals != table$final_away_goals))) stop("Stage shootout scores require a tied completed score", call. = FALSE)
  if (any(tolower(as.character(table$ruleset_version)) != rules_lineage$ruleset_version) || any(tolower(as.character(table$ruleset_sha256)) != tolower(rules_lineage$ruleset_sha256))) stop("Stage slot ruleset lineage mismatch", call. = FALSE)
  invisible(TRUE)
}

phase15_nl_validate_probability_groups <- function(table, group_fields, name, tolerance = 1e-7) {
  if (!is.data.frame(table) || !nrow(table) || !"probability" %in% names(table)) return(invisible(TRUE))
  probabilities <- suppressWarnings(as.numeric(as.character(table$probability)))
  present <- !is.na(probabilities)
  if (any(present & (probabilities < -tolerance | probabilities > 1 + tolerance))) stop("Phase 15 ", name, " contains a probability outside [0,1]", call. = FALSE)
  if (!all(present)) return(invisible(TRUE))
  groups <- interaction(table[group_fields], drop = TRUE, lex.order = TRUE, sep = "::")
  sums <- tapply(probabilities, groups, sum)
  if (any(abs(as.numeric(sums) - 1) > tolerance)) stop("Phase 15 ", name, " probabilities are not conserved", call. = FALSE)
  invisible(TRUE)
}

phase15_nl_validate_outcomes_manifest <- function(manifest, artifacts, candidate = NULL) {
  schema <- phase15_nl_outcomes_schema()$outcomes_manifest
  phase15_nl_require_schema(manifest, schema, "outcomes manifest")
  expected <- phase15_nl_outcomes_expected_inventory()
  if (!identical(as.character(manifest$artifact_path), expected)) stop("Phase 15 outcomes manifest has an unexpected or reordered inventory", call. = FALSE)
  if (any(as.character(manifest$edition_id) != phase15_nl_edition_id())) stop("Phase 15 outcomes manifest has a foreign edition", call. = FALSE)
  phase15_nl_assert_hash(manifest$content_sha256[seq_len(nrow(manifest) - 1L)], "outcomes content", allow_empty = FALSE)
  phase15_nl_assert_hash(manifest$ruleset_sha256, "outcomes ruleset")
  phase15_nl_assert_hash(manifest$source_bundle_sha256, "outcomes source bundle")
  for (field in c("release_manifest_sha256", "release_selector_sha256", "model_sha256", "calibrator_sha256", "draw_policy_sha256", "feature_cutoff_sha256")) {
    values <- as.character(manifest[[field]])
    values <- values[!is.na(values) & nzchar(values)]
    if (length(values)) phase15_nl_assert_hash(values, paste0("outcomes ", field))
  }
  if (any(is.na(as.integer(manifest$row_count)) | as.integer(manifest$row_count) < 0L)) stop("Outcomes manifest row counts are invalid", call. = FALSE)
  for (path in setdiff(expected, "outcomes/outcomes_manifest.csv")) {
    row <- manifest[as.character(manifest$artifact_path) == path, , drop = FALSE]
    table <- artifacts[[path]]
    if (nrow(row) != 1L || !is.data.frame(table)) stop("Outcomes manifest/artifact link is incomplete: ", path, call. = FALSE)
    if (!identical(as.integer(row$row_count[[1L]]), as.integer(nrow(table)))) stop("Outcomes row count mismatch: ", path, call. = FALSE)
    if (!identical(tolower(as.character(row$content_sha256[[1L]])), phase15_nl_table_content_hash(table))) stop("Outcomes content hash mismatch: ", path, call. = FALSE)
    parents <- phase15_nl_manifest_parent_lookup(manifest, path)
    if (!length(parents$paths) || length(parents$paths) != length(parents$hashes) || any(!grepl("^[0-9a-fA-F]{64}$", parents$hashes))) stop("Outcomes artifact is missing complete parent hashes: ", path, call. = FALSE)
  }
  self_index <- which(manifest$artifact_path == "outcomes/outcomes_manifest.csv")
  if (length(self_index) != 1L) stop("Outcomes manifest is missing its self row", call. = FALSE)
  manifest_hashes <- unique(as.character(manifest$manifest_sha256))
  if (length(manifest_hashes) != 1L || !grepl("^[0-9a-fA-F]{64}$", manifest_hashes[[1L]])) stop("Outcomes manifest self hash is invalid", call. = FALSE)
  if (!identical(as.character(manifest$content_sha256[[self_index]]), manifest_hashes[[1L]]) ||
      !identical(as.integer(manifest$row_count[[self_index]]), as.integer(nrow(manifest)))) stop("Outcomes manifest self row is inconsistent", call. = FALSE)
  seed <- manifest
  seed$manifest_sha256 <- ""
  seed$row_count[[self_index]] <- 0L
  seed$content_sha256[[self_index]] <- ""
  seed$row_sha256 <- ""
  if (!identical(tolower(phase15_nl_table_content_hash(seed)), tolower(manifest_hashes[[1L]]))) stop("Outcomes manifest self hash mismatch", call. = FALSE)
  if (nrow(manifest)) {
    expected_manifest_rows <- phase15_nl_row_hashes(manifest)
    if (any(as.character(manifest$row_sha256) != expected_manifest_rows)) stop("Outcomes manifest row self-hash mismatch", call. = FALSE)
  }
  invisible(TRUE)
}

phase15_validate_nl_outcomes_bundle <- function(bundle) {
  if (!is.list(bundle)) stop("Phase 15 outcomes validator requires a candidate or bundle", call. = FALSE)
  artifacts <- bundle$artifacts %||% bundle$outcomes_artifacts
  manifest <- bundle$manifest %||% artifacts[["outcomes/outcomes_manifest.csv"]]
  expected <- phase15_nl_outcomes_expected_inventory()
  if (!is.list(artifacts) || !setequal(names(artifacts), expected)) stop("Phase 15 outcomes candidate must contain exactly the nine-file sibling inventory", call. = FALSE)
  if (!is.data.frame(manifest)) stop("Phase 15 outcomes candidate is missing outcomes_manifest.csv", call. = FALSE)
  schemas <- phase15_nl_outcomes_schema()
  for (path in setdiff(expected, "outcomes/outcomes_manifest.csv")) {
    key <- phase15_nl_artifact_key(path)
    key <- sub("\\.csv$", "", key)
    phase15_nl_require_schema(artifacts[[path]], schemas[[key]], path)
    table <- artifacts[[path]]
    if (nrow(table) && any(as.character(table$edition_id) != phase15_nl_edition_id())) stop("Phase 15 outcomes artifact has a foreign edition: ", path, call. = FALSE)
    if (nrow(table) && any(!grepl("^[0-9a-fA-F]{64}$", as.character(table$row_sha256)))) stop("Phase 15 outcomes artifact has invalid row hashes: ", path, call. = FALSE)
    if (nrow(table) && any(as.character(table$row_sha256) != phase15_nl_row_hashes(table))) stop("Phase 15 outcomes artifact row hash mismatch: ", path, call. = FALSE)
  }
  rules_lineage <- list(
    ruleset_version = bundle$ruleset_version %||% phase15_nl_scalar(bundle$simulation_metadata, "ruleset_version"),
    ruleset_sha256 = bundle$ruleset_sha256 %||% phase15_nl_scalar(bundle$simulation_metadata, "ruleset_sha256")
  )
  phase15_nl_validate_stage_slot_output(artifacts[["outcomes/stage_slots.csv"]], rules_lineage)
  phase15_nl_validate_probability_groups(artifacts[["outcomes/projected_standings.csv"]], c("league", "group_id", "rank"), "projected standings")
  phase15_nl_validate_probability_groups(artifacts[["outcomes/projected_rankings.csv"]], c("ranking_scope", "rank"), "projected rankings")
  for (field in c("p_quarter_final", "p_semi_final", "p_third_place", "p_final", "p_champion", "p_direct_promotion", "p_direct_relegation", "p_playoff_eligibility", "p_playoff_win", "p_playoff_loss")) {
    values <- suppressWarnings(as.numeric(as.character(artifacts[["outcomes/team_path_probabilities.csv"]][[field]])))
    if (any(!is.na(values) & (values < 0 | values > 1))) stop("Team path probability is outside [0,1]: ", field, call. = FALSE)
  }
  phase15_nl_validate_outcomes_manifest(manifest, artifacts, bundle)
  invisible(TRUE)
}

phase15_nl_validate_output_root <- function(output_root, project_root = ".") {
  if (!is.character(output_root) || length(output_root) != 1L || is.na(output_root) || !nzchar(output_root)) stop("Phase 15 outcomes writer requires one output root", call. = FALSE)
  raw <- output_root
  root <- normalizePath(raw, winslash = "/", mustWork = FALSE)
  if (isTRUE(attr(raw, "phase15_registered"))) {
    temp_root <- normalizePath(tempdir(), winslash = "/", mustWork = TRUE)
    if (identical(root, temp_root) || !startsWith(root, paste0(temp_root, "/"))) stop("Test outcomes roots must be registered children of tempdir()", call. = FALSE)
    return(root)
  }
  registered <- phase15_nl_registered_outcomes_root(project_root)
  if (!identical(root, registered)) stop("Phase 15 outcomes writer accepts only the registered Nations League outcomes root", call. = FALSE)
  root
}

phase15_write_nl_outcomes_bundle <- function(candidate, output_root = NULL, project_root = ".") {
  if (is.null(output_root)) output_root <- phase15_nl_registered_outcomes_root(project_root)
  phase15_validate_nl_outcomes_bundle(candidate)
  root <- phase15_nl_validate_output_root(output_root, project_root)
  parent <- dirname(root)
  dir.create(parent, recursive = TRUE, showWarnings = FALSE)
  existing <- if (dir.exists(root)) gsub("\\\\", "/", list.files(root, recursive = TRUE, all.files = FALSE, include.dirs = FALSE)) else character()
  expected_files <- sub("^outcomes/", "", phase15_nl_outcomes_expected_inventory())
  if (length(existing) && !setequal(existing, expected_files)) stop("Existing Phase 15 outcomes root contains an unexpected file", call. = FALSE)
  staging <- tempfile(".outcomes-staging-", tmpdir = parent)
  dir.create(staging, recursive = TRUE, showWarnings = FALSE)
  on.exit(if (dir.exists(staging)) unlink(staging, recursive = TRUE), add = TRUE)
  artifacts <- candidate$artifacts %||% candidate$outcomes_artifacts
  for (path in phase15_nl_outcomes_expected_inventory()) {
    relative <- sub("^outcomes/", "", path)
    target <- file.path(staging, relative)
    dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
    table <- artifacts[[path]]
    if (exists("phase13_publication_write_csv", mode = "function", inherits = TRUE)) {
      phase13_publication_write_csv(table, target)
    } else {
      utils::write.csv(table, target, row.names = FALSE, na = "", quote = TRUE)
    }
  }
  backup <- tempfile(".outcomes-backup-", tmpdir = parent)
  had_existing <- dir.exists(root)
  if (had_existing && !file.rename(root, backup)) stop("Could not stage the existing Nations League outcomes root", call. = FALSE)
  promoted <- file.rename(staging, root)
  if (!promoted) {
    if (had_existing) file.rename(backup, root)
    stop("Could not atomically promote the Nations League outcomes root", call. = FALSE)
  }
  if (had_existing && dir.exists(backup)) unlink(backup, recursive = TRUE)
  output <- phase15_nl_read_outcomes_bundle(root, validate = TRUE)
  output$written_root <- root
  output
}

phase15_nl_read_outcomes_bundle <- function(root = NULL, project_root = ".", validate = TRUE) {
  root <- root %||% phase15_nl_registered_outcomes_root(project_root)
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  if (basename(root) != "outcomes" && !file.exists(file.path(root, "competition_topology.csv"))) root <- file.path(root, "outcomes")
  expected <- phase15_nl_outcomes_expected_inventory()
  relative <- sub("^outcomes/", "", expected)
  present <- gsub("\\\\", "/", list.files(root, recursive = TRUE, all.files = FALSE, include.dirs = FALSE))
  if (!setequal(present, relative)) stop("Phase 15 outcomes durable bundle must contain exactly nine files", call. = FALSE)
  artifacts <- lapply(relative, function(path) phase15_nl_read_csv(file.path(root, path), path))
  names(artifacts) <- expected
  manifest <- artifacts[["outcomes/outcomes_manifest.csv"]]
  bundle <- list(
    edition_id = phase15_nl_edition_id(),
    root = root,
    artifacts = artifacts,
    outcomes_artifacts = artifacts,
    manifest = manifest,
    fixture_forecast_form = artifacts[["outcomes/fixture_forecast_form.csv"]],
    simulation_metadata = artifacts[["outcomes/simulation_metadata.csv"]],
    ruleset_version = phase15_nl_scalar(manifest, "ruleset_version"),
    ruleset_sha256 = phase15_nl_scalar(manifest, "ruleset_sha256"),
    manifest_sha256 = phase15_nl_scalar(manifest, "manifest_sha256")
  )
  if (isTRUE(validate)) phase15_validate_nl_outcomes_bundle(bundle)
  bundle
}
