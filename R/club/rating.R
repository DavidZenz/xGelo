#' Phase 19 club-only, batch-safe Elo rating state.
#'
#' This module deliberately owns its state and identity contract. It reuses the
#' standard Elo expectation equation, but never imports national-team storage,
#' aliases, selectors, or ratings.

phase19_club_rating_abort <- function(reason_code, message, data = list()) {
  stop(structure(
    c(list(message = as.character(message), call = NULL,
           reason_code = as.character(reason_code)), data),
    class = c("phase19_club_rating_error", "phase19_club_contract_error",
              "error", "condition")
  ))
}

phase19_club_rating_require_dependencies <- function() {
  required <- c(
    "phase18_canonical_encoding_v2", "phase18_hash_sequence_v2",
    "phase18_hash_row_v2", "phase18_hash_table_v2",
    "phase19_validate_club_training_snapshot",
    "phase19_validate_current_ucl_club_snapshot"
  )
  missing <- required[!vapply(required, exists, logical(1), mode = "function")]
  if (length(missing)) {
    phase19_club_rating_abort(
      "dependency_missing",
      paste0("Club rating dependencies must be sourced first: ",
             paste(missing, collapse = ", "))
    )
  }
  invisible(TRUE)
}

phase19_club_rating_scalar <- function(value, field, positive = FALSE,
                                       non_negative = FALSE) {
  value <- suppressWarnings(as.numeric(value))
  if (length(value) != 1L || !is.finite(value) ||
      (positive && value <= 0) || (non_negative && value < 0)) {
    qualifier <- if (positive) "positive " else if (non_negative) "non-negative " else ""
    phase19_club_rating_abort(
      "invalid_parameters", paste0(field, " must be one ", qualifier, "finite number")
    )
  }
  value
}

phase19_club_rating_parameter_hash <- function(parameters) {
  fields <- c(
    "schema_version", "hash_encoding_version", "forecast_domain",
    "base_rating", "home_advantage", "k_factor",
    "inactivity_factor", "inactivity_rule"
  )
  phase18_hash_sequence_v2(
    unname(parameters[fields]),
    domain = "phase19-club-rating-parameters-v1",
    names = fields,
    types = vapply(parameters[fields], phase18_v2_type_tag, character(1))
  )
}

#' Create one closed, canonically identified club Elo parameter contract.
#'
#' @export
phase19_club_rating_parameters <- function(
    base_rating = 1500,
    home_advantage = 60,
    k_factor = 20,
    inactivity_factor = 0.995
) {
  phase19_club_rating_require_dependencies()
  base_rating <- phase19_club_rating_scalar(base_rating, "base_rating", positive = TRUE)
  home_advantage <- phase19_club_rating_scalar(
    home_advantage, "home_advantage", non_negative = TRUE
  )
  k_factor <- phase19_club_rating_scalar(k_factor, "k_factor", positive = TRUE)
  inactivity_factor <- phase19_club_rating_scalar(
    inactivity_factor, "inactivity_factor", positive = TRUE
  )
  if (!identical(base_rating, 1500) ||
      !home_advantage %in% c(40, 60, 80) ||
      !k_factor %in% c(20, 30, 40) ||
      !inactivity_factor %in% c(0.99, 0.995, 0.999)) {
    phase19_club_rating_abort(
      "invalid_parameters",
      "Club rating settings must belong to the frozen candidate registry"
    )
  }
  parameters <- list(
    schema_version = "phase19-club-rating-parameters-v1",
    hash_encoding_version = phase18_canonical_encoding_v2(),
    forecast_domain = "club",
    base_rating = base_rating,
    home_advantage = home_advantage,
    k_factor = k_factor,
    inactivity_factor = inactivity_factor,
    inactivity_rule = "base_plus_difference_times_annual_factor",
    parameter_sha256 = ""
  )
  parameters$parameter_sha256 <- phase19_club_rating_parameter_hash(parameters)
  class(parameters) <- c("phase19_club_rating_parameters", "list")
  phase19_validate_club_rating_parameters(parameters)
  parameters
}

phase19_validate_club_rating_parameters <- function(parameters) {
  phase19_club_rating_require_dependencies()
  required <- c(
    "schema_version", "hash_encoding_version", "forecast_domain",
    "base_rating", "home_advantage", "k_factor",
    "inactivity_factor", "inactivity_rule", "parameter_sha256"
  )
  if (!inherits(parameters, "phase19_club_rating_parameters") ||
      !is.list(parameters) || !identical(names(parameters), required) ||
      !identical(parameters$schema_version, "phase19-club-rating-parameters-v1") ||
      !identical(parameters$hash_encoding_version, phase18_canonical_encoding_v2()) ||
      !identical(parameters$forecast_domain, "club") ||
      !identical(parameters$inactivity_rule,
                 "base_plus_difference_times_annual_factor")) {
    phase19_club_rating_abort("invalid_parameters", "Club rating parameter schema is not exact")
  }
  if (!identical(phase19_club_rating_scalar(
    parameters$base_rating, "base_rating", positive = TRUE
  ), 1500) ||
      !phase19_club_rating_scalar(
        parameters$home_advantage, "home_advantage", non_negative = TRUE
      ) %in% c(40, 60, 80) ||
      !phase19_club_rating_scalar(
        parameters$k_factor, "k_factor", positive = TRUE
      ) %in% c(20, 30, 40) ||
      !phase19_club_rating_scalar(
        parameters$inactivity_factor, "inactivity_factor", positive = TRUE
      ) %in% c(0.99, 0.995, 0.999)) {
    phase19_club_rating_abort(
      "invalid_parameters",
      "Club rating settings must belong to the frozen candidate registry"
    )
  }
  if (!phase19_is_sha256(parameters$parameter_sha256) ||
      !identical(parameters$parameter_sha256,
                 phase19_club_rating_parameter_hash(parameters))) {
    phase19_club_rating_abort("invalid_parameters", "Club rating parameter hash drifted")
  }
  invisible(parameters)
}

phase19_club_rating_ids <- function(training_snapshot, current_snapshot) {
  sort(unique(c(
    as.character(training_snapshot$matches$home_club_id),
    as.character(training_snapshot$matches$away_club_id),
    as.character(current_snapshot$clubs$club_id)
  )), method = "radix")
}

phase19_club_rating_clubs_hash <- function(clubs) {
  phase18_hash_table_v2(
    clubs, key = "club_id", schema_tag = "phase19-club-rating-state-clubs-v1"
  )
}

phase19_club_rating_state_hash <- function(state) {
  clubs_sha256 <- phase19_club_rating_clubs_hash(state$clubs)
  fields <- c(
    "schema_version", "hash_encoding_version", "forecast_domain", "entity_kind",
    "authority_mode", "fixture_authority", "promotion_eligible",
    "training_snapshot_sha256", "current_snapshot_sha256",
    "training_generation_id", "current_generation_id", "current_edition_id",
    "training_club_registry_sha256", "current_identity_registry_sha256",
    "current_roster_sha256", "parameter_sha256", "as_of_boundary",
    "last_evidence_available_at_utc", "last_batch_sha256"
  )
  phase18_hash_sequence_v2(
    c(unname(state[fields]), list(clubs_sha256)),
    domain = "phase19-club-rating-state-v1",
    names = c(fields, "clubs_sha256"),
    types = c(vapply(state[fields], phase18_v2_type_tag, character(1)), "character")
  )
}

#' Initialize a club-only rating state from validated Phase 19 snapshots.
#'
#' @export
phase19_initialize_club_rating_state <- function(training_snapshot,
                                                 current_snapshot,
                                                 parameters) {
  phase19_club_rating_require_dependencies()
  phase19_validate_club_rating_parameters(parameters)
  authority_mode <- as.character(training_snapshot$authority_mode)
  if (!authority_mode %in% c("production", "fixture") ||
      !identical(authority_mode, as.character(current_snapshot$authority_mode))) {
    phase19_club_rating_abort(
      "authority_mismatch", "Training and current-UCL authority modes must match"
    )
  }
  phase19_validate_club_training_snapshot(training_snapshot, authority_mode)
  phase19_validate_current_ucl_club_snapshot(current_snapshot, authority_mode)
  if (!identical(as.character(training_snapshot$model_domain), "club") ||
      !identical(as.character(current_snapshot$model_domain), "club")) {
    phase19_club_rating_abort("domain_mismatch", "Club rating accepts only club snapshots")
  }
  is_fixture <- identical(authority_mode, "fixture")
  if (!identical(isTRUE(training_snapshot$fixture_authority), is_fixture) ||
      !identical(isTRUE(current_snapshot$fixture_authority), is_fixture) ||
      (is_fixture && !identical(training_snapshot$fixture_root_sha256,
                                current_snapshot$fixture_root_sha256))) {
    phase19_club_rating_abort(
      "authority_mismatch", "Training and current-UCL fixture authority must be identical"
    )
  }
  club_ids <- phase19_club_rating_ids(training_snapshot, current_snapshot)
  if (!length(club_ids) || any(!grepl("^club_[a-z0-9][a-z0-9_]*$", club_ids))) {
    phase19_club_rating_abort("identity_mismatch", "Rating registry contains non-club IDs")
  }
  clubs <- data.frame(
    club_id = club_ids,
    rating = rep(parameters$base_rating, length(club_ids)),
    prior_match_count = rep(0L, length(club_ids)),
    last_evidence_available_at_utc = rep("", length(club_ids)),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  state <- list(
    schema_version = "phase19-club-rating-state-v1",
    hash_encoding_version = phase18_canonical_encoding_v2(),
    forecast_domain = "club", entity_kind = "club",
    authority_mode = authority_mode, fixture_authority = is_fixture,
    promotion_eligible = !is_fixture,
    training_snapshot_sha256 = as.character(training_snapshot$snapshot_sha256),
    current_snapshot_sha256 = as.character(current_snapshot$snapshot_sha256),
    training_generation_id = as.character(training_snapshot$accepted_generation_id),
    current_generation_id = as.character(current_snapshot$source_generation_id),
    current_edition_id = as.character(current_snapshot$edition_id),
    training_club_registry_sha256 = as.character(training_snapshot$club_registry_sha256),
    current_identity_registry_sha256 = as.character(current_snapshot$identity_registry_sha256),
    current_roster_sha256 = as.character(current_snapshot$roster_sha256),
    parameter_sha256 = as.character(parameters$parameter_sha256),
    parameters = parameters,
    as_of_boundary = "",
    last_evidence_available_at_utc = "",
    last_batch_sha256 = "",
    clubs = clubs,
    state_sha256 = ""
  )
  class(state) <- c("phase19_club_rating_state", "list")
  state$state_sha256 <- phase19_club_rating_state_hash(state)
  phase19_validate_club_rating_state(state)
  state
}

phase19_validate_club_rating_state <- function(state) {
  phase19_club_rating_require_dependencies()
  if (!inherits(state, "phase19_club_rating_state") || !is.list(state) ||
      !identical(state$schema_version, "phase19-club-rating-state-v1") ||
      !identical(state$hash_encoding_version, phase18_canonical_encoding_v2()) ||
      !identical(state$forecast_domain, "club") || !identical(state$entity_kind, "club") ||
      !state$authority_mode %in% c("production", "fixture") ||
      !identical(isTRUE(state$fixture_authority),
                 identical(state$authority_mode, "fixture")) ||
      !identical(isTRUE(state$promotion_eligible),
                 identical(state$authority_mode, "production"))) {
    phase19_club_rating_abort("invalid_state", "Club rating state authority is invalid")
  }
  phase19_validate_club_rating_parameters(state$parameters)
  if (!identical(state$parameter_sha256, state$parameters$parameter_sha256)) {
    phase19_club_rating_abort("invalid_state", "Rating state parameter identity drifted")
  }
  required_clubs <- c(
    "club_id", "rating", "prior_match_count", "last_evidence_available_at_utc"
  )
  if (!is.data.frame(state$clubs) || !identical(names(state$clubs), required_clubs) ||
      !nrow(state$clubs) || anyNA(state$clubs) || anyDuplicated(state$clubs$club_id) ||
      any(!grepl("^club_[a-z0-9][a-z0-9_]*$", state$clubs$club_id)) ||
      !identical(as.character(state$clubs$club_id),
                 sort(as.character(state$clubs$club_id), method = "radix")) ||
      any(!is.finite(state$clubs$rating)) ||
      any(state$clubs$prior_match_count < 0L) ||
      any(state$clubs$prior_match_count != as.integer(state$clubs$prior_match_count))) {
    phase19_club_rating_abort("invalid_state", "Club rating rows are invalid or non-canonical")
  }
  hashes <- c(
    "training_snapshot_sha256", "current_snapshot_sha256",
    "training_club_registry_sha256", "current_identity_registry_sha256",
    "current_roster_sha256", "parameter_sha256", "state_sha256"
  )
  if (any(!vapply(state[hashes], phase19_is_sha256, logical(1))) ||
      !identical(state$state_sha256, phase19_club_rating_state_hash(state))) {
    phase19_club_rating_abort("invalid_state", "Club rating state hash drifted")
  }
  invisible(state)
}

phase19_club_rating_parse_utc <- function(values, field, allow_empty = FALSE) {
  values <- as.character(values)
  empty <- is.na(values) | !nzchar(values)
  if (any(empty) && !allow_empty) {
    phase19_club_rating_abort("invalid_time", paste0(field, " must be complete UTC seconds"))
  }
  if (any(!empty & !grepl(
    "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$", values
  ))) {
    phase19_club_rating_abort("invalid_time", paste0(field, " must use canonical UTC seconds"))
  }
  parsed <- as.POSIXct(values, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  if (any(!empty & is.na(parsed))) {
    phase19_club_rating_abort("invalid_time", paste0(field, " contains invalid UTC values"))
  }
  parsed
}

phase19_club_rating_decay_to <- function(state, boundary_utc) {
  phase19_validate_club_rating_state(state)
  boundary <- phase19_club_rating_parse_utc(boundary_utc, "boundary_utc")[[1L]]
  prior <- phase19_club_rating_parse_utc(
    state$clubs$last_evidence_available_at_utc,
    "last_evidence_available_at_utc", allow_empty = TRUE
  )
  active <- !is.na(prior)
  elapsed_days <- as.numeric(difftime(boundary, prior, units = "days"))
  if (any(active & elapsed_days < 0)) {
    phase19_club_rating_abort("invalid_time", "Rating state cannot move before accepted evidence")
  }
  factor <- rep(1, nrow(state$clubs))
  factor[active] <- state$parameters$inactivity_factor ^
    (elapsed_days[active] / 365)
  base <- state$parameters$base_rating
  state$clubs$rating <- base + (state$clubs$rating - base) * factor
  state$as_of_boundary <- as.character(boundary_utc)
  state$state_sha256 <- phase19_club_rating_state_hash(state)
  phase19_validate_club_rating_state(state)
  state
}

phase19_club_rating_expected_home <- function(home_rating, away_rating,
                                              home_advantage) {
  1 / (1 + 10^((away_rating - (home_rating + home_advantage)) / 400))
}

phase19_club_rating_validate_batch <- function(state, fixtures) {
  required <- c(
    "fixture_id", "forecast_domain", "authority_mode", "boundary_id",
    "kickoff_utc", "home_club_id", "away_club_id", "status",
    "counts_for_model", "regulation_home_goals", "regulation_away_goals"
  )
  if (!is.data.frame(fixtures) || !nrow(fixtures) ||
      length(setdiff(required, names(fixtures)))) {
    phase19_club_rating_abort("invalid_batch", "Rating batch schema is incomplete")
  }
  identifiers <- c(as.character(fixtures$fixture_id),
                   as.character(fixtures$home_club_id),
                   as.character(fixtures$away_club_id))
  if (anyNA(identifiers) || any(!nzchar(identifiers)) ||
      anyDuplicated(as.character(fixtures$fixture_id))) {
    phase19_club_rating_abort("invalid_batch", "Rating batch IDs must be complete and unique")
  }
  if (any(as.character(fixtures$forecast_domain) != "club") ||
      any(as.character(fixtures$authority_mode) != state$authority_mode)) {
    phase19_club_rating_abort(
      "authority_mismatch", "Rating batch domain and authority must match the club state"
    )
  }
  club_ids <- c(as.character(fixtures$home_club_id),
                as.character(fixtures$away_club_id))
  if (any(!grepl("^club_[a-z0-9][a-z0-9_]*$", club_ids)) ||
      any(!club_ids %in% state$clubs$club_id)) {
    phase19_club_rating_abort("identity_mismatch", "Rating batch contains unknown or non-club IDs")
  }
  boundaries <- unique(as.character(fixtures$boundary_id))
  kickoffs <- unique(as.character(fixtures$kickoff_utc))
  if (length(boundaries) != 1L || is.na(boundaries) || !nzchar(boundaries) ||
      length(kickoffs) != 1L) {
    phase19_club_rating_abort("invalid_batch", "One call must contain exactly one rating boundary")
  }
  phase19_club_rating_parse_utc(kickoffs, "kickoff_utc")
  counts <- as.logical(fixtures$counts_for_model)
  completed <- as.character(fixtures$status) == "completed" & !is.na(counts) & counts
  home_goals <- suppressWarnings(as.numeric(fixtures$regulation_home_goals))
  away_goals <- suppressWarnings(as.numeric(fixtures$regulation_away_goals))
  if (any(completed & (!is.finite(home_goals) | home_goals < 0 |
                       home_goals != floor(home_goals))) ||
      any(completed & (!is.finite(away_goals) | away_goals < 0 |
                       away_goals != floor(away_goals)))) {
    phase19_club_rating_abort(
      "invalid_batch", "Completed rating outcomes require non-negative regulation goals"
    )
  }
  invisible(TRUE)
}

phase19_club_rating_batch_hash <- function(fixtures) {
  fields <- c(
    "fixture_id", "forecast_domain", "authority_mode", "boundary_id",
    "kickoff_utc", "home_club_id", "away_club_id", "status",
    "counts_for_model", "regulation_home_goals", "regulation_away_goals"
  )
  canonical <- fixtures[fields]
  canonical <- canonical[order(as.character(canonical$fixture_id), method = "radix"), , drop = FALSE]
  rownames(canonical) <- NULL
  phase18_hash_table_v2(
    canonical, key = "fixture_id", schema_tag = "phase19-club-rating-batch-v1"
  )
}

#' Forecast and then simultaneously update one exact-kickoff club batch.
#'
#' @export
phase19_forecast_club_rating_batch <- function(state, fixtures) {
  phase19_validate_club_rating_state(state)
  phase19_club_rating_validate_batch(state, fixtures)
  fixtures <- fixtures[order(as.character(fixtures$fixture_id), method = "radix"), , drop = FALSE]
  rownames(fixtures) <- NULL
  kickoff <- as.character(fixtures$kickoff_utc[[1L]])
  pre_state <- phase19_club_rating_decay_to(state, kickoff)
  pre_hash <- pre_state$state_sha256
  batch_sha256 <- phase19_club_rating_batch_hash(fixtures)
  home_index <- match(as.character(fixtures$home_club_id), pre_state$clubs$club_id)
  away_index <- match(as.character(fixtures$away_club_id), pre_state$clubs$club_id)
  home_rating <- as.numeric(pre_state$clubs$rating[home_index])
  away_rating <- as.numeric(pre_state$clubs$rating[away_index])
  expected_home <- phase19_club_rating_expected_home(
    home_rating, away_rating, pre_state$parameters$home_advantage
  )
  predictions <- data.frame(
    fixture_id = as.character(fixtures$fixture_id),
    forecast_domain = "club", authority_mode = pre_state$authority_mode,
    fixture_authority = pre_state$fixture_authority,
    promotion_eligible = pre_state$promotion_eligible,
    boundary_id = as.character(fixtures$boundary_id),
    kickoff_utc = kickoff,
    evidence_cutoff_exclusive = kickoff,
    home_club_id = as.character(fixtures$home_club_id),
    away_club_id = as.character(fixtures$away_club_id),
    home_pre_match_rating = home_rating,
    away_pre_match_rating = away_rating,
    rating_difference = home_rating + pre_state$parameters$home_advantage - away_rating,
    home_adjustment = rep(pre_state$parameters$home_advantage, nrow(fixtures)),
    expected_home_result = expected_home,
    home_prior_count = as.integer(pre_state$clubs$prior_match_count[home_index]),
    away_prior_count = as.integer(pre_state$clubs$prior_match_count[away_index]),
    cold_start = pre_state$clubs$prior_match_count[home_index] == 0L |
      pre_state$clubs$prior_match_count[away_index] == 0L,
    max_prior_evidence_available_at_utc = pre_state$last_evidence_available_at_utc,
    pre_batch_state_sha256 = pre_hash,
    batch_sha256 = batch_sha256,
    parameter_sha256 = pre_state$parameter_sha256,
    training_snapshot_sha256 = pre_state$training_snapshot_sha256,
    current_snapshot_sha256 = pre_state$current_snapshot_sha256,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  updated <- pre_state
  counts <- as.logical(fixtures$counts_for_model)
  completed <- as.character(fixtures$status) == "completed" & !is.na(counts) & counts
  if (any(completed)) {
    outcomes <- ifelse(
      fixtures$regulation_home_goals > fixtures$regulation_away_goals, 1,
      ifelse(fixtures$regulation_home_goals == fixtures$regulation_away_goals, 0.5, 0)
    )
    home_delta <- pre_state$parameters$k_factor * (outcomes - expected_home)
    contributions <- rbind(
      data.frame(
        club_id = as.character(fixtures$home_club_id[completed]),
        delta = home_delta[completed], prior_match_count = 1L,
        stringsAsFactors = FALSE
      ),
      data.frame(
        club_id = as.character(fixtures$away_club_id[completed]),
        delta = -home_delta[completed], prior_match_count = 1L,
        stringsAsFactors = FALSE
      )
    )
    contributions <- contributions[
      order(contributions$club_id, contributions$delta, method = "radix"), , drop = FALSE
    ]
    grouped <- split(contributions, contributions$club_id, drop = TRUE)
    for (club_id in sort(names(grouped), method = "radix")) {
      index <- match(club_id, updated$clubs$club_id)
      rows <- grouped[[club_id]]
      updated$clubs$rating[index] <- updated$clubs$rating[index] + sum(rows$delta)
      updated$clubs$prior_match_count[index] <-
        updated$clubs$prior_match_count[index] + as.integer(sum(rows$prior_match_count))
      updated$clubs$last_evidence_available_at_utc[index] <- kickoff
    }
    updated$last_evidence_available_at_utc <- kickoff
  }
  updated$as_of_boundary <- kickoff
  updated$last_batch_sha256 <- batch_sha256
  updated$state_sha256 <- phase19_club_rating_state_hash(updated)
  phase19_validate_club_rating_state(updated)
  list(predictions = predictions, state = updated)
}

phase19_club_rating_component_membership <- function(history) {
  club_ids <- sort(unique(c(
    as.character(history$home_club_id), as.character(history$away_club_id)
  )), method = "radix")
  adjacency <- setNames(lapply(club_ids, function(unused) character()), club_ids)
  if (nrow(history)) {
    for (index in seq_len(nrow(history))) {
      home <- as.character(history$home_club_id[[index]])
      away <- as.character(history$away_club_id[[index]])
      adjacency[[home]] <- unique(c(adjacency[[home]], away))
      adjacency[[away]] <- unique(c(adjacency[[away]], home))
    }
  }
  component <- setNames(rep(NA_integer_, length(club_ids)), club_ids)
  next_component <- 0L
  for (seed in club_ids) {
    if (!is.na(component[[seed]])) next
    next_component <- next_component + 1L
    queue <- seed
    component[[seed]] <- next_component
    while (length(queue)) {
      current <- queue[[1L]]
      queue <- queue[-1L]
      neighbours <- sort(adjacency[[current]], method = "radix")
      unseen <- neighbours[is.na(component[neighbours])]
      if (length(unseen)) {
        component[unseen] <- next_component
        queue <- c(queue, unseen)
      }
    }
  }
  data.frame(
    club_id = names(component),
    component_id = sprintf("component_%04d", as.integer(component)),
    history_match_count = vapply(names(component), function(club_id) {
      sum(history$home_club_id == club_id | history$away_club_id == club_id)
    }, integer(1)),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

phase19_club_rating_component_audit <- function(training_snapshot,
                                                current_snapshot,
                                                history) {
  membership <- phase19_club_rating_component_membership(history)
  roster <- sort(as.character(current_snapshot$clubs$club_id), method = "radix")
  current_rows <- membership[match(roster, membership$club_id), , drop = FALSE]
  missing <- is.na(current_rows$club_id) | current_rows$history_match_count < 1L
  components <- unique(current_rows$component_id[!missing])
  coverage_passed <- !any(missing) && length(components) == 1L
  roster_membership <- data.frame(
    club_id = roster,
    component_id = ifelse(is.na(current_rows$component_id), "", current_rows$component_id),
    history_match_count = ifelse(is.na(current_rows$history_match_count),
                                 0L, current_rows$history_match_count),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  membership_sha256 <- phase18_hash_table_v2(
    membership, key = "club_id",
    schema_tag = "phase19-club-rating-component-membership-v1"
  )
  roster_membership_sha256 <- phase18_hash_table_v2(
    roster_membership, key = "club_id",
    schema_tag = "phase19-current-ucl-rating-component-v1"
  )
  audit <- list(
    schema_version = "phase19-club-rating-component-audit-v1",
    hash_encoding_version = phase18_canonical_encoding_v2(),
    forecast_domain = "club",
    authority_mode = as.character(training_snapshot$authority_mode),
    fixture_authority = isTRUE(training_snapshot$fixture_authority),
    training_snapshot_sha256 = as.character(training_snapshot$snapshot_sha256),
    current_snapshot_sha256 = as.character(current_snapshot$snapshot_sha256),
    current_roster_sha256 = as.character(current_snapshot$roster_sha256),
    training_club_registry_sha256 = as.character(training_snapshot$club_registry_sha256),
    current_identity_registry_sha256 = as.character(current_snapshot$identity_registry_sha256),
    membership_sha256 = membership_sha256,
    roster_membership_sha256 = roster_membership_sha256,
    current_club_count = as.integer(length(roster)),
    missing_current_club_count = as.integer(sum(missing)),
    current_component_count = as.integer(length(components)),
    coverage_passed = coverage_passed,
    component_audit_sha256 = "",
    membership = membership,
    roster_membership = roster_membership
  )
  hash_fields <- setdiff(names(audit),
                         c("component_audit_sha256", "membership", "roster_membership"))
  audit$component_audit_sha256 <- phase18_hash_sequence_v2(
    unname(audit[hash_fields]),
    domain = "phase19-club-rating-component-audit-v1",
    names = hash_fields,
    types = vapply(audit[hash_fields], phase18_v2_type_tag, character(1))
  )
  audit
}

phase19_club_rating_history_boundaries <- function(history) {
  precision <- as.character(history$kickoff_precision)
  exact <- precision == "instant" & nzchar(as.character(history$kickoff_utc))
  date_only <- precision == "date" & !nzchar(as.character(history$kickoff_utc))
  if (any(!(exact | date_only))) {
    phase19_club_rating_abort(
      "invalid_history", "History kickoff precision must be exact instant or conservative date"
    )
  }
  dates <- as.Date(as.character(history$event_date), format = "%Y-%m-%d")
  if (anyNA(dates)) {
    phase19_club_rating_abort("invalid_history", "History event_date must use YYYY-MM-DD")
  }
  boundary_utc <- ifelse(
    exact, as.character(history$kickoff_utc),
    paste0(format(dates, "%Y-%m-%d"), "T00:00:00Z")
  )
  phase19_club_rating_parse_utc(boundary_utc, "history prediction boundary")
  boundary_id <- ifelse(
    exact, paste0("kickoff:", boundary_utc),
    paste0("date:", format(dates, "%Y-%m-%d"))
  )
  data.frame(
    row_index = seq_len(nrow(history)),
    boundary_id = boundary_id,
    boundary_utc = boundary_utc,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

phase19_club_rating_history_batches <- function(history) {
  boundaries <- phase19_club_rating_history_boundaries(history)
  indices <- split(boundaries$row_index, boundaries$boundary_id, drop = TRUE)
  batches <- lapply(sort(names(indices), method = "radix"), function(boundary_id) {
    rows <- history[indices[[boundary_id]], , drop = FALSE]
    boundary_utc <- unique(boundaries$boundary_utc[indices[[boundary_id]]])
    if (length(boundary_utc) != 1L) {
      phase19_club_rating_abort("invalid_history", "One history batch has mixed boundaries")
    }
    completion <- phase19_club_rating_parse_utc(
      rows$completion_not_before_utc, "completion_not_before_utc"
    )
    evidence <- phase19_club_rating_parse_utc(
      rows$evidence_available_at_utc, "evidence_available_at_utc"
    )
    if (any(evidence < completion)) {
      phase19_club_rating_abort("invalid_history", "History evidence predates completion")
    }
    eligible_at <- max(c(completion, evidence))
    list(
      boundary_id = boundary_id,
      boundary_utc = boundary_utc,
      eligible_at_utc = format(eligible_at, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      rows = rows[order(as.character(rows$match_id), method = "radix"), , drop = FALSE]
    )
  })
  order_values <- vapply(batches, function(batch) batch$boundary_utc, character(1))
  batches[order(order_values, vapply(batches, `[[`, character(1), "boundary_id"),
                method = "radix")]
}

phase19_club_rating_prediction_frame <- function(batch, authority_mode) {
  rows <- batch$rows
  data.frame(
    fixture_id = as.character(rows$match_id),
    forecast_domain = "club", authority_mode = authority_mode,
    boundary_id = batch$boundary_id, kickoff_utc = batch$boundary_utc,
    home_club_id = as.character(rows$home_club_id),
    away_club_id = as.character(rows$away_club_id),
    status = "scheduled", counts_for_model = FALSE,
    regulation_home_goals = NA_integer_, regulation_away_goals = NA_integer_,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

phase19_club_rating_update_frame <- function(batches, authority_mode,
                                             eligible_at_utc) {
  rows <- do.call(rbind, lapply(batches, `[[`, "rows"))
  rows <- rows[order(as.character(rows$match_id), method = "radix"), , drop = FALSE]
  data.frame(
    fixture_id = as.character(rows$match_id),
    forecast_domain = "club", authority_mode = authority_mode,
    boundary_id = paste0("evidence:", eligible_at_utc),
    kickoff_utc = eligible_at_utc,
    home_club_id = as.character(rows$home_club_id),
    away_club_id = as.character(rows$away_club_id),
    status = "completed", counts_for_model = TRUE,
    regulation_home_goals = as.integer(rows$regulation_home_goals),
    regulation_away_goals = as.integer(rows$regulation_away_goals),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

phase19_club_rating_apply_pending <- function(state, batches, applied,
                                              before_utc) {
  eligible_at <- vapply(batches, `[[`, character(1), "eligible_at_utc")
  due <- which(!applied & eligible_at < before_utc)
  if (!length(due)) return(list(state = state, applied = applied))
  due_times <- sort(unique(eligible_at[due]), method = "radix")
  for (time in due_times) {
    indices <- which(!applied & eligible_at == time)
    updates <- phase19_club_rating_update_frame(
      batches[indices], state$authority_mode, time
    )
    state <- phase19_forecast_club_rating_batch(state, updates)$state
    applied[indices] <- TRUE
  }
  list(state = state, applied = applied)
}

phase19_club_rating_replay_result <- function(status, reason_code,
                                              training_snapshot,
                                              current_snapshot,
                                              component_audit,
                                              details = list()) {
  is_fixture <- identical(as.character(training_snapshot$authority_mode), "fixture")
  structure(c(list(
    status = status,
    reason_code = reason_code,
    forecast_domain = "club",
    authority_mode = as.character(training_snapshot$authority_mode),
    fixture_authority = is_fixture,
    promotion_eligible = identical(status, "ready") && !is_fixture,
    training_snapshot_sha256 = as.character(training_snapshot$snapshot_sha256),
    current_snapshot_sha256 = as.character(current_snapshot$snapshot_sha256),
    component_audit = component_audit
  ), details), class = c("phase19_club_rating_replay", "list"))
}

#' Replay accepted club history through strict prior-only rating boundaries.
#'
#' `history` may be reordered by a caller only when it is byte-equivalent, after
#' canonicalization, to the validated training snapshot. This supports
#' permutation tests without opening an alternate evidence path.
#'
#' @export
phase19_replay_club_ratings <- function(
    training_snapshot,
    current_snapshot,
    parameters,
    cutoff_utc = training_snapshot$cutoff_utc,
    history = training_snapshot$matches
) {
  phase19_club_rating_require_dependencies()
  authority_mode <- as.character(training_snapshot$authority_mode)
  phase19_validate_club_training_snapshot(training_snapshot, authority_mode)
  phase19_validate_current_ucl_club_snapshot(current_snapshot, authority_mode)
  phase19_validate_club_rating_parameters(parameters)
  if (!identical(authority_mode, as.character(current_snapshot$authority_mode)) ||
      !identical(isTRUE(training_snapshot$fixture_authority),
                 isTRUE(current_snapshot$fixture_authority)) ||
      (identical(authority_mode, "fixture") &&
       !identical(training_snapshot$fixture_root_sha256,
                  current_snapshot$fixture_root_sha256))) {
    phase19_club_rating_abort(
      "authority_mismatch", "Replay snapshots do not share one authority boundary"
    )
  }
  phase18_validate_normalized_club_matches(history)
  canonical <- phase18_history_canonical_table(
    history, c("source_id", "source_match_id", "match_id")
  )
  observed_history_hash <- phase18_hash_table_v2(
    canonical, key = c("source_id", "source_match_id", "match_id"),
    schema_tag = "phase19-club-training-matches-v1"
  )
  if (!identical(observed_history_hash,
                 as.character(training_snapshot$phase19_matches_sha256))) {
    phase19_club_rating_abort(
      "invalid_history", "Replay history is not the validated training snapshot"
    )
  }
  counted <- vapply(canonical$counts_for_model, phase18_history_logical, logical(1))
  if (any(!counted) || any(as.character(canonical$status) != "completed")) {
    phase19_club_rating_abort(
      "invalid_history", "Replay history contains ineligible results"
    )
  }
  cutoff <- phase19_club_rating_parse_utc(cutoff_utc, "cutoff_utc")[[1L]]
  snapshot_cutoff <- phase19_club_rating_parse_utc(
    training_snapshot$cutoff_utc, "training cutoff_utc"
  )[[1L]]
  if (cutoff > snapshot_cutoff) {
    phase19_club_rating_abort(
      "invalid_time", "Replay cutoff cannot exceed the accepted training cutoff"
    )
  }
  cutoff_text <- format(cutoff, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  component_audit <- phase19_club_rating_component_audit(
    training_snapshot, current_snapshot, canonical
  )
  if (!isTRUE(component_audit$coverage_passed)) {
    return(phase19_club_rating_replay_result(
      "blocked", "current_ucl_identity_incomplete",
      training_snapshot, current_snapshot, component_audit
    ))
  }

  state <- phase19_initialize_club_rating_state(
    training_snapshot, current_snapshot, parameters
  )
  batches <- phase19_club_rating_history_batches(canonical)
  applied <- rep(FALSE, length(batches))
  prediction_parts <- list()
  prediction_index <- 0L
  for (batch in batches) {
    if (batch$boundary_utc >= cutoff_text) next
    pending <- phase19_club_rating_apply_pending(
      state, batches, applied, batch$boundary_utc
    )
    state <- pending$state
    applied <- pending$applied
    predicted <- phase19_forecast_club_rating_batch(
      state, phase19_club_rating_prediction_frame(batch, authority_mode)
    )
    state <- predicted$state
    prediction_index <- prediction_index + 1L
    prediction_parts[[prediction_index]] <- predicted$predictions
  }
  pending <- phase19_club_rating_apply_pending(state, batches, applied, cutoff_text)
  state <- phase19_club_rating_decay_to(pending$state, cutoff_text)
  predictions <- if (length(prediction_parts)) {
    do.call(rbind, prediction_parts)
  } else {
    data.frame()
  }
  if (nrow(predictions)) {
    predictions <- predictions[
      order(predictions$kickoff_utc, predictions$fixture_id, method = "radix"), ,
      drop = FALSE
    ]
    rownames(predictions) <- NULL
  }
  phase19_club_rating_replay_result(
    "ready", "", training_snapshot, current_snapshot, component_audit,
    list(
      cutoff_utc = cutoff_text,
      predictions = predictions,
      state = state,
      applied_batch_count = as.integer(sum(pending$applied)),
      excluded_batch_count = as.integer(length(batches) - sum(pending$applied))
    )
  )
}
