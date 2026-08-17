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
