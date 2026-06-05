#' Generate Pipeline DAG Visualization for xGelo
#'
#' Since the targets package may have environment-specific issues,
#' this script provides an alternative way to visualize the pipeline DAG.
#'
#' @author xGelo project
#' @date 2026-06-04

#' Generate DAG visualization using igraph
#' @param output_path Path to save the visualization
#' @export
generate_pipeline_dag <- function(output_path = "outputs/pipeline_dag.png") {
  suppressPackageStartupMessages({
    library(igraph)
    library(ggplot2)
    library(dplyr)
  })
  
  # Define nodes (pipeline stages)
  nodes <- data.frame(
    id = c("data_raw", "data_clean", "elo_ratings", "xg_model", 
           "team_match_xg", "rolling_form", "forecast_models", "forecasts", "reports"),
    label = c("Data Raw", "Data Clean", "Elo Ratings", "xG Model",
              "Team-Match xG", "Rolling Form", "Forecast Models", "Forecasts", "Reports"),
    phase = c("Phase 1", "Phase 1", "Phase 3", "Phase 2",
              "Phase 4", "Phase 4", "Phase 5", "Phase 5", "Phase 5"),
    stringsAsFactors = FALSE
  )
  
  # Define edges (dependencies)
  edges <- data.frame(
    from = c("data_raw", "data_clean", "data_clean", "data_clean",
             "data_raw", "data_raw", "team_match_xg", "elo_ratings",
             "rolling_form", "elo_ratings", "forecast_models", "forecasts"),
    to = c("data_clean", "elo_ratings", "xg_model", "team_match_xg",
           "team_match_xg", "rolling_form", "rolling_form", "rolling_form",
           "forecast_models", "forecast_models", "forecasts", "reports"),
    stringsAsFactors = FALSE
  )
  
  # Create graph
  graph <- graph_from_data_frame(edges, directed = TRUE, vertices = nodes)
  
  # Get layout
  layout <- layout_with_sugiyama(graph)
  
  # Assign colors based on phase
  phase_colors <- c(
    "Phase 1" = "#FF6B6B",  # Red
    "Phase 2" = "#4ECDC4",  # Teal
    "Phase 3" = "#45B7D1",  # Blue
    "Phase 4" = "#96CEB4",  # Green
    "Phase 5" = "#FFEAA7"   # Yellow
  )
  node_colors <- phase_colors[nodes$phase]
  
  # Plot
  png(output_path, width = 1200, height = 800)
  par(mar = rep(0.5, 4))
  
  # Plot graph
  plot(graph, 
       layout = layout,
       vertex.label = nodes$label,
       vertex.color = node_colors,
       vertex.size = 30,
       vertex.label.cex = 1.2,
       vertex.label.color = "black",
       edge.arrow.size = 0.5,
       edge.color = "#666666",
       edge.width = 2,
       main = "xGelo Pipeline DAG",
       sub = "Directed Acyclic Graph of Data Dependencies")
  
  # Add legend
  legend("bottom", 
         legend = names(phase_colors),
         fill = phase_colors,
         cex = 1.2,
         title = "Phase",
         bty = "n",
         ncol = length(phase_colors))
  
  dev.off()
  
  message(paste("DAG visualization saved to", output_path))
  return(graph)
}

#' Wrapper function
#' @export
run_dag_visualization <- function() {
  if (!dir.exists("outputs")) {
    dir.create("outputs", recursive = TRUE)
  }
  generate_pipeline_dag()
}

#' Alternative: Generate DAG using Mermaid JS syntax
#' This can be rendered in markdown documents
#' @export
generate_mermaid_dag <- function() {
  cat("```mermaid\n")
  cat("graph TD\n")
  cat("    %% xGelo Pipeline DAG\n")
  cat("    %% Phase dependencies\n\n")
  
  cat("    %% Phase 1: Data Ingestion\n")
  cat("    data_raw[Data Raw] --> data_clean[Data Clean]\n\n")
  
  cat("    %% Phase 2: xG Model\n")
  cat("    data_clean --> xg_model[xG Model]\n\n")
  
  cat("    %% Phase 3: Elo Ratings\n")
  cat("    data_clean --> elo_ratings[Elo Ratings]\n\n")
  
  cat("    %% Phase 4: Integration\n")
  cat("    data_raw --> team_match_xg[Team-Match xG]\n")
  cat("    xg_model --> team_match_xg\n")
  cat("    team_match_xg --> rolling_form[Rolling Form]\n")
  cat("    elo_ratings --> rolling_form\n\n")
  
  cat("    %% Phase 5: Forecasting\n")
  cat("    rolling_form --> forecast_models[Forecast Models]\n")
  cat("    elo_ratings --> forecast_models\n")
  cat("    forecast_models --> forecasts[Forecasts]\n")
  cat("    forecasts --> reports[Reports]\n")
  cat("\n```\n")
}

# Run on script load
if (interactive()) {
  run_dag_visualization()
}
