library(testthat)

source(file.path(
  normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
                winslash = "/", mustWork = TRUE),
  "tests/testthat/helper_phase19_club_fixture.R"
))
phase19_test_load()

goal_model_test_load <- function() {
  dependencies <- c(
    "R/evaluation/proper_scores.R",
    "R/club/rating.R",
    "R/club/evaluation_protocol.R"
  )
  for (path in dependencies) {
    source(file.path(phase19_test_root, path), local = .GlobalEnv)
  }
  module <- file.path(phase19_test_root, "R/club/goal_model.R")
  if (!file.exists(module)) stop("RED: missing Phase 19 club goal-model module", call. = FALSE)
  source(module, local = .GlobalEnv)
  phase19_test_require(c(
    "phase19_fit_club_goal_model",
    "phase19_predict_club_goal_model",
    "phase19_validate_club_goal_predictions"
  ))
}

goal_model_test_matching_current <- function(current) {
  club_ids <- c("club_alpha", "club_beta", "club_gamma", "club_delta")
  clubs <- current$clubs[seq_along(club_ids), , drop = FALSE]
  clubs$provider_club_id <- as.character(9000L + seq_along(club_ids))
  clubs$club_id <- club_ids
  clubs$display_name <- paste("Goal", club_ids)
  clubs$canonical_name <- clubs$display_name
  clubs$row_sha256 <- ""
  clubs$row_sha256 <- phase18_ucl_projected_row_hash(clubs)
  clubs <- clubs[order(clubs$club_id, method = "radix"), , drop = FALSE]
  rownames(clubs) <- NULL
  current$clubs <- clubs
  current$club_count <- as.integer(nrow(clubs))
  current$roster_sha256 <- phase18_hash_table_v2(
    clubs, key = "club_id", schema_tag = "phase19-current-ucl-club-roster-v1"
  )
  current$snapshot_sha256 <- phase19_current_snapshot_sha256(current)
  phase19_validate_current_ucl_club_snapshot(current, "fixture")
  current
}

goal_model_test_context <- local({
  value <- NULL
  function() {
    if (is.null(value)) {
      goal_model_test_load()
      root <- phase19_test_fixture_root("goal-model")
      training <- phase19_load_fixture_club_training_snapshot(root)
      current <- goal_model_test_matching_current(
        phase19_load_fixture_current_ucl_club_snapshot(root)
      )
      parameters <- phase19_club_rating_parameters(
        base_rating = 1500, home_advantage = 60,
        k_factor = 20, inactivity_factor = 0.995
      )
      rating <- phase19_replay_club_ratings(
        training, current, parameters, cutoff_utc = training$cutoff_utc
      )
      protocol <- phase19_load_fixture_club_evaluation_protocol()
      value <<- list(
        root = root, training = training, current = current,
        parameters = parameters, rating = rating, protocol = protocol
      )
    }
    value
  }
})

goal_model_test_registration <- function(context, model_id = "club_elo_nb") {
  context$protocol$candidate_registry[
    context$protocol$candidate_registry$model_id == model_id, , drop = FALSE
  ]
}

goal_model_test_fixtures <- function(context) {
  scheduled <- data.frame(
    fixture_id = c("ucl_fixture_b", "ucl_fixture_a"),
    forecast_domain = "club", authority_mode = "fixture",
    boundary_id = "kickoff:2025-06-01T18:00:00Z",
    kickoff_utc = "2025-06-01T18:00:00Z",
    home_club_id = c("club_gamma", "club_alpha"),
    away_club_id = c("club_delta", "club_beta"),
    status = "scheduled", counts_for_model = FALSE,
    regulation_home_goals = NA_integer_, regulation_away_goals = NA_integer_,
    stringsAsFactors = FALSE, check.names = FALSE
  )
  phase19_forecast_club_rating_batch(context$rating$state, scheduled)$predictions
}

goal_model_test_fit <- function(context = goal_model_test_context(),
                                model_id = "club_elo_nb",
                                cutoff_utc = "2025-06-01T18:00:00Z",
                                rating = context$rating) {
  phase19_fit_club_goal_model(
    registration = goal_model_test_registration(context, model_id),
    training_snapshot = context$training,
    rating_evidence = rating,
    protocol = context$protocol,
    cutoff_utc = cutoff_utc
  )
}

test_that("club_elo_nb fits strict prior club evidence and emits a complete G=40 grid", {
  context <- goal_model_test_context()
  fit <- goal_model_test_fit(context)
  fixtures <- goal_model_test_fixtures(context)
  result <- phase19_predict_club_goal_model(
    fit, fixtures,
    declared_fixture_ids = sort(fixtures$fixture_id, method = "radix")
  )

  expect_identical(fit$forecast_domain, "club")
  expect_identical(fit$model_id, "club_elo_nb")
  expect_identical(fit$model_family, "negative_binomial")
  expect_true(fit$converged)
  expect_true(is.finite(fit$theta) && fit$theta > 0)
  expect_identical(fit$fallback_status, "none")
  expect_identical(
    fit$active_features,
    c("elo_difference_for_team", "venue_role")
  )
  expect_true(fit$fit_row_count > 0L)
  expect_true(fit$max_completion_not_before_utc < fit$cutoff_utc)
  expect_true(fit$max_evidence_available_at_utc < fit$cutoff_utc)
  expect_match(fit$fit_sha256, "^[0-9a-f]{64}$")

  expect_identical(result$predictions$fixture_id,
                   sort(fixtures$fixture_id, method = "radix"))
  expect_equal(nrow(result$distributions), 2L * 1681L)
  expect_equal(as.integer(table(result$distributions$fixture_id)), c(1681L, 1681L))
  expect_equal(
    vapply(split(result$distributions$probability,
                 result$distributions$fixture_id), sum, numeric(1)),
    c(ucl_fixture_a = 1, ucl_fixture_b = 1),
    tolerance = 1e-12
  )
  expect_true(all(is.finite(result$predictions$expected_home_goals)))
  expect_true(all(is.finite(result$predictions$expected_away_goals)))
  expect_silent(phase19_validate_club_goal_predictions(
    result, declared_fixture_ids = c("ucl_fixture_a", "ucl_fixture_b"),
    require_goal_grid = TRUE
  ))

  for (fixture_id in result$predictions$fixture_id) {
    row <- result$predictions[result$predictions$fixture_id == fixture_id, , drop = FALSE]
    grid <- result$distributions[
      result$distributions$fixture_id == fixture_id, , drop = FALSE
    ]
    expect_equal(row$p_home,
                 sum(grid$probability[grid$home_goals > grid$away_goals]),
                 tolerance = 1e-12)
    expect_equal(row$p_draw,
                 sum(grid$probability[grid$home_goals == grid$away_goals]),
                 tolerance = 1e-12)
    expect_equal(row$p_away,
                 sum(grid$probability[grid$home_goals < grid$away_goals]),
                 tolerance = 1e-12)
    markets <- derive_binary_markets(grid)
    expect_equal(row$p_over_2_5, markets$p_over_2_5, tolerance = 1e-12)
    expect_equal(row$p_btts, markets$p_btts, tolerance = 1e-12)
    modal <- grid[which.max(grid$probability), , drop = FALSE]
    expect_identical(row$likely_home_goals, as.integer(modal$home_goals))
    expect_identical(row$likely_away_goals, as.integer(modal$away_goals))
  }
})

test_that("club goal fitting excludes equal-cutoff and same-batch results", {
  context <- goal_model_test_context()
  evidence_times <- sort(unique(context$training$matches$evidence_available_at_utc))
  cutoff <- evidence_times[[length(evidence_times)]]
  fit <- goal_model_test_fit(context, cutoff_utc = cutoff)

  expect_identical(fit$cutoff_utc, cutoff)
  expect_equal(fit$fit_row_count, 5L)
  expect_true(fit$max_completion_not_before_utc < cutoff)
  expect_true(fit$max_evidence_available_at_utc < cutoff)

  contemporaneous <- context$rating
  contemporaneous$predictions$rating_difference[
    contemporaneous$predictions$fixture_id ==
      context$training$matches$match_id[[nrow(context$training$matches)]]
  ] <- 1e9
  refit <- goal_model_test_fit(context, cutoff_utc = cutoff,
                               rating = contemporaneous)
  expect_identical(fit$fit_sha256, refit$fit_sha256)
})

test_that("club goal fit and predictions are canonical under evidence and fixture reorder", {
  context <- goal_model_test_context()
  reordered_rating <- context$rating
  reordered_rating$predictions <- reordered_rating$predictions[
    rev(seq_len(nrow(reordered_rating$predictions))), , drop = FALSE
  ]
  first_fit <- goal_model_test_fit(context)
  second_fit <- goal_model_test_fit(context, rating = reordered_rating)
  expect_identical(first_fit$fit_sha256, second_fit$fit_sha256)

  fixtures <- goal_model_test_fixtures(context)
  first <- phase19_predict_club_goal_model(
    first_fit, fixtures,
    declared_fixture_ids = sort(fixtures$fixture_id, method = "radix")
  )
  second <- phase19_predict_club_goal_model(
    second_fit, fixtures[2:1, , drop = FALSE],
    declared_fixture_ids = sort(fixtures$fixture_id, method = "radix")
  )
  expect_identical(first$prediction_table_sha256,
                   second$prediction_table_sha256)
  expect_identical(first$distribution_table_sha256,
                   second$distribution_table_sha256)
  expect_identical(first$predictions, second$predictions)
  expect_identical(first$distributions, second$distributions)
})

test_that("club goal authority rejects domain, rating, feature, and grid attacks", {
  context <- goal_model_test_context()
  registration <- goal_model_test_registration(context)

  national <- registration
  national$forecast_domain <- "national_team"
  expect_error(
    phase19_fit_club_goal_model(
      national, context$training, context$rating, context$protocol,
      "2025-06-01T18:00:00Z"
    ),
    class = "phase19_club_goal_model_error"
  )
  missing_rating <- context$rating
  missing_rating$predictions$rating_difference[[1L]] <- NA_real_
  expect_error(goal_model_test_fit(context, rating = missing_rating),
               class = "phase19_club_goal_model_error")

  fit <- goal_model_test_fit(context)
  fixtures <- goal_model_test_fixtures(context)
  result <- phase19_predict_club_goal_model(
    fit, fixtures,
    declared_fixture_ids = sort(fixtures$fixture_id, method = "radix")
  )
  incomplete <- result
  incomplete$distributions <- incomplete$distributions[-1L, , drop = FALSE]
  expect_error(
    phase19_validate_club_goal_predictions(
      incomplete, c("ucl_fixture_a", "ucl_fixture_b"), TRUE
    ),
    class = "phase19_club_goal_model_error"
  )
  invalid_mass <- result
  invalid_mass$distributions$probability[[1L]] <- 2
  expect_error(
    phase19_validate_club_goal_predictions(
      invalid_mass, c("ucl_fixture_a", "ucl_fixture_b"), TRUE
    ),
    class = "phase19_club_goal_model_error"
  )
})

test_that("all four frozen club roles dispatch with truthful capabilities", {
  context <- goal_model_test_context()
  fixtures <- goal_model_test_fixtures(context)
  declared <- sort(fixtures$fixture_id, method = "radix")
  expected <- list(
    uniform_1x2 = list(goal = FALSE, comparable = FALSE, cells = 0L,
                       status = "ready_report_only"),
    expanding_1x2 = list(goal = TRUE, comparable = FALSE, cells = 3362L,
                         status = "ready_goal_distribution"),
    club_venue_nb = list(goal = TRUE, comparable = TRUE, cells = 3362L,
                         status = "ready_goal_distribution"),
    club_elo_nb = list(goal = TRUE, comparable = TRUE, cells = 3362L,
                       status = "ready_goal_distribution")
  )
  prediction_schemas <- list()

  for (model_id in names(expected)) {
    dispatched <- phase19_dispatch_club_goal_model(
      goal_model_test_registration(context, model_id),
      context$training, context$rating, context$protocol,
      "2025-06-01T18:00:00Z", fixtures, declared
    )
    fit <- dispatched$fit
    prediction <- dispatched$prediction
    contract <- expected[[model_id]]

    expect_identical(fit$model_id, model_id)
    expect_identical(fit$goal_distribution_declared, contract$goal)
    expect_identical(fit$promotion_comparable, contract$comparable)
    expect_identical(prediction$promotion_comparable, contract$comparable)
    expect_equal(nrow(prediction$distributions), contract$cells)
    expect_true(all(prediction$predictions$prediction_status == contract$status))
    expect_true(all(prediction$predictions$fallback_status == "none"))
    prediction_schemas[[model_id]] <- names(prediction$predictions)
  }

  expect_identical(prediction_schemas$club_venue_nb,
                   prediction_schemas$club_elo_nb)
  expect_identical(
    phase19_club_goal_comparable_ids(context$protocol),
    c("club_venue_nb", "club_elo_nb")
  )
})

test_that("fixture inventory is exact and surplus or duplicate coverage cannot score", {
  context <- goal_model_test_context()
  fit <- goal_model_test_fit(context)
  fixtures <- goal_model_test_fixtures(context)

  expect_error(
    phase19_predict_club_goal_model(
      fit, fixtures[1L, , drop = FALSE],
      declared_fixture_ids = c("ucl_fixture_a", "ucl_fixture_b")
    ),
    class = "phase19_club_goal_model_error"
  )
  expect_error(
    phase19_predict_club_goal_model(
      fit, rbind(fixtures, fixtures[1L, , drop = FALSE]),
      declared_fixture_ids = c("ucl_fixture_a", "ucl_fixture_b")
    ),
    class = "phase19_club_goal_model_error"
  )
  expect_error(
    phase19_predict_club_goal_model(
      fit, fixtures,
      declared_fixture_ids = c("ucl_fixture_a")
    ),
    class = "phase19_club_goal_model_error"
  )
  expect_error(
    phase19_predict_club_goal_model(
      fit, fixtures,
      declared_fixture_ids = c("ucl_fixture_b", "ucl_fixture_a")
    ),
    class = "phase19_club_goal_model_error"
  )
})

test_that("unavailable enrichment values and candidate formula drift fail before fit", {
  context <- goal_model_test_context()
  enriched_rating <- context$rating
  enriched_rating$predictions$current_xg <- 0
  expect_error(
    goal_model_test_fit(context, rating = enriched_rating),
    class = "phase19_club_goal_model_error"
  )

  fit <- goal_model_test_fit(context)
  enriched_fixture <- goal_model_test_fixtures(context)
  enriched_fixture$injury <- 0
  expect_error(
    phase19_predict_club_goal_model(
      fit, enriched_fixture,
      declared_fixture_ids = sort(enriched_fixture$fixture_id, method = "radix")
    ),
    class = "phase19_club_goal_model_error"
  )

  drifted <- goal_model_test_registration(context)
  drifted$formula <- "goals ~ elo_difference_for_team + venue_role + current_xg"
  drifted$row_sha256 <- phase19_candidate_row_sha256(drifted)
  expect_error(
    phase19_fit_club_goal_model(
      drifted, context$training, context$rating, context$protocol,
      "2025-06-01T18:00:00Z"
    ),
    class = "phase19_club_goal_model_error"
  )
})

test_that("invalid NB theta or mean fails without family or control fallback", {
  context <- goal_model_test_context()
  fit <- goal_model_test_fit(context)
  fixtures <- goal_model_test_fixtures(context)
  declared <- sort(fixtures$fixture_id, method = "radix")

  invalid_theta <- fit
  invalid_theta$theta <- -1
  invalid_theta$theta_text <- "-1"
  invalid_theta$fit_sha256 <- phase19_club_goal_fit_hash(invalid_theta)
  expect_error(
    phase19_predict_club_goal_model(invalid_theta, fixtures, declared),
    class = "phase19_club_goal_model_error"
  )
  expect_identical(invalid_theta$model_id, "club_elo_nb")
  expect_identical(invalid_theta$model_family, "negative_binomial")
  expect_identical(invalid_theta$fallback_status, "none")

  invalid_model <- fit
  invalid_model$model$coefficients[[1L]] <- Inf
  invalid_model$fit_sha256 <- phase19_club_goal_fit_hash(invalid_model)
  expect_error(
    phase19_predict_club_goal_model(invalid_model, fixtures, declared),
    class = "phase19_club_goal_model_error"
  )
  expect_identical(invalid_model$fallback_status, "none")
})
