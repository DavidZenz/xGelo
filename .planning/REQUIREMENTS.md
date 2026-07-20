# Requirements: xGelo v2.0

**Defined:** 2026-07-20
**Core Value:** Accurate, calibrated international-football forecasting without dependence on paid data feeds.

## v2.0 Requirements

### Forecast Integrity

- [x] **LEDGER-01**: The analyst can reconstruct the latest committed forecast that existed before each 2026 World Cup kickoff.
- [x] **LEDGER-02**: Every reconstructed forecast records kickoff time, generation time, feature and result cutoffs, source commit, model version, and provenance.
- [x] **LEDGER-03**: Forecasts that violate timing or provenance rules are rejected with a machine-readable reason.
- [x] **EVAL-01**: The analyst can score 1X2 probabilities, goal distributions, totals, both-teams-to-score, and exact-score forecasts with documented metrics.
- [x] **EVAL-02**: The analyst can score knockout advancement and tournament-stage reach probabilities against actual outcomes.
- [x] **EVAL-03**: The retrospective reports calibration and uncertainty by stage, outcome class, and confidence, with strict and exploratory samples clearly separated.

### Benchmarking

- [ ] **BENCH-01**: The analyst can run deterministic tournament-blocked World Cup and Euro evaluation folds using only information available before each assessed match.
- [ ] **BENCH-02**: The benchmark prevents 2026 World Cup outcomes from entering model fitting, feature selection, tuning, or calibration before the final sealed evaluation.
- [ ] **BENCH-03**: Every candidate uses a common prediction schema, point-in-time feature contract, model manifest, and feature-coverage audit.
- [ ] **BENCH-04**: The benchmark includes naive, Elo-only, and incumbent negative-binomial baselines on identical fixtures and folds.
- [ ] **BENCH-05**: Candidates are compared with shared seeds, paired tournament-fold deltas, uncertainty estimates, and a predeclared promotion rule.

### Statistical Challengers

- [ ] **STAT-01**: The analyst can benchmark a team-specific penalized Poisson model against the registered baselines.
- [ ] **STAT-02**: The analyst can benchmark dynamic attack and defence ratings whose updates use only prior matches.
- [ ] **STAT-03**: The analyst can compare Dixon-Coles and bivariate-Poisson score-dependence corrections under the common benchmark contract.
- [ ] **STAT-04**: The analyst can run controlled ablations of the incumbent model's correlated predictors and identify each retained feature set.

### Hybrid Models and Features

- [ ] **HYBRID-01**: The analyst can benchmark a Groll-style random forest that includes independently estimated team-ability parameters.
- [ ] **HYBRID-02**: The analyst can evaluate host, neutral venue, rest, travel, and tournament-context features as a named open-data feature set.
- [ ] **HYBRID-03**: The benchmark reports xG coverage and activates an xG-informed candidate only when its point-in-time signal passes a declared coverage gate.
- [ ] **HYBRID-04**: The analyst can evaluate socio-economic variables as a structural prior for teams with sparse recent match evidence.
- [ ] **HYBRID-05**: Squad information and bookmaker consensus are evaluated only in explicitly labelled enriched or external benchmark modes.

### Calibration and Release

- [ ] **CAL-01**: The analyst can train probability calibration using inner out-of-fold predictions without using the outer assessment tournament.
- [ ] **CAL-02**: The benchmark compares raw and calibrated probabilities with the same proper scores and reports any discrimination or calibration regression.
- [ ] **PROMO-01**: Candidate models, settings, feature sets, and promotion thresholds are frozen before the final 2026 World Cup evaluation is opened.
- [ ] **PROMO-02**: The analyst can execute the final 2026 comparison once and retain the incumbent unless a challenger satisfies the promotion rule.
- [ ] **PROMO-03**: The approved model is published as a versioned artifact with a model card, benchmark report, and dashboard regression tests.

## Future Requirements

### Additional Challengers

- **FUTURE-01**: Benchmark XGBoost after the random-forest challenger demonstrates stable nonlinear value.
- **FUTURE-02**: Add sequence-aware or neural event models when point-in-time international event coverage supports them.
- **FUTURE-03**: Add richer player-availability signals when a legal, reproducible historical source exists.
- **FUTURE-04**: Provide continuous live forecast evaluation after immutable batch evaluation is proven.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Tuning against WC 2026 outcomes | The completed tournament is the final holdout, not development data |
| Automated bookmaker, FotMob, or Transfermarkt scraping | Conflicts with licensing, terms, or the open-data-first operating mode |
| Paid data as a default model dependency | Violates the project's core value |
| Deep model zoo | Representative model families provide more decision value than exhaustive implementation |
| Betting recommendations or staking | xGelo evaluates forecasts; it is not a commercial betting product |

## Traceability

Each active v2.0 requirement maps to exactly one roadmap phase.

| Requirement | Phase | Status |
|-------------|-------|--------|
| LEDGER-01 | 8 | Complete |
| LEDGER-02 | 8 | Complete |
| LEDGER-03 | 8 | Complete |
| EVAL-01 | 8 | Complete |
| EVAL-02 | 8 | Complete |
| EVAL-03 | 8 | Complete |
| BENCH-01 | 9 | Pending |
| BENCH-02 | 9 | Pending |
| BENCH-03 | 9 | Pending |
| BENCH-04 | 9 | Pending |
| BENCH-05 | 9 | Pending |
| STAT-01 | 10 | Pending |
| STAT-02 | 10 | Pending |
| STAT-03 | 10 | Pending |
| STAT-04 | 10 | Pending |
| HYBRID-01 | 11 | Pending |
| HYBRID-02 | 11 | Pending |
| HYBRID-03 | 11 | Pending |
| HYBRID-04 | 11 | Pending |
| HYBRID-05 | 11 | Pending |
| CAL-01 | 12 | Pending |
| CAL-02 | 12 | Pending |
| PROMO-01 | 12 | Pending |
| PROMO-02 | 12 | Pending |
| PROMO-03 | 12 | Pending |

**Coverage:**
- v2.0 requirements: 25 total
- Mapped to phases: 25
- Unmapped: 0

---
*Requirements defined: 2026-07-20*
*Last updated: 2026-07-20 after roadmap mapping*
