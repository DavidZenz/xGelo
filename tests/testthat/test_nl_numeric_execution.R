library(testthat)

nl_numeric_test_module <- local({
  module <- new.env(parent = .GlobalEnv)
  for (path in c("source_contracts", "publication_hashes", "forecast_layer", "form", "state_bundle",
                 "standings", "uefa_nations_league_rules", "uefa_nations_league_simulation", "uefa_nations_league_numeric")) {
    sys.source(paste0("../../R/competition/", path, ".R"), envir = module)
  }
  fixture_env <- new.env(parent = module)
  for (expression in parse("test_phase15_nations_league.R")) {
    if (is.call(expression) && identical(expression[[1L]], as.name("<-"))) eval(expression, envir = fixture_env)
  }
  list(module = module, fixture = fixture_env)
})

nl_numeric_test_setup <- function(team_counts = c(A = 4L, D = 3L), missing = NULL) {
  module <- nl_numeric_test_module$module
  fixtures <- lapply(seq_along(team_counts), function(i) {
    nl_numeric_test_module$fixture$phase15_test_group_fixture(names(team_counts)[[i]], i, team_counts[[i]])
  })
  matches <- do.call(rbind, lapply(fixtures, `[[`, "matches"))
  matches$stage_id <- "league_phase"
  groups <- do.call(rbind, lapply(fixtures, function(fixture) {
    fixture$standings[, c("team_id", "league", "group_id", "discipline_points", "access_list_position")]
  }))
  if (identical(missing, "discipline")) groups$discipline_points[[1L]] <- NA_integer_
  if (identical(missing, "access")) groups$access_list_position[[1L]] <- NA_integer_
  rules <- module$uefa_nl_2026_27_rules()
  source <- fixtures[[1L]]$matches$source_bundle_id[[1L]]
  cutoff <- "2026-10-01T00:00:00Z"
  runtime <- new.env(parent = module)
  runtime <- module$uefa_nl_sim_prepare_group_reducer(runtime, matches, groups, rules, source, cutoff)
  previous <- runtime$uefa_nl_sim_build_league_state
  if (isTRUE(attr(previous, "nl_numeric_prepared", exact = TRUE))) previous <- environment(previous)$previous
  runtime <- module$uefa_nl_sim_prepare_numeric_groups(runtime, matches, groups, rules, source, cutoff)
  list(matches = matches, groups = groups, rules = rules, source = source, cutoff = cutoff,
       runtime = runtime, reference = previous)
}

nl_numeric_test_compare <- function(setup, matches = setup$matches, before_actual = NULL) {
  reference <- setup$reference(matches, setup$groups, setup$rules, setup$source, setup$cutoff)
  if (is.function(before_actual)) before_actual()
  actual <- setup$runtime$uefa_nl_sim_build_league_state(matches, setup$groups, setup$rules, setup$source, setup$cutoff)
  expect_identical(actual, reference)
  actual
}

test_that("prepared numeric group and Article 19 objects match full reference objects", {
  setup <- nl_numeric_test_setup()
  expect_true(isTRUE(attr(setup$runtime$uefa_nl_sim_build_league_state, "nl_numeric_prepared", exact = TRUE)))
  for (seed in c(7L, 31L, 15017L, 30001L, 41027L, 61001L)) {
    set.seed(seed)
    matches <- setup$matches
    matches$final_home_goals <- sample(0:5, nrow(matches), replace = TRUE)
    matches$final_away_goals <- sample(0:5, nrow(matches), replace = TRUE)
    actual <- nl_numeric_test_compare(setup, matches)
    a <- actual$individual[actual$individual$league == "A", ]
    d <- actual$individual[actual$individual$league == "D", ]
    expect_true(all(nzchar(a$excluded_match_ids[a$group_position < 4L])))
    expect_identical(a$excluded_match_ids[a$group_position == 4L], "")
    expect_true(all(!nzchar(d$excluded_match_ids)))
  }
})

test_that("distinct points and two-team ties retain exact criterion trace order", {
  setup <- nl_numeric_test_setup(c(A = 4L))
  module <- nl_numeric_test_module$module
  original <- module$uefa_nl_rank_group
  calls <- 0L
  setup$runtime$uefa_nl_rank_group <- function(...) { calls <<- calls + 1L; original(...) }
  # Every stronger team wins both legs: distinct 18/12/6/0 points.
  matches <- setup$matches
  teams <- sort(setup$groups$team_id)
  home <- match(matches$home_team_id, teams)
  away <- match(matches$away_team_id, teams)
  matches$final_home_goals <- as.integer(home < away)
  matches$final_away_goals <- as.integer(away < home)
  actual <- nl_numeric_test_compare(setup, matches, function() calls <<- 0L)
  expect_identical(calls, 0L)
  expect_identical(attr(actual$group_rankings[[1L]], "trace")$criterion, "points")
  # Seed 31 has a two-team points tie, resolved by H2H. Find a suitable fixed
  # seed explicitly so the test asserts the fast-path coverage it promises.
  found <- FALSE
  for (seed in 1:50) {
    set.seed(seed)
    matches$final_home_goals <- sample(0:3, nrow(matches), TRUE)
    matches$final_away_goals <- sample(0:3, nrow(matches), TRUE)
    reference <- setup$reference(matches, setup$groups, setup$rules, setup$source, setup$cutoff)
    trace <- attr(reference$group_rankings[[1L]], "trace")
    if (any(grepl("head_to_head", trace$criterion)) && all(table(reference$group_rankings[[1L]]$points) <= 2L)) {
      calls <- 0L
      nl_numeric_test_compare(setup, matches, function() calls <<- 0L)
      expect_identical(calls, 0L)
      found <- TRUE
      break
    }
  }
  expect_true(found)
})

test_that("three/four-team ties use the recursive Article 15 reducer", {
  for (team_count in c(3L, 4L)) {
    setup <- nl_numeric_test_setup(setNames(team_count, "A"))
    original <- nl_numeric_test_module$module$uefa_nl_rank_group
    calls <- 0L
    setup$runtime$uefa_nl_rank_group <- function(...) { calls <<- calls + 1L; original(...) }
    matches <- setup$matches
    matches$final_home_goals <- matches$final_away_goals <- rep.int(1L, nrow(matches))
    nl_numeric_test_compare(setup, matches, function() calls <<- 0L)
    expect_identical(calls, 1L)
  }
})

test_that("missing discipline/access, unavailable and late evidence preserve blocking", {
  for (missing in c("discipline", "access")) {
    setup <- nl_numeric_test_setup(missing = missing)
    actual <- nl_numeric_test_compare(setup)
    expect_true(all(actual$individual$ordering_status == "blocked"))
  }
  setup <- nl_numeric_test_setup()
  for (kind in c("missing", "late", "unavailable", "postponed", "unknown_status", "projected")) {
    matches <- setup$matches
    if (kind == "missing") matches$evidence_completed_at_utc[[1L]] <- NA_character_
    if (kind == "late") matches$evidence_completed_at_utc[[1L]] <- "2026-10-02T00:00:00Z"
    if (kind %in% c("unavailable", "postponed")) {
      matches$match_status[[1L]] <- if (kind == "postponed") "postponed" else "scheduled"
      matches$counts_for_standings[[1L]] <- FALSE
      matches$final_home_goals[[1L]] <- matches$final_away_goals[[1L]] <- NA_integer_
      matches$evidence_completed_at_utc[[1L]] <- NA_character_
    }
    if (kind == "unknown_status") matches$match_status[[1L]] <- "unsupported_status"
    if (kind == "projected") matches$evidence_completed_at_utc[[1L]] <- setup$cutoff
    nl_numeric_test_compare(setup, matches)
  }
})

test_that("prepared group helpers bind to the caller's private namespace", {
  setup <- nl_numeric_test_setup(c(A = 4L))
  calls <- 0L
  original <- nl_numeric_test_module$module$uefa_nl_rank_finalize
  setup$runtime$uefa_nl_rank_finalize <- function(...) { calls <<- calls + 1L; original(...) }
  nl_numeric_test_compare(setup)
  expect_gte(calls, 1L)
  same <- nl_numeric_test_module$module$uefa_nl_sim_prepare_numeric_groups(
    setup$runtime, setup$matches, setup$groups, setup$rules, setup$source, setup$cutoff)
  expect_identical(same$uefa_nl_sim_build_league_state, setup$runtime$uefa_nl_sim_build_league_state)
})
