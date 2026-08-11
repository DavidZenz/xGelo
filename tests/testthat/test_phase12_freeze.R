library(testthat)

# Validation 12-00-01: the freeze surface retains all nine registered identities.
# Validation 12-00-02: synthetic registry rows never discover or mutate holdout data.

phase12_freeze_synthetic_registry <- function() {
  ids <- c(
    "phase11_rf_dynamic_elo_open", "phase11_rf_dynamic_elo_rich",
    "phase11_nb_dynamic_elo_open", "phase11_nb_dynamic_elo_rich",
    "phase11_penalized_poisson", "phase11_dynamic_goal_ability",
    "phase11_score_dependence", "phase11_context_prior", "phase11_structural_prior"
  )
  data.frame(
    candidate_id = ids,
    active_status = c(TRUE, rep(FALSE, 8L)),
    score_status = c("scored", rep("no_score", 8L)),
    research_only = c(FALSE, rep(TRUE, 8L)),
    sealed = TRUE,
    registry_order = seq_along(ids),
    stringsAsFactors = FALSE
  )
}

phase12_freeze_require_api <- function(required, owner) {
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

test_that("12-00-01 freeze fixture retains nine active and inactive rows", {
  registry <- phase12_freeze_synthetic_registry()
  expect_equal(nrow(registry), 9L)
  expect_equal(sum(registry$active_status), 1L)
  expect_equal(sum(registry$score_status == "no_score"), 8L)
  expect_true(all(registry$sealed))
  expect_identical(registry$registry_order, seq_len(9L))
})

test_that("12-00-01 freeze owner gate names manifest and seal APIs", {
  phase12_freeze_require_api(
    c(
      "build_phase12_freeze_manifest",
      "validate_phase12_freeze_manifest",
      "phase12_freeze_parent_graph",
      "phase12_freeze_self_hash",
      "phase12_assert_unopened_holdout",
      "phase12_freeze_candidate_rows"
    ),
    "freeze"
  )
})
