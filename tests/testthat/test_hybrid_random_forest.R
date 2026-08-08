library(testthat)

source(file.path(
  normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else ".")),
  "tests/testthat/helper_hybrid_phase11.R"
))
hybrid_require_rf_api()

test_that("HYBRID-01 / D-01 and D-03 fit independent home and away goal forests", {
  history <- hybrid_rf_history()
  fit <- fit_hybrid_two_goal_rf(
    history = history,
    cutoff = as.Date("2010-06-11"),
    settings = hybrid_rf_settings()
  )

  expect_true(is.list(fit))
  expect_true(all(c("home_model", "away_model") %in% names(fit)))
  expect_false(identical(fit$home_model, fit$away_model))
  expect_false(any(c("p_home", "p_draw", "p_away") %in% names(fit)))

  means <- predict_hybrid_rf_means(
    fit = fit,
    fixtures = hybrid_rf_fixtures(),
    settings = hybrid_rf_settings()
  )
  expect_equal(nrow(means), 2L)
  expect_true(all(c("fixture_id", "mu_home", "mu_away") %in% names(means)))
  expect_true(all(is.finite(means$mu_home) & means$mu_home > 0))
  expect_true(all(is.finite(means$mu_away) & means$mu_away > 0))

  evidence <- hybrid_rf_evidence_features()
  expect_true(all(evidence %in% names(means)))
  expect_true(all(vapply(
    evidence,
    function(feature) {
      all(c(
        paste0(feature, "__source_date"),
        paste0(feature, "__source_present"),
        paste0(feature, "__value_present"),
        paste0(feature, "__imputed"),
        paste0(feature, "__imputation_reason")
      ) %in% names(means))
    },
    logical(1)
  )))
  expect_true(all(as.Date(means$elo_diff__source_date) < as.Date("2010-06-11")))
  expect_true(all(means$elo_diff__source_present))
  expect_true(all(means$home_attack_effect__source_present))
})

test_that("HYBRID-01 / D-02 emits one reconciled NB score grid at sealed G=40", {
  history <- hybrid_rf_history()
  fit <- fit_hybrid_two_goal_rf(
    history = history,
    cutoff = as.Date("2010-06-11"),
    settings = hybrid_rf_settings()
  )
  means <- predict_hybrid_rf_means(
    fit = fit,
    fixtures = hybrid_rf_fixtures(),
    settings = hybrid_rf_settings()
  )
  distributions <- hybrid_rf_nb_score_distributions(
    means = means,
    support_max = 40L,
    settings = hybrid_rf_settings()
  )

  expect_true(is.data.frame(distributions))
  expect_equal(nrow(distributions), 2L * 41L * 41L)
  expect_true(all(c(
    "score_distribution_id", "home_goals", "away_goals", "probability",
    "support_max_home", "support_max_away", "raw_tail_mass", "normalized"
  ) %in% names(distributions)))
  expect_equal(unique(distributions$support_max_home), 40L)
  expect_equal(unique(distributions$support_max_away), 40L)
  expect_true(all(distributions$normalized))
  expect_true(all(is.finite(distributions$probability) & distributions$probability >= 0))

  expected_ids <- unique(distributions$score_distribution_id)
  expect_length(expected_ids, 2L)
  expect_silent(validate_benchmark_score_distributions(
    distributions,
    expected_distribution_ids = expected_ids,
    support_max = 40L,
    raw_tail_tolerance = 1e-8
  ))

  for (distribution_id in expected_ids) {
    grid <- distributions[
      distributions$score_distribution_id == distribution_id,
      ,
      drop = FALSE
    ]
    expect_equal(nrow(grid), 1681L)
    expect_equal(
      as.integer(sort(unique(grid$home_goals))),
      0:40
    )
    expect_equal(
      as.integer(sort(unique(grid$away_goals))),
      0:40
    )
    market <- derive_benchmark_markets(grid)
    expect_equal(
      sum(c(market$p_home, market$p_draw, market$p_away)),
      1,
      tolerance = 1e-10
    )
    expect_true(all(is.finite(unlist(market))))
  }
})

test_that("HYBRID-01 / D-04 exposes one sealed research-only RF registration", {
  protocol <- load_and_validate_hybrid_protocol()
  registration <- protocol$model_registry[
    protocol$model_registry$candidate_id == "phase11_rf_dynamic_elo_open",
    , drop = FALSE
  ]

  expect_equal(nrow(registration), 1L)
  expect_equal(as.character(registration$native_panel_id), "open_core")
  expect_equal(as.integer(registration$score_support_max), 40L)
  expect_equal(as.integer(registration$open_fixture_count), 630L)
  expect_equal(as.integer(registration$rich_fixture_count), 609L)
  expect_true(isTRUE(as.logical(registration$research_only)))
  expect_true(isTRUE(as.logical(registration$wc2026_sealed)))
  expect_true(grepl("num.trees=", registration$settings, fixed = TRUE))
  expect_true(grepl("nb_dispersion_source=", registration$settings, fixed = TRUE))
})

test_that("HYBRID-01 / D-04 runs the RF through the common score service", {
  history <- hybrid_rf_history()
  fixtures <- hybrid_rf_fixtures()
  fixtures$track_id <- "frozen"
  fixtures$forecast_sequence <- seq_len(nrow(fixtures))
  fixtures$result_cutoff_exclusive <- fixtures$evidence_cutoff_exclusive
  fixtures$regulation_home_goals <- c(1L, 0L)
  fixtures$regulation_away_goals <- c(0L, 1L)
  fixtures$score_eligible <- TRUE

  result <- run_hybrid_challenger_benchmark(
    history = history,
    fixtures = fixtures,
    run_id = "phase11_rf_tracer_test"
  )

  expect_true(is.data.frame(result$predictions))
  expect_true(is.data.frame(result$distributions))
  expect_true(is.data.frame(result$scores))
  expect_equal(nrow(result$predictions), 2L)
  expect_equal(nrow(result$distributions), 2L * 41L * 41L)
  expect_true(nrow(result$scores) > 0L)
  expect_true(isTRUE(result$run_manifest$research_only[[1L]]))
  expect_true(isTRUE(result$run_manifest$wc2026_sealed[[1L]]))
  expect_true(isTRUE(result$run_manifest$network_free[[1L]]))
  expect_equal(as.integer(result$run_manifest$selected_g[[1L]]), 40L)
})

test_that("HYBRID-01 / D-04 freezes the registered RF tuning grid and provenance", {
  protocol <- load_and_validate_hybrid_protocol()
  registration <- protocol$model_registry[
    protocol$model_registry$candidate_id == "phase11_rf_dynamic_elo_open",
    , drop = FALSE
  ]

  grid <- canonical_phase11_rf_tuning_grid()
  expect_equal(nrow(grid), 1L)
  expect_equal(as.character(grid$candidate_id), "phase11_rf_dynamic_elo_open")
  expect_equal(as.integer(grid$num.trees), 64L)
  expect_equal(as.integer(grid$mtry), 3L)
  expect_equal(as.integer(grid$min.node.size), 1L)
  expect_equal(as.character(grid$seed_policy), "registered_seed")
  expect_equal(as.character(grid$settings_sha256), as.character(registration$settings_sha256))

  expect_error(
    hybrid_rf_registered_settings(
      list(num.trees = 65L), registration = registration
    ),
    "not registered"
  )

  fit <- fit_hybrid_two_goal_rf(
    history = hybrid_rf_history(),
    cutoff = as.Date("2010-06-11"),
    settings = hybrid_rf_settings(),
    registration = registration
  )
  expect_equal(fit$environment$package_version, "0.18.0")
  expect_equal(fit$ranger_provenance_id, registration$ranger_provenance_id)
  expect_equal(fit$settings_sha256, registration$settings_sha256)
  expect_equal(fit$runtime_settings$`num.trees`, 64L)
  expect_equal(fit$runtime_settings$mtry, 3L)
  expect_equal(fit$runtime_settings$`min.node.size`, 1L)
})
