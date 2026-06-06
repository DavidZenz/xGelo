#' xGelo World Cup Forecast Dashboard
#'
#' Builds a compact static dashboard from xGelo forecast distributions.

#' Load the 2026 World Cup group seed data
#'
#' @param groups_path Path to group seed CSV
#' @return Data frame with group, position, team, display_team, fifa_code
#' @export
load_worldcup_2026_groups <- function(groups_path = "data/raw/worldcup_2026_groups.csv") {
  groups <- read.csv(groups_path, stringsAsFactors = FALSE)
  required_cols <- c("group", "position", "team", "display_team", "fifa_code")
  missing_cols <- setdiff(required_cols, names(groups))
  if (length(missing_cols) > 0) {
    stop(paste("World Cup groups missing required columns:", paste(missing_cols, collapse = ", ")))
  }
  if (nrow(groups) != 48) stop("World Cup group seed must contain exactly 48 teams")
  if (!setequal(unique(groups$group), LETTERS[1:12])) {
    stop("World Cup group seed must contain groups A through L")
  }
  group_sizes <- table(groups$group)
  if (any(group_sizes != 4)) stop("Each World Cup group must contain exactly four teams")
  groups[order(groups$group, groups$position), ]
}

#' Load and validate the official 2026 World Cup group-stage fixture schedule
#'
#' @param groups Group seed data frame
#' @param schedule_path Path to group-stage fixture CSV
#' @return Fixture data frame compatible with xGelo forecasts
#' @export
load_worldcup_2026_group_fixtures <- function(
    groups,
    schedule_path = "data/raw/worldcup_2026_group_fixtures.csv"
) {
  fixtures <- read.csv(schedule_path, stringsAsFactors = FALSE)
  required_cols <- c(
    "match_id",
    "group",
    "matchday",
    "home_team",
    "away_team",
    "date",
    "kickoff_local",
    "venue_name",
    "host_city",
    "host_country"
  )
  missing_cols <- setdiff(required_cols, names(fixtures))
  if (length(missing_cols) > 0) {
    stop(paste("World Cup group fixtures missing required columns:", paste(missing_cols, collapse = ", ")))
  }
  if (nrow(fixtures) != 72) stop("World Cup group fixture schedule must contain exactly 72 matches")
  if (anyDuplicated(fixtures$match_id) > 0) stop("World Cup group fixture match_id values must be unique")
  if (!setequal(unique(fixtures$group), LETTERS[1:12])) {
    stop("World Cup group fixture schedule must contain groups A through L")
  }
  if (any(table(fixtures$group) != 6)) stop("Each World Cup group must contain exactly six fixtures")

  fixtures$date <- as.Date(fixtures$date)
  if (any(is.na(fixtures$date))) stop("World Cup group fixture dates must parse as ISO dates")
  if (min(fixtures$date) != as.Date("2026-06-11") || max(fixtures$date) != as.Date("2026-06-27")) {
    stop("World Cup group fixtures must run from 2026-06-11 through 2026-06-27")
  }
  if (any(!grepl("^[0-2][0-9]:[0-5][0-9]$", fixtures$kickoff_local))) {
    stop("World Cup group fixture kickoff_local values must use HH:MM local time")
  }

  display_lookup <- setNames(groups$display_team, groups$team)
  group_lookup <- setNames(groups$group, groups$team)
  fixture_teams <- unique(c(fixtures$home_team, fixtures$away_team))
  missing_teams <- setdiff(fixture_teams, groups$team)
  if (length(missing_teams) > 0) {
    stop(paste("World Cup group fixtures contain teams absent from group seed:", paste(missing_teams, collapse = ", ")))
  }

  for (group_id in LETTERS[1:12]) {
    group_teams <- groups[groups$group == group_id, ]
    scheduled_teams <- unique(c(
      fixtures$home_team[fixtures$group == group_id],
      fixtures$away_team[fixtures$group == group_id]
    ))
    if (!setequal(group_teams$team, scheduled_teams)) {
      stop(paste("Fixture teams do not match group seed for Group", group_id))
    }
    group_pairs <- apply(
      fixtures[fixtures$group == group_id, c("home_team", "away_team")],
      1,
      function(pair) paste(sort(pair), collapse = " vs ")
    )
    if (length(unique(group_pairs)) != 6) {
      stop(paste("Group", group_id, "must contain each pairing exactly once"))
    }
  }

  fixtures$stage <- "group"
  fixtures$home_display <- unname(display_lookup[fixtures$home_team])
  fixtures$away_display <- unname(display_lookup[fixtures$away_team])
  fixtures$home_group <- unname(group_lookup[fixtures$home_team])
  fixtures$away_group <- unname(group_lookup[fixtures$away_team])
  if (any(fixtures$group != fixtures$home_group | fixtures$group != fixtures$away_group)) {
    stop("World Cup group fixture teams must belong to their listed group")
  }
  fixtures$venue <- "neutral"

  fixtures[, c(
    "match_id",
    "stage",
    "group",
    "matchday",
    "home_team",
    "away_team",
    "home_display",
    "away_display",
    "date",
    "kickoff_local",
    "venue_name",
    "host_city",
    "host_country",
    "venue"
  )]
}

#' Load 72 World Cup group-stage fixtures
#'
#' Compatibility wrapper for existing dashboard code.
#'
#' @param groups Group seed data frame
#' @param schedule_path Path to group-stage fixture CSV
#' @param start_date Deprecated; ignored because fixtures are schedule-backed
#' @return Fixture data frame compatible with xGelo forecasts
#' @export
make_worldcup_group_fixtures <- function(
    groups,
    schedule_path = "data/raw/worldcup_2026_group_fixtures.csv",
    start_date = NULL
) {
  invisible(start_date)
  load_worldcup_2026_group_fixtures(groups = groups, schedule_path = schedule_path)
}

forecast_dashboard_matches <- function(fixtures, n_match_sim = 1000, seed = 20260611, ...) {
  if (!exists("simulate_fixture")) {
    source("R/forecast/monte_carlo.R")
  }
  if (!is.null(seed)) set.seed(seed)
  fixture_seeds <- sample.int(.Machine$integer.max, nrow(fixtures))
  match_rows <- list()
  scoreline_rows <- list()

  for (i in seq_len(nrow(fixtures))) {
    fixture <- fixtures[i, ]
    sim <- simulate_fixture(
      home_team = fixture$home_team,
      away_team = fixture$away_team,
      date = fixture$date,
      venue = fixture$venue,
      n_sim = n_match_sim,
      seed = fixture_seeds[i],
      top_n_scorelines = 5,
      include_scoreline_distribution = TRUE,
      ...
    )
    match_rows[[i]] <- data.frame(
      match_id = fixture$match_id,
      stage = fixture$stage,
      group = fixture$group,
      matchday = fixture$matchday,
      date = as.character(fixture$date),
      home_team = fixture$home_team,
      away_team = fixture$away_team,
      home_display = fixture$home_display,
      away_display = fixture$away_display,
      kickoff_local = fixture$kickoff_local,
      venue_name = fixture$venue_name,
      host_city = fixture$host_city,
      host_country = fixture$host_country,
      home_goals_expected = sim$expected_home,
      away_goals_expected = sim$expected_away,
      win_probability = sim$win_prob,
      draw_probability = sim$draw_prob,
      loss_probability = sim$loss_prob,
      predicted_outcome = sim$predicted_outcome,
      most_likely_score = sim$most_likely_score,
      most_likely_score_probability = sim$most_likely_score_probability,
      rounded_expected_score = sim$rounded_expected_score,
      over_2_5_probability = sim$over_2_5_probability,
      under_2_5_probability = sim$under_2_5_probability,
      both_teams_to_score_probability = sim$both_teams_to_score_probability,
      stringsAsFactors = FALSE
    )
    dist <- sim$scoreline_distribution
    dist$match_id <- fixture$match_id
    dist$rank <- seq_len(nrow(dist))
    scoreline_rows[[i]] <- dist
  }

  list(
    match_forecasts = do.call(rbind, match_rows),
    scoreline_distributions = do.call(rbind, scoreline_rows)
  )
}

simulate_group_stage_dashboard <- function(groups, fixtures, scoreline_distributions, n_tournaments = 1000, seed = 20260612) {
  if (!exists("rank_group_table")) {
    source("R/forecast/tournament.R")
  }
  if (!is.null(seed)) set.seed(seed)
  teams <- groups[, c("group", "position", "team", "display_team", "fifa_code")]
  team_names <- teams$team
  team_index <- match(team_names, team_names)
  counts <- data.frame(
    team = team_names,
    group = teams$group,
    display_team = teams$display_team,
    group_win_count = 0,
    top_two_count = 0,
    third_qual_count = 0,
    round_of_32_count = 0,
    points_sum = 0,
    goals_for_sum = 0,
    goals_against_sum = 0,
    pos1_count = 0,
    pos2_count = 0,
    pos3_count = 0,
    pos4_count = 0,
    stringsAsFactors = FALSE
  )
  dists <- split(scoreline_distributions, scoreline_distributions$match_id)

  for (iteration in seq_len(n_tournaments)) {
    stats <- data.frame(
      team = team_names,
      group = teams$group,
      points = 0,
      goals_for = 0,
      goals_against = 0,
      stringsAsFactors = FALSE
    )

    for (i in seq_len(nrow(fixtures))) {
      fixture <- fixtures[i, ]
      dist <- dists[[fixture$match_id]]
      sampled <- dist[sample(seq_len(nrow(dist)), size = 1, prob = dist$probability), ]
      home_goals <- as.integer(sampled$home_goals)
      away_goals <- as.integer(sampled$away_goals)
      home_points <- if (home_goals > away_goals) 3 else if (home_goals == away_goals) 1 else 0
      away_points <- if (away_goals > home_goals) 3 else if (home_goals == away_goals) 1 else 0
      home_idx <- match(fixture$home_team, stats$team)
      away_idx <- match(fixture$away_team, stats$team)
      stats$points[home_idx] <- stats$points[home_idx] + home_points
      stats$points[away_idx] <- stats$points[away_idx] + away_points
      stats$goals_for[home_idx] <- stats$goals_for[home_idx] + home_goals
      stats$goals_against[home_idx] <- stats$goals_against[home_idx] + away_goals
      stats$goals_for[away_idx] <- stats$goals_for[away_idx] + away_goals
      stats$goals_against[away_idx] <- stats$goals_against[away_idx] + home_goals
    }

    ranked_groups <- list()
    for (group_id in LETTERS[1:12]) {
      table <- stats[stats$group == group_id, ]
      table$goal_difference <- table$goals_for - table$goals_against
      table$tie_breaker <- runif(nrow(table))
      ranked <- rank_group_table(table)
      ranked$finish_position <- seq_len(nrow(ranked))
      ranked_groups[[group_id]] <- ranked

      counts$group_win_count[match(ranked$team[1], counts$team)] <- counts$group_win_count[match(ranked$team[1], counts$team)] + 1
      top_two <- ranked$team[1:2]
      counts$top_two_count[match(top_two, counts$team)] <- counts$top_two_count[match(top_two, counts$team)] + 1
      for (position in 1:4) {
        col <- paste0("pos", position, "_count")
        counts[[col]][match(ranked$team[position], counts$team)] <- counts[[col]][match(ranked$team[position], counts$team)] + 1
      }
    }

    all_ranked <- do.call(rbind, ranked_groups)
    third_place <- all_ranked[all_ranked$finish_position == 3, ]
    third_place <- third_place[order(-third_place$points, -third_place$goal_difference, -third_place$goals_for, third_place$tie_breaker), ]
    best_thirds <- head(third_place$team, 8)
    round_of_32 <- union(all_ranked$team[all_ranked$finish_position <= 2], best_thirds)
    counts$third_qual_count[match(best_thirds, counts$team)] <- counts$third_qual_count[match(best_thirds, counts$team)] + 1
    counts$round_of_32_count[match(round_of_32, counts$team)] <- counts$round_of_32_count[match(round_of_32, counts$team)] + 1
    counts$points_sum[team_index] <- counts$points_sum[team_index] + stats$points
    counts$goals_for_sum[team_index] <- counts$goals_for_sum[team_index] + stats$goals_for
    counts$goals_against_sum[team_index] <- counts$goals_against_sum[team_index] + stats$goals_against
  }

  position_counts <- counts[, c("pos1_count", "pos2_count", "pos3_count", "pos4_count")]
  most_likely_position <- max.col(position_counts, ties.method = "first")
  group_probabilities <- data.frame(
    group = counts$group,
    team = counts$team,
    display_team = counts$display_team,
    group_win_probability = counts$group_win_count / n_tournaments,
    top_two_probability = counts$top_two_count / n_tournaments,
    third_place_qual_probability = counts$third_qual_count / n_tournaments,
    round_of_32_probability = counts$round_of_32_count / n_tournaments,
    most_likely_position = most_likely_position,
    stringsAsFactors = FALSE
  )
  expected_group_tables <- data.frame(
    group = counts$group,
    team = counts$team,
    display_team = counts$display_team,
    expected_points = counts$points_sum / n_tournaments,
    expected_goals_for = counts$goals_for_sum / n_tournaments,
    expected_goals_against = counts$goals_against_sum / n_tournaments,
    expected_goal_difference = (counts$goals_for_sum - counts$goals_against_sum) / n_tournaments,
    most_likely_position = most_likely_position,
    stringsAsFactors = FALSE
  )
  group_probabilities <- group_probabilities[order(group_probabilities$group, -group_probabilities$round_of_32_probability), ]
  expected_group_tables <- expected_group_tables[order(expected_group_tables$group, expected_group_tables$most_likely_position), ]
  list(
    group_probabilities = group_probabilities,
    expected_group_tables = expected_group_tables
  )
}

estimate_stage_probabilities <- function(groups, group_probabilities, elo_current_path = "data/processed/elo_current.csv") {
  elo <- read.csv(elo_current_path, stringsAsFactors = FALSE)
  elo <- elo[, intersect(c("team", "rating"), names(elo))]
  stages <- merge(group_probabilities, elo, by = "team", all.x = TRUE)
  stages$rating[is.na(stages$rating)] <- 1500
  strength <- exp((stages$rating - mean(stages$rating, na.rm = TRUE)) / 400)
  stages$round_of_16_probability <- pmin(stages$round_of_32_probability * (0.25 + 0.75 * strength / max(strength)), 1)
  stages$quarterfinal_probability <- pmin(stages$round_of_16_probability * (0.25 + 0.65 * strength / max(strength)), 1)
  stages$semifinal_probability <- pmin(stages$quarterfinal_probability * (0.20 + 0.60 * strength / max(strength)), 1)
  stages$final_probability <- pmin(stages$semifinal_probability * (0.18 + 0.55 * strength / max(strength)), 1)
  champion_raw <- stages$final_probability * strength
  stages$champion_probability <- if (sum(champion_raw) > 0) champion_raw / sum(champion_raw) else 1 / nrow(stages)
  stages <- merge(stages, groups[, c("team", "display_team", "group", "fifa_code")], by = "team", all.x = TRUE, suffixes = c("", "_seed"))
  data.frame(
    team = stages$team,
    display_team = ifelse(is.na(stages$display_team_seed), stages$display_team, stages$display_team_seed),
    group = ifelse(is.na(stages$group_seed), stages$group, stages$group_seed),
    rating = stages$rating,
    round_of_32_probability = stages$round_of_32_probability,
    round_of_16_probability = stages$round_of_16_probability,
    quarterfinal_probability = stages$quarterfinal_probability,
    semifinal_probability = stages$semifinal_probability,
    final_probability = stages$final_probability,
    champion_probability = stages$champion_probability,
    stringsAsFactors = FALSE
  )
}

stage_probability_column <- function(round) {
  switch(
    round,
    "Round of 32" = "round_of_16_probability",
    "Round of 16" = "quarterfinal_probability",
    "Quarter-finals" = "semifinal_probability",
    "Semi-finals" = "final_probability",
    "Final" = "champion_probability",
    "Champion" = "champion_probability",
    "champion_probability"
  )
}

team_stage_probability <- function(team, stage_probabilities, probability_col) {
  if (is.na(team) || !nzchar(team) || !(probability_col %in% names(stage_probabilities))) {
    return(NA_real_)
  }
  row <- stage_probabilities[stage_probabilities$team == team, ]
  if (nrow(row) == 0) return(NA_real_)
  row[[probability_col]][1]
}

resolve_bracket_slot <- function(slot, group_probabilities, stage_probabilities, projections = list()) {
  winner_match <- regmatches(slot, regexpr("^Winner M[0-9]+$", slot))
  if (length(winner_match) > 0 && nzchar(winner_match)) {
    source_match_id <- sub("^Winner ", "", slot)
    prior <- projections[[source_match_id]]
    if (is.null(prior)) {
      return(list(
        team = NA_character_,
        display_team = slot,
        probability = NA_real_,
        source_match_id = source_match_id
      ))
    }
    return(list(
      team = prior$projected_winner_team,
      display_team = prior$projected_winner,
      probability = prior$projected_winner_stage_probability,
      source_match_id = source_match_id
    ))
  }

  group_letter <- sub(".*Group ([A-L]).*", "\\1", slot)
  if (grepl("^Winner Group [A-L]$", slot)) {
    candidates <- group_probabilities[group_probabilities$group == group_letter, ]
    row <- candidates[which.max(candidates$group_win_probability), ]
    return(list(
      team = row$team,
      display_team = row$display_team,
      probability = row$group_win_probability,
      source_match_id = NA_character_
    ))
  }
  if (grepl("^Runner-up Group [A-L]$", slot)) {
    candidates <- group_probabilities[group_probabilities$group == group_letter, ]
    candidates$runner_up_score <- ifelse(candidates$most_likely_position == 2, 1, 0) + candidates$top_two_probability
    row <- candidates[which.max(candidates$runner_up_score), ]
    return(list(
      team = row$team,
      display_team = row$display_team,
      probability = row$top_two_probability,
      source_match_id = NA_character_
    ))
  }
  if (grepl("^Best 3rd", slot)) {
    allowed <- unlist(strsplit(gsub("[^A-L/]", "", slot), "/"))
    candidates <- group_probabilities[group_probabilities$group %in% allowed, ]
    row <- candidates[which.max(candidates$third_place_qual_probability), ]
    return(list(
      team = row$team,
      display_team = row$display_team,
      probability = row$third_place_qual_probability,
      source_match_id = NA_character_
    ))
  }
  if (slot == "Champion") {
    row <- stage_probabilities[which.max(stage_probabilities$champion_probability), ]
    return(list(
      team = row$team,
      display_team = row$display_team,
      probability = row$champion_probability,
      source_match_id = "M104"
    ))
  }
  list(team = NA_character_, display_team = slot, probability = NA_real_, source_match_id = NA_character_)
}

build_bracket_paths <- function(group_probabilities, stage_probabilities) {
  round32 <- data.frame(
    round = "Round of 32",
    match_id = paste0("M", 73:88),
    slot1_label = c(
      "Winner Group E", "Winner Group I", "Runner-up Group A", "Winner Group F",
      "Winner Group D", "Winner Group G", "Winner Group H", "Runner-up Group K",
      "Winner Group A", "Winner Group C", "Winner Group B", "Winner Group J",
      "Winner Group K", "Winner Group L", "Runner-up Group D", "Runner-up Group F"
    ),
    slot2_label = c(
      "Best 3rd A/B/C/D/F", "Best 3rd C/D/F/G/H", "Runner-up Group B", "Runner-up Group C",
      "Best 3rd B/E/F/I/J", "Best 3rd A/E/H/I/J", "Runner-up Group J", "Runner-up Group L",
      "Best 3rd C/E/F/H/I", "Best 3rd A/B/F/G/K", "Best 3rd E/F/G/I/J", "Runner-up Group H",
      "Best 3rd A/B/D/E/I", "Best 3rd C/D/E/F/H", "Runner-up Group E", "Runner-up Group G"
    ),
    stringsAsFactors = FALSE
  )
  later <- rbind(
    data.frame(round = "Round of 16", match_id = paste0("M", 89:96), slot1_label = paste0("Winner M", 73:80), slot2_label = paste0("Winner M", 81:88)),
    data.frame(round = "Quarter-finals", match_id = paste0("M", 97:100), slot1_label = paste0("Winner M", 89:92), slot2_label = paste0("Winner M", 93:96)),
    data.frame(round = "Semi-finals", match_id = paste0("M", 101:102), slot1_label = paste0("Winner M", 97:98), slot2_label = paste0("Winner M", 99:100)),
    data.frame(round = "Final", match_id = "M104", slot1_label = "Winner M101", slot2_label = "Winner M102"),
    data.frame(round = "Champion", match_id = "Champion", slot1_label = "Champion", slot2_label = "", stringsAsFactors = FALSE)
  )
  paths <- rbind(round32, later)
  paths$slot1_team <- NA_character_
  paths$slot1_display <- NA_character_
  paths$slot1_probability <- NA_real_
  paths$slot1_source_match_id <- NA_character_
  paths$slot2_team <- NA_character_
  paths$slot2_display <- NA_character_
  paths$slot2_probability <- NA_real_
  paths$slot2_source_match_id <- NA_character_
  paths$projected_winner_team <- NA_character_
  paths$projected_winner <- NA_character_
  paths$projected_winner_stage_probability <- NA_real_
  paths$projected_winner_title_probability <- NA_real_
  paths$next_match_id <- NA_character_
  paths$projected_winner_continues <- FALSE

  projections <- list()
  for (i in seq_len(nrow(paths))) {
    slot1 <- resolve_bracket_slot(
      paths$slot1_label[i],
      group_probabilities = group_probabilities,
      stage_probabilities = stage_probabilities,
      projections = projections
    )
    slot2 <- if (nzchar(paths$slot2_label[i])) {
      resolve_bracket_slot(
        paths$slot2_label[i],
        group_probabilities = group_probabilities,
        stage_probabilities = stage_probabilities,
        projections = projections
      )
    } else {
      list(team = NA_character_, display_team = NA_character_, probability = NA_real_, source_match_id = NA_character_)
    }

    probability_col <- stage_probability_column(paths$round[i])
    candidates <- data.frame(
      team = c(slot1$team, slot2$team),
      display_team = c(slot1$display_team, slot2$display_team),
      stage_probability = c(
        team_stage_probability(slot1$team, stage_probabilities, probability_col),
        team_stage_probability(slot2$team, stage_probabilities, probability_col)
      ),
      stringsAsFactors = FALSE
    )
    candidates <- candidates[!is.na(candidates$team) & nzchar(candidates$team), ]
    if (nrow(candidates) == 0 && paths$round[i] == "Champion") {
      champion <- stage_probabilities[which.max(stage_probabilities$champion_probability), ]
      candidates <- data.frame(
        team = champion$team,
        display_team = champion$display_team,
        stage_probability = champion$champion_probability,
        stringsAsFactors = FALSE
      )
    }
    winner <- if (nrow(candidates) > 0) {
      candidates[which.max(candidates$stage_probability), ]
    } else {
      data.frame(team = NA_character_, display_team = NA_character_, stage_probability = NA_real_)
    }

    paths$slot1_team[i] <- slot1$team
    paths$slot1_display[i] <- slot1$display_team
    paths$slot1_probability[i] <- slot1$probability
    paths$slot1_source_match_id[i] <- slot1$source_match_id
    paths$slot2_team[i] <- slot2$team
    paths$slot2_display[i] <- slot2$display_team
    paths$slot2_probability[i] <- slot2$probability
    paths$slot2_source_match_id[i] <- slot2$source_match_id
    paths$projected_winner_team[i] <- winner$team[1]
    paths$projected_winner[i] <- winner$display_team[1]
    paths$projected_winner_stage_probability[i] <- winner$stage_probability[1]
    paths$projected_winner_title_probability[i] <- team_stage_probability(
      winner$team[1],
      stage_probabilities,
      "champion_probability"
    )
    projections[[paths$match_id[i]]] <- as.list(paths[i, ])
  }

  for (i in seq_len(nrow(paths))) {
    next_rows <- which(
      paths$slot1_label == paste("Winner", paths$match_id[i]) |
        paths$slot2_label == paste("Winner", paths$match_id[i])
    )
    if (length(next_rows) > 0) {
      paths$next_match_id[i] <- paths$match_id[next_rows[1]]
    } else if (paths$match_id[i] == "M104") {
      paths$next_match_id[i] <- "Champion"
    }
  }
  for (i in seq_len(nrow(paths))) {
    next_match_id <- paths$next_match_id[i]
    if (is.na(next_match_id) || !nzchar(next_match_id)) next
    next_row <- paths[paths$match_id == next_match_id, ]
    if (nrow(next_row) == 0) next
    paths$projected_winner_continues[i] <- isTRUE(
      !is.na(paths$projected_winner_team[i]) &&
        !is.na(next_row$projected_winner_team[1]) &&
        paths$projected_winner_team[i] == next_row$projected_winner_team[1]
    )
  }

  paths
}

#' Build dashboard-ready World Cup forecast data
#'
#' @export
build_worldcup_dashboard_data <- function(
    groups_path = "data/raw/worldcup_2026_groups.csv",
    schedule_path = "data/raw/worldcup_2026_group_fixtures.csv",
    output_dir = "outputs/dashboard",
    n_match_sim = 1000,
    n_tournaments = 1000,
    seed = 20260611,
    elo_current_path = "data/processed/elo_current.csv",
    ...
) {
  suppressPackageStartupMessages({
    library(jsonlite)
  })
  groups <- load_worldcup_2026_groups(groups_path)
  fixtures <- make_worldcup_group_fixtures(groups, schedule_path = schedule_path)
  match_data <- forecast_dashboard_matches(fixtures, n_match_sim = n_match_sim, seed = seed, ...)
  group_data <- simulate_group_stage_dashboard(
    groups,
    fixtures,
    match_data$scoreline_distributions,
    n_tournaments = n_tournaments,
    seed = seed + 1
  )
  stage_probabilities <- estimate_stage_probabilities(groups, group_data$group_probabilities, elo_current_path = elo_current_path)
  champion_probabilities <- stage_probabilities[order(-stage_probabilities$champion_probability), c("team", "display_team", "group", "champion_probability")]
  bracket_paths <- build_bracket_paths(group_data$group_probabilities, stage_probabilities)
  top_scorelines <- match_data$scoreline_distributions[match_data$scoreline_distributions$rank <= 5, ]
  payload <- list(
    metadata = list(
      title = "xGelo 2026 World Cup Forecast",
      generated_at = as.character(Sys.time()),
      n_match_sim = n_match_sim,
      n_tournaments = n_tournaments,
      format_note = "48 teams, 12 groups of four, top two plus eight best third-place teams reach the Round of 32.",
      fixture_source = "FIFA World Cup 2026 group-stage fixture schedule, cross-checked against FourFourTwo listing updated 2026-06-05.",
      caveat = "Pre-match forecast only. No injuries, lineups, live state, extra-time model, or penalty model."
    ),
    groups = groups,
    fixtures = fixtures,
    match_forecasts = match_data$match_forecasts,
    scoreline_distributions = top_scorelines,
    group_probabilities = group_data$group_probabilities,
    expected_group_tables = group_data$expected_group_tables,
    stage_probabilities = stage_probabilities,
    champion_probabilities = champion_probabilities,
    bracket_paths = bracket_paths
  )

  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)
  json_path <- file.path(output_dir, "worldcup_dashboard_data.json")
  jsonlite::write_json(payload, json_path, pretty = TRUE, auto_unbox = TRUE, digits = 10)
  write.csv(match_data$match_forecasts, file.path(output_dir, "worldcup_match_forecasts.csv"), row.names = FALSE)
  write.csv(group_data$group_probabilities, file.path(output_dir, "worldcup_group_probabilities.csv"), row.names = FALSE)
  write.csv(stage_probabilities, file.path(output_dir, "worldcup_stage_probabilities.csv"), row.names = FALSE)
  write.csv(bracket_paths, file.path(output_dir, "worldcup_bracket_paths.csv"), row.names = FALSE)
  payload$paths <- list(data_json = json_path)
  payload
}

dashboard_html_template <- function(json_text) {
  paste0('<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>xGelo 2026 World Cup Forecast</title>
<link rel="icon" href="data:image/svg+xml,%3Csvg xmlns=%27http://www.w3.org/2000/svg%27 viewBox=%270 0 32 32%27%3E%3Crect width=%2732%27 height=%2732%27 fill=%27%231d1d1f%27/%3E%3Ccircle cx=%2716%27 cy=%2716%27 r=%279%27 fill=%27%23fff%27/%3E%3Cpath d=%27M16 7v18M7 16h18%27 stroke=%27%23c84b42%27 stroke-width=%272%27/%3E%3C/svg%3E">
<style>
:root{--ink:#1d1d1f;--muted:#666;--line:#d8d8d8;--paper:#f7f6f2;--panel:#fff;--red:#c84b42;--blue:#3573a8;--gold:#d29d2b;--green:#3b8754}
*{box-sizing:border-box}body{margin:0;background:var(--paper);color:var(--ink);font-family:Arial,Helvetica,sans-serif;font-size:14px;line-height:1.4}
header{padding:22px 24px 14px;border-bottom:1px solid var(--line);background:#fff}
h1{margin:0;font-family:Georgia,serif;font-size:30px;font-weight:700;line-height:1.05;letter-spacing:0}
.subhead{margin-top:8px;max-width:920px;color:#444}.meta{margin-top:10px;color:var(--muted);font-size:12px}
main{padding:18px 24px 32px}.tabs{display:flex;gap:6px;flex-wrap:wrap;margin-bottom:16px}.tab{border:1px solid var(--line);background:#fff;padding:8px 10px;cursor:pointer;font-weight:700}.tab.active{border-color:var(--ink);background:var(--ink);color:#fff}
.toolbar{display:flex;gap:8px;flex-wrap:wrap;margin:10px 0 18px}.toolbar input,.toolbar select{border:1px solid var(--line);background:#fff;padding:8px;min-width:180px}
.hero{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:10px;margin-bottom:18px}.metric{background:#fff;border-top:3px solid var(--red);padding:12px;min-height:82px}.metric .label{font-size:12px;color:var(--muted);text-transform:uppercase}.metric .value{font-size:24px;font-weight:700;margin-top:4px}.metric .note{font-size:12px;color:var(--muted)}
.section{display:none}.section.active{display:block}.grid-groups{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px}.group-box,.match-card,.team-card,.bracket-game{background:#fff;border:1px solid var(--line);padding:10px}
.group-box h2,.panel-title{font-size:15px;margin:0 0 8px;font-weight:700}table{width:100%;border-collapse:collapse}th,td{padding:5px 4px;border-bottom:1px solid #eee;text-align:left;font-size:12px}th{color:#555;font-weight:700}.num{text-align:right;font-variant-numeric:tabular-nums}
.probbar{height:7px;background:#eee;position:relative;margin-top:3px}.probbar span{display:block;height:100%;background:var(--blue)}
.match-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px}.match-title{font-weight:700;font-size:15px}.match-meta{font-size:12px;color:var(--muted);margin:2px 0 8px}.wdl{display:flex;height:10px;margin:8px 0;background:#eee}.wdl span:nth-child(1){background:var(--blue)}.wdl span:nth-child(2){background:var(--gold)}.wdl span:nth-child(3){background:var(--green)}
.chips{display:flex;gap:6px;flex-wrap:wrap;margin-top:8px}.chip{border:1px solid var(--line);padding:3px 6px;font-size:12px;background:#fafafa}.scorelines{font-size:12px;color:#444;margin-top:8px}.scorelines span{display:inline-block;margin-right:8px}
.bracket-wrap{overflow-x:auto;padding-bottom:18px}.bracket{position:relative;display:grid;grid-template-columns:repeat(6,260px);grid-template-rows:repeat(33,46px);column-gap:96px;min-width:2200px;padding:34px 16px 30px}.bracket-link-svg{position:absolute;inset:0;pointer-events:none;z-index:1}.bracket-link{fill:none;stroke:#c5beb2;stroke-width:2}.bracket-link.projected-path{stroke:var(--blue);stroke-width:3}.bracket-link.champion{stroke:var(--red);stroke-width:4}.bracket-link-label{position:absolute;z-index:4;padding:4px 7px;background:#fff;border:1px solid #c5beb2;font-size:12px;color:#333;white-space:nowrap;box-shadow:0 1px 3px rgba(0,0,0,.12);transform:translateY(8px)}.bracket-link-label.projected-path{border-color:var(--blue);color:#111;font-weight:700}.bracket-link-label.champion{border-color:var(--red);font-weight:700}.bracket-round-title{font-size:13px;font-weight:700;color:#444;align-self:end}.bracket-game{position:relative;z-index:3;min-height:82px;padding:10px;border-left:3px solid #d6d0c6}.bracket-game.projected{border-left-color:var(--blue)}.bracket-game.champion{border-left-color:var(--red);background:#fffdf8}.bracket-id{display:flex;justify-content:space-between;gap:8px;font-size:11px;color:var(--muted);margin-bottom:6px}.bracket-champion{font-weight:700;margin-top:6px}.bracket-prob{font-size:12px;color:#444}.slot{display:flex;justify-content:space-between;gap:8px;padding:4px 0;border-bottom:1px solid #eee}.slot:last-child{border-bottom:0}.slot small{color:var(--muted);white-space:nowrap}.bracket-slot-target{position:relative}.bracket-slot-target::before{content:"";position:absolute;left:-13px;top:50%;width:7px;border-top:2px solid #c8c1b5}
.team-layout{display:grid;grid-template-columns:260px 1fr;gap:14px}.team-list{background:#fff;border:1px solid var(--line);max-height:640px;overflow:auto}.team-row{display:flex;justify-content:space-between;border-bottom:1px solid #eee;padding:8px;cursor:pointer}.team-row.active{background:#f0eee7;font-weight:700}.team-detail{background:#fff;border:1px solid var(--line);padding:12px}
details{background:#fff;border:1px solid var(--line);padding:10px;margin-top:18px}summary{font-weight:700;cursor:pointer}
@media(max-width:980px){.hero{grid-template-columns:repeat(2,minmax(0,1fr))}.grid-groups,.match-grid{grid-template-columns:1fr}.team-layout{grid-template-columns:1fr}.bracket{min-width:2200px}}
@media(max-width:560px){main,header{padding-left:14px;padding-right:14px}.hero{grid-template-columns:1fr}h1{font-size:24px}}
</style>
</head>
<body>
<header><h1>xGelo 2026 World Cup Forecast</h1><div class="subhead">Probabilities are the forecast. Modal scores and predicted outcomes are summaries of the simulated score distribution, not certainty.</div><div class="meta" id="meta"></div></header>
<main>
<div class="hero" id="hero"></div>
<div class="tabs"><button class="tab active" data-tab="groups">Groups</button><button class="tab" data-tab="matches">Matches</button><button class="tab" data-tab="bracket">Bracket</button><button class="tab" data-tab="teams">Teams</button></div>
<section id="groups" class="section active"><div class="grid-groups" id="groupsGrid"></div></section>
<section id="matches" class="section"><div class="toolbar"><input id="matchSearch" placeholder="Search team"><select id="groupFilter"><option value="">All groups</option></select></div><div class="match-grid" id="matchesGrid"></div></section>
<section id="bracket" class="section"><div class="bracket-wrap"><div class="bracket" id="bracketGrid"></div></div></section>
<section id="teams" class="section"><div class="toolbar"><input id="teamSearch" placeholder="Search team"></div><div class="team-layout"><div class="team-list" id="teamList"></div><div class="team-detail" id="teamDetail"></div></div></section>
<details open><summary>Methodology</summary><p>xGelo estimates match goal distributions, simulates scorelines, derives win/draw/loss probabilities, and then samples group outcomes. The most likely score is the modal simulated scoreline. The rounded expected score is only rounded decimal projected goals. Knockout and title probabilities in this dashboard are path estimates for presentation, not a separate extra-time or penalty model.</p></details>
</main>
<script id="dashboard-data" type="application/json">', json_text, '</script>
<script>
const data = JSON.parse(document.getElementById("dashboard-data").textContent);
const pct = v => v == null || Number.isNaN(v) ? "" : (100 * Number(v)).toFixed(1) + "%";
const num = v => Number(v).toFixed(2);
const esc = s => String(s == null ? "" : s).replace(/[&<>"\']/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;","\\"":"&quot;","\'":"&#39;"}[c]));
const by = (rows, key) => rows.reduce((acc, row) => ((acc[row[key]] ||= []).push(row), acc), {});
document.getElementById("meta").textContent = `Generated ${data.metadata.generated_at} | ${data.metadata.n_match_sim} match sims | ${data.metadata.n_tournaments} group-stage sims | ${data.metadata.caveat}`;
function renderHero(){
  const champs = data.champion_probabilities.slice(0,3).map(r => `${r.display_team} ${pct(r.champion_probability)}`).join(" | ");
  const groupRows = data.group_probabilities;
  const topGroup = [...groupRows].sort((a,b)=>b.group_win_probability-a.group_win_probability)[0];
  const uncertain = Object.values(by(groupRows,"group")).map(rows => {
    const sorted = [...rows].sort((a,b)=>b.group_win_probability-a.group_win_probability);
    return {group: rows[0].group, margin: sorted[0].group_win_probability - sorted[1].group_win_probability};
  }).sort((a,b)=>a.margin-b.margin)[0];
  const finalPath = data.bracket_paths.find(r => r.match_id === "M104");
  const finalTeams = finalPath ? `${finalPath.slot1_display} vs ${finalPath.slot2_display}` : data.stage_probabilities.slice().sort((a,b)=>b.final_probability-a.final_probability).slice(0,2).map(r=>r.display_team).join(" vs ");
  document.getElementById("hero").innerHTML = [
    ["Top title chances", champs, "Simulation-derived title view"],
    ["Likely final", finalTeams, "Highest final probabilities"],
    ["Strongest group favorite", `${topGroup.display_team} (${topGroup.group})`, pct(topGroup.group_win_probability)],
    ["Most open group", `Group ${uncertain.group}`, `Leader margin ${pct(uncertain.margin)}`]
  ].map(m => `<div class="metric"><div class="label">${esc(m[0])}</div><div class="value">${esc(m[1])}</div><div class="note">${esc(m[2])}</div></div>`).join("");
}
function renderGroups(){
  const probs = by(data.group_probabilities, "group");
  const exp = by(data.expected_group_tables, "team");
  document.getElementById("groupsGrid").innerHTML = Object.keys(probs).sort().map(g => {
    const rows = probs[g].slice().sort((a,b)=>a.most_likely_position-b.most_likely_position);
    return `<div class="group-box"><h2>Group ${g}</h2><table><thead><tr><th>Team</th><th class="num">Pts</th><th class="num">Qual</th><th class="num">Win</th></tr></thead><tbody>${rows.map(r => {
      const e = exp[r.team][0];
      return `<tr><td>${esc(r.display_team)}<div class="probbar"><span style="width:${100*r.round_of_32_probability}%"></span></div></td><td class="num">${num(e.expected_points)}</td><td class="num">${pct(r.round_of_32_probability)}</td><td class="num">${pct(r.group_win_probability)}</td></tr>`;
    }).join("")}</tbody></table></div>`;
  }).join("");
}
function renderMatches(){
  const search = document.getElementById("matchSearch").value.toLowerCase();
  const group = document.getElementById("groupFilter").value;
  const scorelines = by(data.scoreline_distributions, "match_id");
  const rows = data.match_forecasts.filter(r => (!group || r.group === group) && (`${r.home_display} ${r.away_display}`.toLowerCase().includes(search)));
  document.getElementById("matchesGrid").innerHTML = rows.map(r => {
    const tops = (scorelines[r.match_id] || []).slice(0,5).map(s => `<span>${esc(s.scoreline)} ${pct(s.probability)}</span>`).join("");
    return `<div class="match-card"><div class="match-title">${esc(r.home_display)} vs ${esc(r.away_display)}</div><div class="match-meta">Group ${esc(r.group)} | ${esc(r.date)} ${esc(r.kickoff_local)} local | ${esc(r.venue_name)}, ${esc(r.host_city)}</div><div class="wdl"><span style="width:${100*r.win_probability}%"></span><span style="width:${100*r.draw_probability}%"></span><span style="width:${100*r.loss_probability}%"></span></div><div class="chips"><span class="chip">${esc(r.home_display)} ${pct(r.win_probability)}</span><span class="chip">Draw ${pct(r.draw_probability)}</span><span class="chip">${esc(r.away_display)} ${pct(r.loss_probability)}</span></div><div class="chips"><span class="chip">Projected ${num(r.home_goals_expected)}-${num(r.away_goals_expected)}</span><span class="chip">Most likely ${esc(r.most_likely_score)} (${pct(r.most_likely_score_probability)})</span><span class="chip">Rounded xG ${esc(r.rounded_expected_score)}</span><span class="chip">O2.5 ${pct(r.over_2_5_probability)}</span><span class="chip">BTTS ${pct(r.both_teams_to_score_probability)}</span></div><div class="scorelines">${tops}</div></div>`;
  }).join("");
}
function renderBracket(){
  const order = ["Round of 32","Round of 16","Quarter-finals","Semi-finals","Final","Champion"];
  const col = Object.fromEntries(order.map((round, i) => [round, i + 1]));
  const byId = Object.fromEntries(data.bracket_paths.map(row => [row.match_id, row]));
  const childIds = match => [match.slot1_source_match_id, match.slot2_source_match_id].filter(Boolean);
  const leafOrder = matchId => {
    const match = byId[matchId];
    if (!match) return [];
    const children = childIds(match);
    return children.length ? children.flatMap(leafOrder) : [matchId];
  };
  const leaves = leafOrder("M104");
  const rows = {};
  leaves.forEach((matchId, idx) => rows[matchId] = 2 * idx + 1);
  const placeMatch = matchId => {
    if (rows[matchId] != null) return rows[matchId];
    const match = byId[matchId];
    if (!match) return 1;
    const children = childIds(match);
    if (!children.length) {
      rows[matchId] = 1;
    } else {
      const childRows = children.map(placeMatch);
      rows[matchId] = childRows.reduce((sum, value) => sum + value, 0) / childRows.length;
    }
    return rows[matchId];
  };
  data.bracket_paths.forEach(row => {
    if (row.match_id === "Champion") {
      rows[row.match_id] = placeMatch("M104");
    } else {
      placeMatch(row.match_id);
    }
  });
  const titles = order.map(round => `<div class="bracket-round-title" style="grid-column:${col[round]};grid-row:1;">${esc(round)}</div>`).join("");
  const games = data.bracket_paths.map(g => {
    const isChampion = g.round === "Champion";
    const winnerLabel = isChampion ? "Projected champion" : "Projected winner";
    const slot1Source = g.slot1_source_match_id || "";
    const slot2Source = g.slot2_source_match_id || "";
    const slot1Class = slot1Source ? " slot bracket-slot-target" : " slot";
    const slot2Class = slot2Source ? " slot bracket-slot-target" : " slot";
    const slot2 = g.slot2_label ? `<div class="${slot2Class}" data-source-match-id="${esc(slot2Source)}"><span>${esc(g.slot2_display || g.slot2_label)}</span><small>${pct(g.slot2_probability)}</small></div>` : "";
    const championText = isChampion ? `<div class="bracket-champion">${esc(winnerLabel)}: ${esc(g.projected_winner)}</div><div class="bracket-prob">Title ${pct(g.projected_winner_title_probability)}</div>` : "";
    return `<div class="bracket-game ${isChampion ? "champion" : "projected"}" data-match-id="${esc(g.match_id)}" data-next-match-id="${esc(g.next_match_id || "")}" data-winner-continues="${g.projected_winner_continues ? "true" : "false"}" data-projected-winner="${esc(g.projected_winner || "")}" data-stage-probability="${pct(g.projected_winner_stage_probability)}" data-title-probability="${pct(g.projected_winner_title_probability)}" style="grid-column:${col[g.round]};grid-row:${rows[g.match_id] + 1} / span 2;"><div class="bracket-id"><span>${esc(g.match_id)}</span><span>${esc(g.round)}</span></div>${isChampion ? championText : `<div class="${slot1Class}" data-source-match-id="${esc(slot1Source)}"><span>${esc(g.slot1_display || g.slot1_label)}</span><small>${pct(g.slot1_probability)}</small></div>${slot2}`}</div>`;
  }).join("");
  document.getElementById("bracketGrid").innerHTML = `<svg class="bracket-link-svg" aria-hidden="true"></svg>${titles}${games}`;
  requestAnimationFrame(drawBracketLinks);
}
function drawBracketLinks(){
  const grid = document.getElementById("bracketGrid");
  const svg = grid.querySelector(".bracket-link-svg");
  if (!grid || !svg) return;
  grid.querySelectorAll(".bracket-link-label").forEach(label => label.remove());
  const width = grid.scrollWidth;
  const height = grid.scrollHeight;
  svg.setAttribute("width", width);
  svg.setAttribute("height", height);
  svg.setAttribute("viewBox", `0 0 ${width} ${height}`);
  const paths = [];
  const labels = [];
  grid.querySelectorAll(".bracket-game[data-next-match-id]").forEach(card => {
    const nextId = card.dataset.nextMatchId;
    if (!nextId) return;
    const next = grid.querySelector(`.bracket-game[data-match-id="${CSS.escape(nextId)}"]`);
    if (!next) return;
    const x1 = card.offsetLeft + card.offsetWidth;
    const y1 = card.offsetTop + card.offsetHeight / 2;
    const targetSlot = next.querySelector(`[data-source-match-id="${CSS.escape(card.dataset.matchId)}"]`);
    const x2 = next.offsetLeft;
    const y2 = targetSlot
      ? targetSlot.offsetTop + next.offsetTop + targetSlot.offsetHeight / 2
      : next.offsetTop + next.offsetHeight / 2;
    const mid = x1 + Math.max(18, (x2 - x1) / 2);
    const projectedPath = card.dataset.winnerContinues === "true" ? " projected-path" : "";
    const champion = nextId === "Champion" ? " champion" : "";
    paths.push(`<path class="bracket-link${projectedPath}${champion}" d="M${x1} ${y1} H${mid} V${y2} H${x2}"></path>`);
    const label = document.createElement("div");
    label.className = `bracket-link-label${projectedPath}${champion}`;
    label.style.left = `${x1 + 12}px`;
    label.style.top = `${y1}px`;
    label.textContent = `${card.dataset.projectedWinner} ${card.dataset.stageProbability}`;
    labels.push(label);
  });
  svg.innerHTML = paths.join("");
  labels.forEach(label => grid.appendChild(label));
}
function renderTeams(selected){
  const search = document.getElementById("teamSearch").value.toLowerCase();
  const teams = data.stage_probabilities.slice().sort((a,b)=>b.champion_probability-a.champion_probability).filter(r => r.display_team.toLowerCase().includes(search));
  const current = selected || (teams[0] && teams[0].team);
  document.getElementById("teamList").innerHTML = teams.map(t => `<div class="team-row ${t.team===current?"active":""}" data-team="${esc(t.team)}"><span>${esc(t.display_team)}</span><span>${pct(t.champion_probability)}</span></div>`).join("");
  const team = data.stage_probabilities.find(t => t.team === current) || teams[0];
  if (!team) return;
  const matches = data.match_forecasts.filter(m => m.home_team === team.team || m.away_team === team.team);
  document.getElementById("teamDetail").innerHTML = `<h2>${esc(team.display_team)}</h2><p>Group ${esc(team.group)} | Title ${pct(team.champion_probability)} | Final ${pct(team.final_probability)} | Quarter-final ${pct(team.quarterfinal_probability)} | Round of 32 ${pct(team.round_of_32_probability)}</p><h3 class="panel-title">Group matches</h3>${matches.map(m => `<div class="slot"><span>${esc(m.home_display)} vs ${esc(m.away_display)}<br><small>${esc(m.date)} ${esc(m.kickoff_local)} local | ${esc(m.host_city)}</small></span><small>${esc(m.most_likely_score)}</small></div>`).join("")}`;
  document.querySelectorAll(".team-row").forEach(row => row.onclick = () => renderTeams(row.dataset.team));
}
document.querySelectorAll(".tab").forEach(btn => btn.onclick = () => {
  document.querySelectorAll(".tab").forEach(b=>b.classList.remove("active"));
  document.querySelectorAll(".section").forEach(s=>s.classList.remove("active"));
  btn.classList.add("active"); document.getElementById(btn.dataset.tab).classList.add("active");
  if (btn.dataset.tab === "bracket") requestAnimationFrame(drawBracketLinks);
});
for (const g of "ABCDEFGHIJKL") document.getElementById("groupFilter").innerHTML += `<option value="${g}">Group ${g}</option>`;
document.getElementById("matchSearch").oninput = renderMatches;
document.getElementById("groupFilter").onchange = renderMatches;
document.getElementById("teamSearch").oninput = () => renderTeams();
window.addEventListener("resize", drawBracketLinks);
renderHero(); renderGroups(); renderMatches(); renderBracket(); renderTeams();
</script>
</body>
</html>')
}

#' Render the static World Cup forecast dashboard
#'
#' @export
render_worldcup_dashboard <- function(data_json_path = "outputs/dashboard/worldcup_dashboard_data.json", output_path = "outputs/dashboard/worldcup_forecast.html") {
  json_text <- paste(readLines(data_json_path, warn = FALSE), collapse = "\n")
  html <- dashboard_html_template(json_text)
  if (!dir.exists(dirname(output_path))) dir.create(dirname(output_path), recursive = TRUE)
  writeLines(html, output_path)
  output_path
}

#' Build data and render the World Cup dashboard
#'
#' @export
build_worldcup_dashboard <- function(
    groups_path = "data/raw/worldcup_2026_groups.csv",
    schedule_path = "data/raw/worldcup_2026_group_fixtures.csv",
    output_dir = "outputs/dashboard",
    n_match_sim = 1000,
    n_tournaments = 1000,
    seed = 20260611,
    elo_current_path = "data/processed/elo_current.csv",
    ...
) {
  payload <- build_worldcup_dashboard_data(
    groups_path = groups_path,
    schedule_path = schedule_path,
    output_dir = output_dir,
    n_match_sim = n_match_sim,
    n_tournaments = n_tournaments,
    seed = seed,
    elo_current_path = elo_current_path,
    ...
  )
  output_path <- render_worldcup_dashboard(
    data_json_path = payload$paths$data_json,
    output_path = file.path(output_dir, "worldcup_forecast.html")
  )
  payload$paths$html <- output_path
  payload
}
