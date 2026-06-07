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
  expect_equal(length(unique(payload$scoreline_distributions$match_id)), 72)
  expect_equal(nrow(payload$group_probabilities), 48)
  expect_equal(sum(payload$group_probabilities$round_of_32_probability), 32, tolerance = 0.001)
  expect_equal(sum(payload$group_probabilities$third_place_qual_probability), 8, tolerance = 0.001)
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
  expect_false(any(is.na(payload$bracket_paths$projected_winner)))
  knockout_paths <- payload$bracket_paths[
    payload$bracket_paths$round != "Champion" &
      !is.na(payload$bracket_paths$slot1_team) &
      nzchar(payload$bracket_paths$slot1_team) &
      !is.na(payload$bracket_paths$slot2_team) &
      nzchar(payload$bracket_paths$slot2_team),
  ]
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
  expect_true(grepl("Rounded xG", html, fixed = TRUE))
  expect_true(grepl("Top exact scorelines", html, fixed = TRUE))
  expect_true(grepl("Top exact score", html, fixed = TRUE))
  expect_true(grepl("scoreline-bar", html, fixed = TRUE))
  expect_true(grepl("scoreline-fill", html, fixed = TRUE))
  expect_true(grepl("Projected winner", html, fixed = TRUE))
  expect_true(grepl("data-match-probability", html, fixed = TRUE))
  expect_true(grepl("data-route-label", html, fixed = TRUE))
  expect_true(grepl("data-tooltip-detail", html, fixed = TRUE))
  expect_true(grepl("has-tooltip", html, fixed = TRUE))
  expect_true(grepl(".bracket-game.has-tooltip:hover,.bracket-link-label.has-tooltip:hover{z-index:120}", html, fixed = TRUE))
  expect_true(grepl(".has-tooltip::after{content:attr(data-tooltip);display:none;position:absolute;left:0;top:calc(100% + 8px);z-index:130", html, fixed = TRUE))
  expect_false(grepl("title=\"", html, fixed = TRUE))
  expect_false(grepl("label.title", html, fixed = TRUE))
  expect_false(grepl("data-source-match-id=\"${esc(slot1Source)}\"${tooltipAttr}", html, fixed = TRUE))
  expect_false(grepl("data-source-match-id=\"${esc(slot2Source)}\"${tooltipAttr}", html, fixed = TRUE))
  expect_true(grepl("ET/pens share", html, fixed = TRUE))
  expect_true(grepl("If ET/pens:", html, fixed = TRUE))
  expect_true(grepl("90-minute scoring", html, fixed = TRUE))
  expect_true(grepl("Projected goals", html, fixed = TRUE))
  expect_true(grepl("Top scorelines", html, fixed = TRUE))
  expect_true(grepl('join("\\n")', html, fixed = TRUE))
  expect_true(grepl('join("\\n\\n")', html, fixed = TRUE))
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
