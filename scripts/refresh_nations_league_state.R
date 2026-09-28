#!/usr/bin/env Rscript

# Rebuild the durable Phase 14 Nations League state bundle after an accepted
# source refresh.  The state builder itself is deterministic and remains the
# authority for the artifact schemas; this wrapper only owns the durable file
# promotion and the empty stage-capture source-hash repin.

phase14_refresh_nl_args <- commandArgs(trailingOnly = TRUE)
phase14_refresh_nl_file_args <- commandArgs(trailingOnly = FALSE)
phase14_refresh_nl_file_arg <- phase14_refresh_nl_file_args[grepl("^--file=", phase14_refresh_nl_file_args)]
phase14_refresh_nl_script <- if (length(phase14_refresh_nl_file_arg)) {
  sub("^--file=", "", phase14_refresh_nl_file_arg[[1L]])
} else {
  "scripts/refresh_nations_league_state.R"
}
phase14_refresh_nl_root <- normalizePath(
  file.path(dirname(phase14_refresh_nl_script), ".."),
  winslash = "/",
  mustWork = FALSE
)
phase14_refresh_nl_edition_id <- "uefa_nations_league_2026_27"

phase14_refresh_nl_parse_args <- function(args) {
  output <- list(edition_id = phase14_refresh_nl_edition_id, dry_run = FALSE, help = FALSE)
  index <- 1L
  while (index <= length(args)) {
    token <- as.character(args[[index]])
    if (token %in% c("--help", "-h")) {
      output$help <- TRUE
      index <- index + 1L
      next
    }
    if (identical(token, "--dry-run")) {
      output$dry_run <- TRUE
      index <- index + 1L
      next
    }
    if (token %in% c("--edition-id", "--edition_id")) {
      if (index == length(args)) stop("--edition-id requires a value", call. = FALSE)
      output$edition_id <- as.character(args[[index + 1L]])
      index <- index + 2L
      next
    }
    if (grepl("^--edition-id=", token)) {
      output$edition_id <- sub("^--edition-id=", "", token)
      index <- index + 1L
      next
    }
    stop("Unsupported argument: ", token, call. = FALSE)
  }
  if (!isTRUE(output$help) && !identical(output$edition_id, phase14_refresh_nl_edition_id)) {
    stop("Only the registered Nations League edition can be refreshed: ", output$edition_id, call. = FALSE)
  }
  output
}

phase14_refresh_nl_usage <- function() {
  paste(
    "Usage: Rscript --vanilla scripts/refresh_nations_league_state.R",
    "[--edition-id uefa_nations_league_2026_27] [--dry-run]",
    sep = "\n"
  )
}

phase14_refresh_nl_source <- function(relative_path, environment) {
  path <- file.path(phase14_refresh_nl_root, relative_path)
  if (!file.exists(path)) stop("Required Nations League refresh dependency is missing: ", relative_path, call. = FALSE)
  sys.source(path, envir = environment)
}

phase14_refresh_nl_load <- function() {
  environment <- new.env(parent = globalenv())
  phase14_refresh_nl_source("R/competition/source_contracts.R", environment)
  phase14_refresh_nl_source("R/competition/publication_hashes.R", environment)
  phase14_refresh_nl_source("R/competition/team_identity.R", environment)
  phase14_refresh_nl_source("R/competition/uefa_nations_league_adapter.R", environment)
  state_script <- file.path(phase14_refresh_nl_root, "scripts/build_competition_state.R")
  sys.source(state_script, envir = environment)
  environment
}

phase14_refresh_nl_read_source_bundle <- function(environment) {
  path <- file.path(phase14_refresh_nl_root, "data/competition/registries/source_bundles.csv")
  bundles <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  row <- bundles[
    as.character(bundles$bundle_id) == environment$phase14_uefa_nl_bundle_id() &
      as.character(bundles$edition_id) == phase14_refresh_nl_edition_id,
    , drop = FALSE
  ]
  if (nrow(row) != 1L || !grepl("^[0-9a-fA-F]{64}$", as.character(row$source_bundle_sha256[[1L]]))) {
    stop("The accepted Nations League source bundle hash is unavailable", call. = FALSE)
  }
  row[1L, , drop = FALSE]
}

phase14_refresh_nl_repin_stage_capture <- function(environment, source_bundle) {
  paths <- environment$phase15_uefa_nl_stage_capture_paths(phase14_refresh_nl_root)
  required <- environment$phase15_uefa_nl_stage_capture_manifest_schema()
  manifest <- utils::read.csv(paths$manifest_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  registry <- utils::read.csv(paths$registry_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  capture <- utils::read.csv(paths$capture_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  if (!identical(names(manifest), required) || !identical(names(registry), required)) {
    stop("The registered Nations League stage-capture lineage schema is incomplete", call. = FALSE)
  }
  manifest$source_bundle_id <- as.character(source_bundle$bundle_id[[1L]])
  manifest$source_bundle_sha256 <- tolower(as.character(source_bundle$source_bundle_sha256[[1L]]))
  manifest$manifest_sha256 <- environment$phase15_uefa_nl_manifest_self_sha256(manifest)
  manifest$row_sha256 <- environment$phase15_uefa_nl_capture_row_hash(manifest)
  registry_index <- match(as.character(manifest$capture_id[[1L]]), as.character(registry$capture_id))
  if (is.na(registry_index)) stop("The Nations League stage-capture registry row is missing", call. = FALSE)
  registry[registry_index, required] <- manifest[1L, required]
  environment$phase15_uefa_nl_validate_stage_capture_manifest(
    manifest,
    paths = paths,
    capture = capture,
    project_root = phase14_refresh_nl_root
  )
  environment$phase15_uefa_nl_validate_stage_capture_registry_contract(
    registry[registry_index, , drop = FALSE],
    manifest,
    paths = paths
  )
  list(paths = paths, manifest = manifest, registry = registry)
}

phase14_refresh_nl_write_stage_capture <- function(environment, repin) {
  environment$phase13_publication_write_csv(repin$manifest, repin$paths$manifest_path)
  environment$phase13_publication_write_csv(repin$registry, repin$paths$registry_path)
  invisible(TRUE)
}

phase14_refresh_nl_empty_schema <- function(columns) {
  output <- setNames(
    # A header-only CSV is read back by base::read.csv as logical columns.
    # Build the in-memory empty schema with the same type so the artifact
    # content hash remains stable across the durable write/read boundary.
    lapply(columns, function(column) logical()),
    columns
  )
  as.data.frame(output, stringsAsFactors = FALSE, check.names = FALSE)
}

phase14_refresh_nl_prepare_candidate <- function(environment, candidate) {
  form_columns <- c(
    "edition_id", "team_id", "form_scope", "window_type", "window_size",
    "window_span", "sample_count", "eligible_sample_count", "result_sequence",
    "competition_type", "feature_cutoff_utc", "latest_evidence_completed_at_utc",
    "latest_evidence_date", "latest_evidence_precision", "contributing_match_ids",
    "contributing_match_hashes", "contributing_source_lineages", "xgf", "xga",
    "xgd", "availability_status", "availability_reason", "source_id",
    "evidence_basis", "row_sha256", "canonical_row_sha256", "table_sha256",
    "canonical_table_sha256"
  )
  reconciliation_columns <- c(
    "official_source_bundle_id", "official_rank", "official_played", "official_wins",
    "official_draws", "official_losses", "official_goals_for", "official_goals_against",
    "official_goal_difference", "official_points", "reconciliation_status",
    "reconciliation_reason", "reconciliation_severity", "publication_disposition",
    "prior_state_action", "prior_state_retention", "warning_status", "block_status",
    "blocked"
  )
  if (is.null(candidate$competition_form) ||
      (is.data.frame(candidate$competition_form) && !nrow(candidate$competition_form) && !ncol(candidate$competition_form))) {
    candidate$competition_form <- phase14_refresh_nl_empty_schema(form_columns)
  }
  if (is.null(candidate$all_senior_form) ||
      (is.data.frame(candidate$all_senior_form) && !nrow(candidate$all_senior_form) && !ncol(candidate$all_senior_form))) {
    candidate$all_senior_form <- phase14_refresh_nl_empty_schema(form_columns)
  }
  if (is.null(candidate$standings_reconciliation) ||
      (is.data.frame(candidate$standings_reconciliation) && !nrow(candidate$standings_reconciliation) && !ncol(candidate$standings_reconciliation))) {
    candidate$standings_reconciliation <- phase14_refresh_nl_empty_schema(reconciliation_columns)
  }
  # Rebuild the manifest after schema-filling so row counts, content hashes,
  # and parent hashes describe exactly what will be written to disk.
  environment$phase14_state_bundle_attach_manifest(candidate)
}

phase14_refresh_nl_canonicalize_stage_manifest <- function(environment, stage_root) {
  expected <- environment$phase14_state_bundle_expected_inventory()
  artifacts <- lapply(expected, function(relative) {
    path <- file.path(stage_root, relative)
    if (identical(relative, "local/score_distributions.rds")) {
      readRDS(path)
    } else {
      utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
    }
  })
  names(artifacts) <- expected
  manifest <- artifacts[["audit/state_manifest.csv"]]
  self_index <- match("audit/state_manifest.csv", expected)
  if (is.na(self_index) || !is.data.frame(manifest) || nrow(manifest) != length(expected)) {
    stop("The staged Nations League state manifest is incomplete", call. = FALSE)
  }

  # Compute the self hash from the serialized artifacts, matching the Phase 15
  # reader's seed projection.  This removes any dependence on in-memory CSV
  # column classes (header-only tables are read back as logical columns).
  seed <- manifest
  seed$manifest_sha256 <- ""
  seed$row_count[[self_index]] <- 0L
  seed$content_sha256[[self_index]] <- ""
  seed$row_sha256 <- vapply(expected, function(relative) {
    if (relative %in% c("audit/state_manifest.csv", "local/score_distributions.rds")) return("")
    paste(environment$phase14_state_bundle_row_hashes(artifacts[[relative]]), collapse = "|")
  }, character(1))
  manifest_hash <- environment$phase14_state_bundle_hash_value(seed)
  manifest$manifest_sha256 <- manifest_hash
  manifest$row_count[[self_index]] <- nrow(manifest)
  manifest$content_sha256[[self_index]] <- manifest_hash
  manifest$row_sha256 <- vapply(seq_len(nrow(manifest)), function(index) {
    row <- manifest[index, , drop = FALSE]
    row$row_sha256 <- ""
    environment$phase14_state_bundle_hash_value(row)
  }, character(1))
  environment$phase13_publication_write_csv(
    manifest,
    file.path(stage_root, "audit/state_manifest.csv")
  )
  manifest_hash
}

phase14_refresh_nl_write_state <- function(environment, candidate) {
  target_root <- file.path(
    phase14_refresh_nl_root,
    "outputs/competition",
    phase14_refresh_nl_edition_id
  )
  parent_root <- dirname(target_root)
  stage_root <- tempfile(".nations-league-state-stage-", tmpdir = parent_root)
  backup_root <- tempfile(".nations-league-state-backup-", tmpdir = parent_root)
  dir.create(stage_root, recursive = TRUE, showWarnings = FALSE)
  dir.create(backup_root, recursive = TRUE, showWarnings = FALSE)
  on.exit({
    if (dir.exists(stage_root)) unlink(stage_root, recursive = TRUE, force = TRUE)
    if (dir.exists(backup_root)) unlink(backup_root, recursive = TRUE, force = TRUE)
  }, add = TRUE)

  expected <- environment$phase14_state_bundle_expected_inventory()
  artifacts <- candidate$state_artifacts
  if (!identical(names(artifacts), expected)) stop("State candidate artifact inventory is not the registered eleven-file inventory", call. = FALSE)
  for (relative in expected) {
    target <- file.path(stage_root, relative)
    dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
    if (identical(relative, "local/score_distributions.rds")) {
      saveRDS(artifacts[[relative]], target)
    } else {
      environment$phase13_publication_write_csv(artifacts[[relative]], target)
    }
  }
  canonical_manifest_hash <- phase14_refresh_nl_canonicalize_stage_manifest(environment, stage_root)

  directories <- c("state", "audit", "local")
  promoted <- setNames(logical(length(directories)), directories)
  backed_up <- setNames(logical(length(directories)), directories)
  rollback <- function() {
    for (directory in rev(directories)) {
      target <- file.path(target_root, directory)
      if (isTRUE(promoted[[directory]]) && dir.exists(target)) unlink(target, recursive = TRUE, force = TRUE)
    }
    for (directory in directories) {
      target <- file.path(target_root, directory)
      backup <- file.path(backup_root, directory)
      if (isTRUE(backed_up[[directory]]) && dir.exists(backup) && !dir.exists(target)) file.rename(backup, target)
    }
  }
  success <- FALSE
  on.exit(if (!success) rollback(), add = TRUE)
  dir.create(target_root, recursive = TRUE, showWarnings = FALSE)
  for (directory in directories) {
    target <- file.path(target_root, directory)
    backup <- file.path(backup_root, directory)
    if (dir.exists(target)) {
      if (!file.rename(target, backup)) stop("Could not stage the existing state directory: ", directory, call. = FALSE)
      backed_up[[directory]] <- TRUE
    }
  }
  for (directory in directories) {
    target <- file.path(target_root, directory)
    staged <- file.path(stage_root, directory)
    if (!file.rename(staged, target)) stop("Could not promote the refreshed state directory: ", directory, call. = FALSE)
    promoted[[directory]] <- TRUE
  }
  environment$phase14_validate_competition_state_bundle(target_root)
  success <- TRUE
  attr(target_root, "manifest_sha256") <- canonical_manifest_hash
  invisible(target_root)
}

phase14_refresh_nl_main <- function(args = phase14_refresh_nl_args) {
  options <- phase14_refresh_nl_parse_args(args)
  if (isTRUE(options$help)) {
    cat(phase14_refresh_nl_usage(), "\n", sep = "")
    return(invisible(list(help = TRUE)))
  }
  environment <- phase14_refresh_nl_load()
  source_bundle <- phase14_refresh_nl_read_source_bundle(environment)
  state_result <- environment$phase14_build_competition_state_main(
    args = c("--edition-id", phase14_refresh_nl_edition_id, "--dry-run"),
    project_root = phase14_refresh_nl_root
  )
  if (!isTRUE(state_result$validation)) stop("Nations League state build did not validate", call. = FALSE)
  candidate <- state_result$batch$candidates[[phase14_refresh_nl_edition_id]]
  candidate <- phase14_refresh_nl_prepare_candidate(environment, candidate)
  environment$phase14_validate_competition_state_bundle(candidate)
  repin <- phase14_refresh_nl_repin_stage_capture(environment, source_bundle)
  if (!isTRUE(options$dry_run)) {
    phase14_refresh_nl_write_stage_capture(environment, repin)
    phase14_refresh_nl_write_state(environment, candidate)
  }
  cat(sprintf(
    "Nations League state %s: source_bundle_sha256=%s state_manifest_sha256=%s\n",
    if (isTRUE(options$dry_run)) "validated" else "published",
    as.character(source_bundle$source_bundle_sha256[[1L]]),
    as.character(candidate$state_manifest_sha256)
  ))
  invisible(list(candidate = candidate, source_bundle = source_bundle, repin = repin))
}

if (identical(environment(), globalenv()) && !interactive()) {
  phase14_refresh_nl_main()
}
