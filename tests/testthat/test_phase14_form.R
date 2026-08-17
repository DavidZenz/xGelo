library(testthat)

phase14_form_test_project_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/"
)

phase14_form_fixture_path <- file.path(
  phase14_form_test_project_root,
  "tests/fixtures/phase14/point_in_time_history.csv"
)

phase14_form_registry_path <- file.path(
  phase14_form_test_project_root,
  "data/competition/registries/national_team_xg_sources.csv"
)

phase14_form_cases <- function() {
  utils::read.csv(
    phase14_form_fixture_path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = c("", "NA")
  )
}

phase14_form_accepted_history <- function(history) {
  accepted <- history[history$expected_model_form_eligible, , drop = FALSE]
  accepted$source_id <- "fixture-shot-xg-v1"
  accepted$source_artifact_id <- "fixture-shot-xg-v1"
  accepted$source_lineage_id <- paste0("fixture-shot-xg-v1::", accepted$match_id)
  accepted$source_row_sha256 <- vapply(seq_len(nrow(accepted)), function(index) {
    digest::digest(
      paste(accepted$match_id[[index]], accepted$team_id[[index]], accepted$xgf[[index]], accepted$xga[[index]], sep = "|"),
      algo = "sha256",
      serialize = FALSE
    )
  }, character(1))
  accepted
}

phase14_form_accepted_registry <- function() {
  artifact_path <- tempfile("phase14-shot-xg-", fileext = ".csv")
  writeLines("fixture shot-derived evidence", artifact_path)
  registry <- data.frame(
    schema_version = "phase14-national-team-xg-source-v1",
    source_id = "fixture-shot-xg-v1",
    source_scope = "senior_mens_national_team",
    evidence_basis = "shot_derived",
    acceptance_status = "accepted",
    accepted_artifact_path = artifact_path,
    accepted_artifact_sha256 = digest::digest(file = artifact_path, algo = "sha256"),
    stable_match_id_contract = "canonical_match_id_required",
    stable_team_id_contract = "xgelo_team_id_required",
    point_in_time_evidence_contract = "evidence_completed_at_utc_strictly_before_feature_cutoff_utc",
    review_state = "reviewed",
    reviewed_at_utc = "2026-08-17T00:00:00Z",
    reviewed_by = "phase14-test",
    review_note = "test-only accepted shot-derived source",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  registry$row_sha256 <- phase14_national_team_xg_registry_row_hash(registry)
  registry
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

test_that("production display form keeps competition and all-senior history independent", {
  cases <- phase14_form_cases()
  history <- cases[cases$record_type == "history", , drop = FALSE]
  teams <- c("TEAM_ZERO", "TEAM_ONE", "TEAM_FOUR", "TEAM_FIVE", "TEAM_MORE")

  all_senior <- phase14_build_display_form(
    matches = history,
    teams = teams,
    edition_id = "euro2024",
    feature_cutoff_utc = "2026-06-10T12:00:00Z",
    form_scope = "all_senior_international"
  )
  competition <- phase14_build_display_form(
    matches = history,
    teams = teams,
    edition_id = "euro2024",
    feature_cutoff_utc = "2026-06-10T12:00:00Z",
    form_scope = "competition"
  )

  expect_equal(
    all_senior$sample_count[match(all_senior$team_id, teams)],
    c(0L, 1L, 4L, 5L, 5L)
  )
  expect_equal(
    competition$sample_count[match(competition$team_id, teams)],
    c(0L, 1L, 4L, 5L, 4L)
  )

  more_all <- all_senior[all_senior$team_id == "TEAM_MORE", , drop = FALSE]
  more_competition <- competition[competition$team_id == "TEAM_MORE", , drop = FALSE]
  expect_identical(
    more_all$contributing_match_ids,
    "MORE-02|MORE-03|MORE-04|MORE-05|MORE-06"
  )
  expect_identical(
    more_competition$contributing_match_ids,
    "MORE-03|MORE-04|MORE-05|MORE-06"
  )
  expect_identical(more_all$result_sequence, "LWDLW")
  expect_true(grepl("friendly", more_all$competition_type, fixed = TRUE))
  expect_false(grepl("friendly", more_competition$competition_type, fixed = TRUE))
  expect_true(all(is.na(all_senior$xgf)))
})

test_that("production all-senior display form accepts normalized full history", {
  historical <- utils::read.csv(
    file.path(phase14_form_test_project_root, "data/processed/martj42_historical_normalized.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = c("", "NA")
  )

  display_form <- phase14_build_display_form(
    matches = historical,
    teams = c("team_aut", "team_deu"),
    feature_cutoff_utc = "2026-08-01T00:00:00Z",
    form_scope = "all_senior_international"
  )

  expect_equal(nrow(display_form), 2L)
  expect_true(all(display_form$sample_count <= 5L))
  expect_true(all(display_form$availability_status == "available"))
  expect_true(all(display_form$feature_cutoff_utc == "2026-08-01T00:00:00Z"))
  expect_true(all(is.na(display_form$xgf) & is.na(display_form$xga) & is.na(display_form$xgd)))
})

test_that("production model form preserves explicit unavailable evidence", {
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

test_that("current Austria and Germany model form remains unavailable", {
  historical <- utils::read.csv(
    file.path(phase14_form_test_project_root, "data/processed/martj42_historical_normalized.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = c("", "NA")
  )
  model_form <- phase14_build_model_form(
    xg_history = historical,
    teams = c("team_aut", "team_deu"),
    feature_cutoff_utc = "2026-08-01T00:00:00Z",
    span = 12L
  )

  expect_identical(model_form$availability_status, c("unavailable", "unavailable"))
  expect_identical(
    model_form$availability_reason,
    c("no_accepted_national_team_xg_source", "no_accepted_national_team_xg_source")
  )
  expect_true(all(is.na(model_form$source_id)))
  expect_true(all(model_form$sample_count == 0L))
  expect_true(all(model_form$feature_cutoff_utc == "2026-08-01T00:00:00Z"))
  expect_true(all(is.na(model_form[, c("xgf", "xga", "xgd", "xgf_ewma", "xga_ewma", "xgd_ewma")])))
})

test_that("the current national-team xG registry is explicit and unaccepted", {
  registry <- utils::read.csv(
    phase14_form_registry_path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = c("", "NA")
  )

  expect_named(registry, phase14_national_team_xg_source_schema())
  expect_true(nrow(registry) >= 1L)
  expect_true(all(registry$source_scope == "senior_mens_national_team"))
  expect_true(all(registry$evidence_basis == "shot_derived"))
  expect_false(any(registry$acceptance_status == "accepted"))
  expect_silent(phase14_validate_national_team_xg_registry(registry))
})

test_that("accepted shot-derived national-team xG produces span-12 EWMA", {
  cases <- phase14_form_cases()
  history <- cases[cases$record_type == "history", , drop = FALSE]
  accepted_history <- phase14_form_accepted_history(history)
  registry <- phase14_form_accepted_registry()

  adapted <- phase14_adapt_national_team_xg(
    xg_history = accepted_history,
    registry = registry,
    feature_cutoff_utc = "2026-06-10T12:00:00Z"
  )
  expect_equal(nrow(adapted), 6L)
  expect_true(all(adapted$source_id == "fixture-shot-xg-v1"))
  expect_true(all(adapted$source_scope == "senior_mens_national_team"))
  expect_true(all(adapted$evidence_basis == "shot_derived"))
  expect_true(all(grepl("^[0-9a-f]{64}$", adapted$source_row_sha256)))

  model <- phase14_build_model_form(
    xg_history = accepted_history,
    teams = c("TEAM_ZERO", "TEAM_MORE"),
    feature_cutoff_utc = "2026-06-10T12:00:00Z",
    span = 12L,
    registry = registry
  )
  more <- model[model$team_id == "TEAM_MORE", , drop = FALSE]
  zero <- model[model$team_id == "TEAM_ZERO", , drop = FALSE]
  expect_identical(more$availability_status, "available")
  expect_equal(more$sample_count, 6L)
  expect_equal(more$window_span, 12L)
  expect_true(is.finite(more$xgf_ewma) && is.finite(more$xga_ewma) && is.finite(more$xgd_ewma))
  expect_equal(more$xgd_ewma, more$xgf_ewma - more$xga_ewma)
  expect_identical(zero$availability_status, "unavailable")
  expect_true(all(is.na(zero[, c("xgf_ewma", "xga_ewma", "xgd_ewma")])))

  reversed <- phase14_build_model_form(
    xg_history = accepted_history[rev(seq_len(nrow(accepted_history))), , drop = FALSE],
    teams = c("TEAM_ZERO", "TEAM_MORE"),
    feature_cutoff_utc = "2026-06-10T12:00:00Z",
    span = 12L,
    registry = registry
  )
  expect_identical(model$canonical_table_sha256, reversed$canonical_table_sha256)
  expect_identical(
    model$canonical_row_sha256[model$team_id == "TEAM_MORE"],
    reversed$canonical_row_sha256[reversed$team_id == "TEAM_MORE"]
  )
})

test_that("national-team xG adapter rejects club form and non-shot evidence", {
  cases <- phase14_form_cases()
  history <- cases[cases$record_type == "history", , drop = FALSE]
  registry <- phase14_form_accepted_registry()
  accepted_history <- phase14_form_accepted_history(history)

  club_form <- utils::read.csv(
    file.path(phase14_form_test_project_root, "data/processed/rolling_form.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  expect_error(
    phase14_adapt_national_team_xg(club_form, registry, "2026-06-10T12:00:00Z"),
    "club|national.team.xG|stable match"
  )

  scoreline <- accepted_history
  scoreline$source_scope <- "results_only"
  scoreline$evidence_basis <- "scoreline"
  expect_error(
    phase14_adapt_national_team_xg(scoreline, registry, "2026-06-10T12:00:00Z"),
    "scope|shot_derived|scoreline"
  )
})

test_that("national-team xG adapter rejects football goals relabelled as xG", {
  cases <- phase14_form_cases()
  history <- cases[cases$record_type == "history", , drop = FALSE]
  relabelled <- phase14_form_accepted_history(history)
  relabelled$xgf <- relabelled$football_goals_for
  relabelled$xga <- relabelled$football_goals_against

  expect_error(
    phase14_adapt_national_team_xg(
      relabelled,
      registry = phase14_form_accepted_registry(),
      feature_cutoff_utc = "2026-06-10T12:00:00Z"
    ),
    "goals relabelled as xG"
  )
})
