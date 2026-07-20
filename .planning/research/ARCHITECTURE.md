# Architecture Research

**Domain:** Leakage-safe probabilistic sports-model benchmarking
**Researched:** 2026-07-20
**Confidence:** HIGH

## System Overview

```text
Historical git snapshots + canonical results
                    |
                    v
        Forecast Ledger Builder
        - cutoff and kickoff proof
        - provenance manifest
                    |
                    v
        Evaluation Contract
        - common prediction schema
        - proper scoring rules
        - calibration/stage metrics
                    |
                    v
        Rolling Tournament Harness
        - immutable folds
        - shared seeds and fixtures
                    |
        +-----------+-----------+
        |           |           |
        v           v           v
     Baselines   Statistical   ML/context
                 challengers   challengers
        +-----------+-----------+
                    |
                    v
          Calibration + Promotion
                    |
                    v
         Versioned model and report
```

## Component Responsibilities

| Component | Responsibility | Implementation |
|-----------|----------------|----------------|
| Ledger builder | Recover last forecast before kickoff and attach actuals | Git plumbing plus R schema validation |
| Benchmark schema | Normalize predictions from every model | Data frame contract with model/fold/cutoff/provenance |
| Fold registry | Define train, calibration, and assessment periods | Tournament-blocked `rsample` or explicit split table |
| Model adapter | Fit/predict through one interface | Named R functions returning score distributions |
| Metric engine | Proper scores and uncertainty | yardstick/scoringRules plus bootstrap by tournament |
| Promotion engine | Apply predeclared model gate | Paired fold comparison with hard leakage checks |
| Report publisher | Explain performance and chosen model | Quarto/R Markdown artifact from benchmark tables |

## Recommended Structure

```text
R/
├── evaluation/
│   ├── ledger.R
│   ├── schema.R
│   ├── metrics.R
│   ├── calibration.R
│   └── promotion.R
├── benchmark/
│   ├── folds.R
│   ├── registry.R
│   ├── baselines.R
│   └── tournament_scoring.R
├── forecast/
│   ├── poisson.R
│   ├── dependent_scores.R
│   ├── dynamic_ability.R
│   └── ml_challengers.R
data/processed/
├── forecast_ledger/
└── benchmark_folds/
outputs/model_evaluation/
├── metrics/
├── calibration/
└── report/
```

Keep challenger code under the forecast boundary; keep all selection logic under evaluation/benchmark. The dashboard consumes only an approved versioned prediction contract.

## Architectural Patterns

### Immutable Evaluation Ledger

Each row identifies fixture, kickoff UTC, forecast generation UTC, feature/result cutoff, source commit, model version, seed, and probabilities. A ledger row is valid only when every feature source predates kickoff and the forecast existed before kickoff.

### Common Challenger Adapter

Every model exposes:

```r
fit_model(training_data, config)
predict_score_distribution(model, fixtures, max_goals)
model_manifest(model, config)
```

The harness derives 1X2 and tournament simulations from the score distribution. Models that predict 1X2 directly must be marked as outcome-only and cannot be compared on goal-distribution metrics.

### Nested Temporal Selection

Outer folds assess complete tournaments. Inner time-blocked folds select hyperparameters and calibration. The final WC 2026 fold is evaluated once after the challenger set and promotion rule are frozen.

### Capability-Based Feature Sets

Feature sets are named and nested:

1. `elo_only`
2. `ability` (Elo plus dynamic attack/defence)
3. `open_context` (venue, host, rest, travel, tournament)
4. `structural_prior`
5. `enriched_squad`
6. `market_benchmark`

No model silently replaces missing features with zeros without reporting coverage.

## Data Flows

### WC 2026 Retrospective

```text
Fixture kickoff -> find latest prior git commit -> read forecast artifact
-> validate cutoffs/provenance -> attach canonical final result
-> score -> publish immutable ledger and caveat report
```

### Rolling Benchmark

```text
Fold definition -> build point-in-time features -> fit challenger
-> optional inner calibration -> predict complete tournament
-> simulate tournament -> score match and stage events
-> aggregate paired deltas and uncertainty
```

## Integration Boundaries

| Boundary | Contract |
|----------|----------|
| Data to features | Every value carries a source date or frozen snapshot |
| Features to model | Named feature-set manifest and missingness audit |
| Model to simulator | Normalized finite score-probability matrix summing to one |
| Simulator to evaluator | Fixture and stage event probabilities with stable IDs |
| Evaluator to dashboard | Approved model version only; no evaluation-time branching |

## Build Order

1. Ledger and metric contracts.
2. Rolling folds and baseline reproduction.
3. Regularized and dependent-score challengers.
4. Dynamic ability, RF, and contextual/structural challengers.
5. Calibration, promotion decision, and approved-model integration.

## Sources

- https://rsample.tidymodels.org/articles/Common_Patterns.html
- https://CRAN.R-project.org/package=scoringRules
- https://arxiv.org/abs/1806.03208
- https://arxiv.org/abs/2410.09068
- https://www.zeileis.org/news/fifa2018eval/

---
*Architecture research for: xGelo v2.0*
*Researched: 2026-07-20*
