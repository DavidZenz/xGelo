# Phase 10: Statistical Goal-Model Challengers - Pattern Map

**Mapped:** 2026-07-22  
**Files analyzed:** 20 implementation/config/test files plus 11 generated bundle artifacts  
**Analogs found:** 27 / 31 (four novel statistical/selection seams have only partial analogs)

## Scope Extracted From Context And Research

Phase 10 is an overlay on the accepted Phase 9 benchmark. It adds seven registered candidates, chronology-safe fold tuning, three score-dependence choices sharing one mean structure, hierarchical incumbent ablation evidence, all-baseline paired comparisons, and a three-slot research shortlist. It must not edit `data/benchmark/phase09/`, copy the 979 MB Phase 9 bundle, call `evaluate_promotion()`, or read World Cup 2026 outcomes.

The seven candidate registrations expected by the research are:

1. `poisson_team_ridge`
2. `poisson_team_ridge_elo`
3. `dynamic_goal_ability`
4. `dynamic_goal_ability_elo`
5. `poisson_team_ridge_elo_dc`
6. `poisson_team_ridge_elo_bivpois`
7. `open_nb_elo_only_ablation`

## File Classification

### Source, Registry, Pipeline, And Tests

| New/Modified File | Change | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|---|
| `data/benchmark/phase10/model_registry.csv` | create | config/registry | batch | `data/benchmark/phase09/model_registry.csv` | role-match |
| `data/benchmark/phase10/feature_contract.csv` | create | config/registry | batch | `data/benchmark/phase09/feature_contract.csv` | exact |
| `data/benchmark/phase10/tuning_editions.csv` | create | config/registry | chronological batch | `data/benchmark/phase09/boundaries.csv`; `R/benchmark/cutoffs.R` | role-match |
| `data/benchmark/phase10/tuning_grid.csv` | create | config/registry | batch | `data/benchmark/phase09/score_support_audit.csv`; `build_score_support_audit()` | role-match |
| `data/benchmark/phase10/ablation_registry.csv` | create | config/registry | batch | `data/benchmark/phase09/model_registry.csv` | partial |
| `data/benchmark/phase10/selection_protocol.json` | create | config/protocol | batch | `data/benchmark/phase09/promotion_protocol.json`; `R/evaluation/promotion.R` | role-match, semantics differ |
| `data/benchmark/phase10/storage_preflight.csv` | create | config/evidence | batch + file-I/O | Phase 9 bundle/checksum preflight | role-match |
| `R/benchmark/challenger_protocol.R` | create | canonical registry/protocol validator | batch + file-I/O | `R/benchmark/registry.R`; `R/evaluation/promotion.R` | role-match |
| `R/forecast/penalized_poisson.R` | create | model/service | transform + batch | `R/benchmark/baselines.R` | role-match |
| `R/forecast/dynamic_goal_ability.R` | create | model/service | event-driven chronological batch | `R/forecast/goal_ability.R` | exact role/flow |
| `R/forecast/score_dependence.R` | create | model/utility | transform | `benchmark_one_distribution()` plus score-grid validators | partial |
| `R/forecast/poisson.R` | likely modify | model/config utility | transform | `baseline_goal_predictors()` in same file | exact if helper is added |
| `R/benchmark/challengers.R` | create | adapter/service | request-response + batch | `R/benchmark/baselines.R` | exact role/flow |
| `R/benchmark/challenger_runner.R` | create | orchestrator/service | chronological batch + file-I/O | `R/benchmark/runner.R` | exact role/flow |
| `R/evaluation/challenger_selection.R` | create | evaluation service | transform + batch | `R/evaluation/benchmark_scores.R` | role-match |
| `_targets.R` | modify | pipeline config | event-driven DAG + file-I/O | Phase 9 targets in `_targets.R` | exact |
| `tests/testthat/helper_statistical_challengers.R` | create | test helper | transform | `tests/testthat/helper_benchmark.R` | exact |
| `tests/testthat/test_statistical_penalized_poisson_design.R` | create | task-scoped test | batch | `test_benchmark_baselines.R` | role-match |
| `tests/testthat/test_statistical_penalized_poisson_tuning.R` | create | task-scoped test | chronological batch | `test_benchmark_cutoffs.R` | role-match |
| `tests/testthat/test_statistical_dynamic_state.R` | create | task-scoped test | event-driven chronological batch | `test_benchmark_cutoffs.R` | exact role/flow |
| `tests/testthat/test_statistical_dynamic_tuning.R` | create | task-scoped test | chronological batch | `test_benchmark_cutoffs.R` | role-match |
| `tests/testthat/test_statistical_dependence_pmf.R` | create | task-scoped test | transform | `test_benchmark_contracts.R` | role-match |
| `tests/testthat/test_statistical_dependence_parameters.R` | create | task-scoped test | chronological batch | `test_benchmark_cutoffs.R` | role-match |
| `tests/testthat/test_statistical_registry_protocol.R` | create | canonical mutation test | registry + chronology | `test_benchmark_pipeline.R`; `test_benchmark_promotion.R` | role-match |
| `tests/testthat/test_statistical_storage_preflight.R` | create | canonical mutation test | protocol + file-I/O | `test_benchmark_pipeline.R`; `test_benchmark_promotion.R` | role-match |
| `tests/testthat/test_statistical_ablation_hierarchy.R` | create | task-scoped test | batch | `test_benchmark_baselines.R` | role-match |
| `tests/testthat/test_statistical_adapter_dispatch.R` | create | task-scoped integration test | batch | `test_benchmark_contracts.R` | exact role/flow |
| `tests/testthat/test_statistical_ablation_selection.R` | create | task-scoped test | batch | `test_benchmark_scoring.R` | role-match |
| `tests/testthat/test_statistical_selection.R` | create | task-scoped integration test | batch | `test_benchmark_scoring.R` | role-match |
| `tests/testthat/test_statistical_bundle.R` | create | task-scoped integration test | batch + file-I/O | `test_benchmark_pipeline.R` | exact role/flow |
| `tests/testthat/test_statistical_targets.R` | create | task-scoped DAG test | pipeline graph | `test_benchmark_pipeline.R` | exact role/flow |
| `tests/testthat/phase10_core_coverage.R` | create | coverage gate | instrumentation | project covr patterns | role-match |
| `tests/testthat/phase10_coverage_exceptions.csv` | create | coverage exception evidence | registry | no exact analog | partial |

`R/forecast/poisson.R` need not change if the Elo-only predictor vector is kept private to `challengers.R`. If modified, add only a named predictor-set helper; do not alter the incumbent formula or fitter.

### Likely Generated Bundle Files

The research fixes the output root but leaves exact names to planning. Freeze these names before implementation, following `benchmark_output_paths()` (`R/benchmark/runner.R:14-28`):

| Likely Generated File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `outputs/benchmarks/rolling_tournaments/phase10-statistical-challengers/run_manifest.csv` | manifest | file-I/O | Phase 9 `run_manifest.csv` | exact |
| `.../manifests/model_manifests.csv` | manifest | file-I/O | Phase 9 model manifests | exact |
| `.../manifests/feature_coverage.csv` | evidence | file-I/O | Phase 9 feature coverage | exact |
| `.../manifests/fold_tuning.csv` | evidence/manifest | chronological batch | Phase 9 score-support audit | partial |
| `.../manifests/checksum_manifest.csv` | integrity manifest | file-I/O | Phase 9 checksum manifest | exact |
| `.../predictions/fixture_predictions.csv` | prediction artifact | batch | Phase 9 fixture predictions | exact |
| `.../predictions/score_distributions.csv` | prediction artifact | batch | Phase 9 score distributions | exact |
| `.../scores/fixture_scores.csv` | evaluation artifact | batch | Phase 9 fixture scores | exact |
| `.../scores/benchmark_summaries.csv` | evaluation artifact | batch | Phase 9 summaries | exact |
| `.../comparisons/all_baseline_paired_comparisons.csv` | evidence | batch | Phase 9 paired comparisons | role-match |
| `.../selection/shortlist.csv` (and optional rendered report) | handoff/report | batch + file-I/O | no safe exact analog; promotion decisions are out of scope | no exact analog |

The output bundle should reference the accepted Phase 9 bundle and registry hashes as checked inputs. It should not contain copied Phase 9 prediction or score-grid rows.

## Pattern Assignments

### `data/benchmark/phase10/model_registry.csv`

**Analog:** `data/benchmark/phase09/model_registry.csv`, loaded and hashed by `R/benchmark/registry.R`.

Copy the Phase 9 conventions of one immutable row per model, explicit adapter/formula/settings identifiers, canonical SHA-256 fields, and hard-coded dispatch. Extend rather than mutate the Phase 9 registry. Phase 10 rows should include at least `phase09_parent_registry_sha256`, `phase09_parent_bundle_sha256`, `candidate_id`, `adapter_id`, `native_panel_id`, `mean_model_id`, `dependence_id`, `tuning_protocol_id`, `feature_set_id`, `complexity_rank`, `settings_sha256`, and `registration_sha256`.

**Canonical row hashing pattern** (`R/benchmark/registry.R:83-113`):

```r
benchmark_row_sha256 <- function(data, hash_col = "row_sha256") {
  fields <- setdiff(names(data), hash_col)
  vapply(seq_len(nrow(data)), function(i) {
    values <- vapply(data[i, fields, drop = FALSE], benchmark_canonical_scalar, character(1))
    digest::digest(paste(values, collapse = "|"), algo = "sha256", serialize = FALSE)
  }, character(1))
}
```

**Validation/dispatch pattern:** validate required columns, unique `candidate_id`, parent hashes, row hashes, and allowlisted `adapter_id` before fitting. Copy the `switch()` allowlist shape from `fit_registered_baseline()` (`R/benchmark/baselines.R:232-264`); never use `eval(parse())` on registry text.

### `data/benchmark/phase10/feature_contract.csv`

**Analog:** `data/benchmark/phase09/feature_contract.csv` and `build_registered_feature_coverage()` (`R/benchmark/baselines.R:435-509`).

Preserve the Phase 9 schema dimensions: feature identity, source identity/hash, availability rule, imputation rule, missingness rule, allowed lag, license class, and row hash. Dynamic state/cold-start evidence may add registered features, but every prediction must still expand to its exact feature-contract rows.

**Evidence separation pattern** (`R/benchmark/contracts.R:287-331`):

```r
source_present <- as.logical(coverage$source_present)
value_present <- as.logical(coverage$value_present)
imputed <- as.logical(coverage$imputed)
active <- as.logical(coverage$active_in_fit)

if (any(value_present & !source_present & !derived_fixture)) {
  stop("Feature coverage source-absent values cannot masquerade as observations", call. = FALSE)
}
if (any(!value_present & !imputed)) {
  stop("Missing feature values must remain explicitly imputed", call. = FALSE)
}
```

For zero-coded xG/form columns, require `source_present = FALSE`, `value_present = FALSE`, `imputed = TRUE`, an explicit zero-coverage reason, and `active_in_fit = FALSE`. Numeric zero is the formula-compatible value, not evidence of an observation.

### `data/benchmark/phase10/tuning_editions.csv`

**Analog:** Phase 9 boundary registry and `R/benchmark/cutoffs.R`.

Represent chronology as data, not a runtime guess. Each row should identify the outer assessment edition, one eligible completed inner edition, the inner final date, the outer opener/cutoff, the objective track (`updating`), and an eligible-match-ID hash. Pre-2002 World Cups 1994/1998 and Euros 1996/2000 seed the first outer fold as researched.

**Strict prior selection** (`R/benchmark/cutoffs.R:81-93`):

```r
cutoff <- as.Date(cutoff)
dates <- as.Date(history[[date_col]])
eligible <- history[!is.na(dates) & dates < cutoff, , drop = FALSE]
eligible <- eligible[do.call(order, c(args, list(na.last = TRUE, method = "radix"))), , drop = FALSE]
```

**Same-date boundary contract** (`R/benchmark/cutoffs.R:112-126`): all fixtures on one date share one exclusive cutoff, sequences are contiguous, and each updating boundary links to its exact predecessor. The Phase 10 inner-fold validator should additionally require every inner edition to finish before the outer edition starts.

### `data/benchmark/phase10/tuning_grid.csv`

**Analog:** `build_score_support_audit()` (`R/benchmark/baselines.R:622-668`).

Plan 10-09 owns this artifact and its canonical validator. Use exact ordered rows, deterministic traversal, objective values, parent hashes, and row hashes. The locked specification has 13 ascending team-ridge values from `10^seq(-4,2,by=0.5)`, 13 ascending Elo-lasso values from `10^seq(-5,1,by=0.5)`, five pseudo-exposures `2,4,8,16,32` with 730-day half-life, then exact Dixon-Coles and bivariate-q bounded-continuous specifications. Select penalties/hyperparameters only from eligible inner editions and use deterministic strongest-shrinkage tie-breaking.

```r
candidates <- seq.int(model_registry$candidate_min[m], model_registry$candidate_max[m])
values <- vapply(candidates, evaluator, numeric(1))
audit$parent_hashes <- benchmark_support_parent_sha256(audit)
audit$row_hash <- benchmark_row_sha256(audit, "row_hash")
```

Unlike Phase 9 support selection, every value, dependence bound/policy, and row order is frozen. Canonical validation must compare exact content and recompute hashes, not merely recognize parameter IDs or SHA shape. Record one selected setting per outer fold and reuse it unchanged for frozen and updating tracks.

### `data/benchmark/phase10/ablation_registry.csv`

**Analog:** Phase 9 model registry; no exact ablation graph exists.

Use immutable rows with `ablation_id`, `parent_candidate_id`, `feature_block_id`, `retained_features`, `removed_features`, `activation_status`, `activation_reason`, `complexity_rank`, and row/settings hashes. Register only the scored level-one sibling `open_nb_elo_only_ablation`. Register deeper xG/form nodes as `not_activated_zero_coverage`; do not fit them.

The parent predictor block is fixed in `R/forecast/poisson.R:12-14`:

```r
baseline_goal_predictors <- function() {
  c("elo_diff", "xgf_ewma_diff", "xga_ewma_diff", "xgd_ewma_diff", "form_index_diff")
}
```

### `data/benchmark/phase10/selection_protocol.json`

**Analog:** Phase 9 protocol canonicalization and validation, not Phase 9 promotion semantics.

Copy checksum-backed JSON serialization (`R/evaluation/promotion.R:18-34`) and fail-fast required-field validation (`R/evaluation/promotion.R:76-90`). Freeze the practical-gain, tie, non-inferiority, supporting-score, calibration, fold-breadth, and stability thresholds before assessment results are inspected.

Do **not** copy `evaluate_promotion()` (`R/evaluation/promotion.R:451-470`), which emits `veto`, `retain_incumbent`, and `eligible_for_final_holdout`. Phase 10 protocol/output vocabulary should be research-only: `best_proper_score`, `simplest_non_inferior`, and `dependence_representative`, with evidence and reason fields but no `promote`, `release`, or final-holdout decision.

### `R/benchmark/challenger_protocol.R` and `data/benchmark/phase10/storage_preflight.csv`

**Analogs:** `R/benchmark/registry.R`, canonical promotion-protocol hashing in `R/evaluation/promotion.R`, and Phase 9 checksum/read-back validation.

Plan 10-09 exclusively owns canonical registry, chronology, grid, ablation, selection, no-promotion, and storage validation. `challengers.R` and the runner consume `load_and_validate_challenger_protocol()`; they do not redefine raw registry loaders or trust stored pass booleans. Canonical validators recompute row/settings/JSON hashes from non-hash content, assert the exact accepted Phase 9 bundle SHA `977e119dd17e1212d2bfc57da2e676b6ee9d16bfba8b6c9bdbf1a97d302db069` plus durable registry/checksum graph evidence, and reject missing, extra, reordered, or mutated values.

The chronology validator reconstructs the complete outer/inner relation from the four exact pre-2002 editions and Phase 9 tournaments, while the diagnostic executes only those pre-2002 rows and proves the frozen grid hash is unchanged. Selection validation checks exact numerical RPS, tie, supporting-score, calibration, fold-breadth, and stability thresholds; the complete ablation parent graph; exact shortlist order; and a recursive no-promotion/WC2026 boundary. Storage validation recomputes exact pilot cardinalities, schema/generator hashes, compressed bytes, projection operands, and free-space result.

### `R/forecast/penalized_poisson.R`

**Analog:** `R/benchmark/baselines.R` for long-form goal rows, fitter diagnostics, active/dropped predictors, and complete prediction behavior.

Use namespace-qualified `Matrix::`/`glmnet::` calls; do not attach packages inside model functions. Build two rows per match in the same signed-home/signed-away style as `fit_elo_goal_nb()` (`R/benchmark/baselines.R:174-196`):

```r
long <- rbind(
  data.frame(goals = home_goals, elo_difference_for_team = elo_diff, ...),
  data.frame(goals = away_goals, elo_difference_for_team = -elo_diff, ...)
)
```

Apply ridge (`alpha = 0`) to full attack/defence indicators with intercept/venue unpenalized. Fit the augmented Elo term in a second offset stage (`alpha = 1`, `intercept = FALSE`), so a zero Elo coefficient exactly recovers the minimal model. Freeze all factor levels using training plus assessment identities; unseen teams must map to zero team columns/global log effect rather than error or fixture loss.

**Fit failure pattern** (`R/benchmark/baselines.R:103-116`):

```r
fit <- tryCatch(
  glmnet::glmnet(...),
  error = function(error) structure(list(error = conditionMessage(error)), class = "challenger_fit_error")
)
if (inherits(fit, "challenger_fit_error")) {
  stop(label, " penalized-Poisson fit failed: ", fit$error, call. = FALSE)
}
```

Return a structured fit with candidate/model IDs, selected lambdas, active/dropped predictors, design levels, prior counts, shrinkage/cold-start diagnostics, fit row/date range, convergence state, package version, and settings/parent hashes. Do not silently fall back to another family.

### `R/forecast/dynamic_goal_ability.R`

**Analog:** `compute_goal_ability_features()` in `R/forecast/goal_ability.R`.

Copy the date-batched state-machine shape. Fixtures on a date are predicted from the pre-date snapshot; completed results are applied only after all same-date predictions. Existing code already follows that ordering (`R/forecast/goal_ability.R:234-284`).

```r
for (date_value in ordered_dates) {
  decay_to(date_value)
  fixture_rows <- fixtures_by_date[[as.character(as.Date(date_value))]]
  # predict every fixture from the unchanged snapshot
  ...
  same_day <- history_by_date[[as.character(as.Date(date_value))]]
  # update only after predictions
  ...
}
```

Reuse the project recency/importance convention (`R/forecast/goal_ability.R:60-67`) and evidence companion helper (`R/forecast/goal_ability.R:113-139`). Change the state mathematics to fixed global pseudo-exposure plus decayed team sufficient statistics so inactivity genuinely reverts effects toward zero/global mean. Preserve all history; do not reset at tournament cycles.

Cold-start lookup should copy the neutral fallback evidence shape (`R/forecast/goal_ability.R:200-231`): return a finite neutral value plus explicit `source_present`, `value_present`, `imputed`, and reason fields.

### `R/forecast/score_dependence.R`

**Analog:** score-grid construction in `R/benchmark/baselines.R:294-307`, followed by shared validation in `R/benchmark/contracts.R:64-122`.

This file is a novel statistical transform, but its output is not novel. It should accept fixed `mu_home`/`mu_away`, a dependence ID and one fold-frozen parameter; emit the canonical rectangular `0:G x 0:G` grid; normalize once; and let `derive_benchmark_markets()` produce every market.

```r
grid <- expand.grid(home_goals = 0:support_max, away_goals = 0:support_max)
grid$probability <- as.vector(raw / sum(raw))
grid$normalized <- TRUE
```

Required branches:

- independent Poisson;
- Dixon-Coles, modifying only 0-0, 0-1, 1-0, and 1-1 with a positivity-safe fold-global `rho`;
- bivariate Poisson with `kappa_i = q * min(mu_home_i, mu_away_i)`, adjusted independent components, `lgamma()` and log-sum-exp, and exact `q = 0` handling.

Persist and assert a shared `mean_prediction_hash` over `(outer_fold, track, boundary, fixture_id, mu_home, mu_away)` before generating all three sibling grids. `validate_benchmark_score_distributions()` then enforces finite nonnegative cells, complete support, one distribution per requested ID, audited tail, and unit mass (`R/benchmark/contracts.R:85-122`).

### `R/forecast/poisson.R` (conditional modification)

**Analog:** existing predictor-vector helpers at `R/forecast/poisson.R:8-33`.

If modified, add an exported or internal `elo_only_goal_predictors()` returning only `"elo_diff"`. Do not change `baseline_goal_predictors()`, `hybrid_goal_predictors()`, training defaults, or incumbent behavior. The ablation must use the same two-sided NB fitting path as `open_nb_incumbent`, not the distinct long-format `elo_goal_nb` model.

### `R/benchmark/challengers.R`

**Analog:** `run_registered_baseline_adapter()` (`R/benchmark/baselines.R:514-593`).

Keep the adapter boundary identical: one registration row, checked history, boundary fixtures, seed registry, support, run ID, frozen registry/overlay, and feature contract. Split fixtures by `boundary_id`, enforce one exclusive cutoff, fit/predict, then bind predictions, distributions, manifests, and feature evidence.

**Canonical output shape** (`R/benchmark/baselines.R:590-593`):

```r
list(
  predictions = predictions,
  distributions = distributions,
  manifests = manifests,
  feature_coverage = feature_coverage
)
```

Copy prediction columns exactly from `benchmark_prediction_columns()` (`R/benchmark/contracts.R:50-59`). Extend manifests/evidence with candidate-specific tuning, dependence, cold-start, and mean-hash facts, but do not replace common fields. Validate before returning.

Dispatch on allowlisted `adapter_id`, not arbitrary formula text. All seven candidates must use one shared market derivation and scorer; no candidate-specific scoring functions belong here.

### `R/benchmark/challenger_runner.R`

**Analog:** `R/benchmark/runner.R`.

Build a Phase 10 overlay runner rather than changing `run_rolling_tournament_benchmark()`. Reuse the frozen Phase 9 registries/panels, score support, feature contracts, cutoffs, seeds, validators, and scorer. Verify the accepted Phase 9 parent bundle hash before candidate work, then read only the Phase 9 artifacts needed for paired comparisons.

Important patterns to copy:

- canonical sorting/hashing before persistence (`R/benchmark/runner.R:60-115`);
- explicit parent graph hashes (`R/benchmark/runner.R:526-603`);
- exact panel projection and scoring (`R/benchmark/runner.R:1024-1067`);
- deterministic branch jobs and result binding (`R/benchmark/runner.R:1461-1517`);
- run-manifest runtime/package/contract fields (`R/benchmark/runner.R:1523-1554`).

For all-baseline evidence, generalize only the comparison loop. Phase 9 currently chooses one incumbent from panel identity (`R/benchmark/runner.R:1069-1081`):

```r
incumbent_id <- if (panel_id == "feature_rich") "production_hybrid_nb" else "open_nb_incumbent"
comparison <- make_paired_fold_comparisons(
  track_scores, challenger_id, incumbent_id, tournaments,
  expected_fixture_ids, seed = 920001L
)
```

Phase 10 should instead cross each candidate with all five baselines, projecting both sides to the explicit comparison panel first: 630 fixtures for the four open baselines and 609 for `production_hybrid_nb`. Assert fixture-ID equality before pairing.

Do not call `benchmark_runner_decisions()` or `evaluate_promotion()`. Feed paired evidence to `challenger_selection.R`.

### `R/evaluation/challenger_selection.R`

**Analog:** `R/evaluation/benchmark_scores.R`, especially `aggregate_benchmark_scores()` and `make_paired_fold_comparisons()`.

Do not reimplement proper scores. Reuse `score_benchmark_fixtures()`, fixed calibration, equal-tournament aggregation, exact paired fold deltas, leave-one-tournament-out diagnostics, and deterministic tournament bootstrap.

**Equal-tournament headline** (`R/evaluation/benchmark_scores.R:168-194`):

```r
tournaments <- do.call(rbind, lapply(expected_editions, function(edition) {
  ... estimate = mean(edition_rows$value) ...
}))
headline <- mean(tournaments$estimate)
```

**Exact pairing** (`R/evaluation/benchmark_scores.R:349-375`):

```r
if (!setequal(challenger$fixture_id, expected_fixture_ids) ||
    !setequal(incumbent$fixture_id, expected_fixture_ids)) {
  stop("Candidate and incumbent must contain the exact paired fixture set", call. = FALSE)
}
paired <- merge(challenger, incumbent, by = "fixture_id", sort = TRUE)
```

Selection output should be three non-exclusive slots with evidence/reason columns:

- lowest valid equal-tournament updating-track RPS;
- simplest candidate within the frozen non-inferiority margin and without vetoes;
- dependence representative, preferring Dixon-Coles under the frozen practical tie rule.

The independent Poisson candidate may remain preferred even while DC/BP occupies the research-representative slot. Never convert this shortlist into a promotion decision.

### `_targets.R`

**Analog:** isolated Phase 9 chain at `_targets.R:446-576`.

Add `glmnet` to `tar_option_set(packages = ...)` only after exact version preflight succeeds, and source the new forecast/benchmark/evaluation modules beside their Phase 9 peers (`_targets.R:49-57`). Follow the Phase 9 dependency chain:

```text
phase10 registry files
  -> validated overlay + verified Phase 9 parent
  -> tuning folds/grids
  -> candidate predictions/evidence/manifests
  -> shared scores
  -> all-baseline comparisons
  -> shortlist
  -> atomic bundle files
```

Use `format = "file"` for registry and final bundle targets. Keep Phase 9 targets unchanged and make Phase 10 depend on the durable Phase 9 bundle/hash rather than rerunning it. Do not add dashboard, network, refresh, WC2026, or promotion dependencies.

### `tests/testthat/helper_statistical_challengers.R`

**Analog:** `tests/testthat/helper_benchmark.R`.

Use deterministic small data-frame constructors, not fixtures loaded from mutable outputs. Follow the helper's conventions:

- one function per reusable synthetic object;
- explicit dates, identities, schema fields, and `stringsAsFactors = FALSE`;
- same-date rows and sparse/unseen team levels;
- fixed score-grid/PMF oracle fixtures;
- helpers return plain data frames/lists without hidden global state.

The Phase 9 helper constructs complete synthetic tournament/boundary graphs (`tests/testthat/helper_benchmark.R:16-168`) and explicit same-date history (`:170-190`). Add compact helpers for outer/inner folds, fixed sparse `Matrix` levels, independence/DC/BP oracle cells, cold-start fixtures, parent hashes, and a minimal Phase 10 bundle.

### `tests/testthat/test_statistical_penalized_poisson_design.R` and `test_statistical_penalized_poisson_tuning.R`

**Analogs:** `test_benchmark_baselines.R` and `test_benchmark_cutoffs.R`.

Copy the test-file bootstrap pattern (`test_benchmark_baselines.R:1-14`): `library(testthat)`, resolve `project_root`, source helpers/contracts/modules directly. The design file owns only ridge-protected blocks, centering, cold starts, and completeness. The tuning file separately owns nested means, zero-selectable Elo, exact canonical provenance, prior-edition tuning, shared settings, poisoning, manifest hashes, and baseline pairing. This split lets Plan 10-03 Task 1 pass before Task 2 symbols exist.

Poison outer-tournament outcomes and require predictions/tuning to remain unchanged. Follow the registry-drift failure style at `test_benchmark_baselines.R:138-160`.

### `tests/testthat/test_statistical_dynamic_state.R` and `test_statistical_dynamic_tuning.R`

**Analog:** `tests/testthat/test_benchmark_cutoffs.R:25-56`.

The key existing assertions are directly reusable:

```r
same_date <- split(updating, updating$assessment_date)
expect_true(all(vapply(same_date, function(x) length(unique(x$state_sha256)) == 1L, logical(1))))

first <- build_state(history, fixtures)
second <- build_state(history[rev(seq_len(nrow(history))), ], fixtures[rev(seq_len(nrow(fixtures))), ])
expect_identical(first, second)
```

The state file owns same-date effects, reversion, no reset/window, and sparse-team evidence. The tuning file separately owns the nested Elo sibling, prior-only hyperparameters, shared tracks, poisoning, and strict source cutoffs.

### `tests/testthat/test_statistical_dependence_pmf.R` and `test_statistical_dependence_parameters.R`

**Analogs:** `test_benchmark_contracts.R` distribution tests and `test_benchmark_baselines.R:99-118` grid tests.

Use hand-calculated cells and limiting cases in the PMF file; reserve prior-fit parameter and poisoning behavior for the parameter file. Assert:

- Dixon-Coles touches only the four low-score cells and all adjusted cells stay positive;
- `rho = 0` and `q = 0` recover independent Poisson;
- bivariate marginals recover the fixed penalized means;
- all three variants have identical `mean_prediction_hash` values;
- every fixture has complete `0:40` support, finite nonnegative probabilities, unit mass, and shared derived markets;
- dependence parameters are one per outer fold, prior-fit only, and identical across tracks.

Call `validate_benchmark_score_distributions()` rather than duplicating its checks.

### `tests/testthat/test_statistical_ablation_hierarchy.R`, `test_statistical_adapter_dispatch.R`, and `test_statistical_ablation_selection.R`

**Analogs:** predictor/manifests tests in `test_benchmark_baselines.R` and paired evidence in `test_benchmark_scoring.R:127-163`.

The hierarchy file asserts that the full incumbent and Elo-only sibling use the same two-sided NB fitter, rows, weights, panels, and cutoffs; only the predictor set differs. It requires xG/form values to remain zero-coded with source/value absence, imputation, and inactive-fit status, and deeper rows to stay `not_activated_zero_coverage`. The dispatch file owns only the seven common adapters. The selection file owns practical non-inferiority through out-of-sample RPS/supporting vetoes, never coefficient p-values.

### `tests/testthat/test_statistical_selection.R`, `test_statistical_bundle.R`, and `test_statistical_targets.R`

**Analog:** `tests/testthat/test_benchmark_pipeline.R`.

Copy these high-value patterns:

- write then semantically validate every durable artifact (`test_benchmark_pipeline.R:280-304`);
- reject missing rows and corrupted parent hashes (`:336-369`);
- canonical hashes ignore output roots and branch ordering (`:372-384`);
- reject WC2026 labels before adapter invocation (`:395-410`);
- statically reject network/refresh calls (`:413-423`);
- restore the old bundle after failed post-install validation (`:675-696`);
- inspect the targets dependency graph (`:698-727`).

The selection file owns exact all-baseline evidence and shortlist rules. The bundle file owns the accepted Phase 9 parent hash, seven candidates, both tracks, exact 630/609 denominators, G=40, fresh-session deterministic registry/manifest/prediction/score/evidence/comparison/shortlist hashes, no `evaluate_promotion()` call, and no Phase 10 promotion artifact. The targets file separately owns exact target names and forbidden ancestry so Plan 10-07 Task 2 can pass before Task 3 symbols exist.

### `tests/testthat/test_statistical_registry_protocol.R` and `test_statistical_storage_preflight.R`

**Analogs:** mutation matrices in `test_benchmark_pipeline.R` and exact protocol boundary tests in `test_benchmark_promotion.R`.

These are Plan 10-09-owned test files, not Wave 0 production-family tests. The registry file deletes, inserts, reorders, mutates, and substitutes valid-shape hashes across parent, candidate, feature, tuning-grid, and complete 114-row chronology artifacts, then executes/asserts the pre-2002 diagnostic. The storage file applies the same fail-closed matrix to the complete ablation graph, exact threshold/shortlist/no-promotion protocol, and every storage projection operand/hash. Task 1 and Task 2 remain independently runnable.

### Generated Phase 10 Bundle

**Analog:** `benchmark_output_paths()`, `write_rolling_benchmark_bundle()`, and checksum/read-back validation in `R/benchmark/runner.R`.

Every generated table should be canonically sorted and written with `row.names = FALSE`, `na = ""`, and quoted CSV (`R/benchmark/runner.R:111-115`). The checksum manifest records path, role, byte/file hash, canonical content hash, rows, producer, source git SHA, parent hashes, and selected G (`R/benchmark/runner.R:526-603`).

Atomic publication must validate staging before replacement and validate again after installation. Copy rollback semantics from `benchmark_runner_install_staged_bundle()` (`R/benchmark/runner.R:1408-1441`): rename the existing bundle to a backup, install staged output, restore the backup on failed read-back validation, and remove the backup only after success.

Because score grids dominate storage, Plan 10-09 Task 2 runs in Wave 1 and generates a deterministic, format-identical, conservatively low-compressibility pilot before the full seven-candidate run. The pilot contains 630 fixtures x 2 tracks x 41 x 41 = 2,118,060 score rows. If `B` is its measured compressed size, freeze `score_projection = 7 * B`, `one_bundle_projection = score_projection + max(1 GiB, ceiling(0.25 * score_projection))`, and `minimum_free_bytes = ceiling(3 * one_bundle_projection * 1.10)` in `storage_preflight.csv`; no provisional fixed-GiB threshold remains.

## Shared Phase 9 Contracts To Reuse Unchanged

### Frozen Parent And Phase Boundary

- Accepted Phase 9 bundle SHA-256: `977e119dd17e1212d2bfc57da2e676b6ee9d16bfba8b6c9bdbf1a97d302db069` (`09-VERIFICATION.md:26-30`). Verify it and the Phase 9 registry/settings parents before fitting and publication.
- Development panel: exactly 12 tournaments and 630 open fixtures; rich comparisons use exactly 609 fixtures (`09-VERIFICATION.md:34-42`, `83-88`).
- Tracks: one pre-opener frozen track and date-batched updating track with strict exclusive cutoffs (`R/benchmark/cutoffs.R:27-72`, `103-134`).
- Sealed holdout: call `guard_benchmark_purpose(history, "candidate_selection")` before any callback; WC2026 labels are forbidden (`R/benchmark/cutoffs.R:194-240`).

### Prediction And Score-Grid Contract

- Emit every field in `benchmark_prediction_columns()` (`R/benchmark/contracts.R:50-59`).
- Emit one normalized complete `0:40 x 0:40` joint score distribution per prediction and derive all markets through `derive_benchmark_markets()` (`R/benchmark/contracts.R:64-122`).
- `validate_benchmark_predictions()` enforces exact fixtures, identity, seeds, cutoff ordering, grids, and market reconciliation (`R/benchmark/contracts.R:155-203`).
- Namespace distribution IDs by candidate and track before binding, following `benchmark_runner_namespace_adapter_output()` (`R/benchmark/runner.R:958-965`).

### Manifest And Feature Evidence Contract

- Preserve Phase 9 manifest fields and strict pre-cutoff dates (`R/benchmark/contracts.R:208-237`). Add tuning/dependence/cold-start fields without removing common fields.
- Preserve one exact registered feature row per prediction-feature key and prediction foreign keys into evidence groups (`R/benchmark/contracts.R:242-375`).
- Keep source presence, numeric value presence, imputation, active fit, output coverage, and license/provenance as independent dimensions.

### Scoring And Evidence Contract

- Reuse `score_benchmark_fixtures()` for RPS, Brier, log loss, scoreline log loss, goal RPS, totals, BTTS, and exact-score evidence (`R/evaluation/benchmark_scores.R:36-143`).
- Aggregate within each tournament before the equal-tournament headline (`:151-199`).
- Use fixed shared calibration bins (`:203-293`).
- Pair exact fixture IDs, retain all 12 fold deltas, and use the registered deterministic 10,000-tournament bootstrap (`:297-398`).

### Error Handling And Validation

R modules use fail-fast `stop(..., call. = FALSE)` for schema, key, hash, date, probability, convergence, and coverage failures. Optional model complexity must never turn a failed candidate into a silent fallback or dropped fixture. Model-specific numerical errors may be captured with `tryCatch()` only to add context, then must fail the candidate explicitly.

### Imports And Package Use

Production modules generally use namespace-qualified calls (`stats::`, `utils::`, `digest::`, `MASS::`) and `_targets.R` sources project modules explicitly. Follow that style with `Matrix::` and `glmnet::`. Tests use `library(testthat)` and direct `source(file.path(project_root, ...))` calls.

### No Authentication Pattern

This is a local analytical pipeline; no authentication, session, controller, or network middleware pattern applies. Security-relevant reuse is path confinement, schema validation, hard-coded adapter dispatch, parent hashing, holdout sealing, bounded numerical parameters, and atomic publication.

## No Exact Analog Found

| File/Concern | Role | Data Flow | Planner Guidance |
|---|---|---|---|
| `R/forecast/penalized_poisson.R` optimizer composition | model | batch transform | Use research's two-stage `glmnet` design; wrap it in Phase 9 fit/manifests/error conventions. |
| `R/forecast/score_dependence.R` DC/BP mathematics | model utility | transform | Use researched formulas and PMF oracle tests; emit the existing grid schema. |
| `data/benchmark/phase10/tuning_editions.csv` inner-tournament relation | config | chronological batch | Extend Phase 9 strict-cutoff registry/hash pattern; no random CV analogue exists. |
| `.../selection/shortlist.csv` | evaluation handoff | batch | Implement a research-only three-slot selector; explicitly avoid the promotion evaluator and vocabulary. |

## Metadata

**Analog search scope:** `R/benchmark/`, `R/evaluation/`, `R/forecast/`, `_targets.R`, `tests/testthat/`, `data/benchmark/phase09/`, Phase 9 context/verification, and the accepted Phase 9 bundle layout.  
**Primary analogs:** `R/benchmark/registry.R`, `R/benchmark/cutoffs.R`, `R/benchmark/contracts.R`, `R/benchmark/baselines.R`, `R/benchmark/runner.R`, `R/evaluation/benchmark_scores.R`, and `R/forecast/goal_ability.R`.  
**Test analogs:** `helper_benchmark.R`, benchmark cutoff/baseline/contract/scoring/pipeline tests.  
**Pattern extraction date:** 2026-07-22.
