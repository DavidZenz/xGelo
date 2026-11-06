library(testthat)
ucl_clock_root <- normalizePath(if (basename(getwd()) == "testthat") "../.." else ".", mustWork = TRUE)
ucl_clock_env <- function() {
  env <- new.env(parent = globalenv())
  withr::local_dir(ucl_clock_root)
  sys.source(file.path(ucl_clock_root, "scripts/stage_non_wc_dashboards.R"), env)
  env$non_wc_runtime
}

test_that("each authority boundary uses its own fixed current-clock default", {
  env <- ucl_clock_env(); read_default <- validate_default <- FALSE
  spy <- new.env(parent = baseenv())
  # Deliberately invalid availability claim. Receipt validation stays FALSE;
  # this exercises call arguments without fabricating production authority.
  spy$ucl_read_production_outcomes <- function(now_utc) {
    read_default <<- missing(now_utc)
    list(status = "available", production_eligible = TRUE, reason_code = "declared_invalid_receipt")
  }
  spy$ucl_validate_production_outcome_read_result <- function(result, now_utc) {
    validate_default <<- missing(now_utc)
    FALSE
  }
  env$.phase21_cl_facade <- function() spy
  result <- env$.phase21_cl_context("2000-01-01T00:00:00Z")
  expect_true(read_default); expect_true(validate_default)
  expect_identical(result$status, "blocked")
  expect_identical(result$reason_code, "declared_invalid_receipt")
})

test_that("actual fixed reader retains its real-clock gate without accepted outputs", {
  env <- ucl_clock_env(); facade <- env$.phase21_cl_facade()
  stale <- format(Sys.time()-120, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  old <- facade$ucl_read_production_outcomes(stale)
  current <- facade$ucl_read_production_outcomes()
  expect_identical(old$reason_code, "production_reader_requires_current_time")
  expect_identical(current$reason_code, "publication_missing")
  expect_false(old$production_eligible); expect_false(current$production_eligible)
})

test_that("public clocks cannot backdate or advance authority before a read", {
  env <- ucl_clock_env()
  payload <- env$phase21_payload_ucl(list(edition_id = "ucl_2026_27", status = "production_blocked"))
  payload$metadata$tournament_status <- "available"
  payload$metadata$production_eligible <- TRUE
  called <- 0L
  env$.phase21_cl_context <- function(...) { called <<- called + 1L; stop("Must not read for a forged clock") }
  for (offset in c(-120, 120)) {
    instant <- format(Sys.time()+offset, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    expect_false(env$phase21_validate_ucl_persisted_outcome_payload(payload, instant))
  }
  expect_identical(called, 0L)
})

test_that("current league-fixture expiry treats equality as unavailable and never invents a result", {
  env <- ucl_clock_env(); namespace <- env$.phase21_cl_facade()$.ucl_runtime_load()
  check <- namespace$phase20_ucl_runtime$.ucl_read_current_fixture_window
  bundle <- list(tables = list(fixture_forecast_ledger = data.frame(
    forecast_status = c("available", "unavailable"),
    kickoff_utc = c("2026-11-06T12:00:00Z", "2026-11-05T12:00:00Z"))))
  expect_true(check(bundle, "2026-11-06T11:59:59Z"))
  expect_error(check(bundle, "2026-11-06T12:00:00Z"), "past_unconfirmed_league_fixture")
  expect_error(check(bundle, "2026-11-06T12:00:01Z"), "past_unconfirmed_league_fixture")
  bundle$tables$fixture_forecast_ledger$forecast_status[[1L]] <- "unavailable"
  expect_true(check(bundle, "2026-11-06T12:00:01Z"))
})

test_that("approved rendering repartitions actual accepted-fixture mechanics after a slow read", {
  # Reuse only declared source fixture constructors; no test or live acquisition
  # from the source file executes, and no production model is supplied.
  declarations <- new.env(parent = globalenv())
  withr::local_dir(ucl_clock_root)
  for (expr in parse(file.path(ucl_clock_root, "tests/testthat/test_ucl_live_dashboard.R")))
    if (!is.call(expr) || !identical(expr[[1L]], as.name("test_that"))) eval(expr, declarations)
  current <- declarations$ucl_live_test_current()
  env <- ucl_clock_env()
  matches <- current$accepted$tables$matches
  open <- matches[!matches$status %in% c("FINISHED", "CANCELLED"), , drop = FALSE]
  at <- min(as.character(open$kickoff_utc))
  instant <- as.POSIXct(at, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  early <- format(instant-1, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  late <- format(instant+1, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  clock <- early; calls <- 0L
  env$.phase21_cl_now <- function() clock
  env$phase18_read_ucl_refresh_current <- function(...) current
  env$phase19_forecast_current_ucl <- function(...) {
    calls <<- calls + 1L
    env$phase19_live_club_absence("declared_fixture_only", "Declared non-authoritative fixture")
  }
  env$.phase21_cl_context <- function(...) {
    clock <<- late
    list(status = "blocked", reason_code = "declared_slow_read_without_model")
  }
  before <- env$phase21_payload_ucl_live_source(current, now_utc = early)
  result <- env$render_ucl_live_dashboard("approved", now_utc = early, write_output = FALSE)
  expect_identical(calls, 1L)
  expect_identical(result$metadata$generated_at_utc, late)
  expect_lt(length(result$sections$fixtures$rows), length(before$sections$fixtures$rows))
  expect_true(all(vapply(result$sections$fixtures$rows, function(row) row[["Kickoff (UTC)"]] > late, logical(1))))
  expect_gt(result$metadata$result_confirmation_pending_count, before$metadata$result_confirmation_pending_count)
  expect_identical(result$metadata$completed_result_count, before$metadata$completed_result_count)
  pending <- Filter(function(row) identical(row$Status, "Result awaiting source confirmation"), result$sections$results$rows)
  expect_true(all(vapply(pending, function(row) is.na(row$Score), logical(1))))
  expect_identical(result$metadata$tournament_status, "unavailable")
  expect_false(isTRUE(result$metadata$production_eligible))
})

test_that("presentation rebasing preserves fresh facts and cannot grant fixture authority", {
  env <- ucl_clock_env()
  facts <- env$phase21_payload_ucl(list(edition_id = "ucl_2026_27", status = "production_blocked"))
  presented <- env$phase21_ucl_attach_persisted_outcomes(facts)
  facts$sections$results$rows <- list(list(Status = "Result awaiting source confirmation", Score = NA_character_))
  fresh <- facts$sections[c("standings", "fixtures", "results", "form", "match_forecasts")]
  result <- env$.phase21_cl_rebase_facts(facts, presented)
  expect_identical(result$sections[names(fresh)], fresh)
  expect_false(isTRUE(result$metadata$production_eligible))
  expect_true(env$phase21_validate_ucl_persisted_outcome_payload(result))
  claimed <- presented; claimed$metadata$tournament_status <- "available"
  fixture <- env$.phase21_cl_rebase_facts(facts, claimed)
  expect_false(isTRUE(fixture$metadata$production_eligible))
  expect_false(env$phase21_validate_ucl_persisted_outcome_payload(fixture))
  changed <- presented; changed$metadata$source_bundle_sha256 <- strrep("f", 64)
  expect_error(env$.phase21_cl_rebase_facts(facts, changed), "different sources")
})
