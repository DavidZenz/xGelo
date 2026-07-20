library(testthat)

project_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))
source(file.path(project_root, "R/evaluation/proper_scores.R"))
source(file.path(project_root, "R/evaluation/benchmark_scores.R"))

benchmark_test_distribution <- function(id = "dist_1") {
  grid <- expand.grid(home_goals = 0:1, away_goals = 0:1)
  grid$score_distribution_id <- id
  grid$probability <- c(0.2, 0.3, 0.1, 0.4)
  grid
}

benchmark_test_prediction <- function(model_id = "candidate", fixture_id = "f1", edition_id = "wc2002") {
  data.frame(
    run_id = "run_1", model_id = model_id, panel_id = "open_core",
    edition_id = edition_id, track_id = "updating", fixture_id = fixture_id,
    score_distribution_id = "dist_1", p_home = 0.3, p_draw = 0.6,
    p_away = 0.1, p_over_2_5 = 0, p_under_2_5 = 1, p_btts = 0.4,
    prediction_status = "ok", stringsAsFactors = FALSE
  )
}

benchmark_test_fixture <- function(fixture_id = "f1", edition_id = "wc2002") {
  data.frame(
    edition_id = edition_id, fixture_id = fixture_id,
    regulation_home_goals = 1L, regulation_away_goals = 1L,
    score_eligible = TRUE, stringsAsFactors = FALSE
  )
}

test_that("fixture scores preserve every locked hand-calculated scale", {
  scores <- score_benchmark_fixtures(
    benchmark_test_prediction(), benchmark_test_fixture(), benchmark_test_distribution()
  )
  value <- function(metric) scores$value[scores$metric == metric]

  expect_equal(value("rps"), 0.05, tolerance = 1e-12)
  expect_equal(value("brier"), 0.26, tolerance = 1e-12)
  expect_equal(value("log_loss"), -log(0.6), tolerance = 1e-12)
  expect_equal(value("joint_scoreline_log_loss"), -log(0.4), tolerance = 1e-12)
  expect_equal(value("home_goal_rps"), 0.09, tolerance = 1e-12)
  expect_equal(value("away_goal_rps"), 0.25, tolerance = 1e-12)
  expect_equal(value("over_2_5_brier"), 0, tolerance = 1e-12)
  expect_equal(value("btts_brier"), 0.36, tolerance = 1e-12)
  expect_equal(value("btts_log_loss"), -log(0.4), tolerance = 1e-12)
})

test_that("scoring fails instead of shrinking registered fixture coverage", {
  predictions <- benchmark_test_prediction()
  fixtures <- rbind(
    benchmark_test_fixture("f1"),
    benchmark_test_fixture("f2")
  )
  expect_error(
    score_benchmark_fixtures(predictions, fixtures, benchmark_test_distribution()),
    "exactly the registered fixture IDs"
  )
})

test_that("headline aggregation weights tournaments equally and labels pooled estimates", {
  editions <- c(paste0("wc", 1:6), paste0("euro", 1:6))
  scores <- do.call(rbind, lapply(seq_along(editions), function(i) {
    n <- if (i == 1L) 10L else 1L
    data.frame(
      run_id = "run", model_id = "m", panel_id = "open_core", track_id = "updating",
      edition_id = editions[i], fixture_id = paste0(editions[i], "_", seq_len(n)),
      target = "regulation_1x2", metric = "rps", value = if (i == 1L) 0 else 1,
      covered = TRUE, stringsAsFactors = FALSE
    )
  }))
  summaries <- aggregate_benchmark_scores(scores, expected_editions = editions)
  headline <- summaries[summaries$grain == "headline", ]

  expect_equal(headline$estimate[headline$aggregation == "equal_tournament"], 11 / 12)
  expect_equal(headline$estimate[headline$aggregation == "fixture_weighted"], 11 / 21)
  expect_false(isTRUE(all.equal(
    headline$estimate[headline$aggregation == "equal_tournament"],
    headline$estimate[headline$aggregation == "fixture_weighted"]
  )))
  expect_equal(sum(summaries$grain == "tournament"), 12L)
})

test_that("fixed calibration bins are shared and tournament weighted", {
  predictions <- benchmark_test_prediction()
  predictions$p_home <- 0.8
  predictions$p_draw <- 0.1
  predictions$p_away <- 0.1
  fixtures <- benchmark_test_fixture()
  fixtures$regulation_home_goals <- 1L
  fixtures$regulation_away_goals <- 0L

  calibration <- fixed_benchmark_calibration(predictions, fixtures, min_bin_count = 2L)
  expect_equal(calibration$summary$calibration_error, (0.2 + 0.1 + 0.1) / 3)
  expect_equal(calibration$bins$bin_lower[calibration$bins$class == "home"], 0.8)
  expect_true(all(calibration$bins$sparse))
  expect_equal(calibration$bins$weight, rep(1 / 3, 3))
})

benchmark_pair_scores <- function() {
  editions <- c(paste0("wc", 1:6), paste0("euro", 1:6))
  deltas <- c(rep(-0.01, 4), rep(0.005, 2), rep(-0.01, 4), rep(0.005, 2))
  incumbent <- data.frame(
    run_id = "run", model_id = "incumbent", panel_id = "open_core", track_id = "updating",
    edition_id = editions, fixture_id = paste0("f", seq_along(editions)),
    target = "regulation_1x2", metric = "rps", value = 0.2,
    covered = TRUE, stringsAsFactors = FALSE
  )
  candidate <- incumbent
  candidate$model_id <- "candidate"
  candidate$value <- candidate$value + deltas
  tournaments <- data.frame(
    edition_id = editions,
    competition_id = c(rep("world_cup", 6), rep("euro", 6)),
    stringsAsFactors = FALSE
  )
  list(scores = rbind(candidate, incumbent), tournaments = tournaments, editions = editions)
}

test_that("paired comparisons retain 12 folds and expose breadth, regression, and LOTO", {
  x <- benchmark_pair_scores()
  comparison <- make_paired_fold_comparisons(
    x$scores[sample(nrow(x$scores)), ], "candidate", "incumbent",
    tournaments = x$tournaments, expected_fixture_ids = paste0("f", 1:12)
  )

  expect_equal(nrow(comparison$folds), 12L)
  expect_equal(comparison$breadth$fold_wins, 8L)
  expect_equal(comparison$breadth$world_cup_wins, 4L)
  expect_equal(comparison$breadth$euro_wins, 4L)
  expect_equal(comparison$breadth$maximum_fold_regression, 0.005)
  expect_equal(nrow(comparison$leave_one_out), 12L)

  incomplete <- x$scores[x$scores$fixture_id != "f12" | x$scores$model_id != "candidate", ]
  expect_error(
    make_paired_fold_comparisons(
      incomplete, "candidate", "incumbent", x$tournaments, paste0("f", 1:12)
    ),
    "exact paired fixture set"
  )
})

test_that("paired bootstrap uses 12 tournament deltas and the registered seed deterministically", {
  folds <- data.frame(edition_id = paste0("e", 1:12), delta = rep(-0.004, 12))
  first <- paired_tournament_bootstrap(folds, reps = 10000L, seed = 920001L)
  second <- paired_tournament_bootstrap(folds, reps = 10000L, seed = 920001L)

  expect_identical(first, second)
  expect_equal(first$estimate, -0.004)
  expect_equal(first$lower, -0.004)
  expect_equal(first$upper, -0.004)
  expect_equal(first$replicates, 10000L)
  expect_error(
    paired_tournament_bootstrap(folds[-1, ], reps = 10000L, seed = 920001L),
    "exactly 12 tournament deltas"
  )
})
