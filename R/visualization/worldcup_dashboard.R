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

dashboard_model_predictors <- function(model) {
  predictors <- attr(model, "xgelo_predictors")
  if (is.null(predictors) || length(predictors) == 0) {
    predictors <- tryCatch(attr(stats::terms(model), "term.labels"), error = function(e) character())
  }
  if (length(predictors) == 0) predictors <- "elo_diff"
  predictors
}

dashboard_reverse_feature_frame <- function(data) {
  reversed <- data
  diff_cols <- grep("(^elo_diff$|_diff$)", names(reversed), value = TRUE)
  for (col in diff_cols) reversed[[col]] <- -reversed[[col]]
  reversed
}

dashboard_model_uses_home_perspective <- function(model) {
  identical(attr(model, "xgelo_feature_perspective"), "home")
}

dashboard_get_negative_binomial_theta <- function(model) {
  if (!is.list(model)) return(1)
  theta <- model$theta
  if (!is.null(theta) && is.numeric(theta) && length(theta) == 1 && is.finite(theta) && theta > 0) {
    return(theta)
  }
  1
}

precompute_dashboard_fixture_lambdas <- function(fixtures, home_model, away_model, forecast_features) {
  if (!is.data.frame(forecast_features) || nrow(forecast_features) == 0 || !all(c("date", "home_team", "away_team") %in% names(forecast_features))) {
    return(NULL)
  }
  if (inherits(home_model, "constant_goal_model") || inherits(away_model, "constant_goal_model")) {
    return(NULL)
  }
  normalise_team <- if (exists("feature_team_match_key")) feature_team_match_key else if (exists("canonicalise_feature_team_name")) canonicalise_feature_team_name else identity
  forecast_features$date <- as.Date(forecast_features$date)
  feature_keys <- paste(
    as.character(forecast_features$date),
    normalise_team(forecast_features$home_team),
    normalise_team(forecast_features$away_team),
    sep = "\r"
  )
  feature_index <- split(seq_len(nrow(forecast_features)), feature_keys)
  fixture_keys <- paste(
    as.character(as.Date(fixtures$date)),
    normalise_team(fixtures$home_team),
    normalise_team(fixtures$away_team),
    sep = "\r"
  )
  match_idx <- vapply(fixture_keys, function(key) {
    idx <- feature_index[[key]]
    if (length(idx) == 0) NA_integer_ else idx[1]
  }, integer(1))
  if (any(is.na(match_idx))) return(NULL)

  features <- forecast_features[match_idx, , drop = FALSE]
  predictors <- unique(c(dashboard_model_predictors(home_model), dashboard_model_predictors(away_model)))
  for (predictor in predictors) {
    if (!predictor %in% names(features)) features[[predictor]] <- 0
  }
  newdata <- features[, predictors, drop = FALSE]
  for (predictor in predictors) {
    newdata[[predictor]] <- suppressWarnings(as.numeric(newdata[[predictor]]))
    newdata[[predictor]][!is.finite(newdata[[predictor]])] <- 0
  }
  reversed <- dashboard_reverse_feature_frame(newdata)
  neutral <- fixtures$venue == "neutral"
  home_lambda <- numeric(nrow(fixtures))
  away_lambda <- numeric(nrow(fixtures))
  if (all(neutral) && (dashboard_model_uses_home_perspective(home_model) || dashboard_model_uses_home_perspective(away_model))) {
    home_lambda <- rowMeans(cbind(
      as.numeric(predict(home_model, newdata = newdata, type = "response")),
      as.numeric(predict(away_model, newdata = reversed, type = "response"))
    ))
    away_lambda <- rowMeans(cbind(
      as.numeric(predict(home_model, newdata = reversed, type = "response")),
      as.numeric(predict(away_model, newdata = newdata, type = "response"))
    ))
  } else {
    home_lambda <- as.numeric(predict(home_model, newdata = newdata, type = "response"))
    away_lambda <- as.numeric(predict(away_model, newdata = reversed, type = "response"))
  }
  data.frame(
    match_id = fixtures$match_id,
    home_lambda = pmax(home_lambda, 1e-6),
    away_lambda = pmax(away_lambda, 1e-6),
    stringsAsFactors = FALSE
  )
}

simulate_fixture_from_lambdas <- function(
    home_lambda,
    away_lambda,
    home_theta,
    away_theta,
    n_sim = 1000,
    top_n_scorelines = 5,
    max_goals = 10
) {
  goals <- 0:max_goals
  home_probs <- stats::dnbinom(goals, size = home_theta, mu = home_lambda)
  away_probs <- stats::dnbinom(goals, size = away_theta, mu = away_lambda)
  grid <- outer(home_probs, away_probs)
  grid <- grid / sum(grid)
  scorelines <- expand.grid(home_goals = goals, away_goals = goals, KEEP.OUT.ATTRS = FALSE)
  scorelines$probability <- as.vector(grid)
  scorelines$count <- scorelines$probability * n_sim
  scorelines$scoreline <- paste(scorelines$home_goals, scorelines$away_goals, sep = "-")
  scorelines$outcome <- ifelse(scorelines$home_goals > scorelines$away_goals, "home_win",
                               ifelse(scorelines$home_goals == scorelines$away_goals, "draw", "away_win"))
  scorelines$total_goals <- scorelines$home_goals + scorelines$away_goals
  scorelines <- scorelines[order(-scorelines$probability, scorelines$total_goals, scorelines$home_goals, scorelines$away_goals), ]
  home_marginal <- rowSums(grid)
  away_marginal <- colSums(grid)
  win_prob <- sum(grid[row(grid) > col(grid)])
  draw_prob <- sum(diag(grid))
  loss_prob <- sum(grid[row(grid) < col(grid)])
  top_scorelines <- head(scorelines, top_n_scorelines)
  list(
    win_prob = win_prob,
    draw_prob = draw_prob,
    loss_prob = loss_prob,
    expected_home = sum(goals * home_marginal),
    expected_away = sum(goals * away_marginal),
    home_lambda = home_lambda,
    away_lambda = away_lambda,
    total_prob = win_prob + draw_prob + loss_prob,
    predicted_outcome = names(which.max(c(home_win = win_prob, draw = draw_prob, away_win = loss_prob))),
    most_likely_score = top_scorelines$scoreline[1],
    most_likely_home_goals = top_scorelines$home_goals[1],
    most_likely_away_goals = top_scorelines$away_goals[1],
    most_likely_score_probability = top_scorelines$probability[1],
    rounded_expected_score = paste(round(sum(goals * home_marginal)), round(sum(goals * away_marginal)), sep = "-"),
    over_2_5_probability = sum(scorelines$probability[scorelines$total_goals > 2.5]),
    under_2_5_probability = sum(scorelines$probability[scorelines$total_goals <= 2.5]),
    both_teams_to_score_probability = sum(scorelines$probability[scorelines$home_goals > 0 & scorelines$away_goals > 0]),
    scoreline_distribution = scorelines[, c("home_goals", "away_goals", "scoreline", "outcome", "count", "probability")],
    n_sim = n_sim
  )
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

worldcup_result_key <- function(date, home_team, away_team) {
  paste(as.character(as.Date(date)), as.character(home_team), as.character(away_team), sep = "\r")
}

#' Attach completed World Cup scores to scheduled group fixtures
#'
#' @param fixtures Fixture data frame from make_worldcup_group_fixtures()
#' @param matches_path Processed martj42/Elo matches path
#' @param result_cutoff_date Latest result date to include
#' @return Fixture data frame with actual score/status columns
#' @export
attach_worldcup_actual_results <- function(
    fixtures,
    matches_path = "data/processed/elo_matches.csv",
    result_cutoff_date = Sys.Date()
) {
  fixtures$date <- as.Date(fixtures$date)
  fixtures$is_completed <- FALSE
  fixtures$match_status <- "scheduled"
  fixtures$actual_home_goals <- NA_integer_
  fixtures$actual_away_goals <- NA_integer_
  fixtures$actual_score <- NA_character_

  if (!file.exists(matches_path)) return(fixtures)
  matches <- read.csv(matches_path, stringsAsFactors = FALSE)
  required <- c("date", "home_team_canonical", "away_team_canonical", "home_score", "away_score", "tournament")
  if (!all(required %in% names(matches))) return(fixtures)
  matches$date <- as.Date(matches$date)
  result_cutoff_date <- as.Date(result_cutoff_date)
  completed <- matches[
    matches$tournament == "FIFA World Cup" &
      !is.na(matches$home_score) &
      !is.na(matches$away_score) &
      matches$date <= result_cutoff_date,
    ,
    drop = FALSE
  ]
  if (nrow(completed) == 0) return(fixtures)

  result_keys <- worldcup_result_key(
    completed$date,
    completed$home_team_canonical,
    completed$away_team_canonical
  )
  result_index <- split(seq_len(nrow(completed)), result_keys)
  fixture_keys <- worldcup_result_key(fixtures$date, fixtures$home_team, fixtures$away_team)
  for (i in seq_along(fixture_keys)) {
    idx <- result_index[[fixture_keys[i]]]
    if (length(idx) == 0) next
    row <- completed[idx[length(idx)], , drop = FALSE]
    fixtures$is_completed[i] <- TRUE
    fixtures$match_status[i] <- "final"
    fixtures$actual_home_goals[i] <- as.integer(row$home_score[1])
    fixtures$actual_away_goals[i] <- as.integer(row$away_score[1])
    fixtures$actual_score[i] <- paste(fixtures$actual_home_goals[i], fixtures$actual_away_goals[i], sep = "-")
  }
  fixtures
}

forecast_dashboard_matches <- function(fixtures, n_match_sim = 1000, seed = 20260611, ...) {
  if (!exists("simulate_fixture")) {
    source("R/forecast/monte_carlo.R")
  }
  if (!is.null(seed)) set.seed(seed)
  extra_args <- list(...)
  get_extra_arg <- function(name) extra_args[[name, exact = TRUE]]
  if (is.null(get_extra_arg("home_model"))) {
    home_model_path <- if (!is.null(get_extra_arg("home_model_path"))) get_extra_arg("home_model_path") else "models/home_goal_model.rds"
    if (file.exists(home_model_path)) extra_args$home_model <- readRDS(home_model_path)
  }
  if (is.null(get_extra_arg("away_model"))) {
    away_model_path <- if (!is.null(get_extra_arg("away_model_path"))) get_extra_arg("away_model_path") else "models/away_goal_model.rds"
    if (file.exists(away_model_path)) extra_args$away_model <- readRDS(away_model_path)
  }
  if (is.null(get_extra_arg("elo_ratings"))) {
    elo_ratings_path <- if (!is.null(get_extra_arg("elo_ratings_path"))) get_extra_arg("elo_ratings_path") else "data/processed/elo_ratings.csv"
    if (file.exists(elo_ratings_path)) extra_args$elo_ratings <- read.csv(elo_ratings_path, stringsAsFactors = FALSE)
  }
  completed <- if ("is_completed" %in% names(fixtures)) {
    isTRUE(fixtures$is_completed) | fixtures$is_completed %in% c(TRUE, "TRUE", "true", "1")
  } else {
    rep(FALSE, nrow(fixtures))
  }
  open_fixtures <- fixtures[!completed, , drop = FALSE]
  fixture_lambdas <- if (
    nrow(open_fixtures) > 0 &&
      !is.null(get_extra_arg("home_model")) &&
      !is.null(get_extra_arg("away_model")) &&
      !is.null(get_extra_arg("forecast_features"))
  ) {
    precompute_dashboard_fixture_lambdas(
      fixtures = open_fixtures,
      home_model = get_extra_arg("home_model"),
      away_model = get_extra_arg("away_model"),
      forecast_features = get_extra_arg("forecast_features")
    )
  } else {
    NULL
  }
  home_theta <- if (!is.null(get_extra_arg("home_model"))) dashboard_get_negative_binomial_theta(get_extra_arg("home_model")) else NULL
  away_theta <- if (!is.null(get_extra_arg("away_model"))) dashboard_get_negative_binomial_theta(get_extra_arg("away_model")) else NULL
  fixture_seeds <- sample.int(.Machine$integer.max, nrow(fixtures))
  match_rows <- list()
  scoreline_rows <- list()

  for (i in seq_len(nrow(fixtures))) {
    fixture <- fixtures[i, ]
    fixture_completed <- isTRUE(completed[i])
    if (fixture_completed) {
      home_goals <- as.integer(fixture$actual_home_goals)
      away_goals <- as.integer(fixture$actual_away_goals)
      outcome <- if (home_goals > away_goals) "home_win" else if (home_goals == away_goals) "draw" else "away_win"
      sim <- list(
        win_prob = as.numeric(outcome == "home_win"),
        draw_prob = as.numeric(outcome == "draw"),
        loss_prob = as.numeric(outcome == "away_win"),
        expected_home = home_goals,
        expected_away = away_goals,
        predicted_outcome = outcome,
        most_likely_score = paste(home_goals, away_goals, sep = "-"),
        most_likely_score_probability = 1,
        rounded_expected_score = paste(home_goals, away_goals, sep = "-"),
        over_2_5_probability = as.numeric(home_goals + away_goals > 2.5),
        under_2_5_probability = as.numeric(home_goals + away_goals <= 2.5),
        both_teams_to_score_probability = as.numeric(home_goals > 0 && away_goals > 0),
        scoreline_distribution = data.frame(
          home_goals = home_goals,
          away_goals = away_goals,
          scoreline = paste(home_goals, away_goals, sep = "-"),
          outcome = outcome,
          count = n_match_sim,
          probability = 1,
          stringsAsFactors = FALSE
        )
      )
    } else if (!is.null(fixture_lambdas)) {
      lambda_row <- fixture_lambdas[fixture_lambdas$match_id == fixture$match_id, , drop = FALSE]
      if (nrow(lambda_row) == 0) {
        stop(paste("Missing forecast feature/lambda row for open fixture:", fixture$match_id), call. = FALSE)
      }
      sim <- simulate_fixture_from_lambdas(
        home_lambda = lambda_row$home_lambda[1],
        away_lambda = lambda_row$away_lambda[1],
        home_theta = home_theta,
        away_theta = away_theta,
        n_sim = n_match_sim,
        top_n_scorelines = 5
      )
    } else {
      sim <- do.call(
        simulate_fixture,
        c(
          list(
            home_team = fixture$home_team,
            away_team = fixture$away_team,
            date = fixture$date,
            venue = fixture$venue,
            n_sim = n_match_sim,
            seed = fixture_seeds[i],
            top_n_scorelines = 5,
            include_scoreline_distribution = TRUE
          ),
          extra_args
        )
      )
    }
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
      is_completed = fixture_completed,
      match_status = if ("match_status" %in% names(fixture)) fixture$match_status else if (fixture_completed) "final" else "scheduled",
      actual_home_goals = if ("actual_home_goals" %in% names(fixture)) fixture$actual_home_goals else NA_integer_,
      actual_away_goals = if ("actual_away_goals" %in% names(fixture)) fixture$actual_away_goals else NA_integer_,
      actual_score = if ("actual_score" %in% names(fixture)) fixture$actual_score else NA_character_,
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

dashboard_prematch_forecast_map <- function() {
  c(
    prematch_home_goals_expected = "home_goals_expected",
    prematch_away_goals_expected = "away_goals_expected",
    prematch_win_probability = "win_probability",
    prematch_draw_probability = "draw_probability",
    prematch_loss_probability = "loss_probability",
    prematch_predicted_outcome = "predicted_outcome",
    prematch_most_likely_score = "most_likely_score",
    prematch_most_likely_score_probability = "most_likely_score_probability",
    prematch_rounded_expected_score = "rounded_expected_score",
    prematch_over_2_5_probability = "over_2_5_probability",
    prematch_under_2_5_probability = "under_2_5_probability",
    prematch_both_teams_to_score_probability = "both_teams_to_score_probability"
  )
}

read_dashboard_prematch_forecast_archive <- function(path) {
  if (is.null(path) || !nzchar(path) || !file.exists(path)) {
    return(data.frame())
  }
  archive <- read.csv(path, stringsAsFactors = FALSE)
  if (!"match_id" %in% names(archive)) {
    return(data.frame())
  }
  archive <- archive[!is.na(archive$match_id) & nzchar(archive$match_id), , drop = FALSE]
  archive[!duplicated(archive$match_id, fromLast = TRUE), , drop = FALSE]
}

make_dashboard_prematch_forecast_rows <- function(
    match_forecasts,
    generated_at,
    feature_cutoff_date,
    actual_results_cutoff_date
) {
  completed <- if ("is_completed" %in% names(match_forecasts)) {
    match_forecasts$is_completed %in% c(TRUE, "TRUE", "true", "1")
  } else {
    rep(FALSE, nrow(match_forecasts))
  }
  final_status <- if ("match_status" %in% names(match_forecasts)) {
    match_forecasts$match_status == "final"
  } else {
    rep(FALSE, nrow(match_forecasts))
  }
  open <- !(completed | final_status)
  rows <- match_forecasts[open, , drop = FALSE]
  if (!nrow(rows)) {
    return(data.frame())
  }

  map <- dashboard_prematch_forecast_map()
  out <- rows[, intersect(
    c("match_id", "date", "group", "home_team", "away_team", "home_display", "away_display"),
    names(rows)
  ), drop = FALSE]
  for (target in names(map)) {
    source <- unname(map[[target]])
    out[[target]] <- if (source %in% names(rows)) rows[[source]] else NA
  }
  out$prematch_generated_at <- as.character(generated_at)
  out$prematch_feature_cutoff_date <- as.character(feature_cutoff_date)
  out$prematch_actual_results_cutoff_date <- as.character(actual_results_cutoff_date)
  out$prematch_forecast_source <- "dashboard_archive"
  out
}

update_dashboard_prematch_forecast_archive <- function(
    match_forecasts,
    path,
    generated_at,
    feature_cutoff_date,
    actual_results_cutoff_date
) {
  archive <- read_dashboard_prematch_forecast_archive(path)
  latest_open <- make_dashboard_prematch_forecast_rows(
    match_forecasts = match_forecasts,
    generated_at = generated_at,
    feature_cutoff_date = feature_cutoff_date,
    actual_results_cutoff_date = actual_results_cutoff_date
  )
  if (!nrow(latest_open)) {
    return(archive)
  }

  if (nrow(archive)) {
    missing_cols <- setdiff(names(latest_open), names(archive))
    for (col in missing_cols) archive[[col]] <- NA
    missing_cols <- setdiff(names(archive), names(latest_open))
    for (col in missing_cols) latest_open[[col]] <- NA
    archive <- archive[!archive$match_id %in% latest_open$match_id, names(latest_open), drop = FALSE]
  } else {
    archive <- latest_open[0, , drop = FALSE]
  }

  combined <- rbind(archive[, names(latest_open), drop = FALSE], latest_open)
  combined[!duplicated(combined$match_id, fromLast = TRUE), , drop = FALSE]
}

attach_dashboard_prematch_forecasts <- function(match_forecasts, prematch_archive) {
  map <- dashboard_prematch_forecast_map()
  prematch_cols <- c(
    names(map),
    "prematch_generated_at",
    "prematch_feature_cutoff_date",
    "prematch_actual_results_cutoff_date",
    "prematch_forecast_source"
  )
  for (col in prematch_cols) {
    if (!col %in% names(match_forecasts)) {
      match_forecasts[[col]] <- NA
    }
  }
  match_forecasts$prematch_forecast_available <- FALSE

  if (is.null(prematch_archive) || !nrow(prematch_archive) || !"match_id" %in% names(prematch_archive)) {
    return(match_forecasts)
  }

  idx <- match(match_forecasts$match_id, prematch_archive$match_id)
  has_archive <- !is.na(idx)
  for (col in prematch_cols) {
    if (col %in% names(prematch_archive)) {
      match_forecasts[[col]][has_archive] <- prematch_archive[[col]][idx[has_archive]]
    }
  }
  match_forecasts$prematch_forecast_available[has_archive] <- !is.na(match_forecasts$prematch_win_probability[has_archive])
  match_forecasts
}

dashboard_bracket_prematch_forecast_map <- function() {
  c(
    prematch_slot1_probability = "slot1_probability",
    prematch_slot1_advancement_probability = "slot1_advancement_probability",
    prematch_slot1_regulation_win_probability = "slot1_regulation_win_probability",
    prematch_slot1_extra_time_penalty_probability = "slot1_extra_time_penalty_probability",
    prematch_slot1_tiebreak_probability = "slot1_tiebreak_probability",
    prematch_slot2_probability = "slot2_probability",
    prematch_slot2_advancement_probability = "slot2_advancement_probability",
    prematch_slot2_regulation_win_probability = "slot2_regulation_win_probability",
    prematch_slot2_extra_time_penalty_probability = "slot2_extra_time_penalty_probability",
    prematch_slot2_tiebreak_probability = "slot2_tiebreak_probability",
    prematch_draw_after_regulation_probability = "draw_after_regulation_probability",
    prematch_projected_winner_team = "projected_winner_team",
    prematch_projected_winner = "projected_winner",
    prematch_projected_winner_match_probability = "projected_winner_match_probability",
    prematch_projected_winner_regulation_probability = "projected_winner_regulation_probability",
    prematch_projected_winner_extra_time_penalty_probability = "projected_winner_extra_time_penalty_probability",
    prematch_projected_winner_tiebreak_probability = "projected_winner_tiebreak_probability",
    prematch_projected_winner_route_label = "projected_winner_route_label",
    prematch_slot1_expected_goals = "slot1_expected_goals",
    prematch_slot2_expected_goals = "slot2_expected_goals",
    prematch_most_likely_score = "most_likely_score",
    prematch_most_likely_score_probability = "most_likely_score_probability",
    prematch_rounded_expected_score = "rounded_expected_score",
    prematch_over_2_5_probability = "over_2_5_probability",
    prematch_both_teams_to_score_probability = "both_teams_to_score_probability",
    prematch_top_scorelines_label = "top_scorelines_label"
  )
}

read_dashboard_bracket_prematch_forecast_archive <- function(path) {
  if (is.null(path) || !nzchar(path) || !file.exists(path)) {
    return(data.frame())
  }
  archive <- read.csv(path, stringsAsFactors = FALSE)
  if (!"match_id" %in% names(archive)) {
    return(data.frame())
  }
  archive <- archive[!is.na(archive$match_id) & nzchar(archive$match_id), , drop = FALSE]
  archive[!duplicated(archive$match_id, fromLast = TRUE), , drop = FALSE]
}

make_dashboard_bracket_prematch_forecast_rows <- function(
    bracket_paths,
    generated_at,
    feature_cutoff_date,
    actual_results_cutoff_date
) {
  completed <- if ("is_completed" %in% names(bracket_paths)) {
    bracket_paths$is_completed %in% c(TRUE, "TRUE", "true", "1")
  } else {
    rep(FALSE, nrow(bracket_paths))
  }
  final_status <- if ("match_status" %in% names(bracket_paths)) {
    bracket_paths$match_status == "final"
  } else {
    rep(FALSE, nrow(bracket_paths))
  }
  open <- !(completed | final_status)
  rows <- bracket_paths[open, , drop = FALSE]
  if (!nrow(rows)) {
    return(data.frame())
  }

  map <- dashboard_bracket_prematch_forecast_map()
  out <- rows[, intersect(
    c(
      "match_id", "round", "slot1_label", "slot1_team", "slot1_display",
      "slot1_source_match_id", "slot2_label", "slot2_team", "slot2_display",
      "slot2_source_match_id"
    ),
    names(rows)
  ), drop = FALSE]
  for (target in names(map)) {
    source <- unname(map[[target]])
    out[[target]] <- if (source %in% names(rows)) rows[[source]] else NA
  }
  out$prematch_generated_at <- as.character(generated_at)
  out$prematch_feature_cutoff_date <- as.character(feature_cutoff_date)
  out$prematch_actual_results_cutoff_date <- as.character(actual_results_cutoff_date)
  out$prematch_forecast_source <- "dashboard_bracket_archive"
  out
}

update_dashboard_bracket_prematch_forecast_archive <- function(
    bracket_paths,
    path,
    generated_at,
    feature_cutoff_date,
    actual_results_cutoff_date
) {
  archive <- read_dashboard_bracket_prematch_forecast_archive(path)
  latest_open <- make_dashboard_bracket_prematch_forecast_rows(
    bracket_paths = bracket_paths,
    generated_at = generated_at,
    feature_cutoff_date = feature_cutoff_date,
    actual_results_cutoff_date = actual_results_cutoff_date
  )
  if (!nrow(latest_open)) {
    return(archive)
  }

  if (nrow(archive)) {
    missing_cols <- setdiff(names(latest_open), names(archive))
    for (col in missing_cols) archive[[col]] <- NA
    missing_cols <- setdiff(names(archive), names(latest_open))
    for (col in missing_cols) latest_open[[col]] <- NA
    archive <- archive[!archive$match_id %in% latest_open$match_id, names(latest_open), drop = FALSE]
  } else {
    archive <- latest_open[0, , drop = FALSE]
  }

  combined <- rbind(archive[, names(latest_open), drop = FALSE], latest_open)
  combined[!duplicated(combined$match_id, fromLast = TRUE), , drop = FALSE]
}

attach_dashboard_bracket_prematch_forecasts <- function(bracket_paths, prematch_archive) {
  map <- dashboard_bracket_prematch_forecast_map()
  prematch_cols <- c(
    names(map),
    "prematch_generated_at",
    "prematch_feature_cutoff_date",
    "prematch_actual_results_cutoff_date",
    "prematch_forecast_source"
  )
  for (col in prematch_cols) {
    if (!col %in% names(bracket_paths)) {
      bracket_paths[[col]] <- NA
    }
  }
  bracket_paths$prematch_forecast_available <- FALSE

  if (is.null(prematch_archive) || !nrow(prematch_archive) || !"match_id" %in% names(prematch_archive)) {
    return(bracket_paths)
  }

  idx <- match(bracket_paths$match_id, prematch_archive$match_id)
  has_archive <- !is.na(idx)
  for (col in prematch_cols) {
    if (col %in% names(prematch_archive)) {
      bracket_paths[[col]][has_archive] <- prematch_archive[[col]][idx[has_archive]]
    }
  }
  bracket_paths$prematch_forecast_available[has_archive] <-
    !is.na(bracket_paths$prematch_projected_winner_match_probability[has_archive])
  bracket_paths
}

worldcup_bracket_template <- function(include_champion = TRUE) {
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
    stringsAsFactors = FALSE
  )
  bracket <- rbind(round32, later)
  if (include_champion) {
    bracket <- rbind(
      bracket,
      data.frame(round = "Champion", match_id = "Champion", slot1_label = "Winner M104", slot2_label = "", stringsAsFactors = FALSE)
    )
  }
  bracket
}

resolve_simulated_bracket_slot <- function(slot, ranked_groups, remaining_thirds, match_winners) {
  winner_match <- regmatches(slot, regexpr("^Winner M[0-9]+$", slot))
  if (length(winner_match) > 0 && nzchar(winner_match)) {
    source_match_id <- sub("^Winner ", "", slot)
    return(list(team = match_winners[[source_match_id]], remaining_thirds = remaining_thirds))
  }

  group_letter <- sub(".*Group ([A-L]).*", "\\1", slot)
  if (grepl("^Winner Group [A-L]$", slot)) {
    return(list(team = ranked_groups[[group_letter]]$team[1], remaining_thirds = remaining_thirds))
  }
  if (grepl("^Runner-up Group [A-L]$", slot)) {
    return(list(team = ranked_groups[[group_letter]]$team[2], remaining_thirds = remaining_thirds))
  }
  if (grepl("^Best 3rd", slot)) {
    allowed <- unlist(strsplit(gsub("[^A-L/]", "", slot), "/"))
    candidate_idx <- which(remaining_thirds$group %in% allowed)
    chosen_idx <- if (length(candidate_idx) > 0) candidate_idx[1] else 1
    team <- remaining_thirds$team[chosen_idx]
    remaining_thirds <- remaining_thirds[-chosen_idx, , drop = FALSE]
    return(list(team = team, remaining_thirds = remaining_thirds))
  }

  list(team = NA_character_, remaining_thirds = remaining_thirds)
}

knockout_advancement_probability <- function(team1, team2, rating_by_team) {
  if ((is.na(team1) || !nzchar(team1)) && !is.na(team2) && nzchar(team2)) return(0)
  if ((is.na(team2) || !nzchar(team2)) && !is.na(team1) && nzchar(team1)) return(1)
  rating1 <- if (!is.na(team1) && team1 %in% names(rating_by_team)) rating_by_team[[team1]] else 1500
  rating2 <- if (!is.na(team2) && team2 %in% names(rating_by_team)) rating_by_team[[team2]] else 1500
  if (is.null(rating1) || is.na(rating1)) rating1 <- 1500
  if (is.null(rating2) || is.na(rating2)) rating2 <- 1500
  1 / (1 + 10^((rating2 - rating1) / 400))
}

summarise_knockout_scorelines <- function(slot1_goals, slot2_goals, top_n_scorelines = 5) {
  n_sim <- length(slot1_goals)
  scorelines <- aggregate(
    count ~ slot1_goals + slot2_goals,
    data = data.frame(slot1_goals = slot1_goals, slot2_goals = slot2_goals, count = 1L),
    FUN = sum
  )
  scorelines$scoreline <- paste(scorelines$slot1_goals, scorelines$slot2_goals, sep = "-")
  scorelines$outcome <- ifelse(
    scorelines$slot1_goals > scorelines$slot2_goals,
    "slot1_win",
    ifelse(scorelines$slot1_goals == scorelines$slot2_goals, "draw", "slot2_win")
  )
  scorelines$probability <- scorelines$count / n_sim
  scorelines$total_goals <- scorelines$slot1_goals + scorelines$slot2_goals
  scorelines <- scorelines[order(-scorelines$probability, scorelines$total_goals, scorelines$slot1_goals, scorelines$slot2_goals), ]
  top_scorelines <- head(scorelines, top_n_scorelines)
  list(
    most_likely_score = top_scorelines$scoreline[1],
    most_likely_score_probability = top_scorelines$probability[1],
    rounded_expected_score = paste(round(mean(slot1_goals)), round(mean(slot2_goals)), sep = "-"),
    over_2_5_probability = mean(slot1_goals + slot2_goals > 2.5),
    both_teams_to_score_probability = mean(slot1_goals > 0 & slot2_goals > 0),
    top_scorelines_label = paste(
      sprintf("%s %.1f%%", top_scorelines$scoreline, 100 * top_scorelines$probability),
      collapse = " | "
    )
  )
}

summarise_knockout_scoreline_grid <- function(score_grid, goals, top_n_scorelines = 5) {
  scorelines <- expand.grid(
    slot1_goals = goals,
    slot2_goals = goals,
    KEEP.OUT.ATTRS = FALSE
  )
  scorelines$probability <- as.vector(score_grid)
  scorelines$scoreline <- paste(scorelines$slot1_goals, scorelines$slot2_goals, sep = "-")
  scorelines$outcome <- ifelse(
    scorelines$slot1_goals > scorelines$slot2_goals,
    "slot1_win",
    ifelse(scorelines$slot1_goals == scorelines$slot2_goals, "draw", "slot2_win")
  )
  scorelines$total_goals <- scorelines$slot1_goals + scorelines$slot2_goals
  scorelines <- scorelines[order(-scorelines$probability, scorelines$total_goals, scorelines$slot1_goals, scorelines$slot2_goals), ]
  top_scorelines <- head(scorelines, top_n_scorelines)
  slot1_marginal <- rowSums(score_grid)
  slot2_marginal <- colSums(score_grid)
  list(
    most_likely_score = top_scorelines$scoreline[1],
    most_likely_score_probability = top_scorelines$probability[1],
    rounded_expected_score = paste(round(sum(goals * slot1_marginal)), round(sum(goals * slot2_marginal)), sep = "-"),
    over_2_5_probability = sum(scorelines$probability[scorelines$total_goals > 2.5]),
    both_teams_to_score_probability = sum(scorelines$probability[scorelines$slot1_goals > 0 & scorelines$slot2_goals > 0]),
    top_scorelines_label = paste(
      sprintf("%s %.1f%%", top_scorelines$scoreline, 100 * top_scorelines$probability),
      collapse = " | "
    )
  )
}

sample_knockout_winner_from_route <- function(team1, team2, route) {
  if ((is.na(team1) || !nzchar(team1)) && !is.na(team2) && nzchar(team2)) return(team2)
  if ((is.na(team2) || !nzchar(team2)) && !is.na(team1) && nzchar(team1)) return(team1)
  if (is.null(route)) stop("knockout route probabilities are required for two-team knockout matches")
  u <- runif(1)
  if (u <= route$slot1_regulation_win_probability) return(team1)
  if (u <= route$slot1_regulation_win_probability + route$slot2_regulation_win_probability) return(team2)
  if (runif(1) <= route$tiebreak_probability) team1 else team2
}

preserve_random_state <- function(expr) {
  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  old_seed <- if (had_seed) get(".Random.seed", envir = .GlobalEnv, inherits = FALSE) else NULL
  on.exit({
    if (had_seed) {
      assign(".Random.seed", old_seed, envir = .GlobalEnv)
    } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".Random.seed", envir = .GlobalEnv)
    }
  }, add = TRUE)
  force(expr)
}

make_knockout_route_estimator <- function(
    rating_by_team,
    date,
    n_sim = 1000,
    seed = NULL,
    home_model_path = "models/home_goal_model.rds",
    away_model_path = "models/away_goal_model.rds",
    elo_ratings_path = "data/processed/elo_ratings.csv",
    forecast_features = NULL,
    forecast_features_path = NULL,
    require_forecast_features = FALSE,
    model_version = NULL,
    top_n_scorelines = 5,
    precompute_teams = NULL,
    precompute_workers = 1,
    route_method = c("analytic", "simulation"),
    route_max_goals = 10,
    cache = new.env(parent = emptyenv())
) {
  route_method <- match.arg(route_method)
  if (!file.exists(home_model_path)) stop(paste("Home model not found:", home_model_path))
  if (!file.exists(away_model_path)) stop(paste("Away model not found:", away_model_path))
  if (!file.exists(elo_ratings_path)) stop(paste("Elo ratings not found:", elo_ratings_path))

  home_model <- readRDS(home_model_path)
  away_model <- readRDS(away_model_path)
  elo_ratings <- read.csv(elo_ratings_path, stringsAsFactors = FALSE)
  elo_ratings$date <- as.Date(elo_ratings$date)
  match_date <- as.Date(date)
  if (is.null(model_version)) {
    model_version <- attr(home_model, "xgelo_model_version")
    if (is.null(model_version)) model_version <- "unknown"
  }
  if (
    is.null(forecast_features) &&
      is.character(forecast_features_path) &&
      length(forecast_features_path) == 1 &&
      !is.na(forecast_features_path) &&
      file.exists(forecast_features_path)
  ) {
    forecast_features <- read.csv(forecast_features_path, stringsAsFactors = FALSE)
  }
  if (!is.null(forecast_features) && "date" %in% names(forecast_features)) {
    forecast_features$date <- as.Date(forecast_features$date)
  }
  normalise_team <- if (exists("feature_team_match_key")) feature_team_match_key else if (exists("canonicalise_feature_team_name")) canonicalise_feature_team_name else identity
  forecast_feature_index <- NULL
  if (is.data.frame(forecast_features) && nrow(forecast_features) > 0 && all(c("home_team", "away_team") %in% names(forecast_features))) {
    feature_dates <- if ("date" %in% names(forecast_features)) as.character(as.Date(forecast_features$date)) else rep("__any__", nrow(forecast_features))
    feature_keys <- paste(
      feature_dates,
      normalise_team(forecast_features$home_team),
      normalise_team(forecast_features$away_team),
      sep = "\r"
    )
    forecast_feature_index <- split(seq_len(nrow(forecast_features)), feature_keys)
  }

  model_has_side_context <- function(model) {
    inherits(model, c("glm", "lm", "negbin", "side_context_goal_model")) &&
      !inherits(model, "constant_goal_model")
  }
  model_uses_home_perspective <- function(model) {
    identical(attr(model, "xgelo_feature_perspective"), "home")
  }
  model_predictors <- function(model) {
    predictors <- attr(model, "xgelo_predictors")
    if (is.null(predictors) || length(predictors) == 0) {
      predictors <- tryCatch(attr(stats::terms(model), "term.labels"), error = function(e) character())
    }
    if (length(predictors) == 0) predictors <- "elo_diff"
    predictors
  }
  get_negative_binomial_theta <- function(model) {
    theta <- model$theta
    if (!is.null(theta) && is.numeric(theta) && length(theta) == 1 && is.finite(theta) && theta > 0) {
      return(theta)
    }
    1
  }
  get_pre_match_elo <- function(team_name) {
    team_rows <- elo_ratings[
      elo_ratings$team == team_name &
        !is.na(elo_ratings$rating) &
        elo_ratings$date < match_date,
    ]
    if (nrow(team_rows) > 0) {
      if (!"is_post_match" %in% names(team_rows)) team_rows$is_post_match <- TRUE
      team_rows <- team_rows[order(team_rows$date, team_rows$is_post_match), ]
      return(tail(team_rows$rating, 1))
    }
    fallback <- if (!is.na(team_name) && team_name %in% names(rating_by_team)) rating_by_team[[team_name]] else 1500
    if (is.null(fallback) || is.na(fallback)) 1500 else fallback
  }
  lookup_feature_row <- function(team1, team2, elo_diff) {
    predictors <- unique(c(model_predictors(home_model), model_predictors(away_model)))
    row <- as.data.frame(as.list(stats::setNames(rep(0, length(predictors)), predictors)))
    if ("elo_diff" %in% predictors) row$elo_diff <- elo_diff

    if (!is.null(forecast_feature_index)) {
      lookup_dates <- if ("date" %in% names(forecast_features)) as.character(match_date) else "__any__"
      lookup_key <- paste(lookup_dates, normalise_team(team1), normalise_team(team2), sep = "\r")
      match_idx <- forecast_feature_index[[lookup_key]]
      if (length(match_idx) > 0) {
        matched <- forecast_features[match_idx[1], , drop = FALSE]
        for (predictor in intersect(predictors, names(matched))) {
          row[[predictor]] <- matched[[predictor]][1]
        }
        for (predictor in names(row)) {
          row[[predictor]] <- suppressWarnings(as.numeric(row[[predictor]]))
          if (!is.finite(row[[predictor]])) row[[predictor]] <- 0
        }
        return(row)
      }
    }

    non_elo_predictors <- setdiff(predictors, "elo_diff")
    if (isTRUE(require_forecast_features) && length(non_elo_predictors) > 0) {
      available_rows <- if (is.data.frame(forecast_features) && nrow(forecast_features) > 0 && all(c("date", "home_team", "away_team") %in% names(forecast_features))) {
        date_rows <- forecast_features[as.Date(forecast_features$date) == match_date, c("home_team", "away_team"), drop = FALSE]
        nearby <- date_rows[
          normalise_team(date_rows$home_team) == normalise_team(team1) |
            normalise_team(date_rows$away_team) == normalise_team(team2),
          ,
          drop = FALSE
        ]
        paste(head(paste(nearby$home_team, nearby$away_team, sep = " vs "), 5), collapse = " | ")
      } else {
        "no forecast feature rows loaded"
      }
      stop(paste(
        "Missing required knockout forecast features for",
        team1,
        "vs",
        team2,
        "on",
        as.character(match_date),
        sprintf(
          "(keys: %s vs %s; nearby: %s)",
          normalise_team(team1),
          normalise_team(team2),
          available_rows
        )
      ))
    }
    row
  }
  reverse_feature_row <- function(row) {
    reversed <- row
    diff_cols <- grep("(^elo_diff$|_diff$)", names(reversed), value = TRUE)
    for (col in diff_cols) reversed[[col]] <- -reversed[[col]]
    reversed
  }
  route_lambda_cache <- new.env(parent = emptyenv())
  build_predict_newdata <- function(features) {
    predictors <- unique(c(model_predictors(home_model), model_predictors(away_model)))
    if (length(predictors) == 0) predictors <- "elo_diff"
    for (predictor in predictors) {
      if (!predictor %in% names(features)) features[[predictor]] <- 0
    }
    newdata <- features[, predictors, drop = FALSE]
    for (predictor in predictors) {
      newdata[[predictor]] <- suppressWarnings(as.numeric(newdata[[predictor]]))
      newdata[[predictor]][!is.finite(newdata[[predictor]])] <- 0
    }
    newdata
  }
  precompute_route_lambdas <- function() {
    if (!is.data.frame(forecast_features) || nrow(forecast_features) == 0 || !"date" %in% names(forecast_features)) {
      return(invisible(0L))
    }
    route_features <- forecast_features[forecast_features$date == match_date, , drop = FALSE]
    if (nrow(route_features) == 0 || !all(c("home_team", "away_team") %in% names(route_features))) {
      return(invisible(0L))
    }
    feature_newdata <- build_predict_newdata(route_features)
    feature_newdata_reversed <- reverse_feature_row(feature_newdata)
    if (model_uses_home_perspective(home_model) || model_uses_home_perspective(away_model)) {
      slot1_lambda <- rowMeans(cbind(
        as.numeric(predict(home_model, newdata = feature_newdata, type = "response")),
        as.numeric(predict(away_model, newdata = feature_newdata_reversed, type = "response"))
      ))
      slot2_lambda <- rowMeans(cbind(
        as.numeric(predict(home_model, newdata = feature_newdata_reversed, type = "response")),
        as.numeric(predict(away_model, newdata = feature_newdata, type = "response"))
      ))
    } else if (model_has_side_context(home_model) || model_has_side_context(away_model)) {
      slot1_lambda <- rowMeans(cbind(
        as.numeric(predict(home_model, newdata = feature_newdata, type = "response")),
        as.numeric(predict(away_model, newdata = feature_newdata, type = "response"))
      ))
      slot2_lambda <- rowMeans(cbind(
        as.numeric(predict(home_model, newdata = feature_newdata_reversed, type = "response")),
        as.numeric(predict(away_model, newdata = feature_newdata_reversed, type = "response"))
      ))
    } else {
      slot1_lambda <- as.numeric(predict(home_model, newdata = feature_newdata, type = "response"))
      slot2_lambda <- as.numeric(predict(away_model, newdata = feature_newdata_reversed, type = "response"))
    }
    route_keys <- paste(
      as.character(match_date),
      normalise_team(route_features$home_team),
      normalise_team(route_features$away_team),
      sep = "\r"
    )
    for (i in seq_along(route_keys)) {
      assign(
        route_keys[i],
        c(
          slot1_lambda = max(slot1_lambda[i], 1e-6, na.rm = TRUE),
          slot2_lambda = max(slot2_lambda[i], 1e-6, na.rm = TRUE)
        ),
        envir = route_lambda_cache
      )
    }
    invisible(length(route_keys))
  }
  precompute_route_lambdas()

  estimate_uncached <- function(team1, team2, route_seed) {
    tiebreak_probability <- knockout_advancement_probability(team1, team2, rating_by_team)
    elo_diff <- get_pre_match_elo(team1) - get_pre_match_elo(team2)
    lambda_key <- paste(as.character(match_date), normalise_team(team1), normalise_team(team2), sep = "\r")
    route_lambdas <- if (exists(lambda_key, envir = route_lambda_cache, inherits = FALSE)) {
      get(lambda_key, envir = route_lambda_cache, inherits = FALSE)
    } else {
      NULL
    }
    if (!is.null(route_lambdas)) {
      slot1_lambda <- route_lambdas[["slot1_lambda"]]
      slot2_lambda <- route_lambdas[["slot2_lambda"]]
    } else {
      feature_newdata <- lookup_feature_row(team1, team2, elo_diff)
      feature_newdata_reversed <- reverse_feature_row(feature_newdata)
      if (model_uses_home_perspective(home_model) || model_uses_home_perspective(away_model)) {
        slot1_lambda <- mean(c(
          predict(home_model, newdata = feature_newdata, type = "response"),
          predict(away_model, newdata = feature_newdata_reversed, type = "response")
        ))
        slot2_lambda <- mean(c(
          predict(home_model, newdata = feature_newdata_reversed, type = "response"),
          predict(away_model, newdata = feature_newdata, type = "response")
        ))
      } else if (model_has_side_context(home_model) || model_has_side_context(away_model)) {
        slot1_lambda <- mean(c(
          predict(home_model, newdata = feature_newdata, type = "response"),
          predict(away_model, newdata = feature_newdata, type = "response")
        ))
        slot2_lambda <- mean(c(
          predict(home_model, newdata = feature_newdata_reversed, type = "response"),
          predict(away_model, newdata = feature_newdata_reversed, type = "response")
        ))
      } else {
        slot1_lambda <- predict(home_model, newdata = feature_newdata, type = "response")
        slot2_lambda <- predict(away_model, newdata = feature_newdata_reversed, type = "response")
      }
    }
    if (route_method == "analytic") {
      goals <- 0:route_max_goals
      home_theta <- get_negative_binomial_theta(home_model)
      away_theta <- get_negative_binomial_theta(away_model)
      slot1_probs <- stats::dnbinom(goals, size = home_theta, mu = slot1_lambda)
      slot2_probs <- stats::dnbinom(goals, size = away_theta, mu = slot2_lambda)
      score_grid <- outer(slot1_probs, slot2_probs)
      score_grid <- score_grid / sum(score_grid)
      slot1_regulation <- sum(score_grid[row(score_grid) > col(score_grid)])
      draw_after_regulation <- sum(diag(score_grid))
      slot2_regulation <- sum(score_grid[row(score_grid) < col(score_grid)])
      slot1_extra <- draw_after_regulation * tiebreak_probability
      slot2_extra <- draw_after_regulation * (1 - tiebreak_probability)
      scoreline_summary <- summarise_knockout_scoreline_grid(
        score_grid,
        goals,
        top_n_scorelines = top_n_scorelines
      )
      return(list(
        slot1_regulation_win_probability = slot1_regulation,
        slot1_extra_time_penalty_probability = slot1_extra,
        slot1_advancement_probability = slot1_regulation + slot1_extra,
        slot2_regulation_win_probability = slot2_regulation,
        slot2_extra_time_penalty_probability = slot2_extra,
        slot2_advancement_probability = slot2_regulation + slot2_extra,
        draw_after_regulation_probability = draw_after_regulation,
        tiebreak_probability = tiebreak_probability,
        slot1_expected_goals = sum(goals * rowSums(score_grid)),
        slot2_expected_goals = sum(goals * colSums(score_grid)),
        most_likely_score = scoreline_summary$most_likely_score,
        most_likely_score_probability = scoreline_summary$most_likely_score_probability,
        rounded_expected_score = scoreline_summary$rounded_expected_score,
        over_2_5_probability = scoreline_summary$over_2_5_probability,
        both_teams_to_score_probability = scoreline_summary$both_teams_to_score_probability,
        top_scorelines_label = scoreline_summary$top_scorelines_label
      ))
    }
    if (!is.null(route_seed)) set.seed(route_seed)
    slot1_goals <- rnbinom(n_sim, size = get_negative_binomial_theta(home_model), prob = get_negative_binomial_theta(home_model) / (get_negative_binomial_theta(home_model) + slot1_lambda))
    slot2_goals <- rnbinom(n_sim, size = get_negative_binomial_theta(away_model), prob = get_negative_binomial_theta(away_model) / (get_negative_binomial_theta(away_model) + slot2_lambda))
    slot1_regulation <- mean(slot1_goals > slot2_goals)
    draw_after_regulation <- mean(slot1_goals == slot2_goals)
    slot2_regulation <- mean(slot2_goals > slot1_goals)
    slot1_extra <- draw_after_regulation * tiebreak_probability
    slot2_extra <- draw_after_regulation * (1 - tiebreak_probability)
    scoreline_summary <- summarise_knockout_scorelines(
      slot1_goals,
      slot2_goals,
      top_n_scorelines = top_n_scorelines
    )
    list(
      slot1_regulation_win_probability = slot1_regulation,
      slot1_extra_time_penalty_probability = slot1_extra,
      slot1_advancement_probability = slot1_regulation + slot1_extra,
      slot2_regulation_win_probability = slot2_regulation,
      slot2_extra_time_penalty_probability = slot2_extra,
      slot2_advancement_probability = slot2_regulation + slot2_extra,
      draw_after_regulation_probability = draw_after_regulation,
      tiebreak_probability = tiebreak_probability,
      slot1_expected_goals = mean(slot1_goals),
      slot2_expected_goals = mean(slot2_goals),
      most_likely_score = scoreline_summary$most_likely_score,
      most_likely_score_probability = scoreline_summary$most_likely_score_probability,
      rounded_expected_score = scoreline_summary$rounded_expected_score,
      over_2_5_probability = scoreline_summary$over_2_5_probability,
      both_teams_to_score_probability = scoreline_summary$both_teams_to_score_probability,
      top_scorelines_label = scoreline_summary$top_scorelines_label
    )
  }

  stable_route_seed <- function(key) {
    if (is.null(seed)) return(sample.int(.Machine$integer.max, 1))
    codes <- utf8ToInt(key)
    hash <- 0
    for (code in codes) {
      hash <- (hash * 131 + code) %% 1000000000
    }
    route_seed <- (seed + hash) %% .Machine$integer.max
    as.integer(if (route_seed <= 0) route_seed + .Machine$integer.max else route_seed)
  }

  route_cache_key <- function(team1, team2) {
    paste(model_version, as.character(match_date), team1, team2, sep = "\r")
  }

  estimate_route_cached <- function(team1, team2) {
    if ((is.na(team1) || !nzchar(team1)) || (is.na(team2) || !nzchar(team2))) {
      return(NULL)
    }
    key <- route_cache_key(team1, team2)
    if (!exists(key, envir = cache, inherits = FALSE)) {
      route_seed <- stable_route_seed(key)
      route <- preserve_random_state(estimate_uncached(team1, team2, route_seed))
      assign(key, route, envir = cache)
    }
    get(key, envir = cache, inherits = FALSE)
  }

  precompute_route_cache <- function(teams) {
    teams <- unique(as.character(teams))
    teams <- teams[!is.na(teams) & nzchar(teams)]
    if (length(teams) < 2) return(invisible(0L))
    pair_grid <- expand.grid(team1 = teams, team2 = teams, stringsAsFactors = FALSE)
    pair_grid <- pair_grid[pair_grid$team1 != pair_grid$team2, , drop = FALSE]
    pair_grid$key <- mapply(route_cache_key, pair_grid$team1, pair_grid$team2, USE.NAMES = FALSE)
    pair_grid <- pair_grid[!vapply(pair_grid$key, exists, logical(1), envir = cache, inherits = FALSE), , drop = FALSE]
    if (nrow(pair_grid) == 0) return(invisible(0L))

    worker_count <- suppressWarnings(as.integer(precompute_workers))
    if (is.na(worker_count) || worker_count < 1L) worker_count <- 1L
    worker_count <- min(worker_count, nrow(pair_grid))
    if (.Platform$OS.type == "windows") worker_count <- 1L
    chunks <- split(pair_grid, rep(seq_len(worker_count), length.out = nrow(pair_grid)))

    estimate_chunk <- function(rows) {
      out <- vector("list", nrow(rows))
      names(out) <- rows$key
      for (i in seq_len(nrow(rows))) {
        route_seed <- stable_route_seed(rows$key[i])
        out[[i]] <- preserve_random_state(estimate_uncached(rows$team1[i], rows$team2[i], route_seed))
      }
      out
    }

    route_chunks <- if (worker_count > 1L) {
      parallel::mclapply(chunks, estimate_chunk, mc.cores = worker_count, mc.preschedule = TRUE)
    } else {
      lapply(chunks, estimate_chunk)
    }
    for (route_chunk in route_chunks) {
      for (key in names(route_chunk)) {
        assign(key, route_chunk[[key]], envir = cache)
      }
    }
    invisible(nrow(pair_grid))
  }

  if (!is.null(precompute_teams)) {
    precompute_route_cache(precompute_teams)
  }

  estimate_route_cached
}

estimate_knockout_route_probabilities <- function(
    team1,
    team2,
    rating_by_team,
    date,
    n_sim = 1000,
    seed = NULL,
    ...
) {
  estimator <- make_knockout_route_estimator(
    rating_by_team = rating_by_team,
    date = date,
    n_sim = n_sim,
    seed = seed,
    ...
  )
  estimator(team1, team2)
}

simulate_knockout_bracket_once <- function(
    ranked_groups,
    best_thirds,
    rating_by_team,
    knockout_route_estimator = NULL
) {
  if (is.null(knockout_route_estimator)) {
    stop("knockout_route_estimator is required so knockouts use 90-minute goal-model routes")
  }
  bracket <- worldcup_bracket_template(include_champion = FALSE)
  remaining_thirds <- best_thirds
  match_winners <- list()
  reachers <- list(
    round_of_16 = character(),
    quarterfinal = character(),
    semifinal = character(),
    final = character(),
    champion = character()
  )

  for (i in seq_len(nrow(bracket))) {
    slot1 <- resolve_simulated_bracket_slot(bracket$slot1_label[i], ranked_groups, remaining_thirds, match_winners)
    remaining_thirds <- slot1$remaining_thirds
    slot2 <- resolve_simulated_bracket_slot(bracket$slot2_label[i], ranked_groups, remaining_thirds, match_winners)
    remaining_thirds <- slot2$remaining_thirds

    route <- knockout_route_estimator(slot1$team, slot2$team)
    winner <- sample_knockout_winner_from_route(slot1$team, slot2$team, route)
    match_winners[[bracket$match_id[i]]] <- winner

    if (bracket$round[i] == "Round of 32") {
      reachers$round_of_16 <- c(reachers$round_of_16, winner)
    } else if (bracket$round[i] == "Round of 16") {
      reachers$quarterfinal <- c(reachers$quarterfinal, winner)
    } else if (bracket$round[i] == "Quarter-finals") {
      reachers$semifinal <- c(reachers$semifinal, winner)
    } else if (bracket$round[i] == "Semi-finals") {
      reachers$final <- c(reachers$final, winner)
    } else if (bracket$round[i] == "Final") {
      reachers$champion <- c(reachers$champion, winner)
    }
  }

  reachers
}

normalise_dashboard_workers <- function(n_workers, n_tournaments) {
  n_workers <- suppressWarnings(as.integer(n_workers))
  if (is.na(n_workers) || n_workers < 1L) n_workers <- 1L
  n_workers <- min(n_workers, as.integer(n_tournaments))
  if (.Platform$OS.type == "windows") {
    return(1L)
  }
  n_workers
}

default_dashboard_workers <- function(max_workers = 4L) {
  configured <- getOption("xgelo.dashboard_workers", NULL)
  if (!is.null(configured)) return(configured)
  detected <- tryCatch(parallel::detectCores(), error = function(e) 1L)
  if (is.na(detected) || detected < 1L) detected <- 1L
  min(as.integer(max_workers), max(1L, as.integer(detected) - 1L))
}

simulate_group_stage_dashboard <- function(
    groups,
    fixtures,
    scoreline_distributions,
    n_tournaments = 1000,
    seed = 20260612,
    knockout_ratings = NULL,
    knockout_date = NULL,
    n_knockout_sim = 1000,
    knockout_route_estimator = NULL,
    n_workers = default_dashboard_workers(),
    ...
) {
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
    round_of_16_count = 0,
    quarterfinal_count = 0,
    semifinal_count = 0,
    final_count = 0,
    champion_count = 0,
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
  if (is.null(knockout_ratings)) {
    knockout_ratings <- data.frame(team = team_names, rating = 1500, stringsAsFactors = FALSE)
  }
  knockout_ratings <- knockout_ratings[knockout_ratings$team %in% team_names, c("team", "rating")]
  rating_by_team <- stats::setNames(knockout_ratings$rating, knockout_ratings$team)
  if (is.null(knockout_date)) knockout_date <- max(fixtures$date, na.rm = TRUE) + 1
  if (is.null(knockout_route_estimator)) {
    knockout_route_estimator <- make_knockout_route_estimator(
      rating_by_team = rating_by_team,
      date = knockout_date,
      n_sim = n_knockout_sim,
      seed = if (!is.null(seed)) seed + 100000L else NULL,
      ...
    )
  }

  count_columns <- setdiff(names(counts), c("team", "group", "display_team"))
  worker_count <- normalise_dashboard_workers(n_workers, n_tournaments)
  iteration_seeds <- sample.int(.Machine$integer.max, n_tournaments)
  seed_chunks <- split(iteration_seeds, rep(seq_len(worker_count), length.out = n_tournaments))
  simulate_chunk <- function(chunk_seeds) {
    chunk_counts <- counts
    chunk_counts[count_columns] <- 0

    for (iteration_seed in chunk_seeds) {
      set.seed(iteration_seed)
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

        chunk_counts$group_win_count[match(ranked$team[1], chunk_counts$team)] <- chunk_counts$group_win_count[match(ranked$team[1], chunk_counts$team)] + 1
        top_two <- ranked$team[1:2]
        chunk_counts$top_two_count[match(top_two, chunk_counts$team)] <- chunk_counts$top_two_count[match(top_two, chunk_counts$team)] + 1
        for (position in 1:4) {
          col <- paste0("pos", position, "_count")
          chunk_counts[[col]][match(ranked$team[position], chunk_counts$team)] <- chunk_counts[[col]][match(ranked$team[position], chunk_counts$team)] + 1
        }
      }

      all_ranked <- do.call(rbind, ranked_groups)
      third_place <- all_ranked[all_ranked$finish_position == 3, ]
      third_place <- third_place[order(-third_place$points, -third_place$goal_difference, -third_place$goals_for, third_place$tie_breaker), ]
      best_third_rows <- head(third_place, 8)
      best_thirds <- best_third_rows$team
      round_of_32 <- union(all_ranked$team[all_ranked$finish_position <= 2], best_thirds)
      chunk_counts$third_qual_count[match(best_thirds, chunk_counts$team)] <- chunk_counts$third_qual_count[match(best_thirds, chunk_counts$team)] + 1
      chunk_counts$round_of_32_count[match(round_of_32, chunk_counts$team)] <- chunk_counts$round_of_32_count[match(round_of_32, chunk_counts$team)] + 1
      knockout_reachers <- simulate_knockout_bracket_once(
        ranked_groups,
        best_third_rows,
        rating_by_team,
        knockout_route_estimator = knockout_route_estimator
      )
      chunk_counts$round_of_16_count[match(knockout_reachers$round_of_16, chunk_counts$team)] <- chunk_counts$round_of_16_count[match(knockout_reachers$round_of_16, chunk_counts$team)] + 1
      chunk_counts$quarterfinal_count[match(knockout_reachers$quarterfinal, chunk_counts$team)] <- chunk_counts$quarterfinal_count[match(knockout_reachers$quarterfinal, chunk_counts$team)] + 1
      chunk_counts$semifinal_count[match(knockout_reachers$semifinal, chunk_counts$team)] <- chunk_counts$semifinal_count[match(knockout_reachers$semifinal, chunk_counts$team)] + 1
      chunk_counts$final_count[match(knockout_reachers$final, chunk_counts$team)] <- chunk_counts$final_count[match(knockout_reachers$final, chunk_counts$team)] + 1
      chunk_counts$champion_count[match(knockout_reachers$champion, chunk_counts$team)] <- chunk_counts$champion_count[match(knockout_reachers$champion, chunk_counts$team)] + 1
      chunk_counts$points_sum[team_index] <- chunk_counts$points_sum[team_index] + stats$points
      chunk_counts$goals_for_sum[team_index] <- chunk_counts$goals_for_sum[team_index] + stats$goals_for
      chunk_counts$goals_against_sum[team_index] <- chunk_counts$goals_against_sum[team_index] + stats$goals_against
    }

    chunk_counts
  }
  chunk_counts <- if (worker_count > 1L) {
    parallel::mclapply(seed_chunks, simulate_chunk, mc.cores = worker_count, mc.preschedule = TRUE)
  } else {
    lapply(seed_chunks, simulate_chunk)
  }
  counts[count_columns] <- 0
  for (chunk in chunk_counts) {
    counts[count_columns] <- counts[count_columns] + chunk[count_columns]
  }

  position_counts <- counts[, c("pos1_count", "pos2_count", "pos3_count", "pos4_count")]
  most_likely_position <- max.col(position_counts, ties.method = "first")
  expected_points <- counts$points_sum / n_tournaments
  expected_goals_for <- counts$goals_for_sum / n_tournaments
  expected_goals_against <- counts$goals_against_sum / n_tournaments
  expected_goal_difference <- (counts$goals_for_sum - counts$goals_against_sum) / n_tournaments
  projected_position <- integer(nrow(counts))
  for (group_id in unique(counts$group)) {
    idx <- which(counts$group == group_id)
    projected_order <- idx[order(
      -expected_points[idx],
      -expected_goal_difference[idx],
      -expected_goals_for[idx],
      -counts$group_win_count[idx] / n_tournaments,
      counts$display_team[idx]
    )]
    projected_position[projected_order] <- seq_along(projected_order)
  }
  group_probabilities <- data.frame(
    group = counts$group,
    team = counts$team,
    display_team = counts$display_team,
    fifa_code = teams$fifa_code,
    group_win_probability = counts$group_win_count / n_tournaments,
    top_two_probability = counts$top_two_count / n_tournaments,
    third_place_qual_probability = counts$third_qual_count / n_tournaments,
    round_of_32_probability = counts$round_of_32_count / n_tournaments,
    position_1_probability = counts$pos1_count / n_tournaments,
    position_2_probability = counts$pos2_count / n_tournaments,
    position_3_probability = counts$pos3_count / n_tournaments,
    position_4_probability = counts$pos4_count / n_tournaments,
    most_likely_position = most_likely_position,
    projected_position = projected_position,
    stringsAsFactors = FALSE
  )
  expected_group_tables <- data.frame(
    group = counts$group,
    team = counts$team,
    display_team = counts$display_team,
    expected_points = expected_points,
    expected_goals_for = expected_goals_for,
    expected_goals_against = expected_goals_against,
    expected_goal_difference = expected_goal_difference,
    most_likely_position = most_likely_position,
    projected_position = projected_position,
    stringsAsFactors = FALSE
  )
  group_probabilities <- group_probabilities[order(group_probabilities$group, -group_probabilities$round_of_32_probability), ]
  expected_group_tables <- expected_group_tables[order(expected_group_tables$group, expected_group_tables$projected_position), ]
  ratings <- knockout_ratings[match(team_names, knockout_ratings$team), ]
  ratings$rating[is.na(ratings$rating)] <- 1500
  stage_probabilities <- data.frame(
    team = team_names,
    display_team = teams$display_team,
    group = teams$group,
    rating = ratings$rating,
    round_of_32_probability = counts$round_of_32_count / n_tournaments,
    round_of_16_probability = counts$round_of_16_count / n_tournaments,
    quarterfinal_probability = counts$quarterfinal_count / n_tournaments,
    semifinal_probability = counts$semifinal_count / n_tournaments,
    final_probability = counts$final_count / n_tournaments,
    champion_probability = counts$champion_count / n_tournaments,
    stringsAsFactors = FALSE
  )
  list(
    group_probabilities = group_probabilities,
    expected_group_tables = expected_group_tables,
    stage_probabilities = stage_probabilities
  )
}

latest_elo_before_date <- function(
    teams,
    cutoff_date,
    elo_ratings_path = "data/processed/elo_ratings.csv",
    elo_current_path = "data/processed/elo_current.csv"
) {
  if (file.exists(elo_ratings_path)) {
    elo_history <- read.csv(elo_ratings_path, stringsAsFactors = FALSE)
    elo_history$date <- as.Date(elo_history$date)
    valid <- elo_history[
      elo_history$team %in% teams &
        !is.na(elo_history$rating) &
        elo_history$date < as.Date(cutoff_date),
    ]
    if (nrow(valid) > 0) {
      valid <- valid[order(valid$team, valid$date, valid$is_post_match), ]
      latest <- do.call(rbind, lapply(split(valid, valid$team), function(rows) rows[nrow(rows), ]))
      return(latest[, c("team", "rating")])
    }
  }

  elo <- read.csv(elo_current_path, stringsAsFactors = FALSE)
  elo <- elo[elo$team %in% teams & !is.na(elo$rating), intersect(c("team", "rating"), names(elo))]
  elo
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

resolve_bracket_slot <- function(slot, group_probabilities, stage_probabilities, projections = list(), used_teams = character()) {
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
    available <- candidates[!(candidates$team %in% used_teams), ]
    if (nrow(available) > 0) candidates <- available
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
    available <- candidates[!(candidates$team %in% used_teams), ]
    if (nrow(available) > 0) candidates <- available
    preferred <- candidates[candidates$projected_position == 2, ]
    if (nrow(preferred) > 0) candidates <- preferred
    candidates$runner_up_score <- ifelse(candidates$projected_position == 2, 1, 0) + candidates$top_two_probability
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
    available <- candidates[!(candidates$team %in% used_teams), ]
    if (nrow(available) > 0) candidates <- available
    preferred <- candidates[candidates$projected_position == 3, ]
    if (nrow(preferred) > 0) candidates <- preferred
    candidates$third_score <- ifelse(candidates$projected_position == 3, 1, 0) + candidates$third_place_qual_probability
    row <- candidates[which.max(candidates$third_score), ]
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

build_bracket_paths <- function(
    group_probabilities,
    stage_probabilities,
    knockout_date = NULL,
    n_knockout_sim = 1000,
    seed = 20260628,
    knockout_route_estimator = NULL,
    ...
) {
  paths <- worldcup_bracket_template(include_champion = TRUE)
  paths$slot1_team <- NA_character_
  paths$slot1_display <- NA_character_
  paths$slot1_probability <- NA_real_
  paths$slot1_advancement_probability <- NA_real_
  paths$slot1_regulation_win_probability <- NA_real_
  paths$slot1_extra_time_penalty_probability <- NA_real_
  paths$slot1_tiebreak_probability <- NA_real_
  paths$slot1_source_match_id <- NA_character_
  paths$slot2_team <- NA_character_
  paths$slot2_display <- NA_character_
  paths$slot2_probability <- NA_real_
  paths$slot2_advancement_probability <- NA_real_
  paths$slot2_regulation_win_probability <- NA_real_
  paths$slot2_extra_time_penalty_probability <- NA_real_
  paths$slot2_tiebreak_probability <- NA_real_
  paths$slot2_source_match_id <- NA_character_
  paths$draw_after_regulation_probability <- NA_real_
  paths$projected_winner_team <- NA_character_
  paths$projected_winner <- NA_character_
  paths$projected_winner_match_probability <- NA_real_
  paths$projected_winner_regulation_probability <- NA_real_
  paths$projected_winner_extra_time_penalty_probability <- NA_real_
  paths$projected_winner_tiebreak_probability <- NA_real_
  paths$projected_winner_route_label <- NA_character_
  paths$slot1_expected_goals <- NA_real_
  paths$slot2_expected_goals <- NA_real_
  paths$most_likely_score <- NA_character_
  paths$most_likely_score_probability <- NA_real_
  paths$rounded_expected_score <- NA_character_
  paths$over_2_5_probability <- NA_real_
  paths$both_teams_to_score_probability <- NA_real_
  paths$top_scorelines_label <- NA_character_
  paths$projected_winner_stage_probability <- NA_real_
  paths$projected_winner_title_probability <- NA_real_
  paths$next_match_id <- NA_character_
  paths$projected_winner_continues <- FALSE

  projections <- list()
  used_group_stage_teams <- character()
  rating_by_team <- stats::setNames(stage_probabilities$rating, stage_probabilities$team)
  for (i in seq_len(nrow(paths))) {
    slot1 <- resolve_bracket_slot(
      paths$slot1_label[i],
      group_probabilities = group_probabilities,
      stage_probabilities = stage_probabilities,
      projections = projections,
      used_teams = used_group_stage_teams
    )
    slot2 <- if (nzchar(paths$slot2_label[i])) {
      resolve_bracket_slot(
        paths$slot2_label[i],
        group_probabilities = group_probabilities,
        stage_probabilities = stage_probabilities,
        projections = projections,
        used_teams = c(used_group_stage_teams, slot1$team)
      )
    } else {
      list(team = NA_character_, display_team = NA_character_, probability = NA_real_, source_match_id = NA_character_)
    }
    if (paths$round[i] == "Round of 32") {
      used_group_stage_teams <- unique(c(used_group_stage_teams, slot1$team, slot2$team))
      used_group_stage_teams <- used_group_stage_teams[!is.na(used_group_stage_teams) & nzchar(used_group_stage_teams)]
    }

    probability_col <- stage_probability_column(paths$round[i])
    slot1_advancement_probability <- NA_real_
    slot2_advancement_probability <- NA_real_
    slot1_regulation_win_probability <- NA_real_
    slot2_regulation_win_probability <- NA_real_
    slot1_extra_time_penalty_probability <- NA_real_
    slot2_extra_time_penalty_probability <- NA_real_
    slot1_tiebreak_probability <- NA_real_
    slot2_tiebreak_probability <- NA_real_
    draw_after_regulation_probability <- NA_real_
    slot1_expected_goals <- NA_real_
    slot2_expected_goals <- NA_real_
    most_likely_score <- NA_character_
    most_likely_score_probability <- NA_real_
    rounded_expected_score <- NA_character_
    over_2_5_probability <- NA_real_
    both_teams_to_score_probability <- NA_real_
    top_scorelines_label <- NA_character_
    route <- NULL
    if (!is.na(slot1$team) && nzchar(slot1$team) && !is.na(slot2$team) && nzchar(slot2$team)) {
      slot1_advancement_probability <- knockout_advancement_probability(slot1$team, slot2$team, rating_by_team)
      slot2_advancement_probability <- 1 - slot1_advancement_probability
      if (!is.null(knockout_route_estimator)) {
        route <- knockout_route_estimator(slot1$team, slot2$team)
      } else if (!is.null(knockout_date)) {
        route <- estimate_knockout_route_probabilities(
          team1 = slot1$team,
          team2 = slot2$team,
          rating_by_team = rating_by_team,
          date = knockout_date,
          n_sim = n_knockout_sim,
          seed = seed + i,
          ...
        )
      }
      if (!is.null(route)) {
        slot1_advancement_probability <- route$slot1_advancement_probability
        slot2_advancement_probability <- route$slot2_advancement_probability
        slot1_regulation_win_probability <- route$slot1_regulation_win_probability
        slot2_regulation_win_probability <- route$slot2_regulation_win_probability
        slot1_extra_time_penalty_probability <- route$slot1_extra_time_penalty_probability
        slot2_extra_time_penalty_probability <- route$slot2_extra_time_penalty_probability
        slot1_tiebreak_probability <- route$tiebreak_probability
        slot2_tiebreak_probability <- 1 - route$tiebreak_probability
        draw_after_regulation_probability <- route$draw_after_regulation_probability
        slot1_expected_goals <- if (is.null(route$slot1_expected_goals)) NA_real_ else route$slot1_expected_goals
        slot2_expected_goals <- if (is.null(route$slot2_expected_goals)) NA_real_ else route$slot2_expected_goals
        most_likely_score <- if (is.null(route$most_likely_score)) NA_character_ else route$most_likely_score
        most_likely_score_probability <- if (is.null(route$most_likely_score_probability)) NA_real_ else route$most_likely_score_probability
        rounded_expected_score <- if (is.null(route$rounded_expected_score)) NA_character_ else route$rounded_expected_score
        over_2_5_probability <- if (is.null(route$over_2_5_probability)) NA_real_ else route$over_2_5_probability
        both_teams_to_score_probability <- if (is.null(route$both_teams_to_score_probability)) NA_real_ else route$both_teams_to_score_probability
        top_scorelines_label <- if (is.null(route$top_scorelines_label)) NA_character_ else route$top_scorelines_label
      }
    } else if (!is.na(slot1$team) && nzchar(slot1$team) && paths$round[i] == "Champion") {
      slot1_advancement_probability <- team_stage_probability(slot1$team, stage_probabilities, "champion_probability")
    }
    candidates <- data.frame(
      team = c(slot1$team, slot2$team),
      display_team = c(slot1$display_team, slot2$display_team),
      stage_probability = c(
        team_stage_probability(slot1$team, stage_probabilities, probability_col),
        team_stage_probability(slot2$team, stage_probabilities, probability_col)
      ),
      match_probability = c(slot1_advancement_probability, slot2_advancement_probability),
      stringsAsFactors = FALSE
    )
    candidates <- candidates[!is.na(candidates$team) & nzchar(candidates$team), ]
    if (nrow(candidates) == 0 && paths$round[i] == "Champion") {
      champion <- stage_probabilities[which.max(stage_probabilities$champion_probability), ]
      candidates <- data.frame(
        team = champion$team,
        display_team = champion$display_team,
        stage_probability = champion$champion_probability,
        match_probability = champion$champion_probability,
        stringsAsFactors = FALSE
      )
    }
    winner <- if (nrow(candidates) > 0) {
      ranking_probability <- ifelse(is.na(candidates$match_probability), candidates$stage_probability, candidates$match_probability)
      candidates[which.max(ranking_probability), ]
    } else {
      data.frame(team = NA_character_, display_team = NA_character_, stage_probability = NA_real_, match_probability = NA_real_)
    }

    paths$slot1_team[i] <- slot1$team
    paths$slot1_display[i] <- slot1$display_team
    paths$slot1_probability[i] <- slot1$probability
    paths$slot1_advancement_probability[i] <- slot1_advancement_probability
    paths$slot1_regulation_win_probability[i] <- slot1_regulation_win_probability
    paths$slot1_extra_time_penalty_probability[i] <- slot1_extra_time_penalty_probability
    paths$slot1_tiebreak_probability[i] <- slot1_tiebreak_probability
    paths$slot1_source_match_id[i] <- slot1$source_match_id
    paths$slot2_team[i] <- slot2$team
    paths$slot2_display[i] <- slot2$display_team
    paths$slot2_probability[i] <- slot2$probability
    paths$slot2_advancement_probability[i] <- slot2_advancement_probability
    paths$slot2_regulation_win_probability[i] <- slot2_regulation_win_probability
    paths$slot2_extra_time_penalty_probability[i] <- slot2_extra_time_penalty_probability
    paths$slot2_tiebreak_probability[i] <- slot2_tiebreak_probability
    paths$slot2_source_match_id[i] <- slot2$source_match_id
    paths$draw_after_regulation_probability[i] <- draw_after_regulation_probability
    paths$slot1_expected_goals[i] <- slot1_expected_goals
    paths$slot2_expected_goals[i] <- slot2_expected_goals
    paths$most_likely_score[i] <- most_likely_score
    paths$most_likely_score_probability[i] <- most_likely_score_probability
    paths$rounded_expected_score[i] <- rounded_expected_score
    paths$over_2_5_probability[i] <- over_2_5_probability
    paths$both_teams_to_score_probability[i] <- both_teams_to_score_probability
    paths$top_scorelines_label[i] <- top_scorelines_label
    paths$projected_winner_team[i] <- winner$team[1]
    paths$projected_winner[i] <- winner$display_team[1]
    paths$projected_winner_match_probability[i] <- winner$match_probability[1]
    if (!is.na(winner$team[1]) && winner$team[1] == slot1$team) {
      paths$projected_winner_regulation_probability[i] <- slot1_regulation_win_probability
      paths$projected_winner_extra_time_penalty_probability[i] <- slot1_extra_time_penalty_probability
    } else if (!is.na(winner$team[1]) && winner$team[1] == slot2$team) {
      paths$projected_winner_regulation_probability[i] <- slot2_regulation_win_probability
      paths$projected_winner_extra_time_penalty_probability[i] <- slot2_extra_time_penalty_probability
    }
    if (
      !is.na(draw_after_regulation_probability) &&
        draw_after_regulation_probability > 0 &&
        !is.na(paths$projected_winner_extra_time_penalty_probability[i])
    ) {
      paths$projected_winner_tiebreak_probability[i] <-
        paths$projected_winner_extra_time_penalty_probability[i] / draw_after_regulation_probability
    }
    if (
      !is.na(paths$projected_winner_regulation_probability[i]) &&
        !is.na(paths$projected_winner_extra_time_penalty_probability[i]) &&
        !is.na(paths$projected_winner_tiebreak_probability[i])
    ) {
      paths$projected_winner_route_label[i] <- paste0(
        "90' win ",
        sprintf("%.1f%%", 100 * paths$projected_winner_regulation_probability[i]),
        " + (90' draw ",
        sprintf("%.1f%%", 100 * draw_after_regulation_probability),
        " x ET/pens share ",
        sprintf("%.1f%%", 100 * paths$projected_winner_tiebreak_probability[i]),
        " = ",
        sprintf("%.1f%%", 100 * paths$projected_winner_extra_time_penalty_probability[i]),
        ")"
      )
    }
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

  paths <- mark_projected_champion_path(paths)
  paths
}

mark_projected_champion_path <- function(paths) {
  paths$projected_champion_path <- FALSE
  if (!nrow(paths) || !"match_id" %in% names(paths)) {
    return(paths)
  }

  champion_idx <- match("Champion", paths$match_id)
  final_idx <- match("M104", paths$match_id)
  champion_team <- NA_character_
  if (!is.na(champion_idx)) {
    champion_team <- paths$projected_winner_team[champion_idx]
    paths$projected_champion_path[champion_idx] <- TRUE
  }
  if ((is.na(champion_team) || !nzchar(champion_team)) && !is.na(final_idx)) {
    champion_team <- paths$projected_winner_team[final_idx]
  }
  if (is.na(champion_team) || !nzchar(champion_team)) {
    return(paths)
  }

  current_id <- "M104"
  seen <- character()
  while (!is.na(current_id) && nzchar(current_id) && !current_id %in% seen) {
    seen <- c(seen, current_id)
    idx <- match(current_id, paths$match_id)
    if (is.na(idx)) break
    if (!isTRUE(!is.na(paths$projected_winner_team[idx]) && paths$projected_winner_team[idx] == champion_team)) {
      break
    }

    paths$projected_champion_path[idx] <- TRUE
    next_source <- NA_character_
    if (
      "slot1_team" %in% names(paths) &&
        !is.na(paths$slot1_team[idx]) &&
        paths$slot1_team[idx] == champion_team &&
        "slot1_source_match_id" %in% names(paths)
    ) {
      next_source <- paths$slot1_source_match_id[idx]
    } else if (
      "slot2_team" %in% names(paths) &&
        !is.na(paths$slot2_team[idx]) &&
        paths$slot2_team[idx] == champion_team &&
        "slot2_source_match_id" %in% names(paths)
    ) {
      next_source <- paths$slot2_source_match_id[idx]
    }
    if (is.na(next_source) || !nzchar(next_source)) break
    current_id <- next_source
  }

  paths
}

#' Read compact Transfermarkt snapshot metadata for dashboard provenance
#' @keywords internal
read_transfermarkt_dashboard_metadata <- function(
    metadata_path = "data/raw/transfermarkt/SNAPSHOT-METADATA.csv",
    snapshot_path = "data/raw/transfermarkt/transfermarkt-datasets.duckdb"
) {
  if (file.exists(metadata_path)) {
    meta <- read.csv(metadata_path, stringsAsFactors = FALSE)
    if (nrow(meta) > 0) {
      return(list(
        snapshot_path = meta$snapshot_path[1],
        snapshot_md5 = if ("md5" %in% names(meta)) meta$md5[1] else NA_character_,
        snapshot_modified_time = if ("modified_time" %in% names(meta)) meta$modified_time[1] else NA_character_
      ))
    }
  }
  if (file.exists(snapshot_path)) {
    checksum <- if (requireNamespace("tools", quietly = TRUE)) unname(tools::md5sum(snapshot_path)) else NA_character_
    return(list(
      snapshot_path = snapshot_path,
      snapshot_md5 = checksum,
      snapshot_modified_time = as.character(file.info(snapshot_path)$mtime)
    ))
  }
  list(snapshot_path = NA_character_, snapshot_md5 = NA_character_, snapshot_modified_time = NA_character_)
}

#' Read compact EURO 2024 benchmark summary for dashboard provenance
#' @keywords internal
read_euro2024_benchmark_summary <- function(metrics_path = "outputs/benchmarks/euro2024_transfermarkt_regularized/euro2024_metrics.csv") {
  if (!file.exists(metrics_path)) {
    return(list(available = FALSE))
  }
  metrics <- read.csv(metrics_path, stringsAsFactors = FALSE)
  baseline <- metrics[metrics$model == "baseline", , drop = FALSE]
  hybrid <- metrics[metrics$model == "hybrid", , drop = FALSE]
  if (nrow(baseline) == 0 || nrow(hybrid) == 0) {
    return(list(available = FALSE))
  }
  list(
    available = TRUE,
    baseline_brier = baseline$multiclass_brier[1],
    hybrid_brier = hybrid$multiclass_brier[1],
    baseline_log_loss = baseline$log_loss[1],
    hybrid_log_loss = hybrid$log_loss[1],
    baseline_rps = baseline$ranked_probability_score[1],
    hybrid_rps = hybrid$ranked_probability_score[1],
    hybrid_pass = if ("hybrid_pass" %in% names(metrics)) any(as.logical(metrics$hybrid_pass), na.rm = TRUE) else NA
  )
}

#' Read compact xG/form feature usage summary for dashboard provenance
#' @keywords internal
read_xg_feature_usage_summary <- function(audit_path = "data/processed/xg_feature_usage_audit.csv") {
  if (!file.exists(audit_path)) {
    return(list(available = FALSE))
  }
  audit <- read.csv(audit_path, stringsAsFactors = FALSE)
  if (nrow(audit) == 0) {
    return(list(available = FALSE))
  }
  active <- as.logical(audit$active_in_model)
  active[is.na(active)] <- FALSE
  nonzero <- suppressWarnings(as.numeric(audit$nonzero_count))
  sd_values <- suppressWarnings(as.numeric(audit$sd))
  list(
    available = TRUE,
    candidate_predictors = audit$predictor,
    active_predictors = audit$predictor[active],
    any_active = any(active),
    max_nonzero_count = if (all(is.na(nonzero))) NA_real_ else max(nonzero, na.rm = TRUE),
    max_sd = if (all(is.na(sd_values))) NA_real_ else max(sd_values, na.rm = TRUE),
    rolling_form_rows = audit$rolling_form_rows[1],
    training_team_coverage = audit$training_team_coverage[1],
    forecast_team_coverage = audit$forecast_team_coverage[1],
    summary = if (any(as.logical(audit$active_in_model), na.rm = TRUE)) {
      "Rolling xG/form predictors are active in at least one fitted goal model."
    } else {
      "Rolling xG/form predictors are audited but inactive in the current WC2026 goal models because usable rolling-form coverage is insufficient."
    }
  )
}

#' Compute baseline-vs-hybrid dashboard diagnostics
#' @keywords internal
compute_worldcup_model_comparison <- function(primary_payload, baseline_payload) {
  primary_stage <- primary_payload$stage_probabilities
  baseline_stage <- baseline_payload$stage_probabilities
  team_cols <- c(
    "team", "display_team", "group", "round_of_32_probability",
    "round_of_16_probability", "quarterfinal_probability",
    "semifinal_probability", "final_probability", "champion_probability"
  )
  team_comparison <- merge(
    primary_stage[, team_cols, drop = FALSE],
    baseline_stage[, team_cols, drop = FALSE],
    by = c("team", "display_team", "group"),
    suffixes = c("_hybrid", "_baseline"),
    all = FALSE
  )
  probability_cols <- setdiff(team_cols, c("team", "display_team", "group"))
  for (col in probability_cols) {
    team_comparison[[paste0(col, "_delta")]] <-
      team_comparison[[paste0(col, "_hybrid")]] - team_comparison[[paste0(col, "_baseline")]]
  }
  team_comparison <- team_comparison[order(-team_comparison$champion_probability_hybrid), , drop = FALSE]

  primary_matches <- primary_payload$match_forecasts
  baseline_matches <- baseline_payload$match_forecasts
  match_cols <- c(
    "match_id", "group", "date", "home_team", "away_team", "home_display", "away_display",
    "home_goals_expected", "away_goals_expected", "win_probability", "draw_probability", "loss_probability"
  )
  match_comparison <- merge(
    primary_matches[, match_cols, drop = FALSE],
    baseline_matches[, match_cols, drop = FALSE],
    by = c("match_id", "group", "date", "home_team", "away_team", "home_display", "away_display"),
    suffixes = c("_hybrid", "_baseline"),
    all = FALSE
  )
  for (col in c("home_goals_expected", "away_goals_expected", "win_probability", "draw_probability", "loss_probability")) {
    match_comparison[[paste0(col, "_delta")]] <-
      match_comparison[[paste0(col, "_hybrid")]] - match_comparison[[paste0(col, "_baseline")]]
  }
  list(team_deltas = team_comparison, match_deltas = match_comparison)
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
    n_workers = default_dashboard_workers(),
    elo_ratings_path = "data/processed/elo_ratings.csv",
    elo_current_path = "data/processed/elo_current.csv",
    model_version = "baseline",
    feature_cutoff_date = Sys.Date(),
    require_forecast_features = FALSE,
    forecast_features = NULL,
    forecast_features_path = NULL,
    precompute_knockout_routes = NULL,
    precompute_route_workers = n_workers,
    route_method = c("analytic", "simulation"),
    route_max_goals = 10,
    transfermarkt_metadata_path = "data/raw/transfermarkt/SNAPSHOT-METADATA.csv",
    transfermarkt_snapshot_path = "data/raw/transfermarkt/transfermarkt-datasets.duckdb",
    euro2024_metrics_path = "outputs/benchmarks/euro2024_transfermarkt_regularized/euro2024_metrics.csv",
    xg_feature_usage_audit_path = "data/processed/xg_feature_usage_audit.csv",
    actual_results_path = "data/processed/elo_matches.csv",
    actual_results_cutoff_date = Sys.Date(),
    prematch_forecasts_path = file.path(output_dir, "worldcup_prematch_forecasts.csv"),
    bracket_prematch_forecasts_path = file.path(output_dir, "worldcup_bracket_prematch_forecasts.csv"),
    baseline_comparison = FALSE,
    baseline_home_model_path = "models/home_goal_model.rds",
    baseline_away_model_path = "models/away_goal_model.rds",
    ...
) {
  suppressPackageStartupMessages({
    library(jsonlite)
  })
  extra_args <- list(...)
  route_method <- match.arg(route_method)
  home_model_path <- if (!is.null(extra_args$home_model_path)) extra_args$home_model_path else "models/home_goal_model.rds"
  away_model_path <- if (!is.null(extra_args$away_model_path)) extra_args$away_model_path else "models/away_goal_model.rds"
  dashboard_forecast_features <- forecast_features
  dashboard_forecast_features_path <- forecast_features_path
  if (
    is.null(dashboard_forecast_features) &&
      is.character(dashboard_forecast_features_path) &&
      length(dashboard_forecast_features_path) == 1 &&
      !is.na(dashboard_forecast_features_path) &&
      file.exists(dashboard_forecast_features_path)
  ) {
    dashboard_forecast_features <- read.csv(dashboard_forecast_features_path, stringsAsFactors = FALSE)
  }
  feature_cutoff_date <- as.Date(feature_cutoff_date)
  actual_results_cutoff_date <- as.Date(actual_results_cutoff_date)
  groups <- load_worldcup_2026_groups(groups_path)
  fixtures <- make_worldcup_group_fixtures(groups, schedule_path = schedule_path)
  fixtures <- attach_worldcup_actual_results(
    fixtures = fixtures,
    matches_path = actual_results_path,
    result_cutoff_date = actual_results_cutoff_date
  )
  completed_fixture_count <- sum(fixtures$is_completed, na.rm = TRUE)
  if (is.null(precompute_knockout_routes)) {
    precompute_knockout_routes <- FALSE
  }
  forecast_args <- extra_args
  forecast_args$forecast_features <- dashboard_forecast_features
  match_data <- do.call(
    forecast_dashboard_matches,
    c(
      list(
        fixtures = fixtures,
        n_match_sim = n_match_sim,
        seed = seed,
        elo_ratings_path = elo_ratings_path
      ),
      forecast_args
    )
  )
  generated_at <- as.character(Sys.time())
  prematch_archive <- update_dashboard_prematch_forecast_archive(
    match_forecasts = match_data$match_forecasts,
    path = prematch_forecasts_path,
    generated_at = generated_at,
    feature_cutoff_date = feature_cutoff_date,
    actual_results_cutoff_date = actual_results_cutoff_date
  )
  match_data$match_forecasts <- attach_dashboard_prematch_forecasts(
    match_forecasts = match_data$match_forecasts,
    prematch_archive = prematch_archive
  )
  tournament_start_date <- min(fixtures$date, na.rm = TRUE)
  knockout_ratings <- latest_elo_before_date(
    teams = groups$team,
    cutoff_date = tournament_start_date,
    elo_ratings_path = elo_ratings_path,
    elo_current_path = elo_current_path
  )
  tournament_knockout_date <- max(fixtures$date, na.rm = TRUE) + 1
  knockout_route_estimator <- make_knockout_route_estimator(
    rating_by_team = stats::setNames(knockout_ratings$rating, knockout_ratings$team),
    date = tournament_knockout_date,
    n_sim = n_match_sim,
    seed = seed + 100000L,
    home_model_path = home_model_path,
    away_model_path = away_model_path,
    elo_ratings_path = elo_ratings_path,
    forecast_features = dashboard_forecast_features,
    forecast_features_path = dashboard_forecast_features_path,
    require_forecast_features = require_forecast_features,
    model_version = model_version,
    precompute_teams = if (isTRUE(precompute_knockout_routes)) groups$team else NULL,
    precompute_workers = precompute_route_workers,
    route_method = route_method,
    route_max_goals = route_max_goals
  )
  group_data <- simulate_group_stage_dashboard(
    groups,
    fixtures,
    match_data$scoreline_distributions,
    n_tournaments = n_tournaments,
    seed = seed + 1,
    knockout_ratings = knockout_ratings,
    knockout_date = tournament_knockout_date,
    n_knockout_sim = n_match_sim,
    knockout_route_estimator = knockout_route_estimator,
    n_workers = n_workers
  )
  stage_probabilities <- group_data$stage_probabilities
  champion_probabilities <- stage_probabilities[order(-stage_probabilities$champion_probability), c("team", "display_team", "group", "champion_probability")]
  bracket_paths <- build_bracket_paths(
    group_data$group_probabilities,
    stage_probabilities,
    knockout_date = tournament_knockout_date,
    n_knockout_sim = n_match_sim,
    seed = seed + 2,
    knockout_route_estimator = knockout_route_estimator,
    elo_ratings_path = elo_ratings_path,
    ...
  )
  bracket_prematch_archive <- update_dashboard_bracket_prematch_forecast_archive(
    bracket_paths = bracket_paths,
    path = bracket_prematch_forecasts_path,
    generated_at = generated_at,
    feature_cutoff_date = feature_cutoff_date,
    actual_results_cutoff_date = actual_results_cutoff_date
  )
  bracket_paths <- attach_dashboard_bracket_prematch_forecasts(
    bracket_paths = bracket_paths,
    prematch_archive = bracket_prematch_archive
  )
  top_scorelines <- match_data$scoreline_distributions[match_data$scoreline_distributions$rank <= 5, ]
  tm_metadata <- read_transfermarkt_dashboard_metadata(
    metadata_path = transfermarkt_metadata_path,
    snapshot_path = transfermarkt_snapshot_path
  )
  benchmark_summary <- read_euro2024_benchmark_summary(euro2024_metrics_path)
  xg_usage_summary <- read_xg_feature_usage_summary(xg_feature_usage_audit_path)
  payload <- list(
    metadata = list(
      title = "xGelo 2026 World Cup Forecast",
      generated_at = generated_at,
      model_version = model_version,
      feature_cutoff_date = as.character(feature_cutoff_date),
      precompute_knockout_routes = isTRUE(precompute_knockout_routes),
      precompute_route_workers = if (isTRUE(precompute_knockout_routes)) {
        normalise_dashboard_workers(precompute_route_workers, length(groups$team) * (length(groups$team) - 1))
      } else {
        0L
      },
      knockout_route_method = route_method,
      knockout_route_max_goals = route_max_goals,
      transfermarkt_snapshot_path = tm_metadata$snapshot_path,
      transfermarkt_snapshot_checksum = tm_metadata$snapshot_md5,
      transfermarkt_snapshot_modified_time = tm_metadata$snapshot_modified_time,
      euro2024_benchmark_summary = benchmark_summary,
      xg_feature_usage_summary = xg_usage_summary,
      completed_group_matches = completed_fixture_count,
      actual_results_cutoff_date = as.character(actual_results_cutoff_date),
      n_match_sim = n_match_sim,
      n_tournaments = n_tournaments,
      n_workers = normalise_dashboard_workers(n_workers, n_tournaments),
      format_note = "48 teams, 12 groups of four, top two plus eight best third-place teams reach the Round of 32.",
      fixture_source = "FIFA World Cup 2026 group-stage fixture schedule, cross-checked against FourFourTwo listing updated 2026-06-05.",
      caveat = if (completed_fixture_count > 0) {
        paste0(
          "In-tournament forecast: completed group matches are fixed at actual scores through ",
          as.character(actual_results_cutoff_date),
          ". Remaining fixtures are simulated from pre-match features; no injuries, lineups, or live state."
        )
      } else {
        "Pre-match forecast only. No injuries, lineups, or live state. Knockout ET/pens routes are an Elo tiebreak allocation of drawn 90-minute simulations."
      }
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

  if (isTRUE(baseline_comparison) && identical(model_version, "hybrid")) {
    baseline_payload <- build_worldcup_dashboard_data(
      groups_path = groups_path,
      schedule_path = schedule_path,
      output_dir = file.path(output_dir, "baseline"),
      n_match_sim = n_match_sim,
      n_tournaments = n_tournaments,
      seed = seed,
      n_workers = n_workers,
      elo_ratings_path = elo_ratings_path,
      elo_current_path = elo_current_path,
      model_version = "baseline",
      feature_cutoff_date = feature_cutoff_date,
      require_forecast_features = FALSE,
      forecast_features = NULL,
      forecast_features_path = NULL,
      precompute_knockout_routes = precompute_knockout_routes,
      precompute_route_workers = precompute_route_workers,
      route_method = route_method,
      route_max_goals = route_max_goals,
      transfermarkt_metadata_path = transfermarkt_metadata_path,
      transfermarkt_snapshot_path = transfermarkt_snapshot_path,
      euro2024_metrics_path = euro2024_metrics_path,
      actual_results_path = actual_results_path,
      actual_results_cutoff_date = actual_results_cutoff_date,
      prematch_forecasts_path = prematch_forecasts_path,
      baseline_comparison = FALSE,
      home_model_path = baseline_home_model_path,
      away_model_path = baseline_away_model_path
    )
    payload$model_comparison <- compute_worldcup_model_comparison(payload, baseline_payload)
  }

  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)
  json_path <- file.path(output_dir, "worldcup_dashboard_data.json")
  jsonlite::write_json(payload, json_path, pretty = TRUE, auto_unbox = TRUE, digits = 10)
  write.csv(match_data$match_forecasts, file.path(output_dir, "worldcup_match_forecasts.csv"), row.names = FALSE)
  write.csv(prematch_archive, prematch_forecasts_path, row.names = FALSE)
  write.csv(bracket_prematch_archive, bracket_prematch_forecasts_path, row.names = FALSE)
  write.csv(group_data$group_probabilities, file.path(output_dir, "worldcup_group_probabilities.csv"), row.names = FALSE)
  write.csv(stage_probabilities, file.path(output_dir, "worldcup_stage_probabilities.csv"), row.names = FALSE)
  write.csv(bracket_paths, file.path(output_dir, "worldcup_bracket_paths.csv"), row.names = FALSE)
  if (!is.null(payload$model_comparison)) {
    write.csv(payload$model_comparison$team_deltas, file.path(output_dir, "worldcup_team_model_deltas.csv"), row.names = FALSE)
    write.csv(payload$model_comparison$match_deltas, file.path(output_dir, "worldcup_match_model_deltas.csv"), row.names = FALSE)
  }
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
<link rel="icon" href="data:image/svg+xml,%3Csvg xmlns=%27http://www.w3.org/2000/svg%27 viewBox=%270 0 32 32%27%3E%3Crect width=%2732%27 height=%2732%27 fill=%27%231d1d1f%27/%3E%3Ccircle cx=%2716%27 cy=%2716%27 r=%279%27 fill=%27%23fff%27/%3E%3Cpath d=%27M16 7v18M7 16h18%27 stroke=%27%233573a8%27 stroke-width=%272%27/%3E%3C/svg%3E">
<style>
:root{--ink:#1d1d1f;--muted:#666;--line:#d8d8d8;--paper:#f7f6f2;--panel:#fff;--blue:#3573a8;--blue-dark:#24577e;--blue-soft:#eef6fb;--gold:#d29d2b;--green:#3b8754}
*{box-sizing:border-box}body{margin:0;background:var(--paper);color:var(--ink);font-family:Arial,Helvetica,sans-serif;font-size:14px;line-height:1.4}
header{padding:22px 24px 14px;border-bottom:1px solid var(--line);background:#fff}
h1{margin:0;font-size:30px;font-weight:700;line-height:1.05;letter-spacing:0}
.subhead{margin-top:8px;max-width:980px;color:#444}.subhead a{color:var(--blue);font-weight:700;text-decoration:none}.subhead a:hover{text-decoration:underline}.meta{margin-top:10px;color:var(--muted);font-size:12px}
main{padding:18px 24px 32px}.tabs{display:flex;gap:6px;flex-wrap:wrap;margin-bottom:16px}.tab{border:1px solid var(--line);background:#fff;padding:8px 10px;cursor:pointer;font-weight:700}.tab.active{border-color:var(--ink);background:var(--ink);color:#fff}
.toolbar{display:flex;gap:8px;flex-wrap:wrap;margin:10px 0 18px}.toolbar input,.toolbar select{border:1px solid var(--line);background:#fff;padding:8px;min-width:180px}
.hero{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:10px;margin-bottom:18px}.metric{background:#fff;border-top:3px solid var(--blue);padding:12px;min-height:82px}.metric .label{font-size:12px;color:var(--muted);text-transform:uppercase}.metric .value{font-size:24px;font-weight:700;margin-top:4px}.metric .note{font-size:12px;color:var(--muted)}
.section{display:none}.section.active{display:block}.grid-groups{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:14px}.group-box,.match-card,.team-card,.bracket-game{background:#fff;border:1px solid var(--line);padding:10px}.group-box{overflow-x:auto}
.group-box h2,.panel-title{font-size:15px;margin:0 0 8px;font-weight:700}.group-table{min-width:570px;border-collapse:separate;border-spacing:3px}table{width:100%;border-collapse:collapse}th,td{padding:5px 4px;border-bottom:1px solid #eee;text-align:left;font-size:12px}th{color:#555;font-weight:700}.num{text-align:right;font-variant-numeric:tabular-nums}
.group-table th,.group-table td{border-bottom:0}.group-table th{text-align:center}.group-table th:first-child{text-align:left}.group-table th.xpts-head{font-size:11px;line-height:1.1}.team-cell{min-width:150px}.team-ident{display:flex;align-items:center;gap:9px;font-weight:700}.team-flag{font-size:25px;line-height:1}.team-name{font-size:15px;line-height:1.15}.xpts-cell{width:48px;text-align:center;font-size:15px;font-variant-numeric:tabular-nums}.heat-cell{position:relative;width:58px;height:50px;text-align:center;border-radius:8px;background:rgba(53,115,168,var(--heat));color:#163c5d;font-weight:800;font-size:15px;font-variant-numeric:tabular-nums;overflow:hidden}.heat-cell.strong{color:#fff}.heat-cell::after{content:"";position:absolute;left:9px;bottom:8px;width:calc(var(--prob) * (100% - 18px));height:5px;border-radius:6px;background:currentColor;opacity:.72}.heat-cell .heat-val{position:relative;z-index:1}.heat-cell.qual{background:rgba(47,139,183,var(--heat))}.heat-cell.third{background:rgba(53,115,168,var(--heat))}
.probbar{height:7px;background:#eee;position:relative;margin-top:3px}.probbar span{display:block;height:100%;background:var(--blue)}
.match-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px}.match-title{font-weight:700;font-size:15px}.match-meta{font-size:12px;color:var(--muted);margin:2px 0 8px}.wdl{display:flex;height:10px;margin:8px 0;background:#eee}.wdl span:nth-child(1){background:var(--blue)}.wdl span:nth-child(2){background:var(--gold)}.wdl span:nth-child(3){background:var(--green)}
.chips{display:flex;gap:6px;flex-wrap:wrap;margin-top:8px}.chip{border:1px solid var(--line);padding:3px 6px;font-size:12px;background:#fafafa}.chip.primary{font-weight:800;background:var(--blue-soft);border-color:#b5c7d8;color:var(--blue-dark)}.prematch-forecast{margin-top:10px;padding-top:8px;border-top:1px solid #eee}.prematch-forecast .wdl{margin:5px 0}.scorelines{margin-top:10px}.scoreline-heading{font-size:11px;color:var(--muted);text-transform:uppercase;margin-bottom:5px}.scoreline-row{display:grid;grid-template-columns:38px minmax(90px,1fr) 44px;gap:7px;align-items:center;margin:4px 0;font-size:12px}.scoreline-score{font-weight:700;font-variant-numeric:tabular-nums}.scoreline-bar{height:9px;background:#eee;position:relative}.scoreline-fill{display:block;height:100%;min-width:2px}.scoreline-fill.home_win{background:var(--blue)}.scoreline-fill.draw{background:var(--gold)}.scoreline-fill.away_win{background:var(--green)}.scoreline-prob{text-align:right;color:#444;font-variant-numeric:tabular-nums}
.section.active{position:relative;z-index:1}#bracket.active{z-index:20}.bracket-inspector{display:none;position:fixed;z-index:5000;width:min(440px,calc(100vw - 28px));max-height:calc(100vh - 28px);overflow:auto;background:#fff;border:1px solid var(--line);border-left:3px solid var(--blue);padding:12px;box-shadow:0 16px 38px rgba(17,38,56,.24)}.bracket-inspector.open{display:block}.bracket-inspector-head{display:flex;justify-content:space-between;gap:12px;align-items:flex-start;flex-wrap:wrap}.bracket-inspector h2{font-size:15px;margin:0}.bracket-inspector-note{font-size:12px;color:var(--muted)}.bracket-inspector-close{border:1px solid var(--line);background:#fff;padding:3px 7px;font-size:12px;cursor:pointer}.bracket-inspector-legend{margin-top:7px;font-size:12px;color:#34495b}.bracket-forecast-detail{margin-top:10px;padding-top:10px;border-top:1px solid #e9edf1}.bracket-empty-detail{margin-top:8px;color:var(--muted)}.bracket-wrap{overflow-x:auto;overflow-y:visible;padding-bottom:18px;position:relative}.bracket{position:relative;isolation:isolate;display:grid;grid-template-columns:repeat(6,260px);grid-template-rows:repeat(33,58px);column-gap:220px;min-width:2720px;padding:34px 20px 30px}.bracket-link-svg{position:absolute;inset:0;pointer-events:none;z-index:1}.bracket-link{fill:none;stroke:#c5beb2;stroke-width:2}.bracket-link.projected-path{stroke:var(--blue);stroke-width:3}.bracket-link.champion{stroke:var(--blue-dark);stroke-width:4}.bracket-link.hover-path{stroke:var(--green);stroke-width:4}.bracket-link-label{position:absolute;z-index:4;min-width:170px;padding:4px 7px;background:#fff;border:1px solid #c5beb2;font-size:12px;color:#333;white-space:nowrap;box-shadow:0 1px 3px rgba(0,0,0,.12);transform:translateY(8px);cursor:pointer}.bracket-link-label.projected-path{border-color:var(--blue);color:#111;font-weight:700}.bracket-link-label.champion{border-color:var(--blue-dark);font-weight:700}.bracket-link-label.hover-path{border-color:var(--green);color:#174226;font-weight:800;box-shadow:0 3px 10px rgba(59,135,84,.22)}.bracket-link-label.selected{outline:2px solid var(--ink);outline-offset:2px}.bracket-round-title{font-size:13px;font-weight:700;color:#444;align-self:end}.bracket-game{position:relative;z-index:3;min-height:104px;padding:10px;border-left:3px solid #d6d0c6;cursor:pointer;transition:box-shadow .12s ease,border-color .12s ease,opacity .12s ease}.bracket-game.projected{border-left-color:var(--blue)}.bracket-game.champion{border-left-color:var(--blue-dark);background:var(--blue-soft)}.bracket-game.selected{outline:2px solid var(--ink);outline-offset:2px;box-shadow:0 6px 18px rgba(29,29,31,.16)}.bracket-game.hover-path{border-left-color:var(--green);box-shadow:0 5px 16px rgba(59,135,84,.18)}.bracket.is-hovering .bracket-game:not(.hover-path){opacity:.68}.bracket.is-hovering .bracket-link:not(.hover-path){opacity:.34}.bracket.is-hovering .bracket-link-label:not(.hover-path){opacity:.58}.bracket-id{display:flex;justify-content:space-between;gap:8px;font-size:11px;color:var(--muted);margin-bottom:6px}.bracket-champion{font-weight:700;margin-top:6px}.bracket-prob{font-size:12px;color:#444}.bracket-team-target{display:inline-block;cursor:pointer}.bracket-team-target:hover,.bracket-team-target:focus{color:var(--blue-dark);text-decoration:underline}.tooltip-kicker{font-size:10px;line-height:1;text-transform:uppercase;color:var(--muted);letter-spacing:0;font-weight:700}.tooltip-title{margin-top:5px;font-size:15px;font-weight:800;color:var(--ink)}.tooltip-title-team.slot1{color:var(--blue-dark)}.tooltip-title-team.slot2{color:#2f7a49}.tooltip-vs{color:var(--muted);font-weight:700}.tooltip-legend-title{margin-top:7px;font-size:10px;text-transform:uppercase;color:var(--muted);font-weight:800}.tooltip-legend{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:6px;margin-top:4px}.tooltip-legend-item{display:flex;align-items:center;gap:5px;min-width:0;padding:4px 5px;background:#f7f9fb;border:1px solid #e4eaf0;font-size:10px;font-weight:700;color:#3d4d5b}.legend-dot{width:9px;height:9px;flex:0 0 9px}.legend-dot.slot1{background:var(--blue)}.legend-dot.draw{background:var(--gold)}.legend-dot.slot2{background:var(--green)}.tooltip-legend-item span:last-child{overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.tooltip-winner{display:flex;justify-content:space-between;gap:10px;margin-top:9px;padding:8px;background:var(--blue-soft);border-left:3px solid var(--blue);font-size:13px}.tooltip-winner span{font-weight:800;color:var(--blue-dark);font-variant-numeric:tabular-nums}.tooltip-section{margin-top:10px}.tooltip-section-title{font-size:10px;text-transform:uppercase;color:var(--muted);font-weight:800;margin-bottom:5px}.tooltip-advance-row{display:grid;grid-template-columns:minmax(90px,1fr) 48px 48px 52px;gap:6px;align-items:center;padding:5px 0;border-bottom:1px solid #eef0f2;font-size:12px}.tooltip-advance-row.slot1{border-left:3px solid var(--blue);padding-left:6px}.tooltip-advance-row.slot2{border-left:3px solid var(--green);padding-left:6px}.tooltip-advance-row.slot1 strong{color:var(--blue-dark)}.tooltip-advance-row.slot2 strong{color:#2f7a49}.tooltip-advance-row:last-child{border-bottom:0}.tooltip-advance-row strong{font-size:12px}.tooltip-advance-head{color:var(--muted);font-size:10px;text-transform:uppercase;font-weight:700}.tooltip-prob{text-align:right;font-weight:800;font-variant-numeric:tabular-nums}.score-tile-grid{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:6px}.score-tile{min-height:54px;padding:7px 5px;border-radius:8px;background:rgba(53,115,168,var(--heat));color:#163c5d;text-align:center;border:1px solid rgba(36,87,126,.12)}.score-tile.slot2_win{background:rgba(59,135,84,var(--heat));color:#174226}.score-tile.draw{background:rgba(210,157,43,var(--heat));color:#513a06}.score-tile.strong{color:#fff}.score-tile-prob{display:block;font-size:15px;font-weight:900;font-variant-numeric:tabular-nums}.score-tile-score{display:block;margin-top:3px;font-size:12px;font-weight:800}.tooltip-foot{display:flex;gap:7px;flex-wrap:wrap;margin-top:9px}.tooltip-pill{padding:3px 6px;background:#f5f7f9;border:1px solid #e3e8ed;font-size:11px;color:#34495b}.tooltip-pill.et-split{display:flex;align-items:center;gap:5px}.tooltip-et-team{font-weight:800}.tooltip-et-team.slot1{color:var(--blue-dark)}.tooltip-et-team.slot2{color:#2f7a49}.tooltip-et-dot{width:8px;height:8px;flex:0 0 8px}.tooltip-et-dot.slot1{background:var(--blue)}.tooltip-et-dot.slot2{background:var(--green)}.slot{display:flex;justify-content:space-between;gap:8px;padding:4px 0;border-bottom:1px solid #eee}.slot:last-child{border-bottom:0}.slot small{color:var(--muted);white-space:nowrap}.bracket-slot-target{position:relative}.bracket-slot-target::before{content:"";position:absolute;left:-13px;top:50%;width:7px;border-top:2px solid #c8c1b5}
.team-layout{display:grid;grid-template-columns:260px 1fr;gap:14px}.team-list{background:#fff;border:1px solid var(--line);max-height:640px;overflow:auto}.team-row{display:flex;justify-content:space-between;border-bottom:1px solid #eee;padding:8px;cursor:pointer}.team-row.active{background:#f0eee7;font-weight:700}.team-detail{background:#fff;border:1px solid var(--line);padding:12px}
details{background:#fff;border:1px solid var(--line);padding:10px;margin-top:18px}summary{font-weight:700;cursor:pointer}
@media(max-width:1180px){.hero{grid-template-columns:repeat(3,minmax(0,1fr))}}
@media(max-width:980px){.hero{grid-template-columns:repeat(2,minmax(0,1fr))}.grid-groups,.match-grid{grid-template-columns:1fr}.team-layout{grid-template-columns:1fr}.bracket{min-width:2720px}}
@media(max-width:560px){main,header{padding-left:14px;padding-right:14px}.hero{grid-template-columns:1fr}h1{font-size:24px}}
</style>
</head>
<body>
<header><h1>xGelo 2026 World Cup Forecast</h1><div class="subhead" id="subhead"></div><div class="meta" id="meta"></div></header>
<main>
<div class="hero" id="hero"></div>
<div class="tabs"><button class="tab active" data-tab="groups">Groups</button><button class="tab" data-tab="matches">Matches</button><button class="tab" data-tab="bracket">Bracket</button><button class="tab" data-tab="teams">Teams</button></div>
<section id="groups" class="section active"><div class="grid-groups" id="groupsGrid"></div></section>
<section id="matches" class="section"><div class="toolbar"><input id="matchSearch" placeholder="Search team"><select id="groupFilter"><option value="">All groups</option></select></div><div class="match-grid" id="matchesGrid"></div></section>
<section id="bracket" class="section"><div class="bracket-inspector" id="bracketInspector" aria-live="polite"></div><div class="bracket-wrap"><div class="bracket" id="bracketGrid"></div></div></section>
<section id="teams" class="section"><div class="toolbar"><input id="teamSearch" placeholder="Search team"></div><div class="team-layout"><div class="team-list" id="teamList"></div><div class="team-detail" id="teamDetail"></div></div></section>
<details open><summary>Methodology</summary><p>xGelo estimates match goal distributions, simulates scorelines, derives win/draw/loss probabilities, and then samples full tournaments. Completed World Cup group matches are fixed at their actual scores; remaining fixtures are simulated from team Elo strength, leakage-safe Transfermarkt player-pool valuation, and weighted historical goal ability. xG/form is currently not used because international rolling-form coverage is too sparse. The combined model is the default because it improved EURO 2024 Brier score, log loss, and ranked probability score without materially hurting draw calibration. Knockout rounds resolve each simulated bracket directly from the simulated group table, derive 90-minute route probabilities from the goal-model score distribution, and allocate drawn 90-minute probability mass to ET/pens advancement by Elo tiebreak share.</p></details>
<details><summary>Data Credits</summary><p>This dashboard builds on open football data projects. Historical international results come from <a href="https://github.com/martj42/international_results" target="_blank" rel="noopener">martj42/international_results</a>. Event-level shot data used for xG training comes from <a href="https://github.com/statsbomb/open-data" target="_blank" rel="noopener">StatsBomb Open Data</a>, which is available under StatsBomb Open Data terms for non-commercial analytical use. Player-pool valuation features use a local snapshot of <a href="https://github.com/dcaribou/transfermarkt-datasets" target="_blank" rel="noopener">dcaribou/transfermarkt-datasets</a>. The 2026 World Cup group seeds and fixture schedule are manually maintained in this repository and cross-checked against public FIFA schedule listings.</p></details>
</main>
<script id="dashboard-data" type="application/json">', json_text, '</script>
<script>
const data = JSON.parse(document.getElementById("dashboard-data").textContent);
const pct = v => v == null || Number.isNaN(v) ? "" : (100 * Number(v)).toFixed(1) + "%";
const pp = v => v == null || Number.isNaN(v) ? "" : (100 * Number(v)).toFixed(1) + " pp";
const intFmt = v => v == null || Number.isNaN(Number(v)) ? "" : Number(v).toLocaleString("en-US");
const num = v => Number(v).toFixed(2);
const maybeNum = v => v == null || Number.isNaN(Number(v)) ? "" : Number(v).toFixed(2);
const esc = s => String(s == null ? "" : s).replace(/[&<>"\']/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;","\\"":"&quot;","\'":"&#39;"}[c]));
const by = (rows, key) => rows.reduce((acc, row) => ((acc[row[key]] ||= []).push(row), acc), {});
const pctNum = v => v == null || Number.isNaN(v) ? "" : (100 * Number(v)).toFixed(1);
const hasPrematchForecast = r => {
  const flag = r.prematch_forecast_available === true || r.prematch_forecast_available === "TRUE" || r.prematch_forecast_available === "true";
  return flag && r.prematch_win_probability != null && !Number.isNaN(Number(r.prematch_win_probability));
};
const prematchForecastChips = r => hasPrematchForecast(r)
  ? `<div class="prematch-forecast"><div class="scoreline-heading">Pre-match forecast</div><div class="wdl"><span style="width:${100*r.prematch_win_probability}%"></span><span style="width:${100*r.prematch_draw_probability}%"></span><span style="width:${100*r.prematch_loss_probability}%"></span></div><div class="chips"><span class="chip">${esc(r.home_display)} ${pct(r.prematch_win_probability)}</span><span class="chip">Draw ${pct(r.prematch_draw_probability)}</span><span class="chip">${esc(r.away_display)} ${pct(r.prematch_loss_probability)}</span><span class="chip primary">xG ${maybeNum(r.prematch_home_goals_expected)}-${maybeNum(r.prematch_away_goals_expected)}</span><span class="chip">Top exact ${esc(r.prematch_most_likely_score || "")} (${pct(r.prematch_most_likely_score_probability)})</span></div></div>`
  : "";
const prematchForecastText = r => hasPrematchForecast(r)
  ? `pre-match ${esc(r.home_display)} ${pct(r.prematch_win_probability)} / Draw ${pct(r.prematch_draw_probability)} / ${esc(r.away_display)} ${pct(r.prematch_loss_probability)} | xG ${maybeNum(r.prematch_home_goals_expected)}-${maybeNum(r.prematch_away_goals_expected)}`
  : "";
const fifaToIso2 = {
  ALG:"DZ", ARG:"AR", AUS:"AU", AUT:"AT", BEL:"BE", BIH:"BA", BRA:"BR", CAN:"CA",
  CIV:"CI", COD:"CD", COL:"CO", CPV:"CV", CRO:"HR", CUW:"CW", CZE:"CZ", ECU:"EC",
  EGY:"EG", ENG:"GB", ESP:"ES", FRA:"FR", GER:"DE", GHA:"GH", HAI:"HT", IRN:"IR",
  IRQ:"IQ", JOR:"JO", JPN:"JP", KOR:"KR", KSA:"SA", MAR:"MA", MEX:"MX", NED:"NL",
  NOR:"NO", NZL:"NZ", PAN:"PA", PAR:"PY", POR:"PT", QAT:"QA", RSA:"ZA", SCO:"GB",
  SEN:"SN", SUI:"CH", SWE:"SE", TUN:"TN", TUR:"TR", URU:"UY", USA:"US", UZB:"UZ"
};
function flagEmoji(code){
  const iso = fifaToIso2[code] || code;
  if (!/^[A-Z]{2}$/.test(iso)) return "";
  return String.fromCodePoint(...[...iso].map(c => 127397 + c.charCodeAt(0)));
}
function heatCell(value, className = ""){
  const prob = Number(value);
  const heat = Math.max(0.10, Math.min(0.92, 0.12 + prob * 0.78));
  const strong = prob >= 0.55 ? " strong" : "";
  return `<td class="heat-cell ${className}${strong}" style="--heat:${heat.toFixed(3)};--prob:${Math.max(0, Math.min(1, prob)).toFixed(3)}"><span class="heat-val">${pctNum(prob)}</span></td>`;
}
function finiteProb(value){
  const prob = Number(value);
  return Number.isFinite(prob) ? prob : null;
}
function parseTopScorelines(label){
  if (!label) return [];
  return String(label).split("|").map(part => {
    const match = part.trim().match(/^([0-9]+-[0-9]+)\\s+([0-9.]+)%$/);
    if (!match) return null;
    return {scoreline: match[1], probability: Number(match[2]) / 100};
  }).filter(Boolean);
}
function scoreOutcome(scoreline){
  const goals = String(scoreline).split("-").map(Number);
  if (goals.length !== 2 || goals.some(Number.isNaN)) return "";
  if (goals[0] > goals[1]) return "slot1_win";
  if (goals[0] < goals[1]) return "slot2_win";
  return "draw";
}
function scoreTileGrid(label){
  const rows = parseTopScorelines(label).slice(0,5);
  if (!rows.length) return "";
  const maxProb = Math.max(...rows.map(row => row.probability), 0.01);
  return `<div class="score-tile-grid">${rows.map(row => {
    const heat = Math.max(0.18, Math.min(0.92, 0.18 + (row.probability / maxProb) * 0.62));
    const strong = heat >= 0.58 ? " strong" : "";
    return `<div class="score-tile ${scoreOutcome(row.scoreline)}${strong}" style="--heat:${heat.toFixed(3)}"><span class="score-tile-prob">${pct(row.probability)}</span><span class="score-tile-score">${esc(row.scoreline)}</span></div>`;
  }).join("")}</div>`;
}
function hasBracketPrematchForecast(g){
  const flag = g && (g.prematch_forecast_available === true || g.prematch_forecast_available === "TRUE" || g.prematch_forecast_available === "true");
  return flag && g.prematch_projected_winner_match_probability != null && !Number.isNaN(Number(g.prematch_projected_winner_match_probability));
}
function bracketPrematchHtml(g){
  if (!hasBracketPrematchForecast(g)) return "";
  const topScores = g.prematch_top_scorelines_label ? `<span class="tooltip-pill">Pre-game top scores ${esc(g.prematch_top_scorelines_label)}</span>` : "";
  return `<div class="tooltip-section"><div class="tooltip-section-title">Pre-game forecast</div><div class="tooltip-winner"><strong>Most likely advances: ${esc(g.prematch_projected_winner || "")}</strong><span>${pct(g.prematch_projected_winner_match_probability)}</span></div><div class="tooltip-foot"><span class="tooltip-pill">Mean goals ${maybeNum(g.prematch_slot1_expected_goals)}-${maybeNum(g.prematch_slot2_expected_goals)}</span><span class="tooltip-pill">Rounded ${esc(g.prematch_rounded_expected_score || "")}</span><span class="tooltip-pill">Top exact ${esc(g.prematch_most_likely_score || "")} (${pct(g.prematch_most_likely_score_probability)})</span>${topScores}</div></div>`;
}
function bracketForecastDetailHtml(g, projectedWinnerProbability){
  if (!g || !g.slot2_label) return "";
  const slot1Name = g.slot1_display || g.slot1_label;
  const slot2Name = g.slot2_display || g.slot2_label;
  const slot1Adv = finiteProb(g.slot1_advancement_probability);
  const slot2Adv = finiteProb(g.slot2_advancement_probability);
  const slot1Reg = finiteProb(g.slot1_regulation_win_probability);
  const slot2Reg = finiteProb(g.slot2_regulation_win_probability);
  const slot1Late = finiteProb(g.slot1_extra_time_penalty_probability);
  const slot2Late = finiteProb(g.slot2_extra_time_penalty_probability);
  const drawAfter90 = finiteProb(g.draw_after_regulation_probability);
  const scoreTiles = scoreTileGrid(g.top_scorelines_label);
  const titleHtml = `<span class="tooltip-title-team slot1">${esc(slot1Name)}</span> <span class="tooltip-vs">vs</span> <span class="tooltip-title-team slot2">${esc(slot2Name)}</span>`;
  const legendHtml = `<div class="tooltip-legend-title">90 min score colors</div><div class="tooltip-legend"><div class="tooltip-legend-item"><span class="legend-dot slot1"></span><span>${esc(slot1Name)} win</span></div><div class="tooltip-legend-item"><span class="legend-dot draw"></span><span>Draw</span></div><div class="tooltip-legend-item"><span class="legend-dot slot2"></span><span>${esc(slot2Name)} win</span></div></div>`;
  const advanceRows = [
    ["slot1", slot1Name, slot1Adv, slot1Reg, slot1Late],
    ["slot2", slot2Name, slot2Adv, slot2Reg, slot2Late]
  ].map(row => `<div class="tooltip-advance-row ${row[0]}"><strong>${esc(row[1])}</strong><span class="tooltip-prob">${pct(row[2])}</span><span class="tooltip-prob">${pct(row[3])}</span><span class="tooltip-prob">${pct(row[4])}</span></div>`).join("");
  const conditional = drawAfter90 != null && drawAfter90 > 0 && g.slot1_tiebreak_probability != null && g.slot2_tiebreak_probability != null
    ? `<span class="tooltip-pill et-split">If ET/pens: <span class="tooltip-et-dot slot1"></span><span class="tooltip-et-team slot1">${esc(slot1Name)} ${pct(g.slot1_tiebreak_probability)}</span> / <span class="tooltip-et-dot slot2"></span><span class="tooltip-et-team slot2">${esc(slot2Name)} ${pct(g.slot2_tiebreak_probability)}</span></span>`
    : "";
  return `<div class="bracket-forecast-detail" role="region" aria-label="Bracket match forecast"><div class="tooltip-kicker">${esc(g.match_id)} | ${esc(g.round)}</div><div class="tooltip-title">${titleHtml}</div>${legendHtml}<div class="tooltip-winner"><strong>Most likely advances: ${esc(g.projected_winner || "")}</strong><span>${pct(projectedWinnerProbability)}</span></div>${bracketPrematchHtml(g)}<div class="tooltip-section"><div class="tooltip-section-title">Advance probability</div><div class="tooltip-advance-row tooltip-advance-head"><span>Team</span><span>Adv</span><span>90 min</span><span>ET/pens</span></div>${advanceRows}</div>${scoreTiles ? `<div class="tooltip-section"><div class="tooltip-section-title">Top exact 90 min scores</div>${scoreTiles}</div>` : ""}<div class="tooltip-foot"><span class="tooltip-pill">90 min mean goals ${maybeNum(g.slot1_expected_goals)}-${maybeNum(g.slot2_expected_goals)}</span><span class="tooltip-pill">Rounded ${esc(g.rounded_expected_score || "")}</span><span class="tooltip-pill">90 min draw ${pct(drawAfter90)}</span><span class="tooltip-pill">O2.5 ${pct(g.over_2_5_probability)}</span><span class="tooltip-pill">BTTS ${pct(g.both_teams_to_score_probability)}</span>${conditional}</div></div>`;
}
const modelDescription = (data.metadata.model_version || "baseline") === "hybrid"
  ? "using a combined Elo, Transfermarkt player-pool valuation, and historical goal-ability model"
  : "using the baseline Elo model";
const completedCount = Number(data.metadata.completed_group_matches || 0);
const progressText = completedCount > 0 ? `${completedCount} completed group matches fixed at actual scores; ` : "";
document.getElementById("subhead").innerHTML = `Built from ${intFmt(data.metadata.n_match_sim)} match simulations and ${intFmt(data.metadata.n_tournaments)} full tournament simulations ${modelDescription}. ${progressText}remaining probabilities are forecasts, while final scores are tournament state. Created by <a href="https://github.com/DavidZenz" target="_blank" rel="noopener">David Zenz</a>.`;
document.getElementById("meta").textContent = `Generated ${data.metadata.generated_at} | Feature cutoff ${data.metadata.feature_cutoff_date || "n/a"} | Actual results through ${data.metadata.actual_results_cutoff_date || "n/a"} | ${intFmt(data.metadata.n_match_sim)} match sims | ${intFmt(data.metadata.n_tournaments)} full tournament sims | ${data.metadata.caveat}`;
function renderHero(){
  const champs = data.champion_probabilities.slice(0,3).map(r => `${r.display_team} ${pct(r.champion_probability)}`).join(" | ");
  const groupRows = data.group_probabilities;
  const topGroup = [...groupRows].sort((a,b)=>b.group_win_probability-a.group_win_probability)[0];
  const open = Object.values(by(groupRows,"group")).map(rows => {
    const winProbs = rows.map(row => Number(row.group_win_probability));
    return {group: rows[0].group, spread: Math.max(...winProbs) - Math.min(...winProbs)};
  }).sort((a,b)=>a.spread-b.spread)[0];
  const closestRace = Object.values(by(groupRows,"group")).map(rows => {
    const sorted = [...rows].sort((a,b)=>b.group_win_probability-a.group_win_probability);
    return {group: rows[0].group, margin: sorted[0].group_win_probability - sorted[1].group_win_probability};
  }).sort((a,b)=>a.margin-b.margin)[0];
  const finalPath = data.bracket_paths.find(r => r.match_id === "M104");
  const finalTeams = finalPath ? `${finalPath.slot1_display} vs ${finalPath.slot2_display}` : data.stage_probabilities.slice().sort((a,b)=>b.final_probability-a.final_probability).slice(0,2).map(r=>r.display_team).join(" vs ");
  document.getElementById("hero").innerHTML = [
    ["Top title chances", champs, "Full tournament simulations"],
    ["Likely final", finalTeams, "Highest final probabilities"],
    ["Strongest group favorite", `${topGroup.display_team} (${topGroup.group})`, pct(topGroup.group_win_probability)],
    ["Closest group-win race", `Group ${closestRace.group}`, `Leader margin ${pp(closestRace.margin)}`],
    ["Most open group", `Group ${open.group}`, `Win spread ${pp(open.spread)}`]
  ].map(m => `<div class="metric"><div class="label">${esc(m[0])}</div><div class="value">${esc(m[1])}</div><div class="note">${esc(m[2])}</div></div>`).join("");
}
function renderGroups(){
  const probs = by(data.group_probabilities, "group");
  const exp = by(data.expected_group_tables, "team");
  document.getElementById("groupsGrid").innerHTML = Object.keys(probs).sort().map(g => {
    const rows = probs[g].slice().sort((a,b)=>(a.projected_position ?? a.most_likely_position)-(b.projected_position ?? b.most_likely_position));
    return `<div class="group-box"><h2>Group ${g}</h2><table class="group-table"><thead><tr><th>Team</th><th class="num xpts-head">xPts<br>Avg</th><th class="num">1</th><th class="num">2</th><th class="num">3</th><th class="num">4</th><th class="num">R32</th><th class="num">3rd<br>Top 8</th></tr></thead><tbody>${rows.map(r => {
      const e = (exp[r.team] && exp[r.team][0]) || {};
      const code = r.fifa_code || "";
      return `<tr><td class="team-cell"><div class="team-ident"><span class="team-flag" aria-hidden="true">${esc(flagEmoji(code))}</span><span class="team-name">${esc(r.display_team)}</span></div></td><td class="xpts-cell">${Number(e.expected_points).toFixed(1)}</td>${heatCell(r.position_1_probability)}${heatCell(r.position_2_probability)}${heatCell(r.position_3_probability)}${heatCell(r.position_4_probability)}${heatCell(r.round_of_32_probability, "qual")}${heatCell(r.third_place_qual_probability, "third")}</tr>`;
    }).join("")}</tbody></table></div>`;
  }).join("");
}
function renderMatches(){
  const search = document.getElementById("matchSearch").value.toLowerCase();
  const group = document.getElementById("groupFilter").value;
  const scorelines = by(data.scoreline_distributions, "match_id");
  const rows = data.match_forecasts.filter(r => (!group || r.group === group) && (`${r.home_display} ${r.away_display}`.toLowerCase().includes(search)));
  document.getElementById("matchesGrid").innerHTML = rows.map(r => {
    const completed = r.is_completed === true || r.is_completed === "TRUE" || r.match_status === "final";
    const topRows = (scorelines[r.match_id] || []).slice(0,5);
    const maxProb = Math.max(...topRows.map(s => Number(s.probability)), 0.01);
    const topBars = topRows.map(s => {
      const relWidth = Math.max(4, 100 * Number(s.probability) / maxProb);
      return `<div class="scoreline-row"><div class="scoreline-score">${esc(s.scoreline)}</div><div class="scoreline-bar"><span class="scoreline-fill ${esc(s.outcome)}" style="width:${relWidth}%"></span></div><div class="scoreline-prob">${pct(s.probability)}</div></div>`;
    }).join("");
    const statusChips = completed
      ? `<div class="chips"><span class="chip primary">Final ${esc(r.actual_score)}</span><span class="chip">Fixed in simulations</span></div>`
      : `<div class="chips"><span class="chip primary">Expected goals ${num(r.home_goals_expected)}-${num(r.away_goals_expected)}</span><span class="chip">Rounded goals ${esc(r.rounded_expected_score)}</span><span class="chip">O2.5 ${pct(r.over_2_5_probability)}</span><span class="chip">BTTS ${pct(r.both_teams_to_score_probability)}</span><span class="chip">Top exact score ${esc(r.most_likely_score)} (${pct(r.most_likely_score_probability)})</span></div>`;
    const heading = completed ? "Final score" : "Top exact scorelines";
    return `<div class="match-card"><div class="match-title">${esc(r.home_display)} vs ${esc(r.away_display)}</div><div class="match-meta">Group ${esc(r.group)} | ${esc(r.date)} ${esc(r.kickoff_local)} local | ${esc(r.venue_name)}, ${esc(r.host_city)}</div><div class="wdl"><span style="width:${100*r.win_probability}%"></span><span style="width:${100*r.draw_probability}%"></span><span style="width:${100*r.loss_probability}%"></span></div><div class="chips"><span class="chip">${esc(r.home_display)} ${pct(r.win_probability)}</span><span class="chip">Draw ${pct(r.draw_probability)}</span><span class="chip">${esc(r.away_display)} ${pct(r.loss_probability)}</span></div>${statusChips}${completed ? prematchForecastChips(r) : ""}<div class="scorelines"><div class="scoreline-heading">${heading}</div>${topBars}</div></div>`;
  }).join("");
}
let selectedBracketMatchId = null;
let selectedBracketAnchor = null;
let activeBracketHoverTeam = "";
const bracketRowsById = () => Object.fromEntries(data.bracket_paths.map(row => [row.match_id, row]));
function defaultBracketMatchId(){
  const final = data.bracket_paths.find(r => r.match_id === "M104");
  if (final) return final.match_id;
  const championPath = data.bracket_paths.find(r => r.round !== "Champion" && (r.projected_champion_path === true || r.projected_champion_path === "TRUE" || r.projected_champion_path === "true"));
  return championPath ? championPath.match_id : (data.bracket_paths[0] && data.bracket_paths[0].match_id);
}
function bracketHoverLegend(){
  if (activeBracketHoverTeam) {
    return `Hover highlight: ${esc(activeBracketHoverTeam)} projected route. The terminal match stays highlighted, but no line continues after a projected exit.`;
  }
  return "Default highlight: projected champion path. Hover a country to trace its projected route; click a match for forecasts.";
}
function renderBracketInspector(g){
  const panel = document.getElementById("bracketInspector");
  if (!panel) return;
  if (!g) {
    panel.classList.remove("open");
    panel.innerHTML = "";
    return;
  }
  const projectedWinnerProbability = g.projected_winner_match_probability ?? g.projected_winner_stage_probability;
  const detail = bracketForecastDetailHtml(g, projectedWinnerProbability) || `<div class="bracket-empty-detail">${esc(g.projected_winner || "")} is projected champion. Click a knockout match to inspect the route forecast.</div>`;
  panel.innerHTML = `<div class="bracket-inspector-head"><div><h2>Bracket match details</h2><div class="bracket-inspector-note">${esc(g.match_id)} | ${esc(g.round)}</div></div><button class="bracket-inspector-close" type="button" aria-label="Close match details">Close</button><span class="chip primary">${esc(g.projected_winner || "Projected winner")} ${pct(projectedWinnerProbability)}</span></div><div class="bracket-inspector-legend">${bracketHoverLegend()}</div>${detail}`;
  panel.classList.add("open");
  const close = panel.querySelector(".bracket-inspector-close");
  if (close) close.onclick = event => {
    event.preventDefault();
    event.stopPropagation();
    closeBracketInspector();
  };
  bindBracketInspectorDismissal();
  positionBracketInspector(selectedBracketAnchor);
}
function positionBracketInspector(anchor){
  const panel = document.getElementById("bracketInspector");
  if (!panel || !panel.classList.contains("open")) return;
  const margin = 14;
  const gap = 10;
  const rect = anchor && anchor.getBoundingClientRect ? anchor.getBoundingClientRect() : {left: margin, right: margin, top: margin, bottom: margin};
  const width = panel.offsetWidth || 440;
  const height = panel.offsetHeight || 260;
  let left = rect.right + gap;
  if (left + width > window.innerWidth - margin) left = rect.left - width - gap;
  if (left < margin) left = Math.min(Math.max(rect.left, margin), Math.max(margin, window.innerWidth - width - margin));
  let top = rect.top;
  if (top + height > window.innerHeight - margin) top = window.innerHeight - height - margin;
  if (top < margin) top = margin;
  panel.style.left = `${left}px`;
  panel.style.top = `${top}px`;
}
function closeBracketInspector(){
  selectedBracketMatchId = null;
  selectedBracketAnchor = null;
  document.querySelectorAll(".bracket-game.selected,.bracket-link-label.selected").forEach(el => el.classList.remove("selected"));
  renderBracketInspector(null);
}
function isBracketMatchClickTarget(target){
  const grid = document.getElementById("bracketGrid");
  if (!grid || !target || !target.closest) return false;
  const label = target.closest(".bracket-link-label");
  const card = target.closest(".bracket-game");
  return Boolean((label && grid.contains(label)) || (card && grid.contains(card)));
}
function bindBracketInspectorDismissal(){
  if (window.bracketInspectorDismissBound) return;
  window.bracketInspectorDismissBound = true;
  document.addEventListener("click", event => {
    const panel = document.getElementById("bracketInspector");
    if (!panel || !panel.classList.contains("open")) return;
    const close = event.target.closest && event.target.closest(".bracket-inspector-close");
    if (close && panel.contains(close)) {
      event.preventDefault();
      closeBracketInspector();
      return;
    }
    if (panel.contains(event.target) || isBracketMatchClickTarget(event.target)) return;
    closeBracketInspector();
  });
  document.addEventListener("keydown", event => {
    if (event.key === "Escape") closeBracketInspector();
  });
}
function selectBracketMatch(matchId, anchor = null){
  const rows = bracketRowsById();
  const row = rows[matchId] || rows[defaultBracketMatchId()];
  if (!row) return;
  selectedBracketMatchId = row.match_id;
  selectedBracketAnchor = anchor || document.querySelector(`.bracket-link-label[data-source-match-id="${CSS.escape(row.match_id)}"]`) || document.querySelector(`.bracket-game[data-match-id="${CSS.escape(row.match_id)}"]`);
  document.querySelectorAll(".bracket-game.selected,.bracket-link-label.selected").forEach(el => el.classList.remove("selected"));
  document.querySelectorAll(`.bracket-game[data-match-id="${CSS.escape(row.match_id)}"],.bracket-link-label[data-source-match-id="${CSS.escape(row.match_id)}"]`).forEach(el => el.classList.add("selected"));
  renderBracketInspector(row);
}
function setBracketHoverTeam(team){
  const normalizedTeam = team || "";
  activeBracketHoverTeam = normalizedTeam;
  const grid = document.getElementById("bracketGrid");
  if (!grid) return;
  grid.classList.toggle("is-hovering", Boolean(normalizedTeam));
  document.querySelectorAll(".hover-path").forEach(el => el.classList.remove("hover-path"));
  if (normalizedTeam) {
    grid.querySelectorAll(".bracket-game").forEach(card => {
      const inMatch = card.dataset.slot1Team === normalizedTeam || card.dataset.slot2Team === normalizedTeam || card.dataset.projectedWinnerTeam === normalizedTeam;
      if (inMatch) card.classList.add("hover-path");
    });
    grid.querySelectorAll(".bracket-link,.bracket-link-label").forEach(el => {
      const projectedWinner = el.dataset.projectedWinnerTeam === normalizedTeam;
      const next = grid.querySelector(`.bracket-game[data-match-id="${CSS.escape(el.dataset.nextMatchId || "")}"]`);
      const entersNext = next && (
        next.dataset.slot1Team === normalizedTeam ||
        next.dataset.slot2Team === normalizedTeam ||
        next.dataset.projectedWinnerTeam === normalizedTeam
      );
      if (projectedWinner && entersNext) el.classList.add("hover-path");
    });
  }
  const selected = selectedBracketMatchId ? bracketRowsById()[selectedBracketMatchId] : null;
  if (selected) renderBracketInspector(selected);
}
function clearBracketHoverTeam(){
  setBracketHoverTeam("");
}
function bracketHoverTeamFromTarget(target, grid){
  const teamTarget = target.closest && target.closest(".bracket-team-target");
  if (teamTarget && grid.contains(teamTarget)) return teamTarget.dataset.team;
  const label = target.closest && target.closest(".bracket-link-label");
  if (label && grid.contains(label)) return label.dataset.projectedWinnerTeam;
  return "";
}
function bindBracketInteractions(){
  const grid = document.getElementById("bracketGrid");
  if (!grid || grid.dataset.bound === "true") return;
  grid.dataset.bound = "true";
  grid.addEventListener("pointerover", event => {
    const team = bracketHoverTeamFromTarget(event.target, grid);
    if (team) setBracketHoverTeam(team); else clearBracketHoverTeam();
  });
  grid.addEventListener("pointerleave", clearBracketHoverTeam);
  grid.addEventListener("focusin", event => {
    const team = bracketHoverTeamFromTarget(event.target, grid);
    if (team) setBracketHoverTeam(team); else clearBracketHoverTeam();
  });
  grid.addEventListener("focusout", event => {
    if (!grid.contains(event.relatedTarget)) clearBracketHoverTeam();
  });
  grid.addEventListener("click", event => {
    const label = event.target.closest && event.target.closest(".bracket-link-label");
    const card = event.target.closest && event.target.closest(".bracket-game");
    const matchId = label && grid.contains(label) ? label.dataset.sourceMatchId : card && grid.contains(card) ? card.dataset.matchId : "";
    if (matchId) selectBracketMatch(matchId, label || card);
  });
  grid.addEventListener("keydown", event => {
    if (event.key !== "Enter" && event.key !== " ") return;
    const label = event.target.closest && event.target.closest(".bracket-link-label");
    const card = event.target.closest && event.target.closest(".bracket-game");
    const matchId = label && grid.contains(label) ? label.dataset.sourceMatchId : card && grid.contains(card) ? card.dataset.matchId : "";
    if (matchId) {
      event.preventDefault();
      selectBracketMatch(matchId, label || card);
    }
  });
  if (!window.bracketOutsideHoverBound) {
    window.bracketOutsideHoverBound = true;
    document.addEventListener("pointerover", event => {
      const activeGrid = document.getElementById("bracketGrid");
      if (activeGrid && !activeGrid.contains(event.target)) clearBracketHoverTeam();
    });
    document.addEventListener("focusin", event => {
      const activeGrid = document.getElementById("bracketGrid");
      if (activeGrid && !activeGrid.contains(event.target)) clearBracketHoverTeam();
    });
    window.addEventListener("scroll", clearBracketHoverTeam, true);
    window.addEventListener("scroll", () => positionBracketInspector(selectedBracketAnchor), true);
    window.addEventListener("resize", () => positionBracketInspector(selectedBracketAnchor));
  }
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
    const slot1Probability = g.slot1_advancement_probability ?? g.slot1_probability;
    const slot2Probability = g.slot2_advancement_probability ?? g.slot2_probability;
    const projectedWinnerProbability = g.projected_winner_match_probability ?? g.projected_winner_stage_probability;
    const hasDetail = Boolean(bracketForecastDetailHtml(g, projectedWinnerProbability));
    const championPath = g.projected_champion_path === true || g.projected_champion_path === "TRUE" || g.projected_champion_path === "true";
    const gameClass = isChampion ? "champion" : `${championPath ? "projected" : ""}`;
    const slot1Class = slot1Source ? "slot bracket-slot-target" : "slot";
    const slot2Class = slot2Source ? "slot bracket-slot-target" : "slot";
    const slot1Team = g.slot1_team || "";
    const slot2Team = g.slot2_team || "";
    const slot1Name = g.slot1_display || g.slot1_label;
    const slot2Name = g.slot2_display || g.slot2_label;
    const slot1Target = slot1Team ? `<span class="bracket-team-target" tabindex="0" data-team="${esc(slot1Team)}" title="Hover to highlight ${esc(slot1Name)} path">${esc(slot1Name)}</span>` : `<span>${esc(slot1Name)}</span>`;
    const slot2Target = slot2Team ? `<span class="bracket-team-target" tabindex="0" data-team="${esc(slot2Team)}" title="Hover to highlight ${esc(slot2Name)} path">${esc(slot2Name)}</span>` : `<span>${esc(slot2Name)}</span>`;
    const slot2 = g.slot2_label ? `<div class="${slot2Class}" data-source-match-id="${esc(slot2Source)}">${slot2Target}<small>${pct(slot2Probability)}</small></div>` : "";
    const championText = isChampion ? `<div class="bracket-champion">${esc(winnerLabel)}: ${esc(g.projected_winner)}</div><div class="bracket-prob">Title ${pct(g.projected_winner_title_probability)}</div>` : "";
    return `<div class="bracket-game ${gameClass}" tabindex="0" role="button" title="Click for forecast" aria-label="Click for forecast: ${esc(g.match_id)} ${esc(g.round)}" data-match-id="${esc(g.match_id)}" data-next-match-id="${esc(g.next_match_id || "")}" data-winner-continues="${g.projected_winner_continues ? "true" : "false"}" data-champion-path="${championPath ? "true" : "false"}" data-slot1-team="${esc(slot1Team)}" data-slot2-team="${esc(slot2Team)}" data-projected-winner-team="${esc(g.projected_winner_team || "")}" data-projected-winner="${esc(g.projected_winner || "")}" data-match-probability="${pct(projectedWinnerProbability)}" data-route-label="${esc(g.projected_winner_route_label || "")}" data-has-detail="${hasDetail ? "true" : "false"}" data-stage-probability="${pct(g.projected_winner_stage_probability)}" data-title-probability="${pct(g.projected_winner_title_probability)}" style="grid-column:${col[g.round]};grid-row:${rows[g.match_id] + 1} / span 2;"><div class="bracket-id"><span>${esc(g.match_id)}</span><span>${esc(g.round)}</span></div>${isChampion ? championText : `<div class="${slot1Class}" data-source-match-id="${esc(slot1Source)}">${slot1Target}<small>${pct(slot1Probability)}</small></div>${slot2}`}</div>`;
  }).join("");
  document.getElementById("bracketGrid").innerHTML = `<svg class="bracket-link-svg" aria-hidden="true"></svg>${titles}${games}`;
  requestAnimationFrame(() => {
    drawBracketLinks();
    bindBracketInteractions();
    if (selectedBracketMatchId) selectBracketMatch(selectedBracketMatchId);
    else renderBracketInspector(null);
  });
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
    const mid = x1 + Math.max(48, (x2 - x1) / 2);
    const projectedPath = card.dataset.championPath === "true" ? " projected-path" : "";
    const champion = nextId === "Champion" ? " champion" : "";
    paths.push(`<path class="bracket-link${projectedPath}${champion}" data-source-match-id="${esc(card.dataset.matchId)}" data-next-match-id="${esc(nextId)}" data-projected-winner-team="${esc(card.dataset.projectedWinnerTeam || "")}" data-winner-continues="${esc(card.dataset.winnerContinues || "false")}" d="M${x1} ${y1} H${mid} V${y2} H${x2}"></path>`);
    const label = document.createElement("div");
    label.className = `bracket-link-label${projectedPath}${champion}`;
    label.tabIndex = 0;
    label.setAttribute("role", "button");
    label.setAttribute("title", "Click for forecast");
    label.setAttribute("aria-label", `Click for forecast: winner from ${card.dataset.matchId}`);
    label.dataset.sourceMatchId = card.dataset.matchId;
    label.dataset.nextMatchId = nextId;
    label.dataset.projectedWinnerTeam = card.dataset.projectedWinnerTeam || "";
    label.dataset.winnerContinues = card.dataset.winnerContinues || "false";
    label.style.left = `${x1 + 24}px`;
    label.style.top = `${y1}px`;
    label.innerHTML = `${esc(card.dataset.projectedWinner)} ${esc(card.dataset.matchProbability)}`;
    labels.push(label);
  });
  svg.innerHTML = paths.join("");
  labels.forEach(label => grid.appendChild(label));
  bindBracketInteractions();
  if (activeBracketHoverTeam) setBracketHoverTeam(activeBracketHoverTeam);
  if (selectedBracketMatchId) selectBracketMatch(selectedBracketMatchId);
}
function refreshBracketLinks(){
  drawBracketLinks();
  requestAnimationFrame(drawBracketLinks);
  window.setTimeout(drawBracketLinks, 50);
}
function renderTeams(selected){
  const search = document.getElementById("teamSearch").value.toLowerCase();
  const teams = data.stage_probabilities.slice().sort((a,b)=>b.champion_probability-a.champion_probability).filter(r => r.display_team.toLowerCase().includes(search));
  const current = selected || (teams[0] && teams[0].team);
  document.getElementById("teamList").innerHTML = teams.map(t => `<div class="team-row ${t.team===current?"active":""}" data-team="${esc(t.team)}"><span>${esc(t.display_team)}</span><span>${pct(t.champion_probability)}</span></div>`).join("");
  const team = data.stage_probabilities.find(t => t.team === current) || teams[0];
  if (!team) return;
  const matches = data.match_forecasts.filter(m => m.home_team === team.team || m.away_team === team.team);
  const roundOrder = {"Round of 32": 1, "Round of 16": 2, "Quarter-finals": 3, "Semi-finals": 4, "Final": 5, "Champion": 6};
  const routeRows = data.bracket_paths
    .filter(r => r.round !== "Champion" && (r.slot1_team === team.team || r.slot2_team === team.team))
    .sort((a,b) => (roundOrder[a.round] || 99) - (roundOrder[b.round] || 99));
  const isProjectedTeam = value => value === team.display_team || value === team.team;
  const teamScore = (score, isSlot1) => {
    if (!score || isSlot1) return score || "";
    const parts = String(score).split("-");
    return parts.length === 2 ? `${parts[1]}-${parts[0]}` : score;
  };
  const championRow = data.bracket_paths.find(r => r.round === "Champion" && isProjectedTeam(r.projected_winner));
  const routeHtml = routeRows.length > 0
    ? routeRows.map(r => {
      const isSlot1 = r.slot1_team === team.team;
      const opponent = isSlot1 ? (r.slot2_display || r.slot2_label) : (r.slot1_display || r.slot1_label);
      const advance = isSlot1 ? r.slot1_advancement_probability : r.slot2_advancement_probability;
      const regulation = isSlot1 ? r.slot1_regulation_win_probability : r.slot2_regulation_win_probability;
      const late = isSlot1 ? r.slot1_extra_time_penalty_probability : r.slot2_extra_time_penalty_probability;
      const projectedAdvance = isProjectedTeam(r.projected_winner);
      const status = projectedAdvance ? "Projected advance" : "Projected exit";
      return `<div class="slot"><span><strong>${esc(r.round)}</strong>: ${esc(team.display_team)} vs ${esc(opponent)}<br><small>${esc(status)} | 90 min win ${pct(regulation)} | ET/pens ${pct(late)} | rounded goals ${esc(teamScore(r.rounded_expected_score, isSlot1))}</small></span><small>${pct(advance)}</small></div>`;
    }).join("") + (championRow ? `<div class="slot"><span><strong>Champion</strong>: ${esc(team.display_team)}<br><small>Projected champion in the displayed bracket path</small></span><small>${pct(team.champion_probability)}</small></div>` : "")
    : `<div class="slot"><span>No projected knockout route in the displayed bracket path<br><small>Simulations still give ${esc(team.display_team)} a ${pct(team.round_of_32_probability)} Round-of-32 chance.</small></span><small>${pct(team.champion_probability)}</small></div>`;
  document.getElementById("teamDetail").innerHTML = `<h2>${esc(team.display_team)}</h2><p>Group ${esc(team.group)} | Title ${pct(team.champion_probability)} | Final ${pct(team.final_probability)} | Quarter-final ${pct(team.quarterfinal_probability)} | Round of 32 ${pct(team.round_of_32_probability)}</p><h3 class="panel-title">Group matches</h3>${matches.map(m => {
    const completed = m.is_completed === true || m.is_completed === "TRUE" || m.match_status === "final";
    const prematch = completed ? prematchForecastText(m) : "";
    const detail = completed ? `final ${esc(m.actual_score)} | fixed in simulations${prematch ? " | " + prematch : ""}` : `rounded ${esc(m.rounded_expected_score)} | top exact ${esc(m.most_likely_score)}`;
    const side = completed ? `Final ${esc(m.actual_score)}` : `xG ${num(m.home_goals_expected)}-${num(m.away_goals_expected)}`;
    return `<div class="slot"><span>${esc(m.home_display)} vs ${esc(m.away_display)}<br><small>${esc(m.date)} ${esc(m.kickoff_local)} local | ${esc(m.host_city)} | ${detail}</small></span><small>${side}</small></div>`;
  }).join("")}<h3 class="panel-title">Projected tournament path</h3>${routeHtml}`;
  document.querySelectorAll(".team-row").forEach(row => row.onclick = () => renderTeams(row.dataset.team));
}
document.querySelectorAll(".tab").forEach(btn => btn.onclick = () => {
  document.querySelectorAll(".tab").forEach(b=>b.classList.remove("active"));
  document.querySelectorAll(".section").forEach(s=>s.classList.remove("active"));
  clearBracketHoverTeam();
  btn.classList.add("active"); document.getElementById(btn.dataset.tab).classList.add("active");
  if (btn.dataset.tab === "bracket") refreshBracketLinks();
});
for (const g of "ABCDEFGHIJKL") document.getElementById("groupFilter").innerHTML += `<option value="${g}">Group ${g}</option>`;
document.getElementById("matchSearch").oninput = renderMatches;
document.getElementById("groupFilter").onchange = renderMatches;
document.getElementById("teamSearch").oninput = () => renderTeams();
window.addEventListener("resize", refreshBracketLinks);
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

#' Publish the World Cup dashboard into the GitHub Pages tree
#'
#' @export
publish_worldcup_dashboard_pages <- function(
    data_json_path = "outputs/dashboard/worldcup_dashboard_data.json",
    pages_dir = "docs/wc2026"
) {
  output_path <- file.path(pages_dir, "index.html")
  site_root <- dirname(pages_dir)
  if (!dir.exists(site_root)) dir.create(site_root, recursive = TRUE)
  writeLines("", file.path(site_root, ".nojekyll"))
  render_worldcup_dashboard(data_json_path = data_json_path, output_path = output_path)
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
    n_workers = default_dashboard_workers(),
    elo_ratings_path = "data/processed/elo_ratings.csv",
    elo_current_path = "data/processed/elo_current.csv",
    forecast_features = NULL,
    forecast_features_path = NULL,
    precompute_knockout_routes = NULL,
    precompute_route_workers = n_workers,
    route_method = c("analytic", "simulation"),
    route_max_goals = 10,
    ...
) {
  route_method <- match.arg(route_method)
  payload <- build_worldcup_dashboard_data(
    groups_path = groups_path,
    schedule_path = schedule_path,
    output_dir = output_dir,
    n_match_sim = n_match_sim,
    n_tournaments = n_tournaments,
    seed = seed,
    n_workers = n_workers,
    elo_ratings_path = elo_ratings_path,
    elo_current_path = elo_current_path,
    forecast_features = forecast_features,
    forecast_features_path = forecast_features_path,
    precompute_knockout_routes = precompute_knockout_routes,
    precompute_route_workers = precompute_route_workers,
    route_method = route_method,
    route_max_goals = route_max_goals,
    ...
  )
  output_path <- render_worldcup_dashboard(
    data_json_path = payload$paths$data_json,
    output_path = file.path(output_dir, "worldcup_forecast.html")
  )
  payload$paths$html <- output_path
  payload
}
