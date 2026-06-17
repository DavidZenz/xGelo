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
  always_slot1_route <- function(team1, team2) {
    route_calls <<- route_calls + 1
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

  expect_equal(route_calls, 31)
  expect_equal(reachers$champion, "E1")
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
      date = as.Date("2026-06-11"),
      home_team_canonical = "Mexico",
      away_team_canonical = "South Africa",
      home_score = 2,
      away_score = 0,
      tournament = "FIFA World Cup",
      stringsAsFactors = FALSE
    ),
    results_path,
    row.names = FALSE
  )

  fixtures <- attach_worldcup_actual_results(
    fixtures = fixtures,
    matches_path = results_path,
    result_cutoff_date = as.Date("2026-06-12")
  )
  opener <- fixtures[fixtures$match_id == "GA01", ]
  expect_true(opener$is_completed)
  expect_equal(opener$match_status, "final")
  expect_equal(opener$actual_score, "2-0")

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

test_that("dashboard data export includes probabilities, scorelines, and bracket paths", {
  source(file.path(project_root, "R/forecast/monte_carlo.R"))
  source(file.path(project_root, "R/forecast/tournament.R"))
  source(file.path(project_root, "R/visualization/worldcup_dashboard.R"))

  groups <- load_worldcup_2026_groups(file.path(project_root, "data/raw/worldcup_2026_groups.csv"))
  home_model_path <- tempfile(fileext = ".rds")
  away_model_path <- tempfile(fileext = ".rds")
  elo_ratings_path <- tempfile(fileext = ".csv")
  output_dir <- tempfile("worldcup-dashboard-")

  saveRDS(structure(list(lambda = 0.6), class = "constant_goal_model"), home_model_path)
  saveRDS(structure(list(lambda = 0.4), class = "constant_goal_model"), away_model_path)
  write.csv(
    data.frame(
      date = as.Date(rep("2026-01-01", nrow(groups))),
      team = groups$team,
      rating = 1500 + seq_len(nrow(groups)),
      is_post_match = TRUE,
      stringsAsFactors = FALSE
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
    home_model_path = home_model_path,
    away_model_path = away_model_path,
    elo_ratings_path = elo_ratings_path
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
  expect_true(all(c("Round of 32", "Round of 16", "Quarter-finals", "Semi-finals", "Final", "Champion") %in% payload$bracket_paths$round))
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
    "projected_winner_continues",
    "projected_champion_path",
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
  for (group_id in unique(payload$group_probabilities$group)) {
    expect_equal(
      sort(payload$group_probabilities$projected_position[payload$group_probabilities$group == group_id]),
      1:4
    )
    group_table <- payload$expected_group_tables[payload$expected_group_tables$group == group_id, ]
    expect_equal(group_table$projected_position, 1:4)
    expect_true(all(diff(group_table$expected_points) <= 0))
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
  expect_true(grepl("Data Credits", html, fixed = TRUE))
  expect_true(grepl("https://github.com/martj42/international_results", html, fixed = TRUE))
  expect_true(grepl("https://github.com/statsbomb/open-data", html, fixed = TRUE))
  expect_true(grepl("StatsBomb Open Data", html, fixed = TRUE))
  expect_true(grepl("manually maintained in this repository", html, fixed = TRUE))
  expect_true(grepl("xPts<br>Avg", html, fixed = TRUE))
  expect_true(grepl("3rd<br>Top 8", html, fixed = TRUE))
  expect_true(grepl("heat-cell", html, fixed = TRUE))
  expect_true(grepl("team-flag", html, fixed = TRUE))
  expect_false(grepl("team-code", html, fixed = TRUE))
  expect_true(grepl("--prob:", html, fixed = TRUE))
  expect_true(grepl("position_1_probability", html, fixed = TRUE))
  expect_true(grepl("Closest group-win race", html, fixed = TRUE))
  expect_true(grepl("Leader margin", html, fixed = TRUE))
  expect_true(grepl("Win spread", html, fixed = TRUE))
  expect_true(grepl("Completed World Cup group matches are fixed at their actual scores", html, fixed = TRUE))
  expect_true(grepl("remaining fixtures are simulated", html, fixed = TRUE))
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
  expect_true(grepl("bindBracketInteractions", html, fixed = TRUE))
  expect_true(grepl("hover-path", html, fixed = TRUE))
  expect_true(grepl("entersNext", html, fixed = TRUE))
  expect_true(grepl("next.dataset.slot1Team", html, fixed = TRUE))
  expect_true(grepl("bracket-team-target", html, fixed = TRUE))
  expect_true(grepl("hasBracketPrematchForecast", html, fixed = TRUE))
  expect_true(grepl("Pre-game forecast", html, fixed = TRUE))
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
  expect_true(grepl("[\"slot1\", slot1Name", html, fixed = TRUE))
  expect_true(grepl("[\"slot2\", slot2Name", html, fixed = TRUE))
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
