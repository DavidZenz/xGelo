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
