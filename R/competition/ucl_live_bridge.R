# Receipt-backed Phase 18 facts -> Phase 20 fixture schema and mixed ledger.
# This adapter grants no tournament publication authority. In particular, settled
# results never acquire retrospective pre-match predictions from a newer model.

.ucl_live_bridge_time <- function(value) {
  text <- as.character(value)
  valid <- !is.na(text) & grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$", text)
  result <- rep(NA_real_, length(text))
  result[valid] <- as.numeric(as.POSIXct(text[valid], format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  result
}

.ucl_live_bridge_forecast_authority <- function(forecasts, source_hash) {
  absent <- function(reason, quality = "unavailable") list(ready = FALSE, reason = reason, quality = quality, rows = data.frame())
  if (is.null(forecasts)) return(absent("live_forecasts_unavailable"))
  if (!exists("phase19_validate_live_club_forecasts", mode = "function")) return(absent("live_forecast_validator_unavailable"))
  phase19_validate_live_club_forecasts(forecasts)
  if (!identical(forecasts$status, "available") || !nrow(forecasts$predictions)) return(absent("live_forecasts_unavailable"))
  if (!exists("phase19_resolve_production_club_release", mode = "function")) return(absent("approved_release_resolver_unavailable"))
  # The fixed selector is independently resolved; caller metadata cannot promote
  # a fixture/diagnostic envelope into production authority.
  release <- tryCatch(phase19_resolve_production_club_release(), error = function(e) NULL)
  contract <- if (is.list(release)) release$model_contract else NULL
  if (is.null(contract) || !isTRUE(contract$production_eligible) || isTRUE(contract$fixture_authority) ||
      !identical(contract$authority_mode, "production")) return(absent("approved_release_unavailable"))
  rows <- forecasts$predictions
  expected <- list(model_release_id = as.character(contract$release_id),
    model_sha256 = as.character(contract$model_sha256),
    calibrator_sha256 = as.character(contract$calibrator_sha256),
    model_id = as.character(release$model$model_id), probability_view = as.character(contract$primary_probability_view),
    source_bundle_sha256 = source_hash, authority_mode = "production")
  for (field in names(expected)) {
    if (length(expected[[field]]) != 1L || is.na(expected[[field]]) || !field %in% names(rows) ||
        anyNA(rows[[field]]) || any(as.character(rows[[field]]) != expected[[field]]))
      stop("Live bridge forecast lineage differs from the fixed approved release/source", call. = FALSE)
  }
  if (anyNA(rows$fixture_authority) || any(rows$fixture_authority) ||
      !identical(as.character(forecasts$metadata$source_bundle_sha256), source_hash))
    stop("Live bridge requires production forecasts for this accepted source", call. = FALSE)
  for (i in seq_len(nrow(rows))) {
    raw <- as.numeric(rows[i, c("raw_p_home", "raw_p_draw", "raw_p_away")])
    primary <- if (identical(expected$probability_view, "calibrated_1x2"))
      phase19_club_temperature_transform(raw, release$calibrator$temperature) else raw
    if (any(abs(primary - as.numeric(rows[i, c("p_home", "p_draw", "p_away")])) > 1e-10))
      stop("Live bridge probabilities differ from the approved probability view", call. = FALSE)
  }
  list(ready = TRUE, reason = "", rows = rows,
    quality = if (identical(expected$model_id, "club_venue_nb")) "venue_baseline_only" else "approved_team_strength_model")
}

ucl_live_build_bridge <- function(current, forecasts = NULL,
    now_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), allow_venue_baseline = FALSE) {
  if (!exists("phase18_validate_ucl_refresh_current", mode = "function") ||
      !exists("phase18_validate_ucl_source_bundle", mode = "function"))
    stop("Live bridge requires receipt-backed source validators", call. = FALSE)
  if (!is.list(current) || !identical(as.character(current$pointer$accepted_status), "accepted") || !is.list(current$accepted))
    stop("Live bridge requires an accepted current UCL source", call. = FALSE)
  phase18_validate_ucl_refresh_current(current)
  accepted <- current$accepted
  phase18_validate_ucl_source_bundle(accepted)
  if (!identical(as.character(accepted$authority$authority_type[[1L]]), "provider_acceptance") ||
      !isTRUE(accepted$authority$provider_automation_enabled[[1L]]))
    stop("Live bridge requires genuine accepted provider authority", call. = FALSE)
  now <- .ucl_live_bridge_time(now_utc)
  if (length(now) != 1L || !is.finite(now)) stop("Live bridge requires a canonical UTC cutoff", call. = FALSE)
  matches <- accepted$tables$matches
  matches <- matches[order(matches$kickoff_utc, matches$provider_match_id), , drop = FALSE]
  if (any(matches$stage != "LEAGUE_STAGE")) stop("Live bridge supports league-phase facts only", call. = FALSE)
  kickoff <- .ucl_live_bridge_time(matches$kickoff_utc)
  if (any(!is.finite(kickoff))) stop("Live bridge requires canonical UTC kickoffs", call. = FALSE)
  bundle_id <- as.character(accepted$bundle$bundle_id[[1L]])
  bundle_hash <- as.character(accepted$bundle$bundle_sha256[[1L]])
  match_artifact <- accepted$artifacts[accepted$artifacts$resource_type == "matches", , drop = FALSE]
  if (nrow(match_artifact) != 1L) stop("Live bridge requires one accepted matches artifact", call. = FALSE)
  status_map <- c(SCHEDULED = "scheduled", TIMED = "scheduled", IN_PLAY = "in_progress", PAUSED = "in_progress",
    FINISHED = "completed", AWARDED = "completed", POSTPONED = "postponed", CANCELLED = "abandoned", SUSPENDED = "abandoned")
  status <- unname(status_map[as.character(matches$status)])
  if (anyNA(status)) stop("Live bridge refuses an unmapped provider status", call. = FALSE)
  completed <- status == "completed"
  regulation <- as.character(matches$status) == "FINISHED"
  upcoming <- !completed & kickoff > now & matches$status %in% c("SCHEDULED", "TIMED")
  pending <- !completed & kickoff <= now & matches$status %in% c("SCHEDULED", "TIMED", "IN_PLAY", "PAUSED")
  fixtures <- data.frame(
    edition_id = as.character(matches$edition_id), fixture_id = as.character(matches$provider_match_id),
    matchday = as.integer(matches$matchday), home_club_id = as.character(matches$home_club_id), away_club_id = as.character(matches$away_club_id),
    venue_id = paste0("accepted-home-designation:", matches$home_club_id),
    venue_semantics = "accepted_league_phase_home_designation_not_stadium",
    kickoff_utc = as.character(matches$kickoff_utc), kickoff_confirmed = matches$status != "SCHEDULED",
    # Phase 20's field is the confirmed scheduled instant, not confirmation time.
    confirmed_kickoff_at_utc = as.character(matches$kickoff_utc),
    source_artifact_id = as.character(match_artifact$artifact_id[[1L]]), source_row_key = as.character(matches$provider_match_id),
    source_lineage_id = paste0(match_artifact$artifact_id[[1L]], ":", matches$provider_match_id), source_bundle_id = bundle_id,
    source_row_sha256 = as.character(matches$row_sha256), source_status = status, match_status = status,
    completion_method = ifelse(regulation, "regulation", ifelse(completed, "awarded", "not_completed")),
    regulation_home_goals = ifelse(regulation, matches$home_score, NA_integer_),
    regulation_away_goals = ifelse(regulation, matches$away_score, NA_integer_),
    final_home_goals = ifelse(completed, matches$home_score, NA_integer_), final_away_goals = ifelse(completed, matches$away_score, NA_integer_),
    shootout_home_goals = NA_integer_, shootout_away_goals = NA_integer_, counts_for_standings = completed,
    winner_club_id = ifelse(completed & !is.na(matches$home_score) & !is.na(matches$away_score),
      ifelse(matches$home_score > matches$away_score, as.character(matches$home_club_id),
        ifelse(matches$away_score > matches$home_score, as.character(matches$away_club_id), NA_character_)), NA_character_),
    provider_status = as.character(matches$status), result_confirmation_pending = pending,
    stringsAsFactors = FALSE)
  graph <- list(edition_id = "ucl_2026_27", clubs = accepted$tables$clubs, fixtures = fixtures,
    source_bundle_id = bundle_id, source_bundle_sha256 = bundle_hash, source_bundle_evidence = accepted)
  graph_validation <- if (exists("ucl_validate_schedule", mode = "function"))
    ucl_validate_schedule(graph, require_authority = TRUE) else list(status = "blocked", reason_code = "schedule_validator_unavailable")
  forecast <- .ucl_live_bridge_forecast_authority(forecasts, bundle_hash)
  predictions <- forecast$rows
  if (nrow(predictions)) {
    index <- match(predictions$fixture_id, fixtures$fixture_id)
    if (anyNA(index) || any(predictions$home_club_id != fixtures$home_club_id[index]) ||
        any(predictions$away_club_id != fixtures$away_club_id[index]) || any(predictions$kickoff_utc != fixtures$kickoff_utc[index]))
      stop("Live bridge prediction identity differs from accepted fixtures", call. = FALSE)
  }
  baseline_blocked <- identical(forecast$quality, "venue_baseline_only") && !isTRUE(allow_venue_baseline)
  source_age <- now - .ucl_live_bridge_time(accepted$bundle$created_at_utc[[1L]])
  stale <- !is.finite(source_age) || source_age < -3600 || source_age > 48 * 3600
  eligible <- upcoming & forecast$ready & !baseline_blocked & !stale
  ledger <- fixtures[, c("edition_id", "fixture_id", "home_club_id", "away_club_id", "kickoff_utc", "source_bundle_id")]
  ledger$ledger_kind <- ifelse(completed, "outcome", ifelse(pending, "result_pending", "suppressed"))
  ledger$forecast_status <- "suppressed"
  ledger$suppression_reason <- ifelse(completed, "completed_without_retrospective_forecast", ifelse(pending,
    "kickoff_not_after_current_cutoff", ifelse(!upcoming, "fixture_not_scheduled", if (stale) "stale_current_source" else
      if (baseline_blocked) "venue_baseline_not_team_strength_forecast" else forecast$reason)))
  for (field in c("model_release_id", "model_sha256", "calibrator_sha256", "feature_cutoff_utc", "likely_score", "score_distribution_sha256")) ledger[[field]] <- NA_character_
  for (field in c("prob_home", "prob_draw", "prob_away", "xg_home", "xg_away")) ledger[[field]] <- NA_real_
  ledger$regulation_home_goals <- fixtures$regulation_home_goals
  ledger$regulation_away_goals <- fixtures$regulation_away_goals
  for (i in which(eligible)) {
    row <- predictions[predictions$fixture_id == fixtures$fixture_id[[i]], , drop = FALSE]
    if (nrow(row) != 1L) { ledger$suppression_reason[[i]] <- "supported_live_forecast_missing"; next }
    ledger$ledger_kind[[i]] <- "forecast"
    ledger$forecast_status[[i]] <- "available"
    ledger$suppression_reason[[i]] <- NA_character_
    for (field in c("model_release_id", "model_sha256", "calibrator_sha256", "score_distribution_sha256")) ledger[[field]][[i]] <- as.character(row[[field]][[1L]])
    ledger$feature_cutoff_utc[[i]] <- as.character(row$information_cutoff_utc[[1L]])
    ledger$likely_score[[i]] <- paste(row$likely_home_goals[[1L]], row$likely_away_goals[[1L]], sep = "-")
    for (pair in list(c("prob_home", "p_home"), c("prob_draw", "p_draw"), c("prob_away", "p_away"),
        c("xg_home", "expected_home_goals"), c("xg_away", "expected_away_goals"))) ledger[[pair[[1L]]]][[i]] <- as.numeric(row[[pair[[2L]]]][[1L]])
  }
  ledger$row_sha256 <- vapply(seq_len(nrow(ledger)), function(i)
    phase18_hash_row_v2(ledger[i, , drop = FALSE], schema_tag = "ucl-live-mixed-ledger-v1"), character(1))
  reasons <- c(if (!identical(graph_validation$status, "ready")) paste0("schedule_", graph_validation$reason_code),
    if (stale) "stale_current_source", if (any(pending)) "past_kickoff_results_pending",
    if (!forecast$ready) forecast$reason,
    if (identical(forecast$quality, "venue_baseline_only")) "team_strength_model_not_promoted",
    if (any(upcoming & ledger$forecast_status != "available")) "future_forecast_coverage_incomplete")
  rules <- if (exists(".ucl_rule_contract", mode = "function")) tryCatch(.ucl_rule_contract(), error = function(e) NULL) else NULL
  if (is.null(rules)) reasons <- c(reasons, "pinned_rules_unavailable") else {
    draw <- rules$evidence[rules$evidence$document_id == "draw_procedure_2026_27", , drop = FALSE]
    if (nrow(draw) != 1L || !isTRUE(draw$accepted[[1L]]) || !isTRUE(draw$complete[[1L]])) reasons <- c(reasons, "missing_edition_draw_procedure")
  }
  reasons <- unique(c(reasons, "mixed_ledger_simulation_integration_pending", "production_outcome_writer_not_integrated"))
  list(schema_version = "ucl-live-bridge-v1", status = "source_mapped_tournaments_incomplete",
    fixtures = fixtures, graph = if (identical(graph_validation$status, "ready")) graph_validation$graph else graph,
    graph_validation = graph_validation, ledger = ledger, forecast_rows = ledger,
    readiness = list(tournament_eligible = FALSE, blocked_reason_codes = reasons, forecast_quality = forecast$quality,
      source_freshness = if (stale) "stale" else "fresh", future_fixture_count = sum(upcoming),
      available_forecast_count = sum(ledger$forecast_status == "available"), completed_result_count = sum(completed),
      result_pending_count = sum(pending)), information_cutoff_utc = now_utc, source_bundle_sha256 = bundle_hash,
    model_lineage = if (forecast$ready) list(model_release_id = unique(as.character(predictions$model_release_id)),
      model_sha256 = unique(as.character(predictions$model_sha256)), calibrator_sha256 = unique(as.character(predictions$calibrator_sha256)),
      primary_probability_view = unique(as.character(predictions$probability_view))) else NULL,
    production_eligible = FALSE, authority_mode = "bridge_only")
}
