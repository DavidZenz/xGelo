#' Canonical Phase 19 club evaluation policy registries.
#'
#' This module freezes policy candidates before any assessment result exists.
#' It deliberately reuses only the canonical-v2 hashing primitive and the
#' Phase 19 club feature contract. National-team protocol objects are not
#' accepted as parents or aliases.

phase19_protocol_abort <- function(reason_code, message, data = list()) {
  stop(structure(
    c(list(message = as.character(message), call = NULL,
           reason_code = as.character(reason_code)), data),
    class = c(
      if (identical(reason_code, "protocol_policy_not_approved")) {
        "phase19_protocol_policy_not_approved"
      } else {
        "phase19_protocol_registry_error"
      },
      "phase19_protocol_error", "error", "condition"
    )
  ))
}

phase19_protocol_require_dependencies <- function() {
  required <- c(
    "phase18_canonical_encoding_v2", "phase18_hash_sequence_v2",
    "phase18_hash_row_v2", "phase18_hash_table_v2",
    "phase19_load_feature_contract", "phase19_validate_feature_contract"
  )
  missing <- required[!vapply(required, exists, logical(1), mode = "function")]
  if (length(missing)) {
    phase19_protocol_abort(
      "protocol_dependency_missing",
      paste0("Phase 19 protocol dependencies must be sourced first: ",
             paste(missing, collapse = ", "))
    )
  }
  invisible(TRUE)
}

phase19_candidate_registry_schema <- function() {
  c(
    "schema_version", "hash_encoding_version", "forecast_domain", "model_id",
    "registry_role", "selection_role", "model_family", "formula",
    "output_capability", "goal_distribution_declared", "release_selectable",
    "score_support_min", "score_support_max", "base_rating",
    "elo_k_candidates", "home_advantage_candidates",
    "inactivity_factor_candidates", "tuning_scope",
    "outer_assessment_tuning_allowed", "settings_status", "row_sha256"
  )
}

phase19_seed_registry_schema <- function() {
  c(
    "schema_version", "hash_encoding_version", "forecast_domain", "seed_id",
    "purpose", "seed", "selection_stage", "row_sha256"
  )
}

phase19_protocol_schema_sha256 <- function(schema, name) {
  phase18_hash_sequence_v2(
    as.list(as.character(schema)),
    domain = paste0("phase19-club-protocol-schema-v1:", name),
    names = sprintf("column_%03d", seq_along(schema)),
    types = rep("character", length(schema))
  )
}

phase19_candidate_row_sha256 <- function(registry) {
  phase19_protocol_require_dependencies()
  if (!is.data.frame(registry) ||
      !identical(names(registry), phase19_candidate_registry_schema())) {
    phase19_protocol_abort("candidate_registry_invalid", "Candidate registry schema is not exact")
  }
  phase18_hash_row_v2(
    registry, exclude = "row_sha256",
    schema_tag = "phase19-club-candidate-registry-row-v1"
  )
}

phase19_seed_row_sha256 <- function(registry) {
  phase19_protocol_require_dependencies()
  if (!is.data.frame(registry) ||
      !identical(names(registry), phase19_seed_registry_schema())) {
    phase19_protocol_abort("seed_registry_invalid", "Seed registry schema is not exact")
  }
  phase18_hash_row_v2(
    registry, exclude = "row_sha256",
    schema_tag = "phase19-club-seed-registry-row-v1"
  )
}

phase19_candidate_core_fields <- function() {
  c("outcome", "prior_regulation_results", "goals",
    "elo_difference_for_team", "venue_role")
}

phase19_protocol_forbidden_national_pattern <- function() {
  paste(c(
    "national[_ -]?team", "world[_ -]?cup", "fifa", "uefa[_ -]?euro",
    "open_core", "feature_rich", "wc20[0-9]{2}", "euro20[0-9]{2}",
    "frozen[_ -]?track", "updating[_ -]?track"
  ), collapse = "|")
}

phase19_protocol_assert_no_national_authority <- function(data, label) {
  values <- tolower(unlist(lapply(data, as.character), use.names = FALSE))
  values <- values[!is.na(values)]
  bad <- values[grepl(phase19_protocol_forbidden_national_pattern(), values, perl = TRUE)]
  if (length(bad)) {
    phase19_protocol_abort(
      "protocol_domain_mismatch",
      paste0(label, " imports forbidden national-team authority: ", bad[[1L]])
    )
  }
  invisible(TRUE)
}

phase19_expected_candidate_policy <- function() {
  data.frame(
    model_id = c("uniform_1x2", "expanding_1x2", "club_venue_nb", "club_elo_nb"),
    registry_role = c(
      "sanity_control", "historical_control", "promotion_incumbent", "promotion_candidate"
    ),
    selection_role = c("report_only", "report_only", "incumbent", "candidate"),
    model_family = c(
      "empirical_control", "empirical_control", "negative_binomial", "negative_binomial"
    ),
    formula = c(
      "outcome ~ 1", "outcome ~ prior_regulation_results",
      "goals ~ venue_role", "goals ~ elo_difference_for_team + venue_role"
    ),
    output_capability = c(
      "1x2_only_non_goal_distribution", "1x2_and_empirical_score_grid",
      "complete_score_distribution_and_derived_markets",
      "complete_score_distribution_and_derived_markets"
    ),
    goal_distribution_declared = c(FALSE, TRUE, TRUE, TRUE),
    release_selectable = c(FALSE, FALSE, TRUE, TRUE),
    score_support_min = c(NA_integer_, 0L, 0L, 0L),
    score_support_max = c(NA_integer_, 40L, 40L, 40L),
    base_rating = c(NA_integer_, NA_integer_, NA_integer_, 1500L),
    elo_k_candidates = c("not_applicable", "not_applicable", "not_applicable", "20|30|40"),
    home_advantage_candidates = c(
      "not_applicable", "not_applicable", "not_applicable", "40|60|80"
    ),
    inactivity_factor_candidates = c(
      "not_applicable", "not_applicable", "not_applicable", "0.99|0.995|0.999"
    ),
    tuning_scope = c("not_applicable", "not_applicable", "fixed", "inner_fold_only"),
    outer_assessment_tuning_allowed = c(FALSE, FALSE, FALSE, FALSE),
    settings_status = c(
      "fixed_exact_thirds", "fixed_weighted_prior_regulation",
      "fixed_venue_only", "predeclared_inner_selection"
    ),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

phase19_validate_candidate_registry <- function(registry, feature_contract) {
  phase19_protocol_require_dependencies()
  schema <- phase19_candidate_registry_schema()
  if (!is.data.frame(registry) || !identical(names(registry), schema)) {
    phase19_protocol_abort("candidate_registry_invalid", "Candidate registry schema is not exact")
  }
  character_fields <- setdiff(
    schema,
    c("goal_distribution_declared", "release_selectable", "score_support_min",
      "score_support_max", "base_rating", "outer_assessment_tuning_allowed")
  )
  if (any(!vapply(registry[character_fields], is.character, logical(1))) ||
      !is.logical(registry$goal_distribution_declared) ||
      !is.logical(registry$release_selectable) ||
      !is.integer(registry$score_support_min) ||
      !is.integer(registry$score_support_max) ||
      !is.integer(registry$base_rating) ||
      !is.logical(registry$outer_assessment_tuning_allowed) ||
      anyNA(registry[setdiff(schema, c("score_support_min", "score_support_max", "base_rating"))])) {
    phase19_protocol_abort("candidate_registry_invalid", "Candidate registry types or missingness are invalid")
  }
  expected_ids <- phase19_expected_candidate_policy()$model_id
  if (nrow(registry) != length(expected_ids) || anyDuplicated(registry$model_id) ||
      !setequal(as.character(registry$model_id), expected_ids)) {
    phase19_protocol_abort("candidate_registry_invalid", "Candidate model inventory is missing, duplicate, or unknown")
  }
  if (any(registry$schema_version != "phase19-club-candidate-v1") ||
      any(registry$hash_encoding_version != phase18_canonical_encoding_v2()) ||
      any(registry$forecast_domain != "club")) {
    phase19_protocol_abort("protocol_domain_mismatch", "Candidate registry metadata is not club canonical-v2")
  }
  phase19_protocol_assert_no_national_authority(registry, "Candidate registry")
  phase19_validate_feature_contract(feature_contract)

  ordered <- registry[match(expected_ids, registry$model_id), , drop = FALSE]
  rownames(ordered) <- NULL
  policy_fields <- names(phase19_expected_candidate_policy())
  expected <- phase19_expected_candidate_policy()
  if (!identical(ordered[policy_fields], expected)) {
    phase19_protocol_abort("candidate_registry_invalid", "Candidate roles, formulas, parameters, or support drifted")
  }
  roles <- as.character(ordered$registry_role)
  if (sum(roles == "promotion_incumbent") != 1L ||
      sum(roles == "promotion_candidate") != 1L ||
      !identical(ordered$model_id[roles == "promotion_incumbent"], "club_venue_nb") ||
      !identical(ordered$model_id[roles == "promotion_candidate"], "club_elo_nb")) {
    phase19_protocol_abort("candidate_registry_invalid", "Promotion incumbent or candidate role is invalid")
  }
  if (any(ordered$outer_assessment_tuning_allowed)) {
    phase19_protocol_abort("candidate_registry_invalid", "Outer assessment tuning is forbidden")
  }
  unavailable <- as.character(
    feature_contract$feature_id[
      feature_contract$availability_status != "available" |
        !feature_contract$active_in_model
    ]
  )
  for (index in seq_len(nrow(ordered))) {
    tokens <- all.vars(stats::as.formula(ordered$formula[[index]]))
    unknown <- setdiff(tokens, phase19_candidate_core_fields())
    if (length(unknown) || length(intersect(tokens, unavailable))) {
      phase19_protocol_abort(
        "candidate_registry_invalid",
        paste0("Candidate formula references unavailable or unknown fields: ",
               paste(unique(c(unknown, intersect(tokens, unavailable))), collapse = ", "))
      )
    }
  }
  expected_hashes <- phase19_candidate_row_sha256(registry)
  if (!identical(as.character(registry$row_sha256), expected_hashes) ||
      anyDuplicated(registry$row_sha256) ||
      any(!vapply(registry$row_sha256, phase19_is_sha256, logical(1)))) {
    phase19_protocol_abort("candidate_registry_invalid", "Candidate canonical row hash drifted or collided")
  }
  invisible(ordered)
}

phase19_expected_seed_policy <- function() {
  data.frame(
    seed_id = c(
      "club_candidate_tuning_v1", "club_probability_calibration_v1",
      "club_paired_bootstrap_v1", "club_isolated_replay_v1"
    ),
    purpose = c(
      "candidate_tuning", "calibration", "paired_bootstrap",
      "isolated_reproducibility_replay"
    ),
    seed = c(1903001L, 1903002L, 1903003L, 1903004L),
    selection_stage = c(
      "inner_training", "inner_out_of_fold", "post_assessment_fixed_policy",
      "isolated_replay"
    ),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

phase19_validate_seed_registry <- function(registry) {
  phase19_protocol_require_dependencies()
  schema <- phase19_seed_registry_schema()
  if (!is.data.frame(registry) || !identical(names(registry), schema)) {
    phase19_protocol_abort("seed_registry_invalid", "Seed registry schema is not exact")
  }
  character_fields <- setdiff(schema, "seed")
  if (any(!vapply(registry[character_fields], is.character, logical(1))) ||
      !is.integer(registry$seed) || anyNA(registry)) {
    phase19_protocol_abort("seed_registry_invalid", "Seed registry types or missingness are invalid")
  }
  expected_ids <- phase19_expected_seed_policy()$seed_id
  if (nrow(registry) != length(expected_ids) || anyDuplicated(registry$seed_id) ||
      anyDuplicated(registry$purpose) || anyDuplicated(registry$seed) ||
      !setequal(as.character(registry$seed_id), expected_ids) ||
      any(registry$seed <= 0L)) {
    phase19_protocol_abort("seed_registry_invalid", "Seed inventory, purpose, or values are invalid")
  }
  if (any(registry$schema_version != "phase19-club-seed-v1") ||
      any(registry$hash_encoding_version != phase18_canonical_encoding_v2()) ||
      any(registry$forecast_domain != "club")) {
    phase19_protocol_abort("protocol_domain_mismatch", "Seed registry metadata is not club canonical-v2")
  }
  phase19_protocol_assert_no_national_authority(registry, "Seed registry")
  ordered <- registry[match(expected_ids, registry$seed_id), , drop = FALSE]
  rownames(ordered) <- NULL
  policy_fields <- names(phase19_expected_seed_policy())
  if (!identical(ordered[policy_fields], phase19_expected_seed_policy()) ||
      any(ordered$selection_stage == "outer_assessment")) {
    phase19_protocol_abort("seed_registry_invalid", "Seed purposes, values, or stages drifted")
  }
  expected_hashes <- phase19_seed_row_sha256(registry)
  if (!identical(as.character(registry$row_sha256), expected_hashes) ||
      anyDuplicated(registry$row_sha256) ||
      any(!vapply(registry$row_sha256, phase19_is_sha256, logical(1)))) {
    phase19_protocol_abort("seed_registry_invalid", "Seed canonical row hash drifted or collided")
  }
  invisible(ordered)
}

phase19_candidate_registry_sha256 <- function(registry, feature_contract = NULL) {
  if (is.null(feature_contract)) feature_contract <- phase19_load_feature_contract()
  phase19_validate_candidate_registry(registry, feature_contract)
  phase18_hash_table_v2(
    registry, key = "model_id",
    schema_tag = "phase19-club-candidate-registry-table-v1"
  )
}

phase19_seed_registry_sha256 <- function(registry) {
  phase19_validate_seed_registry(registry)
  phase18_hash_table_v2(
    registry, key = "seed_id",
    schema_tag = "phase19-club-seed-registry-table-v1"
  )
}

phase19_candidate_seed_policy_sha256 <- function(candidate_registry, seed_registry,
                                                 feature_contract = NULL) {
  if (is.null(feature_contract)) feature_contract <- phase19_load_feature_contract()
  candidate_hash <- phase19_candidate_registry_sha256(candidate_registry, feature_contract)
  seed_hash <- phase19_seed_registry_sha256(seed_registry)
  phase18_hash_sequence_v2(
    list(
      schema_version = "phase19-club-candidate-seed-policy-v1",
      hash_encoding_version = phase18_canonical_encoding_v2(),
      forecast_domain = "club",
      candidate_file_name = "candidate_registry.csv",
      candidate_schema_sha256 = phase19_protocol_schema_sha256(
        phase19_candidate_registry_schema(), "candidate_registry.csv"
      ),
      candidate_registry_sha256 = candidate_hash,
      seed_file_name = "seed_registry.csv",
      seed_schema_sha256 = phase19_protocol_schema_sha256(
        phase19_seed_registry_schema(), "seed_registry.csv"
      ),
      seed_registry_sha256 = seed_hash
    ),
    domain = "phase19-club-candidate-seed-policy-v1",
    names = c(
      "schema_version", "hash_encoding_version", "forecast_domain",
      "candidate_file_name", "candidate_schema_sha256", "candidate_registry_sha256",
      "seed_file_name", "seed_schema_sha256", "seed_registry_sha256"
    ),
    types = rep("character", 9L)
  )
}

phase19_protocol_read_candidates <- function(path) {
  phase19_assert_regular_file(path, "candidate_registry_invalid")
  registry <- utils::read.csv(
    path, stringsAsFactors = FALSE, check.names = FALSE,
    na.strings = "",
    colClasses = c(
      rep("character", 9L), "logical", "logical", "integer", "integer",
      "integer", rep("character", 4L), "logical", "character", "character"
    )
  )
  registry
}

phase19_protocol_read_seeds <- function(path) {
  phase19_assert_regular_file(path, "seed_registry_invalid")
  utils::read.csv(
    path, stringsAsFactors = FALSE, check.names = FALSE,
    na.strings = character(),
    colClasses = c(rep("character", 5L), "integer", "character", "character")
  )
}

#' Load the exact committed candidate/seed policy as fixture-only authority.
#'
#' The policy is mechanically evaluable, but cannot authorize a production
#' release until the complete gate policy and an accepted owner review exist.
phase19_load_club_candidate_seed_policy <- function(...) {
  phase19_reject_arbitrary_arguments(list(...))
  phase19_protocol_require_dependencies()
  root <- file.path(.phase19_club_project_root, "data", "club", "model_protocol")
  candidate_registry <- phase19_protocol_read_candidates(
    file.path(root, "candidate_registry.csv")
  )
  seed_registry <- phase19_protocol_read_seeds(file.path(root, "seed_registry.csv"))
  feature_contract <- phase19_load_feature_contract()
  candidate_registry <- phase19_validate_candidate_registry(
    candidate_registry, feature_contract
  )
  seed_registry <- phase19_validate_seed_registry(seed_registry)
  candidate_hash <- phase19_candidate_registry_sha256(candidate_registry, feature_contract)
  seed_hash <- phase19_seed_registry_sha256(seed_registry)
  structure(list(
    status = "ready", reason_code = "", authority_mode = "fixture",
    fixture_authority = TRUE, production_eligible = FALSE,
    forecast_domain = "club", hash_encoding_version = phase18_canonical_encoding_v2(),
    candidate_registry = candidate_registry, seed_registry = seed_registry,
    candidate_registry_sha256 = candidate_hash,
    seed_registry_sha256 = seed_hash,
    candidate_seed_policy_sha256 = phase19_candidate_seed_policy_sha256(
      candidate_registry, seed_registry, feature_contract
    )
  ), class = c("phase19_club_protocol_candidate", "list"))
}

phase19_gate_registry_schema <- function() {
  c(
    "schema_version", "hash_encoding_version", "forecast_domain", "gate_order",
    "gate_id", "gate_category", "metric_id", "aggregation",
    "comparator_model_id", "operator", "threshold", "applicability",
    "failure_reason_code", "row_sha256"
  )
}

phase19_policy_review_schema <- function() {
  c(
    "schema_version", "hash_encoding_version", "forecast_domain", "reviewer",
    "reviewed_at_utc", "decision", "candidate_registry_sha256",
    "gate_registry_sha256", "seed_registry_sha256", "feature_contract_sha256",
    "protocol_sha256", "rationale_code", "review_sha256"
  )
}

phase19_expected_gate_policy <- function() {
  gate_id <- c(
    "equal_fold_rps_delta", "paired_rps_ci_upper",
    "rolling_origin_fold_breadth", "heldout_league_fold_breadth",
    "worst_fold_rps_regression", "equal_fold_brier_relative_regression",
    "equal_fold_log_loss_relative_regression", "fixed_bin_calibration_delta",
    "declared_fixture_coverage", "full_score_grid_coverage",
    "current_ucl_club_coverage", "common_rating_component_coverage",
    "byte_reproducibility", "probability_integrity", "distribution_integrity",
    "cutoff_integrity", "identity_integrity", "source_integrity",
    "license_integrity", "feature_integrity", "seed_integrity",
    "checksum_integrity", "domain_integrity", "model_card_integrity"
  )
  data.frame(
    gate_order = seq_along(gate_id),
    gate_id = gate_id,
    gate_category = c(
      "proper_score", "uncertainty", "breadth", "breadth", "proper_score",
      "supporting_score", "supporting_score", "calibration", "coverage",
      "coverage", "current_club", "current_club", "reproducibility",
      rep("integrity", 11L)
    ),
    metric_id = c(
      "candidate_minus_incumbent_rps", "paired_fold_rps_delta_ci_upper",
      "improved_fold_fraction_rolling_origin_league_season",
      "improved_fold_fraction_heldout_league_transport",
      "maximum_fold_rps_regression", "brier_relative_regression",
      "log_loss_relative_regression", "fixed_bin_calibration_error_delta",
      "declared_fixture_prediction_fraction", "declared_score_grid_cell_fraction",
      "accepted_current_ucl_club_fraction", "current_ucl_common_component_fraction",
      "isolated_canonical_artifact_hash_equality", "probability_contract_pass",
      "distribution_contract_pass", "exclusive_cutoff_contract_pass",
      "club_identity_contract_pass", "accepted_source_contract_pass",
      "source_license_contract_pass", "feature_contract_pass",
      "seed_contract_pass", "checksum_contract_pass", "club_domain_contract_pass",
      "model_card_contract_pass"
    ),
    aggregation = c(
      "equal_fold_mean", "paired_fold_bootstrap_95_upper",
      "eligible_fold_fraction", "eligible_fold_fraction", "maximum_fold_delta",
      "equal_fold_relative_change", "equal_fold_relative_change",
      "fixed_probability_bin_error_delta", "declared_fixture_fraction",
      "declared_grid_cell_fraction", "accepted_current_ucl_club_fraction",
      "accepted_current_ucl_common_component_fraction", "isolated_run_hash_equality",
      rep("all_rows_boolean", 11L)
    ),
    comparator_model_id = c(
      rep("club_venue_nb", 8L), "declared_assessment_fixtures",
      "declared_score_support_g40", "accepted_current_ucl_roster",
      "accepted_history_rating_graph", "same_protocol_isolated_replay",
      rep("predeclared_contract", 11L)
    ),
    operator = c("<=", "<", ">=", ">=", rep("<=", 4L), rep("==", 16L)),
    threshold = c(-0.003, 0, 2 / 3, 2 / 3, 0.015, 0.01, 0.01, 0.01, rep(1, 16L)),
    applicability = c(
      rep("candidate_vs_club_venue_nb", 8L),
      "all_declared_assessment_fixtures", "all_declared_goal_distributions",
      "production_release", "production_release", "same_parents_code_and_seeds",
      rep("all_evaluation_and_release_artifacts", 11L)
    ),
    failure_reason_code = c(
      "primary_rps_effect_failed", "paired_uncertainty_failed",
      "rolling_origin_breadth_failed", "heldout_league_breadth_failed",
      "worst_fold_regression_failed", "brier_relative_regression_failed",
      "log_loss_relative_regression_failed", "calibration_delta_failed",
      "declared_fixture_coverage_failed", "score_grid_coverage_failed",
      "current_ucl_club_coverage_failed", "common_rating_component_failed",
      "byte_reproducibility_failed", "probability_integrity_failed",
      "distribution_integrity_failed", "cutoff_integrity_failed",
      "identity_integrity_failed", "source_integrity_failed",
      "license_integrity_failed", "feature_integrity_failed", "seed_integrity_failed",
      "checksum_integrity_failed", "domain_integrity_failed", "model_card_integrity_failed"
    ),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

phase19_gate_row_sha256 <- function(registry) {
  phase19_protocol_require_dependencies()
  if (!is.data.frame(registry) ||
      !identical(names(registry), phase19_gate_registry_schema())) {
    phase19_protocol_abort("gate_registry_invalid", "Gate registry schema is not exact")
  }
  phase18_hash_row_v2(
    registry, exclude = "row_sha256",
    schema_tag = "phase19-club-gate-registry-row-v1"
  )
}

phase19_validate_gate_registry <- function(registry) {
  phase19_protocol_require_dependencies()
  schema <- phase19_gate_registry_schema()
  if (!is.data.frame(registry) || !identical(names(registry), schema)) {
    phase19_protocol_abort("gate_registry_invalid", "Gate registry schema is not exact")
  }
  character_fields <- setdiff(schema, c("gate_order", "threshold"))
  if (any(!vapply(registry[character_fields], is.character, logical(1))) ||
      !is.integer(registry$gate_order) || !is.double(registry$threshold) ||
      anyNA(registry)) {
    phase19_protocol_abort("gate_registry_invalid", "Gate registry types or missingness are invalid")
  }
  expected <- phase19_expected_gate_policy()
  expected_ids <- expected$gate_id
  if (nrow(registry) != nrow(expected) || anyDuplicated(registry$gate_id) ||
      anyDuplicated(registry$gate_order) || anyDuplicated(registry$failure_reason_code) ||
      !setequal(as.character(registry$gate_id), expected_ids)) {
    phase19_protocol_abort("gate_registry_invalid", "Gate inventory is missing, duplicate, or unknown")
  }
  if (any(registry$schema_version != "phase19-club-gate-v1") ||
      any(registry$hash_encoding_version != phase18_canonical_encoding_v2()) ||
      any(registry$forecast_domain != "club")) {
    phase19_protocol_abort("protocol_domain_mismatch", "Gate registry metadata is not club canonical-v2")
  }
  phase19_protocol_assert_no_national_authority(registry, "Gate registry")
  ordered <- registry[order(registry$gate_order, method = "radix"), , drop = FALSE]
  rownames(ordered) <- NULL
  policy_fields <- names(expected)
  if (!identical(ordered[policy_fields], expected)) {
    phase19_protocol_abort(
      "gate_registry_invalid",
      "Gate order, metric, aggregation, comparator, operator, threshold, applicability, or reason drifted"
    )
  }
  if (any(grepl("infer|observed[_ -]?threshold|result[_ -]?derived",
                tolower(ordered$aggregation), perl = TRUE))) {
    phase19_protocol_abort("gate_registry_invalid", "Gate thresholds cannot be derived from observed results")
  }
  expected_hashes <- phase19_gate_row_sha256(registry)
  if (!identical(as.character(registry$row_sha256), expected_hashes) ||
      anyDuplicated(registry$row_sha256) ||
      any(!vapply(registry$row_sha256, phase19_is_sha256, logical(1)))) {
    phase19_protocol_abort("gate_registry_invalid", "Gate canonical row hash drifted or collided")
  }
  invisible(ordered)
}

phase19_gate_registry_sha256 <- function(registry) {
  phase19_validate_gate_registry(registry)
  phase18_hash_table_v2(
    registry, key = "gate_id",
    schema_tag = "phase19-club-gate-registry-table-v1"
  )
}

phase19_protocol_file_inventory <- function() {
  c(
    "candidate_registry.csv", "gate_registry.csv", "seed_registry.csv",
    "feature_contract.csv", "policy_review.json"
  )
}

phase19_protocol_future_inventory <- function() {
  c("fold_registry.csv", "protocol_state.json", "calibration_recipe.json", "fold_review.json")
}

phase19_validate_protocol_inventory <- function(files, allow_missing_review = FALSE) {
  files <- sort(as.character(files), method = "radix")
  required <- sort(phase19_protocol_file_inventory(), method = "radix")
  optional <- character()
  if (isTRUE(allow_missing_review)) {
    required <- setdiff(required, "policy_review.json")
    optional <- "policy_review.json"
  }
  future <- sort(phase19_protocol_future_inventory(), method = "radix")
  extras <- sort(setdiff(files, c(required, optional)), method = "radix")
  future_state_valid <- !length(extras) || identical(extras, future)
  if (anyNA(files) || any(!nzchar(files)) || anyDuplicated(files) ||
      length(setdiff(required, files)) || !future_state_valid) {
    phase19_protocol_abort(
      "protocol_inventory_invalid",
      "Club protocol directory has missing, duplicate, unsafe, or surplus files"
    )
  }
  invisible(TRUE)
}

phase19_protocol_sha256 <- function(candidate_registry, gate_registry, seed_registry,
                                    feature_contract) {
  candidate_hash <- phase19_candidate_registry_sha256(candidate_registry, feature_contract)
  gate_hash <- phase19_gate_registry_sha256(gate_registry)
  seed_hash <- phase19_seed_registry_sha256(seed_registry)
  feature_hash <- phase19_feature_contract_sha256(feature_contract)
  file_names <- c(
    "candidate_registry.csv", "gate_registry.csv", "seed_registry.csv",
    "feature_contract.csv"
  )
  schemas <- list(
    phase19_candidate_registry_schema(), phase19_gate_registry_schema(),
    phase19_seed_registry_schema(), phase19_feature_contract_schema()
  )
  table_hashes <- c(candidate_hash, gate_hash, seed_hash, feature_hash)
  values <- list(
    schema_version = "phase19-club-evaluation-protocol-v1",
    hash_encoding_version = phase18_canonical_encoding_v2(),
    forecast_domain = "club", score_support = "0:40"
  )
  for (index in seq_along(file_names)) {
    prefix <- sprintf("file_%02d", index)
    values[[paste0(prefix, "_name")]] <- file_names[[index]]
    values[[paste0(prefix, "_schema_sha256")]] <- phase19_protocol_schema_sha256(
      schemas[[index]], file_names[[index]]
    )
    values[[paste0(prefix, "_table_sha256")]] <- table_hashes[[index]]
  }
  phase18_hash_sequence_v2(
    values, domain = "phase19-club-evaluation-protocol-v1",
    names = names(values), types = rep("character", length(values))
  )
}

phase19_policy_review_sha256 <- function(review) {
  schema <- phase19_policy_review_schema()
  if (!is.list(review) || !identical(names(review), schema)) {
    phase19_protocol_abort("protocol_policy_not_approved", "Policy review schema is not exact")
  }
  values <- review[setdiff(schema, "review_sha256")]
  if (any(vapply(values, length, integer(1)) != 1L) ||
      any(vapply(values, function(value) is.na(value[[1L]]), logical(1)))) {
    phase19_protocol_abort("protocol_policy_not_approved", "Policy review values are not exact scalars")
  }
  values[] <- lapply(values, function(value) enc2utf8(as.character(value[[1L]])))
  phase18_hash_sequence_v2(
    values, domain = "phase19-club-policy-review-v1",
    names = names(values), types = rep("character", length(values))
  )
}

phase19_validate_policy_review <- function(review, protocol, require_accepted = FALSE) {
  if (!is.list(review) || !identical(names(review), phase19_policy_review_schema())) {
    phase19_protocol_abort("protocol_policy_not_approved", "Policy review is missing or has schema drift")
  }
  review[] <- lapply(review, function(value) as.character(value[[1L]]))
  if (!identical(review$schema_version, "phase19-club-policy-review-v1") ||
      !identical(review$hash_encoding_version, phase18_canonical_encoding_v2()) ||
      !identical(review$forecast_domain, "club") ||
      !review$decision %in% c("pending", "accepted", "rejected") ||
      !phase19_is_sha256(review$review_sha256) ||
      !identical(review$review_sha256, phase19_policy_review_sha256(review))) {
    phase19_protocol_abort("protocol_policy_not_approved", "Policy review metadata or self-hash is invalid")
  }
  parent_fields <- c(
    "candidate_registry_sha256", "gate_registry_sha256", "seed_registry_sha256",
    "feature_contract_sha256", "protocol_sha256"
  )
  if (any(!vapply(review[parent_fields], phase19_is_sha256, logical(1))) ||
      !identical(
        unname(unlist(review[parent_fields], use.names = FALSE)),
        unname(unlist(protocol[parent_fields], use.names = FALSE))
      )) {
    phase19_protocol_abort("protocol_policy_not_approved", "Policy review does not bind the exact protocol parents")
  }
  if (identical(review$decision, "pending")) {
    if (nzchar(review$reviewer) || nzchar(review$reviewed_at_utc) ||
        !identical(review$rationale_code, "pending_owner_review")) {
      phase19_protocol_abort("protocol_policy_not_approved", "Pending review invents owner evidence")
    }
  }
  if (identical(review$decision, "accepted")) {
    if (!nzchar(review$reviewer) ||
        !grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$",
               review$reviewed_at_utc) || !nzchar(review$rationale_code)) {
      phase19_protocol_abort("protocol_policy_not_approved", "Accepted review lacks owner or UTC evidence")
    }
  }
  if (isTRUE(require_accepted) && !identical(review$decision, "accepted")) {
    phase19_protocol_abort("protocol_policy_not_approved", "Club protocol owner review is not accepted")
  }
  invisible(review)
}

phase19_protocol_read_gates <- function(path) {
  phase19_assert_regular_file(path, "gate_registry_invalid")
  utils::read.csv(
    path, stringsAsFactors = FALSE, check.names = FALSE,
    na.strings = character(),
    colClasses = c(
      rep("character", 3L), "integer", rep("character", 6L), "double",
      rep("character", 3L)
    )
  )
}

phase19_protocol_read_review <- function(path) {
  phase19_assert_regular_file(path, "protocol_policy_not_approved")
  review <- as.list(jsonlite::fromJSON(path, simplifyVector = TRUE))
  if (!identical(names(review), phase19_policy_review_schema())) {
    phase19_protocol_abort("protocol_policy_not_approved", "Policy review schema is not exact")
  }
  review[] <- lapply(review, function(value) as.character(value[[1L]]))
  review
}

phase19_protocol_components <- function(include_review = TRUE) {
  root <- file.path(.phase19_club_project_root, "data", "club", "model_protocol")
  entries <- list.files(root, all.files = FALSE, no.. = TRUE)
  phase19_validate_protocol_inventory(entries, allow_missing_review = !isTRUE(include_review))
  candidate_registry <- phase19_protocol_read_candidates(file.path(root, "candidate_registry.csv"))
  gate_registry <- phase19_protocol_read_gates(file.path(root, "gate_registry.csv"))
  seed_registry <- phase19_protocol_read_seeds(file.path(root, "seed_registry.csv"))
  feature_contract <- phase19_load_feature_contract()
  candidate_registry <- phase19_validate_candidate_registry(candidate_registry, feature_contract)
  gate_registry <- phase19_validate_gate_registry(gate_registry)
  seed_registry <- phase19_validate_seed_registry(seed_registry)
  hashes <- list(
    candidate_registry_sha256 = phase19_candidate_registry_sha256(candidate_registry, feature_contract),
    gate_registry_sha256 = phase19_gate_registry_sha256(gate_registry),
    seed_registry_sha256 = phase19_seed_registry_sha256(seed_registry),
    feature_contract_sha256 = phase19_feature_contract_sha256(feature_contract)
  )
  hashes$protocol_sha256 <- phase19_protocol_sha256(
    candidate_registry, gate_registry, seed_registry, feature_contract
  )
  c(list(
    schema_version = "phase19-club-evaluation-protocol-v1",
    hash_encoding_version = phase18_canonical_encoding_v2(),
    forecast_domain = "club", candidate_registry = candidate_registry,
    gate_registry = gate_registry, seed_registry = seed_registry,
    feature_contract = feature_contract
  ), hashes, list(
    policy_review = if (isTRUE(include_review)) {
      phase19_protocol_read_review(file.path(root, "policy_review.json"))
    } else NULL
  ))
}

phase19_evaluate_policy_review <- function(protocol, review, authority_mode = "production") {
  if (!authority_mode %in% c("production", "fixture")) {
    phase19_protocol_abort("protocol_domain_mismatch", "Protocol authority mode is invalid")
  }
  valid <- tryCatch({
    phase19_validate_policy_review(
      review, protocol, require_accepted = identical(authority_mode, "production")
    )
    TRUE
  }, error = function(error) error)
  if (inherits(valid, "error")) {
    return(structure(list(
      status = "blocked", reason_code = "protocol_policy_not_approved",
      authority_mode = authority_mode,
      fixture_authority = identical(authority_mode, "fixture"),
      production_eligible = FALSE, forecast_domain = "club",
      upstream_reason = if (is.null(valid$reason_code)) class(valid)[[1L]] else valid$reason_code
    ), class = c("phase19_club_evaluation_protocol", "list")))
  }
  result <- protocol
  result$status <- "ready"
  result$reason_code <- ""
  result$authority_mode <- authority_mode
  result$fixture_authority <- identical(authority_mode, "fixture")
  result$production_eligible <- identical(authority_mode, "production")
  result$policy_review <- review
  structure(result, class = c("phase19_club_evaluation_protocol", "list"))
}

#' Load the committed policy for deterministic fixture evaluation.
phase19_load_fixture_club_evaluation_protocol <- function(...) {
  phase19_reject_arbitrary_arguments(list(...))
  protocol <- phase19_protocol_components(include_review = TRUE)
  phase19_validate_policy_review(protocol$policy_review, protocol, require_accepted = FALSE)
  result <- protocol
  result$status <- "ready"
  result$reason_code <- ""
  result$authority_mode <- "fixture"
  result$fixture_authority <- TRUE
  result$production_eligible <- FALSE
  structure(result, class = c("phase19_club_evaluation_protocol", "list"))
}

#' Load production club policy only when one exact owner review is accepted.
phase19_load_club_evaluation_protocol <- function(...) {
  phase19_reject_arbitrary_arguments(list(...))
  protocol <- phase19_protocol_components(include_review = FALSE)
  root <- file.path(.phase19_club_project_root, "data", "club", "model_protocol")
  review <- tryCatch(
    phase19_protocol_read_review(file.path(root, "policy_review.json")),
    error = function(error) NULL
  )
  phase19_evaluate_policy_review(protocol, review, "production")
}
