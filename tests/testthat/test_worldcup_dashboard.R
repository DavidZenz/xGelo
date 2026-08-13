# xGelo World Cup dashboard contracts

context("World Cup Dashboard")

project_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))

predict.constant_goal_model <- function(object, newdata, type = "response", ...) {
  rep(object$lambda, nrow(newdata))
}
assign("predict.constant_goal_model", predict.constant_goal_model, envir = .GlobalEnv)

test_that("World Cup group seed and official fixtures cover the 2026 format", {
  source(file.path(project_root, "R/visualization/worldcup_dashboard.R"))
  groups <- load_worldcup_2026_groups(file.path(project_root, "data/raw/worldcup_2026_groups.csv"))
  fixtures <- make_worldcup_group_fixtures(
    groups,
    schedule_path = file.path(project_root, "data/raw/worldcup_2026_group_fixtures.csv")
  )

  expect_equal(nrow(groups), 48)
  expect_equal(sort(unique(groups$group)), LETTERS[1:12])
  expect_true(all(table(groups$group) == 4))
  expect_equal(nrow(fixtures), 72)
  expect_true(all(table(fixtures$group) == 6))
  expect_equal(min(fixtures$date), as.Date("2026-06-11"))
  expect_equal(max(fixtures$date), as.Date("2026-06-27"))
  expect_true(all(c(
    "home_team",
    "away_team",
    "home_display",
    "away_display",
    "match_id",
    "kickoff_local",
    "venue_name",
    "host_city"
  ) %in% names(fixtures)))

  opener <- fixtures[fixtures$match_id == "GA01", ]
  expect_equal(opener$home_team, "Mexico")
  expect_equal(opener$away_team, "South Africa")
  expect_equal(opener$date, as.Date("2026-06-11"))
  expect_equal(opener$kickoff_local, "13:00")
  expect_equal(opener$venue_name, "Estadio Azteca")

  england_opener <- fixtures[fixtures$match_id == "GL02", ]
  expect_equal(england_opener$home_team, "England")
  expect_equal(england_opener$away_team, "Croatia")
  expect_equal(england_opener$date, as.Date("2026-06-17"))
  expect_equal(england_opener$host_city, "Arlington")
})

test_that("12-10 calibrated outcome view changes 1X2 fields but preserves scorelines", {
  source(file.path(project_root, "R/visualization/worldcup_dashboard.R"))
  old_simulate <- if (exists("simulate_fixture", envir = .GlobalEnv, inherits = FALSE)) get("simulate_fixture", envir = .GlobalEnv) else NULL
  old_apply <- if (exists("apply_phase12_1x2_calibrator", envir = .GlobalEnv, inherits = FALSE)) get("apply_phase12_1x2_calibrator", envir = .GlobalEnv) else NULL
  on.exit({
    if (is.null(old_simulate)) rm("simulate_fixture", envir = .GlobalEnv) else assign("simulate_fixture", old_simulate, envir = .GlobalEnv)
    if (is.null(old_apply)) rm("apply_phase12_1x2_calibrator", envir = .GlobalEnv) else assign("apply_phase12_1x2_calibrator", old_apply, envir = .GlobalEnv)
  }, add = TRUE)
  assign("simulate_fixture", function(...) {
    list(
      win_prob = 0.6, draw_prob = 0.2, loss_prob = 0.2,
      expected_home = 1.4, expected_away = 0.7,
      predicted_outcome = "home_win", most_likely_score = "1-0",
      most_likely_score_probability = 0.35, rounded_expected_score = "1-1",
      over_2_5_probability = 0.3, under_2_5_probability = 0.7,
      both_teams_to_score_probability = 0.25,
      scoreline_distribution = data.frame(
        home_goals = c(0L, 1L), away_goals = c(0L, 0L),
        scoreline = c("0-0", "1-0"), outcome = c("draw", "home_win"),
        count = c(4L, 6L), probability = c(0.4, 0.6), stringsAsFactors = FALSE
      )
    )
  }, envir = .GlobalEnv)
  assign("apply_phase12_1x2_calibrator", function(calibrator, probabilities) setNames(c(0.1, 0.2, 0.7), c("home", "draw", "away")), envir = .GlobalEnv)
  calibrator <- list(schema_version = "phase12-calibrator-v1", candidate_id = "synthetic", track_id = "updating", fit_status = "fitted", primary_probability_view = "calibrated_1x2", distribution_unchanged = TRUE, temperature = 1.2)
  fixture <- data.frame(
    match_id = "SYN01", stage = "Group stage", group = "A", matchday = 1L, date = as.Date("2026-06-11"),
    home_team = "A1", away_team = "A2", home_display = "A1", away_display = "A2", kickoff_local = "13:00",
    venue = "Synthetic", venue_name = "Synthetic", host_city = "Synthetic", host_country = "Mexico",
    is_completed = FALSE, match_status = "scheduled", actual_home_goals = NA_integer_, actual_away_goals = NA_integer_, actual_score = NA_character_, stringsAsFactors = FALSE
  )
  raw <- forecast_dashboard_matches(fixture, n_match_sim = 10, seed = 1)
  calibrated <- forecast_dashboard_matches(fixture, n_match_sim = 10, seed = 1, calibrator = calibrator, primary_probability_view = "calibrated_1x2")
  expect_equal(raw$scoreline_distributions[, c("home_goals", "away_goals", "probability")], calibrated$scoreline_distributions[, c("home_goals", "away_goals", "probability")])
  expect_equal(raw$match_forecasts[, c("home_goals_expected", "away_goals_expected", "most_likely_score", "over_2_5_probability", "both_teams_to_score_probability")], calibrated$match_forecasts[, c("home_goals_expected", "away_goals_expected", "most_likely_score", "over_2_5_probability", "both_teams_to_score_probability")])
  expect_equal(calibrated$outcome_view[, c("p_home", "p_draw", "p_away")], data.frame(p_home = 0.1, p_draw = 0.2, p_away = 0.7))
  expect_equal(calibrated$match_forecasts[, c("win_probability", "draw_probability", "loss_probability")], data.frame(win_probability = 0.1, draw_probability = 0.2, loss_probability = 0.7))
  expect_identical(calibrated$match_forecasts$predicted_outcome, "away_win")
})

test_that("12-10 calibrated group outcomes drive points while raw scores drive goals", {
  source(file.path(project_root, "R/forecast/tournament.R"))
  source(file.path(project_root, "R/visualization/worldcup_dashboard.R"))
  groups <- load_worldcup_2026_groups(file.path(project_root, "data/raw/worldcup_2026_groups.csv"))
  fixtures <- make_worldcup_group_fixtures(groups, file.path(project_root, "data/raw/worldcup_2026_group_fixtures.csv"))
  scorelines <- do.call(rbind, lapply(fixtures$match_id, function(id) data.frame(match_id = id, home_goals = 0L, away_goals = 0L, probability = 1, rank = 1L, stringsAsFactors = FALSE)))
  outcome_view <- data.frame(match_id = fixtures$match_id, p_home = 1, p_draw = 0, p_away = 0, stringsAsFactors = FALSE)
  always_slot1_route <- function(team1, team2) list(slot1_regulation_win_probability = 1, slot2_regulation_win_probability = 0, slot1_advancement_probability = 1, slot2_advancement_probability = 0, draw_after_regulation_probability = 0, tiebreak_probability = 0.5)
  raw <- simulate_group_stage_dashboard(groups, fixtures, scorelines, n_tournaments = 4, seed = 5, knockout_route_estimator = always_slot1_route, n_workers = 1)
  calibrated <- simulate_group_stage_dashboard(groups, fixtures, scorelines, n_tournaments = 4, seed = 5, knockout_route_estimator = always_slot1_route, n_workers = 1, outcome_view = outcome_view, primary_probability_view = "calibrated_1x2")
  expect_false(identical(raw$expected_group_tables, calibrated$expected_group_tables))
  expect_false(identical(raw$group_probabilities$group_win_probability, calibrated$group_probabilities$group_win_probability))
  expect_true(all(calibrated$expected_group_tables$expected_goals_for == 0))
  expect_true(all(calibrated$expected_group_tables$expected_goals_against == 0))
})

test_that("12-10 calibrated knockout route changes advancement components only", {
  source(file.path(project_root, "R/visualization/worldcup_dashboard.R"))
  old_apply <- if (exists("apply_phase12_1x2_calibrator", envir = .GlobalEnv, inherits = FALSE)) get("apply_phase12_1x2_calibrator", envir = .GlobalEnv) else NULL
  on.exit(if (is.null(old_apply)) rm("apply_phase12_1x2_calibrator", envir = .GlobalEnv) else assign("apply_phase12_1x2_calibrator", old_apply, envir = .GlobalEnv), add = TRUE)
  assign("apply_phase12_1x2_calibrator", function(calibrator, probabilities) setNames(c(0.1, 0.2, 0.7), c("home", "draw", "away")), envir = .GlobalEnv)
  ratings_path <- tempfile(fileext = ".csv")
  utils::write.csv(data.frame(team = c("A", "B"), date = as.Date("2026-01-01"), rating = c(1500, 1500)), ratings_path, row.names = FALSE)
  model <- structure(list(lambda = 2), class = "constant_goal_model")
  calibrator <- list(schema_version = "phase12-calibrator-v1", candidate_id = "synthetic", track_id = "updating", fit_status = "fitted", primary_probability_view = "calibrated_1x2", distribution_unchanged = TRUE, temperature = 1.2)
  raw <- make_knockout_route_estimator(c(A = 1500, B = 1500), "2026-06-28", home_model = model, away_model = model, elo_ratings_path = ratings_path, route_method = "analytic")
  calibrated <- make_knockout_route_estimator(c(A = 1500, B = 1500), "2026-06-28", home_model = model, away_model = model, elo_ratings_path = ratings_path, route_method = "analytic", calibrator = calibrator, primary_probability_view = "calibrated_1x2")
  raw_route <- raw("A", "B")
  calibrated_route <- calibrated("A", "B")
  expect_false(isTRUE(all.equal(raw_route[c("slot1_regulation_win_probability", "draw_after_regulation_probability", "slot2_regulation_win_probability")], calibrated_route[c("slot1_regulation_win_probability", "draw_after_regulation_probability", "slot2_regulation_win_probability")])) )
  expect_equal(raw_route[c("most_likely_score", "over_2_5_probability", "both_teams_to_score_probability")], calibrated_route[c("most_likely_score", "over_2_5_probability", "both_teams_to_score_probability")])
})

test_that("12-10 invalid calibrated releases fail before forecast work", {
  source(file.path(project_root, "R/visualization/worldcup_dashboard.R"))
  old_simulate <- if (exists("simulate_fixture", envir = .GlobalEnv, inherits = FALSE)) get("simulate_fixture", envir = .GlobalEnv) else NULL
  on.exit(if (is.null(old_simulate)) rm("simulate_fixture", envir = .GlobalEnv) else assign("simulate_fixture", old_simulate, envir = .GlobalEnv), add = TRUE)
  calls <- 0L
  assign("simulate_fixture", function(...) { calls <<- calls + 1L; stop("forecast should not run") }, envir = .GlobalEnv)
  fixture <- data.frame(match_id = "SYN02", stage = "Group stage", group = "A", matchday = 1L, date = as.Date("2026-06-11"), home_team = "A1", away_team = "A2", home_display = "A1", away_display = "A2", kickoff_local = "13:00", venue = "Synthetic", venue_name = "Synthetic", host_city = "Synthetic", host_country = "Mexico", is_completed = FALSE, match_status = "scheduled", stringsAsFactors = FALSE)
  expect_error(forecast_dashboard_matches(fixture, primary_probability_view = "calibrated_1x2"), "structurally valid calibrator")
  expect_identical(calls, 0L)
})

test_that("12-10 direct dashboard callers retain resolver-first release authority", {
  targets <- paste(readLines(file.path(project_root, "_targets.R"), warn = FALSE), collapse = "\n")
  updater <- paste(readLines(file.path(project_root, "scripts/update_worldcup_dashboard.R"), warn = FALSE), collapse = "\n")
  expect_true(grepl("resolve_phase12_approved_release", targets, fixed = TRUE))
  expect_true(grepl("resolve_phase12_approved_release", updater, fixed = TRUE))
  expect_false(grepl("home_model_path =", targets, fixed = TRUE))
  expect_false(grepl("home_model_path =", updater, fixed = TRUE))
})

test_that("dashboard builders reject NULL roots and caller-supplied model authority", {
  source(file.path(project_root, "R/release/release_bundle.R"))
  source(file.path(project_root, "R/release/release_install.R"))
  source(file.path(project_root, "R/release/release_contract.R"))
  source(file.path(project_root, "R/visualization/worldcup_dashboard.R"))
  expect_error(build_worldcup_dashboard_data(release_root = NULL), "trusted Phase 12 release root")
  expect_error(build_worldcup_dashboard(release_root = NULL), "trusted Phase 12 release root")
  expect_error(dashboard_reject_raw_model_paths(list(home_model_path = "model.rds")), "home_model_path")
  expect_error(dashboard_reject_raw_model_paths(list(baseline_comparison = FALSE)), "baseline_comparison")
  expect_error(dashboard_reject_raw_model_paths(baseline_comparison_supplied = TRUE), "baseline_comparison")
})

test_that("World Cup knockout template follows official FIFA match tree", {
  source(file.path(project_root, "R/visualization/worldcup_dashboard.R"))

  bracket <- worldcup_bracket_template(include_champion = FALSE)
  by_id <- function(match_id) bracket[bracket$match_id == match_id, ]

  expect_equal(nrow(bracket), 32)
  expect_setequal(bracket$match_id, paste0("M", 73:104))

  expect_equal(by_id("M73")$slot1_label, "Runner-up Group A")
  expect_equal(by_id("M73")$slot2_label, "Runner-up Group B")
  expect_equal(by_id("M74")$slot1_label, "Winner Group E")
  expect_equal(by_id("M74")$slot2_label, "Best 3rd A/B/C/D/F")
  expect_equal(by_id("M80")$slot1_label, "Winner Group L")
  expect_equal(by_id("M80")$slot2_label, "Best 3rd E/H/I/J/K")
  expect_equal(by_id("M87")$slot1_label, "Winner Group K")
  expect_equal(by_id("M87")$slot2_label, "Best 3rd D/E/I/J/L")
  expect_equal(by_id("M88")$slot1_label, "Runner-up Group D")
  expect_equal(by_id("M88")$slot2_label, "Runner-up Group G")

  expect_equal(by_id("M89")$slot1_label, "Winner M74")
  expect_equal(by_id("M89")$slot2_label, "Winner M77")
  expect_equal(by_id("M96")$slot1_label, "Winner M85")
  expect_equal(by_id("M96")$slot2_label, "Winner M87")
  expect_equal(by_id("M98")$slot1_label, "Winner M93")
  expect_equal(by_id("M98")$slot2_label, "Winner M94")
  expect_equal(by_id("M100")$slot1_label, "Winner M95")
  expect_equal(by_id("M100")$slot2_label, "Winner M96")
  expect_equal(by_id("M101")$slot1_label, "Winner M97")
  expect_equal(by_id("M101")$slot2_label, "Winner M98")
  expect_equal(by_id("M102")$slot1_label, "Winner M99")
  expect_equal(by_id("M102")$slot2_label, "Winner M100")
  expect_equal(by_id("M104")$slot1_label, "Winner M101")
  expect_equal(by_id("M104")$slot2_label, "Winner M102")
  expect_equal(by_id("M103")$round, "Third-place play-off")
  expect_equal(by_id("M103")$slot1_label, "Loser M101")
  expect_equal(by_id("M103")$slot2_label, "Loser M102")
  expect_lt(match("M104", bracket$match_id), match("M103", bracket$match_id))
})

test_that("World Cup third-place routing uses FIFA Annex C combinations", {
  source(file.path(project_root, "R/visualization/worldcup_dashboard.R"))

  pairings <- worldcup_third_place_pairing_table(
    file.path(project_root, "data/raw/worldcup_2026_third_place_pairings.csv")
  )
  expect_equal(nrow(pairings), 495)
  assignments <- worldcup_third_place_assignments(LETTERS[1:8], pairings)
  expect_equal(unname(assignments[c("A", "B", "D", "E", "G", "I", "K", "L")]), c("H", "G", "B", "C", "A", "F", "D", "E"))

  ranked_groups <- lapply(LETTERS[1:12], function(group_id) {
    data.frame(
      group = group_id,
      team = paste0(group_id, 1:4),
      display_team = paste0(group_id, 1:4),
      projected_position = 1:4,
      third_place_qual_probability = c(0, 0, if (group_id %in% LETTERS[1:8]) 1 else 0, 0),
      position_3_probability = c(0, 0, 1, 0),
      stringsAsFactors = FALSE
    )
  })
  group_probabilities <- do.call(rbind, ranked_groups)
  projected <- projected_worldcup_third_place_candidates(group_probabilities, pairings)
  expect_equal(projected$assignments["E"], c(E = "C"))
  expect_equal(projected$candidates$team[projected$candidates$group == "C"], "C3")
})

test_that("dynamic World Cup knockouts sample route probabilities, not Elo-only winners", {
  source(file.path(project_root, "R/visualization/worldcup_dashboard.R"))

  ranked_groups <- lapply(LETTERS[1:12], function(group_id) {
    data.frame(
      group = group_id,
      team = paste0(group_id, 1:4),
      points = c(9, 6, 3, 0),
      goal_difference = c(5, 2, -1, -6),
      goals_for = c(8, 5, 3, 1),
      tie_breaker = seq(0.1, 0.4, by = 0.1),
      finish_position = 1:4,
      stringsAsFactors = FALSE
    )
  })
  names(ranked_groups) <- LETTERS[1:12]
  best_thirds <- data.frame(
    group = LETTERS[1:8],
    team = paste0(LETTERS[1:8], 3),
    points = 3,
    goal_difference = -1,
    goals_for = 3,
    tie_breaker = seq(0.1, 0.8, by = 0.1),
    finish_position = 3,
    stringsAsFactors = FALSE
  )
  rating_by_team <- stats::setNames(rep(1500, 48), unlist(lapply(LETTERS[1:12], function(group_id) paste0(group_id, 1:4))))
  route_calls <- 0
  route_teams <- list()
  always_slot1_route <- function(team1, team2) {
    route_calls <<- route_calls + 1
    route_teams[[route_calls]] <<- c(team1, team2)
    list(
      slot1_regulation_win_probability = 1,
      slot1_extra_time_penalty_probability = 0,
      slot1_advancement_probability = 1,
      slot2_regulation_win_probability = 0,
      slot2_extra_time_penalty_probability = 0,
      slot2_advancement_probability = 0,
      draw_after_regulation_probability = 0,
      tiebreak_probability = 0.5
    )
  }

  reachers <- simulate_knockout_bracket_once(
    ranked_groups,
    best_thirds,
    rating_by_team,
    knockout_route_estimator = always_slot1_route
  )

  expect_equal(route_calls, 32)
  expect_equal(reachers$champion, "E1")
  expect_false(any(route_teams[[31]] %in% route_teams[[32]]))
})

test_that("World Cup tournament simulation chunks are deterministic across workers", {
  source(file.path(project_root, "R/forecast/tournament.R"))
  source(file.path(project_root, "R/visualization/worldcup_dashboard.R"))

  groups <- load_worldcup_2026_groups(file.path(project_root, "data/raw/worldcup_2026_groups.csv"))
  fixtures <- make_worldcup_group_fixtures(
    groups,
    schedule_path = file.path(project_root, "data/raw/worldcup_2026_group_fixtures.csv")
  )
  scoreline_distributions <- do.call(rbind, lapply(fixtures$match_id, function(match_id) {
    data.frame(
      match_id = match_id,
      home_goals = c(0L, 1L),
      away_goals = c(0L, 0L),
      probability = c(0.45, 0.55),
      rank = 1:2,
      stringsAsFactors = FALSE
    )
  }))
  always_slot1_route <- function(team1, team2) {
    list(
      slot1_regulation_win_probability = 1,
      slot2_regulation_win_probability = 0,
      tiebreak_probability = 1
    )
  }

  serial <- simulate_group_stage_dashboard(
    groups,
    fixtures,
    scoreline_distributions,
    n_tournaments = 8,
    seed = 20260612,
    knockout_route_estimator = always_slot1_route,
    n_workers = 1
  )
  parallel <- simulate_group_stage_dashboard(
    groups,
    fixtures,
    scoreline_distributions,
    n_tournaments = 8,
    seed = 20260612,
    knockout_route_estimator = always_slot1_route,
    n_workers = 2
  )

  expect_equal(parallel$group_probabilities, serial$group_probabilities)
  expect_equal(parallel$expected_group_tables, serial$expected_group_tables)
  expect_equal(parallel$stage_probabilities, serial$stage_probabilities)
})

test_that("completed knockout results condition tournament stage probabilities", {
  source(file.path(project_root, "R/forecast/tournament.R"))
  source(file.path(project_root, "R/visualization/worldcup_dashboard.R"))

  groups <- load_worldcup_2026_groups(file.path(project_root, "data/raw/worldcup_2026_groups.csv"))
  fixtures <- make_worldcup_group_fixtures(
    groups,
    schedule_path = file.path(project_root, "data/raw/worldcup_2026_group_fixtures.csv")
  )
  scoreline_distributions <- do.call(rbind, lapply(fixtures$match_id, function(match_id) {
    data.frame(
      match_id = match_id,
      home_goals = 1L,
      away_goals = 0L,
      probability = 1,
      rank = 1L,
      stringsAsFactors = FALSE
    )
  }))
  always_slot1_route <- function(team1, team2) {
    list(
      slot1_regulation_win_probability = 1,
      slot1_extra_time_penalty_probability = 0,
      slot1_advancement_probability = 1,
      slot2_regulation_win_probability = 0,
      slot2_extra_time_penalty_probability = 0,
      slot2_advancement_probability = 0,
      draw_after_regulation_probability = 0,
      tiebreak_probability = 0.5
    )
  }
  actual_knockout_results <- data.frame(
    date = as.Date("2026-06-28"),
    home_team_canonical = "Germany",
    away_team_canonical = "France",
    home_score = 1L,
    away_score = 1L,
    actual_winner_team = "France",
    tournament = "FIFA World Cup",
    stringsAsFactors = FALSE
  )

  result <- simulate_group_stage_dashboard(
    groups,
    fixtures,
    scoreline_distributions,
    n_tournaments = 4,
    seed = 20260612,
    knockout_route_estimator = always_slot1_route,
    actual_knockout_results = actual_knockout_results,
    n_workers = 1
  )
  stages <- result$stage_probabilities

  expect_equal(stages$round_of_32_probability[stages$team == "Germany"], 1)
  expect_equal(stages$round_of_16_probability[stages$team == "Germany"], 0)
  expect_equal(stages$round_of_32_probability[stages$team == "France"], 1)
  expect_equal(stages$round_of_16_probability[stages$team == "France"], 1)
})

test_that("completed World Cup fixtures are fixed at actual scores", {
  source(file.path(project_root, "R/forecast/monte_carlo.R"))
  source(file.path(project_root, "R/visualization/worldcup_dashboard.R"))

  groups <- load_worldcup_2026_groups(file.path(project_root, "data/raw/worldcup_2026_groups.csv"))
  fixtures <- make_worldcup_group_fixtures(
    groups,
    schedule_path = file.path(project_root, "data/raw/worldcup_2026_group_fixtures.csv")
  )
  results_path <- tempfile(fileext = ".csv")
  write.csv(
    data.frame(
      date = as.Date(c("2026-06-11", "2026-06-24")),
      home_team_canonical = c("Mexico", "Mexico"),
      away_team_canonical = c("South Africa", "Czech Republic"),
      home_score = c(2, 3),
      away_score = c(0, 0),
      tournament = c("FIFA World Cup", "FIFA World Cup"),
      stringsAsFactors = FALSE
    ),
    results_path,
    row.names = FALSE
  )

  fixtures <- attach_worldcup_actual_results(
    fixtures = fixtures,
    matches_path = results_path,
    result_cutoff_date = as.Date("2026-06-25")
  )
  opener <- fixtures[fixtures$match_id == "GA01", ]
  expect_true(opener$is_completed)
  expect_equal(opener$match_status, "final")
  expect_equal(opener$actual_score, "2-0")

  reversed <- fixtures[fixtures$match_id == "GA05", ]
  expect_true(reversed$is_completed)
  expect_equal(reversed$match_status, "final")
  expect_equal(reversed$home_team, "Czech Republic")
  expect_equal(reversed$away_team, "Mexico")
  expect_equal(reversed$actual_score, "0-3")

  forecast <- forecast_dashboard_matches(opener, n_match_sim = 20, seed = 1)
  expect_true(forecast$match_forecasts$is_completed)
  expect_equal(forecast$match_forecasts$actual_score, "2-0")
  expect_equal(forecast$match_forecasts$win_probability, 1)
  expect_equal(forecast$match_forecasts$draw_probability, 0)
  expect_equal(forecast$match_forecasts$loss_probability, 0)
  expect_equal(forecast$scoreline_distributions$scoreline, "2-0")
  expect_equal(forecast$scoreline_distributions$probability, 1)

  with_prematch <- attach_dashboard_prematch_forecasts(
    forecast$match_forecasts,
    data.frame(
      match_id = "GA01",
      prematch_home_goals_expected = 1.4,
      prematch_away_goals_expected = 0.8,
      prematch_win_probability = 0.55,
      prematch_draw_probability = 0.25,
      prematch_loss_probability = 0.20,
      prematch_predicted_outcome = "home_win",
      prematch_most_likely_score = "1-0",
      prematch_most_likely_score_probability = 0.12,
      prematch_rounded_expected_score = "1-1",
      prematch_over_2_5_probability = 0.42,
      prematch_under_2_5_probability = 0.58,
      prematch_both_teams_to_score_probability = 0.45,
      prematch_generated_at = "2026-06-10 12:00:00",
      prematch_feature_cutoff_date = "2026-06-10",
      prematch_actual_results_cutoff_date = "2026-06-10",
      prematch_forecast_source = "dashboard_archive",
      stringsAsFactors = FALSE
    )
  )
  expect_equal(with_prematch$win_probability, 1)
  expect_true(with_prematch$prematch_forecast_available)
  expect_equal(with_prematch$prematch_win_probability, 0.55)
  expect_equal(with_prematch$prematch_draw_probability, 0.25)
  expect_equal(with_prematch$prematch_loss_probability, 0.20)
  expect_equal(with_prematch$prematch_most_likely_score, "1-0")
})

test_that("prematch archive accepts older forecast rows without completion columns", {
  source(file.path(project_root, "R/visualization/worldcup_dashboard.R"))

  archive <- make_dashboard_prematch_forecast_rows(
    data.frame(
      match_id = "GA01",
      date = "2026-06-11",
      group = "A",
      home_team = "Mexico",
      away_team = "South Africa",
      home_display = "Mexico",
      away_display = "South Africa",
      home_goals_expected = 1.7,
      away_goals_expected = 1.0,
      win_probability = 0.52,
      draw_probability = 0.24,
      loss_probability = 0.24,
      predicted_outcome = "home_win",
      most_likely_score = "1-0",
      most_likely_score_probability = 0.11,
      rounded_expected_score = "2-1",
      over_2_5_probability = 0.48,
      under_2_5_probability = 0.52,
      both_teams_to_score_probability = 0.47,
      stringsAsFactors = FALSE
    ),
    generated_at = "2026-06-10 12:00:00",
    feature_cutoff_date = "2026-06-10",
    actual_results_cutoff_date = "2026-06-10"
  )

  expect_equal(nrow(archive), 1)
  expect_equal(archive$match_id, "GA01")
  expect_equal(archive$prematch_win_probability, 0.52)
})

test_that("bracket prematch archive preserves projected knockout forecasts", {
  source(file.path(project_root, "R/visualization/worldcup_dashboard.R"))

  bracket_paths <- data.frame(
    match_id = "M104",
    round = "Final",
    slot1_label = "Winner M102",
    slot1_team = "Austria",
    slot1_display = "Austria",
    slot1_source_match_id = "M102",
    slot1_probability = 0.42,
    slot1_advancement_probability = 0.56,
    slot1_regulation_win_probability = 0.34,
    slot1_extra_time_penalty_probability = 0.22,
    slot1_tiebreak_probability = 0.55,
    slot2_label = "Winner M103",
    slot2_team = "Bosnia and Herzegovina",
    slot2_display = "Bosnia and Herzegovina",
    slot2_source_match_id = "M103",
    slot2_probability = 0.38,
    slot2_advancement_probability = 0.44,
    slot2_regulation_win_probability = 0.28,
    slot2_extra_time_penalty_probability = 0.16,
    slot2_tiebreak_probability = 0.45,
    draw_after_regulation_probability = 0.38,
    projected_winner_team = "Austria",
    projected_winner = "Austria",
    projected_winner_match_probability = 0.56,
    projected_winner_regulation_probability = 0.34,
    projected_winner_extra_time_penalty_probability = 0.22,
    projected_winner_tiebreak_probability = 0.55,
    projected_winner_route_label = "90' win 34.0%",
    slot1_expected_goals = 1.5,
    slot2_expected_goals = 1.1,
    most_likely_score = "1-0",
    most_likely_score_probability = 0.12,
    rounded_expected_score = "2-1",
    over_2_5_probability = 0.48,
    both_teams_to_score_probability = 0.51,
    top_scorelines_label = "1-0 12.0%; 1-1 11.0%",
    stringsAsFactors = FALSE
  )

  archive <- make_dashboard_bracket_prematch_forecast_rows(
    bracket_paths = bracket_paths,
    generated_at = "2026-06-28 12:00:00",
    feature_cutoff_date = "2026-06-28",
    actual_results_cutoff_date = "2026-06-28"
  )

  expect_equal(nrow(archive), 1)
  expect_equal(archive$match_id, "M104")
  expect_equal(archive$prematch_projected_winner, "Austria")
  expect_equal(archive$prematch_slot1_expected_goals, 1.5)
  expect_equal(archive$prematch_most_likely_score, "1-0")

  attached <- attach_dashboard_bracket_prematch_forecasts(
    bracket_paths,
    archive
  )
  expect_true(attached$prematch_forecast_available)
  expect_equal(attached$prematch_projected_winner_match_probability, 0.56)
  expect_equal(attached$prematch_top_scorelines_label, "1-0 12.0%; 1-1 11.0%")
})

test_that("knockout bracket rows attach actual decided results", {
  source(file.path(project_root, "R/visualization/worldcup_dashboard.R"))

  bracket_paths <- data.frame(
    round = c("Round of 32", "Round of 16"),
    match_id = c("M73", "M90"),
    slot1_label = c("Runner-up Group A", "Winner M73"),
    slot2_label = c("Runner-up Group B", "Winner M75"),
    slot1_team = c("South Africa", "Canada"),
    slot1_display = c("South Africa", "Canada"),
    slot1_source_match_id = c(NA, "M73"),
    slot2_team = c("Canada", "Morocco"),
    slot2_display = c("Canada", "Morocco"),
    slot2_source_match_id = c(NA, "M75"),
    projected_winner_team = c("Canada", "Morocco"),
    projected_winner = c("Canada", "Morocco"),
    next_match_id = c("M90", NA),
    stringsAsFactors = FALSE
  )
  matches_path <- tempfile(fileext = ".csv")
  write.csv(
    data.frame(
      date = "2026-06-28",
      home_team_canonical = "South Africa",
      away_team_canonical = "Canada",
      home_score = 0,
      away_score = 1,
      tournament = "FIFA World Cup",
      stringsAsFactors = FALSE
    ),
    matches_path,
    row.names = FALSE
  )

  attached <- attach_worldcup_bracket_actual_results(
    bracket_paths,
    matches_path = matches_path,
    result_cutoff_date = "2026-06-28",
    knockout_start_date = "2026-06-28"
  )

  expect_true(attached$is_completed[attached$match_id == "M73"])
  expect_equal(attached$match_status[attached$match_id == "M73"], "final")
  expect_equal(attached$actual_score[attached$match_id == "M73"], "0-1")
  expect_equal(attached$actual_winner_team[attached$match_id == "M73"], "Canada")
  expect_equal(attached$actual_winner[attached$match_id == "M73"], "Canada")
  expect_true(attached$actual_winner_continues[attached$match_id == "M73"])
  expect_false(attached$is_completed[attached$match_id == "M90"])

  later_attached <- attach_worldcup_bracket_actual_results(
    bracket_paths,
    matches_path = matches_path,
    result_cutoff_date = "2026-06-30",
    knockout_start_date = "2026-06-28"
  )
  expect_true(later_attached$is_completed[later_attached$match_id == "M73"])

  tied_matches_path <- tempfile(fileext = ".csv")
  write.csv(
    data.frame(
      date = "2026-06-29",
      home_team_canonical = "Germany",
      away_team_canonical = "Paraguay",
      home_score = 1,
      away_score = 1,
      actual_winner_team = "Paraguay",
      tournament = "FIFA World Cup",
      stringsAsFactors = FALSE
    ),
    tied_matches_path,
    row.names = FALSE
  )
  tied_bracket <- data.frame(
    round = "Round of 32",
    match_id = "M74",
    slot1_team = "Germany",
    slot1_display = "Germany",
    slot2_team = "Paraguay",
    slot2_display = "Paraguay",
    projected_winner_team = "Germany",
    projected_winner = "Germany",
    next_match_id = NA_character_,
    stringsAsFactors = FALSE
  )
  tied_attached <- attach_worldcup_bracket_actual_results(
    tied_bracket,
    matches_path = tied_matches_path,
    result_cutoff_date = "2026-06-30",
    knockout_start_date = "2026-06-28"
  )
  expect_true(tied_attached$is_completed)
  expect_equal(tied_attached$actual_score, "1-1")
  expect_equal(tied_attached$actual_winner_team, "Paraguay")
  expect_equal(tied_attached$actual_winner, "Paraguay")
})

test_that("dashboard data export includes probabilities, scorelines, and bracket paths", {
  source(file.path(project_root, "R/forecast/monte_carlo.R"))
  source(file.path(project_root, "R/forecast/tournament.R"))
  source(file.path(project_root, "R/release/release_bundle.R"))
  source(file.path(project_root, "R/release/release_install.R"))
  source(file.path(project_root, "R/release/release_contract.R"))
  source(file.path(project_root, "R/visualization/worldcup_dashboard.R"))

  groups <- load_worldcup_2026_groups(file.path(project_root, "data/raw/worldcup_2026_groups.csv"))
  elo_ratings_path <- tempfile(fileext = ".csv")
  output_dir <- tempfile("worldcup-dashboard-")

  write.csv(
    rbind(
      data.frame(
        date = as.Date(rep("2026-01-01", nrow(groups))),
        team = groups$team,
        rating = 1500 + seq_len(nrow(groups)),
        match_id = "seed",
        is_post_match = TRUE,
        stringsAsFactors = FALSE
      ),
      data.frame(
        date = as.Date("2026-06-12"),
        team = groups$team[1],
        rating = 1600,
        match_id = "M001",
        is_post_match = TRUE,
        stringsAsFactors = FALSE
      )
    ),
    elo_ratings_path,
    row.names = FALSE
  )

  payload <- build_worldcup_dashboard(
    groups_path = file.path(project_root, "data/raw/worldcup_2026_groups.csv"),
    schedule_path = file.path(project_root, "data/raw/worldcup_2026_group_fixtures.csv"),
    output_dir = output_dir,
    n_match_sim = 20,
    n_tournaments = 10,
    seed = 7,
    n_workers = 2,
    elo_current_path = elo_ratings_path,
    elo_ratings_path = elo_ratings_path,
    release_root = file.path(project_root, "outputs/releases")
  )

  expect_true(file.exists(payload$paths$data_json))
  expect_true(file.exists(payload$paths$html))
  pages_dir <- file.path(output_dir, "docs", "wc2026")
  pages_file <- publish_worldcup_dashboard_pages(
    data_json_path = payload$paths$data_json,
    pages_dir = pages_dir
  )
  expect_equal(normalizePath(pages_file), normalizePath(file.path(pages_dir, "index.html")))
  expect_true(file.exists(pages_file))
  expect_true(file.exists(file.path(output_dir, "docs", ".nojekyll")))
  expect_true(grepl("xGelo 2026 World Cup Forecast", paste(readLines(pages_file, warn = FALSE), collapse = "\n"), fixed = TRUE))
  expect_equal(nrow(payload$match_forecasts), 72)
  expect_true(all(c("kickoff_local", "venue_name", "host_city", "host_country") %in% names(payload$match_forecasts)))
  expect_true(all(c(
    "prematch_forecast_available",
    "prematch_win_probability",
    "prematch_draw_probability",
    "prematch_loss_probability",
    "prematch_home_goals_expected",
    "prematch_away_goals_expected"
  ) %in% names(payload$match_forecasts)))
  expect_true(file.exists(file.path(output_dir, "worldcup_prematch_forecasts.csv")))
  expect_true(file.exists(file.path(output_dir, "worldcup_bracket_prematch_forecasts.csv")))
  bracket_archive <- read.csv(file.path(output_dir, "worldcup_bracket_prematch_forecasts.csv"), stringsAsFactors = FALSE)
  expect_equal(nrow(bracket_archive), 33)
  expect_equal(bracket_archive$round[bracket_archive$match_id == "M103"], "Third-place play-off")
  expect_true(file.exists(file.path(output_dir, "worldcup_elo_evolution.csv")))
  expect_true(all(c("date", "team", "display_team", "group", "rating") %in% names(payload$elo_evolution)))
  expect_true(any(payload$elo_evolution$match_id == "M001"))
  expect_equal(length(unique(payload$scoreline_distributions$match_id)), 72)
  expect_equal(nrow(payload$group_probabilities), 48)
  expect_equal(sum(payload$group_probabilities$round_of_32_probability), 32, tolerance = 0.001)
  expect_equal(sum(payload$group_probabilities$third_place_qual_probability), 8, tolerance = 0.001)
  expect_true(all(c(
    "fifa_code",
    "position_1_probability",
    "position_2_probability",
    "position_3_probability",
    "position_4_probability"
  ) %in% names(payload$group_probabilities)))
  expect_equal(
    payload$group_probabilities$position_1_probability +
      payload$group_probabilities$position_2_probability +
      payload$group_probabilities$position_3_probability +
      payload$group_probabilities$position_4_probability,
    rep(1, nrow(payload$group_probabilities)),
    tolerance = 0.001
  )
  expect_true(all(payload$stage_probabilities$champion_probability >= 0))
  expect_true(all(payload$stage_probabilities$champion_probability <= 1))
  expect_gt(stats::sd(payload$stage_probabilities$rating), 0)
  expect_equal(sum(payload$stage_probabilities$round_of_32_probability), 32, tolerance = 0.001)
  expect_equal(sum(payload$stage_probabilities$round_of_16_probability), 16, tolerance = 0.001)
  expect_equal(sum(payload$stage_probabilities$quarterfinal_probability), 8, tolerance = 0.001)
  expect_equal(sum(payload$stage_probabilities$semifinal_probability), 4, tolerance = 0.001)
  expect_equal(sum(payload$stage_probabilities$final_probability), 2, tolerance = 0.001)
  expect_equal(sum(payload$champion_probabilities$champion_probability), 1, tolerance = 0.001)
  expect_equal(nrow(payload$bracket_paths), 33)
  expect_true(all(c("Round of 32", "Round of 16", "Quarter-finals", "Semi-finals", "Third-place play-off", "Final", "Champion") %in% payload$bracket_paths$round))
  expect_true(all(c(
    "projected_winner",
    "projected_winner_stage_probability",
    "projected_winner_match_probability",
    "projected_winner_regulation_probability",
    "projected_winner_extra_time_penalty_probability",
    "projected_winner_tiebreak_probability",
    "projected_winner_route_label",
    "slot1_expected_goals",
    "slot2_expected_goals",
    "most_likely_score",
    "most_likely_score_probability",
    "rounded_expected_score",
    "over_2_5_probability",
    "both_teams_to_score_probability",
    "top_scorelines_label",
    "projected_winner_title_probability",
    "next_match_id",
    "loser_next_match_id",
    "projected_winner_continues",
    "projected_champion_path",
    "is_completed",
    "match_status",
    "actual_match_date",
    "actual_slot1_goals",
    "actual_slot2_goals",
    "actual_score",
    "actual_winner_team",
    "actual_winner",
    "actual_winner_continues",
    "prematch_forecast_available",
    "prematch_projected_winner_match_probability",
    "prematch_slot1_expected_goals",
    "prematch_slot2_expected_goals",
    "prematch_most_likely_score",
    "prematch_top_scorelines_label",
    "slot1_advancement_probability",
    "slot2_advancement_probability",
    "slot1_regulation_win_probability",
    "slot1_extra_time_penalty_probability",
    "slot1_tiebreak_probability",
    "slot2_regulation_win_probability",
    "slot2_extra_time_penalty_probability",
    "slot2_tiebreak_probability",
    "draw_after_regulation_probability"
  ) %in% names(payload$bracket_paths)))
  expect_true("projected_position" %in% names(payload$group_probabilities))
  expect_true("projected_position" %in% names(payload$expected_group_tables))
  expect_true("display_position" %in% names(payload$group_probabilities))
  expect_true("display_position" %in% names(payload$expected_group_tables))
  for (group_id in unique(payload$group_probabilities$group)) {
    group_probs <- payload$group_probabilities[payload$group_probabilities$group == group_id, ]
    expect_equal(
      sort(group_probs$projected_position),
      1:4
    )
    expect_equal(
      sort(group_probs$display_position),
      1:4
    )
    group_table <- payload$expected_group_tables[payload$expected_group_tables$group == group_id, ]
    expect_equal(sort(group_table$projected_position), 1:4)
    expect_equal(group_table$display_position, 1:4)
    displayed_points <- floor(group_table$expected_points * 10 + 0.5) / 10
    expect_true(all(diff(displayed_points) <= 0))
    tied_rows <- which(diff(displayed_points) == 0)
    if (length(tied_rows) > 0) {
      sorted_probs <- group_probs[match(group_table$team, group_probs$team), ]
      expect_true(all(sorted_probs$group_win_probability[tied_rows] >= sorted_probs$group_win_probability[tied_rows + 1]))
    }
  }
  expect_false(any(is.na(payload$bracket_paths$projected_winner)))
  knockout_paths <- payload$bracket_paths[
    payload$bracket_paths$round != "Champion" &
      !is.na(payload$bracket_paths$slot1_team) &
      nzchar(payload$bracket_paths$slot1_team) &
      !is.na(payload$bracket_paths$slot2_team) &
      nzchar(payload$bracket_paths$slot2_team),
  ]
  expect_equal(payload$metadata$n_workers, normalise_dashboard_workers(2, 10))
  expect_equal(
    knockout_paths$slot1_advancement_probability + knockout_paths$slot2_advancement_probability,
    rep(1, nrow(knockout_paths)),
    tolerance = 0.001
  )
  expect_true(all(knockout_paths$projected_winner_match_probability >= 0.5))
  expect_true(all(knockout_paths$projected_winner_match_probability <= 1))
  expect_equal(
    knockout_paths$slot1_regulation_win_probability + knockout_paths$slot2_regulation_win_probability +
      knockout_paths$draw_after_regulation_probability,
    rep(1, nrow(knockout_paths)),
    tolerance = 0.001
  )
  expect_equal(
    knockout_paths$slot1_extra_time_penalty_probability + knockout_paths$slot2_extra_time_penalty_probability,
    knockout_paths$draw_after_regulation_probability,
    tolerance = 0.001
  )
  expect_equal(
    knockout_paths$slot1_tiebreak_probability + knockout_paths$slot2_tiebreak_probability,
    rep(1, nrow(knockout_paths)),
    tolerance = 0.001
  )
  expect_equal(
    knockout_paths$slot1_extra_time_penalty_probability,
    knockout_paths$draw_after_regulation_probability * knockout_paths$slot1_tiebreak_probability,
    tolerance = 0.001
  )
  expect_equal(
    knockout_paths$slot2_extra_time_penalty_probability,
    knockout_paths$draw_after_regulation_probability * knockout_paths$slot2_tiebreak_probability,
    tolerance = 0.001
  )
  expect_equal(
    knockout_paths$projected_winner_extra_time_penalty_probability,
    knockout_paths$draw_after_regulation_probability * knockout_paths$projected_winner_tiebreak_probability,
    tolerance = 0.001
  )
  expect_false(any(is.na(knockout_paths$projected_winner_route_label)))
  expect_true(any(grepl("90' win", knockout_paths$projected_winner_route_label, fixed = TRUE)))
  expect_true(any(grepl("90' draw", knockout_paths$projected_winner_route_label, fixed = TRUE)))
  expect_true(any(grepl("ET/pens share", knockout_paths$projected_winner_route_label, fixed = TRUE)))
  expect_false(any(is.na(knockout_paths$slot1_expected_goals)))
  expect_false(any(is.na(knockout_paths$slot2_expected_goals)))
  expect_true(all(knockout_paths$slot1_expected_goals >= 0))
  expect_true(all(knockout_paths$slot2_expected_goals >= 0))
  expect_false(any(is.na(knockout_paths$most_likely_score)))
  expect_true(all(knockout_paths$most_likely_score_probability > 0))
  expect_true(all(knockout_paths$most_likely_score_probability <= 1))
  expect_true(all(knockout_paths$over_2_5_probability >= 0 & knockout_paths$over_2_5_probability <= 1))
  expect_true(all(knockout_paths$both_teams_to_score_probability >= 0 & knockout_paths$both_teams_to_score_probability <= 1))
  expect_true(all(grepl("-", knockout_paths$top_scorelines_label, fixed = TRUE)))
  expect_equal(payload$bracket_paths$next_match_id[payload$bracket_paths$match_id == "M104"], "Champion")
  expect_equal(payload$bracket_paths$next_match_id[payload$bracket_paths$match_id %in% c("M101", "M102")], rep("M104", 2))
  expect_equal(payload$bracket_paths$loser_next_match_id[payload$bracket_paths$match_id %in% c("M101", "M102")], rep("M103", 2))
  expect_true(is.na(payload$bracket_paths$next_match_id[payload$bracket_paths$match_id == "M103"]))
  expect_true(is.na(payload$bracket_paths$loser_next_match_id[payload$bracket_paths$match_id == "M103"]))
  expect_false(payload$bracket_paths$projected_champion_path[payload$bracket_paths$match_id == "M103"])
  expect_true(payload$bracket_paths$projected_winner_continues[payload$bracket_paths$match_id == "M104"])
  expect_true(payload$bracket_paths$projected_champion_path[payload$bracket_paths$match_id == "M104"])
  expect_true(payload$bracket_paths$projected_champion_path[payload$bracket_paths$match_id == "Champion"])
  champion_team <- payload$bracket_paths$projected_winner_team[payload$bracket_paths$match_id == "Champion"]
  champion_path <- payload$bracket_paths[payload$bracket_paths$projected_champion_path, , drop = FALSE]
  expect_gte(nrow(champion_path), 2)
  expect_lte(nrow(champion_path), 6)
  expect_true(all(champion_path$projected_winner_team == champion_team))
  expect_equal(sum(!is.na(payload$bracket_paths$next_match_id)), 31)
  expect_lt(sum(payload$bracket_paths$projected_winner_continues), 31)
  expect_equal(
    payload$bracket_paths$projected_winner[payload$bracket_paths$match_id == "Champion"],
    payload$bracket_paths$projected_winner[payload$bracket_paths$match_id == "M104"]
  )
  round32 <- payload$bracket_paths[payload$bracket_paths$round == "Round of 32", ]
  expect_true(all(round32$next_match_id %in% paste0("M", 89:96)))
  expect_equal(length(unique(c(round32$slot1_team, round32$slot2_team))), 32)

  html <- paste(readLines(payload$paths$html, warn = FALSE), collapse = "\n")
  expect_true(grepl("xGelo 2026 World Cup Forecast", html, fixed = TRUE))
  expect_true(grepl("Built from ${intFmt(data.metadata.n_match_sim)} match simulations", html, fixed = TRUE))
  expect_true(grepl("Created by <a href=\"https://github.com/DavidZenz\"", html, fixed = TRUE))
  expect_true(grepl("rel=\"noopener\"", html, fixed = TRUE))
  expect_true(grepl("title-chance-row", html, fixed = TRUE))
  expect_true(grepl("title-chance-pct", html, fixed = TRUE))
  expect_true(grepl(
    "champion_probabilities.filter(r => Number(r.champion_probability) > 0).slice(0,3)",
    html,
    fixed = TRUE
  ))
  expect_true(grepl(
    "finalSourceIds.length === 2 && finalSourceIds.every(matchId => bracketMatchIsCompleted",
    html,
    fixed = TRUE
  ))
  expect_true(grepl('{label:"Final fixed", value:finalTeams, note:"Finalists confirmed"}', html, fixed = TRUE))
  expect_true(grepl('{label:"Likely final", value:finalTeams, note:"Highest final probabilities"}', html, fixed = TRUE))
  expect_true(grepl(
    'const confirmedChampion = bracketMatchIsCompleted(finalPath) ? actualBracketWinnerName(finalPath) : "";',
    html,
    fixed = TRUE
  ))
  expect_true(grepl('{label:"Winner", value:confirmedChampion, note:"Tournament champion"}', html, fixed = TRUE))
  expect_true(grepl('{label:"Top title chances", valueHtml:', html, fixed = TRUE))
  expect_true(grepl("const groupStageComplete = completedCount >= 72 && currentGroupRows.length > 0;", html, fixed = TRUE))
  expect_true(grepl('{label:"Best group-stage record", value:', html, fixed = TRUE))
  expect_true(grepl('{label:"Closest group finish", value:', html, fixed = TRUE))
  expect_true(grepl('"Decided on goal difference"', html, fixed = TRUE))
  expect_true(grepl("const fourthMetric = groupStageComplete", html, fixed = TRUE))
  expect_true(grepl("const fifthMetric = groupStageComplete", html, fixed = TRUE))
  expect_true(grepl("Data Credits", html, fixed = TRUE))
  expect_true(grepl("https://github.com/martj42/international_results", html, fixed = TRUE))
  expect_true(grepl("https://github.com/statsbomb/open-data", html, fixed = TRUE))
  expect_true(grepl("StatsBomb Open Data", html, fixed = TRUE))
  expect_true(grepl("manually maintained in this repository", html, fixed = TRUE))
  expect_true(grepl("xPts<br>Avg", html, fixed = TRUE))
  expect_true(grepl("Elo Ratings", html, fixed = TRUE))
  expect_true(grepl("renderEloRatings", html, fixed = TRUE))
  expect_true(grepl("renderEloEvolution", html, fixed = TRUE))
  expect_true(grepl("eloEvolution", html, fixed = TRUE))
  expect_true(grepl("Elo evolution line-step plot", html, fixed = TRUE))
  expect_true(grepl("elo-step-line", html, fixed = TRUE))
  expect_true(grepl("toggleEloEvolutionTeam", html, fixed = TRUE))
  expect_true(grepl("elo-hit-line", html, fixed = TRUE))
  expect_true(grepl("eloEvolutionSelectedTeams", html, fixed = TRUE))
  expect_true(grepl("const selectedRatings = ratings;", html, fixed = TRUE))
  expect_true(grepl("elo-evolution-body", html, fixed = TRUE))
  expect_true(grepl("elo-picker-row", html, fixed = TRUE))
  expect_true(grepl("elo-gain-label", html, fixed = TRUE))
  expect_true(grepl("const gain = Math.round(point.rating - previous.rating);", html, fixed = TRUE))
  expect_true(grepl("const resultingRating = Math.round(point.rating);", html, fixed = TRUE))
  expect_true(grepl("teams by current Elo", html, fixed = TRUE))
  expect_true(grepl("Ratings are the Elo values used by the tournament simulation snapshot", html, fixed = TRUE))
  expect_true(grepl("<th>R32</th><th>R16</th><th>QF</th><th>HF</th><th>F</th><th>Title</th>", html, fixed = TRUE))
  expect_true(grepl("elo-prob-cell", html, fixed = TRUE))
  expect_true(grepl("stageMax", html, fixed = TRUE))
  expect_true(grepl("3rd<br>Top 8", html, fixed = TRUE))
  expect_true(grepl("heat-cell", html, fixed = TRUE))
  expect_true(grepl("heat-cell.empty", html, fixed = TRUE))
  expect_true(grepl("rounded === 0", html, fixed = TRUE))
  expect_true(grepl("team-flag", html, fixed = TRUE))
  expect_true(grepl("status-cell", html, fixed = TRUE))
  expect_true(grepl("aria-label=\"Status\"", html, fixed = TRUE))
  expect_false(grepl("team-code", html, fixed = TRUE))
  expect_true(grepl("--prob:", html, fixed = TRUE))
  expect_true(grepl("position_1_probability", html, fixed = TRUE))
  expect_true(grepl("Locked group winners", html, fixed = TRUE))
  expect_true(grepl("Strongest unresolved favorite", html, fixed = TRUE))
  expect_true(grepl("Strongest qualified favorite", html, fixed = TRUE))
  expect_true(grepl("allGroupsHaveQualifier", html, fixed = TRUE))
  expect_true(grepl("qualifiedThreshold", html, fixed = TRUE))
  expect_true(grepl("lockedThreshold", html, fixed = TRUE))
  expect_true(grepl("Closest group-win race", html, fixed = TRUE))
  expect_true(grepl("Leader margin", html, fixed = TRUE))
  expect_true(grepl("Win spread", html, fixed = TRUE))
  expect_true(grepl("Completed World Cup group matches are fixed at their actual scores", html, fixed = TRUE))
  expect_true(grepl("remaining fixtures are simulated", html, fixed = TRUE))
  expect_true(grepl("All matches", html, fixed = TRUE))
  expect_true(grepl("Knockout phase", html, fixed = TRUE))
  expect_true(grepl("knockoutMatchRows", html, fixed = TRUE))
  expect_true(grepl("Projected knockout phase", html, fixed = TRUE))
  expect_true(grepl("Top exact 90 min scorelines", html, fixed = TRUE))
  expect_true(grepl("advance ${pct(r.slot1_advancement_probability)}", html, fixed = TRUE))
  expect_true(grepl("match-divider", html, fixed = TRUE))
  expect_true(grepl("Decided matches", html, fixed = TRUE))
  expect_true(grepl("upcomingRows", html, fixed = TRUE))
  expect_true(grepl("completedRows", html, fixed = TRUE))
  expect_true(grepl("Expected goals", html, fixed = TRUE))
  expect_true(grepl("chip primary", html, fixed = TRUE))
  expect_true(grepl("Rounded goals", html, fixed = TRUE))
  expect_true(grepl("Top exact scorelines", html, fixed = TRUE))
  expect_true(grepl("Top exact score", html, fixed = TRUE))
  expect_true(grepl("scoreline-bar", html, fixed = TRUE))
  expect_true(grepl("scoreline-fill", html, fixed = TRUE))
  expect_true(grepl("Projected winner", html, fixed = TRUE))
  expect_true(grepl("Projected tournament path", html, fixed = TRUE))
  expect_true(grepl("Projected advance", html, fixed = TRUE))
  expect_true(grepl("Projected exit", html, fixed = TRUE))
  expect_true(grepl("projected_position", html, fixed = TRUE))
  expect_true(grepl("display_position", html, fixed = TRUE))
  expect_true(grepl("final scores are tournament state", html, fixed = TRUE))
  expect_true(grepl("data-champion-path", html, fixed = TRUE))
  expect_true(grepl("data-match-probability", html, fixed = TRUE))
  expect_true(grepl("data-route-label", html, fixed = TRUE))
  expect_true(grepl("bracket-inspector", html, fixed = TRUE))
  expect_true(grepl("Bracket match details", html, fixed = TRUE))
  expect_true(grepl("data-slot1-team", html, fixed = TRUE))
  expect_true(grepl("data-slot2-team", html, fixed = TRUE))
  expect_true(grepl("data-projected-winner-team", html, fixed = TRUE))
  expect_true(grepl("data-has-detail", html, fixed = TRUE))
  expect_true(grepl("Click for forecast", html, fixed = TRUE))
  expect_true(grepl("bracketForecastDetailHtml", html, fixed = TRUE))
  expect_true(grepl("selectBracketMatch", html, fixed = TRUE))
  expect_true(grepl("setBracketHoverTeam", html, fixed = TRUE))
  expect_true(grepl("clearBracketHoverTeam", html, fixed = TRUE))
  expect_true(grepl("selectedBracketPathTeam", html, fixed = TRUE))
  expect_true(grepl("Selected highlight", html, fixed = TRUE))
  expect_true(grepl("bindBracketInteractions", html, fixed = TRUE))
  expect_true(grepl("bindBracketInspectorDismissal", html, fixed = TRUE))
  expect_true(grepl("isBracketMatchClickTarget", html, fixed = TRUE))
  expect_false(grepl("bracket-inspector-close", html, fixed = TRUE))
  expect_true(grepl("hover-path", html, fixed = TRUE))
  expect_true(grepl("entersNext", html, fixed = TRUE))
  expect_true(grepl("next.dataset.slot1Team", html, fixed = TRUE))
  expect_true(grepl("bracket-team-target", html, fixed = TRUE))
  expect_true(grepl("grid-template-rows:repeat(39,64px)", html, fixed = TRUE))
  expect_true(grepl('"Third-place play-off": 5', html, fixed = TRUE))
  expect_true(grepl("data-loser-next-match-id", html, fixed = TRUE))
  expect_true(grepl('data-outcome="loser"', html, fixed = TRUE))
  expect_true(grepl("projectedOutcomeTeam", html, fixed = TRUE))
  expect_true(grepl("Most likely wins third place", html, fixed = TRUE))
  expect_true(grepl("Projected third-place winner", html, fixed = TRUE))
  expect_true(grepl("Projected fourth place", html, fixed = TRUE))
  expect_true(grepl("won third place", html, fixed = TRUE))
  expect_true(grepl("bracket-flag", html, fixed = TRUE))
  expect_true(grepl("bracket-flag code", html, fixed = TRUE))
  expect_true(grepl("registerTeamMeta", html, fixed = TRUE))
  expect_true(grepl("(data.groups || []).forEach(registerTeamMeta)", html, fixed = TRUE))
  expect_true(grepl("teamMetaFor", html, fixed = TRUE))
  expect_true(grepl("teamLabel", html, fixed = TRUE))
  expect_true(grepl("hasBracketPrematchForecast", html, fixed = TRUE))
  expect_true(grepl("Pre-game forecast", html, fixed = TRUE))
  expect_true(grepl("Pre-game pick", html, fixed = TRUE))
  expect_true(grepl("scoreTileGrid", html, fixed = TRUE))
  expect_true(grepl("score-tile-grid", html, fixed = TRUE))
  expect_true(grepl("score-tile-prob", html, fixed = TRUE))
  expect_true(grepl("score-tile-score", html, fixed = TRUE))
  expect_true(grepl("tooltip-title-team slot1", html, fixed = TRUE))
  expect_true(grepl("tooltip-title-team slot2", html, fixed = TRUE))
  expect_true(grepl("tooltip-legend-title", html, fixed = TRUE))
  expect_true(grepl("tooltip-legend", html, fixed = TRUE))
  expect_true(grepl("legend-dot slot1", html, fixed = TRUE))
  expect_true(grepl("legend-dot draw", html, fixed = TRUE))
  expect_true(grepl("legend-dot slot2", html, fixed = TRUE))
  expect_true(grepl(".tooltip-advance-row.slot1", html, fixed = TRUE))
  expect_true(grepl(".tooltip-advance-row.slot2", html, fixed = TRUE))
  expect_true(grepl("[\"slot1\", g.slot1_team", html, fixed = TRUE))
  expect_true(grepl("[\"slot2\", g.slot2_team", html, fixed = TRUE))
  expect_true(grepl("90 min score colors", html, fixed = TRUE))
  expect_true(grepl("Most likely advances", html, fixed = TRUE))
  expect_true(grepl("Advance probability", html, fixed = TRUE))
  expect_false(grepl("bracket-tooltip-portal", html, fixed = TRUE))
  expect_false(grepl("setupBracketTooltipPortal", html, fixed = TRUE))
  expect_false(grepl("positionBracketTooltipPortal", html, fixed = TRUE))
  expect_true(grepl("padding:34px 20px 30px", html, fixed = TRUE))
  expect_false(grepl("padding:34px 20px 420px", html, fixed = TRUE))
  expect_false(grepl("mouseover", html, fixed = TRUE))
  expect_false(grepl("cursor:help", html, fixed = TRUE))
  expect_true(grepl("keydown", html, fixed = TRUE))
  expect_true(grepl("tabindex", html, fixed = TRUE))
  expect_true(grepl('tabindex="0"', html, fixed = TRUE))
  expect_false(grepl("tabindex=\"0\"\" : \"\"", html, fixed = TRUE))
  expect_false(grepl("z-index:100000", html, fixed = TRUE))
  expect_false(grepl(".has-bracket-tooltip:hover>.bracket-tooltip", html, fixed = TRUE))
  expect_false(grepl("has-bracket-tooltip", html, fixed = TRUE))
  expect_false(grepl("data-has-tooltip", html, fixed = TRUE))
  expect_false(grepl("data-tooltip=\"", html, fixed = TRUE))
  expect_false(grepl(".has-tooltip::after", html, fixed = TRUE))
  expect_true(grepl("title=\"Click for forecast\"", html, fixed = TRUE))
  expect_false(grepl("data-source-match-id=\"${esc(slot1Source)}\"${tooltipHtml}", html, fixed = TRUE))
  expect_false(grepl("data-source-match-id=\"${esc(slot2Source)}\"${tooltipHtml}", html, fixed = TRUE))
  expect_true(grepl("ET/pens share", html, fixed = TRUE))
  expect_true(grepl("If ET/pens:", html, fixed = TRUE))
  expect_true(grepl("tooltip-pill et-split", html, fixed = TRUE))
  expect_true(grepl("tooltip-et-dot slot1", html, fixed = TRUE))
  expect_true(grepl("tooltip-et-dot slot2", html, fixed = TRUE))
  expect_true(grepl("tooltip-et-team slot1", html, fixed = TRUE))
  expect_true(grepl("tooltip-et-team slot2", html, fixed = TRUE))
  expect_true(grepl("Top exact 90 min scores", html, fixed = TRUE))
  expect_true(grepl("90 min mean goals", html, fixed = TRUE))
  expect_true(grepl("90 min draw", html, fixed = TRUE))
  expect_true(grepl("top_scorelines_label", html, fixed = TRUE))
  expect_false(grepl('join("\\n")', html, fixed = TRUE))
  expect_false(grepl('join("\\n\\n")', html, fixed = TRUE))
  expect_false(grepl("join(\"\n\")", html, fixed = TRUE))
  expect_false(grepl("join(\"\n\n\")", html, fixed = TRUE))
  expect_true(grepl("full tournament sims", html, fixed = TRUE))
  expect_true(grepl("bracket-link-svg", html, fixed = TRUE))
  expect_true(grepl("bracket-link-label", html, fixed = TRUE))
  expect_true(grepl("data-projected-winner", html, fixed = TRUE))
  expect_true(grepl("data-source-match-id", html, fixed = TRUE))
  expect_true(grepl("bracket-slot-target", html, fixed = TRUE))
  expect_true(grepl("Estadio Azteca", html, fixed = TRUE))
  for (group_id in LETTERS[1:12]) {
    expect_true(grepl(paste0("Group ", group_id), html, fixed = TRUE))
  }
})
