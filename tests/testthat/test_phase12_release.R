library(testthat)

# Validation 12-00-01: release ownership covers staged bundle and consumers.
# Validation 12-00-02: synthetic release fixtures remain outside the holdout boundary.

phase12_release_contract_files <- function() {
  file.path(
    phase12_test_project_root,
    c(
      "tests/testthat/test_phase12_calibration.R",
      "tests/testthat/test_phase12_freeze.R",
      "tests/testthat/test_phase12_final_evaluation.R",
      "tests/testthat/test_phase12_promotion.R",
      "tests/testthat/test_phase12_release.R"
    )
  )
}

phase12_release_synthetic_manifest <- function() {
  data.frame(
    release_id = "synthetic_release_v0",
    status = "incumbent retained",
    candidate_id = "phase11_rf_dynamic_elo_open",
    track_id = "updating",
    score_support = 40L,
    primary_probability_view = "raw_1x2",
    labels_embedded = FALSE,
    stringsAsFactors = FALSE
  )
}

phase12_release_require_api <- function(required, owner) {
  missing <- required[!vapply(required, exists, logical(1), mode = "function")]
  if (length(missing)) {
    stop(
      paste0("Wave 0 RED contract awaits Phase 12 ", owner, " API: ",
             paste(missing, collapse = ", ")),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

phase12_release_static_scan <- function(files = phase12_release_contract_files()) {
  expected <- phase12_release_contract_files()
  stopifnot(identical(files, expected), all(file.exists(files)))

  forbidden_source_patterns <- c(
    paste0("data/benchmark/phase12/", "wc2026_labels", "\\.", "csv")
  )
  forbidden_calls <- character()

  for (path in files) {
    text <- paste(readLines(path, warn = FALSE), collapse = "\n")
    bad_patterns <- forbidden_source_patterns[vapply(
      forbidden_source_patterns, function(pattern) grepl(pattern, text, perl = TRUE),
      logical(1)
    )]
    if (length(bad_patterns)) {
      stop(
        "forbidden label-boundary construct in Phase 12 validation file: ",
        path, " :: ", paste(bad_patterns, collapse = ", ")
      )
    }
    parsed <- parse(file = path, keep.source = TRUE)
    stopifnot(length(parsed) > 0L)
    parse_data <- getParseData(parsed)
    calls <- unique(parse_data$text[parse_data$token == "SYMBOL_FUNCTION_CALL"])
    bad_calls <- intersect(calls, forbidden_calls)
    if (length(bad_calls)) {
      stop(
        "forbidden production or write call in Wave 0 scaffold: ", path,
        " :: ", paste(bad_calls, collapse = ", ")
      )
    }
  }
  invisible(TRUE)
}

test_that("12-00-01 release fixture is explicit, versioned, and hash-ready", {
  manifest <- phase12_release_synthetic_manifest()
  expect_identical(manifest$status, "incumbent retained")
  expect_equal(manifest$score_support, 40L)
  expect_identical(manifest$primary_probability_view, "raw_1x2")
  expect_false(manifest$labels_embedded)
})

test_that("12-00-02 static scan covers exactly the five Wave 0 files", {
  expect_invisible(phase12_release_static_scan())
})

test_that("12-00-01 release gate names bundle, install, and resolver seams", {
  expect_invisible(phase12_release_require_api(
    c(
      "stage_phase12_release_bundle",
      "validate_phase12_release_bundle",
      "complete_phase12_release_bundle",
      "install_phase12_release_bundle",
      "resolve_phase12_approved_release",
      "validate_phase12_release_contract",
      "phase12_release_metadata"
    ),
    "release"
  ))
})

phase12_test_release_root <- function() {
  file.path(phase12_test_project_root, "outputs/releases")
}

phase12_test_copy_release <- function() {
  source(file.path(phase12_test_project_root, "R/release/release_bundle.R"), local = .GlobalEnv)
  source(file.path(phase12_test_project_root, "R/release/release_install.R"), local = .GlobalEnv)
  source(file.path(phase12_test_project_root, "R/release/release_contract.R"), local = .GlobalEnv)
  source(file.path(phase12_test_project_root, "R/release/promotion_report.R"), local = .GlobalEnv)
  source_root <- file.path(phase12_test_project_root, "outputs/releases/phase12-wc2026-incumbent-retained-v1")
  trusted_root <- tempfile("phase12-release-root-")
  dir.create(trusted_root, recursive = TRUE)
  file.copy(source_root, trusted_root, recursive = TRUE)
  release_root <- file.path(trusted_root, basename(source_root))
  list(trusted_root = trusted_root, release_root = release_root)
}

phase12_test_refresh_manifest_self_hash <- function(release_root) {
  manifest_path <- file.path(release_root, "release_manifest.csv")
  manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  self <- manifest$artifact == "release_manifest.csv"
  manifest$manifest_self_sha256[self] <- phase12_release_manifest_body_hash(manifest)
  manifest$sha256[self] <- manifest$manifest_self_sha256[self]
  manifest$canonical_content_sha256[self] <- manifest$manifest_self_sha256[self]
  utils::write.csv(manifest, manifest_path, row.names = FALSE, na = "", quote = TRUE)
  invisible(manifest)
}

phase12_test_refresh_release_hashes <- function(release_root) {
  manifest_path <- file.path(release_root, "release_manifest.csv")
  manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  for (index in which(manifest$artifact != "release_manifest.csv")) {
    path <- file.path(release_root, manifest$relative_path[[index]])
    hash <- phase12_release_file_sha256(path)
    manifest$sha256[[index]] <- hash
    manifest$canonical_content_sha256[[index]] <- hash
  }
  utils::write.csv(manifest, manifest_path, row.names = FALSE, na = "", quote = TRUE)
  phase12_test_refresh_manifest_self_hash(release_root)
}

phase12_test_refresh_contract_manifest_row <- function(release_root) {
  manifest_path <- file.path(release_root, "release_manifest.csv")
  manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  index <- which(manifest$relative_path == "model_contract.json")
  hash <- phase12_release_file_sha256(file.path(release_root, "model_contract.json"))
  manifest$sha256[index] <- hash
  manifest$canonical_content_sha256[index] <- hash
  utils::write.csv(manifest, manifest_path, row.names = FALSE, na = "", quote = TRUE)
  phase12_test_refresh_manifest_self_hash(release_root)
}

test_that("12-09 metadata preflight is label-free and authoritative", {
  source(file.path(phase12_test_project_root, "R/release/release_contract.R"), local = .GlobalEnv)
  preflight <- preflight_phase12_approved_release(phase12_test_release_root())
  expect_identical(preflight$metadata$status, "incumbent retained")
  expect_identical(preflight$metadata$selected_model_id, "open_nb_incumbent")
  expect_false("model" %in% names(preflight))
  expect_false("calibrator" %in% names(preflight))
  expect_identical(preflight$model_contract$model_artifact, "model/approved_model.rds")
  expect_identical(preflight$model_contract$calibrator_artifact, "model/calibrator.rds")
})

test_that("12-09 preflight rejects missing and ambiguous trusted-root topology", {
  source(file.path(phase12_test_project_root, "R/release/release_contract.R"), local = .GlobalEnv)
  expect_error(preflight_phase12_approved_release(NULL), "release root is required")
  expect_error(preflight_phase12_approved_release(file.path(tempdir(), "phase12-missing-root")), "cannot open|does not exist|No such file")

  fixture <- phase12_test_copy_release()
  child <- file.path(fixture$trusted_root, "second-release")
  dir.create(child)
  file.copy(file.path(fixture$release_root, "release_manifest.csv"), file.path(child, "release_manifest.csv"))
  expect_error(preflight_phase12_approved_release(fixture$trusted_root), "ambiguous or missing")

  root_manifest <- file.path(fixture$trusted_root, "release_manifest.csv")
  file.copy(file.path(fixture$release_root, "release_manifest.csv"), root_manifest)
  expect_error(preflight_phase12_approved_release(fixture$trusted_root), "ambiguous or missing")
})

test_that("12-09 hash and contract metadata failures occur before RDS loading", {
  source(file.path(phase12_test_project_root, "R/release/release_contract.R"), local = .GlobalEnv)
  fixture <- phase12_test_copy_release()
  model_path <- file.path(fixture$release_root, "model/approved_model.rds")
  writeBin(charToRaw("deliberately unreadable model bytes"), model_path)
  expect_error(preflight_phase12_approved_release(fixture$trusted_root), "hash|metadata")

  fixture <- phase12_test_copy_release()
  contract_path <- file.path(fixture$release_root, "model_contract.json")
  contract <- jsonlite::fromJSON(contract_path, simplifyVector = FALSE)
  contract$labels_embedded <- TRUE
  jsonlite::write_json(contract, contract_path, auto_unbox = TRUE, pretty = TRUE)
  expect_error(preflight_phase12_approved_release(fixture$trusted_root), "hash|labels_embedded")

  fixture <- phase12_test_copy_release()
  manifest <- utils::read.csv(file.path(fixture$release_root, "release_manifest.csv"), stringsAsFactors = FALSE, check.names = FALSE)
  manifest$artifact_role[manifest$artifact == "model/calibrator.rds"] <- "calibrator"
  utils::write.csv(manifest, file.path(fixture$release_root, "release_manifest.csv"), row.names = FALSE, na = "", quote = TRUE)
  phase12_test_refresh_manifest_self_hash(fixture$release_root)
  expect_error(preflight_phase12_approved_release(fixture$trusted_root), "artifact_role|model manifest")
})

test_that("12-09 direct resolver preflights before reading invalid model bytes", {
  source(file.path(phase12_test_project_root, "R/release/release_contract.R"), local = .GlobalEnv)
  fixture <- phase12_test_copy_release()
  writeBin(charToRaw("not an RDS"), file.path(fixture$release_root, "model/approved_model.rds"))
  expect_error(resolve_phase12_approved_release(fixture$trusted_root), "hash|metadata")
  resolved <- resolve_phase12_approved_release(phase12_test_release_root())
  expect_identical(resolved$metadata$status, "incumbent retained")
})

test_that("12-10 trusted release topology rejects symlink roots and candidates", {
  source(file.path(phase12_test_project_root, "R/release/release_contract.R"), local = .GlobalEnv)
  fixture <- phase12_test_copy_release()
  linked_root <- tempfile("phase12-linked-root-")
  expect_true(file.symlink(fixture$trusted_root, linked_root))
  expect_error(preflight_phase12_approved_release(linked_root), "real directory")

  fixture <- phase12_test_copy_release()
  root_manifest <- file.path(fixture$trusted_root, "release_manifest.csv")
  expect_true(file.symlink(file.path(fixture$release_root, "release_manifest.csv"), root_manifest))
  expect_error(preflight_phase12_approved_release(fixture$trusted_root), "root release manifest")

  linked_parent <- tempfile("phase12-linked-child-")
  dir.create(linked_parent)
  expect_true(file.symlink(fixture$release_root, file.path(linked_parent, basename(fixture$release_root))))
  expect_error(preflight_phase12_approved_release(linked_parent), "immediate-child release directory")

  fixture <- phase12_test_copy_release()
  manifest_path <- file.path(fixture$release_root, "release_manifest.csv")
  unlink(manifest_path)
  expect_true(file.symlink(file.path(phase12_test_release_root(), "phase12-wc2026-incumbent-retained-v1/release_manifest.csv"), manifest_path))
  expect_error(preflight_phase12_approved_release(fixture$trusted_root), "child release manifest")
})

test_that("12-10 resolver rejects forged handoffs after a fresh preflight", {
  source(file.path(phase12_test_project_root, "R/release/release_contract.R"), local = .GlobalEnv)
  first <- phase12_test_copy_release()
  second <- phase12_test_copy_release()
  alternate <- preflight_phase12_approved_release(second$trusted_root)
  expect_error(
    resolve_phase12_approved_release(first$trusted_root, validated_preflight = alternate),
    "stale or forged"
  )
})

test_that("12-10 decision identity binds exact tokens, evidence, and selected IDs", {
  source(file.path(phase12_test_project_root, "R/release/release_contract.R"), local = .GlobalEnv)
  evidence <- data.frame(
    candidate_id = c("challenger_a", "incumbent"),
    release_decision = c("challenger approved", "incumbent retained"),
    score = c(0.1, 0.2),
    stringsAsFactors = FALSE
  )
  approved <- phase12_release_contract_recompute_decision_sha256(evidence, "challenger approved", "challenger_a")
  retained <- phase12_release_contract_recompute_decision_sha256(evidence, "incumbent retained", "incumbent")
  expect_match(approved, "^[0-9a-f]{64}$")
  expect_match(retained, "^[0-9a-f]{64}$")
  expect_false(identical(approved, retained))
  expect_false(identical(approved, phase12_release_contract_recompute_decision_sha256(evidence, "challenger approved", "incumbent")))
  expect_false(identical(approved, phase12_release_contract_recompute_decision_sha256(transform(evidence, score = c(0.3, 0.2)), "challenger approved", "challenger_a")))
  expect_error(phase12_release_contract_recompute_decision_sha256(evidence, "approved", "challenger_a"), "token is invalid")
})

test_that("12-10 refreshed hashes cannot authorize a model/calibrator path swap", {
  source(file.path(phase12_test_project_root, "R/release/release_contract.R"), local = .GlobalEnv)
  fixture <- phase12_test_copy_release()
  contract_path <- file.path(fixture$release_root, "model_contract.json")
  contract <- jsonlite::fromJSON(contract_path, simplifyVector = FALSE)
  contract$model_artifact <- "model/calibrator.rds"
  contract$calibrator_artifact <- "model/approved_model.rds"
  jsonlite::write_json(contract, contract_path, auto_unbox = TRUE, pretty = TRUE)
  phase12_test_refresh_contract_manifest_row(fixture$release_root)
  expect_error(preflight_phase12_approved_release(fixture$trusted_root), "canonical")
})

test_that("12-10 freeze, evaluation, provenance, and compatibility links fail closed", {
  source(file.path(phase12_test_project_root, "R/release/release_contract.R"), local = .GlobalEnv)
  fixture <- phase12_test_copy_release()
  contract_path <- file.path(fixture$release_root, "model_contract.json")
  contract <- jsonlite::fromJSON(contract_path, simplifyVector = FALSE)
  contract$freeze_self_sha256 <- paste(rep("a", 64), collapse = "")
  jsonlite::write_json(contract, contract_path, auto_unbox = TRUE, pretty = TRUE)
  phase12_test_refresh_contract_manifest_row(fixture$release_root)
  expect_error(preflight_phase12_approved_release(fixture$trusted_root), "freeze self")

  fixture <- phase12_test_copy_release()
  final_path <- file.path(fixture$release_root, "manifests/final_evaluation_manifest.csv")
  final <- utils::read.csv(final_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  final$freeze_id[[1L]] <- "different_freeze"
  utils::write.csv(final, final_path, row.names = FALSE, na = "", quote = TRUE)
  phase12_test_refresh_release_hashes(fixture$release_root)
  expect_error(preflight_phase12_approved_release(fixture$trusted_root), "freeze or track link")

  fixture <- phase12_test_copy_release()
  final_path <- file.path(fixture$release_root, "manifests/final_evaluation_manifest.csv")
  final <- utils::read.csv(final_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  final$promotion_decision_sha256[[1L]] <- "not-a-hash"
  utils::write.csv(final, final_path, row.names = FALSE, na = "", quote = TRUE)
  phase12_test_refresh_release_hashes(fixture$release_root)
  expect_error(preflight_phase12_approved_release(fixture$trusted_root), "promotion report identity")

  valid <- preflight_phase12_approved_release(phase12_test_release_root())
  expect_null(valid$model_contract$freeze_self_sha256)
  expect_identical(valid$metadata$primary_probability_view, "raw_1x2")
})

test_that("12-10 loaded model and calibrator identities are checked after metadata preflight", {
  source(file.path(phase12_test_project_root, "R/release/release_contract.R"), local = .GlobalEnv)
  fixture <- phase12_test_copy_release()
  saveRDS(list(not_model_id = "wrong"), file.path(fixture$release_root, "model/approved_model.rds"))
  phase12_test_refresh_release_hashes(fixture$release_root)
  expect_error(resolve_phase12_approved_release(fixture$trusted_root), "model identity")

  fixture <- phase12_test_copy_release()
  calibrator <- readRDS(file.path(fixture$release_root, "model/calibrator.rds"))
  calibrator$candidate_id <- "wrong_candidate"
  saveRDS(calibrator, file.path(fixture$release_root, "model/calibrator.rds"))
  phase12_test_refresh_release_hashes(fixture$release_root)
  expect_error(resolve_phase12_approved_release(fixture$trusted_root), "calibrator identity")
})
