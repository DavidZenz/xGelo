library(testthat)

phase19_fold_test_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/", mustWork = TRUE
)

phase19_fold_test_load <- function() {
  source(file.path(
    phase19_fold_test_root, "tests/testthat/helper_phase19_club_fixture.R"
  ), local = .GlobalEnv)
  phase19_test_load()
  source(file.path(
    phase19_fold_test_root, "R/club/evaluation_protocol.R"
  ), local = .GlobalEnv)
  invisible(TRUE)
}

# Production control-flow tests replace only runtime loaders/writers. They must
# never refresh the real accepted-history/fold pointer during ordinary tests.
phase19_fold_test_with_bindings <- function(bindings, code) {
  previous <- mget(names(bindings), envir = .GlobalEnv, inherits = FALSE)
  on.exit(list2env(previous, envir = .GlobalEnv), add = TRUE)
  list2env(bindings, envir = .GlobalEnv)
  force(code)
}

phase19_fold_test_fixture <- function(label = "folds") {
  root <- phase19_test_fixture_root(label)
  snapshot <- phase19_load_fixture_club_training_snapshot(root)
  protocol <- phase19_load_fixture_club_evaluation_protocol()
  folds <- phase19_build_fixture_club_fold_registry(snapshot, protocol)
  list(root = root, snapshot = snapshot, protocol = protocol, folds = folds)
}

test_that("fixture history freezes deterministic rolling and transport folds", {
  phase19_fold_test_load()
  phase19_test_require(c(
    "phase19_build_fixture_club_fold_registry", "phase19_validate_fold_registry",
    "phase19_fold_registry_sha256", "phase19_fold_registry_schema"
  ))
  fixture <- phase19_fold_test_fixture("fold-families")
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  folds <- fixture$folds

  expect_identical(names(folds), phase19_fold_registry_schema())
  expect_setequal(
    unique(folds$fold_family),
    c("rolling_origin_league_season", "heldout_league_transport")
  )
  expect_true(all(folds$authority_mode == "fixture"))
  expect_true(all(folds$fixture_authority))
  expect_true(all(folds$forecast_domain == "club"))
  expect_true(all(folds$eligibility_status == "eligible"))
  expect_true(all(folds$declared_fixture_count > 0L))
  expect_true(all(folds$training_fixture_count > 0L))
  expect_true(all(folds$calibration_fixture_count > 0L))
  expect_identical(anyDuplicated(folds$fold_id), 0L)
  expect_silent(phase19_validate_fold_registry(
    folds, fixture$snapshot, fixture$protocol, authority_mode = "fixture"
  ))

  reversed <- folds[rev(seq_len(nrow(folds))), , drop = FALSE]
  expect_identical(
    phase19_fold_registry_sha256(reversed, fixture$snapshot, fixture$protocol),
    phase19_fold_registry_sha256(folds, fixture$snapshot, fixture$protocol)
  )
  phase19_fold_test_with_bindings(list(
    .phase19_fold_raw_registry_uncached = function(...) stop("Identical reviewed inputs must reuse the derived inventory")
  ), {
    expect_identical(phase19_fold_raw_registry(fixture$snapshot, fixture$protocol, "fixture"), folds)
    expect_identical(phase19_fold_raw_registry(fixture$snapshot, fixture$protocol, "fixture"), folds)
    changed <- fixture$snapshot
    changed$matches$regulation_home_goals[[1L]] <- "99"
    expect_error(phase19_fold_raw_registry(changed, fixture$protocol, "fixture"),
      class = "history_match_hash_mismatch")
  })
})

test_that("fold role evidence is strictly prior nested and transport-excluded", {
  phase19_fold_test_load()
  fixture <- phase19_fold_test_fixture("fold-roles")
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)

  for (index in seq_len(nrow(fixture$folds))) {
    fold <- fixture$folds[index, , drop = FALSE]
    fit <- phase19_fold_role_evidence(fixture$snapshot, fold, "fit")
    tune <- phase19_fold_role_evidence(fixture$snapshot, fold, "tuning")
    calibration <- phase19_fold_role_evidence(
      fixture$snapshot, fold, "calibration"
    )
    expect_true(nrow(fit) > 0L, info = fold$fold_id)
    expect_identical(fit, tune, info = fold$fold_id)
    expect_true(nrow(calibration) > 0L, info = fold$fold_id)
    expect_true(all(fit$completion_not_before_utc < fold$training_cutoff_exclusive))
    expect_true(all(fit$evidence_available_at_utc < fold$training_cutoff_exclusive))
    expect_true(all(
      calibration$completion_not_before_utc < fold$calibration_cutoff_exclusive
    ))
    expect_true(all(
      calibration$evidence_available_at_utc < fold$calibration_cutoff_exclusive
    ))
    expect_false(any(calibration$match_id %in% fit$match_id))
    if (identical(fold$fold_family, "heldout_league_transport")) {
      expect_false(any(fit$competition_id == fold$held_out_competition_id))
      expect_false(any(calibration$competition_id == fold$held_out_competition_id))
      expect_identical(fold$fit_excluded_competition_id, fold$held_out_competition_id)
      expect_identical(fold$tuning_excluded_competition_id, fold$held_out_competition_id)
      expect_identical(
        fold$calibration_excluded_competition_id, fold$held_out_competition_id
      )
    }
  }
})

test_that("exact cutoff same batch heldout labels and overlap fail closed", {
  phase19_fold_test_load()
  fixture <- phase19_fold_test_fixture("fold-attacks")
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  fold <- fixture$folds[
    fixture$folds$fold_family == "heldout_league_transport", , drop = FALSE
  ][1L, , drop = FALSE]
  rows <- fixture$snapshot$matches

  heldout <- rows[rows$competition_id == fold$held_out_competition_id, , drop = FALSE][1L, ]
  expect_error(
    phase19_validate_fold_role_evidence(heldout, fold, "fit"),
    class = "phase19_fold_contract_error"
  )
  exact <- rows[rows$match_id %in% strsplit(fold$training_fixture_ids, "\\|")[[1L]],
                , drop = FALSE][1L, ]
  exact$completion_not_before_utc <- fold$training_cutoff_exclusive
  expect_error(
    phase19_validate_fold_role_evidence(exact, fold, "fit"),
    class = "phase19_fold_contract_error"
  )
  overlap <- fixture$folds
  overlap$calibration_fixture_ids[[1L]] <- overlap$training_fixture_ids[[1L]]
  overlap$calibration_fixture_count[[1L]] <- overlap$training_fixture_count[[1L]]
  overlap$calibration_fixture_sha256[[1L]] <- overlap$training_fixture_sha256[[1L]]
  overlap$row_sha256 <- phase19_fold_row_sha256(overlap)
  expect_error(
    phase19_validate_fold_registry(
      overlap, fixture$snapshot, fixture$protocol, authority_mode = "fixture"
    ),
    class = "phase19_fold_contract_error"
  )
})

test_that("instant and date precision create conservative shared boundaries", {
  phase19_fold_test_load()
  instant <- data.frame(
    match_id = c("a", "b"), event_date = c("2025-01-01", "2025-01-01"),
    kickoff_utc = c("2025-01-01T18:00:00Z", "2025-01-01T18:00:00Z"),
    kickoff_precision = c("instant", "instant"), stringsAsFactors = FALSE
  )
  expect_identical(
    phase19_fold_boundary_utc(instant),
    rep("2025-01-01T18:00:00Z", 2L)
  )
  dated <- instant
  dated$kickoff_utc <- ""
  dated$kickoff_precision <- "date"
  expect_identical(
    phase19_fold_boundary_utc(dated),
    rep("2025-01-01T00:00:00Z", 2L)
  )
  mixed <- instant
  mixed$kickoff_precision[[2L]] <- "minute"
  expect_error(
    phase19_fold_boundary_utc(mixed), class = "phase19_fold_contract_error"
  )
})

test_that("declared fixture coverage cannot drop duplicate or add rows", {
  phase19_fold_test_load()
  fixture <- phase19_fold_test_fixture("fold-coverage")
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  fold <- fixture$folds[1L, , drop = FALSE]
  declared <- strsplit(fold$declared_fixture_ids, "\\|")[[1L]]

  expect_silent(phase19_validate_fold_prediction_coverage(fold, declared))
  expect_error(
    phase19_validate_fold_prediction_coverage(fold, declared[-1L]),
    class = "phase19_fold_contract_error"
  )
  expect_error(
    phase19_validate_fold_prediction_coverage(fold, c(declared, declared[[1L]])),
    class = "phase19_fold_contract_error"
  )
  expect_error(
    phase19_validate_fold_prediction_coverage(fold, c(declared, "surplus")),
    class = "phase19_fold_contract_error"
  )
})

test_that("committed bootstrap fold artifacts remain truthful independent of runtime acceptance", {
  phase19_fold_test_load()
  root <- file.path(phase19_fold_test_root, "data/club/model_protocol")
  paths <- file.path(root, c("fold_registry.csv", "protocol_state.json",
    "calibration_recipe.json", "fold_review.json"))
  expect_true(all(file.exists(paths)))
  before <- lapply(paths, readBin, what = "raw", n = file.info(paths)$size)
  registry <- phase19_read_fold_registry(paths[[1L]], allow_empty = TRUE)
  state <- phase19_read_json_exact(paths[[2L]], phase19_protocol_state_schema(), "protocol_state_invalid")
  recipe <- phase19_read_json_exact(paths[[3L]], phase19_calibration_recipe_schema(), "calibration_recipe_invalid")
  review <- phase19_read_json_exact(paths[[4L]], phase19_fold_review_schema(), "fold_review_invalid")
  expect_silent(phase19_validate_protocol_state(state))
  expect_silent(phase19_validate_calibration_recipe(recipe))
  expect_identical(review$review_sha256, phase19_fold_review_sha256(review))
  expect_identical(state$state, "blocked")
  expect_identical(state$reason_code, "no_accepted_club_history")
  expect_identical(state$authority_mode, "production")
  expect_false(state$fixture_authority)
  expect_identical(nrow(registry), 0L)
  expect_identical(state$accepted_generation_id, "")
  expect_identical(state$fold_registry_sha256, "")
  expect_identical(review$decision, "pending")
  expect_identical(review$reviewer, "")
  expect_identical(review$reviewed_at_utc, "")
  expect_identical(before, lapply(paths, readBin, what = "raw", n = file.info(paths)$size))
})

test_that("fixture materialization stops pending review then accepts exact owner review", {
  phase19_fold_test_load()
  phase19_test_require(c(
    "phase19_publish_fixture_fold_candidate", "phase19_load_fixture_fold_protocol",
    "phase19_build_fold_review", "phase19_apply_fixture_fold_review",
    "phase19_assert_production_fold_protocol"
  ))
  fixture <- phase19_fold_test_fixture("fold-publication")
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  candidate <- phase19_publish_fixture_fold_candidate(
    fixture$root, fixture$snapshot, fixture$protocol,
    code_commit = paste(rep("a", 40L), collapse = "")
  )
  pending <- phase19_load_fixture_fold_protocol(fixture$root)

  expect_identical(candidate$status, "pending_review")
  expect_identical(pending$status, "blocked")
  expect_identical(pending$reason_code, "fold_inventory_not_approved")
  expect_identical(pending$protocol_state$state, "pending_review")
  expect_false(pending$production_eligible)
  expect_error(
    phase19_assert_production_fold_protocol(pending),
    class = "phase19_fold_contract_error"
  )

  review <- phase19_build_fold_review(
    candidate, decision = "accepted", reviewer = "phase19-fixture-owner",
    reviewed_at_utc = "2026-09-20T18:30:00Z",
    rationale_code = "fixture_mechanics_reviewed"
  )
  expect_silent(phase19_apply_fixture_fold_review(fixture$root, review))
  ready <- phase19_load_fixture_fold_protocol(fixture$root)
  expect_identical(ready$status, "ready")
  expect_identical(ready$reason_code, "")
  expect_identical(ready$protocol_state$state, "ready")
  expect_true(ready$fixture_authority)
  expect_false(ready$production_eligible)
  expect_identical(
    ready$fold_registry_sha256,
    phase19_fold_registry_sha256(
      ready$fold_registry, fixture$snapshot, fixture$protocol, "fixture"
    )
  )
})

test_that("review parent drift partial publication and fixture escalation fail", {
  phase19_fold_test_load()
  fixture <- phase19_fold_test_fixture("fold-review-attacks")
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  candidate <- phase19_publish_fixture_fold_candidate(
    fixture$root, fixture$snapshot, fixture$protocol,
    code_commit = paste(rep("b", 40L), collapse = "")
  )
  review <- phase19_build_fold_review(
    candidate, decision = "accepted", reviewer = "phase19-fixture-owner",
    reviewed_at_utc = "2026-09-20T18:31:00Z",
    rationale_code = "fixture_mechanics_reviewed"
  )
  pointer_path <- file.path(fixture$root, "model_protocol", "protocol_current.json")
  before <- readBin(pointer_path, what = "raw", n = file.info(pointer_path)$size)

  drift <- review
  drift$fold_registry_sha256 <- paste(rep("c", 64L), collapse = "")
  drift$review_sha256 <- phase19_fold_review_sha256(drift)
  expect_error(
    phase19_apply_fixture_fold_review(fixture$root, drift),
    class = "phase19_fold_contract_error"
  )
  expect_identical(
    readBin(pointer_path, what = "raw", n = file.info(pointer_path)$size), before
  )

  invented_pending <- review
  invented_pending$decision <- "pending"
  invented_pending$rationale_code <- "pending_owner_review"
  invented_pending$review_sha256 <- phase19_fold_review_sha256(invented_pending)
  expect_error(
    phase19_validate_fold_review(invented_pending, candidate),
    class = "phase19_fold_contract_error"
  )
  expect_error(
    phase19_assert_production_fold_protocol(candidate),
    class = "phase19_fold_contract_error"
  )
  production_writes <- 0L
  phase19_fold_test_with_bindings(list(
    phase19_load_club_fold_protocol = function(...) candidate,
    phase19_protocol_write_generation = function(...) {
      production_writes <<- production_writes + 1L
      stop("Production writer must not run in fixture escalation test")
    }
  ), {
    expect_error(phase19_apply_club_fold_review(review), class = "phase19_fold_contract_error")
    expect_identical(production_writes, 0L)
  })
})

test_that("production refresh stops before writers when history is unavailable", {
  phase19_fold_test_load()
  writes <- policy_reads <- candidate_builds <- 0L
  blocked <- structure(list(status = "blocked", reason_code = "no_accepted_club_history",
    authority_mode = "production", fixture_authority = FALSE, production_eligible = FALSE),
    class = c("phase19_club_fold_protocol", "list"))
  phase19_fold_test_with_bindings(list(
    phase19_load_club_training_snapshot = function(...) list(status = "blocked"),
    phase19_load_blocked_fold_protocol = function(...) blocked,
    phase19_load_club_evaluation_protocol = function(...) {
      policy_reads <<- policy_reads + 1L
      stop("Policy must not load before accepted history")
    },
    phase19_protocol_candidate = function(...) {
      candidate_builds <<- candidate_builds + 1L
      stop("Candidate must not be built before accepted history")
    },
    phase19_protocol_write_generation = function(...) {
      writes <<- writes + 1L
      stop("Production writer must not run without accepted history")
    }
  ), {
    refreshed <- phase19_refresh_club_fold_protocol()
    expect_identical(refreshed, blocked)
    expect_identical(policy_reads, 0L)
    expect_identical(candidate_builds, 0L)
    expect_identical(writes, 0L)
  })
})

test_that("production refresh stops before writers when policy is unapproved", {
  phase19_fold_test_load()
  writes <- candidate_builds <- 0L
  phase19_fold_test_with_bindings(list(
    phase19_load_club_training_snapshot = function(...) list(status = "ready"),
    phase19_load_club_evaluation_protocol = function(...) list(status = "blocked"),
    phase19_protocol_candidate = function(...) {
      candidate_builds <<- candidate_builds + 1L
      stop("Candidate must not be built before owner policy approval")
    },
    phase19_protocol_write_generation = function(...) {
      writes <<- writes + 1L
      stop("Production writer must not run before owner policy approval")
    }
  ), {
    refreshed <- phase19_refresh_club_fold_protocol()
    expect_identical(refreshed$status, "blocked")
    expect_identical(refreshed$reason_code, "protocol_policy_not_approved")
    expect_false(refreshed$production_eligible)
    expect_identical(candidate_builds, 0L)
    expect_identical(writes, 0L)
  })
})
