# xGelo v2 Feature and Benchmark Tests

context("Transfermarkt and EURO 2024 benchmark")

project_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))

test_that("Transfermarkt valuation lookup is strictly as-of", {
  source(file.path(project_root, "R/transfermarkt/squad_strength.R"))

  valuations <- data.frame(
    player_id = c(1, 1, 1, 2),
    date = as.Date(c("2024-01-01", "2024-06-14", "2024-07-01", "2024-06-13")),
    market_value_in_eur = c(10, 99, 100, 20),
    stringsAsFactors = FALSE
  )

  latest <- latest_player_valuations_as_of(valuations, as.Date("2024-06-14"))
  expect_equal(nrow(latest), 2)
  expect_equal(latest$market_value_in_eur[latest$player_id == 1], 10)
  expect_equal(latest$market_value_in_eur[latest$player_id == 2], 20)
  expect_false(any(latest$date >= as.Date("2024-06-14")))
})

test_that("Transfermarkt squad aggregation reports top values and missing share", {
  source(file.path(project_root, "R/transfermarkt/squad_strength.R"))

  squad <- data.frame(
    team = rep("A", 12),
    player_id = 1:12,
    date_of_birth = as.Date(rep("2000-01-01", 12)),
    international_caps = 1:12,
    international_goals = rep(1, 12),
    stringsAsFactors = FALSE
  )
  valuations <- data.frame(
    player_id = 1:12,
    date = as.Date(c(rep("2024-01-01", 11), "2024-07-01")),
    market_value_in_eur = c(12:2, 100) * 1000000,
    stringsAsFactors = FALSE
  )

  features <- compute_squad_strength_as_of(squad, valuations, as.Date("2024-06-14"))
  expect_equal(nrow(features), 1)
  expect_equal(features$num_players_with_value, 11)
  expect_equal(features$top11_value, sum(2:12) * 1000000)
  expect_equal(features$top15_value, features$top11_value)
  expect_equal(features$missing_value_share, 1 / 12)
  expect_lt(features$feature_source_date, as.Date("2024-06-14"))
})

test_that("Transfermarkt aggregation ignores current player market values", {
  source(file.path(project_root, "R/transfermarkt/squad_strength.R"))

  squad <- data.frame(
    team = "A",
    player_id = 1,
    market_value_in_eur = 999000000,
    position = "Attack",
    stringsAsFactors = FALSE
  )
  valuations <- data.frame(
    player_id = 1,
    date = as.Date("2024-01-01"),
    market_value_in_eur = 1000000,
    stringsAsFactors = FALSE
  )

  features <- compute_squad_strength_as_of(squad, valuations, as.Date("2024-06-14"))
  expect_equal(features$squad_value, 1000000)
  expect_equal(features$attack_value, 1000000)
  expect_equal(features$log_attack_value, log1p(1000000))
})

test_that("Transfermarkt aggregation derives positional, depth, age, and momentum features", {
  source(file.path(project_root, "R/transfermarkt/squad_strength.R"))

  squad <- data.frame(
    team = rep("A", 5),
    player_id = 1:5,
    date_of_birth = as.Date(c("1990-01-01", "1998-01-01", "2003-01-01", "2001-01-01", "1988-01-01")),
    position = c("Goalkeeper", "Defender", "Midfield", "Attack", "Attack"),
    stringsAsFactors = FALSE
  )
  valuations <- data.frame(
    player_id = rep(1:5, each = 2),
    date = rep(as.Date(c("2023-06-01", "2024-01-01")), 5),
    market_value_in_eur = c(1, 2, 2, 4, 3, 6, 4, 8, 5, 10) * 1000000,
    stringsAsFactors = FALSE
  )

  features <- compute_squad_strength_as_of(squad, valuations, as.Date("2024-06-14"))
  expect_equal(features$goalkeeper_value, 2000000)
  expect_equal(features$defense_value, 4000000)
  expect_equal(features$midfield_value, 6000000)
  expect_equal(features$attack_value, 18000000)
  expect_equal(features$top5_value_share, 1)
  expect_equal(features$top11_to_top23_ratio, 1)
  expect_gt(features$squad_value_momentum_12m, 0)
  expect_true("value_weighted_avg_age" %in% names(features))
})

test_that("goal ability excludes matches on or after the cutoff", {
  source(file.path(project_root, "R/forecast/goal_ability.R"))

  matches <- data.frame(
    date = as.Date(c("2024-01-01", "2024-06-14", "2024-06-15")),
    home_team_canonical = c("A", "A", "A"),
    away_team_canonical = c("B", "B", "B"),
    home_score = c(1, 10, 10),
    away_score = c(0, 0, 0),
    tournament = c("Friendly", "UEFA Euro", "UEFA Euro"),
    stringsAsFactors = FALSE
  )

  ability <- compute_weighted_goal_ability(matches, as.Date("2024-06-14"))
  expect_true(all(ability$feature_source_date < as.Date("2024-06-14")))
  expect_equal(ability$ability_match_count[ability$team == "A"], 1)
  expect_equal(ability$attack_ability[ability$team == "A"], 2)
})

test_that("EURO 2024 selector finds the checked-in 51 match holdout", {
  source(file.path(project_root, "R/benchmark/euro2024.R"))
  matches <- read.csv(file.path(project_root, "data/processed/elo_matches.csv"), stringsAsFactors = FALSE)
  euro <- select_euro2024_matches(matches)
  expect_equal(nrow(euro), 51)
  expect_true(all(as.Date(euro$date) >= as.Date("2024-06-14")))
  expect_true(all(as.Date(euro$date) <= as.Date("2024-07-14")))
})

test_that("EURO 2024 third-place pairing table matches actual CDEF bracket", {
  source(file.path(project_root, "R/benchmark/euro2024_tournament.R"))

  pairing <- euro_third_place_pairing_table()
  cdef <- pairing[pairing$combo == "CDEF", , drop = FALSE]
  expect_equal(nrow(cdef), 1)
  expect_equal(cdef$vs_1B, "F")
  expect_equal(cdef$vs_1C, "E")
  expect_equal(cdef$vs_1E, "D")
  expect_equal(cdef$vs_1F, "C")
})

test_that("synthetic EURO benchmark outputs baseline and hybrid metrics", {
  source(file.path(project_root, "R/forecast/features.R"))
  source(file.path(project_root, "R/forecast/goal_ability.R"))
  source(file.path(project_root, "R/forecast/poisson.R"))
  source(file.path(project_root, "R/benchmark/euro2024.R"))

  teams <- c("A", "B", "C", "D")
  training <- data.frame(
    date = as.Date("2023-01-01") + 1:40,
    home_team_canonical = rep(teams, 10),
    away_team_canonical = rep(rev(teams), 10),
    home_score = rep(c(2, 1, 0, 1), 10),
    away_score = rep(c(0, 1, 2, 0), 10),
    tournament = rep("Friendly", 40),
    neutral = rep(FALSE, 40),
    stringsAsFactors = FALSE
  )
  holdout <- data.frame(
    date = as.Date("2024-06-14") + rep(0:16, each = 3)[1:51],
    home_team_canonical = rep(teams, length.out = 51),
    away_team_canonical = rep(rev(teams), length.out = 51),
    home_score = rep(c(1, 1, 0), 17),
    away_score = rep(c(0, 1, 1), 17),
    tournament = rep("UEFA Euro", 51),
    neutral = rep(TRUE, 51),
    stringsAsFactors = FALSE
  )
  matches <- rbind(training, holdout)
  elo <- data.frame(
    date = rep(as.Date("2022-12-31"), length(teams)),
    team = teams,
    rating = c(1600, 1500, 1450, 1400),
    is_post_match = TRUE,
    stringsAsFactors = FALSE
  )

  matches_path <- tempfile(fileext = ".csv")
  elo_path <- tempfile(fileext = ".csv")
  out_dir <- tempfile("euro-benchmark-")
  write.csv(matches, matches_path, row.names = FALSE)
  write.csv(elo, elo_path, row.names = FALSE)

  result <- suppressWarnings(run_euro2024_benchmark(
    matches_path = matches_path,
    elo_ratings_path = elo_path,
    rolling_form_path = tempfile(fileext = ".csv"),
    squad_strength_path = tempfile(fileext = ".csv"),
    output_dir = out_dir
  ))

  expect_equal(result$holdout_rows, 51)
  expect_equal(sort(result$metrics$model), c("baseline", "hybrid"))
  expect_true(all(c("multiclass_brier", "log_loss", "ranked_probability_score") %in% names(result$metrics)))
  expect_true(all(as.Date(result$predictions$feature_source_date) < as.Date("2024-06-14")))
  expect_true(file.exists(file.path(out_dir, "euro2024_metrics.csv")))
})

test_that("WC2026 feature builder creates group and ordered knockout rows without leakage", {
  source(file.path(project_root, "R/forecast/features.R"))
  source(file.path(project_root, "R/forecast/goal_ability.R"))

  groups <- data.frame(
    team = c("A", "B", "C"),
    stringsAsFactors = FALSE
  )
  fixtures <- data.frame(
    match_id = "G1",
    date = as.Date("2026-06-11"),
    home_team = "A",
    away_team = "B",
    venue = "neutral",
    stringsAsFactors = FALSE
  )
  history <- data.frame(
    date = as.Date(c("2025-01-01", "2025-02-01")),
    home_team_canonical = c("A", "B"),
    away_team_canonical = c("B", "C"),
    home_score = c(2, 1),
    away_score = c(0, 1),
    tournament = "Friendly",
    stringsAsFactors = FALSE
  )
  elo <- data.frame(
    date = rep(as.Date("2026-06-01"), 3),
    team = c("A", "B", "C"),
    rating = c(1600, 1500, 1400),
    stringsAsFactors = FALSE
  )
  squad <- data.frame(
    team = c("A", "B", "C"),
    as_of_date = rep(as.Date("2026-06-10"), 3),
    feature_source_date = rep(as.Date("2026-06-09"), 3),
    log_squad_value = c(10, 9, 8),
    log_top11_value = c(9, 8, 7),
    stringsAsFactors = FALSE
  )

  features <- build_worldcup_forecast_feature_table(
    groups = groups,
    fixtures = fixtures,
    history_matches = history,
    elo_ratings = elo,
    squad_strength = squad,
    feature_cutoff_date = as.Date("2026-06-10")
  )

  expect_equal(nrow(features), 7)
  expect_true(all(as.Date(features$feature_source_date) < as.Date(features$date)))
  assert_worldcup_forecast_features(
    features,
    fixtures = fixtures,
    teams = groups$team,
    predictors = c("elo_diff", "attack_ability_diff", "log_squad_value_diff")
  )
})

test_that("WC2026 squad lookup canonicalizes Transfermarkt country aliases", {
  source(file.path(project_root, "R/forecast/features.R"))

  matches <- data.frame(
    date = as.Date("2026-06-11"),
    home_team_canonical = "Korea Republic",
    away_team_canonical = "Ivory Coast",
    home_score = NA_real_,
    away_score = NA_real_,
    neutral = TRUE,
    stringsAsFactors = FALSE
  )
  elo <- data.frame(
    date = as.Date(c("2026-06-01", "2026-06-01")),
    team = c("Korea Republic", "Ivory Coast"),
    rating = c(1500, 1500),
    stringsAsFactors = FALSE
  )
  squad <- data.frame(
    team = c("Korea, South", "Cote d'Ivoire"),
    as_of_date = as.Date(c("2026-06-10", "2026-06-10")),
    feature_source_date = as.Date(c("2026-06-09", "2026-06-09")),
    log_squad_value = c(11, 9),
    stringsAsFactors = FALSE
  )

  features <- build_forecast_feature_table(
    matches = matches,
    elo_ratings = elo,
    squad_strength = squad,
    cutoff_date = as.Date("2026-06-10")
  )

  expect_equal(features$log_squad_value_diff, 2)
})

test_that("knockout route estimator uses supplied hybrid forecast features", {
  source(file.path(project_root, "R/visualization/worldcup_dashboard.R"))

  model_data <- data.frame(
    goals = c(1, 2, 1, 4, 3, 6),
    elo_diff = c(-2, -1, 0, 1, 2, 3),
    log_squad_value_diff = c(3, -1, 2, -2, 1, -3)
  )
  home_model <- glm(goals ~ elo_diff + log_squad_value_diff, data = model_data, family = poisson)
  away_model <- glm(goals ~ elo_diff + log_squad_value_diff, data = model_data, family = poisson)
  attr(home_model, "xgelo_predictors") <- c("elo_diff", "log_squad_value_diff")
  attr(away_model, "xgelo_predictors") <- c("elo_diff", "log_squad_value_diff")
  attr(home_model, "xgelo_feature_perspective") <- "home"
  attr(away_model, "xgelo_feature_perspective") <- "home"
  attr(home_model, "xgelo_model_version") <- "hybrid"
  attr(away_model, "xgelo_model_version") <- "hybrid"

  home_path <- tempfile(fileext = ".rds")
  away_path <- tempfile(fileext = ".rds")
  elo_path <- tempfile(fileext = ".csv")
  saveRDS(home_model, home_path)
  saveRDS(away_model, away_path)
  write.csv(
    data.frame(date = as.Date(c("2026-06-01", "2026-06-01")), team = c("A", "B"), rating = c(1500, 1500)),
    elo_path,
    row.names = FALSE
  )
  feature_rows <- data.frame(
    date = as.Date(c("2026-06-28", "2026-06-28")),
    home_team = c("A", "B"),
    away_team = c("B", "A"),
    elo_diff = c(0, 0),
    log_squad_value_diff = c(3, -3),
    stringsAsFactors = FALSE
  )

  without_features <- make_knockout_route_estimator(
    rating_by_team = c(A = 1500, B = 1500),
    date = as.Date("2026-06-28"),
    n_sim = 1000,
    seed = 1,
    home_model_path = home_path,
    away_model_path = away_path,
    elo_ratings_path = elo_path,
    model_version = "hybrid"
  )("A", "B")
  with_features <- make_knockout_route_estimator(
    rating_by_team = c(A = 1500, B = 1500),
    date = as.Date("2026-06-28"),
    n_sim = 1000,
    seed = 1,
    home_model_path = home_path,
    away_model_path = away_path,
    elo_ratings_path = elo_path,
    forecast_features = feature_rows,
    require_forecast_features = TRUE,
    model_version = "hybrid"
  )("A", "B")
  with_precompute <- make_knockout_route_estimator(
    rating_by_team = c(A = 1500, B = 1500),
    date = as.Date("2026-06-28"),
    n_sim = 1000,
    seed = 1,
    home_model_path = home_path,
    away_model_path = away_path,
    elo_ratings_path = elo_path,
    forecast_features = feature_rows,
    require_forecast_features = TRUE,
    model_version = "hybrid",
    precompute_teams = c("A", "B"),
    precompute_workers = 2
  )("A", "B")

  expect_gt(abs(with_features$slot1_expected_goals - without_features$slot1_expected_goals), 0.1)
  expect_equal(with_precompute$slot1_expected_goals, with_features$slot1_expected_goals)
  expect_equal(with_precompute$slot2_expected_goals, with_features$slot2_expected_goals)
})
