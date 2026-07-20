# Phase 09: Rolling Tournament Benchmark Harness - Research

**Researched:** 2026-07-20
**Domain:** Leakage-safe international-football tournament backtesting, probabilistic scoring, and model-promotion governance
**Confidence:** HIGH for repository architecture and contracts; MEDIUM for historical-data supplementation and literature-to-project adaptation

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### Tournament Folds

- **D-01:** The development benchmark contains 12 completed tournaments: World
  Cups 2002, 2006, 2010, 2014, 2018, and 2022, plus Euros 2004, 2008, 2012,
  2016, 2020, and 2024.
- **D-02:** Use complete tournaments as assessment blocks in chronological
  rolling-origin evaluation. No future tournament may affect an earlier fold.
- **D-03:** The primary track is pre-match updating: each fixture may use only
  information from matches fully completed before its deterministic update
  boundary. Retain a secondary forecast frozen before the tournament opener.
- **D-04:** Aggregate each tournament first and weight the 12 tournament folds
  equally for headline results. Fixture-weighted pooled results are secondary.
- **D-05:** All 12 tournaments remain in a fixed open-data core panel. Optional
  features may define named, predeclared feature-rich secondary panels, but those
  panels cannot replace or alter the core result.

### Training Evidence

- **D-06:** Count and machine-learning models use an expanding set of eligible
  pre-cutoff matches with a fixed recency-weight schedule. Older eligible rows
  remain available but receive less influence.
- **D-07:** Elo retains its full chronological senior-international history and
  existing recursive match-importance/K-factor treatment. Do not truncate Elo
  to the supervised-model window or apply the count/ML observation weights to it.
- **D-08:** Include all senior internationals in supervised training with fixed
  importance tiers. Friendlies remain useful for sparse teams but are
  downweighted relative to competitive matches.
- **D-09:** Register one transparent recency and match-importance schedule for
  every baseline. Alternative schedules are challenger ablations, not silent
  baseline differences.
- **D-10:** Refit model coefficients at deterministic matchday boundaries using
  only fully completed matches. Feature definitions, formulas, hyperparameters,
  weighting schedules, and calibration recipes remain frozen.

### Baseline Contract

- **D-11:** Register two no-strength controls: a uniform 1X2 sanity floor and an
  expanding historical 1X2 base-rate comparator estimated strictly from prior
  data.
- **D-12:** The Elo-only baseline is an Elo-driven goal model using point-in-time
  Elo difference and venue/neutral status only. It must emit the complete joint
  score distribution and all derived forecast targets.
- **D-13:** Register two negative-binomial incumbents. The open-data NB model is
  the incumbent on the 12-tournament core panel; the current production hybrid
  NB model is reproduced on a named feature-rich panel. Promotion may not regress
  the open core.
- **D-14:** Freeze all registered baseline formulas and hyperparameters before
  executing folds. Baselines do not receive fold-specific hyperparameter tuning.
- **D-15:** Every model uses the same fixtures, cutoffs, seeds, team identities,
  and output schema. Required outputs include the complete normalized scoreline
  distribution, derived 1X2/totals/BTTS probabilities, expected goals,
  pre-tournament stage probabilities, model manifest, feature coverage, and
  point-in-time provenance. Missing outputs or silent fixture drops fail the
  contract.

### Promotion Rule

- **D-16:** On the historical open-data core panel, a challenger must lower
  tournament-weighted RPS by at least `0.003` versus the open NB incumbent. The
  paired 95 percent interval for challenger-minus-incumbent RPS must lie entirely
  below zero.
- **D-17:** The challenger must improve RPS in at least 8 of 12 tournament folds,
  including at least two World Cups and two Euros. No individual fold may regress
  by more than `0.015` RPS.
- **D-18:** Promotion is vetoed if tournament-weighted Brier score or log loss
  worsens by more than 1 percent, calibration error worsens by more than `0.01`,
  or any probability, distribution, provenance, coverage, licensing, or
  reproducibility contract fails.
- **D-19:** Candidates requiring optional data must also beat the production
  hybrid NB on their predeclared paired feature-rich panel while satisfying the
  open-core non-regression requirement.
- **D-20:** Candidate code, features, settings, panels, seeds, and promotion
  thresholds must be frozen and checksummed before World Cup 2026 is opened.
  Final promotion requires lower WC2026 RPS than the applicable incumbent, no
  supporting-score veto, complete required coverage, and preservation of the
  default open-data operating mode.

### the agent's Discretion

The planner may define the file layout, adapter API, exact numeric recency and
importance schedule, cross-format matchday boundary convention, bootstrap or
hierarchical interval implementation, calibration-error estimator, scoreline
support/tail representation, and report styling. These choices must be declared
before evaluation, deterministic, and consistent with D-01 through D-20.

### Deferred Ideas (OUT OF SCOPE)

- Expand the proven benchmark harness to Copa America and Africa Cup of Nations.
  This is valuable for confederation and style diversity but lies outside Phase
  9's locked World Cup/Euro scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BENCH-01 | Run deterministic tournament-blocked World Cup and Euro folds using only pre-match information. | The fold registry, date-level completion batches, frozen/updating track state machine, and strict `< evidence_cutoff` joins below define the implementation contract. [VERIFIED: `.planning/REQUIREMENTS.md`; `.planning/phases/09-rolling-tournament-benchmark-harness/09-CONTEXT.md`] |
| BENCH-02 | Prevent World Cup 2026 outcomes from fitting, feature selection, tuning, or calibration before sealed evaluation. | The purpose-gated data-access policy, `wc2026` denylist, sealed manifest, and synthetic leakage tests below make this a hard failure instead of a convention. [VERIFIED: `.planning/REQUIREMENTS.md`; `.planning/PROJECT.md`] |
| BENCH-03 | Use a common prediction schema, point-in-time feature contract, model manifest, and coverage audit. | The normalized relational schemas and adapter API below are model-agnostic and fail closed on missing rows, incomplete distributions, invalid cutoffs, or unregistered features. [VERIFIED: `R/evaluation/proper_scores.R`; `R/evaluation/worldcup_ledger.R`] |
| BENCH-04 | Include naive, Elo-only, and incumbent NB baselines on identical fixtures and folds. | The five-model registry below specifies the two controls, Elo goal model, open NB incumbent, and production hybrid NB, including how controls emit coherent score distributions. [VERIFIED: 09-CONTEXT.md D-11..D-15; `R/benchmark/euro2024.R`; `R/forecast/poisson.R`] |
| BENCH-05 | Compare candidates with shared seeds, paired tournament deltas, uncertainty, and a predeclared promotion rule. | The paired tournament bootstrap, equal-tournament aggregation, breadth/regression checks, veto order, seed ledger, and decision schema below implement the locked gate exactly. [VERIFIED: 09-CONTEXT.md D-16..D-20; `R/evaluation/worldcup_retrospective.R`] |
</phase_requirements>

## Summary

Phase 09 should be planned as a new authoritative benchmark service, not as an extension of the current EURO 2024 script. The repository already supplies reliable low-level pieces: strict pre-date feature lookup, complete-distribution validators, RPS/Brier/log scoring, coverage accounting, deterministic bootstrap patterns, SHA-256 revision hashes, immutable CSV/RDS bundles, and `targets` orchestration. [VERIFIED: `R/forecast/features.R`; `R/evaluation/proper_scores.R`; `R/evaluation/worldcup_retrospective.R`; `R/evaluation/worldcup_ledger.R`; `_targets.R`] The existing `run_euro2024_benchmark()` and `simulate_euro2024_tournament_models()` remain useful reference implementations, but they are one-edition paths with model-specific schemas, one frozen cutoff, edition-specific routing, unweighted fits, different model seeds, and legacy promotion logic. [VERIFIED: `R/benchmark/euro2024.R`; `R/benchmark/euro2024_tournament.R`]

The implementation should begin with data contracts. The checked-in `elo_matches.csv` contains exactly 630 target fixtures: 384 World Cup matches and 246 Euro matches across the 12 locked editions. It has dates, scores, tournament names, venue neutrality, canonical names, and mostly populated FIFA codes, but it has no stage, kickoff, completion-status, or regulation-versus-extra-time fields. Three tournament team identities (`Republic of Ireland`, `China`, and `Scotland`) have missing FIFA codes in the current processed rows. [VERIFIED: repository R inventory run 2026-07-20] The upstream Mart Jürisoo/openfootball data lineage also explicitly lacks extra-time flags and match status, while shootouts contain winners but not shootout scores. [CITED: https://github.com/openfootball/internationals] Therefore Wave 0 must create a curated, source-attributed fixture registry and format registry before any model benchmark can be trusted.

Use conservative calendar-date update batches for every edition. All fixtures completed on date `d` are forecast from one state whose evidence is strictly dated before `d`; no result from date `d` is visible until the entire date batch closes. The frozen track uses the pre-opener state for every fixture. [VERIFIED: 09-CONTEXT.md D-03, D-10; repository source data has date precision only] Compute fixture-level proper scores once, tournament means second, and the equal mean of the 12 tournament means third. Paired uncertainty resamples the 12 tournament deltas, never unpaired fixtures. [VERIFIED: 09-CONTEXT.md D-04, D-16; `R/evaluation/worldcup_retrospective.R` supplies the deterministic bootstrap pattern]

**Primary recommendation:** Build and freeze the registries, adapter/output contracts, and leakage guards first; then run all five baselines through one harness and one scorer; only after those artifacts reconcile should the promotion protocol be checksummed and exposed to Phases 10-12. [VERIFIED: 09-CONTEXT.md D-01..D-20]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Tournament/fixture/fold registries | Data / Storage | Pipeline | These are immutable evidence and routing contracts consumed by every branch. [VERIFIED: repository file-oriented data pattern] |
| Evidence cutoffs and matchday state transitions | Benchmark / API logic | Data / Storage | The harness owns admissibility; data files record completion and cutoff facts. [VERIFIED: BENCH-01, BENCH-02] |
| Model fitting and model adapters | Forecast / Model layer | Benchmark | Existing forecast functions fit models; adapters translate them to the shared contract. [VERIFIED: `R/forecast/poisson.R`; `R/benchmark/euro2024.R`] |
| Elo chronology | Elo layer | Benchmark | Elo must remain recursive and independent of supervised observation weights; the harness only requests point-in-time snapshots. [VERIFIED: 09-CONTEXT.md D-07] |
| Feature assembly and coverage | Integration layer | Benchmark | The established layer rule requires xG and Elo to combine through feature tables; the harness audits those tables. [VERIFIED: `AGENTS.md`; `R/forecast/features.R`] |
| Scoreline-to-market derivation | Evaluation layer | Forecast / Model layer | Models emit one joint distribution; shared evaluation code derives 1X2, totals, BTTS, marginals, and scores. [VERIFIED: `R/evaluation/proper_scores.R`] |
| Tournament simulation/stage probabilities | Forecast tournament layer | Benchmark | Format adapters route simulated teams; the benchmark validates common seeds and output coverage. [VERIFIED: `R/forecast/tournament.R`; `R/benchmark/euro2024_tournament.R`] |
| Equal-tournament aggregation and uncertainty | Evaluation layer | Pipeline | This is a scoring policy independent of model family. [VERIFIED: 09-CONTEXT.md D-04, D-16] |
| Promotion/veto decision | Evaluation governance | Pipeline | A pure function should consume frozen summaries and manifests and emit a reasoned decision. [VERIFIED: 09-CONTEXT.md D-16..D-20] |
| Durable execution/caching | Pipeline | Data / Storage | `targets` should branch by immutable fold/model/track units and retain file artifacts. [VERIFIED: `_targets.R`; CRAN `targets` 1.12.0 documentation] |

## Project Constraints (from AGENTS.md)

- Use R and the existing `targets` workflow; do not introduce a parallel implementation language or orchestration system. [VERIFIED: `AGENTS.md`]
- Preserve the layer boundary: xG and Elo combine only through the integration-layer feature table. [VERIFIED: `AGENTS.md`]
- Keep the default operating mode open-data-first; restricted Transfermarkt/FotMob-style inputs remain optional, local, non-redistributed, and explicitly labelled. Automated FotMob scraping is forbidden. [VERIFIED: `AGENTS.md`; `.planning/PROJECT.md`]
- Train the xG shot model on domestic leagues only and exclude international tournaments; Phase 09 may consume already-derived, point-in-time xG/form features but must not retrain the shot model on assessment tournaments. [VERIFIED: `AGENTS.md`]
- Use FIFA codes as primary external identity keys, backed by the canonical mapping; do not join benchmark rows on display names alone. [VERIFIED: `AGENTS.md`]
- Preserve the custom Elo implementation, home-advantage behavior, chronological updates, and all-international history. [VERIFIED: `AGENTS.md`; 09-CONTEXT.md D-07]
- Use negative-binomial goal models for the registered incumbents; any Poisson fallback must be visible in the manifest and cannot silently change the registered model family. [VERIFIED: `AGENTS.md`; 09-CONTEXT.md D-13]
- Seed every stochastic operation deterministically and verify reproducibility. [VERIFIED: `AGENTS.md`; 09-CONTEXT.md D-15, D-20]
- Put durable tests under `tests/testthat/`, run them frequently, and retain at least 80% coverage for core functions. [VERIFIED: `AGENTS.md`]
- Commit planning documentation because `commit_docs` is enabled, but do not alter dashboard behavior while building the evaluation layer. [VERIFIED: `AGENTS.md`; `.planning/config.json`; 09-CONTEXT.md]

## Repository and Data Inventory

### Closest implementation points

| Existing asset | Reuse | Required change / boundary |
|----------------|-------|----------------------------|
| `R/benchmark/euro2024.R` | Holdout selection shape, feature assembly, home/away NB fitting, prediction rows, RPS/Brier/log output. [VERIFIED: codebase] | Do not generalize it in place. Replace date/regex edition detection, single cutoff, unweighted fitting, model-specific probability path, and legacy `hybrid_pass` with new registry-driven services. [VERIFIED: codebase] |
| `R/benchmark/euro2024_tournament.R` | Ordered-pair forecast precomputation, group ranking, best-third routing table, stage-probability accumulation. [VERIFIED: codebase] | Extract format families; current hard-coded teams, Germany host logic, EURO 2024 groups, and separate seed offsets are not valid common contracts. [VERIFIED: codebase] |
| `R/evaluation/proper_scores.R` | Keep the validated normalized 1X2 RPS, unscaled multiclass Brier, natural-log score, binary Brier, score-distribution validation, market derivation, and goal RPS. [VERIFIED: 33 selected test expectations passed 2026-07-20] | Add benchmark-grain wrappers, not duplicate metric formulas. Extend validation to rectangular support completeness and tail diagnostics. [VERIFIED: codebase] |
| `R/evaluation/worldcup_retrospective.R` | Reuse long metric-row style, explicit coverage, deterministic bootstrap pattern, calibration output style, and checksum bundle pattern. [VERIFIED: 23 selected test expectations passed 2026-07-20] | Replace fixture-level resampling with paired tournament-level resampling for Phase 09 headline uncertainty. Keep Phase 08 strict/exploratory semantics separate. [VERIFIED: codebase; 09-CONTEXT.md D-04] |
| `R/evaluation/worldcup_ledger.R` | Reuse UTC parsing, stable reason precedence, fail-fast fixture validation, SHA-256 `digest` hashing, source/Git identity, and immutable manifest ideas. [VERIFIED: codebase] | Historical folds have date precision, not genuine archived generation timestamps; record precision honestly and validate exclusive dates rather than fabricating kickoff proof. [VERIFIED: codebase and data inventory] |
| `R/forecast/features.R` | Its latest-before lookups already use strict `< lookup_date`; coverage and canonical-alias helpers are reusable. [VERIFIED: codebase] | Add source-level cutoff columns and required/optional feature status; do not let missing optional values silently become zero without a missingness record. [VERIFIED: codebase] |
| `R/forecast/goal_ability.R` | Reuse the transparent 730-day half-life and tournament-importance schedule as Phase 09's registered supervised weighting schedule. [VERIFIED: codebase] | Apply weights to the supervised model likelihood itself; do not apply these weights to Elo recursion. [VERIFIED: 09-CONTEXT.md D-06..D-09] |
| `R/forecast/poisson.R` | Reuse predictor registries and NB model-fitting mechanics. [VERIFIED: codebase] | The harness adapter must pass deterministic complete training data and weights. It must reject or record NB failure; the current silent Poisson fallback and random sampled production branches are not benchmark-safe. [VERIFIED: codebase] |
| `R/forecast/monte_carlo.R` | Reuse derived output names and neutral-fixture symmetry logic. [VERIFIED: codebase] | Do not use finite Monte Carlo samples as the canonical match score distribution when analytic NB probabilities are available; empirical samples can omit observed cells and introduce avoidable score noise. [VERIFIED: codebase behavior] |
| `_targets.R` | Add downstream file targets without changing existing dashboard dependencies. [VERIFIED: codebase] | Branch on registry rows/model IDs/tracks and publish one run manifest. Do not make Phase 09 artifacts upstream of the dashboard. [VERIFIED: 09-CONTEXT.md] |

### Locked fold inventory

| Edition ID | Display edition | Fixtures | Distinct completion dates | Format family |
|------------|-----------------|----------|---------------------------|---------------|
| `wc2002` | FIFA World Cup 2002 | 64 | 25 | `wc32_r16` |
| `wc2006` | FIFA World Cup 2006 | 64 | 25 | `wc32_r16` |
| `wc2010` | FIFA World Cup 2010 | 64 | 25 | `wc32_r16` |
| `wc2014` | FIFA World Cup 2014 | 64 | 25 | `wc32_r16` |
| `wc2018` | FIFA World Cup 2018 | 64 | 25 | `wc32_r16` |
| `wc2022` | FIFA World Cup 2022 | 64 | 23 | `wc32_r16` |
| `euro2004` | UEFA Euro 2004 | 31 | 19 | `euro16_qf` |
| `euro2008` | UEFA Euro 2008 | 31 | 19 | `euro16_qf` |
| `euro2012` | UEFA Euro 2012 | 31 | 19 | `euro16_qf` |
| `euro2016` | UEFA Euro 2016 | 51 | 23 | `euro24_r16_best4third` |
| `euro2020` | UEFA Euro 2020, played in 2021 | 51 | 22 | `euro24_r16_best4third` |
| `euro2024` | UEFA Euro 2024 | 51 | 22 | `euro24_r16_best4third` |

The total is 630 fixtures across 272 edition-date batches when batches are counted within editions; modern 51/64-match formats would dominate a pooled fixture score, which is exactly why the locked headline first averages within each edition. [VERIFIED: repository R inventory run 2026-07-20; 09-CONTEXT.md D-04]

### Data gaps that must be Wave 0 work

1. `tournament` values are only `FIFA World Cup` or `UEFA Euro`; edition identity must come from a checked registry, not `format(date, "%Y")`, because Euro 2020 was played in 2021 and regex matching can include qualifiers. [VERIFIED: `data/raw/martj42/results.csv` inventory]
2. The 630 rows have no stage/group/routing fields. Pre-tournament simulation therefore needs checked group membership and format/routing tables. [VERIFIED: `data/processed/elo_matches.csv` schema]
3. Source scores do not distinguish regulation from extra time, and source status does not identify abandoned/awarded/replayed matches. The assessment registry must source regulation goals, final goals, winner, status, and completion date explicitly. [CITED: https://github.com/openfootball/internationals]
4. `actual_winner_team` is unpopulated for all 630 current processed rows. The shootout file can supply some winners only after exact fixture joins; non-shootout knockout winners still need derivation from final scores/status. [VERIFIED: repository R inventory run 2026-07-20]
5. Current tournament rows contain missing FIFA codes for `Republic of Ireland`, `China`, and `Scotland`; the canonical map must be repaired and audited before FIFA code becomes a hard key. [VERIFIED: repository R inventory run 2026-07-20]
6. Optional Transfermarkt snapshots cover most but not all tournament teams before each opener; observed gaps include several historical aliases/teams. Rich-panel eligibility must be frozen by fixture and must never silently default a missing team to zero. [VERIFIED: repository R inventory run 2026-07-20]
7. `rolling_form.csv` currently contains only 10 rows for six teams dated 2026-06-05, so the existing xG/form fields do not constitute a 12-tournament historical signal. The open NB manifest must expose their coverage and active/zero-variance status per fold. [VERIFIED: repository R inventory run 2026-07-20]

## Leakage-Safe Cutoff Protocol

### Canonical boundary convention

Use `actual_completion_date` as the cross-format update batch key. For ordinary completed fixtures it equals the historical event date. All fixtures in one edition with the same completion date share a single `boundary_id`. [VERIFIED: source precision is date-only; recommendation implements 09-CONTEXT.md D-03, D-10]

For boundary date `d`:

- `evidence_cutoff_exclusive = d`.
- Supervised training rows require `match_completion_date < d`.
- Every feature source requires `source_date < d`.
- Elo lookup requires `rating_date < d`; Elo may recursively update only from matches with `completion_date < d`.
- All fixtures completed on `d` are forecast from the same model/features/Elo state.
- Outcomes from `d` become eligible only for the next boundary date.

This convention is deliberately conservative: it gives up possible information from an early same-day match because historical kickoff times are unavailable, but it cannot leak a same-day result into another same-day forecast. [VERIFIED: repository source precision; first-principles leakage analysis]

### Frozen track

For edition opener date `o`, fit coefficients and build every mutable feature/Elo snapshot using only evidence with date `< o`; issue every edition fixture from that unchanged state. [VERIFIED: 09-CONTEXT.md D-03] The frozen track is also the source of required pre-tournament stage probabilities because it is the only track with one genuinely pre-opener tournament state. [VERIFIED: 09-CONTEXT.md D-15]

### Updating track

For each ordered date batch, rebuild eligible training rows, recompute supervised observation weights relative to that boundary, refit registered model coefficients once, snapshot point-in-time features once, and predict every fixture in the batch. [VERIFIED: 09-CONTEXT.md D-03, D-06, D-10] Elo ratings are not refit under those supervised weights: continue the existing recursive history through completed prior batches and read the pre-boundary rating. [VERIFIED: 09-CONTEXT.md D-07]

### Registered recency and match-importance schedule

Use the already-established schedule as the Phase 09 baseline schedule:

```text
recency_weight = 0.5 ^ (age_days / 730)
importance_weight = 1.8  for World Cup/continental finals
                    1.3  for qualifiers/qualification/Nations League
                    0.6  for friendlies
                    1.0  otherwise
observation_weight = recency_weight * importance_weight
```

Normalize `observation_weight` to mean 1 inside each training snapshot before passing it to a supervised likelihood so the schedule expresses relative influence and does not change scale merely as row counts expand. [VERIFIED: `R/forecast/goal_ability.R` supplies the 730-day half-life and 1.8/1.3/0.6 tiers; normalization is a prescriptive implementation choice] The uniform control declares weights `not_applicable`; the historical base-rate and empirical conditional-score components use the same weights; Elo explicitly declares `not_applied`. [VERIFIED: 09-CONTEXT.md D-07, D-09, D-11]

### World Cup 2026 hard seal

Do not rely on callers remembering not to use 2026. Every fit, selection, tuning, feature, and calibration entry point should accept a `purpose` and call one common guard. In `development`, `baseline_reproduction`, and `candidate_selection` purposes, any row with `edition_id == "wc2026"` in an outcome-bearing role is rejected before data are handed to model code. [VERIFIED: BENCH-02; 09-CONTEXT.md D-20] A separate sealed fixture manifest may expose fixture IDs, schedule, team identities, panel eligibility, and checksums, but not labels to development code. [VERIFIED: 09-CONTEXT.md D-20]

The final Phase 12 runner should require an explicit one-time `final_evaluation` purpose, verify the frozen protocol checksum first, write an append-only opening record, and then expose labels only to scoring and valid rolling updates—not to feature selection, hyperparameter search, or calibration. [VERIFIED: `.planning/ROADMAP.md` Phase 12; 09-CONTEXT.md D-20]

## Common Artifact Schemas

Use normalized CSV tables for auditable row-level contracts and RDS only for fitted model objects or compact internal bundles. Every CSV has `schema_version`; every durable artifact is listed in the run manifest with row count, byte count, SHA-256, producer, source Git SHA, and creation time. [VERIFIED: repository CSV/RDS and Phase 08 manifest pattern; `R/evaluation/worldcup_ledger.R` already uses SHA-256 via `digest`]

### Registry tables

#### `tournaments.csv`

| Column | Type / invariant |
|--------|------------------|
| `edition_id` | Stable key such as `wc2002` or `euro2020`; unique. |
| `competition_id` | `world_cup` or `euro`; never inferred with regex. |
| `edition_label` | Historical label (`2002`, ..., `2020`, `2024`) separate from played year. |
| `opener_date`, `final_date` | ISO dates. |
| `format_id` | One of the three registered format families. |
| `headline_weight` | Exactly `1/12` for all development folds. |
| `expected_fixture_count` | 64, 31, or 51 as inventoried. |
| `host_team_ids` | Delimited stable team IDs for metadata only; venue remains fixture-specific. |
| `source_id`, `source_sha256` | Provenance for the edition inventory. |

[VERIFIED: 09-CONTEXT.md D-01, D-04; repository inventory]

#### `fixtures.csv`

| Column group | Required columns |
|--------------|------------------|
| Identity | `edition_id`, `fixture_id`, `source_match_id`, `stage_id`, `group_id`, `round_id`, `home_team_id`, `away_team_id` |
| Timing | `scheduled_date`, `actual_completion_date`, `time_precision`, `boundary_id`, optional `kickoff_utc` |
| Venue | `venue_country`, `neutral`, `venue_role` (`home`, `away`, `neutral`), `home_is_host`, `away_is_host` |
| Outcome | `regulation_home_goals`, `regulation_away_goals`, `final_home_goals`, `final_away_goals`, `went_extra_time`, `went_penalties`, `winner_team_id` |
| Status | `status` (`completed`, `resumed`, `replayed`, `awarded`, `abandoned`), `fit_eligible`, `score_eligible`, `exclusion_reason` |
| Provenance | `result_source`, `result_source_date`, `source_license`, `row_sha256` |

The validator requires exactly the registered fixture count, unique `fixture_id`, valid teams, a valid boundary, complete regulation scores for every score-eligible row, and no silent exclusions. [VERIFIED: `R/evaluation/worldcup_ledger.R::validate_fixture_registry()` pattern; 09-CONTEXT.md D-15]

#### `boundaries.csv`

`boundary_id`, `edition_id`, `sequence`, `track`, `assessment_date`, `evidence_cutoff_exclusive`, `prior_boundary_id`, `fixture_count`, `completed_input_count`, `status`, and `boundary_sha256`. Frozen track has one pre-opener state; updating track has one state per distinct completion date. [VERIFIED: cutoff protocol above]

#### `panels.csv` and `panel_fixtures.csv`

`panels.csv` records `panel_id`, `mode` (`open_core`, `feature_rich`), required source/feature sets, license class, predeclaration SHA, and minimum coverage policy. `panel_fixtures.csv` records every `panel_id × fixture_id` with `eligible`, each failed coverage flag, and the final reason. [VERIFIED: 09-CONTEXT.md D-05, D-19] The open core has all 630 fixtures and cannot be edited by optional-data availability. [VERIFIED: 09-CONTEXT.md D-05]

### Model and feature contracts

#### `model_registry.csv`

`model_id`, `model_family`, `adapter_version`, `panel_id`, `formula_id`, `hyperparameter_id`, `weight_schedule_id`, `calibration_id`, `score_support_id`, `stochastic`, `open_mode_compatible`, `registered_at`, and `registry_sha256`. [VERIFIED: 09-CONTEXT.md D-09, D-14, D-20]

#### `model_manifests.csv`

One row per `run_id × model_id × edition_id × track × boundary_id`: include the registry keys above plus `fit_status`, `fit_row_count`, `fit_min_date`, `fit_max_date`, `max_result_date`, `max_feature_source_date`, `active_predictors`, `dropped_predictors_with_reason`, model class, dispersion/theta, convergence/fallback status, coefficient/object SHA-256, source Git SHA, R/package versions, and parent artifact hashes. [VERIFIED: existing model attributes in `R/forecast/poisson.R`; Phase 08 provenance pattern]

#### `feature_contract.csv` and `feature_coverage.csv`

The contract has one row per feature with `feature_id`, `definition_version`, `source_id`, `required`, `panel_id`, `availability_rule`, `imputation_rule`, `allowed_max_source_lag`, and `license_class`. Coverage has one row per `model × boundary × fixture × feature` with `value_present`, `source_present`, `source_date`, `cutoff_valid`, `imputed`, `imputation_reason`, `active_in_fit`, and `coverage_status`. [VERIFIED: `R/forecast/xg_usage_audit.R`; 09-CONTEXT.md D-15]

### Forecast outputs

#### `fixture_predictions.csv`

One row per `run_id × model_id × edition_id × track × fixture_id` with:

```text
schema_version, run_id, model_id, panel_id, edition_id, track,
fixture_id, boundary_id, forecast_sequence, home_team_id, away_team_id,
venue_role, evidence_cutoff_exclusive, result_cutoff_exclusive,
model_manifest_id, feature_coverage_id, seed_id,
p_home, p_draw, p_away,
expected_home_goals, expected_away_goals,
p_over_2_5, p_under_2_5, p_btts,
modal_home_goals, modal_away_goals, modal_score_probability,
score_distribution_id, prediction_status, failure_reason
```

All market probabilities are derived from the stored joint score distribution and then checked against any adapter-supplied values; disagreement above `1e-10` fails validation. [VERIFIED: `R/evaluation/proper_scores.R::derive_binary_markets()` pattern; prescriptive tolerance]

#### `score_distributions.csv`

Long rows keyed by `score_distribution_id`, with integer `home_goals`, integer `away_goals`, `probability`, `support_max_home`, `support_max_away`, `raw_tail_mass`, and `normalized`. Store the full rectangular grid, including zero-probability cells, so “complete” is machine-checkable. [VERIFIED: Phase 08 found truncated storage unusable; 09-CONTEXT.md D-15]

For NB/Poisson models, compute the analytic joint PMF on `0:G × 0:G`. Register `G = 15` initially, record mass outside the rectangle, require `raw_tail_mass <= 1e-10`, and fail the baseline freeze if that bound is violated; raise `G` globally and refreeze rather than choosing support per model. Renormalize only after the tail check. [VERIFIED: standard R `dnbinom`/`dpois` behavior and existing independent-grid implementation in `R/benchmark/euro2024.R`; support/tolerance are prescriptive choices] The observed regulation score must lie within support or scoring fails loudly. [VERIFIED: `R/evaluation/proper_scores.R`]

#### `stage_probabilities.csv`

One row per `run × model × edition × frozen anchor × team × applicable stage`: `team_id`, `stage_id`, `stage_order`, `probability`, `n_simulations`, `seed_id`, `format_id`, `anchor_boundary_id`, and simulator/config hashes. A separate stage registry declares which stages apply to each format; absent stages are not encoded as false zeroes. Probabilities must be in `[0,1]`, monotone non-increasing across successive reach stages, and sum to 1 for `champion`. [VERIFIED: existing stage output concepts in `R/benchmark/euro2024_tournament.R`; prescriptive cross-format contract]

Use 50,000 tournament simulations with precomputed match distributions and one shared random-number ledger per edition. This caps the worst-case binomial Monte Carlo standard error at about `0.00224` and aligns with the project's established 50,000-simulation reproducibility target. [VERIFIED: elementary binomial SE calculation; `AGENTS.md` performance target] Stage probabilities are required outputs but are not part of the Phase 09 RPS promotion statistic. [VERIFIED: 09-CONTEXT.md D-16..D-18]

### Scoring and decision outputs

#### `fixture_scores.csv`

Long rows keyed by model/track/panel/edition/fixture, with `target`, `metric`, `value`, observed class/score, and eligibility/coverage fields. Reuse the Phase 08 score names and formulas. [VERIFIED: `R/evaluation/worldcup_retrospective.R`]

#### `benchmark_summaries.csv`

Store all three grains explicitly: `fixture`, `tournament`, and `headline`. Columns include `aggregation` (`equal_tournament`, `fixture_weighted`), `estimate`, `n_tournaments`, `n_fixtures`, `coverage_numerator`, `coverage_denominator`, and `coverage`. [VERIFIED: 09-CONTEXT.md D-04]

#### `paired_comparisons.csv`

`challenger_id`, `incumbent_id`, `panel_id`, `track`, `metric`, `edition_id` (or `headline`), `challenger_estimate`, `incumbent_estimate`, `delta`, `bootstrap_lower`, `bootstrap_upper`, `improved`, `regression_limit_pass`, and paired fixture counts. [VERIFIED: 09-CONTEXT.md D-16, D-17]

#### `promotion_decisions.csv`

One row per candidate with each gate as an explicit boolean/value: practical RPS delta, CI upper bound, fold wins, World Cup wins, Euro wins, maximum fold regression, Brier relative change, log-loss relative change, calibration change, core coverage, rich-panel result if applicable, probability/distribution/provenance/license/reproducibility checks, and final `decision`/ordered `veto_reasons`. [VERIFIED: 09-CONTEXT.md D-16..D-20]

#### `run_manifest.csv`, `seed_registry.csv`, `checksum_manifest.csv`

The run manifest identifies the protocol version, Git SHA, dirty-worktree status, sealed-data policy, R session, package versions, all registry hashes, start/end time, and command. The seed registry assigns deterministic integer seeds by purpose (`stage_simulation`, `bootstrap`, future stochastic adapter), edition, boundary, and fixture where needed; seeds do not depend on execution order or model ID when common random numbers are required. The checksum manifest records SHA-256 for every input registry and durable output. [VERIFIED: Phase 08 ledger/manifest patterns; 09-CONTEXT.md D-15, D-20]

## Standard Stack

### Core

| Library / runtime | Version to use | Published / verified | Purpose | Why standard here |
|-------------------|----------------|----------------------|---------|-------------------|
| R | Installed 4.6.1 | Local runtime 2026-07-20 | Contracts, fitting, scoring, simulation | Non-negotiable project language. [VERIFIED: environment; `AGENTS.md`] |
| `targets` | 1.12.0 | 2026-02-09 | Incremental fold/model/track orchestration | Already the root pipeline and current installed CRAN version. [CITED: https://CRAN.R-project.org/package=targets] |
| base `stats` / `utils` | R 4.6.1 | Bundled | GLMs, weighted summaries, bootstrap primitives, CSV | Sufficient for the new aggregation and uncertainty code; avoids a new scoring/resampling dependency. [VERIFIED: codebase] |
| `MASS` | Keep installed 7.3-65 for this phase | CRAN latest 7.3-66 published 2026-07-15 | `glm.nb` incumbents | Existing model implementation depends on it; do not combine benchmark work with an unrelated patch upgrade. [CITED: https://CRAN.R-project.org/package=MASS; VERIFIED: environment] |
| `digest` | 0.6.39 | 2025-11-19 | SHA-256 object/row/protocol hashes | Already used by Phase 08 for revision hashes and installed locally. [CITED: https://CRAN.R-project.org/package=digest; VERIFIED: `R/evaluation/worldcup_ledger.R`] |
| `testthat` | 3.3.2 | 2026-01-11 | Unit, contract, integration, determinism tests | Existing test framework and installed current CRAN version. [CITED: https://CRAN.R-project.org/package=testthat] |

### Supporting

| Library | Version | Purpose | When to use |
|---------|---------|---------|-------------|
| `dplyr` | 1.2.1 | Existing data manipulation and simulation helpers | Reuse where current modules already depend on it; contract validators should remain simple base-R-friendly functions. [CITED: https://CRAN.R-project.org/package=dplyr] |
| `jsonlite` | 2.0.0 installed | Optional machine-readable frozen protocol snapshot | Use for a canonical JSON rendering in addition to relational CSVs, with sorted keys/rows before hashing. [VERIFIED: environment; `_targets.R`] |
| `ggplot2` | 4.0.3 installed | Diagnostic/report figures | Use only after metric tables are finalized; figures are not decision inputs. [VERIFIED: environment; `_targets.R`] |

### Alternatives Considered

| Instead of | Could use | Why not for Phase 09 |
|------------|-----------|----------------------|
| Explicit registry-driven folds | `rsample` sliding resamples | Generic time slices do not encode edition formats, date-complete update batches, dual tracks, panel eligibility, or the 2026 seal; a custom registry is smaller and more auditable. [VERIFIED: project requirements; recommendation] |
| Shared project proper-score functions | A new scoring package | Current formulas are hand-tested and already match the locked scale; changing implementations risks a threshold-scale mismatch. [VERIFIED: `tests/testthat/test_worldcup_scoring.R`] |
| Paired tournament bootstrap | Fixture bootstrap or Diebold-Mariano-style match sequence test | Fixtures within one tournament are dependent and the estimand weights tournaments equally; resampling fixtures answers the wrong question. [VERIFIED: 09-CONTEXT.md D-04, D-16; first-principles cluster analysis] |
| Analytic match PMFs | Monte Carlo match distributions | Analytic NB/Poisson PMFs eliminate finite-sample noise and missing observed cells; retain Monte Carlo only for tournament paths. [VERIFIED: current Monte Carlo implementation; recommendation] |
| CSV/RDS artifacts | New database/Parquet layer | The benchmark is only 630 fixtures plus long score grids, and repository conventions favor inspectable CSV/RDS contracts. [VERIFIED: repository inventory and patterns] |

**Installation:** No new package installation is required. Use the already-installed project stack and record exact versions in each run manifest. [VERIFIED: environment audit 2026-07-20]

## Package Legitimacy Audit

Not applicable: Phase 09 should add no external package dependency. All named packages above are already used or installed in this repository, and their versions were checked locally and against official CRAN pages. [VERIFIED: `_targets.R`; environment audit; CRAN]

## Architecture Patterns

### System Architecture Diagram

```text
Checked source results + curated edition/status/regulation corrections
                              |
                              v
              Tournament / fixture / format registries
                              |
                       validate + hash
                              |
                              v
             Fold × track boundary state machine
          +-------------------+--------------------+
          |                                        |
     frozen pre-opener                     updating date batch d
     evidence date < opener                evidence date < d
          |                                        |
          +-------------------+--------------------+
                              v
             Point-in-time training + feature contract
                    |                     |
            recursive Elo stream     supervised weights
                    |                     |
                    +----------+----------+
                               v
                  Registered model adapter API
    uniform | historical | Elo goal | open NB | production hybrid NB
                               |
                               v
                 Common complete score distribution
                               |
          +--------------------+--------------------+
          |                                         |
 derived match markets/proper scores      frozen tournament simulator
          |                                         |
          +--------------------+--------------------+
                               v
                  tournament-first aggregation
                               |
                  paired tournament uncertainty
                               |
                               v
           ordered promotion/veto decision + checksums
                               |
                        immutable run bundle

External service boundary: optional restricted-data snapshots remain local and
may populate only a predeclared feature-rich panel; they never alter open_core.
```

[VERIFIED: 09-CONTEXT.md D-01..D-20; repository layered architecture]

### Recommended Project Structure

```text
R/
├── benchmark/
│   ├── registry.R             # tournament, fixture, format, panel loaders/validators
│   ├── cutoffs.R              # boundary state machine and 2026 seal guard
│   ├── weights.R              # one registered recency/importance schedule
│   ├── contracts.R            # adapter, prediction, distribution, manifest validators
│   ├── baselines.R            # five registered baseline adapters
│   └── runner.R               # fold/track execution and immutable bundle writer
├── evaluation/
│   ├── proper_scores.R        # existing formulas; only generic extensions
│   ├── benchmark_scores.R     # fixture/tournament/headline aggregation, calibration
│   └── promotion.R            # paired uncertainty and pure veto decision
└── forecast/
    └── tournament_formats.R   # three format adapters and shared simulator

data/benchmark/phase09/
├── tournaments.csv
├── fixtures.csv
├── teams.csv
├── formats.csv
├── route_rules.csv
├── panels.csv
├── panel_fixtures.csv
├── model_registry.csv
├── feature_contract.csv
├── seed_registry.csv
└── promotion_protocol.json

outputs/benchmarks/rolling_tournaments/<run_id>/
├── manifests/
├── predictions/
├── scores/
├── stage_probabilities/
├── comparisons/
└── run_manifest.csv

tests/testthat/
├── test_benchmark_registry.R
├── test_benchmark_cutoffs.R
├── test_benchmark_contracts.R
├── test_benchmark_baselines.R
├── test_benchmark_scoring.R
├── test_benchmark_promotion.R
└── test_benchmark_pipeline.R
```

This layout makes the new harness authoritative without deleting or changing legacy EURO 2024 outputs. [VERIFIED: 09-CONTEXT.md code insights; repository conventions]

### Pattern 1: Registry-driven state machine

**What:** Every run starts from immutable registry rows. Runtime code never discovers tournaments with date regexes or chooses a cutoff from the data it is about to score. [VERIFIED: BENCH-01, BENCH-02]

**When to use:** Every frozen or updating fold branch.

**Key invariant:** `max(training_completion_date, feature_source_date, result_source_date) < evidence_cutoff_exclusive <= assessment_date`. [VERIFIED: existing strict-before lookup pattern in `R/forecast/features.R`]

### Pattern 2: Thin model adapter, thick shared validator

**What:** A model adapter implements `fit()`, `predict_score_distribution()`, and `manifest()`. The harness derives markets and expected goals, validates the distribution, joins fixture identity, and writes common artifacts. [VERIFIED: recommendation derived from BENCH-03]

**When to use:** All baselines now and all Phase 10/11 challengers later.

**Adapter return contract:** one complete score grid per requested fixture, one manifest, and one feature-coverage table; no adapter writes final metric tables. [VERIFIED: 09-CONTEXT.md D-15]

### Pattern 3: Tournament-first scoring

**What:** Score fixtures, average each edition, then average the 12 edition estimates. Store the pooled fixture average separately. [VERIFIED: 09-CONTEXT.md D-04]

**When to use:** Every headline metric, delta, and veto input.

### Pattern 4: Pure promotion decision

**What:** `evaluate_promotion(candidate_summary, incumbent_summary, manifests, protocol)` performs no fitting and no I/O except returning a decision row. Gate order is fixed: contract failures → core RPS effect/CI → breadth/regression → supporting metrics/calibration → optional-panel requirement → reproducibility/seal. [VERIFIED: 09-CONTEXT.md D-16..D-20]

**When to use:** Phase 09 baseline self-checks, Phase 10/11 comparisons, and final Phase 12 promotion.

### Anti-Patterns to Avoid

- **One script per model:** This recreates model-specific fixture filters and scoring paths. Use adapters behind one runner. [VERIFIED: BENCH-03]
- **Discovering folds from observed rows:** It lets missing data change the benchmark. Registries define the denominator before model execution. [VERIFIED: 09-CONTEXT.md D-05, D-15]
- **Refitting fixture by fixture:** Same-day results would leak under date-only source precision and work would multiply unnecessarily. Refit once per completed date batch. [VERIFIED: cutoff protocol]
- **Using `Sys.Date()`/`Sys.time()` as benchmark logic:** It makes historical runs non-reproducible. Runtime timestamps may appear only in manifests; cutoffs come from registries. [VERIFIED: existing `_targets.R` environment-cutoff pattern is unsuitable as a historical fold definition]
- **Silent NB-to-Poisson fallback:** A registered NB baseline that silently changes family is not reproduced. Mark failure or predeclare a fallback as a distinct model ID. [VERIFIED: current `train_goal_model_from_features()` behavior; 09-CONTEXT.md D-14]
- **Model-specific seeds:** Existing EURO simulation offsets seeds by model; common comparisons require seed IDs independent of model. [VERIFIED: `R/benchmark/euro2024_tournament.R`; 09-CONTEXT.md D-15]
- **Zero-filling optional data without a flag:** Current feature lookups often default to zero. Phase 09 must record imputation and must not let zero mean both “true zero” and “missing.” [VERIFIED: `R/forecast/features.R`; BENCH-03]

## Registered Baseline Design

### 1. Uniform 1X2 sanity floor

Set `p_home = p_draw = p_away = 1/3`. To satisfy the score-distribution contract without inventing contradictory markets, estimate the pre-cutoff empirical conditional score distribution within each outcome class using the registered weights and fixed smoothing, then mix the three conditional distributions with equal `1/3` weights. [VERIFIED: 09-CONTEXT.md D-11, D-15; prescriptive coherent construction]

Use a fixed Jeffreys-style `0.5` pseudocount per cell on the global score support before class conditioning. This ensures finite exact-score log loss for every supported cell and is frozen across boundaries. [VERIFIED: prescriptive smoothing choice] Derive expected goals, totals, and BTTS from the resulting joint distribution. The fixture teams, Elo, and optional features are ignored. [VERIFIED: no-strength control definition]

### 2. Expanding historical 1X2 base-rate comparator

Estimate weighted pre-cutoff `P(home/draw/away)` from all eligible senior internationals, using the same conditional scoreline distributions and smoothing as the uniform control. Mix by the estimated weighted class probabilities. [VERIFIED: 09-CONTEXT.md D-08, D-09, D-11; prescriptive coherent construction] Venue can be included only if it is registered now as a stratification rule; the simplest transparent baseline is one global rate and should be frozen as such. [VERIFIED: prescriptive choice]

### 3. Elo-only goal model

Create two long rows per match, one from each team's perspective. Fit one NB model to goals with only point-in-time `elo_difference_for_team` and `venue_advantage_for_team ∈ {-1,0,1}`; no designated-home intercept is needed, so neutral fixtures are symmetric under team-order reversal. [VERIFIED: 09-CONTEXT.md D-12; prescriptive formula]

Elo itself uses the existing full recursive senior-international stream and no supervised recency/importance weights. The NB coefficient fit uses the registered supervised row weights because D-09 applies one schedule to every supervised baseline. [VERIFIED: 09-CONTEXT.md D-06..D-09] Emit independent NB marginals and the analytic joint grid. [VERIFIED: D-12]

### 4. Open-data NB incumbent

Use `build_forecast_feature_table()` plus the registered `baseline_goal_predictors()` intent (`elo_diff`, `xgf_ewma_diff`, `xga_ewma_diff`, `xgd_ewma_diff`, `form_index_diff`) and weighted full-history fitting through `train_goal_model_from_features()` mechanics. [VERIFIED: `R/forecast/poisson.R`; `R/benchmark/euro2024.R`] Freeze the predictor list even when a fold has zero variance; record inactive terms and the reason in the manifest. Do not call the legacy `train_home_goal_model()`/`train_away_goal_model()` sampled-data branch because it samples rows without a benchmark seed and does not use the shared feature table. [VERIFIED: `R/forecast/poisson.R`]

The current local rolling-form artifact has effectively no historical tournament coverage, so Phase 09 may reveal that this incumbent collapses toward an Elo-only specification on the open core. That is an evidence result, not a reason to backfill features or alter the baseline. [VERIFIED: repository data inventory; 09-CONTEXT.md D-14]

### 5. Feature-rich production hybrid NB

Use the registered `hybrid_goal_predictors()` and current production mechanics only on a predeclared paired rich panel. Preserve feature source dates, Transfermarkt license class, missingness, active coefficients, and local-only provenance. [VERIFIED: `R/forecast/poisson.R`; `R/benchmark/euro2024.R`; `.planning/PROJECT.md`] A fixture enters that panel only if both teams satisfy every required optional-data rule at the cutoff; panel membership is frozen before model output is examined. [VERIFIED: 09-CONTEXT.md D-05, D-19]

For a future optional-data challenger to be eligible for default promotion, register an open-mode companion variant on `open_core` and a rich variant on the paired panel. An optional-only model with no valid open-core output may win an enriched-mode comparison but cannot replace the default open-data model. [VERIFIED: 09-CONTEXT.md D-19, D-20; `.planning/PROJECT.md` core value]

## Statistical Implementation

### Proper scores and fixed scales

- **RPS:** Keep the repository formula, class order `home, draw, away`, and division by the two non-trivial cumulative boundaries. Perfect = 0; the maximally wrong extreme = 1; uniform versus a home win = `5/18`. The promotion threshold `-0.003` is interpreted on this exact normalized scale. [VERIFIED: `R/evaluation/proper_scores.R`; `tests/testthat/test_worldcup_scoring.R`; RPS cumulative-definition source: https://journals.ametsoc.org/view/journals/mwre/98/12/1520-0493_1970_098_0917_trpsat_2_3_co_2.xml]
- **Multiclass Brier:** Keep the sum of three squared class errors, not the mean across classes; range is 0 to 2. [VERIFIED: `R/evaluation/proper_scores.R`; hand tests]
- **Log loss:** Keep natural logarithms with `epsilon = 1e-15`; all distributions must be smoothed/analytic so epsilon is a numerical guard, not routine mass creation. [VERIFIED: `R/evaluation/proper_scores.R`]
- **Derived targets:** Continue joint scoreline log loss, home/away marginal goal RPS, totals 2.5 Brier/log loss, BTTS Brier/log loss, exact-score hit, and expected-goal errors as supporting diagnostics. [VERIFIED: `R/evaluation/worldcup_retrospective.R`]

RPS is a proper cumulative score for ordered categories, but football-forecast literature also argues that log score can be more discriminating and that RPS's distance sensitivity is not automatically desirable. Keeping Brier and log loss as prominent veto metrics is therefore statistically sensible and already locked. [CITED: https://www.degruyter.com/document/doi/10.1515/jqas-2019-0089/html; VERIFIED: 09-CONTEXT.md D-18]

### Equal-tournament aggregation

For model `m`, track `r`, tournament `t`, and metric `s`:

```text
S_mrt = mean_i(score_mrti) over the registered, paired fixture set in t
S_mr_headline = (1/12) * sum_t(S_mrt)
S_mr_fixture_weighted = sum_t(n_t * S_mrt) / sum_t(n_t)
```

Never average already-rounded values. A model/panel comparison uses the intersection declared by `panel_fixtures.csv`, then asserts both models produced exactly that set; it does not compute an accidental runtime intersection. [VERIFIED: 09-CONTEXT.md D-04, D-05, D-15]

### Paired tournament uncertainty

For challenger `c` and incumbent `b`, compute `d_t = RPS_ct - RPS_bt` on identical fixture IDs, then `delta = mean(d_t)` across 12 tournaments. With fixed bootstrap seed and `B = 10,000`, resample the 12 paired tournament IDs with replacement and take the 2.5th/97.5th type-8 quantiles of bootstrap means. [VERIFIED: 09-CONTEXT.md D-16; deterministic bootstrap/quantile pattern in `R/evaluation/worldcup_retrospective.R`; prescriptive cluster level and B]

Also report all 12 `d_t` values and leave-one-tournament-out headline deltas. The bootstrap CI is the promotion gate; leave-one-out is a stability diagnostic, not another hidden gate. [VERIFIED: prescriptive choice consistent with D-16/D-17]

### Calibration error

Use one-vs-rest, fixed-width bins `[0,.1), ... [.9,1]` shared by every model. Weight each fixture-class observation by `1 / (3 * n_t)` within its tournament so each tournament contributes equally; within each class/bin compare the weighted mean probability with weighted observed frequency, weight the absolute gap by bin weight, and average the three class errors. [VERIFIED: prescriptive estimator consistent with equal-tournament policy] Emit bin counts and a sparse flag for diagnostics, but do not change bins by model or by observed outcomes. This avoids model-specific quantile bins changing the estimand. [VERIFIED: contrast with `make_calibration_bins()` implementation; recommendation]

### Promotion and veto logic

Define all lower-is-better deltas as `challenger - incumbent`. Apply the locked checks without rounding:

1. Core headline RPS delta `<= -0.003`.
2. Paired 95% bootstrap CI upper endpoint `< 0`.
3. `sum(d_t < 0) >= 8`, including at least two World Cups and two Euros; exact ties do not count as wins.
4. `max(d_t) <= 0.015`.
5. Relative Brier worsening `(Brier_c - Brier_b) / Brier_b <= 0.01`.
6. Relative log-loss worsening `(Log_c - Log_b) / Log_b <= 0.01`.
7. Calibration worsening `ECE_c - ECE_b <= 0.01`.
8. Every probability, distribution, fixture, coverage, provenance, licensing, seed, checksum, and reproducibility check passes.
9. If optional data are used, rich-panel comparison versus production hybrid passes the same predeclared effect/uncertainty policy and the registered open companion passes core non-regression/promotion requirements.

[VERIFIED: 09-CONTEXT.md D-16..D-20; formulas make the locked prose executable]

If any hard contract fails, emit `decision = "veto"` with all failed reason codes; do not continue to a favorable score comparison. If statistical gates fail with clean contracts, emit `decision = "retain_incumbent"`. [VERIFIED: prescriptive decision semantics]

## Historical Edge-Case Policy

### Postponed, suspended, abandoned, replayed, and awarded fixtures

| Case | Registry handling | Fit/scoring handling |
|------|-------------------|----------------------|
| Postponed before play | Keep stable `fixture_id`; update schedule version and move to actual completion-date batch. | No result becomes eligible until completion; frozen forecast remains unchanged, updating forecast may be reissued at the rescheduled boundary. [VERIFIED: cutoff protocol] |
| Suspended then resumed | One fixture with status history and final `actual_completion_date`. | Use no partial result; unlock only after official completion. [VERIFIED: leakage principle] |
| Abandoned and never completed | Retain row and reason; never drop silently. | `fit_eligible=false`, `score_eligible=false`; report denominator/exclusion. [VERIFIED: 09-CONTEXT.md D-15] |
| Replayed | Link original and replay records with `supersedes_fixture_id`; only official deciding fixture is score eligible. | Original prediction remains provenance evidence; final official assessment row controls scoring. [VERIFIED: prescriptive policy] |
| Awarded administratively | Retain official result/status but mark non-generative. | Exclude from count-model fitting and proper-score comparison unless the protocol explicitly predeclares otherwise; report coverage. [VERIFIED: prescriptive policy] |

The upstream result source cannot identify these statuses, so the fixture registry must cite a supplemental official source for any non-ordinary row. [CITED: https://github.com/openfootball/internationals]

### Regulation time, extra time, and penalties

All match-level goals and 1X2 scores are regulation-time targets. Store regulation, final-after-extra-time, and shootout winner separately. Never encode a shootout winner as a regulation win, and never add shootout goals to the count response. [VERIFIED: Phase 08 scoring contract; `R/evaluation/worldcup_retrospective.R`]

For assessment, every knockout fixture requires verified regulation goals even when raw `home_score/away_score` appears plausible. For subsequent-fold supervised training, use the corrected regulation score where the registry has one; otherwise preserve the raw senior-international row with an explicit `score_period_quality = "source_unspecified"` limitation rather than silently claiming it is verified 90-minute data. [CITED: https://github.com/openfootball/internationals; prescriptive provenance policy]

Stage advancement is a separate binary target based on extra time/penalties and belongs in stage/tournament diagnostics, not the headline regulation 1X2 RPS. [VERIFIED: `R/evaluation/worldcup_retrospective.R::score_knockout_advancement()`]

### Host and neutral treatment

Use the fixture-level `neutral`/venue fact for model inputs. Do not infer home advantage from the edition's host list alone: Euro 2020 was multi-host and the current data identify 28 of its 51 fixtures as non-neutral, unlike ordinary single-host editions. [VERIFIED: repository R inventory run 2026-07-20]

Store `home_is_host`/`away_is_host` separately for later context ablations, but D-12's Elo-only model consumes only Elo difference and fixture venue role. For neutral fixtures, swapping team order must swap the two goal marginals and 1X2 probabilities without otherwise changing the distribution. [VERIFIED: 09-CONTEXT.md D-12; current neutral-symmetry intent in `R/forecast/monte_carlo.R`]

### Tournament naming and team identity

- Use stable `edition_id` and `competition_id`; display strings are labels, not keys. [VERIFIED: Euro 2020 date/name issue in repository data]
- Use a stable internal `team_id` backed by checked FIFA code and canonical name. Resolve aliases once in `teams.csv`; adapters never normalize ad hoc. [VERIFIED: `AGENTS.md`; current duplicated alias logic across `R/forecast/features.R` and `R/evaluation/worldcup_ledger.R`]
- Do not collapse historical national entities into successor teams without an explicit mapping policy. Preserve the identity used for each fixture and expose any lineage relationship separately. [VERIFIED: prescriptive identity safety]
- Validate no duplicated FIFA code, no missing team ID in the 630 fixtures, and no display-name join in prediction/scoring code. [VERIFIED: BENCH-03]

### Optional panels and missing coverage

Panel eligibility is a property of a predeclared fixture, not a model's successful runtime output. The rich panel should require both teams to have all registered optional source vintages strictly before the fixture boundary. [VERIFIED: 09-CONTEXT.md D-05, D-19] Keep predictions for ineligible fixtures as explicit `prediction_status = "panel_ineligible"` rows where practical, and always write the full 630-row coverage audit. [VERIFIED: D-15]

Missing optional features may be imputed only when the model registry defines the imputation and a missingness indicator. Current zero defaults are not sufficient provenance. [VERIFIED: `R/forecast/features.R`; recommendation] A rich-panel comparison is valid only when candidate and hybrid incumbent have identical eligible fixture IDs and each included edition meets the frozen minimum coverage rule. [VERIFIED: D-19]

Register that minimum as at least 80% of official fixtures within every one of the 12 editions, with 100% prediction/distribution/provenance coverage on the fixtures declared eligible. If any edition falls below 80%, the rich panel is descriptive only and cannot support promotion. [VERIFIED: prescriptive panel policy consistent with D-05, D-15, D-19]

## Literature Lineage and Scope Mapping

| Lineage | Verified method | Phase 09 implication | Later candidate / ablation |
|---------|-----------------|----------------------|----------------------------|
| Hoffmann, Ging & Ramasamy (2002) | OLS model of FIFA ranking points using per-capita wealth and its square, squared deviation from 14°C, prior host status, and Latin-culture × population; the paper reports inverted-U wealth/temperature relationships. [CITED: https://ucema.edu.ar/publicaciones/download/volume5/hoffmann.pdf] | Structural variables need vintage provenance and should not enter the open benchmark as an unregistered baseline. | Phase 11 sparse-team structural prior, not a Phase 09 implementation. |
| Groll & Abedieh | Pairwise Poisson GLMM for EURO goals with team/match random effects and sparse variable selection; the EURO 2012 model used the two prior EUROs and selected a small covariate set. [CITED: https://cms-cdn.lmu.de/media/16-finmath/publikation/euro.pdf] | The common adapter must support long matched-pair goal rows and model manifests, but no GLMM is added now. | Phase 10/11 comparison or historical ablation only if predeclared. |
| Groll, Schauberger & Tutz (2015) | Team-specific attack/defence effects plus covariate differences in regularized Poisson regression, with group LASSO/LASSO and historical 10-fold CV. [CITED: https://epub.ub.uni-muenchen.de/31579/1/Groll_Prediction.pdf] | Preserve its model structure as a candidate interface, but replace random 10-fold tuning with inner chronology-safe procedures later; outer assessment remains whole tournaments. | Phase 10 penalized Poisson. |
| Groll, Kneib, Mayr & Schauberger (2018) | Sparse bivariate Poisson on three prior EUROs, boosting covariate selection, and repeated tournament simulation to examine score dependence. [CITED: https://doi.org/10.1515/jqas-2017-0067] | Complete joint score distributions and a dependence-capable adapter are mandatory now; do not implement the dependence model in Phase 09. | Phase 10 bivariate-Poisson/Dixon-Coles comparison. |
| Zeileis, Leitner & Hornik (2016) | Margin-adjusted consensus from 19 bookmakers, transformed into draw-adjusted Bradley-Terry-style abilities and tournament survival probabilities. [CITED: https://www.econstor.eu/bitstream/10419/146132/1/859777529.pdf] | Stage output and external-panel provenance must accommodate a market benchmark without making it part of open core. | Phase 11 external/bookmaker mode only. |
| Groll, Ley, Schauberger & Van Eetvelde (2018/2019) | Random forests and Poisson ranking abilities were compared on World Cups 2002-2014; adding separately estimated ability parameters to the random forest improved predictive performance in that study. [CITED: https://arxiv.org/abs/1806.03208; https://portal.fis.tum.de/en/publications/a-hybrid-random-forest-to-predict-soccer-matches-in-international/] | The adapter must allow independently estimated ability features with source cutoffs and coverage, but Phase 09 stops at the registered baselines. | Phase 11 Groll-style RF plus ability. |
| Joachim Klement adaptation | Klement's 2026 note says his proprietary model is rooted in Hoffmann et al. and uses GDP/capita, population/football culture, temperature, host status, FIFA ranking points, and chance. [CITED: https://beautifulpool.org/wp-content/uploads/2026/05/panmure-prediction.pdf] | It is not a reproducible Groll implementation and should not become a baseline. Treat it as evidence that the Hoffmann structural lineage can be adapted as a prior. | Phase 11 structural-prior ablation; label proprietary limitations. |

The literature mostly evaluates one upcoming tournament after fitting prior tournaments and often performs ordinary cross-validation inside pooled historical matches. Phase 09 should preserve the model ideas while enforcing the project's stronger outer tournament-blocked, date-updating, common-fixture contract. [CITED: papers above; VERIFIED: BENCH-01..BENCH-05]

## Don't Hand-Roll

| Problem | Don't build | Use instead | Why |
|---------|-------------|-------------|-----|
| Proper-score formulas | New RPS/Brier/log implementations per model | Existing `R/evaluation/proper_scores.R` | The scales are tested and tied to promotion thresholds. [VERIFIED: codebase] |
| Point-in-time feature joins | Ad hoc `merge()` followed by latest-row selection | Existing strict latest-before lookup pattern plus new cutoff validator | Same-day/future leakage is easy to introduce. [VERIFIED: `R/forecast/features.R`] |
| Team aliasing | Normalization inside each adapter | One checked team registry derived from `team_name_map.csv` | Current modules already have divergent alias maps; one identity contract prevents model-specific fixture mismatches. [VERIFIED: codebase] |
| Checksum algorithm | Custom hash or concatenation without canonical ordering | `digest::digest(..., algo="sha256")` with sorted canonical serialization | Phase 08 already uses it and it is installed. [VERIFIED: `R/evaluation/worldcup_ledger.R`; CRAN digest docs] |
| NB likelihood | Custom optimizer | `MASS::glm.nb` with explicit weights/convergence manifest | Existing stack and behavior are understood. [VERIFIED: codebase] |
| Tournament routing | One-off edition simulator copied 12 times | Three format adapters plus data-driven route rules | The 12 editions reduce to three structural families. [VERIFIED: fold inventory] |
| Missing-data panel selection | Runtime `complete.cases()` intersection | Frozen `panel_fixtures.csv` | Runtime filtering can favor a model and change denominators. [VERIFIED: D-05, D-15, D-19] |
| Randomness | One mutable global RNG stream | Checked seed registry/common random-number ledger | Execution order and parallelism must not change outputs. [VERIFIED: D-15, D-20] |

**Key insight:** The hard part is not another score formula or model fit; it is making fixture identity, evidence admissibility, output completeness, and comparison denominators impossible for an adapter to redefine. [VERIFIED: repository and requirement synthesis]

## Common Pitfalls

### Pitfall 1: Treating Mart Jürisoo rows as a complete benchmark registry

**What goes wrong:** Extra-time goals can be scored as regulation goals, stage routes cannot be simulated, and abnormal fixture statuses disappear. [CITED: https://github.com/openfootball/internationals]

**How to avoid:** Curate source-attributed assessment/status/format fields and make registry reconciliation the first phase gate.

**Warning signs:** No `regulation_*`, `stage_id`, `format_id`, or `status` columns; 630 rows are selected only by date regex.

### Pitfall 2: Updating within a date

**What goes wrong:** Source row order becomes a fake kickoff order and later loop rows see same-day results. [VERIFIED: source has dates but no times]

**How to avoid:** One model/feature/Elo snapshot per edition-date batch; assert identical `boundary_id` state hashes for all same-date fixtures.

### Pitfall 3: Equal-fixture aggregation masquerading as equal-tournament

**What goes wrong:** 64-match World Cups and modern 51-match Euros dominate 31-match Euros. [VERIFIED: fold inventory]

**How to avoid:** Materialize tournament estimates before headline estimates and test a synthetic unequal-size example.

### Pitfall 4: Accidental model-family changes

**What goes wrong:** `glm.nb` failure silently returns Poisson, or zero-variance removal changes the active formula without provenance. [VERIFIED: `R/forecast/poisson.R`]

**How to avoid:** Registered model family is an invariant; fallback is failure or a separately registered model ID; active/dropped predictors are manifest fields.

### Pitfall 5: Incoherent no-strength controls

**What goes wrong:** A 1X2 control emits arbitrary scoreline, totals, and expected-goal probabilities that do not reproduce its stated 1X2. [VERIFIED: D-15 logical requirement]

**How to avoid:** Use weighted empirical scoreline distributions conditional on outcome, then mix by uniform or historical outcome weights.

### Pitfall 6: Empirical Monte Carlo score grids as canonical predictions

**What goes wrong:** Finite samples omit low-probability cells, making exact-score log loss fail or depend on seed. [VERIFIED: `simulate_fixture()` stores only sampled cells; `score_scoreline_distribution()` rejects absent observed cells]

**How to avoid:** Analytic PMFs for count models; full zero-filled rectangular support; bounded tail; tournament-only simulation.

### Pitfall 7: Bootstrap at the wrong unit

**What goes wrong:** Resampling 630 fixtures understates tournament-level uncertainty and contradicts equal-tournament weighting. [VERIFIED: D-04 and cluster structure]

**How to avoid:** Pair models within fixture, aggregate within edition, then bootstrap 12 edition deltas.

### Pitfall 8: Quantile calibration bins differ by model

**What goes wrong:** ECE deltas partly measure different bin boundaries. [VERIFIED: current `make_calibration_bins()` builds quantile bins per sample/view]

**How to avoid:** Fixed shared probability bins and equal-tournament observation weights for the promotion ECE; retain quantile bins only as plots.

### Pitfall 9: 2026 outcomes present in a globally loaded table

**What goes wrong:** A harmless-looking feature/tuning helper can inspect final-holdout labels even if the outer fold later filters them. [VERIFIED: current result data extend through 2026-07-19]

**How to avoid:** Purpose-gated loaders return label-redacted data before any model code; synthetic tests inject a forbidden 2026 row into every entry point.

### Pitfall 10: Optional panel becomes the de facto headline

**What goes wrong:** Better coverage in modern tournaments or stronger teams changes the estimand and hides open-core regression. [VERIFIED: D-05, D-19]

**How to avoid:** Render core first, rich panel second; always show panel fixture IDs/coverage; default promotion requires the open companion.

## Code Examples

Verified patterns and implementation sketches for the planner:

### Strict date-batch construction

```r
# Source pattern: R/forecast/features.R uses strict date < lookup_date.
make_update_boundaries <- function(fixtures) {
  dates <- sort(unique(as.Date(fixtures$actual_completion_date)))
  data.frame(
    boundary_id = paste(fixtures$edition_id[1], dates, sep = "__"),
    edition_id = fixtures$edition_id[1],
    sequence = seq_along(dates),
    assessment_date = dates,
    evidence_cutoff_exclusive = dates,
    stringsAsFactors = FALSE
  )
}

eligible_history <- function(history, boundary) {
  history[as.Date(history$actual_completion_date) <
            as.Date(boundary$evidence_cutoff_exclusive), , drop = FALSE]
}
```

[VERIFIED: `R/forecast/features.R`; cutoff protocol]

### Registered supervised weights

```r
# Source pattern: R/forecast/goal_ability.R
benchmark_weights <- function(date, tournament, cutoff) {
  age_days <- as.numeric(as.Date(cutoff) - as.Date(date))
  recency <- 0.5 ^ (age_days / 730)
  importance <- tournament_importance_weight(tournament)
  weight <- recency * importance
  weight / mean(weight)
}
```

[VERIFIED: `R/forecast/goal_ability.R`; mean normalization is the registered Phase 09 choice]

### Tournament-first aggregation

```r
# Source policy: 09-CONTEXT.md D-04
fold_scores <- aggregate(
  value ~ model_id + track + panel_id + edition_id + metric,
  data = fixture_scores,
  FUN = mean
)

headline <- aggregate(
  value ~ model_id + track + panel_id + metric,
  data = fold_scores,
  FUN = mean
)
headline$aggregation <- "equal_tournament"
```

[VERIFIED: 09-CONTEXT.md D-04]

### Paired tournament bootstrap

```r
# Source pattern: R/evaluation/worldcup_retrospective.R deterministic bootstrap.
paired_tournament_ci <- function(delta_by_tournament, reps = 10000L,
                                 seed = 20260720L, conf = 0.95) {
  stopifnot(length(delta_by_tournament) == 12L, all(is.finite(delta_by_tournament)))
  set.seed(seed)
  draws <- replicate(
    reps,
    mean(sample(delta_by_tournament, 12L, replace = TRUE))
  )
  alpha <- (1 - conf) / 2
  stats::quantile(draws, c(alpha, 1 - alpha), type = 8, names = FALSE)
}
```

[VERIFIED: `R/evaluation/worldcup_retrospective.R`; 09-CONTEXT.md D-16]

### Pure promotion gate

```r
# Source policy: 09-CONTEXT.md D-16..D-20
promotion_pass <- function(x) {
  contract_ok <- all(unlist(x$contract_checks), na.rm = FALSE)
  statistical_ok <-
    x$rps_delta <= -0.003 &&
    x$rps_ci_upper < 0 &&
    x$fold_wins >= 8L &&
    x$world_cup_wins >= 2L &&
    x$euro_wins >= 2L &&
    x$max_fold_regression <= 0.015 &&
    x$brier_relative_worsening <= 0.01 &&
    x$log_relative_worsening <= 0.01 &&
    x$calibration_worsening <= 0.01
  isTRUE(contract_ok && statistical_ok && x$optional_panel_ok)
}
```

[VERIFIED: 09-CONTEXT.md D-16..D-20]

## State of the Art

| Legacy / paper approach | Phase 09 standard | Impact |
|-------------------------|-------------------|--------|
| One held-out tournament and one frozen cutoff | 12 complete rolling tournament blocks with frozen and updating tracks | Measures stability across eras and operational updating. [VERIFIED: D-01..D-04] |
| Random or ordinary 10-fold CV inside pooled tournament matches | Outer complete-tournament assessment; later tuning must remain chronology-safe inside training only | Prevents future-tournament leakage and optimistic model selection. [CITED: Groll et al. 2015/2018 papers above; VERIFIED: BENCH-01] |
| Model-specific probability/scoring paths | One complete joint-distribution adapter contract and one shared scorer | Makes metrics, markets, and coverage comparable. [VERIFIED: BENCH-03] |
| Winner-pick accuracy or one champion prediction | Proper match scores, stage probabilities, calibration, uncertainty, and explicit coverage | Avoids judging a probabilistic model by one noisy path. [VERIFIED: `.planning/ROADMAP.md`; RPS literature] |
| Fixture-pooled headline | Equal edition means, fixture pooling secondary | Prevents format expansion from silently reweighting model selection. [VERIFIED: D-04] |
| Unfrozen “best model” selection | Checksum-backed practical effect, CI, breadth, regression, metric, calibration, license, coverage, and reproducibility gates | Makes retention the default unless every gate passes. [VERIFIED: D-16..D-20] |

**Deprecated/outdated for the new authority:**

- `run_euro2024_benchmark()`'s `hybrid_pass` is not a promotion rule for v2.0; preserve it only as legacy output. [VERIFIED: `R/benchmark/euro2024.R`; D-16..D-20]
- `simulate_euro2024_tournament_models()`'s model-specific seed offsets violate the new shared-seed contract. [VERIFIED: `R/benchmark/euro2024_tournament.R`; D-15]
- Runtime filtering to available predictions is invalid; Phase 08 established that missing coverage must remain visible. [VERIFIED: Phase 08 context and summary]

## Planner-Ready Task Decomposition

### Plan 09-01: Canonical registries and leakage guard

1. Build the 12-edition tournament, fixture, format, route, team, panel, and boundary registries from the 630 checked source rows plus curated official stage/status/regulation corrections. [VERIFIED: data inventory]
2. Repair and test all tournament team IDs/FIFA-code coverage; eliminate display-name joins from the benchmark path. [VERIFIED: BENCH-03]
3. Implement validators, date-complete boundary generation, strict cutoff assertions, postponed/status policy, and the purpose-gated WC2026 seal. [VERIFIED: BENCH-01, BENCH-02]
4. Freeze registry checksums and add contract fixtures covering Euro 2020's played-year mismatch and all three format families. [VERIFIED: data inventory]

**Exit gate:** exactly 12 editions/630 unique fixtures; expected counts by edition; all score-eligible rows have verified regulation outcomes; every updating boundary is leakage-safe; development loaders reject synthetic WC2026 labels. [VERIFIED: requirements]

### Plan 09-02: Common adapter/output contract and baselines

1. Implement score-grid, market, model-manifest, feature-coverage, seed, and run-manifest validators. [VERIFIED: BENCH-03]
2. Add the registered weighting schedule and coherent uniform/historical score-distribution controls. [VERIFIED: D-06..D-11]
3. Add Elo-only, open NB, and production hybrid NB adapters; enforce deterministic full training rows, explicit NB family/convergence, and no silent fixture drops/fallbacks. [VERIFIED: D-12..D-15]
4. Add three tournament-format adapters and pre-tournament frozen stage simulation with shared random-number ledgers. [VERIFIED: D-15]

**Exit gate:** every baseline emits identical fixture keys and required outputs on its registered panel; distributions/markets reconcile; same-date state hashes agree; repeated runs are byte-identical except runtime timestamps isolated from content hashes. [VERIFIED: BENCH-03, BENCH-04]

### Plan 09-03: Shared scoring, uncertainty, and promotion protocol

1. Wrap existing proper scores at fixture grain; add fixed-bin tournament-weighted calibration. [VERIFIED: BENCH-05]
2. Implement tournament-first and secondary pooled aggregation, paired deltas, 10,000-replicate tournament bootstrap, fold breadth, competition breadth, maximum regression, and leave-one-out diagnostics. [VERIFIED: D-04, D-16, D-17]
3. Implement pure ordered veto logic, complete reason codes, optional-panel companion checks, and frozen JSON/CSV protocol artifacts. [VERIFIED: D-18..D-20]
4. Produce baseline self-comparisons that must yield exact zero deltas/CI and expected “retain incumbent” outcomes for weaker controls. [VERIFIED: recommendation]

**Exit gate:** hand-calculated synthetic cases prove each gate and threshold boundary; unequal tournament sizes prove headline weighting; one missing prediction/provenance/hash/license flag causes a veto. [VERIFIED: BENCH-05]

### Plan 09-04: Pipeline integration and sealed benchmark bundle

1. Add incremental `targets` branches for registry validation, boundary states, baseline predictions, stage simulations, scores, summaries, comparisons, and final manifests. [VERIFIED: `_targets.R`; targets docs]
2. Add a cache-only `run_rolling_tournament_benchmark()` entry point with explicit paths, seed registry, protocol version, and no network calls. [VERIFIED: Phase 08 runner pattern]
3. Run all 12 folds/tracks/baselines, reconcile artifacts, write the pre-WC2026 sealed benchmark/protocol checksums, and generate a compact report. [VERIFIED: Phase 09 success criteria]
4. Verify existing dashboard and Phase 08 tests remain unchanged, then run the full suite. [VERIFIED: 09-CONTEXT.md integration boundary]

**Exit gate:** all five BENCH requirements map to passing automated tests; baseline bundle is reproducible from checked inputs; dashboard outputs are unaffected; planner can hand Phase 10 a stable adapter registration API. [VERIFIED: roadmap]

This four-plan split minimizes dependency tangles: registries precede adapters, adapters precede scoring, and a full expensive run happens only after small synthetic contracts are green. [VERIFIED: dependency analysis]

## Environment Availability

| Dependency | Required by | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| R / Rscript | Entire phase | ✓ | 4.6.1 | None needed. [VERIFIED: local probe] |
| `targets` | Pipeline | ✓ | 1.12.0 | Direct runner can debug locally, but committed pipeline remains required. [VERIFIED: local probe] |
| `testthat` | Validation | ✓ | 3.3.2 | None needed. [VERIFIED: local probe] |
| `MASS` | NB baselines | ✓ | 7.3-65 | Do not silently fall back; fail and diagnose. [VERIFIED: local probe] |
| `digest` | SHA-256 manifests | ✓ | 0.6.39 | `shasum -a 256` is available, but keep one canonical implementation. [VERIFIED: local probes] |
| Git | Source provenance | ✓ | 2.54.0 | None needed. [VERIFIED: local probe] |
| `shasum` | Independent checksum verification | ✓ | 6.02 | `digest` is primary. [VERIFIED: local probe] |
| Local Transfermarkt DuckDB snapshot | Rich panel only | ✓ | File present | Rich panel remains optional; open core is unaffected. [VERIFIED: local probe] |
| Historical official stage/regulation/status supplement | Registry Wave 0 | ✗ as one canonical checked file | — | Curate from existing open rows plus source-attributed corrections before model work. [VERIFIED: repository inventory] |

**Missing dependency with no fallback:** a canonical source-attributed assessment/format registry is absent and blocks trustworthy stage simulation and regulation-time scoring. [VERIFIED: repository inventory]

**Missing dependencies with fallback:** none for the open core runtime. Optional rich data are explicitly panel-scoped. [VERIFIED: project design]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `testthat` 3.3.2 [VERIFIED: environment] |
| Config file | None; repository tests source modules directly. [VERIFIED: `tests/testthat/`] |
| Quick run command | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_benchmark_contracts.R"); testthat::test_file("tests/testthat/test_benchmark_scoring.R"); testthat::test_file("tests/testthat/test_benchmark_promotion.R")'` |
| Full suite command | `Rscript --vanilla -e 'testthat::test_dir("tests/testthat")'` [VERIFIED: `AGENTS.md`] |

The three closest existing files passed 126 selected expectations with zero failures/warnings/skips on 2026-07-20: scoring 33, retrospective 23, and Transfermarkt benchmark 70. [VERIFIED: local test run]

### Phase Requirements → Test Map

| Req ID | Behavior | Test type | Automated command | File exists? |
|--------|----------|-----------|-------------------|--------------|
| BENCH-01 | 12 exact folds, date-complete boundaries, frozen/updating semantics, strict prior-only evidence | Unit + integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_benchmark_cutoffs.R")'` | ❌ Wave 0 |
| BENCH-02 | Development paths reject 2026 labels before fitting/selection/tuning/calibration | Adversarial unit + pipeline | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_benchmark_seal.R")'` | ❌ Wave 0 |
| BENCH-03 | Common schemas, complete distributions, feature coverage, provenance, no missing fixture rows | Contract/property | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_benchmark_contracts.R")'` | ❌ Wave 0 |
| BENCH-04 | Five registered baselines use identical fixture/boundary/seed keys and reproduce outputs | Synthetic integration + artifact regression | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_benchmark_baselines.R")'` | ❌ Wave 0 |
| BENCH-05 | Equal-tournament metrics, paired CI, breadth/regression and every veto edge | Hand-calculated unit + integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_benchmark_promotion.R")'` | ❌ Wave 0 |

### Required property/edge tests

- Swapping teams on a neutral fixture swaps home/away probabilities and goal marginals exactly. [VERIFIED: D-12 contract]
- Same-date fixture ordering does not change predictions, fits, or Elo snapshots. [VERIFIED: cutoff protocol]
- Adding a future or WC2026 label anywhere causes the purpose guard to fail before adapter invocation. [VERIFIED: BENCH-02]
- Every score distribution has the full rectangular key set, non-negative finite probabilities, sum 1 within tolerance, bounded raw tail, and markets that reconcile. [VERIFIED: BENCH-03]
- Unequal synthetic tournament sizes produce different headline and pooled estimates with the headline equal to the unweighted mean of tournament means. [VERIFIED: D-04]
- Candidate/incumbent fixture permutations yield identical paired results; a missing row fails rather than shrinking the comparison. [VERIFIED: D-15]
- Threshold boundaries are inclusive/exclusive exactly as specified: delta `<= -0.003`, CI upper `< 0`, max regression `<= 0.015`, supporting worsening `<=` limits. [VERIFIED: D-16..D-18]
- A repeated run under a different branch execution order yields identical content hashes. [VERIFIED: BENCH-05]
- All three tournament format adapters reproduce known participant counts and champion mass 1. [VERIFIED: fold inventory]

### Sampling Rate

- **Per task commit:** relevant new test file plus `test_worldcup_scoring.R` when score contracts change.
- **Per wave merge:** all `test_benchmark_*.R` plus `test_transfermarkt_benchmark.R`, `test_worldcup_scoring.R`, and `test_worldcup_retrospective.R`.
- **Phase gate:** full `tests/testthat` suite, `targets::tar_manifest()` load, a deterministic rerun/hash comparison, and no dashboard artifact changes.

[VERIFIED: `AGENTS.md`; Phase 08 established test/manifest pattern]

### Wave 0 Gaps

- [ ] `data/benchmark/phase09/*.csv` plus source notes — canonical editions, fixtures, statuses, regulation scores, identities, formats, routes, panels, models, features, seeds.
- [ ] `tests/testthat/helper_benchmark.R` — compact synthetic histories, three format fixtures, adapter stubs, fixed distributions.
- [ ] `tests/testthat/test_benchmark_registry.R`
- [ ] `tests/testthat/test_benchmark_cutoffs.R`
- [ ] `tests/testthat/test_benchmark_seal.R`
- [ ] `tests/testthat/test_benchmark_contracts.R`
- [ ] `tests/testthat/test_benchmark_baselines.R`
- [ ] `tests/testthat/test_benchmark_scoring.R`
- [ ] `tests/testthat/test_benchmark_promotion.R`
- [ ] `tests/testthat/test_benchmark_pipeline.R`

No framework install is needed. [VERIFIED: environment]

## Security Domain

OWASP ASVS 5.0.0 is the latest stable ASVS release as of this research date. This phase is a local analytical pipeline rather than a web application, so authentication/session/access-control categories do not apply; input validation, integrity, unsafe deserialization, local path handling, and restricted-data disclosure do. [CITED: https://owasp.org/www-project-application-security-verification-standard/]

### Applicable ASVS Categories

| ASVS category | Applies | Standard control |
|---------------|---------|------------------|
| V2 Authentication | No | No user identity or login boundary in this phase. [VERIFIED: repository architecture] |
| V3 Session Management | No | No sessions. [VERIFIED: repository architecture] |
| V4 Access Control | No for application roles; yes for file scope | Benchmark runner accepts only project-relative registered paths and does not expose arbitrary file reads. [VERIFIED: prescriptive control] |
| V5 Input Validation | Yes | Central schema/range/key/cutoff validators run before adapter code and fail closed. [CITED: https://owasp.org/www-project-secure-coding-practices-quick-reference-guide/stable-en/02-checklist/05-checklist] |
| V6 Cryptography / integrity | Yes, integrity only | SHA-256 through the existing `digest` implementation; no custom cryptography and no secrets. [VERIFIED: `R/evaluation/worldcup_ledger.R`; CRAN digest docs] |

### Known Threat Patterns for the R file pipeline

| Pattern | STRIDE | Standard mitigation |
|---------|--------|---------------------|
| Modified fixture/protocol/model artifact after freeze | Tampering / Repudiation | Canonical serialization, SHA-256 manifest, Git SHA, parent hashes, verify-before-run. [VERIFIED: Phase 08 pattern] |
| Team alias spoof maps one fixture to the wrong team | Spoofing | Stable internal/FIFA IDs, one registry, no display-name scoring joins. [VERIFIED: BENCH-03] |
| Malformed CSV/RDS or injected unexpected columns | Tampering / Denial of service | Required/allowed column schemas, type/range checks, row/support caps, reject unknown enum values. [VERIFIED: prescriptive control] |
| User-controlled path escapes output/input root | Information disclosure / Tampering | Normalize paths, require approved project-relative roots, reject `..`/absolute external paths in registry values. [CITED: https://owasp.org/www-project/web-security-testing-guide/stable/4-Web_Application_Security_Testing/07-Input_Validation_Testing/11.1-Testing_for_Local_File_Inclusion] |
| Restricted Transfermarkt raw data copied into public bundle | Information disclosure | Emit aggregate feature values/coverage/provenance only; keep raw snapshot local and rich panel labelled. [VERIFIED: `.planning/PROJECT.md`] |
| Huge or non-normalized score grid exhausts memory or corrupts metrics | Denial of service / Tampering | Fixed global support, expected cell count, finite probability checks, tail bound, sum tolerance. [VERIFIED: prediction schema] |
| 2026 labels exposed to development code | Tampering of evaluation validity | Purpose-gated loader, denylist, sealed label manifest, adversarial tests. [VERIFIED: BENCH-02] |

## Assumptions Log

| # | Claim | Section | Risk if wrong |
|---|-------|---------|---------------|
| — | None. All factual claims are tied to repository inspection, locked context, local probes/tests, or cited primary/official sources. Prescriptive numeric choices are explicitly labelled as such. | — | — |

## Open Questions

1. **Which official or durable open source should back the 12-edition stage/status/regulation corrections?**
   - What we know: the repository's Mart Jürisoo lineage supplies all 630 base fixtures but explicitly lacks extra-time/status semantics and stage routing. [CITED: https://github.com/openfootball/internationals]
   - What is unclear: one already-licensed source may not expose every historical field uniformly.
   - Recommendation: create a source-attributed correction layer rather than replacing the base dataset; require source URL/license and row hash for every correction, and pause Plan 09-01 if regulation outcomes cannot be verified.

2. **Can the production hybrid be reconstructed with full point-in-time provenance for the entire rich panel?**
   - What we know: the local processed Transfermarkt snapshots span 2000-2026 and cover most edition teams, and the raw DuckDB snapshot is present; several historical aliases/teams are missing in a direct coverage audit. [VERIFIED: repository inventory]
   - What is unclear: whether every processed snapshot can be regenerated from the current raw snapshot with identical historical source semantics.
   - Recommendation: make regeneration/hash closure a Plan 09-02 gate. If it fails, retain the rich panel as descriptive with an explicit provenance veto; do not weaken the open core.

3. **Does `G = 15` satisfy the registered NB tail bound for every baseline/fold/boundary?**
   - What we know: target tournament observed scores are at most 8 home and 7 away in current data, but predictive NB tails depend on fitted means and dispersion. [VERIFIED: repository inventory]
   - What is unclear: worst fitted tail mass before the complete baseline dry run.
   - Recommendation: run a support audit before freezing models; if any tail exceeds `1e-10`, raise one global `G` and recompute protocol hashes. Never adapt support after viewing candidate scores.

## Sources

### Primary (HIGH confidence)

- `.planning/phases/09-rolling-tournament-benchmark-harness/09-CONTEXT.md` — locked folds, evidence, baselines, outputs, promotion, and scope.
- `.planning/REQUIREMENTS.md` and `.planning/ROADMAP.md` — BENCH-01..BENCH-05 acceptance and phase boundaries.
- `AGENTS.md` and `.planning/PROJECT.md` — R/targets, layer, data-license, Elo, NB, seed, and testing constraints.
- `R/benchmark/euro2024.R`, `R/benchmark/euro2024_tournament.R` — legacy benchmark patterns and limitations.
- `R/evaluation/proper_scores.R`, `R/evaluation/worldcup_retrospective.R`, `R/evaluation/worldcup_ledger.R` — validated scoring, coverage, uncertainty, provenance, and hashing services.
- `R/forecast/features.R`, `R/forecast/goal_ability.R`, `R/forecast/poisson.R`, `R/forecast/monte_carlo.R`, `R/forecast/tournament.R` — cutoff, weights, model, distribution, and simulator behavior.
- `_targets.R` and the relevant `tests/testthat/` files — pipeline and regression contracts.
- Local R/data inventory and selected tests run 2026-07-20 — 630 fixtures, edition counts, schema/coverage gaps, environment versions, and 126 passing relevant expectations.

### Secondary (MEDIUM confidence; official/primary literature reached through web search)

- https://journals.ametsoc.org/view/journals/mwre/98/12/1520-0493_1970_098_0917_trpsat_2_3_co_2.xml — RPS for ordered categories.
- https://www.degruyter.com/document/doi/10.1515/jqas-2019-0089/html — comparative football scoring-rule definitions and critique.
- https://ucema.edu.ar/publicaciones/download/volume5/hoffmann.pdf — Hoffmann, Ging & Ramasamy structural model.
- https://cms-cdn.lmu.de/media/16-finmath/publikation/euro.pdf — Groll/Abedieh EURO Poisson/GLMM lineage and replication.
- https://epub.ub.uni-muenchen.de/31579/1/Groll_Prediction.pdf — regularized team-specific Poisson model.
- https://doi.org/10.1515/jqas-2017-0067 — sparse bivariate Poisson model.
- https://arxiv.org/abs/1806.03208 — random forest plus independently estimated ability parameters.
- https://www.econstor.eu/bitstream/10419/146132/1/859777529.pdf — bookmaker consensus and stage simulation.
- https://beautifulpool.org/wp-content/uploads/2026/05/panmure-prediction.pdf — Klement's stated Hoffmann adaptation.
- https://github.com/openfootball/internationals — Mart Jürisoo mirror, license, and documented result-data omissions.
- Official CRAN pages for `targets`, `testthat`, `MASS`, `digest`, and `dplyr` — versions and publish dates.
- https://owasp.org/www-project-application-security-verification-standard/ — ASVS 5.0.0 status and scope.

### Tertiary (LOW confidence)

- None used for implementation decisions.

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — all required runtime/packages are existing repository dependencies and were checked locally; official CRAN versions were checked on 2026-07-20.
- Architecture: HIGH — directly derived from locked decisions and inspected modules/tests.
- Cutoff/statistical protocol: HIGH — formulas and estimands are explicit, existing score scales are tested, and discretionary choices are predeclared.
- Historical fixture semantics: MEDIUM — the base 630-row inventory is verified, but official stage/regulation/status supplementation is still a Wave 0 dependency.
- Literature mapping: MEDIUM — primary papers/official records were inspected, but model implementation belongs to later phases.
- Pitfalls: HIGH — most are observable in current code/data or direct consequences of the locked estimand.

**Research date:** 2026-07-20
**Valid until:** 2026-08-19 for package/environment details; architecture and literature remain valid until Phase 09 context or source registries change.
