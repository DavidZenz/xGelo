# Phase 12: Calibration, Promotion, and Model Release - Pattern Map

**Mapped:** 2026-08-10
**Files analyzed:** 17 likely new/modified files
**Analogs found:** 17 / 17 (exact or partial; no exact analog for the new calibration and release-authority seams)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `R/calibration/inner_oof.R` | service / utility | transform, request-response | `R/benchmark/cutoffs.R` + `R/benchmark/hybrid_runner.R` | role/data-flow partial |
| `R/calibration/probability_calibration.R` | service / model utility | transform | `R/evaluation/proper_scores.R` + legacy `R/forecast/calibration.R` | partial; no chronology-safe fit analog |
| `R/calibration/calibration_selection.R` | evaluation service | CRUD/aggregation, request-response | `R/evaluation/benchmark_scores.R` + `R/evaluation/promotion.R` | role/data-flow strong |
| `R/evaluation/benchmark_scores.R` | evaluation service | request-response, aggregation | existing file | exact |
| `R/release/freeze_manifest.R` | manifest/config service | batch, file I/O | `R/benchmark/runner.R` + `R/benchmark/hybrid_runner.R` | role/data-flow strong |
| `R/release/final_evaluation.R` | service / controller | request-response, file I/O | `R/benchmark/cutoffs.R` + `R/benchmark/runner.R` | role-match; one-shot opener is new |
| `R/release/release_contract.R` | config / provider | request-response, file I/O | `R/benchmark/runner.R` checksum validation + dashboard loading | partial; no approved resolver exists |
| `R/release/release_bundle.R` | service / publisher | file I/O, batch | `R/benchmark/runner.R` staged install | exact publication pattern |
| `_targets.R` | config / orchestration | request-response dependency graph, file I/O | existing Phase 9/11 target chains | exact |
| `R/visualization/worldcup_dashboard.R` | consumer / export | request-response, file I/O | existing dashboard model loading | role/data-flow exact, authority gap |
| `tests/testthat/test_phase12_calibration.R` | test | transform/evaluation regression | `tests/testthat/test_benchmark_scoring.R` + `test_benchmark_seal.R` | strong |
| `tests/testthat/test_phase12_freeze.R` | test | batch/manifest contract | `tests/testthat/test_benchmark_pipeline.R` + `test_hybrid_targets.R` | strong |
| `tests/testthat/test_phase12_final_evaluation.R` | test | request-response/file I/O negative path | `tests/testthat/test_benchmark_seal.R` + staged-install test in `test_benchmark_pipeline.R` | strong |
| `tests/testthat/test_phase12_release.R` | test | request-response/file I/O | `tests/testthat/test_worldcup_dashboard.R` + `test_benchmark_pipeline.R` | strong |
| `tests/testthat/test_worldcup_dashboard.R` | test (extended) | presentation/export regression | existing file | exact consumer regression harness |

The research names four new calibration/release directories and four focused Phase 12 test files. It also requires extending the shared scorer, targets boundary, dashboard/export loading, and inherited regression coverage. Keep the exact nine Phase 11 candidate rows, including inactive/no-score rows, in every Phase 12 registry/report.

## Pattern Assignments

### `R/calibration/inner_oof.R` (service/utility, transform)

**Analog:** `R/benchmark/cutoffs.R` lines 80-137, 154-191, 220-239; `R/benchmark/hybrid_runner.R` lines 712-810.

The analog supplies chronology and guard semantics, not the calibrator itself. Assemble candidate/track-specific rows with `outer_edition_id`, `inner_edition_id`, `fixture_id`, exclusive cutoff, raw 1X2 probabilities, observed class, source prediction hash, and seed. Assert `inner_edition_id` is strictly prior to the outer edition and invoke the existing purpose guard before fitting.

**Cutoff/holdout pattern** (`R/benchmark/cutoffs.R:220-239`):

```r
guard_benchmark_purpose <- function(data, purpose, adapter = NULL) {
  development_purposes <- c(
    "development", "baseline_reproduction", "candidate_selection",
    "fit", "feature_selection", "tuning", "calibration"
  )
  allowed_purposes <- c(development_purposes, "sealed_evaluation", "reporting")
  if (length(purpose) != 1L || is.na(purpose) || !purpose %in% allowed_purposes) {
    stop("Unknown benchmark purpose", call. = FALSE)
  }
  if (!is.data.frame(data)) stop("Benchmark purpose guard requires a data frame", call. = FALSE)
  holdout <- benchmark_holdout_rows(data)
  labels <- benchmark_outcome_columns(data)
  label_present <- function(column) {
    values <- data[[column]][holdout]
    if (is.logical(values)) return(any(!is.na(values)))
    any(!is.na(values) & nzchar(as.character(values)))
  }
  if (purpose %in% development_purposes && any(holdout) && length(labels) &&
      any(vapply(labels, label_present, logical(1)))) {
    stop("Sealed wc2026 outcome labels are forbidden for benchmark development purposes", call. = FALSE)
  }
  if (!is.null(adapter)) return(adapter(data))
  data
}
```

**Boundary pattern** (`R/benchmark/cutoffs.R:154-191`): use the existing eligible-history/boundary functions so all inner rows prove outcomes precede `evidence_cutoff_exclusive`; do not infer chronology from row order alone.

**Candidate/track routing pattern** (`R/benchmark/hybrid_runner.R:748-810`): validate the exact registered candidate order, require non-empty explicit `track_id`, normalize identifiers, and slice seed registries by fixture IDs before invoking adapters. Preserve inactive adapter results rather than filtering them out.

**Required Phase 12 schema:**

```r
inner_oof <- data.frame(
  candidate_id = character(), track_id = character(),
  outer_edition_id = character(), inner_edition_id = character(),
  fixture_id = character(), evidence_cutoff_exclusive = as.Date(character()),
  p_home_raw = numeric(), p_draw_raw = numeric(), p_away_raw = numeric(),
  observed_class = character(), source_prediction_sha256 = character(),
  stringsAsFactors = FALSE
)
```

No exact analog exists for fitting a chronology-safe calibrator. Planner should use the existing cutoff guard and explicitly test first-fold fallback, strict prior-edition filtering, source hashes, and absence of WC2026 labels.

---

### `R/calibration/probability_calibration.R` (service/model utility, transform)

**Analog:** `R/evaluation/proper_scores.R` lines 3-14, 17-21, 30-69; legacy `R/forecast/calibration.R` lines 19-40 and 48-84.

Use the proper-score validator as the probability contract. The legacy helper is only a negative/partial analog: it simulates a sample, calibrates draw probability only, and has no OOF, candidate, track, outer-fold, or holdout semantics. Do not copy its fitting workflow.

**Simplex validation pattern** (`R/evaluation/proper_scores.R:3-14`):

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

**Scoring primitive pattern** (`R/evaluation/proper_scores.R:47-68`): preserve the fixed `home`, `draw`, `away` class order for RPS, validate named classes, and use epsilon only for log-loss stability. The new calibrator changes only the derived 1X2 vector; the fitted G=40 joint score distribution remains untouched.

**Legacy warning** (`R/forecast/calibration.R:48-66`): the existing `calibrate_model()` computes simulated draw predictions and a draw-only Brier score. It is diagnostic-only and must not become the Phase 12 calibration contract.

**Required artifact pattern:** persist a calibrator object plus a manifest row containing candidate/track/outer edition, prior inner editions, row and class counts, recipe hash, seed, fit status, source prediction hash, maximum inner evidence date, and `primary_probability_view`. On insufficient prior history/class support, return an explicit raw fallback rather than fitting an unstable object.

---

### `R/calibration/calibration_selection.R` (evaluation service, aggregation/request-response)

**Analog:** `R/evaluation/benchmark_scores.R` lines 36-143, 151-199, 203-292; `R/evaluation/promotion.R` lines 351-471.

Score raw and calibrated predictions as separate views against identical fixture IDs and the same distributions/labels. Aggregate within tournament first and use equal-tournament headlines. Feed the resulting development evidence into the frozen Phase 9 gate evaluator rather than a new threshold table.

**Shared scorer contract** (`R/evaluation/benchmark_scores.R:36-67`):

```r
score_benchmark_fixtures <- function(predictions, fixtures, distributions, expected_fixture_ids) {
  prediction_columns <- c(
    "run_id", "model_id", "panel_id", "edition_id", "track_id", "fixture_id",
    "score_distribution_id", "p_home", "p_draw", "p_away", "p_over_2_5",
    "p_under_2_5", "p_btts", "prediction_status"
  )
  benchmark_score_require_columns(predictions, prediction_columns, "Benchmark predictions")
  benchmark_score_require_columns(fixtures, fixture_columns, "Benchmark fixtures")
  expected_fixture_ids <- as.character(expected_fixture_ids)
  if (!length(expected_fixture_ids) || anyDuplicated(expected_fixture_ids)) {
    stop("expected_fixture_ids must contain unique declared fixture IDs", call. = FALSE)
  }
  ...
}
```

The scorer rejects missing/duplicate fixture IDs, non-score-eligible fixtures, incomplete prediction status, edition mismatches, missing distributions, and invalid distributions. Copy that fail-closed behavior into raw/calibrated view assembly; never silently shrink denominators.

**Equal-tournament aggregation** (`R/evaluation/benchmark_scores.R:151-198`):

```r
rows <- rows[rows$covered & is.finite(rows$value), , drop = FALSE]
if (!setequal(unique(as.character(rows$edition_id)), expected_editions)) {
  stop("Headline aggregation requires every registered tournament", call. = FALSE)
}
...
estimate = mean(tournaments$estimate), aggregation = "equal_tournament"
```

**Frozen policy authority** (`R/evaluation/promotion.R:451-471`):

```r
evaluate_promotion <- function(candidate, protocol) {
  gate_values <- promotion_gate_values(candidate, protocol)
  gate_passes <- promotion_gate_passes(candidate, protocol)
  reasons <- unname(promotion_gate_reason_map()[names(gate_passes)[!unlist(gate_passes, use.names = FALSE)]])
  hard_failure <- any(reasons %in% promotion_hard_reason_codes())
  decision <- if (hard_failure) "veto" else if (length(reasons)) "retain_incumbent" else "eligible_for_final_holdout"
  list(candidate_id = candidate$candidate_id, incumbent_id = candidate$incumbent_id,
       decision = decision, reason_codes = reasons, gate_values = gate_values,
       gate_passes = gate_passes)
}
```

Use `load_promotion_protocol()`, `validate_promotion_protocol()`, `evaluate_promotion()`, and `select_promoted_candidate()`; do not restate the RPS, CI, breadth, regression, Brier/log-loss, calibration, contract, G=40, or 12-fold thresholds.

---

### `R/evaluation/benchmark_scores.R` (evaluation service, request-response/aggregation)

**Analog:** the existing file itself, especially `score_benchmark_fixtures()` lines 36-143 and `fixed_benchmark_calibration()` lines 203-292.

Extend or compose the existing contract so raw and calibrated 1X2 columns can be scored under a view/model identity. Preserve metric names, `target = "regulation_1x2"`, exact registered fixture sets, fixed-bin calibration, proper scores, and the unchanged scoreline distribution. Do not create a Phase 12 parallel scorer.

**Fixed-bin calibration pattern** (`R/evaluation/benchmark_scores.R:230-292`): group by run/model/panel/track, require exact fixture IDs and complete `prediction_status`, derive one-vs-rest observations, assign fixed ten bins, mark sparse bins, and persist class-specific plus aggregate calibration errors.

**Paired fold pattern** (`R/evaluation/benchmark_scores.R:351-397`): pair challenger/incumbent by exact fixture IDs, compute tournament fold deltas, require all 12 editions, derive improvement breadth and maximum regression, then use the registered deterministic bootstrap seed. This is the evidence shape for raw-vs-calibrated regression reporting.

---

### `R/release/freeze_manifest.R` (manifest/config service, batch/file I/O)

**Analog:** `R/benchmark/runner.R:526-603` and `R/benchmark/hybrid_runner.R:63-105, 108-138`; parent loader `R/benchmark/challenger_runner.R:194-260`.

Create one authoritative aggregate freeze manifest after preflight and before any calibrator fit. Include all nine Phase 11 candidate registrations (active and inactive), code commit/dirty state, registration/settings/features/panels/seeds/calibration/threshold hashes, Phase 9/10/11 parent identities, selected `G = 40`, WC2026 seal, runtime/package versions, and a self-hash.

**Manifest row pattern** (`R/benchmark/runner.R:526-544`): store artifact name, relative path, artifact role, file SHA-256, canonical content SHA-256, row count/bytes, producer, source git SHA, parent hash, and selected G.

**Parent graph/self-hash pattern** (`R/benchmark/runner.R:549-601`): sort named input hashes, hash their joined values into one parent graph identity, append external input rows, sort canonically, compute the manifest body self-hash, append a `checksum_manifest` self row, and write with the canonical CSV writer.

**Phase 11 parent identity pattern** (`R/benchmark/hybrid_runner.R:63-105`): parent paths are named by stable identities; missing parents receive deterministic absent hashes; existing files use `digest::digest(path, algo = "sha256", file = TRUE)`. Reuse this rather than inventing a new hash convention.

**Parent admissibility pattern** (`R/benchmark/challenger_runner.R:200-260`): normalize the requested root, reject paths outside the approved durable root, read the parent checksum manifest, verify exact panel counts/editions/baselines, and return parent hashes plus durable artifact paths.

**Phase 11 candidate/status pattern:** `R/benchmark/hybrid_runner.R:794-801` preserves an inactive adapter result as the combined result. `R/benchmark/hybrid_protocol.R:413-444` validates `active_status`, `score_status`, `inactive_reason`, source hashes, and `wc2026_sealed`. Carry these fields into the freeze and final registry; inactive rows must remain explicit no-score rows.

---

### `R/release/final_evaluation.R` (service/controller, request-response/file I/O)

**Analog:** `R/benchmark/cutoffs.R:194-239`, `tests/testthat/test_benchmark_seal.R:7-50`, and `R/benchmark/runner.R:1414-1448`.

Implement a label-free preflight followed by exactly one application-level label-opening boundary. Preflight validates the freeze hash, all admissibility rows, contracts, calibration selection, and unopened state. Only the opener may read WC2026 outcome columns; it copies labels to an immutable final-evaluation artifact, records label hash/timestamp, and exposes that copy only to scoring/reporting.

**Holdout detection/guard excerpt** (`R/benchmark/cutoffs.R:194-239`): the existing `benchmark_holdout_rows()` identifies `edition_id == "wc2026"`, `fixture_id` beginning with `wc2026`, and 2026 World Cup competition/year; `guard_benchmark_purpose()` rejects non-reporting label-bearing data before an adapter callback. Use this guard in calibration/development and a separate sealed-evaluation purpose for the opener.

**Negative-path test pattern** (`tests/testthat/test_benchmark_seal.R:7-22`): loop every development purpose, pass a recording adapter, expect an error mentioning WC2026/sealed/outcome, and assert the adapter call count remains zero. Add equivalent tests for preflight failure and second label opening.

**One-shot state requirement:** do not rely on `targets` freshness. Persist an append-only final-evaluation manifest with freeze hash, label hash, run timestamp, candidate/prediction/score hashes, coverage, and promotion decision; reject an existing consumed-label record or any hash mismatch.

---

### `R/release/release_contract.R` (config/provider, request-response/file I/O)

**Analog:** `R/benchmark/runner.R:656-712` checksum validation plus current dashboard loading in `R/visualization/worldcup_dashboard.R:350-368, 1032-1073`.

There is no existing approved-release resolver. Add one trusted-root resolver used by dashboard and exports. It must reject missing/ambiguous/non-approved manifests, unsafe paths, wrong release status, wrong candidate/model ID, missing artifacts, contract schema drift, G/panel/settings/feature mismatch, and every declared SHA-256 mismatch before loading model/calibrator objects.

**Checksum validation pattern** (`R/benchmark/runner.R:656-712`): require the manifest schema, reject duplicate/missing artifacts, compare file and canonical-content hashes, compare row counts, recompute external input hashes and the parent graph, then recompute the checksum manifest self-hash. Use `stop()` for every mismatch.

**Current unsafe consumer pattern to replace** (`R/visualization/worldcup_dashboard.R:350-368`):

```r
if (is.null(get_extra_arg("home_model"))) {
  home_model_path <- if (!is.null(get_extra_arg("home_model_path"))) get_extra_arg("home_model_path") else "models/home_goal_model.rds"
  if (file.exists(home_model_path)) extra_args$home_model <- readRDS(home_model_path)
}
```

The resolver must replace existence-based loading; a missing or mismatched release must fail closed rather than fall back to baseline/latest paths.

---

### `R/release/release_bundle.R` (service/publisher, file I/O/batch)

**Analog:** `R/benchmark/runner.R:607-648, 1414-1448`; `R/benchmark/hybrid_runner.R:1207-1289`.

Stage the complete release in a unique sibling temporary directory, write model object, calibrator, model contract, freeze/final manifests, benchmark report, model card, provenance, limitations, and reproducibility metadata; validate from the staged root; atomically install; validate again; restore the prior release if post-install validation fails.

**Atomic install excerpt** (`R/benchmark/runner.R:1414-1448`):

```r
invisible(validator(staged_root))
had_existing <- dir.exists(output_dir)
if (had_existing) {
  backup_root <- tempfile(paste0(".", basename(output_dir), "-backup-"), tmpdir = dirname(output_dir))
  if (!file.rename(output_dir, backup_root)) stop("Could not stage the existing benchmark bundle for replacement", call. = FALSE)
}
if (!file.rename(staged_root, output_dir)) {
  if (had_existing) file.rename(backup_root, output_dir)
  stop("Could not install the reconciled benchmark bundle", call. = FALSE)
}
validation <- tryCatch(validator(output_dir), error = function(error) {
  if (dir.exists(output_dir)) unlink(output_dir, recursive = TRUE)
  restored <- !had_existing || file.rename(backup_root, output_dir)
  if (!restored) stop("Installed benchmark validation failed and the sealed backup could not be restored: ", conditionMessage(error), call. = FALSE)
  stop(error)
})
```

**Phase 11 staged shape** (`R/benchmark/hybrid_runner.R:1207-1257`): write each artifact under a relative path, hash the persisted file, record row count/required flag/parent graph/G/panel counts, then add a checksum self-row. The Phase 12 release manifest should additionally encode exactly `challenger approved` or `incumbent retained`; alternatives remain audit-only.

---

### `_targets.R` (orchestration/config, request-response dependency graph/file I/O)

**Analog:** existing target source/import boundary lines 34-86, dashboard target lines 448-478, Phase 11 bundle target lines 911-946, and Phase 9 test expectations in `tests/testthat/test_benchmark_pipeline.R:698-727`.

Source the new Phase 12 scripts after the inherited evaluation/benchmark modules. Keep the durable chain file-oriented and structurally downstream:

```text
Phase 9/10/11 parents
  -> preflight
  -> freeze manifest
  -> inner-OOF calibration
  -> development raw/calibrated gate
  -> final pre-label gate
  -> one-shot WC2026 evaluation
  -> promotion report
  -> staged release bundle
  -> approved consumer/dashboard/export targets
```

**File target pattern** (`_targets.R:934-946`):

```r
tar_target(
  benchmark_phase11_bundle_files,
  {
    benchmark_phase11_comparisons
    write_hybrid_challenger_bundle(
      benchmark_phase11_predictions,
      "outputs/benchmarks/rolling_tournaments/phase11-hybrid-challengers"
    )
    unname(hybrid_output_paths("outputs/benchmarks/rolling_tournaments/phase11-hybrid-challengers"))
  },
  format = "file"
)
```

Use `format = "file"` for manifests, final-evaluation artifacts, reports, model contracts, and release files. Ensure no label-bearing source is an ancestor of freeze/calibration targets; only the final-evaluation opener may consume labels.

**Current dashboard gap** (`_targets.R:449-475`): it chooses hybrid versus baseline by file existence and passes raw `.rds` paths. Replace this with the approved release resolver target and make both dashboard and export outputs depend on the validated contract.

---

### `R/visualization/worldcup_dashboard.R` (consumer/export, request-response/file I/O)

**Analog:** existing `forecast_dashboard_matches()` lines 350-415, `make_knockout_route_estimator()` lines 1032-1073, `build_worldcup_dashboard_data()` lines 2977-3035, and `build_worldcup_dashboard()` lines 4394-4437.

Change the consumer boundary, not the simulation/data shape. Resolve an approved release contract first, verify hashes, then pass loaded model/calibrator objects and explicit `model_version`/`primary_probability_view` into dashboard and CSV export generation. Preserve deterministic `set.seed()` behavior and existing output schemas.

**Current loader contract:** `make_knockout_route_estimator()` checks model/Elo paths, `readRDS()` loads both models, derives a version from `xgelo_model_version`, and optionally reads feature CSV. Phase 12 should put the manifest resolver before these operations and prohibit arbitrary path arguments for production consumption.

**Regression target:** dashboard match cards/CSV exports may expose calibrated 1X2 as primary only if the contract says so; scoreline/tournament simulation must continue using the unchanged G=40 joint distribution. Include release ID, model ID, contract hash, and probability-view metadata in exports where the existing schema permits.

---

### `tests/testthat/test_phase12_calibration.R` (test, transform/evaluation)

**Analog:** `tests/testthat/test_benchmark_scoring.R:33-104, 127-224` and `tests/testthat/test_benchmark_seal.R:7-50`.

Source the Phase 12 calibration files plus existing proper/scoring/cutoff modules. Use synthetic inner OOF and fixture rows. Assert chronology, candidate/track isolation, cutoff safety, simplex validity, raw/calibrated identical fixture IDs, unchanged distributions, shared RPS/Brier/log-loss scoring, fixed-bin calibration diagnostics, and explicit raw fallback when history/support is insufficient. Add WC2026 label rows and assert the recording adapter is never called.

**Scoring test pattern** (`tests/testthat/test_benchmark_scoring.R:33-104`): call `score_benchmark_fixtures()` with exact IDs, inspect hand-calculated metrics, then assert errors when fixture coverage shrinks; call `aggregate_benchmark_scores()` and `fixed_benchmark_calibration()` to verify equal-tournament weighting and sparse-bin flags.

---

### `tests/testthat/test_phase12_freeze.R` (test, batch/manifest contract)

**Analog:** `tests/testthat/test_hybrid_targets.R:43-104` and `tests/testthat/test_benchmark_pipeline.R:639-696`.

Build a nine-row synthetic candidate registry with inactive/no-score entries. Assert the freeze contains every candidate and all required hashes/parent identities, selected G=40, seed/calibration/threshold identities, clean/dirty code status, and self-hash. Mutate a candidate, panel, parent, recipe, inactive status, or threshold and expect a fail-closed drift error.

**Phase 11 contract test pattern** (`tests/testthat/test_hybrid_targets.R:43-82`): inspect target commands and runner source for explicit candidate/parent paths, exact `open_fixture_count = 630L`, `rich_fixture_count = 609L`, `selected_g = 40L`, `wc2026_sealed = TRUE`, `network_free = TRUE`, and research-only flags. Reuse the style, but assert Phase 12 decision authority is enabled only after freeze/final evaluation.

---

### `tests/testthat/test_phase12_final_evaluation.R` (test, request-response/file I/O)

**Analog:** `tests/testthat/test_benchmark_seal.R:7-50` and `tests/testthat/test_benchmark_pipeline.R:675-696`.

Cover preflight failure before label access, exactly one label opening, immutable copied label artifact, append-only manifest, freeze/label/prediction/score hashes, all nine final registry rows, and explicit `incumbent retained` fallback with challenger gate failures. Re-run the opener and expect a second-open/consumed-label error. Tamper with copied labels, predictions, scores, coverage, or promotion decision and expect validation failure.

**Rollback test pattern** (`tests/testthat/test_benchmark_pipeline.R:675-696`): a validator fails on post-install read-back; assert the original sealed directory is restored and the staged directory is gone. Apply the same to the release/final-evaluation publication path.

---

### `tests/testthat/test_phase12_release.R` (test, request-response/file I/O)

**Analog:** `tests/testthat/test_worldcup_dashboard.R:564-718` and the checksum/tamper tests in `tests/testthat/test_benchmark_pipeline.R:639-696`.

Create a temporary complete release with a small constant goal model, contract, manifests, and hashes. Assert fresh-process resolver success, dashboard/export output generation, deterministic output, and rejection of missing manifest, non-approved status, mismatched model/contract hash, wrong G, candidate/settings/features/panel mismatch, unsafe paths, and stale/ambiguous release roots.

**Dashboard regression shape** (`tests/testthat/test_worldcup_dashboard.R:600-636`): build the dashboard from temporary model/feature/Elo artifacts, assert HTML/data files and export rows exist, then retain the existing output-shape assertions. Add manifest-only setup and fail-closed cases around the existing fixture.

---

### `tests/testthat/test_worldcup_dashboard.R` (test, presentation/export regression)

**Analog:** existing file, especially lines 564-718.

Extend rather than replace the broad dashboard regression. Keep assertions for 72 fixtures, 48 group rows, 33 bracket rows, valid probability sums, output files, and deterministic seeds. Add assertions that dashboard generation uses the approved release ID/model contract and fails before output generation when the release manifest or declared model hash is invalid.

## Shared Patterns

### Fail-closed validation

**Sources:** `R/benchmark/cutoffs.R:220-239`; `R/evaluation/benchmark_scores.R:3-8, 48-67`; `R/evaluation/promotion.R:424-471`.

Validate type/schema/IDs before computation, reject malformed/missing/mismatched artifacts with `stop(..., call. = FALSE)`, retain ordered machine-readable reason codes, and never repair or silently drop invalid fixtures.

### Exact panel, fixture, and score-support contracts

**Sources:** `R/evaluation/benchmark_scores.R:52-67, 72-87`; `R/benchmark/runner.R:233-385`; Phase 11 paths/flags `R/benchmark/hybrid_runner.R:108-138`.

Keep exact registered fixture identity, exact panel membership, 12 tournament folds, open/rich coverage (630/609 where inherited), and fixed `G = 40`. Coverage is not permission to shrink denominators.

### Determinism and seeds

**Sources:** `R/evaluation/benchmark_scores.R:311-336`; current dashboard `R/visualization/worldcup_dashboard.R:350-355`; `AGENTS.md` testing strategy.

Put randomness behind explicit registered seeds, preserve RNG state where helpers do resampling, record seeds in manifests, and test repeatability with identical outputs.

### Canonical SHA-256 and parent graphs

**Sources:** `R/benchmark/runner.R:38-41, 95-109, 549-601, 656-712`; `R/benchmark/hybrid_runner.R:88-105, 1218-1257`.

Use `digest::digest(..., algo = "sha256")`, stable sorting/serialization, content and file hashes, named parent identities, graph hashes, and self-hashes. Validate from a fresh root/process before consumer load.

### Staged publication and rollback

**Sources:** `R/benchmark/runner.R:1414-1448`; `R/benchmark/hybrid_runner.R:1262-1289`.

Write and validate a complete sibling stage, atomically rename it into place, retain the accepted release until post-install validation succeeds, restore it on failure, and only then remove the backup.

### Candidate registry and inactive status

**Sources:** `R/benchmark/hybrid_adapters.R:215-236`; `R/benchmark/hybrid_protocol.R:413-444`; `R/benchmark/hybrid_runner.R:794-801`.

Validate candidate IDs against the registered protocol, preserve `active_status`, `score_status`, `inactive_reason`, and no-score rows, and never turn an absent score into a fabricated metric or an omitted candidate.

### Targets as durable artifact boundary

**Sources:** `_targets.R:934-946`; `tests/testthat/test_hybrid_targets.R:18-41`.

Return durable paths from write targets with `format = "file"`; make dependencies explicit and inspect target ancestry to prove that final label access is downstream of preflight/freeze/calibration.

### Consumer resolution

**Sources:** current unsafe paths `_targets.R:459-475`; `R/visualization/worldcup_dashboard.R:350-368, 1032-1073`.

One resolver must serve dashboard and export consumers. No latest-file, file-existence, or baseline fallback may select a production model. Validate approved release status, contract fields, trusted relative paths, and all hashes before simulation or export.

## No Analog Found

| File | Missing pattern | Planner implication |
|---|---|---|
| `R/calibration/probability_calibration.R` | No candidate/track-specific chronology-safe 1X2 calibrator exists. | Freeze the recipe/minimum-history/support rule before fitting; use `proper_scores.R` only for validation and retain raw fallback. |
| `R/calibration/inner_oof.R` | No nested inner-OOF assembly service exists. | Compose cutoff/boundary guards; persist outer/inner edition and source cutoff identities explicitly. |
| `R/release/final_evaluation.R` | No application-level exactly-once WC2026 label opener exists. | Separate label-free preflight from the sole label-bearing opener and enforce append-only consumed-label state. |
| `R/release/release_contract.R` | No approved manifest/model-contract resolver exists. | Create one shared fail-closed resolver for dashboard and exports; do not reuse raw model-path arguments as authority. |
| Final-fit adapter/model object per Phase 11 candidate | Phase 11 publishes research predictions and explicitly has `phase12_decision_authority = FALSE`; no `fit_final_release_model()` was found. | Planner must define an allowlisted pre-2026 final-fit/replay seam and hash the resulting model object in the release contract. |

## Metadata

**Analog search scope:** `R/evaluation`, `R/benchmark`, `R/visualization`, `_targets.R`, and focused `tests/testthat` suites; Phase 9-11 durable manifests and protocol/registry files.
**Files scanned:** 17 primary analogs plus related protocol, adapter, scoring, and selection helpers.
**Pattern extraction date:** 2026-08-10
