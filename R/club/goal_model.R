#' Phase 19 club-only goal models and registered controls.
#'
#' This module owns the statistical model boundary for club forecasts.  It
#' consumes only validated Phase 19 snapshots, the frozen club candidate
#' registry, and immutable pre-boundary club rating evidence.  In particular,
#' it never imports national-team model objects or substitutes another model
#' family when a registered negative-binomial fit fails.

phase19_club_goal_model_abort <- function(reason_code, message, data = list()) {
  stop(structure(
    c(list(message = as.character(message), call = NULL,
           reason_code = as.character(reason_code)), data),
    class = c("phase19_club_goal_model_error", "error", "condition")
  ))
}

phase19_club_goal_require_dependencies <- function() {
  required <- c(
    "phase18_canonical_encoding_v2", "phase18_hash_sequence_v2",
    "phase18_hash_row_v2", "phase18_hash_table_v2",
    "phase19_validate_club_training_snapshot",
    "phase19_validate_candidate_registry", "phase19_validate_feature_contract",
    "validate_scoreline_distribution", "derive_binary_markets"
  )
  missing <- required[!vapply(required, exists, logical(1), mode = "function")]
  if (length(missing)) {
    phase19_club_goal_model_abort(
      "dependency_missing",
      paste0("Club goal-model dependencies must be sourced first: ",
             paste(missing, collapse = ", "))
    )
  }
  if (!requireNamespace("MASS", quietly = TRUE)) {
    phase19_club_goal_model_abort(
      "negative_binomial_unavailable", "MASS is required for club negative-binomial models"
    )
  }
  invisible(TRUE)
}

phase19_club_goal_parse_utc <- function(value, field) {
  if (length(value) != 1L || is.na(value[[1L]]) ||
      !grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$",
             as.character(value[[1L]]))) {
    phase19_club_goal_model_abort(
      "invalid_cutoff", paste0(field, " must be one second-precision UTC instant")
    )
  }
  parsed <- as.POSIXct(as.character(value[[1L]]), format = "%Y-%m-%dT%H:%M:%SZ",
                       tz = "UTC")
  if (is.na(parsed)) {
    phase19_club_goal_model_abort("invalid_cutoff", paste0(field, " is not a UTC instant"))
  }
  parsed
}

phase19_club_goal_hash_scalars <- function(values, domain) {
  phase18_hash_sequence_v2(
    values, domain = domain, names = names(values),
    types = vapply(values, phase18_v2_type_tag, character(1))
  )
}

phase19_club_goal_registration <- function(registration, protocol) {
  if (!inherits(protocol, "phase19_club_evaluation_protocol") ||
      !identical(protocol$status, "ready") ||
      !identical(protocol$forecast_domain, "club") ||
      !protocol$authority_mode %in% c("fixture", "production")) {
    phase19_club_goal_model_abort(
      "protocol_not_ready", "A ready club evaluation protocol is required"
    )
  }
  phase19_validate_feature_contract(protocol$feature_contract)
  phase19_validate_candidate_registry(
    protocol$candidate_registry, protocol$feature_contract
  )
  if (!is.data.frame(registration) || nrow(registration) != 1L ||
      !identical(names(registration), names(protocol$candidate_registry))) {
    phase19_club_goal_model_abort(
      "candidate_not_registered", "Registration must be exactly one frozen candidate row"
    )
  }
  model_id <- as.character(registration$model_id[[1L]])
  frozen <- protocol$candidate_registry[
    protocol$candidate_registry$model_id == model_id, , drop = FALSE
  ]
  if (nrow(frozen) != 1L || !identical(registration, frozen)) {
    phase19_club_goal_model_abort(
      "candidate_not_registered", "Candidate registration differs from the frozen club registry"
    )
  }
  if (!identical(as.character(registration$forecast_domain[[1L]]), "club")) {
    phase19_club_goal_model_abort(
      "domain_mismatch", "Club goal models reject non-club registrations"
    )
  }
  registration
}

phase19_club_goal_unavailable_ids <- function(feature_contract) {
  phase19_validate_feature_contract(feature_contract)
  as.character(feature_contract$feature_id[
    feature_contract$availability_status != "available" |
      !feature_contract$active_in_model |
      feature_contract$imputation_policy == "forbidden"
  ])
}

phase19_club_goal_reject_unavailable_columns <- function(data, feature_contract,
                                                         label) {
  forbidden <- intersect(names(data), phase19_club_goal_unavailable_ids(feature_contract))
  if (length(forbidden)) {
    phase19_club_goal_model_abort(
      "unavailable_feature_active",
      paste0(label, " contains unavailable club enrichment fields: ",
             paste(sort(forbidden, method = "radix"), collapse = ", "))
    )
  }
  invisible(TRUE)
}

#' Return exactly the frozen goal-comparable promotion models.
#'
#' @export
phase19_club_goal_comparable_ids <- function(protocol) {
  if (!inherits(protocol, "phase19_club_evaluation_protocol") ||
      !identical(protocol$status, "ready") ||
      !identical(protocol$forecast_domain, "club")) {
    phase19_club_goal_model_abort(
      "protocol_not_ready", "A ready club evaluation protocol is required"
    )
  }
  registry <- phase19_validate_candidate_registry(
    protocol$candidate_registry, protocol$feature_contract
  )
  ids <- as.character(registry$model_id[
    registry$release_selectable & registry$goal_distribution_declared
  ])
  expected <- c("club_venue_nb", "club_elo_nb")
  if (!identical(ids, expected)) {
    phase19_club_goal_model_abort(
      "candidate_not_registered", "Goal-comparable model inventory drifted"
    )
  }
  ids
}

phase19_club_goal_validate_rating_evidence <- function(rating_evidence,
                                                       training_snapshot,
                                                       authority_mode,
                                                       feature_contract) {
  if (!inherits(rating_evidence, "phase19_club_rating_replay") ||
      !identical(rating_evidence$status, "ready") ||
      !identical(rating_evidence$forecast_domain, "club") ||
      !identical(rating_evidence$authority_mode, authority_mode) ||
      !identical(as.character(rating_evidence$training_snapshot_sha256),
                 as.character(training_snapshot$snapshot_sha256)) ||
      !is.data.frame(rating_evidence$predictions)) {
    phase19_club_goal_model_abort(
      "rating_evidence_invalid",
      "Rating evidence is not one ready club replay over the training snapshot"
    )
  }
  required <- c(
    "fixture_id", "forecast_domain", "authority_mode", "boundary_id",
    "evidence_cutoff_exclusive", "home_club_id", "away_club_id",
    "rating_difference", "pre_batch_state_sha256", "batch_sha256",
    "parameter_sha256", "training_snapshot_sha256", "current_snapshot_sha256"
  )
  if (length(setdiff(required, names(rating_evidence$predictions))) ||
      anyDuplicated(as.character(rating_evidence$predictions$fixture_id)) ||
      any(as.character(rating_evidence$predictions$forecast_domain) != "club") ||
      any(as.character(rating_evidence$predictions$authority_mode) != authority_mode)) {
    phase19_club_goal_model_abort(
      "rating_evidence_invalid", "Rating prediction evidence is incomplete, duplicate, or mixed-domain"
    )
  }
  phase19_club_goal_reject_unavailable_columns(
    rating_evidence$predictions, feature_contract, "Rating evidence"
  )
  invisible(TRUE)
}

phase19_club_goal_eligible_history <- function(training_snapshot, cutoff_utc) {
  authority_mode <- as.character(training_snapshot$authority_mode)
  phase19_validate_club_training_snapshot(training_snapshot, authority_mode)
  cutoff <- phase19_club_goal_parse_utc(cutoff_utc, "cutoff_utc")
  snapshot_cutoff <- phase19_club_goal_parse_utc(
    training_snapshot$cutoff_utc, "training_snapshot$cutoff_utc"
  )
  if (cutoff > snapshot_cutoff) {
    phase19_club_goal_model_abort(
      "invalid_cutoff", "Fit cutoff cannot exceed the accepted training snapshot cutoff"
    )
  }
  history <- training_snapshot$matches
  completion <- as.POSIXct(history$completion_not_before_utc,
                           format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  evidence <- as.POSIXct(history$evidence_available_at_utc,
                         format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  counted <- vapply(history$counts_for_model, phase18_history_logical, logical(1))
  eligible <- !is.na(completion) & !is.na(evidence) & completion < cutoff &
    evidence < cutoff & counted & as.character(history$status) == "completed"
  history <- history[eligible, , drop = FALSE]
  if (!nrow(history)) {
    phase19_club_goal_model_abort(
      "insufficient_training_support", "No completed club result is strictly prior to the fit cutoff"
    )
  }
  history <- phase18_history_canonical_table(
    history, c("source_id", "source_match_id", "match_id")
  )
  list(
    rows = history,
    cutoff = cutoff,
    cutoff_utc = format(cutoff, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  )
}

phase19_club_goal_join_rating <- function(history, rating_evidence) {
  ratings <- rating_evidence$predictions
  index <- match(as.character(history$match_id), as.character(ratings$fixture_id))
  if (anyNA(index) || anyDuplicated(as.character(ratings$fixture_id[index]))) {
    phase19_club_goal_model_abort(
      "rating_evidence_invalid", "Every eligible training result requires exactly one rating row"
    )
  }
  ratings <- ratings[index, , drop = FALSE]
  numeric_rating <- suppressWarnings(as.numeric(ratings$rating_difference))
  if (any(!is.finite(numeric_rating)) ||
      any(as.character(ratings$home_club_id) != as.character(history$home_club_id)) ||
      any(as.character(ratings$away_club_id) != as.character(history$away_club_id)) ||
      any(as.character(ratings$training_snapshot_sha256) !=
            as.character(rating_evidence$training_snapshot_sha256))) {
    phase19_club_goal_model_abort(
      "rating_evidence_invalid", "Eligible rating values or parent identities are invalid"
    )
  }
  rating_cutoff <- as.POSIXct(
    ratings$evidence_cutoff_exclusive,
    format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"
  )
  completion <- as.POSIXct(
    history$completion_not_before_utc,
    format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"
  )
  if (anyNA(rating_cutoff) || any(rating_cutoff >= completion)) {
    phase19_club_goal_model_abort(
      "rating_evidence_invalid", "Rating rows must be immutable pre-result evidence"
    )
  }
  ratings$rating_difference <- numeric_rating
  ratings
}

phase19_club_goal_active_features <- function(model_id) {
  switch(
    model_id,
    uniform_1x2 = character(),
    expanding_1x2 = "prior_regulation_results",
    club_venue_nb = "venue_role",
    club_elo_nb = c("elo_difference_for_team", "venue_role"),
    phase19_club_goal_model_abort(
      "candidate_not_registered", paste0("Unknown club model_id: ", model_id)
    )
  )
}

phase19_club_goal_long_training <- function(history, ratings, active_features) {
  home <- data.frame(
    match_id = as.character(history$match_id),
    goals = suppressWarnings(as.numeric(history$regulation_home_goals)),
    elo_difference_for_team = as.numeric(ratings$rating_difference),
    venue_role = factor("home", levels = c("away", "home")),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  away <- data.frame(
    match_id = as.character(history$match_id),
    goals = suppressWarnings(as.numeric(history$regulation_away_goals)),
    elo_difference_for_team = -as.numeric(ratings$rating_difference),
    venue_role = factor("away", levels = c("away", "home")),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  long <- rbind(home, away)
  long <- long[order(long$match_id, long$venue_role, method = "radix"), , drop = FALSE]
  rownames(long) <- NULL
  required <- c("goals", active_features)
  if (any(!is.finite(long$goals)) || any(long$goals < 0) ||
      any(long$goals != as.integer(long$goals)) ||
      any(!stats::complete.cases(long[required])) ||
      ("elo_difference_for_team" %in% active_features &&
       any(!is.finite(long$elo_difference_for_team)))) {
    phase19_club_goal_model_abort(
      "invalid_training_feature", "Registered club training values must be complete and finite"
    )
  }
  long[, c("match_id", required), drop = FALSE]
}

phase19_club_goal_nb_fit <- function(formula, data, model_id) {
  warnings <- character()
  fitted <- tryCatch(
    withCallingHandlers(
      MASS::glm.nb(
        formula = formula, data = data,
        control = stats::glm.control(maxit = 100), model = TRUE,
        x = FALSE, y = TRUE
      ),
      warning = function(condition) {
        warnings <<- c(warnings, conditionMessage(condition))
        invokeRestart("muffleWarning")
      }
    ),
    error = function(error) error
  )
  if (inherits(fitted, "error")) {
    phase19_club_goal_model_abort(
      "negative_binomial_fit_failed",
      paste0(model_id, " negative-binomial fit failed: ", conditionMessage(fitted))
    )
  }
  coefficients <- stats::coef(fitted)
  if (!isTRUE(fitted$converged) || length(fitted$theta) != 1L ||
      !is.finite(fitted$theta) || fitted$theta <= 0 ||
      !length(coefficients) || any(!is.finite(coefficients))) {
    phase19_club_goal_model_abort(
      "negative_binomial_not_converged",
      paste0(model_id, " negative-binomial fit is non-converged or has invalid theta")
    )
  }
  list(model = fitted, warnings = unique(warnings))
}

phase19_club_goal_empirical_grid <- function(history, support_max) {
  grid <- expand.grid(
    home_goals = 0:as.integer(support_max),
    away_goals = 0:as.integer(support_max),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  grid$probability <- rep(0.5 / nrow(grid), nrow(grid))
  home <- as.integer(history$regulation_home_goals)
  away <- as.integer(history$regulation_away_goals)
  inside <- home >= 0L & away >= 0L & home <= support_max & away <= support_max
  if (any(inside)) {
    keys <- paste(grid$home_goals, grid$away_goals, sep = ":")
    index <- match(paste(home[inside], away[inside], sep = ":"), keys)
    counts <- tabulate(index, nbins = nrow(grid))
    grid$probability <- grid$probability + counts
  }
  grid$probability <- grid$probability / sum(grid$probability)
  grid
}

phase19_club_goal_fit_hash <- function(fit) {
  fields <- c(
    "schema_version", "hash_encoding_version", "forecast_domain",
    "authority_mode", "fixture_authority", "promotion_eligible", "model_id",
    "registry_role", "selection_role", "model_family", "formula",
    "output_capability", "goal_distribution_declared", "support_min",
    "support_max", "promotion_comparable", "tail_policy", "cutoff_utc", "fit_row_count",
    "max_completion_not_before_utc", "max_evidence_available_at_utc",
    "active_features_text", "dropped_features_text", "converged",
    "convergence_status", "fallback_status", "theta_text",
    "training_snapshot_sha256", "current_snapshot_sha256",
    "rating_parameter_sha256", "rating_evidence_sha256",
    "candidate_registry_sha256", "feature_contract_sha256",
    "protocol_sha256", "training_rows_sha256", "coefficient_sha256",
    "empirical_grid_sha256", "model_sha256", "registration_sha256",
    "mass_package_version",
    "unavailable_feature_ids_text"
  )
  phase19_club_goal_hash_scalars(
    unname(fit[fields]) |> setNames(fields), "phase19-club-goal-fit-v1"
  )
}

phase19_club_goal_nested_hash <- function(value, domain) {
  if (is.null(value)) return("")
  if (!requireNamespace("digest", quietly = TRUE)) {
    phase19_club_goal_model_abort("dependency_missing", "digest is required for fitted-object identity")
  }
  # Hash a stable, content-only projection.  Serializing a complete MASS
  # object can materialize lazy slots between construction and validation.
  # The registered formula/rows are bound separately; this identity binds
  # the fitted family, coefficient names/values, dispersion, and model shape
  # that directly determine every prediction.
  if (inherits(value, "negbin")) {
    payload <- paste(
      paste(class(value), collapse = "/"),
      paste(names(value$coefficients), collapse = "|"),
      paste(sprintf("%.17g", as.numeric(value$coefficients)), collapse = "|"),
      sprintf("%.17g", as.numeric(value$theta)),
      as.integer(value$rank), as.integer(value$df.residual),
      nrow(value$model), paste(names(value$model), collapse = "|"),
      paste(deparse(value$call), collapse = " "),
      paste(deparse(value$terms), collapse = " "),
      sep = "\u001f"
    )
  } else {
    payload <- value
  }
  digest::digest(payload, algo = "sha256", serialize = TRUE)
}

phase19_club_goal_registration_hash <- function(registration) {
  if (!is.data.frame(registration) || !nrow(registration) ||
      !"model_id" %in% names(registration)) {
    phase19_club_goal_model_abort("invalid_fit", "Goal-fit registration is incomplete")
  }
  phase18_hash_table_v2(
    registration, key = "model_id",
    schema_tag = "phase19-club-goal-registration-v1"
  )
}

phase19_club_goal_coefficients_hash <- function(coefficients) {
  if (!is.data.frame(coefficients) || !nrow(coefficients)) return("")
  phase18_hash_table_v2(
    coefficients, key = "term",
    schema_tag = "phase19-club-goal-coefficients-v1"
  )
}

phase19_club_goal_empirical_grid_hash <- function(empirical_grid) {
  if (!is.data.frame(empirical_grid) || !nrow(empirical_grid)) return("")
  phase18_hash_table_v2(
    empirical_grid, key = c("home_goals", "away_goals"),
    schema_tag = "phase19-club-empirical-grid-v1"
  )
}

#' Fit exactly one frozen club candidate or control at an exclusive boundary.
#'
#' @export
phase19_fit_club_goal_model <- function(registration, training_snapshot,
                                        rating_evidence, protocol, cutoff_utc) {
  phase19_club_goal_require_dependencies()
  registration <- phase19_club_goal_registration(registration, protocol)
  authority_mode <- as.character(training_snapshot$authority_mode)
  phase19_validate_club_training_snapshot(training_snapshot, authority_mode)
  if (!identical(authority_mode, as.character(protocol$authority_mode)) ||
      !identical(isTRUE(training_snapshot$fixture_authority),
                 isTRUE(protocol$fixture_authority))) {
    phase19_club_goal_model_abort(
      "authority_mismatch", "Training snapshot and protocol authority differ"
    )
  }
  phase19_club_goal_validate_rating_evidence(
    rating_evidence, training_snapshot, authority_mode, protocol$feature_contract
  )
  phase19_club_goal_reject_unavailable_columns(
    training_snapshot$matches, protocol$feature_contract, "Training snapshot"
  )
  eligible <- phase19_club_goal_eligible_history(training_snapshot, cutoff_utc)
  history <- eligible$rows
  ratings <- phase19_club_goal_join_rating(history, rating_evidence)
  model_id <- as.character(registration$model_id[[1L]])
  active_features <- phase19_club_goal_active_features(model_id)
  support_max <- if (is.na(registration$score_support_max[[1L]])) {
    NA_integer_
  } else {
    as.integer(registration$score_support_max[[1L]])
  }
  if (!is.na(support_max) && support_max != 40L) {
    phase19_club_goal_model_abort(
      "candidate_not_registered", "Goal-capable club models require frozen G=40 support"
    )
  }
  model <- NULL
  fit_warnings <- character()
  theta <- NA_real_
  coefficients <- data.frame(
    term = character(), estimate = numeric(), stringsAsFactors = FALSE
  )
  empirical_grid <- data.frame(
    home_goals = integer(), away_goals = integer(), probability = numeric()
  )
  converged <- TRUE
  convergence_status <- if (registration$model_family[[1L]] == "negative_binomial") {
    "converged"
  } else {
    "not_applicable"
  }

  if (registration$model_family[[1L]] == "negative_binomial") {
    if (nrow(history) < 5L) {
      phase19_club_goal_model_abort(
        "insufficient_training_support",
        paste0(model_id, " requires at least five strictly prior club matches")
      )
    }
    long <- phase19_club_goal_long_training(history, ratings, active_features)
    formula <- stats::as.formula(as.character(registration$formula[[1L]]))
    fit_result <- phase19_club_goal_nb_fit(formula, long, model_id)
    model <- fit_result$model
    fit_warnings <- fit_result$warnings
    theta <- as.numeric(model$theta)
    coefficients <- data.frame(
      term = names(stats::coef(model)), estimate = as.numeric(stats::coef(model)),
      stringsAsFactors = FALSE, check.names = FALSE
    )
    coefficients <- coefficients[order(coefficients$term, method = "radix"), , drop = FALSE]
    rownames(coefficients) <- NULL
  } else if (identical(model_id, "expanding_1x2")) {
    empirical_grid <- phase19_club_goal_empirical_grid(history, support_max)
  }

  training_rows <- history[, c(
    "match_id", "completion_not_before_utc", "evidence_available_at_utc",
    "home_club_id", "away_club_id", "regulation_home_goals",
    "regulation_away_goals", "row_sha256"
  ), drop = FALSE]
  rating_rows <- ratings[, c(
    "fixture_id", "rating_difference", "pre_batch_state_sha256",
    "batch_sha256", "parameter_sha256", "training_snapshot_sha256",
    "current_snapshot_sha256"
  ), drop = FALSE]
  rating_rows <- rating_rows[order(rating_rows$fixture_id, method = "radix"), , drop = FALSE]
  rownames(rating_rows) <- NULL
  coefficient_hash <- if (nrow(coefficients)) {
    phase18_hash_table_v2(
      coefficients, key = "term", schema_tag = "phase19-club-goal-coefficients-v1"
    )
  } else ""
  empirical_hash <- if (nrow(empirical_grid)) {
    phase18_hash_table_v2(
      empirical_grid, key = c("home_goals", "away_goals"),
      schema_tag = "phase19-club-empirical-grid-v1"
    )
  } else ""
  registration_hash <- phase19_club_goal_registration_hash(registration)
  fit <- list(
    schema_version = "phase19-club-goal-fit-v1",
    hash_encoding_version = phase18_canonical_encoding_v2(),
    forecast_domain = "club", authority_mode = authority_mode,
    fixture_authority = isTRUE(training_snapshot$fixture_authority),
    promotion_eligible = identical(authority_mode, "production") &&
      isTRUE(protocol$production_eligible),
    model_id = model_id,
    registry_role = as.character(registration$registry_role[[1L]]),
    selection_role = as.character(registration$selection_role[[1L]]),
    model_family = as.character(registration$model_family[[1L]]),
    formula = as.character(registration$formula[[1L]]),
    output_capability = as.character(registration$output_capability[[1L]]),
    goal_distribution_declared = isTRUE(registration$goal_distribution_declared[[1L]]),
    promotion_comparable = isTRUE(registration$release_selectable[[1L]]) &&
      isTRUE(registration$goal_distribution_declared[[1L]]) &&
      model_id %in% c("club_venue_nb", "club_elo_nb"),
    support_min = if (is.na(registration$score_support_min[[1L]])) NA_integer_ else 0L,
    support_max = support_max,
    tail_policy = if (is.na(support_max)) {
      "not_applicable"
    } else {
      "truncate_0_40_then_joint_renormalize_once"
    },
    cutoff_utc = eligible$cutoff_utc,
    fit_row_count = as.integer(nrow(history)),
    max_completion_not_before_utc = max(as.character(history$completion_not_before_utc)),
    max_evidence_available_at_utc = max(as.character(history$evidence_available_at_utc)),
    active_features = active_features,
    active_features_text = paste(active_features, collapse = "|"),
    dropped_features = character(), dropped_features_text = "",
    converged = converged, convergence_status = convergence_status,
    fallback_status = "none", theta = theta,
    theta_text = if (is.na(theta)) "" else sprintf("%.17g", theta),
    training_snapshot_sha256 = as.character(training_snapshot$snapshot_sha256),
    current_snapshot_sha256 = as.character(rating_evidence$current_snapshot_sha256),
    rating_parameter_sha256 = as.character(rating_rows$parameter_sha256[[1L]]),
    rating_evidence_sha256 = phase18_hash_table_v2(
      rating_rows, key = "fixture_id", schema_tag = "phase19-club-goal-rating-evidence-v1"
    ),
    candidate_registry_sha256 = as.character(protocol$candidate_registry_sha256),
    feature_contract_sha256 = as.character(protocol$feature_contract_sha256),
    protocol_sha256 = as.character(protocol$protocol_sha256),
    training_rows_sha256 = phase18_hash_table_v2(
      training_rows, key = "match_id", schema_tag = "phase19-club-goal-training-rows-v1"
    ),
    coefficient_sha256 = coefficient_hash,
    empirical_grid_sha256 = empirical_hash,
    model_sha256 = "",
    registration_sha256 = registration_hash,
    mass_package_version = as.character(utils::packageVersion("MASS")),
    unavailable_feature_ids = phase19_club_goal_unavailable_ids(protocol$feature_contract),
    unavailable_feature_ids_text = paste(
      phase19_club_goal_unavailable_ids(protocol$feature_contract), collapse = "|"
    ),
    registration = registration,
    model = model, coefficients = coefficients,
    empirical_grid = empirical_grid,
    fit_warnings = fit_warnings,
    fit_sha256 = ""
  )
  if (any(as.character(rating_rows$parameter_sha256) != fit$rating_parameter_sha256) ||
      any(as.character(rating_rows$current_snapshot_sha256) != fit$current_snapshot_sha256)) {
    phase19_club_goal_model_abort(
      "rating_evidence_invalid", "Rating rows mix parameter or current-snapshot identities"
    )
  }
  # Compute the nested-model identity only after the complete fit object has
  # been assembled; MASS lazily materializes a few slots while inspected.
  fit$model_sha256 <- phase19_club_goal_nested_hash(
    fit$model, "phase19-club-goal-model-v1"
  )
  fit$fit_sha256 <- phase19_club_goal_fit_hash(fit)
  structure(fit, class = c("phase19_club_goal_fit", "list"))
}

phase19_validate_club_goal_fit <- function(fit) {
  if (!inherits(fit, "phase19_club_goal_fit") ||
      !identical(fit$forecast_domain, "club") ||
      !identical(fit$fit_sha256, phase19_club_goal_fit_hash(fit)) ||
      !identical(fit$fallback_status, "none")) {
      phase19_club_goal_model_abort("invalid_fit", "Club goal fit identity is invalid")
  }
  expected_coefficients <- phase19_club_goal_coefficients_hash(fit$coefficients)
  expected_grid <- phase19_club_goal_empirical_grid_hash(fit$empirical_grid)
  expected_registration <- phase19_club_goal_registration_hash(fit$registration)
  expected_model <- phase19_club_goal_nested_hash(fit$model, "phase19-club-goal-model-v1")
  if (!identical(as.character(fit$coefficient_sha256), expected_coefficients) ||
      !identical(as.character(fit$empirical_grid_sha256), expected_grid) ||
      !identical(as.character(fit$registration_sha256), expected_registration) ||
      !identical(as.character(fit$model_sha256), expected_model)) {
    phase19_club_goal_model_abort(
      "invalid_fit", "Club goal fit nested model, registration, coefficient, or grid identity drifted"
    )
  }
  if (identical(fit$model_family, "negative_binomial")) {
    if (is.null(fit$model) || !inherits(fit$model, "negbin") ||
        !isTRUE(fit$converged) || !isTRUE(fit$model$converged) ||
        length(fit$theta) != 1L || !is.finite(fit$theta) || fit$theta <= 0 ||
        length(fit$model$theta) != 1L || !is.finite(fit$model$theta) ||
        fit$model$theta <= 0 || !identical(as.numeric(fit$theta),
                                           as.numeric(fit$model$theta)) ||
        !identical(names(stats::coef(fit$model)), fit$coefficients$term) ||
        !isTRUE(all.equal(
          as.numeric(stats::coef(fit$model)), fit$coefficients$estimate,
          tolerance = 0, check.attributes = FALSE
        )) || any(!is.finite(stats::coef(fit$model)))) {
      phase19_club_goal_model_abort(
        "negative_binomial_not_converged",
        "Club negative-binomial fit object, coefficients, or theta drifted"
      )
    }
  }
  invisible(fit)
}

phase19_club_goal_fixture_rows <- function(fit, fixtures, declared_fixture_ids) {
  phase19_validate_club_goal_fit(fit)
  required <- c(
    "fixture_id", "forecast_domain", "authority_mode", "boundary_id",
    "kickoff_utc", "evidence_cutoff_exclusive", "home_club_id", "away_club_id",
    "rating_difference", "pre_batch_state_sha256", "batch_sha256",
    "parameter_sha256", "training_snapshot_sha256", "current_snapshot_sha256"
  )
  if (!is.data.frame(fixtures) || !nrow(fixtures) ||
      length(setdiff(required, names(fixtures))) ||
      anyDuplicated(as.character(fixtures$fixture_id)) ||
      any(as.character(fixtures$forecast_domain) != "club") ||
      any(as.character(fixtures$authority_mode) != fit$authority_mode)) {
    phase19_club_goal_model_abort(
      "invalid_fixture_inventory", "Prediction fixtures are incomplete, duplicate, or mixed-domain"
    )
  }
  forbidden <- intersect(names(fixtures), fit$unavailable_feature_ids)
  if (length(forbidden)) {
    phase19_club_goal_model_abort(
      "unavailable_feature_active",
      paste0("Prediction fixtures contain unavailable club enrichment fields: ",
             paste(sort(forbidden, method = "radix"), collapse = ", "))
    )
  }
  declared_fixture_ids <- as.character(declared_fixture_ids)
  if (!length(declared_fixture_ids) || anyNA(declared_fixture_ids) ||
      any(!nzchar(declared_fixture_ids)) || anyDuplicated(declared_fixture_ids) ||
      !identical(declared_fixture_ids, sort(declared_fixture_ids, method = "radix")) ||
      !setequal(declared_fixture_ids, as.character(fixtures$fixture_id))) {
    phase19_club_goal_model_abort(
      "fixture_coverage_mismatch",
      "Observed fixtures must equal the unique canonical declared fixture inventory"
    )
  }
  fixtures <- fixtures[match(declared_fixture_ids, fixtures$fixture_id), , drop = FALSE]
  rownames(fixtures) <- NULL
  if (any(as.character(fixtures$evidence_cutoff_exclusive) != fit$cutoff_utc) ||
      any(as.character(fixtures$training_snapshot_sha256) != fit$training_snapshot_sha256) ||
      any(as.character(fixtures$current_snapshot_sha256) != fit$current_snapshot_sha256) ||
      any(as.character(fixtures$parameter_sha256) != fit$rating_parameter_sha256)) {
    phase19_club_goal_model_abort(
      "fixture_parent_mismatch", "Fixture cutoff or rating parents differ from the fit"
    )
  }
  if (identical(fit$model_id, "club_elo_nb") &&
      any(!is.finite(suppressWarnings(as.numeric(fixtures$rating_difference))))) {
    phase19_club_goal_model_abort(
      "invalid_prediction_feature", "club_elo_nb requires finite rating_difference values"
    )
  }
  fixtures
}

phase19_club_goal_nb_means <- function(fit, fixtures) {
  home <- data.frame(
    elo_difference_for_team = as.numeric(fixtures$rating_difference),
    venue_role = factor("home", levels = c("away", "home")),
    stringsAsFactors = FALSE
  )
  away <- data.frame(
    elo_difference_for_team = -as.numeric(fixtures$rating_difference),
    venue_role = factor("away", levels = c("away", "home")),
    stringsAsFactors = FALSE
  )
  if (identical(fit$model_id, "club_venue_nb")) {
    home <- home["venue_role"]
    away <- away["venue_role"]
  }
  home_mean <- tryCatch(
    as.numeric(stats::predict(fit$model, newdata = home, type = "response")),
    error = function(error) error
  )
  away_mean <- tryCatch(
    as.numeric(stats::predict(fit$model, newdata = away, type = "response")),
    error = function(error) error
  )
  if (inherits(home_mean, "error") || inherits(away_mean, "error") ||
      length(home_mean) != nrow(fixtures) || length(away_mean) != nrow(fixtures) ||
      any(!is.finite(home_mean) | home_mean <= 0) ||
      any(!is.finite(away_mean) | away_mean <= 0)) {
    phase19_club_goal_model_abort(
      "negative_binomial_prediction_failed",
      "Club negative-binomial prediction produced invalid goal means"
    )
  }
  list(home = home_mean, away = away_mean)
}

phase19_club_goal_distribution <- function(fit, fixture_id, home_mean, away_mean) {
  goals <- 0:fit$support_max
  home <- stats::dnbinom(goals, size = fit$theta, mu = home_mean)
  away <- stats::dnbinom(goals, size = fit$theta, mu = away_mean)
  raw <- outer(home, away)
  raw_mass <- sum(raw)
  if (!is.finite(raw_mass) || raw_mass <= 0 || raw_mass > 1 + 1e-8) {
    phase19_club_goal_model_abort(
      "invalid_probability_mass", "Negative-binomial grid has invalid raw mass"
    )
  }
  grid <- expand.grid(
    home_goals = goals, away_goals = goals,
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  grid$probability <- as.vector(raw / raw_mass)
  grid$fixture_id <- fixture_id
  grid$score_distribution_id <- paste0(fixture_id, "__", fit$model_id, "__score")
  grid$model_id <- fit$model_id
  grid$support_max_home <- fit$support_max
  grid$support_max_away <- fit$support_max
  grid$raw_tail_mass <- max(0, 1 - raw_mass)
  grid$normalized <- TRUE
  grid$tail_policy <- fit$tail_policy
  grid$fit_sha256 <- fit$fit_sha256
  grid <- grid[, c(
    "fixture_id", "score_distribution_id", "model_id", "home_goals",
    "away_goals", "probability", "support_max_home", "support_max_away",
    "raw_tail_mass", "normalized", "tail_policy", "fit_sha256"
  )]
  grid <- grid[order(grid$home_goals, grid$away_goals, method = "radix"), , drop = FALSE]
  rownames(grid) <- NULL
  validate_scoreline_distribution(
    grid, tolerance = 1e-10, support_max = fit$support_max,
    require_full_rectangle = TRUE
  )
}

phase19_club_goal_grid_markets <- function(grid) {
  markets <- derive_binary_markets(grid, tolerance = 1e-10)
  modal <- grid[which.max(grid$probability), , drop = FALSE]
  list(
    p_home = sum(grid$probability[grid$home_goals > grid$away_goals]),
    p_draw = sum(grid$probability[grid$home_goals == grid$away_goals]),
    p_away = sum(grid$probability[grid$home_goals < grid$away_goals]),
    p_over_2_5 = markets$p_over_2_5, p_btts = markets$p_btts,
    expected_home_goals = sum(grid$home_goals * grid$probability),
    expected_away_goals = sum(grid$away_goals * grid$probability),
    likely_home_goals = as.integer(modal$home_goals),
    likely_away_goals = as.integer(modal$away_goals)
  )
}

phase19_club_goal_prediction_row_hash <- function(predictions) {
  phase18_hash_row_v2(
    predictions, exclude = "prediction_sha256",
    schema_tag = "phase19-club-goal-prediction-row-v1"
  )
}

#' Predict a complete declared fixture inventory from one club goal fit.
#'
#' @export
phase19_predict_club_goal_model <- function(fit, fixtures, declared_fixture_ids) {
  phase19_club_goal_require_dependencies()
  fixtures <- phase19_club_goal_fixture_rows(fit, fixtures, declared_fixture_ids)
  distributions <- list()
  prediction_rows <- vector("list", nrow(fixtures))
  means <- if (identical(fit$model_family, "negative_binomial")) {
    phase19_club_goal_nb_means(fit, fixtures)
  } else NULL

  for (index in seq_len(nrow(fixtures))) {
    fixture_id <- as.character(fixtures$fixture_id[[index]])
    grid <- NULL
    if (identical(fit$model_family, "negative_binomial")) {
      grid <- phase19_club_goal_distribution(
        fit, fixture_id, means$home[[index]], means$away[[index]]
      )
    } else if (identical(fit$model_id, "expanding_1x2")) {
      grid <- fit$empirical_grid
      grid$fixture_id <- fixture_id
      grid$score_distribution_id <- paste0(fixture_id, "__", fit$model_id, "__score")
      grid$model_id <- fit$model_id
      grid$support_max_home <- fit$support_max
      grid$support_max_away <- fit$support_max
      grid$raw_tail_mass <- 0
      grid$normalized <- TRUE
      grid$tail_policy <- fit$tail_policy
      grid$fit_sha256 <- fit$fit_sha256
      grid <- grid[, c(
        "fixture_id", "score_distribution_id", "model_id", "home_goals",
        "away_goals", "probability", "support_max_home", "support_max_away",
        "raw_tail_mass", "normalized", "tail_policy", "fit_sha256"
      )]
    }
    if (is.null(grid)) {
      market <- list(
        p_home = 1 / 3, p_draw = 1 / 3, p_away = 1 / 3,
        p_over_2_5 = NA_real_, p_btts = NA_real_,
        expected_home_goals = NA_real_, expected_away_goals = NA_real_,
        likely_home_goals = NA_integer_, likely_away_goals = NA_integer_
      )
      distribution_id <- ""
      distribution_sha256 <- ""
      raw_tail_mass <- NA_real_
      prediction_status <- "ready_report_only"
    } else {
      grid <- grid[order(grid$home_goals, grid$away_goals, method = "radix"), , drop = FALSE]
      rownames(grid) <- NULL
      market <- phase19_club_goal_grid_markets(grid)
      distribution_id <- as.character(grid$score_distribution_id[[1L]])
      distribution_sha256 <- phase18_hash_table_v2(
        grid, key = c("fixture_id", "home_goals", "away_goals"),
        schema_tag = "phase19-club-goal-distribution-v1"
      )
      raw_tail_mass <- as.numeric(grid$raw_tail_mass[[1L]])
      prediction_status <- "ready_goal_distribution"
      distributions[[length(distributions) + 1L]] <- grid
    }
    prediction_rows[[index]] <- data.frame(
      fixture_id = fixture_id, forecast_domain = "club",
      authority_mode = fit$authority_mode,
      fixture_authority = fit$fixture_authority,
      promotion_eligible = fit$promotion_eligible,
      promotion_comparable = fit$promotion_comparable,
      model_id = fit$model_id, model_family = fit$model_family,
      output_capability = fit$output_capability,
      goal_distribution_declared = fit$goal_distribution_declared,
      prediction_status = prediction_status,
      boundary_id = as.character(fixtures$boundary_id[[index]]),
      evidence_cutoff_exclusive = as.character(fixtures$evidence_cutoff_exclusive[[index]]),
      home_club_id = as.character(fixtures$home_club_id[[index]]),
      away_club_id = as.character(fixtures$away_club_id[[index]]),
      score_distribution_id = distribution_id,
      p_home = market$p_home, p_draw = market$p_draw, p_away = market$p_away,
      p_over_2_5 = market$p_over_2_5, p_btts = market$p_btts,
      expected_home_goals = market$expected_home_goals,
      expected_away_goals = market$expected_away_goals,
      likely_home_goals = market$likely_home_goals,
      likely_away_goals = market$likely_away_goals,
      raw_tail_mass = raw_tail_mass,
      support_max = fit$support_max,
      fit_sha256 = fit$fit_sha256,
      rating_evidence_sha256 = fit$rating_evidence_sha256,
      training_snapshot_sha256 = fit$training_snapshot_sha256,
      current_snapshot_sha256 = fit$current_snapshot_sha256,
      protocol_sha256 = fit$protocol_sha256,
      fallback_status = fit$fallback_status,
      distribution_sha256 = distribution_sha256,
      prediction_sha256 = "",
      stringsAsFactors = FALSE, check.names = FALSE
    )
  }
  predictions <- do.call(rbind, prediction_rows)
  rownames(predictions) <- NULL
  predictions$prediction_sha256 <- phase19_club_goal_prediction_row_hash(predictions)
  distributions <- if (length(distributions)) {
    value <- do.call(rbind, distributions)
    rownames(value) <- NULL
    value
  } else {
    data.frame(
      fixture_id = character(), score_distribution_id = character(),
      model_id = character(), home_goals = integer(), away_goals = integer(),
      probability = numeric(), support_max_home = integer(),
      support_max_away = integer(), raw_tail_mass = numeric(),
      normalized = logical(), tail_policy = character(), fit_sha256 = character(),
      stringsAsFactors = FALSE, check.names = FALSE
    )
  }
  prediction_hash <- phase18_hash_table_v2(
    predictions, key = "fixture_id",
    schema_tag = "phase19-club-goal-predictions-v1"
  )
  distribution_hash <- if (nrow(distributions)) {
    phase18_hash_table_v2(
      distributions, key = c("fixture_id", "home_goals", "away_goals"),
      schema_tag = "phase19-club-goal-distributions-v1"
    )
  } else ""
  result <- structure(list(
    schema_version = "phase19-club-goal-prediction-set-v1",
    hash_encoding_version = phase18_canonical_encoding_v2(),
    forecast_domain = "club", authority_mode = fit$authority_mode,
    fixture_authority = fit$fixture_authority,
    promotion_eligible = fit$promotion_eligible,
    promotion_comparable = fit$promotion_comparable,
    model_id = fit$model_id, output_capability = fit$output_capability,
    goal_distribution_declared = fit$goal_distribution_declared,
    declared_fixture_ids = as.character(declared_fixture_ids),
    fit_sha256 = fit$fit_sha256,
    predictions = predictions, distributions = distributions,
    prediction_table_sha256 = prediction_hash,
    distribution_table_sha256 = distribution_hash
  ), class = c("phase19_club_goal_predictions", "list"))
  phase19_validate_club_goal_predictions(
    result, declared_fixture_ids,
    require_goal_grid = isTRUE(fit$goal_distribution_declared)
  )
  result
}

#' Validate exact fixture/grid coverage and recompute every derived market.
#'
#' @export
phase19_validate_club_goal_predictions <- function(result,
                                                   declared_fixture_ids,
                                                   require_goal_grid = TRUE) {
  phase19_club_goal_require_dependencies()
  if (!inherits(result, "phase19_club_goal_predictions") ||
      !identical(result$forecast_domain, "club") ||
      !is.data.frame(result$predictions) ||
      !is.data.frame(result$distributions)) {
    phase19_club_goal_model_abort(
      "invalid_prediction_set", "Club goal prediction set structure is invalid"
    )
  }
  declared_fixture_ids <- as.character(declared_fixture_ids)
  observed <- as.character(result$predictions$fixture_id)
  if (!length(declared_fixture_ids) || anyDuplicated(declared_fixture_ids) ||
      !identical(declared_fixture_ids, sort(declared_fixture_ids, method = "radix")) ||
      anyDuplicated(observed) || !identical(observed, declared_fixture_ids) ||
      any(as.character(result$predictions$forecast_domain) != "club")) {
    phase19_club_goal_model_abort(
      "fixture_coverage_mismatch", "Prediction rows do not exactly cover declared fixtures"
    )
  }
  expected_prediction_hashes <- phase19_club_goal_prediction_row_hash(result$predictions)
  if (!identical(as.character(result$predictions$prediction_sha256),
                 expected_prediction_hashes)) {
    phase19_club_goal_model_abort(
      "prediction_hash_mismatch", "Prediction row identity is invalid"
    )
  }
  observed_prediction_hash <- phase18_hash_table_v2(
    result$predictions, key = "fixture_id",
    schema_tag = "phase19-club-goal-predictions-v1"
  )
  if (!identical(result$prediction_table_sha256, observed_prediction_hash)) {
    phase19_club_goal_model_abort(
      "prediction_hash_mismatch", "Prediction table identity is invalid"
    )
  }
  if (isTRUE(require_goal_grid)) {
    if (nrow(result$distributions) != length(declared_fixture_ids) * 1681L ||
        any(!as.character(result$distributions$fixture_id) %in% declared_fixture_ids)) {
      phase19_club_goal_model_abort(
        "grid_coverage_mismatch", "Goal distributions require exactly 1,681 cells per fixture"
      )
    }
    counts <- table(factor(
      result$distributions$fixture_id, levels = declared_fixture_ids
    ))
    if (any(as.integer(counts) != 1681L)) {
      phase19_club_goal_model_abort(
        "grid_coverage_mismatch", "Goal distribution cell coverage is incomplete"
      )
    }
    for (fixture_id in declared_fixture_ids) {
      row <- result$predictions[result$predictions$fixture_id == fixture_id, , drop = FALSE]
      grid <- result$distributions[
        result$distributions$fixture_id == fixture_id, , drop = FALSE
      ]
      valid <- tryCatch(
        validate_scoreline_distribution(
          grid, tolerance = 1e-10, support_max = 40L,
          require_full_rectangle = TRUE
        ),
        error = function(error) error
      )
      if (inherits(valid, "error")) {
        phase19_club_goal_model_abort(
          "invalid_probability_mass", conditionMessage(valid)
        )
      }
      markets <- phase19_club_goal_grid_markets(grid)
      fields <- c(
        "p_home", "p_draw", "p_away", "p_over_2_5", "p_btts",
        "expected_home_goals", "expected_away_goals"
      )
      if (any(abs(as.numeric(row[1L, fields]) -
                  as.numeric(unlist(markets[fields], use.names = FALSE))) > 1e-10) ||
          !identical(as.integer(row$likely_home_goals), markets$likely_home_goals) ||
          !identical(as.integer(row$likely_away_goals), markets$likely_away_goals)) {
        phase19_club_goal_model_abort(
          "derived_market_mismatch", "Stored markets do not derive from the stored grid"
        )
      }
      grid_hash <- phase18_hash_table_v2(
        grid, key = c("fixture_id", "home_goals", "away_goals"),
        schema_tag = "phase19-club-goal-distribution-v1"
      )
      if (!identical(as.character(row$distribution_sha256), grid_hash)) {
        phase19_club_goal_model_abort(
          "distribution_hash_mismatch", "Fixture distribution identity is invalid"
        )
      }
    }
    observed_distribution_hash <- phase18_hash_table_v2(
      result$distributions, key = c("fixture_id", "home_goals", "away_goals"),
      schema_tag = "phase19-club-goal-distributions-v1"
    )
    if (!identical(result$distribution_table_sha256, observed_distribution_hash)) {
      phase19_club_goal_model_abort(
        "distribution_hash_mismatch", "Distribution table identity is invalid"
      )
    }
  } else if (nrow(result$distributions)) {
    phase19_club_goal_model_abort(
      "capability_mismatch", "A non-goal report-only control cannot carry a score grid"
    )
  }
  invisible(result)
}

#' Fit and predict one frozen club registry row at one boundary.
#'
#' @export
phase19_dispatch_club_goal_model <- function(registration, training_snapshot,
                                             rating_evidence, protocol,
                                             cutoff_utc, fixtures,
                                             declared_fixture_ids) {
  fit <- phase19_fit_club_goal_model(
    registration, training_snapshot, rating_evidence, protocol, cutoff_utc
  )
  list(
    fit = fit,
    prediction = phase19_predict_club_goal_model(
      fit, fixtures, declared_fixture_ids
    )
  )
}
