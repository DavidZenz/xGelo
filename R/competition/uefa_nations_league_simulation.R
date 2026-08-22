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
