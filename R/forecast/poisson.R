#' xGelo Forecasting Layer - Goal Models
#'
#' Simplified implementation for MVP. Uses Elo differences to predict goals.
#'
#' @author xGelo project
#' @date 2026-06-03

#' Baseline goal-model predictors
#'
#' @return Character vector of baseline predictor columns
#' @export
baseline_goal_predictors <- function() {
  c("elo_diff", "xgf_ewma_diff", "xga_ewma_diff", "xgd_ewma_diff", "form_index_diff")
}

#' Elo-only incumbent ablation predictors
#'
#' @return Character vector containing the registered Elo predictor
#' @export
elo_only_goal_predictors <- function() {
  "elo_diff"
}

#' Hybrid goal-model predictors
#'
#' @return Character vector of hybrid predictor columns
#' @export
hybrid_goal_predictors <- function() {
  c(
    baseline_goal_predictors(),
    "attack_ability_diff", "defense_ability_diff",
    "log_squad_value_diff", "log_top11_value_diff", "log_top15_value_diff",
    "median_player_value_diff", "total_caps_diff", "total_goals_diff",
    "log_top23_value_diff", "top5_value_share_diff", "top11_to_top23_ratio_diff", "value_drop_11_to_23_diff",
    "value_weighted_avg_age_diff", "top11_avg_age_diff", "top11_u24_value_share_diff", "top11_over30_value_share_diff",
    "log_top1_goalkeeper_value_diff", "log_top4_defense_value_diff", "log_top4_midfield_value_diff",
    "log_top3_attack_value_diff", "defense_value_share_diff", "midfield_value_share_diff", "attack_value_share_diff",
    "squad_value_momentum_6m_diff", "squad_value_momentum_12m_diff",
    "top11_value_momentum_6m_diff", "top11_value_momentum_12m_diff"
  )
}

#' Train one goal model from a prepared match feature table
#'
#' @param feature_table Match-level feature table
#' @param side One of "home" or "away"
#' @param predictors Candidate predictor columns
#' @param model_path Optional RDS output path
#' @param model_version Model version tag stored as an attribute
#' @return Fitted negative-binomial or Poisson model
#' @export
train_goal_model_from_features <- function(
    feature_table,
    side = c("home", "away"),
    predictors = NULL,
    model_path = NULL,
    model_version = "hybrid"
) {
  suppressPackageStartupMessages({
    library(MASS)
  })
  side <- match.arg(side)
  response <- if (side == "home") "home_goals" else "away_goals"
  if (!response %in% names(feature_table)) {
    stop(paste("Feature table missing response column:", response))
  }
  if (is.null(predictors)) {
    predictors <- hybrid_goal_predictors()
  }
  if (!"elo_diff" %in% names(feature_table)) feature_table$elo_diff <- 0
  predictors <- intersect(predictors, names(feature_table))
  predictors <- predictors[vapply(feature_table[predictors], function(x) {
    values <- suppressWarnings(as.numeric(x))
    any(is.finite(values)) && stats::sd(values, na.rm = TRUE) > 0
  }, logical(1))]
  if (length(predictors) == 0) predictors <- "elo_diff"
  predictors <- unique(c("elo_diff", predictors))

  model_data <- feature_table[, unique(c(response, predictors)), drop = FALSE]
  for (predictor in predictors) {
    model_data[[predictor]] <- suppressWarnings(as.numeric(model_data[[predictor]]))
    model_data[[predictor]][!is.finite(model_data[[predictor]])] <- 0
  }
  model_data[[response]] <- suppressWarnings(as.numeric(model_data[[response]]))
  model_data <- model_data[is.finite(model_data[[response]]), , drop = FALSE]
  if (nrow(model_data) == 0) stop("No valid training data")

  formula <- stats::as.formula(paste(response, "~", paste(predictors, collapse = " + ")))
  model <- tryCatch({
    MASS::glm.nb(formula, data = model_data, control = glm.control(maxit = 50))
  }, error = function(e) {
    stats::glm(formula, data = model_data, family = poisson)
  })
  attr(model, "xgelo_predictors") <- predictors
  attr(model, "xgelo_feature_perspective") <- "home"
  attr(model, "xgelo_goal_side") <- side
  attr(model, "xgelo_model_version") <- model_version
  if (!is.null(model_path)) {
    saveRDS(model, model_path)
  }
  model
}

#' Train home goal model - simplified version
#' Uses a small sample for speed, with Elo difference as predictor
#' @export
train_home_goal_model <- function(
    data_path = "data/processed/elo_matches.csv",
    elo_ratings_path = "data/processed/elo_ratings.csv",
    model_path = "models/home_goal_model.rds",
    n_sample = 5000,
    feature_table = NULL,
    feature_table_path = NULL,
    predictors = NULL,
    model_version = "baseline"
) {
  
  suppressPackageStartupMessages({
    library(MASS)
    library(dplyr)
  })
  
  message("Training home goal model...")
  if (!is.null(feature_table_path) && file.exists(feature_table_path)) {
    feature_table <- read.csv(feature_table_path, stringsAsFactors = FALSE)
  }
  if (!is.null(feature_table)) {
    home_model <- train_goal_model_from_features(
      feature_table = feature_table,
      side = "home",
      predictors = predictors,
      model_path = model_path,
      model_version = model_version
    )
    message(paste("Trained feature-based home model on", nrow(feature_table), "samples"))
    return(home_model)
  }
  
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

  attr(home_model, "xgelo_predictors") <- "elo_diff"
  attr(home_model, "xgelo_feature_perspective") <- "home"
  attr(home_model, "xgelo_goal_side") <- "home"
  attr(home_model, "xgelo_model_version") <- model_version
  
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
    n_sample = 5000,
    feature_table = NULL,
    feature_table_path = NULL,
    predictors = NULL,
    model_version = "baseline"
) {
  
  suppressPackageStartupMessages({
    library(MASS)
    library(dplyr)
  })
  
  message("Training away goal model...")
  if (!is.null(feature_table_path) && file.exists(feature_table_path)) {
    feature_table <- read.csv(feature_table_path, stringsAsFactors = FALSE)
  }
  if (!is.null(feature_table)) {
    away_model <- train_goal_model_from_features(
      feature_table = feature_table,
      side = "away",
      predictors = predictors,
      model_path = model_path,
      model_version = model_version
    )
    message(paste("Trained feature-based away model on", nrow(feature_table), "samples"))
    return(away_model)
  }
  
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

  attr(away_model, "xgelo_predictors") <- "elo_diff"
  attr(away_model, "xgelo_feature_perspective") <- "home"
  attr(away_model, "xgelo_goal_side") <- "away"
  attr(away_model, "xgelo_model_version") <- model_version
  
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
