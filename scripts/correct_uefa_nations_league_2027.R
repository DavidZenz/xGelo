#!/usr/bin/env Rscript

# Correct the active Nations League source bundle from the official UEFA
# match endpoint.  The runner stages the complete accepted/source/identity/
# match graph and promotes only explicit targets after every contract has
# passed.  It intentionally has no local JSON replay option: production
# provenance must be reproducible from UEFA's endpoint.

phase14_uefa_correction_args <- commandArgs(trailingOnly = TRUE)
phase14_uefa_correction_file_args <- commandArgs(trailingOnly = FALSE)
phase14_uefa_correction_file <- sub(
  "^--file=",
  "",
  phase14_uefa_correction_file_args[grepl("^--file=", phase14_uefa_correction_file_args)][1L]
)
if (is.na(phase14_uefa_correction_file) || !nzchar(phase14_uefa_correction_file) || !file.exists(phase14_uefa_correction_file)) {
  phase14_uefa_correction_file <- file.path(getwd(), "scripts/correct_uefa_nations_league_2027.R")
}
phase14_uefa_correction_file <- normalizePath(phase14_uefa_correction_file, winslash = "/", mustWork = TRUE)
phase14_uefa_correction_project_root <- normalizePath(file.path(dirname(phase14_uefa_correction_file), ".."), winslash = "/", mustWork = TRUE)
source(file.path(phase14_uefa_correction_project_root, "R/competition/source_contracts.R"))
source(file.path(phase14_uefa_correction_project_root, "R/competition/team_identity.R"))
source(file.path(phase14_uefa_correction_project_root, "R/competition/uefa_nations_league_adapter.R"))
source(file.path(phase14_uefa_correction_project_root, "R/competition/edition_registry.R"))
source(file.path(phase14_uefa_correction_project_root, "R/release/release_contract.R"))

phase14_uefa_correction_parse_args <- function(args) {
  output <- list(
    dry_run = FALSE,
    operator = "codex",
    bundle_id = phase14_uefa_nl_bundle_id(),
    refresh_batch_id = "refresh-20260817-uefa-official-v2",
    matches_url = phase14_uefa_nl_matches_url(),
    api_key = NULL
  )
  index <- 1L
  while (index <= length(args)) {
    token <- args[[index]]
    if (identical(token, "--dry-run")) {
      output$dry_run <- TRUE
      index <- index + 1L
      next
    }
    if (!startsWith(token, "--") || index == length(args)) {
      stop("Unsupported UEFA correction argument: ", token, call. = FALSE)
    }
    key <- sub("^--", "", token)
    value <- args[[index + 1L]]
    if (key %in% c("operator", "bundle-id", "refresh-batch-id", "uefa-matches-url", "uefa-api-key")) {
      if (identical(key, "operator")) output$operator <- value
      if (identical(key, "bundle-id")) output$bundle_id <- value
      if (identical(key, "refresh-batch-id")) output$refresh_batch_id <- value
      if (identical(key, "uefa-matches-url")) output$matches_url <- value
      if (identical(key, "uefa-api-key")) output$api_key <- value
      index <- index + 2L
      next
    }
    stop("Unsupported UEFA correction argument: --", key, call. = FALSE)
  }
  output
}

phase14_uefa_correction_copy_tree <- function(source, target) {
  if (!dir.exists(source)) stop("UEFA correction source directory is missing: ", source, call. = FALSE)
  dir.create(target, recursive = TRUE, showWarnings = FALSE)
  entries <- list.files(source, all.files = TRUE, full.names = TRUE, no.. = TRUE)
  for (entry in entries) {
    destination <- file.path(target, basename(entry))
    if (dir.exists(entry)) {
      phase14_uefa_correction_copy_tree(entry, destination)
    } else if (!file.copy(entry, destination, overwrite = TRUE)) {
      stop("UEFA correction could not stage: ", entry, call. = FALSE)
    }
  }
  invisible(target)
}

phase14_uefa_correction_read_csv <- function(path) {
  if (!file.exists(path)) stop("UEFA correction registry file is missing: ", path, call. = FALSE)
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
}

phase14_uefa_correction_stage_roots <- function(project_root) {
  competition_root <- file.path(project_root, "data/competition")
  stage_root <- tempfile(".phase14-uefa-correction-stage-", tmpdir = competition_root)
  dir.create(stage_root, recursive = TRUE, showWarnings = FALSE)
  phase14_uefa_correction_copy_tree(
    file.path(competition_root, "accepted"),
    file.path(stage_root, "data/competition/accepted")
  )
  phase14_uefa_correction_copy_tree(
    file.path(competition_root, "registries"),
    file.path(stage_root, "data/competition/registries")
  )
  phase14_uefa_correction_copy_tree(
    file.path(competition_root, "local_raw"),
    file.path(stage_root, "data/competition/local_raw")
  )
  stage_root
}

phase14_uefa_correction_update_edition <- function(
    editions,
    edition_id,
    bundle_id,
    accepted_at_utc,
    operator) {
  index <- match(edition_id, as.character(editions$edition_id))
  if (is.na(index)) stop("UEFA correction edition is not registered: ", edition_id, call. = FALSE)
  row <- editions[index, , drop = FALSE]
  row$source_bundle_id <- bundle_id
  row$active_output_bundle_id <- bundle_id
  row$last_accepted_output_bundle_id <- bundle_id
  row$blocked <- FALSE
  row$blocked_refresh_batch_id <- ""
  row$blocked_reason <- ""
  row$blocked_at_utc <- ""
  row$last_refresh_failure <- ""
  row$last_refresh_failure_at_utc <- ""
  row$audit_event <- "refresh_accepted"
  row$audit_at_utc <- accepted_at_utc
  row$operator <- operator
  row$registry_revision <- as.integer(row$registry_revision[[1L]]) + 1L
  row$row_sha256 <- phase13_registry_row_hash(row)
  editions[index, names(row)] <- row
  editions$row_sha256 <- phase13_row_sha256(editions)
  editions
}

phase14_uefa_correction_stage_refresh_history <- function(
    registry_root,
    edition_id,
    refresh_batch_id,
    candidate,
    edition_row,
    operator,
    operator_action,
    phase13) {
  history_path <- file.path(registry_root, "refresh_batches", edition_id, "status_history.csv")
  history <- phase13$read_history(history_path)
  phase13$validate_history(history, edition_id, file.path(registry_root, "refresh_batches"))
  if (any(as.character(history$refresh_batch_id) == refresh_batch_id)) {
    stop("UEFA correction refresh batch already exists: ", refresh_batch_id, call. = FALSE)
  }
  event <- phase13$build_history_row(
    edition_id = edition_id,
    refresh_batch_id = refresh_batch_id,
    event_index = if (nrow(history)) max(as.integer(history$event_index)) + 1L else 1L,
    status = "accepted",
    event_at_utc = as.character(candidate$bundle$accepted_at_utc[[1L]]),
    candidate_bundle_id = as.character(candidate$bundle$bundle_id[[1L]]),
    last_accepted_bundle_id = as.character(candidate$bundle$bundle_id[[1L]]),
    last_accepted_output_bundle_id = as.character(candidate$bundle$bundle_id[[1L]]),
    registry_revision = as.integer(edition_row$registry_revision[[1L]]),
    operator = operator,
    operator_action = operator_action,
    validation_passed = TRUE,
    record_relative_path = ""
  )
  history <- rbind(history, event)
  phase13$validate_history(history, edition_id, file.path(registry_root, "refresh_batches"))
  phase13$write_csv(history, history_path)
  invisible(history)
}

phase14_uefa_correction_atomic_promote <- function(stage_root, project_root, bundle_id) {
  competition_root <- file.path(project_root, "data/competition")
  stage_competition_root <- file.path(stage_root, "data/competition")
  edition_id <- phase14_uefa_nl_edition_id()
  relative_targets <- c(
    file.path("accepted", edition_id),
    file.path("registries", "source_artifacts.csv"),
    file.path("registries", "source_bundles.csv"),
    file.path("registries", "team_identity.csv"),
    file.path("registries", "competition_editions.csv"),
    file.path("registries", "match_identity.csv"),
    file.path("registries", "refresh_batches", edition_id, "status_history.csv"),
    file.path("local_raw", edition_id, bundle_id)
  )
  stage_targets <- file.path(stage_competition_root, relative_targets)
  target_paths <- file.path(competition_root, relative_targets)
  if (any(!vapply(stage_targets, function(path) file.exists(path) || dir.exists(path), logical(1)))) {
    stop("UEFA correction staging graph is incomplete", call. = FALSE)
  }
  lock_path <- file.path(competition_root, ".phase14-uefa-correction.lock")
  if (file.exists(lock_path)) stop("UEFA correction publication lock already exists", call. = FALSE)
  if (!file.create(lock_path)) stop("UEFA correction could not acquire its publication lock", call. = FALSE)
  on.exit(if (file.exists(lock_path)) unlink(lock_path), add = TRUE)
  backup_root <- tempfile(".phase14-uefa-correction-backup-", tmpdir = competition_root)
  dir.create(backup_root, recursive = TRUE, showWarnings = FALSE)
  backed_up <- setNames(logical(length(target_paths)), relative_targets)
  promoted <- setNames(logical(length(target_paths)), relative_targets)
  rollback <- function() {
    for (index in rev(seq_along(target_paths))) {
      target <- target_paths[[index]]
      if (isTRUE(promoted[[index]]) && (file.exists(target) || dir.exists(target))) {
        unlink(target, recursive = TRUE, force = TRUE)
      }
    }
    for (index in seq_along(target_paths)) {
      backup <- file.path(backup_root, relative_targets[[index]])
      if (isTRUE(backed_up[[index]]) && (file.exists(backup) || dir.exists(backup)) &&
          !file.exists(target_paths[[index]]) && !dir.exists(target_paths[[index]])) {
        dir.create(dirname(target_paths[[index]]), recursive = TRUE, showWarnings = FALSE)
        if (!file.rename(backup, target_paths[[index]])) {
          stop("UEFA correction rollback could not restore: ", relative_targets[[index]], call. = FALSE)
        }
      }
    }
  }
  success <- FALSE
  on.exit({
    if (!success) rollback()
    if (dir.exists(backup_root)) unlink(backup_root, recursive = TRUE, force = TRUE)
  }, add = TRUE)

  for (index in seq_along(target_paths)) {
    target <- target_paths[[index]]
    if (file.exists(target) || dir.exists(target)) {
      backup <- file.path(backup_root, relative_targets[[index]])
      dir.create(dirname(backup), recursive = TRUE, showWarnings = FALSE)
      if (!file.rename(target, backup)) stop("UEFA correction could not stage previous target: ", relative_targets[[index]], call. = FALSE)
      backed_up[[index]] <- TRUE
    }
  }
  for (index in seq_along(target_paths)) {
    dir.create(dirname(target_paths[[index]]), recursive = TRUE, showWarnings = FALSE)
    if (!file.rename(stage_targets[[index]], target_paths[[index]])) {
      stop("UEFA correction could not promote target: ", relative_targets[[index]], call. = FALSE)
    }
    promoted[[index]] <- TRUE
  }
  success <- TRUE
  invisible(target_paths)
}

phase14_uefa_correction_load_acquisition <- function(project_root) {
  acquisition <- new.env(parent = globalenv())
  sys.source(file.path(project_root, "scripts/acquire_uefa_snapshot.R"), envir = acquisition)
  acquisition
}

phase14_uefa_correction_main <- function(
    args = phase14_uefa_correction_args,
    project_root = phase14_uefa_correction_project_root) {
  options <- phase14_uefa_correction_parse_args(args)
  edition_id <- phase14_uefa_nl_edition_id()
  if (!identical(as.character(options$bundle_id), phase14_uefa_nl_bundle_id())) {
    stop("The official Nations League correction uses the immutable bundle ID ", phase14_uefa_nl_bundle_id(), call. = FALSE)
  }
  acquisition <- phase14_uefa_correction_load_acquisition(project_root)
  source(file.path(project_root, "R/competition/match_state.R"), local = TRUE)
  phase13 <- list(
    capture = get("phase13_capture_structured_bundle", acquisition),
    enrich = get("phase13_acquire_enrich_candidate", acquisition),
    write_raw = get("phase13_acquire_write_raw_store", acquisition),
    validate_raw = get("phase13_acquire_validate_raw_store", acquisition),
    build_handoff = get("phase13_acquire_build_source_handoff_set", acquisition),
    publish_normalized = get("phase13_publish_normalized_editions", acquisition),
    write_csv = get("phase13_source_write_csv", acquisition),
    read_history = get("phase13_acquire_read_refresh_history", acquisition),
    validate_history = get("phase13_acquire_validate_refresh_history_table", acquisition),
    build_history_row = get("phase13_acquire_build_refresh_history_row", acquisition)
  )
  project_registry_root <- file.path(project_root, "data/competition/registries")
  project_accepted_root <- file.path(project_root, "data/competition/accepted")
  project_raw_root <- file.path(project_root, "data/competition/local_raw")
  existing_identity <- phase14_uefa_correction_read_csv(file.path(project_registry_root, "team_identity.csv"))
  stable_identity <- phase14_uefa_correction_read_csv(file.path(project_registry_root, "martj42_identity_map.csv"))
  existing_crosswalk <- phase14_uefa_correction_read_csv(file.path(project_registry_root, "match_identity.csv"))
  phase14_validate_match_identity_crosswalk(existing_crosswalk)
  if (phase14_uefa_nl_bundle_id() %in% as.character(phase14_uefa_correction_read_csv(file.path(project_registry_root, "source_bundles.csv"))$bundle_id)) {
    stop("Official UEFA Nations League bundle is already present; refusing to mutate an immutable bundle", call. = FALSE)
  }

  fetch_options <- list(
    `uefa-matches-url` = options$matches_url,
    `uefa-api-key` = options$api_key
  )
  input <- phase14_uefa_nl_live_input(
    options = fetch_options,
    fetch_fn = get("phase13_acquire_fetch_structured_url", acquisition)
  )
  if (!identical(as.character(input$official_endpoint), phase14_uefa_nl_matches_url()) &&
      !identical(as.character(options$matches_url), phase14_uefa_nl_matches_url())) {
    stop("Official UEFA Nations League correction endpoint drifted from the approved URL", call. = FALSE)
  }
  retrieved_at <- as.character(input$retrieved_at_utc)
  candidate <- phase13$capture(
    resource_payloads = input$resources,
    edition_id = edition_id,
    bundle_id = options$bundle_id,
    source_urls = input$source_urls,
    retrieved_at_utc = retrieved_at,
    fallback_status = "official",
    parser_commit_sha = get("phase13_parser_commit_sha", acquisition)(project_root),
    project_root = project_root,
    raw_bytes_by_resource = input$raw_bytes_by_resource
  )
  candidate <- phase13$enrich(
    candidate,
    source_urls = input$source_urls,
    status_provenance = "explicit",
    status_contributors = "status"
  )
  if (isTRUE(options$dry_run)) {
    message(sprintf(
      "Official UEFA Nations League dry-run valid: %s fixtures, %s groups, %s teams; raw_sha256=%s",
      input$official_counts[["fixtures"]], input$official_counts[["groups"]], input$official_counts[["teams"]],
      as.character(candidate$artifacts$raw_sha256[[1L]])
    ))
    return(invisible(candidate))
  }

  stage_root <- phase14_uefa_correction_stage_roots(project_root)
  on.exit(if (dir.exists(stage_root)) unlink(stage_root, recursive = TRUE, force = TRUE), add = TRUE)
  stage_accepted_root <- file.path(stage_root, "data/competition/accepted")
  stage_registry_root <- file.path(stage_root, "data/competition/registries")
  stage_raw_root <- file.path(stage_root, "data/competition/local_raw")
  phase13$write_raw(candidate, stage_raw_root, edition_id, options$bundle_id)
  phase13$validate_raw(candidate, stage_raw_root, edition_id)

  identity <- phase14_uefa_nl_build_identity_registry(
    official_teams = input$teams,
    stable_identity_map = stable_identity,
    bundle_id = options$bundle_id,
    existing_registry = existing_identity
  )
  source_bundles_before <- phase14_uefa_correction_read_csv(file.path(stage_registry_root, "source_bundles.csv"))
  phase13_validate_team_identity_registry(
    identity,
    source_bundles = rbind(source_bundles_before, candidate$bundle)
  )
  phase13$write_csv(identity, file.path(stage_registry_root, "team_identity.csv"))

  handoff <- phase13$build_handoff(
    candidate = candidate,
    edition_id = edition_id,
    raw_root = stage_raw_root,
    registry_root = stage_registry_root,
    project_root = stage_root
  )
  on.exit(if (dir.exists(handoff$handoff_root)) unlink(handoff$handoff_root, recursive = TRUE, force = TRUE), add = TRUE)
  # The normalized publisher reads the registry context before promoting its
  # fourteen-file graph.  Seed that context with the same candidate/companion
  # source registry that the handoff validator accepted, so the expanded
  # identity registry is never validated against the retired sample bundle.
  phase13$write_csv(
    handoff$source_registries$bundles,
    file.path(stage_registry_root, "source_bundles.csv")
  )
  phase13$write_csv(
    handoff$source_registries$artifacts,
    file.path(stage_registry_root, "source_artifacts.csv")
  )
  phase13$publish_normalized(
    output_root = stage_accepted_root,
    registry_root = stage_registry_root,
    registry_context_root = stage_registry_root,
    handoff_root = handoff$handoff_root
  )

  accepted_fixtures <- phase14_uefa_correction_read_csv(file.path(stage_accepted_root, edition_id, "fixtures.csv"))
  accepted_results <- phase14_uefa_correction_read_csv(file.path(stage_accepted_root, edition_id, "results.csv"))
  historical <- existing_crosswalk[as.character(existing_crosswalk$source_namespace) == "martj42_history", , drop = FALSE]
  # The retired competition rows are intentionally excluded.  Rebuild the
  # historical-only table hash before using it as the immutable existing map;
  # its original table_sha256 covered the old full crosswalk.
  historical <- phase14_match_state_rebuild_identity_hashes(historical)
  phase14_validate_match_identity_crosswalk(historical)
  rebuilt_crosswalk <- phase14_build_match_identity_crosswalk(
    historical = historical,
    accepted_fixtures = accepted_fixtures,
    accepted_results = accepted_results,
    existing_crosswalk = historical,
    strict = TRUE
  )
  phase14_validate_match_identity_crosswalk(rebuilt_crosswalk)
  phase14_write_match_identity_crosswalk(
    rebuilt_crosswalk,
    file.path(stage_registry_root, "match_identity.csv"),
    overwrite = TRUE
  )

  editions <- phase14_uefa_correction_read_csv(file.path(stage_registry_root, "competition_editions.csv"))
  editions <- phase14_uefa_correction_update_edition(
    editions,
    edition_id = edition_id,
    bundle_id = options$bundle_id,
    accepted_at_utc = retrieved_at,
    operator = options$operator
  )
  source_bundles <- phase14_uefa_correction_read_csv(file.path(stage_registry_root, "source_bundles.csv"))
  phase13_validate_competition_edition_registries(
    editions,
    source_bundles = source_bundles,
    require_complete = TRUE,
    selector_path = file.path(project_root, "outputs/releases/approved_release.csv"),
    project_root = project_root
  )
  phase13$write_csv(editions, file.path(stage_registry_root, "competition_editions.csv"))
  edition_row <- editions[as.character(editions$edition_id) == edition_id, , drop = FALSE]
  phase14_uefa_correction_stage_refresh_history(
    registry_root = stage_registry_root,
    edition_id = edition_id,
    refresh_batch_id = options$refresh_batch_id,
    candidate = candidate,
    edition_row = edition_row,
    operator = options$operator,
    operator_action = "Replaced the fictional sample with the official UEFA 2026/27 Nations League match endpoint response.",
    phase13 = phase13
  )
  get("phase13_validate_refresh_history", acquisition)(
    edition_id = edition_id,
    registry_root = stage_registry_root,
    accepted_root = stage_accepted_root,
    refresh_batch_root = file.path(stage_registry_root, "refresh_batches"),
    project_root = project_root,
    raw_root = stage_raw_root
  )

  phase14_uefa_correction_atomic_promote(stage_root, project_root, options$bundle_id)
  final_crosswalk <- phase14_uefa_correction_read_csv(file.path(project_registry_root, "match_identity.csv"))
  phase14_validate_match_identity_crosswalk(final_crosswalk)
  message(sprintf(
    "Official UEFA Nations League correction accepted: bundle=%s fixtures=%d groups=%d teams=%d raw_sha256=%s match_identity_rows=%d",
    options$bundle_id,
    nrow(accepted_fixtures),
    nrow(phase14_uefa_correction_read_csv(file.path(project_accepted_root, edition_id, "groups.csv"))),
    nrow(identity),
    as.character(candidate$artifacts$raw_sha256[[1L]]),
    nrow(final_crosswalk)
  ))
  invisible(list(
    candidate = candidate,
    identity = identity,
    crosswalk = final_crosswalk,
    official_counts = input$official_counts,
    raw_sha256 = as.character(candidate$artifacts$raw_sha256[[1L]]),
    retrieved_at_utc = retrieved_at,
    bundle_id = options$bundle_id
  ))
}

if (identical(environment(), globalenv())) {
  phase14_uefa_correction_main()
}
