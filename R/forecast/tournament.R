#' xGelo Forecasting Layer - Tournament Simulation
#'
#' Simulates explicit tournament fixture sets from match scoreline distributions.

#' Rank a group table using FIFA World Cup group table rules
#'
#' @param table Group table with team, points, goal_difference, goals_for
#' @param matches Optional match rows with home_team, away_team, home_goals, away_goals
#' @return Ranked table
#' @export
rank_group_table <- function(table, matches = NULL) {
  required_cols <- c("team", "points", "goal_difference", "goals_for")
  missing_cols <- setdiff(required_cols, names(table))
  if (length(missing_cols) > 0) {
    stop(paste("Group table missing required columns:", paste(missing_cols, collapse = ", ")))
  }

  tie_breaker <- if ("tie_breaker" %in% names(table)) table$tie_breaker else runif(nrow(table))
  table$tie_breaker <- tie_breaker

  if (is.null(matches) || nrow(matches) == 0) {
    return(table[order(-table$points, -table$goal_difference, -table$goals_for, table$tie_breaker), ])
  }

  match_required <- c("home_team", "away_team", "home_goals", "away_goals")
  if (length(setdiff(match_required, names(matches))) > 0) {
    return(table[order(-table$points, -table$goal_difference, -table$goals_for, table$tie_breaker), ])
  }

  fallback_order <- function(idx) {
    idx[order(-table$points[idx], -table$goal_difference[idx], -table$goals_for[idx], table$tie_breaker[idx])]
  }

  rank_tied_idx <- function(idx) {
    if (length(idx) <= 1) return(idx)

    teams <- table$team[idx]
    h2h_points <- numeric(length(idx))
    h2h_goal_difference <- numeric(length(idx))
    h2h_goals_for <- numeric(length(idx))

    for (i in seq_len(nrow(matches))) {
      home_pos <- match(matches$home_team[i], teams)
      away_pos <- match(matches$away_team[i], teams)
      if (is.na(home_pos) || is.na(away_pos) || is.na(matches$home_goals[i]) || is.na(matches$away_goals[i])) next

      home_goals <- as.integer(matches$home_goals[i])
      away_goals <- as.integer(matches$away_goals[i])
      home_points <- if (home_goals > away_goals) 3L else if (home_goals == away_goals) 1L else 0L
      away_points <- if (away_goals > home_goals) 3L else if (home_goals == away_goals) 1L else 0L

      h2h_points[home_pos] <- h2h_points[home_pos] + home_points
      h2h_points[away_pos] <- h2h_points[away_pos] + away_points
      h2h_goal_difference[home_pos] <- h2h_goal_difference[home_pos] + home_goals - away_goals
      h2h_goal_difference[away_pos] <- h2h_goal_difference[away_pos] + away_goals - home_goals
      h2h_goals_for[home_pos] <- h2h_goals_for[home_pos] + home_goals
      h2h_goals_for[away_pos] <- h2h_goals_for[away_pos] + away_goals
    }

    ord <- order(-h2h_points, -h2h_goal_difference, -h2h_goals_for)
    ordered_idx <- idx[ord]
    keys <- paste(h2h_points[ord], h2h_goal_difference[ord], h2h_goals_for[ord], sep = "\r")
    if (length(unique(keys)) == 1) {
      return(fallback_order(idx))
    }

    ranked_parts <- lapply(split(ordered_idx, factor(keys, levels = unique(keys)), drop = TRUE), function(part) {
      if (length(part) <= 1) part else rank_tied_idx(part)
    })
    unlist(ranked_parts, use.names = FALSE)
  }

  point_levels <- sort(unique(table$points), decreasing = TRUE)
  ranked_idx <- unlist(
    lapply(point_levels, function(points) rank_tied_idx(which(table$points == points))),
    use.names = FALSE
  )
  table[ranked_idx, ]
}

#' Simulate a tournament from explicit fixtures
#'
#' @param fixtures Data frame with match_id, stage, group, home_team, away_team, date, venue
#' @param n_tournaments Number of tournament simulations
#' @param n_match_sim Number of simulations used to precompute each fixture distribution
#' @param seed Random seed for reproducibility
#' @param ... Additional arguments passed to simulate_fixture
#' @return List with stage probabilities, champion probabilities, match forecasts, and sampled tournament
#' @export
simulate_tournament <- function(
    fixtures,
    n_tournaments = 10000,
    n_match_sim = 5000,
    seed = NULL,
    ...
) {
  suppressPackageStartupMessages({
    library(dplyr)
  })
  if (!exists("simulate_fixture")) {
    source("R/forecast/monte_carlo.R")
  }
  if (n_tournaments <= 0) stop("n_tournaments must be positive")
  if (n_match_sim <= 0) stop("n_match_sim must be positive")

  required_cols <- c("match_id", "stage", "group", "home_team", "away_team", "date", "venue")
  missing_cols <- setdiff(required_cols, names(fixtures))
  if (length(missing_cols) > 0) {
    stop(paste("Fixtures missing required columns:", paste(missing_cols, collapse = ", ")))
  }

  if (!is.null(seed)) set.seed(seed)
  fixture_seeds <- sample.int(.Machine$integer.max, nrow(fixtures))

  match_forecasts <- vector("list", nrow(fixtures))
  for (i in seq_len(nrow(fixtures))) {
    fixture <- fixtures[i, ]
    sim <- simulate_fixture(
      home_team = fixture$home_team,
      away_team = fixture$away_team,
      date = fixture$date,
      venue = fixture$venue,
      n_sim = n_match_sim,
      seed = fixture_seeds[i],
      include_scoreline_distribution = TRUE,
      ...
    )
    match_forecasts[[i]] <- list(
      match_id = fixture$match_id,
      fixture = fixture,
      forecast = sim,
      scoreline_distribution = sim$scoreline_distribution
    )
  }

  teams <- sort(unique(c(fixtures$home_team, fixtures$away_team)))
  team_totals <- data.frame(
    team = teams,
    points_sum = 0,
    goals_for_sum = 0,
    goals_against_sum = 0,
    stringsAsFactors = FALSE
  )
  stage_counts <- data.frame(
    team = teams,
    group_count = 0,
    knockout_count = 0,
    champion_count = 0,
    stringsAsFactors = FALSE
  )

  sampled_tournament <- NULL
  lower_stage <- tolower(fixtures$stage)
  group_rows <- which(lower_stage %in% c("group", "group_stage"))
  knockout_rows <- setdiff(seq_len(nrow(fixtures)), group_rows)

  for (iteration in seq_len(n_tournaments)) {
    sampled_matches <- vector("list", nrow(fixtures))
    group_stats <- list()
    group_match_results <- fixtures[, c("group", "home_team", "away_team")]
    group_match_results$home_goals <- NA_integer_
    group_match_results$away_goals <- NA_integer_
    tournament_champion <- NA_character_
    iteration_group_teams <- character()
    iteration_knockout_teams <- character()

    for (i in seq_len(nrow(fixtures))) {
      forecast <- match_forecasts[[i]]$forecast
      dist <- match_forecasts[[i]]$scoreline_distribution
      draw <- dist[sample(seq_len(nrow(dist)), size = 1, prob = dist$probability), ]
      fixture <- fixtures[i, ]
      home_goals <- as.integer(draw$home_goals)
      away_goals <- as.integer(draw$away_goals)
      regulation_winner <- if (home_goals > away_goals) {
        fixture$home_team
      } else if (away_goals > home_goals) {
        fixture$away_team
      } else {
        NA_character_
      }
      knockout_winner <- regulation_winner
      if (is.na(knockout_winner) && !(i %in% group_rows)) {
        non_draw_total <- forecast$win_prob + forecast$loss_prob
        home_advance_prob <- if (non_draw_total > 0) forecast$win_prob / non_draw_total else 0.5
        knockout_winner <- if (runif(1) <= home_advance_prob) fixture$home_team else fixture$away_team
      }

      sampled_matches[[i]] <- data.frame(
        iteration = iteration,
        match_id = fixture$match_id,
        stage = fixture$stage,
        group = fixture$group,
        home_team = fixture$home_team,
        away_team = fixture$away_team,
        home_goals = home_goals,
        away_goals = away_goals,
        regulation_winner = regulation_winner,
        advancing_team = if (i %in% knockout_rows) knockout_winner else NA_character_,
        stringsAsFactors = FALSE
      )

      home_idx <- match(fixture$home_team, team_totals$team)
      away_idx <- match(fixture$away_team, team_totals$team)
      team_totals$goals_for_sum[home_idx] <- team_totals$goals_for_sum[home_idx] + home_goals
      team_totals$goals_against_sum[home_idx] <- team_totals$goals_against_sum[home_idx] + away_goals
      team_totals$goals_for_sum[away_idx] <- team_totals$goals_for_sum[away_idx] + away_goals
      team_totals$goals_against_sum[away_idx] <- team_totals$goals_against_sum[away_idx] + home_goals

      if (i %in% group_rows) {
        home_points <- if (home_goals > away_goals) 3 else if (home_goals == away_goals) 1 else 0
        away_points <- if (away_goals > home_goals) 3 else if (home_goals == away_goals) 1 else 0
        team_totals$points_sum[home_idx] <- team_totals$points_sum[home_idx] + home_points
        team_totals$points_sum[away_idx] <- team_totals$points_sum[away_idx] + away_points

        group_key <- as.character(fixture$group)
        if (is.null(group_stats[[group_key]])) {
          group_teams <- sort(unique(c(
            fixtures$home_team[group_rows][fixtures$group[group_rows] == fixture$group],
            fixtures$away_team[group_rows][fixtures$group[group_rows] == fixture$group]
          )))
          group_stats[[group_key]] <- data.frame(
            team = group_teams,
            points = 0,
            goals_for = 0,
            goals_against = 0,
            tie_breaker = runif(length(group_teams)),
            stringsAsFactors = FALSE
          )
        }
        group_match_results$home_goals[i] <- home_goals
        group_match_results$away_goals[i] <- away_goals
        table <- group_stats[[group_key]]
        gh <- match(fixture$home_team, table$team)
        ga <- match(fixture$away_team, table$team)
        table$points[gh] <- table$points[gh] + home_points
        table$points[ga] <- table$points[ga] + away_points
        table$goals_for[gh] <- table$goals_for[gh] + home_goals
        table$goals_against[gh] <- table$goals_against[gh] + away_goals
        table$goals_for[ga] <- table$goals_for[ga] + away_goals
        table$goals_against[ga] <- table$goals_against[ga] + home_goals
        group_stats[[group_key]] <- table
      } else {
        iteration_knockout_teams <- union(iteration_knockout_teams, c(fixture$home_team, fixture$away_team))
        tournament_champion <- knockout_winner
      }
    }

    for (group_key in names(group_stats)) {
      table <- group_stats[[group_key]]
      table$goal_difference <- table$goals_for - table$goals_against
      ranked <- rank_group_table(
        table,
        group_match_results[
          group_match_results$group == group_key,
          c("home_team", "away_team", "home_goals", "away_goals"),
          drop = FALSE
        ]
      )
      advancing <- head(ranked$team, min(2, nrow(ranked)))
      iteration_group_teams <- union(iteration_group_teams, ranked$team)
      iteration_knockout_teams <- union(iteration_knockout_teams, advancing)
    }

    if (length(iteration_group_teams) > 0) {
      stage_counts$group_count[match(iteration_group_teams, stage_counts$team)] <-
        stage_counts$group_count[match(iteration_group_teams, stage_counts$team)] + 1
    }
    if (length(iteration_knockout_teams) > 0) {
      stage_counts$knockout_count[match(iteration_knockout_teams, stage_counts$team)] <-
        stage_counts$knockout_count[match(iteration_knockout_teams, stage_counts$team)] + 1
    }

    if (!is.na(tournament_champion)) {
      stage_counts$champion_count[match(tournament_champion, stage_counts$team)] <-
        stage_counts$champion_count[match(tournament_champion, stage_counts$team)] + 1
    }

    if (iteration == 1) {
      sampled_tournament <- do.call(rbind, sampled_matches)
    }
  }

  stage_probabilities <- stage_counts %>%
    dplyr::mutate(
      group_probability = group_count / n_tournaments,
      knockout_probability = knockout_count / n_tournaments,
      champion_probability = champion_count / n_tournaments
    ) %>%
    dplyr::select(team, group_probability, knockout_probability, champion_probability)

  champion_probabilities <- stage_probabilities %>%
    dplyr::select(team, champion_probability) %>%
    dplyr::arrange(dplyr::desc(champion_probability), team)

  team_expectations <- team_totals %>%
    dplyr::mutate(
      expected_points = points_sum / n_tournaments,
      expected_goals_for = goals_for_sum / n_tournaments,
      expected_goals_against = goals_against_sum / n_tournaments
    ) %>%
    dplyr::select(team, expected_points, expected_goals_for, expected_goals_against)

  list(
    stage_probabilities = stage_probabilities,
    champion_probabilities = champion_probabilities,
    team_expectations = team_expectations,
    match_forecasts = match_forecasts,
    sampled_tournament = sampled_tournament
  )
}
