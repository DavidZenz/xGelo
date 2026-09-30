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

phase15_nl_default_workers <- function() {
  value <- suppressWarnings(as.integer(Sys.getenv("XGELO_NL_WORKERS", "1")))
  if (is.na(value) || value < 1L) value <- 1L
  value
}

phase15_nl_parse_args <- function(args = commandArgs(trailingOnly = TRUE)) {
  options <- list(
    edition_id = NULL,
    simulations = 1000L,
    seed = 15017L,
    workers = phase15_nl_default_workers(),
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
    if (grepl("^--(edition-id|simulations|seed|workers)=", argument)) {
      parts <- strsplit(argument, "=", fixed = TRUE)[[1L]]
      option <- parts[[1L]]
      value <- paste(parts[-1L], collapse = "=")
    } else if (argument %in% c("--edition-id", "--simulations", "--seed", "--workers")) {
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
    } else if (identical(option, "--workers")) {
      parsed <- suppressWarnings(as.integer(value))
      if (is.na(parsed) || parsed < 1L || !identical(as.character(parsed), value)) {
        phase15_nl_fail("--workers must be a positive integer.")
      }
      options$workers <- parsed
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
    "  --workers N       Parallel simulation workers (default: XGELO_NL_WORKERS or 1)",
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

# The Phase 14 state bundle contains forecasts for the league phase only.  The
# Nations League simulation can resolve the knockout path as soon as it is
# given the same approved-model forecast contract for the possible knockout
# matchups.  Build that finite handoff once per state manifest and attach the
# stage/slot identity that the simulator uses when it follows a sampled path.
phase15_nl_knockout_forecast_cache <- if (exists("phase15_nl_knockout_forecast_cache", inherits = FALSE)) {
  get("phase15_nl_knockout_forecast_cache", inherits = FALSE)
} else {
  new.env(parent = emptyenv())
}

phase15_nl_bind_rows_fill <- function(frames) {
  frames <- frames[vapply(frames, function(frame) is.data.frame(frame) && nrow(frame), logical(1))]
  if (!length(frames)) return(data.frame(stringsAsFactors = FALSE, check.names = FALSE))
  fields <- unique(unlist(lapply(frames, names), use.names = FALSE))
  frames <- lapply(frames, function(frame) {
    frame <- as.data.frame(frame, stringsAsFactors = FALSE, check.names = FALSE)
    for (field in setdiff(fields, names(frame))) frame[[field]] <- rep(NA, nrow(frame))
    frame[, fields, drop = FALSE]
  })
  output <- do.call(rbind, frames)
  row.names(output) <- NULL
  output
}

phase15_nl_knockout_stage_contexts <- function(team_table) {
  if (!is.data.frame(team_table) || !nrow(team_table)) return(data.frame(stringsAsFactors = FALSE, check.names = FALSE))
  teams <- team_table[toupper(as.character(team_table$league)) == "A", c("team_id", "group_id"), drop = FALSE]
  teams$team_id <- as.character(teams$team_id)
  teams$group_id <- as.character(teams$group_id)
  teams <- teams[order(teams$group_id, teams$team_id, method = "radix"), , drop = FALSE]
  if (nrow(teams) != 16L) stop("Nations League knockout forecast handoff requires sixteen League A teams", call. = FALSE)

  rows <- list()
  row_index <- 0L
  add <- function(stage_id, leg_number, home_team_id, away_team_id, slot_home, slot_away) {
    row_index <<- row_index + 1L
    rows[[row_index]] <<- data.frame(
      stage_id = stage_id, leg_number = as.integer(leg_number),
      home_team_id = as.character(home_team_id), away_team_id = as.character(away_team_id),
      participant_slot_home = as.character(slot_home), participant_slot_away = as.character(slot_away),
      stringsAsFactors = FALSE, check.names = FALSE
    )
  }

  # Every legal quarter-final pairing is a group winner against a different
  # group runner-up.  The two legs are represented in the simulator's home
  # orientation (runner-up hosts leg one, winner hosts leg two).
  group_ids <- sort(unique(teams$group_id), method = "radix")
  for (group_a in group_ids) {
    for (group_b in setdiff(group_ids, group_a)) {
      winners <- teams$team_id[teams$group_id == group_a]
      runners <- teams$team_id[teams$group_id == group_b]
      for (winner in winners) {
        for (runner in runners) {
          add(
            "league_a_quarter_final", 1L, runner, winner,
            paste0("A-group-runner-up-", group_b), paste0("A-group-winner-", group_a)
          )
          add(
            "league_a_quarter_final", 2L, winner, runner,
            paste0("A-group-winner-", group_a), paste0("A-group-runner-up-", group_b)
          )
        }
      }
    }
  }

  # The semifinal draw is open after the QF draw.  Keep both bracket slots
  # available for every ordered League A team pair.
  semi_slots <- list(
    c("semi-finalist-1", "semi-finalist-2"),
    c("semi-finalist-3", "semi-finalist-4")
  )
  for (slots in semi_slots) {
    for (home in teams$team_id) {
      for (away in teams$team_id[teams$team_id != home]) {
        add("league_a_semi_final", 1L, home, away, slots[[1L]], slots[[2L]])
      }
    }
  }

  # The same pairwise model is used for the final and third-place match.  The
  # actual participants are supplied by the sampled semifinal winners/losers.
  for (stage_id in c("league_a_final", "league_a_third_place")) {
    slots <- if (stage_id == "league_a_final") {
      c("semi-final-1-winner", "semi-final-2-winner")
    } else {
      c("semi-final-1-loser", "semi-final-2-loser")
    }
    for (home in teams$team_id) {
      for (away in teams$team_id[teams$team_id != home]) {
        add(stage_id, 1L, home, away, slots[[1L]], slots[[2L]])
      }
    }
  }
  if (!length(rows)) return(data.frame(stringsAsFactors = FALSE, check.names = FALSE))
  output <- do.call(rbind, rows)
  output$context_id <- sprintf("nl-knockout-context-%05d", seq_len(nrow(output)))
  row.names(output) <- NULL
  output
}

phase15_nl_knockout_forecast_handoff <- function(loaded) {
  if (!is.list(loaded) || !is.list(loaded$state_bundle) || !is.list(loaded$topology)) {
    phase15_nl_fail("Knockout forecast handoff requires loaded Nations League inputs.")
  }
  state <- loaded$state_bundle
  cache_key <- paste(
    phase15_nl_text(state$state_manifest_sha256, ""),
    phase15_nl_text(state$model_release_id, ""),
    sep = "::"
  )
  if (exists(cache_key, envir = phase15_nl_knockout_forecast_cache, inherits = FALSE)) {
    return(get(cache_key, envir = phase15_nl_knockout_forecast_cache, inherits = FALSE))
  }

  base_teams <- loaded$topology$teams[toupper(as.character(loaded$topology$teams$league)) == "A", c("team_id", "group_id"), drop = FALSE]
  team_ids <- sort(unique(as.character(base_teams$team_id)), method = "radix")
  # Build only the ordered pairings that can occur in the registered bracket.
  # The previous implementation forecast every ordered pair of League A
  # teams (54 * 53 = 2,862 rows), even though the Nations League knockout
  # topology needs only the pairs represented by the QF/SF/final contexts.
  # Keeping this finite handoff to the reachable graph is the same
  # precompute-before-simulation pattern used by the WC dashboard and avoids
  # spending most of a refresh fitting forecasts that can never be sampled.
  contexts <- phase15_nl_knockout_stage_contexts(loaded$topology$teams)
  context_pairs <- unique(contexts[c("home_team_id", "away_team_id")])
  context_pairs <- context_pairs[
    !is.na(context_pairs$home_team_id) &
      !is.na(context_pairs$away_team_id) &
      nzchar(as.character(context_pairs$home_team_id)) &
      nzchar(as.character(context_pairs$away_team_id)) &
      context_pairs$home_team_id != context_pairs$away_team_id,
    ,
    drop = FALSE
  ]
  pairs <- context_pairs[order(context_pairs$home_team_id, context_pairs$away_team_id, method = "radix"), , drop = FALSE]
  row.names(pairs) <- NULL
  if (!nrow(pairs) || any(!pairs$home_team_id %in% team_ids) || any(!pairs$away_team_id %in% team_ids)) {
    phase15_nl_fail("Nations League knockout forecast contexts contain an unknown League A team.")
  }
  pairs$edition_id <- phase15_nl_edition_id()
  pairs$fixture_id <- paste0("nl-knockout-base-", pairs$home_team_id, "-", pairs$away_team_id)
  pairs$match_id <- pairs$fixture_id
  pairs$scheduled_at_utc <- "2027-03-21T18:00:00Z"
  pairs$confirmed_kickoff_at_utc <- pairs$scheduled_at_utc
  pairs$kickoff_confirmed <- TRUE
  pairs$source_status <- "UPCOMING"
  pairs$venue <- "home"
  pairs <- pairs[, c(
    "edition_id", "fixture_id", "match_id", "home_team_id", "away_team_id",
    "scheduled_at_utc", "confirmed_kickoff_at_utc", "kickoff_confirmed", "source_status", "venue"
  ), drop = FALSE]

  generated <- phase14_build_fixture_forecasts(
    canonical_matches = pairs,
    team_registry = file.path(loaded$project_root, "data/competition/registries/team_identity.csv"),
    trusted_release_root = file.path(loaded$project_root, "outputs/releases"),
    national_team_xg_registry = file.path(loaded$project_root, "data/competition/registries/national_team_xg_sources.csv"),
    edition_registry = file.path(loaded$project_root, "data/competition/registries/competition_editions.csv"),
    edition_lifecycle_state = "scheduled"
  )
  if (!is.data.frame(generated$forecasts) || nrow(generated$forecasts) != nrow(pairs) ||
      !is.data.frame(generated$fixture_status) || nrow(generated$fixture_status) != nrow(pairs) ||
      !is.data.frame(generated$score_distributions) || !nrow(generated$score_distributions)) {
    phase15_nl_fail("Approved forecast release did not cover the Nations League knockout pairings.")
  }
  if (any(tolower(as.character(generated$forecasts$forecast_status)) != "available") ||
      any(tolower(as.character(generated$fixture_status$forecast_status)) != "available")) {
    phase15_nl_fail("Nations League knockout pairings contain unavailable approved forecasts.")
  }

  base_forecasts <- generated$forecasts
  base_forecasts$home_team_id <- pairs$home_team_id[match(base_forecasts$fixture_id, pairs$fixture_id)]
  base_forecasts$away_team_id <- pairs$away_team_id[match(base_forecasts$fixture_id, pairs$fixture_id)]
  base_forecasts$stage_id <- "league_phase"
  base_forecasts$leg_number <- NA_integer_
  base_forecasts$participant_slot_home <- base_forecasts$home_team_id
  base_forecasts$participant_slot_away <- base_forecasts$away_team_id
  base_status <- generated$fixture_status
  base_status$home_team_id <- pairs$home_team_id[match(base_status$fixture_id, pairs$fixture_id)]
  base_status$away_team_id <- pairs$away_team_id[match(base_status$fixture_id, pairs$fixture_id)]

  pair_key <- paste(pairs$home_team_id, pairs$away_team_id, sep = "::")
  context_key <- paste(contexts$home_team_id, contexts$away_team_id, sep = "::")
  contexts$base_fixture_id <- pairs$fixture_id[match(context_key, pair_key)]
  if (anyNA(contexts$base_fixture_id)) phase15_nl_fail("Knockout forecast context contains an unknown team pairing.")
  contexts$fixture_id <- paste0("nl-knockout-stage-", contexts$context_id)
  contexts$match_id <- contexts$fixture_id

  base_index <- match(contexts$base_fixture_id, base_forecasts$fixture_id)
  stage_forecasts <- base_forecasts[base_index, , drop = FALSE]
  stage_forecasts$fixture_id <- contexts$fixture_id
  stage_forecasts$match_id <- contexts$match_id
  stage_forecasts$stage_id <- contexts$stage_id
  stage_forecasts$leg_number <- contexts$leg_number
  stage_forecasts$home_team_id <- contexts$home_team_id
  stage_forecasts$away_team_id <- contexts$away_team_id
  stage_forecasts$participant_slot_home <- contexts$participant_slot_home
  stage_forecasts$participant_slot_away <- contexts$participant_slot_away
  stage_status <- base_status[match(contexts$base_fixture_id, base_status$fixture_id), , drop = FALSE]
  stage_status$fixture_id <- contexts$fixture_id
  stage_status$match_id <- contexts$match_id
  stage_status$home_team_id <- contexts$home_team_id
  stage_status$away_team_id <- contexts$away_team_id
  stage_status$stage_id <- contexts$stage_id
  stage_status$leg_number <- contexts$leg_number
  stage_status$participant_slot_home <- contexts$participant_slot_home
  stage_status$participant_slot_away <- contexts$participant_slot_away

  league_forecasts <- phase15_nl_forecast_handoff(state)
  league_forecasts$stage_id <- "league_phase"
  league_forecasts$leg_number <- if ("leg_number" %in% names(league_forecasts)) league_forecasts$leg_number else NA_integer_
  league_forecasts$participant_slot_home <- if ("participant_slot_home" %in% names(league_forecasts)) league_forecasts$participant_slot_home else league_forecasts$home_team_id
  league_forecasts$participant_slot_away <- if ("participant_slot_away" %in% names(league_forecasts)) league_forecasts$participant_slot_away else league_forecasts$away_team_id
  league_status <- as.data.frame(state$forecast_status, stringsAsFactors = FALSE, check.names = FALSE)
  output <- list(
    forecasts = phase15_nl_bind_rows_fill(list(league_forecasts, stage_forecasts)),
    forecast_status = phase15_nl_bind_rows_fill(list(league_status, stage_status)),
    score_distributions = phase15_nl_bind_rows_fill(list(state$score_distributions, generated$score_distributions)),
    stage_contexts = contexts,
    base_forecast_count = nrow(base_forecasts),
    stage_forecast_count = nrow(stage_forecasts)
  )
  assign(cache_key, output, envir = phase15_nl_knockout_forecast_cache)
  output
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
  knockout_handoff <- phase15_nl_knockout_forecast_handoff(loaded)
  forecasts <- knockout_handoff$forecasts
  forecast_status <- knockout_handoff$forecast_status
  score_distributions <- knockout_handoff$score_distributions
  simulation <- uefa_nl_run_simulation(
    canonical_matches = state_bundle$canonical_matches,
    completed_results = source_override$results,
    forecast_status = forecast_status,
    forecasts = forecasts,
    score_distributions = score_distributions,
    groups = list(groups = loaded$topology$groups, group_rows = loaded$topology$teams),
    rules = loaded$rules,
    simulation_count = options$simulations,
    workers = options$workers,
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
    workers = options$workers,
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
  cat(sprintf("workers=%d\n", result$workers %||% 1L))
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
