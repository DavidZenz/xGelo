library(testthat)

phase14_plan18_test_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/",
  mustWork = TRUE
)

source(file.path(phase14_plan18_test_root, "R/competition/state_bundle.R"), local = .GlobalEnv)
source(file.path(phase14_plan18_test_root, "R/competition/publication_transaction.R"), local = .GlobalEnv)

phase14_plan18_snapshot_files <- function(paths) {
  exists <- file.exists(paths)
  list(
    paths = paths,
    exists = exists,
    bytes = lapply(seq_along(paths), function(index) {
      if (exists[[index]]) phase13_transaction_file_bytes(paths[[index]]) else raw(0)
    }),
    sha256 = vapply(seq_along(paths), function(index) {
      if (exists[[index]]) {
        phase13_transaction_sha256(phase13_transaction_file_bytes(paths[[index]]))
      } else {
        ""
      }
    }, character(1))
  )
}

phase14_plan18_restore_files <- function(snapshot) {
  for (index in seq_along(snapshot$paths)) {
    path <- snapshot$paths[[index]]
    if (isTRUE(snapshot$exists[[index]])) {
      phase13_transaction_write_bytes(snapshot$bytes[[index]], path)
    } else if (file.exists(path) || dir.exists(path)) {
      unlink(path, recursive = TRUE, force = TRUE)
    }
  }
  invisible(TRUE)
}

phase14_plan18_write_candidate <- function(artifacts, root, inventory) {
  for (path in inventory) {
    value <- artifacts[[path]]
    target <- file.path(root, path)
    dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
    if (identical(path, "local/score_distributions.rds")) {
      saveRDS(value, target)
    } else {
      utils::write.csv(value, target, row.names = FALSE, na = "")
    }
  }
  invisible(root)
}

phase14_run_temporary_eleven_target_transaction_probe <- function(
    output_root,
    expected_inventory = phase14_state_bundle_expected_inventory(),
    failure_indices = seq_along(expected_inventory),
    successful_readback = TRUE,
    candidate = NULL) {
  output_root <- normalizePath(output_root, winslash = "/", mustWork = TRUE)
  inventory <- as.character(expected_inventory)
  expected <- as.character(phase14_state_bundle_expected_inventory())
  if (length(inventory) != 11L || !identical(inventory, expected) || anyDuplicated(inventory)) {
    stop("Phase 14 Plan 18 probe requires the exact eleven-target inventory", call. = FALSE)
  }
  if (any(!as.integer(failure_indices) %in% seq_along(inventory))) {
    stop("Phase 14 Plan 18 probe failure indices are outside the eleven-target inventory", call. = FALSE)
  }
  targets <- file.path(output_root, inventory)
  if (any(!file.exists(targets)) || any(vapply(targets, dir.exists, logical(1)))) {
    stop("Phase 14 Plan 18 probe requires all incumbent target files", call. = FALSE)
  }

  source_root <- NULL
  if (is.null(candidate)) {
    source_paths <- targets
  } else {
    source_root <- tempfile(".phase14-plan18-candidate-", tmpdir = dirname(output_root))
    dir.create(source_root, recursive = FALSE, showWarnings = FALSE)
    on.exit(if (dir.exists(source_root)) unlink(source_root, recursive = TRUE, force = TRUE), add = TRUE)
    phase14_plan18_write_candidate(
      phase14_state_bundle_artifact_values(candidate),
      source_root,
      inventory
    )
    if (!isTRUE(phase14_validate_competition_state_bundle(source_root))) {
      stop("Phase 14 Plan 18 candidate failed staged validation", call. = FALSE)
    }
    source_paths <- file.path(source_root, inventory)
  }
  source_bytes <- lapply(source_paths, phase13_transaction_file_bytes)

  sibling <- tempfile(".phase14-plan18-sibling-", tmpdir = dirname(output_root))
  writeLines("phase14-plan18-unrelated-sibling", sibling, useBytes = TRUE)
  on.exit(if (file.exists(sibling)) unlink(sibling, force = TRUE), add = TRUE)
  sibling_before <- phase14_plan18_snapshot_files(sibling)
  authority_paths <- c(
    file.path(dirname(output_root), "..", "releases", "approved_release.csv"),
    file.path(dirname(output_root), "..", "releases", "phase14-open-nb-incumbent-calibrated-v1", "release_manifest.csv")
  )
  authority_paths <- normalizePath(authority_paths, winslash = "/", mustWork = TRUE)
  authority_before <- phase14_plan18_snapshot_files(authority_paths)

  run_once <- function(failure_index = NULL) {
    stage_root <- tempfile(".phase14-plan18-stage-", tmpdir = dirname(output_root))
    backup_root <- tempfile(".phase14-plan18-backup-", tmpdir = dirname(output_root))
    lock_path <- tempfile(".phase14-plan18-lock-", tmpdir = dirname(output_root))
    dir.create(stage_root, recursive = FALSE, showWarnings = FALSE)
    dir.create(backup_root, recursive = FALSE, showWarnings = FALSE)
    dir.create(lock_path, recursive = FALSE, showWarnings = FALSE)
    on.exit({
      if (dir.exists(stage_root)) unlink(stage_root, recursive = TRUE, force = TRUE)
      if (dir.exists(backup_root)) unlink(backup_root, recursive = TRUE, force = TRUE)
      if (dir.exists(lock_path)) unlink(lock_path, recursive = TRUE, force = TRUE)
    }, add = TRUE)
    staged_targets <- file.path(stage_root, inventory)
    names(staged_targets) <- inventory
    target_map <- file.path(output_root, inventory)
    names(target_map) <- inventory
    for (index in seq_along(inventory)) {
      phase13_transaction_write_bytes(source_bytes[[index]], staged_targets[[index]])
    }
    incumbent <- phase14_plan18_snapshot_files(target_map)
    promoted <- 0L
    failure <- NULL
    transaction <- list(targets = target_map, staging_targets = staged_targets, state = new.env(parent = emptyenv()))
    transaction$state$promoted_count <- 0L
    transaction$state$promoted_targets <- character()
    tryCatch({
      for (index in seq_along(inventory)) {
        target <- target_map[[index]]
        staged <- staged_targets[[index]]
        backup <- file.path(backup_root, inventory[[index]])
        dir.create(dirname(backup), recursive = TRUE, showWarnings = FALSE)
        if (!file.rename(target, backup)) stop("Phase 14 Plan 18 probe could not backup target", call. = FALSE)
        if (!file.rename(staged, target)) stop("Phase 14 Plan 18 probe could not promote target", call. = FALSE)
        promoted <- index
        transaction$state$promoted_count <- index
        transaction$state$promoted_targets <- c(transaction$state$promoted_targets, target)
        phase13_transaction_injected_failure(
          function(current, unused_target, unused_transaction) {
            identical(as.integer(current), as.integer(failure_index))
          },
          index,
          target,
          transaction
        )
      }
    }, error = function(error) failure <<- error)
    if (!is.null(failure)) {
      phase14_plan18_restore_files(incumbent)
      if (is.null(failure_index) || !identical(as.integer(promoted), as.integer(failure_index))) {
        stop(conditionMessage(failure), call. = FALSE)
      }
    }
    actual <- phase14_plan18_snapshot_files(target_map)
    if (is.null(failure_index)) {
      if (!all(vapply(seq_along(source_bytes), function(index) {
        identical(actual$sha256[[index]], phase13_transaction_sha256(source_bytes[[index]]))
      }, logical(1)))) stop("Phase 14 Plan 18 successful promotion changed candidate bytes", call. = FALSE)
    } else if (!identical(actual$sha256, incumbent$sha256)) {
      stop("Phase 14 Plan 18 rollback did not restore incumbent bytes", call. = FALSE)
    }
    if (!identical(phase14_plan18_snapshot_files(sibling)$sha256, sibling_before$sha256) ||
        !identical(phase14_plan18_snapshot_files(authority_paths)$sha256, authority_before$sha256)) {
      stop("Phase 14 Plan 18 transaction changed unrelated authority or sibling bytes", call. = FALSE)
    }
    invisible(TRUE)
  }

  for (failure_index in as.integer(failure_indices)) run_once(failure_index)
  run_once(NULL)
  if (isTRUE(successful_readback) && !isTRUE(phase14_validate_competition_state_bundle(output_root))) {
    stop("Phase 14 Plan 18 durable read-back failed validation", call. = FALSE)
  }
  TRUE
}

test_that("Plan 14-18 eleven-target transaction probe restores exact bytes", {
  expect_true(isTRUE(phase14_run_temporary_eleven_target_transaction_probe(
    file.path(phase14_plan18_test_root, "outputs/competition/uefa_nations_league_2026_27"),
    phase14_state_bundle_expected_inventory(),
    failure_indices = seq_len(11L),
    successful_readback = TRUE
  )))
})

test_that("Phase 14 state validation allows only the registered outcomes sibling", {
  output_root <- file.path(
    phase14_plan18_test_root,
    "outputs/competition/uefa_nations_league_2026_27"
  )
  expect_true(isTRUE(phase14_validate_competition_state_bundle(output_root)))

  extra <- tempfile("phase14-plan18-unexpected-", tmpdir = output_root)
  writeLines("unexpected state-bundle extra", extra, useBytes = TRUE)
  on.exit(unlink(extra, force = TRUE), add = TRUE)
  expect_error(
    phase14_validate_competition_state_bundle(output_root),
    "unexpected inventory artifact"
  )
})
