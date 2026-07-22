library(testthat)

project_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))
dependence_module <- file.path(project_root, "R/forecast/score_dependence.R")
if (file.exists(dependence_module)) source(dependence_module)

require_dependence_parameter_api <- function() {
  required <- c(
    "statistical_mean_prediction_hash",
    "fit_fold_dependence_parameters",
    "validate_shared_mean_hash",
    "score_dependence_manifest"
  )
  missing <- required[!vapply(required, exists, logical(1), mode = "function")]
  if (length(missing)) {
    stop(paste("Wave 0 RED contract awaits:", paste(missing, collapse = ", ")), call. = FALSE)
  }
}

dependence_parameter_history <- function() {
  data.frame(
    match_id = paste0("m", 1:8),
    edition_id = rep(c("wc1998", "wc2002", "wc2006", "wc2010"), each = 2),
    actual_completion_date = as.Date(c(
      "1998-06-10", "1998-06-11", "2002-06-10", "2002-06-11",
      "2006-06-10", "2006-06-11", "2010-06-12", "2010-06-13"
    )),
    home_goals = c(1L, 0L, 2L, 1L, 0L, 3L, 8L, 9L),
    away_goals = c(0L, 0L, 1L, 1L, 1L, 2L, 7L, 6L),
    mu_home = c(1.2, 0.9, 1.5, 1.1, 0.8, 1.7, 1.4, 1.6),
    mu_away = c(0.8, 0.7, 1.0, 1.0, 1.1, 1.3, 1.0, 0.9),
    stringsAsFactors = FALSE
  )
}

dependence_tuning_editions <- function() {
  data.frame(
    outer_edition_id = "wc2010",
    inner_edition_id = c("wc1998", "wc2002", "wc2006"),
    inner_completion_date = as.Date(c("1998-07-12", "2002-06-30", "2006-07-09")),
    outer_opener_date = as.Date("2010-06-11"),
    stringsAsFactors = FALSE
  )
}

fit_dependence_test_parameters <- function(history = dependence_parameter_history()) {
  fit_fold_dependence_parameters(
    history = history,
    outer_edition_id = "wc2010",
    outer_opener_date = as.Date("2010-06-11"),
    tuning_editions = dependence_tuning_editions(),
    support_max = 40L
  )
}

dependence_sibling_rows <- function(hash = strrep("a", 64)) {
  expand.grid(
    dependence_id = c("independent", "dixon_coles", "bivariate_poisson"),
    track_id = c("frozen", "updating"),
    fixture_id = c("f1", "f2"),
    stringsAsFactors = FALSE
  ) |>
    transform(
      outer_edition_id = "wc2010", boundary_id = "b1",
      mean_prediction_hash = hash
    )
}

test_that("one prior-fit fold-global parameter is emitted per dependence family", {
  require_dependence_parameter_api()
  fit <- fit_dependence_test_parameters()

  expect_identical(sort(fit$dependence_id), c("bivariate_poisson", "dixon_coles"))
  expect_identical(unique(fit$outer_edition_id), "wc2010")
  expect_false("track_id" %in% names(fit))
  expect_identical(
    as.integer(table(fit$dependence_id)),
    c(1L, 1L)
  )
  expect_true(all(is.finite(fit$parameter)))
  expect_true(all(fit$parameter > fit$lower_bound & fit$parameter < fit$upper_bound))
  expect_true(all(fit$training_count == 6L))
  expect_true(all(as.Date(fit$training_max_date) < as.Date("2010-06-11")))
  expect_true(all(fit$optimization_status == "converged"))
})

test_that("assessed-outcome poisoning and input order cannot change parameters or manifests", {
  require_dependence_parameter_api()
  history <- dependence_parameter_history()
  poisoned <- history
  assessed <- poisoned$edition_id == "wc2010"
  poisoned$home_goals[assessed] <- 99L
  poisoned$away_goals[assessed] <- 88L

  fit <- fit_dependence_test_parameters(history)
  poisoned_fit <- fit_dependence_test_parameters(poisoned)
  reordered_fit <- fit_dependence_test_parameters(history[nrow(history):1, , drop = FALSE])
  expect_identical(fit, poisoned_fit)
  expect_identical(fit, reordered_fit)

  manifest <- score_dependence_manifest(fit, history, outer_edition_id = "wc2010")
  poisoned_manifest <- score_dependence_manifest(poisoned_fit, poisoned, outer_edition_id = "wc2010")
  reordered_manifest <- score_dependence_manifest(reordered_fit, history[nrow(history):1, , drop = FALSE], outer_edition_id = "wc2010")
  expect_identical(manifest, poisoned_manifest)
  expect_identical(manifest, reordered_manifest)
})

test_that("the same fold parameters and mean hashes are reused across tracks and fixtures", {
  require_dependence_parameter_api()
  siblings <- dependence_sibling_rows()
  expect_silent(validate_shared_mean_hash(siblings))

  parameter_rows <- merge(
    siblings,
    fit_dependence_test_parameters()[, c("dependence_id", "parameter"), drop = FALSE],
    by = "dependence_id", all.x = TRUE
  )
  parameter_rows$parameter[parameter_rows$dependence_id == "independent"] <- 0
  by_family <- split(parameter_rows, parameter_rows$dependence_id)
  expect_true(all(vapply(by_family, function(x) length(unique(x$parameter)) == 1L, logical(1))))
  expect_true(all(vapply(by_family, function(x) length(unique(x$mean_prediction_hash)) == 1L, logical(1))))

  drift <- siblings
  drift$mean_prediction_hash[drift$dependence_id == "dixon_coles" & drift$fixture_id == "f1"] <- strrep("b", 64)
  expect_error(validate_shared_mean_hash(drift), "mean.*hash|shared mean")
})

test_that("chronology and fold-global shape reject late or track-specific evidence", {
  require_dependence_parameter_api()
  invalid_tuning <- dependence_tuning_editions()
  invalid_tuning$inner_completion_date[3] <- as.Date("2010-06-11")
  expect_error(
    fit_fold_dependence_parameters(
      dependence_parameter_history(), "wc2010", as.Date("2010-06-11"), invalid_tuning, 40L
    ),
    "strictly before|chronology|prior"
  )

  siblings <- dependence_sibling_rows()
  siblings$parameter <- ifelse(siblings$track_id == "frozen", 0.1, 0.2)
  expect_error(validate_shared_mean_hash(siblings), "track|fold-global|parameter")
})

test_that("dependence manifests expose bounded prior evidence without fallback", {
  require_dependence_parameter_api()
  history <- dependence_parameter_history()
  fit <- fit_dependence_test_parameters(history)
  manifest <- score_dependence_manifest(fit, history, outer_edition_id = "wc2010")

  expect_true(all(c(
    "dependence_id", "parameter", "lower_bound", "upper_bound", "objective",
    "training_count", "training_min_date", "training_max_date",
    "eligible_match_ids_sha256", "mean_prediction_hash", "optimization_status",
    "package_versions", "r_version", "fallback_status", "manifest_sha256"
  ) %in% names(manifest)))
  expect_true(all(manifest$optimization_status == "converged"))
  expect_true(all(manifest$fallback_status == "none"))
  expect_true(all(as.Date(manifest$training_max_date) < as.Date("2010-06-11")))
  expect_true(all(grepl("^[0-9a-f]{64}$", manifest$eligible_match_ids_sha256)))
  expect_true(all(grepl("^[0-9a-f]{64}$", manifest$mean_prediction_hash)))
  expect_true(all(grepl("^[0-9a-f]{64}$", manifest$manifest_sha256)))
})
