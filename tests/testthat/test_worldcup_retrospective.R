library(testthat)

project_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))
source(file.path(project_root, "R/evaluation/proper_scores.R"))
source(file.path(project_root, "R/evaluation/worldcup_ledger.R"))
source(file.path(project_root, "R/evaluation/worldcup_retrospective.R"))
source(file.path(project_root, "R/visualization/worldcup_retrospective.R"))
bundle_dir <- file.path(project_root, "outputs/evaluation/wc2026")

test_that("retrospective report contains the required evidence sections", {
  report <- paste(readLines(
    file.path(project_root, "notebooks/worldcup_2026_retrospective.Rmd"), warn = FALSE
  ), collapse = "\n")
  sections <- c(
    "# Scorecard", "# Provenance And Coverage", "# Match Outcomes", "# Goals",
    "# Advancement And Stage Reach", "# Calibration", "# Fixture Ledger", "# Appendices"
  )
  expect_true(all(vapply(sections, grepl, logical(1), x = report, fixed = TRUE)))
  expect_true(grepl("95%", report, fixed = TRUE))
  expect_true(grepl("104", report, fixed = TRUE))
})

test_that("runner is cache-only and exposes deterministic arguments", {
  runner <- paste(readLines(
    file.path(project_root, "scripts/run_worldcup_2026_retrospective.R"), warn = FALSE
  ), collapse = "\n")
  expect_true(all(vapply(
    c("--source-ref", "--output-dir", "--bootstrap-reps", "--seed"),
    grepl, logical(1), x = runner, fixed = TRUE
  )))
  expect_true(all(vapply(
    c('"HEAD"', '"outputs/evaluation/wc2026"', '"2000"', '"20260720"'),
    grepl, logical(1), x = runner, fixed = TRUE
  )))
  forbidden <- c("httr::", "httr2::", "curl::", "download.file", "train_home_goal_model", "train_away_goal_model")
  expect_false(any(vapply(forbidden, grepl, logical(1), x = runner, fixed = TRUE)))
})

test_that("targets declares ordered retrospective contracts", {
  pipeline <- paste(readLines(file.path(project_root, "_targets.R"), warn = FALSE), collapse = "\n")
  expected <- c(
    'source("R/evaluation/proper_scores.R")',
    'source("R/evaluation/worldcup_ledger.R")',
    'source("R/evaluation/worldcup_retrospective.R")',
    'source("R/visualization/worldcup_retrospective.R")',
    "worldcup_retrospective_ledger_bundle", "worldcup_retrospective_score_files",
    "worldcup_retrospective_figure_files", "worldcup_retrospective_report_file"
  )
  expect_true(all(vapply(expected, grepl, logical(1), x = pipeline, fixed = TRUE)))
})

test_that("evaluation bundle reconciles fixtures and pre-kickoff selections", {
  fixtures <- read.csv(file.path(bundle_dir, "fixture_results.csv"), stringsAsFactors = FALSE)
  selected <- read.csv(file.path(bundle_dir, "selected_forecasts.csv"), stringsAsFactors = FALSE)
  coverage <- read.csv(file.path(bundle_dir, "forecast_coverage.csv"), stringsAsFactors = FALSE)
  expect_equal(nrow(fixtures), 104)
  expect_equal(length(unique(fixtures$match_id)), 104)
  expect_equal(nrow(coverage), 104)
  expect_true(all(abs(selected$p_home + selected$p_draw + selected$p_away - 1) <= 1e-6))
  expect_true(all(parse_utc_time(selected$generated_at_utc) < parse_utc_time(selected$kickoff_utc)))
  expect_true(all(parse_utc_time(selected$committed_at) < parse_utc_time(selected$kickoff_utc)))
  expect_equal(sum(coverage$strict), 83)
  expect_equal(sum(coverage$exploratory), 79)
})

test_that("core figures are present with non-zero pixel dimensions", {
  paths <- file.path(bundle_dir, "figures", c(
    "forecast_coverage.png", "cumulative_rps.png", "outcome_calibration.png",
    "forecast_revisions.png", "goal_diagnostics.png"
  ))
  expect_true(all(file.exists(paths)))
  expect_true(all(file.info(paths)$size > 1000))
  if (requireNamespace("png", quietly = TRUE)) {
    dimensions <- lapply(paths, function(path) dim(png::readPNG(path)))
    expect_true(all(vapply(dimensions, function(x) length(x) >= 2 && all(x[1:2] > 100), logical(1))))
  }
})

test_that("report and final manifest identify the requested source", {
  report <- file.path(bundle_dir, "worldcup_2026_retrospective.html")
  manifest_path <- file.path(bundle_dir, "retrospective_manifest.csv")
  expect_true(file.exists(report))
  expect_gt(file.info(report)$size, 10000)
  manifest <- read.csv(manifest_path, stringsAsFactors = FALSE)
  ledger_manifest <- read.csv(file.path(bundle_dir, "bundle_manifest.csv"), stringsAsFactors = FALSE)
  expect_true(all(nchar(manifest$source_sha) == 40))
  expect_equal(unique(manifest$source_sha), unique(ledger_manifest$source_sha))
  manifest_paths <- ifelse(grepl("^/", manifest$path), manifest$path, file.path(project_root, manifest$path))
  expect_true(all(unname(tools::md5sum(manifest_paths)) == manifest$md5))
})
