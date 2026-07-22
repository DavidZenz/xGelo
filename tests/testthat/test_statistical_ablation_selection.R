library(testthat)

project_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))
source(file.path(project_root, "tests/testthat/helper_statistical_challengers.R"))
source(file.path(project_root, "R/evaluation/proper_scores.R"))
source(file.path(project_root, "R/benchmark/contracts.R"))
source(file.path(project_root, "R/forecast/poisson.R"))
challenger_module <- file.path(project_root, "R/benchmark/challengers.R")
if (file.exists(challenger_module)) source(challenger_module)

require_ablation_selection_api <- function() {
  required <- "challenger_ablation_evidence"
  missing <- required[!vapply(required, exists, logical(1), mode = "function")]
  if (length(missing)) {
    stop(paste("Wave 0 RED contract awaits:", paste(missing, collapse = ", ")), call. = FALSE)
  }
}

ablation_selection_fixture <- function(rps_delta = 0.001, brier = 0, log_loss = 0,
                                       calibration = 0, worst_fold = 0.01) {
  list(
    candidate_id = "open_nb_elo_only_ablation",
    parent_id = "open_nb_incumbent",
    updating_equal_tournament_rps_delta = rps_delta,
    brier_relative_change = brier,
    log_loss_relative_change = log_loss,
    calibration_change = calibration,
    maximum_fold_regression = worst_fold,
    fold_wins = 8L,
    world_cup_wins = 4L,
    euro_wins = 4L,
    active_features = "elo_diff",
    inactive_features = c("xgf_ewma_diff", "xga_ewma_diff", "xgd_ewma_diff", "form_index_diff")
  )
}

test_that("practical non-inferiority includes the +0.001 boundary", {
  require_ablation_selection_api()
  at_boundary <- challenger_ablation_evidence(ablation_selection_fixture(0.001))
  above_boundary <- challenger_ablation_evidence(ablation_selection_fixture(0.0010001))
  expect_true(at_boundary$practically_non_inferior)
  expect_false(above_boundary$practically_non_inferior)
  expect_identical(at_boundary$active_features, "elo_diff")
  expect_setequal(at_boundary$inactive_features, ablation_selection_fixture()$inactive_features)
})

test_that("each supporting regression veto blocks simplification", {
  require_ablation_selection_api()
  cases <- list(
    brier = ablation_selection_fixture(brier = 0.010001),
    log_loss = ablation_selection_fixture(log_loss = 0.010001),
    calibration = ablation_selection_fixture(calibration = 0.010001),
    worst_fold = ablation_selection_fixture(worst_fold = 0.015001)
  )
  decisions <- lapply(cases, challenger_ablation_evidence)
  expect_false(any(vapply(decisions, `[[`, logical(1), "practically_non_inferior")))
  expect_true(all(vapply(decisions, function(x) nzchar(x$reason_codes), logical(1))))
})

test_that("coefficient significance cannot enter ablation selection", {
  require_ablation_selection_api()
  forbidden <- c("p_value", "pvalue", "significance", "coefficient_significant")
  expect_false(any(forbidden %in% names(formals(challenger_ablation_evidence))))
  code <- paste(deparse(body(challenger_ablation_evidence)), collapse = "\n")
  expect_false(any(vapply(forbidden, grepl, logical(1), x = code, ignore.case = TRUE)))
  result <- challenger_ablation_evidence(ablation_selection_fixture())
  expect_false(any(forbidden %in% names(result)))
})

ablation_adapter_fixture <- function(track_id) {
  sparse <- synthetic_sparse_teams()
  set.seed(1006L)
  n <- 180L
  known_teams <- sparse$registered_team_ids[seq_len(6L)]
  home_index <- rep(seq_along(known_teams), length.out = n)
  away_index <- ((home_index + rep(1:5, length.out = n) - 1L) %% 6L) + 1L
  dates <- as.Date("1994-01-01") + seq_len(n) * 20L
  elo_diff <- (home_index - away_index) * 32
  home_mu <- exp(0.35 + elo_diff / 700)
  away_mu <- exp(0.20 - elo_diff / 700)
  history <- data.frame(
    match_id = sprintf("adapter_history_%03d", seq_len(n)),
    fixture_id = sprintf("adapter_history_fixture_%03d", seq_len(n)),
    edition_id = rep(c("wc1994", "euro1996", "wc1998", "euro2000"), length.out = n),
    tournament = rep(c("FIFA World Cup", "UEFA Euro", "Friendly"), length.out = n),
    date = dates, actual_completion_date = dates,
    evidence_cutoff_exclusive = dates + 1L,
    home_team_id = known_teams[home_index], away_team_id = known_teams[away_index],
    home_goals = stats::rnbinom(n, size = 4, mu = home_mu),
    away_goals = stats::rnbinom(n, size = 4, mu = away_mu),
    regulation_home_goals = 0L, regulation_away_goals = 0L,
    venue_role = rep(c("home", "neutral"), length.out = n),
    elo_diff = elo_diff,
    elo_diff__value_present = TRUE, elo_diff__source_present = TRUE,
    elo_diff__source_date = dates - 1L, elo_diff__imputed = FALSE,
    elo_diff__imputation_reason = "", stringsAsFactors = FALSE
  )
  history$regulation_home_goals <- history$home_goals
  history$regulation_away_goals <- history$away_goals
  fixtures <- sparse$fixtures[c(1L, 5L), , drop = FALSE]
  fixtures$fixture_id <- paste(track_id, fixtures$fixture_id, sep = "__")
  fixtures$track_id <- track_id
  fixtures$forecast_sequence <- seq_len(nrow(fixtures))
  fixtures$boundary_id <- paste("wc2010", track_id, sep = "__")
  fixtures$result_cutoff_exclusive <- fixtures$evidence_cutoff_exclusive
  list(history = history, fixtures = fixtures, teams = sparse$registered_team_ids)
}

ablation_adapter_seeds <- function(fixtures) {
  seeds <- data.frame(
    schema_version = "1.0",
    seed_id = paste0("phase10_seed_", seq_len(nrow(fixtures))),
    purpose = "fixture_prediction", edition_id = fixtures$edition_id,
    boundary_id = fixtures$boundary_id, fixture_id = fixtures$fixture_id,
    seed = 10600L + seq_len(nrow(fixtures)), model_independent = TRUE,
    seed_key_sha256 = "", stringsAsFactors = FALSE
  )
  seeds$seed_key_sha256 <- benchmark_seed_key_sha256(seeds)
  seeds
}

test_that("all seven candidates preserve both-track common adapter contracts", {
  require_ablation_selection_api()
  candidates <- c(
    "poisson_team_ridge", "poisson_team_ridge_elo",
    "dynamic_goal_ability", "dynamic_goal_ability_elo",
    "poisson_team_ridge_elo_dc", "poisson_team_ridge_elo_bivpois",
    "open_nb_elo_only_ablation"
  )
  protocol <- challenger_load_validated_protocol()
  results <- list()
  for (track_id in c("frozen", "updating")) {
    inputs <- ablation_adapter_fixture(track_id)
    for (feature_id in ablation_selection_fixture()$inactive_features) {
      inputs$history[[feature_id]] <- 0
      inputs$history[[paste0(feature_id, "__source_present")]] <- FALSE
      inputs$history[[paste0(feature_id, "__value_present")]] <- FALSE
      inputs$history[[paste0(feature_id, "__imputed")]] <- TRUE
      inputs$history[[paste0(feature_id, "__imputation_reason")]] <-
        "point_in_time_source_coverage_zero"
    }
    seeds <- ablation_adapter_seeds(inputs$fixtures)
    for (candidate_id in candidates) {
      settings <- list(
        registered_team_ids = inputs$teams,
        team_ridge_lambda = 1,
        elo_lasso_lambda = 1,
        pseudo_exposure = 8,
        half_life_days = 730,
        elo_coefficient = 0,
        rho = 0,
        q = 0
      )
      result <- tryCatch(
        suppressWarnings(run_registered_challenger_adapter(
          candidate_id = candidate_id,
          history = inputs$history,
          fixtures = inputs$fixtures,
          seed_registry = seeds,
          support_max = 40L,
          settings = settings,
          run_id = paste("phase10_test", track_id, sep = "__"),
          protocol = protocol
        )),
        error = function(error) {
          stop(candidate_id, "/", track_id, ": ", conditionMessage(error), call. = FALSE)
        }
      )
      key <- paste(candidate_id, track_id, sep = "__")
      results[[key]] <- result
      expect_identical(
        names(result),
        c("predictions", "distributions", "manifests", "feature_coverage")
      )
      expect_setequal(result$predictions$fixture_id, inputs$fixtures$fixture_id)
      expect_equal(nrow(result$distributions), nrow(inputs$fixtures) * 41L * 41L)
      expect_true(all(result$distributions$support_max_home == 40L))
      expect_true(all(result$distributions$support_max_away == 40L))
      expect_setequal(
        unique(result$feature_coverage$feature_coverage_id),
        result$predictions$feature_coverage_id
      )
      inactive <- result$feature_coverage$feature_id %in%
        ablation_selection_fixture()$inactive_features
      expect_false(any(result$feature_coverage$source_present[inactive]))
      expect_false(any(result$feature_coverage$value_present[inactive]))
      expect_true(all(result$feature_coverage$imputed[inactive]))
      expect_false(any(result$feature_coverage$active_in_fit[inactive]))
    }
  }
  siblings <- c(
    "poisson_team_ridge_elo", "poisson_team_ridge_elo_dc",
    "poisson_team_ridge_elo_bivpois"
  )
  for (track_id in c("frozen", "updating")) {
    hashes <- vapply(siblings, function(candidate_id) {
      unique(results[[paste(candidate_id, track_id, sep = "__")]]$manifests$mean_prediction_hash)
    }, character(1))
    expect_length(unique(hashes), 1L)
  }
})
