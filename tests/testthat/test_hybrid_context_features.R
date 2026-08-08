library(testthat)

source(file.path(
  normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else ".")),
  "tests/testthat/helper_hybrid_phase11.R"
))
hybrid_require_context_api()

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
