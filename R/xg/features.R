#' xGelo: xG Feature Calculations
#'
#' Functions for calculating xG features from StatsBomb event coordinates.
#' Uses StatsBomb standard coordinate system (120x80 yard pitch).

#' StatsBomb Pitch Constants
#'
#' @description Constants for the StatsBomb coordinate system.
#' @details
#' - Pitch dimensions: 120 yards (length) x 80 yards (width)
#' - Goal centered at x=120, with posts at y=36.34 and y=43.66
#' - Goal width: 7.32 yards (distance between posts)
PITCH_LENGTH <- 120
PITCH_WIDTH <- 80
GOAL_CENTER_X <- 120
GOAL_CENTER_Y <- 40
GOAL_POST_Y1 <- 36.34
GOAL_POST_Y2 <- 43.66
GOAL_WIDTH <- GOAL_POST_Y2 - GOAL_POST_Y1

#' Calculate Euclidean Distance to Goal Center
#'
#' @description Computes the straight-line distance from a shot location to the goal center.
#'
#' @param x Numeric vector of x-coordinates (along pitch length)
#' @param y Numeric vector of y-coordinates (along pitch width)
#' @return Numeric vector of distances in yards
#' @examples
#' calculate_distance(108, 40)  # Penalty spot: ~12 yards
#' calculate_distance(60, 40)   # Center spot: 60 yards
#' @export
calculate_distance <- function(x, y) {
  sqrt((GOAL_CENTER_X - x)^2 + (GOAL_CENTER_Y - y)^2)
}

#' Calculate Shot Angle to Goal
#'
#' @description Computes the angle between the shot location and the two goalposts
#' using the law of cosines. The angle represents how "central" the shot is.
#'
#' @param x Numeric vector of x-coordinates
#' @param y Numeric vector of y-coordinates
#' @return Numeric vector of angles in radians [0, π]
#' @details
#' The angle is calculated using the law of cosines: cos(angle) = (a² + b² - c²) / (2ab)
#' where a and b are distances to each goalpost, and c is the goal width.
#' @examples
#' calculate_angle(60, 40)   # Center: π/2 radians (90 degrees)
#' calculate_angle(108, 40)  # Penalty spot: small angle
#' @export
calculate_angle <- function(x, y) {
  a <- sqrt((GOAL_CENTER_X - x)^2 + (GOAL_POST_Y1 - y)^2)
  b <- sqrt((GOAL_CENTER_X - x)^2 + (GOAL_POST_Y2 - y)^2)
  c <- GOAL_WIDTH
  
  # Law of cosines: cos(theta) = (a^2 + b^2 - c^2) / (2 * a * b)
  cos_theta <- (a^2 + b^2 - c^2) / (2 * a * b)
  
  # Clamp to [-1, 1] to avoid numerical errors
  cos_theta <- pmax(-1, pmin(1, cos_theta))
  
  # Convert to radians
  acos(cos_theta)
}

#' Extract xG Features from StatsBomb Events Data Frame
#'
#' @description Extracts the complete xG feature set from a StatsBomb events data frame.
#'
#' @param events_df A data frame of StatsBomb events (as loaded from JSON)
#' @param competition_name Character string for the competition name
#' @return A data frame with columns: distance, angle, header, open_play, competition, goal
#' @details
#' The events_df should be a data frame with columns: type, location, shot, play_pattern.
#' Each column is a nested data frame with the same number of rows as events_df.
#' Filters to only shot events (type$name == "Shot"), excludes penalties.
#' @export
extract_features_from_events <- function(events_df, competition_name = NA_character_) {
  # Validate input
  if (!is.data.frame(events_df)) {
    stop("events_df must be a data frame")
  }
  
  # Find shot event indices
  shot_idx <- which(events_df$type$name == "Shot")
  
  if (length(shot_idx) == 0) {
    return(data.frame(
      distance = numeric(0),
      angle = numeric(0),
      header = logical(0),
      open_play = logical(0),
      competition = character(0),
      goal = logical(0)
    ))
  }
  
  # Initialize feature vectors
  n_shots <- length(shot_idx)
  distances <- numeric(n_shots)
  angles <- numeric(n_shots)
  headers <- logical(n_shots)
  open_plays <- logical(n_shots)
  goals <- logical(n_shots)
  competitions <- character(n_shots)
  
  # Extract features for each shot
  for (i in seq_len(n_shots)) {
    idx <- shot_idx[i]
    
    # Extract coordinates from location list column
    loc <- events_df$location[[idx]]
    if (is.null(loc) || length(loc) < 2) {
      distances[i] <- NA
      angles[i] <- NA
    } else {
      x <- loc[1]
      y <- loc[2]
      distances[i] <- calculate_distance(x, y)
      angles[i] <- calculate_angle(x, y)
    }
    
    # Extract header flag from shot$body_part$name
    bp <- events_df$shot$body_part$name[idx]
    headers[i] <- !is.na(bp) && bp == "Head"
    
    # Extract open_play flag from play_pattern$name
    pp <- events_df$play_pattern$name[idx]
    open_plays[i] <- !is.na(pp) && pp == "Regular Play"
    
    # Extract goal flag from shot$outcome$name
    outcome <- events_df$shot$outcome$name[idx]
    goals[i] <- !is.na(outcome) && outcome == "Goal"
    
    # Competition
    competitions[i] <- as.character(competition_name)
  }
  
  # Filter out penalty shots
  penalty_idx <- which(events_df$shot$type$name[shot_idx] == "Penalty")
  if (length(penalty_idx) > 0) {
    keep <- setdiff(seq_len(n_shots), penalty_idx)
    distances <- distances[keep]
    angles <- angles[keep]
    headers <- headers[keep]
    open_plays <- open_plays[keep]
    goals <- goals[keep]
    competitions <- competitions[keep]
  }
  
  # Create result data frame
  # Note: goal is kept as logical for compatibility; will be converted to factor in model training if needed
  data.frame(
    distance = distances,
    angle = angles,
    header = headers,
    open_play = open_plays,
    competition = competitions,
    goal = goals,
    stringsAsFactors = FALSE
  )
}
