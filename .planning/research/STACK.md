# Stack Research

**Domain:** International-football probabilistic forecast evaluation and model comparison
**Researched:** 2026-07-20
**Confidence:** HIGH

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| R | Project runtime | Model fitting, scoring, simulation, reports | Keeps the existing production and test surface intact |
| targets | 1.12.0 installed | Reproducible benchmark DAG | Already owns project orchestration and cache invalidation |
| rsample | 1.3.2 installed | Time-ordered tournament folds | `sliding_period()` and related methods avoid random temporal leakage |
| yardstick | 1.4.0 installed | Standard classification metrics | Fits the existing tidymodels conventions |
| testthat | 3.3.2 installed | Contracts and regression tests | Existing project test framework |

### Challenger and Evaluation Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| scoringRules | 1.1.3 | Log score, RPS, CRPS, count-distribution scores | Canonical evaluator for probabilistic and simulated forecasts |
| glmnet | Current CRAN | Penalized Poisson regression | Groll-style Lasso/ridge challenger and correlated-feature shrinkage |
| bivpois | 1.2 | Bivariate Poisson distribution/regression | Explicit score-dependence challenger |
| ranger | Current CRAN | Fast random forest | Reproduce the Groll hybrid RF benchmark before boosting |
| xgboost | 3.3.x | Gradient-boosted count challenger | Add only after the RF and statistical baselines are stable |
| probably | 1.2.x | Multiclass calibration diagnostics/remediation | Fit calibrators within training folds only |
| MASS | 7.3-65 installed | Existing negative-binomial baseline | Preserve for exact current-model reproduction |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Git object history | Reconstruct last committed forecast before kickoff | Read with `git log`/`git show`; never rewrite historical commits |
| CSV plus manifest | Human-readable immutable forecast ledger | Include commit, code version, cutoff, generation time, and provenance |
| Quarto/R Markdown | Reproducible retrospective report | Use generated tables/figures, not manually transcribed metrics |

## Installation Strategy

Do not install the entire challenger stack at milestone initialization. Each model phase adds only its required dependency and records it in the project dependency lock.

```r
install.packages(c("scoringRules", "glmnet", "bivpois", "ranger", "probably"))
# Add xgboost only when the boosting challenger is approved.
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| `glmnet` Poisson | Custom tailored Lasso | Only if the published team-effect penalty cannot be represented faithfully |
| `bivpois` | Dixon-Coles likelihood | Prefer Dixon-Coles when low-score correction wins on rolling folds |
| `ranger` | XGBoost | Use XGBoost after RF establishes whether nonlinear interactions add value |
| CSV ledger plus manifest | Parquet/Arrow | Move to Arrow only if forecast/fold volume becomes a real bottleneck |
| `probably` calibration | Hand-coded calibration | Hand code only for a method absent from probably and cover it with simulation tests |

## What Not to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Random match-level cross-validation | Leaks future team strength and tournament context | Tournament- or date-blocked rolling folds |
| A single all-feature model | Hides which information source adds value | Nested, named feature sets and ablations |
| Unpenalized 20+ correlated squad variables | Unstable coefficients and optimistic holdout selection | Penalization, grouped features, or trees |
| 2026 metrics for tuning | Converts the final holdout into training data | Freeze 2026; tune on earlier folds |
| Market odds in the default open model | Changes the product into a market-informed forecast | External benchmark or explicit optional mode |

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| rsample 1.3.2 | tidymodels 1.5.x | Prefer `sliding_period()`; `rolling_origin()` is superseded |
| probably 1.2.x | yardstick 1.4.x | Supports multinomial, beta, and isotonic calibration |
| xgboost 3.3.x | macOS CPU | Official docs note OpenMP is needed for multithreaded macOS builds |
| MASS 7.3-65 | Existing model RDS files | Retain to reproduce the shipped NB baseline |

## Sources

- https://rsample.tidymodels.org/reference/rolling_origin.html
- https://www.tidymodels.org/learn/models/calibration/
- https://CRAN.R-project.org/package=scoringRules
- https://CRAN.R-project.org/package=glmnet
- https://CRAN.R-project.org/package=bivpois
- https://xgboost.readthedocs.io/en/stable/R-package/index.html
- https://arxiv.org/abs/1806.03208
- https://arxiv.org/abs/2410.09068

---
*Stack research for: xGelo v2.0*
*Researched: 2026-07-20*
