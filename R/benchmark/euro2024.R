#' UEFA Euro 2024 Benchmark
#'
#' Compares baseline and hybrid forecast features on the frozen pre-tournament
#' EURO 2024 holdout.

#' Select UEFA Euro 2024 holdout matches
#'
#' @param matches Match data
#' @param start_date Tournament start date
#' @param end_date Tournament end date
#' @return 51-match holdout data frame
#' @export
select_euro2024_matches <- function(
    matches,
    start_date = as.Date("2024-06-14"),
    end_date = as.Date("2024-07-14")
) {
  matches$date <- as.Date(matches$date)
  euro <- matches[
    !is.na(matches$date) &
      matches$date >= as.Date(start_date) &
      matches$date <= as.Date(end_date) &
      grepl("UEFA Euro", matches$tournament, ignore.case = TRUE),
    ,
    drop = FALSE
  ]
  euro <- euro[order(euro$date), , drop = FALSE]
  if (nrow(euro) != 51) {
    stop(paste("Expected 51 EURO 2024 matches, found", nrow(euro)))
  }
  euro
}

#' Compute multiclass forecast metrics
#'
#' @param predictions Data frame with probabilities and actual_outcome
#' @return Metrics data frame
#' @export
compute_match_probability_metrics <- function(predictions) {
  required_cols <- c("home_win_prob", "draw_prob", "away_win_prob", "actual_outcome")
  missing_cols <- setdiff(required_cols, names(predictions))
  if (length(missing_cols) > 0) {
    stop(paste("Predictions missing required columns:", paste(missing_cols, collapse = ", ")))
  }

  probs <- as.matrix(predictions[, c("home_win_prob", "draw_prob", "away_win_prob")])
  colnames(probs) <- c("home_win", "draw", "away_win")
  probs <- pmax(pmin(probs, 1 - 1e-12), 1e-12)
  colnames(probs) <- c("home_win", "draw", "away_win")
  probs <- probs / rowSums(probs)
  outcomes <- factor(predictions$actual_outcome, levels = c("home_win", "draw", "away_win"))
  actual <- cbind(
    home_win = as.integer(outcomes == "home_win"),
    draw = as.integer(outcomes == "draw"),
    away_win = as.integer(outcomes == "away_win")
  )

  brier <- mean(rowSums((probs - actual)^2))
  log_loss <- -mean(log(probs[cbind(seq_len(nrow(probs)), as.integer(outcomes))]))
  ranked_probability_score <- mean(rowSums((t(apply(probs, 1, cumsum)) - t(apply(actual, 1, cumsum)))^2) / 2)
  draw_calibration_error <- mean(probs[, "draw"]) - mean(actual[, "draw"])

  data.frame(
    multiclass_brier = brier,
    log_loss = log_loss,
    ranked_probability_score = ranked_probability_score,
    mean_predicted_draw = mean(probs[, "draw"]),
    actual_draw_rate = mean(actual[, "draw"]),
    draw_calibration_error = draw_calibration_error,
    n_matches = nrow(predictions),
    stringsAsFactors = FALSE
  )
}

#' Reliability bins for each outcome probability
#'
#' @param predictions Prediction data frame
#' @param n_bins Number of probability bins
#' @return Reliability-bin data frame
#' @export
compute_reliability_bins <- function(predictions, n_bins = 10) {
  outcomes <- c("home_win", "draw", "away_win")
  prob_cols <- c("home_win_prob", "draw_prob", "away_win_prob")
  bins <- seq(0, 1, length.out = n_bins + 1)
  rows <- list()
  for (j in seq_along(outcomes)) {
    prob <- predictions[[prob_cols[j]]]
    actual <- as.integer(predictions$actual_outcome == outcomes[j])
    bin <- cut(prob, breaks = bins, include.lowest = TRUE)
    summary <- aggregate(
      data.frame(predicted = prob, actual = actual),
      list(bin = bin),
      function(x) mean(x, na.rm = TRUE)
    )
    summary$n <- as.integer(table(bin)[as.character(summary$bin)])
    summary$outcome <- outcomes[j]
    rows[[j]] <- summary[, c("outcome", "bin", "predicted", "actual", "n")]
  }
  do.call(rbind, rows)
}

#' Predict match probabilities from fitted goal models and feature rows
#'
#' @keywords internal
predict_feature_goal_probabilities <- function(home_model, away_model, features, max_goals = 10) {
  predictors <- unique(c(attr(home_model, "xgelo_predictors"), attr(away_model, "xgelo_predictors")))
  if (length(predictors) == 0) predictors <- "elo_diff"
  for (predictor in predictors) {
    if (!predictor %in% names(features)) features[[predictor]] <- 0
  }
  newdata <- features[, predictors, drop = FALSE]
  home_lambda <- as.numeric(predict(home_model, newdata = newdata, type = "response"))
  away_lambda <- as.numeric(predict(away_model, newdata = newdata, type = "response"))

  theta_or_inf <- function(model) {
    theta <- model$theta
    if (!is.null(theta) && is.finite(theta) && theta > 0) theta else Inf
  }
  home_theta <- theta_or_inf(home_model)
  away_theta <- theta_or_inf(away_model)

  rows <- vector("list", nrow(features))
  goals <- 0:max_goals
  for (i in seq_len(nrow(features))) {
    hp <- if (is.infinite(home_theta)) stats::dpois(goals, home_lambda[i]) else stats::dnbinom(goals, size = home_theta, mu = home_lambda[i])
    ap <- if (is.infinite(away_theta)) stats::dpois(goals, away_lambda[i]) else stats::dnbinom(goals, size = away_theta, mu = away_lambda[i])
    grid <- outer(hp, ap)
    grid <- grid / sum(grid)
    rows[[i]] <- data.frame(
      home_win_prob = sum(grid[row(grid) > col(grid)]),
      draw_prob = sum(diag(grid)),
      away_win_prob = sum(grid[row(grid) < col(grid)]),
      expected_home_goals = home_lambda[i],
      expected_away_goals = away_lambda[i],
      stringsAsFactors = FALSE
    )
  }
  do.call(rbind, rows)
}

#' Run frozen EURO 2024 benchmark
#'
#' @param matches_path Path to processed match data
#' @param elo_ratings_path Path to Elo ratings
#' @param rolling_form_path Optional rolling form path
#' @param squad_strength_path Optional Transfermarkt squad features
#' @param cutoff_date Frozen pre-tournament cutoff
#' @param output_dir Output directory
#' @return List with metrics, predictions, and reliability bins
#' @export
run_euro2024_benchmark <- function(
    matches_path = "data/processed/elo_matches.csv",
    elo_ratings_path = "data/processed/elo_ratings.csv",
    rolling_form_path = "data/processed/rolling_form.csv",
    squad_strength_path = "data/processed/transfermarkt_squad_strength.csv",
    cutoff_date = as.Date("2024-06-14"),
    output_dir = "outputs/benchmarks/euro2024"
) {
  suppressPackageStartupMessages({
    library(MASS)
  })
  if (!exists("build_forecast_feature_table")) source("R/forecast/features.R")
  if (!exists("compute_goal_ability_features")) source("R/forecast/goal_ability.R")
  if (!exists("train_goal_model_from_features")) source("R/forecast/poisson.R")

  matches <- read.csv(matches_path, stringsAsFactors = FALSE)
  matches$date <- as.Date(matches$date)
  elo <- read.csv(elo_ratings_path, stringsAsFactors = FALSE)
  rolling <- if (file.exists(rolling_form_path)) read.csv(rolling_form_path, stringsAsFactors = FALSE) else NULL
  squad <- if (file.exists(squad_strength_path)) read.csv(squad_strength_path, stringsAsFactors = FALSE) else NULL

  holdout <- select_euro2024_matches(matches, start_date = cutoff_date)
  training <- matches[
    matches$date < cutoff_date &
      !is.na(matches$home_score) &
      !is.na(matches$away_score) &
      !is.na(matches$home_team_canonical) &
      !is.na(matches$away_team_canonical),
    ,
    drop = FALSE
  ]
  if (any(training$date >= cutoff_date, na.rm = TRUE)) stop("Benchmark training leakage detected")

  baseline_train <- build_forecast_feature_table(training, elo, rolling_form = rolling)
  baseline_holdout <- build_forecast_feature_table(holdout, elo, rolling_form = rolling, cutoff_date = cutoff_date)
  assert_no_feature_leakage(baseline_holdout, cutoff_date = cutoff_date)

  ability_train <- suppressWarnings(compute_goal_ability_features(training, matches))
  ability_holdout <- suppressWarnings(compute_goal_ability_features(holdout, matches, cutoff_date = cutoff_date))
  hybrid_train <- build_forecast_feature_table(
    training, elo, rolling_form = rolling, squad_strength = squad, goal_ability = ability_train
  )
  hybrid_holdout <- build_forecast_feature_table(
    holdout, elo, rolling_form = rolling, squad_strength = squad, goal_ability = ability_holdout, cutoff_date = cutoff_date
  )
  assert_no_feature_leakage(hybrid_holdout, cutoff_date = cutoff_date)

  baseline_predictors <- baseline_goal_predictors()
  hybrid_predictors <- hybrid_goal_predictors()

  baseline_home <- train_goal_model_from_features(baseline_train, "home", predictors = baseline_predictors, model_version = "baseline")
  baseline_away <- train_goal_model_from_features(baseline_train, "away", predictors = baseline_predictors, model_version = "baseline")
  hybrid_home <- train_goal_model_from_features(hybrid_train, "home", predictors = hybrid_predictors, model_version = "hybrid")
  hybrid_away <- train_goal_model_from_features(hybrid_train, "away", predictors = hybrid_predictors, model_version = "hybrid")

  baseline_probs <- predict_feature_goal_probabilities(baseline_home, baseline_away, baseline_holdout)
  hybrid_probs <- predict_feature_goal_probabilities(hybrid_home, hybrid_away, hybrid_holdout)

  make_predictions <- function(model_name, features, probabilities) {
    data.frame(
      model = model_name,
      date = features$date,
      home_team = features$home_team,
      away_team = features$away_team,
      actual_outcome = features$actual_outcome,
      probabilities,
      feature_source_date = features$feature_source_date,
      stringsAsFactors = FALSE
    )
  }
  predictions <- rbind(
    make_predictions("baseline", baseline_holdout, baseline_probs),
    make_predictions("hybrid", hybrid_holdout, hybrid_probs)
  )
  metrics <- do.call(rbind, lapply(split(predictions, predictions$model), function(rows) {
    cbind(model = rows$model[1], compute_match_probability_metrics(rows))
  }))
  rownames(metrics) <- NULL

  baseline_metrics <- metrics[metrics$model == "baseline", , drop = FALSE]
  hybrid_metrics <- metrics[metrics$model == "hybrid", , drop = FALSE]
  hybrid_pass <- isTRUE(
    hybrid_metrics$multiclass_brier < baseline_metrics$multiclass_brier &&
      hybrid_metrics$log_loss < baseline_metrics$log_loss &&
      abs(hybrid_metrics$draw_calibration_error) <= abs(baseline_metrics$draw_calibration_error) + 0.02
  )
  metrics$hybrid_pass <- metrics$model == "hybrid" & hybrid_pass

  reliability <- do.call(rbind, lapply(split(predictions, predictions$model), function(rows) {
    cbind(model = rows$model[1], compute_reliability_bins(rows))
  }))
  rownames(reliability) <- NULL

  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)
  write.csv(predictions, file.path(output_dir, "euro2024_predictions.csv"), row.names = FALSE)
  write.csv(metrics, file.path(output_dir, "euro2024_metrics.csv"), row.names = FALSE)
  write.csv(reliability, file.path(output_dir, "euro2024_reliability.csv"), row.names = FALSE)

  list(
    metrics = metrics,
    predictions = predictions,
    reliability = reliability,
    training_rows = nrow(training),
    holdout_rows = nrow(holdout),
    cutoff_date = cutoff_date,
    hybrid_pass = hybrid_pass
  )
}
