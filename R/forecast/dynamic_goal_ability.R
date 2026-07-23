#' Chronology-safe dynamic international goal ability
#'
#' Dynamic attack and defence effects are represented by decayed sufficient
#' statistics.  The global pseudo-exposure is fixed, so observed evidence can
#' decay continuously without changing the global prior.

.dynamic_goal_tuning_cache <- new.env(parent = emptyenv())

dynamic_goal_required_columns <- function(data, required, label) {
  missing <- setdiff(required, names(data))
  if (length(missing)) {
    stop(label, " missing required columns: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  invisible(TRUE)
}

dynamic_goal_date <- function(x, label) {
  value <- as.Date(x)
  if (length(value) != 1L || is.na(value)) {
    stop(label, " must be one non-missing date", call. = FALSE)
  }
  value
}

dynamic_goal_empty_team_rows <- function(team_ids) {
  team_ids <- sort(unique(as.character(team_ids)), method = "radix")
  data.frame(
    team_id = team_ids,
    GF = rep(0, length(team_ids)),
    GA = rep(0, length(team_ids)),
    W = rep(0, length(team_ids)),
    history_match_count = rep(0L, length(team_ids)),
    latest_source_date = as.Date(rep(NA_character_, length(team_ids))),
    stringsAsFactors = FALSE
  )
}

#' Initialize a dynamic goal state
#'
#' @param team_ids Stable team identifiers known at initialization.
#' @param global_goal_rate Positive global goals-per-team-match prior.
#' @param pseudo_exposure Positive fixed global-prior exposure.
#' @param as_of_date Exclusive state date.
#' @return A deterministic dynamic goal state.
#' @export
initialize_dynamic_goal_state <- function(
    team_ids,
    global_goal_rate,
    pseudo_exposure,
    as_of_date
) {
  team_ids <- as.character(team_ids)
  if (anyNA(team_ids) || any(!nzchar(team_ids))) {
    stop("team_ids must be non-missing stable identifiers", call. = FALSE)
  }
  global_goal_rate <- as.numeric(global_goal_rate)
  pseudo_exposure <- as.numeric(pseudo_exposure)
  if (length(global_goal_rate) != 1L || !is.finite(global_goal_rate) || global_goal_rate <= 0) {
    stop("global_goal_rate must be one positive finite value", call. = FALSE)
  }
  if (length(pseudo_exposure) != 1L || !is.finite(pseudo_exposure) || pseudo_exposure <= 0) {
    stop("pseudo_exposure must be one positive finite value", call. = FALSE)
  }

  structure(
    list(
      schema_version = "phase10-dynamic-goal-v1",
      global_goal_rate = global_goal_rate,
      pseudo_exposure = pseudo_exposure,
      as_of_date = dynamic_goal_date(as_of_date, "as_of_date"),
      teams = dynamic_goal_empty_team_rows(team_ids)
    ),
    class = "dynamic_goal_state"
  )
}

dynamic_goal_validate_state <- function(state) {
  if (!inherits(state, "dynamic_goal_state") || !is.list(state)) {
    stop("state must be a dynamic_goal_state", call. = FALSE)
  }
  dynamic_goal_required_columns(
    state$teams,
    c("team_id", "GF", "GA", "W", "history_match_count", "latest_source_date"),
    "state$teams"
  )
  if (anyDuplicated(state$teams$team_id)) stop("state team identifiers must be unique", call. = FALSE)
  if (any(!is.finite(state$teams$GF)) || any(state$teams$GF < 0) ||
      any(!is.finite(state$teams$GA)) || any(state$teams$GA < 0) ||
      any(!is.finite(state$teams$W)) || any(state$teams$W < 0)) {
    stop("state sufficient statistics must be finite and non-negative", call. = FALSE)
  }
  invisible(TRUE)
}

#' Decay observed dynamic evidence to a later date
#'
#' @param state Dynamic goal state.
#' @param to_date Date to which observed evidence is decayed.
#' @param half_life_days Fixed evidence half-life in days.
#' @return The decayed state; pseudo-exposure is unchanged.
#' @export
decay_dynamic_goal_state <- function(state, to_date, half_life_days = 730) {
  dynamic_goal_validate_state(state)
  to_date <- dynamic_goal_date(to_date, "to_date")
  half_life_days <- as.numeric(half_life_days)
  if (length(half_life_days) != 1L || !is.finite(half_life_days) || half_life_days <= 0) {
    stop("half_life_days must be one positive finite value", call. = FALSE)
  }
  elapsed <- as.numeric(to_date - state$as_of_date)
  if (elapsed < 0) stop("dynamic state cannot decay backwards in time", call. = FALSE)

  factor <- exp(-log(2) * elapsed / half_life_days)
  state$teams$GF <- state$teams$GF * factor
  state$teams$GA <- state$teams$GA * factor
  state$teams$W <- state$teams$W * factor
  state$as_of_date <- to_date
  state$half_life_days <- half_life_days
  state$last_decay_factor <- factor
  state$teams <- state$teams[order(state$teams$team_id, method = "radix"), , drop = FALSE]
  rownames(state$teams) <- NULL
  state
}

dynamic_goal_team_evidence <- function(state, team_id, prediction_date) {
  index <- match(as.character(team_id), state$teams$team_id)
  if (is.na(index)) {
    return(list(
      attack = 1,
      defence = 1,
      exposure = 0,
      shrinkage_weight = 0,
      cold_start = TRUE,
      source_date = as.Date(NA),
      state_age_days = 0,
      history_match_count = 0L
    ))
  }
  row <- state$teams[index, , drop = FALSE]
  exposure <- as.numeric(row$W)
  denominator <- state$pseudo_exposure + exposure
  attack_rate <- (state$pseudo_exposure * state$global_goal_rate + row$GF) / denominator
  defence_rate <- (state$pseudo_exposure * state$global_goal_rate + row$GA) / denominator
  source_date <- as.Date(row$latest_source_date)
  list(
    attack = attack_rate / state$global_goal_rate,
    defence = defence_rate / state$global_goal_rate,
    exposure = exposure,
    shrinkage_weight = exposure / denominator,
    cold_start = exposure == 0,
    source_date = source_date,
    state_age_days = if (is.na(source_date)) Inf else as.numeric(as.Date(prediction_date) - source_date),
    history_match_count = as.integer(row$history_match_count)
  )
}

dynamic_goal_max_date <- function(x) {
  x <- as.Date(x)
  if (!length(x) || all(is.na(x))) as.Date(NA) else max(x, na.rm = TRUE)
}

#' Predict a complete fixture-date batch without mutating state
#'
#' @param state One immutable pre-date state.
#' @param fixtures Fixtures sharing a prediction date.
#' @return Fixture means and auditable state evidence in stable fixture order.
#' @export
predict_dynamic_goal_batch <- function(state, fixtures, elo_coefficient = 0) {
  dynamic_goal_validate_state(state)
  dynamic_goal_required_columns(
    fixtures,
    c("fixture_id", "match_date", "home_team_id", "away_team_id"),
    "fixtures"
  )
  if (!nrow(fixtures)) return(data.frame())
  dates <- as.Date(fixtures$match_date)
  if (anyNA(dates) || length(unique(dates)) != 1L) {
    stop("fixtures must contain one complete match-date batch", call. = FALSE)
  }
  if (dates[1] < state$as_of_date) stop("fixture date predates dynamic state", call. = FALSE)
  if (anyDuplicated(fixtures$fixture_id)) stop("fixture_id must be unique within a batch", call. = FALSE)
  elo_coefficient <- as.numeric(elo_coefficient)
  if (length(elo_coefficient) != 1L || !is.finite(elo_coefficient)) {
    stop("elo_coefficient must be one finite signed value", call. = FALSE)
  }
  if (elo_coefficient != 0) dynamic_goal_validate_elo_provenance(fixtures, dates, "fixtures")

  ordered <- fixtures[order(as.character(fixtures$fixture_id), method = "radix"), , drop = FALSE]
  rows <- lapply(seq_len(nrow(ordered)), function(i) {
    home <- dynamic_goal_team_evidence(state, ordered$home_team_id[i], dates[1])
    away <- dynamic_goal_team_evidence(state, ordered$away_team_id[i], dates[1])
    source_date <- dynamic_goal_max_date(c(home$source_date, away$source_date))
    dynamic_log_mu_home <- log(state$global_goal_rate * home$attack * away$defence)
    dynamic_log_mu_away <- log(state$global_goal_rate * away$attack * home$defence)
    elo_value <- if ("elo_diff" %in% names(ordered)) as.numeric(ordered$elo_diff[i]) else 0
    data.frame(
      fixture_id = as.character(ordered$fixture_id[i]),
      boundary_id = if ("boundary_id" %in% names(ordered)) as.character(ordered$boundary_id[i]) else "",
      match_date = dates[1],
      home_team_id = as.character(ordered$home_team_id[i]),
      away_team_id = as.character(ordered$away_team_id[i]),
      mu_home = exp(dynamic_log_mu_home + elo_coefficient * elo_value),
      mu_away = exp(dynamic_log_mu_away - elo_coefficient * elo_value),
      global_goal_rate = state$global_goal_rate,
      dynamic_log_mu_home = dynamic_log_mu_home,
      dynamic_log_mu_away = dynamic_log_mu_away,
      elo_coefficient = elo_coefficient,
      home_attack_effect = log(home$attack),
      home_defence_effect = log(home$defence),
      away_attack_effect = log(away$attack),
      away_defence_effect = log(away$defence),
      state_age_days = max(home$state_age_days, away$state_age_days),
      observed_exposure = home$exposure + away$exposure,
      shrinkage_weight = mean(c(home$shrinkage_weight, away$shrinkage_weight)),
      cold_start = home$cold_start || away$cold_start,
      dynamic_state_source_date = source_date,
      home_state_source_date = home$source_date,
      away_state_source_date = away$source_date,
      historical_xg_active = FALSE,
      historical_xg_inactive_reason = "historical_xg_point_in_time_coverage_inactive",
      historical_form_active = FALSE,
      historical_form_inactive_reason = "historical_form_point_in_time_coverage_inactive",
      stringsAsFactors = FALSE
    )
  })
  result <- do.call(rbind, rows)
  rownames(result) <- NULL
  result
}

dynamic_goal_importance_weights <- function(results) {
  if ("importance_weight" %in% names(results)) {
    weights <- as.numeric(results$importance_weight)
  } else if ("tournament" %in% names(results) && exists("benchmark_importance_weight", mode = "function")) {
    weights <- as.numeric(benchmark_importance_weight(results$tournament))
  } else {
    weights <- rep(1, nrow(results))
  }
  if (any(!is.finite(weights)) || any(weights <= 0)) {
    stop("importance weights must be positive and finite", call. = FALSE)
  }
  weights
}

#' Update state once from a complete observed result-date batch
#'
#' @param state Pre-date dynamic state.
#' @param results Completed regulation-score rows for one date.
#' @return Deterministically aggregated post-date state.
#' @export
update_dynamic_goal_batch <- function(state, results) {
  dynamic_goal_validate_state(state)
  dynamic_goal_required_columns(
    results,
    c("match_date", "home_team_id", "away_team_id"),
    "results"
  )
  if (!nrow(results)) return(state)
  dates <- as.Date(results$match_date)
  if (anyNA(dates) || length(unique(dates)) != 1L) {
    stop("results must contain one complete match-date batch", call. = FALSE)
  }
  if (dates[1] < state$as_of_date) stop("result date predates dynamic state", call. = FALSE)
  if ("completed" %in% names(results) && any(is.na(results$completed) | !as.logical(results$completed))) {
    stop("dynamic updates require completed observed results", call. = FALSE)
  }
  home_goal_col <- if ("regulation_home_goals" %in% names(results)) "regulation_home_goals" else "home_goals"
  away_goal_col <- if ("regulation_away_goals" %in% names(results)) "regulation_away_goals" else "away_goals"
  dynamic_goal_required_columns(results, c(home_goal_col, away_goal_col), "results")
  home_goals <- as.numeric(results[[home_goal_col]])
  away_goals <- as.numeric(results[[away_goal_col]])
  if (any(!is.finite(home_goals)) || any(home_goals < 0) ||
      any(!is.finite(away_goals)) || any(away_goals < 0)) {
    stop("regulation goals must be finite and non-negative", call. = FALSE)
  }
  weights <- dynamic_goal_importance_weights(results)

  contributions <- rbind(
    data.frame(
      team_id = as.character(results$home_team_id),
      GF = weights * home_goals,
      GA = weights * away_goals,
      W = weights,
      history_match_count = 1L,
      latest_source_date = dates,
      stringsAsFactors = FALSE
    ),
    data.frame(
      team_id = as.character(results$away_team_id),
      GF = weights * away_goals,
      GA = weights * home_goals,
      W = weights,
      history_match_count = 1L,
      latest_source_date = dates,
      stringsAsFactors = FALSE
    )
  )
  if (anyNA(contributions$team_id) || any(!nzchar(contributions$team_id))) {
    stop("result team identifiers must be non-missing", call. = FALSE)
  }
  by_team <- split(contributions, contributions$team_id, drop = TRUE)
  additions <- do.call(rbind, lapply(sort(names(by_team), method = "radix"), function(team_id) {
    rows <- by_team[[team_id]]
    data.frame(
      team_id = team_id,
      GF = sum(rows$GF),
      GA = sum(rows$GA),
      W = sum(rows$W),
      history_match_count = as.integer(sum(rows$history_match_count)),
      latest_source_date = max(as.Date(rows$latest_source_date)),
      stringsAsFactors = FALSE
    )
  }))
  rownames(additions) <- NULL

  new_ids <- setdiff(additions$team_id, state$teams$team_id)
  if (length(new_ids)) state$teams <- rbind(state$teams, dynamic_goal_empty_team_rows(new_ids))
  for (i in seq_len(nrow(additions))) {
    index <- match(additions$team_id[i], state$teams$team_id)
    state$teams$GF[index] <- state$teams$GF[index] + additions$GF[i]
    state$teams$GA[index] <- state$teams$GA[index] + additions$GA[i]
    state$teams$W[index] <- state$teams$W[index] + additions$W[i]
    state$teams$history_match_count[index] <-
      state$teams$history_match_count[index] + additions$history_match_count[i]
    state$teams$latest_source_date[index] <- dynamic_goal_max_date(c(
      state$teams$latest_source_date[index], additions$latest_source_date[i]
    ))
  }
  state$teams <- state$teams[order(state$teams$team_id, method = "radix"), , drop = FALSE]
  rownames(state$teams) <- NULL
  state$as_of_date <- dates[1]
  state
}

#' Replay dynamic states in deterministic date batches
#'
#' @param history Completed historical regulation results.
#' @param fixtures Prediction fixtures.
#' @param initial_state Initial global-prior state.
#' @param half_life_days Evidence half-life.
#' @return Predictions, one snapshot per boundary, and final state.
#' @export
replay_dynamic_goal_states <- function(history, fixtures, initial_state, half_life_days = 730) {
  dynamic_goal_validate_state(initial_state)
  dynamic_goal_required_columns(history, c("match_date", "home_team_id", "away_team_id"), "history")
  dynamic_goal_required_columns(fixtures, c("fixture_id", "match_date", "home_team_id", "away_team_id"), "fixtures")
  state <- initial_state
  history_dates <- as.Date(history$match_date)
  fixture_dates <- as.Date(fixtures$match_date)
  if (anyNA(history_dates) || anyNA(fixture_dates)) stop("replay dates must be complete", call. = FALSE)

  # A blank initial state may safely be anchored before synthetic/diagnostic
  # history.  A populated state is never rewound.
  if (nrow(history) && all(state$teams$history_match_count == 0L)) {
    state$as_of_date <- min(c(state$as_of_date, history_dates))
  }
  ordered_dates <- sort(unique(c(history_dates, fixture_dates)))
  history_groups <- split(seq_len(nrow(history)), match(history_dates, ordered_dates))
  fixture_groups <- split(seq_len(nrow(fixtures)), match(fixture_dates, ordered_dates))
  prediction_parts <- list()
  snapshot_parts <- list()
  prediction_index <- 0L
  snapshot_index <- 0L

  for (date_index in seq_along(ordered_dates)) {
    date_value <- ordered_dates[[date_index]]
    date_value <- as.Date(date_value, origin = "1970-01-01")
    state <- decay_dynamic_goal_state(state, date_value, half_life_days = half_life_days)
    fixture_index <- fixture_groups[[as.character(date_index)]]
    fixture_rows <- fixtures[fixture_index, , drop = FALSE]
    if (nrow(fixture_rows)) {
      prediction_index <- prediction_index + 1L
      prediction_parts[[prediction_index]] <- predict_dynamic_goal_batch(state, fixture_rows)
      boundary_ids <- if ("boundary_id" %in% names(fixture_rows)) {
        sort(unique(as.character(fixture_rows$boundary_id)), method = "radix")
      } else {
        paste0("date_", format(date_value, "%Y%m%d"))
      }
      for (boundary_id in boundary_ids) {
        snapshot_index <- snapshot_index + 1L
        snapshot_parts[[snapshot_index]] <- list(
          boundary_id = boundary_id,
          evidence_cutoff_exclusive = date_value,
          state = state
        )
      }
    }
    history_index <- history_groups[[as.character(date_index)]]
    history_rows <- history[history_index, , drop = FALSE]
    if (nrow(history_rows)) state <- update_dynamic_goal_batch(state, history_rows)
  }

  predictions <- if (length(prediction_parts)) do.call(rbind, prediction_parts) else data.frame()
  if (nrow(predictions)) {
    predictions <- predictions[order(predictions$match_date, predictions$fixture_id, method = "radix"), , drop = FALSE]
    rownames(predictions) <- NULL
  }
  list(predictions = predictions, snapshots = snapshot_parts, final_state = state)
}

dynamic_goal_history_columns <- function(history) {
  date_col <- c("actual_completion_date", "match_date", "date")
  date_col <- date_col[date_col %in% names(history)][1]
  if (is.na(date_col)) stop("history requires an observed completion date", call. = FALSE)
  home_goal_col <- c("regulation_home_goals", "home_goals", "home_score")
  home_goal_col <- home_goal_col[home_goal_col %in% names(history)][1]
  away_goal_col <- c("regulation_away_goals", "away_goals", "away_score")
  away_goal_col <- away_goal_col[away_goal_col %in% names(history)][1]
  if (is.na(home_goal_col) || is.na(away_goal_col)) {
    stop("history requires observed regulation goals", call. = FALSE)
  }
  list(date = date_col, home_goals = home_goal_col, away_goals = away_goal_col)
}

dynamic_goal_as_results <- function(history) {
  columns <- dynamic_goal_history_columns(history)
  result <- history
  result$match_date <- as.Date(history[[columns$date]])
  result$home_goals <- as.numeric(history[[columns$home_goals]])
  result$away_goals <- as.numeric(history[[columns$away_goals]])
  result$completed <- TRUE
  if (!"match_id" %in% names(result)) {
    result$match_id <- sprintf("dynamic_match_%08d", seq_len(nrow(result)))
  }
  result
}

dynamic_goal_hash <- function(data) {
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("digest is required for dynamic goal provenance hashes", call. = FALSE)
  }
  digest::digest(data, algo = "sha256", serialize = TRUE)
}

dynamic_goal_score_probabilities <- function(mu_home, mu_away, support_max) {
  support_max <- as.integer(support_max)
  if (length(support_max) != 1L || is.na(support_max) || support_max < 1L) {
    stop("support_max must be one positive integer", call. = FALSE)
  }
  home <- stats::dpois(0:support_max, mu_home)
  away <- stats::dpois(0:support_max, mu_away)
  matrix <- outer(home, away)
  matrix <- matrix / sum(matrix)
  c(home = sum(matrix[row(matrix) > col(matrix)]),
    draw = sum(diag(matrix)),
    away = sum(matrix[row(matrix) < col(matrix)]))
}

dynamic_goal_rps <- function(probabilities, home_goals, away_goals) {
  observed <- if (home_goals > away_goals) 1L else if (home_goals == away_goals) 2L else 3L
  cumulative_prediction <- c(probabilities[1], probabilities[1] + probabilities[2])
  cumulative_observed <- c(as.numeric(observed <= 1L), as.numeric(observed <= 2L))
  mean((cumulative_prediction - cumulative_observed)^2)
}

dynamic_goal_tuning_cache_key <- function(
    history, inner_edition_id, pseudo_exposure, half_life_days, support_max
) {
  history <- dynamic_goal_as_results(history)
  assessment <- history$edition_id == inner_edition_id
  if (!any(assessment)) stop("inner edition has no eligible history rows: ", inner_edition_id, call. = FALSE)
  opener <- min(history$match_date[assessment])
  prior <- history$match_date < opener
  cache_rows <- history[prior | assessment, c(
    "match_id", "edition_id", "match_date", "home_team_id", "away_team_id",
    "home_goals", "away_goals"
  ), drop = FALSE]
  cache_rows <- cache_rows[
    order(cache_rows$match_date, cache_rows$match_id, method = "radix"), , drop = FALSE
  ]
  dynamic_goal_hash(list(
    rows = cache_rows, inner_edition_id = inner_edition_id,
    pseudo_exposure = as.numeric(pseudo_exposure),
    half_life_days = as.numeric(half_life_days), support_max = as.integer(support_max)
  ))
}

dynamic_goal_candidate_rps <- function(history, inner_edition_id, pseudo_exposure, half_life_days, support_max) {
  history <- dynamic_goal_as_results(history)
  dynamic_goal_required_columns(history, c("edition_id", "home_team_id", "away_team_id"), "history")
  assessment <- history$edition_id == inner_edition_id
  if (!any(assessment)) stop("inner edition has no eligible history rows: ", inner_edition_id, call. = FALSE)
  opener <- min(history$match_date[assessment])
  prior <- history$match_date < opener
  cache_key <- dynamic_goal_tuning_cache_key(
    history, inner_edition_id, pseudo_exposure, half_life_days, support_max
  )
  if (exists(cache_key, envir = .dynamic_goal_tuning_cache, inherits = FALSE)) {
    return(get(cache_key, envir = .dynamic_goal_tuning_cache, inherits = FALSE))
  }
  team_ids <- sort(unique(c(history$home_team_id[prior | assessment], history$away_team_id[prior | assessment])), method = "radix")
  prior_goals <- c(history$home_goals[prior], history$away_goals[prior])
  global_rate <- if (length(prior_goals) && is.finite(mean(prior_goals)) && mean(prior_goals) > 0) {
    mean(prior_goals)
  } else {
    1.25
  }
  first_date <- min(history$match_date[prior | assessment])
  state <- initialize_dynamic_goal_state(team_ids, global_rate, pseudo_exposure, first_date)
  evaluation_rows <- history[prior | assessment, , drop = FALSE]
  evaluation_rows <- evaluation_rows[order(evaluation_rows$match_date, evaluation_rows$match_id, method = "radix"), , drop = FALSE]
  date_groups <- split(seq_len(nrow(evaluation_rows)), evaluation_rows$match_date)
  scores <- numeric()
  for (date_index in seq_along(date_groups)) {
    date_rows <- evaluation_rows[date_groups[[date_index]], , drop = FALSE]
    date_value <- as.Date(date_rows$match_date[1L])
    state <- decay_dynamic_goal_state(state, date_value, half_life_days)
    if (any(date_rows$edition_id == inner_edition_id)) {
      assessment_rows <- date_rows[date_rows$edition_id == inner_edition_id, , drop = FALSE]
      fixtures <- data.frame(
        fixture_id = as.character(assessment_rows$match_id),
        match_date = assessment_rows$match_date,
        home_team_id = assessment_rows$home_team_id,
        away_team_id = assessment_rows$away_team_id,
        stringsAsFactors = FALSE
      )
      predictions <- predict_dynamic_goal_batch(state, fixtures)
      assessment_rows <- assessment_rows[match(predictions$fixture_id, assessment_rows$match_id), , drop = FALSE]
      scores <- c(scores, vapply(seq_len(nrow(predictions)), function(i) {
        probabilities <- dynamic_goal_score_probabilities(predictions$mu_home[i], predictions$mu_away[i], support_max)
        dynamic_goal_rps(probabilities, assessment_rows$home_goals[i], assessment_rows$away_goals[i])
      }, numeric(1)))
    }
    state <- update_dynamic_goal_batch(state, date_rows)
  }
  if (!length(scores) || any(!is.finite(scores))) stop("dynamic tuning produced nonfinite RPS", call. = FALSE)
  result <- mean(scores)
  assign(cache_key, result, envir = .dynamic_goal_tuning_cache)
  result
}

#' Select dynamic pseudo-exposure from completed prior tournaments
#'
#' @return Track-shared selected settings with an attached complete tuning audit.
#' @export
select_dynamic_goal_hyperparameters <- function(
    history,
    outer_edition_id,
    tuning_editions,
    tuning_grid,
    support_max = 40L
) {
  dynamic_goal_required_columns(history, c("edition_id", "home_team_id", "away_team_id"), "history")
  if (length(outer_edition_id) != 1L || is.na(outer_edition_id) || !nzchar(outer_edition_id)) {
    stop("outer_edition_id must be one registered edition", call. = FALSE)
  }
  completion_col <- c("inner_completion_date", "inner_final_date")
  completion_col <- completion_col[completion_col %in% names(tuning_editions)][1]
  dynamic_goal_required_columns(
    tuning_editions,
    c("outer_edition_id", "inner_edition_id", "outer_opener_date", completion_col),
    "tuning_editions"
  )
  eligible_editions <- tuning_editions[tuning_editions$outer_edition_id == outer_edition_id, , drop = FALSE]
  eligible_editions[[completion_col]] <- as.Date(eligible_editions[[completion_col]])
  eligible_editions$outer_opener_date <- as.Date(eligible_editions$outer_opener_date)
  eligible_editions <- eligible_editions[
    order(eligible_editions[[completion_col]], eligible_editions$inner_edition_id, method = "radix"),
    , drop = FALSE
  ]
  if (!nrow(eligible_editions) || any(eligible_editions[[completion_col]] >= eligible_editions$outer_opener_date)) {
    stop("dynamic tuning requires completed editions strictly before the outer opener", call. = FALSE)
  }
  if (anyDuplicated(eligible_editions$inner_edition_id)) stop("inner editions must be unique", call. = FALSE)

  if ("pseudo_exposure" %in% names(tuning_grid)) {
    candidates <- data.frame(
      pseudo_exposure = as.numeric(tuning_grid$pseudo_exposure),
      half_life_days = as.numeric(tuning_grid$half_life_days),
      stringsAsFactors = FALSE
    )
  } else {
    rows <- tuning_grid$parameter_id == "dynamic_pseudo_exposure"
    candidates <- data.frame(
      pseudo_exposure = as.numeric(tuning_grid$parameter_value[rows]),
      half_life_days = as.numeric(tuning_grid$half_life_days[rows]),
      stringsAsFactors = FALSE
    )
  }
  if (!nrow(candidates) || any(!is.finite(candidates$pseudo_exposure)) || any(candidates$pseudo_exposure <= 0) ||
      any(!is.finite(candidates$half_life_days)) || any(candidates$half_life_days <= 0)) {
    stop("dynamic tuning grid must contain positive finite pseudo-exposures and half-lives", call. = FALSE)
  }
  candidates <- unique(candidates[order(candidates$pseudo_exposure, method = "radix"), , drop = FALSE])

  history_columns <- dynamic_goal_history_columns(history)
  history_dates <- as.Date(history[[history_columns$date]])
  prior_history <- history[history$edition_id != outer_edition_id & history_dates < eligible_editions$outer_opener_date[1], , drop = FALSE]
  required_inner <- as.character(eligible_editions$inner_edition_id)
  if (!all(required_inner %in% unique(prior_history$edition_id))) {
    stop("history is missing registered prior inner editions", call. = FALSE)
  }
  audit <- do.call(rbind, lapply(seq_len(nrow(candidates)), function(i) {
    edition_scores <- vapply(required_inner, function(edition_id) {
      dynamic_goal_candidate_rps(
        prior_history, edition_id, candidates$pseudo_exposure[i],
        candidates$half_life_days[i], support_max
      )
    }, numeric(1))
    data.frame(
      candidate_pseudo_exposure = candidates$pseudo_exposure[i],
      half_life_days = candidates$half_life_days[i],
      objective_rps = mean(edition_scores),
      inner_scores_sha256 = dynamic_goal_hash(data.frame(
        inner_edition_id = required_inner,
        rps = edition_scores,
        stringsAsFactors = FALSE
      )),
      stringsAsFactors = FALSE
    )
  }))
  best_rps <- min(audit$objective_rps)
  tied <- audit$objective_rps <= best_rps + sqrt(.Machine$double.eps)
  selected_index <- which(tied & audit$candidate_pseudo_exposure == max(audit$candidate_pseudo_exposure[tied]))[1]
  selected <- audit[selected_index, , drop = FALSE]
  parent_rows <- eligible_editions[order(eligible_editions$inner_edition_id, method = "radix"), , drop = FALSE]
  settings <- do.call(rbind, lapply(c("frozen", "updating"), function(track_id) {
    data.frame(
      outer_edition_id = outer_edition_id,
      track_id = track_id,
      pseudo_exposure = selected$candidate_pseudo_exposure,
      candidate_pseudo_exposure = selected$candidate_pseudo_exposure,
      half_life_days = selected$half_life_days,
      objective_rps = selected$objective_rps,
      inner_edition_id = as.character(parent_rows$inner_edition_id),
      inner_completion_date = as.Date(parent_rows[[completion_col]]),
      outer_opener_date = as.Date(parent_rows$outer_opener_date),
      tuning_objective = "equal_tournament_updating_rps_prior_editions_only",
      tie_break = "largest_pseudo_exposure",
      stringsAsFactors = FALSE
    )
  }))
  rownames(settings) <- NULL
  attr(settings, "tuning_audit") <- audit
  attr(settings, "tuning_sha256") <- dynamic_goal_hash(audit)
  settings
}

dynamic_goal_validate_elo_feature_contract <- function(feature_contract_path) {
  if (is.null(feature_contract_path)) {
    root <- if (basename(getwd()) == "testthat") file.path(getwd(), "..", "..") else getwd()
    feature_contract_path <- file.path(root, "data", "benchmark", "phase10", "feature_contract.csv")
  }
  if (!file.exists(feature_contract_path)) stop("canonical feature contract is unavailable", call. = FALSE)
  contract <- utils::read.csv(feature_contract_path, stringsAsFactors = FALSE, check.names = FALSE)
  dynamic_goal_required_columns(contract, c("panel_id", "feature_id", "required"), "feature contract")
  row <- contract[contract$feature_id == "elo_diff" & contract$panel_id == "open_core", , drop = FALSE]
  if (nrow(row) != 1L || !isTRUE(as.logical(row$required))) {
    stop("feature contract must register required open-core elo_diff", call. = FALSE)
  }
  invisible(TRUE)
}

dynamic_goal_validate_elo_provenance <- function(data, cutoffs, label = "history") {
  required <- c(
    "elo_diff", "elo_diff__value_present", "elo_diff__source_present",
    "elo_diff__source_date", "elo_diff__imputed", "elo_diff__imputation_reason"
  )
  dynamic_goal_required_columns(data, required, label)
  values <- as.numeric(data$elo_diff)
  value_present <- as.logical(data$elo_diff__value_present)
  source_present <- as.logical(data$elo_diff__source_present)
  source_dates <- as.Date(data$elo_diff__source_date)
  imputed <- as.logical(data$elo_diff__imputed)
  reasons <- as.character(data$elo_diff__imputation_reason)
  reasons[is.na(reasons)] <- ""
  cutoffs <- as.Date(cutoffs)
  if (length(cutoffs) == 1L) cutoffs <- rep(cutoffs, nrow(data))
  if (length(cutoffs) != nrow(data)) stop(label, " Elo chronology cutoffs do not align", call. = FALSE)
  if (anyNA(source_present) || any(!source_present) || anyNA(value_present) || any(!value_present) ||
      anyNA(imputed) || any(imputed) || any(!is.finite(values)) || anyNA(source_dates) ||
      any(source_dates >= cutoffs) || any(nzchar(reasons))) {
    stop(label, " Elo provenance must be observed, non-imputed, and source dated strictly before its prediction cutoff", call. = FALSE)
  }
  invisible(TRUE)
}

#' Fit one signed Elo increment over dynamic parent means
#'
#' @export
fit_dynamic_elo_coefficient <- function(
    history,
    outer_edition_id,
    outer_opener_date,
    pseudo_exposure = 8,
    half_life_days = 730,
    feature_contract_path = NULL
) {
  dynamic_goal_required_columns(history, c("edition_id", "home_team_id", "away_team_id"), "history")
  dynamic_goal_validate_elo_feature_contract(feature_contract_path)
  outer_opener_date <- dynamic_goal_date(outer_opener_date, "outer_opener_date")
  columns <- dynamic_goal_history_columns(history)
  dates <- as.Date(history[[columns$date]])
  eligible <- history$edition_id != outer_edition_id & !is.na(dates) & dates < outer_opener_date
  training <- history[eligible, , drop = FALSE]
  training_dates <- dates[eligible]
  if (!nrow(training)) stop("no strictly prior Elo training rows are available", call. = FALSE)
  training_cutoffs <- if ("evidence_cutoff_exclusive" %in% names(training)) {
    as.Date(training$evidence_cutoff_exclusive)
  } else {
    training_dates
  }
  dynamic_goal_validate_elo_provenance(training, training_cutoffs, "prior training frame")
  training <- dynamic_goal_as_results(training)
  training$match_id <- iconv(
    as.character(training$match_id), from = "", to = "UTF-8", sub = "byte"
  )
  training <- training[order(training$match_date, training$match_id, method = "radix"), , drop = FALSE]
  team_ids <- sort(unique(c(training$home_team_id, training$away_team_id)), method = "radix")
  global_rate <- mean(c(training$home_goals, training$away_goals))
  if (!is.finite(global_rate) || global_rate <= 0) global_rate <- 1.25
  state <- initialize_dynamic_goal_state(team_ids, global_rate, pseudo_exposure, min(training$match_date))
  offsets <- numeric(2L * nrow(training))
  predictors <- numeric(2L * nrow(training))
  outcomes <- numeric(2L * nrow(training))
  cursor <- 0L
  date_groups <- split(seq_len(nrow(training)), training$match_date)
  for (date_index in seq_along(date_groups)) {
    rows <- training[date_groups[[date_index]], , drop = FALSE]
    date_value <- as.Date(rows$match_date[1L])
    state <- decay_dynamic_goal_state(state, date_value, half_life_days)
    fixtures <- data.frame(
      fixture_id = as.character(rows$match_id),
      match_date = rows$match_date,
      home_team_id = rows$home_team_id,
      away_team_id = rows$away_team_id,
      stringsAsFactors = FALSE
    )
    means <- predict_dynamic_goal_batch(state, fixtures)
    rows <- rows[match(means$fixture_id, rows$match_id), , drop = FALSE]
    positions <- cursor + seq_len(2L * nrow(rows))
    offsets[positions] <- c(means$dynamic_log_mu_home, means$dynamic_log_mu_away)
    predictors[positions] <- c(as.numeric(rows$elo_diff), -as.numeric(rows$elo_diff))
    outcomes[positions] <- c(rows$home_goals, rows$away_goals)
    cursor <- cursor + length(positions)
    state <- update_dynamic_goal_batch(state, rows)
  }
  objective <- function(coefficient) {
    lambda <- exp(offsets + coefficient * predictors)
    -sum(stats::dpois(outcomes, lambda = lambda, log = TRUE))
  }
  optimization <- stats::optimize(objective, interval = c(-0.05, 0.05), tol = 1e-10)
  coefficient <- as.numeric(optimization$minimum)
  if (!is.finite(coefficient) || !is.finite(optimization$objective)) {
    stop("dynamic Elo coefficient fit was nonfinite", call. = FALSE)
  }
  list(
    outer_edition_id = outer_edition_id,
    outer_opener_date = outer_opener_date,
    coefficient = coefficient,
    converged = TRUE,
    convergence_status = "converged",
    objective = as.numeric(optimization$objective),
    eligible_match_ids = sort(as.character(training$match_id), method = "radix"),
    eligible_match_ids_sha256 = dynamic_goal_hash(sort(as.character(training$match_id), method = "radix")),
    elo_value_sha256 = dynamic_goal_hash(data.frame(
      match_id = as.character(training$match_id), elo_diff = as.numeric(training$elo_diff), stringsAsFactors = FALSE
    )),
    elo_provenance_sha256 = dynamic_goal_hash(data.frame(
      match_id = as.character(training$match_id),
      source_date = as.Date(training$elo_diff__source_date),
      source_present = as.logical(training$elo_diff__source_present),
      value_present = as.logical(training$elo_diff__value_present),
      imputed = as.logical(training$elo_diff__imputed),
      imputation_reason = as.character(training$elo_diff__imputation_reason),
      stringsAsFactors = FALSE
    )),
    max_elo_source_date = max(as.Date(training$elo_diff__source_date)),
    state_sha256 = dynamic_goal_hash(list(final_state = state, offsets = offsets)),
    package_versions = c(R = as.character(getRversion()), stats = as.character(utils::packageVersion("stats")))
  )
}

#' Build an auditable dynamic-candidate manifest
#'
#' @export
dynamic_goal_manifest <- function(fit, settings, history, outer_edition_id) {
  required_fit <- c(
    "coefficient", "converged", "convergence_status", "eligible_match_ids_sha256",
    "elo_value_sha256", "elo_provenance_sha256", "max_elo_source_date", "state_sha256"
  )
  missing <- setdiff(required_fit, names(fit))
  if (length(missing)) stop("dynamic Elo fit missing manifest fields: ", paste(missing, collapse = ", "), call. = FALSE)
  selected_settings <- settings[settings$outer_edition_id == outer_edition_id, , drop = FALSE]
  if (!nrow(selected_settings) || !setequal(selected_settings$track_id, c("frozen", "updating"))) {
    stop("manifest requires one track-shared outer-fold setting", call. = FALSE)
  }
  tuning_sha256 <- attr(settings, "tuning_sha256")
  if (is.null(tuning_sha256)) tuning_sha256 <- dynamic_goal_hash(selected_settings)
  history_columns <- dynamic_goal_history_columns(history)
  history_order <- order(
    as.Date(history[[history_columns$date]]),
    if ("match_id" %in% names(history)) as.character(history$match_id) else seq_len(nrow(history)),
    method = "radix"
  )
  canonical_history <- history[history_order, , drop = FALSE]
  rownames(canonical_history) <- NULL
  data.frame(
    outer_edition_id = outer_edition_id,
    candidate_id = "dynamic_goal_ability_elo",
    parent_candidate_id = "dynamic_goal_ability",
    state_sha256 = fit$state_sha256,
    tuning_sha256 = tuning_sha256,
    eligible_match_ids_sha256 = fit$eligible_match_ids_sha256,
    elo_coefficient = as.numeric(fit$coefficient),
    coefficient_status = if (isTRUE(fit$converged)) "fitted" else "failed",
    elo_value_sha256 = fit$elo_value_sha256,
    elo_provenance_sha256 = fit$elo_provenance_sha256,
    max_elo_source_date = as.Date(fit$max_elo_source_date),
    historical_xg_active = FALSE,
    historical_xg_inactive_reason = "historical_xg_point_in_time_coverage_inactive",
    historical_form_active = FALSE,
    historical_form_inactive_reason = "historical_form_point_in_time_coverage_inactive",
    convergence_status = as.character(fit$convergence_status),
    package_versions = paste(names(fit$package_versions), fit$package_versions, sep = "=", collapse = ";"),
    package_versions_sha256 = dynamic_goal_hash(fit$package_versions),
    history_parent_sha256 = dynamic_goal_hash(canonical_history),
    settings_parent_sha256 = dynamic_goal_hash(selected_settings),
    stringsAsFactors = FALSE
  )
}
