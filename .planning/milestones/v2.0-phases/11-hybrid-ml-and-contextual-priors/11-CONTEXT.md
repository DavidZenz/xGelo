# Phase 11: Hybrid ML and Contextual Priors - Context

**Gathered:** 2026-08-08
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 11 delivers chronology-safe hybrid challengers and contextual feature
variants inside the frozen rolling-tournament benchmark. It covers a
Groll-style random forest with independently estimated team ability, a named
open-data tournament-context bundle, a gated point-in-time xG variant, an
Hoffmann-Ging-Ramasamy-inspired structural shrinkage prior, and separately
labelled enriched squad and external bookmaker modes.

Every candidate must use the existing tournament folds, fixtures, cutoffs,
seeds, normalized score-distribution schema, provenance evidence, and proper
scoring services. This phase does not open the sealed 2026 holdout, make the
final promotion decision, automate restricted-data collection, or add XGBoost
before the RF challenger has established stable nonlinear value.

</domain>

<decisions>
## Implementation Decisions

### RF And Team Ability

- **D-01:** Implement the primary Groll-style challenger as two goal forests,
  one for home goals and one for away goals. A direct 1X2 classifier is not the
  primary implementation because it cannot satisfy the common goal-distribution
  contract.
- **D-02:** Convert the two RF goal means into the common score distribution by
  using registered/tuned negative-binomial marginals. Preserve football-goal
  overdispersion while retaining the existing shared adapter and G=40 support.
- **D-03:** Supply the RF with fold-local Phase 10 dynamic attack/defence
  abilities and Elo as separate inputs. The ability signal remains estimated
  independently from the forest and must retain its point-in-time evidence.
- **D-04:** Accept the RF only through identical rolling folds and the existing
  proper-score comparison framework. Require consistent improvement or
  non-inferiority across primary scores and stability checks; this phase does
  not automatically promote the RF.

### Open Context And Tournament Coverage

- **D-05:** Register the full open-context bundle: host, neutral venue, rest,
  travel, and tournament stage. Run individual ablations so incremental value
  is attributable to named features rather than only to a combined black box.
- **D-06:** Keep the established primary benchmark core frozen. Copa America and
  AFCON may provide supplemental training information and separately labelled
  regional diagnostics when their point-in-time coverage and provenance qualify,
  but they must not silently change the established core denominator.
- **D-07:** Use a strict common open-context panel for headline context-model
  comparisons. Keep the baseline on its established panel, report explicit
  feature and fixture coverage for the context variants, and do not silently
  impute unavailable context values.
- **D-08:** Derive rest, travel, and stage with deterministic open-data proxies:
  rest from prior match dates, travel from great-circle distance between the
  prior match location and current venue or host-country centroid, and stage
  from checked fixture metadata. Record source, vintage, derivation, and
  missingness for each field.

### Structural Prior And XG Activation

- **D-09:** Construct the Hoffmann-Ging-Ramasamy-inspired structural signal from
  point-in-time, vintage-aware data. Use it only as a prior for teams with
  sparse recent match evidence; raw contemporary structural values must not be
  backfilled into historical folds.
- **D-10:** Apply the structural information through continuous,
  evidence-weighted shrinkage toward the structural prior. Do not use a hard
  sparse/not-sparse switch, and do not add raw structural variables directly to
  the RF or goal model in the primary prior test.
- **D-11:** Determine the prior weight from a recency-weighted effective match
  count. The prior-strength parameter and any bounds or transformation must be
  registered before evaluation.
- **D-12:** Activate xG only after a predeclared point-in-time coverage, variance,
  and provenance gate passes. When the gate fails, xG is explicitly inactive;
  missing xG is not observed zero and the open benchmark remains non-xG.

### Enriched And External Modes

- **D-13:** Implement squad information only as a separately labelled,
  point-in-time enriched mode using locally derived squad-strength aggregates.
  Record vintage and provenance, keep raw restricted data out of committed
  outputs, do not automate collection, and do not replace the open default.
- **D-14:** Use bookmaker consensus only as a manually frozen, point-in-time
  external benchmark. Retain permitted probabilities or derived benchmark
  values with timestamp, source, and licensing metadata; automated collection is
  out of scope.
- **D-15:** Report three distinct modes: open default, enriched squad, and
  external market benchmark. Do not blend their scores or present them as
  equivalent candidates with identical data availability.
- **D-16:** Keep promotion eligibility mode-specific. Only the open-data mode
  can compete for the open default under the established benchmark and
  promotion rules. Enriched and external modes remain labelled research or
  reference outputs.

### Claude's Discretion

- The planner may choose the exact RF feature matrix, forest hyperparameter
  grid, random-forest package wiring, negative-binomial dispersion estimation,
  and the home/away forest tuning relationship, provided these choices are
  registered and chronology-safe.
- The planner may define the exact HGR-inspired structural variable registry,
  vintage availability rules, prior-strength parameterization, and effective
  sample-size formula. These must be justified by the literature record and
  frozen before historical scoring.
- The planner may set the numerical coverage, variance, and provenance gates for
  xG after inspecting available point-in-time evidence, but the gate must be
  predeclared, reproducible, and fail closed.
- The planner may select the concrete open-data sources and derivation schemas
  for rest, travel, stage, host, and neutral venue, subject to the deterministic
  proxy and provenance decisions above.
- The planner may choose the derived squad aggregates, permitted bookmaker
  representation, mode manifests, and report layout, subject to licensing and
  mode-specific promotion boundaries.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone And Phase Contracts

- `.planning/ROADMAP.md` - Phase 11 goal, requirements, dependencies, success
  criteria, and boundary before calibration and release.
- `.planning/REQUIREMENTS.md` - HYBRID-01 through HYBRID-05 and the future
  XGBoost/player-data requirements.
- `.planning/PROJECT.md` - Open-data-first operating mode, reproducibility,
  interpretability, licensing, and sealed-2026 constraints.
- `.planning/STATE.md` - Current phase position, completed Phase 10 handoff,
  and accumulated project decisions.

### Prior Phase Contracts And Verification

- `.planning/phases/08-forecast-ledger-and-wc-2026-retrospective/08-CONTEXT.md` -
  Immutable forecast-ledger, strict timing, missingness, and retrospective
  reporting boundaries.
- `.planning/phases/09-rolling-tournament-benchmark-harness/09-CONTEXT.md` -
  Locked tournament folds, exact panels, point-in-time training, common output
  schema, scoring, and promotion protocol.
- `.planning/phases/09-rolling-tournament-benchmark-harness/09-RESEARCH.md` -
  Literature review and adaptation notes for Groll random forests, Hoffmann,
  Ging and Ramasamy structural factors, Joachim Klement's related prediction
  note, bookmaker consensus, and chronological benchmark implementation.
- `.planning/phases/09-rolling-tournament-benchmark-harness/09-VERIFICATION.md` -
  Verified 630-fixture open and 609-fixture rich panels, durable evidence, and
  accepted benchmark bundle contracts.
- `.planning/phases/10-statistical-goal-model-challengers/10-CONTEXT.md` -
  Phase 10 model-adapter, dynamic ability, xG inactivity, shortlist, and
  research-only handoff decisions.
- `.planning/phases/10-statistical-goal-model-challengers/10-VERIFICATION.md` -
  Phase 10's verified seven-candidate bundle, exact panel/G=40 evidence, and
  research-only boundary.

### Phase Research And Literature

- `.planning/research/SUMMARY.md` - Phase 11 deliverables, RF-before-XGBoost
  ordering, open/enriched modes, and no-promotion boundary.
- `.planning/research/FEATURES.md` - Open versus enriched feature modes,
  structural-prior role, market benchmark treatment, and anti-feature guidance.
- `.planning/research/ARCHITECTURE.md` - Named feature sets, normalized score
  distribution contract, rolling-fold flow, and mode architecture.
- `.planning/research/STACK.md` - `ranger` recommendation for the RF and
  deferred `xgboost` dependency.
- `.planning/research/PITFALLS.md` - Vintage data, temporal leakage, xG
  activation, licensing, and stability risks.
- `.planning/research/SPI_MODEL_EVOLUTION.md` - Existing feature inventory and
  open questions around ability, xG, rest, travel, and squad priors.

### Frozen Registries And Evaluation Services

- `data/benchmark/phase09/model_registry.csv` - Registered model identity,
  panel, score support, and settings schema to extend for Phase 11.
- `data/benchmark/phase09/feature_contract.csv` - Point-in-time feature
  evidence, missingness, active-fit, provenance, and licensing semantics.
- `data/benchmark/phase09/panel_fixtures.csv` - Exact frozen open and rich
  evaluation fixture membership.
- `data/benchmark/phase09/promotion_protocol.json` - Supporting-score,
  stability, coverage, and promotion-gate semantics inherited by challengers.

### Existing Model And Pipeline Code

- `R/benchmark/runner.R` - Canonical deterministic execution, panel-aware
  scoring, reconciliation, and atomic publication.
- `R/benchmark/challenger_runner.R` - Shared challenger fit/predict adapter
  boundary and output handling.
- `R/benchmark/baselines.R` - Baseline fitting, score distributions, active and
  dropped predictor manifests, and feature evidence patterns.
- `R/benchmark/contracts.R` - Prediction, manifest, panel, provenance, and
  distribution validators.
- `R/benchmark/challenger_protocol.R` - Phase 10 registry and research-only
  challenger protocol patterns.
- `R/evaluation/benchmark_scores.R` - Proper scores, equal-tournament
  aggregation, paired deltas, uncertainty, and calibration diagnostics.
- `R/evaluation/challenger_selection.R` - Evidence-linked shortlist and
  non-promotion selection patterns.
- `R/forecast/goal_ability.R` - Existing point-in-time weighted ability features
  and evidence helpers.
- `R/forecast/dynamic_goal_ability.R` - Phase 10 dynamic attack/defence state,
  Elo adapter, cutoff, decay, and evidence implementation.
- `R/forecast/features.R` - Existing date-safe feature lookup and optional
  squad/xG feature assembly.
- `R/forecast/xg_usage_audit.R` - Explicit xG/form coverage and inactive-status
  audit helpers.
- `R/transfermarkt/squad_strength.R` - Local derived squad-strength snapshot
  and as-of-date aggregation patterns; restricted-data boundary applies.
- `_targets.R` - File-oriented pipeline integration and target ancestry.

### Regression And Contract Tests

- `tests/testthat/test_benchmark_baselines.R` - Adapter, fitting, and manifest
  regression patterns.
- `tests/testthat/test_benchmark_contracts.R` - Common schema and validator
  expectations.
- `tests/testthat/test_benchmark_cutoffs.R` - Point-in-time cutoff and leakage
  checks.
- `tests/testthat/test_benchmark_pipeline.R` - End-to-end deterministic bundle
  and panel-routing contracts.
- `tests/testthat/test_benchmark_promotion.R` - Promotion veto and stability
  semantics.
- `tests/testthat/test_benchmark_registry.R` - Registry and settings identity
  contracts.
- `tests/testthat/test_benchmark_scoring.R` - Shared scoring and paired
  comparison expectations.
- `tests/testthat/test_statistical_targets.R` - Phase 10 target and evidence
  regression patterns to preserve.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- The common benchmark runner and challenger adapter already provide the
  fit/predict/evidence boundary, normalized score-distribution output, panel
  routing, and durable publication path required by every Phase 11 mode.
- `dynamic_goal_ability.R` provides the fold-local attack/defence and Elo signal
  selected for the RF, including deterministic boundaries and explicit evidence
  companions.
- `goal_ability.R` provides transparent prior-only weighted ability features that
  can support structural-prior comparisons or cold-start diagnostics.
- `squad_strength.R` already supports local as-of-date squad aggregation and can
  be wrapped as an enriched mode without changing the open-data contract.
- `xg_usage_audit.R` and existing feature coverage records provide the starting
  point for a fail-closed xG gate; inactive xG/form must remain distinguishable
  from observed zero.

### Established Patterns

- Models are registry-driven, file-oriented R modules with explicit `run_*()`
  entry points, deterministic seeds, checked settings hashes, and fail-fast
  schemas.
- All candidates emit a complete normalized joint score distribution and derive
  1X2, totals, BTTS, exact-score, and tournament outputs through shared code.
- Source-row presence, numeric-value presence, imputation, active-fit status,
  and output coverage are separate evidence concepts.
- Frozen and updating tracks share formulas and tuning decisions; only eligible
  prior evidence changes at deterministic boundaries.
- Optional-data candidates use named feature-rich panels and cannot replace the
  complete open-core comparison or the open-data operating mode.

### Integration Points

- Extend model, feature, panel, and provenance registries rather than branching
  model-specific scoring behavior inside the runner.
- Add RF, context, structural-prior, xG-gated, enriched, and external adapters
  behind the existing common contract.
- Reuse the Phase 10 dynamic ability service and Phase 9 panel-aware scorer for
  every nested model and ablation.
- Add Phase 11 targets and reports while preserving the sealed WC2026 path and
  the Phase 10 research-only artifacts.

</code_context>

<specifics>
## Specific Ideas

- The RF should reproduce the literature's ability-plus-nonlinear structure
  faithfully before considering a broader boosting model.
- Goal means must remain usable by the existing distribution and market scoring
  services; a direct 1X2 classifier is not a substitute for the common contract.
- The HGR lineage and Klement adaptation are references for a structural prior,
  not permission to use current cross-sectional values in historical folds or to
  treat a proprietary model as a reproducible baseline.
- Copa America and AFCON are useful additional evidence, but their use must be
  visible as supplemental training and regional diagnostics rather than a silent
  change to the established World Cup/Euro estimand.
- The open default remains the project identity. Squad and bookmaker modes may
  be informative without becoming the default or sharing a pooled leaderboard.

</specifics>

<deferred>
## Deferred Ideas

- XGBoost remains deferred until the RF challenger establishes stable nonlinear
  value; this is tracked by `FUTURE-01`.
- Automated bookmaker, FotMob, or Transfermarkt collection remains out of scope
  because of licensing, terms, and reproducibility constraints.
- Current structural snapshots for historical folds, raw structural variables as
  unrestricted RF predictors, and direct 1X2-only RF models are deferred or
  rejected by the phase boundary.
- Expanding the primary benchmark denominator with Copa America or AFCON is
  deferred; they are supplemental training inputs and separately labelled
  regional diagnostics only.
- Combining open, enriched, and external modes into one candidate pool or
  allowing restricted modes to replace the open default is deferred and rejected
  by the mode-specific promotion decision.
- Opening the sealed 2026 holdout and making the final promotion or release
  decision belong to Phase 12.

</deferred>

---

*Phase: 11-Hybrid ML and Contextual Priors*
*Context gathered: 2026-08-08*
