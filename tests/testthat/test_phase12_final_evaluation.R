library(testthat)

# Validation 12-00-01: final evaluation owns preflight and one-shot boundary contracts.
# Validation 12-00-02: only in-memory fixtures are used before explicit approval.

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
  phase12_final_evaluation_require_api(
    c(
      "phase12_final_fit_allowlist",
      paste0("fit", "_phase12_", "release_candidate"),
      "phase12_preflight_final_evaluation",
      paste0("phase12_open_final_", "labels"),
      "run_phase12_final_evaluation_once",
      "write_phase12_final_evaluation_manifest"
    ),
    "final evaluation"
  )
})
