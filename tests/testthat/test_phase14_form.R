library(testthat)

phase14_form_test_project_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/"
)

phase14_form_fixture_path <- file.path(
  phase14_form_test_project_root,
  "tests/fixtures/phase14/point_in_time_history.csv"
)

phase14_form_cases <- function() {
  utils::read.csv(
    phase14_form_fixture_path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = c("", "NA")
  )
}

phase14_fixture_result <- function(goals_for, goals_against) {
  if (is.na(goals_for) || is.na(goals_against)) return(NA_character_)
  if (goals_for > goals_against) return("W")
  if (goals_for < goals_against) return("L")
  "D"
}

phase14_fixture_ordered_ids <- function(rows) {
  timestamp <- as.POSIXct(
    rows$evidence_completed_at_utc,
    format = "%Y-%m-%dT%H:%M:%SZ",
    tz = "UTC"
  )
  date_fallback <- as.POSIXct(as.Date(rows$evidence_date), tz = "UTC")
  sort_time <- ifelse(is.na(timestamp), as.numeric(date_fallback), as.numeric(timestamp))
  rows$match_id[order(sort_time, rows$match_id)]
}

production_path <- file.path(
  phase14_form_test_project_root,
  "R/competition/form.R"
)
if (file.exists(production_path)) source(production_path, local = .GlobalEnv)

test_that("point-in-time fixture freezes the D-09 through D-12 schema", {
  cases <- phase14_form_cases()
  required <- c(
    "record_type", "case_id", "match_id", "team_id", "opponent_team_id",
    "edition_id", "target_edition_id", "competition_type",
    "is_senior_mens_a", "match_status", "completion_method",
    "football_goals_for", "football_goals_against", "shootout_goals_for",
    "shootout_goals_against", "counts_for_form", "evidence_precision",
    "evidence_completed_at_utc", "evidence_date", "fixture_cutoff_utc",
    "expected_cutoff_eligible", "expected_competition_form_eligible",
    "expected_all_senior_form_eligible", "xgf", "xga", "source_scope",
    "evidence_basis", "expected_model_form_eligible", "expected_result",
    "expected_all_senior_sample_count", "expected_competition_sample_count",
    "expected_last_five_count", "expected_model_sample_count",
    "expected_display_availability_status",
    "expected_model_availability_status", "expected_display_window_type",
    "expected_model_window_type", "expected_model_span"
  )

  expect_named(cases, required)
  expect_equal(anyDuplicated(cases$case_id), 0L)
  expect_lte(nrow(cases), 32L)
  expect_setequal(cases$competition_type[cases$record_type == "history"], c("competition", "friendly"))
})

test_that("all-senior and competition histories remain separate", {
  cases <- phase14_form_cases()
  history <- cases[cases$record_type == "history", , drop = FALSE]
  expected <- cases[cases$record_type == "expectation", , drop = FALSE]

  all_senior_counts <- table(factor(
    history$team_id[history$expected_all_senior_form_eligible],
    levels = expected$team_id
  ))
  competition_counts <- table(factor(
    history$team_id[history$expected_competition_form_eligible],
    levels = expected$team_id
  ))

  expect_equal(as.integer(all_senior_counts), expected$expected_all_senior_sample_count)
  expect_equal(as.integer(competition_counts), expected$expected_competition_sample_count)
  expect_equal(pmin(as.integer(all_senior_counts), 5L), expected$expected_last_five_count)

  more <- history[history$team_id == "TEAM_MORE", , drop = FALSE]
  expect_true(any(more$competition_type == "friendly" & more$expected_all_senior_form_eligible))
  expect_true(any(more$edition_id == "euro2020" & more$expected_all_senior_form_eligible))
  expect_false(any(more$edition_id == "euro2020" & more$expected_competition_form_eligible))
  expect_equal(sum(more$expected_competition_form_eligible), 4L)
})

test_that("zero, singleton, and bounded last-five histories are explicit", {
  cases <- phase14_form_cases()
  expected <- cases[cases$record_type == "expectation", , drop = FALSE]

  zero <- expected[expected$team_id == "TEAM_ZERO", , drop = FALSE]
  one <- expected[expected$team_id == "TEAM_ONE", , drop = FALSE]
  more <- expected[expected$team_id == "TEAM_MORE", , drop = FALSE]
  expect_equal(zero$expected_all_senior_sample_count, 0L)
  expect_identical(zero$expected_display_availability_status, "unavailable")
  expect_equal(one$expected_all_senior_sample_count, 1L)
  expect_equal(one$expected_last_five_count, 1L)
  expect_equal(more$expected_all_senior_sample_count, 6L)
  expect_equal(more$expected_last_five_count, 5L)

  expect_error(
    phase14_fixture_ordered_ids(NULL),
    "argument|numeric|POSIX|origin|character|NULL"
  )
})

test_that("unplayed and purely awarded rows cannot enter display form", {
  cases <- phase14_form_cases()
  excluded <- cases[cases$case_id %in% c("pure-award", "unplayed"), , drop = FALSE]

  expect_true(all(!excluded$counts_for_form))
  expect_true(all(!excluded$expected_competition_form_eligible))
  expect_true(all(!excluded$expected_all_senior_form_eligible))
})

test_that("shootout kicks never change the football form result", {
  cases <- phase14_form_cases()
  shootout <- cases[cases$completion_method %in% "penalties", , drop = FALSE]

  expect_equal(nrow(shootout), 1L)
  expect_equal(shootout$football_goals_for, shootout$football_goals_against)
  expect_true(shootout$shootout_goals_for > shootout$shootout_goals_against)
  expect_identical(
    phase14_fixture_result(shootout$football_goals_for, shootout$football_goals_against),
    "D"
  )
  expect_identical(shootout$expected_result, "D")
})

test_that("last-five display form and span-12 model form cannot substitute", {
  cases <- phase14_form_cases()
  expected <- cases[cases$record_type == "expectation", , drop = FALSE]
  history <- cases[cases$record_type == "history", , drop = FALSE]

  expect_true(all(expected$expected_display_window_type == "last_five"))
  expect_true(all(expected$expected_model_window_type == "ewma"))
  expect_true(all(expected$expected_model_span == 12L))
  expect_false(any(expected$expected_display_window_type == expected$expected_model_window_type))

  model_counts <- table(factor(
    history$team_id[history$expected_model_form_eligible],
    levels = expected$team_id
  ))
  expect_equal(as.integer(model_counts), expected$expected_model_sample_count)
  expect_identical(
    expected$expected_model_availability_status[expected$team_id == "TEAM_ZERO"],
    "unavailable"
  )
})

test_that("production display form honors the frozen scopes and windows", {
  skip_if_not(exists("phase14_build_display_form"))

  cases <- phase14_form_cases()
  history <- cases[cases$record_type == "history", , drop = FALSE]
  expected <- cases[cases$record_type == "expectation", , drop = FALSE]
  display_form <- phase14_build_display_form(
    matches = history,
    teams = expected$team_id,
    edition_id = "euro2024",
    feature_cutoff_utc = "2026-06-10T12:00:00Z",
    form_scope = "all_senior_international"
  )

  expect_true(all(c(
    "team_id", "form_scope", "window_type", "window_size", "sample_count",
    "result_sequence", "competition_type", "feature_cutoff_utc",
    "contributing_match_ids", "availability_status"
  ) %in% names(display_form)))
  expect_true(all(display_form$window_type == "last_five"))
  expect_lte(max(display_form$sample_count), 5L)
})

test_that("production model form preserves explicit unavailable evidence", {
  skip_if_not(exists("phase14_build_model_form"))

  cases <- phase14_form_cases()
  history <- cases[cases$record_type == "history", , drop = FALSE]
  model_form <- phase14_build_model_form(
    xg_history = history,
    teams = c("TEAM_ZERO", "TEAM_MORE"),
    feature_cutoff_utc = "2026-06-10T12:00:00Z",
    span = 12L
  )

  zero <- model_form[model_form$team_id == "TEAM_ZERO", , drop = FALSE]
  expect_identical(zero$availability_status, "unavailable")
  expect_equal(zero$sample_count, 0L)
  expect_true(all(is.na(zero[, c("xgf_ewma", "xga_ewma", "xgd_ewma")])))
})
