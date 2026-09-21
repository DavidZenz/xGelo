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

.ucl_sim_seed_for <- function(seed, ...) {
  digest <- .ucl_sim_hash(c(seed, ...))
  value <- suppressWarnings(strtoi(substr(digest, 1L, 7L), base = 16L))
  if (is.na(value)) value <- 1L
  as.integer((as.numeric(value) %% (.Machine$integer.max - 1)) + 1)
}

.ucl_sim_status_completed <- function(value) {
  tolower(trimws(as.character(value))) %in% c(
    "completed", "complete", "finished", "full_time", "full-time",
    "after_extra_time", "after-extra-time", "after_penalties", "after-penalties", "awarded"
  )
}

.ucl_sim_status_fixed <- function(value) {
  status <- tolower(trimws(as.character(value)))
  .ucl_sim_status_completed(status) || status %in% c("postponed", "cancelled", "canceled", "abandoned")
}

.ucl_sim_open_status <- function(value) {
  status <- tolower(trimws(as.character(value)))
  is.na(status) || !nzchar(status) || status %in% c("scheduled", "not_started", "not-started", "upcoming", "fixture", "open")
}

.ucl_sim_before <- function(left, right) {
  if (is.null(left) || is.null(right) || !length(left) || !length(right) || is.na(left[[1L]]) || is.na(right[[1L]])) return(FALSE)
  as.character(left[[1L]]) < as.character(right[[1L]])
}

.ucl_sim_probability <- function(row) {
  fields <- intersect(c("prob_home", "prob_draw", "prob_away", "p_home", "p_draw", "p_away"), names(row))
  if (length(fields) == 6L) fields <- fields[1:3]
  if (length(fields) != 3L) return(c(NA_real_, NA_real_, NA_real_))
  p <- suppressWarnings(as.numeric(row[fields]))
  if (any(!is.finite(p)) || any(p < 0) || abs(sum(p) - 1) > 1e-8) return(c(NA_real_, NA_real_, NA_real_))
  p
}

.ucl_sim_score_grid <- function(row) {
  grid <- NULL
  for (field in c("score_grid", "score_distribution", "score_grid_json")) {
    if (!field %in% names(row)) next
    candidate <- row[[field]][[1L]]
    if (is.character(candidate) && length(candidate) == 1L && nzchar(candidate) && requireNamespace("jsonlite", quietly = TRUE)) {
      candidate <- tryCatch(jsonlite::fromJSON(candidate), error = function(error) NULL)
    }
    if (!is.null(candidate)) {
      grid <- candidate
      break
    }
  }
  if (is.null(grid)) return(NULL)
  if (is.list(grid) && !is.data.frame(grid) && !is.null(grid$home_goals)) grid <- as.data.frame(grid, stringsAsFactors = FALSE, check.names = FALSE)
  if (!is.data.frame(grid) || !all(c("home_goals", "away_goals", "probability") %in% names(grid)) || !nrow(grid)) return(NULL)
  home <- suppressWarnings(as.numeric(grid$home_goals)); away <- suppressWarnings(as.numeric(grid$away_goals)); probability <- suppressWarnings(as.numeric(grid$probability))
  if (any(!is.finite(c(home, away, probability))) || any(home < 0 | away < 0) || any(home != floor(home) | away != floor(away)) || any(probability < 0) || abs(sum(probability) - 1) > 1e-8 || anyDuplicated(paste(home, away, sep = ":"))) return(NULL)
  grid <- data.frame(home_goals = as.integer(home), away_goals = as.integer(away), probability = probability, stringsAsFactors = FALSE, check.names = FALSE)
  grid[order(grid$home_goals, grid$away_goals, method = "radix"), , drop = FALSE]
}

.ucl_sim_sample_score <- function(row) {
  grid <- .ucl_sim_score_grid(row)
  if (is.null(grid)) return(list(home = NA_integer_, away = NA_integer_, status = "suppressed", reason = "insufficient_model_evidence"))
  index <- sample.int(nrow(grid), size = 1L, prob = grid$probability)
  list(home = grid$home_goals[[index]], away = grid$away_goals[[index]], status = "sampled", reason = "none")
}

# Normalize lifecycle rows before sampling. Settled rows and postponed rows are
# immutable; only open rows with a valid score grid can be sampled.
.ucl_prepare_iteration_matches <- function(fixtures, cutoff_utc = NULL) {
  fixtures <- as.data.frame(fixtures, stringsAsFactors = FALSE, check.names = FALSE)
  if (!"fixture_id" %in% names(fixtures)) stop("UCL iteration matches require fixture_id", call. = FALSE)
  status <- if ("match_status" %in% names(fixtures)) as.character(fixtures$match_status) else rep("scheduled", nrow(fixtures))
  fixed <- vapply(status, .ucl_sim_status_fixed, logical(1))
  open <- !fixed & vapply(status, .ucl_sim_open_status, logical(1))
  fixture_ids <- as.character(fixtures$fixture_id)
  if (anyDuplicated(fixture_ids)) stop("UCL iteration matches require unique fixture ids", call. = FALSE)
  list(
    matches = fixtures,
    fixed_fixture_ids = sort(fixture_ids[fixed], method = "radix"),
    open_fixture_ids = sort(fixture_ids[open], method = "radix"),
    eligible_open_fixture_ids = sort(fixture_ids[open], method = "radix"),
    suppressed_fixture_ids = character(),
    cutoff_utc = cutoff_utc %||% NA_character_
  )
}

.ucl_sample_open_fixtures <- function(prepared, ledger, seed = 20260921L, cutoff_utc = NULL) {
  if (is.data.frame(prepared)) prepared <- .ucl_prepare_iteration_matches(prepared, cutoff_utc = cutoff_utc)
  if (!is.list(prepared) || !is.data.frame(prepared$matches)) stop("UCL prepared iteration matches are invalid", call. = FALSE)
  table <- if (is.list(ledger) && is.data.frame(ledger$ledger)) ledger$ledger else as.data.frame(ledger, stringsAsFactors = FALSE, check.names = FALSE)
  if (!"fixture_id" %in% names(table)) stop("UCL forecast ledger requires fixture_id", call. = FALSE)
  fixtures <- prepared$matches
  sampled <- character(); suppressed <- character(); records <- list(); record_index <- 0L
  ids <- sort(as.character(fixtures$fixture_id), method = "radix")
  for (fixture_id in ids) {
    index <- match(fixture_id, as.character(fixtures$fixture_id))
    if (!fixture_id %in% prepared$open_fixture_ids) next
    row <- table[as.character(table$fixture_id) == fixture_id, , drop = FALSE]
    reason <- NULL
    if (nrow(row) != 1L) reason <- "forecast_row_missing"
    if (is.null(reason) && (!"forecast_status" %in% names(row) || !as.character(row$forecast_status[[1L]]) %in% c("available", "eligible_fixture", "eligible_production"))) reason <- as.character(row$suppression_reason[[1L]] %||% "forecast_suppressed")
    kickoff <- if ("kickoff_utc" %in% names(fixtures)) fixtures$kickoff_utc[[index]] else NA_character_
    feature_cutoff <- if (nrow(row) && "feature_cutoff_utc" %in% names(row)) row$feature_cutoff_utc[[1L]] else NA_character_
    if (is.null(reason) && !.ucl_sim_before(feature_cutoff, kickoff)) reason <- "cutoff_violation"
    if (is.null(reason) && is.null(.ucl_sim_score_grid(row))) reason <- "insufficient_model_evidence"
    if (!is.null(reason)) {
      suppressed <- c(suppressed, fixture_id)
      record_index <- record_index + 1L
      records[[record_index]] <- data.frame(fixture_id = fixture_id, sampling_status = "suppressed", suppression_reason = reason, sampled_home_goals = NA_integer_, sampled_away_goals = NA_integer_, stringsAsFactors = FALSE, check.names = FALSE)
      next
    }
    sampled_score <- .ucl_sim_with_seed(.ucl_sim_seed_for(seed, "fixture", fixture_id), function() .ucl_sim_sample_score(row))
    if (!identical(sampled_score$status, "sampled")) {
      suppressed <- c(suppressed, fixture_id)
      next
    }
    fixtures$source_status[[index]] <- "completed"
    fixtures$match_status[[index]] <- "completed"
    fixtures$completion_method[[index]] <- "regulation"
    fixtures$regulation_home_goals[[index]] <- sampled_score$home
    fixtures$regulation_away_goals[[index]] <- sampled_score$away
    fixtures$final_home_goals[[index]] <- sampled_score$home
    fixtures$final_away_goals[[index]] <- sampled_score$away
    fixtures$counts_for_standings[[index]] <- TRUE
    fixtures$winner_club_id[[index]] <- if (sampled_score$home > sampled_score$away) fixtures$home_club_id[[index]] else if (sampled_score$away > sampled_score$home) fixtures$away_club_id[[index]] else NA_character_
    sampled <- c(sampled, fixture_id)
    record_index <- record_index + 1L
    records[[record_index]] <- data.frame(fixture_id = fixture_id, sampling_status = "sampled", suppression_reason = NA_character_, sampled_home_goals = sampled_score$home, sampled_away_goals = sampled_score$away, stringsAsFactors = FALSE, check.names = FALSE)
  }
  list(
    matches = fixtures,
    fixed_fixture_ids = prepared$fixed_fixture_ids,
    sampled_fixture_ids = sort(sampled, method = "radix"),
    suppressed_fixture_ids = sort(unique(suppressed), method = "radix"),
    eligible_open_fixture_ids = prepared$eligible_open_fixture_ids,
    records = if (length(records)) do.call(rbind, records) else data.frame(),
    cutoff_utc = cutoff_utc %||% prepared$cutoff_utc
  )
}

.ucl_sim_iteration_graph <- function(graph, ledger, seed = 20260921L, cutoff_utc = NULL, iteration = 1L) {
  output <- graph
  prepared <- .ucl_prepare_iteration_matches(output$fixtures, cutoff_utc = cutoff_utc)
  sampled <- .ucl_sample_open_fixtures(prepared, ledger = ledger, seed = .ucl_sim_seed_for(seed, "iteration", iteration), cutoff_utc = cutoff_utc)
  output$fixtures <- sampled$matches
  attr(output, "ucl_sampling") <- sampled
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
  ledger_authority <- if (is.list(ledger) && !is.null(ledger$authority)) ledger$authority else list()
  ledger_table <- if (is.list(ledger) && is.data.frame(ledger$ledger)) ledger$ledger else ledger
  if (is.null(ledger_table)) ledger_table <- data.frame(fixture_id = validation$graph$fixtures$fixture_id, forecast_status = "suppressed", stringsAsFactors = FALSE)
  simulations <- as.integer(simulations)
  if (length(simulations) != 1L || is.na(simulations) || simulations < 1L || simulations > 100000L) stop("UCL simulation count must be between 1 and 100000", call. = FALSE)
  rules <- rules %||% if (exists(".ucl_rule_contract", mode = "function")) .ucl_rule_contract() else NULL
  source_bundle_id <- source_bundle_id %||% validation$graph$source_bundle_id
  run_id <- .ucl_sim_hash(c(validation$graph$graph_sha256, if (is.null(rules)) "" else rules$ruleset_sha256, source_bundle_id, seed, simulations, information_cutoff_utc %||% ""))
  iteration_results <- lapply(seq_len(simulations), function(iteration) {
    graph_i <- .ucl_sim_iteration_graph(validation$graph, ledger_table, seed = seed, cutoff_utc = information_cutoff_utc, iteration = iteration)
    built <- if (exists("ucl_build_state", mode = "function")) ucl_build_state(graph_i, rules = rules, state_cutoff_utc = information_cutoff_utc %||% "2099-12-31T23:59:59Z") else NULL
    list(graph = graph_i, rows = if (is.null(built) || !identical(built$status, "ready")) data.frame() else .ucl_sim_rank_rows(built$standings, iteration, run_id))
  })
  rows <- do.call(rbind, lapply(iteration_results, `[[`, "rows")); if (is.null(rows)) rows <- data.frame(); row.names(rows) <- NULL
  path_state <- ucl_enumerate_legal_knockout_paths(if (nrow(rows)) rows[rows$iteration == max(rows$iteration), , drop = FALSE] else data.frame(), draw_artifact = draw_artifact, rules = rules, source_bundle_id = source_bundle_id, seed = seed)
  draw <- ucl_validate_draw_artifact(draw_artifact, rules = rules, source_bundle_id = source_bundle_id)
  sampling <- lapply(iteration_results, function(result) attr(result$graph, "ucl_sampling"))
  path_statuses <- if (is.data.frame(path_state) && nrow(path_state)) as.character(path_state$path_status) else character()
  unresolved_draw <- !identical(draw$status, "accepted") && (length(path_statuses) == 0L || any(path_statuses %in% c("pre_draw_legal", "unresolved")))
  metadata <- list(
    run_id = run_id, edition_id = validation$graph$edition_id, source_bundle_id = source_bundle_id,
    ruleset_version = if (is.null(rules)) NA_character_ else rules$ruleset_version,
    ruleset_sha256 = if (is.null(rules)) NA_character_ else rules$ruleset_sha256,
    draw_policy_id = if (is.null(rules)) "ucl-2026-27-article19-annexb-v1" else rules$draw_policy_id,
    draw_artifact_id = if (identical(draw$status, "accepted")) draw$draw_artifact_id else NA_character_,
    draw_artifact_sha256 = if (identical(draw$status, "accepted")) draw$draw_artifact_sha256 else NA_character_,
    information_cutoff_utc = information_cutoff_utc %||% NA_character_, algorithm_version = "ucl-conditional-league-v2",
    simulation_count = simulations, seed = as.integer(seed), path_policy_id = attr(path_state, "path_policy")$policy_id %||% "ucl-2026-27-article19-annexb-v1",
    path_policy_count = if (is.data.frame(path_state)) nrow(path_state) else 0L,
    path_policy_mode = attr(path_state, "path_policy")$mode %||% "unresolved",
    path_policy_seed = as.integer(seed), legality_checks = TRUE,
    authority_mode = as.character(validation$graph$authority_mode), production_eligible = FALSE,
    original_parent_reason = as.character(ledger_authority$original_parent_reason %||% ledger_authority$parent_reason %||% NA_character_),
    human_needed_reason = as.character(ledger_authority$human_needed_reason %||% NA_character_),
    status = if (unresolved_draw) "unresolved_draw_procedure" else "ready"
  )
  structure(list(status = metadata$status, run_id = run_id, rank_rows = rows, simulations = rows,
                 knockout_paths = path_state, metadata = metadata, graph = validation$graph,
                 ledger = ledger_table, fixture_sampling = sampling,
                 fixture_authority = isTRUE(validation$graph$fixture_authority), production_eligible = FALSE),
            class = c("ucl_simulation_run", "list"))
}

#' Aggregate rank, band, and cut-line probabilities from simulation rows.
ucl_aggregate_rank_distributions <- function(simulation, rules = NULL) {
  rows <- if (is.list(simulation) && is.data.frame(simulation$rank_rows)) simulation$rank_rows else simulation
  if (!is.data.frame(rows) || !nrow(rows)) return(list(status = "unresolved", rank_distribution = data.frame(), band_probabilities = data.frame(), cutline_distributions = list(), cutline = data.frame()))
  rules <- rules %||% if (exists(".ucl_rule_contract", mode = "function")) .ucl_rule_contract() else list(cardinality = list(clubs = max(36L, length(unique(rows$club_id)))))
  club_count <- as.integer(rules$cardinality$clubs %||% length(unique(rows$club_id))); total <- length(unique(rows$iteration)); clubs <- sort(unique(as.character(rows$club_id)), method = "radix")
  band_levels <- c("direct_round_of_16", "knockout_play_off", "eliminated")
  rank_distribution <- do.call(rbind, lapply(clubs, function(club) {
    values <- rows[as.character(rows$club_id) == club, , drop = FALSE]
    unresolved <- nrow(values) != total || any(is.na(values$rank) | as.character(values$rank_status) == "unresolved" | is.na(values$qualification_band))
    probability <- if (unresolved) rep(NA_real_, club_count) else vapply(seq_len(club_count), function(rank) mean(as.integer(values$rank) == rank), numeric(1))
    data.frame(edition_id = as.character(values$edition_id[[1L]] %||% NA_character_), club_id = club, rank = seq_len(club_count), probability = probability, status = if (unresolved) "unresolved" else "resolved", stringsAsFactors = FALSE, check.names = FALSE)
  }))
  band_probabilities <- do.call(rbind, lapply(clubs, function(club) {
    values <- rows[as.character(rows$club_id) == club, , drop = FALSE]
    unresolved <- nrow(values) != total || any(is.na(values$rank) | as.character(values$rank_status) == "unresolved" | is.na(values$qualification_band))
    probability <- if (unresolved) rep(NA_real_, length(band_levels)) else vapply(band_levels, function(band) mean(as.character(values$qualification_band) == band), numeric(1))
    data.frame(club_id = club, qualification_band = band_levels, probability = probability, status = if (unresolved) "unresolved" else "resolved", stringsAsFactors = FALSE, check.names = FALSE)
  }))
  cutline_distributions <- setNames(lapply(c(8L, 24L), function(boundary) {
    data.frame(cutline = boundary, club_id = clubs, probability = vapply(clubs, function(club) {
      values <- rows[as.character(rows$club_id) == club, , drop = FALSE]
      if (nrow(values) != total || any(is.na(values$rank) | as.character(values$rank_status) == "unresolved" | is.na(values$qualification_band))) return(NA_real_)
      mean(as.integer(values$rank) == boundary)
    }, numeric(1)), status = vapply(clubs, function(club) {
      values <- rows[as.character(rows$club_id) == club, , drop = FALSE]
      if (nrow(values) != total || any(is.na(values$rank) | as.character(values$rank_status) == "unresolved" | is.na(values$qualification_band))) "unresolved" else "resolved"
    }, character(1)), stringsAsFactors = FALSE, check.names = FALSE)
  }), c("rank_8", "rank_24"))
  cutline <- do.call(rbind, cutline_distributions)
  list(status = if (any(is.na(rows$rank) | as.character(rows$rank_status) == "unresolved" | is.na(rows$qualification_band))) "unresolved" else "ready", rank_distribution = rank_distribution,
       band_probabilities = band_probabilities, cutline_distributions = cutline_distributions, cutline = cutline, simulation_count = total,
       run_id = if (is.list(simulation)) simulation$run_id %||% NA_character_ else NA_character_)
}

.ucl_sim_rank_value <- function(rankings, club_id) {
  row <- rankings[as.character(rankings$club_id) == as.character(club_id), , drop = FALSE]
  if (nrow(row) != 1L) return(NA_integer_)
  status <- as.character(row$rank_status[[1L]] %||% "resolved")
  if (!is.na(row$rank[[1L]]) && status != "unresolved") return(as.integer(row$rank[[1L]]))
  lo <- as.integer(row$rank_interval_min[[1L]]); hi <- as.integer(row$rank_interval_max[[1L]])
  if (is.na(lo) || is.na(hi) || lo != hi || status == "unresolved") return(NA_integer_)
  lo
}

.ucl_unresolved_path <- function(rules, source_bundle_id, reason = "unresolved_rank_interval") {
  data.frame(edition_id = rules$edition_id, path_id = "pre-draw-unresolved", stage_id = "knockout_play_off", seed_slot_id = NA_character_, bracket_position = NA_character_, participant_a = NA_character_, participant_b = NA_character_, seed_rank = NA_integer_, opponent_rank = NA_integer_, leg_order = NA_character_, draw_policy_id = rules$draw_policy_id, draw_artifact_id = NA_character_, draw_artifact_sha256 = NA_character_, path_status = "unresolved", unresolved_reason = reason, source_bundle_id = source_bundle_id %||% NA_character_, ruleset_sha256 = rules$ruleset_sha256, stringsAsFactors = FALSE, check.names = FALSE)
}

.ucl_validate_legal_path <- function(path, rules = NULL, rank_lookup = NULL) {
  rules <- rules %||% if (exists(".ucl_rule_contract", mode = "function")) .ucl_rule_contract() else list(edition_id = "ucl_2026_27", draw_policy_id = "ucl-2026-27-article19-annexb-v1", ruleset_sha256 = NA_character_)
  if (!is.data.frame(path) || nrow(path) != 1L || !all(c("stage_id", "participant_a", "participant_b", "leg_order", "bracket_position") %in% names(path))) return(FALSE)
  path_status <- if ("path_status" %in% names(path)) as.character(path$path_status[[1L]]) else "accepted_draw"
  if (path_status == "unresolved") return(FALSE)
  if (as.character(path$leg_order[[1L]]) != "seeded_return_leg") return(FALSE)
  stage <- as.character(path$stage_id[[1L]]); seed_rank <- suppressWarnings(as.integer(path$seed_rank[[1L]])); opponent_rank <- suppressWarnings(as.integer(path$opponent_rank[[1L]]))
  if (stage == "knockout_play_off") {
    policy <- .ucl_rule_draw_policy(rules); families <- policy$playoff_pair_families
    valid_family <- nrow(families) == 4L && any(seed_rank >= families$seed_rank_min & seed_rank <= families$seed_rank_max & opponent_rank >= families$opponent_rank_min & opponent_rank <= families$opponent_rank_max & as.character(path$bracket_position[[1L]]) == as.character(families$bracket_position))
    if (!is.null(rank_lookup) && (is.null(names(rank_lookup)) || is.na(rank_lookup[[as.character(path$participant_a[[1L]])]]) || is.na(rank_lookup[[as.character(path$participant_b[[1L]])]]) || rank_lookup[[as.character(path$participant_a[[1L]])]] != seed_rank || rank_lookup[[as.character(path$participant_b[[1L]])]] != opponent_rank)) return(FALSE)
    return(isTRUE(valid_family) && nzchar(as.character(path$participant_a[[1L]])) && nzchar(as.character(path$participant_b[[1L]])) && !identical(as.character(path$participant_a[[1L]]), as.character(path$participant_b[[1L]])))
  }
  if (stage == "round_of_16") {
    policy <- .ucl_rule_draw_policy(rules); pairs <- policy$round_of_16_seed_pairs
    valid_position <- as.character(path$bracket_position[[1L]]) %in% c(as.character(pairs$bracket_position_a), as.character(pairs$bracket_position_b))
    if (!is.null(rank_lookup) && (is.null(names(rank_lookup)) || is.na(rank_lookup[[as.character(path$participant_a[[1L]])]]) || rank_lookup[[as.character(path$participant_a[[1L]])]] != seed_rank)) return(FALSE)
    return(seed_rank %in% 1:8 && is.na(opponent_rank) && valid_position && grepl("^winner:", as.character(path$participant_b[[1L]])) && nzchar(as.character(path$participant_a[[1L]])))
  }
  FALSE
}

#' Enumerate only rank-compatible play-off and round-of-16 path families.
ucl_enumerate_legal_knockout_paths <- function(rankings, draw_artifact = NULL, rules = NULL, seed = NULL, source_bundle_id = NULL) {
  rules <- rules %||% if (exists(".ucl_rule_contract", mode = "function")) .ucl_rule_contract() else list(edition_id = "ucl_2026_27", ruleset_sha256 = NA_character_, draw_policy_id = "ucl-2026-27-article19-annexb-v1")
  draw <- ucl_validate_draw_artifact(draw_artifact, rules = rules, source_bundle_id = source_bundle_id)
  if (identical(draw$status, "accepted")) {
    if (is.data.frame(rankings) && nrow(rankings) && all(c("club_id", "rank") %in% names(rankings))) {
      passed <- setNames(vapply(as.character(rankings$club_id), function(club) .ucl_sim_rank_value(rankings, club), integer(1)), as.character(rankings$club_id))
      expected <- setNames(as.integer(draw$rank_inputs$rank), as.character(draw$rank_inputs$club_id))
      common <- intersect(names(passed), names(expected))
      if (!length(common) || anyNA(passed[common]) || any(passed[common] != expected[common])) return(.ucl_unresolved_path(rules, source_bundle_id, "draw_rank_input_mismatch"))
    }
    output <- draw$pairings
    output$edition_id <- rules$edition_id; output$draw_policy_id <- rules$draw_policy_id; output$draw_artifact_id <- draw$draw_artifact_id; output$draw_artifact_sha256 <- draw$draw_artifact_sha256; output$path_status <- "accepted_draw"; output$unresolved_reason <- NA_character_; output$source_bundle_id <- source_bundle_id %||% draw$source_bundle_id %||% NA_character_; output$ruleset_sha256 <- rules$ruleset_sha256
    attr(output, "path_policy") <- list(policy_id = rules$draw_policy_id, mode = "accepted_draw_conditioning", count = nrow(output), seed = seed %||% NA_integer_)
    return(output)
  }
  if (!is.data.frame(rankings) || !nrow(rankings) || !all(c("club_id", "rank") %in% names(rankings))) return(.ucl_unresolved_path(rules, source_bundle_id, draw$reason %||% "unresolved_rank_interval"))
  club_rank <- setNames(vapply(as.character(rankings$club_id), function(club) .ucl_sim_rank_value(rankings, club), integer(1)), as.character(rankings$club_id))
  if (anyNA(club_rank) || anyDuplicated(club_rank) || !identical(sort(as.integer(club_rank)), seq_len(36L))) return(.ucl_unresolved_path(rules, source_bundle_id, if (identical(draw$reason, "missing_edition_draw_procedure")) "unresolved_rank_interval" else draw$reason %||% "unresolved_rank_interval"))
  by_rank <- setNames(names(club_rank), as.character(club_rank)); policy <- .ucl_rule_draw_policy(rules); rows <- list(); index <- 0L
  families <- policy$playoff_pair_families
  for (family_index in seq_len(nrow(families))) {
    family <- families[family_index, , drop = FALSE]
    for (seed_rank in family$seed_rank_min:family$seed_rank_max) for (opponent_rank in family$opponent_rank_min:family$opponent_rank_max) {
      index <- index + 1L
      rows[[index]] <- data.frame(edition_id = rules$edition_id, path_id = sprintf("playoff-%02d", index), stage_id = "knockout_play_off", seed_slot_id = paste0("playoff-seed-", sprintf("%02d", seed_rank)), bracket_position = as.character(family$bracket_position), participant_a = by_rank[[as.character(seed_rank)]], participant_b = by_rank[[as.character(opponent_rank)]], seed_rank = as.integer(seed_rank), opponent_rank = as.integer(opponent_rank), leg_order = "seeded_return_leg", draw_policy_id = rules$draw_policy_id, draw_artifact_id = NA_character_, draw_artifact_sha256 = NA_character_, path_status = "pre_draw_legal", unresolved_reason = "missing_edition_draw_procedure", source_bundle_id = source_bundle_id %||% NA_character_, ruleset_sha256 = rules$ruleset_sha256, stringsAsFactors = FALSE, check.names = FALSE)
    }
  }
  pairs <- policy$round_of_16_seed_pairs
  for (pair_index in seq_len(nrow(pairs))) {
    pair <- pairs[pair_index, , drop = FALSE]
    for (position_index in 1:2) {
      seed_rank <- if (position_index == 1L) pair$seed_rank_min else pair$seed_rank_max
      bracket <- if (position_index == 1L) pair$bracket_position_a else pair$bracket_position_b
      index <- index + 1L
      rows[[index]] <- data.frame(edition_id = rules$edition_id, path_id = sprintf("r16-%02d", index - 16L), stage_id = "round_of_16", seed_slot_id = as.character(pair$seed_pair_id), bracket_position = as.character(bracket), participant_a = by_rank[[as.character(seed_rank)]], participant_b = paste0("winner:playoff-", sprintf("%02d", ((pair_index - 1L) * 4L) + position_index)), seed_rank = as.integer(seed_rank), opponent_rank = NA_integer_, leg_order = "seeded_return_leg", draw_policy_id = rules$draw_policy_id, draw_artifact_id = NA_character_, draw_artifact_sha256 = NA_character_, path_status = "pre_draw_legal", unresolved_reason = "missing_edition_draw_procedure", source_bundle_id = source_bundle_id %||% NA_character_, ruleset_sha256 = rules$ruleset_sha256, stringsAsFactors = FALSE, check.names = FALSE)
    }
  }
  output <- do.call(rbind, rows); row.names(output) <- NULL
  attr(output, "path_policy") <- list(policy_id = rules$draw_policy_id, mode = "deterministic_pre_draw_enumeration", count = nrow(output), seed = seed %||% NA_integer_, legality_checks = TRUE)
  output
}

#' Validate a same-edition accepted draw or return a typed unresolved state.
ucl_validate_draw_artifact <- function(draw_artifact = NULL, rules = NULL, source_bundle_id = NULL) {
  rules <- rules %||% if (exists(".ucl_rule_contract", mode = "function")) .ucl_rule_contract() else list(edition_id = "ucl_2026_27")
  if (is.null(draw_artifact)) return(list(status = "unresolved", reason = "missing_edition_draw_procedure", draw_artifact_id = NA_character_, draw_artifact_sha256 = NA_character_))
  if (is.list(draw_artifact) && identical(as.character(draw_artifact$status %||% ""), "unresolved") && !is.null(draw_artifact$reason)) return(list(status = "unresolved", reason = as.character(draw_artifact$reason), draw_artifact_id = NA_character_, draw_artifact_sha256 = NA_character_))
  if (!is.list(draw_artifact) || !is.data.frame(draw_artifact$pairings)) return(list(status = "unresolved", reason = "partial_draw_artifact"))
  artifact <- draw_artifact; pairings <- artifact$pairings
  required <- c("path_id", "stage_id", "seed_slot_id", "bracket_position", "participant_a", "participant_b", "seed_rank", "opponent_rank", "leg_order", "source_artifact_ids")
  if (!all(required %in% names(pairings)) || !nrow(pairings) || anyNA(pairings$path_id) || anyDuplicated(as.character(pairings$path_id))) return(list(status = "unresolved", reason = "partial_draw_artifact"))
  if (!identical(as.character(artifact$edition_id %||% ""), as.character(rules$edition_id)) || (!is.null(source_bundle_id) && !identical(as.character(artifact$source_bundle_id %||% ""), as.character(source_bundle_id)))) return(list(status = "unresolved", reason = "foreign_lineage"))
  if (!isTRUE(artifact$accepted) || !isTRUE(artifact$complete)) return(list(status = "unresolved", reason = "partial_draw_artifact"))
  draw_id <- as.character(artifact$draw_artifact_id %||% artifact$artifact_id %||% ""); hash <- as.character(artifact$draw_artifact_sha256 %||% artifact$artifact_sha256 %||% "")
  if (!nzchar(draw_id) || !grepl("^[0-9a-f]{64}$", hash)) return(list(status = "unresolved", reason = "stale_draw_artifact"))
  rank_inputs <- artifact$rank_inputs
  if (!is.data.frame(rank_inputs) || !all(c("club_id", "rank") %in% names(rank_inputs)) || nrow(rank_inputs) != 36L || anyNA(rank_inputs$rank) || anyDuplicated(as.integer(rank_inputs$rank)) || !identical(sort(as.integer(rank_inputs$rank)), seq_len(36L)) || !grepl("^[0-9a-f]{64}$", as.character(artifact$rank_input_sha256 %||% ""))) return(list(status = "unresolved", reason = "partial_draw_artifact"))
  rank_map <- setNames(as.integer(rank_inputs$rank), as.character(rank_inputs$club_id))
  for (index in seq_len(nrow(pairings))) {
    row <- pairings[index, , drop = FALSE]
    if (!.ucl_validate_legal_path(row, rules = rules, rank_lookup = rank_map)) return(list(status = "unresolved", reason = "contradictory_draw_artifact"))
    a <- as.character(row$participant_a[[1L]]); b <- as.character(row$participant_b[[1L]])
    if (grepl("^winner:", b)) next
    if (!a %in% names(rank_map) || !b %in% names(rank_map)) return(list(status = "unresolved", reason = "foreign_lineage"))
    if (identical(a, b)) return(list(status = "unresolved", reason = "contradictory_draw_artifact"))
  }
  list(status = "accepted", reason = NA_character_, draw_artifact_id = draw_id, draw_artifact_sha256 = hash, pairings = pairings, edition_id = rules$edition_id, source_bundle_id = as.character(artifact$source_bundle_id), rank_inputs = rank_inputs)
}

.ucl_sim_score <- function(row, fields, default = NA_real_) {
  fields <- fields[fields %in% names(row)]
  if (!length(fields)) return(default)
  value <- suppressWarnings(as.numeric(row[[fields[[1L]]]][[1L]]))
  if (!length(value) || is.na(value)) return(default)
  value
}

.ucl_sim_valid_goal <- function(value, allow_na = TRUE) {
  if (is.na(value)) return(isTRUE(allow_na))
  is.finite(value) && value >= 0 && value == floor(value)
}

.ucl_sim_id <- function(row, fields, default = NA_character_) {
  fields <- fields[fields %in% names(row)]
  if (!length(fields)) return(default)
  value <- row[[fields[[1L]]]][[1L]]
  if (length(value) != 1L || is.na(value) || !nzchar(trimws(as.character(value)))) return(default)
  trimws(as.character(value))
}

.ucl_sim_leg_payload <- function(row) {
  regulation_home <- .ucl_sim_score(row, c("regulation_home_goals", "home_goals", "final_home_goals"))
  regulation_away <- .ucl_sim_score(row, c("regulation_away_goals", "away_goals", "final_away_goals"))
  extra_home <- .ucl_sim_score(row, c("extra_time_home_goals", "extra_home_goals", "et_home_goals"), NA_real_)
  extra_away <- .ucl_sim_score(row, c("extra_time_away_goals", "extra_away_goals", "et_away_goals"), NA_real_)
  final_home <- .ucl_sim_score(row, c("final_home_goals", "home_final_goals"), NA_real_)
  final_away <- .ucl_sim_score(row, c("final_away_goals", "away_final_goals"), NA_real_)
  shootout_home <- .ucl_sim_score(row, c("penalty_home", "penalties_home", "penalty_shootout_home_goals", "shootout_home_goals"), NA_real_)
  shootout_away <- .ucl_sim_score(row, c("penalty_away", "penalties_away", "penalty_shootout_away_goals", "shootout_away_goals"), NA_real_)
  list(
    regulation_home = regulation_home, regulation_away = regulation_away,
    extra_home = extra_home, extra_away = extra_away,
    final_home = final_home, final_away = final_away,
    shootout_home = shootout_home, shootout_away = shootout_away
  )
}

.ucl_sim_strict_two_leg <- function(first, second) {
  any(c("stage_id", "participant_a", "participant_b", "leg_order", "leg_number", "seed_rank", "opponent_rank") %in% names(first)) ||
    any(c("stage_id", "participant_a", "participant_b", "leg_order", "leg_number", "seed_rank", "opponent_rank") %in% names(second))
}

.ucl_sim_invalid_resolution <- function(reason, rules = NULL, ...) {
  list(status = "blocked", reason = reason, winner = NA_character_, loser = NA_character_,
       ruleset_sha256 = if (is.list(rules)) rules$ruleset_sha256 %||% NA_character_ else NA_character_, ...)
}

#' Resolve a UCL two-leg tie by aggregate goals, then second-leg ET and penalties.
ucl_resolve_two_leg_tie <- function(first_leg, second_leg, rules = NULL, penalty_winner = NULL) {
  first <- as.data.frame(first_leg, stringsAsFactors = FALSE, check.names = FALSE)
  second <- as.data.frame(second_leg, stringsAsFactors = FALSE, check.names = FALSE)
  if (nrow(first) != 1L || nrow(second) != 1L) stop("UCL two-leg resolver requires one row per leg", call. = FALSE)
  rules <- rules %||% if (exists(".ucl_rule_contract", mode = "function")) .ucl_rule_contract() else list(two_leg_policy = "aggregate_regulation_then_second_leg_extra_time_then_penalties_no_away_goals")
  strict <- .ucl_sim_strict_two_leg(first, second)
  if (strict) {
    if (!all(c("leg_number", "leg_order") %in% names(first)) || !all(c("leg_number", "leg_order") %in% names(second))) return(.ucl_sim_invalid_resolution("invalid_leg_topology", rules))
    leg_numbers <- suppressWarnings(as.integer(c(first$leg_number[[1L]], second$leg_number[[1L]])))
    if (anyNA(leg_numbers) || !identical(sort(leg_numbers), 1:2) || any(as.character(c(first$leg_order[[1L]], second$leg_order[[1L]])) != "seeded_return_leg")) return(.ucl_sim_invalid_resolution("invalid_leg_topology", rules))
  } else {
    if (!"leg_number" %in% names(first)) first$leg_number <- 1L
    if (!"leg_number" %in% names(second)) second$leg_number <- 2L
    if (!"leg_order" %in% names(first)) first$leg_order <- "legacy_two_leg"
    if (!"leg_order" %in% names(second)) second$leg_order <- "legacy_two_leg"
  }
  ordered <- if (as.integer(first$leg_number[[1L]]) == 1L) list(first = first, second = second) else list(first = second, second = first)
  first <- ordered$first; second <- ordered$second
  home_first <- .ucl_sim_id(first, c("home_club_id", "home_team_id", "home_team"))
  away_first <- .ucl_sim_id(first, c("away_club_id", "away_team_id", "away_team"))
  home_second <- .ucl_sim_id(second, c("home_club_id", "home_team_id", "home_team"))
  away_second <- .ucl_sim_id(second, c("away_club_id", "away_team_id", "away_team"))
  if (any(is.na(c(home_first, away_first, home_second, away_second))) ||
      any(!nzchar(c(home_first, away_first, home_second, away_second))) ||
      any(c(home_first, away_first, home_second, away_second)[c(TRUE, FALSE, TRUE, FALSE)] == c(away_first, away_second)) ||
      !identical(sort(c(home_first, away_first)), sort(c(home_second, away_second))) ||
      length(unique(c(home_first, away_first))) != 2L || !setequal(c(home_first, home_second), c(home_first, away_first))) {
    return(.ucl_sim_invalid_resolution("invalid_leg_topology", rules))
  }
  explicit_participants <- all(c("participant_a", "participant_b") %in% names(first)) && all(c("participant_a", "participant_b") %in% names(second))
  participant_a <- if (explicit_participants) .ucl_sim_id(first, "participant_a") else home_first
  participant_b <- if (explicit_participants) .ucl_sim_id(first, "participant_b") else away_first
  if (is.na(participant_a) || is.na(participant_b) || identical(participant_a, participant_b) ||
      !identical(sort(c(participant_a, participant_b)), sort(c(home_first, away_first))) ||
      (explicit_participants && (.ucl_sim_id(second, "participant_a") != participant_a || .ucl_sim_id(second, "participant_b") != participant_b))) {
    return(.ucl_sim_invalid_resolution("invalid_leg_topology", rules))
  }
  if (strict) {
    if (!all(c("venue_id") %in% names(first)) || !all(c("venue_id") %in% names(second)) ||
        any(!nzchar(c(.ucl_sim_id(first, "venue_id", ""), .ucl_sim_id(second, "venue_id", ""))))) return(.ucl_sim_invalid_resolution("invalid_leg_topology", rules))
    if (!all(c("seed_rank", "opponent_rank") %in% names(first)) ||
        suppressWarnings(as.integer(first$seed_rank[[1L]])) >= suppressWarnings(as.integer(first$opponent_rank[[1L]]))) {
      return(.ucl_sim_invalid_resolution("invalid_leg_order", rules))
    }
    if (!identical(home_first, participant_b) || !identical(home_second, participant_a)) return(.ucl_sim_invalid_resolution("invalid_leg_order", rules))
  }
  first_payload <- .ucl_sim_leg_payload(first); second_payload <- .ucl_sim_leg_payload(second)
  regulation <- c(0, 0); names(regulation) <- c(participant_a, participant_b)
  final <- regulation
  if (any(!vapply(c(first_payload$regulation_home, first_payload$regulation_away, second_payload$regulation_home, second_payload$regulation_away), .ucl_sim_valid_goal, logical(1), allow_na = FALSE))) return(list(status = "unresolved", reason = "score_evidence_missing", winner = NA_character_, participant_a = participant_a, participant_b = participant_b))
  regulation[home_first] <- regulation[home_first] + first_payload$regulation_home
  regulation[away_first] <- regulation[away_first] + first_payload$regulation_away
  regulation[home_second] <- regulation[home_second] + second_payload$regulation_home
  regulation[away_second] <- regulation[away_second] + second_payload$regulation_away
  final <- regulation
  extra_applied <- FALSE; penalty_applied <- FALSE; winner <- NA_character_; resolution <- "aggregate"
  et_home <- second_payload$extra_home; et_away <- second_payload$extra_away
  if (identical(as.numeric(regulation[[participant_a]]), as.numeric(regulation[[participant_b]]))) {
    pen_home <- second_payload$shootout_home; pen_away <- second_payload$shootout_away
    if (any(!vapply(c(et_home, et_away), .ucl_sim_valid_goal, logical(1), allow_na = FALSE))) {
      if (.ucl_sim_valid_goal(pen_home) && .ucl_sim_valid_goal(pen_away) && pen_home != pen_away) {
        et_home <- 0L; et_away <- 0L
      } else if (!is.null(penalty_winner) && length(penalty_winner) == 1L && as.character(penalty_winner) %in% c(participant_a, participant_b)) {
        et_home <- 0L; et_away <- 0L
      } else {
        return(list(status = "unresolved", reason = "extra_time_evidence_missing", winner = NA_character_, participant_a = participant_a, participant_b = participant_b, aggregate_regulation_home = as.integer(regulation[[participant_a]]), aggregate_regulation_away = as.integer(regulation[[participant_b]]), extra_time_applied = FALSE, penalty_applied = FALSE, away_goals_used = FALSE))
      }
    }
    extra_applied <- TRUE
    final[home_second] <- final[home_second] + et_home
    final[away_second] <- final[away_second] + et_away
    resolution <- "extra_time"
  }
  if (final[[participant_a]] > final[[participant_b]]) winner <- participant_a
  if (final[[participant_b]] > final[[participant_a]]) winner <- participant_b
  pen_home <- second_payload$shootout_home; pen_away <- second_payload$shootout_away
  if (is.na(winner)) {
    if (.ucl_sim_valid_goal(pen_home) && .ucl_sim_valid_goal(pen_away) && pen_home != pen_away) {
      penalty_applied <- TRUE; resolution <- "penalties"
      winner <- if (pen_home > pen_away) home_second else away_second
    } else if (!is.null(penalty_winner) && length(penalty_winner) == 1L && as.character(penalty_winner) %in% c(participant_a, participant_b)) {
      penalty_applied <- TRUE; resolution <- "penalties"; winner <- as.character(penalty_winner)
    }
  }
  if (is.na(winner)) return(list(status = "unresolved", reason = "penalty_evidence_missing", winner = NA_character_, participant_a = participant_a, participant_b = participant_b, aggregate_regulation_home = as.integer(regulation[[participant_a]]), aggregate_regulation_away = as.integer(regulation[[participant_b]]), aggregate_final_home = as.integer(final[[participant_a]]), aggregate_final_away = as.integer(final[[participant_b]]), extra_time_applied = extra_applied, extra_time_home = et_home, extra_time_away = et_away, penalty_applied = penalty_applied, penalty_home = pen_home, penalty_away = pen_away, away_goals_used = FALSE, ruleset_sha256 = rules$ruleset_sha256 %||% NA_character_))
  list(status = "resolved", reason = NA_character_, winner = winner, loser = setdiff(c(participant_a, participant_b), winner)[[1L]], participant_a = participant_a, participant_b = participant_b, aggregate_regulation_home = as.integer(regulation[[participant_a]]), aggregate_regulation_away = as.integer(regulation[[participant_b]]), aggregate_final_home = as.integer(final[[participant_a]]), aggregate_final_away = as.integer(final[[participant_b]]), extra_time_applied = extra_applied, extra_time_home = if (extra_applied) as.integer(et_home) else NA_integer_, extra_time_away = if (extra_applied) as.integer(et_away) else NA_integer_, penalty_applied = penalty_applied, penalty_home = if (penalty_applied) as.integer(pen_home) else NA_integer_, penalty_away = if (penalty_applied) as.integer(pen_away) else NA_integer_, away_goals_used = FALSE, leg_order = as.character(first$leg_order[[1L]]), leg_1_venue_id = .ucl_sim_id(first, "venue_id"), leg_2_venue_id = .ucl_sim_id(second, "venue_id"), second_leg_venue_id = .ucl_sim_id(second, "venue_id"), resolution = resolution, ruleset_sha256 = rules$ruleset_sha256 %||% NA_character_)
}

#' Resolve the neutral, single-match UCL final.
ucl_resolve_final <- function(match, rules = NULL, penalty_winner = NULL) {
  row <- as.data.frame(match, stringsAsFactors = FALSE, check.names = FALSE)
  if (nrow(row) != 1L) stop("UCL final resolver requires one match row", call. = FALSE)
  rules <- rules %||% if (exists(".ucl_rule_contract", mode = "function")) .ucl_rule_contract() else list(final_policy = "single_neutral_match_extra_time_then_penalties")
  home <- .ucl_sim_id(row, c("home_club_id", "home_team_id", "home_team")); away <- .ucl_sim_id(row, c("away_club_id", "away_team_id", "away_team"))
  if (is.na(home) || is.na(away) || identical(home, away)) return(.ucl_sim_invalid_resolution("invalid_final_participants", rules))
  strict <- "stage_id" %in% names(row) || "stage_event_id" %in% names(row)
  neutral <- if ("neutral" %in% names(row)) isTRUE(row$neutral[[1L]]) else TRUE
  if (!neutral) return(.ucl_sim_invalid_resolution("final_not_neutral", rules))
  venue <- .ucl_sim_id(row, c("venue_id", "venue", "neutral_venue_id"), NA_character_)
  if (strict && is.na(venue)) return(.ucl_sim_invalid_resolution("final_venue_missing", rules))
  payload <- .ucl_sim_leg_payload(row)
  if (any(!vapply(c(payload$regulation_home, payload$regulation_away), .ucl_sim_valid_goal, logical(1), allow_na = FALSE))) return(list(status = "unresolved", reason = "score_evidence_missing", winner = NA_character_, neutral = TRUE, home_club_id = home, away_club_id = away))
  regulation_tied <- payload$regulation_home == payload$regulation_away
  et_home <- payload$extra_home; et_away <- payload$extra_away
  final_home <- payload$regulation_home; final_away <- payload$regulation_away
  extra_applied <- FALSE; penalty_applied <- FALSE; winner <- if (final_home > final_away) home else if (final_away > final_home) away else NA_character_; resolution <- "regulation"
  if (regulation_tied) {
    pen_home <- payload$shootout_home; pen_away <- payload$shootout_away
    if (any(!vapply(c(et_home, et_away), .ucl_sim_valid_goal, logical(1), allow_na = FALSE))) {
      if ((.ucl_sim_valid_goal(pen_home) && .ucl_sim_valid_goal(pen_away) && pen_home != pen_away) || (!is.null(penalty_winner) && as.character(penalty_winner) %in% c(home, away))) {
        et_home <- 0L; et_away <- 0L
      } else {
        return(list(status = "unresolved", reason = "extra_time_evidence_missing", winner = NA_character_, neutral = TRUE, home_club_id = home, away_club_id = away, venue_id = venue))
      }
    }
    extra_applied <- TRUE; final_home <- final_home + et_home; final_away <- final_away + et_away; resolution <- "extra_time"
    winner <- if (final_home > final_away) home else if (final_away > final_home) away else NA_character_
  }
  pen_home <- payload$shootout_home; pen_away <- payload$shootout_away
  if (is.na(winner)) {
    if (.ucl_sim_valid_goal(pen_home) && .ucl_sim_valid_goal(pen_away) && pen_home != pen_away) { penalty_applied <- TRUE; resolution <- "penalties"; winner <- if (pen_home > pen_away) home else away }
    else if (!is.null(penalty_winner) && as.character(penalty_winner) %in% c(home, away)) { penalty_applied <- TRUE; resolution <- "penalties"; winner <- as.character(penalty_winner) }
  }
  if (is.na(winner)) return(list(status = "unresolved", reason = "penalty_evidence_missing", winner = NA_character_, neutral = TRUE, home_club_id = home, away_club_id = away, venue_id = venue, extra_time_applied = extra_applied, penalty_applied = penalty_applied))
  list(status = "resolved", reason = NA_character_, winner = winner, loser = setdiff(c(home, away), winner)[[1L]], neutral = TRUE, home_advantage = FALSE, home_club_id = home, away_club_id = away, venue_id = venue, regulation_home_goals = as.integer(payload$regulation_home), regulation_away_goals = as.integer(payload$regulation_away), final_home_goals = as.integer(final_home), final_away_goals = as.integer(final_away), extra_time_applied = extra_applied, extra_time_home = if (extra_applied) as.integer(et_home) else NA_integer_, extra_time_away = if (extra_applied) as.integer(et_away) else NA_integer_, penalty_applied = penalty_applied, penalty_home = if (penalty_applied) as.integer(pen_home) else NA_integer_, penalty_away = if (penalty_applied) as.integer(pen_away) else NA_integer_, resolution = resolution, ruleset_sha256 = rules$ruleset_sha256 %||% NA_character_)
}

# Persist one canonical stage-event row.  This is intentionally private: the
# public output seam is the closed knockout_paths.csv artifact.
.ucl_record_stage_event <- function(resolution, stage_id, stage_event_id, seed_slot_id = NA_character_, draw_policy_id = NA_character_, draw_artifact_id = NA_character_, draw_artifact_sha256 = NA_character_, source_artifact_ids = NA_character_, source_bundle_id = NA_character_, simulation_run_id = NA_character_) {
  resolution <- if (is.data.frame(resolution)) as.list(resolution[1L, , drop = FALSE]) else resolution
  scalar <- function(name, default = NA) { value <- resolution[[name]]; if (is.null(value) || !length(value)) return(default); value[[1L]] }
  aggregate_regulation_home <- scalar("aggregate_regulation_home", scalar("regulation_home_goals", NA_integer_))
  aggregate_regulation_away <- scalar("aggregate_regulation_away", scalar("regulation_away_goals", NA_integer_))
  aggregate_final_home <- scalar("aggregate_final_home", scalar("final_home_goals", NA_integer_))
  aggregate_final_away <- scalar("aggregate_final_away", scalar("final_away_goals", NA_integer_))
  status <- as.character(scalar("status", scalar("path_status", "unresolved")))
  if (status %in% c("completed", "accepted_draw")) status <- "resolved"
  venue <- scalar("venue_id", scalar("second_leg_venue_id", NA_character_))
  leg_1 <- scalar("leg_1_venue_id", venue); leg_2 <- scalar("leg_2_venue_id", venue)
  if (identical(as.character(stage_id), "final")) { leg_1 <- venue; leg_2 <- NA_character_ }
  out <- data.frame(
    edition_id = scalar("edition_id", if (exists(".ucl_rule_contract", mode = "function")) .ucl_rule_contract()$edition_id else "ucl_2026_27"),
    path_id = as.character(stage_event_id), stage_event_id = as.character(stage_event_id), stage_id = as.character(stage_id), seed_slot_id = as.character(seed_slot_id),
    participant_a = as.character(scalar("participant_a", scalar("home_club_id", NA_character_))), participant_b = as.character(scalar("participant_b", scalar("away_club_id", NA_character_))),
    leg_order = as.character(scalar("leg_order", if (identical(as.character(stage_id), "final")) "single_neutral" else "seeded_return_leg")),
    leg_1_venue_id = as.character(leg_1), leg_2_venue_id = as.character(leg_2),
    aggregate_regulation_home = as.integer(aggregate_regulation_home), aggregate_regulation_away = as.integer(aggregate_regulation_away), aggregate_final_home = as.integer(aggregate_final_home), aggregate_final_away = as.integer(aggregate_final_away),
    extra_time_applied = isTRUE(scalar("extra_time_applied", FALSE)), extra_time_home = as.integer(scalar("extra_time_home", NA_integer_)), extra_time_away = as.integer(scalar("extra_time_away", NA_integer_)), penalty_applied = isTRUE(scalar("penalty_applied", FALSE)), penalty_home = as.integer(scalar("penalty_home", NA_integer_)), penalty_away = as.integer(scalar("penalty_away", NA_integer_)),
    draw_policy_id = as.character(draw_policy_id), draw_artifact_id = as.character(draw_artifact_id), draw_artifact_sha256 = as.character(draw_artifact_sha256), path_status = status, unresolved_reason = as.character(scalar("reason", scalar("unresolved_reason", NA_character_))), source_artifact_ids = as.character(source_artifact_ids), source_bundle_id = as.character(source_bundle_id), ruleset_sha256 = as.character(scalar("ruleset_sha256", NA_character_)), simulation_run_id = as.character(simulation_run_id), stringsAsFactors = FALSE, check.names = FALSE
  )
  out
}

#' Aggregate stage input/output event counts without repairing unresolved rows.
ucl_aggregate_stage_events <- function(events, rules = NULL, stage_inputs = NULL, league_bands = NULL) {
  empty <- data.frame(stage_id = character(), input_count = integer(), resolved_count = integer(), unresolved_count = integer(), suppressed_count = integer(), output_count = integer(), stringsAsFactors = FALSE, check.names = FALSE)
  if (is.null(events)) {
    attr(empty, "valid") <- FALSE
    attr(empty, "errors") <- "stage_events_empty"
    return(empty)
  }
  events <- as.data.frame(events, stringsAsFactors = FALSE, check.names = FALSE)
  if (!"stage_id" %in% names(events)) stop("UCL stage events require stage_id", call. = FALSE)
  stage <- as.character(events$stage_id)
  raw_status <- if ("status" %in% names(events)) as.character(events$status) else if ("path_status" %in% names(events)) as.character(events$path_status) else rep("resolved", nrow(events))
  resolved_status <- c("resolved", "completed", "accepted_draw")
  unresolved_status <- c("unresolved", "blocked")
  suppressed_status <- c("suppressed", "pre_draw_legal")
  unknown <- !raw_status %in% c(resolved_status, unresolved_status, suppressed_status)
  classified <- ifelse(raw_status %in% resolved_status, "resolved", ifelse(raw_status %in% suppressed_status, "suppressed", "unresolved"))
  input_names <- names(stage_inputs)
  if (!is.null(stage_inputs) && (is.null(input_names) || any(!nzchar(input_names)))) stop("stage_inputs must be a named count vector", call. = FALSE)
  ids <- sort(unique(c(stage, input_names %||% character())), method = "radix")
  errors <- character()
  out <- do.call(rbind, lapply(ids, function(stage_id) {
    observed <- classified[stage == stage_id]
    expected <- if (!is.null(stage_inputs) && stage_id %in% input_names) suppressWarnings(as.integer(stage_inputs[[stage_id]])) else length(observed)
    if (is.na(expected) || expected < 0L) {
      errors <<- c(errors, paste0("invalid_stage_input:", stage_id))
      expected <- length(observed)
    }
    if (length(observed) > expected) errors <<- c(errors, paste0("stage_input_overflow:", stage_id))
    missing <- max(0L, expected - length(observed))
    data.frame(stage_id = stage_id, input_count = as.integer(expected), resolved_count = as.integer(sum(observed == "resolved")), unresolved_count = as.integer(sum(observed == "unresolved") + missing), suppressed_count = as.integer(sum(observed == "suppressed")), output_count = as.integer(sum(observed == "resolved")), stringsAsFactors = FALSE, check.names = FALSE)
  }))
  if (any(unknown)) errors <- c(errors, "unknown_stage_event_status")
  if (any(out$input_count != out$resolved_count + out$unresolved_count + out$suppressed_count)) errors <- c(errors, "stage_count_nonconservation")
  if (!is.null(league_bands)) {
    bands <- suppressWarnings(as.numeric(league_bands))
    if (anyNA(bands) || any(bands < 0) || abs(sum(bands) - 36) > 0) errors <- c(errors, "league_band_nonconservation")
  }
  row.names(out) <- NULL
  attr(out, "valid") <- !length(errors)
  attr(out, "errors") <- unique(errors)
  out
}

#' Validate probability conservation and monotone progression.
ucl_validate_progression_reconciliation <- function(progression, stage_inputs = NULL, league_bands = NULL, tolerance = 1e-10) {
  if (!is.data.frame(progression) || !nrow(progression)) return(list(status = "unresolved", valid = FALSE, errors = "progression_empty"))
  required <- c("club_id", "stage_id", "probability")
  if (!all(required %in% names(progression))) return(list(status = "blocked", valid = FALSE, errors = "progression_schema_incomplete"))
  errors <- character()
  p <- suppressWarnings(as.numeric(progression$probability))
  finite <- !is.na(p)
  if (any(!is.finite(p[finite]) | p[finite] < -tolerance | p[finite] > 1 + tolerance)) errors <- c(errors, "probability_bounds")
  if (any(is.na(p) & (!("status" %in% names(progression)) | as.character(progression$status) == "resolved"))) errors <- c(errors, "resolved_probability_missing")
  stage_order <- if ("stage_order" %in% names(progression)) suppressWarnings(as.numeric(progression$stage_order)) else match(as.character(progression$stage_id), c("direct_round_of_16", "knockout_play_off", "round_of_16", "quarter_final", "semi_final", "final", "champion", "eliminated"))
  if (any(is.na(stage_order))) errors <- c(errors, "stage_order_missing")
  for (club in unique(as.character(progression$club_id))) {
    rows <- progression[as.character(progression$club_id) == club, , drop = FALSE]
    order_values <- stage_order[as.character(progression$club_id) == club]
    ordered <- rows[order(order_values), , drop = FALSE]
    ordered_probability <- suppressWarnings(as.numeric(ordered$probability))
    if (length(ordered_probability) > 1L && any(diff(ordered_probability) > tolerance, na.rm = TRUE)) errors <- c(errors, paste0("non_monotone:", club))
    if ("qualification_band" %in% names(ordered)) {
      resolved <- if ("status" %in% names(ordered)) ordered[as.character(ordered$status) == "resolved", , drop = FALSE] else ordered
      values <- suppressWarnings(as.numeric(resolved$probability))
      if (length(values) && abs(sum(values, na.rm = TRUE) - 1) > tolerance) errors <- c(errors, paste0("band_sum:", club))
    }
  }
  if (!is.null(stage_inputs) && all(as.character(progression$status %||% rep("resolved", nrow(progression))) == "resolved")) {
    for (stage_id in intersect(names(stage_inputs), unique(as.character(progression$stage_id)))) {
      values <- suppressWarnings(as.numeric(progression$probability[as.character(progression$stage_id) == stage_id]))
      if (length(values) > 1L && all(is.finite(values)) && abs(sum(values) - 1) > tolerance) errors <- c(errors, paste0("stage_sum:", stage_id))
    }
  }
  if (!is.null(stage_inputs)) {
    if (is.null(names(stage_inputs)) || any(!nzchar(names(stage_inputs))) || anyNA(as.numeric(stage_inputs)) || any(as.numeric(stage_inputs) < 0)) errors <- c(errors, "stage_input_schema")
    unknown_stages <- setdiff(names(stage_inputs), unique(as.character(progression$stage_id)))
    if (length(unknown_stages)) errors <- c(errors, paste0("stage_input_missing:", unknown_stages))
  }
  if (!is.null(league_bands)) {
    bands <- suppressWarnings(as.numeric(league_bands))
    if (anyNA(bands) || any(bands < 0) || abs(sum(bands) - 36) > 0) errors <- c(errors, "league_band_nonconservation")
  }
  errors <- unique(errors)
  list(status = if (length(errors)) "invalid" else "ready", valid = !length(errors), errors = errors)
}
