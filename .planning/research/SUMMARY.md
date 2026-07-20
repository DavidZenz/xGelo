# Project Research Summary

**Project:** xGelo
**Domain:** International-football probabilistic forecasting
**Researched:** 2026-07-20
**Confidence:** HIGH

## Executive Summary

xGelo v2.0 should be an evaluation-led model evolution milestone. The first deliverable is not a new algorithm: it is a provably pre-kickoff WC 2026 ledger and a shared probabilistic scoring contract. Existing hourly git snapshots make an honest reconstruction possible despite the current dashboard archive containing rows first written after kickoff.

After that foundation, the project should compare representative model families on complete rolling tournament folds. The strongest literature pattern is to combine an independently estimated ability signal with regularized count models or tree learners, then simulate the tournament. The current negative-binomial model remains the incumbent, but its 26 correlated, unpenalized predictors and inactive xG/form inputs justify explicit simpler and better-regularized challengers.

The final WC 2026 results must remain untouched during feature selection, tuning, and calibration. Model promotion should require lower proper scores across several prior tournament folds, acceptable calibration, stable leave-one-tournament-out behavior, and no licensing regression in the default open mode.

## Key Findings

### Recommended Stack

- Keep R, targets, yardstick, MASS, and testthat as the stable core.
- Add scoringRules for proper distribution scoring and rsample's sliding methods for temporal folds.
- Add glmnet for the first regularized Poisson challenger.
- Add bivpois for an explicit score-dependence challenger.
- Add ranger for the Groll-style RF plus ability model; defer XGBoost until RF establishes nonlinear value.
- Add probably only when out-of-fold calibration is ready.

### Must-Have Features

- Git-derived pre-kickoff forecast ledger with provenance and rejection reasons.
- Match and tournament-event proper scores, calibration, and uncertainty.
- Shared rolling tournament folds and a common model adapter.
- Elo-only and incumbent NB baselines.
- Regularized Poisson, dependent-score, and RF-plus-ability challengers.
- Frozen promotion rule and one-time final WC 2026 evaluation.

### Architecture

The new evaluation layer sits between point-in-time feature construction and dashboard publication. Models emit a normalized score-distribution contract; the same code derives 1X2 probabilities, tournament simulations, and metrics. The dashboard reads only the explicitly promoted model version, so challenger work cannot silently change published behavior.

### Critical Pitfalls

1. Post-kickoff snapshots mislabeled as prematch.
2. Tuning or calibrating on WC 2026.
3. Match-level random cross-validation.
4. Model comparisons with different cutoffs or fixtures.
5. Correlated squad features without shrinkage.
6. Claiming xG influence when xG predictors are inactive.
7. Selecting a winner from one noisy tournament.

## Implications for Roadmap

### Phase 8: Forecast Ledger and WC 2026 Retrospective
**Delivers:** Reconstructed pre-kickoff ledger, provenance manifest, exploratory and strict scorecards.
**Rationale:** Every later decision depends on trustworthy evaluation data.

### Phase 9: Rolling Tournament Benchmark Harness
**Delivers:** Fold registry, model/prediction schema, proper metrics, baseline reproduction, and frozen promotion protocol.
**Rationale:** Prevents WC 2026 tuning and makes challengers comparable.

### Phase 10: Statistical Goal-Model Challengers
**Delivers:** Regularized Poisson, dynamic attack/defence ability, and Dixon-Coles/bivariate-Poisson comparisons.
**Rationale:** Tests the best-supported interpretable improvements before black-box models.

### Phase 11: Hybrid ML and Contextual Priors
**Delivers:** RF-plus-ability model, controlled open context, structural sparse-team prior, and optional enriched squad/market benchmarks.
**Rationale:** Adds nonlinear and external information only after stable statistical baselines exist.

### Phase 12: Calibration, Promotion, and Model Release
**Delivers:** Out-of-fold calibration, paired fold comparison, one-time 2026 final evaluation, approved model artifact, model card, and dashboard integration.
**Rationale:** Separates model invention from the release decision.

### Ordering Rationale

- Ledger precedes scoring; scoring precedes challengers; challengers precede calibration and promotion.
- Statistical challengers come before ML to establish whether complexity is necessary.
- Structural and market signals are isolated so the open-data model remains identifiable.
- WC 2026 remains sealed until all candidates and gates are fixed.

### Research Flags

- **Phase 8:** Verify timezone and git-commit selection semantics carefully.
- **Phase 10:** Decide whether Dixon-Coles or bivariate Poisson is the primary dependence implementation after a small empirical spike.
- **Phase 11:** Reproduce the Groll response/ability construction faithfully before adding XGBoost.
- **Phase 12:** Predeclare practical improvement thresholds and uncertainty method.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Existing R ecosystem plus official package documentation |
| Features | HIGH | Directly tied to observed archive/model gaps and established forecast practice |
| Architecture | HIGH | Matches current targets separation and literature workflow |
| Pitfalls | HIGH | Most are already observable in current artifacts |

**Overall confidence:** HIGH

### Gaps

- Exact historical tournament coverage and point-in-time squad availability require an inventory in Phase 9.
- The best dependence correction is empirical; both Dixon-Coles and bivariate Poisson should share one short spike.
- Bookmaker and structural benchmarks require vintage-data provenance to be considered fully comparable.

## Sources

### Primary

- https://arxiv.org/abs/1806.03208
- https://epub.ub.uni-muenchen.de/31579/1/Groll_Prediction.pdf
- https://portal.fis.tum.de/de/publications/on-the-dependency-of-soccer-scores-a-sparse-bivariate-poisson-mod/
- https://arxiv.org/abs/2410.09068
- https://www2.uibk.ac.at/downloads/c4041030/wpaper/2016-15.pdf
- https://rsample.tidymodels.org/articles/Common_Patterns.html
- https://CRAN.R-project.org/package=scoringRules
- https://CRAN.R-project.org/package=glmnet
- https://CRAN.R-project.org/package=bivpois

### Project Evidence

- `outputs/dashboard/worldcup_prematch_forecasts.csv`
- `outputs/dashboard/worldcup_bracket_prematch_forecasts.csv`
- `data/processed/xg_feature_usage_audit.csv`
- `R/forecast/poisson.R`
- `.planning/phases/999.1-socio-economic-structural-benchmark/RESEARCH.md`

---
*Research completed: 2026-07-20*
*Ready for roadmap: yes*
