library(testthat)

live_prediction_test_root <- normalizePath(file.path(getwd(),
  if (basename(getwd()) == "testthat") "../.." else "."), winslash = "/", mustWork = TRUE)
# Reuse the existing isolated, hash-validated fixture constructors, without
# executing their test cases or resolving a production pointer.
for (path in c("test_phase19_club_goal_model.R", "test_phase19_club_calibration.R")) {
  for (expression in parse(file.path(live_prediction_test_root, "tests/testthat", path))) {
    if (!(is.call(expression) && identical(expression[[1L]], as.name("test_that"))))
      eval(expression, envir = .GlobalEnv)
  }
}
source(file.path(live_prediction_test_root, "R/club/live_predictions.R"))

live_prediction_test_context <- local({
  cached <- NULL
  function() {
    if (is.null(cached)) {
      context <- goal_model_test_context()
      calibration <- phase19_calibration_test_context()
      calibrator <- phase19_fit_club_calibrator(calibration$rows, calibration$fold,
        calibration$candidate, calibration$protocol)
      fit <- goal_model_test_fit(context)
      cutoff <- "2025-06-01T18:00:00Z"
      replay <- phase19_replay_club_ratings(context$training, context$current,
        context$parameters, min(cutoff, context$training$cutoff_utc))
      matches <- data.frame(provider_match_id = c("future_a", "finished", "past", "neutral", "unknown", "knockout"),
        kickoff_utc = c("2025-06-02T18:00:00Z", "2025-05-01T18:00:00Z", cutoff,
          rep("2025-06-03T18:00:00Z", 3L)),
        home_club_id = "club_alpha", away_club_id = c(rep("club_beta", 4L), "club_unknown", "club_beta"),
        status = c("SCHEDULED", "FINISHED", rep("TIMED", 4L)),
        stage = c(rep("LEAGUE_STAGE", 5L), "LAST_16"), neutral_venue = c(FALSE, FALSE, FALSE, TRUE, FALSE, FALSE),
        home_score = c(NA_integer_, 4L, rep(NA_integer_, 4L)),
        away_score = c(NA_integer_, 1L, rep(NA_integer_, 4L)), stringsAsFactors = FALSE)
      cached <<- list(context = context, fit = fit, calibrator = calibrator,
        replay = replay, matches = matches, cutoff = cutoff)
    }
    cached
  }
})

live_prediction_test_predict <- function(x = live_prediction_test_context(), matches = x$matches,
    cutoff = x$cutoff, fit = x$fit) {
  phase19_forecast_fixture_ucl(fit, x$calibrator, x$context$training,
    x$context$current, x$replay, matches, cutoff)
}

test_that("live club forecasts use strict prior evidence and real normalized NB grids", {
  x <- live_prediction_test_context()
  result <- live_prediction_test_predict(x)
  expect_identical(result$status, "available")
  expect_identical(result$predictions$fixture_id, "future_a")
  expect_identical(result$predictions$authority_mode, "fixture")
  expect_true(result$predictions$fixture_authority)
  expect_identical(result$predictions$fit_sha256, x$fit$fit_sha256)
  expect_identical(result$predictions$source_bundle_sha256, x$context$current$bundle_sha256)
  expect_equal(sum(result$predictions[c("p_home", "p_draw", "p_away")]), 1, tolerance = 1e-10)
  expect_equal(nrow(result$score_distributions), 41L * 41L)
  expect_equal(sum(result$score_distributions$probability), 1, tolerance = 1e-10)
  expect_silent(phase19_validate_live_club_forecasts(result))
  expect_false(any(grepl("score|label|outcome", names(result$predictions)) &
    names(result$predictions) %in% c("home_score", "away_score", "observed_outcome")))
  expect_setequal(result$unavailable$reason_code, c("kickoff_not_after_information_cutoff",
    "unsupported_neutral_venue", "historical_club_coverage_unavailable", "unsupported_competition_stage"))
  expect_false("finished" %in% c(result$predictions$fixture_id, result$unavailable$fixture_id))
})

test_that("fixture labels never influence a future forecast and earlier cutoffs are rejected", {
  x <- live_prediction_test_context()
  original <- live_prediction_test_predict(x)
  matches <- x$matches
  matches$home_score <- 99L
  matches$away_score <- 0L
  expect_identical(live_prediction_test_predict(x, matches), original)
  expect_error(live_prediction_test_predict(x, cutoff = "2025-05-31T18:00:00Z"),
    class = "phase19_live_club_error")
  matches$forecast_domain <- "national"
  expect_error(live_prediction_test_predict(x, matches), class = "phase19_live_club_error")
  matches <- rbind(x$matches, x$matches[1L, ])
  expect_error(live_prediction_test_predict(x, matches), class = "phase19_live_club_error")
})

test_that("live forecast validation detects probability and goal grid tampering", {
  result <- live_prediction_test_predict()
  changed <- result
  changed$predictions$p_home <- -0.1
  expect_error(phase19_validate_live_club_forecasts(changed))
  changed <- result
  changed$predictions$expected_home_goals <- changed$predictions$expected_home_goals + 1
  expect_error(phase19_validate_live_club_forecasts(changed), class = "phase19_live_club_error")
  changed <- result
  changed$score_distributions <- changed$score_distributions[-1L, ]
  expect_error(phase19_validate_live_club_forecasts(changed))
  changed <- result
  changed$predictions$information_cutoff_utc <- changed$predictions$kickoff_utc
  expect_error(phase19_validate_live_club_forecasts(changed), class = "phase19_live_club_error")
})

test_that("missing club release absence retains its machine reason for the dashboard", {
  absent <- phase19_live_club_absence("release_missing", "No approved club release is available.")
  expect_silent(phase19_validate_live_club_forecasts(absent))
  source(file.path(live_prediction_test_root, "R/dashboard/payload_contract_v2.R"))
  source(file.path(live_prediction_test_root, "R/dashboard/payload_ucl.R"))
  payload <- phase21_payload_ucl()
  payload$sections$results$rows <- list(list(Home = "Alpha", Away = "Beta", Score = "4–1"))
  updated <- phase21_ucl_attach_live_forecasts(payload, absent, data.frame(), character())
  expect_identical(updated$sections$results, payload$sections$results)
  expect_identical(updated$metadata$forecast_reason_code, "release_missing")
  expect_identical(updated$metadata$forecast_status, "unavailable")
  expect_length(updated$sections$match_forecasts$rows, 0L)
})

test_that("invalid production release returns typed absence instead of breaking rendering", {
  name <- "phase19_resolve_production_club_release"
  previous <- if (exists(name, envir = .GlobalEnv, inherits = FALSE)) get(name, envir = .GlobalEnv) else NULL
  on.exit(if (is.null(previous)) rm(list = name, envir = .GlobalEnv) else assign(name, previous, envir = .GlobalEnv))
  assign(name, function(...) stop(structure(list(message = "Release parent changed", call = NULL,
    reason_code = "production_parent_changed"), class = c("phase19_club_production_error", "error", "condition"))),
    envir = .GlobalEnv)
  absent <- phase19_forecast_current_ucl("2026-10-27T12:00:00Z")
  expect_identical(absent$status, "unavailable")
  expect_identical(absent$reason_code, "production_parent_changed")
  expect_silent(phase19_validate_live_club_forecasts(absent))
})


test_that("different future kickoff batches retain valid distribution and row identities", {
  x <- live_prediction_test_context()
  matches <- x$matches[1L, , drop = FALSE]
  second <- matches
  second$provider_match_id <- "future_b"
  second$kickoff_utc <- "2025-06-04T18:00:00Z"
  result <- live_prediction_test_predict(x, rbind(matches, second))
  expect_identical(result$predictions$fixture_id, c("future_a", "future_b"))
  expect_silent(phase19_validate_live_club_forecasts(result))
  expect_equal(nrow(result$score_distributions), 2L * 41L * 41L)
  source(file.path(live_prediction_test_root, "R/dashboard/payload_ucl.R"))
  payload <- phase21_payload_ucl()
  payload$metadata$source_bundle_sha256 <- x$context$current$bundle_sha256
  expect_error(phase21_ucl_attach_live_forecasts(payload, result, matches, character()),
    "approved production model")
})
