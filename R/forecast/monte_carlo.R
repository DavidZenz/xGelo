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
#' @param n_sim Number of simulations (default: 50000)
#' @param seed Random seed for reproducibility
#' @return List with win_prob, draw_prob, loss_prob, expected_home, expected_away
#' @export
simulate_fixture <- function(
    home_team,
    away_team,
    date = NULL,
    venue = "home",
    home_model_path = "models/home_goal_model.rds",
    away_model_path = "models/away_goal_model.rds",
    n_sim = 50000,
    seed = NULL
) {
  
  suppressPackageStartupMessages({
    library(MASS)
    library(dplyr)
  })
  
  # Load models
  if (!file.exists(home_model_path)) stop(paste("Home model not found:", home_model_path))
  if (!file.exists(away_model_path)) stop(paste("Away model not found:", away_model_path))
  
  home_model <- readRDS(home_model_path)
  away_model <- readRDS(away_model_path)
  
  # Set seed for reproducibility
  if (!is.null(seed)) set.seed(seed)
  
  # For MVP, use placeholder Elo values since we don't have full feature computation
  # In production, this would use actual Elo ratings and form metrics
  home_elo <- 1500
  away_elo <- 1500
  
  # Add home advantage for non-neutral
  if (venue == "home") {
    home_elo <- home_elo + 60
  } else if (venue == "neutral") {
    # No home advantage
  } else {
    # away venue - swap home and away
    home_elo <- away_elo
    away_elo <- 1500 + 60
  }
  
  elo_diff <- home_elo - away_elo
  
  # Predict lambdas
  home_lambda <- predict(home_model, newdata = data.frame(elo_diff = elo_diff), type = "response")
  away_lambda <- predict(away_model, newdata = data.frame(elo_diff = -elo_diff), type = "response")
  
  # Get theta (dispersion) from models
  home_theta <- if (inherits(home_model, "glm.nb")) home_model$theta else 1
  away_theta <- if (inherits(away_model, "glm.nb")) away_model$theta else 1
  
  # Simulate goals
  home_goals <- rnbinom(n_sim, size = home_theta, prob = home_lambda / (home_lambda + home_theta))
  away_goals <- rnbinom(n_sim, size = away_theta, prob = away_lambda / (away_lambda + away_theta))
  
  # Compute outcomes
  outcomes <- ifelse(home_goals > away_goals, "win", 
                     ifelse(home_goals == away_goals, "draw", "loss"))
  
  # Compute probabilities
  probs <- table(outcomes) / n_sim
  win_prob <- ifelse("win" %in% names(probs), probs["win"], 0)
  draw_prob <- ifelse("draw" %in% names(probs), probs["draw"], 0)
  loss_prob <- ifelse("loss" %in% names(probs), probs["loss"], 0)
  
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
  
  # Return results
  list(
    win_prob = win_prob,
    draw_prob = draw_prob,
    loss_prob = loss_prob,
    expected_home = expected_home,
    expected_away = expected_away,
    home_lambda = home_lambda,
    away_lambda = away_lambda,
    total_prob = win_prob + draw_prob + loss_prob
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
