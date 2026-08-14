library(testthat)

phase13_transaction_test_project_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/"
)

phase13_transaction_test_load_api <- function() {
  path <- file.path(
    phase13_transaction_test_project_root,
    "R/competition/publication_transaction.R"
  )
  if (file.exists(path)) source(path, local = .GlobalEnv)
  invisible(TRUE)
}

phase13_transaction_test_require_api <- function(required) {
  missing <- required[!vapply(required, exists, logical(1), mode = "function")]
  if (length(missing)) {
    stop(
      paste0(
        "Wave 9 RED contract awaits publication transaction API: ",
        paste(missing, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

phase13_transaction_test_targets <- function(root) {
  accepted_root <- file.path(root, "accepted")
  registry_root <- file.path(root, "registries")
  dir.create(accepted_root, recursive = TRUE, showWarnings = FALSE)
  dir.create(registry_root, recursive = TRUE, showWarnings = FALSE)
  phase13_normalized_publication_targets(accepted_root, registry_root)
}

phase13_transaction_test_write_targets <- function(targets, prefix) {
  for (index in seq_along(targets)) {
    path <- unname(targets[[index]])
    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
    writeBin(charToRaw(paste0(prefix, "-", index)), path)
  }
  invisible(targets)
}

phase13_transaction_test_snapshot_bytes <- function(snapshot) {
  setNames(snapshot$bytes, snapshot$path)
}

test_that("normalized publication targets are exactly bounded and exclude refresh batches", {
  phase13_transaction_test_load_api()
  phase13_transaction_test_require_api(c("phase13_normalized_publication_targets"))
  root <- tempfile("phase13-transaction-targets-")
  targets <- phase13_transaction_test_targets(root)

  expected_relative <- c(
    file.path("registries", "source_artifacts.csv"),
    file.path("registries", "source_bundles.csv"),
    unlist(lapply(
      c("uefa_nations_league_2026_27", "uefa_euro_2028_qualifying"),
      function(edition_id) file.path(
        "accepted", edition_id,
        c("source_bundle_manifest.csv", paste0(c("fixtures", "groups", "standings", "results", "status"), ".csv"))
      )
    ), use.names = FALSE)
  )

  expect_length(targets, 14L)
  expect_identical(
    unname(targets),
    file.path(normalizePath(root, winslash = "/", mustWork = TRUE), expected_relative)
  )
  expect_false(any(grepl("refresh_batches", targets, fixed = TRUE)))
  expect_length(unique(targets), 14L)
})

test_that("publication lock rejects collisions and cleans only its own artifacts", {
  phase13_transaction_test_load_api()
  phase13_transaction_test_require_api(c(
    "phase13_normalized_publication_targets",
    "phase13_with_publication_lock",
    "phase13_publication_lock_path"
  ))
  root <- tempfile("phase13-transaction-lock-")
  dir.create(root, recursive = TRUE)
  targets <- phase13_transaction_test_targets(root)
  refresh_marker <- file.path(root, "refresh_batches", "keep.txt")
  unrelated <- file.path(root, "unrelated.txt")
  dir.create(dirname(refresh_marker), recursive = TRUE)
  writeBin(charToRaw("refresh-batch-record"), refresh_marker)
  writeBin(charToRaw("unrelated"), unrelated)

  lock_path <- phase13_publication_lock_path(root)
  dir.create(lock_path, recursive = TRUE)
  expect_error(
    phase13_with_publication_lock(root, targets, function(transaction) TRUE),
    "lock|collision|active"
  )
  unlink(lock_path, recursive = TRUE, force = TRUE)

  expect_identical(
    phase13_with_publication_lock(root, targets, function(transaction) {
      expect_true(dir.exists(transaction$staging_root))
      expect_true(dir.exists(transaction$backup_root))
      TRUE
    }),
    TRUE
  )
  expect_false(file.exists(lock_path))
  expect_false(any(grepl("^\\.phase13-publication-(stage|backup)-", list.files(root))))
  expect_true(file.exists(refresh_marker))
  expect_true(file.exists(unrelated))
})

test_that("publication snapshots restore changed, missing, and newly-created targets exactly", {
  phase13_transaction_test_load_api()
  phase13_transaction_test_require_api(c(
    "phase13_normalized_publication_targets",
    "phase13_snapshot_publication_targets",
    "phase13_restore_publication_snapshot"
  ))
  root <- tempfile("phase13-transaction-snapshot-")
  dir.create(root, recursive = TRUE)
  targets <- phase13_transaction_test_targets(root)
  phase13_transaction_test_write_targets(targets, "baseline")
  unlink(targets[[1L]])
  snapshot <- phase13_snapshot_publication_targets(targets)
  expect_false(snapshot$exists[[1L]])
  expect_true(all(snapshot$exists[-1L]))
  expect_true(all(grepl("^[0-9a-f]{64}$", snapshot$sha256[-1L])))

  writeBin(charToRaw("changed"), targets[[2L]])
  unlink(targets[[3L]])
  writeBin(charToRaw("new-target"), targets[[1L]])
  phase13_restore_publication_snapshot(snapshot)

  expect_false(file.exists(targets[[1L]]))
  expect_identical(readBin(targets[[2L]], what = "raw", n = file.info(targets[[2L]])$size), snapshot$bytes[[2L]])
  expect_identical(readBin(targets[[3L]], what = "raw", n = file.info(targets[[3L]])$size), snapshot$bytes[[3L]])
  expect_identical(phase13_snapshot_publication_targets(targets)$sha256, snapshot$sha256)
})

test_that("failure after every ordered target promotion restores the complete publication graph", {
  phase13_transaction_test_load_api()
  phase13_transaction_test_require_api(c(
    "phase13_normalized_publication_targets",
    "phase13_with_publication_lock",
    "phase13_seed_publication_staging",
    "phase13_promote_publication_targets",
    "phase13_snapshot_publication_targets"
  ))
  root <- tempfile("phase13-transaction-rollback-")
  dir.create(root, recursive = TRUE)
  targets <- phase13_transaction_test_targets(root)
  refresh_marker <- file.path(root, "refresh_batches", "existing", "blocked_refresh.json")
  dir.create(dirname(refresh_marker), recursive = TRUE)
  writeBin(charToRaw("keep refresh history"), refresh_marker)
  unrelated <- file.path(root, "outside-target-vector.txt")
  writeBin(charToRaw("keep unrelated"), unrelated)

  phase13_transaction_test_write_targets(targets, "baseline")
  baseline <- phase13_snapshot_publication_targets(targets)

  for (failure_index in seq_along(targets)) {
    expect_error(
      phase13_with_publication_lock(
        root,
        targets,
        function(transaction) {
          phase13_seed_publication_staging(transaction)
          for (index in seq_along(transaction$staging_targets)) {
            writeBin(charToRaw(paste0("candidate-", failure_index, "-", index)), transaction$staging_targets[[index]])
          }
          phase13_promote_publication_targets(transaction)
        },
        failure_injector = function(index, target, transaction) index == failure_index,
        require_complete_promotion = TRUE
      ),
      "Injected|failure|promotion"
    )

    after <- phase13_snapshot_publication_targets(targets)
    expect_identical(after$exists, baseline$exists)
    expect_identical(after$sha256, baseline$sha256)
    expect_identical(phase13_transaction_test_snapshot_bytes(after), phase13_transaction_test_snapshot_bytes(baseline))
    expect_identical(readBin(refresh_marker, what = "raw", n = file.info(refresh_marker)$size), charToRaw("keep refresh history"))
    expect_identical(readBin(unrelated, what = "raw", n = file.info(unrelated)$size), charToRaw("keep unrelated"))
    expect_false(any(grepl("^\\.phase13-publication-(stage|backup)-", list.files(root))))
  }
})
