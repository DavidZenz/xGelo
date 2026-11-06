# Proposed CL future-matchup contract; no fit, policy or source authority is
# changed here. Production factories resolve fixed parents and fail closed.
.ucl_future_authority <- local(list(token = new.env(parent = emptyenv()),contexts=new.env(parent=emptyenv())))
.ucl_future_version <- "ucl-future-matchup-nb-v1"

.ucl_future_abort <- function(reason, message = reason) stop(structure(
  list(message = message, call = NULL, reason_code = reason), class = c("ucl_future_error", "error", "condition")))
.ucl_future_block <- function(reason) list(status = "blocked", reason_code = reason, production_eligible = FALSE)
.ucl_future_time <- function(x) {
  text <- as.character(x)
  if (length(text) != 1L || is.na(text) || !grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$", text)) return(NA_real_)
  as.numeric(as.POSIXct(text, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
}
.ucl_future_hash <- function(x, domain) phase18_hash_sequence_v2(
  list(phase18_v2_hex(serialize(x, NULL, version = 3L))), domain,
  names = "canonical_contract_payload", types = "character")

.ucl_future_payload <- function(context) unclass(context)[c("schema_version", "forecast_domain", "authority_mode", "fixture_authority",
  "model_release_id", "model_sha256", "calibrator_sha256", "source_bundle_sha256", "rating_state_sha256",
  "coefficients", "theta", "home_advantage", "temperature", "primary_probability_view", "information_cutoff_utc",
  "source_available_at_utc", "ratings", "rating_time_policy", "future_policy_sha256", "joint_policy_sha256", "future_tie_policy", "club_coefficients")]

.ucl_future_context <- function(coefficients, theta, ratings, home_advantage, temperature, primary_probability_view,
    information_cutoff_utc, source_available_at_utc, lineage, authority_mode = "fixture", rating_at = NULL,
    future_tie_policy = "retain_unresolved_intervals", club_coefficients = NULL) {
  required <- c("(Intercept)", "elo_difference_for_team", "venue_rolehome")
  if (!is.numeric(coefficients) || !setequal(names(coefficients), required) || any(!is.finite(coefficients)))
    .ucl_future_abort("unsupported_frozen_model_formula")
  if (length(theta) != 1L || !is.finite(theta) || theta <= 0 || length(temperature) != 1L || !is.finite(temperature) || temperature <= 0 ||
      length(home_advantage) != 1L || !is.finite(home_advantage) || home_advantage < 0) .ucl_future_abort("invalid_frozen_model_parameters")
  if (!is.numeric(ratings) || length(ratings) < 2L || is.null(names(ratings)) || anyNA(names(ratings)) ||
      any(!nzchar(names(ratings))) || anyDuplicated(names(ratings)) || any(!is.finite(ratings))) .ucl_future_abort("rating_roster_invalid")
  cutoff <- .ucl_future_time(information_cutoff_utc); available <- .ucl_future_time(source_available_at_utc)
  if (!is.finite(cutoff) || !is.finite(available) || available > cutoff) .ucl_future_abort("source_after_information_cutoff")
  if (!primary_probability_view %in% c("raw_1x2", "calibrated_1x2")) .ucl_future_abort("invalid_primary_probability_view")
  if (!future_tie_policy %in% c("retain_unresolved_intervals", "exchangeable_final_disciplinary_weak_order_v1")) .ucl_future_abort("unsupported_future_tie_policy")
  if (!is.null(club_coefficients)) {
    if (!is.numeric(club_coefficients) || !setequal(names(club_coefficients), names(ratings)) || any(!is.finite(club_coefficients) | club_coefficients < 0)) .ucl_future_abort("known_coefficient_coverage_incomplete")
    club_coefficients <- club_coefficients[order(names(club_coefficients), method = "radix")]
  }
  if (!all(c("model_release_id", "model_sha256", "calibrator_sha256", "source_bundle_sha256", "rating_state_sha256",
      "future_policy_sha256", "joint_policy_sha256") %in% names(lineage))) .ucl_future_abort("lineage_incomplete")
  for (field in setdiff(names(lineage), "model_release_id")) if (!grepl("^[0-9a-f]{64}$", as.character(lineage[[field]]))) .ucl_future_abort("lineage_hash_invalid")
  ratings <- ratings[order(names(ratings), method = "radix")]
  context <- c(list(schema_version = .ucl_future_version, forecast_domain = "club", authority_mode = authority_mode,
    fixture_authority = !identical(authority_mode, "production"), coefficients = coefficients[required], theta = as.numeric(theta),
    home_advantage = as.numeric(home_advantage), temperature = as.numeric(temperature), primary_probability_view = primary_probability_view,
    information_cutoff_utc = information_cutoff_utc, source_available_at_utc = source_available_at_utc, ratings = ratings, future_tie_policy = future_tie_policy, club_coefficients = club_coefficients,
    rating_time_policy = if (is.null(rating_at)) "fixture_frozen_ratings" else "accepted_state_decay_to_slot_without_simulated_updates"), lineage)
  context$context_sha256 <- .ucl_future_hash(.ucl_future_payload(context), "ucl-future-context-v1")
  context$.rating_at <- if (is.null(rating_at)) function(instant) list(ratings = ratings, state_sha256 = lineage$rating_state_sha256) else rating_at
  context$.cache <- new.env(parent = emptyenv())
  class(context) <- c("ucl_future_matchup_context", "list")
  context
}

.ucl_future_runtime <- function(context) {
  if (isTRUE(context$fixture_authority)) return(list(cache=context$.cache,rating_at=context$.rating_at))
  if (!identical(context$.authority_token,.ucl_future_authority$token) ||
      !exists(context$context_sha256,envir=.ucl_future_authority$contexts,inherits=FALSE)) .ucl_future_abort("production_context_runtime_missing")
  get(context$context_sha256,envir=.ucl_future_authority$contexts,inherits=FALSE)
}

ucl_future_fixture_context <- function(coefficients, theta, ratings, home_advantage = 60, temperature = 1,
    primary_probability_view = "raw_1x2", information_cutoff_utc = "2026-11-05T19:00:00Z", future_tie_policy = "retain_unresolved_intervals", club_coefficients = NULL) {
  hash <- .ucl_future_hash(list(coefficients, theta, ratings), "ucl-fixture-context-parents-v1")
  lineage <- list(model_release_id = "fixture-only-not-an-approved-release", model_sha256 = hash, calibrator_sha256 = hash,
    source_bundle_sha256 = hash, rating_state_sha256 = hash, future_policy_sha256 = hash, joint_policy_sha256 = hash)
  .ucl_future_context(coefficients, theta, ratings, home_advantage, temperature, primary_probability_view,
    information_cutoff_utc, information_cutoff_utc, lineage, future_tie_policy = future_tie_policy, club_coefficients = club_coefficients)
}

ucl_future_fixture_slot <- function(slot_id, stage_id, leg_number, kickoff_lower_bound_utc, neutral = FALSE,
    venue_id = "fixture-venue", evidence_available_at_utc = "2026-11-05T19:00:00Z") {
  slot <- list(slot_id = as.character(slot_id), stage_id = as.character(stage_id), leg_number = as.integer(leg_number),
    kickoff_lower_bound_utc = kickoff_lower_bound_utc, neutral = isTRUE(neutral), venue_id = venue_id,
    schedule_semantics = "potential_round_slot_lower_bound_not_official_fixture", evidence_available_at_utc = evidence_available_at_utc,
    schedule_evidence_sha256 = .ucl_future_hash(list(slot_id, stage_id, kickoff_lower_bound_utc), "ucl-fixture-calendar-v1"), fixture_authority = TRUE)
  slot$slot_sha256 <- .ucl_future_hash(slot, "ucl-future-slot-v1")
  class(slot) <- c("ucl_future_slot", "list")
  slot
}

.ucl_future_validate <- function(context, home, away, slot) {
  if (!inherits(context, "ucl_future_matchup_context") || !identical(context$forecast_domain, "club") ||
      !identical(context$context_sha256, .ucl_future_hash(.ucl_future_payload(context), "ucl-future-context-v1"))) .ucl_future_abort("context_integrity_invalid")
  if (length(home) != 1L || length(away) != 1L || is.na(home) || is.na(away) || identical(home, away) ||
      !all(c(home, away) %in% names(context$ratings))) .ucl_future_abort("dynamic_matchup_identity_invalid")
  if (!inherits(slot, "ucl_future_slot")) .ucl_future_abort("slot_evidence_missing")
  payload <- unclass(slot); payload$slot_sha256 <- NULL; payload$.authority_token <- NULL
  if (!identical(slot$slot_sha256, .ucl_future_hash(payload, "ucl-future-slot-v1"))) .ucl_future_abort("slot_evidence_changed")
  cutoff <- .ucl_future_time(context$information_cutoff_utc); kickoff <- .ucl_future_time(slot$kickoff_lower_bound_utc)
  published <- .ucl_future_time(slot$evidence_available_at_utc)
  if (!is.finite(kickoff) || !is.finite(published) || published > cutoff || !(cutoff < kickoff)) .ucl_future_abort("matchup_information_cutoff_violation")
  if (!slot$stage_id %in% c("knockout_play_off", "round_of_16", "quarter_final", "semi_final", "final") ||
      !slot$leg_number %in% c(1L, 2L) || is.na(slot$venue_id) || !nzchar(slot$venue_id)) .ucl_future_abort("slot_contract_invalid")
  if (identical(slot$stage_id, "final") && (!isTRUE(slot$neutral) || slot$leg_number != 1L)) .ucl_future_abort("final_requires_single_neutral_slot")
  if (!isTRUE(context$fixture_authority) && (!identical(context$.authority_token, .ucl_future_authority$token) ||
      isTRUE(slot$fixture_authority) || !identical(slot$.authority_token, .ucl_future_authority$token))) .ucl_future_abort("production_matchup_authority_missing")
  invisible(TRUE)
}

.ucl_future_means <- function(context, home, away, slot) {
  rated <- .ucl_future_runtime(context)$rating_at(slot$kickoff_lower_bound_utc)
  ratings <- rated$ratings
  if (!all(c(home, away) %in% names(ratings)) || any(!is.finite(ratings[c(home, away)]))) .ucl_future_abort("dynamic_rating_coverage_missing")
  difference <- as.numeric(ratings[[home]] - ratings[[away]])
  b <- context$coefficients
  if (isTRUE(slot$neutral)) {
    # Explicit log-link neutral intervention: remove the Elo home adjustment
    # and centre the fitted home/away venue coefficient for both participants.
    eta <- b[["(Intercept)"]] + b[["venue_rolehome"]] / 2
    means <- c(home = exp(eta + b[["elo_difference_for_team"]] * difference),
      away = exp(eta - b[["elo_difference_for_team"]] * difference))
  } else {
    difference <- difference + context$home_advantage
    means <- c(home = exp(b[["(Intercept)"]] + b[["elo_difference_for_team"]] * difference + b[["venue_rolehome"]]),
      away = exp(b[["(Intercept)"]] - b[["elo_difference_for_team"]] * difference))
  }
  if (any(!is.finite(means) | means <= 0)) .ucl_future_abort("future_nb_means_invalid")
  list(means = means, rating_state_sha256 = rated$state_sha256, rating_difference = difference)
}

.ucl_future_nb_grid <- function(means, theta, minutes) {
  exposure <- minutes / 90
  goals <- 0:40
  h <- stats::dnbinom(goals, mu = means[[1L]] * exposure, size = theta * exposure)
  a <- stats::dnbinom(goals, mu = means[[2L]] * exposure, size = theta * exposure)
  mass <- outer(h, a); retained <- sum(mass)
  if (!is.finite(retained) || retained <= 0 || 1-retained > 1e-8) .ucl_future_abort("future_score_tail_exceeds_frozen_support")
  grid <- expand.grid(home_goals = goals, away_goals = goals, KEEP.OUT.ATTRS = FALSE)
  grid$probability <- as.vector(mass / retained)
  list(grid = grid, raw_tail_mass = max(0, 1-retained), exposure = exposure,
    theta = theta * exposure, means = means * exposure)
}

ucl_future_forecast_matchup <- function(context, home_club_id, away_club_id, slot, minutes = 90L) {
  .ucl_future_validate(context, home_club_id, away_club_id, slot)
  if (length(minutes) != 1L || !minutes %in% c(30L, 90L)) .ucl_future_abort("unsupported_match_duration")
  identity <- list(context_sha256 = context$context_sha256, home_club_id = home_club_id, away_club_id = away_club_id,
    slot_sha256 = slot$slot_sha256, minutes = as.integer(minutes))
  match_hash <- .ucl_future_hash(identity, "ucl-dynamic-matchup-v1")
  cache <- .ucl_future_runtime(context)$cache
  if (exists(match_hash, envir=cache, inherits=FALSE)) return(get(match_hash,envir=cache,inherits=FALSE))
  rated <- .ucl_future_means(context, home_club_id, away_club_id, slot)
  raw <- .ucl_future_nb_grid(rated$means, context$theta, minutes)
  g <- raw$grid
  raw_1x2 <- c(sum(g$probability[g$home_goals > g$away_goals]), sum(g$probability[g$home_goals == g$away_goals]), sum(g$probability[g$home_goals < g$away_goals]))
  # The accepted calibrator was fitted for 90 minutes, never for extra time.
  view <- if (minutes == 90L) context$primary_probability_view else "raw_1x2"
  primary <- raw_1x2
  if (identical(view, "calibrated_1x2")) {
    z <- log(pmax(primary, 1e-15)) / context$temperature
    primary <- exp(z-max(z)); primary <- primary/sum(primary)
  }
  raw_hash <- .ucl_joint_grid_hash(g, "ucl-future-raw-nb-grid-v1")
  joint <- ucl_tournament_score_view(g, primary, paste0("conditional-", substr(match_hash, 1L, 24L)),
    context$model_release_id, view, raw_hash)
  metadata <- c(identity, list(schema_version = .ucl_future_version, forecast_domain = "club", authority_mode = context$authority_mode,
    fixture_authority = context$fixture_authority, model_release_id = context$model_release_id, model_sha256 = context$model_sha256,
    calibrator_sha256 = context$calibrator_sha256, source_bundle_sha256 = context$source_bundle_sha256,
    information_cutoff_utc = context$information_cutoff_utc, kickoff_lower_bound_utc = slot$kickoff_lower_bound_utc,
    slot_id = slot$slot_id, stage_id = slot$stage_id, leg_number = slot$leg_number, venue_context = slot$venue_id,
    schedule_semantics = slot$schedule_semantics, schedule_evidence_sha256 = slot$schedule_evidence_sha256,
    home_rating_state_sha256 = rated$rating_state_sha256, rating_difference = rated$rating_difference,
    neutral = slot$neutral, neutral_policy = if (slot$neutral) "remove_elo_home_and_centre_venue_log_link_v1" else "released_home_away_roles",
    exposure_policy = if (minutes == 30L) "independent_nb_process_shape_and_mean_one_third_v1" else "released_90_minute_nb",
    matchup_id = paste0("potential:", match_hash), joint_max_1x2_error = joint$provenance$max_1x2_error,
    joint_max_conditional_error = joint$provenance$max_conditional_error,
    primary_probability_view = view, raw_tail_mass = raw$raw_tail_mass,
    raw_grid_sha256 = raw_hash, joint_view_sha256 = joint$provenance$view_sha256))
  metadata$forecast_sha256 <- .ucl_future_hash(metadata, "ucl-dynamic-matchup-forecast-v1")
  result <- list(status = "available", metadata = metadata, raw_grid = g, score_grid = joint$grid,
    primary_1x2 = stats::setNames(primary, c("home", "draw", "away")), raw_1x2 = raw_1x2,
    theoretical_raw_means = raw$means, theoretical_raw_theta = raw$theta, joint_provenance = joint$provenance)
  assign(match_hash,result,envir=cache)
  result
}

ucl_future_policy_status <- function() {
  root <- .ucl_out_project_root()
  package <- file.path(root, "data/competition/rules/reviews/ucl-forecast-policy-v1")
  tryCatch({
    review_path <- file.path(package,"owner_review.json"); manifest <- file.path(package,"review_manifest.csv")
    if (!file.exists(review_path) || !file.exists(manifest)) return(.ucl_future_block("future_matchup_policy_not_approved"))
    review <- jsonlite::read_json(review_path,simplifyVector=TRUE)
    if (!identical(review$schema_version, "ucl-forecast-policy-owner-review-v1") || !identical(review$policy_id, "ucl-conditional-tournament-forecast-v1") || !identical(review$decision, "approved") ||
        !identical(review$approval_basis, "explicit_owner_decision") || length(review$reviewer) != 1L || !nzchar(review$reviewer) ||
        !is.finite(.ucl_future_time(review$reviewed_at_utc)) ||
        !identical(review$review_manifest_sha256, digest::digest(file = manifest, algo = "sha256"))) return(.ucl_future_block("future_matchup_policy_not_approved"))
    rows <- utils::read.csv(manifest, stringsAsFactors = FALSE)
    expected <- c(
      "R/competition/ucl_future_matchups.R",
      "R/competition/ucl_joint_score_view.R",
      "R/competition/ucl_live_bridge.R",
      "R/competition/ucl_live_outcomes.R",
      "R/competition/uefa_champions_league_outcomes.R",
      "R/competition/uefa_champions_league_simulation.R",
      "data/competition/rules/reviews/ucl-forecast-policy-v1/POLICY.md",
      "data/competition/rules/reviews/ucl-forecast-policy-v1/README.md",
      "data/competition/rules/reviews/ucl-forecast-policy-v1/calendar.json",
      "data/competition/rules/reviews/ucl-forecast-policy-v1/club_coefficients_2026.csv",
      "data/competition/rules/reviews/ucl-forecast-policy-v1/coefficient_identity_crosswalk.csv",
      "data/competition/rules/reviews/ucl-forecast-policy-v1/coefficient_reference.md",
      "data/competition/rules/reviews/ucl-forecast-policy-v1/draw_policy.json",
      "data/competition/rules/reviews/ucl-forecast-policy-v1/evidence/accepted_rules_reference.json",
      "data/competition/rules/reviews/ucl-forecast-policy-v1/evidence/annex_b_bracket.png",
      "data/competition/rules/reviews/ucl-forecast-policy-v1/evidence/annex_b_system.jpg",
      "data/competition/rules/reviews/ucl-forecast-policy-v1/evidence/annex_c_calendar.png",
      "data/competition/rules/reviews/ucl-forecast-policy-v1/evidence/source_manifest.json",
      "data/competition/rules/reviews/ucl-forecast-policy-v1/evidence/uefa-coefficients-2026-dom.yml",
      "data/competition/rules/reviews/ucl-forecast-policy-v1/evidence/uefa-coefficients-2026-evidence.json",
      "data/competition/rules/reviews/ucl-forecast-policy-v1/evidence/uefa-coefficients-2026-page.png",
      "data/competition/rules/reviews/ucl-forecast-policy-v1/evidence/uefa-coefficients-2026-page1.json",
      "data/competition/rules/reviews/ucl-forecast-policy-v1/evidence/uefa-coefficients-2026-page2.json",
      "data/competition/rules/reviews/ucl-forecast-policy-v1/evidence/uefa-coefficients-2026-page3.json",
      "data/competition/rules/reviews/ucl-forecast-policy-v1/evidence/uefa-coefficients-2026-page4.json",
      "data/competition/rules/reviews/ucl-forecast-policy-v1/evidence/uefa-coefficients-2026-page5.json",
      "data/competition/rules/reviews/ucl-forecast-policy-v1/evidence/uefa-coefficients-2026-page6.json",
      "data/competition/rules/reviews/ucl-forecast-policy-v1/evidence/uefa-coefficients-2026-page7.json",
      "data/competition/rules/reviews/ucl-forecast-policy-v1/evidence/uefa-coefficients-2026-page8.json",
      "data/competition/rules/reviews/ucl-forecast-policy-v1/evidence/uefa-coefficients-2026-page9.json",
      "data/competition/rules/reviews/ucl-forecast-policy-v1/evidence/uefa-como-debut-evidence.json",
      "data/competition/rules/reviews/ucl-forecast-policy-v1/evidence/uefa-como-debut-page.png",
      "data/competition/rules/reviews/ucl-forecast-policy-v1/evidence/uefa-como-profile-dom.yml",
      "data/competition/rules/reviews/ucl-forecast-policy-v1/evidence/uefa-como-profile-text.json",
      "data/competition/rules/reviews/ucl-forecast-policy-v1/verify_coefficient_inputs.py",
      "scripts/build_uefa_champions_league_outcomes.R",
      "tests/testthat/test_ucl_future_integration.R",
      "tests/testthat/test_ucl_future_matchups.R",
      "tests/testthat/test_ucl_joint_score_view.R",
      "tests/testthat/test_ucl_live_outcomes.R")
    if (nrow(rows) != length(expected) || !setequal(rows$artifact_path, expected) ||
        !all(vapply(seq_len(nrow(rows)), function(i) identical(rows$sha256[[i]],
          digest::digest(file = file.path(root, rows$artifact_path[[i]]), algo = "sha256")), logical(1)))) return(.ucl_future_block("future_matchup_review_hash_mismatch"))
    list(status="approved",policy_sha256=review$review_manifest_sha256,package=package,approved_at_utc=review$reviewed_at_utc)
  }, error = function(e) .ucl_future_block("future_matchup_policy_not_approved"))
}

# Pure current-roster selection; it grants no model or publication authority.
# The caller validates the full replay separately and retains its full state/hash.
.ucl_future_current_roster_ratings <- function(state, current) {
  if (!is.list(current) || !is.data.frame(current$clubs) || !"club_id" %in% names(current$clubs))
    .ucl_future_abort("current_roster_invalid")
  ids <- as.character(current$clubs$club_id)
  if (length(ids) != 36L || anyNA(ids) || anyDuplicated(ids) ||
      any(!grepl("^club_[a-z0-9][a-z0-9_]*$", ids))) .ucl_future_abort("current_roster_invalid")
  if (!is.list(state)) .ucl_future_abort("rating_state_roster_invalid")
  clubs <- state$clubs
  if (!is.data.frame(clubs) || !all(c("club_id", "rating", "prior_match_count") %in% names(clubs)) ||
      anyNA(clubs$club_id) || anyDuplicated(as.character(clubs$club_id)) ||
      !is.numeric(clubs$rating) || any(!is.finite(clubs$rating)) || !is.numeric(clubs$prior_match_count) ||
      any(!is.finite(clubs$prior_match_count) | clubs$prior_match_count < 0 | clubs$prior_match_count != floor(clubs$prior_match_count)))
    .ucl_future_abort("rating_state_roster_invalid")
  ids <- sort(ids, method = "radix")
  index <- match(ids, as.character(clubs$club_id))
  if (anyNA(index)) .ucl_future_abort("current_roster_rating_missing")
  if (any(clubs$prior_match_count[index] <= 0L)) .ucl_future_abort("current_roster_history_incomplete")
  stats::setNames(as.numeric(clubs$rating[index]), ids)
}

ucl_future_production_context <- function(information_cutoff_utc) {
  cutoff <- .ucl_future_time(information_cutoff_utc)
  if (!is.finite(cutoff) || cutoff > as.numeric(Sys.time()) + 60) return(.ucl_future_block("invalid_current_information_cutoff"))
  tryCatch({
    release <- phase19_resolve_production_club_release()
    if (!identical(release$model_contract$selected_model_id, "club_elo_nb")) return(.ucl_future_block("team_strength_model_not_promoted"))
    policy <- ucl_future_policy_status()
    if (!identical(policy$status, "approved")) return(policy)
    if (.ucl_future_time(policy$approved_at_utc)>cutoff) return(.ucl_future_block("future_policy_after_information_cutoff"))
    if (!.ucl_live_joint_policy_approved()) return(.ucl_future_block("tournament_joint_view_review_pending"))
    draw_settings <- jsonlite::read_json(file.path(policy$package, "draw_policy.json"), simplifyVector = TRUE)
    phase19_validate_club_goal_fit(release$model)
    phase19_validate_club_calibrator(release$calibrator, require_fitted = TRUE)
    if (!isTRUE(release$model_contract$production_eligible) || isTRUE(release$model_contract$fixture_authority) ||
        !identical(release$model_contract$authority_mode, "production") || release$model$cutoff_utc > information_cutoff_utc ||
        release$calibrator$calibration_cutoff_exclusive > information_cutoff_utc) return(.ucl_future_block("frozen_model_after_information_cutoff"))
    source <- .ucl_live_fixed_current()
    source_available <- as.character(source$accepted$bundle$created_at_utc[[1L]])
    age <- cutoff - .ucl_future_time(source_available)
    if (!is.finite(age) || age < 0 || age > 48*3600) return(.ucl_future_block("current_source_not_available_or_stale"))
    training <- phase19_load_club_training_snapshot(); roster <- phase19_load_current_ucl_club_snapshot()
    if (!identical(training$status, "ready") || !identical(roster$status, "ready") ||
        !identical(as.character(roster$bundle_sha256), as.character(source$accepted$bundle$bundle_sha256[[1L]]))) return(.ucl_future_block("current_club_inputs_unavailable"))
    parameters <- release$rating_parameters
    runtime <- phase19_live_club_rating_runtime()
    replay <- runtime$phase19_replay_club_ratings(training, roster, parameters, min(information_cutoff_utc, as.character(training$cutoff_utc)))
    runtime$phase19_validate_club_rating_replay(replay, training, roster)
    if (!identical(replay$status, "ready")) return(.ucl_future_block("current_roster_history_incomplete"))
    state <- replay$state
    current_ratings <- .ucl_future_current_roster_ratings(state, roster)
    rating_cache <- new.env(parent = emptyenv())
    rating_at <- function(instant) {
      if (!exists(instant, envir = rating_cache, inherits = FALSE)) {
        decayed <- runtime$phase19_club_rating_decay_to(state, instant)
        assign(instant, list(ratings = .ucl_future_current_roster_ratings(decayed, roster),
          state_sha256 = decayed$state_sha256), envir = rating_cache)
      }
      get(instant, envir = rating_cache, inherits = FALSE)
    }
    lineage <- list(model_release_id = release$model_contract$release_id, model_sha256 = release$model_contract$model_sha256,
      calibrator_sha256 = release$model_contract$calibrator_sha256, source_bundle_sha256 = as.character(source$accepted$bundle$bundle_sha256[[1L]]),
      rating_state_sha256 = state$state_sha256, future_policy_sha256 = policy$policy_sha256,
      joint_policy_sha256 = policy$policy_sha256)
    coefficient_inputs <- ucl_future_read_coefficient_inputs(policy,names(current_ratings))
    if (.ucl_future_time(coefficient_inputs$available_at_utc)>cutoff) return(.ucl_future_block("coefficient_evidence_after_information_cutoff"))
    context <- .ucl_future_context(stats::coef(release$model$model), release$model$theta,
      current_ratings, parameters$home_advantage,
      release$calibrator$temperature, release$model_contract$primary_probability_view, information_cutoff_utc, source_available,
      lineage, "production", rating_at, draw_settings$future_tie_policy, coefficient_inputs$values)
    context$.authority_token <- .ucl_future_authority$token
    assign(context$context_sha256,list(cache=new.env(parent=emptyenv()),rating_at=rating_at),envir=.ucl_future_authority$contexts)
    context$status <- "ready"; context$production_eligible <- TRUE
    context
  }, error = function(e) .ucl_future_block(if (!is.null(e$reason_code)) e$reason_code else "future_context_resolution_failed"))
}

ucl_future_production_slot <- function(context, slot_id) {
  if (isTRUE(context$fixture_authority) || !identical(context$.authority_token, .ucl_future_authority$token)) return(.ucl_future_block("production_context_required"))
  cache <- .ucl_future_runtime(context)$cache
  cache_key <- paste0("slot:", slot_id)
  if (exists(cache_key, envir = cache, inherits = FALSE)) return(get(cache_key, envir = cache, inherits = FALSE))
  policy <- ucl_future_policy_status()
  if (!identical(policy$status, "approved") || !identical(policy$policy_sha256, context$future_policy_sha256)) return(.ucl_future_block("future_matchup_policy_not_approved"))
  tryCatch({
    calendar <- jsonlite::read_json(file.path(policy$package, "calendar.json"), simplifyVector = TRUE)
    if (!identical(calendar$edition_id, "ucl_2026_27") || !identical(calendar$evidence_status, "transcribed_official_annex_c") ||
        !grepl("^https://(documents|www)\\.uefa\\.com/", calendar$source_url) || !grepl("^[0-9a-f]{64}$", calendar$raw_sha256))
      return(.ucl_future_block("official_knockout_calendar_not_reviewed"))
    row <- calendar$slots[as.character(calendar$slots$slot_id) == slot_id, , drop = FALSE]
    if (nrow(row) != 1L) return(.ucl_future_block("official_round_slot_missing"))
    slot <- ucl_future_fixture_slot(row$slot_id[[1L]], row$stage_id[[1L]], row$leg_number[[1L]], row$kickoff_lower_bound_utc[[1L]],
      row$neutral[[1L]], row$venue_context[[1L]], calendar$evidence_available_at_utc)
    slot$fixture_authority <- FALSE; slot$schedule_evidence_sha256 <- calendar$raw_sha256
    slot$slot_sha256 <- NULL
    slot$slot_sha256 <- .ucl_future_hash(unclass(slot), "ucl-future-slot-v1")
    slot$.authority_token <- .ucl_future_authority$token
    assign(cache_key, slot, envir = cache)
    slot
  }, error = function(e) .ucl_future_block("official_knockout_calendar_not_reviewed"))
}

ucl_future_context_is_production <- function(context) {
  inherits(context, "ucl_future_matchup_context") && !isTRUE(context$fixture_authority) &&
    identical(context$.authority_token, .ucl_future_authority$token) &&
    identical(context$context_sha256, .ucl_future_hash(.ucl_future_payload(context), "ucl-future-context-v1")) &&
    identical(ucl_future_policy_status()$status, "approved")
}

.ucl_future_seeded <- function(seed, callback) {
  existed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  old <- if (existed) get(".Random.seed", envir = .GlobalEnv) else NULL
  on.exit(if (existed) assign(".Random.seed", old, envir = .GlobalEnv) else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) rm(".Random.seed", envir = .GlobalEnv), add = TRUE)
  set.seed(as.integer(seed)); callback()
}

ucl_future_sample_score <- function(forecast) {
  grid <- forecast$score_grid
  i <- sample.int(nrow(grid), 1L, prob = grid$probability)
  c(home = as.integer(grid$home_goals[[i]]), away = as.integer(grid$away_goals[[i]]))
}

ucl_future_simulate_tie <- function(context, participant_a, participant_b, slots, rules, seed,
    stage_id, path_id, seed_rank_a = NA_integer_, seed_rank_b = NA_integer_, score_sampler = NULL, penalty_sampler = NULL) {
  final <- identical(stage_id, "final")
  if (length(slots) != if (final) 1L else 2L) .ucl_future_abort("tie_slot_count_invalid")
  if (!final && (length(seed_rank_a) != 1L || length(seed_rank_b) != 1L || anyNA(c(seed_rank_a, seed_rank_b)) || seed_rank_a >= seed_rank_b)) .ucl_future_abort("inherited_seed_order_invalid")
  if (!final && .ucl_future_time(slots[[1L]]$kickoff_lower_bound_utc) >= .ucl_future_time(slots[[2L]]$kickoff_lower_bound_utc)) .ucl_future_abort("leg_time_order_invalid")
  if (!isTRUE(context$fixture_authority) && (!is.null(score_sampler) || !is.null(penalty_sampler))) .ucl_future_abort("production_sampler_injection_forbidden")
  if (is.null(score_sampler)) score_sampler <- ucl_future_sample_score
  if (is.null(penalty_sampler)) penalty_sampler <- function(home, away) sample(c(home, away), 1L)
  .ucl_future_seeded(seed, function() {
    forecasts <- list(); records <- list()
    play <- function(home, away, slot, minutes = 90L) {
      f <- ucl_future_forecast_matchup(context, home, away, slot, minutes)
      forecasts[[length(forecasts) + 1L]] <<- f$metadata
      score <- score_sampler(f)
      if (length(score) != 2L || anyNA(score) || any(!is.finite(score)) || any(score < 0 | score != floor(score))) .ucl_future_abort("sampled_score_invalid")
      c(home = as.integer(score[[1L]]), away = as.integer(score[[2L]]))
    }
    make_row <- function(home, away, slot, score, leg) data.frame(stage_id = stage_id, stage_event_id = path_id,
      participant_a = participant_a, participant_b = participant_b, home_club_id = home, away_club_id = away,
      leg_number = leg, leg_order = if (final) "single_neutral" else "seeded_return_leg",
      seed_rank = as.integer(seed_rank_a), opponent_rank = as.integer(seed_rank_b),
      venue_id = if (final) slot$venue_id else paste0("conditional-home-designation:", home), neutral = final,
      regulation_home_goals = score[[1L]], regulation_away_goals = score[[2L]], stringsAsFactors = FALSE)
    if (final) {
      score <- play(participant_a, participant_b, slots[[1L]])
      row <- make_row(participant_a, participant_b, slots[[1L]], score, 1L)
      tied <- score[[1L]] == score[[2L]]
      if (tied) {
        et <- play(participant_a, participant_b, slots[[1L]], 30L)
        row$extra_time_home_goals <- et[[1L]]; row$extra_time_away_goals <- et[[2L]]
        tied <- et[[1L]] == et[[2L]]
      }
      penalty <- if (tied) penalty_sampler(participant_a, participant_b) else NULL
      resolution <- ucl_resolve_final(row, rules, penalty_winner = penalty)
      records <- list(row)
    } else {
      first <- play(participant_b, participant_a, slots[[1L]])
      second <- play(participant_a, participant_b, slots[[2L]])
      row1 <- make_row(participant_b, participant_a, slots[[1L]], first, 1L)
      row2 <- make_row(participant_a, participant_b, slots[[2L]], second, 2L)
      tied <- first[[2L]] + second[[1L]] == first[[1L]] + second[[2L]]
      if (tied) {
        et <- play(participant_a, participant_b, slots[[2L]], 30L)
        row2$extra_time_home_goals <- et[[1L]]; row2$extra_time_away_goals <- et[[2L]]
        tied <- et[[1L]] == et[[2L]]
      }
      penalty <- if (tied) penalty_sampler(participant_a, participant_b) else NULL
      resolution <- ucl_resolve_two_leg_tie(row1, row2, rules, penalty_winner = penalty)
      records <- list(row1, row2)
    }
    if (!identical(resolution$status, "resolved") || !resolution$winner %in% c(participant_a, participant_b)) .ucl_future_abort("knockout_resolution_failed")
    list(resolution = resolution, fixture_rows = records, matchup_provenance = forecasts,
      stage_id = stage_id, path_id = path_id, seed = as.integer(seed), penalty_policy = "exchangeable_winner_half_no_fabricated_tally_v1",
      ruleset_sha256 = rules$ruleset_sha256, context_sha256 = context$context_sha256)
  })
}

.ucl_future_template_nodes <- function(orientation) {
  if (length(orientation) != 12L || anyNA(orientation) || any(!orientation %in% 0:1)) .ucl_future_abort("draw_orientation_invalid")
  rows <- list()
  add <- function(id, stage, side, a, b) rows[[length(rows) + 1L]] <<- data.frame(node_id = id, stage_id = stage, side = side,
    ref_a = a, ref_b = b, slot_leg1 = paste0(stage, "_1"), slot_leg2 = if (stage == "final") NA_character_ else paste0(stage, "_2"), stringsAsFactors = FALSE)
  seeded <- list(11:12, 13:14, 9:10, 15:16)
  unseeded <- list(21:22, 19:20, 23:24, 17:18)
  top <- list(5:6, 3:4, 7:8, 1:2)
  for (side in c("silver", "blue")) for (position in 1:4) {
    pick <- function(pair, bit) pair[[if (side == "silver") 1L + bit else 2L - bit]]
    a <- pick(seeded[[position]], orientation[[position]])
    b <- pick(unseeded[[position]], orientation[[position+4L]])
    add(paste0("po-", side, "-", position), "knockout_play_off", side, paste0("rank:", a), paste0("rank:", b))
  }
  for (side in c("silver", "blue")) for (position in 1:4) {
    pair <- top[[position]]
    rank <- pair[[if (side == "silver") 1L + orientation[[position+8L]] else 2L - orientation[[position+8L]]]]
    add(paste0("r16-", side, "-", position), "round_of_16", side, paste0("rank:", rank), paste0("winner:po-", side, "-", position))
  }
  for (side in c("silver", "blue")) for (position in 1:2)
    add(paste0("qf-", side, "-", position), "quarter_final", side,
      paste0("winner:r16-", side, "-", 2L*position-1L), paste0("winner:r16-", side, "-", 2L*position))
  for (side in c("silver", "blue")) add(paste0("sf-", side), "semi_final", side,
    paste0("winner:qf-", side, "-1"), paste0("winner:qf-", side, "-2"))
  add("final", "final", "silver_nominal_home", "winner:sf-silver", "winner:sf-blue")
  do.call(rbind, rows)
}

ucl_future_fixture_bracket <- function(rankings, orientation = rep(0L, 12L)) {
  if (!is.data.frame(rankings) || !all(c("club_id", "rank") %in% names(rankings)) || nrow(rankings) != 36L ||
      anyNA(rankings$club_id) || anyDuplicated(rankings$club_id) || !setequal(rankings$rank, 1:36)) .ucl_future_abort("complete_resolved_rankings_required")
  rankings <- rankings[order(rankings$rank), c("club_id", "rank"), drop = FALSE]
  rownames(rankings) <- NULL
  bracket <- list(schema_version = "ucl-annex-b-conditional-bracket-v1", edition_id = "ucl_2026_27", rankings = rankings,
    orientation = as.integer(orientation), nodes = .ucl_future_template_nodes(orientation),
    template_source_sha256 = "d4592de4d76c21db70cfc192c081186d5315882787a6cd70ba13ad671e1827cf",
    draw_scope = "fixture_conditional_orientation_not_an_official_draw", fixture_authority = TRUE)
  bracket$bracket_sha256 <- .ucl_future_hash(bracket, "ucl-conditional-bracket-v1")
  class(bracket) <- c("ucl_future_bracket", "list")
  bracket
}

ucl_future_validate_bracket <- function(bracket) {
  if (!inherits(bracket, "ucl_future_bracket")) .ucl_future_abort("bracket_contract_missing")
  payload <- unclass(bracket); payload$bracket_sha256 <- NULL; payload$.authority_token <- NULL
  if (!identical(bracket$bracket_sha256, .ucl_future_hash(payload, "ucl-conditional-bracket-v1"))) .ucl_future_abort("bracket_content_changed")
  expected <- .ucl_future_template_nodes(bracket$orientation)
  if (!identical(bracket$nodes, expected)) .ucl_future_abort("bracket_not_annex_b_template")
  if (!setequal(bracket$rankings$rank, 1:36) || anyDuplicated(bracket$rankings$club_id)) .ucl_future_abort("bracket_rankings_invalid")
  # Explicit independent conservation and DAG checks, beyond the template hash.
  counts <- table(bracket$nodes$stage_id)
  want <- c(knockout_play_off = 8L, round_of_16 = 8L, quarter_final = 4L, semi_final = 2L, final = 1L)
  if (!identical(as.integer(counts[names(want)]), unname(want))) .ucl_future_abort("bracket_stage_cardinality_invalid")
  refs <- unlist(bracket$nodes[c("ref_a", "ref_b")], use.names = FALSE)
  initial <- as.integer(sub("^rank:", "", refs[startsWith(refs, "rank:")]))
  if (!setequal(initial, 1:24) || anyDuplicated(initial)) .ucl_future_abort("initial_knockout_participants_invalid")
  children <- sub("^winner:", "", refs[startsWith(refs, "winner:")])
  if (!setequal(children, setdiff(bracket$nodes$node_id, "final")) || anyDuplicated(children)) .ucl_future_abort("bracket_progression_nonconservation")
  invisible(TRUE)
}

ucl_future_production_bracket <- function(context, rankings, seed, rules) {
  if (isTRUE(context$fixture_authority) || !identical(context$.authority_token, .ucl_future_authority$token)) return(.ucl_future_block("production_context_required"))
  evidence <- rules$evidence[rules$evidence$document_id == "article_19", , drop = FALSE]
  if (nrow(evidence) != 1L || !isTRUE(evidence$accepted[[1L]]) || !isTRUE(evidence$complete[[1L]])) return(.ucl_future_block("same_edition_regulations_not_accepted"))
  tryCatch({
    cache <- .ucl_future_runtime(context)$cache
    if (exists("draw-policy", envir = cache, inherits = FALSE)) {
      cached <- get("draw-policy", envir = cache, inherits = FALSE)
      draw <- cached$draw; draw_sha256 <- cached$sha256
    } else {
      policy <- ucl_future_policy_status()
      if (!identical(policy$status, "approved")) return(policy)
      draw_path <- file.path(policy$package, "draw_policy.json")
      draw <- jsonlite::read_json(draw_path, simplifyVector = TRUE)
      draw_sha256 <- digest::digest(file = draw_path, algo = "sha256")
    }
    if (!identical(draw$edition_id, "ucl_2026_27") || !identical(draw$forecast_scope, "unconditioned_regulations_prior") ||
        !identical(draw$regulations_canonical_sha256, evidence$canonical_sha256[[1L]]) ||
        !identical(draw$official_procedure_claimed, FALSE) || !identical(draw$observed_draw_claimed, FALSE) ||
        !identical(draw$law, "twelve_independent_pair_orientations_half_v1") ||
        !identical(draw$template_raw_sha256, "d4592de4d76c21db70cfc192c081186d5315882787a6cd70ba13ad671e1827cf"))
      return(.ucl_future_block("draw_probability_law_not_reviewed"))
    assign("draw-policy", list(draw = draw, sha256 = draw_sha256), envir = cache)
    orientation <- .ucl_future_seeded(seed, function() sample.int(2L, 12L, replace = TRUE)-1L)
    bracket <- ucl_future_fixture_bracket(rankings, orientation)
    bracket$fixture_authority <- FALSE; bracket$draw_scope <- "unconditioned_regulations_prior"
    bracket$draw_procedure_sha256 <- NA_character_
    bracket$draw_policy_sha256 <- draw_sha256
    bracket$bracket_sha256 <- NULL
    bracket$bracket_sha256 <- .ucl_future_hash(unclass(bracket), "ucl-conditional-bracket-v1")
    bracket$.authority_token <- .ucl_future_authority$token
    bracket
  }, error = function(e) .ucl_future_block("draw_probability_law_not_reviewed"))
}

.ucl_future_child_seed <- function(seed, iteration, node) {
  hash <- .ucl_future_hash(list(seed = as.integer(seed), iteration = as.integer(iteration), node_id = node), "ucl-future-rng-stream-v1")
  strtoi(substr(hash, 1L, 7L), base = 16L)
}

ucl_future_run_bracket <- function(context, bracket, slots = NULL, rules, seed, iteration = 1L) {
  ucl_future_validate_bracket(bracket)
  production <- !isTRUE(context$fixture_authority)
  if (production && (!identical(context$.authority_token, .ucl_future_authority$token) ||
      isTRUE(bracket$fixture_authority) || !identical(bracket$.authority_token, .ucl_future_authority$token) || !is.null(slots)))
    .ucl_future_abort("production_bracket_or_calendar_authority_missing")
  results <- new.env(parent = emptyenv()); events <- list(); provenance <- list(); resolutions <- list()
  rank_to_club <- stats::setNames(as.character(bracket$rankings$club_id), as.character(bracket$rankings$rank))
  resolve <- function(ref) {
    if (startsWith(ref, "rank:")) {
      rank <- as.integer(sub("^rank:", "", ref)); return(list(club_id = unname(rank_to_club[[as.character(rank)]]), inherited_seed = rank))
    }
    id <- sub("^winner:", "", ref)
    if (!exists(id, envir = results, inherits = FALSE)) .ucl_future_abort("noncausal_bracket_reference")
    get(id, envir = results, inherits = FALSE)
  }
  for (i in seq_len(nrow(bracket$nodes))) {
    node <- bracket$nodes[i, , drop = FALSE]
    a <- resolve(node$ref_a[[1L]]); b <- resolve(node$ref_b[[1L]])
    if (identical(a$club_id, b$club_id)) .ucl_future_abort("duplicate_conditional_participant")
    final <- identical(node$stage_id[[1L]], "final")
    if (!final && a$inherited_seed > b$inherited_seed) { swap <- a; a <- b; b <- swap }
    ids <- if (final) node$slot_leg1[[1L]] else c(node$slot_leg1[[1L]], node$slot_leg2[[1L]])
    chosen <- if (production) lapply(ids, function(id) ucl_future_production_slot(context, id)) else slots[ids]
    if (any(vapply(chosen, function(x) !inherits(x, "ucl_future_slot"), logical(1)))) .ucl_future_abort("round_calendar_slot_missing")
    tie <- ucl_future_simulate_tie(context, a$club_id, b$club_id, chosen, rules,
      .ucl_future_child_seed(seed, iteration, node$node_id[[1L]]), node$stage_id[[1L]], node$node_id[[1L]], a$inherited_seed, b$inherited_seed)
    inherited <- min(a$inherited_seed, b$inherited_seed)
    assign(node$node_id[[1L]], list(club_id = tie$resolution$winner, inherited_seed = inherited), envir = results)
    events[[i]] <- data.frame(iteration = as.integer(iteration), node_id = node$node_id[[1L]], stage_id = node$stage_id[[1L]],
      participant_a = a$club_id, participant_b = b$club_id, inherited_seed_a = a$inherited_seed, inherited_seed_b = b$inherited_seed,
      winner = tie$resolution$winner, loser = tie$resolution$loser, inherited_winner_seed = inherited,
      resolution = tie$resolution$resolution, extra_time_applied = tie$resolution$extra_time_applied,
      penalty_applied = tie$resolution$penalty_applied, seed = tie$seed, stringsAsFactors = FALSE)
    provenance <- c(provenance, tie$matchup_provenance)
    resolutions[[node$node_id[[1L]]]] <- tie$resolution
  }
  table <- do.call(rbind, events)
  if (nrow(table) != 23L || sum(table$stage_id == "final") != 1L || anyNA(table$winner)) .ucl_future_abort("knockout_iteration_nonconservation")
  list(status = "ready", events = table, champion = table$winner[table$stage_id == "final"],
    matchup_provenance = provenance, resolutions = resolutions, bracket = bracket,
    bracket_sha256 = bracket$bracket_sha256, context_sha256 = context$context_sha256,
    draw_scope = bracket$draw_scope, fixture_authority = context$fixture_authority,
    events_sha256 = .ucl_future_hash(table, "ucl-knockout-iteration-events-v1"))
}

ucl_future_progression <- function(rank_rows, context, slots = NULL, rules, seed, fixture_orientation = rep(0L, 12L)) {
  if (!is.data.frame(rank_rows) || !all(c("iteration", "club_id", "rank") %in% names(rank_rows))) .ucl_future_abort("league_simulation_rank_rows_required")
  rank_rows <- rank_rows[order(rank_rows$iteration,rank_rows$club_id,method="radix"),,drop=FALSE];rownames(rank_rows)<-NULL
  iterations <- sort(unique(as.integer(rank_rows$iteration)))
  runs <- lapply(iterations, function(iteration) {
    rankings <- rank_rows[rank_rows$iteration == iteration, c("club_id", "rank"), drop = FALSE]
    orientation <- if (is.function(fixture_orientation)) fixture_orientation(iteration) else fixture_orientation
    bracket <- if (isTRUE(context$fixture_authority)) ucl_future_fixture_bracket(rankings, orientation) else
      ucl_future_production_bracket(context, rankings, .ucl_future_child_seed(seed, iteration, "draw"), rules)
    if (!inherits(bracket, "ucl_future_bracket")) .ucl_future_abort(bracket$reason_code)
    ucl_future_run_bracket(context, bracket, slots, rules, seed, iteration)
  })
  events <- do.call(rbind, lapply(runs, `[[`, "events"))
  clubs <- sort(unique(as.character(rank_rows$club_id)), method = "radix")
  stages <- c("direct_round_of_16", "knockout_play_off", "eliminated", "round_of_16", "quarter_final", "semi_final", "final", "champion")
  counts <- matrix(0L, nrow = length(clubs), ncol = length(stages), dimnames = list(clubs, stages))
  for (iteration in iterations) {
    ranks <- rank_rows[rank_rows$iteration == iteration, ]
    counts[as.character(ranks$club_id[ranks$rank <= 8L]), "direct_round_of_16"] <- counts[as.character(ranks$club_id[ranks$rank <= 8L]), "direct_round_of_16"] + 1L
    counts[as.character(ranks$club_id[ranks$rank %in% 9:24]), "knockout_play_off"] <- counts[as.character(ranks$club_id[ranks$rank %in% 9:24]), "knockout_play_off"] + 1L
    counts[as.character(ranks$club_id[ranks$rank >= 25L]), "eliminated"] <- counts[as.character(ranks$club_id[ranks$rank >= 25L]), "eliminated"] + 1L
    per <- events[events$iteration == iteration, ]
    mapping <- c(round_of_16 = "round_of_16", quarter_final = "quarter_final", semi_final = "semi_final", final = "final")
    for (stage in names(mapping)) {
      node <- per[per$stage_id == stage, ]
      participants <- c(node$participant_a, node$participant_b)
      if (anyDuplicated(participants)) .ucl_future_abort("stage_participant_nonconservation")
      counts[participants, stage] <- counts[participants, stage] + 1L
    }
    winner <- per$winner[per$stage_id == "final"]
    counts[winner, "champion"] <- counts[winner, "champion"] + 1L
  }
  expected <- c(8L, 16L, 12L, 16L, 8L, 4L, 2L, 1L) * length(iterations)
  if (!identical(as.integer(colSums(counts)), as.integer(expected))) .ucl_future_abort("progression_probability_nonconservation")
  progression <- do.call(rbind, lapply(clubs, function(club) data.frame(club_id = club, stage_id = stages,
    wins_or_entries = as.integer(counts[club, ]), probability = as.numeric(counts[club, ]) / length(iterations),
    simulation_count = length(iterations), status = "resolved", stringsAsFactors = FALSE)))
  uncertainty <- ucl_live_monte_carlo_uncertainty(progression)
  result <- list(status = "ready", progression = progression, uncertainty = uncertainty, events = events, iterations = runs,
    model_uncertainty_included = FALSE, fixture_authority = context$fixture_authority,
    context_sha256 = context$context_sha256, seed = as.integer(seed), simulation_count = length(iterations),
    late_tie_prior_samples=.ucl_future_empty_prior_samples(),
    late_tie_prior_contribution=ucl_future_prior_contribution(.ucl_future_empty_prior_samples(),clubs,length(iterations)),
    rank_rows=rank_rows,rank_rows_sha256=.ucl_future_hash(rank_rows,"ucl-future-rank-inputs-v1"),
    progression_sha256 = .ucl_future_hash(progression, "ucl-future-progression-v1"),
    event_log_sha256 = .ucl_future_hash(events, "ucl-future-knockout-event-log-v1"))
  if (!isTRUE(context$fixture_authority)) {
    result$.authority_token <- .ucl_future_authority$token
    result$.context <- context
    result$.binding_sha256 <- .ucl_future_projection_binding(result,context)
  }
  result
}

ucl_future_verify_projection <- function(projection, ledger) {
  if (!is.list(projection) || !identical(projection$status, "ready") || isTRUE(projection$fixture_authority) ||
      !identical(projection$.authority_token, .ucl_future_authority$token)) return(FALSE)
  context <- projection$.context
  if (!inherits(context, "ucl_future_matchup_context") || !identical(context$.authority_token, .ucl_future_authority$token) ||
      !identical(context$context_sha256, .ucl_future_hash(.ucl_future_payload(context), "ucl-future-context-v1"))) return(FALSE)
  for (field in c("model_release_id", "model_sha256", "calibrator_sha256", "source_bundle_sha256", "information_cutoff_utc"))
    if (!identical(as.character(context[[field]]), as.character(ledger[[field]]))) return(FALSE)
  policy <- ucl_future_policy_status()
  if (!identical(policy$status, "approved") || !identical(policy$policy_sha256, context$future_policy_sha256)) return(FALSE)
  if (!identical(projection$rank_rows_sha256,.ucl_future_hash(projection$rank_rows,"ucl-future-rank-inputs-v1")) ||
      !identical(projection$progression_sha256, .ucl_future_hash(projection$progression, "ucl-future-progression-v1")) ||
      !identical(projection$event_log_sha256, .ucl_future_hash(projection$events, "ucl-future-knockout-event-log-v1"))) return(FALSE)
  if (!all(vapply(projection$iterations, function(run) {
    tryCatch({ ucl_future_validate_bracket(run$bracket)
      !isTRUE(run$bracket$fixture_authority) && identical(run$bracket$.authority_token, .ucl_future_authority$token) &&
        identical(run$bracket$draw_scope, "unconditioned_regulations_prior") &&
        identical(run$events_sha256, .ucl_future_hash(run$events, "ucl-knockout-iteration-events-v1"))
    }, error = function(e) FALSE)
  }, logical(1)))) return(FALSE)
  binding <- .ucl_future_projection_binding(projection,context)
  identical(binding, projection$.binding_sha256)
}

ucl_future_projection_artifacts <- function(projection) {
  events <- projection$events
  events$stage_event_id <- paste0("conditional-iteration-", events$iteration, ":", events$node_id)
  rows <- list()
  for (i in seq_along(projection$iterations)) {
    run <- projection$iterations[[i]]
    for (j in seq_along(run$matchup_provenance)) {
      row <- as.data.frame(run$matchup_provenance[[j]], stringsAsFactors = FALSE)
      row$iteration <- as.integer(i)
      row$fixture_id <- paste0("conditional-simulation-", i, "-query-", j)
      row$is_official_fixture <- FALSE
      rows[[length(rows) + 1L]] <- row
    }
  }
  provenance <- do.call(rbind, rows); rownames(provenance) <- NULL
  if (any(provenance$joint_max_1x2_error > 1e-12) || any(provenance$joint_max_conditional_error > 1e-12)) .ucl_future_abort("future_joint_view_qa_failed")
  list(events=events,provenance=provenance,league_rank_inputs=projection$rank_rows,late_tie_prior_samples=projection$late_tie_prior_samples,
    late_tie_prior_contribution=projection$late_tie_prior_contribution)
}


# Derive every score-defined Article18 criterion from the complete accepted
# schedule plus this iteration's scores. No provider rank or ID tiebreak is used.
ucl_future_complete_score_ranking <- function(state, graph, rules, context) {
  fixtures <- graph$fixtures; clubs <- sort(as.character(graph$clubs$club_id),method="radix")
  if (length(clubs)!=36L || nrow(fixtures)!=144L || any(!.ucl_sim_status_completed(fixtures$match_status))) .ucl_future_abort("league_score_evidence_incomplete")
  home <- as.character(fixtures$home_club_id); away <- as.character(fixtures$away_club_id)
  hg <- as.integer(fixtures$regulation_home_goals); ag <- as.integer(fixtures$regulation_away_goals)
  if (anyNA(c(hg,ag)) || any(c(hg,ag)<0)) .ucl_future_abort("league_score_evidence_incomplete")
  metrics <- do.call(rbind,lapply(clubs,function(club) {
    h <- home==club; a <- away==club; gf <- c(hg[h],ag[a]);ga <- c(ag[h],hg[a]); wins<-gf>ga;draws<-gf==ga
    if (length(gf)!=8L || length(unique(c(away[h],home[a])))!=8L) .ucl_future_abort("league_opponent_graph_invalid")
    data.frame(club_id=club,played=8L,wins=sum(wins),draws=sum(draws),losses=sum(gf<ga),
      goals_for=sum(gf),goals_against=sum(ga),goal_difference=sum(gf-ga),points=3*sum(wins)+sum(draws),
      away_goals_scored=sum(ag[a]),away_wins=sum(ag[a]>hg[a]),stringsAsFactors=FALSE)
  }))
  prior <- state$universal_standings
  prior_ids <- as.character(prior$club_id %||% prior$team_id)
  fields <- c("played","wins","draws","losses","goals_for","goals_against","goal_difference","points")
  if (!setequal(prior_ids,clubs)) .ucl_future_abort("score_metrics_disagree_with_standings_authority")
  # The factual Phase14 table is evaluated at the information cutoff; it must
  # exclude future simulated results. Projected standings deliberately include
  # them as scenarios, without relabelling them as newly available evidence.
  index <- match(clubs,prior_ids)
  monotone <- setdiff(fields,"goal_difference")
  if (any(!vapply(monotone,function(field)all(as.numeric(prior[[field]][index])<=as.numeric(metrics[[field]])),logical(1)))) .ucl_future_abort("score_metrics_disagree_with_standings_authority")
  settled <- as.numeric(prior$played[index])==8L
  if (any(settled) && any(!vapply(fields,function(field)identical(as.numeric(metrics[[field]][settled]),as.numeric(prior[[field]][index][settled])),logical(1)))) .ucl_future_abort("score_metrics_disagree_with_standings_authority")
  if (sum(metrics$goals_for)!=sum(metrics$goals_against) || sum(metrics$wins)!=sum(metrics$losses) || sum(metrics$goal_difference)!=0)
    .ucl_future_abort("league_score_metrics_nonconservation")
  for (field in c("points","goal_difference","goals_for")) {
    values <- stats::setNames(metrics[[field]],metrics$club_id)
    metric <- vapply(clubs,function(club)sum(values[c(away[home==club],home[away==club])]),numeric(1))
    target <- switch(field,points="opponent_points",goal_difference="opponent_goal_difference",goals_for="opponent_goals_scored")
    metrics[[target]] <- metric
  }
  if (!is.null(context$club_coefficients)) metrics$club_coefficient <- as.numeric(context$club_coefficients[metrics$club_id])
  # Genuine accepted discipline, if present in the factual standings, remains
  # factual. Future scores never manufacture cards or overwrite observed values.
  if ("disciplinary_points" %in% names(prior)) metrics$disciplinary_points <- as.numeric(prior$disciplinary_points[match(clubs,prior_ids)])
  ranking <- ucl_apply_article18(metrics,matches=fixtures,rules=rules)
  ranking$source_bundle_id <- graph$source_bundle_id
  ranking$ranking_scope <- "counterfactual_complete_league"
  ranking$observed_source_eligible <- FALSE; ranking$training_eligible <- FALSE
  attr(ranking,"score_metrics_sha256") <- .ucl_future_hash(metrics,"ucl-complete-score-article18-metrics-v1")
  attr(ranking,"score_metrics") <- metrics
  ranking
}

# Known preseason coefficients are factual inputs, never sampled from a prior.
ucl_future_validate_coefficient_inputs <- function(table, clubs) {
  required <- c("club_id", "uefa_club_id", "association_code", "effective_coefficient", "club_five_season_sum",
    "association_floor", "reference_first_season_year", "reference_last_season_year", paste0("season_",2022:2026))
  if (!is.data.frame(table) || !all(required %in% names(table)) || nrow(table)!=length(clubs) ||
      !setequal(table$club_id,clubs) || anyDuplicated(table$club_id) || anyDuplicated(table$uefa_club_id) ||
      anyNA(table$uefa_club_id) || any(!nzchar(as.character(table$uefa_club_id)))) .ucl_future_abort("known_coefficient_coverage_incomplete")
  numeric_fields <- c("effective_coefficient", "club_five_season_sum", "association_floor", paste0("season_",2022:2026))
  if (any(!vapply(table[numeric_fields],is.numeric,logical(1))) || any(!is.finite(as.matrix(table[numeric_fields]))) ||
      any(as.matrix(table[numeric_fields])<0) || any(table$reference_first_season_year!=2022L) || any(table$reference_last_season_year!=2026L))
    .ucl_future_abort("known_coefficient_reference_or_type_invalid")
  if (any(abs(rowSums(table[paste0("season_",2022:2026)])-table$club_five_season_sum)>1e-9) ||
      any(abs(pmax(table$club_five_season_sum,table$association_floor)-table$effective_coefficient)>1e-9)) .ucl_future_abort("known_coefficient_floor_or_sum_mismatch")
  # The reviewed current36 have distinct effective coefficients. A later roster
  # containing equal coefficients needs genuine D.8 ordering, never ID sorting.
  if (anyDuplicated(table$effective_coefficient)) .ucl_future_abort("known_equal_coefficient_d8_inputs_required")
  list(values=stats::setNames(as.numeric(table$effective_coefficient),as.character(table$club_id)),
    table_sha256=.ucl_future_hash(table,"ucl-known-preseason-coefficient-inputs-v1"))
}

ucl_future_read_coefficient_inputs <- function(policy, clubs) {
  if (!identical(policy$status,"approved")) .ucl_future_abort("future_matchup_policy_not_approved")
  table <- utils::read.csv(file.path(policy$package,"club_coefficients_2026.csv"),stringsAsFactors=FALSE)
  inputs <- ucl_future_validate_coefficient_inputs(table,clubs)
  available <- unique(as.character(table$local_evidence_available_at_utc))
  if (length(available)!=1L || !is.finite(.ucl_future_time(available))) .ucl_future_abort("known_coefficient_availability_missing")
  inputs$available_at_utc <- available
  inputs
}

.ucl_future_empty_prior_samples <- function() data.frame(iteration=integer(),club_id=character(),rank_interval_min=integer(),
  rank_interval_max=integer(),disciplinary_scenario_order=integer(),known_club_coefficient=numeric(),
  coefficient_tiebreak_used=logical(),scenario_rank=integer(),policy=character(),factual_rank_claimed=logical(),stringsAsFactors=FALSE)

# Uniform ordered set partitions (weak orders), an explicit uncalibrated model
# prior. F(n)=sum_k choose(n,k)*F(n-k) counts all possible nonempty first blocks.
# Within equal disciplinary scenario blocks, criterion10 uses known coefficients.
.ucl_future_weak_order_counts <- function(n) {
  if (length(n)!=1L || is.na(n) || n<0L || n>36L || n!=floor(n)) .ucl_future_abort("weak_order_size_invalid")
  counts <- numeric(n+1L); counts[[1L]] <- 1
  if (n>0L) for (m in seq_len(n)) counts[[m+1L]] <- sum(vapply(seq_len(m),function(k)choose(m,k)*counts[[m-k+1L]],numeric(1)))
  counts
}
.ucl_future_sample_weak_order <- function(ids) {
  ids <- sort(as.character(ids),method="radix")
  if (!length(ids) || anyDuplicated(ids)) .ucl_future_abort("weak_order_identity_invalid")
  counts <- .ucl_future_weak_order_counts(length(ids)); remaining <- ids; result <- stats::setNames(integer(length(ids)),ids); block <- 0L
  while(length(remaining)) {
    n <- length(remaining); sizes <- seq_len(n)
    weights <- vapply(sizes,function(k)choose(n,k)*counts[[n-k+1L]],numeric(1))
    size <- sizes[[sample.int(n,1L,prob=weights)]]
    selected <- sample.int(n,size,replace=FALSE); block <- block+1L
    result[remaining[selected]] <- block; remaining <- remaining[-selected]
  }
  result
}

ucl_future_prior_contribution <- function(samples, clubs, simulation_count) {
  affected <- length(unique(samples$iteration))
  data.frame(club_id=as.character(clubs),simulation_count=as.integer(simulation_count),
    prior_affected_iteration_count=as.integer(affected),
    prior_affected_club_iteration_count=vapply(clubs,function(club)length(unique(samples$iteration[samples$club_id==club])),integer(1)),
    all_stage_max_absolute_probability_change_bound=affected/simulation_count,
    bound_scope="changing_only_late_tie_prior_can_change_at_most_affected_iteration_mass",
    prior_policy="exchangeable_final_disciplinary_weak_order_v1",model_uncertainty_included=FALSE,stringsAsFactors=FALSE)
}

.ucl_future_projection_binding <- function(projection, context) .ucl_future_hash(list(context$context_sha256,
  projection$progression_sha256,projection$event_log_sha256,projection$rank_rows_sha256,projection$uncertainty,
  projection$late_tie_prior_samples,projection$late_tie_prior_contribution),"ucl-future-projection-authority-v2")

ucl_future_resolve_rank_intervals <- function(rank_rows, context, has_future_league_matches, seed) {
  required <- c("iteration", "club_id", "rank", "rank_interval_min", "rank_interval_max")
  if (!all(required %in% names(rank_rows))) .ucl_future_abort("rank_interval_contract_missing")
  missing <- is.na(rank_rows$rank)
  if (!any(missing)) return(list(rows=rank_rows,prior_samples=.ucl_future_empty_prior_samples()))
  if (!isTRUE(has_future_league_matches)) .ucl_future_abort("accepted_factual_late_tiebreak_inputs_required")
  if (!"missing_criterion_id" %in% names(rank_rows) || anyNA(rank_rows$missing_criterion_id[missing]) ||
      any(rank_rows$missing_criterion_id[missing]!="disciplinary_points")) .ucl_future_abort("unresolved_rank_not_proven_disciplinary_only")
  if (!identical(context$future_tie_policy,"exchangeable_final_disciplinary_weak_order_v1")) .ucl_future_abort("unresolved_forecast_late_tiebreak_intervals")
  coefficients <- context$club_coefficients
  if (is.null(coefficients) || !all(rank_rows$club_id %in% names(coefficients))) .ucl_future_abort("known_coefficient_coverage_incomplete")
  samples <- list()
  for (iteration in sort(unique(rank_rows$iteration))) {
    at <- which(rank_rows$iteration==iteration & is.na(rank_rows$rank))
    groups <- split(at,paste(rank_rows$rank_interval_min[at],rank_rows$rank_interval_max[at],sep=":"))
    for (group in groups) {
      low <- unique(as.integer(rank_rows$rank_interval_min[group])); high <- unique(as.integer(rank_rows$rank_interval_max[group]))
      if (length(low)!=1L || length(high)!=1L || anyNA(c(low,high)) || low<1L || high>36L || high-low+1L!=length(group)) .ucl_future_abort("unresolved_rank_interval_inconsistent")
      ids <- as.character(rank_rows$club_id[group]); known <- coefficients[ids]
      if (anyDuplicated(known)) .ucl_future_abort("known_equal_coefficient_d8_inputs_required")
      scenario <- .ucl_future_seeded(.ucl_future_child_seed(seed,iteration,paste0("late-tie-",low,"-",high)),function().ucl_future_sample_weak_order(ids))
      ordinal <- as.integer(scenario[ids]); positions <- integer(length(group)); positions[order(ordinal,-known)] <- seq.int(low,high)
      used <- duplicated(ordinal) | duplicated(ordinal,fromLast=TRUE)
      rank_rows$rank[group] <- positions
      rank_rows$rank_status[group] <- "scenario_prior_order_not_official_rank"
      rank_rows$qualification_band[group] <- ifelse(positions<=8L,"direct_round_of_16",ifelse(positions<=24L,"knockout_play_off","eliminated"))
      samples[[length(samples)+1L]] <- data.frame(iteration=as.integer(iteration),club_id=ids,
        rank_interval_min=low,rank_interval_max=high,disciplinary_scenario_order=ordinal,known_club_coefficient=as.numeric(known),
        coefficient_tiebreak_used=used,scenario_rank=positions,policy="exchangeable_final_disciplinary_weak_order_v1",factual_rank_claimed=FALSE,stringsAsFactors=FALSE)
    }
    ranks <- rank_rows$rank[rank_rows$iteration==iteration]
    if (!setequal(ranks,1:36) || anyDuplicated(ranks)) .ucl_future_abort("scenario_rank_permutation_invalid")
  }
  out <- if(length(samples))do.call(rbind,samples)else .ucl_future_empty_prior_samples()
  if (nrow(out)) out <- out[order(out$iteration,out$club_id,method="radix"),,drop=FALSE]
  rownames(out)<-NULL
  list(rows=rank_rows,prior_samples=out)
}

ucl_future_attach_to_simulation <- function(simulation, context, rules, slots = NULL) {
  if (!is.data.frame(simulation$rank_rows) || !nrow(simulation$rank_rows)) .ucl_future_abort("league_rank_simulations_missing")
  if (!isTRUE(context$fixture_authority)) {
    for (field in c("model_release_id", "model_sha256", "calibrator_sha256", "information_cutoff_utc"))
      if (!identical(as.character(context[[field]]), as.character(simulation$metadata[[field]]))) .ucl_future_abort("league_knockout_model_parent_mismatch")
    if (!identical(context$source_bundle_sha256, simulation$graph$source_bundle_sha256)) .ucl_future_abort("league_knockout_source_parent_mismatch")
  }
  original_ranks <- simulation$rank_rows
  if (anyNA(original_ranks$rank)) {
    future <- any(!.ucl_sim_status_completed(simulation$graph$fixtures$match_status))
    resolved <- ucl_future_resolve_rank_intervals(original_ranks, context, future, simulation$metadata$seed)
    simulation$rank_rows <- resolved$rows
  } else resolved <- list(prior_samples=.ucl_future_empty_prior_samples())
  projection <- ucl_future_progression(simulation$rank_rows, context, slots, rules, simulation$metadata$seed)
  projection$late_tie_prior_samples <- resolved$prior_samples
  projection$late_tie_prior_contribution <- ucl_future_prior_contribution(resolved$prior_samples,names(context$ratings),projection$simulation_count)
  if (!isTRUE(context$fixture_authority)) projection$.binding_sha256 <- .ucl_future_projection_binding(projection,context)
  run_id <- paste0("ucl-full-", substr(.ucl_future_hash(list(simulation$run_id, context$context_sha256,
    projection$progression_sha256, projection$event_log_sha256,projection$late_tie_prior_samples,projection$late_tie_prior_contribution), "ucl-full-simulation-run-v2"), 1L, 32L))
  last <- projection$iterations[[length(projection$iterations)]]
  prior_sha <- context$future_policy_sha256
  prior_id <- paste0("unconditioned-prior-", substr(prior_sha, 1L, 16L))
  stage_events <- lapply(seq_len(nrow(last$bracket$nodes)), function(i) {
    node <- last$bracket$nodes[i, ]
    .ucl_record_stage_event(last$resolutions[[node$node_id]], node$stage_id, node$node_id,
      seed_slot_id = node$node_id, draw_policy_id = "ucl-annex-b-unconditioned-orientation-prior-v1",
      draw_artifact_id = prior_id, draw_artifact_sha256 = prior_sha,
      source_artifact_ids = paste0("reviewed-forecast-policy:", prior_sha), source_bundle_id = simulation$graph$source_bundle_id,
      simulation_run_id = run_id)
  })
  champion <- .ucl_record_stage_event(last$resolutions$final, "champion", "champion",
    seed_slot_id = "champion", draw_policy_id = "ucl-annex-b-unconditioned-orientation-prior-v1",
    draw_artifact_id = prior_id, draw_artifact_sha256 = prior_sha, source_artifact_ids = paste0("reviewed-forecast-policy:", prior_sha),
    source_bundle_id = simulation$graph$source_bundle_id, simulation_run_id = run_id)
  stage_events <- do.call(rbind, c(stage_events, list(champion)))
  stage_events$status <- stage_events$path_status
  progression <- simulation$progression_probabilities
  key <- paste(progression$club_id, progression$stage_id, sep = ":")
  index <- match(key, paste(projection$progression$club_id, projection$progression$stage_id, sep = ":"))
  if (anyNA(index)) .ucl_future_abort("league_knockout_progression_schema_mismatch")
  progression$probability <- projection$progression$probability[index]
  progression$status <- "resolved"; progression$unresolved_reason <- NA_character_
  progression$run_id <- run_id; progression$draw_artifact_sha256 <- prior_sha
  simulation$stage_events <- simulation$knockout_paths <- stage_events
  simulation$progression_probabilities <- progression
  simulation$future_projection <- projection
  simulation$run_id <- run_id
  simulation$rank_rows$run_id <- run_id
  if (is.data.frame(simulation$simulations)) simulation$simulations$run_id <- run_id
  simulation$metadata$run_id <- run_id; simulation$metadata$status <- "ready"
  simulation$metadata$algorithm_version <- "ucl-league-plus-dynamic-knockout-v1"
  simulation$metadata$draw_scope <- "unconditioned_regulations_prior"
  simulation$metadata$draw_authority_mode <- if (isTRUE(context$fixture_authority)) "fixture_unconditioned_prior" else "reviewed_unconditioned_prior"
  simulation$metadata$draw_policy_id <- "ucl-annex-b-unconditioned-orientation-prior-v1"
  simulation$metadata$draw_artifact_id <- prior_id; simulation$metadata$draw_artifact_sha256 <- prior_sha
  simulation$metadata$representative_knockout_path_iteration <- length(projection$iterations)
  simulation$metadata$future_policy_sha256 <- context$future_policy_sha256
  simulation$metadata$future_context_sha256 <- context$context_sha256
  simulation$metadata$knockout_event_log_sha256 <- projection$event_log_sha256
  simulation$metadata$forecast_scope_disclosure <- "Unconditioned legal-bracket prior; not an official draw forecast; administrative draw restrictions are not conditioned on."
  simulation$metadata$model_uncertainty_included <- FALSE
  simulation$metadata$future_tie_policy <- context$future_tie_policy
  simulation$metadata$late_tie_prior_sample_count <- nrow(resolved$prior_samples)
  simulation$metadata$late_tie_prior_affected_iterations <- length(unique(resolved$prior_samples$iteration))
  simulation$metadata$late_tie_prior_max_probability_change_bound <- length(unique(resolved$prior_samples$iteration))/projection$simulation_count
  simulation$metadata$component_hashes$stage_events_sha256 <- .ucl_sim_canonical_table_hash(stage_events, "stage_event_id", "ucl20-stage-events-v1")
  simulation$metadata$component_hashes$knockout_paths_sha256 <- simulation$metadata$component_hashes$stage_events_sha256
  simulation$metadata$component_hashes$progression_sha256 <- .ucl_sim_canonical_table_hash(progression, "club_id", "ucl20-progression-v1")
  simulation$component_hashes <- simulation$metadata$component_hashes
  simulation$status <- "ready"
  simulation
}
