#' Team-Match xG Metrics for xGelo
#'
#' This script computes xGF, xGA, xGD, and shots per 90 for each team in each match
#' using StatsBomb event data and our own xG model.
#'
#' @author xGelo project
#' @date 2026-06-03

#' Compute team-match xG metrics from StatsBomb events
#'
#' @param events_dir Path to directory containing StatsBomb event JSON files
#' @param model_path Path to xG model RDS file
#' @param competitions_path Path to StatsBomb competitions JSON file
#' @param output_path Path to save output CSV
#' @param use_own_model Logical whether to use our own xG model (TRUE) or StatsBomb's xG (FALSE)
#' @return Data frame with team-match xG metrics
#' @export
compute_team_match_xg <- function(events_dir = "data/raw/statsbomb/events/",
                                  model_path = "models/xg_model.rds",
                                  competitions_path = "data/raw/statsbomb/competitions.json",
                                  output_path = "data/processed/team_match_xg.csv",
                                  use_own_model = TRUE) {
  
  suppressPackageStartupMessages({
    library(jsonlite)
    library(dplyr)
    library(tidymodels)
  })
  
  # Load xG model if using our own
  if (use_own_model) {
    if (!file.exists(model_path)) {
      stop(paste("xG model not found:", model_path))
    }
    xg_model <- readRDS(model_path)
    message("Loaded xG model from ", model_path)
  }
  
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
    if (length(events) > 0 && !is.null(events[[1]]$match_date)) {
      tryCatch({
        match_date <- as.Date(events[[1]]$match_date)
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
    shot_events <- events[sapply(events, function(e) {
      !is.null(e$type) && !is.null(e$type$name) && e$type$name == "Shot"
    })]
    
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
    
    # Compute xG for each shot using our own model
    if (use_own_model) {
      # Extract features and predict xG for home shots
      home_xg_values <- compute_shot_xg_values(home_shots, xg_model, comp_name)
      away_xg_values <- compute_shot_xg_values(away_shots, xg_model, comp_name)
    } else {
      # Use StatsBomb's xG values
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
    }
    
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

#' Helper function to compute xG values for a list of shot events using our model
#'
#' @param shot_events List of shot events from StatsBomb JSON
#' @param model Trained xG model (tidymodels workflow)
#' @param competition_name Competition name to use for prediction
#' @return Numeric vector of xG values
compute_shot_xg_values <- function(shot_events, model, competition_name) {
  if (length(shot_events) == 0) {
    return(numeric(0))
  }
  
  # Extract features for all shots
  n_shots <- length(shot_events)
  distances <- numeric(n_shots)
  angles <- numeric(n_shots)
  headers <- logical(n_shots)
  open_plays <- logical(n_shots)
  
  GOAL_CENTER_X <- 120
  GOAL_CENTER_Y <- 40
  GOAL_POST_Y1 <- 36.34
  GOAL_POST_Y2 <- 43.66
  GOAL_WIDTH <- GOAL_POST_Y2 - GOAL_POST_Y1
  
  for (i in seq_len(n_shots)) {
    shot <- shot_events[[i]]
    
    # Extract coordinates
    if (!is.null(shot$location) && length(shot$location) >= 2) {
      x <- as.numeric(shot$location[1])
      y <- as.numeric(shot$location[2])
      
      # Calculate distance
      distances[i] <- sqrt((GOAL_CENTER_X - x)^2 + (GOAL_CENTER_Y - y)^2)
      
      # Calculate angle using law of cosines
      a <- sqrt((GOAL_CENTER_X - x)^2 + (GOAL_POST_Y1 - y)^2)
      b <- sqrt((GOAL_CENTER_X - x)^2 + (GOAL_POST_Y2 - y)^2)
      cos_theta <- (a^2 + b^2 - GOAL_WIDTH^2) / (2 * a * b)
      angles[i] <- acos(pmax(-1, pmin(1, cos_theta)))
    } else {
      distances[i] <- NA
      angles[i] <- NA
    }
    
    # Extract header flag
    if (!is.null(shot$shot) && !is.null(shot$shot$body_part) && !is.null(shot$shot$body_part$name)) {
      headers[i] <- shot$shot$body_part$name == "Head"
    } else {
      headers[i] <- FALSE
    }
    
    # Extract open_play flag
    if (!is.null(shot$play_pattern) && !is.null(shot$play_pattern$name)) {
      open_plays[i] <- shot$play_pattern$name == "Regular Play"
    } else {
      open_plays[i] <- FALSE
    }
  }
  
  # Create data frame for prediction
  new_data <- data.frame(
    distance = distances,
    angle = angles,
    header = headers,
    open_play = open_plays,
    competition = rep(competition_name, n_shots),
    stringsAsFactors = FALSE
  )
  
  # Predict xG
  predictions <- predict(model, new_data = new_data, type = "prob")
  
  # Extract goal probability column
  goal_col <- NULL
  if (".pred_Goal" %in% names(predictions)) {
    goal_col <- ".pred_Goal"
  } else if (".pred_TRUE" %in% names(predictions)) {
    goal_col <- ".pred_TRUE"
  } else if (ncol(predictions) == 2) {
    goal_col <- names(predictions)[2]
  } else {
    # Try to find any column containing Goal or TRUE
    goal_cols <- grep("Goal|TRUE", names(predictions), ignore.case = TRUE, value = TRUE)
    if (length(goal_cols) > 0) {
      goal_col <- goal_cols[1]
    }
  }
  
  if (is.null(goal_col)) {
    stop("Could not determine goal probability column from prediction")
  }
  
  return(predictions[[goal_col]])
}

#' Wrapper function to run team-match xG computation
#' @export
run_team_match_xg <- function(use_own_model = TRUE) {
  result <- compute_team_match_xg(use_own_model = use_own_model)
  invisible(result)
}
