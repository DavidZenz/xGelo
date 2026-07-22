library(testthat)

project_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))
source(file.path(project_root, "tests/testthat/helper_statistical_challengers.R"))
source(file.path(project_root, "R/evaluation/proper_scores.R"))
source(file.path(project_root, "R/benchmark/contracts.R"))
source(file.path(project_root, "R/benchmark/cutoffs.R"))
penalized_module <- file.path(project_root, "R/forecast/penalized_poisson.R")
if (file.exists(penalized_module)) source(penalized_module)

require_penalized_tuning_api <- function() {
  required <- c(
    "build_penalized_poisson_design",
    "fit_penalized_team_means",
    "fit_penalized_elo_offset",
    "select_penalized_poisson_hyperparameters",
    "predict_penalized_poisson_means",
    "penalized_poisson_manifest"
  )
  missing <- required[!vapply(required, exists, logical(1), mode = "function")]
  if (length(missing)) {
    fail(paste("Wave 0 RED contract awaits:", paste(missing, collapse = ", ")))
  }
}

canonical_tournament_map <- function(history) {
  unique(history[, c("match_id", "tournament"), drop = FALSE])
}

select_synthetic_penalties <- function(history, tournament_map = canonical_tournament_map(history)) {
  folds <- synthetic_statistical_folds("wc2010")
  select_penalized_poisson_hyperparameters(
    history = history,
    outer_edition_id = "wc2010",
    tournaments = folds$tournaments,
    tuning_editions = folds$tuning_editions,
    tuning_grid = folds$tuning_grid,
    tournament_map = tournament_map,
    support_max = 40L
  )
}

run_synthetic_penalized_candidate <- function(history) {
  sparse <- synthetic_sparse_teams()
  folds <- synthetic_statistical_folds("wc2010")
  settings <- select_synthetic_penalties(history)
  prior <- history[as.Date(history$actual_completion_date) < folds$outer$opener_date, , drop = FALSE]
  design <- build_penalized_poisson_design(
    prior,
    registered_team_ids = sparse$registered_team_ids
  )
  minimal <- fit_penalized_team_means(
    design,
    lambda = unique(settings$team_ridge_lambda),
    observation_weights = rep(1, nrow(prior))
  )
  augmented <- fit_penalized_elo_offset(
    minimal_fit = minimal,
    design = design,
    lambda = unique(settings$elo_lasso_lambda)
  )
  predictions <- predict_penalized_poisson_means(augmented, sparse$fixtures)
  manifest <- penalized_poisson_manifest(
    fit = augmented,
    settings = settings,
    history = prior,
    fixtures = sparse$fixtures,
    candidate_id = "poisson_team_ridge_elo",
    outer_edition_id = "wc2010"
  )
  list(settings = settings, predictions = predictions, manifest = manifest)
}

test_that("the Elo offset stage is nested and may select exactly zero increment", {
  require_penalized_tuning_api()
  sparse <- synthetic_sparse_teams()
  design <- build_penalized_poisson_design(
    sparse$history,
    registered_team_ids = sparse$registered_team_ids
  )
  minimal <- fit_penalized_team_means(
    design,
    lambda = 1,
    observation_weights = rep(1, nrow(sparse$history))
  )
  augmented <- fit_penalized_elo_offset(
    minimal_fit = minimal,
    design = design,
    lambda = 1e6
  )

  expect_equal(augmented$elo_coefficient, 0, tolerance = 0)
  expect_identical(augmented$team_fit_sha256, minimal$team_fit_sha256)
  expect_identical(augmented$active_predictors, character())
  expect_match(augmented$dropped_predictors_with_reason, "elo_diff.*zero", ignore.case = TRUE)

  minimal_predictions <- predict_penalized_poisson_means(minimal, sparse$fixtures)
  augmented_predictions <- predict_penalized_poisson_means(augmented, sparse$fixtures)
  expect_equal(augmented_predictions$mu_home, minimal_predictions$mu_home, tolerance = 1e-12)
  expect_equal(augmented_predictions$mu_away, minimal_predictions$mu_away, tolerance = 1e-12)
})

test_that("parsed source contains no raw-rating or nearest-date reconstruction path", {
  require_penalized_tuning_api()
  parsed_source <- paste(deparse(parse(penalized_module)), collapse = "\n")
  compact <- gsub("[[:space:]]+", " ", parsed_source)

  expect_false(grepl("elo_ratings\\.csv", compact, ignore.case = TRUE))
  expect_false(grepl("read\\.(csv|table).*elo_matches\\.csv", compact, ignore.case = TRUE))
  expect_false(grepl("read_csv.*elo_matches\\.csv", compact, ignore.case = TRUE))
  expect_false(grepl("(findInterval|which\\.min|approx).*elo", compact, ignore.case = TRUE))
  expect_false(grepl("elo.*(findInterval|which\\.min|approx)", compact, ignore.case = TRUE))
  forbidden_formals <- c(
    "rating_history", "raw_ratings", "rating_path", "elo_path",
    "rating_lookup", "elo_lookup", "home_rating", "away_rating"
  )
  expect_false(any(forbidden_formals %in% names(formals(fit_penalized_elo_offset))))
  expect_false(any(forbidden_formals %in% names(formals(select_penalized_poisson_hyperparameters))))
})

test_that("Elo fitting rejects noncanonical values and provenance before optimization", {
  require_penalized_tuning_api()
  sparse <- synthetic_sparse_teams()
  design <- build_penalized_poisson_design(
    sparse$history,
    registered_team_ids = sparse$registered_team_ids
  )
  minimal <- fit_penalized_team_means(
    design,
    lambda = 1,
    observation_weights = rep(1, nrow(sparse$history))
  )
  companions <- c(
    "elo_diff", "elo_diff__value_present", "elo_diff__source_present",
    "elo_diff__source_date", "elo_diff__imputed", "elo_diff__imputation_reason"
  )
  for (column in companions) {
    broken <- design
    broken$row_data[[column]] <- NULL
    expect_error(
      fit_penalized_elo_offset(minimal_fit = minimal, design = broken, lambda = 0.1),
      "elo_diff|provenance|companion"
    )
  }

  stale <- design
  stale$row_data$elo_diff__source_date[1] <- stale$row_data$evidence_cutoff_exclusive[1]
  expect_error(
    fit_penalized_elo_offset(minimal_fit = minimal, design = stale, lambda = 0.1),
    "strictly before|cutoff|stale"
  )
  masquerading <- design
  masquerading$row_data$elo_diff__source_present[1] <- FALSE
  expect_error(
    fit_penalized_elo_offset(minimal_fit = minimal, design = masquerading, lambda = 0.1),
    "source|masquerade|provenance"
  )
  reasonless <- design
  reasonless$row_data$elo_diff__value_present[1] <- FALSE
  reasonless$row_data$elo_diff__imputed[1] <- TRUE
  reasonless$row_data$elo_diff__imputation_reason[1] <- ""
  expect_error(
    fit_penalized_elo_offset(minimal_fit = minimal, design = reasonless, lambda = 0.1),
    "reason|imput"
  )
  injected <- design
  injected$row_data$home_elo <- 1500
  injected$row_data$away_elo <- 1450
  expect_error(
    fit_penalized_elo_offset(minimal_fit = minimal, design = injected, lambda = 0.1),
    "raw|rating|forbidden|noncanonical"
  )

  lookup_calls <- 0L
  lookup_spy <- function(...) {
    lookup_calls <<- lookup_calls + 1L
    stop("lookup callback must never run", call. = FALSE)
  }
  expect_error(
    do.call(
      fit_penalized_elo_offset,
      list(minimal_fit = minimal, design = design, lambda = 0.1, rating_lookup = lookup_spy)
    ),
    "unused argument|forbidden|rating_lookup"
  )
  expect_equal(lookup_calls, 0L)
})

test_that("tournament mapping is one-to-one and complete before tuning", {
  require_penalized_tuning_api()
  history <- synthetic_statistical_history()
  mapping <- canonical_tournament_map(history)

  duplicate <- rbind(mapping, mapping[1, , drop = FALSE])
  expect_error(select_synthetic_penalties(history, duplicate), "duplicate|one-to-one|unique")

  missing <- mapping[-1, , drop = FALSE]
  expect_error(select_synthetic_penalties(history, missing), "unmatched|complete|coverage")

  extra <- rbind(mapping, data.frame(match_id = "not_in_history", tournament = "Friendly"))
  expect_error(select_synthetic_penalties(history, extra), "unmatched|complete|coverage")

  raw_rating_history <- history
  raw_rating_history$home_elo <- 1500
  raw_rating_history$away_elo <- 1450
  expect_error(select_synthetic_penalties(raw_rating_history), "raw|rating|forbidden|noncanonical")
})

test_that("only prior completed tournaments tune one settings pair shared by both tracks", {
  require_penalized_tuning_api()
  history <- synthetic_statistical_history()
  folds <- synthetic_statistical_folds("wc2010")
  settings <- select_synthetic_penalties(history)

  expect_identical(settings$track_id, c("frozen", "updating"))
  expect_equal(length(unique(settings$team_ridge_lambda)), 1L)
  expect_equal(length(unique(settings$elo_lasso_lambda)), 1L)
  expect_equal(length(unique(settings$settings_sha256)), 1L)
  expect_equal(length(unique(settings$eligible_match_ids_sha256)), 1L)
  expect_true(all(as.Date(settings$max_inner_final_date) < folds$outer$opener_date))
  expect_true(all(settings$objective_track == "updating"))
  expect_true(all(settings$team_ridge_lambda %in%
    folds$tuning_grid$value[folds$tuning_grid$parameter_id == "team_ridge_lambda"]))
  expect_true(all(settings$elo_lasso_lambda %in%
    folds$tuning_grid$value[folds$tuning_grid$parameter_id == "elo_lasso_lambda"]))
  expect_true(all(grepl("^[0-9a-f]{64}$", settings$settings_sha256)))
  expect_true(all(grepl("^[0-9a-f]{64}$", settings$eligible_match_ids_sha256)))
})

test_that("assessed-outcome poisoning cannot alter settings, predictions, or manifests", {
  require_penalized_tuning_api()
  history <- synthetic_statistical_history()
  poisoned <- history
  outer <- poisoned$edition_id == "wc2010"
  poisoned$home_goals[outer] <- poisoned$home_goals[outer] + 50L
  poisoned$away_goals[outer] <- poisoned$away_goals[outer] + 40L
  poisoned$regulation_home_goals[outer] <- poisoned$home_goals[outer]
  poisoned$regulation_away_goals[outer] <- poisoned$away_goals[outer]

  original <- run_synthetic_penalized_candidate(history)
  contaminated <- run_synthetic_penalized_candidate(poisoned)
  expect_identical(original$settings, contaminated$settings)
  expect_identical(original$predictions, contaminated$predictions)
  expect_identical(original$manifest, contaminated$manifest)

  required_manifest <- c(
    "candidate_id", "outer_edition_id", "track_id",
    "team_ridge_lambda", "elo_lasso_lambda", "eligible_match_ids_sha256",
    "tuning_grid_sha256", "tuning_protocol_sha256", "settings_sha256",
    "active_predictors", "dropped_predictors_with_reason",
    "cold_start_fixture_count", "fit_max_date", "max_feature_source_date",
    "evidence_cutoff_exclusive", "glmnet_version", "convergence_status"
  )
  expect_true(all(required_manifest %in% names(original$manifest)))
  expect_true(all(as.Date(original$manifest$fit_max_date) < as.Date(original$manifest$evidence_cutoff_exclusive)))
  expect_true(all(as.Date(original$manifest$max_feature_source_date) < as.Date(original$manifest$evidence_cutoff_exclusive)))
})

test_that("candidate comparisons preserve every Phase 9 baseline fixture key", {
  registries <- synthetic_phase10_registries("poisson_team_ridge_elo")
  expect_equal(nrow(registries$tournaments), 12L)
  expect_equal(sum(registries$tournaments$expected_fixture_count), 630L)
  expect_equal(registries$score_support_max, 40L)
  expect_identical(registries$track_ids, c("frozen", "updating"))
  expect_false(any(grepl("2026", registries$tournaments$edition_id)))
  expect_true(all(grepl("^[0-9a-f]{64}$", registries$parent_hashes)))

  by_baseline <- split(registries$comparison_keys, registries$comparison_keys$baseline_id)
  expect_setequal(names(by_baseline), registries$model_registry$model_id)
  for (baseline_id in names(by_baseline)) {
    rows <- by_baseline[[baseline_id]]
    panel_id <- registries$model_registry$panel_id[registries$model_registry$model_id == baseline_id]
    panel <- registries$panel_fixtures[
      registries$panel_fixtures$panel_id == panel_id &
        registries$panel_fixtures$eligible &
        registries$panel_fixtures$output_coverage_required,
      , drop = FALSE
    ]
    expected_count <- if (baseline_id == "production_hybrid_nb") 609L else 630L
    expect_equal(nrow(rows), expected_count, info = baseline_id)
    expect_setequal(rows$fixture_id, panel$fixture_id)
    expect_equal(anyDuplicated(rows$fixture_id), 0L, info = baseline_id)
  }
})
