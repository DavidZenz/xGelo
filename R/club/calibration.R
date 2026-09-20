#' Club-owned, nested prior-only 1X2 calibration.
#'
#' The calibrator in this module is intentionally independent of the national
#' team calibration authority.  It transforms only a derived 1X2 view and
#' carries the source goal-distribution identity through unchanged.

phase19_club_calibration_abort <- function(reason_code, message, data = list()) {
  stop(structure(
    c(list(message = as.character(message), call = NULL,
           reason_code = as.character(reason_code)), data),
    class = c("phase19_club_calibration_error", "error", "condition")
  ))
}

phase19_club_calibration_require_dependencies <- function() {
  required <- c(
    "phase18_canonical_encoding_v2", "phase18_hash_sequence_v2",
    "phase18_hash_row_v2", "phase18_hash_table_v2",
    "phase18_history_logical",
    "phase19_is_sha256", "phase19_fold_row_sha256",
    "phase19_validate_fold_role_evidence", "phase19_validate_fold_prediction_coverage",
    "phase19_expected_calibration_recipe", "phase19_validate_calibration_recipe",
    "validate_probability_vector"
  )
  missing <- required[!vapply(required, exists, logical(1), mode = "function")]
  if (length(missing)) {
    phase19_club_calibration_abort(
      "calibration_dependency_missing",
      paste0("Phase 19 calibration dependencies must be sourced first: ",
             paste(missing, collapse = ", "))
    )
  }
  invisible(TRUE)
}

phase19_club_calibration_source_schema <- function() {
  c(
    "fixture_id", "candidate_id", "outer_fold_id", "inner_fold_id",
    "evidence_role", "competition_id", "event_date", "kickoff_utc",
    "kickoff_precision", "completion_not_before_utc",
    "evidence_available_at_utc", "counts_for_model", "p_home_raw",
    "p_draw_raw", "p_away_raw", "observed_class", "source_grid_sha256",
    "source_prediction_sha256"
  )
}

#' Canonical row identity for inner out-of-fold calibration predictions.
#' @export
phase19_club_calibration_source_row_sha256 <- function(rows) {
  phase19_club_calibration_require_dependencies()
  if (!is.data.frame(rows) ||
      !identical(names(rows), phase19_club_calibration_source_schema())) {
    phase19_club_calibration_abort(
      "source_prediction_schema_invalid",
      "Club calibration source-prediction schema is not exact"
    )
  }
  phase18_hash_row_v2(
    rows, exclude = "source_prediction_sha256",
    schema_tag = "phase19-club-calibration-source-row-v1"
  )
}

phase19_club_calibration_source_table_sha256 <- function(rows) {
  expected <- phase19_club_calibration_source_row_sha256(rows)
  if (!identical(as.character(rows$source_prediction_sha256), expected)) {
    phase19_club_calibration_abort(
      "source_prediction_hash_mismatch",
      "Inner OOF source prediction content does not match its canonical hash"
    )
  }
  phase18_hash_table_v2(
    rows, key = "fixture_id",
    schema_tag = "phase19-club-calibration-source-table-v1"
  )
}

phase19_club_calibration_audit_source_sha256 <- function(rows) {
  if (is.data.frame(rows) &&
      identical(names(rows), phase19_club_calibration_source_schema()) &&
      nrow(rows) && !anyDuplicated(as.character(rows$fixture_id)) &&
      all(nzchar(as.character(rows$fixture_id)))) {
    return(phase18_hash_table_v2(
      rows, key = "fixture_id",
      schema_tag = "phase19-club-calibration-untrusted-source-table-v1"
    ))
  }
  phase19_club_calibration_hash_values(
    list(
      schema = paste(if (is.data.frame(rows)) names(rows) else class(rows), collapse = "|"),
      row_count = as.integer(if (is.data.frame(rows)) nrow(rows) else 0L)
    ),
    "phase19-club-calibration-untrusted-source-summary-v1"
  )
}

phase19_club_calibration_hash_values <- function(values, domain) {
  phase18_hash_sequence_v2(
    values, domain = domain, names = names(values),
    types = vapply(values, phase18_v2_type_tag, character(1))
  )
}

phase19_club_calibrator_schema <- function() {
  c(
    "schema_version", "hash_encoding_version", "forecast_domain",
    "authority_mode", "fixture_authority", "production_eligible",
    "authoritative", "candidate_id", "candidate_registry_role",
    "selection_role", "goal_distribution_declared", "fold_id", "fold_family",
    "assessment_competition_id", "assessment_season_id",
    "held_out_competition_id", "fit_status", "failure_reason_code",
    "temperature", "initial_temperature", "temperature_lower",
    "temperature_upper", "row_count", "class_count_home", "class_count_draw",
    "class_count_away", "inner_fold_ids", "calibration_cutoff_exclusive",
    "max_completion_not_before_utc", "max_evidence_available_at_utc",
    "recipe_sha256", "optimizer_seed_id", "optimizer_seed",
    "optimizer_method", "optimizer_convergence", "optimizer_value",
    "source_predictions_sha256", "source_grids_sha256", "fold_row_sha256",
    "candidate_row_sha256", "candidate_registry_sha256",
    "seed_registry_sha256", "protocol_sha256", "policy_review_sha256",
    "probability_view", "distribution_unchanged", "labels_embedded",
    "calibrator_sha256"
  )
}

phase19_club_calibrator_sha256 <- function(calibrator) {
  schema <- phase19_club_calibrator_schema()
  if (!is.list(calibrator) || !identical(names(calibrator), schema)) {
    phase19_club_calibration_abort(
      "calibrator_schema_invalid", "Club calibrator schema is not exact"
    )
  }
  values <- calibrator[setdiff(schema, "calibrator_sha256")]
  phase19_club_calibration_hash_values(values, "phase19-club-calibrator-v1")
}

phase19_club_calibration_protocol_context <- function(candidate, fold, protocol,
                                                       recipe) {
  if (!is.data.frame(fold) || nrow(fold) != 1L ||
      !identical(names(fold), phase19_fold_registry_schema()) ||
      !identical(as.character(fold$row_sha256), phase19_fold_row_sha256(fold))) {
    phase19_club_calibration_abort(
      "fold_identity_invalid", "Calibration requires one canonical frozen fold row"
    )
  }
  if (!inherits(protocol, "phase19_club_evaluation_protocol") ||
      !identical(protocol$status, "ready") ||
      !identical(protocol$forecast_domain, "club") ||
      !is.data.frame(protocol$candidate_registry) ||
      !is.data.frame(protocol$seed_registry)) {
    phase19_club_calibration_abort(
      "protocol_authority_invalid", "Calibration requires a validated ready club protocol"
    )
  }
  if (!identical(as.character(fold$authority_mode),
                 as.character(protocol$authority_mode)) ||
      !identical(isTRUE(fold$fixture_authority), isTRUE(protocol$fixture_authority)) ||
      !identical(as.character(fold$protocol_sha256),
                 as.character(protocol$protocol_sha256)) ||
      !identical(as.character(fold$policy_review_sha256),
                 as.character(protocol$policy_review$review_sha256))) {
    phase19_club_calibration_abort(
      "protocol_parent_mismatch", "Fold and evaluation-protocol authority do not agree"
    )
  }
  phase19_validate_calibration_recipe(recipe)
  if (!identical(as.character(fold$calibration_recipe_sha256),
                 as.character(recipe$recipe_sha256))) {
    phase19_club_calibration_abort(
      "recipe_parent_mismatch", "Fold does not bind the exact calibration recipe"
    )
  }
  if (!is.data.frame(candidate) || nrow(candidate) != 1L ||
      !identical(names(candidate), names(protocol$candidate_registry))) {
    phase19_club_calibration_abort(
      "candidate_identity_invalid", "Calibration requires one exact registered candidate row"
    )
  }
  registered <- protocol$candidate_registry[
    protocol$candidate_registry$model_id == candidate$model_id[[1L]], , drop = FALSE
  ]
  rownames(registered) <- NULL
  canonical_candidate <- candidate
  rownames(canonical_candidate) <- NULL
  if (nrow(registered) != 1L || !identical(canonical_candidate, registered)) {
    phase19_club_calibration_abort(
      "candidate_identity_invalid", "Calibration candidate is not the frozen registry row"
    )
  }
  seed <- protocol$seed_registry[
    protocol$seed_registry$seed_id == recipe$optimizer_seed_id, , drop = FALSE
  ]
  if (nrow(seed) != 1L || !identical(as.character(seed$selection_stage),
                                     "inner_out_of_fold")) {
    phase19_club_calibration_abort(
      "optimizer_seed_invalid", "Calibration seed is absent or assigned to another stage"
    )
  }
  list(candidate = canonical_candidate, seed = seed)
}

phase19_club_calibration_support <- function(rows) {
  counts <- table(factor(as.character(rows$observed_class),
                         levels = c("home", "draw", "away")))
  c(home = as.integer(counts[["home"]]), draw = as.integer(counts[["draw"]]),
    away = as.integer(counts[["away"]]))
}

phase19_club_calibration_grid_hash <- function(rows) {
  grids <- sort(unique(as.character(rows$source_grid_sha256)), method = "radix")
  phase19_club_calibration_hash_values(
    as.list(grids) |> setNames(sprintf("grid_%05d", seq_along(grids))),
    "phase19-club-calibration-source-grids-v1"
  )
}

phase19_club_calibration_validate_rows <- function(rows, fold, candidate) {
  schema <- phase19_club_calibration_source_schema()
  if (!is.data.frame(rows) || !identical(names(rows), schema) || !nrow(rows)) {
    phase19_club_calibration_abort(
      "source_prediction_schema_invalid", "Inner OOF source predictions are empty or non-canonical"
    )
  }
  character_fields <- setdiff(
    schema, c("counts_for_model", "p_home_raw", "p_draw_raw", "p_away_raw")
  )
  if (any(!vapply(rows[character_fields], is.character, logical(1))) ||
      !is.logical(rows$counts_for_model) ||
      any(!vapply(rows[c("p_home_raw", "p_draw_raw", "p_away_raw")],
                  is.numeric, logical(1))) || anyNA(rows)) {
    phase19_club_calibration_abort(
      "source_prediction_schema_invalid", "Inner OOF source-prediction types are invalid"
    )
  }
  if (anyDuplicated(rows$fixture_id) || any(!nzchar(rows$fixture_id)) ||
      any(rows$candidate_id != candidate$model_id[[1L]]) ||
      any(rows$outer_fold_id != fold$fold_id[[1L]]) ||
      any(rows$evidence_role != "inner_out_of_fold") ||
      any(!nzchar(rows$inner_fold_id)) || length(unique(rows$inner_fold_id)) < 2L ||
      any(!rows$observed_class %in% c("home", "draw", "away"))) {
    phase19_club_calibration_abort(
      "nested_role_invalid", "Calibration rows do not form one nested inner OOF candidate/fold set"
    )
  }
  expected_hash <- phase19_club_calibration_source_row_sha256(rows)
  if (!identical(as.character(rows$source_prediction_sha256), expected_hash) ||
      any(!vapply(rows$source_prediction_sha256, phase19_is_sha256, logical(1)))) {
    phase19_club_calibration_abort(
      "source_prediction_hash_mismatch", "Inner OOF source-prediction hash drifted"
    )
  }
  if (isTRUE(candidate$goal_distribution_declared[[1L]])) {
    if (any(!vapply(rows$source_grid_sha256, phase19_is_sha256, logical(1)))) {
      phase19_club_calibration_abort(
        "source_grid_identity_invalid", "Goal-capable candidate lacks source grid identity"
      )
    }
  } else if (any(nzchar(rows$source_grid_sha256))) {
    phase19_club_calibration_abort(
      "source_grid_identity_invalid", "Non-goal candidate cannot claim source grid identity"
    )
  }
  for (index in seq_len(nrow(rows))) {
    validate_probability_vector(
      c(home = rows$p_home_raw[[index]], draw = rows$p_draw_raw[[index]],
        away = rows$p_away_raw[[index]]),
      tolerance = 1e-10, name = "inner OOF raw 1X2 probabilities"
    )
  }
  role_rows <- rows
  role_rows$match_id <- role_rows$fixture_id
  phase19_validate_fold_role_evidence(role_rows, fold, "calibration")
  invisible(TRUE)
}

phase19_club_calibrator_object <- function(rows, fold, candidate, protocol,
                                            recipe, seed, status,
                                            reason_code = "", temperature = NA_real_,
                                            convergence = NA_integer_,
                                            optimizer_value = NA_real_) {
  support <- if (is.data.frame(rows) && "observed_class" %in% names(rows)) {
    phase19_club_calibration_support(rows)
  } else c(home = 0L, draw = 0L, away = 0L)
  safe_max <- function(field) {
    if (!is.data.frame(rows) || !field %in% names(rows) || !nrow(rows)) return("")
    values <- as.character(rows[[field]])
    if (anyNA(values) || !length(values)) "" else max(values)
  }
  source_hash <- tryCatch(
    phase19_club_calibration_source_table_sha256(rows),
    error = function(error) phase19_club_calibration_audit_source_sha256(rows)
  )
  grid_hash <- tryCatch(
    phase19_club_calibration_grid_hash(rows),
    error = function(error) ""
  )
  inner_ids <- if (is.data.frame(rows) && "inner_fold_id" %in% names(rows)) {
    paste(sort(unique(as.character(rows$inner_fold_id)), method = "radix"), collapse = "|")
  } else ""
  fitted <- identical(status, "fitted")
  production_eligible <- fitted && identical(protocol$authority_mode, "production") &&
    !isTRUE(protocol$fixture_authority) && isTRUE(protocol$production_eligible) &&
    isTRUE(candidate$release_selectable[[1L]])
  result <- list(
    schema_version = "phase19-club-calibrator-v1",
    hash_encoding_version = phase18_canonical_encoding_v2(),
    forecast_domain = "club", authority_mode = as.character(protocol$authority_mode),
    fixture_authority = isTRUE(protocol$fixture_authority),
    production_eligible = production_eligible, authoritative = fitted,
    candidate_id = as.character(candidate$model_id[[1L]]),
    candidate_registry_role = as.character(candidate$registry_role[[1L]]),
    selection_role = as.character(candidate$selection_role[[1L]]),
    goal_distribution_declared = isTRUE(candidate$goal_distribution_declared[[1L]]),
    fold_id = as.character(fold$fold_id[[1L]]),
    fold_family = as.character(fold$fold_family[[1L]]),
    assessment_competition_id = as.character(fold$assessment_competition_id[[1L]]),
    assessment_season_id = as.character(fold$assessment_season_id[[1L]]),
    held_out_competition_id = as.character(fold$held_out_competition_id[[1L]]),
    fit_status = as.character(status), failure_reason_code = as.character(reason_code),
    temperature = as.numeric(temperature),
    initial_temperature = as.numeric(recipe$initial_temperature),
    temperature_lower = as.numeric(recipe$temperature_lower),
    temperature_upper = as.numeric(recipe$temperature_upper),
    row_count = as.integer(if (is.data.frame(rows)) nrow(rows) else 0L),
    class_count_home = as.integer(support[["home"]]),
    class_count_draw = as.integer(support[["draw"]]),
    class_count_away = as.integer(support[["away"]]), inner_fold_ids = inner_ids,
    calibration_cutoff_exclusive = as.character(fold$calibration_cutoff_exclusive[[1L]]),
    max_completion_not_before_utc = safe_max("completion_not_before_utc"),
    max_evidence_available_at_utc = safe_max("evidence_available_at_utc"),
    recipe_sha256 = as.character(recipe$recipe_sha256),
    optimizer_seed_id = as.character(recipe$optimizer_seed_id),
    optimizer_seed = as.integer(seed$seed[[1L]]),
    optimizer_method = as.character(recipe$optimizer),
    optimizer_convergence = as.integer(convergence),
    optimizer_value = as.numeric(optimizer_value),
    source_predictions_sha256 = source_hash, source_grids_sha256 = grid_hash,
    fold_row_sha256 = as.character(fold$row_sha256[[1L]]),
    candidate_row_sha256 = as.character(candidate$row_sha256[[1L]]),
    candidate_registry_sha256 = as.character(protocol$candidate_registry_sha256),
    seed_registry_sha256 = as.character(protocol$seed_registry_sha256),
    protocol_sha256 = as.character(protocol$protocol_sha256),
    policy_review_sha256 = as.character(protocol$policy_review$review_sha256),
    probability_view = "derived_1x2", distribution_unchanged = TRUE,
    labels_embedded = FALSE, calibrator_sha256 = ""
  )
  result$calibrator_sha256 <- phase19_club_calibrator_sha256(result)
  structure(result, class = c("phase19_club_calibrator", "list"))
}

phase19_club_temperature_transform <- function(probabilities, temperature,
                                                epsilon = 1e-15) {
  probabilities <- validate_probability_vector(
    probabilities, tolerance = 1e-10, name = "raw club 1X2 probabilities"
  )
  temperature <- as.numeric(temperature)
  if (length(temperature) != 1L || !is.finite(temperature) || temperature <= 0) {
    phase19_club_calibration_abort(
      "temperature_invalid", "Club calibration temperature must be finite and positive"
    )
  }
  logits <- log(pmax(probabilities, as.numeric(epsilon))) / temperature
  logits <- logits - max(logits)
  value <- exp(logits)
  value <- value / sum(value)
  names(value) <- names(probabilities)
  validate_probability_vector(
    value, tolerance = 1e-10, name = "calibrated club 1X2 probabilities"
  )
}

#' Fit one deterministic club calibrator from validated inner OOF rows.
#' @export
phase19_fit_club_calibrator <- function(
    inner_oof, fold, candidate, protocol,
    recipe = phase19_expected_calibration_recipe(), optimizer_fn = stats::optim
) {
  phase19_club_calibration_require_dependencies()
  context <- tryCatch(
    phase19_club_calibration_protocol_context(candidate, fold, protocol, recipe),
    error = function(error) error
  )
  if (inherits(context, "error")) stop(context)
  candidate <- context$candidate
  seed <- context$seed
  failure <- function(reason) {
    object <- phase19_club_calibrator_object(
      inner_oof, fold, candidate, protocol, recipe, seed,
      status = "failed", reason_code = reason
    )
    phase19_validate_club_calibrator(object, require_fitted = FALSE)
    object
  }
  validated <- tryCatch({
    phase19_club_calibration_validate_rows(inner_oof, fold, candidate)
    TRUE
  }, error = function(error) error)
  if (inherits(validated, "error")) {
    reason <- if (!is.null(validated$reason_code)) {
      as.character(validated$reason_code)
    } else if (inherits(validated, "phase19_fold_contract_error")) {
      if (is.null(validated$reason_code)) "fold_role_invalid" else
        as.character(validated$reason_code)
    } else "source_prediction_invalid"
    return(failure(reason))
  }
  support <- phase19_club_calibration_support(inner_oof)
  if (nrow(inner_oof) < as.integer(recipe$minimum_history_rows) ||
      any(support < as.integer(recipe$minimum_class_count))) {
    return(failure("insufficient_history_or_class_support"))
  }
  raw <- as.matrix(inner_oof[, c("p_home_raw", "p_draw_raw", "p_away_raw")])
  observed <- match(inner_oof$observed_class, c("home", "draw", "away"))
  epsilon <- as.numeric(recipe$epsilon)
  objective <- function(parameter) {
    calibrated <- t(vapply(seq_len(nrow(raw)), function(index) {
      unname(phase19_club_temperature_transform(
        setNames(raw[index, ], c("home", "draw", "away")),
        parameter[[1L]], epsilon
      ))
    }, numeric(3)))
    value <- -sum(log(pmax(
      calibrated[cbind(seq_len(nrow(calibrated)), observed)], epsilon
    )))
    if (is.finite(value)) value else Inf
  }
  optimized <- tryCatch(
    optimizer_fn(
      par = as.numeric(recipe$initial_temperature), fn = objective,
      method = "L-BFGS-B", lower = as.numeric(recipe$temperature_lower),
      upper = as.numeric(recipe$temperature_upper)
    ),
    error = function(error) error
  )
  if (inherits(optimized, "error") || !is.list(optimized) ||
      length(optimized$par) != 1L || !is.finite(optimized$par[[1L]]) ||
      optimized$par[[1L]] < as.numeric(recipe$temperature_lower) ||
      optimized$par[[1L]] > as.numeric(recipe$temperature_upper) ||
      length(optimized$convergence) != 1L ||
      !identical(as.integer(optimized$convergence), 0L) ||
      length(optimized$value) != 1L || !is.finite(optimized$value)) {
    return(failure("optimizer_failed"))
  }
  result <- phase19_club_calibrator_object(
    inner_oof, fold, candidate, protocol, recipe, seed,
    status = "fitted", temperature = optimized$par[[1L]],
    convergence = optimized$convergence, optimizer_value = optimized$value
  )
  phase19_validate_club_calibrator(result, require_fitted = TRUE)
  result
}

#' Validate a durable Phase 19 club calibrator.
#' @export
phase19_validate_club_calibrator <- function(calibrator, require_fitted = FALSE) {
  phase19_club_calibration_require_dependencies()
  schema <- phase19_club_calibrator_schema()
  if (!inherits(calibrator, "phase19_club_calibrator") ||
      !is.list(calibrator) || !identical(names(calibrator), schema)) {
    phase19_club_calibration_abort(
      "calibrator_schema_invalid", "Club calibrator is not an exact typed object"
    )
  }
  if (!identical(calibrator$schema_version, "phase19-club-calibrator-v1") ||
      !identical(calibrator$hash_encoding_version, phase18_canonical_encoding_v2()) ||
      !identical(calibrator$forecast_domain, "club") ||
      !calibrator$authority_mode %in% c("fixture", "production") ||
      !identical(isTRUE(calibrator$fixture_authority),
                 identical(calibrator$authority_mode, "fixture")) ||
      !identical(calibrator$probability_view, "derived_1x2") ||
      !isTRUE(calibrator$distribution_unchanged) ||
      isTRUE(calibrator$labels_embedded)) {
    phase19_club_calibration_abort(
      "calibrator_contract_invalid", "Club calibrator domain or immutable contract drifted"
    )
  }
  hashes <- c(
    "recipe_sha256", "source_predictions_sha256", "source_grids_sha256",
    "fold_row_sha256", "candidate_row_sha256", "candidate_registry_sha256",
    "seed_registry_sha256", "protocol_sha256", "policy_review_sha256",
    "calibrator_sha256"
  )
  if (any(!vapply(calibrator[hashes], phase19_is_sha256, logical(1))) ||
      !identical(as.character(calibrator$calibrator_sha256),
                 phase19_club_calibrator_sha256(calibrator))) {
    phase19_club_calibration_abort(
      "calibrator_hash_invalid", "Club calibrator parent or self identity drifted"
    )
  }
  if (isTRUE(calibrator$fixture_authority) && isTRUE(calibrator$production_eligible)) {
    phase19_club_calibration_abort(
      "fixture_escalation_forbidden", "Fixture calibrator cannot become production eligible"
    )
  }
  fitted <- identical(calibrator$fit_status, "fitted")
  if (isTRUE(require_fitted) && !fitted) {
    phase19_club_calibration_abort(
      "calibrator_not_fitted", "Only a fitted calibrator is usable authority"
    )
  }
  if (fitted) {
    counts <- c(calibrator$class_count_home, calibrator$class_count_draw,
                calibrator$class_count_away)
    if (!isTRUE(calibrator$authoritative) ||
        nzchar(calibrator$failure_reason_code) ||
        !is.finite(calibrator$temperature) ||
        calibrator$temperature < calibrator$temperature_lower ||
        calibrator$temperature > calibrator$temperature_upper ||
        !identical(calibrator$optimizer_method, "stats::optim-L-BFGS-B") ||
        !identical(as.integer(calibrator$optimizer_convergence), 0L) ||
        !is.finite(calibrator$optimizer_value) || calibrator$row_count < 60L ||
        any(counts < 10L) || !nzchar(calibrator$inner_fold_ids)) {
      phase19_club_calibration_abort(
        "fitted_calibrator_invalid", "Fitted calibrator support or optimizer state is invalid"
      )
    }
  } else if (identical(calibrator$fit_status, "failed")) {
    if (isTRUE(calibrator$authoritative) || isTRUE(calibrator$production_eligible) ||
        !nzchar(calibrator$failure_reason_code) || is.finite(calibrator$temperature) ||
        !is.na(calibrator$optimizer_convergence) || is.finite(calibrator$optimizer_value)) {
      phase19_club_calibration_abort(
        "failed_calibrator_invalid", "Failed calibrator claims fit or promotion authority"
      )
    }
  } else {
    phase19_club_calibration_abort(
      "calibrator_status_invalid", "Club calibrator fit status is not closed"
    )
  }
  invisible(calibrator)
}

phase19_club_calibration_prediction_hash <- function(predictions, tag) {
  phase18_hash_table_v2(
    predictions, key = "fixture_id",
    schema_tag = paste0("phase19-club-calibration-", tag, "-v1")
  )
}

#' Apply a fitted calibrator to the exact later assessment inventory.
#' @export
phase19_apply_club_calibrator <- function(calibrator, predictions, fold) {
  phase19_validate_club_calibrator(calibrator, require_fitted = TRUE)
  if (!is.data.frame(fold) || nrow(fold) != 1L ||
      !identical(as.character(fold$row_sha256), calibrator$fold_row_sha256) ||
      !identical(as.character(fold$fold_id), calibrator$fold_id)) {
    phase19_club_calibration_abort(
      "fold_identity_invalid", "Application fold differs from fitted calibrator"
    )
  }
  required <- c(
    "fixture_id", "candidate_id", "evidence_cutoff_exclusive",
    "p_home", "p_draw", "p_away", "distribution_sha256"
  )
  if (!is.data.frame(predictions) || !nrow(predictions) ||
      length(setdiff(required, names(predictions))) || anyNA(predictions[required])) {
    phase19_club_calibration_abort(
      "assessment_prediction_invalid", "Assessment prediction view is empty or incomplete"
    )
  }
  phase19_validate_fold_prediction_coverage(fold, predictions$fixture_id)
  if (any(predictions$candidate_id != calibrator$candidate_id)) {
    phase19_club_calibration_abort(
      "candidate_identity_invalid", "Assessment prediction candidate differs from calibrator"
    )
  }
  application_cutoff <- phase19_fold_parse_utc(
    predictions$evidence_cutoff_exclusive, "assessment evidence cutoff"
  )
  calibration_cutoff <- phase19_fold_parse_utc(
    calibrator$calibration_cutoff_exclusive, "calibration cutoff"
  )[[1L]]
  if (any(application_cutoff < calibration_cutoff)) {
    phase19_club_calibration_abort(
      "application_not_later", "Calibrator can apply only to its later assessment inventory"
    )
  }
  if (isTRUE(calibrator$goal_distribution_declared)) {
    if (any(!vapply(predictions$distribution_sha256,
                    phase19_is_sha256, logical(1)))) {
      phase19_club_calibration_abort(
        "source_grid_identity_invalid", "Assessment prediction lacks source-grid identity"
      )
    }
  } else if (any(nzchar(as.character(predictions$distribution_sha256)))) {
    phase19_club_calibration_abort(
      "source_grid_identity_invalid", "Non-goal candidate cannot claim a source grid"
    )
  }
  predictions <- predictions[order(predictions$fixture_id, method = "radix"), , drop = FALSE]
  rownames(predictions) <- NULL
  raw_input <- predictions
  calibrated <- t(vapply(seq_len(nrow(predictions)), function(index) {
    probability <- c(
      home = predictions$p_home[[index]], draw = predictions$p_draw[[index]],
      away = predictions$p_away[[index]]
    )
    unname(phase19_club_temperature_transform(
      probability, calibrator$temperature
    ))
  }, numeric(3)))
  result <- predictions
  result$p_home_raw <- result$p_home
  result$p_draw_raw <- result$p_draw
  result$p_away_raw <- result$p_away
  result$p_home_calibrated <- calibrated[, 1L]
  result$p_draw_calibrated <- calibrated[, 2L]
  result$p_away_calibrated <- calibrated[, 3L]
  preserved <- intersect(
    c("p_over_2_5", "p_btts", "expected_home_goals", "expected_away_goals",
      "likely_home_goals", "likely_away_goals", "raw_tail_mass"),
    names(result)
  )
  for (field in preserved) result[[paste0(field, "_raw")]] <- result[[field]]
  result$source_distribution_sha256 <- result$distribution_sha256
  result$distribution_unchanged <- TRUE
  result$calibrator_sha256 <- calibrator$calibrator_sha256
  result$probability_view_status <- "raw_and_calibrated_unselected"
  raw_hash <- phase19_club_calibration_prediction_hash(
    raw_input, "raw-assessment-predictions"
  )
  calibrated_hash <- phase19_club_calibration_prediction_hash(
    result, "calibrated-assessment-view"
  )
  structure(list(
    schema_version = "phase19-club-calibrated-view-v1",
    hash_encoding_version = phase18_canonical_encoding_v2(),
    forecast_domain = "club", authority_mode = calibrator$authority_mode,
    fixture_authority = calibrator$fixture_authority,
    production_eligible = FALSE, candidate_id = calibrator$candidate_id,
    fold_id = calibrator$fold_id, calibrator_sha256 = calibrator$calibrator_sha256,
    source_prediction_table_sha256 = raw_hash,
    calibrated_view_sha256 = calibrated_hash,
    source_distribution_sha256 = phase19_club_calibration_hash_values(
      as.list(result$source_distribution_sha256) |>
        setNames(paste0("fixture_", result$fixture_id)),
      "phase19-club-calibration-assessment-grids-v1"
    ),
    distribution_unchanged = TRUE,
    primary_probability_view = "not_selected", predictions = result
  ), class = c("phase19_club_calibrated_view", "list"))
}
