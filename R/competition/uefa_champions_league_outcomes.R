# Deterministic, fail-closed UCL outcome candidate and result-contract boundary.

# Outcomes is sourced directly by focused tests and by the targets verifier, so
# keep the Phase 18 canonical-v2 primitives private to this module.  Outcome
# identities must not depend on delimiter-separated text: a source identifier
# containing a delimiter is still a distinct byte sequence.
.ucl_out_canonical_env <- local({
  env <- new.env(parent = baseenv())
  root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  repeat {
    candidate <- file.path(root, "R", "common", "phase18_canonical_hash.R")
    if (file.exists(candidate)) {
      try(sys.source(candidate, envir = env), silent = TRUE)
      break
    }
    parent <- dirname(root)
    if (identical(parent, root)) break
    root <- parent
  }
  env
})

.ucl_out_hash <- function(value) {
  fn <- if (exists("phase18_hash_sequence_v2", envir = .ucl_out_canonical_env, inherits = FALSE)) {
    get("phase18_hash_sequence_v2", envir = .ucl_out_canonical_env, inherits = FALSE)
  } else NULL
  values <- lapply(value, function(item) {
    if (is.null(item) || !length(item) || is.na(item[[1L]])) NA_character_ else as.character(item[[1L]])
  })
  if (is.function(fn)) {
    return(fn(values, domain = "ucl20-outcome-sequence-v2",
              names = paste0("value_", seq_along(values)),
              types = rep("character", length(values))))
  }
  if (!requireNamespace("digest", quietly = TRUE)) stop("UCL outcomes require digest", call. = FALSE)
  digest::digest(charToRaw(enc2utf8(paste(values, collapse = "\x1f"))), algo = "sha256", serialize = FALSE)
}

.ucl_out_scalar <- function(value) {
  if (inherits(value, "POSIXt")) return(format(value, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  if (inherits(value, "Date")) return(format(value, "%Y-%m-%d"))
  if (is.logical(value)) return(ifelse(is.na(value), "", ifelse(value, "true", "false")))
  if (!length(value) || is.na(value[[1L]])) return("")
  as.character(value[[1L]])
}

.ucl_out_hashable_table <- function(data) {
  data <- as.data.frame(data, stringsAsFactors = FALSE, check.names = FALSE)
  for (field in names(data)) {
    if (is.list(data[[field]]) && !is.data.frame(data[[field]])) {
      data[[field]] <- vapply(data[[field]], function(value) {
        if (is.null(value) || !length(value)) return(NA_character_)
        if (is.data.frame(value)) return(.ucl_out_canonical_hash(value))
        if (is.list(value)) return(.ucl_out_hash(unlist(value, use.names = FALSE)))
        as.character(value[[1L]])
      }, character(1))
    }
  }
  data
}

.ucl_out_canonical_hash <- function(data) {
  if (is.null(data)) return(.ucl_out_hash(""))
  if (is.data.frame(data)) {
    data <- .ucl_out_hashable_table(data)
    table_fn <- if (exists("phase18_hash_table_v2", envir = .ucl_out_canonical_env, inherits = FALSE)) {
      get("phase18_hash_table_v2", envir = .ucl_out_canonical_env, inherits = FALSE)
    } else NULL
    key_candidates <- c("artifact_path", "fixture_id", "path_id", "stage_event_id", "club_id",
                        "tie_group_id", "run_id", "manifest_id", "slot_id", "edition_id")
    key_candidates <- key_candidates[key_candidates %in% names(data)]
    key_candidates <- key_candidates[vapply(key_candidates, function(field) {
      values <- data[[field]]
      !length(values) || (!anyNA(values) && all(nzchar(trimws(as.character(values)))))
    }, logical(1))]
    if (is.function(table_fn) && length(key_candidates)) {
      return(table_fn(data, key = key_candidates[[1L]], schema_tag = "ucl20-outcome-table-v2"))
    }
    fields <- sort(names(data), method = "radix")
    ordered <- data[, fields, drop = FALSE]
    if (nrow(ordered)) {
      keys <- lapply(ordered, function(column) vapply(column, .ucl_out_scalar, character(1)))
      ordered <- ordered[do.call(order, c(keys, list(method = "radix", na.last = TRUE))), , drop = FALSE]
    }
    rows <- if (!nrow(ordered)) character() else vapply(seq_len(nrow(ordered)), function(index) {
      paste(vapply(ordered[index, fields, drop = FALSE], .ucl_out_scalar, character(1)), collapse = "\x1f")
    }, character(1))
    return(.ucl_out_hash(c(paste(fields, collapse = "\x1f"), rows)))
  }
  if (is.list(data)) {
    values <- data[sort(names(data), method = "radix")]
    return(.ucl_out_hash(c(names(values), vapply(values, .ucl_out_canonical_hash, character(1)))))
  }
  .ucl_out_hash(.ucl_out_scalar(data))
}

.ucl_out_empty <- function(fields) {
  result <- as.data.frame(setNames(lapply(fields, function(ignore) character()), fields), stringsAsFactors = FALSE, check.names = FALSE)
  result
}

.ucl_out_coerce <- function(data, fields, defaults = list()) {
  if (is.null(data)) data <- data.frame(stringsAsFactors = FALSE)
  data <- as.data.frame(data, stringsAsFactors = FALSE, check.names = FALSE)
  for (field in setdiff(fields, names(data))) {
    value <- defaults[[field]]
    if (is.null(value)) value <- NA_character_
    data[[field]] <- rep(value, length.out = nrow(data))
  }
  data[, fields, drop = FALSE]
}

.ucl_out_first <- function(value, default = NA_character_) {
  if (is.null(value) || !length(value)) return(default)
  usable <- !is.na(value)
  if (is.character(value)) usable <- usable & nzchar(trimws(value))
  index <- which(usable)[1L]
  if (is.na(index)) default else value[[index]]
}

.ucl_out_validate_cutoff <- function(value) {
  if (length(value) != 1L || is.null(value) || is.na(value) ||
      !grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$", as.character(value))) {
    return(list(valid = FALSE, reason = "information_cutoff_invalid", value = NA_character_))
  }
  text <- as.character(value[[1L]])
  parsed <- suppressWarnings(as.POSIXct(text, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  if (is.na(parsed)) return(list(valid = FALSE, reason = "information_cutoff_invalid", value = text))
  if (parsed >= as.POSIXct("2099-01-01T00:00:00Z", format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")) {
    return(list(valid = FALSE, reason = "information_cutoff_sentinel", value = text))
  }
  list(valid = TRUE, reason = NA_character_, value = text)
}

.ucl_out_table <- function(ledger) {
  if (is.data.frame(ledger)) return(ledger)
  if (is.list(ledger) && is.data.frame(ledger$ledger)) return(ledger$ledger)
  NULL
}

.ucl_out_validate_ledger_lineage <- function(ledger) {
  table <- .ucl_out_table(ledger)
  if (is.null(table) || !nrow(table)) return(list(valid = TRUE, errors = character()))
  available <- if ("forecast_status" %in% names(table)) {
    as.character(table$forecast_status) %in% c("available", "eligible", "eligible_fixture", "eligible_production", "forecast_available")
  } else rep(TRUE, nrow(table))
  errors <- character()
  one_identity <- function(field, required = FALSE) {
    if (!field %in% names(table)) return(if (required) "missing" else character())
    values <- as.character(table[[field]][available])
    values <- values[!is.na(values) & nzchar(trimws(values))]
    if (required && !length(values)) return("empty")
    if (length(unique(values)) > 1L) return("mixed")
    character()
  }
  if (length(one_identity("model_release_id", required = TRUE))) errors <- c(errors, "ledger_release_lineage_mixed")
  if (length(one_identity("model_sha256", required = TRUE)) ||
      length(one_identity("calibrator_sha256", required = TRUE))) errors <- c(errors, "ledger_model_lineage_mixed")
  list(valid = !length(errors), errors = unique(errors))
}

# The state authority owns the immutable fixture rows.  Simulation additionally
# requires the Phase 18 framing/table metadata and (when available) the source
# release's score-grid column.  Preserve those source bytes while adapting the
# object shape; never manufacture a score distribution from three-way odds.
.ucl_out_prepare_simulation_ledger <- function(ledger, graph, release, cutoff) {
  if (!is.list(ledger) || !is.data.frame(ledger$ledger)) return(ledger)
  table <- ledger$ledger
  release_rows <- if (is.list(release) && is.data.frame(release$forecast_rows)) release$forecast_rows else NULL
  if (!is.null(release_rows) && "score_grid" %in% names(release_rows)) {
    grids <- release_rows$score_grid[match(as.character(table$fixture_id), as.character(release_rows$fixture_id))]
    table$score_grid <- grids
  }
  row_fn <- if (exists(".ucl_sim_canonical_row_hash", mode = "function")) get(".ucl_sim_canonical_row_hash") else NULL
  table_fn <- if (exists(".ucl_sim_canonical_table_hash", mode = "function")) get(".ucl_sim_canonical_table_hash") else NULL
  if (is.function(row_fn)) {
    table$row_sha256 <- vapply(seq_len(nrow(table)), function(index) {
      row_fn(table[index, , drop = FALSE], schema_tag = "ucl20-forecast-ledger-row-v1")
    }, character(1))
  }
  if (is.function(table_fn)) {
    ledger$table_sha256 <- table_fn(table, key = "fixture_id", schema_tag = "ucl20-forecast-ledger-v1")
    ledger$canonical_hash_version <- "phase18-canonical-v2"
  }
  ledger$ledger <- table
  ledger$forecast_rows <- table
  graph_hash_fn <- if (exists(".ucl_sim_graph_content_hash", mode = "function")) get(".ucl_sim_graph_content_hash") else NULL
  ledger$graph_sha256 <- if (is.function(graph_hash_fn)) as.character(graph_hash_fn(graph)) else as.character(graph$graph_sha256 %||% NA_character_)
  ledger$source_bundle_id <- as.character(graph$source_bundle_id %||% ledger$source_bundle_id %||% NA_character_)
  ledger$state_cutoff_utc <- cutoff
  ledger$information_cutoff_utc <- cutoff
  if (is.null(ledger$model_release_id) && nrow(table)) ledger$model_release_id <- .ucl_out_first(table$model_release_id)
  if (is.null(ledger$model_sha256) && nrow(table)) ledger$model_sha256 <- .ucl_out_first(table$model_sha256)
  if (is.null(ledger$calibrator_sha256) && nrow(table)) ledger$calibrator_sha256 <- .ucl_out_first(table$calibrator_sha256)
  ledger
}

# Phase 18 state hashing is intentionally scalar and rejects nested score-grid
# columns.  Keep those grids in the caller-owned release for the simulation
# seam, but remove them from the release view passed to the state ledger; the
# grids are reattached by .ucl_out_prepare_simulation_ledger after the state
# rows have been validated and hashed.
.ucl_out_release_for_state <- function(release) {
  if (!is.list(release)) return(release)
  result <- release
  for (field in c("forecast_rows", "forecasts")) {
    rows <- result[[field]]
    if (!is.data.frame(rows)) next
    nested <- vapply(rows, is.list, logical(1))
    if (any(nested)) result[[field]] <- rows[, !nested, drop = FALSE]
  }
  result
}

.ucl_out_inventory <- c(
  "competition_topology", "league_schedule", "tie_break_trace",
  "projected_standings", "projected_rankings", "knockout_paths",
  "progression_probabilities", "fixture_forecast_ledger",
  "simulation_metadata", "outcomes_manifest"
)

.ucl_out_schemas <- list(
  competition_topology = c("edition_id", "stage_id", "slot_id", "seed_slot_id", "parent_stage_id", "ruleset_version", "ruleset_sha256", "source_bundle_id", "row_sha256"),
  league_schedule = c("edition_id", "fixture_id", "matchday", "home_club_id", "away_club_id", "venue_id", "kickoff_utc", "lifecycle_status", "score_regulation_home", "score_regulation_away", "score_final_home", "score_final_away", "score_shootout_home", "score_shootout_away", "source_bundle_id", "source_row_sha256", "row_sha256"),
  tie_break_trace = c("edition_id", "tie_group_id", "criterion_order", "criterion_id", "subset_before", "subset_after", "evidence_status", "source_artifact_ids", "decisive", "rank_interval_min", "rank_interval_max", "ruleset_version", "ruleset_sha256", "row_sha256"),
  projected_standings = c("edition_id", "club_id", "played", "wins", "draws", "losses", "goals_for", "goals_against", "goal_difference", "points", "ranking_phase", "rank_interval_min", "rank_interval_max", "qualification_band", "evidence_status", "source_bundle_id", "ruleset_sha256", "row_sha256"),
  projected_rankings = c("edition_id", "club_id", "rank", "rank_interval_min", "rank_interval_max", "rank_status", "decisive_trace_id", "qualification_band", "source_bundle_id", "ruleset_sha256", "row_sha256"),
  knockout_paths = c("edition_id", "path_id", "stage_event_id", "stage_id", "seed_slot_id", "participant_a", "participant_b", "leg_order", "leg_1_venue_id", "leg_2_venue_id", "aggregate_regulation_home", "aggregate_regulation_away", "aggregate_final_home", "aggregate_final_away", "extra_time_applied", "extra_time_home", "extra_time_away", "penalty_applied", "penalty_home", "penalty_away", "draw_policy_id", "draw_artifact_id", "draw_artifact_sha256", "path_status", "unresolved_reason", "source_artifact_ids", "source_bundle_id", "ruleset_sha256", "simulation_run_id", "row_sha256"),
  progression_probabilities = c("edition_id", "club_id", "stage_id", "probability", "status", "source_bundle_id", "ruleset_sha256", "draw_artifact_sha256", "simulation_count", "seed", "run_id", "row_sha256"),
  fixture_forecast_ledger = c("edition_id", "fixture_id", "home_club_id", "away_club_id", "kickoff_utc", "forecast_status", "suppression_reason", "model_release_id", "model_sha256", "calibrator_sha256", "feature_cutoff_utc", "prob_home", "prob_draw", "prob_away", "xg_home", "xg_away", "likely_score", "source_bundle_id", "row_sha256"),
  simulation_metadata = c("run_id", "edition_id", "source_bundle_id", "ruleset_version", "ruleset_sha256", "model_release_id", "model_sha256", "calibrator_sha256", "draw_policy_id", "draw_artifact_id", "draw_artifact_sha256", "information_cutoff_utc", "algorithm_version", "simulation_count", "seed", "path_policy_id", "path_policy_count", "authority_mode", "production_eligible", "status", "run_sha256"),
  outcomes_manifest = c("manifest_id", "edition_id", "run_id", "artifact_path", "artifact_schema_version", "artifact_sha256", "parent_id", "parent_sha256", "authority_mode", "production_eligible", "information_cutoff_utc", "canonical_hash_version", "manifest_sha256")
)

.ucl_out_artifact_hash <- function(data) .ucl_out_canonical_hash(data)

# CSV has no schema for an all-missing column.  Read-back must therefore use
# the validated in-memory column classes; otherwise an all-NA character field
# is inferred as logical and its canonical hash no longer binds the bytes that
# were written.  The artifact schemas contain only scalar CSV-safe columns,
# so unsupported classes are deliberately read as character rather than
# silently inferred.
.ucl_out_csv_col_classes <- function(data) {
  vapply(data, function(column) {
    if (is.integer(column)) return("integer")
    if (is.numeric(column)) return("numeric")
    if (is.logical(column)) return("logical")
    "character"
  }, character(1))
}

.ucl_out_row_hash_valid <- function(data) {
  if (!is.data.frame(data) || !"row_sha256" %in% names(data)) return(FALSE)
  if (!nrow(data)) return(TRUE)
  hashes <- as.character(data$row_sha256)
  if (any(is.na(hashes) | !grepl("^[0-9a-f]{64}$", hashes))) return(FALSE)
  expected <- vapply(seq_len(nrow(data)), function(index) .ucl_out_canonical_hash(data[index, setdiff(names(data), "row_sha256"), drop = FALSE]), character(1))
  identical(tolower(hashes), tolower(expected))
}

.ucl_out_manifest_base <- function(manifest) {
  base <- manifest
  base$manifest_sha256 <- ""
  self <- which(as.character(base$artifact_path) == "outcomes_manifest.csv")
  if (length(self) == 1L) base$artifact_sha256[[self]] <- ""
  base
}

.ucl_out_validate_manifest <- function(manifest, graph = NULL) {
  fields <- .ucl_out_schemas$outcomes_manifest
  errors <- character()
  if (!is.data.frame(manifest) || !identical(names(manifest), fields)) return(list(valid = FALSE, errors = "manifest_schema"))
  if (nrow(manifest) != length(.ucl_out_inventory)) errors <- c(errors, "manifest_cardinality")
  expected_paths <- paste0(.ucl_out_inventory, ".csv")
  if (!identical(sort(unique(as.character(manifest$artifact_path))), sort(expected_paths)) || anyDuplicated(as.character(manifest$artifact_path))) errors <- c(errors, "manifest_paths")
  hashes <- as.character(manifest$artifact_sha256)
  parents <- as.character(manifest$parent_sha256)
  self_hash <- as.character(manifest$manifest_sha256)
  if (any(is.na(hashes) | !grepl("^[0-9a-f]{64}$", hashes))) errors <- c(errors, "manifest_artifact_hashes")
  if (any(is.na(parents) | !grepl("^[0-9a-f]{64}$", parents))) errors <- c(errors, "manifest_parent_hashes")
  if (any(is.na(self_hash) | !grepl("^[0-9a-f]{64}$", self_hash)) || length(unique(self_hash)) != 1L) errors <- c(errors, "manifest_self_hash")
  self <- which(as.character(manifest$artifact_path) == "outcomes_manifest.csv")
  if (length(self) == 1L && all(grepl("^[0-9a-f]{64}$", hashes))) {
    expected_self_artifact <- .ucl_out_canonical_hash(.ucl_out_manifest_base(manifest))
    if (!identical(as.character(manifest$artifact_sha256[[self]]), expected_self_artifact)) errors <- c(errors, "manifest_self_artifact_hash")
    seed <- manifest
    seed$manifest_sha256 <- ""
    if (!identical(as.character(manifest$manifest_sha256[[1L]]), .ucl_out_canonical_hash(seed))) errors <- c(errors, "manifest_self_hash_mismatch")
  }
  list(valid = !length(errors), errors = unique(errors))
}

.ucl_out_validate_artifact_tables <- function(artifacts, graph = NULL, rules = NULL, simulation = NULL) {
  errors <- character()
  if (!is.list(artifacts) || !identical(sort(names(artifacts), method = "radix"), sort(.ucl_out_inventory, method = "radix"))) return(list(valid = FALSE, errors = "artifact_inventory"))
  for (name in .ucl_out_inventory[.ucl_out_inventory != "outcomes_manifest"]) {
    table <- artifacts[[name]]
    if (!is.data.frame(table) || !identical(names(table), .ucl_out_schemas[[name]])) {
      errors <- c(errors, paste0("schema:", name))
    } else if (identical(name, "simulation_metadata") && (nrow(table) != 1L || is.na(table$run_sha256[[1L]]) || !grepl("^[0-9a-f]{64}$", as.character(table$run_sha256[[1L]])) || !identical(as.character(table$run_sha256[[1L]]), .ucl_out_canonical_hash(table[, setdiff(names(table), "run_sha256"), drop = FALSE])))) {
      errors <- c(errors, paste0("run_hash:", name))
    } else if (!identical(name, "simulation_metadata") && !.ucl_out_row_hash_valid(table)) {
      errors <- c(errors, paste0("row_hash:", name))
    }
  }
  if (is.data.frame(artifacts$competition_topology) && nrow(artifacts$competition_topology) != 36L) errors <- c(errors, "topology_cardinality")
  if (is.data.frame(artifacts$league_schedule) && nrow(artifacts$league_schedule) != 144L) errors <- c(errors, "schedule_cardinality")
  if (is.data.frame(artifacts$fixture_forecast_ledger) && nrow(artifacts$fixture_forecast_ledger) != 144L) errors <- c(errors, "forecast_cardinality")
  if (is.data.frame(artifacts$simulation_metadata) && nrow(artifacts$simulation_metadata) != 1L) errors <- c(errors, "metadata_cardinality")
  if (is.data.frame(artifacts$simulation_metadata) && nrow(artifacts$simulation_metadata) == 1L) {
    metadata <- artifacts$simulation_metadata
    if (is.na(metadata$run_id[[1L]]) || !nzchar(as.character(metadata$run_id[[1L]])) || is.na(metadata$source_bundle_id[[1L]]) || !nzchar(as.character(metadata$source_bundle_id[[1L]])) || is.na(metadata$ruleset_sha256[[1L]]) || !grepl("^[0-9a-f]{64}$", as.character(metadata$ruleset_sha256[[1L]]))) errors <- c(errors, "metadata_lineage")
    if (is.na(metadata$production_eligible[[1L]]) || isTRUE(as.logical(metadata$production_eligible[[1L]]))) errors <- c(errors, "production_promotion")
  }
  if (is.data.frame(artifacts$league_schedule) && is.data.frame(artifacts$fixture_forecast_ledger) && nrow(artifacts$league_schedule) == 144L && nrow(artifacts$fixture_forecast_ledger) == 144L && !identical(sort(as.character(artifacts$league_schedule$fixture_id)), sort(as.character(artifacts$fixture_forecast_ledger$fixture_id)))) errors <- c(errors, "forecast_fixture_coverage")
  manifest_check <- .ucl_out_validate_manifest(artifacts$outcomes_manifest, graph = graph)
  errors <- c(errors, manifest_check$errors)
  if (is.data.frame(artifacts$outcomes_manifest) && nrow(artifacts$outcomes_manifest)) {
    manifest <- artifacts$outcomes_manifest
    if (length(unique(as.character(manifest$manifest_id))) != 1L ||
        length(unique(as.character(manifest$edition_id))) != 1L ||
        length(unique(as.character(manifest$run_id))) != 1L) {
      errors <- c(errors, "manifest_lineage_identity")
    }
    # The manifest is an integrity index, not a second caller-owned claim.
    # Recompute every table hash from the actual in-memory bytes and compare it
    # with the matching manifest row.  The self row is checked separately by
    # .ucl_out_validate_manifest because it commits the manifest's own bytes.
    for (name in setdiff(.ucl_out_inventory, "outcomes_manifest")) {
      row <- manifest[as.character(manifest$artifact_path) == paste0(name, ".csv"), , drop = FALSE]
      if (nrow(row) != 1L || !identical(as.character(row$artifact_sha256[[1L]]), .ucl_out_artifact_hash(artifacts[[name]]))) {
        errors <- c(errors, paste0("manifest_artifact_hash:", name))
      }
    }
    manifest_production <- suppressWarnings(as.logical(artifacts$outcomes_manifest$production_eligible))
    if (any(is.na(manifest_production) | manifest_production)) errors <- c(errors, "manifest_production_promotion")
  }
  if (is.data.frame(artifacts$outcomes_manifest) && is.data.frame(artifacts$simulation_metadata) && nrow(artifacts$simulation_metadata) == 1L) {
    manifest_runs <- as.character(artifacts$outcomes_manifest$run_id)
    metadata_run <- as.character(artifacts$simulation_metadata$run_id[[1L]])
    if (length(manifest_runs) != nrow(artifacts$outcomes_manifest) ||
        length(metadata_run) != 1L || is.na(metadata_run) || !nzchar(metadata_run) ||
        anyNA(manifest_runs) || any(!nzchar(manifest_runs)) ||
        any(manifest_runs != metadata_run)) {
      errors <- c(errors, "manifest_run_lineage")
    }
  }
  list(valid = !length(errors), errors = unique(errors))
}

.ucl_out_build_manifest <- function(artifacts, graph, simulation, metadata, fixture_authority = TRUE) {
  fields <- .ucl_out_schemas$outcomes_manifest
  run_id <- as.character(metadata$run_id[[1L]] %||% NA_character_)
  edition_id <- as.character(metadata$edition_id[[1L]] %||% graph$edition_id)
  parent_id <- as.character(graph$source_bundle_id %||% "")
  parent_hash <- as.character(graph$graph_sha256 %||% .ucl_out_hash(parent_id))
  if (!grepl("^[0-9a-f]{64}$", parent_hash)) parent_hash <- .ucl_out_hash(parent_hash)
  manifest_id <- paste0("ucl-outcomes-", substr(.ucl_out_hash(c(edition_id, run_id)), 1L, 16L))
  rows <- lapply(.ucl_out_inventory, function(name) {
    data.frame(manifest_id = manifest_id, edition_id = edition_id, run_id = run_id, artifact_path = paste0(name, ".csv"), artifact_schema_version = "ucl-outcome-candidate-v2", artifact_sha256 = if (name == "outcomes_manifest") "" else .ucl_out_artifact_hash(artifacts[[name]]), parent_id = parent_id, parent_sha256 = parent_hash, authority_mode = if (fixture_authority) "fixture" else "production", production_eligible = FALSE, information_cutoff_utc = as.character(metadata$information_cutoff_utc[[1L]] %||% NA_character_), canonical_hash_version = "ucl-canonical-v2", manifest_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE)
  })
  manifest <- do.call(rbind, rows)
  self <- match("outcomes_manifest.csv", as.character(manifest$artifact_path))
  manifest$artifact_sha256[[self]] <- .ucl_out_artifact_hash(.ucl_out_manifest_base(manifest))
  manifest$manifest_sha256 <- .ucl_out_artifact_hash(manifest)
  manifest[, fields, drop = FALSE]
}

.ucl_out_parent_reason <- function(authority = NULL, candidate = NULL) {
  original <- if (is.list(authority)) authority$original_parent_reason %||% authority$parent_reason %||% authority$error else NULL
  if (is.null(original) && is.list(candidate)) original <- candidate$original_parent_reason %||% candidate$parent_reason
  original <- if (length(original) && !is.na(original[[1L]])) as.character(original[[1L]]) else ""
  if (identical(original, "no_accepted_current_ucl")) return(list(status = "production_human_needed", human_needed_reason = "phase18_authority_missing", production_blocked_reason = NA_character_, normalization_error = FALSE, original_parent_reason = original))
  if (original %in% c("no_accepted_club_history", "protocol_policy_not_approved", "fold_inventory_not_approved", "phase19_cr01_roster_mismatch", "phase19_cr02_rating_replay_unverified", "phase19_cr03_fold_identity_unverified", "phase19_cr04_probability_lineage_unverified", "phase19_cr05_unbacked_installer")) return(list(status = "production_human_needed", human_needed_reason = "phase19_cr01_cr05_repair_pending", production_blocked_reason = NA_character_, normalization_error = FALSE, original_parent_reason = original))
  if (identical(original, "phase19_selector_not_accepted")) return(list(status = "production_human_needed", human_needed_reason = "phase19_selector_not_accepted", production_blocked_reason = NA_character_, normalization_error = FALSE, original_parent_reason = original))
  if (!nzchar(original)) return(list(status = "production_blocked", human_needed_reason = NA_character_, production_blocked_reason = "unrecognized_parent_reason", normalization_error = TRUE, original_parent_reason = original))
  list(status = "production_blocked", human_needed_reason = NA_character_, production_blocked_reason = "unrecognized_parent_reason", normalization_error = TRUE, original_parent_reason = original)
}

.ucl_out_graph <- function(candidate) {
  if (is.list(candidate) && !is.null(candidate$graph)) return(candidate$graph)
  if (is.list(candidate) && is.list(candidate$state) && !is.null(candidate$state$graph)) return(candidate$state$graph)
  NULL
}

.ucl_out_state <- function(candidate) {
  if (is.list(candidate) && is.list(candidate$state) && !is.null(candidate$state$graph)) return(candidate$state)
  if (is.list(candidate) && !is.null(candidate$graph) && !is.null(candidate$standings)) return(candidate)
  NULL
}

.ucl_out_ledger <- function(candidate) {
  ledger <- if (is.list(candidate) && is.list(candidate$ledger) && is.data.frame(candidate$ledger$ledger)) candidate$ledger$ledger else if (is.list(candidate) && is.data.frame(candidate$ledger)) candidate$ledger else NULL
  if (is.null(ledger) && is.list(candidate) && is.data.frame(candidate$forecast_ledger)) ledger <- candidate$forecast_ledger
  ledger
}

.ucl_out_simulation <- function(candidate) {
  if (is.list(candidate) && is.list(candidate$simulation)) return(candidate$simulation)
  if (is.list(candidate) && !is.null(candidate$rank_rows) && !is.null(candidate$metadata)) return(candidate)
  NULL
}

.ucl_out_topology <- function(graph, rules) {
  fields <- c("edition_id", "stage_id", "slot_id", "seed_slot_id", "parent_stage_id", "ruleset_version", "ruleset_sha256", "source_bundle_id", "row_sha256")
  if (is.null(graph) || !is.data.frame(graph$clubs)) return(.ucl_out_empty(fields))
  data <- data.frame(
    edition_id = as.character(graph$edition_id), stage_id = "league_phase",
    slot_id = as.character(graph$clubs$club_id), seed_slot_id = NA_character_, parent_stage_id = NA_character_,
    ruleset_version = rules$ruleset_version, ruleset_sha256 = rules$ruleset_sha256,
    source_bundle_id = graph$source_bundle_id, row_sha256 = NA_character_, stringsAsFactors = FALSE, check.names = FALSE
  )
  data <- data[order(as.character(data$slot_id), method = "radix"), , drop = FALSE]
  data$row_sha256 <- vapply(seq_len(nrow(data)), function(index) .ucl_out_canonical_hash(data[index, setdiff(fields, "row_sha256"), drop = FALSE]), character(1))
  data[, fields, drop = FALSE]
}

.ucl_out_schedule <- function(graph) {
  fields <- c("edition_id", "fixture_id", "matchday", "home_club_id", "away_club_id", "venue_id", "kickoff_utc", "lifecycle_status", "score_regulation_home", "score_regulation_away", "score_final_home", "score_final_away", "score_shootout_home", "score_shootout_away", "source_bundle_id", "source_row_sha256", "row_sha256")
  if (is.null(graph) || !is.data.frame(graph$fixtures)) return(.ucl_out_empty(fields))
  fixtures <- graph$fixtures
  data <- data.frame(
    edition_id = as.character(fixtures$edition_id), fixture_id = as.character(fixtures$fixture_id), matchday = as.integer(fixtures$matchday),
    home_club_id = as.character(fixtures$home_club_id), away_club_id = as.character(fixtures$away_club_id), venue_id = as.character(fixtures$venue_id), kickoff_utc = as.character(fixtures$kickoff_utc), lifecycle_status = as.character(fixtures$match_status),
    score_regulation_home = as.integer(fixtures$regulation_home_goals), score_regulation_away = as.integer(fixtures$regulation_away_goals), score_final_home = as.integer(fixtures$final_home_goals), score_final_away = as.integer(fixtures$final_away_goals), score_shootout_home = as.integer(fixtures$shootout_home_goals), score_shootout_away = as.integer(fixtures$shootout_away_goals),
    source_bundle_id = as.character(fixtures$source_bundle_id), source_row_sha256 = as.character(fixtures$source_row_sha256), row_sha256 = NA_character_, stringsAsFactors = FALSE, check.names = FALSE
  )
  data$row_sha256 <- vapply(seq_len(nrow(data)), function(index) .ucl_out_canonical_hash(data[index, setdiff(fields, "row_sha256"), drop = FALSE]), character(1))
  data[order(data$fixture_id, method = "radix"), fields, drop = FALSE]
}

.ucl_out_trace <- function(state, rules) {
  fields <- c("edition_id", "tie_group_id", "criterion_order", "criterion_id", "subset_before", "subset_after", "evidence_status", "source_artifact_ids", "decisive", "rank_interval_min", "rank_interval_max", "ruleset_version", "ruleset_sha256", "row_sha256")
  trace <- if (is.list(state)) state$tie_break_trace else NULL
  if (is.null(trace) || !is.data.frame(trace)) return(.ucl_out_empty(fields))
  data <- .ucl_out_coerce(trace, fields, list(edition_id = state$edition_id, ruleset_version = rules$ruleset_version, ruleset_sha256 = rules$ruleset_sha256))
  if (nrow(data)) data <- data[do.call(order, c(lapply(data[setdiff(fields, "row_sha256")], function(column) vapply(column, .ucl_out_scalar, character(1))), list(method = "radix", na.last = TRUE))), , drop = FALSE]
  data$row_sha256 <- vapply(seq_len(nrow(data)), function(index) .ucl_out_canonical_hash(data[index, setdiff(fields, "row_sha256"), drop = FALSE]), character(1))
  data[, fields, drop = FALSE]
}

.ucl_out_standings <- function(state, rules) {
  fields <- c("edition_id", "club_id", "played", "wins", "draws", "losses", "goals_for", "goals_against", "goal_difference", "points", "ranking_phase", "rank_interval_min", "rank_interval_max", "qualification_band", "evidence_status", "source_bundle_id", "ruleset_sha256", "row_sha256")
  if (is.null(state) || !is.data.frame(state$universal_standings)) return(.ucl_out_empty(fields))
  base <- state$universal_standings
  ids <- if ("team_id" %in% names(base)) base$team_id else base$club_id
  ranking <- state$standings
  rank_rows <- if (is.data.frame(ranking)) ranking else data.frame(club_id = ids, rank = NA_integer_, rank_interval_min = NA_integer_, rank_interval_max = NA_integer_, qualification_band = NA_character_, rank_status = "unresolved", stringsAsFactors = FALSE)
  data <- data.frame(
    edition_id = as.character(base$edition_id %||% state$edition_id), club_id = as.character(ids), played = as.integer(base$played %||% 0L), wins = as.integer(base$wins %||% 0L), draws = as.integer(base$draws %||% 0L), losses = as.integer(base$losses %||% 0L), goals_for = as.integer(base$goals_for %||% 0L), goals_against = as.integer(base$goals_against %||% 0L), goal_difference = as.integer(base$goal_difference %||% 0L), points = as.integer(base$points %||% 0L), ranking_phase = "league_phase", rank_interval_min = as.integer(rank_rows$rank_interval_min[match(as.character(ids), as.character(rank_rows$club_id))]), rank_interval_max = as.integer(rank_rows$rank_interval_max[match(as.character(ids), as.character(rank_rows$club_id))]), qualification_band = as.character(rank_rows$qualification_band[match(as.character(ids), as.character(rank_rows$club_id))]), evidence_status = ifelse(is.na(rank_rows$rank_interval_min[match(as.character(ids), as.character(rank_rows$club_id))]), "unresolved", "available"), source_bundle_id = state$source_bundle_id, ruleset_sha256 = rules$ruleset_sha256, row_sha256 = NA_character_, stringsAsFactors = FALSE, check.names = FALSE
  )
  data$row_sha256 <- vapply(seq_len(nrow(data)), function(index) .ucl_out_canonical_hash(data[index, setdiff(fields, "row_sha256"), drop = FALSE]), character(1))
  data[order(data$club_id, method = "radix"), fields, drop = FALSE]
}

.ucl_out_rankings <- function(state, rules) {
  fields <- c("edition_id", "club_id", "rank", "rank_interval_min", "rank_interval_max", "rank_status", "decisive_trace_id", "qualification_band", "source_bundle_id", "ruleset_sha256", "row_sha256")
  if (is.null(state) || !is.data.frame(state$standings)) return(.ucl_out_empty(fields))
  ranking <- state$standings
  data <- data.frame(edition_id = as.character(state$edition_id), club_id = as.character(ranking$club_id), rank = as.integer(ranking$rank), rank_interval_min = as.integer(ranking$rank_interval_min), rank_interval_max = as.integer(ranking$rank_interval_max), rank_status = as.character(ranking$rank_status), decisive_trace_id = NA_character_, qualification_band = as.character(ranking$qualification_band), source_bundle_id = state$source_bundle_id, ruleset_sha256 = rules$ruleset_sha256, row_sha256 = NA_character_, stringsAsFactors = FALSE, check.names = FALSE)
  data$row_sha256 <- vapply(seq_len(nrow(data)), function(index) .ucl_out_canonical_hash(data[index, setdiff(fields, "row_sha256"), drop = FALSE]), character(1))
  data[order(data$club_id, method = "radix"), fields, drop = FALSE]
}

.ucl_out_paths <- function(simulation, rules) {
  fields <- c("edition_id", "path_id", "stage_event_id", "stage_id", "seed_slot_id", "participant_a", "participant_b", "leg_order", "leg_1_venue_id", "leg_2_venue_id", "aggregate_regulation_home", "aggregate_regulation_away", "aggregate_final_home", "aggregate_final_away", "extra_time_applied", "extra_time_home", "extra_time_away", "penalty_applied", "penalty_home", "penalty_away", "draw_policy_id", "draw_artifact_id", "draw_artifact_sha256", "path_status", "unresolved_reason", "source_artifact_ids", "source_bundle_id", "ruleset_sha256", "simulation_run_id", "row_sha256")
  paths <- if (is.list(simulation)) simulation$knockout_paths else NULL
  if (is.null(paths) || !is.data.frame(paths)) return(.ucl_out_empty(fields))
  data <- .ucl_out_coerce(paths, fields, list(edition_id = rules$edition_id, draw_policy_id = rules$draw_policy_id, ruleset_sha256 = rules$ruleset_sha256, simulation_run_id = if (is.list(simulation)) simulation$run_id else NA_character_))
  missing_event <- is.na(data$stage_event_id) | !nzchar(as.character(data$stage_event_id))
  data$stage_event_id[missing_event] <- as.character(data$path_id[missing_event])
  if ("source_artifact_ids" %in% names(paths) && "source_artifact_ids" %in% names(data)) data$source_artifact_ids <- as.character(data$source_artifact_ids)
  unresolved_draw <- any(as.character(data$path_status) %in% c("unresolved", "pre_draw_legal")) || identical(as.character(simulation$status %||% ""), "unresolved_draw_procedure")
  if (unresolved_draw && nrow(data)) {
    required_stages <- c("knockout_play_off", "round_of_16", "quarter_final", "semi_final", "final", "champion")
    missing_stages <- setdiff(required_stages, unique(as.character(data$stage_id)))
    if (length(missing_stages)) {
      unresolved_reason <- as.character(data$unresolved_reason)[!is.na(data$unresolved_reason) & nzchar(as.character(data$unresolved_reason))]
      unresolved_reason <- if (length(unresolved_reason)) unresolved_reason[[1L]] else "missing_edition_draw_procedure"
      extra <- data[rep(1L, length(missing_stages)), fields, drop = FALSE]
      for (field in fields) extra[[field]] <- rep(NA, length(missing_stages))
      extra$edition_id <- rules$edition_id
      extra$path_id <- paste0("suppressed-", missing_stages)
      extra$stage_event_id <- extra$path_id
      extra$stage_id <- missing_stages
      extra$leg_order <- ifelse(missing_stages == "final", "single_neutral", "seeded_return_leg")
      extra$draw_policy_id <- rules$draw_policy_id
      extra$path_status <- "suppressed"
      extra$unresolved_reason <- unresolved_reason
      extra$source_bundle_id <- as.character(simulation$metadata$source_bundle_id %||% NA_character_)
      extra$ruleset_sha256 <- rules$ruleset_sha256
      extra$simulation_run_id <- as.character(simulation$run_id %||% NA_character_)
      data <- rbind(data, extra)
    }
  }
  if (nrow(data)) data <- data[order(as.character(data$stage_id), as.character(data$stage_event_id), as.character(data$path_id), method = "radix"), , drop = FALSE]
  data$row_sha256 <- vapply(seq_len(nrow(data)), function(index) .ucl_out_canonical_hash(data[index, setdiff(fields, "row_sha256"), drop = FALSE]), character(1))
  data[, fields, drop = FALSE]
}

.ucl_out_progression <- function(simulation, rules) {
  fields <- c("edition_id", "club_id", "stage_id", "probability", "status", "source_bundle_id", "ruleset_sha256", "draw_artifact_sha256", "simulation_count", "seed", "run_id", "row_sha256")
  if (is.list(simulation) && is.data.frame(simulation$progression_probabilities) && nrow(simulation$progression_probabilities)) {
    output <- .ucl_out_coerce(simulation$progression_probabilities, fields, list(edition_id = rules$edition_id, ruleset_sha256 = rules$ruleset_sha256, run_id = simulation$run_id %||% NA_character_))
    output <- output[order(as.character(output$club_id), match(as.character(output$stage_id), c("knockout_play_off", "round_of_16", "quarter_final", "semi_final", "final", "champion", "direct_round_of_16", "eliminated")), method = "radix"), , drop = FALSE]
    output$row_sha256 <- vapply(seq_len(nrow(output)), function(index) .ucl_out_canonical_hash(output[index, setdiff(fields, "row_sha256"), drop = FALSE]), character(1))
    return(output[, fields, drop = FALSE])
  }
  rows <- if (is.list(simulation) && is.data.frame(simulation$rank_rows)) simulation$rank_rows else data.frame()
  if (!nrow(rows)) return(.ucl_out_empty(fields))
  output <- do.call(rbind, lapply(sort(unique(as.character(rows$club_id)), method = "radix"), function(club) {
    value <- rows[as.character(rows$club_id) == club, , drop = FALSE]
    bands <- c("direct_round_of_16", "knockout_play_off", "eliminated")
    ranks <- as.numeric(value$rank)
    safe_mean <- function(values) if (all(is.na(values))) NA_real_ else mean(values, na.rm = TRUE)
    probabilities <- c(safe_mean(ranks >= 1 & ranks <= 8), safe_mean(ranks >= 9 & ranks <= 24), safe_mean(ranks >= 25 & ranks <= 36))
    base <- data.frame(edition_id = as.character(simulation$metadata$edition_id %||% NA_character_), club_id = club, stage_id = bands, probability = probabilities, status = ifelse(any(is.na(ranks)), "unresolved", "resolved"), source_bundle_id = simulation$metadata$source_bundle_id %||% NA_character_, ruleset_sha256 = simulation$metadata$ruleset_sha256 %||% rules$ruleset_sha256, draw_artifact_sha256 = simulation$metadata$draw_artifact_sha256 %||% NA_character_, simulation_count = as.integer(simulation$metadata$simulation_count %||% length(unique(rows$iteration))), seed = as.integer(simulation$metadata$seed %||% NA_integer_), run_id = simulation$run_id %||% NA_character_, row_sha256 = NA_character_, stringsAsFactors = FALSE, check.names = FALSE)
    if (identical(as.character(simulation$status %||% ""), "unresolved_draw_procedure")) {
      unresolved_stages <- data.frame(edition_id = base$edition_id[[1L]], club_id = club, stage_id = c("round_of_16", "quarter_final", "semi_final", "final", "champion"), probability = NA_real_, status = "unresolved", source_bundle_id = base$source_bundle_id[[1L]], ruleset_sha256 = base$ruleset_sha256[[1L]], draw_artifact_sha256 = base$draw_artifact_sha256[[1L]], simulation_count = base$simulation_count[[1L]], seed = base$seed[[1L]], run_id = base$run_id[[1L]], row_sha256 = NA_character_, stringsAsFactors = FALSE, check.names = FALSE)
      return(rbind(base, unresolved_stages))
    }
    base
  }))
  stage_order <- c("direct_round_of_16", "knockout_play_off", "round_of_16", "quarter_final", "semi_final", "final", "champion", "eliminated")
  output <- output[order(as.character(output$club_id), match(as.character(output$stage_id), stage_order), method = "radix"), , drop = FALSE]
  output$row_sha256 <- vapply(seq_len(nrow(output)), function(index) .ucl_out_canonical_hash(output[index, setdiff(fields, "row_sha256"), drop = FALSE]), character(1))
  output[, fields, drop = FALSE]
}

.ucl_out_ledger_table <- function(ledger) {
  fields <- c("edition_id", "fixture_id", "home_club_id", "away_club_id", "kickoff_utc", "forecast_status", "suppression_reason", "model_release_id", "model_sha256", "calibrator_sha256", "feature_cutoff_utc", "prob_home", "prob_draw", "prob_away", "xg_home", "xg_away", "likely_score", "source_bundle_id", "row_sha256")
  if (is.null(ledger) || !is.data.frame(ledger)) return(.ucl_out_empty(fields))
  data <- .ucl_out_coerce(ledger, fields)
  data <- data[order(as.character(data$fixture_id), method = "radix"), fields, drop = FALSE]
  data$row_sha256 <- vapply(seq_len(nrow(data)), function(index) .ucl_out_canonical_hash(data[index, setdiff(fields, "row_sha256"), drop = FALSE]), character(1))
  data[, fields, drop = FALSE]
}

.ucl_out_metadata <- function(simulation, ledger, graph, rules) {
  fields <- c("run_id", "edition_id", "source_bundle_id", "ruleset_version", "ruleset_sha256", "model_release_id", "model_sha256", "calibrator_sha256", "draw_policy_id", "draw_artifact_id", "draw_artifact_sha256", "information_cutoff_utc", "algorithm_version", "simulation_count", "seed", "path_policy_id", "path_policy_count", "authority_mode", "production_eligible", "status", "run_sha256")
  metadata <- if (is.list(simulation)) simulation$metadata else list()
  table <- .ucl_out_table(ledger)
  release_id <- if (is.data.frame(table) && nrow(table)) .ucl_out_first(unique(as.character(table$model_release_id))) else NA_character_
  model_hash <- if (is.data.frame(table) && nrow(table)) .ucl_out_first(unique(as.character(table$model_sha256))) else NA_character_
  calibrator_hash <- if (is.data.frame(table) && nrow(table)) .ucl_out_first(unique(as.character(table$calibrator_sha256))) else NA_character_
  data <- data.frame(
    run_id = as.character(.ucl_out_first(metadata$run_id %||% if (is.list(simulation)) simulation$run_id else NULL)),
    edition_id = as.character(.ucl_out_first(metadata$edition_id %||% graph$edition_id)),
    source_bundle_id = as.character(.ucl_out_first(metadata$source_bundle_id %||% graph$source_bundle_id)),
    ruleset_version = as.character(.ucl_out_first(metadata$ruleset_version %||% rules$ruleset_version)),
    ruleset_sha256 = as.character(.ucl_out_first(metadata$ruleset_sha256 %||% rules$ruleset_sha256)),
    model_release_id = as.character(release_id), model_sha256 = as.character(model_hash), calibrator_sha256 = as.character(calibrator_hash),
    draw_policy_id = as.character(.ucl_out_first(metadata$draw_policy_id %||% rules$draw_policy_id)),
    draw_artifact_id = as.character(.ucl_out_first(metadata$draw_artifact_id)),
    draw_artifact_sha256 = as.character(.ucl_out_first(metadata$draw_artifact_sha256)),
    information_cutoff_utc = as.character(.ucl_out_first(metadata$information_cutoff_utc)),
    algorithm_version = as.character(.ucl_out_first(metadata$algorithm_version, "ucl-conditional-league-v1")),
    simulation_count = as.integer(.ucl_out_first(metadata$simulation_count, NA_integer_)),
    seed = as.integer(.ucl_out_first(metadata$seed, NA_integer_)),
    path_policy_id = as.character(.ucl_out_first(metadata$path_policy_id, "ucl-rank-constrained-pre-draw-v1")),
    path_policy_count = as.integer(.ucl_out_first(metadata$path_policy_count, 0L)),
    authority_mode = as.character(.ucl_out_first(metadata$authority_mode %||% graph$authority_mode)),
    production_eligible = FALSE,
    status = as.character(.ucl_out_first(metadata$status, "unresolved_draw_procedure")),
    run_sha256 = NA_character_, stringsAsFactors = FALSE, check.names = FALSE
  )
  data$run_sha256 <- .ucl_out_canonical_hash(data[, setdiff(fields, "run_sha256"), drop = FALSE])
  data[, fields, drop = FALSE]
}

.ucl_out_stage_inventory <- function() {
  c(knockout_play_off = 8L, round_of_16 = 8L, quarter_final = 4L,
    semi_final = 2L, final = 1L, champion = 1L)
}

.ucl_out_validate_stage_events <- function(events, rules) {
  inventory <- .ucl_out_stage_inventory()
  if (!is.data.frame(events) || !nrow(events)) return(list(valid = FALSE, errors = "stage_events_missing", aggregate = data.frame()))
  if (!"stage_id" %in% names(events) || nrow(events) != sum(inventory) ||
      !setequal(unique(as.character(events$stage_id)), names(inventory))) {
    return(list(valid = FALSE, errors = "stage_inventory_incomplete", aggregate = data.frame()))
  }
  if (!exists("ucl_aggregate_stage_events", mode = "function")) {
    return(list(valid = FALSE, errors = "stage_event_validator_missing", aggregate = data.frame()))
  }
  aggregate <- ucl_aggregate_stage_events(
    events, rules = rules, stage_inputs = inventory,
    league_bands = c(direct_round_of_16 = 8L, knockout_play_off = 16L, eliminated = 12L),
    required_stage_ids = names(inventory)
  )
  valid <- isTRUE(attr(aggregate, "valid"))
  errors <- if (valid) character() else as.character(attr(aggregate, "errors") %||% "stage_event_reconciliation_failed")
  list(valid = valid, errors = unique(errors), aggregate = aggregate)
}

.ucl_out_validate_progression <- function(progression, graph, simulation) {
  inventory <- .ucl_out_stage_inventory()
  required <- c("direct_round_of_16", "knockout_play_off", "eliminated", names(inventory)[-1L])
  if (!is.data.frame(progression) || !nrow(progression)) return(list(valid = FALSE, errors = "progression_empty", reconciliation = list(valid = FALSE, errors = "progression_empty")))
  if (!all(c("club_id", "stage_id", "probability", "status") %in% names(progression))) return(list(valid = FALSE, errors = "progression_schema_incomplete", reconciliation = list(valid = FALSE, errors = "progression_schema_incomplete")))
  clubs <- if (is.data.frame(graph$clubs)) sort(unique(as.character(graph$clubs$club_id)), method = "radix") else character()
  if (length(clubs) != 36L || anyNA(clubs) || any(!nzchar(clubs))) return(list(valid = FALSE, errors = "progression_club_inventory_invalid", reconciliation = list(valid = FALSE, errors = "progression_club_inventory_invalid")))
  combinations <- paste(rep(clubs, each = length(required)), rep(required, length(clubs)), sep = "\x1f")
  observed <- paste(as.character(progression$club_id), as.character(progression$stage_id), sep = "\x1f")
  errors <- character()
  if (nrow(progression) != length(combinations) || anyDuplicated(observed) || !setequal(observed, combinations)) errors <- c(errors, "progression_stage_inventory_incomplete")
  if (any(!as.character(progression$status) %in% c("resolved", "unresolved", "suppressed"))) errors <- c(errors, "progression_status_invalid")
  values <- suppressWarnings(as.numeric(progression$probability))
  resolved <- as.character(progression$status) == "resolved"
  if (any(resolved & (!is.finite(values) | values < 0 | values > 1))) errors <- c(errors, "resolved_probability_invalid")
  unresolved <- !resolved
  if (any(unresolved & !is.na(values))) errors <- c(errors, "unresolved_probability_must_be_na")
  reconciliation <- if (exists("ucl_validate_progression_reconciliation", mode = "function")) {
    ucl_validate_progression_reconciliation(
      progression, stage_inputs = inventory,
      league_bands = c(direct_round_of_16 = 8L, knockout_play_off = 16L, eliminated = 12L),
      required_stage_ids = required
    )
  } else list(valid = FALSE, errors = "progression_validator_missing")
  if (!isTRUE(reconciliation$valid)) errors <- c(errors, reconciliation$errors)
  list(valid = !length(errors), errors = unique(errors), reconciliation = reconciliation)
}

.ucl_out_sim_table_hash <- function(data, key, schema_tag) {
  if (!is.data.frame(data)) return(NA_character_)
  fn <- if (exists(".ucl_sim_canonical_table_hash", mode = "function")) get(".ucl_sim_canonical_table_hash") else NULL
  if (!is.function(fn)) return(NA_character_)
  tryCatch(fn(data, key = key, schema_tag = schema_tag), error = function(error) NA_character_)
}

.ucl_out_validate_component_binding <- function(candidate, graph, state, ledger_object, ledger_table, simulation) {
  failures <- character()
  if (!is.list(simulation) || !is.list(simulation$metadata)) return("simulation_metadata_missing")
  metadata <- simulation$metadata
  graph_fn <- if (exists(".ucl_sim_graph_content_hash", mode = "function")) get(".ucl_sim_graph_content_hash") else NULL
  state_fn <- if (exists(".ucl_sim_state_content_hash", mode = "function")) get(".ucl_sim_state_content_hash") else NULL
  graph_hash <- if (is.function(graph_fn)) tryCatch(as.character(graph_fn(graph)), error = function(error) NA_character_) else NA_character_
  state_hash <- if (is.function(state_fn)) tryCatch(as.character(state_fn(state, graph)), error = function(error) NA_character_) else NA_character_
  ledger_hash <- .ucl_out_sim_table_hash(ledger_table, "fixture_id", "ucl20-forecast-ledger-v1")
  simulation_ledger_hash <- .ucl_out_sim_table_hash(simulation$ledger, "fixture_id", "ucl20-forecast-ledger-v1")
  if (is.na(graph_hash) || !identical(tolower(graph_hash), tolower(as.character(metadata$graph_sha256 %||% "")))) failures <- c(failures, "component_graph_hash_mismatch")
  if (is.na(state_hash) || !identical(tolower(state_hash), tolower(as.character(metadata$state_sha256 %||% "")))) failures <- c(failures, "component_state_hash_mismatch")
  if (is.na(ledger_hash) || !identical(tolower(ledger_hash), tolower(as.character(metadata$ledger_sha256 %||% "")))) failures <- c(failures, "component_ledger_hash_mismatch")
  if (is.na(simulation_ledger_hash) || !identical(tolower(simulation_ledger_hash), tolower(as.character(metadata$ledger_sha256 %||% "")))) failures <- c(failures, "simulation_ledger_hash_mismatch")
  if (!identical(as.character(simulation$run_id %||% ""), as.character(metadata$run_id %||% ""))) failures <- c(failures, "simulation_run_identity_mismatch")
  if (!identical(tolower(as.character(simulation$graph_sha256 %||% "")), tolower(graph_hash))) failures <- c(failures, "simulation_graph_identity_mismatch")
  if (!identical(tolower(as.character(simulation$state_sha256 %||% "")), tolower(state_hash))) failures <- c(failures, "simulation_state_identity_mismatch")
  if (!is.list(ledger_object) || !inherits(ledger_object, "ucl_forecast_ledger")) failures <- c(failures, "ledger_object_contract_missing")
  if (is.list(ledger_object)) {
    if (!identical(tolower(as.character(ledger_object$graph_sha256 %||% "")), tolower(graph_hash))) failures <- c(failures, "ledger_graph_identity_mismatch")
    if (!identical(tolower(as.character(ledger_object$table_sha256 %||% "")), tolower(ledger_hash))) failures <- c(failures, "ledger_table_identity_mismatch")
    if (!identical(as.character(ledger_object$source_bundle_id %||% ""), as.character(metadata$source_bundle_id %||% ""))) failures <- c(failures, "ledger_source_identity_mismatch")
    if (!identical(as.character(ledger_object$state_cutoff_utc %||% ""), as.character(metadata$information_cutoff_utc %||% ""))) failures <- c(failures, "ledger_cutoff_identity_mismatch")
    for (field in c("model_release_id", "model_sha256", "calibrator_sha256")) {
      if (!identical(tolower(as.character(ledger_object[[field]] %||% "")), tolower(as.character(metadata[[field]] %||% "")))) failures <- c(failures, paste0("ledger_", field, "_mismatch"))
    }
  }
  component_hashes <- simulation$component_hashes %||% metadata$component_hashes
  if (!is.list(component_hashes)) return(unique(c(failures, "simulation_component_hashes_missing")))
  observed_stage_hash <- .ucl_out_sim_table_hash(simulation$stage_events, "stage_event_id", "ucl20-stage-events-v1")
  observed_progression_hash <- .ucl_out_sim_table_hash(simulation$progression_probabilities, "club_id", "ucl20-progression-v1")
  if (!identical(tolower(as.character(component_hashes$stage_events_sha256 %||% "")), tolower(as.character(observed_stage_hash)))) failures <- c(failures, "stage_component_hash_mismatch")
  if (!identical(tolower(as.character(component_hashes$knockout_paths_sha256 %||% "")), tolower(as.character(observed_stage_hash)))) failures <- c(failures, "path_component_hash_mismatch")
  if (!identical(tolower(as.character(component_hashes$progression_sha256 %||% "")), tolower(as.character(observed_progression_hash)))) failures <- c(failures, "progression_component_hash_mismatch")
  if (!is.null(metadata$draw_artifact_sha256) && length(metadata$draw_artifact_sha256) && !is.na(metadata$draw_artifact_sha256[[1L]]) && nzchar(as.character(metadata$draw_artifact_sha256[[1L]]))) {
    path_hashes <- unique(as.character(simulation$stage_events$draw_artifact_sha256 %||% character()))
    path_hashes <- path_hashes[!is.na(path_hashes) & nzchar(path_hashes)]
    if (!length(path_hashes) || any(tolower(path_hashes) != tolower(as.character(metadata$draw_artifact_sha256[[1L]])))) failures <- c(failures, "draw_component_hash_mismatch")
  }
  unique(failures)
}

#' Validate a deterministic candidate without writing production artifacts.
ucl_validate_outcome_candidate <- function(candidate, rules = NULL, information_cutoff_utc = NULL) {
  graph <- .ucl_out_graph(candidate)
  state <- .ucl_out_state(candidate)
  ledger_object <- if (is.list(candidate$ledger) && is.data.frame(candidate$ledger$ledger)) candidate$ledger else NULL
  ledger <- .ucl_out_ledger(candidate)
  simulation <- .ucl_out_simulation(candidate)
  rules <- rules %||% if (exists(".ucl_rule_contract", mode = "function")) .ucl_rule_contract() else NULL
  if (is.null(rules) || is.null(graph) || is.null(state) || is.null(ledger) || is.null(simulation)) {
    return(list(valid = FALSE, status = "production_blocked", failures = "candidate_components_missing", warnings = character(), artifacts = list(), production_eligible = FALSE, fixture_authority = TRUE))
  }
  topology <- .ucl_out_topology(graph, rules)
  schedule <- .ucl_out_schedule(graph)
  trace <- .ucl_out_trace(state, rules)
  standings <- .ucl_out_standings(state, rules)
  rankings <- .ucl_out_rankings(state, rules)
  paths <- .ucl_out_paths(simulation, rules)
  progression <- .ucl_out_progression(simulation, rules)
  forecasts <- .ucl_out_ledger_table(ledger)
  cutoff_value <- information_cutoff_utc
  if (is.null(cutoff_value) && is.list(simulation) && is.list(simulation$metadata)) cutoff_value <- simulation$metadata$information_cutoff_utc
  cutoff <- .ucl_out_validate_cutoff(cutoff_value)
  simulation_for_metadata <- simulation
  if (is.list(simulation_for_metadata)) {
    simulation_for_metadata$metadata <- simulation_for_metadata$metadata %||% list()
    if (isTRUE(cutoff$valid)) simulation_for_metadata$metadata$information_cutoff_utc <- cutoff$value
  }
  metadata <- .ucl_out_metadata(simulation_for_metadata, ledger, graph, rules)
  fixture_authority <- isTRUE(graph$fixture_authority) || identical(as.character(graph$authority_mode), "fixture") || isTRUE(candidate$fixture_authority)
  authority <- if (is.list(candidate$ledger)) candidate$ledger$authority else NULL
  parent <- .ucl_out_parent_reason(authority, candidate)
  expected_artifacts <- list(competition_topology = topology, league_schedule = schedule, tie_break_trace = trace, projected_standings = standings, projected_rankings = rankings, knockout_paths = paths, progression_probabilities = progression, fixture_forecast_ledger = forecasts, simulation_metadata = metadata)
  expected_artifacts$outcomes_manifest <- .ucl_out_build_manifest(expected_artifacts, graph, simulation_for_metadata, metadata, fixture_authority = fixture_authority)
  supplied <- is.list(candidate$artifacts) && length(candidate$artifacts)
  failures <- character()
  if (!isTRUE(cutoff$valid)) failures <- c(failures, cutoff$reason)
  lineage_check <- .ucl_out_validate_ledger_lineage(ledger)
  if (!isTRUE(lineage_check$valid)) failures <- c(failures, lineage_check$errors)
  component_binding <- .ucl_out_validate_component_binding(candidate, graph, state, ledger_object, ledger, simulation)
  failures <- c(failures, component_binding)
  if (supplied) {
    artifacts <- candidate$artifacts
    if (!identical(sort(names(artifacts), method = "radix"), sort(names(expected_artifacts), method = "radix"))) {
      failures <- c(failures, "artifact_inventory")
    } else {
      # A caller may replay a candidate, but cannot replace its freshly
      # computed bytes.  Compare every supplied table to the expected table
      # before validating the supplied manifest/self-hash.
      for (name in names(expected_artifacts)) {
        supplied_hash <- if (is.data.frame(artifacts[[name]])) .ucl_out_artifact_hash(artifacts[[name]]) else NA_character_
        expected_hash <- .ucl_out_artifact_hash(expected_artifacts[[name]])
        if (!identical(supplied_hash, expected_hash)) failures <- c(failures, paste0("artifact_mismatch:", name))
      }
    }
  } else {
    artifacts <- expected_artifacts
  }
  table_check <- .ucl_out_validate_artifact_tables(artifacts, graph = graph, rules = rules, simulation = simulation)
  if (!isTRUE(table_check$valid)) failures <- c(failures, table_check$errors)
  if (nrow(topology) != 36L || nrow(schedule) != 144L) failures <- c(failures, "topology_or_schedule_cardinality")
  if (nrow(forecasts) != 144L) failures <- c(failures, "forecast_ledger_cardinality")
  progression_check <- .ucl_out_validate_progression(progression, graph, simulation)
  reconciliation <- progression_check$reconciliation
  if (!isTRUE(progression_check$valid)) failures <- c(failures, progression_check$errors)
  paths_for_events <- paths
  draw_unresolved <- nrow(paths_for_events) > 0L && any(as.character(paths_for_events$path_status) %in% c("unresolved", "pre_draw_legal"))
  draw_unresolved <- draw_unresolved || identical(as.character(simulation$status), "unresolved_draw_procedure")
  stage_events <- if (is.list(simulation) && is.data.frame(simulation$stage_events)) simulation$stage_events else data.frame()
  stage_check <- .ucl_out_validate_stage_events(stage_events, rules)
  if (!isTRUE(stage_check$valid)) failures <- c(failures, stage_check$errors)
  status <- if (length(failures)) "production_blocked" else if (draw_unresolved) "unresolved_draw_procedure" else if (fixture_authority) "mechanics_complete" else parent$status
  if (!fixture_authority && status == "mechanics_complete") status <- parent$status
  artifact_hashes <- vapply(artifacts, .ucl_out_canonical_hash, character(1))
  unresolved_reason <- if (draw_unresolved) unique(as.character(paths_for_events$unresolved_reason)) else character()
  unresolved_reason <- unresolved_reason[!is.na(unresolved_reason) & nzchar(unresolved_reason)]
  if (!length(unresolved_reason) && draw_unresolved) unresolved_reason <- "missing_edition_draw_procedure"
  result <- list(valid = !length(failures), status = status, failures = unique(failures), warnings = character(), skips = character(), unexpected_failures = character(), mechanics_complete = !length(failures), production_eligible = FALSE, fixture_authority = fixture_authority, authority_mode = if (fixture_authority) "fixture" else parent$status, original_parent_reason = parent$original_parent_reason, human_needed = identical(parent$status, "production_human_needed"), human_needed_reason = parent$human_needed_reason, production_blocked_reason = if (identical(status, "production_blocked")) parent$production_blocked_reason else NA_character_, normalization_error = parent$normalization_error, unresolved = unresolved_reason, selector_changed = FALSE, incumbent_changed = FALSE, edition_id = graph$edition_id, source_bundle_id = graph$source_bundle_id, ruleset_version = rules$ruleset_version, ruleset_sha256 = rules$ruleset_sha256, model_release_id = metadata$model_release_id, model_sha256 = metadata$model_sha256, calibrator_sha256 = metadata$calibrator_sha256, draw_policy_id = metadata$draw_policy_id, draw_artifact_id = metadata$draw_artifact_id, draw_artifact_sha256 = metadata$draw_artifact_sha256, information_cutoff_utc = metadata$information_cutoff_utc, simulation_run_id = simulation$run_id %||% NA_character_, simulation_count = metadata$simulation_count, seed = metadata$seed, artifact_hashes = artifact_hashes, artifacts = artifacts, stage_events = stage_events, stage_reconciliation = stage_check$aggregate, progression_reconciliation = reconciliation)
  class(result) <- c("ucl_outcome_candidate", "list")
  result
}

#' Build a deterministic manifest row for a validated candidate or artifact.
ucl_outcomes_manifest <- function(candidate, artifact_path = NA_character_, parent_id = NA_character_) {
  validated <- if (is.list(candidate) && isTRUE(candidate$valid) && is.list(candidate$artifacts) && "outcomes_manifest" %in% names(candidate$artifacts)) candidate else ucl_validate_outcome_candidate(candidate)
  if (is.list(validated$artifacts) && is.data.frame(validated$artifacts$outcomes_manifest) && nrow(validated$artifacts$outcomes_manifest) == length(.ucl_out_inventory)) return(validated$artifacts$outcomes_manifest)
  data.frame()
}

#' Parse the fixed UCL CLI surface without accepting path/authority overrides.
ucl20_parse_args <- function(args = commandArgs(trailingOnly = TRUE)) {
  result <- list(edition_id = "ucl_2026_27", simulations = 1000L, seed = 20260921L,
                 information_cutoff_utc = "2026-09-21T00:00:00Z",
                 dry_run = TRUE, replay_check = FALSE, write = FALSE, help = FALSE,
                 mode = "dry-run")
  saw_dry_run <- FALSE
  saw_write <- FALSE
  forbidden_roots <- c("fixture-root", "output-root", "selector-path", "trusted-root",
                       "trusted-release-root", "production-root", "national-root", "source-root")
  value_options <- c("edition-id", "simulations", "seed", "information-cutoff-utc")
  parse_integer <- function(value, option, minimum, maximum) {
    if (!length(value) || !grepl("^-?[0-9]+$", as.character(value))) stop(paste0(option, " must be an integer"), call. = FALSE)
    parsed <- suppressWarnings(as.integer(value))
    if (is.na(parsed) || parsed < minimum || parsed > maximum) stop(paste0(option, " is outside the allowed range"), call. = FALSE)
    parsed
  }
  arguments <- as.character(args)
  index <- 1L
  while (index <= length(arguments)) {
    arg <- arguments[[index]]
    if (arg %in% c("--help", "-h")) { result$help <- TRUE; index <- index + 1L; next }
    if (identical(arg, "--dry-run")) { result$dry_run <- TRUE; saw_dry_run <- TRUE; index <- index + 1L; next }
    if (identical(arg, "--replay-check")) { result$replay_check <- TRUE; index <- index + 1L; next }
    if (identical(arg, "--write")) { result$write <- TRUE; result$dry_run <- FALSE; saw_write <- TRUE; index <- index + 1L; next }
    if (!grepl("^--[A-Za-z0-9_-]+(?:=.*)?$", arg, perl = TRUE)) stop(paste0("Unknown UCL argument: ", arg), call. = FALSE)
    parts <- strsplit(sub("^--", "", arg), "=", fixed = TRUE)[[1L]]
    key <- parts[[1L]]
    if (key %in% forbidden_roots) stop("UCL CLI does not accept authority or fixture path overrides", call. = FALSE)
    if (!key %in% value_options) stop(paste0("Unknown UCL argument: --", key), call. = FALSE)
    if (length(parts) == 1L) {
      if (index == length(arguments)) stop(paste0("Option --", key, " requires one value"), call. = FALSE)
      index <- index + 1L
      value <- arguments[[index]]
    } else value <- paste(parts[-1L], collapse = "=")
    if (identical(key, "edition-id")) result$edition_id <- value
    else if (identical(key, "simulations")) result$simulations <- parse_integer(value, "--simulations", 1L, 100000L)
    else if (identical(key, "seed")) result$seed <- parse_integer(value, "--seed", 0L, .Machine$integer.max)
    else if (identical(key, "information-cutoff-utc")) result$information_cutoff_utc <- value
    else stop(paste0("Unknown UCL argument: --", key), call. = FALSE)
    index <- index + 1L
  }
  if (isTRUE(result$help)) return(result)
  if (!identical(result$edition_id, "ucl_2026_27")) stop("UCL CLI edition is not supported", call. = FALSE)
  if (length(result$simulations) != 1L || is.na(result$simulations) || result$simulations < 1L || result$simulations > 100000L) stop("UCL simulations must be between 1 and 100000", call. = FALSE)
  if (length(result$seed) != 1L || is.na(result$seed) || result$seed < 0L) stop("UCL seed must be a non-negative integer", call. = FALSE)
  cutoff <- .ucl_out_validate_cutoff(result$information_cutoff_utc)
  if (!isTRUE(cutoff$valid)) stop(cutoff$reason, call. = FALSE)
  if (isTRUE(saw_write) && isTRUE(saw_dry_run)) stop("--write cannot be combined with --dry-run", call. = FALSE)
  if (isTRUE(result$write) && isTRUE(result$replay_check)) stop("--write cannot be combined with --replay-check", call. = FALSE)
  result$information_cutoff_utc <- cutoff$value
  result$mode <- if (isTRUE(result$write)) "write" else if (isTRUE(result$replay_check)) "replay" else "dry-run"
  result
}

#' Return the machine-readable Phase 20 result contract.
phase20_result_contract <- function(status = "mechanics_complete", exit_code = 0L, mechanics_complete = NULL, production_eligible = FALSE, human_needed = NULL, human_needed_reason = NA_character_, original_parent_reason = NA_character_, production_blocked_reason = NA_character_, normalization_error = FALSE, unresolved = character(), failures = character(), warnings = character(), skips = character(), unexpected_failures = character(), mapped_threat_ids = character(), selector_changed = FALSE, incumbent_changed = FALSE, artifact_hashes = character(), artifacts = NULL, information_cutoff_utc = NA_character_, ...) {
  allowed <- c("mechanics_complete", "production_human_needed", "production_blocked", "unresolved_draw_procedure", "unexpected_failure")
  if (!status %in% allowed) { failures <- c(failures, "invalid_status"); status <- "unexpected_failure"; exit_code <- 1L }
  failures <- unique(as.character(failures[!is.na(failures) & nzchar(as.character(failures))]))
  unexpected_failures <- unique(as.character(unexpected_failures[!is.na(unexpected_failures) & nzchar(as.character(unexpected_failures))]))
  if (identical(status, "unexpected_failure")) {
    if (length(failures) + length(unexpected_failures) == 0L) unexpected_failures <- "unexpected_failure_without_reason"
    exit_code <- max(1L, as.integer(exit_code %||% 0L))
    mechanics_complete <- FALSE
  }
  if (is.null(mechanics_complete)) mechanics_complete <- status %in% c("mechanics_complete", "production_human_needed", "unresolved_draw_procedure") && !length(failures)
  if (is.null(human_needed)) human_needed <- identical(status, "production_human_needed")
  supplied_hashes <- as.character(artifact_hashes %||% character())
  names(supplied_hashes) <- names(artifact_hashes %||% supplied_hashes)
  list(status = status, exit_code = as.integer(exit_code), mechanics_complete = isTRUE(mechanics_complete),
       production_eligible = FALSE, human_needed = isTRUE(human_needed),
       human_needed_reason = as.character(human_needed_reason %||% NA_character_),
       original_parent_reason = as.character(original_parent_reason %||% NA_character_),
       production_blocked_reason = as.character(production_blocked_reason %||% NA_character_),
       normalization_error = isTRUE(normalization_error), unresolved = as.character(unresolved),
       failures = failures, warnings = as.character(warnings), skips = as.character(skips),
       unexpected_failures = unexpected_failures, mapped_threat_ids = as.character(mapped_threat_ids),
       selector_changed = FALSE, incumbent_changed = FALSE,
       artifact_hashes = supplied_hashes, artifacts = artifacts,
       information_cutoff_utc = as.character(information_cutoff_utc %||% NA_character_))
}

#' Verify the zero-failure typed result contract.
phase20_verify_contracts <- function(result) {
  if (!is.list(result)) return(FALSE)
  allowed <- c("mechanics_complete", "production_human_needed", "production_blocked", "unresolved_draw_procedure", "unexpected_failure")
  if (!identical(as.character(result$status), result$status) || !result$status %in% allowed) return(FALSE)
  if (identical(result$status, "unexpected_failure")) {
    if (identical(as.integer(result$exit_code), 0L) || (!length(result$failures) && !length(result$unexpected_failures))) return(FALSE)
  } else {
    if (!identical(as.integer(result$exit_code), 0L)) return(FALSE)
    if (length(result$failures) || length(result$warnings) || length(result$skips) || length(result$unexpected_failures)) return(FALSE)
  }
  if (isTRUE(result$production_eligible) || isTRUE(result$selector_changed) || isTRUE(result$incumbent_changed)) return(FALSE)
  if (identical(result$status, "production_human_needed") && !as.character(result$human_needed_reason) %in% c("phase18_authority_missing", "phase19_cr01_cr05_repair_pending", "phase19_selector_not_accepted")) return(FALSE)
  if (identical(result$status, "production_blocked") && !isTRUE(result$normalization_error) && !nzchar(as.character(result$production_blocked_reason))) return(FALSE)
  raw_hashes <- result$artifact_hashes %||% character()
  hashes <- as.character(raw_hashes)
  names(hashes) <- names(raw_hashes)
  if (length(hashes)) {
    if (is.null(names(hashes)) || any(!nzchar(names(hashes))) || anyNA(hashes) || any(!grepl("^[0-9a-fA-F]{64}$", hashes))) return(FALSE)
    if (is.list(result$artifacts) && length(result$artifacts)) {
      actual <- vapply(result$artifacts, .ucl_out_artifact_hash, character(1))
      if (!identical(names(hashes), names(actual)) || !identical(tolower(hashes), tolower(actual))) return(FALSE)
    }
  }
  if (result$status %in% c("mechanics_complete", "unresolved_draw_procedure") && !length(hashes)) return(FALSE)
  TRUE
}

.ucl_out_project_root <- function() {
  root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  repeat {
    if (file.exists(file.path(root, "R", "competition", "uefa_champions_league_state.R"))) return(root)
    parent <- dirname(root)
    if (identical(parent, root)) return(normalizePath(getwd(), winslash = "/", mustWork = TRUE))
    root <- parent
  }
}

.ucl_out_blocked_result <- function(reason, original_parent_reason = NA_character_,
                                    human_needed = FALSE, human_needed_reason = NA_character_,
                                    normalization_error = FALSE, mapped_threat_ids = character(),
                                    information_cutoff_utc = NA_character_) {
  phase20_result_contract(
    status = if (isTRUE(human_needed)) "production_human_needed" else "production_blocked",
    mechanics_complete = FALSE, human_needed = human_needed,
    human_needed_reason = human_needed_reason,
    original_parent_reason = original_parent_reason,
    production_blocked_reason = if (isTRUE(human_needed)) NA_character_ else as.character(reason),
    normalization_error = normalization_error, mapped_threat_ids = mapped_threat_ids,
    information_cutoff_utc = information_cutoff_utc
  )
}

.ucl_out_production_authority <- function() {
  root <- .ucl_out_project_root()
  accepted_root <- file.path(root, "data", "competition", "accepted")
  registry_root <- file.path(root, "data", "competition", "registries")
  reader <- if (exists("phase18_read_ucl_refresh_current", mode = "function")) get("phase18_read_ucl_refresh_current") else NULL
  if (!is.function(reader)) return(list(error = "no_accepted_current_ucl"))
  current <- tryCatch(reader(accepted_root = accepted_root, registry_root = registry_root),
                      error = function(error) list(error = "no_accepted_current_ucl", message = conditionMessage(error)))
  if (is.null(current) || !is.null(current$error) ||
      !identical(as.character(current$pointer$accepted_status %||% ""), "accepted") ||
      !is.list(current$accepted) || is.null(current$accepted$bundle)) {
    return(list(error = if (is.list(current) && !is.null(current$error)) as.character(current$error[[1L]]) else "no_accepted_current_ucl"))
  }
  accepted <- current$accepted
  rules <- tryCatch(if (exists(".ucl_rule_contract", mode = "function")) .ucl_rule_contract() else NULL,
                    error = function(error) error)
  if (inherits(rules, "error") || is.null(rules)) return(list(error = "rules_evidence_invalid"))
  tables <- accepted$tables %||% accepted$artifacts
  if (!is.list(tables)) return(list(error = "accepted_source_schema_invalid"))
  clubs <- tables$clubs %||% tables$teams
  fixtures <- tables$matches %||% tables$fixtures
  if (!is.data.frame(clubs) || !is.data.frame(fixtures)) return(list(error = "accepted_source_schema_invalid"))
  graph <- list(
    edition_id = as.character(accepted$bundle$edition_id[[1L]]),
    source_bundle_id = as.character(accepted$bundle$bundle_id[[1L]]),
    authority_mode = "production", fixture_authority = FALSE,
    production_eligible = TRUE, selector_path = NULL, production_root = NULL,
    clubs = clubs, fixtures = fixtures
  )
  validation <- tryCatch(ucl_validate_schedule(graph, rules = rules, require_authority = TRUE),
                         error = function(error) list(status = "blocked", reason_code = "accepted_source_schema_invalid"))
  if (!identical(validation$status, "ready")) return(list(error = validation$reason_code %||% "accepted_source_schema_invalid"))
  resolver <- if (exists("phase19_resolve_production_club_release", mode = "function")) get("phase19_resolve_production_club_release") else NULL
  if (!is.function(resolver)) return(list(error = "no_accepted_club_history"))
  resolved <- tryCatch(list(value = resolver()), error = function(error) {
    reason <- if (!is.null(error$reason_code)) as.character(error$reason_code[[1L]]) else "phase19_selector_not_accepted"
    if (reason %in% c("release_root_invalid", "release_artifact_missing", "release_dependency_missing", "release_preflight_stale")) reason <- "no_accepted_club_history"
    list(error = reason, message = conditionMessage(error))
  })
  if (!is.null(resolved$error)) return(list(error = as.character(resolved$error[[1L]])))
  release <- resolved$value
  release_rows <- if (is.list(release) && is.data.frame(release$forecast_rows)) release$forecast_rows else if (is.list(release) && is.data.frame(release$forecasts)) release$forecasts else NULL
  if (is.null(release_rows) || !nrow(release_rows)) return(list(error = "phase19_forecast_rows_missing"))
  raw_draw <- accepted$draw_artifact %||%
    if (is.list(accepted$artifacts)) accepted$artifacts$draw_artifact else NULL
  trusted_draw <- if (exists(".ucl_resolve_trusted_draw_artifact", mode = "function")) {
    tryCatch(.ucl_resolve_trusted_draw_artifact(raw_draw, rules = rules, source_bundle_id = validation$graph$source_bundle_id), error = function(error) NULL)
  } else NULL
  if (!is.list(trusted_draw) || !identical(as.character(trusted_draw$status %||% "accepted"), "accepted") || !inherits(trusted_draw, "ucl_trusted_draw_artifact")) trusted_draw <- NULL
  list(graph = validation$graph, rules = rules, release = release, current = current, draw_artifact = trusted_draw)
}

.ucl_out_build_pipeline <- function(graph, release, rules, simulations, seed, draw_artifact,
                                    information_cutoff_utc, write = FALSE, output_root = NULL,
                                    draw_authority_mode = "fixture") {
  cutoff <- .ucl_out_validate_cutoff(information_cutoff_utc)
  if (!isTRUE(cutoff$valid)) return(.ucl_out_blocked_result(cutoff$reason, mapped_threat_ids = "T20-03-01", information_cutoff_utc = cutoff$value))
  state <- tryCatch(ucl_build_state(graph, rules = rules, state_cutoff_utc = cutoff$value),
                    error = function(error) list(status = "blocked", reason_code = "state_build_failed", message = conditionMessage(error)))
  if (!identical(state$status, "ready")) return(.ucl_out_blocked_result(state$reason_code %||% "state_blocked", mapped_threat_ids = "T20-01-01", information_cutoff_utc = cutoff$value))
  state_release <- .ucl_out_release_for_state(release)
  ledger <- tryCatch(ucl_build_forecast_ledger(state, release = state_release, state_cutoff_utc = cutoff$value),
                     error = function(error) list(status = "blocked", reason_code = "ledger_build_failed", message = conditionMessage(error)))
  if (!inherits(ledger, "ucl_forecast_ledger") || !is.data.frame(ledger$ledger)) return(.ucl_out_blocked_result(ledger$reason_code %||% "ledger_contract_invalid", mapped_threat_ids = "T20-03-01", information_cutoff_utc = cutoff$value))
  ledger <- .ucl_out_prepare_simulation_ledger(ledger, graph = state$graph, release = release, cutoff = cutoff$value)
  required_ledger_fields <- c("graph_sha256", "source_bundle_id", "state_cutoff_utc", "table_sha256", "model_release_id", "model_sha256", "calibrator_sha256")
  if (any(!vapply(required_ledger_fields, function(field) length(ledger[[field]]) == 1L && !is.na(ledger[[field]]) && nzchar(as.character(ledger[[field]])), logical(1)))) {
    return(.ucl_out_blocked_result("ledger_metadata_incomplete", mapped_threat_ids = "T20-03-01", information_cutoff_utc = cutoff$value))
  }
  simulation <- tryCatch(ucl_run_simulation(state, ledger = ledger, simulations = simulations, seed = seed,
                                             rules = rules, draw_artifact = draw_artifact,
                                             information_cutoff_utc = cutoff$value,
                                             draw_authority_mode = draw_authority_mode),
                         error = function(error) list(status = "blocked", reason = "simulation_failed", message = conditionMessage(error)))
  if (identical(as.character(simulation$status), "blocked")) return(.ucl_out_blocked_result(simulation$reason %||% "simulation_blocked", mapped_threat_ids = "T20-03-03", information_cutoff_utc = cutoff$value))
  candidate <- tryCatch(ucl_validate_outcome_candidate(list(state = state, ledger = ledger, simulation = simulation),
                                                        rules = rules, information_cutoff_utc = cutoff$value),
                        error = function(error) list(valid = FALSE, failures = conditionMessage(error), status = "production_blocked"))
  if (!isTRUE(candidate$valid)) {
    reason <- paste(unique(as.character(candidate$failures %||% "outcome_validation_failed")), collapse = ";")
    return(.ucl_out_blocked_result(reason, mapped_threat_ids = c("T20-04-01", "T20-04-02"), information_cutoff_utc = cutoff$value))
  }
  if (isTRUE(write)) {
    if (is.null(output_root)) return(.ucl_out_blocked_result("production_writer_not_authorized", mapped_threat_ids = "T20-05-01", information_cutoff_utc = cutoff$value))
    tryCatch(ucl_write_outcome_candidate(candidate, output_root = output_root),
             error = function(error) stop(error))
  }
  phase20_result_contract(
    status = candidate$status, mechanics_complete = candidate$mechanics_complete,
    production_eligible = FALSE, human_needed = FALSE,
    original_parent_reason = candidate$original_parent_reason,
    production_blocked_reason = candidate$production_blocked_reason,
    normalization_error = candidate$normalization_error, unresolved = candidate$unresolved,
    warnings = candidate$warnings, skips = candidate$skips,
    artifact_hashes = candidate$artifact_hashes, artifacts = candidate$artifacts,
    information_cutoff_utc = cutoff$value,
    mapped_threat_ids = c("T20-01-01", "T20-03-01", "T20-03-03", "T20-04-01", "T20-04-02")
  )
}

#' Build the fixed production outcome contract or a mechanics-only fixture candidate.
ucl20_build_outcomes <- function(graph = NULL, release = NULL, simulations = 1L, seed = 20260921L, draw_artifact = NULL, information_cutoff_utc = NULL, write = FALSE, output_root = NULL) {
  if (is.null(graph)) {
    authority <- .ucl_out_production_authority()
    if (!is.null(authority$error)) {
      parent <- .ucl_out_parent_reason(list(original_parent_reason = authority$error))
      if (identical(authority$error, "phase19_forecast_rows_missing")) {
        return(.ucl_out_blocked_result(authority$error, normalization_error = FALSE, mapped_threat_ids = "T20-05-02", information_cutoff_utc = information_cutoff_utc %||% NA_character_))
      }
      return(.ucl_out_blocked_result(parent$production_blocked_reason %||% authority$error,
                                     original_parent_reason = parent$original_parent_reason,
                                     human_needed = identical(parent$status, "production_human_needed"),
                                     human_needed_reason = parent$human_needed_reason,
                                     normalization_error = parent$normalization_error,
                                     mapped_threat_ids = c("T20-01-02", "T20-05-02"),
                                     information_cutoff_utc = information_cutoff_utc %||% NA_character_))
    }
    cutoff <- information_cutoff_utc
    if (is.null(cutoff)) return(.ucl_out_blocked_result("information_cutoff_missing", mapped_threat_ids = "T20-03-01"))
    return(.ucl_out_build_pipeline(authority$graph, authority$release, authority$rules, simulations, seed,
                                   authority$draw_artifact, cutoff,
                                   write = write, output_root = output_root,
                                   draw_authority_mode = "production"))
  }
  fixture <- isTRUE(graph$fixture_authority) && identical(as.character(graph$authority_mode %||% ""), "fixture") && !isTRUE(graph$production_eligible)
  if (!fixture) return(.ucl_out_blocked_result("graph_injection_requires_fixture_authority", mapped_threat_ids = "T20-01-01", information_cutoff_utc = information_cutoff_utc %||% NA_character_))
  if (is.null(release) || !isTRUE(release$fixture_authority) || isTRUE(release$production_eligible)) {
    return(.ucl_out_blocked_result("fixture_release_missing_or_promotable", mapped_threat_ids = "T20-03-01", information_cutoff_utc = information_cutoff_utc %||% NA_character_))
  }
  cutoff <- information_cutoff_utc %||% "2026-09-21T00:00:00Z"
  rules <- if (exists(".ucl_rule_contract", mode = "function")) .ucl_rule_contract() else NULL
  if (is.null(rules)) return(.ucl_out_blocked_result("rules_evidence_invalid", mapped_threat_ids = "T20-02-01", information_cutoff_utc = information_cutoff_utc %||% "2026-09-21T00:00:00Z"))
  .ucl_out_build_pipeline(graph, release, rules, simulations, seed, draw_artifact, cutoff,
                          write = write, output_root = output_root,
                          draw_authority_mode = "fixture")
}

#' Write only a validated sibling candidate under a process-temporary root.
ucl_write_outcome_candidate <- function(candidate, output_root = NULL, overwrite = FALSE) {
  if (!is.list(candidate) || !isTRUE(candidate$valid) || !is.list(candidate$artifacts)) stop("UCL outcome candidate is not validated", call. = FALSE)
  check <- .ucl_out_validate_artifact_tables(candidate$artifacts)
  if (!isTRUE(check$valid)) stop(paste0("UCL outcome candidate artifact validation failed: ", paste(check$errors, collapse = ",")), call. = FALSE)
  if (is.null(output_root)) stop("UCL candidate output requires an explicit process-temporary root", call. = FALSE)
  output_root <- gsub("/+", "/", normalizePath(output_root, winslash = "/", mustWork = FALSE))
  temporary <- normalizePath(tempdir(), winslash = "/", mustWork = TRUE)
  temporary_aliases <- unique(c(temporary, sub("^/private", "", temporary), paste0("/private", temporary)))
  allowed <- any(vapply(temporary_aliases, function(prefix) identical(output_root, prefix) || startsWith(output_root, paste0(prefix, "/")), logical(1)))
  if (!allowed) stop("UCL outcome writes are limited to process-temporary roots", call. = FALSE)
  output_root <- file.path(normalizePath(dirname(output_root), winslash = "/", mustWork = TRUE), basename(output_root))
  if (dir.exists(output_root) && !isTRUE(overwrite) && length(list.files(output_root, all.files = TRUE, no.. = TRUE))) stop("UCL candidate output root is not empty", call. = FALSE)
  parent_root <- normalizePath(dirname(output_root), winslash = "/", mustWork = TRUE)
  staging <- tempfile(".ucl-outcomes-staging-", tmpdir = parent_root)
  dir.create(staging, recursive = TRUE, showWarnings = FALSE)
  on.exit(if (dir.exists(staging)) unlink(staging, recursive = TRUE, force = TRUE), add = TRUE)
  paths <- character()
  for (name in .ucl_out_inventory) {
    path <- file.path(staging, paste0(name, ".csv"))
    utils::write.csv(candidate$artifacts[[name]], path, row.names = FALSE, na = "", quote = TRUE)
    paths[[name]] <- file.path(output_root, paste0(name, ".csv"))
  }
  written_names <- sort(list.files(staging, pattern = "\\.csv$"), method = "radix")
  if (!identical(written_names, sort(paste0(.ucl_out_inventory, ".csv"), method = "radix"))) stop("UCL candidate staging inventory mismatch", call. = FALSE)
  readback <- lapply(.ucl_out_inventory, function(name) {
    utils::read.csv(
      file.path(staging, paste0(name, ".csv")), stringsAsFactors = FALSE,
      check.names = FALSE, na.strings = "",
      colClasses = .ucl_out_csv_col_classes(candidate$artifacts[[name]])
    )
  })
  names(readback) <- .ucl_out_inventory
  readback_check <- .ucl_out_validate_artifact_tables(readback)
  if (!isTRUE(readback_check$valid)) stop(paste0("UCL candidate read-back validation failed: ", paste(readback_check$errors, collapse = ",")), call. = FALSE)
  expected_hashes <- vapply(candidate$artifacts, .ucl_out_artifact_hash, character(1))
  readback_hashes <- vapply(readback, .ucl_out_artifact_hash, character(1))
  if (!identical(names(expected_hashes), names(readback_hashes)) ||
      !identical(tolower(expected_hashes), tolower(readback_hashes))) {
    stop("UCL candidate read-back artifact hashes do not bind written bytes", call. = FALSE)
  }
  if (dir.exists(output_root) && length(list.files(output_root, all.files = TRUE, no.. = TRUE)) && isTRUE(overwrite)) {
    for (name in .ucl_out_inventory) {
      target <- file.path(output_root, paste0(name, ".csv"))
      if (file.exists(target) && !file.remove(target)) stop(paste0("Could not replace UCL incumbent artifact: ", name), call. = FALSE)
    }
    for (name in .ucl_out_inventory) if (!file.rename(file.path(staging, paste0(name, ".csv")), file.path(output_root, paste0(name, ".csv")))) stop(paste0("Could not publish UCL candidate artifact: ", name), call. = FALSE)
  } else if (dir.exists(output_root)) {
    dir.create(output_root, recursive = TRUE, showWarnings = FALSE)
    for (name in .ucl_out_inventory) if (!file.rename(file.path(staging, paste0(name, ".csv")), file.path(output_root, paste0(name, ".csv")))) stop(paste0("Could not publish UCL candidate artifact: ", name), call. = FALSE)
  } else if (!file.rename(staging, output_root)) stop("Could not publish UCL candidate staging root", call. = FALSE)
  invisible(list(status = "written", output_root = output_root, paths = paths, manifest = candidate$artifacts$outcomes_manifest))
}
