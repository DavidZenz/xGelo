library(testthat)

nl_paths_test_module <- local({
  module <- new.env(parent = .GlobalEnv)
  for (path in c("source_contracts", "publication_hashes", "forecast_layer", "form", "state_bundle", "standings",
                 "uefa_nations_league_rules", "uefa_nations_league_simulation", "uefa_nations_league_numeric", "uefa_nations_league_paths")) {
    sys.source(paste0("../../R/competition/", path, ".R"), envir = module)
  }
  fixture <- new.env(parent = module)
  for (expression in parse("test_phase15_nations_league.R")) if (is.call(expression) && identical(expression[[1L]], as.name("<-"))) eval(expression, envir = fixture)
  list(module = module, fixture = fixture)
})

nl_paths_test_runtime <- function(rules = nl_paths_test_module$module$uefa_nl_2026_27_rules(), slots = data.frame()) {
  module <- nl_paths_test_module$module
  runtime <- new.env(parent = module)
  for (name in ls(envir = module, pattern = "^uefa_nl_")) {
    value <- get(name, envir = module)
    if (is.function(value)) { environment(value) <- runtime; assign(name, value, envir = runtime) }
  }
  module$uefa_nl_sim_prepare_paths(runtime, rules, slots)
}

nl_paths_test_inputs <- function() {
  teams <- letters[1:8]
  groups <- data.frame(team_id = teams, stringsAsFactors = FALSE)
  interim <- data.frame(team_id = teams, league = "A", interim_rank = 1:8, ordering_status = "ready", stringsAsFactors = FALSE)
  pairs <- data.frame(tie_id = paste0("tie", 1:4), team_a = teams[c(1L, 3L, 5L, 7L)], team_b = teams[c(2L, 4L, 6L, 8L)], stringsAsFactors = FALSE)
  results <- data.frame(tie_id = pairs$tie_id, stage_status = "completed", winner_team_id = pairs$team_a, loser_team_id = pairs$team_b, stringsAsFactors = FALSE)
  semi <- pairs[1:2, ]; semi$team_a <- c("a", "e"); semi$team_b <- c("c", "g")
  semi_results <- results[1:2, ]; semi_results$winner_team_id <- semi$team_a; semi_results$loser_team_id <- semi$team_b
  final <- data.frame(stage_status = "completed", winner_team_id = "a", loser_team_id = "e", stringsAsFactors = FALSE)
  third <- data.frame(stage_status = "completed", winner_team_id = "c", loser_team_id = "g", stringsAsFactors = FALSE)
  list(groups = groups, interim = interim, transitions = data.frame(), qf_pairs = pairs, qf_resolutions = results,
       semi_pairs = semi, semi_resolutions = semi_results, final_resolution = final, third_resolution = third, iteration = 17L)
}

test_that("indexed team paths preserve participation, duplicate and unknown-result semantics", {
  runtime <- nl_paths_test_runtime()
  reference <- nl_paths_test_module$module$uefa_nl_sim_iteration_paths
  base <- nl_paths_test_inputs()
  compare <- function(args) { actual <- do.call(runtime$uefa_nl_sim_iteration_paths, args); expect_identical(actual, do.call(reference, args)); actual }
  compare(base)
  for (kind in c("absent_pairs", "absent_results", "duplicate", "unknown", "suppressed", "NA_status", "unknown_participants", "nonparticipant", "overlap", "final_missing", "final_unresolved", "third_missing", "third_unresolved")) {
    args <- base
    if (kind == "absent_pairs") args$qf_pairs <- data.frame()
    if (kind == "absent_results") args$qf_resolutions <- data.frame()
    if (kind == "duplicate") args$qf_resolutions <- rbind(args$qf_resolutions, args$qf_resolutions[1L, ])
    if (kind == "unknown") args$qf_resolutions$stage_status[[1L]] <- "unresolved"
    if (kind == "suppressed") args$qf_resolutions$stage_status[[1L]] <- "suppressed"
    if (kind == "NA_status") args$qf_resolutions$stage_status[[1L]] <- NA_character_
    if (kind == "unknown_participants") args$qf_pairs$team_a <- args$qf_pairs$team_b <- NA_character_
    if (kind == "nonparticipant") args$qf_pairs <- args$qf_pairs[1:2, ]
    if (kind == "overlap") { args$qf_pairs <- rbind(args$qf_pairs, args$qf_pairs[1L, ]); args$qf_pairs$tie_id[[5L]] <- "bad" }
    if (kind == "final_missing") args$final_resolution <- data.frame()
    if (kind == "final_unresolved") args$final_resolution$stage_status <- "unresolved"
    if (kind == "third_missing") args$third_resolution <- data.frame()
    if (kind == "third_unresolved") args$third_resolution$stage_status <- "unresolved"
    actual <- compare(args)
    if (kind == "overlap") expect_true(all(is.na(actual$p_semi_final[actual$team_id %in% c("a", "b")])))
  }
})

test_that("transition precedence and C/D suppression retain exact team-path values", {
  runtime <- nl_paths_test_runtime(); reference <- nl_paths_test_module$module$uefa_nl_sim_iteration_paths
  args <- nl_paths_test_inputs()
  transitions <- data.frame(team_id = c("a", "a", "b", "c", "d", "e", "f", "g", "h"),
    transition_type = c("direct_promotion", rep("playoff", 8L)),
    stage_id = c("direct_transition", rep("a_b_playoff", 3L), rep("c_d_playoff", 5L)),
    stage_status = c("projected", "unresolved", "completed", "unresolved", "completed", "completed", "unresolved", "completed", "completed"),
    outcome_type = c("direct_promotion", "unresolved", "playoff_win", "unresolved", "playoff_loss", "playoff_win", "unresolved", NA, "playoff_loss"),
    cd_playoff_status = c(rep("not_required", 4L), "cancelled", rep("not_required", 4L)),
    eligibility_status = c(rep("not_applicable", 5L), "unresolved_external_eligibility", rep("not_applicable", 3L)),
    higher_league_team_id = c(NA, "x", "x", "c", "d", "x", "f", "x", "h"),
    lower_league_team_id = c("a", "a", "b", "x", "x", "e", "x", "g", NA), stringsAsFactors = FALSE)
  args$transitions <- transitions
  actual <- do.call(runtime$uefa_nl_sim_iteration_paths, args)
  expect_identical(actual, do.call(reference, args))
  expect_identical(actual$p_promotion[[1L]], 1)
  expect_identical(actual$status[actual$team_id == "d"], "suppressed")
  expect_identical(actual$suppression_reason[actual$team_id == "d"], "c_d_playoff_cancelled")
  expect_identical(actual$status[actual$team_id == "e"], "unresolved")
  transitions$stage_status[[1L]] <- "unresolved"; args$transitions <- transitions
  expect_identical(do.call(runtime$uefa_nl_sim_iteration_paths, args), do.call(reference, args))
})

test_that("vector slots, official lookup and QF traversal preserve full rows and hashes", {
  module <- nl_paths_test_module$module; rules <- module$uefa_nl_2026_27_rules()
  pairs <- data.frame(tie_id = c("x", "y", "z"), pair_index = 1:3, legs = c(2L, 1L, 2L),
    team_a = c("a", "c", NA), team_b = c("b", "d", NA), slot_a = c("sa", "sc", "se"), slot_b = c("sb", "sd", "sf"),
    group_a = NA_character_, group_b = NA_character_, stringsAsFactors = FALSE)
  runtime <- nl_paths_test_runtime()
  for (policy in c("projected", "unresolved", "suppressed")) expect_identical(
    runtime$uefa_nl_sim_stage_slots("a_b_playoff", "play_off", pairs, rules, "run", "policy", policy),
    module$uefa_nl_sim_stage_slots("a_b_playoff", "play_off", pairs, rules, "run", "policy", policy))
  winners <- data.frame(team_id = paste0("w", 1:4), group_id = paste0("A", 1:4), stringsAsFactors = FALSE)
  runners <- data.frame(team_id = paste0("r", 1:4), group_id = paste0("A", 1:4), stringsAsFactors = FALSE)
  for (seed in list(NULL, 7L, 31L, 15017L)) expect_identical(
    runtime$uefa_nl_draw_quarter_finals(winners, runners, seed, "run", rules),
    module$uefa_nl_draw_quarter_finals(winners, runners, seed, "run", rules))
  official <- module$uefa_nl_sim_stage_slots("a_b_playoff", "play_off", pairs[c(1L, 3L), ], rules, "run", "policy")
  official$tie_id <- rep(c("x", "z"), each = 2L)
  official <- official[c(4L, 1L, 3L, 2L), ]
  runtime <- nl_paths_test_runtime(slots = official)
  expect_identical(runtime$uefa_nl_sim_pairings_from_slots(official, "a_b_playoff", rules), module$uefa_nl_sim_pairings_from_slots(official, "a_b_playoff", rules))
  for (tie in c("x", "z", "absent")) expect_identical(runtime$uefa_nl_sim_stage_match_rows_from_official(official, "a_b_playoff", tie), module$uefa_nl_sim_stage_match_rows_from_official(official, "a_b_playoff", tie))
  expect_identical(runtime$uefa_nl_sim_projection_ids("run", "policy", 7L), module$uefa_nl_sim_projection_ids("run", "policy", 31L))
  for (seed in list(NULL, 7L, 31L)) expect_identical(runtime$uefa_nl_sim_projection_ids(NULL, "policy", seed), module$uefa_nl_sim_projection_ids(NULL, "policy", seed))
})

test_that("numeric resolution preserves aggregate, ET, penalties, aliases and RNG", {
  runtime <- nl_paths_test_runtime(); module <- nl_paths_test_module$module
  pair <- nl_paths_test_module$fixture$phase15_test_two_leg_pair()$valid
  pair$regulation_home_goals <- c(1L, 2L); pair$regulation_away_goals <- c(0L, 0L)
  pair$extra_time_home_goals <- pair$extra_time_away_goals <- 0L
  for (kind in c("aggregate", "extra_time", "penalties", "missing", "reversed", "character_scores")) {
    candidate <- pair
    if (kind %in% c("extra_time", "penalties")) candidate$regulation_home_goals <- c(1L, 1L)
    if (kind == "extra_time") candidate$extra_time_home_goals[[2L]] <- 1L
    if (kind == "missing") candidate$regulation_home_goals[[1L]] <- NA_integer_
    if (kind == "reversed") candidate <- candidate[2:1, ]
    if (kind == "character_scores") candidate$regulation_home_goals <- as.character(candidate$regulation_home_goals)
    set.seed(712L); before <- .Random.seed
    expect_identical(runtime$uefa_nl_resolve_two_leg_tie(candidate, seed = 31L), module$uefa_nl_resolve_two_leg_tie(candidate, seed = 31L))
    expect_identical(.Random.seed, before)
  }
  single <- pair[1L, ]; single$regulation_home_goals <- 3L; single$regulation_away_goals <- 1L
  for (mode in c("final", "direct_penalty")) for (kind in c("regulation", "extra_time", "penalties")) {
    candidate <- single
    if (kind != "regulation") candidate$regulation_home_goals <- candidate$regulation_away_goals <- 1L
    if (kind == "extra_time") candidate$extra_time_home_goals <- 1L
    expect_identical(runtime$uefa_nl_resolve_single_leg(candidate, mode, seed = 7L), module$uefa_nl_resolve_single_leg(candidate, mode, seed = 7L))
  }
  for (candidate in list(single, transform(single, regulation_home_goals = NaN), single[, setdiff(names(single), "regulation_home_goals")])) expect_identical(runtime$uefa_nl_sim_leg_scores(candidate), module$uefa_nl_sim_leg_scores(candidate))
  invalid <- single; invalid$regulation_home_goals <- -1L
  expect_error(runtime$uefa_nl_sim_leg_scores(invalid), "score is invalid")
  invalid <- pair; invalid$home_team_id <- rev(pair$home_team_id)
  expect_error(runtime$uefa_nl_resolve_two_leg_tie(invalid), "invalid same-side")
})

test_that("full private mechanics iterations remain identical for multiple seeds and unknowns", {
  module <- nl_paths_test_module$module
  for (seed in c(7L, 31L, 99L)) {
    inputs <- nl_paths_test_module$fixture$phase15_test_simulation_inputs(1L, seed)
    if (seed == 31L) { inputs$forecast_status$forecast_status <- "unavailable"; inputs$forecast_status$suppression_reason <- "unavailable-test" }
    rules <- if (seed == 99L) module$uefa_nl_2026_27_legacy_rules() else inputs$rules
    source <- inputs$source_bundle_id
    matches <- module$uefa_nl_sim_normalize_matches(inputs$canonical_matches, inputs$completed_results, rules, source)
    groups <- module$uefa_nl_sim_normalize_groups(inputs$groups, matches, rules)
    forecasts <- module$uefa_nl_sim_normalize_forecasts(inputs$forecasts, rules)
    status <- module$uefa_nl_sim_normalize_status(inputs$forecast_status, rules)
    scores <- module$uefa_nl_sim_normalize_score_distributions(inputs$score_distributions)
    cutoff <- module$uefa_nl_sim_cutoff(matches); slots <- module$uefa_nl_sim_normalize_stage_slots(NULL, rules)
    ids <- module$uefa_nl_sim_projection_ids("", "phase15-articles16-17-legal-seeded-draws-v2", seed)
    make_runtime <- function(paths) {
      runtime <- module$uefa_nl_sim_prepare_runtime(matches, forecasts, status, scores, cutoff, ids$projection_run_id, ids$draw_policy_id)
      runtime <- module$uefa_nl_sim_prepare_group_reducer(runtime, matches, groups, rules, source, cutoff)
      if (paths) runtime <- module$uefa_nl_sim_prepare_paths(runtime, rules, slots)
      runtime
    }
    before <- make_runtime(FALSE); after <- make_runtime(TRUE)
    eligibility <- if (seed == 99L) data.frame(team_id = groups$team_id, qualifies_for_euro_playoff = TRUE, stringsAsFactors = FALSE) else NULL
    args <- list(1L, matches, groups, status, forecasts, scores, rules, module$uefa_nl_sim_seed_for(seed, iteration = 1L), source, slots, eligibility, cutoff, ids$projection_run_id, ids$draw_policy_id)
    actual <- do.call(after$uefa_nl_sim_iteration, args)
    expect_identical(actual, do.call(before$uefa_nl_sim_iteration, args))
    if (seed == 99L) expect_true(any(actual$paths$status == "suppressed"))
  }
})
