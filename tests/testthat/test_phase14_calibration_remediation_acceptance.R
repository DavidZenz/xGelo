library(testthat)

if (!exists("reference_validate_phase14_calibration_candidate", mode = "function")) {
  helper_candidates <- c(
    "helper_phase14_calibration_remediation_acceptance.R",
    "tests/testthat/helper_phase14_calibration_remediation_acceptance.R"
  )
  helper_candidate <- helper_candidates[file.exists(helper_candidates)][[1L]]
  source(helper_candidate)
}

acceptance_project_root <- reference_phase14_repo_root()
acceptance_helper_path <- file.path(
  acceptance_project_root, "tests/testthat/helper_phase14_calibration_remediation_acceptance.R"
)
acceptance_test_path <- file.path(
  acceptance_project_root, "tests/testthat/test_phase14_calibration_remediation_acceptance.R"
)
acceptance_candidate_root <- file.path(
  acceptance_project_root,
  "outputs", "benchmarks", "rolling_tournaments",
  "phase14-incumbent-calibration-remediation-v2"
)

acceptance_copy_candidate <- function() {
  destination <- tempfile("phase14-22-candidate-")
  dir.create(destination, recursive = TRUE)
  paths <- list.files(acceptance_candidate_root, full.names = TRUE, all.files = FALSE)
  copied <- file.copy(paths, destination, recursive = TRUE, copy.mode = TRUE)
  stopifnot(all(copied))
  destination
}

acceptance_write_csv <- function(data, path) {
  utils::write.csv(data, path, row.names = FALSE, na = "", quote = TRUE)
  invisible(path)
}

acceptance_rehash_candidate_graph <- function(root) {
  fits_path <- file.path(root, "outer_fold_fits.csv")
  selection_path <- file.path(root, "outer_fold_selection.csv")
  predictions_path <- file.path(root, "calibrated_predictions.csv")
  gate_path <- file.path(root, "calibration_gate.csv")
  manifest_path <- file.path(root, "calibration_revision_manifest.csv")

  fits <- reference_phase14_read_csv(fits_path)
  fits$fit_record_sha256 <- reference_phase14_row_sha256(fits, "fit_record_sha256")
  acceptance_write_csv(fits, fits_path)

  selection <- reference_phase14_read_csv(selection_path)
  selection$fit_record_sha256 <- fits$fit_record_sha256[
    match(selection$outer_edition_id, fits$outer_edition_id)
  ]
  selection$selection_row_sha256 <- reference_phase14_row_sha256(
    selection, "selection_row_sha256"
  )
  acceptance_write_csv(selection, selection_path)

  predictions <- reference_phase14_read_csv(predictions_path)
  predictions$fit_record_sha256 <- fits$fit_record_sha256[
    match(predictions$edition_id, fits$outer_edition_id)
  ]
  acceptance_write_csv(predictions, predictions_path)

  gate <- reference_phase14_read_csv(gate_path, character = TRUE)
  gate$row_sha256 <- reference_phase14_table_sha256(
    gate[, setdiff(names(gate), "row_sha256"), drop = FALSE]
  )
  acceptance_write_csv(gate, gate_path)

  manifest <- reference_phase14_read_csv(manifest_path, character = TRUE)
  artifact_fields <- c(
    remediation_contract_sha256 = "remediation_contract.csv",
    outer_fold_selection_sha256 = "outer_fold_selection.csv",
    outer_fold_fits_sha256 = "outer_fold_fits.csv",
    calibrator_sha256 = "calibrator.rds",
    calibrated_predictions_sha256 = "calibrated_predictions.csv",
    calibration_gate_sha256 = "calibration_gate.csv"
  )
  for (field in names(artifact_fields)) {
    manifest[[field]] <- reference_phase14_file_sha256(file.path(root, artifact_fields[[field]]))
  }
  manifest$manifest_self_sha256 <- reference_phase14_table_sha256(
    manifest[, setdiff(names(manifest), "manifest_self_sha256"), drop = FALSE]
  )
  acceptance_write_csv(manifest, manifest_path)
  invisible(root)
}

acceptance_call_symbols <- function(expression) {
  output <- character()
  walk <- function(node) {
    if (is.call(node)) {
      if (is.symbol(node[[1L]])) output <<- c(output, as.character(node[[1L]]))
      lapply(as.list(node)[-1L], walk)
    } else if (is.expression(node) || is.pairlist(node)) {
      lapply(as.list(node), walk)
    }
    invisible(NULL)
  }
  walk(expression)
  unique(output)
}

test_that("14-22 acceptance artifacts never invoke the remediation producer", {
  helper_text <- paste(readLines(acceptance_helper_path, warn = FALSE), collapse = "\n")
  parsed <- parse(acceptance_helper_path)
  calls <- acceptance_call_symbols(parsed)
  producer_symbols <- c(
    paste0("phase14_", "validate_calibration_remediation"),
    paste0("phase14_", "select_nested_calibrator"),
    paste0("phase14_", "build_calibration_remediation")
  )
  expect_length(intersect(calls, producer_symbols), 0L)
  source_calls <- gregexpr("source\\s*\\([^)]*\\)", helper_text, perl = TRUE)
  source_text <- regmatches(helper_text, source_calls)[[1L]]
  forbidden_path <- paste0("R/release/calibration_", "remediation.R")
  expect_false(any(grepl(forbidden_path, source_text, fixed = TRUE)))
  expect_true(file.exists(acceptance_test_path))
})

test_that("14-22 independently reconstructs the complete promoted graph", {
  expect_true(isTRUE(reference_validate_phase14_calibration_candidate(
    acceptance_candidate_root, require_promoted = TRUE
  )))
})

test_that("14-22 rejects an outer label entering inner training", {
  root <- acceptance_copy_candidate()
  selection_path <- file.path(root, "outer_fold_selection.csv")
  selection <- reference_phase14_read_csv(selection_path)
  row <- match("wc2014", selection$outer_edition_id)
  selection$inner_training_map[[row]] <- paste0(
    selection$inner_training_map[[row]], "+wc2014"
  )
  acceptance_write_csv(selection, selection_path)
  expect_error(
    reference_validate_phase14_calibration_candidate(root, require_promoted = TRUE),
    "Selection inner_training_map differs"
  )
})

test_that("14-22 rejects forged outer training IDs", {
  root <- acceptance_copy_candidate()
  fits_path <- file.path(root, "outer_fold_fits.csv")
  fits <- reference_phase14_read_csv(fits_path)
  row <- match("euro2016", fits$outer_edition_id)
  fits$outer_training_editions[[row]] <- paste0(fits$outer_training_editions[[row]], "|euro2016")
  acceptance_write_csv(fits, fits_path)
  expect_error(
    reference_validate_phase14_calibration_candidate(root, require_promoted = TRUE),
    "Fit outer_training_editions differs"
  )
})

test_that("14-22 rejects forged fitted vector parameters", {
  root <- acceptance_copy_candidate()
  fits_path <- file.path(root, "outer_fold_fits.csv")
  fits <- reference_phase14_read_csv(fits_path)
  row <- match("euro2008", fits$outer_edition_id)
  fits$slope_home[[row]] <- fits$slope_home[[row]] + 0.01
  acceptance_write_csv(fits, fits_path)
  expect_error(
    reference_validate_phase14_calibration_candidate(root, require_promoted = TRUE),
    "Fit slope_home differs"
  )
})

test_that("14-22 rejects a self-consistently rehashed leaked graph", {
  root <- acceptance_copy_candidate()
  selection_path <- file.path(root, "outer_fold_selection.csv")
  fits_path <- file.path(root, "outer_fold_fits.csv")
  predictions_path <- file.path(root, "calibrated_predictions.csv")
  selection <- reference_phase14_read_csv(selection_path)
  fits <- reference_phase14_read_csv(fits_path)
  predictions <- reference_phase14_read_csv(predictions_path)
  row <- match("wc2014", selection$outer_edition_id)
  leaked_training <- paste0(selection$outer_training_editions[[row]], "|wc2014")
  selection$outer_training_editions[[row]] <- leaked_training
  selection$inner_training_map[[row]] <- paste0(selection$inner_training_map[[row]], ";wc2014~wc2014")
  fits_row <- match("wc2014", fits$outer_edition_id)
  fits$outer_training_editions[[fits_row]] <- leaked_training
  fits$inner_training_map[[fits_row]] <- selection$inner_training_map[[row]]
  prediction_rows <- predictions$edition_id == "wc2014"
  predictions$outer_training_editions[prediction_rows] <- leaked_training
  predictions$inner_training_map[prediction_rows] <- selection$inner_training_map[[row]]
  acceptance_write_csv(selection, selection_path)
  acceptance_write_csv(fits, fits_path)
  acceptance_write_csv(predictions, predictions_path)
  acceptance_rehash_candidate_graph(root)

  manifest <- reference_phase14_read_csv(file.path(root, "calibration_revision_manifest.csv"),
                                         character = TRUE)
  gate <- reference_phase14_read_csv(file.path(root, "calibration_gate.csv"), character = TRUE)
  expect_identical(manifest$outer_fold_fits_sha256,
                   reference_phase14_file_sha256(file.path(root, "outer_fold_fits.csv")))
  expect_identical(manifest$calibration_gate_sha256,
                   reference_phase14_file_sha256(file.path(root, "calibration_gate.csv")))
  expect_identical(gate$disposition, "CALIBRATION_RELEASE_APPROVED")
  expect_identical(gate$reason_count, "0")
  expect_error(
    reference_validate_phase14_calibration_candidate(root, require_promoted = TRUE),
    "Selection outer_training_editions differs"
  )
})
