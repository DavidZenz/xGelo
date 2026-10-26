# Prepared private knockout helpers. Public draw/resolution functions remain
# authoritative for unsupported inputs and all extra-time/penalty decisions.
uefa_nl_sim_prepare_paths <- function(runtime, rules, official_slots) {
  if (isTRUE(runtime$uefa_nl_paths_prepared)) return(runtime)
  scope <- environment()
  parent.env(scope) <- runtime
  fixed_rules <- rules
  fixed_slots <- official_slots
  frame <- function(columns, n) structure(columns, class = "data.frame", row.names = if (n) c(NA_integer_, -as.integer(n)) else integer())
  original_paths <- runtime$uefa_nl_sim_iteration_paths
  original_projection <- runtime$uefa_nl_sim_projection_ids
  original_slots <- runtime$uefa_nl_sim_stage_slots
  original_topology <- runtime$uefa_nl_stage_topology
  original_pairings <- runtime$uefa_nl_sim_pairings_from_slots
  original_official <- runtime$uefa_nl_sim_stage_match_rows_from_official
  original_leg <- runtime$uefa_nl_sim_leg_scores
  original_two <- runtime$uefa_nl_resolve_two_leg_tie
  original_single <- runtime$uefa_nl_resolve_single_leg
  original_qf <- runtime$uefa_nl_draw_quarter_finals
  original_sf <- runtime$uefa_nl_draw_semi_finals
  original_transition_pair <- runtime$uefa_nl_sim_transition_pair
  original_resolution_row <- runtime$uefa_nl_sim_stage_resolution_row
  topology <- original_topology(rules)
  rules_hash <- uefa_nl_ruleset_sha256(rules)
  policy_hashes <- new.env(parent = emptyenv())
  leg_schemas <- new.env(parent = emptyenv())
  legal_draws <- new.env(parent = emptyenv())
  empty <- frame(list(), 0L)
  runtime$uefa_nl_stage_topology <- function(rules = fixed_rules) {
    if (identical(rules, fixed_rules)) topology else original_topology(rules)
  }
  runtime$uefa_nl_sim_projection_ids <- function(projection_run_id, draw_policy_id, seed = NULL) {
    if (!length(projection_run_id) || is.na(projection_run_id[[1L]]) || !nzchar(as.character(projection_run_id[[1L]])) || !length(draw_policy_id) || is.na(draw_policy_id[[1L]])) return(original_projection(projection_run_id, draw_policy_id, seed))
    policy <- as.character(draw_policy_id[[1L]])
    if (!nzchar(policy)) return(original_projection(projection_run_id, draw_policy_id, seed))
    if (!exists(policy, envir = policy_hashes, inherits = FALSE)) assign(policy, uefa_nl_sim_hash_data(policy), envir = policy_hashes)
    list(projection_run_id = as.character(projection_run_id[[1L]]), draw_policy_id = policy, draw_policy_sha256 = get(policy, envir = policy_hashes, inherits = FALSE))
  }
  runtime$uefa_nl_sim_stage_slots <- function(stage_id, stage_type, pairs, rules, projection_run_id, draw_policy_id, source_status = "projected") {
    if (!is.data.frame(pairs) || !nrow(pairs)) return(original_slots(stage_id, stage_type, pairs, rules, projection_run_id, draw_policy_id, source_status))
    required <- c("legs", "team_a", "team_b", "slot_a", "slot_b")
    if (!identical(rules, fixed_rules) || !all(required %in% names(pairs)) || anyNA(pairs$legs) || !all(pairs$legs %in% c(1L, 2L)) || !all(lengths(list(stage_id, stage_type, source_status)) == 1L)) return(original_slots(stage_id, stage_type, pairs, rules, projection_run_id, draw_policy_id, source_status))
    ids <- uefa_nl_sim_projection_ids(projection_run_id, draw_policy_id)
    row_index <- rep(seq_len(nrow(pairs)), times = as.integer(pairs$legs))
    leg <- sequence(as.integer(pairs$legs))
    first <- leg == 1L
    n <- length(leg)
    # The reference deliberately puts team_b at home for a one-leg slot, too.
    output <- frame(list(edition_id = rep(as.character(rules$edition_id), n), stage_id = rep(as.character(stage_id), n),
      stage_type = rep(as.character(stage_type), n), stage_status = rep(as.character(source_status), n), leg_number = as.integer(leg),
      participant_slot_home = ifelse(first, as.character(pairs$slot_b[row_index]), as.character(pairs$slot_a[row_index])),
      participant_slot_away = ifelse(first, as.character(pairs$slot_a[row_index]), as.character(pairs$slot_b[row_index])),
      home_team_id = ifelse(first, as.character(pairs$team_b[row_index]), as.character(pairs$team_a[row_index])),
      away_team_id = ifelse(first, as.character(pairs$team_a[row_index]), as.character(pairs$team_b[row_index])),
      source_fixture_id = rep("", n), source_artifact_id = rep("", n), projection_run_id = rep(ids$projection_run_id, n),
      draw_policy_id = rep(ids$draw_policy_id, n), scheduled_at_utc = rep(NA_character_, n), unresolved_reason = rep("", n),
      suppression_reason = rep("", n), ruleset_version = rep(as.character(rules$ruleset_version), n), ruleset_sha256 = rep(rules_hash, n),
      regulation_home_goals = rep(NA_integer_, n), regulation_away_goals = rep(NA_integer_, n), extra_time_home_goals = rep(NA_integer_, n),
      extra_time_away_goals = rep(NA_integer_, n), penalty_shootout_home_goals = rep(NA_integer_, n), penalty_shootout_away_goals = rep(NA_integer_, n),
      final_home_goals = rep(NA_integer_, n), final_away_goals = rep(NA_integer_, n), completed_at_utc = rep(NA_character_, n),
      draw_policy_sha256 = rep(ids$draw_policy_sha256, n)), n)
    output$row_sha256 <- uefa_nl_rules_row_sha256(output)
    output
  }
  # Predecode official fixtures once, preserving the original stage traversal
  # separately for pair decoding and for resolution-row lookup.
  stages <- unique(c(as.character(topology$stage_id), if (is.data.frame(official_slots)) as.character(official_slots$stage_id)))
  official_stages <- pairings <- official_rows <- setNames(vector("list", length(stages)), stages)
  if (is.data.frame(official_slots) && nrow(official_slots)) for (stage in stages) {
    official_stages[[stage]] <- official_slots[official_slots$stage_id == stage, , drop = FALSE]
    pairings[[stage]] <- original_pairings(official_slots, stage, fixed_rules)
    stage_rows <- official_stages[[stage]]
    tie_ids <- if (nrow(stage_rows)) unique(vapply(seq_len(nrow(stage_rows)), function(i) uefa_nl_sim_stage_tie_id(stage_rows[i, , drop = FALSE], stage, i), character(1))) else character()
    official_rows[[stage]] <- setNames(lapply(tie_ids, function(tie) original_official(official_slots, stage, tie)), tie_ids)
  }
  runtime$uefa_nl_sim_pairings_from_slots <- function(slots, stage_id, rules) {
    if (!is.data.frame(slots) || !nrow(slots)) return(empty)
    if (length(stage_id) != 1L || is.na(stage_id)) return(original_pairings(slots, stage_id, rules))
    if (identical(rules, fixed_rules) && stage_id %in% names(pairings) && (identical(slots, fixed_slots) || identical(slots, official_stages[[stage_id]]))) return(pairings[[stage_id]])
    original_pairings(slots, stage_id, rules)
  }
  runtime$uefa_nl_sim_stage_match_rows_from_official <- function(slots, stage_id, tie_id) {
    if (!is.data.frame(slots) || !nrow(slots)) return(empty)
    if (length(stage_id) != 1L || is.na(stage_id) || length(tie_id) != 1L || is.na(tie_id)) return(original_official(slots, stage_id, tie_id))
    if (identical(slots, fixed_slots) && stage_id %in% names(official_rows)) {
      rows <- official_rows[[stage_id]][[tie_id]]
      if (!is.null(rows)) return(rows)
      stage_rows <- official_stages[[stage_id]]
      return(stage_rows[FALSE, , drop = FALSE])
    }
    original_official(slots, stage_id, tie_id)
  }
  aliases <- list(c("regulation_home_goals", "home_goals", "final_home_goals"), c("regulation_away_goals", "away_goals", "final_away_goals"),
    "extra_time_home_goals", "extra_time_away_goals", "final_home_goals", "final_away_goals", c("penalty_shootout_home_goals", "shootout_home_goals"), c("penalty_shootout_away_goals", "shootout_away_goals"))
  score_names <- c("regulation_home", "regulation_away", "extra_home", "extra_away", "final_home", "final_away", "shootout_home", "shootout_away")
  leg_scores <- function(row, index = 1L) {
    fields <- names(row)
    key <- paste(paste0(nchar(fields, type = "bytes"), ":", fields), collapse = "|")
    if (!exists(key, envir = leg_schemas, inherits = FALSE)) {
      positions <- vapply(aliases, function(alias) { position <- match(alias, fields); position <- position[!is.na(position)]; if (length(position)) position[[1L]] else 0L }, integer(1))
      assign(key, positions, envir = leg_schemas)
    }
    positions <- get(key, envir = leg_schemas, inherits = FALSE)
    columns <- unclass(row)
    if (any(vapply(positions[positions > 0L], function(position) !is.numeric(columns[[position]]) || length(columns[[position]]) < index, logical(1)))) return(NULL)
    values <- rep(NA_real_, 8L)
    for (i in which(positions > 0L)) values[[i]] <- as.numeric(columns[[positions[[i]]]][[index]])
    if (any(!is.na(values) & (!is.finite(values) | values < 0 | values != floor(values)))) return(NULL)
    values[is.na(values)] <- NA_real_
    values[3:4][is.na(values[3:4])] <- 0
    if (is.na(values[[5L]])) values[[5L]] <- values[[1L]] + values[[3L]]
    if (is.na(values[[6L]])) values[[6L]] <- values[[2L]] + values[[4L]]
    setNames(as.list(values), score_names)
  }
  runtime$uefa_nl_sim_leg_scores <- function(row) {
    if (!is.data.frame(row) || nrow(row) != 1L) return(original_leg(row))
    scores <- leg_scores(row)
    if (is.null(scores)) original_leg(row) else scores
  }
  valid_seed <- function(seed) is.null(seed) || (length(seed) == 1L && is.numeric(seed) && !is.na(seed) && is.finite(seed) && seed >= 0 && seed <= .Machine$integer.max)
  runtime$uefa_nl_resolve_two_leg_tie <- function(pair, seed = NULL, rules = fixed_rules, lower_league_team_id = NULL, penalty_winner = NULL, second_leg_extra_time = NULL) {
    fallback <- function() original_two(pair, seed, rules, lower_league_team_id, penalty_winner, second_leg_extra_time)
    if (!is.data.frame(pair) || nrow(pair) != 2L || !all(c("leg_number", "home_team_id", "away_team_id") %in% names(pair)) || !valid_seed(seed) || !is.numeric(pair$leg_number) || !setequal(pair$leg_number, 1:2) || anyDuplicated(pair$leg_number)) return(fallback())
    home <- pair$home_team_id; away <- pair$away_team_id
    if (!is.character(home) || !is.character(away) || anyNA(c(home, away)) || any(!nzchar(c(home, away))) || !identical(home, trimws(home)) || !identical(away, trimws(away)) || any(home == away) || home[[1L]] != away[[2L]] || home[[2L]] != away[[1L]]) return(fallback())
    ordering <- order(pair$leg_number, method = "radix")
    first <- leg_scores(pair, ordering[[1L]]); second <- leg_scores(pair, ordering[[2L]])
    if (is.null(first) || is.null(second) || any(!is.finite(c(first$final_home, first$final_away, second$regulation_home, second$regulation_away)))) return(fallback())
    lower <- unique(c(lower_league_team_id, if ("lower_league_team_id" %in% names(pair)) as.character(pair$lower_league_team_id), if ("lower_team_id" %in% names(pair)) as.character(pair$lower_team_id)))
    lower <- lower[!is.na(lower) & nzchar(lower)]
    if (length(lower) > 1L || (length(lower) == 1L && home[[ordering[[1L]]]] != lower[[1L]])) return(fallback())
    teams <- sort(home, method = "radix")
    first_total <- second_total <- setNames(c(0, 0), teams)
    first_total[home[[ordering[[1L]]]]] <- first$final_home
    first_total[away[[ordering[[1L]]]]] <- first$final_away
    second_total[home[[ordering[[2L]]]]] <- second$regulation_home
    second_total[away[[ordering[[2L]]]]] <- second$regulation_away
    aggregate <- first_total + second_total
    if (aggregate[[1L]] == aggregate[[2L]]) return(fallback())
    winner <- names(which.max(aggregate))[[1L]]
    uefa_nl_sim_resolution(stage_status = "completed", winner = winner, loser = setdiff(teams, winner)[[1L]], resolution = "aggregate",
      extra_time_used = FALSE, penalty_used = FALSE, first_leg = first, second_leg = second, aggregate_goals = aggregate,
      aggregate_goals_before_extra_time = aggregate, first_leg_home_team_id = home[[ordering[[1L]]]], second_leg_home_team_id = home[[ordering[[2L]]]],
      penalty_winner_team_id = NA_character_, penalty_resolution_policy = "seeded_bernoulli_0.5")
  }
  runtime$uefa_nl_resolve_single_leg <- function(match, mode = c("extra_time_then_penalties", "penalties_without_extra_time"), seed = NULL, rules = fixed_rules, penalty_winner = NULL, extra_time_score = NULL, tie_break_policy = NULL) {
    fallback <- function() original_single(match, mode, seed, rules, penalty_winner, extra_time_score, tie_break_policy)
    if (!is.data.frame(match) || nrow(match) != 1L || !valid_seed(seed)) return(fallback())
    selected_mode <- if (length(tie_break_policy) && !is.null(tie_break_policy)) tie_break_policy else mode
    selected_mode <- tolower(as.character(selected_mode[[1L]]))
    if (selected_mode %in% c("final", "semi_final", "semi-final", "extra_time", "extra-time-then-penalties")) selected_mode <- "extra_time_then_penalties"
    if (selected_mode %in% c("third_place", "third-place", "direct_penalty", "direct-penalty", "penalties", "penalties-without-extra-time")) selected_mode <- "penalties_without_extra_time"
    if (!selected_mode %in% c("extra_time_then_penalties", "penalties_without_extra_time")) return(fallback())
    home <- uefa_nl_sim_row_value(match, c("home_team_id", "team_a"), NA_character_)
    away <- uefa_nl_sim_row_value(match, c("away_team_id", "team_b"), NA_character_)
    if (!is.character(home) || !is.character(away) || is.na(home) || is.na(away) || !nzchar(home) || !nzchar(away) || identical(home, away)) return(fallback())
    scores <- leg_scores(match)
    if (is.null(scores) || !is.finite(scores$regulation_home) || !is.finite(scores$regulation_away) || scores$regulation_home == scores$regulation_away) return(fallback())
    winner <- if (scores$regulation_home > scores$regulation_away) home else away
    uefa_nl_sim_resolution(stage_status = "completed", winner = winner, loser = if (identical(winner, home)) away else home, resolution = "regulation",
      extra_time_used = FALSE, penalty_used = FALSE, regulation_score = c(home = scores$regulation_home, away = scores$regulation_away),
      final_score = c(home = scores$regulation_home, away = scores$regulation_away), mode = selected_mode,
      penalty_winner_team_id = NA_character_, penalty_resolution_policy = "seeded_bernoulli_0.5")
  }
  runtime$uefa_nl_sim_stage_resolution_row <- function(iteration, stage_id, tie_id, resolution, stage_status = NULL, source_status = "projected") {
    status <- stage_status %||% resolution$stage_status %||% "unresolved"
    values <- list(as.integer(iteration), as.character(stage_id), as.character(tie_id), as.character(status), as.character(source_status),
      as.character(resolution$winner_team_id %||% NA_character_), as.character(resolution$loser_team_id %||% NA_character_),
      as.character(resolution$resolution %||% "unresolved"), isTRUE(resolution$extra_time_used), isTRUE(resolution$penalty_used), as.character(resolution$unresolved_reason %||% ""))
    if (!all(lengths(values) == 1L)) return(original_resolution_row(iteration, stage_id, tie_id, resolution, stage_status, source_status))
    names(values) <- c("iteration", "stage_id", "tie_id", "stage_status", "source_status", "winner_team_id", "loser_team_id", "resolution", "extra_time_used", "penalty_used", "unresolved_reason")
    frame(values, 1L)
  }
  runtime$uefa_nl_sim_transition_pair <- function(row, official_slots = NULL, rules = fixed_rules) {
    if (!is.data.frame(row) || nrow(row) != 1L || !identical(rules, fixed_rules) || !all(c("stage_id", "higher_league_team_id", "lower_league_team_id", "higher_league_rank", "lower_league_rank", "higher_league", "lower_league", "group_id") %in% names(row))) return(original_transition_pair(row, official_slots, rules))
    stage <- as.character(row$stage_id[[1L]])
    high <- as.character(row$higher_league_team_id[[1L]]); low <- as.character(row$lower_league_team_id[[1L]])
    if (is.na(high) || is.na(low) || !nzchar(high) || !nzchar(low) || identical(high, low)) return(NULL)
    official <- uefa_nl_sim_pairings_from_slots(official_slots, stage, rules)
    if (nrow(official)) return(original_transition_pair(row, official_slots, rules))
    frame(list(tie_id = uefa_nl_sim_row_value(row, "tie_id", paste(stage, as.character(row$higher_league_rank[[1L]]), as.character(row$lower_league_rank[[1L]]), sep = "::")),
      pair_index = 1L, legs = 2L, team_a = high, team_b = low,
      slot_a = paste0(as.character(row$higher_league), "-rank-", as.character(row$higher_league_rank)),
      slot_b = paste0(as.character(row$lower_league), "-rank-", as.character(row$lower_league_rank)), group_a = as.character(row$group_id[[1L]]), group_b = NA_character_), 1L)
  }
  runtime$uefa_nl_draw_quarter_finals <- function(group_winners, runners_up = NULL, seed = NULL, projection_run_id = NULL, rules = fixed_rules, official_stage_slots = NULL, pairings = NULL) {
    fallback <- function() original_qf(group_winners, runners_up, seed, projection_run_id, rules, official_stage_slots, pairings)
    if (!is.null(official_stage_slots) || !is.null(pairings) || !identical(rules, fixed_rules) || !is.data.frame(group_winners) || !is.data.frame(runners_up) || !all(c("team_id", "group_id") %in% names(group_winners)) || !all(c("team_id", "group_id") %in% names(runners_up))) return(fallback())
    winners <- group_winners; runners <- runners_up
    if (nrow(winners) != 4L || nrow(runners) != 4L || anyNA(c(winners$team_id, winners$group_id, runners$team_id, runners$group_id)) || any(!nzchar(c(as.character(winners$team_id), as.character(winners$group_id), as.character(runners$team_id), as.character(runners$group_id)))) || anyDuplicated(c(as.character(winners$team_id), as.character(runners$team_id)))) return(fallback())
    winners <- winners[order(as.character(winners$group_id), as.character(winners$team_id), method = "radix"), , drop = FALSE]
    runners <- runners[order(as.character(runners$group_id), as.character(runners$team_id), method = "radix"), , drop = FALSE]
    group_values <- c(as.character(winners$group_id), as.character(runners$group_id))
    key <- paste(paste0(nchar(group_values, type = "bytes"), ":", group_values), collapse = "|")
    if (!exists(key, envir = legal_draws, inherits = FALSE)) {
      legal <- list()
      walk <- function(index, used, chosen) {
        if (index > 4L) { legal[[length(legal) + 1L]] <<- chosen; return(invisible(NULL)) }
        for (candidate in which(!(1:4 %in% used) & as.character(runners$group_id) != as.character(winners$group_id[[index]]))) walk(index + 1L, c(used, candidate), c(chosen, candidate))
        invisible(NULL)
      }
      walk(1L, integer(), integer())
      assign(key, legal, envir = legal_draws)
    }
    legal <- get(key, envir = legal_draws, inherits = FALSE)
    if (!length(legal)) return(fallback())
    selected <- if (is.null(seed)) legal[[1L]] else uefa_nl_sim_with_seed(seed, function() legal[[sample.int(length(legal), 1L)]])
    pairs <- frame(list(tie_id = paste0("qf-", 1:4), pair_index = 1:4, legs = rep(2L, 4L),
      team_a = as.character(winners$team_id), team_b = as.character(runners$team_id[selected]),
      slot_a = paste0("A-group-winner-", as.character(winners$group_id)), slot_b = paste0("A-group-runner-up-", as.character(runners$group_id[selected])),
      group_a = as.character(winners$group_id), group_b = as.character(runners$group_id[selected])), 4L)
    ids <- uefa_nl_sim_projection_ids(projection_run_id, "nl-article17-qf-group-winner-different-group-runner-up-runner-up-home-v1", seed)
    slots <- uefa_nl_sim_stage_slots("league_a_quarter_final", "quarter_final", pairs, rules, ids$projection_run_id, ids$draw_policy_id)
    list(stage_slots = slots, slots = slots, pairings = pairs, draw_policy_id = ids$draw_policy_id, draw_policy_sha256 = ids$draw_policy_sha256, projection_run_id = ids$projection_run_id, official = FALSE)
  }
  runtime$uefa_nl_draw_semi_finals <- function(semi_finalists = NULL, host_association_id = NULL, association_map = NULL, seed = NULL, projection_run_id = NULL, rules = fixed_rules, quarter_final_winners = NULL) {
    fallback <- function() original_sf(semi_finalists, host_association_id, association_map, seed, projection_run_id, rules, quarter_final_winners)
    if (length(host_association_id) || !is.null(association_map) || !identical(rules, fixed_rules)) return(fallback())
    finalists <- uefa_nl_sim_team_rows(semi_finalists %||% quarter_final_winners, "League A semi-finalists")
    if (nrow(finalists) != 4L || anyNA(finalists$team_id) || anyDuplicated(as.character(finalists$team_id))) return(fallback())
    finalists <- finalists[order(as.character(finalists$team_id), method = "radix"), , drop = FALSE]
    ordering <- if (is.null(seed)) 1:4 else uefa_nl_sim_with_seed(seed, function() sample(1:4, 4L))
    finalists <- finalists[ordering, , drop = FALSE]
    pairs <- frame(list(tie_id = c("semi-final-1", "semi-final-2"), pair_index = 1:2, legs = rep(1L, 2L),
      team_a = as.character(finalists$team_id[c(1L, 3L)]), team_b = as.character(finalists$team_id[c(2L, 4L)]),
      slot_a = c("semi-finalist-1", "semi-finalist-3"), slot_b = c("semi-finalist-2", "semi-finalist-4"),
      group_a = rep(NA_character_, 2L), group_b = rep(NA_character_, 2L)), 2L)
    ids <- uefa_nl_sim_projection_ids(projection_run_id, "nl-article17-semi-seeded-open-draw-v1", seed)
    slots <- uefa_nl_sim_stage_slots("league_a_semi_final", "semi_final", pairs, rules, ids$projection_run_id, ids$draw_policy_id)
    # Only the private iteration consumes this helper: it constructs the final
    # and third-place slots itself after resolving the semi-finals.
    list(stage_slots = slots, slots = slots, semi_finals = pairs, pairings = pairs,
      draw_policy_id = ids$draw_policy_id, draw_policy_sha256 = ids$draw_policy_sha256, projection_run_id = ids$projection_run_id, official = FALSE)
  }
  runtime$uefa_nl_sim_iteration_paths <- function(groups, interim, transitions, qf_pairs, qf_resolutions, semi_pairs, semi_resolutions, final_resolution, third_resolution, iteration) {
    fallback <- function() original_paths(groups, interim, transitions, qf_pairs, qf_resolutions, semi_pairs, semi_resolutions, final_resolution, third_resolution, iteration)
    if (length(iteration) != 1L || !is.data.frame(groups) || !is.data.frame(interim) || !all(c("team_id", "league", "interim_rank", "ordering_status") %in% names(interim)) || !"team_id" %in% names(groups)) return(fallback())
    teams <- sort(as.character(groups$team_id), method = "radix"); n <- length(teams)
    if (!n || anyNA(teams) || anyDuplicated(teams) || anyDuplicated(interim$team_id)) return(fallback())
    positions <- match(teams, as.character(interim$team_id))
    if (anyNA(positions) || anyNA(interim$league[positions])) return(fallback())
    stage_valid <- function(pairs, resolutions) {
      if (!is.data.frame(pairs) || !nrow(pairs)) return(TRUE)
      if (!all(c("tie_id", "team_a", "team_b") %in% names(pairs)) || !is.character(pairs$tie_id) || anyNA(pairs$tie_id) || !is.character(pairs$team_a) || !is.character(pairs$team_b)) return(FALSE)
      if (!is.data.frame(resolutions) || !nrow(resolutions)) return(TRUE)
      all(c("tie_id", "stage_status", "winner_team_id", "loser_team_id") %in% names(resolutions)) && is.character(resolutions$tie_id) && !anyNA(resolutions$tie_id) && is.character(resolutions$winner_team_id) && is.character(resolutions$loser_team_id)
    }
    if (!stage_valid(qf_pairs, qf_resolutions) || !stage_valid(semi_pairs, semi_resolutions)) return(fallback())
    for (resolution in list(final_resolution, third_resolution)) if (is.data.frame(resolution) && nrow(resolution) == 1L && (!all(c("stage_status", "winner_team_id", "loser_team_id") %in% names(resolution)) || is.na(resolution$stage_status[[1L]]))) return(fallback())
    stage_paths <- function(pairs, resolutions) {
      if (!is.data.frame(pairs) || !nrow(pairs)) return(list(winner = rep(NA_real_, n), loser = rep(NA_real_, n)))
      winner <- loser <- numeric(n); bad <- logical(n)
      for (i in seq_len(nrow(pairs))) {
        participants <- unique(match(c(pairs$team_a[[i]], pairs$team_b[[i]]), teams)); participants <- participants[!is.na(participants)]
        if (!length(participants)) next
        result <- if (is.data.frame(resolutions) && nrow(resolutions)) which(resolutions$tie_id == pairs$tie_id[[i]]) else integer()
        if (length(result) != 1L || is.na(resolutions$stage_status[[result]]) || resolutions$stage_status[[result]] != "completed") { bad[participants] <- TRUE; next }
        w <- match(resolutions$winner_team_id[[result]], teams); l <- match(resolutions$loser_team_id[[result]], teams)
        if (!is.na(w) && w %in% participants) winner[[w]] <- 1
        if (!is.na(l) && l %in% participants) loser[[l]] <- 1
      }
      winner[bad] <- loser[bad] <- NA_real_
      list(winner = winner, loser = loser)
    }
    qf_path <- stage_paths(qf_pairs, qf_resolutions)
    sf_path <- stage_paths(semi_pairs, semi_resolutions)
    semi <- qf_path$winner
    champion <- finalist <- third_place <- numeric(n)
    if (is.data.frame(final_resolution) && nrow(final_resolution) == 1L && final_resolution$stage_status[[1L]] == "completed") {
      w <- match(as.character(final_resolution$winner_team_id[[1L]]), teams); l <- match(as.character(final_resolution$loser_team_id[[1L]]), teams)
      if (!is.na(w)) champion[[w]] <- 1
      finalist[unique(c(w, l))[!is.na(unique(c(w, l)))]] <- 1
    } else if ((is.data.frame(final_resolution) && nrow(final_resolution) == 1L) || any(semi == 1, na.rm = TRUE)) {
      finalist[which(semi == 1)] <- champion[which(semi == 1)] <- NA_real_
    }
    if (is.data.frame(third_resolution) && nrow(third_resolution) == 1L && third_resolution$stage_status[[1L]] == "completed") {
      i <- unique(match(as.character(c(third_resolution$winner_team_id[[1L]], third_resolution$loser_team_id[[1L]])), teams)); third_place[i[!is.na(i)]] <- 1
    } else if ((is.data.frame(third_resolution) && nrow(third_resolution) == 1L) || any(semi == 1, na.rm = TRUE)) third_place[which(semi == 1)] <- NA_real_
    direct_promotion <- direct_relegation <- numeric(n)
    promotion <- relegation <- eligibility <- playoff_win <- playoff_loss <- numeric(n)
    cancelled <- unresolved_cd <- logical(n)
    if (is.data.frame(transitions) && nrow(transitions)) {
      required <- c("team_id", "transition_type", "stage_id", "stage_status", "outcome_type", "cd_playoff_status", "eligibility_status", "higher_league_team_id", "lower_league_team_id")
      if (!all(required %in% names(transitions)) || anyNA(transitions$team_id) || anyNA(transitions$transition_type)) return(fallback())
      ti <- match(as.character(transitions$team_id), teams)
      flag <- function(mask) tabulate(ti[which(mask)], nbins = n) > 0L
      cancelled <- flag(as.character(transitions$cd_playoff_status) == "cancelled")
      unresolved_cd <- flag(as.character(transitions$eligibility_status) == "unresolved_external_eligibility")
      direct <- function(type) { selected <- as.character(transitions$transition_type) == type; result <- as.numeric(flag(selected)); result[flag(selected & as.character(transitions$stage_status) == "unresolved")] <- NA_real_; result }
      direct_promotion <- direct("direct_promotion"); direct_relegation <- direct("direct_relegation")
      playoff <- as.character(transitions$stage_id) %in% c("a_b_playoff", "b_c_playoff", "c_d_playoff")
      eligibility <- as.numeric(flag(playoff)); eligibility[cancelled | unresolved_cd] <- NA_real_
      unresolved <- flag(playoff & as.character(transitions$stage_status) == "unresolved")
      won <- flag(playoff & as.character(transitions$outcome_type) == "playoff_win")
      lost <- flag(playoff & as.character(transitions$outcome_type) == "playoff_loss")
      playoff_win[unresolved] <- playoff_loss[unresolved] <- NA_real_
      playoff_win[won] <- 1; playoff_loss[lost] <- 1
      move <- function(direct, endpoint, outcome) {
        result <- numeric(n)
        relevant <- playoff & (is.na(endpoint) | as.character(endpoint) == as.character(transitions$team_id))
        invalid <- relevant & (is.na(endpoint) | is.na(transitions$stage_status) | as.character(transitions$stage_status) != "completed")
        unknown <- flag(relevant & is.na(transitions$outcome_type))
        result[unknown] <- NA_real_
        result[flag(relevant & transitions$outcome_type == outcome)] <- 1
        result[flag(invalid)] <- NA_real_
        result[!is.na(direct) & direct == 1] <- 1
        result[is.na(direct)] <- NA_real_
        result
      }
      promotion <- move(direct_promotion, transitions$lower_league_team_id, "playoff_win")
      relegation <- move(direct_relegation, transitions$higher_league_team_id, "playoff_loss")
    }
    leagues <- as.character(interim$league[positions]); ranks <- as.integer(interim$interim_rank[positions])
    status <- rep("projected", n)
    status[unresolved_cd | as.character(interim$ordering_status[positions]) %in% c("unresolved", "blocked")] <- "unresolved"
    status[cancelled] <- "suppressed"
    frame(list(iteration = rep(as.integer(iteration), n), team_id = teams, league = leagues,
      p_quarter_final = as.numeric(!is.na(ranks) & leagues == "A" & ranks <= 8L), p_semi_final = semi, p_third_place = third_place,
      p_final = finalist, p_champion = champion, p_promotion = promotion, p_relegation = relegation,
      p_direct_promotion = direct_promotion, p_direct_relegation = direct_relegation, p_playoff_eligibility = eligibility,
      p_playoff_win = playoff_win, p_playoff_loss = playoff_loss, status = status, suppression_reason = ifelse(cancelled, "c_d_playoff_cancelled", "")), n)
  }
  runtime$uefa_nl_paths_prepared <- TRUE
  runtime
}
