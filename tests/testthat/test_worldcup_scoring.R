library(testthat)

project_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))
source(file.path(project_root, "R/evaluation/proper_scores.R"))
source(file.path(project_root, "R/evaluation/worldcup_ledger.R"))
source(file.path(project_root, "R/evaluation/worldcup_retrospective.R"))

testthat::test_that("1X2 proper scores match hand calculations", {
  perfect <- c(home = 1, draw = 0, away = 0)
  uniform <- c(home = 1 / 3, draw = 1 / 3, away = 1 / 3)
  wrong <- c(home = 0, draw = 0, away = 1)

  testthat::expect_equal(multiclass_brier(perfect, "home"), 0)
  testthat::expect_equal(ranked_probability_score(perfect, "home"), 0)
  testthat::expect_equal(multiclass_brier(uniform, "home"), 2 / 3, tolerance = 1e-12)
  testthat::expect_equal(ranked_probability_score(uniform, "home"), 5 / 18, tolerance = 1e-12)
  testthat::expect_equal(ranked_probability_score(wrong, "home"), 1, tolerance = 1e-12)
  testthat::expect_equal(log_score(uniform, "home"), log(3), tolerance = 1e-12)
})

testthat::test_that("probability contracts reject invalid distributions", {
  testthat::expect_error(
    multiclass_brier(c(home = 0.5, draw = 0.2, away = 0.2), "home"),
    "sum to one"
  )
  testthat::expect_error(binary_brier(1.1, 1), "in \\[0, 1\\]")
  testthat::expect_error(
    ranked_probability_score(c(home = 0.5, away = 0.5), "home"),
    "every ordered class"
  )
})

testthat::test_that("complete scoreline distributions yield direct market scores", {
  distribution <- expand.grid(home_goals = 0:1, away_goals = 0:1)
  distribution$probability <- c(0.2, 0.3, 0.1, 0.4)
  markets <- derive_binary_markets(distribution)
  scores <- score_scoreline_distribution(distribution, 1, 1)

  testthat::expect_equal(markets$p_over_2_5, 0)
  testthat::expect_equal(markets$p_btts, 0.4)
  testthat::expect_equal(markets$home_probabilities, c(0.3, 0.7))
  testthat::expect_equal(markets$away_probabilities, c(0.5, 0.5))
  testthat::expect_equal(scores$joint_log_score, -log(0.4))
  testthat::expect_equal(scores$exact_score_hit, 1)
})

testthat::test_that("incomplete and missing-cell scoreline distributions fail visibly", {
  incomplete <- data.frame(home_goals = 0:1, away_goals = 0:1, probability = c(0.2, 0.3))
  complete <- data.frame(
    home_goals = c(0, 1), away_goals = c(0, 0), probability = c(0.4, 0.6)
  )
  testthat::expect_error(derive_binary_markets(incomplete), "sum to one")
  testthat::expect_error(
    score_scoreline_distribution(complete, 1, 1),
    "observed scoreline cell is absent"
  )
})

synthetic_selected_forecasts <- function() {
  data.frame(
    match_id = c("G1", "G2", "G1", "G2"),
    sample = c("strict", "strict", "exploratory", "exploratory"),
    view = "latest_valid", stage = "group", round = "Group A",
    canonical_home_team = c("A", "C", "A", "C"),
    canonical_away_team = c("B", "D", "B", "D"),
    actual_home_goals = c(1, 0, 1, 0), actual_away_goals = c(0, 0, 0, 0),
    actual_winner_team = c("A", NA, "A", NA),
    expected_home_goals = 1, expected_away_goals = 0.5,
    p_home = c(0.6, 0.3, 0.5, 0.2), p_draw = c(0.2, 0.4, 0.3, 0.5),
    p_away = c(0.2, 0.3, 0.2, 0.3), p_home_advance = NA_real_, p_away_advance = NA_real_,
    p_over_2_5 = 0.4, p_btts = 0.3,
    commit_sha = c("a", "b", "c", "d"), committed_at = "2026-06-01T00:00:00+00:00",
    stringsAsFactors = FALSE
  )
}

testthat::test_that("fixture scores and equal-weight aggregates remain sample-separated", {
  selected <- synthetic_selected_forecasts()
  scores <- score_worldcup_matches(selected)
  aggregates <- aggregate_worldcup_scores(scores, n_official = 2, reps = 100, seed = 20260720)
  headline <- aggregates[
    aggregates$sample == "strict" & aggregates$view == "latest_valid" &
      aggregates$metric == "rps" & aggregates$cut_type == "overall", , drop = FALSE
  ]
  fixture_rps <- scores$value[scores$sample == "strict" & scores$metric == "rps"]

  testthat::expect_equal(nrow(scores[scores$metric == "rps", ]), 4)
  testthat::expect_equal(headline$estimate, mean(fixture_rps))
  testthat::expect_equal(headline$n_scored, 2)
  testthat::expect_equal(headline$coverage, 1)
  testthat::expect_false(any(grepl("strict.*exploratory|exploratory.*strict", aggregates$sample)))
  scoreline <- aggregates[
    aggregates$sample == "strict" & aggregates$view == "latest_valid" &
      aggregates$metric == "joint_scoreline_log_loss" & aggregates$cut_type == "overall", , drop = FALSE
  ]
  testthat::expect_equal(scoreline$n_scored, 0)
  testthat::expect_equal(scoreline$coverage, 0)
})

testthat::test_that("bootstrap intervals are deterministic", {
  scores <- score_worldcup_matches(synthetic_selected_forecasts())
  first <- bootstrap_worldcup_scores(scores, reps = 100, seed = 20260720)
  second <- bootstrap_worldcup_scores(scores, reps = 100, seed = 20260720)
  testthat::expect_identical(first, second)
})

testthat::test_that("paired deltas use only fixtures present in both views", {
  selected <- synthetic_selected_forecasts()
  first <- selected
  first$view <- "first_valid"
  first$p_home <- pmax(first$p_home - 0.05, 0)
  first$p_draw <- first$p_draw + 0.05
  scores <- score_worldcup_matches(rbind(first, selected))
  aggregates <- aggregate_worldcup_scores(scores, n_official = 2, reps = 50)
  paired <- aggregates[
    aggregates$sample == "strict" & aggregates$view == "paired_delta_latest_minus_first" &
      aggregates$metric == "rps", , drop = FALSE
  ]
  testthat::expect_equal(paired$n_scored, 2)
})

testthat::test_that("calibration bins flag groups below minimum size", {
  bins <- make_calibration_bins(synthetic_selected_forecasts(), min_bin_size = 5, max_bins = 10)
  testthat::expect_true(all(bins$sparse))
  testthat::expect_true(all(c("sample", "view", "class", "n") %in% names(bins)))
})

testthat::test_that("knockout forecasts are scored against the advancing team", {
  selected <- synthetic_selected_forecasts()[1, ]
  selected$match_id <- "M73"
  selected$stage <- "knockout"
  selected$round <- "Round of 32"
  selected$p_home_advance <- 0.75
  selected$p_away_advance <- 0.25
  advancement <- score_knockout_advancement(selected)
  testthat::expect_equal(advancement$brier, 0.0625)
  testthat::expect_equal(advancement$actual_advancing_team, "A")
})

testthat::test_that("stage anchors are unique and strictly predate boundaries", {
  fixtures <- data.frame(
    round = c("Group A", "Round of 32", "Round of 16", "Quarter-finals", "Semi-finals", "Final"),
    kickoff_utc = c(
      "2026-06-11T00:00:00Z", "2026-06-28T00:00:00Z", "2026-07-04T00:00:00Z",
      "2026-07-09T00:00:00Z", "2026-07-13T00:00:00Z", "2026-07-19T00:00:00Z"
    ), stringsAsFactors = FALSE
  )
  selected <- data.frame(
    sample = rep("strict", 3), commit_sha = c("a", "b", "c"),
    committed_at = c(
      "2026-06-01T00:00:00+00:00", "2026-06-20T00:00:00+00:00",
      "2026-07-05T00:00:00+00:00"
    ), stringsAsFactors = FALSE
  )
  stage <- data.frame(commit_sha = rep(c("a", "b", "c"), each = 2), team = rep(c("A", "B"), 3))
  anchors <- select_stage_reach_anchors(selected, stage, fixtures)
  testthat::expect_true(all(parse_utc_time(anchors$forecast_at) < parse_utc_time(anchors$boundary_utc)))
  testthat::expect_equal(anyDuplicated(anchors[c("sample", "anchor_type", "target_stage")]), 0L)
  testthat::expect_equal(sum(anchors$anchor_type == "pre_tournament"), 6)
})
