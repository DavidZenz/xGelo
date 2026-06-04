#' Elo Validation for xGelo
#'
#' This script performs validation of the Elo rating system
#' using a simple time-based split.
#'
#' @author xGelo project
#' @date 2026-06-03

#' Perform simple validation of Elo ratings
#'
#' @param matches_path Path to preprocessed matches CSV
#' @param team_map_path Path to team name mapping CSV
#' @param ratings_path Path to computed Elo ratings CSV
#' @param output_path Path to save validation results
#' @return Data frame with validation results
#' @export
validate_elo <- function(matches_path = "data/processed/elo_matches.csv",
                        team_map_path = "data/raw/team_name_map.csv",
                        ratings_path = "data/processed/elo_ratings.csv",
                        output_path = "outputs/model_performance/elo_validation.csv") {
  
  suppressPackageStartupMessages({
    library(dplyr)
    library(lubridate)
    library(pROC)
  })
  
  source("R/elo/runner_optimized.R")
  
  # Load data
  matches_df <- read.csv(matches_path, stringsAsFactors = FALSE)
  matches_df$date <- as.Date(matches_df$date)
  
  team_map <- read.csv(team_map_path, stringsAsFactors = FALSE)
  
  # Split into train and test (last 6 months)
  test_start <- max(matches_df$date) - 180
  
  train_matches <- matches_df[matches_df$date < test_start, ]
  test_matches <- matches_df[matches_df$date >= test_start, ]
  
  message(paste("Training period:", min(train_matches$date), "to", max(train_matches$date)))
  message(paste("Test period:", min(test_matches$date), "to", max(test_matches$date)))
  message(paste("Training matches:", nrow(train_matches)))
  message(paste("Test matches:", nrow(test_matches)))
  
  # Compute ratings on training data only
  result <- compute_elo_optimized(train_matches, team_map, home_advantage = 60)
  
  train_ratings <- result$current_ratings
  
  # For each test match, predict result using training ratings
  predictions <- numeric(nrow(test_matches))
  actuals_binary <- numeric(nrow(test_matches))  # 1 = home win, 0 = not home win
  
  for (i in 1:nrow(test_matches)) {
    match <- test_matches[i, ]
    home_team <- match$home_team_canonical
    away_team <- match$away_team_canonical
    is_home <- match$is_home
    actual_result <- match$result
    
    # Get ratings
    home_idx <- which(train_ratings$team == home_team)
    away_idx <- which(train_ratings$team == away_team)
    
    if (length(home_idx) == 0 || length(away_idx) == 0) {
      predictions[i] <- NA
      actuals_binary[i] <- NA
      next
    }
    
    home_rating <- train_ratings$rating[home_idx]
    away_rating <- train_ratings$rating[away_idx]
    
    # Apply home advantage
    if (is_home) {
      home_rating_adj <- home_rating + 60
      away_rating_adj <- away_rating
    } else {
      home_rating_adj <- home_rating
      away_rating_adj <- away_rating + 60
    }
    
    # Predict probability of home win
    predictions[i] <- expected_result(home_rating_adj, away_rating_adj)
    
    # Actual: 1 = home win, 0 = home loss or draw
    # For simplicity, we'll treat draw as 0 (not home win)
    actuals_binary[i] <- ifelse(actual_result == 1, 1, 0)
  }
  
  # Remove NA values
  valid_idx <- complete.cases(predictions, actuals_binary)
  pred_valid <- predictions[valid_idx]
  actual_valid <- actuals_binary[valid_idx]
  
  # Calculate metrics
  if (length(unique(actual_valid)) < 2) {
    auc_val <- NA
  } else {
    roc_obj <- pROC::roc(actual_valid, pred_valid)
    auc_val <- pROC::auc(roc_obj)
  }
  
  accuracy <- mean(as.integer(pred_valid >= 0.5) == actual_valid)
  brier_score <- mean((pred_valid - actual_valid)^2)
  
  # Create validation results
  validation_results <- data.frame(
    date = test_matches$date[valid_idx],
    home_team = test_matches$home_team_canonical[valid_idx],
    away_team = test_matches$away_team_canonical[valid_idx],
    predicted_prob = pred_valid,
    actual_result = test_matches$result[valid_idx],
    actual_binary = actual_valid,
    stringsAsFactors = FALSE
  )
  
  # Save results
  if (!dir.exists(dirname(output_path))) {
    dir.create(dirname(output_path), recursive = TRUE)
  }
  write.csv(validation_results, output_path, row.names = FALSE)
  
  # Print summary
  message(paste("\n=== Validation Results ==="))
  message(paste("Test matches:", length(pred_valid)))
  message(paste("AUC:", round(auc_val, 4)))
  message(paste("Accuracy:", round(accuracy, 4)))
  message(paste("Brier Score:", round(brier_score, 4)))
  
  # Return metrics
  list(
    validation_data = validation_results,
    auc = auc_val,
    accuracy = accuracy,
    brier_score = brier_score,
    num_test_matches = length(pred_valid)
  )
}

#' Run validation and save results
#' @export
run_validation <- function() {
  result <- validate_elo()
  invisible(result)
}
