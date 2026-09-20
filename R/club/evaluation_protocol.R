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
