#' Chronology-safe dynamic international goal ability
#'
#' Dynamic attack and defence effects are represented by decayed sufficient
#' statistics.  The global pseudo-exposure is fixed, so observed evidence can
#' decay continuously without changing the global prior.

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
      state_age_days = Inf,
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
predict_dynamic_goal_batch <- function(state, fixtures) {
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

  ordered <- fixtures[order(as.character(fixtures$fixture_id), method = "radix"), , drop = FALSE]
  rows <- lapply(seq_len(nrow(ordered)), function(i) {
    home <- dynamic_goal_team_evidence(state, ordered$home_team_id[i], dates[1])
    away <- dynamic_goal_team_evidence(state, ordered$away_team_id[i], dates[1])
    source_date <- dynamic_goal_max_date(c(home$source_date, away$source_date))
    data.frame(
      fixture_id = as.character(ordered$fixture_id[i]),
      boundary_id = if ("boundary_id" %in% names(ordered)) as.character(ordered$boundary_id[i]) else "",
      match_date = dates[1],
      home_team_id = as.character(ordered$home_team_id[i]),
      away_team_id = as.character(ordered$away_team_id[i]),
      mu_home = state$global_goal_rate * home$attack * away$defence,
      mu_away = state$global_goal_rate * away$attack * home$defence,
      global_goal_rate = state$global_goal_rate,
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
  prediction_parts <- list()
  snapshot_parts <- list()
  prediction_index <- 0L
  snapshot_index <- 0L

  for (date_value in ordered_dates) {
    date_value <- as.Date(date_value, origin = "1970-01-01")
    state <- decay_dynamic_goal_state(state, date_value, half_life_days = half_life_days)
    fixture_rows <- fixtures[fixture_dates == date_value, , drop = FALSE]
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
    history_rows <- history[history_dates == date_value, , drop = FALSE]
    if (nrow(history_rows)) state <- update_dynamic_goal_batch(state, history_rows)
  }

  predictions <- if (length(prediction_parts)) do.call(rbind, prediction_parts) else data.frame()
  if (nrow(predictions)) {
    predictions <- predictions[order(predictions$match_date, predictions$fixture_id, method = "radix"), , drop = FALSE]
    rownames(predictions) <- NULL
  }
  list(predictions = predictions, snapshots = snapshot_parts, final_state = state)
}
