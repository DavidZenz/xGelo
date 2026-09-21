library(testthat)

phase19_protocol_test_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/", mustWork = TRUE
)

phase19_protocol_test_load <- function() {
  paths <- c(
    "R/common/phase18_canonical_hash.R",
    "R/club/model_contract.R",
    "R/club/evaluation_protocol.R"
  )
  for (path in file.path(phase19_protocol_test_root, paths)) {
    if (!file.exists(path)) stop("RED: missing Phase 19 protocol dependency: ", path, call. = FALSE)
    source(path, local = .GlobalEnv)
  }
  invisible(TRUE)
}

phase19_protocol_test_require <- function(functions) {
  missing <- functions[!vapply(functions, exists, logical(1), mode = "function")]
  if (length(missing)) stop("RED: missing Phase 19 protocol API: ", paste(missing, collapse = ", "), call. = FALSE)
}

phase19_protocol_rehash_candidates <- function(registry) {
  registry$row_sha256 <- phase19_candidate_row_sha256(registry)
  registry
}

phase19_protocol_rehash_seeds <- function(registry) {
  registry$row_sha256 <- phase19_seed_row_sha256(registry)
  registry
}

phase19_protocol_rehash_gates <- function(registry) {
  registry$row_sha256 <- phase19_gate_row_sha256(registry)
  registry
}

phase19_protocol_test_review <- function(protocol, decision = "accepted",
                                         reviewer = "phase19-test-owner",
                                         reviewed_at_utc = "2026-09-20T12:00:00Z") {
  review <- list(
    schema_version = "phase19-club-policy-review-v1",
    hash_encoding_version = "phase18-canonical-v2",
    forecast_domain = "club",
    reviewer = reviewer,
    reviewed_at_utc = reviewed_at_utc,
    decision = decision,
    candidate_registry_sha256 = protocol$candidate_registry_sha256,
    gate_registry_sha256 = protocol$gate_registry_sha256,
    seed_registry_sha256 = protocol$seed_registry_sha256,
    feature_contract_sha256 = protocol$feature_contract_sha256,
    protocol_sha256 = protocol$protocol_sha256,
    rationale_code = if (decision == "accepted") "fixture_test_acceptance" else paste0("fixture_test_", decision),
    review_sha256 = ""
  )
  review$review_sha256 <- phase19_policy_review_sha256(review)
  review
}

test_that("committed candidate and seed authority is exact club-only policy", {
  phase19_protocol_test_load()
  phase19_protocol_test_require(c(
    "phase19_load_club_candidate_seed_policy",
    "phase19_validate_candidate_registry",
    "phase19_validate_seed_registry",
    "phase19_candidate_registry_sha256",
    "phase19_seed_registry_sha256"
  ))

  policy <- phase19_load_club_candidate_seed_policy()
  candidates <- policy$candidate_registry
  seeds <- policy$seed_registry

  expect_s3_class(policy, "phase19_club_protocol_candidate")
  expect_identical(policy$status, "ready")
  expect_identical(policy$authority_mode, "fixture")
  expect_true(policy$fixture_authority)
  expect_false(policy$production_eligible)
  expect_identical(policy$forecast_domain, "club")
  expect_identical(
    as.character(candidates$model_id),
    c("uniform_1x2", "expanding_1x2", "club_venue_nb", "club_elo_nb")
  )
  expect_identical(
    as.character(candidates$registry_role),
    c("sanity_control", "historical_control", "promotion_incumbent", "promotion_candidate")
  )
  expect_identical(
    as.character(candidates$selection_role),
    c("report_only", "report_only", "incumbent", "candidate")
  )
  expect_identical(which(candidates$release_selectable), c(3L, 4L))
  expect_identical(which(candidates$registry_role == "promotion_incumbent"), 3L)
  expect_identical(candidates$output_capability[[1L]], "1x2_only_non_goal_distribution")
  expect_false(candidates$goal_distribution_declared[[1L]])
  expect_true(all(candidates$score_support_min[-1L] == 0L))
  expect_true(all(candidates$score_support_max[-1L] == 40L))

  candidate <- candidates[candidates$model_id == "club_elo_nb", , drop = FALSE]
  expect_identical(candidate$base_rating, 1500L)
  expect_identical(candidate$elo_k_candidates, "20|30|40")
  expect_identical(candidate$home_advantage_candidates, "40|60|80")
  expect_identical(candidate$inactivity_factor_candidates, "0.99|0.995|0.999")
  expect_identical(candidate$tuning_scope, "inner_fold_only")
  expect_false(candidate$outer_assessment_tuning_allowed)
  expect_identical(candidate$formula, "goals ~ elo_difference_for_team + venue_role")

  expect_identical(
    as.character(seeds$purpose),
    c("candidate_tuning", "calibration", "paired_bootstrap", "isolated_reproducibility_replay")
  )
  expect_true(all(seeds$seed > 0L))
  expect_identical(anyDuplicated(seeds$seed), 0L)
  expect_identical(anyDuplicated(seeds$purpose), 0L)
  expect_true(all(candidates$forecast_domain == "club"))
  expect_true(all(seeds$forecast_domain == "club"))
  expect_true(all(grepl("^[0-9a-f]{64}$", c(
    policy$candidate_registry_sha256,
    policy$seed_registry_sha256,
    policy$candidate_seed_policy_sha256
  ))))
  expect_identical(
    policy$candidate_registry_sha256,
    phase19_candidate_registry_sha256(candidates)
  )
  expect_identical(policy$seed_registry_sha256, phase19_seed_registry_sha256(seeds))
  expect_silent(phase19_validate_candidate_registry(candidates, phase19_load_feature_contract()))
  expect_silent(phase19_validate_seed_registry(seeds))
})

test_that("canonical candidate and seed projections ignore physical row order but not drift", {
  phase19_protocol_test_load()
  policy <- phase19_load_club_candidate_seed_policy()
  candidates <- policy$candidate_registry
  seeds <- policy$seed_registry
  reverse_candidates <- candidates[rev(seq_len(nrow(candidates))), , drop = FALSE]
  reverse_seeds <- seeds[rev(seq_len(nrow(seeds))), , drop = FALSE]

  expect_silent(phase19_validate_candidate_registry(reverse_candidates, phase19_load_feature_contract()))
  expect_silent(phase19_validate_seed_registry(reverse_seeds))
  expect_identical(
    phase19_candidate_registry_sha256(reverse_candidates),
    policy$candidate_registry_sha256
  )
  expect_identical(phase19_seed_registry_sha256(reverse_seeds), policy$seed_registry_sha256)
  expect_identical(
    phase19_candidate_seed_policy_sha256(reverse_candidates, reverse_seeds),
    policy$candidate_seed_policy_sha256
  )

  value_edit <- candidates
  value_edit$elo_k_candidates[value_edit$model_id == "club_elo_nb"] <- "20|30|50"
  value_edit <- phase19_protocol_rehash_candidates(value_edit)
  expect_error(
    phase19_validate_candidate_registry(value_edit, phase19_load_feature_contract()),
    class = "phase19_protocol_registry_error"
  )
  seed_edit <- seeds
  seed_edit$seed[[1L]] <- seed_edit$seed[[1L]] + 1L
  seed_edit <- phase19_protocol_rehash_seeds(seed_edit)
  expect_error(phase19_validate_seed_registry(seed_edit), class = "phase19_protocol_registry_error")
})

test_that("candidate role domain tuning formula and seed attacks fail closed", {
  phase19_protocol_test_load()
  policy <- phase19_load_club_candidate_seed_policy()
  feature_contract <- phase19_load_feature_contract()
  candidates <- policy$candidate_registry
  seeds <- policy$seed_registry

  candidate_attacks <- list(
    missing = candidates[-1L, , drop = FALSE],
    duplicate = rbind(candidates, candidates[1L, , drop = FALSE]),
    unknown_role = transform(candidates, registry_role = replace(registry_role, 1L, "release_champion")),
    extra_incumbent = transform(candidates, registry_role = replace(registry_role, 2L, "promotion_incumbent")),
    outer_tuning = transform(candidates, outer_assessment_tuning_allowed = replace(outer_assessment_tuning_allowed, 4L, TRUE)),
    unavailable_formula = transform(candidates, formula = replace(formula, 4L, "goals ~ elo_difference_for_team + injury")),
    national_domain = transform(candidates, forecast_domain = replace(forecast_domain, 4L, "national_team")),
    national_parent = transform(candidates, settings_status = replace(settings_status, 4L, "open_core")),
    hash_drift = transform(candidates, row_sha256 = replace(row_sha256, 1L, paste(rep("a", 64L), collapse = "")))
  )
  for (name in setdiff(names(candidate_attacks), c("missing", "duplicate", "hash_drift"))) {
    candidate_attacks[[name]] <- phase19_protocol_rehash_candidates(candidate_attacks[[name]])
  }
  for (name in names(candidate_attacks)) {
    expect_error(
      phase19_validate_candidate_registry(candidate_attacks[[name]], feature_contract),
      class = "phase19_protocol_registry_error",
      info = name
    )
  }

  seed_attacks <- list(
    duplicate_purpose = transform(seeds, purpose = replace(purpose, 2L, purpose[[1L]])),
    duplicate_seed = transform(seeds, seed = replace(seed, 2L, seed[[1L]])),
    nonpositive = transform(seeds, seed = replace(seed, 1L, 0L)),
    national = transform(seeds, forecast_domain = replace(forecast_domain, 1L, "national_team")),
    outer_stage = transform(seeds, selection_stage = replace(selection_stage, 1L, "outer_assessment")),
    hash_drift = transform(seeds, row_sha256 = replace(row_sha256, 1L, paste(rep("b", 64L), collapse = "")))
  )
  for (name in setdiff(names(seed_attacks), "hash_drift")) {
    seed_attacks[[name]] <- phase19_protocol_rehash_seeds(seed_attacks[[name]])
  }
  for (name in names(seed_attacks)) {
    expect_error(
      phase19_validate_seed_registry(seed_attacks[[name]]),
      class = "phase19_protocol_registry_error",
      info = name
    )
  }
})

test_that("complete ordered club gate policy is frozen before assessment", {
  phase19_protocol_test_load()
  phase19_protocol_test_require(c(
    "phase19_load_fixture_club_evaluation_protocol",
    "phase19_load_club_evaluation_protocol",
    "phase19_validate_gate_registry", "phase19_gate_registry_sha256",
    "phase19_protocol_sha256", "phase19_policy_review_sha256"
  ))
  files <- file.path(
    phase19_protocol_test_root, "data/club/model_protocol",
    c("candidate_registry.csv", "gate_registry.csv", "seed_registry.csv",
      "feature_contract.csv", "policy_review.json")
  )
  before <- lapply(files, readBin, what = "raw", n = file.info(files)$size)
  protocol <- phase19_load_fixture_club_evaluation_protocol()
  after <- lapply(files, readBin, what = "raw", n = file.info(files)$size)

  expect_s3_class(protocol, "phase19_club_evaluation_protocol")
  expect_identical(protocol$status, "ready")
  expect_identical(protocol$authority_mode, "fixture")
  expect_true(protocol$fixture_authority)
  expect_false(protocol$production_eligible)
  expect_identical(protocol$forecast_domain, "club")
  expect_identical(protocol$policy_review$decision, "pending")
  expect_identical(protocol$policy_review$reviewer, "")
  expect_identical(protocol$policy_review$reviewed_at_utc, "")
  expect_identical(before, after)

  gates <- protocol$gate_registry
  expected_ids <- c(
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
  expect_identical(as.character(gates$gate_id), expected_ids)
  expect_identical(gates$gate_order, seq_along(expected_ids))
  expect_identical(gates$comparator_model_id[[1L]], "club_venue_nb")
  expect_identical(gates$operator[1:8], c("<=", "<", ">=", ">=", "<=", "<=", "<=", "<="))
  expect_equal(gates$threshold[1:8], c(-0.003, 0, 2 / 3, 2 / 3, 0.015, 0.01, 0.01, 0.01), tolerance = 1e-15)
  expect_true(all(gates$threshold[9:24] == 1))
  expect_identical(anyDuplicated(gates$failure_reason_code), 0L)
  expect_true(all(grepl("^[0-9a-f]{64}$", c(
    protocol$candidate_registry_sha256, protocol$gate_registry_sha256,
    protocol$seed_registry_sha256, protocol$feature_contract_sha256,
    protocol$protocol_sha256, protocol$policy_review$review_sha256
  ))))
  expect_silent(phase19_validate_gate_registry(gates))
  expect_identical(protocol$gate_registry_sha256, phase19_gate_registry_sha256(gates))

  production <- phase19_load_club_evaluation_protocol()
  expect_identical(production$status, "blocked")
  expect_identical(production$reason_code, "protocol_policy_not_approved")
  expect_identical(production$authority_mode, "production")
  expect_false(production$fixture_authority)
  expect_false(production$production_eligible)
})

test_that("policy owner review must accept and bind every exact parent hash", {
  phase19_protocol_test_load()
  protocol <- phase19_load_fixture_club_evaluation_protocol()
  accepted <- phase19_protocol_test_review(protocol)
  # Copy the committed fixture graph, relabel it as production, clear the
  # embedded review, and retain its valid self-hashes.  This is the exact
  # caller-object probe: a coherent relabel must still fail fixed-root
  # resolution.
  forged <- protocol
  forged$authority_mode <- "production"
  forged$fixture_authority <- FALSE
  forged$production_eligible <- TRUE
  forged$policy_review <- NULL
  authority <- phase19_evaluate_policy_review(forged, accepted, "production")
  expect_identical(authority$status, "blocked")
  expect_identical(authority$reason_code, "protocol_policy_not_approved")
  expect_identical(authority$upstream_reason, "caller_policy_review_not_fixed_runtime_root")
  expect_false(authority$production_eligible)
  expect_false(authority$fixture_authority)

  rejected <- phase19_protocol_test_review(protocol, "rejected")
  pending <- phase19_protocol_test_review(protocol, "pending", "", "")
  stale <- accepted
  stale$gate_registry_sha256 <- paste(rep("a", 64L), collapse = "")
  stale$review_sha256 <- phase19_policy_review_sha256(stale)
  malformed_accepted <- phase19_protocol_test_review(protocol, "accepted", "", "")
  attacks <- list(missing = NULL, pending = pending, rejected = rejected,
                  stale = stale, malformed_accepted = malformed_accepted)
  for (name in names(attacks)) {
    result <- phase19_evaluate_policy_review(protocol, attacks[[name]], "production")
    expect_identical(result$status, "blocked", info = name)
    expect_identical(result$reason_code, "protocol_policy_not_approved", info = name)
    expect_false(result$production_eligible, info = name)
  }
  drifted_self_hash <- accepted
  drifted_self_hash$rationale_code <- "edited_after_review"
  result <- phase19_evaluate_policy_review(protocol, drifted_self_hash, "production")
  expect_identical(result$reason_code, "protocol_policy_not_approved")
})

test_that("gate threshold order omission national and inventory attacks fail closed", {
  phase19_protocol_test_load()
  protocol <- phase19_load_fixture_club_evaluation_protocol()
  gates <- protocol$gate_registry
  attacks <- list(
    omitted = gates[-1L, , drop = FALSE],
    duplicate = rbind(gates, gates[1L, , drop = FALSE]),
    threshold = transform(gates, threshold = replace(threshold, 1L, -0.002)),
    operator = transform(gates, operator = replace(operator, 2L, "<=")),
    semantic_order = transform(gates, gate_order = replace(gate_order, c(1L, 2L), c(2L, 1L))),
    national = transform(gates, applicability = replace(applicability, 1L, "world_cup_updating")),
    derived = transform(gates, aggregation = replace(aggregation, 1L, "infer_from_observed_scores")),
    hash_drift = transform(gates, row_sha256 = replace(row_sha256, 1L, paste(rep("c", 64L), collapse = "")))
  )
  for (name in setdiff(names(attacks), c("omitted", "duplicate", "hash_drift"))) {
    attacks[[name]] <- phase19_protocol_rehash_gates(attacks[[name]])
  }
  for (name in names(attacks)) {
    expect_error(
      phase19_validate_gate_registry(attacks[[name]]),
      class = "phase19_protocol_registry_error", info = name
    )
  }
  expect_silent(phase19_validate_protocol_inventory(c(
    "candidate_registry.csv", "gate_registry.csv", "seed_registry.csv",
    "feature_contract.csv", "policy_review.json"
  )))
  expect_error(
    phase19_validate_protocol_inventory(c(
      "candidate_registry.csv", "gate_registry.csv", "seed_registry.csv",
      "feature_contract.csv", "policy_review.json", "observed_thresholds.csv"
    )),
    class = "phase19_protocol_registry_error"
  )
  expect_error(
    phase19_load_club_evaluation_protocol(protocol_dir = tempdir()),
    class = "phase19_arbitrary_authority_error"
  )
})
