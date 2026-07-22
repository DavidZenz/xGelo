library(testthat)

project_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))
dynamic_module <- file.path(project_root, "R/forecast/dynamic_goal_ability.R")
if (file.exists(dynamic_module)) source(dynamic_module)

require_dynamic_tuning_api <- function() {
  required <- c(
    "initialize_dynamic_goal_state",
    "predict_dynamic_goal_batch",
    "select_dynamic_goal_hyperparameters",
    "fit_dynamic_elo_coefficient",
    "dynamic_goal_manifest"
  )
  missing <- required[!vapply(required, exists, logical(1), mode = "function")]
  if (length(missing)) {
    stop(paste("Wave 0 RED contract awaits:", paste(missing, collapse = ", ")), call. = FALSE)
  }
}

dynamic_tuning_history <- function() {
  data.frame(
    match_id = paste0("m", 1:8),
    edition_id = rep(c("wc1998", "wc2002", "wc2006", "wc2010"), each = 2),
    actual_completion_date = as.Date(c(
      "1998-06-10", "1998-06-11", "2002-06-10", "2002-06-11",
      "2006-06-10", "2006-06-11", "2010-06-10", "2010-06-11"
    )),
    home_team_id = rep(c("A", "C"), 4),
    away_team_id = rep(c("B", "D"), 4),
    home_goals = c(2, 0, 1, 3, 2, 1, 0, 4),
    away_goals = c(0, 1, 1, 0, 1, 2, 3, 0),
    elo_diff = c(40, -20, 30, 60, 15, -35, 90, 10),
    elo_diff__value_present = TRUE,
    elo_diff__source_present = TRUE,
    elo_diff__source_date = as.Date(c(
      "1998-06-09", "1998-06-10", "2002-06-09", "2002-06-10",
      "2006-06-09", "2006-06-10", "2010-06-09", "2010-06-10"
    )),
    elo_diff__imputed = FALSE,
    elo_diff__imputation_reason = "",
    stringsAsFactors = FALSE
  )
}

dynamic_tuning_editions <- function() {
  data.frame(
    outer_edition_id = "wc2010",
    inner_edition_id = c("wc1998", "wc2002", "wc2006"),
    inner_completion_date = as.Date(c("1998-07-12", "2002-06-30", "2006-07-09")),
    outer_opener_date = as.Date("2010-06-11"),
    stringsAsFactors = FALSE
  )
}

dynamic_tuning_grid <- function() {
  data.frame(pseudo_exposure = c(2, 4, 8, 16, 32), half_life_days = 730, stringsAsFactors = FALSE)
}

select_dynamic_test_settings <- function(history = dynamic_tuning_history()) {
  select_dynamic_goal_hyperparameters(
    history = history,
    outer_edition_id = "wc2010",
    tuning_editions = dynamic_tuning_editions(),
    tuning_grid = dynamic_tuning_grid(),
    support_max = 40L
  )
}

test_that("prior tournaments select one track-shared setting with stronger-shrinkage tie-breaking", {
  require_dynamic_tuning_api()
  settings <- select_dynamic_test_settings()

  expect_identical(unique(settings$outer_edition_id), "wc2010")
  expect_identical(sort(unique(settings$track_id)), c("frozen", "updating"))
  expect_length(unique(settings$pseudo_exposure), 1L)
  expect_length(unique(settings$half_life_days), 1L)
  expect_identical(unique(settings$half_life_days), 730)
  tied <- settings$objective_rps == min(settings$objective_rps)
  expect_identical(unique(settings$pseudo_exposure), max(settings$candidate_pseudo_exposure[tied]))
  expect_true(all(settings$inner_edition_id %in% c("wc1998", "wc2002", "wc2006")))
  expect_true(all(as.Date(settings$inner_completion_date) < as.Date(settings$outer_opener_date)))
})

test_that("assessed labels cannot change dynamic settings or the Elo coefficient", {
  require_dynamic_tuning_api()
  history <- dynamic_tuning_history()
  poisoned <- history
  outer <- poisoned$edition_id == "wc2010"
  poisoned$home_goals[outer] <- 99
  poisoned$away_goals[outer] <- 77

  settings <- select_dynamic_test_settings(history)
  poisoned_settings <- select_dynamic_test_settings(poisoned)
  expect_identical(settings, poisoned_settings)

  fit <- fit_dynamic_elo_coefficient(
    history, outer_edition_id = "wc2010", outer_opener_date = as.Date("2010-06-11")
  )
  poisoned_fit <- fit_dynamic_elo_coefficient(
    poisoned, outer_edition_id = "wc2010", outer_opener_date = as.Date("2010-06-11")
  )
  expect_identical(fit, poisoned_fit)
  expect_true(is.finite(fit$coefficient))
  expect_true(isTRUE(fit$converged))
})

test_that("the Elo sibling adds one signed term to identical standalone dynamic means", {
  require_dynamic_tuning_api()
  state <- initialize_dynamic_goal_state(
    team_ids = c("A", "B"), global_goal_rate = 1.25,
    pseudo_exposure = 8, as_of_date = as.Date("2010-06-10")
  )
  fixtures <- data.frame(
    fixture_id = "f1", match_date = as.Date("2010-06-11"),
    home_team_id = "A", away_team_id = "B", venue_role = "home",
    elo_diff = 80, elo_diff__value_present = TRUE, elo_diff__source_present = TRUE,
    elo_diff__source_date = as.Date("2010-06-10"), elo_diff__imputed = FALSE,
    elo_diff__imputation_reason = "", stringsAsFactors = FALSE
  )
  standalone <- predict_dynamic_goal_batch(state, fixtures, elo_coefficient = 0)
  augmented <- predict_dynamic_goal_batch(state, fixtures, elo_coefficient = 0.002)

  expect_identical(standalone$dynamic_log_mu_home, augmented$dynamic_log_mu_home)
  expect_identical(standalone$dynamic_log_mu_away, augmented$dynamic_log_mu_away)
  expect_equal(log(augmented$mu_home) - log(standalone$mu_home), 0.002 * fixtures$elo_diff)
  expect_equal(log(augmented$mu_away) - log(standalone$mu_away), -0.002 * fixtures$elo_diff)
})

test_that("Elo fitting rejects absent or stale canonical provenance", {
  require_dynamic_tuning_api()
  absent <- dynamic_tuning_history()
  absent$elo_diff__source_present[1] <- FALSE
  expect_error(
    fit_dynamic_elo_coefficient(absent, "wc2010", as.Date("2010-06-11")),
    "source_present|provenance"
  )

  stale <- dynamic_tuning_history()
  stale$elo_diff__source_date[1] <- stale$actual_completion_date[1]
  expect_error(
    fit_dynamic_elo_coefficient(stale, "wc2010", as.Date("2010-06-11")),
    "strictly before|source date|chronology"
  )
  expect_false("elo_ratings" %in% names(formals(fit_dynamic_elo_coefficient)))
})

test_that("dynamic manifests retain all tuning parents and inactive xG evidence", {
  require_dynamic_tuning_api()
  history <- dynamic_tuning_history()
  settings <- select_dynamic_test_settings(history)
  fit <- fit_dynamic_elo_coefficient(history, "wc2010", as.Date("2010-06-11"))
  manifest <- dynamic_goal_manifest(fit, settings, history, outer_edition_id = "wc2010")

  expect_true(all(c(
    "state_sha256", "tuning_sha256", "eligible_match_ids_sha256",
    "elo_coefficient", "elo_value_sha256", "elo_provenance_sha256",
    "max_elo_source_date", "historical_xg_active", "historical_xg_inactive_reason",
    "historical_form_active", "historical_form_inactive_reason", "convergence_status"
  ) %in% names(manifest)))
  expect_false(any(manifest$historical_xg_active))
  expect_false(any(manifest$historical_form_active))
  expect_true(all(nzchar(manifest$historical_xg_inactive_reason)))
  expect_true(all(nzchar(manifest$historical_form_inactive_reason)))
  hash_columns <- grep("_sha256$", names(manifest), value = TRUE)
  expect_true(all(vapply(manifest[hash_columns], function(x) all(grepl("^[0-9a-f]{64}$", x)), logical(1))))
})
