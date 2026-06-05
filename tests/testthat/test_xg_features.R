# xGelo Unit Tests - xG Feature Calculations

context("xG Feature Calculations")

project_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))
source(file.path(project_root, "R/xg/features.R"))
source(file.path(project_root, "R/xg/data_prep.R"))

test_that("distance calculation uses StatsBomb goal-center coordinates", {
  expect_equal(calculate_distance(120, 40), 0, tolerance = 0.001)
  expect_equal(calculate_distance(108, 40), 12, tolerance = 0.001)
  expect_equal(calculate_distance(60, 40), 60, tolerance = 0.001)
  expect_equal(calculate_distance(0, 0), sqrt(120^2 + 40^2), tolerance = 0.001)
})

test_that("angle calculation returns bounded numeric values", {
  result <- calculate_angle(c(108, 100, 60), c(40, 30, 40))
  expect_true(is.numeric(result))
  expect_true(all(result >= 0 & result <= pi))
})

test_that("domestic filtering fails closed without event manifest", {
  expect_error(
    prepare_training_data(
      events_dir = file.path(project_root, "data/raw/statsbomb/events"),
      competitions_file = file.path(project_root, "data/raw/statsbomb/competitions.json"),
      domestic_only = TRUE,
      event_manifest_file = file.path(tempdir(), "missing-events-manifest.csv")
    ),
    "requires an event manifest"
  )
})

test_that("sample-mode domestic override extracts real shot features", {
  expect_warning(
    data <- prepare_training_data(
      events_dir = file.path(project_root, "data/raw/statsbomb/events"),
      competitions_file = file.path(project_root, "data/raw/statsbomb/competitions.json"),
      domestic_only = TRUE,
      competition_name = "La Liga",
      event_manifest_file = file.path(tempdir(), "missing-events-manifest.csv"),
      allow_unmapped_sample = TRUE
    ),
    "treating checked-in sample events"
  )
  expect_gt(nrow(data), 0)
  expect_true(all(c("distance", "angle", "header", "open_play", "competition", "goal") %in% names(data)))
  expect_true(all(data$competition == "La Liga"))
})
