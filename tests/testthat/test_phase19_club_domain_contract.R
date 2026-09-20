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

phase19_test_feature_schema <- function() {
  c(
    "schema_version", "hash_encoding_version", "forecast_domain", "feature_id",
    "availability_status", "reason_code", "source_contract_id",
    "source_contract_sha256", "value_type", "value", "observed_at_utc",
    "cutoff_status", "required_by_model", "active_in_model",
    "imputation_policy", "row_sha256"
  )
}

phase19_test_rehash_feature_contract <- function(contract) {
  contract$row_sha256 <- phase19_feature_row_sha256(contract)
  contract
}

phase19_test_accepted_source_contract <- function(feature_id = "injury") {
  contract <- data.frame(
    schema_version = "phase19-club-feature-source-contract-v1",
    hash_encoding_version = "phase18-canonical-v2",
    forecast_domain = "club",
    feature_id = feature_id,
    source_contract_id = paste0("accepted_", feature_id, "_v1"),
    decision = "accepted",
    accepted_at_utc = "2026-09-20T00:00:00Z",
    contract_sha256 = "",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  contract$contract_sha256 <- phase18_hash_row_v2(
    contract,
    schema_tag = "phase19-club-feature-source-contract-v1"
  )
  contract
}

test_that("committed enrichment registry is exact unavailable club evidence", {
  phase19_test_load()
  phase19_test_require(c(
    "phase19_load_feature_contract", "phase19_validate_feature_contract",
    "phase19_feature_contract_sha256", "phase19_feature_row_sha256"
  ))
  contract <- phase19_load_feature_contract()

  expect_identical(names(contract), phase19_test_feature_schema())
  expect_identical(
    as.character(contract$feature_id),
    c("current_xg", "injury", "lineup", "suspension", "player")
  )
  expect_identical(anyDuplicated(contract$feature_id), 0L)
  expect_true(all(contract$schema_version == "phase19-club-feature-v1"))
  expect_true(all(contract$hash_encoding_version == "phase18-canonical-v2"))
  expect_true(all(contract$forecast_domain == "club"))
  expect_true(all(contract$availability_status == "unavailable"))
  expect_true(all(contract$reason_code == "no_accepted_source_contract"))
  expect_true(all(contract$source_contract_id == ""))
  expect_true(all(contract$source_contract_sha256 == ""))
  expect_true(all(contract$value_type == "unavailable"))
  expect_true(all(contract$value == ""))
  expect_true(all(contract$observed_at_utc == ""))
  expect_true(all(contract$cutoff_status == "not_applicable"))
  expect_true(all(!contract$required_by_model))
  expect_true(all(!contract$active_in_model))
  expect_true(all(contract$imputation_policy == "forbidden"))
  expect_identical(contract$row_sha256, phase19_feature_row_sha256(contract))
  expect_true(grepl("^[0-9a-f]{64}$", phase19_feature_contract_sha256(contract)))
  expect_silent(phase19_validate_feature_contract(contract))
})

test_that("unavailable enrichment omission mutation activation and formula attacks fail", {
  phase19_test_load()
  contract <- phase19_load_feature_contract()
  attacks <- list(
    omission = contract[-1L, , drop = FALSE],
    duplication = rbind(contract, contract[1L, , drop = FALSE]),
    unknown = transform(contract, feature_id = replace(feature_id, 1L, "weather")),
    reorder = contract[rev(seq_len(nrow(contract))), , drop = FALSE],
    zero_fill = transform(contract, value = replace(value, 1L, "0")),
    activated = transform(contract, active_in_model = replace(active_in_model, 1L, TRUE)),
    unsupported_source = transform(
      contract,
      source_contract_id = replace(source_contract_id, 1L, "claimed-current-xg-v1"),
      source_contract_sha256 = replace(source_contract_sha256, 1L, paste(rep("a", 64L), collapse = ""))
    ),
    row_hash_drift = transform(contract, row_sha256 = replace(row_sha256, 1L, paste(rep("b", 64L), collapse = "")))
  )
  attacks$unknown <- phase19_test_rehash_feature_contract(attacks$unknown)
  attacks$zero_fill <- phase19_test_rehash_feature_contract(attacks$zero_fill)
  attacks$activated <- phase19_test_rehash_feature_contract(attacks$activated)
  attacks$unsupported_source <- phase19_test_rehash_feature_contract(attacks$unsupported_source)

  for (name in names(attacks)) {
    expect_error(
      phase19_validate_feature_contract(attacks[[name]]),
      class = "phase19_feature_contract_error",
      info = name
    )
  }
  expect_error(
    phase19_validate_feature_formula(~ elo_diff + injury, contract),
    class = "phase19_feature_contract_error"
  )
  expect_silent(phase19_validate_feature_formula(~ elo_diff + competition_form, contract))
})

test_that("only a separately accepted hash-valid source contract can activate a feature", {
  phase19_test_load()
  contract <- phase19_load_feature_contract()
  source_contract <- phase19_test_accepted_source_contract("injury")
  row <- match("injury", contract$feature_id)
  contract$availability_status[[row]] <- "available"
  contract$reason_code[[row]] <- "accepted_source_contract"
  contract$source_contract_id[[row]] <- source_contract$source_contract_id[[1L]]
  contract$source_contract_sha256[[row]] <- source_contract$contract_sha256[[1L]]
  contract$value_type[[row]] <- "numeric"
  contract$value[[row]] <- "1"
  contract$observed_at_utc[[row]] <- "2026-09-19T12:00:00Z"
  contract$cutoff_status[[row]] <- "before_cutoff"
  contract$required_by_model[[row]] <- TRUE
  contract$active_in_model[[row]] <- TRUE
  contract <- phase19_test_rehash_feature_contract(contract)

  expect_silent(phase19_validate_feature_contract(
    contract,
    accepted_source_contracts = list(source_contract)
  ))
  expect_silent(phase19_validate_feature_formula(~ elo_diff + injury, contract))

  forged <- source_contract
  forged$accepted_at_utc[[1L]] <- "2026-09-21T00:00:00Z"
  expect_error(
    phase19_validate_feature_contract(contract, list(forged)),
    class = "phase19_feature_contract_error"
  )
})

test_that("fixture projections carry every typed unavailable row without numeric invention", {
  phase19_test_load()
  contract <- phase19_load_feature_contract()
  fixtures <- data.frame(
    fixture_id = c("ucl_2026_27-league-0001", "ucl_2026_27-league-0002"),
    forecast_domain = "club",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  projected <- phase19_project_feature_evidence(fixtures, contract)

  expect_equal(nrow(projected), 10L)
  expect_identical(names(projected), c("fixture_id", phase19_test_feature_schema()))
  expect_identical(
    split(as.character(projected$feature_id), projected$fixture_id),
    setNames(rep(list(as.character(contract$feature_id)), 2L), fixtures$fixture_id)
  )
  expect_true(all(projected$availability_status == "unavailable"))
  expect_true(all(projected$value_type == "unavailable"))
  expect_true(all(projected$value == ""))
  expect_false(any(vapply(projected, is.numeric, logical(1))))

  bad_fixtures <- fixtures
  bad_fixtures$forecast_domain[[1L]] <- "national_team"
  expect_error(
    phase19_project_feature_evidence(bad_fixtures, contract),
    class = "phase19_domain_mismatch"
  )
})
