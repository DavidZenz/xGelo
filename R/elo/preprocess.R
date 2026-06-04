#' Elo Data Preprocessing for xGelo
#'
#' This script preprocesses martj42 results data for Elo rating computation.
#' It loads the raw results, maps team names to canonical names, adds result
#' columns, and prepares the data for the Elo computation function.
#'
#' @author xGelo project
#' @date 2026-06-03

#' Preprocess martj42 results for Elo computation
#'
#' @param results_path Path to the martj42 results.csv file
#' @param team_map_path Path to the team name mapping CSV file
#' @param output_path Path to save the preprocessed data (default: "data/processed/elo_matches.csv")
#' @return Data frame with preprocessed matches
#' @export
preprocess_martj42 <- function(results_path = "data/raw/martj42/results.csv",
                            team_map_path = "data/raw/team_name_map.csv",
                            output_path = "data/processed/elo_matches.csv") {
  
  # Load libraries
  suppressPackageStartupMessages({
    library(dplyr)
    library(lubridate)
    library(stringr)
  })
  
  # Load results
  if (!file.exists(results_path)) {
    stop(paste("Results file not found:", results_path))
  }
  
  results <- read.csv(results_path, stringsAsFactors = FALSE)
  
  message(paste("Loaded", nrow(results), "matches from", results_path))
  
  # Load team name mapping
  if (!file.exists(team_map_path)) {
    stop(paste("Team map file not found:", team_map_path))
  }
  
  team_map <- read.csv(team_map_path, stringsAsFactors = FALSE)
  
  message(paste("Loaded", nrow(team_map), "team mappings from", team_map_path))
  
  # Validate that team_map has required columns
  required_map_cols <- c("source_name", "canonical_name", "fifa_code")
  missing_map_cols <- setdiff(required_map_cols, names(team_map))
  if (length(missing_map_cols) > 0) {
    stop(paste("Team map missing required columns:", paste(missing_map_cols, collapse = ", ")))
  }
  
  # Validate results has required columns
  required_cols <- c("date", "home_team", "away_team", "home_score", "away_score", "neutral")
  missing_cols <- setdiff(required_cols, names(results))
  if (length(missing_cols) > 0) {
    stop(paste("Results missing required columns:", paste(missing_cols, collapse = ", ")))
  }
  
  # Create mapping from source_name to canonical_name
  # Handle pipe-delimited alt_names
  team_mapping <- list()
  for (i in 1:nrow(team_map)) {
    row <- team_map[i, ]
    source_name <- row$source_name
    canonical_name <- row$canonical_name
    fifa_code <- row$fifa_code
    
    # Split alt_names if present
    alt_names <- if (!is.na(row$alt_names) && nchar(row$alt_names) > 0) {
      str_split(row$alt_names, "\\|")[1]
    } else {
      character(0)
    }
    
    # Map all variations to canonical name
    all_names <- c(source_name, alt_names)
    for (name in all_names) {
      if (!is.na(name) && nchar(name) > 0) {
        team_mapping[[tolower(name)]] <- list(
          canonical_name = canonical_name,
          fifa_code = fifa_code,
          source_name = source_name
        )
      }
    }
  }
  
  # Function to map team name to canonical name
  map_team_name <- function(team_name) {
    if (is.na(team_name)) {
      return(NA_character_)
    }
    
    lower_name <- tolower(team_name)
    
    if (lower_name %in% names(team_mapping)) {
      return(team_mapping[[lower_name]]$canonical_name)
    } else {
      # Try fuzzy matching or return original
      return(team_name)
    }
  }
  
  # Function to map team name to FIFA code
  map_team_fifa <- function(team_name) {
    if (is.na(team_name)) {
      return(NA_character_)
    }
    
    lower_name <- tolower(team_name)
    
    if (lower_name %in% names(team_mapping)) {
      return(team_mapping[[lower_name]]$fifa_code)
    } else {
      return(NA_character_)
    }
  }
  
  # Preprocess results
  elo_matches <- results |>
    # Convert date to Date object
    mutate(date = as.Date(date)) |>
    
    # Map team names to canonical names
    mutate(
      home_team_canonical = sapply(home_team, map_team_name),
      away_team_canonical = sapply(away_team, map_team_name),
      home_team_fifa = sapply(home_team, map_team_fifa),
      away_team_fifa = sapply(away_team, map_team_fifa)
    ) |>
    
    # Determine result from scores
    mutate(
      result = case_when(
        home_score > away_score ~ 1.0,
        home_score == away_score ~ 0.5,
        home_score < away_score ~ 0.0
      )
    ) |>
    
    # Create match identifier
    mutate(
      match_id = paste(home_team_canonical, away_team_canonical, date, sep = "_")
    ) |>
    
    # Mark home/away
    mutate(
      is_home = !neutral
    ) |>
    
    # Sort chronologically (oldest first)
    arrange(date)
  
  # Check for unmapped teams
  unmapped_home <- which(is.na(elo_matches$home_team_fifa))
  unmapped_away <- which(is.na(elo_matches$away_team_fifa))
  
  if (length(unmapped_home) > 0) {
    warning(paste("Unmapped home teams:", 
                  paste(unique(elo_matches$home_team[unmapped_home]), collapse = ", ")))
  }
  if (length(unmapped_away) > 0) {
    warning(paste("Unmapped away teams:",
                  paste(unique(elo_matches$away_team[unmapped_away]), collapse = ", ")))
  }
  
  # Save preprocessed data
  if (!dir.exists(dirname(output_path))) {
    dir.create(dirname(output_path), recursive = TRUE)
  }
  
  write.csv(elo_matches, output_path, row.names = FALSE)
  
  message(paste("Preprocessed data saved to", output_path))
  message(paste("Total matches:", nrow(elo_matches)))
  message(paste("Date range:", min(elo_matches$date), "to", max(elo_matches$date)))
  message(paste("Unique teams:", length(unique(c(elo_matches$home_team_canonical, elo_matches$away_team_canonical)))))
  
  # Return the preprocessed data
  elo_matches
}

#' Preprocess and save Elo matches (wrapper for use in pipeline)
#'
#' @param results_path Path to results.csv
#' @param team_map_path Path to team_name_map.csv
#' @param output_path Path to save output
#' @return Path to saved file
#' @export
preprocess_and_save_elo_matches <- function(results_path = "data/raw/martj42/results.csv",
                                           team_map_path = "data/raw/team_name_map.csv",
                                           output_path = "data/processed/elo_matches.csv") {
  result <- preprocess_martj42(results_path, team_map_path, output_path)
  invisible(output_path)
}
