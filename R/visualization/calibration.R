#' xGelo Visualization - Calibration Plots
#'
#' Generates reliability diagrams for xG and forecast models.
#'
#' @author xGelo project
#' @date 2026-06-04

#' Generate xG model calibration plot
#'
#' @param model_path Path to xG model RDS file
#' @param test_data_path Path to test data RDS file
#' @param output_path Path to save the PNG file
#' @return ggplot object
#' @export
generate_xg_calibration <- function(
    model_path = "models/xg_model.rds",
    test_data_path = "data/processed/xg_test_data.rds",
    output_path = "outputs/visualizations/xg_calibration.png"
) {
  suppressPackageStartupMessages({
    library(ggplot2)
    library(dplyr)
    library(tidymodels)
  })
  
  # Load model and test data
  if (!file.exists(model_path)) {
    stop(paste("xG model not found:", model_path))
  }
  
  if (!file.exists(test_data_path)) {
    stop(paste("Test data not found:", test_data_path))
  }
  
  model <- readRDS(model_path)
  test_data <- readRDS(test_data_path)
  
  # Predict probabilities
  predictions <- predict(model, new_data = test_data, type = "prob")
  
  # Extract goal probability
  goal_col <- if (".pred_Goal" %in% names(predictions)) ".pred_Goal" else names(predictions)[2]
  test_data$xg_pred <- predictions[[goal_col]]
  actual_goal <- if (is.logical(test_data$goal)) {
    as.integer(test_data$goal)
  } else if (is.numeric(test_data$goal)) {
    as.integer(test_data$goal > 0)
  } else {
    as.integer(tolower(as.character(test_data$goal)) %in% c("goal", "true", "1", "yes"))
  }
  test_data$actual_goal <- actual_goal
  
  # Create calibration bins
  n_bins <- 10
  bins <- cut(test_data$xg_pred, 
             breaks = seq(0, 1, length.out = n_bins + 1),
             labels = paste0("(", round(seq(0, 0.9, length.out = n_bins), 2), ", ", 
                           round(seq(0.1, 1, length.out = n_bins), 2), ")"))
  
  calibration_data <- test_data %>%
    mutate(bin = bins) %>%
    group_by(bin) %>%
    summarise(
      mean_predicted = mean(xg_pred, na.rm = TRUE),
      mean_actual = mean(actual_goal, na.rm = TRUE),
      n = n()
    ) %>%
    filter(!is.na(bin) & n > 0)
  
  # Create plot
  p <- ggplot(calibration_data, aes(x = mean_predicted, y = mean_actual)) +
    geom_point(aes(size = n), alpha = 0.7, color = "#45B7D1") +
    geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "#FF0000", linewidth = 1) +
    geom_errorbar(aes(ymin = mean_actual - 2 * sqrt(mean_actual * (1 - mean_actual) / n),
                     ymax = mean_actual + 2 * sqrt(mean_actual * (1 - mean_actual) / n)),
                 width = 0.02, color = "#45B7D1", alpha = 0.5) +
    labs(
      title = "xG Model Calibration Plot",
      subtitle = "Reliability Diagram: Predicted xG vs Actual Goal Rate",
      x = "Mean Predicted xG",
      y = "Mean Actual Goal Rate",
      size = "Sample Size"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
      plot.subtitle = element_text(size = 12, color = "#666666", hjust = 0.5),
      axis.text = element_text(size = 12),
      axis.title = element_text(size = 14, face = "bold"),
      panel.grid = element_blank()
    )
  
  # Ensure output directory exists
  if (!dir.exists(dirname(output_path))) {
    dir.create(dirname(output_path), recursive = TRUE)
  }
  
  # Save plot
  ggsave(output_path, plot = p, width = 10, height = 8, dpi = 300, bg = "white")
  
  message(paste("xG calibration plot saved to", output_path))
  
  return(p)
}

#' Generate forecast model calibration plot
#'
#' @param home_model_path Path to home goal model RDS
#' @param away_model_path Path to away goal model RDS
#' @param matches_path Path to matches CSV file
#' @param output_path Path to save the PNG file
#' @return ggplot object
#' @export
generate_forecast_calibration <- function(
    home_model_path = "models/home_goal_model.rds",
    away_model_path = "models/away_goal_model.rds",
    matches_path = "data/processed/elo_matches.csv",
    output_path = "outputs/visualizations/forecast_calibration.png"
) {
  suppressPackageStartupMessages({
    library(ggplot2)
    library(dplyr)
  })
  if (!exists("simulate_fixture")) {
    source("R/forecast/monte_carlo.R")
  }
  
  if (!file.exists(home_model_path)) {
    stop(paste("Home goal model not found:", home_model_path))
  }
  if (!file.exists(away_model_path)) {
    stop(paste("Away goal model not found:", away_model_path))
  }
  
  # Load matches
  if (!file.exists(matches_path)) {
    stop(paste("Matches data not found:", matches_path))
  }
  matches <- read.csv(matches_path, stringsAsFactors = FALSE)
  matches <- head(matches[!is.na(matches$home_score) & !is.na(matches$away_score), ], 200)
  if (nrow(matches) == 0) stop("No matches available for forecast calibration")
  
  predicted <- numeric(nrow(matches))
  actual <- as.integer(matches$home_score == matches$away_score)
  for (i in seq_len(nrow(matches))) {
    sim <- simulate_fixture(
      home_team = matches$home_team_canonical[i],
      away_team = matches$away_team_canonical[i],
      date = matches$date[i],
      venue = ifelse(isTRUE(matches$neutral[i]), "neutral", "home"),
      home_model_path = home_model_path,
      away_model_path = away_model_path,
      n_sim = 1000,
      seed = 7000 + i
    )
    predicted[i] <- sim$draw_prob
  }
  
  calibration_data <- data.frame(predicted = predicted, actual = actual) |>
    mutate(bin = cut(predicted, breaks = seq(0, 1, length.out = 11), include.lowest = TRUE)) |>
    group_by(bin) |>
    summarise(
      predicted = mean(predicted),
      actual = mean(actual),
      n = n(),
      .groups = "drop"
    ) |>
    filter(!is.na(predicted), !is.na(actual))
  
  # Create plot
  p <- ggplot(calibration_data, aes(x = predicted, y = actual)) +
    geom_point(aes(size = n), alpha = 0.7, color = "#FF6B6B") +
    geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "#FF0000", linewidth = 1) +
    geom_errorbar(aes(ymin = actual - 0.05, ymax = actual + 0.05), 
                 width = 0.02, color = "#FF6B6B", alpha = 0.5) +
    labs(
      title = "Forecast Model Calibration Plot",
      subtitle = "Reliability Diagram: Predicted Probabilities vs Actual Frequencies",
      x = "Mean Predicted Probability",
      y = "Mean Actual Frequency",
      size = "Sample Size"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
      plot.subtitle = element_text(size = 12, color = "#666666", hjust = 0.5),
      axis.text = element_text(size = 12),
      axis.title = element_text(size = 14, face = "bold"),
      panel.grid = element_blank()
    )
  
  # Ensure output directory exists
  if (!dir.exists(dirname(output_path))) {
    dir.create(dirname(output_path), recursive = TRUE)
  }
  
  # Save plot
  ggsave(output_path, plot = p, width = 10, height = 8, dpi = 300, bg = "white")
  
  message(paste("Forecast calibration plot saved to", output_path))
  
  return(p)
}

#' Generate all calibration plots
#' @export
run_calibration_plots <- function() {
  generate_xg_calibration()
  generate_forecast_calibration()
}

# Run on script load
if (interactive()) {
  run_calibration_plots()
}
