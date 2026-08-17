#' Cutoff-safe universal standings and same-bundle reconciliation for Phase 14.
#'
#' This module owns only football-universal arithmetic.  Competition-specific
#' ordering belongs behind the ruleset adapter argument and is never inferred
#' from a source table or from the dashboard's competition-specific ranker.

phase14_standings_snapshot_key_fields <- function() {
  c("edition_id", "group_id", "state_cutoff_utc", "source_bundle_id")
}

phase14_standings_metric_fields <- function() {
  c(
    "played", "wins", "draws", "losses", "goals_for", "goals_against",
    "goal_difference", "points"
  )
}

phase14_standings_official_metric_fields <- function() {
  paste0("official_", phase14_standings_metric_fields())
}

phase14_standings_core_schema <- function() {
  c(
    phase14_standings_snapshot_key_fields(),
    "team_id",
    phase14_standings_metric_fields(),
    "computed_rank", "ordering_status", "ruleset_adapter_id"
  )
}

phase14_standings_reconciliation_schema <- function() {
  c(
    "official_source_bundle_id", "official_rank",
    phase14_standings_official_metric_fields(),
    "reconciliation_status", "reconciliation_reason",
    "reconciliation_severity", "publication_disposition",
    "prior_state_action", "prior_state_retention", "warning_status",
    "block_status", "blocked"
  )
}

phase14_standings_schema <- function() {
  c(
    phase14_standings_core_schema(),
    phase14_standings_reconciliation_schema(),
    "row_sha256", "table_sha256"
  )
}

phase14_standings_scalar <- function(value, field, allow_empty = FALSE) {
  if (length(value) != 1L || is.null(value) || is.na(value)) {
    stop("Phase 14 standings ", field, " must be one non-missing value", call. = FALSE)
  }
  value <- as.character(value[[1L]])
  if (!isTRUE(allow_empty) && !nzchar(trimws(value))) {
    stop("Phase 14 standings ", field, " must not be empty", call. = FALSE)
  }
  value
}

phase14_standings_clean_text <- function(values) {
  values <- as.character(values)
  values[is.na(values) | !nzchar(trimws(values))] <- NA_character_
  trimws(values)
}

phase14_standings_timestamp <- function(values, field) {
  values <- phase14_standings_clean_text(values)
  output <- rep(as.POSIXct(NA, tz = "UTC"), length(values))
  present <- !is.na(values)
  if (!any(present)) return(output)

  parsed <- suppressWarnings(as.POSIXct(values[present], tz = "UTC"))
  if (any(is.na(parsed))) {
    stop("Phase 14 standings ", field, " contains an invalid UTC timestamp", call. = FALSE)
  }
  output[present] <- parsed
  output
}

phase14_standings_logical <- function(values, field) {
  if (is.logical(values)) {
    output <- values
  } else {
    text <- tolower(phase14_standings_clean_text(values))
    output <- rep(NA, length(text))
    output[text %in% c("true", "t", "1", "yes", "y")] <- TRUE
    output[text %in% c("false", "f", "0", "no", "n")] <- FALSE
  }
  if (any(is.na(output))) {
    stop("Phase 14 standings ", field, " must contain explicit TRUE/FALSE values", call. = FALSE)
  }
  as.logical(output)
}

phase14_standings_nonnegative_integer <- function(values, field, allow_missing = TRUE) {
  text <- phase14_standings_clean_text(values)
  numeric_values <- suppressWarnings(as.numeric(text))
  present <- !is.na(text)
  invalid <- present & (
    is.na(numeric_values) | !is.finite(numeric_values) |
      numeric_values < 0 | numeric_values != floor(numeric_values)
  )
  if (any(invalid)) {
    stop("Phase 14 standings ", field, " must contain non-negative integers", call. = FALSE)
  }
  if (!isTRUE(allow_missing) && any(!present)) {
    stop("Phase 14 standings ", field, " must not be missing", call. = FALSE)
  }
  output <- rep(NA_integer_, length(numeric_values))
  output[present] <- as.integer(numeric_values[present])
  output
}

phase14_standings_integer <- function(values, field, allow_missing = TRUE) {
  text <- phase14_standings_clean_text(values)
  numeric_values <- suppressWarnings(as.numeric(text))
  present <- !is.na(text)
  invalid <- present & (
    is.na(numeric_values) | !is.finite(numeric_values) | numeric_values != floor(numeric_values)
  )
  if (any(invalid)) {
    stop("Phase 14 standings ", field, " must contain integers", call. = FALSE)
  }
  if (!isTRUE(allow_missing) && any(!present)) {
    stop("Phase 14 standings ", field, " must not be missing", call. = FALSE)
  }
  output <- rep(NA_integer_, length(numeric_values))
  output[present] <- as.integer(numeric_values[present])
  output
}

phase14_standings_metric_integer <- function(values, field, allow_missing = TRUE) {
  if (identical(field, "goal_difference") || identical(field, "official_goal_difference")) {
    return(phase14_standings_integer(values, field, allow_missing = allow_missing))
  }
  phase14_standings_nonnegative_integer(values, field, allow_missing = allow_missing)
}

phase14_standings_hash_column <- function(values) {
  if (inherits(values, "POSIXt")) {
    values <- format(values, "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC")
  } else if (is.logical(values)) {
    values <- ifelse(is.na(values), NA_character_, ifelse(values, "TRUE", "FALSE"))
  } else {
    values <- as.character(values)
  }
  values <- trimws(values)
  values[is.na(values)] <- "<NA>"
  values
}

phase14_standings_hash_payload <- function(data) {
  fields <- setdiff(names(data), c("row_sha256", "table_sha256"))
  if (!length(fields)) return("")
  columns <- lapply(data[fields], phase14_standings_hash_column)
  row_payloads <- if (!nrow(data)) {
    character()
  } else {
    vapply(seq_len(nrow(data)), function(index) {
      paste(vapply(columns, `[[`, character(1), index), collapse = "\x1f")
    }, character(1))
  }
  paste(c(paste(fields, collapse = "\x1f"), row_payloads), collapse = "\x1e")
}

phase14_standings_row_hashes <- function(data) {
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("digest is required for Phase 14 standings hashes", call. = FALSE)
  }
  if (!nrow(data)) return(character())
  vapply(seq_len(nrow(data)), function(index) {
    digest::digest(
      phase14_standings_hash_payload(data[index, , drop = FALSE]),
      algo = "sha256",
      serialize = FALSE
    )
  }, character(1))
}

phase14_standings_table_hash <- function(data) {
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("digest is required for Phase 14 standings hashes", call. = FALSE)
  }
  if (!nrow(data)) {
    return(digest::digest("", algo = "sha256", serialize = FALSE))
  }
  sort_fields <- intersect(
    c(phase14_standings_snapshot_key_fields(), "team_id", "computed_rank"),
    names(data)
  )
  order_args <- lapply(data[sort_fields], phase14_standings_hash_column)
  order_args$na.last <- TRUE
  ordered <- data[do.call(order, order_args), , drop = FALSE]
  digest::digest(
    phase14_standings_hash_payload(ordered),
    algo = "sha256",
    serialize = FALSE
  )
}

phase14_standings_apply_hashes <- function(data) {
  data$row_sha256 <- phase14_standings_row_hashes(data)
  table_hash <- phase14_standings_table_hash(data)
  data$table_sha256 <- rep(table_hash, nrow(data))
  data
}

phase14_standings_validate_snapshot_key <- function(data, expected = NULL, context = "snapshot") {
  key_fields <- phase14_standings_snapshot_key_fields()
  missing <- setdiff(key_fields, names(data))
  if (length(missing)) {
    stop("Phase 14 standings ", context, " is missing snapshot key fields: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  for (field in key_fields) {
    values <- phase14_standings_clean_text(data[[field]])
    if (any(is.na(values))) {
      stop("Phase 14 standings ", context, " has missing ", field, call. = FALSE)
    }
    if (length(unique(values)) != 1L) {
      stop("Phase 14 standings ", context, " must have one exact ", field, call. = FALSE)
    }
    if (!is.null(expected) && !identical(values[[1L]], as.character(expected[[field]]))) {
      stop("Phase 14 standings ", context, " has foreign ", field, call. = FALSE)
    }
  }
  invisible(TRUE)
}

phase14_standings_validate_metrics <- function(data, context = "snapshot") {
  metric_fields <- phase14_standings_metric_fields()
  missing <- setdiff(c("team_id", metric_fields, "computed_rank"), names(data))
  if (length(missing)) {
    stop("Phase 14 standings ", context, " is missing metric fields: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  teams <- phase14_standings_clean_text(data$team_id)
  if (any(is.na(teams)) || anyDuplicated(teams)) {
    stop("Phase 14 standings ", context, " contains missing or duplicate team IDs", call. = FALSE)
  }
  metrics <- Map(
    function(values, field) phase14_standings_metric_integer(values, field, allow_missing = FALSE),
    data[metric_fields],
    metric_fields
  )
  names(metrics) <- metric_fields
  if (any(metrics$played != metrics$wins + metrics$draws + metrics$losses)) {
    stop("Phase 14 standings ", context, " has played/results arithmetic mismatch", call. = FALSE)
  }
  if (any(metrics$goal_difference != metrics$goals_for - metrics$goals_against)) {
    stop("Phase 14 standings ", context, " has goal-difference arithmetic mismatch", call. = FALSE)
  }
  if (any(metrics$points != 3L * metrics$wins + metrics$draws)) {
    stop("Phase 14 standings ", context, " has points arithmetic mismatch", call. = FALSE)
  }
  ranks <- phase14_standings_nonnegative_integer(data$computed_rank, "computed_rank", allow_missing = FALSE)
  if (any(ranks < 1L) || (nrow(data) > 1L && !setequal(ranks, seq_len(nrow(data))))) {
    stop("Phase 14 standings ", context, " must have one contiguous computed rank per team", call. = FALSE)
  }
  invisible(TRUE)
}

phase14_standings_metadata <- function(data, field, expected) {
  if (!field %in% names(data)) return(rep(expected, nrow(data)))
  values <- phase14_standings_clean_text(data[[field]])
  foreign <- !is.na(values) & values != expected
  if (any(foreign)) {
    stop("Phase 14 standings input contains foreign ", field, " values", call. = FALSE)
  }
  values[is.na(values)] <- expected
  values
}

phase14_standings_adapter_id <- function(adapter, explicit_id = NULL) {
  if (is.null(adapter)) return("none")
  if (!is.null(explicit_id)) return(phase14_standings_scalar(explicit_id, "ruleset_adapter_id"))
  attribute_id <- attr(adapter, "adapter_id", exact = TRUE)
  if (!is.null(attribute_id)) return(phase14_standings_scalar(attribute_id, "ruleset_adapter_id"))
  "supplied"
}

phase14_standings_adapter_ranks <- function(adapter_result, standings) {
  if (is.data.frame(adapter_result)) {
    if (!"team_id" %in% names(adapter_result)) {
      stop("Phase 14 standings ruleset adapter result must include team_id", call. = FALSE)
    }
    rank_field <- intersect(c("computed_rank", "ruleset_rank", "rank", "position"), names(adapter_result))
    if (!length(rank_field)) {
      stop("Phase 14 standings ruleset adapter result must include a rank field", call. = FALSE)
    }
    team_ids <- phase14_standings_clean_text(adapter_result$team_id)
    if (anyDuplicated(team_ids) || !setequal(team_ids, standings$team_id)) {
      stop("Phase 14 standings ruleset adapter returned the wrong team set", call. = FALSE)
    }
    ranks <- phase14_standings_nonnegative_integer(adapter_result[[rank_field[[1L]]]], "ruleset rank", allow_missing = FALSE)
    output <- ranks[match(standings$team_id, team_ids)]
  } else if (is.list(adapter_result)) {
    candidate <- adapter_result$standings %||% adapter_result$ordered_team_ids %||% adapter_result$team_order
    if (is.null(candidate) && !is.null(adapter_result$computed_rank)) candidate <- adapter_result$computed_rank
    if (is.null(candidate)) stop("Phase 14 standings ruleset adapter returned no ordering", call. = FALSE)
    return(phase14_standings_adapter_ranks(candidate, standings))
  } else if (is.numeric(adapter_result) || is.integer(adapter_result)) {
    output <- phase14_standings_nonnegative_integer(adapter_result, "ruleset rank", allow_missing = FALSE)
  } else if (is.character(adapter_result)) {
    team_ids <- phase14_standings_clean_text(adapter_result)
    if (length(team_ids) != nrow(standings) || anyDuplicated(team_ids) || !setequal(team_ids, standings$team_id)) {
      stop("Phase 14 standings ruleset adapter returned the wrong team order", call. = FALSE)
    }
    output <- match(standings$team_id, team_ids)
  } else {
    stop("Phase 14 standings ruleset adapter must return a data frame, rank vector, or team order", call. = FALSE)
  }
  if (length(output) != nrow(standings) || any(output < 1L) || !setequal(output, seq_len(nrow(standings)))) {
    stop("Phase 14 standings ruleset adapter must return contiguous unique ranks", call. = FALSE)
  }
  as.integer(output)
}

`%||%` <- function(left, right) if (!is.null(left)) left else right

phase14_standings_order <- function(data) {
  data[order(data$computed_rank, data$team_id), , drop = FALSE]
}

phase14_compute_standings <- function(
    matches,
    edition_id,
    group_id,
    state_cutoff_utc,
    source_bundle_id,
    ruleset_adapter = NULL,
    team_ids = NULL,
    teams = NULL,
    ruleset_adapter_id = NULL) {
  if (!is.data.frame(matches)) {
    stop("Phase 14 standings matches must be a data frame", call. = FALSE)
  }
  edition_id <- phase14_standings_scalar(edition_id, "edition_id")
  group_id <- phase14_standings_scalar(group_id, "group_id")
  state_cutoff_utc <- phase14_standings_scalar(state_cutoff_utc, "state_cutoff_utc")
  source_bundle_id <- phase14_standings_scalar(source_bundle_id, "source_bundle_id")
  cutoff <- phase14_standings_timestamp(state_cutoff_utc, "state_cutoff_utc")[[1L]]
  if (is.na(cutoff)) stop("Phase 14 standings state_cutoff_utc is invalid", call. = FALSE)

  required <- c("home_team_id", "away_team_id", "final_home_goals", "final_away_goals", "counts_for_standings")
  missing <- setdiff(required, names(matches))
  if (length(missing)) {
    stop("Phase 14 standings matches missing fields: ", paste(missing, collapse = ", "), call. = FALSE)
  }

  if (nrow(matches)) {
    phase14_standings_validate_input_key <- function(field, expected) {
      phase14_standings_metadata(matches, field, expected)
    }
    phase14_standings_validate_input_key("edition_id", edition_id)
    phase14_standings_validate_input_key("group_id", group_id)
    phase14_standings_validate_input_key("state_cutoff_utc", state_cutoff_utc)
    phase14_standings_validate_input_key("source_bundle_id", source_bundle_id)
  }

  home_team <- phase14_standings_clean_text(matches$home_team_id)
  away_team <- phase14_standings_clean_text(matches$away_team_id)
  counts <- phase14_standings_logical(matches$counts_for_standings, "counts_for_standings")
  home_goals <- phase14_standings_nonnegative_integer(matches$final_home_goals, "final_home_goals")
  away_goals <- phase14_standings_nonnegative_integer(matches$final_away_goals, "final_away_goals")
  if ("match_id" %in% names(matches)) {
    match_ids <- phase14_standings_clean_text(matches$match_id)
    present_match_ids <- match_ids[!is.na(match_ids)]
    if (anyDuplicated(present_match_ids)) {
      stop("Phase 14 standings matches contain duplicate canonical match_id values", call. = FALSE)
    }
  }
  if (any(counts & (is.na(home_team) | is.na(away_team)))) {
    stop("Phase 14 counted standings matches require both team IDs", call. = FALSE)
  }

  status <- if ("match_status" %in% names(matches)) {
    tolower(phase14_standings_clean_text(matches$match_status))
  } else {
    rep("completed", nrow(matches))
  }
  completed_status <- status %in% c(
    "completed", "complete", "finished", "full_time", "full-time",
    "after_extra_time", "after-extra-time", "after_penalties", "after-penalties", "awarded"
  )
  evidence <- if ("evidence_completed_at_utc" %in% names(matches)) {
    phase14_standings_timestamp(matches$evidence_completed_at_utc, "evidence_completed_at_utc")
  } else {
    rep(as.POSIXct(NA, tz = "UTC"), nrow(matches))
  }
  score_complete <- !is.na(home_goals) & !is.na(away_goals)
  eligible <- counts & completed_status & score_complete & !is.na(evidence) & evidence <= cutoff

  supplied_team_ids <- team_ids %||% teams
  if (is.data.frame(supplied_team_ids)) {
    candidate_fields <- intersect(c("team_id", "team", "id"), names(supplied_team_ids))
    if (!length(candidate_fields)) stop("Phase 14 standings teams must include team_id", call. = FALSE)
    supplied_team_ids <- supplied_team_ids[[candidate_fields[[1L]]]]
  }
  supplied_team_ids <- if (is.null(supplied_team_ids)) character() else phase14_standings_clean_text(supplied_team_ids)
  if (any(is.na(supplied_team_ids))) stop("Phase 14 standings team_ids must not be missing", call. = FALSE)
  all_team_ids <- unique(c(home_team, away_team, supplied_team_ids))
  all_team_ids <- sort(all_team_ids[!is.na(all_team_ids)])
  if (!length(all_team_ids)) {
    empty <- data.frame(
      edition_id = character(), group_id = character(), state_cutoff_utc = character(), source_bundle_id = character(),
      team_id = character(), played = integer(), wins = integer(), draws = integer(), losses = integer(),
      goals_for = integer(), goals_against = integer(), goal_difference = integer(), points = integer(),
      computed_rank = integer(), ordering_status = character(), ruleset_adapter_id = character(),
      official_source_bundle_id = character(), official_rank = integer(),
      official_played = integer(), official_wins = integer(), official_draws = integer(), official_losses = integer(),
      official_goals_for = integer(), official_goals_against = integer(), official_goal_difference = integer(), official_points = integer(),
      reconciliation_status = character(), reconciliation_reason = character(), reconciliation_severity = character(),
      publication_disposition = character(), prior_state_action = character(), prior_state_retention = character(),
      warning_status = character(), block_status = character(), blocked = logical(),
      row_sha256 = character(), table_sha256 = character(),
      stringsAsFactors = FALSE, check.names = FALSE
    )
    return(empty)
  }

  rows <- lapply(all_team_ids, function(team_id) {
    home <- eligible & home_team == team_id
    away <- eligible & away_team == team_id
    home_goals_for <- home_goals[home]
    away_goals_for <- away_goals[away]
    goals_for <- c(home_goals_for, away_goals_for)
    goals_against <- c(away_goals[home], home_goals[away])
    wins <- sum(goals_for > goals_against)
    draws <- sum(goals_for == goals_against)
    losses <- sum(goals_for < goals_against)
    data.frame(
      edition_id = edition_id,
      group_id = group_id,
      state_cutoff_utc = state_cutoff_utc,
      source_bundle_id = source_bundle_id,
      team_id = team_id,
      played = as.integer(length(goals_for)),
      wins = as.integer(wins),
      draws = as.integer(draws),
      losses = as.integer(losses),
      goals_for = as.integer(sum(goals_for)),
      goals_against = as.integer(sum(goals_against)),
      goal_difference = as.integer(sum(goals_for) - sum(goals_against)),
      points = as.integer(3L * wins + draws),
      computed_rank = NA_integer_,
      ordering_status = if (is.null(ruleset_adapter)) "provisional" else "ruleset_adapter",
      ruleset_adapter_id = phase14_standings_adapter_id(ruleset_adapter, ruleset_adapter_id),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  })
  output <- do.call(rbind, rows)
  provisional_order <- order(
    -output$points,
    -output$goal_difference,
    -output$goals_for,
    -output$wins,
    output$team_id
  )
  output$computed_rank[provisional_order] <- seq_len(nrow(output))

  if (!is.null(ruleset_adapter)) {
    adapter_input <- output
    adapter_result <- tryCatch(
      ruleset_adapter(adapter_input),
      error = function(error) stop("Phase 14 standings ruleset adapter failed: ", conditionMessage(error), call. = FALSE)
    )
    output$computed_rank <- phase14_standings_adapter_ranks(adapter_result, adapter_input)
    output$ordering_status <- "ruleset_adapter"
  }

  output <- phase14_standings_order(output)
  output$official_source_bundle_id <- NA_character_
  output$official_rank <- NA_integer_
  for (field in phase14_standings_official_metric_fields()) output[[field]] <- NA_integer_
  output$reconciliation_status <- "not_reconciled"
  output$reconciliation_reason <- "not_reconciled"
  output$reconciliation_severity <- "none"
  output$publication_disposition <- "not_published"
  output$prior_state_action <- "none"
  output$prior_state_retention <- "not_applicable"
  output$warning_status <- "none"
  output$block_status <- "not_blocked"
  output$blocked <- FALSE
  output <- output[, setdiff(phase14_standings_schema(), c("row_sha256", "table_sha256")), drop = FALSE]
  output <- phase14_standings_apply_hashes(output)
  phase14_validate_standings_snapshot(output)
  output
}

phase14_standings_prepare_computed <- function(computed) {
  if (!is.data.frame(computed)) stop("Phase 14 computed standings must be a data frame", call. = FALSE)
  required <- c(phase14_standings_snapshot_key_fields(), "team_id", phase14_standings_metric_fields(), "computed_rank")
  missing <- setdiff(required, names(computed))
  if (length(missing)) stop("Phase 14 computed standings missing fields: ", paste(missing, collapse = ", "), call. = FALSE)
  output <- computed
  output[phase14_standings_snapshot_key_fields()] <- lapply(output[phase14_standings_snapshot_key_fields()], phase14_standings_clean_text)
  output$team_id <- phase14_standings_clean_text(output$team_id)
  output[phase14_standings_metric_fields()] <- Map(
    function(values, field) phase14_standings_metric_integer(values, field, allow_missing = FALSE),
    output[phase14_standings_metric_fields()],
    phase14_standings_metric_fields()
  )
  output$computed_rank <- phase14_standings_nonnegative_integer(output$computed_rank, "computed_rank", allow_missing = FALSE)
  if (!"ordering_status" %in% names(output)) output$ordering_status <- "provisional"
  if (!"ruleset_adapter_id" %in% names(output)) output$ruleset_adapter_id <- "none"
  phase14_standings_validate_snapshot_key(output, context = "computed standings")
  phase14_standings_validate_metrics(output, context = "computed standings")
  output[, phase14_standings_core_schema(), drop = FALSE]
}

phase14_standings_official_value <- function(data, field) {
  official_field <- paste0("official_", field)
  if (official_field %in% names(data)) return(data[[official_field]])
  if (field %in% names(data)) return(data[[field]])
  rep(NA, nrow(data))
}

phase14_standings_prepare_official <- function(official, computed) {
  if (is.null(official)) return(NULL)
  if (!is.data.frame(official)) stop("Phase 14 official standings must be a data frame", call. = FALSE)
  if (!nrow(official)) return(NULL)
  if (!"team_id" %in% names(official)) stop("Phase 14 official standings must include team_id", call. = FALSE)
  output <- data.frame(
    team_id = phase14_standings_clean_text(official$team_id),
    official_source_bundle_id = if ("official_source_bundle_id" %in% names(official)) {
      phase14_standings_clean_text(official$official_source_bundle_id)
    } else if ("source_bundle_id" %in% names(official)) {
      phase14_standings_clean_text(official$source_bundle_id)
    } else {
      rep(NA_character_, nrow(official))
    },
    official_rank = if ("official_rank" %in% names(official)) {
      phase14_standings_nonnegative_integer(official$official_rank, "official_rank")
    } else if ("rank" %in% names(official)) {
      phase14_standings_nonnegative_integer(official$rank, "official_rank")
    } else if ("position" %in% names(official)) {
      phase14_standings_nonnegative_integer(official$position, "official_rank")
    } else {
      rep(NA_integer_, nrow(official))
    },
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  for (field in phase14_standings_metric_fields()) {
    output[[paste0("official_", field)]] <- phase14_standings_metric_integer(
      phase14_standings_official_value(official, field),
      paste0("official_", field)
    )
  }
  if (any(is.na(output$team_id)) || anyDuplicated(output$team_id)) {
    stop("Phase 14 official standings contain missing or duplicate team IDs", call. = FALSE)
  }
  unknown <- setdiff(output$team_id, computed$team_id)
  if (length(unknown)) stop("Phase 14 official standings contain unknown team IDs", call. = FALSE)
  for (field in phase14_standings_snapshot_key_fields()) {
    if (!field %in% names(official)) next
    values <- phase14_standings_clean_text(official[[field]])
    expected <- computed[[field]][[1L]]
    if (any(!is.na(values) & values != expected)) {
      stop("Phase 14 official standings contain foreign ", field, call. = FALSE)
    }
  }
  output
}

phase14_reconcile_standings <- function(
    computed,
    official = NULL,
    accepted_source_bundle_id = NULL,
    source_bundle_id = NULL,
    prior_state = NULL) {
  computed <- phase14_standings_prepare_computed(computed)
  if (!is.null(source_bundle_id)) accepted_source_bundle_id <- source_bundle_id
  expected_bundle <- computed$source_bundle_id[[1L]]
  if (!is.null(accepted_source_bundle_id)) {
    accepted_source_bundle_id <- phase14_standings_scalar(accepted_source_bundle_id, "accepted_source_bundle_id")
  }

  if (is.null(official)) {
    official_fields <- c("official_source_bundle_id", "official_rank", phase14_standings_official_metric_fields())
    if (any(official_fields %in% names(computed)) && any(vapply(computed[intersect(official_fields, names(computed))], function(values) any(!is.na(values)), logical(1)))) {
      official <- computed
    }
  }
  official <- phase14_standings_prepare_official(official, computed)
  output <- computed
  output$official_source_bundle_id <- NA_character_
  output$official_rank <- NA_integer_
  for (field in phase14_standings_official_metric_fields()) output[[field]] <- NA_integer_
  output$reconciliation_status <- "official_absent_provisional"
  output$reconciliation_reason <- "official_absent_provisional"
  output$reconciliation_severity <- "none"
  output$publication_disposition <- "publish_provisional"
  output$prior_state_action <- "publish_provisional"
  output$prior_state_retention <- "not_applicable"
  output$warning_status <- "none"
  output$block_status <- "not_blocked"
  output$blocked <- FALSE

  for (index in seq_len(nrow(output))) {
    team_id <- output$team_id[[index]]
    official_row <- if (is.null(official)) NULL else official[official$team_id == team_id, , drop = FALSE]
    if (is.null(official_row) || !nrow(official_row)) next
    output$official_source_bundle_id[[index]] <- official_row$official_source_bundle_id[[1L]]
    output$official_rank[[index]] <- official_row$official_rank[[1L]]
    for (field in phase14_standings_official_metric_fields()) output[[field]][[index]] <- official_row[[field]][[1L]]

    official_bundle <- official_row$official_source_bundle_id[[1L]]
    aggregate_values <- as.numeric(official_row[phase14_standings_official_metric_fields()][1L, , drop = TRUE])
    aggregate_missing <- any(is.na(aggregate_values))
    rank_missing <- is.na(official_row$official_rank[[1L]])
    accepted_bundle_mismatch <- !is.null(accepted_source_bundle_id) &&
      !is.na(accepted_source_bundle_id) &&
      !identical(expected_bundle, accepted_source_bundle_id)
    if (accepted_bundle_mismatch) {
      status <- "foreign_source_bundle_rejected"
    } else if (!is.na(official_bundle) && !identical(official_bundle, expected_bundle)) {
      status <- "foreign_source_bundle_rejected"
    } else if (is.na(official_bundle) && is.na(official_row$official_rank[[1L]]) && aggregate_missing) {
      status <- "official_absent_provisional"
    } else if (aggregate_missing || rank_missing) {
      status <- "partial_official_blocked"
    } else {
      computed_values <- as.numeric(output[index, phase14_standings_metric_fields(), drop = TRUE])
      status <- if (any(computed_values != aggregate_values)) {
        "aggregate_mismatch_blocked"
      } else if (!identical(output$computed_rank[[index]], official_row$official_rank[[1L]])) {
        "rank_only_warning"
      } else {
        "exact"
      }
    }
    output$reconciliation_status[[index]] <- status
    output$reconciliation_reason[[index]] <- status
    if (identical(status, "exact")) {
      output$reconciliation_severity[[index]] <- "none"
      output$publication_disposition[[index]] <- "publish_reconciled"
      output$prior_state_action[[index]] <- "publish_reconciled"
      output$prior_state_retention[[index]] <- "not_applicable"
      output$warning_status[[index]] <- "none"
      output$block_status[[index]] <- "not_blocked"
      output$blocked[[index]] <- FALSE
      output$ordering_status[[index]] <- "official_reconciled"
    } else if (identical(status, "rank_only_warning")) {
      output$reconciliation_severity[[index]] <- "warning"
      output$publication_disposition[[index]] <- "publish_reconciled"
      output$prior_state_action[[index]] <- "publish_reconciled"
      output$prior_state_retention[[index]] <- "not_applicable"
      output$warning_status[[index]] <- "warning"
      output$block_status[[index]] <- "not_blocked"
      output$blocked[[index]] <- FALSE
      output$ordering_status[[index]] <- "official_reconciled"
    } else if (identical(status, "official_absent_provisional")) {
      output$reconciliation_severity[[index]] <- "none"
      output$publication_disposition[[index]] <- "publish_provisional"
      output$prior_state_action[[index]] <- "publish_provisional"
      output$prior_state_retention[[index]] <- "not_applicable"
      output$warning_status[[index]] <- "none"
      output$block_status[[index]] <- "not_blocked"
      output$blocked[[index]] <- FALSE
      output$ordering_status[[index]] <- "provisional"
    } else {
      output$reconciliation_severity[[index]] <- "block"
      output$publication_disposition[[index]] <- "retain_prior"
      output$prior_state_action[[index]] <- "retain_prior"
      output$prior_state_retention[[index]] <- "retain_prior"
      output$warning_status[[index]] <- "none"
      output$block_status[[index]] <- if (identical(status, "foreign_source_bundle_rejected")) "rejected" else "blocked"
      output$blocked[[index]] <- TRUE
      output$ordering_status[[index]] <- if (identical(status, "foreign_source_bundle_rejected")) "rejected" else "blocked"
    }
  }
  output <- output[, setdiff(phase14_standings_schema(), c("row_sha256", "table_sha256")), drop = FALSE]
  output <- phase14_standings_apply_hashes(output)
  phase14_validate_standings_snapshot(output)
  output
}

phase14_validate_standings_snapshot <- function(
    snapshot,
    verify_hashes = TRUE,
    strict = TRUE) {
  if (!is.data.frame(snapshot)) stop("Phase 14 standings snapshot must be a data frame", call. = FALSE)
  required <- phase14_standings_core_schema()
  missing <- setdiff(required, names(snapshot))
  if (length(missing)) stop("Phase 14 standings snapshot missing fields: ", paste(missing, collapse = ", "), call. = FALSE)
  phase14_standings_validate_snapshot_key(snapshot)
  phase14_standings_validate_metrics(snapshot)

  if ("ordering_status" %in% names(snapshot)) {
    allowed_ordering <- c("provisional", "ruleset_adapter", "official_reconciled", "blocked", "rejected")
    if (any(is.na(snapshot$ordering_status) | !snapshot$ordering_status %in% allowed_ordering)) {
      stop("Phase 14 standings snapshot has an invalid ordering_status", call. = FALSE)
    }
  }
  if ("ruleset_adapter_id" %in% names(snapshot) && any(is.na(phase14_standings_clean_text(snapshot$ruleset_adapter_id)))) {
    stop("Phase 14 standings snapshot has a missing ruleset_adapter_id", call. = FALSE)
  }

  reconciliation_fields <- phase14_standings_reconciliation_schema()
  has_reconciliation <- all(reconciliation_fields %in% names(snapshot))
  if (isTRUE(strict) && any(reconciliation_fields %in% names(snapshot)) && !has_reconciliation) {
    stop("Phase 14 standings snapshot has an incomplete reconciliation schema", call. = FALSE)
  }
  if (has_reconciliation && nrow(snapshot)) {
    status <- as.character(snapshot$reconciliation_status)
    if (any(is.na(status))) stop("Phase 14 standings snapshot has missing reconciliation status", call. = FALSE)
    aggregate_fields <- phase14_standings_metric_fields()
    official_fields <- phase14_standings_official_metric_fields()
    for (index in seq_len(nrow(snapshot))) {
      official_bundle <- phase14_standings_clean_text(snapshot$official_source_bundle_id[[index]])
      computed_bundle <- snapshot$source_bundle_id[[index]]
      official_values <- as.numeric(snapshot[index, official_fields, drop = TRUE])
      computed_values <- as.numeric(snapshot[index, aggregate_fields, drop = TRUE])
      current_status <- status[[index]]
      if (identical(current_status, "official_absent_provisional")) {
        if (!is.na(official_bundle) || !is.na(snapshot$official_rank[[index]]) || any(!is.na(official_values)) ||
            !identical(snapshot$ordering_status[[index]], "provisional")) {
          stop("Phase 14 standings official absence is not provisional and unresolved", call. = FALSE)
        }
      } else if (identical(current_status, "foreign_source_bundle_rejected")) {
        if (is.na(official_bundle) || identical(official_bundle, computed_bundle) ||
            !isTRUE(snapshot$blocked[[index]]) || snapshot$publication_disposition[[index]] != "retain_prior") {
          stop("Phase 14 standings foreign source bundle was not rejected", call. = FALSE)
        }
      } else if (identical(current_status, "partial_official_blocked")) {
        if (!isTRUE(snapshot$blocked[[index]]) || snapshot$publication_disposition[[index]] != "retain_prior") {
          stop("Phase 14 standings partial official evidence was not blocked", call. = FALSE)
        }
      } else if (identical(current_status, "aggregate_mismatch_blocked")) {
        if (any(is.na(official_values)) || !any(computed_values != official_values) ||
            !isTRUE(snapshot$blocked[[index]]) || snapshot$publication_disposition[[index]] != "retain_prior") {
          stop("Phase 14 standings aggregate mismatch was not blocked", call. = FALSE)
        }
      } else if (identical(current_status, "rank_only_warning")) {
        if (any(is.na(official_values)) || any(computed_values != official_values) ||
            is.na(snapshot$official_rank[[index]]) || snapshot$computed_rank[[index]] == snapshot$official_rank[[index]] ||
            isTRUE(snapshot$blocked[[index]]) || snapshot$publication_disposition[[index]] != "publish_reconciled") {
          stop("Phase 14 standings rank-only mismatch is not a warning-only reconciliation", call. = FALSE)
        }
      } else if (identical(current_status, "exact")) {
        if (any(is.na(official_values)) || any(computed_values != official_values) ||
            is.na(snapshot$official_rank[[index]]) || snapshot$computed_rank[[index]] != snapshot$official_rank[[index]] ||
            isTRUE(snapshot$blocked[[index]]) || snapshot$publication_disposition[[index]] != "publish_reconciled") {
          stop("Phase 14 standings exact reconciliation is not exact", call. = FALSE)
        }
      } else if (identical(current_status, "not_reconciled")) {
        if (any(!is.na(official_values)) || !is.na(official_bundle) || !is.na(snapshot$official_rank[[index]])) {
          stop("Phase 14 standings not-reconciled row contains official evidence", call. = FALSE)
        }
      } else {
        stop("Phase 14 standings has unsupported reconciliation status: ", current_status, call. = FALSE)
      }
    }
  }

  if (isTRUE(verify_hashes)) {
    if (!all(c("row_sha256", "table_sha256") %in% names(snapshot))) {
      stop("Phase 14 standings snapshot is missing canonical hashes", call. = FALSE)
    }
    expected_rows <- phase14_standings_row_hashes(snapshot)
    actual_rows <- tolower(as.character(snapshot$row_sha256))
    if (!identical(actual_rows, tolower(expected_rows))) {
      stop("Phase 14 standings row hash mismatch", call. = FALSE)
    }
    expected_table <- phase14_standings_table_hash(snapshot)
    actual_table <- tolower(as.character(snapshot$table_sha256))
    if (any(actual_table != tolower(expected_table))) {
      stop("Phase 14 standings table hash mismatch", call. = FALSE)
    }
  }
  invisible(TRUE)
}
