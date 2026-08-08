library(testthat)

source(file.path(
  normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else ".")),
  "tests/testthat/helper_hybrid_phase11.R"
))
hybrid_require_context_api()
# The shared helper intentionally stops before the adapter layer so Wave 0
# context tests can exercise the registry contract independently.  This plan's
# registry test also covers the adapter candidate allow-list explicitly.
hybrid_source_if_present("R/benchmark/hybrid_adapters.R")

test_that("HYBRID-02 / D-05 and D-08 return named open-context evidence", {
  features <- build_open_context_features(
    fixtures = hybrid_context_fixtures(),
    history = hybrid_context_history(),
    country_centroids = hybrid_context_centroids(),
    strict_common_panel = TRUE
  )

  expect_equal(nrow(features), 2L)
  expected_features <- hybrid_context_feature_names()
  expect_true(all(expected_features %in% names(features)))
  companion_suffixes <- c(
    "__value_present", "__source_present", "__source_date",
    "__imputed", "__imputation_reason"
  )
  for (feature in expected_features) {
    expect_true(all(paste0(feature, companion_suffixes) %in% names(features)))
  }

  expect_true(all(is.finite(as.numeric(features$rest_days))))
  expect_true(all(as.numeric(features$rest_days) > 0))
  expect_true(all(is.finite(as.numeric(features$travel_km))))
  expect_true(all(as.numeric(features$travel_km) > 0))
  expect_true(all(as.character(features$stage_id) %in% c("group", "round_of_16")))
  expect_true(all(features$neutral__value_present))
  expect_true(all(features$rest_days__source_present))
  expect_true(all(features$travel_km__source_present))

  feature_dates <- as.Date(features$date)
  for (feature in expected_features) {
    source_dates <- as.Date(features[[paste0(feature, "__source_date")]])
    expect_true(all(is.na(source_dates) | source_dates < feature_dates))
  }
})

test_that("HYBRID-02 / D-07 rejects missing common-panel context instead of imputing", {
  incomplete <- hybrid_context_fixtures()
  incomplete$venue_country[1] <- NA_character_
  incomplete$host_country[1] <- NA_character_
  incomplete$host_team_id[1] <- NA_character_

  expect_error(
    build_open_context_features(
      fixtures = incomplete,
      history = hybrid_context_history(),
      country_centroids = hybrid_context_centroids(),
      strict_common_panel = TRUE
    ),
    "common|missing|context|imput",
    ignore.case = TRUE
  )
})

test_that("HYBRID-02 / D-05 registers the full context bundle and every drop-one ablation", {
  protocol <- load_and_validate_hybrid_protocol()
  expected_ids <- c(
    "phase11_rf_dynamic_elo_open",
    "phase11_rf_dynamic_elo_context_open",
    "phase11_rf_dynamic_elo_context_drop_host_open",
    "phase11_rf_dynamic_elo_context_drop_neutral_open",
    "phase11_rf_dynamic_elo_context_drop_rest_open",
    "phase11_rf_dynamic_elo_context_drop_travel_open",
    "phase11_rf_dynamic_elo_context_drop_stage_open"
  )
  expect_setequal(as.character(protocol$model_registry$candidate_id), expected_ids)
  expect_setequal(hybrid_phase11_candidate_ids(protocol), expected_ids)

  ablations <- canonical_phase11_context_ablation_registry()
  expect_silent(validate_phase11_context_ablation_registry(ablations))
  expect_setequal(
    as.character(ablations$candidate_id),
    expected_ids[-1L]
  )
  expect_identical(
    as.character(ablations$removed_feature_id),
    c("", "host", "neutral", "rest_days", "travel_km", "stage_id")
  )
  expect_true(all(as.integer(ablations$open_fixture_count) == 630L))
  expect_true(all(as.integer(ablations$rich_fixture_count) == 609L))
  expect_true(all(as.integer(ablations$score_support_g) == 40L))
  expect_true(all(as.logical(ablations$research_only)))
  expect_true(all(as.logical(ablations$wc2026_sealed)))
})

test_that("HYBRID-02 / D-06 and D-07 keep context provenance and the open denominator explicit", {
  protocol <- load_and_validate_hybrid_protocol()
  context_features <- protocol$feature_contract[
    protocol$feature_contract$feature_id %in% hybrid_context_feature_names(),
    , drop = FALSE
  ]
  expect_setequal(as.character(context_features$feature_id), hybrid_context_feature_names())
  expect_true(all(context_features$license_class == "open-or-derived-open"))
  expect_true(all(grepl("^[0-9a-f]{64}$", context_features$row_sha256)))
  travel <- context_features[context_features$feature_id == "travel_km", , drop = FALSE]
  expect_equal(nrow(travel), 1L)
  expect_true(grepl("centroid|metadata", travel$availability_rule, ignore.case = TRUE))
  expect_true(grepl("[0-9a-f]{64}.*[0-9a-f]{64}", travel$parent_artifact_sha256))

  context_rows <- protocol$model_registry[
    grepl("context", protocol$model_registry$candidate_id),
    , drop = FALSE
  ]
  expect_true(all(as.character(context_rows$panel_id) == "open_core"))
  expect_true(all(as.integer(context_rows$open_fixture_count) == 630L))
  expect_true(all(as.character(context_rows$mode_id) == "open_default"))
})

test_that("HYBRID-02 dispatches the context bundle and ablations through the common runner", {
  history <- hybrid_rf_history()
  history$edition_id <- "wc2010"
  history$venue_country <- rep(c("DEU", "FRA", "ITA"), length.out = nrow(history))
  history$host_country <- history$venue_country
  history$host_team_id <- history$home_team_id
  history$neutral <- FALSE
  history$stage_id <- "group"

  fixtures <- hybrid_rf_fixtures()
  fixtures$venue_country <- c("DEU", "ITA")
  fixtures$host_country <- c("DEU", "ITA")
  fixtures$host_team_id <- c("team_alpha", "team_beta")
  fixtures$neutral <- c(FALSE, TRUE)
  fixtures$stage_id <- "group"
  fixtures$track_id <- "frozen"
  fixtures$forecast_sequence <- seq_len(nrow(fixtures))
  fixtures$result_cutoff_exclusive <- fixtures$evidence_cutoff_exclusive
  fixtures$regulation_home_goals <- c(1L, 0L)
  fixtures$regulation_away_goals <- c(0L, 1L)
  fixtures$score_eligible <- TRUE

  candidates <- c(
    "phase11_rf_dynamic_elo_context_open",
    "phase11_rf_dynamic_elo_context_drop_host_open",
    "phase11_rf_dynamic_elo_context_drop_neutral_open",
    "phase11_rf_dynamic_elo_context_drop_rest_open",
    "phase11_rf_dynamic_elo_context_drop_travel_open",
    "phase11_rf_dynamic_elo_context_drop_stage_open"
  )
  result <- run_hybrid_challenger_benchmark(
    history = history,
    fixtures = fixtures,
    candidate_order = candidates,
    run_id = "phase11_context_runner_test"
  )

  expect_equal(as.integer(result$run_manifest$candidate_count[[1L]]), length(candidates))
  expect_setequal(as.character(result$candidate_evidence$candidate_id), candidates)
  expect_equal(nrow(result$predictions), length(candidates) * nrow(fixtures))
  expect_equal(nrow(result$distributions), length(candidates) * nrow(fixtures) * 41L * 41L)
  expect_true(nrow(result$scores) > 0L)
  expect_true(all(as.integer(result$candidate_evidence$open_fixture_count) == 630L))
  expect_true(all(as.integer(result$candidate_evidence$rich_fixture_count) == 609L))
  expect_true(all(as.integer(result$candidate_evidence$score_support_g) == 40L))
  expect_true(isTRUE(result$run_manifest$research_only[[1L]]))
  expect_true(isTRUE(result$run_manifest$wc2026_sealed[[1L]]))
})
