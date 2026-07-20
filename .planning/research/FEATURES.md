# Feature Research

**Domain:** Post-tournament football forecast evaluation and model evolution
**Researched:** 2026-07-20
**Confidence:** HIGH

## Feature Landscape

### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Pre-kickoff forecast ledger | A retrospective is invalid without proof of information timing | HIGH | Select the latest committed snapshot before each kickoff |
| Proper match-level scores | Accuracy alone rewards bad probabilities | MEDIUM | Brier, log loss, RPS, goal CRPS/log score, calibration |
| Tournament-stage scores | Tournament models predict paths as well as matches | MEDIUM | Score advancement and stage reach as probabilistic events |
| Rolling tournament folds | One tournament is too noisy for model selection | HIGH | Train on past data, assess on a later complete tournament |
| Named model/feature registry | Comparisons must be reproducible and auditable | MEDIUM | Same fixtures, folds, seeds, and metric definitions |
| Promotion gate | Complexity needs a predeclared acceptance rule | MEDIUM | Paired fold deltas and no material calibration regression |

### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Git-derived 2026 reconstruction | Recovers an operationally honest tournament record | HIGH | Existing hourly commits make this unusually feasible |
| Dynamic attack/defence ability | Separates scoring and prevention from one-dimensional Elo | HIGH | Update strictly after each match |
| Hybrid RF plus ability parameters | Direct benchmark to Groll et al. 2018 | HIGH | Ability is an input, not replaced by covariates |
| Structural sparse-team prior | Stabilizes countries with little recent match evidence | MEDIUM | Hoffmann/Klement variables act as shrinkage only |
| Open vs enriched operating modes | Preserves the core promise while testing squad/market value | MEDIUM | Report feature provenance and licensing per model |
| Calibration layer | Improves probabilities without changing rankings | MEDIUM | Fit within rolling training folds, never on 2026 |

### Anti-Features

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Tune until WC 2026 improves | Produces a satisfying postmortem | Destroys the only final holdout | Freeze 2026 and improve earlier-fold aggregate results |
| Include every literature model | Feels comprehensive | Creates a model zoo without decision value | Representative challengers by model family |
| Optimize exact-score hit rate | Easy to explain | Modal score accuracy is not a proper probabilistic objective | Score the full score distribution |
| Promote on average accuracy | Familiar headline | Ignores confidence and class imbalance | Proper scores plus calibration |
| Automatic bookmaker ingestion | Strong external signal | Licensing, reproducibility, and product-identity problems | Manually frozen external benchmark |

## Dependencies

```text
Pre-kickoff ledger
    -> 2026 retrospective
    -> immutable benchmark contract
        -> rolling tournament folds
            -> statistical challengers
            -> machine-learning challengers
            -> calibration
                -> promotion decision

Structural prior -> challenger feature sets
Bookmaker consensus -> external benchmark only
```

## Milestone Scope

### Must Have

- [ ] Reconstruct and validate all available WC 2026 prematch forecasts.
- [ ] Score 1X2, goals, totals, both-teams-to-score, knockout advancement, and stage reach.
- [ ] Build multi-tournament rolling folds and simple Elo/current-model baselines.
- [ ] Implement regularized Poisson and score-dependence challengers.
- [ ] Implement the RF-plus-ability challenger and a controlled context/structural feature set.
- [ ] Calibrate, compare, and publish a model promotion decision.

### Add Only After Core Validation

- [ ] XGBoost goal challenger - only if RF shows stable nonlinear gains.
- [ ] Dynamic xG attack/defence updates - only after international xG coverage is nonzero and audited.
- [ ] Rich player availability - only with a legal, point-in-time source.

### Future

- [ ] Live forecast evaluation service.
- [ ] Automated bookmaker collection.
- [ ] Deep sequence or neural models.

## Prioritization

| Feature | User Value | Cost | Priority |
|---------|------------|------|----------|
| Forecast ledger | HIGH | HIGH | P1 |
| Proper scoring report | HIGH | MEDIUM | P1 |
| Rolling folds | HIGH | HIGH | P1 |
| Regularized/dependent count models | HIGH | MEDIUM | P1 |
| RF plus ability | HIGH | HIGH | P1 |
| Structural prior | MEDIUM | MEDIUM | P2 |
| Post-hoc calibration | HIGH | MEDIUM | P2 |
| XGBoost | MEDIUM | HIGH | P3 |

## Sources

- https://arxiv.org/abs/1806.03208
- https://epub.ub.uni-muenchen.de/31579/1/Groll_Prediction.pdf
- https://portal.fis.tum.de/de/publications/on-the-dependency-of-soccer-scores-a-sparse-bivariate-poisson-mod/
- https://arxiv.org/abs/2410.09068
- https://www.zeileis.org/news/fifa2018eval/
- https://CRAN.R-project.org/package=scoringRules

---
*Feature research for: xGelo v2.0*
*Researched: 2026-07-20*
