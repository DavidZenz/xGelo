# Phase 09: Rolling Tournament Benchmark Harness - Pattern Map

**Mapped:** 2026-07-20
**Files analyzed:** 33 authored new/modified files
**Analogs found:** 31 / 33

## Scope Interpretation

The file list below combines the explicit recommended structure in `09-RESEARCH.md`, the additional `boundaries.csv`, seal test, helper, and source-notes requirements in the schema/validation sections, and the two existing files explicitly identified for modification (`R/evaluation/proper_scores.R` and `_targets.R`). Runtime files under `outputs/benchmarks/rolling_tournaments/<run_id>/` are generated artifacts, not hand-authored source files, and are mapped separately below.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `R/benchmark/registry.R` | service / registry | file-I/O, transform | `R/evaluation/worldcup_ledger.R` | exact |
| `R/benchmark/cutoffs.R` | service | batch, transform | `R/forecast/features.R` | exact |
| `R/benchmark/weights.R` | utility | transform | `R/forecast/goal_ability.R` | exact |
| `R/benchmark/contracts.R` | utility / validator | transform | `R/evaluation/proper_scores.R` | exact |
| `R/benchmark/baselines.R` | service / adapter | batch, request-response | `R/benchmark/euro2024.R` | role-match |
| `R/benchmark/runner.R` | service / orchestrator | batch, file-I/O | `R/evaluation/worldcup_ledger.R` | exact |
| `R/evaluation/proper_scores.R` | utility (modified) | transform | existing file itself | exact |
| `R/evaluation/benchmark_scores.R` | service | batch, transform | `R/evaluation/worldcup_retrospective.R` | exact |
| `R/evaluation/promotion.R` | service / policy | transform | `R/evaluation/worldcup_retrospective.R` | role-match |
| `R/forecast/tournament_formats.R` | service / adapter | event-driven, batch | `R/benchmark/euro2024_tournament.R` | exact |
| `_targets.R` | config / pipeline | event-driven, file-I/O | existing Phase 8 targets at `_targets.R` | exact |
| `data/benchmark/phase09/tournaments.csv` | config / registry | file-I/O | fixture registry contract in `R/evaluation/worldcup_ledger.R` | role-match |
| `data/benchmark/phase09/fixtures.csv` | model / registry | file-I/O | fixture registry contract in `R/evaluation/worldcup_ledger.R` | exact |
| `data/benchmark/phase09/teams.csv` | model / registry | file-I/O | canonical identity validation in `R/evaluation/worldcup_ledger.R` | role-match |
| `data/benchmark/phase09/formats.csv` | config / registry | file-I/O | `euro2024_groups()` in `R/benchmark/euro2024_tournament.R` | role-match |
| `data/benchmark/phase09/route_rules.csv` | config / registry | file-I/O, event-driven | `euro_third_place_pairing_table()` in `R/benchmark/euro2024_tournament.R` | exact |
| `data/benchmark/phase09/panels.csv` | config / registry | file-I/O | strict/exploratory registry fields in `R/evaluation/worldcup_ledger.R` | role-match |
| `data/benchmark/phase09/panel_fixtures.csv` | model / coverage | file-I/O | coverage table in `R/evaluation/worldcup_ledger.R` | exact |
| `data/benchmark/phase09/model_registry.csv` | config / registry | file-I/O | model bundle metadata in `R/benchmark/euro2024_tournament.R` | role-match |
| `data/benchmark/phase09/feature_contract.csv` | config / registry | file-I/O | source coverage contract in `R/forecast/features.R` | exact |
| `data/benchmark/phase09/seed_registry.csv` | config / registry | file-I/O | deterministic seed setup in `R/evaluation/worldcup_retrospective.R` | role-match |
| `data/benchmark/phase09/boundaries.csv` | model / state registry | batch, file-I/O | strict cutoff representation in `R/forecast/features.R` | exact |
| `data/benchmark/phase09/promotion_protocol.json` | config / policy | file-I/O | none; use frozen schema from `09-RESEARCH.md` | none |
| `data/benchmark/phase09/SOURCES.md` | config / provenance | file-I/O | none; project has no equivalent curated source ledger | none |
| `tests/testthat/helper_benchmark.R` | test utility | batch, transform | synthetic fixture helper in `tests/testthat/test_worldcup_scoring.R` | exact |
| `tests/testthat/test_benchmark_registry.R` | test | file-I/O, transform | `tests/testthat/test_worldcup_scoring.R` and `test_worldcup_retrospective.R` | role-match |
| `tests/testthat/test_benchmark_cutoffs.R` | test | batch, transform | `tests/testthat/test_transfermarkt_benchmark.R` | exact |
| `tests/testthat/test_benchmark_seal.R` | test / security | request-response, transform | fail-fast contract tests in `tests/testthat/test_worldcup_scoring.R` | role-match |
| `tests/testthat/test_benchmark_contracts.R` | test | transform | `tests/testthat/test_worldcup_scoring.R` | exact |
| `tests/testthat/test_benchmark_baselines.R` | test | batch | `tests/testthat/test_transfermarkt_benchmark.R` | exact |
| `tests/testthat/test_benchmark_scoring.R` | test | batch, transform | `tests/testthat/test_worldcup_scoring.R` | exact |
| `tests/testthat/test_benchmark_promotion.R` | test | transform | deterministic/paired tests in `tests/testthat/test_worldcup_scoring.R` | role-match |
| `tests/testthat/test_benchmark_pipeline.R` | test | event-driven, file-I/O | `tests/testthat/test_worldcup_retrospective.R` | exact |

## Pattern Assignments

### `R/benchmark/registry.R` (service/registry, file-I/O + transform)

**Primary analog:** `R/evaluation/worldcup_ledger.R`

**Fail-fast schema and cardinality pattern** (lines 136-168):

```r
validate_fixture_registry <- function(fixtures, expected_matches = 104L) {
  required <- c(
    "match_id", "stage", "home_team", "away_team", "kickoff_utc",
    "actual_home_goals", "actual_away_goals", "actual_winner_team",
    "result_event_id", "result_source_path"
  )
  missing <- setdiff(required, names(fixtures))
  if (length(missing)) stop("Fixture registry missing columns: ", paste(missing, collapse = ", "))
  if (nrow(fixtures) != expected_matches) {
    stop("Fixture registry must contain exactly ", expected_matches, " matches; found ", nrow(fixtures))
  }
  if (anyDuplicated(fixtures$match_id)) stop("Fixture registry match_id values must be unique")
  if (any(is.na(fixtures$actual_home_goals) | is.na(fixtures$actual_away_goals))) {
    stop("Fixture registry contains missing regulation scores")
  }
  invisible(fixtures)
}
```

Copy the structure, not the WC2026 column names. Add separate loaders/validators for tournaments, fixtures, teams, formats, routes, panels, models, features, seeds, and boundaries. Validate exactly 12 editions and 630 fixtures, stable IDs, cross-registry foreign keys, score/status consistency, and canonical sorted hashes.

**Deterministic ordering pattern** (lines 247-253):

```r
fixtures$home_key <- normalize_worldcup_team_key(fixtures$home_team)
fixtures$away_key <- normalize_worldcup_team_key(fixtures$away_team)
fixtures <- fixtures[order(parse_utc_time(fixtures$kickoff_utc), fixtures$match_id), , drop = FALSE]
rownames(fixtures) <- NULL
validate_fixture_registry(fixtures)
fixtures
```

Phase 09 must replace ad hoc display-name normalization with checked `team_id`/FIFA-code joins from `teams.csv`.

---

### Registry assets under `data/benchmark/phase09/` (models/config, file-I/O)

**Files:**

- `tournaments.csv`
- `fixtures.csv`
- `teams.csv`
- `formats.csv`
- `route_rules.csv`
- `panels.csv`
- `panel_fixtures.csv`
- `model_registry.csv`
- `feature_contract.csv`
- `seed_registry.csv`
- `boundaries.csv`

**Primary analogs:** `R/evaluation/worldcup_ledger.R` for validated immutable registries; `R/benchmark/euro2024_tournament.R` for routing tables.

**Explicit tabular route-rule pattern** (`R/benchmark/euro2024_tournament.R`, lines 19-29):

```r
euro_third_place_pairing_table <- function() {
  data.frame(
    combo = c("ABCD", "ABCE", "ABCF", "ABDE", "ABDF", "ABEF", "ACDE", "ACDF", "ACEF", "ADEF", "BCDE", "BCDF", "BCEF", "BDEF", "CDEF"),
    vs_1B = c("A", "A", "A", "D", "D", "E", "E", "F", "E", "E", "E", "F", "F", "F", "F"),
    vs_1C = c("D", "E", "F", "E", "F", "F", "D", "D", "F", "F", "D", "D", "E", "E", "E"),
    vs_1E = c("B", "B", "B", "A", "A", "B", "C", "C", "C", "D", "B", "C", "C", "D", "D"),
    vs_1F = c("C", "C", "C", "B", "B", "A", "A", "A", "A", "A", "C", "B", "B", "B", "C"),
    stringsAsFactors = FALSE
  )
}
```

Move this style of route data into CSV registries. Every CSV should have `schema_version`; use stable IDs and explicit source/hash/license columns. `fixtures.csv` stores regulation, extra-time/final, and shootout outcomes separately. `boundaries.csv` is derived deterministically but frozen and checked. `panel_fixtures.csv` records both eligible and ineligible rows with reasons rather than silently filtering.

---

### `R/benchmark/cutoffs.R` (service, batch + transform)

**Primary analog:** `R/forecast/features.R`

**Strict latest-before lookup** (lines 95-112):

```r
latest_team_value_before <- function(data, team, lookup_date, value_col,
                                     team_col = "team", date_col = "date", default = NA_real_) {
  if (is.null(data) || nrow(data) == 0 || !all(c(team_col, date_col, value_col) %in% names(data))) return(default)
  data[[date_col]] <- as.Date(data[[date_col]])
  rows <- data[
    data[[team_col]] == team &
      !is.na(data[[date_col]]) &
      data[[date_col]] < as.Date(lookup_date) &
      !is.na(data[[value_col]]),
    , drop = FALSE
  ]
  if (nrow(rows) == 0) return(default)
  rows <- rows[order(rows[[date_col]]), , drop = FALSE]
  tail(rows[[value_col]], 1)
}
```

**Leakage assertion pattern** (lines 423-443):

```r
assert_no_feature_leakage <- function(feature_table, cutoff_date = NULL) {
  if (!all(c("date", "feature_source_date") %in% names(feature_table))) {
    stop("Feature table must contain date and feature_source_date")
  }
  feature_table$date <- as.Date(feature_table$date)
  feature_table$feature_source_date <- as.Date(feature_table$feature_source_date)
  bad_rows <- which(feature_table$feature_source_date >= feature_table$date)
  if (length(bad_rows) > 0) {
    stop(paste("Feature leakage detected in rows:", paste(head(bad_rows, 10), collapse = ", ")))
  }
  invisible(TRUE)
}
```

Build both tracks as date-complete batches: all fixtures on assessment date `d` share one state, and results from `d` become available only after that batch. The invariant is strict `< evidence_cutoff_exclusive`; no timestamp should be fabricated where source precision is only a date. Put the WC2026 denylist/purpose gate before any adapter call.

---

### `R/benchmark/weights.R` (utility, transform)

**Primary analog:** `R/forecast/goal_ability.R`

**Registered importance and recency pattern** (lines 6-15 and 60-67):

```r
tournament_importance_weight <- function(tournament) {
  tournament <- ifelse(is.na(tournament), "", tournament)
  tournament_lower <- tolower(tournament)
  weight <- rep(1, length(tournament_lower))
  weight[grepl("world cup|uefa euro|copa america|african cup|asian cup", tournament_lower)] <- 1.8
  weight[grepl("qualifier|qualification|nations league", tournament_lower)] <- 1.3
  weight[grepl("friendly", tournament_lower)] <- 0.6
  weight
}

age_days <- as.numeric(cutoff_date - prior$date)
recency_weight <- exp(-log(2) * age_days / half_life_days)
tournament_weight <- tournament_importance_weight(prior$tournament)
match_weight <- recency_weight * tournament_weight
```

Expose one registered schedule function with the 730-day half-life and 1.8/1.3/0.6 tiers. Normalize supervised `observation_weight` to mean 1 within each snapshot. Elo must explicitly report `not_applied`; do not feed these weights into Elo recursion.

---

### `R/benchmark/contracts.R` and `R/evaluation/proper_scores.R` (validators/utilities, transform)

**Primary analog:** `R/evaluation/proper_scores.R`

**Probability validation pattern** (lines 3-15):

```r
validate_probability_vector <- function(probabilities, tolerance = 1e-6, name = "probabilities") {
  probabilities <- as.numeric(probabilities)
  if (!length(probabilities) || any(!is.finite(probabilities))) {
    stop(name, " must contain finite values", call. = FALSE)
  }
  if (any(probabilities < 0 | probabilities > 1)) {
    stop(name, " must lie in [0, 1]", call. = FALSE)
  }
  if (abs(sum(probabilities) - 1) > tolerance) {
    stop(name, " must sum to one within tolerance", call. = FALSE)
  }
  probabilities
}
```

**Joint-distribution validation and derivation** (lines 101-133):

```r
validate_scoreline_distribution <- function(distribution, tolerance = 1e-6) {
  required <- c("home_goals", "away_goals", "probability")
  missing <- setdiff(required, names(distribution))
  if (length(missing)) stop("scoreline distribution missing: ", paste(missing, collapse = ", "), call. = FALSE)
  if (!nrow(distribution)) stop("scoreline distribution must not be empty", call. = FALSE)
  keys <- paste(distribution$home_goals, distribution$away_goals, sep = "-")
  if (anyDuplicated(keys)) stop("scoreline distribution contains duplicate cells", call. = FALSE)
  distribution$probability <- validate_probability_vector(
    distribution$probability, tolerance, "scoreline probabilities"
  )
  distribution
}

derive_binary_markets <- function(distribution, tolerance = 1e-6) {
  distribution <- validate_scoreline_distribution(distribution, tolerance)
  # derive marginals, totals, and BTTS from the single joint distribution
}
```

Keep metric formulas in `proper_scores.R`; put common schema/manifests/coverage/seed validators in `contracts.R`. Extend score-grid validation to require every cell in `0:G x 0:G`, shared support, finite values, tail mass at or below `1e-10`, and reconciliation of adapter-supplied markets to distribution-derived values within `1e-10`. Contract failures use `stop(..., call. = FALSE)` and never silently drop rows.

---

### `R/benchmark/baselines.R` (service/adapters, batch)

**Primary analog:** `R/benchmark/euro2024.R`

**Model preparation and shared prediction-row pattern** (lines 173-228):

```r
training <- matches[
  matches$date < cutoff_date &
    !is.na(matches$home_score) &
    !is.na(matches$away_score) &
    !is.na(matches$home_team_canonical) &
    !is.na(matches$away_team_canonical),
  , drop = FALSE
]
if (any(training$date >= cutoff_date, na.rm = TRUE)) stop("Benchmark training leakage detected")

baseline_train <- build_forecast_feature_table(training, elo, rolling_form = rolling)
baseline_holdout <- build_forecast_feature_table(holdout, elo, rolling_form = rolling, cutoff_date = cutoff_date)
assert_no_feature_leakage(baseline_holdout, cutoff_date = cutoff_date)

baseline_home <- train_goal_model_from_features(baseline_train, "home", predictors = baseline_predictors)
baseline_away <- train_goal_model_from_features(baseline_train, "away", predictors = baseline_predictors)

make_predictions <- function(model_name, features, probabilities) {
  data.frame(
    model = model_name,
    date = features$date,
    home_team = features$home_team,
    away_team = features$away_team,
    probabilities,
    feature_source_date = features$feature_source_date,
    stringsAsFactors = FALSE
  )
}
```

Implement five thin adapters—uniform, expanding historical base rate, Elo goal model, open NB, rich NB—behind one API. Adapters receive a validated snapshot, fixture rows, model registration, and seed IDs; they return score grids plus manifests/coverage. Shared code derives every market. Do not copy the legacy zero-fill at lines 106-110, silent Poisson fallback behavior, model-specific schemas, or `hybrid_pass` at lines 231-238.

**Analytic score-grid pattern to retain and harden** (lines 122-138):

```r
goals <- 0:max_goals
hp <- if (is.infinite(home_theta)) stats::dpois(goals, home_lambda[i]) else
  stats::dnbinom(goals, size = home_theta, mu = home_lambda[i])
ap <- if (is.infinite(away_theta)) stats::dpois(goals, away_lambda[i]) else
  stats::dnbinom(goals, size = away_theta, mu = away_lambda[i])
grid <- outer(hp, ap)
grid <- grid / sum(grid)
```

Before normalization, calculate and validate raw tail mass. Store the full long rectangular grid, including zero-probability cells.

---

### `R/forecast/tournament_formats.R` (service/format adapters, event-driven + batch)

**Primary analog:** `R/benchmark/euro2024_tournament.R`

**Precompute-then-simulate pattern** (lines 127-143 and 209-245):

```r
pairs <- expand.grid(home_team = teams, away_team = teams, stringsAsFactors = FALSE)
pairs <- pairs[pairs$home_team != pairs$away_team, , drop = FALSE]

forecast_cache <- new.env(parent = emptyenv())
for (i in seq_len(nrow(rows))) {
  key <- paste(rows$home_team[i], rows$away_team[i], rows$venue[i], sep = "||")
  assign(key, as.list(rows[i, , drop = FALSE]), envir = forecast_cache)
}
predict_fixture <- function(home_team, away_team, venue) {
  key <- paste(home_team, away_team, venue, sep = "||")
  if (!exists(key, envir = forecast_cache, inherits = FALSE)) {
    stop(paste("No precomputed forecast for", home_team, "vs", away_team, venue))
  }
  get(key, envir = forecast_cache, inherits = FALSE)
}
```

Create registry-selected adapters for the three locked format families. Route from `formats.csv`/`route_rules.csv`, not hard-coded teams or edition names. Preserve explicit group standings, knockout routing, and stage accumulation, but consume the same precomputed score distributions and random-number ledger for every model.

**Stage accumulation pattern** (lines 467-505):

```r
set.seed(seed)
for (i in seq_len(n_sim)) {
  sim <- simulate_one_euro2024_tournament_cached(model_bundle, sim_match)
  stage_cols <- c("ro16", "quarterfinal", "semifinal", "final", "champion")
  counts[sim$team, stage_cols] <- counts[sim$team, stage_cols] + sim[sim$team, stage_cols]
}
counts[, stage_cols] <- counts[, stage_cols] / n_sim
```

Do not copy model-specific seed offsets (legacy lines 496-499). Seed IDs must be model-independent for common random numbers.

---

### `R/evaluation/benchmark_scores.R` (service, batch + transform)

**Primary analog:** `R/evaluation/worldcup_retrospective.R`

**Long metric-row pattern** (lines 3-19 and 59-83):

```r
metric_row <- function(forecast, metric, value, target = "regulation_1x2") {
  data.frame(
    match_id = forecast$match_id,
    target = target,
    metric = metric,
    value = as.numeric(value),
    stringsAsFactors = FALSE
  )
}

add("rps", ranked_probability_score(probabilities, observed))
add("brier", multiclass_brier(probabilities, observed))
add("log_loss", log_score(probabilities, observed))
add("over_2_5_brier", binary_brier(forecast$p_over_2_5, actual_over), "over_2_5")
add("btts_brier", binary_brier(forecast$p_btts, actual_btts), "btts")
```

Add Phase 09 keys (`run_id`, `model_id`, `panel_id`, `edition_id`, `track`, `fixture_id`) and coverage eligibility to every row. Score fixtures once, aggregate each tournament second, then average the 12 tournament estimates equally for headline results. Keep fixture-weighted pooling as a separately labeled secondary aggregation.

**Deterministic bootstrap mechanics** (lines 118-145):

```r
bootstrap_mean <- function(values, reps, conf) {
  values <- values[is.finite(values)]
  if (!length(values)) return(c(lower = NA_real_, upper = NA_real_))
  draws <- replicate(reps, mean(sample(values, length(values), replace = TRUE)))
  alpha <- (1 - conf) / 2
  stats::quantile(draws, c(alpha, 1 - alpha), names = FALSE, type = 8)
}

set.seed(seed)
```

For Phase 09, bootstrap the 12 paired tournament deltas, not fixtures. Use fixed calibration bins declared before model scoring; do not copy model-specific quantile bins.

---

### `R/evaluation/promotion.R` (service/pure policy, transform)

**Primary analog:** paired comparison construction in `R/evaluation/worldcup_retrospective.R`, lines 236-256.

```r
paired <- merge(
  first_scores[, c("sample", "target", "metric", "match_id", "value")],
  latest_scores[, c("sample", "target", "metric", "match_id", "value")],
  by = c("sample", "target", "metric", "match_id"),
  suffixes = c("_first", "_latest")
)
paired$value <- paired$value_latest - paired$value_first
```

Adapt this to challenger-minus-incumbent rows on identical fixture IDs, then reduce to one delta per tournament before uncertainty. Implement promotion as a pure function over validated summaries and contract flags. Return every gate value/boolean plus ordered `veto_reasons`; do not write files or inspect global state inside the decision function. Apply gates in the frozen order: contracts/coverage, practical RPS delta and CI, fold/competition breadth and max regression, supporting-score vetoes, optional rich-panel gate, final decision.

The legacy EURO gate (`R/benchmark/euro2024.R`, lines 231-238) is an anti-pattern for Phase 09 because it has no paired interval, breadth checks, or full contract vetoes.

---

### `R/benchmark/runner.R` (service/orchestrator, batch + file-I/O)

**Primary analog:** `R/evaluation/worldcup_ledger.R`

**Explicit-path cache-only entry point and bundle pattern** (lines 666-731):

```r
write_forecast_ledger_bundle <- function(
    source_ref = "HEAD",
    output_dir = "outputs/evaluation/wc2026",
    repo = ".",
    max_commits = Inf
) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  fixtures <- build_worldcup_2026_fixture_registry()
  # build, classify, validate, then write artifacts
  write.csv(fixtures, paths["fixtures"], row.names = FALSE)
  saveRDS(distributions, paths["distributions"])
  source_sha <- run_git_read(c("rev-parse", source_ref), repo = repo)[1]
  write_checksum_manifest(unname(paths), source_ref, source_sha, manifest_path)
  list(paths = c(paths, manifest = manifest_path), fixtures = fixtures)
}
```

Expose `run_rolling_tournament_benchmark()` with explicit registry/input/output paths, protocol version, seed registry, and cache-only behavior. Validate before and after each adapter, reconcile fixture/model/panel coverage before writing, and isolate runtime timestamps from content hashes. Use CSV for auditable rows and RDS only for fitted objects/compact internal bundles.

**Current checksum-manifest shape** (lines 652-663):

```r
manifest <- data.frame(
  path = existing,
  bytes = as.numeric(file.info(existing)$size),
  md5 = unname(tools::md5sum(existing)),
  source_ref = source_ref,
  source_sha = source_sha,
  stringsAsFactors = FALSE
)
```

Copy the manifest workflow but upgrade Phase 09 artifact integrity to canonical SHA-256 using `digest::digest(..., algo = "sha256")`, as already used for row revisions in `worldcup_ledger.R` lines 369-381.

---

### `_targets.R` (pipeline config, event-driven + file-I/O)

**Primary analog:** existing Phase 8 target chain in `_targets.R`.

**Source registration pattern** (lines 39-48):

```r
source("R/benchmark/euro2024.R")
source("R/benchmark/euro2024_tournament.R")
source("R/evaluation/proper_scores.R")
source("R/evaluation/worldcup_ledger.R")
source("R/evaluation/worldcup_retrospective.R")
```

Add new sources in dependency order: registry/cutoffs/weights/contracts/baselines/formats/scores/promotion/runner.

**Ordered evaluation target and file-output pattern** (lines 428-453):

```r
tar_target(
  worldcup_retrospective_ledger_bundle,
  write_forecast_ledger_bundle(
    source_ref = "HEAD",
    output_dir = "outputs/evaluation/wc2026"
  )
),
tar_target(
  worldcup_retrospective_score_files,
  {
    bundle <- worldcup_retrospective_ledger_bundle
    scores <- score_worldcup_matches(bundle$selected, distributions$scorelines)
    aggregates <- aggregate_worldcup_scores(scores)
    write_worldcup_score_bundle(scores, aggregates, calibration, advancement, stages, output_dir)
    file.path(output_dir, c("match_scores.csv", "aggregate_scores.csv", "score_manifest.csv"))
  },
  format = "file"
)
```

Register incremental targets for validated registries, boundary snapshots, adapters, stage simulations, fixture scores, tournament summaries, paired comparisons, promotion decisions, and final manifests. Keep these independent of dashboard targets and preserve file-oriented `format = "file"` contracts. Use static or dynamic branching only over prevalidated registry rows; the cache-only runner must not depend on download targets.

---

### `tests/testthat/helper_benchmark.R` (test utility, batch + transform)

**Primary analog:** `tests/testthat/test_worldcup_scoring.R`, lines 59-75.

```r
synthetic_selected_forecasts <- function() {
  data.frame(
    match_id = c("G1", "G2", "G1", "G2"),
    sample = c("strict", "strict", "exploratory", "exploratory"),
    view = "latest_valid",
    actual_home_goals = c(1, 0, 1, 0),
    actual_away_goals = c(0, 0, 0, 0),
    p_home = c(0.6, 0.3, 0.5, 0.2),
    p_draw = c(0.2, 0.4, 0.3, 0.5),
    p_away = c(0.2, 0.3, 0.2, 0.3),
    stringsAsFactors = FALSE
  )
}
```

Centralize compact synthetic histories, all three format families, adapter stubs, fixed score grids, and deterministic registries here. Helpers should return data, not write project files; use `tempfile()`/temporary directories in tests that exercise bundle writers.

---

### Benchmark contract/unit tests (test role, batch/transform/file-I/O)

**Files and closest analog assignments:**

| New Test | Copy Pattern From |
|---|---|
| `test_benchmark_registry.R` | `test_worldcup_scoring.R` lines 21-56 for invalid contracts; `test_worldcup_retrospective.R` lines 52-64 for artifact cardinality/reconciliation |
| `test_benchmark_cutoffs.R` | `test_transfermarkt_benchmark.R` lines 158-175 and 256-313 for strict cutoff and complete fixture rows |
| `test_benchmark_seal.R` | `test_worldcup_scoring.R` lines 21-31 for explicit errors; add synthetic `wc2026` labels and assert rejection before adapter invocation |
| `test_benchmark_contracts.R` | `test_worldcup_scoring.R` lines 33-56 for score-grid/market reconciliation and visible missing-cell failures |
| `test_benchmark_baselines.R` | `test_transfermarkt_benchmark.R` lines 198-254 for synthetic end-to-end baseline output and artifact checks |
| `test_benchmark_scoring.R` | `test_worldcup_scoring.R` lines 8-19 and 77-125 for hand calculations, aggregation, deterministic intervals, paired rows, calibration |
| `test_benchmark_promotion.R` | `test_worldcup_scoring.R` lines 100-120 for deterministic and paired comparisons; add boundary-exact pure-gate tables |
| `test_benchmark_pipeline.R` | `test_worldcup_retrospective.R` lines 23-64 and 79-90 for cache-only runner text, target declarations, artifact reconciliation, and manifest hashes |

**Standard test imports** (`tests/testthat/test_worldcup_scoring.R`, lines 1-6):

```r
library(testthat)

project_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))
source(file.path(project_root, "R/evaluation/proper_scores.R"))
source(file.path(project_root, "R/evaluation/worldcup_ledger.R"))
source(file.path(project_root, "R/evaluation/worldcup_retrospective.R"))
```

Source only the modules needed by each test file. Keep tests deterministic and small; the full 12-fold run belongs at the phase gate, not per-task feedback.

**Hand-calculated contract tests** (`test_worldcup_scoring.R`, lines 8-31):

```r
testthat::test_that("1X2 proper scores match hand calculations", {
  perfect <- c(home = 1, draw = 0, away = 0)
  uniform <- c(home = 1 / 3, draw = 1 / 3, away = 1 / 3)
  wrong <- c(home = 0, draw = 0, away = 1)

  testthat::expect_equal(multiclass_brier(perfect, "home"), 0)
  testthat::expect_equal(ranked_probability_score(uniform, "home"), 5 / 18, tolerance = 1e-12)
  testthat::expect_equal(ranked_probability_score(wrong, "home"), 1, tolerance = 1e-12)
})
```

**Determinism test** (`test_worldcup_scoring.R`, lines 100-105):

```r
first <- bootstrap_worldcup_scores(scores, reps = 100, seed = 20260720)
second <- bootstrap_worldcup_scores(scores, reps = 100, seed = 20260720)
testthat::expect_identical(first, second)
```

**Pipeline/cache-only guard** (`test_worldcup_retrospective.R`, lines 23-37):

```r
runner <- paste(readLines(file.path(project_root, "scripts/run_worldcup_2026_retrospective.R"), warn = FALSE), collapse = "\n")
expect_true(all(vapply(c("--source-ref", "--output-dir", "--bootstrap-reps", "--seed"),
  grepl, logical(1), x = runner, fixed = TRUE)))
forbidden <- c("httr::", "httr2::", "curl::", "download.file", "train_home_goal_model", "train_away_goal_model")
expect_false(any(vapply(forbidden, grepl, logical(1), x = runner, fixed = TRUE)))
```

For Phase 09, allow local fitting but continue to forbid network/download calls. Assert the sealed loader rejects WC2026 outcomes and that rejected data never reach adapter stubs.

---

### `data/benchmark/phase09/promotion_protocol.json` (config/policy, file-I/O)

**Analog:** No close codebase analog. Use the exact schema and thresholds in `09-RESEARCH.md`/D-16 through D-20. Keep it machine-readable, versioned, canonically serialized, and SHA-256 hashed before any fold execution. It must encode the incumbent IDs, panel/track, `-0.003` RPS threshold, CI rule, 8/12 breadth with at least two World Cups and two Euros, `0.015` maximum fold regression, supporting-score veto thresholds, coverage/provenance/license/reproducibility vetoes, optional-panel rule, seeds, and freeze metadata.

---

### `data/benchmark/phase09/SOURCES.md` (provenance documentation, file-I/O)

**Analog:** No close codebase analog. Use one entry per curated source/correction with source URL/title, access date, license, affected registry/rows, original value, curated value, rationale, and reviewer/checksum. This is the human-review companion to machine-readable provenance columns; it must not substitute for row-level source IDs/hashes.

## Shared Patterns

### Project Imports and Dependencies

The repository does not use package-style imports in these modules. Functions are sourced explicitly by `_targets.R` and test files. Optional packages use fail-fast namespace checks, e.g. `worldcup_ledger.R` lines 77-80:

```r
if (!requireNamespace("jsonlite", quietly = TRUE)) stop("jsonlite is required")
```

Use `digest::digest()` explicitly for SHA-256. Keep `MASS` loading at orchestration/adapter boundaries rather than hidden inside pure validators.

### Validation and Error Handling

Validation is fail-fast with required-column checks, exact cardinality, uniqueness, finite/range checks, and actionable messages. Pure validation functions return the validated object or `invisible(TRUE)`; they do not repair silently. Avoid `tryCatch(..., error = function(e) NULL)` on benchmark-critical paths—the Phase 8 retrospective uses it for optional archived scoreline diagnostics, but Phase 09 requires missing distributions to fail the contract.

### Point-in-Time Evidence

All joins use strict `< cutoff`, and source dates remain explicit in outputs. Same-day fixtures share a pre-day state. The only sanctioned update occurs after the complete date batch closes. Validate maximum result/feature source dates in every model manifest.

### Identity

Use registry `team_id` backed by checked FIFA code and canonical display name. Normalize aliases once while building `teams.csv`; adapters and scoring code join IDs and never canonicalize display strings independently.

### Determinism

Set seeds at public stochastic boundaries, source them from `seed_registry.csv`, and make common-random-number seeds independent of model ID and execution order. Canonically sort rows before hashing. Test both object identity and content hashes across reruns.

### Artifact Writing

Build -> validate -> write -> hash -> manifest. CSVs are row-level auditable contracts; RDS is reserved for fitted objects/compact internal bundles. Every durable artifact records schema version, row/byte counts, SHA-256, producer, source Git SHA, and parent hashes. Runtime timestamps are excluded from content hashes.

### Coverage

Never use an inner join that silently reduces fixture scope. Start from the registered fixture/panel inventory, left-join predictions/features, mark status/reason, and fail required coverage. Optional rich-panel membership is frozen before output inspection.

## Generated Output Contracts (Not Hand-Authored)

`R/benchmark/runner.R` should generate these under `outputs/benchmarks/rolling_tournaments/<run_id>/`:

| Artifact | Producer Pattern |
|---|---|
| `manifests/model_manifests.csv`, `feature_coverage.csv`, `checksum_manifest.csv` | Phase 8 bundle/manifest writers in `worldcup_ledger.R` lines 652-731 |
| `predictions/fixture_predictions.csv`, `score_distributions.csv` | shared prediction rows from `euro2024.R` lines 210-225 plus full distribution validation in `proper_scores.R` |
| `stage_probabilities/stage_probabilities.csv` | simulation accumulation in `euro2024_tournament.R` lines 467-505 |
| `scores/fixture_scores.csv`, `benchmark_summaries.csv` | long score rows and aggregation in `worldcup_retrospective.R` lines 3-19 and 171-260 |
| `comparisons/paired_comparisons.csv`, `promotion_decisions.csv` | paired merge pattern in `worldcup_retrospective.R` lines 236-256 plus pure Phase 09 gate |
| `run_manifest.csv` | bundle manifest pattern in `worldcup_ledger.R` lines 652-663, upgraded to SHA-256 |

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `data/benchmark/phase09/promotion_protocol.json` | config / policy | file-I/O | No existing frozen machine-readable promotion protocol; legacy `hybrid_pass` is intentionally insufficient. |
| `data/benchmark/phase09/SOURCES.md` | provenance documentation | file-I/O | No existing row-oriented curated historical source/correction ledger. |

## Metadata

**Analog search scope:** `R/benchmark/`, `R/evaluation/`, `R/forecast/`, `_targets.R`, `tests/testthat/`, and Phase 09 planning contracts.

**Primary analogs read:**

- `R/evaluation/worldcup_ledger.R`
- `R/benchmark/euro2024.R`
- `R/benchmark/euro2024_tournament.R`
- `R/evaluation/proper_scores.R`
- `R/evaluation/worldcup_retrospective.R`
- `R/forecast/features.R`
- `R/forecast/goal_ability.R`
- `_targets.R`
- `tests/testthat/test_worldcup_scoring.R`
- `tests/testthat/test_worldcup_retrospective.R`
- `tests/testthat/test_transfermarkt_benchmark.R`

**Pattern extraction date:** 2026-07-20

**Planner warning:** Preserve the reusable mechanics but do not generalize the single-edition EURO files in place. Phase 09 should create registry-driven services and leave legacy EURO/dashboard outputs behaviorally unchanged.
