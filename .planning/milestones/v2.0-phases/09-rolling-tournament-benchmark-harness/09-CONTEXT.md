# Phase 9: Rolling Tournament Benchmark Harness - Context

**Gathered:** 2026-07-20
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase builds the deterministic historical benchmark used by every baseline
and challenger: tournament folds, point-in-time training contracts, common
prediction schemas, registered baselines, scoring, uncertainty, and a frozen
promotion protocol. It does not implement the Phase 10 statistical challengers,
the Phase 11 hybrid/structural models, or open the sealed World Cup 2026 holdout.

</domain>

<decisions>
## Implementation Decisions

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

### The Agent's Discretion

The planner may define the file layout, adapter API, exact numeric recency and
importance schedule, cross-format matchday boundary convention, bootstrap or
hierarchical interval implementation, calibration-error estimator, scoreline
support/tail representation, and report styling. These choices must be declared
before evaluation, deterministic, and consistent with D-01 through D-20.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone And Phase Contracts

- `.planning/ROADMAP.md` - Phase 9 goal, dependencies, and success criteria.
- `.planning/REQUIREMENTS.md` - BENCH-01 through BENCH-05 and the sealed-2026
  requirements.
- `.planning/PROJECT.md` - Open-data constraints and v2.0 evaluation principles.
- `.planning/research/SUMMARY.md` - Literature-backed benchmark architecture,
  model-family ordering, and critical leakage pitfalls.
- `.planning/phases/08-forecast-ledger-and-wc-2026-retrospective/08-CONTEXT.md` -
  Locked evidence, scoring, missingness, and reporting rules inherited from
  Phase 8.
- `.planning/phases/08-forecast-ledger-and-wc-2026-retrospective/08-03-SUMMARY.md` -
  Actual WC2026 coverage findings and mandatory retention gaps for Phase 9.

### Existing Benchmark And Evaluation Code

- `R/benchmark/euro2024.R` - Current frozen EURO 2024 match-level benchmark,
  baseline/hybrid feature fitting, prediction rows, and metrics.
- `R/benchmark/euro2024_tournament.R` - Current tournament simulation and stage
  probability comparison patterns.
- `R/evaluation/proper_scores.R` - Validated RPS, Brier, log, binary, and
  score-distribution scoring rules.
- `R/evaluation/worldcup_retrospective.R` - Equal-fixture aggregation,
  calibration bins, paired bootstrap, advancement, and stage-reach scoring.
- `R/forecast/poisson.R` - Existing open and hybrid negative-binomial predictor
  contracts and fitting behavior.
- `R/forecast/monte_carlo.R` - Complete scoreline distribution and derived
  match/tournament forecast outputs.
- `_targets.R` - Existing file-oriented orchestration and Phase 8 evaluation
  target integration.

### Regression Contracts

- `tests/testthat/test_transfermarkt_benchmark.R` - Synthetic EURO benchmark
  and tournament simulation expectations to preserve or supersede explicitly.
- `tests/testthat/test_worldcup_scoring.R` - Proper-score formulas, coverage,
  deterministic uncertainty, and stage-anchor tests.
- `tests/testthat/test_worldcup_retrospective.R` - Immutable bundle, provenance,
  report, and cache-only runner contracts.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `run_euro2024_benchmark()` already demonstrates point-in-time holdout
  selection, feature building, baseline/hybrid fitting, shared prediction rows,
  and RPS/Brier/log-loss output.
- `run_euro2024_tournament_benchmark()` already precomputes fixture predictions
  and simulates complete tournament paths for more than one model.
- `proper_scores.R` and `worldcup_retrospective.R` provide tested scoring and
  deterministic interval helpers that should become shared benchmark services.
- Existing forecast functions already distinguish `baseline_goal_predictors()`
  and `hybrid_goal_predictors()` and attach model metadata to RDS artifacts.

### Established Patterns

- The repository uses project-relative CSV/RDS contracts, explicit `run_*()`
  entry points, deterministic seeds, fail-fast schema validation, and `targets`
  orchestration.
- Testthat files source R modules directly and combine small synthetic contract
  tests with real artifact regression checks.
- Existing EURO outputs are useful legacy references, but the new multi-fold
  harness should become authoritative instead of inheriting one-tournament
  promotion logic.

### Integration Points

- Add the fold registry, model adapters, feature contracts, manifests, and
  promotion checks under a dedicated benchmark/evaluation layer.
- Feed every adapter through one prediction schema before metrics or tournament
  simulation, preventing model-specific scoring paths.
- Register fold inventories, baseline artifacts, paired comparisons, and the
  frozen promotion protocol in `_targets.R` without changing dashboard behavior.

</code_context>

<specifics>
## Specific Ideas

- The benchmark should represent operational forecasting: issue an early frozen
  tournament forecast, then use pre-match updates and matchday refits as results
  arrive.
- Equal tournament weighting is intentional so expanded modern formats do not
  dominate model selection.
- Baseline quality must be judged against both the open-data core and, where
  provenance permits, the production hybrid feature set.

</specifics>

<deferred>
## Deferred Ideas

- Expand the proven benchmark harness to Copa America and Africa Cup of Nations.
  This is valuable for confederation and style diversity but lies outside Phase
  9's locked World Cup/Euro scope.

</deferred>

---

*Phase: 09-rolling-tournament-benchmark-harness*
*Context gathered: 2026-07-20*
