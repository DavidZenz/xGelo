library(testthat)

source(file.path(
  normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
                winslash = "/", mustWork = TRUE),
  "tests/testthat/helper_phase19_club_fixture.R"
))
phase19_test_load()

rating_test_require <- function() {
  module <- file.path(phase19_test_root, "R/club/rating.R")
  if (!file.exists(module)) stop("RED: missing Phase 19 club rating module", call. = FALSE)
  source(module, local = .GlobalEnv)
  phase19_test_require(c(
    "phase19_club_rating_parameters",
    "phase19_initialize_club_rating_state",
    "phase19_forecast_club_rating_batch",
    "phase19_validate_club_rating_state"
  ))
}

rating_test_authority <- local({
  value <- NULL
  function() {
    if (is.null(value)) {
      root <- phase19_test_fixture_root("rating-batch")
      value <<- list(
        root = root,
        training = phase19_load_fixture_club_training_snapshot(root),
        current = phase19_load_fixture_current_ucl_club_snapshot(root)
      )
    }
    value
  }
})

rating_test_parameters <- function() {
  phase19_club_rating_parameters(
    base_rating = 1500,
    home_advantage = 60,
    k_factor = 24,
    inactivity_half_life_days = 730
  )
}

rating_test_state <- function() {
  authority <- rating_test_authority()
  phase19_initialize_club_rating_state(
    authority$training, authority$current, rating_test_parameters()
  )
}

rating_test_batch <- function() {
  data.frame(
    fixture_id = c("fixture_b", "fixture_a"),
    forecast_domain = "club",
    authority_mode = "fixture",
    boundary_id = "kickoff:2025-05-01T18:00:00Z",
    kickoff_utc = "2025-05-01T18:00:00Z",
    home_club_id = c("club_gamma", "club_alpha"),
    away_club_id = c("club_delta", "club_beta"),
    status = "completed",
    counts_for_model = TRUE,
    regulation_home_goals = c(0L, 4L),
    regulation_away_goals = c(1L, 0L),
    extra_time_home_goals = c(3L, NA_integer_),
    extra_time_away_goals = c(2L, NA_integer_),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

test_that("one exact kickoff batch forecasts from one immutable club snapshot", {
  rating_test_require()
  state <- rating_test_state()
  before <- serialize(state, NULL, version = 3)
  result <- phase19_forecast_club_rating_batch(state, rating_test_batch())

  expect_identical(serialize(state, NULL, version = 3), before)
  expect_identical(result$predictions$fixture_id, c("fixture_a", "fixture_b"))
  expect_true(all(c(
    "home_pre_match_rating", "away_pre_match_rating", "rating_difference",
    "home_adjustment", "home_prior_count", "away_prior_count", "cold_start",
    "evidence_cutoff_exclusive", "pre_batch_state_sha256", "batch_sha256",
    "parameter_sha256", "training_snapshot_sha256", "current_snapshot_sha256"
  ) %in% names(result$predictions)))
  expect_equal(result$predictions$home_pre_match_rating, c(1500, 1500))
  expect_equal(result$predictions$away_pre_match_rating, c(1500, 1500))
  expect_equal(result$predictions$rating_difference, c(60, 60))
  expect_true(all(result$predictions$cold_start))
  expect_true(all(result$predictions$evidence_cutoff_exclusive ==
                    "2025-05-01T18:00:00Z"))
  expect_false(identical(result$state$state_sha256, state$state_sha256))
  expect_equal(sum(result$state$clubs$prior_match_count), 4L)
  expect_silent(phase19_validate_club_rating_state(result$state))
})

test_that("same-batch order and outcomes cannot leak into peer predictions", {
  rating_test_require()
  state <- rating_test_state()
  batch <- rating_test_batch()
  forward <- phase19_forecast_club_rating_batch(state, batch)
  reverse <- phase19_forecast_club_rating_batch(state, batch[2:1, , drop = FALSE])

  expect_identical(
    serialize(forward$predictions, NULL, version = 3),
    serialize(reverse$predictions, NULL, version = 3)
  )
  expect_identical(
    serialize(forward$state, NULL, version = 3),
    serialize(reverse$state, NULL, version = 3)
  )

  changed <- batch
  changed$regulation_home_goals[changed$fixture_id == "fixture_a"] <- 12L
  changed_result <- phase19_forecast_club_rating_batch(state, changed)
  peer_columns <- c(
    "home_pre_match_rating", "away_pre_match_rating", "rating_difference",
    "home_prior_count", "away_prior_count", "pre_batch_state_sha256"
  )
  expect_identical(
    forward$predictions[forward$predictions$fixture_id == "fixture_b", peer_columns],
    changed_result$predictions[changed_result$predictions$fixture_id == "fixture_b", peer_columns]
  )
})

test_that("club rating boundary rejects duplicate, unknown, national and mixed evidence", {
  rating_test_require()
  state <- rating_test_state()
  batch <- rating_test_batch()

  expect_error(
    phase19_forecast_club_rating_batch(state, rbind(batch, batch[1, , drop = FALSE])),
    class = "phase19_club_rating_error"
  )
  unknown <- batch
  unknown$home_club_id[[1L]] <- "club_unknown"
  expect_error(phase19_forecast_club_rating_batch(state, unknown),
               class = "phase19_club_rating_error")
  national <- batch
  national$home_club_id[[1L]] <- "AUT"
  expect_error(phase19_forecast_club_rating_batch(state, national),
               class = "phase19_club_rating_error")
  mixed_domain <- batch
  mixed_domain$forecast_domain[[1L]] <- "national"
  expect_error(phase19_forecast_club_rating_batch(state, mixed_domain),
               class = "phase19_club_rating_error")
  mixed_authority <- batch
  mixed_authority$authority_mode[[1L]] <- "production"
  expect_error(phase19_forecast_club_rating_batch(state, mixed_authority),
               class = "phase19_club_rating_error")
})

test_that("club rating parameters are closed, finite and canonically identified", {
  rating_test_require()
  parameters <- rating_test_parameters()
  expect_identical(parameters$forecast_domain, "club")
  expect_identical(parameters$base_rating, 1500)
  expect_match(parameters$parameter_sha256, "^[0-9a-f]{64}$")
  expect_error(phase19_club_rating_parameters(base_rating = 0),
               class = "phase19_club_rating_error")
  expect_error(phase19_club_rating_parameters(home_advantage = Inf),
               class = "phase19_club_rating_error")
  expect_error(phase19_club_rating_parameters(k_factor = -1),
               class = "phase19_club_rating_error")
  expect_error(phase19_club_rating_parameters(inactivity_half_life_days = 0),
               class = "phase19_club_rating_error")
})
