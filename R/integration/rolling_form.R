#' Rolling Form Metrics for xGelo
#'
#' This script computes EWMA-based rolling form metrics over 6-12 matches
#' using team-match xG metrics and Elo ratings.
#'
#' @author xGelo project
#' @date 2026-06-03

#' Compute rolling form metrics using EWMA
#'
#' @param xg_metrics_path Path to team-match xG metrics CSV
#' @param elo_ratings_path Path to Elo ratings CSV (optional)
#' @param span Number of matches to include in EWMA (default: 12)
#' @param alpha Decay factor for EWMA (default: NULL, computed from span)
#' @param output_path Path to save output CSV
#' @return Data frame with rolling form metrics
#' @export
compute_rolling_form <- function(xg_metrics_path = "data/processed/team_match_xg.csv",
                                  elo_ratings_path = "data/processed/elo_ratings.csv",
                                  span = 12,
                                  alpha = NULL,
                                  output_path = "data/processed/rolling_form.csv") {
  
  suppressPackageStartupMessages({
    library(dplyr)
    library(lubridate)
  })
  
  # Load team-match xG metrics
  if (!file.exists(xg_metrics_path)) {
    stop(paste("xG metrics file not found:", xg_metrics_path))
  }
  
  xg_metrics <- read.csv(xg_metrics_path, stringsAsFactors = FALSE)
  
  if (nrow(xg_metrics) == 0) {
    stop("xG metrics file is empty")
  }
  
  # Load Elo ratings (optional)
  elo_ratings <- NULL
  if (file.exists(elo_ratings_path)) {
    elo_ratings <- read.csv(elo_ratings_path, stringsAsFactors = FALSE)
    message(paste("Loaded", nrow(elo_ratings), "Elo rating entries"))
  } else {
    warning(paste("Elo ratings file not found:", elo_ratings_path, "- continuing without Elo"))
  }
  
  # Compute alpha from span if not provided
  if (is.null(alpha)) {
    alpha <- 2 / (span + 1)
    message(paste("Using alpha =", round(alpha, 4), "for span =", span))
  }
  
  # Process each team separately
  all_teams <- unique(c(xg_metrics$home_team, xg_metrics$away_team))
  all_teams <- all_teams[!is.na(all_teams)]
  
  message(paste("Processing", length(all_teams), "teams..."))
  
  all_results <- list()
  
  for (team in all_teams) {
    # Get all matches for this team (both as home and away)
    team_matches_home <- xg_metrics[xg_metrics$home_team == team, ]
    team_matches_away <- xg_metrics[xg_metrics$away_team == team, ]
    
    # Process home matches: xGF is team's xG, xGA is opponent's xG
    if (nrow(team_matches_home) > 0) {
      home_results <- data.frame(
        team = team,
        match_date = team_matches_home$date,
        opponent = team_matches_home$away_team,
        is_home = TRUE,
        xGF_team = team_matches_home$xGF,
        xGA_team = team_matches_home$xGA,
        xGD_team = team_matches_home$xGD,
        shots_team = team_matches_home$shots_home,
        shots_against = team_matches_home$shots_away
      )
    } else {
      home_results <- data.frame(team = character(), match_date = as.Date(character()), 
                                 opponent = character(), is_home = logical(),
                                 xGF_team = numeric(), xGA_team = numeric(),
                                 xGD_team = numeric(), shots_team = numeric(),
                                 shots_against = numeric(), stringsAsFactors = FALSE)
    }
    
    # Process away matches: xGF_team = xGA (away team's xG), xGA_team = xGF (home team's xG)
    if (nrow(team_matches_away) > 0) {
      away_results <- data.frame(
        team = team,
        match_date = team_matches_away$date,
        opponent = team_matches_away$home_team,
        is_home = FALSE,
        xGF_team = team_matches_away$xGA,
        xGA_team = team_matches_away$xGF,
        xGD_team = -team_matches_away$xGD,  # Reverse the difference
        shots_team = team_matches_away$shots_away,
        shots_against = team_matches_away$shots_home
      )
    } else {
      away_results <- data.frame(team = character(), match_date = as.Date(character()),
                                 opponent = character(), is_home = logical(),
                                 xGF_team = numeric(), xGA_team = numeric(),
                                 xGD_team = numeric(), shots_team = numeric(),
                                 shots_against = numeric(), stringsAsFactors = FALSE)
    }
    
    # Combine all matches for this team
    team_all_matches <- rbind(home_results, away_results)
    
    if (nrow(team_all_matches) == 0) {
      message(paste("  No matches found for", team))
      next
    }
    
    # Sort by date
    team_all_matches <- team_all_matches[order(team_all_matches$match_date), ]
    
    # Add match number
    team_all_matches$match_num <- 1:nrow(team_all_matches)
    
    # Compute EWMA for each metric
    # Use manual calculation to avoid dplyr issues
    
    compute_ewma_simple <- function(values, alpha) {
      # Ensure values is a numeric vector
      if (length(values) == 0) return(numeric(0))
      
      values <- as.numeric(values)
      if (length(values) == 0) return(numeric(0))
      
      # Replace NA with 0
      values[is.na(values)] <- 0
      
      # If all zeros, return zeros
      if (all(values == 0)) return(rep(0, length(values)))
      
      # Compute EWMA
      ewma <- numeric(length(values))
      
      # Check if first value is valid
      if (is.na(values[1]) || is.null(values[1]) || !is.numeric(values[1])) {
        values[1] <- 0
      }
      
      ewma[1] <- values[1]
      if (length(values) > 1) {
        for (i in 2:length(values)) {
          val_i <- alpha * values[i]
          val_prev <- (1 - alpha) * ewma[i-1]
          ewma[i] <- val_i + val_prev
        }
      }
      return(ewma)
    }
    
    # Extract metric values
    xgf_vec <- team_all_matches$xGF_team
    xga_vec <- team_all_matches$xGA_team
    xgd_vec <- team_all_matches$xGD_team
    shots_vec <- team_all_matches$shots_team
    
    # Compute EWMA
    xgf_ewma <- compute_ewma_simple(xgf_vec, alpha)
    xga_ewma <- compute_ewma_simple(xga_vec, alpha)
    xgd_ewma <- compute_ewma_simple(xgd_vec, alpha)
    shots_ewma <- compute_ewma_simple(shots_vec, alpha)
    
    # Get Elo ratings for this team (simplified - use most recent before match)
    team_elo <- rep(1500, nrow(team_all_matches))  # Default to base rating
    
    if (!is.null(elo_ratings)) {
      for (i in 1:nrow(team_all_matches)) {
        match_date <- team_all_matches$match_date[i]
        # Find ratings for this team before the match date
        team_ratings_before <- elo_ratings[elo_ratings$team == team & elo_ratings$date <= match_date, ]
        if (nrow(team_ratings_before) > 0) {
          # Get the most recent rating
          most_recent <- team_ratings_before[which.max(team_ratings_before$date), ]
          team_elo[i] <- most_recent$rating
        }
      }
      # Replace any remaining NA with 1500
      team_elo[is.na(team_elo)] <- 1500
      elo_ewma <- compute_ewma_simple(team_elo, alpha)
    } else {
      elo_ewma <- rep(NA, nrow(team_all_matches))
    }
    
    # Create form index (simple weighted combination of normalized metrics)
    # Normalize each metric by typical max values
    xgf_norm <- pmin(xgf_ewma / 5, 1)
    xga_norm <- pmin(xga_ewma / 5, 1)
    shots_norm <- pmin(shots_ewma / 30, 1)
    
    # For xGA, lower is better (defensive strength), so invert
    xga_norm_inverted <- 1 - xga_norm
    
    # Elo normalization: typical range 1000-2000, normalize to 0-1
    elo_norm <- pmin(pmax((team_elo - 1000) / 1000, 0), 1)
    
    # Form index (weighted combination)
    form_index <- 0.35 * xgf_norm + 0.25 * xga_norm_inverted + 0.20 * shots_norm + 0.20 * elo_norm
    
    # Create results for this team
    team_results <- data.frame(
      team = team,
      match_date = team_all_matches$match_date,
      opponent = team_all_matches$opponent,
      is_home = team_all_matches$is_home,
      match_num = team_all_matches$match_num,
      xgf_ewma = xgf_ewma,
      xga_ewma = xga_ewma,
      xgd_ewma = xgd_ewma,
      shots_ewma = shots_ewma,
      elo = team_elo,
      elo_ewma = elo_ewma,
      form_index = form_index,
      span = span,
      alpha = alpha,
      stringsAsFactors = FALSE
    )
    
    all_results[[length(all_results) + 1]] <- team_results
    message(paste("  Processed", nrow(team_results), "matches for", team))
  }
  
  # Combine all results
  if (length(all_results) > 0) {
    combined <- do.call(rbind, all_results)
  } else {
    combined <- data.frame(stringsAsFactors = FALSE)
    warning("No results generated for any team")
  }
  
  # Sort by team and date
  combined <- combined[order(combined$team, combined$match_date), ]
  
  # Save output
  if (!dir.exists(dirname(output_path))) {
    dir.create(dirname(output_path), recursive = TRUE)
  }
  
  write.csv(combined, output_path, row.names = FALSE)
  
  message(paste("\nRolling form metrics saved to", output_path))
  message(paste("Total entries:", nrow(combined)))
  
  # Summary
  if (nrow(combined) > 0) {
    message(paste("Teams:", length(unique(combined$team))))
    message(paste("Date range:", min(combined$match_date), "to", max(combined$match_date)))
    if (!all(is.na(combined$form_index))) {
      message(paste("Mean form_index:", round(mean(combined$form_index, na.rm = TRUE), 3)))
    }
  }
  
  combined
}

#' Wrapper function to run rolling form computation
#' @export
run_rolling_form <- function() {
  result <- compute_rolling_form()
  invisible(result)
}
