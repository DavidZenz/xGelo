library(testthat)

phase13_refresh_test_project_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/"
)

phase13_refresh_test_load_acquire <- function() {
  environment <- new.env(parent = globalenv())
  previous_directory <- getwd()
  setwd(phase13_refresh_test_project_root)
  on.exit(setwd(previous_directory), add = TRUE)
  sys.source(
    file.path(phase13_refresh_test_project_root, "scripts/acquire_uefa_snapshot.R"),
    envir = environment
  )
  environment
}

phase13_refresh_test_copy_tree <- function(source, target) {
  dir.create(target, recursive = TRUE, showWarnings = FALSE)
  files <- list.files(source, full.names = TRUE, all.files = FALSE)
  for (path in files) {
    destination <- file.path(target, basename(path))
    if (dir.exists(path)) {
      phase13_refresh_test_copy_tree(path, destination)
    } else {
      stopifnot(file.copy(path, destination, overwrite = TRUE))
    }
  }
  invisible(target)
}

phase13_refresh_test_copy_sandbox <- function() {
  root <- tempfile("phase13-refresh-copy-", tmpdir = phase13_refresh_test_project_root)
  accepted_root <- file.path(root, "accepted")
  registry_root <- file.path(root, "registries")
  raw_root <- file.path(root, "local_raw")
  source_accepted_root <- file.path(phase13_refresh_test_project_root, "data/competition/accepted")
  source_registry_root <- file.path(phase13_refresh_test_project_root, "data/competition/registries")
  source_raw_root <- file.path(phase13_refresh_test_project_root, "data/competition/local_raw")
  editions <- c("uefa_nations_league_2026_27", "uefa_euro_2028_qualifying")

  dir.create(accepted_root, recursive = TRUE, showWarnings = FALSE)
  dir.create(registry_root, recursive = TRUE, showWarnings = FALSE)
  for (edition_id in editions) {
    phase13_refresh_test_copy_tree(
      file.path(source_accepted_root, edition_id),
      file.path(accepted_root, edition_id)
    )
  }
  phase13_refresh_test_copy_tree(source_raw_root, raw_root)
  registry_files <- file.path(
    source_registry_root,
    c("competition_editions.csv", "source_artifacts.csv", "source_bundles.csv", "team_identity.csv")
  )
  stopifnot(all(file.copy(registry_files, registry_root, overwrite = TRUE)))

  list(
    root = root,
    accepted_root = accepted_root,
    registry_root = registry_root,
    raw_root = raw_root
  )
}

phase13_refresh_test_file_snapshot <- function(root) {
  if (!dir.exists(root)) return(setNames(character(), character()))
  files <- list.files(root, recursive = TRUE, full.names = TRUE, all.files = FALSE, no.. = TRUE)
  files <- files[file.info(files)$isdir %in% FALSE]
  if (!length(files)) return(setNames(character(), character()))
  relative <- substring(files, nchar(normalizePath(root, winslash = "/", mustWork = TRUE)) + 2L)
  hashes <- vapply(files, function(path) {
    digest::digest(readBin(path, what = "raw", n = file.info(path)$size), algo = "sha256", serialize = FALSE)
  }, character(1))
  setNames(hashes, relative)
}

phase13_refresh_test_run_acquire <- function(args) {
  script <- file.path(phase13_refresh_test_project_root, "scripts/acquire_uefa_snapshot.R")
  output <- system2("Rscript", c("--vanilla", script, args), stdout = TRUE, stderr = TRUE)
  list(
    output = output,
    status = if (is.null(attr(output, "status"))) 0L else as.integer(attr(output, "status"))
  )
}

phase13_refresh_test_invalid_fixture_dir <- function() {
  fixture_dir <- file.path(phase13_refresh_test_project_root, "tests/fixtures/phase13")
  invalid_dir <- tempfile("phase13-invalid-refresh-")
  dir.create(invalid_dir, recursive = TRUE, showWarnings = FALSE)
  invalid <- jsonlite::fromJSON(
    file.path(fixture_dir, "uefa_nations_league_sample.json"),
    simplifyVector = FALSE
  )
  invalid$resources$standings[[1L]]$points <- NULL
  jsonlite::write_json(
    invalid,
    file.path(invalid_dir, "uefa_nations_league_sample.json"),
    auto_unbox = TRUE,
    pretty = TRUE
  )
  invalid_dir
}

phase13_refresh_test_valid_candidate <- function(acquire, sandbox, bundle_id) {
  acquire$phase13_acquire_candidate(
    list(
      `fixture-dir` = file.path(phase13_refresh_test_project_root, "tests/fixtures/phase13"),
      `fixture-file` = NULL,
      `fallback-file` = NULL,
      `bundle-id` = bundle_id
    ),
    "uefa_nations_league_2026_27",
    project_root = phase13_refresh_test_project_root
  )
}

test_that("invalid refresh durably blocks one edition without changing accepted/source artifacts", {
  acquire <- phase13_refresh_test_load_acquire()
  sandbox <- phase13_refresh_test_copy_sandbox()
  on.exit(unlink(sandbox$root, recursive = TRUE, force = TRUE), add = TRUE)

  accepted_before <- phase13_refresh_test_file_snapshot(sandbox$accepted_root)
  source_before <- phase13_refresh_test_file_snapshot(sandbox$registry_root)
  invalid_dir <- phase13_refresh_test_invalid_fixture_dir()
  on.exit(unlink(invalid_dir, recursive = TRUE, force = TRUE), add = TRUE)
  refresh_batch_id <- "refresh-2026-08-14-invalid-standings-v1"

  blocked <- suppressWarnings(phase13_refresh_test_run_acquire(c(
    "--fixture-dir", invalid_dir,
    "--edition-id", "uefa_nations_league_2026_27",
    "--output-root", sandbox$accepted_root,
    "--registry-root", sandbox$registry_root,
    "--raw-root", sandbox$raw_root,
    "--bundle-id", "nl-2026-27-invalid-refresh-v1",
    "--refresh-batch-id", refresh_batch_id
  )))

  expect_false(identical(blocked$status, 0L), info = paste(blocked$output, collapse = "\n"))
  expect_identical(phase13_refresh_test_file_snapshot(sandbox$accepted_root), accepted_before)
  expect_identical(
    phase13_refresh_test_file_snapshot(sandbox$registry_root)[
      setdiff(names(source_before), "competition_editions.csv")
    ],
    source_before[setdiff(names(source_before), "competition_editions.csv")]
  )
  expect_false(file.exists(file.path(
    sandbox$accepted_root,
    "uefa_nations_league_2026_27",
    "blocked_refresh.json"
  )))

  editions <- utils::read.csv(
    file.path(sandbox$registry_root, "competition_editions.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = ""
  )
  edition <- editions[editions$edition_id == "uefa_nations_league_2026_27", , drop = FALSE]
  expect_equal(nrow(edition), 1L)
  expect_true(phase13_registry_logical(edition$blocked[[1L]], "blocked"))
  expect_identical(as.character(edition$blocked_refresh_batch_id[[1L]]), refresh_batch_id)
  expect_true(grepl("^[0-9a-f]{64}$", edition$row_sha256[[1L]]))
  expect_identical(edition$row_sha256[[1L]], phase13_row_sha256(edition)[[1L]])

  blocked_path <- file.path(
    sandbox$registry_root,
    "refresh_batches",
    "uefa_nations_league_2026_27",
    refresh_batch_id,
    "blocked_refresh.json"
  )
  history_path <- file.path(
    sandbox$registry_root,
    "refresh_batches",
    "uefa_nations_league_2026_27",
    "status_history.csv"
  )
  expect_true(file.exists(blocked_path))
  expect_true(file.exists(history_path))
  blocked_record <- jsonlite::fromJSON(blocked_path, simplifyVector = TRUE)
  history <- utils::read.csv(history_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  expect_identical(as.character(blocked_record$refresh_batch_id), refresh_batch_id)
  expect_identical(as.character(blocked_record$status), "blocked")
  expect_identical(as.character(blocked_record$edition_id), edition$edition_id[[1L]])
  expect_identical(as.character(blocked_record$candidate_bundle_id), "nl-2026-27-invalid-refresh-v1")
  expect_true(isTRUE(blocked_record$edition_blocked))
  expect_identical(as.character(blocked_record$registry_revision), as.character(edition$registry_revision[[1L]]))
  expect_equal(nrow(history), 1L)
  expect_identical(as.character(history$refresh_batch_id[[1L]]), refresh_batch_id)
  expect_identical(as.character(history$status[[1L]]), "blocked")
  expect_identical(as.character(history$record_relative_path[[1L]]), file.path(
    "refresh_batches", "uefa_nations_league_2026_27", refresh_batch_id, "blocked_refresh.json"
  ))
  expect_identical(history$row_sha256[[1L]], phase13_row_sha256(history)[[1L]])

  expect_silent(acquire$phase13_validate_refresh_history(
    edition_id = "uefa_nations_league_2026_27",
    registry_root = sandbox$registry_root,
    accepted_root = sandbox$accepted_root,
    refresh_batch_root = file.path(sandbox$registry_root, "refresh_batches"),
    refresh_batch_id = refresh_batch_id,
    project_root = phase13_refresh_test_project_root,
    raw_root = sandbox$raw_root
  ))
})

test_that("sidecar publication failure rolls back the edition, history, and new batch directory", {
  acquire <- phase13_refresh_test_load_acquire()
  sandbox <- phase13_refresh_test_copy_sandbox()
  on.exit(unlink(sandbox$root, recursive = TRUE, force = TRUE), add = TRUE)
  before <- phase13_refresh_test_file_snapshot(sandbox$registry_root)
  accepted_before <- phase13_refresh_test_file_snapshot(sandbox$accepted_root)

  expect_error(
    acquire$phase13_acquire_write_blocked_metadata(
      edition_id = "uefa_nations_league_2026_27",
      bundle_id = "nl-2026-27-injected-failure-v1",
      output_root = sandbox$accepted_root,
      registry_root = sandbox$registry_root,
      reason = "injected sidecar failure",
      project_root = phase13_refresh_test_project_root,
      refresh_batch_id = "refresh-2026-08-14-injected-sidecar-v1",
      raw_root = sandbox$raw_root,
      sidecar_writer = function(value, path) stop("injected sidecar writer failure", call. = FALSE)
    ),
    "^Phase 13 refresh-batch publication failed: blocked_refresh\\.json$"
  )
  expect_identical(phase13_refresh_test_file_snapshot(sandbox$registry_root), before)
  expect_identical(phase13_refresh_test_file_snapshot(sandbox$accepted_root), accepted_before)
  expect_false(dir.exists(file.path(
    sandbox$registry_root,
    "refresh_batches",
    "uefa_nations_league_2026_27",
    "refresh-2026-08-14-injected-sidecar-v1"
  )))
})

test_that("blocked recovery is explicit and later accepted linkage uses a distinct batch", {
  acquire <- phase13_refresh_test_load_acquire()
  sandbox <- phase13_refresh_test_copy_sandbox()
  on.exit(unlink(sandbox$root, recursive = TRUE, force = TRUE), add = TRUE)
  first_batch <- "refresh-2026-08-14-recovery-blocked-v1"
  second_batch <- "refresh-2026-08-14-recovery-accepted-v2"
  acquire$phase13_acquire_write_blocked_metadata(
    edition_id = "uefa_nations_league_2026_27",
    bundle_id = "nl-2026-27-invalid-recovery-v1",
    output_root = sandbox$accepted_root,
    registry_root = sandbox$registry_root,
    reason = "invalid recovery candidate",
    project_root = phase13_refresh_test_project_root,
    refresh_batch_id = first_batch,
    raw_root = sandbox$raw_root
  )

  candidate <- phase13_refresh_test_valid_candidate(acquire, sandbox, "nl-2026-27-recovered-v2")
  expect_error(
    acquire$phase13_acquire_publish_refresh(
      candidate = candidate,
      output_root = sandbox$accepted_root,
      edition_id = "uefa_nations_league_2026_27",
      raw_root = sandbox$raw_root,
      registry_root = sandbox$registry_root,
      project_root = phase13_refresh_test_project_root,
      refresh_batch_id = second_batch
    ),
    "operator action|validation"
  )

  accepted <- acquire$phase13_acquire_publish_refresh(
    candidate = candidate,
    output_root = sandbox$accepted_root,
    edition_id = "uefa_nations_league_2026_27",
    raw_root = sandbox$raw_root,
    registry_root = sandbox$registry_root,
    project_root = phase13_refresh_test_project_root,
    refresh_batch_id = second_batch,
    operator = "reviewer",
    operator_action = "reviewed complete replacement",
    validation_passed = TRUE
  )
  expect_true(is.list(accepted))
  expect_true(file.exists(file.path(
    sandbox$raw_root,
    "uefa_nations_league_2026_27",
    "nl-2026-27-recovered-v2",
    "fixtures.json"
  )))

  editions <- utils::read.csv(
    file.path(sandbox$registry_root, "competition_editions.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = ""
  )
  edition <- editions[editions$edition_id == "uefa_nations_league_2026_27", , drop = FALSE]
  expect_false(phase13_registry_logical(edition$blocked[[1L]], "blocked"))
  expect_identical(as.character(edition$blocked_refresh_batch_id[[1L]]), first_batch)
  expect_identical(as.character(edition$source_bundle_id[[1L]]), "nl-2026-27-recovered-v2")
  expect_identical(as.character(edition$active_output_bundle_id[[1L]]), "nl-2026-27-recovered-v2")
  expect_identical(as.character(edition$last_accepted_output_bundle_id[[1L]]), "nl-2026-27-recovered-v2")

  blocked_path <- file.path(
    sandbox$registry_root, "refresh_batches", "uefa_nations_league_2026_27", first_batch, "blocked_refresh.json"
  )
  blocked_before <- readBin(blocked_path, what = "raw", n = file.info(blocked_path)$size)
  history <- utils::read.csv(
    file.path(sandbox$registry_root, "refresh_batches", "uefa_nations_league_2026_27", "status_history.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = ""
  )
  expect_identical(as.character(history$status), c("blocked", "recovery", "accepted"))
  expect_identical(as.character(history$refresh_batch_id), c(first_batch, first_batch, second_batch))
  expect_identical(readBin(blocked_path, what = "raw", n = file.info(blocked_path)$size), blocked_before)
  expect_silent(acquire$phase13_validate_refresh_history(
    edition_id = "uefa_nations_league_2026_27",
    registry_root = sandbox$registry_root,
    accepted_root = sandbox$accepted_root,
    refresh_batch_root = file.path(sandbox$registry_root, "refresh_batches"),
    refresh_batch_id = first_batch,
    project_root = phase13_refresh_test_project_root,
    raw_root = sandbox$raw_root
  ))
  expect_identical(history$row_sha256, phase13_row_sha256(history))
})
