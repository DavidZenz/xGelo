library(testthat)

ucl_bridge_root <- normalizePath(if (basename(getwd()) == "testthat") "../.." else ".", mustWork = TRUE)
for (expr in parse(file.path(ucl_bridge_root, "tests/testthat/test_ucl_live_dashboard.R"))) {
  if (!is.call(expr) || !identical(expr[[1L]], as.name("test_that"))) eval(expr, envir = .GlobalEnv)
}
ucl_bridge_load <- function() {
  for (path in c("R/competition/uefa_champions_league_rules.R", "R/competition/uefa_champions_league_state.R", "R/competition/ucl_live_bridge.R"))
    source(file.path(ucl_bridge_root, path), local = .GlobalEnv)
}

test_that("live bridge maps accepted outcomes and suppresses every absent forecast", {
  current <- ucl_live_test_current()
  ucl_bridge_load()
  out <- ucl_live_build_bridge(current, now_utc = "2026-09-19T13:00:00Z")
  expect_equal(nrow(out$fixtures), 144L)
  expect_equal(nrow(out$ledger), 144L)
  expect_equal(sum(out$ledger$ledger_kind == "outcome"), 1L)
  completed <- out$ledger[out$ledger$ledger_kind == "outcome", ]
  expect_equal(completed$regulation_home_goals, 2L)
  expect_equal(completed$regulation_away_goals, 1L)
  expect_true(all(is.na(out$ledger$prob_home)))
  expect_true(all(out$ledger$forecast_status == "suppressed"))
  expect_equal(length(unique(out$ledger$fixture_id)), 144L)
  expect_true(all(grepl("^[0-9a-f]{64}$", out$ledger$row_sha256)))
  expect_false(out$readiness$tournament_eligible)
  expect_false(out$production_eligible)
  expect_identical(out$readiness$forecast_quality, "unavailable")
  expect_true("missing_edition_draw_procedure" %in% out$readiness$blocked_reason_codes)
  expect_true("production_outcome_writer_not_integrated" %in% out$readiness$blocked_reason_codes)
  expect_true(all(out$fixtures$venue_semantics == "accepted_league_phase_home_designation_not_stadium"))
})

test_that("past kickoffs yield pending suppression rows without retrospective probabilities", {
  current <- ucl_live_test_current()
  ucl_bridge_load()
  now <- max(as.character(current$accepted$tables$matches$kickoff_utc))
  out <- ucl_live_build_bridge(current, now_utc = now)
  expect_equal(out$readiness$future_fixture_count, 0L)
  expect_equal(out$readiness$result_pending_count, 143L)
  expect_equal(sum(out$ledger$ledger_kind == "result_pending"), 143L)
  expect_true(all(is.na(out$ledger$prob_home)))
  expect_equal(sum(!is.na(out$ledger$regulation_home_goals)), 1L)
  expect_true("past_kickoff_results_pending" %in% out$readiness$blocked_reason_codes)
  expect_error(ucl_live_build_bridge(current, now_utc = "2026-11-05T19:00:00+01:00"), "canonical UTC")
})

test_that("bridge never manufactures authority from tampered or unaccepted source facts", {
  current <- ucl_live_test_current()
  ucl_bridge_load()
  invalid <- current
  invalid$pointer$accepted_status <- "no_incumbent"
  expect_error(ucl_live_build_bridge(invalid), "accepted current UCL")
  invalid <- current
  invalid$accepted$tables$matches$home_score[[1L]] <- 99L
  expect_error(ucl_live_build_bridge(invalid), class = "phase18_ucl_bundle_error")
  # Merely allowing baseline display never enables tournament publication.
  out <- ucl_live_build_bridge(current, now_utc = "2026-09-19T13:00:00Z", allow_venue_baseline = TRUE)
  expect_false(out$readiness$tournament_eligible)
  expect_false(out$production_eligible)
})
