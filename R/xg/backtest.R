#' xGelo: xG Model Backtesting
#'
#' Script for evaluating xG model performance on test data.

#' Backtest xG Model
#'
#' @description Evaluates model performance on test data and generates backtest report.
#'
#' @param model A fitted tidymodels workflow object
#' @param test_data Data frame with test data (same features as training data, with goal column)
#' @param output_dir Character string directory to save outputs (default: "outputs/model_performance")
#' @return A data frame with backtest metrics
#' @export
backtest_xg_model <- function(model, test_data, output_dir = "outputs/model_performance") {
  library(tidymodels)
  library(yardstick)
  library(ggplot2)
  library(pROC)
  
  # Validate inputs
  if (!inherits(model, "workflow")) {
    stop("model must be a tidymodels workflow object")
  }
  
  required_features <- c("distance", "angle", "header", "open_play", "competition", "goal")
  missing_features <- setdiff(required_features, names(test_data))
  if (length(missing_features) > 0) {
    stop(paste("Missing required features:", paste(missing_features, collapse = ", ")))
  }
  
  if (nrow(test_data) == 0) {
    stop("test_data must have at least one row")
  }
  
  # Generate predictions
  predictions <- predict_xg(model, test_data)
  actuals <- as.numeric(test_data$goal)
  
  # Calculate metrics
  
  # AUC
  auc_value <- auc(roc(actuals, predictions))
  
  # Accuracy
  predicted_class <- as.integer(predictions >= 0.5)
  accuracy_value <- mean(predicted_class == actuals)
  
  # Brier score
  brier_score_value <- mean((predictions - actuals)^2)
  
  # Also calculate by competition if available and there are multiple competitions
  if ("competition" %in% names(test_data)) {
    unique_comps <- unique(test_data$competition)
    if (length(unique_comps) > 1) {
      by_competition_list <- list()
      for (comp in unique_comps) {
        comp_data <- test_data[test_data$competition == comp, ]
        comp_actuals <- as.numeric(comp_data$goal)
        comp_predictions <- predict_xg(model, comp_data)
        comp_class <- as.integer(comp_predictions >= 0.5)
        
        by_competition_list[[comp]] <- list(
          competition = comp,
          n_shots = nrow(comp_data),
          n_goals = sum(comp_actuals),
          auc = auc(roc(comp_actuals, comp_predictions)),
          accuracy = mean(comp_class == comp_actuals),
          brier_score = mean((comp_predictions - comp_actuals)^2)
        )
      }
      by_competition <- do.call(rbind, lapply(by_competition_list, as.data.frame))
    } else {
      # Only one competition, skip by-competition analysis
      by_competition <- data.frame()
    }
  } else {
    by_competition <- data.frame()
  }
  
  # Create backtest results
  backtest_results <- data.frame(
    metric = c("auc", "accuracy", "brier_score"),
    value = c(auc_value, accuracy_value, brier_score_value),
    data_type = "overall"
  )
  
  # Add per-competition results
  if (nrow(by_competition) > 0) {
    by_comp_long <- by_competition %>%
      pivot_longer(
        cols = c(auc, accuracy, brier_score),
        names_to = "metric",
        values_to = "value"
      ) %>%
      mutate(data_type = "by_competition")
    
    backtest_results <- bind_rows(backtest_results, by_comp_long)
  }
  
  # Save results
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  
  write.csv(backtest_results, file.path(output_dir, "xg_backtest.csv"), row.names = FALSE)
  
  cat("Backtest Results:\n")
  cat("==================\n")
  cat(sprintf("AUC: %.4f\n", auc_value))
  cat(sprintf("Accuracy: %.4f\n", accuracy_value))
  cat(sprintf("Brier Score: %.4f\n", brier_score_value))
  cat("\n")
  
  # Check if meets AUC >= 0.75 requirement
  if (auc_value >= 0.75) {
    cat("✓ AUC >= 0.75 requirement MET\n")
  } else {
    cat("✗ AUC >= 0.75 requirement NOT MET\n")
    cat(sprintf("  Current AUC: %.4f, Need: 0.7500\n", auc_value))
  }
  
  # Generate ROC curve
  roc_obj <- roc(actuals, predictions)
  
  # Ensure all vectors have the same length
  # pROC sometimes returns different lengths due to threshold handling
  max_len <- max(length(roc_obj$fpr), length(roc_obj$tpr), length(roc_obj$thresholds))
  
  # Pad with NA if needed
  fpr <- c(roc_obj$fpr, rep(NA, max_len - length(roc_obj$fpr)))
  tpr <- c(roc_obj$tpr, rep(NA, max_len - length(roc_obj$tpr)))
  thresholds <- c(roc_obj$thresholds, rep(NA, max_len - length(roc_obj$thresholds)))
  
  roc_data <- data.frame(
    fpr = fpr[1:max_len],
    tpr = tpr[1:max_len],
    threshold = thresholds[1:max_len]
  )
  
  # Remove rows with NA
  roc_data <- na.omit(roc_data)
  
  roc_plot <- ggplot(roc_data, aes(x = fpr, y = tpr)) +
    geom_path(color = "blue") +
    geom_abline(intercept = 1, slope = 0, linetype = "dashed", color = "red") +
    labs(
      title = sprintf("ROC Curve (AUC = %.4f)", auc_value),
      x = "False Positive Rate",
      y = "True Positive Rate"
    ) +
    theme_minimal()
  
  ggsave(file.path(output_dir, "xg_roc_curve.png"), 
         plot = roc_plot,
         width = 8, height = 6)
  
  cat(sprintf("ROC curve saved to %s\n", file.path(output_dir, "xg_roc_curve.png")))
  cat(sprintf("Backtest CSV saved to %s\n", file.path(output_dir, "xg_backtest.csv")))
  
  return(backtest_results)
}
