#!/usr/bin/env Rscript

# Production entrypoint for the registered 2026/27 Nations League outcomes
# bundle.  All source and Phase 14 state inputs are read-only handoffs; this
# script only delegates simulation and publication to the Phase 15 contracts.

phase15_nl_cli_args <- commandArgs(trailingOnly = FALSE)
phase15_nl_script_arg <- phase15_nl_cli_args[grepl("^--file=", phase15_nl_cli_args)]
phase15_nl_script_path <- if (length(phase15_nl_script_arg) == 1L) {
  sub("^--file=", "", phase15_nl_script_arg[[1L]])
} else {
  "scripts/build_nations_league_outcomes.R"
}
phase15_nl_script_path <- normalizePath(phase15_nl_script_path, mustWork = FALSE)
phase15_nl_script_environment <- environment()
phase15_nl_project_root <- normalizePath(
  file.path(dirname(phase15_nl_script_path), ".."),
  mustWork = FALSE
)

phase15_nl_source_if_missing <- function(relative_path, symbol) {
  if (exists(symbol, envir = phase15_nl_script_environment, inherits = TRUE)) {
    return(invisible(FALSE))
  }
  dependency <- file.path(phase15_nl_project_root, relative_path)
  if (!file.exists(dependency)) {
    stop(sprintf("Required dependency is missing: %s", relative_path), call. = FALSE)
  }
  sys.source(dependency, envir = phase15_nl_script_environment)
  invisible(TRUE)
}

phase15_nl_source_file <- function(relative_path) {
  dependency <- file.path(phase15_nl_project_root, relative_path)
  if (!file.exists(dependency)) {
    stop(sprintf("Required dependency is missing: %s", relative_path), call. = FALSE)
  }
  sys.source(dependency, envir = phase15_nl_script_environment)
  invisible(TRUE)
}

phase15_nl_source_if_missing("R/competition/source_contracts.R", "phase13_source_required_resource_types")
phase15_nl_source_if_missing("R/competition/publication_hashes.R", "phase13_publication_write_csv")
phase15_nl_source_if_missing("R/competition/forecast_layer.R", "phase14_build_fixture_forecasts")
phase15_nl_source_file("R/competition/form.R")
phase15_nl_source_file("R/competition/match_state.R")
phase15_nl_source_if_missing("R/competition/state_bundle.R", "phase14_build_competition_state_candidate")
phase15_nl_source_if_missing("R/competition/uefa_nations_league_rules.R", "uefa_nl_2026_27_rules")
phase15_nl_source_if_missing("R/competition/uefa_nations_league_rule_inputs.R", "phase15_nl_read_rule_inputs")
phase15_nl_source_if_missing("R/competition/standings.R", "phase14_compute_standings")
phase15_nl_source_if_missing("R/competition/uefa_nations_league_simulation.R", "uefa_nl_run_simulation")
phase15_nl_source_if_missing("R/competition/uefa_nations_league_adapter.R", "phase14_uefa_nl_validate_response")
phase15_nl_source_if_missing("R/competition/uefa_nations_league_outcomes.R", "phase15_build_nl_outcomes_candidate")

phase15_nl_fail <- function(message) {
  stop(message, call. = FALSE)
}

phase15_nl_require_scalar <- function(value, option) {
  if (length(value) != 1L || is.na(value) || !nzchar(value)) {
    phase15_nl_fail(sprintf("Option %s requires one non-empty value.", option))
  }
  value
}

phase15_nl_parse_args <- function(args = commandArgs(trailingOnly = TRUE)) {
  options <- list(
    edition_id = NULL,
    simulations = 1000L,
    seed = 15017L,
    dry_run = FALSE,
    replay_check = FALSE,
    write = FALSE,
    help = FALSE,
    mode = "dry-run"
  )
  index <- 1L
  while (index <= length(args)) {
    argument <- args[[index]]
    if (identical(argument, "--help") || identical(argument, "-h")) {
      options$help <- TRUE
      index <- index + 1L
      next
    }
    if (argument %in% c("--dry-run", "--replay-check", "--write")) {
      field <- switch(
        argument,
        `--dry-run` = "dry_run",
        `--replay-check` = "replay_check",
        `--write` = "write"
      )
      options[[field]] <- TRUE
      index <- index + 1L
      next
    }
    if (grepl("^--(edition-id|simulations|seed)=", argument)) {
      parts <- strsplit(argument, "=", fixed = TRUE)[[1L]]
      option <- parts[[1L]]
      value <- paste(parts[-1L], collapse = "=")
    } else if (argument %in% c("--edition-id", "--simulations", "--seed")) {
      if (index == length(args)) {
        phase15_nl_fail(sprintf("Option %s requires one value.", argument))
      }
      option <- argument
      index <- index + 1L
      value <- args[[index]]
    } else {
      phase15_nl_fail(sprintf("Unsupported argument: %s", argument))
    }
    value <- phase15_nl_require_scalar(value, option)
    if (identical(option, "--edition-id")) {
      options$edition_id <- value
    } else if (identical(option, "--simulations")) {
      parsed <- suppressWarnings(as.integer(value))
      if (is.na(parsed) || parsed < 1L || !identical(as.character(parsed), value)) {
        phase15_nl_fail("--simulations must be a positive integer.")
      }
      options$simulations <- parsed
    } else if (identical(option, "--seed")) {
      parsed <- suppressWarnings(as.integer(value))
      if (is.na(parsed) || parsed < 0L || !identical(as.character(parsed), value)) {
        phase15_nl_fail("--seed must be a non-negative integer.")
      }
      options$seed <- parsed
    }
    index <- index + 1L
  }

  if (isTRUE(options$help)) {
    return(options)
  }
  if (is.null(options$edition_id)) {
    phase15_nl_fail("--edition-id is required.")
  }
  if (!identical(options$edition_id, phase15_nl_edition_id())) {
    phase15_nl_fail(sprintf(
      "Unsupported edition-id '%s'; only %s is registered.",
      options$edition_id,
      phase15_nl_edition_id()
    ))
  }
  if (isTRUE(options$write) && (isTRUE(options$dry_run) || isTRUE(options$replay_check))) {
    phase15_nl_fail("--write cannot be combined with --dry-run or --replay-check.")
  }
  options$mode <- if (isTRUE(options$write)) {
    "write"
  } else if (isTRUE(options$replay_check)) {
    "replay"
  } else {
    "dry-run"
  }
  options
}

phase15_nl_cli_usage <- function() {
  script_name <- file.path("scripts", basename(phase15_nl_script_path))
  paste(
    "Usage:",
    paste0("  Rscript --vanilla ", script_name),
    "--edition-id uefa_nations_league_2026_27 [options]",
    "",
    "Options:",
    "  --simulations N   Positive simulation count (default: 1000)",
    "  --seed N          Non-negative deterministic seed (default: 15017)",
    "  --dry-run         Validate and build in memory (default mode)",
    "  --replay-check    Validate normal, reversed, and repeated replays",
    "  --write           Atomically publish the registered nine-file bundle",
    "  --help            Show this help",
    sep = "\n"
  )
}

phase15_nl_hash_bytes <- function(bytes) {
  digest::digest(bytes, algo = "sha256", serialize = FALSE)
}

phase15_nl_read_raw_hash <- function(path) {
  phase15_nl_hash_bytes(readBin(path, what = "raw", n = file.info(path)$size))
}

phase15_nl_default_inputs <- function(
    edition_id = phase15_nl_edition_id(),
    project_root = phase15_nl_project_root
) {
  project_root <- normalizePath(project_root, mustWork = TRUE)
  if (!identical(edition_id, phase15_nl_edition_id())) {
    phase15_nl_fail(sprintf("Unsupported edition-id '%s'.", edition_id))
  }

  source <- phase15_nl_read_source_bundle(project_root = project_root, edition_id = edition_id)
  required_resources <- as.character(phase13_source_required_resource_types())
  if (!identical(required_resources, c("fixtures", "groups", "standings", "results", "status"))) {
    phase15_nl_fail("Phase 13 resource contract is not the registered five-resource contract.")
  }
  source_artifacts <- source$source_artifacts
  if (!is.data.frame(source_artifacts) || nrow(source_artifacts) != length(required_resources)) {
    phase15_nl_fail("The accepted source bundle does not contain exactly five resource artifacts.")
  }
  if (!identical(sort(as.character(source_artifacts$artifact_type)), sort(required_resources))) {
    phase15_nl_fail("The accepted source bundle resource types do not match the Phase 13 contract.")
  }

  raw_paths <- vapply(required_resources, function(resource_type) {
    row <- source_artifacts[source_artifacts$artifact_type == resource_type, , drop = FALSE]
    if (nrow(row) != 1L || is.na(row$relative_local_raw_path[[1L]])) {
      phase15_nl_fail(sprintf("Missing raw source lineage for resource '%s'.", resource_type))
    }
    path <- file.path(project_root, row$relative_local_raw_path[[1L]])
    if (!file.exists(path)) {
      phase15_nl_fail(sprintf("Raw source artifact is missing for resource '%s'.", resource_type))
    }
    path
  }, character(1L))
  names(raw_paths) <- required_resources
  raw_hashes <- vapply(raw_paths, phase15_nl_read_raw_hash, character(1L))

  fixture_payload <- jsonlite::fromJSON(
    paste(readLines(raw_paths[["fixtures"]], warn = FALSE, encoding = "UTF-8"), collapse = "\n"),
    simplifyVector = FALSE
  )
  phase14_uefa_nl_validate_response(fixture_payload)
  adapted <- phase14_uefa_nl_adapt_response(fixture_payload)
  if (!identical(names(adapted$resources), required_resources)) {
    phase15_nl_fail("The Phase 13 adapter returned an unexpected resource contract.")
  }

  stage_capture <- phase15_uefa_nl_read_stage_capture(project_root = project_root)
  state_bundle <- phase15_nl_read_phase14_state_bundle(
    project_root = project_root,
    edition_id = edition_id
  )
  topology_base <- uefa_nl_build_topology(
    groups = source$groups,
    fixtures = source$fixtures,
    project_root = project_root
  )
  rule_inputs <- phase15_nl_read_rule_inputs(
    project_root = project_root,
    teams = topology_base$teams
  )
  topology <- uefa_nl_build_topology(
    groups = source$groups,
    fixtures = source$fixtures,
    access_list = rule_inputs$access_list,
    discipline_points = rule_inputs$discipline_points,
    project_root = project_root
  )
  list(
    project_root = project_root,
    edition_id = edition_id,
    source = source,
    adapted_source = adapted,
    raw_paths = raw_paths,
    raw_hashes = raw_hashes,
    stage_capture = stage_capture,
    state_bundle = state_bundle,
    rule_inputs = rule_inputs,
    topology = topology,
    rules = uefa_nl_2026_27_rules()
  )
}

phase15_nl_forecast_handoff <- function(state_bundle) {
  forecasts <- as.data.frame(state_bundle$forecasts, stringsAsFactors = FALSE)
  canonical_matches <- as.data.frame(state_bundle$canonical_matches, stringsAsFactors = FALSE)
  required <- c("fixture_id", "home_team_id", "away_team_id")
  if (!all(c("fixture_id", "home_team_id", "away_team_id") %in% names(canonical_matches))) {
    phase15_nl_fail("Phase 14 canonical match state lacks simulator fixture team identifiers.")
  }
  if (!"fixture_id" %in% names(forecasts)) {
    phase15_nl_fail("Phase 14 forecasts lack fixture_id.")
  }
  if (!all(c("home_team_id", "away_team_id") %in% names(forecasts))) {
    match_index <- match(forecasts$fixture_id, canonical_matches$fixture_id)
    if (anyNA(match_index)) {
      phase15_nl_fail("Phase 14 forecasts contain fixture IDs absent from canonical match state.")
    }
    forecasts$home_team_id <- canonical_matches$home_team_id[match_index]
    forecasts$away_team_id <- canonical_matches$away_team_id[match_index]
  }
  if (anyNA(forecasts$home_team_id) || anyNA(forecasts$away_team_id)) {
    phase15_nl_fail("Simulator forecast handoff contains missing team identifiers.")
  }
  forecasts
}

phase15_nl_stage_capture_lineage <- function(stage_capture) {
  manifest <- stage_capture$manifest
  registry <- stage_capture$registry
  capture_id <- as.character(manifest$capture_id[[1L]])
  registry_row <- registry[registry$capture_id == capture_id, , drop = FALSE]
  if (nrow(registry_row) != 1L) {
    phase15_nl_fail(sprintf("Stage capture registry row is not unique for '%s'.", capture_id))
  }
  lineage_paths <- c(
    registry_path = as.character(stage_capture$paths$registry_relative_path),
    manifest_path = as.character(stage_capture$paths$manifest_relative_path),
    accepted_path = as.character(stage_capture$paths$capture_relative_path)
  )
  if (any(is.na(lineage_paths) | !nzchar(trimws(lineage_paths))) ||
      any(!file.exists(file.path(stage_capture$paths$project_root, lineage_paths)))) {
    phase15_nl_fail("Stage capture lineage paths must be non-empty registered files.")
  }
  lineage <- list(
    capture_id = capture_id,
    capture_status = as.character(manifest$capture_status[[1L]]),
    raw_sha256 = as.character(manifest$raw_sha256[[1L]]),
    capture_content_sha256 = as.character(manifest$capture_content_sha256[[1L]]),
    manifest_sha256 = as.character(manifest$manifest_sha256[[1L]]),
    registry_row_sha256 = as.character(registry_row$row_sha256[[1L]]),
    registry_path = lineage_paths[["registry_path"]],
    manifest_path = lineage_paths[["manifest_path"]],
    accepted_path = lineage_paths[["accepted_path"]]
  )
  lineage
}

phase15_nl_attach_stage_capture_lineage <- function(candidate, stage_capture) {
  lineage <- phase15_nl_stage_capture_lineage(stage_capture)
  candidate$parent_graph$stage_capture_capture_id <- lineage$capture_id
  candidate$parent_graph$stage_capture_registry <- list(
    path = lineage$registry_path,
    row_sha256 = lineage$registry_row_sha256
  )
  candidate$parent_graph$stage_capture_lineage <- lineage
  candidate$stage_capture_lineage <- lineage
  # The contract manifest intentionally records only its defined parent keys;
  # the richer registry lineage remains available on the candidate graph.
  candidate
}

phase15_nl_build_candidate <- function(loaded, options, source_override = loaded$source) {
  state_bundle <- loaded$state_bundle
  forecasts <- phase15_nl_forecast_handoff(state_bundle)
  simulation <- uefa_nl_run_simulation(
    canonical_matches = state_bundle$canonical_matches,
    completed_results = source_override$results,
    forecast_status = state_bundle$forecast_status,
    forecasts = forecasts,
    score_distributions = state_bundle$score_distributions,
    groups = list(groups = loaded$topology$groups, group_rows = loaded$topology$teams),
    rules = loaded$rules,
    simulation_count = options$simulations,
    seed = options$seed,
    source_bundle_id = state_bundle$source_bundle_id,
    source_bundle_sha256 = state_bundle$source_bundle_sha256,
    model_release_id = state_bundle$model_release_id,
    model_lineage = state_bundle$model_lineage,
    state_manifest_sha256 = state_bundle$state_manifest_sha256,
    euro_playoff_eligibility = NULL,
    official_stage_slots = loaded$stage_capture$stage_capture
  )
  candidate <- phase15_build_nl_outcomes_candidate(
    simulation = simulation,
    rules = loaded$rules,
    topology = loaded$topology,
    source = loaded$source,
    stage_capture = loaded$stage_capture,
    state_bundle = state_bundle,
    project_root = loaded$project_root,
    generated_at_utc = NULL,
    rule_inputs = loaded$rule_inputs
  )
  candidate <- phase15_nl_attach_stage_capture_lineage(candidate, loaded$stage_capture)
  phase15_validate_nl_outcomes_bundle(candidate)
  list(candidate = candidate, simulation = simulation)
}

phase15_nl_reverse_inputs <- function(inputs) {
  reverse_value <- function(value) {
    if (is.data.frame(value)) {
      if (!nrow(value)) return(value)
      return(value[seq.int(nrow(value), 1L), , drop = FALSE])
    }
    if (is.list(value)) {
      return(lapply(value, reverse_value))
    }
    value
  }
  reverse_value(inputs)
}

phase15_nl_compare_replays <- function(first, second, label = "replay") {
  first_candidate <- if (!is.null(first$candidate)) first$candidate else first
  second_candidate <- if (!is.null(second$candidate)) second$candidate else second
  expected <- phase15_nl_outcomes_expected_inventory()
  if (!identical(names(first_candidate$artifacts), names(second_candidate$artifacts))) {
    phase15_nl_fail(sprintf("%s changed the artifact inventory.", label))
  }
  for (artifact in expected) {
    first_bytes <- phase15_nl_csv_bytes(first_candidate$artifacts[[artifact]])
    second_bytes <- phase15_nl_csv_bytes(second_candidate$artifacts[[artifact]])
    if (!identical(first_bytes, second_bytes)) {
      phase15_nl_fail(sprintf("%s changed artifact bytes for %s.", label, artifact))
    }
    if (!identical(phase15_nl_hash_bytes(first_bytes), phase15_nl_hash_bytes(second_bytes))) {
      phase15_nl_fail(sprintf("%s changed artifact hash for %s.", label, artifact))
    }
  }
  compare_fields <- function(first_table, second_table, fields, table_label) {
    fields <- intersect(fields, intersect(names(first_table), names(second_table)))
    if (length(fields) && !identical(first_table[fields], second_table[fields])) {
      phase15_nl_fail(sprintf("%s changed explicit fields in %s.", label, table_label))
    }
  }
  compare_fields(
    first_candidate$artifacts[["outcomes/stage_slots.csv"]],
    second_candidate$artifacts[["outcomes/stage_slots.csv"]],
    c(
      "source_fixture_id", "stage_status", "resolution_status",
      "regulation_home_goals", "regulation_away_goals",
      "extra_time_home_goals", "extra_time_away_goals",
      "penalty_shootout_home_goals", "penalty_shootout_away_goals",
      "final_home_goals", "final_away_goals", "completed_at_utc"
    ),
    "stage_slots.csv"
  )
  compare_fields(
    first_candidate$artifacts[["outcomes/transition_outcomes.csv"]],
    second_candidate$artifacts[["outcomes/transition_outcomes.csv"]],
    c(
      "source_fixture_id", "stage_status", "cd_playoff_status",
      "eligibility_status", "playoff_eligibility_probability",
      "playoff_win_probability", "playoff_loss_probability",
      "retained_next_edition_league", "retained_next_edition_rank"
    ),
    "transition_outcomes.csv"
  )
  compare_fields(
    first_candidate$artifacts[["outcomes/team_path_probabilities.csv"]],
    second_candidate$artifacts[["outcomes/team_path_probabilities.csv"]],
    c("probability", "p_quarter_final", "p_semi_final", "p_final", "p_champion"),
    "team_path_probabilities.csv"
  )
  compare_fields(
    first_candidate$artifacts[["outcomes/simulation_metadata.csv"]],
    second_candidate$artifacts[["outcomes/simulation_metadata.csv"]],
    c(
      "ruleset_version", "ruleset_sha256", "draw_policy_id", "draw_policy_sha256",
      "projection_run_id", "simulation_seed", "simulation_count",
      "source_bundle_id", "source_bundle_sha256", "state_manifest_sha256",
      "model_release_id", "model_sha256", "calibrator_sha256",
      "feature_cutoff_sha256"
    ),
    "simulation_metadata.csv"
  )
  candidate_fields <- c(
    "edition_id", "ruleset_version", "ruleset_sha256", "draw_policy_id",
    "draw_policy_sha256", "projection_run_id", "simulation_seed", "simulation_count",
    "source_bundle_id", "source_bundle_sha256", "state_manifest_sha256",
    "model_release_id", "model_sha256", "calibrator_sha256", "feature_cutoff_sha256"
  )
  for (field in candidate_fields) {
    if (field %in% names(first_candidate) && field %in% names(second_candidate) &&
        !identical(first_candidate[[field]], second_candidate[[field]])) {
      phase15_nl_fail(sprintf("%s changed candidate lineage field %s.", label, field))
    }
  }
  explicit_lineage <- c(
    "stage_capture_capture_id",
    "stage_capture_registry",
    "stage_capture_lineage",
    "stage_capture_manifest",
    "stage_capture_raw",
    "stage_capture_content",
    "article15_rule_inputs_manifest",
    "article15_access_list",
    "article15_discipline_points"
  )
  for (key in explicit_lineage) {
    if (!identical(first_candidate$parent_graph[[key]], second_candidate$parent_graph[[key]])) {
      phase15_nl_fail(sprintf("%s changed source lineage field %s.", label, key))
    }
  }
  invisible(TRUE)
}

phase15_nl_rng_snapshot <- function() {
  list(
    present = exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE),
    value = if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
    } else {
      NULL
    }
  )
}

phase15_nl_rng_restore <- function(snapshot) {
  if (isTRUE(snapshot$present)) {
    assign(".Random.seed", snapshot$value, envir = .GlobalEnv)
  } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
    rm(".Random.seed", envir = .GlobalEnv)
  }
  invisible(TRUE)
}

phase15_build_nl_outcomes_main <- function(
    args = commandArgs(trailingOnly = TRUE),
    project_root = phase15_nl_project_root
) {
  options <- phase15_nl_parse_args(args)
  if (isTRUE(options$help)) {
    return(list(help = TRUE, usage = phase15_nl_cli_usage(), durable_mutation = FALSE))
  }
  project_root <- normalizePath(project_root, mustWork = TRUE)
  rng_before <- phase15_nl_rng_snapshot()
  on.exit(phase15_nl_rng_restore(rng_before), add = TRUE)

  loaded <- phase15_nl_default_inputs(
    edition_id = options$edition_id,
    project_root = project_root
  )
  normal <- phase15_nl_build_candidate(loaded, options)
  result <- list(
    edition_id = options$edition_id,
    mode = options$mode,
    simulations = options$simulations,
    seed = options$seed,
    candidate = normal$candidate,
    simulation = normal$simulation,
    validation = TRUE,
    durable_mutation = FALSE,
    source_bundle_id = loaded$state_bundle$source_bundle_id,
    state_manifest_sha256 = loaded$state_bundle$state_manifest_sha256,
    stage_capture_lineage = normal$candidate$stage_capture_lineage
  )

  if (identical(options$mode, "replay")) {
    reversed <- phase15_nl_build_candidate(phase15_nl_reverse_inputs(loaded), options)
    repeated <- phase15_nl_build_candidate(loaded, options)
    phase15_nl_compare_replays(normal, reversed, label = "reversed replay")
    phase15_nl_compare_replays(normal, repeated, label = "repeated replay")
    result$reversed <- reversed
    result$repeated <- repeated
    result$replay_verified <- TRUE
    result$durable_mutation <- FALSE
  }

  if (identical(options$mode, "write")) {
    written <- phase15_write_nl_outcomes_bundle(
      normal$candidate,
      output_root = phase15_nl_registered_outcomes_root(project_root),
      project_root = project_root
    )
    result$written <- written
    result$durable_mutation <- TRUE
  }
  result
}

phase15_nl_print_result <- function(result) {
  if (isTRUE(result$help)) {
    cat(result$usage, "\n", sep = "")
    return(invisible(TRUE))
  }
  cat(sprintf("edition_id=%s\n", result$edition_id))
  cat(sprintf("mode=%s\n", result$mode))
  cat(sprintf("simulations=%d\n", result$simulations))
  cat(sprintf("seed=%d\n", result$seed))
  cat("artifact_count=9\n")
  cat(sprintf("validation=%s\n", if (isTRUE(result$validation)) "TRUE" else "FALSE"))
  cat(sprintf("durable_mutation=%s\n", if (isTRUE(result$durable_mutation)) "TRUE" else "FALSE"))
  if (isTRUE(result$replay_verified)) {
    cat("replay_verified=TRUE\n")
  }
  if (!is.null(result$written)) {
    cat(sprintf("written_root=%s\n", result$written$output_root))
  }
  lineage <- result$stage_capture_lineage
  if (is.list(lineage)) {
    cat(sprintf("stage_capture_id=%s\n", lineage$capture_id))
    cat(sprintf("stage_capture_raw_sha256=%s\n", lineage$raw_sha256))
    cat(sprintf("stage_capture_content_sha256=%s\n", lineage$capture_content_sha256))
    cat(sprintf("stage_capture_manifest_sha256=%s\n", lineage$manifest_sha256))
    cat(sprintf("stage_capture_registry_row_sha256=%s\n", lineage$registry_row_sha256))
  }
  invisible(TRUE)
}

phase15_nl_direct_invocation <- !interactive() && any(grepl("^--file=", phase15_nl_cli_args))
if (isTRUE(phase15_nl_direct_invocation)) {
  phase15_nl_result <- phase15_build_nl_outcomes_main()
  phase15_nl_print_result(phase15_nl_result)
}
