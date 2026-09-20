# Phase 19: Independent Club Forecast Authority - Research

**Researched:** 2026-09-20  
**Domain:** Club-only rating and goal models, leakage-safe multi-league evaluation, immutable model release, and explicit unavailable enrichment evidence  
**Confidence:** MEDIUM — the repository contracts and implementation seams are directly verified, but production model fitness cannot be established until the Phase 18 historical corpus has real accepted authority.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CLUBMOD-01 | The project can train club-only rating and goal models without consuming national-team features, releases, or selectors as forecast authority. `[VERIFIED: .planning/REQUIREMENTS.md]` | Create a new club-domain model protocol, rating state, goal-model adapters, and feature registry whose only training parent is the accepted Phase 18 club-history generation. Reuse domain-neutral score math, never national model objects, selectors, identities, or feature tables. `[VERIFIED: codebase audit; R/club/history_contract.R; R/evaluation/proper_scores.R]` |
| CLUBMOD-02 | Club-model evaluation uses frozen rolling-origin and cross-league folds with explicit information cutoffs and same-kickoff leakage tests. `[VERIFIED: .planning/REQUIREMENTS.md]` | Freeze two fold families before execution: chronological league-season folds and held-out-league transport folds. Build every forecast batch from evidence strictly before its exclusive cutoff; equal kickoffs, or the whole UTC date for date-only rows, share one pre-update state. `[VERIFIED: Phase 18 history schema; R/benchmark/cutoffs.R; Phase 9 benchmark contracts]` |
| CLUBMOD-03 | A club candidate is promoted only after passing predeclared proper-score, calibration, coverage, and reproducibility gates against documented baselines. `[VERIFIED: .planning/REQUIREMENTS.md]` | Reuse the shared RPS/Brier/log-loss/calibration formulas and freeze a club-specific gate registry, baselines, candidate registry, fold inventory, seed registry, feature contract, and parent hashes before evaluation. Promotion must be a pure decision over persisted evidence. `[VERIFIED: R/evaluation/benchmark_scores.R; R/evaluation/promotion.R; Phase 12 release architecture]` |
| CLUBMOD-04 | The approved club release is immutable, selector-authorized, documented by a model card, and rejected by national-team consumers while national-team releases are rejected by club consumers. `[VERIFIED: .planning/REQUIREMENTS.md]` | Publish a separate `outputs/releases/club/` generation tree and one self-hashed selector. Bind `forecast_domain = club`, the accepted history generation, model/evaluation/gate hashes, model card, and exact inventory into the release. Add an expected-domain guard to both club and national consumer entrypoints. `[VERIFIED: R/release/release_contract.R; outputs/releases/approved_release.csv; Phase 18 generation-pointer patterns]` |
| CLUBMOD-05 | Current xG, injury, lineup, suspension, and player features remain typed unavailable unless a separately accepted lawful source contract exists. `[VERIFIED: .planning/REQUIREMENTS.md]` | Freeze five feature-registry rows with `availability_status = unavailable`, `reason_code = no_accepted_source_contract`, no source authority, no value, and `active_in_model = FALSE`. Validators must reject zero-imputation, activation, or a claimed source without a separately accepted contract. `[VERIFIED: v4.0 decisions; Phase 14 unavailable-evidence patterns]` |
</phase_requirements>

## Summary

Phase 19 should be a new club-domain authority layered directly on the accepted Phase 18 history generation. It should not adapt the existing national-team release by changing labels. The current national stack hard-codes national identities, World Cup/Euro panels, Phase 12 candidate identities, `open_core`, and the root `outputs/releases/approved_release.csv` selector. Those are useful implementation analogs, but they are not club authority. `[VERIFIED: R/elo/runner.R; R/benchmark/*; R/release/*; R/competition/forecast_layer.R]`

The minimum defensible club model is a batch-safe club Elo state plus a negative-binomial goal model driven by club rating difference and venue. Register uniform, expanding 1X2, and venue-only goal controls; treat the club-Elo goal model as the first candidate. Run it through a frozen, nested protocol containing chronological league-season folds and held-out-league transport folds, with strict same-kickoff batching and full declared-fixture coverage. Use the existing score-distribution and proper-score functions through a thin club adapter, but build new club-namespaced calibration, promotion, manifests, and release objects. `[VERIFIED: existing scorer/model patterns; ASSUMED: initial club candidate and baselines]`

Production is currently and correctly blocked. `data/club/history_current.json` validates as `acceptance_state = blocked`, has no `accepted_generation_id`, and reports missing source pins, licenses, coverage, lineage, identity, score semantics, and temporal evidence. The provider token is also absent. Phase 19 can therefore implement and verify the entire contract with tagged synthetic fixtures, but no fixture-backed candidate may create or replace the production club selector. The production runner must write a typed blocked-run record and leave `outputs/releases/club/approved_release.csv` absent until a real accepted history generation passes every gate. `[VERIFIED: fresh-process production read-back on 2026-09-20; 18-VERIFICATION.md]`

**Primary recommendation:** Implement Phase 19 as `accepted club history -> frozen club protocol -> club rating/goal candidates -> two-family leakage-safe evaluation -> predeclared promotion gate -> immutable club release selector`, with fixture authority restricted to temporary test roots and production remaining fail-closed until Phase 18 external evidence is accepted. `[VERIFIED: requirements and existing trust-boundary patterns]`

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Accepted-history resolution | Database / Storage | API / Backend | The Phase 18 pointer selects the only immutable generation eligible for training; Phase 19 validates it before any fit. `[VERIFIED: phase18_read_club_history_current()]` |
| Club rating state | API / Backend | Database / Storage | Rating recursion and same-batch updates are model business logic; pre-match states and hashes are durable evidence. `[VERIFIED: existing Elo architecture; ASSUMED: new club implementation]` |
| Club goal model and calibration | API / Backend | Database / Storage | Fitting and probability transformation are backend computations; fitted objects, recipes, and manifests are immutable artifacts. `[VERIFIED: R/benchmark/baselines.R; R/calibration/*]` |
| Fold and gate registry | Database / Storage | API / Backend | Registries are predeclared authority; execution validates and consumes them but cannot rewrite them from observed scores. `[VERIFIED: Phase 9/12 registry pattern]` |
| Evaluation and promotion | API / Backend | Database / Storage | Shared proper scores and club-specific gates compute decisions; row-level predictions, scores, calibration, and decision evidence remain durable. `[VERIFIED: R/evaluation/*]` |
| Release generation and selector | Database / Storage | API / Backend | Immutable release trees and one atomic selector own visibility; the resolver validates hashes/domain before loading RDS. `[VERIFIED: R/release/release_contract.R; Phase 18 pointer patterns]` |
| UCL forecast consumption | API / Backend | Frontend Server / SSR | Phase 20 requests club forecasts through the club resolver; the dashboard only receives validated forecast/status tables. `[VERIFIED: ROADMAP.md phase boundaries]` |
| Enrichment availability | API / Backend | Frontend Server / SSR | The model contract owns whether evidence is active; later presentation renders its typed unavailable state without guessing values. `[VERIFIED: CLUBMOD-05; Phase 14 state/forecast patterns]` |

## Project Constraints (from AGENTS.md)

- Use R as the implementation language and `targets` as the reproducible orchestration boundary. `[VERIFIED: AGENTS.md]`
- Keep data acquisition, model training, ratings, integration, forecasting, and publication as distinct layers; do not make Phase 19 a current-state acquisition or UCL rules phase. `[VERIFIED: AGENTS.md; ROADMAP.md]`
- Never reuse national-team identity or authority for clubs; club identities use the project-owned `club_` namespace and validity-aware Phase 18 registries. `[VERIFIED: AGENTS.md; STATE.md Phase 18 decisions]`
- Preserve strict temporal safety: only evidence before the prediction cutoff is eligible, and same-time results must not affect each other. `[VERIFIED: AGENTS.md; Phase 18 history policy; Phase 9 cutoff protocol]`
- Use deterministic seeds and reproducible artifacts; test core functions under `tests/testthat` and run tests frequently. `[VERIFIED: AGENTS.md]`
- Keep unsupported current xG, injury, lineup, suspension, and player evidence unavailable rather than zero-filled or inferred. `[VERIFIED: PROJECT.md; REQUIREMENTS.md]`
- Do not install a database, application server, frontend framework, or new runtime for this phase. `[VERIFIED: REQUIREMENTS.md Out of Scope]`
- Preserve unrelated user changes, read before editing, commit planning and implementation artifacts, and verify before committing. `[VERIFIED: AGENTS.md]`

## Current-State Findings

| Finding | Planning consequence |
|---------|----------------------|
| Phase 18 exposes `phase18_read_club_history_current()` and validates a pointer-selected immutable generation before exposing accepted history. `[VERIFIED: R/club/history_contract.R:919]` | Make this the only production training entrypoint; never read `history_audits/*/matches.csv` or a caller-supplied CSV directly. |
| The production history pointer is blocked and has no accepted generation. `[VERIFIED: fresh-process read-back on 2026-09-20]` | The production Phase 19 runner must exit with a typed blocked result before fitting, scoring, publishing a release, or changing a selector. |
| Normalized history includes `competition_id`, `season_id`, club IDs, regulation/final/shootout scores, completion method, `completion_not_before_utc`, `evidence_available_at_utc`, `counts_for_model`, and row/source/registry hashes. `[VERIFIED: phase18_normalized_club_match_schema()]` | Fold builders can use regulation goals and exact history authority without reparsing raw source data. Both completion and evidence timestamps must be checked. |
| The history inventory predeclares 2021/22–2025/26 rows across domestic and European source families, but every current row is pending review. `[VERIFIED: data/club/history_sources.csv]` | Do not freeze production fold counts or claim connected coverage from the pending inventory; derive the exact fold inventory from the accepted generation, then freeze it before model execution. |
| The national `compute_elo()` uses national names/FIFA mappings, sequential row updates, and absolute-rating decay. `[VERIFIED: R/elo/runner.R]` | Do not call or lightly parameterize it. A club rating must use club IDs, regress differences toward a base rating, and update equal-kickoff batches simultaneously. |
| `fit_elo_goal_nb()` already shows a deterministic two-row-per-match negative-binomial pattern using rating difference and venue. `[VERIFIED: R/benchmark/baselines.R]` | Extract/reuse the mathematical pattern through a club-owned adapter; do not reuse national registries, candidate IDs, manifests, or model objects. |
| The shared scorer validates complete fixture/distribution coverage and computes RPS, multiclass Brier, log loss, joint scoreline log loss, goal RPS, totals, BTTS, and exact score. `[VERIFIED: R/evaluation/benchmark_scores.R]` | Reuse the scorer unchanged after mapping club outputs to its domain-neutral schema. Do not fork metric formulas. |
| Phase 12 calibration and release code is candidate-, panel-, and World-Cup-specific. `[VERIFIED: R/calibration/*; R/release/*]` | Reuse temperature-transform and immutable-publication ideas, not Phase 12 objects or authority. Implement club-namespaced recipes/manifests/resolvers. |
| The active national selector is `outputs/releases/approved_release.csv` and points to `phase14-open-nb-incumbent-calibrated-v1`. `[VERIFIED: outputs/releases/approved_release.csv]` | Use a disjoint club root/selector and add expected-domain guards; never overwrite or repurpose the national selector. |

## Standard Stack

No new package is needed. Use only the installed project runtime and existing dependencies. `[VERIFIED: local environment audit]`

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| R | 4.6.1 | Club model fitting, evaluation, manifests, release validation, and CLIs | Project runtime and non-negotiable language. `[VERIFIED: local runtime; AGENTS.md]` |
| Base R `stats` | R 4.6.1 | Deterministic optimization, prediction, dates, and simple GLM utilities | Already available; sufficient for one-parameter probability calibration and deterministic helpers. `[VERIFIED: local runtime; existing Phase 12 code]` |
| `MASS` | 7.3-65 | Negative-binomial club goal models | Installed and already used by the benchmark. Official documentation states `glm.nb()` estimates theta, accepts observation weights, uses a log link by default, and returns a `negbin`/`glm` object. `[VERIFIED: local package; CITED: https://stat.ethz.ch/R-manual/R-devel/library/MASS/html/glm.nb.html]` |
| `targets` | 1.12.0 | File-oriented phase orchestration | Already owns `_targets.R`; official docs specify that `format = "file"` targets return existing paths and track those artifacts for invalidation. `[VERIFIED: local package; CITED: https://docs.ropensci.org/targets/reference/tar_target.html]` |
| `digest` | 0.6.39 | SHA-256 file verification where existing contracts require it | Installed and used throughout existing releases. Canonical row/table identities should use the collision-safe canonical-v2 helper instead of delimiter concatenation. `[VERIFIED: local package; R/common/phase18_canonical_hash.R]` |
| `jsonlite` | 2.0.0 | Strict pointer, protocol, blocked-run, and model-contract JSON | Installed and used by Phase 18/12 durable contracts. `[VERIFIED: local package and codebase]` |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `testthat` | 3.3.2 | Unit, adversarial, subprocess, and integration tests | Use for every Phase 19 trust boundary and the fresh-process aggregate gate. `[VERIFIED: local package; tests/testthat]` |
| Existing `R/evaluation/proper_scores.R` and `benchmark_scores.R` | repository commit `15b6ffda...` at research time | Probability/distribution validation and proper-score computation | Reuse through a club schema adapter after confirming exact fixture coverage. `[VERIFIED: codebase and git]` |
| Existing `R/common/phase18_canonical_hash.R` | canonical-v2 | Typed, framed scalar/sequence/row/table identities | Use for all new registries, manifests, selectors, fold rows, and release metadata. `[VERIFIED: Phase 18 verification]` |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| New club rating recursion | Reuse `compute_elo()` | Existing code is national-identity-bound and updates sequentially, so same-kickoff order could affect state; a club batch-safe implementation is required. `[VERIFIED: R/elo/runner.R]` |
| Club-namespaced release | Relabel the Phase 14 national release | Violates CLUBMOD-01/04 and would preserve national training, feature, selector, and panel authority. `[VERIFIED: requirements and release code]` |
| Shared score formulas | New club scoring package | Duplicates tested formulas and introduces avoidable metric drift/dependency risk. `[VERIFIED: R/evaluation/*]` |
| Explicit unavailable rows | Zero or median imputation for absent enrichment | Turns absence into fabricated evidence and can silently activate unsupported predictors. `[VERIFIED: CLUBMOD-05]` |
| Fixture-only full-path tests | Invent a production accepted corpus | Fixtures can prove mechanics but cannot establish licensing, identity, or production model quality. `[VERIFIED: Phase 18 verification]` |

**Installation:** None. Do not modify the package environment for Phase 19. `[VERIFIED: dependency audit]`

## Package Legitimacy Audit

No external package installation is proposed. The phase reuses R, `MASS`, `targets`, `digest`, `jsonlite`, and `testthat` already installed and used by the project, so the package-legitimacy gate is not applicable. `[VERIFIED: local environment and repository imports]`

## Architecture Patterns

### System Architecture Diagram

```text
Production entry
      |
      v
[validate Phase 18 current history pointer]
      |
      +-- blocked / no accepted generation --> [typed blocked run]
      |                                         [no fit, no release, no selector]
      |
      v accepted, exact immutable generation
[snapshot matches + registries + corpus hash]
      |
      v
[validate frozen club protocol]
  candidates + controls + features + folds + gates + seeds
      |
      +-- any drift / fixture authority in production --> reject
      |
      v
[build pre-kickoff batch boundaries]
      |
      +--> [rolling-origin league-season folds]
      |
      +--> [held-out-league transport folds]
      |
      v
[club Elo state] --> [venue-only NB control / club-Elo NB candidate]
      |                         |
      +-------------------------+
                    |
                    v
       [complete G=40 score grids + raw 1X2]
                    |
                    v
       [nested prior-only club calibration]
                    |
                    v
 [shared proper scores + calibration + exact coverage evidence]
                    |
                    v
        [pure predeclared promotion decision]
                    |
             pass? -- no --> [auditable rejected run; selector unchanged]
                    |
                    v
        [final fit at explicit cutoff]
                    |
                    v
[immutable club release + model card + exact inventory]
                    |
                    v
   [atomic outputs/releases/club/approved_release.csv]
                    |
                    v
 [club resolver asserts forecast_domain=club]
                    |
                    +--> Phase 20 UCL forecasts

National resolver/consumer <---- expected-domain guard ----> Club resolver/consumer
```

This design has four independent authority checks: accepted source history, frozen evaluation protocol, promotion evidence, and release selector. Passing a downstream check cannot repair a missing upstream authority. `[VERIFIED: existing project trust-boundary pattern; ASSUMED: Phase 19 decomposition]`

### Recommended Project Structure

```text
R/
├── club/
│   ├── model_contract.R          # accepted-history snapshot and domain/feature guards
│   ├── rating.R                  # batch-safe club Elo recursion and manifests
│   ├── goal_model.R              # controls, NB candidate, complete score grids
│   ├── calibration.R             # club-namespaced prior-only temperature calibration
│   ├── evaluation_protocol.R     # frozen registries, folds, gates, seeds, hashes
│   ├── evaluation.R              # two fold families, scoring, diagnostics, promotion evidence
│   └── release.R                 # immutable release, selector, resolver, model card
├── release/
│   └── domain_contract.R         # expected-domain guard shared by national and club consumers
└── common/
    └── phase18_canonical_hash.R  # reuse; do not fork

data/club/model_protocol/
├── candidate_registry.csv
├── feature_contract.csv
├── gate_registry.csv
├── fold_registry.csv
├── seed_registry.csv
└── calibration_recipe.json

outputs/club_model/
├── evaluations/<run_id>/         # immutable predictions, distributions, scores, diagnostics
└── blocked/<run_id>.json          # no-authority evidence; never a release

outputs/releases/club/
├── <release_id>/
│   ├── release_manifest.csv
│   ├── model_contract.json
│   ├── model/approved_model.rds
│   ├── model/calibrator.rds
│   ├── manifests/{history,protocol,evaluation,promotion,provenance}.csv
│   └── reports/{model_card.md,benchmark_report.md,limitations.md,reproducibility.json}
└── approved_release.csv

scripts/
├── run_phase19_club_evaluation.R
└── verify_phase19_contracts.R

tests/testthat/
├── helper_phase19_club_fixture.R
├── test_phase19_club_domain_contract.R
├── test_phase19_club_rating.R
├── test_phase19_club_goal_model.R
├── test_phase19_club_folds.R
├── test_phase19_club_evaluation.R
├── test_phase19_club_release.R
└── test_phase19_adversarial_regression.R
```

Paths are recommendations; the critical constraint is that club authority, artifacts, and selector remain disjoint from the national release root. `[ASSUMED]`

### Pattern 1: Accepted History Is the Only Training Door

The production loader should accept only the fixed Phase 18 pointer and generation root, validate the current pointer and selected generation, require `acceptance_state = accepted`, require a non-empty `accepted_generation_id`, then read `accepted/matches.csv` from that validated generation. It must bind pointer, corpus manifest, matches, club registry, and source manifest hashes into a Phase 19 input snapshot. `[VERIFIED: Phase 18 APIs and schema]`

```r
# Source: R/club/history_contract.R and R/common/phase18_canonical_hash.R
load_phase19_club_training_snapshot <- function(
    current_path = "data/club/history_current.json",
    generations_root = "data/club/history_generations",
    authority_mode = "production") {
  pointer <- phase18_read_club_history_current(current_path, generations_root)
  if (!identical(authority_mode, "production")) {
    stop("fixture authority must use the explicit test-only loader", call. = FALSE)
  }
  if (!identical(pointer$acceptance_state, "accepted") ||
      !nzchar(pointer$accepted_generation_id)) {
    return(list(status = "blocked", reason_code = "history_not_accepted"))
  }
  # Resolve only pointer-selected accepted/ paths, validate again, snapshot bytes,
  # and return the bound corpus identity plus normalized model rows.
}
```

Never accept a data frame, arbitrary CSV path, audit-only generation, or caller-supplied `accepted_for_training = TRUE` as production authority. `[VERIFIED: Phase 18 threat model and verification]`

### Pattern 2: Batch-Safe Club Rating State

Use canonical `club_id` keys only. For a boundary, apply inactivity reversion toward the base rating, generate every fixture's pre-match rating evidence from the unchanged state, and only after every prediction is recorded apply the batch's rating deltas simultaneously. `[ASSUMED]`

Recommended initial rating contract: `[ASSUMED]`

- Base rating: 1500.
- Expected outcome: standard logistic Elo curve.
- Home advantage and K-factor: frozen numeric fields in the candidate registry; tune only on inner folds, never on the outer assessment block.
- Inactivity: regress the difference from 1500, not the absolute rating: `1500 + (rating - 1500) * decay`.
- Regulation result is the rating outcome; extra-time/shootout scores are not silently treated as regulation.
- Every pre-match row records rating-state hash, last eligible evidence time, prior-match count, cold-start flag, and fold/boundary identity.
- All matches at an identical known kickoff share a batch. If kickoff is date-only, the entire UTC date shares a batch and results become eligible at the next UTC day boundary, matching Phase 18's conservative policy. `[VERIFIED: Phase 18 decision]`

The club match graph must connect every current-UCL club to one common rating component through accepted domestic/European evidence. A disconnected current club blocks the production release rather than receiving a silently comparable 1500. `[ASSUMED; risk derived from rating-scale identifiability]`

### Pattern 3: Explicit Two-Family Evaluation

Freeze `fold_registry.csv` before fitting. Each row carries `fold_id`, `fold_family`, `assessment_competition_id`, `assessment_season_id`, `assessment_start_utc`, `assessment_end_utc`, `training_cutoff_exclusive`, `calibration_cutoff_exclusive`, declared fixture IDs/hash, held-out competition, minimum support state, and row hash. `[ASSUMED]`

1. **`rolling_origin_league_season`:** assess one future league/European season block; training, parameter tuning, rating recursion, and calibration use only evidence strictly before the block's cutoff. `[VERIFIED: CLUBMOD-02; existing rolling-origin contract]`
2. **`heldout_league_transport`:** exclude the held-out `competition_id` from fit, tuning, and calibration evidence and assess its frozen fixture block. Preserve every declared fixture; cold starts and disconnected clubs become explicit no-forecast/coverage failures, never dropped rows. `[ASSUMED: strongest interpretation of cross-league evaluation]`

Nested tuning/calibration folds must lie entirely inside the outer training window and inherit the outer held-out-league exclusion. Aggregate first within each fold, then equally across folds within each family; fixture-weighted results are secondary. Report per-league and per-season values so a large league cannot dominate. `[VERIFIED: Phase 9 equal-block pattern; ASSUMED: club fold families]`

### Pattern 4: Same-Kickoff Leakage Guard

For each fixture, compute an exclusive cutoff. Eligible training evidence must satisfy both:

```text
completion_not_before_utc < boundary_cutoff_exclusive
AND evidence_available_at_utc < boundary_cutoff_exclusive
AND counts_for_model == TRUE
```

No outcome from the assessment boundary may be visible to rating updates, goal-model fitting, hyperparameter selection, or calibration until the next boundary. Permuting rows within one boundary must produce byte-equivalent pre-match ratings and forecasts. `[VERIFIED: Phase 18 schema and CLUBMOD-02; ASSUMED: permutation invariant]`

Adversarial tests must cover equal exact kickoffs, date-only matches, extra-time completion floors, evidence exactly at cutoff, evidence one second before/after cutoff, postponed matches, shuffled input order, duplicated fixture IDs, and assessment labels injected into a training role. `[VERIFIED: prior phase failure modes; ASSUMED: test inventory]`

### Pattern 5: Frozen Candidates, Baselines, and Gates

Recommended initial registry: `[ASSUMED]`

| ID | Role | Inputs | Output |
|----|------|--------|--------|
| `uniform_1x2` | sanity control | none | exact 1/3 1X2 plus a declared non-goal-distribution status |
| `expanding_1x2` | historical control | prior regulation results only | weighted prior 1X2 and empirical score grid |
| `club_venue_nb` | incumbent goal baseline | venue only | complete G=40 NB score distribution and derived markets |
| `club_elo_nb` | first candidate | club Elo difference plus venue | complete G=40 NB score distribution and derived markets |

All are club-only because their only rows and identities come from the accepted club corpus. The release candidate contains the rating settings/state, home and away/team goal model, calibrator, and frozen feature declaration as one model object. `[ASSUMED]`

Recommended gate registry, frozen before predictions: `[ASSUMED; thresholds inherit the project's tested Phase 9 policy where applicable]`

| Gate | Pass rule |
|------|-----------|
| Primary proper score | Equal-fold candidate-minus-`club_venue_nb` RPS `<= -0.003` |
| Paired uncertainty | 95% paired-fold bootstrap upper bound `< 0` |
| Fold breadth | Candidate improves at least two-thirds of eligible folds in **each** fold family |
| Worst fold | No fold RPS regression `> 0.015` |
| Supporting scores | Equal-fold Brier and log-loss relative regression each `<= 1%` |
| Calibration | Fixed-bin calibration error change `<= 0.01`; calibrated view becomes primary only if it improves calibration without triggering any score veto |
| Coverage | Exactly 100% of every declared assessment fixture has a validated prediction and full score grid; no silent drops |
| Current-UCL coverage | Every accepted current UCL club resolves to the model's club registry and common rating component before a production release |
| Reproducibility | Two isolated runs from the same accepted history/protocol/code/seed have identical canonical artifact hashes |
| Contract integrity | Probability, distribution, cutoff, identity, source, license, feature, seed, checksum, domain, and model-card gates all pass |

`uniform_1x2` and `expanding_1x2` remain report-only controls; promotion is against the stronger `club_venue_nb` incumbent. If the candidate does not clear every gate, publish evaluation evidence but do not create an approved club release or selector. `[ASSUMED]`

### Pattern 6: Club-Namespace Calibration

Implement one-parameter temperature calibration on derived 1X2 probabilities using strictly prior inner out-of-fold rows. Preserve the fitted goal distribution and expose both raw and calibrated views. Bind the recipe, support counts, fold inventory, source prediction hashes, optimizer state, cutoff, and fallback reason. `[VERIFIED: Phase 12 proven pattern; ASSUMED: reuse for club domain]`

Do not call a Phase 12 calibrator as authority because its schema and freeze graph are World-Cup candidate-specific. A domain-neutral pure transform may be extracted, but the club calibrator must carry `forecast_domain = club` and Phase 19 parent hashes. `[VERIFIED: R/calibration/probability_calibration.R]`

### Pattern 7: Typed Unavailable Enrichment

Freeze exactly these initial optional features: `current_xg`, `injury`, `lineup`, `suspension`, and `player`. Recommended schema: `[ASSUMED]`

```text
schema_version, forecast_domain, feature_id, availability_status,
reason_code, source_contract_id, source_contract_sha256,
value_type, value, observed_at_utc, cutoff_status,
required_by_model, active_in_model, imputation_policy, row_sha256
```

Initial production rows must have: `forecast_domain = club`, `availability_status = unavailable`, `reason_code = no_accepted_source_contract`, blank contract/hash/timestamp/value, `required_by_model = FALSE`, `active_in_model = FALSE`, `imputation_policy = forbidden`. `[VERIFIED: CLUBMOD-05; ASSUMED: exact schema]`

Reject a protocol if an unavailable feature appears in a formula, if its value is zero-filled, if a claimed contract is not separately hash-validated, or if a fixture row omits the unavailable evidence row. This makes absence visible and stable for Phase 20/21 consumers. `[VERIFIED: CLUBMOD-05; existing Phase 14 fail-closed pattern]`

### Pattern 8: Immutable Domain-Bound Release

The club release manifest should list every file recursively with bytes, SHA-256, schema, producer, and release ID plus a self-hash. The model contract must bind at least: `[ASSUMED]`

```text
forecast_domain = club
entity_kind = club
release_id, selected_model_id, candidate_id, incumbent_id
history_generation_id, history_manifest_sha256, club_registry_sha256
protocol_sha256, fold_registry_sha256, gate_registry_sha256
evaluation_manifest_sha256, promotion_decision_sha256
model_artifact, model_sha256, calibrator_artifact, calibrator_sha256
model_data_cutoff_utc, calibration_data_cutoff_utc
score_support_g, primary_probability_view
feature_contract_sha256, unavailable_feature_ids
model_card_sha256, code_commit, labels_embedded = FALSE
fixture_authority = FALSE
```

Publish the immutable generation first, validate it in a fresh process without loading RDS, hash-check model/calibrator bytes, then load and validate object class/domain/IDs, and finally atomically replace one self-hashed `outputs/releases/club/approved_release.csv`. A selector row must contain `forecast_domain`, `release_id`, relative manifest path, manifest hash, approval time, and row hash. `[VERIFIED: Phase 12/14 and Phase 18 publication patterns; ASSUMED: club schema]`

The model card is authority, not decoration: validate its release/domain/model/history/protocol/cutoff/metric/limitation identities against the contract or use a structured model-card manifest alongside the Markdown. `[VERIFIED: Phase 12 release lesson; ASSUMED: validation design]`

### Pattern 9: Symmetric Cross-Domain Rejection

Add one shared guard:

```r
assert_forecast_domain <- function(metadata, expected_domain) {
  allowed <- c("national_team", "club")
  if (!expected_domain %in% allowed ||
      !identical(as.character(metadata$forecast_domain), expected_domain)) {
    stop("forecast release domain mismatch", call. = FALSE)
  }
  invisible(TRUE)
}
```

The club resolver requires explicit `club`. The national consumer wraps the validated legacy Phase 14 release as explicit `national_team` metadata and calls the same guard before forecasting. Tests must attempt both selector swaps, release-root swaps, contract-field mutation, copied artifacts, mixed model/calibrator objects, and direct consumer calls. Existing immutable national artifacts need not be edited. `[VERIFIED: existing selector topology; ASSUMED: compatibility adapter]`

### Pattern 10: Fixture-Backed Development Without False Authority

Synthetic fixtures should exercise multiple competitions, seasons, connected European bridge matches, exact and date-only kickoffs, postponed rows, cold starts, and known probability behavior. Every fixture snapshot, protocol, evaluation, and release must carry `authority_mode = fixture`, `fixture_authority = TRUE`, and a fixture-root hash. `[ASSUMED]`

Production CLIs and resolvers reject fixture authority unconditionally. Full-path fixture releases live only under `withr`/`tempdir()`-style test roots (base `tempfile()` is sufficient; do not add a package), never under `outputs/releases/club/`. A fixture run may prove schemas, leakage controls, gates, atomic publication, and cross-domain rejection; it cannot prove model quality, licensing, current-club coverage, or production acceptance. `[VERIFIED: Phase 18 fixture-authority precedent; ASSUMED: Phase 19 restriction]`

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Proper-score formulas | New RPS/Brier/log-loss implementations | `R/evaluation/proper_scores.R` and `benchmark_scores.R` | Existing formulas and coverage validation are already tested. `[VERIFIED: codebase]` |
| Probability/distribution validation | Ad hoc sum/range checks | Existing `validate_probability_vector()`, score-grid, and market-derivation contracts | Avoids disagreement between stored grids and displayed markets. `[VERIFIED: codebase]` |
| Canonical hashing | Delimiter-concatenated strings | Canonical-v2 typed/framed hash helpers | Phase 18 proved delimiter/type collisions in older patterns. `[VERIFIED: 18-VERIFICATION.md]` |
| Atomic visibility | Copying files into a live release | Immutable generation plus one atomic selector | Readers must see complete old or complete new authority. `[VERIFIED: existing release/source patterns]` |
| Path containment | String-prefix checks alone | Safe relative IDs, lexical checks, real-path containment, exact inventory, no symlinks | Phase 18 review found lexical/symlink escape risks. `[VERIFIED: 18-REVIEW.md and fixes]` |
| Release discovery | Latest mtime or directory scan | One validated club selector | Directory ordering is not approval authority. `[VERIFIED: Phase 14 selector]` |
| Calibration library | New external package | Club-namespaced version of the existing one-parameter recipe using `stats::optim` | No new dependency is needed and the pattern is already exercised. `[VERIFIED: R/calibration/*]` |
| Missing enrichment | Numeric placeholders | Typed unavailable evidence rows | Zero is a claim, not absence. `[VERIFIED: CLUBMOD-05]` |
| National/club authority | Filename/model-ID heuristics | Explicit domain discriminator and expected-domain guard | Names can collide or be copied; domain must be contract-bound. `[ASSUMED]` |

**Key insight:** Reuse pure mathematical services, not authority objects. Scores, canonical hashing, and atomic-generation mechanics are domain-neutral; identities, training parents, fold registries, promotion evidence, selectors, and release contracts are domain authority and must be new. `[VERIFIED: codebase architecture and requirements]`

## Common Pitfalls

### Pitfall 1: Treating a Valid Phase 18 Audit as Accepted Training Authority
**What goes wrong:** Phase 19 reads `history_audits/.../matches.csv` or a blocked generation and trains anyway.  
**Why it happens:** Audit artifacts are complete enough to parse and may look authoritative.  
**How to avoid:** Resolve only `history_current.json`, require accepted state/non-empty accepted generation, then read its `accepted/` tree.  
**Warning signs:** Caller-supplied training CSV paths, `allow_blocked`, or `accepted_for_training` trusted without recomputation. `[VERIFIED: Phase 18 contract]`

### Pitfall 2: Reusing National Elo or Release Authority
**What goes wrong:** A club model receives FIFA mappings, national ratings, the Phase 14 selector, or a national fitted object.  
**Why it happens:** Existing functions already return plausible probabilities.  
**How to avoid:** Separate club namespaces and expected-domain guards at loaders, fitters, release validators, and consumers.  
**Warning signs:** `team_id`, `fifa_code`, `outputs/releases/approved_release.csv`, or `phase14_resolve_approved_release()` in a club forecast call graph. `[VERIFIED: CLUBMOD-01/04 and codebase]`

### Pitfall 3: Sequential Same-Kickoff Updates
**What goes wrong:** Row order lets one match result change another forecast at the same information time.  
**Why it happens:** A simple loop predicts and updates one row at a time.  
**How to avoid:** Snapshot once per boundary, predict all rows, then apply all updates; assert row-permutation invariance.  
**Warning signs:** Predictions differ after shuffling same-date rows. `[VERIFIED: CLUBMOD-02; national Elo code risk]`

### Pitfall 4: Tuning or Calibrating on Outer Assessment Labels
**What goes wrong:** Candidate settings or calibration improve because the held-out league/season affected selection.  
**Why it happens:** One table is reused for fit, tuning, calibration, and scoring.  
**How to avoid:** Nested registries with explicit roles and cutoffs; held-out-league exclusions propagate to every inner operation.  
**Warning signs:** Outer fold IDs appear in calibrator source rows or tuning manifests. `[VERIFIED: existing nested OOF principles; ASSUMED: club implementation]`

### Pitfall 5: Dropping Cold Starts or Weak Leagues
**What goes wrong:** Coverage looks excellent because difficult clubs/fixtures disappear.  
**Why it happens:** Inner joins or `complete.cases()` silently shrink the assessment panel.  
**How to avoid:** Freeze fixture IDs first, left-join outputs, emit explicit failed/no-forecast rows, and require 100% promotion coverage.  
**Warning signs:** Score denominator differs by model or fold. `[VERIFIED: shared scorer exact-coverage contract]`

### Pitfall 6: Incomparable Domestic Rating Islands
**What goes wrong:** Top clubs from disconnected leagues all appear similarly rated because each league is internally zero-sum.  
**Why it happens:** No accepted cross-league bridge matches connect rating pools.  
**How to avoid:** Persist the club-match graph, require one connected component for current UCL coverage, and fail the release if it is disconnected.  
**Warning signs:** Multiple graph components or current clubs with only isolated domestic evidence. `[ASSUMED: model-identifiability risk]`

### Pitfall 7: Freezing Gates After Seeing Results
**What goes wrong:** Thresholds or baselines are chosen to approve the observed candidate.  
**Why it happens:** Protocol and score generation share one mutable run.  
**How to avoid:** Canonically hash registries before predictions and bind their hashes into every row/manifest. A changed protocol requires a new run identity.  
**Warning signs:** Gate registry timestamp is after prediction artifacts or thresholds are absent from the freeze. `[VERIFIED: Phase 9/12 governance]`

### Pitfall 8: Fixture Success Becomes Production Approval
**What goes wrong:** Synthetic data creates a valid-looking production selector or model card.  
**Why it happens:** Test and production use identical output roots without an authority discriminator.  
**How to avoid:** Separate loader and root, bind fixture authority into every object, and make production release/selector validators reject it.  
**Warning signs:** Fixture IDs or `fixture_authority=TRUE` under `outputs/releases/club/`. `[VERIFIED: Phase 18 precedent; ASSUMED: Phase 19 enforcement]`

### Pitfall 9: Model Card Exists but Is Not Bound
**What goes wrong:** Markdown describes different data, cutoffs, or metrics from the actual release.  
**Why it happens:** The card is treated as documentation only.  
**How to avoid:** Hash it in the manifest and validate a structured identity projection against the release contract.  
**Warning signs:** Model-card edits do not invalidate the release. `[VERIFIED: release-integrity lesson; ASSUMED: structured projection]`

### Pitfall 10: Hash-Then-Read Race or Unsafe RDS Loading
**What goes wrong:** A file changes after validation or an untrusted model object is loaded before its bytes/domain are approved.  
**Why it happens:** Validators repeatedly reopen live paths.  
**How to avoid:** Validate exact inventory and hashes, read immutable bytes once where practical, load RDS only after contract/hash approval, then validate object class/domain/IDs.  
**Warning signs:** `readRDS()` precedes manifest verification or accepts arbitrary paths. `[VERIFIED: Phase 18 snapshot-read lesson; ASSUMED: model loader application]`

## Code Examples

### Same-Boundary Eligibility

```r
# Source pattern: R/club/history_contract.R and R/benchmark/cutoffs.R
eligible_before <- function(matches, cutoff_utc, excluded_competition = "") {
  cutoff <- as.POSIXct(cutoff_utc, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  completion <- as.POSIXct(matches$completion_not_before_utc,
                           format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  evidence <- as.POSIXct(matches$evidence_available_at_utc,
                         format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  keep <- matches$counts_for_model & completion < cutoff & evidence < cutoff
  if (nzchar(excluded_competition)) {
    keep <- keep & matches$competition_id != excluded_competition
  }
  matches[keep, , drop = FALSE]
}
```

Production code must additionally require the validated immutable snapshot and reject missing timestamps; this example shows the eligibility predicate only. `[VERIFIED: source schema; ASSUMED: function shape]`

### Club Score Adapter

```r
# Source pattern: R/benchmark/contracts.R and R/evaluation/benchmark_scores.R
score_club_predictions <- function(predictions, fixtures, distributions, fold) {
  stopifnot(identical(unique(predictions$forecast_domain), "club"))
  expected <- fold$declared_fixture_ids[[1L]]
  validate_benchmark_predictions(predictions, expected_fixture_ids = expected)
  validate_benchmark_score_distributions(distributions)
  score_benchmark_fixtures(predictions, fixtures, distributions, expected)
}
```

The actual adapter must match the current function signatures and preserve club/fold hashes in surrounding manifests. `[VERIFIED: existing APIs; ASSUMED: adapter wrapper]`

### Typed Unavailable Row

```r
# Source pattern: Phase 14 unavailable evidence; exact Phase 19 schema is recommended.
club_unavailable_feature <- function(feature_id) {
  data.frame(
    schema_version = "phase19-club-feature-v1",
    forecast_domain = "club",
    feature_id = feature_id,
    availability_status = "unavailable",
    reason_code = "no_accepted_source_contract",
    source_contract_id = "",
    source_contract_sha256 = "",
    value_type = "unavailable",
    value = NA_character_,
    observed_at_utc = "",
    cutoff_status = "not_applicable",
    required_by_model = FALSE,
    active_in_model = FALSE,
    imputation_policy = "forbidden",
    row_sha256 = "",
    stringsAsFactors = FALSE
  )
}
```

### Expected-Domain Consumer Guard

```r
# Source pattern: R/release/release_contract.R identity validation.
assert_forecast_domain <- function(metadata, expected_domain) {
  if (!expected_domain %in% c("national_team", "club")) {
    stop("unsupported expected forecast domain", call. = FALSE)
  }
  if (!is.list(metadata) ||
      !identical(as.character(metadata$forecast_domain), expected_domain)) {
    stop("forecast release domain mismatch", call. = FALSE)
  }
  invisible(TRUE)
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| One national-team model path selected from files | Hash-validated immutable national release selected by `approved_release.csv` | Phases 12 and 14 | Phase 19 should create an equivalent but separate club selector, not regress to path discovery. `[VERIFIED: repository history/artifacts]` |
| Delimiter-based hashes in older benchmark/release helpers | Typed framed canonical-v2 hashing | Phase 18 | New club registries should start on canonical-v2 rather than copy collision-prone helpers. `[VERIFIED: 18-VERIFICATION.md]` |
| Nominal happy-path tests | Adversarial trust-boundary tests plus fresh-process aggregate gate | Phase 18 remediation | Phase 19 needs explicit domain-swap, same-kickoff, fixture-authority, path, hash, and publication attacks. `[VERIFIED: Phase 18 review/verification]` |
| Optional feature absence sometimes represented through model-specific fallback | Durable typed unavailable evidence | Phase 14 patterns and v4.0 requirement | Unsupported club enrichments remain visible and cannot silently affect fits. `[VERIFIED: Phase 14 code; CLUBMOD-05]` |

**Deprecated/outdated:**

- `R/elo/runner.R::compute_elo()` as a club implementation: keep it for legacy national workflows; do not extend its authority to clubs. `[VERIFIED: domain-specific inputs and update behavior]`
- Phase 12/14 release schemas as club release objects: use them as design analogs only. `[VERIFIED: national candidate/panel identities]`
- Direct `readRDS()` or release-directory scanning by a UCL consumer: resolve through the validated club selector. `[VERIFIED: current release contract pattern]`

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The first production candidate should be a club Elo plus venue negative-binomial goal model, compared primarily with a venue-only NB incumbent. | Summary; Pattern 5 | A different candidate family may be required, changing model/evaluation tasks but not the authority architecture. |
| A2 | Cross-league evaluation should include a strict held-out-league transport family in addition to league-season rolling-origin folds. | Pattern 3 | If product owners mean only league-stratified reporting, the strict fold may be unnecessarily hard; clarify before freezing production folds. |
| A3 | Phase 9 numeric promotion margins (`-0.003`, `0.015`, 1%, `0.01`) are appropriate initial club gates, with a two-thirds breadth rule per fold family. | Pattern 5 | Club fixture/fold variance may make them too strict or lenient; they must be owner-reviewed before the production protocol is frozen and never tuned after scores. |
| A4 | Current UCL clubs should form one connected rating graph through accepted domestic/European evidence. | Patterns 2 and 5 | Some accepted data designs may use explicit league-strength priors instead; without either connectivity or priors, cross-league rating comparisons are weak. |
| A5 | One-parameter 1X2 temperature calibration is sufficient for the initial club release. | Pattern 6 | Club calibration may need a different predeclared recipe, but changing it requires a new protocol identity and nested evaluation. |
| A6 | The club release root should be `outputs/releases/club/` with a separate selector. | Recommended Project Structure | Another disjoint topology is acceptable if all validators and consumers bind it exactly. |
| A7 | Model-card identity should be machine-validated through a structured projection. | Pattern 8 | Without this, the Markdown can drift from the release; exact implementation format remains planner discretion. |

## Open Questions (RESOLVED)

The four planning questions are resolved as authority contracts, not as approval of currently proposed values. Production remains dependent on real accepted Phase 18 evidence and explicit owner decisions over the exact hashes described below.

1. **Real fold inventory — resolved to reviewed materialization.**
   - Planning decision: materialize the exact rolling-origin and held-out-league fold inventory only from the accepted historical generation as a self-hashed candidate. It remains `pending_review` until a separate immutable `fold_review.json` records reviewer, review time, decision, exact fold-inventory hash, cutoff hash, calibration-recipe hash, and parent authority hashes. No real score may be computed before that review is accepted.
   - Remaining human/evidence dependency: Phase 18 must expose accepted real rows, source commits, identity coverage, and graph connectivity; an owner must then accept the exact candidate fold review. `[VERIFIED: production history pointer; RESOLVED: Plans 19-03/19-04 review authority]`

2. **Cross-league semantics — resolved to strict held-out-league transport.**
   - Planning decision: the fixture-testable protocol uses strict leave-one-league-out assessment, with the held-out league excluded from fitting, tuning, and calibration. This is a policy candidate, not production authority; production requires an accepted self-hashed `policy_review.json` over the exact candidate family and fold semantics.
   - Remaining human/evidence dependency: an owner must accept the exact policy hash before production fold readiness or scoring. A different split semantics requires a new policy identity and review, never an observed-score-driven edit. `[VERIFIED: CLUBMOD-02; RESOLVED: Plan 19-03 policy review]`

3. **Inherited numeric gates — resolved to reviewable candidates.**
   - Planning decision: inherited thresholds, baselines, seed registry, candidate family, and one-parameter calibration recipe are committed as immutable candidate inputs. They do not become club promotion authority until an owner accepts their exact hashes in `policy_review.json`, before any real predictions or scores are observed.
   - Remaining human/evidence dependency: real fold counts and variance remain unavailable until accepted history exists, and the owner must approve or reject the pre-score candidate policy without tuning it from Phase 19 outcomes. `[VERIFIED: Phase 9 protocol and blocked history; RESOLVED: Plan 19-03 policy review]`

4. **Final-fit cutoff — resolved to fold-reviewed explicit identity.**
   - Planning decision: materialize the final-fit cutoff from the latest eligible row in the accepted history generation strictly before forecast issuance, bind it into the exact candidate fold inventory and `fold_review.json`, and reject any runtime inference from the current provider bundle or forecast inputs.
   - Remaining human/evidence dependency: the current blocked corpus is not production authority; Phase 18 must first provide accepted usable history, after which the owner must accept the exact cutoff and fold-parent hashes before fitting or release publication. `[VERIFIED: CLUBMOD-02/04 and corpus manifest; RESOLVED: Plan 19-04 fold review]`

## Environment Availability

| Dependency | Required By | Available | Version / State | Fallback |
|------------|-------------|-----------|-----------------|----------|
| R | All Phase 19 code | ✓ | 4.6.1 | — |
| `MASS` | Negative-binomial goal model | ✓ | 7.3-65 | No silent Poisson fallback for promotion; fit failure is explicit. `[ASSUMED]` |
| `targets` | Pipeline integration | ✓ | 1.12.0 | Direct focused scripts for tests only |
| `digest` | Existing file hashes | ✓ | 0.6.39 | — |
| `jsonlite` | Protocol/release JSON | ✓ | 2.0.0 | — |
| `testthat` | Validation | ✓ | 3.3.2 | — |
| Git CLI | Code/provenance identity | ✓ | 2.55.0 | Explicit `working-tree` state blocks release |
| Accepted Phase 18 club history | Production fit/evaluation | ✗ | pointer state `blocked`, accepted generation absent | Tagged synthetic fixture corpus for implementation/tests only; no production release |
| Accepted current UCL provider/identity evidence | Current-club release coverage | ✗ | missing credential and real owner mappings | Test fixtures only; production remains blocked |

**Missing dependencies with no production fallback:**

- A real accepted Phase 18 historical club generation. `[VERIFIED: production pointer]`
- Reviewed real current UCL club identity/source authority for current-club coverage. `[VERIFIED: Phase 18 human verification]`

**Missing dependencies with a non-production fallback:**

- Synthetic multi-league fixtures can verify algorithms, contracts, leakage, gates, release publication, and rejection behavior, but must remain incapable of production selection. `[ASSUMED]`

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `testthat` 3.3.2 `[VERIFIED: local environment]` |
| Config file | none; tests source project modules directly `[VERIFIED: tests/testthat pattern]` |
| Quick run command | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase19_<slice>.R", reporter="summary")'` |
| Full phase command | `Rscript --vanilla scripts/verify_phase19_contracts.R` |
| Repository regression | `Rscript --vanilla -e 'testthat::test_dir("tests/testthat")'` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CLUBMOD-01 | Only accepted club history/club IDs feed club rating and goal models; national features/releases/selectors are rejected | unit + integration + adversarial | `test_phase19_club_domain_contract.R`, `test_phase19_club_rating.R`, `test_phase19_club_goal_model.R` | ❌ Wave 0 |
| CLUBMOD-02 | Frozen rolling and held-out-league folds enforce exclusive cutoffs and same-batch invariance | unit + property + integration | `test_phase19_club_folds.R` | ❌ Wave 0 |
| CLUBMOD-03 | Shared proper scores, calibration, exact coverage, deterministic replay, and predeclared gate decide promotion | unit + integration | `test_phase19_club_evaluation.R` | ❌ Wave 0 |
| CLUBMOD-04 | Immutable model-card-backed selector resolves club release and rejects both cross-domain directions | integration + subprocess + failure injection | `test_phase19_club_release.R`, `test_phase19_adversarial_regression.R` | ❌ Wave 0 |
| CLUBMOD-05 | Five enrichment types remain typed unavailable and reject activation/zero-fill/unsupported source claims | unit + integration | `test_phase19_club_domain_contract.R`, `test_phase19_adversarial_regression.R` | ❌ Wave 0 |

### Required Adversarial Inventory

- History pointer/generation tamper, audit-only path, blocked state, arbitrary CSV path, and fixture-to-production escalation. `[ASSUMED]`
- National selector/model/calibrator into club consumer and club selector/model/calibrator into national consumer. `[ASSUMED]`
- Same-kickoff permutation, same-date unknown time, exact-cutoff, after-cutoff, postponed, and extra-time completion evidence. `[ASSUMED]`
- Fold/gate/feature/seed registry drift after freeze; outer labels in fit/tune/calibration roles. `[ASSUMED]`
- Missing fixture, duplicate fixture, incomplete G=40 grid, invalid simplex, wrong domain, disconnected current club, and silent cold-start drop. `[ASSUMED]`
- Release symlink/path traversal, recursive surplus file, hash mismatch, model-card drift, selector swap during read, interrupted writer, lock loser, and post-commit notification failure. `[ASSUMED]`
- `current_xg`, injury, lineup, suspension, or player row activated, omitted, zero-filled, or attached to an unaccepted contract. `[ASSUMED]`

### Sampling Rate

- **Per task commit:** focused test file for the owned module.
- **Per wave merge:** all `test_phase19_*.R` files in fresh R processes.
- **Phase gate:** aggregate `verify_phase19_contracts.R`, existing Phase 18 contract gate, relevant Phase 9/12/14 regression tests, and full repository suite green before verification.

### Wave 0 Gaps

- [ ] `tests/testthat/helper_phase19_club_fixture.R` — deterministic multi-league fixture factory, fixture-only roots, expected hashes.
- [ ] Seven `test_phase19_*.R` files listed above.
- [ ] `scripts/verify_phase19_contracts.R` — exact test inventory, fresh-process execution, no skips/warnings/failures, production-byte map unchanged, production remains fail-closed unless real authority exists.
- [ ] `data/club/model_protocol/*` schemas plus a blocked/pending production protocol state; final fold rows are materialized only from accepted history.

No test-framework installation is needed. `[VERIFIED: local environment]`

## Security Domain

Security enforcement is enabled because `.planning/config.json` does not set it to false. `[VERIFIED: config.json]`

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | No user authentication or remote service is introduced in Phase 19; provider credentials remain Phase 18 scope. `[VERIFIED: phase boundary]` |
| V3 Session Management | no | Static/file pipeline has no application sessions. `[VERIFIED: architecture]` |
| V4 Access Control | yes | Production vs fixture authority, trusted roots, accepted-history pointer, and selector topology are explicit authorization boundaries. `[ASSUMED: ASVS mapping]` |
| V5 Input Validation | yes | Exact schemas, closed enums, canonical hashes, cutoffs, club IDs, paths, inventories, and model object identity validate before use. `[VERIFIED: project patterns]` |
| V6 Cryptography | yes, integrity only | SHA-256/canonical-v2 binds artifacts and selectors; do not treat unkeyed hashes as signatures or secrecy. `[VERIFIED: project patterns]` |

### Known Threat Patterns for the Phase 19 Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| National/club authority confusion | Spoofing / Elevation | Explicit domain field, disjoint selectors, expected-domain guard at every consumer. `[ASSUMED]` |
| Fixture evidence promoted as production | Elevation / Tampering | Fixture discriminator bound into every artifact; production loader/release/selector rejects it; temp roots only. `[ASSUMED]` |
| Manifest/model substitution | Tampering | Exact recursive inventory, canonical parent graph, file hashes before RDS load, object identity checks after load. `[VERIFIED: existing release patterns]` |
| Path traversal or symlink escape | Tampering | Safe IDs/relative paths, lexical and resolved containment, no symlinks, exact topology. `[VERIFIED: Phase 18 remediation]` |
| Time leakage | Tampering / Repudiation | Exclusive cutoffs, immutable folds, same-batch state, row-level max-evidence provenance, injected-label tests. `[VERIFIED: CLUBMOD-02]` |
| Concurrent/interrupted publication | Denial of Service / Tampering | Single writer lock, immutable generation, atomic selector replacement, old selector retained on any failure. `[VERIFIED: existing publication patterns]` |
| Misleading missing evidence | Repudiation | Typed unavailable rows, forbidden imputation, complete per-fixture inventory, model-card limitations. `[VERIFIED: CLUBMOD-05]` |

## Sources

### Primary (HIGH confidence)

- Repository requirements, roadmap, state, AGENTS.md, and `.planning/PROJECT.md` — phase scope and locked project constraints. `[VERIFIED: codebase]`
- `R/club/history_contract.R`, `data/club/history_current.json`, and generation/audit artifacts — actual accepted-history API, schema, and blocked production state. `[VERIFIED: codebase and fresh-process read-back]`
- `R/common/phase18_canonical_hash.R` and `18-VERIFICATION.md` — collision-safe canonical identity and trust-boundary lessons. `[VERIFIED: codebase and verifier]`
- `R/benchmark/cutoffs.R`, `contracts.R`, `baselines.R`, and `R/evaluation/*` — current cutoff, model, score, calibration, and promotion services. `[VERIFIED: codebase]`
- `R/calibration/*`, `R/release/*`, and `R/competition/forecast_layer.R` — current national calibration/release/consumer contracts and domain-specific constraints. `[VERIFIED: codebase]`

### Secondary (MEDIUM confidence)

- [Official R `MASS::glm.nb` documentation](https://stat.ethz.ch/R-manual/R-devel/library/MASS/html/glm.nb.html) — supported NB interface and fitted object semantics. `[CITED: official R documentation]`
- [Official `targets::tar_target` documentation](https://docs.ropensci.org/targets/reference/tar_target.html) — file target semantics. `[CITED: official rOpenSci documentation]`
- [Gneiting and Raftery (2007), Strictly Proper Scoring Rules, Prediction, and Estimation](https://sites.stat.washington.edu/raftery/Research/PDF/Gneiting2007jasa.pdf) — primary statistical basis for proper probabilistic scoring. `[CITED: author-hosted paper]`

### Tertiary (LOW confidence)

- None. Design choices not established by sources are explicitly logged as `[ASSUMED]` and require protocol/owner review before production freeze.

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — installed versions and APIs were checked; no new package is proposed.
- Architecture: HIGH for trust boundaries and reuse seams; MEDIUM for the initial candidate/baseline/fold choice because no Phase 19 CONTEXT.md locks those details.
- Pitfalls: HIGH for source/release/leakage/domain risks observed in existing code and prior reviews; MEDIUM for rating-connectivity policy until real corpus topology is measured.
- Production feasibility: MEDIUM — the full capability is implementable and fixture-testable, but a real approved model/release remains correctly impossible without Phase 18 human evidence.

**Research date:** 2026-09-20  
**Valid until:** 2026-10-20 for repository architecture; re-audit immediately after real Phase 18 source/history acceptance or any change to the national release contract.
