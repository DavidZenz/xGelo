# xGelo Roadmap

**Active milestone:** v2.0 - Model Retrospective and Forecast Evolution
**Status:** In progress
**Created:** 2026-07-20

## Milestone Objective

Re-evaluate xGelo after the 2026 World Cup, establish a leakage-safe tournament
benchmark, and promote a better model only when it demonstrates reproducible
out-of-sample gains over the incumbent.

## Phase Map

`8 Forecast Ledger -> 9 Benchmark Harness -> 10 Statistical Challengers -> 11 Hybrid Models -> 12 Calibration and Release`

### Phase 8: Forecast Ledger and WC 2026 Retrospective

**Goal:** Build an auditable point-in-time record of the forecasts that genuinely
existed before kickoff, then evaluate the completed tournament without silently
backfilling missing predictions.

**Requirements:** LEDGER-01, LEDGER-02, LEDGER-03, EVAL-01, EVAL-02, EVAL-03

**Depends on:** Nothing (first v2.0 phase)

**Success Criteria:**

1. The ledger covers every official 2026 World Cup fixture and marks each record
   valid, missing, or rejected; no retrospective probability is presented as a
   pre-match forecast.

2. Every valid forecast proves that generation and source-data cutoffs preceded
   kickoff in UTC and records its source commit, model version, and provenance;
   invalid records carry machine-readable rejection reasons.

3. A reproducible evaluator reports 1X2 Brier score, log loss, RPS, goal and total
   distribution scores, both-teams-to-score scores, and exact-score performance.

4. Advancement and stage-reach forecasts are scored separately, while calibration
   and uncertainty are reported by stage, outcome class, and confidence for clearly
   labelled strict and exploratory samples.

5. The published retrospective can be regenerated from the immutable ledger and
   reports missing forecast coverage as an analytical result.

**Plans:** 3 plans

Plans:

- [x] 08-01: Reconstruct and validate the immutable forecast ledger
- [x] 08-02: Score match, goal, advancement, and stage-reach forecasts
- [x] 08-03: Publish the retrospective and integrate the pipeline

**Execution waves:** Wave 1: 08-01; Wave 2: 08-02 after 08-01; Wave 3: 08-03 after 08-02.

### Phase 9: Rolling Tournament Benchmark Harness

**Goal:** Create the common, leakage-safe evaluation contract under which every
baseline and challenger will be compared.

**Requirements:** BENCH-01, BENCH-02, BENCH-03, BENCH-04, BENCH-05

**Depends on:** Phase 8

**Success Criteria:**

1. Deterministic complete-tournament assessment folds cover the available World
   Cups and European Championships, and no 2026 outcome can enter fitting,
   feature selection, tuning, or calibration.

2. All models emit one prediction schema and retain a point-in-time feature
   contract, model manifest, data cutoffs, and feature-coverage audit.

3. Naive, Elo-only, and incumbent negative-binomial baselines run on identical
   fixtures and shared seeds and reproduce their registered outputs.

4. The harness reports proper scores, calibration diagnostics, paired per-fold
   deltas, and uncertainty rather than relying on winner-pick accuracy alone.

5. A checksum-backed promotion protocol defines practical improvement thresholds
   and tie-breaking rules before challenger selection begins.

### Phase 10: Statistical Goal-Model Challengers

**Goal:** Test interpretable score-model alternatives and simplify the incumbent
where correlated or inactive predictors do not add out-of-sample value.

**Requirements:** STAT-01, STAT-02, STAT-03, STAT-04

**Depends on:** Phase 9

**Success Criteria:**

1. A team-specific regularized Poisson candidate is registered and evaluated under
   the common benchmark contract.

2. Dynamic attack and defence ratings update strictly from prior matches and pass
   point-in-time leakage tests.

3. Dixon-Coles and bivariate-Poisson corrections produce valid score distributions;
   a representative dependence model is selected from pre-2026 folds only.

4. Controlled ablations of the incumbent's correlated predictors report active
   feature manifests and explicitly diagnose zero-coverage xG and form signals.

5. The phase report provides paired fold-level comparisons against every baseline
   without making a final 2026 promotion decision.

### Phase 11: Hybrid ML and Contextual Priors

**Goal:** Determine whether nonlinear, tournament-context, xG, and structural
information add stable value beyond the strongest statistical benchmark.

**Requirements:** HYBRID-01, HYBRID-02, HYBRID-03, HYBRID-04, HYBRID-05

**Depends on:** Phase 10

**Success Criteria:**

1. A Groll-style random forest with independently estimated team-ability parameters
   runs through the same folds, schema, seeds, and scoring contract as the baselines.

2. Host, neutral venue, rest, travel, and tournament-stage variables form a named,
   provenance-tracked open-data context feature set with documented ablations.

3. xG coverage is measured point in time, and no candidate is labelled xG-informed
   unless its signal passes the predeclared coverage and variance gate.

4. A Hoffmann-Ging-Ramasamy-inspired structural prior is evaluated specifically as
   shrinkage for teams with sparse recent match evidence.

5. Squad information and bookmaker consensus, when available, remain separately
   labelled enriched or external modes with explicit licensing and provenance.

### Phase 12: Calibration, Promotion, and Model Release

**Goal:** Freeze the candidate set, calibrate without outer-fold leakage, open the
2026 holdout once, and release only a challenger that clears the promotion rule.

**Requirements:** CAL-01, CAL-02, PROMO-01, PROMO-02, PROMO-03

**Depends on:** Phase 11

**Success Criteria:**

1. Calibration is learned from inner out-of-fold predictions only, and raw versus
   calibrated probabilities are compared with identical proper scores.

2. Candidate implementations, settings, feature sets, calibration recipes, and
   promotion thresholds are frozen and checksummed before 2026 results are opened.

3. The final 2026 comparison is executed once; the incumbent remains production
   default unless a challenger satisfies every predeclared promotion condition.

4. The selected model is published as a versioned artifact with its model card,
   benchmark report, data provenance, limitations, and reproducibility metadata.

5. Dashboard and export code consume only the approved model contract, and model,
   pipeline, and presentation regression tests pass.

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 8. Forecast Ledger and WC 2026 Retrospective | 3/3 | Complete | 2026-07-20 |
| 9. Rolling Tournament Benchmark Harness | 3/4 | In Progress | - |
| 10. Statistical Goal-Model Challengers | 0/TBD | Not started | - |
| 11. Hybrid ML and Contextual Priors | 0/TBD | Not started | - |
| 12. Calibration, Promotion, and Model Release | 0/TBD | Not started | - |

## Completed Milestones

### v1.0 - Open-Data Forecasting MVP

**Status:** Complete (2026-06-05)

Seven phases delivered the ingestion, xG, Elo, integration, forecasting, pipeline,
testing, visualization, and documentation foundations. See the
[archived v1.0 roadmap](milestones/v1.0-ROADMAP.md) and
[archived v1.0 requirements](milestones/v1.0-REQUIREMENTS.md).

## Requirement Coverage

| Phase | Requirements | Count |
|-------|--------------|-------|
| 8 | LEDGER-01..03, EVAL-01..03 | 6 |
| 9 | BENCH-01..05 | 5 |
| 10 | STAT-01..04 | 4 |
| 11 | HYBRID-01..05 | 5 |
| 12 | CAL-01..02, PROMO-01..03 | 5 |
| **Total** | **All v2.0 requirements** | **25** |

---
*Last updated: 2026-07-20 after Phase 8 completion*
