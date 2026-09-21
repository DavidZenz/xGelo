# Accepted UCL schedule, canonical state, and immutable forecast-ledger seam.

.ucl_state_blocked <- function(reason_code, message, graph = NULL, diagnostics = list()) {
  structure(
    list(
      status = "blocked", reason_code = as.character(reason_code),
      message = as.character(message), graph = graph,
      diagnostics = diagnostics, production_eligible = FALSE,
      fixture_authority = if (is.null(graph)) FALSE else isTRUE(graph$fixture_authority)
    ),
    class = c("ucl_blocked_state", "list")
  )
}

.ucl_state_root <- function() {
  candidate <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  repeat {
    if (dir.exists(file.path(candidate, ".git")) || file.exists(file.path(candidate, ".git"))) return(candidate)
    parent <- dirname(candidate)
    if (identical(parent, candidate)) return(normalizePath(getwd(), winslash = "/", mustWork = TRUE))
    candidate <- parent
  }
}

.ucl_state_hash <- function(value) {
  if (!requireNamespace("digest", quietly = TRUE)) stop("UCL state requires digest", call. = FALSE)
  digest::digest(charToRaw(enc2utf8(paste(as.character(value), collapse = "\x1f"))), algo = "sha256", serialize = FALSE)
}

.ucl_state_scalar <- function(value) {
  if (inherits(value, "POSIXt")) return(format(value, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  if (inherits(value, "Date")) return(format(value, "%Y-%m-%d"))
  if (is.logical(value)) return(ifelse(is.na(value), "", ifelse(value, "true", "false")))
  if (!length(value) || is.na(value[[1L]])) return("")
  as.character(value[[1L]])
}

.ucl_state_graph_parts <- function(source, clubs = NULL, fixtures = NULL) {
  if (is.list(source) && !is.data.frame(source)) {
    clubs <- clubs %||% source$clubs
    fixtures <- fixtures %||% source$fixtures
  }
  list(
    graph = if (is.list(source) && !is.data.frame(source)) source else list(clubs = clubs, fixtures = fixtures),
    clubs = clubs, fixtures = fixtures
  )
}

.ucl_state_parse_time <- function(value) {
  suppressWarnings(as.POSIXct(as.character(value), tz = "UTC"))
}

.ucl_state_required_fixture_fields <- function() {
  c("edition_id", "fixture_id", "matchday", "home_club_id", "away_club_id",
    "venue_id", "kickoff_utc", "kickoff_confirmed", "confirmed_kickoff_at_utc",
    "source_artifact_id", "source_row_key", "source_lineage_id", "source_bundle_id",
    "source_status", "match_status", "completion_method",
    "regulation_home_goals", "regulation_away_goals", "final_home_goals",
    "final_away_goals", "shootout_home_goals", "shootout_away_goals",
    "counts_for_standings")
}

.ucl_state_status_completed <- function(value) {
  tolower(trimws(as.character(value))) %in% c(
    "completed", "complete", "finished", "full_time", "full-time",
    "after_extra_time", "after-extra-time", "after_penalties", "after-penalties", "awarded"
  )
}

.ucl_state_validate_scores <- function(fixtures) {
  completed <- .ucl_state_status_completed(fixtures$match_status)
  score_fields <- c("regulation_home_goals", "regulation_away_goals", "final_home_goals", "final_away_goals", "shootout_home_goals", "shootout_away_goals")
  for (field in score_fields) {
    values <- fixtures[[field]]
    if (any(!is.na(values) & (!is.finite(as.numeric(values)) | as.numeric(values) < 0 | as.numeric(values) != floor(as.numeric(values))))) {
      return("score_not_nonnegative_integer")
    }
  }
  has_final <- !is.na(fixtures$final_home_goals) & !is.na(fixtures$final_away_goals)
  has_regulation <- !is.na(fixtures$regulation_home_goals) & !is.na(fixtures$regulation_away_goals)
  if (any(completed & !(has_final | has_regulation))) return("completed_score_missing")
  if (any(!completed & (has_final | has_regulation | !is.na(fixtures$shootout_home_goals) | !is.na(fixtures$shootout_away_goals)))) return("open_fixture_has_score")
  invisible(NULL)
}

.ucl_state_canonical_sort <- function(fixtures) {
  fixtures[order(as.character(fixtures$fixture_id), as.character(fixtures$home_club_id), as.character(fixtures$away_club_id), method = "radix"), , drop = FALSE]
}

.ucl_state_graph_hash <- function(graph) {
  fixtures <- .ucl_state_canonical_sort(graph$fixtures)
  fields <- intersect(c("edition_id", "fixture_id", "matchday", "home_club_id", "away_club_id", "venue_id", "kickoff_utc", "source_artifact_id", "source_row_key", "source_lineage_id", "source_row_sha256"), names(fixtures))
  .ucl_state_hash(paste(vapply(seq_len(nrow(fixtures)), function(index) paste(vapply(fixtures[index, fields, drop = FALSE], .ucl_state_scalar, character(1)), collapse = "|"), character(1)), collapse = "\x1e"))
}

.ucl_state_validate_source_lineage <- function(fixtures) {
  fields <- c("source_artifact_id", "source_row_key", "source_lineage_id", "source_bundle_id")
  if (!all(fields %in% names(fixtures))) return("source_lineage_missing")
  for (field in fields) {
    values <- as.character(fixtures[[field]])
    if (any(is.na(values) | !nzchar(trimws(values)))) return(paste0(field, "_missing"))
  }
  if ("source_row_sha256" %in% names(fixtures)) {
    values <- as.character(fixtures$source_row_sha256)
    if (any(is.na(values) | !grepl("^[0-9a-f]{64}$", values))) return("source_row_hash_missing")
  }
  invisible(NULL)
}

#' Validate the complete accepted 36-club/144-fixture league graph.
#'
#' Invalid inputs return a typed blocked value and never synthesize missing
#' pairings.  Valid inputs return a canonical, semantically sorted graph.
ucl_validate_schedule <- function(source, clubs = NULL, fixtures = NULL, rules = NULL, require_authority = FALSE) {
  parts <- .ucl_state_graph_parts(source, clubs, fixtures)
  graph <- parts$graph; clubs <- parts$clubs; fixtures <- parts$fixtures
  if (!is.data.frame(clubs) || !is.data.frame(fixtures)) return(.ucl_state_blocked("source_schema_invalid", "UCL schedule requires clubs and fixtures tables", graph))
  expected_edition <- if (!is.null(rules) && !is.null(rules$edition_id)) as.character(rules$edition_id) else "ucl_2026_27"
  missing_fixture <- setdiff(.ucl_state_required_fixture_fields(), names(fixtures))
  if (length(missing_fixture)) return(.ucl_state_blocked("fixture_schema_incomplete", paste0("UCL fixtures missing: ", paste(missing_fixture, collapse = ", ")), graph, list(missing = missing_fixture)))
  if (!"club_id" %in% names(clubs)) return(.ucl_state_blocked("club_schema_incomplete", "UCL clubs require club_id", graph))
  if (nrow(clubs) != 36L || length(unique(as.character(clubs$club_id))) != 36L) return(.ucl_state_blocked("club_cardinality_invalid", "UCL schedule requires exactly 36 unique clubs", graph))
  if (nrow(fixtures) != 144L || anyDuplicated(as.character(fixtures$fixture_id))) return(.ucl_state_blocked("fixture_cardinality_invalid", "UCL schedule requires exactly 144 unique fixtures", graph))
  club_ids <- as.character(clubs$club_id); fixture_ids <- as.character(fixtures$fixture_id)
  if (any(is.na(club_ids) | !nzchar(club_ids)) || anyDuplicated(club_ids) || any(is.na(fixture_ids) | !nzchar(fixture_ids))) return(.ucl_state_blocked("identity_invalid", "UCL club and fixture identities must be stable and non-empty", graph))
  if (length(unique(as.character(fixtures$edition_id))) != 1L || any(as.character(fixtures$edition_id) != expected_edition)) return(.ucl_state_blocked("foreign_edition", "UCL fixtures must belong to one supported edition", graph))
  if (length(unique(as.character(clubs$edition_id %||% expected_edition))) > 1L || any(as.character(clubs$edition_id %||% expected_edition) != expected_edition)) return(.ucl_state_blocked("foreign_club_edition", "UCL clubs must belong to the supported edition", graph))
  endpoints <- c(as.character(fixtures$home_club_id), as.character(fixtures$away_club_id))
  if (any(!endpoints %in% club_ids)) return(.ucl_state_blocked("unknown_fixture_endpoint", "UCL fixture references an unknown club", graph))
  if (any(as.character(fixtures$home_club_id) == as.character(fixtures$away_club_id))) return(.ucl_state_blocked("self_fixture", "UCL fixtures cannot contain a club against itself", graph))
  degree <- table(factor(endpoints, levels = club_ids))
  home_degree <- table(factor(as.character(fixtures$home_club_id), levels = club_ids))
  away_degree <- table(factor(as.character(fixtures$away_club_id), levels = club_ids))
  if (any(as.integer(degree) != 8L) || any(as.integer(home_degree) != 4L) || any(as.integer(away_degree) != 4L)) return(.ucl_state_blocked("schedule_degree_invalid", "UCL schedule requires eight opponents and a 4/4 home-away split", graph))
  opponents <- lapply(club_ids, function(id) unique(c(as.character(fixtures$away_club_id[fixtures$home_club_id == id]), as.character(fixtures$home_club_id[fixtures$away_club_id == id]))))
  if (any(vapply(opponents, length, integer(1)) != 8L)) return(.ucl_state_blocked("opponent_cardinality_invalid", "UCL schedule requires eight distinct opponents per club", graph))
  if (any(is.na(suppressWarnings(as.integer(fixtures$matchday)))) || any(as.integer(fixtures$matchday) < 1L | as.integer(fixtures$matchday) > 8L)) return(.ucl_state_blocked("matchday_invalid", "UCL matchday must be in 1 through 8", graph))
  if (any(is.na(as.character(fixtures$venue_id)) | !nzchar(trimws(as.character(fixtures$venue_id))))) return(.ucl_state_blocked("venue_missing", "UCL fixture venue evidence is required", graph))
  kickoff <- .ucl_state_parse_time(fixtures$kickoff_utc); confirmed <- as.logical(fixtures$kickoff_confirmed)
  confirmed_time <- .ucl_state_parse_time(fixtures$confirmed_kickoff_at_utc)
  if (any(is.na(kickoff)) || any(is.na(confirmed)) || any(!confirmed) || any(is.na(confirmed_time))) return(.ucl_state_blocked("kickoff_unconfirmed", "UCL fixtures require a confirmed kickoff", graph))
  if (any(as.character(fixtures$source_bundle_id) != as.character(fixtures$source_bundle_id[[1L]]))) return(.ucl_state_blocked("lineage_bundle_mismatch", "UCL fixtures must share one source bundle", graph))
  lineage_error <- .ucl_state_validate_source_lineage(fixtures)
  if (!is.null(lineage_error)) return(.ucl_state_blocked("source_lineage_invalid", lineage_error, graph))
  score_error <- .ucl_state_validate_scores(fixtures)
  if (!is.null(score_error)) return(.ucl_state_blocked("score_semantics_invalid", score_error, graph))
  graph$edition_id <- expected_edition
  graph$clubs <- clubs[order(as.character(clubs$club_id), method = "radix"), , drop = FALSE]
  graph$fixtures <- .ucl_state_canonical_sort(fixtures)
  graph$source_bundle_id <- as.character(graph$source_bundle_id %||% graph$fixtures$source_bundle_id[[1L]])
  graph$source_lineage_id <- as.character(graph$source_lineage_id %||% paste(unique(as.character(graph$fixtures$source_lineage_id)), collapse = ";"))
  graph$authority_mode <- as.character(graph$authority_mode %||% "accepted")
  graph$fixture_authority <- isTRUE(graph$fixture_authority)
  graph$production_eligible <- isTRUE(graph$production_eligible) && !graph$fixture_authority
  graph$selector_path <- graph$selector_path %||% NULL
  graph$production_root <- graph$production_root %||% NULL
  if (isTRUE(require_authority) && identical(graph$authority_mode, "fixture") && !isTRUE(graph$fixture_authority)) return(.ucl_state_blocked("fixture_authority_marker_missing", "Fixture source must carry its non-promotable marker", graph))
  graph$graph_sha256 <- .ucl_state_graph_hash(graph)
  structure(list(status = "ready", graph = graph, clubs = graph$clubs, fixtures = graph$fixtures,
                 edition_id = expected_edition, source_bundle_id = graph$source_bundle_id,
                 authority_mode = graph$authority_mode, fixture_authority = graph$fixture_authority,
                 production_eligible = graph$production_eligible, graph_sha256 = graph$graph_sha256),
            class = c("ucl_schedule_validation", "list"))
}

.ucl_state_to_phase14_matches <- function(fixtures, state_cutoff_utc = "2099-12-31T23:59:59Z") {
  n <- nrow(fixtures)
  final_home <- as.integer(fixtures$final_home_goals)
  final_away <- as.integer(fixtures$final_away_goals)
  final_home[is.na(final_home)] <- as.integer(fixtures$regulation_home_goals[is.na(final_home)])
  final_away[is.na(final_away)] <- as.integer(fixtures$regulation_away_goals[is.na(final_away)])
  completed <- .ucl_state_status_completed(fixtures$match_status)
  evidence <- ifelse(completed, as.character(fixtures$confirmed_kickoff_at_utc), NA_character_)
  data.frame(
    schema_version = "phase14-canonical-match-v1",
    match_id = as.character(fixtures$fixture_id), source_namespace = "ucl_fixture",
    source_id = as.character(fixtures$source_artifact_id), source_match_id = as.character(fixtures$source_row_key),
    source_lineage_id = as.character(fixtures$source_lineage_id), edition_id = as.character(fixtures$edition_id),
    fixture_id = as.character(fixtures$fixture_id), source_group_id = "league_phase", group_id = "league_phase",
    home_team_id = as.character(fixtures$home_club_id), away_team_id = as.character(fixtures$away_club_id),
    home_display_name = as.character(fixtures$home_club_id), away_display_name = as.character(fixtures$away_club_id),
    scheduled_at_utc = as.character(fixtures$kickoff_utc), match_date = substr(as.character(fixtures$kickoff_utc), 1L, 10L),
    kickoff_confirmed = as.logical(fixtures$kickoff_confirmed), confirmed_kickoff_at_utc = as.character(fixtures$confirmed_kickoff_at_utc),
    neutral = FALSE, venue_context = as.character(fixtures$venue_id), source_status = as.character(fixtures$source_status),
    match_status = as.character(fixtures$match_status),
    completion_method = ifelse(completed, ifelse(as.character(fixtures$completion_method) == "not_completed", "regulation", as.character(fixtures$completion_method)), "not_applicable"),
    regulation_home_goals = as.integer(fixtures$regulation_home_goals), regulation_away_goals = as.integer(fixtures$regulation_away_goals),
    final_home_goals = final_home, final_away_goals = final_away,
    shootout_home_goals = as.integer(fixtures$shootout_home_goals), shootout_away_goals = as.integer(fixtures$shootout_away_goals),
    winner_team_id = ifelse(!completed, NA_character_, ifelse(final_home > final_away, as.character(fixtures$home_club_id), ifelse(final_away > final_home, as.character(fixtures$away_club_id), NA_character_))),
    evidence_completed_at_utc = evidence, counts_for_standings = as.logical(fixtures$counts_for_standings),
    counts_for_form = as.logical(fixtures$counts_for_standings), source_artifact_id = as.character(fixtures$source_artifact_id),
    fixture_source_artifact_id = as.character(fixtures$source_artifact_id), competition_lineage_id = as.character(fixtures$source_lineage_id),
    history_lineage_id = as.character(fixtures$source_lineage_id), source_row_sha256 = as.character(fixtures$source_row_sha256),
    state_cutoff_utc = as.character(state_cutoff_utc),
    row_sha256 = NA_character_, table_sha256 = NA_character_, stringsAsFactors = FALSE, check.names = FALSE
  )
}

.ucl_state_source_phase14 <- function() {
  if (exists("phase14_compute_standings", mode = "function", inherits = TRUE)) return(invisible(TRUE))
  root <- .ucl_state_root()
  for (relative in c("R/competition/standings.R", "R/competition/match_state.R")) {
    path <- file.path(root, relative)
    if (file.exists(path)) try(source(path, local = .GlobalEnv), silent = TRUE)
  }
  invisible(exists("phase14_compute_standings", mode = "function", inherits = TRUE))
}

.ucl_state_fallback_standings <- function(matches, team_ids) {
  rows <- lapply(team_ids, function(team) {
    counted <- (as.character(matches$home_team_id) == team | as.character(matches$away_team_id) == team) & as.logical(matches$counts_for_standings)
    home <- counted & as.character(matches$home_team_id) == team
    away <- counted & as.character(matches$away_team_id) == team
    hg <- as.numeric(matches$final_home_goals); ag <- as.numeric(matches$final_away_goals)
    gf <- c(hg[home], ag[away]); ga <- c(ag[home], hg[away]);
    data.frame(team_id = team, played = sum(!is.na(gf) & !is.na(ga)), wins = sum(gf > ga, na.rm = TRUE), draws = sum(gf == ga, na.rm = TRUE), losses = sum(gf < ga, na.rm = TRUE), goals_for = sum(gf, na.rm = TRUE), goals_against = sum(ga, na.rm = TRUE), goal_difference = sum(gf - ga, na.rm = TRUE), points = 3 * sum(gf > ga, na.rm = TRUE) + sum(gf == ga, na.rm = TRUE), stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}

#' Build canonical UCL league state and Article 18 projection.
ucl_build_state <- function(source, rules = NULL, state_cutoff_utc = NULL, provider_standings = NULL,
                            evidence = NULL, evidence_path = NULL) {
  rules <- rules %||% if (exists(".ucl_rule_contract", mode = "function")) .ucl_rule_contract(evidence, evidence_path) else NULL
  validation <- ucl_validate_schedule(source, rules = rules)
  if (!identical(validation$status, "ready")) return(validation)
  state_cutoff_utc <- state_cutoff_utc %||% "2099-12-31T23:59:59Z"
  graph <- validation$graph
  matches <- .ucl_state_to_phase14_matches(graph$fixtures, state_cutoff_utc)
  .ucl_state_source_phase14()
  universal <- if (exists("phase14_compute_standings", mode = "function", inherits = TRUE)) {
    phase14_compute_standings(matches = matches, edition_id = graph$edition_id, group_id = "league_phase", state_cutoff_utc = state_cutoff_utc, source_bundle_id = graph$source_bundle_id, ruleset_adapter = NULL, team_ids = graph$clubs$club_id)
  } else {
    .ucl_state_fallback_standings(matches, as.character(graph$clubs$club_id))
  }
  ranking <- ucl_apply_article18(universal, matches = graph$fixtures, evidence = evidence, rules = rules)
  ranking$source_bundle_id <- graph$source_bundle_id
  ranking$ruleset_sha256 <- rules$ruleset_sha256
  provider <- if (is.null(provider_standings)) NULL else as.data.frame(provider_standings, stringsAsFactors = FALSE, check.names = FALSE)
  if (!is.null(provider)) {
    provider$reconciliation_status <- if ("club_id" %in% names(provider)) ifelse(provider$club_id %in% ranking$club_id, "same_lineage_candidate", "foreign_identity") else "unusable"
  }
  status <- attr(ranking, "status", exact = TRUE) %||% "ready"
  structure(list(
    status = "ready", ranking_status = status, edition_id = graph$edition_id,
    state_cutoff_utc = state_cutoff_utc, source_bundle_id = graph$source_bundle_id,
    source_lineage_id = graph$source_lineage_id, authority_mode = graph$authority_mode,
    fixture_authority = graph$fixture_authority, production_eligible = graph$production_eligible,
    graph_sha256 = graph$graph_sha256, graph = graph, clubs = graph$clubs,
    fixtures = graph$fixtures, canonical_matches = matches,
    universal_standings = universal, standings = ranking, projected_standings = ranking,
    projected_rankings = ranking[, intersect(c("edition_id", "club_id", "rank", "rank_interval_min", "rank_interval_max", "rank_status", "qualification_band", "source_bundle_id", "ruleset_sha256"), names(ranking)), drop = FALSE],
    tie_break_trace = attr(ranking, "trace", exact = TRUE), provider_reconciliation = provider,
    rules = rules, ruleset_version = rules$ruleset_version, ruleset_sha256 = rules$ruleset_sha256
  ), class = c("ucl_state_bundle", "list"))
}

.ucl_state_normalize_parent_reason <- function(reason) {
  original <- if (length(reason) && !is.na(reason[[1L]])) as.character(reason[[1L]]) else ""
  if (identical(original, "no_accepted_current_ucl")) return(list(status = "production_human_needed", human_needed_reason = "phase18_authority_missing", production_blocked_reason = NA_character_, normalization_error = FALSE, original_parent_reason = original))
  if (original %in% c("no_accepted_club_history", "protocol_policy_not_approved", "fold_inventory_not_approved", "phase19_cr01_roster_mismatch", "phase19_cr02_rating_replay_unverified", "phase19_cr03_fold_identity_unverified", "phase19_cr04_probability_lineage_unverified", "phase19_cr05_unbacked_installer")) return(list(status = "production_human_needed", human_needed_reason = "phase19_cr01_cr05_repair_pending", production_blocked_reason = NA_character_, normalization_error = FALSE, original_parent_reason = original))
  if (identical(original, "phase19_selector_not_accepted")) return(list(status = "production_human_needed", human_needed_reason = "phase19_selector_not_accepted", production_blocked_reason = NA_character_, normalization_error = FALSE, original_parent_reason = original))
  list(status = "production_blocked", human_needed_reason = NA_character_, production_blocked_reason = "unrecognized_parent_reason", normalization_error = TRUE, original_parent_reason = original)
}

.ucl_state_production_release <- function() {
  if (!exists("phase19_resolve_production_club_release", mode = "function", inherits = TRUE)) {
    release_path <- file.path(.ucl_state_root(), "R", "club", "release.R")
    if (file.exists(release_path)) try(source(release_path, local = .GlobalEnv), silent = TRUE)
  }
  if (!exists("phase19_resolve_production_club_release", mode = "function", inherits = TRUE)) return(list(error = "no_accepted_club_history"))
  tryCatch(list(value = phase19_resolve_production_club_release()), error = function(error) {
    reason <- if (!is.null(error$reason_code)) as.character(error$reason_code) else "phase19_selector_not_accepted"
    if (reason %in% c("release_root_invalid", "release_artifact_missing", "release_dependency_missing", "release_preflight_stale")) {
      reason <- "no_accepted_club_history"
    }
    list(error = reason, message = conditionMessage(error))
  })
}

.ucl_state_ledger_hash <- function(row) {
  fields <- setdiff(names(row), "row_sha256")
  .ucl_state_hash(paste(vapply(row[fields], .ucl_state_scalar, character(1)), collapse = "|"))
}

.ucl_state_forecast_row <- function(fixture, release_rows = NULL, prior = NULL, authority = NULL, cutoff = NULL) {
  fixture_id <- as.character(fixture$fixture_id[[1L]])
  completed <- .ucl_state_status_completed(fixture$match_status[[1L]])
  candidate <- if (!is.null(release_rows) && nrow(release_rows)) release_rows[as.character(release_rows$fixture_id) == fixture_id, , drop = FALSE] else data.frame()
  valid_candidate <- nrow(candidate) == 1L
  if (valid_candidate) {
    cutoff_time <- .ucl_state_parse_time(candidate$feature_cutoff_utc[[1L]])
    kickoff <- .ucl_state_parse_time(fixture$kickoff_utc[[1L]])
    probs <- suppressWarnings(as.numeric(candidate[c("prob_home", "prob_draw", "prob_away")]))
    valid_candidate <- all(is.finite(probs)) && all(probs >= 0) && abs(sum(probs) - 1) <= 1e-10 && !is.na(cutoff_time) && !is.na(kickoff) && cutoff_time < kickoff
  }
  if (completed && !is.null(prior) && nrow(prior) == 1L) {
    # Completed forecast bytes are immutable: reuse every prior field and only
    # check identity.  No post-kickoff model output can replace this row.
    return(prior[1L, , drop = FALSE])
  }
  result <- data.frame(
    edition_id = as.character(fixture$edition_id[[1L]]), fixture_id = fixture_id,
    home_club_id = as.character(fixture$home_club_id[[1L]]), away_club_id = as.character(fixture$away_club_id[[1L]]),
    kickoff_utc = as.character(fixture$kickoff_utc[[1L]]),
    forecast_status = if (valid_candidate) as.character(candidate$forecast_status[[1L]] %||% "available") else "suppressed",
    suppression_reason = if (valid_candidate) NA_character_ else if (!isTRUE(fixture$kickoff_confirmed[[1L]])) "kickoff_unconfirmed" else if (!is.null(cutoff) && isTRUE(.ucl_state_parse_time(cutoff) >= .ucl_state_parse_time(fixture$kickoff_utc[[1L]]))) "cutoff_violation" else if (!is.null(authority) && !is.null(authority$error)) "release_unavailable" else "insufficient_model_evidence",
    model_release_id = if (valid_candidate) as.character(candidate$model_release_id[[1L]]) else NA_character_,
    model_sha256 = if (valid_candidate) as.character(candidate$model_sha256[[1L]]) else NA_character_,
    calibrator_sha256 = if (valid_candidate) as.character(candidate$calibrator_sha256[[1L]]) else NA_character_,
    feature_cutoff_utc = if (valid_candidate) as.character(candidate$feature_cutoff_utc[[1L]]) else NA_character_,
    prob_home = if (valid_candidate) as.numeric(candidate$prob_home[[1L]]) else NA_real_,
    prob_draw = if (valid_candidate) as.numeric(candidate$prob_draw[[1L]]) else NA_real_,
    prob_away = if (valid_candidate) as.numeric(candidate$prob_away[[1L]]) else NA_real_,
    xg_home = if (valid_candidate) as.numeric(candidate$xg_home[[1L]]) else NA_real_,
    xg_away = if (valid_candidate) as.numeric(candidate$xg_away[[1L]]) else NA_real_,
    likely_score = if (valid_candidate) as.character(candidate$likely_score[[1L]]) else NA_character_,
    source_bundle_id = as.character(fixture$source_bundle_id[[1L]]), row_sha256 = NA_character_,
    stringsAsFactors = FALSE, check.names = FALSE
  )
  result$row_sha256 <- .ucl_state_ledger_hash(result)
  result
}

#' Build one immutable, typed forecast row for every accepted UCL fixture.
ucl_build_forecast_ledger <- function(state, release = NULL, prior_ledger = NULL,
                                      state_cutoff_utc = NULL, authority_mode = NULL,
                                      production_resolver = NULL) {
  graph <- if (is.list(state) && !is.data.frame(state) && !is.null(state$graph)) state$graph else state
  validation <- ucl_validate_schedule(graph)
  if (!identical(validation$status, "ready")) return(validation)
  production <- if (is.null(production_resolver)) .ucl_state_production_release() else tryCatch(list(value = production_resolver()), error = function(error) list(error = if (!is.null(error$reason_code)) as.character(error$reason_code) else "phase19_selector_not_accepted", message = conditionMessage(error)))
  parent_reason <- if (!is.null(production$error)) production$error else ""
  authority <- .ucl_state_normalize_parent_reason(parent_reason)
  chosen <- release
  if (is.null(chosen) && is.null(production$error)) chosen <- production$value
  is_fixture <- is.list(chosen) && isTRUE(chosen$fixture_authority)
  if (is_fixture) {
    chosen$production_eligible <- FALSE
    chosen$selector_authorized <- FALSE
    chosen$authority_mode <- "fixture"
  }
  release_rows <- if (is.list(chosen) && is.data.frame(chosen$forecast_rows)) chosen$forecast_rows else if (is.list(chosen) && is.data.frame(chosen$forecasts)) chosen$forecasts else NULL
  previous <- if (is.data.frame(prior_ledger)) prior_ledger else if (is.list(prior_ledger) && is.data.frame(prior_ledger$ledger)) prior_ledger$ledger else NULL
  rows <- lapply(seq_len(nrow(validation$graph$fixtures)), function(index) {
    fixture <- validation$graph$fixtures[index, , drop = FALSE]
    prior <- if (!is.null(previous)) previous[as.character(previous$fixture_id) == as.character(fixture$fixture_id), , drop = FALSE] else NULL
    .ucl_state_forecast_row(fixture, release_rows, prior, if (is_fixture) NULL else production, state_cutoff_utc)
  })
  ledger <- do.call(rbind, rows)
  ledger <- ledger[order(as.character(ledger$fixture_id), method = "radix"), , drop = FALSE]
  row.names(ledger) <- NULL
  if (anyDuplicated(as.character(ledger$fixture_id)) || !setequal(as.character(ledger$fixture_id), as.character(validation$graph$fixtures$fixture_id))) stop("UCL forecast ledger coverage is not one row per fixture", call. = FALSE)
  fixture_authority <- isTRUE(validation$graph$fixture_authority) || is_fixture
  result <- list(
    status = if (fixture_authority) "fixture_mechanics" else authority$status,
    ledger = ledger, forecast_rows = ledger, authority = authority,
    original_parent_reason = authority$original_parent_reason,
    authority_mode = if (fixture_authority) "fixture" else "production",
    fixture_authority = fixture_authority, production_eligible = FALSE,
    selector_authorized = FALSE, source_bundle_id = validation$graph$source_bundle_id,
    graph_sha256 = validation$graph$graph_sha256
  )
  class(result) <- c("ucl_forecast_ledger", "list")
  result
}
