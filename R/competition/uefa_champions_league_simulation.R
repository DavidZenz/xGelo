# Deterministic UCL league sampling and editioned knockout mechanics.

.ucl_sim_scalar <- function(value) {
  if (inherits(value, "POSIXt")) return(format(value, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  if (!length(value) || is.na(value[[1L]])) return("")
  as.character(value[[1L]])
}

.ucl_sim_hash <- function(value) {
  if (!requireNamespace("digest", quietly = TRUE)) stop("UCL simulation requires digest", call. = FALSE)
  digest::digest(charToRaw(enc2utf8(paste(as.character(value), collapse = "\x1f"))), algo = "sha256", serialize = FALSE)
}

.ucl_sim_with_seed <- function(seed, callback) {
  if (length(seed) != 1L || is.na(seed) || !is.finite(as.numeric(seed))) stop("UCL simulation seed must be finite", call. = FALSE)
  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  old_seed <- if (had_seed) get(".Random.seed", envir = .GlobalEnv, inherits = FALSE) else NULL
  set.seed(as.integer(seed))
  on.exit({
    if (had_seed) assign(".Random.seed", old_seed, envir = .GlobalEnv)
    else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) rm(".Random.seed", envir = .GlobalEnv)
  }, add = TRUE)
  callback()
}

.ucl_sim_status_completed <- function(value) {
  tolower(trimws(as.character(value))) %in% c("completed", "complete", "finished", "full_time", "full-time", "after_extra_time", "after-extra-time", "after_penalties", "after-penalties", "awarded")
}

.ucl_sim_probability <- function(row) {
  fields <- intersect(c("prob_home", "prob_draw", "prob_away", "p_home", "p_draw", "p_away"), names(row))
  if (length(fields) == 6L) fields <- fields[1:3]
  if (length(fields) != 3L) return(c(NA_real_, NA_real_, NA_real_))
  p <- suppressWarnings(as.numeric(row[fields]))
  if (any(!is.finite(p)) || any(p < 0) || abs(sum(p) - 1) > 1e-8) return(c(NA_real_, NA_real_, NA_real_))
  p
}

.ucl_sim_sample_score <- function(row) {
  p <- .ucl_sim_probability(row)
  if (anyNA(p)) return(list(home = NA_integer_, away = NA_integer_, status = "suppressed", reason = "insufficient_model_evidence"))
  outcome <- sample(c("home", "draw", "away"), size = 1L, prob = p)
  if (outcome == "home") return(list(home = 1L, away = 0L, status = "sampled", reason = "none"))
  if (outcome == "away") return(list(home = 0L, away = 1L, status = "sampled", reason = "none"))
  list(home = 1L, away = 1L, status = "sampled", reason = "none")
}

.ucl_sim_iteration_graph <- function(graph, ledger) {
  output <- graph
  fixtures <- output$fixtures
  for (index in seq_len(nrow(fixtures))) {
    completed <- .ucl_sim_status_completed(fixtures$match_status[[index]])
    if (completed) next
    fixture_id <- as.character(fixtures$fixture_id[[index]])
    row <- ledger[as.character(ledger$fixture_id) == fixture_id, , drop = FALSE]
    if (nrow(row) != 1L || !as.character(row$forecast_status[[1L]]) %in% c("available", "eligible_fixture", "eligible_production")) next
    sampled <- .ucl_sim_sample_score(row)
    if (!identical(sampled$status, "sampled")) next
    fixtures$source_status[[index]] <- "completed"
    fixtures$match_status[[index]] <- "completed"
    fixtures$completion_method[[index]] <- "regulation"
    fixtures$regulation_home_goals[[index]] <- sampled$home
    fixtures$regulation_away_goals[[index]] <- sampled$away
    fixtures$final_home_goals[[index]] <- sampled$home
    fixtures$final_away_goals[[index]] <- sampled$away
    fixtures$counts_for_standings[[index]] <- TRUE
    fixtures$winner_club_id[[index]] <- if (sampled$home > sampled$away) fixtures$home_club_id[[index]] else if (sampled$away > sampled$home) fixtures$away_club_id[[index]] else NA_character_
  }
  output$fixtures <- fixtures
  output
}

.ucl_sim_rank_rows <- function(ranking, iteration, run_id) {
  if (!is.data.frame(ranking) || !nrow(ranking)) return(data.frame())
  data.frame(
    run_id = run_id, iteration = as.integer(iteration), edition_id = as.character(ranking$edition_id),
    club_id = as.character(ranking$club_id), rank = as.integer(ranking$rank),
    rank_interval_min = as.integer(ranking$rank_interval_min), rank_interval_max = as.integer(ranking$rank_interval_max),
    rank_status = as.character(ranking$rank_status), qualification_band = as.character(ranking$qualification_band),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

#' Run a seeded conditional league-phase simulation.
ucl_run_simulation <- function(state, ledger = NULL, simulations = 1L, seed = 20260921L,
                               rules = NULL, draw_artifact = NULL, source_bundle_id = NULL,
                               information_cutoff_utc = NULL) {
  graph <- if (is.list(state) && !is.data.frame(state) && !is.null(state$graph)) state$graph else state
  validation <- ucl_validate_schedule(graph, rules = rules)
  if (!identical(validation$status, "ready")) return(list(status = "blocked", reason = validation$reason_code, simulations = data.frame(), metadata = list()))
  ledger <- if (is.list(ledger) && is.data.frame(ledger$ledger)) ledger$ledger else ledger
  if (is.null(ledger)) {
    ledger <- data.frame(fixture_id = validation$graph$fixtures$fixture_id, forecast_status = "suppressed", stringsAsFactors = FALSE)
  }
  simulations <- as.integer(simulations)
  if (length(simulations) != 1L || is.na(simulations) || simulations < 1L || simulations > 100000L) stop("UCL simulation count must be between 1 and 100000", call. = FALSE)
  rules <- rules %||% if (exists(".ucl_rule_contract", mode = "function")) .ucl_rule_contract() else NULL
  source_bundle_id <- source_bundle_id %||% validation$graph$source_bundle_id
  run_id <- .ucl_sim_hash(c(validation$graph$graph_sha256, if (is.null(rules)) "" else rules$ruleset_sha256, source_bundle_id, seed, simulations, information_cutoff_utc %||% ""))
  rows <- .ucl_sim_with_seed(seed, function() {
    output <- lapply(seq_len(simulations), function(iteration) {
      graph_i <- .ucl_sim_iteration_graph(validation$graph, ledger)
      built <- if (exists("ucl_build_state", mode = "function")) ucl_build_state(graph_i, rules = rules, state_cutoff_utc = "2099-12-31T23:59:59Z") else NULL
      if (is.null(built) || !identical(built$status, "ready")) return(data.frame())
      .ucl_sim_rank_rows(built$standings, iteration, run_id)
    })
    do.call(rbind, output)
  })
  row.names(rows) <- NULL
  path_state <- ucl_enumerate_legal_knockout_paths(
    if (nrow(rows)) rows[rows$iteration == max(rows$iteration), , drop = FALSE] else data.frame(),
    draw_artifact = draw_artifact, rules = rules, source_bundle_id = source_bundle_id
  )
  metadata <- list(
    run_id = run_id, edition_id = validation$graph$edition_id, source_bundle_id = source_bundle_id,
    ruleset_version = if (is.null(rules)) NA_character_ else rules$ruleset_version,
    ruleset_sha256 = if (is.null(rules)) NA_character_ else rules$ruleset_sha256,
    draw_policy_id = if (is.null(rules)) "ucl-2026-27-article19-annexb-v1" else rules$draw_policy_id,
    draw_artifact_id = if (is.null(draw_artifact)) NA_character_ else as.character(draw_artifact$draw_artifact_id %||% NA_character_),
    draw_artifact_sha256 = if (is.null(draw_artifact)) NA_character_ else as.character(draw_artifact$draw_artifact_sha256 %||% NA_character_),
    information_cutoff_utc = information_cutoff_utc %||% NA_character_, algorithm_version = "ucl-conditional-league-v1",
    simulation_count = simulations, seed = as.integer(seed), path_policy_id = "ucl-rank-constrained-pre-draw-v1",
    path_policy_count = if (is.data.frame(path_state)) nrow(path_state) else 0L,
    authority_mode = as.character(validation$graph$authority_mode), production_eligible = FALSE,
    status = if (is.data.frame(path_state) && nrow(path_state) && any(path_state$path_status == "unresolved")) "unresolved_draw_procedure" else "ready"
  )
  structure(list(status = metadata$status, run_id = run_id, rank_rows = rows, simulations = rows,
                 knockout_paths = path_state, metadata = metadata, graph = validation$graph,
                 ledger = ledger, fixture_authority = isTRUE(validation$graph$fixture_authority), production_eligible = FALSE),
            class = c("ucl_simulation_run", "list"))
}

#' Aggregate rank, band, and cut-line probabilities from simulation rows.
ucl_aggregate_rank_distributions <- function(simulation, rules = NULL) {
  rows <- if (is.list(simulation) && is.data.frame(simulation$rank_rows)) simulation$rank_rows else simulation
  if (!is.data.frame(rows) || !nrow(rows)) return(list(status = "unresolved", rank_distribution = data.frame(), band_probabilities = data.frame(), cutline = data.frame()))
  total <- length(unique(rows$iteration)); clubs <- sort(unique(as.character(rows$club_id)), method = "radix")
  rank_distribution <- do.call(rbind, lapply(clubs, function(club) {
    values <- rows[as.character(rows$club_id) == club, , drop = FALSE]
    ranks <- sort(unique(as.integer(values$rank)), method = "radix", na.last = TRUE)
    out <- data.frame(club_id = club, rank = ranks, probability = vapply(ranks, function(rank) if (is.na(rank)) mean(is.na(values$rank)) else mean(values$rank == rank, na.rm = TRUE), numeric(1)), stringsAsFactors = FALSE, check.names = FALSE)
    out
  }))
  band_levels <- c("direct_round_of_16", "knockout_play_off", "eliminated")
  band_probabilities <- do.call(rbind, lapply(clubs, function(club) {
    values <- rows[as.character(rows$club_id) == club, , drop = FALSE]
    data.frame(club_id = club, qualification_band = band_levels, probability = vapply(band_levels, function(band) mean(as.character(values$qualification_band) == band), numeric(1)), status = ifelse(any(as.character(values$rank_status) == "unresolved"), "unresolved", "resolved"), stringsAsFactors = FALSE, check.names = FALSE)
  }))
  cutline <- do.call(rbind, lapply(c(8L, 24L), function(boundary) {
    data.frame(cutline = boundary, rank = sort(unique(as.integer(rows$rank))), probability = vapply(sort(unique(as.integer(rows$rank))), function(rank) mean(rows$rank == rank), numeric(1)), stringsAsFactors = FALSE, check.names = FALSE)
  }))
  list(status = if (any(is.na(rows$rank))) "unresolved" else "ready", rank_distribution = rank_distribution,
       band_probabilities = band_probabilities, cutline = cutline, simulation_count = total,
       run_id = if (is.list(simulation)) simulation$run_id %||% NA_character_ else NA_character_)
}

.ucl_sim_rank_value <- function(rankings, club_id) {
  row <- rankings[as.character(rankings$club_id) == as.character(club_id), , drop = FALSE]
  if (nrow(row) != 1L) return(NA_integer_)
  if (!is.na(row$rank[[1L]])) return(as.integer(row$rank[[1L]]))
  lo <- as.integer(row$rank_interval_min[[1L]]); hi <- as.integer(row$rank_interval_max[[1L]])
  if (is.na(lo) || is.na(hi) || lo != hi) return(NA_integer_)
  lo
}

#' Enumerate only rank-compatible play-off and round-of-16 path families.
ucl_enumerate_legal_knockout_paths <- function(rankings, draw_artifact = NULL, rules = NULL, seed = NULL, source_bundle_id = NULL) {
  rules <- rules %||% if (exists(".ucl_rule_contract", mode = "function")) .ucl_rule_contract() else list(edition_id = "ucl_2026_27", ruleset_sha256 = NA_character_, draw_policy_id = "ucl-2026-27-article19-annexb-v1")
  draw <- ucl_validate_draw_artifact(draw_artifact, rules = rules, source_bundle_id = source_bundle_id)
  if (identical(draw$status, "accepted")) {
    pairs <- draw$pairings
    if (!is.data.frame(pairs) || !nrow(pairs)) return(data.frame(path_id = character(), path_status = character(), unresolved_reason = character(), stringsAsFactors = FALSE))
    output <- pairs
    output$edition_id <- rules$edition_id; output$draw_policy_id <- rules$draw_policy_id; output$draw_artifact_id <- draw$draw_artifact_id; output$draw_artifact_sha256 <- draw$draw_artifact_sha256; output$path_status <- "accepted_draw"; output$unresolved_reason <- NA_character_; output$source_bundle_id <- source_bundle_id %||% NA_character_; output$ruleset_sha256 <- rules$ruleset_sha256
    return(output)
  }
  if (!is.data.frame(rankings) || !nrow(rankings)) {
    return(data.frame(edition_id = rules$edition_id, path_id = "pre-draw-unresolved", stage_id = "knockout_play_off", participant_a = NA_character_, participant_b = NA_character_, leg_order = NA_character_, draw_policy_id = rules$draw_policy_id, draw_artifact_id = NA_character_, draw_artifact_sha256 = NA_character_, path_status = "unresolved", unresolved_reason = draw$reason %||% "unresolved_rank_interval", source_bundle_id = source_bundle_id %||% NA_character_, ruleset_sha256 = rules$ruleset_sha256, stringsAsFactors = FALSE, check.names = FALSE))
  }
  rows <- list(); index <- 0L
  add_family <- function(seed_range, opponent_range, stage_id) {
    for (a in seed_range) for (b in opponent_range) {
      if (a > b) next
      if (is.na(a) || is.na(b)) next
      index <<- index + 1L
      rows[[index]] <<- data.frame(edition_id = rules$edition_id, path_id = paste0(stage_id, "-", index), stage_id = stage_id, participant_a = as.character(a), participant_b = as.character(b), leg_order = "seeded_return_leg", draw_policy_id = rules$draw_policy_id, draw_artifact_id = NA_character_, draw_artifact_sha256 = NA_character_, path_status = "pre_draw_legal", unresolved_reason = "missing_edition_draw_procedure", source_bundle_id = source_bundle_id %||% NA_character_, ruleset_sha256 = rules$ruleset_sha256, stringsAsFactors = FALSE, check.names = FALSE)
    }
  }
  rank_values <- vapply(seq_len(nrow(rankings)), function(i) .ucl_sim_rank_value(rankings, rankings$club_id[[i]]), integer(1))
  unresolved <- any(is.na(rank_values))
  if (unresolved) return(data.frame(edition_id = rules$edition_id, path_id = "pre-draw-unresolved", stage_id = "knockout_play_off", participant_a = NA_character_, participant_b = NA_character_, leg_order = NA_character_, draw_policy_id = rules$draw_policy_id, draw_artifact_id = NA_character_, draw_artifact_sha256 = NA_character_, path_status = "unresolved", unresolved_reason = "unresolved_rank_interval", source_bundle_id = source_bundle_id %||% NA_character_, ruleset_sha256 = rules$ruleset_sha256, stringsAsFactors = FALSE, check.names = FALSE))
  add_family(9:10, 23:24, "knockout_play_off"); add_family(11:12, 21:22, "knockout_play_off"); add_family(13:14, 19:20, "knockout_play_off"); add_family(15:16, 17:18, "knockout_play_off")
  if (!length(rows)) return(data.frame())
  do.call(rbind, rows)
}

#' Validate a same-edition accepted draw or return a typed unresolved state.
ucl_validate_draw_artifact <- function(draw_artifact = NULL, rules = NULL, source_bundle_id = NULL) {
  rules <- rules %||% if (exists(".ucl_rule_contract", mode = "function")) .ucl_rule_contract() else list(edition_id = "ucl_2026_27")
  if (is.null(draw_artifact)) return(list(status = "unresolved", reason = "missing_edition_draw_procedure", draw_artifact_id = NA_character_, draw_artifact_sha256 = NA_character_))
  if (is.list(draw_artifact) && identical(as.character(draw_artifact$status %||% ""), "unresolved") && !is.null(draw_artifact$reason)) {
    return(list(status = "unresolved", reason = as.character(draw_artifact$reason), draw_artifact_id = NA_character_, draw_artifact_sha256 = NA_character_))
  }
  artifact <- if (is.list(draw_artifact) && is.data.frame(draw_artifact$pairings)) draw_artifact else list(pairings = as.data.frame(draw_artifact, stringsAsFactors = FALSE, check.names = FALSE))
  pairings <- artifact$pairings
  required <- c("participant_a", "participant_b")
  if (!all(required %in% names(pairings))) return(list(status = "unresolved", reason = "partial_draw_artifact"))
  if (!is.null(artifact$edition_id) && !identical(as.character(artifact$edition_id), as.character(rules$edition_id))) return(list(status = "unresolved", reason = "foreign_lineage"))
  if (!is.null(artifact$source_bundle_id) && !is.null(source_bundle_id) && !identical(as.character(artifact$source_bundle_id), as.character(source_bundle_id))) return(list(status = "unresolved", reason = "foreign_lineage"))
  if (!isTRUE(artifact$accepted) || !isTRUE(artifact$complete)) return(list(status = "unresolved", reason = "missing_edition_draw_procedure"))
  draw_id <- as.character(artifact$draw_artifact_id %||% artifact$artifact_id %||% "")
  if (!nzchar(draw_id)) return(list(status = "unresolved", reason = "partial_draw_artifact"))
  hash <- as.character(artifact$draw_artifact_sha256 %||% artifact$artifact_sha256 %||% .ucl_sim_hash(pairings))
  if (!grepl("^[0-9a-f]{64}$", hash)) return(list(status = "unresolved", reason = "stale_draw_artifact"))
  list(status = "accepted", reason = NA_character_, draw_artifact_id = draw_id, draw_artifact_sha256 = hash, pairings = pairings, edition_id = rules$edition_id)
}

.ucl_sim_score <- function(row, names) {
  field <- names[names %in% names(row)][1L]
  if (is.na(field) || is.null(field)) return(NA_real_)
  suppressWarnings(as.numeric(row[[field]][[1L]]))
}

#' Resolve a two-leg tie by aggregate goals, then second-leg ET and penalties.
ucl_resolve_two_leg_tie <- function(first_leg, second_leg, rules = NULL, penalty_winner = NULL) {
  first <- as.data.frame(first_leg, stringsAsFactors = FALSE, check.names = FALSE)
  second <- as.data.frame(second_leg, stringsAsFactors = FALSE, check.names = FALSE)
  if (nrow(first) != 1L || nrow(second) != 1L) stop("UCL two-leg resolver requires one row per leg", call. = FALSE)
  rules <- rules %||% if (exists(".ucl_rule_contract", mode = "function")) .ucl_rule_contract() else list(two_leg_policy = "aggregate_regulation_then_second_leg_extra_time_then_penalties_no_away_goals")
  fh <- .ucl_sim_score(first, c("final_home_goals", "regulation_home_goals", "home_goals")); fa <- .ucl_sim_score(first, c("final_away_goals", "regulation_away_goals", "away_goals"))
  sh <- .ucl_sim_score(second, c("final_home_goals", "regulation_home_goals", "home_goals")); sa <- .ucl_sim_score(second, c("final_away_goals", "regulation_away_goals", "away_goals"))
  participants <- unique(c(as.character(first$home_club_id %||% first$home_team_id %||% first$home_team), as.character(first$away_club_id %||% first$away_team_id %||% first$away_team)))
  if (length(participants) != 2L || anyNA(c(fh, fa, sh, sa))) return(list(status = "unresolved", reason = "score_evidence_missing", winner = NA_character_))
  aggregate_home <- fh + sa; aggregate_away <- fa + sh
  winner <- if (aggregate_home > aggregate_away) participants[[1L]] else if (aggregate_away > aggregate_home) participants[[2L]] else NA_character_
  et_applied <- FALSE; penalty_applied <- FALSE
  et_home <- .ucl_sim_score(second, c("extra_time_home_goals", "et_home_goals")); et_away <- .ucl_sim_score(second, c("extra_time_away_goals", "et_away_goals"))
  pen_home <- .ucl_sim_score(second, c("penalty_home", "penalties_home", "shootout_home_goals")); pen_away <- .ucl_sim_score(second, c("penalty_away", "penalties_away", "shootout_away_goals"))
  if (is.na(winner) && is.finite(et_home) && is.finite(et_away)) {
    et_applied <- TRUE
    if (et_home > et_away) winner <- as.character(second$home_club_id %||% second$home_team_id %||% second$home_team) else if (et_away > et_home) winner <- as.character(second$away_club_id %||% second$away_team_id %||% second$away_team)
  }
  if (is.na(winner) && is.finite(pen_home) && is.finite(pen_away)) {
    penalty_applied <- TRUE
    if (pen_home > pen_away) winner <- as.character(second$home_club_id %||% second$home_team_id %||% second$home_team) else if (pen_away > pen_home) winner <- as.character(second$away_club_id %||% second$away_team_id %||% second$away_team)
  }
  if (is.na(winner) && !is.null(penalty_winner) && length(penalty_winner) == 1L && as.character(penalty_winner) %in% participants) { penalty_applied <- TRUE; winner <- as.character(penalty_winner) }
  list(status = if (is.na(winner)) "unresolved" else "resolved", reason = if (is.na(winner)) "penalty_evidence_missing" else NA_character_, winner = winner, participant_a = participants[[1L]], participant_b = participants[[2L]], aggregate_regulation_home = aggregate_home, aggregate_regulation_away = aggregate_away, extra_time_applied = et_applied, extra_time_home = et_home, extra_time_away = et_away, penalty_applied = penalty_applied, penalty_home = pen_home, penalty_away = pen_away, away_goals_used = FALSE, second_leg_venue_id = as.character(second$venue_id %||% second$venue %||% NA_character_), ruleset_sha256 = rules$ruleset_sha256 %||% NA_character_)
}

#' Resolve the neutral, single-match UCL final.
ucl_resolve_final <- function(match, rules = NULL, penalty_winner = NULL) {
  row <- as.data.frame(match, stringsAsFactors = FALSE, check.names = FALSE)
  if (nrow(row) != 1L) stop("UCL final resolver requires one match row", call. = FALSE)
  rules <- rules %||% if (exists(".ucl_rule_contract", mode = "function")) .ucl_rule_contract() else list(final_policy = "single_neutral_match_extra_time_then_penalties")
  home <- as.character(row$home_club_id %||% row$home_team_id %||% row$home_team)
  away <- as.character(row$away_club_id %||% row$away_team_id %||% row$away_team)
  if (!isTRUE(row$neutral[[1L]] %||% TRUE)) return(list(status = "blocked", reason = "final_not_neutral"))
  hg <- .ucl_sim_score(row, c("final_home_goals", "regulation_home_goals", "home_goals")); ag <- .ucl_sim_score(row, c("final_away_goals", "regulation_away_goals", "away_goals"))
  if (anyNA(c(hg, ag))) return(list(status = "unresolved", reason = "score_evidence_missing", winner = NA_character_))
  winner <- if (hg > ag) home else if (ag > hg) away else NA_character_
  et_home <- .ucl_sim_score(row, c("extra_time_home_goals", "et_home_goals")); et_away <- .ucl_sim_score(row, c("extra_time_away_goals", "et_away_goals")); penalty_home <- .ucl_sim_score(row, c("penalty_home", "penalties_home", "shootout_home_goals")); penalty_away <- .ucl_sim_score(row, c("penalty_away", "penalties_away", "shootout_away_goals"))
  et <- FALSE; penalties <- FALSE
  if (is.na(winner) && is.finite(et_home) && is.finite(et_away)) { et <- TRUE; winner <- if (et_home > et_away) home else if (et_away > et_home) away else NA_character_ }
  if (is.na(winner) && is.finite(penalty_home) && is.finite(penalty_away)) { penalties <- TRUE; winner <- if (penalty_home > penalty_away) home else if (penalty_away > penalty_home) away else NA_character_ }
  if (is.na(winner) && !is.null(penalty_winner) && as.character(penalty_winner) %in% c(home, away)) { penalties <- TRUE; winner <- as.character(penalty_winner) }
  list(status = if (is.na(winner)) "unresolved" else "resolved", reason = if (is.na(winner)) "penalty_evidence_missing" else NA_character_, winner = winner, neutral = TRUE, home_club_id = home, away_club_id = away, extra_time_applied = et, penalty_applied = penalties, penalty_home = penalty_home, penalty_away = penalty_away, ruleset_sha256 = rules$ruleset_sha256 %||% NA_character_)
}

#' Aggregate stage input/output event counts without repairing unresolved rows.
ucl_aggregate_stage_events <- function(events, rules = NULL) {
  if (is.null(events)) return(data.frame(stage_id = character(), input_count = integer(), resolved_count = integer(), unresolved_count = integer(), suppressed_count = integer(), output_count = integer(), stringsAsFactors = FALSE, check.names = FALSE))
  events <- as.data.frame(events, stringsAsFactors = FALSE, check.names = FALSE)
  if (!"stage_id" %in% names(events)) stop("UCL stage events require stage_id", call. = FALSE)
  status <- if ("status" %in% names(events)) as.character(events$status) else if ("path_status" %in% names(events)) as.character(events$path_status) else rep("resolved", nrow(events))
  ids <- sort(unique(as.character(events$stage_id)), method = "radix")
  out <- do.call(rbind, lapply(ids, function(stage) {
    values <- status[as.character(events$stage_id) == stage]
    data.frame(stage_id = stage, input_count = length(values), resolved_count = sum(values %in% c("resolved", "completed", "accepted_draw", "pre_draw_legal")), unresolved_count = sum(values %in% c("unresolved", "blocked")), suppressed_count = sum(values %in% c("suppressed")), output_count = sum(values %in% c("resolved", "completed", "accepted_draw", "pre_draw_legal")), stringsAsFactors = FALSE, check.names = FALSE)
  }))
  row.names(out) <- NULL
  out
}

#' Validate probability conservation and monotone progression.
ucl_validate_progression_reconciliation <- function(progression, tolerance = 1e-10) {
  if (!is.data.frame(progression) || !nrow(progression)) return(list(status = "unresolved", valid = FALSE, errors = "progression_empty"))
  required <- c("club_id", "stage_id", "probability")
  if (!all(required %in% names(progression))) return(list(status = "blocked", valid = FALSE, errors = "progression_schema_incomplete"))
  errors <- character()
  p <- suppressWarnings(as.numeric(progression$probability))
  finite <- !is.na(p)
  if (any(!is.finite(p[finite]) | p[finite] < -tolerance | p[finite] > 1 + tolerance)) errors <- c(errors, "probability_bounds")
  for (club in unique(as.character(progression$club_id))) {
    rows <- progression[as.character(progression$club_id) == club, , drop = FALSE]
    if ("status" %in% names(rows) && any(as.character(rows$status) == "resolved")) {
      resolved <- rows[as.character(rows$status) == "resolved", , drop = FALSE]
      if ("qualification_band" %in% names(resolved)) {
        total <- sum(as.numeric(resolved$probability), na.rm = TRUE)
        if (abs(total - 1) > tolerance) errors <- c(errors, paste0("band_sum:", club))
      }
    }
    if (all(c("stage_order", "probability") %in% names(rows))) {
      ordered <- rows[order(as.numeric(rows$stage_order)), , drop = FALSE]
      if (any(diff(as.numeric(ordered$probability)) > tolerance, na.rm = TRUE)) errors <- c(errors, paste0("non_monotone:", club))
    }
  }
  list(status = if (length(errors)) "invalid" else "ready", valid = !length(errors), errors = unique(errors))
}
