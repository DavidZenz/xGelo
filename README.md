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
  "testthat",
  "knitr",
  "rmarkdown",
  "igraph",
  "visNetwork"
))
```

There is not currently a project-level `renv.lock` or package `DESCRIPTION`.
See [`SETUP.md`](SETUP.md) for longer environment notes.

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

Dashboard views include:

- Group tables with expected points and qualification probabilities.
- Match cards with win/draw/loss probabilities, projected goals, modal
  scorelines, over 2.5, and both-teams-to-score probabilities.
- A connected bracket tree that projects the most likely path from Round of 32
  through champion, with winner and title probabilities reflected in each round.
- Team pages showing stage probabilities and group fixtures.

The bracket is a presentation path estimate. It does not model extra time,
penalties, injuries, lineups, or live state.

## Key Outputs

- `data/processed/elo_ratings.csv`: historical team Elo ratings
- `data/processed/elo_current.csv`: latest team Elo ratings
- `data/processed/team_match_xg.csv`: team-level xG by match
- `data/processed/rolling_form.csv`: lagged rolling-form features
- `models/xg_model.rds`: trained shot-level xG model
- `models/home_goal_model.rds`: home-goal negative-binomial model
- `models/away_goal_model.rds`: away-goal negative-binomial model
- `outputs/forecasts/*.csv`: forecast probabilities and expected goals
- `outputs/forecasts/scorelines/*.csv`: scoreline distributions by fixture
- `outputs/dashboard/worldcup_forecast.html`: static World Cup dashboard
- `outputs/dashboard/worldcup_dashboard_data.json`: dashboard source payload
- `outputs/dashboard/worldcup_*_probabilities.csv`: dashboard probability exports
- `outputs/visualizations/*.png`: AUC and calibration plots
- `outputs/notebooks/model_performance.html`: rendered model report

## Data Sources And Usage

xGelo uses open or locally cached data sources:

- martj42 international football results for historical international matches.
- StatsBomb Open Data for event-level shot data used to train the xG model.
- Local team-name mappings in `data/raw/team_name_map.csv`.
- Manually maintained 2026 World Cup group seeds and fixture schedule in
  `data/raw/worldcup_2026_groups.csv` and
  `data/raw/worldcup_2026_group_fixtures.csv`.

StatsBomb Open Data is licensed under Creative Commons
Attribution-NonCommercial-ShareAlike 4.0. Check upstream source licenses before
redistributing data or using the project commercially.

The project intentionally avoids automated scraping of restricted sources. If
manually cached World Cup Qualifier data is used, keep it local and do not
redistribute it unless the upstream terms allow that use.

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
bracket projection contracts.

## Important Caveats

- Forecasts are pre-match model outputs, not betting advice.
- The model does not currently account for confirmed lineups, injuries,
  suspensions, travel disruption, or in-play match state.
- xG training is domestic-only to reduce target leakage into international
  forecasts. The checked-in development pipeline uses an explicit sample
  override for the included StatsBomb data.
- Model quality depends on the freshness and coverage of the local data cache.
- No project-level software license file is currently included; data sources
  retain their own licenses.

## Further Reading

- [`SETUP.md`](SETUP.md): installation and first-run setup
- [`RUNBOOK.md`](RUNBOOK.md): operational commands and troubleshooting
- [`MODEL-CARD.md`](MODEL-CARD.md): intended use, model assumptions, metrics
- [`DATA-INVENTORY.md`](DATA-INVENTORY.md): data sources, coverage, and licenses
- [`open_data_elo_xg_wcq_research_memo.md`](open_data_elo_xg_wcq_research_memo.md):
  research background and design rationale
