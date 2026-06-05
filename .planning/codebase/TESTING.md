# Testing Patterns

**Analysis Date:** 2026-06-05

## Test Framework

**Runner:**
- testthat - configured by convention, not by package metadata.
- Config: Not detected. There is no `DESCRIPTION`, `tests/testthat.R`, or standalone testthat config file.
- Test files: `tests/testthat/test_xg_features.R`, `tests/testthat/test_elo.R`, `tests/testthat/test_pipeline.R`.

**Assertion Library:**
- testthat expectations: `expect_equal()`, `expect_true()`, `expect_gt()`, `expect_lt()`, `expect_not_null()`, and `skip()`.

**Run Commands:**
```bash
Rscript -e "library(testthat); test_dir('tests/testthat')"              # Run all tests
Rscript -e "testthat::test_file('tests/testthat/test_xg_features.R')"   # Run xG feature tests
Rscript -e "testthat::test_file('tests/testthat/test_elo.R')"           # Run Elo tests
Rscript -e "testthat::test_file('tests/testthat/test_pipeline.R')"      # Run pipeline integration tests
```

## Test File Organization

**Location:**
- Tests are in a separate `tests/testthat/` directory.
- Tests are not colocated with `R/` source files.
- A root scratch file, `test_len1.R`, is not part of the testthat suite.

**Naming:**
- Use `test_<area>.R` names, with one file per major area: `test_xg_features.R`, `test_elo.R`, `test_pipeline.R`.
- Keep test suite names aligned with project layers: xG features, Elo calculations, pipeline integration.

**Structure:**
```text
tests/
└── testthat/
    ├── test_xg_features.R   # xG unit tests and fallback feature mocks
    ├── test_elo.R           # Elo unit tests and fallback Elo mock
    └── test_pipeline.R      # File, directory, model, forecast, and planning artifact checks
```

## Test Structure

**Suite Organization:**
```r
context("xG Feature Calculations")

if (file.exists("R/xg/features.R")) {
  source("R/xg/features.R")
  have_xg_features <- TRUE
} else {
  have_xg_features <- FALSE
  calculate_distance <- function(x, y) {
    sqrt(x^2 + y^2)
  }
}

test_that("distance calculation works", {
  if (!exists("calculate_distance")) skip("calculate_distance not available")
  expect_equal(calculate_distance(3, 4), 5, tolerance = 0.001)
})
```

**Patterns:**
- Load source files directly with `source("R/...")` at the top of test files, as in `tests/testthat/test_xg_features.R` and `tests/testthat/test_elo.R`.
- Use `context()` at the top of each test file.
- Use `test_that()` blocks with descriptive behavior names.
- Use explicit numeric tolerances for floating-point football/model calculations, usually `tolerance = 0.001`.
- Guard optional dependencies or missing functions with `skip()` or conditional blocks.
- Use `tryCatch(..., error = function(e) NULL)` in tests that probe whether models/files can be read without failing the entire loop immediately.

## Mocking

**Framework:** inline test-local mocks; no mocking package detected.

**Patterns:**
```r
if (file.exists("R/elo/runner.R")) {
  source("R/elo/runner.R")
  have_elo_functions <- TRUE
} else {
  have_elo_functions <- FALSE
  compute_elo_single <- function(home_team, away_team, home_score, away_score,
                                 home_elo, away_elo, k_factor = 20,
                                 home_advantage = 60, is_neutral = FALSE) {
    expected_home <- 1 / (1 + 10^((away_elo - home_elo) / 400))
    actual_home <- ifelse(home_score > away_score, 1, ifelse(home_score < away_score, 0, 0.5))
    list(home = home_elo + k_factor * (actual_home - expected_home), away = away_elo)
  }
}
```

**What to Mock:**
- Mock small pure calculations only when the source file is absent, following `tests/testthat/test_xg_features.R` and `tests/testthat/test_elo.R`.
- Keep fallback mocks inside the test file and limited to the function under test.

**What NOT to Mock:**
- Do not mock pipeline file existence in `tests/testthat/test_pipeline.R`; that file verifies real artifacts under `data/`, `models/`, `outputs/`, and `.planning/`.
- Do not mock model RDS loading in integration tests; use `tryCatch(readRDS(...), error = function(e) NULL)` and assert the loaded object is not null.

## Fixtures and Factories

**Test Data:**
```r
ratings <- data.frame(team = c("A", "B"), rating = c(1500, 1500))

required_files <- c(
  "data/raw/martj42/results.csv",
  "data/processed/elo_matches.csv",
  "models/xg_model.rds"
)
```

**Location:**
- Inline scalar and small data frame fixtures live directly in test files, such as `ratings` in `tests/testthat/test_elo.R`.
- Integration fixtures are real repository artifacts under `data/processed/`, `models/`, `outputs/forecasts/`, and `.planning/phases/`.
- No dedicated `tests/testthat/fixtures/` directory is detected.

## Coverage

**Requirements:** The project documentation states a target of at least 80% coverage for core xG and Elo functions in `AGENTS.md`, `CLAUDE.md`, and `.planning/phases/06-pipeline-quality/PLAN.md`.

**Enforcement:** Not detected. No `covr` config, coverage command, package metadata, or CI threshold is present in the codebase.

**View Coverage:**
```bash
# Not configured in repo. If covr is available, use an ad hoc expression for exploratory checks:
Rscript -e "covr::file_coverage(c('R/xg/features.R', 'R/elo/runner.R'), c('tests/testthat/test_xg_features.R', 'tests/testthat/test_elo.R'))"
```

## Test Types

**Unit Tests:**
- `tests/testthat/test_xg_features.R` covers distance, angle, edge cases, and realistic StatsBomb coordinates for `R/xg/features.R`.
- `tests/testthat/test_elo.R` covers win/loss, draws, home advantage, k-factor sensitivity, rating ranges, and a guarded full-Elo call for `R/elo/runner.R`.
- Tests currently favor simple deterministic calculations and small inline fixtures.

**Integration Tests:**
- `tests/testthat/test_pipeline.R` checks required data/model/output files, required directories, valid model RDS files, forecast CSV schemas, `.planning/phases/...` directories, R script presence, and forecast probability sums.
- `R/pipeline/validation.R` provides runtime validation helpers with boolean results for schemas, xG values, probability validity, model presence, and forecast artifacts.

**E2E Tests:**
- No separate E2E framework detected.
- `_targets.R` defines the end-to-end pipeline, and docs list `targets::tar_make()` as the pipeline execution command, but there is no testthat test that runs the full targets DAG.

## Common Patterns

**Async Testing:**
```r
# Not applicable. Tests are synchronous R/testthat tests.
```

**Error Testing:**
```r
result <- tryCatch(
  compute_elo(home = "A", away = "B", home_score = 2, away_score = 1,
              ratings = ratings, k_factor = 20),
  error = function(e) NULL
)
expect_not_null(result)
```

**Floating-Point Testing:**
```r
expect_equal(calculate_distance(3, 4), 5, tolerance = 0.001)
expect_true(all(abs(prob_sum - 1) < 0.001, na.rm = TRUE))
```

**Current Verification Notes:**
- `Rscript -e "library(testthat); test_dir('tests/testthat', reporter = 'summary')"` fails in `tests/testthat/test_pipeline.R`.
- The failure mode is relative-path based: `test_dir()` executes tests with a working directory that makes project-root paths such as `data/raw/martj42/results.csv`, `R/xg/features.R`, and `.planning/phases/01-data-ingestion` resolve incorrectly.
- Use project-root-aware paths or run file-level tests with an explicit working directory when extending `tests/testthat/test_pipeline.R`.

---

*Testing analysis: 2026-06-05*
