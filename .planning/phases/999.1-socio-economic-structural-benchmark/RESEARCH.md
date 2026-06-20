# Structural and Tournament Forecast Benchmarks

## Scope

This note captures literature for a future xGelo benchmark/enhancement that compares the existing Elo + xG forecast stack against macro-structural models, bookmaker-consensus models, Poisson/ranking models, and hybrid machine-learning tournament simulators.

## Main Branches

### 1. Macro-structural country strength

- Hoffmann, Ging, and Ramasamy (2002) model international football performance using FIFA ranking points as the outcome.
- Key variables: GNP/GDP per capita, squared GNP/GDP per capita, squared distance from 14 C average capital-city temperature, prior World Cup host status, and Latin cultural origin x population share.
- Joachim Klement's 2026 World Cup model explicitly cites Hoffmann/Ging/Ramasamy as its root, adds current FIFA ranking points, simulates tournament progression, and reports explaining roughly 55% of cross-country World Cup success variation.
- Use in xGelo: structural-only benchmark, plus optional shrinkage prior for low-sample national teams.

### 2. Bookmaker-consensus ability models

- Leitner, Zeileis, and Hornik (2010a) introduce tournament forecasting from estimated team abilities derived from market-implied probabilities.
- Zeileis, Leitner, and Hornik apply this family to EURO 2012, World Cup 2014, EURO 2016, and World Cup 2018.
- The 2018 World Cup version aggregates quoted odds from 26 bookmakers/exchanges, adjusts overrounds, averages on the log-odds scale, then uses inverse tournament simulation to recover team abilities and pairwise win probabilities.
- Use in xGelo: strong external benchmark if odds are allowed as a comparison input; keep separate from open-data model features.

### 3. Goal-model and ranking lineage

- Maher (1982), Dixon and Coles (1997), Dyte and Clarke (2000), Karlis and Ntzoufras (2003), and McHale/Scarf variants provide the older count-model foundation: independent Poisson, low-score dependence adjustment, ratings-based Poisson, bivariate Poisson, and broader dependence structures.
- Groll and Abedieh (2013) use generalized linear mixed models for EURO 2012.
- Groll, Schauberger, and Tutz (2015) use team-specific regularized Poisson regression for World Cup 2014, selecting sparse covariates when the predictive value of inputs is unclear.
- Groll, Kneib, Mayr, and Schauberger (2018) test sparse bivariate Poisson models for EURO 2016 and find that rich covariates can make an explicit bivariate dependency parameter unnecessary.
- Gilch and Mueller (2018) combine Elo covariates with Poisson regression and team-specific effects for World Cup 2018, validating stage predictions with ordinal/rank probability scores.
- Use in xGelo: improve or benchmark the existing negative-binomial forecast layer; add formal stage/tournament scoring for simulations.

### 4. Hybrid machine-learning tournament simulators

- Groll, Ley, Schauberger, and Van Eetvelde (2018) compare Poisson regressions, random forests, and ranking methods on World Cups 2002-2014.
- Their best model combines random forests with Poisson-ranking ability parameters estimated from recent national-team matches. For World Cup 2018, abilities are estimated using more than 7,000 matches from 228 national teams since 2010-06-13, then the tournament is simulated 100,000 times.
- Important finding for xGelo: ability estimates are by far the most important random-forest predictor, ahead of FIFA rank, bookmaker odds, GDP, squad variables, and confederation variables.
- Successor models apply the same hybrid idea to the 2019 Women's World Cup, EURO 2020, and EURO 2024; the 2024 version combines GLM, random forest, and XGBoost with historic-match, bookmaker-consensus, and player-rating ability variables.
- Use in xGelo: candidate v2 benchmark, especially if we want to compare interpretable Elo/xG forecasts against RF/XGBoost expected-goals simulators.

## Candidate xGelo Benchmark Design

1. Structural baseline: estimate country/team strength from GDP per capita, population share, climate, host/continent flags, FIFA rank or Elo, and optional culture/history proxies.
2. Ability baseline: use current xGelo Elo as the open-data ability parameter, then test whether a Poisson-ranking ability model adds value.
3. Count-model baseline: independent Poisson or negative-binomial goals using Elo/xG form features.
4. Hybrid ML baseline: random forest or XGBoost goal model with Elo ability, xG form, structural variables, squad/coach variables if available, and tournament-context flags.
5. Evaluation: match-level log loss/Brier/RPS plus tournament-stage calibration from repeated simulations.

## Implementation Notes

- Keep bookmaker odds as an external benchmark, not a training feature, unless the project adds a market-informed mode.
- Avoid leakage: tournament covariates must be frozen before the tournament or match kickoff.
- Prefer open-data substitutes for squad quality: club confederation, club Elo/market value only if licensing is clean, minutes/lineups only when available without scraping restrictions.
- Treat macro variables as slow-moving priors rather than match-level tactical predictors.

## Sources Reviewed

- Hoffmann, R., L. C. Ging, and B. Ramasamy (2002). "The Socio-Economic Determinants of International Soccer Performance." Journal of Applied Economics, 5(2), 253-272.
- Klement, J. (2026). "FIFA World Cup Predictions 2026." Panmure Liberum strategy note.
- Groll, A., C. Ley, G. Schauberger, and H. Van Eetvelde (2018). "Prediction of the FIFA World Cup 2018 - A random forest approach with an emphasis on estimated team ability parameters." arXiv:1806.03208.
- Groll, A. and J. Abedieh (2013). "Spain retains its title and sets a new record - generalized linear mixed models on European football championships." Journal of Quantitative Analysis in Sports, 9, 51-66.
- Groll, A., G. Schauberger, and G. Tutz (2015). "Prediction of major international soccer tournaments based on team-specific regularized Poisson regression: an application to the FIFA World Cup 2014." Journal of Quantitative Analysis in Sports, 11, 97-115.
- Groll, A., T. Kneib, A. Mayr, and G. Schauberger (2018). "On the dependency of soccer scores - A sparse bivariate Poisson model for the UEFA European Football Championship 2016." Statistical Modelling.
- Zeileis, A., C. Leitner, and K. Hornik (2016). "Predictive Bookmaker Consensus Model for the UEFA Euro 2016." Working Papers 2016-15, University of Innsbruck.
- Zeileis, A., C. Leitner, and K. Hornik (2018). "Probabilistic forecasts for the 2018 FIFA World Cup based on the bookmaker consensus model." Working Paper 2018-09, University of Innsbruck.
- Gilch, L. A. and S. Mueller (2018). "On Elo based prediction models for the FIFA Worldcup 2018." arXiv:1806.01930.
- Groll, A., L. M. Hvattum, C. Ley, J. Sternemann, G. Schauberger, and A. Zeileis (2024). "Modeling and Prediction of the UEFA EURO 2024 via Combined Statistical Learning Approaches." arXiv:2410.09068.
