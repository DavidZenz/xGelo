#' Elo Rating System for xGelo
#'
#' This script implements a custom Elo rating system for international football
#' using martj42 historical results. It includes configurable k-factor, home advantage,
#' and rating decay.
#'
#' @author xGelo project
#' @date 2026-06-03

#' Compute expected result for team A against team B
#'
#' @param rating_a Numeric rating for team A
#' @param rating_b Numeric rating for team B
#' @return Numeric probability (0-1) that team A wins
#' @examples
#' expected_result(1500, 1500)  # Should return 0.5
#' expected_result(1600, 1500)  # Team A has higher rating
#' @export
expected_result <- function(rating_a, rating_b) {
  if (missing(rating_a) || missing(rating_b)) {
    stop("Both ratings must be provided")
  }
  if (!is.numeric(rating_a) || !is.numeric(rating_b)) {
    stop("Ratings must be numeric")
  }
  if (length(rating_a) != 1 || length(rating_b) != 1) {
    stop("Ratings must be scalar values")
  }
  
  1 / (1 + 10^((rating_b - rating_a) / 400))
}

#' Compute Elo rating update for both teams
#'
#' @param rating_a Current rating for team A (home team)
#' @param rating_b Current rating for team B (away team)
#' @param actual_result Actual result: 1 (team A win), 0.5 (draw), 0 (team B win)
#' @param k_factor_a K-factor for team A
#' @param k_factor_b K-factor for team B
#' @param home_advantage Home advantage points (default: 60 for non-neutral)
#' @param is_home Logical, TRUE if team A is home (default: TRUE)
#' @return List with updated ratings: rating_a, rating_b
#' @export
elo_update <- function(rating_a, rating_b, actual_result, k_factor_a, k_factor_b, home_advantage = 60, is_home = TRUE) {
  # Input validation
  if (missing(actual_result)) {
    stop("actual_result must be provided")
  }
  if (!actual_result %in% c(0, 0.5, 1)) {
    stop("actual_result must be in {0, 0.5, 1}")
  }
  if (!is.numeric(rating_a) || !is.numeric(rating_b)) {
    stop("Ratings must be numeric")
  }
  if (!is.numeric(k_factor_a) || !is.numeric(k_factor_b)) {
    stop("K-factors must be numeric")
  }
  
  # Apply home advantage to home team's rating for expected result calculation
  if (is_home) {
    rating_a_adj <- rating_a + home_advantage
    rating_b_adj <- rating_b
  } else {
    # If away, apply advantage to team B
    rating_a_adj <- rating_a
    rating_b_adj <- rating_b + home_advantage
  }
  
  # Compute expected results
  exp_a <- expected_result(rating_a_adj, rating_b_adj)
  exp_b <- 1 - exp_a
  
  # Compute rating updates
  # For team A: actual_result is from A's perspective (1 = A win, 0 = A loss, 0.5 = draw)
  rating_a_new <- rating_a + k_factor_a * (actual_result - exp_a)
  
  # For team B: actual_result from B's perspective is (1 - actual_result_from_A)
  # If actual_result = 1 (A wins), B's result = 0
  # If actual_result = 0 (B wins), B's result = 1
  # If actual_result = 0.5 (draw), B's result = 0.5
  rating_b_new <- rating_b + k_factor_b * ((1 - actual_result) - exp_b)
  
  list(rating_a = rating_a_new, rating_b = rating_b_new)
}

#' Apply rating decay based on days since last match
#'
#' @param rating Current rating
#' @param days_since_last Number of days since last match
#' @return Decayed rating
#' @export
apply_decay <- function(rating, days_since_last) {
  if (missing(days_since_last) || is.na(days_since_last)) {
    return(rating)  # No decay if no information
  }
  if (!is.numeric(rating) || !is.numeric(days_since_last)) {
    stop("rating and days_since_last must be numeric")
  }
  
  rating * (0.995 ^ (days_since_last / 365))
}

#' Get k-factor based on match frequency
#'
#' @param matches_last_year Number of matches in the last year
#' @param matches_this_year Number of matches in the current year
#' @return K-factor (20 or 40)
#' @export
get_k_factor <- function(matches_last_year, matches_this_year) {
  total_matches <- matches_last_year + matches_this_year
  if (total_matches >= 15) {
    return(20)
  } else {
    return(40)
  }
}

#' Main function to compute Elo ratings for all matches
#'
#' @param matches_df Data frame with match data (must contain: date, home_team, away_team, home_score, away_score, neutral)
#' @param team_map_df Data frame with team name mapping (fifa_code, canonical_name, source_name)
#' @param home_advantage Numeric home advantage in points (default: 60)
#' @param base_rating Numeric base rating for new teams (default: 1500)
#' @return List containing:
#'         - ratings_history: Data frame with all historical ratings
#'         - current_ratings: Data frame with most recent ratings
#'         - matches_processed: Data frame with processed match results
#' @export
compute_elo <- function(matches_df, team_map_df, home_advantage = 60, base_rating = 1500) {
  # Input validation
  if (nrow(matches_df) == 0) {
    stop("matches_df must contain at least one match")
  }
  
  required_cols <- c("date", "home_team", "away_team", "home_score", "away_score", "neutral")
  missing_cols <- setdiff(required_cols, names(matches_df))
  if (length(missing_cols) > 0) {
    stop(paste("Missing required columns:", paste(missing_cols, collapse = ", ")))
  }
  
  # Preprocess matches: determine result, sort chronologically
  matches_processed <- matches_df |>
    mutate(
      date = as.Date(date),
      result = case_when(
        home_score > away_score ~ 1.0,
        home_score == away_score ~ 0.5,
        home_score < away_score ~ 0.0
      ),
      is_home = !neutral
    ) |>
    arrange(date)
  
  # Get unique teams and initialize ratings
  all_teams <- unique(c(matches_processed$home_team, matches_processed$away_team))
  
  # Create team mapping for quick lookup
  team_to_fifa <- team_map_df$fifa_code
  names(team_to_fifa) <- team_map_df$source_name
  
  # For teams without FIFA code, use canonical name
  team_to_canonical <- team_map_df$canonical_name
  names(team_to_canonical) <- team_map_df$source_name
  
  # Initialize ratings data frame
  ratings_history <- data.frame(
    date = as.Date(character()),
    team = character(),
    fifa_code = character(),
    rating = numeric(),
    match_id = character(),
    is_post_match = logical(),
    stringsAsFactors = FALSE
  )
  
  # Initialize current ratings
  current_ratings <- data.frame(
    team = all_teams,
    fifa_code = sapply(all_teams, function(t) {
      if (t %in% names(team_to_fifa)) {
        team_to_fifa[[t]]
      } else if (t %in% names(team_to_canonical)) {
        team_to_canonical[[t]]
      } else {
        NA_character_
      }
    }),
    rating = base_rating,
    last_match_date = as.Date(NA),
    matches_last_year = 0,
    matches_this_year = 0,
    stringsAsFactors = FALSE
  )
  
  # Process each match
  for (i in 1:nrow(matches_processed)) {
    match <- matches_processed[i, ]
    home_team <- match$home_team
    away_team <- match$away_team
    match_date <- match$date
    is_home <- match$is_home
    result <- match$result
    
    # Get current ratings
    home_idx <- which(current_ratings$team == home_team)
    away_idx <- which(current_ratings$team == away_team)
    
    if (length(home_idx) == 0 || length(away_idx) == 0) {
      warning(paste("Team not found in ratings:", home_team, "or", away_team))
      next
    }
    
    home_rating <- current_ratings$rating[home_idx]
    away_rating <- current_ratings$rating[away_idx]
    
    # Apply decay based on days since last match
    if (!is.na(current_ratings$last_match_date[home_idx])) {
      days_since_home <- as.numeric(difftime(match_date, 
                                            current_ratings$last_match_date[home_idx],
                                            units = "days"))
      home_rating <- apply_decay(home_rating, days_since_home)
    }
    
    if (!is.na(current_ratings$last_match_date[away_idx])) {
      days_since_away <- as.numeric(difftime(match_date,
                                            current_ratings$last_match_date[away_idx],
                                            units = "days"))
      away_rating <- apply_decay(away_rating, days_since_away)
    }
    
    # Update current ratings with decayed values
    current_ratings$rating[home_idx] <- home_rating
    current_ratings$rating[away_idx] <- away_rating
    
    # Save pre-match ratings to history
    match_id <- paste(home_team, away_team, match_date, sep = "_")
    
    ratings_history <- rbind(ratings_history, 
      data.frame(
        date = match_date,
        team = home_team,
        fifa_code = current_ratings$fifa_code[home_idx],
        rating = home_rating,
        match_id = match_id,
        is_post_match = FALSE,
        stringsAsFactors = FALSE
      )
    )
    
    ratings_history <- rbind(ratings_history,
      data.frame(
        date = match_date,
        team = away_team,
        fifa_code = current_ratings$fifa_code[away_idx],
        rating = away_rating,
        match_id = match_id,
        is_post_match = FALSE,
        stringsAsFactors = FALSE
      )
    )
    
    # Determine k-factors
    k_home <- get_k_factor(current_ratings$matches_last_year[home_idx], 
                           current_ratings$matches_this_year[home_idx])
    k_away <- get_k_factor(current_ratings$matches_last_year[away_idx],
                           current_ratings$matches_this_year[away_idx])
    
    # Update ratings using elo_update
    update <- elo_update(home_rating, away_rating, result, k_home, k_away, 
                         home_advantage, is_home)
    
    # Update current ratings
    current_ratings$rating[home_idx] <- update$rating_a
    current_ratings$rating[away_idx] <- update$rating_b
    current_ratings$last_match_date[home_idx] <- match_date
    current_ratings$last_match_date[away_idx] <- match_date
    
    # Update match counts for k-factor calculation
    match_year <- as.integer(format(match_date, "%Y"))
    
    # Reset yearly counts if year changed
    if (is.na(current_ratings$last_match_date[home_idx]) || 
        as.integer(format(current_ratings$last_match_date[home_idx], "%Y")) != match_year) {
      current_ratings$matches_last_year[home_idx] <- current_ratings$matches_this_year[home_idx]
      current_ratings$matches_this_year[home_idx] <- 1
    } else {
      current_ratings$matches_this_year[home_idx] <- current_ratings$matches_this_year[home_idx] + 1
    }
    
    if (is.na(current_ratings$last_match_date[away_idx]) ||
        as.integer(format(current_ratings$last_match_date[away_idx], "%Y")) != match_year) {
      current_ratings$matches_last_year[away_idx] <- current_ratings$matches_this_year[away_idx]
      current_ratings$matches_this_year[away_idx] <- 1
    } else {
      current_ratings$matches_this_year[away_idx] <- current_ratings$matches_this_year[away_idx] + 1
    }
    
    # Save post-match ratings to history
    ratings_history <- rbind(ratings_history,
      data.frame(
        date = match_date,
        team = home_team,
        fifa_code = current_ratings$fifa_code[home_idx],
        rating = update$rating_a,
        match_id = match_id,
        is_post_match = TRUE,
        stringsAsFactors = FALSE
      )
    )
    
    ratings_history <- rbind(ratings_history,
      data.frame(
        date = match_date,
        team = away_team,
        fifa_code = current_ratings$fifa_code[away_idx],
        rating = update$rating_b,
        match_id = match_id,
        is_post_match = TRUE,
        stringsAsFactors = FALSE
      )
    )
    
    # Periodic progress update for long runs
    if (i %% 1000 == 0) {
      message(paste("Processed", i, "of", nrow(matches_processed), "matches..."))
    }
  }
  
  # Get most recent ratings (post-match only)
  current_ratings_final <- current_ratings
  
  list(
    ratings_history = ratings_history,
    current_ratings = current_ratings_final,
    matches_processed = matches_processed
  )
}
