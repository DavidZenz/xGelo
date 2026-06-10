#' Optimized Elo Rating System for xGelo
#'
#' This script implements an optimized custom Elo rating system for international football.
#' It uses pre-allocated data structures and avoids rbind in loops for better performance.
#'
#' @author xGelo project
#' @date 2026-06-03

#' Compute expected result for team A against team B
#' @export
expected_result <- function(rating_a, rating_b) {
  1 / (1 + 10^((rating_b - rating_a) / 400))
}

#' Apply rating decay based on days since last match
#' @export
apply_decay <- function(rating, days_since_last) {
  if (missing(days_since_last) || is.na(days_since_last)) {
    return(rating)
  }
  rating * (0.995 ^ (days_since_last / 365))
}

#' Get k-factor based on match frequency
#' @export
get_k_factor <- function(matches_last_year, matches_this_year) {
  total_matches <- matches_last_year + matches_this_year
  if (total_matches >= 15) {
    return(20)
  } else {
    return(40)
  }
}

#' Compute Elo rating update for both teams
#' @export
elo_update <- function(rating_a, rating_b, actual_result, k_factor_a, k_factor_b, 
                      home_advantage = 60, is_home = TRUE) {
  if (is_home) {
    rating_a_adj <- rating_a + home_advantage
    rating_b_adj <- rating_b
  } else {
    rating_a_adj <- rating_a
    rating_b_adj <- rating_b + home_advantage
  }
  
  exp_a <- expected_result(rating_a_adj, rating_b_adj)
  exp_b <- 1 - exp_a
  
  rating_a_new <- rating_a + k_factor_a * (actual_result - exp_a)
  rating_b_new <- rating_b + k_factor_b * ((1 - actual_result) - exp_b)
  
  list(rating_a = rating_a_new, rating_b = rating_b_new)
}

#' Optimized compute_elo function that pre-allocates arrays
#' @export
compute_elo_optimized <- function(matches_df, team_map_df, home_advantage = 60, 
                                  base_rating = 1500, batch_size = 5000) {
  
  # Input validation
  if (nrow(matches_df) == 0) {
    stop("matches_df must contain at least one match")
  }
  
  required_cols <- c("date", "home_team_canonical", "away_team_canonical", 
                    "home_score", "away_score", "neutral", "result", "is_home")
  missing_cols <- setdiff(required_cols, names(matches_df))
  if (length(missing_cols) > 0) {
    stop(paste("Missing required columns:", paste(missing_cols, collapse = ", ")))
  }
  
  # Ensure date is Date object
  if (!inherits(matches_df$date, "Date")) {
    matches_df$date <- as.Date(matches_df$date)
  }
  
  # Sort by date
  matches_df <- matches_df[order(matches_df$date), ]

  scored_rows <- is.finite(matches_df$result) &
    is.finite(matches_df$home_score) &
    is.finite(matches_df$away_score)
  skipped_unscored <- sum(!scored_rows)
  if (skipped_unscored > 0) {
    message(paste("Skipping", skipped_unscored, "unscored matches for Elo rating updates"))
    matches_df <- matches_df[scored_rows, , drop = FALSE]
  }
  if (nrow(matches_df) == 0) {
    stop("matches_df must contain at least one scored match")
  }
  
  # Create team mapping
  all_teams <- unique(c(matches_df$home_team_canonical, matches_df$away_team_canonical))
  n_teams <- length(all_teams)
  
  # Create named vector for team to index mapping
  team_to_idx <- seq_len(n_teams)
  names(team_to_idx) <- all_teams
  
  # Create FIFA code mapping
  fifa_codes <- rep(NA_character_, n_teams)
  for (i in seq_len(n_teams)) {
    team_name <- all_teams[i]
    match_idx <- which(team_map_df$canonical_name == team_name)
    if (length(match_idx) > 0) {
      fifa_codes[i] <- team_map_df$fifa_code[match_idx]
    }
  }
  
  # Initialize current ratings (pre-allocated arrays)
  ratings <- rep(base_rating, n_teams)
  last_match_dates <- rep(as.Date(NA), n_teams)
  matches_last_year <- rep(0, n_teams)
  matches_this_year <- rep(0, n_teams)
  
  # Pre-allocate history storage
  # We'll store: date, team, fifa_code, rating, match_id, is_post_match
  # This is more memory-efficient than rbind in a loop
  max_history_size <- nrow(matches_df) * 2 * 2  # 2 teams per match, 2 entries each (pre+post)
  history_date <- rep(as.Date(NA), max_history_size)
  history_team <- rep(NA_character_, max_history_size)
  history_fifa <- rep(NA_character_, max_history_size)
  history_rating <- rep(NA_real_, max_history_size)
  history_match_id <- rep(NA_character_, max_history_size)
  history_is_post <- rep(NA, max_history_size)
  
  history_counter <- 0
  
  # Add pre-match rating entries for initial state
  initial_date <- min(matches_df$date) - 1
  for (i in seq_len(n_teams)) {
    history_counter <- history_counter + 1
    history_date[history_counter] <- initial_date
    history_team[history_counter] <- all_teams[i]
    history_fifa[history_counter] <- fifa_codes[i]
    history_rating[history_counter] <- base_rating
    history_match_id[history_counter] <- "initial"
    history_is_post[history_counter] <- FALSE
  }
  
  # Process matches in batches for better performance
  n_matches <- nrow(matches_df)
  
  for (start_idx in seq(1, n_matches, by = batch_size)) {
    end_idx <- min(start_idx + batch_size - 1, n_matches)
    batch_matches <- matches_df[start_idx:end_idx, ]
    
    for (i in 1:nrow(batch_matches)) {
      match <- batch_matches[i, ]
      home_team <- match$home_team_canonical
      away_team <- match$away_team_canonical
      match_date <- match$date
      is_home <- match$is_home
      result <- match$result
      
      # Get team indices
      home_idx <- team_to_idx[[home_team]]
      away_idx <- team_to_idx[[away_team]]
      
      if (is.na(home_idx) || is.na(away_idx)) {
        next
      }
      
      home_rating <- ratings[home_idx]
      away_rating <- ratings[away_idx]
      
      # Apply decay
      if (!is.na(last_match_dates[home_idx])) {
        days_since_home <- as.numeric(difftime(match_date, last_match_dates[home_idx], units = "days"))
        home_rating <- apply_decay(home_rating, days_since_home)
      }
      
      if (!is.na(last_match_dates[away_idx])) {
        days_since_away <- as.numeric(difftime(match_date, last_match_dates[away_idx], units = "days"))
        away_rating <- apply_decay(away_rating, days_since_away)
      }
      
      # Update current ratings with decayed values
      ratings[home_idx] <- home_rating
      ratings[away_idx] <- away_rating
      
      # Save pre-match ratings to history
      match_id <- paste(home_team, away_team, as.character(match_date), sep = "_")
      
      history_counter <- history_counter + 1
      history_date[history_counter] <- match_date
      history_team[history_counter] <- home_team
      history_fifa[history_counter] <- fifa_codes[home_idx]
      history_rating[history_counter] <- home_rating
      history_match_id[history_counter] <- match_id
      history_is_post[history_counter] <- FALSE
      
      history_counter <- history_counter + 1
      history_date[history_counter] <- match_date
      history_team[history_counter] <- away_team
      history_fifa[history_counter] <- fifa_codes[away_idx]
      history_rating[history_counter] <- away_rating
      history_match_id[history_counter] <- match_id
      history_is_post[history_counter] <- FALSE
      
      # Determine k-factors
      k_home <- get_k_factor(matches_last_year[home_idx], matches_this_year[home_idx])
      k_away <- get_k_factor(matches_last_year[away_idx], matches_this_year[away_idx])
      
      # Update ratings using elo_update
      update <- elo_update(home_rating, away_rating, result, k_home, k_away, home_advantage, is_home)
      
      previous_home_match_date <- last_match_dates[home_idx]
      previous_away_match_date <- last_match_dates[away_idx]
      
      # Update current ratings
      ratings[home_idx] <- update$rating_a
      ratings[away_idx] <- update$rating_b
      last_match_dates[home_idx] <- match_date
      last_match_dates[away_idx] <- match_date
      
      # Update match counts for k-factor calculation
      match_year <- as.integer(format(match_date, "%Y"))
      
      if (is.na(previous_home_match_date) || as.integer(format(previous_home_match_date, "%Y")) != match_year) {
        matches_last_year[home_idx] <- matches_this_year[home_idx]
        matches_this_year[home_idx] <- 1
      } else {
        matches_this_year[home_idx] <- matches_this_year[home_idx] + 1
      }
      
      if (is.na(previous_away_match_date) || as.integer(format(previous_away_match_date, "%Y")) != match_year) {
        matches_last_year[away_idx] <- matches_this_year[away_idx]
        matches_this_year[away_idx] <- 1
      } else {
        matches_this_year[away_idx] <- matches_this_year[away_idx] + 1
      }
      
      # Save post-match ratings to history
      history_counter <- history_counter + 1
      history_date[history_counter] <- match_date
      history_team[history_counter] <- home_team
      history_fifa[history_counter] <- fifa_codes[home_idx]
      history_rating[history_counter] <- update$rating_a
      history_match_id[history_counter] <- match_id
      history_is_post[history_counter] <- TRUE
      
      history_counter <- history_counter + 1
      history_date[history_counter] <- match_date
      history_team[history_counter] <- away_team
      history_fifa[history_counter] <- fifa_codes[away_idx]
      history_rating[history_counter] <- update$rating_b
      history_match_id[history_counter] <- match_id
      history_is_post[history_counter] <- TRUE
    }
    
    message(paste("Processed batch up to match", end_idx, "of", n_matches))
  }
  
  # Trim history arrays to actual size
  history_date <- history_date[1:history_counter]
  history_team <- history_team[1:history_counter]
  history_fifa <- history_fifa[1:history_counter]
  history_rating <- history_rating[1:history_counter]
  history_match_id <- history_match_id[1:history_counter]
  history_is_post <- history_is_post[1:history_counter]
  
  # Create result data frames
  ratings_history <- data.frame(
    date = history_date,
    team = history_team,
    fifa_code = history_fifa,
    rating = history_rating,
    match_id = history_match_id,
    is_post_match = history_is_post,
    stringsAsFactors = FALSE
  )
  
  current_ratings <- data.frame(
    team = all_teams,
    fifa_code = fifa_codes,
    rating = ratings,
    last_match_date = last_match_dates,
    matches_last_year = matches_last_year,
    matches_this_year = matches_this_year,
    stringsAsFactors = FALSE
  )
  
  list(
    ratings_history = ratings_history,
    current_ratings = current_ratings,
    matches_processed = matches_df
  )
}
