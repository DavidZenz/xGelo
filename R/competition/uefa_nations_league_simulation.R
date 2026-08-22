#' Deterministic Nations League sampling and stage resolution.
#'
#' Phase 14 owns forecast construction.  This module consumes that immutable
#' handoff and applies only Nations League outcome rules to it.

uefa_nl_simulation_source_if_missing <- function(relative_path, symbols) {
  missing <- symbols[!vapply(symbols, exists, logical(1), mode = "function")]
  if (!length(missing)) return(invisible(TRUE))
  root <- if (exists("uefa_nl_rules_project_root", mode = "function")) {
    uefa_nl_rules_project_root(".")
  } else {
    normalizePath(".", winslash = "/", mustWork = TRUE)
  }
  path <- file.path(root, relative_path)
  if (!file.exists(path)) stop("Nations League simulation dependency is missing: ", relative_path, call. = FALSE)
  sys.source(path, envir = .GlobalEnv)
  missing <- symbols[!vapply(symbols, exists, logical(1), mode = "function")]
  if (length(missing)) stop("Nations League simulation dependency did not define: ", paste(missing, collapse = ", "), call. = FALSE)
  invisible(TRUE)
}

uefa_nl_simulation_source_if_missing(
  "R/competition/uefa_nations_league_rules.R",
  c("uefa_nl_2026_27_rules", "uefa_nl_ruleset_sha256", "uefa_nl_rules_row_sha256")
)
uefa_nl_simulation_source_if_missing(
  "R/competition/standings.R",
  c("phase14_compute_standings")
)

uefa_nl_sim_null_coalesce <- function(left, right) {
  if (is.null(left) || !length(left)) right else left
}

uefa_nl_sim_scalar_text <- function(value, field, allow_empty = FALSE) {
  if (length(value) != 1L || is.null(value) || is.na(value[[1L]])) {
    if (allow_empty) return("")
    stop("Nations League simulation ", field, " must be one non-missing value", call. = FALSE)
  }
  value <- trimws(as.character(value[[1L]]))
  if (!allow_empty && !nzchar(value)) stop("Nations League simulation ", field, " must not be empty", call. = FALSE)
  value
}

uefa_nl_sim_hash_column <- function(value) {
  if (inherits(value, "POSIXt")) {
    value <- format(value, "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC")
  } else if (is.logical(value)) {
    value <- ifelse(is.na(value), "<NA>", ifelse(value, "TRUE", "FALSE"))
  } else {
    value <- as.character(value)
  }
  value[is.na(value)] <- "<NA>"
  value
}

uefa_nl_sim_hash_data <- function(value) {
  if (!requireNamespace("digest", quietly = TRUE)) stop("digest is required for Nations League simulation hashes", call. = FALSE)
  if (is.data.frame(value)) {
    fields <- sort(names(value), method = "radix")
    data <- value[, fields, drop = FALSE]
    columns <- lapply(data, uefa_nl_sim_hash_column)
    ordering <- if (ncol(data)) {
      do.call(order, c(columns, list(na.last = TRUE, method = "radix")))
    } else {
      seq_len(nrow(data))
    }
    data <- data[ordering, , drop = FALSE]
    columns <- lapply(data, uefa_nl_sim_hash_column)
    rows <- if (!nrow(data)) character() else vapply(seq_len(nrow(data)), function(index) {
      paste(vapply(columns, `[[`, character(1), index), collapse = "\x1f")
    }, character(1))
    payload <- paste(c(paste(fields, collapse = "\x1f"), rows), collapse = "\x1e")
    return(tolower(digest::digest(payload, algo = "sha256", serialize = FALSE)))
  }
  if (is.list(value)) {
    if (!is.null(names(value))) value <- value[sort(names(value), method = "radix")]
    return(tolower(digest::digest(value, algo = "sha256", serialize = TRUE)))
  }
  value <- uefa_nl_sim_hash_column(value)
  tolower(digest::digest(paste(value, collapse = "\x1f"), algo = "sha256", serialize = FALSE))
}

uefa_nl_sim_with_seed <- function(seed, callback) {
  if (!is.function(callback)) stop("Nations League simulation seeded callback must be a function", call. = FALSE)
  if (is.null(seed)) return(callback())
  seed <- suppressWarnings(as.integer(seed))
  if (length(seed) != 1L || is.na(seed) || seed < 0L) stop("Nations League simulation seed must be one non-negative integer", call. = FALSE)
  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  old_seed <- if (had_seed) get(".Random.seed", envir = .GlobalEnv, inherits = FALSE) else NULL
  set.seed(seed)
  on.exit({
    if (had_seed) assign(".Random.seed", old_seed, envir = .GlobalEnv) else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) rm(".Random.seed", envir = .GlobalEnv)
  }, add = TRUE)
  callback()
}

uefa_nl_sim_probability_vector <- function(probabilities = NULL, forecast = NULL) {
  if (is.null(probabilities)) probabilities <- forecast
  if (is.data.frame(probabilities)) {
    if (nrow(probabilities) != 1L) stop("Nations League calibrated probabilities require one forecast row", call. = FALSE)
    probabilities <- probabilities[1L, , drop = FALSE]
  }
  if (is.list(probabilities) && !is.atomic(probabilities)) {
    fields <- c("p_home", "p_draw", "p_away")
    if (all(fields %in% names(probabilities))) probabilities <- unlist(probabilities[fields], use.names = FALSE)
  }
  if (is.null(probabilities)) stop("Nations League calibrated probabilities are missing", call. = FALSE)
  if (is.atomic(probabilities) && all(c("p_home", "p_draw", "p_away") %in% names(probabilities))) {
    probabilities <- probabilities[c("p_home", "p_draw", "p_away")]
    names(probabilities) <- c("home", "draw", "away")
  } else if (is.atomic(probabilities) && all(c("home", "draw", "away") %in% names(probabilities))) {
    probabilities <- probabilities[c("home", "draw", "away")]
  } else {
    probabilities <- as.numeric(probabilities)
    if (length(probabilities) == 3L) names(probabilities) <- c("home", "draw", "away")
  }
  probabilities <- suppressWarnings(as.numeric(probabilities))
  names(probabilities) <- c("home", "draw", "away")
  if (length(probabilities) != 3L || any(!is.finite(probabilities)) || any(probabilities < 0) || any(probabilities > 1)) {
    stop("Nations League calibrated probabilities must be finite and non-negative", call. = FALSE)
  }
  if (abs(sum(probabilities) - 1) > 1e-10) stop("Nations League calibrated probabilities must sum to one", call. = FALSE)
  probabilities
}

uefa_nl_sim_outcome_class <- function(home_goals, away_goals) {
  ifelse(home_goals > away_goals, "home", ifelse(home_goals == away_goals, "draw", "away"))
}

uefa_nl_sim_normalize_outcome_class <- function(value) {
  value <- tolower(trimws(as.character(value)))
  value[value %in% c("home_win", "home-win", "win", "h")] <- "home"
  value[value %in% c("draw", "tie", "d")] <- "draw"
  value[value %in% c("away_win", "away-win", "loss", "a")] <- "away"
  if (length(value) != 1L || is.na(value) || !value %in% c("home", "draw", "away")) stop("Nations League score outcome must be home, draw, or away", call. = FALSE)
  value
}

uefa_nl_sim_forecast_row <- function(forecast) {
  if (is.list(forecast) && !is.data.frame(forecast)) {
    candidates <- intersect(c("forecasts", "forecast", "row"), names(forecast))
    if (length(candidates)) forecast <- forecast[[candidates[[1L]]]]
  }
  if (!is.data.frame(forecast) || nrow(forecast) != 1L) stop("Nations League stage sampling requires one forecast row", call. = FALSE)
  as.data.frame(forecast[1L, , drop = FALSE], stringsAsFactors = FALSE, check.names = FALSE)
}

uefa_nl_sim_grid <- function(score_distribution, expected_fixture_id = NULL, expected_score_distribution_id = NULL) {
  if (is.list(score_distribution) && !is.data.frame(score_distribution)) {
    candidates <- intersect(c("score_distributions", "score_distribution", "grid"), names(score_distribution))
    if (length(candidates)) score_distribution <- score_distribution[[candidates[[1L]]]]
  }
  if (!is.data.frame(score_distribution) || !nrow(score_distribution)) stop("Nations League score grid must be a non-empty data frame", call. = FALSE)
  required <- c("home_goals", "away_goals", "probability")
  missing <- setdiff(required, names(score_distribution))
  if (length(missing)) stop("Nations League score grid is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  grid <- as.data.frame(score_distribution, stringsAsFactors = FALSE, check.names = FALSE)
  grid$home_goals <- suppressWarnings(as.numeric(as.character(grid$home_goals)))
  grid$away_goals <- suppressWarnings(as.numeric(as.character(grid$away_goals)))
  grid$probability <- suppressWarnings(as.numeric(as.character(grid$probability)))
  if (any(!is.finite(grid$home_goals) | !is.finite(grid$away_goals) | grid$home_goals < 0 | grid$away_goals < 0 | grid$home_goals != floor(grid$home_goals) | grid$away_goals != floor(grid$away_goals))) {
    stop("Nations League score grid has invalid goal support", call. = FALSE)
  }
  if (any(grid$home_goals > 40 | grid$away_goals > 40)) stop("Nations League score grid exceeds bounded support G=40", call. = FALSE)
  if (any(!is.finite(grid$probability) | grid$probability < 0)) stop("Nations League score grid probabilities must be finite and non-negative", call. = FALSE)
  if (abs(sum(grid$probability) - 1) > 1e-10) stop("Nations League score grid must be normalized", call. = FALSE)
  if ("normalized" %in% names(grid) && any(!as.logical(grid$normalized))) stop("Nations League score grid is not marked normalized", call. = FALSE)
  if (anyDuplicated(paste(grid$home_goals, grid$away_goals, sep = "::"))) stop("Nations League score grid has duplicate score cells", call. = FALSE)
  if (!is.null(expected_fixture_id) && "fixture_id" %in% names(grid)) {
    ids <- trimws(as.character(grid$fixture_id))
    ids <- ids[!is.na(ids) & nzchar(ids)]
    if (length(ids) && any(ids != as.character(expected_fixture_id))) stop("Nations League score grid has a foreign fixture identity", call. = FALSE)
  }
  if (!is.null(expected_score_distribution_id)) {
    if (!"score_distribution_id" %in% names(grid)) stop("Nations League score grid is missing score_distribution_id", call. = FALSE)
    ids <- unique(trimws(as.character(grid$score_distribution_id)))
    if (length(ids) != 1L || is.na(ids[[1L]]) || ids[[1L]] != as.character(expected_score_distribution_id)) stop("Nations League score grid identity does not match forecast", call. = FALSE)
  }
  grid$outcome_class <- uefa_nl_sim_outcome_class(grid$home_goals, grid$away_goals)
  grid
}

uefa_nl_sample_calibrated_outcome <- function(probabilities = NULL, n = 1L, seed = NULL, forecast = NULL) {
  probabilities <- uefa_nl_sim_probability_vector(probabilities, forecast)
  n <- suppressWarnings(as.integer(n))
  if (length(n) != 1L || is.na(n) || n < 1L) stop("Nations League outcome sample size must be positive", call. = FALSE)
  sample_one <- function() sample(c("home", "draw", "away"), size = n, replace = TRUE, prob = probabilities)
  uefa_nl_sim_with_seed(seed, sample_one)
}

uefa_nl_condition_score_distribution <- function(
    score_distribution,
    outcome_class = NULL,
    calibrated_probabilities = NULL,
    forecast = NULL) {
  probabilities <- uefa_nl_sim_probability_vector(calibrated_probabilities, forecast)
  grid <- uefa_nl_sim_grid(score_distribution)
  classes <- c("home", "draw", "away")
  class_index <- lapply(classes, function(value) which(grid$outcome_class == value))
  names(class_index) <- classes
  positive_category_missing <- vapply(seq_along(classes), function(index) {
    length(class_index[[index]]) == 0L || sum(grid$probability[class_index[[index]]]) <= 0
  }, logical(1)) & probabilities > 1e-12
  if (any(positive_category_missing)) stop("Nations League score grid category is empty: ", paste(classes[positive_category_missing], collapse = ", "), call. = FALSE)
  selected <- if (is.null(outcome_class)) classes else uefa_nl_sim_normalize_outcome_class(outcome_class)
  grid$grid_probability <- grid$probability
  grid$conditional_probability <- 0
  grid$probability <- 0
  for (value in classes) {
    indexes <- class_index[[value]]
    if (!length(indexes)) next
    category_mass <- sum(grid$grid_probability[indexes])
    if (category_mass <= 0) next
    grid$conditional_probability[indexes] <- grid$grid_probability[indexes] / category_mass
    if (length(selected) == 3L || identical(selected, value)) grid$probability[indexes] <- grid$conditional_probability[indexes] * probabilities[[value]]
  }
  grid$conditioned_outcome <- if (length(selected) == 3L) "all" else selected
  grid$scoreline_conditioning_policy <- "calibrated_1x2_conditional_score_grid"
  grid
}

uefa_nl_sample_stage_match <- function(
    forecast,
    score_distribution,
    seed = NULL,
    stage_id = "league_phase",
    stage_status = "projected",
    projection_run_id = "",
    draw_policy_id = "") {
  row <- uefa_nl_sim_forecast_row(forecast)
  if (!"forecast_status" %in% names(row) || !identical(tolower(as.character(row$forecast_status[[1L]])), "available")) stop("Nations League stage sampling requires forecast_status = available", call. = FALSE)
  if (!"primary_probability_view" %in% names(row) || !identical(as.character(row$primary_probability_view[[1L]]), "calibrated_1x2")) stop("Nations League stage sampling requires primary_probability_view = calibrated_1x2", call. = FALSE)
  fixture_id <- if ("fixture_id" %in% names(row)) as.character(row$fixture_id[[1L]]) else if ("match_id" %in% names(row)) as.character(row$match_id[[1L]]) else NA_character_
  score_id <- if ("score_distribution_id" %in% names(row)) as.character(row$score_distribution_id[[1L]]) else NULL
  probabilities <- uefa_nl_sim_probability_vector(row)
  grid <- uefa_nl_sim_grid(score_distribution, expected_fixture_id = fixture_id, expected_score_distribution_id = score_id)
  home_team <- if ("home_team_id" %in% names(row)) as.character(row$home_team_id[[1L]]) else NA_character_
  away_team <- if ("away_team_id" %in% names(row)) as.character(row$away_team_id[[1L]]) else NA_character_
  if (is.na(home_team) || !nzchar(home_team) || is.na(away_team) || !nzchar(away_team) || identical(home_team, away_team)) stop("Nations League stage sampling requires two distinct team IDs", call. = FALSE)
  uefa_nl_sim_with_seed(seed, function() {
    outcome <- uefa_nl_sample_calibrated_outcome(probabilities, n = 1L)
    conditioned <- uefa_nl_condition_score_distribution(grid, outcome_class = outcome, calibrated_probabilities = probabilities)
    indexes <- which(conditioned$outcome_class == outcome)
    chosen <- sample(indexes, size = 1L, prob = conditioned$conditional_probability[indexes])
    score <- conditioned[chosen, , drop = FALSE]
    data.frame(
      edition_id = if ("edition_id" %in% names(row)) as.character(row$edition_id[[1L]]) else NA_character_,
      fixture_id = fixture_id, match_id = if ("match_id" %in% names(row)) as.character(row$match_id[[1L]]) else fixture_id,
      stage_id = as.character(stage_id), stage_status = as.character(stage_status), leg_number = 1L,
      home_team_id = home_team, away_team_id = away_team,
      home_goals = as.integer(score$home_goals[[1L]]), away_goals = as.integer(score$away_goals[[1L]]),
      participant_slot_home = home_team, participant_slot_away = away_team,
      source_fixture_id = "", source_artifact_id = "", projection_run_id = as.character(projection_run_id), draw_policy_id = as.character(draw_policy_id),
      regulation_home_goals = as.integer(score$home_goals[[1L]]), regulation_away_goals = as.integer(score$away_goals[[1L]]),
      extra_time_home_goals = 0L, extra_time_away_goals = 0L,
      penalty_shootout_home_goals = NA_integer_, penalty_shootout_away_goals = NA_integer_,
      final_home_goals = as.integer(score$home_goals[[1L]]), final_away_goals = as.integer(score$away_goals[[1L]]),
      completed_at_utc = NA_character_, outcome_class = outcome,
      outcome_probability = probabilities[[outcome]], scoreline_conditional_probability = conditioned$conditional_probability[[chosen]],
      probability_sampling_policy = "calibrated_1x2_conditional_score_grid",
      scoreline_conditioning_policy = "calibrated_1x2_conditional_score_grid",
      stringsAsFactors = FALSE, check.names = FALSE
    )
  })
}

uefa_nl_sim_row_value <- function(row, fields, default = NA) {
  fields <- intersect(fields, names(row))
  if (!length(fields)) return(default)
  value <- row[[fields[[1L]]]][[1L]]
  if (length(value) == 0L || is.na(value)) default else value
}

uefa_nl_sim_score_value <- function(row, fields, default = NA_real_) {
  value <- uefa_nl_sim_row_value(row, fields, default)
  if (length(value) == 0L || is.na(value)) return(default)
  value <- suppressWarnings(as.numeric(as.character(value)))
  if (!is.finite(value) || value < 0 || value != floor(value)) stop("Nations League stage score is invalid", call. = FALSE)
  value
}

uefa_nl_sim_leg_scores <- function(row) {
  regulation_home <- uefa_nl_sim_score_value(row, c("regulation_home_goals", "home_goals", "final_home_goals"))
  regulation_away <- uefa_nl_sim_score_value(row, c("regulation_away_goals", "away_goals", "final_away_goals"))
  extra_home <- uefa_nl_sim_score_value(row, c("extra_time_home_goals"), 0)
  extra_away <- uefa_nl_sim_score_value(row, c("extra_time_away_goals"), 0)
  final_home <- uefa_nl_sim_score_value(row, c("final_home_goals"), regulation_home + extra_home)
  final_away <- uefa_nl_sim_score_value(row, c("final_away_goals"), regulation_away + extra_away)
  list(
    regulation_home = regulation_home, regulation_away = regulation_away,
    extra_home = extra_home, extra_away = extra_away,
    final_home = final_home, final_away = final_away,
    shootout_home = uefa_nl_sim_score_value(row, c("penalty_shootout_home_goals", "shootout_home_goals")),
    shootout_away = uefa_nl_sim_score_value(row, c("penalty_shootout_away_goals", "shootout_away_goals"))
  )
}

uefa_nl_validate_two_leg_pair <- function(
    pair,
    higher_league_team_id = NULL,
    lower_league_team_id = NULL,
    rules = uefa_nl_2026_27_rules()) {
  if (!is.data.frame(pair) || nrow(pair) != 2L) stop("Nations League two-leg tie must contain exactly two legs", call. = FALSE)
  required <- c("leg_number", "home_team_id", "away_team_id")
  missing <- setdiff(required, names(pair))
  if (length(missing)) stop("Nations League two-leg tie is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  legs <- suppressWarnings(as.integer(as.character(pair$leg_number)))
  if (any(is.na(legs)) || !setequal(legs, 1:2) || anyDuplicated(legs)) stop("Nations League two-leg tie must contain leg 1 and leg 2 exactly once", call. = FALSE)
  home <- trimws(as.character(pair$home_team_id)); away <- trimws(as.character(pair$away_team_id))
  if (any(is.na(home) | is.na(away) | !nzchar(home) | !nzchar(away) | home == away)) stop("Nations League two-leg tie contains an invalid same-side row", call. = FALSE)
  participants <- sort(unique(c(home, away)), method = "radix")
  if (length(participants) != 2L) stop("Nations League two-leg tie must use exactly two unordered participants", call. = FALSE)
  if (!identical(sort(c(home[[1L]], away[[1L]]), method = "radix"), sort(c(home[[2L]], away[[2L]]), method = "radix"))) stop("Nations League two-leg tie must use the same unordered participants", call. = FALSE)
  if (length(unique(home)) != 2L || length(unique(away)) != 2L) stop("Nations League two-leg tie must host each participant exactly once", call. = FALSE)
  lower_values <- c(lower_league_team_id, if ("lower_league_team_id" %in% names(pair)) as.character(pair$lower_league_team_id), if ("lower_team_id" %in% names(pair)) as.character(pair$lower_team_id))
  lower_values <- unique(lower_values[!is.na(lower_values) & nzchar(lower_values)])
  if (length(lower_values) > 1L) stop("Nations League two-leg tie has ambiguous lower-league participant", call. = FALSE)
  stage_ids <- if ("stage_id" %in% names(pair)) tolower(as.character(pair$stage_id)) else character()
  is_playoff <- any(stage_ids %in% c("a_b_playoff", "b_c_playoff", "c_d_playoff", "play_off", "playoff")) || length(lower_values) == 1L
  if (is_playoff && length(lower_values) == 1L) {
    first <- which(legs == 1L)
    if (!identical(as.character(home[[first]]), lower_values[[1L]])) stop("Nations League play-off lower-league participant must host leg 1", call. = FALSE)
  }
  invisible(TRUE)
}

uefa_nl_sim_penalty_winner <- function(home_team, away_team, row = NULL, seed = NULL, penalty_winner = NULL) {
  explicit <- penalty_winner
  if (is.null(explicit) && !is.null(row)) explicit <- uefa_nl_sim_row_value(row, c("penalty_winner_team_id", "shootout_winner_team_id"), NULL)
  if (!is.null(explicit) && length(explicit) && !is.na(explicit[[1L]]) && as.character(explicit[[1L]]) %in% c(home_team, away_team)) return(as.character(explicit[[1L]]))
  scores <- if (is.null(row)) list(shootout_home = NA_real_, shootout_away = NA_real_) else uefa_nl_sim_leg_scores(row)
  if (is.finite(scores$shootout_home) && is.finite(scores$shootout_away)) {
    if (scores$shootout_home == scores$shootout_away) stop("Nations League shootout tallies cannot be tied", call. = FALSE)
    return(if (scores$shootout_home > scores$shootout_away) home_team else away_team)
  }
  uefa_nl_sim_with_seed(seed, function() sample(c(home_team, away_team), size = 1L, prob = c(0.5, 0.5)))
}

uefa_nl_sim_resolution <- function(
    stage_status = "completed", winner = NA_character_, loser = NA_character_,
    resolution = "unresolved", extra_time_used = FALSE, penalty_used = FALSE,
    unresolved_reason = "", ...) {
  list(
    stage_status = stage_status, winner_team_id = winner, loser_team_id = loser,
    winner = winner, loser = loser, resolution = resolution, resolution_method = resolution,
    extra_time_used = isTRUE(extra_time_used), penalty_used = isTRUE(penalty_used),
    unresolved_reason = unresolved_reason, ...
  )
}

uefa_nl_resolve_two_leg_tie <- function(
    pair,
    seed = NULL,
    rules = uefa_nl_2026_27_rules(),
    lower_league_team_id = NULL,
    penalty_winner = NULL,
    second_leg_extra_time = NULL) {
  uefa_nl_validate_two_leg_pair(pair, lower_league_team_id = lower_league_team_id, rules = rules)
  ordered <- pair[order(as.integer(pair$leg_number), method = "radix"), , drop = FALSE]
  uefa_nl_sim_with_seed(seed, function() {
    first <- uefa_nl_sim_leg_scores(ordered[1L, , drop = FALSE])
    second <- uefa_nl_sim_leg_scores(ordered[2L, , drop = FALSE])
    if (any(!is.finite(c(first$final_home, first$final_away, second$regulation_home, second$regulation_away)))) {
      return(uefa_nl_sim_resolution(stage_status = "unresolved", resolution = "unresolved", unresolved_reason = "completed_scores_missing", first_leg = first, second_leg = second))
    }
    teams <- sort(unique(c(as.character(ordered$home_team_id), as.character(ordered$away_team_id))), method = "radix")
    first_total <- setNames(c(0, 0), teams)
    second_reg_total <- setNames(c(0, 0), teams)
    first_total[as.character(ordered$home_team_id[[1L]])] <- first_total[as.character(ordered$home_team_id[[1L]])] + first$final_home
    first_total[as.character(ordered$away_team_id[[1L]])] <- first_total[as.character(ordered$away_team_id[[1L]])] + first$final_away
    second_reg_total[as.character(ordered$home_team_id[[2L]])] <- second_reg_total[as.character(ordered$home_team_id[[2L]])] + second$regulation_home
    second_reg_total[as.character(ordered$away_team_id[[2L]])] <- second_reg_total[as.character(ordered$away_team_id[[2L]])] + second$regulation_away
    aggregate <- first_total + second_reg_total
    resolution <- "aggregate"
    extra_used <- FALSE
    penalty_used <- FALSE
    second_final_total <- second_reg_total
    if (diff(range(aggregate)) == 0) {
      extra <- c(home = second$extra_home, away = second$extra_away)
      if (!is.null(second_leg_extra_time)) {
        extra <- suppressWarnings(as.numeric(second_leg_extra_time))
        if (length(extra) != 2L || any(!is.finite(extra)) || any(extra < 0 | extra != floor(extra))) stop("Nations League second-leg extra-time score is invalid", call. = FALSE)
        names(extra) <- c("home", "away")
      }
      if (all(is.finite(extra))) {
        extra_used <- TRUE
        second_final_total[as.character(ordered$home_team_id[[2L]])] <- second_final_total[as.character(ordered$home_team_id[[2L]])] + extra[["home"]]
        second_final_total[as.character(ordered$away_team_id[[2L]])] <- second_final_total[as.character(ordered$away_team_id[[2L]])] + extra[["away"]]
        aggregate <- first_total + second_final_total
        resolution <- "extra_time"
      }
    }
    if (diff(range(aggregate)) == 0) {
      penalty_used <- TRUE
      winner <- uefa_nl_sim_penalty_winner(as.character(ordered$home_team_id[[2L]]), as.character(ordered$away_team_id[[2L]]), ordered[2L, , drop = FALSE], penalty_winner = penalty_winner)
      resolution <- "penalties"
    } else {
      winner <- names(which.max(aggregate))[[1L]]
    }
    loser <- setdiff(teams, winner)[[1L]]
    uefa_nl_sim_resolution(
      stage_status = "completed", winner = winner, loser = loser, resolution = resolution,
      extra_time_used = extra_used, penalty_used = penalty_used,
      first_leg = first, second_leg = second, aggregate_goals = aggregate,
      aggregate_goals_before_extra_time = first_total + second_reg_total,
      first_leg_home_team_id = as.character(ordered$home_team_id[[1L]]),
      second_leg_home_team_id = as.character(ordered$home_team_id[[2L]]),
      penalty_winner_team_id = if (penalty_used) winner else NA_character_,
      penalty_resolution_policy = "seeded_bernoulli_0.5"
    )
  })
}

uefa_nl_resolve_single_leg <- function(
    match,
    mode = c("extra_time_then_penalties", "penalties_without_extra_time"),
    seed = NULL,
    rules = uefa_nl_2026_27_rules(),
    penalty_winner = NULL,
    extra_time_score = NULL,
    tie_break_policy = NULL) {
  if (is.list(match) && !is.data.frame(match)) match <- as.data.frame(match, stringsAsFactors = FALSE, check.names = FALSE)
  if (!is.data.frame(match) || nrow(match) != 1L) stop("Nations League single-leg resolution requires one match row", call. = FALSE)
  if (length(tie_break_policy) && !is.null(tie_break_policy)) mode <- tie_break_policy
  mode <- tolower(as.character(mode[[1L]]))
  if (mode %in% c("final", "semi_final", "semi-final", "extra_time", "extra_time_then_penalties", "extra-time-then-penalties")) mode <- "extra_time_then_penalties"
  if (mode %in% c("third_place", "third-place", "direct_penalty", "direct-penalty", "penalties", "penalties_without_extra_time", "penalties-without-extra-time")) mode <- "penalties_without_extra_time"
  if (!mode %in% c("extra_time_then_penalties", "penalties_without_extra_time")) stop("Nations League single-leg resolution mode is unsupported", call. = FALSE)
  home <- uefa_nl_sim_row_value(match, c("home_team_id", "team_a"), NA_character_)
  away <- uefa_nl_sim_row_value(match, c("away_team_id", "team_b"), NA_character_)
  if (is.na(home) || is.na(away) || !nzchar(home) || !nzchar(away) || identical(home, away)) stop("Nations League single-leg match requires two distinct teams", call. = FALSE)
  uefa_nl_sim_with_seed(seed, function() {
    scores <- uefa_nl_sim_leg_scores(match)
    if (any(!is.finite(c(scores$regulation_home, scores$regulation_away)))) return(uefa_nl_sim_resolution(stage_status = "unresolved", resolution = "unresolved", unresolved_reason = "completed_scores_missing"))
    home_score <- scores$regulation_home
    away_score <- scores$regulation_away
    resolution <- "regulation"
    extra_used <- FALSE
    penalty_used <- FALSE
    if (home_score == away_score && identical(mode, "extra_time_then_penalties")) {
      extra <- if (is.null(extra_time_score)) c(scores$extra_home, scores$extra_away) else suppressWarnings(as.numeric(extra_time_score))
      if (length(extra) != 2L || any(!is.finite(extra)) || any(extra < 0 | extra != floor(extra))) stop("Nations League extra-time score is invalid", call. = FALSE)
      home_score <- home_score + extra[[1L]]
      away_score <- away_score + extra[[2L]]
      extra_used <- TRUE
      resolution <- "extra_time"
    }
    if (home_score == away_score) {
      penalty_used <- TRUE
      winner <- uefa_nl_sim_penalty_winner(home, away, match, penalty_winner = penalty_winner)
      resolution <- "penalties"
    } else {
      winner <- if (home_score > away_score) home else away
    }
    loser <- if (identical(winner, home)) away else home
    uefa_nl_sim_resolution(
      stage_status = "completed", winner = winner, loser = loser, resolution = resolution,
      extra_time_used = extra_used, penalty_used = penalty_used,
      regulation_score = c(home = scores$regulation_home, away = scores$regulation_away),
      final_score = c(home = home_score, away = away_score),
      mode = mode, penalty_winner_team_id = if (penalty_used) winner else NA_character_,
      penalty_resolution_policy = "seeded_bernoulli_0.5"
    )
  })
}

uefa_nl_sim_team_rows <- function(value, role = "team") {
  if (is.null(value)) return(data.frame(team_id = character(), group_id = character(), stringsAsFactors = FALSE, check.names = FALSE))
  if (is.list(value) && !is.data.frame(value)) {
    candidate <- intersect(c("rows", "rankings", "teams", "group_standings"), names(value))
    if (length(candidate)) value <- value[[candidate[[1L]]]]
  }
  if (is.data.frame(value)) {
    fields <- intersect(c("team_id", "team", "id"), names(value))
    if (!length(fields)) stop("Nations League ", role, " rows require team_id", call. = FALSE)
    output <- as.data.frame(value, stringsAsFactors = FALSE, check.names = FALSE)
    output$team_id <- as.character(output[[fields[[1L]]]])
    if (!"group_id" %in% names(output)) {
      group_field <- intersect(c("group", "group_key", "published_group_id"), names(output))
      output$group_id <- if (length(group_field)) as.character(output[[group_field[[1L]]]]) else NA_character_
    }
    if (!"league" %in% names(output) && "league_id" %in% names(output)) output$league <- as.character(output$league_id)
    if (!"group_position" %in% names(output)) output$group_position <- NA_integer_
    return(output)
  }
  value <- as.character(value)
  if (!length(value)) return(data.frame(team_id = character(), group_id = character(), stringsAsFactors = FALSE, check.names = FALSE))
  group_ids <- names(value)
  if (is.null(group_ids)) group_ids <- rep(NA_character_, length(value))
  data.frame(team_id = value, group_id = group_ids, stringsAsFactors = FALSE, check.names = FALSE)
}

uefa_nl_sim_projection_ids <- function(projection_run_id, draw_policy_id, seed = NULL) {
  policy <- as.character(draw_policy_id[[1L]])
  policy_hash <- uefa_nl_sim_hash_data(policy)
  projection <- if (length(projection_run_id) && !is.na(projection_run_id[[1L]]) && nzchar(as.character(projection_run_id[[1L]]))) {
    as.character(projection_run_id[[1L]])
  } else {
    paste0("phase15-nl-projection-", substr(uefa_nl_sim_hash_data(list(seed = seed, policy = policy)), 1L, 16L))
  }
  list(projection_run_id = projection, draw_policy_id = policy, draw_policy_sha256 = policy_hash)
}

uefa_nl_sim_stage_slots <- function(
    stage_id, stage_type, pairs, rules, projection_run_id, draw_policy_id,
    source_status = "projected") {
  if (!nrow(pairs)) return(data.frame(stringsAsFactors = FALSE, check.names = FALSE))
  ids <- uefa_nl_sim_projection_ids(projection_run_id, draw_policy_id)
  rows <- lapply(seq_len(nrow(pairs)), function(index) {
    pair <- pairs[index, , drop = FALSE]
    leg_rows <- if (as.integer(pair$legs[[1L]]) == 2L) c(1L, 2L) else 1L
    do.call(rbind, lapply(leg_rows, function(leg) {
      home <- if (leg == 1L) as.character(pair$team_b[[1L]]) else as.character(pair$team_a[[1L]])
      away <- if (leg == 1L) as.character(pair$team_a[[1L]]) else as.character(pair$team_b[[1L]])
      base <- data.frame(
        edition_id = as.character(rules$edition_id), stage_id = as.character(stage_id), stage_type = as.character(stage_type), stage_status = as.character(source_status), leg_number = as.integer(leg),
        participant_slot_home = if (leg == 1L) as.character(pair$slot_b[[1L]]) else as.character(pair$slot_a[[1L]]),
        participant_slot_away = if (leg == 1L) as.character(pair$slot_a[[1L]]) else as.character(pair$slot_b[[1L]]),
        home_team_id = home, away_team_id = away, source_fixture_id = "", source_artifact_id = "",
        projection_run_id = ids$projection_run_id, draw_policy_id = ids$draw_policy_id, scheduled_at_utc = NA_character_,
        unresolved_reason = "", suppression_reason = "", ruleset_version = as.character(rules$ruleset_version), ruleset_sha256 = uefa_nl_ruleset_sha256(rules),
        regulation_home_goals = NA_integer_, regulation_away_goals = NA_integer_, extra_time_home_goals = NA_integer_, extra_time_away_goals = NA_integer_,
        penalty_shootout_home_goals = NA_integer_, penalty_shootout_away_goals = NA_integer_, final_home_goals = NA_integer_, final_away_goals = NA_integer_, completed_at_utc = NA_character_,
        stringsAsFactors = FALSE, check.names = FALSE
      )
      base$draw_policy_sha256 <- ids$draw_policy_sha256
      base$row_sha256 <- uefa_nl_rules_row_sha256(base, hash_col = "row_sha256")
      base
    }))
  })
  output <- do.call(rbind, rows)
  row.names(output) <- NULL
  output
}

uefa_nl_draw_quarter_finals <- function(
    group_winners,
    runners_up = NULL,
    seed = NULL,
    projection_run_id = NULL,
    rules = uefa_nl_2026_27_rules(),
    official_stage_slots = NULL,
    pairings = NULL) {
  if (!is.null(official_stage_slots)) {
    slots <- as.data.frame(official_stage_slots, stringsAsFactors = FALSE, check.names = FALSE)
    if (exists("uefa_nl_validate_stage_slots", mode = "function")) uefa_nl_validate_stage_slots(slots, edition_id = rules$edition_id, ruleset_sha256 = uefa_nl_ruleset_sha256(rules))
    return(list(stage_slots = slots, slots = slots, pairings = data.frame(stringsAsFactors = FALSE), draw_policy_id = "official_stage_capture", draw_policy_sha256 = uefa_nl_sim_hash_data("official_stage_capture"), projection_run_id = projection_run_id %||% "", official = TRUE))
  }
  winners <- uefa_nl_sim_team_rows(group_winners, "League A group winners")
  if (is.null(runners_up) && "group_position" %in% names(winners)) {
    full <- winners
    runners_up <- full[as.integer(full$group_position) == 2L, , drop = FALSE]
    winners <- full[as.integer(full$group_position) == 1L, , drop = FALSE]
  } else {
    runners_up <- uefa_nl_sim_team_rows(runners_up, "League A group runners-up")
  }
  if (nrow(winners) != 4L || nrow(runners_up) != 4L) stop("Nations League quarter-final draw requires four group winners and four runners-up", call. = FALSE)
  for (rows in list(winners, runners_up)) {
    if (any(is.na(rows$group_id) | !nzchar(as.character(rows$group_id)))) stop("Nations League quarter-final draw requires group IDs", call. = FALSE)
    if (anyDuplicated(as.character(rows$team_id))) stop("Nations League quarter-final draw has duplicate teams", call. = FALSE)
  }
  if (length(intersect(as.character(winners$team_id), as.character(runners_up$team_id)))) stop("Nations League quarter-final draw reuses a team", call. = FALSE)
  winners <- winners[order(as.character(winners$group_id), as.character(winners$team_id), method = "radix"), , drop = FALSE]
  runners_up <- runners_up[order(as.character(runners_up$group_id), as.character(runners_up$team_id), method = "radix"), , drop = FALSE]
  legal <- list()
  walk <- function(index, used, chosen) {
    if (index > nrow(winners)) {
      legal[[length(legal) + 1L]] <<- chosen
      return(invisible(NULL))
    }
    candidates <- which(!(seq_len(nrow(runners_up)) %in% used) & as.character(runners_up$group_id) != as.character(winners$group_id[[index]]))
    for (candidate in candidates) walk(index + 1L, c(used, candidate), c(chosen, candidate))
    invisible(NULL)
  }
  walk(1L, integer(), integer())
  if (!length(legal)) stop("Nations League quarter-final draw has no legal different-group pairing", call. = FALSE)
  selected <- if (is.null(seed)) legal[[1L]] else uefa_nl_sim_with_seed(seed, function() legal[[sample.int(length(legal), 1L)]])
  pairs <- data.frame(
    tie_id = paste0("qf-", seq_len(4L)), pair_index = seq_len(4L), legs = 2L,
    team_a = as.character(winners$team_id), team_b = as.character(runners_up$team_id[selected]),
    slot_a = paste0("A-group-winner-", as.character(winners$group_id)), slot_b = paste0("A-group-runner-up-", as.character(runners_up$group_id[selected])),
    group_a = as.character(winners$group_id), group_b = as.character(runners_up$group_id[selected]),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  policy <- "nl-article17-qf-group-winner-different-group-runner-up-runner-up-home-v1"
  ids <- uefa_nl_sim_projection_ids(projection_run_id, policy, seed)
  slots <- uefa_nl_sim_stage_slots("league_a_quarter_final", "quarter_final", pairs, rules, ids$projection_run_id, ids$draw_policy_id)
  list(stage_slots = slots, slots = slots, pairings = pairs, draw_policy_id = ids$draw_policy_id, draw_policy_sha256 = ids$draw_policy_sha256, projection_run_id = ids$projection_run_id, official = FALSE)
}

uefa_nl_draw_semi_finals <- function(
    semi_finalists = NULL,
    host_association_id = NULL,
    association_map = NULL,
    seed = NULL,
    projection_run_id = NULL,
    rules = uefa_nl_2026_27_rules(),
    quarter_final_winners = NULL) {
  semi_finalists <- semi_finalists %||% quarter_final_winners
  finalists <- uefa_nl_sim_team_rows(semi_finalists, "League A semi-finalists")
  if (nrow(finalists) != 4L) stop("Nations League semi-final draw requires four semi-finalists", call. = FALSE)
  if (anyDuplicated(as.character(finalists$team_id))) stop("Nations League semi-final draw has duplicate teams", call. = FALSE)
  association <- rep(NA_character_, nrow(finalists))
  association_fields <- intersect(c("association_id", "host_association_id", "association"), names(finalists))
  if (length(association_fields)) association <- as.character(finalists[[association_fields[[1L]]]])
  if (!is.null(association_map)) {
    map <- as.data.frame(association_map, stringsAsFactors = FALSE, check.names = FALSE)
    if (all(c("team_id", "association_id") %in% names(map))) association <- as.character(map$association_id[match(as.character(finalists$team_id), as.character(map$team_id))])
  }
  host_index <- integer()
  if (length(host_association_id) && !is.na(host_association_id[[1L]])) {
    host_token <- as.character(host_association_id[[1L]])
    host_index <- which(association == host_token)
    if (!length(host_index)) host_index <- which(as.character(finalists$team_id) == host_token)
    if (length(host_index) > 1L) stop("Nations League semi-final host association maps to multiple teams", call. = FALSE)
  }
  host_team <- if (length(host_index)) {
    if (length(host_token) && host_token %in% association) as.character(finalists$team_id[which(association == host_token)[[1L]]]) else host_token
  } else {
    NA_character_
  }
  finalists <- finalists[order(as.character(finalists$team_id), method = "radix"), , drop = FALSE]
  if (length(host_index)) {
    if (is.na(host_team) || !nzchar(host_team)) host_team <- host_token
    host_position <- match(host_team, as.character(finalists$team_id))
    if (is.na(host_position)) stop("Nations League semi-final host association has no supplied team", call. = FALSE)
    remaining <- setdiff(seq_len(nrow(finalists)), host_position)
    opponent <- if (is.null(seed)) remaining[[1L]] else uefa_nl_sim_with_seed(seed, function() sample(remaining, 1L))
    rest <- setdiff(remaining, opponent)
    rest <- if (is.null(seed)) rest else uefa_nl_sim_with_seed(as.integer(seed) + 1L, function() sample(rest, length(rest)))
    order_index <- c(host_position, opponent, rest)
  } else {
    order_index <- if (is.null(seed)) seq_len(nrow(finalists)) else uefa_nl_sim_with_seed(seed, function() sample(seq_len(nrow(finalists)), nrow(finalists)))
  }
  finalists <- finalists[order_index, , drop = FALSE]
  pairings <- data.frame(
    tie_id = c("semi-final-1", "semi-final-2"), pair_index = 1:2, legs = 1L,
    team_a = as.character(finalists$team_id[c(1L, 3L)]), team_b = as.character(finalists$team_id[c(2L, 4L)]),
    slot_a = c("semi-finalist-1", "semi-finalist-3"), slot_b = c("semi-finalist-2", "semi-finalist-4"),
    group_a = NA_character_, group_b = NA_character_, stringsAsFactors = FALSE, check.names = FALSE
  )
  policy <- if (length(host_index)) "nl-article17-semi-host-association-first-v1" else "nl-article17-semi-seeded-open-draw-v1"
  ids <- uefa_nl_sim_projection_ids(projection_run_id, policy, seed)
  semi_pairs <- pairings
  semi_slots <- uefa_nl_sim_stage_slots("league_a_semi_final", "semi_final", semi_pairs, rules, ids$projection_run_id, ids$draw_policy_id)
  final_pairs <- data.frame(tie_id = "league-a-final", pair_index = 1L, legs = 1L, team_a = NA_character_, team_b = NA_character_, slot_a = "semi-final-1-winner", slot_b = "semi-final-2-winner", group_a = NA_character_, group_b = NA_character_, stringsAsFactors = FALSE, check.names = FALSE)
  third_pairs <- data.frame(tie_id = "league-a-third-place", pair_index = 1L, legs = 1L, team_a = NA_character_, team_b = NA_character_, slot_a = "semi-final-1-loser", slot_b = "semi-final-2-loser", group_a = NA_character_, group_b = NA_character_, stringsAsFactors = FALSE, check.names = FALSE)
  final_slots <- uefa_nl_sim_stage_slots("league_a_final", "final", final_pairs, rules, ids$projection_run_id, ids$draw_policy_id)
  third_slots <- uefa_nl_sim_stage_slots("league_a_third_place", "third_place", third_pairs, rules, ids$projection_run_id, ids$draw_policy_id)
  for (field in c("home_team_id", "away_team_id")) {
    final_slots[[field]] <- NA_character_
    third_slots[[field]] <- NA_character_
  }
  final_slots$participant_slot_home <- "semi-final-1-winner"
  final_slots$participant_slot_away <- "semi-final-2-winner"
  third_slots$participant_slot_home <- "semi-final-1-loser"
  third_slots$participant_slot_away <- "semi-final-2-loser"
  final_slots$row_sha256 <- uefa_nl_rules_row_sha256(final_slots, hash_col = "row_sha256")
  third_slots$row_sha256 <- uefa_nl_rules_row_sha256(third_slots, hash_col = "row_sha256")
  stage_slots <- rbind(semi_slots, final_slots, third_slots)
  row.names(stage_slots) <- NULL
  list(
    stage_slots = stage_slots, slots = stage_slots, semi_finals = semi_pairs,
    pairings = semi_pairs, final_slot = final_slots, third_place_slot = third_slots,
    final_team_a_source = "semi-final-1-winner", final_team_b_source = "semi-final-2-winner",
    third_place_team_a_source = "semi-final-1-loser", third_place_team_b_source = "semi-final-2-loser",
    host_association_id = if (length(host_association_id)) as.character(host_association_id[[1L]]) else NA_character_,
    draw_policy_id = ids$draw_policy_id, draw_policy_sha256 = ids$draw_policy_sha256,
    projection_run_id = ids$projection_run_id, official = FALSE
  )
}

# ---------------------------------------------------------------------------
# Full simulation boundary.
# ---------------------------------------------------------------------------

uefa_nl_sim_extract_table <- function(value, candidates = character()) {
  if (is.null(value)) return(NULL)
  if (is.data.frame(value)) return(as.data.frame(value, stringsAsFactors = FALSE, check.names = FALSE))
  if (!is.list(value)) stop("Nations League simulation table must be a data frame or named list", call. = FALSE)
  fields <- intersect(candidates, names(value))
  if (length(fields)) {
    field <- fields[[1L]]
    return(uefa_nl_sim_extract_table(value[[field]], candidates))
  }
  frames <- value[vapply(value, is.data.frame, logical(1))]
  if (length(frames)) {
    names_frames <- names(frames)
    frames <- lapply(seq_along(frames), function(index) {
      frame <- as.data.frame(frames[[index]], stringsAsFactors = FALSE, check.names = FALSE)
      if (!is.null(names_frames) && nzchar(names_frames[[index]]) && !"group_id" %in% names(frame)) frame$group_id <- names_frames[[index]]
      frame
    })
    all_names <- unique(unlist(lapply(frames, names), use.names = FALSE))
    frames <- lapply(frames, function(frame) {
      for (field in setdiff(all_names, names(frame))) frame[[field]] <- NA_character_
      frame[, all_names, drop = FALSE]
    })
    return(do.call(rbind, frames))
  }
  stop("Nations League simulation table does not contain a data frame", call. = FALSE)
}

uefa_nl_sim_canonical_table <- function(value, name, key = NULL) {
  if (is.null(value)) return(data.frame(stringsAsFactors = FALSE, check.names = FALSE))
  value <- uefa_nl_sim_extract_table(value, c(name, paste0(name, "s"), "rows", "table"))
  if (!is.data.frame(value)) stop("Nations League simulation ", name, " must be a data frame", call. = FALSE)
  value <- as.data.frame(value, stringsAsFactors = FALSE, check.names = FALSE)
  if (!nrow(value)) return(value)
  fields <- sort(names(value), method = "radix")
  ordering <- lapply(value[fields], uefa_nl_sim_hash_column)
  ordering$na.last <- TRUE
  ordering$method <- "radix"
  value <- value[do.call(order, ordering), , drop = FALSE]
  if (!is.null(key)) {
    keys <- intersect(key, names(value))
    if (length(keys)) {
      ordering <- lapply(value[keys], uefa_nl_sim_hash_column)
      ordering$na.last <- TRUE
      ordering$method <- "radix"
      value <- value[do.call(order, ordering), , drop = FALSE]
    }
  }
  row.names(value) <- NULL
  value
}

uefa_nl_sim_phase14_hash <- function(value, kind = "table") {
  if (is.null(value)) return(uefa_nl_sim_hash_data(data.frame(stringsAsFactors = FALSE)))
  if (kind == "score_distributions" && exists("phase14_state_bundle_hash_value", mode = "function", inherits = TRUE)) {
    result <- tryCatch(phase14_state_bundle_hash_value(value), error = function(error) NULL)
    if (is.character(result) && length(result) == 1L) return(tolower(result))
  }
  if (exists("phase14_forecast_hash_data", mode = "function", inherits = TRUE)) {
    result <- tryCatch(phase14_forecast_hash_data(value), error = function(error) NULL)
    if (is.character(result) && length(result) == 1L) return(tolower(result))
  }
  uefa_nl_sim_hash_data(value)
}

uefa_nl_sim_seed_for <- function(seed, ...) {
  token <- uefa_nl_sim_hash_data(list(seed = as.integer(seed), ...))
  value <- suppressWarnings(strtoi(substr(token, 1L, 7L), base = 16L))
  if (is.na(value) || value < 0L) value <- 1L
  as.integer(value %% (.Machine$integer.max - 1L) + 1L)
}

uefa_nl_sim_normalize_count <- function(value) {
  value <- suppressWarnings(as.integer(value))
  if (length(value) != 1L || is.na(value) || value < 1L) stop("Nations League simulation_count must be a positive integer", call. = FALSE)
  value
}

uefa_nl_sim_normalize_seed <- function(value) {
  value <- suppressWarnings(as.integer(value))
  if (length(value) != 1L || is.na(value) || value < 0L) stop("Nations League simulation seed must be one non-negative integer", call. = FALSE)
  value
}

uefa_nl_sim_first_present <- function(row, fields, default = NA_character_) {
  fields <- intersect(fields, names(row))
  if (!length(fields)) return(default)
  for (field in fields) {
    value <- row[[field]][[1L]]
    if (length(value) && !is.na(value) && nzchar(trimws(as.character(value)))) return(as.character(value))
  }
  default
}

uefa_nl_sim_parse_timestamp <- function(value) {
  if (is.null(value) || !length(value) || is.na(value[[1L]]) || !nzchar(trimws(as.character(value[[1L]])))) return(as.POSIXct(NA, tz = "UTC"))
  parsed <- suppressWarnings(as.POSIXct(as.character(value[[1L]]), tz = "UTC"))
  if (is.na(parsed)) stop("Nations League simulation timestamp is invalid", call. = FALSE)
  parsed
}

uefa_nl_sim_status_is_completed <- function(value) {
  tolower(trimws(as.character(value))) %in% c(
    "completed", "complete", "finished", "full_time", "full-time", "final",
    "after_extra_time", "after-extra-time", "after_penalties", "after-penalties", "awarded"
  )
}

uefa_nl_sim_status_is_open <- function(value) {
  !uefa_nl_sim_status_is_completed(value) & !tolower(trimws(as.character(value))) %in% c("cancelled", "canceled", "abandoned")
}

uefa_nl_sim_score_present <- function(row) {
  home <- uefa_nl_sim_row_value(row, c("final_home_goals", "home_goals", "regulation_home_goals"), NA_real_)
  away <- uefa_nl_sim_row_value(row, c("final_away_goals", "away_goals", "regulation_away_goals"), NA_real_)
  home <- suppressWarnings(as.numeric(as.character(home)))
  away <- suppressWarnings(as.numeric(as.character(away)))
  length(home) == 1L && length(away) == 1L && is.finite(home) && is.finite(away) && home >= 0 && away >= 0 && home == floor(home) && away == floor(away)
}

uefa_nl_sim_cutoff_for_row <- function(row, default = as.POSIXct("2099-12-31 23:59:59", tz = "UTC")) {
  fields <- intersect(c("state_cutoff_utc", "simulation_cutoff_utc", "cutoff_utc"), names(row))
  if (!length(fields)) return(default)
  parsed <- uefa_nl_sim_parse_timestamp(row[[fields[[1L]]]])
  if (is.na(parsed)) default else parsed
}

uefa_nl_sim_admit_completed_results <- function(canonical_matches, completed_results, edition_id, source_bundle_id) {
  canonical <- as.data.frame(canonical_matches, stringsAsFactors = FALSE, check.names = FALSE)
  results <- as.data.frame(completed_results, stringsAsFactors = FALSE, check.names = FALSE)
  if (!nrow(results)) return(canonical)
  id_field <- intersect(c("fixture_id", "match_id", "source_fixture_id"), names(results))
  canonical_id_field <- intersect(c("fixture_id", "match_id", "source_fixture_id"), names(canonical))
  if (!length(id_field) || !length(canonical_id_field)) stop("Nations League completed results require a canonical fixture identity", call. = FALSE)
  result_ids <- trimws(as.character(results[[id_field[[1L]]]]))
  canonical_ids <- trimws(as.character(canonical[[canonical_id_field[[1L]]]]))
  if (any(is.na(result_ids) | !nzchar(result_ids)) || anyDuplicated(result_ids)) stop("Nations League completed results have missing or duplicate fixture IDs", call. = FALSE)
  if (any(!result_ids %in% canonical_ids)) stop("Nations League completed results contain a foreign fixture", call. = FALSE)
  for (result_index in seq_len(nrow(results))) {
    target <- match(result_ids[[result_index]], canonical_ids)
    result <- results[result_index, , drop = FALSE]
    completed <- uefa_nl_sim_status_is_completed(uefa_nl_sim_first_present(result, c("match_status", "source_status", "stage_status"), "completed"))
    admitted <- completed && uefa_nl_sim_score_present(result)
    if (!admitted) next
    for (field in intersect(names(result), names(canonical))) canonical[[field]][target] <- result[[field]][[1L]]
    new_fields <- setdiff(names(result), names(canonical))
    for (field in new_fields) {
      canonical[[field]] <- rep(NA, nrow(canonical))
      canonical[[field]][target] <- result[[field]][[1L]]
    }
    if ("edition_id" %in% names(canonical)) canonical$edition_id[[target]] <- edition_id
    if (!"source_bundle_id" %in% names(canonical)) canonical$source_bundle_id <- source_bundle_id
    canonical$source_bundle_id[[target]] <- source_bundle_id
    if (!"match_status" %in% names(canonical)) canonical$match_status <- "scheduled"
    canonical$match_status[[target]] <- "completed"
    if (!"counts_for_standings" %in% names(canonical)) canonical$counts_for_standings <- FALSE
    canonical$counts_for_standings[[target]] <- TRUE
  }
  canonical
}

uefa_nl_sim_normalize_matches <- function(canonical_matches, completed_results, rules, source_bundle_id) {
  matches <- uefa_nl_sim_canonical_table(canonical_matches, "canonical_matches", key = c("stage_id", "group_id", "fixture_id", "match_id"))
  if (!nrow(matches)) stop("Nations League simulation canonical_matches must not be empty", call. = FALSE)
  edition_id <- as.character(rules$edition_id)
  if (!"edition_id" %in% names(matches)) matches$edition_id <- edition_id
  if (any(!is.na(matches$edition_id) & nzchar(as.character(matches$edition_id)) & as.character(matches$edition_id) != edition_id)) stop("Nations League simulation canonical_matches contain a foreign edition", call. = FALSE)
  matches$edition_id <- edition_id
  id_field <- intersect(c("fixture_id", "match_id", "source_fixture_id"), names(matches))
  if (!length(id_field)) stop("Nations League simulation canonical_matches require fixture_id or match_id", call. = FALSE)
  matches$fixture_id <- trimws(as.character(matches[[id_field[[1L]]]]))
  if (any(is.na(matches$fixture_id) | !nzchar(matches$fixture_id)) || anyDuplicated(matches$fixture_id)) stop("Nations League simulation canonical_matches require unique fixture IDs", call. = FALSE)
  if (!"match_id" %in% names(matches)) matches$match_id <- matches$fixture_id
  if (!"stage_id" %in% names(matches)) matches$stage_id <- "league_phase"
  matches$stage_id <- uefa_nl_rank_final_stage_id(matches$stage_id)
  matches$stage_id[is.na(matches$stage_id) | !nzchar(matches$stage_id)] <- "league_phase"
  if (!"group_id" %in% names(matches)) matches$group_id <- NA_character_
  if (!"league_id" %in% names(matches) && "league" %in% names(matches)) matches$league_id <- as.character(matches$league)
  if (!"league" %in% names(matches) && "league_id" %in% names(matches)) matches$league <- as.character(matches$league_id)
  if (!"home_team_id" %in% names(matches) || !"away_team_id" %in% names(matches)) stop("Nations League simulation canonical_matches require home_team_id and away_team_id", call. = FALSE)
  matches$home_team_id <- trimws(as.character(matches$home_team_id))
  matches$away_team_id <- trimws(as.character(matches$away_team_id))
  if (any(is.na(matches$home_team_id) | !nzchar(matches$home_team_id) | is.na(matches$away_team_id) | !nzchar(matches$away_team_id) | matches$home_team_id == matches$away_team_id)) stop("Nations League simulation canonical_matches contain invalid team pairs", call. = FALSE)
  if (!"source_bundle_id" %in% names(matches)) matches$source_bundle_id <- source_bundle_id
  matches$source_bundle_id <- source_bundle_id
  if (!"match_status" %in% names(matches)) {
    status_field <- intersect(c("source_status", "status"), names(matches))
    matches$match_status <- if (length(status_field)) as.character(matches[[status_field[[1L]]]]) else "scheduled"
  }
  if (!"source_status" %in% names(matches)) matches$source_status <- as.character(matches$match_status)
  if (!"counts_for_standings" %in% names(matches)) matches$counts_for_standings <- uefa_nl_sim_status_is_completed(matches$match_status) & matches$stage_id == "league_phase"
  matches$counts_for_standings <- as.logical(ifelse(is.na(matches$counts_for_standings), FALSE, matches$counts_for_standings))
  score_aliases <- list(
    final_home_goals = c("final_home_goals", "home_goals", "regulation_home_goals"),
    final_away_goals = c("final_away_goals", "away_goals", "regulation_away_goals"),
    regulation_home_goals = c("regulation_home_goals", "home_goals", "final_home_goals"),
    regulation_away_goals = c("regulation_away_goals", "away_goals", "final_away_goals")
  )
  for (field in names(score_aliases)) if (!field %in% names(matches)) {
    alias <- intersect(score_aliases[[field]], names(matches))
    matches[[field]] <- if (length(alias)) suppressWarnings(as.integer(as.character(matches[[alias[[1L]]]]))) else rep(NA_integer_, nrow(matches))
  }
  for (field in c("extra_time_home_goals", "extra_time_away_goals", "penalty_shootout_home_goals", "penalty_shootout_away_goals")) if (!field %in% names(matches)) matches[[field]] <- rep(NA_integer_, nrow(matches))
  if (!"completed_at_utc" %in% names(matches)) matches$completed_at_utc <- NA_character_
  if (!"evidence_completed_at_utc" %in% names(matches)) matches$evidence_completed_at_utc <- as.character(matches$completed_at_utc)
  matches <- uefa_nl_sim_admit_completed_results(matches, completed_results, edition_id, source_bundle_id)
  matches <- uefa_nl_sim_canonical_table(matches, "canonical_matches", key = c("stage_id", "group_id", "fixture_id"))
  matches
}

uefa_nl_sim_normalize_groups <- function(groups, matches, rules) {
  group_rows <- if (is.list(groups) && !is.data.frame(groups)) {
    uefa_nl_sim_extract_table(groups, c("group_rows", "access_list", "teams", "rows"))
  } else {
    NULL
  }
  supplied <- uefa_nl_sim_extract_table(groups, c("groups", "group_rows", "teams", "rows"))
  if (is.null(supplied)) supplied <- data.frame(stringsAsFactors = FALSE, check.names = FALSE)
  supplied <- as.data.frame(supplied, stringsAsFactors = FALSE, check.names = FALSE)
  if (!nrow(supplied)) {
    group_ids <- sort(unique(as.character(matches$group_id[!is.na(matches$group_id) & nzchar(as.character(matches$group_id))])), method = "radix")
    rows <- lapply(group_ids, function(group_id) {
      group_matches <- matches[as.character(matches$group_id) == group_id, , drop = FALSE]
      teams <- sort(unique(c(as.character(group_matches$home_team_id), as.character(group_matches$away_team_id))), method = "radix")
      league_field <- intersect(c("league", "league_id"), names(group_matches))
      league <- if (length(league_field) && nrow(group_matches)) as.character(group_matches[[league_field[[1L]]]][[1L]]) else NA_character_
      data.frame(edition_id = rules$edition_id, team_id = teams, league = league, league_id = league, group_id = group_id, stringsAsFactors = FALSE, check.names = FALSE)
    })
    supplied <- if (length(rows)) do.call(rbind, rows) else data.frame(stringsAsFactors = FALSE, check.names = FALSE)
  }
  if (!"group_id" %in% names(supplied)) {
    field <- intersect(c("source_group_id", "published_group_id", "group"), names(supplied))
    if (length(field)) supplied$group_id <- as.character(supplied[[field[[1L]]]])
  }
  if (!"team_id" %in% names(supplied)) {
    group_ids <- trimws(as.character(supplied$group_id))
    expanded <- lapply(seq_len(nrow(supplied)), function(index) {
      group_id <- group_ids[[index]]
      group_matches <- matches[as.character(matches$group_id) == group_id, , drop = FALSE]
      teams <- sort(unique(c(as.character(group_matches$home_team_id), as.character(group_matches$away_team_id))), method = "radix")
      row <- supplied[index, , drop = FALSE][rep(1L, length(teams)), , drop = FALSE]
      row$team_id <- teams
      row
    })
    supplied <- if (length(expanded)) do.call(rbind, expanded) else data.frame(stringsAsFactors = FALSE, check.names = FALSE)
  }
  # Phase 14 supplies group definitions and admitted team rows separately.  Keep
  # the definition as the source of group identity, then carry only explicit
  # team-level access metadata into the simulation boundary.
  if (is.data.frame(group_rows) && nrow(group_rows) && "team_id" %in% names(group_rows)) {
    group_rows <- as.data.frame(group_rows, stringsAsFactors = FALSE, check.names = FALSE)
    if (!"group_id" %in% names(group_rows)) {
      field <- intersect(c("source_group_id", "published_group_id", "group"), names(group_rows))
      if (length(field)) group_rows$group_id <- as.character(group_rows[[field[[1L]]]])
    }
    if ("group_id" %in% names(group_rows)) {
      group_rows$team_id <- trimws(as.character(group_rows$team_id))
      group_rows$group_id <- trimws(as.character(group_rows$group_id))
      for (field in setdiff(names(group_rows), names(supplied))) supplied[[field]] <- NA
      join <- match(paste(supplied$group_id, supplied$team_id, sep = "::"), paste(group_rows$group_id, group_rows$team_id, sep = "::"))
      for (field in setdiff(names(group_rows), c("group_id", "team_id"))) {
        missing_value <- is.na(supplied[[field]]) | !nzchar(trimws(as.character(supplied[[field]])))
        supplied[[field]][missing_value & !is.na(join)] <- group_rows[[field]][join[missing_value & !is.na(join)]]
      }
    }
  }
  if (!"group_id" %in% names(supplied) || !"team_id" %in% names(supplied)) stop("Nations League simulation groups require group_id and team_id", call. = FALSE)
  if (!"league" %in% names(supplied)) {
    field <- intersect(c("league_id", "league_name"), names(supplied))
    supplied$league <- if (length(field)) as.character(supplied[[field[[1L]]]]) else NA_character_
  }
  if (!"league_id" %in% names(supplied)) supplied$league_id <- as.character(supplied$league)
  if (!"edition_id" %in% names(supplied)) supplied$edition_id <- rules$edition_id
  supplied$edition_id <- as.character(supplied$edition_id)
  supplied$group_id <- trimws(as.character(supplied$group_id))
  supplied$team_id <- trimws(as.character(supplied$team_id))
  supplied$league <- toupper(trimws(as.character(supplied$league)))
  supplied$league_id <- supplied$league
  if (any(is.na(supplied$group_id) | !nzchar(supplied$group_id) | is.na(supplied$team_id) | !nzchar(supplied$team_id))) stop("Nations League simulation groups contain missing group or team IDs", call. = FALSE)
  if (anyDuplicated(supplied$team_id)) stop("Nations League simulation groups assign a team to more than one group", call. = FALSE)
  if (any(!supplied$team_id %in% unique(c(matches$home_team_id, matches$away_team_id)))) stop("Nations League simulation groups contain a team absent from canonical matches", call. = FALSE)
  if (any(is.na(supplied$league) | !supplied$league %in% c("A", "B", "C", "D"))) stop("Nations League simulation groups contain an unknown league", call. = FALSE)
  if (!"access_list_position" %in% names(supplied)) {
    field <- intersect(c("access_position", "access_rank", "position_in_access_list"), names(supplied))
    supplied$access_list_position <- if (length(field)) suppressWarnings(as.integer(as.character(supplied[[field[[1L]]]]))) else NA_integer_
  }
  supplied$access_list_position <- suppressWarnings(as.integer(as.character(supplied$access_list_position)))
  if (!"discipline_points" %in% names(supplied)) {
    field <- intersect(c("discipline", "disciplinary_points", "cards_points"), names(supplied))
    supplied$discipline_points <- if (length(field)) suppressWarnings(as.integer(as.character(supplied[[field[[1L]]]]))) else NA_integer_
  }
  supplied$discipline_points <- suppressWarnings(as.integer(as.character(supplied$discipline_points)))
  supplied <- uefa_nl_sim_canonical_table(supplied, "groups", key = c("league", "group_id", "team_id"))
  supplied
}

uefa_nl_sim_normalize_status <- function(forecast_status, rules) {
  status <- uefa_nl_sim_extract_table(forecast_status, c("fixture_status", "forecast_status", "status", "rows"))
  if (is.null(status)) stop("Nations League simulation forecast_status is required", call. = FALSE)
  if (!is.data.frame(status)) stop("Nations League simulation forecast_status must be a data frame", call. = FALSE)
  status <- as.data.frame(status, stringsAsFactors = FALSE, check.names = FALSE)
  id_field <- intersect(c("fixture_id", "match_id", "source_fixture_id"), names(status))
  if (!length(id_field)) stop("Nations League simulation forecast_status requires fixture_id", call. = FALSE)
  status$fixture_id <- trimws(as.character(status[[id_field[[1L]]]]))
  if (any(is.na(status$fixture_id) | !nzchar(status$fixture_id)) || anyDuplicated(status$fixture_id)) stop("Nations League simulation forecast_status requires unique fixture IDs", call. = FALSE)
  if (!"forecast_status" %in% names(status)) {
    status_field <- intersect(c("status", "state"), names(status))
    if (!length(status_field)) stop("Nations League simulation forecast_status requires forecast_status", call. = FALSE)
    status$forecast_status <- as.character(status[[status_field[[1L]]]])
  }
  status$forecast_status <- tolower(trimws(as.character(status$forecast_status)))
  if (!"suppression_reason" %in% names(status)) status$suppression_reason <- ifelse(status$forecast_status == "available", "none", "forecast_unavailable")
  if (!"edition_id" %in% names(status)) status$edition_id <- rules$edition_id
  status$edition_id <- as.character(status$edition_id)
  if (any(!is.na(status$edition_id) & nzchar(status$edition_id) & status$edition_id != rules$edition_id)) stop("Nations League simulation forecast_status contains a foreign edition", call. = FALSE)
  uefa_nl_sim_canonical_table(status, "forecast_status", key = c("fixture_id"))
}

uefa_nl_sim_normalize_forecasts <- function(forecasts, rules) {
  output <- uefa_nl_sim_extract_table(forecasts, c("forecasts", "forecast", "rows"))
  if (is.null(output)) output <- data.frame(stringsAsFactors = FALSE, check.names = FALSE)
  output <- as.data.frame(output, stringsAsFactors = FALSE, check.names = FALSE)
  if (!nrow(output)) return(output)
  id_field <- intersect(c("fixture_id", "match_id", "source_fixture_id"), names(output))
  if (!length(id_field)) stop("Nations League simulation forecasts require fixture_id", call. = FALSE)
  output$fixture_id <- trimws(as.character(output[[id_field[[1L]]]]))
  if (any(is.na(output$fixture_id) | !nzchar(output$fixture_id)) || anyDuplicated(output$fixture_id)) stop("Nations League simulation forecasts require unique fixture IDs", call. = FALSE)
  if (!"edition_id" %in% names(output)) output$edition_id <- rules$edition_id
  if (!"stage_id" %in% names(output)) output$stage_id <- "league_phase"
  output$stage_id <- uefa_nl_rank_final_stage_id(output$stage_id)
  uefa_nl_sim_canonical_table(output, "forecasts", key = c("stage_id", "fixture_id"))
}

uefa_nl_sim_normalize_score_distributions <- function(score_distributions) {
  output <- uefa_nl_sim_extract_table(score_distributions, c("score_distributions", "score_distribution", "local_score_distributions", "grid", "rows"))
  if (is.null(output)) output <- data.frame(stringsAsFactors = FALSE, check.names = FALSE)
  output <- as.data.frame(output, stringsAsFactors = FALSE, check.names = FALSE)
  if (!nrow(output)) return(output)
  uefa_nl_sim_canonical_table(output, "score_distributions", key = c("score_distribution_id", "fixture_id", "home_goals", "away_goals"))
}

uefa_nl_sim_normalize_stage_slots <- function(official_stage_slots, rules) {
  slots <- uefa_nl_sim_extract_table(official_stage_slots, c("official_stage_slots", "stage_slots", "stage_capture", "capture", "rows"))
  if (is.null(slots)) return(data.frame(stringsAsFactors = FALSE, check.names = FALSE))
  slots <- as.data.frame(slots, stringsAsFactors = FALSE, check.names = FALSE)
  if (!nrow(slots)) return(slots)
  if (!"edition_id" %in% names(slots)) slots$edition_id <- rules$edition_id
  if (!"stage_id" %in% names(slots)) stop("Nations League official_stage_slots require stage_id", call. = FALSE)
  slots$stage_id <- uefa_nl_rank_final_stage_id(slots$stage_id)
  topology <- uefa_nl_stage_topology(rules)
  if (any(!slots$stage_id %in% topology$stage_id)) stop("Nations League official_stage_slots contain an unknown stage", call. = FALSE)
  if (!"stage_type" %in% names(slots)) slots$stage_type <- topology$stage_type[match(slots$stage_id, topology$stage_id)]
  if (!"stage_status" %in% names(slots)) {
    field <- intersect(c("source_status", "status"), names(slots))
    slots$stage_status <- if (length(field)) tolower(trimws(as.character(slots[[field[[1L]]]]))) else "official"
  }
  slots$stage_status <- tolower(trimws(as.character(slots$stage_status)))
  slots$stage_status[slots$stage_status %in% c("finished", "full_time", "after_extra_time", "after_penalties")] <- "completed"
  if (!"leg_number" %in% names(slots)) slots$leg_number <- seq_len(nrow(slots))
  slots$leg_number <- suppressWarnings(as.integer(as.character(slots$leg_number)))
  if (!"participant_slot_home" %in% names(slots)) slots$participant_slot_home <- as.character(slots$home_team_id %||% "")
  if (!"participant_slot_away" %in% names(slots)) slots$participant_slot_away <- as.character(slots$away_team_id %||% "")
  if (!"home_team_id" %in% names(slots)) slots$home_team_id <- NA_character_
  if (!"away_team_id" %in% names(slots)) slots$away_team_id <- NA_character_
  slots$home_team_id <- trimws(as.character(slots$home_team_id))
  slots$away_team_id <- trimws(as.character(slots$away_team_id))
  if (!"source_fixture_id" %in% names(slots)) slots$source_fixture_id <- ""
  if (!"source_artifact_id" %in% names(slots)) slots$source_artifact_id <- ""
  if (!"projection_run_id" %in% names(slots)) slots$projection_run_id <- ""
  if (!"draw_policy_id" %in% names(slots)) slots$draw_policy_id <- "official_stage_capture"
  if (!"unresolved_reason" %in% names(slots)) slots$unresolved_reason <- ""
  if (!"suppression_reason" %in% names(slots)) slots$suppression_reason <- ""
  slots <- uefa_nl_sim_canonical_table(slots, "official_stage_slots", key = c("stage_id", "leg_number", "source_fixture_id", "participant_slot_home", "participant_slot_away"))
  slots
}

uefa_nl_sim_fixture_grid <- function(score_distributions, forecast_row) {
  fixture_id <- as.character(forecast_row$fixture_id[[1L]])
  score_id <- if ("score_distribution_id" %in% names(forecast_row)) as.character(forecast_row$score_distribution_id[[1L]]) else NA_character_
  grid <- score_distributions
  if (!is.data.frame(grid) || !nrow(grid)) return(NULL)
  if (!is.na(score_id) && nzchar(score_id) && "score_distribution_id" %in% names(grid)) {
    candidate <- grid[as.character(grid$score_distribution_id) == score_id, , drop = FALSE]
    if (nrow(candidate)) return(candidate)
  }
  if ("fixture_id" %in% names(grid)) {
    candidate <- grid[as.character(grid$fixture_id) == fixture_id, , drop = FALSE]
    if (nrow(candidate)) return(candidate)
  }
  if ("score_distribution_id" %in% names(grid)) {
    candidate <- grid[as.character(grid$score_distribution_id) %in% c(paste0(fixture_id, "__score"), fixture_id), , drop = FALSE]
    if (nrow(candidate)) return(candidate)
  }
  NULL
}

uefa_nl_sim_forecast_status_for_id <- function(status, fixture_id) {
  row <- status[as.character(status$fixture_id) == as.character(fixture_id), , drop = FALSE]
  if (nrow(row) != 1L) return(NULL)
  row
}

uefa_nl_sim_find_forecast <- function(
    forecasts, status, stage_id, home_team_id = NULL, away_team_id = NULL,
    fixture_id = NULL, leg_number = NULL, participant_slot_home = NULL, participant_slot_away = NULL) {
  if (!is.data.frame(forecasts) || !nrow(forecasts)) return(NULL)
  candidate <- forecasts
  if (!is.null(fixture_id) && length(fixture_id) && !is.na(fixture_id) && nzchar(as.character(fixture_id))) candidate <- candidate[as.character(candidate$fixture_id) == as.character(fixture_id), , drop = FALSE]
  if ("stage_id" %in% names(candidate)) candidate <- candidate[uefa_nl_rank_final_stage_id(candidate$stage_id) == uefa_nl_rank_final_stage_id(stage_id), , drop = FALSE]
  if (!is.null(home_team_id) && "home_team_id" %in% names(candidate)) candidate <- candidate[as.character(candidate$home_team_id) == as.character(home_team_id), , drop = FALSE]
  if (!is.null(away_team_id) && "away_team_id" %in% names(candidate)) candidate <- candidate[as.character(candidate$away_team_id) == as.character(away_team_id), , drop = FALSE]
  if (!is.null(leg_number) && "leg_number" %in% names(candidate)) candidate <- candidate[suppressWarnings(as.integer(as.character(candidate$leg_number))) == as.integer(leg_number), , drop = FALSE]
  if (!is.null(participant_slot_home) && "participant_slot_home" %in% names(candidate)) candidate <- candidate[as.character(candidate$participant_slot_home) == as.character(participant_slot_home), , drop = FALSE]
  if (!is.null(participant_slot_away) && "participant_slot_away" %in% names(candidate)) candidate <- candidate[as.character(candidate$participant_slot_away) == as.character(participant_slot_away), , drop = FALSE]
  if (nrow(candidate) != 1L) return(NULL)
  status_row <- uefa_nl_sim_forecast_status_for_id(status, candidate$fixture_id[[1L]])
  if (is.null(status_row) || !identical(as.character(status_row$forecast_status[[1L]]), "available")) return(NULL)
  candidate
}

uefa_nl_sim_stage_tie_id <- function(rows, stage_id, index = 1L) {
  explicit <- intersect(c("tie_id", "matchup_id", "pair_id", "participant_pair_id"), names(rows))
  if (length(explicit)) {
    value <- trimws(as.character(rows[[explicit[[1L]]]]))
    if (length(value) && !is.na(value[[1L]]) && nzchar(value[[1L]])) return(value[[1L]])
  }
  slots <- intersect(c("participant_slot_home", "participant_slot_away"), names(rows))
  if (length(slots) == 2L) {
    values <- trimws(as.character(rows[1L, slots, drop = TRUE]))
    values <- values[!is.na(values) & nzchar(values)]
    if (length(values) == 2L) return(paste(stage_id, paste(sort(values, method = "radix"), collapse = "::"), sep = "::"))
  }
  teams <- intersect(c("home_team_id", "away_team_id"), names(rows))
  if (length(teams) == 2L) {
    values <- trimws(as.character(rows[1L, teams, drop = TRUE]))
    values <- values[!is.na(values) & nzchar(values)]
    if (length(values) == 2L) return(paste(stage_id, paste(sort(values, method = "radix"), collapse = "::"), sep = "::"))
  }
  paste(stage_id, as.integer(index), sep = "::")
}

uefa_nl_sim_pairings_from_slots <- function(slots, stage_id, rules) {
  if (!is.data.frame(slots) || !nrow(slots)) return(data.frame(stringsAsFactors = FALSE, check.names = FALSE))
  stage <- slots[slots$stage_id == stage_id, , drop = FALSE]
  if (!nrow(stage)) return(data.frame(stringsAsFactors = FALSE, check.names = FALSE))
  stage <- stage[order(as.integer(stage$leg_number), as.character(stage$source_fixture_id), as.character(stage$participant_slot_home), method = "radix"), , drop = FALSE]
  stage$.__tie_id <- vapply(seq_len(nrow(stage)), function(index) uefa_nl_sim_stage_tie_id(stage[index, , drop = FALSE], stage_id, index), character(1))
  tie_ids <- unique(stage$.__tie_id)
  topology <- uefa_nl_stage_topology(rules)
  legs <- topology$legs[match(stage_id, topology$stage_id)]
  rows <- lapply(seq_along(tie_ids), function(index) {
    tie <- stage[stage$.__tie_id == tie_ids[[index]], , drop = FALSE]
    tie <- tie[order(as.integer(tie$leg_number), as.character(tie$source_fixture_id), method = "radix"), , drop = FALSE]
    if (as.integer(legs) == 2L && nrow(tie) != 2L) return(NULL)
    if (as.integer(legs) == 1L && nrow(tie) < 1L) return(NULL)
    if (as.integer(legs) == 2L) {
      first <- tie[1L, , drop = FALSE]
      second <- tie[2L, , drop = FALSE]
      team_a <- uefa_nl_sim_first_present(first, c("away_team_id", "team_a"), NA_character_)
      team_b <- uefa_nl_sim_first_present(first, c("home_team_id", "team_b"), NA_character_)
      if (is.na(team_a) || is.na(team_b) || !nzchar(team_a) || !nzchar(team_b)) {
        team_a <- uefa_nl_sim_first_present(second, c("home_team_id", "team_a"), NA_character_)
        team_b <- uefa_nl_sim_first_present(second, c("away_team_id", "team_b"), NA_character_)
      }
      data.frame(
        tie_id = tie_ids[[index]], pair_index = index, legs = 2L,
        team_a = team_a, team_b = team_b,
        slot_a = uefa_nl_sim_first_present(first, c("participant_slot_away", "slot_a"), team_a),
        slot_b = uefa_nl_sim_first_present(first, c("participant_slot_home", "slot_b"), team_b),
        group_a = NA_character_, group_b = NA_character_,
        stringsAsFactors = FALSE, check.names = FALSE
      )
    } else {
      row <- tie[1L, , drop = FALSE]
      data.frame(
        tie_id = tie_ids[[index]], pair_index = index, legs = 1L,
        team_a = uefa_nl_sim_first_present(row, c("home_team_id", "team_a"), NA_character_),
        team_b = uefa_nl_sim_first_present(row, c("away_team_id", "team_b"), NA_character_),
        slot_a = uefa_nl_sim_first_present(row, c("participant_slot_home", "slot_a"), NA_character_),
        slot_b = uefa_nl_sim_first_present(row, c("participant_slot_away", "slot_b"), NA_character_),
        group_a = NA_character_, group_b = NA_character_,
        stringsAsFactors = FALSE, check.names = FALSE
      )
    }
  })
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (!length(rows)) return(data.frame(stringsAsFactors = FALSE, check.names = FALSE))
  output <- do.call(rbind, rows)
  output <- output[!is.na(output$team_a) & !is.na(output$team_b) & nzchar(output$team_a) & nzchar(output$team_b) & output$team_a != output$team_b, , drop = FALSE]
  row.names(output) <- NULL
  output
}

uefa_nl_sim_projected_slot_rows <- function(stage_id, stage_type, pairings, rules, projection_run_id, draw_policy_id) {
  if (!is.data.frame(pairings) || !nrow(pairings)) return(data.frame(stringsAsFactors = FALSE, check.names = FALSE))
  slots <- uefa_nl_sim_stage_slots(stage_id, stage_type, pairings, rules, projection_run_id, draw_policy_id, source_status = "projected")
  slots
}

uefa_nl_sim_forecast_match_row <- function(
    forecasts, status, score_distributions, stage_id, home_team_id, away_team_id,
    leg_number = 1L, fixture_id = NULL, participant_slot_home = NULL,
    participant_slot_away = NULL, seed = NULL, projection_run_id = "", draw_policy_id = "") {
  forecast <- uefa_nl_sim_find_forecast(
    forecasts, status, stage_id = stage_id, home_team_id = home_team_id,
    away_team_id = away_team_id, fixture_id = fixture_id, leg_number = leg_number,
    participant_slot_home = participant_slot_home, participant_slot_away = participant_slot_away
  )
  if (is.null(forecast)) return(NULL)
  grid <- uefa_nl_sim_fixture_grid(score_distributions, forecast)
  if (is.null(grid)) return(NULL)
  sampled <- uefa_nl_sample_stage_match(
    forecast = forecast,
    score_distribution = grid,
    seed = seed,
    stage_id = stage_id,
    stage_status = "projected",
    projection_run_id = projection_run_id,
    draw_policy_id = draw_policy_id
  )
  sampled$leg_number <- as.integer(leg_number)
  sampled$participant_slot_home <- as.character(participant_slot_home %||% home_team_id)
  sampled$participant_slot_away <- as.character(participant_slot_away %||% away_team_id)
  sampled$home_team_id <- as.character(home_team_id)
  sampled$away_team_id <- as.character(away_team_id)
  sampled$fixture_id <- as.character(forecast$fixture_id[[1L]])
  sampled$match_id <- sampled$fixture_id
  sampled
}

uefa_nl_sim_stage_resolution_row <- function(iteration, stage_id, tie_id, resolution, stage_status = NULL, source_status = "projected") {
  status <- stage_status %||% resolution$stage_status %||% "unresolved"
  data.frame(
    iteration = as.integer(iteration), stage_id = as.character(stage_id), tie_id = as.character(tie_id),
    stage_status = as.character(status), source_status = as.character(source_status),
    winner_team_id = as.character(resolution$winner_team_id %||% NA_character_),
    loser_team_id = as.character(resolution$loser_team_id %||% NA_character_),
    resolution = as.character(resolution$resolution %||% "unresolved"),
    extra_time_used = isTRUE(resolution$extra_time_used), penalty_used = isTRUE(resolution$penalty_used),
    unresolved_reason = as.character(resolution$unresolved_reason %||% ""),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

uefa_nl_sim_stage_match_rows_from_official <- function(slots, stage_id, tie_id) {
  if (!is.data.frame(slots) || !nrow(slots)) return(data.frame(stringsAsFactors = FALSE, check.names = FALSE))
  stage <- slots[slots$stage_id == stage_id, , drop = FALSE]
  if (!nrow(stage)) return(stage)
  stage$.__tie_id <- vapply(seq_len(nrow(stage)), function(index) uefa_nl_sim_stage_tie_id(stage[index, , drop = FALSE], stage_id, index), character(1))
  stage <- stage[stage$.__tie_id == tie_id, setdiff(names(stage), ".__tie_id"), drop = FALSE]
  stage[order(as.integer(stage$leg_number), as.character(stage$source_fixture_id), method = "radix"), , drop = FALSE]
}

uefa_nl_sim_resolve_stage_pair <- function(
    pair, stage_id, iteration, official_slots, forecasts, status, score_distributions,
    rules, seed, projection_run_id, draw_policy_id, lower_league_team_id = NULL) {
  topology <- uefa_nl_stage_topology(rules)
  stage_type <- as.character(topology$stage_type[match(stage_id, topology$stage_id)])
  official <- uefa_nl_sim_stage_match_rows_from_official(official_slots, stage_id, pair$tie_id[[1L]])
  if (nrow(official)) {
    status_values <- tolower(trimws(as.character(official$stage_status)))
    if (all(status_values == "completed")) {
      resolution <- if (as.integer(pair$legs[[1L]]) == 2L) {
        uefa_nl_resolve_two_leg_tie(official, seed = uefa_nl_sim_seed_for(seed, stage = stage_id, tie = pair$tie_id[[1L]], mode = "official"), rules = rules, lower_league_team_id = lower_league_team_id)
      } else {
        uefa_nl_resolve_single_leg(official[1L, , drop = FALSE], mode = if (stage_id == "league_a_third_place") "direct_penalty" else "final", seed = uefa_nl_sim_seed_for(seed, stage = stage_id, tie = pair$tie_id[[1L]], mode = "official"), rules = rules)
      }
      return(list(
        rows = official, resolution = uefa_nl_sim_stage_resolution_row(iteration, stage_id, pair$tie_id[[1L]], resolution, stage_status = "completed", source_status = "official")
      ))
    }
  }
  if (is.data.frame(official) && nrow(official) && any(tolower(trimws(as.character(official$stage_status))) == "suppressed")) {
    resolution <- uefa_nl_sim_resolution(stage_status = "suppressed", resolution = "suppressed", unresolved_reason = "stage_suppressed")
    return(list(rows = official, resolution = uefa_nl_sim_stage_resolution_row(iteration, stage_id, pair$tie_id[[1L]], resolution, stage_status = "suppressed", source_status = "official")))
  }
  sampled_rows <- list()
  if (as.integer(pair$legs[[1L]]) == 2L) {
    for (leg in 1:2) {
      home <- if (leg == 1L) pair$team_b[[1L]] else pair$team_a[[1L]]
      away <- if (leg == 1L) pair$team_a[[1L]] else pair$team_b[[1L]]
      slot_home <- if (leg == 1L) pair$slot_b[[1L]] else pair$slot_a[[1L]]
      slot_away <- if (leg == 1L) pair$slot_a[[1L]] else pair$slot_b[[1L]]
      sampled <- uefa_nl_sim_forecast_match_row(
        forecasts, status, score_distributions, stage_id, home, away,
        leg_number = leg, fixture_id = NULL, participant_slot_home = slot_home,
        participant_slot_away = slot_away,
        seed = uefa_nl_sim_seed_for(seed, stage = stage_id, tie = pair$tie_id[[1L]], leg = leg),
        projection_run_id = projection_run_id, draw_policy_id = draw_policy_id
      )
      if (is.null(sampled)) {
        resolution <- uefa_nl_sim_resolution(stage_status = "unresolved", resolution = "unresolved", unresolved_reason = "stage_forecast_unavailable")
        return(list(rows = if (length(sampled_rows)) do.call(rbind, sampled_rows) else data.frame(stringsAsFactors = FALSE, check.names = FALSE), resolution = uefa_nl_sim_stage_resolution_row(iteration, stage_id, pair$tie_id[[1L]], resolution)))
      }
      sampled_rows[[leg]] <- sampled
    }
    pair_rows <- do.call(rbind, sampled_rows)
    resolution <- uefa_nl_resolve_two_leg_tie(pair_rows, seed = uefa_nl_sim_seed_for(seed, stage = stage_id, tie = pair$tie_id[[1L]], mode = "sampled"), rules = rules, lower_league_team_id = lower_league_team_id)
  } else {
    sampled <- uefa_nl_sim_forecast_match_row(
      forecasts, status, score_distributions, stage_id, pair$team_a[[1L]], pair$team_b[[1L]],
      leg_number = 1L, fixture_id = NULL, participant_slot_home = pair$slot_a[[1L]],
      participant_slot_away = pair$slot_b[[1L]],
      seed = uefa_nl_sim_seed_for(seed, stage = stage_id, tie = pair$tie_id[[1L]], leg = 1L),
      projection_run_id = projection_run_id, draw_policy_id = draw_policy_id
    )
    if (is.null(sampled)) {
      resolution <- uefa_nl_sim_resolution(stage_status = "unresolved", resolution = "unresolved", unresolved_reason = "stage_forecast_unavailable")
      return(list(rows = data.frame(stringsAsFactors = FALSE, check.names = FALSE), resolution = uefa_nl_sim_stage_resolution_row(iteration, stage_id, pair$tie_id[[1L]], resolution)))
    }
    pair_rows <- sampled
    resolution <- uefa_nl_resolve_single_leg(pair_rows, mode = if (stage_id == "league_a_third_place") "direct_penalty" else "final", seed = uefa_nl_sim_seed_for(seed, stage = stage_id, tie = pair$tie_id[[1L]], mode = "sampled"), rules = rules)
  }
  list(rows = pair_rows, resolution = uefa_nl_sim_stage_resolution_row(iteration, stage_id, pair$tie_id[[1L]], resolution))
}

uefa_nl_sim_bind_rows <- function(frames) {
  frames <- frames[vapply(frames, function(frame) is.data.frame(frame) && nrow(frame), logical(1))]
  if (!length(frames)) return(data.frame(stringsAsFactors = FALSE, check.names = FALSE))
  fields <- unique(unlist(lapply(frames, names), use.names = FALSE))
  frames <- lapply(frames, function(frame) {
    frame <- as.data.frame(frame, stringsAsFactors = FALSE, check.names = FALSE)
    for (field in setdiff(fields, names(frame))) frame[[field]] <- rep(NA, nrow(frame))
    frame[, fields, drop = FALSE]
  })
  output <- do.call(rbind, frames)
  row.names(output) <- NULL
  output
}

uefa_nl_sim_cutoff <- function(matches) {
  fields <- intersect(c("state_cutoff_utc", "simulation_cutoff_utc"), names(matches))
  values <- character()
  if (length(fields)) values <- as.character(unlist(matches[fields], use.names = FALSE))
  parsed <- suppressWarnings(as.POSIXct(values, tz = "UTC"))
  parsed <- parsed[!is.na(parsed)]
  if (!length(parsed) && "evidence_completed_at_utc" %in% names(matches)) {
    parsed <- suppressWarnings(as.POSIXct(as.character(matches$evidence_completed_at_utc), tz = "UTC"))
    parsed <- parsed[!is.na(parsed)]
  }
  if (!length(parsed)) return("2099-12-31T23:59:59Z")
  format(max(parsed), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

uefa_nl_sim_prepare_iteration_matches <- function(matches, cutoff_utc) {
  output <- as.data.frame(matches, stringsAsFactors = FALSE, check.names = FALSE)
  if (!"state_cutoff_utc" %in% names(output)) output$state_cutoff_utc <- cutoff_utc
  output$state_cutoff_utc <- cutoff_utc
  if (!"evidence_completed_at_utc" %in% names(output)) output$evidence_completed_at_utc <- NA_character_
  if (!"stage_id" %in% names(output)) output$stage_id <- "league_phase"
  if (!"match_status" %in% names(output)) output$match_status <- "scheduled"
  if (!"source_status" %in% names(output)) output$source_status <- as.character(output$match_status)
  output$counts_for_standings <- FALSE
  for (index in seq_len(nrow(output))) {
    evidence <- uefa_nl_sim_parse_timestamp(output$evidence_completed_at_utc[[index]])
    qualifies <- output$stage_id[[index]] == "league_phase" &&
      uefa_nl_sim_status_is_completed(output$match_status[[index]]) &&
      uefa_nl_sim_score_present(output[index, , drop = FALSE]) &&
      !is.na(evidence) && evidence <= as.POSIXct(cutoff_utc, tz = "UTC")
    output$counts_for_standings[[index]] <- isTRUE(qualifies)
  }
  output
}

uefa_nl_sim_sample_league_matches <- function(
    matches, forecast_status, forecasts, score_distributions, rules, seed,
    projection_run_id, draw_policy_id, cutoff_utc) {
  output <- uefa_nl_sim_prepare_iteration_matches(matches, cutoff_utc)
  open <- output$stage_id == "league_phase" & uefa_nl_sim_status_is_open(output$match_status)
  records <- list()
  record_index <- 0L
  if (any(open)) {
    for (index in which(open)) {
      fixture_id <- as.character(output$fixture_id[[index]])
      status_row <- uefa_nl_sim_forecast_status_for_id(forecast_status, fixture_id)
      forecast_status_value <- if (is.null(status_row)) "unresolved" else as.character(status_row$forecast_status[[1L]])
      suppression_reason <- if (is.null(status_row)) "forecast_status_missing" else as.character(status_row$suppression_reason[[1L]])
      forecast <- if (!is.null(status_row) && identical(forecast_status_value, "available")) {
        uefa_nl_sim_find_forecast(
          forecasts, forecast_status, stage_id = "league_phase",
          home_team_id = output$home_team_id[[index]], away_team_id = output$away_team_id[[index]],
          fixture_id = fixture_id
        )
      } else {
        NULL
      }
      grid <- if (!is.null(forecast)) uefa_nl_sim_fixture_grid(score_distributions, forecast) else NULL
      sampled <- if (!is.null(forecast) && !is.null(grid)) {
        uefa_nl_sim_forecast_match_row(
          forecasts, forecast_status, score_distributions, "league_phase",
          output$home_team_id[[index]], output$away_team_id[[index]],
          leg_number = 1L, fixture_id = fixture_id,
          participant_slot_home = output$home_team_id[[index]],
          participant_slot_away = output$away_team_id[[index]],
          seed = uefa_nl_sim_seed_for(seed, fixture = fixture_id, stage = "league_phase", iteration = 1L),
          projection_run_id = projection_run_id, draw_policy_id = draw_policy_id
        )
      } else {
        NULL
      }
      if (!is.null(sampled)) {
        for (field in intersect(names(sampled), names(output))) output[[field]][[index]] <- sampled[[field]][[1L]]
        output$final_home_goals[[index]] <- sampled$final_home_goals[[1L]]
        output$final_away_goals[[index]] <- sampled$final_away_goals[[1L]]
        output$regulation_home_goals[[index]] <- sampled$regulation_home_goals[[1L]]
        output$regulation_away_goals[[index]] <- sampled$regulation_away_goals[[1L]]
        output$extra_time_home_goals[[index]] <- 0L
        output$extra_time_away_goals[[index]] <- 0L
        output$match_status[[index]] <- "completed"
        output$source_status[[index]] <- "projected"
        output$counts_for_standings[[index]] <- TRUE
        output$evidence_completed_at_utc[[index]] <- cutoff_utc
        record_index <- record_index + 1L
        records[[record_index]] <- data.frame(
          fixture_id = fixture_id, stage_id = "league_phase", stage_status = "projected",
          forecast_status = "available", outcome_class = as.character(sampled$outcome_class[[1L]]),
          outcome_probability = as.numeric(sampled$outcome_probability[[1L]]),
          p_home = as.numeric(uefa_nl_sim_row_value(forecast, c("p_home", "prob_home"), NA_real_)),
          p_draw = as.numeric(uefa_nl_sim_row_value(forecast, c("p_draw", "prob_draw"), NA_real_)),
          p_away = as.numeric(uefa_nl_sim_row_value(forecast, c("p_away", "prob_away"), NA_real_)),
          suppression_reason = "", unresolved_reason = "", stringsAsFactors = FALSE, check.names = FALSE
        )
      } else {
        output$counts_for_standings[[index]] <- FALSE
        status_value <- if (identical(forecast_status_value, "available")) "unresolved" else forecast_status_value
        reason <- if (identical(status_value, "unresolved") && nzchar(suppression_reason)) suppression_reason else if (identical(status_value, "unresolved")) "stage_forecast_unavailable" else suppression_reason
        record_index <- record_index + 1L
        records[[record_index]] <- data.frame(
          fixture_id = fixture_id, stage_id = "league_phase", stage_status = status_value,
          forecast_status = forecast_status_value, outcome_class = NA_character_, outcome_probability = NA_real_,
          p_home = NA_real_, p_draw = NA_real_, p_away = NA_real_,
          suppression_reason = if (status_value %in% c("suppressed", "unavailable")) reason else "",
          unresolved_reason = if (status_value == "unresolved") reason else "",
          stringsAsFactors = FALSE, check.names = FALSE
        )
      }
    }
  }
  list(matches = output, fixture_rows = uefa_nl_sim_bind_rows(records))
}

uefa_nl_sim_build_league_state <- function(matches, groups, rules, source_bundle_id, cutoff_utc) {
  group_ids <- sort(unique(as.character(groups$group_id)), method = "radix")
  states <- list()
  group_rankings <- list()
  league_matches <- matches[matches$stage_id == "league_phase", , drop = FALSE]
  for (group_id in group_ids) {
    group <- groups[as.character(groups$group_id) == group_id, , drop = FALSE]
    group_matches <- league_matches[as.character(league_matches$group_id) == group_id, , drop = FALSE]
    discipline <- group[, intersect(c("team_id", "discipline_points"), names(group)), drop = FALSE]
    access <- group[, intersect(c("team_id", "access_list_position"), names(group)), drop = FALSE]
    state <- uefa_nl_build_group_standings_state(
      group_matches, discipline_points = discipline, access_list = access, group_id = group_id,
      rules = rules, edition_id = rules$edition_id, state_cutoff_utc = cutoff_utc,
      source_bundle_id = source_bundle_id, team_ids = as.character(group$team_id)
    )
    # Phase 14's universal standings snapshot is deliberately league-neutral;
    # Article 19 needs the admitted group league carried back at this boundary.
    if (is.data.frame(state$standings) && nrow(state$standings)) {
      state$standings$league <- as.character(group$league[[1L]])
      state$standings$league_id <- as.character(group$league[[1L]])
    }
    states[[group_id]] <- state
    group_rankings[[group_id]] <- state$standings
  }
  individual <- uefa_nl_rank_individual_league(group_rankings, league_matches, rules)
  interim <- uefa_nl_rank_interim_overall(individual, rules)
  list(states = states, group_rankings = group_rankings, individual = individual, interim = interim)
}

uefa_nl_sim_transition_pair <- function(row, official_slots = NULL, rules = uefa_nl_2026_27_rules()) {
  stage_id <- as.character(row$stage_id[[1L]])
  high <- as.character(row$higher_league_team_id[[1L]])
  low <- as.character(row$lower_league_team_id[[1L]])
  if (is.na(high) || is.na(low) || !nzchar(high) || !nzchar(low) || identical(high, low)) return(NULL)
  pair <- data.frame(
    tie_id = paste(stage_id, as.character(row$higher_league_rank[[1L]]), as.character(row$lower_league_rank[[1L]]), sep = "::"),
    pair_index = 1L, legs = 2L, team_a = high, team_b = low,
    slot_a = paste0(as.character(row$higher_league), "-rank-", as.character(row$higher_league_rank)),
    slot_b = paste0(as.character(row$lower_league), "-rank-", as.character(row$lower_league_rank)),
    group_a = as.character(row$group_id[[1L]]), group_b = NA_character_,
    stringsAsFactors = FALSE, check.names = FALSE
  )
  official_pairs <- uefa_nl_sim_pairings_from_slots(official_slots, stage_id, rules)
  if (nrow(official_pairs)) {
    match <- which(vapply(seq_len(nrow(official_pairs)), function(index) {
      setequal(c(as.character(official_pairs$team_a[[index]]), as.character(official_pairs$team_b[[index]])), c(high, low))
    }, logical(1)))
    if (length(match) == 1L) pair <- official_pairs[match, , drop = FALSE]
  }
  pair
}

uefa_nl_sim_make_unresolved_stage <- function(pair, stage_id, iteration, reason = "stage_participants_unresolved") {
  uefa_nl_sim_stage_resolution_row(
    iteration, stage_id, pair$tie_id[[1L]],
    uefa_nl_sim_resolution(stage_status = "unresolved", resolution = "unresolved", unresolved_reason = reason)
  )
}

uefa_nl_sim_resolve_pairs <- function(
    pairs, stage_id, iteration, official_slots, forecasts, forecast_status, score_distributions,
    rules, seed, projection_run_id, draw_policy_id, lower_league = NULL) {
  if (!is.data.frame(pairs) || !nrow(pairs)) {
    return(list(match_rows = data.frame(stringsAsFactors = FALSE, check.names = FALSE), resolutions = data.frame(stringsAsFactors = FALSE, check.names = FALSE)))
  }
  results <- lapply(seq_len(nrow(pairs)), function(index) {
    pair <- pairs[index, , drop = FALSE]
    if (any(is.na(c(pair$team_a[[1L]], pair$team_b[[1L]]))) || any(!nzchar(c(as.character(pair$team_a[[1L]]), as.character(pair$team_b[[1L]]))))) {
      return(list(rows = data.frame(stringsAsFactors = FALSE, check.names = FALSE), resolution = uefa_nl_sim_make_unresolved_stage(pair, stage_id, iteration)))
    }
    uefa_nl_sim_resolve_stage_pair(
      pair, stage_id, iteration, official_slots, forecasts, forecast_status, score_distributions,
      rules, seed, projection_run_id, draw_policy_id, lower_league_team_id = lower_league
    )
  })
  list(
    match_rows = uefa_nl_sim_bind_rows(lapply(results, `[[`, "rows")),
    resolutions = uefa_nl_sim_bind_rows(lapply(results, `[[`, "resolution"))
  )
}

uefa_nl_sim_pairs_with_unknown_participants <- function(qf_pairs) {
  if (!is.data.frame(qf_pairs) || nrow(qf_pairs) < 4L) return(data.frame(stringsAsFactors = FALSE, check.names = FALSE))
  data.frame(
    tie_id = c("semi-final-1", "semi-final-2"), pair_index = 1:2, legs = 1L,
    team_a = NA_character_, team_b = NA_character_,
    slot_a = c("quarter-final-1-winner", "quarter-final-3-winner"),
    slot_b = c("quarter-final-2-winner", "quarter-final-4-winner"),
    group_a = NA_character_, group_b = NA_character_, stringsAsFactors = FALSE, check.names = FALSE
  )
}

uefa_nl_sim_pair_from_results <- function(stage_id, pair_index, pairs, resolutions, winner = TRUE) {
  if (!is.data.frame(pairs) || nrow(pairs) < pair_index) return(NA_character_)
  pair <- pairs[pair_index, , drop = FALSE]
  if (!is.data.frame(resolutions) || !nrow(resolutions)) return(NA_character_)
  row <- resolutions[resolutions$tie_id == pair$tie_id[[1L]] & resolutions$stage_id == stage_id, , drop = FALSE]
  if (nrow(row) != 1L || row$stage_status[[1L]] != "completed") return(NA_character_)
  if (winner) as.character(row$winner_team_id[[1L]]) else as.character(row$loser_team_id[[1L]])
}

uefa_nl_sim_transition_events <- function(transition_slots, playoff_results, iteration) {
  if (!is.data.frame(transition_slots) || !nrow(transition_slots)) return(data.frame(stringsAsFactors = FALSE, check.names = FALSE))
  rows <- list()
  row_index <- 0L
  for (index in seq_len(nrow(transition_slots))) {
    source <- transition_slots[index, , drop = FALSE]
    stage_id <- as.character(source$stage_id[[1L]])
    if (stage_id == "c_d_playoff" && as.character(source$cd_playoff_status[[1L]]) %in% c("cancelled", "unresolved")) {
      row <- source
      row$iteration <- as.integer(iteration)
      row$outcome_type <- if (source$cd_playoff_status[[1L]] == "cancelled") "retained_next_edition" else "unresolved_external_eligibility"
      row$probability <- NA_real_
      rows[[row_index <- row_index + 1L]] <- row
      next
    }
    if (stage_id == "direct_transition") {
      row <- source
      row$iteration <- as.integer(iteration)
      row$outcome_type <- as.character(source$transition_type[[1L]])
      row$stage_status <- if (as.character(source$selection_status[[1L]]) == "selected") "projected" else "unresolved"
      row$probability <- if (row$stage_status[[1L]] == "projected") 1 else NA_real_
      rows[[row_index <- row_index + 1L]] <- row
      next
    }
    high <- as.character(source$higher_league_team_id[[1L]])
    low <- as.character(source$lower_league_team_id[[1L]])
    tie_id <- paste(stage_id, as.character(source$higher_league_rank[[1L]]), as.character(source$lower_league_rank[[1L]]), sep = "::")
    resolved <- if (is.data.frame(playoff_results) && nrow(playoff_results)) playoff_results[playoff_results$stage_id == stage_id & playoff_results$tie_id == tie_id, , drop = FALSE] else data.frame(stringsAsFactors = FALSE, check.names = FALSE)
    stage_status <- if (nrow(resolved) == 1L) as.character(resolved$stage_status[[1L]]) else "unresolved"
    winner <- if (nrow(resolved) == 1L) as.character(resolved$winner_team_id[[1L]]) else NA_character_
    for (team in c(high, low)) {
      row <- source
      row$iteration <- as.integer(iteration)
      row$team_id <- team
      row$outcome_type <- if (stage_status == "completed") if (identical(team, winner)) "playoff_win" else "playoff_loss" else "unresolved"
      row$stage_status <- stage_status
      row$probability <- if (stage_status == "completed") 1 else NA_real_
      row$playoff_eligibility_probability <- 1
      row$playoff_win_probability <- if (stage_status == "completed") as.numeric(identical(team, winner)) else NA_real_
      row$playoff_loss_probability <- if (stage_status == "completed") as.numeric(!identical(team, winner)) else NA_real_
      row$transition_key <- paste(tie_id, team, row$outcome_type, sep = "::")
      rows[[row_index <- row_index + 1L]] <- row
    }
  }
  uefa_nl_sim_bind_rows(rows)
}

uefa_nl_sim_iteration_paths <- function(
    groups, interim, transitions, qf_pairs, qf_resolutions, semi_pairs, semi_resolutions,
    final_resolution, third_resolution, iteration) {
  teams <- sort(as.character(groups$team_id), method = "radix")
  rank <- setNames(as.integer(interim$interim_rank), as.character(interim$team_id))
  leagues <- setNames(as.character(interim$league), as.character(interim$team_id))
  numeric_path <- function(value) as.numeric(ifelse(is.na(value), NA, value))
  stage_path <- function(team, pairs, resolutions, role = c("winner", "loser")) {
    role <- match.arg(role)
    if (!is.data.frame(pairs) || !nrow(pairs)) return(NA_real_)
    participant <- vapply(seq_len(nrow(pairs)), function(index) team %in% c(as.character(pairs$team_a[[index]]), as.character(pairs$team_b[[index]])), logical(1))
    if (!any(participant)) return(0)
    selected <- pairs[participant, , drop = FALSE]
    values <- numeric(nrow(selected))
    for (index in seq_len(nrow(selected))) {
      result <- if (is.data.frame(resolutions) && nrow(resolutions)) resolutions[resolutions$tie_id == selected$tie_id[[index]], , drop = FALSE] else data.frame(stringsAsFactors = FALSE, check.names = FALSE)
      if (nrow(result) != 1L || result$stage_status[[1L]] != "completed") values[[index]] <- NA_real_ else values[[index]] <- as.numeric(identical(team, if (role == "winner") result$winner_team_id[[1L]] else result$loser_team_id[[1L]]))
    }
    if (any(is.na(values))) NA_real_ else max(values)
  }
  transition_for <- function(team, transition_type) {
    if (!is.data.frame(transitions) || !nrow(transitions)) return(0)
    rows <- transitions[as.character(transitions$team_id) == team & as.character(transitions$transition_type) == transition_type, , drop = FALSE]
    if (!nrow(rows)) return(0)
    if (any(as.character(rows$stage_status) == "unresolved")) return(NA_real_)
    1
  }
  qf <- setNames(vapply(teams, function(team) if (!is.na(rank[[team]]) && leagues[[team]] == "A" && rank[[team]] <= 8L) 1 else 0, numeric(1)), teams)
  semi <- setNames(vapply(teams, function(team) stage_path(team, qf_pairs, qf_resolutions, "winner"), numeric(1)), teams)
  final <- setNames(vapply(teams, function(team) stage_path(team, semi_pairs, semi_resolutions, "winner"), numeric(1)), teams)
  third <- setNames(vapply(teams, function(team) stage_path(team, semi_pairs, semi_resolutions, "loser"), numeric(1)), teams)
  champion <- setNames(rep(0, length(teams)), teams)
  finalist <- setNames(rep(0, length(teams)), teams)
  third_place <- setNames(rep(0, length(teams)), teams)
  if (is.data.frame(final_resolution) && nrow(final_resolution) == 1L) {
    if (final_resolution$stage_status[[1L]] == "completed") {
      champion[as.character(final_resolution$winner_team_id[[1L]])] <- 1
      finalist[as.character(final_resolution$winner_team_id[[1L]])] <- 1
      finalist[as.character(final_resolution$loser_team_id[[1L]])] <- 1
    } else {
      finalist[semi == 1] <- NA_real_
      champion[semi == 1] <- NA_real_
    }
  } else if (any(semi == 1, na.rm = TRUE)) {
    finalist[semi == 1] <- NA_real_
    champion[semi == 1] <- NA_real_
  }
  if (is.data.frame(third_resolution) && nrow(third_resolution) == 1L) {
    if (third_resolution$stage_status[[1L]] == "completed") {
      third_place[as.character(third_resolution$winner_team_id[[1L]])] <- 1
      third_place[as.character(third_resolution$loser_team_id[[1L]])] <- 1
    } else {
      third_place[semi == 1] <- NA_real_
    }
  } else if (any(semi == 1, na.rm = TRUE)) {
    third_place[semi == 1] <- NA_real_
  }
  cancelled <- if (is.data.frame(transitions) && nrow(transitions)) as.character(transitions$cd_playoff_status) == "cancelled" else logical()
  unresolved_cd <- if (is.data.frame(transitions) && nrow(transitions)) as.character(transitions$eligibility_status) == "unresolved_external_eligibility" else logical()
  output <- lapply(teams, function(team) {
    team_transition <- if (is.data.frame(transitions) && nrow(transitions)) transitions[as.character(transitions$team_id) == team, , drop = FALSE] else data.frame(stringsAsFactors = FALSE, check.names = FALSE)
    cd_cancelled <- nrow(team_transition) && any(as.character(team_transition$cd_playoff_status) == "cancelled")
    cd_unresolved <- nrow(team_transition) && any(as.character(team_transition$eligibility_status) == "unresolved_external_eligibility")
    playoff_rows <- team_transition[as.character(team_transition$stage_id) %in% c("a_b_playoff", "b_c_playoff", "c_d_playoff"), , drop = FALSE]
    eligibility <- if (cd_cancelled || cd_unresolved) NA_real_ else if (nrow(playoff_rows)) 1 else 0
    playoff_win <- if (nrow(playoff_rows) && any(as.character(playoff_rows$outcome_type) == "playoff_win")) 1 else if (nrow(playoff_rows) && any(as.character(playoff_rows$stage_status) == "unresolved")) NA_real_ else 0
    playoff_loss <- if (nrow(playoff_rows) && any(as.character(playoff_rows$outcome_type) == "playoff_loss")) 1 else if (nrow(playoff_rows) && any(as.character(playoff_rows$stage_status) == "unresolved")) NA_real_ else 0
    data.frame(
      iteration = as.integer(iteration), team_id = team, league = leagues[[team]],
      p_quarter_final = qf[[team]], p_semi_final = semi[[team]], p_third_place = third_place[[team]],
      p_final = finalist[[team]], p_champion = champion[[team]],
      p_direct_promotion = transition_for(team, "direct_promotion"),
      p_direct_relegation = transition_for(team, "direct_relegation"),
      p_playoff_eligibility = eligibility, p_playoff_win = playoff_win, p_playoff_loss = playoff_loss,
      status = if (cd_cancelled) "suppressed" else if (cd_unresolved || any(c("unresolved", "blocked") %in% as.character(interim$ordering_status[match(interim$team_id, team)]))) "unresolved" else "projected",
      suppression_reason = if (cd_cancelled) "c_d_playoff_cancelled" else "",
      stringsAsFactors = FALSE, check.names = FALSE
    )
  })
  do.call(rbind, output)
}

uefa_nl_sim_iteration <- function(
    iteration, matches, groups, forecast_status, forecasts, score_distributions, rules,
    seed, source_bundle_id, official_stage_slots, euro_playoff_eligibility,
    cutoff_utc, projection_run_id, draw_policy_id) {
  sampled <- uefa_nl_sim_sample_league_matches(
    matches, forecast_status, forecasts, score_distributions, rules, seed,
    projection_run_id, draw_policy_id, cutoff_utc
  )
  state <- uefa_nl_sim_build_league_state(sampled$matches, groups, rules, source_bundle_id, cutoff_utc)
  interim <- state$interim
  transition_slots <- tryCatch(
    uefa_nl_select_transition_slots(interim, euro_playoff_eligibility, rules),
    error = function(error) data.frame(stringsAsFactors = FALSE, check.names = FALSE)
  )
  cd <- tryCatch(uefa_nl_resolve_cd_playoff_cancellation(interim, euro_playoff_eligibility, rules), error = function(error) data.frame(stringsAsFactors = FALSE, check.names = FALSE))
  cd_status <- attr(cd, "cancellation_status", exact = TRUE) %||% "not_required"
  if (!identical(cd_status, "not_required") && nrow(transition_slots)) {
    transition_slots <- transition_slots[transition_slots$stage_id != "c_d_playoff", , drop = FALSE]
    transition_slots <- uefa_nl_sim_bind_rows(list(transition_slots, cd))
  }

  official_qf <- official_stage_slots[official_stage_slots$stage_id == "league_a_quarter_final", , drop = FALSE]
  winners <- interim[as.character(interim$league) == "A" & as.integer(interim$group_position) == 1L, , drop = FALSE]
  runners <- interim[as.character(interim$league) == "A" & as.integer(interim$group_position) == 2L, , drop = FALSE]
  qf_draw <- if (nrow(official_qf)) NULL else if (nrow(winners) == 4L && nrow(runners) == 4L) {
    uefa_nl_draw_quarter_finals(winners, runners, seed = uefa_nl_sim_seed_for(seed, iteration = iteration, stage = "qf"), projection_run_id = projection_run_id, rules = rules)
  } else NULL
  qf_pairs <- if (nrow(official_qf)) uefa_nl_sim_pairings_from_slots(official_qf, "league_a_quarter_final", rules) else qf_draw$pairings %||% data.frame(stringsAsFactors = FALSE, check.names = FALSE)
  qf_slots <- if (nrow(official_qf)) official_qf else if (!is.null(qf_draw)) qf_draw$stage_slots else data.frame(stringsAsFactors = FALSE, check.names = FALSE)
  qf <- uefa_nl_sim_resolve_pairs(
    qf_pairs, "league_a_quarter_final", iteration, official_stage_slots, forecasts, forecast_status, score_distributions,
    rules, seed, projection_run_id, if (nrow(official_qf)) "official_stage_capture" else draw_policy_id
  )
  qf_complete <- nrow(qf$resolutions) == nrow(qf_pairs) && nrow(qf_pairs) == 4L && all(qf$resolutions$stage_status == "completed")

  official_sf <- official_stage_slots[official_stage_slots$stage_id == "league_a_semi_final", , drop = FALSE]
  semi_draw <- NULL
  if (nrow(official_sf)) {
    semi_pairs <- uefa_nl_sim_pairings_from_slots(official_sf, "league_a_semi_final", rules)
  } else if (qf_complete) {
    qf_winners <- data.frame(team_id = qf$resolutions$winner_team_id, stringsAsFactors = FALSE, check.names = FALSE)
    semi_draw <- uefa_nl_draw_semi_finals(qf_winners, seed = uefa_nl_sim_seed_for(seed, iteration = iteration, stage = "semi"), projection_run_id = projection_run_id, rules = rules)
    semi_pairs <- semi_draw$semi_finals
  } else {
    semi_pairs <- uefa_nl_sim_pairs_with_unknown_participants(qf_pairs)
  }
  semi_slots <- if (nrow(official_sf)) official_sf else if (!is.null(semi_draw)) semi_draw$stage_slots[semi_draw$stage_slots$stage_id == "league_a_semi_final", , drop = FALSE] else if (nrow(semi_pairs)) uefa_nl_sim_projected_slot_rows("league_a_semi_final", "semi_final", semi_pairs, rules, projection_run_id, draw_policy_id) else data.frame(stringsAsFactors = FALSE, check.names = FALSE)
  semi <- uefa_nl_sim_resolve_pairs(
    semi_pairs, "league_a_semi_final", iteration, official_stage_slots, forecasts, forecast_status, score_distributions,
    rules, seed, projection_run_id, if (nrow(official_sf)) "official_stage_capture" else draw_policy_id
  )
  semi_complete <- nrow(semi$resolutions) == 2L && all(semi$resolutions$stage_status == "completed")

  official_final <- official_stage_slots[official_stage_slots$stage_id == "league_a_final", , drop = FALSE]
  official_third <- official_stage_slots[official_stage_slots$stage_id == "league_a_third_place", , drop = FALSE]
  final_pairs <- if (nrow(official_final)) uefa_nl_sim_pairings_from_slots(official_final, "league_a_final", rules) else if (semi_complete) data.frame(tie_id = "league-a-final", pair_index = 1L, legs = 1L, team_a = semi$resolutions$winner_team_id[[1L]], team_b = semi$resolutions$winner_team_id[[2L]], slot_a = "semi-final-1-winner", slot_b = "semi-final-2-winner", group_a = NA_character_, group_b = NA_character_, stringsAsFactors = FALSE, check.names = FALSE) else data.frame(tie_id = "league-a-final", pair_index = 1L, legs = 1L, team_a = NA_character_, team_b = NA_character_, slot_a = "semi-final-1-winner", slot_b = "semi-final-2-winner", group_a = NA_character_, group_b = NA_character_, stringsAsFactors = FALSE, check.names = FALSE)
  third_pairs <- if (nrow(official_third)) uefa_nl_sim_pairings_from_slots(official_third, "league_a_third_place", rules) else if (semi_complete) data.frame(tie_id = "league-a-third-place", pair_index = 1L, legs = 1L, team_a = semi$resolutions$loser_team_id[[1L]], team_b = semi$resolutions$loser_team_id[[2L]], slot_a = "semi-final-1-loser", slot_b = "semi-final-2-loser", group_a = NA_character_, group_b = NA_character_, stringsAsFactors = FALSE, check.names = FALSE) else data.frame(tie_id = "league-a-third-place", pair_index = 1L, legs = 1L, team_a = NA_character_, team_b = NA_character_, slot_a = "semi-final-1-loser", slot_b = "semi-final-2-loser", group_a = NA_character_, group_b = NA_character_, stringsAsFactors = FALSE, check.names = FALSE)
  final_slots <- if (nrow(official_final)) official_final else uefa_nl_sim_projected_slot_rows("league_a_final", "final", final_pairs, rules, projection_run_id, draw_policy_id)
  third_slots <- if (nrow(official_third)) official_third else uefa_nl_sim_projected_slot_rows("league_a_third_place", "third_place", third_pairs, rules, projection_run_id, draw_policy_id)
  final <- uefa_nl_sim_resolve_pairs(
    final_pairs, "league_a_final", iteration, official_stage_slots, forecasts, forecast_status, score_distributions,
    rules, seed, projection_run_id, if (nrow(official_final)) "official_stage_capture" else draw_policy_id
  )
  third <- uefa_nl_sim_resolve_pairs(
    third_pairs, "league_a_third_place", iteration, official_stage_slots, forecasts, forecast_status, score_distributions,
    rules, seed, projection_run_id, if (nrow(official_third)) "official_stage_capture" else draw_policy_id
  )

  playoff_stages <- c("a_b_playoff", "b_c_playoff", "c_d_playoff")
  playoff_matches <- list()
  playoff_resolutions <- list()
  playoff_slots <- list()
  for (stage_id in playoff_stages) {
    selected <- transition_slots[transition_slots$stage_id == stage_id & as.character(transition_slots$selection_status) == "selected", , drop = FALSE]
    if (!nrow(selected)) next
    for (row_index in seq_len(nrow(selected))) {
      pair <- uefa_nl_sim_transition_pair(selected[row_index, , drop = FALSE], official_stage_slots, rules)
      if (is.null(pair)) next
      official_stage <- official_stage_slots[official_stage_slots$stage_id == stage_id, , drop = FALSE]
      if (!nrow(official_stage)) playoff_slots[[length(playoff_slots) + 1L]] <- uefa_nl_sim_projected_slot_rows(stage_id, if (stage_id == "a_b_playoff") "a_b_playoff" else if (stage_id == "b_c_playoff") "b_c_playoff" else "c_d_playoff", pair, rules, projection_run_id, draw_policy_id)
      result <- uefa_nl_sim_resolve_pairs(
        pair, stage_id, iteration, official_stage_slots, forecasts, forecast_status, score_distributions,
        rules, seed, projection_run_id, if (nrow(official_stage)) "official_stage_capture" else draw_policy_id,
        lower_league = as.character(selected$lower_league_team_id[[row_index]])
      )
      playoff_matches[[length(playoff_matches) + 1L]] <- result$match_rows
      playoff_resolutions[[length(playoff_resolutions) + 1L]] <- result$resolutions
    }
  }
  playoff_resolution_frame <- uefa_nl_sim_bind_rows(playoff_resolutions)
  all_resolutions <- uefa_nl_sim_bind_rows(list(qf$resolutions, semi$resolutions, final$resolutions, third$resolutions, playoff_resolution_frame))
  ranking_input <- all_resolutions[, setdiff(names(all_resolutions), "iteration"), drop = FALSE]
  final_rankings <- uefa_nl_rank_final_overall(interim, stage_results = ranking_input, rules = rules, transition_slots = transition_slots)
  transition_events <- uefa_nl_sim_transition_events(transition_slots, playoff_resolution_frame, iteration)
  paths <- uefa_nl_sim_iteration_paths(groups, interim, transition_events, qf_pairs, qf$resolutions, semi_pairs, semi$resolutions, final$resolutions, third$resolutions, iteration)
  generated_slots <- uefa_nl_sim_bind_rows(c(
    list(if (nrow(official_qf)) data.frame(stringsAsFactors = FALSE, check.names = FALSE) else qf_slots),
    list(if (nrow(official_sf)) data.frame(stringsAsFactors = FALSE, check.names = FALSE) else semi_slots),
    list(if (nrow(official_final)) data.frame(stringsAsFactors = FALSE, check.names = FALSE) else final_slots),
    list(if (nrow(official_third)) data.frame(stringsAsFactors = FALSE, check.names = FALSE) else third_slots),
    playoff_slots
  ))
  stage_slots <- uefa_nl_sim_bind_rows(list(official_stage_slots, generated_slots))
  if (nrow(stage_slots)) stage_slots$iteration <- as.integer(iteration)
  list(
    matches = sampled$matches, fixture_rows = sampled$fixture_rows, state = state,
    interim = interim, final_rankings = final_rankings, transition_slots = transition_slots,
    transition_events = transition_events, paths = paths, stage_slots = stage_slots,
    stage_matches = uefa_nl_sim_bind_rows(list(qf$match_rows, semi$match_rows, final$match_rows, third$match_rows, playoff_matches)),
    stage_resolutions = all_resolutions
  )
}

uefa_nl_sim_add_metadata <- function(data, edition_id, projection_run_id, simulation_count, seed, rules, source_bundle_id, source_bundle_sha256, model_release_id) {
  if (!is.data.frame(data) || !nrow(data)) return(data)
  values <- list(
    edition_id = as.character(edition_id), projection_run_id = as.character(projection_run_id),
    simulation_count = as.integer(simulation_count), simulation_seed = as.integer(seed),
    ruleset_version = as.character(rules$ruleset_version), ruleset_sha256 = uefa_nl_ruleset_sha256(rules),
    source_bundle_id = as.character(source_bundle_id), source_bundle_sha256 = as.character(source_bundle_sha256),
    model_release_id = as.character(model_release_id)
  )
  for (field in names(values)) data[[field]] <- rep(values[[field]], length.out = nrow(data))
  data
}

uefa_nl_sim_mean_path <- function(values) {
  values <- suppressWarnings(as.numeric(values))
  if (!length(values) || any(is.na(values))) NA_real_ else mean(values)
}

uefa_nl_sim_rank_capture <- function(iteration) {
  group_frames <- lapply(iteration$state$group_rankings, function(frame) {
    frame <- as.data.frame(frame, stringsAsFactors = FALSE, check.names = FALSE)
    if (!nrow(frame)) return(frame)
    frame$ranking_scope <- "group"
    frame$rank <- as.integer(frame$group_position)
    frame$interim_overall_rank <- NA_integer_
    frame$final_overall_rank <- NA_integer_
    frame$ranking_stage <- "group"
    frame
  })
  individual <- as.data.frame(iteration$state$individual, stringsAsFactors = FALSE, check.names = FALSE)
  individual$rank <- as.integer(individual$individual_rank)
  individual$interim_overall_rank <- NA_integer_
  individual$final_overall_rank <- NA_integer_
  individual$ranking_stage <- "individual_league"
  interim <- as.data.frame(iteration$state$interim, stringsAsFactors = FALSE, check.names = FALSE)
  final <- as.data.frame(iteration$final_rankings, stringsAsFactors = FALSE, check.names = FALSE)
  final_lookup <- final[match(as.character(interim$team_id), as.character(final$team_id)), , drop = FALSE]
  interim$ranking_scope <- "interim_overall"
  interim$rank <- as.integer(interim$interim_rank)
  interim$interim_overall_rank <- as.integer(interim$interim_rank)
  interim$final_overall_rank <- as.integer(final_lookup$final_overall_rank)
  interim$ranking_stage <- as.character(final_lookup$ranking_stage)
  final$ranking_scope <- "final_overall"
  final$rank <- as.integer(final$final_overall_rank)
  final$interim_overall_rank <- as.integer(final$interim_rank)
  final
  uefa_nl_sim_bind_rows(c(group_frames, list(individual, interim, final)))
}

uefa_nl_sim_aggregate_rankings <- function(captures, simulation_count, metadata) {
  if (!is.data.frame(captures) || !nrow(captures)) return(data.frame(stringsAsFactors = FALSE, check.names = FALSE))
  captures$iteration <- NULL
  fields <- intersect(c(
    "ranking_scope", "team_id", "league", "group_id", "group_position", "rank",
    "interim_overall_rank", "final_overall_rank", "ranking_stage", "ordering_status",
    "missing_rule_input", "suppression_reason", "counted_match_ids", "excluded_match_ids"
  ), names(captures))
  captures <- captures[, c(fields, setdiff(names(captures), fields)), drop = FALSE]
  key_fields <- intersect(c("ranking_scope", "team_id", "league", "group_id", "group_position", "rank", "interim_overall_rank", "final_overall_rank", "ranking_stage"), names(captures))
  key <- do.call(paste, c(lapply(captures[key_fields], function(column) ifelse(is.na(column), "<NA>", as.character(column))), sep = "\x1f"))
  groups <- split(seq_len(nrow(captures)), key, drop = TRUE)
  rows <- lapply(groups, function(indexes) {
    row <- captures[indexes[[1L]], , drop = FALSE]
    row$probability <- if (any(is.na(suppressWarnings(as.numeric(as.character(captures$rank[indexes])))))) NA_real_ else length(indexes) / simulation_count
    row$rank_probability <- row$probability
    row$simulation_count <- as.integer(simulation_count)
    row
  })
  output <- uefa_nl_sim_bind_rows(rows)
  uefa_nl_sim_add_metadata(output, metadata$edition_id, metadata$projection_run_id, simulation_count, metadata$simulation_seed, metadata$rules, metadata$source_bundle_id, metadata$source_bundle_sha256, metadata$model_release_id)
}

uefa_nl_sim_aggregate_standings <- function(iterations, simulation_count, metadata) {
  captures <- lapply(iterations, function(iteration) {
    frame <- uefa_nl_sim_bind_rows(iteration$state$group_rankings)
    if (!nrow(frame)) return(frame)
    frame$iteration <- as.integer(iteration$paths$iteration[[1L]])
    frame$rank <- as.integer(frame$group_position)
    frame
  })
  captures <- uefa_nl_sim_bind_rows(captures)
  if (!nrow(captures)) return(captures)
  key_fields <- intersect(c("league", "group_id", "team_id", "rank"), names(captures))
  key <- do.call(paste, c(lapply(captures[key_fields], function(column) ifelse(is.na(column), "<NA>", as.character(column))), sep = "\x1f"))
  groups <- split(seq_len(nrow(captures)), key, drop = TRUE)
  rows <- lapply(groups, function(indexes) {
    row <- captures[indexes[[1L]], , drop = FALSE]
    row$probability <- if (any(is.na(captures$rank[indexes]))) NA_real_ else length(indexes) / simulation_count
    row$expected_points <- if ("points" %in% names(captures) && all(is.finite(as.numeric(captures$points[indexes])))) mean(as.numeric(captures$points[indexes])) else NA_real_
    row$expected_goal_difference <- if ("goal_difference" %in% names(captures) && all(is.finite(as.numeric(captures$goal_difference[indexes])))) mean(as.numeric(captures$goal_difference[indexes])) else NA_real_
    row$simulation_count <- as.integer(simulation_count)
    row
  })
  output <- uefa_nl_sim_bind_rows(rows)
  uefa_nl_sim_add_metadata(output, metadata$edition_id, metadata$projection_run_id, simulation_count, metadata$simulation_seed, metadata$rules, metadata$source_bundle_id, metadata$source_bundle_sha256, metadata$model_release_id)
}

uefa_nl_sim_aggregate_paths <- function(iterations, groups, simulation_count, metadata) {
  captures <- uefa_nl_sim_bind_rows(lapply(iterations, `[[`, "paths"))
  teams <- sort(as.character(groups$team_id), method = "radix")
  path_fields <- c("p_quarter_final", "p_semi_final", "p_third_place", "p_final", "p_champion", "p_direct_promotion", "p_direct_relegation", "p_playoff_eligibility", "p_playoff_win", "p_playoff_loss")
  rows <- lapply(teams, function(team) {
    team_rows <- captures[as.character(captures$team_id) == team, , drop = FALSE]
    if (!nrow(team_rows)) return(data.frame(team_id = team, stringsAsFactors = FALSE, check.names = FALSE))
    row <- team_rows[1L, setdiff(names(team_rows), c("iteration", path_fields, "status", "suppression_reason")), drop = FALSE]
    for (field in path_fields) row[[field]] <- uefa_nl_sim_mean_path(team_rows[[field]])
    statuses <- as.character(team_rows$status)
    row$status <- if (any(statuses == "suppressed")) "suppressed" else if (any(statuses == "unresolved")) "unresolved" else "projected"
    row$suppression_reason <- if (row$status[[1L]] == "suppressed") paste(unique(as.character(team_rows$suppression_reason[statuses == "suppressed"])), collapse = ";") else ""
    row$simulation_count <- as.integer(simulation_count)
    row
  })
  output <- uefa_nl_sim_bind_rows(rows)
  uefa_nl_sim_add_metadata(output, metadata$edition_id, metadata$projection_run_id, simulation_count, metadata$simulation_seed, metadata$rules, metadata$source_bundle_id, metadata$source_bundle_sha256, metadata$model_release_id)
}

uefa_nl_sim_aggregate_transitions <- function(iterations, simulation_count, metadata) {
  captures <- uefa_nl_sim_bind_rows(lapply(iterations, `[[`, "transition_events"))
  if (!nrow(captures)) return(captures)
  probability_fields <- intersect(c("probability", "playoff_eligibility_probability", "playoff_win_probability", "playoff_loss_probability"), names(captures))
  captures$iteration <- NULL
  key_fields <- setdiff(names(captures), c(probability_fields, "row_sha256", "table_sha256"))
  key <- do.call(paste, c(lapply(captures[key_fields], function(column) ifelse(is.na(column), "<NA>", as.character(column))), sep = "\x1f"))
  groups <- split(seq_len(nrow(captures)), key, drop = TRUE)
  rows <- lapply(groups, function(indexes) {
    row <- captures[indexes[[1L]], , drop = FALSE]
    for (field in probability_fields) row[[field]] <- uefa_nl_sim_mean_path(captures[[field]][indexes])
    row$simulation_count <- as.integer(simulation_count)
    row$row_sha256 <- NULL
    row
  })
  output <- uefa_nl_sim_bind_rows(rows)
  output <- uefa_nl_sim_add_metadata(output, metadata$edition_id, metadata$projection_run_id, simulation_count, metadata$simulation_seed, metadata$rules, metadata$source_bundle_id, metadata$source_bundle_sha256, metadata$model_release_id)
  if (nrow(output)) output$row_sha256 <- uefa_nl_rules_row_sha256(output)
  output
}

uefa_nl_sim_aggregate_fixtures <- function(matches, forecast_status, forecasts, fixture_captures, simulation_count, metadata, source_bundle_sha256, state_manifest_sha256) {
  rows <- lapply(seq_len(nrow(matches)), function(index) {
    fixture_id <- as.character(matches$fixture_id[[index]])
    captures <- fixture_captures[fixture_captures$fixture_id == fixture_id, , drop = FALSE]
    forecast <- forecasts[as.character(forecasts$fixture_id) == fixture_id & as.character(forecasts$stage_id) == "league_phase", , drop = FALSE]
    status <- uefa_nl_sim_forecast_status_for_id(forecast_status, fixture_id)
    row <- if (nrow(forecast)) forecast[1L, , drop = FALSE] else data.frame(fixture_id = fixture_id, stringsAsFactors = FALSE, check.names = FALSE)
    row$fixture_id <- fixture_id
    row$edition_id <- metadata$edition_id
    row$forecast_status <- if (nrow(captures)) as.character(captures$forecast_status[[1L]]) else if (uefa_nl_sim_status_is_completed(matches$match_status[[index]])) "completed" else if (is.null(status)) "unresolved" else as.character(status$forecast_status[[1L]])
    row$suppression_reason <- if (nrow(captures)) as.character(captures$suppression_reason[[1L]]) else if (is.null(status)) "forecast_status_missing" else as.character(status$suppression_reason[[1L]])
    if (!nrow(captures) || all(is.na(captures$outcome_class))) {
      row$p_home <- NA_real_; row$p_draw <- NA_real_; row$p_away <- NA_real_
    } else {
      row$p_home <- mean(captures$outcome_class == "home", na.rm = TRUE)
      row$p_draw <- mean(captures$outcome_class == "draw", na.rm = TRUE)
      row$p_away <- mean(captures$outcome_class == "away", na.rm = TRUE)
    }
    row$source_bundle_sha256 <- source_bundle_sha256
    row$parent_state_manifest_sha256 <- state_manifest_sha256
    row$simulation_count <- as.integer(simulation_count)
    row
  })
  output <- uefa_nl_sim_bind_rows(rows)
  uefa_nl_sim_add_metadata(output, metadata$edition_id, metadata$projection_run_id, simulation_count, metadata$simulation_seed, metadata$rules, metadata$source_bundle_id, metadata$source_bundle_sha256, metadata$model_release_id)
}

uefa_nl_sim_metadata_row <- function(metadata, input_hashes, canonical_input_hashes, output_hashes) {
  ranking_stages <- metadata$ranking_stages %||% character()
  fields <- list(
    edition_id = metadata$edition_id, projection_run_id = metadata$projection_run_id,
    simulation_seed = as.integer(metadata$simulation_seed), simulation_count = as.integer(metadata$simulation_count),
    probability_sampling_policy = "calibrated_1x2_conditional_score_grid",
    scoreline_conditioning_policy = "calibrated_1x2_conditional_score_grid",
    penalty_resolution_policy = "seeded_bernoulli_0.5",
    draw_policy_id = metadata$draw_policy_id, draw_policy_sha256 = metadata$draw_policy_sha256,
    ruleset_version = metadata$rules$ruleset_version, ruleset_sha256 = uefa_nl_ruleset_sha256(metadata$rules),
    source_bundle_id = metadata$source_bundle_id, source_bundle_sha256 = metadata$source_bundle_sha256,
    state_manifest_sha256 = metadata$state_manifest_sha256, model_release_id = metadata$model_release_id,
    model_lineage_sha256 = uefa_nl_sim_hash_data(metadata$model_lineage),
    ranking_stages = paste(as.character(ranking_stages), collapse = ";"),
    ranking_stages_sha256 = uefa_nl_sim_hash_data(ranking_stages),
    forecast_status_sha256 = canonical_input_hashes$forecast_status,
    forecasts_sha256 = canonical_input_hashes$forecasts,
    score_distributions_sha256 = canonical_input_hashes$score_distributions,
    canonical_matches_sha256 = canonical_input_hashes$canonical_matches,
    completed_results_sha256 = input_hashes$completed_results,
    official_stage_slots_sha256 = canonical_input_hashes$official_stage_slots,
    cutoff_utc = metadata$cutoff_utc,
    generated_at_utc = "",
    input_hashes_sha256 = uefa_nl_sim_hash_data(input_hashes),
    canonical_input_hashes_sha256 = uefa_nl_sim_hash_data(canonical_input_hashes),
    output_hashes_sha256 = uefa_nl_sim_hash_data(output_hashes)
  )
  output <- as.data.frame(fields, stringsAsFactors = FALSE, check.names = FALSE)
  output$row_sha256 <- uefa_nl_rules_row_sha256(output)
  output
}

uefa_nl_run_simulation <- function(
    canonical_matches, completed_results = NULL, forecast_status, forecasts,
    score_distributions, groups, rules = uefa_nl_2026_27_rules(), simulation_count = 1000L,
    seed = 15017L, source_bundle_id, source_bundle_sha256, model_release_id,
    model_lineage = list(), state_manifest_sha256, euro_playoff_eligibility = NULL,
    official_stage_slots = NULL) {
  count <- uefa_nl_sim_normalize_count(simulation_count)
  simulation_seed <- uefa_nl_sim_normalize_seed(seed)
  source_bundle_id <- uefa_nl_sim_scalar_text(source_bundle_id, "source_bundle_id")
  source_bundle_sha256 <- uefa_nl_sim_scalar_text(source_bundle_sha256, "source_bundle_sha256")
  model_release_id <- uefa_nl_sim_scalar_text(model_release_id, "model_release_id")
  state_manifest_sha256 <- uefa_nl_sim_scalar_text(state_manifest_sha256, "state_manifest_sha256")
  rules <- uefa_nl_rank_rules(rules)
  raw_input_hashes <- list(
    canonical_matches = uefa_nl_sim_phase14_hash(canonical_matches, "canonical_matches"),
    completed_results = uefa_nl_sim_phase14_hash(completed_results, "completed_results"),
    forecast_status = uefa_nl_sim_phase14_hash(forecast_status, "forecast_status"),
    forecasts = uefa_nl_sim_phase14_hash(forecasts, "forecasts"),
    score_distributions = uefa_nl_sim_phase14_hash(score_distributions, "score_distributions"),
    groups = uefa_nl_sim_phase14_hash(groups, "groups"),
    euro_playoff_eligibility = uefa_nl_sim_phase14_hash(euro_playoff_eligibility, "euro_playoff_eligibility"),
    official_stage_slots = uefa_nl_sim_phase14_hash(official_stage_slots, "official_stage_slots")
  )
  normalized_matches <- uefa_nl_sim_normalize_matches(canonical_matches, completed_results, rules, source_bundle_id)
  normalized_groups <- uefa_nl_sim_normalize_groups(groups, normalized_matches, rules)
  normalized_status <- uefa_nl_sim_normalize_status(forecast_status, rules)
  normalized_forecasts <- uefa_nl_sim_normalize_forecasts(forecasts, rules)
  normalized_scores <- uefa_nl_sim_normalize_score_distributions(score_distributions)
  normalized_slots <- uefa_nl_sim_normalize_stage_slots(official_stage_slots, rules)
  canonical_input_hashes <- list(
    canonical_matches = uefa_nl_sim_phase14_hash(normalized_matches, "canonical_matches"),
    forecast_status = uefa_nl_sim_phase14_hash(normalized_status, "forecast_status"),
    forecasts = uefa_nl_sim_phase14_hash(normalized_forecasts, "forecasts"),
    score_distributions = uefa_nl_sim_phase14_hash(normalized_scores, "score_distributions"),
    groups = uefa_nl_sim_phase14_hash(normalized_groups, "groups"),
    official_stage_slots = uefa_nl_sim_phase14_hash(normalized_slots, "official_stage_slots")
  )
  cutoff_utc <- uefa_nl_sim_cutoff(normalized_matches)
  policy <- "phase15-article17-legal-draws-v1"
  projection <- uefa_nl_sim_projection_ids("", policy, simulation_seed)
  metadata <- list(
    edition_id = rules$edition_id, projection_run_id = projection$projection_run_id,
    simulation_seed = simulation_seed, simulation_count = count, rules = rules,
    draw_policy_id = projection$draw_policy_id, draw_policy_sha256 = projection$draw_policy_sha256,
    source_bundle_id = source_bundle_id, source_bundle_sha256 = source_bundle_sha256,
    model_release_id = model_release_id, model_lineage = model_lineage,
    state_manifest_sha256 = state_manifest_sha256, cutoff_utc = cutoff_utc
  )
  uefa_nl_sim_with_seed(simulation_seed, function() {
    iterations <- lapply(seq_len(count), function(iteration) {
      iter_seed <- uefa_nl_sim_seed_for(simulation_seed, iteration = iteration)
      uefa_nl_sim_iteration(
        iteration, normalized_matches, normalized_groups, normalized_status, normalized_forecasts, normalized_scores,
        rules, iter_seed, source_bundle_id, normalized_slots, euro_playoff_eligibility,
        cutoff_utc, projection$projection_run_id, projection$draw_policy_id
      )
    })
    fixture_captures <- uefa_nl_sim_bind_rows(lapply(iterations, `[[`, "fixture_rows"))
    projected_standings <- uefa_nl_sim_aggregate_standings(iterations, count, metadata)
    ranking_captures <- uefa_nl_sim_bind_rows(lapply(iterations, uefa_nl_sim_rank_capture))
    projected_rankings <- uefa_nl_sim_aggregate_rankings(ranking_captures, count, metadata)
    metadata$ranking_stages <- sort(unique(as.character(projected_rankings$ranking_stage)), method = "radix")
    transition_outcomes <- uefa_nl_sim_aggregate_transitions(iterations, count, metadata)
    team_paths <- uefa_nl_sim_aggregate_paths(iterations, normalized_groups, count, metadata)
    fixture_outcomes <- uefa_nl_sim_aggregate_fixtures(normalized_matches, normalized_status, normalized_forecasts, fixture_captures, count, metadata, source_bundle_sha256, state_manifest_sha256)
    stage_slots <- uefa_nl_sim_bind_rows(lapply(iterations, `[[`, "stage_slots"))
    stage_matches <- uefa_nl_sim_bind_rows(lapply(iterations, `[[`, "stage_matches"))
    stage_resolutions <- uefa_nl_sim_bind_rows(lapply(iterations, `[[`, "stage_resolutions"))
    for (name in c("stage_slots", "stage_matches", "stage_resolutions")) {
      value <- get(name)
      value <- uefa_nl_sim_add_metadata(value, metadata$edition_id, metadata$projection_run_id, count, simulation_seed, rules, source_bundle_id, source_bundle_sha256, model_release_id)
      assign(name, value)
    }
    output_tables <- list(
      projected_standings = projected_standings, projected_rankings = projected_rankings,
      transition_outcomes = transition_outcomes, team_path_probabilities = team_paths,
      fixture_forecast_form = fixture_outcomes, outcome_probabilities = fixture_outcomes,
      stage_slots = stage_slots, stage_matches = stage_matches, stage_resolutions = stage_resolutions
    )
    output_hashes <- lapply(output_tables, uefa_nl_sim_hash_data)
    simulation_metadata <- uefa_nl_sim_metadata_row(metadata, raw_input_hashes, canonical_input_hashes, output_hashes)
    list(
      projected_standings = projected_standings, projected_rankings = projected_rankings,
      stage_slots = stage_slots, stage_matches = stage_matches, stage_resolutions = stage_resolutions,
      transition_outcomes = transition_outcomes, team_path_probabilities = team_paths,
      fixture_forecast_form = fixture_outcomes, outcome_probabilities = fixture_outcomes,
      simulation_metadata = simulation_metadata, input_hashes = raw_input_hashes,
      canonical_input_hashes = canonical_input_hashes, output_hashes = output_hashes,
      metadata = metadata
    )
  })
}
