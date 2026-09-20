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
