library(testthat)

phase14_release_test_project_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/",
  mustWork = TRUE
)

source(file.path(phase14_release_test_project_root, "tests/testthat/helper_phase14_release.R"))
source(file.path(phase14_release_test_project_root, "R/calibration/calibration_selection.R"))

phase14_release_test_source_if_present <- function(relative_path) {
  path <- file.path(phase14_release_test_project_root, relative_path)
  if (file.exists(path)) source(path, local = .GlobalEnv)
  invisible(TRUE)
}

phase14_release_test_source_if_present("R/release/calibration_revision.R")
phase14_release_test_source_if_present("R/competition/edition_registry.R")

phase14_release_test_require_api <- function(required, owner) {
  missing <- required[!vapply(required, exists, logical(1), mode = "function")]
  if (length(missing)) {
    skip(paste0(
      "Wave 0 guard awaits the ", owner, " API: ",
      paste(missing, collapse = ", ")
    ))
  }
  invisible(TRUE)
}

phase14_release_test_cache <- new.env(parent = emptyenv())

phase14_release_test_fixture <- function(kind = c("raw", "fitted")) {
  kind <- match.arg(kind)
  if (!exists(kind, envir = phase14_release_test_cache, inherits = FALSE)) {
    descriptor <- file.path(
      phase14_release_test_project_root,
      "tests/fixtures/phase14",
      if (identical(kind, "raw")) "raw_release" else "calibrated_release"
    )
    trusted_root <- tempfile(paste0("phase14-", kind, "-release-root-"))
    dir.create(trusted_root, recursive = TRUE)
    assign(
      kind,
      phase14_materialize_release_fixture_root(descriptor, trusted_root),
      envir = phase14_release_test_cache
    )
  }
  get(kind, envir = phase14_release_test_cache, inherits = FALSE)
}

phase14_release_test_read_bytes <- function(path) {
  readBin(path, what = "raw", n = file.info(path)$size)
}

phase14_release_test_write_bytes <- function(path, bytes) {
  connection <- file(path, open = "wb")
  on.exit(close(connection), add = TRUE)
  writeBin(bytes, connection)
  invisible(path)
}

phase14_release_test_rebind_selector <- function(fixture) {
  manifest <- phase14_release_fixture_refresh_manifest(fixture$release_root)
  selector <- utils::read.csv(
    fixture$selector_path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    colClasses = "character",
    na.strings = character()
  )
  selector$manifest_sha256 <- phase12_release_file_sha256(fixture$release_manifest_path)
  selector$row_sha256 <- phase14_release_fixture_selector_hash(selector)
  phase12_release_write_csv(selector, fixture$selector_path)
  invisible(manifest)
}

phase14_release_test_failed_comparison <- function() {
  list(
    candidate_id = "open_nb_incumbent",
    track_id = "updating",
    raw_headline = c(rps = 0.20, brier = 0.20, log_loss = 0.60),
    calibrated_headline = c(rps = 0.20, brier = 0.20, log_loss = 0.60),
    raw_calibration_values = list(calibration_error = 0.05),
    calibrated_calibration_values = list(calibration_error = 0.05),
    paired_rps = list(
      breadth = data.frame(maximum_fold_regression = 0),
      bootstrap = data.frame(estimate = 0, lower = 0, upper = 0)
    ),
    calibration_support_valid = TRUE,
    coverage_valid = TRUE,
    coverage_numerator = 2L,
    coverage_denominator = 2L,
    distribution_unchanged = TRUE,
    identity = list(score_distribution_identity_match = TRUE)
  )
}

phase14_release_test_gate_fields <- function(result) {
  if (is.data.frame(result)) return(result[1L, , drop = FALSE])
  if (is.list(result) && is.data.frame(result$gate)) return(result$gate[1L, , drop = FALSE])
  if (is.list(result) && is.list(result$decision)) return(result$decision)
  result
}

test_that("14-02 release descriptors distinguish raw fallback from fitted calibration", {
  raw <- phase14_release_fixture_descriptor(file.path(
    phase14_release_test_project_root,
    "tests/fixtures/phase14/raw_release"
  ))
  fitted <- phase14_release_fixture_descriptor(file.path(
    phase14_release_test_project_root,
    "tests/fixtures/phase14/calibrated_release"
  ))

  expect_identical(as.integer(raw$contract$support_max), 40L)
  expect_identical(as.integer(fitted$contract$support_max), 40L)
  expect_identical(as.character(raw$contract$calibrator$fit_status), "raw_fallback")
  expect_identical(as.character(raw$contract$primary_probability_view), "raw_1x2")
  expect_false(isTRUE(raw$contract$calibration_gate$passed))
  expect_identical(as.character(fitted$contract$calibrator$fit_status), "fitted")
  expect_identical(as.character(fitted$contract$primary_probability_view), "calibrated_1x2")
  expect_true(isTRUE(fitted$contract$calibration_gate$passed))
  expect_false(identical(raw$contract$release_id, fitted$contract$release_id))
  expect_false(identical(raw$contract$calibrator$sha256, fitted$contract$calibrator$sha256))
  expect_invisible(phase14_assert_no_binary_release_fixtures(file.path(
    phase14_release_test_project_root,
    "tests/fixtures/phase14"
  )))
})

test_that("14-02 descriptor pairs materialize complete hash-valid selected roots", {
  raw <- phase14_release_test_fixture("raw")
  fitted <- phase14_release_test_fixture("fitted")

  expect_invisible(phase14_validate_release_fixture_root(raw$trusted_root))
  expect_invisible(phase14_validate_release_fixture_root(fitted$trusted_root))
  expect_identical(raw$model_sha256, fitted$model_sha256)
  expect_false(identical(raw$calibrator_sha256, fitted$calibrator_sha256))
  expect_false(identical(raw$release_manifest_sha256, fitted$release_manifest_sha256))
  expect_false(identical(raw$selector_self_sha256, fitted$selector_self_sha256))
  expect_identical(raw$primary_probability_view, "raw_1x2")
  expect_identical(fitted$primary_probability_view, "calibrated_1x2")
  expect_identical(fitted$fit_status, "fitted")
  expect_identical(fitted$model_data_cutoff, "2026-06-10")
  expect_identical(fitted$calibration_data_cutoff, "2024-07-14")
})

test_that("14-02 selector, calibrator, gate, and label forgeries fail closed", {
  fitted <- phase14_release_test_fixture("fitted")

  selector_bytes <- phase14_release_test_read_bytes(fitted$selector_path)
  selector <- utils::read.csv(
    fitted$selector_path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    colClasses = "character"
  )
  selector$manifest_sha256 <- strrep("0", 64L)
  phase12_release_write_csv(selector, fitted$selector_path)
  expect_error(
    phase14_validate_release_fixture_root(fitted$trusted_root),
    "selector self-hash"
  )
  phase14_release_test_write_bytes(fitted$selector_path, selector_bytes)

  calibrator_path <- file.path(fitted$release_root, "model/calibrator.rds")
  calibrator_bytes <- phase14_release_test_read_bytes(calibrator_path)
  writeBin(charToRaw("forged calibrator bytes"), calibrator_path)
  expect_error(
    phase14_validate_release_fixture_root(fitted$trusted_root),
    "artifact hash|calibrator artifact hash"
  )
  phase14_release_test_write_bytes(calibrator_path, calibrator_bytes)

  manifest_bytes <- phase14_release_test_read_bytes(fitted$release_manifest_path)
  selector_bytes <- phase14_release_test_read_bytes(fitted$selector_path)
  contract_path <- file.path(fitted$release_root, "model_contract.json")
  contract_bytes <- phase14_release_test_read_bytes(contract_path)
  calibrator <- readRDS(calibrator_path)
  calibrator$calibration_gate_passed <- FALSE
  phase12_release_write_rds(calibrator, calibrator_path)
  contract <- phase12_release_read_contract(contract_path)
  contract$calibrator_sha256 <- phase12_release_file_sha256(calibrator_path)
  phase12_release_write_json(contract, contract_path)
  phase14_release_test_rebind_selector(fitted)
  expect_error(
    phase14_validate_release_fixture_root(fitted$trusted_root),
    "fitted calibrator and passing gate"
  )
  phase14_release_test_write_bytes(calibrator_path, calibrator_bytes)
  phase14_release_test_write_bytes(contract_path, contract_bytes)
  phase14_release_test_write_bytes(fitted$release_manifest_path, manifest_bytes)
  phase14_release_test_write_bytes(fitted$selector_path, selector_bytes)
  expect_invisible(phase14_validate_release_fixture_root(fitted$trusted_root))

  descriptor_root <- tempfile("phase14-final-label-descriptor-")
  dir.create(descriptor_root, recursive = TRUE)
  source_descriptor <- file.path(
    phase14_release_test_project_root,
    "tests/fixtures/phase14/calibrated_release"
  )
  expect_true(all(file.copy(
    list.files(source_descriptor, full.names = TRUE),
    descriptor_root
  )))
  contract_path <- file.path(descriptor_root, "model_contract.json")
  contract <- jsonlite::fromJSON(contract_path, simplifyVector = FALSE)
  contract$calibrator$source_path <- "final_evaluation/labels.csv"
  jsonlite::write_json(contract, contract_path, auto_unbox = TRUE, pretty = TRUE)
  expect_error(
    phase14_release_fixture_descriptor(descriptor_root),
    "final-label lineage"
  )
})

test_that("14-02 explicit selector remains exact when directory discovery is ambiguous", {
  raw <- phase14_release_test_fixture("raw")
  ambiguous <- file.path(raw$trusted_root, "unselected-release")
  dir.create(ambiguous)
  expect_true(file.copy(raw$release_manifest_path, file.path(ambiguous, "release_manifest.csv")))

  expect_invisible(phase14_validate_release_fixture_root(raw$trusted_root))
  expect_error(
    preflight_phase12_approved_release(raw$trusted_root),
    "ambiguous or missing"
  )
})

test_that("14-04 empirical calibration gate preserves failed disposition", {
  phase14_release_test_require_api(
    "phase14_evaluate_incumbent_calibration",
    "empirical calibration"
  )
  evaluator <- get("phase14_evaluate_incumbent_calibration", mode = "function")
  expect_true("comparison" %in% names(formals(evaluator)))
  arguments <- list(
    comparison = phase14_release_test_failed_comparison(),
    output_root = tempfile("phase14-blocked-calibration-")
  )
  arguments <- arguments[names(arguments) %in% names(formals(evaluator))]
  result <- phase14_release_test_gate_fields(do.call(evaluator, arguments))
  promoted <- if (is.data.frame(result)) result$calibration_promoted[[1L]] else result$calibration_promoted
  view <- if (is.data.frame(result)) result$primary_probability_view[[1L]] else result$primary_probability_view
  reasons <- if (is.data.frame(result)) result$reason_codes[[1L]] else result$reason_codes
  expect_false(isTRUE(promoted))
  expect_identical(as.character(view), "raw_1x2")
  expect_true(length(reasons) > 0L && any(nzchar(as.character(reasons))))
})

test_that("14-06 selector-aware preflight rejects forgery and ignores unselected roots", {
  phase14_release_test_require_api(
    "phase14_resolve_approved_release",
    "selector-aware preflight"
  )
  fitted <- phase14_release_test_fixture("fitted")
  resolver <- get("phase14_resolve_approved_release", mode = "function")
  resolved <- resolver(
    selector_path = fitted$selector_path,
    trusted_release_root = fitted$trusted_root
  )
  required <- c(
    "release_dir", "release_manifest_path", "release_identity", "model_identity",
    "calibrator_identity", "model_data_cutoff", "calibration_data_cutoff",
    "support_max", "primary_probability_view", "model", "calibrator"
  )
  expect_true(all(required %in% names(resolved)))
  expect_identical(as.character(resolved$release_identity$release_id), fitted$release_id)
  expect_identical(as.integer(resolved$support_max), 40L)
  expect_identical(as.character(resolved$primary_probability_view), "calibrated_1x2")

  unselected <- file.path(fitted$trusted_root, "unselected-release")
  dir.create(unselected, showWarnings = FALSE)
  file.copy(fitted$release_manifest_path, file.path(unselected, "release_manifest.csv"))
  expect_identical(
    as.character(resolver(
      selector_path = fitted$selector_path,
      trusted_release_root = fitted$trusted_root
    )$release_identity$release_id),
    fitted$release_id
  )

  forged_selector <- tempfile("phase14-forged-selector-", fileext = ".csv")
  selector <- utils::read.csv(
    fitted$selector_path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    colClasses = "character"
  )
  selector$manifest_sha256 <- strrep("f", 64L)
  selector$row_sha256 <- phase14_release_fixture_selector_hash(selector)
  phase12_release_write_csv(selector, forged_selector)
  expect_error(
    resolver(
      selector_path = forged_selector,
      trusted_release_root = fitted$trusted_root
    ),
    "manifest|hash|selector"
  )
})

test_that("14-06 immutable release validation binds fitted object and manifest bytes", {
  phase14_release_test_require_api(
    "validate_phase12_release_bundle",
    "immutable calibrated bundle validation"
  )
  raw <- phase14_release_test_fixture("raw")
  fitted <- phase14_release_test_fixture("fitted")
  expect_invisible(validate_phase12_release_bundle(raw$release_root, load_models = TRUE))
  validated <- validate_phase12_release_bundle(fitted$release_root, load_models = TRUE)
  expect_identical(as.character(validated$primary_probability_view), "calibrated_1x2")
  expect_identical(as.character(validated$calibrator$fit_status), "fitted")

  calibrator_path <- file.path(fitted$release_root, "model/calibrator.rds")
  calibrator_bytes <- phase14_release_test_read_bytes(calibrator_path)
  writeBin(charToRaw("forged fitted calibrator"), calibrator_path)
  expect_error(
    validate_phase12_release_bundle(fitted$release_root, load_models = TRUE),
    "hash"
  )
  phase14_release_test_write_bytes(calibrator_path, calibrator_bytes)
})

test_that("14-09 dual repin contract rejects split pins and exposes injected rollback", {
  phase14_release_test_require_api(
    c(
      "phase14_repin_both_competition_releases",
      "phase14_promote_calibrated_release"
    ),
    "atomic dual-repin"
  )
  repin <- get("phase14_repin_both_competition_releases", mode = "function")
  promote <- get("phase14_promote_calibrated_release", mode = "function")
  repin_formals <- names(formals(repin))
  promote_formals <- names(formals(promote))
  expect_true("registries" %in% repin_formals)
  expect_true(any(c("model_release_id", "release_identity", "resolved_release") %in% repin_formals))
  expect_true(any(c("inject_failure", "failure_injector") %in% promote_formals))

  repin_body <- paste(deparse(body(repin)), collapse = "\n")
  promote_body <- paste(deparse(body(promote)), collapse = "\n")
  expect_match(repin_body, "split|unique\\(.*model_release_id|one-release", perl = TRUE)
  expect_match(repin_body, "registry_revision", fixed = TRUE)
  expect_match(promote_body, "snapshot|prior.*bytes|readBin", perl = TRUE)
  expect_match(promote_body, "rollback|restore", perl = TRUE)
  expect_match(promote_body, "inject.*fail|fail.*inject", perl = TRUE)
})
