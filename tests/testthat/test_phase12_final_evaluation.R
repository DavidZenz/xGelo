library(testthat)

# Validation 12-00-01: final evaluation owns preflight and one-shot boundary contracts.
# Validation 12-00-02: only in-memory fixtures are used before explicit approval.

project_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))
source(file.path(project_root, "R/release/final_fit.R"))
source(file.path(project_root, "R/release/final_evaluation.R"))

phase12_final_evaluation_synthetic_state <- function() {
  list(
    approval_state = "pending",
    holdout_state = "unopened",
    score_support = 40L,
    candidate_ids = phase12_final_evaluation_synthetic_candidates(),
    copied_label_rows = 0L
  )
}

phase12_final_evaluation_synthetic_candidates <- function() {
  c(
    "phase11_rf_dynamic_elo_open", "phase11_rf_dynamic_elo_rich",
    "phase11_nb_dynamic_elo_open", "phase11_nb_dynamic_elo_rich",
    "phase11_penalized_poisson", "phase11_dynamic_goal_ability",
    "phase11_score_dependence", "phase11_context_prior", "phase11_structural_prior"
  )
}

phase12_final_evaluation_require_api <- function(required, owner) {
  missing <- required[!vapply(required, exists, logical(1), mode = "function")]
  if (length(missing)) {
    stop(
      paste0("Wave 0 RED contract awaits Phase 12 ", owner, " API: ",
             paste(missing, collapse = ", ")),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

test_that("12-00-01 final evaluation fixture starts sealed and unopened", {
  state <- phase12_final_evaluation_synthetic_state()
  expect_identical(state$approval_state, "pending")
  expect_identical(state$holdout_state, "unopened")
  expect_equal(state$score_support, 40L)
  expect_equal(length(state$candidate_ids), 9L)
  expect_equal(state$copied_label_rows, 0L)
})

test_that("12-00-01 final evaluation gate names downstream seams without invoking them", {
  expect_invisible(phase12_final_evaluation_require_api(
    c(
      "phase12_final_fit_allowlist",
      paste0("fit", "_phase12_", "release_candidate"),
      "phase12_preflight_final_evaluation",
      paste0("phase12_open_final_", "labels")
    ),
    "final evaluation"
  ))
})

test_that("12-04-01 final-fit allowlist is exact and retains inactive rows", {
  phase12_reset_final_evaluation_state()
  allowlist <- phase12_final_fit_allowlist()
  expect_equal(nrow(allowlist), 9L)
  expect_identical(as.character(allowlist$track_id), rep("updating", 9L))
  expect_identical(as.character(allowlist$candidate_id[allowlist$admissible]), "phase11_rf_dynamic_elo_open")
  expect_equal(sum(allowlist$admissible), 1L)
  expect_equal(sum(allowlist$score_status == "no_score"), 8L)
  expect_true(all(nzchar(allowlist$no_score_reason[!allowlist$admissible])))
  expect_true(all(allowlist$score_support_g == 40L))
})

test_that("12-04-01 durable final-fit manifest reconciles in a fresh process", {
  expect_true(isTRUE(validate_phase12_final_fit_manifest()))
  manifest <- utils::read.csv(
    file.path(project_root, "outputs/benchmarks/rolling_tournaments/phase12-calibration-release/final_evaluation/final_fit/final_fit_manifest.csv"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  expect_equal(nrow(manifest), 9L)
  expect_identical(as.character(manifest$candidate_id[manifest$admissible]), "phase11_rf_dynamic_elo_open")
  expect_true(all(manifest$score_support_g == 40L))
  expect_true(all(!manifest$labels_consumed))
  expect_true(all(manifest$holdout_state == "unopened"))
  expect_match(as.character(manifest$model_sha256[manifest$admissible]), "^[0-9a-f]{64}$")
  expect_match(as.character(manifest$calibrator_sha256[manifest$admissible]), "^[0-9a-f]{64}$")
})

test_that("12-04-01 preflight passes label-free and does not call a provider", {
  phase12_reset_final_evaluation_state()
  calls <- 0L
  old_provider <- getOption("xgelo.phase12_final_label_provider")
  options(xgelo.phase12_final_label_provider = function(path) {
    calls <<- calls + 1L
    stop("provider must not be invoked by preflight", call. = FALSE)
  })
  on.exit(options(xgelo.phase12_final_label_provider = old_provider), add = TRUE)
  preflight <- phase12_preflight_final_evaluation(
    final_state = phase12_final_evaluation_synthetic_state(),
    protocol = file.path(project_root, "data/benchmark/phase09/promotion_protocol.json")
  )
  expect_identical(preflight$preflight_status, "passed")
  expect_identical(preflight$approval_state, "pending")
  expect_identical(preflight$holdout_state, "unopened")
  expect_false(preflight$can_open)
  expect_identical(calls, 0L)
  expect_identical(phase12_final_evaluation_provider_calls(), 0L)
})

test_that("12-04-01 failed preflight blocks the synthetic provider before any callback", {
  phase12_reset_final_evaluation_state()
  calls <- 0L
  old_provider <- getOption("xgelo.phase12_final_label_provider")
  options(xgelo.phase12_final_label_provider = function(path) {
    calls <<- calls + 1L
    data.frame(edition_id = "wc2026", stringsAsFactors = FALSE)
  })
  on.exit(options(xgelo.phase12_final_label_provider = old_provider), add = TRUE)
  expect_error(
    phase12_preflight_final_evaluation(final_state = list(approval_state = "pending", holdout_state = "opened")),
    "holdout_consumed"
  )
  expect_error(
    phase12_open_final_labels(
      phase12_final_evaluation_allowlisted_label_path(), strrep("a", 64), "approved"
    ),
    "preflight"
  )
  expect_identical(calls, 0L)
  expect_identical(phase12_final_evaluation_provider_calls(), 0L)
})

test_that("12-04-02 final-fit and preflight drift contracts fail closed", {
  manifest <- utils::read.csv(
    file.path(project_root, "outputs/benchmarks/rolling_tournaments/phase12-calibration-release/final_evaluation/final_fit/final_fit_manifest.csv"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  tampered_hash <- manifest
  tampered_hash$model_sha256[tampered_hash$admissible] <- strrep("b", 64)
  expect_error(validate_phase12_final_fit_manifest(tampered_hash), "self_hash|artifact_drift|hash_drift")
  tampered_state <- manifest
  tampered_state$labels_consumed[1L] <- TRUE
  expect_error(validate_phase12_final_fit_manifest(tampered_state), "unopened_state|self_hash")
  bad_gate <- utils::read.csv(
    file.path(project_root, "outputs/benchmarks/rolling_tournaments/phase12-calibration-release/calibration/calibration_gate.csv"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  bad_gate$score_support_g[1L] <- 39L
  expect_error(
    phase12_preflight_final_evaluation(calibration_gate = bad_gate),
    "score_support|calibration_gate"
  )
  expect_error(
    phase12_preflight_final_evaluation(final_state = list(approval_state = "pending", holdout_state = "unopened", label_path = "other.csv")),
    "path"
  )
})

test_that("12-04-02 final-fit manifest rejects contract, protocol, code, label, candidate, and G drift", {
  manifest <- utils::read.csv(
    file.path(project_root, "outputs/benchmarks/rolling_tournaments/phase12-calibration-release/final_evaluation/final_fit/final_fit_manifest.csv"),
    stringsAsFactors = FALSE, check.names = FALSE
  )

  tampered_contract <- manifest
  tampered_contract$contract_flags[tampered_contract$admissible] <- "freeze_valid"
  expect_error(validate_phase12_final_fit_manifest(tampered_contract), "contract_drift|artifact_drift")

  tampered_protocol <- manifest
  tampered_protocol$promotion_protocol_sha256[1L] <- strrep("c", 64)
  expect_error(validate_phase12_final_fit_manifest(tampered_protocol), "artifact_drift|protocol|self_hash")

  tampered_code <- manifest
  tampered_code$dirty_code[1L] <- "dirty-working-tree"
  expect_error(validate_phase12_final_fit_manifest(tampered_code), "code_drift|artifact_drift|self_hash")

  tampered_label <- manifest
  tampered_label$label_source_path[1L] <- "data/benchmark/phase12/other_labels.csv"
  expect_error(validate_phase12_final_fit_manifest(tampered_label), "unopened_state|artifact_drift|self_hash")

  tampered_candidate <- manifest
  tampered_candidate$candidate_id[1L] <- "not_allowlisted"
  expect_error(validate_phase12_final_fit_manifest(tampered_candidate), "candidate_drift|artifact_drift|self_hash")

  tampered_g <- manifest
  tampered_g$score_support_g[1L] <- 39L
  expect_error(validate_phase12_final_fit_manifest(tampered_g), "support_drift|artifact_drift|self_hash")
})

test_that("12-04-02 opener contract remains exact and allowlisted", {
  expect_identical(
    phase12_final_evaluation_allowlisted_label_path(),
    "data/benchmark/phase12/wc2026_labels.csv"
  )
  expect_error(
    phase12_open_final_labels("other.csv", strrep("a", 64), "approved"),
    "allowlisted"
  )
})
