library(testthat)

phase19_domain_test_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/", mustWork = TRUE
)
source(file.path(phase19_domain_test_root, "tests/testthat/helper_phase19_club_fixture.R"),
       local = .GlobalEnv)

test_that("production history and current UCL authority fail closed before side effects", {
  phase19_test_load()
  phase19_test_require(c(
    "phase19_load_club_training_snapshot",
    "phase19_load_current_ucl_club_snapshot"
  ))
  fit_called <- FALSE
  canary <- tempfile("phase19-production-side-effect-")
  selector <- file.path(phase19_domain_test_root, "outputs/releases/club/approved_release.csv")
  selector_before <- file.exists(selector)

  history <- phase19_load_club_training_snapshot(fit_callback = function(snapshot) {
    fit_called <<- TRUE
    file.create(canary)
  })
  expect_s3_class(history, "phase19_club_authority_result")
  expect_identical(history$status, "blocked")
  expect_identical(history$reason_code, "no_accepted_club_history")
  expect_identical(history$authority_mode, "production")
  expect_identical(history$model_domain, "club")
  expect_false(history$fixture_authority)
  expect_false(fit_called)
  expect_false(file.exists(canary))
  expect_identical(file.exists(selector), selector_before)

  current <- phase19_load_current_ucl_club_snapshot()
  expect_s3_class(current, "phase19_current_ucl_authority_result")
  expect_identical(current$status, "blocked")
  expect_identical(current$reason_code, "no_accepted_current_ucl")
  expect_identical(current$authority_mode, "production")
  expect_false(current$fixture_authority)
  expect_identical(file.exists(selector), selector_before)
})

test_that("fixture history and current roster use explicit non-promotable authority", {
  phase19_test_load()
  phase19_test_require(c(
    "phase19_load_fixture_club_training_snapshot",
    "phase19_load_fixture_current_ucl_club_snapshot",
    "phase19_validate_club_training_snapshot",
    "phase19_validate_current_ucl_club_snapshot",
    "phase19_assert_production_club_authority"
  ))
  root <- phase19_test_fixture_root("valid")
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)

  history <- phase19_load_fixture_club_training_snapshot(root, authority_mode = "fixture")
  expect_identical(history$status, "ready")
  expect_identical(history$authority_mode, "fixture")
  expect_true(history$fixture_authority)
  expect_identical(history$model_domain, "club")
  expect_equal(history$row_count, 6L)
  expect_equal(nrow(history$matches), 6L)
  expect_true(all(vapply(history$matches$counts_for_model,
                         phase18_history_logical, logical(1))))
  expect_true(all(grepl("^club_", history$matches$home_club_id)))
  expect_true(all(grepl("^[0-9a-f]{64}$", c(
    history$pointer_sha256, history$generation_manifest_sha256,
    history$corpus_manifest_sha256, history$matches_sha256,
    history$club_registry_sha256, history$source_manifest_sha256,
    history$snapshot_sha256
  ))))
  expect_silent(phase19_validate_club_training_snapshot(history, "fixture"))
  expect_error(
    phase19_assert_production_club_authority(history),
    class = "phase19_fixture_authority_error"
  )

  current <- phase19_load_fixture_current_ucl_club_snapshot(root, authority_mode = "fixture")
  expect_identical(current$status, "ready")
  expect_identical(current$authority_mode, "fixture")
  expect_true(current$fixture_authority)
  expect_false(current$promotion_eligible)
  expect_identical(current$accepted_status, "fixture_only")
  expect_identical(current$edition_id, "ucl_2026_27")
  expect_equal(current$club_count, 36L)
  expect_identical(current$clubs$club_id, sort(current$clubs$club_id, method = "radix"))
  expect_true(all(grepl("^[0-9a-f]{64}$", c(
    current$bundle_sha256, current$source_authority_sha256,
    current$identity_registry_sha256, current$roster_sha256,
    current$snapshot_sha256
  ))))
  expect_silent(phase19_validate_current_ucl_club_snapshot(current, "fixture"))
})

test_that("authority escalation national identity and arbitrary-path attacks fail closed", {
  phase19_test_load()
  root <- phase19_test_fixture_root("attacks")
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  snapshot <- phase19_load_fixture_club_training_snapshot(root, "fixture")

  expect_error(
    phase19_load_fixture_club_training_snapshot(root, "production"),
    class = "phase19_fixture_authority_error"
  )
  expect_error(
    phase19_load_club_training_snapshot(current_path = file.path(root, "history_current.json")),
    class = "phase19_arbitrary_authority_error"
  )
  expect_error(
    phase19_load_current_ucl_club_snapshot(
      accepted_root = file.path(root, "ucl_candidate")
    ),
    class = "phase19_arbitrary_authority_error"
  )
  outside <- file.path(phase19_domain_test_root, "tests")
  expect_error(
    phase19_load_fixture_club_training_snapshot(outside, "fixture"),
    class = "phase19_fixture_authority_error"
  )
  unmarked <- tempfile("phase19-unmarked-", tmpdir = tempdir())
  dir.create(unmarked)
  on.exit(unlink(unmarked, recursive = TRUE, force = TRUE), add = TRUE)
  expect_error(
    phase19_load_fixture_club_training_snapshot(unmarked, "fixture"),
    class = "phase19_fixture_authority_error"
  )

  national_domain <- snapshot
  national_domain$model_domain <- "national_team"
  expect_error(
    phase19_validate_club_training_snapshot(national_domain, "fixture"),
    class = "phase19_domain_mismatch"
  )
  national_identity <- snapshot
  national_identity$matches$home_club_id[[1L]] <- "AUT"
  national_identity$matches$row_sha256 <- phase18_history_row_sha256(national_identity$matches)
  expect_error(
    phase19_validate_club_training_snapshot(national_identity, "fixture"),
    class = "phase19_domain_mismatch"
  )
})

test_that("audit-only tampered tombstone and incomplete-current evidence cannot gain authority", {
  phase19_test_load()
  blocked_root <- phase19_test_fixture_root("audit-only", accepted_history = FALSE)
  on.exit(unlink(blocked_root, recursive = TRUE, force = TRUE), add = TRUE)
  blocked <- phase19_load_fixture_club_training_snapshot(blocked_root, "fixture")
  expect_identical(blocked$status, "blocked")
  expect_identical(blocked$reason_code, "no_accepted_club_history")

  tampered_history_root <- phase19_test_fixture_root("tampered-history")
  on.exit(unlink(tampered_history_root, recursive = TRUE, force = TRUE), add = TRUE)
  phase19_test_tamper_history(tampered_history_root)
  tampered_history <- phase19_load_fixture_club_training_snapshot(tampered_history_root, "fixture")
  expect_identical(tampered_history$status, "blocked")
  expect_identical(tampered_history$reason_code, "invalid_club_history_authority")

  incomplete_root <- phase19_test_fixture_root("incomplete-current", current_identity_complete = FALSE)
  on.exit(unlink(incomplete_root, recursive = TRUE, force = TRUE), add = TRUE)
  incomplete <- phase19_load_fixture_current_ucl_club_snapshot(incomplete_root, "fixture")
  expect_identical(incomplete$status, "blocked")
  expect_identical(incomplete$reason_code, "current_ucl_identity_incomplete")

  tampered_current_root <- phase19_test_fixture_root("tampered-current")
  on.exit(unlink(tampered_current_root, recursive = TRUE, force = TRUE), add = TRUE)
  phase19_test_tamper_current(tampered_current_root)
  tampered_current <- phase19_load_fixture_current_ucl_club_snapshot(tampered_current_root, "fixture")
  expect_identical(tampered_current$status, "blocked")
  expect_identical(tampered_current$reason_code, "invalid_current_ucl_authority")

  expect_identical(phase19_current_ucl_acceptance_reason("no_incumbent"), "no_accepted_current_ucl")
  expect_identical(phase19_current_ucl_acceptance_reason("unavailable_tombstone"), "no_accepted_current_ucl")
  expect_identical(phase19_current_ucl_acceptance_reason("accepted"), "")
})

test_that("focused runner rejects warning skip failure error empty and missing tests", {
  runner <- file.path(phase19_domain_test_root, "scripts/run_phase19_focused_test.R")
  expect_true(file.exists(runner))
  make_test <- function(label, body) {
    path <- tempfile(paste0("test_phase19_runner_", label, "_"), fileext = ".R")
    writeLines(c("library(testthat)", body), path, useBytes = TRUE)
    path
  }
  run <- function(paths) {
    output <- suppressWarnings(system2(
      file.path(R.home("bin"), "Rscript"), c("--vanilla", runner, paths),
      stdout = TRUE, stderr = TRUE
    ))
    list(status = if (is.null(attr(output, "status"))) 0L else as.integer(attr(output, "status")),
         output = output)
  }
  pass_a <- make_test("pass_a", "test_that('pass a', expect_true(TRUE))")
  pass_b <- make_test("pass_b", "test_that('pass b', expect_identical(1L, 1L))")
  warning <- make_test("warning", "test_that('warning', warning('bare warning'))")
  skipped <- make_test("skip", "test_that('skip', skip('not allowed'))")
  failure <- make_test("failure", "test_that('failure', expect_true(FALSE))")
  error <- make_test("error", "test_that('error', stop('boom'))")
  empty <- make_test("empty", "# deliberately no tests")

  expect_identical(run(c(pass_a, pass_b))$status, 0L)
  for (path in c(warning, skipped, failure, error, empty, tempfile("missing-phase19-"))) {
    expect_gt(run(path)$status, 0L)
  }
})
