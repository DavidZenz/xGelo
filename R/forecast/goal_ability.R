#' Hybrid Historical Goal Ability
#'
#' Weighted attack/defense ratings derived from historical international
#' results. All rows are fitted from matches strictly before a cutoff.

#' Return a simple tournament importance weight
#' @keywords internal
tournament_importance_weight <- function(tournament) {
  tournament <- ifelse(is.na(tournament), "", tournament)
  tournament_lower <- tolower(tournament)
  weight <- rep(1, length(tournament_lower))
  weight[grepl("world cup|uefa euro|copa america|african cup|asian cup", tournament_lower)] <- 1.8
  weight[grepl("qualifier|qualification|nations league", tournament_lower)] <- 1.3
  weight[grepl("friendly", tournament_lower)] <- 0.6
  weight
}

#' Compute weighted attack and defense ability as of a cutoff
#'
#' @param matches Match data with canonical teams, scores, date, and tournament
#' @param cutoff_date Only matches before this date are used
#' @param half_life_days Exponential recency half-life
#' @return Data frame with one row per team
#' @export
compute_weighted_goal_ability <- function(
    matches,
    cutoff_date,
    half_life_days = 730
) {
  required_cols <- c("date", "home_team_canonical", "away_team_canonical", "home_score", "away_score")
  missing_cols <- setdiff(required_cols, names(matches))
  if (length(missing_cols) > 0) {
    stop(paste("Matches missing required columns:", paste(missing_cols, collapse = ", ")))
  }

  cutoff_date <- as.Date(cutoff_date)
  matches$date <- as.Date(matches$date)
  prior <- matches[
    !is.na(matches$date) &
      matches$date < cutoff_date &
      !is.na(matches$home_score) &
      !is.na(matches$away_score) &
      !is.na(matches$home_team_canonical) &
      !is.na(matches$away_team_canonical),
    ,
    drop = FALSE
  ]
  if (nrow(prior) == 0) {
    return(data.frame(
      team = character(),
      as_of_date = as.Date(character()),
      feature_source_date = as.Date(character()),
      attack_ability = numeric(),
      defense_ability = numeric(),
      ability_match_count = integer(),
      stringsAsFactors = FALSE
    ))
  }

  age_days <- as.numeric(cutoff_date - prior$date)
  recency_weight <- exp(-log(2) * age_days / half_life_days)
  tournament_weight <- if ("tournament" %in% names(prior)) {
    tournament_importance_weight(prior$tournament)
  } else {
    rep(1, nrow(prior))
  }
  match_weight <- recency_weight * tournament_weight

  long <- rbind(
    data.frame(
      team = prior$home_team_canonical,
      goals_for = prior$home_score,
      goals_against = prior$away_score,
      weight = match_weight,
      stringsAsFactors = FALSE
    ),
    data.frame(
      team = prior$away_team_canonical,
      goals_for = prior$away_score,
      goals_against = prior$home_score,
      weight = match_weight,
      stringsAsFactors = FALSE
    )
  )

  global_for <- stats::weighted.mean(long$goals_for, long$weight, na.rm = TRUE)
  global_against <- stats::weighted.mean(long$goals_against, long$weight, na.rm = TRUE)
  if (!is.finite(global_for) || global_for <= 0) global_for <- 1
  if (!is.finite(global_against) || global_against <= 0) global_against <- 1

  by_team <- split(long, long$team)
  result <- do.call(rbind, lapply(by_team, function(team_rows) {
    weighted_for <- stats::weighted.mean(team_rows$goals_for, team_rows$weight, na.rm = TRUE)
    weighted_against <- stats::weighted.mean(team_rows$goals_against, team_rows$weight, na.rm = TRUE)
    data.frame(
      team = team_rows$team[1],
      as_of_date = cutoff_date,
      feature_source_date = cutoff_date - 1,
      attack_ability = weighted_for / global_for,
      defense_ability = weighted_against / global_against,
      ability_match_count = nrow(team_rows),
      stringsAsFactors = FALSE
    )
  }))
  rownames(result) <- NULL
  result
}

#' Compute ability features for fixtures
#'
#' @param fixtures Fixture/match data
#' @param history_matches Historical matches used for ability fitting
#' @param cutoff_date Optional fixed cutoff for every fixture
#' @return Fixture-level ability differences
#' @export
compute_goal_ability_features <- function(fixtures, history_matches, cutoff_date = NULL) {
  required_cols <- c("date", "home_team_canonical", "away_team_canonical")
  missing_cols <- setdiff(required_cols, names(fixtures))
  if (length(missing_cols) > 0) {
    stop(paste("Fixtures missing required columns:", paste(missing_cols, collapse = ", ")))
  }

  fixtures$date <- as.Date(fixtures$date)
  history_matches$date <- as.Date(history_matches$date)
  if (is.null(cutoff_date)) {
    fixtures$.fixture_order <- seq_len(nrow(fixtures))
    ordered_dates <- sort(unique(fixtures$date))
    history <- history_matches[
      !is.na(history_matches$date) &
        !is.na(history_matches$home_score) &
        !is.na(history_matches$away_score) &
        !is.na(history_matches$home_team_canonical) &
        !is.na(history_matches$away_team_canonical),
      ,
      drop = FALSE
    ]
    history$.date_key <- as.character(history$date)
    history_by_date <- split(history, history$.date_key)
    teams <- sort(unique(c(history$home_team_canonical, history$away_team_canonical, fixtures$home_team_canonical, fixtures$away_team_canonical)))
    weighted_for <- stats::setNames(rep(0, length(teams)), teams)
    weighted_against <- stats::setNames(rep(0, length(teams)), teams)
    weighted_total <- stats::setNames(rep(0, length(teams)), teams)
    match_count <- stats::setNames(rep(0L, length(teams)), teams)
    global_for <- 0
    global_against <- 0
    global_total <- 0
    last_date <- min(c(history$date, fixtures$date), na.rm = TRUE)
    out <- vector("list", nrow(fixtures))

    decay_to <- function(date_value) {
      delta <- as.numeric(as.Date(date_value) - last_date)
      if (is.finite(delta) && delta > 0) {
        decay <- exp(-log(2) * delta / 730)
        weighted_for <<- weighted_for * decay
        weighted_against <<- weighted_against * decay
        weighted_total <<- weighted_total * decay
        global_for <<- global_for * decay
        global_against <<- global_against * decay
        global_total <<- global_total * decay
        last_date <<- as.Date(date_value)
      }
    }

    lookup <- function(team, values, total_values) {
      if (!team %in% names(values) || total_values[[team]] <= 0 || global_total <= 0) return(1)
      team_rate <- values[[team]] / total_values[[team]]
      global_rate <- sum(values, na.rm = TRUE) / sum(total_values, na.rm = TRUE)
      if (!is.finite(global_rate) || global_rate <= 0) return(1)
      value <- team_rate / global_rate
      ifelse(is.finite(value), value, 1)
    }

    for (date_value in ordered_dates) {
      decay_to(date_value)
      fixture_rows <- fixtures[fixtures$date == date_value, , drop = FALSE]
      for (i in seq_len(nrow(fixture_rows))) {
        row_idx <- fixture_rows$.fixture_order[i]
        home_team <- fixture_rows$home_team_canonical[i]
        away_team <- fixture_rows$away_team_canonical[i]
        home_attack <- lookup(home_team, weighted_for, weighted_total)
        away_attack <- lookup(away_team, weighted_for, weighted_total)
        home_defense <- lookup(home_team, weighted_against, weighted_total)
        away_defense <- lookup(away_team, weighted_against, weighted_total)
        out[[row_idx]] <- data.frame(
          home_attack_ability = home_attack,
          away_attack_ability = away_attack,
          home_defense_ability = home_defense,
          away_defense_ability = away_defense,
          attack_ability_diff = home_attack - away_attack,
          defense_ability_diff = home_defense - away_defense,
          goal_ability_source_date = as.Date(date_value) - 1,
          stringsAsFactors = FALSE
        )
      }

      same_day <- history_by_date[[as.character(as.Date(date_value))]]
      if (!is.null(same_day) && nrow(same_day) > 0) {
        weights <- if ("tournament" %in% names(same_day)) tournament_importance_weight(same_day$tournament) else rep(1, nrow(same_day))
        for (j in seq_len(nrow(same_day))) {
          home_team <- same_day$home_team_canonical[j]
          away_team <- same_day$away_team_canonical[j]
          weight <- weights[j]
          weighted_for[[home_team]] <- weighted_for[[home_team]] + same_day$home_score[j] * weight
          weighted_against[[home_team]] <- weighted_against[[home_team]] + same_day$away_score[j] * weight
          weighted_total[[home_team]] <- weighted_total[[home_team]] + weight
          match_count[[home_team]] <- match_count[[home_team]] + 1L
          weighted_for[[away_team]] <- weighted_for[[away_team]] + same_day$away_score[j] * weight
          weighted_against[[away_team]] <- weighted_against[[away_team]] + same_day$home_score[j] * weight
          weighted_total[[away_team]] <- weighted_total[[away_team]] + weight
          match_count[[away_team]] <- match_count[[away_team]] + 1L
          global_for <- global_for + (same_day$home_score[j] + same_day$away_score[j]) * weight
          global_against <- global_against + (same_day$away_score[j] + same_day$home_score[j]) * weight
          global_total <- global_total + 2 * weight
        }
      }
    }
    return(do.call(rbind, out))
  }
  lookup_dates <- if (is.null(cutoff_date)) fixtures$date else rep(as.Date(cutoff_date), nrow(fixtures))
  unique_dates <- sort(unique(lookup_dates))
  ability_by_date <- lapply(unique_dates, function(date_value) {
    compute_weighted_goal_ability(history_matches, cutoff_date = date_value)
  })
  names(ability_by_date) <- as.character(unique_dates)

  lookup_team <- function(ability, team, value_col) {
    rows <- ability[ability$team == team, , drop = FALSE]
    if (nrow(rows) == 0 || !value_col %in% names(rows)) return(1)
    value <- rows[[value_col]][1]
    ifelse(is.finite(value), value, 1)
  }

  rows <- vector("list", nrow(fixtures))
  for (i in seq_len(nrow(fixtures))) {
    ability <- ability_by_date[[as.character(lookup_dates[i])]]
    home_team <- fixtures$home_team_canonical[i]
    away_team <- fixtures$away_team_canonical[i]
    home_attack <- lookup_team(ability, home_team, "attack_ability")
    away_attack <- lookup_team(ability, away_team, "attack_ability")
    home_defense <- lookup_team(ability, home_team, "defense_ability")
    away_defense <- lookup_team(ability, away_team, "defense_ability")

    if (home_attack == 1 && !home_team %in% ability$team) warning(paste("No goal ability for", home_team, "- using neutral fallback"))
    if (away_attack == 1 && !away_team %in% ability$team) warning(paste("No goal ability for", away_team, "- using neutral fallback"))

    rows[[i]] <- data.frame(
      home_attack_ability = home_attack,
      away_attack_ability = away_attack,
      home_defense_ability = home_defense,
      away_defense_ability = away_defense,
      attack_ability_diff = home_attack - away_attack,
      defense_ability_diff = home_defense - away_defense,
      goal_ability_source_date = lookup_dates[i] - 1,
      stringsAsFactors = FALSE
    )
  }
  do.call(rbind, rows)
}
