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
