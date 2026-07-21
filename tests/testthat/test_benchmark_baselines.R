library(testthat)

project_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))
source(file.path(project_root, "R/evaluation/proper_scores.R"))
source(file.path(project_root, "R/benchmark/registry.R"))
source(file.path(project_root, "R/benchmark/contracts.R"))
source(file.path(project_root, "R/forecast/poisson.R"))
for (path in c(
  "R/benchmark/weights.R", "R/benchmark/baselines.R",
  "R/forecast/tournament_formats.R", "R/benchmark/runner.R"
)) {
  full_path <- file.path(project_root, path)
  if (file.exists(full_path)) source(full_path)
}

coverage_ready_fixtures <- function() {
  fixtures <- data.frame(
    schema_version = "1.0", edition_id = "wc2002", track_id = "frozen",
    fixture_id = c("f1", "f2"), boundary_id = "wc2002__frozen",
    forecast_sequence = 1:2, home_team_id = c("a", "b"), away_team_id = c("b", "a"),
    venue_role = c("neutral", "home"), actual_completion_date = as.Date("2002-05-31"),
    evidence_cutoff_exclusive = as.Date("2002-05-31"),
    result_cutoff_exclusive = as.Date("2002-05-31"), stringsAsFactors = FALSE
  )
  producer_features <- c("elo_diff", "form_index_diff", "xga_ewma_diff", "xgd_ewma_diff", "xgf_ewma_diff")
  for (feature_id in producer_features) {
    fixtures[[feature_id]] <- 0
    fixtures[[paste0(feature_id, "__value_present")]] <- TRUE
    fixtures[[paste0(feature_id, "__source_present")]] <- TRUE
    fixtures[[paste0(feature_id, "__source_date")]] <- as.Date("2002-05-30")
    fixtures[[paste0(feature_id, "__imputed")]] <- FALSE
    fixtures[[paste0(feature_id, "__imputation_reason")]] <- ""
  }
  fixtures
}

coverage_seed_registry <- function(fixtures) {
  seeds <- data.frame(
    schema_version = "1.0", seed_id = paste0("s", seq_len(nrow(fixtures))),
    purpose = "fixture_prediction", edition_id = fixtures$edition_id,
    boundary_id = fixtures$boundary_id, fixture_id = fixtures$fixture_id,
    seed = seq_len(nrow(fixtures)) + 10L, model_independent = TRUE,
    seed_key_sha256 = "", stringsAsFactors = FALSE
  )
  seeds$seed_key_sha256 <- benchmark_seed_key_sha256(seeds)
  seeds
}

baseline_training_data <- function(n = 120L) {
  set.seed(902L)
  dates <- as.Date("1998-01-01") + seq_len(n) * 30L
  elo <- rep(seq(-180, 180, length.out = 20), length.out = n)
  venue <- rep(c("home", "neutral", "away"), length.out = n)
  home_mu <- exp(0.35 + elo / 600 + ifelse(venue == "home", 0.18, 0))
  away_mu <- exp(0.20 - elo / 600 + ifelse(venue == "away", 0.18, 0))
  data.frame(
    fixture_id = sprintf("history_%03d", seq_len(n)),
    date = dates,
    actual_completion_date = dates,
    tournament = rep(c("FIFA World Cup", "UEFA Euro qualification", "Friendly", "UEFA Nations League"), length.out = n),
    home_team_id = rep(sprintf("team_%02d", 1:12), length.out = n),
    away_team_id = rep(sprintf("team_%02d", 12:1), length.out = n),
    home_goals = stats::rnbinom(n, size = 4, mu = home_mu),
    away_goals = stats::rnbinom(n, size = 4, mu = away_mu),
    elo_diff = elo,
    venue_role = venue,
    xgf_ewma_diff = sin(seq_len(n) / 7),
    xga_ewma_diff = cos(seq_len(n) / 9),
    xgd_ewma_diff = sin(seq_len(n) / 11),
    form_index_diff = cos(seq_len(n) / 13),
    attack_ability_diff = sin(seq_len(n) / 5),
    defense_ability_diff = cos(seq_len(n) / 6),
    stringsAsFactors = FALSE
  )
}

baseline_registry_rows <- function() {
  read.csv(
    file.path(project_root, "data/benchmark/phase09/model_registry.csv"),
    stringsAsFactors = FALSE
  )
}

test_that("the frozen supervised weight schedule is exact and snapshot normalized", {
  expect_equal(
    benchmark_importance_weight(c("FIFA World Cup", "Euro qualification", "Friendly", "UEFA Nations League", "Other")),
    c(1.8, 1.3, 0.6, 1.3, 1.0)
  )
  history <- baseline_training_data(20)
  weights <- benchmark_observation_weights(history, as.Date("2001-01-01"))
  expect_equal(mean(weights), 1, tolerance = 1e-12)
  expect_true(all(weights > 0))
  expect_true(weights[which.max(history$date)] > weights[which.min(history$date)])
  schedule <- benchmark_weight_schedule()
  expect_equal(schedule$half_life_days, 730)
  expect_equal(schedule$recursive_elo, "not_applied")
})

test_that("uniform and expanding controls emit coherent complete score grids", {
  history <- baseline_training_data(90)
  uniform <- fit_uniform_1x2(history, support_max = 8L)
  expanding <- fit_expanding_1x2(
    history, cutoff = as.Date("2005-01-01"), support_max = 8L
  )
  fixture <- data.frame(
    fixture_id = "fixture_1", elo_diff = 75, venue_role = "neutral",
    stringsAsFactors = FALSE
  )
  uniform_grid <- predict_registered_baseline(uniform, fixture)$distributions
  expanding_grid <- predict_registered_baseline(expanding, fixture)$distributions
  expect_equal(nrow(uniform_grid), 81L)
  expect_equal(sum(uniform_grid$probability), 1, tolerance = 1e-12)
  uniform_market <- derive_benchmark_markets(uniform_grid)
  expect_equal(unname(unlist(uniform_market[c("p_home", "p_draw", "p_away")])), rep(1 / 3, 3), tolerance = 1e-12)
  expect_equal(sum(expanding_grid$probability), 1, tolerance = 1e-12)
  expect_false(isTRUE(all.equal(uniform_grid$probability, expanding_grid$probability)))
  expect_true(all(expanding$training_dates < as.Date("2005-01-01")))
})

test_that("Elo-only negative binomial is neutral-swap symmetric and uses only D-12 inputs", {
  history <- baseline_training_data()
  fit <- fit_elo_goal_nb(history, observation_weights = rep(1, nrow(history)))
  expect_equal(fit$active_predictors, c("elo_difference_for_team", "venue_advantage_for_team"))
  expect_equal(fit$recursive_elo_weighting, "not_applied")
  fixtures <- data.frame(
    fixture_id = c("ab", "ba"), elo_diff = c(120, -120),
    venue_role = c("neutral", "neutral"), stringsAsFactors = FALSE
  )
  predicted <- predict_registered_baseline(fit, fixtures, support_max = 20L)$distributions
  ab <- predicted[predicted$score_distribution_id == "ab__score", ]
  ba <- predicted[predicted$score_distribution_id == "ba__score", ]
  ba <- ba[match(paste(ab$away_goals, ab$home_goals), paste(ba$home_goals, ba$away_goals)), ]
  expect_equal(ab$probability, ba$probability, tolerance = 1e-10)
  expect_identical(fit$fallback_status, "none")
  expect_true(isTRUE(fit$converged))
})

test_that("registered NB incumbents stay distinct and reject registry drift", {
  history <- baseline_training_data()
  registry <- baseline_registry_rows()
  open_row <- registry[registry$model_id == "open_nb_incumbent", ]
  rich_row <- registry[registry$model_id == "production_hybrid_nb", ]
  open_fit <- fit_registered_baseline(open_row, history)
  rich_fit <- fit_registered_baseline(rich_row, history)
  expect_identical(open_fit$panel_id, "open_core")
  expect_identical(rich_fit$panel_id, "feature_rich")
  expect_identical(open_fit$model_family, "negative_binomial")
  expect_identical(rich_fit$model_family, "negative_binomial")
  expect_false(identical(open_fit$active_predictors, rich_fit$active_predictors))

  drifted <- open_row
  drifted$settings_sha256 <- strrep("0", 64)
  expect_error(
    fit_registered_baseline(drifted, history, frozen_registry = registry),
    "settings hash drift"
  )
  tuned <- open_row
  tuned$fold_specific_tuning_allowed <- TRUE
  expect_error(fit_registered_baseline(tuned, history), "Fold-specific tuning")
})

test_that("the common adapter preserves fixture and model-independent seed keys", {
  history <- baseline_training_data()
  registry <- baseline_registry_rows()
  row <- registry[registry$model_id == "uniform_1x2", ]
  fixtures <- data.frame(
    schema_version = "1.0", edition_id = "wc2002", track_id = "frozen",
    fixture_id = c("f1", "f2"), boundary_id = "wc2002__frozen",
    forecast_sequence = 1:2, home_team_id = c("a", "b"), away_team_id = c("b", "a"),
    venue_role = "neutral", actual_completion_date = as.Date("2002-05-31"),
    evidence_cutoff_exclusive = as.Date("2002-05-31"),
    result_cutoff_exclusive = as.Date("2002-05-31"), stringsAsFactors = FALSE
  )
  seeds <- data.frame(
    schema_version = "1.0", seed_id = c("s1", "s2"), purpose = "fixture_prediction",
    edition_id = "wc2002", boundary_id = "wc2002__frozen", fixture_id = c("f1", "f2"),
    seed = c(11L, 12L), model_independent = TRUE, seed_key_sha256 = "",
    stringsAsFactors = FALSE
  )
  seeds$seed_key_sha256 <- benchmark_seed_key_sha256(seeds)
  result <- run_registered_baseline_adapter(
    row, history, fixtures, seeds, support_max = 8L, run_id = "test_run"
  )
  expect_setequal(result$predictions$fixture_id, fixtures$fixture_id)
  expect_setequal(result$predictions$seed_id, seeds$seed_id)
  expect_equal(nrow(result$distributions), 2L * 81L)
  expect_silent(validate_model_manifests(result$manifests))
  expect_true(all(result$predictions$prediction_status == "ok"))
})

test_that("adapter emits exact deterministic feature coverage groups", {
  history <- baseline_training_data()
  registry <- baseline_registry_rows()
  registration <- registry[registry$model_id == "uniform_1x2", , drop = FALSE]
  feature_contract <- read.csv(
    file.path(project_root, "data/benchmark/phase09/feature_contract.csv"),
    stringsAsFactors = FALSE
  )
  feature_contract <- feature_contract[feature_contract$panel_id == registration$panel_id, , drop = FALSE]
  fixtures <- coverage_ready_fixtures()

  frozen_id <- benchmark_feature_coverage_id(
    "test_run", registration$model_id, "frozen", "wc2002__frozen", "f1"
  )
  updating_id <- benchmark_feature_coverage_id(
    "test_run", registration$model_id, "updating", "wc2002__day1", "f1"
  )
  expect_false(identical(frozen_id, updating_id))
  expect_identical(
    frozen_id,
    benchmark_feature_coverage_id("test_run", registration$model_id, "frozen", "wc2002__frozen", "f1")
  )

  result <- run_registered_baseline_adapter(
    registration, history, fixtures, coverage_seed_registry(fixtures),
    support_max = 8L, run_id = "test_run", feature_contract = feature_contract
  )
  coverage <- result$feature_coverage
  expected_features <- sort(unique(feature_contract$feature_id))

  expect_equal(nrow(coverage), nrow(fixtures) * length(expected_features))
  expect_setequal(coverage$feature_id, expected_features)
  expect_true(all(c(
    "schema_version", "feature_coverage_id", "run_id", "model_id", "panel_id",
    "edition_id", "track_id", "boundary_id", "fixture_id", "feature_id",
    "source_id", "source_artifact_sha256", "value_present", "source_present",
    "source_date", "evidence_cutoff_exclusive", "cutoff_valid", "imputed",
    "imputation_reason", "active_in_fit", "coverage_status", "license_class",
    "feature_contract_row_sha256"
  ) %in% names(coverage)))
  expect_true(all(!coverage$active_in_fit))
  expect_silent(validate_feature_coverage(coverage, coverage))
  expect_silent(validate_prediction_feature_coverage_links(result$predictions, coverage, feature_contract))
  expect_setequal(unique(coverage$feature_coverage_id), result$predictions$feature_coverage_id)
})

test_that("feature coverage rejects key, cutoff, imputation, provenance, and link drift", {
  history <- baseline_training_data()
  registration <- baseline_registry_rows()[1, , drop = FALSE]
  feature_contract <- read.csv(
    file.path(project_root, "data/benchmark/phase09/feature_contract.csv"),
    stringsAsFactors = FALSE
  )
  feature_contract <- feature_contract[feature_contract$panel_id == registration$panel_id, , drop = FALSE]
  fixtures <- coverage_ready_fixtures()
  result <- run_registered_baseline_adapter(
    registration, history, fixtures, coverage_seed_registry(fixtures),
    support_max = 8L, run_id = "test_run", feature_contract = feature_contract
  )
  coverage <- result$feature_coverage
  expected <- coverage

  expect_error(validate_feature_coverage(coverage[-1, , drop = FALSE], expected), "registered keys")
  extra <- rbind(coverage, transform(coverage[1, , drop = FALSE], feature_id = "unknown_feature"))
  expect_error(validate_feature_coverage(extra, expected), "registered keys")

  future <- coverage
  future$source_date[1] <- future$evidence_cutoff_exclusive[1]
  expect_error(validate_feature_coverage(future, expected), "cutoff")
  fabricated <- coverage
  fabricated$source_present[1] <- FALSE
  expect_error(validate_feature_coverage(fabricated, expected), "source-absent")
  inverted <- coverage
  inverted$source_present[1] <- FALSE
  inverted$source_date[1] <- as.Date(NA)
  inverted$value_present[1] <- TRUE
  expect_error(validate_feature_coverage(inverted, expected), "masquerade")
  unreasoned <- coverage
  unreasoned$value_present[1] <- FALSE
  unreasoned$imputed[1] <- TRUE
  unreasoned$imputation_reason[1] <- ""
  expect_error(validate_feature_coverage(unreasoned, expected), "reason")

  drifted <- coverage
  drifted$source_artifact_sha256[1] <- strrep("0", 64)
  expect_error(validate_feature_coverage(drifted, expected), "provenance")
  drifted <- coverage
  drifted$feature_contract_row_sha256[1] <- strrep("0", 64)
  expect_error(validate_feature_coverage(drifted, expected), "contract hash")
  drifted <- coverage
  drifted$license_class[1] <- "unknown"
  expect_error(validate_feature_coverage(drifted, expected), "license")

  dangling <- result$predictions
  dangling$feature_coverage_id[1] <- "missing_group"
  expect_error(
    validate_prediction_feature_coverage_links(dangling, coverage, feature_contract),
    "dangling"
  )
})

test_that("runner preserves producer evidence before applying numeric defaults", {
  history <- data.frame(
    date = as.Date("2002-05-31"), actual_completion_date = as.Date("2002-05-31"),
    home_team = "A", away_team = "B", home_goals = 1, away_goals = 0,
    venue_role = "neutral", tournament = "FIFA World Cup", elo_diff = NA_real_,
    elo_diff__value_present = FALSE, elo_diff__source_present = FALSE,
    elo_diff__source_date = as.Date(NA), elo_diff__imputed = TRUE,
    elo_diff__imputation_reason = "missing_source_row", stringsAsFactors = FALSE
  )
  prepared <- benchmark_runner_prepare_history(history, baseline_registry_rows())
  expect_true(is.na(prepared$elo_diff))
  expect_false(prepared$elo_diff__source_present)
  expect_true(prepared$elo_diff__imputed)
  expect_equal(prepared$elo_diff__imputation_reason, "missing_source_row")

  fixtures <- data.frame(
    fixture_id = "f1", actual_completion_date = as.Date("2002-05-31"),
    home_team_id = "a", away_team_id = "b", venue_role = "neutral",
    stringsAsFactors = FALSE
  )
  teams <- data.frame(team_id = c("a", "b"), canonical_name = c("A", "B"), stringsAsFactors = FALSE)
  features <- benchmark_runner_fixture_features(fixtures, teams, prepared)
  expect_equal(features$elo_diff, 0)
  expect_false(features$elo_diff__value_present)
  expect_false(features$elo_diff__source_present)
  expect_true(features$elo_diff__imputed)
  expect_equal(features$elo_diff__imputation_reason, "missing_source_row")
  expect_true(is.na(features$elo_diff__source_date))
})

test_that("support audit is complete, checksummed, globally minimal, and hard-fails without support", {
  registry <- baseline_registry_rows()[1:2, ]
  registry$candidate_min <- 8L
  registry$candidate_max <- 10L
  boundaries <- data.frame(
    edition_id = c("wc2002", "wc2002"), track_id = c("frozen", "updating"),
    boundary_id = c("wc2002__frozen", "wc2002__day1"),
    boundary_sha256 = c(strrep("1", 64), strrep("2", 64)), stringsAsFactors = FALSE
  )
  tail_evaluator <- function(model_id, edition_id, track_id, boundary_id, candidate_g) {
    ifelse(candidate_g < 10L, 1e-6, 1e-12)
  }
  audit <- build_score_support_audit(registry, boundaries, tail_evaluator)
  expect_equal(unique(audit$selected_g), 10L)
  expect_equal(nrow(audit), 2L * 2L * 3L)
  expect_silent(validate_score_support_audit(audit, registry, boundaries))
  expect_true(all(grepl("^[0-9a-f]{64}$", audit$row_hash)))
  expect_error(
    build_score_support_audit(registry, boundaries, function(...) 1e-3),
    "No globally valid score support"
  )
})

test_that("all registered tournament formats conserve expected stage and champion mass", {
  formats <- read.csv(file.path(project_root, "data/benchmark/phase09/formats.csv"), stringsAsFactors = FALSE)
  routes <- read.csv(file.path(project_root, "data/benchmark/phase09/route_rules.csv"), stringsAsFactors = FALSE)
  seed_ledger <- data.frame(
    seed_id = "stage_seed", purpose = "stage_simulation", seed = 902L,
    model_independent = TRUE, stringsAsFactors = FALSE
  )
  expected_mass <- list(
    wc32_r16 = c(round_of_16 = 16, quarterfinal = 8, semifinal = 4, final = 2, champion = 1),
    euro16_qf = c(quarterfinal = 8, semifinal = 4, final = 2, champion = 1),
    euro24_r16_best4third = c(round_of_16 = 16, quarterfinal = 8, semifinal = 4, final = 2, champion = 1)
  )
  deterministic_paths <- function(adapter, team_ids, n_simulations) {
    stages <- names(expected_mass[[adapter$format$format_id]])
    do.call(rbind, lapply(stages, function(stage) {
      mass <- expected_mass[[adapter$format$format_id]][[stage]]
      simulation_id <- rep(seq_len(n_simulations), each = mass)
      slot <- rep(seq_len(mass), times = n_simulations)
      data.frame(
        simulation_id = simulation_id,
        team_id = team_ids[((slot + simulation_id - 2L) %% length(team_ids)) + 1L],
        stage_id = stage,
        stringsAsFactors = FALSE
      )
    }))
  }
  for (format_id in formats$format_id) {
    adapter <- get_tournament_format_adapter(format_id, formats, routes)
    expect_silent(validate_tournament_format(adapter))
    teams <- sprintf("team_%02d", seq_len(adapter$format$team_count))
    stage <- simulate_registered_tournament(
      adapter, teams, seed_ledger, deterministic_paths,
      run_id = "run", model_id = "uniform_1x2", edition_id = "edition",
      anchor_boundary_id = "edition__frozen", n_simulations = 50000L
    )
    expect_silent(validate_stage_probabilities(stage))
    mass <- tapply(stage$probability, stage$stage_id, sum)
    expect_equal(
      unname(as.numeric(mass[names(expected_mass[[format_id]])])),
      unname(as.numeric(expected_mass[[format_id]])),
      tolerance = 1e-12
    )
  }
})

test_that("post-output rich coverage is observed without mutating frozen declarations", {
  panel <- data.frame(
    panel_id = "feature_rich", edition_id = c("e1", "e1"), fixture_id = c("f1", "f2"),
    eligible = TRUE, point_in_time_provenance_complete = TRUE,
    output_coverage_required = TRUE, stringsAsFactors = FALSE
  )
  predictions <- data.frame(
    model_id = "production_hybrid_nb", panel_id = "feature_rich",
    fixture_id = c("f1", "f2"), prediction_status = c("ok", "ok"), stringsAsFactors = FALSE
  )
  observed <- benchmark_output_coverage(predictions, panel, "production_hybrid_nb", coverage_floor = 0.8)
  expect_true(observed$output_coverage_complete)
  expect_true(observed$promotion_eligible)
  expect_false(any(c("output_coverage_complete", "promotion_eligible") %in% names(panel)))
})
