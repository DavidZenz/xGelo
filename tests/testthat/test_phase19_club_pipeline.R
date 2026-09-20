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

phase19_pipeline_manifest <- function() {
  withr::local_dir(phase19_pipeline_root)
  targets::tar_manifest(
    fields = c(name, command, format), callr_function = NULL,
    script = "_targets.R"
  )
}

test_that("the target manifest contains a validated club-only authority chain", {
  manifest <- phase19_pipeline_manifest()
  expected <- c(
    "club_history_pointer_file", "club_history_authority",
    "club_current_ucl_source_file", "club_current_ucl_authority",
    "club_identity_authority", "club_policy_review_files",
    "club_fold_registry_file", "club_fold_review_file",
    "club_protocol_authority", "club_rating_replay",
    "club_model_candidates", "club_fold_predictions", "club_fold_scores",
    "club_evaluation_set", "club_promotion_decision", "club_release_state",
    "club_selector_state"
  )
  expect_true(all(expected %in% manifest$name))
  club <- manifest[grepl("^club_", manifest$name), , drop = FALSE]
  forbidden <- "phase12_approved_release|phase14|national|fifa|worldcup|euro"
  expect_false(any(grepl(forbidden, club$command, ignore.case = TRUE)))
  expect_true(grepl("club_history_authority", manifest$command[manifest$name == "club_protocol_authority"]))
  expect_true(grepl("club_current_ucl_authority", manifest$command[manifest$name == "club_protocol_authority"]))
  expect_true(grepl("club_protocol_authority", manifest$command[manifest$name == "club_rating_replay"]))
  expect_true(grepl("club_fold_scores", manifest$command[manifest$name == "club_evaluation_set"]))
  expect_true(grepl("club_promotion_decision", manifest$command[manifest$name == "club_release_state"]))
})

test_that("blocked club targets complete truthfully without release or selector files", {
  skip_if_not_installed("targets")
  withr::local_dir(phase19_pipeline_root)
  targets::tar_make(
    names = c("club_release_state", "club_selector_state"),
    callr_function = NULL, script = "_targets.R",
    reporter = "silent"
  )
  decision <- targets::tar_read(club_promotion_decision, store = file.path(phase19_pipeline_root, "_targets"))
  release <- targets::tar_read(club_release_state, store = file.path(phase19_pipeline_root, "_targets"))
  selector <- targets::tar_read(club_selector_state, store = file.path(phase19_pipeline_root, "_targets"))
  expect_identical(decision$status, "blocked")
  expect_true(decision$reason_code %in% c(
    "no_accepted_club_history", "no_accepted_current_ucl",
    "current_ucl_identity_incomplete", "protocol_policy_not_approved",
    "fold_inventory_not_approved"
  ))
  expect_identical(release$status, "blocked")
  expect_identical(selector$status, "blocked")
  expect_false(file.exists(file.path(phase19_pipeline_root, "outputs/releases/club/approved_release.csv")))
})

test_that("club file targets are explicit and downstream invalidation parents are visible", {
  manifest <- phase19_pipeline_manifest()
  file_targets <- c(
    "club_history_pointer_file", "club_current_ucl_source_file",
    "club_policy_review_files", "club_fold_registry_file", "club_fold_review_file"
  )
  rows <- manifest[match(file_targets, manifest$name), , drop = FALSE]
  expect_true(all(as.character(rows$format) == "file"))
  expect_true(grepl("club_current_ucl_source_file", manifest$command[manifest$name == "club_current_ucl_authority"]))
  expect_true(grepl("club_current_ucl_authority", manifest$command[manifest$name == "club_identity_authority"]))
  expect_true(grepl("club_identity_authority", manifest$command[manifest$name == "club_fold_authority"]))
})
