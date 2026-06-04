#' Elo Parameter Tuning for xGelo
#'
#' This script implements rolling-origin validation for Elo rating system.
#' It tests different parameter combinations (k-factor, home advantage, decay)
#' and selects the best performing parameters.
#'
#' @author xGelo project
#' @date 2026-06-03

#' Perform rolling-origin validation for Elo ratings
#'
#' @param matches_df Data frame with preprocessed match data
#' @param team_map_df Data frame with team name mapping
#' @param test_years Number of years to use as test period (default: 1)
#' @param k_factors Vector of k-factors to test (default: c(20, 30, 40))
#' @param home_advantages Vector of home advantages to test (default: c(40, 60, 80))
#' @param decay_factors Vector of decay factors to test (default: c(0.99, 0.995, 0.999))
#' @param output_path Path to save validation results (default: "outputs/model_performance/elo_validation.csv")
#' @return Data frame with validation results for each parameter combination
#' @export
rolling_origin_validation <- function(matches_df, team_map_df,
                                      test_years = 1,
                                      k_factors = c(20, 30, 40),
                                      home_advantages = c(40, 60, 80),
                                      decay_factors = c(0.99, 0.995, 0.999),
                                      output_path = "outputs/model_performance/elo_validation.csv") {
  
  suppressPackageStartupMessages({
    library(dplyr)
    library(lubridate)
    library(pROC)
  })
  
  # Source the Elo runner functions
  source("R/elo/runner.R")
  
  # Validate inputs
  if (nrow(matches_df) == 0) {
    stop("matches_df must contain at least one match")
  }
  
  # Convert dates if needed
  if (!inherits(matches_df$date, "Date")) {
    matches_df <- matches_df |>
      mutate(date = as.Date(date))
  }
  
  # Sort by date
  matches_df <- matches_df |>
    arrange(date)
  
  # Determine test period start date
  test_start_date <- max(matches_df$date) - (test_years * 365)
  
  # Split into train and test
  train_matches <- matches_df[matches_df$date < test_start_date, ]
  test_matches <- matches_df[matches_df$date >= test_start_date, ]
  
  message(paste("Training period:", min(train_matches$date), "to", max(train_matches$date)))
  message(paste("Test period:", min(test_matches$date), "to", max(test_matches$date)))
  message(paste("Training matches:", nrow(train_matches)))
  message(paste("Test matches:", nrow(test_matches)))
  
  # Create custom apply_decay function for testing different decay factors
  create_decay_function <- function(decay_factor) {
    function(rating, days_since_last) {
      if (missing(days_since_last) || is.na(days_since_last)) {
        return(rating)
      }
      rating * (decay_factor ^ (days_since_last / 365))
    }
  }
  
  # Create custom compute_elo function for testing different parameters
  compute_elo_with_params <- function(matches_data, team_map_data, 
                                     k_factor_val = 20, 
                                     home_advantage_val = 60,
                                     decay_factor_val = 0.995) {
    
    # Use the custom decay function
    apply_decay_custom <- create_decay_function(decay_factor_val)
    
    # Modified get_k_factor that returns a constant for testing
    get_k_factor_custom <- function(matches_last_year, matches_this_year) {
      return(k_factor_val)
    }
    
    # Modified elo_update with custom home advantage
    elo_update_custom <- function(rating_a, rating_b, actual_result, k_factor_a, k_factor_b, 
                                   home_advantage = home_advantage_val, is_home = TRUE) {
      if (is_home) {
        rating_a_adj <- rating_a + home_advantage
        rating_b_adj <- rating_b
      } else {
        rating_a_adj <- rating_a
        rating_b_adj <- rating_b + home_advantage
      }
      
      exp_a <- expected_result(rating_a_adj, rating_b_adj)
      exp_b <- 1 - exp_a
      
      rating_a_new <- rating_a + k_factor_a * (actual_result - exp_a)
      rating_b_new <- rating_b + k_factor_b * ((1 - actual_result) - exp_b)
      
      list(rating_a = rating_a_new, rating_b = rating_b_new)
    }
    
    # Initialize ratings
    all_teams <- unique(c(matches_data$home_team_canonical, matches_data$away_team_canonical))
    
    current_ratings <- data.frame(
      team = all_teams,
      fifa_code = sapply(all_teams, function(t) {
        idx <- which(team_map_data$canonical_name == t)
        if (length(idx) > 0) {
          team_map_data$fifa_code[idx]
        } else {
          NA_character_
        }
      }),
      rating = 1500,
      last_match_date = as.Date(NA),
      stringsAsFactors = FALSE
    )
    
    # Process each match
    for (i in 1:nrow(matches_data)) {
      match <- matches_data[i, ]
      home_team <- match$home_team_canonical
      away_team <- match$away_team_canonical
      match_date <- match$date
      is_home <- match$is_home
      result <- match$result
      
      home_idx <- which(current_ratings$team == home_team)
      away_idx <- which(current_ratings$team == away_team)
      
      if (length(home_idx) == 0 || length(away_idx) == 0) {
        next
      }
      
      home_rating <- current_ratings$rating[home_idx]
      away_rating <- current_ratings$rating[away_idx]
      
      # Apply decay
      if (!is.na(current_ratings$last_match_date[home_idx])) {
        days_since_home <- as.numeric(difftime(match_date,
                                              current_ratings$last_match_date[home_idx],
                                              units = "days"))
        home_rating <- apply_decay_custom(home_rating, days_since_home)
      }
      
      if (!is.na(current_ratings$last_match_date[away_idx])) {
        days_since_away <- as.numeric(difftime(match_date,
                                              current_ratings$last_match_date[away_idx],
                                              units = "days"))
        away_rating <- apply_decay_custom(away_rating, days_since_away)
      }
      
      current_ratings$rating[home_idx] <- home_rating
      current_ratings$rating[away_idx] <- away_rating
      
      k_home <- k_factor_val
      k_away <- k_factor_val
      
      update <- elo_update_custom(home_rating, away_rating, result, k_home, k_away, 
                                   home_advantage_val, is_home)
      
      current_ratings$rating[home_idx] <- update$rating_a
      current_ratings$rating[away_idx] <- update$rating_b
      current_ratings$last_match_date[home_idx] <- match_date
      current_ratings$last_match_date[away_idx] <- match_date
    }
    
    current_ratings
  }
  
  # Function to run validation for a single parameter combination
  validate_params <- function(k_val, ha_val, decay_val, train_data, test_data, team_map_data) {
    message(paste("Testing: k =", k_val, ", home_advantage =", ha_val, ", decay =", decay_val))
    
    # Compute ratings using training data
    train_ratings <- compute_elo_with_params(train_data, team_map_data,
                                              k_val, ha_val, decay_val)
    
    # For each test match, predict result using pre-match ratings
    predictions <- list()
    actuals <- list()
    match_dates <- list()
    
    for (i in 1:nrow(test_data)) {
      test_match <- test_data[i, ]
      home_team <- test_match$home_team_canonical
      away_team <- test_match$away_team_canonical
      match_date <- test_match$date
      is_home <- test_match$is_home
      actual_result <- test_match$result
      
      # Get ratings from training period (before this match)
      train_before <- train_data[train_data$date < match_date, ]
      
      if (nrow(train_before) == 0) {
        # No training data before this match, use base ratings
        home_rating <- 1500
        away_rating <- 1500
      } else {
        # Compute ratings using only data before this match
        ratings_before <- compute_elo_with_params(train_before, team_map_data,
                                                    k_val, ha_val, decay_val)
        
        home_idx <- which(ratings_before$team == home_team)
        away_idx <- which(ratings_before$team == away_team)
        
        if (length(home_idx) > 0) {
          home_rating <- ratings_before$rating[home_idx]
        } else {
          home_rating <- 1500
        }
        
        if (length(away_idx) > 0) {
          away_rating <- ratings_before$rating[away_idx]
        } else {
          away_rating <- 1500
        }
      }
      
      # Apply home advantage for prediction
      if (is_home) {
        home_rating_adj <- home_rating + ha_val
        away_rating_adj <- away_rating
      } else {
        home_rating_adj <- home_rating
        away_rating_adj <- away_rating + ha_val
      }
      
      # Predict probability of home win
      # Note: actual_result is from home perspective (1=home win, 0=home loss, 0.5=draw)
      # We predict probability of home win
      pred_prob <- expected_result(home_rating_adj, away_rating_adj)
      
      predictions[[i]] <- pred_prob
      actuals[[i]] <- actual_result
      match_dates[[i]] <- match_date
    }
    
    # Calculate metrics
    pred_vec <- unlist(predictions)
    actual_vec <- unlist(actuals)
    
    # For AUC, we need binary outcomes. We'll use:
    # - Home win (actual = 1): positive class
    # - Draw (actual = 0.5): we can either exclude or treat as partial
    # - Away win (actual = 0): negative class
    
    # For binary AUC, let's predict home win vs not home win (draw + away win)
    binary_actual <- ifelse(actual_vec == 1, 1, 0)
    
    # For calibration, use the continuous predictions
    # For Brier score
    brier_score <- mean((pred_vec - binary_actual)^2)
    
    # For accuracy, use threshold of 0.5
    predicted_wins <- ifelse(pred_vec >= 0.5, 1, 0)
    accuracy <- mean(predicted_wins == binary_actual)
    
    # Calculate AUC
    if (length(unique(binary_actual)) < 2) {
      auc_val <- NA
    } else {
      roc_obj <- pROC::roc(binary_actual, pred_vec)
      auc_val <- pROC::auc(roc_obj)
    }
    
    # Return results
    list(
      k_factor = k_val,
      home_advantage = ha_val,
      decay_factor = decay_val,
      auc = auc_val,
      accuracy = accuracy,
      brier_score = brier_score,
      num_test_matches = length(pred_vec)
    )
  }
  
  # Run validation for all parameter combinations
  all_results <- list()
  
  for (k_val in k_factors) {
    for (ha_val in home_advantages) {
      for (decay_val in decay_factors) {
        result <- validate_params(k_val, ha_val, decay_val, 
                                  train_matches, test_matches, team_map_df)
        all_results[[length(all_results) + 1]] <- result
        
        message(paste("Completed: k =", k_val, ", ha =", ha_val, ", decay =", decay_val,
                       "| AUC =", round(result$auc, 4), ", Accuracy =", round(result$accuracy, 4)))
      }
    }
  }
  
  # Convert to data frame
  results_df <- do.call(rbind, lapply(all_results, as.data.frame))
  
  # Sort by AUC (descending)
  results_df <- results_df |>
    arrange(desc(auc))
  
  # Save results
  if (!dir.exists(dirname(output_path))) {
    dir.create(dirname(output_path), recursive = TRUE)
  }
  
  write.csv(results_df, output_path, row.names = FALSE)
  
  # Identify best parameters
  best_params <- results_df[1, ]
  message(paste("\n=== Best Parameters ==="))
  message(paste("k_factor:", best_params$k_factor))
  message(paste("home_advantage:", best_params$home_advantage))
  message(paste("decay_factor:", best_params$decay_factor))
  message(paste("AUC:", round(best_params$auc, 4)))
  message(paste("Accuracy:", round(best_params$accuracy, 4)))
  message(paste("Brier Score:", round(best_params$brier_score, 4)))
  
  results_df
}

#' Run Elo tuning with default parameters
#'
#' @param matches_path Path to preprocessed matches CSV
#' @param team_map_path Path to team name mapping CSV
#' @param output_path Path to save validation results
#' @return Path to output file
#' @export
tune_elo <- function(matches_path = "data/processed/elo_matches.csv",
                     team_map_path = "data/raw/team_name_map.csv",
                     output_path = "outputs/model_performance/elo_validation.csv") {
  
  # Load data
  matches_df <- read.csv(matches_path, stringsAsFactors = FALSE)
  team_map_df <- read.csv(team_map_path, stringsAsFactors = FALSE)
  
  # Run validation
  result <- rolling_origin_validation(matches_df, team_map_df, 
                                     output_path = output_path)
  
  invisible(output_path)
}
