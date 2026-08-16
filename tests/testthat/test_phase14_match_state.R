library(testthat)

phase14_match_state_test_project_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/"
)

phase14_match_state_fixture_path <- file.path(
  phase14_match_state_test_project_root,
  "tests/fixtures/phase14/match_lifecycle_cases.csv"
)

phase14_match_state_cases <- function() {
  utils::read.csv(
    phase14_match_state_fixture_path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = ""
  )
}

phase14_score_pair_is_complete <- function(home, away) {
  xor(is.na(home), is.na(away)) == FALSE
}

phase14_match_state_builder_input <- function(cases) {
  output <- cases[, c(
    "source_fixture_id", "source_status", "regulation_home_goals",
    "regulation_away_goals", "final_home_goals", "final_away_goals",
    "shootout_home_goals", "shootout_away_goals", "winner_team_id",
    "counts_for_standings", "counts_for_form"
  ), drop = FALSE]
  output$match_id <- cases$expected_match_id
  output$match_status <- cases$expected_match_status
  output$completion_method <- cases$expected_completion_method
  output
}

production_path <- file.path(
  phase14_match_state_test_project_root,
  "R/competition/match_state.R"
)
if (file.exists(production_path)) source(production_path, local = .GlobalEnv)

test_that("lifecycle fixture freezes the complete D-02 state matrix", {
  cases <- phase14_match_state_cases()
  required <- c(
    "case_id", "identity_case_id", "source_fixture_id", "source_status",
    "expected_match_status", "expected_completion_method",
    "regulation_home_goals", "regulation_away_goals", "final_home_goals",
    "final_away_goals", "shootout_home_goals", "shootout_away_goals",
    "winner_team_id", "counts_for_standings", "counts_for_form",
    "expected_match_id", "expected_valid", "expected_reason"
  )

  expect_named(cases, required)
  expect_equal(anyDuplicated(cases$case_id), 0L)
  expect_lte(nrow(cases), 20L)
  expect_setequal(
    unique(stats::na.omit(cases$expected_match_status)),
    c("scheduled", "in_progress", "completed", "postponed", "abandoned")
  )
  expect_setequal(
    unique(cases$expected_completion_method),
    c("not_applicable", "regulation", "extra_time", "penalties", "awarded")
  )

  valid <- cases[cases$expected_valid, , drop = FALSE]
  completed <- valid$expected_match_status == "completed"
  expect_true(all(valid$expected_completion_method[!completed] == "not_applicable"))
  expect_true(all(valid$expected_completion_method[completed] != "not_applicable"))

  unknown <- cases[cases$case_id == "unknown-source", , drop = FALSE]
  expect_equal(nrow(unknown), 1L)
  expect_false(unknown$expected_valid)
  expect_true(is.na(unknown$expected_match_status))
  expect_identical(unknown$expected_reason, "unmapped_source_status")
})

test_that("score axes and count flags encode D-03 and D-04 independently", {
  cases <- phase14_match_state_cases()
  valid <- cases[cases$expected_valid, , drop = FALSE]
  for (prefix in c("regulation", "final", "shootout")) {
    home <- valid[[paste0(prefix, "_home_goals")]]
    away <- valid[[paste0(prefix, "_away_goals")]]
    expect_true(all(phase14_score_pair_is_complete(home, away)), info = prefix)
  }

  penalties <- valid[valid$expected_completion_method == "penalties", , drop = FALSE]
  expect_equal(nrow(penalties), 1L)
  expect_identical(penalties$final_home_goals, penalties$final_away_goals)
  expect_true(penalties$shootout_home_goals != penalties$shootout_away_goals)

  awarded <- valid[valid$expected_completion_method == "awarded", , drop = FALSE]
  expect_true(awarded$counts_for_standings)
  expect_false(awarded$counts_for_form)
  expect_true(is.na(awarded$regulation_home_goals))
  expect_false(is.na(awarded$final_home_goals))

  inactive <- valid$expected_match_status %in% c(
    "scheduled", "in_progress", "postponed", "abandoned"
  )
  expect_true(all(!valid$counts_for_standings[inactive]))
  expect_true(all(!valid$counts_for_form[inactive]))

  invalid <- cases[!cases$expected_valid, , drop = FALSE]
  expect_setequal(
    invalid$expected_reason,
    c(
      "unmapped_source_status", "unpaired_final_score",
      "penalty_requires_tied_final_score",
      "shootout_requires_penalty_completion"
    )
  )
})

test_that("score and status corrections cannot remint canonical identity", {
  cases <- phase14_match_state_cases()
  corrections <- cases[cases$identity_case_id == "correction-1", , drop = FALSE]

  expect_equal(nrow(corrections), 2L)
  expect_equal(length(unique(corrections$source_fixture_id)), 1L)
  expect_equal(length(unique(corrections$expected_match_id)), 1L)
  expect_setequal(corrections$expected_match_status, c("scheduled", "completed"))
  expect_false(identical(
    corrections$final_home_goals[[1L]],
    corrections$final_home_goals[[2L]]
  ))
})

test_that("canonical match API enforces the frozen lifecycle and score contract", {
  skip_if_not(exists("phase14_build_canonical_matches"))

  cases <- phase14_match_state_cases()
  valid <- cases[cases$expected_valid, , drop = FALSE]
  canonical <- phase14_build_canonical_matches(
    phase14_match_state_builder_input(valid)
  )

  expect_equal(nrow(canonical), nrow(valid))
  expect_true(all(c(
    "match_id", "source_status", "match_status", "completion_method",
    "regulation_home_goals", "regulation_away_goals", "final_home_goals",
    "final_away_goals", "shootout_home_goals", "shootout_away_goals",
    "winner_team_id", "counts_for_standings", "counts_for_form"
  ) %in% names(canonical)))
  expect_identical(as.character(canonical$match_id), valid$expected_match_id)
  expect_identical(as.character(canonical$source_status), valid$source_status)
  expect_identical(as.character(canonical$match_status), valid$expected_match_status)
  expect_identical(
    as.character(canonical$completion_method),
    valid$expected_completion_method
  )

  invalid <- cases[!cases$expected_valid, , drop = FALSE]
  for (index in seq_len(nrow(invalid))) {
    expect_error(
      phase14_build_canonical_matches(
        phase14_match_state_builder_input(invalid[index, , drop = FALSE])
      ),
      "source|status|score|penalt|shootout|pair|unknown|unmapped",
      info = invalid$case_id[[index]]
    )
  }
})
