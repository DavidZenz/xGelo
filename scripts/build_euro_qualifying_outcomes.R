#!/usr/bin/env Rscript

# Registered EURO qualifying outcomes entrypoint.  Acquisition remains owned
# by the accepted source manifest; this script only loads, validates, builds,
# replays, and publishes the Phase 16 nine-file outcome candidate.

phase16_euro_cli_command_args <- commandArgs(trailingOnly = FALSE)
phase16_euro_cli_file_arg <- phase16_euro_cli_command_args[
  grepl("^--file=", phase16_euro_cli_command_args)
]
phase16_euro_cli_script_path <- if (length(phase16_euro_cli_file_arg) == 1L) {
  normalizePath(sub("^--file=", "", phase16_euro_cli_file_arg[[1L]]), mustWork = FALSE)
} else {
  normalizePath("scripts/build_euro_qualifying_outcomes.R", mustWork = FALSE)
}
phase16_euro_cli_find_project_root <- function(start_paths) {
  candidates <- character()
  for (start in unique(start_paths)) {
    current <- normalizePath(start, winslash = "/", mustWork = FALSE)
    repeat {
      candidates <- c(candidates, current)
      parent <- dirname(current)
      if (identical(parent, current)) break
      current <- parent
    }
  }
  matches <- candidates[file.exists(file.path(candidates, "R/competition/uefa_euro_outcomes.R"))]
  if (!length(matches)) {
    stop("Could not locate the xGelo project root for EURO outcomes", call. = FALSE)
  }
  normalizePath(matches[[1L]], winslash = "/", mustWork = TRUE)
}
phase16_euro_cli_project_root <- phase16_euro_cli_find_project_root(c(
  dirname(phase16_euro_cli_script_path),
  getwd()
))
phase16_euro_cli_environment <- environment()

`%||%` <- function(left, right) {
  if (is.null(left) || !length(left)) return(right)
  if (length(left) == 1L) {
    item <- left[[1L]]
    if (length(item) == 1L && isTRUE(is.na(item))) return(right)
  }
  left
}

phase16_euro_cli_source_if_missing <- function(relative_path, symbols = character()) {
  is_present <- function(symbol) {
    exists(symbol, envir = phase16_euro_cli_environment, mode = "function", inherits = TRUE)
  }
  missing <- symbols[!vapply(symbols, is_present, logical(1))]
  if (!length(missing)) return(invisible(TRUE))
  dependency <- file.path(phase16_euro_cli_project_root, relative_path)
  if (!file.exists(dependency)) {
    stop("Required EURO outcomes dependency is missing: ", relative_path, call. = FALSE)
  }
  source_environment <- phase16_euro_cli_environment
  isolate_entrypoint <- identical(relative_path, "scripts/build_competition_state.R")
  if (isolate_entrypoint) source_environment <- new.env(parent = phase16_euro_cli_environment)
  sys.source(dependency, envir = source_environment)
  if (isolate_entrypoint && !identical(source_environment, phase16_euro_cli_environment)) {
    exports <- unique(c(
      symbols,
      "phase14_build_competition_state_script_environment",
      "phase14_build_competition_state_batch",
      "phase14_validate_competition_state_bundle"
    ))
    present <- vapply(
      exports,
      function(symbol) exists(symbol, envir = source_environment, inherits = FALSE),
      logical(1)
    )
    for (symbol in exports[present]) {
      assign(symbol, get(symbol, envir = source_environment, inherits = FALSE), envir = phase16_euro_cli_environment)
    }
  }
  missing <- symbols[!vapply(symbols, is_present, logical(1))]
  if (length(missing)) {
    stop("EURO outcomes dependency did not define: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  invisible(TRUE)
}

phase16_euro_cli_source_file <- function(relative_path) {
  dependency <- file.path(phase16_euro_cli_project_root, relative_path)
  if (!file.exists(dependency)) {
    stop("Required EURO outcomes dependency is missing: ", relative_path, call. = FALSE)
  }
  sys.source(dependency, envir = phase16_euro_cli_environment)
  invisible(TRUE)
}

phase16_euro_cli_source_if_missing(
  "R/competition/uefa_euro_rules.R",
  c(
    "uefa_euro_2026_28_rules", "validate_euro_activation", "uefa_euro_ruleset_sha256",
    "uefa_euro_source_bundle_id", "validate_euro_draw_conditions",
    "uefa_euro_playoff_topologies", "allocate_euro_places"
  )
)
phase16_euro_cli_source_if_missing(
  "R/competition/uefa_euro_outcomes.R",
  c("phase16_build_euro_outcomes_candidate", "phase16_validate_euro_outcomes_bundle")
)

phase16_euro_cli_ensure_simulation <- function() {
  phase16_euro_cli_source_if_missing(
    "R/competition/uefa_euro_simulation.R",
    c("uefa_euro_run_simulation", "uefa_euro_normalize_nl_interim_projection")
  )
  invisible(TRUE)
}
phase16_euro_cli_source_if_missing(
  "scripts/build_competition_state.R",
  c("phase14_build_competition_state_main", "phase14_build_competition_state_default_inputs")
)

# The Phase 16 modules may define a legacy coalescing helper while they load;
# keep the CLI boundary's structured-input behavior deterministic.
`%||%` <- function(left, right) {
  if (is.null(left) || !length(left)) return(right)
  if (length(left) == 1L) {
    item <- left[[1L]]
    if (length(item) == 1L && isTRUE(is.na(item))) return(right)
  }
  left
}

phase16_euro_cli_fail <- function(message) {
  stop(message, call. = FALSE)
}

phase16_euro_cli_require_scalar <- function(value, option) {
  if (length(value) != 1L || is.na(value) || !nzchar(as.character(value))) {
    phase16_euro_cli_fail(sprintf("Option %s requires one non-empty value.", option))
  }
  as.character(value[[1L]])
}

phase16_euro_cli_parse_args <- function(args = commandArgs(trailingOnly = TRUE)) {
  options <- list(
    edition_id = NULL,
    simulations = 1000L,
    seed = 16017L,
    dry_run = FALSE,
    replay_check = FALSE,
    write = FALSE,
    replay_probe = NULL,
    help = FALSE,
    mode = "dry-run"
  )
  index <- 1L
  while (index <= length(args)) {
    argument <- as.character(args[[index]])
    if (argument %in% c("--help", "-h")) {
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
    if (grepl("^--(edition-id|simulations|seed|replay-probe)=", argument)) {
      pieces <- strsplit(argument, "=", fixed = TRUE)[[1L]]
      option <- pieces[[1L]]
      value <- paste(pieces[-1L], collapse = "=")
    } else if (argument %in% c("--edition-id", "--simulations", "--seed", "--replay-probe")) {
      if (index == length(args)) phase16_euro_cli_fail(sprintf("Option %s requires one value.", argument))
      option <- argument
      index <- index + 1L
      value <- args[[index]]
    } else {
      phase16_euro_cli_fail(sprintf("Unsupported argument: %s", argument))
    }
    value <- phase16_euro_cli_require_scalar(value, option)
    if (identical(option, "--edition-id")) {
      options$edition_id <- value
    } else if (identical(option, "--simulations")) {
      parsed <- suppressWarnings(as.integer(value))
      if (is.na(parsed) || parsed < 1L || !identical(as.character(parsed), value)) {
        phase16_euro_cli_fail("--simulations must be a positive integer.")
      }
      options$simulations <- parsed
    } else if (identical(option, "--seed")) {
      parsed <- suppressWarnings(as.integer(value))
      if (is.na(parsed) || parsed < 0L || !identical(as.character(parsed), value)) {
        phase16_euro_cli_fail("--seed must be a non-negative integer.")
      }
      options$seed <- parsed
    } else if (identical(option, "--replay-probe")) {
      options$replay_probe <- normalizePath(value, winslash = "/", mustWork = FALSE)
    }
    index <- index + 1L
  }
  if (isTRUE(options$help)) return(options)
  if (is.null(options$edition_id)) phase16_euro_cli_fail("--edition-id is required.")
  if (!identical(options$edition_id, phase16_euro_edition_id())) {
    phase16_euro_cli_fail(sprintf(
      "Unsupported edition-id '%s'; only %s is registered.",
      options$edition_id,
      phase16_euro_edition_id()
    ))
  }
  mode_count <- sum(c(options$dry_run, options$replay_check, options$write))
  if (mode_count > 1L) phase16_euro_cli_fail("--dry-run, --replay-check, and --write are mutually exclusive.")
  if (!is.null(options$replay_probe) && isTRUE(options$write)) {
    phase16_euro_cli_fail("--replay-probe is only valid for a non-mutating run.")
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

phase16_euro_cli_usage <- function() {
  script_name <- file.path("scripts", basename(phase16_euro_cli_script_path))
  paste(
    "Usage:",
    paste0("  Rscript --vanilla ", script_name),
    "--edition-id uefa_euro_2028_qualifying [options]",
    "",
    "Options:",
    "  --simulations N   Positive simulation count (default: 1000)",
    "  --seed N          Non-negative deterministic seed (default: 16017)",
    "  --dry-run         Validate and build in memory (default mode)",
    "  --replay-check    Validate normal, reversed, repeated, and fresh replays",
    "  --write           Atomically publish the registered nine-file bundle",
    "  --help            Show this help",
    sep = "\n"
  )
}

phase16_euro_cli_read_csv <- function(path, required = FALSE) {
  if (!file.exists(path)) {
    if (isTRUE(required)) phase16_euro_cli_fail(paste0("Registered EURO input is missing: ", path))
    return(NULL)
  }
  utils::read.csv(
    path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = "",
    colClasses = "character"
  )
}

phase16_euro_cli_scalar <- function(value, default = "") {
  if (is.null(value) || !length(value) || is.na(value[[1L]])) return(default)
  value <- trimws(as.character(value[[1L]]))
  if (nzchar(value)) value else default
}

phase16_euro_cli_first <- function(data, fields, default = "") {
  if (is.null(data)) return(default)
  if (is.data.frame(data)) {
    for (field in fields) {
      if (field %in% names(data) && nrow(data)) return(phase16_euro_cli_scalar(data[[field]], default))
    }
  } else if (is.list(data)) {
    for (field in fields) {
      if (!is.null(data[[field]])) return(phase16_euro_cli_scalar(data[[field]], default))
    }
  }
  default
}

phase16_euro_cli_bind_edition <- function(data, edition_id) {
  if (is.null(data)) return(data.frame(edition_id = character(), stringsAsFactors = FALSE, check.names = FALSE))
  data <- as.data.frame(data, stringsAsFactors = FALSE, check.names = FALSE)
  if (!"edition_id" %in% names(data)) data$edition_id <- edition_id
  data
}

phase16_euro_cli_normalize_resource <- function(data, resource, edition_id) {
  data <- phase16_euro_cli_bind_edition(data, edition_id)
  if (!nrow(data)) return(data)
  if (identical(resource, "groups") && !"group_id" %in% names(data) && "source_group_id" %in% names(data)) {
    data$group_id <- as.character(data$source_group_id)
  }
  if (identical(resource, "fixtures") && "group_id" %in% names(data) && "source_group_id" %in% names(data)) {
    empty <- is.na(data$group_id) | !nzchar(as.character(data$group_id))
    data$group_id[empty] <- as.character(data$source_group_id[empty])
  }
  data
}

phase16_euro_cli_order_frame <- function(data) {
  if (!is.data.frame(data) || nrow(data) < 2L || !ncol(data)) return(data)
  values <- lapply(data, function(column) {
    output <- as.character(column)
    output[is.na(output)] <- ""
    output
  })
  ordering <- do.call(order, c(values, list(na.last = TRUE, method = "radix")))
  data[ordering, , drop = FALSE]
}

phase16_euro_cli_order_value <- function(value) {
  if (is.data.frame(value)) return(phase16_euro_cli_order_frame(value))
  if (is.list(value)) {
    output <- lapply(value, phase16_euro_cli_order_value)
    if (!is.null(names(output))) output <- output[sort(names(output), method = "radix")]
    return(output)
  }
  value
}

phase16_euro_cli_reverse_value <- function(value) {
  if (is.data.frame(value)) {
    if (nrow(value) < 2L) return(value)
    return(value[rev(seq_len(nrow(value))), , drop = FALSE])
  }
  if (is.list(value)) return(lapply(value, phase16_euro_cli_reverse_value))
  value
}

phase16_euro_cli_hash_bytes <- function(bytes) {
  if (!requireNamespace("digest", quietly = TRUE)) phase16_euro_cli_fail("digest is required for EURO replay hashes")
  digest::digest(bytes, algo = "sha256", serialize = FALSE)
}

phase16_euro_cli_read_raw_hash <- function(path) {
  phase16_euro_cli_hash_bytes(readBin(path, what = "raw", n = file.info(path)$size))
}

phase16_euro_cli_manifest_rows <- function(manifest, field, default = "") {
  if (!is.data.frame(manifest) || !field %in% names(manifest)) return(default)
  values <- as.character(manifest[[field]])
  values <- values[!is.na(values) & nzchar(values)]
  if (length(values)) values[[1L]] else default
}

phase16_euro_cli_source_lineage <- function(manifest, accepted_root, edition_id, source_bundle_id) {
  manifest <- as.data.frame(manifest, stringsAsFactors = FALSE, check.names = FALSE)
  manifest <- phase16_euro_cli_order_frame(manifest)
  artifacts <- manifest
  artifact_ids <- if ("source_artifact_id" %in% names(artifacts)) {
    paste(as.character(artifacts$source_artifact_id), collapse = "|")
  } else {
    ""
  }
  artifact_paths <- paste(
    file.path("data/competition/accepted", edition_id, paste0(
      as.character(artifacts$artifact_type), ".csv"
    )),
    collapse = "|"
  )
  raw_values <- if ("raw_sha256" %in% names(artifacts)) as.character(artifacts$raw_sha256) else character()
  raw_values <- raw_values[!is.na(raw_values) & nzchar(raw_values)]
  list(
    source_bundle_id = source_bundle_id,
    source_bundle_sha256 = phase16_euro_cli_first(artifacts, c("source_bundle_sha256", "bundle_sha256")),
    artifact_manifest_sha256 = phase16_euro_cli_first(artifacts, c("artifact_manifest_sha256", "manifest_sha256")),
    source_artifact_ids = artifact_ids,
    source_artifact_paths = artifact_paths,
    source_manifest_path = file.path("data/competition/accepted", edition_id, "source_bundle_manifest.csv"),
    raw_sha256 = if (length(raw_values)) raw_values[[1L]] else "",
    raw_sha256_all = paste(raw_values, collapse = "|"),
    accepted_root = normalizePath(accepted_root, winslash = "/", mustWork = FALSE)
  )
}

phase16_euro_cli_team_registry <- function(resources, project_root, edition_id) {
  fixture_rows <- resources$fixtures
  standings <- resources$standings
  ids <- unique(c(
    if (is.data.frame(fixture_rows) && nrow(fixture_rows)) as.character(fixture_rows$home_team_id) else character(),
    if (is.data.frame(fixture_rows) && nrow(fixture_rows)) as.character(fixture_rows$away_team_id) else character(),
    if (is.data.frame(standings) && nrow(standings) && "team_id" %in% names(standings)) as.character(standings$team_id) else character()
  ))
  ids <- ids[!is.na(ids) & nzchar(ids)]
  if (!length(ids)) {
    return(data.frame(team_id = character(), stringsAsFactors = FALSE, check.names = FALSE))
  }
  registry <- phase16_euro_cli_read_csv(
    file.path(project_root, "data/competition/registries/team_identity.csv")
  )
  output <- data.frame(team_id = ids, stringsAsFactors = FALSE, check.names = FALSE)
  output$display_name <- output$team_id
  output$association_id <- output$team_id
  if (is.data.frame(fixture_rows) && nrow(fixture_rows)) {
    display <- c(
      setNames(as.character(fixture_rows$home_display_name), as.character(fixture_rows$home_team_id)),
      setNames(as.character(fixture_rows$away_display_name), as.character(fixture_rows$away_team_id))
    )
    matched <- display[output$team_id]
    matched[is.na(matched) | !nzchar(matched)] <- output$display_name[is.na(matched) | !nzchar(matched)]
    output$display_name <- unname(matched)
  }
  if (is.data.frame(registry) && nrow(registry) && "team_id" %in% names(registry)) {
    matched <- match(output$team_id, as.character(registry$team_id))
    display <- if ("uefa_display_name_current" %in% names(registry)) as.character(registry$uefa_display_name_current) else as.character(registry$canonical_name)
    display[is.na(display) | !nzchar(display)] <- output$display_name[is.na(display) | !nzchar(display)]
    output$display_name <- display[matched]
    output$display_name[is.na(output$display_name) | !nzchar(output$display_name)] <- output$team_id[is.na(output$display_name) | !nzchar(output$display_name)]
    if ("fifa_code" %in% names(registry)) {
      output$association_id <- as.character(registry$fifa_code)[matched]
      output$association_id[is.na(output$association_id) | !nzchar(output$association_id)] <- output$team_id[is.na(output$association_id) | !nzchar(output$association_id)]
    }
  }
  output$edition_id <- edition_id
  output$source_bundle_id <- ""
  phase16_euro_cli_order_frame(output)
}

phase16_euro_cli_read_source <- function(project_root, edition_id, registry_row = NULL) {
  accepted_root <- file.path(project_root, "data/competition/accepted", edition_id)
  required <- c("fixtures", "groups", "standings", "results", "status")
  resources <- setNames(lapply(required, function(resource) {
    phase16_euro_cli_normalize_resource(
      phase16_euro_cli_read_csv(file.path(accepted_root, paste0(resource, ".csv")), required = TRUE),
      resource,
      edition_id
    )
  }), required)
  manifest_path <- file.path(accepted_root, "source_bundle_manifest.csv")
  manifest <- phase16_euro_cli_read_csv(manifest_path, required = TRUE)
  bundle_id <- phase16_euro_cli_first(
    registry_row,
    c("source_bundle_id", "active_output_bundle_id", "last_accepted_output_bundle_id")
  )
  if (!nzchar(bundle_id)) bundle_id <- phase16_euro_cli_first(manifest, c("bundle_id", "source_bundle_id"))
  source_bundle_registry <- phase16_euro_cli_read_csv(
    file.path(project_root, "data/competition/registries/source_bundles.csv")
  )
  source_bundle <- if (is.data.frame(source_bundle_registry) && nrow(source_bundle_registry)) {
    row <- source_bundle_registry[as.character(source_bundle_registry$bundle_id) == bundle_id, , drop = FALSE]
    if (nrow(row)) row[1L, , drop = FALSE] else data.frame(stringsAsFactors = FALSE, check.names = FALSE)
  } else {
    data.frame(stringsAsFactors = FALSE, check.names = FALSE)
  }
  source_bundle <- as.list(source_bundle)
  source_bundle$bundle_id <- bundle_id
  source_bundle$source_bundle_id <- bundle_id
  source_bundle$edition_id <- edition_id
  source_bundle$bundle_status <- phase16_euro_cli_first(source_bundle, c("bundle_status", "acceptance_state"), "accepted")
  source_bundle$source_confidence <- phase16_euro_cli_first(source_bundle, c("source_confidence", "fallback_status"), "official")
  source_bundle$ruleset_version <- phase16_euro_cli_first(registry_row, c("ruleset_version"), uefa_euro_ruleset_version())
  source_bundle$artifacts <- manifest
  source_lineage <- phase16_euro_cli_source_lineage(manifest, accepted_root, edition_id, bundle_id)
  raw_snapshot <- list(
    source_bundle_id = bundle_id,
    bundle_id = bundle_id,
    edition_id = edition_id,
    retrieved_at_utc = phase16_euro_cli_first(manifest, c("retrieved_at_utc", "accepted_at_utc")),
    raw_sha256 = source_lineage$raw_sha256,
    raw_sha256_all = source_lineage$raw_sha256_all
  )
  status <- resources$status
  lifecycle <- tolower(phase16_euro_cli_first(status, c("lifecycle_state", "competition_status"), "pre_draw"))
  if (lifecycle %in% c("active", "in_progress")) lifecycle <- "scheduled"
  resources$status$lifecycle_state <- lifecycle
  resources$status$edition_id <- edition_id
  activation <- list(
    edition_id = edition_id,
    lifecycle_state = lifecycle,
    activation_status = if (identical(lifecycle, "pre_draw")) "pre_draw" else "active",
    forecast_status = if (identical(lifecycle, "pre_draw")) "pre_draw" else "available",
    source_bundle_id = bundle_id,
    ruleset_version = source_bundle$ruleset_version,
    source_confidence = source_bundle$source_confidence,
    last_refresh_at_utc = raw_snapshot$retrieved_at_utc,
    source_bundle = source_bundle,
    resources = c(
      list(teams = phase16_euro_cli_team_registry(resources, project_root, edition_id)),
      resources
    ),
    manifest = manifest,
    raw_snapshot = raw_snapshot
  )
  list(
    project_root = project_root,
    edition_id = edition_id,
    accepted_root = accepted_root,
    source = source_bundle,
    source_manifest = manifest,
    source_lineage = source_lineage,
    raw_snapshot = raw_snapshot,
    activation = activation,
    resources = resources,
    source_bundle_id = bundle_id
  )
}

phase16_euro_cli_state_lineage <- function(state_candidate, source_lineage) {
  row <- if (is.data.frame(state_candidate$state_manifest) && nrow(state_candidate$state_manifest)) {
    state_candidate$state_manifest[1L, , drop = FALSE]
  } else {
    data.frame(stringsAsFactors = FALSE, check.names = FALSE)
  }
  value <- function(field, fallback = "") {
    phase16_euro_cli_first(row, field, phase16_euro_cli_first(state_candidate, field, fallback))
  }
  list(
    source_bundle_id = source_lineage$source_bundle_id,
    source_bundle_sha256 = source_lineage$source_bundle_sha256,
    source_artifact_ids = source_lineage$source_artifact_ids,
    source_artifact_paths = source_lineage$source_artifact_paths,
    artifact_manifest_sha256 = source_lineage$artifact_manifest_sha256,
    model_release_id = value("model_release_id"),
    model_id = value("model_id"),
    model_sha256 = value("model_sha256"),
    release_manifest_sha256 = value("release_manifest_sha256"),
    release_selector_sha256 = value("release_selector_sha256"),
    calibrator_id = value("calibrator_id"),
    calibrator_sha256 = value("calibrator_sha256"),
    model_data_cutoff = value("model_data_cutoff"),
    state_manifest_sha256 = state_candidate$state_manifest_sha256 %||% "",
    forecast_status_sha256 = value("forecast_status_sha256"),
    forecasts_sha256 = value("forecasts_sha256"),
    score_distributions_sha256 = value("score_distributions_sha256"),
    feature_cutoff_sha256 = value("feature_cutoff_sha256")
  )
}

phase16_euro_cli_state_bundle <- function(state_candidate) {
  if (is.null(state_candidate)) return(NULL)
  if (!is.null(state_candidate$state_artifacts)) {
    artifacts <- state_candidate$state_artifacts
    read_artifact <- function(path, fallback = data.frame(stringsAsFactors = FALSE)) {
      value <- artifacts[[path]]
      if (is.data.frame(value)) return(value)
      fallback
    }
    score <- artifacts[["local/score_distributions.rds"]]
    return(list(
      edition_id = state_candidate$edition_id,
      state_manifest = state_candidate$state_manifest,
      state_manifest_sha256 = state_candidate$state_manifest_sha256,
      model_release_id = phase16_euro_cli_first(state_candidate$state_manifest, "model_release_id"),
      canonical_matches = read_artifact("state/canonical_matches.csv"),
      forecast_status = read_artifact("state/forecast_status.csv"),
      forecasts = read_artifact("state/forecasts.csv"),
      competition_form = read_artifact("state/competition_form.csv"),
      all_international_form = read_artifact("state/all_international_form.csv"),
      score_distributions = score %||% data.frame(stringsAsFactors = FALSE),
      parent_graph = list()
    ))
  }
  state_candidate
}

phase16_euro_default_inputs <- function(
    edition_id = NULL,
    project_root = phase16_euro_cli_project_root,
    state_bundle = NULL,
    simulation = NULL,
    source_override = NULL,
    activation = NULL,
    model_lineage = NULL,
    nl_handoff = NULL,
    config = NULL) {
  if (is.null(edition_id)) phase16_euro_cli_fail("phase16_euro_default_inputs requires an explicit edition_id")
  if (!identical(edition_id, phase16_euro_edition_id())) {
    phase16_euro_cli_fail(sprintf("Unsupported edition-id '%s'.", edition_id))
  }
  project_root <- normalizePath(project_root, winslash = "/", mustWork = TRUE)
  registry <- phase16_euro_cli_read_csv(
    file.path(project_root, "data/competition/registries/competition_editions.csv"),
    required = TRUE
  )
  registry_row <- registry[as.character(registry$edition_id) == edition_id, , drop = FALSE]
  if (nrow(registry_row) != 1L) phase16_euro_cli_fail("Registered EURO edition row is missing or ambiguous")
  source <- phase16_euro_cli_read_source(project_root, edition_id, registry_row)
  if (!is.null(source_override)) {
    if (is.list(source_override) && !is.null(source_override$resources)) {
      source$activation <- source_override
    } else {
      source$activation$resources <- source_override
    }
  }
  if (!is.null(activation)) source$activation <- activation
  state_candidate <- state_bundle
  if (is.null(state_candidate)) {
    state_result <- phase14_build_competition_state_main(
      args = c("--edition-id", edition_id, "--dry-run"),
      project_root = project_root,
      input_loader_fn = phase14_build_competition_state_default_inputs,
      build_batch_fn = phase14_build_competition_state_script_environment$phase14_build_competition_state_batch,
      validate_fn = phase14_validate_competition_state_bundle
    )
    state_candidate <- state_result$batch$candidates[[edition_id]]
  }
  state <- phase16_euro_cli_state_bundle(state_candidate)
  if (is.null(model_lineage)) model_lineage <- phase16_euro_cli_state_lineage(state_candidate, source$source_lineage)
  phase16_euro_cli_ensure_simulation()
  if (is.null(nl_handoff) && exists("uefa_euro_read_registered_nl_handoff", mode = "function", inherits = TRUE)) {
    nl_handoff <- uefa_euro_read_registered_nl_handoff(project_root = project_root)
  }
  list(
    project_root = project_root,
    edition_id = edition_id,
    registry = registry,
    registry_row = registry_row,
    config = config %||% list(),
    activation_config = config %||% list(),
    activation = source$activation,
    source = source$source,
    source_lineage = source$source_lineage,
    raw_snapshot = source$raw_snapshot,
    state_bundle = state,
    state_candidate = state_candidate,
    model_lineage = model_lineage,
    nl_handoff = nl_handoff,
    simulation = simulation,
    generated_at_utc = source$raw_snapshot$retrieved_at_utc
  )
}

phase16_euro_cli_phase15_handoff <- function(loaded) {
  handoff <- loaded$nl_handoff
  if (is.null(handoff)) return(NULL)
  if (is.data.frame(handoff)) return(handoff)
  if (is.list(handoff)) return(handoff)
  NULL
}

phase16_euro_cli_simulation <- function(loaded, activation, options, state, model_lineage) {
  if (!identical(tolower(phase16_euro_cli_first(activation, c("activation_status", "lifecycle_state"))), "active") &&
      !identical(tolower(phase16_euro_cli_first(activation$resources$status, c("competition_status", "lifecycle_state"))), "active") &&
      !identical(tolower(phase16_euro_cli_first(activation$resources$status, c("competition_status", "lifecycle_state"))), "scheduled")) {
    return(NULL)
  }
  simulation <- loaded$simulation
  if (is.function(simulation)) simulation <- simulation(loaded = loaded, options = options)
  if (!is.null(simulation)) return(simulation)
  phase16_euro_cli_ensure_simulation()
  # Active-after-draw output may legitimately have no completed standings or
  # forecasts yet.  Preserve official groups/fixtures without fabricating
  # probabilities until the registered Phase 14 inputs are available.
  list(
    status = "available",
    reason = "forecast_inputs_pending",
    projection_run_id = paste0("phase16-euro-", options$seed),
    simulation_seed = options$seed,
    simulation_count = options$simulations,
    draw_policy_id = "uefa-euro-2028-playoff-draw-conditions-v1",
    stage_slots = data.frame(stringsAsFactors = FALSE, check.names = FALSE),
    simulation_metadata = data.frame(
      status = "available",
      reason = "forecast_inputs_pending",
      simulation_seed = options$seed,
      simulation_count = options$simulations,
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  )
}

phase16_euro_cli_payload <- function(candidate, activation_validation, loaded) {
  rules <- candidate$rules %||% uefa_euro_2026_28_rules()
  source_bundle_id <- phase16_euro_cli_first(candidate$source, c("source_bundle_id", "bundle_id"))
  last_refresh <- phase16_euro_cli_first(
    activation_validation,
    c("last_refresh_at_utc"),
    phase16_euro_cli_first(loaded$raw_snapshot, c("retrieved_at_utc", "last_refresh_at_utc"))
  )
  reason <- phase16_euro_cli_first(
    activation_validation,
    c("forecast_unavailability_reason", "failure_reason", "reason"),
    candidate$reason %||% ""
  )
  list(
    message_heading = phase16_euro_cli_first(rules, "message_heading", "EURO qualifying is awaiting the official draw"),
    message_body = phase16_euro_cli_first(rules, "message_body", paste(
      "Official groups and the schedule are not available yet.",
      "The draw is expected on 6 December 2026.",
      "Forecasts will appear after a complete official draw-and-schedule bundle is accepted."
    )),
    official_draw_date = phase16_euro_cli_first(
      activation_validation,
      "official_draw_date",
      phase16_euro_cli_first(rules, "official_draw_date", "2026-12-06")
    ),
    last_refresh_at_utc = last_refresh,
    source_bundle_id = source_bundle_id,
    source_confidence = phase16_euro_cli_first(activation_validation, "source_confidence", "official_registry_pending"),
    forecast_reason = if (identical(candidate$candidate_status, "pre_draw")) {
      "awaiting_official_draw_and_schedule"
    } else {
      reason
    },
    forecast_unavailability_reason = reason,
    raw_snapshot_sha256 = phase16_euro_cli_first(activation_validation, "raw_sha256", phase16_euro_cli_first(loaded$raw_snapshot, "raw_sha256"))
  )
}

phase16_euro_cli_prepare_activation <- function(activation, loaded) {
  if (!is.list(activation)) phase16_euro_cli_fail("Registered EURO activation input must be a list")
  edition_id <- loaded$edition_id %||% phase16_euro_edition_id()
  source_lineage <- loaded$source_lineage %||% list()
  source_bundle_id <- phase16_euro_cli_first(
    activation,
    c("source_bundle_id"),
    phase16_euro_cli_first(source_lineage, "source_bundle_id")
  )
  ruleset_version <- phase16_euro_cli_first(
    activation,
    c("ruleset_version"),
    phase16_euro_cli_first(source_lineage, "ruleset_version", uefa_euro_ruleset_version())
  )
  last_refresh <- phase16_euro_cli_first(
    activation,
    c("last_refresh_at_utc"),
    phase16_euro_cli_first(loaded$raw_snapshot, c("retrieved_at_utc", "last_refresh_at_utc"), "registered")
  )
  source_bundle <- activation[["source_bundle"]]
  if (!is.list(source_bundle)) source_bundle <- list()
  source_bundle$bundle_id <- source_bundle$bundle_id %||% source_bundle_id
  source_bundle$source_bundle_id <- source_bundle$source_bundle_id %||% source_bundle_id
  source_bundle$edition_id <- source_bundle$edition_id %||% edition_id
  source_bundle$ruleset_version <- source_bundle$ruleset_version %||% ruleset_version
  source_bundle$bundle_status <- source_bundle$bundle_status %||% "accepted"
  source_bundle$source_confidence <- source_bundle$source_confidence %||% phase16_euro_cli_first(activation, "source_confidence", "official")

  manifest <- activation[["manifest"]]
  if (!is.data.frame(manifest) && is.data.frame(source_bundle$artifacts)) manifest <- source_bundle$artifacts
  required <- c("fixtures", "groups", "standings", "results", "status")
  if (!is.data.frame(manifest) || !all(required %in% as.character(manifest$artifact_type))) {
    artifact_ids <- strsplit(phase16_euro_cli_first(source_lineage, "source_artifact_ids"), "\\|", fixed = FALSE)[[1L]]
    artifact_ids <- artifact_ids[nzchar(artifact_ids)]
    if (length(artifact_ids) != length(required)) artifact_ids <- paste0("registered-source-", required, "-v1")
    raw_hash <- phase16_euro_cli_first(
      loaded$raw_snapshot,
      c("raw_sha256", "snapshot_sha256"),
      phase16_euro_cli_first(source_lineage, c("raw_sha256", "source_bundle_sha256"), phase16_euro_cli_hash_bytes(charToRaw(source_bundle_id)))
    )
    canonical_hash <- phase16_euro_cli_first(
      source_lineage,
      c("artifact_manifest_sha256", "source_bundle_sha256"),
      phase16_euro_cli_hash_bytes(charToRaw(paste0(source_bundle_id, "-manifest")))
    )
    manifest <- data.frame(
      artifact_type = required,
      artifact_id = paste0("registered-artifact-", required, "-v1"),
      source_artifact_id = artifact_ids[match(required, required)],
      edition_id = edition_id,
      bundle_id = source_bundle_id,
      source_url = "registered-source-manifest",
      retrieved_at_utc = last_refresh,
      parser_version = "registered-source-manifest-v1",
      raw_sha256 = raw_hash,
      canonical_content_sha256 = canonical_hash,
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  }
  source_bundle$artifacts <- manifest

  resources <- activation[["resources"]]
  if (!is.list(resources)) {
    resources <- setNames(lapply(required, function(resource) activation[[resource]]), required)
  }
  for (resource in required) {
    if (is.null(resources[[resource]])) resources[[resource]] <- activation[[resource]]
    if (is.null(resources[[resource]])) {
      resources[[resource]] <- data.frame(stringsAsFactors = FALSE, check.names = FALSE)
    }
  }
  if (is.null(resources$status) || !is.data.frame(resources$status) ||
      !nrow(resources$status) || !ncol(resources$status)) {
    resources$status <- data.frame(
      edition_id = edition_id,
      lifecycle_state = phase16_euro_cli_first(activation, "lifecycle_state", "pre_draw"),
      competition_status = phase16_euro_cli_first(activation, "competition_status", phase16_euro_cli_first(activation, "lifecycle_state", "pre_draw")),
      source_bundle_id = source_bundle_id,
      ruleset_version = ruleset_version,
      retrieved_at_utc = last_refresh,
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  }
  teams <- activation[["teams"]]
  if (is.null(teams)) teams <- resources$teams
  if (!is.null(teams)) resources$teams <- teams

  raw_snapshot <- activation[["raw_snapshot"]]
  if (!is.list(raw_snapshot)) raw_snapshot <- list()
  raw_snapshot$bundle_id <- raw_snapshot$bundle_id %||% source_bundle_id
  raw_snapshot$source_bundle_id <- raw_snapshot$source_bundle_id %||% source_bundle_id
  raw_snapshot$edition_id <- raw_snapshot$edition_id %||% edition_id
  raw_snapshot$retrieved_at_utc <- raw_snapshot$retrieved_at_utc %||% last_refresh
  raw_snapshot$raw_sha256 <- raw_snapshot$raw_sha256 %||% phase16_euro_cli_first(
    source_lineage,
    c("raw_sha256", "source_bundle_sha256"),
    phase16_euro_cli_hash_bytes(charToRaw(source_bundle_id))
  )

  activation$edition_id <- activation$edition_id %||% edition_id
  activation$source_bundle_id <- source_bundle_id
  activation$ruleset_version <- ruleset_version
  activation$source_bundle <- source_bundle
  activation$resources <- c(list(teams = teams), resources[setdiff(names(resources), "teams")])
  activation$manifest <- manifest
  activation$raw_snapshot <- raw_snapshot
  activation
}

phase16_euro_cli_suppress_candidate_rows <- function(candidate) {
  blocked_statuses <- c("unavailable", "unresolved", "unsupported_topology", "revision_blocked")
  if (!phase16_euro_cli_scalar(candidate$candidate_status) %in% blocked_statuses) return(candidate)
  schemas <- phase16_euro_outcomes_schema()
  expected <- phase16_euro_outcomes_expected_inventory()
  for (path in setdiff(expected, c("outcomes/simulation_metadata.csv", "outcomes/outcomes_manifest.csv"))) {
    key <- sub("\\.csv$", "", sub("^outcomes/", "", path))
    candidate$artifacts[[path]] <- phase16_euro_empty_table(schemas[[key]])
    candidate[[key]] <- candidate$artifacts[[path]]
  }
  candidate$outcomes_artifacts <- candidate$artifacts
  candidate
}

phase16_euro_cli_refresh_manifest <- function(candidate, payload) {
  manifest <- candidate$manifest %||% candidate$artifacts[["outcomes/outcomes_manifest.csv"]]
  if (!is.data.frame(manifest) || !nrow(manifest)) return(candidate)
  status <- tolower(as.character(candidate$candidate_status %||% ""))
  warning <- if (identical(status, "pre_draw")) {
    paste(
      payload$message_heading,
      payload$message_body,
      paste0("expected_draw_date=", payload$official_draw_date),
      paste0("last_refresh_at_utc=", payload$last_refresh_at_utc),
      paste0("source_bundle_id=", payload$source_bundle_id),
      paste0("unavailability_reason=", payload$forecast_unavailability_reason),
      sep = " | "
    )
  } else if (status %in% c("unavailable", "unresolved", "unsupported_topology", "revision_blocked")) {
    paste0("unavailability_reason=", payload$forecast_unavailability_reason)
  } else {
    "none"
  }
  manifest$warnings <- warning
  manifest$failure_reason <- if (status %in% c("unavailable", "unresolved", "unsupported_topology", "revision_blocked")) {
    payload$forecast_unavailability_reason
  } else {
    ""
  }
  manifest$manifest_sha256 <- ""
  manifest$row_sha256 <- ""
  self_index <- which(manifest$artifact_path == "outcomes/outcomes_manifest.csv")
  if (length(self_index) != 1L) phase16_euro_cli_fail("EURO outcomes manifest self row is missing")
  manifest$row_count[[self_index]] <- 0L
  manifest$content_sha256[[self_index]] <- ""
  manifest_hash <- phase16_euro_table_content_hash(manifest)
  manifest$manifest_sha256 <- manifest_hash
  manifest$row_count[[self_index]] <- nrow(manifest)
  manifest$content_sha256[[self_index]] <- manifest_hash
  manifest$row_sha256 <- phase16_euro_row_hashes(manifest)
  manifest <- manifest[, phase16_euro_outcomes_schema()$outcomes_manifest, drop = FALSE]
  candidate$manifest <- manifest
  candidate$artifacts[["outcomes/outcomes_manifest.csv"]] <- manifest
  candidate$outcomes_artifacts <- candidate$artifacts
  candidate$manifest_sha256 <- manifest_hash
  candidate
}

phase16_euro_cli_build_candidate <- function(loaded, options, source_override = NULL) {
  if (!is.list(loaded)) phase16_euro_cli_fail("EURO CLI input loader must return a list")
  loaded <- phase16_euro_cli_order_value(loaded)
  if (!is.null(source_override)) {
    if (is.list(source_override) && !is.null(source_override$resources)) loaded$activation <- source_override else loaded$activation$resources <- source_override
  }
  activation <- phase16_euro_cli_prepare_activation(loaded$activation, loaded)
  loaded$activation <- activation
  if (is.null(activation)) phase16_euro_cli_fail("Registered EURO activation input is missing")
  options <- options %||% list(simulations = 1000L, seed = 16017L)
  options$simulations <- options$simulations %||% 1000L
  options$seed <- options$seed %||% 16017L
  state <- phase16_euro_cli_state_bundle(loaded$state_bundle)
  model_lineage <- loaded$model_lineage %||% list()
  source_lineage <- loaded$source_lineage %||% list()
  incumbent <- loaded$incumbent
  activation_validation <- phase16_validate_euro_activation(
    candidate = activation,
    config = loaded$config %||% loaded$activation_config,
    incumbent = incumbent
  )
  build_activation <- activation
  if (!isTRUE(activation_validation$valid)) {
    build_activation$activation_status <- if (!is.null(incumbent)) "revision_blocked" else "unavailable"
    build_activation$lifecycle_state <- if (!is.null(incumbent)) "revision_blocked" else "unavailable"
    build_activation$forecast_status <- "unavailable"
    build_activation$reason <- activation_validation$failure_reason %||% activation_validation$reason
    build_activation$forecast_reason <- build_activation$reason
  }
  simulation <- phase16_euro_cli_simulation(loaded, activation, options, state, model_lineage)
  generated_at <- loaded$generated_at_utc %||% activation_validation$last_refresh_at_utc %||% ""
  candidate <- phase16_build_euro_outcomes_candidate(
    simulation = simulation,
    rules = loaded$rules %||% uefa_euro_2026_28_rules(loaded$config %||% loaded$activation_config),
    topology = loaded$topology,
    source = loaded[["source"]],
    stage_capture = loaded$stage_capture,
    state_bundle = state,
    project_root = loaded$project_root %||% phase16_euro_cli_project_root,
    generated_at_utc = generated_at,
    activation = build_activation,
    source_lineage = source_lineage,
    model_lineage = model_lineage,
    incumbent = incumbent
  )
  candidate$activation_validation <- activation_validation
  candidate$payload <- phase16_euro_cli_payload(candidate, activation_validation, loaded)
  candidate$raw_sha256 <- candidate$payload$raw_snapshot_sha256
  candidate$source_bundle_id <- candidate$payload$source_bundle_id
  candidate$revision_status <- if (isTRUE(activation_validation$valid)) {
    if (is.null(incumbent)) "accepted" else "candidate"
  } else if (is.null(incumbent)) {
    "unavailable"
  } else {
    "revision_blocked"
  }
  candidate <- phase16_euro_cli_suppress_candidate_rows(candidate)
  if (phase16_euro_cli_scalar(candidate$candidate_status) %in% c("unavailable", "unresolved", "unsupported_topology", "revision_blocked")) {
    candidate <- phase16_euro_attach_manifest(candidate)
  }
  candidate <- phase16_euro_cli_refresh_manifest(candidate, candidate$payload)
  validation <- phase16_validate_euro_outcomes_bundle(candidate)
  list(
    candidate = candidate,
    simulation = simulation,
    activation_validation = activation_validation,
    validation = validation,
    validation_failure_reason = validation$failure_reason
  )
}

phase16_euro_build_candidate <- phase16_euro_cli_build_candidate

phase16_euro_cli_candidate <- function(value) {
  if (is.list(value) && !is.null(value$candidate)) value$candidate else value
}

phase16_euro_cli_replay_fingerprint <- function(value) {
  candidate <- phase16_euro_cli_candidate(value)
  artifacts <- candidate$artifacts %||% candidate$outcomes_artifacts
  expected <- phase16_euro_outcomes_expected_inventory()
  bytes <- lapply(expected, function(path) phase16_euro_csv_bytes(artifacts[[path]]))
  names(bytes) <- expected
  hashes <- vapply(bytes, phase16_euro_cli_hash_bytes, character(1))
  sizes <- vapply(bytes, length, integer(1))
  manifest <- artifacts[["outcomes/outcomes_manifest.csv"]]
  lineage_fields <- c(
    "source_bundle_id", "source_bundle_sha256", "ruleset_version", "ruleset_sha256",
    "model_release_id", "model_id", "model_sha256", "calibrator_id", "calibrator_sha256",
    "model_data_cutoff", "feature_cutoff_sha256", "simulation_seed", "simulation_count",
    "projection_run_id", "draw_policy_id", "draw_policy_sha256", "state_manifest_sha256"
  )
  lineage <- setNames(lapply(lineage_fields, function(field) {
    if (field %in% names(manifest)) phase16_euro_cli_manifest_rows(manifest, field) else phase16_euro_cli_scalar(candidate[[field]])
  }), lineage_fields)
  list(
    artifact_bytes = bytes,
    artifact_hashes = hashes,
    artifact_sizes = sizes,
    manifest_hash = phase16_euro_cli_manifest_rows(manifest, "manifest_sha256"),
    manifest_parent_hashes = as.character(manifest$parent_sha256),
    lineage = lineage,
    candidate_status = phase16_euro_cli_scalar(candidate$candidate_status),
    activation_status = phase16_euro_cli_scalar(candidate$activation_status),
    forecast_status = phase16_euro_cli_scalar(candidate$forecast_status),
    reason = phase16_euro_cli_scalar(candidate$reason),
    payload = candidate$payload
  )
}

phase16_euro_replay_mismatch <- function(type, label, detail) {
  condition <- structure(
    list(message = sprintf("%s replay mismatch [%s]: %s", label, type, detail), type = type, label = label, detail = detail),
    class = c("phase16_euro_replay_mismatch", "error", "condition")
  )
  stop(condition)
}

phase16_euro_compare_replays <- function(first, second, label = "replay") {
  left <- phase16_euro_cli_replay_fingerprint(first)
  right <- phase16_euro_cli_replay_fingerprint(second)
  if (!identical(names(left$artifact_bytes), names(right$artifact_bytes))) {
    phase16_euro_replay_mismatch("inventory", label, "artifact inventory changed")
  }
  for (path in names(left$artifact_bytes)) {
    if (!identical(left$artifact_bytes[[path]], right$artifact_bytes[[path]])) {
      phase16_euro_replay_mismatch("artifact_bytes", label, path)
    }
    if (!identical(left$artifact_hashes[[path]], right$artifact_hashes[[path]])) {
      phase16_euro_replay_mismatch("artifact_hash", label, path)
    }
  }
  if (!identical(left$lineage, right$lineage)) {
    changed <- names(left$lineage)[!vapply(names(left$lineage), function(field) identical(left$lineage[[field]], right$lineage[[field]]), logical(1))]
    phase16_euro_replay_mismatch("lineage", label, paste(changed, collapse = ","))
  }
  if (!identical(left$manifest_parent_hashes, right$manifest_parent_hashes)) {
    phase16_euro_replay_mismatch("manifest_parent_hashes", label, "manifest parent graph changed")
  }
  for (field in c("candidate_status", "activation_status", "forecast_status", "reason", "payload")) {
    if (!identical(left[[field]], right[[field]])) phase16_euro_replay_mismatch(field, label, field)
  }
  list(identical = TRUE, differences = character(), fingerprint = left)
}

phase16_euro_cli_fresh_replay <- function(loaded, options, normal) {
  probe_paths <- vapply(seq_len(2L), function(index) {
    tempfile(sprintf("phase16-euro-replay-%d-", index), fileext = ".rds")
  }, character(1))
  on.exit(unlink(probe_paths, force = TRUE), add = TRUE)
  rscript <- file.path(R.home("bin"), "Rscript")
  script <- file.path(phase16_euro_cli_project_root, "scripts/build_euro_qualifying_outcomes.R")
  for (path in probe_paths) {
    status <- system2(
      rscript,
      c(
        "--vanilla", script,
        "--edition-id", phase16_euro_edition_id(),
        "--dry-run", "--replay-probe", path
      ),
      stdout = TRUE,
      stderr = TRUE
    )
    exit_status <- attr(status, "status") %||% 0L
    if (!identical(as.integer(exit_status), 0L) || !file.exists(path)) {
      phase16_euro_cli_fail(paste0("fresh child-process EURO replay failed: ", paste(status, collapse = "\n")))
    }
  }
  first <- readRDS(probe_paths[[1L]])
  second <- readRDS(probe_paths[[2L]])
  if (!identical(first, second)) phase16_euro_replay_mismatch("fresh_process", "fresh child replay", "two child fingerprints differ")
  normal_fingerprint <- phase16_euro_cli_replay_fingerprint(normal)
  if (!identical(first$artifact_hashes, normal_fingerprint$artifact_hashes) ||
      !identical(first$lineage, normal_fingerprint$lineage) ||
      !identical(first$manifest_parent_hashes, normal_fingerprint$manifest_parent_hashes)) {
    phase16_euro_replay_mismatch("fresh_process", "fresh child replay", "child fingerprint differs from normal candidate")
  }
  list(verified = TRUE, first = first, second = second)
}

phase16_euro_cli_read_incumbent <- function(project_root) {
  root <- phase16_euro_registered_outcomes_root(project_root)
  manifest_path <- file.path(root, "outcomes_manifest.csv")
  if (!file.exists(manifest_path)) return(NULL)
  tryCatch(
    phase16_read_euro_outcomes_bundle(output_root = root, project_root = project_root, validate = TRUE),
    error = function(error) NULL
  )
}

phase16_euro_cli_incumbent_overlay <- function(incumbent, validation, candidate) {
  warning <- "Refresh blocked — showing the last accepted EURO snapshot"
  list(
    accepted_bundle = incumbent,
    candidate = NULL,
    candidate_isolated = TRUE,
    revision_status = "revision_blocked",
    revision_warning = warning,
    warning = warning,
    revision_failure_reason = validation$failure_reason %||% candidate$reason,
    durable_mutation = FALSE
  )
}

phase16_build_euro_qualifying_outcomes_main <- function(
    args = commandArgs(trailingOnly = TRUE),
    project_root = phase16_euro_cli_project_root,
    input_loader_fn = phase16_euro_default_inputs,
    build_candidate_fn = phase16_euro_cli_build_candidate) {
  options <- phase16_euro_cli_parse_args(args)
  if (isTRUE(options$help)) {
    return(list(help = TRUE, usage = phase16_euro_cli_usage(), durable_mutation = FALSE))
  }
  project_root <- normalizePath(project_root, winslash = "/", mustWork = TRUE)
  rng_before <- if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) get(".Random.seed", envir = .GlobalEnv) else NULL
  had_rng <- !is.null(rng_before)
  on.exit({
    if (had_rng) assign(".Random.seed", rng_before, envir = .GlobalEnv)
    else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) rm(".Random.seed", envir = .GlobalEnv)
  }, add = TRUE)
  loaded <- do.call(input_loader_fn, list(edition_id = options$edition_id, project_root = project_root))
  if (!is.list(loaded)) phase16_euro_cli_fail("EURO CLI input loader must return a list")
  loaded$project_root <- project_root
  loaded$edition_id <- options$edition_id
  incumbent <- phase16_euro_cli_read_incumbent(project_root)
  loaded$incumbent <- incumbent
  normal <- build_candidate_fn(loaded, options)
  result <- list(
    edition_id = options$edition_id,
    mode = options$mode,
    simulations = options$simulations,
    seed = options$seed,
    candidate = normal$candidate,
    simulation = normal$simulation,
    activation_validation = normal$activation_validation,
    validation = isTRUE(normal$validation$valid),
    validation_failure_reason = normal$validation$failure_reason,
    source_validation = isTRUE(normal$activation_validation$valid),
    durable_mutation = FALSE,
    incumbent_present = !is.null(incumbent),
    payload = normal$candidate$payload
  )
  if (identical(options$mode, "replay")) {
    reversed_loaded <- phase16_euro_cli_reverse_value(loaded)
    reversed_loaded$project_root <- project_root
    reversed_loaded$edition_id <- options$edition_id
    reversed_loaded$incumbent <- incumbent
    reversed <- build_candidate_fn(reversed_loaded, options)
    repeated <- build_candidate_fn(loaded, options)
    phase16_euro_compare_replays(normal, reversed, label = "reversed-input")
    phase16_euro_compare_replays(normal, repeated, label = "repeated")
    fresh <- phase16_euro_cli_fresh_replay(loaded, options, normal)
    result$reversed <- reversed
    result$repeated <- repeated
    result$fresh_process <- fresh
    result$replay <- list(verified = TRUE, normal = phase16_euro_cli_replay_fingerprint(normal), reversed = phase16_euro_cli_replay_fingerprint(reversed), repeated = phase16_euro_cli_replay_fingerprint(repeated), fresh_process = fresh)
    result$replay_verified <- TRUE
  }
  if (identical(options$mode, "write")) {
    if (!isTRUE(normal$activation_validation$valid) && !is.null(incumbent)) {
      result <- c(result, phase16_euro_cli_incumbent_overlay(incumbent, normal$activation_validation, normal$candidate))
      result$candidate <- NULL
      result$simulation <- NULL
      result$payload <- normal$candidate$payload
    } else {
      if (!isTRUE(normal$validation$valid)) {
        phase16_euro_cli_fail(paste0("EURO outcomes candidate is not validated: ", normal$validation$failure_reason))
      }
      written <- phase16_write_euro_outcomes_bundle(
        normal$candidate,
        output_root = phase16_euro_registered_outcomes_root(project_root),
        project_root = project_root
      )
      result$written <- written
      result$durable_mutation <- TRUE
      result$accepted_bundle <- written
    }
  }
  if (!is.null(options$replay_probe)) {
    dir.create(dirname(options$replay_probe), recursive = TRUE, showWarnings = FALSE)
    saveRDS(phase16_euro_cli_replay_fingerprint(normal), options$replay_probe)
  }
  result
}

phase16_euro_cli_print_result <- function(result) {
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
  cat(sprintf("source_validation=%s\n", if (isTRUE(result$source_validation)) "TRUE" else "FALSE"))
  cat(sprintf("durable_mutation=%s\n", if (isTRUE(result$durable_mutation)) "TRUE" else "FALSE"))
  if (isTRUE(result$replay_verified)) cat("replay_verified=TRUE\n")
  if (!is.null(result$written)) cat(sprintf("written_root=%s\n", result$written$written_root))
  if (!is.null(result$revision_warning)) cat(sprintf("revision_warning=%s\n", result$revision_warning))
  if (!is.null(result$revision_failure_reason)) cat(sprintf("revision_failure_reason=%s\n", result$revision_failure_reason))
  if (!is.null(result$payload)) {
    cat(sprintf("forecast_status=%s\n", result$candidate$forecast_status))
    cat(sprintf("source_bundle_id=%s\n", result$payload$source_bundle_id))
    cat(sprintf("forecast_reason=%s\n", result$payload$forecast_reason))
  }
  invisible(TRUE)
}

phase16_euro_cli_direct_invocation <- identical(phase16_euro_cli_environment, .GlobalEnv) &&
  !interactive() &&
  identical(basename(phase16_euro_cli_script_path), "build_euro_qualifying_outcomes.R") &&
  any(grepl("^--file=", phase16_euro_cli_command_args))
if (isTRUE(phase16_euro_cli_direct_invocation)) {
  phase16_euro_cli_result <- phase16_build_euro_qualifying_outcomes_main()
  phase16_euro_cli_print_result(phase16_euro_cli_result)
}
