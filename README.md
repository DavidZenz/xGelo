# xGelo

Open-data football forecasting in R, combining Elo ratings with expected-goals
features to produce pre-match win/draw/loss probabilities for international
fixtures, with a focus on UEFA World Cup Qualifiers.

xGelo is built as a reproducible analytical pipeline rather than a packaged API.
It ingests open football data, computes historical Elo ratings, trains an xG
model from StatsBomb event data, fits negative-binomial goal models, and runs
Monte Carlo simulations for fixture forecasts.

## What It Does

- Builds team Elo histories from international match results.
- Trains an xG model from StatsBomb shot/event data.
- Aggregates team-match xG and lagged rolling-form features.
- Fits home and away negative-binomial goal models.
- Simulates fixtures to estimate win, draw, loss, and expected goals.
- Generates scoreline distributions, market-style summaries, and a static 2026
  World Cup dashboard with group, match, team, and bracket views.
- Simulates the 2026 World Cup group stage from sampled scorelines, then
  simulates knockout advancement from 90-minute goal-model outcomes plus an
  Elo tiebreak allocation for matches drawn after regulation.
- Produces validation outputs, calibration plots, and forecast CSV files.

The current pipeline is defined in [`_targets.R`](_targets.R). It includes a
small checked-in sample workflow suitable for development and validation.

## Model Shape

```text
martj42 international results        StatsBomb event data
              |                              |
              v                              v
        Elo ratings                    xG model
              |                              |
              +----------+-------------------+
                         v
          team-match xG and rolling form
                         |
                         v
        negative-binomial goal models
                         |
                         v
              Monte Carlo forecasts
```

The forecast layer uses negative-binomial goal simulation to allow overdispersed
football scores instead of assuming Poisson variance.

Current WC2026 dashboard forecasts use Elo, Transfermarkt player-pool strength,
and weighted historical goal ability as active goal-model predictors. The
shot-level xG model and rolling xG/form tables remain in the pipeline, but the
publication dashboard audits those candidate rolling predictors and leaves them
inactive when the available international rolling-form coverage is insufficient.

For the 2026 World Cup dashboard, group-stage and knockout-stage simulations are
related but not identical:

- Group-stage matches use 90-minute scoreline simulations directly. Each sampled
  score produces points, goals for, goals against, group ranks, and the best
  third-place qualifiers.
- Group ranking applies FIFA-style head-to-head tiebreakers within equal-point
  teams before falling back to overall goal difference, overall goals for, and a
  seeded residual tie-breaker. This matters for teams that can no longer pass a
  tied opponent because of the direct result, even if their overall goal
  difference could still improve.
- Group tables are ordered by projected rank from expected points, expected goal
  difference, and expected goals for. The modal finishing position is retained in
  the dashboard data as a diagnostic summary, but it is not used for the visible
  table order because it can disagree with expected points for close teams.
- Knockout matches first sample a 90-minute outcome from the same neutral
  goal-model route. If the 90-minute score is not drawn, that winner advances.
  If it is drawn, the drawn bucket is allocated through an Elo tiebreak share as
  a combined extra-time/penalty path.
- The dashboard bracket displays both the total two-outcome advancement
  probability and the projected winner route split, for example
  `Advance 75.4% = 90' win 59.0% + (90' draw 21.8% x ET/pens share 75.2% = 16.4%)`.
  It also shows the conditional tiebreak matchup, for example
  `If ET/pens: Germany 75.2% / Scotland 24.8%`.
- Bracket tooltips also include the projected knockout matchup's 90-minute
  scoring view: expected goals, rounded score, top exact scorelines, over 2.5,
  and both-teams-to-score probabilities. Drawn 90-minute scores remain possible
  in that scoring view even though knockout advancement itself has no draw
  outcome.

The current model does not yet split extra time and penalties into separate
sub-models; `ET/pens` is one combined tiebreak bucket.

The publication dashboard uses a fast numeric tournament simulator for the
100,000-tournament path. It pre-indexes group fixtures, parses bracket slots
once, and precomputes the two-team knockout advancement matrix before the Monte
Carlo loop. The simulation logic is the same as the object-oriented path, but
individual random draws are not bit-for-bit identical because knockout
advancement is sampled directly from the total advancement probability.

## Repository Layout

```text
R/
  elo/             Elo preprocessing, runners, tuning, validation
  xg/              Shot features, xG model training, backtests, calibration
  integration/     Team-match xG and rolling-form feature tables
  forecast/        Goal models, Monte Carlo simulation, forecast outputs
  pipeline/        Validation helpers and DAG visualization
  visualization/   AUC, calibration, and World Cup dashboard rendering
data/
  raw/             Source data caches
  processed/       Generated intermediate tables
models/            Trained model artifacts
outputs/
  forecasts/       Fixture forecast CSVs
  dashboard/       Static 2026 World Cup dashboard and source data exports
  visualizations/  Calibration and performance plots
  notebooks/       Rendered reporting artifacts
tests/testthat/    Unit and integration tests
```

## Requirements

- R 4.3.0 or newer
- A working compiler toolchain for R packages with compiled dependencies
- Git, if you want to refresh upstream open-data sources

Install the R package dependencies:

```r
install.packages(c(
  "targets",
  "tidyverse",
  "tidymodels",
  "jsonlite",
  "lubridate",
  "stringr",
  "MASS",
  "pROC",
  "yardstick",
  "ggplot2",
  "calibrate",
  "duckdb",
  "testthat",
  "knitr",
  "rmarkdown",
  "igraph",
  "visNetwork"
))
```

There is not currently a project-level `renv.lock` or package `DESCRIPTION`.
See [`SETUP.md`](SETUP.md) for longer environment notes.

`duckdb` is only required when the optional Transfermarkt feature block is
enabled. The default pipeline and checked-in validation path do not require a
Transfermarkt snapshot.

## Quick Start

From the repository root:

```r
source("_targets.R")
targets::tar_make()
```

Run the test suite:

```r
testthat::test_dir("tests/testthat")
```

Run only the pipeline validation target:

```r
source("_targets.R")
targets::tar_make(names = validation, callr_function = NULL)
```

Build the static 2026 World Cup dashboard:

```r
source("_targets.R")
targets::tar_make(names = worldcup_dashboard_file)
```

Prepare the GitHub Pages copy at `docs/wc2026/index.html`:

```r
source("_targets.R")
targets::tar_make(names = worldcup_pages_file)
```

Update the publication-scale hybrid dashboard from the current local processed
data and publish the GitHub Pages HTML in one command:

```bash
Rscript scripts/update_worldcup_dashboard.R
```

The script defaults to 100,000 match simulations, 100,000 tournament
simulations, four dashboard workers, the hybrid goal models,
`outputs/dashboard_100k/`, and
`docs/wc2026/index.html`. It does not download upstream data; refresh the
local targets first if new international results or Transfermarkt snapshots
should be included. Before and after building, it audits all 48 World Cup teams
against the local Elo, Transfermarkt player-pool, forecast-feature, and
dashboard outputs, while reporting raw Transfermarkt national-team table gaps
and xG/form predictor usage as diagnostics. For a quick smoke run:

```bash
XGELO_MATCH_SIMS=100 XGELO_TOURNAMENT_SIMS=100 XGELO_DASHBOARD_WORKERS=1 \
XGELO_OUTPUT_DIR=/tmp/xgelo-dashboard-smoke XGELO_PUBLISH=false \
Rscript scripts/update_worldcup_dashboard.R
```

The repository includes a GitHub Actions Pages workflow in
`.github/workflows/deploy-pages.yml`. After GitHub Pages is configured to use
**GitHub Actions** as its source, pushes to `master` deploy the contents of
`docs/`.

### Automatic Local Data Update

Use the local automation wrapper to check upstream martj42 data, rebuild the
hybrid WC2026 forecast when new rows are available, run tests, commit, and push:

```bash
scripts/auto_update_worldcup_dashboard.sh
```

The routine is local by design because the hybrid dashboard requires
`data/raw/transfermarkt/transfermarkt-datasets.duckdb`, which is intentionally
not committed. It refuses to run with existing tracked changes or when the local
branch is not aligned with its upstream remote.

Useful environment overrides:

```bash
XGELO_AUTO_PUSH=false scripts/auto_update_worldcup_dashboard.sh  # commit only
XGELO_AUTO_FORCE=true scripts/auto_update_worldcup_dashboard.sh  # rebuild even if martj42 did not change
XGELO_RUN_BENCHMARK=true scripts/auto_update_worldcup_dashboard.sh  # refresh frozen EURO 2024 validation too
XGELO_MATCH_SIMS=1000 XGELO_TOURNAMENT_SIMS=1000 scripts/auto_update_worldcup_dashboard.sh
```

For a daily local cron job at 09:30:

```cron
30 9 * * * cd /Users/davidzenz/R/xGelo && mkdir -p logs && scripts/auto_update_worldcup_dashboard.sh >> logs/auto-update.log 2>&1
```

For an hourly local watcher that checks immediately, then once per hour:

```bash
scripts/watch_worldcup_dashboard_updates.sh
```

The watcher writes the updater output to `logs/auto-update-loop.log` and keeps
running until stopped with `Ctrl-C`. It uses
`logs/dashboard-update-watcher.lock` to prevent duplicate local loops. Override
the polling interval when needed:

```bash
XGELO_UPDATE_INTERVAL_SECONDS=1800 scripts/watch_worldcup_dashboard_updates.sh
```

For a bounded smoke run:

```bash
XGELO_UPDATE_MAX_RUNS=1 scripts/watch_worldcup_dashboard_updates.sh
```

On macOS, use the LaunchAgent definition for a durable hourly local schedule:

```bash
mkdir -p ~/Library/LaunchAgents
cp scripts/com.xgelo.dashboard-update.plist ~/Library/LaunchAgents/
launchctl unload ~/Library/LaunchAgents/com.xgelo.dashboard-update.plist 2>/dev/null || true
launchctl load ~/Library/LaunchAgents/com.xgelo.dashboard-update.plist
```

The LaunchAgent runs once when loaded and then every hour. Its stdout/stderr go
to `logs/launchd-dashboard-update.out` and
`logs/launchd-dashboard-update.err`.

## Generate A Forecast

After the pipeline has produced `models/home_goal_model.rds`,
`models/away_goal_model.rds`, and `data/processed/elo_ratings.csv`, generate a
single fixture forecast:

```r
source("R/forecast/monte_carlo.R")
source("R/forecast/output.R")

result <- generate_forecast(
  home_team = "France",
  away_team = "England",
  date = as.Date("2026-06-12"),
  venue = "neutral",
  seed = 42
)

result$forecast
```

Generate multiple fixtures:

```r
fixtures <- data.frame(
  home_team = c("Spain", "Germany", "France"),
  away_team = c("Italy", "Netherlands", "England"),
  date = as.Date(c("2026-06-10", "2026-06-11", "2026-06-12")),
  venue = c("home", "home", "neutral"),
  stringsAsFactors = FALSE
)

generate_batch_forecasts(fixtures, seed = 42)
```

Forecast CSVs are written to `outputs/forecasts/`. Scoreline distributions are
written to `outputs/forecasts/scorelines/`.

## World Cup Dashboard

The dashboard at `outputs/dashboard/worldcup_forecast.html` is a static,
self-contained forecast view for the 2026 World Cup. It uses the seeded group
data in `data/raw/worldcup_2026_groups.csv` and the schedule-backed group-stage
fixtures in `data/raw/worldcup_2026_group_fixtures.csv`.

For GitHub Pages, the dashboard is published under its own route rather than at
the xGelo site root. The Pages copy is written to `docs/wc2026/index.html`, so
with the Pages workflow enabled it is available at
`https://davidzenz.github.io/xGelo/wc2026/` after deployment. The
`docs/.nojekyll` marker keeps GitHub Pages from applying Jekyll processing to
the generated static HTML.

Dashboard views include:

- Group cards with a Forecast/Current toggle. The forecast table shows expected
  points, finish-position probabilities, Round-of-32 qualification, and
  best-third probabilities. The current table shows points plus `Played`,
  `Wins`, `Draws`, `Losses`, `Goals For`, `Goals Against`, and `Goal Diff`.
  Points/xPts and goal difference use compact heat cells for scanning.
- Round-of-32 status markers next to the points/xPts column. A blue check marks
  teams already qualified for the Round of 32, and a muted x marks teams with no
  remaining Round-of-32 route under the current simulation and FIFA head-to-head
  group tiebreak rules.
- Match cards with win/draw/loss probabilities, projected goals, modal
  scorelines, over 2.5, and both-teams-to-score probabilities.
- A connected bracket tree that projects the most likely path from Round of 32
  through champion, with two-outcome advancement probabilities, connector paths,
  projected winner route splits, 90-minute scoring summaries, and title
  probabilities reflected in each round.
- Team pages showing stage probabilities and group fixtures.
- An Elo ratings table with current rating rank, rating bar, and Round of 32,
  Round of 16, quarter-final, semi-final, final, and title probabilities. The
  probability cells use column-scaled heat coloring so the darkest cell in each
  probability column marks the highest value in that column.

The bracket is a presentation path estimate derived from full tournament
simulations. Knockout games do not allow draws: each matchup advances one team
through either a 90-minute win or the combined ET/pens tiebreak bucket. The
dashboard does not model injuries, lineups, or live state.

The dashboard tournament simulation can run in deterministic parallel chunks on
Unix-like systems by passing `n_workers` to `build_worldcup_dashboard()` or by
setting `options(xgelo.dashboard_workers = N)`. Each tournament draw receives
its own seed, so a seeded run is reproducible across serial and parallel worker
counts. When no option is set, dashboard builds use up to four local workers.
Hybrid dashboard builds reuse loaded model objects, vectorize group-fixture
goal predictions, and derive knockout routes from analytic score grids by
default (`route_method = "analytic"`). For the publication-scale dashboard,
the group-stage tournament loop also uses pre-indexed numeric fixtures,
numeric head-to-head ranking, parsed bracket slots, and a precomputed
knockout advancement matrix so 100,000 match simulations and 100,000 full
tournament simulations are practical locally. The older route Monte Carlo
remains available with `route_method = "simulation"`. Knockout route estimates
are cached lazily by matchup; all-pair route precomputation is available with
`precompute_knockout_routes = TRUE`, but it is opt-in because a 48-team
ordered-pair cache is expensive for quick smoke runs.
Windows falls back to serial execution.

For publication updates, use `Rscript scripts/update_worldcup_dashboard.R`.
Environment variables supported by that script include `XGELO_MATCH_SIMS`,
`XGELO_TOURNAMENT_SIMS`, `XGELO_DASHBOARD_WORKERS`, `XGELO_OUTPUT_DIR`,
`XGELO_PAGES_DIR`, `XGELO_PUBLISH`, `XGELO_BASELINE_COMPARISON`,
`XGELO_FEATURE_CUTOFF_DATE`, `XGELO_ROUTE_METHOD`, and
`XGELO_TRANSFERMARKT_SNAPSHOT`.

## Key Outputs

- `data/processed/elo_ratings.csv`: historical team Elo ratings
- `data/processed/elo_current.csv`: latest team Elo ratings
- `data/processed/team_match_xg.csv`: team-level xG by match
- `data/processed/rolling_form.csv`: lagged rolling-form features
- `data/processed/xg_feature_usage_audit.csv`: candidate xG/form predictor
  coverage and fitted-model usage diagnostic
- `models/xg_model.rds`: trained shot-level xG model
- `models/home_goal_model.rds`: home-goal negative-binomial model
- `models/away_goal_model.rds`: away-goal negative-binomial model
- `outputs/forecasts/*.csv`: forecast probabilities and expected goals
- `outputs/forecasts/scorelines/*.csv`: scoreline distributions by fixture
- `outputs/dashboard/worldcup_forecast.html`: static World Cup dashboard
- `outputs/dashboard/worldcup_dashboard_data.json`: dashboard source payload
- `outputs/dashboard/worldcup_*_probabilities.csv`: dashboard probability exports
- `outputs/dashboard/worldcup_current_group_tables.csv`: current group tables
  from completed fixtures
- `outputs/dashboard_100k/`: publication-scale dashboard artifacts before they
  are synced into `outputs/dashboard/`
- `outputs/benchmarks/euro2024/euro2024_metrics.csv`: frozen EURO 2024
  baseline-vs-hybrid benchmark metrics
- `outputs/benchmarks/euro2024/euro2024_predictions.csv`: match-grain EURO 2024
  benchmark probabilities
- `docs/wc2026/index.html`: GitHub Pages copy of the World Cup dashboard
- `outputs/visualizations/*.png`: AUC and calibration plots
- `outputs/notebooks/model_performance.html`: rendered model report

## Data Sources And Usage

xGelo uses open or locally cached data sources:

- [martj42/international_results](https://github.com/martj42/international_results)
  for historical men's full international match results, including
  `results.csv`, `shootouts.csv`, and `goalscorers.csv`.
- [StatsBomb Open Data](https://github.com/statsbomb/open-data) for
  event-level shot data used to train the xG model.
- Local team-name mappings in `data/raw/team_name_map.csv`.
- Manually maintained 2026 World Cup group seeds and fixture schedule in
  `data/raw/worldcup_2026_groups.csv` and
  `data/raw/worldcup_2026_group_fixtures.csv`.
- Optional local
  [dcaribou/transfermarkt-datasets](https://github.com/dcaribou/transfermarkt-datasets)
  DuckDB snapshot for player-pool valuation features. Put it at
  `data/raw/transfermarkt/transfermarkt-datasets.duckdb`; raw snapshots are not
  committed. The optional feature block uses dated player valuations to derive
  player-pool value, top-11/top-15/top-23 value, positional depth, value shares,
  depth concentration, age profile, and 6-/12-month valuation momentum.

Please credit those upstream projects when using or publishing outputs derived
from this repository. StatsBomb Open Data is licensed under Creative Commons
Attribution-NonCommercial-ShareAlike 4.0. Check upstream source licenses before
redistributing data or using the project commercially.

The project intentionally avoids automated scraping of restricted sources. If
manually cached World Cup Qualifier data is used, keep it local and do not
redistribute it unless the upstream terms allow that use.

Transfermarkt-derived features are strictly as-of-date: valuation and squad
feature source dates must be before the match or benchmark cutoff date. Same-day
records are treated as unavailable. Current player profile fields such as
current club, current national team, current market value, and current caps are
not valid for historical benchmarks unless they are reconstructed from dated
records.

See [`DATA-INVENTORY.md`](DATA-INVENTORY.md) for source-level details.

## Validation

Recommended checks before trusting a forecast run:

```r
testthat::test_dir("tests/testthat")

source("_targets.R")
targets::tar_make(names = validation, callr_function = NULL)
```

The test suite covers xG feature calculations, Elo counters, leakage-sensitive
rolling-form behavior, forecast simulation sanity checks, calibration grouping,
pipeline validation helpers, World Cup fixture contracts, dashboard exports, and
bracket projection contracts, including FIFA head-to-head group tiebreaks and
knockout route probabilities that sum to one winner per matchup.

## Important Caveats

- Forecasts are pre-match model outputs, not betting advice.
- The model does not currently account for confirmed lineups, injuries,
  suspensions, travel disruption, or in-play match state.
- Transfermarkt player-pool features are optional and default-off. The EURO 2024
  benchmark reports whether the hybrid feature set improves match-level Brier
  score, log loss, ranked probability score, and calibration versus the baseline
  path.
- xG training is domestic-only to reduce target leakage into international
  forecasts. The checked-in development pipeline uses an explicit sample
  override for the included StatsBomb data.
- Rolling xG/form candidate features are currently audited but inactive in the
  WC2026 dashboard unless coverage and fitted-model retention justify using
  them.
- Model quality depends on the freshness and coverage of the local data cache.
- No project-level software license file is currently included; data sources
  retain their own licenses.

## Further Reading

- [`SETUP.md`](SETUP.md): installation and first-run setup
- [`RUNBOOK.md`](RUNBOOK.md): operational commands and troubleshooting
- [`MODEL-CARD.md`](MODEL-CARD.md): intended use, model assumptions, metrics
- [`DATA-INVENTORY.md`](DATA-INVENTORY.md): data sources, coverage, and licenses
- [`.planning/research/SPI_MODEL_EVOLUTION.md`](.planning/research/SPI_MODEL_EVOLUTION.md):
  notes on how professional forecasting systems such as SPI can inform future
  model evolution
- [`open_data_elo_xg_wcq_research_memo.md`](open_data_elo_xg_wcq_research_memo.md):
  research background and design rationale
