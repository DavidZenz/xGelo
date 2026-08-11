library(testthat)

# Validation 12-00-01: promotion owns evaluator delegation and fallback contracts.
# Validation 12-00-02: promotion fixtures contain synthetic score evidence only.

phase12_promotion_synthetic_candidates <- function() {
  data.frame(
    candidate_id = c(
      "phase11_rf_dynamic_elo_open", "phase11_rf_dynamic_elo_rich",
      "phase11_nb_dynamic_elo_open", "phase11_nb_dynamic_elo_rich",
      "phase11_penalized_poisson", "phase11_dynamic_goal_ability",
      "phase11_score_dependence", "phase11_context_prior", "phase11_structural_prior"
    ),
    incumbent_id = "phase11_rf_dynamic_elo_open",
    eligible = c(TRUE, rep(FALSE, 8L)),
    rps_delta = c(0, rep(NA_real_, 8L)),
    decision = "incumbent retained",
    stringsAsFactors = FALSE
  )
}

phase12_promotion_require_api <- function(required, owner) {
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

test_that("12-00-01 promotion fixture retains exact incumbent fallback", {
  candidates <- phase12_promotion_synthetic_candidates()
  expect_equal(nrow(candidates), 9L)
  expect_equal(sum(candidates$eligible), 1L)
  expect_identical(unique(candidates$decision), "incumbent retained")
  expect_true(all(is.na(candidates$rps_delta[-1L])))
})

test_that("12-00-01 promotion gate names evaluator and report seams", {
  phase12_promotion_require_api(
    c(
      "evaluate_phase12_candidates",
      "write_phase12_promotion_report",
      "evaluate_promotion",
      "select_promoted_candidate"
    ),
    "promotion"
  )
})
