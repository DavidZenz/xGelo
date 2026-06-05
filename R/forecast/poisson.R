#' xGelo Forecasting Layer - Goal Models
#'
#' Simplified implementation for MVP. Uses Elo differences to predict goals.
#'
#' @author xGelo project
#' @date 2026-06-03

#' Train home goal model - simplified version
#' Uses a small sample for speed, with Elo difference as predictor
#' @export
train_home_goal_model <- function(
    data_path = "data/processed/elo_matches.csv",
    elo_ratings_path = "data/processed/elo_ratings.csv",
    model_path = "models/home_goal_model.rds",
    n_sample = 5000
) {
  
  suppressPackageStartupMessages({
    library(MASS)
    library(dplyr)
  })
  
  message("Training home goal model...")
  
  # Load data
  matches <- read.csv(data_path, stringsAsFactors = FALSE) %>% 
    filter(!is.na(home_score), !is.na(away_score), 
           !is.na(home_team_canonical), !is.na(away_team_canonical)) %>% 
    sample_n(min(n_sample, n()))
  
  elo_ratings <- read.csv(elo_ratings_path, stringsAsFactors = FALSE) %>% 
    mutate(date = as.Date(date))
  
  # Convert match dates
  matches <- matches %>% mutate(date = as.Date(date))
  
  # Simple vectorized Elo lookup for a small sample
  # For each match, find Elo ratings
  get_elo <- function(requested_team, match_date) {
    team_data <- elo_ratings[elo_ratings$team == requested_team & elo_ratings$date < match_date, ]
    if (nrow(team_data) > 0) {
      team_data <- team_data[order(team_data$date), ]
      ratings <- team_data$rating[!is.na(team_data$rating)]
      if (length(ratings) > 0) return(tail(ratings, 1))
    }
    return(1500)
  }
  
  # Apply to first N matches for speed
  n_use <- min(2000, nrow(matches))
  use_matches <- head(matches, n_use)
  
  elo_diffs <- numeric(n_use)
  home_goals <- numeric(n_use)
  
  for (i in 1:n_use) {
    m <- use_matches[i, ]
    home_elo <- get_elo(m$home_team_canonical, m$date)
    away_elo <- get_elo(m$away_team_canonical, m$date)
    
    # Add home advantage
    if (!m$neutral) home_elo <- home_elo + 60
    
    elo_diffs[i] <- home_elo - away_elo
    home_goals[i] <- m$home_score
  }
  
  training_data <- data.frame(elo_diff = elo_diffs, home_goals = home_goals)
  training_data <- na.omit(training_data)
  
  if (nrow(training_data) == 0) stop("No valid training data")
  
  # Train model
  formula_home <- home_goals ~ elo_diff
  
  home_model <- tryCatch({
    glm.nb(formula_home, data = training_data, control = glm.control(maxit = 50))
  }, error = function(e) {
    tryCatch({
      glm(formula_home, data = training_data, family = poisson)
    }, error = function(e2) {
      message("All models failed, returning NULL")
      return(NULL)
    })
  })
  
  if (is.null(home_model)) stop("Home goal model training failed")
  
  message(paste("Trained on", nrow(training_data), "samples"))
  message(paste("Model type:", class(home_model)))
  if (inherits(home_model, "glm.nb")) {
    message(paste("Theta:", round(home_model$theta, 4)))
  }
  
  # Save
  saveRDS(home_model, model_path)
  message(paste("Saved to", model_path))
  
  return(home_model)
}

#' Train away goal model - simplified version
#' @export
train_away_goal_model <- function(
    data_path = "data/processed/elo_matches.csv",
    elo_ratings_path = "data/processed/elo_ratings.csv",
    model_path = "models/away_goal_model.rds",
    n_sample = 5000
) {
  
  suppressPackageStartupMessages({
    library(MASS)
    library(dplyr)
  })
  
  message("Training away goal model...")
  
  # Load data
  matches <- read.csv(data_path, stringsAsFactors = FALSE) %>% 
    filter(!is.na(home_score), !is.na(away_score), 
           !is.na(home_team_canonical), !is.na(away_team_canonical)) %>% 
    sample_n(min(n_sample, n()))
  
  elo_ratings <- read.csv(elo_ratings_path, stringsAsFactors = FALSE) %>% 
    mutate(date = as.Date(date))
  
  matches <- matches %>% mutate(date = as.Date(date))
  
  get_elo <- function(requested_team, match_date) {
    team_data <- elo_ratings[elo_ratings$team == requested_team & elo_ratings$date < match_date, ]
    if (nrow(team_data) > 0) {
      team_data <- team_data[order(team_data$date), ]
      ratings <- team_data$rating[!is.na(team_data$rating)]
      if (length(ratings) > 0) return(tail(ratings, 1))
    }
    return(1500)
  }
  
  n_use <- min(2000, nrow(matches))
  use_matches <- head(matches, n_use)
  
  elo_diffs <- numeric(n_use)
  away_goals <- numeric(n_use)
  
  for (i in 1:n_use) {
    m <- use_matches[i, ]
    home_elo <- get_elo(m$home_team_canonical, m$date)
    away_elo <- get_elo(m$away_team_canonical, m$date)
    
    # For away model: elo_diff = away_elo - home_elo
    elo_diffs[i] <- away_elo - home_elo
    away_goals[i] <- m$away_score
  }
  
  training_data <- data.frame(elo_diff = elo_diffs, away_goals = away_goals)
  training_data <- na.omit(training_data)
  
  if (nrow(training_data) == 0) stop("No valid training data")
  
  # Train model
  formula_away <- away_goals ~ elo_diff
  
  away_model <- tryCatch({
    glm.nb(formula_away, data = training_data, control = glm.control(maxit = 50))
  }, error = function(e) {
    tryCatch({
      glm(formula_away, data = training_data, family = poisson)
    }, error = function(e2) {
      message("All models failed, returning NULL")
      return(NULL)
    })
  })
  
  if (is.null(away_model)) stop("Away goal model training failed")
  
  message(paste("Trained on", nrow(training_data), "samples"))
  message(paste("Model type:", class(away_model)))
  
  # Save
  saveRDS(away_model, model_path)
  message(paste("Saved to", model_path))
  
  return(away_model)
}

#' Train both models
#' @export
run_goal_models <- function() {
  home_model <- train_home_goal_model()
  away_model <- train_away_goal_model()
  list(home = home_model, away = away_model)
}
