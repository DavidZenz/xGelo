#' xGelo Forecasting Layer - Model Calibration
#'
#' Simplified calibration for MVP
#'
#' @author xGelo project
#' @date 2026-06-03

#' Compute Brier score
#' @export
compute_brier_score <- function(predicted, actual) {
  n <- length(predicted)
  if (length(actual) != n) stop("Predicted and actual must have same length")
  if (n == 0) return(NA)
  mean((predicted - actual)^2)
}

#' Quick calibration check
#' @export
calibrate_model <- function(
    matches_data_path = "data/processed/elo_matches.csv",
    n_sample = 1000,
    n_sim = 2000,
    output_path = "outputs/visualizations/forecast_calibration.png"
) {
  
  suppressPackageStartupMessages({
    library(dplyr)
    library(ggplot2)
  })
  if (!exists("simulate_fixture")) {
    source("R/forecast/monte_carlo.R")
  }
  
  message("Running quick calibration check...")
  
  # Load matches
  matches <- read.csv(matches_data_path, stringsAsFactors = FALSE) %>% 
    filter(!is.na(home_score), !is.na(away_score)) %>% 
    head(n_sample)
  if (nrow(matches) == 0) stop("No matches available for calibration")
  
  required_cols <- c("home_team_canonical", "away_team_canonical", "date", "neutral")
  missing_cols <- setdiff(required_cols, names(matches))
  if (length(missing_cols) > 0) {
    stop(paste("Matches data missing required columns:", paste(missing_cols, collapse = ", ")))
  }
  
  predicted_draws <- numeric(nrow(matches))
  actual_outcomes <- as.integer(matches$home_score == matches$away_score)
  
  for (i in seq_len(nrow(matches))) {
    fixture <- matches[i, ]
    sim <- simulate_fixture(
      home_team = fixture$home_team_canonical,
      away_team = fixture$away_team_canonical,
      date = fixture$date,
      venue = ifelse(isTRUE(fixture$neutral), "neutral", "home"),
      n_sim = n_sim,
      seed = 42 + i
    )
    predicted_draws[i] <- sim$draw_prob
  }
  
  actual_draw_rate <- mean(actual_outcomes)
  mean_predicted_draw <- mean(predicted_draws)
  brier_score <- compute_brier_score(predicted_draws, actual_outcomes)
  
  message(paste("Actual draw rate:", round(actual_draw_rate, 3)))
  message(paste("Predicted draw rate:", round(mean_predicted_draw, 3)))
  message(paste("Brier score:", round(brier_score, 4)))
  
  plot_data <- data.frame(
    predicted = predicted_draws,
    actual = actual_outcomes
  ) %>%
    mutate(bin = cut(predicted, breaks = seq(0, 1, length.out = 11), include.lowest = TRUE)) %>%
    group_by(bin) %>%
    summarise(
      predicted = mean(predicted),
      actual = mean(actual),
      n = n(),
      .groups = "drop"
    ) %>%
    filter(!is.na(predicted), !is.na(actual))
  
  # Save plot
  if (!dir.exists(dirname(output_path))) {
    dir.create(dirname(output_path), recursive = TRUE)
  }
  
  p <- ggplot(plot_data, aes(x = predicted, y = actual, size = n)) +
    geom_point() +
    geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "red") +
    xlab("Predicted probability") +
    ylab("Actual frequency") +
    ggtitle("Calibration Plot - Draw Probability") +
    theme_minimal()
  
  ggsave(output_path, plot = p, width = 8, height = 6)
  message(paste("Calibration plot saved to", output_path))
  
  list(
    actual_draw_rate = actual_draw_rate,
    predicted_draw_rate = mean_predicted_draw,
    brier_score = brier_score,
    n_matches = nrow(matches),
    calibration_plot_path = output_path
  )
}

#' Wrapper
#' @export
run_calibration <- function() {
  result <- calibrate_model()
  cat("\nCalibration Results:\n")
  cat("  Actual draw rate:", round(result$actual_draw_rate, 3), "\n")
  cat("  Predicted draw rate:", round(result$predicted_draw_rate, 3), "\n")
  cat("  Brier score:", round(result$brier_score, 4), "\n")
  cat("  Plot saved to:", result$calibration_plot_path, "\n")
  return(result)
}
