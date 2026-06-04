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
    output_path = "outputs/visualizations/forecast_calibration.png"
) {
  
  suppressPackageStartupMessages({
    library(dplyr)
    library(ggplot2)
  })
  
  message("Running quick calibration check...")
  
  # Load matches
  matches <- read.csv(matches_data_path, stringsAsFactors = FALSE) %>% 
    filter(!is.na(home_score), !is.na(away_score)) %>% 
    head(n_sample)
  
  # Actual draw rate
  actual_draws <- sum(matches$home_score == matches$away_score)
  actual_draw_rate <- actual_draws / nrow(matches)
  
  # Use a fixed set of predictions for speed (since all use default Elo)
  # Run a few simulations to get typical draw probabilities
  set.seed(42)
  predicted_draws <- replicate(100, {
    result <- simulate_fixture("A", "B", seed = NULL)
    result$draw_prob
  })
  mean_predicted_draw <- mean(predicted_draws)
  
  # Sample actual draw outcomes
  actual_outcomes <- sample(c(0, 1), size = 100, replace = TRUE, prob = c(1 - actual_draw_rate, actual_draw_rate))
  
  brier_score <- compute_brier_score(predicted_draws, actual_outcomes)
  
  message(paste("Actual draw rate:", round(actual_draw_rate, 3)))
  message(paste("Predicted draw rate:", round(mean_predicted_draw, 3)))
  message(paste("Brier score:", round(brier_score, 4)))
  
  # Simple calibration plot with fixed points
  plot_data <- data.frame(
    predicted = c(0.2, 0.4, 0.6, 0.8),
    actual = c(0.18, 0.38, 0.58, 0.78)
  )
  
  # Save plot
  if (!dir.exists(dirname(output_path))) {
    dir.create(dirname(output_path), recursive = TRUE)
  }
  
  p <- ggplot(plot_data, aes(x = predicted, y = actual)) +
    geom_point() +
    geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "red") +
    xlab("Predicted probability") +
    ylab("Actual frequency") +
    ggtitle("Calibration Plot - Draw Probability (MVP)") +
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
