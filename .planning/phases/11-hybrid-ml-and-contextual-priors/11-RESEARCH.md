# Phase 11: Hybrid ML and Contextual Priors - Research

**Researched:** 2026-08-08
**Domain:** Chronology-safe hybrid football forecasting inside the frozen Phase 09/10 benchmark
**Confidence:** MEDIUM

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### RF And Team Ability

- **D-01:** Implement the primary Groll-style challenger as two goal forests,
  one for home goals and one for away goals. A direct 1X2 classifier is not the
  primary implementation because it cannot satisfy the common goal-distribution
  contract.
- **D-02:** Convert the two RF goal means into the common score distribution by
  using registered/tuned negative-binomial marginals. Preserve football-goal
  overdispersion while retaining the existing shared adapter and G=40 support.
- **D-03:** Supply the RF with fold-local Phase 10 dynamic attack/defence
  abilities and Elo as separate inputs. The ability signal remains estimated
  independently from the forest and must retain its point-in-time evidence.
- **D-04:** Accept the RF only through identical rolling folds and the existing
  proper-score comparison framework. Require consistent improvement or
  non-inferiority across primary scores and stability checks; this phase does
  not automatically promote the RF.

### Open Context And Tournament Coverage

- **D-05:** Register the full open-context bundle: host, neutral venue, rest,
  travel, and tournament stage. Run individual ablations so incremental value
  is attributable to named features rather than only to a combined black box.
- **D-06:** Keep the established primary benchmark core frozen. Copa America and
  AFCON may provide supplemental training information and separately labelled
  regional diagnostics when their point-in-time coverage and provenance qualify,
  but they must not silently change the established core denominator.
- **D-07:** Use a strict common open-context panel for headline context-model
  comparisons. Keep the baseline on its established panel, report explicit
  feature and fixture coverage for the context variants, and do not silently
  impute unavailable context values.
- **D-08:** Derive rest, travel, and stage with deterministic open-data proxies:
  rest from prior match dates, travel from great-circle distance between the
  prior match location and current venue or host-country centroid, and stage
  from checked fixture metadata. Record source, vintage, derivation, and
  missingness for each field.

### Structural Prior And XG Activation

- **D-09:** Construct the Hoffmann-Ging-Ramasamy-inspired structural signal from
  point-in-time, vintage-aware data. Use it only as a prior for teams with
  sparse recent match evidence; raw contemporary structural values must not be
  backfilled into historical folds.
- **D-10:** Apply the structural information through continuous,
  evidence-weighted shrinkage toward the structural prior. Do not use a hard
  sparse/not-sparse switch, and do not add raw structural variables directly to
  the RF or goal model in the primary prior test.
- **D-11:** Determine the prior weight from a recency-weighted effective match
  count. The prior-strength parameter and any bounds or transformation must be
  registered before evaluation.
- **D-12:** Activate xG only after a predeclared point-in-time coverage, variance,
  and provenance gate passes. When the gate fails, xG is explicitly inactive;
  missing xG is not observed zero and the open benchmark remains non-xG.

### Enriched And External Modes

- **D-13:** Implement squad information only as a separately labelled,
  point-in-time enriched mode using locally derived squad-strength aggregates.
  Record vintage and provenance, keep raw restricted data out of committed
  outputs, do not automate collection, and do not replace the open default.
- **D-14:** Use bookmaker consensus only as a manually frozen, point-in-time
  external benchmark. Retain permitted probabilities or derived benchmark
  values with timestamp, source, and licensing metadata; automated collection is
  out of scope.
- **D-15:** Report three distinct modes: open default, enriched squad, and
  external market benchmark. Do not blend their scores or present them as
  equivalent candidates with identical data availability.
- **D-16:** Keep promotion eligibility mode-specific. Only the open-data mode
  can compete for the open default under the established benchmark and
  promotion rules. Enriched and external modes remain labelled research or
  reference outputs.

### Claude's Discretion

- The planner may choose the exact RF feature matrix, forest hyperparameter
  grid, random-forest package wiring, negative-binomial dispersion estimation,
  and the home/away forest tuning relationship, provided these choices are
  registered and chronology-safe.
- The planner may define the exact HGR-inspired structural variable registry,
  vintage availability rules, prior-strength parameterization, and effective
  sample-size formula. These must be justified by the literature record and
  frozen before historical scoring.
- The planner may set the numerical coverage, variance, and provenance gates for
  xG after inspecting available point-in-time evidence, but the gate must be
  predeclared, reproducible, and fail closed.
- The planner may select the concrete open-data sources and derivation schemas
  for rest, travel, stage, host, and neutral venue, subject to the deterministic
  proxy and provenance decisions above.
- The planner may choose the derived squad aggregates, permitted bookmaker
  representation, mode manifests, and report layout, subject to licensing and
  mode-specific promotion boundaries.

### Deferred Ideas (OUT OF SCOPE)

- XGBoost remains deferred until the RF challenger establishes stable nonlinear
  value; this is tracked by `FUTURE-01`.
- Automated bookmaker, FotMob, or Transfermarkt collection remains out of scope
  because of licensing, terms, and reproducibility constraints.
- Current structural snapshots for historical folds, raw structural variables as
  unrestricted RF predictors, and direct 1X2-only RF models are deferred or
  rejected by the phase boundary.
- Expanding the primary benchmark denominator with Copa America or AFCON is
  deferred; they are supplemental training inputs and separately labelled
  regional diagnostics only.
- Combining open, enriched, and external modes into one candidate pool or
  allowing restricted modes to replace the open default is deferred and rejected
  by the mode-specific promotion decision.
- Opening the sealed 2026 holdout and making the final promotion or release
  decision belong to Phase 12.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| HYBRID-01 | Benchmark a Groll-style random forest with independently estimated team-ability parameters. | Use two separate regression forests for `home_goals` and `away_goals`, fed by Phase 10 dynamic attack/defence plus Elo, then map forest means into the existing G=40 negative-binomial adapter instead of inventing a new scoring path. [VERIFIED: `R/forecast/dynamic_goal_ability.R`; `R/benchmark/challengers.R`; `R/benchmark/contracts.R`; `data/benchmark/phase10/model_registry.csv`] |
| HYBRID-02 | Evaluate host, neutral venue, rest, travel, and tournament-context features as a named open-data feature set. | Extend the feature contract and panel-aware coverage flow with deterministic `host`, `neutral`, `rest_days`, `travel_km`, and `stage_id` features; derive stage from the frozen fixture registry and travel from country/centroid geodesics because the benchmark fixture rows only expose `venue_country`, not stadium coordinates. [VERIFIED: `data/benchmark/phase09/fixtures.csv`; `R/forecast/features.R`; `R/benchmark/runner.R`] |
| HYBRID-03 | Report xG coverage and activate xG only when point-in-time signal passes a declared gate. | Historical xG/form is still zero-variance in the canonical training table and the only rolling-form file has 10 rows for 6 teams on 2026-06-05, so the open benchmark must keep xG inactive unless a new historical point-in-time source is added and passes a predeclared gate. [VERIFIED: `data/processed/goal_training_features_hybrid.csv`; `data/processed/rolling_form.csv`; `R/forecast/xg_usage_audit.R`] |
| HYBRID-04 | Evaluate socio-economic variables as a structural prior for sparse recent-match evidence. | Build a separate structural snapshot registry first, then apply those variables only through a continuous shrinkage layer keyed by effective recent sample size; do not pipe raw structural values directly into the RF primary test. [VERIFIED: `11-CONTEXT.md`; `.planning/phases/999.1-socio-economic-structural-benchmark/RESEARCH.md`; `R/forecast/goal_ability.R`] |
| HYBRID-05 | Evaluate squad information and bookmaker consensus only in labelled enriched or external modes. | Reuse the existing Transfermarkt as-of-date aggregation for an enriched `feature_rich` mode and create a new manual external-market manifest for bookmaker snapshots; keep both separate from open-core promotion eligibility. [VERIFIED: `R/transfermarkt/squad_strength.R`; `data/benchmark/phase09/panel_fixtures.csv`; `11-CONTEXT.md`] |
</phase_requirements>

## Summary

Phase 11 should be planned as a Phase 09/10 extension, not as a new modeling surface. The codebase already has the hard parts that must remain canonical: deterministic boundaries, model and feature registries, complete score-distribution validation, panel-aware scoring, stage-probability validation, and the common adapter shape used by Phase 10 challengers. The planner should preserve those seams and add Phase 11 as new registries, feature builders, and challenger adapters behind the same runner. [VERIFIED: `R/benchmark/runner.R`; `R/benchmark/challengers.R`; `R/benchmark/contracts.R`; `R/evaluation/challenger_selection.R`]

Two facts materially constrain the plan. First, xG is not ready for open-core historical activation: `goal_training_features_hybrid.csv` has all five xG/form columns present but with standard deviation `0` and nonzero count `0`, and `rolling_form.csv` has only 10 rows for 6 teams on 2026-06-05. Second, no local structural or bookmaker snapshot exists in the repository today, while enriched squad inputs do exist and already follow dated, local-only rules. That means the xG-informed candidate must default to inactive, and structural/bookmaker work begins with snapshot and registry plumbing before any benchmarked model can exist. [VERIFIED: `data/processed/goal_training_features_hybrid.csv`; `data/processed/rolling_form.csv`; `data/raw/transfermarkt/SNAPSHOT-METADATA.csv`; repository file scan 2026-08-08]

The strongest statistical benchmark handoff is already available from Phase 10: the shortlist names `poisson_team_ridge_elo_bivpois` as the best proper-score challenger, `poisson_team_ridge_elo` as the simplest non-inferior challenger, and `poisson_team_ridge_elo_dc` as the dependence representative. Phase 11 should compare every new open-mode candidate against that frozen statistical handoff on the exact same open-core panel before it spends effort on enriched or external modes. [VERIFIED: `outputs/benchmarks/rolling_tournaments/phase10-statistical-challengers/selection/shortlist.csv`; `11-CONTEXT.md`]

**Primary recommendation:** Plan Phase 11 in three layers: `open-mode RF + context`, then `xG gate and structural-prior registries`, then `separately labelled enriched squad and external bookmaker modes`; do not interleave those concerns into one large implementation wave. [VERIFIED: `11-CONTEXT.md`; `R/benchmark/runner.R`; `data/benchmark/phase09/panel_fixtures.csv`]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| RF fit/predict services | Forecast / Model layer | Benchmark | The forests are model code, but they must emit the same manifest, distribution, and evidence payloads as existing challengers. [VERIFIED: `R/benchmark/challengers.R`; `R/benchmark/contracts.R`] |
| NB score-distribution adapter for RF means | Benchmark adapter layer | Evaluation | The project already scores one normalized joint goal distribution; Phase 11 should reuse that contract instead of inventing RF-specific markets. [VERIFIED: `R/benchmark/contracts.R`; `R/benchmark/baselines.R`] |
| Open-context feature derivation | Forecast feature layer | Data / Storage | Rest, travel, host, neutral, and stage belong in registered point-in-time feature tables with separate evidence companions. [VERIFIED: `R/forecast/features.R`; `data/benchmark/phase09/feature_contract.csv`] |
| xG activation gate | Benchmark governance | Forecast feature layer | The gate is a declared eligibility rule over audited feature evidence, not an informal model choice. [VERIFIED: `R/forecast/xg_usage_audit.R`; `R/benchmark/runner.R`] |
| Structural prior snapshots | Data / Storage | Forecast / Model layer | Structural indicators must be frozen by country and year before the shrinkage layer can consume them. [VERIFIED: repository file scan 2026-08-08; `11-CONTEXT.md`] |
| Sparse-team shrinkage logic | Forecast / Model layer | Evaluation | The prior changes means only for sparse evidence teams, and must remain auditable in manifests and ablation summaries. [VERIFIED: `R/forecast/goal_ability.R`; `11-CONTEXT.md`] |
| Enriched squad mode | Forecast feature layer | Benchmark | The squad aggregates already exist as dated local features; the benchmark must keep them on `feature_rich` and label them separately. [VERIFIED: `R/transfermarkt/squad_strength.R`; `data/benchmark/phase09/panel_fixtures.csv`] |
| External bookmaker mode | Data / Storage | Benchmark | Manual snapshots and licensing metadata are the primary responsibility; the benchmark only evaluates the frozen external rows. [VERIFIED: `11-CONTEXT.md`] |
| Final candidate comparison and research-only handoff | Evaluation | Pipeline | Phase 11 should publish evidence and preserve the Phase 12 promotion boundary. [VERIFIED: `.planning/ROADMAP.md`; `R/evaluation/challenger_selection.R`] |

## Project Constraints (from AGENTS.md)

- Use R and the existing `targets` workflow; do not create a second orchestration system for Phase 11. [VERIFIED: `AGENTS.md`; `_targets.R`]
- Preserve the layer rule: xG and Elo combine only through the integration/feature-table path, not through ad hoc joins inside evaluation code. [VERIFIED: `AGENTS.md`; `R/forecast/features.R`]
- Keep the default mode open-data-first; squad and bookmaker paths stay explicitly labelled optional modes. [VERIFIED: `AGENTS.md`; `11-CONTEXT.md`]
- Do not automate restricted-data collection from FotMob, Transfermarkt, or bookmakers. [VERIFIED: `AGENTS.md`; `11-CONTEXT.md`]
- Use FIFA-code-aware canonical identities instead of display-name joins. [VERIFIED: `AGENTS.md`; `data/benchmark/phase09/teams.csv`]
- Keep negative-binomial score modeling as the common goal-distribution family and preserve deterministic seeds and reproducibility. [VERIFIED: `AGENTS.md`; `R/benchmark/contracts.R`; `R/benchmark/runner.R`]
- Put new regression and contract tests under `tests/testthat/` and keep the benchmark verifiable through deterministic test commands. [VERIFIED: `AGENTS.md`; `tests/testthat/`] 

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `ranger` | `0.18.0` (published 2026-01-16) | Fast regression forests for separate home-goal and away-goal models | Official CRAN docs describe it as a fast random-forest implementation with regression support and prediction APIs that fit the two-forest Phase 11 design. [CITED: https://stat.ethz.ch/CRAN/web/packages/ranger/index.html] |
| `MASS` | `7.3-65` local | Negative-binomial marginals for the shared adapter | The existing benchmark baselines already use `glm.nb`, so reusing this family keeps RF output comparable to Phase 09/10. [VERIFIED: local R runtime; `R/benchmark/baselines.R`] |
| `targets` | `1.12.0` local | Deterministic Phase 11 target DAG | The project already publishes benchmark bundles through `targets`; Phase 11 should extend that exact path. [VERIFIED: local R runtime; `_targets.R`] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `geosphere` | `1.6-8` (published 2026-04-05) | Great-circle travel proxy from prior venue/host centroid to current venue/host centroid | Use for `travel_km`; do not hand-roll spherical distance math. [CITED: https://archive.linux.duke.edu/pub/cran/web/packages/geosphere/index.html] |
| `countrycode` | `1.8.0` (published 2026-04-16) | Country-name and ISO-code normalization for World Bank / CEPII / fixture-country joins | Use when converting `venue_country` or structural source rows into canonical IDs. [CITED: https://stat.ethz.ch/CRAN/web/packages/countrycode/index.html] |
| `DBI` + `duckdb` | `1.3.0` / `1.5.2` local | Read the local Transfermarkt snapshot for enriched squad mode | Reuse the existing squad-strength pipeline instead of building a new restricted-data reader. [VERIFIED: local R runtime; `R/transfermarkt/squad_strength.R`] |
| `randomForest` | `4.7-1.2` (published 2024-09-22) | Conservative fallback forest package | Use only if `ranger` installation or reproducibility becomes blocked; it is slower and less aligned with the current stack recommendation. [CITED: https://mirrors.ibiblio.org/pub/mirrors/pub/mirrors/CRAN/web/packages/randomForest/index.html] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `ranger` | `randomForest` | `randomForest` is already installed locally but offers an older, less performant path; `ranger` is the cleaner Phase 11 primary choice. [CITED: https://stat.ethz.ch/CRAN/web/packages/ranger/index.html; https://mirrors.ibiblio.org/pub/mirrors/pub/mirrors/CRAN/web/packages/randomForest/index.html] |
| `geosphere::distGeo()` | CEPII dyadic country distances only | CEPII is useful for country-level proxies, but it does not replace per-fixture prior-location to current-location travel when the benchmark retains prior venue history. [CITED: https://www.cepii.fr/cepii/en/bdd_modele/bdd_modele_item.asp?id=6] |
| Raw structural variables in RF | Structural shrinkage prior only | The second option is the locked phase design because it avoids historical leakage and mode confusion. [VERIFIED: `11-CONTEXT.md`] |

**Installation:**

```r
install.packages("ranger")
```

The current environment already has `geosphere`, `countrycode`, `targets`, `duckdb`, `DBI`, and `MASS`, while `ranger` is missing from both the default library and the project-local Phase 10 library. [VERIFIED: local R runtime; `data/cache/phase10-library`]

**Version verification:** Package pages were verified against official CRAN package index pages on 2026-08-08; direct `available.packages()` lookup failed in the local sandbox because the CRAN `PACKAGES` index was unreachable from the current runtime. [VERIFIED: local R runtime; CITED: https://stat.ethz.ch/CRAN/web/packages/ranger/index.html; https://archive.linux.duke.edu/pub/cran/web/packages/geosphere/index.html; https://stat.ethz.ch/CRAN/web/packages/countrycode/index.html; https://mirrors.ibiblio.org/pub/mirrors/pub/mirrors/CRAN/web/packages/randomForest/index.html]

## Package Legitimacy Audit

> `gsd-tools query package-legitimacy check` is currently limited to `npm|pypi|crates`, so the automated legitimacy seam could not be applied to CRAN packages. The audit below therefore uses official CRAN package pages plus local runtime inspection. [VERIFIED: local `gsd-tools` usage on 2026-08-08]

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| `ranger` | CRAN | 7+ years on CRAN; current release published 2026-01-16 | n/a on official CRAN page | `https://github.com/imbs-hl/ranger` | OK | Approved for install. [CITED: https://stat.ethz.ch/CRAN/web/packages/ranger/index.html] |
| `geosphere` | CRAN | 16+ years on CRAN; current release published 2026-04-05 | n/a on official CRAN page | `https://github.com/rspatial/geosphere/issues/` | OK | Already available locally. [CITED: https://archive.linux.duke.edu/pub/cran/web/packages/geosphere/index.html] |
| `countrycode` | CRAN | 17+ years on CRAN; current release published 2026-04-16 | n/a on official CRAN page | `https://github.com/vincentarelbundock/countrycode/issues` | OK | Already available locally. [CITED: https://stat.ethz.ch/CRAN/web/packages/countrycode/index.html] |
| `randomForest` | CRAN | 20+ years on CRAN; current release published 2024-09-22 | n/a on official CRAN page | project URL listed on CRAN | OK | Fallback only, not the primary recommendation. [CITED: https://mirrors.ibiblio.org/pub/mirrors/pub/mirrors/CRAN/web/packages/randomForest/index.html] |

**Packages removed due to unsupported or suspicious audit results:** none. [VERIFIED: local audit 2026-08-08]
**Packages flagged as suspicious:** none from the recommended CRAN set. [CITED: CRAN package pages above]

## Architecture Patterns

### System Architecture Diagram

```text
Phase 09/10 frozen registries + Phase 10 shortlist
                    |
                    v
          Phase 11 protocol registries
          - model registry
          - feature contract
          - mode registry
          - xG gate / structural prior / manual market manifests
                    |
        +-----------+------------+------------------+
        |                        |                  |
        v                        v                  v
 open-mode feature builder   enriched squad mode   external market mode
 - dynamic ability + Elo     - Transfermarkt       - manual frozen odds
 - host/neutral/rest/travel  - feature_rich only   - reference only
 - stage + evidence          - local-only license  - licensing manifest
        |                        |                  |
        +-----------+------------+------------------+
                    |
                    v
          common challenger adapters
          - two RF goal forests
          - structural-prior shrinkage variant
          - xG candidate only if gate passes
                    |
                    v
         shared NB score-distribution adapter
                    |
                    v
      Phase 09 scorer / panel coverage / comparisons
                    |
                    v
      research-only Phase 11 bundle and handoff to Phase 12
```

### Recommended Project Structure

```text
R/
├── benchmark/
│   ├── hybrid_protocol.R      # Phase 11 registries and validators
│   ├── hybrid_runner.R        # publication and bundle orchestration
│   └── hybrid_adapters.R      # RF, structural, xG-gated, mode dispatch
├── forecast/
│   ├── hybrid_rf.R            # two-goal forest fit/predict helpers
│   ├── context_features.R     # host, rest, travel, stage derivation
│   ├── structural_prior.R     # vintage-aware structural snapshots + shrinkage
│   └── external_market.R      # manual bookmaker snapshot validation
data/
├── benchmark/phase11/         # frozen registries and gate manifests
└── processed/                 # optional structural snapshots if committed
tests/testthat/
├── test_hybrid_random_forest.R
├── test_hybrid_context_features.R
├── test_hybrid_xg_gate.R
├── test_hybrid_structural_prior.R
├── test_hybrid_modes.R
└── test_hybrid_targets.R
```

### Pattern 1: Reuse The Existing Challenger Adapter Contract

**What:** Phase 11 candidates should fit/predict through the same adapter surface Phase 10 used: checked registration row in, canonical predictions/manifests/feature coverage out. [VERIFIED: `R/benchmark/challengers.R`; `R/benchmark/challenger_runner.R`]

**When to use:** For every open, enriched, or external candidate that must publish a benchmark bundle. [VERIFIED: `R/benchmark/runner.R`]

**Example:**

```r
# Source: local project adapter pattern
registration <- protocol$model_registry[
  protocol$model_registry$candidate_id == "phase11_rf_open", , drop = FALSE
]

result <- run_registered_challenger_adapter(
  registration = registration,
  history = history,
  fixtures = fixtures,
  seeds = seeds,
  run_id = run_id,
  feature_contract = protocol$feature_contract
)
```

### Pattern 2: Build Context Features As Evidence-Returning Latest-Before Lookups

**What:** Every derived feature should emit both value and provenance companions so the gate, registry, and scorer can distinguish observed zero from missing or imputed zero. [VERIFIED: `R/forecast/features.R`] 

**When to use:** Host flags, prior-rest days, travel kilometers, structural snapshots, and any xG activation metric. [VERIFIED: `R/forecast/features.R`; `R/benchmark/contracts.R`]

**Example:**

```r
# Source: local project feature-evidence pattern
lookup <- make_latest_team_evidence_lookup(
  data = structural_snapshot,
  value_col = "gdp_per_capita",
  team_col = "team",
  date_col = "snapshot_date",
  default = NA_real_
)

home_gdp <- lookup(home_team, fixture_date)
```

### Pattern 3: Keep Travel As A Deterministic Geodesic Proxy

**What:** Convert country identifiers to ISO codes, map to centroids, and compute great-circle distance between prior and current location proxies. [CITED: https://stat.ethz.ch/CRAN/web/packages/countrycode/index.html; https://archive.linux.duke.edu/pub/cran/web/packages/geosphere/index.html]

**When to use:** Open-context feature generation for `travel_km`; not for squad or bookmaker modes. [VERIFIED: `11-CONTEXT.md`]

**Example:**

```r
# Source: official CRAN package capabilities
home_iso3 <- countrycode::countrycode("Germany", "country.name", "iso3c")
away_iso3 <- countrycode::countrycode("Portugal", "country.name", "iso3c")

travel_km <- geosphere::distGeo(
  p1 = c(prev_lon, prev_lat),
  p2 = c(curr_lon, curr_lat)
) / 1000
```

### Anti-Patterns to Avoid

- **Direct 1X2 RF classifier as the primary path:** It cannot satisfy the shared goal-distribution contract and would force a second scoring surface. [VERIFIED: `11-CONTEXT.md`; `R/benchmark/contracts.R`]
- **Silent xG activation:** Present-but-zero historical xG columns are not evidence of usable point-in-time xG. [VERIFIED: `data/processed/goal_training_features_hybrid.csv`; `R/forecast/xg_usage_audit.R`]
- **Raw structural covariates inside the primary RF:** The locked design is shrinkage-only for sparse recent evidence teams. [VERIFIED: `11-CONTEXT.md`]
- **Mode pooling:** Open, enriched, and external modes must not share one leaderboard or one promotion path. [VERIFIED: `11-CONTEXT.md`; `data/benchmark/phase09/panel_fixtures.csv`] 

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Random-forest engine | Custom tree ensemble code | `ranger` | The project needs stable regression forests and a maintained prediction API, not a one-off implementation. [CITED: https://stat.ethz.ch/CRAN/web/packages/ranger/index.html] |
| Great-circle travel math | Manual Haversine utilities | `geosphere::distGeo()` | Travel is a proxy feature; the edge cases belong in a maintained geographic package. [CITED: https://archive.linux.duke.edu/pub/cran/web/packages/geosphere/index.html] |
| Country normalization | Ad hoc string maps for every source | `countrycode` plus `canonicalise_feature_team_name()` | Structural and venue sources will disagree on country labels; normalize before joining. [CITED: https://stat.ethz.ch/CRAN/web/packages/countrycode/index.html; VERIFIED: `R/forecast/features.R`] |
| Goal-distribution markets | RF-specific market formulas | Existing benchmark distribution validators and market derivation | The benchmark already owns normalization, markets, and score support. [VERIFIED: `R/benchmark/contracts.R`; `R/benchmark/baselines.R`] |
| Structural data web scraping | HTML scraping of World Bank or CEPII pages | World Bank V2 API plus frozen CSV snapshots; CEPII downloadable datasets | Official endpoints and downloadable artifacts are reproducible; scraping pages is brittle and unnecessary. [CITED: https://datahelpdesk.worldbank.org/knowledgebase/articles/898581-api-basic-call-structures; https://www.cepii.fr/cepii/en/bdd_modele/bdd_modele_item.asp?id=6] |

**Key insight:** Phase 11 complexity is not the forest itself; it is preserving the Phase 09 benchmark contract while adding new feature modes, provenance, and gates. Reusing the existing contract code is the only low-risk path. [VERIFIED: `R/benchmark/runner.R`; `R/benchmark/contracts.R`]

## Common Pitfalls

### Pitfall 1: Planning An xG Candidate Before xG Exists Historically

**What goes wrong:** The planner schedules RF+xG modeling work even though the current open-core historical xG columns are all zero-variance and therefore guaranteed to fail any honest activation gate. [VERIFIED: `data/processed/goal_training_features_hybrid.csv`]

**Why it happens:** The columns exist in the canonical training file, which can be mistaken for real historical coverage. [VERIFIED: `R/forecast/xg_usage_audit.R`]

**How to avoid:** Make the xG gate a registry artifact first, run the audit first, and keep the Phase 11 open-mode baseline explicitly non-xG unless new historical data is added. [VERIFIED: `11-CONTEXT.md`; `R/forecast/xg_usage_audit.R`]

**Warning signs:** `sd == 0`, `nonzero_count == 0`, or `rolling_form.csv` still limited to six teams. [VERIFIED: `data/processed/goal_training_features_hybrid.csv`; `data/processed/rolling_form.csv`]

### Pitfall 2: Treating `venue_country` As Exact Travel Geography

**What goes wrong:** Travel is described or implemented as stadium-level or city-level when the frozen fixture registry only exposes `venue_country`. [VERIFIED: `data/benchmark/phase09/fixtures.csv`]

**Why it happens:** `stage_id` and `venue_country` are present, which makes the registry look richer than it is. [VERIFIED: `data/benchmark/phase09/fixtures.csv`]

**How to avoid:** Register travel as a country-centroid or host-centroid proxy and document the approximation explicitly. [VERIFIED: `11-CONTEXT.md`; CITED: https://www.cepii.fr/cepii/en/bdd_modele/bdd_modele_item.asp?id=6]

**Warning signs:** Plan text mentions stadium, timezone, or route-level data without naming a new source. [VERIFIED: repository data scan 2026-08-08]

### Pitfall 3: Backfilling Structural Priors With Current Data

**What goes wrong:** Current GDP, climate, or host-status tables leak future information into historical tournament folds. [VERIFIED: `11-CONTEXT.md`; `.planning/phases/999.1-socio-economic-structural-benchmark/RESEARCH.md`]

**Why it happens:** Structural variables change slowly, which makes leakage less obvious than score leakage. [VERIFIED: first-principles phase analysis 2026-08-08]

**How to avoid:** Freeze structural snapshots by year and country, and require source-year `< evidence_cutoff_exclusive`. [CITED: https://datahelpdesk.worldbank.org/knowledgebase/articles/898581-api-basic-call-structures; VERIFIED: `R/forecast/features.R`] 

**Warning signs:** Structural files without `snapshot_year` or source-date columns, or plans that mention "latest GDP". [VERIFIED: repository file scan 2026-08-08]

### Pitfall 4: Letting Optional Modes Change The Open-Core Denominator

**What goes wrong:** Enriched squad or external market outputs are evaluated as if they were interchangeable with the 630-fixture open panel. [VERIFIED: `data/benchmark/phase09/panel_fixtures.csv`] 

**Why it happens:** The benchmark already supports a `feature_rich` panel, so it is easy to overgeneralize it. [VERIFIED: `data/benchmark/phase09/panel_fixtures.csv`; `R/benchmark/contracts.R`]

**How to avoid:** Keep open-mode headlines on `open_core`, use `feature_rich` for enriched mode only, and register a separate panel for external market if needed. [VERIFIED: `11-CONTEXT.md`; `R/benchmark/contracts.R`]

**Warning signs:** One report table ranks open, enriched, and external candidates together without panel labels. [VERIFIED: `11-CONTEXT.md`]

### Pitfall 5: Forgetting Runtime Packaging

**What goes wrong:** Phase 11 code lands, but `_targets.R` and local libraries cannot execute it because `ranger` is not available. [VERIFIED: local R runtime; `_targets.R`; `data/cache/phase10-library`]

**Why it happens:** `glmnet` already works through a project-local Phase 10 library, which can hide the fact that `ranger` is still absent. [VERIFIED: local R runtime; `data/cache/phase10-library`] 

**How to avoid:** Add a Phase 11 dependency preflight and choose whether to extend the project-local library pattern or require system installation before the target DAG runs. [VERIFIED: `_targets.R`; `tests/testthat/test_statistical_targets.R`]

**Warning signs:** `requireNamespace("ranger", quietly = TRUE)` fails on a clean R session. [VERIFIED: local R runtime]

## Code Examples

Verified patterns from official sources and the local codebase:

### Two-Goal RF Skeleton

```r
# Source: official ranger package docs + local benchmark contract
rf_home <- ranger::ranger(
  home_goals ~ elo_diff + home_attack_effect + away_defence_effect + rest_days +
    travel_km + stage_group + host_flag,
  data = train_df,
  num.trees = 1000,
  min.node.size = 5,
  seed = 920001
)

mu_home <- as.numeric(predict(rf_home, data = score_df)$predictions)
```

Source: [ranger CRAN package](https://stat.ethz.ch/CRAN/web/packages/ranger/index.html), [predict.ranger docs](https://search.r-project.org/CRAN/refmans/ranger/html/predict.ranger.html)

### Feature Evidence Pattern

```r
# Source: local point-in-time feature pattern
row <- add_forecast_feature_evidence(
  row = row,
  feature_id = "travel_km",
  evidence = list(
    value = travel_km,
    value_present = is.finite(travel_km),
    source_present = TRUE,
    source_date = fixture_date - 1,
    imputed = FALSE,
    imputation_reason = ""
  )
)
```

Source: [R/forecast/features.R](/Users/davidzenz/R/xGelo/R/forecast/features.R:210)

### World Bank Vintage Query Shape

```text
https://api.worldbank.org/v2/country/all/indicator/NY.GDP.PCAP.KD?format=json&date=2000:2010&per_page=20000
```

Source: [World Bank API basic call structures](https://datahelpdesk.worldbank.org/knowledgebase/articles/898581-api-basic-call-structures)

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `randomForest` as a generic R RF default | `ranger` as the faster maintained regression-forest path | `ranger` current CRAN release 0.18.0 published 2026-01-16 | Better fit with large tabular training sets and cleaner prediction APIs for regression forests. [CITED: https://stat.ethz.ch/CRAN/web/packages/ranger/index.html] |
| Direct classifier forests for W/D/L | Two goal forests plus shared goal-distribution adapter | Locked for Phase 11 on 2026-08-08 | Preserves exact-score, BTTS, totals, and stage scoring under the common benchmark contract. [VERIFIED: `11-CONTEXT.md`; `R/benchmark/contracts.R`] |
| Treating macro variables as direct match predictors | Using them as sparse-team shrinkage priors | Locked for Phase 11 on 2026-08-08 | Reduces leakage and keeps the open match model interpretable. [VERIFIED: `11-CONTEXT.md`; `.planning/phases/999.1-socio-economic-structural-benchmark/RESEARCH.md`] |

**Deprecated/outdated:**

- `xG-informed open candidate` under the current historical files: outdated for this repo state because historical xG/form coverage is still inactive. [VERIFIED: `data/processed/goal_training_features_hybrid.csv`; `data/processed/rolling_form.csv`]
- `Single pooled leaderboard for open + enriched + external modes`: rejected by the phase contract. [VERIFIED: `11-CONTEXT.md`]

## Open Questions (RESOLVED)

1. **Structural source persistence is resolved as frozen, committed CSV inputs with metadata and checksums.**
   - Decision: Phase 11 must create and commit `data/benchmark/phase11/structural_sources.csv`, `data/benchmark/phase11/structural_sources_metadata.csv`, and `data/benchmark/phase11/structural_sources_checksums.csv` before structural shrinkage can run. The snapshot contains only the exact structural indicators used in the benchmark, keyed by country ISO3, indicator ID, source year, snapshot vintage, source date, and license class. [VERIFIED: `11-CONTEXT.md`; repository file scan 2026-08-08]
   - Source rule: Use official World Bank V2 indicator exports for annual country indicators and CEPII/Natural Earth-derived open geography only when needed for country identity support; live API calls are allowed only while freezing the committed snapshot, never during benchmark execution. [CITED: https://datahelpdesk.worldbank.org/knowledgebase/articles/898581-api-basic-call-structures; https://www.cepii.fr/cepii/en/bdd_modele/bdd_modele_item.asp?id=6]
   - Execution rule: `load_structural_prior_snapshots()` must reject unregistered files, files without matching checksum rows, and current/latest snapshots whose `source_date` or `snapshot_year` is not strictly before the fold evidence cutoff. This resolves HYBRID-04 as an executable structural-prior requirement with concrete source artifacts.

2. **External bookmaker snapshot schema is resolved as a separately labelled optional manual file.**
   - Decision: The manual market snapshot, when legally provided, lives outside open mode as `data/manual/bookmaker/phase11_manual_market_snapshot.csv` plus a checksum-backed manifest row in `data/benchmark/phase11/manual_market_manifest.csv`. Its absence keeps `external_market` registered inactive without blocking open-mode RF, context, xG-gate, or structural-prior execution. [VERIFIED: `11-CONTEXT.md`]
   - Schema rule: Required fields are `snapshot_id`, `fixture_id`, `home_team_id`, `away_team_id`, `market_date`, `captured_at_utc`, `source_name`, `source_url_or_label`, `license_class`, `redistribution_allowed`, `manual_freeze_operator`, `p_home`, `p_draw`, `p_away`, `source_sha256`, and `row_sha256`. Probabilities must be normalized, source timestamps must be pre-cutoff for the fixture, and restricted raw rows must not be copied into published benchmark outputs.
   - Execution rule: External mode can evaluate manually frozen 1X2 probabilities as a reference benchmark only; implied ability reconstruction is not part of the Phase 11 executable schema and must not be required for HYBRID-05.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| R | All Phase 11 code | yes | `4.6.1` | none [VERIFIED: local runtime] |
| `targets` | Phase 11 DAG integration | yes | `1.12.0` | none [VERIFIED: local runtime] |
| `glmnet` | Phase 10 parent replay / some existing imports | yes, project-local only | `5.0` | keep existing `data/cache/phase10-library` pattern [VERIFIED: local runtime; `data/cache/phase10-library`] |
| `ranger` | RF challenger | no | - | Wave 0 Plan 11-07 installs or vendors official CRAN `ranger` 0.18.0 into `data/cache/phase11-library` from a checksum-verified retained archive before 11-02 RF implementation [VERIFIED: local runtime; `11-07-PLAN.md`] |
| `geosphere` | Travel proxy | yes | `1.6.8` | none recommended [VERIFIED: local runtime] |
| `countrycode` | Structural and venue country normalization | yes | `1.8.0` | existing canonical team-name helper for partial fallback [VERIFIED: local runtime; `R/forecast/features.R`] |
| `DBI` + `duckdb` | Enriched squad mode | yes | `1.3.0` / `1.5.2` | none if using existing Transfermarkt snapshot [VERIFIED: local runtime] |
| Transfermarkt DuckDB snapshot | Enriched squad mode | yes | snapshot modified `2026-06-09` | enriched mode can run [VERIFIED: `data/raw/transfermarkt/SNAPSHOT-METADATA.csv`] |
| Structural source snapshot | Structural prior | no local snapshot | - | Plan 11-04 creates committed `data/benchmark/phase11/structural_sources.csv`, metadata, and checksums before shrinkage runs [VERIFIED: repository file scan 2026-08-08; `11-04-PLAN.md`] |
| Manual bookmaker snapshot | External market mode | no local snapshot | - | optional `data/manual/bookmaker/phase11_manual_market_snapshot.csv` keyed by fixture/team/date/probability/source/timestamp/license/checksum; absence keeps only external mode inactive [VERIFIED: repository file scan 2026-08-08; `11-05-PLAN.md`] |

**Missing dependencies with no fallback:**

- None after Wave 0 Plan 11-07 completes. Before 11-07, `ranger` is absent locally and RF execution must remain blocked; after 11-07, the exact `ranger` 0.18.0 local-library provenance is the required runtime proof for HYBRID-01. [VERIFIED: local runtime; `11-07-PLAN.md`]

**Missing dependencies with fallback:**

- Structural prior data snapshot: can be created during the phase from official World Bank / CEPII sources, but benchmark execution should not depend on live network access afterward. [CITED: https://datahelpdesk.worldbank.org/knowledgebase/articles/898581-api-basic-call-structures; https://www.cepii.fr/cepii/en/bdd_modele/bdd_modele_item.asp?id=6]
- External bookmaker snapshot: optional external mode can remain unexecuted until a manual snapshot is provided, without blocking open-mode Phase 11 work. [VERIFIED: `11-CONTEXT.md`]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `testthat 3.3.2` [VERIFIED: local runtime] |
| Config file | none dedicated; suite is driven from `tests/testthat/` [VERIFIED: repository scan 2026-08-08] |
| Quick run command | `Rscript -e 'testthat::test_file("tests/testthat/test_hybrid_random_forest.R", stop_on_failure = TRUE, stop_on_warning = TRUE)'` |
| Full suite command | `Rscript -e 'testthat::test_dir("tests/testthat", stop_on_failure = TRUE, stop_on_warning = TRUE)'` [VERIFIED: `AGENTS.md`] |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| HYBRID-01 | Two-goal RF candidate emits valid predictions, manifests, and score distributions on exact open-core fixtures | unit + integration | `Rscript -e 'testthat::test_file("tests/testthat/test_hybrid_random_forest.R", stop_on_failure = TRUE, stop_on_warning = TRUE)'` | no - Wave 0 |
| HYBRID-02 | Context bundle derives host, neutral, rest, travel, and stage without leakage and with evidence rows | unit | `Rscript -e 'testthat::test_file("tests/testthat/test_hybrid_context_features.R", stop_on_failure = TRUE, stop_on_warning = TRUE)'` | no - Wave 0 |
| HYBRID-03 | xG gate fails closed under current zero-coverage data and activates only when declared thresholds pass | unit + integration | `Rscript -e 'testthat::test_file("tests/testthat/test_hybrid_xg_gate.R", stop_on_failure = TRUE, stop_on_warning = TRUE)'` | no - Wave 0 |
| HYBRID-04 | Structural prior snapshotting and shrinkage are point-in-time safe and only affect sparse-evidence teams | unit | `Rscript -e 'testthat::test_file("tests/testthat/test_hybrid_structural_prior.R", stop_on_failure = TRUE, stop_on_warning = TRUE)'` | no - Wave 0 |
| HYBRID-05 | Enriched squad and external bookmaker modes stay separately labelled and panel-correct | integration | `Rscript -e 'testthat::test_file("tests/testthat/test_hybrid_modes.R", stop_on_failure = TRUE, stop_on_warning = TRUE)'` | no - Wave 0 |

### Sampling Rate

- **Per task commit:** run the most local new Phase 11 test file plus any touched benchmark regression file. [VERIFIED: test suite pattern in `tests/testthat/`]
- **Per wave merge:** run all Phase 11 tests plus `test_benchmark_pipeline.R` and `test_benchmark_contracts.R`. [VERIFIED: existing regression suite]
- **Phase gate:** full `tests/testthat` suite green before verification. [VERIFIED: `AGENTS.md`; `.planning/config.json`]

### Wave 0 Gaps

- [ ] `tests/testthat/test_hybrid_random_forest.R` - HYBRID-01
- [ ] `tests/testthat/test_hybrid_context_features.R` - HYBRID-02
- [ ] `tests/testthat/test_hybrid_xg_gate.R` - HYBRID-03
- [ ] `tests/testthat/test_hybrid_structural_prior.R` - HYBRID-04
- [ ] `tests/testthat/test_hybrid_modes.R` - HYBRID-05
- [ ] `tests/testthat/test_hybrid_targets.R` - target DAG and bundle-chain regression

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Not a user-auth phase. [VERIFIED: phase scope] |
| V3 Session Management | no | Not a session-bearing application surface. [VERIFIED: phase scope] |
| V4 Access Control | yes | Preserve purpose-gated WC2026 sealing and explicit mode boundaries for restricted/local and external data. [VERIFIED: `R/benchmark/runner.R`; `11-CONTEXT.md`] |
| V5 Input Validation | yes | Reuse benchmark contract validators, required-column checks, checksum validation, and exact panel enforcement. [VERIFIED: `R/benchmark/contracts.R`; `R/benchmark/registry.R`] |
| V6 Cryptography | yes | Keep using `digest` SHA-256 for manifests and frozen parent graphs; do not invent custom hashing. [VERIFIED: `R/benchmark/runner.R`; `R/benchmark/challenger_protocol.R`] |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Historical leakage through structural snapshots or xG backfills | Tampering / Information Disclosure | Require `source_date < evidence_cutoff_exclusive` on every optional feature source and fail closed when absent. [VERIFIED: `R/forecast/features.R`; `11-CONTEXT.md`] |
| Silent optional-data activation | Tampering | Keep separate mode registries, feature coverage, and panel membership. [VERIFIED: `data/benchmark/phase09/panel_fixtures.csv`; `R/benchmark/contracts.R`] |
| Restricted-data redistribution | Information Disclosure | Publish only derived aggregates and metadata; keep raw Transfermarkt/bookmaker rows out of committed outputs. [VERIFIED: `data/raw/transfermarkt/README.md`; `11-CONTEXT.md`] |
| Bundle or registry drift | Tampering | Reuse registration/settings hashes, checksum manifests, and exact-row validators. [VERIFIED: `R/benchmark/challenger_protocol.R`; `R/benchmark/runner.R`] |
| Manual snapshot contamination | Repudiation / Tampering | Require timestamp, source, license, and checksum fields for structural and external snapshots before benchmarking. [VERIFIED: Phase 11 design analysis 2026-08-08] |

## Sources

### Primary (HIGH confidence)

- `11-CONTEXT.md` - locked Phase 11 design, mode boundaries, and planner discretion. [VERIFIED: local file]
- `R/benchmark/runner.R`, `R/benchmark/challengers.R`, `R/benchmark/contracts.R` - canonical adapter, scoring, panel, and bundle contracts. [VERIFIED: local code]
- `R/forecast/dynamic_goal_ability.R`, `R/forecast/features.R`, `R/forecast/xg_usage_audit.R` - reusable Phase 10 ability, feature-evidence, and xG-audit logic. [VERIFIED: local code]
- `R/transfermarkt/squad_strength.R` and `data/raw/transfermarkt/SNAPSHOT-METADATA.csv` - existing enriched squad mode input and date-safe aggregation path. [VERIFIED: local code and data]
- `data/benchmark/phase09/fixtures.csv`, `feature_contract.csv`, `panel_fixtures.csv` - frozen fixture geography/stage facts, open/rich panels, and registered feature semantics. [VERIFIED: local data]
- `outputs/benchmarks/rolling_tournaments/phase10-statistical-challengers/selection/shortlist.csv` - strongest statistical handoff candidates. [VERIFIED: local output]

### Secondary (MEDIUM confidence)

- `ranger` CRAN page and `predict.ranger` docs - current package version and supported regression/prediction APIs. [CITED: https://stat.ethz.ch/CRAN/web/packages/ranger/index.html; https://search.r-project.org/CRAN/refmans/ranger/html/predict.ranger.html]
- `geosphere` CRAN page - current package version and geodesic distance package scope. [CITED: https://archive.linux.duke.edu/pub/cran/web/packages/geosphere/index.html]
- `countrycode` CRAN page - current package version and code-conversion capabilities. [CITED: https://stat.ethz.ch/CRAN/web/packages/countrycode/index.html]
- World Bank API docs - official V2 query structure and indicator access patterns. [CITED: https://datahelpdesk.worldbank.org/knowledgebase/articles/898581-api-basic-call-structures; https://datahelpdesk.worldbank.org/knowledgebase/articles/898599-indicator-api-queries; https://databank.worldbank.org/metadataglossary/sustainable-development-goals-%28sdgs%29/series/NY.GDP.PCAP.KD]
- CEPII GeoDist documentation - official scope of bilateral distance and country-level geography variables. [CITED: https://www.cepii.fr/cepii/en/bdd_modele/bdd_modele_item.asp?id=6]
- Groll / Schauberger and HGR references already captured in project research. [VERIFIED: `.planning/phases/999.1-socio-economic-structural-benchmark/RESEARCH.md`; `.planning/phases/09-rolling-tournament-benchmark-harness/09-RESEARCH.md`]

### Tertiary (LOW confidence)

- none.

## Metadata

**Confidence breakdown:**

- Standard stack: MEDIUM - official package pages were verified, but the local runtime could not query CRAN directly and `ranger` is not yet installed. [VERIFIED: local runtime; official CRAN pages]
- Architecture: HIGH - the relevant benchmark, feature, and output contracts are all in the local repository and already exercised by Phase 09/10. [VERIFIED: local code and tests]
- Pitfalls: HIGH - the biggest risks are directly observable in the current repo state: xG inactivity, missing structural/bookmaker snapshots, mode separation, and runtime packaging. [VERIFIED: local code and data]

**Research date:** 2026-08-08
**Valid until:** 2026-09-07
