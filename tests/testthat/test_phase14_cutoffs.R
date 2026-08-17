library(testthat)

phase14_cutoff_test_project_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/"
)

phase14_cutoff_fixture_path <- file.path(
  phase14_cutoff_test_project_root,
  "tests/fixtures/phase14/point_in_time_history.csv"
)

phase14_cutoff_cases <- function() {
  utils::read.csv(
    phase14_cutoff_fixture_path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = c("", "NA")
  )
}

phase14_fixture_cutoff_eligible <- function(row) {
  cutoff <- as.POSIXct(
    row$fixture_cutoff_utc,
    format = "%Y-%m-%dT%H:%M:%SZ",
    tz = "UTC"
  )
  if (identical(row$evidence_precision, "timestamp")) {
    evidence <- as.POSIXct(
      row$evidence_completed_at_utc,
      format = "%Y-%m-%dT%H:%M:%SZ",
      tz = "UTC"
    )
    return(!is.na(evidence) && evidence < cutoff)
  }
  if (identical(row$evidence_precision, "date")) {
    evidence_date <- as.Date(row$evidence_date)
    return(!is.na(evidence_date) && evidence_date < as.Date(cutoff, tz = "UTC"))
  }
  FALSE
}

phase14_fixture_canonical_lineage <- function(rows) {
  timestamp <- as.POSIXct(
    rows$evidence_completed_at_utc,
    format = "%Y-%m-%dT%H:%M:%SZ",
    tz = "UTC"
  )
  date_fallback <- as.POSIXct(as.Date(rows$evidence_date), tz = "UTC")
  sort_time <- ifelse(is.na(timestamp), as.numeric(date_fallback), as.numeric(timestamp))
  ordered <- rows$match_id[order(sort_time, rows$match_id)]
  canonical_ids <- paste(ordered, collapse = "|")
  codepoints <- utf8ToInt(canonical_ids)
  checksum <- sum(codepoints * seq_along(codepoints)) %% 2147483647
  list(ids = canonical_ids, hash = sprintf("%08x", as.integer(checksum)))
}

production_path <- file.path(
  phase14_cutoff_test_project_root,
  "R/competition/form.R"
)
if (file.exists(production_path)) source(production_path, local = .GlobalEnv)

test_that("exclusive cutoff handles second-level boundaries fail-closed", {
  cases <- phase14_cutoff_cases()
  history <- cases[cases$record_type == "history", , drop = FALSE]
  actual <- vapply(
    seq_len(nrow(history)),
    function(index) phase14_fixture_cutoff_eligible(history[index, , drop = FALSE]),
    logical(1)
  )

  expect_identical(actual, history$expected_cutoff_eligible)
  boundary <- history[history$case_id %in% c("one-01", "boundary-equal", "boundary-after"), , drop = FALSE]
  expect_identical(
    boundary$expected_cutoff_eligible,
    c(TRUE, FALSE, FALSE)
  )
})

test_that("date-only and missing-time evidence use conservative semantics", {
  cases <- phase14_cutoff_cases()
  boundary <- cases[cases$case_id %in% c(
    "date-prior-day", "date-same-day", "time-missing"
  ), , drop = FALSE]

  expect_identical(boundary$evidence_precision, c("date", "date", "missing"))
  expect_identical(boundary$expected_cutoff_eligible, c(TRUE, FALSE, FALSE))
  expect_true(is.na(boundary$evidence_completed_at_utc[boundary$case_id == "time-missing"]))
})

test_that("equal-time ties and input reordering preserve canonical lineage", {
  cases <- phase14_cutoff_cases()
  rows <- cases[
    cases$team_id == "TEAM_MORE" & cases$expected_all_senior_form_eligible,
    ,
    drop = FALSE
  ]
  tied <- rows[rows$evidence_completed_at_utc == "2026-06-05T18:00:00Z", , drop = FALSE]
  expect_identical(sort(tied$match_id), c("MORE-03", "MORE-04"))

  first <- phase14_fixture_canonical_lineage(rows)
  second <- phase14_fixture_canonical_lineage(rows[rev(seq_len(nrow(rows))), , drop = FALSE])
  expect_identical(first$ids, second$ids)
  expect_identical(first$hash, second$hash)
  expect_match(first$hash, "^[0-9a-f]{8}$")
})

test_that("model evidence is only shot-derived senior national-team xG", {
  cases <- phase14_cutoff_cases()
  history <- cases[cases$record_type == "history", , drop = FALSE]
  model <- history[history$expected_model_form_eligible, , drop = FALSE]

  expect_true(all(model$source_scope == "senior_mens_national_team"))
  expect_true(all(model$evidence_basis == "shot_derived"))
  expect_true(all(model$expected_cutoff_eligible))
  expect_true(all(!is.na(model$xgf) & !is.na(model$xga)))
  expect_true(all(model$match_id != "" & !is.na(model$match_id)))
})

test_that("production cutoff validator rejects equal and ambiguous evidence", {
  cases <- phase14_cutoff_cases()
  history <- cases[cases$record_type == "history", , drop = FALSE]
  eligible <- history[history$expected_cutoff_eligible, , drop = FALSE]
  expect_silent(phase14_assert_form_cutoffs(eligible))

  for (case_id in c("boundary-equal", "boundary-after", "date-same-day", "time-missing")) {
    invalid <- history[history$case_id == case_id, , drop = FALSE]
    expect_error(
      phase14_assert_form_cutoffs(invalid),
      "cutoff|equal|future|same-day|precision|time|missing",
      info = case_id
    )
  }
})
