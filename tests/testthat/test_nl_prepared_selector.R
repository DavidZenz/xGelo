library(testthat)
selector_repo <- normalizePath(file.path("..", ".."), winslash = "/", mustWork = TRUE)
withr::local_dir(selector_repo)
selector_module <- new.env(parent = .GlobalEnv)
for (file in c("source_contracts", "publication_hashes", "forecast_layer", "form", "state_bundle", "standings", "uefa_nations_league_rules",
               "uefa_nations_league_simulation", "uefa_nations_league_numeric", "uefa_nations_league_canonical", "uefa_nations_league_paths",
               "uefa_nations_league_transition_selector")) {
  sys.source(file.path(selector_repo, "R", "competition", paste0(file, ".R")), envir = selector_module)
}
selector_fixture <- new.env(parent = selector_module)
for (expression in parse(file.path(selector_repo, "tests", "testthat", "test_phase15_nations_league.R"))) {
  if (is.call(expression) && identical(expression[[1L]], as.name("<-"))) eval(expression, envir = selector_fixture)
}
selector_runtime <- function(rules = selector_module$uefa_nl_2026_27_rules()) {
  runtime <- new.env(parent = selector_module)
  for (name in ls(selector_module, pattern = "^uefa_nl_")) {
    value <- get(name, envir = selector_module)
    if (is.function(value)) { environment(value) <- runtime; assign(name, value, envir = runtime) }
  }
  runtime <- selector_module$uefa_nl_sim_prepare_canonical(runtime)
  runtime <- selector_module$uefa_nl_sim_prepare_paths(runtime, rules, data.frame())
  selector_module$uefa_nl_sim_prepare_transition_selector(runtime, rules)
}
selector_ready <- function() {
  ranks <- 1:54
  league <- c(rep("A", 16L), rep("B", 16L), rep("C", 16L), rep("D", 6L))
  positions <- c(rep(rep(1:4, each = 4L), 3L), rep(1:3, each = 2L))
  rules <- selector_module$uefa_nl_2026_27_rules()
  data.frame(edition_id = rules$edition_id, team_id = sprintf("selector-%02d", ranks), league = league,
    group_id = paste0(league, c(rep(1:4, 12L), rep(1:2, 3L))), group_position = positions,
    interim_rank = ranks, computed_rank = ranks, ranking_scope = "interim_overall", ordering_status = "ready",
    missing_rule_input = "", block_status = "not_blocked", blocked = FALSE, suppression_reason = "none",
    ruleset_version = rules$ruleset_version, ruleset_sha256 = selector_module$uefa_nl_ruleset_sha256(rules),
    stringsAsFactors = FALSE, check.names = FALSE)
}
test_that("numeric selector preserves complete rows, final order, hosting, NA types and hashes", {
  reference <- selector_module$uefa_nl_select_transition_slots
  runtime <- selector_runtime(); ready <- selector_ready()
  expect_identical(formals(runtime$uefa_nl_select_transition_slots), formals(reference))
  for (rows in list(1:54, 54:1, c(seq(2L, 54L, 2L), seq(1L, 53L, 2L)))) {
    candidate <- ready[rows, , drop = FALSE]
    set.seed(2917L); rng <- .Random.seed
    actual <- runtime$uefa_nl_select_transition_slots(candidate)
    expect_identical(.Random.seed, rng)
    expect_identical(actual, reference(candidate))
    expect_identical(nrow(actual), 24L)
    expect_identical(names(actual), names(reference(candidate)))
    expect_true(all(actual$first_leg_home_team_id[1:8] == actual$lower_league_team_id[1:8]))
    expect_identical(actual$higher_league_rank[1:8], c(11:14, 29:32))
    expect_identical(actual$lower_league_rank[1:8], c(21:24, 37:40))
  }
})
test_that("unsupported ready shapes, unknowns, legacy rules and external evidence use original", {
  reference <- selector_module$uefa_nl_select_transition_slots
  runtime <- selector_runtime(); calls <- new.env(parent = emptyenv()); calls$n <- 0L
  assign("original", function(...) { calls$n <- calls$n + 1L; reference(...) }, envir = environment(runtime$uefa_nl_select_transition_slots))
  ready <- selector_ready()
  expect_identical(runtime$uefa_nl_select_transition_slots(ready), reference(ready))
  expect_identical(calls$n, 0L)
  candidates <- list(ready[-54L, ], ready)
  candidates[[2L]]$ordering_status[[1L]] <- "blocked"
  for (field in c("computed_rank", "interim_rank", "group_position", "group_id", "ordering_status")) {
    candidate <- ready; candidate[[field]][[1L]] <- NA; candidates[[length(candidates) + 1L]] <- candidate
  }
  candidate <- ready; candidate$league <- tolower(candidate$league); candidates[[length(candidates) + 1L]] <- candidate
  candidate <- ready; candidate$ordering_status[[1L]] <- "unresolved"; candidates[[length(candidates) + 1L]] <- candidate
  candidate <- ready; candidate$interim_rank <- as.double(candidate$interim_rank); candidates[[length(candidates) + 1L]] <- candidate
  candidate <- ready; candidate$team_id <- factor(candidate$team_id); candidates[[length(candidates) + 1L]] <- candidate
  candidate <- ready; attr(candidate, "custom") <- "sentinel"; candidates[[length(candidates) + 1L]] <- candidate
  candidate <- ready[, setdiff(names(ready), "computed_rank"), drop = FALSE]; candidates[[length(candidates) + 1L]] <- candidate
  candidate <- unclass(ready); candidate$group_id <- setNames(candidate$group_id, seq_len(54L))
  attributes(candidate) <- attributes(ready); candidates[[length(candidates) + 1L]] <- candidate
  for (candidate in candidates) {
    previous <- calls$n
    expect_identical(runtime$uefa_nl_select_transition_slots(candidate), reference(candidate))
    expect_identical(calls$n, previous + 1L)
  }
  eligibility <- data.frame(team_id = ready$team_id, qualifies_for_euro_playoff = FALSE)
  previous <- calls$n
  expect_identical(runtime$uefa_nl_select_transition_slots(ready, eligibility), reference(ready, eligibility))
  expect_identical(calls$n, previous + 1L)
  legacy <- selector_module$uefa_nl_2026_27_legacy_rules()
  previous <- calls$n
  expect_identical(runtime$uefa_nl_select_transition_slots(ready, eligibility, legacy), reference(ready, eligibility, legacy))
  expect_identical(calls$n, previous + 1L)
  eligibility$qualifies_for_euro_playoff <- TRUE
  previous <- calls$n
  expect_identical(runtime$uefa_nl_select_transition_slots(ready, eligibility, legacy), reference(ready, eligibility, legacy))
  expect_identical(calls$n, previous + 1L)
  changed <- selector_module$uefa_nl_2026_27_rules(); changed$transitions$play_offs$a_b_playoff$higher_ranks <- 9:12
  previous <- calls$n
  expect_identical(runtime$uefa_nl_select_transition_slots(ready, rules = changed), reference(ready, rules = changed))
  expect_identical(calls$n, previous + 1L)
})
test_that("candidate preserves full mechanics iterations for revised seeds and unknown forecasts", {
  module <- selector_module
  for (seed in c(7L, 31L, 99L)) {
    inputs <- selector_fixture$phase15_test_simulation_inputs(1L, seed)
    if (seed == 31L) { inputs$forecast_status$forecast_status <- "unavailable"; inputs$forecast_status$suppression_reason <- "unavailable-test" }
    rules <- inputs$rules; source <- inputs$source_bundle_id
    matches <- module$uefa_nl_sim_normalize_matches(inputs$canonical_matches, inputs$completed_results, rules, source)
    groups <- module$uefa_nl_sim_normalize_groups(inputs$groups, matches, rules)
    forecasts <- module$uefa_nl_sim_normalize_forecasts(inputs$forecasts, rules)
    status <- module$uefa_nl_sim_normalize_status(inputs$forecast_status, rules)
    scores <- module$uefa_nl_sim_normalize_score_distributions(inputs$score_distributions)
    cutoff <- module$uefa_nl_sim_cutoff(matches); slots <- module$uefa_nl_sim_normalize_stage_slots(NULL, rules)
    ids <- module$uefa_nl_sim_projection_ids("", "phase15-articles16-17-legal-seeded-draws-v2", seed)
    make_runtime <- function(candidate) {
      runtime <- module$uefa_nl_sim_prepare_runtime(matches, forecasts, status, scores, cutoff, ids$projection_run_id, ids$draw_policy_id)
      runtime <- module$uefa_nl_sim_prepare_group_reducer(runtime, matches, groups, rules, source, cutoff)
      runtime <- module$uefa_nl_sim_prepare_paths(runtime, rules, slots)
      if (candidate) runtime <- module$uefa_nl_sim_prepare_transition_selector(runtime, rules)
      runtime
    }
    before <- make_runtime(FALSE); after <- make_runtime(TRUE)
    args <- list(1L, matches, groups, status, forecasts, scores, rules, module$uefa_nl_sim_seed_for(seed, iteration = 1L), source, slots, NULL, cutoff, ids$projection_run_id, ids$draw_policy_id)
    expect_identical(do.call(after$uefa_nl_sim_iteration, args), do.call(before$uefa_nl_sim_iteration, args))
  }
})
