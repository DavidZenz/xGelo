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
  if (identical(authority_mode, "production")) {
    fixed <- phase19_protocol_components(include_review = FALSE)
    protocol_fields <- intersect(names(fixed), names(protocol))
    if (!is.list(protocol) ||
        !identical(as.character(protocol$forecast_domain), "club") ||
        ("authority_mode" %in% names(protocol) &&
           !is.null(protocol$authority_mode) &&
           !identical(as.character(protocol$authority_mode), "production")) ||
        ("fixture_authority" %in% names(protocol) &&
           isTRUE(protocol$fixture_authority)) ||
        ("policy_review" %in% names(protocol) &&
           !is.null(protocol$policy_review)) ||
        !identical(protocol[protocol_fields], fixed[protocol_fields])) {
      return(structure(list(
        status = "blocked", reason_code = "protocol_policy_not_approved",
        authority_mode = authority_mode, fixture_authority = FALSE,
        production_eligible = FALSE, forecast_domain = "club",
        upstream_reason = "caller_protocol_not_fixed_runtime_root"
      ), class = c("phase19_club_evaluation_protocol", "list")))
    }
    fixed_root <- file.path(.phase19_club_project_root, "data", "club", "model_protocol")
    fixed_review <- tryCatch(
      phase19_protocol_read_review(file.path(fixed_root, "policy_review.json")),
      error = function(error) NULL
    )
    if (is.null(fixed_review) || !identical(review, fixed_review)) {
      return(structure(list(
        status = "blocked", reason_code = "protocol_policy_not_approved",
        authority_mode = authority_mode, fixture_authority = FALSE,
        production_eligible = FALSE, forecast_domain = "club",
        upstream_reason = "caller_policy_review_not_fixed_runtime_root"
      ), class = c("phase19_club_evaluation_protocol", "list")))
    }
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

#' Frozen Phase 19 club fold authority.
#'
#' Fold construction is deliberately separate from fitting.  A registry fixes
#' every assessment fixture, inner evidence role, cutoff, and authority parent
#' before a model callback can observe an assessment result.

phase19_fold_abort <- function(reason_code, message, data = list()) {
  stop(structure(
    c(list(message = as.character(message), call = NULL,
           reason_code = as.character(reason_code)), data),
    class = c("phase19_fold_contract_error", "phase19_protocol_error",
              "error", "condition")
  ))
}

phase19_fold_registry_schema <- function() {
  c(
    "schema_version", "hash_encoding_version", "forecast_domain",
    "authority_mode", "fixture_authority", "fold_id", "fold_family",
    "assessment_competition_id", "assessment_season_id",
    "assessment_start_utc", "assessment_end_utc",
    "training_cutoff_exclusive", "calibration_cutoff_exclusive",
    "declared_fixture_ids", "declared_fixture_count",
    "declared_fixture_sha256", "training_fixture_ids",
    "training_fixture_count", "training_fixture_sha256",
    "calibration_fixture_ids", "calibration_fixture_count",
    "calibration_fixture_sha256", "held_out_competition_id",
    "fit_excluded_competition_id", "tuning_excluded_competition_id",
    "calibration_excluded_competition_id", "eligibility_status",
    "support_reason_code", "accepted_generation_id",
    "corpus_manifest_sha256", "snapshot_sha256", "protocol_sha256",
    "policy_review_sha256", "calibration_recipe_sha256", "row_sha256"
  )
}

phase19_calibration_recipe_schema <- function() {
  c(
    "schema_version", "hash_encoding_version", "forecast_domain",
    "calibration_family", "probability_view", "initial_temperature",
    "temperature_lower", "temperature_upper", "epsilon", "optimizer",
    "optimizer_seed_id", "evidence_role", "minimum_history_rows",
    "minimum_class_count", "failure_behavior", "raw_fallback_promotable",
    "distribution_unchanged", "recipe_sha256"
  )
}

phase19_calibration_recipe_sha256 <- function(recipe) {
  schema <- phase19_calibration_recipe_schema()
  if (!is.list(recipe) || !identical(names(recipe), schema)) {
    phase19_fold_abort("calibration_recipe_invalid", "Calibration recipe schema is not exact")
  }
  values <- recipe[setdiff(schema, "recipe_sha256")]
  if (any(vapply(values, length, integer(1)) != 1L) ||
      any(vapply(values, function(value) is.na(value[[1L]]), logical(1)))) {
    phase19_fold_abort("calibration_recipe_invalid", "Calibration recipe values are not scalars")
  }
  phase18_hash_sequence_v2(
    values, domain = "phase19-club-calibration-recipe-v1",
    names = names(values), types = vapply(values, phase18_v2_type_tag, character(1))
  )
}

phase19_expected_calibration_recipe <- function() {
  recipe <- list(
    schema_version = "phase19-club-calibration-recipe-v1",
    hash_encoding_version = phase18_canonical_encoding_v2(),
    forecast_domain = "club",
    calibration_family = "temperature_1x2",
    probability_view = "derived_1x2",
    initial_temperature = "1",
    temperature_lower = "0.25",
    temperature_upper = "4",
    epsilon = "1e-15",
    optimizer = "stats::optim-L-BFGS-B",
    optimizer_seed_id = "club_probability_calibration_v1",
    evidence_role = "strictly_prior_inner_out_of_fold",
    minimum_history_rows = "60",
    minimum_class_count = "10",
    failure_behavior = "explicit_failure_not_promotion_evidence",
    raw_fallback_promotable = FALSE,
    distribution_unchanged = TRUE,
    recipe_sha256 = ""
  )
  recipe$recipe_sha256 <- phase19_calibration_recipe_sha256(recipe)
  recipe
}

phase19_validate_calibration_recipe <- function(recipe) {
  expected <- phase19_expected_calibration_recipe()
  if (!is.list(recipe) || !identical(names(recipe), names(expected)) ||
      !identical(recipe, expected) ||
      !phase19_is_sha256(as.character(recipe$recipe_sha256)) ||
      !identical(as.character(recipe$recipe_sha256),
                 phase19_calibration_recipe_sha256(recipe))) {
    phase19_fold_abort(
      "calibration_recipe_invalid",
      "Club calibration family, bounds, support, optimizer, role, or failure policy drifted"
    )
  }
  invisible(recipe)
}

phase19_fold_parse_utc <- function(value, field) {
  value <- as.character(value)
  if (!length(value) || anyNA(value) || any(!grepl(
    "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$", value
  ))) {
    phase19_fold_abort("fold_cutoff_invalid", paste0(field, " must be exact UTC seconds"))
  }
  parsed <- as.POSIXct(strptime(value, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  canonical <- format(parsed, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  if (anyNA(parsed) || !identical(canonical, value)) {
    phase19_fold_abort("fold_cutoff_invalid", paste0(field, " contains an invalid UTC instant"))
  }
  parsed
}

phase19_fold_boundary_utc <- function(matches) {
  required <- c("match_id", "event_date", "kickoff_utc", "kickoff_precision")
  if (!is.data.frame(matches) || length(setdiff(required, names(matches)))) {
    phase19_fold_abort("fold_boundary_invalid", "Fold boundary rows are incomplete")
  }
  precision <- as.character(matches$kickoff_precision)
  if (anyNA(precision) || any(!precision %in% c("instant", "date"))) {
    phase19_fold_abort("fold_boundary_invalid", "Kickoff precision must be instant or date")
  }
  result <- character(nrow(matches))
  instant <- precision == "instant"
  if (any(instant)) {
    if (any(!nzchar(as.character(matches$kickoff_utc[instant])))) {
      phase19_fold_abort("fold_boundary_invalid", "Instant precision requires kickoff UTC")
    }
    phase19_fold_parse_utc(matches$kickoff_utc[instant], "kickoff_utc")
    result[instant] <- as.character(matches$kickoff_utc[instant])
  }
  dated <- !instant
  if (any(dated)) {
    dates <- as.character(matches$event_date[dated])
    parsed <- as.Date(dates, format = "%Y-%m-%d")
    if (any(nzchar(as.character(matches$kickoff_utc[dated]))) || anyNA(parsed) ||
        !identical(format(parsed, "%Y-%m-%d"), dates)) {
      phase19_fold_abort(
        "fold_boundary_invalid",
        "Date precision requires a blank kickoff and one valid full UTC date"
      )
    }
    result[dated] <- paste0(dates, "T00:00:00Z")
  }
  result
}

phase19_fold_id_values <- function(ids, field, allow_empty = FALSE) {
  ids <- as.character(ids)
  if (!length(ids) && isTRUE(allow_empty)) return(character())
  if (!length(ids) || anyNA(ids) || any(!nzchar(ids)) || anyDuplicated(ids)) {
    phase19_fold_abort("fold_fixture_inventory_invalid", paste0(field, " is not a unique fixture set"))
  }
  sort(ids, method = "radix")
}

phase19_fold_id_text <- function(ids, field, allow_empty = FALSE) {
  paste(phase19_fold_id_values(ids, field, allow_empty), collapse = "|")
}

phase19_fold_parse_id_text <- function(value, field, allow_empty = FALSE) {
  if (length(value) != 1L || is.na(value)) {
    phase19_fold_abort("fold_fixture_inventory_invalid", paste0(field, " is not scalar"))
  }
  if (!nzchar(value)) {
    if (isTRUE(allow_empty)) return(character())
    phase19_fold_abort("fold_fixture_inventory_invalid", paste0(field, " is empty"))
  }
  ids <- strsplit(as.character(value), "|", fixed = TRUE)[[1L]]
  canonical <- phase19_fold_id_values(ids, field, allow_empty)
  if (!identical(ids, canonical)) {
    phase19_fold_abort("fold_fixture_inventory_invalid", paste0(field, " is not canonical"))
  }
  canonical
}

phase19_fold_id_sha256 <- function(ids, role) {
  ids <- phase19_fold_id_values(ids, paste0(role, "_fixture_ids"))
  phase18_hash_sequence_v2(
    as.list(ids), domain = paste0("phase19-club-fold-fixtures-v1:", role),
    names = sprintf("fixture_%05d", seq_along(ids)),
    types = rep("character", length(ids))
  )
}

phase19_fold_row_sha256 <- function(registry) {
  if (!is.data.frame(registry) ||
      !identical(names(registry), phase19_fold_registry_schema())) {
    phase19_fold_abort("fold_registry_invalid", "Fold registry schema is not exact")
  }
  phase18_hash_row_v2(
    registry, exclude = "row_sha256",
    schema_tag = "phase19-club-fold-registry-row-v1"
  )
}

phase19_fold_policy_parents <- function(protocol) {
  required <- c("protocol_sha256", "policy_review")
  if (!inherits(protocol, "phase19_club_evaluation_protocol") ||
      length(setdiff(required, names(protocol))) ||
      !phase19_is_sha256(protocol$protocol_sha256) ||
      !is.list(protocol$policy_review) ||
      !phase19_is_sha256(protocol$policy_review$review_sha256)) {
    phase19_fold_abort("fold_policy_invalid", "A validated club evaluation protocol is required")
  }
  phase19_validate_policy_review(protocol$policy_review, protocol, require_accepted = FALSE)
  list(
    protocol_sha256 = as.character(protocol$protocol_sha256),
    policy_review_sha256 = as.character(protocol$policy_review$review_sha256)
  )
}

phase19_fold_eligible_before <- function(matches, cutoff, excluded_competition = "") {
  cutoff_time <- phase19_fold_parse_utc(cutoff, "fold cutoff")[[1L]]
  completion <- phase19_fold_parse_utc(
    matches$completion_not_before_utc, "completion_not_before_utc"
  )
  evidence <- phase19_fold_parse_utc(
    matches$evidence_available_at_utc, "evidence_available_at_utc"
  )
  boundary <- phase19_fold_parse_utc(
    phase19_fold_boundary_utc(matches), "match boundary"
  )
  counted <- vapply(matches$counts_for_model, phase18_history_logical, logical(1))
  eligible <- counted & completion < cutoff_time & evidence < cutoff_time &
    boundary < cutoff_time
  if (nzchar(excluded_competition)) {
    eligible <- eligible & as.character(matches$competition_id) != excluded_competition
  }
  matches[eligible, , drop = FALSE]
}

phase19_fold_raw_registry <- function(snapshot, protocol, authority_mode) {
  expected_fixture <- identical(authority_mode, "fixture")
  phase19_validate_club_training_snapshot(snapshot, authority_mode)
  if (!inherits(protocol, "phase19_club_evaluation_protocol") ||
      !identical(protocol$status, "ready") ||
      !identical(protocol$authority_mode, authority_mode) ||
      !identical(isTRUE(protocol$fixture_authority), expected_fixture)) {
    phase19_fold_abort("fold_policy_invalid", "Snapshot and protocol authority modes must agree")
  }
  parents <- phase19_fold_policy_parents(protocol)
  recipe <- phase19_expected_calibration_recipe()
  phase19_validate_calibration_recipe(recipe)
  matches <- snapshot$matches
  if (anyDuplicated(matches$match_id)) {
    phase19_fold_abort("fold_fixture_inventory_invalid", "Snapshot fixture IDs are duplicate")
  }
  matches$.fold_boundary_utc <- phase19_fold_boundary_utc(matches)
  block_key <- paste(matches$competition_id, matches$season_id, sep = "\037")
  block_names <- sort(unique(block_key), method = "radix")
  rows <- list()
  cursor <- 0L
  for (key in block_names) {
    assessment <- matches[block_key == key, , drop = FALSE]
    assessment <- assessment[order(assessment$match_id, method = "radix"), , drop = FALSE]
    outer_cutoff <- min(assessment$.fold_boundary_utc)
    assessment_end <- max(assessment$.fold_boundary_utc)
    for (family in c("rolling_origin_league_season", "heldout_league_transport")) {
      heldout <- if (identical(family, "heldout_league_transport")) {
        as.character(assessment$competition_id[[1L]])
      } else ""
      prior <- phase19_fold_eligible_before(matches, outer_cutoff, heldout)
      if (!nrow(prior)) next
      prior$.fold_boundary_utc <- phase19_fold_boundary_utc(prior)
      calibration_batch <- max(prior$.fold_boundary_utc)
      fit <- phase19_fold_eligible_before(prior, calibration_batch, heldout)
      calibration <- prior[
        prior$.fold_boundary_utc >= calibration_batch &
          prior$.fold_boundary_utc < outer_cutoff,
        , drop = FALSE
      ]
      if (!nrow(fit) || !nrow(calibration)) next
      declared_ids <- phase19_fold_id_values(assessment$match_id, "declared_fixture_ids")
      fit_ids <- phase19_fold_id_values(fit$match_id, "training_fixture_ids")
      calibration_ids <- phase19_fold_id_values(
        calibration$match_id, "calibration_fixture_ids"
      )
      if (length(intersect(fit_ids, calibration_ids)) ||
          length(intersect(c(fit_ids, calibration_ids), declared_ids))) {
        phase19_fold_abort("fold_role_overlap", "Fold fit, calibration, and assessment roles overlap")
      }
      competition <- as.character(assessment$competition_id[[1L]])
      season <- as.character(assessment$season_id[[1L]])
      cursor <- cursor + 1L
      rows[[cursor]] <- data.frame(
        schema_version = "phase19-club-fold-v1",
        hash_encoding_version = phase18_canonical_encoding_v2(),
        forecast_domain = "club", authority_mode = authority_mode,
        fixture_authority = expected_fixture,
        fold_id = paste("club", family, competition, season, sep = "__"),
        fold_family = family, assessment_competition_id = competition,
        assessment_season_id = season, assessment_start_utc = outer_cutoff,
        assessment_end_utc = assessment_end,
        training_cutoff_exclusive = calibration_batch,
        calibration_cutoff_exclusive = outer_cutoff,
        declared_fixture_ids = phase19_fold_id_text(declared_ids, "declared_fixture_ids"),
        declared_fixture_count = as.integer(length(declared_ids)),
        declared_fixture_sha256 = phase19_fold_id_sha256(declared_ids, "declared"),
        training_fixture_ids = phase19_fold_id_text(fit_ids, "training_fixture_ids"),
        training_fixture_count = as.integer(length(fit_ids)),
        training_fixture_sha256 = phase19_fold_id_sha256(fit_ids, "training"),
        calibration_fixture_ids = phase19_fold_id_text(
          calibration_ids, "calibration_fixture_ids"
        ),
        calibration_fixture_count = as.integer(length(calibration_ids)),
        calibration_fixture_sha256 = phase19_fold_id_sha256(
          calibration_ids, "calibration"
        ),
        held_out_competition_id = heldout,
        fit_excluded_competition_id = heldout,
        tuning_excluded_competition_id = heldout,
        calibration_excluded_competition_id = heldout,
        eligibility_status = "eligible", support_reason_code = "",
        accepted_generation_id = as.character(snapshot$accepted_generation_id),
        corpus_manifest_sha256 = as.character(snapshot$corpus_manifest_sha256),
        snapshot_sha256 = as.character(snapshot$snapshot_sha256),
        protocol_sha256 = parents$protocol_sha256,
        policy_review_sha256 = parents$policy_review_sha256,
        calibration_recipe_sha256 = as.character(recipe$recipe_sha256),
        row_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE
      )
    }
  }
  if (!length(rows)) {
    phase19_fold_abort(
      "fold_support_empty",
      "No fold has non-empty strictly nested fit and calibration evidence"
    )
  }
  registry <- do.call(rbind, rows)
  registry <- registry[order(registry$fold_id, method = "radix"), , drop = FALSE]
  rownames(registry) <- NULL
  registry$row_sha256 <- phase19_fold_row_sha256(registry)
  registry
}

phase19_validate_fold_registry <- function(registry, snapshot, protocol,
                                           authority_mode = "fixture") {
  if (!authority_mode %in% c("fixture", "production")) {
    phase19_fold_abort("fold_authority_invalid", "Fold authority mode is invalid")
  }
  schema <- phase19_fold_registry_schema()
  if (!is.data.frame(registry) || !identical(names(registry), schema) || !nrow(registry)) {
    phase19_fold_abort("fold_registry_invalid", "Fold registry schema or inventory is empty")
  }
  integer_fields <- c(
    "declared_fixture_count", "training_fixture_count", "calibration_fixture_count"
  )
  logical_fields <- "fixture_authority"
  character_fields <- setdiff(schema, c(integer_fields, logical_fields))
  if (any(!vapply(registry[integer_fields], is.integer, logical(1))) ||
      any(!vapply(registry[logical_fields], is.logical, logical(1))) ||
      any(!vapply(registry[character_fields], is.character, logical(1))) ||
      anyNA(registry) || anyDuplicated(registry$fold_id)) {
    phase19_fold_abort("fold_registry_invalid", "Fold registry types, missingness, or IDs are invalid")
  }
  if (any(registry$schema_version != "phase19-club-fold-v1") ||
      any(registry$hash_encoding_version != phase18_canonical_encoding_v2()) ||
      any(registry$forecast_domain != "club") ||
      any(registry$authority_mode != authority_mode) ||
      any(registry$fixture_authority != identical(authority_mode, "fixture")) ||
      any(registry$eligibility_status != "eligible") ||
      any(nzchar(registry$support_reason_code))) {
    phase19_fold_abort("fold_authority_invalid", "Fold metadata or eligibility drifted")
  }
  if (!setequal(
    unique(registry$fold_family),
    c("rolling_origin_league_season", "heldout_league_transport")
  )) {
    phase19_fold_abort("fold_registry_invalid", "Both exact fold families are required")
  }
  if (!identical(as.character(registry$row_sha256), phase19_fold_row_sha256(registry)) ||
      anyDuplicated(registry$row_sha256) ||
      any(!vapply(registry$row_sha256, phase19_is_sha256, logical(1)))) {
    phase19_fold_abort("fold_registry_invalid", "Fold row identity drifted or collided")
  }
  expected <- phase19_fold_raw_registry(snapshot, protocol, authority_mode)
  canonical <- registry[order(registry$fold_id, method = "radix"), , drop = FALSE]
  rownames(canonical) <- NULL
  if (!identical(canonical, expected)) {
    phase19_fold_abort(
      "fold_registry_invalid",
      "Fold inventory, cutoffs, roles, fixture coverage, exclusions, or parents drifted"
    )
  }
  invisible(canonical)
}

phase19_fold_registry_sha256 <- function(registry, snapshot, protocol,
                                         authority_mode = "fixture") {
  canonical <- phase19_validate_fold_registry(
    registry, snapshot, protocol, authority_mode
  )
  phase18_hash_table_v2(
    canonical, key = "fold_id",
    schema_tag = "phase19-club-fold-registry-table-v1"
  )
}

phase19_build_fixture_club_fold_registry <- function(snapshot, protocol) {
  if (!inherits(snapshot, "phase19_club_authority_result") ||
      !identical(snapshot$authority_mode, "fixture") ||
      !isTRUE(snapshot$fixture_authority)) {
    phase19_fold_abort("fold_authority_invalid", "Fixture fold builder requires fixture snapshot authority")
  }
  registry <- phase19_fold_raw_registry(snapshot, protocol, "fixture")
  phase19_validate_fold_registry(registry, snapshot, protocol, "fixture")
  registry
}

phase19_validate_fold_role_evidence <- function(rows, fold, role) {
  if (!role %in% c("fit", "tuning", "calibration") ||
      !is.data.frame(fold) || nrow(fold) != 1L ||
      !identical(names(fold), phase19_fold_registry_schema())) {
    phase19_fold_abort("fold_role_invalid", "Fold role validation inputs are invalid")
  }
  required <- c(
    "match_id", "competition_id", "counts_for_model",
    "completion_not_before_utc", "evidence_available_at_utc",
    "event_date", "kickoff_utc", "kickoff_precision"
  )
  if (!is.data.frame(rows) || !nrow(rows) || length(setdiff(required, names(rows))) ||
      anyDuplicated(rows$match_id)) {
    phase19_fold_abort("fold_role_invalid", "Fold role evidence is empty, duplicate, or incomplete")
  }
  cutoff <- if (role %in% c("fit", "tuning")) {
    fold$training_cutoff_exclusive[[1L]]
  } else fold$calibration_cutoff_exclusive[[1L]]
  cutoff_time <- phase19_fold_parse_utc(cutoff, paste0(role, " cutoff"))[[1L]]
  completion <- phase19_fold_parse_utc(
    rows$completion_not_before_utc, "completion_not_before_utc"
  )
  evidence <- phase19_fold_parse_utc(
    rows$evidence_available_at_utc, "evidence_available_at_utc"
  )
  boundary <- phase19_fold_parse_utc(
    phase19_fold_boundary_utc(rows), "match boundary"
  )
  if (any(completion >= cutoff_time) || any(evidence >= cutoff_time) ||
      any(boundary >= cutoff_time) ||
      any(!vapply(rows$counts_for_model, phase18_history_logical, logical(1)))) {
    phase19_fold_abort("fold_temporal_leakage", "Fold role evidence is not strictly prior to its cutoff")
  }
  excluded_field <- paste0(role, "_excluded_competition_id")
  excluded <- as.character(fold[[excluded_field]][[1L]])
  if (nzchar(excluded) && any(as.character(rows$competition_id) == excluded)) {
    phase19_fold_abort("fold_heldout_leakage", "Held-out competition entered fit, tuning, or calibration")
  }
  declared <- phase19_fold_parse_id_text(
    fold$declared_fixture_ids[[1L]], "declared_fixture_ids"
  )
  if (length(intersect(as.character(rows$match_id), declared))) {
    phase19_fold_abort("fold_assessment_leakage", "Assessment labels entered a prior evidence role")
  }
  expected <- if (role %in% c("fit", "tuning")) {
    phase19_fold_parse_id_text(fold$training_fixture_ids[[1L]], "training_fixture_ids")
  } else {
    lower <- phase19_fold_parse_utc(
      fold$training_cutoff_exclusive[[1L]], "training cutoff"
    )[[1L]]
    if (any(boundary < lower)) {
      phase19_fold_abort("fold_nesting_invalid", "Calibration evidence overlaps inner fit evidence")
    }
    phase19_fold_parse_id_text(
      fold$calibration_fixture_ids[[1L]], "calibration_fixture_ids"
    )
  }
  if (!identical(sort(as.character(rows$match_id), method = "radix"), expected)) {
    phase19_fold_abort("fold_role_coverage_invalid", "Fold role evidence differs from the frozen fixture set")
  }
  invisible(TRUE)
}

phase19_fold_role_evidence <- function(snapshot, fold, role) {
  if (!inherits(snapshot, "phase19_club_authority_result") ||
      !identical(snapshot$status, "ready")) {
    phase19_fold_abort("fold_authority_invalid", "A validated ready snapshot is required")
  }
  ids <- if (role %in% c("fit", "tuning")) {
    phase19_fold_parse_id_text(fold$training_fixture_ids[[1L]], "training_fixture_ids")
  } else if (identical(role, "calibration")) {
    phase19_fold_parse_id_text(
      fold$calibration_fixture_ids[[1L]], "calibration_fixture_ids"
    )
  } else {
    phase19_fold_abort("fold_role_invalid", "Unknown fold evidence role")
  }
  rows <- snapshot$matches[match(ids, snapshot$matches$match_id), , drop = FALSE]
  if (anyNA(rows$match_id)) {
    phase19_fold_abort("fold_role_coverage_invalid", "Frozen role fixture is absent from snapshot")
  }
  phase19_validate_fold_role_evidence(rows, fold, role)
  rows
}

phase19_validate_fold_prediction_coverage <- function(fold, prediction_fixture_ids) {
  if (!is.data.frame(fold) || nrow(fold) != 1L ||
      !identical(names(fold), phase19_fold_registry_schema())) {
    phase19_fold_abort("fold_coverage_invalid", "One exact fold row is required")
  }
  expected <- phase19_fold_parse_id_text(
    fold$declared_fixture_ids[[1L]], "declared_fixture_ids"
  )
  observed <- as.character(prediction_fixture_ids)
  if (anyNA(observed) || any(!nzchar(observed)) || anyDuplicated(observed) ||
      !identical(sort(observed, method = "radix"), expected)) {
    phase19_fold_abort(
      "fold_coverage_invalid",
      "Predictions must cover the exact declared fold fixture inventory once"
    )
  }
  invisible(TRUE)
}

phase19_protocol_state_schema <- function() {
  c(
    "schema_version", "hash_encoding_version", "forecast_domain",
    "authority_mode", "fixture_authority", "state", "reason_code",
    "generation_id", "accepted_generation_id", "corpus_manifest_sha256",
    "snapshot_sha256", "policy_review_sha256", "protocol_sha256",
    "calibration_recipe_sha256", "fold_registry_sha256",
    "fold_review_sha256", "final_cutoff_utc", "code_commit", "state_sha256"
  )
}

phase19_fold_review_schema <- function() {
  c(
    "schema_version", "hash_encoding_version", "forecast_domain",
    "authority_mode", "fixture_authority", "reviewer", "reviewed_at_utc",
    "decision", "accepted_generation_id", "corpus_manifest_sha256",
    "snapshot_sha256", "policy_review_sha256", "protocol_sha256",
    "calibration_recipe_sha256", "fold_registry_sha256", "final_cutoff_utc",
    "code_commit", "rationale_code", "review_sha256"
  )
}

phase19_protocol_pointer_schema <- function() {
  c(
    "schema_version", "hash_encoding_version", "authority_mode",
    "fixture_authority", "generation_id", "protocol_state_sha256",
    "pointer_sha256"
  )
}

phase19_protocol_state_sha256 <- function(state) {
  schema <- phase19_protocol_state_schema()
  if (!is.list(state) || !identical(names(state), schema)) {
    phase19_fold_abort("protocol_state_invalid", "Protocol state schema is not exact")
  }
  values <- state[setdiff(schema, "state_sha256")]
  phase18_hash_sequence_v2(
    values, domain = "phase19-club-fold-protocol-state-v1",
    names = names(values), types = vapply(values, phase18_v2_type_tag, character(1))
  )
}

phase19_fold_review_sha256 <- function(review) {
  schema <- phase19_fold_review_schema()
  if (!is.list(review) || !identical(names(review), schema)) {
    phase19_fold_abort("fold_review_invalid", "Fold review schema is not exact")
  }
  values <- review[setdiff(schema, "review_sha256")]
  phase18_hash_sequence_v2(
    values, domain = "phase19-club-fold-review-v1",
    names = names(values), types = vapply(values, phase18_v2_type_tag, character(1))
  )
}

phase19_protocol_pointer_sha256 <- function(pointer) {
  schema <- phase19_protocol_pointer_schema()
  if (!is.list(pointer) || !identical(names(pointer), schema)) {
    phase19_fold_abort("protocol_pointer_invalid", "Protocol pointer schema is not exact")
  }
  values <- pointer[setdiff(schema, "pointer_sha256")]
  phase18_hash_sequence_v2(
    values, domain = "phase19-club-fold-protocol-pointer-v1",
    names = names(values), types = vapply(values, phase18_v2_type_tag, character(1))
  )
}

phase19_fold_candidate_parents <- function(candidate) {
  fields <- c(
    "accepted_generation_id", "corpus_manifest_sha256", "snapshot_sha256",
    "policy_review_sha256", "protocol_sha256", "calibration_recipe_sha256",
    "fold_registry_sha256", "final_cutoff_utc", "code_commit"
  )
  missing <- setdiff(fields, names(candidate))
  if (length(missing)) {
    phase19_fold_abort(
      "fold_candidate_invalid",
      paste0("Fold candidate parents are missing: ", paste(missing, collapse = ", "))
    )
  }
  values <- unname(candidate[fields]) |> setNames(fields)
  values[] <- lapply(values, function(value) as.character(value[[1L]]))
  values
}

phase19_validate_fold_review <- function(review, candidate, require_accepted = FALSE) {
  schema <- phase19_fold_review_schema()
  if (!is.list(review) || !identical(names(review), schema)) {
    phase19_fold_abort("fold_review_invalid", "Fold review schema is not exact")
  }
  review[] <- lapply(review, function(value) {
    if (is.logical(value)) isTRUE(value[[1L]]) else as.character(value[[1L]])
  })
  if (!identical(review$schema_version, "phase19-club-fold-review-v1") ||
      !identical(review$hash_encoding_version, phase18_canonical_encoding_v2()) ||
      !identical(review$forecast_domain, "club") ||
      !review$authority_mode %in% c("production", "fixture") ||
      !identical(review$fixture_authority, identical(review$authority_mode, "fixture")) ||
      !review$decision %in% c("pending", "accepted", "rejected") ||
      !phase19_is_sha256(review$review_sha256) ||
      !identical(review$review_sha256, phase19_fold_review_sha256(review))) {
    phase19_fold_abort("fold_review_invalid", "Fold review metadata or self-hash is invalid")
  }
  parents <- phase19_fold_candidate_parents(candidate)
  if (!identical(
    unname(unlist(review[names(parents)], use.names = FALSE)),
    unname(unlist(parents, use.names = FALSE))
  )) {
    phase19_fold_abort("fold_inventory_not_approved", "Fold review does not bind the exact candidate parents")
  }
  if (identical(review$decision, "pending")) {
    if (nzchar(review$reviewer) || nzchar(review$reviewed_at_utc) ||
        !identical(review$rationale_code, "pending_owner_review")) {
      phase19_fold_abort("fold_review_invalid", "Pending fold review invents owner evidence")
    }
  } else {
    if (!nzchar(review$reviewer) ||
        !grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$",
               review$reviewed_at_utc) || !nzchar(review$rationale_code)) {
      phase19_fold_abort("fold_review_invalid", "Decided fold review lacks owner, UTC, or rationale evidence")
    }
    phase19_fold_parse_utc(review$reviewed_at_utc, "reviewed_at_utc")
  }
  if (isTRUE(require_accepted) && !identical(review$decision, "accepted")) {
    phase19_fold_abort("fold_inventory_not_approved", "Fold inventory owner review is not accepted")
  }
  invisible(review)
}

phase19_validate_protocol_state <- function(state, candidate = NULL) {
  schema <- phase19_protocol_state_schema()
  if (!is.list(state) || !identical(names(state), schema)) {
    phase19_fold_abort("protocol_state_invalid", "Protocol state schema is not exact")
  }
  state[] <- lapply(state, function(value) {
    if (is.logical(value)) isTRUE(value[[1L]]) else as.character(value[[1L]])
  })
  if (!identical(state$schema_version, "phase19-club-fold-protocol-state-v1") ||
      !identical(state$hash_encoding_version, phase18_canonical_encoding_v2()) ||
      !identical(state$forecast_domain, "club") ||
      !state$authority_mode %in% c("production", "fixture") ||
      !identical(state$fixture_authority, identical(state$authority_mode, "fixture")) ||
      !state$state %in% c("blocked", "pending_review", "ready") ||
      !phase19_is_sha256(state$state_sha256) ||
      !identical(state$state_sha256, phase19_protocol_state_sha256(state))) {
    phase19_fold_abort("protocol_state_invalid", "Protocol state metadata or self-hash is invalid")
  }
  if (identical(state$state, "blocked")) {
    blank <- c(
      "generation_id", "accepted_generation_id", "corpus_manifest_sha256",
      "snapshot_sha256", "fold_registry_sha256", "final_cutoff_utc", "code_commit"
    )
    if (!identical(state$reason_code, "no_accepted_club_history") ||
        any(nzchar(unlist(state[blank], use.names = FALSE)))) {
      phase19_fold_abort("protocol_state_invalid", "Blocked protocol fabricates accepted fold authority")
    }
  } else {
    hashes <- c(
      "corpus_manifest_sha256", "snapshot_sha256", "policy_review_sha256",
      "protocol_sha256", "calibration_recipe_sha256", "fold_registry_sha256",
      "fold_review_sha256"
    )
    if (!nzchar(state$generation_id) || !nzchar(state$accepted_generation_id) ||
        any(!vapply(state[hashes], phase19_is_sha256, logical(1))) ||
        !grepl("^[0-9a-f]{40}$", state$code_commit) ||
        nzchar(state$reason_code) != !identical(state$state, "ready")) {
      phase19_fold_abort("protocol_state_invalid", "Pending or ready protocol parents are incomplete")
    }
    phase19_fold_parse_utc(state$final_cutoff_utc, "final_cutoff_utc")
  }
  if (!is.null(candidate)) {
    parents <- phase19_fold_candidate_parents(candidate)
    if (!identical(
      unname(unlist(state[names(parents)], use.names = FALSE)),
      unname(unlist(parents, use.names = FALSE))
    )) {
      phase19_fold_abort("protocol_state_invalid", "Protocol state does not bind the exact candidate parents")
    }
  }
  invisible(state)
}

phase19_build_fold_review <- function(candidate, decision = "pending", reviewer = "",
                                      reviewed_at_utc = "",
                                      rationale_code = "pending_owner_review") {
  parents <- phase19_fold_candidate_parents(candidate)
  authority_mode <- as.character(candidate$authority_mode[[1L]])
  review <- list(
    schema_version = "phase19-club-fold-review-v1",
    hash_encoding_version = phase18_canonical_encoding_v2(),
    forecast_domain = "club", authority_mode = authority_mode,
    fixture_authority = identical(authority_mode, "fixture"),
    reviewer = as.character(reviewer), reviewed_at_utc = as.character(reviewed_at_utc),
    decision = as.character(decision),
    accepted_generation_id = parents$accepted_generation_id,
    corpus_manifest_sha256 = parents$corpus_manifest_sha256,
    snapshot_sha256 = parents$snapshot_sha256,
    policy_review_sha256 = parents$policy_review_sha256,
    protocol_sha256 = parents$protocol_sha256,
    calibration_recipe_sha256 = parents$calibration_recipe_sha256,
    fold_registry_sha256 = parents$fold_registry_sha256,
    final_cutoff_utc = parents$final_cutoff_utc,
    code_commit = parents$code_commit,
    rationale_code = as.character(rationale_code), review_sha256 = ""
  )
  review$review_sha256 <- phase19_fold_review_sha256(review)
  phase19_validate_fold_review(review, candidate, require_accepted = FALSE)
  review
}

phase19_build_protocol_state <- function(candidate, review, state = "pending_review",
                                         generation_id = "") {
  parents <- phase19_fold_candidate_parents(candidate)
  phase19_validate_fold_review(
    review, candidate, require_accepted = identical(state, "ready")
  )
  authority_mode <- as.character(candidate$authority_mode[[1L]])
  result <- list(
    schema_version = "phase19-club-fold-protocol-state-v1",
    hash_encoding_version = phase18_canonical_encoding_v2(),
    forecast_domain = "club", authority_mode = authority_mode,
    fixture_authority = identical(authority_mode, "fixture"),
    state = as.character(state),
    reason_code = if (identical(state, "pending_review")) {
      "fold_inventory_not_approved"
    } else "",
    generation_id = as.character(generation_id),
    accepted_generation_id = parents$accepted_generation_id,
    corpus_manifest_sha256 = parents$corpus_manifest_sha256,
    snapshot_sha256 = parents$snapshot_sha256,
    policy_review_sha256 = parents$policy_review_sha256,
    protocol_sha256 = parents$protocol_sha256,
    calibration_recipe_sha256 = parents$calibration_recipe_sha256,
    fold_registry_sha256 = parents$fold_registry_sha256,
    fold_review_sha256 = as.character(review$review_sha256),
    final_cutoff_utc = parents$final_cutoff_utc,
    code_commit = parents$code_commit, state_sha256 = ""
  )
  result$state_sha256 <- phase19_protocol_state_sha256(result)
  phase19_validate_protocol_state(result, candidate)
  result
}

phase19_read_json_exact <- function(path, schema, reason_code) {
  phase19_assert_regular_file(path, reason_code)
  value <- as.list(jsonlite::fromJSON(path, simplifyVector = TRUE))
  if (!identical(names(value), schema)) {
    phase19_fold_abort(reason_code, paste0("JSON schema is not exact: ", basename(path)))
  }
  value
}

phase19_write_json_atomic <- function(value, path) {
  directory <- dirname(path)
  if (!dir.exists(directory)) dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  stage <- tempfile(paste0(".", basename(path), "-"), tmpdir = directory)
  on.exit(if (file.exists(stage)) unlink(stage, force = TRUE), add = TRUE)
  jsonlite::write_json(value, stage, auto_unbox = TRUE, pretty = TRUE, null = "null")
  if (!file.rename(stage, path)) {
    phase19_fold_abort("protocol_write_failed", paste0("Could not atomically install ", path))
  }
  invisible(path)
}

phase19_read_fold_registry <- function(path, allow_empty = FALSE) {
  phase19_assert_regular_file(path, "fold_registry_invalid")
  schema <- phase19_fold_registry_schema()
  classes <- rep("character", length(schema))
  classes[match("fixture_authority", schema)] <- "logical"
  classes[match(c(
    "declared_fixture_count", "training_fixture_count", "calibration_fixture_count"
  ), schema)] <- "integer"
  registry <- utils::read.csv(
    path, stringsAsFactors = FALSE, check.names = FALSE,
    na.strings = character(), colClasses = classes
  )
  if (!identical(names(registry), schema) || (!isTRUE(allow_empty) && !nrow(registry))) {
    phase19_fold_abort("fold_registry_invalid", "Persisted fold registry schema or inventory is invalid")
  }
  registry
}

phase19_write_fold_registry <- function(registry, path) {
  if (!is.data.frame(registry) || !identical(names(registry), phase19_fold_registry_schema())) {
    phase19_fold_abort("fold_registry_invalid", "Cannot write a non-canonical fold registry")
  }
  directory <- dirname(path)
  if (!dir.exists(directory)) dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  stage <- tempfile(".fold-registry-", tmpdir = directory)
  on.exit(if (file.exists(stage)) unlink(stage, force = TRUE), add = TRUE)
  utils::write.csv(registry, stage, row.names = FALSE, na = "", quote = TRUE)
  if (!file.rename(stage, path)) {
    phase19_fold_abort("protocol_write_failed", "Could not atomically install fold registry")
  }
  invisible(path)
}

phase19_protocol_generation_files <- function() {
  c("fold_registry.csv", "protocol_state.json", "calibration_recipe.json", "fold_review.json")
}

phase19_protocol_candidate <- function(snapshot, protocol, authority_mode, code_commit) {
  if (!grepl("^[0-9a-f]{40}$", as.character(code_commit))) {
    phase19_fold_abort("fold_candidate_invalid", "Code commit must be one lowercase full SHA-1")
  }
  folds <- phase19_fold_raw_registry(snapshot, protocol, authority_mode)
  phase19_validate_fold_registry(folds, snapshot, protocol, authority_mode)
  fold_hash <- phase19_fold_registry_sha256(folds, snapshot, protocol, authority_mode)
  recipe <- phase19_expected_calibration_recipe()
  parents <- phase19_fold_policy_parents(protocol)
  candidate <- structure(list(
    status = "pending_review", reason_code = "fold_inventory_not_approved",
    authority_mode = authority_mode,
    fixture_authority = identical(authority_mode, "fixture"),
    production_eligible = FALSE, forecast_domain = "club",
    accepted_generation_id = as.character(snapshot$accepted_generation_id),
    corpus_manifest_sha256 = as.character(snapshot$corpus_manifest_sha256),
    snapshot_sha256 = as.character(snapshot$snapshot_sha256),
    policy_review_sha256 = parents$policy_review_sha256,
    protocol_sha256 = parents$protocol_sha256,
    calibration_recipe_sha256 = as.character(recipe$recipe_sha256),
    fold_registry_sha256 = fold_hash,
    final_cutoff_utc = as.character(snapshot$cutoff_utc),
    code_commit = as.character(code_commit), fold_registry = folds,
    calibration_recipe = recipe, snapshot = snapshot, protocol = protocol
  ), class = c("phase19_club_fold_protocol", "list"))
  candidate
}

phase19_protocol_generation_id <- function(candidate, review) {
  digest <- phase18_hash_sequence_v2(
    list(
      fold_registry_sha256 = as.character(candidate$fold_registry_sha256),
      fold_review_sha256 = as.character(review$review_sha256),
      state = as.character(review$decision)
    ),
    domain = "phase19-club-fold-generation-id-v1",
    names = c("fold_registry_sha256", "fold_review_sha256", "state"),
    types = rep("character", 3L)
  )
  paste0("club-folds-", substr(digest, 1L, 24L))
}

phase19_protocol_pointer <- function(authority_mode, generation_id, state_sha256) {
  pointer <- list(
    schema_version = "phase19-club-fold-protocol-pointer-v1",
    hash_encoding_version = phase18_canonical_encoding_v2(),
    authority_mode = authority_mode,
    fixture_authority = identical(authority_mode, "fixture"),
    generation_id = generation_id,
    protocol_state_sha256 = state_sha256,
    pointer_sha256 = ""
  )
  pointer$pointer_sha256 <- phase19_protocol_pointer_sha256(pointer)
  pointer
}

phase19_validate_protocol_pointer <- function(pointer, authority_mode) {
  if (!is.list(pointer) || !identical(names(pointer), phase19_protocol_pointer_schema()) ||
      !identical(as.character(pointer$schema_version), "phase19-club-fold-protocol-pointer-v1") ||
      !identical(as.character(pointer$hash_encoding_version), phase18_canonical_encoding_v2()) ||
      !identical(as.character(pointer$authority_mode), authority_mode) ||
      !identical(isTRUE(pointer$fixture_authority), identical(authority_mode, "fixture")) ||
      !grepl("^club-folds-[0-9a-f]{24}$", as.character(pointer$generation_id)) ||
      !phase19_is_sha256(pointer$protocol_state_sha256) ||
      !phase19_is_sha256(pointer$pointer_sha256) ||
      !identical(as.character(pointer$pointer_sha256), phase19_protocol_pointer_sha256(pointer))) {
    phase19_fold_abort("protocol_pointer_invalid", "Protocol pointer metadata or self-hash is invalid")
  }
  invisible(pointer)
}

phase19_protocol_write_generation <- function(runtime_root, candidate, review, state_name) {
  phase19_validate_fold_review(
    review, candidate, require_accepted = identical(state_name, "ready")
  )
  generation_id <- phase19_protocol_generation_id(candidate, review)
  state <- phase19_build_protocol_state(candidate, review, state_name, generation_id)
  generations <- file.path(runtime_root, "generations")
  if (!dir.exists(generations)) dir.create(generations, recursive = TRUE, showWarnings = FALSE)
  stage <- tempfile(".club-fold-generation-", tmpdir = generations)
  dir.create(stage)
  on.exit(if (dir.exists(stage)) unlink(stage, recursive = TRUE, force = TRUE), add = TRUE)
  phase19_write_fold_registry(candidate$fold_registry, file.path(stage, "fold_registry.csv"))
  phase19_write_json_atomic(state, file.path(stage, "protocol_state.json"))
  phase19_write_json_atomic(candidate$calibration_recipe, file.path(stage, "calibration_recipe.json"))
  phase19_write_json_atomic(review, file.path(stage, "fold_review.json"))
  if (!identical(sort(list.files(stage), method = "radix"),
                 sort(phase19_protocol_generation_files(), method = "radix"))) {
    phase19_fold_abort("protocol_write_failed", "Staged protocol inventory is incomplete")
  }
  final <- file.path(generations, generation_id)
  if (file.exists(final) || dir.exists(final)) {
    phase19_fold_abort("protocol_write_failed", "Immutable fold generation already exists")
  }
  if (!file.rename(stage, final)) {
    phase19_fold_abort("protocol_write_failed", "Could not install immutable fold generation")
  }
  pointer <- phase19_protocol_pointer(
    candidate$authority_mode, generation_id, state$state_sha256
  )
  phase19_write_json_atomic(pointer, file.path(runtime_root, "protocol_current.json"))
  list(state = state, review = review, generation_id = generation_id, pointer = pointer)
}

phase19_protocol_read_generation <- function(runtime_root, snapshot, protocol,
                                             authority_mode) {
  pointer_path <- file.path(runtime_root, "protocol_current.json")
  pointer <- phase19_read_json_exact(
    pointer_path, phase19_protocol_pointer_schema(), "protocol_pointer_invalid"
  )
  phase19_validate_protocol_pointer(pointer, authority_mode)
  generation <- file.path(runtime_root, "generations", as.character(pointer$generation_id))
  if (!dir.exists(generation) || nzchar(Sys.readlink(generation)) ||
      !identical(sort(list.files(generation), method = "radix"),
                 sort(phase19_protocol_generation_files(), method = "radix"))) {
    phase19_fold_abort("protocol_generation_invalid", "Selected protocol generation is unsafe or incomplete")
  }
  folds <- phase19_read_fold_registry(file.path(generation, "fold_registry.csv"))
  phase19_validate_fold_registry(folds, snapshot, protocol, authority_mode)
  recipe <- phase19_read_json_exact(
    file.path(generation, "calibration_recipe.json"),
    phase19_calibration_recipe_schema(), "calibration_recipe_invalid"
  )
  phase19_validate_calibration_recipe(recipe)
  state <- phase19_read_json_exact(
    file.path(generation, "protocol_state.json"),
    phase19_protocol_state_schema(), "protocol_state_invalid"
  )
  review <- phase19_read_json_exact(
    file.path(generation, "fold_review.json"),
    phase19_fold_review_schema(), "fold_review_invalid"
  )
  candidate <- phase19_protocol_candidate(
    snapshot, protocol, authority_mode, as.character(state$code_commit)
  )
  phase19_validate_fold_review(
    review, candidate, require_accepted = identical(as.character(state$state), "ready")
  )
  phase19_validate_protocol_state(state, candidate)
  if (!identical(as.character(state$generation_id), as.character(pointer$generation_id)) ||
      !identical(as.character(state$state_sha256), as.character(pointer$protocol_state_sha256)) ||
      !identical(as.character(state$fold_review_sha256), as.character(review$review_sha256))) {
    phase19_fold_abort("protocol_generation_invalid", "Pointer, state, or review identity drifted")
  }
  status <- if (identical(as.character(state$state), "ready")) "ready" else "blocked"
  reason <- if (identical(status, "ready")) "" else "fold_inventory_not_approved"
  result <- candidate
  result$status <- status
  result$reason_code <- reason
  result$production_eligible <- identical(status, "ready") &&
    identical(authority_mode, "production")
  result$fold_registry <- folds
  result$calibration_recipe <- recipe
  result$protocol_state <- state
  result$fold_review <- review
  result$generation_id <- as.character(state$generation_id)
  result$protocol_pointer <- pointer
  class(result) <- c("phase19_club_fold_protocol", "list")
  result
}

phase19_publish_fixture_fold_candidate <- function(fixture_root, snapshot, protocol,
                                                   code_commit) {
  fixture <- phase19_validate_fixture_root(fixture_root)
  if (!identical(snapshot$fixture_root_sha256, as.character(fixture$marker$fixture_root_sha256))) {
    phase19_fold_abort("fold_authority_invalid", "Fixture snapshot belongs to another root")
  }
  candidate <- phase19_protocol_candidate(snapshot, protocol, "fixture", code_commit)
  review <- phase19_build_fold_review(candidate)
  runtime_root <- file.path(fixture$root, "model_protocol")
  phase19_protocol_write_generation(runtime_root, candidate, review, "pending_review")
  candidate
}

phase19_load_fixture_fold_protocol <- function(fixture_root) {
  fixture <- phase19_validate_fixture_root(fixture_root)
  snapshot <- phase19_load_fixture_club_training_snapshot(fixture$root)
  protocol <- phase19_load_fixture_club_evaluation_protocol()
  phase19_protocol_read_generation(
    file.path(fixture$root, "model_protocol"), snapshot, protocol, "fixture"
  )
}

phase19_apply_fixture_fold_review <- function(fixture_root, review) {
  fixture <- phase19_validate_fixture_root(fixture_root)
  current <- phase19_load_fixture_fold_protocol(fixture$root)
  phase19_validate_fold_review(review, current, require_accepted = TRUE)
  runtime_root <- file.path(fixture$root, "model_protocol")
  phase19_protocol_write_generation(runtime_root, current, review, "ready")
  invisible(phase19_load_fixture_fold_protocol(fixture$root))
}

phase19_blocked_fold_candidate <- function(protocol, recipe) {
  list(
    accepted_generation_id = "", corpus_manifest_sha256 = "", snapshot_sha256 = "",
    policy_review_sha256 = as.character(protocol$policy_review$review_sha256),
    protocol_sha256 = as.character(protocol$protocol_sha256),
    calibration_recipe_sha256 = as.character(recipe$recipe_sha256),
    fold_registry_sha256 = "", final_cutoff_utc = "", code_commit = ""
  )
}

phase19_load_blocked_fold_protocol <- function() {
  root <- file.path(.phase19_club_project_root, "data", "club", "model_protocol")
  protocol <- phase19_protocol_components(include_review = TRUE)
  phase19_validate_policy_review(protocol$policy_review, protocol, require_accepted = FALSE)
  folds <- phase19_read_fold_registry(file.path(root, "fold_registry.csv"), allow_empty = TRUE)
  if (nrow(folds)) {
    phase19_fold_abort("protocol_state_invalid", "Bootstrap blocked fold registry must be header-only")
  }
  recipe <- phase19_read_json_exact(
    file.path(root, "calibration_recipe.json"),
    phase19_calibration_recipe_schema(), "calibration_recipe_invalid"
  )
  phase19_validate_calibration_recipe(recipe)
  candidate <- phase19_blocked_fold_candidate(protocol, recipe)
  review <- phase19_read_json_exact(
    file.path(root, "fold_review.json"), phase19_fold_review_schema(),
    "fold_review_invalid"
  )
  state <- phase19_read_json_exact(
    file.path(root, "protocol_state.json"), phase19_protocol_state_schema(),
    "protocol_state_invalid"
  )
  phase19_validate_fold_review(review, candidate, require_accepted = FALSE)
  phase19_validate_protocol_state(state)
  if (!identical(as.character(state$policy_review_sha256), candidate$policy_review_sha256) ||
      !identical(as.character(state$protocol_sha256), candidate$protocol_sha256) ||
      !identical(as.character(state$calibration_recipe_sha256), candidate$calibration_recipe_sha256) ||
      !identical(as.character(state$fold_review_sha256), as.character(review$review_sha256))) {
    phase19_fold_abort("protocol_state_invalid", "Blocked state parents drifted")
  }
  structure(list(
    status = "blocked", reason_code = "no_accepted_club_history",
    authority_mode = "production", fixture_authority = FALSE,
    production_eligible = FALSE, forecast_domain = "club",
    fold_registry = folds, fold_registry_sha256 = "",
    calibration_recipe = recipe, protocol_state = state,
    fold_review = review, protocol = protocol, protocol_pointer = NULL
  ), class = c("phase19_club_fold_protocol", "list"))
}

phase19_club_fold_runtime_root <- function() {
  file.path(.phase19_club_project_root, "data", "club", "fold_protocol_runtime")
}

phase19_load_club_fold_protocol <- function(...) {
  phase19_reject_arbitrary_arguments(list(...))
  runtime_root <- phase19_club_fold_runtime_root()
  pointer <- file.path(runtime_root, "protocol_current.json")
  if (!file.exists(pointer)) return(phase19_load_blocked_fold_protocol())
  snapshot <- phase19_load_club_training_snapshot()
  if (!identical(snapshot$status, "ready")) {
    phase19_fold_abort("protocol_state_invalid", "Runtime fold authority exists without accepted history")
  }
  protocol <- phase19_load_club_evaluation_protocol()
  if (!identical(protocol$status, "ready")) {
    phase19_fold_abort("protocol_policy_not_approved", "Runtime fold authority exists without accepted policy")
  }
  phase19_protocol_read_generation(runtime_root, snapshot, protocol, "production")
}

phase19_refresh_club_fold_protocol <- function(...) {
  phase19_reject_arbitrary_arguments(list(...))
  snapshot <- phase19_load_club_training_snapshot()
  if (!identical(snapshot$status, "ready")) return(phase19_load_blocked_fold_protocol())
  protocol <- phase19_load_club_evaluation_protocol()
  if (!identical(protocol$status, "ready")) {
    return(structure(list(
      status = "blocked", reason_code = "protocol_policy_not_approved",
      authority_mode = "production", fixture_authority = FALSE,
      production_eligible = FALSE, forecast_domain = "club"
    ), class = c("phase19_club_fold_protocol", "list")))
  }
  commit <- tryCatch(
    system2("git", c("rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE),
    error = function(error) character()
  )
  if (length(commit) != 1L || !grepl("^[0-9a-f]{40}$", commit)) {
    phase19_fold_abort("fold_candidate_invalid", "Could not bind the current code commit")
  }
  candidate <- phase19_protocol_candidate(snapshot, protocol, "production", commit)
  review <- phase19_build_fold_review(candidate)
  phase19_protocol_write_generation(
    phase19_club_fold_runtime_root(), candidate, review, "pending_review"
  )
  phase19_load_club_fold_protocol()
}

phase19_apply_club_fold_review <- function(review, ...) {
  phase19_reject_arbitrary_arguments(list(...))
  current <- phase19_load_club_fold_protocol()
  if (!identical(current$authority_mode, "production") ||
      isTRUE(current$fixture_authority) ||
      !identical(current$status, "blocked") ||
      !identical(current$reason_code, "fold_inventory_not_approved")) {
    phase19_fold_abort(
      "fold_inventory_not_approved",
      "Production fold review requires one exact pending production inventory"
    )
  }
  phase19_validate_fold_review(review, current, require_accepted = TRUE)
  phase19_protocol_write_generation(
    phase19_club_fold_runtime_root(), current, review, "ready"
  )
  invisible(phase19_load_club_fold_protocol())
}

phase19_assert_production_fold_protocol <- function(protocol) {
  if (!inherits(protocol, "phase19_club_fold_protocol") ||
      !identical(protocol$status, "ready") ||
      !identical(protocol$authority_mode, "production") ||
      isTRUE(protocol$fixture_authority) || !isTRUE(protocol$production_eligible)) {
    phase19_fold_abort(
      "fold_authority_invalid",
      "Only an exact owner-reviewed production fold protocol is consumable"
    )
  }
  graph_valid <- tryCatch({
    pointer <- protocol$protocol_pointer
    state <- protocol$protocol_state
    review <- protocol$fold_review
    phase19_validate_protocol_pointer(pointer, "production")
    is.list(state) && is.list(review) &&
      identical(as.character(pointer$generation_id), as.character(protocol$generation_id)) &&
      identical(as.character(pointer$protocol_state_sha256), as.character(state$state_sha256)) &&
      identical(as.character(state$generation_id), as.character(pointer$generation_id)) &&
      identical(as.character(state$fold_review_sha256), as.character(review$review_sha256)) &&
      identical(as.character(review$decision), "accepted") &&
      identical(as.character(review$fold_registry_sha256), as.character(protocol$fold_registry_sha256)) &&
      identical(as.character(state$state), "ready")
  }, error = function(error) FALSE)
  if (!isTRUE(graph_valid)) {
    phase19_fold_abort(
      "fold_authority_invalid",
      "Production fold protocol is missing its exact persisted pointer and review graph"
    )
  }
  invisible(protocol)
}
