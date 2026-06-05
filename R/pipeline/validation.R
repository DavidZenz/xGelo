#' Pipeline Validation Functions for xGelo
#'
#' @author xGelo project
#' @date 2026-06-04

#' Validate schema of a CSV file
#' @param path Path to CSV file
#' @param required_cols Vector of required column names
#' @return TRUE if valid, FALSE otherwise
#' @export
validate_schema <- function(path, required_cols = NULL) {
  if (!file.exists(path)) {
    message(paste("File not found:", path))
    return(FALSE)
  }
  
  data <- tryCatch({
    read.csv(path, stringsAsFactors = FALSE)
  }, error = function(e) {
    message(paste("Error reading file:", path, "-", e$message))
    return(FALSE)
  })
  
  if (nrow(data) == 0) {
    message(paste("File is empty:", path))
    return(FALSE)
  }
  
  if (!is.null(required_cols)) {
    missing_cols <- setdiff(required_cols, names(data))
    if (length(missing_cols) > 0) {
      message(paste("Missing columns in", path, ":", paste(missing_cols, collapse = ", ")))
      return(FALSE)
    }
  }
  
  return(TRUE)
}

#' Validate xG values
#' @param path Path to team_match_xg.csv
#' @return TRUE if valid, FALSE otherwise
#' @export
validate_xg_values <- function(path) {
  if (!file.exists(path)) {
    message(paste("File not found:", path))
    return(FALSE)
  }
  
  data <- read.csv(path, stringsAsFactors = FALSE)
  
  xg_cols <- c("xGF", "xGA", "xGD")
  if (!all(xg_cols %in% names(data))) {
    message(paste("Missing xG columns:", paste(setdiff(xg_cols, names(data)), collapse = ", ")))
    return(FALSE)
  }
  
  if (any(data$xGF < 0, na.rm = TRUE) || any(data$xGA < 0, na.rm = TRUE)) {
    message("Negative xG values found")
    return(FALSE)
  }
  
  return(TRUE)
}

#' Validate probabilities
#' @param dir Directory containing forecast CSV files
#' @return TRUE if valid, FALSE otherwise
#' @export
validate_probabilities <- function(dir) {
  if (!dir.exists(dir)) {
    message(paste("Directory not found:", dir))
    return(FALSE)
  }
  
  csv_files <- list.files(dir, pattern = "\\.csv$", full.names = TRUE)
  
  if (length(csv_files) == 0) {
    message(paste("No CSV files found in:", dir))
    return(FALSE)
  }
  
  required_cols <- c("win_probability", "draw_probability", "loss_probability")
  
  all_valid <- TRUE
  for (file in csv_files) {
    data <- read.csv(file, stringsAsFactors = FALSE)
    
    if (!all(required_cols %in% names(data))) {
      message(paste("Missing probability columns in:", file))
      all_valid <- FALSE
      next
    }
    
    prob_sums <- data$win_probability + data$draw_probability + data$loss_probability
    if (any(abs(prob_sums - 1) > 0.001, na.rm = TRUE)) {
      message(paste("Probabilities don't sum to 1 in:", file))
      all_valid <- FALSE
    }
    
    if (any(data$win_probability < 0 | data$win_probability > 1, na.rm = TRUE) ||
        any(data$draw_probability < 0 | data$draw_probability > 1, na.rm = TRUE) ||
        any(data$loss_probability < 0 | data$loss_probability > 1, na.rm = TRUE)) {
      message(paste("Invalid probability values in:", file))
      all_valid <- FALSE
    }
  }
  
  return(all_valid)
}

#' Run all validation checks
#' @return List of validation results
#' @export
run_all_validations <- function() {
  results <- list()
  
  results$data_raw <- list(
    results.csv = validate_schema("data/raw/martj42/results.csv", c("date", "home_team", "away_team", "home_score", "away_score")),
    events = file.exists("data/raw/statsbomb/events/15946.json"),
    competitions = file.exists("data/raw/statsbomb/competitions.json")
  )
  
  results$data_clean <- list(
    elo_matches = validate_schema("data/processed/elo_matches.csv", c("date", "home_team", "away_team", "home_score", "away_score")),
    elo_ratings = validate_schema("data/processed/elo_ratings.csv", c("date", "team", "rating")),
    team_match_xg = validate_xg_values("data/processed/team_match_xg.csv"),
    rolling_form = validate_schema("data/processed/rolling_form.csv", c("team", "match_date", "xgf_ewma"))
  )
  
  results$models <- list(
    xg_model = file.exists("models/xg_model.rds"),
    home_goal_model = file.exists("models/home_goal_model.rds"),
    away_goal_model = file.exists("models/away_goal_model.rds")
  )
  
  results$forecasts <- list(
    forecasts_valid = validate_probabilities("outputs/forecasts"),
    calibration_plot = file.exists("outputs/visualizations/forecast_calibration.png")
  )
  
  return(results)
}

#' Wrapper to run validations and print results
#' @export
run_validation_checks <- function() {
  results <- run_all_validations()
  
  cat("\n=== Pipeline Validation Results ===\n\n")
  
  cat("Raw Data:\n")
  cat("  results.csv:", ifelse(results$data_raw$results.csv, "PASS", "FAIL"), "\n")
  cat("  events:", ifelse(results$data_raw$events, "PASS", "FAIL"), "\n")
  cat("  competitions:", ifelse(results$data_raw$competitions, "PASS", "FAIL"), "\n\n")
  
  cat("Processed Data:\n")
  cat("  elo_matches.csv:", ifelse(results$data_clean$elo_matches, "PASS", "FAIL"), "\n")
  cat("  elo_ratings.csv:", ifelse(results$data_clean$elo_ratings, "PASS", "FAIL"), "\n")
  cat("  team_match_xg.csv:", ifelse(results$data_clean$team_match_xg, "PASS", "FAIL"), "\n")
  cat("  rolling_form.csv:", ifelse(results$data_clean$rolling_form, "PASS", "FAIL"), "\n\n")
  
  cat("Models:\n")
  cat("  xg_model.rds:", ifelse(results$models$xg_model, "PASS", "FAIL"), "\n")
  cat("  home_goal_model.rds:", ifelse(results$models$home_goal_model, "PASS", "FAIL"), "\n")
  cat("  away_goal_model.rds:", ifelse(results$models$away_goal_model, "PASS", "FAIL"), "\n\n")
  
  cat("Forecasts:\n")
  cat("  probability sums:", ifelse(results$forecasts$forecasts_valid, "PASS", "FAIL"), "\n")
  cat("  calibration plot:", ifelse(results$forecasts$calibration_plot, "PASS", "FAIL"), "\n")
  
  all_pass <- all(unlist(results))
  cat("\n=== Overall:", ifelse(all_pass, "ALL CHECKS PASSED", "SOME CHECKS FAILED"), "===\n")
  
  return(list(all_passed = all_pass, results = results))
}
