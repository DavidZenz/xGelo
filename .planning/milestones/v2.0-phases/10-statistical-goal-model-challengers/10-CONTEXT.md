# Phase 10: Statistical Goal-Model Challengers - Context

**Gathered:** 2026-07-22
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase implements and evaluates interpretable statistical goal-model
challengers inside the frozen Phase 09 benchmark: a nested penalized-Poisson
pair, dynamic attack/defence variants, Dixon-Coles and bivariate-Poisson score
dependence, and controlled incumbent ablations. It produces paired historical
comparisons and a small evidence-based shortlist. It does not use World Cup 2026
outcomes, implement Phase 11 machine-learning or structural candidates, add the
Phase 12 calibration layer, or make a final promotion/release decision.

</domain>

<decisions>
## Implementation Decisions

### Penalized Poisson Design

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

### Dynamic Attack And Defence

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

### Score Dependence

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

### Incumbent Ablations And Handoff

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

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone And Benchmark Contracts

- `.planning/ROADMAP.md` - Phase 10 goal, dependency, success criteria, and
  explicit boundary before Phases 11 and 12.
- `.planning/REQUIREMENTS.md` - STAT-01 through STAT-04.
- `.planning/PROJECT.md` - Open-data-first, interpretability, reproducibility,
  and sealed-WC2026 constraints.
- `.planning/phases/09-rolling-tournament-benchmark-harness/09-CONTEXT.md` -
  Locked tournament folds, training evidence, common adapter, scoring, and
  promotion decisions inherited by every challenger.
- `.planning/phases/09-rolling-tournament-benchmark-harness/09-VERIFICATION.md` -
  Verified 630 open / 609 rich panel, durable evidence, and bundle acceptance
  contract that Phase 10 must not weaken.

### Literature And Phase Research

- `.planning/research/SUMMARY.md` - Recommended statistical challenger order,
  libraries, and no-promotion boundary.
- `.planning/research/STACK.md` - `glmnet` and `bivpois` recommendations and
  dependency strategy.
- `.planning/research/FEATURES.md` - Interpretable challenger priorities and
  anti-feature guidance against an uncontrolled model zoo.
- `.planning/phases/09-rolling-tournament-benchmark-harness/09-RESEARCH.md` -
  Groll regularized-Poisson lineage, Dixon-Coles/bivariate comparison rationale,
  and chronology-safe adaptation of the literature.

### Frozen Registries And Evaluation Services

- `data/benchmark/phase09/model_registry.csv` - Registered baseline formulas,
  panels, score support, and immutable settings schema to extend for challengers.
- `data/benchmark/phase09/feature_contract.csv` - Point-in-time feature evidence,
  missingness, active-fit, and license requirements.
- `data/benchmark/phase09/panel_fixtures.csv` - Exact frozen evaluation
  denominators.
- `data/benchmark/phase09/promotion_protocol.json` - Supporting-score and
  stability gates to report without making Phase 12's final decision.
- `R/evaluation/benchmark_scores.R` - Shared proper scores, tournament-first
  aggregation, paired fold deltas, and uncertainty.
- `R/evaluation/promotion.R` - Frozen gate semantics; Phase 10 may report the
  evidence but must not issue a final WC2026 promotion.

### Adapter And Model Integration

- `R/benchmark/baselines.R` - Current fit/predict adapter shape, active/dropped
  predictor manifests, complete score distributions, and feature evidence.
- `R/benchmark/contracts.R` - Prediction, manifest, panel, provenance, and score
  distribution validators.
- `R/benchmark/runner.R` - Canonical deterministic execution, panel-aware
  scoring, comparison, reconciliation, and atomic publication path.
- `R/forecast/poisson.R` - Incumbent negative-binomial formulas and predictor
  blocks to ablate.
- `R/forecast/goal_ability.R` - Existing prior-only weighted goal-ability
  features and evidence helpers that dynamic ratings may supersede or reuse.
- `tests/testthat/test_benchmark_baselines.R` - Adapter and model-manifest
  regression patterns.
- `tests/testthat/test_benchmark_pipeline.R` - End-to-end deterministic bundle
  and panel-routing contracts.
- `tests/testthat/test_benchmark_scoring.R` - Shared scoring and paired-comparison
  expectations.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `run_registered_baseline_adapter()` and the canonical runner already provide
  the fit/predict/evidence/output boundary that challenger adapters must satisfy.
- `benchmark_glm_nb()`, numeric-predictor screening, and active/dropped predictor
  manifests provide established fitting and diagnostics patterns.
- `compute_goal_ability_features()` already enforces prior-date lookup,
  same-day-safe updates, inactivity decay, neutral fallback, and source/value
  evidence companions.
- Shared scoring and promotion modules already compute all required proper-score,
  calibration, uncertainty, fold-breadth, and regression evidence.

### Established Patterns

- Models are registry-driven, file-oriented R modules with explicit `run_*()`
  entry points, deterministic seeds, checked settings hashes, and fail-fast
  schemas.
- Every adapter emits one normalized joint score distribution and derives all
  markets through shared code; model-specific scoring paths are forbidden.
- Source-row presence, numeric-value presence, imputation, active-fit status,
  and output coverage remain separate evidence concepts.
- Frozen and updating tracks share formulas and tuning decisions; only eligible
  prior match evidence changes at deterministic boundaries.

### Integration Points

- Extend the model and feature registries with Phase 10 candidate registrations
  rather than branching scoring behavior inside the runner.
- Add challenger fit/predict modules under the benchmark/forecast layers and
  dispatch them through the existing adapter interface.
- Reuse the exact panel-aware scorer and comparison tables for every nested
  variant and ablation.
- Add Phase 10 targets and reports without changing the dashboard or opening the
  sealed WC2026 evaluation path.

</code_context>

<specifics>
## Specific Ideas

- The nested model pairs are deliberate attribution devices: minimal versus
  augmented Poisson, and dynamic ability alone versus dynamic ability plus Elo.
- Same-day matches are simultaneous evidence batches, not an ordering problem to
  solve with arbitrary row order.
- Zero-coded xG/form columns stay for compatibility, but their inactive status
  must remain impossible to mistake for observed zero signal.
- The phase should reduce the field to a small shortlist while leaving the final
  retain/promote decision sealed for Phase 12.

</specifics>

<deferred>
## Deferred Ideas

None - discussion stayed within the Phase 10 boundary.

</deferred>

---

*Phase: 10-statistical-goal-model-challengers*
*Context gathered: 2026-07-22*
