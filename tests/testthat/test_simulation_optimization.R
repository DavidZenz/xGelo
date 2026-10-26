library(testthat)

optimization_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))
source(file.path(optimization_root, "R/common/simulation_execution.R"))
source(file.path(optimization_root, "R/competition/uefa_nations_league_rules.R"))
source(file.path(optimization_root, "R/competition/uefa_nations_league_simulation.R"))

optimization_nl_inputs <- function() {
  # Reuse declared mechanics fixtures without running the other test file.
  env <- new.env(parent = .GlobalEnv)
  for (expression in parse(file.path(optimization_root, "tests/testthat/test_phase15_nations_league.R"))) {
    if (is.call(expression) && identical(expression[[1L]], as.name("<-"))) eval(expression, envir = env)
  }
  env$phase15_test_simulation_inputs(simulation_count = 3L)
}

test_that("persistent execution preserves order, RNG and measured progress", {
  set.seed(25L); saved <- .Random.seed
  events <- list()
  callback <- function(event) events[[length(events) + 1L]] <<- event
  serial <- simulation_execute(17L, function(i) i * 3L, batch_size = 3L, progress = callback)
  parallel <- simulation_execute(17L, function(i) i * 3L, workers = 4L, batch_size = 2L)
  expect_identical(serial, parallel)
  expect_identical(saved, .Random.seed)
  counts <- vapply(events, `[[`, integer(1), "completed")
  expect_identical(counts[[1L]], 0L)
  expect_identical(counts[[length(counts)]], 17L)
  expect_true(all(diff(counts) > 0))
  expect_error(simulation_execute(2, identity, workers = 1.5), "positive integer")
  expect_error(simulation_execute(2, identity, batch_size = 0), "positive integer")
  expect_error(simulation_execute(2, identity, progress = NA), "progress")
  expect_error(simulation_execute(4, function(i) stop("deliberate failure"), workers = 2), "failed.*deliberate failure")
})

test_that("prepared NL numeric standings preserve the complete reference ranking", {
  inputs <- optimization_nl_inputs()
  rules <- inputs$rules
  matches <- uefa_nl_sim_normalize_matches(inputs$canonical_matches, NULL, rules, inputs$source_bundle_id)
  groups <- uefa_nl_sim_normalize_groups(inputs$groups, matches, rules)
  forecasts <- uefa_nl_sim_normalize_forecasts(inputs$forecasts, rules)
  status <- uefa_nl_sim_normalize_status(inputs$forecast_status, rules)
  scores <- uefa_nl_sim_normalize_score_distributions(inputs$score_distributions)
  cutoff <- uefa_nl_sim_cutoff(matches)
  runtime <- uefa_nl_sim_prepare_runtime(matches, forecasts, status, scores, cutoff, "probe", "draw")
  runtime <- uefa_nl_sim_prepare_group_reducer(runtime, matches, groups, rules, inputs$source_bundle_id, cutoff)
  for (seed in c(1L, 7L, 31L)) {
    old <- uefa_nl_sim_sample_league_matches(matches, status, forecasts, scores, rules, seed, "probe", "draw", cutoff)
    new <- runtime$uefa_nl_sim_sample_league_matches(matches, status, forecasts, scores, rules, seed, "probe", "draw", cutoff)
    expect_identical(new, old)
    reference <- uefa_nl_sim_build_league_state(old$matches, groups, rules, inputs$source_bundle_id, cutoff)
    prepared <- runtime$uefa_nl_sim_build_league_state(new$matches, groups, rules, inputs$source_bundle_id, cutoff)
    for (field in names(prepared)) expect_identical(prepared[[field]], reference[[field]], info = field)
  }
  missing_groups <- groups
  missing_groups$discipline_points[[1L]] <- NA_integer_
  runtime <- uefa_nl_sim_prepare_group_reducer(runtime, matches, missing_groups, rules, inputs$source_bundle_id, cutoff)
  reference <- uefa_nl_sim_build_league_state(old$matches, missing_groups, rules, inputs$source_bundle_id, cutoff)
  prepared <- runtime$uefa_nl_sim_build_league_state(new$matches, missing_groups, rules, inputs$source_bundle_id, cutoff)
  for (field in names(prepared)) expect_identical(prepared[[field]], reference[[field]], info = paste("missing discipline", field))
  late <- matches
  late$evidence_completed_at_utc[[2L]] <- "2099-12-31T23:59:59Z"
  runtime <- uefa_nl_sim_prepare_runtime(late, forecasts, status, scores, cutoff, "probe", "draw")
  sampled <- runtime$uefa_nl_sim_sample_league_matches(late, status, forecasts, scores, rules, 7L, "probe", "draw", cutoff)
  expect_identical(sampled, uefa_nl_sim_sample_league_matches(late, status, forecasts, scores, rules, 7L, "probe", "draw", cutoff))
  expect_false(sampled$matches$counts_for_standings[[2L]])
})

test_that("NL complete outputs are scheduling invariant and retain suppressed data", {
  inputs <- optimization_nl_inputs()
  serial <- do.call(uefa_nl_run_simulation, c(inputs, list(workers = 1L, batch_size = 1L)))
  parallel <- do.call(uefa_nl_run_simulation, c(inputs, list(workers = 4L, batch_size = 2L)))
  expect_identical(serial, parallel)
  inputs$forecast_status$forecast_status <- "unavailable"
  inputs$forecast_status$suppression_reason <- "test-unavailable"
  suppressed <- do.call(uefa_nl_run_simulation, c(inputs, list(workers = 2L)))
  expect_true(any(suppressed$fixture_forecast_form$forecast_status == "unavailable"))
  expect_true(anyNA(suppressed$fixture_forecast_form$p_home))
  inputs$forecast_status$forecast_status <- "available"
  inputs$score_distributions$probability[[1L]] <- -1
  expect_error(do.call(uefa_nl_run_simulation, inputs), "non-negative|normalized")
})

test_that("CL prepared sampling preserves reference rows and worker equality", {
  source(file.path(optimization_root, "tests/testthat/helper_uefa_champions_league.R"), local = TRUE)
  for (name in c("rules", "state", "simulation")) source(file.path(optimization_root,
    paste0("R/competition/uefa_champions_league_", name, ".R")), local = TRUE)
  for (expression in parse(file.path(optimization_root, "tests/testthat/test_phase20_simulation_review.R"))) {
    if (is.call(expression) && identical(expression[[1L]], as.name("<-")) &&
        identical(expression[[2L]], as.name("phase20_sim_review_ledger"))) eval(expression)
  }
  graph <- phase20_fixture_graph_36x144()
  ledger <- phase20_sim_review_ledger(graph)
  cutoff <- "2026-09-01T00:00:00Z"
  sampler <- .ucl_sim_prepare_sampler(graph, ledger$ledger, cutoff)
  ranker <- .ucl_sim_prepare_ranker(graph, .ucl_rule_contract(), cutoff)
  for (i in 1:3) {
    sampled <- sampler(i, 7L)
    expect_identical(sampled, .ucl_sim_iteration_graph(graph, ledger$ledger, seed = 7L, cutoff_utc = cutoff, iteration = i))
    ranked <- ranker(sampled)
    expect_identical(sum(ranked$played), 288L)
    expect_equal(sum(ranked$goals_for), sum(sampled$fixtures$final_home_goals + sampled$fixtures$final_away_goals))
    expect_equal(sum(ranked$points), 3 * sum(sampled$fixtures$final_home_goals != sampled$fixtures$final_away_goals) +
      2 * sum(sampled$fixtures$final_home_goals == sampled$fixtures$final_away_goals))
  }
  state <- ucl_build_state(graph, state_cutoff_utc = cutoff)
  args <- list(state = state, ledger = ledger, simulations = 4L, seed = 7L, information_cutoff_utc = cutoff)
  expect_identical(do.call(ucl_run_simulation, c(args, list(workers = 1L))),
    do.call(ucl_run_simulation, c(args, list(workers = 4L, batch_size = 1L))))
})


test_that("CL projections count samples without admitting future actual evidence", {
  source(file.path(optimization_root, "tests/testthat/helper_uefa_champions_league.R"), local = TRUE)
  for (name in c("rules", "state", "simulation")) source(file.path(optimization_root,
    paste0("R/competition/uefa_champions_league_", name, ".R")), local = TRUE)
  for (expression in parse(file.path(optimization_root, "tests/testthat/test_phase20_simulation_review.R"))) {
    if (is.call(expression) && identical(expression[[1L]], as.name("<-")) &&
        identical(expression[[2L]], as.name("phase20_sim_review_ledger"))) eval(expression)
  }
  graph <- phase20_fixture_graph_36x144(); original <- graph
  cutoff <- "2026-09-01T00:00:00Z"
  ledger <- phase20_sim_review_ledger(graph)
  sampler <- .ucl_sim_prepare_sampler(graph, ledger$ledger, cutoff)
  ranker <- .ucl_sim_prepare_ranker(graph, .ucl_rule_contract(), cutoff)
  a <- sampler(1L, 7L); b <- a
  b$fixtures$final_home_goals[] <- 20L; b$fixtures$final_away_goals[] <- 0L
  expect_false(identical(ranker(a)$goals_for, ranker(b)$goals_for))
  expect_identical(graph, original)
  expect_true(all(attr(a, "ucl_sampling")$sampled_fixture_ids %in% graph$fixtures$fixture_id))
  graph$fixtures$match_status[1L] <- "completed"
  graph$fixtures$final_home_goals[1L] <- 99L; graph$fixtures$final_away_goals[1L] <- 0L
  future <- .ucl_sim_prepare_ranker(graph, .ucl_rule_contract(), cutoff)(graph)
  expect_identical(sum(future$played), 0L)
  expect_identical(sum(future$goals_for), 0L)
})
