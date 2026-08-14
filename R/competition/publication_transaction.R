#' Atomic normalized Phase 13 publication envelope.
#'
#' This module owns the durable publication boundary only.  It declares the
#' bounded target graph, creates an exclusive lock and sibling staging/backup
#' roots, promotes targets in a deterministic order, and restores the exact
#' pre-transaction bytes on every failure.  Canonical table, registry, and
#' manifest hashes remain owned by publication_hashes.R and
#' publication_manifests.R.

phase13_transaction_scalar <- function(value, name) {
  if (length(value) != 1L || is.null(value) || is.na(value) || !nzchar(as.character(value[[1L]]))) {
    stop("Phase 13 publication transaction ", name, " must be one non-empty value", call. = FALSE)
  }
  as.character(value[[1L]])
}

phase13_transaction_root <- function(path, name, must_work = TRUE) {
  path <- phase13_transaction_scalar(path, name)
  resolved <- normalizePath(path, winslash = "/", mustWork = isTRUE(must_work))
  if (isTRUE(must_work) && !dir.exists(resolved)) {
    stop("Phase 13 publication transaction ", name, " must be a directory: ", resolved, call. = FALSE)
  }
  resolved
}

phase13_transaction_path_within <- function(path, root) {
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  root <- normalizePath(root, winslash = "/", mustWork = FALSE)
  identical(path, root) || startsWith(path, paste0(root, "/"))
}

phase13_transaction_is_symlink <- function(path) {
  if (!file.exists(path) && !dir.exists(path)) return(FALSE)
  link <- tryCatch(Sys.readlink(path), error = function(error) "")
  length(link) == 1L && nzchar(link)
}

phase13_transaction_common_root <- function(accepted_root, registry_root) {
  accepted_root <- phase13_transaction_root(accepted_root, "accepted_root")
  registry_root <- phase13_transaction_root(registry_root, "registry_root")
  if (!identical(basename(accepted_root), "accepted") || !identical(basename(registry_root), "registries")) {
    stop("Phase 13 publication transaction requires accepted and registries trusted roots", call. = FALSE)
  }
  if (phase13_transaction_is_symlink(accepted_root) || phase13_transaction_is_symlink(registry_root)) {
    stop("Phase 13 publication transaction trusted roots must not be symlinks", call. = FALSE)
  }
  common_root <- normalizePath(dirname(accepted_root), winslash = "/", mustWork = TRUE)
  if (!identical(common_root, normalizePath(dirname(registry_root), winslash = "/", mustWork = TRUE))) {
    stop("Phase 13 publication transaction roots must be siblings", call. = FALSE)
  }
  if (phase13_transaction_path_within(registry_root, accepted_root) ||
      phase13_transaction_path_within(accepted_root, registry_root)) {
    stop("Phase 13 publication transaction roots must not overlap", call. = FALSE)
  }
  if (grepl("(^|/)refresh_batches(/|$)", accepted_root) ||
      grepl("(^|/)refresh_batches(/|$)", registry_root)) {
    stop("Phase 13 publication transaction cannot use refresh_batches as a trusted root", call. = FALSE)
  }
  common_root
}

phase13_transaction_expected_relative_targets <- function() {
  editions <- c("uefa_nations_league_2026_27", "uefa_euro_2028_qualifying")
  resource_files <- paste0(c("fixtures", "groups", "standings", "results", "status"), ".csv")
  c(
    file.path("registries", "source_artifacts.csv"),
    file.path("registries", "source_bundles.csv"),
    unlist(lapply(editions, function(edition_id) c(
      file.path("accepted", edition_id, "source_bundle_manifest.csv"),
      file.path("accepted", edition_id, resource_files)
    )), use.names = FALSE)
  )
}

phase13_transaction_build_targets <- function(common_root) {
  relative <- phase13_transaction_expected_relative_targets()
  targets <- file.path(common_root, relative)
  names(targets) <- relative
  targets
}

#' Return the exact fourteen durable targets owned by normalized publication.
phase13_normalized_publication_targets <- function(
    accepted_root = "data/competition/accepted",
    registry_root = "data/competition/registries") {
  common_root <- phase13_transaction_common_root(accepted_root, registry_root)
  targets <- phase13_transaction_build_targets(common_root)
  expected_accepted <- normalizePath(accepted_root, winslash = "/", mustWork = TRUE)
  expected_registry <- normalizePath(registry_root, winslash = "/", mustWork = TRUE)
  if (!all(vapply(targets, function(path) {
    phase13_transaction_path_within(path, expected_accepted) ||
      phase13_transaction_path_within(path, expected_registry)
  }, logical(1)))) {
    stop("Phase 13 publication target vector crossed a trusted root", call. = FALSE)
  }
  targets
}

phase13_transaction_infer_common_root <- function(targets) {
  targets <- as.character(targets)
  accepted_matches <- grep("/accepted/", targets, fixed = TRUE, value = TRUE)
  registry_matches <- grep("/registries/", targets, fixed = TRUE, value = TRUE)
  if (!length(accepted_matches) || !length(registry_matches)) {
    stop("Phase 13 publication target vector must contain accepted and registry targets", call. = FALSE)
  }
  accepted_root <- sub("/accepted/.*$", "/accepted", accepted_matches[[1L]])
  registry_root <- sub("/registries/.*$", "/registries", registry_matches[[1L]])
  phase13_transaction_common_root(accepted_root, registry_root)
}

phase13_transaction_validate_targets <- function(targets) {
  if (!is.character(targets) || length(targets) != length(phase13_transaction_expected_relative_targets())) {
    stop("Phase 13 publication target vector must contain exactly fourteen paths", call. = FALSE)
  }
  if (any(is.na(targets) | !nzchar(targets)) || anyDuplicated(targets)) {
    stop("Phase 13 publication target vector contains missing or duplicate paths", call. = FALSE)
  }
  if (any(!grepl("^/", targets)) || any(grepl("(^|/)\\.\\.?(/|$)", targets)) ||
      any(grepl("refresh_batches", targets, fixed = TRUE))) {
    stop("Phase 13 publication target vector contains an unsafe or out-of-scope path", call. = FALSE)
  }
  resolved <- normalizePath(targets, winslash = "/", mustWork = FALSE)
  common_root <- phase13_transaction_infer_common_root(resolved)
  expected <- phase13_transaction_build_targets(common_root)
  expected_paths <- unname(expected)
  if (!setequal(resolved, expected_paths) || length(resolved) != length(expected_paths)) {
    stop("Phase 13 publication target vector must match the exact fourteen-file graph", call. = FALSE)
  }
  if (any(vapply(resolved, phase13_transaction_is_symlink, logical(1)))) {
    stop("Phase 13 publication targets must not be symlinks", call. = FALSE)
  }
  names(resolved) <- names(expected)[match(resolved, expected_paths)]
  resolved
}

phase13_publication_lock_path <- function(publication_root) {
  publication_root <- phase13_transaction_root(publication_root, "publication_root")
  file.path(publication_root, ".phase13-publication.lock")
}

phase13_transaction_file_bytes <- function(path) {
  if (!file.exists(path) || dir.exists(path)) {
    stop("Phase 13 publication target is not a regular file: ", path, call. = FALSE)
  }
  readBin(path, what = "raw", n = file.info(path)$size)
}

phase13_transaction_sha256 <- function(bytes) {
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("digest is required for Phase 13 publication transaction snapshots", call. = FALSE)
  }
  digest::digest(bytes, algo = "sha256", serialize = FALSE)
}

#' Capture exact existence, bytes, and SHA-256 values for all durable targets.
phase13_snapshot_publication_targets <- function(targets) {
  targets <- phase13_transaction_validate_targets(targets)
  exists <- vapply(targets, file.exists, logical(1))
  if (any(exists & vapply(targets, dir.exists, logical(1)))) {
    stop("Phase 13 publication snapshot cannot capture a directory target", call. = FALSE)
  }
  bytes <- lapply(seq_along(targets), function(index) {
    if (isTRUE(exists[[index]])) phase13_transaction_file_bytes(targets[[index]]) else raw(0)
  })
  sha256 <- vapply(seq_along(targets), function(index) {
    if (isTRUE(exists[[index]])) phase13_transaction_sha256(bytes[[index]]) else ""
  }, character(1))
  byte_count <- vapply(bytes, length, integer(1))
  list(
    path = unname(targets),
    exists = exists,
    bytes = bytes,
    byte_count = byte_count,
    sha256 = sha256,
    target_names = names(targets)
  )
}

phase13_transaction_validate_snapshot <- function(snapshot) {
  required <- c("path", "exists", "bytes", "byte_count", "sha256")
  if (!is.list(snapshot) || length(setdiff(required, names(snapshot)))) {
    stop("Phase 13 publication snapshot is incomplete", call. = FALSE)
  }
  phase13_transaction_validate_targets(snapshot$path)
  if (length(snapshot$exists) != length(snapshot$path) ||
      length(snapshot$bytes) != length(snapshot$path) ||
      length(snapshot$byte_count) != length(snapshot$path) ||
      length(snapshot$sha256) != length(snapshot$path)) {
    stop("Phase 13 publication snapshot target metadata is incomplete", call. = FALSE)
  }
  if (any(!vapply(snapshot$exists, is.logical, logical(1))) ||
      any(!vapply(snapshot$bytes, is.raw, logical(1)))) {
    stop("Phase 13 publication snapshot target metadata has invalid types", call. = FALSE)
  }
  invisible(snapshot)
}

phase13_transaction_write_bytes <- function(bytes, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  staged <- tempfile(paste0(".", basename(path), "-restore-"), tmpdir = dirname(path))
  on.exit(if (file.exists(staged)) unlink(staged, force = TRUE), add = TRUE)
  writeBin(bytes, staged)
  if (file.exists(path) || dir.exists(path)) unlink(path, recursive = TRUE, force = TRUE)
  if (!file.rename(staged, path)) stop("Could not restore Phase 13 publication target: ", path, call. = FALSE)
  invisible(path)
}

#' Restore every target from an exact pre-publication snapshot.
phase13_restore_publication_snapshot <- function(snapshot) {
  phase13_transaction_validate_snapshot(snapshot)
  for (index in seq_along(snapshot$path)) {
    path <- snapshot$path[[index]]
    if (isTRUE(snapshot$exists[[index]])) {
      if (length(snapshot$bytes[[index]]) != as.integer(snapshot$byte_count[[index]]) ||
          !identical(phase13_transaction_sha256(snapshot$bytes[[index]]), snapshot$sha256[[index]])) {
        stop("Phase 13 publication snapshot bytes are internally inconsistent: ", path, call. = FALSE)
      }
      phase13_transaction_write_bytes(snapshot$bytes[[index]], path)
    } else if (file.exists(path) || dir.exists(path)) {
      unlink(path, recursive = TRUE, force = TRUE)
    }
  }
  invisible(snapshot)
}

phase13_transaction_relative_target <- function(transaction, target) {
  target <- normalizePath(target, winslash = "/", mustWork = FALSE)
  root <- transaction$publication_root
  if (!phase13_transaction_path_within(target, root) || identical(target, root)) {
    stop("Phase 13 publication target is outside the transaction root", call. = FALSE)
  }
  substring(target, nchar(root) + 2L)
}

phase13_seed_publication_staging <- function(transaction) {
  if (!is.list(transaction) || is.null(transaction$staging_targets)) {
    stop("Phase 13 publication staging requires a transaction context", call. = FALSE)
  }
  for (index in seq_along(transaction$targets)) {
    target <- transaction$targets[[index]]
    staged <- transaction$staging_targets[[index]]
    if (file.exists(target)) {
      if (dir.exists(target)) stop("Phase 13 publication target is a directory: ", target, call. = FALSE)
      phase13_transaction_write_bytes(phase13_transaction_file_bytes(target), staged)
    }
  }
  invisible(transaction$staging_targets)
}

phase13_transaction_injected_failure <- function(injector, index, target, transaction) {
  if (is.null(injector)) return(invisible(FALSE))
  if (!is.function(injector)) stop("Phase 13 publication failure injector must be a function", call. = FALSE)
  result <- injector(index, target, transaction)
  if (length(result) != 1L || !is.logical(result) || is.na(result)) {
    stop("Phase 13 publication failure injector must return one non-missing logical value", call. = FALSE)
  }
  if (isTRUE(result)) {
    stop("Injected Phase 13 publication failure after target promotion ", index, ": ", target, call. = FALSE)
  }
  invisible(FALSE)
}

#' Promote every staged target in order, invoking failure injection after each.
phase13_promote_publication_targets <- function(transaction, failure_injector = NULL) {
  if (!is.list(transaction) || is.null(transaction$targets) || is.null(transaction$staging_targets) ||
      is.null(transaction$backup_root) || is.null(transaction$state)) {
    stop("Phase 13 publication promotion requires a transaction context", call. = FALSE)
  }
  targets <- phase13_transaction_validate_targets(transaction$targets)
  staged_targets <- transaction$staging_targets
  if (!identical(names(staged_targets), names(targets)) || length(staged_targets) != length(targets)) {
    stop("Phase 13 publication staging target graph is incomplete", call. = FALSE)
  }
  if (is.null(failure_injector)) failure_injector <- transaction$failure_injector
  for (index in seq_along(targets)) {
    target <- targets[[index]]
    staged <- staged_targets[[index]]
    if (!file.exists(staged) || dir.exists(staged)) {
      stop("Phase 13 publication staging target is missing: ", staged, call. = FALSE)
    }
    relative <- phase13_transaction_relative_target(transaction, target)
    backup <- file.path(transaction$backup_root, relative)
    if (file.exists(target) || dir.exists(target)) {
      if (dir.exists(target)) stop("Phase 13 publication target is a directory: ", target, call. = FALSE)
      dir.create(dirname(backup), recursive = TRUE, showWarnings = FALSE)
      if (!file.rename(target, backup)) stop("Could not backup Phase 13 publication target: ", target, call. = FALSE)
    }
    dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
    if (!file.rename(staged, target)) stop("Could not promote Phase 13 publication target: ", target, call. = FALSE)
    transaction$state$promoted_count <- index
    transaction$state$last_target <- target
    transaction$state$promoted_targets <- c(transaction$state$promoted_targets, target)
    phase13_transaction_injected_failure(failure_injector, index, target, transaction)
  }
  invisible(transaction$state$promoted_targets)
}

phase13_transaction_cleanup <- function(transaction) {
  if (isTRUE(transaction$owned_staging) && dir.exists(transaction$staging_root)) {
    unlink(transaction$staging_root, recursive = TRUE, force = TRUE)
  }
  if (isTRUE(transaction$owned_backup) && dir.exists(transaction$backup_root)) {
    unlink(transaction$backup_root, recursive = TRUE, force = TRUE)
  }
  if (isTRUE(transaction$owned_lock) && (file.exists(transaction$lock_path) || dir.exists(transaction$lock_path))) {
    unlink(transaction$lock_path, recursive = TRUE, force = TRUE)
  }
  invisible(TRUE)
}

#' Run one normalized publication callback under an exclusive lock.
phase13_with_publication_lock <- function(
    publication_root,
    targets,
    callback,
    failure_injector = NULL,
    require_complete_promotion = FALSE) {
  publication_root <- phase13_transaction_root(publication_root, "publication_root")
  targets <- phase13_transaction_validate_targets(targets)
  if (!is.function(callback)) stop("Phase 13 publication lock callback must be a function", call. = FALSE)
  if (length(require_complete_promotion) != 1L || !is.logical(require_complete_promotion) || is.na(require_complete_promotion)) {
    stop("Phase 13 publication complete-promotion flag must be one logical value", call. = FALSE)
  }
  lock_path <- phase13_publication_lock_path(publication_root)
  if (file.exists(lock_path) || dir.exists(lock_path)) {
    stop("Phase 13 publication lock collision: an active lock already exists", call. = FALSE)
  }
  if (!dir.create(lock_path, recursive = FALSE, showWarnings = FALSE)) {
    stop("Phase 13 publication lock collision: could not acquire exclusive lock", call. = FALSE)
  }
  owned_lock <- TRUE
  lock_owner <- file.path(lock_path, "owner")
  writeLines(c("phase13-normalized-publication-v1", paste(Sys.getpid(), Sys.time())), lock_owner, useBytes = TRUE)

  staging_root <- tempfile(".phase13-publication-stage-", tmpdir = publication_root)
  backup_root <- tempfile(".phase13-publication-backup-", tmpdir = publication_root)
  if (!dir.create(staging_root, recursive = FALSE, showWarnings = FALSE) ||
      !dir.create(backup_root, recursive = FALSE, showWarnings = FALSE)) {
    transaction <- list(
      owned_lock = owned_lock, owned_staging = dir.exists(staging_root), owned_backup = dir.exists(backup_root),
      lock_path = lock_path, staging_root = staging_root, backup_root = backup_root
    )
    phase13_transaction_cleanup(transaction)
    stop("Phase 13 publication staging or backup root could not be created", call. = FALSE)
  }
  snapshot <- phase13_snapshot_publication_targets(targets)
  relative <- names(targets)
  staging_targets <- file.path(staging_root, relative)
  names(staging_targets) <- relative
  state <- new.env(parent = emptyenv())
  state$promoted_count <- 0L
  state$last_target <- ""
  state$promoted_targets <- character()
  transaction <- list(
    publication_root = publication_root,
    targets = targets,
    snapshot = snapshot,
    lock_path = lock_path,
    staging_root = staging_root,
    backup_root = backup_root,
    staging_targets = staging_targets,
    failure_injector = failure_injector,
    state = state,
    owned_lock = owned_lock,
    owned_staging = TRUE,
    owned_backup = TRUE
  )

  callback_error <- NULL
  result <- tryCatch(
    callback(transaction),
    error = function(error) {
      callback_error <<- error
      NULL
    }
  )
  if (is.null(callback_error) && isTRUE(require_complete_promotion) &&
      !identical(as.integer(state$promoted_count), length(targets))) {
    callback_error <- simpleError(
      paste0("Phase 13 publication did not promote the complete target vector (",
             state$promoted_count, "/", length(targets), ")")
    )
  }
  if (!is.null(callback_error)) {
    restore_error <- NULL
    tryCatch(
      phase13_restore_publication_snapshot(snapshot),
      error = function(error) restore_error <<- error
    )
    phase13_transaction_cleanup(transaction)
    if (!is.null(restore_error)) {
      stop(
        "Phase 13 publication rollback failed after: ", conditionMessage(callback_error),
        "; restore error: ", conditionMessage(restore_error),
        call. = FALSE
      )
    }
    stop(callback_error)
  }
  phase13_transaction_cleanup(transaction)
  result
}
