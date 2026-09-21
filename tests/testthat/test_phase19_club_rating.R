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
    k_factor = 20,
    inactivity_factor = 0.995
  )
}

rating_test_matching_current <- function(current, club_ids = c(
  "club_alpha", "club_beta", "club_gamma", "club_delta"
)) {
  clubs <- current$clubs[seq_along(club_ids), , drop = FALSE]
  clubs$provider_club_id <- as.character(9000L + seq_along(club_ids))
  clubs$club_id <- club_ids
  clubs$display_name <- paste("Rating", club_ids)
  clubs$canonical_name <- clubs$display_name
  clubs$row_sha256 <- ""
  clubs$row_sha256 <- phase18_ucl_projected_row_hash(clubs)
  clubs <- clubs[order(clubs$club_id, method = "radix"), , drop = FALSE]
  rownames(clubs) <- NULL
  current$clubs <- clubs
  current$source_clubs <- clubs
  current$club_count <- as.integer(nrow(clubs))
  current$roster_sha256 <- phase18_hash_table_v2(
    clubs, key = "club_id", schema_tag = "phase19-current-ucl-club-roster-v1"
  )
  current$source_club_table_sha256 <- phase19_current_ucl_source_clubs_sha256(clubs)
  current$snapshot_sha256 <- phase19_current_snapshot_sha256(current)
  phase19_validate_current_ucl_club_snapshot(current, "fixture")
  current
}

rating_test_training_variant <- function(training, mutate_rows) {
  rows <- mutate_rows(training$matches)
  rows$row_sha256 <- ""
  rows$row_sha256 <- phase18_history_row_sha256(rows)
  rows <- phase18_history_canonical_table(
    rows, c("source_id", "source_match_id", "match_id")
  )
  training$matches <- rows
  training$row_count <- as.integer(nrow(rows))
  training$phase19_matches_sha256 <- phase18_hash_table_v2(
    rows, key = c("source_id", "source_match_id", "match_id"),
    schema_tag = "phase19-club-training-matches-v1"
  )
  training$snapshot_sha256 <- phase19_training_snapshot_sha256(training)
  phase19_validate_club_training_snapshot(training, "fixture")
  training
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
  expect_error(phase19_club_rating_parameters(base_rating = 1400),
               class = "phase19_club_rating_error")
  expect_error(phase19_club_rating_parameters(home_advantage = Inf),
               class = "phase19_club_rating_error")
  expect_error(phase19_club_rating_parameters(k_factor = -1),
               class = "phase19_club_rating_error")
  expect_error(phase19_club_rating_parameters(inactivity_factor = 0),
               class = "phase19_club_rating_error")
})

test_that("replay is strict at completion and evidence cutoffs", {
  rating_test_require()
  phase19_test_require(c("phase19_replay_club_ratings"))
  authority <- rating_test_authority()
  current <- rating_test_matching_current(authority$current)

  before <- phase19_replay_club_ratings(
    authority$training, current, rating_test_parameters(),
    cutoff_utc = "2025-02-01T19:59:59Z"
  )
  exact <- phase19_replay_club_ratings(
    authority$training, current, rating_test_parameters(),
    cutoff_utc = "2025-02-01T20:00:00Z"
  )
  after <- phase19_replay_club_ratings(
    authority$training, current, rating_test_parameters(),
    cutoff_utc = "2025-02-01T20:00:01Z"
  )

  expect_identical(before$status, "ready")
  expect_equal(sum(before$state$clubs$prior_match_count), 0L)
  expect_equal(sum(exact$state$clubs$prior_match_count), 0L)
  expect_equal(sum(after$state$clubs$prior_match_count), 2L)
  expect_identical(exact$state$last_evidence_available_at_utc, "")
  expect_identical(after$state$last_evidence_available_at_utc,
                   "2025-02-01T20:00:00Z")
  expect_true(all(after$predictions$evidence_cutoff_exclusive <
                    "2025-02-01T20:00:01Z"))
})

test_that("date-only rows share one conservative boundary and cannot train peers", {
  rating_test_require()
  authority <- rating_test_authority()
  current <- rating_test_matching_current(authority$current)
  date_only <- rating_test_training_variant(authority$training, function(rows) {
    selected <- rows$competition_id == "league-a"
    rows$event_date[selected] <- "2025-02-01"
    rows$kickoff_utc[selected] <- ""
    rows$kickoff_precision[selected] <- "date"
    rows$completion_not_before_utc[selected] <- "2025-02-02T00:00:00Z"
    rows$evidence_observed_at_utc[selected] <- "2025-02-02T00:00:00Z"
    rows$evidence_available_at_utc[selected] <- "2025-02-02T00:00:00Z"
    rows$evidence_precision_policy[selected] <- "date_next_day_utc"
    rows
  })
  replay <- phase19_replay_club_ratings(
    date_only, current, rating_test_parameters(),
    cutoff_utc = "2025-02-02T00:00:01Z"
  )
  peers <- replay$predictions[replay$predictions$home_club_id %in%
                                c("club_alpha", "club_beta") &
                                replay$predictions$away_club_id %in%
                                c("club_alpha", "club_beta"), , drop = FALSE]

  expect_equal(nrow(peers), 2L)
  expect_equal(length(unique(peers$boundary_id)), 1L)
  expect_equal(length(unique(peers$pre_batch_state_sha256)), 1L)
  expect_true(all(peers$home_prior_count == 0L))
  expect_true(all(peers$away_prior_count == 0L))
  expect_equal(sum(replay$state$clubs$prior_match_count), 4L)
})

test_that("replay uses regulation outcomes and is byte-stable under history permutation", {
  rating_test_require()
  authority <- rating_test_authority()
  current <- rating_test_matching_current(authority$current)
  first <- phase19_replay_club_ratings(
    authority$training, current, rating_test_parameters(),
    history = authority$training$matches
  )
  shuffled <- phase19_replay_club_ratings(
    authority$training, current, rating_test_parameters(),
    history = authority$training$matches[rev(seq_len(nrow(authority$training$matches))), ,
                                         drop = FALSE]
  )
  expect_identical(serialize(first, NULL, version = 3),
                   serialize(shuffled, NULL, version = 3))

  extra_time <- rating_test_training_variant(authority$training, function(rows) {
    rows$extra_time_home_goals <- "99"
    rows$extra_time_away_goals <- "0"
    rows$final_home_goals <- "99"
    rows$final_away_goals <- "0"
    rows$shootout_home_goals <- "8"
    rows$shootout_away_goals <- "7"
    rows$completion_method <- "penalties"
    rows$score_semantics <- "penalties"
    rows
  })
  changed <- phase19_replay_club_ratings(
    extra_time, current, rating_test_parameters()
  )
  expect_equal(first$state$clubs$rating, changed$state$clubs$rating, tolerance = 0)
  expect_equal(first$state$clubs$prior_match_count,
               changed$state$clubs$prior_match_count)
})

test_that("identical accepted snapshots replay byte-equivalently in isolated R processes", {
  rating_test_require()
  authority <- rating_test_authority()
  input <- tempfile("phase19-rating-input-", fileext = ".rds")
  script <- tempfile("phase19-rating-replay-", fileext = ".R")
  outputs <- tempfile(c("phase19-rating-a-", "phase19-rating-b-"), fileext = ".bin")
  saveRDS(list(
    training = authority$training,
    current = rating_test_matching_current(authority$current),
    parameters = rating_test_parameters()
  ), input, version = 3)
  writeLines(c(
    "args <- commandArgs(trailingOnly = TRUE)",
    "setwd(args[[1L]])",
    "source('tests/testthat/helper_phase19_club_fixture.R')",
    "phase19_test_load()",
    "source('R/club/rating.R')",
    "value <- readRDS(args[[2L]])",
    "result <- phase19_replay_club_ratings(value$training, value$current, value$parameters)",
    "writeBin(serialize(result, NULL, version = 3), args[[3L]])"
  ), script, useBytes = TRUE)
  on.exit(unlink(c(input, script, outputs), force = TRUE), add = TRUE)

  statuses <- vapply(outputs, function(output) {
    process_output <- system2(
      file.path(R.home("bin"), "Rscript"),
      c("--vanilla", shQuote(script), shQuote(phase19_test_root),
        shQuote(input), shQuote(output)),
      stdout = TRUE, stderr = TRUE
    )
    status <- attr(process_output, "status")
    if (is.null(status)) 0L else as.integer(status)
  }, integer(1))
  expect_identical(unname(statuses), c(0L, 0L))
  bytes <- lapply(outputs, function(path) {
    readBin(path, what = "raw", n = file.info(path)$size)
  })
  expect_identical(bytes[[1L]], bytes[[2L]])
})

test_that("current UCL roster graph coverage fails closed on absence or disconnection", {
  rating_test_require()
  authority <- rating_test_authority()
  missing <- phase19_replay_club_ratings(
    authority$training, authority$current, rating_test_parameters()
  )
  expect_identical(missing$status, "blocked")
  expect_identical(missing$reason_code, "current_ucl_identity_incomplete")
  expect_false(missing$promotion_eligible)

  current <- rating_test_matching_current(authority$current)
  connected <- phase19_replay_club_ratings(
    authority$training, current, rating_test_parameters()
  )
  expect_identical(connected$status, "ready")
  expect_identical(connected$component_audit$current_roster_sha256,
                   current$roster_sha256)
  expect_identical(connected$component_audit$training_snapshot_sha256,
                   authority$training$snapshot_sha256)
  expect_match(connected$component_audit$component_audit_sha256,
               "^[0-9a-f]{64}$")
  expect_true(connected$fixture_authority)
  expect_false(connected$promotion_eligible)

  disconnected_training <- rating_test_training_variant(authority$training, function(rows) {
    rows[rows$competition_id != "champions-league", , drop = FALSE]
  })
  disconnected <- phase19_replay_club_ratings(
    disconnected_training, current, rating_test_parameters()
  )
  expect_identical(disconnected$status, "blocked")
  expect_identical(disconnected$reason_code, "current_ucl_identity_incomplete")
})

test_that("postponed rows do not update and inactivity regresses only rating differences", {
  rating_test_require()
  state <- rating_test_state()
  completed <- phase19_forecast_club_rating_batch(state, rating_test_batch())$state
  postponed <- rating_test_batch()
  postponed$status <- "postponed"
  postponed$counts_for_model <- FALSE
  postponed$regulation_home_goals <- NA_integer_
  postponed$regulation_away_goals <- NA_integer_
  postponed$kickoff_utc <- "2027-05-01T18:00:00Z"
  postponed$boundary_id <- "kickoff:2027-05-01T18:00:00Z"
  decayed <- phase19_forecast_club_rating_batch(completed, postponed)$state

  base <- rating_test_parameters()$base_rating
  elapsed <- as.numeric(difftime(
    as.POSIXct("2027-05-01T18:00:00Z", tz = "UTC"),
    as.POSIXct("2025-05-01T18:00:00Z", tz = "UTC"), units = "days"
  ))
  factor <- rating_test_parameters()$inactivity_factor ^ (elapsed / 365)
  expect_equal(decayed$clubs$rating - base,
               (completed$clubs$rating - base) * factor, tolerance = 1e-12)
  expect_identical(decayed$clubs$prior_match_count,
                   completed$clubs$prior_match_count)
})

test_that("rating batches reject unknown status, coercive flags, and forged boundaries", {
  rating_test_require()
  state <- rating_test_state()
  unknown <- rating_test_batch()
  unknown$status <- "mystery"
  expect_error(
    phase19_forecast_club_rating_batch(state, unknown),
    class = "phase19_club_rating_error"
  )
  coercive <- rating_test_batch()
  coercive$counts_for_model <- "TRUE"
  expect_error(
    phase19_forecast_club_rating_batch(state, coercive),
    class = "phase19_club_rating_error"
  )
  forged_boundary <- rating_test_batch()
  forged_boundary$boundary_id <- "kickoff:2025-05-01T19:00:00Z"
  expect_error(
    phase19_forecast_club_rating_batch(state, forged_boundary),
    class = "phase19_club_rating_error"
  )
  completed_missing_goals <- rating_test_batch()
  completed_missing_goals$counts_for_model <- FALSE
  completed_missing_goals$regulation_home_goals <- NA_integer_
  expect_error(
    phase19_forecast_club_rating_batch(state, completed_missing_goals),
    class = "phase19_club_rating_error"
  )
})
