#' xGelo Forecasting Layer - Monte Carlo Simulation
#'
#' Implements Monte Carlo simulation to compute win/draw/loss probabilities
#'
#' @author xGelo project
#' @date 2026-06-03

#' Simulate a single fixture and return probabilities
#'
#' @param home_team Home team name (canonical)
#' @param away_team Away team name (canonical)
#' @param date Match date
#' @param venue Match venue ("home", "away", "neutral")
#' @param home_model_path Path to home goal model RDS
#' @param away_model_path Path to away goal model RDS
#' @param elo_ratings_path Path to historical Elo ratings CSV
#' @param n_sim Number of simulations (default: 50000)
#' @param seed Random seed for reproducibility
#' @param top_n_scorelines Number of scorelines to include in top_scorelines
#' @param include_scoreline_distribution Whether to return full scoreline distribution
#' @return List with win_prob, draw_prob, loss_prob, expected_home, expected_away
#' @export
simulate_fixture <- function(
    home_team,
    away_team,
    date = NULL,
    venue = "home",
    home_model_path = "models/home_goal_model.rds",
    away_model_path = "models/away_goal_model.rds",
    elo_ratings_path = "data/processed/elo_ratings.csv",
    n_sim = 50000,
    seed = NULL,
    top_n_scorelines = 10,
    include_scoreline_distribution = TRUE
) {

  suppressPackageStartupMessages({
    library(MASS)
    library(dplyr)
  })
  if (n_sim <= 0) stop("n_sim must be positive")
  if (top_n_scorelines <= 0) stop("top_n_scorelines must be positive")

  # Load models
  if (!file.exists(home_model_path)) stop(paste("Home model not found:", home_model_path))
  if (!file.exists(away_model_path)) stop(paste("Away model not found:", away_model_path))
  if (!file.exists(elo_ratings_path)) stop(paste("Elo ratings not found:", elo_ratings_path))

  home_model <- readRDS(home_model_path)
  away_model <- readRDS(away_model_path)
  elo_ratings <- read.csv(elo_ratings_path, stringsAsFactors = FALSE)
  elo_ratings$date <- as.Date(elo_ratings$date)

  # Set seed for reproducibility
  if (!is.null(seed)) set.seed(seed)

  match_date <- if (is.null(date)) {
    max(elo_ratings$date, na.rm = TRUE) + 1
  } else {
    as.Date(date)
  }

  get_pre_match_elo <- function(team_name) {
    team_rows <- elo_ratings[
      elo_ratings$team == team_name &
        !is.na(elo_ratings$rating) &
        elo_ratings$date < match_date,
    ]

    if (nrow(team_rows) == 0) {
      warning(paste("No pre-match Elo found for", team_name, "before", match_date, "- using 1500"))
      return(1500)
    }

    team_rows <- team_rows[order(team_rows$date, team_rows$is_post_match), ]
    tail(team_rows$rating, 1)
  }

  home_elo <- get_pre_match_elo(home_team)
  away_elo <- get_pre_match_elo(away_team)

  # Add home advantage for non-neutral
  if (venue == "home") {
    home_elo <- home_elo + 60
  } else if (venue == "neutral") {
    # No home advantage
  } else if (venue == "away") {
    away_elo <- away_elo + 60
  } else {
    stop("venue must be one of 'home', 'away', or 'neutral'")
  }

  elo_diff <- home_elo - away_elo

  # Predict lambdas
  home_lambda <- predict(home_model, newdata = data.frame(elo_diff = elo_diff), type = "response")
  away_lambda <- predict(away_model, newdata = data.frame(elo_diff = -elo_diff), type = "response")

  # Get theta (dispersion) from models
  home_theta <- if (inherits(home_model, "glm.nb")) home_model$theta else 1
  away_theta <- if (inherits(away_model, "glm.nb")) away_model$theta else 1

  # Simulate goals
  home_goals <- rnbinom(n_sim, size = home_theta, prob = home_theta / (home_theta + home_lambda))
  away_goals <- rnbinom(n_sim, size = away_theta, prob = away_theta / (away_theta + away_lambda))

  # Compute outcomes
  outcomes <- ifelse(home_goals > away_goals, "win",
                     ifelse(home_goals == away_goals, "draw", "loss"))

  # Compute probabilities
  probs <- table(outcomes) / n_sim
  win_prob <- ifelse("win" %in% names(probs), as.numeric(probs["win"]), 0)
  draw_prob <- ifelse("draw" %in% names(probs), as.numeric(probs["draw"]), 0)
  loss_prob <- ifelse("loss" %in% names(probs), as.numeric(probs["loss"]), 0)

  # Verify sum
  total_prob <- win_prob + draw_prob + loss_prob
  if (abs(total_prob - 1) > 0.001) {
    warning(paste("Probabilities don't sum to 1:", total_prob))
    # Normalize
    win_prob <- win_prob / total_prob
    draw_prob <- draw_prob / total_prob
    loss_prob <- loss_prob / total_prob
  }

  # Expected goals
  expected_home <- mean(home_goals)
  expected_away <- mean(away_goals)

  scoreline_distribution <- data.frame(
    home_goals = home_goals,
    away_goals = away_goals,
    count = 1L
  ) %>%
    dplyr::group_by(home_goals, away_goals) %>%
    dplyr::summarise(count = sum(count), .groups = "drop") %>%
    dplyr::mutate(
      scoreline = paste(home_goals, away_goals, sep = "-"),
      outcome = ifelse(home_goals > away_goals, "home_win",
                       ifelse(home_goals == away_goals, "draw", "away_win")),
      probability = count / n_sim,
      total_goals = home_goals + away_goals
    ) %>%
    dplyr::arrange(dplyr::desc(probability), total_goals, home_goals, away_goals)

  top_scorelines <- head(scoreline_distribution, top_n_scorelines) %>%
    dplyr::select(home_goals, away_goals, scoreline, outcome, count, probability)

  modal_scoreline <- scoreline_distribution[1, ]
  outcome_probabilities <- c(
    home_win = win_prob,
    draw = draw_prob,
    away_win = loss_prob
  )
  predicted_outcome <- names(outcome_probabilities)[which.max(outcome_probabilities)]
  rounded_expected_score <- paste(round(expected_home), round(expected_away), sep = "-")
  over_2_5_probability <- sum(scoreline_distribution$probability[scoreline_distribution$total_goals > 2.5])
  under_2_5_probability <- sum(scoreline_distribution$probability[scoreline_distribution$total_goals <= 2.5])
  both_teams_to_score_probability <- sum(
    scoreline_distribution$probability[
      scoreline_distribution$home_goals > 0 & scoreline_distribution$away_goals > 0
    ]
  )

  scoreline_distribution <- scoreline_distribution %>%
    dplyr::select(home_goals, away_goals, scoreline, outcome, count, probability)

  # Return results
  list(
    win_prob = win_prob,
    draw_prob = draw_prob,
    loss_prob = loss_prob,
    expected_home = expected_home,
    expected_away = expected_away,
    home_lambda = home_lambda,
    away_lambda = away_lambda,
    total_prob = win_prob + draw_prob + loss_prob,
    predicted_outcome = predicted_outcome,
    most_likely_score = modal_scoreline$scoreline,
    most_likely_home_goals = modal_scoreline$home_goals,
    most_likely_away_goals = modal_scoreline$away_goals,
    most_likely_score_probability = modal_scoreline$probability,
    rounded_expected_score = rounded_expected_score,
    rounded_expected_home_goals = round(expected_home),
    rounded_expected_away_goals = round(expected_away),
    over_2_5_probability = over_2_5_probability,
    under_2_5_probability = under_2_5_probability,
    both_teams_to_score_probability = both_teams_to_score_probability,
    top_scorelines = top_scorelines,
    scoreline_distribution = if (include_scoreline_distribution) scoreline_distribution else NULL,
    n_sim = n_sim
  )
}

#' Wrapper for easier use
#' @export
run_monte_carlo <- function() {
  # Test with default values
  result <- simulate_fixture("Team A", "Team B", seed = 42)
  cat("Monte Carlo simulation test:\n")
  cat("Win probability:", round(result$win_prob, 4), "\n")
  cat("Draw probability:", round(result$draw_prob, 4), "\n")
  cat("Loss probability:", round(result$loss_prob, 4), "\n")
  cat("Total probability:", round(result$total_prob, 4), "\n")
  cat("Expected home goals:", round(result$expected_home, 2), "\n")
  cat("Expected away goals:", round(result$expected_away, 2), "\n")

  return(result)
}
