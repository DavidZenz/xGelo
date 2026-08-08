library(testthat)

project_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))
source(file.path(project_root, "tests/testthat/helper_statistical_challengers.R"))
challenger_module <- file.path(project_root, "R/benchmark/challengers.R")
if (file.exists(challenger_module)) source(challenger_module)

statistical_candidate_ids <- function() {
  c(
    "poisson_team_ridge", "poisson_team_ridge_elo",
    "dynamic_goal_ability", "dynamic_goal_ability_elo",
    "poisson_team_ridge_elo_dc", "poisson_team_ridge_elo_bivpois",
    "open_nb_elo_only_ablation"
  )
}

require_challenger_adapter_api <- function() {
  required <- c(
    "fit_registered_challenger", "predict_registered_challenger",
    "run_registered_challenger_adapter"
  )
  missing <- required[!vapply(required, exists, logical(1), mode = "function")]
  if (length(missing)) {
    stop(paste("Wave 0 RED contract awaits:", paste(missing, collapse = ", ")), call. = FALSE)
  }
}

test_that("dispatch is an exact seven-candidate allowlist", {
  require_challenger_adapter_api()
  expect_true("candidate_id" %in% names(formals(fit_registered_challenger)))
  code <- paste(deparse(body(fit_registered_challenger)), collapse = "\n")
  expect_true(all(vapply(statistical_candidate_ids(), grepl, logical(1), x = code, fixed = TRUE)))
  expect_false(grepl("eval\\s*\\(|parse\\s*\\(|do.call\\s*\\(", code))

  called <- 0L
  callback <- function(...) {
    called <<- called + 1L
    stop("callback must not run")
  }
  expect_error(
    fit_registered_challenger(
      candidate_id = "system('touch injected')", history = data.frame(),
      settings = list(), fit_callback = callback
    ),
    "unknown|allowlist|registered|unused argument"
  )
  expect_identical(called, 0L)
})

test_that("every candidate uses the common adapter return contract", {
  require_challenger_adapter_api()
  expected <- c("predictions", "distributions", "manifests", "feature_coverage")
  code <- paste(deparse(body(run_registered_challenger_adapter)), collapse = "\n")

  expect_true(all(vapply(statistical_candidate_ids(), grepl, logical(1), x = code, fixed = TRUE)))
  expect_true(all(vapply(expected, grepl, logical(1), x = code, fixed = TRUE)))
  expect_true(grepl("derive_benchmark_markets", code, fixed = TRUE))
  expect_true(grepl("validate_benchmark_predictions", code, fixed = TRUE))
  expect_true(grepl("validate_benchmark_feature_evidence", code, fixed = TRUE))
  expect_false(grepl("score_benchmark_fixtures|make_paired_fold_comparisons", code))
})

test_that("dependence siblings attest one augmented penalized mean", {
  require_challenger_adapter_api()
  rows <- data.frame(
    candidate_id = c(
      "poisson_team_ridge_elo", "poisson_team_ridge_elo_dc",
      "poisson_team_ridge_elo_bivpois"
    ),
    mean_parent_id = "poisson_team_ridge_elo",
    mean_prediction_hash = strrep("a", 64),
    stringsAsFactors = FALSE
  )
  result <- predict_registered_challenger(
    candidate_id = rows$candidate_id,
    mean_predictions = rows,
    support_max = 40L,
    validate_only = TRUE
  )
  expect_identical(unique(result$mean_parent_id), "poisson_team_ridge_elo")
  expect_length(unique(result$mean_prediction_hash), 1L)
})

test_that("sibling fit cache keys share only identical mean components", {
  require_challenger_adapter_api()
  settings <- list(team_ridge_lambda = 1, elo_lasso_lambda = 0.1)
  keys <- vapply(
    c(
      "poisson_team_ridge_elo", "poisson_team_ridge_elo_dc",
      "poisson_team_ridge_elo_bivpois"
    ),
    function(candidate_id) {
      challenger_penalized_fit_cache_key(
        candidate_id, as.Date("2022-11-20"), settings
      )
    },
    character(1)
  )
  expect_length(unique(keys), 1L)
  expect_false(identical(
    challenger_penalized_fit_cache_key(
      "poisson_team_ridge", as.Date("2022-11-20"), settings
    ),
    keys[[1L]]
  ))
  expect_null(challenger_penalized_fit_cache_key(
    "dynamic_goal_ability", as.Date("2022-11-20"), settings
  ))
})

test_that("dynamic siblings reuse the boundary replay but retain Elo-specific means", {
  require_challenger_adapter_api()
  if (!exists("baseline_goal_predictors", mode = "function")) {
    source(file.path(project_root, "R/forecast/poisson.R"))
  }
  history <- synthetic_statistical_history(include_outer = TRUE)
  fixture <- history[history$edition_id == "wc2010", , drop = FALSE][1L, , drop = FALSE]
  fixture$track_id <- "updating"
  fixture$boundary_id <- "wc2010__dynamic_cache"
  fixture$forecast_sequence <- 1L
  fixture$evidence_cutoff_exclusive <- as.Date(fixture$actual_completion_date)
  base_settings <- list(pseudo_exposure = 8, half_life_days = 730, elo_coefficient = 0)
  elo_settings <- c(base_settings, elo_coefficient = 0.25)
  cache <- new.env(parent = emptyenv())
  plain <- challenger_dynamic_means(
    challenger_dynamic_fit(history, fixture$evidence_cutoff_exclusive, base_settings, FALSE),
    fixture, mean_cache = cache
  )
  elo <- challenger_dynamic_means(
    challenger_dynamic_fit(history, fixture$evidence_cutoff_exclusive, elo_settings, TRUE),
    fixture, mean_cache = cache
  )
  expect_length(ls(cache), 1L)
  expect_equal(plain$dynamic_log_mu_home, elo$dynamic_log_mu_home)
  expect_equal(plain$dynamic_log_mu_away, elo$dynamic_log_mu_away)
})
