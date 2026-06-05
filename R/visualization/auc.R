#' xGelo Visualization - AUC Comparison Chart
#'
#' Generates a bar chart comparing AUC across 4 feature configurations.
#'
#' @author xGelo project
#' @date 2026-06-04

#' Generate AUC comparison chart
#'
#' @param output_path Path to save the PNG file
#' @return ggplot object
#' @export
generate_auc_chart <- function(output_path = "outputs/visualizations/auc_comparison.png") {
  suppressPackageStartupMessages({
    library(ggplot2)
    library(dplyr)
    library(pROC)
  })
  
  metric_rows <- list()
  
  xg_backtest_path <- "outputs/model_performance/xg_backtest.csv"
  if (file.exists(xg_backtest_path)) {
    xg_backtest <- read.csv(xg_backtest_path, stringsAsFactors = FALSE)
    xg_auc <- xg_backtest$value[xg_backtest$metric == "auc" & xg_backtest$data_type == "overall"]
    if (length(xg_auc) > 0) {
      metric_rows[[length(metric_rows) + 1]] <- data.frame(
        configuration = "xG model",
        auc = as.numeric(xg_auc[1]),
        stringsAsFactors = FALSE
      )
    }
  }
  
  elo_validation_path <- "outputs/model_performance/elo_validation.csv"
  if (file.exists(elo_validation_path)) {
    elo_validation <- read.csv(elo_validation_path, stringsAsFactors = FALSE)
    if (all(c("actual_binary", "predicted_prob") %in% names(elo_validation)) &&
        length(unique(elo_validation$actual_binary)) >= 2) {
      auc_value <- as.numeric(pROC::auc(pROC::roc(elo_validation$actual_binary, elo_validation$predicted_prob, quiet = TRUE)))
      metric_rows[[length(metric_rows) + 1]] <- data.frame(
        configuration = "Elo home-win model",
        auc = auc_value,
        stringsAsFactors = FALSE
      )
    }
  }
  
  if (length(metric_rows) == 0) {
    stop("No AUC metric artifacts found. Run xG/Elo backtests before generating AUC chart.")
  }
  
  configs <- bind_rows(metric_rows)
  
  # Create color palette
  colors <- c("#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4")
  
  # Create plot
  p <- ggplot(configs, aes(x = reorder(configuration, auc), y = auc, fill = configuration)) +
    geom_bar(stat = "identity", width = 0.7) +
    geom_hline(yintercept = 0.75, linetype = "dashed", color = "#FF0000", linewidth = 1) +
    geom_text(aes(label = sprintf("%.4f", auc)), 
              position = position_stack(vjust = 0.5), 
              size = 4, color = "white", fontface = "bold") +
    labs(
      title = "xGelo Model Performance by Feature Configuration",
      subtitle = "AUC on held-out test sets (xG model from Phase 2, forecast models from Phase 5)",
      x = "Feature Configuration",
      y = "AUC (Area Under Curve)",
      fill = "Configuration"
    ) +
    scale_fill_manual(values = colors) +
    theme_minimal() +
    theme(
      plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
      plot.subtitle = element_text(size = 12, color = "#666666", hjust = 0.5),
      axis.text.x = element_text(angle = 45, hjust = 1, size = 12),
      axis.text.y = element_text(size = 12),
      axis.title.x = element_text(size = 14, face = "bold"),
      axis.title.y = element_text(size = 14, face = "bold"),
      legend.position = "bottom",
      legend.text = element_text(size = 11),
      legend.title = element_text(size = 12, face = "bold"),
      panel.grid.major.y = element_line(color = "#E0E0E0", linewidth = 0.2)
    ) +
    annotate("text", x = 1, y = 0.74, label = "Minimum acceptable", 
             size = 3.5, color = "#666666", angle = 90, vjust = -0.5, hjust = 1)
  
  # Ensure output directory exists
  if (!dir.exists(dirname(output_path))) {
    dir.create(dirname(output_path), recursive = TRUE)
  }
  
  # Save plot
  ggsave(output_path, plot = p, width = 12, height = 8, dpi = 300, bg = "white")
  
  message(paste("AUC comparison chart saved to", output_path))
  
  return(p)
}

#' Wrapper function
#' @export
run_auc_chart <- function() {
  generate_auc_chart()
}

# Run on script load
if (interactive()) {
  run_auc_chart()
}
