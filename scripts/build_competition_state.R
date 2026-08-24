#!/usr/bin/env Rscript

# Fixed before any dependency or injectable callback is sourced.  The state
# batch itself is deterministic, but keeping the seed at this entrypoint makes
# any future stochastic callback replay-safe as well.
set.seed(14017L)

phase14_build_competition_state_command_args <- commandArgs(trailingOnly = FALSE)
phase14_build_competition_state_script_arg <- phase14_build_competition_state_command_args[
  grepl("^--file=", phase14_build_competition_state_command_args)
]
phase14_build_competition_state_source_file <- tryCatch(
  sys.frame(1L)$ofile,
  error = function(error) NULL
)
phase14_build_competition_state_script_candidates <- c(
  if (length(phase14_build_competition_state_script_arg)) sub("^--file=", "", phase14_build_competition_state_script_arg[[1L]]) else character(),
  if (!is.null(phase14_build_competition_state_source_file)) as.character(phase14_build_competition_state_source_file) else character(),
  file.path(getwd(), "scripts/build_competition_state.R")
)
phase14_build_competition_state_search_root <- normalizePath(getwd(), winslash = "/", mustWork = FALSE)
repeat {
  phase14_build_competition_state_script_candidates <- c(
    phase14_build_competition_state_script_candidates,
    file.path(phase14_build_competition_state_search_root, "scripts/build_competition_state.R")
  )
  phase14_build_competition_state_parent <- dirname(phase14_build_competition_state_search_root)
  if (identical(phase14_build_competition_state_parent, phase14_build_competition_state_search_root)) break
  phase14_build_competition_state_search_root <- phase14_build_competition_state_parent
}
phase14_build_competition_state_script_candidates <- phase14_build_competition_state_script_candidates[
  !is.na(phase14_build_competition_state_script_candidates) & nzchar(phase14_build_competition_state_script_candidates)
]
phase14_build_competition_state_script_file <- phase14_build_competition_state_script_candidates[
  vapply(phase14_build_competition_state_script_candidates, file.exists, logical(1))
][1L]
if (is.na(phase14_build_competition_state_script_file) || !nzchar(phase14_build_competition_state_script_file)) {
  stop("Phase 14 state build entrypoint could not resolve its script path", call. = FALSE)
}
phase14_build_competition_state_script_file <- normalizePath(
  phase14_build_competition_state_script_file,
  winslash = "/",
  mustWork = TRUE
)
phase14_build_competition_state_project_root <- normalizePath(
  file.path(dirname(phase14_build_competition_state_script_file), ".."),
  winslash = "/",
  mustWork = TRUE
)
phase14_build_competition_state_script_environment <- environment()

phase14_build_competition_state_source_if_missing <- function(path, symbol) {
  if (exists(symbol, envir = phase14_build_competition_state_script_environment, inherits = FALSE)) {
    return(invisible(TRUE))
  }
  dependency <- file.path(phase14_build_competition_state_project_root, path)
  if (!file.exists(dependency)) stop("Phase 14 state build dependency is missing: ", path, call. = FALSE)
  sys.source(dependency, envir = phase14_build_competition_state_script_environment)
  if (!exists(symbol, envir = phase14_build_competition_state_script_environment, inherits = FALSE)) {
    stop("Phase 14 state build dependency did not define: ", symbol, call. = FALSE)
  }
  invisible(TRUE)
}

phase14_build_competition_state_source_if_missing(
  "R/competition/forecast_layer.R",
  "phase14_build_fixture_forecasts"
)
phase14_build_competition_state_source_if_missing(
  "R/competition/uefa_euro_rules.R",
  "validate_euro_activation"
)
phase14_build_competition_state_source_if_missing(
  "R/competition/state_bundle.R",
  "phase14_build_competition_state_batch"
)

phase14_build_competition_state_parse_args <- function(args) {
  output <- list(edition_id = NULL, dry_run = FALSE, replay_check = FALSE, help = FALSE)
  index <- 1L
  while (index <= length(args)) {
    token <- as.character(args[[index]])
    if (!startsWith(token, "--")) stop("Phase 14 state build argument must start with --: ", token, call. = FALSE)
    key <- sub("^--", "", token)
    key <- gsub("_", "-", key, fixed = TRUE)
    if (identical(key, "dry-run")) {
      output$dry_run <- TRUE
      index <- index + 1L
      next
    }
    if (identical(key, "replay-check")) {
      output$replay_check <- TRUE
      output$dry_run <- TRUE
      index <- index + 1L
      next
    }
    if (identical(key, "help")) {
      output$help <- TRUE
      index <- index + 1L
      next
    }
    if (identical(key, "edition-id")) {
      if (index == length(args)) stop("Phase 14 state build option requires a value: --edition-id", call. = FALSE)
      output$edition_id <- as.character(args[[index + 1L]])
      index <- index + 2L
      next
    }
    stop("Unsupported Phase 14 state build option: --", key, call. = FALSE)
  }
  if (!isTRUE(output$help) && (is.null(output$edition_id) || !length(output$edition_id) || is.na(output$edition_id) || !nzchar(output$edition_id))) {
    stop("Phase 14 state build requires --edition-id <edition_id|both>", call. = FALSE)
  }
  output
}

phase14_build_competition_state_reverse_inputs <- function(loaded) {
  if (!is.list(loaded)) return(loaded)
  reversed <- loaded
  for (name in names(reversed)) {
    value <- reversed[[name]]
    if (is.data.frame(value) && nrow(value) > 1L) {
      reversed[[name]] <- value[rev(seq_len(nrow(value))), , drop = FALSE]
    }
  }
  reversed
}

phase14_build_competition_state_run <- function(
    ids,
    loaded,
    registry,
    build_batch_fn,
    validate_fn) {
  build_arguments <- loaded
  build_arguments$edition_id <- ids
  build_arguments$edition_registry <- build_arguments$edition_registry %||% registry
  batch <- phase14_build_competition_state_call(build_batch_fn, build_arguments)
  validation <- phase14_build_competition_state_call(validate_fn, list(bundle = batch))
  if (!isTRUE(validation)) stop("Phase 14 state replay validation did not return TRUE", call. = FALSE)
  list(batch = batch, validation = validation)
}

phase14_build_competition_state_replay_summary <- function(batch) {
  candidates <- lapply(batch$edition_ids, function(edition_id) {
    candidate <- batch$candidates[[edition_id]]
    artifacts <- candidate$state_artifacts
    list(
      state_manifest_sha256 = as.character(candidate$state_manifest_sha256),
      canonical_matches_sha256 = phase14_state_bundle_hash_value(artifacts[["state/canonical_matches.csv"]]),
      forecast_status_sha256 = phase14_state_bundle_hash_value(artifacts[["state/forecast_status.csv"]]),
      forecasts_sha256 = phase14_state_bundle_hash_value(artifacts[["state/forecasts.csv"]]),
      score_distributions_sha256 = phase14_state_bundle_hash_value(artifacts[["local/score_distributions.rds"]]),
      top10_sha256 = phase14_state_bundle_hash_value(artifacts[["state/forecast_top10.csv"]]),
      artifact_inventory = as.character(candidate$state_manifest$artifact_path),
      source_fixture_ids = as.character(candidate$input_fixture_ids %||% character()),
      output_fixture_ids = as.character(phase14_state_bundle_fixture_ids(artifacts[["state/canonical_matches.csv"]], "replay output")),
      status_fixture_ids = as.character(phase14_state_bundle_ids_from_status(artifacts[["state/forecast_status.csv"]]))
    )
  })
  names(candidates) <- batch$edition_ids
  list(
    edition_ids = batch$edition_ids,
    batch_sha256 = as.character(batch$batch_sha256),
    batch_manifest = batch$batch_manifest,
    candidates = candidates
  )
}

phase14_build_competition_state_compare_replays <- function(first, second, label) {
  first_summary <- phase14_build_competition_state_replay_summary(first)
  second_summary <- phase14_build_competition_state_replay_summary(second)
  if (!identical(first_summary$edition_ids, second_summary$edition_ids) ||
      !identical(first_summary$batch_sha256, second_summary$batch_sha256) ||
      !identical(first_summary$batch_manifest, second_summary$batch_manifest)) {
    stop("Phase 14 ", label, " replay changed the batch manifest or hash", call. = FALSE)
  }
  for (edition_id in first_summary$edition_ids) {
    left <- first_summary$candidates[[edition_id]]
    right <- second_summary$candidates[[edition_id]]
    if (!identical(left, right)) {
      stop("Phase 14 ", label, " replay changed the edition artifact or fixture inventory: ", edition_id, call. = FALSE)
    }
  }
  invisible(TRUE)
}

phase14_build_competition_state_read_csv <- function(path, required = FALSE) {
  if (!file.exists(path)) {
    if (isTRUE(required)) stop("Phase 14 state build input is missing: ", path, call. = FALSE)
    return(NULL)
  }
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
}

phase14_build_competition_state_bind_edition <- function(value, edition_id) {
  if (is.null(value)) return(NULL)
  if (!is.data.frame(value)) stop("Phase 14 state build edition input must be a data frame", call. = FALSE)
  if (!"edition_id" %in% names(value)) value$edition_id <- edition_id
  value
}

phase14_build_competition_state_load_resource <- function(project_root, edition_id, resource) {
  path <- file.path(project_root, "data/competition/accepted", edition_id, paste0(resource, ".csv"))
  phase14_build_competition_state_bind_edition(
    phase14_build_competition_state_read_csv(path),
    edition_id
  )
}

phase14_build_competition_state_default_inputs <- function(edition_ids, project_root) {
  registry_root <- file.path(project_root, "data/competition/registries")
  edition_registry <- phase14_build_competition_state_read_csv(
    file.path(registry_root, "competition_editions.csv"),
    required = TRUE
  )
  identity <- phase14_build_competition_state_read_csv(
    file.path(registry_root, "team_identity.csv"),
    required = TRUE
  )
  canonical_matches <- do.call(rbind, lapply(edition_ids, function(id) {
    value <- phase14_build_competition_state_load_resource(project_root, id, "fixtures")
    if (is.null(value)) return(data.frame(stringsAsFactors = FALSE, check.names = FALSE))
    value
  }))
  if (is.null(canonical_matches)) canonical_matches <- data.frame(stringsAsFactors = FALSE, check.names = FALSE)
  source_bundle_manifest <- do.call(rbind, lapply(edition_ids, function(id) {
    value <- phase14_build_competition_state_read_csv(
      file.path(project_root, "data/competition/accepted", id, "source_bundle_manifest.csv")
    )
    if (is.null(value)) data.frame(stringsAsFactors = FALSE, check.names = FALSE) else value
  }))
  if (is.null(source_bundle_manifest)) source_bundle_manifest <- data.frame(stringsAsFactors = FALSE, check.names = FALSE)
  source_status <- do.call(rbind, lapply(edition_ids, function(id) {
    value <- phase14_build_competition_state_load_resource(project_root, id, "status")
    if (is.null(value)) data.frame(stringsAsFactors = FALSE, check.names = FALSE) else value
  }))
  if (is.null(source_status)) source_status <- data.frame(stringsAsFactors = FALSE, check.names = FALSE)
  list(
    edition_registry = edition_registry,
    canonical_matches = canonical_matches,
    team_registry = identity,
    resolved_release = phase14_resolve_approved_release(
      file.path(project_root, "outputs/releases/approved_release.csv"),
      file.path(project_root, "outputs/releases")
    ),
    selector_path = file.path(project_root, "outputs/releases/approved_release.csv"),
    trusted_release_root = file.path(project_root, "outputs/releases"),
    elo_ratings = phase14_build_competition_state_read_csv(
      file.path(project_root, "data/processed/elo_ratings.csv"), required = TRUE
    ),
    national_team_xg_registry = file.path(registry_root, "national_team_xg_sources.csv"),
    source_bundle_manifest = source_bundle_manifest,
    source_status = source_status,
    model_manifest_path = file.path(
      project_root,
      "outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen/manifests/model_manifests.csv"
    ),
    results = do.call(rbind, lapply(edition_ids, function(id) {
      value <- phase14_build_competition_state_load_resource(project_root, id, "results")
      if (is.null(value)) data.frame(stringsAsFactors = FALSE, check.names = FALSE) else value
    })),
    groups = do.call(rbind, lapply(edition_ids, function(id) {
      value <- phase14_build_competition_state_load_resource(project_root, id, "groups")
      if (is.null(value)) data.frame(stringsAsFactors = FALSE, check.names = FALSE) else value
    })),
    standings = do.call(rbind, lapply(edition_ids, function(id) {
      value <- phase14_build_competition_state_load_resource(project_root, id, "standings")
      if (is.null(value)) data.frame(stringsAsFactors = FALSE, check.names = FALSE) else value
    }))
  )
}

phase14_build_competition_state_call <- function(callback, arguments) {
  if (!is.function(callback)) stop("Phase 14 state build callback must be a function", call. = FALSE)
  formal_names <- names(formals(callback))
  if (!"..." %in% formal_names) arguments <- arguments[names(arguments) %in% formal_names]
  do.call(callback, arguments)
}

phase14_build_competition_state_main <- function(
    args = commandArgs(trailingOnly = TRUE),
    project_root = phase14_build_competition_state_project_root,
    input_loader_fn = phase14_build_competition_state_default_inputs,
    build_batch_fn = phase14_build_competition_state_script_environment$phase14_build_competition_state_batch,
    validate_fn = phase14_validate_competition_state_bundle) {
  options <- phase14_build_competition_state_parse_args(args)
  if (isTRUE(options$help)) {
    return(list(
      help = TRUE,
      usage = "Rscript scripts/build_competition_state.R --edition-id <edition_id|both> [--dry-run|--replay-check]",
      seed = 14017L
    ))
  }
  project_root <- normalizePath(project_root, winslash = "/", mustWork = TRUE)
  registry_path <- file.path(project_root, "data/competition/registries/competition_editions.csv")
  registry <- phase14_build_competition_state_read_csv(registry_path, required = TRUE)
  ids <- if (identical(tolower(options$edition_id), "both")) {
    phase14_state_bundle_default_edition_ids(registry)
  } else {
    as.character(options$edition_id)
  }
  loaded <- phase14_build_competition_state_call(
    input_loader_fn,
    list(edition_ids = ids, project_root = project_root)
  )
  if (!is.list(loaded)) stop("Phase 14 state build input loader must return a list", call. = FALSE)
  normal <- phase14_build_competition_state_run(ids, loaded, registry, build_batch_fn, validate_fn)
  if (isTRUE(options$replay_check)) {
    reversed <- phase14_build_competition_state_run(
      rev(ids),
      phase14_build_competition_state_reverse_inputs(loaded),
      registry,
      build_batch_fn,
      validate_fn
    )
    repeated <- phase14_build_competition_state_run(ids, loaded, registry, build_batch_fn, validate_fn)
    phase14_build_competition_state_compare_replays(normal$batch, reversed$batch, "reversed-input")
    phase14_build_competition_state_compare_replays(normal$batch, repeated$batch, "repeated")
    return(list(
      dry_run = TRUE,
      replay_check = TRUE,
      seed = 14017L,
      edition_ids = normal$batch$edition_ids,
      options = options,
      batch = normal$batch,
      validation = normal$validation,
      replay = list(
        verified = TRUE,
        normal = phase14_build_competition_state_replay_summary(normal$batch),
        reversed = phase14_build_competition_state_replay_summary(reversed$batch),
        repeated = phase14_build_competition_state_replay_summary(repeated$batch)
      ),
      durable_mutation = FALSE
    ))
  }
  batch <- normal$batch
  validation <- normal$validation
  list(
    dry_run = isTRUE(options$dry_run),
    replay_check = FALSE,
    seed = 14017L,
    edition_ids = ids,
    options = options,
    batch = batch,
    validation = validation,
    durable_mutation = FALSE
  )
}

# `sys.source()` is the supported embedding mode used by tests and later
# orchestration.  Only an actual Rscript invocation runs the command entrypoint.
phase14_build_competition_state_direct <- identical(environment(), .GlobalEnv) &&
  !interactive() &&
  any(grepl("^--file=", phase14_build_competition_state_command_args))
if (isTRUE(phase14_build_competition_state_direct)) {
  phase14_build_competition_state_result <- phase14_build_competition_state_main()
  if (!isTRUE(phase14_build_competition_state_result$help) &&
      !isTRUE(phase14_build_competition_state_result$validation)) {
    quit(save = "no", status = 1L, runLast = FALSE)
  }
}
