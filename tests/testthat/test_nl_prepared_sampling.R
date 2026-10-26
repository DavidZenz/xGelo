library(testthat)

nl_sampling_test_module <- local({
  module <- new.env(parent = .GlobalEnv)
  for (path in c("source_contracts", "publication_hashes", "forecast_layer", "form", "state_bundle", "standings",
                 "uefa_nations_league_rules", "uefa_nations_league_simulation", "uefa_nations_league_canonical")) {
    sys.source(paste0("../../R/competition/", path, ".R"), envir = module)
  }
  fixture <- new.env(parent = module)
  for (expression in parse("test_phase15_nations_league.R")) {
    if (is.call(expression) && identical(expression[[1L]], as.name("<-"))) eval(expression, envir = fixture)
  }
  list(module = module, fixture = fixture)
})

nl_sampling_test_inputs <- function(unavailable = FALSE) {
  module <- nl_sampling_test_module$module
  inputs <- nl_sampling_test_module$fixture$phase15_test_simulation_inputs(1L, 7L)
  matches <- module$uefa_nl_sim_normalize_matches(inputs$canonical_matches, inputs$completed_results,
    inputs$rules, inputs$source_bundle_id)
  forecasts <- module$uefa_nl_sim_normalize_forecasts(inputs$forecasts, inputs$rules)
  status <- module$uefa_nl_sim_normalize_status(inputs$forecast_status, inputs$rules)
  if (unavailable) {
    status$forecast_status[[1L]] <- "unavailable"
    status$suppression_reason[[1L]] <- "unavailable-test"
  }
  scores <- module$uefa_nl_sim_normalize_score_distributions(inputs$score_distributions)
  cutoff <- module$uefa_nl_sim_cutoff(matches)
  runtime <- module$uefa_nl_sim_prepare_runtime(matches, forecasts, status, scores, cutoff, "test-run", "test-policy")
  list(matches = matches, forecasts = forecasts, status = status, scores = scores,
    rules = inputs$rules, cutoff = cutoff, runtime = runtime)
}

test_that("prepared sampled columns preserve complete stage rows and caller RNG", {
  module <- nl_sampling_test_module$module
  inputs <- nl_sampling_test_inputs()
  indexes <- head(which(inputs$forecasts$forecast_status == "available"), 3L)
  expect_gt(length(indexes), 0L)
  for (index in indexes) {
    forecast <- inputs$forecasts[index, , drop = FALSE]
    grid <- module$uefa_nl_sim_fixture_grid(inputs$scores, forecast)
    for (seed in c(0L, 7L, 31L)) {
      args <- list(forecast = forecast, score_distribution = grid, seed = seed,
        stage_id = "league_a_quarter_finals", stage_status = "projected",
        projection_run_id = "distinct-run", draw_policy_id = "distinct-policy")
      set.seed(1701L); before <- .Random.seed
      actual <- do.call(inputs$runtime$uefa_nl_sample_stage_match, args)
      expect_identical(actual, do.call(module$uefa_nl_sample_stage_match, args))
      expect_identical(.Random.seed, before)
    }
  }
})

test_that("prepared league columns retain suppression, iteration identities and full schemas", {
  module <- nl_sampling_test_module$module
  for (unavailable in c(FALSE, TRUE)) {
    inputs <- nl_sampling_test_inputs(unavailable)
    for (seed in c(7L, 31L)) for (iteration in c(1L, 3L)) {
      args <- list(matches = inputs$matches, forecast_status = inputs$status, forecasts = inputs$forecasts,
        score_distributions = inputs$scores, rules = inputs$rules, seed = seed,
        projection_run_id = "test-run", draw_policy_id = "test-policy", cutoff_utc = inputs$cutoff,
        iteration = iteration)
      set.seed(1701L); before <- .Random.seed
      expect_identical(do.call(inputs$runtime$uefa_nl_sim_sample_league_matches, args),
        do.call(module$uefa_nl_sim_sample_league_matches, args))
      expect_identical(.Random.seed, before)
    }
  }
})

test_that("prepared forecast row assembly preserves leg and participant fields", {
  module <- nl_sampling_test_module$module
  for (unavailable in c(FALSE, TRUE)) {
    inputs <- nl_sampling_test_inputs(unavailable)
    forecast <- inputs$forecasts[1L, , drop = FALSE]
    args <- list(forecasts = inputs$forecasts, status = inputs$status,
      score_distributions = inputs$scores, stage_id = forecast$stage_id[[1L]],
      home_team_id = forecast$home_team_id[[1L]], away_team_id = forecast$away_team_id[[1L]],
      fixture_id = forecast$fixture_id[[1L]], seed = 31L,
      projection_run_id = "test-run", draw_policy_id = "test-policy")
    for (leg in c(1L, 2L)) {
      args$leg_number <- leg
      set.seed(1701L); before <- .Random.seed
      actual <- do.call(inputs$runtime$uefa_nl_sim_forecast_match_row, args)
      expect_identical(actual, do.call(module$uefa_nl_sim_forecast_match_row, args))
      expect_identical(.Random.seed, before)
    }
    args$participant_slot_home <- "missing-home-slot"
    args$participant_slot_away <- "missing-away-slot"
    expect_identical(do.call(inputs$runtime$uefa_nl_sim_forecast_match_row, args),
      do.call(module$uefa_nl_sim_forecast_match_row, args))
  }
})
