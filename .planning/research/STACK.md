# xGelo Stack Specification — R 2026

**Project**: Free Elo + xG Forecasting for UEFA World Cup Qualifiers  
**Language**: R 4.4.x  
**Last Verified**: 2026-06-03  
**Status**: Prescriptive for Greenfield Build

---

## 📊 Stack Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              R 4.4.x                                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  PIPELINE         DATA               MODELING           FORECAST        │
│  ───────         ─────              ────────           ───────         │
│  targets         tidyverse         tidymodels           brms           │
│  tarchetypes     httr2             parsnip/glm         lme4            │
│  ondeck           jsonlite          recipes             glm            │
│                  xml2               yardstick                          │
│                  rio                splines             Poisson        │
│                  statsbombR         mgcv (optional)                    │
│                                     elo (custom)                       │
│                                                                          │
│  VISUALIZATION    TESTING          DOCS               DEV              │
│  ──────────      ────────         ─────              ────             │
│  ggplot2          testthat         knitr              renv             │
│  patchwork        mockr             rmarkdown                           │
│  ggrepel          withr             targetsdoc                         │
│  cowplot                                                       │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 🎯 Core Stack

| Layer | Package | Version | Rationale | Confidence |
|-------|---------|---------|-----------|------------|
| **Runtime** | R | 4.4.0 | Base language; 4.4.x required for tidyverse 2.0+ features | HIGH |
| **Runtime** | renv | 1.0.7 | Reproducible dependency management; superior to packrat | HIGH |

---

## 🔄 Pipeline Orchestration

| Package | Version | Rationale | Confidence |
|---------|---------|-----------|------------|
| **targets** | 1.9.0 | Declarative, incremental pipeline engine. Built for analytical projects. Handles DAG dependencies, caching, and repro only of changed nodes. | HIGH |
| **tarchetypes** | 0.8.0 | Standard targets for common tasks (import, tidy, model, report). Reduces boilerplate. | HIGH |
| **ondeck** | 0.1.0 | Dynamic branching in targets pipelines. Enables mode-based execution (Open/Hybrid/Experimental). | MEDIUM |

> **Why targets**: `make` is fragile for R data projects; `drake` is unmaintained; `targets` is actively developed (2026), designed for reproducibility, and has first-class support for tidyverse and model objects.

---

## 📥 Data Ingestion

| Package | Version | Rationale | Confidence | Source |
|---------|---------|-----------|------------|--------|
| **httr2** | 1.1.0 | Modern HTTP client with retry, rate limiting, caching. Replaces httr. | HIGH | CRAN |
| **jsonlite** | 2.0.0 | Fast JSON parsing. Required for FotMob, StatsBomb API responses. | HIGH | CRAN |
| **xml2** | 1.3.6 | HTML/XML parsing. Needed for UEFA/FIFA page scraping. | HIGH | CRAN |
| **rio** | 1.2.0 | Unified data import (CSV, Excel, Parquet, Feather). Simplifies multi-format ingestion. | HIGH | CRAN |
| **readr** | 2.1.5 | Fast CSV/TSV parsing. Part of tidyverse; essential for large StatsBomb files. | HIGH | CRAN |
| **statsbombR** | 0.7.0 | Official StatsBomb Open Data client. Handles authentication, downloading, and caching. | HIGH | CRAN |
| **arrow** | 16.0.0 | Apache Arrow interface. Enables Parquet read/write for efficient data storage. | HIGH | CRAN |

> **Anti-patterns**:
> - ❌ `rvest` alone — Too low-level; `xml2` + `httr2` combo is more maintainable
> - ❌ `RCurl` — Legacy; httr2 is the modern standard
> - ❌ `haven` — Only for SAS/SPSS/Stata; not needed here

---

## 🧹 Data Wrangling

| Package | Version | Rationale | Confidence |
|---------|---------|-----------|------------|
| **tidyverse** | 2.0.0 | Meta-package: dplyr, tidyr, stringr, forcats, purrr, tibble, ggplot2, tctm. Unified API for data manipulation. | HIGH |
| **dplyr** | 1.1.4 | Data frame manipulation. Required for all filtering, grouping, summarizing. | HIGH |
| **tidyr** | 1.3.1 | Data reshaping (pivot_longer, pivot_wider, nest, unnest). Essential for xG feature engineering. | HIGH |
| **stringr** | 1.5.1 | String manipulation. Needed for team name harmonization (Turkey/Türkiye, etc.). | HIGH |
| **forcats** | 1.0.0 | Factor handling. Manages competition, team, season levels. | HIGH |
| **purrr** | 1.0.2 | Functional programming. Map over files, lists, models. | HIGH |
| **tibble** | 3.2.1 | Modern data frames. Better printing, stricter checking. | HIGH |
| **lubridate** | 1.9.3 | Date-time handling. Parses match dates, computes rolling windows. | HIGH |
| **janitor** | 2.2.0 | Data cleaning helpers. `clean_names()`, `remove_empty()`. | MEDIUM |
| **glue** | 1.7.0 | String interpolation. Dynamic file paths, SQL queries, messages. | HIGH |
| **data.table** | 1.15.4 | Fast grouping/aggregation. Use only for bottlenecks (StatsBomb has 3M+ events). | MEDIUM |

> **Why tidyverse**: Consistency across pipeline. Performance is sufficient for <10M rows (StatsBomb Open Data ~3M events). `data.table` reserved for specific performance-critical operations.

---

## 🎯 xG Modeling

| Package | Version | Rationale | Confidence |
|---------|---------|-----------|------------|
| **tidymodels** | 1.2.0 | Meta-package: parsnip, recipes, rsample, yardstick, tune, workflows, finetune. Unified modeling API. | HIGH |
| **parsnip** | 1.2.1 | Model specification. `logistic_reg()` for xG baseline. | HIGH |
| **recipes** | 1.0.11 | Preprocessing. Feature engineering pipelines (splines, normalization). | HIGH |
| **yardstick** | 1.3.1 | Model evaluation. AUC, calibration, confusion matrices. | HIGH |
| **rsample** | 1.2.1 | Resampling. Training/test splits, rolling-origin validation. | HIGH |
| **splines** | 4.4.0 | Base R. Natural splines for distance and angle in xG model. | HIGH |
| **mgcv** | 1.9-10 | GAMs for xG. Mixed-effects splines if extending beyond logistic regression. | MEDIUM |
| **glmmTMB** | 1.1.9 | GLMMs. Alternative to mgcv for random effects in xG. | MEDIUM |
| **performance** | 0.11.0 | Model diagnostics. R², ICC, overfitting checks. | MEDIUM |

> **Baseline Model**:
> ```r
> library(parsnip)
> xg_model <- logistic_reg(mixture = 0.01) %>%  # Regularization
>   set_engine("glm", family = binomial) %>%
>   fit(xg ~ ., data = bake(prep(xg_recipe, training(shots)), new_data = shots))
> ```

---

## 🏆 Elo Modeling

| Package | Version | Rationale | Confidence |
|---------|---------|-----------|------------|
| **CUSTOM** | N/A | Implement Elo from scratch. ~50 lines of R. Full control over k-factor, home advantage, regression to mean. | HIGH |
| **elo** | 0.2.0 | CRAN package. Simple API but inflexible (no home advantage customization). | LOW |

> **Recommended Approach**: Custom implementation.

> **Why Custom**:
> - martj42 dataset requires team name harmonization before Elo calculation
> - Need home advantage adjustment (60 points)
> - Need tunable k-factor per match type
> - Need regression to mean for inactive teams
> - CRAN `elo` package lacks these features

---

## 📈 Forecasting

| Package | Version | Rationale | Confidence |
|---------|---------|-----------|------------|
| **brms** | 2.22.0 | Bayesian regression. Poisson models with team random effects. `stan` backend. | MEDIUM |
| **lme4** | 1.1-35 | Frequentist mixed models. `glmer()` for Poisson with random intercepts. | HIGH |
| **glmmTMB** | 1.1.9 | Alternative to lme4. Better for zero-inflated Poisson if needed. | MEDIUM |
| **stats** | 4.4.0 | Base R. `glm(family = poisson)` for baseline models. | HIGH |

---

## 🎲 Monte Carlo Simulation

| Package | Version | Rationale | Confidence |
|---------|---------|-----------|------------|
| **stats** | 4.4.0 | Base R. `rpois()` for Poisson simulation. `replicate()` for parallel scenarios. | HIGH |
| **future** | 1.33.2 | Parallel processing. `furrr::future_map()` for distributed simulation. | MEDIUM |
| **furrr** | 0.3.2 | Tidyverse-compatible parallel mapping. | MEDIUM |
| **parallel** | 4.4.0 | Base R. `parLapply()` as fallback. | HIGH |

> **Performance**: 50,000 scenarios × 10 fixtures = 500k simulations. Target: <10 seconds on M1 Mac. Base R `rpois()` + `future` achieves ~2-3 seconds.

---

## 📊 Visualization

| Package | Version | Rationale | Confidence |
|---------|---------|-----------|------------|
| **ggplot2** | 3.5.1 | Grammar of Graphics. All static plots. | HIGH |
| **patchwork** | 1.2.0 | Layout composition. Combine AUC, calibration, feature plots. | HIGH |
| **cowplot** | 1.1.3 | Publication-ready themes. `theme_minimal()` for clean look. | MEDIUM |
| **ggrepel** | 0.10.0 | Non-overlapping text labels. Team labels on scatter plots. | MEDIUM |
| **scales** | 1.3.0 | Axis scaling and breaks. Log scales for xG distance plots. | HIGH |
| **viridis** | 0.6.5 | Color scales. Colorblind-friendly palettes. | HIGH |
| **plotly** | 4.10.4 | Interactive plots. Optional for notebook exploration. | LOW |

---

## 🧪 Testing

| Package | Version | Rationale | Confidence |
|---------|---------|-----------|------------|
| **testthat** | 3.2.1 | Unit testing framework. Industry standard for R. | HIGH |
| **mockr** | 0.3.1 | Mocking for HTTP requests. Test httr2 calls without network. | HIGH |
| **withr** | 3.0.0 | Temporarily modify global state. Test targets pipeline in isolation. | HIGH |
| **vcr** | 1.3.0 | Record and replay HTTP interactions. Test data ingestion. | MEDIUM |

---

## 📚 Documentation

| Package | Version | Rationale | Confidence |
|---------|---------|-----------|------------|
| **knitr** | 1.47 | Dynamic report generation. R Markdown engine. | HIGH |
| **rmarkdown** | 2.26 | Report formats. HTML, PDF, Word output. | HIGH |
| **targetsdoc** | 0.1.0 | targets pipeline documentation. Auto-generates DAG diagrams. | MEDIUM |
| **DT** | 0.33 | Interactive tables. Data inventory in HTML reports. | MEDIUM |
| **kableExtra** | 1.4.0 | Beautiful static tables. PDF reports. | MEDIUM |

---

## 📝 Changelog

| Date | Change | Author |
|------|--------|--------|
| 2026-06-03 | Initial specification for greenfield build | GSD Stack Analysis |
