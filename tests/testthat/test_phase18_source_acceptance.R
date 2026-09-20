library(testthat)

phase18_test_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/"
)

phase18_test_load <- function() {
  source_path <- file.path(phase18_test_root, "R/competition/ucl_source_acceptance.R")
  script_path <- file.path(phase18_test_root, "scripts/accept_ucl_provider.R")
  if (file.exists(source_path)) source(source_path, local = .GlobalEnv)
  if (file.exists(script_path)) sys.source(script_path, envir = .GlobalEnv)
  invisible(TRUE)
}

phase18_test_require <- function(functions) {
  missing <- functions[!vapply(functions, exists, logical(1), mode = "function")]
  if (length(missing)) {
    stop("Missing Phase 18 API: ", paste(missing, collapse = ", "), call. = FALSE)
  }
}

phase18_test_review <- function(review_set = "approved") {
  review <- utils::read.csv(
    file.path(phase18_test_root, "tests/fixtures/phase18/provider_terms_review.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  review <- review[review$review_set == review_set, setdiff(names(review), "review_set"), drop = FALSE]
  phase18_hash_terms_review(review)
}

phase18_test_expectations <- function() {
  expectations <- data.frame(
    schema_version = "phase18-edition-expectation-v1",
    edition_id = "ucl_2026_27",
    lifecycle = "league_phase",
    expected_club_count = 36L,
    expected_league_phase_match_count = 144L,
    allowed_stages = "LEAGUE_STAGE|PLAYOFFS|LAST_16|QUARTER_FINALS|SEMI_FINALS|FINAL",
    standings_required = TRUE,
    expected_standings_rows = 36L,
    reviewer = "fixture-reviewer",
    reviewed_at_utc = "2026-09-19T12:00:00Z",
    row_sha256 = "",
    expectation_sha256 = "",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  phase18_hash_edition_expectations(expectations)
}

phase18_test_machine_checks <- function(execution_mode = "offline_contract_test", passed = TRUE) {
  expectation_sha <- phase18_test_expectations()$expectation_sha256[[1L]]
  checks <- data.frame(
    schema_version = "phase18-machine-check-v1",
    capability = c("competition_metadata", "teams", "matches", "standings"),
    decision = "INTEGRATE",
    execution_mode = execution_mode,
    passed = passed,
    observed_count = c(1L, 36L, 144L, 36L),
    observed_stages = c("", "", "LEAGUE_STAGE", ""),
    expectation_sha256 = expectation_sha,
    live_run_id = if (identical(execution_mode, "live_acceptance_probe")) "live-fixture-001" else "",
    real_key_evidence = identical(execution_mode, "live_acceptance_probe"),
    freshness_passed = passed,
    identity_passed = passed,
    pagination_complete = passed,
    secret_scan_passed = passed,
    checked_at_utc = "2026-09-19T12:30:00Z",
    row_sha256 = "",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  phase18_hash_machine_checks(checks)
}

test_that("Phase 18 source-acceptance API seam exists", {
  phase18_test_load()
  phase18_test_require(c(
    "phase18_provider_preflight",
    "phase18_validate_terms_review",
    "phase18_validate_edition_expectations",
    "phase18_build_acceptance_manifest",
    "phase18_validate_acceptance_manifest",
    "phase18_accept_ucl_provider_main"
  ))
})

test_that("missing credential preflight is a durable fail-closed decision", {
  phase18_test_load()
  preflight <- phase18_provider_preflight(FALSE, "2026-09-19T12:00:00Z")
  expect_identical(preflight$decision, "not_run")
  expect_identical(preflight$reason_code, "missing_credential")
  expect_identical(preflight$credential_status, "absent")
  expect_false(preflight$automation_enabled)
  expect_match(preflight$row_sha256, "^[0-9a-f]{64}$")
})

test_that("no-key operator path never calls transport and emits a validating manifest", {
  phase18_test_load()
  evidence_root <- tempfile("phase18-no-key-")
  review_path <- file.path(phase18_test_root, "tests/fixtures/phase18/provider_terms_review.csv")
  transport_calls <- 0L
  result <- phase18_accept_ucl_provider_main(
    args = c(
      "--provider-id", "football_data_org_v4",
      "--edition-id", "ucl_2026_27",
      "--review-path", review_path,
      "--evidence-root", evidence_root
    ),
    token_present = FALSE,
    transport_fn = function(...) {
      transport_calls <<- transport_calls + 1L
      stop("transport must not be called")
    },
    now_utc = "2026-09-19T12:30:00Z"
  )
  expect_identical(transport_calls, 0L)
  expect_identical(result$manifest$decision, "not_run")
  expect_identical(result$manifest$reason_code, "missing_credential")
  expect_false(result$manifest$automation_enabled)
  manifest_path <- file.path(evidence_root, "football_data_org_v4", "ucl_2026_27", "acceptance_manifest.csv")
  expect_true(file.exists(manifest_path))
  persisted <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
  expect_silent(phase18_validate_acceptance_manifest(
    persisted,
    result$machine_checks,
    result$owner_review,
    result$edition_expectations
  ))
  expect_false(any(grepl("token|authorization|header|request", names(persisted), ignore.case = TRUE)))
})

test_that("offline evidence cannot bootstrap automation", {
  phase18_test_load()
  review <- phase18_test_review("approved")
  expectations <- phase18_test_expectations()
  machine <- phase18_test_machine_checks("offline_contract_test", TRUE)
  manifest <- phase18_build_acceptance_manifest(
    machine_checks = machine,
    owner_review = review,
    edition_expectations = expectations,
    evidence_hashes = list(schema_fingerprint_sha256 = paste(rep("d", 64L), collapse = "")),
    decision_id = "offline-proof-001",
    now_utc = "2026-09-19T12:30:00Z"
  )
  expect_false(manifest$automation_enabled)
  expect_identical(manifest$decision, "not_run")
  expect_identical(manifest$live_provider_decision, "not_run")
  expect_true(manifest$offline_contract_tests_passed)
  expect_silent(phase18_validate_acceptance_manifest(manifest, machine, review, expectations))
})

test_that("owner review validation is typed for approved pending rejected and malformed input", {
  phase18_test_load()
  approved <- phase18_validate_terms_review(phase18_test_review("approved"))
  pending <- phase18_validate_terms_review(phase18_test_review("pending"))
  rejected <- phase18_validate_terms_review(phase18_test_review("rejected"))
  malformed <- phase18_validate_terms_review(NULL)
  expect_true(approved$valid)
  expect_identical(approved$decision, "accepted")
  expect_false(pending$valid)
  expect_identical(pending$decision, "manual_only")
  expect_false(rejected$valid)
  expect_identical(rejected$decision, "rejected")
  expect_false(malformed$valid)
  expect_true(malformed$decision %in% c("manual_only", "rejected"))
})
