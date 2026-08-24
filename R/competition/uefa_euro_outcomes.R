#' Phase 15 EURO qualifying outcome publication contract.
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

phase16_euro_edition_id <- function() {
  "uefa_nations_league_2026_27"
}

phase16_euro_outcomes_expected_inventory <- function() {
  file.path(
    "outcomes",
    c(
      "competition_topology.csv",
      "stage_slots.csv",
      "projected_standings.csv",
      "projected_rankings.csv",
      "qualification_ledger.csv",
      "team_path_probabilities.csv",
      "fixture_forecast_form.csv",
      "simulation_metadata.csv",
      "outcomes_manifest.csv"
    )
  )
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

phase16_euro_empty_table <- function(schema) {
  output <- as.data.frame(setNames(lapply(schema, function(field) character()), schema), stringsAsFactors = FALSE, check.names = FALSE)
  row.names(output) <- integer()
  output
}

phase16_euro_field <- function(data, field, n = if (is.data.frame(data)) nrow(data) else 0L, default = "", aliases = character()) {
  candidates <- unique(c(field, aliases))
  found <- candidates[candidates %in% names(data)]
  if (length(found)) return(data[[found[[1L]]]])
  rep(default, n)
}

phase16_euro_scalar <- function(data, field, default = "", aliases = character()) {
  value <- phase16_euro_field(data, field, n = 1L, default = default, aliases = aliases)
  if (!length(value) || is.na(value[[1L]])) return(default)
  as.character(value[[1L]])
}

phase16_euro_text <- function(value, default = "") {
  if (is.null(value) || !length(value) || is.na(value[[1L]])) return(default)
  value <- trimws(as.character(value[[1L]]))
  if (!nzchar(value)) default else value
}

phase16_euro_sha256 <- function(value, serialize = FALSE) {
  if (!requireNamespace("digest", quietly = TRUE)) stop("digest is required for Phase 15 outcomes hashes", call. = FALSE)
  if (is.raw(value)) return(tolower(digest::digest(value, algo = "sha256", serialize = FALSE)))
  tolower(digest::digest(value, algo = "sha256", serialize = serialize))
}

phase16_euro_canonical_scalar <- function(value) {
  if (length(value) == 0L || is.na(value[[1L]])) return("")
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

phase16_euro_sort_table <- function(data) {
  if (!is.data.frame(data)) stop("Phase 15 outcomes artifact must be a data frame", call. = FALSE)
  if (exists("phase13_publication_sort_table", mode = "function", inherits = TRUE)) {
    return(phase13_publication_sort_table(data))
  }
  hash_col <- if ("row_sha256" %in% names(data)) "row_sha256" else NULL
  fields <- setdiff(names(data), hash_col)
  if (nrow(data) > 1L && length(fields)) {
    values <- lapply(data[fields], function(column) vapply(column, phase16_euro_canonical_scalar, character(1)))
    data <- data[do.call(order, c(values, list(na.last = TRUE, method = "radix"))), , drop = FALSE]
  }
  row.names(data) <- NULL
  data
}

phase16_euro_add_row_hashes <- function(data) {
  if (!is.data.frame(data)) stop("Phase 15 outcomes row hashing requires a data frame", call. = FALSE)
  if (!"row_sha256" %in% names(data)) stop("Phase 15 outcomes artifact requires row_sha256", call. = FALSE)
  data$row_sha256 <- ""
  data$row_sha256 <- phase16_euro_row_hashes(data)
  phase16_euro_sort_table(data)
}

phase16_euro_csv_bytes <- function(data) {
  canonical <- as.data.frame(lapply(data, function(column) {
    values <- vapply(column, phase16_euro_canonical_scalar, character(1))
    values[!nzchar(values)] <- NA_character_
    values
  }), stringsAsFactors = FALSE, check.names = FALSE)
  path <- tempfile("phase15-outcomes-", fileext = ".csv")
  on.exit(if (file.exists(path)) unlink(path), add = TRUE)
  utils::write.csv(canonical, path, row.names = FALSE, na = "", quote = TRUE)
  readBin(path, what = "raw", n = file.info(path)$size)
}

phase16_euro_table_content_hash <- function(data) {
  phase16_euro_sha256(phase16_euro_csv_bytes(data))
}

phase16_euro_artifact_key <- function(path) {
  path <- gsub("\\\\", "/", as.character(path))
  sub("^outcomes/", "", path)
}

phase16_euro_artifact_type <- function(path) {
  key <- phase16_euro_artifact_key(path)
  if (identical(key, "outcomes_manifest.csv")) return("manifest")
  sub("\\.csv$", "", key)
}

phase16_euro_competition_root <- function(project_root = ".") {
  root <- normalizePath(project_root, winslash = "/", mustWork = FALSE)
  edition <- phase16_euro_edition_id()
  if (basename(root) == edition && dir.exists(file.path(root, "state"))) return(root)
  candidate <- file.path(root, "outputs", "competition", edition)
  if (dir.exists(file.path(root, "state")) && dir.exists(file.path(root, "audit"))) return(root)
  normalizePath(candidate, winslash = "/", mustWork = FALSE)
}

phase16_euro_registered_outcomes_root <- function(project_root = ".") {
  root <- phase16_euro_competition_root(project_root)
  outcomes <- normalizePath(file.path(root, "outcomes"), winslash = "/", mustWork = FALSE)
  if (isTRUE(attr(project_root, "phase15_registered"))) return(outcomes)
  registered <- normalizePath(file.path(phase16_euro_competition_root(project_root), "outcomes"), winslash = "/", mustWork = FALSE)
  if (!identical(outcomes, registered)) stop("Phase 15 outcomes root is not the registered EURO qualifying sibling directory", call. = FALSE)
  outcomes
}

phase16_euro_read_csv <- function(path, name = basename(path)) {
  if (!file.exists(path)) stop("Phase 15 outcomes file is missing: ", name, call. = FALSE)
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
}

phase16_euro_require_schema <- function(data, schema, name) {
  if (!is.data.frame(data) || !identical(names(data), schema)) {
    stop("Phase 15 ", name, " schema mismatch; expected exact columns", call. = FALSE)
  }
  invisible(data)
}

phase16_euro_parent_value <- function(parent_graph, key, default = "") {
  value <- if (is.list(parent_graph)) parent_graph[[key]] else NULL
  if (is.list(value) && !is.null(value$sha256)) value <- value$sha256
  phase16_euro_text(value, default)
}

phase16_euro_parent_path <- function(parent_graph, key, default = "") {
  value <- if (is.list(parent_graph)) parent_graph[[key]] else NULL
  if (is.list(value) && !is.null(value$path)) value <- value$path
  phase16_euro_text(value, default)
}

phase16_euro_parent_pairs <- function(parent_graph, keys) {
  keys <- keys[keys %in% names(parent_graph)]
  keys <- keys[vapply(keys, function(key) nzchar(phase16_euro_parent_value(parent_graph, key)), logical(1))]
  list(
    paths = vapply(keys, function(key) phase16_euro_parent_path(parent_graph, key, key), character(1)),
    hashes = vapply(keys, function(key) phase16_euro_parent_value(parent_graph, key), character(1))
  )
}

phase16_euro_assert_hash <- function(value, name, allow_empty = FALSE) {
  value <- as.character(value)
  if (allow_empty && all(is.na(value) | !nzchar(trimws(value)))) return(invisible(TRUE))
  if (any(is.na(value) | !grepl("^[0-9a-fA-F]{64}$", value))) stop("Phase 15 ", name, " must contain SHA-256 hashes", call. = FALSE)
  invisible(TRUE)
}

phase16_euro_repo_root <- function(project_root = ".") {
  root <- normalizePath(project_root, winslash = "/", mustWork = FALSE)
  if (dir.exists(file.path(root, "data/competition"))) return(root)
  if (basename(root) == phase16_euro_edition_id()) {
    candidate <- dirname(dirname(dirname(dirname(root))))
    if (dir.exists(file.path(candidate, "data/competition"))) return(candidate)
  }
  if (exists("phase13_source_find_project_root", mode = "function", inherits = TRUE)) {
    return(phase13_source_find_project_root(root))
  }
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

phase16_euro_read_source_bundle <- function(
    project_root = ".",
    edition_id = phase16_euro_edition_id()) {
  root <- phase16_euro_repo_root(project_root)
  edition_id <- phase16_euro_text(edition_id)
  if (!identical(edition_id, phase16_euro_edition_id())) stop("Phase 15 outcomes source bundle requires the EURO qualifying edition", call. = FALSE)
  registry_root <- file.path(root, "data/competition/registries")
  accepted_root <- file.path(root, "data/competition/accepted", edition_id)
  bundle_path <- file.path(registry_root, "source_bundles.csv")
  artifacts_path <- file.path(registry_root, "source_artifacts.csv")
  edition_path <- file.path(registry_root, "competition_editions.csv")
  manifest_path <- file.path(accepted_root, "source_bundle_manifest.csv")
  required_paths <- c(bundle_path, artifacts_path, edition_path, manifest_path)
  if (any(!file.exists(required_paths))) stop("Phase 15 accepted source lineage is incomplete", call. = FALSE)
  bundles <- phase16_euro_read_csv(bundle_path, "source bundle registry")
  artifacts <- phase16_euro_read_csv(artifacts_path, "source artifact registry")
  editions <- phase16_euro_read_csv(edition_path, "competition edition registry")
  manifest <- phase16_euro_read_csv(manifest_path, "accepted source bundle manifest")
  if (!"edition_id" %in% names(editions) || !any(as.character(editions$edition_id) == edition_id)) {
    stop("Phase 15 accepted source lineage has no registered EURO qualifying edition", call. = FALSE)
  }
  bundle_rows <- bundles[as.character(bundles$edition_id) == edition_id, , drop = FALSE]
  if (nrow(bundle_rows) != 1L) stop("Phase 15 accepted source bundle registry requires one EURO qualifying row", call. = FALSE)
  bundle <- bundle_rows[1L, , drop = FALSE]
  bundle_id <- phase16_euro_scalar(bundle, "bundle_id", aliases = "source_bundle_id")
  bundle_status <- tolower(phase16_euro_scalar(bundle, "bundle_status"))
  acceptance <- tolower(phase16_euro_scalar(bundle, "acceptance_state"))
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
    phase16_euro_field(bundle, "source_bundle_sha256"),
    phase16_euro_field(manifest, "source_bundle_sha256")
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
    table <- phase16_euro_read_csv(path, paste0("accepted ", type, " source"))
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

phase16_euro_phase14_hash_value <- function(value) {
  if (exists("phase14_state_bundle_hash_value", mode = "function", inherits = TRUE)) {
    return(phase14_state_bundle_hash_value(value))
  }
  if (is.data.frame(value)) return(phase16_euro_table_content_hash(value))
  phase16_euro_sha256(value, serialize = TRUE)
}

phase16_euro_state_manifest_seed_hash <- function(manifest, artifacts, expected) {
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
    paste(phase16_euro_row_hashes(value), collapse = "|")
  }, character(1))
  phase16_euro_phase14_hash_value(base)
}

phase16_euro_state_manifest_row_hashes <- function(manifest) {
  if (!is.data.frame(manifest) || !nrow(manifest)) return(character())
  if (!"row_sha256" %in% names(manifest)) stop("Phase 14 state manifest is missing row_sha256", call. = FALSE)
  vapply(seq_len(nrow(manifest)), function(index) {
    row <- manifest[index, , drop = FALSE]
    row$row_sha256 <- ""
    phase16_euro_phase14_hash_value(row)
  }, character(1))
}

phase16_euro_read_phase14_state_bundle <- function(
    project_root = ".",
    state_root = NULL,
    edition_id = phase16_euro_edition_id()) {
  root <- normalizePath(state_root %||% phase16_euro_competition_root(project_root), winslash = "/", mustWork = TRUE)
  if (basename(root) != phase16_euro_edition_id() && !dir.exists(file.path(root, "state"))) {
    stop("Phase 15 Phase 14 parent must be the registered EURO qualifying state root", call. = FALSE)
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
    if (identical(path, "local/score_distributions.rds")) readRDS(full) else phase16_euro_read_csv(full, path)
  })
  names(artifacts) <- expected
  manifest <- artifacts[["audit/state_manifest.csv"]]
  manifest_required <- c(
    "edition_id", "artifact_path", "artifact_type", "row_count", "content_sha256", "row_sha256",
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
  expected_types <- ifelse(expected == "local/score_distributions.rds", "rds", "csv")
  if (!identical(as.character(manifest$artifact_type), expected_types)) {
    stop("Phase 14 state manifest artifact types do not match the registered inventory", call. = FALSE)
  }
  row_counts <- suppressWarnings(as.integer(as.character(manifest$row_count)))
  if (any(is.na(row_counts) | row_counts < 0L)) stop("Phase 14 state manifest row counts are invalid", call. = FALSE)
  phase16_euro_assert_hash(manifest$content_sha256, "Phase 14 state artifact content hashes")
  phase16_euro_assert_hash(manifest$row_sha256, "Phase 14 state manifest row hashes")
  manifest_hashes <- unique(as.character(manifest$manifest_sha256))
  manifest_hashes <- manifest_hashes[!is.na(manifest_hashes) & nzchar(manifest_hashes)]
  if (length(manifest_hashes) != 1L) stop("Phase 14 state manifest self identity is not unique", call. = FALSE)
  phase16_euro_assert_hash(manifest_hashes, "Phase 14 state manifest self identity")
  self_index <- match("audit/state_manifest.csv", expected)
  if (!identical(as.character(manifest$content_sha256[[self_index]]), manifest_hashes[[1L]]) ||
      !identical(as.integer(manifest$row_count[[self_index]]), as.integer(nrow(manifest)))) {
    stop("Phase 14 state manifest self row is inconsistent", call. = FALSE)
  }
  recomputed_manifest_hash <- phase16_euro_state_manifest_seed_hash(manifest, artifacts, expected)
  if (!identical(tolower(recomputed_manifest_hash), tolower(manifest_hashes[[1L]]))) {
    stop("Phase 14 state manifest self-hash mismatch", call. = FALSE)
  }
  expected_manifest_row_hashes <- phase16_euro_state_manifest_row_hashes(manifest)
  if (any(tolower(as.character(manifest$row_sha256)) != tolower(expected_manifest_row_hashes))) {
    stop("Phase 14 state manifest row hash mismatch", call. = FALSE)
  }
  for (index in seq_along(expected)) {
    path <- expected[[index]]
    value <- artifacts[[path]]
    if (!identical(as.integer(manifest$row_count[[index]]), if (is.data.frame(value)) as.integer(nrow(value)) else 1L)) {
      stop("Phase 14 state row count mismatch: ", path, call. = FALSE)
    }
    expected_hash <- if (identical(path, "audit/state_manifest.csv")) manifest_hashes[[1L]] else phase16_euro_phase14_hash_value(value)
    if (!identical(tolower(as.character(manifest$content_sha256[[index]])), tolower(expected_hash))) {
      stop("Phase 14 state content hash mismatch: ", path, call. = FALSE)
    }
    parent_paths <- phase16_euro_text(manifest$parent_paths[[index]], "")
    parent_hashes <- phase16_euro_text(manifest$parent_sha256[[index]], "")
    if (nzchar(parent_paths)) {
      parents <- strsplit(parent_paths, "|", fixed = TRUE)[[1L]]
      hashes <- strsplit(parent_hashes, "|", fixed = TRUE)[[1L]]
      if (length(parents) != length(hashes) || any(!parents %in% expected)) stop("Phase 14 state parent graph is invalid: ", path, call. = FALSE)
      observed <- vapply(parents, function(parent) phase16_euro_phase14_hash_value(artifacts[[parent]]), character(1))
      if (!identical(tolower(paste(observed, collapse = "|")), tolower(paste(hashes, collapse = "|")))) {
        stop("Phase 14 state parent hash mismatch: ", path, call. = FALSE)
      }
    }
  }
  source <- phase16_euro_read_source_bundle(project_root = project_root, edition_id = edition_id)
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
    if (grepl("sha256", field)) phase16_euro_assert_hash(values, paste0("Phase 14 ", field))
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

phase16_euro_rules_lineage <- function(rules = NULL) {
  rules <- rules %||% if (exists("uefa_nl_2026_27_rules", mode = "function", inherits = TRUE)) uefa_nl_2026_27_rules() else list()
  version <- if (exists("uefa_nl_ruleset_version", mode = "function", inherits = TRUE)) uefa_nl_ruleset_version() else phase16_euro_text(rules$ruleset_version, "phase15-nations-league-rules-v1")
  hash <- if (exists("uefa_nl_ruleset_sha256", mode = "function", inherits = TRUE)) {
    uefa_nl_ruleset_sha256(rules)
  } else {
    phase16_euro_sha256(rules, serialize = TRUE)
  }
  list(rules = rules, ruleset_version = version, ruleset_sha256 = tolower(hash))
}

phase16_euro_simulation_metadata_row <- function(simulation) {
  metadata <- simulation$simulation_metadata %||% simulation$metadata$simulation_metadata %||% data.frame(stringsAsFactors = FALSE)
  if (is.data.frame(metadata) && nrow(metadata)) return(metadata[1L, , drop = FALSE])
  if (is.list(metadata) && !is.data.frame(metadata)) return(as.data.frame(metadata, stringsAsFactors = FALSE, check.names = FALSE))
  data.frame(stringsAsFactors = FALSE)
}

phase16_euro_stage_type <- function(stage_id, topology = NULL, rules = NULL) {
  stage_id <- as.character(stage_id)
  if (!is.null(topology) && is.data.frame(topology) && "stage_id" %in% names(topology) && "stage_type" %in% names(topology)) {
    value <- as.character(topology$stage_type[match(stage_id, as.character(topology$stage_id))])
    if (!is.na(value) && nzchar(value)) return(value)
  }
  if (is.list(topology) && is.data.frame(topology$stage_topology)) return(phase16_euro_stage_type(stage_id, topology$stage_topology, rules))
  if (is.list(rules) && is.data.frame(rules$stage_topology)) return(phase16_euro_stage_type(stage_id, rules$stage_topology, rules))
  if (exists("uefa_nl_stage_topology", mode = "function", inherits = TRUE)) {
    table <- uefa_nl_stage_topology()
    value <- as.character(table$stage_type[match(stage_id, as.character(table$stage_id))])
    if (!is.na(value) && nzchar(value)) return(value)
  }
  ""
}

phase16_euro_topology_table <- function(topology, source, rules_lineage) {
  schema <- phase16_euro_outcomes_schema()$competition_topology
  rows <- phase16_euro_empty_table(schema)
  groups <- if (is.list(topology)) topology$groups else topology
  teams <- if (is.list(topology)) topology$teams else NULL
  fixtures <- if (is.list(topology)) topology$fixtures else NULL
  if (is.null(groups) || !is.data.frame(groups)) groups <- source$groups %||% data.frame(stringsAsFactors = FALSE)
  if (is.null(teams) || !is.data.frame(teams) || !nrow(teams)) {
    stop("EURO qualifying topology requires a non-empty team table", call. = FALSE)
  }
  if (is.null(fixtures) || !is.data.frame(fixtures)) fixtures <- source$fixtures %||% data.frame(stringsAsFactors = FALSE)
  if (nrow(groups)) {
    group_field <- if ("group_id" %in% names(groups)) "group_id" else if ("source_group_id" %in% names(groups)) "source_group_id" else NULL
    if (is.null(group_field)) stop("EURO qualifying topology groups require group_id", call. = FALSE)
    team_group_field <- if ("group_id" %in% names(teams)) "group_id" else if ("source_group_id" %in% names(teams)) "source_group_id" else NULL
    if (is.null(team_group_field)) stop("EURO qualifying topology teams require group_id", call. = FALSE)
    group_ids <- unique(as.character(groups[[group_field]]))
    group_ids <- group_ids[!is.na(group_ids) & nzchar(group_ids)]
    group_rows <- lapply(group_ids, function(group_id) {
      group <- groups[as.character(groups[[group_field]]) == group_id, , drop = FALSE]
      league <- toupper(phase16_euro_scalar(group, "league"))
      team_count <- sum(as.character(teams[[team_group_field]]) == group_id, na.rm = TRUE)
      expected_team_count <- if (identical(league, "D")) 3L else if (league %in% c("A", "B", "C")) 4L else NA_integer_
      if (is.na(expected_team_count) || team_count != expected_team_count) {
        stop(sprintf(
          "EURO qualifying topology group %s has %d teams; expected %d for league %s",
          group_id, team_count, expected_team_count, league
        ), call. = FALSE)
      }
      fixture_group_field <- if ("group_id" %in% names(fixtures)) "group_id" else if ("source_group_id" %in% names(fixtures)) "source_group_id" else NULL
      fixture_count <- if (!is.null(fixture_group_field)) sum(as.character(fixtures[[fixture_group_field]]) == group_id, na.rm = TRUE) else 0L
      row <- phase16_euro_empty_table(schema)
      row[1L, ] <- list(
        phase16_euro_edition_id(), "group", league, group_id,
        phase16_euro_scalar(group, "display_name", aliases = "name"),
        team_count, fixture_count, "", "", "", "", "", "", "", "", "",
        source$source_bundle_id %||% "",
        paste(unique(as.character(phase16_euro_field(group, "source_artifact_id"))), collapse = "|"),
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
      row <- phase16_euro_empty_table(schema)
      row[1L, ] <- list(
        phase16_euro_edition_id(), "stage", "", "", "", 0L, 0L,
        phase16_euro_scalar(stage, "stage_id"), phase16_euro_scalar(stage, "stage_type"),
        phase16_euro_field(stage, "legs", n = 1L, default = 1L), phase16_euro_scalar(stage, "seed_policy"),
        phase16_euro_scalar(stage, "different_group"), phase16_euro_scalar(stage, "first_leg_home_policy"),
        phase16_euro_scalar(stage, "tie_break_policy"), phase16_euro_scalar(stage, "cancellation_condition"),
        "unresolved", source$source_bundle_id %||% "", "", rules_lineage$ruleset_version,
        rules_lineage$ruleset_sha256, ""
      )
      row
    })
    rows <- rbind(rows, do.call(rbind, stage_rows))
  }
  if (!nrow(rows)) return(phase16_euro_empty_table(schema))
  rows$source_artifact_ids <- vapply(seq_len(nrow(rows)), function(index) phase16_euro_text(rows$source_artifact_ids[[index]], ""), character(1))
  phase16_euro_add_row_hashes(rows)
}

phase16_euro_capture_stage_slots <- function(stage_capture, topology, rules_lineage) {
  schema <- phase16_euro_outcomes_schema()$stage_slots
  if (is.null(stage_capture)) return(phase16_euro_empty_table(schema))
  capture <- if (is.list(stage_capture)) stage_capture$stage_capture %||% stage_capture$capture else stage_capture
  if (!is.data.frame(capture) || !nrow(capture)) return(phase16_euro_empty_table(schema))
  rows <- lapply(seq_len(nrow(capture)), function(index) {
    source <- capture[index, , drop = FALSE]
    source_status <- tolower(phase16_euro_scalar(source, "stage_status", aliases = "source_status"))
    status <- if (source_status %in% c("completed", "complete", "played", "final")) "completed" else "official"
    row <- phase16_euro_empty_table(schema)
    row[1L, ] <- list(
      phase16_euro_edition_id(), phase16_euro_scalar(source, "stage_id"),
      phase16_euro_stage_type(phase16_euro_scalar(source, "stage_id"), topology, rules_lineage$rules), status,
      as.integer(suppressWarnings(as.numeric(phase16_euro_scalar(source, "leg_number", default = 1L)))),
      phase16_euro_scalar(source, "participant_slot_home"), phase16_euro_scalar(source, "participant_slot_away"),
      phase16_euro_scalar(source, "home_team_id"), phase16_euro_scalar(source, "away_team_id"),
      phase16_euro_scalar(source, "source_fixture_id"), phase16_euro_scalar(source, "source_artifact_id"),
      "", "", phase16_euro_scalar(source, "scheduled_at_utc"),
      phase16_euro_field(source, "regulation_home_goals", n = 1L), phase16_euro_field(source, "regulation_away_goals", n = 1L),
      phase16_euro_field(source, "extra_time_home_goals", n = 1L), phase16_euro_field(source, "extra_time_away_goals", n = 1L),
      phase16_euro_field(source, "penalty_shootout_home_goals", n = 1L), phase16_euro_field(source, "penalty_shootout_away_goals", n = 1L),
      phase16_euro_field(source, "final_home_goals", n = 1L), phase16_euro_field(source, "final_away_goals", n = 1L),
      phase16_euro_scalar(source, "completed_at_utc"), status, "", "",
      rules_lineage$ruleset_version, rules_lineage$ruleset_sha256, ""
    )
    row
  })
  output <- do.call(rbind, rows)
  phase16_euro_add_row_hashes(output)
}

phase16_euro_simulation_stage_slots <- function(simulation, topology, rules_lineage) {
  schema <- phase16_euro_outcomes_schema()$stage_slots
  source <- simulation$stage_slots
  if (!is.data.frame(source) || !nrow(source)) return(phase16_euro_empty_table(schema))
  rows <- lapply(seq_len(nrow(source)), function(index) {
    input <- source[index, , drop = FALSE]
    status <- tolower(phase16_euro_scalar(input, "stage_status", aliases = "status"))
    if (!status %in% c("projected", "unresolved", "suppressed", "official", "completed")) status <- "unresolved"
    if (status %in% c("official", "completed")) status <- "projected"
    is_resolved <- status == "projected"
    row <- phase16_euro_empty_table(schema)
    row[1L, ] <- list(
      phase16_euro_edition_id(), phase16_euro_scalar(input, "stage_id"),
      phase16_euro_stage_type(phase16_euro_scalar(input, "stage_id"), topology, rules_lineage$rules), status,
      as.integer(suppressWarnings(as.numeric(phase16_euro_scalar(input, "leg_number", default = 1L)))),
      if (is_resolved) phase16_euro_scalar(input, "participant_slot_home") else "",
      if (is_resolved) phase16_euro_scalar(input, "participant_slot_away") else "",
      if (is_resolved) phase16_euro_scalar(input, "home_team_id") else "",
      if (is_resolved) phase16_euro_scalar(input, "away_team_id") else "",
      "", "", if (is_resolved) phase16_euro_scalar(input, "projection_run_id") else "",
      if (is_resolved) phase16_euro_scalar(input, "draw_policy_id") else "",
      if (is_resolved) phase16_euro_scalar(input, "scheduled_at_utc") else "",
      NA_integer_, NA_integer_, NA_integer_, NA_integer_, NA_integer_, NA_integer_, NA_integer_, NA_integer_, "",
      status, if (status == "unresolved") phase16_euro_scalar(input, "unresolved_reason", default = "missing_stage_resolution") else "",
      if (status == "suppressed") phase16_euro_scalar(input, "suppression_reason", default = "stage_suppressed") else "",
      rules_lineage$ruleset_version, rules_lineage$ruleset_sha256, ""
    )
    row
  })
  output <- do.call(rbind, rows)
  if (nrow(output) > 1L) {
    key <- paste(output$stage_id, output$leg_number, output$participant_slot_home, output$participant_slot_away, output$stage_status, sep = "::")
    output <- output[!duplicated(key), , drop = FALSE]
  }
  phase16_euro_add_row_hashes(output)
}

phase16_euro_merge_stage_slots <- function(stage_capture, simulation, topology, rules_lineage) {
  official <- phase16_euro_capture_stage_slots(stage_capture, topology, rules_lineage)
  projected <- phase16_euro_simulation_stage_slots(simulation, topology, rules_lineage)
  if (!nrow(official) && !nrow(projected)) return(phase16_euro_empty_table(phase16_euro_outcomes_schema()$stage_slots))
  output <- rbind(official, projected)
  if (nrow(output) > 1L) {
    key <- paste(output$stage_id, output$leg_number, output$participant_slot_home, output$participant_slot_away, sep = "::")
    output <- output[!duplicated(key), , drop = FALSE]
  }
  phase16_euro_add_row_hashes(output)
}

phase16_euro_common_simulation_fields <- function(simulation, rules_lineage, source, state, metadata = NULL) {
  metadata <- metadata %||% phase16_euro_simulation_metadata_row(simulation)
  list(
    edition_id = phase16_euro_edition_id(),
    projection_run_id = phase16_euro_scalar(metadata, "projection_run_id", default = phase16_euro_scalar(simulation$metadata, "projection_run_id")),
    simulation_count = phase16_euro_field(metadata, "simulation_count", n = 1L, default = phase16_euro_field(simulation$metadata, "simulation_count", n = 1L, default = "")),
    simulation_seed = phase16_euro_field(metadata, "simulation_seed", n = 1L, default = phase16_euro_field(simulation$metadata, "simulation_seed", n = 1L, default = "")),
    source_bundle_id = source$source_bundle_id %||% phase16_euro_scalar(metadata, "source_bundle_id"),
    source_bundle_sha256 = source$source_bundle_sha256 %||% phase16_euro_scalar(metadata, "source_bundle_sha256"),
    model_release_id = state$model_release_id %||% phase16_euro_scalar(metadata, "model_release_id"),
    ruleset_version = rules_lineage$ruleset_version,
    ruleset_sha256 = rules_lineage$ruleset_sha256
  )
}

phase16_euro_fill_common <- function(output, common, fields = names(common)) {
  for (field in intersect(fields, names(output))) {
    if (field %in% names(common)) output[[field]] <- common[[field]]
  }
  output
}

phase16_euro_map_simulation_table <- function(input, schema, common, aliases = list()) {
  if (!is.data.frame(input) || !nrow(input)) return(phase16_euro_empty_table(schema))
  output <- phase16_euro_empty_table(schema)
  output <- output[rep(1L, nrow(input)), , drop = FALSE]
  for (field in schema) {
    if (field == "row_sha256") next
    source_field <- c(field, aliases[[field]] %||% character())
    source_field <- source_field[source_field %in% names(input)]
    if (length(source_field)) output[[field]] <- input[[source_field[[1L]]]]
  }
  phase16_euro_fill_common(output, common)
}

phase16_euro_normalize_ranking_status <- function(status) {
  status <- tolower(trimws(as.character(status)))
  status[is.na(status) | !nzchar(status)] <- "resolved"
  status[status %in% c("blocked", "unresolved", "missing", "suppressed")] <- "unresolved"
  status
}

phase16_euro_build_projected_standings <- function(simulation, common) {
  output <- phase16_euro_map_simulation_table(
    simulation$projected_standings,
    phase16_euro_outcomes_schema()$projected_standings,
    common,
    aliases = list(expected_goal_difference = "expected_goal_diff", ranking_status = "ordering_status")
  )
  if (nrow(output)) output$ranking_status <- phase16_euro_normalize_ranking_status(output$ranking_status)
  if (nrow(output)) phase16_euro_add_row_hashes(output) else output
}

phase16_euro_build_projected_rankings <- function(simulation, common) {
  output <- phase16_euro_map_simulation_table(
    simulation$projected_rankings,
    phase16_euro_outcomes_schema()$projected_rankings,
    common,
    aliases = list(
      group_position = "group_rank", rank = "overall_rank", ranking_status = "ordering_status",
      counted_match_ids = "counted_matches", excluded_match_ids = "excluded_matches"
    )
  )
  if (nrow(output)) {
    output$ranking_status <- phase16_euro_normalize_ranking_status(output$ranking_status)
    blocked <- output$ranking_status == "unresolved"
    if (any(blocked)) {
      output$rank[blocked] <- NA_integer_
      output$interim_overall_rank[blocked] <- NA_integer_
      output$final_overall_rank[blocked] <- NA_integer_
      output$missing_rule_input[blocked & is.na(output$missing_rule_input)] <- "ranking_input_unresolved"
      output$suppression_reason[blocked & is.na(output$suppression_reason)] <- "ranking_input_unresolved"
    }
  }
  if (nrow(output)) phase16_euro_add_row_hashes(output) else output
}

phase16_euro_build_qualification_ledger <- function(simulation, common) {
  output <- phase16_euro_map_simulation_table(
    simulation$qualification_ledger,
    phase16_euro_outcomes_schema()$qualification_ledger,
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
  if (nrow(output)) phase16_euro_add_row_hashes(output) else output
}

phase16_euro_build_team_paths <- function(simulation, common) {
  output <- phase16_euro_map_simulation_table(
    simulation$team_path_probabilities,
    phase16_euro_outcomes_schema()$team_path_probabilities,
    common,
    aliases = list(status = "path_status")
  )
  if (nrow(output)) {
    output$status <- tolower(trimws(as.character(output$status)))
    output$status[is.na(output$status) | !nzchar(output$status)] <- "projected"
  }
  if (nrow(output)) phase16_euro_add_row_hashes(output) else output
}

phase16_euro_build_simulation_metadata <- function(simulation, state, source, rules_lineage, common, output_hash = "") {
  schema <- phase16_euro_outcomes_schema()$simulation_metadata
  input <- phase16_euro_simulation_metadata_row(simulation)
  output <- phase16_euro_empty_table(schema)
  output <- output[rep(1L, 1L), , drop = FALSE]
  if (is.data.frame(input) && ncol(input)) {
    for (field in setdiff(schema, "row_sha256")) if (field %in% names(input)) output[[field]] <- input[[field]][[1L]]
  }
  output$edition_id <- phase16_euro_edition_id()
  output$projection_run_id <- common$projection_run_id
  output$simulation_seed <- common$simulation_seed
  output$simulation_count <- common$simulation_count
  output$draw_policy_id <- phase16_euro_scalar(input, "draw_policy_id", default = phase16_euro_scalar(simulation$metadata, "draw_policy_id"))
  output$draw_policy_sha256 <- phase16_euro_scalar(input, "draw_policy_sha256", default = phase16_euro_scalar(simulation$metadata, "draw_policy_sha256"))
  output$ruleset_version <- rules_lineage$ruleset_version
  output$ruleset_sha256 <- rules_lineage$ruleset_sha256
  output$source_bundle_id <- common$source_bundle_id
  output$source_bundle_sha256 <- common$source_bundle_sha256
  output$model_release_id <- common$model_release_id
  if (!nzchar(phase16_euro_text(output$state_manifest_sha256[[1L]], ""))) output$state_manifest_sha256 <- state$state_manifest_sha256 %||% ""
  output$forecast_status_sha256 <- phase16_euro_parent_value(state$parent_graph, "phase14_forecast_status", phase16_euro_text(output$forecast_status_sha256[[1L]], ""))
  output$forecasts_sha256 <- phase16_euro_parent_value(state$parent_graph, "phase14_forecasts", phase16_euro_text(output$forecasts_sha256[[1L]], ""))
  output$score_distributions_sha256 <- phase16_euro_parent_value(state$parent_graph, "phase14_score_distributions", phase16_euro_text(output$score_distributions_sha256[[1L]], ""))
  output$release_manifest_sha256 <- phase16_euro_scalar(input, "release_manifest_sha256", default = phase16_euro_scalar(state$state_manifest, "release_manifest_sha256"))
  output$release_selector_sha256 <- phase16_euro_scalar(input, "release_selector_sha256", default = phase16_euro_scalar(state$state_manifest, "release_selector_sha256"))
  output$model_data_cutoff <- phase16_euro_scalar(input, "model_data_cutoff", default = phase16_euro_scalar(state$state_manifest, "model_data_cutoff"))
  output$feature_cutoff_sha256 <- phase16_euro_scalar(input, "feature_cutoff_sha256", default = phase16_euro_parent_value(state$parent_graph, "phase14_feature_cutoff"))
  output$generated_at_utc <- phase16_euro_scalar(input, "generated_at_utc", default = phase16_euro_scalar(state$state_manifest, "generated_at_utc"))
  output$output_sha256 <- if (nzchar(output_hash)) output_hash else phase16_euro_scalar(input, "output_sha256", default = phase16_euro_sha256(simulation$output_hashes, serialize = TRUE))
  phase16_euro_add_row_hashes(output)
}

phase16_euro_parent_graph_from_state <- function(state, source, stage_capture, rules_lineage, simulation, simulation_metadata) {
  manifest <- state$state_manifest
  parent <- list()
  put <- function(key, path, hash) parent[[key]] <<- list(path = path, sha256 = phase16_euro_text(hash))
  put("phase14_state_manifest", "audit/state_manifest.csv", state$state_manifest_sha256)
  for (path in phase14_state_bundle_expected_inventory()) {
    if (path == "audit/state_manifest.csv") next
    row <- manifest[as.character(manifest$artifact_path) == path, , drop = FALSE]
    if (nrow(row)) put(paste0("phase14_", gsub("[^A-Za-z0-9]+", "_", sub("\\.csv$", "", path))), path, phase16_euro_scalar(row, "content_sha256"))
  }
  put("source_bundle_manifest", source$source_manifest_path %||% "data/competition/accepted/uefa_nations_league_2026_27/source_bundle_manifest.csv", source$source_bundle_sha256)
  put("source_bundle", "data/competition/registries/source_bundles.csv", source$source_bundle_sha256)
  put("ruleset", "rules/uefa_nations_league_ruleset", rules_lineage$ruleset_sha256)
  capture_manifest <- if (is.list(stage_capture)) stage_capture$manifest else NULL
  if (is.data.frame(capture_manifest) && nrow(capture_manifest)) {
    put("stage_capture_manifest", "data/competition/accepted/uefa_nations_league_2026_27/stage_capture_manifest.csv", phase16_euro_scalar(capture_manifest, "manifest_sha256"))
    put("stage_capture_raw", phase16_euro_scalar(capture_manifest, "raw_relative_path"), phase16_euro_scalar(capture_manifest, "raw_sha256"))
    put("stage_capture_content", phase16_euro_scalar(capture_manifest, "capture_relative_path"), phase16_euro_scalar(capture_manifest, "capture_content_sha256"))
  }
  put("model_release", "outputs/releases/approved_release.csv", phase16_euro_scalar(manifest, "release_manifest_sha256"))
  put("model_selector", "outputs/releases/approved_release.csv", phase16_euro_scalar(manifest, "release_selector_sha256"))
  put("model", "outputs/releases/model_manifest.csv", phase16_euro_scalar(manifest, "model_sha256"))
  put("calibrator", "outputs/releases/model_manifest.csv", phase16_euro_scalar(manifest, "calibrator_sha256"))
  put("phase14_feature_cutoff", "state/forecast_status.csv#feature_cutoff_utc", phase16_euro_sha256(unique(as.character(state$forecast_status$feature_cutoff_utc))))
  put("simulation_metadata", "outcomes/simulation_metadata.csv", phase16_euro_table_content_hash(simulation_metadata))
  parent
}

phase16_build_euro_outcomes_candidate <- function(
    simulation,
    rules = NULL,
    topology = NULL,
    source = NULL,
    stage_capture = NULL,
    state_bundle = NULL,
    project_root = ".",
    generated_at_utc = NULL) {
  if (!is.list(simulation)) stop("Phase 15 outcomes candidate requires a simulation return list", call. = FALSE)
  state <- state_bundle %||% phase16_euro_read_phase14_state_bundle(project_root = project_root)
  if (is.character(state)) state <- phase16_euro_read_phase14_state_bundle(project_root = project_root, state_root = state)
  if (!is.list(state) || is.null(state$state_manifest)) stop("Phase 15 outcomes candidate requires the validated Phase 14 state parent", call. = FALSE)
  source <- source %||% state$source %||% phase16_euro_read_source_bundle(project_root = project_root)
  rules_lineage <- phase16_euro_rules_lineage(rules)
  topology <- topology %||% simulation$topology
  if (is.null(topology) && exists("uefa_nl_build_topology", mode = "function", inherits = TRUE)) {
    topology <- uefa_nl_build_topology(groups = source$groups, fixtures = source$fixtures, project_root = project_root)
  }
  if (is.null(stage_capture)) {
    if (exists("phase15_uefa_nl_read_stage_capture", mode = "function", inherits = TRUE)) {
      stage_capture <- phase15_uefa_nl_read_stage_capture(project_root = project_root)
    }
  }
  metadata <- phase16_euro_simulation_metadata_row(simulation)
  common <- phase16_euro_common_simulation_fields(simulation, rules_lineage, source, state, metadata)
  competition_topology <- phase16_euro_topology_table(topology, source, rules_lineage)
  stage_slots <- phase16_euro_merge_stage_slots(stage_capture, simulation, topology, rules_lineage)
  projected_standings <- phase16_euro_build_projected_standings(simulation, common)
  projected_rankings <- phase16_euro_build_projected_rankings(simulation, common)
  qualification_ledger <- phase16_euro_build_qualification_ledger(simulation, common)
  team_paths <- phase16_euro_build_team_paths(simulation, common)
  fixture_form <- phase16_euro_build_fixture_forecast_form(
    canonical_matches = state$canonical_matches,
    forecast_status = state$forecast_status,
    forecasts = state$forecasts,
    competition_form = state$competition_form,
    all_international_form = state$all_international_form,
    state_manifest = state$state_manifest,
    score_distributions = state$score_distributions,
    source = source
  )
  simulation_metadata <- phase16_euro_build_simulation_metadata(simulation, state, source, rules_lineage, common)
  parent_graph <- phase16_euro_parent_graph_from_state(state, source, stage_capture, rules_lineage, simulation, simulation_metadata)
  state$parent_graph <- parent_graph
  output_hash <- phase16_euro_sha256(list(
    projected_standings, projected_rankings, qualification_ledger, team_paths,
    stage_slots, fixture_form, simulation_metadata
  ), serialize = TRUE)
  simulation_metadata$output_sha256 <- output_hash
  simulation_metadata <- phase16_euro_add_row_hashes(simulation_metadata)
  artifacts <- list(
    "outcomes/competition_topology.csv" = competition_topology,
    "outcomes/stage_slots.csv" = stage_slots,
    "outcomes/projected_standings.csv" = projected_standings,
    "outcomes/projected_rankings.csv" = projected_rankings,
    "outcomes/qualification_ledger.csv" = qualification_ledger,
    "outcomes/team_path_probabilities.csv" = team_paths,
    "outcomes/fixture_forecast_form.csv" = fixture_form,
    "outcomes/simulation_metadata.csv" = simulation_metadata
  )
  candidate <- list(
    edition_id = phase16_euro_edition_id(),
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
    draw_policy_id = phase16_euro_scalar(simulation_metadata, "draw_policy_id"),
    draw_policy_sha256 = phase16_euro_scalar(simulation_metadata, "draw_policy_sha256"),
    parent_graph = parent_graph,
    artifacts = artifacts,
    outcomes_artifacts = artifacts,
    generated_at_utc = generated_at_utc %||% phase16_euro_scalar(simulation_metadata, "generated_at_utc")
  )
  candidate$manifest <- phase16_euro_outcomes_manifest_rows(candidate, artifacts)
  candidate <- phase16_euro_attach_manifest(candidate)
  candidate
}

phase16_euro_state_manifest_content_hash <- function(state_manifest, path) {
  if (!is.data.frame(state_manifest) || !nrow(state_manifest) || !"artifact_path" %in% names(state_manifest)) return("")
  row <- state_manifest[as.character(state_manifest$artifact_path) == path, , drop = FALSE]
  if (!nrow(row) || !"content_sha256" %in% names(row)) return("")
  phase16_euro_scalar(row, "content_sha256")
}

phase16_euro_form_rows_for_team <- function(form, team_id) {
  if (!is.data.frame(form) || !nrow(form) || !"team_id" %in% names(form)) return(data.frame(stringsAsFactors = FALSE))
  rows <- form[as.character(form$team_id) == as.character(team_id), , drop = FALSE]
  if (nrow(rows) > 1L) rows <- rows[order(as.character(phase16_euro_field(rows, "feature_cutoff_utc")), method = "radix"), , drop = FALSE]
  if (nrow(rows)) rows[1L, , drop = FALSE] else rows
}

phase16_euro_form_summary <- function(form, team_ids) {
  rows <- lapply(team_ids, function(team_id) phase16_euro_form_rows_for_team(form, team_id))
  present <- vapply(rows, nrow, integer(1)) > 0L
  available <- present & vapply(rows, function(row) {
    if (!nrow(row)) return(FALSE)
    tolower(phase16_euro_scalar(row, "availability_status", default = "unavailable")) == "available"
  }, logical(1))
  status <- if (all(available)) "available" else if (any(available)) "partial" else "unavailable"
  chosen <- rows[which(available)]
  chosen <- chosen[vapply(chosen, nrow, integer(1)) > 0L]
  values <- function(field, default = "") {
    if (!length(chosen)) return(default)
    values <- vapply(chosen, function(row) phase16_euro_scalar(row, field, default = default), character(1))
    values <- unique(values[nzchar(values)])
    if (length(values)) paste(values, collapse = "|") else default
  }
  reason <- vapply(rows, function(row) phase16_euro_scalar(row, "availability_reason", default = "no_eligible_form_history"), character(1))
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

phase16_euro_forecast_row <- function(data, fixture_id) {
  if (!is.data.frame(data) || !nrow(data)) return(data[FALSE, , drop = FALSE] %||% data.frame(stringsAsFactors = FALSE))
  key <- if ("fixture_id" %in% names(data)) "fixture_id" else if ("match_id" %in% names(data)) "match_id" else NULL
  if (is.null(key)) return(data[FALSE, , drop = FALSE])
  rows <- data[as.character(data[[key]]) == as.character(fixture_id), , drop = FALSE]
  if (nrow(rows) > 1L) rows <- rows[1L, , drop = FALSE]
  rows
}

phase16_euro_form_parent_hash <- function(state_manifest, path) {
  hash <- phase16_euro_state_manifest_content_hash(state_manifest, path)
  if (nzchar(hash)) return(hash)
  ""
}

phase16_euro_build_fixture_forecast_form <- function(
    canonical_matches,
    forecast_status,
    forecasts,
    competition_form,
    all_international_form,
    state_manifest,
    score_distributions = NULL,
    source = list()) {
  schema <- phase16_euro_outcomes_schema()$fixture_forecast_form
  if (!is.data.frame(canonical_matches)) stop("Phase 15 fixture pass-through requires canonical matches", call. = FALSE)
  if (!nrow(canonical_matches)) return(phase16_euro_empty_table(schema))
  if (!"fixture_id" %in% names(canonical_matches)) stop("Phase 15 fixture pass-through requires fixture_id", call. = FALSE)
  parent <- list(
    state_manifest = phase16_euro_form_parent_hash(state_manifest, "audit/state_manifest.csv"),
    canonical_matches = phase16_euro_form_parent_hash(state_manifest, "state/canonical_matches.csv"),
    forecast_status = phase16_euro_form_parent_hash(state_manifest, "state/forecast_status.csv"),
    forecasts = phase16_euro_form_parent_hash(state_manifest, "state/forecasts.csv"),
    score_distributions = phase16_euro_form_parent_hash(state_manifest, "local/score_distributions.rds")
  )
  rows <- lapply(seq_len(nrow(canonical_matches)), function(index) {
    fixture <- canonical_matches[index, , drop = FALSE]
    fixture_id <- phase16_euro_scalar(fixture, "fixture_id", aliases = "match_id")
    status_row <- phase16_euro_forecast_row(forecast_status, fixture_id)
    forecast_row <- phase16_euro_forecast_row(forecasts, fixture_id)
    status <- phase16_euro_scalar(status_row, "forecast_status", default = phase16_euro_scalar(forecast_row, "forecast_status", default = "unavailable"))
    status <- tolower(status)
    suppression <- phase16_euro_scalar(status_row, "suppression_reason", default = phase16_euro_scalar(forecast_row, "suppression_reason", default = "none"))
    available <- identical(status, "available")
    home_team <- phase16_euro_scalar(fixture, "home_team_id")
    away_team <- phase16_euro_scalar(fixture, "away_team_id")
    competition <- phase16_euro_form_summary(competition_form, c(home_team, away_team))
    international <- phase16_euro_form_summary(all_international_form, c(home_team, away_team))
    feature_cutoff <- phase16_euro_scalar(status_row, "feature_cutoff_utc", default = phase16_euro_scalar(forecast_row, "feature_cutoff_utc"))
    model_cutoff <- phase16_euro_scalar(forecast_row, "model_data_cutoff", default = phase16_euro_scalar(status_row, "model_data_cutoff"))
    output <- phase16_euro_empty_table(schema)
    output[1L, ] <- list(
      phase16_euro_edition_id(), fixture_id, status, if (available) "none" else suppression,
      phase16_euro_scalar(forecast_row, "primary_probability_view", default = phase16_euro_scalar(status_row, "primary_probability_view")),
      if (available) phase16_euro_field(forecast_row, "p_home", n = 1L, default = NA_real_) else NA_real_,
      if (available) phase16_euro_field(forecast_row, "p_draw", n = 1L, default = NA_real_) else NA_real_,
      if (available) phase16_euro_field(forecast_row, "p_away", n = 1L, default = NA_real_) else NA_real_,
      if (available) phase16_euro_field(forecast_row, "expected_home_goals", n = 1L, default = NA_real_) else NA_real_,
      if (available) phase16_euro_field(forecast_row, "expected_away_goals", n = 1L, default = NA_real_) else NA_real_,
      phase16_euro_scalar(forecast_row, "model_id", default = phase16_euro_scalar(status_row, "model_id")),
      phase16_euro_scalar(forecast_row, "model_sha256", default = phase16_euro_scalar(status_row, "model_sha256")),
      phase16_euro_scalar(forecast_row, "model_release_id", default = phase16_euro_scalar(status_row, "model_release_id")),
      phase16_euro_scalar(forecast_row, "release_manifest_sha256", default = phase16_euro_scalar(status_row, "release_manifest_sha256")),
      phase16_euro_scalar(forecast_row, "release_selector_sha256", default = phase16_euro_scalar(status_row, "release_selector_sha256")),
      model_cutoff, if (nzchar(model_cutoff)) phase16_euro_sha256(model_cutoff) else "",
      feature_cutoff, if (nzchar(feature_cutoff)) phase16_euro_sha256(feature_cutoff) else "",
      competition$status, competition$window_type, competition$window_size, competition$cutoff_utc,
      parent$competition_form %||% phase16_euro_form_parent_hash(state_manifest, "state/competition_form.csv"),
      international$status, international$window_type, international$window_size, international$cutoff_utc,
      parent$all_international_form %||% phase16_euro_form_parent_hash(state_manifest, "state/all_international_form.csv"),
      phase16_euro_scalar(forecast_row, "source_bundle_id", default = phase16_euro_scalar(status_row, "source_bundle_id", default = source$source_bundle_id %||% "")),
      source$source_bundle_sha256 %||% "", parent$state_manifest, parent$canonical_matches,
      parent$forecast_status, parent$forecasts, parent$score_distributions, ""
    )
    output
  })
  output <- do.call(rbind, rows)
  # `parent$competition_form` and `parent$all_international_form` are optional
  # aliases in the local helper; fill them explicitly from the state manifest.
  output$competition_form_sha256 <- phase16_euro_form_parent_hash(state_manifest, "state/competition_form.csv")
  output$all_international_form_sha256 <- phase16_euro_form_parent_hash(state_manifest, "state/all_international_form.csv")
  if (nrow(output)) phase16_euro_add_row_hashes(output) else output
}

phase16_euro_manifest_lineage <- function(candidate) {
  state_manifest <- candidate$state_manifest %||% data.frame(stringsAsFactors = FALSE)
  source <- candidate$source %||% list()
  first <- if (is.data.frame(state_manifest) && nrow(state_manifest)) state_manifest[1L, , drop = FALSE] else data.frame(stringsAsFactors = FALSE)
  list(
    source_bundle_id = source$source_bundle_id %||% phase16_euro_scalar(first, "source_bundle_id"),
    source_bundle_sha256 = source$source_bundle_sha256 %||% phase16_euro_scalar(first, "source_bundle_sha256"),
    source_artifact_ids = source$source_artifact_ids %||% phase16_euro_scalar(first, "source_artifact_ids"),
    model_release_id = candidate$model_release_id %||% phase16_euro_scalar(first, "model_release_id"),
    release_manifest_sha256 = phase16_euro_scalar(first, "release_manifest_sha256"),
    release_selector_sha256 = phase16_euro_scalar(first, "release_selector_sha256"),
    model_id = phase16_euro_scalar(first, "model_id"),
    model_sha256 = phase16_euro_scalar(first, "model_sha256"),
    calibrator_id = phase16_euro_scalar(first, "calibrator_id"),
    calibrator_sha256 = phase16_euro_scalar(first, "calibrator_sha256"),
    model_data_cutoff = phase16_euro_scalar(first, "model_data_cutoff"),
    feature_cutoff_sha256 = phase16_euro_scalar(candidate$simulation_metadata, "feature_cutoff_sha256", default = phase16_euro_parent_value(candidate$parent_graph, "phase14_feature_cutoff")),
    ruleset_version = candidate$ruleset_version %||% "",
    ruleset_sha256 = candidate$ruleset_sha256 %||% "",
    draw_policy_id = candidate$draw_policy_id %||% phase16_euro_scalar(candidate$simulation_metadata, "draw_policy_id"),
    draw_policy_sha256 = candidate$draw_policy_sha256 %||% phase16_euro_scalar(candidate$simulation_metadata, "draw_policy_sha256"),
    simulation_seed = candidate$simulation_seed %||% phase16_euro_scalar(candidate$simulation_metadata, "simulation_seed"),
    simulation_count = candidate$simulation_count %||% phase16_euro_scalar(candidate$simulation_metadata, "simulation_count"),
    projection_run_id = candidate$projection_run_id %||% phase16_euro_scalar(candidate$simulation_metadata, "projection_run_id"),
    generated_at_utc = candidate$generated_at_utc %||% phase16_euro_scalar(candidate$simulation_metadata, "generated_at_utc")
  )
}

phase16_euro_manifest_parent_keys <- function(artifact_key) {
  artifact_key <- sub("\\.csv$", "", artifact_key)
  switch(
    artifact_key,
    competition_topology = c("source_bundle_manifest", "ruleset"),
    stage_slots = c("source_bundle_manifest", "stage_capture_manifest", "stage_capture_raw", "stage_capture_content", "ruleset", "simulation_metadata"),
    projected_standings = c("phase14_state_manifest", "phase14_canonical_matches", "source_bundle_manifest", "ruleset", "simulation_metadata"),
    projected_rankings = c("phase14_state_manifest", "phase14_canonical_matches", "source_bundle_manifest", "ruleset", "simulation_metadata"),
    qualification_ledger = c("phase14_state_manifest", "source_bundle_manifest", "ruleset", "model_release", "simulation_metadata"),
    team_path_probabilities = c("phase14_state_manifest", "source_bundle_manifest", "ruleset", "model_release", "simulation_metadata"),
    fixture_forecast_form = c("phase14_state_manifest", "phase14_canonical_matches", "phase14_forecast_status", "phase14_forecasts", "phase14_score_distributions", "source_bundle_manifest"),
    simulation_metadata = c("phase14_state_manifest", "phase14_forecast_status", "phase14_forecasts", "phase14_score_distributions", "source_bundle_manifest", "ruleset", "model_release"),
    character()
  )
}

phase16_euro_manifest_row <- function(path, table, candidate, lineage, parent_graph) {
  key <- phase16_euro_artifact_key(path)
  pairs <- phase16_euro_parent_pairs(parent_graph, phase16_euro_manifest_parent_keys(key))
  data.frame(
    edition_id = phase16_euro_edition_id(),
    artifact_path = path,
    artifact_type = "csv",
    row_count = as.integer(nrow(table)),
    content_sha256 = phase16_euro_table_content_hash(table),
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

phase16_euro_outcomes_manifest_rows <- function(candidate, artifacts = NULL, generated_at_utc = NULL) {
  schema <- phase16_euro_outcomes_schema()$outcomes_manifest
  artifacts <- artifacts %||% candidate$artifacts %||% candidate$outcomes_artifacts
  expected <- phase16_euro_outcomes_expected_inventory()
  table_paths <- setdiff(expected, "outcomes/outcomes_manifest.csv")
  if (!is.list(artifacts) || !setequal(names(artifacts), table_paths)) stop("Phase 15 outcomes candidate must contain exactly eight non-manifest artifacts", call. = FALSE)
  lineage <- phase16_euro_manifest_lineage(candidate)
  parent_graph <- candidate$parent_graph %||% list()
  rows <- lapply(table_paths, function(path) {
    phase16_euro_manifest_row(path, artifacts[[path]], candidate, lineage, parent_graph)
  })
  manifest_row <- as.data.frame(setNames(lapply(schema, function(field) {
    if (field == "edition_id") return(phase16_euro_edition_id())
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

phase16_euro_attach_manifest <- function(candidate) {
  artifacts <- candidate$artifacts %||% candidate$outcomes_artifacts
  base <- phase16_euro_outcomes_manifest_rows(candidate, artifacts, candidate$generated_at_utc)
  base$manifest_sha256 <- ""
  base$validation_status <- "valid"
  self_index <- which(base$artifact_path == "outcomes/outcomes_manifest.csv")
  base$row_count[[self_index]] <- 0L
  base$content_sha256[[self_index]] <- ""
  manifest_hash <- phase16_euro_table_content_hash(base)
  base$manifest_sha256 <- manifest_hash
  base$row_count[[self_index]] <- nrow(base)
  base$content_sha256[[self_index]] <- manifest_hash
  base$row_sha256 <- phase16_euro_row_hashes(base)
  base <- base[, phase16_euro_outcomes_schema()$outcomes_manifest, drop = FALSE]
  artifacts[["outcomes/outcomes_manifest.csv"]] <- base
  candidate$artifacts <- artifacts
  candidate$outcomes_artifacts <- artifacts
  candidate$manifest <- base
  candidate$manifest_sha256 <- manifest_hash
  candidate$candidate_status <- "valid"
  candidate
}

phase16_euro_manifest_parent_lookup <- function(manifest, path) {
  row <- manifest[as.character(manifest$artifact_path) == path, , drop = FALSE]
  if (!nrow(row)) return(list())
  paths <- phase16_euro_text(row$parent_paths[[1L]], "")
  hashes <- phase16_euro_text(row$parent_sha256[[1L]], "")
  if (!nzchar(paths)) return(list())
  list(
    paths = strsplit(paths, "|", fixed = TRUE)[[1L]],
    hashes = strsplit(hashes, "|", fixed = TRUE)[[1L]]
  )
}

phase16_euro_validate_stage_slot_output <- function(table, rules_lineage) {
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

phase16_euro_validate_probability_groups <- function(table, group_fields, name, tolerance = 1e-7) {
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

phase16_euro_validate_outcomes_manifest <- function(manifest, artifacts, candidate = NULL) {
  schema <- phase16_euro_outcomes_schema()$outcomes_manifest
  phase16_euro_require_schema(manifest, schema, "outcomes manifest")
  expected <- phase16_euro_outcomes_expected_inventory()
  if (!identical(as.character(manifest$artifact_path), expected)) stop("Phase 15 outcomes manifest has an unexpected or reordered inventory", call. = FALSE)
  if (any(as.character(manifest$edition_id) != phase16_euro_edition_id())) stop("Phase 15 outcomes manifest has a foreign edition", call. = FALSE)
  phase16_euro_assert_hash(manifest$content_sha256[seq_len(nrow(manifest) - 1L)], "outcomes content", allow_empty = FALSE)
  phase16_euro_assert_hash(manifest$ruleset_sha256, "outcomes ruleset")
  phase16_euro_assert_hash(manifest$source_bundle_sha256, "outcomes source bundle")
  for (field in c("release_manifest_sha256", "release_selector_sha256", "model_sha256", "calibrator_sha256", "draw_policy_sha256", "feature_cutoff_sha256")) {
    values <- as.character(manifest[[field]])
    values <- values[!is.na(values) & nzchar(values)]
    if (length(values)) phase16_euro_assert_hash(values, paste0("outcomes ", field))
  }
  if (any(is.na(as.integer(manifest$row_count)) | as.integer(manifest$row_count) < 0L)) stop("Outcomes manifest row counts are invalid", call. = FALSE)
  for (path in setdiff(expected, "outcomes/outcomes_manifest.csv")) {
    row <- manifest[as.character(manifest$artifact_path) == path, , drop = FALSE]
    table <- artifacts[[path]]
    if (nrow(row) != 1L || !is.data.frame(table)) stop("Outcomes manifest/artifact link is incomplete: ", path, call. = FALSE)
    if (!identical(as.integer(row$row_count[[1L]]), as.integer(nrow(table)))) stop("Outcomes row count mismatch: ", path, call. = FALSE)
    if (!identical(tolower(as.character(row$content_sha256[[1L]])), phase16_euro_table_content_hash(table))) stop("Outcomes content hash mismatch: ", path, call. = FALSE)
    parents <- phase16_euro_manifest_parent_lookup(manifest, path)
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
  if (!identical(tolower(phase16_euro_table_content_hash(seed)), tolower(manifest_hashes[[1L]]))) stop("Outcomes manifest self hash mismatch", call. = FALSE)
  if (nrow(manifest)) {
    expected_manifest_rows <- phase16_euro_row_hashes(manifest)
    if (any(as.character(manifest$row_sha256) != expected_manifest_rows)) stop("Outcomes manifest row self-hash mismatch", call. = FALSE)
  }
  invisible(TRUE)
}

phase16_validate_euro_outcomes_bundle <- function(bundle) {
  if (!is.list(bundle)) stop("Phase 15 outcomes validator requires a candidate or bundle", call. = FALSE)
  artifacts <- bundle$artifacts %||% bundle$outcomes_artifacts
  manifest <- bundle$manifest %||% artifacts[["outcomes/outcomes_manifest.csv"]]
  expected <- phase16_euro_outcomes_expected_inventory()
  if (!is.list(artifacts) || !setequal(names(artifacts), expected)) stop("Phase 15 outcomes candidate must contain exactly the nine-file sibling inventory", call. = FALSE)
  if (!is.data.frame(manifest)) stop("Phase 15 outcomes candidate is missing outcomes_manifest.csv", call. = FALSE)
  schemas <- phase16_euro_outcomes_schema()
  for (path in setdiff(expected, "outcomes/outcomes_manifest.csv")) {
    key <- phase16_euro_artifact_key(path)
    key <- sub("\\.csv$", "", key)
    phase16_euro_require_schema(artifacts[[path]], schemas[[key]], path)
    table <- artifacts[[path]]
    if (nrow(table) && any(as.character(table$edition_id) != phase16_euro_edition_id())) stop("Phase 15 outcomes artifact has a foreign edition: ", path, call. = FALSE)
    if (nrow(table) && any(!grepl("^[0-9a-fA-F]{64}$", as.character(table$row_sha256)))) stop("Phase 15 outcomes artifact has invalid row hashes: ", path, call. = FALSE)
    if (nrow(table) && any(as.character(table$row_sha256) != phase16_euro_row_hashes(table))) stop("Phase 15 outcomes artifact row hash mismatch: ", path, call. = FALSE)
  }
  rules_lineage <- list(
    ruleset_version = bundle$ruleset_version %||% phase16_euro_scalar(bundle$simulation_metadata, "ruleset_version"),
    ruleset_sha256 = bundle$ruleset_sha256 %||% phase16_euro_scalar(bundle$simulation_metadata, "ruleset_sha256")
  )
  phase16_euro_validate_stage_slot_output(artifacts[["outcomes/stage_slots.csv"]], rules_lineage)
  phase16_euro_validate_probability_groups(artifacts[["outcomes/projected_standings.csv"]], c("league", "group_id", "rank"), "projected standings")
  phase16_euro_validate_probability_groups(artifacts[["outcomes/projected_rankings.csv"]], c("ranking_scope", "rank"), "projected rankings")
  for (field in c("p_quarter_final", "p_semi_final", "p_third_place", "p_final", "p_champion", "p_direct_promotion", "p_direct_relegation", "p_playoff_eligibility", "p_playoff_win", "p_playoff_loss")) {
    values <- suppressWarnings(as.numeric(as.character(artifacts[["outcomes/team_path_probabilities.csv"]][[field]])))
    if (any(!is.na(values) & (values < 0 | values > 1))) stop("Team path probability is outside [0,1]: ", field, call. = FALSE)
  }
  phase16_euro_validate_outcomes_manifest(manifest, artifacts, bundle)
  invisible(TRUE)
}

phase16_euro_validate_output_root <- function(output_root, project_root = ".") {
  if (!is.character(output_root) || length(output_root) != 1L || is.na(output_root) || !nzchar(output_root)) stop("Phase 15 outcomes writer requires one output root", call. = FALSE)
  raw <- output_root
  root <- normalizePath(raw, winslash = "/", mustWork = FALSE)
  if (isTRUE(attr(raw, "phase15_registered"))) {
    temp_root <- normalizePath(tempdir(), winslash = "/", mustWork = TRUE)
    if (identical(root, temp_root) || !startsWith(root, paste0(temp_root, "/"))) stop("Test outcomes roots must be registered children of tempdir()", call. = FALSE)
    return(root)
  }
  registered <- phase16_euro_registered_outcomes_root(project_root)
  if (!identical(root, registered)) stop("Phase 15 outcomes writer accepts only the registered EURO qualifying outcomes root", call. = FALSE)
  root
}

phase16_write_euro_outcomes_bundle <- function(candidate, output_root = NULL, project_root = ".") {
  if (is.null(output_root)) output_root <- phase16_euro_registered_outcomes_root(project_root)
  phase16_validate_euro_outcomes_bundle(candidate)
  root <- phase16_euro_validate_output_root(output_root, project_root)
  parent <- dirname(root)
  dir.create(parent, recursive = TRUE, showWarnings = FALSE)
  existing <- if (dir.exists(root)) gsub("\\\\", "/", list.files(root, recursive = TRUE, all.files = FALSE, include.dirs = FALSE)) else character()
  expected_files <- sub("^outcomes/", "", phase16_euro_outcomes_expected_inventory())
  if (length(existing) && !setequal(existing, expected_files)) stop("Existing Phase 15 outcomes root contains an unexpected file", call. = FALSE)
  staging <- tempfile(".outcomes-staging-", tmpdir = parent)
  dir.create(staging, recursive = TRUE, showWarnings = FALSE)
  on.exit(if (dir.exists(staging)) unlink(staging, recursive = TRUE), add = TRUE)
  artifacts <- candidate$artifacts %||% candidate$outcomes_artifacts
  for (path in phase16_euro_outcomes_expected_inventory()) {
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
  if (had_existing && !file.rename(root, backup)) stop("Could not stage the existing EURO qualifying outcomes root", call. = FALSE)
  promoted <- file.rename(staging, root)
  if (!promoted) {
    if (had_existing) file.rename(backup, root)
    stop("Could not atomically promote the EURO qualifying outcomes root", call. = FALSE)
  }
  if (had_existing && dir.exists(backup)) unlink(backup, recursive = TRUE)
  output <- phase16_read_euro_outcomes_bundle(root, validate = TRUE)
  output$written_root <- root
  output
}

phase16_read_euro_outcomes_bundle <- function(root = NULL, project_root = ".", validate = TRUE) {
  root <- root %||% phase16_euro_registered_outcomes_root(project_root)
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  if (basename(root) != "outcomes" && !file.exists(file.path(root, "competition_topology.csv"))) root <- file.path(root, "outcomes")
  expected <- phase16_euro_outcomes_expected_inventory()
  relative <- sub("^outcomes/", "", expected)
  present <- gsub("\\\\", "/", list.files(root, recursive = TRUE, all.files = FALSE, include.dirs = FALSE))
  if (!setequal(present, relative)) stop("Phase 15 outcomes durable bundle must contain exactly nine files", call. = FALSE)
  artifacts <- lapply(relative, function(path) phase16_euro_read_csv(file.path(root, path), path))
  names(artifacts) <- expected
  manifest <- artifacts[["outcomes/outcomes_manifest.csv"]]
  bundle <- list(
    edition_id = phase16_euro_edition_id(),
    root = root,
    artifacts = artifacts,
    outcomes_artifacts = artifacts,
    manifest = manifest,
    fixture_forecast_form = artifacts[["outcomes/fixture_forecast_form.csv"]],
    simulation_metadata = artifacts[["outcomes/simulation_metadata.csv"]],
    ruleset_version = phase16_euro_scalar(manifest, "ruleset_version"),
    ruleset_sha256 = phase16_euro_scalar(manifest, "ruleset_sha256"),
    manifest_sha256 = phase16_euro_scalar(manifest, "manifest_sha256")
  )
  if (isTRUE(validate)) phase16_validate_euro_outcomes_bundle(bundle)
  bundle
}

# Phase 16 EURO qualifying overrides.  The Phase 15 file remains the structural
# sibling, but EURO has a different allocation ledger and an activation gate.

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
