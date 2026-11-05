library(testthat)

nl_state_reporting_root <- normalizePath(if (basename(getwd()) == "testthat") "../.." else ".", mustWork = TRUE)

nl_state_reporting_fixture <- function() {
  api <- new.env(parent = globalenv())
  script <- Sys.getenv("XGELO_NL_STATE_REPORTING_TEST_SCRIPT",
    file.path(nl_state_reporting_root, "scripts/refresh_nations_league_state.R"))
  sys.source(script, envir = api)
  api$phase14_refresh_nl_root <- nl_state_reporting_root
  candidate_hash <- paste(rep("a", 64L), collapse = "")
  installed_hash <- digest::digest("independently serialized canonical state fixture", algo = "sha256", serialize = FALSE)
  candidate <- list(state_manifest_sha256 = candidate_hash)
  backend <- new.env(parent = globalenv())
  backend$phase14_build_competition_state_main <- function(...) list(validation = TRUE,
    batch = list(candidates = setNames(list(candidate), "uefa_nations_league_2026_27")))
  backend$phase14_validate_competition_state_bundle <- function(...) invisible(TRUE)
  api$phase14_refresh_nl_load <- function() backend
  api$phase14_refresh_nl_read_source_bundle <- function(...) data.frame(source_bundle_sha256 = paste(rep("c", 64L), collapse = ""))
  api$phase14_refresh_nl_prepare_candidate <- function(environment, candidate) candidate
  api$phase14_refresh_nl_repin_stage_capture <- function(...) list(capture_id = "independent-stage-capture")
  writes <- new.env(parent = emptyenv()); writes$state <- 0L; writes$stage <- 0L
  directory <- tempfile("nl-state-hash-report-")
  api$phase14_refresh_nl_write_stage_capture <- function(...) { writes$stage <- writes$stage + 1L; invisible(TRUE) }
  api$phase14_refresh_nl_write_state <- function(...) {
    writes$state <- writes$state + 1L
    dir.create(directory)
    # The disk-roundtrip canonical hash intentionally differs from the
    # in-memory candidate. Reading this fixture independently catches a
    # regression that prints the candidate after successful promotion.
    utils::write.csv(data.frame(manifest_sha256 = installed_hash), file.path(directory, "state_manifest.csv"), row.names = FALSE)
    invisible(structure(directory, manifest_sha256 = installed_hash))
  }
  list(api = api, directory = directory, candidate_hash = candidate_hash,
    installed_hash = installed_hash, writes = writes)
}

test_that("published NL state log reports the canonical installed disk identity", {
  fixture <- nl_state_reporting_fixture()
  on.exit(unlink(fixture$directory, recursive = TRUE), add = TRUE)
  text <- utils::capture.output(result <- fixture$api$phase14_refresh_nl_main(character()))
  disk <- utils::read.csv(file.path(fixture$directory, "state_manifest.csv"), stringsAsFactors = FALSE)
  expect_true(grepl(paste0(" state_manifest_sha256=", disk$manifest_sha256[[1L]]), paste(text, collapse = "\n"), fixed = TRUE))
  expect_false(grepl(fixture$candidate_hash, paste(text, collapse = "\n"), fixed = TRUE))
  expect_identical(result$installed_state_manifest_sha256, disk$manifest_sha256[[1L]])
  expect_identical(result$candidate$state_manifest_sha256, fixture$candidate_hash)
  expect_identical(fixture$writes$state, 1L)
  expect_identical(fixture$writes$stage, 1L)
})

test_that("dry run identifies a candidate hash and performs no promotion", {
  fixture <- nl_state_reporting_fixture()
  text <- utils::capture.output(result <- fixture$api$phase14_refresh_nl_main("--dry-run"))
  text <- paste(text, collapse = "\n")
  expect_true(grepl(paste0(" candidate_state_manifest_sha256=", fixture$candidate_hash), text, fixed = TRUE))
  expect_false(grepl(" state_manifest_sha256=", text, fixed = TRUE))
  expect_null(result$installed_state_manifest_sha256)
  expect_null(result$written_state)
  expect_identical(fixture$writes$state, 0L)
  expect_identical(fixture$writes$stage, 0L)
  expect_false(dir.exists(fixture$directory))
})

test_that("missing or malformed installed hashes cannot produce a success identity", {
  for (bad in list(NULL, "not-a-sha", c(paste(rep("d", 64), collapse = ""), paste(rep("e", 64), collapse = "")))) {
    fixture <- nl_state_reporting_fixture()
    fixture$api$phase14_refresh_nl_write_state <- local({
      hash <- bad
      function(...) invisible(structure("independent-fixture-root", manifest_sha256 = hash))
    })
    expect_error(fixture$api$phase14_refresh_nl_main(character()), "canonical installed manifest hash")
  }
})
