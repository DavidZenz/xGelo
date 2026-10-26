# Prepared Article 15/19 arithmetic for the private simulation runtime.
# Public rule entry points retain their validation and recursive tie semantics.
uefa_nl_sim_prepare_numeric_groups <- function(runtime, matches, groups, rules, source, cutoff) {
  previous <- runtime$uefa_nl_sim_build_league_state
  if (isTRUE(attr(previous, "nl_numeric_prepared", exact = TRUE))) return(runtime)
  definitions <- environment(previous)$definitions
  if (!is.function(previous) || !length(definitions)) return(runtime)
  scope <- environment()
  parent.env(scope) <- runtime
  fixed_groups <- groups
  fixed_rules <- rules
  fixed_source <- source
  fixed_cutoff <- cutoff
  immutable_fields <- intersect(c("match_id", "fixture_id", "stage_id", "group_id", "home_team_id", "away_team_id"), names(matches))
  immutable <- matches[immutable_fields]
  row_count <- nrow(matches)
  league_indexes <- which(matches$stage_id == "league_phase")
  evidence_field <- intersect(c("evidence_completed_at_utc", "completed_at_utc"), names(matches))
  required <- c("final_home_goals", "final_away_goals", "match_status", "counts_for_standings")
  if (!all(required %in% names(matches)) || !length(evidence_field)) return(runtime)
  evidence_field <- evidence_field[[1L]]
  original_evidence <- as.character(matches[[evidence_field]])
  parsed_evidence <- uefa_nl_rank_parse_utc(original_evidence)
  parsed_cutoff <- uefa_nl_rank_parse_utc(cutoff)
  if (length(parsed_cutoff) != 1L || is.na(parsed_cutoff)) return(runtime)
  original_evidence_eligible <- !is.na(parsed_evidence) & parsed_evidence <= parsed_cutoff
  all_teams <- unlist(lapply(definitions, function(definition) as.character(definition$template$team_id)), use.names = FALSE)
  if (anyDuplicated(all_teams)) return(runtime)
  home_index <- match(as.character(matches$home_team_id), all_teams)
  away_index <- match(as.character(matches$away_team_id), all_teams)
  if (anyNA(home_index[league_indexes]) || anyNA(away_index[league_indexes])) return(runtime)
  rules_hash <- uefa_nl_ruleset_sha256(rules)
  prepared <- lapply(definitions, function(definition) {
    ids <- as.character(definition$template$team_id)
    rows <- matches[definition$indexes, , drop = FALSE]
    # Validate immutable identifiers and rule evidence once, using the public
    # parser. Dynamic score/status/evidence checks below fail back to it.
    canonical_ids <- if (nrow(rows)) uefa_nl_rank_match_id(rows) else character()
    discipline <- uefa_nl_rank_input_table(definition$discipline, ids, "discipline_points", "discipline points")
    access <- uefa_nl_rank_input_table(definition$access, ids, "access_list_position", "access list")
    global <- match(ids, all_teams)
    home <- match(as.character(rows$home_team_id), ids)
    away <- match(as.character(rows$away_team_id), ids)
    pairs <- lapply(seq_along(ids), function(team) lapply(seq_along(ids), function(opponent) {
      definition$indexes[which((home == team & away == opponent) | (away == team & home == opponent))]
    }))
    c(definition, list(team_ids = ids, global = global, home = home, away = away,
      canonical_ids = canonical_ids, discipline_values = discipline$values,
      access_values = access$values, static_missing = unique(c(discipline$missing, access$missing)), pairs = pairs))
  })
  if (any(vapply(prepared, function(definition) length(definition$static_missing) > 0L || anyNA(definition$home) || anyNA(definition$away), logical(1)))) return(runtime)
  metric_names <- c("played", "wins", "draws", "losses", "goals_for", "goals_against", "goal_difference", "points", "away_goals", "away_wins")
  metric_fields <- seq_len(8L)
  h2h_criteria <- c("head_to_head_points", "head_to_head_goal_difference", "head_to_head_goals")
  overall_criteria <- c("overall_goal_difference", "overall_goals", "overall_away_goals", "wins", "away_wins", "discipline_points", "access_list_position")
  individual_fields <- c("individual_points", "individual_goal_difference", "individual_goals", "individual_away_goals", "individual_wins", "individual_away_wins")
  individual_metrics <- c(8L, 7L, 5L, 9L, 2L, 10L)
  collapse_ids <- function(ids) paste(sort(unique(ids[!is.na(ids) & nzchar(ids)]), method = "radix"), collapse = ";")
  trace_row <- function(definition, criterion, ids, counted, decision, remaining = ids) {
    structure(list(ranking_scope = "group", league = uefa_nl_rank_table_scalar(definition$template$league[[1L]]),
      group_id = definition$id, criterion = criterion, tied_subset = collapse_ids(ids),
      counted_match_ids = collapse_ids(counted), decision = decision, recursion_depth = 0L,
      remaining_tied_subset = collapse_ids(remaining), ruleset_version = as.character(fixed_rules$ruleset_version),
      ruleset_sha256 = rules_hash), class = "data.frame", row.names = c(NA_integer_, -1L))
  }
  decision_text <- function(ids, values, decreasing = TRUE) {
    values <- as.numeric(values)
    unique_values <- sort(unique(values), decreasing = decreasing, method = "radix")
    parts <- lapply(unique_values, function(value) ids[values == value])
    list(parts = parts, text = paste(vapply(parts, function(part) paste(sort(part), collapse = "+"), character(1)), collapse = " > "))
  }
  # Pair metrics share the global contribution vectors and prepared integer
  # incidence sets. They serve both two-team H2H and Article 19 exclusions.
  pair_metrics <- function(definition, team, opponent, eligible, hg, ag) {
    indexes <- definition$pairs[[team]][[opponent]]
    indexes <- indexes[eligible[indexes]]
    home <- home_index[indexes] == definition$global[[team]]
    gf <- ifelse(home, hg[indexes], ag[indexes])
    ga <- ifelse(home, ag[indexes], hg[indexes])
    wins <- gf > ga
    as.integer(c(length(indexes), sum(wins), sum(gf == ga), sum(gf < ga), sum(gf), sum(ga), sum(gf) - sum(ga), 3L * sum(wins) + sum(gf == ga), sum(gf[!home]), sum(wins[!home])))
  }
  rank_fast <- function(snapshot, definition, totals, eligible, hg, ag) {
    ids <- as.character(snapshot$team_id)
    first <- decision_text(ids, snapshot$points)
    if (any(lengths(first$parts) > 2L)) return(NULL)
    all_counted <- definition$canonical_ids[eligible[definition$indexes]]
    traces <- list(trace_row(definition, "points", ids, all_counted, first$text))
    ordered <- character()
    for (part in first$parts) {
      if (length(part) == 1L) { ordered <- c(ordered, part); next }
      positions <- match(part, definition$team_ids)
      a <- pair_metrics(definition, positions[[1L]], positions[[2L]], eligible, hg, ag)
      b <- pair_metrics(definition, positions[[2L]], positions[[1L]], eligible, hg, ag)
      pair_indexes <- definition$pairs[[positions[[1L]]]][[positions[[2L]]]]
      pair_ids <- definition$canonical_ids[match(pair_indexes[eligible[pair_indexes]], definition$indexes)]
      resolved <- FALSE
      for (criterion_index in seq_along(h2h_criteria)) {
        metric <- c(8L, 7L, 5L)[[criterion_index]]
        result <- decision_text(part, c(a[[metric]], b[[metric]]))
        traces[[length(traces) + 1L]] <- trace_row(definition, h2h_criteria[[criterion_index]], part, pair_ids, result$text)
        if (length(result$parts) > 1L) { ordered <- c(ordered, unlist(result$parts, use.names = FALSE)); resolved <- TRUE; break }
      }
      if (resolved) next
      for (criterion in overall_criteria) {
        positions <- match(part, definition$team_ids)
        values <- switch(criterion,
          overall_goal_difference = totals[positions, 7L], overall_goals = totals[positions, 5L],
          overall_away_goals = totals[positions, 9L], wins = totals[positions, 2L],
          away_wins = totals[positions, 10L], discipline_points = definition$discipline_values[part],
          access_list_position = definition$access_values[part])
        result <- decision_text(part, values, criterion != "discipline_points")
        traces[[length(traces) + 1L]] <- trace_row(definition, criterion, part, all_counted, result$text)
        if (length(result$parts) > 1L) { ordered <- c(ordered, unlist(result$parts, use.names = FALSE)); resolved <- TRUE; break }
      }
      if (!resolved) ordered <- c(ordered, sort(part, method = "radix"))
    }
    output <- snapshot[match(ordered, snapshot$team_id), , drop = FALSE]
    output <- uefa_nl_rank_add_columns(output, fixed_rules, ranking_scope = "group")
    output$league <- uefa_nl_rank_table_scalar(definition$template$league[[1L]])
    output$league_id <- output$league
    output$group_id <- definition$id
    output$team_id <- ordered
    output$computed_rank <- as.integer(seq_along(ordered))
    output$group_position <- output$computed_rank
    output$discipline_points <- as.integer(definition$discipline_values[ordered])
    output$access_list_position <- as.integer(definition$access_values[ordered])
    output$counted_match_ids <- vapply(match(ordered, definition$team_ids), function(team) {
      collapse_ids(definition$canonical_ids[eligible[definition$indexes] & (definition$home == team | definition$away == team)])
    }, character(1), USE.NAMES = FALSE)
    output$excluded_match_ids <- ""
    output$ordering_status <- "ready"
    output$missing_rule_input <- ""
    output$block_status <- "not_blocked"
    output$blocked <- FALSE
    output$suppression_reason <- "none"
    output$ruleset_version <- fixed_rules$ruleset_version
    output$ruleset_sha256 <- rules_hash
    output <- uefa_nl_rank_finalize(output, fixed_rules)
    trace <- do.call(rbind, traces)
    row.names(trace) <- NULL
    attr(output, "tiebreak_trace") <- trace
    attr(output, "trace") <- trace
    output
  }
  runtime$uefa_nl_sim_build_league_state <- function(matches, groups, rules, source_bundle_id, cutoff_utc) {
    fallback <- function() previous(matches, groups, rules, source_bundle_id, cutoff_utc)
    if (!identical(groups, fixed_groups) || !identical(rules, fixed_rules) || !identical(source_bundle_id, fixed_source) || !identical(cutoff_utc, fixed_cutoff) || nrow(matches) != row_count) return(fallback())
    if (!all(c(immutable_fields, required, evidence_field) %in% names(matches))) return(fallback())
    if (!all(vapply(immutable_fields, function(field) identical(matches[[field]], immutable[[field]]), logical(1)))) return(fallback())
    counts <- matches$counts_for_standings
    if (!is.logical(counts) || anyNA(counts)) return(fallback())
    hg <- matches$final_home_goals
    ag <- matches$final_away_goals
    if (!is.numeric(hg) || !is.numeric(ag)) return(fallback())
    scores <- !is.na(hg) & !is.na(ag)
    if (any(scores & (!is.finite(hg) | !is.finite(ag) | hg < 0 | ag < 0 | hg != floor(hg) | ag != floor(ag)))) return(fallback())
    statuses <- matches$match_status
    if (any(!uefa_nl_rank_valid_status(statuses[league_indexes]))) return(fallback())
    completed <- uefa_nl_rank_completed_status(statuses)
    evidence <- as.character(matches[[evidence_field]])
    same <- (is.na(evidence) & is.na(original_evidence)) | (!is.na(evidence) & !is.na(original_evidence) & evidence == original_evidence)
    projected <- !is.na(evidence) & evidence == fixed_cutoff
    if (any(!(same | projected)[league_indexes])) return(fallback())
    good_evidence <- (same & original_evidence_eligible) | projected
    eligible <- counts & completed & scores & good_evidence
    # The old private snapshot uses counts; the Article 15 parser additionally
    # requires completed scores and timely evidence. Unsupported divergence
    # must retain that exact blocked-output path, rather than quietly drop it.
    if (any(counts[league_indexes] & !eligible[league_indexes])) return(fallback())
    totals <- matrix(0L, nrow = length(all_teams), ncol = length(metric_names), dimnames = list(NULL, metric_names))
    indexes <- league_indexes[eligible[league_indexes]]
    if (length(indexes)) {
      home_wins <- hg[indexes] > ag[indexes]
      away_wins <- hg[indexes] < ag[indexes]
      draws <- hg[indexes] == ag[indexes]
      n <- length(indexes)
      contribution <- cbind(rep.int(1L, 2L * n), c(home_wins, away_wins), rep(draws, 2L), c(away_wins, home_wins),
        c(hg[indexes], ag[indexes]), c(ag[indexes], hg[indexes]), c(hg[indexes] - ag[indexes], ag[indexes] - hg[indexes]),
        c(3L * home_wins + draws, 3L * away_wins + draws), c(integer(n), ag[indexes]), c(integer(n), away_wins))
      storage.mode(contribution) <- "integer"
      sums <- rowsum(contribution, c(home_index[indexes], away_index[indexes]), reorder = FALSE)
      totals[as.integer(row.names(sums)), ] <- sums
    }
    rankings <- vector("list", length(prepared))
    names(rankings) <- vapply(prepared, `[[`, character(1), "id")
    for (group_index in seq_along(prepared)) {
      definition <- prepared[[group_index]]
      snapshot <- definition$template
      group_totals <- totals[definition$global, , drop = FALSE]
      for (field in metric_fields) snapshot[[metric_names[[field]]]] <- as.integer(group_totals[, field])
      provisional <- order(-snapshot$points, -snapshot$goal_difference, -snapshot$goals_for, -snapshot$wins, snapshot$team_id)
      snapshot$computed_rank[provisional] <- seq_len(nrow(snapshot))
      snapshot <- snapshot[provisional, , drop = FALSE]
      snapshot$ordering_status <- "ruleset_adapter"
      snapshot$ruleset_adapter_id <- "uefa_nl_article15_v2"
      ranking <- rank_fast(snapshot, definition, group_totals, eligible, hg, ag)
      if (is.null(ranking)) ranking <- uefa_nl_rank_group(snapshot, matches[definition$indexes, , drop = FALSE], definition$discipline, definition$access, fixed_rules, definition$id)
      ranking$league <- as.character(definition$group$league[[1L]])
      ranking$league_id <- as.character(definition$group$league[[1L]])
      rankings[[group_index]] <- ranking
    }
    # Bind each group once. This deliberately retains the first group's trace
    # attributes, as the reference per-row rbind implementation does.
    individual <- uefa_nl_rank_bind_group_standings(rankings)
    individual$ranking_scope <- "individual_league"
    individual$individual_rank <- NA_integer_
    individual$interim_rank <- NA_integer_
    for (field in individual_fields) individual[[field]] <- integer(nrow(individual))
    individual$comparison_status <- "ready"
    for (group_index in seq_along(prepared)) {
      definition <- prepared[[group_index]]
      frame <- rankings[[group_index]]
      indexes <- which(individual$group_id == definition$id)
      local <- match(individual$team_id[indexes], definition$team_ids)
      measures <- totals[definition$global[local], individual_metrics, drop = FALSE]
      fourth <- which(frame$group_position == 4L)
      fourth_local <- if (length(fourth) == 1L) match(frame$team_id[[fourth]], definition$team_ids) else NA_integer_
      counted_ids <- excluded_ids <- character(length(local))
      for (team_index in seq_along(local)) {
        team <- local[[team_index]]
        team_match <- eligible[definition$indexes] & (definition$home == team | definition$away == team)
        excluded <- rep(FALSE, length(definition$indexes))
        if (!is.na(fourth_local) && individual$group_position[indexes[[team_index]]] %in% 1:3) {
          excluded <- team_match & (definition$home == fourth_local | definition$away == fourth_local)
          pair <- pair_metrics(definition, team, fourth_local, eligible, hg, ag)
          measures[team_index, ] <- measures[team_index, ] - pair[individual_metrics]
        }
        counted_ids[[team_index]] <- collapse_ids(definition$canonical_ids[team_match & !excluded])
        excluded_ids[[team_index]] <- collapse_ids(definition$canonical_ids[excluded])
      }
      for (field in seq_along(individual_fields)) individual[[individual_fields[[field]]]][indexes] <- as.integer(measures[, field])
      individual$counted_match_ids[indexes] <- counted_ids
      individual$excluded_match_ids[indexes] <- excluded_ids
    }
    individual$ordering_status <- "ready"
    individual$missing_rule_input <- ""
    individual$block_status <- "not_blocked"
    individual$blocked <- FALSE
    individual$suppression_reason <- "none"
    individual$ruleset_version <- fixed_rules$ruleset_version
    individual$ruleset_sha256 <- rules_hash
    individual$computed_rank <- NA_integer_
    for (league in sort(unique(individual$league), method = "radix")) {
      indexes <- which(individual$league == league)
      ordering <- order(individual$group_position[indexes], -individual$individual_points[indexes],
        -individual$individual_goal_difference[indexes], -individual$individual_goals[indexes],
        -individual$individual_away_goals[indexes], -individual$individual_wins[indexes],
        -individual$individual_away_wins[indexes], individual$discipline_points[indexes],
        -individual$access_list_position[indexes], individual$team_id[indexes], method = "radix")
      individual$individual_rank[indexes[ordering]] <- seq_along(indexes)
    }
    individual <- uefa_nl_rank_add_columns(individual, fixed_rules, ranking_scope = "individual_league")
    individual <- individual[order(individual$league, individual$individual_rank, individual$team_id, method = "radix"), , drop = FALSE]
    individual <- uefa_nl_rank_finalize(individual, fixed_rules)
    list(group_rankings = rankings, individual = individual, interim = uefa_nl_rank_interim_overall(individual, fixed_rules))
  }
  attr(runtime$uefa_nl_sim_build_league_state, "nl_numeric_prepared") <- TRUE
  runtime
}
