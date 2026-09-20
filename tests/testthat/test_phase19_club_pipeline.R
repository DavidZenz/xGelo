library(testthat)

phase19_pipeline_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/", mustWork = TRUE
)

source(file.path(phase19_pipeline_root, "tests/testthat/helper_phase19_club_fixture.R"),
       local = .GlobalEnv)
phase19_test_load()
source(file.path(phase19_pipeline_root, "R/club/release.R"), local = .GlobalEnv)

phase19_pipeline_cli <- function(arguments = character()) {
  script <- file.path(phase19_pipeline_root, "scripts/run_phase19_club_evaluation.R")
  output <- suppressWarnings(system2(
    file.path(R.home("bin"), "Rscript"),
    c("--vanilla", script, arguments),
    stdout = TRUE, stderr = TRUE
  ))
  status <- attr(output, "status")
  if (is.null(status)) status <- 0L
  list(status = as.integer(status), output = output,
       text = paste(output, collapse = "\n"))
}

phase19_pipeline_tmp_dir <- function(label) {
  root <- tempfile(paste0("phase19-pipeline-", label, "-"), tmpdir = tempdir())
  dir.create(root, recursive = TRUE)
  root
}

test_that("the production controller is an explicit fail-closed entrypoint", {
  output_path <- file.path(phase19_pipeline_root, "outputs/club_model/blocked/phase19-production-blocked.json")
  selector_path <- file.path(phase19_pipeline_root, "outputs/releases/club/approved_release.csv")
  before <- if (file.exists(output_path)) readBin(output_path, "raw", file.info(output_path)$size) else NULL
  result <- phase19_pipeline_cli()
  expect_identical(result$status, 0L)
  expect_match(result$text, "no_accepted_club_history", fixed = TRUE)
  expect_match(result$text, "human_needed", fixed = TRUE)
  expect_false(file.exists(selector_path))
  if (is.null(before) && file.exists(output_path)) unlink(output_path, force = TRUE)
  if (!is.null(before) && file.exists(output_path)) {
    expect_identical(readBin(output_path, "raw", file.info(output_path)$size), before)
  }
})

test_that("explicit fixture mode completes through an isolated fixture release", {
  fixture_root <- phase19_test_fixture_root("pipeline-cli")
  output_root <- phase19_pipeline_tmp_dir("output")
  release_root <- phase19_pipeline_tmp_dir("release")
  on.exit(unlink(c(fixture_root, output_root, release_root), recursive = TRUE, force = TRUE), add = TRUE)

  result <- phase19_pipeline_cli(c(
    "--fixture", "--fixture-root", fixture_root,
    "--output-root", output_root, "--release-root", release_root
  ))
  expect_identical(result$status, 0L)
  expect_match(result$text, "fixture_ineligible", fixed = TRUE)
  expect_match(result$text, "ineligible_fixture", fixed = TRUE)
  result_file <- file.path(output_root, "phase19-fixture-result.json")
  expect_true(file.exists(result_file))
  result_record <- jsonlite::fromJSON(result_file, simplifyVector = TRUE)
  expect_identical(result_record$forecast_domain, "club")
  expect_identical(result_record$authority_mode, "fixture")
  expect_true(isTRUE(result_record$fixture_authority))
  expect_identical(result_record$promotion_status, "ineligible_fixture")
  expect_true(file.exists(file.path(release_root, "approved_release.csv")))
  resolved <- phase19_resolve_club_release(release_root)
  expect_identical(resolved$forecast_domain, "club")
  expect_identical(resolved$model_contract$authority_mode, "fixture")
  expect_false(isTRUE(resolved$model_contract$production_eligible))
})

test_that("mode, root, domain, and mixed-root attacks fail before publication", {
  fixture_root <- phase19_test_fixture_root("pipeline-attacks")
  output_root <- phase19_pipeline_tmp_dir("attack-output")
  release_root <- phase19_pipeline_tmp_dir("attack-release")
  on.exit(unlink(c(fixture_root, output_root, release_root), recursive = TRUE, force = TRUE), add = TRUE)
  production_root <- file.path(phase19_pipeline_root, "outputs/releases/club")

  bad_calls <- list(
    missing_fixture_flag = c("--fixture-root", fixture_root,
                             "--output-root", output_root, "--release-root", release_root),
    production_output = c("--fixture", "--fixture-root", fixture_root,
                          "--output-root", production_root, "--release-root", release_root),
    mixed_release = c("--fixture", "--fixture-root", fixture_root,
                      "--output-root", output_root, "--release-root", production_root),
    national_input = c("--fixture", "--fixture-root", fixture_root,
                       "--output-root", output_root, "--release-root", release_root,
                       "--national-selector", "outputs/releases/approved_release.csv"),
    unknown_mode = c("--production", "--fixture-root", fixture_root)
  )
  for (name in names(bad_calls)) {
    result <- phase19_pipeline_cli(bad_calls[[name]])
    expect_true(result$status != 0L, info = name)
    expect_false(file.exists(file.path(release_root, "approved_release.csv")), info = name)
  }
})

test_that("repeated fixture and blocked executions are deterministic and credential-free", {
  fixture_root <- phase19_test_fixture_root("pipeline-idempotence")
  output_one <- phase19_pipeline_tmp_dir("idempotence-one")
  release_one <- phase19_pipeline_tmp_dir("idempotence-release-one")
  output_two <- phase19_pipeline_tmp_dir("idempotence-two")
  release_two <- phase19_pipeline_tmp_dir("idempotence-release-two")
  on.exit(unlink(c(fixture_root, output_one, release_one, output_two, release_two), recursive = TRUE, force = TRUE), add = TRUE)
  args <- function(output, release) c(
    "--fixture", "--fixture-root", fixture_root,
    "--output-root", output, "--release-root", release
  )
  first <- phase19_pipeline_cli(args(output_one, release_one))
  second <- phase19_pipeline_cli(args(output_two, release_two))
  expect_identical(first$status, 0L)
  expect_identical(second$status, 0L)
  first_record <- jsonlite::fromJSON(file.path(output_one, "phase19-fixture-result.json"), simplifyVector = TRUE)
  second_record <- jsonlite::fromJSON(file.path(output_two, "phase19-fixture-result.json"), simplifyVector = TRUE)
  expect_identical(first_record[c("status", "reason_code", "diagnostic_gate_outcome",
                                  "authority_eligibility", "promotion_status", "release_id")],
                   second_record[c("status", "reason_code", "diagnostic_gate_outcome",
                                   "authority_eligibility", "promotion_status", "release_id")])
  expect_false(grepl("token|secret|credential|/Users/|phase12|national", first$text,
                     ignore.case = TRUE))
})
