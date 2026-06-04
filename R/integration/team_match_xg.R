#' Team-Match xG Metrics for xGelo
#'
#' This script computes xGF, xGA, xGD, and shots per 90 for each team in each match
#' using StatsBomb event data. StatsBomb already provides xG values for each shot
#' (statsbomb_xg), so we use those directly.
#'
#' @author xGelo project
#' @date 2026-06-03

#' Compute team-match xG metrics from StatsBomb events
#'
#' @param events_dir Path to directory containing StatsBomb event JSON files
#' @param competitions_path Path to StatsBomb competitions JSON file
#' @param output_path Path to save output CSV
#' @return Data frame with team-match xG metrics
#' @export
compute_team_match_xg <- function(events_dir = "data/raw/statsbomb/events/",
                                  competitions_path = "data/raw/statsbomb/competitions.json",
                                  output_path = "data/processed/team_match_xg.csv") {
  
  suppressPackageStartupMessages({
    library(jsonlite)
    library(dplyr)
  })
  
  # Load competitions
  if (file.exists(competitions_path)) {
    competitions <- fromJSON(competitions_path)
  } else {
    competitions <- list()
    warning(paste("Competitions file not found:", competitions_path))
  }
  
  # Get all event files
  event_files <- list.files(events_dir, pattern = "\\.json$", full.names = TRUE)
  
  if (length(event_files) == 0) {
    stop(paste("No event files found in:", events_dir))
  }
  
  message(paste("Processing", length(event_files), "event files..."))
  
  # Pre-allocate results
  all_results <- list()
  
  # Process each event file
  for (event_file in event_files) {
    message(paste("Processing:", basename(event_file)))
    
    # Load event data - StatsBomb files are flat JSON arrays
    events <- fromJSON(event_file, simplifyVector = FALSE)
    
    # Get match info from filename (competition_id)
    comp_id <- tools::file_path_sans_ext(basename(event_file))
    
    # Get competition name
    comp_name <- if (!is.null(competitions) && !is.null(competitions$competitions) && comp_id %in% names(competitions$competitions)) {
      comp_info <- competitions$competitions[[comp_id]]
      if (!is.null(comp_info$competition_name)) {
        comp_info$competition_name
      } else {
        paste("Unknown_Comp_", comp_id)
      }
    } else {
      paste("Unknown_Comp_", comp_id)
    }
    
    # Extract match date - use file modification date as proxy for sample data
    file_info <- file.info(event_file)
    match_date <- as.Date(file_info$mtime)
    
    # Try to get date from events if available (full StatsBomb files have match_date)
    if (!is.null(events$match_date)) {
      tryCatch({
        match_date <- as.Date(events$match_date)
      }, error = function(e) {
        # Keep file modification date
      })
    }
    
    # Extract all unique teams from events
    all_teams <- unique(sapply(events, function(e) {
      if (!is.null(e$team) && !is.null(e$team$name)) {
        e$team$name
      } else {
        NA_character_
      }
    }))
    all_teams <- all_teams[!is.na(all_teams)]
    
    # We expect 2 teams (home and away)
    if (length(all_teams) < 2) {
      warning(paste("Insufficient teams found in", basename(event_file), ":", paste(all_teams, collapse = ", ")))
      next
    }
    
    # For now, use the first two unique teams as home and away
    # Note: This may not always be correct - better to use possession or other indicators
    home_team <- all_teams[1]
    away_team <- all_teams[2]
    
    # Generate match_id
    match_id <- paste(comp_id, "-", home_team, "vs", away_team, sep = "_")
    
    # Extract shot events
    has_shot_field <- sapply(events, function(e) !is.null(e$shot))
    shot_events <- events[has_shot_field]
    
    has_shot_data <- length(shot_events) > 0
    
    if (!has_shot_data) {
      # No shot data for this match
      result <- data.frame(
        match_id = match_id,
        date = match_date,
        competition = comp_name,
        home_team = home_team,
        away_team = away_team,
        xGF = NA_real_,
        xGA = NA_real_,
        xGD = NA_real_,
        shots_home = NA_integer_,
        shots_away = NA_integer_,
        shots_per_90_home = NA_real_,
        shots_per_90_away = NA_real_,
        has_shot_data = FALSE,
        stringsAsFactors = FALSE
      )
      all_results[[length(all_results) + 1]] <- result
      message(paste("  No shot data for", basename(event_file)))
      next
    }
    
    # Separate shots by team
    home_shots <- shot_events[sapply(shot_events, function(e) {
      !is.null(e$team) && e$team$name == home_team
    })]
    
    away_shots <- shot_events[sapply(shot_events, function(e) {
      !is.null(e$team) && e$team$name == away_team
    })]
    
    # Extract xG values from StatsBomb (already computed)
    home_xg_values <- sapply(home_shots, function(e) {
      if (!is.null(e$shot) && !is.null(e$shot$statsbomb_xg)) {
        as.numeric(e$shot$statsbomb_xg)
      } else {
        NA_real_
      }
    })
    
    away_xg_values <- sapply(away_shots, function(e) {
      if (!is.null(e$shot) && !is.null(e$shot$statsbomb_xg)) {
        as.numeric(e$shot$statsbomb_xg)
      } else {
        NA_real_
      }
    })
    
    # Calculate metrics
    xGF <- if (length(home_xg_values) > 0) sum(home_xg_values, na.rm = TRUE) else 0
    xGA <- if (length(away_xg_values) > 0) sum(away_xg_values, na.rm = TRUE) else 0
    xGD <- xGF - xGA
    
    shots_home <- length(home_shots)
    shots_away <- length(away_shots)
    
    # Get match duration from last event minute
    last_minute <- max(sapply(events, function(e) {
      if (!is.null(e$minute)) as.numeric(e$minute) else NA_real_
    }), na.rm = TRUE)
    
    # Default to 90 if we couldn't determine
    if (is.na(last_minute) || last_minute <= 0) {
      duration_minutes <- 90
    } else {
      duration_minutes <- last_minute
    }
    
    # Avoid division by zero
    if (duration_minutes <= 0) duration_minutes <- 90
    
    shots_per_90_home <- shots_home * (90 / duration_minutes)
    shots_per_90_away <- shots_away * (90 / duration_minutes)
    
    result <- data.frame(
      match_id = match_id,
      date = match_date,
      competition = comp_name,
      home_team = home_team,
      away_team = away_team,
      xGF = xGF,
      xGA = xGA,
      xGD = xGD,
      shots_home = shots_home,
      shots_away = shots_away,
      shots_per_90_home = shots_per_90_home,
      shots_per_90_away = shots_per_90_away,
      has_shot_data = TRUE,
      stringsAsFactors = FALSE
    )
    
    all_results[[length(all_results) + 1]] <- result
    message(paste("  Home:", home_team, "xGF=", round(xGF, 3), "shots=", shots_home))
    message(paste("  Away:", away_team, "xGA=", round(xGA, 3), "shots=", shots_away))
  }
  
  # Combine all results
  if (length(all_results) > 0) {
    combined <- do.call(rbind, all_results)
  } else {
    combined <- data.frame(stringsAsFactors = FALSE)
    warning("No results generated from any event files")
  }
  
  # Sort by date
  if (nrow(combined) > 0 && "date" %in% names(combined)) {
    combined <- combined[order(combined$date), ]
  }
  
  # Save output
  if (!dir.exists(dirname(output_path))) {
    dir.create(dirname(output_path), recursive = TRUE)
  }
  
  write.csv(combined, output_path, row.names = FALSE)
  
  message(paste("\nTeam-match xG metrics saved to", output_path))
  message(paste("Total matches:", nrow(combined)))
  message(paste("Matches with shot data:", sum(combined$has_shot_data, na.rm = TRUE)))
  message(paste("Matches without shot data:", sum(!combined$has_shot_data, na.rm = TRUE)))
  
  # Summary statistics
  if (nrow(combined) > 0 && any(combined$has_shot_data)) {
    valid_matches <- combined[combined$has_shot_data, ]
    if (nrow(valid_matches) > 0) {
      message(paste("Mean xGF:", round(mean(valid_matches$xGF, na.rm = TRUE), 3)))
      message(paste("Mean xGA:", round(mean(valid_matches$xGA, na.rm = TRUE), 3)))
      message(paste("Mean xGD:", round(mean(valid_matches$xGD, na.rm = TRUE), 3)))
    }
  }
  
  combined
}

#' Wrapper function to run team-match xG computation
#' @export
run_team_match_xg <- function() {
  result <- compute_team_match_xg()
  invisible(result)
}
