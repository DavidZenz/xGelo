#' xGelo: xG Model Training
#'
#' Script for training logistic regression xG model with natural splines.

#' Train xG Model
#'
#' @description Trains a logistic regression model with natural splines for xG prediction.
#'
#' @param train_data Data frame with training data (must have columns: distance, angle, header, open_play, competition, goal)
#' @param deg_free Integer degrees of freedom for natural splines (default: 4)
#' @return A fitted tidymodels workflow object
#' @export
train_xg_model <- function(train_data, deg_free = 4) {
  library(tidymodels)
  
  # Validate input
  required_cols <- c("distance", "angle", "header", "open_play", "competition", "goal")
  missing_cols <- setdiff(required_cols, names(train_data))
  if (length(missing_cols) > 0) {
    stop(paste("Missing required columns:", paste(missing_cols, collapse = ", ")))
  }
  
  if (nrow(train_data) == 0) {
    stop("train_data must have at least one row")
  }
  
  # Ensure goal is a factor for classification
  if (is.logical(train_data$goal)) {
    train_data$goal <- factor(train_data$goal, levels = c(FALSE, TRUE), labels = c("No Goal", "Goal"))
  } else if (!is.factor(train_data$goal)) {
    train_data$goal <- factor(train_data$goal)
  }
  
  # Create recipe using standard pipe
  # Note: step_dummy requires at least 2 levels for categorical variables
  # If competition has only 1 level, we need to filter it out or use step_zv first
  recipe_spec <- recipe(goal ~ distance + angle + header + open_play + competition, 
                        data = train_data)
  
  recipe_spec <- step_ns(recipe_spec, distance, deg_free = deg_free)
  recipe_spec <- step_ns(recipe_spec, angle, deg_free = deg_free)
  recipe_spec <- step_zv(recipe_spec, all_predictors())  # Remove zero-variance predictors first
  recipe_spec <- step_dummy(recipe_spec, all_nominal_predictors(), -all_outcomes())
  
  # Create model specification
  model_spec <- logistic_reg() |>
    set_engine("glm") |>
    set_mode("classification")
  
  # Create workflow
  xg_workflow <- workflow() |>
    add_recipe(recipe_spec) |>
    add_model(model_spec)
  
  # Fit model
  cat("Training xG model...\n")
  xg_fit <- fit(xg_workflow, data = train_data)
  
  cat("Model trained successfully!\n")
  
  return(xg_fit)
}

#' Predict xG Probabilities
#'
#' @description Generates xG predictions from a trained model.
#'
#' @param model A fitted tidymodels workflow object
#' @param new_data Data frame with new data (same features as training data)
#' @return A numeric vector of predicted xG probabilities
#' @export
predict_xg <- function(model, new_data) {
  # Validate model
  if (!inherits(model, "workflow")) {
    stop("model must be a tidymodels workflow object")
  }
  
  # Validate new_data has required features
  required_features <- c("distance", "angle", "header", "open_play", "competition")
  missing_features <- setdiff(required_features, names(new_data))
  if (length(missing_features) > 0) {
    stop(paste("Missing required features:", paste(missing_features, collapse = ", ")))
  }
  
  # Predict
  predictions <- predict(model, new_data = new_data, type = "prob")
  
  # Extract probability of goal
  # predictions is a tibble with columns for each level of the outcome
  # Column names are typically ".pred_No Goal" and ".pred_Goal" for factor levels "No Goal" and "Goal"
  
  # Try to find the goal probability column
  goal_col <- NULL
  
  # Check for standard tidymodels column names
  if (".pred_Goal" %in% names(predictions)) {
    goal_col <- ".pred_Goal"
  } else if (".pred_TRUE" %in% names(predictions)) {
    goal_col <- ".pred_TRUE"
  } else if (".pred_1" %in% names(predictions)) {
    goal_col <- ".pred_1"
  } else if (ncol(predictions) == 2) {
    # Binary outcome: second column is typically the positive class
    goal_col <- names(predictions)[2]
  } else {
    # Try to find any column containing "Goal" or "TRUE"
    goal_col <- grep("Goal|TRUE|1", names(predictions), ignore.case = TRUE, value = TRUE)
    if (length(goal_col) > 0) {
      goal_col <- goal_col[1]
    }
  }
  
  if (is.null(goal_col)) {
    stop("Could not determine which column contains goal probabilities")
  }
  
  return(predictions[[goal_col]])
}

#' Train and Save xG Model
#'
#' @description Convenience function to train model and save to disk.
#'
#' @param train_data Data frame with training data
#' @param output_path Character string path to save model (default: "models/xg_model.rds")
#' @param deg_free Integer degrees of freedom for natural splines (default: 4)
#' @return A fitted tidymodels workflow object
#' @export
train_and_save_xg_model <- function(train_data, output_path = "models/xg_model.rds", deg_free = 4) {
  # Train model
  model <- train_xg_model(train_data, deg_free = deg_free)
  
  # Save model
  if (!dir.exists(dirname(output_path))) {
    dir.create(dirname(output_path), recursive = TRUE)
  }
  
  saveRDS(model, output_path)
  cat(sprintf("Model saved to %s\n", output_path))
  
  return(model)
}
