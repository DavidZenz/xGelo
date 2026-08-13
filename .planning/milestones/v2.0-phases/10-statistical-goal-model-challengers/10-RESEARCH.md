# Phase 10: Statistical Goal-Model Challengers - Research

**Researched:** 2026-07-22  
**Domain:** Chronology-safe football score modelling, dependence correction, and controlled ablation in R  
**Confidence:** MEDIUM-HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Penalized Poisson Design

- **D-01:** Register a nested pair: a minimal team-specific attack/defence model
  with venue treatment, and a second open-data variant that adds stable
  covariates such as point-in-time Elo. Benchmark both so gains from team effects
  and gains from added covariates remain attributable.
- **D-02:** Stabilize team attack/defence effects with grouped or ridge-style
  shrinkage while permitting sparse selection among added covariates. Do not use
  a penalty that can silently erase sparse teams from the model.
- **D-03:** Before each assessment tournament, select penalty strength using only
  earlier completed tournaments through chronology-safe inner validation. Freeze
  the selected penalties for that tournament's frozen and updating tracks; do
  not retune from assessed-tournament results.
- **D-04:** Sparse and unseen teams shrink to the global log-scale team effect.
  Every fixture remains forecastable, and cold-start/shrinkage status is retained
  in the feature and model evidence.

#### Dynamic Attack And Defence

- **D-05:** Register two controlled dynamic variants: a standalone
  attack/defence score model and a second variant that adds point-in-time Elo.
  This explicitly tests whether dynamic ratings replace Elo or add information
  beyond it.
- **D-06:** Update ratings in deterministic matchday batches. Fixtures sharing a
  benchmark boundary use the same pre-boundary state, and their completed results
  affect only later boundaries; never impose arbitrary same-day ordering.
- **D-07:** Drive updates from observed scored and conceded goals using the
  frozen open-data recency and match-importance treatment. Historical xG is not
  mixed into this candidate while its point-in-time open-panel coverage is
  inactive.
- **D-08:** Preserve all eligible history but continuously revert attack and
  defence effects toward the global mean as inactivity grows. Do not use a fixed
  recent window or reset ratings at tournament-cycle boundaries.

#### Score Dependence

- **D-09:** Apply Dixon-Coles and bivariate-Poisson corrections to the same
  registered penalized-Poisson mean structure. Their comparison must isolate
  dependence rather than different predictors or mean models.
- **D-10:** Estimate one global dependence parameter from prior training data for
  each assessment fold and freeze it for the assessed tournament. Do not fit
  tournament-, era-, team-, or match-specific dependence parameters.
- **D-11:** Select the representative dependence implementation using
  tournament-weighted RPS first, subject to no material Brier, log-loss,
  calibration, fold-breadth, or stability regression. Prefer Dixon-Coles when
  the two corrections are practically tied.
- **D-12:** If neither valid dependence correction provides a practically
  meaningful gain, name the better correction as the research representative
  but retain independent Poisson as the preferred candidate. Added dependence
  is not carried forward merely because it is more expressive.

#### Incumbent Ablations And Handoff

- **D-13:** Use hierarchical ablations. Compare Elo-only with the complete
  xG/form block first; split attacking/defensive xG, xGD, and form only when
  observed coverage and block-level value justify deeper attribution. Do not
  search every feature subset.
- **D-14:** Retain the incumbent's zero-coded xG/form predictors for formula
  compatibility, but mark them explicitly as inactive because observed
  point-in-time coverage is zero. They must not be represented as genuine
  measured zeros or credited with predictive value.
- **D-15:** Prefer a smaller active predictor set under practical
  non-inferiority: tournament-weighted RPS is effectively unchanged and no
  supporting-score, calibration, or fold-stability veto appears. Coefficient
  significance alone is not a simplification rule.
- **D-16:** Phase 10 hands Phase 12 a small evidence-based shortlist containing
  the best proper-score candidate, the simplest non-inferior candidate, and the
  named dependence representative when distinct. It does not declare a final
  statistical winner or promotion decision.

### The Agent's Discretion

The planner may choose the exact long-format design matrices, identifiability
constraints, optimization packages, tuning grids, numeric mean-reversion form,
predeclared practical-tie/non-inferiority margins, candidate IDs, report layout,
and task decomposition. These choices must remain chronology-safe, deterministic,
compatible with the frozen 630-fixture open panel and G=40 score support, and
fully represented in model manifests and feature evidence.

### Deferred Ideas (OUT OF SCOPE)

None - discussion stayed within the Phase 10 boundary.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| STAT-01 | The analyst can benchmark a team-specific penalized Poisson model against the registered baselines. | Sparse two-row match design, nested ridge/offset-lasso fit, chronology-safe tuning registry, cold-start evidence, and all-baseline comparison matrix. [VERIFIED: `.planning/REQUIREMENTS.md`; CITED: https://glmnet.stanford.edu/articles/glmnet.html] |
| STAT-02 | The analyst can benchmark dynamic attack and defence ratings whose updates use only prior matches. | Deterministic date-batch state machine, fixed pseudo-exposure mean reversion, frozen recency/importance weights, and boundary-order tests. [VERIFIED: `.planning/REQUIREMENTS.md`; CITED: https://doi.org/10.1111/1467-9884.00243] |
| STAT-03 | The analyst can compare Dixon-Coles and bivariate-Poisson score-dependence corrections under the common benchmark contract. | Shared mean-model hash, fold-frozen global dependence parameters, G=40 normalized PMFs, and representative-selection protocol. [VERIFIED: `.planning/REQUIREMENTS.md`; CITED: https://doi.org/10.1111/1467-9876.00065; CITED: https://doi.org/10.1111/1467-9884.00366] |
| STAT-04 | The analyst can run controlled ablations of the incumbent model's correlated predictors and identify each retained feature set. | Hierarchical block gate, Elo-only incumbent sibling, explicit inactive-feature semantics, and practical non-inferiority evidence. [VERIFIED: `.planning/REQUIREMENTS.md`; VERIFIED: `data/benchmark/phase09/feature_contract.csv`] |
</phase_requirements>

## Summary

Phase 10 should be implemented as an overlay on the accepted Phase 9 benchmark, not as a new benchmark runner. The exact 630-fixture open panel, 609-fixture rich panel, 12 assessment tournaments, frozen/updating tracks, strict prior-only boundaries, equal-tournament aggregation, G=40 support, shared score derivation, and sealed World Cup 2026 boundary are already verified contracts. The Phase 9 bundle contains five baselines and durable predictions, so Phase 10 should reference that bundle by hash and compute paired comparisons without rerunning or copying it. [VERIFIED: `.planning/phases/09-rolling-tournament-benchmark-harness/09-VERIFICATION.md`; VERIFIED: `outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen/run_manifest.csv`]

Register seven Phase 10 candidates: minimal penalized Poisson, penalized Poisson plus Elo, dynamic attack/defence, dynamic attack/defence plus Elo, Dixon-Coles and bivariate-Poisson dependence siblings of the augmented penalized mean, and an Elo-only incumbent ablation. Keep the existing complete incumbent as the ablation parent; do not create deeper xG/form ablations because Phase 9 evidence records zero source/value coverage for those blocks. [VERIFIED: `data/benchmark/phase09/model_registry.csv`; VERIFIED: `outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen/feature_coverage.csv`]

The principal implementation risk is chronology rather than optimizer syntax. Penalties, dynamic hyperparameters, and dependence parameters must be selected from completed pre-assessment tournaments, recorded once per outer fold, and reused by both tracks. Every candidate must emit the existing score-distribution, evidence, manifest, and scoring schemas; Phase 10 adds an all-baseline paired-comparison service and shortlist evidence, but never calls the Phase 9 promotion evaluator. [VERIFIED: `R/benchmark/runner.R`; VERIFIED: `R/evaluation/promotion.R`; VERIFIED: `10-CONTEXT.md`]

**Primary recommendation:** Build a Phase 10 registry/adapter overlay with one shared chronological tuning service, preserve the Phase 9 scorer verbatim, and gate completion on candidate-by-every-baseline paired evidence plus deterministic replay tests. [ASSUMED]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Candidate fit/predict logic | Forecast/model layer | Benchmark adapter | The forecast layer owns statistical state and means; adapters translate to the frozen benchmark schema. [VERIFIED: `R/forecast/`; VERIFIED: `R/benchmark/baselines.R`] |
| Outer/inner chronology | Benchmark orchestration | Evaluation | Boundaries and eligible training evidence are runner responsibilities; evaluation aggregates already-produced predictions. [VERIFIED: `R/benchmark/runner.R`; VERIFIED: `R/evaluation/benchmark_scores.R`] |
| Score dependence | Forecast/model layer | Shared score-distribution service | Dependence modifies the joint PMF but must feed the common market derivation path. [VERIFIED: `R/benchmark/contracts.R`] |
| Proper scores and pairing | Evaluation | Benchmark orchestration | Shared scores own metric semantics; the runner owns exact panel projection and pairing. [VERIFIED: `R/evaluation/benchmark_scores.R`; VERIFIED: `R/benchmark/runner.R`] |
| Registries and frozen artifacts | Data/storage | Pipeline | CSV/JSON registries and hashed bundles are durable inputs/outputs; targets declares their dependency graph. [VERIFIED: `data/benchmark/phase09/`; VERIFIED: `_targets.R`] |
| Shortlist report | Evaluation/reporting | Pipeline | The report summarizes evidence and explicitly does not perform release promotion. [VERIFIED: `10-CONTEXT.md`] |

## Project Constraints (from AGENTS.md)

- Use R as the implementation language and `targets` as the reproducible, incremental orchestration layer. [VERIFIED: `AGENTS.md`]
- Keep xG and Elo separated until the integration/feature-table boundary; Phase 10 may consume point-in-time features but must not create an alternative upstream data path. [VERIFIED: `AGENTS.md`]
- Use canonical team identity/FIFA-code mappings, enforce prior-only temporal features, and never join on display names. [VERIFIED: `AGENTS.md`; VERIFIED: `R/benchmark/contracts.R`]
- Preserve the open-data-first boundary; FotMob is manual-cache-only and must not be scraped or redistributed. [VERIFIED: `AGENTS.md`]
- Keep negative-binomial incumbents intact, use deterministic seeds, and validate model quality through held-out/rolling-origin evidence rather than in-sample significance. [VERIFIED: `AGENTS.md`]
- Put automated tests under `tests/testthat`, run them frequently, and target at least 80% coverage for new core modelling functions. [VERIFIED: `AGENTS.md`]
- Read before editing, preserve unrelated changes, commit planning artifacts, and do not commit without verification. [VERIFIED: `AGENTS.md`]

## Repository and Benchmark Inventory

| Item | Planning consequence |
|------|----------------------|
| Five Phase 9 baselines: `uniform_1x2`, `expanding_1x2`, `elo_goal_nb`, `open_nb_incumbent`, and `production_hybrid_nb`. [VERIFIED: `data/benchmark/phase09/model_registry.csv`] | Every challenger needs paired deltas against all five, not only its registry-designated incumbent. [ASSUMED] |
| Open comparisons use 630 fixtures; the production-rich baseline is only eligible on the exact 609-fixture rich subset. [VERIFIED: `data/benchmark/phase09/panel_fixtures.csv`] | Add a comparison-panel projection independent of a candidate's native panel: 630 for the four open baselines and 609 for `production_hybrid_nb`. [ASSUMED] |
| `benchmark_runner_comparisons()` currently pairs a model only with the applicable incumbent. [VERIFIED: `R/benchmark/runner.R`] | Do not overload its meaning; add `challenger_all_baseline_comparisons()` with explicit candidate/baseline/panel keys. [ASSUMED] |
| The accepted Phase 9 bundle has 6,300 prediction rows, 10,590,300 score rows, 1,420 manifest rows, and 78,120 feature-evidence rows. [VERIFIED: `.planning/phases/09-rolling-tournament-benchmark-harness/09-VERIFICATION.md`] | Import predictions/evidence by parent bundle hash; do not duplicate the 979 MB baseline bundle. [ASSUMED] |
| `goal_training_features_hybrid.csv` lacks `tournament`, while `elo_matches.csv` contains it and shares `match_id`. [VERIFIED: `data/processed/goal_training_features_hybrid.csv`; VERIFIED: `data/processed/elo_matches.csv`] | Build one validated one-to-one `match_id` join before importance weighting and inner-edition assignment. [ASSUMED] |
| Complete pre-2002 assessment-like editions include World Cups 1994/1998 and Euros 1996/2000. [VERIFIED: `data/processed/elo_matches.csv`] | Seed first-fold inner validation with these completed editions rather than inventing an in-sample random split. [ASSUMED] |
| Phase 9's open xG/xGA/xGD/form rows have zero source, value, and active-fit coverage. [VERIFIED: `outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen/feature_coverage.csv`] | Record deeper ablation nodes as `not_activated_zero_coverage`; do not fit or score them. [ASSUMED] |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| R | 4.6.1 locally | Runtime and base optimization/numerics. | Matches the accepted Phase 9 bundle runtime. [VERIFIED: local `R --version`; VERIFIED: Phase 9 `run_manifest.csv`] |
| `glmnet` | 5.0, published 2026-05-04 | Sparse penalized Poisson fits, offsets, case weights, ridge/lasso penalties. | Official documentation supports Poisson families, sparse matrices, offsets, `penalty.factor`, and deterministic externally supplied folds. [CITED: https://cran.r-project.org/package=glmnet; CITED: https://glmnet.stanford.edu/articles/glmnet.html] |
| `Matrix` | 1.7-5 locally | Sparse attack/defence design matrices. | Installed locally and imported by `glmnet`; avoids dense team-by-row matrices. [VERIFIED: local R package inventory; CITED: https://cran.r-project.org/package=glmnet] |
| `stats` | R 4.6.1 | Bounded one-dimensional optimization, Poisson terms, and deterministic utilities. | `optimize()` is sufficient for the one global Dixon-Coles or bivariate parameter required per fold. [VERIFIED: local R runtime; ASSUMED] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `MASS` | 7.3-65 locally | Preserve the incumbent negative-binomial fitter. | Use only for the unchanged full and Elo-only incumbent ablation. [VERIFIED: local R package inventory; VERIFIED: `R/forecast/poisson.R`] |
| `targets` | 1.12.0 locally | Pipeline dependency graph and isolated Phase 10 targets. | Use for registries, candidate execution, reconciliation, and report generation. [VERIFIED: local R package inventory; VERIFIED: `_targets.R`] |
| `testthat` | 3.3.2 locally | Unit, integration, and deterministic replay tests. | Use for every new fitting/state/dependence seam and bundle contract. [VERIFIED: local R package inventory; VERIFIED: `tests/testthat/`] |
| `digest` | 0.6.39 locally | Parent-bundle, registry, settings, mean-model, and output hashes. | Use the existing project hashing convention; do not create a second hashing implementation. [VERIFIED: local R package inventory; VERIFIED: `R/benchmark/contracts.R`] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Nested ridge team fit plus offset-lasso Elo fit | One elastic-net fit | A single `alpha` applies one mixing regime to all coefficients; `penalty.factor` scales penalty strength but does not make team columns ridge and Elo columns lasso. The nested fit enforces D-02 and preserves attribution. [CITED: https://glmnet.stanford.edu/articles/glmnet.html] |
| Custom fixture-varying bivariate-Poisson PMF | `bivpois::bp.mle()` | The package documents a constant three-parameter i.i.d. MLE and PMF; it is suitable as a small-case oracle, not as the production covariate-mean regression required here. [CITED: https://cran.r-project.org/web/packages/bivpois/refman/bivpois.html] |
| Fixed pseudo-exposure dynamic state | Rolling windows or cycle resets | Windows/resets contradict D-08 and create discontinuities; fixed pseudo-exposure lets decayed evidence move continuously toward the global mean. [ASSUMED] |

**Installation:**

Plan 10-02 must capture and hash the official CRAN repository index and `glmnet`
5.0 metadata, inventory `Depends`, `Imports`, and `LinkingTo`, download the
platform-selected source or binary archive without installing it, verify the
archive against the checksum published in official repository metadata, and
compute a SHA-256 over the verified archive. Installation then proceeds only
from that verified local archive into the constrained Phase 10 library without
updating unrelated packages. The preflight must hash the installed package
contents and persist repository-index, package-metadata, dependency-inventory,
archive, and installed-content hashes in the Phase 10 provenance artifact and
every canonical run manifest. [ASSUMED; CITED: https://cran.r-project.org/package=glmnet]

Pin `glmnet == 5.0` in the Phase 10 environment preflight; this repository
currently has neither `renv.lock` nor a package `DESCRIPTION`. [VERIFIED:
repository file inventory; CITED: https://cran.r-project.org/package=glmnet]

## Package Legitimacy Audit

The GSD legitimacy seam supports npm, PyPI, and crates.io but not CRAN, so it cannot issue an automated `OK/SUS/SLOP` verdict for this R phase. Official CRAN and maintainer documentation were therefore used, and installation must remain gated by exact package/version verification. [VERIFIED: `gsd-tools query package-legitimacy` usage response; CITED: https://cran.r-project.org/package=glmnet]

| Package | Registry | Published | Source/maintainer evidence | Verdict | Disposition |
|---------|----------|-----------|----------------------------|---------|-------------|
| `glmnet` | CRAN | 2026-05-04 (v5.0) | CRAN package page and official Stanford vignette. [CITED: https://cran.r-project.org/package=glmnet; CITED: https://glmnet.stanford.edu/articles/glmnet.html] | Manual authoritative audit; automated CRAN gate unavailable | Approved behind official-repository metadata, checksum, dependency-inventory, exact-version, and installed-content-hash preflights |

**Packages removed due to SLOP:** none; no unsupported package is recommended for installation. [VERIFIED: recommended installation list above]  
**Packages flagged as suspicious:** none, but the planner must include a human/environment checkpoint if CRAN installation or version verification fails. [ASSUMED]

## Architecture Patterns

### System Architecture Diagram

```text
Phase 9 frozen registries + accepted bundle (hash-verified)
                         |
                         v
Phase 10 registry overlay + tuning-edition/grid registries
                         |
                  outer tournament fold
                         |
              prior completed tournaments only
                         |
        +----------------+----------------+
        |                |                |
        v                v                v
 penalized means    dynamic state    incumbent ablation
        |                |                |
        +-------> shared adapter/schema <+
        |                                 |
        +--> independent / DC / BP PMF ---+
                         |
                 G=40 normalization
                         |
        shared Phase 9 markets + scorer + evidence
                         |
              explicit comparison-panel branch
                  /                     \
       630 open fixtures           609 rich fixtures
       four open baselines        production_hybrid_nb
                  \                     /
                   paired fold evidence
                         |
        best-score + simplest-NI + dependence representative
                         |
              Phase 12 handoff (no promotion)
```

This flow keeps model fitting upstream of the immutable score/evaluation services and makes the 609-fixture branch an explicit comparison denominator rather than a native candidate panel. [ASSUMED]

### Recommended Project Structure

```text
data/benchmark/phase10/
├── model_registry.csv
├── feature_contract.csv
├── tuning_editions.csv
├── tuning_grid.csv
├── ablation_registry.csv
├── selection_protocol.json
└── storage_preflight.csv
R/forecast/
├── penalized_poisson.R
├── dynamic_goal_ability.R
└── score_dependence.R
R/benchmark/
├── challenger_protocol.R
├── challengers.R
└── challenger_runner.R
R/evaluation/
└── challenger_selection.R
tests/testthat/
├── helper_statistical_challengers.R
├── test_statistical_penalized_poisson_design.R
├── test_statistical_penalized_poisson_tuning.R
├── test_statistical_dynamic_state.R
├── test_statistical_dynamic_tuning.R
├── test_statistical_dependence_pmf.R
├── test_statistical_dependence_parameters.R
├── test_statistical_registry_protocol.R
├── test_statistical_storage_preflight.R
├── test_statistical_ablation_hierarchy.R
├── test_statistical_adapter_dispatch.R
├── test_statistical_ablation_selection.R
├── test_statistical_selection.R
├── test_statistical_bundle.R
├── test_statistical_targets.R
├── phase10_core_coverage.R
└── phase10_coverage_exceptions.csv
outputs/benchmarks/rolling_tournaments/
└── phase10-statistical-challengers/
```

These are new Phase 10 paths; the plan must not edit the frozen Phase 9 registries or accepted bundle. [ASSUMED]

### Pattern 1: Immutable Overlay Registry

Every Phase 10 registry row should carry `phase09_parent_registry_sha256`, `phase09_parent_bundle_sha256`, `candidate_id`, `adapter_id`, `native_panel_id`, `mean_model_id`, `dependence_id`, `tuning_protocol_id`, `feature_set_id`, and `settings_hash`. Dispatch `adapter_id` through a hard-coded allowlist; never evaluate registry text as R code. [ASSUMED]

Recommended candidate registry:

| Candidate ID | Mean/dependence | Native panel | Purpose |
|--------------|-----------------|--------------|---------|
| `poisson_team_ridge` | Team attack/defence + venue, independent | open 630 | Minimal nested parent. [ASSUMED] |
| `poisson_team_ridge_elo` | Parent + selected Elo offset term, independent | open 630 | Added-covariate attribution. [ASSUMED] |
| `dynamic_goal_ability` | Dynamic attack/defence, independent | open 630 | Dynamic standalone. [ASSUMED] |
| `dynamic_goal_ability_elo` | Dynamic state + Elo coefficient | open 630 | Dynamic incremental-Elo test. [ASSUMED] |
| `poisson_team_ridge_elo_dc` | Exact augmented means + Dixon-Coles | open 630 | Low-score dependence sibling. [ASSUMED] |
| `poisson_team_ridge_elo_bivpois` | Exact augmented means + bivariate Poisson | open 630 | Shared-component dependence sibling. [ASSUMED] |
| `open_nb_elo_only_ablation` | Existing two-sided NB formula with xG/form block removed | open 630 | Level-one incumbent simplification. [ASSUMED] |

### Pattern 2: Nested Penalized Poisson

Create two scoring-team rows per match with response `goals`, categorical `attack_team`, categorical `defence_opponent`, `is_home_non_neutral`, and a signed point-in-time `elo_diff`. Build sparse full attack and defence indicator columns; leave the intercept and venue unpenalized and apply ridge to all team columns. [CITED: https://glmnet.stanford.edu/articles/glmnet.html; ASSUMED]

Fit the augmented model in a second stage using the minimal model's `log(mu)` as a fixed offset, `intercept = FALSE`, and lasso on the added Elo coefficient. A zero Elo coefficient then exactly recovers the minimal mean, while team identities cannot be removed by the sparse-selection stage. [CITED: https://glmnet.stanford.edu/articles/glmnet.html; ASSUMED]

For each outer tournament, select the team ridge penalty first and the Elo penalty second by equal-tournament mean updating-track RPS over completed earlier tournaments. Use deterministic largest-penalty tie-breaking, then freeze both values for the outer frozen and updating tracks. [ASSUMED]

Include every assessment identity in the design levels without using its outcomes. A team with no prior rows has all-zero team columns and therefore receives the global log-scale effect; manifests must record attack/defence prior counts, shrinkage weight, and cold-start status. [ASSUMED]

### Pattern 3: Dynamic State with Genuine Inactivity Reversion

Maintain decayed sufficient statistics `GF`, `GA`, and exposure `W` by team. At each new date, decay accumulated evidence by `exp(-log(2) * days / 730)`; combine it with a fixed global pseudo-exposure `k` that does not decay. This makes attack and defence effects converge to zero on the log scale as inactivity grows. [VERIFIED: Phase 9 half-life setting in `data/benchmark/phase09/model_registry.csv`; ASSUMED]

Use the following declared parameterization:

```r
# Recommended project parameterization; literature-informed, not copied verbatim. [ASSUMED]
base <- decayed_total_goals / (2 * decayed_match_weight)
attack_i  <- log(((GF_i + k * base) / (W_i + k)) / base)
defence_i <- -log(((GA_i + k * base) / (W_i + k)) / base)

log_mu_home <- log(base) + home_adv + attack_home - defence_away
log_mu_away <- log(base) - home_adv + attack_away - defence_home
```

Predict every fixture on a date from one pre-date snapshot, aggregate completed outcomes for that date, then update once. The Elo sibling adds a single signed point-in-time Elo term to the log mean; estimate and freeze that coefficient from prior evidence. [CITED: https://doi.org/10.1111/1467-9884.00243; ASSUMED]

Replay history once to materialize boundary snapshots rather than replaying all 49,520 historical matches independently for every benchmark boundary. [VERIFIED: local training-row count; ASSUMED]

### Pattern 4: Shared Means, Alternative Dependence

Persist a `mean_prediction_hash` for `(outer_fold, track, boundary, fixture_id, mu_home, mu_away)`. Independent, Dixon-Coles, and bivariate-Poisson siblings must have identical hashes before score-grid generation. [ASSUMED]

For Dixon-Coles, multiply only the 0-0, 0-1, 1-0, and 1-1 independent Poisson cells by the standard low-score adjustment and estimate one bounded `rho` by prior-data likelihood. Restrict the search interval so every adjustment remains positive, then normalize the truncated G=40 grid through the common score-distribution contract. [CITED: https://doi.org/10.1111/1467-9876.00065; ASSUMED]

With `lambda = mu_home` and `mu = mu_away`, use `tau(0,0) = 1 - lambda * mu * rho`, `tau(0,1) = 1 + lambda * rho`, `tau(1,0) = 1 + mu * rho`, `tau(1,1) = 1 - rho`, and `tau = 1` otherwise. Compute the feasible `rho` interval from all prior-fit means with an epsilon interior rather than relying on optimizer failures. [CITED: https://doi.org/10.1111/1467-9876.00065; ASSUMED]

For bivariate Poisson, use `X=A+C`, `Y=B+C`. To preserve each fixture's fixed penalized-Poisson marginal means while retaining one fold-global parameter, use `kappa_i = q * min(mu_home_i, mu_away_i)`, `lambda1_i = mu_home_i - kappa_i`, and `lambda2_i = mu_away_i - kappa_i`, with `0 <= q < 1`. Estimate one `q` from prior data and freeze it for both tracks. This fixture scaling is a project adaptation and must be predeclared in the registry. [CITED: https://doi.org/10.1111/1467-9884.00366; ASSUMED]

Implement the PMF with `lgamma()` and log-sum-exp. Validate it against hand-computable cases and, if available in a developer environment, `bivpois::dbp()` as a test-only oracle; do not add `bivpois` to the production dependency set. [CITED: https://cran.r-project.org/web/packages/bivpois/refman/bivpois.html; ASSUMED]

### Pattern 5: Hierarchical Ablation and Shortlist

First compare the unchanged `open_nb_incumbent` against `open_nb_elo_only_ablation` using the same NB fitter, weights, panel, boundaries, and scorer. This is not the Phase 9 `elo_goal_nb`, whose long-format coefficient structure is different. [VERIFIED: `R/forecast/poisson.R`; VERIFIED: `R/benchmark/baselines.R`]

Register attack-xG, defence-xG, xGD, and form child nodes but mark them `not_activated_zero_coverage`; retain zero-coded columns in the full incumbent's evidence with separate `source_present = FALSE`, `value_present = FALSE`, `imputed = TRUE`, and `active_fit = FALSE` fields. [VERIFIED: Phase 9 feature-evidence schema; ASSUMED]

Produce three non-exclusive shortlist slots: best tournament-weighted proper-score candidate, simplest practically non-inferior candidate, and dependence representative if distinct. The output is evidence for Phase 12 and must contain no `promote`, `release`, or World Cup 2026 decision field. [VERIFIED: `10-CONTEXT.md`; ASSUMED]

### Anti-Patterns to Avoid

- **Editing Phase 9 registries or bundle:** this invalidates their checked hashes and destroys the frozen comparison parent. Use a Phase 10 overlay. [VERIFIED: Phase 9 verification protocol]
- **Random CV or assessed-tournament tuning:** it violates D-03 and leaks future tournament evidence. Use completed-edition inner folds only. [VERIFIED: `10-CONTEXT.md`]
- **One elastic-net fit for mixed ridge/lasso semantics:** `penalty.factor` changes relative penalty magnitude, not coefficient-specific `alpha`. Use nested fits. [CITED: https://glmnet.stanford.edu/articles/glmnet.html]
- **Decay numerator and denominator together without a prior:** their ratio does not revert to the global mean. Keep the pseudo-exposure fixed. [ASSUMED]
- **Sequential same-day updates:** row order would affect later fixtures on the same date. Predict a date batch before updating. [VERIFIED: `10-CONTEXT.md`]
- **Different mean fits for dependence candidates:** this confounds mean quality and dependence. Assert the shared mean hash. [VERIFIED: `10-CONTEXT.md`]
- **Treating zero-coded xG/form as observed zeros:** this misstates provenance and predictive value. Keep evidence dimensions separate. [VERIFIED: Phase 9 feature coverage]
- **Using p-values to choose the ablation:** D-15 requires out-of-sample practical non-inferiority and veto checks. [VERIFIED: `10-CONTEXT.md`]
- **Calling `evaluate_promotion()`:** Phase 10 may report gate-like diagnostics but cannot issue Phase 12's final decision. [VERIFIED: `10-CONTEXT.md`; VERIFIED: `R/evaluation/promotion.R`]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Penalized Poisson optimization | Custom coordinate descent | `glmnet` 5.0 | It already handles sparse matrices, Poisson likelihood, offsets, weights, and penalty paths. [CITED: https://glmnet.stanford.edu/articles/glmnet.html] |
| Sparse model storage | Dense team dummy matrices | `Matrix` sparse matrices | Team attack/defence indicators are structurally sparse. [VERIFIED: local `Matrix`; ASSUMED] |
| Outer benchmark scoring | Candidate-specific Brier/RPS/log-loss code | Existing Phase 9 scorer | Metric and tournament-weighting semantics are frozen. [VERIFIED: `R/evaluation/benchmark_scores.R`] |
| Market probabilities | Separate 1X2/BTTS/total formulas per candidate | Existing joint-grid market derivation | One normalized G=40 distribution prevents cross-market inconsistency. [VERIFIED: `R/benchmark/contracts.R`] |
| Cryptographic provenance | Custom checksum algorithm | Existing SHA-256/digest helpers | Parent and output identity must use the accepted contract. [VERIFIED: `R/benchmark/contracts.R`] |
| Bivariate-Poisson regression framework | General multivariate optimizer/package wrapper | One bounded scalar search around fixed fixture means | The locked design needs only one prior-fit global dependence parameter. [VERIFIED: `10-CONTEXT.md`; ASSUMED] |

**Key insight:** Hand-written code is warranted only for the small state/dependence transforms unique to the locked design; fitting, scoring, hashing, schemas, and orchestration should stay on established libraries and Phase 9 services. [ASSUMED]

## Common Pitfalls

### Pitfall 1: Inner Validation Leaks the Outer Tournament
**What goes wrong:** A penalty or dependence parameter improves because assessed results entered tuning. [ASSUMED]  
**Why it happens:** Generic cross-validation ignores tournament chronology. [CITED: https://glmnet.stanford.edu/articles/glmnet.html; ASSUMED]  
**How to avoid:** Materialize an `outer_tournament -> eligible_inner_tournaments` registry and hash the eligible match IDs before fitting. [ASSUMED]  
**Warning signs:** Frozen/updating tracks have different selected penalties, or an inner edition ends on/after the outer start date. [ASSUMED]

### Pitfall 2: Cold-Start Teams Become NA or Silently Disappear
**What goes wrong:** A design level absent from training cannot be predicted or is dropped. [ASSUMED]  
**Why it happens:** Training-only factor levels or lasso selection erase sparse identities. [ASSUMED]  
**How to avoid:** Freeze assessment identities as zero-valued sparse columns and let ridge/global fallback handle no-history cases. [ASSUMED]  
**Warning signs:** Fixture loss, `new factor levels`, missing coefficients, or fewer than 630 candidate predictions. [ASSUMED]

### Pitfall 3: Tournament Labels Are Missing from Goal Training Features
**What goes wrong:** Importance weights or inner folds default to generic treatment. [ASSUMED]  
**Why it happens:** The goal feature table has no `tournament` column. [VERIFIED: `data/processed/goal_training_features_hybrid.csv`]  
**How to avoid:** Assert a one-to-one `match_id` join with `elo_matches.csv` and fail on duplicates/unmatched rows. [ASSUMED]  
**Warning signs:** All importance multipliers equal 1 or inner editions are empty. [ASSUMED]

### Pitfall 4: Bivariate Parameters Violate Marginal Means
**What goes wrong:** Adding shared intensity raises both means and confounds D-09. [CITED: https://doi.org/10.1111/1467-9884.00366]  
**Why it happens:** Treating penalized means as independent components instead of final marginals. [ASSUMED]  
**How to avoid:** Subtract `kappa_i` from both independent components and assert recovered marginals. [ASSUMED]  
**Warning signs:** Expected goals differ between independent and dependence siblings. [ASSUMED]

### Pitfall 5: Truncated Grids Do Not Sum to One
**What goes wrong:** G=40 tail truncation or invalid Dixon-Coles cells changes market totals. [ASSUMED]  
**Why it happens:** PMFs are exponentiated directly or not renormalized. [ASSUMED]  
**How to avoid:** Use log-sum-exp, reject nonfinite/negative cells, normalize once, and run the existing distribution validator. [VERIFIED: `R/benchmark/contracts.R`; ASSUMED]  
**Warning signs:** Probability sums outside tolerance or derived markets disagree. [ASSUMED]

### Pitfall 6: Pairing Uses Different Fixture Denominators
**What goes wrong:** Candidate deltas against `production_hybrid_nb` compare 630 rows with 609 rows. [VERIFIED: Phase 9 panel contract]  
**Why it happens:** Existing routing assumes the candidate's native panel. [VERIFIED: `R/benchmark/runner.R`]  
**How to avoid:** Project both members onto the explicit comparison panel before pairing and assert equal fixture IDs. [ASSUMED]  
**Warning signs:** Nonzero unmatched rows or a comparison denominator other than 630/609. [ASSUMED]

### Pitfall 7: Disk Amplification During Atomic Publication
**What goes wrong:** Score-grid staging exhausts disk before reconciliation. [ASSUMED]  
**Why it happens:** Phase 9's score table is 924 MB and atomic publication temporarily holds staged and installed copies. [VERIFIED: local bundle sizes]  
**How to avoid:** Run Plan 10-09 Task 2's deterministic 2,118,060-row pilot, enforce its measured projection formula and frozen `minimum_free_bytes`, write candidate partitions, and remove staging only after accepted publication. [ASSUMED]  
**Warning signs:** Free space below threshold or partial staging directories after failure. [ASSUMED]

## Code Examples

### Sparse Nested Fit

```r
# API pattern: official glmnet vignette; column policy is Phase 10 design. [CITED: https://glmnet.stanford.edu/articles/glmnet.html; ASSUMED]
fit_team <- glmnet::glmnet(
  x = x_team,
  y = goals,
  family = "poisson",
  alpha = 0,
  lambda = selected_team_lambda,
  weights = observation_weight,
  penalty.factor = penalty_factor # one entry per column: team=1, venue=0
)

minimal_log_mu <- as.numeric(predict(fit_team, newx = x_team, type = "link"))
fit_elo <- glmnet::glmnet(
  x = x_elo,
  y = goals,
  family = "poisson",
  alpha = 1,
  lambda = selected_elo_lambda,
  offset = minimal_log_mu,
  intercept = FALSE,
  weights = observation_weight
)
```

### Same-Date-Safe Dynamic Update

```r
# Recommended state-machine shape. [ASSUMED]
for (match_date in sort(unique(history$match_date))) {
  state <- decay_state_to(state, match_date, half_life_days = 730)
  day_rows <- history[history$match_date == match_date, ]
  predictions <- predict_from_snapshot(state, day_rows)
  batch_delta <- aggregate_completed_goals(day_rows, observation_weights)
  state <- apply_batch_delta(state, batch_delta)
}
```

### Stable Bivariate-Poisson Cell

```r
# Formula follows the shared-component definition; log-sum-exp is the project implementation. [CITED: https://cran.r-project.org/web/packages/bivpois/refman/bivpois.html; ASSUMED]
log_bp_cell <- function(x, y, lambda1, lambda2, kappa) {
  z <- 0:min(x, y)
  terms <- (x - z) * log(lambda1) - lgamma(x - z + 1) +
    (y - z) * log(lambda2) - lgamma(y - z + 1) +
    z * log(kappa) - lgamma(z + 1)
  -(lambda1 + lambda2 + kappa) + log_sum_exp(terms)
}
```

Production code must branch exactly at zero intensities to avoid `0 * log(0)` and must pass limiting-case tests at `q = 0`. [ASSUMED]

## Selection Protocol

Predeclare the following margins in `selection_protocol.json`; they are planning defaults and must not be tuned after seeing Phase 10 assessment outcomes. [ASSUMED]

| Decision | Primary rule | Vetoes / tie-break |
|----------|--------------|--------------------|
| Dependence meaningful gain | Equal-tournament updating RPS delta versus independent `<= -0.001`. [ASSUMED] | No relative Brier/log-loss regression over 1%, calibration regression over 0.01, or worst-fold regression over 0.015; prefer Dixon-Coles when absolute RPS difference is `<= 0.0005`. [ASSUMED] |
| Simpler incumbent non-inferiority | Elo-only RPS delta versus full incumbent `<= +0.001`. [ASSUMED] | Same supporting-score/calibration/fold vetoes; no p-value rule. [VERIFIED: D-15; ASSUMED] |
| Best-score shortlist slot | Lowest equal-tournament updating RPS among valid candidates. [ASSUMED] | Report frozen-track and supporting metrics; do not promote. [VERIFIED: D-16; ASSUMED] |

The exact numerical margins are discretion choices and should be treated as locked protocol inputs once planning begins. [ASSUMED]

## State of the Art

| Earlier approach | Current implementation-relevant approach | Impact for Phase 10 |
|------------------|------------------------------------------|---------------------|
| Independent Poisson scorelines | Dixon-Coles low-score correction and bivariate-Poisson shared-component dependence. [CITED: https://doi.org/10.1111/1467-9876.00065; CITED: https://doi.org/10.1111/1467-9884.00366] | Compare dependence with identical mean predictions and one fold-global prior-fit parameter. [ASSUMED] |
| Static unregularized team strengths | Regularized Poisson team effects with additional match covariates. [CITED: https://doi.org/10.1515/jqas-2014-0051] | Sparse identities require shrinkage and chronology-safe penalty selection. [ASSUMED] |
| Fixed-window form | Dynamic strengths with temporal evolution/discounting. [CITED: https://doi.org/10.1111/1467-9884.00243; CITED: https://doi.org/10.1111/1467-9884.00308] | Use deterministic all-history decay plus explicit mean reversion. [ASSUMED] |
| Constant bivariate score parameters | Covariate and time-varying bivariate football models exist in the literature. [CITED: https://doi.org/10.1111/rssa.12042; CITED: https://doi.org/10.1515/jqas-2017-0067] | The locked phase intentionally uses a simpler global dependence parameter for interpretability and stable outer-fold estimation. [VERIFIED: D-10] |

**Deprecated/outdated for this phase:** random train/test splits, tournament-cycle resets, model-specific market scoring, uncontrolled feature-subset search, and significance-driven simplification are incompatible with locked decisions or inherited benchmark contracts. [VERIFIED: `10-CONTEXT.md`; VERIFIED: Phase 9 benchmark contract]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Two-stage ridge team means plus offset-lasso Elo is the best operational interpretation of grouped/ridge team shrinkage plus sparse added-covariate selection. | Architecture Pattern 2 | Another identifiability scheme could be preferred; candidate nesting and attribution must still hold. |
| A2 | Equal-tournament updating RPS with largest-penalty tie-breaking is the inner tuning objective. | Architecture Pattern 2 | A different predeclared track/objective changes selected hyperparameters. |
| A3 | Fixed pseudo-exposure with a 730-day evidence half-life is the chosen dynamic mean-reversion form. | Architecture Pattern 3 | Different shrinkage strength changes dynamic forecasts; it must be tuned only on prior editions. |
| A4 | `q * min(mu_home, mu_away)` is the bivariate shared-intensity parameterization. | Architecture Pattern 4 | It is a project adaptation, not the only valid one-global-parameter construction. |
| A5 | The candidate IDs and seven-model registry are sufficient to satisfy D-01 through D-16 without model-zoo expansion. | Overlay Registry | Planner may rename IDs, but adding candidates increases runtime and weakens controlled attribution. |
| A6 | RPS margins of 0.001, tie margin 0.0005, and existing supporting veto scales are practically appropriate. | Selection Protocol | Conclusions may change near thresholds; values must be locked before assessment. |
| A7 | Plan 10-09 Task 2's measured projection formula defines the publication preflight threshold. | Pitfall 7 | The deterministic 2,118,060-row pilot measures `B` and freezes `minimum_free_bytes = ceiling(3 * (7 * B + max(1 GiB, ceiling(0.25 * 7 * B))) * 1.10)`; no fixed-GiB estimate is accepted. |
| A8 | Phase 9 baselines can be consumed directly by verified durable reference rather than copied into the Phase 10 bundle. | Repository Inventory | Downstream report code may require a lightweight reference manifest or views. |

## Open Questions (RESOLVED)

1. **Frozen hyperparameter grids:** Plan 10-09 freezes and canonically validates team ridge lambda at
   `10^seq(-4, 2, by = 0.5)`, Elo lasso lambda at
   `10^seq(-5, 1, by = 0.5)`, and dynamic pseudo-exposure at
   `c(2, 4, 8, 16, 32)` with the inherited 730-day half-life. The pre-2002
   diagnostic confirms finite numerical reach only and cannot alter these
   grids. Selection remains prior-edition-only and is frozen per outer fold for
   both tracks. [VERIFIED: D-03; ASSUMED]

2. **Bivariate-Poisson implementation:** production uses the custom
   fixture-varying PMF in `R/forecast/score_dependence.R`, with analytical
   limiting cases and deterministic checked-in oracle fixtures. `bivpois` is
   neither installed nor declared as a runtime or test dependency. [ASSUMED;
   CITED: https://cran.r-project.org/web/packages/bivpois/refman/bivpois.html]

3. **Storage projection:** Plan 10-09 owns the protocol and generates a deterministic,
   format-identical, conservatively low-compressibility pilot independent of any
   fitted candidate. It contains exactly 630 fixtures x 2 tracks = 1,260
   distributions and 1,260 x 41 x 41 = 2,118,060 G=40 score rows, with seeded
   high-entropy IDs and normalized probabilities in the production CSV schema.
   If `B` is the measured compressed pilot bytes, then
   `score_projection = 7 * B`,
   `one_bundle_projection = score_projection + max(1 GiB, ceiling(0.25 * score_projection))`,
   and
   `minimum_free_bytes = ceiling(3 * one_bundle_projection * 1.10)`.
   The factor 3 covers normal staging, reversed-order staging, and the installed
   or rollback bundle; the final 10% is filesystem headroom. The measured values
   and formula inputs are frozen in `storage_preflight.csv` before Plan 10-03.
   [ASSUMED]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| R / Rscript | All work | ✓ | 4.6.1 | None needed. [VERIFIED: local executable probe] |
| `glmnet` | STAT-01 and dependence mean model | ✗ | Required 5.0 | Install from CRAN; blocking if exact version cannot be verified. [VERIFIED: local package probe; CITED: https://cran.r-project.org/package=glmnet] |
| `Matrix` | Sparse design | ✓ | 1.7-5 | None needed. [VERIFIED: local package probe] |
| `MASS` | STAT-04 incumbent ablation | ✓ | 7.3-65 | None needed. [VERIFIED: local package probe] |
| `targets` | Pipeline | ✓ | 1.12.0 | Direct script smoke tests only; full phase still requires targets. [VERIFIED: local package probe] |
| `testthat` | Validation | ✓ | 3.3.2 | None needed. [VERIFIED: local package probe] |
| `digest` | Provenance | ✓ | 0.6.39 | None needed. [VERIFIED: local package probe] |
| C/C++/Fortran toolchain | `glmnet` installation | ✓ | Apple clang 17.0.0, GNU Make 3.81, GNU Fortran 15.2.0 | CRAN binary if available. [VERIFIED: local executable probe] |
| Free disk | G=40 candidate artifacts/staging | ✓ but tight | 17 GiB free during research | Partitioned generation and baseline references. [VERIFIED: local filesystem audit; ASSUMED] |

**Missing dependencies with no fallback:** `glmnet` 5.0 is required before implementation tests and benchmark execution. [CITED: https://cran.r-project.org/package=glmnet]  
**Missing dependencies with fallback:** `bivpois` is intentionally not required; checked oracle fixtures replace a runtime dependency. [ASSUMED]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `testthat` 3.3.2. [VERIFIED: local package probe] |
| Config file | `tests/testthat.R` and existing `tests/testthat/helper_benchmark.R`; add `tests/testthat/helper_statistical_challengers.R`. [VERIFIED: repository test inventory; ASSUMED] |
| Quick regression | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_benchmark_baselines.R", reporter="summary", stop_on_failure=TRUE, stop_on_warning=TRUE)'` (75 expectations passed in 7.39s during research). [VERIFIED: local test run] |
| Full suite | `Rscript --vanilla -e 'testthat::test_dir("tests/testthat", reporter="summary", stop_on_failure=TRUE, stop_on_warning=TRUE)'`. [VERIFIED: existing project convention] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| STAT-01 | Sparse identified design, centering, and cold-start behavior. [ASSUMED] | Unit | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_statistical_penalized_poisson_design.R", reporter="summary", stop_on_failure=TRUE, stop_on_warning=TRUE)'` | ❌ Wave 0 (10-01) |
| STAT-01 | Nested Elo boundary, exact prior-only tuning, poisoning, and all-baseline pairing. [ASSUMED] | Unit + integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_statistical_penalized_poisson_tuning.R", reporter="summary", stop_on_failure=TRUE, stop_on_warning=TRUE)'` | ❌ Wave 0 (10-01) |
| STAT-02 | Date-batch state, order invariance, decay, and continuous reversion. [ASSUMED] | Unit + replay | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_statistical_dynamic_state.R", reporter="summary", stop_on_failure=TRUE, stop_on_warning=TRUE)'` | ❌ Wave 0 (10-10) |
| STAT-02 | Nested Elo variant and prior-only dynamic tuning. [ASSUMED] | Unit + integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_statistical_dynamic_tuning.R", reporter="summary", stop_on_failure=TRUE, stop_on_warning=TRUE)'` | ❌ Wave 0 (10-10) |
| STAT-03 | DC/BP PMF oracles, marginals, shared means, and G=40. [ASSUMED] | Unit | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_statistical_dependence_pmf.R", reporter="summary", stop_on_failure=TRUE, stop_on_warning=TRUE)'` | ❌ Wave 0 (10-10) |
| STAT-03 | Prior-fit fold-global dependence parameters and poisoning. [ASSUMED] | Unit + integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_statistical_dependence_parameters.R", reporter="summary", stop_on_failure=TRUE, stop_on_warning=TRUE)'` | ❌ Wave 0 (10-10) |
| STAT-01..04 | Exact parent/hash/grid/chronology validation and executed pre-2002 diagnostic. [ASSUMED] | Registry protocol | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_statistical_registry_protocol.R", reporter="summary", stop_on_failure=TRUE, stop_on_warning=TRUE)'` | ❌ Plan 10-09 |
| STAT-03..04 | Exact ablation/selection/no-promotion/storage validation. [ASSUMED] | Registry protocol | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_statistical_storage_preflight.R", reporter="summary", stop_on_failure=TRUE, stop_on_warning=TRUE)'` | ❌ Plan 10-09 |
| STAT-04 | Hierarchy and inactive-feature provenance. [ASSUMED] | Unit | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_statistical_ablation_hierarchy.R", reporter="summary", stop_on_failure=TRUE, stop_on_warning=TRUE)'` | ❌ Wave 0 (10-11) |
| STAT-01..04 | Exact seven-candidate common adapter dispatch. [ASSUMED] | Integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_statistical_adapter_dispatch.R", reporter="summary", stop_on_failure=TRUE, stop_on_warning=TRUE)'` | ❌ Wave 0 (10-11) |
| STAT-04 | Practical non-inferiority and no significance rule. [ASSUMED] | Unit | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_statistical_ablation_selection.R", reporter="summary", stop_on_failure=TRUE, stop_on_warning=TRUE)'` | ❌ Wave 0 (10-11) |
| STAT-01..04 | Exact all-baseline evidence and research shortlist. [ASSUMED] | Integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_statistical_selection.R", reporter="summary", stop_on_failure=TRUE, stop_on_warning=TRUE)'` | ❌ Wave 0 (10-11) |
| STAT-01..04 | Parent-complete deterministic bundle and no-promotion/WC2026 boundary. [ASSUMED] | End-to-end contract | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_statistical_bundle.R", reporter="summary", stop_on_failure=TRUE, stop_on_warning=TRUE)'` | ❌ Wave 0 (10-11) |
| STAT-01..04 | Exact target manifest and forbidden ancestry. [ASSUMED] | Pipeline structure | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_statistical_targets.R", reporter="summary", stop_on_failure=TRUE, stop_on_warning=TRUE)'` | ❌ Wave 0 (10-11) |

### Required Assertions Beyond Happy Paths

- Shuffle same-day training rows and require byte-identical dynamic state/predictions. [ASSUMED]
- Poison each assessed tournament's outcomes and require its frozen predictions, selected hyperparameters, and dependence parameter to remain unchanged. [ASSUMED]
- Compare independent/DC/BP `mean_prediction_hash` values exactly. [ASSUMED]
- Require candidate-baseline fixture-ID equality before paired deltas: 630 for four open baselines and 609 for `production_hybrid_nb`. [VERIFIED: Phase 9 panel contract; ASSUMED]
- Run twice in fresh R sessions and compare registry, manifest, prediction, score, evidence, comparison, and shortlist hashes. [VERIFIED: Phase 9 reproducibility pattern; ASSUMED]
- Statically and dynamically assert that Phase 10 runner code does not call `evaluate_promotion()` or read World Cup 2026 outcomes. [VERIFIED: phase boundary; ASSUMED]
- Validate every distribution for finite nonnegative cells, unit mass, complete 0:40 support, and common market derivation. [VERIFIED: `R/benchmark/contracts.R`]

### Sampling Rate

- **Per task commit:** Run the owning new test file plus `test_benchmark_baselines.R` (~7.4 seconds observed). [VERIFIED: local test run; ASSUMED]
- **Per wave merge:** Run only the task-scoped Phase 10 tests whose owning production tasks are complete, plus the applicable existing benchmark contracts, cutoffs, scoring, pipeline, and seal tests named in `10-VALIDATION.md`. Do not run still-RED sibling tests from later tasks. [ASSUMED]
- **Phase gate:** Run the full test suite, a fresh-process deterministic bundle validation, exact panel/count reconciliation, and Phase 9 parent-hash verification before `$gsd-verify-work`. [ASSUMED]

### Wave 0 Gaps

- [ ] `tests/testthat/helper_statistical_challengers.R` — synthetic matches, fixed sparse levels, PMF oracle fixtures, and fold helpers. [ASSUMED]
- [ ] Plan 10-01: `helper_statistical_challengers.R`, penalized design, and penalized tuning task-scoped files. [ASSUMED]
- [ ] Plan 10-10: dynamic state/tuning and dependence PMF/parameter task-scoped files. [ASSUMED]
- [ ] Plan 10-11: ablation hierarchy, adapter dispatch, ablation selection, selection, bundle, targets, coverage runner, and exception registry. [ASSUMED]
- [ ] Plan 10-09: registry-protocol and storage-preflight mutation suites owned with `challenger_protocol.R` and all seven Phase 10 registry/storage artifacts. [ASSUMED]
- [ ] Install and verify `glmnet` 5.0, then record it in targets package declarations and manifests. [CITED: https://cran.r-project.org/package=glmnet; ASSUMED]
- [ ] Plan 10-09 Task 2 generates the deterministic, format-identical 2,118,060-row pilot and freezes the measured `B`, `score_projection = 7 * B`, `one_bundle_projection = score_projection + max(1 GiB, ceiling(0.25 * score_projection))`, and `minimum_free_bytes = ceiling(3 * one_bundle_projection * 1.10)` before the full run. [ASSUMED]

## Security Domain

`security_enforcement` is absent from `.planning/config.json`, so security research remains enabled. [VERIFIED: `.planning/config.json`]

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | No | Local analytical pipeline has no authentication boundary in Phase 10. [VERIFIED: repository architecture] |
| V3 Session Management | No | No sessions or interactive service are introduced. [VERIFIED: phase scope] |
| V4 Access Control | No external authorization boundary | Restrict reads/writes to declared project-relative registry, bundle, and output roots. [VERIFIED: existing benchmark path validators; ASSUMED] |
| V5 Input Validation | Yes | Existing schema validators plus allowlisted adapter IDs, exact columns/types, point-in-time dates, identity keys, parameter bounds, and probability checks. [VERIFIED: `R/benchmark/contracts.R`; ASSUMED] |
| V6 Cryptography | Yes for integrity | Reuse SHA-256/digest provenance; never invent cryptography. [VERIFIED: existing benchmark hash contract] |

### Known Threat Patterns for the R Benchmark Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Tampered Phase 9 bundle or Phase 10 registry | Tampering | Verify parent and settings SHA-256 before execution and before publication. [VERIFIED: Phase 9 seal pattern] |
| Future outcomes entering tuning/state | Tampering / information disclosure | Date-boundary assertions, eligible-ID hashes, assessed-outcome poisoning tests, and no WC2026 reads. [ASSUMED] |
| Registry adapter/formula injection | Elevation of privilege | Dispatch only hard-coded adapter IDs; treat formula/settings fields as validated data, never `eval(parse())`. [ASSUMED] |
| Malformed intensities or dependence bounds | Tampering / denial of service | Reject nonfinite means, invalid `rho/q`, negative PMF cells, and non-unit mass before scoring. [ASSUMED] |
| G=40 grid memory/disk exhaustion | Denial of service | Chunked candidate partitions, free-space preflight, bounded workers, and atomic reconciliation. [ASSUMED] |
| Untraceable shortlist claims | Repudiation | Emit per-fold paired evidence, protocol version/hash, active/dropped features, convergence/fallback, and source hashes. [VERIFIED: inherited manifest/evidence pattern; ASSUMED] |

No network access is needed during benchmark execution; network activity is limited to the separately approved dependency-install step. [ASSUMED]

## Sources

### Primary (HIGH confidence project evidence)

- `.planning/phases/10-statistical-goal-model-challengers/10-CONTEXT.md` — locked D-01 through D-16 and phase boundary. [VERIFIED: local file]
- `.planning/phases/09-rolling-tournament-benchmark-harness/09-VERIFICATION.md` — accepted panels, tracks, counts, provenance, and bundle contract. [VERIFIED: local file]
- `data/benchmark/phase09/` and `outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen/` — registries, coverage, manifests, and durable baseline evidence. [VERIFIED: local files]
- `R/benchmark/`, `R/evaluation/`, and `R/forecast/` — adapter, runner, scorer, promotion, incumbent, and goal-ability seams. [VERIFIED: local code inspection]
- `tests/testthat/` — existing benchmark contract and regression patterns. [VERIFIED: local code and test run]

### Primary Literature and Official Documentation (MEDIUM confidence via research seam)

- [Official glmnet CRAN page](https://cran.r-project.org/package=glmnet) — current version and system requirements. [CITED: https://cran.r-project.org/package=glmnet]
- [Official glmnet vignette](https://glmnet.stanford.edu/articles/glmnet.html) — Poisson, sparse matrices, offsets, weights, folds, and penalty factors. [CITED: https://glmnet.stanford.edu/articles/glmnet.html]
- [Dixon & Coles (1997)](https://doi.org/10.1111/1467-9876.00065) — low-score dependence correction. [CITED: https://doi.org/10.1111/1467-9876.00065]
- [Karlis & Ntzoufras (2003)](https://doi.org/10.1111/1467-9884.00366) — bivariate-Poisson football score model. [CITED: https://doi.org/10.1111/1467-9884.00366]
- [Groll et al. regularized Poisson](https://doi.org/10.1515/jqas-2014-0051) and [open manuscript](https://epub.ub.uni-muenchen.de/31579/1/Groll_Prediction.pdf) — regularized team effects and covariates. [CITED: https://doi.org/10.1515/jqas-2014-0051]
- [Rue & Salvesen (2000)](https://doi.org/10.1111/1467-9884.00243) and [Crowder et al. (2002)](https://doi.org/10.1111/1467-9884.00308) — dynamic football strength lineage. [CITED: https://doi.org/10.1111/1467-9884.00243; CITED: https://doi.org/10.1111/1467-9884.00308]
- [Official bivpois manual](https://cran.r-project.org/web/packages/bivpois/refman/bivpois.html) — PMF, marginals, covariance, and package API. [CITED: https://cran.r-project.org/web/packages/bivpois/refman/bivpois.html]
- [Koopman & Lit (2015)](https://doi.org/10.1111/rssa.12042) and [Groll et al. (2018)](https://doi.org/10.1515/jqas-2017-0067) — dynamic/covariate bivariate extensions. [CITED: https://doi.org/10.1111/rssa.12042; CITED: https://doi.org/10.1515/jqas-2017-0067]

### Tertiary (LOW confidence)

- No uncited web/community source is used. Project adaptations and discretion choices are marked `[ASSUMED]`. [VERIFIED: research source audit]

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH for local/official package facts; MEDIUM for the chosen nested penalty composition because it is a project adaptation. [VERIFIED: local package audit; CITED: official glmnet documentation; ASSUMED]
- Architecture: HIGH for inherited Phase 9 seams and panel contracts; MEDIUM for new candidate IDs, dynamic parameterization, and bivariate scaling. [VERIFIED: local code/verification; ASSUMED]
- Pitfalls: HIGH for observed repository hazards; MEDIUM for projected disk and numerical thresholds. [VERIFIED: local audits; ASSUMED]
- Validation: HIGH for inherited test framework; MEDIUM-HIGH for proposed Wave 0 assertions and sampling. [VERIFIED: local test run; ASSUMED]

**Research date:** 2026-07-22  
**Valid until:** 2026-08-21 for package/version facts; benchmark-contract findings remain valid until Phase 9 artifacts or Phase 10 context changes. [ASSUMED]
