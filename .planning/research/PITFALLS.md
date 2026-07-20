# Pitfalls Research

**Domain:** International-football forecast retrospective and model selection
**Researched:** 2026-07-20
**Confidence:** HIGH

## Critical Pitfalls

### 1. Calling a Post-Kickoff Snapshot Prematch

**What goes wrong:** Forecast metrics look valid although the artifact did not exist before kickoff.

**Avoidance:** Reconstruct from git commit time, convert local kickoff to UTC, require `generated_at < kickoff`, and retain rejected rows with reasons.

**Warning signs:** Forecast timestamps after kickoff, same-day result cutoffs, or no commit provenance.

**Phase:** Forecast ledger and 2026 retrospective.

### 2. Tuning on the 2026 Holdout

**What goes wrong:** Model changes are selected because they explain the tournament just observed.

**Avoidance:** Freeze 2026 results outside all fitting, feature selection, hyperparameter, and calibration decisions until the challenger protocol is locked.

**Warning signs:** A feature is justified only by its WC 2026 delta or repeated peeking changes the candidate list.

**Phase:** Benchmark contract and promotion gate.

### 3. Match-Level Random Cross-Validation

**What goes wrong:** Later team strength, squad context, and tournament form leak into earlier assessments.

**Avoidance:** Use date- and tournament-blocked outer folds with point-in-time feature construction.

**Warning signs:** The same tournament appears in train and test or feature dates are not checked.

**Phase:** Rolling tournament harness.

### 4. Comparing Models on Different Inputs

**What goes wrong:** A challenger wins because it saw newer ratings, different fixtures, or extra result information.

**Avoidance:** Share fold IDs, fixture rows, source snapshots, seeds, and metric code. Store a manifest for every run.

**Warning signs:** Row counts differ, model-specific preprocessing changes actuals, or result cutoffs are absent.

**Phase:** Model registry and benchmark harness.

### 5. Overfitting Correlated Squad Features

**What goes wrong:** Coefficients become unstable and apparent gains fail on the next tournament.

**Avoidance:** Penalize, group, or ablate related variables; compare against Elo/ability baselines on paired folds.

**Warning signs:** Large coefficient sign changes, singular fits, or gains concentrated in one tournament.

**Phase:** Statistical and ML challengers.

### 6. Treating Inactive xG as Real Signal

**What goes wrong:** The model is described as xG-informed while forecast-time xG features are zeros.

**Avoidance:** Make feature activation and coverage hard gates. Label model variants by actual retained predictors.

**Warning signs:** Zero variance, zero team coverage, or missing values silently replaced with neutral zero.

**Phase:** Feature audit and challenger registry.

### 7. Overfitting Calibration

**What goes wrong:** A flexible calibrator improves the same data used to fit it and worsens future probabilities.

**Avoidance:** Fit calibration only on inner out-of-fold predictions, compare uncalibrated/calibrated variants, and retain a no-calibration option.

**Warning signs:** Large 2026-only improvement, probabilities collapse to few values, or ranking changes unexpectedly.

**Phase:** Calibration and promotion.

### 8. One Tournament as the Decision Unit

**What goes wrong:** A handful of upsets determine the model choice.

**Avoidance:** Report paired tournament-fold deltas, dispersion, and bootstrap intervals; require directionally consistent evidence.

**Warning signs:** Aggregate improvement disappears when one tournament is removed.

**Phase:** Evaluation report and promotion.

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | Acceptable |
|----------|-------------------|----------------|------------|
| Reuse dashboard CSV as benchmark truth | Fast scorecard | Archive semantics are operational, not evaluative | Only for clearly labeled exploratory metrics |
| Add all challengers to one script | Quick prototype | Unreproducible branching and inconsistent schemas | Never beyond a spike |
| Hard-code tournament rules in metrics | Easy WC 2026 report | Cannot roll across formats | Only behind versioned format adapters |
| Default missing features to zero | Models keep running | Silent model identity change | Only with explicit neutral semantics and audit |

## Licensing and Provenance Gotchas

| Source | Mistake | Correct Approach |
|--------|---------|------------------|
| Transfermarkt | Treat values as open redistributable data | Optional local enriched mode; publish derived metadata only |
| Bookmakers | Scrape/retrain without provenance | Frozen external benchmark with source/date documentation |
| FotMob | Automate collection | Manual cache only under existing project policy |
| Socio-economic data | Use current revised values for old folds | Vintage or pre-tournament snapshot per fold |

## Performance Traps

| Trap | Symptoms | Prevention |
|------|----------|------------|
| Refit every model for every fixture | Very long benchmark | Fit once per fold; vectorize predictions |
| Simulate before match metrics pass | Slow debugging | Validate analytic score matrices first |
| Million-run simulations for every candidate | Cost dominates model fitting | Use deterministic analytic metrics and common random numbers; increase sims for finalists |

## Looks Done But Is Not

- [ ] Every ledger row proves forecast time precedes kickoff.
- [ ] Every feature source date precedes the fixture.
- [ ] Every model predicts the identical fold fixtures.
- [ ] Probability vectors are finite, nonnegative, and sum to one.
- [ ] Calibration is trained out of fold.
- [ ] Metrics include uncertainty and per-tournament deltas.
- [ ] The final WC 2026 evaluation is executed only after the gate is frozen.
- [ ] The promoted model reports active predictors and data-license mode.

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Snapshot timing | Ledger phase | UTC cutoff tests and rejected-row audit |
| Holdout reuse | Benchmark contract | Test that 2026 cannot enter fitting splits |
| Temporal leakage | Fold phase | Source-date assertions on every assessment row |
| Model input mismatch | Registry phase | Shared fixture checksum and manifest |
| Feature overfit | Challenger phases | Penalization/ablation and leave-one-tournament-out deltas |
| Calibration overfit | Promotion phase | Inner out-of-fold calibration tests |

## Sources

- https://rsample.tidymodels.org/articles/Common_Patterns.html
- https://www.tidymodels.org/learn/models/calibration/
- https://www.zeileis.org/news/fifa2018eval/
- https://epub.ub.uni-muenchen.de/31579/1/Groll_Prediction.pdf
- https://arxiv.org/abs/1806.03208

---
*Pitfalls research for: xGelo v2.0*
*Researched: 2026-07-20*
