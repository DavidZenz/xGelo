# Current UCL inference uses a frozen approved club fit and a separately
# identified current rating replay. It never rewrites the fit's training parents.
phase19_live_club_abort <- function(reason_code, message) {
  stop(structure(list(message = message, call = NULL, reason_code = reason_code),
    class = c("phase19_live_club_error", "error", "condition")))
}

phase19_live_club_absence <- function(reason_code, reason) {
  list(schema_version = "phase19-live-club-forecasts-v1", status = "unavailable",
    reason_code = as.character(reason_code), reason = as.character(reason),
    forecast_domain = "club", predictions = data.frame(), unavailable = data.frame(),
    score_distributions = data.frame(), metadata = list())
}

phase19_live_club_hash <- function(value) digest::digest(value, algo = "sha256", serialize = TRUE)

# Internal inference boundary; production callers enter through the fixed resolver
# below. Diagnostic callers enter through the explicitly named fixture API.
.phase19_live_club_predict <- function(fit, calibrator, training, current, replay,
    matches, information_cutoff_utc, release_id, model_sha256, calibrator_sha256,
    authority_mode, primary_probability_view = "calibrated_1x2") {
  phase19_validate_club_goal_fit(fit)
  phase19_validate_club_calibrator(calibrator, require_fitted = TRUE)
  phase19_validate_club_training_snapshot(training, authority_mode)
  phase19_validate_current_ucl_club_snapshot(current, authority_mode)
  if (!identical(fit$forecast_domain, "club") ||
      !identical(calibrator$forecast_domain, "club") ||
      !identical(fit$authority_mode, authority_mode) ||
      !identical(calibrator$authority_mode, authority_mode) ||
      !identical(fit$model_family, "negative_binomial") ||
      !identical(fit$model_id, calibrator$candidate_id)) {
    phase19_live_club_abort("model_domain_mismatch", "Live forecasts require one matching club NB fit and calibrator authority.")
  }
  if (!primary_probability_view %in% c("raw_1x2", "calibrated_1x2"))
    phase19_live_club_abort("invalid_probability_view", "The approved release must freeze its raw or calibrated primary probability view.")
  cutoff <- phase19_club_rating_parse_utc(information_cutoff_utc, "information_cutoff_utc")
  if (as.character(fit$cutoff_utc) > information_cutoff_utc ||
      as.character(calibrator$calibration_cutoff_exclusive) > information_cutoff_utc) {
    phase19_live_club_abort("model_after_information_cutoff", "The fit and calibration evidence must precede the live information cutoff.")
  }
  if (!is.list(replay) || !identical(replay$status, "ready")) {
    return(phase19_live_club_absence("rating_coverage_unavailable",
      "The accepted history does not support the current club rating roster."))
  }
  phase19_validate_club_rating_replay(replay, training, current)
  if (replay$cutoff_utc > information_cutoff_utc ||
      !identical(as.character(replay$parameter_sha256), as.character(fit$rating_parameter_sha256))) {
    phase19_live_club_abort("rating_parent_mismatch", "Current rating evidence must use the frozen model parameters and prior information.")
  }
  required <- c("provider_match_id", "kickoff_utc", "home_club_id", "away_club_id", "status", "stage")
  if (!is.data.frame(matches) || !all(required %in% names(matches)) ||
      anyDuplicated(as.character(matches$provider_match_id)) ||
      anyNA(matches[required]) || any(!nzchar(as.character(matches$provider_match_id)))) {
    phase19_live_club_abort("invalid_live_fixtures", "Accepted live fixtures require unique identities, teams, stages, status and kickoff.")
  }
  if ("forecast_domain" %in% names(matches) && any(matches$forecast_domain != "club"))
    phase19_live_club_abort("fixture_domain_mismatch", "National fixtures cannot enter club inference.")
  kickoff <- phase19_club_rating_parse_utc(matches$kickoff_utc, "fixture kickoff")
  completed <- as.character(matches$status) == "FINISHED"
  pending <- !completed
  reason <- rep("", nrow(matches))
  reason[pending & kickoff <= cutoff] <- "kickoff_not_after_information_cutoff"
  reason[pending & matches$stage != "LEAGUE_STAGE"] <- "unsupported_competition_stage"
  reason[pending & !matches$status %in% c("SCHEDULED", "TIMED")] <- "fixture_not_scheduled"
  if ("neutral_venue" %in% names(matches)) {
    reason[pending & (is.na(matches$neutral_venue) | matches$neutral_venue)] <- "unsupported_neutral_venue"
  }
  supported <- replay$state$clubs$club_id[replay$state$clubs$prior_match_count > 0L]
  unknown <- !matches$home_club_id %in% supported | !matches$away_club_id %in% supported
  reason[pending & unknown] <- "historical_club_coverage_unavailable"
  unavailable <- data.frame(fixture_id = as.character(matches$provider_match_id[pending & nzchar(reason)]),
    reason_code = reason[pending & nzchar(reason)], stringsAsFactors = FALSE)
  eligible <- matches[pending & !nzchar(reason), , drop = FALSE]
  eligible <- eligible[order(eligible$kickoff_utc, eligible$provider_match_id), , drop = FALSE]
  predictions <- grids <- list()
  state <- replay$state
  for (instant in unique(as.character(eligible$kickoff_utc))) {
    batch <- eligible[eligible$kickoff_utc == instant, , drop = FALSE]
    input <- data.frame(fixture_id = as.character(batch$provider_match_id),
      forecast_domain = "club", authority_mode = authority_mode,
      boundary_id = paste0("kickoff:", instant), kickoff_utc = instant,
      home_club_id = as.character(batch$home_club_id), away_club_id = as.character(batch$away_club_id),
      status = "scheduled", counts_for_model = FALSE,
      regulation_home_goals = NA_integer_, regulation_away_goals = NA_integer_,
      stringsAsFactors = FALSE)
    rated <- phase19_forecast_club_rating_batch(state, input)
    state <- rated$state
    means <- phase19_club_goal_nb_means(fit, rated$predictions)
    for (i in seq_len(nrow(rated$predictions))) {
      rating <- rated$predictions[i, , drop = FALSE]
      grid <- phase19_club_goal_distribution(fit, rating$fixture_id, means$home[i], means$away[i])
      market <- phase19_club_goal_grid_markets(grid)
      calibrated <- phase19_club_temperature_transform(unlist(market[c("p_home", "p_draw", "p_away")]), calibrator$temperature)
      primary <- if (identical(primary_probability_view, "calibrated_1x2")) calibrated else unlist(market[c("p_home", "p_draw", "p_away")])
      row <- data.frame(fixture_id = rating$fixture_id, kickoff_utc = instant,
        home_club_id = rating$home_club_id, away_club_id = rating$away_club_id,
        forecast_domain = "club", authority_mode = authority_mode,
        fixture_authority = identical(authority_mode, "fixture"),
        information_cutoff_utc = information_cutoff_utc,
        rating_cutoff_utc = replay$cutoff_utc,
        rating_last_evidence_available_at_utc = rating$max_prior_evidence_available_at_utc,
        model_cutoff_utc = fit$cutoff_utc,
        calibration_cutoff_utc = calibrator$calibration_cutoff_exclusive,
        model_release_id = release_id, model_id = fit$model_id,
        p_home = primary[1], p_draw = primary[2], p_away = primary[3],
        calibrated_p_home = calibrated[1], calibrated_p_draw = calibrated[2], calibrated_p_away = calibrated[3],
        raw_p_home = market$p_home, raw_p_draw = market$p_draw, raw_p_away = market$p_away,
        expected_home_goals = market$expected_home_goals, expected_away_goals = market$expected_away_goals,
        likely_home_goals = market$likely_home_goals, likely_away_goals = market$likely_away_goals,
        probability_view = primary_probability_view, score_probability_view = "raw_negative_binomial",
        venue_semantics = "accepted_league_phase_home_designation",
        model_sha256 = model_sha256, calibrator_sha256 = calibrator_sha256,
        fit_sha256 = fit$fit_sha256, rating_replay_sha256 = replay$replay_digest_sha256,
        rating_state_sha256 = rating$pre_batch_state_sha256,
        training_snapshot_sha256 = training$snapshot_sha256,
        model_training_snapshot_sha256 = fit$training_snapshot_sha256,
        current_snapshot_sha256 = current$snapshot_sha256,
        source_bundle_sha256 = current$bundle_sha256,
        score_distribution_sha256 = phase19_live_club_hash(grid),
        stringsAsFactors = FALSE, row.names = NULL)
      row$prediction_sha256 <- phase18_hash_row_v2(row, schema_tag = "phase19-live-club-prediction-v1")
      predictions[[length(predictions) + 1L]] <- row
      grids[[length(grids) + 1L]] <- grid
    }
  }
  result <- list(schema_version = "phase19-live-club-forecasts-v1",
    status = if (length(predictions)) "available" else "unavailable",
    reason_code = if (length(predictions)) "" else "no_supported_upcoming_fixtures",
    reason = if (length(predictions)) "" else "No supported unplayed fixture has kickoff after the information cutoff.",
    forecast_domain = "club", predictions = if (length(predictions)) do.call(rbind, predictions) else data.frame(),
    unavailable = unavailable, score_distributions = if (length(grids)) do.call(rbind, grids) else data.frame(),
    metadata = list(model_release_id = release_id, model_sha256 = model_sha256,
      calibrator_sha256 = calibrator_sha256, information_cutoff_utc = information_cutoff_utc,
      rating_cutoff_utc = replay$cutoff_utc,
      rating_last_evidence_available_at_utc = replay$state$last_evidence_available_at_utc,
      fit_sha256 = fit$fit_sha256,
      current_snapshot_sha256 = current$snapshot_sha256, source_bundle_sha256 = current$bundle_sha256,
      training_snapshot_sha256 = training$snapshot_sha256, rating_replay_sha256 = replay$replay_digest_sha256,
      probability_view = primary_probability_view, score_probability_view = "raw_negative_binomial"))
  result$forecast_sha256 <- phase19_live_club_hash(result)
  phase19_validate_live_club_forecasts(result)
  result
}

phase19_validate_live_club_forecasts <- function(result) {
  if (!identical(result$schema_version, "phase19-live-club-forecasts-v1") ||
      !identical(result$forecast_domain, "club"))
    phase19_live_club_abort("invalid_live_forecasts", "Invalid live club forecast envelope.")
  rows <- result$predictions
  if (nrow(rows)) {
    if (anyDuplicated(rows$fixture_id) || any(rows$forecast_domain != "club") ||
        any(rows$information_cutoff_utc >= rows$kickoff_utc) ||
        any(rows$rating_cutoff_utc > rows$information_cutoff_utc) ||
        any(rows$model_cutoff_utc > rows$information_cutoff_utc) ||
        any(rows$calibration_cutoff_utc > rows$information_cutoff_utc))
      phase19_live_club_abort("invalid_live_cutoff", "Every live prediction must precede kickoff and follow all evidence cutoffs.")
    for (i in seq_len(nrow(rows))) {
      row <- rows[i, , drop = FALSE]
      rownames(row) <- NULL
      validate_probability_vector(as.numeric(row[c("p_home", "p_draw", "p_away")]), tolerance = 1e-10)
      grid <- result$score_distributions[result$score_distributions$fixture_id == row$fixture_id, , drop = FALSE]
      rownames(grid) <- NULL
      validate_scoreline_distribution(grid, tolerance = 1e-10, support_max = 40L, require_full_rectangle = TRUE)
      market <- phase19_club_goal_grid_markets(grid)
      expected <- unlist(market[c("p_home", "p_draw", "p_away", "expected_home_goals", "expected_away_goals", "likely_home_goals", "likely_away_goals")])
      actual <- unlist(row[c("raw_p_home", "raw_p_draw", "raw_p_away", "expected_home_goals", "expected_away_goals", "likely_home_goals", "likely_away_goals")])
      if (any(abs(expected - actual) > 1e-10) ||
          !identical(row$score_distribution_sha256[[1]], phase19_live_club_hash(grid)))
        phase19_live_club_abort("invalid_live_distribution", "Displayed goal estimates must derive from the retained score grid.")
      stored <- row$prediction_sha256[[1]]
      row$prediction_sha256 <- NULL
      if (!identical(stored, phase18_hash_row_v2(row, schema_tag = "phase19-live-club-prediction-v1")))
        phase19_live_club_abort("invalid_live_prediction_hash", "Live prediction identity changed.")
    }
  }
  if (!is.null(result$forecast_sha256)) {
    stored <- result$forecast_sha256
    result$forecast_sha256 <- NULL
    if (!identical(stored, phase19_live_club_hash(result)))
      phase19_live_club_abort("invalid_live_forecast_hash", "Live forecast envelope identity changed.")
  }
  invisible(TRUE)
}

# Isolated diagnostic API: no production selector or publication is reachable.
phase19_forecast_fixture_ucl <- function(fit, calibrator, training, current, replay,
    matches, information_cutoff_utc) {
  .phase19_live_club_predict(fit, calibrator, training, current, replay, matches,
    information_cutoff_utc, "diagnostic-fixture-only", fit$model_sha256,
    calibrator$calibrator_sha256, "fixture")
}

# Production authority is resolved afresh from the fixed immutable release tree.
phase19_forecast_current_ucl <- function(information_cutoff_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")) {
  tryCatch({
    release <- phase19_resolve_production_club_release()
    training <- phase19_load_club_training_snapshot()
    current <- phase19_load_current_ucl_club_snapshot()
    if (!identical(training$status, "ready") || !identical(current$status, "ready"))
      return(phase19_live_club_absence("accepted_club_inputs_unavailable", "Accepted historical training and current club snapshots are required."))
    fit <- release$model
    parameters <- if (is.list(fit$rating_parameters)) fit$rating_parameters else release$rating_parameters
    if (!is.list(parameters))
      return(phase19_live_club_absence("release_rating_parameters_missing", "The approved release does not retain its selected Elo parameters."))
    phase19_validate_club_rating_parameters(parameters)
    replay_cutoff <- min(information_cutoff_utc, as.character(training$cutoff_utc))
    replay <- phase19_replay_club_ratings(training, current, parameters, replay_cutoff)
    source <- phase18_read_ucl_refresh_current(file.path(.phase19_club_project_root, "data/competition/accepted"),
      file.path(.phase19_club_project_root, "data/competition/registries"))
    phase18_validate_ucl_refresh_current(source)
    if (!identical(as.character(source$accepted$bundle$bundle_sha256[[1]]), as.character(current$bundle_sha256)))
      phase19_live_club_abort("source_parent_changed", "The accepted live source changed during inference; retry with one generation.")
    .phase19_live_club_predict(fit, release$calibrator, training, current, replay,
      source$accepted$tables$matches, information_cutoff_utc, release$release_id,
      release$model_contract$model_sha256, release$model_contract$calibrator_sha256, "production",
      release$model_contract$primary_probability_view)
  }, phase19_club_production_error = function(error) phase19_live_club_absence(error$reason_code, conditionMessage(error)),
     phase19_club_release_error = function(error) phase19_live_club_absence(error$reason_code, conditionMessage(error)),
     phase19_club_contract_error = function(error) phase19_live_club_absence(error$reason_code, conditionMessage(error)),
     phase19_live_club_error = function(error) phase19_live_club_absence(error$reason_code, conditionMessage(error)),
     phase19_club_goal_model_error = function(error) phase19_live_club_absence(error$reason_code, conditionMessage(error)),
     phase19_club_calibration_error = function(error) phase19_live_club_absence(error$reason_code, conditionMessage(error)))
}
