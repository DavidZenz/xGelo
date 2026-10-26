# WC-style sufficient statistics; the simulation's football rules remain in
# the existing iteration kernel. No full history is retained by these reducers.
uefa_nl_stream_path_fields <- function() c("p_quarter_final", "p_semi_final", "p_third_place", "p_final", "p_champion", "p_direct_promotion", "p_direct_relegation", "p_playoff_eligibility", "p_playoff_win", "p_playoff_loss", "p_promotion", "p_relegation")

uefa_nl_stream_capture <- function(value) {
  standings <- uefa_nl_sim_bind_rows(value$state$group_rankings)
  standings$rank <- as.integer(standings$group_position)
  list(rankings = uefa_nl_sim_rank_capture(value), standings = standings)
}

# Counters are vectors during a chunk. Only previously unseen keys allocate a
# representative row; conversion to the compatible bucket format is once per
# chunk, rather than an R get/modify/assign loop for every observed row.
uefa_nl_stream_counter_state <- function(names) {
  structure(stats::setNames(lapply(names, function(name) {
    table <- new.env(parent = emptyenv())
    table$keys <- character(); table$n <- numeric(); table$rows <- list()
    table$iterations <- integer(); table$indexes <- integer()
    table$value_fields <- list(); table$histograms <- list()
    table
  }), names), class = c("uefa_nl_counter_state", "list"))
}

uefa_nl_stream_observe <- function(table, rows, fields, numeric_fields, iteration, histogram_fields) {
  if (!is.data.frame(rows) || !nrow(rows)) return(invisible(NULL))
  keys <- simulation_bucket_keys(rows, fields)
  indexes <- match(keys, table$keys)
  added <- unique(keys[is.na(indexes)])
  if (length(added)) {
    first <- match(added, keys)
    table$keys <- c(table$keys, added)
    table$n <- c(table$n, numeric(length(added)))
    table$rows <- c(table$rows, lapply(first, function(i) rows[i, , drop = FALSE]))
    table$iterations <- c(table$iterations, rep.int(as.integer(iteration), length(added)))
    table$indexes <- c(table$indexes, as.integer(first))
    table$value_fields <- c(table$value_fields, rep(list(numeric_fields), length(added)))
    indexes <- match(keys, table$keys)
  }
  table$n <- table$n + tabulate(indexes, nbins = length(table$keys))
  for (field in histogram_fields) {
    values <- as.numeric(rows[[field]])
    tokens <- ifelse(is.na(values), "<NA>", as.character(values))
    keys <- paste(indexes, tokens, sep = "\x1f")
    histogram <- table$histograms[[field]]
    if (is.null(histogram)) histogram <- list(keys = character(), n = numeric(), bucket = integer(), token = character())
    locations <- match(keys, histogram$keys)
    added <- unique(keys[is.na(locations)])
    if (length(added)) {
      first <- match(added, keys)
      histogram$keys <- c(histogram$keys, added)
      histogram$n <- c(histogram$n, numeric(length(added)))
      histogram$bucket <- c(histogram$bucket, indexes[first])
      histogram$token <- c(histogram$token, tokens[first])
      locations <- match(keys, histogram$keys)
    }
    histogram$n <- histogram$n + tabulate(locations, nbins = length(histogram$keys))
    table$histograms[[field]] <- histogram
  }
  invisible(NULL)
}

uefa_nl_stream_finalize_counters <- function(state) {
  if (!inherits(state, "uefa_nl_counter_state")) return(state)
  output <- simulation_bucket_state(names(state))
  for (name in names(state)) {
    table <- state[[name]]
    for (i in seq_along(table$keys)) {
      fields <- table$value_fields[[i]]
      values <- stats::setNames(lapply(fields, function(field) {
        histogram <- table$histograms[[field]]
        if (is.null(histogram)) return(numeric())
        selected <- which(histogram$bucket == i)
        stats::setNames(histogram$n[selected], histogram$token[selected])
      }), fields)
      assign(table$keys[[i]], list(row = table$rows[[i]], ordinal = c(table$iterations[[i]], table$indexes[[i]]),
        n = table$n[[i]], values = values), output[[name]])
    }
  }
  output
}

uefa_nl_stream_reducer <- function() {
  add_rows <- function(table, rows, fields, numeric, iteration, histogram = FALSE) {
    uefa_nl_stream_observe(table, rows, intersect(fields, names(rows)), intersect(numeric, names(rows)),
      iteration, if (histogram) intersect(numeric, names(rows)) else character())
  }
  list(init = function() uefa_nl_stream_counter_state(c("rankings", "standings", "paths", "transitions", "fixtures", "euro", "slots")),
    update = function(state, value, iteration) {
      capture <- attr(value, "nl_stream_capture", exact = TRUE)
      if (is.null(capture)) capture <- uefa_nl_stream_capture(value)
      ranking <- capture$rankings; ranking$iteration <- NULL
      keys <- c("ranking_scope", "team_id", "league", "group_id", "group_position", "rank", "interim_overall_rank", "final_overall_rank", "ranking_stage")
      add_rows(state$rankings, ranking, keys, character(), iteration)
      standings <- capture$standings
      add_rows(state$standings, standings, c("league", "group_id", "team_id", "rank"), c("points", "goal_difference"), iteration)
      add_rows(state$paths, value$paths, c("team_id", "status", "suppression_reason"), uefa_nl_stream_path_fields(), iteration)
      transitions <- value$transition_events
      probabilities <- intersect(c("probability", "playoff_eligibility_probability", "playoff_win_probability", "playoff_loss_probability"), names(transitions))
      transitions$iteration <- NULL
      add_rows(state$transitions, transitions, setdiff(names(transitions), c(probabilities, "row_sha256", "table_sha256")), probabilities, iteration)
      add_rows(state$fixtures, value$fixture_rows, c("fixture_id", "outcome_class"), character(), iteration)
      add_rows(state$euro, value$euro_priority, c("team_id"), c(uefa_euro_priority_metrics()), iteration, histogram = TRUE)
      slots <- value$stage_slots
      # Match the publisher's projected/unresolved/suppressed grouping exactly.
      if (nrow(slots)) {
        slots$.stream_status <- tolower(as.character(slots$stage_status))
        slots$.stream_status[is.na(slots$.stream_status) | !slots$.stream_status %in% c("projected", "unresolved", "suppressed", "official", "completed")] <- "unresolved"
        slots$.stream_status[slots$.stream_status %in% c("official", "completed")] <- "projected"
        for (pair in list(c(".stream_slot_home", "participant_slot_home"), c(".stream_slot_away", "participant_slot_away"), c(".stream_home", "home_team_id"), c(".stream_away", "away_team_id"))) {
          slots[[pair[[1L]]]] <- ifelse(slots$.stream_status == "projected", slots[[pair[[2L]]]], "")
        }
        keys <- c("stage_id", "leg_number", ".stream_slot_home", ".stream_slot_away", ".stream_status", ".stream_home", ".stream_away")
        add_rows(state$slots, slots, keys, character(), iteration)
      }
      state
    }, finalize = uefa_nl_stream_finalize_counters,
    merge = function(left, right) simulation_bucket_merge_state(
      uefa_nl_stream_finalize_counters(left), uefa_nl_stream_finalize_counters(right)))
}

uefa_nl_stream_bind_buckets <- function(buckets) {
  if (!length(buckets)) return(data.frame())
  rows <- uefa_nl_sim_bind_rows(lapply(buckets, `[[`, "row"))
  row.names(rows) <- NULL
  rows
}
uefa_nl_stream_rankings <- function(statistics, count, metadata) {
  buckets <- simulation_bucket_values(statistics$rankings)
  rows <- lapply(buckets, function(bucket) {
    row <- bucket$row
    row$probability <- if (is.na(suppressWarnings(as.numeric(as.character(row$rank))))) NA_real_ else bucket$n / count
    row$rank_probability <- row$probability; row$simulation_count <- as.integer(count)
    fields <- intersect(c("ranking_scope", "team_id", "league", "group_id", "group_position", "rank", "interim_overall_rank", "final_overall_rank", "ranking_stage", "ordering_status", "missing_rule_input", "suppression_reason", "counted_match_ids", "excluded_match_ids"), names(row))
    row[, c(fields, setdiff(names(row), fields)), drop = FALSE]
  })
  uefa_nl_stream_metadata(uefa_nl_sim_bind_rows(rows), count, metadata)
}
uefa_nl_stream_metadata <- function(data, count, metadata) uefa_nl_sim_add_metadata(data,
  metadata$edition_id, metadata$projection_run_id, count, metadata$simulation_seed,
  metadata$rules, metadata$source_bundle_id, metadata$source_bundle_sha256, metadata$model_release_id)

uefa_nl_stream_prepare_metadata <- function(count, metadata) {
  values <- list(edition_id = as.character(metadata$edition_id), projection_run_id = as.character(metadata$projection_run_id),
    simulation_count = as.integer(count), simulation_seed = as.integer(metadata$simulation_seed),
    ruleset_version = as.character(metadata$rules$ruleset_version), ruleset_sha256 = uefa_nl_ruleset_sha256(metadata$rules),
    source_bundle_id = as.character(metadata$source_bundle_id), source_bundle_sha256 = as.character(metadata$source_bundle_sha256),
    model_release_id = as.character(metadata$model_release_id))
  function(data) {
    if (!is.data.frame(data) || !nrow(data)) return(data)
    for (field in names(values)) data[[field]] <- rep(values[[field]], length.out = nrow(data))
    data
  }
}

uefa_nl_stream_standings <- function(statistics, count, metadata, groups, matches) {
  # Reuse the legacy schema/completed-group policy with one representative run;
  # replace every measure using the sufficient statistics below.
  buckets <- simulation_bucket_values(statistics$standings)
  frames <- lapply(buckets, `[[`, "row")
  fake <- list(list(state = list(group_rankings = frames), paths = data.frame(iteration = 1L)))
  output <- uefa_nl_sim_aggregate_standings(fake, 1L, metadata, groups, matches)
  for (index in seq_len(nrow(output))) {
    row <- output[index, , drop = FALSE]
    team <- Filter(function(b) identical(as.character(b$row$league), as.character(row$league)) && identical(as.character(b$row$group_id), as.character(row$group_id)) && identical(as.character(b$row$team_id), as.character(row$team_id)), buckets)
    complete <- sum(vapply(team, `[[`, numeric(1), "n")) >= count &&
      all(vapply(team, function(b) is.finite(as.numeric(b$row$rank)), logical(1)))
    selected <- Filter(function(b) !is.na(b$row$rank) && b$row$rank == row$rank, team)
    output$probability[[index]] <- if (complete) sum(vapply(selected, `[[`, numeric(1), "n")) / count else NA_real_
    output$ranking_status[[index]] <- if (!complete) "unresolved" else if (output$ranking_status[[index]] == "resolved") "resolved" else "projected"
    for (pair in list(c("expected_points", "points"), c("expected_goal_difference", "goal_difference"))) {
      output[[pair[[1L]]]][[index]] <- if (length(selected)) uefa_nl_stream_exact_mean(statistics, "standings", selected[[1L]]$row, c("league", "group_id", "team_id", "rank"), pair[[2L]]) else NA_real_
    }
  }
  uefa_nl_stream_metadata(output, count, metadata)
}
uefa_nl_stream_paths <- function(statistics, count, metadata, groups) {
  buckets <- simulation_bucket_values(statistics$paths, FALSE)
  fields <- uefa_nl_stream_path_fields()
  rows <- lapply(sort(as.character(groups$team_id), method = "radix"), function(team) {
    values <- Filter(function(b) identical(as.character(b$row$team_id), team), buckets)
    if (!length(values)) return(data.frame(team_id = team))
    order_first <- order(vapply(values, function(b) b$ordinal[[1L]], numeric(1)), vapply(values, function(b) b$ordinal[[2L]], numeric(1)))
    values <- values[order_first]
    statuses <- vapply(values, function(b) {
      s <- tolower(trimws(as.character(b$row$status))); if (is.na(s) || !nzchar(s)) "projected" else s
    }, character(1))
    status <- if (any(statuses == "suppressed")) "suppressed" else if (any(statuses == "unresolved")) "unresolved" else "projected"
    row <- values[[1L]]$row[, setdiff(names(values[[1L]]$row), c("iteration", fields, "status", "suppression_reason")), drop = FALSE]
    for (field in fields) row[[field]] <- if (status %in% c("suppressed", "unresolved")) NA_real_ else uefa_nl_stream_exact_mean(statistics, "paths", values[[1L]]$row, "team_id", field)
    row$status <- status
    reasons <- unique(vapply(values[statuses == "suppressed"], function(b) as.character(b$row$suppression_reason), character(1)))
    reasons <- reasons[!is.na(reasons) & nzchar(trimws(reasons))]
    row$suppression_reason <- if (status == "suppressed") paste(reasons, collapse = ";") else ""
    row$simulation_count <- as.integer(count); row
  })
  uefa_nl_stream_metadata(uefa_nl_sim_bind_rows(rows), count, metadata)
}
uefa_nl_stream_transitions <- function(statistics, count, metadata) {
  buckets <- simulation_bucket_values(statistics$transitions)
  if (!length(buckets)) return(data.frame())
  rows <- lapply(buckets, function(b) {
    row <- b$row
    for (field in names(b$values)) row[[field]] <- uefa_nl_stream_exact_mean(statistics, "transitions", row, setdiff(names(row), c(names(b$values), "row_sha256", "table_sha256")), field)
    row$simulation_count <- as.integer(count); row$row_sha256 <- NULL; row
  })
  output <- uefa_nl_stream_metadata(uefa_nl_sim_bind_rows(rows), count, metadata)
  if (nrow(output)) output$row_sha256 <- uefa_nl_rules_row_sha256(output)
  output
}
uefa_nl_stream_fixtures <- function(statistics, matches, status, forecasts, count, metadata) {
  buckets <- simulation_bucket_values(statistics$fixtures, FALSE)
  representatives <- lapply(buckets, function(b) b$row)
  output <- uefa_nl_sim_aggregate_fixtures(matches, status, forecasts,
    uefa_nl_sim_bind_rows(representatives), count, metadata, metadata$source_bundle_sha256, metadata$state_manifest_sha256)
  for (index in seq_len(nrow(output))) {
    bs <- Filter(function(b) identical(as.character(b$row$fixture_id), as.character(output$fixture_id[[index]])), buckets)
    if (length(bs)) {
      first <- bs[[which.min(vapply(bs, function(b) b$ordinal[[1L]], numeric(1)))]]$row
      output$forecast_status[[index]] <- as.character(first$forecast_status)
      output$suppression_reason[[index]] <- as.character(first$suppression_reason)
    }
    available <- Filter(function(b) !is.na(b$row$outcome_class), bs)
    n <- sum(vapply(available, `[[`, numeric(1), "n"))
    for (outcome in c("home", "draw", "away")) output[[paste0("p_", outcome)]][[index]] <- if (!n) NA_real_ else sum(vapply(available, function(b) if (b$row$outcome_class == outcome) b$n else 0, numeric(1))) / n
  }
  output
}
uefa_nl_stream_euro <- function(statistics, groups, count) {
  buckets <- simulation_bucket_values(statistics$euro)
  policy <- uefa_euro_priority_policy(); metrics <- uefa_euro_priority_metrics()
  roster <- groups[order(as.character(groups$team_id), method = "radix"), c("team_id", "league", "group_id"), drop = FALSE]
  rows <- lapply(seq_len(nrow(roster)), function(index) {
    row <- roster[index, , drop = FALSE]
    key <- simulation_bucket_key(row, "team_id")
    b <- buckets[[key]]
    for (metric in metrics) {
      available <- !is.null(b) && b$n == count && length(b$values[[metric]]) && !"<NA>" %in% names(b$values[[metric]])
      row[[metric]] <- if (available) uefa_nl_stream_exact_mean(statistics, "euro", row, "team_id", metric) else NA_real_
      row[[paste0(metric, "_reason")]] <- if (available) "" else "incomplete_simulated_group_or_interim_ordering"
    }
    qs <- if (is.finite(row$expected_queue_position)) simulation_hist_quantile(b$values$expected_queue_position, c(.1, .9), policy$quantile_type) else c(NA_real_, NA_real_)
    row$queue_position_p10 <- unname(qs[[1L]]); row$queue_position_p90 <- unname(qs[[2L]])
    row$status <- if (all(is.finite(unlist(row[metrics])))) "projected" else "unresolved"
    row$priority_policy_version <- policy$policy_version
    row$priority_policy_sha256 <- uefa_euro_priority_policy_sha256(policy); row
  })
  do.call(rbind, rows)
}
uefa_nl_stream_modal_slots <- function(statistics) {
  bs <- simulation_bucket_values(statistics$slots, FALSE)
  if (!length(bs)) return(data.frame())
  keys <- vapply(bs, function(b) simulation_bucket_key(b$row, c("stage_id", "leg_number", ".stream_slot_home", ".stream_slot_away", ".stream_status")), character(1))
  selected <- lapply(split(seq_along(bs), keys), function(indexes) {
    present <- vapply(bs[indexes], function(b) !is.na(b$row$.stream_home) && nzchar(trimws(b$row$.stream_home)) && !is.na(b$row$.stream_away) && nzchar(trimws(b$row$.stream_away)), logical(1))
    candidates <- indexes[present]
    if (!length(candidates)) candidates <- indexes else {
      ns <- vapply(bs[candidates], `[[`, numeric(1), "n")
      candidates <- candidates[ns == max(ns)]
      pairs <- vapply(bs[candidates], function(b) paste(b$row$.stream_home, b$row$.stream_away, sep = "::"), character(1))
      candidates <- candidates[order(pairs, method = "radix")[[1L]]]
    }
    bs[[candidates[[which.min(vapply(bs[candidates], function(b) b$ordinal[[1L]] * 100000 + b$ordinal[[2L]], numeric(1)))]]]]
  })
  selected <- selected[order(vapply(selected, function(b) b$ordinal[[1L]], numeric(1)), vapply(selected, function(b) b$ordinal[[2L]], numeric(1)))]
  rows <- uefa_nl_stream_bind_buckets(selected); rows[, !grepl("^\\.stream_", names(rows)), drop = FALSE]
}

uefa_nl_stream_mean_records <- function(value) {
  key_parts <- value_parts <- list()
  append <- function(table, rows, keys, metrics) {
    if (!nrow(rows)) return(invisible(NULL))
    if (any(!metrics %in% names(rows))) stop("Missing streamed mean fields: ", table, call. = FALSE)
    key <- simulation_bucket_keys(rows, keys)
    for (metric in metrics) {
      key_parts[[length(key_parts) + 1L]] <<- paste(table, key, metric, sep = "\x1d")
      value_parts[[length(value_parts) + 1L]] <<- as.numeric(rows[[metric]])
    }
  }
  capture <- attr(value, "nl_stream_capture", exact = TRUE)
  if (is.null(capture)) capture <- uefa_nl_stream_capture(value)
  rows <- capture$standings
  append("standings", rows, c("league", "group_id", "team_id", "rank"), c("points", "goal_difference"))
  append("paths", value$paths, "team_id", uefa_nl_stream_path_fields())
  append("euro", value$euro_priority, "team_id", uefa_euro_priority_metrics())
  transitions <- value$transition_events; transitions$iteration <- NULL
  metrics <- intersect(c("probability", "playoff_eligibility_probability", "playoff_win_probability", "playoff_loss_probability"), names(transitions))
  append("transitions", transitions, setdiff(names(transitions), c(metrics, "row_sha256", "table_sha256")), metrics)
  if (!length(key_parts)) return(data.frame(key = character(), value = numeric()))
  data.frame(key = unlist(key_parts, use.names = FALSE), value = unlist(value_parts, use.names = FALSE), stringsAsFactors = FALSE)
}
uefa_nl_stream_exact_mean <- function(statistics, table, row, keys, field) {
  key <- paste(table, simulation_bucket_key(row, keys), field, sep = "\x1d")
  if (!exists(key, statistics$exact_means, inherits = FALSE)) stop("Missing exact streamed mean: ", table, call. = FALSE)
  get(key, statistics$exact_means, inherits = FALSE)
}
