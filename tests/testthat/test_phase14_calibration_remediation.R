library(testthat)

phase14_remediation_test_project_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/",
  mustWork = TRUE
)

source(file.path(
  phase14_remediation_test_project_root,
  "R/release/calibration_revision.R"
))

phase14_remediation_test_module <- file.path(
  phase14_remediation_test_project_root,
  "R/release/calibration_remediation.R"
)
if (file.exists(phase14_remediation_test_module)) {
  source(phase14_remediation_test_module, local = .GlobalEnv)
}

phase14_remediation_test_require_api <- function(required = c(
    "phase14_calibration_remediation_contract",
    "phase14_select_nested_calibrator"
)) {
  missing <- required[!vapply(required, exists, logical(1), mode = "function")]
  if (length(missing)) {
    fail(paste(
      "Plan 14-21 remediation API is missing:",
      paste(missing, collapse = ", ")
    ))
  }
  invisible(TRUE)
}

phase14_remediation_test_panel <- local({
  value <- NULL
  function() {
    if (is.null(value)) value <<- phase14_build_incumbent_development_panel()
    value
  }
})

phase14_remediation_test_fit_cache <- new.env(parent = emptyenv())
phase14_remediation_test_protocol <- phase12_selection_protocol()

phase14_remediation_test_last_outer <- local({
  value <- NULL
  function() {
    if (is.null(value)) {
      panel <- phase14_remediation_test_panel()
      value <<- phase14_select_nested_calibrator(
        panel,
        tail(attr(panel, "edition_order"), 1L),
        fit_cache = phase14_remediation_test_fit_cache,
        protocol = phase14_remediation_test_protocol
      )
    }
    value
  }
})

phase14_remediation_test_split <- function(value) {
  value <- as.character(value)
  if (!length(value) || is.na(value) || !nzchar(value)) character() else {
    strsplit(value, "\\|", fixed = FALSE)[[1L]]
  }
}

test_that("14-21 nested-selector API is present before behavioral contracts run", {
  expect_true(phase14_remediation_test_require_api())
})

test_that("14-21 freezes the exact family, grid, transform, ranking, and seed contract", {
  skip_if_not(exists("phase14_calibration_remediation_contract", mode = "function"))
  contract <- phase14_calibration_remediation_contract()

  expect_identical(contract$warmup_rows, c(60L, 128L, 256L, 400L))
  expect_identical(contract$scalar_shrinkage, c(0.25, 0.50, 0.75, 1.00))
  expect_identical(
    contract$vector_penalties,
    c(0.001, 0.01, 0.05, 0.10, 0.50, 1.00, 5.00)
  )
  expect_identical(contract$family_order, c(
    "raw_identity", "scalar_temperature", "vector_scaling"
  ))
  expect_identical(contract$tie_break_order, c(
    "rps", "calibration_error", "log_loss", "brier", "complexity_rank"
  ))
  expect_identical(contract$minimum_inner_validation_tournaments, 2L)
  expect_identical(contract$minimum_class_count, 10L)
  expect_identical(contract$temperature_bounds, c(0.25, 4))
  expect_identical(contract$vector_slope_bounds, c(0.25, 4))
  expect_identical(contract$vector_offset_bounds, c(-2, 2))
  expect_true(is.integer(contract$seed_base) && length(contract$seed_base) == 1L)

  candidates <- contract$candidates
  expect_identical(nrow(candidates), 45L)
  expect_identical(sum(candidates$family == "raw_identity"), 1L)
  expect_identical(sum(candidates$family == "scalar_temperature"), 16L)
  expect_identical(sum(candidates$family == "vector_scaling"), 28L)
  expect_identical(anyDuplicated(candidates$candidate_id), 0L)
  expect_identical(
    candidates$family,
    candidates$family[order(candidates$complexity_rank, candidates$candidate_order)]
  )
})

test_that("14-21 scalar and identifiable vector transforms preserve a finite simplex", {
  skip_if_not(exists("phase14_remediation_apply_fit", mode = "function"))
  raw <- c(home = 0.52, draw = 0.27, away = 0.21)

  scalar <- data.frame(
    selected_family = "scalar_temperature",
    temperature = exp(0.25 * log(2)),
    slope_home = 1,
    slope_draw = 1,
    slope_away = 1,
    offset_home = 0,
    offset_draw = 0,
    offset_away = 0,
    stringsAsFactors = FALSE
  )
  scalar_probability <- phase14_remediation_apply_fit(scalar, raw)
  expected_scalar <- phase12_temperature_transform(raw, exp(0.25 * log(2)))
  expect_equal(unname(scalar_probability), unname(expected_scalar), tolerance = 1e-15)

  vector <- scalar
  vector$selected_family <- "vector_scaling"
  vector$temperature <- 1
  vector$slope_home <- 0.85
  vector$slope_draw <- 1.15
  vector$slope_away <- 1.05
  vector$offset_home <- 0.10
  vector$offset_draw <- -0.04
  vector$offset_away <- -0.06
  vector_probability <- phase14_remediation_apply_fit(vector, raw)
  expect_true(all(is.finite(vector_probability)))
  expect_true(all(vector_probability > 0 & vector_probability < 1))
  expect_equal(sum(vector_probability), 1, tolerance = 1e-15)
  expect_equal(sum(vector[c("offset_home", "offset_draw", "offset_away")]), 0)

  non_identifiable <- vector
  non_identifiable$offset_away <- 0
  expect_error(
    phase14_remediation_apply_fit(non_identifiable, raw),
    "identifiable|zero.sum|offset"
  )
  invalid_simplex <- raw
  invalid_simplex[[1L]] <- 0.9
  expect_error(
    phase14_remediation_apply_fit(vector, invalid_simplex),
    "probab|simplex|sum"
  )
})

test_that("14-21 inner ranking matches the unchanged canonical Phase 12 decision", {
  panel <- phase14_remediation_test_panel()
  editions <- attr(panel, "edition_order")
  rows <- panel[panel$edition_id %in% editions[1:3], , drop = FALSE]
  fit <- data.frame(
    selected_family = "scalar_temperature", temperature = 1.10,
    slope_home = 1, slope_draw = 1, slope_away = 1,
    offset_home = 0, offset_draw = 0, offset_away = 0,
    stringsAsFactors = FALSE
  )
  calibrated <- phase14_remediation_apply_rows(fit, rows)
  fast <- phase14_remediation_fast_decision(
    rows, calibrated, protocol = phase14_remediation_test_protocol
  )
  canonical <- phase14_remediation_comparison(
    rows, calibrated, protocol = phase14_remediation_test_protocol
  )

  expect_equal(
    fast$comparison$raw_headline,
    canonical$comparison$raw_headline,
    tolerance = 1e-15
  )
  expect_equal(
    fast$comparison$calibrated_headline,
    canonical$comparison$calibrated_headline,
    tolerance = 1e-15
  )
  calibration_fields <- c(
    "calibration_error", "home_calibration_error",
    "draw_calibration_error", "away_calibration_error"
  )
  expect_equal(
    as.numeric(unlist(fast$comparison$raw_calibration_values[calibration_fields])),
    as.numeric(unlist(canonical$comparison$raw_calibration_values[calibration_fields])),
    tolerance = 1e-15
  )
  expect_equal(
    as.numeric(unlist(fast$comparison$calibrated_calibration_values[calibration_fields])),
    as.numeric(unlist(canonical$comparison$calibrated_calibration_values[calibration_fields])),
    tolerance = 1e-15
  )
  expect_identical(fast$decision$reason_codes, canonical$decision$reason_codes)
  expect_identical(
    fast$decision$primary_probability_view,
    canonical$decision$primary_probability_view
  )
})

test_that("14-21 one real outer fold evaluates every family using nested prior tournaments only", {
  skip_if_not(exists("phase14_select_nested_calibrator", mode = "function"))
  panel <- phase14_remediation_test_panel()
  editions <- attr(panel, "edition_order")
  outer <- tail(editions, 1L)
  result <- phase14_remediation_test_last_outer()

  expect_identical(nrow(result$selection), 1L)
  expect_identical(nrow(result$fit), 1L)
  expect_identical(nrow(result$predictions), sum(panel$edition_id == outer))
  expect_identical(nrow(result$candidate_scores), 45L)
  expect_setequal(unique(result$candidate_scores$family), c(
    "raw_identity", "scalar_temperature", "vector_scaling"
  ))

  outer_index <- match(outer, editions)
  expected_training <- editions[seq_len(outer_index - 1L)]
  expect_identical(
    phase14_remediation_test_split(result$fit$outer_training_editions[[1L]]),
    expected_training
  )
  expect_false(outer %in% phase14_remediation_test_split(
    result$fit$inner_validation_editions[[1L]]
  ))
  expect_true(all(result$inner_folds$inner_validation_index < outer_index))
  expect_true(all(result$inner_folds$training_max_sequence <
                    result$inner_folds$inner_validation_index))
  expect_true(all(result$inner_folds$inner_validation_index < outer_index))
  expect_match(result$fit$fit_record_sha256[[1L]], "^[0-9a-f]{64}$")
  expect_identical(as.integer(result$fit$optimizer_seed[[1L]]),
                   as.integer(result$selection$optimizer_seed[[1L]]))
  expect_true(all(abs(rowSums(result$predictions[c(
    "p_home_calibrated", "p_draw_calibrated", "p_away_calibrated"
  )]) - 1) < 1e-12))

  leaked <- panel
  leaked$regulation_home_goals[leaked$edition_id == outer] <- 99L
  leaked$regulation_away_goals[leaked$edition_id == outer] <- 0L
  leaked$observed_class[leaked$edition_id == outer] <- "home"
  leaked_result <- phase14_select_nested_calibrator(
    leaked, outer, fit_cache = phase14_remediation_test_fit_cache,
    protocol = phase14_remediation_test_protocol
  )
  stable_fields <- c(
    "selected_family", "warmup_rows", "scalar_shrinkage", "vector_penalty",
    "outer_training_editions", "inner_validation_editions", "inner_training_map",
    "optimizer_seed", "temperature", "slope_home", "slope_draw", "slope_away",
    "offset_home", "offset_draw", "offset_away", "fallback_reason"
  )
  expect_identical(
    as.character(result$fit[stable_fields]),
    as.character(leaked_result$fit[stable_fields])
  )
})

test_that("14-21 insufficient nested evidence and class support fail closed to raw fallback", {
  skip_if_not(exists("phase14_select_nested_calibrator", mode = "function"))
  panel <- phase14_remediation_test_panel()
  editions <- attr(panel, "edition_order")

  early <- phase14_select_nested_calibrator(
    panel, editions[[2L]], protocol = phase14_remediation_test_protocol
  )
  expect_identical(early$fit$selected_family[[1L]], "raw_identity")
  expect_identical(early$fit$fit_status[[1L]], "raw_fallback")
  expect_match(early$fit$fallback_reason[[1L]], "insufficient")
  expect_identical(early$fit$optimizer_method[[1L]], "not_run")
  expect_identical(early$fit$optimizer_convergence_code[[1L]], NA_integer_)
  expect_equal(
    as.numeric(early$predictions$p_home_calibrated),
    as.numeric(early$predictions$p_home),
    tolerance = 0
  )

  unsupported <- panel
  target <- editions[[8L]]
  prior <- editions[seq_len(match(target, editions) - 1L)]
  unsupported$observed_class[unsupported$edition_id %in% prior] <- "home"
  unsupported$regulation_home_goals[unsupported$edition_id %in% prior] <- 1L
  unsupported$regulation_away_goals[unsupported$edition_id %in% prior] <- 0L
  fallback <- phase14_select_nested_calibrator(
    unsupported, target, protocol = phase14_remediation_test_protocol
  )
  expect_identical(fallback$fit$selected_family[[1L]], "raw_identity")
  expect_match(fallback$fit$fallback_reason[[1L]], "support|insufficient")
})

test_that("14-21 selected fit records reject chronology, convergence, and parameter forgery", {
  skip_if_not(exists("phase14_remediation_validate_fit_record", mode = "function"))
  panel <- phase14_remediation_test_panel()
  editions <- attr(panel, "edition_order")
  result <- phase14_remediation_test_last_outer()
  expect_invisible(phase14_remediation_validate_fit_record(result$fit, panel))

  forged_training <- result$fit
  forged_training$outer_training_editions <- paste(
    forged_training$outer_training_editions,
    forged_training$outer_edition_id,
    sep = "|"
  )
  expect_error(
    phase14_remediation_validate_fit_record(forged_training, panel),
    "strict|training|outer"
  )

  forged_hash <- result$fit
  forged_hash$fit_record_sha256 <- strrep("0", 64L)
  expect_error(
    phase14_remediation_validate_fit_record(forged_hash, panel),
    "hash"
  )

  if (!identical(result$fit$selected_family[[1L]], "raw_identity")) {
    forged_convergence <- result$fit
    forged_convergence$optimizer_convergence_code <- 1L
    forged_convergence$fit_record_sha256 <- phase14_remediation_fit_record_sha256(
      forged_convergence
    )
    expect_error(
      phase14_remediation_validate_fit_record(forged_convergence, panel),
      "convergence|optimizer"
    )
  }
})

phase14_remediation_test_root <- file.path(
  phase14_remediation_test_project_root,
  "outputs/benchmarks/rolling_tournaments/phase14-incumbent-calibration-remediation-v2"
)

phase14_remediation_test_artifact_paths <- function(root = phase14_remediation_test_root) {
  file.path(root, c(
    "remediation_contract.csv", "outer_fold_selection.csv", "outer_fold_fits.csv",
    "calibrator.rds", "calibrated_predictions.csv", "calibration_gate.csv",
    "calibration_revision_manifest.csv"
  ))
}

test_that("14-21 complete remediation graph API is present", {
  expect_true(phase14_remediation_test_require_api(c(
    "phase14_build_calibration_remediation",
    "phase14_validate_calibration_remediation"
  )))
})

test_that("14-21 durable graph covers all 12 outer tournaments and 630 identities", {
  skip_if_not(exists("phase14_validate_calibration_remediation", mode = "function"))
  paths <- phase14_remediation_test_artifact_paths()
  expect_true(all(file.exists(paths)), info = paste(paths[!file.exists(paths)], collapse = ", "))
  if (!all(file.exists(paths))) return(invisible())
  expect_true(phase14_validate_calibration_remediation(
    phase14_remediation_test_root, require_promoted = FALSE
  ))

  selection <- read.csv(paths[[2L]], stringsAsFactors = FALSE, check.names = FALSE)
  fits <- read.csv(paths[[3L]], stringsAsFactors = FALSE, check.names = FALSE)
  predictions <- read.csv(paths[[5L]], stringsAsFactors = FALSE, check.names = FALSE)
  panel <- phase14_remediation_test_panel()
  editions <- attr(panel, "edition_order")

  expect_identical(nrow(selection), 12L)
  expect_identical(nrow(fits), 12L)
  expect_identical(nrow(predictions), 630L)
  expect_identical(as.character(selection$outer_edition_id), editions)
  expect_identical(as.character(fits$outer_edition_id), editions)
  expect_identical(anyDuplicated(predictions$fixture_id), 0L)
  expect_setequal(as.character(predictions$fixture_id), as.character(panel$fixture_id))
  expect_identical(
    as.character(predictions$score_distribution_id[match(panel$fixture_id, predictions$fixture_id)]),
    as.character(panel$score_distribution_id)
  )
  expect_false(phase14_calibration_revision_has_holdout_identity(predictions))
  expect_true(all(abs(rowSums(predictions[c(
    "p_home_calibrated", "p_draw_calibrated", "p_away_calibrated"
  )]) - 1) < 1e-12))
})

test_that("14-21 persisted outer fits independently replay every probability", {
  skip_if_not(exists("phase14_validate_calibration_remediation", mode = "function"))
  paths <- phase14_remediation_test_artifact_paths()
  if (!all(file.exists(paths))) skip("durable remediation graph not built yet")
  fits <- read.csv(paths[[3L]], stringsAsFactors = FALSE, check.names = FALSE)
  predictions <- read.csv(paths[[5L]], stringsAsFactors = FALSE, check.names = FALSE)
  panel <- phase14_remediation_test_panel()
  editions <- attr(panel, "edition_order")

  for (index in seq_along(editions)) {
    edition <- editions[[index]]
    fit <- fits[fits$outer_edition_id == edition, , drop = FALSE]
    expect_invisible(phase14_remediation_validate_fit_record(fit, panel))
    rows <- panel[panel$edition_id == edition, , drop = FALSE]
    replay <- phase14_remediation_apply_rows(fit, rows)
    persisted <- predictions[
      match(rows$fixture_id, predictions$fixture_id),
      c("p_home_calibrated", "p_draw_calibrated", "p_away_calibrated"),
      drop = FALSE
    ]
    expect_equal(unname(replay), unname(as.matrix(persisted)), tolerance = 1e-12)
    expect_identical(
      phase14_remediation_test_split(fit$outer_training_editions[[1L]]),
      if (index == 1L) character() else editions[seq_len(index - 1L)]
    )
  }
})

test_that("14-21 final fitting is permitted only after an actual outer pass", {
  skip_if_not(exists("phase14_validate_calibration_remediation", mode = "function"))
  paths <- phase14_remediation_test_artifact_paths()
  if (!all(file.exists(paths))) skip("durable remediation graph not built yet")
  gate <- read.csv(paths[[6L]], stringsAsFactors = FALSE, check.names = FALSE)
  calibrator <- readRDS(paths[[4L]])
  expect_identical(nrow(gate), 1L)
  expect_identical(as.logical(gate$outer_gate_passed[[1L]]), gate$reason_count[[1L]] == 0L)
  expect_false(as.logical(gate$holdout_labels_used[[1L]]))
  expect_false(as.logical(gate$authority_mutated[[1L]]))
  if (isTRUE(as.logical(gate$outer_gate_passed[[1L]]))) {
    expect_identical(calibrator$fit_status, "fitted")
    expect_true(isTRUE(calibrator$final_fit_performed))
    expect_identical(gate$primary_probability_view[[1L]], "calibrated_1x2")
  } else {
    expect_identical(calibrator$fit_status, "raw_fallback")
    expect_false(isTRUE(calibrator$final_fit_performed))
    expect_false(isTRUE(calibrator$calibration_promoted))
    expect_identical(gate$primary_probability_view[[1L]], "raw_1x2")
  }
})

test_that("14-21 manifest binds original authority and rejects graph tampering", {
  skip_if_not(exists("phase14_validate_calibration_remediation", mode = "function"))
  paths <- phase14_remediation_test_artifact_paths()
  if (!all(file.exists(paths))) skip("durable remediation graph not built yet")
  manifest <- read.csv(paths[[7L]], stringsAsFactors = FALSE, check.names = FALSE)
  root <- phase14_remediation_test_project_root
  expected_authority <- c(
    original_gate_sha256 = "outputs/benchmarks/rolling_tournaments/phase14-incumbent-calibration-revision/calibration_gate.csv",
    original_manifest_sha256 = "outputs/benchmarks/rolling_tournaments/phase14-incumbent-calibration-revision/calibration_revision_manifest.csv",
    protocol_sha256 = "data/benchmark/phase09/promotion_protocol.json",
    freeze_manifest_sha256 = "data/benchmark/phase12/freeze_manifest.csv",
    calibration_recipe_sha256 = "data/benchmark/phase12/calibration_recipe.json",
    model_registry_sha256 = "data/benchmark/phase09/model_registry.csv",
    seed_registry_sha256 = "data/benchmark/phase09/seed_registry.csv",
    phase12_selector_sha256 = "R/calibration/calibration_selection.R"
  )
  expect_identical(nrow(manifest), 1L)
  for (field in names(expected_authority)) {
    expect_identical(
      tolower(as.character(manifest[[field]][[1L]])),
      tolower(phase14_calibration_revision_file_sha256(file.path(root, expected_authority[[field]])))
    )
  }

  tampered_root <- tempfile("phase14-remediation-tamper-")
  dir.create(tampered_root, recursive = TRUE)
  expect_true(all(file.copy(paths, tampered_root)))
  tampered_fits_path <- file.path(tampered_root, "outer_fold_fits.csv")
  tampered_fits <- read.csv(tampered_fits_path, stringsAsFactors = FALSE, check.names = FALSE)
  tampered_fits$offset_home[[1L]] <- 0.10
  tampered_fits$fit_record_sha256[[1L]] <- phase14_remediation_fit_record_sha256(
    tampered_fits[1L, , drop = FALSE]
  )
  write.csv(tampered_fits, tampered_fits_path, row.names = FALSE, na = "")
  expect_error(
    phase14_validate_calibration_remediation(tampered_root, require_promoted = FALSE),
    "fit|identity|replay|hash|manifest"
  )
})

test_that("14-21 every selector path rejects synthetic holdout identity", {
  panel <- phase14_remediation_test_panel()
  panel$edition_id[[1L]] <- "wc2026"
  expect_error(
    phase14_select_nested_calibrator(
      panel, tail(attr(phase14_remediation_test_panel(), "edition_order"), 1L),
      protocol = phase14_remediation_test_protocol
    ),
    "sealed|development|holdout|630"
  )
})
