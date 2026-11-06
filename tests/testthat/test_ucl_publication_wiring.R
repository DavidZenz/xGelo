library(testthat)

ucl_wiring_root <- normalizePath(if (basename(getwd()) == "testthat") "../.." else ".", mustWork = TRUE)
ucl_wiring_namespace <- function() {
  env <- new.env(parent = globalenv())
  withr::local_dir(ucl_wiring_root)
  sys.source(file.path(ucl_wiring_root, "scripts/stage_non_wc_dashboards.R"), env)
  env$non_wc_runtime
}
ucl_wiring_facts <- function(env) {
  env$phase21_payload_ucl(list(edition_id = "ucl_2026_27", status = "production_blocked"))
}

test_that("disabled renderer never reads persisted outcomes or invokes club inference", {
  env <- ucl_wiring_namespace()
  facts <- ucl_wiring_facts(env)
  env$phase18_read_ucl_refresh_current <- function(...) list(pointer = list(accepted_generation_sha256 = strrep("a", 64)))
  env$phase21_payload_ucl_live_source <- function(...) facts
  env$phase19_forecast_current_ucl <- function(...) stop("Inference must not run")
  env$phase21_ucl_attach_persisted_outcomes <- function(...) stop("Outlook read must not run")
  output <- env$render_ucl_live_dashboard("disabled", write_output = FALSE)
  expect_identical(output$metadata$forecast_status, "unavailable")
  expect_identical(output$sections, facts$sections)
  expect_match(output$metadata$forecast_model_quality, "Disabled", fixed = TRUE)
})

test_that("approved renderer uses the actual fixed reader and preserves blocked facts", {
  env <- ucl_wiring_namespace()
  facts <- ucl_wiring_facts(env)
  facts$sections$standings$rows <- list(list(Club = "Declared wiring fixture", Points = 3L))
  env$phase18_read_ucl_refresh_current <- function(...) list(pointer = list(accepted_generation_sha256 = strrep("a", 64)))
  env$phase21_payload_ucl_live_source <- function(...) facts
  env$phase19_forecast_current_ucl <- function(...) list(status = "blocked", reason_code = "declared_fixture_only")
  before <- getwd()
  output <- env$render_ucl_live_dashboard("approved", write_output = FALSE)
  expect_identical(getwd(), before)
  expect_identical(output$metadata$tournament_status, "unavailable")
  expect_identical(output$metadata$tournament_reason_code, "publication_missing")
  expect_identical(output$sections$standings, facts$sections$standings)
  expect_false(isTRUE(output$metadata$production_eligible))
  expect_true(env$phase21_validate_ucl_persisted_outcome_payload(output))
  expect_silent(env$phase21_non_wc_validate_cl_predictions(output, format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")))
})

test_that("real missing-parent publication rejects forged rows, flags and metadata-only claims", {
  env <- ucl_wiring_namespace()
  facts <- ucl_wiring_facts(env)
  now <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  expect_silent(env$phase21_non_wc_validate_cl_predictions(facts, now))
  variants <- list(
    function(p) { p$sections$projected_outcomes$rows <- list(list(Club = "Forged", Chance = "100%")); p },
    function(p) { p$metadata$tournament_status <- "available"; p$metadata$production_eligible <- TRUE; p },
    function(p) { p$cl_tournament_evidence <- list(simulation_count = 10000L); p },
    function(p) { p$metadata$simulation_count <- 10000L; p },
    function(p) { p$sections$rank_distributions$status <- "available"; p })
  for (change in variants)
    expect_error(env$phase21_non_wc_validate_cl_predictions(change(facts), now), "accepted tournament authority")
})

test_that("a blocked tournament read preserves the separate match cutoff", {
  env <- ucl_wiring_namespace(); payload <- ucl_wiring_facts(env)
  # Declared presentation fixture remains production-ineligible throughout.
  payload$sections$match_forecasts$rows <- list(list(Home = "Declared fixture"))
  payload$metadata$information_cutoff_utc <- "2026-11-06T01:00:00Z"
  result <- env$phase21_ucl_attach_persisted_outcomes(payload)
  expect_false(isTRUE(result$metadata$production_eligible))
  expect_identical(result$metadata$tournament_status, "unavailable")
  expect_identical(result$metadata$information_cutoff_utc, payload$metadata$information_cutoff_utc)
  expect_identical(result$metadata$match_information_cutoff_utc, payload$metadata$information_cutoff_utc)
  expect_true(is.na(result$metadata$tournament_information_cutoff_utc))
  expect_identical(result$sections$match_forecasts$rows, payload$sections$match_forecasts$rows)
  expect_match(result$sections$match_forecasts$reason, "Match forecast information cutoff: 2026-11-06T01:00:00Z.", fixed = TRUE)
  repeated <- env$phase21_ucl_attach_persisted_outcomes(result)
  expect_identical(repeated$metadata$match_information_cutoff_utc, result$metadata$match_information_cutoff_utc)
  expect_identical(repeated$sections$match_forecasts$reason, result$sections$match_forecasts$reason)
})

test_that("persisted match ledger formatting keeps identities, probabilities and lifecycle", {
  env <- ucl_wiring_namespace()
  clubs <- data.frame(club_id = c("club_declared_a", "club_declared_b"), display_name = c("Declared A", "Declared B"))
  ledger <- data.frame(fixture_id = c("second", "past", "first"),
    home_club_id = "club_declared_a", away_club_id = "club_declared_b",
    kickoff_utc = c("2026-11-07T20:00:00Z", "2026-11-06T02:00:00Z", "2026-11-06T20:00:00Z"),
    forecast_status = "available", prob_home = 0.501, prob_draw = 0.25, prob_away = 0.249,
    xg_home = 1.234, xg_away = 0.987, likely_score = "1-0")
  rows <- env$.phase21_cl_format_match_rows(ledger, clubs, "2026-11-06T02:00:00Z")
  expect_equal(nrow(rows), 2L)
  expect_identical(rows[["Kickoff (UTC)"]], c("2026-11-06T20:00:00Z", "2026-11-07T20:00:00Z"))
  expect_identical(rows$Home, rep("Declared A", 2))
  expect_identical(rows[["Home win"]], rep("50.1%", 2))
  expect_identical(rows[["Expected home goals"]], rep(1.23, 2))
  expect_identical(rows[["Most likely score"]], rep("1–0", 2))
  ledger$home_club_id[[1]] <- "club_unknown"
  expect_error(env$.phase21_cl_format_match_rows(ledger, clubs, "2026-11-06T02:00:00Z"), "unknown clubs")
})

test_that("publication dispatch separates match provenance from tournament-only model lineage", {
  env <- ucl_wiring_namespace(); payload <- ucl_wiring_facts(env)
  # Private mechanical dispatch doubles only; this is not production-positive
  # evidence. The preceding test exercises the actual fixed missing-parent read.
  calls <- 0L
  env$phase21_validate_ucl_persisted_outcome_payload <- function(value, now_utc) {
    calls <<- calls + 1L
    identical(value$metadata$tournament_publication_sha256, strrep("a", 64))
  }
  contract <- list(model_sha256 = strrep("b", 64), calibrator_sha256 = strrep("c", 64))
  env$phase19_resolve_production_club_release <- function() list(release_id = "declared-fixture-model", model_contract = contract)
  payload$metadata$model_release_id <- "declared-fixture-model"
  payload$metadata$model_sha256 <- contract$model_sha256
  payload$metadata$calibrator_sha256 <- contract$calibrator_sha256
  payload$metadata$tournament_status <- "available"
  payload$metadata$tournament_publication_sha256 <- strrep("a", 64)
  payload$metadata$production_eligible <- TRUE
  expect_null(payload$metadata$forecast_provenance)
  expect_silent(env$phase21_non_wc_validate_cl_predictions(payload, "2026-11-06T02:00:00Z"))
  expect_identical(calls, 1L)
  bad <- payload; bad$metadata$model_sha256 <- strrep("d", 64)
  expect_error(env$phase21_non_wc_validate_cl_predictions(bad, "2026-11-06T02:00:00Z"), "model_sha256")
  bad <- payload; bad$metadata$tournament_publication_sha256 <- strrep("d", 64)
  expect_error(env$phase21_non_wc_validate_cl_predictions(bad, "2026-11-06T02:00:00Z"), "accepted tournament authority")
  bad <- payload; bad$sections$match_forecasts$rows <- list(list(Home = "Declared fixture"))
  expect_error(env$phase21_non_wc_validate_cl_predictions(bad, "2026-11-06T02:00:00Z"), "forecast lineage")
  bad$metadata$forecast_status <- "available"
  bad$metadata$match_information_cutoff_utc <- "2026-11-06T01:00:00Z"
  bad$metadata$forecast_provenance <- bad$metadata[c("source_bundle_sha256", "model_release_id", "model_sha256", "calibrator_sha256")]
  bad$metadata$forecast_provenance$information_cutoff_utc <- "2026-11-06T01:00:00Z"
  expect_silent(env$phase21_non_wc_validate_cl_predictions(bad, "2026-11-06T02:00:00Z"))
  bad$metadata$match_information_cutoff_utc <- "2026-11-06T01:01:00Z"
  expect_error(env$phase21_non_wc_validate_cl_predictions(bad, "2026-11-06T02:00:00Z"), "cutoff differs")
})
