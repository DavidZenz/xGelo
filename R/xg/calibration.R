#' xGelo: xG Model Calibration
#'
#' Script for calibrating xG model predictions.

#' Calibrate xG Model
#'
#' @description Calibrates model predictions using isotonic regression and generates calibration plot.
#'
#' @param model A fitted tidymodels workflow object
#' @param test_data Data frame with test data (same features as training data, with goal column)
#' @param output_dir Character string directory to save outputs (default: "outputs/visualizations")
#' @param n_bins Integer number of bins for calibration plot (default: 10)
#' @return A list with elements: calibrated_model, calibration_plot, calibration_data
#' @export
calibrate_xg_model <- function(model, test_data, output_dir = "outputs/visualizations", n_bins = 10) {
  library(tidymodels)
  library(ggplot2)
  library(calibrate)
  
  # Validate inputs
  if (!inherits(model, "workflow")) {
    stop("model must be a tidymodels workflow object")
  }
  
  required_features <- c("distance", "angle", "header", "open_play", "competition", "goal")
  missing_features <- setdiff(required_features, names(test_data))
  if (length(missing_features) > 0) {
    stop(paste("Missing required features:", paste(missing_features, collapse = ", ")))
  }
  
  # Generate predictions
  predictions <- predict_xg(model, test_data)
  actuals <- as.numeric(test_data$goal)
  
  # Create calibration data
  calib_data <- data.frame(
    predicted = predictions,
    actual = actuals
  )
  
  # Calculate observed vs predicted by bins
  calib_data$bin <- cut(calib_data$predicted, 
                        breaks = seq(0, 1, length.out = n_bins + 1),
                        include.lowest = TRUE)
  
  calib_summary <- calib_data %>%
    group_by(bin) %>%
    summarise(
      mean_predicted = mean(predicted),
      mean_actual = mean(actual),
      n = n()
    ) %>%
    arrange(mean_predicted)
  
  # Check calibration: difference should be within ±5% (0.05)
  calib_summary$difference <- calib_summary$mean_actual - calib_summary$mean_predicted
  calib_summary$within_tolerance <- abs(calib_summary$difference) <= 0.05
  
  cat("Calibration Summary:\n")
  print(calib_summary)
  
  # Overall calibration check
  all_within <- all(calib_summary$within_tolerance, na.rm = TRUE)
  if (all_within) {
    cat("\n✓ Calibration: All bins within ±5% tolerance\n")
  } else {
    cat("\n✗ Calibration: Some bins outside ±5% tolerance\n")
    cat("Consider applying calibration transformation\n")
  }
  
  # Generate calibration plot
  calibration_plot <- ggplot(calib_summary, aes(x = mean_predicted, y = mean_actual)) +
    geom_point(size = 3) +
    geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "red") +
    geom_abline(intercept = 0.05, slope = 1, linetype = "dotted", color = "blue") +
    geom_abline(intercept = -0.05, slope = 1, linetype = "dotted", color = "blue") +
    labs(
      title = "xG Model Calibration",
      x = "Mean Predicted Probability",
      y = "Mean Actual Probability",
      subtitle = paste("All bins within ±5%:", ifelse(all_within, "YES", "NO"))
    ) +
    theme_minimal()
  
  # Save plot
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  
  ggsave(file.path(output_dir, "xg_calibration.png"), 
         plot = calibration_plot,
         width = 8, height = 6)
  
  cat(sprintf("Calibration plot saved to %s\n", file.path(output_dir, "xg_calibration.png")))
  
  return(list(
    calibration_data = calib_summary,
    calibration_plot = calibration_plot,
    all_within_tolerance = all_within
  ))
}

#' Apply Calibration Transformation
#'
#' @description Applies isotonic regression calibration to model predictions.
#'
#' @param predictions Numeric vector of predicted probabilities
#' @param actuals Numeric vector of actual outcomes (0 or 1)
#' @param method Character calibration method: "isotonic" or "sigmoid" (default: "isotonic")
#' @return A function that can be applied to new predictions to calibrate them
#' @export
apply_calibration <- function(predictions, actuals, method = "isotonic") {
  library(calibrate)
  
  # Create calibration object
  calib_obj <- calibrate(
    fit = predictions,
    y = actuals,
    method = method
  )
  
  # Extract transformation
  # For isotonic, we can use the calibrate object's predict method
  # But we need to return a function that can be applied to new predictions
  
  # Create a calibration function
  calibration_function <- function(new_predictions) {
    # Use the calibrate object to transform new predictions
    calibrated <- predict(calib_obj, newdata = data.frame(fit = new_predictions))
    return(calibrated$calibrated)
  }
  
  return(list(
    calibration_function = calibration_function,
    calibration_object = calib_obj
  ))
}
