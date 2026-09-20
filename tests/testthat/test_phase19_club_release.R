library(testthat)

phase19_release_test_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/", mustWork = TRUE
)

phase19_release_test_source <- function(relative_path, required = TRUE) {
  path <- file.path(phase19_release_test_root, relative_path)
  if (!file.exists(path)) {
    if (isTRUE(required)) stop("RED: missing Phase 19 release dependency: ", relative_path, call. = FALSE)
    return(invisible(FALSE))
  }
  source(path, local = .GlobalEnv)
  invisible(TRUE)
}

phase19_release_test_load <- function(require_release = TRUE) {
  phase19_release_test_source("R/common/phase18_canonical_hash.R")
  phase19_release_test_source("R/club/history_contract.R")
  phase19_release_test_source("R/club/model_contract.R")
  phase19_release_test_source("R/club/evaluation_protocol.R")
  phase19_release_test_source("R/club/evaluation.R")
  phase19_release_test_source("R/release/domain_contract.R", required = require_release)
  phase19_release_test_source("R/release/release_contract.R", required = require_release)
  phase19_release_test_source("R/club/release.R", required = require_release)
  phase19_release_test_source("tests/testthat/helper_phase19_club_fixture.R")
  invisible(TRUE)
}

phase19_release_test_require <- function(names) {
  missing <- names[!vapply(names, exists, logical(1), mode = "function")]
  if (length(missing)) stop("RED: missing Phase 19 release API: ", paste(missing, collapse = ", "), call. = FALSE)
  invisible(TRUE)
}

phase19_release_test_minimal_decision <- function() {
  structure(list(
    schema_version = "phase19-club-promotion-decision-v1",
    hash_encoding_version = phase18_canonical_encoding_v2(),
    forecast_domain = "club", authority_mode = "fixture", fixture_authority = TRUE,
    candidate_id = "club_elo_nb", incumbent_id = "club_venue_nb",
    selected_model_id = "club_elo_nb", diagnostic_gate_outcome = "pass",
    authority_eligibility = "fixture_ineligible", promotion_status = "ineligible_fixture",
    reason_codes = "", authority_reason_code = "fixture_ineligible",
    evaluation_set_sha256 = strrep("a", 64L),
    reproducibility_evidence_sha256 = strrep("b", 64L),
    authority_sha256 = strrep("c", 64L), protocol_sha256 = strrep("d", 64L),
    policy_review_sha256 = strrep("e", 64L), gate_registry_sha256 = strrep("f", 64L),
    seed_registry_sha256 = strrep("1", 64L), metrics_sha256 = strrep("2", 64L),
    integrity_sha256 = strrep("3", 64L), gate_results_sha256 = strrep("4", 64L),
    gate_results = data.frame(gate_order = integer(), gate_id = character(),
                              stringsAsFactors = FALSE), decision_sha256 = strrep("5", 64L)
  ), class = c("phase19_club_promotion_decision", "list"))
}

phase19_release_test_model <- function() {
  structure(list(
    schema_version = "phase19-club-goal-fit-v1", forecast_domain = "club",
    authority_mode = "fixture", fixture_authority = TRUE, promotion_eligible = FALSE,
    model_id = "club_elo_nb", model_family = "negative_binomial",
    fit_status = "converged", fallback_status = "none", fit_sha256 = strrep("6", 64L),
    training_snapshot_sha256 = strrep("7", 64L), current_snapshot_sha256 = strrep("8", 64L),
    protocol_sha256 = strrep("d", 64L), cutoff_utc = "2025-01-01T00:00:00Z",
    support_max = 40L, active_features = c("elo_difference_for_team", "venue_role")
  ), class = c("phase19_club_goal_fit", "list"))
}

phase19_release_test_calibrator <- function() {
  structure(list(
    schema_version = "phase19-club-calibrator-v1", forecast_domain = "club",
    authority_mode = "fixture", fixture_authority = TRUE, promotion_eligible = FALSE,
    model_id = "club_elo_nb", candidate_id = "club_elo_nb", calibrator_id = "fixture-calibrator",
    fit_status = "fitted", distribution_unchanged = TRUE, calibrator_sha256 = strrep("9", 64L),
    protocol_sha256 = strrep("d", 64L), calibration_data_cutoff = "2025-01-01T00:00:00Z"
  ), class = c("phase19_club_calibrator", "list"))
}

phase19_release_test_stage <- function(label = "fixture") {
  root <- tempfile(paste0("phase19-release-", label, "-"))
  dir.create(root, recursive = TRUE)
  staged <- phase19_stage_fixture_club_release(
    decision = phase19_release_test_minimal_decision(),
    model = phase19_release_test_model(), calibrator = phase19_release_test_calibrator(),
    output_root = root, release_id = paste0("fixture-", label),
    history_snapshot = list(snapshot_sha256 = strrep("7", 64L), accepted_generation_id = "fixture-history"),
    current_snapshot = list(snapshot_sha256 = strrep("8", 64L), generation_id = "fixture-current")
  )
  list(root = root, staged = staged)
}

test_that("fixture club release APIs are present and the shared guard is strict", {
  phase19_release_test_load(require_release = TRUE)
  phase19_release_test_require(c(
    "assert_forecast_domain", "phase19_club_release_required_artifacts",
    "stage_phase19_fixture_release", "validate_phase19_club_release",
    "install_phase19_club_release", "read_phase19_club_selector",
    "resolve_phase19_club_release"
  ))
  expect_silent(assert_forecast_domain(list(forecast_domain = "club"), "club"))
  expect_error(assert_forecast_domain(list(forecast_domain = "national_team"), "club"),
               class = "phase19_domain_error")
})

test_that("fixture release round trip validates before and after object load", {
  phase19_release_test_load(require_release = TRUE)
  phase19_release_test_require(c(
    "phase19_stage_fixture_club_release", "phase19_validate_club_release",
    "phase19_install_club_release", "phase19_read_club_selector",
    "phase19_resolve_club_release"
  ))
  root <- tempfile("phase19-release-fixture-")
  dir.create(root, recursive = TRUE)
  staged <- phase19_stage_fixture_club_release(
    decision = phase19_release_test_minimal_decision(),
    model = phase19_release_test_model(), calibrator = phase19_release_test_calibrator(),
    output_root = root, release_id = "fixture-release-v1",
    history_snapshot = list(snapshot_sha256 = strrep("7", 64L), accepted_generation_id = "fixture-history"),
    current_snapshot = list(snapshot_sha256 = strrep("8", 64L), generation_id = "fixture-current")
  )
  expect_true(dir.exists(staged$release_root))
  expect_silent(phase19_validate_club_release(staged$release_root, load_models = FALSE,
                                              expected_domain = "club"))
  installed <- phase19_install_club_release(staged$release_root,
                                            file.path(root, "approved"))
  selector <- phase19_read_club_selector(installed$selector_path,
                                         file.path(root, "approved"))
  expect_identical(selector$forecast_domain, "club")
  resolved <- phase19_resolve_club_release(file.path(root, "approved"))
  expect_identical(resolved$model$model_id, "club_elo_nb")
  expect_identical(resolved$calibrator$model_id, "club_elo_nb")
})

test_that("fixture authority cannot be staged through the production writer", {
  phase19_release_test_load(require_release = TRUE)
  phase19_release_test_require("phase19_stage_production_club_release")
  expect_error(
    phase19_stage_production_club_release(
      decision = phase19_release_test_minimal_decision(),
      model = phase19_release_test_model(), calibrator = phase19_release_test_calibrator(),
      output_root = tempfile("phase19-production-release-")
    ),
    class = "phase19_club_release_error"
  )
})

test_that("fixture release rejects traversal, surplus, missing, symlink, and hash attacks", {
  phase19_release_test_load(require_release = TRUE)
  fixture <- phase19_release_test_stage("attacks")
  extra <- file.path(fixture$staged$release_root, "extra.txt")
  writeLines("extra", extra)
  expect_error(phase19_validate_club_release(fixture$staged$release_root, FALSE),
               class = "phase19_club_release_error")

  fixture <- phase19_release_test_stage("missing")
  unlink(file.path(fixture$staged$release_root, "limitations.md"))
  expect_error(phase19_validate_club_release(fixture$staged$release_root, FALSE),
               class = "phase19_club_release_error")

  fixture <- phase19_release_test_stage("hash")
  writeLines(c("tampered"), file.path(fixture$staged$release_root, "reports/model_card.md"))
  expect_error(phase19_validate_club_release(fixture$staged$release_root, FALSE),
               class = "phase19_club_release_error")

  fixture <- phase19_release_test_stage("traversal")
  manifest <- utils::read.csv(file.path(fixture$staged$release_root, "release_manifest.csv"),
                              stringsAsFactors = FALSE, check.names = FALSE,
                              colClasses = "character", na.strings = character())
  manifest$relative_path[manifest$artifact == "limitations.md"] <- "../limitations.md"
  utils::write.csv(manifest, file.path(fixture$staged$release_root, "release_manifest.csv"),
                   row.names = FALSE, na = "", quote = TRUE)
  expect_error(phase19_validate_club_release(fixture$staged$release_root, FALSE),
               class = "phase19_club_release_error")

  fixture <- phase19_release_test_stage("symlink")
  link <- file.path(fixture$staged$release_root, "reports/link.md")
  expect_true(file.symlink("model_card.md", link))
  expect_error(phase19_validate_club_release(fixture$staged$release_root, FALSE),
               class = "phase19_club_release_error")
})

test_that("preflight is metadata-first and object/selector identities are checked", {
  phase19_release_test_load(require_release = TRUE)
  fixture <- phase19_release_test_stage("identity")
  expect_silent(phase19_validate_club_release(fixture$staged$release_root, FALSE))
  installed <- phase19_install_club_release(fixture$staged$release_root,
                                            file.path(fixture$root, "approved"))
  before <- readBin(installed$selector_path, "raw", file.info(installed$selector_path)$size)
  selector <- utils::read.csv(installed$selector_path, stringsAsFactors = FALSE,
                              check.names = FALSE, colClasses = "character",
                              na.strings = character())
  selector$release_id <- "fixture-other"
  utils::write.csv(selector, installed$selector_path, row.names = FALSE, na = "", quote = TRUE)
  expect_error(phase19_read_club_selector(installed$selector_path,
                                           file.path(fixture$root, "approved")),
               class = "phase19_club_release_error")
  writeBin(before, installed$selector_path)
  expect_silent(phase19_read_club_selector(installed$selector_path,
                                           file.path(fixture$root, "approved")))

  # A corrupt RDS is rejected by the metadata/hash preflight without a readRDS call.
  writeBin(charToRaw("not-an-rds"), file.path(installed$release_root, "model/approved_model.rds"))
  expect_error(phase19_validate_club_release(installed$release_root, FALSE),
               class = "phase19_club_release_error")
})

test_that("lock and validation failures preserve the prior selector and bytes", {
  phase19_release_test_load(require_release = TRUE)
  fixture <- phase19_release_test_stage("rollback")
  installed <- phase19_install_club_release(fixture$staged$release_root,
                                            file.path(fixture$root, "approved"))
  selector_before <- readBin(installed$selector_path, "raw", file.info(installed$selector_path)$size)
  second <- phase19_release_test_stage("rollback-second")
  lock <- file.path(fixture$root, "approved", ".approved_release.lock")
  file.create(lock)
  expect_error(phase19_install_club_release(second$staged$release_root,
                                             file.path(fixture$root, "approved")),
               class = "phase19_club_release_error")
  unlink(lock)
  expect_identical(readBin(installed$selector_path, "raw", file.info(installed$selector_path)$size), selector_before)

  third <- phase19_release_test_stage("rollback-third")
  calls <- 0L
  failing_validator <- function(root, load_models = TRUE, expected_domain = "club") {
    calls <<- calls + 1L
    if (isTRUE(load_models)) stop("injected load failure", call. = FALSE)
    phase19_validate_club_release(root, load_models = load_models, expected_domain = expected_domain)
  }
  expect_error(phase19_install_club_release(third$staged$release_root,
                                             file.path(fixture$root, "approved"),
                                             validator = failing_validator),
               class = "error")
  expect_true(calls >= 3L)
  expect_identical(readBin(installed$selector_path, "raw", file.info(installed$selector_path)$size), selector_before)
})
