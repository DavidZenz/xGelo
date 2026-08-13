# Phase 11: Hybrid ML and Contextual Priors - Pattern Map

**Mapped:** 2026-08-08
**Files analyzed:** 20
**Analogs found:** 20 / 20

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `R/benchmark/hybrid_protocol.R` | config | request-response | `R/benchmark/challenger_protocol.R` | exact |
| `R/benchmark/hybrid_runner.R` | service | request-response | `R/benchmark/challenger_runner.R` | exact |
| `R/benchmark/hybrid_adapters.R` | service | transform | `R/benchmark/challengers.R` | exact |
| `R/forecast/hybrid_rf.R` | service | transform | `R/benchmark/baselines.R` | role-match |
| `R/forecast/context_features.R` | utility | transform | `R/forecast/features.R` | exact |
| `R/forecast/structural_prior.R` | service | transform | `R/forecast/goal_ability.R` | role-match |
| `R/forecast/external_market.R` | utility | file-I/O | `R/transfermarkt/squad_strength.R` | partial |
| `data/benchmark/phase11/model_registry.csv` | config | CRUD | `data/benchmark/phase10/model_registry.csv` via `R/benchmark/challenger_protocol.R` | exact |
| `data/benchmark/phase11/feature_contract.csv` | config | CRUD | `data/benchmark/phase10/feature_contract.csv` via `R/benchmark/challenger_protocol.R` | exact |
| `data/benchmark/phase11/mode_registry.csv` | config | CRUD | `data/benchmark/phase09/panel_fixtures.csv` + `R/benchmark/contracts.R` | role-match |
| `data/benchmark/phase11/xg_gate_manifest.csv` | config | CRUD | `R/forecast/xg_usage_audit.R` | role-match |
| `data/benchmark/phase11/structural_prior_manifest.csv` | config | CRUD | `R/forecast/goal_ability.R` | partial |
| `data/benchmark/phase11/manual_market_manifest.csv` | config | file-I/O | `R/transfermarkt/squad_strength.R` | partial |
| `_targets.R` | config | batch | `_targets.R` Phase 10 target chain | exact |
| `tests/testthat/test_hybrid_random_forest.R` | test | transform | `tests/testthat/test_benchmark_contracts.R` | role-match |
| `tests/testthat/test_hybrid_context_features.R` | test | transform | `tests/testthat/test_transfermarkt_benchmark.R` | role-match |
| `tests/testthat/test_hybrid_xg_gate.R` | test | request-response | `tests/testthat/test_transfermarkt_benchmark.R` + `R/forecast/xg_usage_audit.R` | role-match |
| `tests/testthat/test_hybrid_structural_prior.R` | test | transform | `tests/testthat/test_transfermarkt_benchmark.R` + `R/forecast/goal_ability.R` | role-match |
| `tests/testthat/test_hybrid_modes.R` | test | file-I/O | `tests/testthat/test_benchmark_contracts.R` | role-match |
| `tests/testthat/test_hybrid_targets.R` | test | batch | `tests/testthat/test_statistical_targets.R` | exact |

## Pattern Assignments

### `R/benchmark/hybrid_protocol.R` (config, request-response)

**Analog:** `R/benchmark/challenger_protocol.R`

**Registry constructor pattern** ([R/benchmark/challenger_protocol.R:131](../../../R/benchmark/challenger_protocol.R:131)-[185](../../../R/benchmark/challenger_protocol.R:185)):
```r
.canonical_phase10_model_registry <- function() {
  constants <- phase10_protocol_constants()
  candidate_id <- constants$candidate_ids
  registry <- data.frame(
    schema_version = rep("1.0", 7L),
    candidate_id = candidate_id,
    model_family = c(...),
    adapter_id = c(...),
    adapter_version = rep("phase10-v1", 7L),
    native_panel_id = rep("open_core", 7L),
    ...
    score_support_max = rep("40", 7L),
    open_mode_compatible = rep("true", 7L),
    ...
    settings_sha256 = "",
    registration_sha256 = "",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  ...
  registry$settings_sha256 <- .phase10_subset_sha256(registry, settings_fields)
  registry$registration_sha256 <- .phase10_row_sha256(registry, "registration_sha256")
  registry
}
```

**Feature-contract extension pattern** ([R/benchmark/challenger_protocol.R:188](../../../R/benchmark/challenger_protocol.R:188)-[225](../../../R/benchmark/challenger_protocol.R:225)):
```r
additions <- data.frame(
  schema_version = rep("1.0", 8L),
  panel_id = rep("open_core", 8L),
  feature_id = c(...),
  definition_version = rep("phase10-v1", 8L),
  definition = c(...),
  required = rep("true", 8L),
  source_id = c(...),
  source_artifact_sha256 = c(...),
  availability_rule = c(...),
  imputation_rule = c(...),
  missingness_rule = rep(
    "source presence, value presence, imputation, and active-fit status remain distinct", 8L
  ),
  allowed_max_source_lag_days = rep("-1", 8L),
  license_class = rep("open-or-derived-open", 8L),
  row_sha256 = ""
)
```

**Write-and-validate pattern** ([R/benchmark/challenger_protocol.R:451](../../../R/benchmark/challenger_protocol.R:451)-[476](../../../R/benchmark/challenger_protocol.R:476)):
```r
.phase10_validate_task1_files <- function(protocol_dir = "data/benchmark/phase10") {
  files <- c(
    model_registry = "model_registry.csv", feature_contract = "feature_contract.csv",
    tuning_editions = "tuning_editions.csv", tuning_grid = "tuning_grid.csv"
  )
  tables <- lapply(file.path(protocol_dir, files), .phase10_read_csv)
  ...
  .phase10_validate_model_registry(tables$model_registry)
  .phase10_validate_feature_contract(tables$feature_contract)
  ...
}

.write_phase10_task1_protocol <- function(protocol_dir = "data/benchmark/phase10") {
  .phase10_write_csv(.canonical_phase10_model_registry(), file.path(protocol_dir, "model_registry.csv"))
  .phase10_write_csv(.canonical_phase10_feature_contract(), file.path(protocol_dir, "feature_contract.csv"))
  ...
  .phase10_validate_task1_files(protocol_dir)
}
```

**Apply to Phase 11:** create canonical constructors for `model_registry.csv`, `feature_contract.csv`, `mode_registry.csv`, `xg_gate_manifest.csv`, `structural_prior_manifest.csv`, and `manual_market_manifest.csv`; freeze `score_support_max = 40`, preserve open/enriched/external separation, and keep 2026 sealed in the run metadata.

---

### `R/benchmark/hybrid_runner.R` (service, request-response)

**Analog:** `R/benchmark/challenger_runner.R`

**Bundle path layout** ([R/benchmark/challenger_runner.R:168](../../../R/benchmark/challenger_runner.R:168)-[180](../../../R/benchmark/challenger_runner.R:180)):
```r
phase10_output_paths <- function(output_dir) {
  c(
    run_manifest = file.path(output_dir, "run_manifest.csv"),
    model_manifests = file.path(output_dir, "manifests", "model_manifests.csv"),
    feature_coverage = file.path(output_dir, "manifests", "feature_coverage.csv"),
    fold_tuning = file.path(output_dir, "manifests", "fold_tuning.csv"),
    checksum_manifest = file.path(output_dir, "manifests", "checksum_manifest.csv"),
    fixture_predictions = file.path(output_dir, "predictions", "fixture_predictions.csv"),
    score_distributions = file.path(output_dir, "predictions", "score_distributions.csv"),
    fixture_scores = file.path(output_dir, "scores", "fixture_scores.csv"),
```

**Panel-preserving execution pattern** ([R/benchmark/challenger_runner.R:578](../../../R/benchmark/challenger_runner.R:578)-[688](../../../R/benchmark/challenger_runner.R:688)):
```r
if (!is.data.frame(protocol$panel_fixtures)) {
  protocol$panel_fixtures <- utils::read.csv(
    file.path(.phase10_runner_root(), "data", "benchmark", "phase09", "panel_fixtures.csv"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}
...
output[[candidate_id]] <- run_registered_challenger_adapter(
  candidate_id, history,
  fixtures[
    as.character(fixtures$track_id) == track_id &
      as.character(fixtures$edition_id) == edition_id,
    , drop = FALSE
  ],
  seed_registry, support_max = 40L,
  settings = settings, protocol = protocol,
  fit_cache = fit_cache, mean_cache = mean_cache
)
...
scores <- do.call(rbind, lapply(split(predictions, predictions$track_id), function(track_predictions) {
  ...
  score_benchmark_fixtures(
    track_predictions, track_fixtures, distributions,
    benchmark_panel_fixture_ids(protocol$panel_fixtures, "open_core")
  )
}))
```

**Run manifest pattern** ([R/benchmark/challenger_runner.R:754](../../../R/benchmark/challenger_runner.R:754)-[783](../../../R/benchmark/challenger_runner.R:783)):
```r
run_manifest <- data.frame(
  schema_version = "phase10-challenger-bundle-v1",
  run_id = "phase10-statistical-challengers",
  ...
  open_fixture_count = 630L, rich_fixture_count = 609L, selected_g = 40L,
  reproducible = FALSE, wc2026_sealed = TRUE, network_free = TRUE,
  research_only = TRUE, protected_paths_clean = TRUE, synthetic = FALSE,
  stringsAsFactors = FALSE
)
```

**Apply to Phase 11:** keep the bundle layout identical, route open-mode headline scoring through exact `open_core`, keep rich or external comparisons explicitly panel-labelled, and retain `630/609`, `G=40`, `wc2026_sealed = TRUE`, `research_only = TRUE`.

---

### `R/benchmark/hybrid_adapters.R` (service, transform)

**Analog:** `R/benchmark/challengers.R`

**Allowlist dispatch pattern** ([R/benchmark/challengers.R:353](../../../R/benchmark/challengers.R:353)-[390](../../../R/benchmark/challengers.R:390)):
```r
fit_registered_challenger <- function(
    candidate_id, history, settings = list(), cutoff = NULL,
    registration = NULL, protocol = NULL,
    protocol_dir = "data/benchmark/phase10", fit_callback = NULL,
    fit_cache = NULL
) {
  protocol <- challenger_load_validated_protocol(protocol, protocol_dir)
  registration <- challenger_registration(protocol, candidate_id, registration)
  challenger_validate_runtime_settings(settings, registration)
  ...
  fit <- switch(
    candidate_id,
    poisson_team_ridge = challenger_penalized_fit(...),
    dynamic_goal_ability = challenger_dynamic_fit(...),
    ...
    stop("unknown challenger allowlist candidate_id", call. = FALSE)
  )
  ...
}
```

**Distribution adapter pattern** ([R/benchmark/challengers.R:427](../../../R/benchmark/challengers.R:427)-[460](../../../R/benchmark/challengers.R:460)):
```r
challenger_distribution_grid <- function(
    candidate_id, mu_home, mu_away, support_max, distribution_id, settings,
    nb_fit = NULL, row_index = NULL
) {
  if (identical(candidate_id, "open_nb_elo_only_ablation")) {
    goals <- 0:as.integer(support_max)
    home <- stats::dnbinom(goals, size = nb_fit$home_model$theta, mu = mu_home)
    away <- stats::dnbinom(goals, size = nb_fit$away_model$theta, mu = mu_away)
    return(benchmark_one_distribution(
      distribution_id, home, away,
      max(0, 1 - sum(home) * sum(away)), support_max
    ))
  }
  switch(candidate_id, ...)
}
```

**Predictor reconciliation pattern** ([R/benchmark/challengers.R:467](../../../R/benchmark/challengers.R:467)-[520](../../../R/benchmark/challengers.R:520)):
```r
predict_registered_challenger <- function(
    candidate_id, fit = NULL, fixtures = NULL, support_max = 40L,
    mean_predictions = NULL, settings = list(), validate_only = FALSE,
    mean_cache = NULL
) {
  ...
  if (candidate_id %in% c("dynamic_goal_ability", "dynamic_goal_ability_elo")) {
    means <- challenger_dynamic_means(fit, fixtures, mean_cache = mean_cache)
  } else {
    nb <- benchmark_nb_means(fit, fixtures)
    means <- data.frame(
      fixture_id = as.character(fixtures$fixture_id),
      mu_home = nb$home, mu_away = nb$away,
      stringsAsFactors = FALSE
    )
  }
```

**Apply to Phase 11:** give every RF/context/structural/xG-gated/mode-specific candidate a strict adapter ID and allowlist entry. Keep the shared prediction path: fit returns auditable means/evidence, then one NB distribution adapter emits the normalized `0:G` grid.

---

### `R/forecast/hybrid_rf.R` (service, transform)

**Analog:** `R/benchmark/baselines.R`

**Two-sided mean fit skeleton** ([R/benchmark/baselines.R:129](../../../R/benchmark/baselines.R:129)-[161](../../../R/benchmark/baselines.R:161)):
```r
benchmark_fit_two_sided_nb <- function(history, cutoff, candidates, model_id, panel_id, observation_weights = NULL) {
  history <- benchmark_baseline_training_rows(history, cutoff)
  ...
  predictors <- benchmark_numeric_predictors(history, candidates)
  if (!length(predictors$active)) stop(model_id, " has no active registered predictors", call. = FALSE)
  ...
  home_fit <- benchmark_glm_nb(home_formula, model_data, observation_weights, paste(model_id, "home"))
  away_fit <- benchmark_glm_nb(away_formula, model_data, observation_weights, paste(model_id, "away"))
  structure(list(
    model_id = model_id, model_family = "negative_binomial", panel_id = panel_id,
    home_model = home_fit, away_model = away_fit,
    active_predictors = predictors$active,
    dropped_predictors = predictors$dropped,
    ...
  ), class = "benchmark_baseline_fit")
}
```

**NB distribution conversion pattern** ([R/benchmark/baselines.R:294](../../../R/benchmark/baselines.R:294)-[359](../../../R/benchmark/baselines.R:359)):
```r
benchmark_one_distribution <- function(id, home_probability, away_probability, raw_tail, support_max) {
  grid <- expand.grid(home_goals = 0:support_max, away_goals = 0:support_max)
  raw <- outer(home_probability, away_probability)
  grid$score_distribution_id <- id
  grid$probability <- as.vector(raw / sum(raw))
  ...
}

means <- benchmark_nb_means(fit, fixtures)
goals <- 0:support_max
home_probability <- stats::dnbinom(goals, size = means$home_theta, mu = means$home[i])
away_probability <- stats::dnbinom(goals, size = means$away_theta, mu = means$away[i])
```

**Manifest provenance pattern** ([R/benchmark/baselines.R:361](../../../R/benchmark/baselines.R:361)-[385](../../../R/benchmark/baselines.R:385)):
```r
data.frame(
  model_manifest_id = paste(run_id, registration$model_id, boundaries$boundary_id[i], sep = "__"),
  ...
  max_result_date = max(eligible), max_feature_source_date = max(eligible),
  evidence_cutoff_exclusive = cutoff,
  active_predictors = paste(fit$active_predictors, collapse = "|"),
  dropped_predictors_with_reason = paste(fit$dropped_predictors, collapse = "missing_or_zero_variance|"),
  ...
)
```

**Apply to Phase 11:** copy the dual-model fit object shape for home/away forests, but store RF fits plus registered NB dispersion. Keep active/dropped predictor manifests explicit, especially for xG inactive status and context ablations.

---

### `R/forecast/context_features.R` (utility, transform)

**Analog:** `R/forecast/features.R`

**Latest-before evidence lookup** ([R/forecast/features.R:127](../../../R/forecast/features.R:127)-[175](../../../R/forecast/features.R:175)):
```r
make_latest_team_evidence_lookup <- function(
    data,
    value_col,
    team_col = "team",
    date_col = "date",
    default = NA_real_
) {
  missing_evidence <- function(reason, source_present = FALSE, source_date = as.Date(NA)) {
    list(
      value = as.numeric(default),
      source_present = isTRUE(source_present),
      source_date = as.Date(source_date),
      value_present = FALSE,
      imputed = TRUE,
      imputation_reason = reason
    )
  }
  ...
}
```

**Evidence companion write pattern** ([R/forecast/features.R:190](../../../R/forecast/features.R:190)-[226](../../../R/forecast/features.R:226)):
```r
forecast_difference_evidence <- function(home, away) {
  ...
  list(
    value = as.numeric(home$value) - as.numeric(away$value),
    source_present = source_present,
    source_date = as.Date(source_date),
    value_present = value_present,
    imputed = !value_present,
    imputation_reason = reason
  )
}

add_forecast_feature_evidence <- function(row, feature_id, evidence) {
  row[[feature_id]] <- as.numeric(evidence$value)
  row[[paste0(feature_id, "__value_present")]] <- isTRUE(evidence$value_present)
  row[[paste0(feature_id, "__source_present")]] <- isTRUE(evidence$source_present)
  row[[paste0(feature_id, "__source_date")]] <- as.Date(evidence$source_date)
  row[[paste0(feature_id, "__imputed")]] <- isTRUE(evidence$imputed)
  row[[paste0(feature_id, "__imputation_reason")]] <- as.character(evidence$imputation_reason)
  row
}
```

**Strict evidence validation pattern** ([R/forecast/features.R:430](../../../R/forecast/features.R:430)-[455](../../../R/forecast/features.R:455)):
```r
if (any(!is.na(source_date) & source_date >= fixture_dates)) {
  stop(paste("Forecast evidence source dates must be strictly before fixture dates for", producer_id))
}
if (any(imputed != !value_present)) {
  stop(paste("Forecast evidence imputed flag disagrees with value presence for", producer_id))
}
```

**Apply to Phase 11:** derive `host`, `neutral`, `rest_days`, `travel_km`, and `stage_id` with separate evidence companions. Do not silently impute unavailable context values on the open-context panel. Use source rows plus derivation metadata so missingness is visible.

---

### `R/forecast/structural_prior.R` (service, transform)

**Analogs:** `R/forecast/goal_ability.R`, `R/forecast/dynamic_goal_ability.R`

**Recency-weighted effective evidence pattern** ([R/forecast/goal_ability.R:60](../../../R/forecast/goal_ability.R:60)-[108](../../../R/forecast/goal_ability.R:108)):
```r
age_days <- as.numeric(cutoff_date - prior$date)
recency_weight <- exp(-log(2) * age_days / half_life_days)
...
weighted_for <- stats::weighted.mean(team_rows$goals_for, team_rows$weight, na.rm = TRUE)
weighted_against <- stats::weighted.mean(team_rows$goals_against, team_rows$weight, na.rm = TRUE)
...
feature_source_date = max(as.Date(team_rows$source_date), na.rm = TRUE),
ability_match_count = nrow(team_rows),
```

**Sparse-team shrinkage pattern** ([R/forecast/dynamic_goal_ability.R:124](../../../R/forecast/dynamic_goal_ability.R:124)-[153](../../../R/forecast/dynamic_goal_ability.R:153)):
```r
exposure <- as.numeric(row$W)
denominator <- state$pseudo_exposure + exposure
attack_rate <- (state$pseudo_exposure * state$global_goal_rate + row$GF) / denominator
defence_rate <- (state$pseudo_exposure * state$global_goal_rate + row$GA) / denominator
...
shrinkage_weight = exposure / denominator,
cold_start = exposure == 0,
source_date = source_date,
state_age_days = if (is.na(source_date)) Inf else as.numeric(as.Date(prediction_date) - source_date),
history_match_count = as.integer(row$history_match_count)
```

**Apply to Phase 11:** implement the structural prior as a continuous shrinkage layer keyed by effective recent evidence, not as raw RF predictors and not as a hard sparse/not-sparse branch. Every structural row needs vintage and source-date columns strictly before cutoff.

---

### `R/forecast/external_market.R` (utility, file-I/O)

**Analog:** `R/transfermarkt/squad_strength.R`

**Manual snapshot read/validate pattern** ([R/transfermarkt/squad_strength.R:78](../../../R/transfermarkt/squad_strength.R:78)-[105](../../../R/transfermarkt/squad_strength.R:105)):
```r
read_transfermarkt_national_team_values <- function(
    snapshot_path = "data/raw/transfermarkt/transfermarkt-datasets.duckdb"
) {
  validate_transfermarkt_snapshot(snapshot_path)
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = snapshot_path, read_only = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ...
}
```

**Strictly-as-of filter pattern** ([R/transfermarkt/squad_strength.R:409](../../../R/transfermarkt/squad_strength.R:409)-[443](../../../R/transfermarkt/squad_strength.R:443)):
```r
latest_player_valuations_as_of <- function(valuations, as_of_date, ...) {
  ...
  available <- valuations[
    !is.na(valuations[[player_id_col]]) &
      !is.na(valuations[[date_col]]) &
      valuations[[date_col]] < as_of_date,
    ,
    drop = FALSE
  ]
  ...
}
```

**Point-in-time feature-source-date pattern** ([R/transfermarkt/squad_strength.R:604](../../../R/transfermarkt/squad_strength.R:604)-[620](../../../R/transfermarkt/squad_strength.R:620)):
```r
data.frame(
  team = team_rows[[team_col]][1],
  as_of_date = as_of_date,
  feature_source_date = as_of_date - 1,
  ...
)
```

**Apply to Phase 11:** manual bookmaker files should copy the same local-snapshot discipline: read-only local artifact, explicit cutoff filtering, per-row source timestamp, and no automated collection. Keep this mode separate from open default and from enriched squad mode.

---

### `data/benchmark/phase11/*.csv` (config, CRUD)

**Analogs:** `R/benchmark/challenger_protocol.R`, `R/benchmark/contracts.R`

**Required contract columns to preserve** ([R/benchmark/contracts.R:208](../../../R/benchmark/contracts.R:208)-[237](../../../R/benchmark/contracts.R:237), [242](../../../R/benchmark/contracts.R:242)-[243](../../../R/benchmark/contracts.R:242)):
```r
required <- c(
  "model_manifest_id", "run_id", "model_id", "edition_id", "track_id", "boundary_id",
  "fit_status", "fit_row_count", "fit_min_date", "fit_max_date", "max_result_date",
  "max_feature_source_date", "evidence_cutoff_exclusive", "active_predictors",
  "dropped_predictors_with_reason", "model_family", "convergence_status", "fallback_status",
  "adapter_version", "code_version", "r_version", "package_versions",
  "registration_sha256", "settings_sha256", "parent_hashes"
)
```

**Panel fixture contract** ([R/benchmark/contracts.R:443](../../../R/benchmark/contracts.R:443)-[446](../../../R/benchmark/contracts.R:446)):
```r
benchmark_contract_require_columns(
  panel_fixtures,
  c("panel_id", "fixture_id", "eligible", "output_coverage_required"),
```

**Apply to Phase 11:** mode and gate manifests should be designed so runner outputs can still validate against the same prediction, manifest, coverage, panel, and run-manifest contracts. Open-mode registries must preserve `open_core = 630`; enriched mode must preserve `feature_rich = 609`; external mode needs its own explicit labelled scope if it cannot satisfy those panels.

---

### `_targets.R` (config, batch)

**Analog:** `_targets.R`, Phase 10 chain

**Source-order pattern** ([_targets.R:54](../../../_targets.R:54)-[70](../../../_targets.R:70)):
```r
source("R/benchmark/registry.R")
source("R/benchmark/challenger_preflight.R")
source("R/benchmark/cutoffs.R")
source("R/benchmark/weights.R")
source("R/benchmark/contracts.R")
source("R/benchmark/baselines.R")
...
source("R/benchmark/challenger_protocol.R")
source("R/forecast/penalized_poisson.R")
source("R/forecast/dynamic_goal_ability.R")
source("R/forecast/score_dependence.R")
source("R/benchmark/challengers.R")
source("R/evaluation/challenger_selection.R")
source("R/benchmark/challenger_runner.R")
```

**Registry-files target pattern** ([_targets.R:591](../../../_targets.R:591)-[615](../../../_targets.R:615)):
```r
tar_target(
  benchmark_phase10_registry_files,
  c(
    file.path("data/benchmark/phase10", c(...)),
    file.path("data/benchmark/phase09", c(...)),
    file.path(
      "outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen",
      c("run_manifest.csv", "manifests/checksum_manifest.csv", "scores/fixture_scores.csv")
    ),
    "data/processed/goal_training_features_hybrid.csv"
  ),
  format = "file"
)
```

**Predictions-chain pattern** ([_targets.R:616](../../../_targets.R:616)-[700](../../../_targets.R:700)):
```r
tar_target(
  benchmark_phase10_registries,
  {
    ...
    protocol <- load_and_validate_challenger_protocol(phase10_dir)
    ...
    feature_input_sha256 <- benchmark_runner_file_sha256(feature_input)
    list(...)
  }
),
tar_target(
  benchmark_phase10_predictions,
  {
    ...
    history <- .phase10_runner_prepare_history(history, context$protocol)
    ...
    run_statistical_challenger_benchmark(
      history = history, fixtures = fixtures,
      seed_registry = context$phase09_inputs$seed_registry,
      synthetic = FALSE, publish = FALSE
    )
  }
)
```

**Apply to Phase 11:** add a new six-node chain mirroring Phase 10 for registries, context/gate inputs, predictions, scores, comparisons, and bundle files. Keep Phase 11 downstream-only, and do not let it mutate or reopen Phase 09/10 artifacts.

---

### `tests/testthat/test_hybrid_*.R` (tests)

**Registry invariants analog** ([tests/testthat/test_benchmark_registry.R:7](../../../tests/testthat/test_benchmark_registry.R:7)-[17](../../../tests/testthat/test_benchmark_registry.R:17), [52](../../../tests/testthat/test_benchmark_registry.R:52)-[68](../../../tests/testthat/test_benchmark_registry.R:68)):
```r
expect_equal(nrow(registries$fixtures), 630L)
expect_equal(anyDuplicated(registries$fixtures$fixture_id), 0L)
...
short$fixtures <- short$fixtures[-1, ]
expect_error(validate_benchmark_registries(short), "630")
```

**Panel and contract invariants analog** ([tests/testthat/test_benchmark_contracts.R:172](../../../tests/testthat/test_benchmark_contracts.R:172)-[183](../../../tests/testthat/test_benchmark_contracts.R:183), [200](../../../tests/testthat/test_benchmark_contracts.R:200)-[259](../../../tests/testthat/test_benchmark_contracts.R:259), [261](../../../tests/testthat/test_benchmark_contracts.R:261)-[289](../../../tests/testthat/test_benchmark_contracts.R:289)):
```r
expect_length(open_ids, 630L)
expect_length(rich_ids, 609L)
...
expect_equal(nrow(selected), 609L)
expect_equal(attr(selected, "excluded_fixture_count"), 21L)
...
expect_error(validate_model_manifests(leaked), "strictly before")
```

**As-of and evidence tests analog** ([tests/testthat/test_transfermarkt_benchmark.R:7](../../../tests/testthat/test_transfermarkt_benchmark.R:7)-[21](../../../tests/testthat/test_transfermarkt_benchmark.R:21), [643](../../../tests/testthat/test_transfermarkt_benchmark.R:643)-[672](../../../tests/testthat/test_transfermarkt_benchmark.R:672), [675](../../../tests/testthat/test_transfermarkt_benchmark.R:675)-[711](../../../tests/testthat/test_transfermarkt_benchmark.R:711)):
```r
latest <- latest_player_valuations_as_of(valuations, as.Date("2024-06-14"))
expect_false(any(latest$date >= as.Date("2024-06-14")))
...
expect_equal(ability$attack_ability_diff__source_date[1], as.Date("2024-01-05"))
...
expect_error(validate_forecast_feature_evidence(bad, feature_contract), "strictly before")
```

**Targets-chain test analog** ([tests/testthat/test_statistical_targets.R:5](../../../tests/testthat/test_statistical_targets.R:5)-[10](../../../tests/testthat/test_statistical_targets.R:10), [43](../../../tests/testthat/test_statistical_targets.R:43)-[57](../../../tests/testthat/test_statistical_targets.R:43), [68](../../../tests/testthat/test_statistical_targets.R:68)-[97](../../../tests/testthat/test_statistical_targets.R:68), [99](../../../tests/testthat/test_statistical_targets.R:99)-[117](../../../tests/testthat/test_statistical_targets.R:99)):
```r
phase10_target_names <- function() {
  c(
    "benchmark_phase10_registry_files", "benchmark_phase10_registries",
    "benchmark_phase10_predictions", "benchmark_phase10_scores",
    "benchmark_phase10_comparisons", "benchmark_phase10_bundle_files"
  )
}
...
expect_match(commands[["benchmark_phase10_predictions"]], "run_statistical_challenger_benchmark", fixed = TRUE)
...
expect_lt(locations[["challenger_preflight.R"]], locations[["challenger_protocol.R"]])
```

**Apply to Phase 11 tests:**
- `test_hybrid_random_forest.R`: assert two-goal RF adapters emit valid `0:40` score grids and reconcile all derived markets.
- `test_hybrid_context_features.R`: assert rest/travel/stage/host/neutral evidence is strictly prior, with no silent imputation on the common open-context panel.
- `test_hybrid_xg_gate.R`: assert current historical xG fails closed until declared coverage and variance thresholds are met.
- `test_hybrid_structural_prior.R`: assert structural snapshots are vintage-safe and shrinkage weight changes continuously with effective evidence.
- `test_hybrid_modes.R`: assert open, enriched, and external mode outputs remain separated and do not alter open-core eligibility.
- `test_hybrid_targets.R`: mirror the exact six-node chain and deterministic source ordering used in Phase 10.

## Shared Patterns

### Score Distribution Contract
**Sources:** `R/benchmark/baselines.R:294-359`, `R/benchmark/contracts.R:64-121`, `R/benchmark/contracts.R:155-204`

Use one normalized joint score distribution for every Phase 11 candidate. RF means must still reconcile to `p_home`, `p_draw`, `p_away`, totals, BTTS, modal score, and exact-score support on `0:40`.

### Point-in-Time Evidence
**Sources:** `R/forecast/features.R:127-226`, `R/forecast/features.R:430-455`, `R/forecast/goal_ability.R:149-321`

Every new feature needs `__value_present`, `__source_present`, `__source_date`, `__imputed`, and `__imputation_reason`. Source dates must be strictly before the fixture or boundary.

### Sparse-Team Shrinkage
**Sources:** `R/forecast/dynamic_goal_ability.R:124-153`, `R/forecast/goal_ability.R:60-108`

Structural priors should behave like evidence-weighted shrinkage, not direct raw predictors. Preserve explicit exposure, history count, age, and cold-start diagnostics.

### Mode Separation
**Sources:** `R/benchmark/challenger_runner.R:673-688`, `R/benchmark/contracts.R:443-446`, `tests/testthat/test_benchmark_contracts.R:172-259`

Open-mode headline scoring stays on exact `630` `open_core` fixtures. Enriched mode stays on `609` `feature_rich` fixtures. External mode must remain explicitly labelled and isolated from promotion.

### Manual Restricted-Data Boundary
**Sources:** `R/transfermarkt/squad_strength.R:78-105`, `R/transfermarkt/squad_strength.R:409-443`

Restricted or licensed inputs are local manual snapshots only. Use strict `< as_of_date` selection and never automate Transfermarkt or bookmaker collection.

## No Exact Analog Found

| File | Closest Partial Analog | Gap |
|---|---|---|
| `R/forecast/external_market.R` | `R/transfermarkt/squad_strength.R` | Existing pattern covers manual local snapshots and as-of filters, but not bookmaker probability schema. |
| `data/benchmark/phase11/manual_market_manifest.csv` | `R/transfermarkt/squad_strength.R` | No current market-manifest schema exists; planner must freeze source/license/timestamp fields before evaluation. |
| `data/benchmark/phase11/structural_prior_manifest.csv` | `R/forecast/goal_ability.R` | Existing code has recency-weighted evidence and shrinkage semantics, but no structural snapshot registry yet. |

## Metadata

**Analog search scope:** `R/benchmark/`, `R/forecast/`, `R/transfermarkt/`, `tests/testthat/`, `_targets.R`, `data/benchmark/phase09`, `data/benchmark/phase10`

**Files scanned:** 16 primary analog files plus Phase 11 context artifacts

**Pattern extraction date:** 2026-08-08
