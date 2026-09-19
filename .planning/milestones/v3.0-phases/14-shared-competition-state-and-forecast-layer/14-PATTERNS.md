# Phase 14: Shared Competition State and Forecast Layer - Pattern Map

**Mapped:** 2026-08-16
**Planned targets classified:** 23 code/test/fixture targets plus generated artifact sets
**Analogs found:** 23 / 23 (some Phase 14 contracts have only partial analogs)

## Scope Extracted

Phase 14 proposes seven new production entrypoints/modules, four modifications to existing trust-boundary modules, seven test files, and five fixture targets. Accepted competition CSVs, a calibrated release revision, registry rows, and edition-local state outputs are generated artifacts; they must be rebuilt through validators and transactions, never hand-edited.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match |
|---|---|---|---|---|
| `R/competition/source_contracts.R` | config / validator | transform, file-I/O | same file: `phase13_source_resource_schema()` and payload validators | exact extension |
| `R/competition/team_identity.R` | service / model | transform | same file: normalized fixture/result/history builders | exact extension |
| `R/competition/edition_registry.R` | store / validator | CRUD, file-I/O | same file: release preflight, registry validation, revisioned repin | exact extension |
| `R/release/release_contract.R` | service / validator | file-I/O | same file: metadata-first approved-release preflight | exact extension |
| `R/competition/match_state.R` | model / service | transform | `R/competition/team_identity.R` normalized result contract | role-match |
| `R/competition/standings.R` | service | batch, transform | `build_current_group_tables()` in `R/visualization/worldcup_dashboard.R` | role-match |
| `R/competition/form.R` | service | batch, transform | `compute_rolling_form()` plus forecast evidence lookups | exact role |
| `R/competition/forecast_layer.R` | service | batch, transform | `predict_registered_baseline()` and benchmark contracts | exact role |
| `R/competition/state_bundle.R` | service / provider | batch, file-I/O | Phase 13 candidate/validate/promote publication path | exact role |
| `R/release/calibration_revision.R` | service | batch, transform, file-I/O | Phase 12 fit/select/stage/validate release flow | role-match |
| `scripts/build_competition_state.R` | controller | batch, file-I/O | `scripts/acquire_uefa_snapshot.R` | exact role |
| `tests/fixtures/phase14/match_lifecycle_cases.csv` | test fixture | file-I/O | `tests/fixtures/phase13/uefa_nations_league_sample.json` | role-match |
| `tests/fixtures/phase14/standings_reconciliation_cases.csv` | test fixture | file-I/O | Phase 13 Nations League fixture plus current-table tests | role-match |
| `tests/fixtures/phase14/point_in_time_history.csv` | test fixture | file-I/O | `tests/fixtures/phase13/martj42_history_sample.csv` | exact role |
| `tests/fixtures/phase14/raw_release/` | test fixture | file-I/O | copied trusted release fixture pattern in `test_phase12_release.R` | exact role |
| `tests/fixtures/phase14/calibrated_release/` | test fixture | file-I/O | synthetic fitted calibrator pattern in `test_phase12_calibration.R` | exact role |
| `tests/testthat/test_phase14_match_state.R` | test | transform | accepted-result identity/score tests in `test_phase13_competition_registry.R` | role-match |
| `tests/testthat/test_phase14_standings.R` | test | batch, transform | group-table reducer tests in `test_pipeline.R` | role-match |
| `tests/testthat/test_phase14_form.R` | test | batch, transform | feature-evidence and rolling-form tests/contracts | role-match |
| `tests/testthat/test_phase14_cutoffs.R` | test | transform | `test_benchmark_cutoffs.R` | exact role |
| `tests/testthat/test_phase14_calibration_release.R` | test | file-I/O | `test_phase12_release.R` and `test_phase12_calibration.R` | exact role |
| `tests/testthat/test_phase14_forecast_layer.R` | test | batch, transform | `test_benchmark_baselines.R` and `test_benchmark_contracts.R` | exact role |
| `tests/testthat/test_phase14_state_bundle.R` | test | batch, file-I/O | `test_phase13_publication_transaction.R` and refresh-failure tests | exact role |

## Pattern Assignments

### Accepted schema v2: `source_contracts.R` and `team_identity.R`

**Primary analogs:**

- `R/competition/source_contracts.R:12` — `phase13_source_resource_schema()`
- `R/competition/source_contracts.R:22` — `phase13_source_compact_resource_schema()`
- `R/competition/source_contracts.R:206` — `phase13_source_validate_resource_payload()`
- `R/competition/team_identity.R:175` — normalized fixture schema
- `R/competition/team_identity.R:191` — normalized result schema
- `R/competition/team_identity.R:245` — `phase13_normalize_accepted_result_rows()`
- `R/competition/team_identity.R:487` — `phase13_normalize_fixture_rows()`

Copy the explicit named-schema pattern and extend both source-shaped and normalized projections together:

```r
phase13_source_resource_schema <- function() {
  list(
    fixtures = c("source_fixture_id", "scheduled_at_utc", "status", "home", "away"),
    standings = c("source_team_id", "source_group_id", "position", "points"),
    results = c("source_fixture_id", "status", "home_goals", "away_goals")
  )
}
```

Phase 14 fields must be added at this boundary: group/kickoff confirmation, `source_status`, canonical `match_status`, `completion_method`, regulation/final/shootout scores, `winner_team_id`, official standings metrics, and evidence completion time. Preserve explicit empty pre-draw tables with their complete schema; do not represent them as null lists (`test_phase13_source_contracts.R:404-486`).

Keep identity separate from mutable score/status. `phase13_normalize_fixture_rows()` currently derives `fixture_id` from edition and source fixture ID (`team_identity.R:528-531`), while historical IDs are explicitly required non-empty and unique (`team_identity.R:640-661`). Phase 14 should add a durable source-to-canonical `match_id` crosswalk; never hash score or lifecycle into the ID.

Reuse deterministic row/table hashing:

```r
# R/competition/source_contracts.R:161-192
phase13_canonical_sha256(data, key = "match_id")
output$row_sha256 <- phase13_row_sha256(output)
```

### `R/competition/match_state.R`

**Analog:** `phase13_normalize_accepted_result_rows()` (`R/competition/team_identity.R:245-373`).

Copy its pattern of required columns, unique source keys, exact fixture inheritance, paired-score validation, explicit enums, and a final schema-ordered hashed output. Extend rather than reuse its narrow “completed implies score” rule.

Required invariants with no complete existing analog:

- lifecycle and completion method are orthogonal;
- `final_*` includes extra time but excludes shootout kicks;
- penalty completion requires a tied final football score and separate shootout score;
- awarded results may count for standings but default out of form;
- postponed, abandoned, and unresolved rows default false for both count flags;
- stable `match_id` survives score corrections and source deduplication.

Best test analog: `test_phase13_competition_registry.R:278-486`, especially the assertions that score changes alter row hashes but not stable identity fields.

### `R/competition/standings.R`

**Analog:** `build_current_group_tables()` (`R/visualization/worldcup_dashboard.R:2099-2176`).

Copy only the universal reducer arithmetic:

```r
tables$played[c(home_idx, away_idx)] <- tables$played[c(home_idx, away_idx)] + 1L
tables$goals_for[home_idx] <- tables$goals_for[home_idx] + home_goals
tables$goals_against[home_idx] <- tables$goals_against[home_idx] + away_goals
tables$points[home_idx] <- tables$points[home_idx] + home_points
tables$goal_difference <- tables$goals_for - tables$goals_against
```

Do not copy FIFA/UEFA head-to-head sorting from `rank_group_table()`; Phase 14 ordering is provisional behind a ruleset-adapter seam. Snapshot keys must be `edition_id`, `group_id`, `state_cutoff_utc`, and `source_bundle_id`.

Reconciliation must compare same-bundle official and computed `played`, goals, goal difference, and points. Aggregate mismatch blocks promotion and retains the prior accepted state; rank-only mismatch emits a warning; absent official data yields `rank_status = provisional`. There is no exact existing reconciliation analog.

### `R/competition/form.R`

**Analogs:**

- `compute_rolling_form()` (`R/integration/rolling_form.R:18-279`)
- `make_latest_team_evidence_lookup()` (`R/forecast/features.R:127-176`)
- `validate_forecast_feature_evidence()` (`R/forecast/features.R:381-461`)
- `assert_no_feature_leakage()` (`R/forecast/features.R:632-645`)

Copy the approved model-form lag pattern (`rolling_form.R:165-180`):

```r
xgf_ewma_post <- compute_ewma_simple(xgf_vec, alpha)
lag_with_default <- function(values, default = NA_real_) {
  if (length(values) == 0) return(values)
  c(default, head(values, -1))
}
xgf_ewma <- lag_with_default(xgf_ewma_post)
```

Copy the strict latest-before and evidence companions:

```r
idx <- findInterval(as.Date(lookup_date) - 1, team_rows[[date_col]])
list(value = value, source_present = TRUE, source_date = source_date,
     value_present = TRUE, imputed = FALSE, imputation_reason = "")
```

For Phase 14 use UTC evidence timestamps and `< kickoff_utc`; equality is leakage. Date-only history is eligible only on an earlier calendar date. Persist latest evidence time and contributing match IDs/hashes.

Do not copy `compute_rolling_form()`’s `NA -> 0` behavior for descriptive history (`rolling_form.R:134-139`). Phase 14 missing form remains unavailable with sample count/reason. Keep last-five display form separate from the approved span-12 EWMA.

### `R/competition/forecast_layer.R`

**Primary analogs:**

- `predict_registered_baseline()` (`R/benchmark/baselines.R:311-360`)
- `derive_benchmark_markets()` (`R/benchmark/contracts.R:64-82`)
- `validate_benchmark_score_distributions()` (`R/benchmark/contracts.R:85-126`)
- `apply_phase12_1x2_calibrator()` (`R/calibration/probability_calibration.R:204-218`)

Canonical production pattern:

```r
predicted <- predict_registered_baseline(
  fit = release$model,
  fixtures = feature_rows,
  support_max = 40L
)
validate_benchmark_score_distributions(
  predicted$distributions,
  predicted$predictions$score_distribution_id,
  support_max = 40L
)
```

`predict_registered_baseline()` builds `0:40 × 0:40`, records raw tail mass, normalizes the bounded grid, and derives all raw markets from that same grid. `validate_benchmark_score_distributions()` requires the complete rectangle and therefore enforces exactly 1,681 rows per fixture.

Keep two independent probability contracts:

```r
raw <- c(home = row$p_home, draw = row$p_draw, away = row$p_away)
consumer <- apply_phase12_1x2_calibrator(release$calibrator, raw)
```

Expected goals, modal score, top-10 scorelines, and goal intervals come from the unchanged canonical grid. Only consumer 1X2 is calibrated. Validate each simplex separately and retain both views plus calibrator/release hashes.

For top-10 ordering copy the deterministic scoreline order from `simulate_fixture_from_lambdas()` (`worldcup_dashboard.R:231-242`): descending probability, then total goals, home goals, away goals. Do **not** use that helper as producer: it defaults to `0:10` and renormalizes, while Phase 14 requires G=40.

Forecast every fixture to an eligibility/status row. Emit probabilities only for scheduled, confirmed-kickoff, identity-resolved, evidence-complete fixtures backed by a fitted approved calibrator. Otherwise emit a machine-readable suppression reason (`pre_draw`, `kickoff_unconfirmed`, `identity_unresolved`, `feature_evidence_unavailable`, `release_not_calibrated`, or status-ineligible).

### `R/release/calibration_revision.R`

**Analogs:**

- `fit_phase12_1x2_calibrator()` (`R/calibration/probability_calibration.R:82-161`)
- `phase12_selection_decision()` (`R/calibration/calibration_selection.R:255-289`)
- immutable bundle validation in `R/release/release_bundle.R:335-435`

Reuse the fitted/raw-fallback object contract and frozen chronology/provenance fields. Reuse the existing veto order exactly:

```r
reasons <- c()
if (!support_valid) reasons <- c(reasons, "calibration_support_insufficient")
if (!comparison$coverage_valid) reasons <- c(reasons, "fixture_coverage_veto")
if (!comparison$distribution_unchanged) reasons <- c(reasons, "score_identity_veto")
# RPS, Brier, log-loss, fold stability, calibration-improvement vetoes follow
primary_probability_view <- if (!length(reasons)) "calibrated_1x2" else "raw_1x2"
```

The empirical gate must not be assumed to pass. Failure leaves selector and both edition pins unchanged and keeps forecasts suppressed. Bind the exact incumbent model hash, development prediction hash, recipe/protocol hashes, chronology, support, gate decision, and code hash. Do not read WC2026 labels or rewrite historical final-evaluation evidence.

### `R/release/release_contract.R`

**Modify the existing analog in place.** The current ambiguity is explicit at `release_contract.R:192-201`:

```r
candidates <- phase12_release_contract_manifest_candidates(trusted_root)
if (length(candidates) != 1L) stop("Phase 12 release resolution is ambiguous or missing")
```

Add an explicit hash-backed approved selector/exact manifest authority. Preserve trusted-root containment and symlink rejection (`release_contract.R:17-72`), metadata-only validation before RDS loading, fresh preflight comparison, artifact hashes, and post-load model/calibrator identity checks (`release_contract.R:236-278`). Never select by mtime or “latest directory”.

Best test analog: `test_phase12_release.R:159-325`, which proves ambiguity, path/symlink escape, stale handoff, hash forgery, model/calibrator path swap, and identity drift all fail closed before use.

### `R/competition/edition_registry.R`

**Modify the existing analog in place.** Reuse:

- exact two-edition validation: `phase13_validate_competition_edition_registries()` (`edition_registry.R:269-366`);
- one-row revision/audit semantics: `phase13_repin_competition_model_release()` (`edition_registry.R:453-471`);
- row/table hashes: `edition_registry.R:83-102`.

The one-row repin pattern is:

```r
row$model_release_id <- model_release_id
row$registry_revision <- as.integer(row$registry_revision[[1L]]) + 1L
row$audit_event <- "model_release_repin"
row$audit_at_utc <- audit_at_utc
row$row_sha256 <- phase13_registry_row_hash(row)
```

Phase 14 must wrap this in an atomic two-row operation: update both rows in memory, verify both point to the same explicit approved release, validate the complete registry, then promote one candidate `competition_editions.csv`. A split pin is invalid.

### `R/competition/state_bundle.R`

**Analog:** Phase 13 publication transaction.

- exact bounded targets: `R/competition/publication_transaction.R:62-135`;
- snapshots/rollback: `publication_transaction.R:136-225`;
- lock and promotion: `publication_transaction.R:264-406`;
- full composition: `phase13_publish_normalized_editions()` in `scripts/acquire_uefa_snapshot.R:2242-2348`.

Copy the orchestration shape:

```r
phase13_with_publication_lock(..., callback = function(transaction) {
  phase13_seed_publication_staging(transaction)
  # build candidate tables
  canonical_refresh <- phase13_refresh_canonical_table_hashes(transaction$staging_root)
  manifest_refresh <- phase13_refresh_accepted_manifest_hashes(
    transaction$staging_root, canonical_refresh
  )
  # validate complete graph before mutation
  phase13_promote_publication_targets(transaction)
})
```

Use an exact Phase 14 target graph and candidate root. Shared identity/release/history failure invalidates both edition candidates; an edition-specific failure blocks only that edition and preserves its prior accepted state. Do not implement Phase 17’s all-or-nothing public two-site promotion here.

### `scripts/build_competition_state.R`

**Analog:** `scripts/acquire_uefa_snapshot.R:1-52`, `2242-2348`, and `3112-3197`.

Copy script-relative project-root resolution, explicit `source()` composition, argument parsing, injectable build/publish callback, `--dry-run`, and top-level `tryCatch`. The entrypoint should accept one explicit edition or both; it must not discover editions or releases by directory recency.

## Test and Fixture Assignments

| Phase 14 Target | Copy Structure From | Concrete behavior to retain |
|---|---|---|
| `match_lifecycle_cases.csv` / `test_phase14_match_state.R` | `uefa_nations_league_sample.json:1-77`; `test_phase13_competition_registry.R:278-486` | table-driven valid/invalid lifecycle-score combinations; identity stable under score correction |
| `standings_reconciliation_cases.csv` / `test_phase14_standings.R` | `build_current_group_tables()` and `test_pipeline.R:289-327` | reducer totals, exact/rank-only/aggregate mismatch, official-absent behavior |
| `point_in_time_history.csv` / `test_phase14_form.R` / `test_phase14_cutoffs.R` | `martj42_history_sample.csv:1-4`; `test_benchmark_cutoffs.R:25-71` | before passes; equal/after fails; same-day date-only fails; reorder-stable state hash |
| `raw_release/`, `calibrated_release/`, `test_phase14_calibration_release.R` | `helper_phase12_release.R:1-7`; `test_phase12_release.R:159-325`; `test_phase12_calibration.R:124-196,246-308` | copy isolated trusted root; raw suppresses; fitted resolves; forgery and split pin fail |
| `test_phase14_forecast_layer.R` | `test_benchmark_baselines.R:99-190`; `test_benchmark_contracts.R:71-171` | exactly 1,681 G=40 cells, complete rectangle, mass one, market reconciliation, deterministic modal/top-10 |
| `test_phase14_state_bundle.R` | `test_phase13_publication_transaction.R:52-191`; `test_phase13_refresh_failure.R:119-326` | inject failure after every promoted target; exact prior bytes/hashes restored; unrelated files untouched |

Use the repository’s direct test style:

```r
library(testthat)
project_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))
source(file.path(project_root, "R/competition/match_state.R"))

test_that("equal evidence time is rejected", {
  expect_error(build_competition_form(...), "cutoff|strictly before|leak")
})
```

Focused fixtures may use smaller score support only for unit mechanics. At least one production-contract test must use `support_max = 40L` and assert `41L * 41L` rows per fixture.

## Generated Artifact Patterns

| Generated Set | Pattern |
|---|---|
| `data/competition/accepted/<edition>/{fixtures,results,standings,...}.csv` | regenerate complete source/normalized/hash/manifest graph through Phase 13 helpers; never patch hashes manually |
| `data/competition/registries/competition_editions.csv` | candidate write with both release pins revisioned and validated together |
| `outputs/releases/<calibrated-release-id>/...` | immutable staged release directory, exact manifest/self-hash, explicit selector, no overwrite of v1 |
| `outputs/competition/<edition_id>/{state,audit,local}/...` | edition-scoped candidate/validate/promote; full G=40 grids as compressed local RDS, compact top-10 and lineage for later publication |

## Shared Patterns

### Fail-closed validation

Use explicit `stop(..., call. = FALSE)` at trust boundaries and machine-readable reason columns in durable status rows. Validate schemas, enums, foreign keys, hashes, probability mass, cutoffs, and cross-edition isolation before promotion.

### Hashing

Use `digest::digest(..., algo = "sha256", serialize = FALSE)` with canonical row ordering and explicit field projections (`source_contracts.R:137-192`). Every durable row carries a row hash; manifests bind artifact hashes and canonical content hashes.

### Release authority

Preflight metadata and hashes before loading model RDS. The live release proves the current blocker in `outputs/releases/phase12-wc2026-incumbent-retained-v1/model_contract.json:11-17`: G=40 is approved, but the primary view is `raw_1x2` with no fitted calibrator.

### Point-in-time evidence

Use exclusive `<` comparisons. Preserve source presence, value presence, evidence time, imputation/unavailable reason, contributing IDs, and an aggregate evidence hash. Never use `<=` at kickoff.

### Edition isolation

Every derived state/form/forecast row carries `edition_id`. Only identity, approved release, strength inputs, and declared all-senior history may cross edition boundaries. Competition form rejects foreign editions; EURO `pre_draw` emits no fabricated fixtures, groups, standings, form, or probabilities.

## Partial / No Exact Analog

The codebase has no complete analog for these Phase 14 concerns; compose the assigned patterns rather than inventing a hidden fallback:

- two-axis lifecycle plus regulation/final/shootout/awarded score semantics;
- official/computed standings reconciliation with blocker versus warning outcomes;
- stable cross-source canonical match crosswalk;
- eligibility/suppression rows with complete forecast lineage;
- entropy, central 80% goal intervals, top-10 omitted mass, and explicit unavailable uncertainty metadata;
- edition-local state promotion with shared-input failure fan-out.

## Copy Warnings

- Do not use dashboard `simulate_fixture_from_lambdas()` as canonical forecast producer: it defaults to `0:10` and renormalizes.
- Do not copy downstream head-to-head ranking into Phase 14; Phase 15/16 own competition-specific adapters.
- Do not copy rolling-form `NA -> 0` for descriptive history.
- Do not select releases by mtime, newest directory, or sole-directory assumption.
- Do not hand-edit accepted CSV, registry, release-manifest, or hash fields.
- Do not make Phase 14 perform Phase 17 atomic public-batch promotion.

## Metadata

**Primary analog scope:** `R/competition`, `R/release`, `R/calibration`, `R/benchmark`, `R/forecast`, `R/integration`, the targeted dashboard reducers, Phase 12/13 tests, and Phase 13 fixtures.

**Pattern extraction date:** 2026-08-16

## PATTERN MAPPING COMPLETE
