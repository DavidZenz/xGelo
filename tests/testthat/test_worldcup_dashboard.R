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
  expect_equal(nrow(payload$match_forecasts), 72)
  expect_true(all(c("kickoff_local", "venue_name", "host_city", "host_country") %in% names(payload$match_forecasts)))
  expect_equal(length(unique(payload$scoreline_distributions$match_id)), 72)
  expect_equal(nrow(payload$group_probabilities), 48)
  expect_equal(sum(payload$group_probabilities$round_of_32_probability), 32, tolerance = 0.001)
  expect_equal(sum(payload$group_probabilities$third_place_qual_probability), 8, tolerance = 0.001)
  expect_true(all(payload$stage_probabilities$champion_probability >= 0))
  expect_true(all(payload$stage_probabilities$champion_probability <= 1))
  expect_equal(sum(payload$champion_probabilities$champion_probability), 1, tolerance = 0.001)
  expect_true(all(c("Round of 32", "Round of 16", "Quarter-finals", "Semi-finals", "Final", "Champion") %in% payload$bracket_paths$round))

  html <- paste(readLines(payload$paths$html, warn = FALSE), collapse = "\n")
  expect_true(grepl("xGelo 2026 World Cup Forecast", html, fixed = TRUE))
  expect_true(grepl("Most likely", html, fixed = TRUE))
  expect_true(grepl("Rounded xG", html, fixed = TRUE))
  expect_true(grepl("Estadio Azteca", html, fixed = TRUE))
  for (group_id in LETTERS[1:12]) {
    expect_true(grepl(paste0("Group ", group_id), html, fixed = TRUE))
  }
})
