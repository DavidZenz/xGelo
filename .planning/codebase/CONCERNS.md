# Codebase Concerns

**Analysis Date:** 2026-06-05

## Tech Debt

**Forecasting uses placeholder fixture features:**
- Issue: `simulate_fixture()` ignores the supplied teams and date, assigns both teams base Elo 1500, and only applies a fixed 60-point venue adjustment.
- Files: `R/forecast/monte_carlo.R:46`, `R/forecast/monte_carlo.R:48`, `R/forecast/monte_carlo.R:49`, `R/forecast/monte_carlo.R:117`
- Impact: Team-specific forecasts collapse to generic home/neutral/away forecasts. `home_team`, `away_team`, and `date` do not influence ratings, xG form, rest, or other match features.
- Fix approach: Replace placeholder Elo assignment with a feature lookup from `data/processed/elo_ratings.csv`, `data/processed/rolling_form.csv`, and fixture date. Fail clearly when a fixture cannot be feature-complete.

**Forecast calibration is demonstration logic:**
- Issue: `calibrate_model()` compares repeated generic simulations of `"A"` vs `"B"` to sampled draw outcomes, then writes a fixed four-point calibration plot.
- Files: `R/forecast/calibration.R:41`, `R/forecast/calibration.R:45`, `R/forecast/calibration.R:51`, `R/forecast/calibration.R:60`
- Impact: Reported Brier score and draw calibration do not validate real forecast predictions against held-out match outcomes.
- Fix approach: Persist forecast predictions at match grain, join to actual outcomes, and compute Brier/log loss/calibration bins from those rows.

**Visualization metrics are hard-coded or synthetic:**
- Issue: AUC chart values and intervals are embedded constants, and forecast calibration plots create synthetic reliability data.
- Files: `R/visualization/auc.R:20`, `R/visualization/auc.R:28`, `R/visualization/auc.R:29`, `R/visualization/calibration.R:148`, `R/visualization/calibration.R:154`, `R/visualization/calibration.R:155`
- Impact: Visual outputs can look valid while not reflecting the generated models or forecasts.
- Fix approach: Read metrics from backtest/calibration artifacts such as `outputs/model_performance/xg_backtest.csv` and a forecast backtest table, then render plots from those data.

**xG domestic-only filtering is computed but not applied:**
- Issue: `prepare_training_data()` computes `is_domestic` when `domestic_only = TRUE`, but it still processes every JSON file in `events_dir`.
- Files: `R/xg/data_prep.R:16`, `R/xg/data_prep.R:25`, `R/xg/data_prep.R:31`, `R/xg/data_prep.R:36`, `R/xg/data_prep.R:43`
- Impact: International or cup data can enter xG training despite the contamination constraint.
- Fix approach: Map event files to competition metadata before processing and filter `event_files` to the domestic competition set.

**Duplicate Elo implementations are not aligned:**
- Issue: `R/elo/runner.R` and `R/elo/runner_optimized.R` define overlapping exported functions (`expected_result()`, `apply_decay()`, `get_k_factor()`, `elo_update()`), but `_targets.R` sources only `R/elo/runner.R`.
- Files: `R/elo/runner.R:129`, `R/elo/runner_optimized.R:58`, `_targets.R:12`
- Impact: Optimizations and bug fixes can land in one runner while the pipeline uses the other.
- Fix approach: Keep one canonical Elo implementation or make `R/elo/runner.R` delegate to optimized internals with shared tests.

## Known Bugs

**Pipeline entry point does not source:**
- Symptoms: `Rscript -e 'source("_targets.R")'` fails before target creation because missing ingestion scripts are sourced.
- Files: `_targets.R:7`, `_targets.R:8`, `_targets.R:9`
- Trigger: Run `source("_targets.R")` from project root.
- Workaround: Run individual scripts directly; no complete `_targets.R` workaround is present in the codebase.

**Targets definition uses non-standard and unresolved target wiring:**
- Symptoms: `_targets.R` contains `pattern = map(data_raw)`, `pattern = map(models_forecast)`, string-valued `pattern` fields, and `depends = ...` fields that are not valid dependency declarations for normal `targets::tar_target()` usage.
- Files: `_targets.R:34`, `_targets.R:54`, `_targets.R:55`, `_targets.R:89`, `_targets.R:91`, `_targets.R:123`, `_targets.R:125`, `_targets.R:172`, `_targets.R:174`
- Trigger: Load or run the targets pipeline.
- Workaround: Execute phase scripts manually rather than relying on `targets::tar_make()`.

**Targets call functions with missing arguments or wrong names:**
- Symptoms: `_targets.R` calls `prepare_training_data()` with no `events_dir` or `competitions_file`, calls `calibrate_xg()` although the source defines `calibrate_xg_model()`, and calls missing functions such as `compute_elo_all()`, `ingest_martj42()`, `ingest_statsbomb()`, and `clean_and_normalize()`.
- Files: `_targets.R:27`, `_targets.R:29`, `_targets.R:46`, `_targets.R:63`, `_targets.R:77`, `_targets.R:86`, `R/xg/data_prep.R:16`, `R/xg/calibration.R:15`
- Trigger: Execute the `tar_xg_model`, `tar_elo_ratings`, or ingestion targets.
- Workaround: Use implemented functions directly with explicit file paths.

**Goal-model Elo lookup does not filter by requested team:**
- Symptoms: `get_elo()` uses `filter(team == team, date <= match_date)`, which compares the column to itself and selects all teams before the date.
- Files: `R/forecast/poisson.R:40`, `R/forecast/poisson.R:128`
- Trigger: Run `train_home_goal_model()` or `train_away_goal_model()`.
- Workaround: None in current code; replace the helper argument name and use explicit column qualification such as `.data$team == requested_team`.

**Goal model training silently returns `NULL`:**
- Symptoms: Negative-binomial and Poisson failures produce `message("All models failed, returning NULL")`, then training returns `NULL` without an error.
- Files: `R/forecast/poisson.R:80`, `R/forecast/poisson.R:81`, `R/forecast/poisson.R:85`, `R/forecast/poisson.R:165`, `R/forecast/poisson.R:166`, `R/forecast/poisson.R:170`
- Trigger: Model convergence or formula/data failure during `train_home_goal_model()` or `train_away_goal_model()`.
- Workaround: Check the return value and saved model files manually.

**Test suite fails as a suite:**
- Symptoms: `testthat::test_dir("tests/testthat")` exits with failures in `tests/testthat/test_pipeline.R`, including missing files/directories and missing R scripts.
- Files: `tests/testthat/test_pipeline.R:8`, `tests/testthat/test_pipeline.R:25`, `tests/testthat/test_pipeline.R:81`, `tests/testthat/test_pipeline.R:96`
- Trigger: Run `Rscript -e 'testthat::test_dir("tests/testthat")'` from project root.
- Workaround: `testthat::test_file("tests/testthat/test_xg_features.R")` and `testthat::test_file("tests/testthat/test_elo.R")` pass individually because they use file-level behavior and/or mocks.

**Elo k-factor yearly counters update after last-match dates are overwritten:**
- Symptoms: `R/elo/runner_optimized.R` sets `last_match_dates[...] <- match_date` and then checks whether the year changed, making the year-change branch unreachable for processed matches.
- Files: `R/elo/runner_optimized.R:200`, `R/elo/runner_optimized.R:206`, `R/elo/runner_optimized.R:213`
- Trigger: Run `compute_elo_optimized()` across multi-year data.
- Workaround: Use explicit year counter state independent of `last_match_dates`.

## Security Considerations

**Generated data and model artifacts are not broadly ignored:**
- Risk: Raw open data, processed outputs, and binary model artifacts are present under versionable paths, while `.gitignore` only excludes `data/raw/wcq_cache/` and `data/cache/`.
- Files: `.gitignore:1`, `.gitignore:2`, `data/raw/martj42/results.csv`, `data/raw/statsbomb/events/15946.json`, `data/processed/elo_ratings.csv`, `models/xg_model.rds`, `models/home_goal_model.rds`, `models/away_goal_model.rds`
- Current mitigation: `data/raw/wcq_cache/` and `data/cache/` are ignored.
- Recommendations: Decide which generated/open-data artifacts are committed. Add explicit ignore rules for regenerated outputs and model binaries if the project expects reproducible local builds instead of checked-in artifacts.

**Forecast output paths derive from team names:**
- Risk: `generate_forecast()` builds filenames directly from `home_team` and `away_team`; unsafe fixture names can create awkward or nested paths on some platforms.
- Files: `R/forecast/output.R:30`, `R/forecast/output.R:37`, `R/forecast/output.R:62`
- Current mitigation: None beyond `file.path(output_dir, ...)`.
- Recommendations: Sanitize fixture IDs to a strict filename alphabet and keep raw team names only in CSV columns.

**RDS loading executes trusted local artifacts only by convention:**
- Risk: Multiple functions use `readRDS()` on model/data paths. RDS is not a safe interchange format for untrusted input.
- Files: `R/forecast/monte_carlo.R:40`, `R/forecast/monte_carlo.R:41`, `R/visualization/calibration.R:35`, `R/visualization/calibration.R:133`
- Current mitigation: Paths default to local project artifacts in `models/` and `data/processed/`.
- Recommendations: Treat model RDS files as trusted build artifacts only; avoid loading user-supplied model paths in public interfaces.

**Secrets files are not detected:**
- Risk: Not detected for `.env*`, `.Renviron`, `*.pem`, `*.key`, `*secret*`, or `*credential*` files in the scanned tree.
- Files: `.gitignore`
- Current mitigation: No secret-bearing files are present in the scan output.
- Recommendations: Add `.Renviron`, `.env*`, and common key patterns to `.gitignore` before adding API-backed ingestion.

## Performance Bottlenecks

**Unoptimized Elo runner uses repeated `rbind()` in the match loop:**
- Problem: `compute_elo()` appends four rows per match via `rbind()`.
- Files: `R/elo/runner.R:238`, `R/elo/runner.R:250`, `R/elo/runner.R:299`, `R/elo/runner.R:311`
- Cause: Repeated data-frame growth is quadratic and memory-heavy for the 49k-match martj42 dataset.
- Improvement path: Use the preallocated approach from `R/elo/runner_optimized.R` after fixing its yearly counter bug, or build a list and bind once.

**Goal-model training performs nested dplyr filters:**
- Problem: Each sampled match loops through `get_elo()`, and each lookup filters the full Elo ratings table.
- Files: `R/forecast/poisson.R:40`, `R/forecast/poisson.R:48`, `R/forecast/poisson.R:128`, `R/forecast/poisson.R:135`
- Cause: O(sampled_matches * rating_rows) filtering plus the `team == team` bug.
- Improvement path: Precompute pre-match rating features by joining/rolling ratings once, then train GLMs from the feature table.

**Forecast training is capped to 2,000 rows after random sampling:**
- Problem: `train_home_goal_model()` and `train_away_goal_model()` sample up to 5,000 matches, then train on only the first 2,000.
- Files: `R/forecast/poisson.R:29`, `R/forecast/poisson.R:48`, `R/forecast/poisson.R:120`, `R/forecast/poisson.R:135`
- Cause: MVP speed cap rather than scalable feature preparation.
- Improvement path: Make sample size a documented tuning parameter, train on all eligible historical rows by default, and benchmark the join-based feature table.

**Monte Carlo simulation is serial per fixture:**
- Problem: Batch forecasts call `generate_forecast()` in a for-loop, and each fixture defaults to 50,000 negative-binomial draws.
- Files: `R/forecast/output.R:82`, `R/forecast/monte_carlo.R:25`, `R/forecast/monte_carlo.R:74`, `R/forecast/monte_carlo.R:75`
- Cause: Fixture-level work is not vectorized or parallelized.
- Improvement path: Add vectorized or parallel batch simulation and fixed RNG stream handling for reproducible parallel runs.

## Fragile Areas

**StatsBomb match metadata inference:**
- Files: `R/integration/team_match_xg.R:75`, `R/integration/team_match_xg.R:81`, `R/integration/team_match_xg.R:90`, `R/integration/team_match_xg.R:110`
- Why fragile: Competition name can become `Unknown_Comp_*`, match date can fall back to file modification time, and home/away is inferred from the first two unique teams in event order.
- Safe modification: Load match metadata from StatsBomb match files or a manifest keyed by match ID; reject files without exactly one fixture mapping.
- Test coverage: `tests/testthat/test_pipeline.R` checks file existence, not home/away/date correctness.

**Rolling form includes the current match in the reported value:**
- Files: `R/integration/rolling_form.R:135`, `R/integration/rolling_form.R:148`, `R/integration/rolling_form.R:178`, `R/integration/rolling_form.R:205`
- Why fragile: EWMA is calculated over each team's ordered matches and stored on the same match row, so using that row as a pre-match feature leaks current-match xG unless downstream code lags it.
- Safe modification: Emit both post-match form and explicitly lagged pre-match form columns; use only pre-match columns for forecasting.
- Test coverage: No test asserts temporal leakage prevention in `tests/testthat/test_pipeline.R`.

**xG test files do not exercise loaded production functions under suite execution:**
- Files: `tests/testthat/test_xg_features.R:16`, `tests/testthat/test_xg_features.R:33`, `tests/testthat/test_xg_features.R:74`, `R/xg/features.R:28`
- Why fragile: When run from the test directory, the test can fall back to mock distance/angle functions. The mocked distance expectations use origin-based distance, while production `calculate_distance()` measures distance to the goal center.
- Safe modification: Use `testthat::local_edition(3)` plus `source(test_path("../../R/xg/features.R"))` or package-style loading, then rewrite expectations around StatsBomb goal coordinates.
- Test coverage: Current individual `test_file()` run reports 15 passes, but those passes do not prove production feature behavior.

**Elo tests target missing mock API rather than exported API:**
- Files: `tests/testthat/test_elo.R:12`, `tests/testthat/test_elo.R:15`, `tests/testthat/test_elo.R:39`, `tests/testthat/test_elo.R:97`, `R/elo/runner.R:47`
- Why fragile: Tests mostly call `compute_elo_single()`, which is not implemented in `R/elo/runner.R`; under some working directories they skip or use mock logic instead of validating `elo_update()` and `compute_elo()`.
- Safe modification: Test `expected_result()`, `elo_update()`, `apply_decay()`, `get_k_factor()`, and `compute_elo()` directly with small fixture data.
- Test coverage: No test validates chronological processing, team mapping, decay, or current-ratings output shape.

**Probability extraction depends on column-order fallbacks:**
- Files: `R/xg/model.R:97`, `R/xg/model.R:101`, `R/integration/team_match_xg.R:338`, `R/visualization/calibration.R:42`
- Why fragile: When expected tidymodels probability column names are not found, code often falls back to the second prediction column. `R/visualization/calibration.R:42` also checks `" .pred_Goal"` with a leading space.
- Safe modification: Normalize outcome factor levels at training time and require the exact positive class column in all prediction paths.
- Test coverage: No tests assert prediction-column selection.

## Scaling Limits

**Training data volume is sample-sized:**
- Current capacity: `data/raw/statsbomb/events/` contains 5 event files in the scanned tree, and goal model training caps at 2,000 rows.
- Limit: Model metrics and calibration are sensitive to small samples and do not represent the intended open-data universe.
- Scaling path: Add metadata-driven StatsBomb ingestion, deterministic train/test splits by season or match, and join-based feature materialization.

**Validation is hard-coded to specific sample files:**
- Current capacity: `run_all_validations()` checks `data/raw/statsbomb/events/15946.json` and fixed output paths.
- Limit: New datasets can pass or fail based on sample-file presence rather than schema and coverage.
- Scaling path: Validate all files under source directories and produce a table of file-level results.

**Pipeline orchestration is not executable:**
- Current capacity: Individual scripts can be sourced or run manually; `_targets.R` does not load.
- Limit: Incremental rebuilds, dependency invalidation, and reproducibility guarantees from `targets` are unavailable.
- Scaling path: Rebuild `_targets.R` as a list of valid `tar_target()` objects whose commands return artifacts and reference upstream targets directly.

## Dependencies at Risk

**`targets` pipeline contract:**
- Risk: `_targets.R` uses missing sources and invalid target fields.
- Impact: `targets::tar_make()` cannot serve as the reproducibility backbone.
- Migration plan: Replace `_targets.R` with a minimal working `list(tar_target(...), ...)`, then add file-format targets only where needed.

**`calibrate` package usage:**
- Risk: `R/xg/calibration.R` imports `calibrate` and calls `calibrate()` on raw prediction vectors.
- Impact: Calibration can fail or return objects incompatible with the custom `predict()` wrapper if package semantics differ.
- Migration plan: Prefer explicit isotonic/logistic calibration using known packages already in the modeling stack, and test the returned calibration function.

**StatsBomb JSON structure assumptions:**
- Risk: `R/xg/features.R` expects nested data-frame columns from `jsonlite::fromJSON()`, while `R/integration/team_match_xg.R` expects flat lists from `fromJSON(..., simplifyVector = FALSE)`.
- Impact: A change in JSON loading mode or file shape can break one path while another still works.
- Migration plan: Add one parser layer that converts StatsBomb events into a canonical shot table used by xG training and team-match xG scoring.

## Missing Critical Features

**Fixture feature table for forecasting:**
- Problem: No production function builds a fixture-level table with pre-match Elo, rolling xG form, venue, and date-aware covariates.
- Blocks: Team-specific WCQ forecasts, leakage-free backtests, and meaningful Monte Carlo inputs.

**Real forecast backtesting:**
- Problem: Forecast probabilities are not generated historically and joined to actual W/D/L outcomes.
- Blocks: Valid Brier score, calibration, draw-rate validation, and model comparison.

**Executable data ingestion layer:**
- Problem: `_targets.R` references `R/data_ingest/martj42.R`, `R/data_ingest/statsbomb.R`, and `R/data_ingest/team_names.R`, but no `R/data_ingest/` directory exists.
- Blocks: End-to-end rebuild from raw sources.

**Package/renv manifest:**
- Problem: No `DESCRIPTION`, `renv.lock`, or central dependency manifest is detected in the scanned project root.
- Blocks: Reproducible installs for `targets`, `tidymodels`, `MASS`, `jsonlite`, `dplyr`, `lubridate`, `ggplot2`, `pROC`, `yardstick`, `igraph`, and `calibrate`.

## Test Coverage Gaps

**Pipeline execution:**
- What's not tested: A real `targets::tar_make()` run or even successful `_targets.R` sourcing.
- Files: `_targets.R`, `tests/testthat/test_pipeline.R:96`
- Risk: Pipeline regressions go unnoticed because tests inspect relative paths and file existence instead of executing the DAG.
- Priority: High

**Forecast correctness:**
- What's not tested: Team/date-specific feature lookup, NB/Poisson fallback behavior, probability calibration, and batch reproducibility.
- Files: `R/forecast/poisson.R`, `R/forecast/monte_carlo.R`, `R/forecast/calibration.R`
- Risk: Forecast outputs can be generated with generic placeholder inputs and synthetic validation.
- Priority: High

**Temporal leakage:**
- What's not tested: Rolling xG/Elo features use only matches before prediction date.
- Files: `R/integration/rolling_form.R`, `R/forecast/poisson.R`
- Risk: Backtests and model metrics overstate performance.
- Priority: High

**StatsBomb parsing and home/away mapping:**
- What's not tested: Event-file metadata parsing, match date, competition, home team, away team, and shot-team allocation.
- Files: `R/integration/team_match_xg.R`, `R/xg/data_prep.R`, `R/xg/features.R`
- Risk: xG metrics can be assigned to the wrong team or date.
- Priority: High

**Elo full computation:**
- What's not tested: `compute_elo()` and `compute_elo_optimized()` outputs on a known multi-match, multi-year fixture set.
- Files: `R/elo/runner.R`, `R/elo/runner_optimized.R`, `tests/testthat/test_elo.R`
- Risk: Decay, k-factor, mapping, and chronological updates can break without failing tests.
- Priority: Medium

**Visualization provenance:**
- What's not tested: AUC and calibration plots read real metric artifacts instead of constants or synthetic data.
- Files: `R/visualization/auc.R`, `R/visualization/calibration.R`
- Risk: Published charts can detach from model behavior.
- Priority: Medium

---

*Concerns audit: 2026-06-05*
