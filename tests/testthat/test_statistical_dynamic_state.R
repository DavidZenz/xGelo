library(testthat)

project_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))
dynamic_module <- file.path(project_root, "R/forecast/dynamic_goal_ability.R")
if (file.exists(dynamic_module)) source(dynamic_module)

require_dynamic_state_api <- function() {
  required <- c(
    "initialize_dynamic_goal_state",
    "decay_dynamic_goal_state",
    "predict_dynamic_goal_batch",
    "update_dynamic_goal_batch",
    "replay_dynamic_goal_states"
  )
  missing <- required[!vapply(required, exists, logical(1), mode = "function")]
  if (length(missing)) {
    stop(paste("Wave 0 RED contract awaits:", paste(missing, collapse = ", ")), call. = FALSE)
  }
}

dynamic_test_fixtures <- function(date = as.Date("2000-01-02")) {
  data.frame(
    fixture_id = c("fixture_b", "fixture_a"),
    boundary_id = "boundary_20000102",
    match_date = as.Date(date),
    home_team_id = c("C", "A"),
    away_team_id = c("D", "B"),
    venue_role = c("neutral", "home"),
    stringsAsFactors = FALSE
  )
}

dynamic_test_results <- function(date = as.Date("2000-01-02")) {
  data.frame(
    match_id = c("match_b", "match_a"),
    match_date = as.Date(date),
    home_team_id = c("C", "A"),
    away_team_id = c("D", "B"),
    home_goals = c(0L, 4L),
    away_goals = c(1L, 0L),
    importance_weight = c(1, 1.5),
    completed = TRUE,
    stringsAsFactors = FALSE
  )
}

new_dynamic_test_state <- function() {
  initialize_dynamic_goal_state(
    team_ids = c("A", "B", "C", "D"),
    global_goal_rate = 1.25,
    pseudo_exposure = 8,
    as_of_date = as.Date("2000-01-01")
  )
}

canonical_dynamic_predictions <- function(x) {
  rownames(x) <- NULL
  x[order(x$fixture_id), , drop = FALSE]
}

test_that("same-day fixtures use one immutable snapshot and batch updates are byte-identical", {
  require_dynamic_state_api()
  fixtures <- dynamic_test_fixtures()
  results <- dynamic_test_results()

  first_predictions <- predict_dynamic_goal_batch(new_dynamic_test_state(), fixtures)
  second_predictions <- predict_dynamic_goal_batch(new_dynamic_test_state(), fixtures[2:1, , drop = FALSE])
  expect_identical(
    serialize(canonical_dynamic_predictions(first_predictions), NULL, version = 3),
    serialize(canonical_dynamic_predictions(second_predictions), NULL, version = 3)
  )

  first_state <- update_dynamic_goal_batch(new_dynamic_test_state(), results)
  second_state <- update_dynamic_goal_batch(new_dynamic_test_state(), results[2:1, , drop = FALSE])
  expect_identical(
    serialize(first_state, NULL, version = 3),
    serialize(second_state, NULL, version = 3)
  )
})

test_that("a completed result affects only a strictly later date boundary", {
  require_dynamic_state_api()
  state <- new_dynamic_test_state()
  same_day <- dynamic_test_fixtures()[1, , drop = FALSE]
  before <- predict_dynamic_goal_batch(state, same_day)
  updated <- update_dynamic_goal_batch(state, dynamic_test_results()[1, , drop = FALSE])

  peer <- predict_dynamic_goal_batch(state, same_day)
  later <- same_day
  later$fixture_id <- "fixture_later"
  later$match_date <- as.Date("2000-01-03")
  later$boundary_id <- "boundary_20000103"
  after <- predict_dynamic_goal_batch(
    decay_dynamic_goal_state(updated, later$match_date, half_life_days = 730),
    later
  )

  expect_identical(before$mu_home, peer$mu_home)
  expect_identical(before$mu_away, peer$mu_away)
  expect_false(isTRUE(all.equal(c(before$mu_home, before$mu_away), c(after$mu_home, after$mu_away))))
})

test_that("updates aggregate scored and conceded goals with frozen importance weights", {
  require_dynamic_state_api()
  updated <- update_dynamic_goal_batch(new_dynamic_test_state(), dynamic_test_results())
  teams <- updated$teams[match(c("A", "B", "C", "D"), updated$teams$team_id), , drop = FALSE]

  expect_equal(teams$GF, c(6, 0, 0, 1))
  expect_equal(teams$GA, c(0, 6, 1, 0))
  expect_equal(teams$W, c(1.5, 1.5, 1, 1))
  expect_equal(teams$history_match_count, rep(1L, 4L))
})

test_that("all history decays continuously toward the global mean without reset or deletion", {
  require_dynamic_state_api()
  updated <- update_dynamic_goal_batch(new_dynamic_test_state(), dynamic_test_results()[2, , drop = FALSE])
  near <- predict_dynamic_goal_batch(updated, dynamic_test_fixtures(as.Date("2000-01-03"))[2, , drop = FALSE])
  far_state <- decay_dynamic_goal_state(updated, as.Date("2020-01-03"), half_life_days = 730)
  far <- predict_dynamic_goal_batch(far_state, dynamic_test_fixtures(as.Date("2020-01-03"))[2, , drop = FALSE])

  near_effect <- abs(log(near$mu_home / near$global_goal_rate))
  far_effect <- abs(log(far$mu_home / far$global_goal_rate))
  expect_lt(far_effect, near_effect)
  expect_lt(far_effect, 1e-2)
  expect_true(all(far_state$teams$W >= 0))
  expect_equal(sum(far_state$teams$history_match_count), 2L)
  expect_false(any(c("cycle_id", "window_start", "reset_date") %in% names(far_state)))
})

test_that("replay is cycle-label invariant and marks historical xG and form inactive", {
  require_dynamic_state_api()
  history <- rbind(
    transform(dynamic_test_results(as.Date("1998-06-10")), cycle_id = "cycle_1998"),
    transform(dynamic_test_results(as.Date("2002-06-10")), cycle_id = "cycle_2002")
  )
  fixtures <- dynamic_test_fixtures(as.Date("2002-06-11"))

  labelled <- replay_dynamic_goal_states(history, fixtures, initial_state = new_dynamic_test_state())
  unlabelled <- replay_dynamic_goal_states(history[names(history) != "cycle_id"], fixtures, initial_state = new_dynamic_test_state())
  expect_identical(serialize(labelled, NULL, version = 3), serialize(unlabelled, NULL, version = 3))
  expect_true(all(c(
    "state_age_days", "observed_exposure", "shrinkage_weight", "cold_start",
    "historical_xg_active", "historical_xg_inactive_reason",
    "historical_form_active", "historical_form_inactive_reason"
  ) %in% names(labelled$predictions)))
  expect_false(any(labelled$predictions$historical_xg_active))
  expect_false(any(labelled$predictions$historical_form_active))
  expect_true(all(nzchar(labelled$predictions$historical_xg_inactive_reason)))
  expect_true(all(nzchar(labelled$predictions$historical_form_inactive_reason)))
})
